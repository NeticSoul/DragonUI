-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

local MODEL_W, MODEL_H = 231, 320
local VANILLA_W, VANILLA_H = 233, 215
local VANILLA_X, VANILLA_Y = 65, -78

-- Blizzard's own DressUpTexturePath applies this same fallback: the 3.3.5a client ships no
-- Gnome or Troll backdrop art.
local RACE_FALLBACK = { GNOME = "Dwarf", TROLL = "Orc" }

local function raceKey()
    local _, fileName = UnitRace("player")
    if not fileName then return "ORC" end
    local upper = strupper(fileName)
    return strupper(RACE_FALLBACK[upper] or fileName)
end

local function racePath()
    local _, fileName = UnitRace("player")
    if not fileName then return "Interface\\DressUpFrame\\DressUpBackground-Orc" end
    local upper = strupper(fileName)
    fileName = RACE_FALLBACK[upper] or fileName
    return "Interface\\DressUpFrame\\DressUpBackground-" .. fileName
end

-- How dark retail's paperdoll shades each race's art.
local SHADE_BY_RACE = {
    BLOODELF = 0.8, SCOURGE = 0.3, WORGEN = 0.5,
    NIGHTELF = 0.6, ORC = 0.6, TROLL = 0.6, GOBLIN = 0.6,
}
local SHADE_DEFAULT = 0.7

-- Retail's viewport sits at (52, -66) of the frame and the Inset starts at (4, -60).
local FROM_INSET_X, FROM_INSET_Y = 48, -6

local function resizeViewport()
    local viewport, owner = _G.CharacterModelFrame, _G.CharacterFrame
    local inset = owner and owner.Inset
    if viewport == nil or inset == nil or viewport._duiResized then return end

    viewport._duiResized = true
    viewport:SetSize(MODEL_W, MODEL_H)
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", inset, "TOPLEFT", FROM_INSET_X, FROM_INSET_Y)
end

-- Cropped to the viewport: 245 + 75 = 320, the model's exact height. Retail runs the bottom pair
-- their full 128, which made the strip under the model depend on that overhang drawing.
local BOTTOM_CROP = 75 / 128
local QUARTERS = {
    { key = "TopLeft", suffix = 1, w = 212, h = 245, tc = { 0.171875, 1, 0.0392156862745098, 1 },
      point = "TOPLEFT", rel = "TOPLEFT" },
    { key = "TopRight", suffix = 2, w = 19, h = 245, tc = { 0, 0.296875, 0.0392156862745098, 1 },
      point = "TOPLEFT", rel = "TOPRIGHT" },
    { key = "BotLeft", suffix = 3, w = 212, h = 75, tc = { 0.171875, 1, 0, BOTTOM_CROP },
      point = "TOPLEFT", rel = "BOTTOMLEFT" },
    { key = "BotRight", suffix = 4, w = 19, h = 75, tc = { 0, 0.296875, 0, BOTTOM_CROP },
      point = "TOPLEFT", rel = "BOTTOMRIGHT" },
}

local function shadeFor(key)
    return SHADE_BY_RACE[key] or SHADE_DEFAULT
end

local function addQuarter(viewport, entry, relativeTo)
    local piece = viewport:CreateTexture(nil, "BACKGROUND")
    local coords = entry.tc
    piece:SetWidth(entry.w)
    piece:SetHeight(entry.h)
    piece:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    piece:SetPoint(entry.point, relativeTo, entry.rel, 0, 0)
    return piece
end

local function createBackdrop()
    local viewport = _G.CharacterModelFrame
    if viewport == nil or viewport._duiRaceBg then return end

    -- Every other quarter anchors to the top-left one, so it is made before the rest.
    local anchorEntry
    for _, entry in ipairs(QUARTERS) do
        if entry.key == "TopLeft" then anchorEntry = entry break end
    end
    if not anchorEntry then return end

    local bySuffix = {}
    viewport._duiRaceBg = bySuffix
    local anchorPiece = addQuarter(viewport, anchorEntry, viewport)
    bySuffix[anchorEntry.suffix] = anchorPiece
    for _, entry in ipairs(QUARTERS) do
        if entry ~= anchorEntry then
            bySuffix[entry.suffix] = addQuarter(viewport, entry, anchorPiece)
        end
    end

    -- Held to the viewport's corner, not the art's, so the shade ends exactly where the model does.
    local shade = viewport:CreateTexture(nil, "BORDER")
    viewport._duiRaceBgOverlay = shade
    shade:SetPoint("BOTTOMRIGHT", viewport)
    shade:SetPoint("TOPLEFT", anchorPiece)
    shade:SetTexture(0, 0, 0)
end

local function paintBackdrop()
    local viewport = _G.CharacterModelFrame
    if not (viewport and viewport._duiRaceBg) then return end

    -- Plain truth test: the pre-database config is {}, and a missing key must read as colour.
    local desaturate = CP:Config().grey_model_backdrop and true or false
    local artBase = racePath()
    for suffix, piece in pairs(viewport._duiRaceBg) do
        piece:SetTexture(artBase .. suffix)
        piece:SetDesaturated(desaturate)
        piece:Show()
    end

    local shade = viewport._duiRaceBgOverlay
    if shade then
        shade:SetAlpha(desaturate and shadeFor(raceKey()) or 0)
        shade:Show()
    end
end

CP.ApplyModelBackdrop = paintBackdrop

-- Blizzard anchors the viewport in XML only; nothing else undoes our placement without a reload.
function CP.RestoreModel()
    local model = _G.CharacterModelFrame
    if not model then return end
    model._duiResized = nil

    model:SetSize(VANILLA_W, VANILLA_H)
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", model:GetParent(), "TOPLEFT", VANILLA_X, VANILLA_Y)

    if model._duiRaceBg then
        for _, tex in pairs(model._duiRaceBg) do tex:Hide() end
    end
    if model._duiRaceBgOverlay then model._duiRaceBgOverlay:Hide() end
end

-- The art hangs off the viewport, so the viewport has to be at its final size first.
local function build()
    resizeViewport()
    createBackdrop()
    paintBackdrop()
end

CP.RefreshRaceBackground = CP.ApplyModelBackdrop

CP:RegisterBuilder("model", build)
