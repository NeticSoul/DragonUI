-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local WM = addon.WorldMap

-- Retail dims the map while you travel. Everything that fades is a child, so the frame alone is set.

local INTERVAL = 0.1
local DEFAULT_ALPHA = 0.4

local driver
local since, current = 0, 1

local function target()
    local config = WM:Config()
    if config.fadeWhenMoving == false then return 1 end
    if (GetUnitSpeed("player") or 0) <= 0 then return 1 end
    if WM.CursorOverMap() then return 1 end
    return config.moveAlpha or DEFAULT_ALPHA
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

function WM.BuildFade()
    driver = CreateFrame("Frame", "DragonUIWorldMapFade", WorldMapFrame)
    driver:SetScript("OnUpdate", tick)
    driver:SetScript("OnHide", function() apply(1) end)
end
