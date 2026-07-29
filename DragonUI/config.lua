-- ============================================================================
-- DragonUI - Configuration Layer
-- Metatable-based config wrapper that routes to database or static values.
-- Initialized early so core/ files and modules can use localization.
-- ============================================================================

local addon = select(2,...);

-- Localization (must load before any core/ file that references addon.L)
addon.L = LibStub("AceLocale-3.0"):GetLocale("DragonUI")

addon._dir = [[Interface\AddOns\DragonUI\Textures\]];

-- Use centralized font system (loaded via core/fonts.lua before this file)
local _actionbarFont = addon.Fonts.ACTIONBAR

-- Static assets (not backed by database)
local static_assets = {
	font = _actionbarFont,
	normal = addon._dir..'ActionBars\\uiactionbariconframe.tga',
	highlight = addon._dir..'ActionBars\\uiactionbariconframehighlight.tga',
};

-- Static font definitions for button text elements
local static_fonts = {
	count_font = {_actionbarFont, 14, 'OUTLINE'},
	hotkey_font = {_actionbarFont, 14, ''},
	macros_font = {_actionbarFont, 14, ''},
	pages_font = {_actionbarFont, 14, ''},
	cooldown_font = {_actionbarFont, 14, 'OUTLINE'},
};

local function GetProfileValue(section, key, subkey)
	local db = addon.db
	if not (db and db.profile) then
		return nil
	end

	local sectionTable = db.profile[section]
	if sectionTable == nil then
		return nil
	end

	if key == nil then
		return sectionTable
	end

	local keyValue = sectionTable[key]
	if keyValue == nil then
		return nil
	end

	if subkey == nil then
		return keyValue
	end

	if type(keyValue) ~= "table" then
		return nil
	end

	return keyValue[subkey]
end

-- Config wrapper: routes access through metatables to database or static values
addon.config = {};

-- Proxies hold no data (every read hits addon.db.profile), so one per section is
-- profile-switch safe and stops hot event paths allocating a table per access.
local proxyCache = {};

setmetatable(addon.config, {
	__index = function(t, section)
		if section == "assets" then
			return static_assets;
		end

		local cached = proxyCache[section];
		if cached then
			return cached;
		end

		-- Dynamic proxy: delegates lookups to addon.db.profile[section]
		local proxy = {};
		setmetatable(proxy, {
			__index = function(pt, key)
				if section == "map" and key == "border_point" then
					return {'CENTER', 0, 100};
				end
				
				-- Buttons section: proxy font tables as static values
				if section == "buttons" then
					if key == "count" then
						local count_proxy = {};
						setmetatable(count_proxy, {
							__index = function(cpt, ckey)
								if ckey == "font" then
									return static_fonts.count_font;
								elseif ckey == "position" then
									return {'BOTTOMRIGHT', 2, -1};
								else
									return GetProfileValue(section, key, ckey);
								end
							end
						});
						return count_proxy;
					elseif key == "hotkey" then
						local hotkey_proxy = {};
						setmetatable(hotkey_proxy, {
							__index = function(hpt, hkey)
								if hkey == "font" then
									return static_fonts.hotkey_font;
								else
									return GetProfileValue(section, key, hkey);
								end
							end
						});
						return hotkey_proxy;
					elseif key == "macros" then
						local macros_proxy = {};
						setmetatable(macros_proxy, {
							__index = function(mpt, mkey)
								if mkey == "font" then
									return static_fonts.macros_font;
								else
									return GetProfileValue(section, key, mkey);
								end
							end
						});
						return macros_proxy;
					elseif key == "pages" then
						local pages_proxy = {};
						setmetatable(pages_proxy, {
							__index = function(ppt, pkey)
								if pkey == "font" then
									return static_fonts.pages_font;
								else
									return GetProfileValue(section, key, pkey);
								end
							end
						});
						return pages_proxy;
					elseif key == "cooldown" then
						local cooldown_proxy = {};
						setmetatable(cooldown_proxy, {
							__index = function(cpt, ckey)
								if ckey == "font" then
									return static_fonts.cooldown_font;
								elseif ckey == "position" then
									return {'BOTTOM'};
								else
									return GetProfileValue(section, key, ckey);
								end
							end
						});
						return cooldown_proxy;
					end
				end
				
				-- Nested table proxy (delegates to database)
				if type(GetProfileValue(section, key)) == "table" then
					local nested_proxy = {};
					setmetatable(nested_proxy, {
						__index = function(npt, nkey)
							-- Vehicle position is static, not stored in database
							if section == "additional" and key == "vehicle" and nkey == "position" then
								return {'BOTTOMLEFT', -52, 0};
							end
							return GetProfileValue(section, key, nkey);
						end
					});
					return nested_proxy;
				end
				
				return GetProfileValue(section, key);
			end
		});
		proxyCache[section] = proxy;
		return proxy;
	end
});
