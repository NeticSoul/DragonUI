local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's UI-Frame-Inner trim, the same the insets are rimmed with; see paneborder.lua.
local CORNER_SIZE = 6
local EDGE_THICKNESS = 3

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
    local function corner(atlas, point, x, y)
        local t = pd:CreateTexture(nil, "OVERLAY")
        t._duiOwned = true
        t:set_atlas(atlas, true)
        t:SetSize(CORNER_SIZE, CORNER_SIZE)
        t:SetPoint(point, model, point, x, y)
        pieces[#pieces + 1] = t
        return t
    end

    local tl = corner("UI-Frame-InnerTopLeft", "TOPLEFT", -OUTSET, OUTSET)
    local tr = corner("UI-Frame-InnerTopRight", "TOPRIGHT", OUTSET, OUTSET)
    local bl = corner("UI-Frame-InnerBotLeftCorner", "BOTTOMLEFT", -OUTSET, -OUTSET)
    local br = corner("UI-Frame-InnerBotRight", "BOTTOMRIGHT", OUTSET, -OUTSET)

    -- Flush against the corners: this trim is cut to meet, unlike the paperdoll edges it replaced,
    -- which needed a pixel of shift to reach their fatter corner.
    local function edge(atlas, vertical, p1, a1, r1, p2, a2, r2)
        local t = pd:CreateTexture(nil, "OVERLAY")
        t._duiOwned = true
        t:set_atlas(atlas)
        if vertical then t:SetWidth(EDGE_THICKNESS) else t:SetHeight(EDGE_THICKNESS) end
        t:SetPoint(p1, a1, r1)
        t:SetPoint(p2, a2, r2)
        pieces[#pieces + 1] = t
        return t
    end

    edge("!UI-Frame-InnerLeftTile", true, "TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT")
    edge("!UI-Frame-InnerRightTile", true, "TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT")
    edge("_UI-Frame-InnerTopTile", false, "TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT")
    edge("_UI-Frame-InnerBotTile", false, "BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")

    -- Full-width rule level with the bottom of the columns, which end where the model does.
    local divider = pd:CreateTexture(nil, "OVERLAY")
    divider._duiOwned = true
    divider:set_atlas("_UI-Frame-InnerBotTile")
    divider:SetHeight(EDGE_THICKNESS)
    divider:SetPoint("LEFT", inset, "LEFT", 0, 0)
    divider:SetPoint("RIGHT", inset, "RIGHT", 0, 0)
    divider:SetPoint("BOTTOM", model, "BOTTOM", 0, -OUTSET)
    pieces[#pieces + 1] = divider
end

CP.InnerBorderPieces = pieces

CP:RegisterBuilder("innerborder", build)
