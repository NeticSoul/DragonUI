local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const
local max = NP.max

-- Nameplates auras: UNIT_AURA + UnitDebuff when unitid exists; CLEU cache otherwise.
-- Per-icon expiration polling; no bulk hide by ownership heuristics.

NP.auras = NP.auras or {}

local DebuffRuntime = {}
NP.auras.DebuffRuntime = DebuffRuntime
local DEBUFF_UPDATE_INTERVAL = 0.15
local SWIPE_UPDATE_INTERVAL = 0.03

local RAID_ICON_NAME_BY_INDEX = {
    "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL",
}

-- Standard 3.3.5a UnitDebuff returns spellId as value 11. Some compatible
-- clients do not, so retain a lazy reverse index without blocking one frame.
local SPELL_INDEX_MAX_ID = 70000
local SPELL_INDEX_BUDGET_MS = 0.5
local SPELL_INDEX_FALLBACK_BATCH = 250
local spellNameToIdCache = {}
local spellIndexCursor = 1
local spellIndexComplete = false
local spellIndexBuilder = nil

local function FinishSpellNameIndex()
    spellIndexComplete = true
    if spellIndexBuilder then
        spellIndexBuilder:SetScript("OnUpdate", nil)
        spellIndexBuilder:Hide()
    end
    -- A compatibility client may have omitted auras while their names were not
    -- indexed yet. Re-read visible plates once the fallback index is complete.
    if NP.engine and NP.engine.QueueMass and NP.engine.Callbacks then
        NP.engine.QueueMass(NP.engine.Callbacks.OnUpdateAuras)
    end
end

local function BuildSpellNameIndexSlice()
    if spellIndexComplete then return end
    local startedAt = debugprofilestop and debugprofilestop()
    local processed = 0

    while spellIndexCursor <= SPELL_INDEX_MAX_ID do
        local spellID = spellIndexCursor
        spellIndexCursor = spellIndexCursor + 1
        processed = processed + 1

        local spellName = GetSpellInfo(spellID)
        if spellName then
            local key = string.lower(spellName)
            if not spellNameToIdCache[key] then
                spellNameToIdCache[key] = spellID
            end
        end

        if startedAt then
            if debugprofilestop() - startedAt >= SPELL_INDEX_BUDGET_MS then
                return
            end
        elseif processed >= SPELL_INDEX_FALLBACK_BATCH then
            return
        end
    end

    FinishSpellNameIndex()
end

local function StartSpellNameIndex()
    if spellIndexComplete or spellIndexBuilder then return end
    spellIndexBuilder = CreateFrame("Frame")
    spellIndexBuilder:SetScript("OnUpdate", BuildSpellNameIndexSlice)
    spellIndexBuilder:Show()
end

-- Return the live index immediately; it is populated incrementally afterwards.
function DebuffRuntime.GetSpellNameIndex()
    StartSpellNameIndex()
    return spellNameToIdCache
end

function DebuffRuntime.ResolveSpellIdByName(name)
    if not name or name == "" then
        return nil
    end
    local spellId = spellNameToIdCache[string.lower(name)]
    if not spellId then
        StartSpellNameIndex()
    end
    return spellId
end

-- Shared with options panel.
NP.auras.GetSpellNameIndex = DebuffRuntime.GetSpellNameIndex

local function NormalizeAuraName(name)
    if not name or name == "" then
        return nil
    end
    return string.lower(name)
end

local function IsAuraExpirationActive(expirationTime)
    if not expirationTime then
        return false
    end
    if expirationTime == 0 then
        return true
    end
    return expirationTime > GetTime()
end

-- Aura cache (GUID → spellId:casterGUID)

function DebuffRuntime.MakeAuraCacheKey(spellId, casterGUID)
    spellId = tonumber(spellId)
    if not spellId then
        return nil
    end
    return tostring(spellId) .. ":" .. tostring(casterGUID or "UNKNOWN_CASTER")
end

function DebuffRuntime.InitAuraCache(guid)
    if not NP.state.PlateAuraCache[guid] then
        NP.state.PlateAuraCache[guid] = {}
    end
end

function DebuffRuntime.WipeAuraCache(guid)
    if guid then
        NP.state.PlateAuraCache[guid] = nil
    end
end

function DebuffRuntime.AddCachedAura(guid, spellId, expiration, count, casterGUID, texture, debuffType, spellName, duration, isBuff)
    if not guid then return end
    spellId = tonumber(spellId)
    if not spellId then return end
    DebuffRuntime.InitAuraCache(guid)
    local auraKey = DebuffRuntime.MakeAuraCacheKey(spellId, casterGUID)
    if not auraKey then return end
    NP.state.PlateAuraCache[guid][auraKey] = {
        spellId = spellId,
        name = spellName or GetSpellInfo(spellId),
        expiration = expiration,
        count = count or 1,
        casterGUID = casterGUID,
        texture = texture,
        debuffType = debuffType,
        duration = duration,
        isBuff = isBuff,
    }
end

function DebuffRuntime.RemoveCachedAura(guid, spellId, casterGUID)
    if not guid or not NP.state.PlateAuraCache[guid] then return end
    local auraKey = DebuffRuntime.MakeAuraCacheKey(spellId, casterGUID)
    if auraKey then
        NP.state.PlateAuraCache[guid][auraKey] = nil
    end
end

-- Learned duration (EMA); DR-shortened and PvP-capped readings must never become a baseline.

local AURA_DURATION_EMA_ALPHA = 0.35
-- A DR-halved observation lands on exactly 0.5x, so anything shorter than this is not a baseline.
local MIN_LEARNABLE_RATIO = 0.6

local AuraDurations = addon.AuraDurations

local function ApplyLearnedDuration(store, spellId, observedDuration)
    local existing = store[spellId]
    if not existing then
        store[spellId] = observedDuration
    elseif observedDuration >= existing * 0.95 then
        store[spellId] = existing + AURA_DURATION_EMA_ALPHA * (observedDuration - existing)
    end
end

local function IsDiminishedNow(spellId, destGUID)
    local category = destGUID and DebuffRuntime.GetDRCategory(spellId)
    return category ~= nil and DebuffRuntime.GetDRFactor(destGUID, category, GetTime()) < 1
end

function DebuffRuntime.LearnAuraDuration(spellId, observedDuration, casterGUID, destGUID, destIsPlayer)
    if not spellId or not observedDuration or observedDuration <= 0 then
        return
    end
    if IsDiminishedNow(spellId, destGUID) then
        return
    end
    if casterGUID then
        local perCaster = NP.state.AuraDurationByCaster[casterGUID]
        if not perCaster then
            perCaster = {}
            NP.state.AuraDurationByCaster[casterGUID] = perCaster
        end
        ApplyLearnedDuration(perCaster, spellId, observedDuration)
    end
    -- PvP caps make durations on players legitimately short; they must not reach the saved table.
    if destIsPlayer then
        return
    end
    local static = AuraDurations and AuraDurations.Duration[spellId]
    if static and observedDuration < static * MIN_LEARNABLE_RATIO then
        return
    end
    ApplyLearnedDuration(NP.state.AuraDurationCache, spellId, observedDuration)
end

-- The caster's own observation wins: the global average blurs when several casters are specced differently.
local function GetBaseAuraDuration(spellId, casterGUID)
    if not spellId then return nil end
    local perCaster = casterGUID and NP.state.AuraDurationByCaster[casterGUID]
    local learned = (perCaster and perCaster[spellId]) or NP.state.AuraDurationCache[spellId]
    if learned then return learned end
    return AuraDurations and AuraDurations.Duration[spellId]
end

local function GetStaticDebuffType(spellId)
    return (spellId and AuraDurations) and AuraDurations.DebuffType[spellId] or nil
end

-- DR duration estimate for CLEU-only path (unit APIs already return DR-reduced duration).

local DR_RESET_INTERVAL = 15
local DR_FACTORS = { 1, 0.5, 0.25, 0 }

local DR_CATEGORY_BY_SPELL = {
    -- Stuns
    [1833] = "stun", [408] = "stun", [8643] = "stun",
    [6552] = "stun", [6554] = "stun",
    [72] = "stun", [1672] = "stun", [1673] = "stun", [1679] = "stun", [12798] = "stun",
    [5211] = "stun", [6798] = "stun", [8983] = "stun",
    [20549] = "stun",
    [853] = "stun", [5588] = "stun", [5589] = "stun", [10308] = "stun",
    [12809] = "stun",
    [20253] = "stun", [20614] = "stun", [20615] = "stun",
    [30283] = "stun", [89766] = "stun",
    -- Fears
    [5782] = "fear", [6213] = "fear", [6215] = "fear",
    [17928] = "fear",
    [8122] = "fear", [8124] = "fear", [10888] = "fear", [10890] = "fear",
    [5246] = "fear",
    -- Horrors: Death Coil ranks 1-6
    [6789] = "horror", [17925] = "horror", [17926] = "horror",
    [27223] = "horror", [47859] = "horror", [47860] = "horror",
    -- Incapacitates / Polymorph-type / Disorients
    [118] = "incapacitate", [12824] = "incapacitate", [12825] = "incapacitate", [12826] = "incapacitate",
    [28271] = "incapacitate", [28272] = "incapacitate", [61305] = "incapacitate",
    [710] = "incapacitate", [18647] = "incapacitate",
    [51514] = "incapacitate",
    [2637] = "incapacitate", [18657] = "incapacitate", [18658] = "incapacitate",
    [6770] = "incapacitate", [2070] = "incapacitate", [11297] = "incapacitate",
    [3355] = "incapacitate", [14308] = "incapacitate", [14309] = "incapacitate",
    [20066] = "incapacitate",
    [9484] = "incapacitate", [9485] = "incapacitate",
    [33786] = "incapacitate",
    [19386] = "incapacitate", [24132] = "incapacitate", [24133] = "incapacitate", [27068] = "incapacitate",
    [1513] = "incapacitate", [14326] = "incapacitate", [14327] = "incapacitate",
}

-- DRState[guid][category] = { stacks = n, resetAt = time }
local DRState = {}
NP.auras.DRState = DRState

function DebuffRuntime.GetDRCategory(spellId)
    return spellId and DR_CATEGORY_BY_SPELL[spellId]
end

function DebuffRuntime.GetDRFactor(guid, category, now)
    if not guid or not category then
        return 1
    end
    local byGuid = DRState[guid]
    local entry = byGuid and byGuid[category]
    if not entry or now >= entry.resetAt then
        return 1
    end
    return DR_FACTORS[entry.stacks] or 0
end

-- Registers a fresh (non-refresh) application and returns the factor that
-- applies to IT (i.e. after incrementing the stack count).
function DebuffRuntime.RegisterDRApplication(guid, category, now)
    if not guid or not category then
        return 1
    end
    DRState[guid] = DRState[guid] or {}
    local byGuid = DRState[guid]
    local entry = byGuid[category]
    local stacks
    if not entry or now >= entry.resetAt then
        stacks = 1
    else
        stacks = NP.min((entry.stacks or 1) + 1, #DR_FACTORS)
    end
    byGuid[category] = { stacks = stacks, resetAt = now + DR_RESET_INTERVAL }
    return DR_FACTORS[stacks] or 0
end

function NP.auras.WipeDRState(guid)
    if guid then
        DRState[guid] = nil
    end
end

-- Scratch reused each tick; consumer must read before the next wipe.
local expiredGUIDsScratch = {}

function NP.auras.CleanExpiredAuras()
    local now = GetTime()
    local expiredGUIDs = expiredGUIDsScratch
    wipe(expiredGUIDs)
    for guid, auras in pairs(NP.state.PlateAuraCache) do
        local changed = false
        for auraKey, data in pairs(auras) do
            if data.expiration and data.expiration ~= 0 and data.expiration <= now then
                auras[auraKey] = nil
                changed = true
            end
        end
        if not next(auras) then
            NP.state.PlateAuraCache[guid] = nil
        end
        if changed then
            expiredGUIDs[guid] = true
        end
    end
    return expiredGUIDs
end

-- Prune caches on combat end / zone change.
local pruneLiveNames = {}
local pruneLiveGUIDs = {}

function NP.auras.PruneCaches()
    -- An ally outside the group is reachable only by name, so a visible plate keeps its mapping.
    wipe(pruneLiveNames)
    wipe(pruneLiveGUIDs)
    for _, plateData in pairs(NP.module.plates or {}) do
        local plate = plateData and plateData.plate
        if plateData.plateName and plate and plate.IsShown and plate:IsShown() then
            pruneLiveNames[plateData.plateName] = true
        end
    end
    for name, guid in pairs(NP.state.AuraGUIDByName) do
        if pruneLiveNames[name] then
            pruneLiveGUIDs[guid] = true
        else
            NP.state.AuraGUIDByName[name] = nil
        end
    end
    for icon in pairs(NP.state.AuraGUIDByRaidIcon) do
        NP.state.AuraGUIDByRaidIcon[icon] = nil
    end
    for guid in pairs(NP.state.PlateAuraCache) do
        local plateData = NP.state.GUIDToPlate[guid]
        local live = (plateData and plateData.plate and plateData.plate.IsShown
            and plateData.plate:IsShown()) or pruneLiveGUIDs[guid]
        if not live then
            NP.state.PlateAuraCache[guid] = nil
        end
    end
    for guid in pairs(NP.auras.DRState or {}) do
        local plateData = NP.state.GUIDToPlate[guid]
        local live = plateData and plateData.plate and plateData.plate.IsShown
            and plateData.plate:IsShown()
        if not live then
            NP.auras.WipeDRState(guid)
        end
    end
    -- Only the player and the group cast the same spell often enough to be worth keeping.
    local playerGUID = UnitGUID("player")
    for guid in pairs(NP.state.AuraDurationByCaster) do
        if guid ~= playerGUID and not (NP.identity and NP.identity.GroupGUIDToUnit[guid]) then
            NP.state.AuraDurationByCaster[guid] = nil
        end
    end
end

-- Spell filter list parsing (cached by raw string).

-- Keyed by raw string: debuff, buff and friendly lists are consulted in the same pass.
local parsedFilterListCache = {}
local parsedFilterListCount = 0

local function GetParsedFilterSet(rawList)
    rawList = rawList or ""
    local cached = parsedFilterListCache[rawList]
    if cached then
        return cached
    end
    if parsedFilterListCount > 8 then
        wipe(parsedFilterListCache)
        parsedFilterListCount = 0
    end
    local ids = {}
    local names = {}
    for token in string.gmatch(rawList, "[^,%s]+") do
        local id = tonumber(token)
        if id then
            ids[id] = true
            local spellName = GetSpellInfo(id)
            local key = NormalizeAuraName(spellName)
            if key then
                names[key] = true
            end
        end
    end
    local set = { ids = ids, names = names }
    parsedFilterListCache[rawList] = set
    parsedFilterListCount = parsedFilterListCount + 1
    return set
end

local function AuraMatchesFilterSet(data, filterSet)
    if not data or not filterSet then
        return false
    end
    if data.spellId and filterSet.ids[data.spellId] then
        return true
    end
    local key = NormalizeAuraName(data.name)
    if key and filterSet.names[key] then
        return true
    end
    if data.spellId then
        key = NormalizeAuraName(GetSpellInfo(data.spellId))
        if key and filterSet.names[key] then
            return true
        end
    end
    return false
end

-- Mechanics do not flag these (Ice Block carries none), so this hand-kept list seeds defensiveBuffList.
local DEFENSIVE_BUFFS = {
    [642] = true, -- Divine Shield
    [1022] = true, [5599] = true, [10278] = true, -- Hand of Protection
    [498] = true, [5573] = true, -- Divine Protection
    [45438] = true, -- Ice Block
    [48707] = true, -- Anti-Magic Shell
    [48792] = true, -- Icebound Fortitude
    [31224] = true, -- Cloak of Shadows
    [5277] = true, -- Evasion
    [19263] = true, -- Deterrence
    [23920] = true, -- Spell Reflection
    [871] = true, -- Shield Wall
    [12975] = true, -- Last Stand
    [22812] = true, -- Barkskin
    [61336] = true, -- Survival Instincts
    [33206] = true, -- Pain Suppression
    [47585] = true, -- Dispersion
    [46924] = true, -- Bladestorm
    [8178] = true, -- Grounding Totem Effect
    [51690] = true, -- Killing Spree
    [1719] = true, -- Recklessness
    [12292] = true, -- Death Wish
}

-- User lists win over the built-ins so the options panel can show exactly what counts as what.
local function IsDefensiveBuff(spellId, cfg)
    if not spellId then return false end
    local raw = cfg and cfg.defensiveBuffList
    if raw and raw ~= "" then
        return GetParsedFilterSet(raw).ids[spellId] == true
    end
    return DEFENSIVE_BUFFS[spellId] == true
end

-- Crowd control comes from the client's own SpellMechanic ids: every rank and every mob spell.
local function IsCrowdControl(spellId, cfg)
    if not spellId then return false end
    if AuraDurations and AuraDurations.CrowdControl[spellId] then return true end
    local raw = cfg and cfg.ccExtraList
    return raw ~= nil and raw ~= "" and GetParsedFilterSet(raw).ids[spellId] == true
end

-- Sort ranks only. Icon size is a separate, explicit choice: see IsHighlightedAura.
local AURA_RANK = {
    OWN_CC = 1,
    OTHER_CC = 2,
    DEFENSIVE = 3,
    OWN_DEBUFF = 4,
    PURGEABLE = 5,
    OTHER_DEBUFF = 6,
}
NP.auras.AURA_RANK = AURA_RANK

function DebuffRuntime.GetAuraRank(data, playerGUID, cfg)
    if not data then return AURA_RANK.OTHER_DEBUFF end
    local mine = data.casterGUID ~= nil and data.casterGUID == playerGUID
    if data.isBuff then
        if IsDefensiveBuff(data.spellId, cfg) then
            return AURA_RANK.DEFENSIVE
        end
        return AURA_RANK.PURGEABLE
    end
    if IsCrowdControl(data.spellId, cfg) then
        return mine and AURA_RANK.OWN_CC or AURA_RANK.OTHER_CC
    end
    return mine and AURA_RANK.OWN_DEBUFF or AURA_RANK.OTHER_DEBUFF
end

-- Which auras draw larger. Explicit, not derived from the rank: the player can see and change it.
function DebuffRuntime.IsHighlightedAura(data, cfg)
    if not data or not cfg then return false end
    local mode = cfg.auraHighlightMode or "cc"
    if mode == "none" then return false end
    if (mode == "cc" or mode == "ccAndList") and IsCrowdControl(data.spellId, cfg) then
        return true
    end
    if mode == "list" or mode == "ccAndList" then
        local raw = cfg.auraHighlightList
        return raw ~= nil and raw ~= "" and AuraMatchesFilterSet(data, GetParsedFilterSet(raw))
    end
    return false
end

function DebuffRuntime.GetAuraSizeScale(data, cfg)
    if DebuffRuntime.IsHighlightedAura(data, cfg) then
        return tonumber(cfg.auraHighlightScale) or 1.35
    end
    return 1
end

local function PassesListFilter(mode, rawList, data)
    if mode ~= "whitelist" and mode ~= "blacklist" then
        return true
    end
    local inSet = AuraMatchesFilterSet(data, GetParsedFilterSet(rawList))
    if mode == "whitelist" then return inSet end
    return not inSet
end

-- Pre-filter: a raid's worth of ally auras must not reach the cache only to be dropped on draw.
function DebuffRuntime.IsAllyAuraWanted(spellId, cfg, isBuff)
    if not spellId or not cfg then return false end
    if not isBuff and cfg.friendlyIncludeAllDebuffs then
        return true
    end
    if cfg.friendlyIncludeCC and IsCrowdControl(spellId, cfg) then
        return true
    end
    if cfg.friendlyIncludeDefensive and IsDefensiveBuff(spellId, cfg) then
        return true
    end
    local raw = cfg.friendlyAuraFilterList
    return raw ~= nil and raw ~= "" and GetParsedFilterSet(raw).ids[spellId] == true
end

function DebuffRuntime.PassesFilters(cfg, data, isFriendlyPlate)
    if not cfg or not data then
        return true
    end
    -- Allies carry dozens of auras; anything but an explicit list fills the screen.
    if isFriendlyPlate then
        if not data.isBuff and cfg.friendlyIncludeAllDebuffs then
            return true
        end
        if cfg.friendlyIncludeCC and IsCrowdControl(data.spellId, cfg) then
            return true
        end
        if cfg.friendlyIncludeDefensive and IsDefensiveBuff(data.spellId, cfg) then
            return true
        end
        return AuraMatchesFilterSet(data, GetParsedFilterSet(cfg.friendlyAuraFilterList))
    end
    if data.isBuff then
        if cfg.showBuffs == false then
            return false
        end
        local mode = cfg.buffFilterMode or "purgeable"
        -- Purgeable covers what a plate actually needs: what to spellsteal, dispel or wait out.
        if mode == "purgeable" then
            local dispel = data.debuffType or GetStaticDebuffType(data.spellId)
            return dispel == "Magic" or dispel == "Enrage" or IsDefensiveBuff(data.spellId, cfg)
        end
        return PassesListFilter(mode, cfg.buffFilterList, data)
    end
    -- Crowd control matters whoever cast it, so it survives the "only mine" filter.
    if cfg.debuffOnlyMine and data.casterGUID ~= UnitGUID("player") then
        if not (cfg.debuffIncludeOtherCC and IsCrowdControl(data.spellId, cfg)) then
            return false
        end
    end
    return PassesListFilter(cfg.debuffFilterMode, cfg.debuffFilterList, data)
end

local function DebuffPriorityComparator(a, b)
    if a.rank ~= b.rank then
        return a.rank < b.rank
    end
    return a.expiration < b.expiration
end

local function ChronologicalComparator(a, b)
    return a.expiration < b.expiration
end

-- Pooled aura list; callers consume synchronously and copy scalars only.
local cachedDebuffPool = {}
local cachedDebuffResult = {}

function DebuffRuntime.GetCachedAuras(guid, maxCount, cfg, isFriendlyPlate)
    if not guid or not NP.state.PlateAuraCache[guid] then return nil end
    local now = GetTime()
    local playerGUID = UnitGUID("player")
    local result = cachedDebuffResult
    for i = #result, 1, -1 do
        result[i] = nil
    end
    local n = 0
    for _, data in pairs(NP.state.PlateAuraCache[guid]) do
        local active = data.expiration and (data.expiration == 0 or data.expiration > now)
        if active and DebuffRuntime.PassesFilters(cfg, data, isFriendlyPlate) then
            local _, _, tex = GetSpellInfo(data.spellId)
            n = n + 1
            local slot = cachedDebuffPool[n]
            if not slot then
                slot = {}
                cachedDebuffPool[n] = slot
            end
            slot.texture = data.texture or tex
            slot.count = data.count
            slot.expiration = data.expiration
            slot.debuffType = data.debuffType
            slot.spellId = data.spellId
            slot.casterGUID = data.casterGUID
            slot.duration = data.duration
            slot.isBuff = data.isBuff
            slot.rank = DebuffRuntime.GetAuraRank(data, playerGUID, cfg)
            result[n] = slot
        end
    end
    sort(result, (cfg and cfg.auraSortMode == "chronological")
        and ChronologicalComparator or DebuffPriorityComparator)
    if maxCount and n > maxCount then
        for i = maxCount + 1, n do
            result[i] = nil
        end
    end
    return result
end

-- Kept for callers that predate the buff-aware rename.
DebuffRuntime.GetCachedDebuffs = DebuffRuntime.GetCachedAuras

-- UnitDebuff scan when unitid is available

local knownCastersScratch = {}

local RAID_TARGET_TOKENS = {}
for i = 1, 40 do
    RAID_TARGET_TOKENS[i] = "raid" .. i .. "target"
end
local PARTY_TARGET_TOKENS = {}
for i = 1, 4 do
    PARTY_TARGET_TOKENS[i] = "party" .. i .. "target"
end

-- GUID scanned by the caller still on the stack; the client's aura table cannot change inside one.
local freshScanGUID

function DebuffRuntime.UpdateAuraCacheFromUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local cfg = NP.config.GetCfg()
    local isFriendly = UnitIsFriend("player", unit) and true or false
    if isFriendly and not cfg.showFriendlyAuras then
        return nil
    end
    local guid = UnitGUID(unit)
    if not guid then
        return nil
    end
    if guid == freshScanGUID then
        return guid
    end
    local destIsPlayer = UnitIsPlayer(unit)

    -- Preserve known casterGUID across rescans when UnitDebuff returns nil caster.
    -- Scratch table; wiped per UNIT_AURA and aura CLEU event.
    local knownCasters = knownCastersScratch
    wipe(knownCasters)
    if NP.state.PlateAuraCache[guid] then
        for _, data in pairs(NP.state.PlateAuraCache[guid]) do
            if data.spellId and data.casterGUID then
                knownCasters[data.spellId] = data.casterGUID
            end
        end
    end

    DebuffRuntime.WipeAuraCache(guid)
    for i = 1, 40 do
        -- 3.3.5a also returns shouldConsolidate and spellId as values 10/11.
        local name, _, iconTex, count, debuffType, duration, expirationTime, unitCaster,
            _, _, spellId = UnitDebuff(unit, i)
        if not name then
            break
        end
        spellId = tonumber(spellId) or DebuffRuntime.ResolveSpellIdByName(name)
        if spellId and IsAuraExpirationActive(expirationTime) then
            local casterGUID = (unitCaster and UnitGUID(unitCaster)) or knownCasters[spellId]
            DebuffRuntime.LearnAuraDuration(spellId, duration, casterGUID, guid, destIsPlayer)
            DebuffRuntime.AddCachedAura(guid, spellId, expirationTime, count, casterGUID, iconTex, debuffType, name, duration)
        end
    end

    if cfg.showBuffs or isFriendly then
        for i = 1, 40 do
            local name, _, iconTex, count, debuffType, duration, expirationTime, unitCaster,
                _, _, spellId = UnitBuff(unit, i)
            if not name then
                break
            end
            spellId = tonumber(spellId) or DebuffRuntime.ResolveSpellIdByName(name)
            if spellId and IsAuraExpirationActive(expirationTime) then
                local casterGUID = (unitCaster and UnitGUID(unitCaster)) or knownCasters[spellId]
                DebuffRuntime.LearnAuraDuration(spellId, duration, casterGUID, guid, destIsPlayer)
                DebuffRuntime.AddCachedAura(guid, spellId, expirationTime, count, casterGUID, iconTex, debuffType, name, duration, true)
            end
        end
    end

    -- Strongest name -> GUID proof there is; the plate needs it once the token is gone.
    if destIsPlayer then
        local unitName = UnitName(unit)
        if unitName then
            NP.state.AuraGUIDByName[unitName] = guid
        end
    end

    -- Raid icon -> GUID lookup fallback.
    local iconIndex = GetRaidTargetIndex and GetRaidTargetIndex(unit)
    if iconIndex then
        local iconName = RAID_ICON_NAME_BY_INDEX[iconIndex]
        if iconName then
            NP.state.AuraGUIDByRaidIcon[iconName] = guid
        end
    end

    return guid
end

-- Returns the GUID actually rescanned from a live unit, so callers can skip a second scan.
function DebuffRuntime.UpdateAuraCacheByLookup(guid)
    if not guid then
        return nil
    end
    -- Group tokens give exact durations, so they beat the target/mouseover probes for allies.
    local groupUnit = NP.identity.GetGroupUnitByGUID and NP.identity.GetGroupUnitByGUID(guid)
    if groupUnit then
        return DebuffRuntime.UpdateAuraCacheFromUnit(groupUnit)
    end
    if guid == UnitGUID("target") then
        return DebuffRuntime.UpdateAuraCacheFromUnit("target")
    end
    if guid == UnitGUID("mouseover") then
        return DebuffRuntime.UpdateAuraCacheFromUnit("mouseover")
    end
    if guid == UnitGUID("focus") then
        return DebuffRuntime.UpdateAuraCacheFromUnit("focus")
    end
    -- Group-target lookup: in raids prefer raidN (partyN ⊆ raidN; probing both doubles API calls).
    local numRaid = GetNumRaidMembers() or 0
    if numRaid > 0 then
        for i = 1, numRaid do
            local targetUnit = RAID_TARGET_TOKENS[i] or ("raid" .. i .. "target")
            if UnitExists(targetUnit) and UnitGUID(targetUnit) == guid then
                return DebuffRuntime.UpdateAuraCacheFromUnit(targetUnit)
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local targetUnit = PARTY_TARGET_TOKENS[i] or ("party" .. i .. "target")
            if UnitExists(targetUnit) and UnitGUID(targetUnit) == guid then
                return DebuffRuntime.UpdateAuraCacheFromUnit(targetUnit)
            end
        end
    end
    return nil
end

-- Aura widget render and per-icon expiration polling

-- Cache formatted cooldown text (~1/s or ~1/min updates); minutes capped at MINUTES_CACHE_MAX.
local SECONDS_TEXT_CACHE = {}
for i = 1, 60 do
    SECONDS_TEXT_CACHE[i] = tostring(i)
end
local MINUTES_TEXT_CACHE = {}
local MINUTES_CACHE_MAX = 180

local function FormatAuraTimeLeft(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end
    if seconds > 60 then
        local minutes = math.ceil(seconds / 60)
        local cached = MINUTES_TEXT_CACHE[minutes]
        if cached then
            return cached
        end
        local text = tostring(minutes) .. "m"
        if minutes <= MINUTES_CACHE_MAX then
            MINUTES_TEXT_CACHE[minutes] = text
        end
        return text
    end
    local wholeSeconds = math.ceil(seconds)
    return SECONDS_TEXT_CACHE[wholeSeconds] or tostring(wholeSeconds)
end

local function ApplyCooldownTextAnchor(icon, anchor)
    if not icon or not icon.cooldownText then
        return
    end
    icon.cooldownText:ClearAllPoints()
    if anchor == "center" then
        icon.cooldownText:SetPoint("CENTER", icon, "CENTER", 0, 0)
    elseif anchor == "topleft" then
        icon.cooldownText:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    elseif anchor == "bottomleft" then
        icon.cooldownText:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
    elseif anchor == "bottomright" then
        icon.cooldownText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    else
        icon.cooldownText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
    end
end

-- Forward declarations for swipe helpers; hoisted so pollers resolve style once per sweep.
local UpdateSwipeProgressStyled
local GetSwipeStyle

-- Per-icon poll; re-entrancy guard prevents RenderDebuffWidgets ↔ PollHostIcons loops.
local pollHostIconsActive = setmetatable({}, { __mode = "k" })

local function PollHostIcons(host, now, cfg)
    if not host or not host.icons or pollHostIconsActive[host] then
        return
    end
    pollHostIconsActive[host] = true
    now = now or GetTime()
    cfg = cfg or NP.config.GetCfg()
    local fontSize = host._debuffCooldownFontSize or 9
    local showCooldown = host._debuffShowCooldown
    local anyExpired = false
    for _, icon in ipairs(host.icons) do
        if icon and icon.IsShown and icon:IsShown() and icon.expiration then
            -- expiration == 0: permanent aura; must not treat as expired.
            if icon.expiration == 0 then
                if icon.cooldownText and icon._lastCdText ~= "" then
                    icon.cooldownText:SetText("")
                    icon.cooldownText:Hide()
                    icon._lastCdText = ""
                end
            else
                local remaining = icon.expiration - now
                if remaining <= 0 then
                    anyExpired = true
                else
                    if icon.cooldownText then
                        if showCooldown then
                            -- Font rarely changes; SetFont recreates the font
                            -- object, so only re-apply when the size differs.
                            if icon._appliedCdFontSize ~= fontSize then
                                icon.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                                icon._appliedCdFontSize = fontSize
                            end
                            -- Countdown text only changes ~1/s; skip identical SetText.
                            local txt = FormatAuraTimeLeft(remaining)
                            if icon._lastCdText ~= txt then
                                icon.cooldownText:SetText(txt)
                                icon.cooldownText:Show()
                                icon._lastCdText = txt
                            end
                        elseif icon._lastCdText ~= "" then
                            icon.cooldownText:SetText("")
                            icon.cooldownText:Hide()
                            icon._lastCdText = ""
                        end
                    end
                    -- Swipe is driven exclusively by the 0.03s tier (RefreshHostSwipe);
                    -- no redundant update here.
                end
            end
        end
    end
    if anyExpired and host._renderGUID then
        local cached = DebuffRuntime.GetCachedAuras(host._renderGUID, host._renderMaxIcons, cfg, host._renderFriendly)
        NP.auras.RenderDebuffWidgets(host, cached, host._renderMaxIcons, cfg)
    end
    pollHostIconsActive[host] = nil
end

local function RefreshHostSwipe(host, cfg, now)
    if not host or not host.icons or not cfg or not cfg.debuffCooldownSwipe then
        return
    end
    local style = GetSwipeStyle(cfg)
    for _, icon in ipairs(host.icons) do
        if icon and icon.IsShown and icon:IsShown() and icon.expiration and icon.expiration > 0 then
            local remaining = icon.expiration - now
            if remaining > 0 then
                UpdateSwipeProgressStyled(icon, remaining, style)
            end
        end
    end
end

local function SetAuraPoller(host, enabled)
    if not host then
        return
    end
    host._debuffPollElapsed = 0
    host._debuffSwipeElapsed = 0
    if enabled then
        host:SetScript("OnUpdate", function(self, elapsed)
            self._debuffSwipeElapsed = (self._debuffSwipeElapsed or 0) + elapsed
            self._debuffPollElapsed = (self._debuffPollElapsed or 0) + elapsed
            local swipeDue = self._debuffSwipeElapsed >= SWIPE_UPDATE_INTERVAL
            local pollDue = self._debuffPollElapsed >= DEBUFF_UPDATE_INTERVAL
            if not swipeDue and not pollDue then
                return
            end
            -- Resolve cfg/now once per firing frame and share across both tiers.
            local cfg = NP.config.GetCfg()
            local now = GetTime()
            if swipeDue then
                self._debuffSwipeElapsed = 0
                RefreshHostSwipe(self, cfg, now)
            end
            if pollDue then
                self._debuffPollElapsed = 0
                PollHostIcons(self, now, cfg)
            end
        end)
        PollHostIcons(host)
    else
        host:SetScript("OnUpdate", nil)
        if host.icons then
            for _, icon in ipairs(host.icons) do
                if icon and icon.cooldownText then
                    icon.cooldownText:SetText("")
                    icon.cooldownText:Hide()
                    icon._lastCdText = nil
                end
            end
        end
    end
end

local function IsDebuffIconBorderEnabled(cfg)
    if not addon.CreateIconFrameTexture then return false end
    return not (cfg and cfg.debuffModernIconBorder == false)
end

-- Blizzard's rule: every debuff gets a colour, no dispel type means "none". Only the palette is ours.
local function ResolveAuraBorderColor(aura, cfg)
    if not (aura and cfg and cfg.debuffHighlightCC) then return nil end
    local colors = cfg.auraColors
    if aura.isBuff then
        return colors and colors.Buff
    end
    if cfg.auraColorCCEnabled and IsCrowdControl(aura.spellId, cfg) then
        return colors and colors.CrowdControl
    end
    local key = aura.debuffType
    if key == nil or key == "" or (colors and colors[key]) == nil then
        key = "none"
    end
    return colors and colors[key]
end

-- CC highlight border using Blizzard debuff-type colors.
local function ApplyPriorityHighlight(icon, aura, cfg)
    if not icon then return end
    if not icon.priorityBorder then
        icon.priorityBorder = icon:CreateTexture(nil, "BACKGROUND")
        icon.priorityBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
        icon.priorityBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
        icon.priorityBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    end

    local color = ResolveAuraBorderColor(aura, cfg)

    -- The frame buries priorityBorder's 1px overhang, so it carries the CC colour instead.
    if icon.duiIconFrame and IsDebuffIconBorderEnabled(cfg) then
        if addon.SetIconFrameTextureTinted then
            addon.SetIconFrameTextureTinted(icon.duiIconFrame, color ~= nil)
        end
        if color then
            icon.duiIconFrame:SetVertexColor(color.r, color.g, color.b, 1)
        else
            icon.duiIconFrame:SetVertexColor(1, 1, 1, 1)
        end
        icon.priorityBorder:Hide()
        return
    end

    if color then
        icon.priorityBorder:SetVertexColor(color.r, color.g, color.b, 1)
        icon.priorityBorder:Show()
    else
        icon.priorityBorder:Hide()
    end
end

local function HidePriorityHighlight(icon)
    if icon and icon.priorityBorder then icon.priorityBorder:Hide() end
end

-- Plain-texture swipe; native Cooldown goes stale on moving plates.
local SWIPE_MIN = 0.00001
local floor = math.floor
local min = NP.min

local SwipeStyle = {}

-- vertical: single shade growing top-down as the debuff counts down.
SwipeStyle.vertical = {
    ensure = function(icon)
        if icon._swipeFill then return end
        local fill = icon:CreateTexture(nil, "OVERLAY", nil, 1)
        fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        fill:SetVertexColor(0, 0, 0, 0.65)
        fill:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        fill:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        fill:SetHeight(SWIPE_MIN)
        fill:Hide()
        icon._swipeFill = fill
    end,
    update = function(icon, progress)
        local fill = icon._swipeFill
        if not fill then return end
        local h = (icon:GetHeight() or 0) * progress
        fill:SetHeight(max(SWIPE_MIN, h))
        fill:Show()
    end,
    hide = function(icon)
        if icon._swipeFill then icon._swipeFill:Hide() end
    end,
}

-- pie: four wedges fill in clockwise order (TR, BR, BL, TL) to approximate a
-- radial sweep using only plain rectangles.
local QUADRANT_GROWS_VERTICALLY = { true, false, true, false }
local QUADRANT_ANCHOR = { "BOTTOMLEFT", "TOPLEFT", "TOPRIGHT", "BOTTOMRIGHT" }

SwipeStyle.pie = {
    ensure = function(icon)
        if icon._swipeQuadrants then return end
        local quadrants = {}
        for i = 1, 4 do
            local tex = icon:CreateTexture(nil, "OVERLAY", nil, 1)
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            tex:SetVertexColor(0, 0, 0, 0.65)
            tex:Hide()
            quadrants[i] = tex
        end
        icon._swipeQuadrants = quadrants
    end,
    update = function(icon, progress)
        local quadrants = icon._swipeQuadrants
        if not quadrants then return end
        local halfW = (icon:GetWidth() or 0) / 2
        local halfH = (icon:GetHeight() or 0) / 2
        local scaled = min(max(progress, 0), 0.999999) * 4
        local base = floor(scaled)
        local active = base + 1
        local sub = scaled - base
        for i, tex in ipairs(quadrants) do
            local fraction = nil
            if i < active then
                fraction = 1
            elseif i == active and sub > 0 then
                fraction = sub
            end
            if fraction then
                tex:ClearAllPoints()
                tex:SetPoint(QUADRANT_ANCHOR[i], icon, "CENTER", 0, 0)
                if QUADRANT_GROWS_VERTICALLY[i] then
                    tex:SetWidth(halfW)
                    tex:SetHeight(halfH * fraction)
                else
                    tex:SetWidth(halfW * fraction)
                    tex:SetHeight(halfH)
                end
                tex:Show()
            else
                tex:Hide()
            end
        end
    end,
    hide = function(icon)
        if icon._swipeQuadrants then
            for _, tex in ipairs(icon._swipeQuadrants) do tex:Hide() end
        end
    end,
}

-- squareSwirl: pre-rendered square radial flipbook. 3.3.5a cannot mask a
-- diagonal/radial region at runtime, so each atlas cell is one ready state.
local SQUARE_SWIRL_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\cooldown-square-swirl"
local SQUARE_SWIRL_GRID = 32
local SQUARE_SWIRL_FRAMES = SQUARE_SWIRL_GRID * SQUARE_SWIRL_GRID
local SQUARE_SWIRL_TEXEL_INSET = 0.5 / 1024

local function SetSquareSwirlFrame(tex, frame)
    local col = frame % SQUARE_SWIRL_GRID
    local row = floor(frame / SQUARE_SWIRL_GRID)
    local left = (col / SQUARE_SWIRL_GRID) + SQUARE_SWIRL_TEXEL_INSET
    local right = ((col + 1) / SQUARE_SWIRL_GRID) - SQUARE_SWIRL_TEXEL_INSET
    local top = (row / SQUARE_SWIRL_GRID) + SQUARE_SWIRL_TEXEL_INSET
    local bottom = ((row + 1) / SQUARE_SWIRL_GRID) - SQUARE_SWIRL_TEXEL_INSET
    tex:SetTexCoord(left, right, top, bottom)
end

SwipeStyle.squareSwirl = {
    ensure = function(icon)
        if icon._swipeSquareSwirl then return end
        local tex = icon:CreateTexture(nil, "OVERLAY", nil, 1)
        tex:SetAllPoints(icon)
        tex:SetTexture(SQUARE_SWIRL_TEXTURE)
        tex:Hide()
        icon._swipeSquareSwirl = tex
        icon._swipeSquareSwirlFrame = nil
    end,
    update = function(icon, progress)
        local tex = icon._swipeSquareSwirl
        if not tex then return end
        local frame = floor(min(max(progress, 0), 0.999999) * SQUARE_SWIRL_FRAMES)
        if frame ~= icon._swipeSquareSwirlFrame then
            icon._swipeSquareSwirlFrame = frame
            SetSquareSwirlFrame(tex, frame)
        end
        tex:Show()
    end,
    hide = function(icon)
        if icon._swipeSquareSwirl then icon._swipeSquareSwirl:Hide() end
        icon._swipeSquareSwirlFrame = nil
    end,
}

function GetSwipeStyle(cfg)
    local style = cfg and cfg.debuffCooldownSwipeStyle
    return SwipeStyle[style] or SwipeStyle.squareSwirl
end

-- Hide whichever style's widgets are currently attached to the icon, if it
-- differs from the one about to be used (covers a live style change).
local function HideOtherSwipeStyles(icon, active)
    for _, style in pairs(SwipeStyle) do
        if style ~= active and style.hide then
            style.hide(icon)
        end
    end
end

local function ApplySwipeCooldown(icon, aura, cfg)
    if not icon then return end
    local style = GetSwipeStyle(cfg)
    if not (cfg and cfg.debuffCooldownSwipe) then
        HideOtherSwipeStyles(icon, nil)
        icon._swipeExpiration = nil
        icon._swipeDuration = nil
        return
    end
    local expiration = aura and aura.expiration
    if not expiration or expiration <= GetTime() then
        HideOtherSwipeStyles(icon, nil)
        icon._swipeExpiration = nil
        icon._swipeDuration = nil
        return
    end
    HideOtherSwipeStyles(icon, style)
    style.ensure(icon)
    if icon._swipeExpiration ~= expiration then
        icon._swipeExpiration = expiration
        local remaining = expiration - GetTime()
        local totalDuration = aura.duration or GetBaseAuraDuration(aura.spellId, aura.casterGUID) or remaining
        if totalDuration < remaining then
            totalDuration = remaining
        end
        icon._swipeDuration = totalDuration
        if style.start then
            style.start(icon, expiration - totalDuration, totalDuration)
        end
    end
    if style.update then
        local progress = 1 - ((expiration - GetTime()) / icon._swipeDuration)
        if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
        style.update(icon, progress)
    end
end

-- Per-poll-tick refresh for texture-driven styles, with a pre-resolved style so
-- the per-host sweep resolves GetSwipeStyle once instead of once per icon.
function UpdateSwipeProgressStyled(icon, remaining, style)
    if not icon._swipeDuration or icon._swipeDuration <= 0 then return end
    if not style or not style.update then return end
    local progress = 1 - (remaining / icon._swipeDuration)
    if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
    style.update(icon, progress)
end

local function HideSwipeCooldown(icon)
    if not icon then return end
    HideOtherSwipeStyles(icon, nil)
    icon._swipeExpiration = nil
    icon._swipeDuration = nil
end

-- Re-level debuff icon children with minaDebuffHost after depth sort.
function NP.auras.ApplyDebuffIconFrameLevels(host)
    if not host or not host.icons then return end
    local base = (host.GetFrameLevel and host:GetFrameLevel()) or 0
    -- Guard SetFrameLevel when icon already at target level (runs every depth tick).
    for _, icon in ipairs(host.icons) do
        if icon.SetFrameLevel then
            if not icon.GetFrameLevel or icon:GetFrameLevel() ~= base + 1 then
                icon:SetFrameLevel(base + 1)
            end
        end
        if icon.frameLayer and icon.frameLayer.SetFrameLevel then
            if not icon.frameLayer.GetFrameLevel or icon.frameLayer:GetFrameLevel() ~= base + 2 then
                icon.frameLayer:SetFrameLevel(base + 2)
            end
        end
        if icon.textLayer and icon.textLayer.SetFrameLevel then
            if not icon.textLayer.GetFrameLevel or icon.textLayer:GetFrameLevel() ~= base + 3 then
                icon.textLayer:SetFrameLevel(base + 3)
            end
        end
    end
end

-- Sole debuff icon renderer; expects pre-resolved cache data.
function NP.auras.RenderDebuffWidgets(host, cachedAuras, maxIcons, cfg)
    if not host then return end
    local iconSize = (cfg and cfg.debuffIconSize) or 16
    local showCooldown = cfg == nil or cfg.showDebuffCooldown ~= false
    local cooldownFontSize = (cfg and cfg.debuffCooldownFontSize) or 9
    local cooldownTextAnchor = (cfg and cfg.debuffCooldownTextAnchor) or "topright"
    local framed = IsDebuffIconBorderEnabled(cfg)

    host._debuffCooldownFontSize = cooldownFontSize
    host._debuffShowCooldown = showCooldown
    host._renderMaxIcons = maxIcons

    if not cachedAuras or #cachedAuras == 0 then
        SetAuraPoller(host, false)
        host._renderGUID = nil
        host:Hide()
        for _, icon in ipairs(host.icons or {}) do
            icon.expiration = nil
            icon:Hide()
            HidePriorityHighlight(icon)
            HideSwipeCooldown(icon)
            -- Force a fresh SetText next time this icon is reused.
            icon._lastCdText = nil
        end
        return
    end

    local shown = 0
    local rowWidth, tallest = 0, 0
    for _, aura in ipairs(cachedAuras) do
        shown = shown + 1
        if shown > maxIcons then break end
        local icon = host.icons[shown]
        if not icon then
            icon = CreateFrame("Frame", nil, host)
            icon.texture = icon:CreateTexture(nil, "ARTWORK")
            icon.texture:SetAllPoints(icon)
            -- Layer order: highlight → art → swipe overlay → text (child frame).
            -- 3.3.5a ignores texture sublayers, so the lazy swipe would draw over the frame art.
            icon.frameLayer = CreateFrame("Frame", nil, icon)
            icon.frameLayer:SetAllPoints(icon)
            icon.frameLayer:SetFrameLevel(icon:GetFrameLevel() + 1)
            icon.textLayer = CreateFrame("Frame", nil, icon)
            icon.textLayer:SetAllPoints(icon)
            icon.textLayer:SetFrameLevel(icon:GetFrameLevel() + 2)
            icon.text = icon.textLayer:CreateFontString(nil, "OVERLAY")
            icon.text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            icon.text:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
            icon.cooldownText = icon.textLayer:CreateFontString(nil, "OVERLAY")
            icon.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", cooldownFontSize, "OUTLINE")
            if addon.CreateIconFrameTexture then
                icon.duiIconFrame = addon.CreateIconFrameTexture(icon.frameLayer, "OVERLAY")
            end
            host.icons[shown] = icon
        end
        local size = iconSize * DebuffRuntime.GetAuraSizeScale(aura, cfg)
        icon:SetSize(size, size)
        if icon.duiIconFrame then
            if framed then
                addon.LayoutIconFrameTexture(icon.duiIconFrame, icon, size)
                icon.duiIconFrame:Show()
            else
                icon.duiIconFrame:Hide()
            end
        end
        if icon._duiFramedArt ~= framed then
            icon._duiFramedArt = framed
            if framed then
                icon.texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
            else
                icon.texture:SetTexCoord(0, 1, 0, 1)
            end
        end
        icon:ClearAllPoints()
        -- Bottom-aligned so a bigger rank grows upward instead of shifting the row.
        if shown == 1 then
            icon:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
            rowWidth = size
        else
            local gap = 2 + (framed and addon.GetIconFrameGap(size, 2) or 0)
            icon:SetPoint("BOTTOMLEFT", host.icons[shown - 1], "BOTTOMRIGHT", gap, 0)
            rowWidth = rowWidth + gap + size
        end
        if size > tallest then tallest = size end
        icon.texture:SetTexture(aura.texture)
        icon.text:SetText(aura.count and aura.count > 1 and aura.count or "")
        icon.expiration = aura.expiration
        ApplyPriorityHighlight(icon, aura, cfg)
        ApplySwipeCooldown(icon, aura, cfg)
        -- Re-apply SetFont only on size change.
        if icon._appliedCdFontSize ~= cooldownFontSize then
            icon.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", cooldownFontSize, "OUTLINE")
            icon._appliedCdFontSize = cooldownFontSize
        end
        ApplyCooldownTextAnchor(icon, cooldownTextAnchor)
        if showCooldown then
            local txt = FormatAuraTimeLeft((aura.expiration or 0) - GetTime())
            icon.cooldownText:SetText(txt)
            icon.cooldownText:Show()
            icon._lastCdText = txt
        else
            icon.cooldownText:SetText("")
            icon.cooldownText:Hide()
            icon._lastCdText = ""
        end
        icon:Show()
    end
    for i = shown + 1, #host.icons do
        host.icons[i].expiration = nil
        if host.icons[i].cooldownText then
            host.icons[i].cooldownText:SetText("")
            host.icons[i].cooldownText:Hide()
        end
        host.icons[i]:Hide()
        HidePriorityHighlight(host.icons[i])
        HideSwipeCooldown(host.icons[i])
        -- Force a fresh SetText next time this icon is reused.
        host.icons[i]._lastCdText = nil
    end

    host:SetSize(max(1, rowWidth), max(iconSize, tallest))
    NP.auras.ApplyDebuffIconFrameLevels(host)

    -- Poll while icons are visible to update both expiration and countdown text.
    SetAuraPoller(host, true)
    if shown > 0 then
        host:Show()
    else
        host:Hide()
    end
end

-- Plate → aura GUID resolution

function NP.auras.ResolvePlateDebuffGUID(plateData)
    if not plateData then
        return nil
    end
    local reaction, ptype = NP.native_style.GetPlateReaction(plateData)
    if reaction == "FRIENDLY" then
        -- Player names are unique per realm, so a name match is proof enough for an ally.
        if not (NP.config.GetCfg().showFriendlyAuras and ptype == "PLAYER" and plateData.plateName) then
            return nil
        end
        return NP.identity.GetGroupGUIDByName(plateData.plateName)
            or NP.state.AuraGUIDByName[plateData.plateName]
    end
    if ptype == "PLAYER" and plateData.plateName then
        local guid = NP.state.AuraGUIDByName[plateData.plateName]
        if guid then
            return guid
        end
    end
    local iconName = NP.native_style.GetPlateRaidIconName(plateData)
    if iconName then
        return NP.state.AuraGUIDByRaidIcon[iconName]
    end
    return nil
end

function NP.auras.FindFallbackPlateForGUID(guid)
    if not guid then
        return nil
    end
    for _, plateData in pairs(NP.module.plates) do
        if plateData
            and plateData.plate
            and plateData.plate.IsShown
            and plateData.plate:IsShown()
            and NP.auras.ResolvePlateDebuffGUID(plateData) == guid then
            return plateData
        end
    end
    return nil
end

-- SyncDebuffs: identity → cache → render

function NP.auras.SyncDebuffs(plateData, hintedUnit)
    local host = plateData.minaDebuffHost
    if not host then return end

    local cfg = NP.config.GetCfg()
    if cfg.showDebuffs == false then
        NP.state.HidePlateDebuffs(plateData)
        if NP.widgets and NP.widgets.ReflowTopOverlays then
            NP.widgets.ReflowTopOverlays(plateData)
        end
        NP.auras.SyncPreviewOverlay(plateData)
        return
    end

    if cfg.debuffOnlyTargetFocus
        and not (NP.identity.IsTargetPlate(plateData) or NP.identity.IsFocusPlate(plateData)) then
        NP.state.HidePlateDebuffs(plateData)
        if NP.widgets and NP.widgets.ReflowTopOverlays then
            NP.widgets.ReflowTopOverlays(plateData)
        end
        NP.auras.SyncPreviewOverlay(plateData)
        return
    end

    local maxIcons = cfg.maxDebuffs or 5

    -- Conservative ownership validation: evict only when another plate
    -- demonstrably owns the unit token.
    NP.identity.ValidatePlateGUIDOwnership(plateData)

    local unit = NP.identity.GetUnitForPlate(plateData, hintedUnit)
    -- GetUnitForPlate stops at target/focus/mouseover; plate and group tokens need no targeting.
    if not unit then
        -- Re-check the name: nameplateN can have been recycled onto another unit since last sync.
        local token = plateData.namePlateUnitToken
        if token and UnitExists(token) and NP.identity.UnitNameMatchesPlate(token, plateData) then
            unit = token
        elseif cfg.showFriendlyAuras
            and NP.native_style.GetPlateReaction(plateData) == "FRIENDLY" then
            unit = NP.identity.GetGroupUnitByName(plateData.plateName)
        end
    end
    if unit then
        local refreshedGUID = DebuffRuntime.UpdateAuraCacheFromUnit(unit)
        if refreshedGUID and not NP.state.GetPlateGUID(plateData)
            and NP.identity.FriendlyPlateMayUseGUID(plateData, refreshedGUID) then
            NP.state.SetPlateGUID(plateData, refreshedGUID, {
                source = "AURA_HINT",
                confidence = C.GUID_CONFIDENCE.AURA_HINT,
            })
        end
    end

    -- Render from the bound GUID; fall back to hostile-player name or raid
    -- target icon. Never render debuffs from a GUID owned by another plate.
    local guid = NP.state.GetPlateGUID(plateData)
    if not guid then
        guid = NP.auras.ResolvePlateDebuffGUID(plateData)
    end

    if guid and not NP.identity.FriendlyPlateMayUseGUID(plateData, guid) then
        if NP.state.GetPlateGUID(plateData) == guid then
            NP.state.ClearPlateGUID(plateData)
        end
        guid = nil
    end

    if guid then
        -- Plate colour, not the token: a friendly plate without one must still filter as friendly.
        local isFriendlyPlate = NP.native_style.GetPlateReaction(plateData) == "FRIENDLY"
        local cached = DebuffRuntime.GetCachedAuras(guid, maxIcons, cfg, isFriendlyPlate)
        host._renderGUID = guid
        host._renderFriendly = isFriendlyPlate
        NP.auras.RenderDebuffWidgets(host, cached, maxIcons, cfg)
    else
        -- Without a resolvable GUID, hide this widget without invalidating caches.
        NP.state.HidePlateDebuffs(plateData)
    end
    if NP.widgets and NP.widgets.ReflowTopOverlays then
        NP.widgets.ReflowTopOverlays(plateData)
    end
    NP.auras.SyncPreviewOverlay(plateData)
end

-- Debug overlay: independent of minaDebuffHost since it's hidden/zero-size with no active debuffs.

local DEBUFF_PREVIEW_SECONDS = 10

function NP.auras.EnsurePreviewOverlay(plateData)
    if plateData.debuffPreviewOverlay then
        return plateData.debuffPreviewOverlay
    end
    local plate = plateData.plate
    if not plate or not plate.CreateTexture then
        return nil
    end
    local tex = plate:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(0.1, 0.6, 0.9, 0.35)
    if tex.SetDrawLayer then
        tex:SetDrawLayer("OVERLAY", 7)
    end
    tex:Hide()
    plateData.debuffPreviewOverlay = tex
    return tex
end

function NP.auras.ShouldShowPreview()
    local cfg = NP.config.GetCfg()
    if cfg.showDebuffs == false then
        return false
    end
    if cfg.showDebuffPositionDebug == true then
        return true
    end
    local untilTime = NP.module._debuffPreviewUntil
    return untilTime and GetTime() < untilTime or false
end

function NP.auras.ApplyPreviewGeometry(plateData, cfg)
    local overlay = plateData.debuffPreviewOverlay
    local relativeFrame = plateData.minaNameRow or plateData.minaName
    if not overlay or not relativeFrame then
        return
    end
    cfg = cfg or NP.config.GetCfg()
    local iconSize = cfg.debuffIconSize or 24
    local maxIcons = cfg.maxDebuffs or 5
    local spacing = 2 + (IsDebuffIconBorderEnabled(cfg) and addon.GetIconFrameGap(iconSize, 2) or 0)
    local width = (iconSize * maxIcons) + (spacing * max(0, maxIcons - 1))

    overlay:ClearAllPoints()
    overlay:SetSize(width, iconSize)
    overlay:SetPoint("BOTTOMLEFT", relativeFrame, "TOPLEFT",
        cfg.debuffOffsetX or 0, (C.DEBUFF_HOST_OFFSET_Y or 2) + (cfg.debuffOffsetY or 0))
end

function NP.auras.SyncPreviewOverlay(plateData)
    if not plateData then
        return
    end
    local overlay = NP.auras.EnsurePreviewOverlay(plateData)
    if not overlay then
        return
    end
    if NP.auras.ShouldShowPreview() then
        NP.auras.ApplyPreviewGeometry(plateData)
        overlay:Show()
    else
        overlay:Hide()
    end
end

function NP.auras.RefreshAllPreviewOverlays()
    for _, plateData in pairs(NP.module.plates) do
        NP.auras.SyncPreviewOverlay(plateData)
    end
end

function NP.auras.EnablePreview(seconds)
    NP.module._debuffPreviewUntil = GetTime() + (seconds or DEBUFF_PREVIEW_SECONDS)
    NP.auras.RefreshAllPreviewOverlays()
end

function NP.auras.TickPreview()
    if not NP.module._debuffPreviewUntil then
        return
    end
    if GetTime() >= NP.module._debuffPreviewUntil then
        NP.module._debuffPreviewUntil = nil
        if not NP.config.GetCfg().showDebuffPositionDebug then
            NP.auras.RefreshAllPreviewOverlays()
        end
    end
end

-- Combat log path

-- Gate aura CLEU to debuff sub-events; avoids UnitDebuff rescan on damage/heal traffic.
local AURA_COMBATLOG_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_BROKEN = true,
    SPELL_AURA_BROKEN_SPELL = true,
}
-- Exported for engine CLEU subevent gating.
NP.auras.AURA_COMBATLOG_EVENTS = AURA_COMBATLOG_EVENTS

function NP.auras.HandleCombatLog(timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, ...)
    if not AURA_COMBATLOG_EVENTS[event] then
        return
    end
    -- SPELL_AURA_BROKEN_SPELL: irregular suffix; string guard lets it reach removal path.
    local auraType = select(1, ...)
    local cfg = NP.config.GetCfg()
    local isBuff = auraType == "BUFF"
    if isBuff and not (cfg.showBuffs or cfg.showFriendlyAuras) then
        return
    end
    if type(auraType) == "string" and auraType ~= "DEBUFF" and not isBuff then
        return
    end
    if type(destFlags) == "string" then
        destFlags = tonumber(destFlags) or tonumber(destFlags, 16)
    end
    local destIsFriendly = destFlags and COMBATLOG_OBJECT_REACTION_FRIENDLY
        and bit.band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0
    if destIsFriendly and not cfg.showFriendlyAuras then
        return
    end
    spellId = tonumber(spellId)
    if not destGUID or not spellId then
        return
    end
    if destIsFriendly and not DebuffRuntime.IsAllyAuraWanted(spellId, cfg, isBuff) then
        return
    end
    -- Player name -> GUID for the name-based lookup fallback (allies included once enabled).
    if destName and destFlags and COMBATLOG_OBJECT_CONTROL_PLAYER
        and bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0 then
        local rawName = strsplit("-", destName)
        if rawName then
            NP.state.AuraGUIDByName[rawName] = destGUID
        end
    end
    local changed
    local scannedGUID = DebuffRuntime.UpdateAuraCacheByLookup(destGUID)
    if scannedGUID then
        changed = true
    elseif event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        local _, _, texture = GetSpellInfo(spellId)
        local baseDuration = GetBaseAuraDuration(spellId, sourceGUID)
        if baseDuration and baseDuration > 0 then
            local effectiveDuration = baseDuration
            local category = DebuffRuntime.GetDRCategory(spellId)
            if category then
                local now = GetTime()
                local factor = (event == "SPELL_AURA_APPLIED")
                    and DebuffRuntime.RegisterDRApplication(destGUID, category, now)
                    or DebuffRuntime.GetDRFactor(destGUID, category, now)
                -- factor 0 means the server would not have applied the aura at
                -- all (full immunity); guard defensively rather than show 0s.
                effectiveDuration = (factor > 0) and (baseDuration * factor) or baseDuration
            end
            DebuffRuntime.AddCachedAura(destGUID, spellId, GetTime() + effectiveDuration, 1, sourceGUID, texture, GetStaticDebuffType(spellId), spellName, effectiveDuration, isBuff)
            changed = true
        end
    elseif event == "SPELL_AURA_APPLIED_DOSE" then
        local count = tonumber(select(2, ...)) or 1
        local _, _, texture = GetSpellInfo(spellId)
        local duration = GetBaseAuraDuration(spellId, sourceGUID)
        if duration and duration > 0 then
            DebuffRuntime.AddCachedAura(destGUID, spellId, GetTime() + duration, count, sourceGUID, texture, GetStaticDebuffType(spellId), spellName, duration, isBuff)
            changed = true
        end
    elseif event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_BROKEN" or event == "SPELL_AURA_BROKEN_SPELL" then
        DebuffRuntime.RemoveCachedAura(destGUID, spellId, sourceGUID)
        changed = true
    elseif event == "SPELL_AURA_REMOVED_DOSE" then
        local count = tonumber(select(2, ...))
        local auraKey = DebuffRuntime.MakeAuraCacheKey(spellId, sourceGUID)
        local existing = auraKey and NP.state.PlateAuraCache[destGUID] and NP.state.PlateAuraCache[destGUID][auraKey]
        if existing then
            existing.count = max(1, count or existing.count or 1)
            changed = true
        end
    end
    if changed then
        local plateData = NP.state.GUIDToPlate[destGUID] or NP.auras.FindFallbackPlateForGUID(destGUID)
        if plateData then
            freshScanGUID = scannedGUID
            NP.gather.RefreshPlateAuras(plateData, nil, "combat_log_aura")
            freshScanGUID = nil
        end
    end
end

NP.widgets.Register("Debuffs", {
    Ensure = function(plateData)
        return plateData and plateData.minaDebuffHost ~= nil
    end,
    Layout = function(plateData)
        return plateData and plateData.minaDebuffHost ~= nil
    end,
    Sync = function(plateData, context)
        NP.auras.SyncDebuffs(plateData, context and context.resolvedUnit or nil)
    end,
    Hide = function(plateData)
        NP.state.HidePlateDebuffs(plateData)
    end,
})
