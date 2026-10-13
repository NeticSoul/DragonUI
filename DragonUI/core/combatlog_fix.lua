-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local GetTime = GetTime

-- 3.3.5a's combat log can stop firing mid-session; clear it only once the player's casts go unlogged.

local PROBE_WINDOW = 2
local STRIKES_TO_CLEAR = 2
local CLEAR_COOLDOWN = 30

local lastLogEvent = 0
local probeStartedAt = nil
local strikes = 0
local lastClearAt = nil

local function CheckProbe()
    local startedAt = probeStartedAt
    probeStartedAt = nil
    if not startedAt then
        return
    end
    if lastLogEvent >= startedAt then
        strikes = 0
        return
    end
    strikes = strikes + 1
    local now = GetTime()
    if strikes >= STRIKES_TO_CLEAR and (not lastClearAt or now - lastClearAt >= CLEAR_COOLDOWN) then
        strikes = 0
        lastClearAt = now
        CombatLogClearEntries()
        if addon.Debug then
            addon:Debug("Combat log had stopped; cleared it")
        end
    end
end

local logWatcher = CreateFrame("Frame")
logWatcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
logWatcher:SetScript("OnEvent", function()
    lastLogEvent = GetTime()
end)

local castWatcher = CreateFrame("Frame")
castWatcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castWatcher:SetScript("OnEvent", function(_, _, unit)
    if unit == "player" and not probeStartedAt then
        -- A landed cast normally logs a line; two silent windows in a row mean the log is stuck.
        probeStartedAt = GetTime()
        addon:After(PROBE_WINDOW, CheckProbe)
    end
end)
