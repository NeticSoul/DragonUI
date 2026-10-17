-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Adapted from Blizzard's retail FrameXML NineSlice system for DragonUI.

local addon = select(2, ...)

local ipairs, error = ipairs, error

local atlasShim = addon.AtlasShim

-- Kept in apply order: corners first, since edges and the centre anchor to them.
local pieceRules = {}
local kitPieces = {}

local function addRule(name, rule)
	rule.name = name
	-- A mirrored layout flips right-hand art left-to-right and bottom art top-to-bottom.
	rule.flipX = name:find("Right", 1, true) ~= nil
	rule.flipY = name:find("Bottom", 1, true) ~= nil
	pieceRules[#pieceRules + 1] = rule
end

-- Anchor pair spanning spot a to spot b; a nil target means the container itself.
local function span(a, b, targetA, targetB)
	local pointA, pointB = a:upper(), b:upper()
	return { { pointA, targetA, pointB }, { pointB, targetB, pointA } }
end

for _, row in ipairs({ "Top", "Bottom" }) do
	for _, column in ipairs({ "Left", "Right" }) do
		local spot = row .. column
		addRule(spot .. "Corner", { corner = spot:upper() })
		kitPieces[spot .. "Corner"] = { atlas = "%s-nineslice-corner" .. spot:lower() }
	end
end

for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
	local across = side == "Top" or side == "Bottom"
	local a, b = "Top" .. side, "Bottom" .. side
	if across then
		a, b = side .. "Left", side .. "Right"
	end
	local toContainer = span(a, b)
	addRule(side .. "Edge", {
		anchors = span(a, b, a .. "Corner", b .. "Corner"),
		vertical = toContainer,
		horizontal = toContainer,
	})
	-- Atlas naming marks strips that tile across with "_" and strips that tile down with "!".
	kitPieces[side .. "Edge"] = { atlas = (across and "_" or "!") .. "%s-nineslice-edge" .. side:lower() }
end

addRule("Center", {
	anchors = span("TopLeft", "BottomRight", "TopLeftCorner", "BottomRightCorner"),
	vertical = { { "TOPLEFT", "TopEdge", "BOTTOMLEFT" }, { "BOTTOMRIGHT", "BottomEdge", "TOPRIGHT" } },
	horizontal = { { "TOPLEFT", "LeftEdge", "TOPRIGHT" }, { "BOTTOMRIGHT", "RightEdge", "BOTTOMLEFT" } },
})
kitPieces.Center = { atlas = "%s-nineslice-center" }

local layoutRegistry = {
	-- PortraitFrameTemplate in bronze: the professions output icon's ring takes the top-left corner,
	-- centred on the 62 portrait at TOPLEFT(-5,7) (characterpanel/portrait.lua), so 88 at (-18,20).
	-- The title band starts under the ring's metal and the left rail under its lower arc. The ring is
	-- the one OVERLAY piece; the rest sit on ARTWORK (above the BACKGROUND portrait) so it covers the
	-- band's end: this client ignores sublevels and same-layer pieces tie.
	PortraitFrameTemplate = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-PortraitRing", x = -18, y = 20},
		TopRightCorner = {layer = "ARTWORK", atlas = "UI-Frame-Bronze-CornerTopRight", x = 2, y = 16},
		BottomLeftCorner = {layer = "ARTWORK", atlas = "UI-Frame-Bronze-CornerBottomLeft", x = -13, y = -8},
		BottomRightCorner = {layer = "ARTWORK", atlas = "UI-Frame-Bronze-CornerBottomRight", x = 2, y = -8},
		TopEdge = {layer = "ARTWORK", atlas = "_UI-Frame-Bronze-EdgeTop", x = -10, y = -4, x1 = 0, y1 = 0},
		BottomEdge = {layer = "ARTWORK", atlas = "_UI-Frame-Bronze-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "ARTWORK", atlas = "!UI-Frame-Bronze-EdgeLeft", x = 5, y = 10, x1 = 0, y1 = 0},
		RightEdge = {layer = "ARTWORK", atlas = "!UI-Frame-Bronze-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},

	-- The bronze sheet has no wide top-right corner; the maximize button sits on the title band.
	PortraitFrameTemplateMinimizable = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-PortraitRing", x = -18, y = 20},
		TopRightCorner = {layer = "ARTWORK", atlas = "UI-Frame-Bronze-CornerTopRight", x = 2, y = 16},
		BottomLeftCorner = {layer = "ARTWORK", atlas = "UI-Frame-Bronze-CornerBottomLeft", x = -13, y = -8},
		BottomRightCorner = {layer = "ARTWORK", atlas = "UI-Frame-Bronze-CornerBottomRight", x = 2, y = -8},
		TopEdge = {layer = "ARTWORK", atlas = "_UI-Frame-Bronze-EdgeTop", x = -10, y = -4, x1 = 0, y1 = 0},
		BottomEdge = {layer = "ARTWORK", atlas = "_UI-Frame-Bronze-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "ARTWORK", atlas = "!UI-Frame-Bronze-EdgeLeft", x = 5, y = 10, x1 = 0, y1 = 0},
		RightEdge = {layer = "ARTWORK", atlas = "!UI-Frame-Bronze-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},


	-- The professions window's bronze chrome, which every no-portrait window wears so they all
	-- match it. Offsets are that window's: they put the bronze rails within a unit of where the
	-- steel PortraitFrameTemplate's sat, so title text, close buttons and grounds keep their places.
	-- Edges run flush between the corners, stretched (the strips are uniform).
	NoPortraitFrameTemplate = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerTopLeft", x = -13, y = 16},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerTopRight", x = 2, y = 16},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerBottomLeft", x = -13, y = -8},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerBottomRight", x = 2, y = -8},
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Bronze-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Bronze-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Bronze-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Bronze-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},

	-- The bronze sheet has no wide top-right corner; its title band is deep enough that the
	-- maximize button sits on it beside the close one, so this is the same frame.
	NoPortraitFrameTemplateMinimizable = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerTopLeft", x = -13, y = 16},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerTopRight", x = 2, y = 16},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerBottomLeft", x = -13, y = -8},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerBottomRight", x = 2, y = -8},
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Bronze-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Bronze-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Bronze-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Bronze-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},

	-- Inset trim in the professions style: the recipe card's filigree frame, pushed 2.5 out so its
	-- rail lands on the inset's edge and its soft inner shadow falls on the content.
	InsetFrameTemplate = {
		TopLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-Filigree-CornerTopLeft", x = -2.5, y = 2.5 },
		TopRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-Filigree-CornerTopRight", x = 2.5, y = 2.5 },
		BottomLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-Filigree-CornerBottomLeft", x = -2.5, y = -2.5 },
		BottomRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-Filigree-CornerBottomRight", x = 2.5, y = -2.5 },
		TopEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-Filigree-EdgeTop" },
		BottomEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-Filigree-EdgeBottom" },
		LeftEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-Filigree-EdgeLeft" },
		RightEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-Filigree-EdgeRight" },
	},

	-- The same trim at 10 (rail pushed 1.5 out): for an inset too short for the 16 corners and for
	-- content that is itself the inset, like the flight map, which the deeper shadow would dim.
	SmallInsetFrameTemplate = {
		TopLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-FiligreeSmall-CornerTopLeft", x = -1.5, y = 1.5 },
		TopRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-FiligreeSmall-CornerTopRight", x = 1.5, y = 1.5 },
		BottomLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-FiligreeSmall-CornerBottomLeft", x = -1.5, y = -1.5 },
		BottomRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-FiligreeSmall-CornerBottomRight", x = 1.5, y = -1.5 },
		TopEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-FiligreeSmall-EdgeTop" },
		BottomEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-FiligreeSmall-EdgeBottom" },
		LeftEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-FiligreeSmall-EdgeLeft" },
		RightEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-FiligreeSmall-EdgeRight" },
	},

	-- What DialogBorderTemplate resolves to, in bronze: the thin rail on all four sides (the bottom
	-- corners and edge, flipped for the top). Two units further in than the windows' offsets so the
	-- rail's inner edge (7) meets the popups' ground, which starts 7 in (DIALOG_INSET).
	Dialog = {
		TopLeftCorner = {atlas = "UI-Frame-Bronze-CornerTopLeft-Thin", x = -11, y = 6},
		TopRightCorner = {atlas = "UI-Frame-Bronze-CornerTopRight-Thin", x = 1, y = 6},
		BottomLeftCorner = {atlas = "UI-Frame-Bronze-CornerBottomLeft", x = -11, y = -6},
		BottomRightCorner = {atlas = "UI-Frame-Bronze-CornerBottomRight", x = 1, y = -6},
		TopEdge = {atlas = "_UI-Frame-Bronze-EdgeTop-Thin"},
		BottomEdge = {atlas = "_UI-Frame-Bronze-EdgeBottom"},
		LeftEdge = {atlas = "!UI-Frame-Bronze-EdgeLeft"},
		RightEdge = {atlas = "!UI-Frame-Bronze-EdgeRight"}
	},

	-- The bronze frame without a title band: thin rail all round, at the windows' offsets.
	MetalFrameTemplate = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerTopLeft-Thin", x = -13, y = 8},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerTopRight-Thin", x = 2, y = 8},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerBottomLeft", x = -13, y = -8},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Bronze-CornerBottomRight", x = 2, y = -8},
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Bronze-EdgeTop-Thin", x = 0, y = 0, x1 = 0, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Bronze-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Bronze-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Bronze-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},
}

-- Its atlas names embed the texture kit, so one kit picks the whole art set.
layoutRegistry.UniqueCornersLayout = kitPieces

local function getLayout(name)
	if name == nil then
		return nil
	end
	return layoutRegistry[name]
end

local function acquirePiece(container, pieceName)
	local supplier = container.GetNineSlicePiece
	local found = supplier and supplier(container, pieceName) or container[pieceName]
	if found then
		return found, false
	end
	local fresh = container:CreateTexture()
	container[pieceName] = fresh
	return fresh, true
end

local function anchorTarget(container, pieceName)
	if pieceName == nil then
		return container
	end
	return (acquirePiece(container, pieceName))
end

-- Read from the plain Lua field, never the XML attribute of the same name.
local function threeSliceMode(container)
	local named = getLayout(container.layoutType)
	if not named then
		return nil
	end
	if named.threeSliceVertical then
		return "vertical"
	end
	if named.threeSliceHorizontal then
		return "horizontal"
	end
	return nil
end

local function anchorPiece(container, tex, rule, spec, mode)
	tex:ClearAllPoints()
	if rule.corner then
		local point, relativePoint = spec.point or rule.corner, spec.relativePoint or rule.corner
		tex:SetPoint(point, container, relativePoint, spec.x, spec.y)
		return
	end
	local anchors = mode and rule[mode] or rule.anchors
	local near, far = anchors[1], anchors[2]
	tex:SetPoint(near[1], anchorTarget(container, near[2]), near[3], spec.x, spec.y)
	tex:SetPoint(far[1], anchorTarget(container, far[2]), far[3], spec.x1, spec.y1)
end

local function dressPiece(tex, rule, spec, layout, textureKit)
	local mirrored = spec.mirrorLayout
	if mirrored == nil then
		mirrored = layout.mirrorLayout
	end
	local left, right, top, bottom = 0, 1, 0, 1
	if mirrored then
		if rule.flipX then
			left, right = 1, 0
		end
		if rule.flipY then
			top, bottom = 1, 0
		end
	end
	-- SetAtlasTexture replaces these texcoords; they only survive while the D3D9Ex bypass skips it.
	tex:SetSubTexCoord(left, right, top, bottom)

	local atlasName = atlasShim.GetFinalNameFromTextureKit(spec.atlas, textureKit)
	local info = atlasShim.GetAtlasInfo(atlasName)
	local across, down = info.tilesHorizontally, info.tilesVertically
	-- Set here as well because the D3D9Ex bypass turns SetAtlasTexture into a no-op for action-bar art.
	tex:SetHorizTile(across or false)
	tex:SetVertTile(down or false)
	tex:SetAtlasTexture(atlasName, true)
end

local function applyLayout(container, layout, textureKit)
	if not layout then
		error("DragonUI_NineSlice.ApplyLayout: layout is nil", 2)
	end
	local mode = threeSliceMode(container)
	for _, rule in ipairs(pieceRules) do
		local spec = layout[rule.name]
		if spec then
			local piece, isNew = acquirePiece(container, rule.name)
			if isNew then
				piece:SetDrawLayer(spec.layer or "BORDER", spec.subLevel)
			end
			anchorPiece(container, piece, rule, spec, mode)
			dressPiece(piece, rule, spec, layout, textureKit)
		end
	end
end

_G.DragonUI_NineSlice = {
	ApplyLayout = applyLayout,
	GetLayout = getLayout,
}

local function inheritedAttribute(frame, key)
	return frame:GetAttribute(key) or frame:GetParent():GetAttribute(key)
end

_G.DragonUI_NineSlicePanelMixin = {
	GetFrameLayoutType = function(self)
		return inheritedAttribute(self, "layoutType")
	end,
	GetFrameLayoutTextureKit = function(self)
		return inheritedAttribute(self, "layoutTextureKit")
	end,
	-- layoutTextureLayer and ignoreInLayout stay unread, so both action-bar slices draw in BORDER.
	OnLoad = function(self)
		local chosen = getLayout(self:GetFrameLayoutType())
		if chosen ~= nil then
			applyLayout(self, chosen, self:GetFrameLayoutTextureKit())
		end
	end,
}
