-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- InsetFrameTemplate's trim, in the professions style: the recipe card's filigree frame (see
-- nineslice.lua). Its rail sits 2.5 in from the art's edge, so the rim is pushed out that far.
-- "thin" is retail's UI-Frame-Inner trim (6px corners, 3px tiles, bottom pair dropped a pixel so
-- they don't sit proud of the tile), for a rim whose soft filigree shadow would dim live buttons.
local STYLES = {
    filigree = {
        corner = 16, edge = 16, push = 2.5, drop = 0,
        corners = { "UI-Frame-Filigree-CornerTopLeft", "UI-Frame-Filigree-CornerTopRight",
                    "UI-Frame-Filigree-CornerBottomLeft", "UI-Frame-Filigree-CornerBottomRight" },
        edges = { "!UI-Frame-Filigree-EdgeLeft", "!UI-Frame-Filigree-EdgeRight",
                  "_UI-Frame-Filigree-EdgeTop", "_UI-Frame-Filigree-EdgeBottom" },
    },
    thin = {
        corner = 6, edge = 3, push = 0, drop = -1,
        corners = { "UI-Frame-InnerTopLeft", "UI-Frame-InnerTopRight",
                    "UI-Frame-InnerBotLeftCorner", "UI-Frame-InnerBotRight" },
        edges = { "!UI-Frame-InnerLeftTile", "!UI-Frame-InnerRightTile",
                  "_UI-Frame-InnerTopTile", "_UI-Frame-InnerBotTile" },
    },
}

local OUTSET_SIGN = {
    TOPLEFT = { -1, 1 }, TOPRIGHT = { 1, 1 },
    BOTTOMLEFT = { -1, -1 }, BOTTOMRIGHT = { 1, -1 },
}

-- `host` owns the textures so they hide with it; `target` is what gets rimmed. `outset` pushes the
-- rim outward for a target whose own ground would otherwise show past it. `style` is a STYLES key.
function CP.DrawPaneBorder(host, target, outset, style)
    if not host or not target or host._duiPaneBorder then return end
    host._duiPaneBorder = true
    style = STYLES[style] or STYLES.filigree
    outset = (outset or 0) + style.push

    local function corner(atlas, point, drop)
        local t = host:CreateTexture(nil, "BORDER", nil, -5)
        t:SetAtlasTexture(atlas, true)
        t:SetSize(style.corner, style.corner)
        local sign = OUTSET_SIGN[point]
        t:SetPoint(point, target, point, sign[1] * outset, sign[2] * outset + (drop or 0))
        return t
    end

    local c = style.corners
    local tl = corner(c[1], "TOPLEFT")
    local tr = corner(c[2], "TOPRIGHT")
    local bl = corner(c[3], "BOTTOMLEFT", style.drop)
    local br = corner(c[4], "BOTTOMRIGHT", style.drop)

    -- Corner to corner, the way the nine-slice chains them; SetAtlasTexture carries the tiling flag.
    local function edge(atlas, vertical, p1, a1, r1, p2, a2, r2)
        local t = host:CreateTexture(nil, "BORDER", nil, -5)
        t:SetAtlasTexture(atlas)
        if vertical then t:SetWidth(style.edge) else t:SetHeight(style.edge) end
        t:SetPoint(p1, a1, r1)
        t:SetPoint(p2, a2, r2)
    end

    local e = style.edges
    edge(e[1], true, "TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT")
    edge(e[2], true, "TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT")
    edge(e[3], false, "TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT")
    edge(e[4], false, "BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")
end

CP:RegisterBuilder("paneborder", function()
    local cf = _G.CharacterFrame
    if not cf then return end
    if cf.Inset then CP.DrawPaneBorder(cf.Inset, cf.Inset) end
    if cf.InsetRight then CP.DrawPaneBorder(cf.InsetRight, cf.InsetRight) end
end)
