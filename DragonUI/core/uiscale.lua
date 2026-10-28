-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

-- Blizzard's Video slider stops at 0.64; UIParent:SetScale has no such floor.
local UIScale = { MIN = 0.4, MAX = 1 }
addon.UIScale = UIScale

local EPSILON = 0.001

local ownScale -- what DragonUI last put on UIParent; nil while the client owns the scale
local blizzardScale -- the client's own scale, put back when the option is turned off

local function Settings()
    return addon.db and addon.db.global
end

local function Clamp(value)
    return max(UIScale.MIN, min(UIScale.MAX, value))
end

function UIScale.IsEnabled()
    local settings = Settings()
    return settings and settings.uiScaleEnabled and true or false
end

function UIScale.Get()
    local settings = Settings()
    return Clamp(tonumber(settings and settings.uiScale) or UIParent:GetScale())
end

function UIScale.SetValue(value)
    local settings = Settings()
    value = tonumber(value)
    if settings and value then
        settings.uiScale = Clamp(value)
    end
end

-- The first use starts from the scale already on screen, so ticking the box alone changes nothing.
function UIScale.SetEnabled(enabled)
    local settings = Settings()
    if not settings then return end
    if enabled and not tonumber(settings.uiScale) then
        settings.uiScale = Clamp(floor(UIParent:GetScale() * 100 + 0.5) / 100)
    end
    settings.uiScaleEnabled = enabled and true or false
end

-- At scale 1 the UI is 768 units tall, whatever the resolution.
function UIScale.GetAutoScale()
    local height = tonumber((GetCVar("gxResolution") or ""):match("%d+x(%d+)"))
    if height and height > 0 then
        return Clamp(768 / height)
    end
end

local function Sync()
    local current = UIParent:GetScale()
    if ownScale and abs(current - ownScale) > EPSILON then
        blizzardScale = current
    end
    local wanted
    if UIScale.IsEnabled() then
        if not ownScale then
            blizzardScale = current
        end
        wanted = UIScale.Get()
        ownScale = wanted
    elseif ownScale then
        wanted = blizzardScale or current
        ownScale = nil
    else
        return
    end
    if abs(current - wanted) > EPSILON then
        UIParent:SetScale(wanted)
        addon.core:SendMessage("DRAGONUI_UI_SCALE_CHANGED")
    end
end

function UIScale.Apply()
    addon:SafeExecute("uiscale", "sync", Sync)
end

local pending = false

local function SyncNextFrame()
    pending = false
    UIScale.Apply()
end

-- The client puts its own scale back around these events, so look again a frame later.
local watcher = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "UPDATE_FLOATING_CHAT_WINDOWS" }) do
    watcher:RegisterEvent(event)
end
watcher:SetScript("OnEvent", function()
    if pending or not (ownScale or UIScale.IsEnabled()) then return end
    pending = true
    addon:After(0, SyncNextFrame)
end)
