-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- What each window drew on its first open (measured in game), loaded with the world so slow PCs skip that stall.
local WINDOWS = {
    characterpanel = {
        "CharacterPanel\\characterinfoclasses-a", "CharacterPanel\\characterpanelbackground",
        "CharacterPanel\\charpaperdollparts", "CharacterPanel\\paperdollsidebartabs", "CharacterPanel\\scrollbarthumb",
        "CharacterPanel\\scrollbararrows", "CharacterPanel\\commonbuttons", "CharacterPanel\\commonicons",
        "UI\\redbutton2x", "UI\\redbutton3slice", "UI\\ui-background-rock", "UI\\uiframe-inner",
        "UI\\uiframe-inner-vertical", "UI\\uiframeinner", "UI\\uiframemetal2x", "UI\\uiframemetalhorizontal2x",
        "UI\\uiframemetalvertical2x", "UI\\uiframetabs", "WorldMap\\questlog",
    },
    spellbook = {
        "Collections\\UI-Searchbox-Icon", "Spellbook\\spellbook-background", "Spellbook\\spellbook-background_r",
        "Spellbook\\spellbook-ribbon",
        "Spellbook\\spellbookelements", "UI\\redbutton2x", "UI\\uiframemetal2x", "UI\\uiframemetalhorizontal2x",
        "UI\\uiframemetalvertical2x", "UI\\uiframetabs", "WorldMap\\questlog",
    },
    talents = {
        "Talents\\talentframeatlas", "Talents\\talents-animations-clouds", "Talents\\talents-animations-clouds_r",
        "Talents\\talents-animations-particles", "Talents\\talents-animations-particles_r",
        "Talents\\talents-arrows", "Talents\\talents-edge", "Talents\\talents-edge-coarse", "Talents\\talents-line",
        "Talents\\talents-sheet", "Talents\\talents-sheen-apex", "Talents\\talents-sheen-capstonesquare",
        "Talents\\talents-sheen-small", "Talents\\glyph-globe-health", "Talents\\glyph-globe-mana",
        "Talents\\glyph-ring-desat", "Talents\\glyph-ring-gold", "Talents\\glyph-effects-card",
        "Talents\\glyph-orbgloss", "UI\\dropdownbutton", "UI\\redbutton3slice",
    },
    collections = {
        "ActionBars\\uiactionbariconframe_white", "CharacterPanel\\scrollbararrows", "CharacterPanel\\scrollbarthumb",
        "Collections\\FavoritesIcon", "Collections\\IconFrameGold", "Collections\\ListButtons",
        "Collections\\MountJournal-BG", "Collections\\MountJournalIcons", "Collections\\MountPortrait",
        "UI\\ui-background-marble", "UI\\ui-background-rock", "UI\\uiframe-inner", "UI\\uiframe-inner-vertical",
        "UI\\uiframeinner",
    },
    worldmap = {
        "CharacterPanel\\collapsebuttons", "CharacterPanel\\scrollbararrows", "CharacterPanel\\scrollbarthumb",
        "UI\\ui-background-rock", "UI\\uiframe-inner", "UI\\uiframe-inner-vertical", "UI\\uiframeinner",
        "WorldMap\\mapfilter", "WorldMap\\mappins", "WorldMap\\navbar", "WorldMap\\navbar-tile", "WorldMap\\poiicons",
        "WorldMap\\questcollapse", "WorldMap\\questlog-background", "WorldMap\\questtypeicons",
        "WorldMap\\squarebuttons", "WorldMap\\trackingborder", "WorldMap\\zoomhighlight",
    },
    bagster = {
        "Bags\\INV_Misc_Bag_08_round", "Bags\\bagsitemslot2x", "Coins\\coincopper", "Coins\\coingold",
        "Coins\\coinsilver", "Coins\\commoncoinbox", "Coins\\commoncurrencybox", "UI\\buttonhilight-square",
        "UI\\ui-background-rock", "UI\\ui-quickslot2",
    },
    addonmanager = { "ForeverUI\\chrome-dialog", "ForeverUI\\chrome-frame", "ForeverUI\\controls-basic" },
}

-- DragonUI's own windows, there whatever modules are on: the options panel and editor mode.
local ALWAYS = {
    "ForeverUI\\chrome-options", "ForeverUI\\controls-dropdown", "Editmode\\editmodeui",
    "Editmode\\editmodeuihighlightbackground", "Editmode\\editmodeuivertical",
}

addon:RegisterTextureWarmup(function()
    local files = {}
    local function add(rel) files[#files + 1] = addon._dir .. rel end
    for _, rel in ipairs(ALWAYS) do add(rel) end
    for module, list in pairs(WINDOWS) do
        if addon:IsModuleEnabled(module) then
            for _, rel in ipairs(list) do add(rel) end
        end
    end
    local class = select(2, UnitClass("player"))
    if class and (addon:IsModuleEnabled("spellbook") or addon:IsModuleEnabled("talents")) then
        add("ClassIcons\\" .. class)
    end
    -- The talent window paints the class's art for whichever tree is open: every tree of this class.
    if class and addon:IsModuleEnabled("talents") and addon.atlasinfo then
        local prefix = "talents-background-" .. class:lower() .. "-"
        for name, entry in pairs(addon.atlasinfo) do
            if name:sub(1, #prefix) == prefix then
                files[#files + 1] = entry[1]
                files[#files + 1] = entry[1] .. "_r"
            end
        end
    end
    return files
end)
