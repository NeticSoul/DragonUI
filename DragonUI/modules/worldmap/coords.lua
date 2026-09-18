-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

-- Retail's cursor and player readouts, in the canvas corner the shadow art already darkens.

local INTERVAL = 0.05
local FONT_SIZE = 11
local EDGE_X, EDGE_Y, LINE_GAP = 12, 12, 2
local FORMAT = "%s: %.1f, %.1f"

local frame, cursorText, playerText
local since = 0

-- GetCursorPosition is in raw screen pixels, and the canvas carries a scale of its own.
local function cursorPoint()
    local detail = WorldMapDetailFrame
    local left, top = detail:GetLeft(), detail:GetTop()
    if not (left and top) then return end
    local scale = detail:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x = (x / scale - left) / detail:GetWidth()
    y = (top - y / scale) / detail:GetHeight()
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    return x, y
end

local function tick(self, elapsed)
    since = since + elapsed
    if since < INTERVAL then return end
    since = 0

    local cx, cy = cursorPoint()
    if cx then
        cursorText:SetFormattedText(FORMAT, L["Cursor"], cx * 100, cy * 100)
    else
        cursorText:SetText("")
    end

    local px, py = GetPlayerMapPosition("player")
    if px and (px ~= 0 or py ~= 0) then
        playerText:SetFormattedText(FORMAT, PLAYER, px * 100, py * 100)
    else
        playerText:SetText("")
    end
end

function WM.RefreshCoords()
    if not frame then return end
    if WM:Config().coordinates ~= false then
        since = INTERVAL
        frame:Show()
    else
        frame:Hide()
    end
end

local function styleLine(text)
    text:SetFont(addon.Fonts.PRIMARY, FONT_SIZE)
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
end

function WM.BuildCoords()
    if not WM.border then return end
    frame = CreateFrame("Frame", "DragonUIWorldMapCoords", WM.border)
    frame:SetAllPoints(WM.border)
    frame:SetFrameLevel(WM.border:GetFrameLevel() + 6)
    frame:EnableMouse(false)

    playerText = frame:CreateFontString(nil, "OVERLAY")
    playerText:SetPoint("BOTTOMLEFT", WM.border, "BOTTOMLEFT", EDGE_X, EDGE_Y)
    styleLine(playerText)

    cursorText = frame:CreateFontString(nil, "OVERLAY")
    cursorText:SetPoint("BOTTOMLEFT", playerText, "TOPLEFT", 0, LINE_GAP)
    styleLine(cursorText)

    frame:SetScript("OnUpdate", tick)
    WM.RefreshCoords()
end
