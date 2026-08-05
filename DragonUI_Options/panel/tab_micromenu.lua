--[[
================================================================================
DragonUI Options Panel - Micro Menu Tab
================================================================================
Micro menu, bags, XP/rep bars, additional bars.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

local function RefreshVisibility()
    if addon.RefreshActionBarVisibility then addon.RefreshActionBarVisibility() end
end

-- ============================================================================
-- MICRO MENU TAB BUILDER
-- ============================================================================

local function BuildMicromenuTab(scroll)
    -- ====================================================================
    -- MICRO MENU
    -- ====================================================================
    local menu = C:AddSection(scroll, LO["Micro Menu"])

    C:AddToggle(menu, {
        label = LO["Grayscale Icons"],
        desc = LO["Use grayscale icons instead of colored icons."],
        dbPath = "micromenu.grayscale_icons",
        requiresReload = true,
    })

    -- Mode-aware scale
    local modeKey = function()
        return (C:GetDBValue("micromenu.grayscale_icons") and "grayscale" or "normal")
    end

    C:AddSlider(menu, {
        label = LO["Menu Scale"],
        getFunc = function()
            return C:GetDBValue("micromenu." .. modeKey() .. ".scale_menu")
        end,
        setFunc = function(val)
            C:SetDBValue("micromenu." .. modeKey() .. ".scale_menu", val)
            if addon.RefreshMicromenu then addon.RefreshMicromenu() end
        end,
        min = 0.5, max = 3.0, step = 0.01,
        width = 200,
    })

    C:AddSlider(menu, {
        label = LO["Icon Spacing"],
        desc = LO["Padding between micromenu buttons."],
        getFunc = function()
            return C:GetDBValue("micromenu." .. modeKey() .. ".icon_spacing") or 0
        end,
        setFunc = function(val)
            C:SetDBValue("micromenu." .. modeKey() .. ".icon_spacing", val)
            if addon.RefreshMicromenu then addon.RefreshMicromenu() end
        end,
        min = -20, max = 40, step = 1,
        width = 200,
    })

    C:AddSlider(menu, {
        label = LO["Columns"],
        desc = LO["Number of micromenu button columns. Set to 1 for a vertical stack."],
        getFunc = function()
            return C:GetDBValue("micromenu." .. modeKey() .. ".columns") or 12
        end,
        setFunc = function(val)
            C:SetDBValue("micromenu." .. modeKey() .. ".columns", val)
            if addon.RefreshMicromenu then addon.RefreshMicromenu() end
        end,
        min = 1, max = 12, step = 1,
        width = 200,
    })

    C:AddToggle(menu, {
        label = LO["Invert Button Order"],
        desc = LO["Reverse the order of micromenu buttons in the grid."],
        getFunc = function()
            return C:GetDBValue("micromenu." .. modeKey() .. ".invert_order") == true
        end,
        setFunc = function(val)
            C:SetDBValue("micromenu." .. modeKey() .. ".invert_order", val)
            if addon.RefreshMicromenu then addon.RefreshMicromenu() end
        end,
    })

    C:AddToggle(menu, {
        label = LO["Hide on Vehicle"],
        desc = LO["Hide micromenu and bags while in a vehicle."],
        dbPath = "micromenu.hide_on_vehicle",
        callback = function()
            if addon.RefreshMicromenuVehicle then addon.RefreshMicromenuVehicle() end
            if addon.RefreshBagsVehicle then addon.RefreshBagsVehicle() end
        end,
    })

    C:AddToggle(menu, {
        label = LO["Show Latency Indicator"],
        desc = LO["Show a colored bar below the Help button indicating connection quality (green/yellow/red). Requires UI reload."],
        dbPath = "micromenu.show_latency_indicator",
        callback = function()
            StaticPopup_Show("DRAGONUI_RELOAD_UI")
        end,
    })

    local visibility = C:AddSection(scroll, LO["Visibility"])
    local logicValues = {
        ["and"] = LO["AND (both required)"],
        ["or"] = LO["OR (either condition)"],
    }

    C:AddToggle(visibility, {
        label = LO["Always Hidden"],
        dbPath = "actionbars.micro_always_hidden",
        callback = RefreshVisibility,
    })

    C:AddToggle(visibility, {
        label = LO["Show on Hover Only"],
        dbPath = "actionbars.micro_show_on_hover",
        callback = RefreshVisibility,
    })

    C:AddToggle(visibility, {
        label = LO["Show in Combat Only"],
        dbPath = "actionbars.micro_show_in_combat",
        callback = RefreshVisibility,
    })

    C:AddSlider(visibility, {
        label = LO["Visible Alpha"],
        desc = LO["Opacity when a bar is considered visible by hover/combat rules."],
        dbPath = "actionbars.micro_visibility_shown_alpha",
        min = 0, max = 1, step = 0.01,
        isPercent = true,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(visibility, {
        label = LO["Hidden Alpha"],
        desc = LO["Opacity when a bar is hidden by hover/combat rules. Set above 0 to keep bars faintly visible."],
        dbPath = "actionbars.micro_visibility_hidden_alpha",
        min = 0, max = 1, step = 0.01,
        isPercent = true,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(visibility, {
        label = LO["Fade In Duration"],
        desc = LO["Seconds used to fade bars in when they become visible."],
        dbPath = "actionbars.micro_visibility_fade_in_duration",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(visibility, {
        label = LO["Fade Out Duration"],
        desc = LO["Seconds used to fade bars out when they become hidden."],
        dbPath = "actionbars.micro_visibility_fade_out_duration",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(visibility, {
        label = LO["Fade Out Delay"],
        desc = LO["Delay before hover-out starts fading, useful to avoid flicker between buttons."],
        dbPath = "actionbars.micro_visibility_fade_out_delay",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddDropdown(visibility, {
        label = LO["Hover/Combat Logic"],
        desc = LO["When both hover and combat are enabled, choose whether both are required (AND) or either condition is enough (OR)."],
        dbPath = "actionbars.micro_visibility_logic",
        values = logicValues,
        callback = RefreshVisibility,
    })

end

-- Register the tab
Panel:RegisterTab("micromenu", LO["Micro Menu"], BuildMicromenuTab, 9)
