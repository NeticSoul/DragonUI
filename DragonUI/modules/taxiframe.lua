-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local type = type
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local NumTaxiNodes = NumTaxiNodes
local TaxiNodeGetType = TaxiNodeGetType
local TaxiNodePosition = TaxiNodePosition
local SetPortraitToTexture = SetPortraitToTexture

local TaxiModule = {
    initialized = false,
    applied = false,
}

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("taxiframe", TaxiModule,
        localized("Flight Map"),
        localized("Retail-style flight master map window chrome"),
        { lifecyclePrefix = "TaxiFrame", loadOnce = true })
end

local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local FLYING_ICON = DIR .. "Taxi\\icon_petfamily_flying"

-- 4x-UltraSharp redraws of the client's 512px flight maps; empty this table to show the client's own.
local HD_MAPS = {
    taximap0 = DIR .. "Taxi\\Maps\\taximap0",
    taximap1 = DIR .. "Taxi\\Maps\\taximap1",
    taximap530 = DIR .. "Taxi\\Maps\\taximap530",
    taximap571 = DIR .. "Taxi\\Maps\\taximap571",
}

-- FlightMap_FlightPointPinMixin's art and pin sizes; 3.3.5a's DISTANT is retail's unreachable nub.
local NODE_STYLES = {
    -- Retail's 28 is on a ~1000px canvas; on our 330 map it buried close neighbours (Dalaran).
    CURRENT = { atlas = "Taxi_Frame_Green", glow = "Taxi_Frame_Gray", size = 24, layer = 2 },
    REACHABLE = { atlas = "Taxi_Frame_Gray", glow = "Taxi_Frame_Gray", hover = "Taxi_Frame_Yellow", size = 20, layer = 3 },
    DISTANT = { atlas = "UI-Taxi-Icon-Nub", glow = "UI-Taxi-Icon-Nub", size = 14, layer = 1 },
}
local HOVER_LAYER = 4
-- TaxiButtonTemplate's 16px button: in 3.3.5a only that core takes the mouse, not its 32px hover glow.
local MOUSE_SIZE = 16
local GLOW_ALPHA = 0.25
local ROUTE_ALPHA = 0.85

-- The maps are square art (retail draws them 580x580); 330 keeps the window at the PR's 338 width.
local MAP_SIZE = 330
local INSET_LEFT, INSET_TOP, INSET_RIGHT, INSET_BOTTOM = 4, -60, -4, 4
local WIDTH, HEIGHT = INSET_LEFT + MAP_SIZE - INSET_RIGHT, MAP_SIZE - INSET_TOP + INSET_BOTTOM
local PANEL_X_NUDGE = 6

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("taxiframe")
    end
    return true
end

local function applySlices(host, layoutName)
    local slicer = _G.DragonUI_NineSlice
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if layout and slicer.ApplyLayout then
        slicer.ApplyLayout(host, layout)
    end
end

local function nudgePanel(window)
    if not window or not window.SetAttribute then return end
    if window:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then return end
    window:SetAttribute("UIPanelLayout-xoffset", PANEL_X_NUDGE)
    if window:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(window)
    end
end

local function dressCloseButton(cb, owner)
    if not cb then return end
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then
        CP.ModernizeCloseButton(cb, owner)
        cb:SetFrameLevel((owner:GetFrameLevel() or 1) + 22)
    end
end

local function stripStockChrome(taxiFrame)
    local keepPortrait = _G.TaxiPortrait
    local keepMap = _G.TaxiMap
    for _, region in ipairs({ taxiFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            if region ~= keepPortrait and region ~= keepMap and not region._duiOwned then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
end

local function styleNode(button, style)
    button:SetSize(style.size, style.size)
    local inset = (style.size - MOUSE_SIZE) / 2
    if inset < 0 then inset = 0 end
    button:SetHitRectInsets(inset, inset, inset, inset)
    local icon = button:GetNormalTexture()
    if icon then
        icon:SetAtlasTexture(style.atlas)
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
    end
    local glow = button:GetHighlightTexture()
    if glow then
        glow:SetAtlasTexture(style.glow)
        glow:ClearAllPoints()
        glow:SetAllPoints(button)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(GLOW_ALPHA)
    end
end

local function stackNode(button, layer)
    local routeMap = _G.TaxiRouteMap
    button:SetFrameLevel((routeMap and routeMap:GetFrameLevel() or 1) + layer)
end

-- 3.3.5a's hover glow draws over the neighbours without changing which button owns the mouse.
local hoverPin

local function onNodeEnter(button)
    local style = NODE_STYLES[TaxiNodeGetType(button:GetID())]
    if not style or not hoverPin then return end
    hoverPin.owner = button
    -- Retail lights a reachable pin yellow while hovered.
    hoverPin.icon:SetAtlasTexture(style.hover or style.atlas)
    hoverPin.glow:SetAtlasTexture(style.glow)
    stackNode(hoverPin, HOVER_LAYER)
    hoverPin:ClearAllPoints()
    hoverPin:SetAllPoints(button)
    hoverPin:Show()
end

local function onNodeLeave(button)
    if hoverPin and hoverPin.owner == button then
        hoverPin.owner = nil
        hoverPin:Hide()
    end
end

-- TaxiFrame_OnEvent re-stamps every button's NormalTexture file on each TAXIMAP_OPENED.
local function styleNodes()
    for index = 1, NumTaxiNodes() do
        local button = _G["TaxiButton" .. index]
        if button then
            if not button._duiHoverHooked then
                button._duiHoverHooked = true
                button:HookScript("OnEnter", onNodeEnter)
                button:HookScript("OnLeave", onNodeLeave)
            end
            local style = NODE_STYLES[TaxiNodeGetType(index)]
            if style then
                styleNode(button, style)
                -- Destinations stack over the green pin, which isn't a destination, so clusters stay clickable.
                stackNode(button, style.layer)
            end
        end
    end
end

-- TaxiFrame_OnEvent pins nodes to its fixed TAXI_MAP_WIDTH/HEIGHT; redo it on the square map, same nudge.
local function placeNodes()
    local map = _G.TaxiMap
    if not map then return end
    local halfW, halfH = _G.TAXI_BUTTON_HALF_WIDTH or 8, _G.TAXI_BUTTON_HALF_HEIGHT or 8
    local spots = {}
    for index = 1, NumTaxiNodes() do
        local spot = {}
        spots[index] = spot
        local button = _G["TaxiButton" .. index]
        if button and TaxiNodeGetType(index) ~= "NONE" then
            local x, y = TaxiNodePosition(index)
            x, y = x * MAP_SIZE, y * MAP_SIZE
            spot.x, spot.y = x, y
            for check = 1, index - 1 do
                local other = spots[check]
                if other.x and x > other.x - halfW and x < other.x + halfW
                    and y > other.y - halfH and y < other.y + halfH then
                    spot.x, spot.y = x + (x - other.x) * 0.5, y + (y - other.y) * 0.5
                    other.x, other.y = other.x + (other.x - x) * 0.5, other.y + (other.y - y) * 0.5
                end
            end
            button:ClearAllPoints()
            button:SetPoint("CENTER", map, "BOTTOMLEFT", spot.x, spot.y)
        end
    end
end

local function fadeRoutes()
    for index = 1, (_G.NUM_TAXI_ROUTES or 0) do
        local line = _G["TaxiRoute" .. index]
        if line then
            line:SetAlpha(ROUTE_ALPHA)
        end
    end
end

-- SetTaxiMap stamps the client file on every open; a missing HD file falls back to it.
local function swapHDMap()
    local map = _G.TaxiMap
    local path = map and map:GetTexture()
    if type(path) ~= "string" then return end
    local name = path:match("([^\\/]+)$"):gsub("%.%w+$", ""):lower()
    local hd = HD_MAPS[name]
    if hd and not map:SetTexture(hd) then
        map:SetTexture(path)
    end
end

local function dressOpenedMap()
    if hoverPin then
        hoverPin.owner = nil
        hoverPin:Hide()
    end
    swapHDMap()
    placeNodes()
    styleNodes()
    if _G.TaxiPortrait and SetPortraitToTexture then
        SetPortraitToTexture(_G.TaxiPortrait, FLYING_ICON)
    end
end

local function buildTaxiFrame()
    local taxiFrame = _G.TaxiFrame
    if not taxiFrame or taxiFrame._duiSkinned then return end
    taxiFrame._duiSkinned = true

    stripStockChrome(taxiFrame)
    taxiFrame:SetSize(WIDTH, HEIGHT)
    if taxiFrame.SetHitRectInsets then
        taxiFrame:SetHitRectInsets(0, 0, 0, 0)
    end
    nudgePanel(taxiFrame)

    local rock = taxiFrame:CreateTexture(nil, "BACKGROUND")
    rock._duiOwned = true
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", taxiFrame, "BOTTOMRIGHT", -2, 2)

    local streaks = taxiFrame:CreateTexture(nil, "BORDER")
    streaks._duiOwned = true
    streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", 6, -21)
    streaks:SetPoint("BOTTOMRIGHT", taxiFrame, "TOPRIGHT", -2, -64)

    applySlices(taxiFrame, "PortraitFrameTemplate")

    local portrait = _G.TaxiPortrait
    if portrait then
        portrait._duiOwned = true
        portrait:ClearAllPoints()
        -- Retail's CircleMask window over its 62x62 portrait at -5,7 (inset 2,0,-2,4).
        portrait:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", -3, 7)
        portrait:SetSize(58, 58)
        portrait:SetDrawLayer("ARTWORK")
        portrait:SetAlpha(1)
        portrait:Show()
    end

    -- Retail's TitleContainer: TaxiMerchant sits on the window itself, under the OVERLAY title metal.
    if _G.TaxiMerchant then
        _G.TaxiMerchant:Hide()
    end
    local titleBar = CreateFrame("Frame", nil, taxiFrame)
    titleBar:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", 58, -1)
    titleBar:SetPoint("TOPRIGHT", taxiFrame, "TOPRIGHT", -24, -1)
    titleBar:SetHeight(20)
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, -5)
    title:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, -5)
    title:SetJustifyH("CENTER")
    title:SetText(localized("Flight Map"))

    dressCloseButton(_G.TaxiCloseButton, taxiFrame)

    local inset = CreateFrame("Frame", nil, taxiFrame)
    inset:EnableMouse(false)
    inset:SetFrameLevel((taxiFrame:GetFrameLevel() or 1) + 1)
    inset:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", INSET_LEFT, INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", taxiFrame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
    applySlices(inset, "InsetFrameTemplate")

    -- Retail's map IS the inset background, its trim drawn over the map edge: no margin to squeeze it.
    local taxiMap = _G.TaxiMap
    if taxiMap then
        taxiMap:ClearAllPoints()
        taxiMap:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", INSET_LEFT, INSET_TOP)
        taxiMap:SetSize(MAP_SIZE, MAP_SIZE)
        taxiMap:SetDrawLayer("ARTWORK")
    end

    local routeMap = _G.TaxiRouteMap
    if routeMap and taxiMap then
        routeMap:ClearAllPoints()
        routeMap:SetAllPoints(taxiMap)
        routeMap:SetSize(MAP_SIZE, MAP_SIZE)
        routeMap:SetFrameLevel(inset:GetFrameLevel() + 2)

        hoverPin = CreateFrame("Frame", nil, routeMap)
        hoverPin:Hide()
        hoverPin.icon = hoverPin:CreateTexture(nil, "ARTWORK")
        hoverPin.icon:SetAllPoints(hoverPin)
        hoverPin.glow = hoverPin:CreateTexture(nil, "OVERLAY")
        hoverPin.glow:SetAllPoints(hoverPin)
        hoverPin.glow:SetBlendMode("ADD")
        hoverPin.glow:SetAlpha(GLOW_ALPHA)
    end

    -- Runs after the XML-bound TaxiFrame_OnEvent, which hooksecurefunc on the global would miss.
    taxiFrame:HookScript("OnEvent", function(_, event)
        if event == "TAXIMAP_OPENED" then
            dressOpenedMap()
        end
    end)
    for _, drawer in ipairs({ "DrawOneHopLines", "TaxiNodeOnButtonEnter" }) do
        if _G[drawer] then
            hooksecurefunc(drawer, fadeRoutes)
        end
    end
    if taxiFrame:IsShown() then
        dressOpenedMap()
    end
end

function addon.ApplyTaxiFrameSystem()
    if not IsModuleEnabled() then return end
    TaxiModule.initialized = true
    TaxiModule.applied = true
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("taxiframe_apply", buildTaxiFrame)
        return
    end
    buildTaxiFrame()
end

function addon.RestoreTaxiFrameSystem()
    TaxiModule.applied = false
end

function addon.RefreshTaxiFrameSystem()
    if IsModuleEnabled() then
        addon.ApplyTaxiFrameSystem()
    else
        addon.RestoreTaxiFrameSystem()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("TAXIMAP_OPENED")
boot:SetScript("OnEvent", function(_, event)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_LOGIN" then
        addon.ApplyTaxiFrameSystem()
    elseif event == "TAXIMAP_OPENED" then
        buildTaxiFrame()
    end
end)
