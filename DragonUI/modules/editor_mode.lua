-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI - Editor Mode
-- Provides a visual grid overlay and controls for repositioning UI elements.
-- ============================================================================

local addon = select(2, ...);
local L = addon.L

local EditorMode = {};
addon.EditorMode = EditorMode;

local gridOverlay = nil;
local manager = nil;
local editorActive = false;
local errorMessagesMover = nil;
local errorMessagesPositionHooked = false;

-- The overlay hugs one error line, which sits this far above the centre of the 512x60 error frame.
local ERROR_MOVER_WIDTH, ERROR_MOVER_HEIGHT, ERROR_ROW_OFFSET = 280, 32, 20

local function GetWidgetConfig(widgetName)
    return addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets[widgetName]
end

local function ApplyErrorMessagesPosition()
    local cfg = GetWidgetConfig("errorMessages")
    if not UIErrorsFrame or not cfg or not cfg.custom_position then
        return
    end

    if UIPARENT_MANAGED_FRAME_POSITIONS and UIPARENT_MANAGED_FRAME_POSITIONS.UIErrorsFrame then
        UIErrorsFrame.ignoreFramePositionManager = true
    end

    if UIErrorsFrame.SetUserPlaced and (UIErrorsFrame:IsMovable() or UIErrorsFrame:IsResizable()) then
        UIErrorsFrame:SetUserPlaced(nil)
    end

    UIErrorsFrame:ClearAllPoints()
    UIErrorsFrame:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.posX or 0, cfg.posY or 160)
end

addon.ApplyErrorMessagesPosition = ApplyErrorMessagesPosition

local function PersistErrorMessagesMoverPosition()
    if not errorMessagesMover or not addon.db or not addon.db.profile then
        return
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets.errorMessages = addon.db.profile.widgets.errorMessages or {}

    local cx, cy = errorMessagesMover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then
        return
    end

    local cfg = addon.db.profile.widgets.errorMessages
    cfg.anchor = "CENTER"
    cfg.posX = math.floor((cx - ux) + 0.5)
    cfg.posY = math.floor((cy - uy) - ERROR_ROW_OFFSET + 0.5)
    cfg.custom_position = true
end

local function SetupErrorMessagesMover()
    if errorMessagesMover or not addon.CreateUIFrame then
        return
    end

    errorMessagesMover = addon.CreateUIFrame(ERROR_MOVER_WIDTH, ERROR_MOVER_HEIGHT, "ErrorMessages")
    errorMessagesMover:HookScript("OnDragStop", function(self)
        self.DragonUI_WasDragged = true
        PersistErrorMessagesMoverPosition()
        ApplyErrorMessagesPosition()
    end)

    if errorMessagesMover.editorText then
        errorMessagesMover.editorText:SetText(L["Error Messages"])
        errorMessagesMover.editorText:ClearAllPoints()
        errorMessagesMover.editorText:SetPoint("TOP", errorMessagesMover, "BOTTOM", 0, -3)
    end

    -- A sample line in the real error frame's strata, so it sits under the overlay like the other previews.
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetFrameStrata("HIGH")
    holder:SetSize(ERROR_MOVER_WIDTH, ERROR_MOVER_HEIGHT)
    holder:SetPoint("CENTER", errorMessagesMover, "CENTER", 0, 0)
    holder:Hide()
    local sample = holder:CreateFontString(nil, "OVERLAY", "ErrorFont")
    sample:SetPoint("CENTER", holder, "CENTER", 0, 0)
    sample:SetText(_G.ERR_OUT_OF_MANA or "Not enough mana.")
    sample:SetTextColor(1, 0.1, 0.1)
    errorMessagesMover.sample = holder

    addon:RegisterEditableFrame({
        name = "errorMessages",
        frame = errorMessagesMover,
        blizzardFrame = UIErrorsFrame,
        showTest = function()
            local cfg = GetWidgetConfig("errorMessages")
            errorMessagesMover:ClearAllPoints()
            if cfg and cfg.custom_position then
                errorMessagesMover:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER",
                    cfg.posX or 0, (cfg.posY or 160) + ERROR_ROW_OFFSET)
            elseif UIErrorsFrame then
                errorMessagesMover:SetPoint("CENTER", UIErrorsFrame, "CENTER", 0, ERROR_ROW_OFFSET)
            else
                errorMessagesMover:SetPoint("CENTER", UIParent, "CENTER", 0, 160 + ERROR_ROW_OFFSET)
            end
            errorMessagesMover:Show()
            errorMessagesMover.sample:Show()
        end,
        hideTest = function()
            errorMessagesMover.sample:Hide()
        end,
        onHide = function()
            if errorMessagesMover.DragonUI_WasDragged or errorMessagesMover.DragonUI_WasAdjustedByEditor then
                PersistErrorMessagesMoverPosition()
                errorMessagesMover.DragonUI_WasDragged = nil
                errorMessagesMover.DragonUI_WasAdjustedByEditor = nil
            end
            ApplyErrorMessagesPosition()
        end,
        module = EditorMode
    })

    if not errorMessagesPositionHooked then
        errorMessagesPositionHooked = true
        if UIParent_ManageFramePositions then
            hooksecurefunc("UIParent_ManageFramePositions", function()
                ApplyErrorMessagesPosition()
            end)
        end
    end
end

-- StaticPopup to reload UI after exiting editor mode
StaticPopupDialogs["DRAGONUI_EDITOR_RELOAD_UI"] = {
    text = L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"],
    button1 = L["Reload Now"],
    button2 = L["Later"],
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ============================================================================
-- BUTTON STYLING (matches DragonUI Options panel theme)
-- ============================================================================
local BD_EDITOR_BUTTON = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

function addon.StyleEditorButton(button)
    -- Strip all template textures (Left/Middle/Right sub-textures)
    local name = button:GetName()
    if name then
        for _, suffix in ipairs({"Left", "Middle", "Right"}) do
            local tex = _G[name .. suffix]
            if tex and tex.SetTexture then
                tex:SetTexture(nil)
                tex:SetAlpha(0)
                tex:Hide()
            end
        end
    end

    -- Strip Normal/Pushed/Highlight/Disabled textures
    if button:GetNormalTexture() then button:GetNormalTexture():SetTexture(nil); button:GetNormalTexture():SetAlpha(0) end
    if button:GetPushedTexture() then button:GetPushedTexture():SetTexture(nil); button:GetPushedTexture():SetAlpha(0) end
    if button:GetHighlightTexture() then button:GetHighlightTexture():SetTexture(nil); button:GetHighlightTexture():SetAlpha(0) end
    if button:GetDisabledTexture() then button:GetDisabledTexture():SetTexture(nil); button:GetDisabledTexture():SetAlpha(0) end

    -- Apply dark backdrop with subtle blue-accent border
    button:SetBackdrop(BD_EDITOR_BUTTON)
    button:SetBackdropColor(0.16, 0.16, 0.18, 1)
    button:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.6) -- Blue accent border

    -- Create highlight overlay with blue tint
    if not button._dragonHighlight then
        local hl = button:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        hl:SetVertexColor(0.09, 0.52, 0.82, 0.25)
        hl:SetAllPoints()
        button._dragonHighlight = hl
    end

    -- Style text: clean modern font (locale-aware via addon.Fonts)
    local fontString = button:GetFontString()
    if fontString then
        fontString:SetTextColor(0.9, 0.9, 0.9, 1)
        local fontPath = (addon.Fonts and addon.Fonts.NARROW) or "Interface\\AddOns\\DragonUI_Options\\fonts\\PTSansNarrow.ttf"
        fontString:SetFont(fontPath, 12, "")
    end
end

-- ============================================================================
-- MANAGER (top-centre window: layout presets, grid, reset and exit)
-- ============================================================================

local MANAGER_WIDTH = 510
local MANAGER_WIDGET_KEY = "positionPresetPanel"
-- Rows start under the Show Grid row (GRID_BOTTOM); the footer is the gap, the 28 px buttons and their margin.
local MANAGER_PAD_X = 26
local MANAGER_ROW_WIDTH = MANAGER_WIDTH - 2 * MANAGER_PAD_X
local MANAGER_GRID_BOTTOM = 118
local MANAGER_FOOTER = 62
local MANAGER_SECTION_GAP, MANAGER_HEADER_HEIGHT, MANAGER_ROW_GAP = 8, 26, 2
local MANAGER_ROWS_INTERVAL = 0.2
local CLICK_SLOP = 8

local managerSet, generalHeader, clickWatcher

local function IsGridEnabled()
    local profile = addon.db and addon.db.profile
    return not (profile and profile.editorShowGrid == false)
end

local function ApplyGridVisibility()
    if not gridOverlay then return end
    if editorActive and IsGridEnabled() then
        gridOverlay:Show()
    else
        gridOverlay:Hide()
    end
end

function EditorMode:SetGridShown(shown)
    if addon.db and addon.db.profile then
        if shown then
            addon.db.profile.editorShowGrid = nil
        else
            addon.db.profile.editorShowGrid = false
        end
    end
    ApplyGridVisibility()
end

-- A dragged frame is re-anchored by its top-left so rows added later grow downwards.
local function AnchorManagerTopLeft(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return nil end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, top * ratio)
    return left * ratio, top * ratio
end

local function SaveManagerPosition()
    if not manager or not addon.db or not addon.db.profile then return end

    local x, y = AnchorManagerTopLeft(manager)
    if not x then return end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets[MANAGER_WIDGET_KEY] = {
        anchor = "TOPLEFT",
        relativePoint = "BOTTOMLEFT",
        posX = math.floor(x + 0.5),
        posY = math.floor(y + 0.5),
        custom_position = true,
    }
end

local function ApplyManagerPosition(frame)
    local widgets = addon.db and addon.db.profile and addon.db.profile.widgets
    local cfg = widgets and widgets[MANAGER_WIDGET_KEY]
    frame:ClearAllPoints()
    if cfg and cfg.custom_position then
        frame:SetPoint(cfg.anchor or "TOPLEFT", UIParent, cfg.relativePoint or "BOTTOMLEFT", cfg.posX or 0, cfg.posY or 0)
        return true
    end
    frame:SetPoint("TOP", UIParent, "TOP", 0, -60)
    return false
end

-- Combat leaves the window read-only: exiting would touch overlays anchored to protected frames.
local function SetManagerLocked(locked)
    if not manager then return end
    for _, control in ipairs({ manager.layoutDropdown, manager.resetButton, manager.exitButton }) do
        if locked then control:Disable() else control:Enable() end
    end
    if locked and addon.Menu then addon.Menu.Close() end
    if managerSet then managerSet:SetLocked(locked) end
end

-- Rows of the "__manager" registry entry sit between Show Grid and the buttons; the window grows downwards.
local function LayoutManager()
    if not manager then return end
    local y = MANAGER_GRID_BOTTOM
    local visible = managerSet and managerSet:VisibleCount() or 0
    if visible > 0 then
        y = y + MANAGER_SECTION_GAP
        generalHeader:ClearAllPoints()
        generalHeader:SetPoint("TOPLEFT", manager, "TOPLEFT", MANAGER_PAD_X, -y)
        generalHeader:Show()
        y = y + MANAGER_HEADER_HEIGHT
    else
        generalHeader:Hide()
    end
    local extra = 0
    if managerSet then
        local panel = addon.EditorPanel
        local bottom
        bottom, extra = panel.LayoutRows(managerSet, manager, MANAGER_PAD_X, y, MANAGER_ROW_GAP,
            panel.MaxHeight() - y - MANAGER_FOOTER)
        if visible > 0 then y = bottom - MANAGER_ROW_GAP end
    end
    manager:SetWidth(MANAGER_WIDTH + extra)
    manager:SetHeight(y + MANAGER_FOOTER)
end

local function RebuildManagerRows()
    if not (manager and managerSet) then return end
    managerSet:Load(addon.EditorPanel.GetDef("__manager"), "__manager")
    LayoutManager()
    local forever = addon.ForeverUI
    if forever.EnforceLayering then forever.EnforceLayering(manager) end
end

function EditorMode:RebuildManager()
    RebuildManagerRows()
end

local function CreateManager()
    if manager then return manager end
    local forever = addon.ForeverUI
    local ui = addon.EditorUI

    local frame = CreateFrame("Frame", "DragonUI_EditorManager", UIParent)
    frame:SetFrameStrata(ui.STRATA)
    frame:SetFrameLevel(ui.MANAGER)
    frame:SetSize(MANAGER_WIDTH, MANAGER_GRID_BOTTOM + MANAGER_FOOTER)
    forever.SkinDialog(frame, { title = L["Editor Mode"] })
    -- The stock close hides the manager first, which would strand an active editor when Hide refuses in combat.
    frame.CloseButton:SetScript("OnClick", function()
        PlaySound("igMainMenuClose")
        EditorMode:Toggle()
    end)
    if ApplyManagerPosition(frame) then
        AnchorManagerTopLeft(frame)
    end
    frame:Hide()
    frame:HookScript("OnDragStop", SaveManagerPosition)
    manager = frame

    -- On Content: a region of the frame itself would sit under the Back child that paints the fill.
    local layoutLabel = frame.Content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    layoutLabel:SetSize(96, 20)
    layoutLabel:SetJustifyH("LEFT")
    layoutLabel:SetPoint("LEFT", frame, "TOPLEFT", 28, -66)
    layoutLabel:SetText(L["Layout"])

    frame.layoutDropdown = addon.PositionPresets:CreateLayoutDropdown(frame, 346)
    frame.layoutDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 136, -54)

    frame.gridCheckbox = forever.CreateCheckbox(frame, L["Show Grid"], function(checked)
        EditorMode:SetGridShown(checked)
    end, { style = "classic" })
    frame.gridCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -86)

    frame.resetButton = forever.CreateButton(frame, L["Reset All Positions"], 220, 28)
    frame.resetButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 24)
    frame.resetButton:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        EditorMode:ShowResetConfirmation()
    end)

    frame.exitButton = forever.CreateButton(frame, L["Exit Edit Mode"], 220, 28)
    frame.exitButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 24)
    frame.exitButton:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        EditorMode:Toggle()
    end)

    -- On Content like the Layout label; hidden until the registry brings rows.
    generalHeader = frame.Content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    generalHeader:SetText(L["General"])
    generalHeader:Hide()
    managerSet = addon.EditorPanel.CreateRowSet(frame, MANAGER_ROW_WIDTH, { onRelayout = LayoutManager })

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.rowsElapsed = (self.rowsElapsed or 0) + elapsed
        if self.rowsElapsed >= MANAGER_ROWS_INTERVAL then
            self.rowsElapsed = 0
            managerSet:Poll()
        end
    end)

    frame:SetScript("OnShow", function(self)
        self.gridCheckbox:SetChecked(IsGridEnabled())
        addon.PositionPresets:RefreshPanel()
        RebuildManagerRows()
        SetManagerLocked(InCombatLockdown() and true or false)
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        SetManagerLocked(event == "PLAYER_REGEN_DISABLED")
    end)

    return frame
end

function EditorMode:GetManager()
    return CreateManager()
end

function EditorMode:ShowManager()
    CreateManager():Show()
end

function EditorMode:HideManager()
    if manager then manager:Hide() end
end

-- Polled, not a WorldFrame hook: nothing captured (camera clicks pass), and a world drag is not a click.
local function CreateClickWatcher()
    if clickWatcher then return clickWatcher end

    local watcher = CreateFrame("Frame", "DragonUI_EditorClickWatcher", UIParent)
    watcher:Hide()
    local origin, startX, startY

    watcher:SetScript("OnUpdate", function()
        if IsMouseButtonDown("LeftButton") then
            if not origin then
                local focus = GetMouseFocus()
                origin = (focus == nil or focus == WorldFrame) and "world" or "ui"
                startX, startY = GetCursorPosition()
            end
        elseif origin then
            local pressedOn = origin
            origin = nil
            if pressedOn == "world" and addon.selectedEditorFrame then
                local x, y = GetCursorPosition()
                local dx, dy = x - startX, y - startY
                if dx * dx + dy * dy <= CLICK_SLOP * CLICK_SLOP then
                    addon.DeselectEditorFrame()
                end
            end
        end
    end)
    watcher:SetScript("OnHide", function()
        origin = nil
    end)

    clickWatcher = watcher
    return watcher
end

-- Create symmetrical grid overlay for alignment
local function createGridOverlay()
    if gridOverlay then return; end

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    -- Split from center outward to ensure exact symmetry
    local cellSize = 32
    
    -- Calculate how many complete cells fit from center to each side
    local halfCellsHorizontal = math.floor((screenWidth / 2) / cellSize)
    local halfCellsVertical = math.floor((screenHeight / 2) / cellSize)
    
    -- Total cells (always even so the center is exact)
    local totalHorizontalCells = halfCellsHorizontal * 2
    local totalVerticalCells = halfCellsVertical * 2
    
    -- Recalculate actual cell size for perfect symmetry
    local actualCellWidth = screenWidth / totalHorizontalCells
    local actualCellHeight = screenHeight / totalVerticalCells
    
    -- Exact center position
    
    gridOverlay = CreateFrame('Frame', "DragonUIGridOverlay", UIParent)
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND")
    gridOverlay:SetFrameLevel(0)

    --  ADD SEMI-TRANSPARENT DARK BACKGROUND LAYER
    local background = gridOverlay:CreateTexture("DragonUIGridBackground", 'BACKGROUND')
    background:SetAllPoints(gridOverlay)
    background:SetTexture(0, 0, 0, 0.3)  -- Semi-transparent black

    local lineThickness = 1

    -- === SYMMETRICAL VERTICAL LINES ===
    for i = 0, totalHorizontalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridV"..i, 'BACKGROUND')
        
        -- The center line is exactly at halfCellsHorizontal
        if i == halfCellsHorizontal then
            line:SetTexture(1, 0, 0, 0.8)  -- EXACT red center line
        else
            line:SetTexture(1, 1, 1, 0.3)  -- Symmetrical white lines
        end
        
        local x = i * actualCellWidth
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", x - (lineThickness / 2), 0)
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'BOTTOMLEFT', x + (lineThickness / 2), 0)
    end

    -- === SYMMETRICAL HORIZONTAL LINES ===
    for i = 0, totalVerticalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridH"..i, 'BACKGROUND')
        
        -- The center line is exactly at halfCellsVertical
        if i == halfCellsVertical then
            line:SetTexture(1, 0, 0, 0.8)  -- EXACT red center line
        else
            line:SetTexture(1, 1, 1, 0.3)  -- Symmetrical white lines
        end
        
        local y = i * actualCellHeight
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", 0, -y + (lineThickness / 2))
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'TOPRIGHT', 0, -y - (lineThickness / 2))
    end
    
    --  DEBUG: Show symmetry information
    
    
    
    
    gridOverlay:Hide()
end

function EditorMode:FlushPositions()
    if errorMessagesMover and errorMessagesMover:IsShown() then
        PersistErrorMessagesMoverPosition()
    end
end

-- Popups move to TOOLTIP, above every editor window; their stock strata and level are restored on exit.
local function RaiseEditorPopup(popup, level)
    if not popup._dragonEditorStrata then
        popup._dragonEditorStrata = popup:GetFrameStrata()
        popup._dragonEditorLevel = popup:GetFrameLevel()
    end
    popup:SetFrameStrata(addon.EditorUI.POPUP_STRATA)
    popup:SetFrameLevel(level)
end

local function RaiseEditorStaticPopups()
    local numDialogs = STATICPOPUP_NUMDIALOGS or 4
    for i = 1, numDialogs do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() then
            RaiseEditorPopup(popup, addon.EditorUI.POPUP + i)
        end
    end
end

local function RestoreEditorStaticPopups()
    local numDialogs = STATICPOPUP_NUMDIALOGS or 4
    for i = 1, numDialogs do
        local popup = _G["StaticPopup" .. i]
        if popup and popup._dragonEditorStrata then
            popup:SetFrameStrata(popup._dragonEditorStrata)
            popup:SetFrameLevel(popup._dragonEditorLevel)
            popup._dragonEditorStrata, popup._dragonEditorLevel = nil, nil
        end
    end
end

local function EnsureStaticPopupEditorHook()
    if addon._editorStaticPopupHook then
        return
    end

    addon._editorStaticPopupHook = true
    hooksecurefunc("StaticPopup_Show", function()
        if not EditorMode:IsActive() then
            return
        end
        addon:After(0, RaiseEditorStaticPopups)
    end)
end

function EditorMode:Show()
    if InCombatLockdown() then
        
        return
    end

    if editorActive then
        return
    end

    createGridOverlay()
    CreateManager()
    SetupErrorMessagesMover()
    EnsureStaticPopupEditorHook()
    editorActive = true
    ApplyGridVisibility()
    manager:Show()
    CreateClickWatcher():Show()

    addon:ShowAllEditableFrames()
    
    -- Enable action bar overlays to block clicks during editing
    if addon.EnableActionBarOverlays then
        addon.EnableActionBarOverlays()
    end
    
    -- Update overlay sizes after showing
    if addon.UpdateOverlaySizes then
        addon.UpdateOverlaySizes()
    end
end

local errorFrameInit = CreateFrame("Frame")
errorFrameInit:RegisterEvent("PLAYER_ENTERING_WORLD")
errorFrameInit:SetScript("OnEvent", function()
    SetupErrorMessagesMover()
    ApplyErrorMessagesPosition()
end)


function EditorMode:Hide(showReloadPopup)
    if InCombatLockdown() then
        addon:Print(L["Cannot toggle editor mode during combat!"])
        return
    end

    if addon.PositionPresets then
        addon.PositionPresets:CloseDialogs()
    end

    editorActive = false
    ApplyGridVisibility()
    if manager then manager:Hide() end
    if clickWatcher then clickWatcher:Hide() end

    addon:HideAllEditableFrames(true) -- true = refresh and save positions
    RestoreEditorStaticPopups()
    
    -- Disable action bar overlays to restore normal interaction
    if addon.DisableActionBarOverlays then
        addon.DisableActionBarOverlays()
    end
    
    -- Only show reload UI popup if not coming from reset positions
    if showReloadPopup ~= false then
        StaticPopup_Show("DRAGONUI_EDITOR_RELOAD_UI")
    end
    
    
end

function EditorMode:Toggle()
    if self:IsActive() then 
        self:Hide(true) -- true = show reload UI popup (normal exit)
    else 
        self:Show() 
    end
end

function EditorMode:IsActive()
    return editorActive
end

-- Slash commands
SLASH_DRAGONUI_EDITOR1 = "/duiedit"
SLASH_DRAGONUI_EDITOR2 = "/dragonedit"
SlashCmdList["DRAGONUI_EDITOR"] = function()
    EditorMode:Toggle()
end

function EditorMode:ShowResetConfirmation()
    StaticPopup_Show("DRAGONUI_RESET_ALL_POSITIONS")
end

-- Reset widget positions to defaults (works outside editor mode)
function EditorMode:ResetAllPositions()
    if not addon.db or not addon.db.profile then
        return
    end

    if InCombatLockdown() then
        addon:Print(L["Cannot reset positions during combat!"])
        return
    end

    -- Hide editor mode without showing the generic popup
    if self:IsActive() then
        self:Hide(false) -- false = don't show reload UI popup
    end
    
    -- Reset only the widgets section using Ace3 defaults
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets then
        addon.db.profile.widgets = addon:CopyTable(addon.defaults.profile.widgets)
    else
        return
    end

    -- Reset ToT/ToF override flags so they re-attach to parent frames
    if addon.db.profile.unitframe then
        if addon.db.profile.unitframe.tot then
            addon.db.profile.unitframe.tot.override = false
        end
        if addon.db.profile.unitframe.fot then
            addon.db.profile.unitframe.fot.override = false
        end
    end

    -- Reset target/focus castbar override flags so they re-attach to smart layout
    if addon.db.profile.castbar then
        if addon.db.profile.castbar.target then
            addon.db.profile.castbar.target.override = false
        end
        if addon.db.profile.castbar.focus then
            addon.db.profile.castbar.focus.override = false
        end
    end
    
    -- Also reset additional.totem (multicast) and additional.stance positions
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.additional then
        if not addon.db.profile.additional then
            addon.db.profile.additional = {}
        end
        addon.db.profile.additional.totem = addon:CopyTable(addon.defaults.profile.additional.totem)
        if addon.defaults.profile.additional.stance then
            if not addon.db.profile.additional.stance then
                addon.db.profile.additional.stance = {}
            end
            -- Reset only position fields, preserve button_size/spacing user preferences
            addon.db.profile.additional.stance.x_position = addon.defaults.profile.additional.stance.x_position
            addon.db.profile.additional.stance.y_offset = addon.defaults.profile.additional.stance.y_offset
            addon.db.profile.additional.stance.manual_position = nil
        end
    end
    
    -- Reset quest tracker position
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.questtracker then
        addon.db.profile.questtracker = addon:CopyTable(addon.defaults.profile.questtracker)
    end
    
    -- Reset loot roll position
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.lootroll then
        addon.db.profile.lootroll = addon:CopyTable(addon.defaults.profile.lootroll)
    end
    
    -- Use ReloadUI to fully apply the changes
    ReloadUI()
end

-- Deep copy fallback (used if addon.CopyTable not yet defined)
if not addon.CopyTable then
    function addon:CopyTable(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[addon:CopyTable(orig_key)] = addon:CopyTable(orig_value)
            end
            setmetatable(copy, addon:CopyTable(getmetatable(orig)))
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end
end

-- Reset confirmation dialog
StaticPopupDialogs["DRAGONUI_RESET_ALL_POSITIONS"] = {
    text = L["Are you sure you want to reset all interface elements to their default positions?"],
    button1 = L["Yes"],
    button2 = L["No"],
    OnShow = function(self)
        if EditorMode:IsActive() then
            RaiseEditorPopup(self, addon.EditorUI.POPUP + 5)
        end
    end,
    OnAccept = function()
        EditorMode:ResetAllPositions()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}