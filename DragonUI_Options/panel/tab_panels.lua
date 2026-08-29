-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - Panels Tab
================================================================================
The reskinned Blizzard windows: Character Panel, Pets & Mounts, World Map and Loot Window.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- HELPERS
-- ============================================================================

local function EnsureModuleTable(moduleName)
    return C:EnsureModuleTable(moduleName)
end

local function GetModuleField(moduleName, field)
    local m = addon.db.profile.modules
    return m and m[moduleName] and m[moduleName][field]
end

local function IsEnabled(moduleName)
    return GetModuleField(moduleName, "enabled") == true
end

-- ============================================================================
-- SUB-TABS
-- ============================================================================

local activeSubTab = "character"

local subTabs = {
    { key = "character",   label = LO["Character"] },
    { key = "collections", label = LO["Pets & Mounts"] },
    { key = "worldmap",    label = LO["World Map"] },
    { key = "loot",        label = LO["Loot Window"] },
}

-- Search navigation sub-tab setter.
Panel.subTabSetters = Panel.subTabSetters or {}
Panel.subTabSetters["panels"] = function(key) activeSubTab = key or "character" end

-- ============================================================================
-- CHARACTER PANEL
-- ============================================================================

local function BuildCharacterSubTab(scroll)
    local cpSection = C:AddSection(scroll, LO["Character Panel"])

    C:AddDescription(cpSection, LO["Modern reskin of the Blizzard character window."])

    C:AddToggle(cpSection, {
        label = LO["Enable Character Panel"],
        desc = LO["Apply the DragonUI reskin to the character window."],
        getFunc = function() return IsEnabled("characterpanel") end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").enabled = val
            if val then
                if addon.ApplyCharacterPanelSystem then addon.ApplyCharacterPanelSystem() end
            else
                if addon.RestoreCharacterPanelSystem then addon.RestoreCharacterPanelSystem() end
            end
            Panel:SelectTab("panels")
        end,
        requiresReload = true,
    })

    C:AddToggle(cpSection, {
        label = LO["Class Portrait"],
        desc = LO["Show your class icon in the portrait instead of your character's face."],
        getFunc = function()
            return GetModuleField("characterpanel", "class_portrait") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").class_portrait = val
            if addon.CharacterPanel and addon.CharacterPanel.UpdatePortrait then
                addon.CharacterPanel.UpdatePortrait()
            end
        end,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = false,
    })

    C:AddToggle(cpSection, {
        label = LO["Class-Colored Level Text"],
        desc = LO["Color the class name in the \"Level X Race Class\" line."],
        getFunc = function()
            return GetModuleField("characterpanel", "class_level_text") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").class_level_text = val
            if addon.CharacterPanel and addon.CharacterPanel.RefreshLevelText then
                addon.CharacterPanel.RefreshLevelText()
            end
        end,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = true,
    })

    C:AddToggle(cpSection, {
        label = LO["Hide Model Controls"],
        desc = LO["Hide the rotate, zoom and reset buttons over the character model."],
        getFunc = function()
            return GetModuleField("characterpanel", "hide_model_controls") == true
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").hide_model_controls = val
            -- Rebuilt so the sub-option below picks up its new disabled state.
            Panel:SelectTab("panels")
        end,
        callback = function()
            local CP = addon.CharacterPanel
            if CP and CP.RefreshModelControls then CP.RefreshModelControls() end
        end,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = false,
    })

    C:AddToggle(cpSection, {
        label = LO["Keep the Reset Button"],
        desc = LO["Leave the reset button on its own while the rest of the model controls stay hidden."],
        indent = 18,
        getFunc = function()
            return GetModuleField("characterpanel", "model_controls_reset_only") == true
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").model_controls_reset_only = val
        end,
        callback = function()
            local CP = addon.CharacterPanel
            if CP and CP.RefreshModelControls then CP.RefreshModelControls() end
        end,
        disabled = function()
            return not IsEnabled("characterpanel")
                or GetModuleField("characterpanel", "hide_model_controls") ~= true
        end,
        requiresReload = false,
    })

    -- ====================================================================
    -- STATS SIDEBAR
    -- ====================================================================
    C:AddSpacer(scroll)
    local statsSection = C:AddSection(scroll, LO["Stats Sidebar"])

    C:AddDescription(statsSection, LO["The headline numbers above the stat categories."])

    local function RefreshSummary()
        local CP = addon.CharacterPanel
        if CP and CP.ApplyGearSummaryVisibility then CP.ApplyGearSummaryVisibility() end
    end

    C:AddToggle(statsSection, {
        label = LO["Show Item Level"],
        desc = LO["Show the average item level of your equipped gear."],
        getFunc = function()
            return GetModuleField("characterpanel", "show_item_level") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").show_item_level = val
        end,
        callback = RefreshSummary,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = false,
    })

    C:AddToggle(statsSection, {
        label = LO["Show GearScore"],
        desc = LO["Show the GearScore of your equipped gear."],
        getFunc = function()
            return GetModuleField("characterpanel", "show_gear_score") == true
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").show_gear_score = val
        end,
        callback = RefreshSummary,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = false,
    })

    C:AddDescription(statsSection, LO["Set which stat and which combat panel lead the list:"])

    C:AddDropdown(statsSection, {
        label = LO["Highlight Main Stat"],
        desc = LO["The attribute your class is built around."],
        values = {
            auto = LO["Auto (by class)"],
            off = LO["Off"],
            STRENGTH = _G.SPELL_STAT1_NAME,
            AGILITY = _G.SPELL_STAT2_NAME,
            STAMINA = _G.SPELL_STAT3_NAME,
            INTELLECT = _G.SPELL_STAT4_NAME,
            SPIRIT = _G.SPELL_STAT5_NAME,
        },
        getFunc = function()
            return GetModuleField("characterpanel", "stat_highlight") or "auto"
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").stat_highlight = val
        end,
        callback = function()
            local CP = addon.CharacterPanel
            if CP and CP.RefreshSidebar then CP.RefreshSidebar() end
        end,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = false,
    })

    C:AddDropdown(statsSection, {
        label = LO["Combat Statistics"],
        desc = LO["Which one leads the list: Melee, Ranged, or Spell."],
        values = {
            auto = LO["Auto (by class)"],
            off = LO["Off"],
            PLAYERSTAT_MELEE_COMBAT = _G.PLAYERSTAT_MELEE_COMBAT,
            PLAYERSTAT_RANGED_COMBAT = _G.PLAYERSTAT_RANGED_COMBAT,
            PLAYERSTAT_SPELL_COMBAT = _G.PLAYERSTAT_SPELL_COMBAT,
        },
        getFunc = function()
            return GetModuleField("characterpanel", "combat_order") or "auto"
        end,
        setFunc = function(val)
            EnsureModuleTable("characterpanel").combat_order = val
        end,
        callback = function()
            local CP = addon.CharacterPanel
            if CP and CP.ApplyStatsAutoSort then CP.ApplyStatsAutoSort() end
        end,
        disabled = function() return not IsEnabled("characterpanel") end,
        requiresReload = false,
    })
end

-- ============================================================================
-- PETS & MOUNTS
-- ============================================================================

local function BuildCollectionsSubTab(scroll)
    local colSection = C:AddSection(scroll, LO["Pets & Mounts"])

    C:AddDescription(colSection, LO["A dedicated window for your mounts and companion pets, replacing the old Pet tab of the character window."])

    C:AddToggle(colSection, {
        label = LO["Enable Pets & Mounts"],
        desc = LO["Add the Pets & Mounts micro menu button and its window."],
        getFunc = function() return IsEnabled("collections") end,
        setFunc = function(val)
            EnsureModuleTable("collections").enabled = val
            if val then
                if addon.ApplyCollectionsSystem then addon.ApplyCollectionsSystem() end
            else
                if addon.RestoreCollectionsSystem then addon.RestoreCollectionsSystem() end
            end
        end,
        requiresReload = true,
    })

    -- ====================================================================
    -- KEY BINDING
    -- ====================================================================
    C:AddSpacer(scroll)
    local keySection = C:AddSection(scroll, LO["Key Binding"])

    C:AddDescription(keySection, LO["Opens the window without the micro menu."])

    C:AddKeybinding(keySection, {
        label = LO["Toggle Pets & Mounts"],
        desc = LO["Click, then press the key to bind. Press Escape to clear it."],
        action = "DRAGONUI_TOGGLE_COLLECTIONS",
        width = 240,
    })
end

-- ============================================================================
-- WORLD MAP
-- ============================================================================

local function BuildWorldMapSubTab(scroll)
    local mapSection = C:AddSection(scroll, LO["World Map"])

    C:AddDescription(mapSection, LO["Retail-style world map with breadcrumb navigation and a quest log side panel."])

    C:AddToggle(mapSection, {
        label = LO["Enable World Map"],
        desc = LO["Apply the DragonUI reskin to the world map."],
        getFunc = function() return IsEnabled("worldmap") end,
        setFunc = function(val)
            EnsureModuleTable("worldmap").enabled = val
            if val and addon.ApplyWorldMapSystem then addon.ApplyWorldMapSystem() end
            Panel:SelectTab("panels")
        end,
        requiresReload = true,
    })

    C:AddToggle(mapSection, {
        label = LO["Show Undiscovered Areas"],
        desc = LO["Draw the map art of areas you have not explored yet, dimmed."],
        getFunc = function() return GetModuleField("worldmap", "fog") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("worldmap").fog = val
            if addon.RefreshWorldMapSystem then addon.RefreshWorldMapSystem() end
        end,
        disabled = function() return not IsEnabled("worldmap") end,
        requiresReload = false,
    })

    C:AddToggle(mapSection, {
        label = LO["Show Dungeon Entrances"],
        desc = LO["Show dungeon and raid entrance pins on zone maps."],
        getFunc = function() return GetModuleField("worldmap", "entrances") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("worldmap").entrances = val
            if addon.RefreshWorldMapSystem then addon.RefreshWorldMapSystem() end
        end,
        disabled = function() return not IsEnabled("worldmap") end,
        requiresReload = false,
    })

    C:AddToggle(mapSection, {
        label = LO["Show Graveyards"],
        desc = LO["Show graveyard pins on zone maps."],
        getFunc = function() return GetModuleField("worldmap", "graveyards") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("worldmap").graveyards = val
            if addon.RefreshWorldMapSystem then addon.RefreshWorldMapSystem() end
        end,
        disabled = function() return not IsEnabled("worldmap") end,
        requiresReload = false,
    })

    C:AddToggle(mapSection, {
        label = LO["Show Flight Points"],
        desc = LO["Show flight master pins on zone maps."],
        getFunc = function() return GetModuleField("worldmap", "flightPoints") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("worldmap").flightPoints = val
            if addon.RefreshWorldMapSystem then addon.RefreshWorldMapSystem() end
        end,
        disabled = function() return not IsEnabled("worldmap") end,
        requiresReload = false,
    })

    C:AddToggle(mapSection, {
        label = LO["Show Landmarks"],
        desc = LO["Show towns, flight points and other landmark pins on the map."],
        getFunc = function() return GetModuleField("worldmap", "landmarks") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("worldmap").landmarks = val
            if addon.RefreshWorldMapSystem then addon.RefreshWorldMapSystem() end
        end,
        disabled = function() return not IsEnabled("worldmap") end,
        requiresReload = false,
    })
end

-- ============================================================================
-- LOOT WINDOW
-- ============================================================================

local function BuildLootSubTab(scroll)
    local lootSection = C:AddSection(scroll, LO["Loot Window"])

    C:AddDescription(lootSection, LO["Configure the DragonUI loot window."])

    C:AddToggle(lootSection, {
        label = LO["Enable Loot Window"],
        desc = LO["Apply the DragonUI skin to the Blizzard loot window."],
        getFunc = function() return IsEnabled("loot_skin") end,
        setFunc = function(val)
            EnsureModuleTable("loot_skin").enabled = val
            if addon.LootSkinModule then addon.LootSkinModule:Refresh() end
            Panel:SelectTab("panels")
        end,
        requiresReload = false,
    })

    C:AddToggle(lootSection, {
        label = LO["Open at Cursor"],
        desc = LO["Open the loot window at the cursor instead of its saved position."],
        getFunc = function()
            return GetCVar and GetCVar("lootUnderMouse") == "1"
        end,
        setFunc = function(val)
            if SetCVar then SetCVar("lootUnderMouse", val and "1" or "0") end
            if addon.LootSkinModule then addon.LootSkinModule:ApplySavedPosition() end
        end,
        disabled = function() return not IsEnabled("loot_skin") end,
        requiresReload = false,
    })

    C:AddDescription(lootSection, LO["Disable Open at Cursor, then drag the loot window to save its position."])

    C:AddToggle(lootSection, {
        label = LO["Animate Loot Reflow"],
        desc = LO["Smoothly close gaps and resize the loot window after collecting items."],
        getFunc = function()
            return GetModuleField("loot_skin", "animated_reflow") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("loot_skin").animated_reflow = val
            if addon.LootSkinModule then addon.LootSkinModule:RefreshSettings() end
        end,
        disabled = function() return not IsEnabled("loot_skin") end,
        requiresReload = false,
    })

    C:AddButton(lootSection, {
        label = LO["Reset Loot Window Position"],
        desc = LO["Clear the saved position. The Blizzard default will be used next time you open the loot window."],
        callback = function()
            if addon.LootSkinModule then addon.LootSkinModule:ResetPosition() end
        end,
        disabled = function() return not IsEnabled("loot_skin") end,
    })
end

-- ============================================================================
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    character   = BuildCharacterSubTab,
    collections = BuildCollectionsSubTab,
    worldmap    = BuildWorldMapSubTab,
    loot        = BuildLootSubTab,
}

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local function BuildPanelsTab(scroll)
    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("panels")
    end, subTabBuilders)

    if not Panel.indexing then
        local builder = subTabBuilders[activeSubTab]
        if builder then builder(scroll) end
    end
end

-- Register the tab
-- Straight after Enhancements, whose Character Panel and Pets & Mounts sections moved here.
Panel:RegisterTab("panels", LO["Panels"], BuildPanelsTab, 11.5)
