--[[
================================================================================
DragonUI Options Panel - Auras Tab
================================================================================
Weapon enchant separation options.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local floor = math.floor
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

local function RefreshTargetFocusAuraTimers()
    if addon.RefreshAuraCooldownTextSystem then
        addon.RefreshAuraCooldownTextSystem()
    end
end

local function RefreshPlayerAuraSpacing()
    if addon.BuffFrameModule and addon.BuffFrameModule.RefreshAuraSpacing then
        addon.BuffFrameModule:RefreshAuraSpacing()
        return
    end

    if BuffFrame_UpdateAllBuffAnchors then
        BuffFrame_UpdateAllBuffAnchors()
    end
    if addon.BuffFrameModule then
        addon.BuffFrameModule:UpdatePosition()
    end
end

local AURA_ANCHORS = {
    TOP = LO["Top"],
    BOTTOM = LO["Bottom"],
    LEFT = LO["Left"],
    RIGHT = LO["Right"],
    CENTER = LO["Center"],
    TOPLEFT = LO["Top Left"],
    TOPRIGHT = LO["Top Right"],
    BOTTOMLEFT = LO["Bottom Left"],
    BOTTOMRIGHT = LO["Bottom Right"],
}

local AURA_FONTS = {
    actionbar = LO["Actionbar Font"],
    primary = LO["Primary Font"],
    narrow = LO["Narrow Font"],
    arial = LO["Arial Font"],
    system = LO["System Font"],
}

local function GetAuraCooldownConfig()
    local modules = addon.db and addon.db.profile and addon.db.profile.modules
    modules = modules or {}
    modules.auracooldowns = modules.auracooldowns or {}
    modules.auracooldowns.target = modules.auracooldowns.target or {}
    modules.auracooldowns.focus = modules.auracooldowns.focus or {}
    modules.auracooldowns.buffs = modules.auracooldowns.buffs or {}
    modules.auracooldowns.debuffs = modules.auracooldowns.debuffs or {}

    if modules.auracooldowns.target.max_duration_minutes == nil and type(modules.auracooldowns.target.max_duration) == "number" then
        modules.auracooldowns.target.max_duration_minutes = floor((modules.auracooldowns.target.max_duration / 60) + 0.5)
    end
    if modules.auracooldowns.focus.max_duration_minutes == nil and type(modules.auracooldowns.focus.max_duration) == "number" then
        modules.auracooldowns.focus.max_duration_minutes = floor((modules.auracooldowns.focus.max_duration / 60) + 0.5)
    end

    if modules.auracooldowns.target.enabled == nil then
        local timerUnits = modules.auracooldowns.timer_units
        modules.auracooldowns.target.enabled = modules.auracooldowns.timers_enabled == true and (timerUnits == "target" or timerUnits == "both") or false
    end
    if modules.auracooldowns.focus.enabled == nil then
        local timerUnits = modules.auracooldowns.timer_units
        modules.auracooldowns.focus.enabled = modules.auracooldowns.timers_enabled == true and (timerUnits == "focus" or timerUnits == "both") or false
    end

    modules.auracooldowns.timers_enabled = modules.auracooldowns.target.enabled == true or modules.auracooldowns.focus.enabled == true
    modules.auracooldowns.enabled = modules.auracooldowns.icons_enabled == true or modules.auracooldowns.timers_enabled == true

    return modules.auracooldowns
end

local function IsTimerCustomizationEnabled()
    return GetAuraCooldownConfig().timers_enabled == true
end

local function IsIconCustomizationEnabled()
    return GetAuraCooldownConfig().icons_enabled == true
end

local function SyncAuraModuleEnabled(cfg)
    cfg.enabled = cfg.icons_enabled == true or cfg.timers_enabled == true
end

local function SetAuraFeatureEnabled(featureKey, value)
    local cfg = GetAuraCooldownConfig()
    cfg[featureKey] = value and true or false
    SyncAuraModuleEnabled(cfg)
end

local function SyncAuraTimerState(cfg)
    cfg.timers_enabled = cfg.target.enabled == true or cfg.focus.enabled == true
    SyncAuraModuleEnabled(cfg)
end

local function SetAuraUnitEnabled(unitKey, value)
    local cfg = GetAuraCooldownConfig()
    cfg[unitKey].enabled = value and true or false
    SyncAuraTimerState(cfg)
end

local function IsTargetTimerSettingsDisabled()
    return not IsTimerCustomizationEnabled() or GetAuraCooldownConfig().target.enabled ~= true
end

local function IsFocusTimerSettingsDisabled()
    return not IsTimerCustomizationEnabled() or GetAuraCooldownConfig().focus.enabled ~= true
end

local function GetAuraCooldownDefaults()
    local defaults = addon.defaults
        and addon.defaults.profile
        and addon.defaults.profile.modules
        and addon.defaults.profile.modules.auracooldowns
    return defaults
end

local function ResetAuraTimerSettings()
    local defaults = GetAuraCooldownDefaults()
    if not defaults then return end

    local cfg = GetAuraCooldownConfig()

    cfg.duration_anchor = defaults.duration_anchor
    cfg.duration_offset_x = defaults.duration_offset_x
    cfg.duration_offset_y = defaults.duration_offset_y
    cfg.duration_font = defaults.duration_font

    cfg.target.enabled = defaults.target and defaults.target.enabled == true or false
    cfg.target.min_duration = defaults.target and defaults.target.min_duration or 0
    cfg.target.max_duration_minutes = defaults.target and defaults.target.max_duration_minutes or 0
    cfg.target.font_size = defaults.target and defaults.target.font_size or 11

    cfg.focus.enabled = defaults.focus and defaults.focus.enabled == true or false
    cfg.focus.min_duration = defaults.focus and defaults.focus.min_duration or 0
    cfg.focus.max_duration_minutes = defaults.focus and defaults.focus.max_duration_minutes or 0
    cfg.focus.font_size = defaults.focus and defaults.focus.font_size or 11

    SyncAuraTimerState(cfg)
end

local function ResetAuraIconSettings()
    local defaults = GetAuraCooldownDefaults()
    if not defaults then return end

    local cfg = GetAuraCooldownConfig()

    cfg.icons_enabled = defaults.icons_enabled == true
    cfg.stack_anchor = defaults.stack_anchor
    cfg.stack_offset_x = defaults.stack_offset_x
    cfg.stack_offset_y = defaults.stack_offset_y
    cfg.count_font = defaults.count_font
    cfg.buffs = addon.DeepCopy(defaults.buffs or {}, {})
    cfg.debuffs = addon.DeepCopy(defaults.debuffs or {}, {})

    SyncAuraModuleEnabled(cfg)
end

-- ============================================================================
-- AURAS TAB BUILDER
-- ============================================================================

local function BuildAurasTab(scroll)
    -- ====================================================================
    -- WEAPON ENCHANTS
    -- ====================================================================
    local weaponSection = C:AddSection(scroll, LO["Weapon Enchants"])

    C:AddDescription(weaponSection,
        LO["Weapon enchant icons include rogue poisons, sharpening stones, wizard oils, and similar temporary weapon enhancements."])

    C:AddToggle(weaponSection, {
        label = LO["Separate Weapon Enchants"],
        desc = LO["Detach weapon enchant icons (poisons, sharpening stones, etc.) from the buff bar into their own independently moveable frame. Position it freely using Editor Mode."],
        getFunc = function()
            return addon.db.profile.buffs and addon.db.profile.buffs.separate_weapon_enchants
        end,
        setFunc = function(val)
            if not addon.db.profile.buffs then addon.db.profile.buffs = {} end
            addon.db.profile.buffs.separate_weapon_enchants = val
        end,
        callback = function(val)
            if addon.BuffFrameModule then
                addon.BuffFrameModule:ToggleWeaponEnchantSeparation(val)
            end
        end,
        requiresReload = false,
    })

    C:AddDescription(weaponSection,
        "|cff888888" .. LO["When enabled, a 'Weapon Enchants' mover appears in Editor Mode that you can drag to any position on screen."] .. "|r")

    C:AddSpacer(scroll)
    local playerAuraSpacingSection = C:AddSection(scroll, LO["Player Aura Spacing"])

    C:AddSlider(playerAuraSpacingSection, {
        label = LO["Buff Horizontal Gap"],
        dbPath = "buffs.buff_horizontal_gap",
        min = 0, max = 20, step = 1,
        width = 220,
        callback = RefreshPlayerAuraSpacing,
    })

    C:AddSlider(playerAuraSpacingSection, {
        label = LO["Debuff Horizontal Gap"],
        dbPath = "buffs.debuff_horizontal_gap",
        min = 0, max = 20, step = 1,
        width = 220,
        callback = RefreshPlayerAuraSpacing,
    })

    -- ====================================================================
    -- TARGET/FOCUS AURA CUSTOMIZATION
    -- ====================================================================
    C:AddSpacer(scroll)
    local timerSection = C:AddSection(scroll, LO["Aura Timers"])
    local iconSection
    local dynamicWidgets = {}
    local isRefreshingAuraWidgets = false

    local function RegisterDynamicWidget(widget, disabledFunc, valueFunc)
        table.insert(dynamicWidgets, { widget = widget, disabledFunc = disabledFunc, valueFunc = valueFunc })
        return widget
    end

    local function RefreshAuraControlStates()
        isRefreshingAuraWidgets = true
        for _, entry in ipairs(dynamicWidgets) do
            if entry.widget and entry.widget.SetValue and entry.valueFunc then
                entry.widget:SetValue(entry.valueFunc())
            end
            if entry.widget and entry.widget.SetDisabled and entry.disabledFunc then
                entry.widget:SetDisabled(entry.disabledFunc())
            end
        end
        isRefreshingAuraWidgets = false
    end

    local function RefreshAuraUI()
        RefreshAuraControlStates()
        RefreshTargetFocusAuraTimers()
    end

    C:AddDescription(timerSection, LO["Show aura timers on Target and Focus independently."])

    RegisterDynamicWidget(C:AddToggle(timerSection, {
        label = LO["Enable Target Aura Timers"],
        getFunc = function()
            return GetAuraCooldownConfig().target.enabled == true
        end,
        setFunc = function(val)
            SetAuraUnitEnabled("target", val)
        end,
        callback = function()
            if isRefreshingAuraWidgets then return end
            RefreshAuraUI()
        end,
        requiresReload = false,
    }), nil, function()
        return GetAuraCooldownConfig().target.enabled == true
    end)

    RegisterDynamicWidget(C:AddToggle(timerSection, {
        label = LO["Enable Focus Aura Timers"],
        getFunc = function()
            return GetAuraCooldownConfig().focus.enabled == true
        end,
        setFunc = function(val)
            SetAuraUnitEnabled("focus", val)
        end,
        callback = function()
            if isRefreshingAuraWidgets then return end
            RefreshAuraUI()
        end,
        requiresReload = false,
    }), nil, function()
        return GetAuraCooldownConfig().focus.enabled == true
    end)

    C:AddHeading(timerSection, LO["Timer Text Settings"])

    RegisterDynamicWidget(C:AddDropdown(timerSection, {
        label = LO["Duration Text Anchor"],
        dbPath = "modules.auracooldowns.duration_anchor",
        values = AURA_ANCHORS,
        width = 220,
        disabled = function()
            return not IsTimerCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsTimerCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().duration_anchor
    end)

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Duration X Offset"],
        dbPath = "modules.auracooldowns.duration_offset_x",
        min = -50, max = 50, step = 1,
        width = 220,
        disabled = function()
            return not IsTimerCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsTimerCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().duration_offset_x
    end)

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Duration Y Offset"],
        dbPath = "modules.auracooldowns.duration_offset_y",
        min = -50, max = 50, step = 1,
        width = 220,
        disabled = function()
            return not IsTimerCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsTimerCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().duration_offset_y
    end)

    RegisterDynamicWidget(C:AddDropdown(timerSection, {
        label = LO["Duration Font"],
        dbPath = "modules.auracooldowns.duration_font",
        values = AURA_FONTS,
        width = 220,
        disabled = function()
            return not IsTimerCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsTimerCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().duration_font
    end)

    C:AddHeading(timerSection, LO["Target Aura Timer Settings"])

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Target Aura Timer Size"],
        dbPath = "modules.auracooldowns.target.font_size",
        min = 6, max = 30, step = 1,
        width = 220,
        disabled = IsTargetTimerSettingsDisabled,
        callback = RefreshTargetFocusAuraTimers,
    }), IsTargetTimerSettingsDisabled, function()
        return GetAuraCooldownConfig().target.font_size
    end)

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Target Aura Minimum Duration (Seconds)"],
        desc = LO["Only show aura timers when remaining duration is above this value (seconds)."],
        dbPath = "modules.auracooldowns.target.min_duration",
        min = 0, max = 60, step = 1,
        width = 220,
        disabled = IsTargetTimerSettingsDisabled,
        callback = RefreshTargetFocusAuraTimers,
    }), IsTargetTimerSettingsDisabled, function()
        return GetAuraCooldownConfig().target.min_duration
    end)

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Target Aura Maximum Duration (Minutes)"],
        desc = LO["Only show aura timers when remaining duration is below this value (minutes). Use 0 to disable this limit."],
        dbPath = "modules.auracooldowns.target.max_duration_minutes",
        min = 0, max = 180, step = 1,
        width = 220,
        disabled = IsTargetTimerSettingsDisabled,
        callback = RefreshTargetFocusAuraTimers,
    }), IsTargetTimerSettingsDisabled, function()
        return GetAuraCooldownConfig().target.max_duration_minutes
    end)

    C:AddHeading(timerSection, LO["Focus Aura Timer Settings"])

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Focus Aura Timer Size"],
        dbPath = "modules.auracooldowns.focus.font_size",
        min = 6, max = 30, step = 1,
        width = 220,
        disabled = IsFocusTimerSettingsDisabled,
        callback = RefreshTargetFocusAuraTimers,
    }), IsFocusTimerSettingsDisabled, function()
        return GetAuraCooldownConfig().focus.font_size
    end)

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Focus Aura Minimum Duration (Seconds)"],
        desc = LO["Only show aura timers when remaining duration is above this value (seconds)."],
        dbPath = "modules.auracooldowns.focus.min_duration",
        min = 0, max = 60, step = 1,
        width = 220,
        disabled = IsFocusTimerSettingsDisabled,
        callback = RefreshTargetFocusAuraTimers,
    }), IsFocusTimerSettingsDisabled, function()
        return GetAuraCooldownConfig().focus.min_duration
    end)

    RegisterDynamicWidget(C:AddSlider(timerSection, {
        label = LO["Focus Aura Maximum Duration (Minutes)"],
        desc = LO["Only show aura timers when remaining duration is below this value (minutes). Use 0 to disable this limit."],
        dbPath = "modules.auracooldowns.focus.max_duration_minutes",
        min = 0, max = 180, step = 1,
        width = 220,
        disabled = IsFocusTimerSettingsDisabled,
        callback = RefreshTargetFocusAuraTimers,
    }), IsFocusTimerSettingsDisabled, function()
        return GetAuraCooldownConfig().focus.max_duration_minutes
    end)

    C:AddSpacer(timerSection)

    C:AddButton(timerSection, {
        label = LO["Reset Aura Timers"],
        width = 220,
        callback = function()
            ResetAuraTimerSettings()
            RefreshAuraUI()
            print("|cFF00FF00[DragonUI]|r " .. LO["Aura timer settings reset."])
        end,
    })

    C:AddSpacer(scroll)
    iconSection = C:AddSection(scroll, LO["Aura Icon Customization"])

    C:AddDescription(iconSection, LO["Customize icon size, scale, and stack text for target/focus auras."])

    RegisterDynamicWidget(C:AddToggle(iconSection, {
        label = LO["Customize Aura Icons"],
        desc = LO["Enable custom icon styling for target/focus aura icons."],
        getFunc = IsIconCustomizationEnabled,
        setFunc = function(val)
            SetAuraFeatureEnabled("icons_enabled", val)
        end,
        callback = function()
            if isRefreshingAuraWidgets then return end
            RefreshAuraUI()
        end,
        requiresReload = false,
    }), nil, function()
        return IsIconCustomizationEnabled()
    end)

    C:AddHeading(iconSection, LO["Stack Text Settings"])

    RegisterDynamicWidget(C:AddDropdown(iconSection, {
        label = LO["Stack Text Anchor"],
        dbPath = "modules.auracooldowns.stack_anchor",
        values = AURA_ANCHORS,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().stack_anchor
    end)

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Stack X Offset"],
        dbPath = "modules.auracooldowns.stack_offset_x",
        min = -50, max = 50, step = 1,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().stack_offset_x
    end)

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Stack Y Offset"],
        dbPath = "modules.auracooldowns.stack_offset_y",
        min = -50, max = 50, step = 1,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().stack_offset_y
    end)

    RegisterDynamicWidget(C:AddDropdown(iconSection, {
        label = LO["Stack Font"],
        dbPath = "modules.auracooldowns.count_font",
        values = AURA_FONTS,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().count_font
    end)

    C:AddHeading(iconSection, LO["Aura Buffs"])

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Buff Icon Size"],
        dbPath = "modules.auracooldowns.buffs.icon_size",
        min = 0, max = 64, step = 1,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().buffs.icon_size
    end)

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Buff Icon Scale"],
        dbPath = "modules.auracooldowns.buffs.icon_scale",
        min = 0.5, max = 3, step = 0.01,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().buffs.icon_scale
    end)

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Buff Stack Font Size"],
        dbPath = "modules.auracooldowns.buffs.stack_font_size",
        min = 0, max = 30, step = 1,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().buffs.stack_font_size
    end)

    C:AddHeading(iconSection, LO["Aura Debuffs"])

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Debuff Icon Size"],
        dbPath = "modules.auracooldowns.debuffs.icon_size",
        min = 0, max = 64, step = 1,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().debuffs.icon_size
    end)

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Debuff Icon Scale"],
        dbPath = "modules.auracooldowns.debuffs.icon_scale",
        min = 0.5, max = 3, step = 0.01,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().debuffs.icon_scale
    end)

    RegisterDynamicWidget(C:AddSlider(iconSection, {
        label = LO["Debuff Stack Font Size"],
        dbPath = "modules.auracooldowns.debuffs.stack_font_size",
        min = 0, max = 30, step = 1,
        width = 220,
        disabled = function()
            return not IsIconCustomizationEnabled()
        end,
        callback = RefreshTargetFocusAuraTimers,
    }), function()
        return not IsIconCustomizationEnabled()
    end, function()
        return GetAuraCooldownConfig().debuffs.stack_font_size
    end)

    C:AddSpacer(iconSection)

    C:AddButton(iconSection, {
        label = LO["Reset Aura Customization"],
        width = 220,
        callback = function()
            ResetAuraIconSettings()
            RefreshAuraUI()
            print("|cFF00FF00[DragonUI]|r " .. LO["Aura icon customization settings reset."])
        end,
    })

    RefreshAuraControlStates()

    -- ====================================================================
    -- RESET POSITION
    -- ====================================================================
    C:AddSpacer(scroll)
    local resetSection = C:AddSection(scroll, LO["Positions"])

    C:AddButton(resetSection, {
        label = LO["Reset Buff Frame Position"],
        width = 220,
        callback = function()
            if addon.BuffFrameModule then
                addon.BuffFrameModule:ResetBuffFramePosition()
            end
            print("|cFF00FF00[DragonUI]|r " .. LO["Buff frame position reset."])
        end,
    })

    C:AddButton(resetSection, {
        label = LO["Reset Weapon Enchant Position"],
        width = 220,
        callback = function()
            if addon.db.profile.widgets and addon.db.profile.widgets.weapon_enchants then
                local w = addon.db.profile.widgets.weapon_enchants
                w.anchor = "TOPRIGHT"
                w.posX = -100
                w.posY = -15
                w.custom_position = false
            end
            if addon.BuffFrameModule then
                addon.BuffFrameModule:UpdateWeaponEnchantPosition()
            end
            print("|cFF00FF00[DragonUI]|r " .. LO["Weapon enchant position reset."])
        end,
    })

    C:AddSpacer(resetSection)

    local isDebuffDetached = C:GetDBValue("widgets.debuffs.custom_position")
    if isDebuffDetached then
        C:AddDescription(resetSection, "|cff1784d1- " .. LO["Debuffs detached - positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(resetSection, "|cffaaaaaa- " .. LO["Debuffs attached - follow buff row"] .. "|r")
    end

    C:AddButton(resetSection, {
        label = LO["Reset Debuff Position"],
        width = 220,
        disabled = function()
            return not C:GetDBValue("widgets.debuffs.custom_position")
        end,
        callback = function()
            if addon.BuffFrameModule then
                addon.BuffFrameModule:ResetDebuffPosition()
            end
            print("|cFF00FF00[DragonUI]|r " .. LO["Debuff position reset."])
            Panel:SelectTab("auras")
        end,
    })
end

-- Register the tab (order 12 — after Enhancements, before Profiles)
Panel:RegisterTab("auras", LO["Auras"], BuildAurasTab, 12)
