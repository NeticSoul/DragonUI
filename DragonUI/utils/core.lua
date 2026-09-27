-- ============================================================================
-- DragonUI - Core Utilities
-- Base runtime setup: event frame, noop, class detection, API tables.
-- ============================================================================

local addon = select(2, ...)

local type, select, pairs, ipairs, error = type, select, pairs, ipairs, error
local tostring, unpack, getmetatable, max = tostring, unpack, getmetatable, math.max

local function doNothing() end

addon._event = CreateFrame("Frame")
addon._noop = doNothing
addon._class = (select(2, UnitClass("player")))

-- Modules alias these two tables while loading, so they must never be swapped for new ones.
local api, functions = {}, {}
addon.api = api
addon.functions = functions

-- Global on purpose: the NineSlicePanelUiTemplate OnLoad in utils.xml calls it by bare name.
_G.addon_mixin = function(target, ...)
	for position = 1, select("#", ...) do
		local source = select(position, ...)
		if source ~= nil then
			if type(source) ~= "table" then
				error(("addon_mixin: mixin #%d is a %s, expected a table"):format(position, type(source)), 2)
			end
			for key, value in pairs(source) do
				target[key] = value
			end
		end
	end
	return target
end

local legacyActionBarAtlasBypassed = nil

local function ShouldBypassLegacyActionBarAtlas(atlas)
	if type(atlas) ~= 'string' then
		return false
	end

	if legacyActionBarAtlasBypassed == nil then
		legacyActionBarAtlasBypassed = GetCVar and GetCVar('gxApi') == 'd3d9ex'
	end

	if not legacyActionBarAtlasBypassed then
		return false
	end

	return atlas:find('ui%-hud%-actionbar') ~= nil
		or atlas:find('_ui%-hud%-actionbar') ~= nil
		or atlas:find('!ui%-hud%-actionbar') ~= nil
end

local function requireAtlas(name)
	local entry = addon.atlasinfo[name]
	if not entry then
		error(("DragonUI: unknown atlas %s"):format(tostring(name)), 3)
	end
	return entry
end

-- Entries have nil holes, so the count is explicit rather than taken from the length operator.
functions.atlas_unpack = function(name)
	return unpack(requireAtlas(name), 1, 9)
end

local function eachOwnTexture(frame, action, ...)
	local regions = { frame:GetRegions() }
	for index = 1, frame:GetNumRegions() do
		local region = regions[index]
		if region and region:GetObjectType() == "Texture" then
			action(region, ...)
		end
	end
end

local function hideForGood(widget)
	if widget.UnregisterAllEvents then
		widget:UnregisterAllEvents()
	end
	widget.Show = doNothing
	widget:Hide()
end

local function stripTexture(region, mode)
	if mode == true then
		hideForGood(region)
	else
		region:SetTexture(nil)
	end
end

local function setAtlas(texture, name, useAtlasSize)
	if not name then
		texture:SetTexture(nil)
		return
	end
	if ShouldBypassLegacyActionBarAtlas(name) then
		return
	end

	-- Captured before SetTexture: modules rely on a prior positive size being re-stamped.
	local oldWidth, oldHeight = texture:GetSize()
	local entry = requireAtlas(name)

	texture:SetTexture(entry[1])
	texture:SetTexCoord(entry[4], entry[5], entry[6], entry[7])
	texture:SetHorizTile(entry[8] or false)
	texture:SetVertTile(entry[9] or false)

	local width, height = oldWidth, oldHeight
	local resize = (oldWidth or 0) > 0 and (oldHeight or 0) > 0
	if useAtlasSize then
		width, height, resize = entry[2], entry[3], true
	end
	if resize then
		texture:SetWidth(width)
		texture:SetHeight(height)
	end
end

local function clearThenPoint(region, ...)
	region:ClearAllPoints()
	region:SetPoint(...)
end

api.noop = hideForGood
api.set_atlas = setAtlas
api.SetClearPoint = clearThenPoint

api.texture_strip = function(frame, mode)
	eachOwnTexture(frame, stripTexture, mode)
end

-- Deliberately asymmetric: right/bottom scale from 0 and are floored at the current left/top edge.
api.SetSubTexCoord = function(texture, left, right, top, bottom)
	local ulx, uly, _, lly, urx = texture:GetTexCoord()
	local x1, y1 = ulx + (urx - ulx) * left, uly + (lly - uly) * top
	local x2, y2 = max(urx * right, ulx), max(lly * bottom, uly)
	texture:SetTexCoord(x1, y1, x1, y2, x2, y1, x2, y2)
end

api.SetShownReq = function(widget, show)
	if show then
		widget:Show()
	else
		widget:Hide()
	end
end

local DIVIDER_PREFIX = "ui-hud-actionbar-frame-divider-threeslice-"
local DIVIDER_EDGES = {
	{ field = "divider_top", suffix = "edgetop", y = 39 },
	{ field = "divider_bottom", suffix = "edgebottom", y = 9 },
}

local function newBorderTexture(holder, field)
	local texture = holder:CreateTexture(nil, "BORDER")
	holder[field] = texture
	return texture
end

functions.SetThreeSlice = function(button)
	local holder = button:GetParent()
	local edges = {}
	for index, edge in ipairs(DIVIDER_EDGES) do
		local piece = newBorderTexture(holder, edge.field)
		piece:SetPoint("TOPLEFT", button, "BOTTOMRIGHT", -3, edge.y)
		setAtlas(piece, DIVIDER_PREFIX .. edge.suffix, true)
		edges[index] = piece
	end

	-- The second CENTER anchor replaces the first, so the middle piece hangs off the bottom edge.
	local middle = newBorderTexture(holder, "divider_mid")
	middle:SetPoint("CENTER", edges[1], "CENTER", 0, -15)
	middle:SetPoint("CENTER", edges[2], "CENTER", 0, 15)
	setAtlas(middle, "!" .. DIVIDER_PREFIX .. "center", true)
end

local function centerOnParent(region)
	clearThenPoint(region, "CENTER")
end

local PAGE_ARROW_STATES = { "Normal", "Pushed", "Highlight" }

functions.SetNumPagesButton = function(button, parent, direction, yOffset)
	eachOwnTexture(button, centerOnParent)
	button:SetParent(parent)
	clearThenPoint(button, "TOPLEFT", parent, "TOPLEFT", -30, yOffset)
	for _, state in ipairs(PAGE_ARROW_STATES) do
		local texture = button["Get" .. state .. "Texture"](button)
		setAtlas(texture, ("ui-hud-actionbar-%s-%s"):format(direction, state:lower()), true)
	end
end

functions.inject_api = function(object)
	local methods = getmetatable(object).__index
	for name, method in pairs(api) do
		if not object[name] then
			methods[name] = method
		end
	end
end

-- Widget types share one method table, so one live instance per type covers every instance.
function addon:initialize()
	local covered = {}
	local function cover(object)
		local kind = object:GetObjectType()
		if not covered[kind] then
			covered[kind] = true
			functions.inject_api(object)
		end
	end

	local probe = CreateFrame("Frame")
	cover(probe)
	cover(probe:CreateTexture())
	cover(probe:CreateFontString())

	local frame = EnumerateFrames()
	while frame do
		cover(frame)
		frame = EnumerateFrames(frame)
	end
end

addon:initialize()