-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap
local QP = addon.QuestPOI

-- What sits on the canvas: landmark pins, quest POIs, the zone label and the filter button.

-- The retail sheet is twice as tall, so Blizzard's crop lands right once its rows are halved.
local POI_SHEET = addon._dir .. "WorldMap\\poiicons"
local POI_SHEET_ROWS = 0.5
local PIN_SCALE = 1
local LABEL_FONT_SIZE, DESCRIPTION_FONT_SIZE = 24, 16
-- The ring's circle is off-centre in Blizzard's border sheet, hence the icon nudge.
local FILTER_ICON = 26
local FILTER_ICON_X, FILTER_ICON_Y = 2, -2
-- The numbered glyph needs a larger scale to match the completed quest icon.
local QUEST_POI_SCALE, QUEST_POI_NUMERIC_SCALE = 0.7, 1.05
local ROCK = addon._dir .. "UI\\ui-background-rock"
local GLOW = "Interface\\WorldMap\\UI-QuestPoi-IconGlow"
local FLASH_SECONDS, FLASH_PULSES, FLASH_GROW = 2.5, 3, 0.35
local FLASH_PATIENCE = 5

local objectivesPlate
local pendingQuestFlash, pendingQuestFlashUntil

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
        local scale = button.type == QUEST_POI_NUMERIC and QUEST_POI_NUMERIC_SCALE or QUEST_POI_SCALE
        button.duiMapScale = scale
        button:SetScale(scale)
        local factor = WM.poiScale / scale
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

local function resizeNumericQuestPOI(button, size)
    for _, texture in ipairs({ button.normalTexture, button.pushedTexture, button.highlightTexture }) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        texture:SetSize(size, size)
    end
    button.number:ClearAllPoints()
    button.number:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.number:SetSize(size, size)
end

local function resetNumericQuestPOI(button)
    for _, texture in ipairs({ button.normalTexture, button.pushedTexture, button.highlightTexture }) do
        texture:ClearAllPoints()
        texture:SetAllPoints(button)
    end
    button.number:ClearAllPoints()
    button.number:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.number:SetSize(button:GetWidth(), button:GetHeight())
end

-- These are Blizzard's pooled buttons: one handed to another quest must drop the pulse it was
-- running, or the next quest to land on it inherits the animation. Hidden ones freeze mid-pulse.
local flashing = {}

local function poiQuest(button)
    return button.questId or (button.quest and button.quest.questId)
end

local function stopQuestFlash(button)
    flashing[button] = nil
    if not button.duiFlashTime then return end
    button:SetScript("OnUpdate", nil)
    if button.duiFlashNumeric then
        resetNumericQuestPOI(button)
    else
        button:SetScale(button.duiFlashScale)
    end
    button.duiFlashTime, button.duiFlashScale, button.duiFlashNumeric = nil, nil, nil
    button.duiFlashGlow:Hide()
end

local function dropStaleFlashes()
    for button, questID in pairs(flashing) do
        if not button:IsShown() or poiQuest(button) ~= questID then stopQuestFlash(button) end
    end
end

local function flashQuestPOI(button)
    flashing[button] = poiQuest(button)
    local glow = button.duiFlashGlow
    if not glow then
        glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(GLOW)
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.duiFlashGlow = glow
    end
    button.duiFlashTime = 0
    button.duiFlashScale = button.duiMapScale or button:GetScale()
    button.duiFlashNumeric = button.type == QUEST_POI_NUMERIC
    glow:Show()
    button:SetScript("OnUpdate", function(self, elapsed)
        local time = self.duiFlashTime + elapsed
        self.duiFlashTime = time
        if time >= FLASH_SECONDS then
            stopQuestFlash(self)
            return
        end
        local beat = math.sin(time / FLASH_SECONDS * FLASH_PULSES * math.pi * 2) * 0.5 + 0.5
        local fade = 1 - time / FLASH_SECONDS
        local grow = 1 + FLASH_GROW * beat * fade
        if self.duiFlashNumeric then
            resizeNumericQuestPOI(self, self:GetWidth() * grow)
        else
            self:SetScale(self.duiFlashScale * grow)
        end
        self.duiFlashGlow:SetSize(self:GetWidth() * 2 * grow, self:GetHeight() * 2 * grow)
        self.duiFlashGlow:SetAlpha(beat * fade)
    end)
end

-- QuestPOI_SelectButton keeps its pick in a local of Blizzard's, so the crop is set by hand here.
local function cropQuestPOI(button, selected)
    if button.type ~= QUEST_POI_NUMERIC then return end
    local ring = selected and QP.MAP_CROP.selected or QP.MAP_CROP.idle
    button.normalTexture:SetTexCoord(ring[1][1], ring[1][2], ring[1][3], ring[1][4])
    button.pushedTexture:SetTexCoord(ring[2][1], ring[2][2], ring[2][3], ring[2][4])
    button.highlightTexture:SetTexCoord(ring[3][1], ring[3][2], ring[3][3], ring[3][4])
    -- QuestPOI_SetTextColor's own grid: the black glyphs sit half a sheet under the yellow ones.
    local cell = (button.index or 1) - 1
    local x = math.fmod(cell, QUEST_POI_ICONS_PER_ROW) * QUEST_POI_ICON_SIZE
    local glyph = selected and QP.MAP_CROP.glyph.selected or QP.MAP_CROP.glyph.idle
    local y = glyph + math.floor(cell / QUEST_POI_ICONS_PER_ROW) * QUEST_POI_ICON_SIZE
    button.number:SetTexCoord(x, x + QUEST_POI_ICON_SIZE, y, y + QUEST_POI_ICON_SIZE)
    if selected then button.selectionGlow:Show() else button.selectionGlow:Hide() end
end

function WM.SelectQuestPOI(questID)
    for index = 1, WorldMapFrame.numQuests or 0 do
        local row = _G["WorldMapQuestFrame" .. index]
        if row and row.poiIcon then cropQuestPOI(row.poiIcon, row.questId == questID) end
    end
end

local function tryFlashQuestPOI()
    dropStaleFlashes()
    if not pendingQuestFlash then return end
    if GetTime() > pendingQuestFlashUntil then
        pendingQuestFlash = nil
        return
    end
    for index = 1, WorldMapFrame.numQuests or 0 do
        local row = _G["WorldMapQuestFrame" .. index]
        if row and row.questId == pendingQuestFlash then
            local button = row.poiIcon
            local swap = QUEST_POI_SWAP_BUTTONS and QUEST_POI_SWAP_BUTTONS.WorldMapPOIFrame
            if swap and swap.quest == row and swap:IsShown() then button = swap end
            if button and button:IsShown() then
                flashQuestPOI(button)
                pendingQuestFlash = nil
            end
            return
        end
    end
end

function WM.FlashQuestPOI(questID)
    if not questID then return end
    pendingQuestFlash, pendingQuestFlashUntil = questID, GetTime() + FLASH_PATIENCE
    tryFlashQuestPOI()
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
    hooksecurefunc("WorldMapFrame_Update", tryFlashQuestPOI)
    -- Blizzard reselects a pin of its own on every rebuild, so ours is re-cropped after it.
    hooksecurefunc("WorldMapFrame_SelectQuestFrame", function() WM.SelectQuestPOI(QP.GetFocus()) end)
    QP.RegisterFocusListener(WM.SelectQuestPOI)
    hooksecurefunc("WorldMapFrame_UpdateQuests", dropStaleFlashes)
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
