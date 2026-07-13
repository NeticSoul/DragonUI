--[[
================================================================================
DragonUI Options Panel - Action Bars Tab
================================================================================
Scales, positions, button appearance, bar size for action bars.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- SUB-TAB DEFINITIONS
-- ============================================================================

local activeSubTab = "general"

-- Allow external code to set the initial sub-tab before SelectTab
function addon.SetActionBarSubTab(key)
    activeSubTab = key or "general"
end

local subTabs = {
    { key = "general", label = LO["General"] },
    { key = "layout",  label = LO["Layout"] },
    { key = "visibility", label = LO["Visibility"] },
}

-- Search navigation sub-tab setter.
Panel.subTabSetters = Panel.subTabSetters or {}
Panel.subTabSetters["actionbars"] = function(key) activeSubTab = key or "general" end

-- ============================================================================
-- REFRESH HELPER
-- ============================================================================

local function RefreshBars()
    if addon.RefreshMainbars then addon.RefreshMainbars() end
end

local buttonOrderValues = {
    top_left     = LO["Top Left"],
    bottom_left  = LO["Bottom Left"],
    top_right    = LO["Top Right"],
    bottom_right = LO["Bottom Right"],
}

local function RebuildLayoutTab()
    local savedScroll = Panel.scrollWidget and Panel.scrollWidget.scrollbar
        and Panel.scrollWidget.scrollbar:GetValue() or 0
    activeSubTab = "layout"
    Panel:SelectTab("actionbars")
    if savedScroll > 0 and Panel.scrollWidget and Panel.scrollWidget.scrollbar then
        Panel.scrollWidget.scrollbar:SetValue(savedScroll)
        Panel.scrollWidget:SetScroll(savedScroll)
    end
end

local function AddBarOrderControls(section, barKey)
    local dbPrefix = "mainbars." .. barKey

    C:AddToggle(section, {
        label = LO["Change Button Order"],
        dbPath = dbPrefix .. ".change_button_order",
        callback = function(value)
            if value and not C:GetDBValue(dbPrefix .. ".button_order") then
                C:SetDBValue(dbPrefix .. ".button_order", "top_left")
            end
            RefreshBars()
            RebuildLayoutTab()
        end,
    })

    if C:GetDBValue(dbPrefix .. ".change_button_order") then
        C:AddDropdown(section, {
            label = LO["Button Order"],
            dbPath = dbPrefix .. ".button_order",
            values = buttonOrderValues,
            width = 200,
            callback = RefreshBars,
        })
    end
end

local function RefreshButtons()
    if addon.RefreshButtons then addon.RefreshButtons() end
end

local function RefreshCooldowns()
    if addon.RefreshCooldowns then addon.RefreshCooldowns() end
end

local function IsD3D9ExActive()
    local gxApi = GetCVar and GetCVar("gxApi")
    return gxApi and string.lower(gxApi) == "d3d9ex"
end

-- ============================================================================
-- GENERAL SUB-TAB (existing action bar settings)
-- ============================================================================

local function BuildGeneralTab(scroll)
    -- ====================================================================
    -- SCALES
    -- ====================================================================
    local scales = C:AddSection(scroll, LO["Action Bar Scales"])

    local barScales = {
        { path = "mainbars.scale_actionbar",    label = LO["Main Bar Scale"] },
        { path = "mainbars.scale_rightbar",     label = LO["Right Bar Scale"] },
        { path = "mainbars.scale_leftbar",      label = LO["Left Bar Scale"] },
        { path = "mainbars.scale_bottomleft",   label = LO["Bottom Left Bar Scale"] },
        { path = "mainbars.scale_bottomright",  label = LO["Bottom Right Bar Scale"] },
    }

    for _, bar in ipairs(barScales) do
        C:AddSlider(scales, {
            dbPath = bar.path,
            label = bar.label,
            min = 0.5, max = 2.0, step = 0.01,
            width = 250,
            callback = RefreshBars,
        })
    end

    C:AddButton(scales, {
        label = LO["Reset All Scales"],
        width = 180,
        callback = function()
            for _, bar in ipairs(barScales) do
                C:SetDBValue(bar.path, 0.9)
            end
            RefreshBars()
            Panel:SelectTab("actionbars")
            print("|cFF00FF00[DragonUI]|r " .. LO["All action bar scales reset to 0.9"])
        end,
    })

    -- ====================================================================
    -- POSITIONS
    -- ====================================================================
    local positions = C:AddSection(scroll, LO["Action Bar Positions"])

    C:AddToggle(positions, {
        label = LO["Left Bar Horizontal"],
        desc = LO["Make the left secondary bar horizontal instead of vertical."],
        dbPath = "mainbars.left.horizontal",
        callback = function(value)
            addon.db.profile.mainbars.left.columns = value and 12 or 1
            RefreshBars()
        end,
    })

    C:AddToggle(positions, {
        label = LO["Right Bar Horizontal"],
        desc = LO["Make the right secondary bar horizontal instead of vertical."],
        dbPath = "mainbars.right.horizontal",
        callback = function(value)
            addon.db.profile.mainbars.right.columns = value and 12 or 1
            RefreshBars()
        end,
    })

    -- ====================================================================
    -- BUTTON APPEARANCE
    -- ====================================================================
    local buttons = C:AddSection(scroll, LO["Button Appearance"])

    C:AddToggle(buttons, {
        label = LO["Main Bar Only Background"],
        desc = LO["Only the main action bar buttons will have a background."],
        dbPath = "buttons.only_actionbackground",
        callback = RefreshButtons,
    })

    C:AddToggle(buttons, {
        label = LO["Hide Main Bar Background"],
        desc = LO["Hide the background texture of the main action bar."],
        dbPath = "buttons.hide_main_bar_background",
        requiresReload = true,
        callback = RefreshBars,
    })

    -- Text visibility sub-section
    local textVis = C:AddSection(scroll, LO["Text Visibility"])

    C:AddToggle(textVis, {
        label = LO["Show Count Text"],
        dbPath = "buttons.count.show",
        callback = RefreshButtons,
    })

    C:AddToggle(textVis, {
        label = LO["Show Hotkey Text"],
        dbPath = "buttons.hotkey.show",
        callback = RefreshButtons,
    })

    C:AddToggle(textVis, {
        label = LO["Range Indicator"],
        desc = LO["Show range indicator dot on buttons."],
        dbPath = "buttons.hotkey.range",
        callback = RefreshButtons,
        requiresReload = true,
    })

    C:AddToggle(textVis, {
        label = LO["Show Macro Names"],
        dbPath = "buttons.macros.show",
        callback = RefreshButtons,
    })

    C:AddToggle(textVis, {
        label = LO["Show Page Numbers"],
        dbPath = "buttons.pages.show",
        requiresReload = true,
    })

    -- Cooldown text
    local cdSection = C:AddSection(scroll, LO["Cooldown Text"])

    C:AddSlider(cdSection, {
        label = LO["Min Duration"],
        desc = LO["Minimum duration for cooldown text to appear."],
        dbPath = "buttons.cooldown.min_duration",
        min = 1, max = 10, step = 1,
        width = 200,
        callback = RefreshCooldowns,
    })

    C:AddSlider(cdSection, {
        label = LO["Font Size"],
        desc = LO["Size of cooldown text."],
        dbPath = "buttons.cooldown.font_size",
        min = 8, max = 24, step = 1,
        width = 200,
        callback = RefreshCooldowns,
    })

    C:AddColorPicker(cdSection, {
        label = LO["Cooldown Text Color"],
        getFunc = function()
            local c = addon.db.profile.buttons.cooldown.color
            if c then return c[1], c[2], c[3], c[4] end
            return 1, 1, 1, 1
        end,
        setFunc = function(r, g, b, a)
            addon.db.profile.buttons.cooldown.color = { r, g, b, a }
            RefreshCooldowns()
        end,
        hasAlpha = true,
    })

    -- Colors
    local colorSection = C:AddSection(scroll, LO["Colors"])

    C:AddColorPicker(colorSection, {
        label = LO["Macro Text Color"],
        getFunc = function()
            local c = addon.db.profile.buttons.macros.color
            if c then return c[1], c[2], c[3], c[4] end
            return 1, 1, 0, 1
        end,
        setFunc = function(r, g, b, a)
            addon.db.profile.buttons.macros.color = { r, g, b, a }
            RefreshButtons()
        end,
        hasAlpha = true,
    })

    C:AddColorPicker(colorSection, {
        label = LO["Hotkey Shadow Color"],
        getFunc = function()
            local c = addon.db.profile.buttons.hotkey.shadow
            if c then return c[1], c[2], c[3], c[4] end
            return 0, 0, 0, 1
        end,
        setFunc = function(r, g, b, a)
            addon.db.profile.buttons.hotkey.shadow = { r, g, b, a }
            RefreshButtons()
        end,
        hasAlpha = true,
    })

    C:AddColorPicker(colorSection, {
        label = LO["Border Color"],
        getFunc = function()
            local c = addon.db.profile.buttons.border_color
            if c then return c[1], c[2], c[3], c[4] end
            return 1, 1, 1, 1
        end,
        setFunc = function(r, g, b, a)
            addon.db.profile.buttons.border_color = { r, g, b, a }
            RefreshButtons()
        end,
        hasAlpha = true,
    })

    -- ====================================================================
    -- GRYPHONS
    -- ====================================================================
    local gryphons = C:AddSection(scroll, LO["Gryphons"])

    C:AddDescription(gryphons, LO["End-cap ornaments flanking the main action bar."])

    C:AddDropdown(gryphons, {
        label = LO["Style"],
        dbPath = "style.gryphons",
        values = {
            old    = LO["Classic"],
            new    = LO["Dragonflight"],
            flying = LO["Flying"],
            none   = LO["Hidden"],
        },
        width = 200,
        callback = function()
            if addon.RefreshMainbars then addon.RefreshMainbars() end
        end,
    })

    if IsD3D9ExActive() then
        C:AddDescription(gryphons, LO["Gryphon previews are hidden while D3D9Ex is active to avoid client crashes."])
    else
        -- Texture previews row
        local previewRow = C:AddRow(gryphons)
        local assets = addon._dir or "Interface\\AddOns\\DragonUI\\assets\\"
        local faction = UnitFactionGroup and UnitFactionGroup("player") or "Alliance"

        -- Classic gryphon preview
        C:AddTexturePreview(previewRow, {
            label = LO["Classic"],
            texture = assets .. "uiactionbar2x_",
            texCoord = { 1/512, 357/512, 209/2048, 543/2048 },
            width = 80,
            height = 80,
        })

        -- Dragonflight gryphon preview (faction-aware: gryphon=Alliance, wyvern=Horde)
        local dfTexCoord
        if faction == "Horde" then
            dfTexCoord = { 1/512, 357/512, 881/2048, 1215/2048 } -- wyvern-thick-left
        else
            dfTexCoord = { 1/512, 357/512, 209/2048, 543/2048 }  -- gryphon-thick-left
        end
        C:AddTexturePreview(previewRow, {
            label = faction == "Horde" and LO["Dragonflight (Wyvern)"] or LO["Dragonflight (Gryphon)"],
            texture = assets .. "uiactionbar2x_new",
            texCoord = dfTexCoord,
            width = 80,
            height = 80,
        })

        -- Flying gryphon preview
        C:AddTexturePreview(previewRow, {
            label = LO["Flying"],
            texture = assets .. "uiactionbar2x_flying",
            texCoord = { 1/256, 158/256, 149/2048, 342/2048 },
            width = 70,
            height = 90,
        })
    end
end

-- ============================================================================
-- LAYOUT SUB-TAB (grid layout: rows/columns/buttons per bar)
-- ============================================================================

local function BuildLayoutTab(scroll)
    -- ---- Global Button Spacing ----
    local spacingSection = C:AddSection(scroll, LO["Button Spacing"])

    C:AddSlider(spacingSection, {
        dbPath = "mainbars.button_spacing",
        label = LO["Button Spacing"],
        min = 0, max = 20, step = 1,
        width = 250,
        callback = RefreshBars,
    })

    -- ---- Main Bar ----
    local mainSection = C:AddSection(scroll, LO["Main Bar Layout"])

    C:AddDescription(mainSection,
        LO["Configure the main action bar grid layout. Rows are determined automatically from columns and buttons shown."])

    C:AddSlider(mainSection, {
        dbPath = "mainbars.player.columns",
        label = LO["Columns"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(mainSection, {
        dbPath = "mainbars.player.buttons_shown",
        label = LO["Buttons Shown"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    AddBarOrderControls(mainSection, "player")

    local mainPresetRow = C:AddRow(mainSection)

    C:AddButton(mainPresetRow, {
        label = "1x12",
        width = 60,
        callback = function()
            C:SetDBValue("mainbars.player.columns", 12)
            C:SetDBValue("mainbars.player.buttons_shown", 12)
            RefreshBars()
            Panel:SelectTab("actionbars")
        end,
    })

    C:AddButton(mainPresetRow, {
        label = "2x6",
        width = 60,
        callback = function()
            C:SetDBValue("mainbars.player.columns", 6)
            C:SetDBValue("mainbars.player.buttons_shown", 12)
            RefreshBars()
            Panel:SelectTab("actionbars")
        end,
    })

    C:AddButton(mainPresetRow, {
        label = "3x4",
        width = 60,
        callback = function()
            C:SetDBValue("mainbars.player.columns", 4)
            C:SetDBValue("mainbars.player.buttons_shown", 12)
            RefreshBars()
            Panel:SelectTab("actionbars")
        end,
    })

    C:AddButton(mainPresetRow, {
        label = "4x3",
        width = 60,
        callback = function()
            C:SetDBValue("mainbars.player.columns", 3)
            C:SetDBValue("mainbars.player.buttons_shown", 12)
            RefreshBars()
            Panel:SelectTab("actionbars")
        end,
    })

    -- ---- Bottom Left Bar ----
    local blSection = C:AddSection(scroll, LO["Bottom Left Bar Layout"])

    C:AddSlider(blSection, {
        dbPath = "mainbars.bottom_left.columns",
        label = LO["Columns"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(blSection, {
        dbPath = "mainbars.bottom_left.buttons_shown",
        label = LO["Buttons Shown"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    AddBarOrderControls(blSection, "bottom_left")

    -- ---- Bottom Right Bar ----
    local brSection = C:AddSection(scroll, LO["Bottom Right Bar Layout"])

    C:AddSlider(brSection, {
        dbPath = "mainbars.bottom_right.columns",
        label = LO["Columns"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(brSection, {
        dbPath = "mainbars.bottom_right.buttons_shown",
        label = LO["Buttons Shown"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    AddBarOrderControls(brSection, "bottom_right")

    -- ---- Right Bar ----
    local rightSection = C:AddSection(scroll, LO["Right Bar Layout"])

    C:AddSlider(rightSection, {
        dbPath = "mainbars.right.columns",
        label = LO["Columns"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(rightSection, {
        dbPath = "mainbars.right.buttons_shown",
        label = LO["Buttons Shown"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    AddBarOrderControls(rightSection, "right")

    -- ---- Left Bar (Blizzard: MultiBarLeft = "Right 2") ----
    local leftSection = C:AddSection(scroll, LO["Left Bar Layout"])

    C:AddSlider(leftSection, {
        dbPath = "mainbars.left.columns",
        label = LO["Columns"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(leftSection, {
        dbPath = "mainbars.left.buttons_shown",
        label = LO["Buttons Shown"],
        min = 1, max = 12, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    AddBarOrderControls(leftSection, "left")

    -- ---- Quick Presets ----
    local presetSection = C:AddSection(scroll, LO["Quick Presets"])

    C:AddDescription(presetSection, LO["Apply layout presets to multiple bars at once."])

    local presetRow = C:AddRow(presetSection)

    C:AddButton(presetRow, {
        label = LO["Both 1x12"],
        width = 90,
        callback = function()
            for _, key in ipairs({"bottom_left", "bottom_right"}) do
                C:SetDBValue("mainbars." .. key .. ".columns", 12)
                C:SetDBValue("mainbars." .. key .. ".buttons_shown", 12)
            end
            RefreshBars()
            Panel:SelectTab("actionbars")
        end,
    })

    C:AddButton(presetRow, {
        label = LO["Both 2x6"],
        width = 90,
        callback = function()
            for _, key in ipairs({"bottom_left", "bottom_right"}) do
                C:SetDBValue("mainbars." .. key .. ".columns", 6)
                C:SetDBValue("mainbars." .. key .. ".buttons_shown", 12)
            end
            RefreshBars()
            Panel:SelectTab("actionbars")
        end,
    })

    C:AddButton(presetRow, {
        label = LO["Reset All"],
        width = 90,
        callback = function()
            C:SetDBValue("mainbars.player.columns", 12)
            C:SetDBValue("mainbars.player.buttons_shown", 12)
            C:SetDBValue("mainbars.player.change_button_order", false)
            C:SetDBValue("mainbars.player.button_order", "top_left")
            for _, key in ipairs({"bottom_left", "bottom_right"}) do
                C:SetDBValue("mainbars." .. key .. ".columns", 12)
                C:SetDBValue("mainbars." .. key .. ".buttons_shown", 12)
                C:SetDBValue("mainbars." .. key .. ".change_button_order", false)
                C:SetDBValue("mainbars." .. key .. ".button_order", "top_left")
            end
            C:SetDBValue("mainbars.right.columns", 1)
            C:SetDBValue("mainbars.right.buttons_shown", 12)
            C:SetDBValue("mainbars.right.change_button_order", false)
            C:SetDBValue("mainbars.right.button_order", "top_left")
            C:SetDBValue("mainbars.left.columns", 1)
            C:SetDBValue("mainbars.left.buttons_shown", 12)
            C:SetDBValue("mainbars.left.change_button_order", false)
            C:SetDBValue("mainbars.left.button_order", "top_left")
            RefreshBars()
            Panel:SelectTab("actionbars")
            print("|cFF00FF00[DragonUI]|r " .. LO["All bar layouts reset to defaults."])
        end,
    })
end

-- ============================================================================
-- VISIBILITY SUB-TAB (hover/combat show/hide per bar)
-- ============================================================================

local function RefreshVisibility()
    if addon.RefreshActionBarVisibility then addon.RefreshActionBarVisibility() end
    -- Keep Blizzard Interface Options in sync with our toggles
    if addon.SyncBarCVarsFromProfile then addon.SyncBarCVarsFromProfile() end
end

local function BuildVisibilityTab(scroll)
    local desc = C:AddSection(scroll, LO["Bar Visibility"])
    C:AddDescription(desc,
        LO["Control when action bars are visible. Bars can show only on hover, only in combat, or both. When no option is checked the bar is always visible."])

    local fadeSection = C:AddSection(scroll, LO["Hover Fade"])

    C:AddSlider(fadeSection, {
        label = LO["Visible Alpha"],
        desc = LO["Opacity when a bar is considered visible by hover/combat rules."],
        dbPath = "actionbars.visibility_shown_alpha",
        min = 0, max = 1, step = 0.01,
        isPercent = true,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(fadeSection, {
        label = LO["Hidden Alpha"],
        desc = LO["Opacity when a bar is hidden by hover/combat rules. Set above 0 to keep bars faintly visible."],
        dbPath = "actionbars.visibility_hidden_alpha",
        min = 0, max = 1, step = 0.01,
        isPercent = true,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(fadeSection, {
        label = LO["Fade In Duration"],
        desc = LO["Seconds used to fade bars in when they become visible."],
        dbPath = "actionbars.visibility_fade_in_duration",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(fadeSection, {
        label = LO["Fade Out Duration"],
        desc = LO["Seconds used to fade bars out when they become hidden."],
        dbPath = "actionbars.visibility_fade_out_duration",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(fadeSection, {
        label = LO["Fade Out Delay"],
        desc = LO["Delay before hover-out starts fading, useful to avoid flicker between buttons."],
        dbPath = "actionbars.visibility_fade_out_delay",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    local logicValues = {
        ["and"] = LO["AND (both required)"],
        ["or"] = LO["OR (either condition)"],
    }

    local function AddVisibilityModeOptions(section, barKey)
        C:AddDropdown(section, {
            label = LO["Hover/Combat Logic"],
            desc = LO["When both hover and combat are enabled, choose whether both are required (AND) or either condition is enough (OR)."],
            dbPath = "actionbars." .. barKey .. "_visibility_logic",
            values = logicValues,
            callback = RefreshVisibility,
        })
    end

    -- Show in Combat / Hide in Combat are mutually exclusive — enabling one clears the other.
    local function AddCombatToggle(section, barKey, dbSuffix, otherSuffix, label, desc)
        C:AddToggle(section, {
            label = label,
            desc = desc,
            dbPath = "actionbars." .. barKey .. "_" .. dbSuffix,
            callback = function()
                local conflicted = C:GetDBValue("actionbars." .. barKey .. "_" .. dbSuffix)
                    and C:GetDBValue("actionbars." .. barKey .. "_" .. otherSuffix)
                if conflicted then
                    C:SetDBValue("actionbars." .. barKey .. "_" .. otherSuffix, false)
                end
                RefreshVisibility()
                if conflicted and Panel.currentTab then Panel:SelectTab(Panel.currentTab) end
            end,
        })
    end

    -- Builds the standard 4-control Show on Hover / Show in Combat / Hide in Combat / AND-OR block
    -- used by every bar migrated to the shared addon.VisibilityFade engine (everything but Main Bar).
    local function BuildMigratedBarVisibilitySection(barKey, title, hoverDesc, combatDesc)
        local section = C:AddSection(scroll, title)

        C:AddToggle(section, {
            label = LO["Show on Hover Only"],
            desc = hoverDesc,
            dbPath = "actionbars." .. barKey .. "_show_on_hover",
            callback = RefreshVisibility,
        })

        AddCombatToggle(section, barKey, "show_in_combat", "hide_in_combat",
            LO["Show in Combat Only"], combatDesc)
        AddCombatToggle(section, barKey, "hide_in_combat", "show_in_combat",
            LO["Hide in Combat"], nil)

        AddVisibilityModeOptions(section, barKey)
        return section
    end

    -- Enable/disable secondary bars
    local enableSection = C:AddSection(scroll, LO["Enable / Disable Bars"])

    C:AddToggle(enableSection, {
        label = LO["Bottom Left Bar"],
        dbPath = "actionbars.bottom_left_enabled",
        callback = RefreshVisibility,
    })

    C:AddToggle(enableSection, {
        label = LO["Bottom Right Bar"],
        dbPath = "actionbars.bottom_right_enabled",
        callback = RefreshVisibility,
    })

    C:AddToggle(enableSection, {
        label = LO["Right Bar"],
        dbPath = "actionbars.right_enabled",
        callback = RefreshVisibility,
    })

    C:AddToggle(enableSection, {
        label = LO["Left Bar"],
        dbPath = "actionbars.left_enabled",
        callback = RefreshVisibility,
    })

    -- Main bar hover/combat
    local mainVis = C:AddSection(scroll, LO["Main Bar"])

    C:AddToggle(mainVis, {
        label = LO["Show on Hover Only"],
        desc = LO["Hide the main bar until you hover over it."],
        dbPath = "actionbars.main_show_on_hover",
        callback = RefreshVisibility,
    })

    AddCombatToggle(mainVis, "main", "show_in_combat", "hide_in_combat",
        LO["Show in Combat Only"], LO["Hide the main bar until you enter combat."])
    AddCombatToggle(mainVis, "main", "hide_in_combat", "show_in_combat",
        LO["Hide in Combat"], LO["Hide the main bar while in combat."])
    AddVisibilityModeOptions(mainVis, "main")

    -- All secondary bars get the full Show on Hover / Show in Combat / Hide in Combat / AND-OR block.
    BuildMigratedBarVisibilitySection("bottom_left", LO["Bottom Left Bar"])
    BuildMigratedBarVisibilitySection("bottom_right", LO["Bottom Right Bar"])
    BuildMigratedBarVisibilitySection("right", LO["Right Bar"])
    BuildMigratedBarVisibilitySection("left", LO["Left Bar"])
    BuildMigratedBarVisibilitySection("micro", LO["Micro Menu"])
    BuildMigratedBarVisibilitySection("bag", LO["Bag Bar"])
end

-- ============================================================================
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    general    = BuildGeneralTab,
    layout     = BuildLayoutTab,
    visibility = BuildVisibilityTab,
}

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local function BuildActionbarsTab(scroll)
    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("actionbars")
    end, subTabBuilders)

    if not Panel.indexing then
        local builder = subTabBuilders[activeSubTab]
        if builder then builder(scroll) end
    end
end

-- Register the tab
Panel:RegisterTab("actionbars", LO["Action Bars"], BuildActionbarsTab, 3)
