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

-- Retail shows the spec; 3.3.5a's nearest is the active talent group's tree with the most points.
function CP.ActiveSpec()
    if not GetNumTalentTabs or not GetTalentTabInfo then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup(false, false) or 1
    local name, icon, most = nil, nil, 0
    for tab = 1, GetNumTalentTabs(false, false) or 0 do
        local treeName, texture, points = GetTalentTabInfo(tab, false, false, group)
        if (points or 0) > most then name, icon, most = treeName, texture, points end
    end
    return name, icon
end

local function activeSpecIcon()
    return select(2, CP.ActiveSpec())
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

-- Pre-rounded 128px versions of the talent tree icons (scripts/specportraits); keyed by icon file name.
local SPEC_PORTRAIT_DIR = addon._dir .. "CharacterPanel\\SpecPortraits\\"
local SPEC_PORTRAITS = {
    ["ability_backstab"] = true,
    ["ability_hunter_beasttaming"] = true,
    ["ability_hunter_swiftstrike"] = true,
    ["ability_marksmanship"] = true,
    ["ability_racial_bearform"] = true,
    ["ability_rogue_eviscerate"] = true,
    ["ability_stealth"] = true,
    ["ability_warrior_innerrage"] = true,
    ["inv_shield_06"] = true,
    ["spell_deathknight_bloodpresence"] = true,
    ["spell_deathknight_frostpresence"] = true,
    ["spell_deathknight_unholypresence"] = true,
    ["spell_fire_firebolt02"] = true,
    ["spell_frost_frostbolt02"] = true,
    ["spell_holy_auraoflight"] = true,
    ["spell_holy_devotionaura"] = true,
    ["spell_holy_guardianspirit"] = true,
    ["spell_holy_holybolt"] = true,
    ["spell_holy_magicalsentry"] = true,
    ["spell_holy_wordfortitude"] = true,
    ["spell_nature_healingtouch"] = true,
    ["spell_nature_lightning"] = true,
    ["spell_nature_lightningshield"] = true,
    ["spell_nature_magicimmunity"] = true,
    ["spell_nature_starfall"] = true,
    ["spell_shadow_deathcoil"] = true,
    ["spell_shadow_metamorphosis"] = true,
    ["spell_shadow_rainoffire"] = true,
    ["spell_shadow_shadowwordpain"] = true,
}

-- As big as the class circle so the ring frames it; an icon we have no HD art for is rounded by the client.
local function setSpecPortrait()
    local p = _G.CharacterFramePortrait
    local cf = _G.CharacterFrame
    local icon = activeSpecIcon()
    if not p or not cf or not icon then return false end

    local name = string.lower(icon:match("([^\\/]+)$") or "")
    if SPEC_PORTRAITS[name] then
        p:SetTexture(SPEC_PORTRAIT_DIR .. name)
    elseif SetPortraitToTexture then
        SetPortraitToTexture(p, icon)
    else
        return false
    end
    p:SetTexCoord(0, 1, 0, 1)
    applySquareArt(p, cf)
    p._duiMode = "spec"
    return true
end

-- "character", "class" or "spec"; profiles from before stored a class/face toggle, false being the face.
function CP.PortraitStyle()
    local cfg = CP:Config()
    if cfg.class_portrait ~= nil then
        if cfg.class_portrait == false then cfg.portrait_style = "character" end
        cfg.class_portrait = nil
    end
    return cfg.portrait_style or "spec"
end

local function refreshPortrait()
    if not CP:Enabled() then return end
    local style = CP.PortraitStyle()
    if style == "character" then
        showPlayerFace()
    elseif style == "class" or not setSpecPortrait() then
        -- No talents yet, no spec: the class icon stands in.
        setClassPortrait()
    end
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
for _, event in ipairs({ "DISPLAY_SIZE_CHANGED", "UNIT_PORTRAIT_UPDATE", "PLAYER_ENTERING_WORLD",
                         "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" }) do
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
