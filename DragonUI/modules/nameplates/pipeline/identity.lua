local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const
local abs = NP.abs

-- Nameplates identity: plate ↔ unit resolution and GUID binding.
-- Target = native alpha token; mouseover = highlight; GUID evicted on conflict/hide.

NP.identity = NP.identity or {}
-- Alias: NP.match
NP.match = NP.identity

local identity = NP.identity

-- Health and name matching

function identity.UnitMatchesPlateHealth(unit, plateData)
    if not unit or not UnitExists(unit) then
        return false
    end
    local hb = plateData.healthBar
    if not hb or not hb.GetValue or not hb.GetMinMaxValues then
        return false
    end
    local cur = hb:GetValue()
    local _, maxVal = hb:GetMinMaxValues()
    if not maxVal or maxVal <= 0 then
        return false
    end
    local uh, um = UnitHealth(unit), UnitHealthMax(unit)
    if not um or um <= 0 then
        return false
    end
    if abs(maxVal - um) <= NP.max(1, um * 0.01) then
        local tolerance = NP.max(1, um * C.HEALTH_MATCH_TOLERANCE)
        return abs(cur - uh) <= tolerance
    end
    local plateFrac = cur / maxVal
    return abs((uh / um) - plateFrac) <= C.HEALTH_MATCH_TOLERANCE
end

function identity.UnitNameMatchesPlate(unit, plateData)
    local name = plateData.plateName
    if not name or not unit or not UnitExists(unit) then
        return false
    end
    return NP.native_style.UnitNameEquals(UnitName(unit), name)
end

function identity.PlateMatchesUnitFingerprint(plateData, unit, allowFullHealthNPC)
    if not plateData or not unit or not UnitExists(unit) then
        return false
    end
    if not identity.UnitNameMatchesPlate(unit, plateData) then
        return false
    end
    local levelText = plateData.levelText
    if levelText and levelText.GetText then
        local plateLevelText = levelText:GetText()
        local plateLevelNum = plateLevelText and tonumber(plateLevelText)
        if plateLevelNum then
            local unitLevel = UnitLevel(unit)
            if unitLevel and unitLevel > 0 and plateLevelNum ~= unitLevel then
                return false
            end
        end
    end
    if not identity.UnitMatchesPlateHealth(unit, plateData) then
        return false
    end
    if not allowFullHealthNPC and not UnitIsPlayer(unit) then
        local hp, maxHp = UnitHealth(unit), UnitHealthMax(unit)
        if hp and maxHp and maxHp > 0 and hp >= maxHp then
            return false
        end
    end
    return true
end

-- Token gates (alpha / highlight) — authoritative identity on 3.3.5a.

function identity.PlateHasTargetAlpha(plateData)
    local plate = plateData and plateData.plate
    local nativeAlpha = plateData and (plateData._tokenNativeAlpha or plateData._nativeAlpha)
    if nativeAlpha ~= nil then
        return nativeAlpha > 0.95
    end
    return plate and plate.GetAlpha and plate:GetAlpha() and plate:GetAlpha() > 0.95 or false
end

-- Per-frame visual target from harvested alpha (opacity/highlight; not cast/GUID).
-- hasTarget: optional precomputed UnitExists("target") result, so per-frame
-- callers iterating every plate don't re-query the target each plate.
-- Alpha can go stale for a tick; veto with the GUID already refreshed this frame.
function identity.IsTargetPlateVisual(plateData, hasTarget)
    if hasTarget == nil then
        hasTarget = UnitExists("target") == 1
    end
    if not hasTarget then
        return false
    end
    if not identity.PlateHasTargetAlpha(plateData) then
        return false
    end
    local plateGuid = NP.state.GetPlateGUID(plateData)
    local targetGuid = NP.module.targetGUID
    return not (plateGuid and targetGuid and plateGuid ~= targetGuid)
end

local function PlateIsMouseoverToken(plateData)
    local highlight = plateData and plateData.highlight
    if highlight and highlight.IsShown and highlight:IsShown() then
        return true
    end
    local plate = plateData and plateData.plate
    return plate and plate.IsMouseOver and plate:IsMouseOver() or false
end

-- Alpha alone goes stale on self-target (no plate); also require a fingerprint match.
function identity.PlatePassesUnitTokenGate(plateData, unit)
    if unit == "target" then
        return identity.PlateHasTargetAlpha(plateData)
            and identity.PlateMatchesUnitFingerprint(plateData, unit, true)
    elseif unit == "mouseover" then
        return PlateIsMouseoverToken(plateData)
    end
    return false
end

-- Single plate for unit token; nil if ambiguous.
function identity.FindUniquePlateForUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local matchedPlate
    local matchCount = 0
    for _, candidate in pairs(NP.module.plates) do
        if candidate
            and candidate.plateName
            and identity.PlatePassesUnitTokenGate(candidate, unit) then
            matchCount = matchCount + 1
            matchedPlate = candidate
            if matchCount > 1 then
                return nil
            end
        end
    end
    return matchedPlate
end

function identity.PlateHasUniqueUnitMatch(plateData, unit)
    if not plateData then
        return false
    end
    return identity.FindUniquePlateForUnit(unit) == plateData
end

-- Target / mouseover / focus context

-- Target disambiguation when alpha is ambiguous (pre-dim): name+health at target alpha.
-- Alpha gate prevents GUID leak to same-name plates when the real target is off-screen.
local function FindTargetByAlphaFingerprint()
    local found, count = nil, 0
    for _, pd in pairs(NP.module.plates) do
        local plate = pd and pd.plate
        if plate and plate.IsShown and plate:IsShown()
            and identity.PlateHasTargetAlpha(pd)
            and identity.PlateMatchesUnitFingerprint(pd, "target", true) then
            count = count + 1
            found = pd
            if count > 1 then
                return nil
            end
        end
    end
    return found
end

function identity.UpdateTargetContext()
    NP.module.targetGUID = UnitGUID("target")

    if not UnitExists("target") then
        NP.module.targetPlate = nil
        return nil
    end

    local targetGUID = NP.module.targetGUID

    -- Fast path: cached target plate still shown, GUID-bound, name still matches.
    local cachedTarget = NP.module.targetPlate
    if cachedTarget and targetGUID
        and NP.state.GetPlateGUID(cachedTarget) == targetGUID
        and cachedTarget.plate and cachedTarget.plate.IsShown and cachedTarget.plate:IsShown()
        and identity.UnitNameMatchesPlate("target", cachedTarget) then
        return cachedTarget
    end

    local unique = identity.FindUniquePlateForUnit("target")

    -- Alpha can fail transiently; fall back to prior GUID binding when shown.
    if not unique and targetGUID then
        local known = NP.state.GUIDToPlate[targetGUID]
        if known and known.plate and known.plate.IsShown and known.plate:IsShown() then
            unique = known
        end
    end

    -- Last resort: resolve the ambiguous-alpha case (see FindTargetByAlphaFingerprint).
    if not unique then
        unique = FindTargetByAlphaFingerprint()
    end

    if unique then
        NP.module.targetPlate = unique
        -- Bind GUID; SetPlateGUID evicts stale owners on recycled plates.
        if targetGUID and NP.state.GetPlateGUID(unique) ~= targetGUID then
            NP.state.SetPlateGUID(unique, targetGUID, {
                source = "TOKEN_TARGET",
                confidence = C.GUID_CONFIDENCE.TOKEN_TARGET,
            })
        end
        return unique
    end

    NP.module.targetPlate = nil
    return nil
end

function identity.UpdateMouseoverContext()
    NP.module.mouseoverGUID = UnitGUID("mouseover")

    if not UnitExists("mouseover") then
        NP.module.mouseoverPlate = nil
        return nil
    end

    local mouseoverGUID = NP.module.mouseoverGUID

    -- Fast path: cached mouseover plate shown, GUID-bound, name still matches.
    local cachedMouseover = NP.module.mouseoverPlate
    if cachedMouseover and mouseoverGUID
        and NP.state.GetPlateGUID(cachedMouseover) == mouseoverGUID
        and cachedMouseover.plate and cachedMouseover.plate.IsShown and cachedMouseover.plate:IsShown()
        and identity.UnitNameMatchesPlate("mouseover", cachedMouseover) then
        return cachedMouseover
    end

    local unique = identity.FindUniquePlateForUnit("mouseover")
    if not unique then
        -- Fall back to highlight only when unambiguous.
        local count = 0
        for _, candidate in pairs(NP.module.plates) do
            if PlateIsMouseoverToken(candidate) then
                count = count + 1
                unique = candidate
                if count > 1 then
                    unique = nil
                    break
                end
            end
        end
    end

    if unique then
        NP.module.mouseoverPlate = unique
        local guidToBind = mouseoverGUID
        if guidToBind and not identity.UnitNameMatchesPlate("mouseover", unique) then
            guidToBind = nil
        end
        if not guidToBind then
            local token = identity.UpdatePlateUnitToken(unique)
            if token and UnitExists(token) and identity.UnitNameMatchesPlate(token, unique) then
                guidToBind = UnitGUID(token)
            end
        end
        if guidToBind and NP.state.GetPlateGUID(unique) ~= guidToBind then
            NP.state.SetPlateGUID(unique, guidToBind, {
                source = "TOKEN_MOUSEOVER",
                confidence = C.GUID_CONFIDENCE.TOKEN_MOUSEOVER,
            })
        end
        return unique
    end

    NP.module.mouseoverPlate = nil
    return nil
end

function identity.UpdateFocusContext()
    NP.module.focusGUID = UnitGUID("focus")

    if not UnitExists("focus") then
        NP.module.focusPlate = nil
        return nil
    end

    local focusGUID = NP.module.focusGUID

    -- Focus has no native token; reuse GUID binding after hide/show if name still matches.
    if focusGUID then
        local bound = NP.state.GUIDToPlate[focusGUID]
        if bound and bound.plate and bound.plate.IsShown and bound.plate:IsShown()
            and identity.UnitNameMatchesPlate("focus", bound) then
            NP.module.focusPlate = bound
            return bound
        end
    end

    local matched = identity.FindPlateForUnit("focus", true)
    if matched then
        NP.module.focusPlate = matched
        if focusGUID and NP.state.GetPlateGUID(matched) ~= focusGUID then
            NP.state.SetPlateGUID(matched, focusGUID, {
                source = "TOKEN_FOCUS",
                confidence = C.GUID_CONFIDENCE.TOKEN_FOCUS,
            })
        end
        return matched
    end

    NP.module.focusPlate = nil
    return nil
end

function identity.GetTargetPlate()
    return NP.module.targetPlate
end

function identity.GetMouseoverPlate()
    return NP.module.mouseoverPlate
end

function identity.GetFocusPlate()
    return NP.module.focusPlate
end

function identity.GetTargetGUID()
    return NP.module.targetGUID
end

function identity.GetMouseoverGUID()
    return NP.module.mouseoverGUID
end

function identity.IsTargetPlate(plateData)
    return NP.module.targetPlate == plateData
end

function identity.IsMouseoverPlate(plateData)
    return NP.module.mouseoverPlate == plateData
end

function identity.IsFocusPlate(plateData)
    return NP.module.focusPlate == plateData
end

-- Alias for threat/elite/layout.
identity.IsPlateTargeted = identity.IsTargetPlate

function identity.InvalidatePlate(plateData)
    if NP.module.targetPlate == plateData then
        NP.module.targetPlate = nil
    end
    if NP.module.mouseoverPlate == plateData then
        NP.module.mouseoverPlate = nil
    end
    if NP.module.focusPlate == plateData then
        NP.module.focusPlate = nil
    end
    -- Keep combo target across hide/show while target unit unchanged.
    if NP.module.comboTargetPlate == plateData and not UnitExists("target") then
        NP.module.comboTargetPlate = nil
    end
end

-- Plate → unit resolver

local function PlateMatchesUnit(plateData, unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    local unitGuid = UnitGUID(unit)
    local plateGuid = NP.state.GetPlateGUID(plateData)
    if plateGuid and unitGuid then
        return plateGuid == unitGuid
    end
    if unit == "target" then
        return identity.IsTargetPlate(plateData)
    elseif unit == "focus" then
        return identity.IsFocusPlate(plateData)
    elseif unit == "mouseover" then
        return identity.IsMouseoverPlate(plateData)
    end
    return false
end

function identity.GetUnitForPlate(plateData, hintedUnit)
    if not plateData or not plateData.plateName then
        return nil
    end
    if hintedUnit == "target" or hintedUnit == "focus" or hintedUnit == "mouseover" then
        return PlateMatchesUnit(plateData, hintedUnit) and hintedUnit or nil
    end
    if PlateMatchesUnit(plateData, "target") then
        return "target"
    end
    if PlateMatchesUnit(plateData, "focus") then
        return "focus"
    end
    if PlateMatchesUnit(plateData, "mouseover") then
        return "mouseover"
    end
    return nil
end

function identity.ResolvePlateUnit(plateData)
    return identity.GetUnitForPlate(plateData, nil)
end

-- Extended unit tokens (nameplate1..40, arena/party)

-- Precomputed nameplateN tokens (avoid per-probe string concat).
local NAMEPLATE_TOKEN_NAMES = {}
for i = 1, 40 do
    NAMEPLATE_TOKEN_NAMES[i] = "nameplate" .. i
end

local MIRROR_IMAGE_MAX_HEALTH_THRESHOLD = 10000

function identity.GetPlateMaxHealth(plateData)
    local hb = plateData and plateData.healthBar
    if hb and hb.GetMinMaxValues then
        local _, maxHealth = hb:GetMinMaxValues()
        maxHealth = tonumber(maxHealth)
        if maxHealth and maxHealth > 0 then
            return maxHealth
        end
    end
    return nil
end

function identity.CountVisiblePlatesByName(name)
    if not name or name == "" then
        return 0
    end
    local count = 0
    for _, pd in pairs(NP.module.plates) do
        if pd and pd.plateName == name then
            local plate = pd.plate
            if plate and plate.IsShown and plate:IsShown() then
                count = count + 1
            end
        end
    end
    return count
end

function identity.IsMageMirrorImagePlate(plateData, arenaUnit)
    if not plateData or not arenaUnit or not UnitExists(arenaUnit) then
        return false
    end
    if not string.find(arenaUnit, "^arena%d$") then
        return false
    end
    local _, class = UnitClass(arenaUnit)
    if class ~= "MAGE" then
        return false
    end
    local arenaName = UnitName(arenaUnit)
    local plateName = plateData.plateName
    if not arenaName or not plateName or not NP.native_style.UnitNameEquals(arenaName, plateName) then
        return false
    end
    if identity.CountVisiblePlatesByName(plateName) <= 1 then
        return false
    end
    local maxHealth = identity.GetPlateMaxHealth(plateData)
    if maxHealth and maxHealth > 0 and maxHealth < MIRROR_IMAGE_MAX_HEALTH_THRESHOLD then
        return true
    end
    return false
end

-- Likely mage mirror / clone: shared name, low max HP, another same-name plate is full-size.
function identity.IsLikelyMirrorImagePlate(plateData)
    if not plateData then
        return false
    end
    local name = plateData.plateName
    if not name or name == "" then
        return false
    end
    local myMax = identity.GetPlateMaxHealth(plateData)
    if not myMax or myMax <= 0 or myMax >= MIRROR_IMAGE_MAX_HEALTH_THRESHOLD then
        return false
    end
    local sameName, hasOwner = 0, false
    for _, pd in pairs(NP.module.plates) do
        if pd and pd.plateName == name then
            local plate = pd.plate
            if plate and plate.IsShown and plate:IsShown() then
                sameName = sameName + 1
                local m = identity.GetPlateMaxHealth(pd)
                if m and m >= MIRROR_IMAGE_MAX_HEALTH_THRESHOLD then
                    hasOwner = true
                end
            end
        end
    end
    return sameName > 1 and hasOwner
end

function identity.ResolveArenaTokenByName(plateName)
    if not plateName or plateName == "" then
        return nil
    end

    local now = GetTime and GetTime() or 0
    if not NP.module._arenaMapLastUpdate or (now - NP.module._arenaMapLastUpdate) > 0.5 then
        if NP.engine and NP.engine.UpdatePartyArenaTokenMaps then
            NP.engine.UpdatePartyArenaTokenMaps()
        end
    end

    local arenaMap = NP.module.arenaTokenByName
    if not arenaMap then
        return nil
    end

    local direct = arenaMap[plateName]
    if direct and UnitExists(direct) then
        return direct
    end

    for arenaName, token in pairs(arenaMap) do
        if plateName == arenaName and UnitExists(token) then
            return token
        end
        if string.find(plateName, arenaName, 1, true) == 1 then
            local nextChar = string.sub(plateName, string.len(arenaName) + 1, string.len(arenaName) + 1)
            if nextChar == "" or nextChar == "-" or nextChar == " " then
                if UnitExists(token) then
                    return token
                end
            end
        end
    end

    return nil
end

local function BindArenaTokenIdentity(plateData, unit)
    if not plateData or not unit or not UnitExists(unit) then
        return
    end
    local guid = UnitGUID(unit)
    if not guid then
        return
    end
    if NP.state.GetPlateGUID(plateData) ~= guid then
        NP.state.SetPlateGUID(plateData, guid, {
            source = "ARENA_TOKEN",
            confidence = C.GUID_CONFIDENCE.ARENA_TOKEN,
        })
    end
    local bar = plateData.minaCast
    if bar then
        bar._castSourceGUID = guid
    end
end

function identity.IsArenaUnitToken(unit)
    if not unit then
        return false
    end
    return string.find(unit, "^arena%d+$") ~= nil
        or string.find(unit, "^arenapet%d+$") ~= nil
end

function identity.BindArenaPlateUnit(plateData, unit)
    if not plateData or not unit or not UnitExists(unit) then
        return
    end
    if identity.IsMageMirrorImagePlate(plateData, unit) then
        plateData.arenaCastUnit = nil
        return
    end
    plateData.arenaCastUnit = unit
    plateData.unitToken = unit
    BindArenaTokenIdentity(plateData, unit)
end

function identity.FindPlateForArenaUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local guid = UnitGUID(unit)
    if guid and NP.state.GUIDToPlate[guid] then
        return NP.state.GUIDToPlate[guid]
    end

    local matched
    local count = 0
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        if plate and plate.IsShown and plate:IsShown() and plateData.plateName then
            if identity.UnitNameMatchesPlate(unit, plateData) then
                count = count + 1
                matched = plateData
            end
        end
    end
    if count == 1 then
        return matched
    end
    if count > 1 and matched then
        for _, plateData in pairs(NP.module.plates) do
            if identity.UnitNameMatchesPlate(unit, plateData)
                and identity.UnitMatchesPlateHealth(unit, plateData) then
                return plateData
            end
        end
    end
    return nil
end

function identity.UpdateArenaCastBindingForPlate(plateData)
    if not NP.module.inArena or not plateData or not plateData.plateName then
        return
    end
    if plateData.arenaCastUnit and not UnitExists(plateData.arenaCastUnit) then
        plateData.arenaCastUnit = nil
    end
    if plateData.arenaCastUnit and UnitExists(plateData.arenaCastUnit)
        and identity.UnitNameMatchesPlate(plateData.arenaCastUnit, plateData) then
        return
    end
    for i = 1, GetNumArenaOpponents() do
        for _, unit in ipairs({ "arena" .. i, "arenapet" .. i }) do
            if UnitExists(unit) and identity.UnitNameMatchesPlate(unit, plateData) then
                if not identity.IsMageMirrorImagePlate(plateData, unit) then
                    identity.BindArenaPlateUnit(plateData, unit)
                    return
                end
            end
        end
    end
end

function identity.UpdateArenaCastBindings()
    if not NP.module.inArena then
        return
    end
    if NP.engine and NP.engine.UpdatePartyArenaTokenMaps then
        NP.engine.UpdatePartyArenaTokenMaps()
    end
    for i = 1, GetNumArenaOpponents() do
        for _, unit in ipairs({ "arena" .. i, "arenapet" .. i }) do
            if UnitExists(unit) then
                local plateData = identity.FindPlateForArenaUnit(unit)
                if plateData and not identity.IsMageMirrorImagePlate(plateData, unit) then
                    identity.BindArenaPlateUnit(plateData, unit)
                end
            end
        end
    end
end

local function TryResolveArenaPartyToken(plateData)
    if not NP.module.inArena then
        return nil
    end
    local name = plateData.plateName
    if not name or name == "" then
        return nil
    end

    if plateData.classKey == "FRIENDLY_PLAYER" then
        local token = NP.module.partyTokenByName and NP.module.partyTokenByName[name]
        if token and UnitExists(token) then
            plateData.unitToken = token
            plateData.arenaCastUnit = token
            BindArenaTokenIdentity(plateData, token)
            return token
        end
        return nil
    end

    local arenaUnit = identity.ResolveArenaTokenByName(name)
    if not arenaUnit or not UnitExists(arenaUnit) then
        return nil
    end
    if identity.IsMageMirrorImagePlate(plateData, arenaUnit) then
        return nil
    end
    plateData.unitToken = arenaUnit
    plateData.arenaCastUnit = arenaUnit
    BindArenaTokenIdentity(plateData, arenaUnit)
    return arenaUnit
end

function identity.UpdatePlateUnitToken(plateData)
    if not plateData then
        return nil
    end

    local plate = plateData.plate
    local nativeToken = plateData.namePlateUnitToken or (plate and plate.namePlateUnitToken)
    if nativeToken and nativeToken ~= "" and UnitExists(nativeToken) then
        if identity.UnitNameMatchesPlate(nativeToken, plateData)
            and identity.UnitMatchesPlateHealth(nativeToken, plateData) then
            plateData.namePlateUnitToken = nativeToken
            return nativeToken
        end
        plateData.namePlateUnitToken = nil
        if plate then
            plate.namePlateUnitToken = nil
        end
    end

    plateData.namePlateUnitToken = nil
    plateData.unitToken = nil

    -- Arena/party tokens before nameplate1..N (casts need arenaN on some clients).
    local arenaToken = TryResolveArenaPartyToken(plateData)
    if arenaToken then
        return arenaToken
    end

    -- In arena, only arenaN/arenapetN carry cast info for players.
    if NP.module.inArena then
        identity.UpdateArenaCastBindingForPlate(plateData)
        if plateData.arenaCastUnit and UnitExists(plateData.arenaCastUnit) then
            return plateData.arenaCastUnit
        end
        return nil
    end

    -- Open-world fallback: nameplate1..40 probe.
    local now = GetTime and GetTime() or 0
    if not plateData._tokenProbeAt or now >= plateData._tokenProbeAt then
        -- Global per-tick probe budget atop 0.2s cooldown; deferred plates retry without consuming it.
        local tick = NP.module._engineFrame
        if tick then
            if NP.module._tokenProbeTick ~= tick then
                NP.module._tokenProbeTick = tick
                NP.module._tokenProbeBudget = 0
            end
            if NP.module._tokenProbeBudget >= (C.TOKEN_PROBE_PLATES_PER_TICK or 3) then
                return nil
            end
            NP.module._tokenProbeBudget = NP.module._tokenProbeBudget + 1
        end
        plateData._tokenProbeAt = now + 0.2
        local matchedToken = nil
        local matchCount = 0
        for i = 1, 40 do
            local token = NAMEPLATE_TOKEN_NAMES[i]
            if UnitExists(token)
                and identity.UnitNameMatchesPlate(token, plateData)
                and identity.UnitMatchesPlateHealth(token, plateData) then
                matchCount = matchCount + 1
                matchedToken = token
                if matchCount > 1 then
                    matchedToken = nil
                    break
                end
            end
        end
        if matchedToken then
            plateData.namePlateUnitToken = matchedToken
            local tokenGUID = UnitGUID(matchedToken)
            if tokenGUID and NP.state.GetPlateGUID(plateData) ~= tokenGUID then
                NP.state.SetPlateGUID(plateData, tokenGUID, {
                    source = "NAMEPLATE_TOKEN",
                    confidence = C.GUID_CONFIDENCE.NAMEPLATE_TOKEN,
                })
            end
            return matchedToken
        end
    elseif plateData.namePlateUnitToken and UnitExists(plateData.namePlateUnitToken) then
        if identity.UnitNameMatchesPlate(plateData.namePlateUnitToken, plateData)
            and identity.UnitMatchesPlateHealth(plateData.namePlateUnitToken, plateData) then
            return plateData.namePlateUnitToken
        end
        plateData.namePlateUnitToken = nil
    end

    return nil
end

function identity.ResolvePlateCastUnit(plateData)
    if not plateData then
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
    -- Sticky arena cast unit when not target/focus/mouseover.
    if plateData.arenaCastUnit and UnitExists(plateData.arenaCastUnit) then
        return plateData.arenaCastUnit
    end
    local token = identity.UpdatePlateUnitToken(plateData)
    if token then
        return token
    end
    if plateData._matchedCastUnit and UnitExists(plateData._matchedCastUnit)
        and identity.PlateMatchesUnitFingerprint(plateData, plateData._matchedCastUnit) then
        return plateData._matchedCastUnit
    end
    plateData._matchedCastUnit = nil
    if plateData.unitToken and plateData.unitToken ~= "" then
        return plateData.unitToken
    end
    return nil
end

-- GUID tracking

function identity.TryMatchGUID(plateData)
    if plateData.guid then return true end
    if not plateData.plateName then return false end

    if UnitExists("target") and identity.PlateHasUniqueUnitMatch(plateData, "target") then
        local guid = UnitGUID("target")
        if guid then
            -- SetPlateGUID evicts stale owners for unique token match.
            NP.state.SetPlateGUID(plateData, guid, {
                source = "TOKEN_TARGET",
                confidence = C.GUID_CONFIDENCE.TOKEN_TARGET,
            })
            return true
        end
    end

    if UnitExists("mouseover") and identity.PlateHasUniqueUnitMatch(plateData, "mouseover") then
        local guid = UnitGUID("mouseover")
        if guid then
            NP.state.SetPlateGUID(plateData, guid, {
                source = "TOKEN_MOUSEOVER",
                confidence = C.GUID_CONFIDENCE.TOKEN_MOUSEOVER,
            })
            return true
        end
    end

    return false
end

-- Evict only when another plate owns the unit token; model hover must not evict.
function identity.ValidatePlateGUIDOwnership(plateData)
    local guid = NP.state.GetPlateGUID(plateData)
    if not guid then
        return true
    end

    local targetGUID = UnitGUID("target")
    if guid == targetGUID then
        if identity.IsTargetPlate(plateData) then
            return true
        end
        local owner = identity.FindUniquePlateForUnit("target")
        if owner and owner ~= plateData then
            NP.state.ClearPlateGUID(plateData)
            NP.state.HidePlateDebuffs(plateData)
            return false
        end
        return true
    end

    local mouseoverGUID = UnitGUID("mouseover")
    if guid == mouseoverGUID then
        local mouseoverPlate = identity.GetMouseoverPlate()
            or identity.FindUniquePlateForUnit("mouseover")
        if not mouseoverPlate or mouseoverPlate == plateData then
            return true
        end
        NP.state.ClearPlateGUID(plateData)
        NP.state.HidePlateDebuffs(plateData)
        return false
    end

    return true
end

-- Group cache: GUID → party/raid unit (party castbar / aura lookup).
identity.GroupGUIDToUnit = identity.GroupGUIDToUnit or {}

function identity.UpdateGroupCache()
    local map = identity.GroupGUIDToUnit
    for k in pairs(map) do
        map[k] = nil
    end
    local numRaid = GetNumRaidMembers() or 0
    if numRaid > 0 then
        for i = 1, numRaid do
            local unit = "raid" .. i
            local guid = UnitExists(unit) and UnitGUID(unit)
            if guid then
                map[guid] = unit
            end
        end
    else
        for i = 1, GetNumPartyMembers() or 0 do
            local unit = "party" .. i
            local guid = UnitExists(unit) and UnitGUID(unit)
            if guid then
                map[guid] = unit
            end
        end
    end
end

function identity.GetGroupUnitByGUID(guid)
    if not guid then return nil end
    local unit = identity.GroupGUIDToUnit[guid]
    if unit and UnitExists(unit) and UnitGUID(unit) == guid then
        return unit
    end
    return nil
end

-- Friendly plates: only group member GUIDs (not boss/hostile).
function identity.FriendlyPlateMayUseGUID(plateData, guid)
    if not plateData or not guid then
        return false
    end
    if NP.native_style.GetPlateReaction(plateData) ~= "FRIENDLY" then
        return true
    end
    return identity.GetGroupUnitByGUID(guid) ~= nil
end

-- Group member plate: GUID map first, then unique name (ambiguous → nil).
function identity.FindPlateForGroupGUID(guid, fallbackName)
    if not guid then return nil end
    local byGuid = NP.state.GUIDToPlate[guid]
    if byGuid then
        return byGuid
    end
    if not fallbackName then return nil end
    local found
    local count = 0
    for _, plateData in pairs(NP.module.plates) do
        if plateData.plateName == fallbackName
            and plateData.plate and plateData.plate.IsShown and plateData.plate:IsShown() then
            count = count + 1
            found = plateData
            if count > 1 then
                return nil
            end
        end
    end
    return found
end

local GROUP_TARGET_TOKENS_PARTY = {}
for i = 1, 4 do
    GROUP_TARGET_TOKENS_PARTY[i] = "party" .. i .. "target"
end
local GROUP_TARGET_TOKENS_RAID = {}
for i = 1, 40 do
    GROUP_TARGET_TOKENS_RAID[i] = "raid" .. i .. "target"
end

local function ForEachGroupTargetUnit(callback)
    for i = 1, GetNumPartyMembers() do
        local unit = GROUP_TARGET_TOKENS_PARTY[i] or ("party" .. i .. "target")
        if UnitExists(unit) then
            callback(unit)
        end
    end
    for i = 1, GetNumRaidMembers() do
        local unit = GROUP_TARGET_TOKENS_RAID[i] or ("raid" .. i .. "target")
        if UnitExists(unit) then
            callback(unit)
        end
    end
end

-- Inlined group-target scan with early exit (matches ForEachGroupTargetUnit order).
local function FindGroupTargetUnitForPlate(plateData)
    for i = 1, GetNumPartyMembers() do
        local unit = GROUP_TARGET_TOKENS_PARTY[i] or ("party" .. i .. "target")
        if UnitExists(unit) and identity.FindPlateForUnit(unit) == plateData then
            return unit
        end
    end
    for i = 1, GetNumRaidMembers() do
        local unit = GROUP_TARGET_TOKENS_RAID[i] or ("raid" .. i .. "target")
        if UnitExists(unit) and identity.FindPlateForUnit(unit) == plateData then
            return unit
        end
    end
    return nil
end

function identity.FindPlateForUnit(unit, allowFullHealthNPC)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local found
    local count = 0
    for _, plateData in pairs(NP.module.plates) do
        if plateData and plateData.plate and plateData.plate.IsShown and plateData.plate:IsShown()
            and identity.PlateMatchesUnitFingerprint(plateData, unit, allowFullHealthNPC) then
            count = count + 1
            found = plateData
            if count > 1 then
                return nil
            end
        end
    end
    return found
end

function identity.UpdatePlateGroupTargetMatch(plateData, force)
    if not plateData then
        return nil
    end
    if not plateData.plate or not plateData.plate.IsShown or not plateData.plate:IsShown() then
        plateData._matchedCastUnit = nil
        return nil
    end
    if not force then
        local now = GetTime and GetTime() or 0
        local nextProbe = plateData._nextGroupTargetProbeAt or 0
        if now < nextProbe then
            return plateData._matchedCastUnit
        end
        plateData._nextGroupTargetProbeAt = now + 0.2
    end
    local match = FindGroupTargetUnitForPlate(plateData)
    plateData._matchedCastUnit = match
    if match and not NP.state.GetPlateGUID(plateData) then
        local guid = UnitGUID(match)
        if guid then
            NP.state.SetPlateGUID(plateData, guid, {
                source = "GROUP_TARGET",
                confidence = C.GUID_CONFIDENCE.GROUP_TARGET,
            })
        end
    end
    return match
end

function identity.RefreshGroupTargetMatches()
    for _, plateData in pairs(NP.module.plates) do
        if plateData then
            plateData._matchedCastUnit = nil
        end
    end
    local tapEnabled = NP.tap and NP.tap.IsEnabled()
    ForEachGroupTargetUnit(function(unit)
        if tapEnabled then
            NP.tap.UpdateFromUnit(unit)
        end
        local owner = identity.FindPlateForUnit(unit)
        if owner then
            owner._matchedCastUnit = unit
            if not NP.state.GetPlateGUID(owner) then
                local guid = UnitGUID(unit)
                if guid then
                    NP.state.SetPlateGUID(owner, guid, {
                        source = "GROUP_TARGET",
                        confidence = C.GUID_CONFIDENCE.GROUP_TARGET,
                    })
                end
            end
            if tapEnabled and NP.engine and NP.engine.QueuePlate then
                NP.engine.QueuePlate(owner, NP.engine.Callbacks.OnUpdateHealth)
            end
        end
    end)
end

-- Per-frame context transitions (engine).
function identity.ProcessContextTransitions()
    local oldTarget = NP.module.targetPlate
    local oldMouseover = NP.module.mouseoverPlate
    local oldFocus = NP.module.focusPlate

    identity.UpdateTargetContext()
    identity.UpdateMouseoverContext()
    identity.UpdateFocusContext()

    local newTarget = NP.module.targetPlate
    local newMouseover = NP.module.mouseoverPlate
    local newFocus = NP.module.focusPlate

    if newTarget ~= oldTarget then
        if NP.tap and NP.tap.IsEnabled() then
            NP.tap.UpdateFromUnit("target")
        end
        if oldTarget then
            NP.gather.RefreshPlateTargetState(oldTarget, "scan_target_changed")
        end
        if newTarget then
            NP.gather.RefreshPlateTargetState(newTarget, "scan_target_changed")
        end
        if NP.widgets and NP.widgets.RefreshAllComboPoints then
            NP.widgets.RefreshAllComboPoints()
        end
    end

    if newMouseover ~= oldMouseover then
        if NP.tap and NP.tap.IsEnabled() then
            NP.tap.UpdateFromUnit("mouseover")
        end
        if oldMouseover then
            identity.ValidatePlateGUIDOwnership(oldMouseover)
            NP.gather.RefreshPlateMouseoverState(oldMouseover, "scan_mouseover_changed")
            NP.engine.QueuePlate(oldMouseover, NP.engine.Callbacks.OnUpdateCastbar)
        end
        if newMouseover then
            identity.ValidatePlateGUIDOwnership(newMouseover)
            NP.gather.RefreshPlateMouseoverState(newMouseover, "scan_mouseover_changed")
            NP.engine.QueuePlate(newMouseover, NP.engine.Callbacks.OnUpdateCastbar)
        end
    end

    if newFocus ~= oldFocus then
        local tapEnabled = NP.tap and NP.tap.IsEnabled()
        if tapEnabled then
            NP.tap.UpdateFromUnit("focus")
        end
        if oldFocus then
            identity.ValidatePlateGUIDOwnership(oldFocus)
            NP.engine.QueuePlate(oldFocus, NP.engine.Callbacks.OnUpdateCastbar)
            if tapEnabled then
                NP.engine.QueuePlate(oldFocus, NP.engine.Callbacks.OnUpdateHealth)
            end
        end
        if newFocus then
            identity.ValidatePlateGUIDOwnership(newFocus)
            NP.engine.QueuePlate(newFocus, NP.engine.Callbacks.OnUpdateCastbar)
            if tapEnabled then
                NP.engine.QueuePlate(newFocus, NP.engine.Callbacks.OnUpdateHealth)
            end
        end
    end

    -- Target plate direct hover (level-on-hover).
    if newTarget and newTarget.plate and newTarget.plate.IsMouseOver then
        local directHover = newTarget.plate:IsMouseOver() and true or false
        if newTarget._lastDirectHover ~= directHover then
            newTarget._lastDirectHover = directHover
            NP.gather.RefreshPlateName(newTarget, "scan_target_direct_hover_changed")
        end
    end
end
