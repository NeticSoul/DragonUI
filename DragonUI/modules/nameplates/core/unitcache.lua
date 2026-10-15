-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates

-- Name-keyed memory for token-less plates: friendly players (class, guild, title) and NPC subtitles.

NP.unitcache = NP.unitcache or {}
local UC = NP.unitcache

local floor, find, sub, select, type, pairs, ipairs, pcall, tonumber =
    math.floor, string.find, string.sub, select, type, pairs, ipairs, pcall, tonumber
local band = bit.band

local SCHEMA = 1
-- Own order, never CLASS_SORT_ORDER: saved indexes must not move if another addon reorders that table.
local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_INDEX = {}
for i = 1, #CLASS_TOKENS do
    CLASS_INDEX[CLASS_TOKENS[i]] = i
end

-- value = class + 16 * title + 16384 * guild + 2^31 * day; every field stays exact in a double.
local TITLE_MUL, GUILD_MUL, DAY_MUL = 16, 16384, 2147483648
local MAX_TITLES, MAX_GUILDS = 1023, 131071
local MAX_AGE_DAYS = 90
local MAX_PLAYERS = 20000
local MAX_NPCS = 20000
local MAX_SEEN_GUIDS = 30000
local GUILDLESS_CONFIRM = 2
local ROSTER_INTERVAL = 60
local PRUNE_DELAY = 20
local FRIENDLY_PLAYER_FLAGS = (COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) + (COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x10)

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
}

local RAID_UNITS, PARTY_UNITS = {}, {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end
for i = 1, 4 do PARTY_UNITS[i] = "party" .. i end

local store, npcTitles
local guildIndex, titleIndex = {}, {}
local playerCount, npcCount = 0, 0
local today = 0
local seen, seenCount = {}, 0
local npcChecked = {}
local guildlessAt = {}
local pending, hasPending, groupDirty = {}, false, false
local wantClass, wantGuild, wantTitle, wantNPC = false, false, false, false
local active, persist, backgroundOn = false, true, false
local chatOn, rosterOn, friendsOn = false, false, false
local lastRosterScan
local localizedToIndex
local learner
local playerName

local function Unpack(v)
    local class = v % 16
    v = (v - class) / 16
    local title = v % 1024
    v = (v - title) / 1024
    local guild = v % 131072
    return class, title, guild, (v - guild) / 131072
end

local function Pack(class, title, guild, day)
    return class + TITLE_MUL * title + GUILD_MUL * guild + DAY_MUL * day
end

local function IsPlayerKey(name)
    -- Player names never hold a hyphen or a space; "Name-Realm" is another realm's player.
    return type(name) == "string" and name ~= "" and name ~= UNKNOWN and name ~= UNKNOWNOBJECT
        and not find(name, "-", 1, true) and not find(name, " ", 1, true)
end

local function IsNPCKey(name)
    return type(name) == "string" and name ~= "" and name ~= UNKNOWN and name ~= UNKNOWNOBJECT
end

local function NewStore()
    return { v = SCHEMA, players = {}, guilds = {}, titles = {}, pruneDay = 0 }
end

local function RebuildIndexes()
    wipe(guildIndex)
    wipe(titleIndex)
    for i, guildName in ipairs(store.guilds) do
        guildIndex[guildName] = i
    end
    for i, pattern in ipairs(store.titles) do
        titleIndex[pattern] = i
    end
    playerCount = 0
    for _ in pairs(store.players) do
        playerCount = playerCount + 1
    end
    npcCount = 0
    for _ in pairs(npcTitles) do
        npcCount = npcCount + 1
    end
end

local function MarkPending(name)
    pending[name] = true
    hasPending = true
end

-- guild / title: nil keeps the stored value, 0 clears it.
local function Upsert(name, class, guild, title)
    local players = store.players
    local old = players[name]
    local oc, ot, og, od = 0, 0, 0, 0
    if type(old) == "number" then
        oc, ot, og, od = Unpack(old)
    end
    -- A new class means another character took the name; the old guild and title are not theirs.
    if oc ~= 0 and oc ~= class then
        og, ot = 0, 0
    end
    local ng = guild or og
    local nt = title or ot
    if class == oc and ng == og and nt == ot and od == today then
        return
    end
    players[name] = Pack(class, nt, ng, today)
    if old == nil then
        playerCount = playerCount + 1
    end
    if class ~= oc or ng ~= og or nt ~= ot then
        MarkPending(name)
    end
end

local function GuildToIndex(guildName)
    local i = guildIndex[guildName]
    if i then
        return i
    end
    local list = store.guilds
    if #list >= MAX_GUILDS then
        return nil
    end
    i = #list + 1
    list[i] = guildName
    guildIndex[guildName] = i
    return i
end

local function TitleToIndex(pattern)
    local i = titleIndex[pattern]
    if i then
        return i
    end
    local list = store.titles
    if #list >= MAX_TITLES then
        return nil
    end
    i = #list + 1
    list[i] = pattern
    titleIndex[pattern] = i
    return i
end

-- UnitPVPName wraps the bare name in the title ("Sergeant Bob", "Bob the Patient").
local function TitleFromUnit(unit, name)
    local full = UnitPVPName(unit)
    if type(full) ~= "string" or full == "" then
        return nil
    end
    local s, e = find(full, name, 1, true)
    if not s then
        return nil
    end
    if s == 1 and e == #full then
        return 0
    end
    return TitleToIndex(sub(full, 1, s - 1) .. "%s" .. sub(full, e + 1))
end

-- A guild name can reach the client after the unit does; only two guildless reads apart mean "no guild".
local function ConfirmGuildless(name, storedGuild)
    if storedGuild == 0 then
        return 0
    end
    local now = GetTime()
    local first = guildlessAt[name]
    if not first then
        guildlessAt[name] = now
        return nil
    end
    if now - first < GUILDLESS_CONFIRM then
        return nil
    end
    guildlessAt[name] = nil
    return 0
end

local function LearnPlayerUnit(unit)
    if UnitIsUnit(unit, "player") or not UnitIsFriend("player", unit) then
        return
    end
    local name, realm = UnitName(unit)
    if (realm and realm ~= "") or not IsPlayerKey(name) then
        return
    end
    local _, token = UnitClass(unit)
    local class = token and CLASS_INDEX[token]
    if not class then
        return
    end
    -- Out of visibility range (far raid members, raid frames) guild and title read as "none".
    if not UnitIsVisible(unit) then
        Upsert(name, class, nil, nil)
        return
    end
    local guild
    local guildName = GetGuildInfo(unit)
    if guildName and guildName ~= "" then
        guildlessAt[name] = nil
        guild = GuildToIndex(guildName)
    else
        local old = store.players[name]
        local storedGuild = 0
        if type(old) == "number" then
            local _, _, g = Unpack(old)
            storedGuild = g
        end
        guild = ConfirmGuildless(name, storedGuild)
    end
    Upsert(name, class, guild, TitleFromUnit(unit, name))
end

function UC.SetNPCTitle(name, title)
    if not active or not npcTitles or not IsNPCKey(name) or type(title) ~= "string" or title == "" then
        return
    end
    local old = npcTitles[name]
    if old == title then
        return
    end
    if old == nil then
        if npcCount >= MAX_NPCS then
            return
        end
        npcCount = npcCount + 1
    end
    npcTitles[name] = title
    MarkPending(name)
end

local function LearnNPCUnit(unit)
    local name = UnitName(unit)
    if not IsNPCKey(name) or npcChecked[name] then
        return
    end
    npcChecked[name] = true
    UC.SetNPCTitle(name, NP.gather.ScanNPCSubtitle(unit))
end

function UC.LearnUnit(unit)
    if not active or not unit or not UnitExists(unit) then
        return
    end
    if UnitIsPlayer(unit) then
        if wantClass or wantGuild or wantTitle then
            LearnPlayerUnit(unit)
        end
    elseif wantNPC and not UnitPlayerControlled(unit) then
        LearnNPCUnit(unit)
    end
end

local function NoteGUID(guid, name, flags)
    if seenCount >= MAX_SEEN_GUIDS then
        wipe(seen)
        seenCount = 0
    end
    seenCount = seenCount + 1
    if flags then
        if type(flags) ~= "number" then
            flags = tonumber(flags) or tonumber(flags, 16) or 0
        end
        if band(flags, FRIENDLY_PLAYER_FLAGS) ~= FRIENDLY_PLAYER_FLAGS then
            seen[guid] = false
            return
        end
    end
    if not IsPlayerKey(name) or name == playerName then
        seen[guid] = false
        return
    end
    -- pcall: some cores raise for a GUID that is not a player.
    local ok, _, token = pcall(GetPlayerInfoByGUID, guid)
    local class = ok and token and CLASS_INDEX[token]
    seen[guid] = class and true or false
    if class then
        Upsert(name, class, nil, nil)
    end
end

-- Runs for every combat log event while background learning is on: two table reads in the common case.
function UC.OnCombatLog(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags)
    if srcGUID and seen[srcGUID] == nil then
        NoteGUID(srcGUID, srcName, srcFlags)
    end
    if dstGUID and seen[dstGUID] == nil then
        NoteGUID(dstGUID, dstName, dstFlags)
    end
end

local function ScanGuildRoster()
    local now = GetTime()
    if lastRosterScan and now - lastRosterScan < ROSTER_INTERVAL then
        return
    end
    local guildName = GetGuildInfo("player")
    if not guildName or guildName == "" then
        return
    end
    lastRosterScan = now
    local guild = GuildToIndex(guildName)
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, _, _, token = GetGuildRosterInfo(i)
        local class = token and CLASS_INDEX[token]
        if class and IsPlayerKey(name) then
            Upsert(name, class, guild, nil)
        end
    end
end

local function ScanWho()
    for i = 1, (GetNumWhoResults()) do
        local name, guildName, _, _, _, _, token = GetWhoInfo(i)
        local class = token and CLASS_INDEX[token]
        if class and IsPlayerKey(name) then
            -- /who is authoritative: an empty guild really means none.
            local guild = 0
            if guildName and guildName ~= "" then
                guild = GuildToIndex(guildName)
            end
            Upsert(name, class, guild, nil)
        end
    end
end

local function ScanFriends()
    if not localizedToIndex then
        localizedToIndex = {}
        for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            localizedToIndex[localized] = CLASS_INDEX[token]
        end
        for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            localizedToIndex[localized] = CLASS_INDEX[token]
        end
    end
    for i = 1, (GetNumFriends()) do
        local name, _, className = GetFriendInfo(i)
        local class = className and localizedToIndex[className]
        if class and IsPlayerKey(name) then
            Upsert(name, class, nil, nil)
        end
    end
end

local function LearnGroup()
    local raidCount = GetNumRaidMembers()
    if raidCount > 0 then
        for i = 1, raidCount do
            UC.LearnUnit(RAID_UNITS[i])
        end
    else
        for i = 1, GetNumPartyMembers() do
            UC.LearnUnit(PARTY_UNITS[i])
        end
    end
end

function UC.MarkGroupDirty()
    if active then
        groupDirty = true
    end
end

local function ClearPlateMemo(plateData)
    plateData._friendlyHealthClass = nil
    plateData._headlineClass = nil
    plateData._pvpTitleName = nil
    plateData._subtitleText = nil
end

-- Engine tick, before the queues drain; two flag checks when idle.
function UC.Flush()
    if groupDirty then
        groupDirty = false
        LearnGroup()
    end
    if not hasPending then
        return
    end
    hasPending = false
    local healthCallback = NP.engine.Callbacks.OnUpdateHealth
    for _, plateData in pairs(NP.module.plates) do
        local name = plateData.plateName
        local plate = plateData.plate
        if name and pending[name] and plate and plate:IsShown() then
            ClearPlateMemo(plateData)
            NP.engine.QueuePlate(plateData, healthCallback)
        end
    end
    wipe(pending)
end

function UC.GetClass(name)
    local v = store and name and store.players[name]
    if type(v) ~= "number" then
        return nil
    end
    return CLASS_TOKENS[v % 16]
end

function UC.GetGuild(name)
    local v = store and name and store.players[name]
    if type(v) ~= "number" then
        return nil
    end
    local _, _, g = Unpack(v)
    return g > 0 and store.guilds[g] or nil
end

function UC.GetTitledName(name)
    local v = store and name and store.players[name]
    if type(v) ~= "number" then
        return nil
    end
    local _, t = Unpack(v)
    local pattern = t > 0 and store.titles[t]
    local p = pattern and find(pattern, "%s", 1, true)
    if not p then
        return nil
    end
    return sub(pattern, 1, p - 1) .. name .. sub(pattern, p + 2)
end

function UC.GetNPCTitle(name)
    return npcTitles and name and npcTitles[name] or nil
end

local function CompactLists()
    local players = store.players
    local usedGuild, usedTitle = {}, {}
    for _, v in pairs(players) do
        local _, t, g = Unpack(v)
        usedGuild[g] = true
        usedTitle[t] = true
    end
    local guildMap, guilds = {}, {}
    for i, guildName in ipairs(store.guilds) do
        if usedGuild[i] and type(guildName) == "string" then
            guilds[#guilds + 1] = guildName
            guildMap[i] = #guilds
        end
    end
    local titleMap, titles = {}, {}
    for i, pattern in ipairs(store.titles) do
        if usedTitle[i] and type(pattern) == "string" then
            titles[#titles + 1] = pattern
            titleMap[i] = #titles
        end
    end
    for name, v in pairs(players) do
        local c, t, g, d = Unpack(v)
        local ng = g > 0 and guildMap[g] or 0
        local nt = t > 0 and titleMap[t] or 0
        if ng ~= g or nt ~= t then
            players[name] = Pack(c, nt, ng, d)
        end
    end
    store.guilds, store.titles = guilds, titles
end

-- Once a day, out of combat: age out, cap, drop malformed rows, renumber the string lists.
function UC.Prune()
    if not store then
        return
    end
    if InCombatLockdown() then
        addon:After(PRUNE_DELAY, UC.Prune)
        return
    end
    today = floor(time() / 86400)
    local players = store.players
    local oldest = today - MAX_AGE_DAYS
    local perDay, count = {}, 0
    for name, v in pairs(players) do
        local day = -1
        if type(v) == "number" and v >= 0 and v == floor(v) then
            local class = v % 16
            if class >= 1 and class <= #CLASS_TOKENS then
                day = floor(v / DAY_MUL)
            end
        end
        if not IsPlayerKey(name) or day < oldest or day > today + 1 then
            players[name] = nil
        else
            count = count + 1
            perDay[day] = (perDay[day] or 0) + 1
        end
    end
    if count > MAX_PLAYERS then
        local excess, cutDay = count - MAX_PLAYERS, oldest
        -- Today's bucket always survives, even past the cap.
        while excess > 0 and cutDay < today do
            excess = excess - (perDay[cutDay] or 0)
            cutDay = cutDay + 1
        end
        for name, v in pairs(players) do
            if floor(v / DAY_MUL) < cutDay then
                players[name] = nil
            end
        end
    end
    CompactLists()
    store.pruneDay = today
    RebuildIndexes()
end

local function Bind()
    local db = addon.db
    if not (db and db.realm and db.global) then
        return false
    end
    today = floor(time() / 86400)
    local saved = db.realm.unitCache
    if type(saved) ~= "table" or saved.v ~= SCHEMA or type(saved.players) ~= "table"
        or type(saved.guilds) ~= "table" or type(saved.titles) ~= "table" then
        saved = NewStore()
        db.realm.unitCache = saved
    end
    local byLocale = db.global.unitCacheNPC
    if type(byLocale) ~= "table" then
        byLocale = {}
        db.global.unitCacheNPC = byLocale
    end
    local locale = GetLocale()
    if type(byLocale[locale]) ~= "table" then
        byLocale[locale] = {}
    end
    store = saved
    npcTitles = byLocale[locale]
    playerName = UnitName("player")
    RebuildIndexes()
    learner:RegisterEvent("PLAYER_LOGOUT")
    if store.pruneDay ~= today then
        addon:After(PRUNE_DELAY, UC.Prune)
    end
    return true
end

local function SetChat(on)
    if on == chatOn then return end
    chatOn = on
    for i = 1, #CHAT_EVENTS do
        if on then learner:RegisterEvent(CHAT_EVENTS[i]) else learner:UnregisterEvent(CHAT_EVENTS[i]) end
    end
end

local function SetRoster(on)
    if on == rosterOn then return end
    rosterOn = on
    if on then
        learner:RegisterEvent("GUILD_ROSTER_UPDATE")
        learner:RegisterEvent("WHO_LIST_UPDATE")
    else
        learner:UnregisterEvent("GUILD_ROSTER_UPDATE")
        learner:UnregisterEvent("WHO_LIST_UPDATE")
    end
end

local function SetFriends(on)
    if on == friendsOn then return end
    friendsOn = on
    if on then learner:RegisterEvent("FRIENDLIST_UPDATE") else learner:UnregisterEvent("FRIENDLIST_UPDATE") end
end

-- Called from E.SyncConfigSnapshot every 0.25 s: must stay cheap and only act on changes.
function UC.SyncConfig(cfg)
    local headlineAll = cfg.friendlyNameOnly == true and cfg.friendlyNameOnlyAll == true
    wantClass = cfg.friendlyClassColors == true or (headlineAll and cfg.friendlyNameOnlyClassColor == true)
    wantGuild = headlineAll and cfg.friendlyNameOnlyGuild == true
    wantTitle = headlineAll and cfg.friendlyNameOnlyTitle == true
    wantNPC = cfg.friendlyNameOnly == true and cfg.friendlyNPCNameOnly == true and cfg.friendlyNPCNameOnlyTitle == true
    persist = cfg.unitCacheRemember ~= false
    local wanted = wantClass or wantGuild or wantTitle or wantNPC
    if wanted and not store then
        Bind()
    end
    active = wanted and store ~= nil
    -- awesome_wotlk gives every plate a unit token, so nothing needs learning in the background.
    backgroundOn = active and C_NamePlate == nil
    NP.module._unitCacheCLEU = backgroundOn and wantClass
    SetChat(backgroundOn and wantClass)
    SetRoster(backgroundOn and (wantClass or wantGuild))
    SetFriends(backgroundOn and wantClass)
end

function UC.Stop()
    active, backgroundOn = false, false
    NP.module._unitCacheCLEU = false
    SetChat(false)
    SetRoster(false)
    SetFriends(false)
    wipe(seen)
    seenCount = 0
    wipe(npcChecked)
    wipe(guildlessAt)
    wipe(pending)
    hasPending, groupDirty = false, false
end

function UC.Forget()
    local db = addon.db
    if db and db.realm then
        db.realm.unitCache = nil
    end
    if db and db.global then
        db.global.unitCacheNPC = nil
    end
    wipe(seen)
    seenCount = 0
    wipe(npcChecked)
    wipe(guildlessAt)
    wipe(pending)
    hasPending = false
    lastRosterScan = nil
    store, npcTitles = nil, nil
    wipe(guildIndex)
    wipe(titleIndex)
    playerCount, npcCount = 0, 0
    if active then
        active = Bind()
    end
    for _, plateData in pairs(NP.module.plates) do
        ClearPlateMemo(plateData)
    end
    if NP.module.applied then
        NP.engine.QueueMass(NP.engine.Callbacks.OnUpdateHealth)
    end
end

function UC.GetStats()
    return {
        players = playerCount,
        npcs = npcCount,
        guilds = store and #store.guilds or 0,
        titles = store and #store.titles or 0,
        seenGUIDs = seenCount,
        active = active,
        persist = persist,
        background = backgroundOn,
    }
end

function UC.Describe(name)
    local v = store and name and store.players[name]
    if type(v) ~= "number" then
        local npc = UC.GetNPCTitle(name)
        return npc and ("NPC <" .. npc .. ">") or nil
    end
    local c, t, g, d = Unpack(v)
    return string.format("%s guild=%s title=%s seen=%d days ago",
        CLASS_TOKENS[c] or "?", g > 0 and store.guilds[g] or "-", t > 0 and store.titles[t] or "-", today - d)
end

local function OnLearnerEvent(_, event, ...)
    if event == "PLAYER_LOGOUT" then
        -- "Remember" off: nothing learned survives the session.
        if not persist then
            local db = addon.db
            if db and db.realm then db.realm.unitCache = nil end
            if db and db.global then db.global.unitCacheNPC = nil end
        end
        return
    end
    if not active then
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        ScanGuildRoster()
    elseif event == "WHO_LIST_UPDATE" then
        ScanWho()
    elseif event == "FRIENDLIST_UPDATE" then
        ScanFriends()
    else
        -- CHAT_MSG_*: arg2 is the author, arg12 the sender GUID.
        local guid = select(12, ...)
        if guid and guid ~= "" and seen[guid] == nil then
            NoteGUID(guid, (select(2, ...)), nil)
        end
    end
end

learner = CreateFrame("Frame")
learner:SetScript("OnEvent", OnLearnerEvent)
