--[[
================================================================================
DragonUI Options Panel - Enhancements Tab
================================================================================
Dark Mode, Range Indicator, Item Quality Borders, Enhanced Tooltips.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
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
-- TAB BUILDER
-- ============================================================================

local function BuildEnhancementsTab(scroll)
    C:AddLabel(scroll, "|cffFFD700" .. LO["Enhancements"] .. "|r", { color = C.Theme.textGold })
    C:AddDescription(scroll, LO["Visual enhancements that add Dragonflight-style polish to the UI. These are optional \226\128\148 disable any you don't want."])
    C:AddSpacer(scroll)

    -- ====================================================================
    -- DARK MODE
    -- ====================================================================
    local darkSection = C:AddSection(scroll, LO["Dark Mode"])

    C:AddDescription(darkSection, LO["Darkens UI borders and chrome only: action bar borders, unit frame borders, minimap border, bag slot borders, micro menu, castbar borders, and decorative elements. Icons, portraits, and abilities are never affected."])

    C:AddToggle(darkSection, {
        label = LO["Enable Dark Mode"],
        desc = LO["Apply darker tinted textures to all UI elements."],
        getFunc = function() return IsEnabled("darkmode") end,
        setFunc = function(val)
            EnsureModuleTable("darkmode").enabled = val
            if val then
                if addon.ApplyDarkMode then addon.ApplyDarkMode() end
            else
                if addon.RestoreDarkMode then addon.RestoreDarkMode() end
            end
            -- Rebuild tab so the intensity dropdown updates its disabled state
            Panel:SelectTab("enhancements")
        end,
        requiresReload = true,
    })

    C:AddDropdown(darkSection, {
        label = LO["Intensity"],
        values = {
            [1] = LO["Light (subtle)"],
            [2] = LO["Medium (balanced)"],
            [3] = LO["Dark (maximum)"],
        },
        getFunc = function()
            return GetModuleField("darkmode", "intensity_preset") or 3
        end,
        setFunc = function(val)
            EnsureModuleTable("darkmode").intensity_preset = val
        end,
        callback = function()
            if addon.RefreshDarkMode then addon.RefreshDarkMode() end
        end,
        disabled = function() return not IsEnabled("darkmode") or GetModuleField("darkmode", "use_custom_color") == true end,
        width = 200,
    })

    C:AddToggle(darkSection, {
        label = LO["Custom Color"],
        desc = LO["Override presets with a custom tint color."],
        getFunc = function() return GetModuleField("darkmode", "use_custom_color") == true end,
        setFunc = function(val)
            EnsureModuleTable("darkmode").use_custom_color = val
            if addon.RefreshDarkMode then addon.RefreshDarkMode() end
            Panel:SelectTab("enhancements")
        end,
        disabled = function() return not IsEnabled("darkmode") end,
        requiresReload = false,
    })

    C:AddColorPicker(darkSection, {
        label = LO["Tint Color"],
        getFunc = function()
            local c = GetModuleField("darkmode", "custom_color")
            if c then return c.r or 0.15, c.g or 0.15, c.b or 0.15 end
            return 0.15, 0.15, 0.15
        end,
        setFunc = function(r, g, b)
            EnsureModuleTable("darkmode").custom_color = { r = r, g = g, b = b }
        end,
        callback = function()
            if addon.RefreshDarkMode then addon.RefreshDarkMode() end
        end,
        hasAlpha = false,
    })

    -- ====================================================================
    -- RANGE INDICATOR
    -- ====================================================================
    C:AddSpacer(scroll)
    local rangeSection = C:AddSection(scroll, LO["Range Indicator"])

    C:AddDescription(rangeSection, LO["Tints action button icons based on range and usability: red = out of range, blue = not enough mana, gray = unusable."])

    C:AddToggle(rangeSection, {
        label = LO["Enable Range Indicator"],
        desc = LO["Color action button icons when target is out of range or ability is unusable."],
        getFunc = function() return IsEnabled("rage_indicator") end,
        setFunc = function(val)
            EnsureModuleTable("rage_indicator").enabled = val
        end,
        callback = function()
            if addon.RefreshRageIndicatorSystem then addon.RefreshRageIndicatorSystem() end
        end,
        requiresReload = false,
    })

    local function AddRangeColor(field, label, def)
        C:AddColorPicker(rangeSection, {
            label = label,
            getFunc = function()
                local c = GetModuleField("rage_indicator", field)
                if c and c.r then return c.r, c.g, c.b end
                return def.r, def.g, def.b
            end,
            setFunc = function(r, g, b)
                EnsureModuleTable("rage_indicator")[field] = { r = r, g = g, b = b }
            end,
            callback = function()
                if addon.RefreshRageIndicatorSystem then addon.RefreshRageIndicatorSystem() end
            end,
            disabled = function() return not IsEnabled("rage_indicator") end,
            hasAlpha = false,
        })
    end

    AddRangeColor("oor_color", LO["Out of Range Color"], { r = 0.8, g = 0.2, b = 0.2 })
    AddRangeColor("oom_color", LO["Not Enough Mana Color"], { r = 0.5, g = 0.5, b = 1.0 })

    -- ====================================================================
    -- KEY PRESS (fire abilities on key down)
    -- ====================================================================
    C:AddSpacer(scroll)
    local kpSection = C:AddSection(scroll, LO["Key Press"])

    C:AddDescription(kpSection, LO["Fires action bar abilities the instant you press a key instead of when you release it, shaving reaction-time latency. Most useful for interrupts, dispels, and PvP."])

    C:AddToggle(kpSection, {
        label = LO["Enable Key Press"],
        desc = LO["Fire abilities on key press instead of key release."],
        getFunc = function() return IsEnabled("keypress") end,
        setFunc = function(val)
            EnsureModuleTable("keypress").enabled = val
        end,
        callback = function()
            if addon.RefreshKeyPress then addon.RefreshKeyPress() end
        end,
        requiresReload = false,
    })

    -- ====================================================================
    -- ITEM QUALITY BORDERS
    -- ====================================================================
    C:AddSpacer(scroll)
    local iqSection = C:AddSection(scroll, LO["Item Quality Borders"])

    C:AddDescription(iqSection, LO["Adds quality-colored glow borders to items in your bags, character panel, bank, merchant, and inspect frames: green = uncommon, blue = rare, purple = epic, orange = legendary."])

    C:AddToggle(iqSection, {
        label = LO["Enable Item Quality Borders"],
        desc = LO["Show quality-colored borders on items in bags, character panel, bank, merchant, and inspect frames."],
        getFunc = function() return IsEnabled("itemquality") end,
        setFunc = function(val)
            EnsureModuleTable("itemquality").enabled = val
            if val then
                if addon.ApplyItemQualitySystem then addon.ApplyItemQualitySystem() end
            else
                if addon.RestoreItemQualitySystem then addon.RestoreItemQualitySystem() end
            end
            -- Rebuild tab so the min quality dropdown updates its disabled state
            Panel:SelectTab("enhancements")
        end,
        requiresReload = false,
    })

    C:AddDropdown(iqSection, {
        label = LO["Minimum Quality"],
        values = {
            [0] = "|cff9d9d9d" .. LO["Poor"] .. "|r",
            [1] = "|cffffffff" .. LO["Common"] .. "|r",
            [2] = "|cff1eff00" .. LO["Uncommon"] .. "|r",
            [3] = "|cff0070dd" .. LO["Rare"] .. "|r",
            [4] = "|cffa335ee" .. LO["Epic"] .. "|r",
            [5] = "|cffff8000" .. LO["Legendary"] .. "|r",
        },
        getFunc = function()
            return GetModuleField("itemquality", "min_quality") or 2
        end,
        setFunc = function(val)
            EnsureModuleTable("itemquality").min_quality = val
        end,
        callback = function()
            if addon.UpdateAllQualityBorders then addon.UpdateAllQualityBorders() end
        end,
        disabled = function() return not IsEnabled("itemquality") end,
        width = 200,
    })

    -- ====================================================================
    -- UNIT FRAME LAYERS
    -- ====================================================================
    C:AddSpacer(scroll)
    local uflSection = C:AddSection(scroll, LO["Unit Frame Layers"])

    C:AddDescription(uflSection, LO["Heal prediction bars, absorb shields, and animated health loss overlays on unit frames."])

    C:AddToggle(uflSection, {
        label = LO["Enable Unit Frame Layers"],
        desc = LO["Show heal prediction, absorb shields, and animated health loss on all unit frames."],
        getFunc = function() return IsEnabled("unitframe_layers") end,
        setFunc = function(val)
            EnsureModuleTable("unitframe_layers").enabled = val
        end,
        callback = function()
            Panel:SelectTab("enhancements")
        end,
        requiresReload = true,
    })

    C:AddToggle(uflSection, {
        label = LO["Animated Health Loss"],
        desc = LO["Show animated red health loss bar on player frame when taking damage."],
        getFunc = function()
            local m = addon.db.profile.modules and addon.db.profile.modules.unitframe_layers
            if not m then return true end
            return m.animated_loss ~= false
        end,
        setFunc = function(val)
            if not addon.db.profile.modules.unitframe_layers then
                addon.db.profile.modules.unitframe_layers = {}
            end
            addon.db.profile.modules.unitframe_layers.animated_loss = val
        end,
        disabled = function() return not IsEnabled("unitframe_layers") end,
        requiresReload = true,
    })

    C:AddToggle(uflSection, {
        label = LO["Missing Health Text"],
        desc = LO["Show the health deficit (missing health) as red text on health bars. Useful for healers."],
        getFunc = function()
            local m = addon.db.profile.modules and addon.db.profile.modules.unitframe_layers
            if not m then return false end
            return m.missing_health == true
        end,
        setFunc = function(val)
            if not addon.db.profile.modules.unitframe_layers then
                addon.db.profile.modules.unitframe_layers = {}
            end
            addon.db.profile.modules.unitframe_layers.missing_health = val
            if addon.RefreshUnitFrameLayers then
                addon.RefreshUnitFrameLayers()
            end
        end,
        disabled = function() return not IsEnabled("unitframe_layers") end,
        requiresReload = false,
    })

    -- ====================================================================
    -- ENHANCED TOOLTIPS
    -- ====================================================================
    C:AddSpacer(scroll)
    local ttSection = C:AddSection(scroll, LO["Enhanced Tooltips"])

    C:AddDescription(ttSection, LO["Improves GameTooltip with class-colored borders, class-colored names, target-of-target info, and styled health bars."])

    C:AddToggle(ttSection, {
        label = LO["Enable Enhanced Tooltips"],
        desc = LO["Activate all tooltip improvements. Sub-options below control individual features."],
        getFunc = function() return IsEnabled("tooltip") end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").enabled = val
            -- Rebuild tab so sub-toggles update their disabled state
            Panel:SelectTab("enhancements")
        end,
            requiresReload = true,
    })

    C:AddToggle(ttSection, {
        label = LO["Class-Colored Border"],
        desc = LO["Color the tooltip border by the unit's class (players) or reaction (NPCs)."],
        getFunc = function()
            return GetModuleField("tooltip", "class_colored_border") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").class_colored_border = val
        end,
        disabled = function() return not IsEnabled("tooltip") end,
        requiresReload = false,
    })

    C:AddToggle(ttSection, {
        label = LO["Class-Colored Name"],
        desc = LO["Color the unit name text in the tooltip by class color (players only)."],
        getFunc = function()
            return GetModuleField("tooltip", "class_colored_name") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").class_colored_name = val
        end,
        disabled = function() return not IsEnabled("tooltip") end,
        requiresReload = false,
    })

    C:AddToggle(ttSection, {
        label = LO["Target of Target"],
        desc = LO["Add a 'Targeting: <name>' line showing who the unit is targeting."],
        getFunc = function()
            return GetModuleField("tooltip", "target_of_target") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").target_of_target = val
        end,
        disabled = function() return not IsEnabled("tooltip") end,
        requiresReload = false,
    })

    C:AddToggle(ttSection, {
        label = LO["Styled Health Bar"],
        desc = LO["Restyle the tooltip health bar with class/reaction colors and slimmer look."],
        getFunc = function()
            return GetModuleField("tooltip", "health_bar") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").health_bar = val
        end,
        disabled = function() return not IsEnabled("tooltip") end,
        requiresReload = false,
    })

    C:AddToggle(ttSection, {
        label = LO["Anchor to Cursor"],
        desc = LO["Make the tooltip follow the cursor position instead of the default anchor."],
        getFunc = function()
            return GetModuleField("tooltip", "anchor_cursor") == true
        end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").anchor_cursor = val
        end,
        disabled = function() return not IsEnabled("tooltip") end,
        requiresReload = false,
    })
end

-- Register the tab (order 11 = after Quest Tracker, before Profiles)
Panel:RegisterTab("enhancements", LO["Enhancements"], BuildEnhancementsTab, 11)
