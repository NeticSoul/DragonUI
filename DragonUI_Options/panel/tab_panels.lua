-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - Panels Tab
================================================================================
The reskinned Blizzard windows: Character Panel and Pets & Mounts.
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
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    character   = BuildCharacterSubTab,
    collections = BuildCollectionsSubTab,
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
