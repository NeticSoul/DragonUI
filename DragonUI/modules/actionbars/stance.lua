-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local _G, pairs, select = _G, pairs, select
local class = addon._class

-- ============================================================================
-- STANCE MODULE FOR DRAGONUI
-- ============================================================================

-- Module state tracking
local StanceModule = {
    initialized = false,
    applied = false,
    originalStates = {},     -- Store original states for restoration
    registeredEvents = {},   -- Track registered events
    hooks = {},             -- Track hooked functions
    stateDrivers = {},      -- Track state drivers
    frames = {}             -- Track created frames
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("stance", StanceModule,
        addon.L["Stance Bar"],
        addon.L["Stance/shapeshift bar positioning and styling"])
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function IsModuleEnabled()
    return addon:IsModuleEnabled("stance")
end

-- Nil-safe accessor for stance-specific config (addon.db.profile.additional.stance)
-- IMPORTANT: Keep in sync with database.lua → additional.stance
local STANCE_DEFAULTS = {
    x_position = -211,
    y_offset = -55,
    button_size = 31,
    button_spacing = 6,
}
local function GetStanceConfig()
    if addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.stance then
        return addon.db.profile.additional.stance
    end
    return STANCE_DEFAULTS
end

-- ============================================================================
-- CONSTANTS AND VARIABLES
-- ============================================================================

local InCombatLockdown, UnitAffectingCombat = InCombatLockdown, UnitAffectingCombat
local GetNumShapeshiftForms, GetShapeshiftFormInfo = GetNumShapeshiftForms, GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local CreateFrame, UIParent, hooksecurefunc = CreateFrame, UIParent, hooksecurefunc

-- Shadows the global on purpose: the bar always lays out ten slots.
local NUM_SHAPESHIFT_SLOTS = 10

local CLASSES_WITH_FORM_BAR = {
    DEATHKNIGHT = true, DRUID = true, PALADIN = true, PRIEST = true,
    ROGUE = true, WARLOCK = true, WARRIOR = true,
}
local STANCE_VISIBILITY = CLASSES_WITH_FORM_BAR[class] and '[vehicleui] hide; show' or 'hide'
local HOLDER_EDGE = 37

-- Module frames (created only when enabled)
local anchor, stancebar

local STANCE_BASE_Y = 200

local function ResolveStancePosition()
    -- READ VALUES FROM DATABASE
    local stanceConfig = GetStanceConfig()
    local x_position = stanceConfig.x_position or -230  -- X position from center
    local y_offset = stanceConfig.y_offset or 0         -- Additional Y offset
    local base_y = STANCE_BASE_Y                        -- Base Y position from bottom
    local final_y = base_y + y_offset                   -- Final Y position
    
    -- Apply dual-bar offset when both XP and Rep bars are visible
    -- Only if stance bar is at its default position (not moved by user)
    -- IMPORTANT: Keep in sync with database.lua → additional.stance
    local defaultYOffset = -55   -- database default for additional.stance.y_offset
    local defaultXPosition = -211  -- database default for additional.stance.x_position
    -- The flag, not the numbers, marks an editor move: a 1px nudge rounds back inside the tolerance.
    local atDefault = not stanceConfig.manual_position
        and math.abs(x_position - defaultXPosition) <= 1
        and math.abs(y_offset - defaultYOffset) <= 1
    if atDefault and addon.GetDualBarVerticalOffset then
        final_y = final_y + addon.GetDualBarVerticalOffset()
    end
    if atDefault and addon.GetFramedStackDrop then
        final_y = final_y - addon.GetFramedStackDrop()
    end
    if atDefault and addon.GetBottomRowDrop then
        final_y = final_y - addon.GetBottomRowDrop()
    end
    return x_position, final_y, atDefault
end

local function updateStanceBar()
    if not IsModuleEnabled() or not anchor then return end
    if InCombatLockdown() then return end  -- Cannot modify secure frame in combat

    local x_position, final_y = ResolveStancePosition()
    anchor:ClearAllPoints()
    anchor:SetPoint('BOTTOM', UIParent, 'BOTTOM', x_position, final_y)
    if addon.UpdatePetbarPosition then
        addon.UpdatePetbarPosition()
    end
end

-- Left edge, bottom and button height of the bar while it sits at its default spot with forms to show.
function addon.GetDefaultStanceRow()
    if not IsModuleEnabled() or not anchor or not CLASSES_WITH_FORM_BAR[class] then return end
    if (GetNumShapeshiftForms() or 0) < 1 then return end
    local x_position, final_y, atDefault = ResolveStancePosition()
    if not atDefault then return end
    return x_position - HOLDER_EDGE / 2, final_y, GetStanceConfig().button_size or 31
end

-- The y_offset that reproduces where the bar is drawn now, automatic shifts included, so editing never jumps.
local function GetDrawnYOffset()
    local _, final_y = ResolveStancePosition()
    return final_y - STANCE_BASE_Y
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Simple update function - no queues needed
local function UpdateStanceBar()
    if not IsModuleEnabled() then return end
    updateStanceBar()
end

-- Export for external modules (mainbars.lua calls this when dual-bar offset changes)
addon.UpdateStanceBarPosition = UpdateStanceBar

-- ============================================================================
-- POSITIONING FUNCTIONS
-- ============================================================================


-- ============================================================================
-- FRAME CREATION FUNCTIONS
-- ============================================================================

local function CreateStanceFrames()
    if StanceModule.frames.anchor or not IsModuleEnabled() then return end
    
    local holder = CreateFrame('Frame', 'DragonUI_StanceHolder', UIParent)
    holder:SetSize(HOLDER_EDGE, HOLDER_EDGE)
    local bar = CreateFrame('Frame', 'DragonUI_StanceBar', holder, 'SecureHandlerStateTemplate')
    anchor, stancebar = holder, bar
    StanceModule.frames.anchor, StanceModule.frames.stancebar = holder, bar
    bar:SetAllPoints(holder)
    
    -- Expose globally for compatibility
    _G.DragonUI_StanceBar = stancebar
    
    -- Create editor overlay using centralized CreateUIFrame (with nineslice support)
    -- Initial size is a placeholder; real size is set in showTest based on active forms
    local editorOverlay = addon.CreateUIFrame(100, 31, 'StanceOverlay')
    editorOverlay:SetFrameStrata('FULLSCREEN')
    editorOverlay:SetFrameLevel(100)
    editorOverlay:Hide()
    StanceModule.frames.editorOverlay = editorOverlay
    
    -- Variables to track drag movement (custom drag like multicast)
    local dragStartX, dragStartY = 0, 0
    local configStartX, configStartY = 0, 0
    local isDragging = false

    function editorOverlay:SyncManualOverlayDeltaToStanceConfig()
        if not anchor then
            return
        end

        if not (addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.stance) then
            return
        end

        local overlayX, overlayY = self:GetLeft(), self:GetBottom()
        local anchorX, anchorY = anchor:GetLeft(), anchor:GetBottom()
        if not overlayX or not overlayY or not anchorX or not anchorY then
            return
        end

        local deltaX = overlayX - anchorX
        local deltaY = overlayY - anchorY
        if math.abs(deltaX) < 0.5 and math.abs(deltaY) < 0.5 then
            return
        end

        local stanceCfg = addon.db.profile.additional.stance
        stanceCfg.x_position = math.floor((stanceCfg.x_position or -211) + deltaX + 0.5)
        stanceCfg.y_offset = math.floor(GetDrawnYOffset() + deltaY + 0.5)
        stanceCfg.manual_position = true

        updateStanceBar()

        -- Keep overlay glued to the real anchor after applying DB delta.
        self:ClearAllPoints()
        self:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
    end
    
    -- Make draggable with custom behavior (disable built-in movement)
    editorOverlay:SetMovable(false)
    editorOverlay:EnableMouse(true)
    editorOverlay:RegisterForDrag("LeftButton")
    
    editorOverlay:SetScript("OnDragStart", function(self)
        isDragging = true
        
        -- Show dragging state (orange/yellow, like other editor frames).
        if self.NineSlice and addon.SetNinesliceState then
            addon.SetNinesliceState(self, true)
        end
        if addon.ClearSelectionTint then
            addon.ClearSelectionTint(self)
        end
        
        -- Store mouse position when drag starts
        local scale = self:GetEffectiveScale()
        dragStartX = GetCursorPosition() / scale
        dragStartY = select(2, GetCursorPosition()) / scale
        
        -- Store current config values
        if addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.stance then
            configStartX = addon.db.profile.additional.stance.x_position or -230
            configStartY = GetDrawnYOffset()
        end
    end)
    
    -- Real-time update during drag
    editorOverlay:SetScript("OnUpdate", function(self, elapsed)
        if not isDragging then
            -- Pixel-perfect editor controls move the overlay directly.
            -- Convert that overlay movement into stance DB coordinates.
            if self.DragonUI_WasAdjustedByEditor or self.DragonUI_WasDragged then
                self:SyncManualOverlayDeltaToStanceConfig()
                self.DragonUI_WasAdjustedByEditor = nil
                self.DragonUI_WasDragged = nil
            end
            return
        end
        
        -- Calculate current delta from mouse movement
        local scale = self:GetEffectiveScale()
        local currentX = GetCursorPosition() / scale
        local currentY = select(2, GetCursorPosition()) / scale
        
        local deltaX = currentX - dragStartX
        local deltaY = currentY - dragStartY
        -- A click without a move must not store the drawn spot, or the bar stops following the bars below.
        if math.abs(deltaX) < 1 and math.abs(deltaY) < 1 then
            return
        end
        
        -- Update config values in real-time
        if addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.stance then
            addon.db.profile.additional.stance.x_position = math.floor(configStartX + deltaX + 0.5)
            addon.db.profile.additional.stance.y_offset = math.floor(configStartY + deltaY + 0.5)
            addon.db.profile.additional.stance.manual_position = true
            
            -- Update anchor position in real-time (move the actual stance bar)
            updateStanceBar()
            
            -- Keep overlay aligned to BOTTOMLEFT of anchor (buttons start there)
            self:ClearAllPoints()
            self:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
        end
    end)
    
    editorOverlay:SetScript("OnDragStop", function(self)
        isDragging = false
        
        -- Return to selected highlight state.
        if self.NineSlice and addon.SetNinesliceState then
            addon.SetNinesliceState(self, false)
        end
        if addon.ApplySelectionTint then
            addon.ApplySelectionTint(self)
        end
        -- Overlay is already in correct position from OnUpdate
    end)
    
    -- Apply static positioning immediately
    updateStanceBar()
    
    
end

-- ============================================================================
-- POSITIONING FUNCTIONS
-- ============================================================================

--



-- ============================================================================
-- STANCE BUTTON FUNCTIONS
-- ============================================================================

local function FormSlot(index)
    return _G['ShapeshiftButton' .. index]
end

local function RestyleFormSlots()
    local restyle = addon.StyleStanceButtons
    if restyle then
        restyle()
    end
end

local function LayoutFormSlot(slotButton, index, edge, slotScale, gap)
    slotButton:SetSize(edge, edge)
    slotButton:SetScale(slotScale)
    slotButton:ClearAllPoints()
    if index > 1 then
        local previous = FormSlot(index - 1)
        if previous then
            slotButton:SetPoint('LEFT', previous, 'RIGHT', gap, 0)
        end
    else
        slotButton:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
    end
end

local function SyncFormVisibility(slotButton, index)
    local _, formName = GetShapeshiftFormInfo(index)
    if formName then
        slotButton:Show()
    else
        slotButton:Hide()
    end
end

local refreshStanceButtons = function()
    if not (IsModuleEnabled() and anchor) or InCombatLockdown() then return end
    local lead = FormSlot(1)
    if lead then
        lead:ClearAllPoints()
        lead:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
    end
end

local function positionStanceButtons()
    if not IsModuleEnabled() or not stancebar or not anchor then return end

    -- PLAYER_LOGIN also fires on a mid-combat /reload; reparenting secure buttons there is blocked.
    if InCombatLockdown() then
        addon.CombatQueue:Add("stance_position_buttons", positionStanceButtons)
        return
    end

    -- READ VALUES FROM DATABASE
    local stanceConfig = GetStanceConfig()
    local additionalConfig = (addon.db and addon.db.profile and addon.db.profile.additional) or {}
    local btnsize = stanceConfig.button_size or additionalConfig.size or 36
    local space = stanceConfig.button_spacing or additionalConfig.spacing or 6
    
    -- Use scale for uniform sizing of entire button (icon + border + all textures)
    local nativeSize = 36
    local scale = btnsize / nativeSize
    
    for index = 1, NUM_SHAPESHIFT_SLOTS do
        local slotButton = FormSlot(index)
        if slotButton then
            if slotButton:GetParent() ~= stancebar then
                slotButton:SetParent(stancebar)
            end
            LayoutFormSlot(slotButton, index, nativeSize, scale, space)
            SyncFormVisibility(slotButton, index)
        end
    end

    local drivers = StanceModule.stateDrivers
    if not drivers.visibility then
        drivers.visibility = { frame = stancebar, state = 'visibility', condition = STANCE_VISIBILITY }
        RegisterStateDriver(stancebar, 'visibility', STANCE_VISIBILITY)
    end

	-- Hover/combat fade layered on top of the state driver above (alpha-only, never Show/Hide).
	if addon.VisibilityFade then
	    local hoverFrames = { stancebar }
	    for i = 1, NUM_SHAPESHIFT_SLOTS do
	        local btn = _G['ShapeshiftButton' .. i]
	        if btn then table.insert(hoverFrames, btn) end
	    end
	    addon.VisibilityFade.Register("stancebar", stancebar, {
	        dbTable = function() return addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.stance end,
	        hoverFrames = hoverFrames,
	        clickThrough = true,
	    })
	    addon.VisibilityFade.Update("stancebar")
	end
end

local CASTABLE_SHADE, BLOCKED_SHADE = 1, 0.4

-- Never touches ShapeshiftBarFrame fields: an insecure write there taints Blizzard's stance code.
local function RefreshFormSlotStates()
    if not IsModuleEnabled() then return end
    local formCount = math.min(NUM_SHAPESHIFT_SLOTS, GetNumShapeshiftForms())
    for index = 1, formCount do
        local slotButton = FormSlot(index)
        if slotButton then
            local slotName = slotButton:GetName()
            local face, swipe = _G[slotName .. 'Icon'], _G[slotName .. 'Cooldown']
            local texture, _, isActive, isCastable = GetShapeshiftFormInfo(index)
            face:SetTexture(texture)
            swipe:SetAlpha(texture and 1 or 0)
            CooldownFrame_SetTimer(swipe, GetShapeshiftFormCooldown(index))
            slotButton:SetChecked(isActive and 1 or 0)
            local shade = isCastable and CASTABLE_SHADE or BLOCKED_SHADE
            face:SetVertexColor(shade, shade, shade)
        end
    end
end

local function RebuildFormSlots()
    if not IsModuleEnabled() or InCombatLockdown() then return end
    RestyleFormSlots()
    positionStanceButtons()
    for index = 1, NUM_SHAPESHIFT_SLOTS do
        local slotButton = FormSlot(index)
        if slotButton then
            SyncFormVisibility(slotButton, index)
        end
    end
    RefreshFormSlotStates()
    -- Gaining or losing the first form decides whether the pet bar stacks above this bar.
    if addon.UpdatePetbarPosition then
        addon.UpdatePetbarPosition()
    end
end

-- Unlisted events only refresh slot states; the form-count events rebuild the whole bar.
local STANCE_EVENT_ACTIONS = {
    PLAYER_LOGIN = positionStanceButtons,
    UPDATE_SHAPESHIFT_FORMS = RebuildFormSlots,
    ACTIVE_TALENT_GROUP_CHANGED = RebuildFormSlots,
    CHARACTER_POINTS_CHANGED = RebuildFormSlots,
}

local function OnEvent(self, event)
    if not IsModuleEnabled() then return end
    local action = STANCE_EVENT_ACTIONS[event] or RefreshFormSlotStates
    action(self, event)
end

-- ============================================================================
-- INITIALIZATION FUNCTIONS
-- ============================================================================

-- Simple initialization function
local function InitializeStanceBar()
    if not IsModuleEnabled() then return end
    
    -- IMPORTANT: Apply button textures FIRST (from buttons.lua)
    if addon.StyleStanceButtons then
        addon.StyleStanceButtons()
    end
    
    -- Then position and scale
    positionStanceButtons()
    updateStanceBar()
    
    if stancebar then
        stancebar:Show()
    end
end

-- ============================================================================
-- APPLY/RESTORE FUNCTIONS
-- ============================================================================

local function ApplyStanceSystem()
    if StanceModule.applied or not IsModuleEnabled() then return end
    
    -- Create frames
    CreateStanceFrames()
    
    if not anchor or not stancebar then return end
    
    -- Register only essential events
    local events = {
        'PLAYER_LOGIN',
        'UPDATE_SHAPESHIFT_FORMS',
        'UPDATE_SHAPESHIFT_FORM',
        'UPDATE_SHAPESHIFT_USABLE',   -- Druid: fires when entering/leaving water, flyable zones, etc.
        'UPDATE_SHAPESHIFT_COOLDOWN', -- Cooldown changes
        'SPELL_UPDATE_USABLE',        -- General spell usability changes (zone transitions)
        'ACTIONBAR_UPDATE_USABLE',    -- Action bar usability updates
        'CHARACTER_POINTS_CHANGED',   -- Talent point changes can add/remove forms.
        'ACTIVE_TALENT_GROUP_CHANGED',-- Dual spec swap can add/remove forms.
    }
    
    for _, eventName in ipairs(events) do
        stancebar:RegisterEvent(eventName)
        StanceModule.registeredEvents[eventName] = stancebar
    end
    stancebar:SetScript('OnEvent', OnEvent)
    
    -- Simple hook for Blizzard updates - REGISTER ONLY ONCE
    if not StanceModule.hooks.ShapeshiftBar_Update then
        StanceModule.hooks.ShapeshiftBar_Update = true
        hooksecurefunc('ShapeshiftBar_Update', function()
            if IsModuleEnabled() then
                refreshStanceButtons()
            end
        end)
    end
    
    -- Initial setup
    InitializeStanceBar()
    
    StanceModule.applied = true
    
    -- Register with editor mode system
    if addon.RegisterEditableFrame and StanceModule.frames.editorOverlay then
        local editorOverlay = StanceModule.frames.editorOverlay
        
        addon:RegisterEditableFrame({
            name = "stance",
            frame = editorOverlay,
            configPath = {"additional", "stance"},
            
            showTest = function()
                -- Only show overlay if the player actually has stance/shapeshift forms
                local numForms = GetNumShapeshiftForms() or 0
                if numForms < 1 or not anchor then return end
                
                -- Position overlay at anchor location, matching the visual button area
                local stanceConfig = GetStanceConfig()
                local btnSize = stanceConfig.button_size or 31
                local spacing = stanceConfig.button_spacing or 6
                -- Buttons use SetScale(btnSize/36) so visual size = btnSize
                local totalWidth = numForms * btnSize + (numForms - 1) * spacing
                totalWidth = math.max(totalWidth, btnSize)
                editorOverlay:SetSize(totalWidth, btnSize)
                
                -- Buttons start at BOTTOMLEFT of anchor, so align overlay there
                editorOverlay:ClearAllPoints()
                editorOverlay:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', 0, 0)
                editorOverlay:Show()
                
                -- Show nineslice overlay
                if addon.ShowNineslice then
                    addon.SetNinesliceState(editorOverlay, false)
                    addon.ShowNineslice(editorOverlay)
                end
                if editorOverlay.editorText then
                    editorOverlay.editorText:Show()
                end
            end,
            
            hideTest = function()
                -- Ensure manual editor adjustments are persisted before hiding.
                if editorOverlay and editorOverlay.SyncManualOverlayDeltaToStanceConfig then
                    editorOverlay:SyncManualOverlayDeltaToStanceConfig()
                end
                editorOverlay:Hide()
                -- Hide nineslice overlay
                if addon.HideNineslice then
                    addon.HideNineslice(editorOverlay)
                end
                if editorOverlay.editorText then
                    editorOverlay.editorText:Hide()
                end
            end,

            onHide = function()
                if editorOverlay and editorOverlay.SyncManualOverlayDeltaToStanceConfig then
                    editorOverlay:SyncManualOverlayDeltaToStanceConfig()
                end
                if editorOverlay then
                    editorOverlay.DragonUI_WasAdjustedByEditor = nil
                    editorOverlay.DragonUI_WasDragged = nil
                end
            end,
            
            module = StanceModule
        })
    end
    
end

local function RestoreStanceSystem()
    if not StanceModule.applied then return end
    
    -- Unregister all events
    for eventName, frame in pairs(StanceModule.registeredEvents) do
        if frame and frame.UnregisterEvent then
            frame:UnregisterEvent(eventName)
        end
    end
    StanceModule.registeredEvents = {}
    
    -- Unregister all state drivers
    for name, data in pairs(StanceModule.stateDrivers) do
        if data.frame then
            UnregisterStateDriver(data.frame, data.state)
        end
    end
    StanceModule.stateDrivers = {}
    
    -- Hide custom frames
    if anchor then anchor:Hide() end
    if stancebar then stancebar:Hide() end
    
    -- Reset stance button parents to default
    for index=1, NUM_SHAPESHIFT_SLOTS do
        local button = _G['ShapeshiftButton'..index]
        if button then
            button:SetParent(ShapeshiftBarFrame or UIParent)
            button:ClearAllPoints()
            -- Don't reset positions here - let Blizzard handle it
        end
    end
    
    -- Clear global reference
    _G.DragonUI_StanceBar = nil

    StanceModule.applied = false
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Enhanced refresh function with module control
function addon.RefreshStanceSystem()
    if IsModuleEnabled() then
        ApplyStanceSystem()
        -- Call original refresh for settings
        if addon.RefreshStance then
            addon.RefreshStance()
        end
    else
        if addon:ShouldDeferModuleDisable("stance", StanceModule) then
            return
        end
        RestoreStanceSystem()
    end
end

-- Original refresh function for configuration changes
function addon.RefreshStance()
    if not IsModuleEnabled() then return end
    
	if InCombatLockdown() or UnitAffectingCombat('player') then 
		return 
	end
	
	-- Ensure frames exist
	if not anchor or not stancebar then
	    return
	end
	
	-- First apply button textures (from buttons.lua)
	if addon.StyleStanceButtons then
	    addon.StyleStanceButtons()
	end
	
	-- Update button size and spacing (scale-based - matching positionStanceButtons)
	local stanceConfig = GetStanceConfig()
	local additionalConfig = (addon.db and addon.db.profile and addon.db.profile.additional) or {}
	local btnsize = stanceConfig.button_size or additionalConfig.size or 36
	local space = stanceConfig.button_spacing or additionalConfig.spacing or 6
	
	-- Reposition stance buttons with scale for proper texture sizing
	-- Native Blizzard button size is 36x36
	local nativeSize = 36
	local scale = btnsize / nativeSize
	
	for index = 1, NUM_SHAPESHIFT_SLOTS do
		local slotButton = FormSlot(index)
		if slotButton then
			LayoutFormSlot(slotButton, index, nativeSize, scale, space)
		end
	end
	
	-- Update position
	updateStanceBar()

	if addon.VisibilityFade then
		addon.VisibilityFade.Update("stancebar")
	end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if StanceModule.initialized then return end
    
    -- Only apply if module is enabled
    if IsModuleEnabled() then
        ApplyStanceSystem()
    end
    
    StanceModule.initialized = true
end

-- Auto-initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Just mark as loaded, don't initialize yet
        self.addonLoaded = true
    elseif event == "PLAYER_LOGIN" and self.addonLoaded then
        -- Initialize after both addon is loaded and player is logged in
        Initialize()
        self:UnregisterAllEvents()
    end
end)
-- End of stance module