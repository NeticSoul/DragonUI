-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local type = type
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local SetPortraitTexture = SetPortraitTexture
local NumTaxiNodes = NumTaxiNodes
local TaxiNodePosition = TaxiNodePosition

local TaxiModule = {
    initialized = false,
    applied = false,
}

if addon.defaults and addon.defaults.profile and addon.defaults.profile.modules then
    if addon.defaults.profile.modules.taxiframe == nil then
        addon.defaults.profile.modules.taxiframe = { enabled = true }
    end
end
if addon.db and addon.db.profile and addon.db.profile.modules then
    if addon.db.profile.modules.taxiframe == nil then
        addon.db.profile.modules.taxiframe = { enabled = true }
    end
end

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
local MARBLE = DIR .. "UI\\ui-background-marble"
local REDBUTTON = DIR .. "UI\\redbutton2x"

local WIDTH, HEIGHT = 338, 424
local INSET_LEFT, INSET_TOP, INSET_RIGHT, INSET_BOTTOM = 4, -60, -6, 4
local MAP_X, MAP_Y, MAP_W, MAP_H = 10, -64, 316, 352
local PANEL_X_NUDGE = 6

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("taxiframe")
    end
    return true
end

local function applySlices(host, layoutName)
    local slicer = _G.DragonUI_NineSlice or _G.NineSliceUtils
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if layout and slicer.ApplyLayout then
        slicer.ApplyLayout(host, layout)
    end
end

local function setAtlas(tex, name)
    if not tex then return end
    if tex.SetAtlasTexture then
        tex:SetAtlasTexture(name)
    elseif tex.set_atlas then
        tex:set_atlas(name)
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
    if not cb or cb._duiModernized then return end
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then
        CP.ModernizeCloseButton(cb, owner)
        cb:SetFrameLevel((owner:GetFrameLevel() or 1) + 22)
        return
    end
    cb._duiModernized = true
    cb:SetSize(24, 24)
    cb:ClearAllPoints()
    cb:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 1, 0)
    cb:SetFrameLevel((owner:GetFrameLevel() or 1) + 22)

    local function dress(getter, l, r, t, b, blend)
        local tex = cb[getter] and cb[getter](cb)
        if not tex then return end
        tex:SetTexture(REDBUTTON)
        tex:SetTexCoord(l, r, t, b)
        if blend then tex:SetBlendMode(blend) end
    end

    dress("GetNormalTexture", 39/256, 75/256, 1/128, 39/128)
    dress("GetPushedTexture", 39/256, 75/256, 81/128, 119/128)
    dress("GetDisabledTexture", 39/256, 75/256, 41/128, 79/128)
    dress("GetHighlightTexture", 115/256, 151/256, 1/128, 39/128, "ADD")
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

local function syncTaxiNodes()
    local taxiMap = _G.TaxiMap
    if not taxiMap or not NumTaxiNodes then return end
    local w, h = taxiMap:GetWidth(), taxiMap:GetHeight()
    if not (w and h and w > 0 and h > 0) then return end
    local numNodes = NumTaxiNodes() or 0
    for i = 1, numNodes do
        local btn = _G["TaxiButton" .. i]
        if btn and btn:IsShown() then
            local x, y = TaxiNodePosition(btn:GetID())
            if x and y then
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", taxiMap, "BOTTOMLEFT", x * w, y * h)
            end
        end
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

    local rock = taxiFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
    rock._duiOwned = true
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", taxiFrame, "BOTTOMRIGHT", -2, 2)

    local streaks = taxiFrame:CreateTexture(nil, "BORDER")
    streaks._duiOwned = true
    setAtlas(streaks, "_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", 6, -21)
    streaks:SetPoint("BOTTOMRIGHT", taxiFrame, "TOPRIGHT", -2, -64)

    applySlices(taxiFrame, "PortraitFrameTemplate")

    local portrait = _G.TaxiPortrait
    if portrait then
        portrait._duiOwned = true
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", -2, 4)
        portrait:SetSize(56, 56)
        portrait:SetDrawLayer("ARTWORK")
        portrait:SetAlpha(1)
        portrait:Show()
    end

    local title = _G.TaxiMerchant
    if title then
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", 60, -5)
        title:SetPoint("TOPRIGHT", taxiFrame, "TOPRIGHT", -24, -5)
        title:SetHeight(16)
        title:SetJustifyH("CENTER")
    end

    dressCloseButton(_G.TaxiCloseButton, taxiFrame)

    local inset = CreateFrame("Frame", nil, taxiFrame)
    inset:EnableMouse(false)
    inset:SetFrameLevel(taxiFrame:GetFrameLevel())
    inset:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", INSET_LEFT, INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", taxiFrame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
    applySlices(inset, "InsetFrameTemplate")

    local marble = taxiFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
    marble._duiOwned = true
    marble:SetTexture(MARBLE)
    marble:SetHorizTile(true)
    marble:SetVertTile(true)
    marble:SetAllPoints(inset)

    local taxiMap = _G.TaxiMap
    if taxiMap then
        taxiMap:ClearAllPoints()
        taxiMap:SetPoint("TOPLEFT", taxiFrame, "TOPLEFT", MAP_X, MAP_Y)
        taxiMap:SetSize(MAP_W, MAP_H)
        taxiMap:SetDrawLayer("ARTWORK")
    end

    local routeMap = _G.TaxiRouteMap
    if routeMap and taxiMap then
        routeMap:ClearAllPoints()
        routeMap:SetAllPoints(taxiMap)
        routeMap:SetSize(MAP_W, MAP_H)
        routeMap:SetFrameLevel(inset:GetFrameLevel() + 2)
    end

    _G.TAXIMAP_WIDTH = MAP_W
    _G.TAXIMAP_HEIGHT = MAP_H

    taxiFrame:HookScript("OnShow", function()
        if _G.TaxiPortrait then
            SetPortraitTexture(_G.TaxiPortrait, "npc")
        end
        syncTaxiNodes()
    end)
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
        syncTaxiNodes()
    end
end)