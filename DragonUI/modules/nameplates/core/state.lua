local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates state: GUID tracking and helpers.

NP.state = NP.state or {}

NP.state.GUIDToPlate = setmetatable({}, { __mode = "k" })
NP.state.PlateAuraCache = {}
-- Swapped for the saved table on init; the combat log needs a learned duration to render.
NP.state.AuraDurationCache = {}

function NP.state.BindPersistentAuraDurations()
    local db = addon.db
    if not (db and db.global) then return end
    db.global.auraDurations = db.global.auraDurations or {}
    local persisted = db.global.auraDurations
    for spellId, duration in pairs(NP.state.AuraDurationCache) do
        if not persisted[spellId] then
            persisted[spellId] = duration
        end
    end
    NP.state.AuraDurationCache = persisted
end
-- guid -> true|false (tap denied by another player/group); written only on live unit reads.
NP.state.PlateTapCache = {}

-- Fallback GUID lookup when no bound GUID (by name and raid icon).
NP.state.AuraGUIDByName = {}
NP.state.AuraGUIDByRaidIcon = {}

function NP.state.GetPlateGUID(plateData)
    return plateData and plateData.guid
end

function NP.state.GetPlateGUIDConfidence(plateData)
    return (plateData and plateData._guidConfidence) or 0
end

function NP.state.IsGUIDLocked(plateData, now)
    if not plateData or not plateData._guidLockUntil then
        return false
    end
    now = now or (GetTime and GetTime() or 0)
    return now < plateData._guidLockUntil
end

local function ResolveGUIDMeta(meta)
    local confMap = (NP.const and NP.const.GUID_CONFIDENCE) or {}
    local source = (meta and meta.source) or "LEGACY"
    local confidence = tonumber(meta and meta.confidence)
        or tonumber(confMap[source])
        or tonumber(confMap.LEGACY)
        or 0
    return source, confidence
end

local STRONG_GUID_SOURCES = {
    TOKEN_TARGET = true,
    TOKEN_MOUSEOVER = true,
    TOKEN_FOCUS = true,
    NAMEPLATE_TOKEN = true,
    ARENA_TOKEN = true,
    GROUP_TARGET = true,
    RAID_ICON = true,
}

local function NotifyCastbarPlateGUIDBound(plateData, guid, source, confidence)
    if not NP.castbar or not NP.castbar.OnPlateGUIDBound then
        return
    end
    local groupConf = (NP.const and NP.const.GUID_CONFIDENCE and NP.const.GUID_CONFIDENCE.GROUP_TARGET) or 70
    if STRONG_GUID_SOURCES[source] or confidence >= groupConf then
        NP.castbar.OnPlateGUIDBound(plateData, guid)
    end
end

function NP.state.CanBindGUID(plateData, guid, meta)
    if not plateData or not guid then
        return false
    end
    if plateData.guid == guid then
        return true
    end

    local now = GetTime and GetTime() or 0
    local force = meta and meta.force and true or false
    local _, incomingConfidence = ResolveGUIDMeta(meta)
    local currentConfidence = NP.state.GetPlateGUIDConfidence(plateData)

    if not force and NP.state.IsGUIDLocked(plateData, now)
        and incomingConfidence < currentConfidence then
        return false
    end

    if not force and plateData.guid and incomingConfidence < currentConfidence then
        return false
    end

    local previousOwner = NP.state.GUIDToPlate[guid]
    if previousOwner and previousOwner ~= plateData and not force then
        local previousConfidence = NP.state.GetPlateGUIDConfidence(previousOwner)
        if NP.state.IsGUIDLocked(previousOwner, now) and incomingConfidence <= previousConfidence then
            return false
        end
        if incomingConfidence < previousConfidence then
            return false
        end
    end

    return true
end

function NP.state.SetPlateGUID(plateData, guid, meta)
    if not plateData then return false end
    if not guid then
        if plateData.guid and NP.state.GUIDToPlate[plateData.guid] == plateData then
            NP.state.GUIDToPlate[plateData.guid] = nil
        end
        plateData.guid = nil
        plateData._guidSource = nil
        plateData._guidConfidence = nil
        plateData._guidBoundAt = nil
        plateData._guidLockUntil = nil
        return true
    end
    if not NP.state.CanBindGUID(plateData, guid, meta) then
        return false
    end

    local source, confidence = ResolveGUIDMeta(meta)
    local now = GetTime and GetTime() or 0
    local lockThreshold = (NP.const and NP.const.GUID_LOCK_THRESHOLD) or 0
    local lockTTL = (NP.const and NP.const.GUID_LOCK_TTL and NP.const.GUID_LOCK_TTL[source]) or 0

    if plateData.guid == guid then
        if confidence >= NP.state.GetPlateGUIDConfidence(plateData) then
            plateData._guidSource = source
            plateData._guidConfidence = confidence
            plateData._guidBoundAt = now
            if confidence >= lockThreshold and lockTTL > 0 then
                plateData._guidLockUntil = now + lockTTL
            end
        end
        NP.state.GUIDToPlate[guid] = plateData
        NotifyCastbarPlateGUIDBound(plateData, guid, source, confidence)
        return true
    end

    if plateData.guid and NP.state.GUIDToPlate[plateData.guid] == plateData then
        NP.state.GUIDToPlate[plateData.guid] = nil
    end
    -- Evict stale owner: one GUID must not map to two plates.
    local previousOwner = NP.state.GUIDToPlate[guid]
    if previousOwner and previousOwner ~= plateData then
        previousOwner.guid = nil
        previousOwner._guidSource = nil
        previousOwner._guidConfidence = nil
        previousOwner._guidBoundAt = nil
        previousOwner._guidLockUntil = nil
        if NP.lifecycle and NP.lifecycle.InvalidatePlateVisuals then
            NP.lifecycle.InvalidatePlateVisuals(previousOwner, false)
        else
            NP.state.HidePlateDebuffs(previousOwner)
        end
        if NP.identity and NP.identity.InvalidatePlate then
            NP.identity.InvalidatePlate(previousOwner)
        end
        if NP.castbar and NP.castbar.OnPlateHidden then
            NP.castbar.OnPlateHidden(previousOwner)
        end
    end

    plateData.guid = guid
    plateData._guidSource = source
    plateData._guidConfidence = confidence
    plateData._guidBoundAt = now
    if confidence >= lockThreshold and lockTTL > 0 then
        plateData._guidLockUntil = now + lockTTL
    else
        plateData._guidLockUntil = nil
    end
    NP.state.GUIDToPlate[guid] = plateData
    NotifyCastbarPlateGUIDBound(plateData, guid, source, confidence)
    return true
end

function NP.state.ClearPlateGUID(plateData)
    NP.state.SetPlateGUID(plateData, nil)
end

function NP.state.HidePlateDebuffs(plateData)
    local host = plateData and plateData.minaDebuffHost
    if not host then
        return
    end
    host:SetScript("OnUpdate", nil)
    host._renderGUID = nil
    host:Hide()
    for _, icon in ipairs(host.icons or {}) do
        icon.expiration = nil
        icon:Hide()
    end
end
