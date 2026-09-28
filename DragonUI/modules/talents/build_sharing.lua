-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local format = string.format

local PREFIX = "DUI_Talents"
-- Interop marker shared with other DragonUI clients; never translated.
local TOKEN_TAG = "DragonUI Talents"
local LINK_HEAD = "player::duit:"
local MAX_QUEUED = 5

local comm = {}
LibStub("AceComm-3.0"):Embed(comm)

local postedCodes = {}   -- token name -> code, for this session
local answeredAt = {}    -- sender .. name -> time of the last answer
local askedAt = {}       -- owner -> { ticket, time } for requests still waiting
local seenAt = {}        -- sender .. text -> time first received
local waiting = {}       -- decoded shares waiting for a popup

local function me()
    return UnitName("player")
end

local function tokenName(text)
    local name = ns.Trim((text or ""):gsub("[%c|%[%]]", ""))
    return name
end

-- Posting and answering ---------------------------------------------------------------------------

function ns.PostLink(build)
    local name = tokenName(build.name)
    if name == "" then name = L["Imported"] end
    postedCodes[name] = ns.CodeFor(build)
    local editBox = ChatEdit_GetActiveWindow()
    if not editBox then
        ChatFrame_OpenChat("")
        editBox = ChatEdit_GetActiveWindow()
    end
    if editBox then editBox:Insert("[" .. TOKEN_TAG .. ": " .. name .. "]") end
end

function ns.ShareToGuild(build)
    comm:SendCommMessage(PREFIX, ns.CodeFor(build), "GUILD", nil, "BULK")
    ns.Notify(format(L["Build sent (%s). Only DragonUI players will see it."], GUILD), "ok")
end

local function answerRequest(sender, name)
    local code = postedCodes[name]
    if not code then return end
    local key = sender .. "\031" .. name
    local now = GetTime()
    if answeredAt[key] and now - answeredAt[key] < 3 then return end
    answeredAt[key] = now
    comm:SendCommMessage(PREFIX, code, "WHISPER", sender, "BULK")
end

local function askOwner(owner, name)
    comm:SendCommMessage(PREFIX, "?" .. name, "WHISPER", owner, "BULK")
    ns.Notify(format(L["Asking %s for the build…"], owner), "ask")
    local ticket = {}
    askedAt[owner] = { ticket = ticket, time = GetTime() }
    addon:After(10, function()
        local pending = askedAt[owner]
        if pending and pending.ticket == ticket then
            askedAt[owner] = nil
            ns.Notify(format(L["%s didn't answer — they may be offline or not running DragonUI."], owner), "error")
        end
    end)
end

-- Receiving ---------------------------------------------------------------------------------------

function ns.ShowNextShare()
    if #waiting == 0 or InCombatLockdown() or StaticPopup_Visible("DUI_TALENT_SHARED") then return end
    local entry = table.remove(waiting, 1)
    local build = entry.build
    local classLabel = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[build.class] or build.class
    local detail = build.name .. " |cff808080(" .. classLabel .. ")|r"
    if not StaticPopup_Show("DUI_TALENT_SHARED", entry.sender, detail, build) then
        table.insert(waiting, 1, entry)
    end
end

local function forgetOldSightings(now)
    for key, time in pairs(seenAt) do
        if now - time >= 60 then seenAt[key] = nil end
    end
end

local function receiveCode(text, sender)
    if not TM.applied or sender == me() then return end
    local now = GetTime()
    local pending = askedAt[sender]
    local requested = pending and now - pending.time <= 10
    askedAt[sender] = nil

    local key = sender .. "\031" .. text
    if not requested and seenAt[key] and now - seenAt[key] < 60 then return end
    forgetOldSightings(now)
    seenAt[key] = now

    if #waiting >= MAX_QUEUED then return end
    local build = TM.DecodeBuildCode(text)
    if not build then return end
    waiting[#waiting + 1] = { sender = sender, build = build }
    ns.ShowNextShare()
end

local function onComm(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
    if text:sub(1, 1) == "?" then
        if channel == "WHISPER" and TM.applied then answerRequest(sender, text:sub(2)) end
        return
    end
    receiveCode(text, sender)
end

ns.DefinePopup("DUI_TALENT_SHARED", L["%s shared a talent build with you:"] .. "\n\n%s", SAVE, DECLINE, {
    OnAccept = function(_, build)
        if build then ns.KeepBuild(build) end
    end,
    OnHide = function()
        addon:After(0.2, ns.ShowNextShare)
    end,
}, "dead")

-- Chat tokens become clickable links on DragonUI clients ------------------------------------------

local CHAT_EVENTS = "CHAT_MSG_SAY CHAT_MSG_YELL CHAT_MSG_GUILD CHAT_MSG_OFFICER CHAT_MSG_PARTY "
    .. "CHAT_MSG_PARTY_LEADER CHAT_MSG_RAID CHAT_MSG_RAID_LEADER CHAT_MSG_RAID_WARNING CHAT_MSG_BATTLEGROUND "
    .. "CHAT_MSG_BATTLEGROUND_LEADER CHAT_MSG_WHISPER CHAT_MSG_WHISPER_INFORM CHAT_MSG_CHANNEL"

local function linkify(message, owner)
    return (message:gsub("%[" .. TOKEN_TAG .. ": ([^%]]+)%]", function(raw)
        local name = tokenName(raw)
        if name == "" or not owner or owner == "" then return nil end
        return "|cff71d5ff|H" .. LINK_HEAD .. owner .. ":" .. name .. "|h[" .. TOKEN_TAG .. ": " .. name .. "]|h|r"
    end))
end

local function chatFilter(_, event, message, author, ...)
    if type(message) ~= "string" or not message:find(TOKEN_TAG, 1, true) then return false end
    -- On a whisper we sent, the author field holds the recipient; the build is ours.
    local owner = event == "CHAT_MSG_WHISPER_INFORM" and me() or author
    local rewritten = linkify(message, owner)
    if rewritten == message then return false end
    return false, rewritten, author, ...
end

-- Blizzard's SetItemRef does nothing with an empty player name, so the hook runs on a clean call.
local function onLinkClicked(link)
    if type(link) ~= "string" or link:sub(1, #LINK_HEAD) ~= LINK_HEAD then return end
    local owner, name = link:sub(#LINK_HEAD + 1):match("^([^:]*):(.+)$")
    if not owner or owner == "" or not name then return end
    if owner == me() then
        local code = postedCodes[name]
        if code then StaticPopup_Show("DUI_TALENT_EXPORT", nil, nil, code) end
        return
    end
    askOwner(owner, name)
end

function ns.InstallSharing()
    comm:RegisterComm(PREFIX, onComm)
    for event in CHAT_EVENTS:gmatch("%S+") do
        ChatFrame_AddMessageEventFilter(event, chatFilter)
    end
    hooksecurefunc("SetItemRef", onLinkClicked)
    ns.Listen("PLAYER_REGEN_ENABLED", function() ns.ShowNextShare() end)
end
