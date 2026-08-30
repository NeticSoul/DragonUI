-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Rewritten from a base module contributed by PentSec, with thanks.

local addon = select(2, ...)
local L = addon.L

-- Retail's Map & Quest Log over the windowed map; nothing here writes what Blizzard's map reads.

local WorldMapModule = { initialized = false, applied = false }
addon.WorldMap = addon.WorldMap or {}
local WM = addon.WorldMap

if addon.RegisterModule then
    addon:RegisterModule("worldmap", WorldMapModule,
        L["World Map"],
        L["Retail-style world map with breadcrumb navigation and a quest log side panel"],
        { lifecyclePrefix = "WorldMap", loadOnce = true })
end

-- Retail's WorldMapFrame: 702x534 minimized, a 67px title band over a 697x465 canvas.
WM.SPACER_H = 67
WM.INSET_L, WM.INSET_R, WM.INSET_B = 2, 3, 2
WM.PANEL_W = 330
-- The UIPanel slot is (0,-104) and the corner art overhangs 13px; retail sits at (16,-116).
WM.FRAME_X, WM.FRAME_Y = 16, 12
WM.DETAIL_W, WM.DETAIL_H = 1002, 668
local WINDOWED_CANVAS_W = 697
-- Kept clear of the action bars and the screen's right edge when maximized.
local MAX_BOTTOM_MARGIN, MAX_RIGHT_MARGIN = 96, 24
local PORTRAIT = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"
local ROCK = addon._dir .. "UI\\ui-background-rock"
local BASE_LEVEL = 10

local function CP()
    return addon.CharacterPanel
end

function WM:Config()
    return addon:GetModuleConfig("worldmap") or {}
end

function WM:Enabled()
    return addon:IsModuleEnabled("worldmap")
end

-- The client's one "am I windowed" test, read and never written.
function WM.IsWindowed()
    return WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
end

-- Overlays and pins belong to the terrain view; floors under it (Dalaran's Underbelly) have none.
function WM.OnTerrainFloor()
    local level = GetCurrentMapDungeonLevel()
    if DungeonUsesTerrainMap() then level = level - 1 end
    return level <= 0
end

-- WorldMap_OpenToQuest writes WorldMapFrame.blockWorldMapUpdate, re-read by its every WORLD_MAP_UPDATE.
function WM.OpenToQuest(questID)
    if not questID or InCombatLockdown() then return false end
    -- Not a getter: it moves the map whatever it answers, so a quest it cannot place must not strand you.
    local before = (GetCurrentMapAreaID() or 0) - 1
    local area, floor = GetQuestWorldMapAreaID(questID)
    if area and area > 0 then
        SetMapByID(area)
        if floor and floor > 0 then SetDungeonMapLevel(floor) end
    elseif before > 0 then
        SetMapByID(before)
    end
    ShowUIPanel(WorldMapFrame)
    return true
end

-- ============================================================================
-- GEOMETRY
-- ============================================================================

local function canvasSize()
    if WM:Config().maximized then
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local panel = WM.PanelShown() and WM.PANEL_W or 0
        local top = -(UIParent:GetAttribute("TOP_OFFSET") or -104)
        local h = sh - top - WM.FRAME_Y - WM.SPACER_H - WM.INSET_B - MAX_BOTTOM_MARGIN
        local w = sw - WM.FRAME_X - WM.INSET_L - WM.INSET_R - panel - MAX_RIGHT_MARGIN
        local scale = math.max(math.min(h / WM.DETAIL_H, w / WM.DETAIL_W), WINDOWED_CANVAS_W / WM.DETAIL_W)
        return math.floor(WM.DETAIL_W * scale), math.floor(WM.DETAIL_H * scale)
    end
    return WINDOWED_CANVAS_W, math.floor(WINDOWED_CANVAS_W * WM.DETAIL_H / WM.DETAIL_W + 0.5)
end

-- Both passes write implicitly protected frames, so both are combat-deferred.
local canvasW, canvasH

local function layoutCanvas()
    local f = WorldMapFrame
    local detail = WorldMapDetailFrame
    canvasW, canvasH = canvasSize()
    WM.canvasW, WM.canvasH = canvasW, canvasH
    local scale = canvasW / WM.DETAIL_W
    WM.canvasScale = scale
    -- Blizzard multiplies POI and arrow offsets by its windowed constant; ours differs by this.
    WM.poiScale = scale / WORLDMAP_WINDOWED_SIZE

    detail:SetScale(scale)
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", f, "TOPLEFT", (WM.FRAME_X + WM.INSET_L) / scale, -(WM.FRAME_Y + WM.SPACER_H) / scale)
    WorldMapButton:SetScale(scale)
    WorldMapBlobFrame:SetScale(scale)
    -- Blizzard recomputes the blob hit box when this is nil, which keeps the value secure.
    WorldMapBlobFrame.xRatio = nil
    WorldMapFrameAreaFrame:SetScale(1 / scale)

    for _, name in ipairs({ "PlayerArrowFrame", "PlayerArrowEffectFrame" }) do
        local arrow = _G[name]
        if arrow then arrow:SetScale(WM.poiScale) end
    end
    if WM.RefreshPins then WM.RefreshPins() end
    if WM.RefreshMapPins then WM.RefreshMapPins() end
    if WM.RefreshBlobs then WM.RefreshBlobs() end
end

local function windowSize()
    local panel = WM.PanelShown() and WM.PANEL_W or 0
    return WM.INSET_L + canvasW + WM.INSET_R + panel, WM.SPACER_H + canvasH + WM.INSET_B
end

-- The chrome is ours and follows the panel at once; the frame under it is protected in combat.
local function layoutChrome()
    local w, h = windowSize()
    WM.border:SetSize(w, h)
    local panel = WM.PanelShown() and WM.PANEL_W or 0
    WM.spacer:SetPoint("BOTTOMRIGHT", WM.border, "TOPRIGHT", -(WM.INSET_R + panel), -WM.SPACER_H)
    WM.sideToggle:SetPoint("BOTTOMRIGHT", WM.border, "BOTTOMRIGHT", -(WM.INSET_R + panel + 5), WM.INSET_B + 5)
    if WM.OnLayout then WM.OnLayout() end
end

local function layoutWindow()
    local w, h = windowSize()
    WorldMapFrame:SetSize(WM.FRAME_X + w, WM.FRAME_Y + h)
    layoutChrome()
end

function WM.Layout(canvasChanged)
    if not (WM.border and WM.IsWindowed()) then return end
    if InCombatLockdown() then
        addon.CombatQueue:Add("worldmap_layout", WM.Layout, canvasChanged or WM.canvasDirty)
        WM.canvasDirty = WM.canvasDirty or canvasChanged
        if canvasW and not WM.canvasDirty then layoutChrome() end
        return
    end
    WM.canvasDirty = nil
    if canvasChanged or not canvasW then layoutCanvas() end
    layoutWindow()
end

-- ============================================================================
-- CHROME
-- ============================================================================

-- Hidden parent rather than a swapped Show: that method taints every secure caller reaching it.
local holder = CreateFrame("Frame", "DragonUIWorldMapHolder", UIParent)
holder:Hide()

local RETIRED = {
    "WorldMapZoneMinimapDropDown", "WorldMapContinentDropDown", "WorldMapZoneDropDown",
    "WorldMapZoomOutButton", "WorldMapMagnifyingGlassButton", "WorldMapLevelDropDown",
    "WorldMapLevelUpButton", "WorldMapLevelDownButton", "WorldMapFrameSizeUpButton",
    "WorldMapFrameSizeDownButton", "WorldMapTrackQuest", "WorldMapTitleButton",
}

-- Dressing it taints the un-localled numEntries its OnClick re-reads, blocking the blob in combat.
local function retirePermanently()
    if WorldMapQuestShowObjectives:GetParent() == holder then return end
    WorldMapQuestShowObjectives:SetParent(holder)
end

-- Past VARIABLES_LOADED: that handler reads GetChecked() into WatchFrame.showObjectives.
local function retireAfterLogin()
    if IsLoggedIn() then
        retirePermanently()
        return
    end
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_LOGIN")
    waiter:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        retirePermanently()
    end)
end

local function retireBlizzardWidgets()
    for _, name in ipairs(RETIRED) do
        _G[name]:SetParent(holder)
    end
    WorldMapFrameTitle:Hide()
    WorldMapFrameMiniBorderLeft:Hide()
    WorldMapFrameMiniBorderRight:Hide()
end

-- The client's fullscreen map still needs its own controls.
local function restoreBlizzardWidgets()
    for _, name in ipairs(RETIRED) do
        _G[name]:SetParent(WorldMapFrame)
    end
    WorldMapFrameTitle:Show()
end

-- The advanced map is a "center" panel the manager never re-anchors, so a drag keeps its spot.
local function savePosition()
    local f = WorldMapFrame
    WM:Config().position = { x = f:GetLeft(), y = f:GetTop() - UIParent:GetHeight() }
end

function WM.Place()
    local f = WorldMapFrame
    f:SetMovable(true)
    if not WORLDMAP_SETTINGS.advanced then return end
    local position = WM:Config().position
    f:ClearAllPoints()
    if position then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", position.x, position.y)
    else
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, UIParent:GetAttribute("TOP_OFFSET") or -104)
    end
end

local function buildChrome()
    local f = WorldMapFrame

    -- The stone sits at the map's own level so the detail frame draws over it.
    local ground = CreateFrame("Frame", "DragonUIWorldMapGround", f)
    ground:SetFrameLevel(f:GetFrameLevel())
    ground:EnableMouse(false)
    WM.ground = ground

    local border = CreateFrame("Frame", "DragonUIWorldMapBorder", f)
    border:SetFrameStrata("HIGH")
    border:SetFrameLevel(BASE_LEVEL)
    border:SetPoint("TOPLEFT", f, "TOPLEFT", WM.FRAME_X, -WM.FRAME_Y)
    border:EnableMouse(false)
    WM.border = border

    ground:SetPoint("TOPLEFT", border, "TOPLEFT", 2, -21)
    ground:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -2, 2)
    local rock = ground:CreateTexture(nil, "BACKGROUND")
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetAllPoints(ground)

    NineSliceUtils.ApplyLayout(border, NineSliceUtils.GetLayout("PortraitFrameTemplateMinimizable"))

    -- Retail's TitleCanvasSpacerFrame: the band the breadcrumb lives in, stopping at the canvas.
    local spacer = CreateFrame("Frame", "DragonUIWorldMapSpacer", border)
    spacer:SetPoint("TOPLEFT", border, "TOPLEFT", WM.INSET_L, 0)
    spacer:SetFrameLevel(BASE_LEVEL + 1)
    spacer:EnableMouse(true)
    WM.spacer = spacer

    local separator = border:CreateTexture(nil, "BACKGROUND", nil, -5)
    separator:set_atlas("_UI-Frame-InnerTopTile")
    separator:SetHeight(3)
    separator:SetPoint("TOPLEFT", border, "TOPLEFT", WM.INSET_L, -(WM.SPACER_H - 4))
    separator:SetPoint("RIGHT", spacer, "RIGHT", 0, 0)

    -- ARTWORK, under the OVERLAY corner whose ring frames it. Square art shrinks to clear the ring.
    local portrait = border:CreateTexture(nil, "ARTWORK")
    portrait:SetTexture(PORTRAIT)
    portrait:SetSize(56, 56)
    -- The book does not fill its own art, so it hangs low unless lifted inside the ring.
    portrait:SetPoint("TOPLEFT", border, "TOPLEFT", -2, 7)

    local title = border:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", border, "TOP", 0, -5)
    title:SetText(L["Map & Quest Log"])
    WM.title = title

    -- The title band drags the window. The frame is protected, so never in combat.
    local titleBar = CreateFrame("Frame", "DragonUIWorldMapTitleBar", border)
    titleBar:SetFrameLevel(BASE_LEVEL + 1)
    titleBar:SetPoint("TOPLEFT", border, "TOPLEFT", 58, -1)
    titleBar:SetPoint("TOPRIGHT", border, "TOPRIGHT", -52, -1)
    titleBar:SetHeight(20)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        if WM.ClearBlobs then WM.ClearBlobs() end
        f:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        addon:SafeExecute("worldmap", "drop", function()
            f:StopMovingOrSizing()
            savePosition()
            -- Blizzard recomputes the blob hit box when this is nil.
            WorldMapBlobFrame.xRatio = nil
            if WM.RefreshBlobs then WM.RefreshBlobs() end
        end)
    end)

    -- Textures only: the close button's secure OnClick is what closes the map in combat.
    local close = WorldMapFrameCloseButton
    close:SetFrameStrata("HIGH")
    close:SetFrameLevel(BASE_LEVEL + 5)
    CP().ModernizeCloseButton(close, border, 1, 0)

    WM.maxMin = WM.BuildMaxMinButton(border, close)
    WM.sideToggle = WM.BuildSideToggle(border)
end

local function chromeAlpha(opacity)
    local alpha = 0.5 + (1 - (opacity or 0)) * 0.5
    WM.border:SetAlpha(alpha)
    WM.ground:SetAlpha(alpha)
end

-- ============================================================================
-- CONTROLS
-- ============================================================================

local function setButtonState(button, atlas)
    button:GetNormalTexture():set_atlas(atlas)
    button:GetPushedTexture():set_atlas(atlas .. "-pressed")
    button:GetDisabledTexture():set_atlas(atlas .. "-disabled")
end

function WM.BuildMaxMinButton(border, close)
    local button = CreateFrame("Button", "DragonUIWorldMapMaximizeButton", border)
    button:SetSize(24, 24)
    button:SetPoint("RIGHT", close, "LEFT", -1, 0)
    button:SetFrameLevel(BASE_LEVEL + 5)
    button:SetNormalTexture(ROCK)
    button:SetPushedTexture(ROCK)
    button:SetDisabledTexture(ROCK)
    button:SetHighlightTexture(ROCK)
    button:GetHighlightTexture():set_atlas("redbutton-highlight")
    button:GetHighlightTexture():SetBlendMode("ADD")

    local function refresh()
        setButtonState(button, WM:Config().maximized and "redbutton-condense" or "redbutton-expand")
    end
    button:SetScript("OnClick", function()
        -- Rescaling the canvas writes the protected blob frame; the client refuses that in combat.
        if InCombatLockdown() then
            UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
            return
        end
        WM:Config().maximized = not WM:Config().maximized
        refresh()
        WM.Layout(true)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(WM:Config().maximized and MINIMIZE or L["Maximize"])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    refresh()
    return button
end

function WM.BuildSideToggle(border)
    local button = CreateFrame("Button", "DragonUIWorldMapQuestLogToggle", border)
    button:SetSize(32, 32)
    button:SetFrameLevel(BASE_LEVEL + 5)
    button:SetNormalTexture(ROCK)
    button:SetPushedTexture(ROCK)
    button:SetHighlightTexture(ROCK)
    button:GetHighlightTexture():SetBlendMode("ADD")

    local shadow = button:CreateTexture(nil, "BACKGROUND")
    shadow:set_atlas("mapcornershadow-right", true)
    shadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 5, -5)

    -- No highlight cell in the sheet, so the arrow brightens itself and follows the pressed art.
    function button:SetHighlightArt(pressed)
        local state = WM.PanelShown() and "hide" or "show"
        self:GetHighlightTexture():set_atlas("questcollapse-" .. state .. (pressed and "-down" or "-up"))
    end

    function button:Refresh()
        local state = WM.PanelShown() and "hide" or "show"
        self:GetNormalTexture():set_atlas("questcollapse-" .. state .. "-up")
        self:GetPushedTexture():set_atlas("questcollapse-" .. state .. "-down")
        self:SetHighlightArt(false)
    end
    button:SetScript("OnMouseDown", function(self) self:SetHighlightArt(true) end)
    button:SetScript("OnMouseUp", function(self) self:SetHighlightArt(false) end)
    button:SetScript("OnClick", function()
        WM.SetPanelShown(not WM.PanelShown())
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(WM.PanelShown() and L["Hide Quest Log"] or L["Show Quest Log"])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Refresh()
    return button
end

function WM.PanelShown()
    return WM:Config().questLog ~= false
end

-- The panel is ours and shows at once; the window width it needs is the protected part.
function WM.SetPanelShown(shown)
    -- Maximized, the canvas is sized around the panel, and the canvas is protected in combat.
    if WM:Config().maximized and InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
        return
    end
    WM:Config().questLog = shown and true or false
    WM.sideToggle:Refresh()
    if WM.SetQuestLogShown then WM.SetQuestLogShown(shown) end
    WM.Layout(WM:Config().maximized)
end

-- ============================================================================
-- BLIZZARD SIZE MODES
-- ============================================================================

-- The size keybind still reaches Blizzard's fullscreen map, where our chrome gets out of the way.
local function onWindowedChanged()
    local windowed = WM.IsWindowed()
    if windowed then
        WM.border:Show()
        WM.ground:Show()
        retireBlizzardWidgets()
        WM.Place()
        -- Both size toggles re-anchor the close button to the chrome they just showed.
        WorldMapFrameCloseButton:ClearAllPoints()
        WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WM.border, "TOPRIGHT", 1, 0)
        WM.Layout(true)
    else
        WM.border:Hide()
        WM.ground:Hide()
        restoreBlizzardWidgets()
    end
    if WM.OnModeChanged then WM.OnModeChanged(windowed) end
end

local function installHooks()
    retireAfterLogin()
    hooksecurefunc("WorldMap_ToggleSizeUp", onWindowedChanged)
    hooksecurefunc("WorldMap_ToggleSizeDown", onWindowedChanged)
    -- Every windowed re-layout of Blizzard's runs through here and re-anchors the canvas.
    hooksecurefunc("WorldMapFrame_SetMiniMode", function()
        if WM.IsWindowed() then
            WM.Place()
            WM.Layout(true)
        end
    end)
    hooksecurefunc("WorldMapFrame_SetOpacity", chromeAlpha)

    local events = CreateFrame("Frame")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:SetScript("OnEvent", function()
        if WM:Config().maximized then WM.Layout(true) end
    end)
end

-- ============================================================================
-- BOOT
-- ============================================================================

local function boot()
    if InCombatLockdown() then
        addon.CombatQueue:Add("worldmap_boot", boot)
        return
    end
    if WorldMapModule.initialized then return end
    WorldMapModule.initialized = true

    -- Both CVars are read at VARIABLES_LOADED, so they take effect on the next reload.
    if not GetCVarBool("miniWorldMap") then SetCVar("miniWorldMap", 1) end
    if not GetCVarBool("advancedWorldMap") then SetCVar("advancedWorldMap", 1) end

    buildChrome()
    installHooks()
    if WM.BuildNavBar then WM.BuildNavBar() end
    if WM.BuildPins then WM.BuildPins() end
    if WM.BuildQuestLog then WM.BuildQuestLog() end
    if WM.BuildFog then WM.BuildFog() end
    if WM.BuildMapPins then WM.BuildMapPins() end

    chromeAlpha(WORLDMAP_SETTINGS.opacity)
    onWindowedChanged()
    WorldMapModule.applied = true
end

function addon.ApplyWorldMapSystem()
    if WM:Enabled() and not WorldMapModule.applied then boot() end
end

function addon.RefreshWorldMapSystem()
    if not WorldMapModule.applied then
        addon.ApplyWorldMapSystem()
        return
    end
    WM.RefreshLandmarks()
    WM.RefreshFog()
    WM.RefreshMapPins()
end

-- Hooks and reparented widgets cannot be undone in-session, so a disable waits for the reload.
function addon.RestoreWorldMapSystem()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    addon.ApplyWorldMapSystem()
end)
