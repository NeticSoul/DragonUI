--[[
================================================================================
DragonUI Options Panel - Enhancements Tab
================================================================================
Dark Mode, Range Indicator, Item Quality Borders, Enhanced Tooltips.
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
                -- Force-push aura border tint on enable (clears Auras user override).
                if addon.ApplyDarkMode then addon.ApplyDarkMode(true) end
            else
                -- Texture restore + reset aura buff border to default gray.
                if addon.RestoreDarkMode then addon.RestoreDarkMode(true) end
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
            if addon.RefreshDarkMode then addon.RefreshDarkMode(true) end
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
            if addon.RefreshDarkMode then addon.RefreshDarkMode(true) end
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
            if addon.RefreshDarkMode then addon.RefreshDarkMode(true) end
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
    -- ITEM LEVEL
    -- ====================================================================
    C:AddSpacer(scroll)
    local ilvlSection = C:AddSection(scroll, LO["Item Level"] or "Item Level")

    local function IsItemLevelEnabled() return IsEnabled("itemlevel") end

    C:AddToggle(ilvlSection, {
        label = LO["Enable Item Level"] or "Enable Item Level",
        desc = LO["Show the item level on gear icons across bags, bank, character panel and more."]
            or "Show the item level on gear icons across bags, bank, character panel and more.",
        getFunc = IsItemLevelEnabled,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").enabled = val
            if val then
                if addon.ApplyItemLevelSystem then addon.ApplyItemLevelSystem() end
            end
            if addon.RefreshItemLevel then addon:RefreshItemLevel() end
            -- Rebuild tab so the sub-options update their disabled state
            Panel:SelectTab("enhancements")
        end,
        requiresReload = false,
    })

    C:AddDropdown(ilvlSection, {
        label = LO["Font"] or "Font",
        values = {
            ["default"] = LO["Default (Arial Narrow)"] or "Default (Arial Narrow)",
            ["expressway"] = "Expressway",
            ["primary"] = "Friz Quadrata",
            ["narrow"] = "PT Sans Narrow",
            ["skurri"] = "Skurri",
            ["morpheus"] = "Morpheus",
        },
        getFunc = function() return GetModuleField("itemlevel", "font_family") or "default" end,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").font_family = val
        end,
        callback = function()
            if addon.RefreshItemLevelFont then addon:RefreshItemLevelFont() end
        end,
        disabled = function() return not IsItemLevelEnabled() end,
        width = 200,
    })

    C:AddDropdown(ilvlSection, {
        label = LO["Outline"] or "Outline",
        desc = LO["Thickness of the black outline. WoW 3.3.5a has no real bold, so a thicker outline is what makes the number look heavier."]
            or "Thickness of the black outline. WoW 3.3.5a has no real bold, so a thicker outline is what makes the number look heavier.",
        values = {
            ["NONE"] = LO["None"] or "None",
            ["OUTLINE"] = LO["Outline"] or "Outline",
            ["THICKOUTLINE"] = LO["Thick"] or "Thick",
        },
        getFunc = function() return GetModuleField("itemlevel", "font_outline") or "OUTLINE" end,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").font_outline = val
        end,
        callback = function()
            if addon.RefreshItemLevelFont then addon:RefreshItemLevelFont() end
        end,
        disabled = function() return not IsItemLevelEnabled() end,
        width = 200,
    })

    C:AddSlider(ilvlSection, {
        label = LO["Font Size"] or "Font Size",
        desc = LO["Size of the item level number on the icon."] or "Size of the item level number on the icon.",
        min = 8, max = 18, step = 1,
        getFunc = function() return GetModuleField("itemlevel", "font_size") or 11 end,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").font_size = val
            if addon.RefreshItemLevelFont then addon:RefreshItemLevelFont() end
        end,
        disabled = function() return not IsItemLevelEnabled() end,
    })

    C:AddDropdown(ilvlSection, {
        label = LO["Position"] or "Position",
        desc = LO["Vertical position of the item level number on the icon."]
            or "Vertical position of the item level number on the icon.",
        values = {
            ["BOTTOM"] = LO["Bottom"] or "Bottom",
            ["CENTER"] = LO["Center"] or "Center",
            ["TOP"] = LO["Top"] or "Top",
        },
        getFunc = function() return GetModuleField("itemlevel", "position") or "BOTTOM" end,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").position = val
        end,
        callback = function()
            if addon.RefreshItemLevelPosition then addon:RefreshItemLevelPosition() end
        end,
        disabled = function() return not IsItemLevelEnabled() end,
        width = 200,
    })

    C:AddToggle(ilvlSection, {
        label = LO["Average Item Level"] or "Average Item Level",
        desc = LO["Show the average item level of equipped gear on the character and inspect panels."]
            or "Show the average item level of equipped gear on the character and inspect panels.",
        getFunc = function() return GetModuleField("itemlevel", "show_average") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").show_average = val
            if addon.RefreshItemLevel then addon:RefreshItemLevel() end
        end,
        disabled = function() return not IsItemLevelEnabled() end,
        requiresReload = false,
    })

    C:AddToggle(ilvlSection, {
        label = LO["Show in Tooltip"] or "Show in Tooltip",
        desc = LO["Also enable Blizzard's own item level line in item tooltips."]
            or "Also enable Blizzard's own item level line in item tooltips.",
        getFunc = function() return GetModuleField("itemlevel", "tooltip_cvar") == true end,
        setFunc = function(val)
            EnsureModuleTable("itemlevel").tooltip_cvar = val
            SetCVar("showItemLevel", val and 1 or 0)
        end,
        disabled = function() return not IsItemLevelEnabled() end,
        requiresReload = false,
    })

    -- Per-context toggles
    local ilvlContexts = {
        { key = "bags",      label = LO["Bags"] or "Bags" },
        { key = "bank",      label = LO["Bank"] or "Bank" },
        { key = "guildbank", label = LO["Guild Bank"] or "Guild Bank" },
        { key = "character", label = LO["Character Panel"] or "Character Panel" },
        { key = "inspect",   label = LO["Inspect"] or "Inspect" },
        { key = "merchant",  label = LO["Merchant"] or "Merchant" },
        { key = "trade",     label = LO["Trade"] or "Trade" },
        { key = "loot",      label = LO["Loot"] or "Loot" },
        { key = "lootroll",  label = LO["Loot Roll"] or "Loot Roll" },
        { key = "mail",      label = LO["Mail"] or "Mail" },
        { key = "auction",   label = LO["Auction House"] or "Auction House" },
    }

    C:AddDescription(ilvlSection, LO["Choose where the number appears:"] or "Choose where the number appears:")

    for _, context in ipairs(ilvlContexts) do
        C:AddToggle(ilvlSection, {
            label = context.label,
            getFunc = function() return GetModuleField("itemlevel", context.key) ~= false end,
            setFunc = function(val)
                EnsureModuleTable("itemlevel")[context.key] = val
                if addon.RefreshItemLevel then addon:RefreshItemLevel() end
            end,
            disabled = function() return not IsItemLevelEnabled() end,
            relWidth = 0.33,
            requiresReload = false,
        })
    end

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
    -- LOW HP ALERT MODULE
    -- ====================================================================
    C:AddSpacer(scroll)
    local lhpSection = C:AddSection(scroll, LO["Low HP Alert"])

    C:AddDescription(lhpSection, LO["Plays a sound and flashes the screen edges when your HP drops below the configured threshold."])

    C:AddToggle(lhpSection, {
        label = LO["Enable Low HP Alert"],
        getFunc = function() return GetModuleField("hp_low_alert", "enabled") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert")
            addon.db.profile.modules.hp_low_alert.enabled = val
        end,
    })

    C:AddToggle(lhpSection, {
        label = LO["Warning Sound (every 3 sec)"],
        desc = LO["Plays a warning sound every 3 seconds while HP is below threshold."],
        getFunc = function() return GetModuleField("hp_low_alert", "soundEnabled") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert")
            addon.db.profile.modules.hp_low_alert.soundEnabled = val
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
    })

    C:AddToggle(lhpSection, {
        label = LO["Screen Edge Flash"],
        desc = LO["Flashes red at the edges of the screen while HP is below threshold."],
        getFunc = function() return GetModuleField("hp_low_alert", "flashEnabled") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert")
            addon.db.profile.modules.hp_low_alert.flashEnabled = val
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
    })

    C:AddColorPicker(lhpSection, {
        label = LO["Flash Color"],
        getFunc = function()
            local c = GetModuleField("hp_low_alert", "flashColor")
            if c then return c.r or 1, c.g or 0, c.b or 0 end
            return 1, 0, 0
        end,
        setFunc = function(r, g, b)
            EnsureModuleTable("hp_low_alert").flashColor = { r = r, g = g, b = b }
        end,
        callback = function()
            if addon.RefreshHpLowAlertFlash then addon.RefreshHpLowAlertFlash() end
        end,
        disabled = function()
            return not IsEnabled("hp_low_alert") or GetModuleField("hp_low_alert", "useClassColor")
        end,
        hasAlpha = false,
    })

    C:AddToggle(lhpSection, {
        label = LO["Use Class Color"],
        desc = LO["Use your class color (e.g. orange for Druid, yellow for Rogue) instead of the custom color."],
        getFunc = function() return GetModuleField("hp_low_alert", "useClassColor") == true end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert").useClassColor = val
            if addon.RefreshHpLowAlertFlash then addon.RefreshHpLowAlertFlash() end
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
    })

    C:AddSlider(lhpSection, {
        label = LO["Flash Opacity"],
        desc = LO["Maximum opacity of the flash effect."],
        getFunc = function() return GetModuleField("hp_low_alert", "flashOpacity") or 0.35 end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert")
            addon.db.profile.modules.hp_low_alert.flashOpacity = val
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
        min = 0.05,
        max = 1.0,
        step = 0.05,
    })

    C:AddSlider(lhpSection, {
        label = LO["Flash Extent"],
        desc = LO["How far the flash extends from the screen edges toward the center, in pixels."],
        getFunc = function() return GetModuleField("hp_low_alert", "flashExtent") or 40 end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert")
            addon.db.profile.modules.hp_low_alert.flashExtent = val
            if addon.RefreshHpLowAlertFlash then addon.RefreshHpLowAlertFlash() end
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
        min = 20,
        max = 600,
        step = 10,
    })

    C:AddSlider(lhpSection, {
        label = LO["HP Warning Threshold"],
        desc = LO["Percentage of HP at which the warning triggers."],
        getFunc = function() return GetModuleField("hp_low_alert", "threshold") or 30 end,
        setFunc = function(val)
            EnsureModuleTable("hp_low_alert")
            addon.db.profile.modules.hp_low_alert.threshold = val
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
        min = 5,
        max = 80,
        step = 1,
    })

    C:AddButton(lhpSection, {
        label = LO["Test Warning (3 sec)"],
        desc = LO["Triggers a 3-second preview of the warning state to help you adjust the threshold."],
        callback = function()
            if addon.LowHPAlert and addon.LowHPAlert.StartTest then
                addon.LowHPAlert.StartTest()
            end
        end,
        disabled = function() return not IsEnabled("hp_low_alert") end,
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

    C:AddToggle(ttSection, {
        label = LO["Show Aura Source"],
        desc = LO["Show the caster's name (class-colored) and spell ID on buff and debuff tooltips."],
        getFunc = function()
            return GetModuleField("tooltip", "show_aura_source") ~= false
        end,
        setFunc = function(val)
            EnsureModuleTable("tooltip").show_aura_source = val
        end,
        disabled = function() return not IsEnabled("tooltip") end,
        requiresReload = false,
    })
end

-- Register the tab (order 11 = after Quest Tracker, before Profiles)
Panel:RegisterTab("enhancements", LO["Enhancements"], BuildEnhancementsTab, 11)
