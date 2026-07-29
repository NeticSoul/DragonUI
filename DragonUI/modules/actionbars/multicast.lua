-- ============================================================================
-- DragonUI - Multicast (Totem/Possess) Bar Module
-- Handles Shaman totem bar and possession bar positioning and styling.
-- ============================================================================

local addon = select(2,...);
local L = addon.L
local InCombatLockdown = InCombatLockdown;
local UnitAffectingCombat = UnitAffectingCombat;
local hooksecurefunc = hooksecurefunc;
local UIParent = UIParent;
local NUM_POSSESS_SLOTS = NUM_POSSESS_SLOTS or 10;
local NUM_MULTI_CAST_BUTTONS_PER_PAGE = NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4;

-- Get player class dynamically (addon._class may not be set yet at load time)
local function GetPlayerClass()
    return addon._class or select(2, UnitClass('player'))
end

-- noop function for protecting frames
local noop = addon._noop

-- =============================================================================
-- MODULE STATE TRACKING
-- =============================================================================
local MulticastModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    styledButtons = {},
    frames = {},
    hooks = {},
    stateDrivers = {},
    registeredEvents = {}
}
addon.MulticastModule = MulticastModule

if addon.RegisterModule then
    addon:RegisterModule("multicast", MulticastModule,
        (L and L["Multicast"]) or "Multicast",
        (L and L["Shaman totem bar positioning and styling"]) or "Shaman totem bar positioning and styling", {
        refresh = "RefreshMulticast",
        loadOnce = true,
    })
end

-- Module frames (created only when enabled)
local anchor, totembar

-- Timer helper: delegates to centralized addon:After()
local function DelayedCall(delay, func)
    addon:After(delay, func)
end

-- Forward declaration for PositionTotemButtons (defined later)
local PositionTotemButtons

-- Combat deferral uses centralized addon.CombatQueue (core/api.lua)

-- =============================================================================
-- CONFIG HELPER FUNCTIONS
-- =============================================================================
local function GetTotemConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.totem) then
        return {}
    end
    return addon.db.profile.additional.totem
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("multicast")
end

-- =============================================================================
-- DYNAMIC ANCHOR SYSTEM
-- Anchors totem bar based on which action bars are visible:
-- 1. If MultiBarBottomRight is visible -> anchor to it
-- 2. Else if MultiBarBottomLeft is visible -> anchor to it  
-- 3. Else -> anchor to MainMenuBar
-- When user moves with editor, manual_position becomes true and uses x_position/y_offset
-- =============================================================================
local function GetDynamicAnchor()
    -- Check which bars are visible
    -- MultiBarBottomRight = "Bottom Right Action Bar" in Blizzard UI options
    -- MultiBarBottomLeft = "Bottom Left Action Bar" in Blizzard UI options
    
    if MultiBarBottomRight and MultiBarBottomRight:IsShown() then
        return MultiBarBottomRight, 'BOTTOMLEFT', 'TOPLEFT', 0, 2
    elseif MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then
        return MultiBarBottomLeft, 'BOTTOMLEFT', 'TOPLEFT', 0, 2
    else
        -- Anchor above MainMenuBar - offset left to align with action buttons
        -- MainMenuBar has page arrows on the left, so we need negative X offset
        return MainMenuBar, 'BOTTOM', 'TOP', -216, 20
    end
end

-- =============================================================================
-- POSITIONING FUNCTION (with dynamic anchor support)
-- =============================================================================
local pendingPositionUpdate = false
local function UpdateTotemBarPosition()
    if not anchor then return end
    
    -- CRITICAL: Never modify frame points during combat (causes taint)
    if InCombatLockdown() then
        if not pendingPositionUpdate then
            pendingPositionUpdate = true
            addon.CombatQueue:Add("multicast_UpdateTotemBarPosition", function()
                pendingPositionUpdate = false
                UpdateTotemBarPosition()
            end)
        end
        return
    end
    
    -- READ VALUES FROM DATABASE
    local totemConfig = GetTotemConfig()
    local manualPosition = totemConfig.manual_position
    
    anchor:ClearAllPoints()
    
    if manualPosition then
        -- Manual positioning: use saved x_position and y_offset
        local x_position = totemConfig.x_position or 0
        local y_offset = totemConfig.y_offset or 0
        local base_y = 200
        local final_y = base_y + y_offset
        
        anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', x_position, final_y)
    else
        -- Dynamic anchoring: anchor to action bars based on visibility
        local anchorFrame, point, relativePoint, offsetX, offsetY = GetDynamicAnchor()
        anchor:SetPoint(point, anchorFrame, relativePoint, offsetX, offsetY)
    end
end

-- =============================================================================
-- BUTTON POSITIONING WITH SCALE AND SPACING
-- =============================================================================
-- Scale the PARENT frame for size, then reposition buttons for custom spacing
PositionTotemButtons = function()
    if not anchor or not totembar then return end
    if InCombatLockdown() then return end
    if GetPlayerClass() ~= 'SHAMAN' then return end
    if not MultiCastActionBarFrame then return end
    
    -- READ VALUES FROM DATABASE
    local totemConfig = GetTotemConfig()
    local btnsize = totemConfig.button_size or 34
    local spacing = totemConfig.button_spacing or 4
    
    -- Use SCALE on the PARENT frame - all children inherit automatically
    local nativeSize = 30  -- Native Blizzard totem button size
    local scale = btnsize / nativeSize
    
    -- Apply scale to the parent frame
    MultiCastActionBarFrame:SetScale(scale)
    
    -- Calculate spacing in SCALED coordinates (since buttons are inside scaled parent)
    -- Native Blizzard spacing is about 6px, we need to adjust relative to that
    local scaledSpacing = spacing / scale
    
    -- Reposition buttons with custom spacing
    -- Order: SummonSpellButton -> SlotButtons (1-4) -> RecallSpellButton
    
    -- First button anchors to parent
    local summonBtn = MultiCastSummonSpellButton
    if summonBtn then
        summonBtn:ClearAllPoints()
        summonBtn:SetPoint('LEFT', MultiCastActionBarFrame, 'LEFT', 0, 0)
    end
    
    -- Slot buttons chain from summon button
    for i = 1, NUM_MULTI_CAST_BUTTONS_PER_PAGE do
        local slotBtn = _G['MultiCastSlotButton' .. i]
        if slotBtn then
            slotBtn:ClearAllPoints()
            if i == 1 then
                slotBtn:SetPoint('LEFT', summonBtn, 'RIGHT', scaledSpacing, 0)
            else
                slotBtn:SetPoint('LEFT', _G['MultiCastSlotButton' .. (i - 1)], 'RIGHT', scaledSpacing, 0)
            end
        end
        
        -- Action buttons (each page) anchor to their corresponding slot
        for page = 1, NUM_MULTI_CAST_PAGES do
            local actionBtnIndex = (page - 1) * NUM_MULTI_CAST_BUTTONS_PER_PAGE + i
            local actionBtn = _G['MultiCastActionButton' .. actionBtnIndex]
            if actionBtn and slotBtn then
                actionBtn:ClearAllPoints()
                actionBtn:SetPoint('CENTER', slotBtn, 'CENTER', 0, 0)
            end
        end
    end
    
    -- Recall button anchors to last slot button
    local recallBtn = MultiCastRecallSpellButton
    local lastSlot = _G['MultiCastSlotButton' .. (MultiCastActionBarFrame.numActiveSlots or NUM_MULTI_CAST_BUTTONS_PER_PAGE)]
    if recallBtn and lastSlot then
        recallBtn:ClearAllPoints()
        recallBtn:SetPoint('LEFT', lastSlot, 'RIGHT', scaledSpacing, 0)
    end
end

-- =============================================================================
-- FRAME CREATION FUNCTIONS
-- =============================================================================
local function CreateMulticastFrames()
    if MulticastModule.frames.anchor then return end
    
    -- Create simple anchor frame
    anchor = CreateFrame('Frame', 'DragonUI_TotemAnchor', UIParent)
    anchor:SetSize(37, 37)
    MulticastModule.frames.anchor = anchor
    
    -- Create totem bar frame
    totembar = CreateFrame('Frame', 'DragonUI_TotemBar', anchor, 'SecureHandlerStateTemplate')
    totembar:SetAllPoints(anchor)
    MulticastModule.frames.totembar = totembar
    
    -- Create editor overlay using centralized CreateUIFrame (with nineslice support)
    local editorOverlay = addon.CreateUIFrame(200, 37, 'TotemBarOverlay')
    editorOverlay:SetFrameStrata('FULLSCREEN')
    editorOverlay:SetFrameLevel(100)
    editorOverlay:Hide()
    MulticastModule.frames.editorOverlay = editorOverlay
    
    -- Update the editor text
    if editorOverlay.editorText then
        editorOverlay.editorText:SetText((L and (L["TotemBarOverlay"] or L["Totem Bar"])) or "Totem Bar")
    end
    
    -- Variables to track drag movement (custom drag like stance.lua)
    local dragStartX, dragStartY = 0, 0
    local configStartX, configStartY = 0, 0
    local isDragging = false
    
    -- Make draggable with custom behavior
    editorOverlay:SetMovable(false)
    editorOverlay:EnableMouse(true)
    editorOverlay:RegisterForDrag("LeftButton")
    
    editorOverlay:SetScript("OnDragStart", function(self)
        isDragging = true
        
        -- Show selected state
        if self.NineSlice and addon.SetNinesliceState then
            addon.SetNinesliceState(self, true)
        end
        
        -- Store mouse position when drag starts
        local scale = self:GetEffectiveScale()
        dragStartX = GetCursorPosition() / scale
        dragStartY = select(2, GetCursorPosition()) / scale
        
        -- When dragging starts, switch to manual positioning mode
        -- and calculate current position relative to UIParent BOTTOM
        if addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.totem then
            local totemConfig = addon.db.profile.additional.totem
            
            -- If we were in auto-anchor mode, convert current position to manual coordinates
            if not totemConfig.manual_position then
                -- Get current anchor position relative to screen
                local anchorCenterX, anchorCenterY = anchor:GetCenter()
                local screenWidth = UIParent:GetWidth()
                local screenHeight = UIParent:GetHeight()
                
                -- Calculate position relative to BOTTOM center of UIParent
                local base_y = 200  -- Base Y for manual positioning
                configStartX = math.floor((anchorCenterX - screenWidth/2) + 0.5)
                configStartY = math.floor((anchorCenterY - base_y) + 0.5)
                
                -- Update config to reflect current position in manual mode
                totemConfig.x_position = configStartX
                totemConfig.y_offset = configStartY
            else
                -- Already in manual mode, use stored values
                configStartX = totemConfig.x_position or 0
                configStartY = totemConfig.y_offset or 0
            end
            
            -- Enable manual positioning mode (loses dynamic anchor)
            totemConfig.manual_position = true
        end
    end)
    
    -- Real-time update during drag
    editorOverlay:SetScript("OnUpdate", function(self, elapsed)
        if not isDragging then return end
        
        -- Calculate current delta from mouse movement
        local scale = self:GetEffectiveScale()
        local currentX = GetCursorPosition() / scale
        local currentY = select(2, GetCursorPosition()) / scale
        
        local deltaX = currentX - dragStartX
        local deltaY = currentY - dragStartY
        
        -- Update config values in real-time
        if addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.totem then
            addon.db.profile.additional.totem.x_position = math.floor(configStartX + deltaX + 0.5)
            addon.db.profile.additional.totem.y_offset = math.floor(configStartY + deltaY + 0.5)
            
            -- Update anchor position in real-time
            UpdateTotemBarPosition()
            
            -- Calculate width for overlay offset
            local totemConfig = GetTotemConfig()
            local buttonWidth = totemConfig.button_size or 34
            local spacing = totemConfig.button_spacing or 4
            local totalWidth = math.max(6 * buttonWidth + 5 * spacing, 100)
            local offsetX = (totalWidth / 2) - (buttonWidth / 2)
            
            -- Keep overlay centered on anchor
            self:ClearAllPoints()
            self:SetPoint('CENTER', anchor, 'CENTER', offsetX, 0)
        end
    end)
    
    editorOverlay:SetScript("OnDragStop", function(self)
        isDragging = false
        
        -- Return to highlight state
        if self.NineSlice and addon.SetNinesliceState then
            addon.SetNinesliceState(self, false)
        end
    end)
    
    -- Apply static positioning immediately
    UpdateTotemBarPosition()
end

-- =============================================================================
-- SHAMAN MULTICAST (TOTEM) BAR SETUP FUNCTION
-- =============================================================================
local multicastSetupDone = false
local multicastSetupPending = false
local function SetupShamanMulticast()
    if multicastSetupDone then return end
    if GetPlayerClass() ~= 'SHAMAN' then return end
    if not MultiCastActionBarFrame then return end
    
    -- CRITICAL: Defer entire setup if in combat
    -- We need to reparent and reposition the frame, which requires combat lockdown check
    if InCombatLockdown() then
        if not multicastSetupPending then
            multicastSetupPending = true
            addon.CombatQueue:Add("multicast_SetupShamanMulticast", function()
                multicastSetupPending = false
                SetupShamanMulticast()
            end)
        end
        return
    end
    
    multicastSetupDone = true
    
    -- Remove default scripts that might interfere with our positioning
    MultiCastActionBarFrame:SetScript('OnUpdate', nil)
    MultiCastActionBarFrame:SetScript('OnShow', nil)
    MultiCastActionBarFrame:SetScript('OnHide', nil)
    
    -- Parent the MultiCastActionBarFrame to our anchor
    -- Once parented, all child buttons stay relative to this parent
    MultiCastActionBarFrame:SetParent(totembar)
    MultiCastActionBarFrame:ClearAllPoints()
    MultiCastActionBarFrame:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
    MultiCastActionBarFrame:Show()
    
    -- Apply initial scale and spacing to the PARENT frame
    PositionTotemButtons()
    
    -- Slot/flyout buttons are created on demand; rescan so click-through covers each one too.
    -- MultiCastActionButtonN (not MultiCastSlotButtonN) is the real clickable/castable totem button.
    local function SyncTotemHoverButtons()
        if not addon.VisibilityFade then return end
        local found = {}
        for i = 1, (NUM_MULTI_CAST_PAGES or 6) * NUM_MULTI_CAST_BUTTONS_PER_PAGE do
            local actionBtn = _G['MultiCastActionButton' .. i]
            if actionBtn then table.insert(found, actionBtn) end
        end
        for i = 1, 20 do
            local slotBtn = _G['MultiCastSlotButton' .. i]
            if slotBtn then table.insert(found, slotBtn) end
            local flyoutBtn = _G['MultiCastFlyoutButton' .. i]
            if flyoutBtn then table.insert(found, flyoutBtn) end
        end
        if _G.MultiCastFlyoutFrameOpenButton then table.insert(found, _G.MultiCastFlyoutFrameOpenButton) end
        if _G.MultiCastFlyoutFrame then table.insert(found, _G.MultiCastFlyoutFrame) end
        if #found > 0 then
            addon.VisibilityFade.AddHoverFrames("totembar", found)
        end
    end

    -- Hook Blizzard update functions to maintain our custom spacing
    if not MulticastModule.hooks.buttonUpdate then
        MulticastModule.hooks.buttonUpdate = true

        -- When Blizzard updates button positions, re-apply our spacing
        hooksecurefunc('MultiCastSummonSpellButton_Update', function()
            if not InCombatLockdown() then
                PositionTotemButtons()
                SyncTotemHoverButtons()
                if addon.RefreshAdditionalBarHotkeys then
                    addon.RefreshAdditionalBarHotkeys()
                end
            end
        end)

        hooksecurefunc('MultiCastRecallSpellButton_Update', function()
            if not InCombatLockdown() then
                PositionTotemButtons()
                SyncTotemHoverButtons()
                if addon.RefreshAdditionalBarHotkeys then
                    addon.RefreshAdditionalBarHotkeys()
                end
            end
        end)

        -- Hook slot updates too
        hooksecurefunc('MultiCastSlotButton_Update', function()
            if not InCombatLockdown() then
                PositionTotemButtons()
                SyncTotemHoverButtons()
                if addon.RefreshAdditionalBarHotkeys then
                    addon.RefreshAdditionalBarHotkeys()
                end
            end
        end)
    end
    
    -- Hook action bar visibility changes to update dynamic anchoring
    -- Only matters when NOT in manual_position mode
    if not MulticastModule.hooks.actionBarVisibility then
        MulticastModule.hooks.actionBarVisibility = true
        
        -- When MultiBarBottomRight or MultiBarBottomLeft visibility changes, update anchor
        local function OnActionBarVisibilityChange()
            -- CRITICAL: Skip during combat to avoid taint from secure state driver chain
            if InCombatLockdown() then return end
            local totemConfig = GetTotemConfig()
            if not totemConfig.manual_position then
                -- Only update if in auto-anchor mode
                UpdateTotemBarPosition()
            end
        end
        
        if MultiBarBottomRight then
            hooksecurefunc(MultiBarBottomRight, 'Show', OnActionBarVisibilityChange)
            hooksecurefunc(MultiBarBottomRight, 'Hide', OnActionBarVisibilityChange)
        end
        if MultiBarBottomLeft then
            hooksecurefunc(MultiBarBottomLeft, 'Show', OnActionBarVisibilityChange)
            hooksecurefunc(MultiBarBottomLeft, 'Hide', OnActionBarVisibilityChange)
        end
    end
    
    -- Register visibility state driver (hide during vehicle)
    if not MulticastModule.stateDrivers.visibility then
        local visCondition = '[vehicleui] hide; show'
        MulticastModule.stateDrivers.visibility = {frame = totembar, state = 'visibility', condition = visCondition}
        RegisterStateDriver(totembar, 'visibility', visCondition)
    end

    -- Hover/combat fade layered on top of the state driver above (alpha-only, never Show/Hide).
    -- Individual buttons are listed (not just MultiCastActionBarFrame) because EnableMouse
    -- doesn't cascade to children — click-through needs each one's own mouse disabled too.
    -- MultiCastActionButtonN (SecureActionButtonTemplate) is the real castable button, not MultiCastSlotButtonN.
    if addon.VisibilityFade then
        local hoverFrames = { totembar }
        if _G.MultiCastActionBarFrame then table.insert(hoverFrames, _G.MultiCastActionBarFrame) end
        if MultiCastSummonSpellButton then table.insert(hoverFrames, MultiCastSummonSpellButton) end
        if MultiCastRecallSpellButton then table.insert(hoverFrames, MultiCastRecallSpellButton) end
        for i = 1, (NUM_MULTI_CAST_PAGES or 6) * NUM_MULTI_CAST_BUTTONS_PER_PAGE do
            local actionBtn = _G['MultiCastActionButton' .. i]
            if actionBtn then table.insert(hoverFrames, actionBtn) end
        end
        for i = 1, NUM_MULTI_CAST_BUTTONS_PER_PAGE do
            local btn = _G['MultiCastSlotButton' .. i]
            if btn then table.insert(hoverFrames, btn) end
        end
        -- The "deploy totems" flyout (per-element totem choices) lives outside totembar's bounds.
        if _G.MultiCastFlyoutFrameOpenButton then table.insert(hoverFrames, _G.MultiCastFlyoutFrameOpenButton) end
        if _G.MultiCastFlyoutFrame then table.insert(hoverFrames, _G.MultiCastFlyoutFrame) end
        addon.VisibilityFade.Register("totembar", totembar, {
            dbTable = function() return addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.totem end,
            hoverFrames = hoverFrames,
            clickThrough = true,
        })
        addon.VisibilityFade.Update("totembar")
    end
end

-- =============================================================================
-- UNIFIED REFRESH FUNCTION (using SCALE, not SetSize)
-- =============================================================================
function addon.RefreshMulticast(fullRefresh)
    if not IsModuleEnabled() then return end

    if InCombatLockdown() or UnitAffectingCombat("player") then
        addon.CombatQueue:Add(fullRefresh and "multicast_RefreshFull" or "multicast_Refresh", function()
            addon.RefreshMulticast(fullRefresh)
        end)
        return 
    end
    
    -- Update anchor position
    UpdateTotemBarPosition()
    
    -- Update button scaling if fullRefresh
    if fullRefresh then
        PositionTotemButtons()
    end

    if addon.VisibilityFade then
        addon.VisibilityFade.Update("totembar")
    end
end


-- =============================================================================
-- APPLY SYSTEM FUNCTION
-- =============================================================================
local function ApplyMulticastSystem()
    if MulticastModule.applied or not IsModuleEnabled() then return end
    
    -- Create frames
    CreateMulticastFrames()
    
    -- Setup shaman multicast if applicable
    SetupShamanMulticast()
    
    -- Initial positioning
    UpdateTotemBarPosition()
    PositionTotemButtons()
    
    MulticastModule.applied = true
    
    -- Register with editor mode system
    if addon.RegisterEditableFrame and MulticastModule.frames.editorOverlay then
        local editorOverlay = MulticastModule.frames.editorOverlay
        
        addon:RegisterEditableFrame({
            name = "totembar",
            frame = editorOverlay,
            configPath = {"additional", "totem"},
            
            editorVisible = function()
                -- Only show totem bar in editor mode for shamans
                local _, class = UnitClass("player")
                return class == "SHAMAN" and MultiCastActionBarFrame ~= nil
            end,
            
            showTest = function()
                if anchor then
                    -- Calculate width based on config
                    local totemConfig = GetTotemConfig()
                    local buttonWidth = totemConfig.button_size or 34
                    local spacing = totemConfig.button_spacing or 4
                    local totalWidth = math.max(6 * buttonWidth + 5 * spacing, 100)
                    editorOverlay:SetSize(totalWidth, buttonWidth)
                    
                    editorOverlay:ClearAllPoints()
                    editorOverlay:SetPoint('CENTER', anchor, 'CENTER', (totalWidth / 2) - (buttonWidth / 2), 0)
                    editorOverlay:Show()
                    
                    -- Show nineslice overlay
                    if addon.ShowNineslice then
                        addon.SetNinesliceState(editorOverlay, false)
                        addon.ShowNineslice(editorOverlay)
                    end
                    if editorOverlay.editorText then
                        editorOverlay.editorText:Show()
                    end
                end
            end,
            
            hideTest = function()
                editorOverlay:Hide()
                if addon.HideNineslice then
                    addon.HideNineslice(editorOverlay)
                end
                if editorOverlay.editorText then
                    editorOverlay.editorText:Hide()
                end
            end,
            
            module = MulticastModule
        })
    end
end

-- =============================================================================
-- PROFILE CHANGE HANDLER
-- =============================================================================
local function OnProfileChanged()
    DelayedCall(0.2, function()
        if not IsModuleEnabled() and addon:ShouldDeferModuleDisable("multicast", MulticastModule) then
            return
        end

        if InCombatLockdown() or UnitAffectingCombat("player") then
            addon.CombatQueue:Add("multicast_OnProfileChanged", function()
                OnProfileChanged()
            end)
            return
        end
        
        addon.RefreshMulticast(true)
    end)
end

-- =============================================================================
-- CENTRALIZED EVENT HANDLER
-- =============================================================================
local eventFrame = CreateFrame("Frame")
local function RegisterEvents()
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    -- Note: PLAYER_REGEN_ENABLED is handled by SetupShamanMulticast if needed for deferred setup
    
    eventFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "DragonUI" then
            -- Initialize multicast system as early as possible
            if addon.core and addon.core.RegisterMessage then
                addon.core.RegisterMessage(MulticastModule, "DRAGONUI_READY", ApplyMulticastSystem)
            end
            
            -- Register profile callbacks
            DelayedCall(0.5, function()
                if addon.db and addon.db.RegisterCallback then
                    addon.db.RegisterCallback(MulticastModule, "OnProfileChanged", OnProfileChanged)
                    addon.db.RegisterCallback(MulticastModule, "OnProfileCopied", OnProfileChanged)
                    addon.db.RegisterCallback(MulticastModule, "OnProfileReset", OnProfileChanged)
                end
            end)
            
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Apply system immediately when entering world (reload or login)
            ApplyMulticastSystem()
            
        elseif event == "PLAYER_LOGOUT" then
            if addon.db and addon.db.UnregisterCallback then
                addon.db.UnregisterCallback(addon, "OnProfileChanged")
                addon.db.UnregisterCallback(addon, "OnProfileCopied") 
                addon.db.UnregisterCallback(addon, "OnProfileReset")
            end
        end
    end)
end

-- Initialize event system
RegisterEvents()
