--[[
================================================================================
DragonUI - Locale Override Bootstrap
================================================================================
Reads the user's locale preference from the DragonUIDB SavedVariable BEFORE
AceDB:New() runs (AceDB initializes in core.lua:OnInitialize, which fires on
PLAYER_LOGIN — long after the locale files have been evaluated).

The override is stored in the AceDB **global** namespace
(_G.DragonUIDB.global.locale), so it persists across characters and profiles
and is available in raw SavedVar form whenever this file is evaluated.

Resolution order:
  1. _G.DragonUIDB.global.locale  (user override from the General tab dropdown)
  2. GetLocale()                  (client language, "enGB" normalised to "enUS")

A value of "auto" (or nil/empty) means "follow the client language".
================================================================================
]]

local addon = select(2, ...)
if not addon then return end

local CLIENT_LOCALE = GetLocale()
if CLIENT_LOCALE == "enGB" then
    CLIENT_LOCALE = "enUS"
end

-- Set of locales DragonUI ships translations for.
local SUPPORTED = {
    enUS = true, esES = true, esMX = true, ptBR = true,
    deDE = true, frFR = true, ruRU = true,
    zhCN = true, zhTW = true, koKR = true,
}

function addon.GetActiveLocale()
    local sv = _G.DragonUIDB
    local pref = sv and sv.global and sv.global.locale
    if type(pref) == "string" and pref ~= "" and pref ~= "auto" and SUPPORTED[pref] then
        return pref
    end
    return CLIENT_LOCALE
end

-- Exposed for the options panel / dropdown UI.
addon.SUPPORTED_LOCALES = SUPPORTED
addon.CLIENT_LOCALE = CLIENT_LOCALE
