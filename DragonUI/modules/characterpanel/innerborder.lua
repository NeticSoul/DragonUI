local addon = select(2, ...)
local CP = addon.CharacterPanel

local PARTS = addon._dir .. "CharacterPanel\\charpaperdollparts"
local HORIZONTAL = addon._dir .. "CharacterPanel\\charpaperdollhorizontal"
local VERTICAL = addon._dir .. "CharacterPanel\\charpaperdollvertical"

local CORNERS = {
    TopLeft = { 0.40625, 0.43359375, 0.80468750, 0.85937500 },
    TopRight = { 0.40625, 0.43359375, 0.73437500, 0.78906250 },
    BottomLeft = { 0.40625, 0.43359375, 0.66406250, 0.71875000 },
    BottomRight = { 0.40625, 0.43359375, 0.59375000, 0.64843750 },
}
local EDGE_TOP = { 0, 1, 0.50000, 0.81250 }
local EDGE_BOTTOM = { 0, 1, 0.06250, 0.37500 }
local EDGE_LEFT = { 0.06250, 0.37500, 0, 1 }
local EDGE_RIGHT = { 0.50000, 0.81250, 0, 1 }

-- Anchored to the model frame rather than a hardcoded offset from the Inset floor: retail's literal
-- 27 is measured against its own weapon row, and on Wrath's taller one it fell inside the slots.
local OUTSET = 2

local pieces = {}

local function build()
    local cf = _G.CharacterFrame
    local pd = _G.PaperDollFrame
    local model = _G.CharacterModelFrame
    if not cf or not pd or not model or not cf.Inset or cf._duiInnerBorder then return end
    cf._duiInnerBorder = true
    local inset = cf.Inset

    -- Owned by PaperDollFrame so it stacks with the slots and hides with the tab, and tagged so
    -- chrome.lua's sweep tells our art from Blizzard's by identity rather than by path.
    local function corner(tc, point, x, y)
        local t = pd:CreateTexture(nil, "OVERLAY")
        t._duiOwned = true
        t:SetTexture(PARTS)
        t:SetSize(7, 7)
        t:SetTexCoord(unpack(tc))
        t:SetPoint(point, model, point, x, y)
        pieces[#pieces + 1] = t
        return t
    end

    local tl = corner(CORNERS.TopLeft, "TOPLEFT", -OUTSET, OUTSET)
    local tr = corner(CORNERS.TopRight, "TOPRIGHT", OUTSET, OUTSET)
    local bl = corner(CORNERS.BottomLeft, "BOTTOMLEFT", -OUTSET, -OUTSET)
    local br = corner(CORNERS.BottomRight, "BOTTOMRIGHT", OUTSET, -OUTSET)

    local function edge(file, tc, vertical, p1, a1, r1, x1, y1, p2, a2, r2, x2, y2)
        local t = pd:CreateTexture(nil, "OVERLAY")
        t._duiOwned = true
        t:SetTexture(file)
        t:SetTexCoord(unpack(tc))
        if vertical then t:SetVertTile(true); t:SetWidth(5) else t:SetHorizTile(true); t:SetHeight(5) end
        t:SetPoint(p1, a1, r1, x1, y1)
        t:SetPoint(p2, a2, r2, x2, y2)
        pieces[#pieces + 1] = t
        return t
    end

    edge(VERTICAL, EDGE_LEFT, true, "TOPLEFT", tl, "BOTTOMLEFT", -1, 0, "BOTTOMLEFT", bl, "TOPLEFT", -1, 0)
    edge(VERTICAL, EDGE_RIGHT, true, "TOPRIGHT", tr, "BOTTOMRIGHT", 1, 0, "BOTTOMRIGHT", br, "TOPRIGHT", 1, 0)
    edge(HORIZONTAL, EDGE_TOP, false, "TOPLEFT", tl, "TOPRIGHT", 0, 1, "TOPRIGHT", tr, "TOPLEFT", 0, 1)
    edge(HORIZONTAL, EDGE_BOTTOM, false, "BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, -1, "BOTTOMRIGHT", br, "BOTTOMLEFT", 0, -1)

    -- Full-width rule level with the bottom of the columns, which end where the model does.
    local divider = pd:CreateTexture(nil, "OVERLAY")
    divider._duiOwned = true
    divider:SetTexture(HORIZONTAL)
    divider:SetTexCoord(unpack(EDGE_BOTTOM))
    divider:SetHorizTile(true)
    divider:SetHeight(5)
    divider:SetPoint("LEFT", inset, "LEFT", 0, 0)
    divider:SetPoint("RIGHT", inset, "RIGHT", 0, 0)
    divider:SetPoint("BOTTOM", model, "BOTTOM", 0, -OUTSET)
    pieces[#pieces + 1] = divider
end

CP.InnerBorderPieces = pieces

CP:RegisterBuilder("innerborder", build)
