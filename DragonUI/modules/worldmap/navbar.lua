-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

-- Retail's NavBarTemplate on this client's map model: World > Continent > Zone > Floor.

local BAR_H = 34
local BAR_X, BAR_Y, BAR_RIGHT = 60, -24, -4
local CONTENT_X = 3
local CRUMB_H = 24
local TEXT_PAD_HOME, TEXT_PAD = 12, 26
local HOME_PAD, PLAIN_PAD, ARROW_PAD = 25, 34, 56
local WIDTH_BUFFER = 20
local OVERFLOW_W = 44
local ENDCAP_W, ENDCAP_H = 21, 30
-- Home starts one pixel in from the bar; the banner bleeds back over it so no ground shows.
local HOME_BLEED = 1
local BANNER_W = 128
local RIM_OUTSET = 2

local bar

-- ============================================================================
-- MODEL
-- ============================================================================

local function continentNames()
    return { GetMapContinents() }
end

local function zoneNames(continent)
    if not continent or continent <= 0 then return {} end
    return { GetMapZones(continent) }
end

local function floorLabel(index)
    local mapName = strupper(GetMapInfo() or "")
    local floor = DungeonUsesTerrainMap() and index - 1 or index
    return _G["DUNGEON_FLOOR_" .. mapName .. floor] or string.format(FLOOR_NUMBER, index)
end

-- The name of the map on screen, for the breadcrumb and the quest log's zone header.
function WM.CurrentMapName()
    local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
    if continent > 0 and zone > 0 then
        return zoneNames(continent)[zone]
    elseif continent > 0 then
        return continentNames()[continent]
    elseif GetNumDungeonMapLevels() > 0 or IsInInstance() then
        return GetRealZoneText()
    end
    return WORLD_MAP
end

local function continentList()
    local list = {}
    for index, name in ipairs(continentNames()) do
        list[#list + 1] = { text = name, func = function() SetMapZoom(index) end }
    end
    return list
end

local function zoneList(continent)
    local list = {}
    for index, name in ipairs(zoneNames(continent)) do
        list[#list + 1] = { text = name, func = function() SetMapZoom(continent, index) end }
    end
    return list
end

local function floorList()
    local list = {}
    for index = 1, GetNumDungeonMapLevels() do
        list[#list + 1] = { text = floorLabel(index), func = function() SetDungeonMapLevel(index) end,
            checked = index == GetCurrentMapDungeonLevel() }
    end
    return list
end

local function trail()
    local crumbs = {
        { name = L["World"], onClick = function() SetMapZoom(WORLDMAP_WORLD_ID) end, list = continentList },
    }
    local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
    local continentName = continent > 0 and continentNames()[continent]
    if continentName then
        crumbs[#crumbs + 1] = { name = continentName, onClick = function() SetMapZoom(continent) end,
            list = function() return zoneList(continent) end }
        local zoneName = zone > 0 and zoneNames(continent)[zone]
        if zoneName then
            crumbs[#crumbs + 1] = { name = zoneName, onClick = function() SetMapZoom(continent, zone) end }
        end
    elseif GetNumDungeonMapLevels() > 0 or IsInInstance() then
        crumbs[#crumbs + 1] = { name = GetRealZoneText() }
    end
    if GetNumDungeonMapLevels() > 1 then
        crumbs[#crumbs + 1] = { name = floorLabel(GetCurrentMapDungeonLevel()), list = floorList }
    end
    return crumbs
end

-- ============================================================================
-- MENU
-- ============================================================================

function WM.OpenNavMenu(anchor, entries)
    addon.Menu.Open(anchor, entries)
end

-- ============================================================================
-- CRUMBS
-- ============================================================================

local function crumbWidth(isHome, hasArrow, textWidth)
    local pad = isHome and HOME_PAD or PLAIN_PAD
    if hasArrow then pad = pad + ARROW_PAD - PLAIN_PAD end
    return textWidth + pad
end

-- Home's banner keeps its notched right edge and loses width on the left, retail's own crop.
local function cropBanner(tex, width)
    width = math.min(width, BANNER_W)
    local _, _, _, left, right, top, bottom = addon.functions.atlas_unpack("navbar-home-banner")
    tex:SetTexCoord(right - (right - left) * (width / BANNER_W), right, top, bottom)
    tex:SetWidth(width)
end

local function buildArrow(parent)
    local arrow = CreateFrame("Button", nil, parent)
    arrow:SetSize(27, 31)
    local highlight = arrow:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(32, 32)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    highlight:SetBlendMode("ADD")
    arrow.glyph = arrow:CreateTexture(nil, "OVERLAY")
    arrow.glyph:set_atlas("navbar-dropdown-arrow", true)
    arrow.glyph:SetPoint("CENTER", arrow, "CENTER", 0, -1)
    arrow:SetScript("OnMouseDown", function(self) self.glyph:SetPoint("CENTER", -1, -2) end)
    arrow:SetScript("OnMouseUp", function(self) self.glyph:SetPoint("CENTER", 0, -1) end)
    arrow:SetScript("OnClick", function(self)
        if self.list then WM.OpenNavMenu(self, self.list()) end
    end)
    return arrow
end

local function acquireCrumb(index)
    local crumb = bar.crumbs[index]
    if crumb then return crumb end

    crumb = CreateFrame("Button", nil, bar)
    crumb:SetHeight(CRUMB_H)
    crumb.isHome = index == 1

    crumb.bg = crumb:CreateTexture(nil, "BACKGROUND")
    crumb.bg:SetHeight(30)

    crumb.selected = crumb:CreateTexture(nil, "ARTWORK", nil, 0)
    crumb.selected:set_atlas("navbar-glow-selected")
    crumb.selected:SetPoint("TOPLEFT", crumb, "TOPLEFT", -2, 4)
    crumb.selected:SetPoint("BOTTOMRIGHT", crumb, "BOTTOMRIGHT", 0, -4)

    crumb.hover = crumb:CreateTexture(nil, "ARTWORK", nil, 1)
    crumb.hover:set_atlas("navbar-glow-hover")
    crumb.hover:SetPoint("TOPLEFT", crumb, "TOPLEFT", -2, 4)
    crumb.hover:SetPoint("BOTTOMRIGHT", crumb, "BOTTOMRIGHT", 0, -4)
    crumb.hover:SetBlendMode("ADD")
    crumb.hover:Hide()

    -- Above both glows, and bridging into the next crumb's left padding.
    crumb.endcap = crumb:CreateTexture(nil, "ARTWORK", nil, 2)
    crumb.endcap:set_atlas("navbar-endcap-up", true)
    crumb.endcap:SetPoint("LEFT", crumb, "RIGHT", 0, 0)

    crumb.text = crumb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    crumb.text:SetPoint("LEFT", crumb, "LEFT", crumb.isHome and TEXT_PAD_HOME or TEXT_PAD, 0)

    crumb:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 0.6)
        self.hover:Show()
    end)
    crumb:SetScript("OnLeave", function(self)
        if self.isLast then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(1, 0.82, 0) end
        self.hover:Hide()
    end)
    crumb:SetScript("OnClick", function(self)
        PlaySound("igMainMenuOptionCheckBoxOn")
        if self.onClick then self.onClick() end
    end)

    crumb.arrow = buildArrow(bar)
    bar.crumbs[index] = crumb
    return crumb
end

local function acquireOverflow()
    if bar.overflow then return bar.overflow end
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(OVERFLOW_W, 30)
    button:SetNormalTexture(addon._dir .. "UI\\ui-background-rock")
    button:GetNormalTexture():set_atlas("navbar-overflow-up")
    button:SetPushedTexture(addon._dir .. "UI\\ui-background-rock")
    button:GetPushedTexture():set_atlas("navbar-overflow-down")
    button:SetScript("OnClick", function(self)
        local list = {}
        for _, crumb in ipairs(self.hidden) do
            list[#list + 1] = { text = crumb.name, func = crumb.onClick }
        end
        WM.OpenNavMenu(self, list)
    end)
    bar.overflow = button
    return button
end

-- ============================================================================
-- LAYOUT
-- ============================================================================

local function hideCrumb(crumb)
    crumb:Hide()
    crumb.arrow:Hide()
end

local function placeCrumb(index, entry, previous, level, isLast)
    local crumb = bar.crumbs[index]
    crumb.isLast = isLast
    crumb.onClick = entry.onClick
    crumb:SetFrameLevel(level)
    crumb:ClearAllPoints()
    if previous then
        crumb:SetPoint("LEFT", previous, "RIGHT", 0, 0)
    else
        crumb:SetPoint("LEFT", bar, "LEFT", CONTENT_X, 0)
    end
    crumb:SetWidth(crumb.width)
    crumb.bg:ClearAllPoints()
    if crumb.isHome then
        crumb.bg:set_atlas("navbar-home-banner")
        crumb.bg:SetPoint("RIGHT", crumb, "RIGHT", ENDCAP_W, 0)
        cropBanner(crumb.bg, crumb.width + ENDCAP_W + HOME_BLEED)
        crumb.endcap:Hide()
    else
        crumb.bg:set_atlas("_navbar-button-tile")
        crumb.bg:SetSize(crumb.width, 30)
        crumb.bg:SetPoint("CENTER", crumb, "CENTER", 0, 0)
        crumb.endcap:Show()
    end
    if isLast and not crumb.isHome then crumb.selected:Show() else crumb.selected:Hide() end
    if isLast then crumb.text:SetTextColor(1, 1, 1) else crumb.text:SetTextColor(1, 0.82, 0) end

    crumb.arrow.list = entry.list
    if entry.list then
        crumb.arrow:ClearAllPoints()
        crumb.arrow:SetPoint("RIGHT", crumb, "RIGHT", -6, 1)
        crumb.arrow:SetFrameLevel(level + 1)
        crumb.arrow:Show()
    else
        crumb.arrow:Hide()
    end
    crumb.hover:Hide()
    crumb:Show()
    return crumb
end

local function refresh()
    if not bar or not bar:IsShown() then return end
    local entries = trail()
    local available = bar:GetWidth() - WIDTH_BUFFER
    if available <= 0 then return end

    local total = 0
    for index, entry in ipairs(entries) do
        local crumb = acquireCrumb(index)
        crumb.text:SetWidth(0)
        crumb.text:SetText(entry.name)
        crumb.width = crumbWidth(index == 1, entry.list ~= nil, crumb.text:GetStringWidth())
        total = total + crumb.width
    end

    -- Home and the current crumb never fold; the middle ones fold deepest-first until it fits.
    local first = #entries
    local budget = available - bar.crumbs[1].width - (total > available and OVERFLOW_W or 0)
    local run = 0
    for index = #entries, 2, -1 do
        run = run + bar.crumbs[index].width
        if run > budget then break end
        first = index
    end
    first = math.max(first, 2)
    local needOverflow = first > 2

    -- Levels descend left to right so each endcap draws over the crumb that follows it.
    local visible = 1 + (needOverflow and 1 or 0) + (#entries - first + 1)
    local level = bar:GetFrameLevel() + 2 + visible
    local previous = placeCrumb(1, entries[1], nil, level, #entries == 1)

    if needOverflow then
        local overflow = acquireOverflow()
        overflow.hidden = {}
        for index = 2, first - 1 do overflow.hidden[#overflow.hidden + 1] = entries[index] end
        level = level - 1
        overflow:SetFrameLevel(level)
        overflow:ClearAllPoints()
        overflow:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        overflow:Show()
        previous = overflow
    elseif bar.overflow then
        bar.overflow:Hide()
    end

    for index = first, #entries do
        level = level - 1
        previous = placeCrumb(index, entries[index], previous, level, index == #entries)
    end
    for index = 2, #bar.crumbs do
        if index < first or index > #entries then hideCrumb(bar.crumbs[index]) end
    end
end

local function relayout()
    local width = bar:GetWidth()
    if width > 0 then
        bar.bg:SetWidth(width)
        bar.sheen:SetWidth(width)
    end
    refresh()
end

-- ============================================================================
-- BUILD
-- ============================================================================

function WM.BuildNavBar()
    bar = CreateFrame("Frame", "DragonUIWorldMapNavBar", WM.border)
    bar:SetHeight(BAR_H)
    bar:SetFrameLevel(WM.border:GetFrameLevel() + 3)
    bar:SetPoint("TOPLEFT", WM.spacer, "TOPLEFT", BAR_X, BAR_Y)
    bar:SetPoint("TOPRIGHT", WM.spacer, "TOPRIGHT", BAR_RIGHT, BAR_Y)
    bar.crumbs = {}

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:set_atlas("_navbar-barbg-tile")
    bar.bg:SetHeight(BAR_H)
    bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)

    -- Own frame above every crumb: the bar overlay IS retail's rim and runs over them.
    local rim = CreateFrame("Frame", nil, bar)
    rim:SetFrameLevel(bar:GetFrameLevel() + 30)
    rim:EnableMouse(false)
    rim:SetAllPoints(bar)

    bar.sheen = rim:CreateTexture(nil, "OVERLAY")
    bar.sheen:set_atlas("_navbar-baroverlay-tile")
    bar.sheen:SetHeight(BAR_H)
    bar.sheen:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)

    -- Outset so the inset trim rings the bar from outside instead of biting into its own rim.
    addon.CharacterPanel.DrawPaneBorder(rim, bar, RIM_OUTSET)

    bar:SetScript("OnSizeChanged", relayout)
    bar:SetScript("OnShow", refresh)
    hooksecurefunc("WorldMapFrame_Update", refresh)
    WM.navBar = bar
    relayout()
end

function WM.RefreshNavBar()
    refresh()
end
