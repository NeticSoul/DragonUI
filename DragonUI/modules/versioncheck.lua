-- ============================================================================
--  VersionCheck Module for DragonUI
--  Cross-player version broadcast: detects when other players in group/raid
--  have a different addon version and notifies you if an update is available.
-- ============================================================================

local addon = select(2, ...)
local L = addon.L

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local VersionCheckModule = {
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("versioncheck", VersionCheckModule,
        (L and L["Version Check"]) or "Version Check",
        (L and L["Notifies when other players have a different addon version"]) or "Notifies when other players have a different addon version",
        {
            lifecycle = {
                apply   = "ApplyVersionCheckSystem",
                restore = "RestoreVersionCheckSystem",
                refresh = "RefreshVersionCheckSystem",
            },
        })
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Addon message prefix (max 16 chars for CHAT_MSG_ADDON)
local ADDON_PREFIX = "DUI_Version"

-- ============================================================================
-- STATE
-- ============================================================================

local eventFrame = nil
local hasNotifiedThisSession = false
local highestVersionSeen = nil
local lastBroadcastTime = 0
local BROADCAST_THROTTLE = 60 -- seconds between broadcasts
local CURRENT_VERSION = nil

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

-- Parse version string to comparable number.
-- Supports 1-, 2-, and 3-part versions:
--   "1.0.1" -> 1*10000 + 0*100 + 1   = 10001
--   "2.12"  -> 2*10000 + 12*100      = 21200
--   "2.9"   -> 2*10000 + 9*100       = 20900
--   "5"     -> 5*10000                = 50000
local function ParseVersion(versionStr)
    if not versionStr then
        return 0
    end
    local major, minor, patch = string.match(versionStr, "^(%d+)%.(%d+)%.(%d+)")
    if major and minor and patch then
        return tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch)
    end
    local major, minor = string.match(versionStr, "^(%d+)%.(%d+)")
    if major and minor then
        return tonumber(major) * 10000 + tonumber(minor) * 100
    end
    local single = string.match(versionStr, "^(%d+)")
    if single then
        return tonumber(single) * 10000
    end
    return 0
end

local function IsNewerVersion(v1, v2)
    return ParseVersion(v1) > ParseVersion(v2)
end

-- ============================================================================
-- COMMUNICATION
-- ============================================================================

local function SendVersion(channel)
    if not CURRENT_VERSION then return end
    SendAddonMessage(ADDON_PREFIX, CURRENT_VERSION, channel)
end

local function BroadcastVersion()
    local now = GetTime()
    if now - lastBroadcastTime < BROADCAST_THROTTLE then
        return
    end
    lastBroadcastTime = now

    if IsInGuild() then
        SendVersion("GUILD")
    end

    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0

    if numRaid > 0 then
        SendVersion("RAID")
    elseif numParty > 0 then
        SendVersion("PARTY")
    end

    if UnitInBattleground and UnitInBattleground("player") then
        SendVersion("BATTLEGROUND")
    end
end

-- ============================================================================
-- INCOMING MESSAGE HANDLER
-- ============================================================================

local function OnAddonMessage(prefix, message, _channel, _sender)
    if prefix ~= ADDON_PREFIX then
        return
    end
    if not message or message == "" then
        return
    end

    local incomingVersion = string.gsub(message, "%s+", "")

    -- Security: only accept "major.minor" or "major.minor.patch" — untrusted input
    if not string.match(incomingVersion, "^%d+%.%d+(%.%d+)?$") then
        return
    end

    -- Track highest version seen
    if not highestVersionSeen or IsNewerVersion(incomingVersion, highestVersionSeen) then
        highestVersionSeen = incomingVersion
    end

    -- Notify once per session if outdated
    if not hasNotifiedThisSession
        and CURRENT_VERSION
        and highestVersionSeen
        and IsNewerVersion(highestVersionSeen, CURRENT_VERSION)
    then
        hasNotifiedThisSession = true

        local msg = string.format(
            "|cffDFBA69DragonUI|r: Update available! You have |cffFF6666v%s|r, latest seen is |cff66FF66v%s|r",
            CURRENT_VERSION,
            highestVersionSeen
        )
        DEFAULT_CHAT_FRAME:AddMessage(msg)

        addon:Debug("VersionCheck: detected newer version v" .. highestVersionSeen)
    end
end

-- ============================================================================
-- EVENT SETUP
-- ============================================================================

local function SetupEvents()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame", "DragonUI_VersionCheck", UIParent)
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

    eventFrame:SetScript("OnEvent", function(_frame, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            addon:After(5, BroadcastVersion)
        elseif event == "GROUP_ROSTER_UPDATE"
            or event == "PARTY_MEMBERS_CHANGED"
            or event == "RAID_ROSTER_UPDATE"
        then
            BroadcastVersion()
        elseif event == "GUILD_ROSTER_UPDATE" then
            if IsInGuild() then
                SendVersion("GUILD")
            end
        end
    end)
end

local function TeardownEvents()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function addon.ApplyVersionCheckSystem()
    if VersionCheckModule.applied then return end

    -- Grab version from TOC
    CURRENT_VERSION = GetAddOnMetadata("DragonUI", "Version") or "0.0"
    highestVersionSeen = CURRENT_VERSION

    SetupEvents()
    VersionCheckModule.applied = true
    addon:Debug("VersionCheck: applied, version " .. CURRENT_VERSION)
end

function addon.RestoreVersionCheckSystem()
    if not VersionCheckModule.applied then return end

    TeardownEvents()
    hasNotifiedThisSession = false
    highestVersionSeen = nil
    CURRENT_VERSION = nil
    VersionCheckModule.applied = false
    addon:Debug("VersionCheck: restored")
end

function addon.RefreshVersionCheckSystem()
    local config = addon:GetModuleConfig("versioncheck")

    -- Respect master toggle if the config provides one; default to always on
    if config and config.enabled == false then
        addon.RestoreVersionCheckSystem()
    else
        addon.ApplyVersionCheckSystem()
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

addon.VersionCheck = {
    GetVersion = function() return CURRENT_VERSION end,
    GetHighestVersionSeen = function() return highestVersionSeen end,
}
