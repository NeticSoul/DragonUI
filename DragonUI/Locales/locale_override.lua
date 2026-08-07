local addon = select(2, ...)
if not addon then return end

-- Set of locales DragonUI ships translations for.
local SUPPORTED = {
    enUS = true, esES = true, esMX = true, ptBR = true,
    deDE = true, frFR = true, ruRU = true,
    zhCN = true, zhTW = true, koKR = true,
}

local CLIENT_LOCALE = GetLocale()
if CLIENT_LOCALE == "enGB" then
    CLIENT_LOCALE = "enUS"
end
-- Private-server clients report locales we ship nothing for (enCN, enTW, itIT); without this
-- GetLocale would resolve to nil and every addon.L lookup would error.
if not SUPPORTED[CLIENT_LOCALE] then
    CLIENT_LOCALE = "enUS"
end

-- core/fonts.lua picks the UI font from the *client* locale, and a Latin client font carries no
-- Cyrillic or CJK glyphs, so those languages would render the whole UI as "?".
local SCRIPT = { ruRU = "cyrillic", zhCN = "hans", zhTW = "hant", koKR = "hangul" }

function addon.CanRenderLocale(locale)
    local needs = SCRIPT[locale]
    return not needs or needs == SCRIPT[CLIENT_LOCALE]
end

-- SavedVariables load *after* the addon's files (see ADDON_LOADED), so at file scope this can only
-- return the client locale; addon.RefreshLocale() re-resolves it from AceDB in OnInitialize.
function addon.GetActiveLocale()
    local pref
    if addon.db and addon.db.global then
        pref = addon.db.global.locale
    else
        local sv = _G.DragonUIDB
        pref = sv and sv.global and sv.global.locale
    end
    if type(pref) == "string" and SUPPORTED[pref] and addon.CanRenderLocale(pref) then
        return pref
    end
    return CLIENT_LOCALE
end

-- Exposed for the options panel / dropdown UI.
addon.SUPPORTED_LOCALES = SUPPORTED
addon.CLIENT_LOCALE = CLIENT_LOCALE
