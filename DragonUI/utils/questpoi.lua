-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- QuestPOITemplate as one shared widget. Texcoords are the 3.3.5a sheet's; retail moved the rings.

local QP = {}
addon.QuestPOI = QP

local SHEET = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons"
local TURNIN = "Interface\\WorldMap\\UI-WorldMap-QuestIcon"
local GLOW = "Interface\\WorldMap\\UI-QuestPoi-IconGlow"

-- QuestPOITemplate's own metrics; every size below is a share of the 32px button.
local BASE, TURNIN_SIZE, GLOW_SIZE = 32, 24, 50
-- What QuestPOI_DisplayButton scales the client's own badges to, and so what every list uses.
QP.SIZE = 29
local PER_ROW, CELL = 8, 0.125
local YELLOW, BLACK = 0.5, 0

-- The ring says where, the glyph says what, so offMap is the square Blizzard's grid never needed.
local RINGS = {
    numeric     = { { 0.875, 1, 0.875, 1 },     { 0.750, 0.875, 0.875, 1 }, { 0.625, 0.750, 0.875, 1 } },
    complete    = { { 0.875, 1, 0.875, 1 },     { 0.750, 0.875, 0.875, 1 }, { 0.625, 0.750, 0.875, 1 } },
    completeOut = { { 0.500, 0.625, 0.875, 1 }, { 0.375, 0.500, 0.875, 1 }, { 0.625, 0.750, 0.375, 0.5 } },
    offMap      = { { 0.500, 0.625, 0.875, 1 }, { 0.375, 0.500, 0.875, 1 }, { 0.625, 0.750, 0.375, 0.5 } },
}
local SELECTED = { { 0.500, 0.625, 0.375, 0.5 }, { 0.375, 0.500, 0.375, 0.5 }, { 0.625, 0.750, 0.375, 0.5 } }
-- QUEST_POI_COMPLETE_OUT has no selected art, so the dark ring keeps its own when focused.
local NO_SELECTED_ART = { completeOut = true, offMap = true }

-- The canvas POIs are Blizzard's own buttons; pins.lua crops them off these same numbers.
QP.MAP_CROP = { idle = RINGS.numeric, selected = SELECTED, glyph = { idle = YELLOW, selected = BLACK } }

local function crop(texture, box)
    texture:SetTexCoord(box[1], box[2], box[3], box[4])
end

-- Blizzard nudges only the glyph on a press; the pushed ring art supplies the rest of the motion.
local function placeIcon(button, pushed)
    local x, y
    if button.duiStyle == "numeric" then
        x, y = pushed and 1 or 0, pushed and -1 or 0
    else
        x, y = pushed and 0 or -1, pushed and -1 or 0
    end
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER", button, "CENTER", x, y)
end

function QP.Create(parent, size)
    local button = CreateFrame("Button", nil, parent)
    size = size or BASE
    button:SetSize(size, size)
    button.duiScale = size / BASE

    button.glow = button:CreateTexture(nil, "BACKGROUND")
    button.glow:SetTexture(GLOW)
    button.glow:SetBlendMode("ADD")
    button.glow:SetSize(GLOW_SIZE * button.duiScale, GLOW_SIZE * button.duiScale)
    button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.glow:Hide()

    button:SetNormalTexture(SHEET)
    button:SetPushedTexture(SHEET)
    button:SetHighlightTexture(SHEET, "ADD")
    button.ring = button:GetNormalTexture()
    button.ringPushed = button:GetPushedTexture()
    button.ringHighlight = button:GetHighlightTexture()
    -- BORDER like QuestPOITemplate's OnLoad, so the glyph over them stays readable.
    button.ring:SetDrawLayer("BORDER")
    button.ringPushed:SetDrawLayer("BORDER")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)

    button:SetScript("OnMouseDown", function(self) placeIcon(self, true) end)
    button:SetScript("OnMouseUp", function(self) placeIcon(self, false) end)
    QP.SetStyle(button, "numeric", 1)
    return button
end

function QP.SetStyle(button, style, number, selected)
    if selected ~= nil then button.duiSelected = selected and true or nil end
    button.duiStyle = RINGS[style] and style or "numeric"
    button.duiNumber = number
    local focused = button.duiSelected and not NO_SELECTED_ART[button.duiStyle]
    local art = focused and SELECTED or RINGS[button.duiStyle]
    crop(button.ring, art[1])
    crop(button.ringPushed, art[2])
    crop(button.ringHighlight, art[3])

    if button.duiStyle == "numeric" then
        local cell = (number or 1) - 1
        local x = math.fmod(cell, PER_ROW) * CELL
        local y = (focused and BLACK or YELLOW) + math.floor(cell / PER_ROW) * CELL
        button.icon:SetTexture(SHEET)
        button.icon:SetTexCoord(x, x + CELL, y, y + CELL)
        button.icon:SetSize(button:GetWidth(), button:GetHeight())
    elseif button.duiStyle == "offMap" then
        button.icon:SetTexture(nil)
    else
        button.icon:SetTexture(TURNIN)
        button.icon:SetTexCoord(0, 0.5, 0, 0.5)
        button.icon:SetSize(TURNIN_SIZE * button.duiScale, TURNIN_SIZE * button.duiScale)
    end

    if focused then button.glow:Show() else button.glow:Hide() end
    placeIcon(button, false)
end

function QP.SetSelected(button, selected)
    selected = selected and true or nil
    if button.duiSelected == selected then return end
    button.duiSelected = selected
    QP.SetStyle(button, button.duiStyle, button.duiNumber)
end

-- ============================================================================
-- FOCUS
-- ============================================================================

-- The one selection every badge follows: the map, the panel rows and the tracker.
local listeners = {}

function QP.RegisterFocusListener(fn)
    listeners[#listeners + 1] = fn
end

function QP.SetFocus(questID)
    if questID == 0 then questID = nil end
    if QP.focusID == questID then return end
    QP.focusID = questID
    for _, fn in ipairs(listeners) do fn(questID) end
end

function QP.GetFocus()
    return QP.focusID
end
