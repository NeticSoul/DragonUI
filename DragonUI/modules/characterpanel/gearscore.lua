-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- TankadinTV's GearScore, the number every 3.3.5a player already recognises. Ported from the
-- algorithm KPack's GearScoreLite carries; the optional enchant bonus is left out on purpose, so
-- this reports the plain score rather than that fork's inflated one.

local SCALE = 1.8618

-- Weight per equipment slot: a two-hander counts double, a relic or a ring a fraction.
local SLOT_MOD = {
    INVTYPE_RELIC = 0.3164,
    INVTYPE_TRINKET = 0.5625,
    INVTYPE_2HWEAPON = 2.0,
    INVTYPE_WEAPONMAINHAND = 1.0,
    INVTYPE_WEAPONOFFHAND = 1.0,
    INVTYPE_RANGED = 0.3164,
    INVTYPE_THROWN = 0.3164,
    INVTYPE_RANGEDRIGHT = 0.3164,
    INVTYPE_SHIELD = 1.0,
    INVTYPE_WEAPON = 1.0,
    INVTYPE_HOLDABLE = 1.0,
    INVTYPE_HEAD = 1.0,
    INVTYPE_NECK = 0.5625,
    INVTYPE_SHOULDER = 0.75,
    INVTYPE_CHEST = 1.0,
    INVTYPE_ROBE = 1.0,
    INVTYPE_WAIST = 0.75,
    INVTYPE_LEGS = 1.0,
    INVTYPE_FEET = 0.75,
    INVTYPE_WRIST = 0.5625,
    INVTYPE_HAND = 0.75,
    INVTYPE_FINGER = 0.5625,
    INVTYPE_CLOAK = 0.5625,
    INVTYPE_BODY = 0,
}

-- Two curves keyed by rarity: raid-era gear runs off A, everything at or under item level 120 off B.
local FORMULA_A = {
    [4] = { a = 91.45, b = 0.65 },
    [3] = { a = 81.375, b = 0.8125 },
    [2] = { a = 73.0, b = 1.0 },
}
local FORMULA_B = {
    [4] = { a = 26.0, b = 1.2 },
    [3] = { a = 0.75, b = 1.8 },
    [2] = { a = 8.0, b = 2.0 },
}

-- Hunters score their weapon as a stat stick and their bow as the real weapon, so the two swap
-- weights. Titan's Grip halves both hands, or a two-hander in each would count as four.
local HUNTER_MELEE, HUNTER_RANGED = 0.3164, 5.3224

local function itemScore(link)
    if not link then return 0 end

    local ok, _, _, rarity, ilvl, _, _, _, _, equipLoc = pcall(GetItemInfo, link)
    if not ok or not (rarity and ilvl and equipLoc) then return 0 end

    local slotMod = SLOT_MOD[equipLoc]
    if not slotMod then return 0 end

    local qualityScale = 1
    if rarity == 5 then
        qualityScale, rarity = 1.3, 4
    elseif rarity == 0 or rarity == 1 then
        qualityScale, rarity = 0.005, 2
    end
    -- Heirlooms scale with the wearer, so they are scored at the level cap's rarity instead.
    if rarity == 7 then
        rarity, ilvl = 3, 187.05
    end

    local row = ((ilvl > 120) and FORMULA_A or FORMULA_B)[rarity]
    if not row then return 0 end

    local score = math.floor(((ilvl - row.a) / row.b) * slotMod * SCALE * qualityScale)
    return score > 0 and score or 0
end

local function equipLocOf(link)
    if not link then return nil end
    local ok, _, _, _, _, _, _, _, _, equipLoc = pcall(GetItemInfo, link)
    return ok and equipLoc or nil
end

function CP.GetGearScore(unit)
    unit = unit or "player"
    if not GetInventoryItemLink then return 0 end

    local _, class = UnitClass(unit)
    local hunter = class == "HUNTER"
    local total = 0

    local offHand = GetInventoryItemLink(unit, 17)
    local titanGrip = 1
    if equipLocOf(GetInventoryItemLink(unit, 16)) == "INVTYPE_2HWEAPON"
        and equipLocOf(offHand) == "INVTYPE_2HWEAPON" then
        titanGrip = 0.5
    end

    -- Scored ahead of the loop, which then skips it: the off hand is the slot Titan's Grip is
    -- detected from, so its weight is only settled once both hands have been read.
    if offHand then
        local score = itemScore(offHand)
        if hunter then score = score * HUNTER_MELEE end
        total = total + score * titanGrip
    end

    -- 4 is the shirt, which is worth nothing, and 17 is already in.
    for slot = 1, 18 do
        if slot ~= 4 and slot ~= 17 then
            local link = GetInventoryItemLink(unit, slot)
            if link then
                local score = itemScore(link)
                if hunter and slot == 16 then
                    score = score * HUNTER_MELEE
                elseif hunter and slot == 18 then
                    score = score * HUNTER_RANGED
                end
                if slot == 16 then score = score * titanGrip end
                total = total + score
            end
        end
    end

    return math.floor(total > 0 and total or 0)
end

addon.GetGearScore = CP.GetGearScore
