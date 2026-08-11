-- ============================================================================
-- DragonUI - Core Utilities
-- Base runtime setup: event frame, noop, class detection, API tables.
-- ============================================================================

local unpack = unpack;
local select = select;
local pairs = pairs;
local assert = assert;
local getmetatable = getmetatable;
local next = next;

local addon = select(2,...);
addon._event = CreateFrame('Frame');
addon._noop = function() return; end
addon._class = select(2,UnitClass('player'));
addon.api = {};
addon.functions = {};

addon_mixin = function(object, ...)
	local mixins = {...}
	for _,mixin in pairs(mixins) do
		for k,v in next, mixin do
			object[k] = v
		end
	end
	return object
end

addon.api.noop = function(object)
	if object.UnregisterAllEvents then
		object:UnregisterAllEvents()
	end
	object.Show = addon._noop
	object:Hide()
end

addon.api.texture_strip = function(self, object)
	for i=1, self:GetNumRegions() do
		local region = select(i, self:GetRegions())
		if region and region:GetObjectType() == 'Texture' then
			if object and type(object) == 'boolean' then
				region:noop()
			elseif region:GetDrawLayer() == object then
				region:SetTexture(nil)
			elseif object and type(object) == 'string' and region:GetTexture() ~= object then
				region:SetTexture(nil)
			else
				region:SetTexture(nil)
			end
		end
	end
end

addon.functions.atlas_unpack = function(atlas)
	assert(addon.atlasinfo[atlas], 'Atlas ['..atlas..']: failed to unpack')
	return unpack(addon.atlasinfo[atlas])
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

addon.api.set_atlas = function(self, atlas, size)
	if not atlas then
		self:SetTexture(nil)
		return
	end

	if ShouldBypassLegacyActionBarAtlas(atlas) then
		return
	end
	
	local origWidth, origHeight = self:GetSize()
	local tex, width, height, left, right, top, bottom, horizTile, vertTile = addon.functions.atlas_unpack(atlas)
	
	self:SetTexture(tex)
	self:SetTexCoord(left, right, top, bottom)
	self:SetHorizTile(horizTile or false)
	self:SetVertTile(vertTile or false)

	if size then
		self:SetWidth(width)
		self:SetHeight(height)
	elseif origWidth and origWidth > 0 and origHeight and origHeight > 0 then
		-- Only re-assert a size the texture actually had: stamping 0x0 on a fresh one sizes it to
		-- nothing, and the engine then falls back to anchors or the sheet's size depending on the load.
		self:SetWidth(origWidth)
		self:SetHeight(origHeight)
	end
end

addon.api.SetSubTexCoord = function(self, left, right, top, bottom)
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = self:GetTexCoord()

	local leftedge = ULx
	local rightedge = URx
	local topedge = ULy
	local bottomedge = LLy

	local width  = rightedge - leftedge
	local height = bottomedge - topedge

	leftedge = ULx + width * left
	topedge = ULy + height * top
	rightedge = math.max(rightedge * right, ULx)
	bottomedge = math.max(bottomedge * bottom, ULy)

	ULx = leftedge
	ULy = topedge
	LLx = leftedge
	LLy = bottomedge
	URx = rightedge
	URy = topedge
	LRx = rightedge
	LRy = bottomedge

	self:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

addon.api.SetClearPoint = function(self, ...)
	self:ClearAllPoints()
	self:SetPoint(...)
end

addon.api.SetShownReq = function(self, reqshow)
	if reqshow then
		self:Show()
	else
		self:Hide()
	end
end

addon.functions.SetThreeSlice = function(button)
	local parent = button:GetParent()
	parent.divider_top = parent:CreateTexture(nil, 'BORDER')
	parent.divider_top:SetPoint('TOPLEFT', button, 'BOTTOMRIGHT', -3, 39)
	parent.divider_top:set_atlas('ui-hud-actionbar-frame-divider-threeslice-edgetop', true)
	
	parent.divider_bottom = parent:CreateTexture(nil, 'BORDER')
	parent.divider_bottom:SetPoint('TOPLEFT', button, 'BOTTOMRIGHT', -3, 9)
	parent.divider_bottom:set_atlas('ui-hud-actionbar-frame-divider-threeslice-edgebottom', true)
	
	parent.divider_mid = parent:CreateTexture(nil, 'BORDER')
	parent.divider_mid:SetPoint('CENTER', parent.divider_top, 0, -15)
	parent.divider_mid:SetPoint('CENTER', parent.divider_bottom, 0, 15)
	parent.divider_mid:set_atlas('!ui-hud-actionbar-frame-divider-threeslice-center', true)
end

addon.functions.SetNumPagesButton = function(self, parent, direct, yOffset)
	for index=1,self:GetNumRegions() do
		local button = select(index, self:GetRegions())
		if button and button:GetObjectType() == 'Texture' then
			button:SetClearPoint('CENTER')
		end
	end
	self:SetParent(parent)
	self:SetClearPoint('TOPLEFT', parent, 'TOPLEFT', -30, yOffset)
	self:GetNormalTexture():set_atlas('ui-hud-actionbar-'..direct..'-normal', true)
	self:GetPushedTexture():set_atlas('ui-hud-actionbar-'..direct..'-pushed', true)
	self:GetHighlightTexture():set_atlas('ui-hud-actionbar-'..direct..'-highlight', true)
end

addon.functions.inject_api = function(object)
	local mt = getmetatable(object).__index
	for API,FUNCTIONS in pairs(addon.api) do
		if not object[API] then
			mt[API] = addon.api[API]
		end
	end
end

addon.initialize = function(self)
	local handled = {['Frame'] = true}
	local object = CreateFrame('Frame')
	local inject_api = self.functions.inject_api

	inject_api(object)
	inject_api(object:CreateTexture())
	inject_api(object:CreateFontString())

	object = EnumerateFrames()

	while object do
		if not handled[object:GetObjectType()] then
			inject_api(object)
			handled[object:GetObjectType()] = true
		end
		object = EnumerateFrames(object)
	end
end
addon:initialize();