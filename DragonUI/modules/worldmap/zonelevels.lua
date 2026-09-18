-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local WM = addon.WorldMap

-- AreaTable.dbc carries one exploration level and no range, so this list is kept by hand.
-- Keyed by GetMapInfo()'s map file, like fogdata and graveyarddata. Cities are left out on purpose.
WM.ZoneLevels = {
    ["Elwynn"] = { 1, 10 }, ["DunMorogh"] = { 1, 10 }, ["Tirisfal"] = { 1, 10 },
    ["Durotar"] = { 1, 10 }, ["Mulgore"] = { 1, 10 }, ["Teldrassil"] = { 1, 10 },
    ["EversongWoods"] = { 1, 10 }, ["AzuremystIsle"] = { 1, 10 },
    ["Westfall"] = { 10, 20 }, ["LochModan"] = { 10, 20 }, ["Silverpine"] = { 10, 20 },
    ["Darkshore"] = { 10, 20 }, ["Ghostlands"] = { 10, 20 }, ["BloodmystIsle"] = { 10, 20 },
    ["Barrens"] = { 10, 25 }, ["Redridge"] = { 15, 25 }, ["StonetalonMountains"] = { 15, 27 },
    ["Ashenvale"] = { 18, 30 }, ["Duskwood"] = { 18, 30 }, ["Hilsbrad"] = { 20, 30 },
    ["Wetlands"] = { 20, 30 }, ["ThousandNeedles"] = { 25, 35 },
    ["Alterac"] = { 30, 40 }, ["Arathi"] = { 30, 40 }, ["Desolace"] = { 30, 40 },
    ["Stranglethorn"] = { 30, 45 }, ["Badlands"] = { 35, 45 },
    ["SwampOfSorrows"] = { 35, 45 }, ["Dustwallow"] = { 35, 45 },
    ["Hinterlands"] = { 40, 50 }, ["Feralas"] = { 40, 50 }, ["Tanaris"] = { 40, 50 },
    ["SearingGorge"] = { 43, 50 }, ["BlastedLands"] = { 45, 55 }, ["Aszhara"] = { 45, 55 },
    ["Felwood"] = { 48, 55 }, ["UngoroCrater"] = { 48, 55 },
    ["BurningSteppes"] = { 50, 58 }, ["WesternPlaguelands"] = { 51, 58 },
    ["EasternPlaguelands"] = { 53, 60 }, ["ScarletEnclave"] = { 55, 58 },
    ["DeadwindPass"] = { 55, 60 }, ["Silithus"] = { 55, 60 },
    ["Winterspring"] = { 55, 60 }, ["Moonglade"] = { 55, 60 },
    ["Hellfire"] = { 58, 63 }, ["Zangarmarsh"] = { 60, 64 }, ["TerokkarForest"] = { 62, 65 },
    ["Nagrand"] = { 64, 67 }, ["BladesEdgeMountains"] = { 65, 68 },
    ["Netherstorm"] = { 67, 70 }, ["ShadowmoonValley"] = { 67, 70 }, ["Sunwell"] = { 70, 70 },
    ["BoreanTundra"] = { 68, 72 }, ["HowlingFjord"] = { 68, 72 },
    ["Dragonblight"] = { 71, 75 }, ["GrizzlyHills"] = { 73, 75 }, ["ZulDrak"] = { 74, 77 },
    ["SholazarBasin"] = { 76, 78 }, ["CrystalsongForest"] = { 77, 80 },
    ["TheStormPeaks"] = { 77, 80 }, ["IcecrownGlacier"] = { 77, 80 },
    ["HrothgarsLanding"] = { 77, 80 }, ["LakeWintergrasp"] = { 77, 80 },
}

local function difficultyHex(level)
    local color = GetQuestDifficultyColor(level)
    return string.format("|cff%02x%02x%02x", math.floor(color.r * 255 + 0.5),
        math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
end

local function rangeText(minLevel, maxLevel)
    if maxLevel and maxLevel > minLevel then
        return string.format(LFD_LEVEL_FORMAT_RANGE, minLevel, maxLevel)
    end
    return string.format(LFD_LEVEL_FORMAT_SINGLE, minLevel)
end

function WM.ZoneLevelSuffix(mapFile)
    if WM:Config().zoneLevels == false then return "" end
    local range = mapFile and WM.ZoneLevels[mapFile]
    if not range then return "" end
    return " " .. difficultyHex(range[2]) .. rangeText(range[1], range[2]) .. "|r"
end

-- Not minLevel/maxLevel: those are the gate to enter, so every level-cap raid reads "70 - 83". The
-- recommended band is what the instance was built for, capped because its top runs past the cap too.
function WM.DungeonLevelText(lfgID)
    if not lfgID or WM:Config().zoneLevels == false then return end
    local _, _, _, _, recLevel, minLevel, maxLevel = GetLFGDungeonInfo(lfgID)
    if not minLevel or minLevel <= 0 then
        if not recLevel or recLevel <= 0 then return end
        return rangeText(recLevel, recLevel)
    end
    local cap = (MAX_PLAYER_LEVEL or 0) > 0 and MAX_PLAYER_LEVEL or nil
    if cap and maxLevel and maxLevel > cap then maxLevel = cap end
    if maxLevel and maxLevel < minLevel then maxLevel = minLevel end
    return rangeText(minLevel, maxLevel)
end
