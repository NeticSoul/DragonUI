-- ============================================================================
--  VersionCheck — Native DragonUI System
--  Cross-player version broadcast: detects when other players in group/raid
--  have a different addon version and notifies you if an update is available.
-- ============================================================================

local addon = select(2, ...)

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

-- Module state tracking
local VersionCheckModule = {
    initialized = false,
    applied = false,
    registeredEvents = {},
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("versioncheck", VersionCheckModule,
        (addon.L and addon.L["Version Check"]) or "Version Check",
        (addon.L and addon.L["Broadcast and detect addon version updates across group members"]) or "Broadcast and detect addon version updates across group members")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("versioncheck")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("versioncheck")
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
    ChatThrottleLib:SendAddonMessage("NORMAL", ADDON_PREFIX, CURRENT_VERSION, channel)
end


local function BroadcastVersion()
    if not IsModuleEnabled() then return end

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

-- Validate a version string: must be "major.minor" or "major.minor.patch".
-- Lua 5.1 does not support quantifiers on parenthesized groups, so we use
-- two explicit pattern matches instead of one with a capture group + ?.
local function IsValidVersion(v)
    if not v or v == "" then return false end
    -- "major.minor.patch" (e.g. 2.5.1)
    if string.match(v, "^%d+%.%d+%.%d+$") then
        return true
    end
    -- "major.minor" (e.g. 2.5)
    if string.match(v, "^%d+%.%d+$") then
        return true
    end
    return false
end

local function OnAddonMessage(prefix, message, _channel, _sender)
    if not IsModuleEnabled() then return end

    if prefix ~= ADDON_PREFIX then
        return
    end

    local incomingVersion = message and string.gsub(message, "%s+", "") or ""

    -- Security: only accept "major.minor" or "major.minor.patch" — untrusted input
    if not IsValidVersion(incomingVersion) then
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
            "|cff1785d1DragonUI|r: Update available! You have |cffFF6666v%s|r, latest seen is |cff66FF66v%s|r",
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
    if not IsModuleEnabled() then return end
    if eventFrame then return end

    eventFrame = CreateFrame("Frame", "DragonUI_VersionCheck", UIParent)
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

    eventFrame:SetScript("OnEvent", function(_frame, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        elseif event == "PARTY_MEMBERS_CHANGED"
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

-- ============================================================================
-- BOOTSTRAP
-- ============================================================================

do
    -- Bootstrap on PLAYER_LOGIN: capture the current version and start listening
    local initFrame = CreateFrame("Frame", "DragonUI_VersionCheck_Init", UIParent)
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function()
        initFrame:UnregisterAllEvents()

        CURRENT_VERSION = GetAddOnMetadata("DragonUI", "Version") or "0.0"
        highestVersionSeen = CURRENT_VERSION

        -- Print version on login (not on every PLAYER_ENTERING_WORLD)
        DEFAULT_CHAT_FRAME:AddMessage("|cff1785d1DragonUI|r: version " .. (CURRENT_VERSION or "?"))

        if IsModuleEnabled() then
            SetupEvents()

            -- Initial broadcast shortly after login
            addon:After(5, BroadcastVersion)

            addon:Debug("VersionCheck: native system initialized, version " .. CURRENT_VERSION)
        end
    end)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

addon.VersionCheck = {
    GetVersion = function() return CURRENT_VERSION end,
    GetHighestVersionSeen = function() return highestVersionSeen end,
}
