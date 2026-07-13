local addon = select(2, ...);

-- ============================================================================
-- PETBAR MODULE FOR DRAGONUI
-- ============================================================================


-- Petbar constants
local unpack = unpack;
local select = select;
local pairs = pairs;
local _G = getfenv(0);
local GetPetActionInfo = GetPetActionInfo;
local RegisterStateDriver = RegisterStateDriver;
local UnregisterStateDriver = UnregisterStateDriver;
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;

-- DragonUI Configuration Functions
local function GetModuleConfig()
    return addon:GetModuleConfig("petbar")
end

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
        (addon.L and addon.L["Pet Bar"]) or "Pet Bar",
        (addon.L and addon.L["Pet action bar positioning and styling"]) or "Pet action bar positioning and styling")
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
    
    -- Fallback to dynamic positioning only if no widget config exists
    local config = GetDynamicConfig()
    local pUiMainBar = addon.pUiMainBar
    
    -- Check if anchor should be positioned relative to mainbar or absolute
    if pUiMainBar and pUiMainBar:IsShown() then
        -- Dynamic positioning based on other bars (legacy behavior)
        local leftbar = MultiBarBottomLeft and MultiBarBottomLeft:IsShown()
        local rightbar = MultiBarBottomRight and MultiBarBottomRight:IsShown()
        local offsetX = config.x_position
        local nobar = config.y_position
        local leftOffset = nobar + config.leftbar_offset
        local rightOffset = nobar + config.rightbar_offset
        
        if not InCombatLockdown() and not UnitAffectingCombat('player') then
            PetbarModule.anchor:ClearAllPoints()
            if leftbar and rightbar then
                PetbarModule.anchor:SetPoint('TOPLEFT', pUiMainBar, 'TOPLEFT', offsetX, leftOffset)
            elseif leftbar then
                PetbarModule.anchor:SetPoint("TOPLEFT", pUiMainBar, 'TOPLEFT', offsetX, rightOffset)
            elseif rightbar then
                PetbarModule.anchor:SetPoint("TOPLEFT", pUiMainBar, 'TOPLEFT', offsetX, leftOffset)
            else
                PetbarModule.anchor:SetPoint("TOPLEFT", pUiMainBar, 'TOPLEFT', offsetX, nobar)
            end
        end
    else
        -- Fallback to absolute positioning if mainbar not available
        if not InCombatLockdown() then
            PetbarModule.anchor:ClearAllPoints()
            PetbarModule.anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', config.x_position, config.y_position)
        end
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

-- Handle pet action button icon and state updates
local function petbutton_updatestate(self, event)
    if not IsModuleEnabled() then return end
    
    local config = GetDynamicConfig()
    local petActionButton, petActionIcon, petAutoCastableTexture, petAutoCastShine
    
    for index=1, NUM_PET_ACTION_SLOTS, 1 do
        local buttonName = 'PetActionButton'..index
        petActionButton = _G[buttonName]
        petActionIcon = _G[buttonName..'Icon']
        petAutoCastableTexture = _G[buttonName..'AutoCastable']
        petAutoCastShine = _G[buttonName..'Shine']
        
        if petActionButton then
            local name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(index)
            if not isToken then
                petActionIcon:SetTexture(texture)
                petActionButton.tooltipName = name
            else
                petActionIcon:SetTexture(_G[texture])
                petActionButton.tooltipName = _G[name]
            end
            petActionButton.isToken = isToken
            petActionButton.tooltipSubtext = subtext
            if isActive and name ~= 'PET_ACTION_FOLLOW' then
                petActionButton:SetChecked(true)
                if IsPetAttackAction(index) then
                    PetActionButton_StartFlash(petActionButton)
                end
            else
                petActionButton:SetChecked(false)
                if IsPetAttackAction(index) then
                    PetActionButton_StopFlash(petActionButton)
                end
            end
            if autoCastAllowed then
                petAutoCastableTexture:Show()
            else
                petAutoCastableTexture:Hide()
            end
            if autoCastEnabled then
                AutoCastShine_AutoCastStart(petAutoCastShine)
            else
                AutoCastShine_AutoCastStop(petAutoCastShine)
            end
            if name then
                if not config.grid then
                    petActionButton:SetAlpha(1)
                end
            else
                if not config.grid then
                    petActionButton:SetAlpha(0)
                end
            end
            if texture then
                if GetPetActionSlotUsable(index) then
                    SetDesaturation(petActionIcon, nil)
                else
                    SetDesaturation(petActionIcon, 1)
                end
                petActionIcon:Show()
            else
                petActionIcon:Hide()
            end
            if not PetHasActionBar() and texture and name ~= 'PET_ACTION_FOLLOW' then
                PetActionButton_StopFlash(petActionButton)
                SetDesaturation(petActionIcon, 1)
                petActionButton:SetChecked(false)
            end
        end
    end

    -- Reasserts the bar's hover/combat alpha; anchor-only, so it can't undo the per-slot alpha above.
    if addon.VisibilityFade then
        addon.VisibilityFade.Update("petbar")
    end
end

-- Position pet buttons (legacy approach - this is what makes it work!)
local function petbutton_position()
    if not IsModuleEnabled() then return end
    
    local petbar = PetbarModule.petbar
    if not petbar then return end
    
    local config = GetDynamicConfig()
    local btnsize = config.size
    local space = config.spacing
    
    local button
    for index=1, 10 do
        button = _G['PetActionButton'..index]
        if button then
            button:ClearAllPoints()
            button:SetParent(petbar)
            button:SetSize(btnsize, btnsize)
            if index == 1 then
                button:SetPoint('BOTTOMLEFT', 0, 0)
            else
                button:SetPoint('LEFT', _G['PetActionButton'..(index-1)], 'RIGHT', space, 0)
            end
            button:Show()
            petbar:SetAttribute('addchild', button)
            
            -- Apply DragonUI button styling if buttons module available
            if addon.petbuttons_template then
                addon.petbuttons_template()
            end
        end
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
    hooksecurefunc('PetActionBar_Update', petbutton_updatestate)
    PetbarModule.hooks.PetActionBar_Update = true
end

-- Create event frame for legacy system
local function CreateEventFrame()
    if PetbarModule.eventFrame then return PetbarModule.eventFrame end
    
    local eventFrame = CreateFrame("Frame")
    PetbarModule.eventFrame = eventFrame
    
    local function OnEvent(self, event, ...)
        if not IsModuleEnabled() then return end
        -- Skip event processing during editor mode (prevents state driver re-registration)
        if addon.EditorMode and addon.EditorMode:IsActive() then return end
        
        -- Handle pet bar events
        local arg1 = ...
        if event == 'PLAYER_LOGIN' then
            petbutton_position()
        elseif event == 'PET_BAR_UPDATE'
        or event == 'UNIT_PET' and arg1 == 'player'
        or event == 'PLAYER_CONTROL_LOST'
        or event == 'PLAYER_CONTROL_GAINED'
        or event == 'PLAYER_FARSIGHT_FOCUS_CHANGED'
        or event == 'UNIT_FLAGS'
        or arg1 == 'pet' and event == 'UNIT_AURA' then
            petbutton_updatestate()
        elseif event == 'PET_BAR_UPDATE_COOLDOWN' then
            PetActionBar_UpdateCooldowns()
        end
        
        -- Update anchor position for dynamic positioning
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

-- Register bottom bar hooks for dynamic repositioning
local function RegisterBottomBarHooks()
    if not IsModuleEnabled() then return end
    
    for _, bar in pairs({MultiBarBottomLeft, MultiBarBottomRight}) do
        if bar then
            bar:HookScript('OnShow', function()
                UpdateAnchorPosition()
            end)
            bar:HookScript('OnHide', function()
                UpdateAnchorPosition()
            end)
            PetbarModule.hooks[bar:GetName()..'_Show'] = true
            PetbarModule.hooks[bar:GetName()..'_Hide'] = true
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
    petbutton_position()
    
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
        petbutton_position()
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
            addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                addon.RefreshPetbarSystem()
            end)
            addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                addon.RefreshPetbarSystem()
            end)
            addon.db.RegisterCallback(addon, "OnProfileReset", function()
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