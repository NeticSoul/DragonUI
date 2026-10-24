-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - Minimap Tab
================================================================================
Minimap scale, tracking, clock, display settings.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- MINIMAP TAB BUILDER
-- ============================================================================

local function RefreshMinimap()
    if addon.RefreshMinimap then
        addon:RefreshMinimap()
        return
    end

    if addon.MinimapModule then
        addon.MinimapModule:UpdateSettings()
    end
end

local function RefreshAnimatedBorder()
    if addon.MinimapDecorations and addon.MinimapDecorations.Refresh then
        addon.MinimapDecorations:Refresh()
    else
        RefreshMinimap()
    end
end

local AUTO_SCALE_BORDER_VISIBLE = 0.9
local AUTO_SCALE_BORDER_HIDDEN = 1

local function GetMinimapSettingsTable()
    return addon.db and addon.db.profile and addon.db.profile.minimap
end

local function GetRecommendedAnimatedBorderScale(settings)
    -- Square presets frame the map at their own size; only round ones tuck inside the ring.
    local square = settings and (settings.style == "dragonui_square" or settings.style == "forever_square")
    if settings and (settings.animated_border_hide_dragonui_border == true or square) then
        return AUTO_SCALE_BORDER_HIDDEN
    end
    return AUTO_SCALE_BORDER_VISIBLE
end

local function ApplyAnimatedBorderAutoScaleIfNeeded()
    local settings = GetMinimapSettingsTable()
    if not settings or settings.animated_border_scale_auto == false then
        return false, nil
    end

    local recommended = GetRecommendedAnimatedBorderScale(settings)
    local changed = settings.animated_border_scale ~= recommended
    settings.animated_border_scale = recommended
    settings.animated_border_scale_auto = true
    return changed, recommended
end

local function MarkAnimatedBorderScaleManual()
    local settings = GetMinimapSettingsTable()
    if settings then
        settings.animated_border_scale_auto = false
    end
end

local function GetAnimatedBorderPresets()
    if addon.MinimapDecorations and addon.MinimapDecorations.GetPresetList then
        return addon.MinimapDecorations:GetPresetList()
    end

    return {
        ["drg_preset_01"] = "Blue Rune Circles",
        ["drg_preset_02"] = "Blue Rune Diamond",
        ["drg_preset_03"] = "Burning Sun",
        ["drg_preset_04"] = "Stargate",
        ["drg_preset_05"] = "Rogue",
        ["drg_preset_06"] = "Emerald Portal by Korryna",
        ["drg_preset_07"] = "Shamanism by Jaygoody",
    }
end

-- Hybrid mode leaves the ring to SexyMap, so the Forever style is off there.
local function IsForeverMinimap()
    local modules = addon.db and addon.db.profile and addon.db.profile.modules
    local mode = modules and modules.minimap and modules.minimap.sexymap_mode
    local style = C:GetDBValue("minimap.style")
    return (style == "forever" or style == "forever_square") and mode ~= "hybrid"
end

local function IsCollectorEnabled()
    local enabled = C:GetDBValue("minimap.collector_enabled")
    if enabled == nil then
        return true
    end
    return enabled
end

local function SetSectionVisualState(section, enabled)
    if not section or Panel.indexing then
        return
    end

    C.SetSectionState(section, enabled)
end

local function BuildMinimapTab(scroll)
    -- ====================================================================
    -- COLLECTOR SETTINGS (TOP PRIORITY)
    -- ====================================================================
    local collector = C:AddSection(scroll, LO["Minimap Buttons Collector"])
    local collectorWidgets = {}
    local collectorStyleDropdown

    -- Forever has no arrow collector: the dropdown shows Circle and locks while it is on.
    local function GetCollectorStyle()
        if IsForeverMinimap() then return "dragonui" end
        return C:GetDBValue("minimap.collector_style") or "dragonui"
    end

    local function UpdateCollectorSectionState()
        if Panel.indexing then return end
        local enabled = IsCollectorEnabled()
        for _, widget in ipairs(collectorWidgets) do
            if widget and widget.SetDisabled then
                widget:SetDisabled(not enabled)
            end
        end
        if collectorStyleDropdown then
            collectorStyleDropdown:SetValue(GetCollectorStyle())
            collectorStyleDropdown:SetDisabled(not enabled or IsForeverMinimap())
        end
        SetSectionVisualState(collector, enabled)
    end

    C:AddToggle(collector, {
        label = LO["Enable"],
        dbPath = "minimap.collector_enabled",
        callback = function()
            UpdateCollectorSectionState()
            RefreshMinimap()
        end,
    })

    collectorStyleDropdown = C:AddDropdown(collector, {
        label = LO["Style"],
        values = {
            dragonui = LO["Circle"],
            classic = LO["Arrow"],
        },
        width = 220,
        dbPath = "minimap.collector_style",
        getFunc = GetCollectorStyle,
        callback = RefreshMinimap,
    })

    UpdateCollectorSectionState()

    local UpdateAnimatedBorderSectionState -- forward declare

    -- ====================================================================
    -- BASIC SETTINGS
    -- ====================================================================
    local basic = C:AddSection(scroll, LO["Basic Settings"])
    local squareBorderDropdown, topArrowToggle, roundedToggle

    local function UpdateSquareBorderState()
        if Panel.indexing or not squareBorderDropdown or not topArrowToggle or not roundedToggle then return end
        local foreverSquare = IsForeverMinimap() and C:GetDBValue("minimap.style") == "forever_square"
        local thin = foreverSquare and C:GetDBValue("minimap.forever_square_border") == "thin"
        squareBorderDropdown:SetDisabled(not foreverSquare)
        topArrowToggle:SetDisabled(not foreverSquare or thin)
        roundedToggle:SetDisabled(not foreverSquare or thin)
    end

    C:AddDropdown(basic, {
        label = LO["Style"],
        dbPath = "minimap.style",
        values = {
            dragonui = LO["DragonUI"],
            dragonui_square = LO["DragonUI Square"],
            forever = LO["Forever"],
            forever_square = LO["Forever Square"],
        },
        callback = function()
            UpdateCollectorSectionState()
            UpdateSquareBorderState()
            if UpdateAnimatedBorderSectionState then
                UpdateAnimatedBorderSectionState()
            end
            RefreshMinimap()
            RefreshAnimatedBorder()
        end,
    })

    squareBorderDropdown = C:AddDropdown(basic, {
        label = LO["Square Border"],
        dbPath = "minimap.forever_square_border",
        values = {
            frame = LO["Forever Frame"],
            thin = LO["Thin Line"],
        },
        callback = function()
            UpdateSquareBorderState()
            RefreshMinimap()
        end,
    })

    topArrowToggle = C:AddToggle(basic, {
        label = LO["Top Arrow"],
        dbPath = "minimap.square_top_arrow",
        callback = RefreshMinimap,
    })

    roundedToggle = C:AddToggle(basic, {
        label = LO["Rounded Corners"],
        dbPath = "minimap.forever_square_rounded",
        callback = RefreshMinimap,
    })
    UpdateSquareBorderState()

    C:AddSlider(basic, {
        label = LO["Scale"],
        dbPath = "minimap.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = RefreshMinimap,
    })

    C:AddSlider(basic, {
        label = LO["Border Alpha"],
        desc = LO["Top border alpha (0 to hide)."],
        dbPath = "minimap.border_alpha",
        min = 0, max = 1, step = 0.1,
        width = 200,
        callback = function()
            local val = C:GetDBValue("minimap.border_alpha") or 1
            if MinimapBorderTop then MinimapBorderTop:SetAlpha(val) end
            -- The top bar's On Hover fades in to this alpha.
            RefreshMinimap()
        end,
    })

    C:AddToggle(basic, {
        label = LO["Addon Button Skin"],
        desc = LO["Apply DragonUI border styling to addon icons."],
        dbPath = "minimap.addon_button_skin",
        callback = function()
            if addon.RefreshMinimap then addon:RefreshMinimap() end
        end,
    })

    C:AddToggle(basic, {
        label = LO["New Blip Style"],
        desc = LO["Use newer-style minimap blip icons."],
        dbPath = "minimap.blip_skin",
        callback = RefreshMinimap,
    })

    C:AddToggle(basic, {
        label = LO["Show Ping Sender"],
        desc = LO["Show who pinged the minimap, in their class color."],
        dbPath = "minimap.ping_sender",
    })

    C:AddSlider(basic, {
        label = LO["Player Arrow Size"],
        dbPath = "minimap.player_arrow_size",
        min = 8, max = 50, step = 1,
        width = 200,
        callback = RefreshMinimap,
    })

    local farm = C:AddSection(scroll, LO["Farm Mode"])
    C:AddDescription(farm, LO["Bigger minimap with the surrounding clutter hidden."])

    C:AddToggle(farm, {
        label = LO["Enable"],
        dbPath = "minimap.farm_mode_enabled",
        callback = RefreshMinimap,
    })

    C:AddSlider(farm, {
        label = LO["Extra scale"],
        desc = LO["Extra scale applied on top of the minimap scale."],
        dbPath = "minimap.farm_mode_scale",
        min = 1.0, max = 2.0, step = 0.05,
        width = 200,
        callback = RefreshMinimap,
    })

    -- ====================================================================
    -- TIME & CALENDAR
    -- ====================================================================
    local time = C:AddSection(scroll, LO["Time & Calendar"])

    C:AddSlider(time, {
        label = LO["Clock Font Size"],
        dbPath = "minimap.clock_font_size",
        min = 8, max = 20, step = 1,
        width = 200,
        callback = RefreshMinimap,
    })

    -- ====================================================================
    -- DISPLAY SETTINGS
    -- ====================================================================
    local display = C:AddSection(scroll, LO["Display Settings"])

    C:AddToggle(display, {
        label = LO["Tracking Icons"],
        desc = LO["Show current tracking icons (old style)."],
        dbPath = "minimap.tracking_icons",
        callback = function()
            if addon.MinimapModule then addon.MinimapModule:UpdateTrackingIcon() end
        end,
    })

    -- ====================================================================
    -- ZONE TEXT
    -- ====================================================================
    local zoneText = C:AddSection(scroll, LO["Zone Text"])

    C:AddDropdown(zoneText, {
        label = LO["Visibility"],
        dbPath = "minimap.zonetext_show",
        values = {
            always = LO["Always"],
            hover = LO["On Hover"],
            never = LO["Never"],
        },
        callback = RefreshMinimap,
    })

    local zoneFontRow = C:AddRow(zoneText)
    C:AddDropdown(zoneFontRow, {
        label = LO["Font"],
        dbPath = "minimap.zonetext_font",
        values = {
            primary = "Friz Quadrata",
            actionbar = "Expressway",
            narrow = "PT Sans Narrow",
            arial = "Arial Narrow",
            skurri = "Skurri",
            morpheus = "Morpheus",
        },
        callback = RefreshMinimap,
    })
    C:AddSlider(zoneFontRow, {
        label = LO["Font Size"],
        desc = LO["Font size of the zone text above the minimap."],
        dbPath = "minimap.zonetext_font_size",
        min = 8, max = 20, step = 1,
        width = 200,
        callback = RefreshMinimap,
    })

    local zoneColorPicker
    C:AddToggle(zoneText, {
        label = LO["Custom Color"],
        desc = LO["Use one color instead of the PvP zone colors."],
        dbPath = "minimap.zonetext_custom_color",
        callback = function(value)
            if zoneColorPicker and zoneColorPicker.SetDisabled then zoneColorPicker:SetDisabled(not value) end
            RefreshMinimap()
        end,
    })
    zoneColorPicker = C:AddColorPicker(zoneText, {
        label = LO["Text Color"],
        dbPath = "minimap.zonetext_color",
        disabled = function() return not C:GetDBValue("minimap.zonetext_custom_color") end,
        callback = RefreshMinimap,
    })

    local zonePositionRow = C:AddRow(zoneText)
    C:AddSlider(zonePositionRow, {
        label = LO["X Position"],
        desc = LO["Moves the top bar with the zone text and the buttons around it."],
        dbPath = "minimap.zonetext_offset_x",
        min = -200, max = 200, step = 1,
        width = 200,
        callback = RefreshMinimap,
    })
    C:AddSlider(zonePositionRow, {
        label = LO["Y Position"],
        desc = LO["Moves the top bar with the zone text and the buttons around it."],
        dbPath = "minimap.zonetext_offset_y",
        min = -250, max = 100, step = 1,
        width = 200,
        callback = RefreshMinimap,
    })
    C:AddSlider(zoneText, {
        label = LO["Width"],
        desc = LO["Width of the top bar. 0 keeps the default."],
        dbPath = "minimap.zonetext_width",
        min = 0, max = 300, step = 1,
        width = 200,
        callback = RefreshMinimap,
    })

    C:AddDescription(zoneText, LO["Raise the alpha to draw a box behind the zone text."])
    local zoneBoxRow = C:AddRow(zoneText)
    C:AddColorPicker(zoneBoxRow, {
        label = LO["Background Color"],
        dbPath = "minimap.zonetext_bg_color",
        hasAlpha = true,
        callback = RefreshMinimap,
    })
    C:AddColorPicker(zoneBoxRow, {
        label = LO["Border Color"],
        dbPath = "minimap.zonetext_border_color",
        hasAlpha = true,
        callback = RefreshMinimap,
    })

    -- ====================================================================
    -- MINIMAP BUTTONS
    -- ====================================================================
    local buttons = C:AddSection(scroll, LO["Minimap Buttons"])
    C:AddDescription(buttons, LO["On Hover shows a button while the mouse is over the minimap. Never hides it, and takes an addon button out of the collector."])

    local visibilityValues = {
        always = LO["Always"],
        hover = LO["On Hover"],
        never = LO["Never"],
    }

    local buttonRow
    for index, entry in ipairs(addon.MINIMAP_VISIBILITY_BUTTONS or {}) do
        if index % 2 == 1 then buttonRow = C:AddRow(buttons) end
        C:AddDropdown(buttonRow, {
            label = LO[entry.label],
            dbPath = "minimap.button_visibility." .. entry.key,
            values = visibilityValues,
            width = 220,
            callback = RefreshMinimap,
        })
    end

    C:AddHeading(buttons, LO["Addon Buttons"])
    C:AddDropdown(buttons, {
        label = LO["All Addon Buttons"],
        dbPath = "minimap.addon_button_default",
        values = visibilityValues,
        width = 220,
        callback = RefreshMinimap,
    })

    -- "_default" sorts first in the dropdown; picking it clears the button's own entry.
    local addonValues = { _default = LO["Use Default"] }
    for key, label in pairs(visibilityValues) do addonValues[key] = label end

    local module = addon.MinimapModule
    local addonButtons = module and module.GetAddonButtonList and module.GetAddonButtonList() or {}
    if #addonButtons == 0 then
        C:AddDescription(buttons, LO["No addon buttons found on the minimap."])
    end
    local addonRow
    for index, entry in ipairs(addonButtons) do
        if index % 2 == 1 then addonRow = C:AddRow(buttons) end
        C:AddDropdown(addonRow, {
            label = entry.label,
            values = addonValues,
            width = 220,
            getFunc = function()
                local own = C:GetDBValue("minimap.addon_button_visibility")
                return own and own[entry.name] or "_default"
            end,
            setFunc = function(value)
                local own = C:GetDBValue("minimap.addon_button_visibility")
                if own then own[entry.name] = value ~= "_default" and value or nil end
            end,
            callback = RefreshMinimap,
        })
    end

    -- ====================================================================
    -- ANIMATED BORDER DECORATIONS
    -- ====================================================================
    local animatedBorder = C:AddSection(scroll, LO["Minimap Decorations"])
    C:AddDescription(animatedBorder, LO["Border presets from SexyMap by funkydude, used with permission."])
    local animatedBorderWidgets = {}
    local animatedBorderScaleSlider
    local presetDropdown

    -- Round and square styles offer different presets, so each keeps its own choice.
    local function GetPresetPath()
        local style = C:GetDBValue("minimap.style")
        local square = style == "dragonui_square" or style == "forever_square"
        return square and "minimap.animated_border_square_preset" or "minimap.animated_border_preset"
    end

    local function IsAnimatedBorderEnabled()
        return C:GetDBValue("minimap.animated_border_enabled") == true
    end

    UpdateAnimatedBorderSectionState = function()
        if Panel.indexing then return end
        local enabled = IsAnimatedBorderEnabled()
        for _, widget in ipairs(animatedBorderWidgets) do
            if widget and widget.SetDisabled then
                widget:SetDisabled(not enabled)
            end
        end
        if presetDropdown and presetDropdown.SetList then
            presetDropdown:SetList(GetAnimatedBorderPresets())
            presetDropdown:SetValue(C:GetDBValue(GetPresetPath()))
        end
        local _, recommendedScale = ApplyAnimatedBorderAutoScaleIfNeeded()
        if recommendedScale and animatedBorderScaleSlider and animatedBorderScaleSlider.SetValue then
            animatedBorderScaleSlider:SetValue(recommendedScale)
        end
        SetSectionVisualState(animatedBorder, enabled)
    end

    C:AddDescription(animatedBorder,
        LO["Adds decorative animated texture layers around the DragonUI minimap."])

    local hideDragonUIBorderToggle

    C:AddToggle(animatedBorder, {
        label = LO["Enable Minimap Decorations"],
        dbPath = "minimap.animated_border_enabled",
        callback = function()
            if not IsAnimatedBorderEnabled() then
                C:SetDBValue("minimap.animated_border_hide_dragonui_border", false)
                if hideDragonUIBorderToggle and hideDragonUIBorderToggle.SetValue then
                    hideDragonUIBorderToggle:SetValue(false)
                end
            end
            UpdateAnimatedBorderSectionState()
            RefreshAnimatedBorder()
        end,
    })

    presetDropdown = C:AddDropdown(animatedBorder, {
        label = LO["Preset"],
        values = GetAnimatedBorderPresets(),
        width = 260,
        dbPath = "minimap.animated_border_preset",
        getFunc = function() return C:GetDBValue(GetPresetPath()) end,
        setFunc = function(value) C:SetDBValue(GetPresetPath(), value) end,
        callback = RefreshAnimatedBorder,
    })
    animatedBorderWidgets[#animatedBorderWidgets + 1] = presetDropdown

    animatedBorderWidgets[#animatedBorderWidgets + 1] = C:AddToggle(animatedBorder, {
        label = LO["Animated Effects"],
        desc = LO["Rotate preset layers when the selected preset includes animation."],
        dbPath = "minimap.animated_border_animations",
        callback = RefreshAnimatedBorder,
    })

    hideDragonUIBorderToggle = C:AddToggle(animatedBorder, {
        label = LO["Hide DragonUI Border"],
        dbPath = "minimap.animated_border_hide_dragonui_border",
        callback = function()
            local _, recommendedScale = ApplyAnimatedBorderAutoScaleIfNeeded()
            if recommendedScale and animatedBorderScaleSlider and animatedBorderScaleSlider.SetValue then
                animatedBorderScaleSlider:SetValue(recommendedScale)
            end
            RefreshAnimatedBorder()
        end,
    })
    animatedBorderWidgets[#animatedBorderWidgets + 1] = hideDragonUIBorderToggle

    animatedBorderScaleSlider = C:AddSlider(animatedBorder, {
        label = LO["Scale"],
        dbPath = "minimap.animated_border_scale",
        min = 0.5, max = 2, step = 0.01,
        width = 200,
        callback = function()
            MarkAnimatedBorderScaleManual()
            RefreshAnimatedBorder()
        end,
    })
    animatedBorderWidgets[#animatedBorderWidgets + 1] = animatedBorderScaleSlider

    animatedBorderWidgets[#animatedBorderWidgets + 1] = C:AddSlider(animatedBorder, {
        label = LO["Opacity"],
        dbPath = "minimap.animated_border_opacity",
        min = 0, max = 1, step = 0.05,
        width = 200,
        callback = RefreshAnimatedBorder,
    })

    UpdateAnimatedBorderSectionState()

    -- ====================================================================
    -- VISIBILITY (EXPERIMENTAL)
    -- ====================================================================
    local visibility = C:AddSection(scroll, LO["Visibility"])

    C:AddDescription(visibility,
        "|cFFFFAA00" .. LO["Experimental:"] .. "|r " ..
        LO["Fading the minimap can occasionally cause tracking icons to stop updating until you /reload. Use at your own risk."])

    local function SyncMinimapVisibilityOption()
        if addon.MinimapModule and addon.MinimapModule.SyncMinimapVisibility then
            addon.MinimapModule.SyncMinimapVisibility()
        end
    end

    -- Built manually (not via C:AddVisibilityFadeToggles) so "Hide in Combat" can sit right after
    -- "Show in Combat Only" instead of after the AND/OR dropdown.
    C:AddToggle(visibility, {
        label = LO["Show on Hover Only"],
        desc = LO["Fade the minimap until you hover over it."],
        dbPath = "minimap.show_on_hover",
        callback = SyncMinimapVisibilityOption,
    })

    C:AddToggle(visibility, {
        label = LO["Show in Combat Only"],
        desc = LO["Fade the minimap until you enter combat."],
        dbPath = "minimap.show_in_combat",
        callback = function()
            local conflicted = C:GetDBValue("minimap.show_in_combat") and C:GetDBValue("minimap.hide_in_combat")
            if conflicted then
                C:SetDBValue("minimap.hide_in_combat", false)
            end
            SyncMinimapVisibilityOption()
            if conflicted and Panel.currentTab then Panel:SelectTab(Panel.currentTab) end
        end,
    })

    C:AddToggle(visibility, {
        label = LO["Hide in Combat"],
        desc = LO["Hide the minimap while in combat."],
        dbPath = "minimap.hide_in_combat",
        callback = function()
            local conflicted = C:GetDBValue("minimap.hide_in_combat") and C:GetDBValue("minimap.show_in_combat")
            if conflicted then
                C:SetDBValue("minimap.show_in_combat", false)
            end
            SyncMinimapVisibilityOption()
            if conflicted and Panel.currentTab then Panel:SelectTab(Panel.currentTab) end
        end,
    })

    C:AddDropdown(visibility, {
        label = LO["Hover/Combat Logic"],
        desc = LO["When both hover and combat are enabled, choose whether both are required (AND) or either condition is enough (OR)."],
        dbPath = "minimap.visibility_logic",
        values = {
            ["and"] = LO["AND (both required)"],
            ["or"] = LO["OR (either condition)"],
        },
        callback = SyncMinimapVisibilityOption,
    })

    if addon._sexyMapInstalled then
        C:AddDescription(visibility, LO["Has no effect while SexyMap controls the minimap (SexyMap or Hybrid mode)."])
    end

    -- ====================================================================
    -- SEXYMAP COMPATIBILITY  (only when SexyMap is installed)
    -- ====================================================================
    if addon._sexyMapInstalled then
        local sm = C:AddSection(scroll, L["SexyMap Compatibility"])

        C:AddDescription(sm,
            L["Choose how DragonUI and SexyMap share the minimap."])

        C:AddDropdown(sm, {
            label = L["Minimap Mode"],
            values = {
                ["sexymap"]  = L["SexyMap"],
                ["dragonui"] = L["DragonUI"],
                ["hybrid"]   = L["Hybrid"],
            },
            width = 220,
            getFunc = function()
                local cfg = addon.db and addon.db.profile and addon.db.profile.modules
                    and addon.db.profile.modules.minimap
                return cfg and cfg.sexymap_mode or "dragonui"
            end,
            setFunc = function(val)
                if addon.db and addon.db.profile and addon.db.profile.modules
                    and addon.db.profile.modules.minimap then
                    addon.db.profile.modules.minimap.sexymap_mode = val
                end
                -- Enable/Disable the SexyMap addon at the WoW level so it
                -- actually loads (or doesn't) after the UI reload
                if val == "dragonui" then
                    DisableAddOn("SexyMap")
                else
                    EnableAddOn("SexyMap")
                end
                StaticPopup_Show("DRAGONUI_SEXYMAP_MODE_RELOAD")
            end,
        })

        C:AddDescription(sm,
            "|cFF888888" .. L["SexyMap"] .. ":|r " .. L["Uses SexyMap for the minimap."] .. "\n" ..
            "|cFF888888" .. L["DragonUI"] .. ":|r " .. L["Uses DragonUI for the minimap."] .. "\n" ..
            "|cFF888888" .. L["Hybrid"] .. ":|r " .. L["SexyMap visuals with DragonUI editor and positioning."])
    end
end

-- Register the tab
Panel:RegisterTab("minimap", LO["Minimap"], BuildMinimapTab, 8)


