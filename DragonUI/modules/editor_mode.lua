-- ============================================================================
-- DragonUI - Editor Mode
-- Provides a visual grid overlay and controls for repositioning UI elements.
-- ============================================================================

local addon = select(2, ...);
local L = addon.L

local EditorMode = {};
addon.EditorMode = EditorMode;

local gridOverlay = nil;
local exitEditorButton = nil;
local resetAllButton = nil;
local errorMessagesMover = nil;
local errorMessagesPositionHooked = false;

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
    cfg.posY = math.floor((cy - uy) + 0.5)
    cfg.custom_position = true
end

local function SetupErrorMessagesMover()
    if errorMessagesMover or not addon.CreateUIFrame then
        return
    end

    errorMessagesMover = addon.CreateUIFrame(420, 90, "ErrorMessages")
    errorMessagesMover:HookScript("OnDragStop", function(self)
        self.DragonUI_WasDragged = true
        PersistErrorMessagesMoverPosition()
        ApplyErrorMessagesPosition()
    end)

    if errorMessagesMover.editorText then
        errorMessagesMover.editorText:SetText((L and L["Error Messages"]) or "Error Messages")
    end

    addon:RegisterEditableFrame({
        name = "errorMessages",
        frame = errorMessagesMover,
        blizzardFrame = UIErrorsFrame,
        showTest = function()
            local cfg = GetWidgetConfig("errorMessages")
            errorMessagesMover:ClearAllPoints()
            if cfg and cfg.custom_position then
                errorMessagesMover:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.posX or 0, cfg.posY or 160)
            elseif UIErrorsFrame then
                errorMessagesMover:SetPoint("CENTER", UIErrorsFrame, "CENTER", 0, 0)
            else
                errorMessagesMover:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
            end
            errorMessagesMover:Show()
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
StaticPopupDialogs["DRAGONUI_RELOAD_UI"] = {
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

local function createExitButton()
    if exitEditorButton then return; end

    exitEditorButton = CreateFrame("Button", "DragonUIExitEditorButton", UIParent, "UIPanelButtonTemplate");
    exitEditorButton:SetText(L["Exit Edit Mode"]);
    exitEditorButton:SetSize(140, 28);
    exitEditorButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200);
    exitEditorButton:SetFrameStrata("TOOLTIP");
    exitEditorButton:SetFrameLevel(1000);

    -- Apply modern grey + blue style
    addon.StyleEditorButton(exitEditorButton)

    exitEditorButton:SetScript("OnClick", function()
        EditorMode:Toggle();
    end);

    exitEditorButton:Hide();
end

local function createResetAllButton()
    if resetAllButton then return; end

    resetAllButton = CreateFrame("Button", "DragonUIResetAllButton", UIParent, "UIPanelButtonTemplate");
    resetAllButton:SetText(L["Reset All Positions"]);
    resetAllButton:SetSize(140, 28);
    resetAllButton:SetPoint("CENTER", UIParent, "CENTER", 0, 165);
    resetAllButton:SetFrameStrata("TOOLTIP");
    resetAllButton:SetFrameLevel(1000);

    -- Apply modern grey + blue style
    addon.StyleEditorButton(resetAllButton)

    resetAllButton:SetScript("OnClick", function()
        EditorMode:ShowResetConfirmation()
    end);

    resetAllButton:Hide();
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
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    gridOverlay = CreateFrame('Frame', "DragonUIGridOverlay", UIParent)
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND")
    gridOverlay:SetFrameLevel(0)

    --  ADD SEMI-TRANSPARENT DARK BACKGROUND LAYER
    local background = gridOverlay:CreateTexture("DragonUIGridBackground", 'BACKGROUND')
    background:SetAllPoints(gridOverlay)
    background:SetTexture(0, 0, 0, 0.3)  -- Semi-transparent black
    background:SetDrawLayer('BACKGROUND', -1)  -- Behind everything

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

local function RaiseEditorStaticPopups()
    local numDialogs = STATICPOPUP_NUMDIALOGS or 4
    for i = 1, numDialogs do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() then
            popup:SetFrameStrata("FULLSCREEN_DIALOG")
            popup:SetFrameLevel(900 + i)
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

    createGridOverlay()
    createExitButton()
    createResetAllButton()
    SetupErrorMessagesMover()
    EnsureStaticPopupEditorHook()
    gridOverlay:Show()
    exitEditorButton:Show()
    resetAllButton:Show()

    addon:ShowAllEditableFrames()
    
    -- Enable action bar overlays to block clicks during editing
    if addon.EnableActionBarOverlays then
        addon.EnableActionBarOverlays()
    end
    
    -- Update overlay sizes after showing
    if addon.UpdateOverlaySizes then
        addon.UpdateOverlaySizes()
    end

    if addon.PositionPresets then
        addon.PositionPresets:ShowPanel()
    end
end

local errorFrameInit = CreateFrame("Frame")
errorFrameInit:RegisterEvent("PLAYER_ENTERING_WORLD")
errorFrameInit:SetScript("OnEvent", function()
    SetupErrorMessagesMover()
    ApplyErrorMessagesPosition()
end)


function EditorMode:Hide(showReloadPopup)
    if addon.PositionPresets then
        addon.PositionPresets:HidePanel()
    end

    if gridOverlay then gridOverlay:Hide() end
    if exitEditorButton then exitEditorButton:Hide() end
    if resetAllButton then resetAllButton:Hide() end

    addon:HideAllEditableFrames(true) -- true = refresh and save positions
    
    -- Disable action bar overlays to restore normal interaction
    if addon.DisableActionBarOverlays then
        addon.DisableActionBarOverlays()
    end
    
    -- Only show reload UI popup if not coming from reset positions
    if showReloadPopup ~= false then
        StaticPopup_Show("DRAGONUI_RELOAD_UI")
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
    -- Use grid visibility as the true indicator of editor state
    return gridOverlay and gridOverlay:IsShown()
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
            self:SetFrameStrata("FULLSCREEN_DIALOG")
            self:SetFrameLevel(950)
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