--- **AceLocale-3.0-DragonUI** manages localization in addons, allowing for multiple locale to be registered with fallback to the base locale for untranslated strings.
-- Fork of AceLocale-3.0 (ElvUI-style): NewLocale always loads every locale (no GAME_LOCALE gating),
-- and GetLocale accepts a `locale` arg to pick the active locale. Lets users override the client
-- locale at runtime via a dropdown + ReloadUI.
-- @class file
-- @name AceLocale-3.0-DragonUI
-- @release forked from AceLocale-3.0.lua r895
local MAJOR,MINOR = "AceLocale-3.0-DragonUI", 2

local AceLocale, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceLocale then return end -- no upgrade needed

-- Lua APIs
local assert, tostring, error, getmetatable = assert, tostring, error, getmetatable
local setmetatable, rawset, rawget = setmetatable, rawset, rawget

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GAME_LOCALE, geterrorhandler

local gameLocale = GetLocale()
if gameLocale == "enGB" then
	gameLocale = "enUS"
end

AceLocale.apps = AceLocale.apps or {}                    -- array of ["AppName"]=localetableref
AceLocale.appnames = AceLocale.appnames or {}            -- array of [localetableref]="AppName"
AceLocale.defaultlocales = AceLocale.defaultlocales or {} -- array of ["AppName"]="enUS"

-- This metatable is used on all tables returned from GetLocale
local readmeta = {
	__index = function(self, key) -- requesting totally unknown entries: fire off a nonbreaking error and return key
		rawset(self, key, key)      -- only need to see the warning once, really
		geterrorhandler()(MAJOR..": "..tostring(AceLocale.appnames[self])..": Missing entry for '"..tostring(key).."'")
		return key
	end
}

-- This metatable is used on all tables returned from GetLocale if the silent flag is true, it does not issue a warning on unknown keys
local readmetasilent = {
	__index = function(self, key) -- requesting totally unknown entries: return key
		rawset(self, key, key)      -- only need to invoke this function once
		return key
	end
}

-- Remember the locale table being registered right now (it gets set by :NewLocale())
-- NOTE: Do never try to register 2 locale tables at once and mix their definition.
local registering

-- local assert false function
local assertfalse = function() assert(false) end

-- This metatable proxy is used when registering nondefault locales
local writeproxy = setmetatable({}, {
	__newindex = function(self, key, value)
		rawset(registering, key, value == true and key or value) -- assigning values: replace 'true' with key string
	end,
	__index = assertfalse
})

-- This metatable proxy is used when registering the default locale.
-- It refuses to overwrite existing values
-- Reason 1: Allows loading locales in any order
-- Reason 2: If 2 modules have the same string, but only the first one to be
--           loaded has a translation for the current locale, the translation
--           doesn't get overwritten.
--
local writedefaultproxy = setmetatable({}, {
	__newindex = function(self, key, value)
		if not rawget(registering, key) then
			rawset(registering, key, value == true and key or value)
		end
	end,
	__index = assertfalse
})

--- Register a new locale (or extend an existing one) for the specified application.
-- :NewLocale will return a table you can fill your locale into. Unlike stock AceLocale it never
-- returns nil, since every locale is kept so the user can switch language at runtime.
-- @paramsig application, locale[, isDefault[, silent]]
-- @param application Unique name of addon / module
-- @param locale Name of the locale to register, e.g. "enUS", "deDE", etc.
-- @param isDefault If this is the default locale being registered (your addon is written in this language, generally enUS)
-- @param silent If true, the locale will not issue warnings for missing keys. Must be set on the first locale registered.
-- @usage
-- -- enUS.lua
-- local L = LibStub("AceLocale-3.0-DragonUI"):NewLocale("DragonUI", "enUS", true)
-- L["string1"] = true
--
-- -- deDE.lua
-- local L = LibStub("AceLocale-3.0-DragonUI"):NewLocale("DragonUI", "deDE")
-- if not L then return end
-- L["string1"] = "Zeichenkette1"
-- @return Locale Table to add localizations to.
function AceLocale:NewLocale(application, locale, isDefault, silent)
	local app = AceLocale.apps[application]

	if silent and app and getmetatable(app) ~= readmetasilent then
		geterrorhandler()("Usage: NewLocale(application, locale[, isDefault[, silent]]): 'silent' must be specified for the first locale registered")
	end

	if not app then
		app = setmetatable({}, silent and readmetasilent or readmeta)
		AceLocale.apps[application] = app
		AceLocale.appnames[app] = application
	end

	-- DragonUI block (ElvUI-style): keep every locale in its own subtable, no GAME_LOCALE gating.
	-- NOTE: rawget/rawset throughout — the app table carries readmeta, so a plain index would
	-- fire "Missing entry" errors for locales that aren't registered yet.
	if type(rawget(app, locale)) ~= "table" then
		rawset(app, locale, {})
	end
	if isDefault then
		AceLocale.defaultlocales[application] = locale
	end

	registering = rawget(app, locale) -- remember globally for writeproxy and writedefaultproxy
	-- end block

	if isDefault then
		return writedefaultproxy
	end

	return writeproxy
end

--- Returns localizations for the requested locale (or the default locale if translations are missing).
-- Errors if nothing is registered (spank developer, not just a missing translation)
-- @param application Unique name of addon / module
-- @param locale Optional locale name (e.g. "esES"). Falls back to the client locale, then the default locale.
-- @param silent If true, the locale is optional, silently return nil if it's not found (defaults to false, optional)
-- @return The locale table for the requested (or current) language.
--- Modified by DragonUI to add `locale` as second arg
function AceLocale:GetLocale(application, locale, silent)
	if type(locale) == "boolean" then
		silent = locale
		locale = nil
	end

	local app = AceLocale.apps[application]
	if not app then
		if silent then return nil end
		error("Usage: GetLocale(application[, locale[, silent]]): 'application' - No locales registered for '"..tostring(application).."'", 2)
	end

	local defaulttbl = rawget(app, AceLocale.defaultlocales[application] or "enUS")

	local tbl = locale and rawget(app, locale)
	if type(tbl) ~= "table" then tbl = rawget(app, gameLocale) end
	if type(tbl) ~= "table" then tbl = defaulttbl end
	if type(tbl) ~= "table" then return nil end

	-- The default locale keeps the app's own silent/noisy setting, so a key missing from *every*
	-- locale still reports "Missing entry" the way stock AceLocale did.
	if defaulttbl and not getmetatable(defaulttbl) then
		AceLocale.appnames[defaulttbl] = application
		setmetatable(defaulttbl, getmetatable(app) or readmetasilent)
	end

	-- Partial translations must fall through to the default locale; many keys are symbolic ids
	-- ("MainBar", "LFGFrame"), so surfacing the raw key would leak them into the UI.
	if tbl ~= defaulttbl and not getmetatable(tbl) then
		setmetatable(tbl, {
			__index = function(self, key)
				local value = defaulttbl and defaulttbl[key]
				if value == nil then value = key end
				rawset(self, key, value)
				return value
			end,
		})
	end

	return tbl
end
