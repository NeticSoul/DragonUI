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
	-- Retail's PortraitFrameTemplate. The top-left corner carries the portrait cutout, so it
	-- overhangs 13px left / 16px up; the bottom-left must match or LeftEdge joins two offsets.
	PortraitFrameTemplate = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-PortraitMetal-CornerTopLeft", x = -13, y = 16},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3},
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = -4, y = 0, x1 = 4, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},

	-- PortraitFrameTemplate with the wide top-right corner for a maximize button beside close.
	PortraitFrameTemplateMinimizable = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-PortraitMetal-CornerTopLeft", x = -13, y = 16},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRightDouble", x = 4, y = 16},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3},
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = -4, y = 0, x1 = 4, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},

	-- Retail's ButtonFrameTemplateNoPortrait: PortraitFrameTemplate with the cutout corner swapped
	-- for the plain one. Geometry is untouched because both carry the same 12px of left padding --
	-- the -13 is what every left-side piece on this sheet needs, cutout or not.
	NoPortraitFrameTemplate = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -13, y = 16},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 4, y = 16},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -13, y = -3},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3},
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = -4, y = 0, x1 = 4, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
	},

	-- Retail InsetFrameTemplate: thin inner gold trim around a recessed content area.
	InsetFrameTemplate = {
		TopLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerTopLeft" },
		TopRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerTopRight" },
		BottomLeftCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerBotLeftCorner", y = -1 },
		BottomRightCorner = { layer = "BORDER", subLevel = -5, atlas = "UI-Frame-InnerBotRight", y = -1 },
		TopEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-InnerTopTile" },
		BottomEdge = { layer = "BORDER", subLevel = -5, atlas = "_UI-Frame-InnerBotTile" },
		LeftEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-InnerLeftTile" },
		RightEdge = { layer = "BORDER", subLevel = -5, atlas = "!UI-Frame-InnerRightTile" },
	},

	-- What DialogBorderTemplate resolves to: retail frames a popup with this, NOT with the inset trim.
	-- Every piece is pushed out by RAIL_PAD because the rail is only 16 thick inside a 64 piece and
	-- sits 8.5 in; anchored flush the whole border draws inset and the window's ground shows past it.
	Dialog = {
		TopLeftCorner = {atlas = "UI-Frame-DiamondMetal-CornerTopLeft", x = -8, y = 8},
		TopRightCorner = {atlas = "UI-Frame-DiamondMetal-CornerTopRight", x = 8, y = 8},
		BottomLeftCorner = {atlas = "UI-Frame-DiamondMetal-CornerBottomLeft", x = -8, y = -8},
		BottomRightCorner = {atlas = "UI-Frame-DiamondMetal-CornerBottomRight", x = 8, y = -8},
		-- No offsets of their own: SetupEdge chains these to the CORNERS, so they already carry the
		-- corners' push. Repeating it here is what left the rails floating off their own frame.
		TopEdge = {atlas = "_UI-Frame-DiamondMetal-EdgeTop"},
		BottomEdge = {atlas = "_UI-Frame-DiamondMetal-EdgeBottom"},
		LeftEdge = {atlas = "!UI-Frame-DiamondMetal-EdgeLeft"},
		RightEdge = {atlas = "!UI-Frame-DiamondMetal-EdgeRight"}
	},

	-- The metal frame without the portrait cutout. All four corners are the 32px pair, the top two
	-- flipped: mixing them with the ornate 75px tops makes each side edge join two widths.
	MetalFrameTemplate = {
		TopLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft-Thin", x = -4, y = 3},
		TopRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight-Thin", x = 4, y = 3},
		BottomLeftCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -4, y = -3},
		BottomRightCorner = {layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 4, y = -3},
		-- Flush against both corners. The portrait layout insets the top edge because its left
		-- corner overhangs 13px; with symmetric corners that inset just opens a gap at the join.
		TopEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop", x = 0, y = 0, x1 = 0, y1 = 0},
		BottomEdge = {layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom", x = 0, y = 0, x1 = 0, y1 = 0},
		LeftEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft", x = 0, y = 0, x1 = 0, y1 = 0},
		RightEdge = {layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight", x = 0, y = 0, x1 = 0, y1 = 0}
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
