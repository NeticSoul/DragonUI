local addon = select(2,...);
local config = addon.config;
local action = addon.functions;
local unpack = unpack;
local select = select;
local format = string.format;
local match = string.match;
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS;
local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS;
local NUM_POSSESS_SLOTS = NUM_POSSESS_SLOTS;
local VEHICLE_MAX_ACTIONBUTTONS = VEHICLE_MAX_ACTIONBUTTONS;
local hooksecurefunc = hooksecurefunc;
local _G = getfenv(0);

-- ============================================================================
-- BUTTONS MODULE FOR DRAGONUI
-- ============================================================================

local actionbars = {
	'ActionButton',
	'MultiBarBottomLeftButton',
	'MultiBarBottomRightButton',
	'MultiBarRightButton',
	'MultiBarLeftButton',
};

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
        (addon.L and addon.L["Buttons"]) or "Buttons",
        (addon.L and addon.L["Action button styling and enhancements"]) or "Action button styling and enhancements")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("buttons")
end

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

local function ApplyHotkeyTypography(hotkey)
    if not hotkey then return end
    EnsureHotkeyStyleCache()
    hotkey:SetFont(hotkeyStyle.font, hotkeyStyle.size, hotkeyStyle.flags)
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
        hotkey:SetFont(font, size * (referenceScale / buttonScale), flags)
    end
end

addon.buttons_iterator = function()
    local index = 0
    local barIndex = 1
    return function()
        index = index + 1
        if index > 12 then
            index = 1
            barIndex = barIndex + 1
        end
        if actionbars[barIndex] then
            return _G[actionbars[barIndex] .. index]
        end
    end
end

function addon.actionbuttons_grid()
    if not IsModuleEnabled() then return end
    if InCombatLockdown() then
        ButtonsModule.pendingRefresh = true
        return
    end

    for index = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G[format('ActionButton%d', index)]
        if button then
            button:SetAttribute('showgrid', 1)
            ActionButton_ShowGrid(button)
        end
    end
end

local function is_petaction(self, name)
	local spec = self:GetName():match(name)
	if (spec) then return true else return false end
end

local function fix_texture(self, texture)
    if not IsModuleEnabled() then return end
    
	if texture and texture ~= config.assets.normal then
		self:SetNormalTexture(config.assets.normal)
	end
end

local function setup_background(button, anchor, shadow)
    if not IsModuleEnabled() then return nil end
    
	if not button or button.shadow then return; end
	if shadow and not button.shadow then
		local shadow = button:CreateTexture(nil, 'ARTWORK', nil, 1)
		shadow:SetPoint('TOPRIGHT', anchor, 3.8, 3.8)
		shadow:SetPoint('BOTTOMLEFT', anchor, -3.8, -3.8)
		shadow:set_atlas('ui-hud-actionbar-iconframe-flyoutbordershadow', true)
		button.shadow = shadow;
	end

	local background = button:CreateTexture(nil, 'BACKGROUND');
	background:SetAllPoints(anchor);
	background:set_atlas('ui-hud-actionbar-iconframe-slot');
	background:Show();
	
	return background;
end

-- ============================================================================
-- KEY FORMATTING SYSTEM
-- ============================================================================

local GetKeyText
do
    local keyButton = string.gsub(KEY_BUTTON4 or "Button 4", '%d', '')
    local keyNumpad = string.gsub(KEY_NUMPAD1 or "NumPad 1", '%d', '')
    local displaySubs = {
        { '('..keyButton..')', 'M' },
        { '('..keyNumpad..')', 'N' },
        { '(a%-)', 'a' },           -- alt- -> a (lowercase)
        { '(c%-)', 'c' },           -- ctrl- -> c (lowercase)
        { '(s%-)', 's' },           -- shift- -> s (lowercase)
        { KEY_BUTTON3 or "Middle Mouse", 'M3' },
        { KEY_MOUSEWHEELUP or "Mouse Wheel Up", 'MU' },
        { KEY_MOUSEWHEELDOWN or "Mouse Wheel Down", 'MD' },
        { KEY_SPACE or "Space", 'BAR' },
        { CAPSLOCK_KEY_TEXT or "Caps Lock", 'CL' },
        { KEY_NUMLOCK or "Num Lock", 'NL' },
        { 'BUTTON', 'M' },
        { 'NUMPAD', 'N' },
        { '(ALT%-)', 'a' },         -- ALT- -> a (uppercase version)
        { '(CTRL%-)', 'c' },        -- CTRL- -> c 
        { '(SHIFT%-)', 's' },       -- SHIFT- -> s
        { 'MOUSEWHEELUP', 'MU' },
        { 'MOUSEWHEELDOWN', 'MD' },
        { 'SPACE', 'BAR' },
    }

    -- returns formatted key for text.
    -- @param key - a hotkey name
    function GetKeyText(key)
        if not key then return '' end
        for _, value in pairs(displaySubs) do
            key = string.gsub(key, value[1], value[2])
        end
        return key or error('invalid key string: '..tostring(key))
    end
end

-- Assign to addon for global access
addon.GetKeyText = GetKeyText

-- ============================================================================
-- BUTTON STYLING FUNCTIONS
-- ============================================================================

local function actionbuttons_hotkey(button)
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
        local formattedText = GetKeyText(text)
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
            actionbuttons_hotkey(button)
        end
    end

    -- Pet buttons
    for index = 1, NUM_PET_ACTION_SLOTS do
        local button = _G['PetActionButton' .. index]
        if button then
            actionbuttons_hotkey(button)
        end
    end

    -- Possess buttons
    for index = 1, NUM_POSSESS_SLOTS do
        local button = _G['PossessButton' .. index]
        if button then
            actionbuttons_hotkey(button)
        end
    end

    -- Totem/multicast action buttons
    for index = 1, 12 do
        local button = _G['MultiCastActionButton' .. index]
        if button then
            actionbuttons_hotkey(button)
        end
    end

    if _G.MultiCastSummonSpellButton then
        actionbuttons_hotkey(_G.MultiCastSummonSpellButton)
    end

    if _G.MultiCastRecallSpellButton then
        actionbuttons_hotkey(_G.MultiCastRecallSpellButton)
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

local function main_buttons(button, skipCombatGuard)
    if not IsModuleEnabled() then return end
    
    -- Don't style buttons during combat to avoid taint (vehicle buttons
    -- bypass this via skipCombatGuard — all ops are texture-level, combat-safe)
    if InCombatLockdown() and not skipCombatGuard then return end
    
	if not button or button.__styled then return; end

    local buttonName = button:GetName()
    local isMainActionButton = buttonName and buttonName:match('^ActionButton%d+$')

    -- Prevent click-driven top-level promotion on secondary bars.
    -- In 3.3.5a, top-level frames can raise above sibling art frames when clicked.
    if not skipCombatGuard and not isMainActionButton and button.SetToplevel then
        button:SetToplevel(false)
        local parentBar = button:GetParent()
        if parentBar and parentBar.SetToplevel then
            parentBar:SetToplevel(false)
        end
    end

    -- Store original state before styling
    StoreOriginalButtonState(button)

	local name = button:GetName();
	local normal = _G[name..'NormalTexture'] or button:GetNormalTexture();
	local icon = _G[name..'Icon']
	local flash = _G[name..'Flash']
	local cooldown = _G[name..'Cooldown']
	local border = _G[name..'Border']
	
	normal:ClearAllPoints()
	normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
	normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)
	normal:SetVertexColor(1, 1, 1, 1)
	normal:SetDrawLayer('OVERLAY')

	if flash then
		flash:set_atlas('ui-hud-actionbar-iconframe-flash')
	end

	if icon then
		icon:SetTexCoord(.05, .95, .05, .95)
		icon:SetDrawLayer('BORDER')
	end

	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
		cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() +1)
	end
	
	if border then
		border:set_atlas('_ui-hud-actionbar-iconborder-checked')
		border:SetAllPoints(normal)
	end
	
	-- apply button textures
	button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
	button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
	button:SetHighlightTexture(config.assets.highlight)
	button:GetCheckedTexture():SetAllPoints(normal)
	button:GetPushedTexture():SetAllPoints(normal)
	button:GetHighlightTexture():SetAllPoints(normal)
	button:GetCheckedTexture():SetDrawLayer('OVERLAY')
	button:GetPushedTexture():SetDrawLayer('OVERLAY')

	button.background = setup_background(button, normal, true)
	
	button.__styled = true
end

local function additional_buttons(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't style buttons during combat to avoid taint
    if InCombatLockdown() then return end
    
	if not button then return; end

    if button.SetToplevel then
        button:SetToplevel(false)
        local parentBar = button:GetParent()
        if parentBar and parentBar.SetToplevel then
            parentBar:SetToplevel(false)
        end
    end
	
    -- Store original state before styling
    StoreOriginalButtonState(button)
    
	button:SetNormalTexture(config.assets.normal)
	if button.background then return; end

	local name = button:GetName();
	local icon = _G[name..'Icon']
	local flash = _G[name..'Flash']
	local normal = _G[name..'NormalTexture2'] or _G[name..'NormalTexture']
	local cooldown = _G[name..'Cooldown']
	local castable = _G[name..'AutoCastable']

	normal:ClearAllPoints()
	normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
	normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)
	normal:SetDrawLayer('OVERLAY')

	-- apply button textures
	button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
	button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
	button:SetHighlightTexture(config.assets.highlight)
	button:GetCheckedTexture():SetAllPoints(normal)
	button:GetPushedTexture():SetAllPoints(normal)
	button:GetHighlightTexture():SetAllPoints(normal)

	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(button)
		cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() +1)
	end

	if icon then
		icon:ClearAllPoints()
		icon:SetTexCoord(.05, .95, .05, .95)
		icon:SetAllPoints(button)
		icon:SetDrawLayer('BORDER')
	end

	if flash then
		flash:set_atlas('ui-hud-actionbar-iconframe-flash')
	end
	
	if castable then
		castable:ClearAllPoints()
		castable:SetPoint('TOP', 0, 14)
		castable:SetPoint('BOTTOM', 0, -15)
	end

	if is_petaction(button, 'PetActionButton') then
		hooksecurefunc(button, "SetNormalTexture", fix_texture)
	end
	button.background = setup_background(button, normal, false)

	-- Apply the toggle now — waiting for the next RefreshButtons() pass flashes it visible first.
	if button.background then
		local db = GetButtonsConfig()
		if db and db.only_actionbackground then
			button.background:Hide()
		end
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
    button.__styled = nil
    
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
    
    -- Setup main action buttons
    for button in addon.buttons_iterator() do
        if button then
            main_buttons(button)
            button:SetSize(37, 37)
        end
    end
    
    ButtonsModule.applied = true
end

-- ============================================================================
-- UPDATE HANDLERS
-- ============================================================================

local function actionbuttons_update(button)
    if not IsModuleEnabled() then return end
    
    -- CRITICAL: Don't interfere with LibKeyBound during keybind mode
    if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
        local LibKeyBound = LibStub("LibKeyBound-1.0")
        if LibKeyBound:IsShown() then
            if button and button.GetName then
                local macroText = _G[button:GetName() .. 'Name']
                if macroText then
                    macroText:Hide()
                end
            end
        end
    end
    
	if not button then return; end
	local name = button:GetName();
	if name:find('MultiCast') then return; end
	button:SetNormalTexture(config.assets.normal);
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
                pcall(actionbuttons_hotkey, button)

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

-- setup vehicle action buttons
-- @param skipCombatGuard: bypass InCombatLockdown + UnitHasVehicleUI guards
--   for mid-combat vehicle entry (all operations are texture-level, combat-safe)
function addon.vehiclebuttons_template(skipCombatGuard)
    if not IsModuleEnabled() then return end
    
	if skipCombatGuard or UnitHasVehicleUI('player') then
		for index=1, VEHICLE_MAX_ACTIONBUTTONS do
			local button = _G['VehicleMenuBarActionButton'..index]
			if button then
				main_buttons(button, skipCombatGuard)
				actionbuttons_hotkey(button)
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
            actionbuttons_hotkey(button)
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

-- setup possess buttons
function addon.possessbuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_POSSESS_SLOTS do
		additional_buttons(_G['PossessButton'..index])
	end
end

-- Totem/multicast buttons (Shaman) — intentionally left unstyled.
-- The multicast module handles positioning only; modifying textures here
-- caused invisibility issues with Blizzard's multicast bar.
function addon.totembuttons_template()
    if not IsModuleEnabled() then return end
    RefreshAdditionalBarHotkeys()
end

-- setup pet action buttons
function addon.petbuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_PET_ACTION_SLOTS do
		local button = _G['PetActionButton'..index]
		if button then
			additional_buttons(button)
			-- Apply hotkey format to pet buttons too
			actionbuttons_hotkey(button)
		end
	end
end

-- setup stance/shapeshift buttons
function addon.stancebuttons_template()
    if not IsModuleEnabled() then return end
    
	for index=1, NUM_SHAPESHIFT_SLOTS do
		local button = _G['ShapeshiftButton'..index]
		if button then
			additional_buttons(button)
			-- Apply hotkey format to stance buttons too
			actionbuttons_hotkey(button)
		end
	end
end

-- ============================================================================
-- HOOKS MANAGEMENT
-- ============================================================================

local function SetupHooks()
    if ButtonsModule.hooked or not IsModuleEnabled() then return end
    
    hooksecurefunc('ActionButton_Update', actionbuttons_update)

    if type(_G.ActionButton_UpdateHotkeys) == 'function' then
        hooksecurefunc('ActionButton_UpdateHotkeys', function(button)
            if not IsModuleEnabled() then return end
            if button then
                actionbuttons_hotkey(button)
            end
        end)
    end

    -- Blizzard ActionButton_OnUpdate paints in-range gray; reassert custom color only when needed.
    if type(_G.ActionButton_OnUpdate) == 'function' then
        hooksecurefunc('ActionButton_OnUpdate', function(self)
            if not hotkeyStyle.recolor or not IsModuleEnabled() or not self then return end
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

    -- cache border color to avoid repeated config access
    local cachedBorderColor = nil

    -- ShowGrid hook: apply our custom border color to NormalTexture.
    -- This is the ONLY thing we do in this hook — no show/hide logic.
    -- Matches pretty_actionbar's approach exactly.
    hooksecurefunc('ActionButton_ShowGrid', function(button)
        if not IsModuleEnabled() then return end
        if not button then return end
        
        -- Don't interfere with LibKeyBound during keybind mode
        if addon.KeyBindingModule and addon.KeyBindingModule.enabled and LibStub and LibStub("LibKeyBound-1.0") then
            local LibKeyBound = LibStub("LibKeyBound-1.0")
            if LibKeyBound:IsShown() then return end
        end
        
        local buttonName = button:GetName()
        if not buttonName then return end
        
        if not cachedBorderColor then
            cachedBorderColor = config.buttons.border_color
        end
        
        local normalTexture = _G[buttonName..'NormalTexture']
        if normalTexture then
            normalTexture:SetVertexColor(cachedBorderColor[1], cachedBorderColor[2], cachedBorderColor[3], cachedBorderColor[4])
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
        addon.vehiclebuttons_template()
        addon.possessbuttons_template()
        addon.petbuttons_template()
        addon.stancebuttons_template()
        addon.totembuttons_template()
        
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

-- Register initialization events
addon.package:RegisterEvents(function()
    if IsModuleEnabled() then
        addon.actionbuttons_grid()
        addon.RefreshButtons()
    end
    collectgarbage()
end,
    'PLAYER_LOGIN'
);

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
            addon.actionbuttons_grid()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Execute pending refreshes after combat ends
        if IsModuleEnabled() and ButtonsModule.pendingRefresh then
            ButtonsModule.pendingRefresh = false
            addon.actionbuttons_grid()
            addon.RefreshButtons()
        end
    elseif event == "UPDATE_BINDINGS" then
        -- ORIGINAL PATTERN: Update hotkeys when bindings change
        if IsModuleEnabled() then
            addon.RefreshAllHotkeys()
        end
    end
end)

-- Monitor alwaysShowActionBars CVar changes.
-- Only refresh our custom main bar art background.  Multibar grid management
-- is handled by Blizzard’s InterfaceOptions setFunc which directly calls
-- MultiActionBar_ShowAllGrids / MultiActionBar_HideAllGrids.
hooksecurefunc("SetCVar", function(name, value)
    if name == "alwaysShowActionBars" then
        if not IsModuleEnabled() then return end
        if MainMenuBarMixin and MainMenuBarMixin.update_main_bar_background then
            MainMenuBarMixin:update_main_bar_background()
        end
    end
end)