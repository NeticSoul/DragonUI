-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local WM = addon.WorldMap

-- The minimap's own arrow in place of the client's 3D one. WorldMapButton_OnUpdate re-anchors
-- WorldMapPlayer to the player every frame, so the facing is the only part left for us to drive.

local ARROW = addon._dir .. "Minimap\\poi-player"
local SIZE = 36

local arrow, driver, facing

-- Texture:SetRotation appears to depend on the texture's on-screen rect, unresolved before the map's
-- first draw: on first open the arrow came out as a stretched sliver of its art. Corners at radius 1
-- around the middle are SetRotation's own, so the art keeps the size SIZE was tuned at. Not
-- minimap.lua's RotateTexCoords: that one turns at radius sqrt(0.5) and draws the art larger.
local HALF = math.sqrt(0.5)

local function rotate(angle)
    local s, c = math.sin(angle), math.cos(angle)
    local p, q = HALF * (s + c), HALF * (s - c)
    arrow:SetTexCoord(0.5 + q, 0.5 - p, 0.5 - p, 0.5 - q, 0.5 + p, 0.5 + q, 0.5 - q, 0.5 + p)
end

-- Every frame, like the client turns the minimap's: throttling this reads as a stuttering arrow.
local function tick()
    local now = GetPlayerFacing() or 0
    if now == facing then return end
    facing = now
    rotate(now)
end

-- WorldMapPlayer hangs off WorldMapButton, which carries the canvas scale; retail keeps pins one size.
-- The level is re-asserted here because a size toggle re-levels the button and leaves its children put.
function WM.RefreshPlayerArrow()
    if not arrow then return end
    local scale = WM.canvasScale or 1
    arrow:SetSize(SIZE / scale, SIZE / scale)
    -- Where the client drew its own arrow: over the quest pins, which would bury it otherwise.
    WorldMapPlayer:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 100)
    -- A carried flag sits on its carrier, you included; under the arrow it would vanish.
    for i = 1, NUM_WORLDMAP_FLAGS do
        _G["WorldMapFlag" .. i]:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 101)
    end
end

function WM.BuildPlayerArrow()
    -- Both are created by the client, not FrameXML, so they are reached the way core.lua reaches them.
    local model, effect = _G["PlayerArrowFrame"], _G["PlayerArrowEffectFrame"]
    if not model then return end
    -- Alpha rather than Hide: ShowWorldMapArrowFrame(1) runs on every WorldMapButton_OnUpdate.
    model:SetAlpha(0)
    if effect then effect:SetAlpha(0) end

    arrow = WorldMapPlayer:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(ARROW)
    arrow:SetPoint("CENTER", WorldMapPlayer, "CENTER", 0, 0)

    driver = CreateFrame("Frame", nil, WorldMapPlayer)
    driver:SetAllPoints(WorldMapPlayer)
    driver:SetScript("OnUpdate", tick)
    WM.RefreshPlayerArrow()
end
