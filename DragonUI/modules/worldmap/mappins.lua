-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

-- Dungeon, raid, graveyard and flight pins from the DBC tables; no client API lists them.

local ENTRANCE_SIZE = 28
local FLIGHT_SIZE = 18
local GRAVEYARD_W, GRAVEYARD_H = 12, 16
local TAXI_ATLAS = { Alliance = "map-taxinode-alliance", Horde = "map-taxinode-horde" }
-- Pairs closer than this share of their sizes get nudged apart, the way retail does.
local NUDGE_GAP = 0.9
local NUDGE_PASSES = 8
local EMPTY = {}
local GLOW = "Interface\\WorldMap\\UI-QuestPoi-IconGlow"
local FLASH_SECONDS, FLASH_PULSES, FLASH_GROW = 2.5, 3, 0.7
-- A pin asked for before its map has drawn stays pending, but not for a later, unrelated visit.
local FLASH_PATIENCE = 5

local pool = {}
local pendingFlash, pendingUntil

local function acquire(index)
    local pin = pool[index]
    if pin then return pin end

    pin = CreateFrame("Button", nil, WorldMapButton)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 2)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints(pin)
    pin.glow = pin:CreateTexture(nil, "OVERLAY")
    pin.glow:SetTexture(GLOW)
    pin.glow:SetBlendMode("ADD")
    pin.glow:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.glow:Hide()
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.name, 1, 1, 1)
        if self.kind then GameTooltip:AddLine(self.kind, 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pool[index] = pin
    return pin
end

local function styleEntrance(pin, entry)
    -- The client localizes the LFG dungeon; the generated name covers instances outside that list.
    pin.name = (entry.lfg and GetLFGDungeonInfo(entry.lfg)) or entry.name
    pin.kind = entry.raid and RAID or LFG_TYPE_DUNGEON
    pin.icon:set_atlas(entry.raid and "map-entrance-raid" or "map-entrance-dungeon")
    pin:SetSize(ENTRANCE_SIZE, ENTRANCE_SIZE)
end

local function styleGraveyard(pin)
    pin.name, pin.kind = L["Graveyard"], nil
    pin.icon:set_atlas("map-graveyard")
    pin:SetSize(GRAVEYARD_W, GRAVEYARD_H)
end

local function styleFlightPoint(pin, entry)
    pin.name, pin.kind = entry.name, L["Flight Master"]
    pin.icon:set_atlas(TAXI_ATLAS[entry.faction] or "map-taxinode-neutral")
    pin:SetSize(FLIGHT_SIZE, FLIGHT_SIZE)
end

-- Overlapping pins slide apart; pins on the exact same point (an instance's wings) fan out.
local function spread(items, width, height)
    for _ = 1, NUDGE_PASSES do
        local moved = false
        for i = 1, #items - 1 do
            local a = items[i]
            for j = i + 1, #items do
                local b = items[j]
                local minDist = (a.size + b.size) * 0.5 * NUDGE_GAP
                local dx, dy = b.px - a.px, b.py - a.py
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < minDist then
                    if dist < 0.5 then
                        local angle = (i + j) * 2.399
                        dx, dy, dist = math.cos(angle), math.sin(angle), 1
                    end
                    local push = (minDist - dist) / dist * 0.5
                    a.px, a.py = a.px - dx * push, a.py - dy * push
                    b.px, b.py = b.px + dx * push, b.py + dy * push
                    moved = true
                end
            end
        end
        if not moved then break end
    end
    for _, item in ipairs(items) do
        local half = item.size * 0.5
        item.px = math.max(half, math.min(width - half, item.px))
        item.py = math.max(half, math.min(height - half, item.py))
    end
end

-- The pool outlives the map, so a pin handed to something else has to drop the pulse it was
-- running; hidden, its OnUpdate only freezes, and resumes on whatever the pin becomes next.
local function stopFlash(pin)
    if not pin.flashTime then return end
    pin:SetScript("OnUpdate", nil)
    pin.flashTime = nil
    pin.glow:Hide()
    pin.icon:ClearAllPoints()
    pin.icon:SetAllPoints(pin)
end

-- Grows and glows on the beat, fading out as it goes, then hands the icon back to the pin's size.
local function flashUpdate(pin, elapsed)
    local time = (pin.flashTime or 0) + elapsed
    pin.flashTime = time
    if time >= FLASH_SECONDS then
        stopFlash(pin)
        return
    end
    local beat = math.sin(time / FLASH_SECONDS * FLASH_PULSES * math.pi * 2) * 0.5 + 0.5
    local fade = 1 - time / FLASH_SECONDS
    local size = pin:GetWidth() * (1 + FLASH_GROW * beat * fade)
    pin.icon:ClearAllPoints()
    pin.icon:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.icon:SetSize(size, size)
    pin.glow:SetSize(size * 2, size * 2)
    pin.glow:SetAlpha(beat * fade)
end

-- One name or a list of them, when the way in is a complex and any of its doors could be it.
local function asked(name)
    if type(pendingFlash) == "table" then
        for _, wanted in ipairs(pendingFlash) do
            if wanted == name then return true end
        end
        return false
    end
    return pendingFlash == name
end

-- Kept until the pin turns up: SetMapByID only draws the new map a frame later.
function WM.FlashEntrance(name)
    pendingFlash, pendingUntil = name, GetTime() + FLASH_PATIENCE
    WM.RefreshMapPins()
end

function WM.RefreshMapPins()
    if pendingFlash and GetTime() > pendingUntil then pendingFlash = nil end
    local flashed = false
    local count = 0
    local scale = WM.canvasScale
    if scale and WM.OnTerrainFloor() then
        local mapFile = GetMapInfo() or ""
        local config = WM:Config()
        -- Pins keep one screen size; positions are worked in those units, not the canvas's.
        local width, height = WorldMapButton:GetWidth() * scale, WorldMapButton:GetHeight() * scale
        local items = {}
        local function add(x, y, size, style, entry)
            items[#items + 1] = { px = x * width, py = y * height, size = size, style = style, entry = entry }
        end
        if config.entrances ~= false then
            for _, entry in ipairs(WM.Entrances[mapFile] or EMPTY) do add(entry.x, entry.y, ENTRANCE_SIZE, styleEntrance, entry) end
        end
        if config.flightPoints ~= false then
            local faction = UnitFactionGroup("player")
            for _, entry in ipairs(WM.FlightPoints[mapFile] or EMPTY) do
                if not entry.faction or entry.faction == faction then add(entry.x, entry.y, FLIGHT_SIZE, styleFlightPoint, entry) end
            end
        end
        if config.graveyards ~= false then
            for _, point in ipairs(WM.Graveyards[mapFile] or EMPTY) do add(point[1], point[2], GRAVEYARD_H, styleGraveyard) end
        end
        spread(items, width, height)

        -- Placed last to first so entrances, added first, draw on top of what they overlap.
        local pinScale = 1 / scale
        for index = #items, 1, -1 do
            local item = items[index]
            count = count + 1
            local pin = acquire(count)
            local previous = pin.name
            item.style(pin, item.entry)
            if pin.name ~= previous then stopFlash(pin) end
            pin:SetScale(pinScale)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", item.px, -item.py)
            pin:Show()
            if pendingFlash and asked(pin.name) then
                flashed = true
                pin.flashTime = 0
                pin.glow:Show()
                pin:SetScript("OnUpdate", flashUpdate)
            end
        end
    end
    for index = count + 1, #pool do
        stopFlash(pool[index])
        pool[index]:Hide()
    end
    -- Cleared only once the pass is done, so every door of a complex gets lit, not just the first.
    if flashed then pendingFlash = nil end
end

function WM.BuildMapPins()
    hooksecurefunc("WorldMapFrame_Update", WM.RefreshMapPins)
end
