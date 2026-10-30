-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - Modules Tab
================================================================================
Module enable/disable toggles organized by category.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local C = addon.PanelControls
local Panel = addon.OptionsPanel
local LO = addon.LO

-- ============================================================================
-- HELPER: Create a module toggle with standard pattern
-- ============================================================================

local function ModuleToggle(parent, opts)
    -- opts: { label, desc, moduleName (single string or table of names), callback }
    local moduleNames = opts.moduleNames or { opts.moduleName }

    C:AddToggle(parent, {
        label = opts.label,
        desc  = opts.desc,
        getFunc = function()
            for _, name in ipairs(moduleNames) do
                if not addon.Reload.ModuleState(name) then
                    return false
                end
            end
            return true
        end,
        setFunc = function(val)
            local applied = false
            for _, name in ipairs(moduleNames) do
                applied = addon:SetModuleEnabled(name, val) or applied
            end
            -- A staged change isn't running yet, so there is nothing for the callback to refresh.
            if applied and opts.callback then opts.callback(val) end
        end,
    })
end

-- Sections of the individual module list; the titles are the options tab and group names (LO keys).
local ADVANCED_SECTIONS = {
    { title = "Frames", modules = { "nameplates", "unitframe_layers", "hp_low_alert", "personalresource", "swingtimer", "combopoints", "totemframe", "auraborders", "auracooldowns" } },
    { title = "Bars", modules = { "mainbars", "vehicle", "stance", "petbar", "multicast", "extrabar1", "buttons", "cooldowns", "noop", "keybinding" } },
    { title = "Interface", modules = { "minimap", "MinimapDecorations", "micromenu", "questtracker", "chatmods", "tooltip", "darkmode", "levelupenhance", "addonmanager" } },
    { title = "Panels", modules = { "characterpanel", "collections", "spellbook", "professions", "talents", "worldmap", "loot_skin", "mail", "taxiframe" } },
    { title = "Bags", modules = { "bagster", "bags_skin", "bagsort", "altmoney", "itemlevel", "itemquality" } },
}

-- ============================================================================
-- MODULES TAB BUILDER
-- ============================================================================

local function BuildModulesTab(scroll)
    C:AddLabel(scroll, "|cffFFD700" .. LO["Modules"] .. "|r", { color = C.Theme.textGold })
    C:AddDescription(scroll, LO["Toggle individual modules on or off. Disabled modules revert to the default Blizzard UI."])

    C:AddSpacer(scroll)

    -- ====================================================================
    -- CAST BARS
    -- ====================================================================
    local castSection = C:AddSection(scroll, LO["Cast Bars"])

    -- Listed only while that DragonUI bar is off; its own toggle rebuilds the tab.
    local function HideBlizzardToggle(cfgPath, refresh)
        if C:GetDBValue(cfgPath .. "enabled") ~= false then return end
        C:AddToggle(castSection, {
            label = LO["Hide Blizzard's Castbar"],
            desc = LO["With this cast bar off, hide Blizzard's too, so none is shown."],
            dbPath = cfgPath .. "hideBlizzard",
            indent = 18,
            callback = function() if refresh then refresh() end end,
        })
    end

    C:AddToggle(castSection, {
        label = LO["Player Castbar"],
        desc = LO["Enable DragonUI player castbar styling."],
        dbPath = "castbar.enabled",
        callback = function()
            if addon.RefreshCastbar then addon.RefreshCastbar() end
            Panel:SelectTab("modules")
        end,
    })
    HideBlizzardToggle("castbar.", addon.RefreshCastbar)

    C:AddToggle(castSection, {
        label = LO["Target Castbar"],
        desc = LO["Enable DragonUI target castbar styling."],
        getFunc = function()
            local t = addon.db.profile.castbar and addon.db.profile.castbar.target
            if not t then return true end
            return t.enabled ~= false
        end,
        setFunc = function(val)
            if not addon.db.profile.castbar.target then
                addon.db.profile.castbar.target = {}
            end
            addon.db.profile.castbar.target.enabled = val
        end,
        callback = function()
            if addon.RefreshTargetCastbar then addon.RefreshTargetCastbar() end
            Panel:SelectTab("modules")
        end,
    })
    HideBlizzardToggle("castbar.target.", addon.RefreshTargetCastbar)

    C:AddToggle(castSection, {
        label = LO["Focus Castbar"],
        desc = LO["Enable DragonUI focus castbar styling."],
        dbPath = "castbar.focus.enabled",
        callback = function()
            if addon.RefreshFocusCastbar then addon.RefreshFocusCastbar() end
            Panel:SelectTab("modules")
        end,
    })
    HideBlizzardToggle("castbar.focus.", addon.RefreshFocusCastbar)

    C:AddToggle(castSection, {
        label = LO["Global Cooldown"],
        desc = LO["Show a global cooldown readout above the player cast bar."],
        dbPath = "castbar.gcd.enabled",
        callback = function() if addon.RefreshGCD then addon.RefreshGCD() end end,
    })

    -- ====================================================================
    -- ACTION BARS SYSTEM (unified toggle)
    -- ====================================================================
    local abSection = C:AddSection(scroll, LO["Action Bars System"])

    C:AddDescription(abSection, LO["Includes main bars, vehicle, stance, pet, totem bars, and button styling."])

    ModuleToggle(abSection, {
        label = LO["Enable All Action Bar Modules"],
        desc = LO["Master toggle for the complete action bars system."],
        moduleNames = { "mainbars", "vehicle", "stance", "petbar", "multicast", "buttons", "noop", "micromenu" },
    })

    -- ====================================================================
    -- UI SYSTEMS
    -- ====================================================================
    local uiSection = C:AddSection(scroll, LO["UI Systems"])

    ModuleToggle(uiSection, {
        label = LO["Micro Menu & Bags"],
        desc = LO["Micro menu and bags styling."],
        moduleName = "micromenu",
    })

    ModuleToggle(uiSection, {
        label = LO["Minimap System"],
        desc = LO["Minimap styling, tracking icons, and calendar."],
        moduleName = "minimap",
    })

    ModuleToggle(uiSection, {
        label = LO["Buff Frame System"],
        desc = LO["Buff frame styling and toggle button."],
        moduleName = "buffs",
    })

    ModuleToggle(uiSection, {
        label = LO["Cooldown Timers"],
        desc = LO["Show cooldown timers on action buttons."],
        moduleName = "cooldowns",
    })

    ModuleToggle(uiSection, {
        label = LO["Target & Focus Aura Customization"],
        desc = LO["Customize target/focus aura icons and timers."],
        moduleName = "auracooldowns",
    })

    ModuleToggle(uiSection, {
        label = LO["Range Indicator"],
        desc = LO["Tints action button icons based on range and usability: red = out of range, blue = not enough mana, gray = unusable."],
        moduleName = "rage_indicator",
    })

    ModuleToggle(uiSection, {
        label = LO["Quest Tracker"],
        desc = LO["DragonUI quest tracker positioning and styling."],
        moduleName = "questtracker",
    })

    ModuleToggle(uiSection, {
        label = LO["KeyBind Mode"],
        desc = LO["LibKeyBound integration for intuitive hover + key press binding."],
        moduleName = "keybinding",
    })

    ModuleToggle(uiSection, {
        label = LO["Version Check"],
        desc = LO["Broadcast and detect addon version updates across group members."],
        moduleName = "versioncheck",
    })

    ModuleToggle(uiSection, {
        label = LO["Merchant"],
        desc = LO["Retail-style vendor window chrome"],
        moduleName = "merchant",
    })

    ModuleToggle(uiSection, {
        label = LO["Quest Dialog"],
        desc = LO["Retail-style quest and gossip window chrome"],
        moduleName = "questdialog",
    })

    -- ====================================================================
    -- UNIT FRAME LAYERS
    -- ====================================================================
    local ufLayersSection = C:AddSection(scroll, LO["Unit Frame Layers"])

    C:AddDescription(ufLayersSection, LO["Heal prediction bars, absorb shields, and animated health loss overlays on unit frames."])

    ModuleToggle(ufLayersSection, {
        label = LO["Enable Unit Frame Layers"],
        desc = LO["Show heal prediction, absorb shields, and animated health loss on all unit frames."],
        moduleName = "unitframe_layers",
    })

    -- ====================================================================
    -- ADVANCED: Individual Module Control
    -- ====================================================================
    C:AddSpacer(scroll)
    local advSection = C:AddSection(scroll, LO["Advanced - Individual Module Control"])

    C:AddLabel(advSection, "|cffFF6600" .. LO["Warning:"] .. "|r " .. LO["Individual overrides. The grouped toggles above take priority."], { color = C.Theme.warning })
    C:AddSpacer(advSection)

    -- Toggles for all registered modules, in sections named like the options groups and tabs they belong to.
    local MR = addon.ModuleRegistry
    if MR and MR.loadOrder then
        local hiddenAdvancedModules = {
            castbar = true,
            -- Its flag is castbar.gcd.enabled, toggled in Cast Bars above.
            gcd = true,
            player = true,
            boss = true,
            rage_indicator = true,
            buffs = true,
            merchant = true,
            questdialog = true,
            keypress = true,
        }
        -- Like its Unit Frames section: classes without combo points only meet them in a few vehicles.
        local _, playerClass = UnitClass("player")
        if playerClass ~= "ROGUE" and playerClass ~= "DRUID" then
            hiddenAdvancedModules.combopoints = true
        end
        if playerClass ~= "SHAMAN" then
            hiddenAdvancedModules.totemframe = true
        end

        local function AddAdvancedToggle(section, moduleName)
            local info = MR:GetInfo(moduleName)
            -- displayName/description are already translated at registration time via addon.L
            local displayLabel = info.displayName or moduleName
            local displayDesc = info.description
            if not displayDesc or displayDesc == "" then
                displayDesc = LO["Enable/disable "] .. displayLabel
            end
            ModuleToggle(section, {
                label = displayLabel,
                desc = displayDesc,
                moduleName = moduleName,
            })
        end

        local function AddAdvancedSection(title, moduleNames)
            local listed = {}
            for _, moduleName in ipairs(moduleNames) do
                if not hiddenAdvancedModules[moduleName] and MR:GetInfo(moduleName) then
                    listed[#listed + 1] = moduleName
                end
            end
            if #listed == 0 then return end
            C:AddSpacer(scroll)
            local section = C:AddSection(scroll, title)
            for _, moduleName in ipairs(listed) do
                AddAdvancedToggle(section, moduleName)
            end
        end

        local placed = {}
        for _, group in ipairs(ADVANCED_SECTIONS) do
            for _, moduleName in ipairs(group.modules) do
                placed[moduleName] = true
            end
            AddAdvancedSection(LO[group.title], group.modules)
        end

        -- A module no section lists still gets its toggle, so none can go missing.
        local others = {}
        for _, moduleName in ipairs(MR.loadOrder) do
            if not placed[moduleName] then
                others[#others + 1] = moduleName
            end
        end
        AddAdvancedSection(_G.OTHER or "Other", others)
    else
        -- Fallback: show known modules from database defaults
        local knownModules = {
            { key = "mainbars",    name = LO["Main Bars"] },
            { key = "vehicle",     name = LO["Vehicle"] },
            { key = "stance",      name = LO["Stance Bar"] },
            { key = "petbar",      name = LO["Pet Bar"] },
            { key = "multicast",   name = LO["Multicast"] },
            { key = "buttons",     name = LO["Buttons"] },
            { key = "noop",        name = LO["Hide Blizzard Elements"] },
            { key = "micromenu",   name = LO["Micro Menu"] },
            { key = "cooldowns",   name = LO["Cooldowns"] },
            { key = "auracooldowns", name = LO["Target & Focus Aura Customization"] },
            { key = "minimap",     name = LO["Minimap"] },
            { key = "nameplates",  name = LO["Nameplates"] },
            { key = "keybinding",  name = LO["KeyBinding"] },
            { key = "questtracker", name = LO["Quest Tracker"] },
        }
        for _, mod in ipairs(knownModules) do
            ModuleToggle(advSection, {
                label = mod.name,
                desc = LO["Enable/disable "] .. mod.name,
                moduleName = mod.key,
            })
        end
    end
end

-- Register the tab
Panel:RegisterTab("modules", LO["Modules"], BuildModulesTab, 2)
