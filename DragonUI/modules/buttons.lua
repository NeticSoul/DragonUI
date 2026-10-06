-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local config, _G = addon.config, _G
local unpack, format, gsub, hooksecurefunc = unpack, string.format, string.gsub, hooksecurefunc
local NUM_PET_ACTION_SLOTS, NUM_SHAPESHIFT_SLOTS = NUM_PET_ACTION_SLOTS, NUM_SHAPESHIFT_SLOTS
local NUM_POSSESS_SLOTS, VEHICLE_MAX_ACTIONBUTTONS = NUM_POSSESS_SLOTS, VEHICLE_MAX_ACTIONBUTTONS

-- ============================================================================
-- BUTTONS MODULE FOR DRAGONUI
-- ============================================================================

local SLOTS_PER_BAR = 12
local STYLED_BAR_ROWS = { 'ActionButton', 'MultiBarBottomLeftButton', 'MultiBarBottomRightButton',
    'MultiBarRightButton', 'MultiBarLeftButton' }

-- Module state tracking
local ButtonsModule = {
    initialized = false,
    applied = false,
    originalValues = {},  -- Store original button states for restoration
    hooked = false,
    pendingRefresh = false,  -- Flag to indicate pending refresh after combat
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("buttons", ButtonsModule,
        addon.L["Buttons"],
        addon.L["Action button styling and enhancements"])
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function IsModuleEnabled()
    return addon:IsModuleEnabled("buttons")
end

local function GetButtonsConfig()
    return addon.db and addon.db.profile and addon.db.profile.buttons
end

-- Blizzard in-range hotkey gray; custom color only needs OnUpdate recolor when it differs.
local HOTKEY_DEFAULT_R, HOTKEY_DEFAULT_G, HOTKEY_DEFAULT_B = 0.6, 0.6, 0.6
local hotkeyStyle = {
    ready = false,
    recolor = false,
    r = HOTKEY_DEFAULT_R, g = HOTKEY_DEFAULT_G, b = HOTKEY_DEFAULT_B, a = 1,
    font = nil, size = 12, flags = "OUTLINE",
    sr = 0, sg = 0, sb = 0, sa = 1,
}

local function UpdateHotkeyStyleCache()
    local db = GetButtonsConfig()
    local hk = db and db.hotkey
    local font = hk and hk.font
    local color = hk and hk.color
    local shadow = hk and hk.shadow

    hotkeyStyle.font = (font and font[1])
        or (addon.Fonts and addon.Fonts.ARIALN)
        or "Fonts\\ARIALN.TTF"
    hotkeyStyle.size = (hk and hk.font_size) or (font and font[2]) or 12
    hotkeyStyle.flags = (font and font[3]) or "OUTLINE"

    hotkeyStyle.r = (color and color[1]) or HOTKEY_DEFAULT_R
    hotkeyStyle.g = (color and color[2]) or HOTKEY_DEFAULT_G
    hotkeyStyle.b = (color and color[3]) or HOTKEY_DEFAULT_B
    hotkeyStyle.a = (color and color[4]) or 1

    hotkeyStyle.sr = (shadow and shadow[1]) or 0
    hotkeyStyle.sg = (shadow and shadow[2]) or 0
    hotkeyStyle.sb = (shadow and shadow[3]) or 0
    hotkeyStyle.sa = (shadow and shadow[4]) or 1

    hotkeyStyle.recolor = (hotkeyStyle.r ~= HOTKEY_DEFAULT_R)
        or (hotkeyStyle.g ~= HOTKEY_DEFAULT_G)
        or (hotkeyStyle.b ~= HOTKEY_DEFAULT_B)
        or (hotkeyStyle.a ~= 1)
    hotkeyStyle.ready = true
end

local function EnsureHotkeyStyleCache()
    if not hotkeyStyle.ready then
        UpdateHotkeyStyleCache()
    end
end

-- ruRU's FRIZQT__ and our bundled fonts lack ●; Blizzard's own hotkey font has it in every locale.
local function HotkeyFontFor(hotkey, font)
    if RANGE_INDICATOR and hotkey:GetText() == RANGE_INDICATOR then
        local blizzard = _G.NumberFontNormalSmallGray
        return (blizzard and blizzard:GetFont()) or font
    end
    return font
end

local function ApplyHotkeyTypography(hotkey)
    if not hotkey then return end
    EnsureHotkeyStyleCache()
    hotkey:SetFont(HotkeyFontFor(hotkey, hotkeyStyle.font), hotkeyStyle.size, hotkeyStyle.flags)
    hotkey:SetShadowOffset(-1.3, -1.1)
    hotkey:SetShadowColor(hotkeyStyle.sr, hotkeyStyle.sg, hotkeyStyle.sb, hotkeyStyle.sa)
end

local function ApplyHotkeyBoundColor(hotkey)
    if not hotkey then return end
    EnsureHotkeyStyleCache()
    hotkey:SetVertexColor(hotkeyStyle.r, hotkeyStyle.g, hotkeyStyle.b, hotkeyStyle.a)
end

function addon.ApplyHotkeyTypography(hotkey)
    ApplyHotkeyTypography(hotkey)
end

function addon.GetHotkeyBoundColor()
    EnsureHotkeyStyleCache()
    return hotkeyStyle.r, hotkeyStyle.g, hotkeyStyle.b, hotkeyStyle.a
end

local function IsAdditionalBarHotkeyEnabled(buttonName)
    if not buttonName or not addon.db or not addon.db.profile then
        return true
    end

    local additional = addon.db.profile.additional
    if not additional then
        return true
    end

    if buttonName:match('^ShapeshiftButton%d+$') then
        return not (additional.stance and additional.stance.show_hotkey == false)
    end

    if buttonName:match('^PetActionButton%d+$') then
        return not (additional.pet and additional.pet.show_hotkey == false)
    end

    if buttonName:match('^PossessButton%d+$')
        or buttonName:match('^MultiCastActionButton%d+$')
        or buttonName == 'MultiCastSummonSpellButton'
        or buttonName == 'MultiCastRecallSpellButton' then
        return not (additional.totem and additional.totem.show_hotkey == false)
    end

    return true
end

local function IsMulticastButton(buttonName)
    return buttonName and (
        buttonName:match('^MultiCastActionButton%d+$')
        or buttonName == 'MultiCastSummonSpellButton'
        or buttonName == 'MultiCastRecallSpellButton'
    )
end

local function IsAdditionalHotkeyTarget(buttonName)
    return buttonName and (
        buttonName:match('^PetActionButton%d+$')
        or buttonName:match('^PossessButton%d+$')
        or IsMulticastButton(buttonName)
    )
end

local function GetSafeEffectiveScale(frame, fallback)
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
    if scale and scale > 0 then
        return scale
    end

    scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
    if scale and scale > 0 then
        return scale
    end

    return fallback or 1
end

local function NormalizeAdditionalHotkeyVisual(button, hotkey)
    if not button or not hotkey then return end

    local buttonName = button:GetName()
    if not IsAdditionalHotkeyTarget(buttonName) then return end

    local isMulticast = IsMulticastButton(buttonName)
    local referenceButton = (isMulticast and _G.ActionButton1) or _G.ShapeshiftButton1
    local referenceHotkey = (isMulticast and _G.ActionButton1HotKey) or _G.ShapeshiftButton1HotKey

    hotkey:ClearAllPoints()
    local _, _, _, xOfs, yOfs = referenceHotkey and referenceHotkey:GetPoint(1)
    hotkey:SetPoint('TOPRIGHT', button, 'TOPRIGHT', (xOfs or -2) - (isMulticast and 0 or 2), yOfs or -3)

    if not referenceHotkey then
        hotkey:SetJustifyH('RIGHT')
        return
    end

    hotkey:SetJustifyH(referenceHotkey:GetJustifyH() or 'RIGHT')
    hotkey:SetJustifyV(referenceHotkey:GetJustifyV() or 'MIDDLE')

    local font, size, flags = referenceHotkey:GetFont()
    if font and size then
        local referenceScale = GetSafeEffectiveScale(referenceButton, 1)
        local buttonScale = GetSafeEffectiveScale(button, referenceScale)
        hotkey:SetFont(HotkeyFontFor(hotkey, font), size * (referenceScale / buttonScale), flags)
    end
end

local function NumberedGlobal(prefix, index)
    return _G[format('%s%d', prefix, index)]
end

-- Stops at the first missing global, since a generic for ends on nil.
function addon.buttons_iterator()
    local row, slot = 1, 0
    local function advance()
        slot = slot + 1
        if slot > SLOTS_PER_BAR then
            row, slot = row + 1, 1
        end
        local prefix = STYLED_BAR_ROWS[row]
        if prefix then
            return NumberedGlobal(prefix, slot)
        end
    end
    return advance
end

function addon.RefreshButtonGrid()
    if not IsModuleEnabled() then return end
    if InCombatLockdown() then
        ButtonsModule.pendingRefresh = true
        return
    end
    for slot = 1, NUM_ACTIONBAR_BUTTONS do
        local mainSlot = NumberedGlobal('ActionButton', slot)
        if mainSlot then
            mainSlot:SetAttribute('showgrid', 1)
            ActionButton_ShowGrid(mainSlot)
        end
    end
end

local function HasPetSlotName(name)
    return name ~= nil and name:find('PetActionButton', 1, true) ~= nil
end

-- PetActionBar_Update swaps in the stock quickslot art; put ours back after it.
local function KeepPetFrameArt(petSlot, texturePath)
    if not IsModuleEnabled() then return end
    local ours = config.assets.normal
    if texturePath and texturePath ~= ours then
        petSlot:SetNormalTexture(ours)
    end
end

local function PinCorners(region, target, right, top, left, bottom)
    region:SetPoint('TOPRIGHT', target, 'TOPRIGHT', right, top)
    region:SetPoint('BOTTOMLEFT', target, 'BOTTOMLEFT', left, bottom)
end

local function AddSlotBackdrop(owner, frameRegion, withShadow)
    if not IsModuleEnabled() or not owner or owner.shadow then return end
    if withShadow then
        local glow = owner:CreateTexture(nil, 'ARTWORK', nil, 1)
        PinCorners(glow, frameRegion, 3.8, 3.8, -3.8, -3.8)
        glow:SetAtlasTexture('ui-hud-actionbar-iconframe-flyoutbordershadow', true)
        owner.shadow = glow
    end
    local backdrop = owner:CreateTexture(nil, 'BACKGROUND')
    backdrop:SetAllPoints(frameRegion)
    backdrop:SetAtlasTexture('ui-hud-actionbar-iconframe-slot')
    backdrop:Show()
    return backdrop
end

local function DigitFree(text)
    return (gsub(text, '%d', ''))
end

-- Every entry is a Lua pattern; the localized names are deliberately left unescaped.
local KEY_SHORTHANDS = {
    { DigitFree(KEY_BUTTON4 or 'Button 4'), 'M' },
    { DigitFree(KEY_NUMPAD1 or 'NumPad 1'), 'N' },
    { 'a%-', 'a' }, { 'c%-', 'c' }, { 's%-', 's' },
    { KEY_BUTTON3 or 'Middle Mouse', 'M3' },
    { KEY_MOUSEWHEELUP or 'Mouse Wheel Up', 'MU' },
    { KEY_MOUSEWHEELDOWN or 'Mouse Wheel Down', 'MD' },
    { KEY_SPACE or 'Space', 'BAR' },
    { CAPSLOCK_KEY_TEXT or 'Caps Lock', 'CL' },
    { KEY_NUMLOCK or 'Num Lock', 'NL' },
    { 'BUTTON', 'M' }, { 'NUMPAD', 'N' },
    { 'ALT%-', 'a' }, { 'CTRL%-', 'c' }, { 'SHIFT%-', 's' },
    { 'MOUSEWHEELUP', 'MU' }, { 'MOUSEWHEELDOWN', 'MD' }, { 'SPACE', 'BAR' },
}
for digit = 0, 5 do
    KEY_SHORTHANDS[#KEY_SHORTHANDS + 1] = { digit .. ' (цифр. кл.)', 'N' .. digit }
end

function addon.GetHotkeyText(key)
    local text = key
    if not text then
        return ''
    end
    for index = 1, #KEY_SHORTHANDS do
        local rule = KEY_SHORTHANDS[index]
        text = gsub(text, rule[1], rule[2])
    end
    return text
end
local GetHotkeyText = addon.GetHotkeyText

-- ============================================================================
-- BUTTON STYLING FUNCTIONS
-- ============================================================================

local function styleHotkey(button)
    if not IsModuleEnabled() then return end
    
	if not button then return end
	local buttonName = button:GetName()
	if not buttonName then return end
	
	local hotkey = _G[buttonName..'HotKey']
	if not hotkey then return end
	
	local db = GetButtonsConfig()
	if not db or not db.hotkey then return end

    local showHotkeyText = db.hotkey.show and IsAdditionalBarHotkeyEnabled(buttonName)
    if not showHotkeyText then
        hotkey:SetAlpha(0)
        hotkey:SetText('')
        hotkey:Hide()
        return
    end

    local function ResolveBindingTextFromCommand(command)
        if not command or command == '' then return nil end
        local key = GetBindingKey(command)
        if not key then return nil end
        return GetBindingText(key, 'KEY_') or key
    end

    local function ResolveButtonHotkeyText()
        local preferCanonicalBinding = buttonName:match('^ShapeshiftButton%d+$') ~= nil
        local text = hotkey:GetText()
        if not preferCanonicalBinding and text and text ~= '' and (not RANGE_INDICATOR or text ~= RANGE_INDICATOR) then
            return text
        end

        local index = tonumber(buttonName:match('(%d+)$'))
        local candidates

        if buttonName:match('^ActionButton%d+$') then
            candidates = {index and ('ACTIONBUTTON' .. index) or nil}
        elseif buttonName:match('^MultiBarBottomLeftButton%d+$') then
            candidates = {index and ('MULTIACTIONBAR1BUTTON' .. index) or nil}
        elseif buttonName:match('^MultiBarBottomRightButton%d+$') then
            candidates = {index and ('MULTIACTIONBAR2BUTTON' .. index) or nil}
        elseif buttonName:match('^MultiBarRightButton%d+$') then
            candidates = {index and ('MULTIACTIONBAR3BUTTON' .. index) or nil}
        elseif buttonName:match('^MultiBarLeftButton%d+$') then
            candidates = {index and ('MULTIACTIONBAR4BUTTON' .. index) or nil}
        elseif buttonName:match('^ShapeshiftButton%d+$') then
            candidates = {index and ('SHAPESHIFTBUTTON' .. index) or nil}
        elseif buttonName:match('^PetActionButton%d+$') then
            candidates = {
                index and ('PETACTIONBUTTON' .. index) or nil,
                index and ('BONUSACTIONBUTTON' .. index) or nil,
            }
        elseif buttonName:match('^PossessButton%d+$') then
            candidates = {
                index and ('POSSESSBUTTON' .. index) or nil,
                index and ('BONUSACTIONBUTTON' .. index) or nil,
            }
        elseif buttonName:match('^MultiCastActionButton%d+$') then
            candidates = {index and ('MULTICASTACTIONBUTTON' .. index) or nil}
        elseif buttonName == 'MultiCastSummonSpellButton' then
            candidates = {'MULTICASTSUMMONSPELL'}
        elseif buttonName == 'MultiCastRecallSpellButton' then
            candidates = {'MULTICASTRECALLSPELL'}
        elseif buttonName:match('^BonusActionButton%d+$') then
            candidates = {index and ('BONUSACTIONBUTTON' .. index) or nil}
        else
            candidates = nil
        end

        if candidates then
            for _, command in ipairs(candidates) do
                local resolvedText = ResolveBindingTextFromCommand(command)
                if resolvedText and resolvedText ~= '' then
                    return resolvedText
                end
            end
        end

        if button.GetHotkey then
            local ok, resolved = pcall(button.GetHotkey, button)
            if ok and resolved and resolved ~= '' then
                return resolved
            end
        end

        if text and text ~= '' and (not RANGE_INDICATOR or text ~= RANGE_INDICATOR) then
            return preferCanonicalBinding and '' or text
        end

        return ''
    end

    -- Keep ● placeholder (hidden); wiping it on early login kills OnUpdate range dots until reload.
    local nativeText = hotkey:GetText()
    local isNativeRangeDot = RANGE_INDICATOR and nativeText == RANGE_INDICATOR
    local text = ResolveButtonHotkeyText()

    hotkey:SetAlpha(1)
    if isNativeRangeDot then
        if db.hotkey.range then
            hotkey:SetText(RANGE_INDICATOR)
            hotkey:Hide()
            if button.action and HasAction(button.action) then
                button.rangeTimer = -1
            end
        else
            hotkey:SetText('')
            hotkey:Hide()
        end
    else
        local formattedText = GetHotkeyText(text)
        hotkey:SetText(formattedText)
        hotkey:Show()
        ApplyHotkeyBoundColor(hotkey)
    end

    ApplyHotkeyTypography(hotkey)
    NormalizeAdditionalHotkeyVisual(button, hotkey)
end

local function RefreshAdditionalBarHotkeys()
    -- Stance/shapeshift buttons
    for index = 1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton' .. index]
        if button then
            styleHotkey(button)
        end
    end

    -- Pet buttons
    for index = 1, NUM_PET_ACTION_SLOTS do
        local button = _G['PetActionButton' .. index]
        if button then
            styleHotkey(button)
        end
    end

    -- Possess buttons
    for index = 1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton' .. index]
        if button then
            styleHotkey(button)
        end
    end

    -- Totem/multicast action buttons
    for index = 1, 12 do
        local button = _G['MultiCastActionButton' .. index]
        if button then
            styleHotkey(button)
        end
    end

    if _G.MultiCastSummonSpellButton then
        styleHotkey(_G.MultiCastSummonSpellButton)
    end

    if _G.MultiCastRecallSpellButton then
        styleHotkey(_G.MultiCastRecallSpellButton)
    end
end

function addon.RefreshAdditionalBarHotkeys()
    if not IsModuleEnabled() then return end
    RefreshAdditionalBarHotkeys()
end

local function StoreOriginalButtonState(button)
    if not button or ButtonsModule.originalValues[button] then return end
    
    local name = button:GetName()
    if not name then return end
    
    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
    
    ButtonsModule.originalValues[button] = {
        normalTexture = normal and normal:GetTexture(),
        normalPoints = {},
        normalVertexColor = normal and {normal:GetVertexColor()},
        normalDrawLayer = normal and normal:GetDrawLayer(),
        size = {button:GetSize()},
        checkedTexture = button:GetCheckedTexture() and button:GetCheckedTexture():GetTexture(),
        pushedTexture = button:GetPushedTexture() and button:GetPushedTexture():GetTexture(),
        highlightTexture = button:GetHighlightTexture() and button:GetHighlightTexture():GetTexture(),
    }
    
    -- Store normal texture points
    if normal then
        for i = 1, normal:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = normal:GetPoint(i)
            table.insert(ButtonsModule.originalValues[button].normalPoints, {point, relativeTo, relativePoint, xOfs, yOfs})
        end
    end
end

local ICON_CROP = { 0.05, 0.95, 0.05, 0.95 }
local ATLAS_CHECKED = '_ui-hud-actionbar-iconborder-checked'
local ATLAS_PUSHED = '_ui-hud-actionbar-iconborder-pushed'
local ATLAS_FLASH = 'ui-hud-actionbar-iconframe-flash'
local AUTOCAST_EDGES = { { 'TOP', 14 }, { 'BOTTOM', -15 } }

local function Part(owner, suffix)
    return owner and _G[owner .. suffix]
end

local function DropToplevel(frame)
    if frame and frame.SetToplevel then
        frame:SetToplevel(false)
    end
end

local function SeatFrameArt(art, owner)
    art:ClearAllPoints()
    PinCorners(art, owner, 2.2, 2.3, -2.2, -2.2)
    art:SetDrawLayer('OVERLAY')
end

local function SeatCooldown(swipe, owner)
    swipe:ClearAllPoints()
    swipe:SetAllPoints(owner)
    swipe:SetFrameLevel(owner:GetParent():GetFrameLevel() + 1)
end

local function DressLayer(layer, atlas, target, onOverlay)
    if atlas then
        layer:SetAtlasTexture(atlas)
    end
    if onOverlay then
        layer:SetDrawLayer('OVERLAY')
    end
    layer:SetAllPoints(target)
end

local STATE_LAYERS = {
    { 'GetCheckedTexture', ATLAS_CHECKED },
    { 'GetPushedTexture', ATLAS_PUSHED },
    { 'GetHighlightTexture' },
}

-- Only the checked and pushed layers (the atlas ones) move up to OVERLAY when asked.
local function SeatStateArt(owner, art, onOverlay)
    owner:SetHighlightTexture(config.assets.highlight)
    for _, entry in ipairs(STATE_LAYERS) do
        local getter, atlas = entry[1], entry[2]
        DressLayer(owner[getter](owner), atlas, art, onOverlay and atlas ~= nil)
    end
end

local function StyleActionSlot(slotButton, skipCombatGuard)
    if not IsModuleEnabled() then return end
    if not skipCombatGuard and InCombatLockdown() then return end
    if not slotButton or slotButton._duiStyled then return end

    local id = slotButton:GetName()
    if not skipCombatGuard and not (id and id:match('^ActionButton%d+$')) then
        DropToplevel(slotButton)
        DropToplevel(slotButton:GetParent())
    end
    StoreOriginalButtonState(slotButton)

    local art = Part(id, 'NormalTexture') or slotButton:GetNormalTexture()
    SeatFrameArt(art, slotButton)
    art:SetVertexColor(1, 1, 1, 1)

    local flash, face = Part(id, 'Flash'), Part(id, 'Icon')
    local swipe, equipRing = Part(id, 'Cooldown'), Part(id, 'Border')
    if flash then flash:SetAtlasTexture(ATLAS_FLASH) end
    if face then
        face:SetTexCoord(unpack(ICON_CROP))
        face:SetDrawLayer('BORDER')
    end
    if swipe then SeatCooldown(swipe, slotButton) end
    if equipRing then DressLayer(equipRing, ATLAS_CHECKED, art) end
    SeatStateArt(slotButton, art, true)

    slotButton.background = AddSlotBackdrop(slotButton, art, true)
    slotButton._duiStyled = true
end

local function StyleExtraSlot(slotButton)
    if not IsModuleEnabled() or InCombatLockdown() or not slotButton then return end
    DropToplevel(slotButton)
    DropToplevel(slotButton:GetParent())
    StoreOriginalButtonState(slotButton)
    slotButton:SetNormalTexture(config.assets.normal)
    if slotButton.background then return end

    local id = slotButton:GetName()
    local art = Part(id, 'NormalTexture2') or Part(id, 'NormalTexture')
    SeatFrameArt(art, slotButton)
    SeatStateArt(slotButton, art, false)

    local swipe, face = Part(id, 'Cooldown'), Part(id, 'Icon')
    local flash, autocast = Part(id, 'Flash'), Part(id, 'AutoCastable')
    if swipe then SeatCooldown(swipe, slotButton) end
    if face then
        face:ClearAllPoints()
        face:SetTexCoord(unpack(ICON_CROP))
        face:SetAllPoints(slotButton)
        face:SetDrawLayer('BORDER')
    end
    if flash then flash:SetAtlasTexture(ATLAS_FLASH) end
    if autocast then
        autocast:ClearAllPoints()
        for _, edge in ipairs(AUTOCAST_EDGES) do
            autocast:SetPoint(edge[1], 0, edge[2])
        end
    end
    if HasPetSlotName(id) then
        hooksecurefunc(slotButton, 'SetNormalTexture', KeepPetFrameArt)
    end

    local backdrop = AddSlotBackdrop(slotButton, art, false)
    slotButton.background = backdrop
    local db = GetButtonsConfig()
    -- Hidden right away so the slot art never flashes for one frame before RefreshButtons.
    if backdrop and db and db.only_actionbackground then
        backdrop:Hide()
    end
end

-- ============================================================================
-- RESTORATION FUNCTIONS
-- ============================================================================

local function RestoreButtonToOriginal(button)
    if not button or not ButtonsModule.originalValues[button] then return end
    
    local original = ButtonsModule.originalValues[button]
    local name = button:GetName()
    if not name then return end
    
    local normal = _G[name..'NormalTexture'] or button:GetNormalTexture()
    
    -- Restore normal texture
    if normal and original.normalTexture then
        normal:SetTexture(original.normalTexture)
        
        -- Restore points
        normal:ClearAllPoints()
        for _, point in ipairs(original.normalPoints) do
            normal:SetPoint(unpack(point))
        end
        
        -- Restore vertex color
        if original.normalVertexColor then
            normal:SetVertexColor(unpack(original.normalVertexColor))
        end
        
        -- Restore draw layer
        if original.normalDrawLayer then
            normal:SetDrawLayer(original.normalDrawLayer)
        end
    end
    
    -- Restore size
    if original.size then
        button:SetSize(unpack(original.size))
    end
    
    -- Remove custom backgrounds and shadows
    if button.background then
        button.background:Hide()
        button.background = nil
    end
    
    if button.shadow then
        button.shadow:Hide()
        button.shadow = nil
    end
    
    -- Reset styled flag
    button._duiStyled = nil
    
    -- Clear original values
    ButtonsModule.originalValues[button] = nil
end

local function RestoreAllButtons()
    -- Restore main action buttons
    for button in addon.buttons_iterator() do
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore vehicle buttons
    for index=1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G['VehicleMenuBarActionButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore possess buttons
    for index=1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore pet buttons
    for index=1, NUM_PET_ACTION_SLOTS do
        local button = _G['PetActionButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    -- Restore stance buttons
    for index=1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            RestoreButtonToOriginal(button)
        end
    end
    
    ButtonsModule.applied = false
end

-- ============================================================================
-- APPLY STYLING
-- ============================================================================

local function ApplyButtonStyling()
    if ButtonsModule.applied then return end

    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("buttons_apply_styling", ApplyButtonStyling)
        end
        return
    end

    for slotButton in addon.buttons_iterator() do
        StyleActionSlot(slotButton)
        slotButton:SetSize(37, 37)
    end
    
    ButtonsModule.applied = true
end

-- ============================================================================
-- UPDATE HANDLERS
-- ============================================================================

local function KeyBindModeActive()
    local binder = addon.KeyBindingModule
    if not (binder and binder.enabled and LibStub) then return false end
    local keyBound = LibStub('LibKeyBound-1.0')
    return keyBound ~= nil and keyBound:IsShown() and true or false
end

local function refreshSlotButton(slotButton)
    if not IsModuleEnabled() then return end
    if KeyBindModeActive() and slotButton and slotButton.GetName then
        local macroLabel = Part(slotButton:GetName(), 'Name')
        if macroLabel then macroLabel:Hide() end
    end
    if not slotButton then return end
    local id = slotButton:GetName()
    if id and id:find('MultiCast', 1, true) then return end
    slotButton:SetNormalTexture(config.assets.normal)
    -- Blizzard grays an empty slot's hotkey here, and the range recolor below never revisits it.
    if hotkeyStyle.recolor and not slotButton.rangeTimer then
        local hotkey = Part(id, 'HotKey')
        if hotkey and hotkey:GetText() ~= RANGE_INDICATOR then
            ApplyHotkeyBoundColor(hotkey)
        end
    end
end

function addon.RefreshButtons()
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't refresh buttons during combat to avoid taint
    if InCombatLockdown() then 
        ButtonsModule.pendingRefresh = true
        return 
    end

    UpdateHotkeyStyleCache()
    
    local db = GetButtonsConfig()
    if not db then return end

    for button in addon.buttons_iterator() do
        if button and button.background then
            local buttonName = button:GetName()
            if buttonName then
                local isMainActionButton = buttonName:match("^ActionButton%d+$")

                -- show/hide action backgrounds
                if db.only_actionbackground and not isMainActionButton then
                    button.background:Hide()
                else
                    button.background:Show()
                end

                -- update hotkeys and range indicators
                pcall(styleHotkey, button)

                -- handle macro text
                local macros = _G[buttonName .. 'Name']
                if macros and db.macros then
                    if db.macros.show then
                        macros:Show()
                    else
                        macros:Hide()
                    end
                    if db.macros.color then macros:SetVertexColor(unpack(db.macros.color)) end
                    if db.macros.font then macros:SetFont(unpack(db.macros.font)) end
                end

                -- handle count text
                local count = _G[buttonName .. 'Count']
                if count and db.count then
                    count:SetAlpha(db.count.show and 1 or 0)
                end

                -- handle border styling and equipped state
                local border = _G[buttonName .. 'Border']
                if border then
                    if db.border_color then
                        border:SetVertexColor(unpack(db.border_color))
                    end
                    border:SetAlpha(IsEquippedAction(button.action) and 1 or 0)
                end

                ActionButton_Update(button)
            end
        end
    end

    -- buttons_iterator() only walks main/multi bars, so pet/stance/possess/extrabar need their own toggle pass.
    local additionalBars = {
        { prefix = 'PetActionButton', count = NUM_PET_ACTION_SLOTS },
        { prefix = 'ShapeshiftButton', count = NUM_SHAPESHIFT_SLOTS },
        { prefix = 'PossessButton', count = NUM_POSSESS_SLOTS },
        { prefix = 'DragonUI_ExtraBarButton', count = 12 },
    }
    for _, bar in ipairs(additionalBars) do
        for index = 1, bar.count do
            local button = _G[bar.prefix .. index]
            if button and button.background then
                if db.only_actionbackground then
                    button.background:Hide()
                else
                    button.background:Show()
                end
            end
        end
    end

    RefreshAdditionalBarHotkeys()
    if addon.RefreshExtrabarMacroNames then
        addon.RefreshExtrabarMacroNames()
    end
end

-- ============================================================================
-- TEMPLATE FUNCTIONS
-- ============================================================================

-- Texture-only work, so a vehicle entered mid-combat can still be skinned with the skip flag.
function addon.StyleVehicleButtons(skipCombatGuard)
    if not IsModuleEnabled() then return end
    if skipCombatGuard or UnitHasVehicleUI('player') then
        for seat = 1, VEHICLE_MAX_ACTIONBUTTONS do
            local vehicleSlot = NumberedGlobal('VehicleMenuBarActionButton', seat)
            if vehicleSlot then
                StyleActionSlot(vehicleSlot, skipCombatGuard)
                styleHotkey(vehicleSlot)
            end
        end
    end
    RefreshAdditionalBarHotkeys()
end

function addon.RefreshAllHotkeys()
    if not IsModuleEnabled() then return end

    UpdateHotkeyStyleCache()

    for button in addon.buttons_iterator() do
        if button then
            styleHotkey(button)
        end
    end

    RefreshAdditionalBarHotkeys()
end

function addon.RefreshHotkeyStyle()
    if IsModuleEnabled() then
        addon.RefreshAllHotkeys()
    else
        UpdateHotkeyStyleCache()
    end
    if addon.RefreshExtrabarHotkeys then
        addon.RefreshExtrabarHotkeys()
    end
end

function addon.SetKeybindVisualMode(active)
    if not IsModuleEnabled() then return end

    for button in addon.buttons_iterator() do
        if button and button.GetName then
            local macroText = _G[button:GetName() .. 'Name']
            if macroText then
                if active then
                    macroText:Hide()
                else
                    local db = GetButtonsConfig()
                    if db and db.macros and db.macros.show then
                        macroText:Show()
                    else
                        macroText:Hide()
                    end
                end
            end

            -- Keep DragonUI border texture stable while LibKeyBound is active.
            if active then
                button:SetNormalTexture(config.assets.normal)
            end
        end
    end

    if not active then
        addon.RefreshButtons()
    end
end

local function StyleExtraRow(prefix, count, withHotkeys)
    for index = 1, count do
        local extra = NumberedGlobal(prefix, index)
        StyleExtraSlot(extra)
        if extra and withHotkeys then
            styleHotkey(extra)
        end
    end
end

-- Hotkeys only: restyling the multicast buttons left Blizzard's totem bar invisible.
function addon.StyleTotemButtons()
    if not IsModuleEnabled() then return end
    RefreshAdditionalBarHotkeys()
end

-- export name -> { button prefix, slot count, refresh hotkeys too }
local EXTRA_ROW_EXPORTS = {
    StylePossessButtons = { 'PossessButton', NUM_POSSESS_SLOTS, false },
    StylePetButtons = { 'PetActionButton', NUM_PET_ACTION_SLOTS, true },
    StyleStanceButtons = { 'ShapeshiftButton', NUM_SHAPESHIFT_SLOTS, true },
}
for exportName, row in pairs(EXTRA_ROW_EXPORTS) do
    addon[exportName] = function()
        if not IsModuleEnabled() then return end
        StyleExtraRow(row[1], row[2], row[3])
    end
end

-- ============================================================================
-- ACTION BUTTON TOOLTIPS
-- ============================================================================

-- buttons.tooltips: "always" | "combat" (hidden in combat) | "never"
function addon.ShouldHideActionTooltip()
    local db = GetButtonsConfig()
    local mode = db and db.tooltips
    local hide = mode == "never" or (mode == "combat" and InCombatLockdown())
    return hide and IsModuleEnabled() or false
end

local function HideActionTooltip(tooltip)
    if addon.ShouldHideActionTooltip() then
        tooltip:Hide()
    end
end

-- ============================================================================
-- HOOKS MANAGEMENT
-- ============================================================================

local function SetupHooks()
    if ButtonsModule.hooked or not IsModuleEnabled() then return end

    hooksecurefunc('ActionButton_Update', refreshSlotButton)

    hooksecurefunc(GameTooltip, 'SetAction', HideActionTooltip)
    hooksecurefunc(GameTooltip, 'SetShapeshift', HideActionTooltip)
    -- Pet commands (Attack, Follow...) fill the tooltip with SetText, never SetPetAction.
    hooksecurefunc('PetActionButton_OnEnter', function(button)
        if GameTooltip:IsOwned(button) then
            HideActionTooltip(GameTooltip)
        end
    end)

    if type(_G.ActionButton_UpdateHotkeys) == 'function' then
        hooksecurefunc('ActionButton_UpdateHotkeys', function(button)
            if not IsModuleEnabled() then return end
            if button then
                styleHotkey(button)
            end
        end)
    end

    -- Blizzard ActionButton_OnUpdate paints in-range gray; reassert custom color only when needed.
    if type(_G.ActionButton_OnUpdate) == 'function' then
        hooksecurefunc('ActionButton_OnUpdate', function(self)
            -- Blizzard only repaints the hotkey on the frame it resets rangeTimer, so only recolor then.
            if not hotkeyStyle.recolor or not self or self.rangeTimer ~= TOOLTIP_UPDATE_TIME then return end
            if not IsModuleEnabled() then return end
            local name = self:GetName()
            if not name then return end
            local hotkey = _G[name .. 'HotKey']
            if not hotkey or not hotkey:IsShown() then return end
            local text = hotkey:GetText()
            if not text or text == '' or text == RANGE_INDICATOR then return end
            -- Keep Blizzard OOR red; IsActionInRange(0) matches ActionButton.lua range branch.
            if IsActionInRange(self.action) == 0 then return end
            hotkey:SetVertexColor(hotkeyStyle.r, hotkeyStyle.g, hotkeyStyle.b, hotkeyStyle.a)
        end)
    end

    if type(_G.PetActionButton_SetHotkeys) == 'function' then
        hooksecurefunc('PetActionButton_SetHotkeys', function()
            if not IsModuleEnabled() then return end
            RefreshAdditionalBarHotkeys()
        end)
    end

    -- Read once per session; a new border colour needs a reload to reach the grid tint.
    local gridTint
    hooksecurefunc('ActionButton_ShowGrid', function(slotButton)
        if not IsModuleEnabled() or not slotButton or KeyBindModeActive() then return end
        local id = slotButton:GetName()
        if not id then return end
        if not gridTint then
            local c = config.buttons.border_color
            if not c then return end
            gridTint = { c[1], c[2], c[3], c[4] }
        end
        local art = Part(id, 'NormalTexture')
        if art then
            art:SetVertexColor(gridTint[1], gridTint[2], gridTint[3], gridTint[4])
        end
    end)
    
    -- HideGrid hook: protect ONLY main bar from ever being hidden.
    -- Additional bars are fully managed by Blizzard — we don't touch them.
    hooksecurefunc('ActionButton_HideGrid', function(button)
        if not IsModuleEnabled() then return end
        if InCombatLockdown() then return end
        if not button then return end
        local name = button:GetName()
        if name and name:match("^ActionButton%d+$") then
            button:SetAttribute('showgrid', 1)
            button:Show()
        end
    end)
    
    ButtonsModule.hooked = true
end

-- ============================================================================
-- MODULE CONTROL FUNCTIONS
-- ============================================================================

function addon.RefreshButtonStyling()
    if IsModuleEnabled() then
        -- Apply styling
        SetupHooks()
        ApplyButtonStyling()
        
        -- Refresh all templates
        addon.StyleVehicleButtons()
        addon.StylePossessButtons()
        addon.StylePetButtons()
        addon.StyleStanceButtons()
        addon.StyleTotemButtons()
        
        -- Refresh button states
        addon.RefreshButtons()

        -- Re-apply dark mode tinting after full button restyle
        if addon.RefreshDarkModeActionButtons then
            addon.RefreshDarkModeActionButtons()
        end
    else
        -- Restore original buttons
        RestoreAllButtons()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if ButtonsModule.initialized then return end
    
    -- Only apply styling if module is enabled
    if IsModuleEnabled() then
        ApplyButtonStyling()
        SetupHooks()
    end

    if addon.db and addon.db.RegisterCallback then
        local function OnProfileChanged()
            hotkeyStyle.ready = false
            hotkeyStyle.recolor = false
            if IsModuleEnabled() then
                addon.RefreshAllHotkeys()
            end
        end
        addon.db.RegisterCallback(ButtonsModule, "OnProfileChanged", OnProfileChanged)
        addon.db.RegisterCallback(ButtonsModule, "OnProfileCopied", OnProfileChanged)
        addon.db.RegisterCallback(ButtonsModule, "OnProfileReset", OnProfileChanged)
    end
    
    ButtonsModule.initialized = true
end

local function OnLoginGridPass()
    if IsModuleEnabled() then
        addon.RefreshButtonGrid()
        addon.RefreshButtons()
    end
    collectgarbage()
end
addon.package:Subscribe(OnLoginGridPass, 'PLAYER_LOGIN')

-- Auto-initialize when addon loads and handle post-combat refresh
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
initFrame:RegisterEvent("UPDATE_BINDINGS")  -- CLAVE: Actualizar hotkeys cuando cambien los bindings
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-enforce main bar grid on every zone / instance / reload.
        if IsModuleEnabled() then
            addon.RefreshButtonGrid()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Execute pending refreshes after combat ends
        if IsModuleEnabled() and ButtonsModule.pendingRefresh then
            ButtonsModule.pendingRefresh = false
            addon.RefreshButtonGrid()
            addon.RefreshButtons()
        end
    elseif event == "UPDATE_BINDINGS" then
        -- ORIGINAL PATTERN: Update hotkeys when bindings change
        if IsModuleEnabled() then
            addon.RefreshAllHotkeys()
        end
    end
end)

-- Multibar grids are left to Blizzard's option setFunc (MultiActionBar_ShowAllGrids/HideAllGrids).
hooksecurefunc("SetCVar", function(name, value)
    if name == "alwaysShowActionBars" then
        if not IsModuleEnabled() then return end
        local mixin = addon.MainMenuBarMixin
        if mixin and mixin.update_main_bar_background then
            mixin:update_main_bar_background()
        end
    end
end)