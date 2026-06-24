--[[
================================================================================
DragonUI - API Functions
================================================================================
This file contains utility functions used throughout DragonUI.
These are general-purpose functions that can be used by any module.
================================================================================
]]

local addon = select(2, ...)
local L = addon.L

addon.DB_SCHEMA_VERSION = 1
addon.RELEASE_VERSION = GetAddOnMetadata("DragonUI", "Version") or "2.4.0"

-- ============================================================================
-- TABLE UTILITIES
-- ============================================================================

-- Recursively copy tables
function addon.DeepCopy(source, target)
    target = target or {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            addon.DeepCopy(value, target[key])
        else
            target[key] = value
        end
    end
    return target
end

-- Count elements in a table (works with non-sequential tables)
function addon:tcount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

local function UpperCamelCase(name)
    return (name:gsub("(^%l)", string.upper):gsub("_(%l)", string.upper))
end

local function ApplyMissingDefaults(source, target)
    if type(source) ~= "table" or type(target) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyMissingDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- Register unit-filtered events when supported by the client; otherwise fall
-- back to RegisterEvent for compatibility across 3.3.5a variants.
function addon.RegisterUnitEventSafe(frame, eventName, ...)
    if not frame or not eventName then
        return false
    end

    local hasUnitToken = false
    for i = 1, select("#", ...) do
        if select(i, ...) ~= nil then
            hasUnitToken = true
            break
        end
    end

    if type(frame.RegisterUnitEvent) == "function" and hasUnitToken then
        return frame:RegisterUnitEvent(eventName, ...)
    end

    frame:RegisterEvent(eventName)
    return true
end

-- ============================================================================
-- FRAME CREATION AND MANAGEMENT
-- ============================================================================

-- Frames registry for editor mode
addon.frames = addon.frames or {}

-- Editor mode texture base path
local EDITMODE_TEXTURE_BASE = 'Interface\\AddOns\\DragonUI\\Textures\\Editmode\\'

-- Nineslice texture coordinates
local NINESLICE_COORDS = {
    highlight = {
        corner = {0.03125, 0.53125, 0.285156, 0.347656},
        topEdge = {0, 0.5, 0.0742188, 0.136719},
        bottomEdge = {0, 0.5, 0.00390625, 0.0664062},
        leftEdge = {0.0078125, 0.132812, 0, 1},
        rightEdge = {0.148438, 0.273438, 0, 1}
    },
    selected = {
        corner = {0.03125, 0.53125, 0.355469, 0.417969},
        topEdge = {0, 0.5, 0.214844, 0.277344},
        bottomEdge = {0, 0.5, 0.144531, 0.207031},
        leftEdge = {0.289062, 0.414062, 0, 1},
        rightEdge = {0.429688, 0.554688, 0, 1}
    }
}

-- Add nineslice border to a frame
local function AddNineslice(frame)
    frame.NineSlice = {}
    local slice = frame.NineSlice
    
    -- Top left corner (no rotation needed)
    slice.TopLeftCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.TopLeftCorner:SetSize(16, 16)
    slice.TopLeftCorner:SetPoint('TOPLEFT', -8, 8)
    
    -- Top right corner (will be rotated via SetTexCoord)
    slice.TopRightCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.TopRightCorner:SetSize(16, 16)
    slice.TopRightCorner:SetPoint('TOPRIGHT', 8, 8)
    
    -- Bottom left corner (will be rotated via SetTexCoord)
    slice.BottomLeftCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.BottomLeftCorner:SetSize(16, 16)
    slice.BottomLeftCorner:SetPoint('BOTTOMLEFT', -8, -8)
    
    -- Bottom right corner (will be rotated via SetTexCoord)
    slice.BottomRightCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.BottomRightCorner:SetSize(16, 16)
    slice.BottomRightCorner:SetPoint('BOTTOMRIGHT', 8, -8)
    
    -- Top edge (connects corners)
    slice.TopEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.TopEdge:SetPoint('TOPLEFT', slice.TopLeftCorner, 'TOPRIGHT')
    slice.TopEdge:SetPoint('BOTTOMRIGHT', slice.TopRightCorner, 'BOTTOMLEFT')
    
    -- Bottom edge
    slice.BottomEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.BottomEdge:SetPoint('TOPLEFT', slice.BottomLeftCorner, 'TOPRIGHT')
    slice.BottomEdge:SetPoint('BOTTOMRIGHT', slice.BottomRightCorner, 'BOTTOMLEFT')
    
    -- Left edge
    slice.LeftEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.LeftEdge:SetPoint('TOPLEFT', slice.TopLeftCorner, 'BOTTOMLEFT')
    slice.LeftEdge:SetPoint('BOTTOMRIGHT', slice.BottomLeftCorner, 'TOPRIGHT')
    
    -- Right edge
    slice.RightEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.RightEdge:SetPoint('TOPLEFT', slice.TopRightCorner, 'BOTTOMLEFT')
    slice.RightEdge:SetPoint('BOTTOMRIGHT', slice.BottomRightCorner, 'TOPRIGHT')
    
    -- Center (background)
    slice.Center = frame:CreateTexture(nil, 'BACKGROUND')
    slice.Center:SetPoint('TOPLEFT', 0, 0)
    slice.Center:SetPoint('BOTTOMRIGHT', 0, 0)
end

-- Helper function to apply rotated tex coords using 8-value SetTexCoord
-- SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
local function SetTexCoordRotated(texture, coords, rotation)
    local l, r, t, b = coords[1], coords[2], coords[3], coords[4]
    
    if rotation == 0 then
        -- Normal (0°): TopLeft corner
        texture:SetTexCoord(l, t, l, b, r, t, r, b)
    elseif rotation == 90 then
        -- 90° CW: BottomLeft corner
        texture:SetTexCoord(l, b, r, b, l, t, r, t)
    elseif rotation == 180 then
        -- 180°: BottomRight corner
        texture:SetTexCoord(r, b, r, t, l, b, l, t)
    elseif rotation == 270 then
        -- 270° CW (-90°): TopRight corner
        texture:SetTexCoord(r, t, l, t, r, b, l, b)
    end
end

-- Apply highlight or selected state to nineslice
local function SetNinesliceState(frame, selected)
    local slice = frame.NineSlice
    if not slice then return end
    
    local coords = selected and NINESLICE_COORDS.selected or NINESLICE_COORDS.highlight
    
    -- Corners use same texture with different coords and rotations
    local cornerTexture = EDITMODE_TEXTURE_BASE .. 'EditModeUI'
    
    -- TopLeft (0° - normal)
    slice.TopLeftCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.TopLeftCorner, coords.corner, 0)
    
    -- TopRight (90° CW)
    slice.TopRightCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.TopRightCorner, coords.corner, 90)
    
    -- BottomLeft (270° CW / -90°)
    slice.BottomLeftCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.BottomLeftCorner, coords.corner, 270)
    
    -- BottomRight (180°)
    slice.BottomRightCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.BottomRightCorner, coords.corner, 180)
    
    -- Edges
    slice.TopEdge:SetTexture(cornerTexture)
    slice.TopEdge:SetTexCoord(unpack(coords.topEdge))
    slice.BottomEdge:SetTexture(cornerTexture)
    slice.BottomEdge:SetTexCoord(unpack(coords.bottomEdge))
    
    local verticalTexture = EDITMODE_TEXTURE_BASE .. 'EditModeUIVertical'
    slice.LeftEdge:SetTexture(verticalTexture)
    slice.LeftEdge:SetTexCoord(unpack(coords.leftEdge))
    slice.RightEdge:SetTexture(verticalTexture)
    slice.RightEdge:SetTexCoord(unpack(coords.rightEdge))
    
    -- Center background
    local centerTexture = selected and 'EditModeUISelectedBackground' or 'EditModeUIHighlightBackground'
    slice.Center:SetTexture(EDITMODE_TEXTURE_BASE .. centerTexture)
    slice.Center:SetTexCoord(0, 1, 0, 1)
end

-- Show nineslice overlay
local function ShowNineslice(frame)
    local slice = frame.NineSlice
    if not slice then return end
    
    for _, part in pairs(slice) do
        part:Show()
    end
end

-- Hide nineslice overlay
local function HideNineslice(frame)
    local slice = frame.NineSlice
    if not slice then return end
    
    for _, part in pairs(slice) do
        part:Hide()
    end
end

-- Forward declarations for editor system (defined/assigned later)
local ApplySelectionTint, ClearSelectionTint
local editorPanel, selectedEditorFrame

-- Create a UI frame with editor mode support
function addon.CreateUIFrame(width, height, frameName)
    local frame = CreateFrame("Frame", 'DragonUI_' .. frameName, UIParent)
    frame:SetSize(width, height)

    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetMovable(false)
    
    frame:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        -- Ensure this frame is the selected one
        if selectedEditorFrame ~= self then
            addon.SelectEditorFrame(self)
        end
        -- While dragging: remove green tint, show default drag nineslice
        ClearSelectionTint(self)
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        -- AUTO-SAVE: Find this frame in EditableFrames and save position automatically
        for name, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == self then
                -- Save position automatically
                if frameData.configPath and #frameData.configPath == 2 then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                elseif frameData.configPath then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                break
            end
        end
        -- Re-apply green tint now that drag is done (frame stays selected)
        ApplySelectionTint(self)
    end)
    
    -- Click without drag also selects the frame
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            addon.SelectEditorFrame(self)
        end
    end)

    frame:SetFrameLevel(100)
    frame:SetFrameStrata('FULLSCREEN')

    -- Create nineslice overlay (DragonflightUI style)
    AddNineslice(frame)
    SetNinesliceState(frame, false) -- Default to highlight state
    HideNineslice(frame) -- Start hidden
    
    -- Legacy editorTexture reference (for backwards compatibility)
    frame.editorTexture = frame.NineSlice.Center

    -- Text label for editor mode (auto-translate via locale)
    do
        local L = addon.L
        local fontString = frame:CreateFontString(nil, "OVERLAY", 'GameFontNormal')
        fontString:SetPoint("CENTER", frame, "CENTER", 0, 0)
        local ok, translated = pcall(function() return L and L[frameName] end)
        fontString:SetText((ok and translated) or frameName)
        fontString:Hide()
        frame.editorText = fontString
    end

    return frame
end

-- Global function alias for backwards compatibility
CreateUIFrame = addon.CreateUIFrame

-- Export nineslice functions for modules with custom behavior
addon.AddNineslice = AddNineslice
addon.SetNinesliceState = SetNinesliceState
addon.ShowNineslice = ShowNineslice
addon.HideNineslice = HideNineslice

-- ============================================================================
-- FRAME VISIBILITY FUNCTIONS (Editor Mode Support)
-- ============================================================================

-- Show a UI frame (disable editor mode for this frame)
function addon.ShowUIFrame(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    -- Hide nineslice overlay (new system)
    if frame.NineSlice then
        HideNineslice(frame)
    elseif frame.editorTexture then
        -- Legacy fallback for frames not using CreateUIFrame
        frame.editorTexture:Hide()
    end
    
    if frame.editorText then
        frame.editorText:Hide()
    end

    if addon.frames[frame] then
        for _, target in pairs(addon.frames[frame]) do
            target:SetAlpha(1)
        end
        addon.frames[frame] = nil
    end
end

-- Global function alias for backwards compatibility
ShowUIFrame = addon.ShowUIFrame

-- Hide a UI frame (enable editor mode for this frame)
function addon.HideUIFrame(frame, exclude)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    
    -- Show nineslice overlay (new system)
    if frame.NineSlice then
        SetNinesliceState(frame, false) -- Highlight state
        ShowNineslice(frame)
    elseif frame.editorTexture then
        -- Legacy fallback for frames not using CreateUIFrame
        frame.editorTexture:Show()
    end
    
    if frame.editorText then
        frame.editorText:Show()
    end

    addon.frames[frame] = {}
    exclude = exclude or {}

    for _, target in pairs(exclude) do
        target:SetAlpha(0)
        table.insert(addon.frames[frame], target)
    end
end

-- Global function alias for backwards compatibility
HideUIFrame = addon.HideUIFrame

-- ============================================================================
-- POSITION SAVE/LOAD FUNCTIONS
-- ============================================================================

-- Save frame position to database
function addon.SaveUIFramePosition(frame, configPath1, configPath2)
    if not frame then
        return
    end

    local anchor, _, relativePoint, posX, posY = frame:GetPoint(1)

    -- Strip dual-bar offset from positions of affected widgets so the
    -- database always stores the *base* position.  Without this, closing
    -- editor mode while both XP+Rep bars are visible would bake the
    -- offset into the saved Y, breaking IsWidgetAtDefaultPosition.
    -- IMPORTANT: Only strip when the widget is still at its default spot
    -- (i.e.the offset was actually added).  For user-moved frames the
    -- offset was never applied, so subtracting it would cause drift.
    if configPath1 == "widgets" and configPath2
       and addon._dualBarOffsetWidgets and addon._dualBarOffsetWidgets[configPath2]
       and addon.GetDualBarVerticalOffset and addon.IsWidgetAtDefaultPosition
       and addon.IsWidgetAtDefaultPosition(configPath2) then
        local offset = addon.GetDualBarVerticalOffset()
        if offset > 0 and posY then
            posY = posY - offset
        end
    end

    -- Handle nested paths (widgets.player)
    if configPath2 then
        -- Case: SaveUIFramePosition(frame, "widgets", "player")
        if not addon.db.profile[configPath1] then
            addon.db.profile[configPath1] = {}
        end

        if not addon.db.profile[configPath1][configPath2] then
            addon.db.profile[configPath1][configPath2] = {}
        end

        addon.db.profile[configPath1][configPath2].anchor = anchor or "CENTER"
        addon.db.profile[configPath1][configPath2].posX = posX or 0
        addon.db.profile[configPath1][configPath2].posY = posY or 0
    else
        -- Case: SaveUIFramePosition(frame, "minimap") - backwards compatibility
        local widgetName = configPath1
        
        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end

        if not addon.db.profile.widgets[widgetName] then
            addon.db.profile.widgets[widgetName] = {}
        end

        addon.db.profile.widgets[widgetName].anchor = anchor or "CENTER"
        addon.db.profile.widgets[widgetName].posX = posX or 0
        addon.db.profile.widgets[widgetName].posY = posY or 0
    end
end

-- Global function alias for backwards compatibility
SaveUIFramePosition = addon.SaveUIFramePosition

-- Apply a saved widgets.* position to a frame (position presets / reload helpers)
function addon.ApplyWidgetPositionFromDB(widgetKey, frame)
    if not widgetKey or not frame or not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local cfg = addon.db.profile.widgets[widgetKey]
    if not cfg or (cfg.posX == nil and cfg.posY == nil) then
        return
    end

    local anchor = cfg.anchor or "CENTER"
    local posX = cfg.posX or 0
    local posY = cfg.posY or 0

    if addon._dualBarOffsetWidgets and addon._dualBarOffsetWidgets[widgetKey]
       and addon.GetDualBarVerticalOffset and addon.IsWidgetAtDefaultPosition
       and addon.IsWidgetAtDefaultPosition(widgetKey) then
        posY = posY + addon.GetDualBarVerticalOffset()
    end

    if InCombatLockdown() then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(anchor, UIParent, anchor, posX, posY)
end

ApplyWidgetPositionFromDB = addon.ApplyWidgetPositionFromDB

-- Apply frame position from database
function addon.ApplyUIFramePosition(frame, configPath)
    if not frame or not configPath then
        return
    end

    local section, key = configPath:match("([^%.]+)%.([^%.]+)")
    if not section or not key then
        return
    end

    local config = addon.db.profile[section] and addon.db.profile[section][key]
    if not config or not config.override then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(config.anchor or "CENTER", UIParent, config.anchorParent or "CENTER", config.x or 0, config.y or 0)
end

-- Global function alias for backwards compatibility
ApplyUIFramePosition = addon.ApplyUIFramePosition

-- ============================================================================
-- SETTINGS VALIDATION
-- ============================================================================

-- Check if settings exist and load defaults if needed
function addon.CheckSettingsExists(moduleTable, configPaths)
    local needsDefaults = false

    for _, configPath in pairs(configPaths) do
        local section, key = configPath:match("([^%.]+)%.([^%.]+)")
        if section and key then
            if not addon.db.profile[section] or not addon.db.profile[section][key] then
                needsDefaults = true
                break
            end
        end
    end

    if needsDefaults and moduleTable.LoadDefaultSettings then
        moduleTable:LoadDefaultSettings()
    end

    if moduleTable.UpdateWidgets then
        moduleTable:UpdateWidgets()
    end
end

-- Global function alias for backwards compatibility
CheckSettingsExists = addon.CheckSettingsExists

-- ============================================================================
-- EDITABLE FRAMES REGISTRY
-- Centralized system for managing moveable UI elements
-- ============================================================================

addon.EditableFrames = addon.EditableFrames or {}

-- Register a frame as editable
function addon:RegisterEditableFrame(frameInfo)
    local frameData = {
        name = frameInfo.name,                    -- "player", "minimap", "target"
        frame = frameInfo.frame,                  -- The auxiliary frame
        blizzardFrame = frameInfo.blizzardFrame,  -- Real Blizzard frame (optional)
        configPath = frameInfo.configPath,        -- {"widgets", "player"} or {"unitframe", "target"}
        onShow = frameInfo.onShow,                -- Optional function when showing editor
        onHide = frameInfo.onHide,                -- Optional function when hiding editor
        showTest = frameInfo.showTest,            -- Function to show with fake data
        hideTest = frameInfo.hideTest,            -- Function to hide fake frame
        hasTarget = frameInfo.hasTarget,          -- Function to check if should be visible
        editorVisible = frameInfo.editorVisible,  -- Function to check if frame should appear in editor mode
        module = frameInfo.module                 -- Reference to the module
    }
    
    self.EditableFrames[frameInfo.name] = frameData
end

-- ============================================================================
-- EDITOR CONTROL PANEL (Real-time X/Y + Nudge Buttons)
-- ============================================================================

-- Update the coordinate display with current frame position.
-- Uses GetCenter() for screen-relative coords that always reflect the
-- actual visual position (GetPoint offsets can be stale during StartMoving).
-- Skips update while the user is actively typing in an EditBox.
local function UpdateEditorPanelCoords()
    if not editorPanel or not selectedEditorFrame then return end
    local cx, cy = selectedEditorFrame:GetCenter()
    if cx and cy then
        local ux, uy = UIParent:GetCenter()
        local xStr = string.format("%.1f", cx - (ux or 0))
        local yStr = string.format("%.1f", cy - (uy or 0))
        -- Only update text if the EditBox is not focused (user may be typing)
        if not editorPanel.xValue:HasFocus() then
            editorPanel.xValue:SetText(xStr)
        end
        if not editorPanel.yValue:HasFocus() then
            editorPanel.yValue:SetText(yStr)
        end
    end
end

-- Apply coordinates typed by the user into the X/Y EditBoxes
local function ApplyTypedCoordinates()
    if not selectedEditorFrame or not editorPanel then return end
    local xText = editorPanel.xValue:GetText()
    local yText = editorPanel.yValue:GetText()
    local newX = tonumber(xText)
    local newY = tonumber(yText)
    if not newX or not newY then return end
    -- Position is relative to UIParent CENTER (matches what we display)
    selectedEditorFrame:ClearAllPoints()
    selectedEditorFrame:SetPoint("CENTER", UIParent, "CENTER", newX, newY)
    selectedEditorFrame.DragonUI_WasAdjustedByEditor = true
    selectedEditorFrame.DragonUI_WasDragged = true
    -- Auto-save
    if addon.EditableFrames then
        for _, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == selectedEditorFrame and frameData.configPath then
                if #frameData.configPath == 2 then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                break
            end
        end
    end
    -- Clear focus so live polling resumes
    editorPanel.xValue:ClearFocus()
    editorPanel.yValue:ClearFocus()
end

-- Move the selected frame by dx, dy pixels and auto-save
local function NudgeSelectedFrame(dx, dy)
    if not selectedEditorFrame then return end

    local cx, cy = selectedEditorFrame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then return end

    local relX = (cx - ux) + dx
    local relY = (cy - uy) + dy

    selectedEditorFrame:ClearAllPoints()
    selectedEditorFrame:SetPoint("CENTER", UIParent, "CENTER", relX, relY)
    selectedEditorFrame.DragonUI_WasAdjustedByEditor = true
    selectedEditorFrame.DragonUI_WasDragged = true
    -- Auto-save position
    if addon.EditableFrames then
        for _, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == selectedEditorFrame and frameData.configPath then
                if #frameData.configPath == 2 then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                break
            end
        end
    end
    UpdateEditorPanelCoords()
end

local function GetSelectedEditableFrameData()
    if not selectedEditorFrame or not addon.EditableFrames then
        return nil, nil
    end

    for name, frameData in pairs(addon.EditableFrames) do
        if frameData.frame == selectedEditorFrame then
            return name, frameData
        end
    end

    return nil, nil
end

local function ResetDetachedUnitframeToProfileDefaults(unitKey)
    local defaults = addon.defaults and addon.defaults.profile
    local profile = addon.db and addon.db.profile

    if not (defaults and profile and defaults.unitframe and defaults.unitframe[unitKey]) then
        return false
    end

    profile.unitframe = profile.unitframe or {}
    profile.unitframe[unitKey] = addon.DeepCopy(defaults.unitframe[unitKey], {})

    if defaults.widgets and defaults.widgets[unitKey] then
        profile.widgets = profile.widgets or {}
        profile.widgets[unitKey] = addon.DeepCopy(defaults.widgets[unitKey], {})
    end

    return true
end

local function GetDetachedResetActionForSelection()
    if not (addon and addon.db and addon.db.profile) then
        return nil, nil
    end

    local frameName, frameData = GetSelectedEditableFrameData()
    if not frameName then
        return nil, nil
    end

    if frameName == "TargetCastbar" then
        local cfg = addon.db.profile.castbar and addon.db.profile.castbar.target
        if cfg and cfg.override and addon.ResetTargetCastbarPosition then
            return function()
                addon.ResetTargetCastbarPosition()
            end, frameData
        end
    elseif frameName == "FocusCastbar" then
        local cfg = addon.db.profile.castbar and addon.db.profile.castbar.focus
        if cfg and cfg.override and addon.ResetFocusCastbarPosition then
            return function()
                addon.ResetFocusCastbarPosition()
            end, frameData
        end
    elseif frameName == "tot" then
        local cfg = addon.db.profile.unitframe and addon.db.profile.unitframe.tot
        if cfg and cfg.override and addon.TargetOfTarget and addon.TargetOfTarget.Refresh then
            return function()
                if ResetDetachedUnitframeToProfileDefaults("tot") then
                    addon.TargetOfTarget.Refresh()
                end
            end, frameData
        end
    elseif frameName == "fot" then
        local cfg = addon.db.profile.unitframe and addon.db.profile.unitframe.fot
        if cfg and cfg.override and addon.TargetOfFocus and addon.TargetOfFocus.Refresh then
            return function()
                if ResetDetachedUnitframeToProfileDefaults("fot") then
                    addon.TargetOfFocus.Refresh()
                end
            end, frameData
        end
    end

    return nil, frameData
end

local function GetLFGTooltipPositionValue()
    local widgets = addon.db and addon.db.profile and addon.db.profile.widgets
    local lfgFrameConfig = widgets and widgets.lfgframe
    local position = lfgFrameConfig and lfgFrameConfig.tooltip_position

    if position == "TOP" or position == "BOTTOM" or position == "LEFT" or position == "RIGHT" then
        return position
    end

    return "TOP"
end

local function SetLFGTooltipPositionValue(position)
    if position ~= "TOP" and position ~= "BOTTOM" and position ~= "LEFT" and position ~= "RIGHT" then
        return
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets.lfgframe = addon.db.profile.widgets.lfgframe or {}
    addon.db.profile.widgets.lfgframe.tooltip_position = position

    if addon.ReanchorLFDSearchStatus then
        addon.ReanchorLFDSearchStatus()
    end
end

local function SetLFGTooltipButtonState(button, isSelected)
    if not button or not button.SetBackdropColor then
        return
    end

    if isSelected then
        button:SetBackdropColor(0.18, 0.35, 0.55, 1)
        button:SetBackdropBorderColor(0.30, 0.75, 1.00, 1)
    else
        button:SetBackdropColor(0.16, 0.16, 0.18, 1)
        button:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.95)
    end
end

local function UpdateEditorPanelLFGTooltipControls()
    if not editorPanel then
        return
    end

    local frameName = select(1, GetSelectedEditableFrameData())
    local showControls = frameName == "lfgframe"
    local selectedPosition = GetLFGTooltipPositionValue()

    if editorPanel.lfgTooltipLabel then
        if showControls then
            editorPanel.lfgTooltipLabel:Show()
        else
            editorPanel.lfgTooltipLabel:Hide()
        end
    end

    if not editorPanel.lfgTooltipButtons then
        return
    end

    for position, button in pairs(editorPanel.lfgTooltipButtons) do
        if showControls then
            button:Show()
            SetLFGTooltipButtonState(button, position == selectedPosition)
        else
            button:Hide()
        end
    end
end

local function SetEditorPanelExpanded(expanded)
    if not editorPanel then
        return
    end

    local hasLFGTooltipControls = editorPanel.lfgTooltipLabel and editorPanel.lfgTooltipLabel:IsShown()
    local compactHeight = hasLFGTooltipControls and 128 or 80
    local expandedHeight = compactHeight + 24
    local targetHeight = expanded and expandedHeight or compactHeight
    if editorPanel:GetHeight() ~= targetHeight then
        editorPanel:SetHeight(targetHeight)
    end
end

local function UpdateEditorPanelResetButton()
    if not editorPanel or not editorPanel.resetSelectedButton then
        return
    end

    UpdateEditorPanelLFGTooltipControls()

    local action = GetDetachedResetActionForSelection()
    if action then
        editorPanel.resetSelectedButton._dragonuiAction = action
        editorPanel.resetSelectedButton:Show()
        SetEditorPanelExpanded(true)
    else
        editorPanel.resetSelectedButton._dragonuiAction = nil
        editorPanel.resetSelectedButton:Hide()
        SetEditorPanelExpanded(false)
    end
end

local function StyleEditorPanelButton(button)
    if not button or button._dragonStyled then
        return
    end

    button._dragonStyled = true

    if button.GetNumRegions then
        for i = 1, button:GetNumRegions() do
            local region = select(i, button:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end

    local name = button:GetName()
    if name then
        for _, suffix in ipairs({"Left", "Middle", "Right", "left", "middle", "right"}) do
            local tex = _G[name .. suffix]
            if tex and tex.SetTexture then
                tex:SetTexture(nil)
                tex:SetAlpha(0)
                tex:Hide()
            end
        end
    end

    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0.16, 0.16, 0.18, 1)
    button:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.95)

    if button:GetNormalTexture() then button:GetNormalTexture():SetTexture(nil) end
    if button:GetPushedTexture() then button:GetPushedTexture():SetTexture(nil) end
    if button:GetHighlightTexture() then button:GetHighlightTexture():SetTexture(nil) end
    if button:GetDisabledTexture() then button:GetDisabledTexture():SetTexture(nil) end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    highlight:SetVertexColor(0.09, 0.52, 0.82, 0.25)
    highlight:SetAllPoints()

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetTextColor(0.95, 0.95, 0.95)
    end

    button:HookScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.14, 1)
    end)

    button:HookScript("OnMouseUp", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(0.16, 0.16, 0.18, 1)
        end
    end)

    button:HookScript("OnEnable", function(self)
        self:SetBackdropColor(0.16, 0.16, 0.18, 1)
        self:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.95)
        local text = self:GetFontString()
        if text then
            text:SetTextColor(0.95, 0.95, 0.95)
        end
    end)

    button:HookScript("OnDisable", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.14, 0.8)
        self:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.45)
        local text = self:GetFontString()
        if text then
            text:SetTextColor(0.55, 0.55, 0.55)
        end
    end)
end

-- Create the floating control panel (called once, lazily)
local function CreateEditorControlPanel()
    if editorPanel then return editorPanel end

    local panel = CreateFrame("Frame", "DragonUI_EditorPanel", UIParent)
    panel:SetSize(180, 80)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -10)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(200)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    panel:SetBackdropBorderColor(0.4, 0.8, 1, 0.8)

    -- Make the panel draggable so it can be moved out of the way
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    -- Frame name label (top row)
    local nameLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOP", panel, "TOP", 0, -8)
    nameLabel:SetTextColor(0.4, 0.8, 1)
    nameLabel:SetText("\226\128\148")
    panel.nameLabel = nameLabel

    -- X row
    local xLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -26)
    xLabel:SetText("X:")

    local xValue = CreateFrame("EditBox", nil, panel)
    xValue:SetSize(55, 18)
    xValue:SetPoint("LEFT", xLabel, "RIGHT", 2, 0)
    xValue:SetFontObject(GameFontHighlightSmall)
    xValue:SetJustifyH("RIGHT")
    xValue:SetAutoFocus(false)
    xValue:SetNumeric(false)  -- allow negative numbers and decimals
    xValue:SetText("\226\128\148")
    xValue:SetFrameLevel(panel:GetFrameLevel() + 3)
    xValue:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    xValue:SetBackdropColor(0, 0, 0, 0.6)
    xValue:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.6)
    xValue:SetTextInsets(2, 2, 0, 0)
    xValue:SetScript("OnEnterPressed", function(self) ApplyTypedCoordinates(); self:ClearFocus() end)
    xValue:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.xValue = xValue

    local xMinus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    xMinus:SetSize(24, 20)
    xMinus:SetPoint("LEFT", xValue, "RIGHT", 8, 0)
    xMinus:SetText("<")
    xMinus:SetFrameLevel(panel:GetFrameLevel() + 5)
    StyleEditorPanelButton(xMinus)
    xMinus:SetScript("OnClick", function() NudgeSelectedFrame(-1, 0) end)

    local xPlus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    xPlus:SetSize(24, 20)
    xPlus:SetPoint("LEFT", xMinus, "RIGHT", 4, 0)
    xPlus:SetText(">")
    xPlus:SetFrameLevel(panel:GetFrameLevel() + 5)
    StyleEditorPanelButton(xPlus)
    xPlus:SetScript("OnClick", function() NudgeSelectedFrame(1, 0) end)

    -- Y row
    local yLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    yLabel:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -8)
    yLabel:SetText("Y:")

    local yValue = CreateFrame("EditBox", nil, panel)
    yValue:SetSize(55, 18)
    yValue:SetPoint("LEFT", yLabel, "RIGHT", 2, 0)
    yValue:SetFontObject(GameFontHighlightSmall)
    yValue:SetJustifyH("RIGHT")
    yValue:SetAutoFocus(false)
    yValue:SetNumeric(false)
    yValue:SetText("\226\128\148")
    yValue:SetFrameLevel(panel:GetFrameLevel() + 3)
    yValue:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    yValue:SetBackdropColor(0, 0, 0, 0.6)
    yValue:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.6)
    yValue:SetTextInsets(2, 2, 0, 0)
    yValue:SetScript("OnEnterPressed", function(self) ApplyTypedCoordinates(); self:ClearFocus() end)
    yValue:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.yValue = yValue

    local yMinus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    yMinus:SetSize(24, 20)
    yMinus:SetPoint("LEFT", yValue, "RIGHT", 8, 0)
    yMinus:SetText("v")
    yMinus:SetFrameLevel(panel:GetFrameLevel() + 5)
    StyleEditorPanelButton(yMinus)
    yMinus:SetScript("OnClick", function() NudgeSelectedFrame(0, -1) end)

    local yPlus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    yPlus:SetSize(24, 20)
    yPlus:SetPoint("LEFT", yMinus, "RIGHT", 4, 0)
    yPlus:SetText("^")
    yPlus:SetFrameLevel(panel:GetFrameLevel() + 5)
    StyleEditorPanelButton(yPlus)
    yPlus:SetScript("OnClick", function() NudgeSelectedFrame(0, 1) end)

    local lfgTooltipLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local LO = addon.L
    lfgTooltipLabel:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -8)
    lfgTooltipLabel:SetText((LO and LO["Status Tooltip:"]) or "Status Tooltip:")
    lfgTooltipLabel:Hide()
    panel.lfgTooltipLabel = lfgTooltipLabel

    panel.lfgTooltipButtons = {}
    local lfgButtonLabels = {
        TOP = (LO and LO["Top"]) or "Top",
        BOTTOM = (LO and LO["Bottom"]) or "Bottom",
        LEFT = (LO and LO["Left"]) or "Left",
        RIGHT = (LO and LO["Right"]) or "Right"
    }
    local createdButtons = {}
    for _, position in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local currentPosition = position
        local positionButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        positionButton:SetSize(64, 18)

        if currentPosition == "TOP" then
            positionButton:SetPoint("TOPLEFT", lfgTooltipLabel, "BOTTOMLEFT", 0, -4)
        elseif currentPosition == "BOTTOM" then
            positionButton:SetPoint("LEFT", createdButtons.TOP, "RIGHT", 6, 0)
        elseif currentPosition == "LEFT" then
            positionButton:SetPoint("TOPLEFT", createdButtons.TOP, "BOTTOMLEFT", 0, -4)
        else -- RIGHT
            positionButton:SetPoint("LEFT", createdButtons.LEFT, "RIGHT", 6, 0)
        end

        positionButton:SetText(lfgButtonLabels[currentPosition])
        positionButton:SetFrameLevel(panel:GetFrameLevel() + 5)
        StyleEditorPanelButton(positionButton)
        positionButton:SetScript("OnClick", function()
            SetLFGTooltipPositionValue(currentPosition)
            UpdateEditorPanelLFGTooltipControls()
            UpdateEditorPanelResetButton()
        end)
        positionButton:Hide()

        panel.lfgTooltipButtons[currentPosition] = positionButton
        createdButtons[currentPosition] = positionButton
    end

    local resetSelectedButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetSelectedButton:SetSize(160, 20)
    resetSelectedButton:SetPoint("BOTTOM", panel, "BOTTOM", 0, 6)
    resetSelectedButton:SetText((addon.L and addon.L["Right-click to reset"]) or "Reset")
    resetSelectedButton:SetFrameLevel(panel:GetFrameLevel() + 5)
    StyleEditorPanelButton(resetSelectedButton)
    resetSelectedButton:SetScript("OnClick", function(self)
        local action, frameData = GetDetachedResetActionForSelection()
        if not action then
            self:Hide()
            return
        end

        if selectedEditorFrame then
            selectedEditorFrame.DragonUI_WasDragged = nil
            selectedEditorFrame.DragonUI_WasAdjustedByEditor = nil
        end

        action()

        if frameData and frameData.showTest then
            frameData.showTest()
        end

        UpdateEditorPanelResetButton()
        UpdateEditorPanelCoords()
    end)
    resetSelectedButton:Hide()
    panel.resetSelectedButton = resetSelectedButton

    -- Continuous coordinate polling while the panel is visible.
    -- This is simpler and more reliable than per-frame OnUpdate scripts
    -- since it works for every frame type (CreateUIFrame, lootroll, quest, etc.)
    panel:SetScript("OnUpdate", function()
        UpdateEditorPanelCoords()
        UpdateEditorPanelResetButton()
        UpdateEditorPanelLFGTooltipControls()
    end)

    panel:Hide()
    editorPanel = panel
    return panel
end

-- Apply a green tint to the nineslice to visually mark the "selected" frame
ApplySelectionTint = function(frame)
    local slice = frame and frame.NineSlice
    if not slice then return end
    if slice.Center then slice.Center:SetVertexColor(0.2, 1.0, 0.3, 0.5) end
    for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                          "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
        if slice[key] then slice[key]:SetVertexColor(0.2, 1.0, 0.3) end
    end
end

-- Remove the selection tint (restore default texture color)
ClearSelectionTint = function(frame)
    local slice = frame and frame.NineSlice
    if not slice then return end
    if slice.Center then slice.Center:SetVertexColor(1, 1, 1, 1) end
    for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                          "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
        if slice[key] then slice[key]:SetVertexColor(1, 1, 1) end
    end
end

-- Select a frame for coordinate display and nudging
function addon.SelectEditorFrame(frame)
    -- Deselect previous
    if selectedEditorFrame and selectedEditorFrame ~= frame then
        if selectedEditorFrame.NineSlice then
            ClearSelectionTint(selectedEditorFrame)
            SetNinesliceState(selectedEditorFrame, false)
        end
    end

    selectedEditorFrame = frame
    addon.selectedEditorFrame = frame

    -- Show selected nineslice state with green tint
    if frame.NineSlice then
        SetNinesliceState(frame, true)
        ApplySelectionTint(frame)
    end

    -- Resolve display name from editorText (avoids AceLocale strict errors)
    local panel = CreateEditorControlPanel()
    local displayName
    if frame.editorText and frame.editorText.GetText then
        displayName = frame.editorText:GetText()
    end
    if not displayName or displayName == "" then
        for name, _ in pairs(addon.EditableFrames) do
            if addon.EditableFrames[name].frame == frame then
                displayName = name
                break
            end
        end
    end
    panel.nameLabel:SetText(displayName or "Frame")
    UpdateEditorPanelCoords()
    UpdateEditorPanelLFGTooltipControls()
    UpdateEditorPanelResetButton()
    panel:Show()
end

-- Expose tint helpers and selectedEditorFrame for external modules
addon.ApplySelectionTint = function(f) ApplySelectionTint(f) end
addon.ClearSelectionTint = function(f) ClearSelectionTint(f) end
addon.selectedEditorFrame = nil  -- updated below via SelectEditorFrame

-- Clear selection state
function addon.DeselectEditorFrame()
    if selectedEditorFrame and selectedEditorFrame.NineSlice then
        ClearSelectionTint(selectedEditorFrame)
        SetNinesliceState(selectedEditorFrame, false)
    end
    selectedEditorFrame = nil
    addon.selectedEditorFrame = nil
    if editorPanel then
        editorPanel.nameLabel:SetText("\226\128\148")
        editorPanel.xValue:SetText("\226\128\148")
        editorPanel.yValue:SetText("\226\128\148")
        UpdateEditorPanelLFGTooltipControls()
        UpdateEditorPanelResetButton()
    end
end

-- Show all frames in editor mode
function addon:ShowAllEditableFrames()
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            -- Skip frames that explicitly declare they shouldn't appear in editor
            if frameData.editorVisible and not frameData.editorVisible() then
                frameData.frame:Hide()
            else
                addon.HideUIFrame(frameData.frame) -- Show green overlay

                -- Show frame with fake data if needed
                if frameData.showTest then
                    frameData.showTest()
                end

                if frameData.onShow then
                    frameData.onShow()
                end
            end
        end
    end
    local L = addon.L
    print("|cFF00FF00[DragonUI]|r " .. (L and L["All editable frames shown for editing"] or "All editable frames shown for editing"))

    -- Show editor control panel
    CreateEditorControlPanel()
    if editorPanel then
        addon.DeselectEditorFrame()
        editorPanel:Show()
    end
end

-- Hide all frames and save positions
function addon:HideAllEditableFrames(refresh)
    -- Hide editor control panel and clear selection
    addon.DeselectEditorFrame()
    if editorPanel then
        editorPanel:Hide()
    end

    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            addon.ShowUIFrame(frameData.frame) -- Hide green overlay
            
            -- Hide fake frame if it shouldn't be visible
            if frameData.hideTest then
                frameData.hideTest()
            end
            
            if refresh then
                -- Save position automatically (skip if configPath is nil - custom save logic)
                if frameData.configPath then
                    if #frameData.configPath == 2 then
                        addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                    else
                        addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                    end
                end
                
                if frameData.onHide then
                    frameData.onHide()
                end
            end
        end
    end
    local L = addon.L
    print("|cFF00FF00[DragonUI]|r " .. (L and L["All editable frames hidden, positions saved"] or "All editable frames hidden, positions saved"))
end

-- Check if a frame should be visible
function addon:ShouldFrameBeVisible(frameName)
    local frameData = self.EditableFrames[frameName]
    if not frameData then return false end
    
    if frameData.hasTarget then
        return frameData.hasTarget()
    end
    
    -- By default, frames are always visible (player, minimap)
    return true
end

-- Get information about a registered frame
function addon:GetEditableFrameInfo(frameName)
    return self.EditableFrames[frameName]
end

-- ============================================================================
-- MODULE REGISTRY SYSTEM
-- ============================================================================
-- Central registry for all DragonUI modules.
-- Provides: auto-discovery, status reporting, batch enable/disable operations.
-- Modules self-register during load, making the system extensible.

addon.ModuleRegistry = addon.ModuleRegistry or {
    -- Registered modules: { [name] = { module, displayName, description, order } }
    modules = {},
    -- Load order for enable/disable operations
    loadOrder = {},
    -- Counter for auto-ordering
    orderCounter = 0,
    legacyRefreshTargets = {},
}

local MR = addon.ModuleRegistry

local MODULE_LIFECYCLE_OVERRIDES = {
    boss = {
        refresh = "RefreshBossFrames",
        loadOnce = true,
        isEnabled = function()
            return addon.UF and addon.UF.IsEnabled and addon.UF.IsEnabled("boss")
        end,
    },
    buffs = {
        refresh = "RefreshBuffFrame",
        loadOnce = true,
        isEnabled = function()
            return addon.db and addon.db.profile and addon.db.profile.buffs and addon.db.profile.buffs.enabled
        end,
    },
    buttons = { refresh = "RefreshButtons", loadOnce = true },
    chatmods = {
        apply = "ApplyChatModsSystem",
        restore = "RestoreChatModsSystem",
        loadOnce = true,
    },
    combuctor = {
        apply = "ApplyCombuctorSystem",
        restore = "RestoreCombuctorSystem",
        loadOnce = true,
    },
    cooldowns = { refresh = "RefreshCooldowns", loadOnce = true },
    darkmode = { apply = "ApplyDarkMode", restore = "RestoreDarkMode", loadOnce = true },
    itemquality = {
        apply = "ApplyItemQualitySystem",
        restore = "RestoreItemQualitySystem",
        loadOnce = true,
    },
    mainbars = { refresh = "RefreshMainbarsSystem", loadOnce = true },
    micromenu = { refresh = "RefreshMicromenuSystem", loadOnce = true },
    minimap = { refresh = "RefreshMinimapSystem", loadOnce = true },
    nameplates = {
        apply = "ApplyNameplatesSystem",
        restore = "RestoreNameplatesSystem",
        refresh = "RefreshNameplates",
        loadOnce = true,
    },
    multicast = { refresh = "RefreshMulticast", loadOnce = true },
    noop = { refresh = "RefreshNoopSystem", loadOnce = true },
    petbar = { refresh = "RefreshPetbarSystem", loadOnce = true },
    player = {
        refresh = function()
            if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                addon.PlayerFrame.RefreshPlayerFrame()
            end
        end,
        loadOnce = true,
        isEnabled = function()
            return addon.UF and addon.UF.IsEnabled and addon.UF.IsEnabled("player")
        end,
    },
    questtracker = { refresh = "RefreshQuestTracker", loadOnce = true },
    stance = { refresh = "RefreshStanceSystem", loadOnce = true },
    tooltip = {
        apply = "ApplyTooltipSystem",
        restore = "RestoreTooltipSystem",
        loadOnce = true,
    },
    unitframe_layers = { refresh = "RefreshUnitFrameLayers", loadOnce = true },
    vehicle = { refresh = "RefreshVehicleSystem", loadOnce = true },
}

local DEFAULT_LEGACY_REFRESH_TARGETS = {
    { name = "targetframe", funcName = "RefreshTargetFrame", order = 900 },
    { name = "focusframe", funcName = "RefreshFocusFrame", order = 910 },
    { name = "partyframes", funcName = "RefreshPartyFrames", order = 920 },
}

local function ResolveRegistryFunction(info, phase)
    local mod = info and info.module
    local override = info and info.lifecycle or nil
    local prefix = info and info.lifecyclePrefix or nil
    local candidates = {}

    if override and override[phase] then
        table.insert(candidates, override[phase])
    end

    if phase == "refresh" then
        table.insert(candidates, "Refresh" .. prefix .. "System")
        table.insert(candidates, "Refresh" .. prefix)
        table.insert(candidates, "Refresh")
        table.insert(candidates, "OnProfileChanged")
        table.insert(candidates, "Enable")
    elseif phase == "apply" then
        table.insert(candidates, "Apply" .. prefix .. "System")
        table.insert(candidates, "Apply" .. prefix)
        table.insert(candidates, "Apply")
        table.insert(candidates, "Enable")
        table.insert(candidates, "OnEnable")
    elseif phase == "restore" then
        table.insert(candidates, "Restore" .. prefix .. "System")
        table.insert(candidates, "Restore" .. prefix)
        table.insert(candidates, "Restore")
        table.insert(candidates, "Disable")
        table.insert(candidates, "OnDisable")
    end

    for _, candidate in ipairs(candidates) do
        if type(candidate) == "function" then
            return candidate, false
        end
        if type(candidate) == "string" then
            if mod and type(mod[candidate]) == "function" then
                return mod[candidate], true
            end
            if type(addon[candidate]) == "function" then
                return addon[candidate], false
            end
        end
    end

    return nil, false
end

-- Register a module with the registry
-- @param name: Unique module identifier (matches database key in profile.modules)
-- @param moduleTable: The module state table (e.g., StanceModule)
-- @param displayName: Human-readable name for UI display
-- @param description: Description for tooltips (optional)
-- @param order: Load order number (optional, auto-assigned if nil)
function MR:Register(name, moduleTable, displayName, description, orderOrOptions)
    local L = addon.L

    if not name or not moduleTable then
        addon:Error((L and L["ModuleRegistry:Register requires name and moduleTable"]) or "ModuleRegistry:Register requires name and moduleTable")
        return false
    end
    
    -- Prevent duplicate registration
    if self.modules[name] then
        addon:Debug((L and L["ModuleRegistry: Module already registered -"]) or "ModuleRegistry: Module already registered -", name)
        return false
    end
    
    -- Auto-assign order if not provided
    local options = nil
    if type(orderOrOptions) == "table" then
        options = orderOrOptions
    elseif type(orderOrOptions) == "number" then
        options = { order = orderOrOptions }
    else
        options = {}
    end

    self.orderCounter = self.orderCounter + 1
    local assignedOrder = options.order or self.orderCounter
    local lifecycle = options.lifecycle or MODULE_LIFECYCLE_OVERRIDES[name] or {}
    
    -- Store module info
    self.modules[name] = {
        module = moduleTable,
        displayName = displayName or name,
        description = description or "",
        order = assignedOrder,
        lifecyclePrefix = options.lifecyclePrefix or lifecycle.lifecyclePrefix or UpperCamelCase(name),
        lifecycle = lifecycle,
        loadOnce = options.loadOnce or lifecycle.loadOnce or false,
        isEnabled = options.isEnabled or lifecycle.isEnabled,
    }
    
    -- Add to load order
    table.insert(self.loadOrder, name)
    
    addon:Debug((L and L["ModuleRegistry: Registered module -"]) or "ModuleRegistry: Registered module -", name, (L and L["order:"]) or "order:", assignedOrder)
    return true
end

function MR:RegisterLegacyRefreshTarget(name, funcName, order)
    if not name or not funcName then
        return false
    end

    self.legacyRefreshTargets[name] = {
        funcName = funcName,
        order = order or 1000,
    }

    return true
end

function MR:EnsureLegacyRefreshTargets()
    if next(self.legacyRefreshTargets) then
        return
    end

    for _, target in ipairs(DEFAULT_LEGACY_REFRESH_TARGETS) do
        self:RegisterLegacyRefreshTarget(target.name, target.funcName, target.order)
    end
end

-- Get a registered module by name
-- @param name: Module identifier
-- @return moduleTable or nil
function MR:Get(name)
    local info = self.modules[name]
    return info and info.module or nil
end

-- Get module info (name, description, order)
-- @param name: Module identifier
-- @return table { module, displayName, description, order } or nil
function MR:GetInfo(name)
    return self.modules[name]
end

-- Get all registered module names
-- @return table (array) of module names in load order
function MR:GetAll()
    return self.loadOrder
end

-- Get count of registered modules
-- @return number
function MR:Count()
    return #self.loadOrder
end

-- Check if a module is enabled in database
-- @param name: Module identifier
-- @return boolean
function MR:IsEnabled(name)
    local info = self.modules[name]
    if info and info.isEnabled then
        return info.isEnabled()
    end

    if not addon.db or not addon.db.profile or not addon.db.profile.modules then
        return false
    end

    local cfg = addon.db.profile.modules[name]
    return cfg and cfg.enabled
end

function MR:IsLoadOnce(name)
    local info = self.modules[name]
    return info and info.loadOnce or false
end

function addon:IsModuleLoadOnce(name)
    return MR:IsLoadOnce(name)
end

addon._pendingReloadModules = addon._pendingReloadModules or {}

function addon:ShouldDeferModuleDisable(name, moduleState)
    local L = addon.L

    if not self:IsModuleLoadOnce(name) then
        return false
    end

    if not moduleState or not (moduleState.initialized or moduleState.applied) then
        return false
    end

    if not self._pendingReloadModules[name] then
        self._pendingReloadModules[name] = true
    end

    return true
end

function MR:Refresh(name)
    local L = addon.L

    local info = self.modules[name]
    if not info then
        return false
    end

    local enabled = self:IsEnabled(name)
    local fn, useModuleSelf = ResolveRegistryFunction(info, enabled and "refresh" or "restore")

    -- Modules that install secure hooks cannot be cleanly unhooked during a live
    -- WoW session. Treat them as load-once: honor future config on reload, but do
    -- not run unsafe in-session teardown paths.
    if not enabled and info.loadOnce and info.module and (info.module.initialized or info.module.applied) then
        return true
    end

    if not fn then
        fn, useModuleSelf = ResolveRegistryFunction(info, enabled and "apply" or "restore")
    end

    if not fn then
        return false
    end

    local success, err
    if useModuleSelf then
        success, err = pcall(fn, info.module)
    else
        success, err = pcall(fn, addon)
    end

    if not success then
        addon:Error((L and L["ModuleRegistry: Refresh failed for"]) or "ModuleRegistry: Refresh failed for", name, "-", err)
    end

    return success
end

function MR:RefreshAll()
    local failed = {}
    self:EnsureLegacyRefreshTargets()

    for _, name in ipairs(self.loadOrder) do
        if not self:Refresh(name) then
            table.insert(failed, name)
        end
    end

    local legacyTargets = {}
    for name, info in pairs(self.legacyRefreshTargets) do
        table.insert(legacyTargets, { name = name, funcName = info.funcName, order = info.order })
    end
    table.sort(legacyTargets, function(a, b)
        return a.order < b.order
    end)

    for _, target in ipairs(legacyTargets) do
        local fn = addon[target.funcName]
        if type(fn) == "function" then
            local success, err = pcall(fn, addon)
            if not success then
                addon:Error(L["Legacy refresh failed for"], target.name, "-", err)
                table.insert(failed, target.name)
            end
        end
    end

    return failed
end

-- Enable a specific module
-- @param name: Module identifier
-- @return boolean success
function MR:Enable(name)
    local L = addon.L

    local info = self.modules[name]
    if not info then
        addon:Error((L and L["ModuleRegistry: Unknown module -"]) or "ModuleRegistry: Unknown module -", name)
        return false
    end
    
    -- Update database
    if addon.db and addon.db.profile and addon.db.profile.modules then
        if not addon.db.profile.modules[name] then
            addon.db.profile.modules[name] = {}
        end
        addon.db.profile.modules[name].enabled = true
    end
    
    self:Refresh(name)
    
    addon:Debug((L and L["ModuleRegistry: Enabled -"]) or "ModuleRegistry: Enabled -", name)
    return true
end

-- Disable a specific module
-- @param name: Module identifier
-- @return boolean success
function MR:Disable(name)
    local L = addon.L

    local info = self.modules[name]
    if not info then
        addon:Error((L and L["ModuleRegistry: Unknown module -"]) or "ModuleRegistry: Unknown module -", name)
        return false
    end
    
    -- Update database
    if addon.db and addon.db.profile and addon.db.profile.modules then
        if not addon.db.profile.modules[name] then
            addon.db.profile.modules[name] = {}
        end
        addon.db.profile.modules[name].enabled = false
    end
    
    -- hooksecurefunc / HookScript registrations are permanent for the session.
    -- Keep load-once modules active until reload instead of pretending we can fully disable them.
    if info.loadOnce and info.module and (info.module.initialized or info.module.applied) then
        return true
    end

    self:Refresh(name)
    
    addon:Debug((L and L["ModuleRegistry: Disabled -"]) or "ModuleRegistry: Disabled -", name)
    return true
end

-- Enable all registered modules (in load order)
function MR:EnableAll()
    for _, name in ipairs(self.loadOrder) do
        self:Enable(name)
    end
end

-- Disable all registered modules (in reverse load order for proper cleanup)
function MR:DisableAll()
    for i = #self.loadOrder, 1, -1 do
        self:Disable(self.loadOrder[i])
    end
end

-- Print status of all registered modules (for /dragonui status)
function MR:PrintStatus()
    local L = addon.L

    if #self.loadOrder == 0 then
        print("  " .. ((L and L["No modules registered in ModuleRegistry"]) or "No modules registered in ModuleRegistry"))
        return
    end
    
    print("  |cFF00FF00" .. ((L and L["Registered Modules:"]) or "Registered Modules:") .. "|r")
    for _, name in ipairs(self.loadOrder) do
        local info = self.modules[name]
        local enabled = self:IsEnabled(name)
        local status = enabled and ("|cFF00FF00" .. ((L and L["Enabled"]) or "Enabled") .. "|r") or ("|cFFFF0000" .. ((L and L["Disabled"]) or "Disabled") .. "|r")
        local loaded = info.module and (info.module.initialized or info.module.applied) and ("|cFF00FF00" .. ((L and L["Loaded"]) or "Loaded") .. "|r") or "|cFFAAAAAA-|r"
        
        local mode = info.loadOnce and (" |cFFFFD200(" .. ((L and L["load-once"]) or "load-once") .. ")|r") or ""
        print(string.format("    %s: %s (%s)%s", info.displayName, status, loaded, mode))
    end
end

-- Convenience function for modules to register themselves
-- @param name: Module identifier
-- @param moduleTable: Module state table
-- @param displayName: Display name (optional)
-- @param description: Description (optional)
function addon:RegisterModule(name, moduleTable, displayName, description, options)
    return MR:Register(name, moduleTable, displayName, description, options)
end

function addon:RegisterLegacyRefreshTarget(name, funcName, order)
    return MR:RegisterLegacyRefreshTarget(name, funcName, order)
end

function addon:RefreshRegisteredSystems()
    return MR:RefreshAll()
end

-- ============================================================================
-- COMBAT QUEUE SYSTEM
-- ============================================================================
-- Central system for deferring operations that cannot run during combat lockdown.
-- Pattern: Check InCombatLockdown() -> if true, queue operation -> execute after combat
-- Reference: common PLAYER_REGEN_ENABLED deferred-execution pattern

addon.CombatQueue = addon.CombatQueue or {
    -- Pending operations table: { [id] = { func, args } }
    pending = {},
    -- Is the event frame registered?
    isRegistered = false,
    -- Event frame for PLAYER_REGEN_ENABLED
    eventFrame = nil,
}

local CQ = addon.CombatQueue

-- Initialize the combat queue event frame
local function InitializeCombatQueueFrame()
    if CQ.eventFrame then return end
    
    CQ.eventFrame = CreateFrame("Frame", "DragonUI_CombatQueueFrame", UIParent)
    CQ.eventFrame:Hide()
    CQ.eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            addon.CombatQueue:ProcessQueue()
        end
    end)
end

-- Add an operation to the combat queue
-- @param id: Unique identifier for this operation (prevents duplicates)
-- @param func: Function to call when combat ends
-- @param ...: Arguments to pass to the function
function CQ:Add(id, func, ...)
    local L = addon.L

    if not id or not func then
        addon:Error((L and L["CombatQueue:Add requires id and func"]) or "CombatQueue:Add requires id and func")
        return false
    end
    
    -- Initialize frame if needed
    InitializeCombatQueueFrame()
    
    -- Store the operation with its arguments
    self.pending[id] = { func = func, args = {...} }
    
    -- Register for PLAYER_REGEN_ENABLED if not already
    if not self.isRegistered then
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.isRegistered = true
        addon:Debug((L and L["CombatQueue: Registered PLAYER_REGEN_ENABLED"]) or "CombatQueue: Registered PLAYER_REGEN_ENABLED")
    end
    
    addon:Debug((L and L["CombatQueue: Queued operation -"]) or "CombatQueue: Queued operation -", id)
    return true
end

-- Remove an operation from the queue (if no longer needed)
-- @param id: Identifier of the operation to remove
function CQ:Remove(id)
    local L = addon.L

    if self.pending[id] then
        self.pending[id] = nil
        addon:Debug((L and L["CombatQueue: Removed operation -"]) or "CombatQueue: Removed operation -", id)
    end
    
    -- If queue is empty, unregister the event
    if not next(self.pending) and self.isRegistered then
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self.isRegistered = false
    end
end

-- Check if an operation is in the queue
-- @param id: Identifier to check
function CQ:HasPending(id)
    return self.pending[id] ~= nil
end

-- Process all queued operations (called on PLAYER_REGEN_ENABLED)
function CQ:ProcessQueue()
    local L = addon.L

    addon:Debug((L and L["CombatQueue: Processing"]) or "CombatQueue: Processing", addon:tcount(self.pending), (L and L["queued operations"]) or "queued operations")
    
    -- Process all pending operations
    for id, operation in pairs(self.pending) do
        local success, err = pcall(function()
            operation.func(unpack(operation.args))
        end)
        
        if not success then
            addon:Error((L and L["CombatQueue: Failed to execute"]) or "CombatQueue: Failed to execute", id, "-", err)
        else
            addon:Debug((L and L["CombatQueue: Executed -"]) or "CombatQueue: Executed -", id)
        end
    end
    
    -- Clear all pending operations
    self.pending = {}
    
    -- Unregister the event
    if self.isRegistered then
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self.isRegistered = false
        addon:Debug((L and L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"]) or "CombatQueue: Unregistered PLAYER_REGEN_ENABLED")
    end
end

-- Execute immediately if out of combat, queue if in combat
-- @param id: Unique identifier for this operation
-- @param func: Function to call
-- @param ...: Arguments to pass to the function
-- @return true if executed immediately, false if queued
function CQ:ExecuteOrQueue(id, func, ...)
    local L = addon.L

    if InCombatLockdown() then
        self:Add(id, func, ...)
        return false
    else
        -- Execute immediately
        local args = {...}
        local success, err = pcall(function()
            func(unpack(args))
        end)
        
        if not success then
            addon:Error((L and L["CombatQueue: Immediate execution failed -"]) or "CombatQueue: Immediate execution failed -", id, "-", err)
        end
        return true
    end
end

-- Convenience function for modules to check and queue
-- Returns true if operation can proceed (not in combat)
-- @param moduleId: Module name for the queue ID
-- @param operationName: Name of the operation (combined with moduleId)
-- @param func: Function to call when combat ends
-- @param ...: Arguments
function addon:SafeExecute(moduleId, operationName, func, ...)
    local queueId = moduleId .. "_" .. operationName
    return CQ:ExecuteOrQueue(queueId, func, ...)
end

-- ============================================================================
-- MODULE HELPERS (centralized — replaces per-module boilerplate)
-- ============================================================================

-- No-op function reusable across all modules (avoids multiple definitions)
addon._noop = addon._noop or function() end

-- Get module config from addon.db.profile.modules[moduleName]
-- @param moduleName: string key matching database.lua modules table
-- @return table or nil
function addon:GetModuleConfig(moduleName)
    return self.db and self.db.profile and self.db.profile.modules
        and self.db.profile.modules[moduleName]
end

-- Check if a module is enabled in the database
-- @param moduleName: string key matching database.lua modules table
-- @return boolean
function addon:IsModuleEnabled(moduleName)
    local cfg = self:GetModuleConfig(moduleName)
    return cfg and cfg.enabled or false
end

-- ============================================================================
-- DELAYED EXECUTION (unified timer — replaces 3 different implementations)
-- ============================================================================

-- Frame pool for delayed execution (C_Timer replacement for 3.3.5a)
addon._timerPool = addon._timerPool or {}

-- Schedule a callback after a delay (seconds)
-- @param delay: number — seconds to wait
-- @param callback: function — called after delay
function addon:After(delay, callback)
    if type(callback) ~= "function" then
        return
    end

    delay = tonumber(delay) or 0
    if delay < 0 then
        delay = 0
    end

    local f = tremove(self._timerPool) or CreateFrame("Frame")
    f._elapsed = 0
    f._delay = delay
    f._callback = callback
    f:SetScript("OnUpdate", function(self, dt)
        self._elapsed = self._elapsed + dt
        if self._elapsed >= self._delay then
            self:SetScript("OnUpdate", nil)
            tinsert(addon._timerPool, self)
            local cb = self._callback
            self._callback = nil
            cb()
        end
    end)
end

function addon:SafeSetAtlas(texture, atlasName, useAtlasSize)
    if not texture or not atlasName then
        return false
    end

    if texture.set_atlas then
        local ok = pcall(texture.set_atlas, texture, atlasName, useAtlasSize)
        return ok
    end

    return false
end

function addon:SafeSetTexture(texture, path, fallback)
    if not texture then
        return false
    end

    if path and path ~= "" then
        texture:SetTexture(path)
        return true
    end

    if fallback and fallback ~= "" then
        texture:SetTexture(fallback)
        return true
    end

    texture:SetTexture(nil)
    return false
end

function addon:ApplyDatabaseMigrations()
    if not self.db or not self.db.profile then
        return
    end

    local profile = self.db.profile
    local currentVersion = tonumber(profile.version) or 0

    if currentVersion < self.DB_SCHEMA_VERSION then
        ApplyMissingDefaults(self.defaults.profile, profile)
    end

    profile.version = self.DB_SCHEMA_VERSION
    self.db.version = self.DB_SCHEMA_VERSION
end

-- ============================================================================
-- PRINT / DEBUG UTILITIES
-- ============================================================================

-- Print a formatted message
function addon:Print(...)
    print("|cFF00FF00[DragonUI]|r", ...)
end

-- Print a debug message (only in debug mode)
function addon:Debug(...)
    if addon.debugMode then
        print("|cFFFFFF00[DragonUI Debug]|r", ...)
    end
end

-- Print an error message
function addon:Error(...)
    print("|cFFFF0000[DragonUI Error]|r", ...)
end
