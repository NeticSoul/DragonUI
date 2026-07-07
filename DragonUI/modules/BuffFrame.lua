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
        (addon.L and addon.L["Buff Frame"]) or "Buff Frame",
        (addon.L and addon.L["Custom buff frame styling, positioning and toggle button"]) or "Custom buff frame styling, positioning and toggle button")
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

local function GetBuffHorizontalGap()
    local cfg = addon.db and addon.db.profile and addon.db.profile.buffs
    return (cfg and tonumber(cfg.buff_horizontal_gap)) or 0
end

local function GetDebuffHorizontalGap()
    local cfg = addon.db and addon.db.profile and addon.db.profile.buffs
    return (cfg and tonumber(cfg.debuff_horizontal_gap)) or 0
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
        self.toggle = not self.toggle
        if not self.toggle then
            -- HIDE buffs
            buffsHiddenByToggle = true
            if addon.db and addon.db.profile and addon.db.profile.buffs then
                addon.db.profile.buffs.buffs_hidden = true
            end
            local normalTexture = self:GetNormalTexture()
            normalTexture:set_atlas('CollapseButton-Left', true)
            local highlightTexture = toggleButton:GetHighlightTexture()
            highlightTexture:set_atlas('CollapseButton-Left', true)

            for index = 1, BUFF_ACTUAL_DISPLAY do
                local button = _G['BuffButton' .. index]
                if button then
                    button:Hide()
                end
            end
        else
            -- SHOW buffs
            buffsHiddenByToggle = false
            if addon.db and addon.db.profile and addon.db.profile.buffs then
                addon.db.profile.buffs.buffs_hidden = false
            end
            local normalTexture = self:GetNormalTexture()
            normalTexture:set_atlas('CollapseButton-Right', true)
            local highlightTexture = toggleButton:GetHighlightTexture()
            highlightTexture:set_atlas('CollapseButton-Right', true)

            for index = 1, BUFF_ACTUAL_DISPLAY do
                local button = _G['BuffButton' .. index]
                if button then
                    button:Show()
                end
            end
        end
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

-- Show/hide toggle button based on condition
local function ShowToggleButtonIf(condition)
    if condition then
        dragonUIBuffFrame.toggleButton:Show()
    else
        dragonUIBuffFrame.toggleButton:Hide()
    end
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
        -- Only reserve slots when enchants are currently visible in the chain.
        local slack = GetEnchantSlack()
        local perRow = BUFFS_PER_ROW or 16
        local firstBuff = nil
        local lastRowStart = nil
        local numVisible = 0
        for i = 1, BUFF_ACTUAL_DISPLAY do
            local btn = _G["BuffButton" .. i]
            if btn and btn:IsShown() and not btn.consolidated then
                numVisible = numVisible + 1
                if numVisible == 1 then
                    firstBuff = btn
                    lastRowStart = btn
                end
                local idx = numVisible + slack
                if idx > 1 and math.fmod(idx, perRow) == 1 then
                    lastRowStart = btn  -- first buff of a new row
                end
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

        if IsDebuffFrameDetached() then
            local w = addon.db.profile.widgets.debuffs
            dragonUIDebuffFrame:ClearAllPoints()
            dragonUIDebuffFrame:SetPoint(w.anchor or "TOPRIGHT", UIParent, w.anchor or "TOPRIGHT",
                w.posX or -270, w.posY or -75)
        else
            local firstBuff, lastRowStart = GetBuffLayoutInfo()
            local anchor = lastRowStart or firstBuff
            dragonUIDebuffFrame:ClearAllPoints()
            if anchor then
                dragonUIDebuffFrame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -60)
            else
                -- No buffs visible — anchor directly below the buff frame
                dragonUIDebuffFrame:SetPoint("TOPRIGHT", dragonUIBuffFrame, "BOTTOMRIGHT", 0, -60)
            end
        end

        local firstDebuff = _G["DebuffButton1"]
        if firstDebuff then
            firstDebuff:ClearAllPoints()
            firstDebuff:SetPoint("TOPRIGHT", dragonUIDebuffFrame, "TOPRIGHT", 0, 0)

            local debuffGap = GetDebuffHorizontalGap()
            if debuffGap > 0 then
                local previousDebuff = firstDebuff
                for index = 2, (DEBUFF_MAX_DISPLAY or 16) do
                    local debuff = _G["DebuffButton" .. index]
                    if debuff and debuff:IsShown() then
                        debuff:ClearAllPoints()
                        debuff:SetPoint("TOPRIGHT", previousDebuff, "TOPLEFT", -(6 + debuffGap), 0)
                        previousDebuff = debuff
                    end
                end
            end
        end
    end
    BuffFrameModule._FixDebuffPositions = FixDebuffPositions

    local function ReanchorBuffButtons()
        local buffGap = GetBuffHorizontalGap()
        local perRow = BUFFS_PER_ROW or 16
        local slack = GetEnchantSlack()
        local count = 0
        local previousBuff = nil
        local rowStarts = {}
        local spacing = 6 + math.max(0, buffGap)

        local function AnchorFirstBuff(button)
            if weaponEnchantsAreSeparated and ConsolidatedBuffs then
                button:ClearAllPoints()
                if ConsolidatedBuffs:IsShown() then
                    button:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -6, 0)
                else
                    button:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
                end
                return
            end

            local visibleEnchants = slack
            if visibleEnchants > 0 then
                local lastEnchant = _G["TempEnchant" .. visibleEnchants]
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

        for index = 1, BUFF_ACTUAL_DISPLAY do
            local button = _G["BuffButton" .. index]
            if button and button:IsShown() and not button.consolidated then
                count = count + 1
                local layoutIndex = count + slack
                local row = math.floor((layoutIndex - 1) / perRow) + 1
                local column = math.fmod(layoutIndex - 1, perRow) + 1

                if count == 1 then
                    AnchorFirstBuff(button)
                    rowStarts[row] = button
                elseif column == 1 then
                    local previousRowStart = rowStarts[row - 1] or rowStarts[1] or previousBuff
                    if previousRowStart then
                        button:ClearAllPoints()
                        button:SetPoint("TOPRIGHT", previousRowStart, "BOTTOMRIGHT", 0, -15)
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
        if BuffFrame_UpdateAllBuffAnchors then
            BuffFrame_UpdateAllBuffAnchors()
        end
        self:UpdatePosition()
        FixDebuffPositions()
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
        end)
    end

    -- ========================================================================
    -- HOOK: DebuffButton_UpdateAnchors — fix debuff positioning
    -- Blizzard anchors the first debuff to ConsolidatedBuffs BOTTOMRIGHT.
    -- Since we moved ConsolidatedBuffs, debuffs end up too far right.
    -- This hook re-anchors the first debuff below the last buff row.
    -- ========================================================================
    if not BuffFrameModule._hookedDebuffAnchors then
        BuffFrameModule._hookedDebuffAnchors = true
        hooksecurefunc("DebuffButton_UpdateAnchors", function(buttonName, index)
            if not buffFramePositionLocked then return end
            if index ~= 1 then return end  -- only fix the first debuff; rest chain from it
            FixDebuffPositions()
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
                    buffsHiddenByToggle = true
                    toggleButton.toggle = false
                    local normalTex = toggleButton:GetNormalTexture()
                    normalTex:set_atlas('CollapseButton-Left', true)
                    local highlightTex = toggleButton:GetHighlightTexture()
                    highlightTex:set_atlas('CollapseButton-Left', true)
                    for index = 1, BUFF_ACTUAL_DISPLAY do
                        local button = _G['BuffButton' .. index]
                        if button then button:Hide() end
                    end
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
        if addon.db and addon.db.profile and addon.db.profile.buffs and addon.db.profile.buffs.enabled then
            BuffFrameModule:Enable()
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