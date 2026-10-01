-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local WM = addon.WorldMap

-- Zone maps, out of combat: only while zoomed does the canvas leave Blizzard's own hierarchy.

local LEVELS = { 1, 1.5, 2, 2.5, 3 }
local UNIT_SIZE = 16
-- The blob, button and POI frames are anchored to the detail frame, so moving it pans them all.
local CANVAS = { WorldMapDetailFrame, WorldMapBlobFrame, WorldMapButton, WorldMapPOIFrame }

WM.zoom = 1

local clip, content
local level = 1
-- The view's top-left corner, as a fraction of the whole map.
local viewX, viewY = 0, 0
local mapKey
local homes = {}
local panning, moved, panX, panY, panViewX, panViewY, panScale
local cursorInside = true
local muted = {}

local function currentMapKey()
    return (GetCurrentMapAreaID() or 0) .. ":" .. (GetCurrentMapDungeonLevel() or 0)
end

-- SetParent re-levels the frame, which would reshuffle the map's layers.
local function moveTo(frame, parent)
    local frameLevel = frame:GetFrameLevel()
    frame:SetParent(parent)
    frame:SetFrameLevel(frameLevel)
end

local function clampView()
    local limit = 1 - 1 / WM.zoom
    viewX = math.max(0, math.min(viewX, limit))
    viewY = math.max(0, math.min(viewY, limit))
end

local function anchorDetail()
    WorldMapDetailFrame:SetPoint("TOPLEFT", content, "TOPLEFT", -viewX * WM.DETAIL_W, viewY * WM.DETAIL_H)
end

-- Size, not scale: Blizzard re-anchors these every frame in the button's own units.
local function sizeUnits(zoom)
    local size = UNIT_SIZE / zoom
    for i = 1, MAX_PARTY_MEMBERS do
        local unit = _G["WorldMapParty" .. i]
        if unit then unit:SetSize(size, size) end
    end
    for i = 1, MAX_RAID_MEMBERS do
        local unit = _G["WorldMapRaid" .. i]
        if unit then unit:SetSize(size, size) end
    end
end

local function mute(frame)
    if frame:IsMouseEnabled() then
        frame:EnableMouse(false)
        muted[frame] = true
    end
end

local function muteAll(...)
    for i = 1, select("#", ...) do mute((select(i, ...))) end
end

-- The clip hides pins past the view but they still take the mouse, over the world's own frames.
local function setMapMouse(inside)
    cursorInside = inside
    WorldMapButton:EnableMouseWheel(inside)
    if inside then
        for frame in pairs(muted) do
            frame:EnableMouse(true)
            muted[frame] = nil
        end
    else
        mute(WorldMapButton)
        muteAll(WorldMapButton:GetChildren())
        muteAll(WorldMapPOIFrame:GetChildren())
    end
end

function WM.CursorInView()
    return WM.zoom == 1 or cursorInside
end

-- ============================================================================
-- ZOOM
-- ============================================================================

-- Called by layoutCanvas, which has already scaled the canvas by WM.zoom.
function WM.LayoutZoom()
    if WM.zoom == 1 then return false end
    clip:SetSize(WM.canvasW, WM.canvasH)
    content:SetSize(WM.canvasW, WM.canvasH)
    clampView()
    anchorDetail()
    sizeUnits(WM.zoom)
    return true
end

local function adopt()
    mapKey = currentMapKey()
    clip:Show()
    for _, frame in ipairs(CANVAS) do
        homes[frame] = frame:GetParent()
        moveTo(frame, content)
    end
    -- Pinned to the view, outside the scroll child: in it, each change of its text nudged the pins.
    moveTo(WorldMapFrameAreaFrame, WorldMapFrame)
    WorldMapFrameAreaFrame:ClearAllPoints()
    WorldMapFrameAreaFrame:SetPoint("TOP", clip, "TOP", 0, -10)
    clip:RegisterEvent("WORLD_MAP_UPDATE")
    clip:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local function unzoom()
    if WM.zoom == 1 then return end
    panning = nil
    setMapMouse(true)
    WM.zoom, level, viewX, viewY = 1, 1, 0, 0
    clip:UnregisterAllEvents()
    for frame, home in pairs(homes) do
        moveTo(frame, home)
        homes[frame] = nil
    end
    moveTo(WorldMapFrameAreaFrame, WorldMapButton)
    WorldMapFrameAreaFrame:ClearAllPoints()
    WorldMapFrameAreaFrame:SetPoint("TOP", WorldMapButton, "TOP", 0, -10)
    sizeUnits(1)
    clip:Hide()
    WM.Layout(true)
end

function WM.ResetZoom()
    if WM.zoom ~= 1 then addon:SafeExecute("worldmap", "unzoom", unzoom) end
end

-- Keeps the map point under the cursor where it is.
local function zoomTo(index)
    local mapX, mapY = WM.CursorMapPoint()
    if not mapX then return end
    local old, new = LEVELS[level], LEVELS[index]
    if new == 1 then
        WM.ResetZoom()
        return
    end
    if old == 1 then adopt() end
    viewX = mapX - (mapX - viewX) * old / new
    viewY = mapY - (mapY - viewY) * old / new
    level = index
    WM.zoom = new
    WM.Layout(true)
end

local function onWheel(_, delta)
    if InCombatLockdown() or not WM.IsWindowed() or GetCurrentMapZone() == 0 then return end
    local index = math.max(1, math.min(#LEVELS, level + (delta > 0 and 1 or -1)))
    if index ~= level then zoomTo(index) end
end

-- ============================================================================
-- PAN
-- ============================================================================

-- A left click does nothing on a zone map, so Blizzard's mouse-up after a drag is harmless.
local function onMouseDown(_, button)
    if button ~= "LeftButton" or WM.zoom == 1 or InCombatLockdown() then return end
    panX, panY = GetCursorPosition()
    panViewX, panViewY = viewX, viewY
    panScale = WorldMapDetailFrame:GetEffectiveScale()
    panning, moved = true, false
end

-- Blizzard recomputes the blob hit box when this is nil.
local function resetBlobHitBox()
    WorldMapBlobFrame.xRatio = nil
end

-- Never queued, so no drag outlives the start of combat.
local function stopPan()
    if not panning then return end
    panning = nil
    if moved then addon:SafeExecute("worldmap", "panblobs", resetBlobHitBox) end
end

local function onMouseUp(_, button)
    if button == "LeftButton" then stopPan() end
end

local function updatePan()
    if not IsMouseButtonDown("LeftButton") then
        stopPan()
        return
    end
    local x, y = GetCursorPosition()
    local oldX, oldY = viewX, viewY
    viewX = panViewX - (x - panX) / panScale / WM.DETAIL_W
    viewY = panViewY + (y - panY) / panScale / WM.DETAIL_H
    clampView()
    if viewX == oldX and viewY == oldY then return end
    moved = true
    anchorDetail()
    -- Blobs are rasterised where they were drawn and would stay behind.
    if WM.RedrawBlobs then WM.RedrawBlobs() end
end

local function onUpdate()
    if InCombatLockdown() then
        stopPan()
        return
    end
    if panning then
        updatePan()
        return
    end
    local inside = not not clip:IsMouseOver()
    if inside ~= cursorInside then setMapMouse(inside) end
end

local function onEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        stopPan()
        WM.ResetZoom()
    elseif currentMapKey() ~= mapKey then
        WM.ResetZoom()
    end
end

function WM.BuildZoom()
    clip = CreateFrame("ScrollFrame", nil, WorldMapFrame)
    clip:SetFrameLevel(WorldMapFrame:GetFrameLevel())
    clip:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", WM.FRAME_X + WM.INSET_L, -(WM.FRAME_Y + WM.SPACER_H))
    clip:Hide()
    content = CreateFrame("Frame", nil, clip)
    content:SetSize(1, 1)
    clip:SetScrollChild(content)
    clip:SetScript("OnUpdate", onUpdate)
    clip:SetScript("OnEvent", onEvent)
    -- Fires when the map closes too, since the clip is only shown while zoomed.
    clip:SetScript("OnHide", WM.ResetZoom)

    WorldMapButton:EnableMouseWheel(true)
    WorldMapButton:HookScript("OnMouseWheel", onWheel)
    WorldMapButton:HookScript("OnMouseDown", onMouseDown)
    WorldMapButton:HookScript("OnMouseUp", onMouseUp)
end
