-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates quest icons: mark a plate's mob as a kill/loot objective with our own
-- texture. Backend picked once at load: C_QuestLog.GetUnitQuestInfo if present, else a
-- tooltip scan + quest-log crossref. Needs a token (stock: target/mouseover/focus).

NP.quest = NP.quest or {}

local strmatch = string.match

-- Capability probe (once): improved clients expose this; stock 3.3.5a does not.
local hasQuestApi = (C_QuestLog and type(C_QuestLog.GetUnitQuestInfo) == "function") and true or false

-- Tooltip backend only: hidden scanner (never GameTooltip, so it can't fight the
-- visible tooltip) and threat-line filter. Not created on API clients.
local QuestScanTip, threatPattern
if not hasQuestApi then
    QuestScanTip = CreateFrame("GameTooltip", "DragonUINPQuestScan", UIParent, "GameTooltipTemplate")
    QuestScanTip:SetOwner(UIParent, "ANCHOR_NONE")
    -- Threat % line ("50% Threat") also parses as percent progress; filter it out.
    threatPattern = THREAT_TOOLTIP and THREAT_TOOLTIP:gsub("%%d", "%%d+")
end

local function IsThreatLine(text)
    return threatPattern ~= nil and strmatch(text, threatPattern) ~= nil
end

-- normalizedObjectiveText -> "loot" | "kill"
local objectiveTypeIndex = {}
local indexBuilt = false
-- Bumped on every quest log event; part of each plate's scan cache key.
local questLogVersion = 0
-- Engine tick of the last rebuild; coalesces QUEST_LOG_UPDATE bursts within a tick.
local lastBuildFrame = nil
-- Engine tick a quest change was seen; a deferred rebuild runs one tick later because the
-- first QUEST_LOG_UPDATE after accepting often carries an empty leaderboard.
local pendingRebuildFrame = nil

local SCAN_TTL = 0.7

-- Token-less: match plate name to objectives so stock clients get icons on every plate.
local killNameIndex = {}   -- normalizedMobName -> questID (kill objective)
local lootNameIndex = {}   -- normalizedMobName -> questID (loot objective)
-- Set when the active provider's DB wasn't ready during a rebuild; a ticker then retries.
local lootProviderNotReady = false
local lootRetryFrame
local lootRetryActive
-- Static quest->drop-mob map; computed once per quest per session (key for QuestHelper's costly DB).
local staticLootCache = {}
local lootCacheProviderId = nil

NP.quest.lootProviders = NP.quest.lootProviders or {}
function NP.quest.RegisterLootProvider(p)
    table.insert(NP.quest.lootProviders, p)
    table.sort(NP.quest.lootProviders, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
end

-- Locale-safe capture of the mob name from a "monster" leaderboard line.
local killNamePattern
do
    local fmt = QUEST_MONSTERS_KILLED or "%s slain: %d/%d"
    fmt = fmt:gsub("%%s", "\001"):gsub("%%d", "\002")
    fmt = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
    fmt = fmt:gsub("\001", "(.-)"):gsub("\002", "%%d+")
    killNamePattern = "^" .. fmt .. "$"
end

-- Persistent learned loot sources: [mobName] = {objectiveText=true}. nil until AceDB is ready.
local function GetLearnedDB()
    local db = addon.db
    if not (db and db.global) then return nil end
    db.global.questLootLearned = db.global.questLootLearned or {}
    return db.global.questLootLearned
end

local function QueueQuestRefresh()
    if NP.engine and NP.engine.QueueMass and NP.engine.Callbacks then
        NP.engine.QueueMass(NP.engine.Callbacks.OnUpdateQuest)
    end
end

local function NormalizeName(name)
    if not name then return nil end
    return name:gsub("^%s*(.-)%s*$", "%1"):lower()
end

-- Per-plate cache: the name-mode path runs every sync, so avoid re-normalizing a stable name.
local function NormalizedPlateName(plateData)
    local raw = plateData.plateName
    if plateData._questNormSrc ~= raw then
        plateData._questNormSrc = raw
        plateData._questNormName = NormalizeName(raw)
    end
    return plateData._questNormName
end

-- Token path taught us this mob is a loot source; persist it, keyed by normalized objective text.
local function LearnLootKey(mobKey, objText)
    local learned = GetLearnedDB()
    if not learned or not objText or not mobKey or mobKey == "" then return end
    local objs = learned[mobKey]
    if not objs then objs = {}; learned[mobKey] = objs end
    if not objs[objText] then
        objs[objText] = true
        QueueQuestRefresh()
    end
end

local function LearnLoot(plateData, objText)
    LearnLootKey(NormalizedPlateName(plateData), objText)
end

-- True if this mob is a learned loot source for a still-incomplete active objective.
local function LearnedLootActive(mobKey)
    local learned = GetLearnedDB()
    local objs = learned and learned[mobKey]
    if not objs then return false end
    for objText in pairs(objs) do
        if objectiveTypeIndex[objText] == "loot" then return true end
    end
    return false
end

-- Normalize tooltip lines and leaderboard text to one locale-agnostic key.
local function NormalizeObjectiveText(text)
    if not text then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("%b[]", "")
    text = text:gsub("%b()", "")
    text = text:gsub("%d+%s*/%s*%d+", "")
    text = text:gsub("[%d%.]+%%", "")
    text = text:gsub("%p", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s*(.-)%s*$", "%1")
    return text:lower()
end

local function RebuildObjectiveIndex()
    wipe(objectiveTypeIndex)
    wipe(killNameIndex)
    local selection = GetQuestLogSelection()
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        if not isHeader and not isComplete then
            SelectQuestLogEntry(i)
            local numObj = GetNumQuestLeaderBoards(i)
            for o = 1, numObj do
                local desc, objType, finished = GetQuestLogLeaderBoard(o, i)
                if desc and not finished then
                    local norm = NormalizeObjectiveText(desc)
                    if norm and norm ~= "" then
                        objectiveTypeIndex[norm] =
                            (objType == "item" or objType == "object") and "loot" or "kill"
                    end
                    if objType == "monster" then
                        local mobName = strmatch(desc, killNamePattern)
                        local key = NormalizeName(mobName)
                        if key and key ~= "" then
                            killNameIndex[key] = questID or true
                        end
                    end
                end
            end
        end
    end
    SelectQuestLogEntry(selection)
    indexBuilt = true
end

local function EnsureIndexBuilt()
    if not indexBuilt then
        RebuildObjectiveIndex()
    end
end

-- Returns hasObj, objType, tag; pointerMode skips the kill/loot crossref.
local function ScanUnitForQuest(unit, pointerMode)
    -- Show() populates the dynamic quest lines; same-frame Hide() = no visible flicker.
    QuestScanTip:SetOwner(UIParent, "ANCHOR_NONE")
    QuestScanTip:ClearLines()
    QuestScanTip:SetUnit(unit)
    QuestScanTip:Show()
    local numLines = QuestScanTip:NumLines()

    local hasObj = false
    local foundKill, foundLoot = false, false
    local killKey, lootKey
    for i = 2, numLines do
        local fs = _G["DragonUINPQuestScanTextLeft" .. i]
        local text = fs and fs.GetText and fs:GetText()
        if text and text ~= "" and not IsThreatLine(text) then
            local incomplete = false
            local done, total = strmatch(text, "(%d+)%s*/%s*(%d+)")
            if done and total then
                incomplete = tonumber(done) < tonumber(total)
            else
                local pct = tonumber(strmatch(text, "([%d%.]+)%%"))
                if pct then incomplete = pct < 100 end
            end
            if incomplete then
                if pointerMode then
                    hasObj = true
                    break
                end
                local norm = NormalizeObjectiveText(text) or ""
                local t = objectiveTypeIndex[norm]
                if t == "loot" then
                    foundLoot, lootKey = true, norm
                elseif t == "kill" then
                    foundKill, killKey = true, norm
                end
            end
        end
    end
    QuestScanTip:Hide()

    if not pointerMode then
        if foundLoot and not foundKill then
            return true, "loot", lootKey
        elseif foundKill or foundLoot then
            return true, "kill", killKey or lootKey
        end
        return false, nil, nil
    end
    return hasObj, nil, nil
end

-- API backend: collect -> loot, objective -> kill; a set talkToMe = quest-giver (skip).
local function ResolveQuestViaApi(unit, pointerMode)
    local questStatus, questID, talkToMe = C_QuestLog.GetUnitQuestInfo(unit)
    if talkToMe and talkToMe ~= "" then return false, nil, nil end
    if not questStatus then return false, nil, nil end
    if questID and questID > 0 and GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(questID)
        if idx and idx > 0 then
            local _, _, _, _, _, _, isComplete = GetQuestLogTitle(idx)
            if isComplete then return false, nil, nil end
        end
    end
    if questStatus == "collect" then
        return true, (not pointerMode) and "loot" or nil, questID
    elseif questStatus == "objective" then
        return true, (not pointerMode) and "kill" or nil, questID
    end
    return false, nil, nil
end

-- Revalidate a token-less persisted icon; drop it once its objective/quest completes.
local function IsPersistValid(p)
    if p.ver == questLogVersion then return true end
    if p.pointer then return false end
    if hasQuestApi then
        if not (p.tag and GetQuestLogIndexByID) then return false end
        local idx = GetQuestLogIndexByID(p.tag)
        if not idx or idx == 0 then return false end
        local _, _, _, _, _, _, isComplete = GetQuestLogTitle(idx)
        if isComplete then return false end
    else
        if not (p.tag and objectiveTypeIndex[p.tag]) then return false end
    end
    p.ver = questLogVersion
    return true
end

local function QueryObjective(unit, pointerMode)
    if hasQuestApi then
        return ResolveQuestViaApi(unit, pointerMode)
    end
    if not pointerMode then
        EnsureIndexBuilt()
    end
    return ScanUnitForQuest(unit, pointerMode)
end

-- Highest-priority available provider, honoring the lootProvider config (auto|off|id).
local function GetActiveLootProvider()
    local cfg = NP.config.GetCfg().questIcons
    local pref = (cfg and cfg.lootProvider) or "auto"
    if pref == "off" then return nil end
    for _, p in ipairs(NP.quest.lootProviders) do
        if p.IsAvailable() then
            if pref == "auto" then return p end
            if pref == p.id then return p end
        end
    end
    return nil
end

-- Providers (QuestHelper/Questie) compile their DBs async; retry the rebuild until ready.
local function StartLootRetry()
    if lootRetryActive then return end
    lootRetryActive = true
    -- WoW frames are never GC'd; reuse and gate with lootRetryActive.
    if not lootRetryFrame then
        lootRetryFrame = CreateFrame("Frame")
    end
    local tick, waited = 0, 0
    lootRetryFrame:SetScript("OnUpdate", function(self, e)
        tick = tick + e
        if tick < 2 then return end
        waited, tick = waited + tick, 0
        if not lootProviderNotReady or waited > 60 then
            self:SetScript("OnUpdate", nil)
            lootRetryActive = nil
            return
        end
        if NP.quest.OnQuestLogChanged then NP.quest.OnQuestLogChanged() end
    end)
end

-- Only quests with an incomplete item/object objective contribute, so finished loot drops off.
local function RebuildLootIndex()
    wipe(lootNameIndex)
    lootProviderNotReady = false
    local cfg = NP.config.GetCfg().questIcons
    if not cfg or cfg.enabled ~= true or cfg.nameResolution ~= true then return end
    local prov = GetActiveLootProvider()
    if not prov then
        lootCacheProviderId = nil
        return
    end
    if lootCacheProviderId ~= prov.id then
        wipe(staticLootCache)
        lootCacheProviderId = prov.id
    end
    local selection = GetQuestLogSelection()
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        if not isHeader and not isComplete and questID and questID > 0 then
            SelectQuestLogEntry(i)
            local hasIncompleteLoot = false
            local numObj = GetNumQuestLeaderBoards(i)
            for o = 1, numObj do
                local _, objType, finished = GetQuestLogLeaderBoard(o, i)
                if (objType == "item" or objType == "object") and not finished then
                    hasIncompleteLoot = true
                    break
                end
            end
            if hasIncompleteLoot then
                local names = staticLootCache[questID]
                if names == nil then
                    names = {}
                    -- Third-party DB: guard against errors; false = DB not ready, leave uncached to retry.
                    local ok, ready = pcall(prov.CollectLootMobs, questID, names)
                    if not ok then
                        staticLootCache[questID] = names
                    elseif ready == false then
                        lootProviderNotReady = true
                    else
                        staticLootCache[questID] = names
                    end
                end
                for _, mn in ipairs(names) do
                    local key = NormalizeName(mn)
                    if key and key ~= "" and not killNameIndex[key] then
                        lootNameIndex[key] = questID
                    end
                end
            end
        end
    end
    SelectQuestLogEntry(selection)
    if lootProviderNotReady then StartLootRetry() end
end

local function ResolveQuestForPlate(plateData, unit, pointerMode)
    local now = GetTime and GetTime() or 0
    local key = (plateData.plateName or "?") .. "|" .. questLogVersion .. "|" .. (pointerMode and "p" or "t")
    local cache = plateData._questScan
    if cache and cache.key == key and cache.at and now < cache.at + SCAN_TTL then
        return cache.hasObj, cache.objType, cache.tag
    end
    local hasObj, objType, tag = QueryObjective(unit, pointerMode)
    plateData._questScan = { key = key, at = now, hasObj = hasObj, objType = objType, tag = tag }
    return hasObj, objType, tag
end

-- Which texture shows for this objective, given the current config.
local function GetActiveIconKey(q, objType, isElite)
    if q.pointerMode then return "pointer" end
    if objType == "loot" then
        return (q.lootIcon == "chest") and "chest" or "bag"
    end
    if isElite and q.eliteKillIcon then return "elite" end
    return (q.killIcon == "skull") and "skull" or "sword"
end

local function EnsureQuestIcon(plateData)
    if plateData._questIcon then return plateData._questIcon end
    local parent = plateData.minaHp or plateData.visualRoot or plateData.plate
    if not parent then return nil end
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:Hide()
    plateData._questIcon = icon
    return icon
end

local function HideQuestIcon(plateData)
    if not plateData then return end
    plateData._questElite = nil
    if plateData._questIcon then
        plateData._questIcon:Hide()
    end
end

-- Apply the given icon key's texture, per-icon size and per-icon x/y, then show.
local function ShowQuestIcon(plateData, q, key)
    local hp = plateData.minaHp
    if not hp or not key then HideQuestIcon(plateData); return end
    local icon = EnsureQuestIcon(plateData)
    if not icon then return end
    local ic = q.icons and q.icons[key]
    -- Signals the Elite widget to drop its dragon icon (avoids duplicate elite marks).
    plateData._questElite = (key == "elite")
    icon:SetTexture(C.QUEST_ICON_TEX[key])
    -- Shared texture: mirror the sword horizontally, reset the others.
    if key == "sword" then
        icon:SetTexCoord(1, 0, 0, 1)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
    local size = (ic and ic.size) or 22
    icon:SetSize(size, size)
    if icon.SetParent then icon:SetParent(hp) end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", hp, "CENTER", (ic and ic.x) or 0, (ic and ic.y) or 20)
    icon:Show()
end

local function SyncQuestIcon(plateData, context)
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true then
        HideQuestIcon(plateData)
        return
    end

    -- Test preview: force one chosen icon on enemy/neutral plates for tuning.
    if q.testIcon and q.testIcon ~= "off" then
        local reaction = NP.native_style.GetPlateReaction(plateData)
        if reaction == "FRIENDLY" then
            HideQuestIcon(plateData)
            return
        end
        ShowQuestIcon(plateData, q, q.testIcon)
        return
    end

    local pointerMode = q.pointerMode == true
    local unit = context and context.resolvedUnit or NP.gather.ResolvePlateToken(plateData)

    local hasObj, objType
    -- Token first (most precise): resolve live and remember it.
    if unit and UnitExists(unit) and not UnitIsPlayer(unit) then
        local tag
        hasObj, objType, tag = ResolveQuestForPlate(plateData, unit, pointerMode)
        if hasObj then
            -- Learn loot sources from the tooltip scan so token-less plates can show them later.
            if objType == "loot" and not hasQuestApi then
                LearnLoot(plateData, tag)
            end
            local p = plateData._questPersist or {}
            p.objType, p.tag, p.ver, p.pointer = objType, tag, questLogVersion, pointerMode
            plateData._questPersist = p
        end
    end
    -- Name fallback: the tooltip scan can miss (e.g. quest-tracking tooltip CVar off), so the
    -- addon-free kill index / learned loot still covers the plate even when it has a token.
    if not hasObj and q.nameResolution == true then
        local reaction, kind = NP.native_style.GetPlateReaction(plateData)
        if reaction ~= "FRIENDLY" and kind ~= "PLAYER" then
            local key = NormalizedPlateName(plateData)
            if key and key ~= "" then
                if killNameIndex[key] then
                    hasObj, objType = true, "kill"
                elseif lootNameIndex[key] or LearnedLootActive(key) then
                    hasObj, objType = true, "loot"
                end
            end
        end
    end
    if not hasObj then
        -- Last resort: the persisted icon while its objective stays active.
        local p = plateData._questPersist
        if p and IsPersistValid(p) then
            hasObj, objType = true, p.objType
        else
            plateData._questPersist = nil
        end
    end

    if not hasObj then
        HideQuestIcon(plateData)
        return
    end
    local isElite = false
    if objType == "kill" and not pointerMode and q.eliteKillIcon then
        isElite = NP.native_style.ResolvePlateClassification(plateData, unit) ~= nil
    end
    ShowQuestIcon(plateData, q, GetActiveIconKey(q, objType, isElite))
end

NP.widgets.Register("Quest", {
    ShouldShow = function(plateData)
        local q = NP.config.GetCfg().questIcons
        if not q or q.enabled ~= true then return false end
        if NP.quest_coexist and NP.quest_coexist.ShouldDeferToQuestie() then return false end
        return true
    end,
    Ensure = function(plateData)
        return EnsureQuestIcon(plateData) ~= nil
    end,
    Sync = function(plateData, context)
        SyncQuestIcon(plateData, context)
    end,
    Hide = HideQuestIcon,
})

local function DoRebuildIndexes()
    RebuildObjectiveIndex()
    RebuildLootIndex()
    questLogVersion = questLogVersion + 1
end

-- Quest changed: rebuild indexes now (coalesced per tick), bump version, refresh.
function NP.quest.OnQuestLogChanged()
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true then return end
    local frame = NP.module and NP.module._engineFrame
    if frame == nil or lastBuildFrame ~= frame then
        lastBuildFrame = frame
        DoRebuildIndexes()
    end
    pendingRebuildFrame = frame or 0
    QueueQuestRefresh()
end

-- Engine tick hook: re-run the rebuild once the post-accept leaderboard has settled.
function NP.quest.TickDeferredRebuild(currentFrame)
    if pendingRebuildFrame == nil then return end
    if currentFrame and currentFrame > pendingRebuildFrame then
        pendingRebuildFrame = nil
        lastBuildFrame = currentFrame
        DoRebuildIndexes()
        QueueQuestRefresh()
    end
end

-- Loot fallback for the rare mob whose tooltip omits its loot objective; skips if token already taught it.
function NP.quest.OnLootOpened()
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true or q.nameResolution ~= true then return end
    if not next(objectiveTypeIndex) then return end
    if not (UnitExists("target") and UnitIsDead("target") and not UnitIsPlayer("target")) then return end
    local mobKey = NormalizeName(UnitName("target"))
    if not mobKey or mobKey == "" then return end
    if LearnedLootActive(mobKey) then return end
    local learned = GetLearnedDB()
    if not learned then return end
    local numItems = GetNumLootItems and GetNumLootItems() or 0
    local changed = false
    for slot = 1, numItems do
        local _, itemName = GetLootSlotInfo(slot)
        local key = NormalizeObjectiveText(itemName)
        if key and objectiveTypeIndex[key] == "loot" then
            local objs = learned[mobKey]
            if not objs then objs = {}; learned[mobKey] = objs end
            if not objs[key] then
                objs[key] = true
                changed = true
            end
        end
    end
    if changed then QueueQuestRefresh() end
end

-- Fourth source: the mob-model mouseover token never resolves to a plate, so scan it directly.
local lastMouseoverScan
function NP.quest.OnMouseover()
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true or q.nameResolution ~= true or hasQuestApi then return end
    if not next(objectiveTypeIndex) then return end
    if not (UnitExists("mouseover") and not UnitIsPlayer("mouseover")
        and UnitCanAttack("player", "mouseover")) then return end
    local guid = UnitGUID("mouseover")
    if guid == lastMouseoverScan then return end
    lastMouseoverScan = guid
    local mobKey = NormalizeName(UnitName("mouseover"))
    if not mobKey or mobKey == "" or LearnedLootActive(mobKey) then return end
    local hasObj, objType, tag = QueryObjective("mouseover", false)
    if hasObj and objType == "loot" and tag then
        LearnLootKey(mobKey, tag)
    end
end

function NP.quest.ClearIndex()
    wipe(objectiveTypeIndex)
    wipe(killNameIndex)
    wipe(lootNameIndex)
    wipe(staticLootCache)
    lootCacheProviderId = nil
    indexBuilt = false
    lastBuildFrame = nil
    pendingRebuildFrame = nil
end
