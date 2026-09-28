-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- ============================================================================
-- PETBAR MODULE FOR DRAGONUI
-- ============================================================================


local _G, pairs, GetPetActionInfo = _G, pairs, GetPetActionInfo
local RegisterStateDriver, UnregisterStateDriver = RegisterStateDriver, UnregisterStateDriver
local CreateFrame, UIParent, hooksecurefunc = CreateFrame, UIParent, hooksecurefunc
local PET_SLOT_COUNT = 10

-- DragonUI Configuration Functions
local function IsModuleEnabled()
    return addon:IsModuleEnabled("petbar")
end

local function GetPetbarConfig()
    return addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.pet
end

-- DragonUI Module state tracking
local PetbarModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    anchor = nil,
    petbar = nil,
    eventFrame = nil
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("petbar", PetbarModule,
        addon.L["Pet Bar"],
        addon.L["Pet action bar positioning and styling"])
end

-- ============================================================================
-- DYNAMIC CONFIG SYSTEM (reads from DragonUI database)
-- ============================================================================

local function GetDynamicConfig()
    local petConfig = GetPetbarConfig()
    local additionalConfig = addon.db and addon.db.profile and addon.db.profile.additional
    
    -- Default values if config not available
    local defaults = {
        x_position = -400,
        y_position = 200,
        leftbar_offset = 0,
        rightbar_offset = 0,
        size = 30,
        spacing = 6,
        grid = false,
        scale = 1.0
    }
    
    if not petConfig then return defaults end
    
    -- Use parentheses to ensure correct or/and precedence
    return {
        x_position = petConfig.x_position or (additionalConfig and additionalConfig.pet and additionalConfig.pet.x_position) or defaults.x_position,
        y_position = petConfig.y_position or (additionalConfig and additionalConfig.pet and additionalConfig.pet.y_position) or defaults.y_position,
        leftbar_offset = petConfig.leftbar_offset or defaults.leftbar_offset,
        rightbar_offset = petConfig.rightbar_offset or defaults.rightbar_offset,
        size = petConfig.size or (additionalConfig and additionalConfig.size) or defaults.size,
        spacing = petConfig.spacing or (additionalConfig and additionalConfig.spacing) or defaults.spacing,
        grid = petConfig.grid or defaults.grid,
        scale = (additionalConfig and additionalConfig.pet and additionalConfig.pet.scale) or defaults.scale
    }
end

-- ============================================================================
-- DUAL-BAR OFFSET HELPER
-- ============================================================================

-- Get dual-bar vertical offset for petbar (only when at default position)
local function GetPetbarDualBarOffset()
    if addon.GetDualBarVerticalOffset and addon.IsWidgetAtDefaultPosition
       and addon.IsWidgetAtDefaultPosition("petbar") then
        return addon.GetDualBarVerticalOffset()
    end
    return 0
end

-- ============================================================================
-- PETBAR IMPLEMENTATION (combat-safe)
-- ============================================================================

-- Create anchor frame
local function CreateAnchorFrame()
    if not IsModuleEnabled() then return end
    if PetbarModule.anchor then return PetbarModule.anchor end
    
    local config = GetDynamicConfig()
    
    -- Calculate proper petbar size based on config
    local btnsize = config.size or 30
    local space = config.spacing or 6
    local numButtons = 10
    local petbarWidth = (btnsize * numButtons) + (space * (numButtons - 1))
    local petbarHeight = btnsize
    
    -- Reuse the named global if it exists — recreating via CreateFrame resets alpha to 1.
    local anchor = _G.DragonUI_petbar or addon.CreateUIFrame(petbarWidth, petbarHeight, "petbar")
    PetbarModule.anchor = anchor
    
    -- Apply petbar scale
    anchor:SetScale(config.scale or 1.0)
    
    -- Apply position from widgets config or use defaults
    local extraY = GetPetbarDualBarOffset()
    local widgetConfig = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.petbar
    if widgetConfig then
        local anchorPoint = widgetConfig.anchor or "BOTTOM"
        local posX = widgetConfig.posX or config.x_position or -400
        local posY = widgetConfig.posY or config.y_position or 200
        anchor:ClearAllPoints()
        anchor:SetPoint(anchorPoint, UIParent, anchorPoint, posX, posY + extraY)
    else
        -- Use default positioning from config
        anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', config.x_position, config.y_position + extraY)
    end
    
    return anchor
end

-- Dynamic anchor update method (respects widget system positions)
local function UpdateAnchorPosition()
    if not IsModuleEnabled() then return end
    if not PetbarModule.anchor then return end
    -- Skip repositioning while editor mode is active (user may be dragging the anchor)
    if addon.EditorMode and addon.EditorMode:IsActive() and not addon._positionPresetApply then return end
    
    -- Check if we have a saved widget position first
    local widgetConfig = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.petbar
    if widgetConfig and (widgetConfig.anchor or widgetConfig.posX or widgetConfig.posY) then
        -- Use widget system position - don't override user's saved position
        local anchorPoint = widgetConfig.anchor or "BOTTOM"
        local posX = widgetConfig.posX or 0
        local posY = widgetConfig.posY or 200
        local extraY = GetPetbarDualBarOffset()
        
        if not InCombatLockdown() then
            PetbarModule.anchor:ClearAllPoints()
            PetbarModule.anchor:SetPoint(anchorPoint, UIParent, anchorPoint, posX, posY + extraY)
        end
        return
    end
    
    local cfg = GetDynamicConfig()
    local holder = PetbarModule.anchor
    local mainBar = addon.MainBar
    local onMainBar = mainBar and mainBar:IsShown()
    local locked = InCombatLockdown()
    local offsetY = cfg.y_position
    if onMainBar then
        local leftBar, rightBar = _G.MultiBarBottomLeft, _G.MultiBarBottomRight
        local leftShown = leftBar and leftBar:IsShown()
        local rightShown = rightBar and rightBar:IsShown()
        -- The single-bar offsets are crossed on purpose (left bar alone uses the right offset).
        if rightShown then
            offsetY = offsetY + cfg.leftbar_offset
        elseif leftShown then
            offsetY = offsetY + cfg.rightbar_offset
        end
        locked = locked or UnitAffectingCombat('player')
    end
    if locked then return end

    holder:ClearAllPoints()
    if onMainBar then
        holder:SetPoint('TOPLEFT', mainBar, 'TOPLEFT', cfg.x_position, offsetY)
    else
        holder:SetPoint('BOTTOM', UIParent, 'BOTTOM', cfg.x_position, offsetY)
    end
end

-- Create pet bar frame (follows anchor)
local function CreatePetbarFrame()
    if not IsModuleEnabled() then return end
    if PetbarModule.petbar then return PetbarModule.petbar end
    
    local anchor = CreateAnchorFrame()
    if not anchor then return end
    
    local config = GetDynamicConfig()
    -- Reuse the named global if it exists — recreating via CreateFrame resets alpha to 1.
    local petbar = _G.DragonUI_PetBar or CreateFrame('Frame', 'DragonUI_PetBar', UIParent, 'SecureHandlerStateTemplate')
    petbar:SetAllPoints(anchor)
    petbar:SetScale(config.scale or 1.0)
    PetbarModule.petbar = petbar

    return petbar
end

-- ============================================================================
-- PET BUTTON STATE MANAGEMENT
-- ============================================================================

local FOLLOW_TOKEN = 'PET_ACTION_FOLLOW'

-- Must never write PetActionBarFrame.showgrid: an insecure write there taints the pet bar.
local function updatePetButtonStates()
    if not IsModuleEnabled() then return end
    local showEmpty = GetDynamicConfig().grid
    for index = 1, NUM_PET_ACTION_SLOTS do
        local slotName = 'PetActionButton' .. index
        local slotButton = _G[slotName]
        if slotButton then
            local face = _G[slotName .. 'Icon']
            local castable, shine = _G[slotName .. 'AutoCastable'], _G[slotName .. 'Shine']
            local actionName, subtext, iconPath, isToken, isActive, canAutoCast, autoCastOn = GetPetActionInfo(index)
            local isAttack = IsPetAttackAction(index)
            local isFollow = actionName == FOLLOW_TOKEN

            local label, art = actionName, iconPath
            if isToken then
                label, art = _G[actionName], _G[iconPath]
            end
            face:SetTexture(art)
            slotButton.tooltipName = label
            slotButton.isToken = isToken
            slotButton.tooltipSubtext = subtext

            local lit = isActive and not isFollow
            slotButton:SetChecked(lit and true or false)
            if isAttack then
                if lit then
                    PetActionButton_StartFlash(slotButton)
                else
                    PetActionButton_StopFlash(slotButton)
                end
            end

            if canAutoCast then castable:Show() else castable:Hide() end
            if autoCastOn then
                AutoCastShine_AutoCastStart(shine)
            else
                AutoCastShine_AutoCastStop(shine)
            end

            slotButton:SetAlpha((showEmpty or actionName) and 1 or 0)

            if iconPath then
                SetDesaturation(face, not GetPetActionSlotUsable(index))
                face:Show()
            else
                face:Hide()
            end

            if iconPath and not isFollow and not PetHasActionBar() then
                PetActionButton_StopFlash(slotButton)
                SetDesaturation(face, true)
                slotButton:SetChecked(false)
            end
        end
    end
    if addon.VisibilityFade then
        addon.VisibilityFade.Update('petbar')
    end
end

local function PetSlotPoint(index, previous, gap)
    if index > 1 then
        return 'LEFT', previous, 'RIGHT', gap, 0
    end
    return 'BOTTOMLEFT', 0, 0
end

-- Position pet buttons (legacy approach - this is what makes it work!)
local function positionPetButtons()
    if not IsModuleEnabled() then return end

    -- PLAYER_LOGIN also fires on a mid-combat /reload; reparenting secure buttons there is blocked.
    if InCombatLockdown() then
        addon.CombatQueue:Add("petbar_position_buttons", positionPetButtons)
        return
    end

    local petbar = PetbarModule.petbar
    if not petbar then return end
    
    local config = GetDynamicConfig()
    local btnsize = config.size
    local space = config.spacing
    
    -- Restyle runs once per placed slot on purpose: cooldown levels come from the parent at first styling.
    local previous
    for index = 1, PET_SLOT_COUNT do
        local slotButton = _G['PetActionButton' .. index]
        if slotButton then
            slotButton:ClearAllPoints()
            slotButton:SetSize(btnsize, btnsize)
            slotButton:SetParent(petbar)
            slotButton:SetPoint(PetSlotPoint(index, previous, space))
            slotButton:Show()
            petbar:SetAttribute('addchild', slotButton)
            if addon.StylePetButtons then
                addon.StylePetButtons()
            end
        end
        previous = slotButton
    end
    
    -- Register state driver for pet visibility (skip during editor mode to keep petbar visible)
    if not (addon.EditorMode and addon.EditorMode:IsActive()) then
        RegisterStateDriver(petbar, 'visibility', '[pet,novehicleui,nobonusbar:5] show; hide')
        PetbarModule.stateDrivers.visibility = petbar
    end

    -- Hover/combat fade layered on top of the state driver above (alpha-only, never Show/Hide).
    -- Anchor is deliberately excluded: CreateUIFrame gives it frame level 100, so enabling its
    -- mouse would sit above the real action buttons and steal every click meant for them.
    if addon.VisibilityFade then
        local buttons = {}
        for i = 1, 10 do
            local btn = _G['PetActionButton' .. i]
            if btn then table.insert(buttons, btn) end
        end
        local hoverFrames = { petbar }
        for _, btn in ipairs(buttons) do table.insert(hoverFrames, btn) end
        addon.VisibilityFade.Register("petbar", petbar, {
            -- Buttons are reparented to petbar, whose alpha cascades to them — don't duplicate them here.
            dbTable = function() return addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.pet end,
            hoverFrames = hoverFrames,
            clickThrough = true,
        })
        addon.VisibilityFade.Update("petbar")
    end

    -- Hook for pet action updates
    if not PetbarModule.hooks.PetActionBar_Update then
        hooksecurefunc('PetActionBar_Update', updatePetButtonStates)
        PetbarModule.hooks.PetActionBar_Update = true
    end
end

-- Create event frame for legacy system
local function CreateEventFrame()
    if PetbarModule.eventFrame then return PetbarModule.eventFrame end
    
    local eventFrame = CreateFrame("Frame")
    PetbarModule.eventFrame = eventFrame
    
    local slotStateEvents = {
        PET_BAR_UPDATE = true,
        PLAYER_CONTROL_LOST = true,
        PLAYER_CONTROL_GAINED = true,
        PLAYER_FARSIGHT_FOCUS_CHANGED = true,
        UNIT_FLAGS = true,
    }

    -- These two only count for one unit; every other event is unit-agnostic.
    local unitFilteredEvents = { UNIT_PET = 'player', UNIT_AURA = 'pet' }

    local function RefreshesSlotState(eventName, unit)
        local wantedUnit = unitFilteredEvents[eventName]
        if wantedUnit then
            return unit == wantedUnit
        end
        return slotStateEvents[eventName] == true
    end

    local function OnEvent(_, eventName, unit)
        if not IsModuleEnabled() then return end
        if addon.EditorMode and addon.EditorMode:IsActive() then return end

        if eventName == 'PLAYER_LOGIN' then
            positionPetButtons()
        elseif eventName == 'PET_BAR_UPDATE_COOLDOWN' then
            PetActionBar_UpdateCooldowns()
        elseif RefreshesSlotState(eventName, unit) then
            updatePetButtonStates()
        end
        UpdateAnchorPosition()
    end
    
    eventFrame:SetScript('OnEvent', OnEvent)
    
    -- Register pet bar events
    local events = {
        'PET_BAR_HIDE',
        'PET_BAR_UPDATE',
        'PET_BAR_UPDATE_COOLDOWN',
        'PET_BAR_UPDATE_USABLE',
        'PLAYER_CONTROL_GAINED',
        'PLAYER_CONTROL_LOST',
        'PLAYER_FARSIGHT_FOCUS_CHANGED',
        'PLAYER_LOGIN',
        'UNIT_AURA',
        'UNIT_FLAGS',
        'UNIT_PET'
    }
    
    for _, event in ipairs(events) do
        if event == 'UNIT_AURA' then
            if addon.RegisterUnitEventSafe then
                addon.RegisterUnitEventSafe(eventFrame, 'UNIT_AURA', 'pet')
            else
                eventFrame:RegisterEvent(event)
            end
        else
            eventFrame:RegisterEvent(event)
        end
        PetbarModule.registeredEvents[event] = true
    end
    
    return eventFrame
end

-- A fresh pair of hooks is stacked per apply; harmless, since the handler is idempotent.
local function RegisterBottomBarHooks()
    if not IsModuleEnabled() then return end
    for _, barName in ipairs({ 'MultiBarBottomLeft', 'MultiBarBottomRight' }) do
        local bar = _G[barName]
        if bar then
            for _, hook in ipairs({ { 'OnShow', '_Show' }, { 'OnHide', '_Hide' } }) do
                bar:HookScript(hook[1], UpdateAnchorPosition)
                PetbarModule.hooks[barName .. hook[2]] = true
            end
        end
    end
end

-- ============================================================================
-- DRAGONUI MODULE SYSTEM (Apply/Restore pattern)
-- ============================================================================

-- Function to update editor frame registration (must be defined before use)
local function UpdateEditorFrameRegistration()
    if addon.EditableFrames and addon.EditableFrames.petbar and PetbarModule.anchor then
        addon.EditableFrames.petbar.frame = PetbarModule.anchor
        
        -- Update the frame size to match current config
        local config = GetDynamicConfig()
        local btnsize = config.size or 30
        local space = config.spacing or 6
        local numButtons = 10
        local petbarWidth = (btnsize * numButtons) + (space * (numButtons - 1))
        local petbarHeight = btnsize
        
        PetbarModule.anchor:SetSize(petbarWidth, petbarHeight)
    end
end

local function ApplyPetbarSystem()
    if PetbarModule.applied or not IsModuleEnabled() then
        return
    end

    -- Create anchor and petbar frames
    CreateAnchorFrame()
    CreatePetbarFrame()
    
    -- Store original states for restoration
    for index = 1, NUM_PET_ACTION_SLOTS do
        local button = _G['PetActionButton' .. index]
        if button then
            PetbarModule.originalStates[button:GetName()] = {
                parent = button:GetParent(),
                points = {}
            }
            for i = 1, button:GetNumPoints() do
                local point, relativeTo, relativePoint, xOfs, yOfs = button:GetPoint(i)
                table.insert(PetbarModule.originalStates[button:GetName()].points, 
                    {point, relativeTo, relativePoint, xOfs, yOfs})
            end
        end
    end

    -- Initialize pet bar system
    positionPetButtons()
    
    -- Register legacy event system
    CreateEventFrame()
    RegisterBottomBarHooks()
    
    PetbarModule.applied = true
    PetbarModule.initialized = true
    
    -- Update editor frame registration with actual anchor frame
    UpdateEditorFrameRegistration()
    
   
end

local function RestorePetbarSystem()
    if not PetbarModule.applied then return end
    -- Never tear down petbar while editor mode is active (overlay must stay visible)
    if addon.EditorMode and addon.EditorMode:IsActive() then return end

    -- Hide DragonUI frames
    if PetbarModule.anchor then PetbarModule.anchor:Hide() end
    if PetbarModule.petbar then PetbarModule.petbar:Hide() end

    -- Restore original button states
    for buttonName, originalState in pairs(PetbarModule.originalStates) do
        local button = _G[buttonName]
        if button and originalState then
            button:SetParent(originalState.parent)
            button:ClearAllPoints()
            for _, point in ipairs(originalState.points) do
                button:SetPoint(point[1], point[2], point[3], point[4], point[5])
            end
        end
    end

    -- Unregister events
    if PetbarModule.eventFrame then
        PetbarModule.eventFrame:UnregisterAllEvents()
        PetbarModule.eventFrame = nil
    end

    -- Unregister state drivers
    for frame, _ in pairs(PetbarModule.stateDrivers) do
        if frame then
            UnregisterStateDriver(frame, 'visibility')
        end
    end
    PetbarModule.stateDrivers = {}

    -- Clear module state
    PetbarModule.anchor = nil
    PetbarModule.petbar = nil
    PetbarModule.applied = false
    
  
end

-- ============================================================================
-- DRAGONUI WIDGETS INTEGRATION (Editor Mode Support)
-- ============================================================================

local function ShowPetbarTest()
    if not PetbarModule.anchor then return end
    
    -- Ensure anchor frame is visible
    PetbarModule.anchor:Show()
    PetbarModule.anchor:SetMovable(true)
    PetbarModule.anchor:EnableMouse(true)
    
    -- Temporarily unregister state driver so petbar stays visible during editor mode
    -- (state driver hides petbar when player has no pet)
    if PetbarModule.petbar and not InCombatLockdown() then
        UnregisterStateDriver(PetbarModule.petbar, 'visibility')
        PetbarModule.petbar:Show()
    end
    
    -- Show editor overlay elements if they exist
    if PetbarModule.anchor.editorTexture then
        PetbarModule.anchor.editorTexture:Show()
    end
    if PetbarModule.anchor.editorText then
        PetbarModule.anchor.editorText:Show()
    end
end

local function HidePetbarTest()
    if not PetbarModule.anchor then return end
    
    -- Disable editor mode
    PetbarModule.anchor:SetMovable(false)
    PetbarModule.anchor:EnableMouse(false)
    
    -- Re-register state driver for normal gameplay visibility
    if PetbarModule.petbar and not InCombatLockdown() then
        RegisterStateDriver(PetbarModule.petbar, 'visibility', '[pet,novehicleui,nobonusbar:5] show; hide')
        PetbarModule.stateDrivers.visibility = PetbarModule.petbar
    end
    
    -- Hide editor overlay elements
    if PetbarModule.anchor.editorTexture then
        PetbarModule.anchor.editorTexture:Hide()
    end
    if PetbarModule.anchor.editorText then
        PetbarModule.anchor.editorText:Hide()
    end
    
    -- Save position to widgets config
    if addon.SaveUIFramePosition then
        addon.SaveUIFramePosition(PetbarModule.anchor, "widgets", "petbar")
    end
end

-- ============================================================================
-- DRAGONUI INTEGRATION AND INTERFACE
-- ============================================================================

-- Export petbar position update for dual-bar offset system
addon.UpdatePetbarPosition = UpdateAnchorPosition

-- Global functions for DragonUI system
function addon.RefreshPetbarSystem()
    -- Skip refresh during editor mode (prevents overlay from disappearing)
    if addon.EditorMode and addon.EditorMode:IsActive() then return end

    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("petbar_refresh_system", addon.RefreshPetbarSystem)
        end
        return
    end

    if PetbarModule.applied then
        if not IsModuleEnabled() and addon:ShouldDeferModuleDisable("petbar", PetbarModule) then
            return
        end

        RestorePetbarSystem()
        if IsModuleEnabled() then
            ApplyPetbarSystem()
        end
    elseif IsModuleEnabled() then
        ApplyPetbarSystem()
    end
end

-- Re-runs the per-slot alpha logic after the "Show Empty Slots" (grid) toggle changes.
function addon.RefreshPetbarGrid()
    if not IsModuleEnabled() then return end
    updatePetButtonStates()
end

-- Refresh function for size and position updates
function addon.RefreshPetbarFrame()
    if not IsModuleEnabled() or not PetbarModule.anchor then return end

    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("petbar_refresh_frame", addon.RefreshPetbarFrame)
        end
        return
    end
    
    -- Update frame size based on current config
    local config = GetDynamicConfig()
    local btnsize = config.size or 30
    local space = config.spacing or 6
    local numButtons = 10
    local petbarWidth = (btnsize * numButtons) + (space * (numButtons - 1))
    local petbarHeight = btnsize
    
    PetbarModule.anchor:SetSize(petbarWidth, petbarHeight)
    
    -- Update scale on both anchor and petbar (petbar is UIParent-parented, not a child of anchor)
    local newScale = config.scale or 1.0
    PetbarModule.anchor:SetScale(newScale)
    if PetbarModule.petbar then
        PetbarModule.petbar:SetScale(newScale)
    end
    
    -- Update editor registration
    UpdateEditorFrameRegistration()
    
    -- Reposition buttons with new size
    if PetbarModule.petbar then
        positionPetButtons()
    end
end

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        self.addonLoaded = true
        
        -- Register petbar for editor mode (frame will be updated later)
        if addon.RegisterEditableFrame then
            addon:RegisterEditableFrame({
                name = "petbar",
                frame = nil, -- Frame will be set when created
                configPath = {"widgets", "petbar"},
                showTest = ShowPetbarTest,
                hideTest = HidePetbarTest
            })
        end
        
        -- Set up profile callbacks (DragonUI modular system)
        if addon.db then
            addon.db.RegisterCallback(PetbarModule, "OnProfileChanged", function()
                addon.RefreshPetbarSystem()
            end)
            addon.db.RegisterCallback(PetbarModule, "OnProfileCopied", function()
                addon.RefreshPetbarSystem()
            end)
            addon.db.RegisterCallback(PetbarModule, "OnProfileReset", function()
                addon.RefreshPetbarSystem()
            end)
        end
        
    elseif event == "PLAYER_LOGIN" and self.addonLoaded then
        if IsModuleEnabled() then
            addon.RefreshPetbarSystem()
            -- Update editor frame registration after anchor is created
            UpdateEditorFrameRegistration()
        end
    end
end)