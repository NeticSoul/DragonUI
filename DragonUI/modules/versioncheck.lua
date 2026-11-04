-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
--  VersionCheck — signed release announcements between players
-- ============================================================================

local addon = select(2, ...)
local L = addon.L

local VersionCheckModule = {}

if addon.RegisterModule then
    addon:RegisterModule("versioncheck", VersionCheckModule,
        addon.L["Version Check"],
        addon.L["Broadcast and detect addon version updates across group members"])
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- A fork announces its own 3.x releases on "DUI_Version"; a separate prefix keeps those out of our update notice.
local ADDON_PREFIX = "DragonUI_Version"

-- Written by scripts/versionsign/versionsign.py at release time; never edit by hand.
local SIGNED_VERSION = "3.0"
local SIGNED_KEY = 1
local SIGNED_SIGNATURE = "O2ffGFsAKu8ZbnhVSJ5pKFnVReSUUYaPXIMBaHQGKYIzjsZNt4RNYeHz651970UOSPDYi5kt7/Oy2lnEeg7TZtPWh2v2JmMTrFOAVTQAI8ouxUm6IIAcHaeKQUTjAQe9oJY8Q+j8cSu18BK+X7rfUDjMDCBViiax0nMtdFb7g/o"

local DOWNLOAD_URL = "https://github.com/NeticSoul/DragonUI/releases/latest"

local START_DELAY = 8
local ANNOUNCE_DELAY = 3
local FRIEND_ANNOUNCE_DELAY = 15
local CHANNEL_MIN_INTERVAL = 15
local REPLY_DELAY_MIN = 1
local REPLY_WINDOW = 10
local REPLY_SHAPE = 10
-- Players who know a newer release reply last: v3.0 prints the first reply it hears.
local KNOWN_NEWER_OFFSET = REPLY_WINDOW + REPLY_DELAY_MIN
local ANSWERED_COOLDOWN = 1800
local VERIFY_INTERVAL = 1
local VERIFY_QUEUE_MAX = 5
local VERIFY_SESSION_CAP = 30
local WHISPER_ERROR_WINDOW = 30
local INSTALL_CHECK_DELAY = 10
local COMBAT_SETTLE = 10
-- Past the login chatter of other addons, so the line isn't buried.
local NOTICE_DELAY = 20

local GROUP_CHANNELS = { PARTY = true, RAID = true, BATTLEGROUND = true }

-- ============================================================================
-- STATE
-- ============================================================================

local eventFrame
local playerName
local myVersion
local mySignedMessage
local started = false

local lastSent = {}
local pendingAnnounce = {}
local pendingReplies = {}
local answeredAt = {}
local groupChannel
local guildAnnounced = false
local friendsAnnounced = {}
local recentWhispers = {}

local genuineVersions = {}
local validSignatures = {}
local invalidSignatures = {}
local badSenders = {}
local verifyQueue = {}
local verifyBusy = false
local verificationsThisSession = 0
local bestVerified
local lastCombatEnd = 0

-- ============================================================================
-- VERSIONS AND MESSAGES
-- ============================================================================

-- Two digits per part keep VersionNumber() collision-free ("2.100" would equal "3.0").
local function IsValidVersion(v)
    if type(v) ~= "string" then return false end
    return v:match("^%d%d?%.%d%d?$") ~= nil or v:match("^%d%d?%.%d%d?%.%d%d?$") ~= nil
end

local function VersionNumber(v)
    local major, minor, patch = v:match("^(%d+)%.(%d+)%.?(%d*)$")
    return tonumber(major) * 10000 + tonumber(minor) * 100 + (tonumber(patch) or 0)
end

local function CompareVersions(a, b)
    local na, nb = VersionNumber(a), VersionNumber(b)
    if na == nb then return 0 end
    return na > nb and 1 or -1
end

local function SignatureKey(keyIndex, version, signature)
    return keyIndex .. ":" .. version .. ":" .. signature
end

-- Plain "3.0" is what v3.0 understands; "S<key>:<version>:<base64>" is the signed form it ignores.
local function ParseMessage(message)
    if type(message) ~= "string" then return nil end
    message = message:gsub("%s+", "")
    if IsValidVersion(message) then
        return "plain", message
    end
    local keyIndex, version, signature = message:match("^S(%d):([%d%.]+):([%w%+/]+)=*$")
    if keyIndex and IsValidVersion(version) then
        return "signed", version, signature, tonumber(keyIndex)
    end
    return nil
end

local function IsKnownGenuine(keyIndex, version, signature)
    if validSignatures[SignatureKey(keyIndex, version, signature)] then
        return true
    end
    return mySignedMessage ~= nil and keyIndex == SIGNED_KEY and version == SIGNED_VERSION
        and signature == SIGNED_SIGNATURE
end

-- ============================================================================
-- SENDING
-- ============================================================================

local function IsActive()
    return started and addon:IsModuleEnabled("versioncheck")
end

local function ChannelKey(channel, target)
    return target and (channel .. ":" .. target) or channel
end

local function CurrentGroupChannel()
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" then
        if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
            return "BATTLEGROUND"
        end
        return nil
    elseif instanceType == "arena" then
        return nil
    elseif GetRealNumRaidMembers() > 0 then
        return "RAID"
    elseif GetRealNumPartyMembers() > 0 then
        return "PARTY"
    end
    return nil
end

local function IsChannelUsable(channel)
    if channel == "GUILD" then
        return IsInGuild()
    elseif GROUP_CHANNELS[channel] then
        return CurrentGroupChannel() == channel
    end
    return channel == "WHISPER"
end

local function SendRaw(text, channel, target)
    if ChatThrottleLib then
        ChatThrottleLib:SendAddonMessage("BULK", ADDON_PREFIX, text, channel, target)
    else
        SendAddonMessage(ADDON_PREFIX, text, channel, target)
    end
end

local function MarkAnswered(pending)
    local now = GetTime()
    for sender in pairs(pending.triggers) do
        answeredAt[sender] = now
    end
end

local function SendVersion(channel, target)
    if target then
        recentWhispers[target] = GetTime()
    end
    SendRaw(myVersion, channel, target)
    if mySignedMessage then
        SendRaw(mySignedMessage, channel, target)
    end
    lastSent[ChannelKey(channel, target)] = GetTime()

    local pending = not target and pendingReplies[channel]
    if pending then
        pendingReplies[channel] = nil
        MarkAnswered(pending)
    end
end

-- Deferred, never dropped: a channel used less than CHANNEL_MIN_INTERVAL ago waits for its turn.
local function ScheduleAnnounce(channel, target, delay)
    local key = ChannelKey(channel, target)
    if pendingAnnounce[key] then return end
    local wait = delay
    if lastSent[key] then
        wait = math.max(wait, lastSent[key] + CHANNEL_MIN_INTERVAL - GetTime())
    end
    pendingAnnounce[key] = true
    addon:After(wait, function()
        pendingAnnounce[key] = nil
        if IsActive() and IsChannelUsable(channel) then
            SendVersion(channel, target)
        end
    end)
end

-- ============================================================================
-- ANNOUNCEMENTS (login, joining a guild or group, friends coming online)
-- ============================================================================

local function UpdateGroup()
    local channel = CurrentGroupChannel()
    if channel ~= groupChannel then
        groupChannel = channel
        if channel then
            ScheduleAnnounce(channel, nil, ANNOUNCE_DELAY)
        end
    end
end

local function UpdateGuild()
    if IsInGuild() then
        if not guildAnnounced then
            guildAnnounced = true
            ScheduleAnnounce("GUILD", nil, ANNOUNCE_DELAY)
        end
    else
        guildAnnounced = false
    end
end

-- A friend can show online before their addons load, hence the longer FRIEND_ANNOUNCE_DELAY.
local function UpdateFriends()
    local online = {}
    for i = 1, GetNumFriends() do
        local name, _, _, _, connected = GetFriendInfo(i)
        if name and connected then
            online[name] = true
            if not friendsAnnounced[name] then
                friendsAnnounced[name] = true
                ScheduleAnnounce("WHISPER", name, FRIEND_ANNOUNCE_DELAY)
            end
        end
    end
    for name in pairs(friendsAnnounced) do
        if not online[name] then
            friendsAnnounced[name] = nil
        end
    end
end

-- ============================================================================
-- REPLIES TO OUTDATED PLAYERS
-- ============================================================================

local nameSeed = 0

-- Exponential timers (Nonnenmacher-Biersack): about 1.3 replies however big the guild is.
local function ReplyDelay()
    local u = ((math.random(0, 9999) + nameSeed + math.floor(GetTime() * 1000)) % 10000) / 10000
    local delay = REPLY_DELAY_MIN + REPLY_WINDOW * math.log(1 + u * (math.exp(REPLY_SHAPE) - 1)) / REPLY_SHAPE
    return bestVerified and delay + KNOWN_NEWER_OFFSET or delay
end

local function FireReply(channel, pending)
    if pendingReplies[channel] ~= pending then return end
    pendingReplies[channel] = nil
    if IsActive() and IsChannelUsable(channel) then
        SendVersion(channel)
        MarkAnswered(pending)
    end
end

-- Confirmations older than the latest trigger don't count: that player may have missed them.
local function RequestReply(channel, sender, kind)
    local now = GetTime()
    if answeredAt[sender] and now - answeredAt[sender] < ANSWERED_COOLDOWN then return end

    if channel == "WHISPER" then
        answeredAt[sender] = now
        ScheduleAnnounce("WHISPER", sender, REPLY_DELAY_MIN)
        return
    end
    if channel ~= "GUILD" and not GROUP_CHANNELS[channel] then return end
    -- v3.0 announces on guild and group at once; one reply reaches that player.
    for otherChannel, other in pairs(pendingReplies) do
        if otherChannel ~= channel and other.triggers[sender] then return end
    end

    local pending = pendingReplies[channel]
    if not pending then
        pending = { triggers = {} }
        pendingReplies[channel] = pending
        addon:After(ReplyDelay(), function() FireReply(channel, pending) end)
    end
    pending.triggers[sender] = true
    pending.havePlain, pending.haveSigned = false, false
    if kind == "plain" then
        pending.needPlain = true
    else
        pending.needSigned = true
    end
end

local function NoteConfirmation(channel, kind)
    local pending = pendingReplies[channel]
    if not pending then return end
    if kind == "plain" then
        pending.havePlain = true
    else
        pending.haveSigned = true
    end
    if (not pending.needPlain or pending.havePlain) and (not pending.needSigned or pending.haveSigned) then
        pendingReplies[channel] = nil
        MarkAnswered(pending)
    end
end

-- ============================================================================
-- SIGNATURE VERIFICATION AND THE UPDATE NOTICE
-- ============================================================================

-- 0.5 s slack: summed timer steps can land just short of GetTime() and cost a second full wait.
local function IsCalm()
    return not InCombatLockdown() and GetTime() - lastCombatEnd >= COMBAT_SETTLE - 0.5
end

-- Waits for COMBAT_SETTLE calm seconds: Feign Death or Vanish mid-boss drops combat for a moment.
local function OutOfCombat(id, fn)
    local function retry() OutOfCombat(id, fn) end
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add(id, function()
            lastCombatEnd = GetTime()
            retry()
        end)
    elseif not IsCalm() then
        addon:After(COMBAT_SETTLE, retry)
    else
        fn()
    end
end

local function GetStore()
    local global = addon.db and addon.db.global
    if not global then return nil end
    global.versionCheck = global.versionCheck or {}
    return global.versionCheck
end

local function PrintNotice()
    local link = addon.ChatURL and addon:ChatURL(DOWNLOAD_URL, L["Download"]) or DOWNLOAD_URL
    addon:Print(string.format(L["New version available! %s"], link))
end

-- Once per session; a newer release seen later is saved and shown at the next login or reload.
local noticeScheduled, noticeShown = false, false
local function Notify()
    if noticeScheduled or noticeShown then return end
    noticeScheduled = true
    addon:After(NOTICE_DELAY, function()
        OutOfCombat("versioncheck_notice", function()
            noticeScheduled = false
            if noticeShown or not bestVerified or not addon:IsModuleEnabled("versioncheck") then return end
            noticeShown = true
            PrintNotice()
        end)
    end)
end

local function AcceptVerified(item)
    genuineVersions[item.version] = true
    if CompareVersions(item.version, myVersion) <= 0 then return end
    if bestVerified and CompareVersions(item.version, bestVerified.version) <= 0 then return end

    bestVerified = { version = item.version, key = item.keyIndex, signature = item.signature }
    local store = GetStore()
    if store then
        store.update = { version = item.version, key = item.keyIndex, signature = item.signature }
    end
    Notify()
end

local function RejectSignature(item)
    invalidSignatures[item.cacheKey] = true
    if item.sender then
        badSenders[item.sender] = true
        for i = #verifyQueue, 1, -1 do
            if verifyQueue[i].sender == item.sender then
                table.remove(verifyQueue, i)
            end
        end
    else
        local store = GetStore()
        if store and store.update and store.update.signature == item.signature then
            store.update = nil
        end
    end
end

local ProcessVerifyQueue

ProcessVerifyQueue = function()
    if verifyBusy or #verifyQueue == 0 then return end
    if not IsCalm() then
        OutOfCombat("versioncheck_verify", ProcessVerifyQueue)
        return
    end
    local item = table.remove(verifyQueue, 1)
    if not item then return end

    local RS = addon.ReleaseSignature
    if not RS or verificationsThisSession >= VERIFY_SESSION_CAP then
        wipe(verifyQueue)
        return
    end

    verifyBusy = true
    verificationsThisSession = verificationsThisSession + 1
    if RS.Verify(item.keyIndex, item.version, item.signature) then
        validSignatures[item.cacheKey] = true
        AcceptVerified(item)
    else
        RejectSignature(item)
    end
    addon:After(VERIFY_INTERVAL, function()
        verifyBusy = false
        ProcessVerifyQueue()
    end)
end

local function QueueVerify(keyIndex, version, signature, sender)
    if sender and badSenders[sender] then return end
    if not addon.ReleaseSignature or keyIndex < 1 or keyIndex > addon.ReleaseSignature.KEY_COUNT then return end
    if bestVerified and CompareVersions(version, bestVerified.version) <= 0 then return end

    local cacheKey = SignatureKey(keyIndex, version, signature)
    if validSignatures[cacheKey] or invalidSignatures[cacheKey] then return end
    for _, item in ipairs(verifyQueue) do
        if item.cacheKey == cacheKey then return end
    end
    if #verifyQueue >= VERIFY_QUEUE_MAX then return end

    verifyQueue[#verifyQueue + 1] = {
        cacheKey = cacheKey, keyIndex = keyIndex, version = version, signature = signature, sender = sender,
    }
    ProcessVerifyQueue()
end

local function LoadStoredUpdate()
    local store = GetStore()
    local update = store and store.update
    if type(update) ~= "table" then return end
    local version, keyIndex, signature = update.version, tonumber(update.key), update.signature
    local keyCount = addon.ReleaseSignature and addon.ReleaseSignature.KEY_COUNT or 0
    if not IsValidVersion(version) or not keyIndex or keyIndex < 1 or keyIndex > keyCount
        or type(signature) ~= "string" or CompareVersions(version, myVersion) <= 0
    then
        store.update = nil
        return
    end
    QueueVerify(keyIndex, version, signature, nil)
end

-- ============================================================================
-- INCOMING MESSAGES
-- ============================================================================

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX or not IsActive() or not sender or sender == playerName then return end

    local kind, version, signature, keyIndex = ParseMessage(message)
    if not kind then return end
    local order = CompareVersions(version, myVersion)

    if kind == "plain" then
        -- Plain messages never raise the notice: a fork that kept this prefix sends the same text.
        if order < 0 then
            RequestReply(channel, sender, "plain")
        elseif genuineVersions[version] then
            NoteConfirmation(channel, "plain")
        end
        return
    end

    if order < 0 then
        RequestReply(channel, sender, "signed")
        return
    end
    if order > 0 and not IsKnownGenuine(keyIndex, version, signature) then
        QueueVerify(keyIndex, version, signature, sender)
    end
    if IsKnownGenuine(keyIndex, version, signature) then
        NoteConfirmation(channel, "signed")
    end
end

-- Our addon whispers can bounce ("No player named ...", "... is ignoring you"); hide only those.
local function FilterWhisperErrors(_, _, message)
    if not next(recentWhispers) or not ERR_CHAT_PLAYER_NOT_FOUND_S then return false end
    local now = GetTime()
    for name, at in pairs(recentWhispers) do
        if now - at > WHISPER_ERROR_WINDOW then
            recentWhispers[name] = nil
        elseif message == string.format(ERR_CHAT_PLAYER_NOT_FOUND_S, name) then
            return true
        end
    end
    return false
end

local function FilterWhisperIgnored(_, _, _, sender)
    local at = sender and recentWhispers[sender]
    return at ~= nil and GetTime() - at <= WHISPER_ERROR_WINDOW
end

-- ============================================================================
-- INSTALL CHECKS (local, no network)
-- ============================================================================

-- A TOC/file mismatch means files were swapped while the game ran, or two downloads got mixed.
local function CheckInstall()
    local tocVersion = GetAddOnMetadata("DragonUI", "Version")
    local optionsVersion = GetAddOnMetadata("DragonUI_Options", "Version")
    if tocVersion and tocVersion ~= SIGNED_VERSION then
        addon:Print(L["Restart the game to finish updating DragonUI. If this message keeps showing, reinstall it."])
    elseif tocVersion and optionsVersion and optionsVersion ~= tocVersion then
        addon:Print(L["DragonUI and DragonUI_Options are from different versions. Install both from the same download."])
    end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

local function ResetNetworkState()
    started = false
    groupChannel = nil
    guildAnnounced = false
    wipe(friendsAnnounced)
    wipe(pendingReplies)
end

local function StartNetwork()
    if started or not myVersion or not IsLoggedIn() or not addon:IsModuleEnabled("versioncheck") then return end
    started = true
    LoadStoredUpdate()
    UpdateGuild()
    UpdateGroup()
    UpdateFriends()
end

local NETWORK_EVENTS = {
    "CHAT_MSG_ADDON", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE",
    "PLAYER_REGEN_ENABLED",
}

local function SetupEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "DragonUI_VersionCheck", UIParent)
        eventFrame:SetScript("OnEvent", function(_frame, event, ...)
            if event == "CHAT_MSG_ADDON" then
                OnAddonMessage(...)
            elseif event == "PLAYER_REGEN_ENABLED" then
                lastCombatEnd = GetTime()
            elseif not started then
                return
            elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
                UpdateGuild()
            elseif event == "FRIENDLIST_UPDATE" then
                UpdateFriends()
            else
                UpdateGroup()
            end
        end)
    end
    for _, event in ipairs(NETWORK_EVENTS) do
        eventFrame:RegisterEvent(event)
    end
end

function VersionCheckModule:Apply()
    SetupEvents()
    self.applied = true
    if IsLoggedIn() and myVersion then
        addon:After(1, StartNetwork)
    end
end

function VersionCheckModule:Restore()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    ResetNetworkState()
    self.applied = false
end

-- ============================================================================
-- BOOTSTRAP
-- ============================================================================

do
    local initFrame = CreateFrame("Frame", "DragonUI_VersionCheck_Init", UIParent)
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function()
        initFrame:UnregisterAllEvents()

        playerName = UnitName("player")
        for i = 1, #(playerName or "") do
            nameSeed = (nameSeed * 31 + playerName:byte(i)) % 10000
        end

        local tocVersion = GetAddOnMetadata("DragonUI", "Version")
        if IsValidVersion(SIGNED_VERSION) then
            myVersion = SIGNED_VERSION
            if SIGNED_SIGNATURE ~= "" then
                mySignedMessage = "S" .. SIGNED_KEY .. ":" .. SIGNED_VERSION .. ":" .. SIGNED_SIGNATURE
            end
        elseif IsValidVersion(tocVersion) then
            myVersion = tocVersion
        end
        if myVersion then
            genuineVersions[myVersion] = true
        end

        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterWhisperErrors)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_IGNORED", FilterWhisperIgnored)
        addon:After(INSTALL_CHECK_DELAY, function() OutOfCombat("versioncheck_install", CheckInstall) end)

        if addon:IsModuleEnabled("versioncheck") then
            DEFAULT_CHAT_FRAME:AddMessage("|cff1785d1DragonUI|r: Version " .. (myVersion or tocVersion or "?"))
            SetupEvents()
            addon:After(START_DELAY, StartNetwork)
        end
    end)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

addon.VersionCheck = {
    DOWNLOAD_URL = DOWNLOAD_URL,
    GetVersion = function() return myVersion end,
    GetUpdateVersion = function() return bestVerified and bestVerified.version or nil end,
    PrintUpdateNotice = function()
        if bestVerified then
            PrintNotice()
        end
    end,
}
