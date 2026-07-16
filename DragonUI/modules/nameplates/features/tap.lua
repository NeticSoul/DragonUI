-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates tap-denied: GUID-keyed gray health tint (learned via live unit tokens).

NP.tap = NP.tap or {}

local TAP_DENIED_R, TAP_DENIED_G, TAP_DENIED_B = 0.6, 0.6, 0.6

function NP.tap.IsEnabled()
    return NP.config.GetCfg().tapDeniedGray ~= false
end

function NP.tap.WipeCache()
    wipe(NP.state.PlateTapCache)
end

function NP.tap.PruneCache()
    local cache = NP.state.PlateTapCache
    local guidToPlate = NP.state.GUIDToPlate
    for guid in pairs(cache) do
        local plateData = guidToPlate[guid]
        local live = plateData and plateData.plate and plateData.plate.IsShown
            and plateData.plate:IsShown()
        if not live then
            cache[guid] = nil
        end
    end
end

-- Already-resolved tokens only — never probe nameplate1..40 from the color hot path.
local function GetCachedLiveUnit(plateData)
    local identity = NP.identity
    if not identity then
        return nil
    end
    if identity.IsTargetPlate(plateData) then
        return "target"
    end
    if identity.IsFocusPlate(plateData) then
        return "focus"
    end
    if identity.IsMouseoverPlate(plateData) then
        return "mouseover"
    end
    local token = plateData.namePlateUnitToken
    if token and UnitExists(token) then
        return token
    end
    token = plateData.unitToken
    if token and token ~= "" and UnitExists(token) then
        return token
    end
    local matched = plateData._matchedCastUnit
    if matched and UnitExists(matched) then
        return matched
    end
    local arena = plateData.arenaCastUnit
    if arena and UnitExists(arena) then
        return arena
    end
    return nil
end

-- Writes UnitIsTapped and not UnitIsTappedByPlayer under the unit GUID.
local function StoreTapFromUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local guid = UnitGUID(unit)
    if not guid then
        return nil
    end
    local denied = (UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) and true or false
    NP.state.PlateTapCache[guid] = denied
    return denied
end

function NP.tap.UpdateFromUnit(unit)
    if not NP.tap.IsEnabled() then
        return nil
    end
    return StoreTapFromUnit(unit)
end

-- Fresh read when a live token is already known; otherwise GUID memory. nil = unknown.
function NP.tap.IsTapDenied(plateData)
    if not plateData or not NP.tap.IsEnabled() then
        return nil
    end

    local unit = GetCachedLiveUnit(plateData)
    if unit then
        return StoreTapFromUnit(unit)
    end

    local guid = plateData.guid
    if not guid then
        return nil
    end
    return NP.state.PlateTapCache[guid]
end

function NP.tap.GetTapDeniedColor()
    return TAP_DENIED_R, TAP_DENIED_G, TAP_DENIED_B
end
