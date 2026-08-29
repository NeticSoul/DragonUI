-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

-- What sits on the canvas: landmark pins, quest POIs, the zone label and the filter button.

-- The retail sheet is twice as tall, so Blizzard's crop lands right once its rows are halved.
local POI_SHEET = addon._dir .. "WorldMap\\poiicons"
local POI_SHEET_ROWS = 0.5
local PIN_SCALE = 1
local LABEL_FONT_SIZE, DESCRIPTION_FONT_SIZE = 24, 16
-- The ring's circle is off-centre in Blizzard's border sheet, hence the icon nudge.
local FILTER_ICON = 26
local FILTER_ICON_X, FILTER_ICON_Y = 2, -2
-- QuestPOITemplate is 32px; retail's numbered pin reads a good bit smaller than the canvas art.
local QUEST_POI_SCALE = 0.7
local ROCK = addon._dir .. "UI\\ui-background-rock"

local objectivesPlate

-- ============================================================================
-- LANDMARKS AND QUEST POIS
-- ============================================================================

function WM.SetPOIIcon(texture, index)
    local x1, x2, y1, y2 = WorldMap_GetPOITextureCoords(index)
    texture:SetTexture(POI_SHEET)
    texture:SetTexCoord(x1, x2, y1 * POI_SHEET_ROWS, y2 * POI_SHEET_ROWS)
end

-- Blizzard anchors pins in the map's own units and scales them with it; retail keeps pins one size.
local function restyleLandmarks()
    local scale = WM.canvasScale
    if not scale then return end
    local shown = WM:Config().landmarks ~= false
    local pinScale = PIN_SCALE / scale
    local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
    for index = 1, GetNumMapLandmarks() do
        local pin = _G["WorldMapFramePOI" .. index]
        if pin then
            if shown then
                local _, _, textureIndex, x, y = GetMapLandmarkInfo(index)
                WM.SetPOIIcon(_G[pin:GetName() .. "Texture"], textureIndex)
                pin:SetScale(pinScale)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x * width / pinScale, -y * height / pinScale)
            else
                pin:Hide()
            end
        end
    end
end

-- Offsets are read in the button's own space, so the badge scale has to come back out of them.
local function placeQuestPOI(button)
    if button.duiRawX and WM.poiScale then
        button:SetScale(QUEST_POI_SCALE)
        local factor = WM.poiScale / QUEST_POI_SCALE
        button:SetPoint("CENTER", WorldMapPOIFrame, "TOPLEFT", button.duiRawX * factor, button.duiRawY * factor)
    end
end

-- Blizzard only re-anchors a POI it has a position for; the offset it just wrote is the raw one.
local function onQuestPOIDisplayed(questFrame)
    local button = questFrame.poiIcon
    local _, posX = QuestPOIGetIconInfo(questFrame.questId)
    if not (button and posX) then return end
    local _, _, _, x, y = button:GetPoint(1)
    button.duiRawX, button.duiRawY = x, y
    placeQuestPOI(button)
end

WM.RefreshLandmarks = restyleLandmarks

function WM.RefreshPins()
    restyleLandmarks()
    for index = 1, WorldMapFrame.numQuests or 0 do
        local button = _G["WorldMapQuestFrame" .. index].poiIcon
        if button then placeQuestPOI(button) end
    end
end

local function styleAreaLabel()
    local font = addon.Fonts.PRIMARY
    WorldMapFrameAreaLabel:SetFont(font, LABEL_FONT_SIZE)
    WorldMapFrameAreaLabel:SetTextColor(1, 0.82, 0)
    WorldMapFrameAreaLabel:SetShadowColor(0, 0, 0, 1)
    WorldMapFrameAreaLabel:SetShadowOffset(1, -1)
    WorldMapFrameAreaDescription:SetFont(font, DESCRIPTION_FONT_SIZE)
    WorldMapFrameAreaDescription:SetTextColor(1, 1, 1)
    WorldMapFrameAreaDescription:SetShadowColor(0, 0, 0, 1)
    WorldMapFrameAreaDescription:SetShadowOffset(1, -1)
end

-- ============================================================================
-- FILTER BUTTON
-- ============================================================================

local function filterEntries()
    local entries = { { text = FILTERS, isTitle = true } }
    local function toggle(text, key, onChanged)
        entries[#entries + 1] = {
            text = text,
            checked = function() return WM:Config()[key] ~= false end,
            keepShown = true,
            func = function()
                WM:Config()[key] = not (WM:Config()[key] ~= false)
                onChanged()
            end,
        }
    end
    toggle(L["Show Landmarks"], "landmarks", restyleLandmarks)
    toggle(L["Show Undiscovered Areas"], "fog", WM.RefreshFog)
    toggle(L["Show Dungeon Entrances"], "entrances", WM.RefreshMapPins)
    toggle(L["Show Graveyards"], "graveyards", WM.RefreshMapPins)
    toggle(L["Show Flight Points"], "flightPoints", WM.RefreshMapPins)
    return entries
end

local function buildFilterButton()
    local button = CreateFrame("Button", "DragonUIWorldMapFilterButton", WM.border)
    button:SetSize(32, 32)
    button:SetFrameLevel(WM.border:GetFrameLevel() + 5)
    button:SetPoint("TOPRIGHT", WM.spacer, "BOTTOMRIGHT", -4, -4)

    -- Blizzard's tracking button: a 54px ring hung off the top-left corner of a 32px button.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:set_atlas("map-tracking-border", true)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local function face(setter, getter, atlas)
        button[setter](button, ROCK)
        local tex = button[getter](button)
        tex:set_atlas(atlas)
        tex:ClearAllPoints()
        tex:SetSize(FILTER_ICON, FILTER_ICON)
        tex:SetPoint("CENTER", button, "CENTER", FILTER_ICON_X, FILTER_ICON_Y)
        return tex
    end
    face("SetNormalTexture", "GetNormalTexture", "map-filter-button")
    face("SetPushedTexture", "GetPushedTexture", "map-filter-button-down")
    -- MiniMapTracking's highlight fills the button unoffset; only the icon needs the nudge.
    button:SetHighlightTexture(ROCK)
    local highlight = button:GetHighlightTexture()
    highlight:set_atlas("map-zoom-highlight")
    highlight:SetBlendMode("ADD")
    highlight:ClearAllPoints()
    highlight:SetAllPoints(button)

    button:SetScript("OnClick", function(self)
        addon.Menu.Open(self, filterEntries())
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(FILTERS)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- ============================================================================
-- CANVAS SHADOW
-- ============================================================================

-- Where the retired "show quest objectives" box sat; dressing it tainted numEntries (core.lua).
local function buildCanvasShadow()
    objectivesPlate = WM.border:CreateTexture(nil, "ARTWORK")
    objectivesPlate:set_atlas("mapcornershadow-left", true)
    objectivesPlate:SetPoint("BOTTOMLEFT", WM.spacer, "BOTTOMLEFT", 0, -(WM.canvasH or 465))
end

-- ============================================================================
-- BUILD
-- ============================================================================

function WM.BuildPins()
    styleAreaLabel()
    buildFilterButton()
    buildCanvasShadow()

    hooksecurefunc("WorldMapFrame_Update", restyleLandmarks)
    hooksecurefunc("WorldMapFrame_DisplayQuestPOI", onQuestPOIDisplayed)

    local onLayout = WM.OnLayout
    WM.OnLayout = function()
        if onLayout then onLayout() end
        objectivesPlate:SetPoint("BOTTOMLEFT", WM.spacer, "BOTTOMLEFT", 0, -(WM.canvasH or 465))
    end

    local onMode = WM.OnModeChanged
    WM.OnModeChanged = function(windowed)
        if onMode then onMode(windowed) end
        if objectivesPlate then
            if windowed then objectivesPlate:Show() else objectivesPlate:Hide() end
        end
    end
end
