local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Thin gold trim around a content pane, the way retail's InsetFrameTemplate rims its insets. Its
-- UI-Frame-Inner* atlas has no 3.3.5a equivalent; the Char-Paperdoll edges are the same trim.
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

local CORNER_SIZE = 7
local EDGE_THICKNESS = 5
-- The corner is 7px square but the edge only 5px thick, and the corner's line sits a pixel off
-- centre, so every edge needs a 1px shift outward to meet it.
local EDGE_SHIFT = 1

-- `host` owns the textures so they hide with it; `target` is what gets rimmed. `outset` pushes the
-- rim outward for a target whose own ground would otherwise show past it.
local OUTSET_SIGN = {
    TOPLEFT = { -1, 1 }, TOPRIGHT = { 1, 1 },
    BOTTOMLEFT = { -1, -1 }, BOTTOMRIGHT = { 1, -1 },
}

function CP.DrawPaneBorder(host, target, outset)
    if not host or not target or host._duiPaneBorder then return end
    host._duiPaneBorder = true
    outset = outset or 0

    local function corner(tc, point)
        local t = host:CreateTexture(nil, "BORDER")
        t:SetTexture(PARTS)
        t:SetSize(CORNER_SIZE, CORNER_SIZE)
        t:SetTexCoord(unpack(tc))
        local sign = OUTSET_SIGN[point]
        t:SetPoint(point, target, point, sign[1] * outset, sign[2] * outset)
        return t
    end

    local tl = corner(CORNERS.TopLeft, "TOPLEFT")
    local tr = corner(CORNERS.TopRight, "TOPRIGHT")
    local bl = corner(CORNERS.BottomLeft, "BOTTOMLEFT")
    local br = corner(CORNERS.BottomRight, "BOTTOMRIGHT")

    local function edge(file, tc, vertical, dx, dy, p1, a1, r1, p2, a2, r2)
        local t = host:CreateTexture(nil, "BORDER")
        t:SetTexture(file)
        t:SetTexCoord(unpack(tc))
        if vertical then
            t:SetVertTile(true)
            t:SetWidth(EDGE_THICKNESS)
        else
            t:SetHorizTile(true)
            t:SetHeight(EDGE_THICKNESS)
        end
        t:SetPoint(p1, a1, r1, dx, dy)
        t:SetPoint(p2, a2, r2, dx, dy)
    end

    local s = EDGE_SHIFT
    edge(VERTICAL, EDGE_LEFT, true, -s, 0, "TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT")
    edge(VERTICAL, EDGE_RIGHT, true, s, 0, "TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT")
    edge(HORIZONTAL, EDGE_TOP, false, 0, s, "TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT")
    edge(HORIZONTAL, EDGE_BOTTOM, false, 0, -s, "BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")
end

CP:RegisterBuilder("paneborder", function()
    local cf = _G.CharacterFrame
    if not cf then return end
    if cf.Inset then CP.DrawPaneBorder(cf.Inset, cf.Inset) end
    if cf.InsetRight then CP.DrawPaneBorder(cf.InsetRight, cf.InsetRight) end
end)
