-- ============================================================================
-- DragonUI - Buff Frame Module
-- Based on RetailUI by Dmitriy (MIT License)
-- Adapted for DragonUI with Dragonflight-inspired positioning control.
-- ============================================================================

local addon = select(2, ...);

local BuffFrameModule = {}
addon.BuffFrameModule = BuffFrameModule

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("buffs", BuffFrameModule,
        addon.L["Buff Frame"],
        addon.L["Custom buff frame styling, positioning and toggle button"])
end

-- Local variables
local buffFrame = nil
local toggleButton = nil
local dragonUIBuffFrame = nil
local dragonUIWeaponBuffFrame = nil
local dragonUIDebuffFrame = nil
local buffsHiddenByToggle = false
local weaponEnchantsAreSeparated = false

-- Default buff frame position (must match database.lua defaults)
local BUFF_DEFAULT_ANCHOR = "TOPRIGHT"
local BUFF_DEFAULT_POSX = -270
local BUFF_DEFAULT_POSY = -15

-- Y position when a GM ticket or GM chat panel is open
local BUFF_TICKET_POSY = -60

-- Save original BuffFrame methods BEFORE anything modifies them
local original_BuffFrame_SetPoint = BuffFrame.SetPoint
local original_BuffFrame_ClearAllPoints = BuffFrame.ClearAllPoints

-- Save original ConsolidatedBuffs methods — same lock pattern as BuffFrame
local original_CB_SetPoint = ConsolidatedBuffs.SetPoint
local original_CB_ClearAllPoints = ConsolidatedBuffs.ClearAllPoints

-- Flag: when true, our SetPoint/ClearAllPoints overrides are active
local buffFramePositionLocked = false

-- Check if buff frame is at default position (not moved by editor)
-- Uses a saved flag instead of coordinate comparison to avoid stale profile values
local function IsBuffFrameAtDefaultPosition()
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.buffs then
        return true  -- safe default: treat as default position
    end
    return not addon.db.profile.widgets.buffs.custom_position
end

-- Check if weapon enchant separation is enabled in the profile
local function IsWeaponEnchantSeparationEnabled()
    return addon.db and addon.db.profile and addon.db.profile.buffs
        and addon.db.profile.buffs.separate_weapon_enchants
end

-- Check if weapon enchant frame is at its default position
local function IsWeaponEnchantAtDefaultPosition()
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets
       or not addon.db.profile.widgets.weapon_enchants then
        return true
    end
    return not addon.db.profile.widgets.weapon_enchants.custom_position
end

local function GetBuffsConfig()
    return addon.db and addon.db.profile and addon.db.profile.buffs
end

local function GetBuffHorizontalGap()
    local cfg = GetBuffsConfig()
    return (cfg and tonumber(cfg.buff_horizontal_gap)) or 0
end

local function GetDebuffHorizontalGap()
    local cfg = GetBuffsConfig()
    return (cfg and tonumber(cfg.debuff_horizontal_gap)) or 0
end

local function GetBuffScale()
    local cfg = GetBuffsConfig()
    local scale = cfg and tonumber(cfg.buff_scale)
    if not scale or scale <= 0 then
        return 1
    end
    return scale
end

local function GetDebuffScale()
    local cfg = GetBuffsConfig()
    local scale = cfg and tonumber(cfg.debuff_scale)
    if not scale or scale <= 0 then
        return 1
    end
    return scale
end

local function GetBuffsPerRow()
    local cfg = GetBuffsConfig()
    local perRow = cfg and tonumber(cfg.buffs_per_row)
    if not perRow or perRow < 1 then
        return BUFFS_PER_ROW or 16
    end
    return math.floor(perRow)
end

local function GetDebuffsPerRow()
    local cfg = GetBuffsConfig()
    local perRow = cfg and tonumber(cfg.debuffs_per_row)
    if not perRow or perRow < 1 then
        return BUFFS_PER_ROW or 16
    end
    return math.floor(perRow)
end

local function GetMaxBuffRows()
    local cfg = GetBuffsConfig()
    local rows = cfg and tonumber(cfg.max_buff_rows)
    if not rows or rows < 0 then
        return 0
    end
    return math.floor(rows)
end

local function GetMaxDebuffRows()
    local cfg = GetBuffsConfig()
    local rows = cfg and tonumber(cfg.max_debuff_rows)
    if not rows or rows < 0 then
        return 0
    end
    return math.floor(rows)
end

local function GetBuffVerticalGap()
    local cfg = GetBuffsConfig()
    local gap = cfg and tonumber(cfg.buff_vertical_gap)
    if gap == nil then
        return 15
    end
    return math.max(0, gap)
end

local function GetDebuffVerticalGap()
    local cfg = GetBuffsConfig()
    local gap = cfg and tonumber(cfg.debuff_vertical_gap)
    if gap == nil then
        return 15
    end
    return math.max(0, gap)
end

local function GetDebuffOffsetY()
    local cfg = GetBuffsConfig()
    local offset = cfg and tonumber(cfg.debuff_offset_y)
    if offset == nil then
        return 60
    end
    return math.max(0, offset)
end

local BUFF_ORDER_BLIZZARD = "blizzard"

local function GetBuffOrder()
    local cfg = GetBuffsConfig()
    local order = cfg and cfg.buff_order
    if order == "player_first" or order == "other_first" or order == "duration" then
        return order
    end
    return BUFF_ORDER_BLIZZARD
end

local function IsPlayerCaster(caster)
    return caster == "player" or caster == "vehicle"
end

local function GetAuraRemaining(expires)
    if not expires or expires <= 0 then
        return 999999
    end
    local remaining = expires - GetTime()
    if remaining < 0 then
        return 0
    end
    return remaining
end

local sortedBuffs = {}
local sortedBuffPool = {}
local sortedBuffOrder = BUFF_ORDER_BLIZZARD
local activeDebuffs = {}
local debuffRowStarts = {}

local function CompareBuffEntries(a, b)
    if sortedBuffOrder == "player_first" then
        if a.isPlayer ~= b.isPlayer then
            return a.isPlayer
        end
    elseif sortedBuffOrder == "other_first" then
        if a.isPlayer ~= b.isPlayer then
            return not a.isPlayer
        end
    end
    if a.remaining ~= b.remaining then
        return a.remaining < b.remaining
    end
    return a.index < b.index
end

-- Runs on every aura update: reuses one scratch list and one entry pool so the
-- layout pass allocates nothing. The two consumers never nest, so sharing is safe.
local function CollectSortedBuffButtons()
    local list = sortedBuffs
    wipe(list)

    sortedBuffOrder = GetBuffOrder()
    local needsAuraData = sortedBuffOrder ~= BUFF_ORDER_BLIZZARD

    local count = 0
    for index = 1, BUFF_ACTUAL_DISPLAY do
        local button = _G["BuffButton" .. index]
        if button and button:IsShown() and not button.consolidated then
            count = count + 1
            local entry = sortedBuffPool[count]
            if not entry then
                entry = {}
                sortedBuffPool[count] = entry
            end

            local auraIndex = button:GetID() or index
            entry.button = button
            entry.index = auraIndex

            if needsAuraData then
                -- Blizzard fills these buttons from PlayerFrame.unit, which is "vehicle" while mounted.
                local unit = button.unit or PlayerFrame.unit or "player"
                local _, _, _, _, _, _, expires, caster = UnitAura(unit, auraIndex, "HELPFUL")
                entry.remaining = GetAuraRemaining(expires)
                entry.isPlayer = IsPlayerCaster(caster)
            else
                entry.remaining = 0
                entry.isPlayer = false
            end

            list[count] = entry
        end
    end

    if needsAuraData then
        table.sort(list, CompareBuffEntries)
    end
    return list
end

local function IsToggleButtonEnabled()
    local cfg = GetBuffsConfig()
    return not cfg or cfg.show_toggle_button ~= false
end

local function GetEnchantSlack()
    if weaponEnchantsAreSeparated then
        return 0
    end
    if not TemporaryEnchantFrame or not TemporaryEnchantFrame:IsShown() then
        return 0
    end
    local enchants = (BuffFrame and BuffFrame.numEnchants) or 0
    if enchants < 0 then
        return 0
    end
    return enchants
end

-- Default weapon enchant frame position
local WEAPON_DEFAULT_ANCHOR = "TOPRIGHT"
local WEAPON_DEFAULT_POSX = -270
local WEAPON_DEFAULT_POSY = -170

-- Debuffs have no fixed default screen position (it's dynamic, below the live
-- buff row), so custom_position is the sole source of truth for detach state.
local function IsDebuffFrameDetached()
    return addon.db and addon.db.profile and addon.db.profile.widgets
        and addon.db.profile.widgets.debuffs
        and addon.db.profile.widgets.debuffs.custom_position == true
end

local function SetBuffsCollapsed(collapsed)
    -- The toggle button is the only way back out, so never stay collapsed without it.
    if collapsed and not IsToggleButtonEnabled() then
        collapsed = false
    end

    buffsHiddenByToggle = collapsed
    if addon.db and addon.db.profile and addon.db.profile.buffs then
        addon.db.profile.buffs.buffs_hidden = collapsed
    end

    if toggleButton then
        toggleButton.toggle = not collapsed
        local atlas = collapsed and 'CollapseButton-Left' or 'CollapseButton-Right'
        local normalTexture = toggleButton:GetNormalTexture()
        if normalTexture then
            normalTexture:set_atlas(atlas, true)
        end
        local highlightTexture = toggleButton:GetHighlightTexture()
        if highlightTexture then
            highlightTexture:set_atlas(atlas, true)
        end
    end

    for index = 1, BUFF_ACTUAL_DISPLAY do
        local button = _G['BuffButton' .. index]
        if button then
            if collapsed then
                button:Hide()
            else
                button:Show()
            end
        end
    end
end

-- Create the collapse/expand toggle button
local function ReplaceBlizzardFrame(frame)
    frame.toggleButton = frame.toggleButton or CreateFrame('Button', nil, UIParent)
    toggleButton = frame.toggleButton
    toggleButton.toggle = true
    toggleButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 12, -6)
    toggleButton:SetSize(9, 17)
    toggleButton:SetHitRectInsets(0, 0, 0, 0)

    local normalTexture = toggleButton:GetNormalTexture() or toggleButton:CreateTexture(nil, "BORDER")
    normalTexture:SetAllPoints(toggleButton)
    normalTexture:set_atlas('CollapseButton-Right', true)
    toggleButton:SetNormalTexture(normalTexture)

    local highlightTexture = toggleButton:GetHighlightTexture() or toggleButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetAllPoints(toggleButton)
    highlightTexture:set_atlas('CollapseButton-Right', true)
    toggleButton:SetHighlightTexture(highlightTexture)

    toggleButton:SetScript("OnClick", function(self)
        SetBuffsCollapsed(self.toggle)
    end)

    local consolidatedBuffFrame = ConsolidatedBuffs
    consolidatedBuffFrame:SetMovable(true)
    consolidatedBuffFrame:SetUserPlaced(true)
    original_CB_ClearAllPoints(consolidatedBuffFrame)
    -- Anchor ConsolidatedBuffs at its natural TOPRIGHT of the buff area so that
    -- the Blizzard anchor chain (ConsolidatedBuffs → TemporaryEnchantFrame →
    -- TempEnchant1/2/3 → BuffButton1) flows correctly.  Use the original
    -- methods since our override may already be active.
    original_CB_SetPoint(consolidatedBuffFrame, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
end

-- Show/hide toggle button based on condition and profile setting
local function ShowToggleButtonIf(condition)
    if not dragonUIBuffFrame or not dragonUIBuffFrame.toggleButton then
        return
    end
    if condition and IsToggleButtonEnabled() then
        dragonUIBuffFrame.toggleButton:Show()
    else
        dragonUIBuffFrame.toggleButton:Hide()
    end
end

-- Tracks the value we last pushed; GetScale() reads back a float and would never compare equal.
local function SetAuraScale(frame, scale)
    if frame.dragonAuraScale ~= scale then
        frame:SetScale(scale)
        frame.dragonAuraScale = scale
    end
end

local function ApplyAuraScales()
    local buffScale = GetBuffScale()
    local debuffScale = GetDebuffScale()

    for index = 1, (BUFF_ACTUAL_DISPLAY or 32) do
        local button = _G["BuffButton" .. index]
        if button then
            SetAuraScale(button, buffScale)
        end
    end

    for index = 1, 3 do
        local enchant = _G["TempEnchant" .. index]
        if enchant then
            SetAuraScale(enchant, buffScale)
        end
    end

    if ConsolidatedBuffs then
        SetAuraScale(ConsolidatedBuffs, buffScale)
    end

    -- Collapses the buff row, so it tracks the buff scale and ignores the debuff one.
    if toggleButton then
        SetAuraScale(toggleButton, buffScale)
    end

    for index = 1, (DEBUFF_MAX_DISPLAY or 16) do
        local debuff = _G["DebuffButton" .. index]
        if debuff then
            SetAuraScale(debuff, debuffScale)
        end
    end
end

-- ============================================================================
-- LAYOUT PREVIEW
-- ============================================================================

local PREVIEW_ICON_SIZE = 30
local PREVIEW_BUFF_TEXTURE = "Interface\\Icons\\Spell_Holy_WordFortitude"
local PREVIEW_DEBUFF_TEXTURE = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth"
local previewBuffButtons = {}
local previewDebuffButtons = {}

local function IsLayoutPreviewEnabled()
    local cfg = GetBuffsConfig()
    return cfg and cfg.layout_preview == true
end

local function GetPreviewBuffCount()
    local cfg = GetBuffsConfig()
    local n = cfg and tonumber(cfg.layout_preview_buffs)
    if not n or n < 0 then
        return 40
    end
    return math.min(64, math.floor(n))
end

local function GetPreviewDebuffCount()
    local cfg = GetBuffsConfig()
    local n = cfg and tonumber(cfg.layout_preview_debuffs)
    if not n or n < 0 then
        return 16
    end
    return math.min(40, math.floor(n))
end

local function AcquirePreviewIcon(pool, index, isDebuff)
    local button = pool[index]
    if not button then
        button = CreateFrame("Frame", nil, UIParent)
        button:SetSize(PREVIEW_ICON_SIZE, PREVIEW_ICON_SIZE)
        button:EnableMouse(false)
        button:SetFrameStrata("HIGH")

        -- Match AuraButtonTemplate: icon on BACKGROUND so auraborders can raise it to BORDER.
        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        icon:SetTexture(isDebuff and PREVIEW_DEBUFF_TEXTURE or PREVIEW_BUFF_TEXTURE)
        button.icon = icon

        if isDebuff then
            local border = button:CreateTexture(nil, "OVERLAY")
            border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
            border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
            border:SetVertexColor(0.8, 0.1, 0.1)
            border:SetSize(33, 32)
            border:SetPoint("CENTER")
            button.Border = border
        end

        local label = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        label:SetPoint("BOTTOMRIGHT", -2, 2)
        button.label = label
        pool[index] = button
    end
    button.label:SetText(tostring(index))
    return button
end

local function HidePreviewPool(pool)
    for _, button in pairs(pool) do
        button:Hide()
        button:ClearAllPoints()
    end
end

local function SetRealAuraButtonsShown(shown)
    for index = 1, (BUFF_MAX_DISPLAY or 40) do
        local button = _G["BuffButton" .. index]
        if button and not shown then
            button:Hide()
        end
    end
    for index = 1, (DEBUFF_MAX_DISPLAY or 16) do
        local button = _G["DebuffButton" .. index]
        if button and not shown then
            button:Hide()
        end
    end
end

local function LayoutPreviewGrid(pool, count, anchorFrame, perRow, hGap, vGap, scale, maxRows, isDebuff)
    if not anchorFrame or count <= 0 then
        HidePreviewPool(pool)
        return nil, nil
    end

    local spacing = 6 + math.max(0, hGap)
    local maxVisible = count
    if maxRows and maxRows > 0 then
        maxVisible = math.min(count, maxRows * perRow)
    end

    local previous = nil
    local rowStarts = {}
    local firstButton = nil
    local lastRowStart = nil
    local poolCount = 0
    for _ in pairs(pool) do
        poolCount = poolCount + 1
    end

    for i = 1, math.max(count, poolCount) do
        if i > count then
            if pool[i] then
                pool[i]:Hide()
                pool[i]:ClearAllPoints()
            end
        else
            local button = AcquirePreviewIcon(pool, i, isDebuff)
            button:SetScale(scale)
            if i > maxVisible then
                button:Hide()
            else
                button:Show()
                local row = math.floor((i - 1) / perRow) + 1
                local column = math.fmod(i - 1, perRow) + 1
                button:ClearAllPoints()
                if i == 1 then
                    button:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", 0, 0)
                    firstButton = button
                    lastRowStart = button
                    rowStarts[row] = button
                elseif column == 1 then
                    local previousRowStart = rowStarts[row - 1] or rowStarts[1] or previous
                    button:SetPoint("TOPRIGHT", previousRowStart, "BOTTOMRIGHT", 0, -vGap)
                    rowStarts[row] = button
                    lastRowStart = button
                else
                    button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -spacing, 0)
                end
                if addon.StyleAuraButton then
                    addon.StyleAuraButton(button, isDebuff)
                end
                previous = button
            end
        end
    end

    return firstButton, lastRowStart
end

function BuffFrameModule:UpdateLayoutPreview()
    if not IsLayoutPreviewEnabled() then
        HidePreviewPool(previewBuffButtons)
        HidePreviewPool(previewDebuffButtons)
        return
    end

    if not dragonUIBuffFrame then
        return
    end

    -- Hide live aura icons so the fake grid is easy to read.
    SetRealAuraButtonsShown(false)

    local buffCount = GetPreviewBuffCount()
    local debuffCount = GetPreviewDebuffCount()
    local firstBuff, lastBuffRow = LayoutPreviewGrid(
        previewBuffButtons,
        buffCount,
        dragonUIBuffFrame,
        GetBuffsPerRow(),
        GetBuffHorizontalGap(),
        GetBuffVerticalGap(),
        GetBuffScale(),
        GetMaxBuffRows(),
        false
    )

    local debuffAnchor = dragonUIDebuffFrame
    if debuffAnchor and not IsDebuffFrameDetached() then
        debuffAnchor:ClearAllPoints()
        local attachTo = lastBuffRow or firstBuff or dragonUIBuffFrame
        debuffAnchor:SetPoint("TOPRIGHT", attachTo, "BOTTOMRIGHT", 0, -GetDebuffOffsetY())
    end

    LayoutPreviewGrid(
        previewDebuffButtons,
        debuffCount,
        debuffAnchor or dragonUIBuffFrame,
        GetDebuffsPerRow(),
        GetDebuffHorizontalGap(),
        GetDebuffVerticalGap(),
        GetDebuffScale(),
        GetMaxDebuffRows(),
        true
    )
end

-- Count active buffs on a unit
local function GetUnitBuffCount(unit, range)
    local count = 0
    for index = 1, range do
        local name = UnitBuff(unit, index)
        if name then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- POSITIONING SYSTEM
-- We permanently override BuffFrame.SetPoint and ClearAllPoints so that
-- NO Blizzard code (BuffFrame_Update, UIParent_ManageFramePositions, etc.)
-- can move BuffFrame. Every SetPoint call on BuffFrame gets redirected to
-- anchor it to our dragonUIBuffFrame. We only touch dragonUIBuffFrame position.
-- ============================================================================

-- Update the position of dragonUIBuffFrame (BuffFrame follows via override)
function BuffFrameModule:UpdatePosition()
    if not dragonUIBuffFrame then return end
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.buffs then
        return
    end
    
    local widgetOptions = addon.db.profile.widgets.buffs
    
    if IsBuffFrameAtDefaultPosition() then
        -- Default position: shift down when ticket/GM panel is open
        local ticketOpen = (TicketStatusFrame and TicketStatusFrame:IsShown())
                        or (GMChatStatusFrame and GMChatStatusFrame:IsShown())
        local posY = ticketOpen and BUFF_TICKET_POSY or BUFF_DEFAULT_POSY
        dragonUIBuffFrame:ClearAllPoints()
        dragonUIBuffFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", BUFF_DEFAULT_POSX, posY)
    else
        -- Custom position (user-placed via editor): use saved coordinates
        dragonUIBuffFrame:ClearAllPoints()
        dragonUIBuffFrame:SetPoint(
            widgetOptions.anchor, UIParent, widgetOptions.anchor,
            widgetOptions.posX, widgetOptions.posY)
    end
end

-- Reset the buff frame back to its default screen position
function BuffFrameModule:ResetBuffFramePosition()
    if addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.buffs then
        local w = addon.db.profile.widgets.buffs
        w.anchor = BUFF_DEFAULT_ANCHOR
        w.posX = BUFF_DEFAULT_POSX
        w.posY = BUFF_DEFAULT_POSY
        w.custom_position = false
    end
    self:UpdatePosition()
end

-- ============================================================================
-- WEAPON ENCHANT SEPARATION SYSTEM
-- Creates an independent moveable frame for TempEnchant1/2/3 (weapon poisons,
-- sharpening stones, etc.), detaching them from the regular buff anchor chain.
-- ============================================================================

-- Update the weapon enchant frame position from saved profile data
function BuffFrameModule:UpdateWeaponEnchantPosition()
    if not dragonUIWeaponBuffFrame then return end
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets
       or not addon.db.profile.widgets.weapon_enchants then return end

    local wOpts = addon.db.profile.widgets.weapon_enchants

    if IsWeaponEnchantAtDefaultPosition() then
        dragonUIWeaponBuffFrame:ClearAllPoints()
        dragonUIWeaponBuffFrame:SetPoint(WEAPON_DEFAULT_ANCHOR, UIParent, "TOPRIGHT",
            WEAPON_DEFAULT_POSX, WEAPON_DEFAULT_POSY)
    else
        dragonUIWeaponBuffFrame:ClearAllPoints()
        dragonUIWeaponBuffFrame:SetPoint(
            wOpts.anchor, UIParent, wOpts.anchor,
            wOpts.posX, wOpts.posY)
    end
end

-- Anchor TemporaryEnchantFrame to our weapon enchant frame
local function AnchorWeaponEnchantsToFrame()
    if not TemporaryEnchantFrame or not dragonUIWeaponBuffFrame then return end
    TemporaryEnchantFrame:ClearAllPoints()
    TemporaryEnchantFrame:SetPoint("TOPRIGHT", dragonUIWeaponBuffFrame, "TOPRIGHT", 0, 0)
end

-- Restore TemporaryEnchantFrame to the normal buff chain
local function RestoreWeaponEnchantsToChain()
    if not TemporaryEnchantFrame then return end
    local cb = _G.ConsolidatedBuffs
    if cb then
        TemporaryEnchantFrame:ClearAllPoints()
        if cb:IsShown() then
            TemporaryEnchantFrame:SetPoint("TOPRIGHT", cb, "TOPLEFT", -6, 0)
        else
            TemporaryEnchantFrame:SetPoint("TOPRIGHT", cb, "TOPRIGHT", 0, 0)
        end
    end
end

-- Create (or show) the weapon enchant anchor frame and register with editor.
-- Called from Enable() and from the runtime toggle.
function BuffFrameModule:SetupWeaponEnchantSeparation()
    if not IsWeaponEnchantSeparationEnabled() then
        -- Feature disabled — make sure runtime flag is off and clean up
        if weaponEnchantsAreSeparated then
            weaponEnchantsAreSeparated = false
            RestoreWeaponEnchantsToChain()
            if dragonUIWeaponBuffFrame then
                dragonUIWeaponBuffFrame:Hide()
            end
        end
        return
    end

    weaponEnchantsAreSeparated = true

    -- Create the frame once
    if not dragonUIWeaponBuffFrame then
        -- Size matches roughly 3 temp enchant icons (30px each + spacing)
        dragonUIWeaponBuffFrame = addon.CreateUIFrame(100, 34, "WeaponEnchants")

        addon:RegisterEditableFrame({
            name = "weapon_enchants",
            frame = dragonUIWeaponBuffFrame,
            blizzardFrame = TemporaryEnchantFrame,
            configPath = {"widgets", "weapon_enchants"},
            onHide = function()
                -- After editor saves, check if position matches the default
                local w = addon.db.profile.widgets.weapon_enchants
                if w then
                    local isDefault = w.anchor == WEAPON_DEFAULT_ANCHOR
                        and math.abs(w.posX - WEAPON_DEFAULT_POSX) <= 5
                        and math.abs(w.posY - WEAPON_DEFAULT_POSY) <= 5
                    w.custom_position = not isDefault
                end
                self:UpdateWeaponEnchantPosition()
                AnchorWeaponEnchantsToFrame()
            end,
            module = self
        })
    end

    dragonUIWeaponBuffFrame:Show()
    self:UpdateWeaponEnchantPosition()
    AnchorWeaponEnchantsToFrame()
end

-- Runtime toggle: switch weapon enchant separation on/off without reload
function BuffFrameModule:ToggleWeaponEnchantSeparation(enabled)
    if not addon.db or not addon.db.profile or not addon.db.profile.buffs then return end
    addon.db.profile.buffs.separate_weapon_enchants = enabled
    self:SetupWeaponEnchantSeparation()
    -- Force a buff layout refresh so the anchor chain updates immediately
    if BuffFrame_UpdateAllBuffAnchors then
        BuffFrame_UpdateAllBuffAnchors()
    end
end

-- Reset the debuff mover back to following the buff row (attached/default)
function BuffFrameModule:ResetDebuffPosition()
    if addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.debuffs then
        addon.db.profile.widgets.debuffs.custom_position = false
    end
    if self._FixDebuffPositions then
        self._FixDebuffPositions()
    end
end

-- Toggle module on/off
function BuffFrameModule:Toggle(enabled)
    if not addon.db or not addon.db.profile then return end
    
    addon.db.profile.buffs.enabled = enabled
    
    if enabled then
        self:Enable()
    else
        if addon:ShouldDeferModuleDisable("buffs", self) then
            return
        end
        self:Disable()
    end
end

-- Enable the buff frame module
function BuffFrameModule:Enable()
    if not addon.db.profile.buffs.enabled then return end
    
    -- Create auxiliary frame for editor mode
    dragonUIBuffFrame = addon.CreateUIFrame(BuffFrame:GetWidth(), BuffFrame:GetHeight(), "Buff")
    
    -- Register with editor system
    addon:RegisterEditableFrame({
        name = "buffs",
        frame = dragonUIBuffFrame,
        blizzardFrame = BuffFrame,
        configPath = {"widgets", "buffs"},
        onHide = function()
            -- Compare against the ticket-shifted Y when a ticket/GM panel is open,
            -- else editor open/close while one is up wrongly marks it as custom.
            local w = addon.db.profile.widgets.buffs
            local ticketOpen = (TicketStatusFrame and TicketStatusFrame:IsShown())
                            or (GMChatStatusFrame and GMChatStatusFrame:IsShown())
            local expectedPosY = ticketOpen and BUFF_TICKET_POSY or BUFF_DEFAULT_POSY
            local isDefault = w.anchor == BUFF_DEFAULT_ANCHOR
                and math.abs(w.posX - BUFF_DEFAULT_POSX) <= 5
                and math.abs(w.posY - expectedPosY) <= 5
            w.custom_position = not isDefault
            self:UpdatePosition()
        end,
        module = self
    })

    -- Flip to custom position immediately on drag (not deferred to onHide) so
    -- the editor panel's "Click to reset" button appears right away.
    do
        local originalBuffDragStart = dragonUIBuffFrame:GetScript("OnDragStart")
        dragonUIBuffFrame:SetScript("OnDragStart", function(movFrame, button)
            if originalBuffDragStart then
                originalBuffDragStart(movFrame, button)
            end
            local w = addon.db.profile.widgets.buffs
            if w and not w.custom_position then
                w.custom_position = true
            end
        end)
    end

    -- Real body assigned further down (needs GetBuffLayoutInfo); forward
    -- declared here so the Debuffs mover's editor hooks can call it via upvalue.
    local FixDebuffPositions

    -- ========================================================================
    -- DEBUFF INDEPENDENT POSITIONING (Editor Mode)
    -- Debuffs follow the buff row by default (unchanged). Dragging this mover
    -- detaches it immediately; Reset re-anchors it to the default offset.
    -- ========================================================================
    do
        dragonUIDebuffFrame = addon.CreateUIFrame(BuffFrame:GetWidth(), BuffFrame:GetHeight(), "Debuffs")

        addon:RegisterEditableFrame({
            name = "Debuffs",
            frame = dragonUIDebuffFrame,
            blizzardFrame = _G["DebuffButton1"],
            configPath = {"widgets", "debuffs"},
            onHide = function()
                if FixDebuffPositions then FixDebuffPositions() end
            end,
            module = self
        })

        local originalDebuffDragStart = dragonUIDebuffFrame:GetScript("OnDragStart")
        dragonUIDebuffFrame:SetScript("OnDragStart", function(movFrame, button)
            if not IsDebuffFrameDetached() then
                -- Attached anchor is relative to a transient buff button, not
                -- UIParent — snap to a UIParent-relative point before the drag.
                local cx, cy = dragonUIDebuffFrame:GetCenter()
                local ux, uy = UIParent:GetCenter()
                if cx and cy and ux and uy then
                    dragonUIDebuffFrame:ClearAllPoints()
                    dragonUIDebuffFrame:SetPoint("CENTER", UIParent, "CENTER", cx - ux, cy - uy)
                end
            end
            if originalDebuffDragStart then
                originalDebuffDragStart(movFrame, button)
            end
            local w = addon.db.profile.widgets.debuffs
            if w and not w.custom_position then
                w.custom_position = true
            end
        end)

        dragonUIDebuffFrame:HookScript("OnDragStop", function()
            if FixDebuffPositions then FixDebuffPositions() end
        end)
    end

    -- ========================================================================
    -- WEAPON ENCHANT SEPARATION (FEATURE)
    -- When enabled, weapon enchant icons (TempEnchant1/2/3) are detached from
    -- the regular buff chain and anchored to their own independently-moveable
    -- frame.  The editor mode system lets users position it freely.
    -- ========================================================================
    self:SetupWeaponEnchantSeparation()
    
    -- PERMANENTLY OVERRIDE BuffFrame positioning methods.
    -- Every call to BuffFrame:SetPoint() from ANY code path (BuffFrame_Update,
    -- UIParent_ManageFramePositions, etc.) gets redirected to anchor BuffFrame
    -- to our dragonUIBuffFrame. This is the ONLY reliable way to prevent
    -- Blizzard from moving the buff icons.
    buffFramePositionLocked = true
    
    BuffFrame.ClearAllPoints = function(self)
        -- Noop: don't let anyone clear BuffFrame's anchor.
        -- Our SetPoint override handles re-anchoring when needed.
    end
    
    BuffFrame.SetPoint = function(self, ...)
        -- ALWAYS redirect: anchor BuffFrame to our controlled frame
        if not buffFramePositionLocked or not dragonUIBuffFrame then
            -- Module disabled or not ready: use original
            return original_BuffFrame_SetPoint(self, ...)
        end
        -- Redirect to our frame
        original_BuffFrame_ClearAllPoints(self)
        original_BuffFrame_SetPoint(self, "TOPRIGHT", dragonUIBuffFrame, "TOPRIGHT", 0, 0)
        -- DON'T call UpdatePosition() here - it would reset dragonUIBuffFrame
        -- position during editor drag. UpdatePosition is called on events instead.
    end
    
    -- PERMANENTLY OVERRIDE ConsolidatedBuffs positioning methods.
    -- Same pattern as BuffFrame above: ConsolidatedBuffs is the ROOT of the
    -- buff icon anchor chain (CB → TemporaryEnchantFrame → BuffButton1 → …).
    -- Without this lock, Blizzard re-anchors CB on ticket open/close, pulling
    -- the entire buff chain to the wrong position even though dragonUIBuffFrame
    -- (and the toggle button) stay put.
    ConsolidatedBuffs.ClearAllPoints = function(self)
        if not buffFramePositionLocked or not dragonUIBuffFrame then
            return original_CB_ClearAllPoints(self)
        end
        -- Noop when locked
    end
    
    ConsolidatedBuffs.SetPoint = function(self, ...)
        if not buffFramePositionLocked or not dragonUIBuffFrame then
            return original_CB_SetPoint(self, ...)
        end
        original_CB_ClearAllPoints(self)
        original_CB_SetPoint(self, "TOPRIGHT", dragonUIBuffFrame, "TOPRIGHT", 0, 0)
    end
    
    -- Set initial position: anchor BuffFrame and ConsolidatedBuffs to our frame
    original_BuffFrame_ClearAllPoints(BuffFrame)
    original_BuffFrame_SetPoint(BuffFrame, "TOPRIGHT", dragonUIBuffFrame, "TOPRIGHT", 0, 0)
    original_CB_ClearAllPoints(ConsolidatedBuffs)
    original_CB_SetPoint(ConsolidatedBuffs, "TOPRIGHT", dragonUIBuffFrame, "TOPRIGHT", 0, 0)
    BuffFrameModule:UpdatePosition()
    
    -- ========================================================================
    -- HELPER: Find buff layout info (first buff, last-row-start buff, row count)
    -- Used by both buff row-2 fix and debuff anchoring.
    -- ========================================================================
    local function GetBuffLayoutInfo()
        local slack = GetEnchantSlack()
        local perRow = GetBuffsPerRow()
        local sorted = CollectSortedBuffButtons()
        local firstBuff = nil
        local lastRowStart = nil
        local numVisible = #sorted
        for i, entry in ipairs(sorted) do
            local button = entry.button
            if i == 1 then
                firstBuff = button
                lastRowStart = button
            end
            local layoutIndex = i + slack
            if layoutIndex > 1 and math.fmod(layoutIndex, perRow) == 1 then
                lastRowStart = button
            end
        end

        -- When Consolidated Buffs is on, many (or all) icons live in that button.
        -- With no visible BuffButtons, anchor debuffs below ConsolidatedBuffs /
        -- weapon enchants instead of the empty mover frame.
        if not firstBuff then
            if ConsolidatedBuffs and ConsolidatedBuffs:IsShown() then
                firstBuff = ConsolidatedBuffs
                lastRowStart = ConsolidatedBuffs
            elseif not weaponEnchantsAreSeparated
                and TemporaryEnchantFrame and TemporaryEnchantFrame:IsShown() then
                firstBuff = TemporaryEnchantFrame
                lastRowStart = TemporaryEnchantFrame
            end
        end

        return firstBuff, lastRowStart, numVisible
    end

    -- ========================================================================
    -- HELPER: Re-anchor ConsolidatedBuffs to our toggle button.
    -- Blizzard code (UIParent_ManageFramePositions, etc.) may reposition
    -- ConsolidatedBuffs; this restores our custom placement.
    -- ========================================================================
    local function RestoreConsolidatedBuffsAnchor()
        local cb = _G.ConsolidatedBuffs
        if cb and dragonUIBuffFrame then
            original_CB_ClearAllPoints(cb)
            original_CB_SetPoint(cb, "TOPRIGHT", dragonUIBuffFrame, "TOPRIGHT", 0, 0)
        end
        -- When weapon enchants are separated, TemporaryEnchantFrame is managed
        -- by the weapon enchant system — do NOT re-anchor it to ConsolidatedBuffs.
        if weaponEnchantsAreSeparated then return end
        -- Also ensure TemporaryEnchantFrame follows ConsolidatedBuffs correctly
        if TemporaryEnchantFrame and cb then
            TemporaryEnchantFrame:ClearAllPoints()
            if cb:IsShown() then
                TemporaryEnchantFrame:SetPoint("TOPRIGHT", cb, "TOPLEFT", -6, 0)
            else
                TemporaryEnchantFrame:SetPoint("TOPRIGHT", cb, "TOPRIGHT", 0, 0)
            end
        end
    end

    -- ========================================================================
    -- HELPER: Position the debuff mover (attached: dynamic below the last buff
    -- row; detached: from saved profile coords), then anchor the real debuff
    -- icon to the mover so it always follows whichever mode is active.
    -- ========================================================================
    FixDebuffPositions = function()
        if not buffFramePositionLocked or not dragonUIDebuffFrame then return end

        local debuffOffsetY = GetDebuffOffsetY()

        if IsDebuffFrameDetached() then
            local w = addon.db.profile.widgets.debuffs
            dragonUIDebuffFrame:ClearAllPoints()
            dragonUIDebuffFrame:SetPoint(w.anchor or "TOPRIGHT", UIParent, w.anchor or "TOPRIGHT",
                w.posX or -270, w.posY or -75)
        else
            local firstBuff, lastRowStart = GetBuffLayoutInfo()
            local anchor = lastRowStart or firstBuff
            if not anchor and ConsolidatedBuffs and ConsolidatedBuffs:IsShown() then
                anchor = ConsolidatedBuffs
            end
            dragonUIDebuffFrame:ClearAllPoints()
            if anchor then
                dragonUIDebuffFrame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -debuffOffsetY)
            else
                -- No buffs / consolidated button visible — below the buff mover
                dragonUIDebuffFrame:SetPoint("TOPRIGHT", dragonUIBuffFrame, "BOTTOMRIGHT", 0, -debuffOffsetY)
            end
        end

        -- Collect active debuffs first, then lay them out with OUR per-row setting.
        -- Blizzard's DebuffButton_UpdateAnchors uses BUFFS_PER_ROW and would
        -- otherwise overwrite any independent debuffs_per_row value.
        local active = activeDebuffs
        wipe(active)
        local activeCount = 0
        for index = 1, (DEBUFF_MAX_DISPLAY or 16) do
            local debuff = _G["DebuffButton" .. index]
            if debuff and debuff:IsShown() then
                activeCount = activeCount + 1
                active[activeCount] = debuff
            end
        end

        if activeCount == 0 then
            return
        end

        local firstDebuff = active[1]
        firstDebuff:ClearAllPoints()
        firstDebuff:SetPoint("TOPRIGHT", dragonUIDebuffFrame, "TOPRIGHT", 0, 0)

        local perRow = GetDebuffsPerRow()
        local spacing = 6 + math.max(0, GetDebuffHorizontalGap())
        local vGap = GetDebuffVerticalGap()
        local maxRows = GetMaxDebuffRows()
        local maxVisible = (maxRows > 0) and (maxRows * perRow) or activeCount
        local previousDebuff = nil
        local rowStarts = debuffRowStarts
        wipe(rowStarts)

        for count, debuff in ipairs(active) do
            if count > maxVisible then
                debuff:Hide()
            else
                local row = math.floor((count - 1) / perRow) + 1
                local column = math.fmod(count - 1, perRow) + 1

                if count == 1 then
                    rowStarts[row] = debuff
                elseif column == 1 then
                    local previousRowStart = rowStarts[row - 1] or rowStarts[1] or previousDebuff
                    if previousRowStart then
                        debuff:ClearAllPoints()
                        debuff:SetPoint("TOPRIGHT", previousRowStart, "BOTTOMRIGHT", 0, -vGap)
                    end
                    rowStarts[row] = debuff
                elseif previousDebuff then
                    debuff:ClearAllPoints()
                    debuff:SetPoint("TOPRIGHT", previousDebuff, "TOPLEFT", -spacing, 0)
                end

                previousDebuff = debuff
            end
        end
    end
    BuffFrameModule._FixDebuffPositions = FixDebuffPositions

    local function AnchorFirstBuff(button, slack)
        if weaponEnchantsAreSeparated and ConsolidatedBuffs then
            button:ClearAllPoints()
            if ConsolidatedBuffs:IsShown() then
                button:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -6, 0)
            else
                button:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
            end
            return
        end

        if slack > 0 then
            local lastEnchant = _G["TempEnchant" .. slack]
            if lastEnchant and lastEnchant:IsShown() then
                button:ClearAllPoints()
                button:SetPoint("TOPRIGHT", lastEnchant, "TOPLEFT", -6, 0)
                return
            end
        end

        if ConsolidatedBuffs then
            button:ClearAllPoints()
            if ConsolidatedBuffs:IsShown() then
                button:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -6, 0)
            else
                button:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
            end
        end
    end

    local buffRowStarts = {}

    local function ReanchorBuffButtons()
        local buffGap = GetBuffHorizontalGap()
        local perRow = GetBuffsPerRow()
        local slack = GetEnchantSlack()
        local vGap = GetBuffVerticalGap()
        local maxRows = GetMaxBuffRows()
        local maxVisible = nil
        if maxRows > 0 then
            maxVisible = math.max(0, maxRows * perRow - slack)
        end
        local previousBuff = nil
        local rowStarts = buffRowStarts
        wipe(rowStarts)
        local spacing = 6 + math.max(0, buffGap)
        local sorted = CollectSortedBuffButtons()

        for count, entry in ipairs(sorted) do
            local button = entry.button

            if maxVisible and count > maxVisible then
                button:Hide()
            else
                local layoutIndex = count + slack
                local row = math.floor((layoutIndex - 1) / perRow) + 1
                local column = math.fmod(layoutIndex - 1, perRow) + 1

                if count == 1 then
                    AnchorFirstBuff(button, slack)
                    rowStarts[row] = button
                elseif column == 1 then
                    local previousRowStart = rowStarts[row - 1] or rowStarts[1] or previousBuff
                    if previousRowStart then
                        button:ClearAllPoints()
                        button:SetPoint("TOPRIGHT", previousRowStart, "BOTTOMRIGHT", 0, -vGap)
                    end
                    rowStarts[row] = button
                elseif previousBuff then
                    button:ClearAllPoints()
                    button:SetPoint("TOPRIGHT", previousBuff, "TOPLEFT", -spacing, 0)
                end

                previousBuff = button
            end
        end
    end

    function BuffFrameModule:RefreshAuraSpacing()
        -- Must run first: it can expand the bar, and the layout pass below re-applies row caps.
        self:UpdateToggleButtonVisibility()
        ApplyAuraScales()
        -- Full update re-shows buttons previously hidden by max-row caps.
        if BuffFrame_Update then
            BuffFrame_Update()
        elseif BuffFrame_UpdateAllBuffAnchors then
            BuffFrame_UpdateAllBuffAnchors()
            FixDebuffPositions()
        else
            FixDebuffPositions()
        end
        self:UpdatePosition()
        self:UpdateLayoutPreview()
    end

    function BuffFrameModule:UpdateToggleButtonVisibility()
        if buffsHiddenByToggle and not IsToggleButtonEnabled() then
            SetBuffsCollapsed(false)
        end
        local hasBuffs = GetUnitBuffCount("player", 16) > 0
        if not hasBuffs and UnitExists and UnitExists("vehicle") then
            hasBuffs = GetUnitBuffCount("vehicle", 16) > 0
        end
        ShowToggleButtonIf(hasBuffs)
    end

    -- ========================================================================
    -- HOOK: BuffFrame_UpdateAllBuffAnchors — ensure the Blizzard anchor chain
    --   ConsolidatedBuffs → TemporaryEnchantFrame → BuffButton1 → …
    -- stays consistent after Blizzard repositions everything.
    -- Also fixes row-2 alignment and respects the buff toggle state.
    -- ========================================================================
    if not BuffFrameModule._hookedBuffAnchors then
        BuffFrameModule._hookedBuffAnchors = true
        hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", function()
            if not buffFramePositionLocked then return end

            -- 1) Re-anchor TemporaryEnchantFrame (weapon enchants: poisons,
            --    sharpening stones, etc.) to follow ConsolidatedBuffs.
            --    Blizzard's ConsolidatedBuffs OnShow/OnHide handlers set this,
            --    but other code paths may move it; force it every update.
            --    SKIP this when weapon enchants are separated — they have
            --    their own independent anchor managed by the weapon frame.
            if not weaponEnchantsAreSeparated then
                if TemporaryEnchantFrame and ConsolidatedBuffs then
                    TemporaryEnchantFrame:ClearAllPoints()
                    if ConsolidatedBuffs:IsShown() then
                        TemporaryEnchantFrame:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -6, 0)
                    else
                        TemporaryEnchantFrame:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
                    end
                end
            end

            -- 2) Rebuild the visible buff grid every update to avoid stale
            --    anchors from Blizzard or external addons leaving asymmetric rows.
            ApplyAuraScales()
            ReanchorBuffButtons()

            -- 3) Respect buff toggle: re-hide buffs if user collapsed them
            if buffsHiddenByToggle then
                for i = 1, BUFF_ACTUAL_DISPLAY do
                    local btn = _G["BuffButton" .. i]
                    if btn then
                        btn:Hide()
                    end
                end
            end

            -- Debuffs must follow the latest buff / consolidated layout.
            FixDebuffPositions()
            BuffFrameModule:UpdateLayoutPreview()
        end)
    end

    -- ========================================================================
    -- HOOK: DebuffButton_UpdateAnchors — fix debuff positioning
    -- Blizzard anchors the first debuff to ConsolidatedBuffs BOTTOMRIGHT and
    -- wraps later icons with BUFFS_PER_ROW. We defer one frame so our full
    -- grid (using debuffs_per_row) runs AFTER Blizzard finishes the whole pass.
    -- ========================================================================
    if not BuffFrameModule._hookedDebuffAnchors then
        BuffFrameModule._hookedDebuffAnchors = true
        local debuffFixPending = false
        local debuffFixFrame = CreateFrame("Frame")
        debuffFixFrame:Hide()
        debuffFixFrame:SetScript("OnUpdate", function(self)
            self:Hide()
            debuffFixPending = false
            if not buffFramePositionLocked then return end
            ApplyAuraScales()
            FixDebuffPositions()
            BuffFrameModule:UpdateLayoutPreview()
        end)

        hooksecurefunc("DebuffButton_UpdateAnchors", function()
            if not buffFramePositionLocked then return end
            if debuffFixPending then return end
            debuffFixPending = true
            debuffFixFrame:Show()
        end)
    end

    -- ========================================================================
    -- HOOK: UIParent_ManageFramePositions — fires on ticket open/close.
    -- We update our frame position AND re-anchor ConsolidatedBuffs + debuffs
    -- so nothing drifts horizontally.
    -- ========================================================================
    if not BuffFrameModule._hookedManagePositions then
        BuffFrameModule._hookedManagePositions = true
        hooksecurefunc("UIParent_ManageFramePositions", function()
            if not dragonUIBuffFrame then return end
            if not addon.db or not addon.db.profile or not addon.db.profile.buffs
               or not addon.db.profile.buffs.enabled then return end
            -- UpdatePosition() is safe at ANY position: at default it shifts
            -- for tickets, at custom it re-applies the saved coords (no-op).
            BuffFrameModule:UpdatePosition()
            -- ALWAYS restore the anchor chain — Blizzard's code may have
            -- re-anchored ConsolidatedBuffs/TemporaryEnchantFrame away from
            -- our frame.  These helpers only fix the chain, they never move
            -- dragonUIBuffFrame itself, so they're safe at custom position.
            RestoreConsolidatedBuffsAnchor()
            FixDebuffPositions()
        end)
    end
    
    -- Also hook TicketStatusFrame Show/Hide directly for reliable detection
    if not BuffFrameModule._hookedTicketFrame then
        BuffFrameModule._hookedTicketFrame = true
        if TicketStatusFrame then
            hooksecurefunc(TicketStatusFrame, "Show", function()
                if dragonUIBuffFrame and IsBuffFrameAtDefaultPosition() then
                    BuffFrameModule:UpdatePosition()
                    RestoreConsolidatedBuffsAnchor()
                    FixDebuffPositions()
                end
            end)
            hooksecurefunc(TicketStatusFrame, "Hide", function()
                if dragonUIBuffFrame and IsBuffFrameAtDefaultPosition() then
                    BuffFrameModule:UpdatePosition()
                    RestoreConsolidatedBuffsAnchor()
                    FixDebuffPositions()
                end
            end)
        end
        if GMChatStatusFrame then
            hooksecurefunc(GMChatStatusFrame, "Show", function()
                if dragonUIBuffFrame and IsBuffFrameAtDefaultPosition() then
                    BuffFrameModule:UpdatePosition()
                    RestoreConsolidatedBuffsAnchor()
                    FixDebuffPositions()
                end
            end)
            hooksecurefunc(GMChatStatusFrame, "Hide", function()
                if dragonUIBuffFrame and IsBuffFrameAtDefaultPosition() then
                    BuffFrameModule:UpdatePosition()
                    RestoreConsolidatedBuffsAnchor()
                    FixDebuffPositions()
                end
            end)
        end
    end
    
    --  CONFIGURE EVENTS
    if not buffFrame then
        buffFrame = CreateFrame("Frame")
        buffFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        addon.RegisterUnitEventSafe(buffFrame, "UNIT_AURA", "player", "vehicle")
        buffFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        buffFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
        
        buffFrame:SetScript("OnEvent", function(self, event, unit)
            if event == "PLAYER_ENTERING_WORLD" then
                ReplaceBlizzardFrame(dragonUIBuffFrame)
                ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                BuffFrameModule:UpdatePosition()
                
                -- Restore buff toggle state from saved profile
                if addon.db and addon.db.profile and addon.db.profile.buffs
                   and addon.db.profile.buffs.buffs_hidden then
                    SetBuffsCollapsed(true)
                end
                
                -- Reposition the GM ticket frame so it doesn't overlap the minimap
                if TicketStatusFrame then
                    TicketStatusFrame:ClearAllPoints()
                    TicketStatusFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -270, -5)
                end
            elseif event == "UNIT_AURA" then
                if unit == 'vehicle' then
                    ShowToggleButtonIf(GetUnitBuffCount("vehicle", 16) > 0)
                elseif unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                end
            elseif event == "UNIT_ENTERED_VEHICLE" then
                if unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("vehicle", 16) > 0)
                end
            elseif event == "UNIT_EXITED_VEHICLE" then
                if unit == 'player' then
                    ShowToggleButtonIf(GetUnitBuffCount("player", 16) > 0)
                end
            end
        end)
    end
end

-- Disable the buff frame module
function BuffFrameModule:Disable()
    HidePreviewPool(previewBuffButtons)
    HidePreviewPool(previewDebuffButtons)

    -- Restore original BuffFrame and ConsolidatedBuffs positioning methods
    buffFramePositionLocked = false
    BuffFrame.SetPoint = original_BuffFrame_SetPoint
    BuffFrame.ClearAllPoints = original_BuffFrame_ClearAllPoints
    ConsolidatedBuffs.SetPoint = original_CB_SetPoint
    ConsolidatedBuffs.ClearAllPoints = original_CB_ClearAllPoints
    
    -- Clean up weapon enchant separation
    if weaponEnchantsAreSeparated then
        weaponEnchantsAreSeparated = false
        RestoreWeaponEnchantsToChain()
    end
    if dragonUIWeaponBuffFrame then
        dragonUIWeaponBuffFrame:Hide()
        -- Don't nil it — may be re-enabled without reload
    end
    
    if buffFrame then
        buffFrame:UnregisterAllEvents()
        buffFrame:SetScript("OnEvent", nil)
        buffFrame = nil
    end
    
    if toggleButton then
        toggleButton:Hide()
        toggleButton = nil
    end
    
    if dragonUIBuffFrame then
        dragonUIBuffFrame:Hide()
        dragonUIBuffFrame = nil
    end

    if dragonUIDebuffFrame then
        dragonUIDebuffFrame:Hide()
        dragonUIDebuffFrame = nil
    end
end

-- Initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        if addon.db and addon.db.profile and addon.db.profile.buffs then
            -- Preview hides every real aura; carrying it across sessions looks like a broken UI.
            addon.db.profile.buffs.layout_preview = false
            if addon.db.profile.buffs.enabled then
                BuffFrameModule:Enable()
            end
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Refresh callback for options panel
function addon:RefreshBuffFrame()
    if BuffFrameModule and addon.db.profile.buffs.enabled then
        BuffFrameModule:UpdatePosition()
    end
end