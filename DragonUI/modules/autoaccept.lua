-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Answers PARTY_INVITE through the popup's own accept when the inviter is a friend or guildie.

local DIALOG = "PARTY_INVITE"

local function GetConfig()
    local profile = addon.db and addon.db.profile
    return profile and profile.autoaccept
end

-- Names cannot contain "-", so anything from the first one on is the realm and is dropped.
local function baseName(name)
    if type(name) ~= "string" then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

local function IsFriend(name)
    for i = 1, GetNumFriends() do
        if baseName(GetFriendInfo(i)) == name then return true end
    end
    return false
end

local function IsGuildMember(name)
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        if baseName(GetGuildRosterInfo(i)) == name then return true end
    end
    return false
end

local function AcceptVisibleInvite()
    local info = StaticPopupDialogs[DIALOG]
    local popup = info and StaticPopup_FindVisible(DIALOG)
    if not popup then return false end
    -- Through the dialog: a bare AcceptGroup() gets declined by its OnHide.
    info.OnAccept(popup)
    popup:Hide()
    return true
end

local function OnPartyInvite(_, _, inviter)
    local cfg = GetConfig()
    local name = cfg and baseName(inviter)
    if not name then return end
    if not ((cfg.friends == true and IsFriend(name)) or (cfg.guild == true and IsGuildMember(name))) then return end

    -- Event order isn't guaranteed: UIParent may show the popup after this handler runs.
    if not AcceptVisibleInvite() then
        addon:After(0, AcceptVisibleInvite)
    end
end

addon.package:Subscribe(OnPartyInvite, "PARTY_INVITE_REQUEST")

-- Fills the caches the handler reads; the roster is not in them until it is asked for.
function addon.RefreshAutoAcceptCaches()
    local cfg = GetConfig()
    if not cfg then return end
    if cfg.friends == true then ShowFriends() end
    if cfg.guild == true and IsInGuild() then GuildRoster() end
end

addon.package:Subscribe(addon.RefreshAutoAcceptCaches, "PLAYER_LOGIN")
