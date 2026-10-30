-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local WM = addon.WorldMap
local L = addon.L

-- Retail dims the map while you travel. Everything that fades is a child, so the frame alone is set.

local INTERVAL = 0.1
local DEFAULT_ALPHA = 0.4
local NOTIFY_DELAY = 0.2

local driver
local since, current = 0, 1
local notifyQueued

local function fading()
    return WM:Config().fadeWhenMoving ~= false
end

local function target()
    if not fading() then return 1 end
    if (GetUnitSpeed("player") or 0) <= 0 then return 1 end
    if WM.CursorOverMap() then return 1 end
    return WM:Config().moveAlpha or DEFAULT_ALPHA
end

-- SetAlpha is not a protected method, so this is safe to run with the map open mid-fight.
local function apply(alpha)
    if alpha == current then return end
    current = alpha
    WorldMapFrame:SetAlpha(alpha)
end

local function tick(self, elapsed)
    since = since + elapsed
    if since < INTERVAL then return end
    since = 0
    apply(target())
end

function WM.RefreshFade()
    if not driver then return end
    since = INTERVAL
    apply(target())
end

local function notifyOptions()
    addon.core:SendMessage("DRAGONUI_WINDOW_SETTING_CHANGED", "worldmap")
end

-- Options redraws a whole tab for this, so a drag only tells it a few times a second.
local function queueNotify()
    if notifyQueued then return end
    notifyQueued = true
    addon:After(NOTIFY_DELAY, function()
        notifyQueued = nil
        notifyOptions()
    end)
end

local function percent(value)
    return math.floor(value * 100 + 0.5) .. "%"
end

-- The quest log cog's copy of the options.
function WM.AddFadeEntries(entries)
    entries[#entries + 1] = {
        text = L["Fade Map While Moving"],
        checked = fading,
        keepShown = true,
        func = function()
            WM:Config().fadeWhenMoving = not fading()
            WM.RefreshFade()
            notifyOptions()
        end,
    }
    entries[#entries + 1] = {
        text = L["Moving Map Alpha"],
        hidden = function() return not fading() end,
        slider = {
            min = 0.1, max = 1, step = 0.05, format = percent,
            get = function() return WM:Config().moveAlpha or DEFAULT_ALPHA end,
            set = function(value)
                WM:Config().moveAlpha = value
                queueNotify()
            end,
        },
    }
end

function WM.BuildFade()
    driver = CreateFrame("Frame", "DragonUIWorldMapFade", WorldMapFrame)
    driver:SetScript("OnUpdate", tick)
    driver:SetScript("OnHide", function() apply(1) end)
end
