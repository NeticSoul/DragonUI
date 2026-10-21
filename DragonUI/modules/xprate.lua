-- Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

-- A personal XP rate the server keeps for each character (mod-individual-xp). The XP & Rep Bars
-- settings and the XP bar's right-click menu change it. The module and this file talk with addon
-- whispers to the player:
--
--   server -> client   R:<rate>:<max>:<min>:<rampStart>:<rampFullLevel>:<off>
--                      the chosen rate and the range it may take; off is 1 while XP gain is off
--   client -> server   HELLO          send R again
--                      SET:<rate>     choose a rate
--                      DEFAULT        go back to the realm's default rate
--                      ON / OFF       turn XP gain on or off
--
-- A rate above rampStart grows with the level: rampStart at level 1, the full rate from
-- rampFullLevel on, counting the part of the current level already done. The server pays XP
-- that way; Effective() works out the same number for display.
--
-- Until an R arrives the realm offers nothing (it may not run the module) and the setting stays
-- greyed out.

local PREFIX = "DUI_XPRATE"
local SETTLE = 0.4         -- seconds a choice has to rest before it is sent (slider drags)

local XR = {}
addon.XpRate = XR

local state                -- nil until the server answers
local listeners = {}
local pending              -- the message waiting for the slider to settle
local pendingAt = 0

local function changed()
    for _, fn in ipairs(listeners) do fn() end
end

-- `fn` runs whenever the rate, its range or XP gain changes, and as the level grows while ramping.
function XR.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function XR.Available()
    return state ~= nil
end

-- { rate, max, min, rampStart, rampLevel, off } or nil
function XR.State()
    return state
end

function XR.IsRamping()
    return state and state.rampLevel > 1 and state.rate > state.rampStart
        and UnitLevel("player") < state.rampLevel or false
end

-- The rate the server pays at right now.
function XR.Effective()
    if not state then return nil end
    if not XR.IsRamping() then return state.rate end
    local progress = UnitLevel("player") - 1
    local maxXP = UnitXPMax("player")
    if maxXP and maxXP > 0 then
        progress = progress + math.min(1, UnitXP("player") / maxXP)
    end
    local t = math.min(1, progress / (state.rampLevel - 1))
    return state.rampStart + (state.rate - state.rampStart) * t
end

-- 1.5 -> "1.5x", 2 -> "2x", 2.894 -> "2.9x"
function XR.Format(rate)
    local text = format("%.1f", rate):gsub("%.0$", "")
    return text .. "x"
end

-- The rates the right-click menu offers: half steps from 0.5 up to the realm's maximum.
function XR.Steps()
    local steps = {}
    if not state then return steps end
    local r = math.max(0.5, math.ceil(state.min * 2) / 2)
    while r <= state.max + 0.001 do
        steps[#steps + 1] = r
        r = r + 0.5
    end
    if #steps == 0 or steps[#steps] < state.max - 0.001 then
        steps[#steps + 1] = state.max
    end
    return steps
end

-- Messages go out one at a time, GAP apart: the server doesn't make a change that comes within
-- 0.1 s of the last one (it only answers with R, which puts the setting back), and server lag
-- can bunch messages up.
local GAP = 0.3
local queue = {}
local lastSent = -GAP

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
    local now = GetTime()
    if pending and now >= pendingAt then
        queue[#queue + 1] = pending
        pending = nil
    end
    if queue[1] and now - lastSent >= GAP then
        SendAddonMessage(PREFIX, table.remove(queue, 1), "WHISPER", UnitName("player"))
        lastSent = now
    end
    if not pending and not queue[1] then self:Hide() end
end)

local function send(msg)
    queue[#queue + 1] = msg
    driver:Show()
end

-- Sends a choice still settling right away, ahead of whatever is sent next.
local function flush()
    if pending then
        queue[#queue + 1] = pending
        pending = nil
    end
end

local function sendSoon(msg)
    pending, pendingAt = msg, GetTime() + SETTLE
    driver:Show()
end

-- The rate of the latest SET not yet sent, if any.
local function unsentRate()
    local msg = pending
    for i = #queue, 1, -1 do
        if msg then break end
        if queue[i]:match("^SET:") then msg = queue[i] end
    end
    return msg and tonumber(msg:match("^SET:(.+)$"))
end

-- The setting follows at once; the server's R puts it back if it turns the rate down.
function XR.Set(rate)
    if not state or state.off then return end
    rate = math.max(state.min, math.min(state.max, rate))
    if math.abs(rate - state.rate) < 0.001 then return end
    state.rate = rate
    sendSoon(format("SET:%.2f", rate))
    changed()
end

function XR.UseDefault()
    if not state or state.off then return end
    pending = nil
    for i = #queue, 1, -1 do
        if queue[i]:match("^SET:") then table.remove(queue, i) end
    end
    send("DEFAULT")
end

function XR.SetGain(on)
    if not state then return end
    flush() -- the server ignores SET while XP gain is off
    state.off = not on
    send(on and "ON" or "OFF")
    changed()
end

local wasRamping = false

local function onMessage(msg)
    local rate, max, min, rampStart, rampLevel, off =
        msg:match("^R:([%d%.]+):([%d%.]+):([%d%.]+):([%d%.]+):(%d+):(%d)$")
    if not rate then return end
    state = {
        rate = tonumber(rate), max = tonumber(max), min = tonumber(min),
        rampStart = tonumber(rampStart), rampLevel = tonumber(rampLevel), off = off == "1",
    }
    -- A choice not sent yet wins over an answer to an older one.
    state.rate = unsentRate() or state.rate
    wasRamping = XR.IsRamping()
    changed()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("UNIT_LEVEL")
events:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "PLAYER_ENTERING_WORLD" then
        -- At login the server sends R once the stored rate has loaded; after a /reload it has to
        -- be asked.
        events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        send("HELLO")
    elseif event == "CHAT_MSG_ADDON" then
        if prefix == PREFIX and channel == "WHISPER" and sender == UnitName("player") then
            onMessage(msg)
        end
    elseif event == "UNIT_LEVEL" and prefix ~= "player" then
        return
    elseif state then
        -- While ramping the rate grows with every bit of XP; reaching the ramp's level ends it.
        local ramping = XR.IsRamping()
        if ramping or ramping ~= wasRamping then
            wasRamping = ramping
            changed()
        end
    end
end)

-- ============================================================================
-- XP BAR: tooltip line and right-click menu
-- ============================================================================

-- Adds the rate to an XP bar tooltip that is being built.
function XR.AddTooltipLines(tooltip)
    if not state then return end
    tooltip:AddLine(" ")
    if state.off then
        tooltip:AddDoubleLine(L["XP rate: "], "|cFFFF6060" .. L["XP gain is off"] .. "|r")
    elseif XR.IsRamping() then
        tooltip:AddDoubleLine(L["XP rate: "], format("|cFFFFFFFF%s|r " .. L["(%s now)"],
            XR.Format(state.rate), XR.Format(XR.Effective())))
        tooltip:AddLine(format(L["Grows with your level until level %d."], state.rampLevel), 0.6, 0.6, 0.6, true)
    else
        tooltip:AddDoubleLine(L["XP rate: "], "|cFFFFFFFF" .. XR.Format(state.rate) .. "|r")
    end
    tooltip:AddLine(L["Right-click to change your XP rate."], 0.6, 0.6, 0.6)
end

local menuFrame

local function buildMenu()
    local menu = {
        { text = L["XP Rate"], isTitle = true, notCheckable = true },
    }
    for _, rate in ipairs(XR.Steps()) do
        menu[#menu + 1] = {
            text = XR.Format(rate),
            checked = math.abs(rate - state.rate) < 0.001,
            disabled = state.off,
            func = function() XR.Set(rate) end,
        }
    end
    menu[#menu + 1] = {
        text = L["Realm default"], notCheckable = true, disabled = state.off,
        func = function() XR.UseDefault() end,
    }
    menu[#menu + 1] = {
        text = L["Gain experience"], checked = not state.off,
        func = function() XR.SetGain(state.off) end,
    }
    menu[#menu + 1] = {
        text = L["More settings..."], notCheckable = true,
        func = function()
            if addon.OptionsPanel and addon.OptionsPanel:IsOpen() then
                addon.OptionsPanel:SelectTab("xprepbars")
            elseif addon.ToggleOptionsUI then
                addon:ToggleOptionsUI("xprepbars")
            end
        end,
    }
    return menu
end

-- Opens the rate menu at the cursor. False when the realm offers no rate.
function XR.ShowMenu()
    if not state then return false end
    menuFrame = menuFrame or CreateFrame("Frame", "DragonUI_XpRateMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(buildMenu(), menuFrame, "cursor", 0, 0, "MENU")
    return true
end
