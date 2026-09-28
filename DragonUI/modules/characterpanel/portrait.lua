-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Blizzard's portrait is 60x60 at TOPLEFT(7,-6) for the wooden frame; retail's is 62x62 at
-- TOPLEFT(-5,7), which is where the ring baked into our top-left chrome corner sits.
local PORTRAIT_SIZE = 62
local PORTRAIT_X, PORTRAIT_Y = -5, 7
local VANILLA_SIZE = 60
local VANILLA_X, VANILLA_Y = 7, -6

-- 3.3.5a has no mask textures, so SQUARE art has to shrink until its corners clear the circular
-- cutout. Blizzard's UI-Classes-Circles is exempt: that art is already circular.
local SQUARE_INSET = 3

local function applySquareArt(p, cf)
    p:SetSize(PORTRAIT_SIZE - SQUARE_INSET * 2, PORTRAIT_SIZE - SQUARE_INSET * 2)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", PORTRAIT_X + SQUARE_INSET, PORTRAIT_Y - SQUARE_INSET)
end

local function applyGeometry()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    if not p or not cf or p._duiGeometry then return end
    p._duiGeometry = true

    p:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
end

local function setClassPortrait()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    if not p or not cf then return end
    local _, classFile = UnitClass("player")
    if not classFile then return end

    -- DragonUI's HD class icons are square art, so they need the same inset as the face.
    if addon.UF and addon.UF.ApplyClassPortraitIcon then
        if addon.UF.ApplyClassPortraitIcon(p, classFile, true) then
            applySquareArt(p, cf)
            p._duiMode = "class"
            return
        end
    end

    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if not coords then return end
    p:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
    p:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    p:SetTexCoord(unpack(coords))
    p._duiMode = "class"
end

-- Coords reset first: the class icon leaves a sub-rect behind that SetPortraitTexture keeps.
local function showPlayerFace()
    local icon, owner = _G.CharacterFramePortrait, _G.CharacterFrame
    if icon == nil or owner == nil then return end

    icon:SetTexCoord(0, 1, 0, 1)
    applySquareArt(icon, owner)
    if SetPortraitTexture then SetPortraitTexture(icon, "player") end
    icon._duiMode = "face"
end

local function refreshPortrait()
    if not CP:Enabled() then return end
    local useClassArt = CP:Config().class_portrait
    if useClassArt then setClassPortrait() else showPlayerFace() end
end

CP.UpdatePortrait = refreshPortrait

function CP.RestorePortrait()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    if not p or not cf then return end
    p._duiGeometry = nil
    p._duiMode = nil

    p:SetSize(VANILLA_SIZE, VANILLA_SIZE)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", VANILLA_X, VANILLA_Y)
    -- The class icon samples a sub-rect, and SetPortraitTexture does not reset it.
    p:SetTexCoord(0, 1, 0, 1)
    if SetPortraitTexture then SetPortraitTexture(p, "player") end
end

-- Blizzard redoes its portrait on a display resize without going through CharacterFrame_OnEvent.
local portraitEvents = CreateFrame("Frame")
for _, event in ipairs({ "DISPLAY_SIZE_CHANGED", "UNIT_PORTRAIT_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    portraitEvents:RegisterEvent(event)
end
portraitEvents:SetScript("OnEvent", function(_, event, unit)
    if event ~= "UNIT_PORTRAIT_UPDATE" or unit == "player" then refreshPortrait() end
end)

local showHookInstalled, eventHookInstalled = false, false

local function build()
    local owner = _G.CharacterFrame
    if owner == nil then return end
    applyGeometry()

    if not showHookInstalled then
        owner:HookScript("OnShow", refreshPortrait)
        showHookInstalled = true
    end
    -- Blizzard's OnEvent calls SetPortraitTexture on UNIT_PORTRAIT_UPDATE, over our art.
    if not eventHookInstalled and _G.CharacterFrame_OnEvent then
        hooksecurefunc("CharacterFrame_OnEvent", refreshPortrait)
        eventHookInstalled = true
    end

    refreshPortrait()
end

CP:RegisterBuilder("portrait", build)
