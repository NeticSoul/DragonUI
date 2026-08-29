-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local WM = addon.WorldMap

-- Undiscovered subzones dimmed under the client's overlays; fogdata.lua lists every one it ships.

local TINT = { 0.55, 0.55, 0.55, 0.6 }
local TILE = 256

local pool = {}

local function acquire(index)
    local tex = pool[index]
    if not tex then
        tex = WorldMapDetailFrame:CreateTexture(nil, "BORDER")
        tex:SetVertexColor(TINT[1], TINT[2], TINT[3])
        tex:SetAlpha(TINT[4])
        pool[index] = tex
    end
    return tex
end

-- width + height * 2^10 + x * 2^20 + y * 2^30, the packing the generator writes.
local function unpackOverlay(id)
    local width = id % 1024
    local height = math.floor(id / 1024) % 1024
    local x = math.floor(id / 1048576) % 1024
    local y = math.floor(id / 1073741824)
    return width, height, x, y
end

-- The last row and column of a grid are cropped, with their files at the next power of two.
local function fileSize(pixels)
    local size = 16
    while size < pixels do size = size * 2 end
    return size
end

local function drawOverlay(prefix, name, id, count)
    local width, height, offsetX, offsetY = unpackOverlay(id)
    local cols, rows = math.ceil(width / TILE), math.ceil(height / TILE)
    for row = 1, rows do
        local pixelH = row < rows and TILE or (height % TILE ~= 0 and height % TILE or TILE)
        for col = 1, cols do
            local pixelW = col < cols and TILE or (width % TILE ~= 0 and width % TILE or TILE)
            count = count + 1
            local tex = acquire(count)
            tex:SetSize(pixelW, pixelH)
            tex:SetTexCoord(0, pixelW / fileSize(pixelW), 0, pixelH / fileSize(pixelH))
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", offsetX + TILE * (col - 1), -(offsetY + TILE * (row - 1)))
            -- A file the client cannot find leaves the previous art in place; blank it first.
            tex:SetTexture(nil)
            tex:SetTexture(prefix .. name .. ((row - 1) * cols + col))
            tex:Show()
        end
    end
    return count
end

function WM.RefreshFog()
    local count = 0
    local mapFile = GetMapInfo()
    local overlays = WM:Config().fog ~= false and mapFile and WM.OnTerrainFloor() and WM.FogData[mapFile]
    if overlays then
        local prefix = "Interface\\WorldMap\\" .. mapFile .. "\\"
        for name, id in pairs(overlays) do
            count = drawOverlay(prefix, name, id, count)
        end
    end
    for index = count + 1, #pool do pool[index]:Hide() end
end

function WM.BuildFog()
    hooksecurefunc("WorldMapFrame_Update", WM.RefreshFog)
end
