-- ============================================================================
-- DragonUI - Centralized Font System
-- Single source of truth for locale-aware font selection.
-- Loaded early (via DragonUI.xml) so config.lua, database.lua, and all modules
-- can reference addon.Fonts instead of hardcoding font paths.
-- ============================================================================
--
-- WoW 3.3.5a ships different fonts per locale:
--   enUS/deDE/frFR/esES/esMX/ptBR : Fonts\FRIZQT__.TTF  + Fonts\ARIALN.TTF
--   ruRU                           : Fonts\FRIZQT___CYR.TTF (Cyrillic glyphs)
--   koKR                           : Fonts\2002.TTF (Korean CJK glyphs)
--   zhCN                           : Fonts\ZYKai_T.TTF (Simplified Chinese)
--   zhTW                           : Fonts\bLEI00D.TTF (Traditional Chinese)
--
-- Custom fonts (expressway.ttf, PTSansNarrow.ttf) lack CJK/Cyrillic glyphs
-- and render as "???" on those clients. This module selects the correct
-- system font for each locale, falling back to the custom font when safe.
-- ============================================================================

local addon = select(2, ...)

local _locale = GetLocale()

-- ============================================================================
-- FONT TABLES PER LOCALE
-- ============================================================================

-- CJK/Cyrillic font map: locale -> system font that contains the required glyphs
local LOCALE_SYSTEM_FONTS = {
    koKR = "Fonts\\2002.TTF",
    zhCN = "Fonts\\ZYKai_T.TTF",
    zhTW = "Fonts\\bLEI00D.TTF",
    ruRU = "Fonts\\FRIZQT___CYR.TTF",
}

-- Does this locale need a system font instead of custom Latin-only fonts?
local _needsSystemFont = (LOCALE_SYSTEM_FONTS[_locale] ~= nil)

-- ============================================================================
-- RESOLVED FONT PATHS
-- ============================================================================

local Fonts = {}

--- Primary UI font (unit frames, tooltips, game menu, general text).
-- Uses FRIZQT__.TTF on Latin locales, locale-specific font on CJK/Cyrillic.
Fonts.PRIMARY = LOCALE_SYSTEM_FONTS[_locale] or "Fonts\\FRIZQT__.TTF"

--- Action bar font (hotkeys, macros, cooldowns, page numbers).
-- Uses expressway.ttf on Latin locales for a modern Dragonflight look,
-- falls back to the locale system font on CJK/Cyrillic.
Fonts.ACTIONBAR = _needsSystemFont
    and LOCALE_SYSTEM_FONTS[_locale]
    or [[Interface\AddOns\DragonUI\Textures\expressway.ttf]]

--- Narrow UI font (options panel, editor mode labels).
-- PTSansNarrow.ttf on Latin locales, locale system font on CJK/Cyrillic.
Fonts.NARROW = _needsSystemFont
    and LOCALE_SYSTEM_FONTS[_locale]
    or [[Interface\AddOns\DragonUI_Options\fonts\PTSansNarrow.ttf]]

--- ARIALN replacement: used where database defaults previously hardcoded ARIALN.
-- On Latin locales ARIALN is fine; on CJK/Cyrillic we substitute the system font.
Fonts.ARIALN = LOCALE_SYSTEM_FONTS[_locale] or "Fonts\\ARIALN.TTF"

--- Whether the current locale requires a system font (CJK or Cyrillic).
Fonts.needsSystemFont = _needsSystemFont

--- The raw locale string (e.g. "enUS", "koKR").
Fonts.locale = _locale

-- ============================================================================
-- EXPORT
-- ============================================================================

addon.Fonts = Fonts
