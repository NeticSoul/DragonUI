local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's InsetFrameTemplate nine-slice, art and geometry both: 6px corners over 3px tiles, off the
-- client's own UI-Frame-Inner sheets rather than the Char-Paperdoll edges this used to borrow.
local CORNER_SIZE = 6
local EDGE_THICKNESS = 3

-- Its layout drops the bottom pair a pixel; without it they sit proud of the tile that joins them.
local BOTTOM_DROP = -1

local OUTSET_SIGN = {
    TOPLEFT = { -1, 1 }, TOPRIGHT = { 1, 1 },
    BOTTOMLEFT = { -1, -1 }, BOTTOMRIGHT = { 1, -1 },
}

-- `host` owns the textures so they hide with it; `target` is what gets rimmed. `outset` pushes the
-- rim outward for a target whose own ground would otherwise show past it.
function CP.DrawPaneBorder(host, target, outset)
    if not host or not target or host._duiPaneBorder then return end
    host._duiPaneBorder = true
    outset = outset or 0

    local function corner(atlas, point, drop)
        local t = host:CreateTexture(nil, "BORDER", nil, -5)
        t:set_atlas(atlas, true)
        t:SetSize(CORNER_SIZE, CORNER_SIZE)
        local sign = OUTSET_SIGN[point]
        t:SetPoint(point, target, point, sign[1] * outset, sign[2] * outset + (drop or 0))
        return t
    end

    local tl = corner("UI-Frame-InnerTopLeft", "TOPLEFT")
    local tr = corner("UI-Frame-InnerTopRight", "TOPRIGHT")
    local bl = corner("UI-Frame-InnerBotLeftCorner", "BOTTOMLEFT", BOTTOM_DROP)
    local br = corner("UI-Frame-InnerBotRight", "BOTTOMRIGHT", BOTTOM_DROP)

    -- Corner to corner, the way the nine-slice chains them; set_atlas carries the tiling flag.
    local function edge(atlas, vertical, p1, a1, r1, p2, a2, r2)
        local t = host:CreateTexture(nil, "BORDER", nil, -5)
        t:set_atlas(atlas)
        if vertical then t:SetWidth(EDGE_THICKNESS) else t:SetHeight(EDGE_THICKNESS) end
        t:SetPoint(p1, a1, r1)
        t:SetPoint(p2, a2, r2)
    end

    edge("!UI-Frame-InnerLeftTile", true, "TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT")
    edge("!UI-Frame-InnerRightTile", true, "TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT")
    edge("_UI-Frame-InnerTopTile", false, "TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT")
    edge("_UI-Frame-InnerBotTile", false, "BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")
end

CP:RegisterBuilder("paneborder", function()
    local cf = _G.CharacterFrame
    if not cf then return end
    if cf.Inset then CP.DrawPaneBorder(cf.Inset, cf.Inset) end
    if cf.InsetRight then CP.DrawPaneBorder(cf.InsetRight, cf.InsetRight) end
end)
