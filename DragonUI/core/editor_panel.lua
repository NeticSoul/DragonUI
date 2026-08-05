-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local L = addon.L

-- Assigned further down; api.lua reaches them through the addon.* wrappers exported at the end of this file.
local ApplySelectionTint, ClearSelectionTint
local editorPanel, selectedEditorFrame

-- ============================================================================
-- EDITOR CONTROL PANEL (Real-time X/Y + Nudge Buttons)
-- ============================================================================

-- GetCenter() is in the frame's own scaled local space, not screen pixels, so a raw cx-ux breaks once scale != 1.
local function GetFrameOffsetFromUIParent(frame)
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then return nil end
    local frameScale = frame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    local x = (cx * frameScale - ux * uiScale) / frameScale
    local y = (cy * frameScale - uy * uiScale) / frameScale
    return x, y
end

-- Update the coordinate display with current frame position.
-- Uses GetCenter() for screen-relative coords that always reflect the
-- actual visual position (GetPoint offsets can be stale during StartMoving).
-- Skips update while the user is actively typing in an EditBox.
local function UpdateEditorPanelCoords()
    if not editorPanel or not selectedEditorFrame then return end
    local x, y = GetFrameOffsetFromUIParent(selectedEditorFrame)
    if x and y then
        local xStr = string.format("%.1f", x)
        local yStr = string.format("%.1f", y)
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
                if frameData.onNudge then
                    frameData.onNudge()
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

    local relX, relY = GetFrameOffsetFromUIParent(selectedEditorFrame)
    if not relX or not relY then return end

    relX = relX + dx
    relY = relY + dy

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
                if frameData.onNudge then
                    frameData.onNudge()
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
    elseif frameName == "PetFrame" then
        local cfg = addon.db.profile.unitframe and addon.db.profile.unitframe.pet
        if cfg and cfg.override and addon.RefreshPetFrame then
            return function()
                if ResetDetachedUnitframeToProfileDefaults("pet") then
                    addon.RefreshPetFrame()
                end
            end, frameData
        end
    elseif frameName == "Debuffs" then
        local cfg = addon.db.profile.widgets and addon.db.profile.widgets.debuffs
        if cfg and cfg.custom_position and addon.BuffFrameModule and addon.BuffFrameModule.ResetDebuffPosition then
            return function()
                addon.BuffFrameModule:ResetDebuffPosition()
            end, frameData
        end
    elseif frameName == "buffs" then
        local cfg = addon.db.profile.widgets and addon.db.profile.widgets.buffs
        if cfg and cfg.custom_position and addon.BuffFrameModule and addon.BuffFrameModule.ResetBuffFramePosition then
            return function()
                addon.BuffFrameModule:ResetBuffFramePosition()
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
    resetSelectedButton:SetText((addon.L and addon.L["Click to reset"]) or "Reset")
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
            addon.SetNinesliceState(selectedEditorFrame, false)
        end
    end

    selectedEditorFrame = frame
    addon.selectedEditorFrame = frame

    -- Show selected nineslice state with green tint
    if frame.NineSlice then
        addon.SetNinesliceState(frame, true)
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
        addon.SetNinesliceState(selectedEditorFrame, false)
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
    addon:Print((L and L["All editable frames shown for editing"] or "All editable frames shown for editing"))

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
    addon:Print((L and L["All editable frames hidden, positions saved"] or "All editable frames hidden, positions saved"))
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

