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
            local modules = addon.db.profile.modules
            if not modules then return false end
            for _, name in ipairs(moduleNames) do
                if not (modules[name] and modules[name].enabled) then
                    return false
                end
            end
            return true
        end,
        setFunc = function(val)
            if not addon.db.profile.modules then
                addon.db.profile.modules = {}
            end
            for _, name in ipairs(moduleNames) do
                if not addon.db.profile.modules[name] then
                    addon.db.profile.modules[name] = {}
                end
                addon.db.profile.modules[name].enabled = val
            end
        end,
        callback = opts.callback,
        requiresReload = (opts.requiresReload ~= false), -- default true
    })
end

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

    C:AddToggle(castSection, {
        label = LO["Player Castbar"],
        desc = LO["Enable DragonUI player castbar styling."],
        dbPath = "castbar.enabled",
        callback = function() if addon.RefreshCastbar then addon.RefreshCastbar() end end,
    })

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
        callback = function() if addon.RefreshTargetCastbar then addon.RefreshTargetCastbar() end end,
    })

    C:AddToggle(castSection, {
        label = LO["Focus Castbar"],
        desc = LO["Enable DragonUI focus castbar styling."],
        dbPath = "castbar.focus.enabled",
        callback = function() if addon.RefreshFocusCastbar then addon.RefreshFocusCastbar() end end,
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
        callback = function(val)
            if addon.BuffFrameModule then
                addon.BuffFrameModule:Toggle(val)
            end
        end,
    })



    ModuleToggle(uiSection, {
        label = LO["Cooldown Timers"],
        desc = LO["Show cooldown timers on action buttons."],
        moduleName = "cooldowns",
        requiresReload = false,
        callback = function()
            if addon.RefreshCooldownSystem then addon.RefreshCooldownSystem() end
        end,
    })

    ModuleToggle(uiSection, {
        label = LO["Target & Focus Aura Customization"],
        desc = LO["Customize target/focus aura icons and timers."],
        moduleName = "auracooldowns",
        requiresReload = false,
        callback = function()
            if addon.RefreshAuraCooldownTextSystem then addon.RefreshAuraCooldownTextSystem() end
        end,
    })

    ModuleToggle(uiSection, {
        label = LO["Range Indicator"],
        desc = LO["Tints action button icons based on range and usability: red = out of range, blue = not enough mana, gray = unusable."],
        moduleName = "rage_indicator",
        requiresReload = false,
        callback = function()
            if addon.RefreshRageIndicatorSystem then addon.RefreshRageIndicatorSystem() end
        end,
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

    -- ====================================================================
    -- UNIT FRAME LAYERS
    -- ====================================================================
    local ufLayersSection = C:AddSection(scroll, LO["Unit Frame Layers"])

    C:AddDescription(ufLayersSection, LO["Heal prediction bars, absorb shields, and animated health loss overlays on unit frames."])

    ModuleToggle(ufLayersSection, {
        label = LO["Enable Unit Frame Layers"],
        desc = LO["Show heal prediction, absorb shields, and animated health loss on all unit frames."],
        moduleName = "unitframe_layers",
        requiresReload = true,
    })

    -- ====================================================================
    -- ADVANCED: Individual Module Control
    -- ====================================================================
    C:AddSpacer(scroll)
    local advSection = C:AddSection(scroll, LO["Advanced - Individual Module Control"])

    C:AddLabel(advSection, "|cffFF6600" .. LO["Warning:"] .. "|r " .. LO["Individual overrides. The grouped toggles above take priority."], { color = C.Theme.warning })
    C:AddSpacer(advSection)

    -- Generate toggles for all registered modules
    local MR = addon.ModuleRegistry
    if MR and MR.loadOrder then
        local hiddenAdvancedModules = {
            castbar = true,
            player = true,
            boss = true,
            rage_indicator = true,
            buffs = true,
        }

        for _, moduleName in ipairs(MR.loadOrder) do
            if not hiddenAdvancedModules[moduleName] then
            local info = MR:GetInfo(moduleName)
            if info then
                -- displayName/description are already translated at registration time via addon.L
                local displayLabel = info.displayName or moduleName
                local displayDesc = info.description
                if not displayDesc or displayDesc == "" then
                    displayDesc = LO["Enable/disable "] .. displayLabel
                end
                ModuleToggle(advSection, {
                    label = displayLabel,
                    desc = displayDesc,
                    moduleName = moduleName,
                })
            end
            end
        end
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
