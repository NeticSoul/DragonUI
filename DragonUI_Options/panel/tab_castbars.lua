--[[
================================================================================
DragonUI Options Panel - Castbars Tab
================================================================================
Player, target, and focus castbar options with sub-tab navigation.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- SHARED VALUES
-- ============================================================================

local textModeValues = {
    simple   = LO["Simple (Name Only)"],
    detailed = LO["Detailed (Name + Time)"],
}

-- ============================================================================
-- ACTIVE SUB-TAB STATE
-- ============================================================================

local activeSubTab = "player"

local subTabs = {
    { key = "player", label = LO["Player"] },
    { key = "target", label = LO["Target"] },
    { key = "focus",  label = LO["Focus"] },
}

-- Search navigation sub-tab setter.
Panel.subTabSetters = Panel.subTabSetters or {}
Panel.subTabSetters["castbars"] = function(key) activeSubTab = key end

-- ============================================================================
-- COMMON CONTROLS BUILDER
-- ============================================================================

local function AddCastbarControls(parent, dbPrefix, refreshFunc, opts)
    opts = opts or {}

    local sizeXMin = opts.sizeXMin or 80
    local sizeXMax = opts.sizeXMax or 512
    local sizeYMin = opts.sizeYMin or 10
    local sizeYMax = opts.sizeYMax or 64

    C:AddSlider(parent, {
        label = LO["Width"],
        dbPath = dbPrefix .. ".sizeX",
        min = sizeXMin, max = sizeXMax, step = 1,
        width = 200,
        callback = refreshFunc,
    })

    C:AddSlider(parent, {
        label = LO["Height"],
        dbPath = dbPrefix .. ".sizeY",
        min = sizeYMin, max = sizeYMax, step = 1,
        width = 200,
        callback = refreshFunc,
    })

    C:AddSlider(parent, {
        label = LO["Scale"],
        dbPath = dbPrefix .. ".scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshFunc,
    })

    local iconDependents = {}
    local function IsIconHidden()
        return not C:GetDBValue(dbPrefix .. ".showIcon")
    end
    -- Sibling disabled states are evaluated once at build, so toggling Show Icon has to push them.
    local function RefreshIconControlStates()
        local hidden = IsIconHidden()
        for i = 1, #iconDependents do
            local widget = iconDependents[i]
            if widget and widget.SetDisabled then
                widget:SetDisabled(hidden)
            end
        end
    end

    C:AddToggle(parent, {
        label = LO["Show Icon"],
        dbPath = dbPrefix .. ".showIcon",
        callback = function()
            RefreshIconControlStates()
            refreshFunc()
        end,
    })

    iconDependents[#iconDependents + 1] = C:AddSlider(parent, {
        label = LO["Icon Size"],
        dbPath = dbPrefix .. ".sizeIcon",
        min = 1, max = 64, step = 1,
        width = 200,
        disabled = IsIconHidden,
        callback = refreshFunc,
    })

    iconDependents[#iconDependents + 1] = C:AddToggle(parent, {
        label = LO["Modern Icon Border"],
        desc = LO["Modern Icon Border Desc"],
        dbPath = dbPrefix .. ".modernIconBorder",
        disabled = IsIconHidden,
        callback = refreshFunc,
    })

    C:AddDropdown(parent, {
        label = LO["Text Mode"],
        dbPath = dbPrefix .. ".text_mode",
        values = textModeValues,
        callback = function()
            refreshFunc()
            StaticPopup_Show("DRAGONUI_RELOAD_UI")
        end,
    })

    C:AddSlider(parent, {
        label = LO["Time Precision"],
        desc = LO["Decimal places for remaining time."],
        dbPath = dbPrefix .. ".precision_time",
        min = 0, max = 3, step = 1,
        width = 180,
        disabled = function()
            return C:GetDBValue(dbPrefix .. ".text_mode") == "simple"
        end,
    })

    C:AddSlider(parent, {
        label = LO["Max Time Precision"],
        desc = LO["Decimal places for total time."],
        dbPath = dbPrefix .. ".precision_max",
        min = 0, max = 3, step = 1,
        width = 180,
        disabled = function()
            return C:GetDBValue(dbPrefix .. ".text_mode") == "simple"
        end,
    })

    C:AddSlider(parent, {
        label = LO["Hold Time (Success)"],
        desc = LO["How long the bar stays after a successful cast."],
        dbPath = dbPrefix .. ".holdTime",
        min = 0, max = 2, step = 0.1,
        width = 200,
        callback = refreshFunc,
    })

    C:AddSlider(parent, {
        label = LO["Hold Time (Interrupt)"],
        desc = LO["How long the bar stays after being interrupted."],
        dbPath = dbPrefix .. ".holdTimeInterrupt",
        min = 0, max = 2, step = 0.1,
        width = 200,
        callback = refreshFunc,
    })

    if opts.resetFunc then
        C:AddButton(parent, {
            label = LO["Reset Position"],
            width = 160,
            callback = opts.resetFunc,
        })
    end
end

-- ============================================================================
-- SUB-TAB BUILDERS
-- ============================================================================

local function BuildPlayerCastbar(scroll)
    local refresh = function()
        if addon.RefreshCastbar then addon.RefreshCastbar() end
    end

    local s = C:AddSection(scroll, LO["Player Castbar"])
    AddCastbarControls(s, "castbar", refresh, {
        sizeXMin = 80, sizeXMax = 512,
        sizeYMin = 10, sizeYMax = 64,
        resetFunc = function()
            if addon.ResetCastbarPosition then
                addon.ResetCastbarPosition()
            end
            print("|cFF00FF00[DragonUI]|r " .. LO["Player castbar position reset."])
        end,
    })

    -- ================================================================
    -- LATENCY INDICATOR SECTION
    -- ================================================================
    local lat = C:AddSection(scroll, LO["Latency Indicator"])

    C:AddToggle(lat, {
        label = LO["Enable Latency Indicator"],
        desc  = LO["Show a safe-zone overlay based on real cast latency."],
        dbPath = "castbar.latency.enabled",
        callback = function()
            refresh()
            Panel:SelectTab("castbars")
        end,
    })

    C:AddColorPicker(lat, {
        label = LO["Latency Color"],
        dbPath = "castbar.latency.color",
        hasAlpha = false,
        disabled = function()
            return not C:GetDBValue("castbar.latency.enabled")
        end,
        callback = refresh,
    })

    C:AddSlider(lat, {
        label = LO["Latency Alpha"],
        desc  = LO["Opacity of the latency indicator."],
        dbPath = "castbar.latency.alpha",
        min = 0.1, max = 1.0, step = 0.05,
        width = 200,
        disabled = function()
            return not C:GetDBValue("castbar.latency.enabled")
        end,
        callback = refresh,
    })
end

local function BuildTargetCastbar(scroll)
    local refresh = function()
        if addon.RefreshTargetCastbar then addon.RefreshTargetCastbar() end
    end

    local s = C:AddSection(scroll, LO["Target Castbar"])

    local isDetached = C:GetDBValue("castbar.target.override")
    if isDetached then
        C:AddDescription(s, "|cff1784d1- " .. LO["Castbar detached - positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(s, "|cffaaaaaa- " .. LO["Castbar attached - follows Target frame"] .. "|r")
    end

    C:AddButton(s, {
        label = LO["Re-attach Castbar to Target"],
        width = 220,
        disabled = function()
            return not C:GetDBValue("castbar.target.override")
        end,
        callback = function()
            if addon.ResetTargetCastbarPosition then
                addon.ResetTargetCastbarPosition()
            end
            Panel:SelectTab("castbars")
        end,
    })

    AddCastbarControls(s, "castbar.target", refresh, {
        sizeXMin = 50, sizeXMax = 400,
        sizeYMin = 5, sizeYMax = 50,
    })
end

local function BuildFocusCastbar(scroll)
    local refresh = function()
        if addon.RefreshFocusCastbar then addon.RefreshFocusCastbar() end
    end

    local s = C:AddSection(scroll, LO["Focus Castbar"])

    local isDetached = C:GetDBValue("castbar.focus.override")
    if isDetached then
        C:AddDescription(s, "|cff1784d1- " .. LO["Castbar detached - positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(s, "|cffaaaaaa- " .. LO["Castbar attached - follows Focus frame"] .. "|r")
    end

    C:AddButton(s, {
        label = LO["Re-attach Castbar to Focus"],
        width = 220,
        disabled = function()
            return not C:GetDBValue("castbar.focus.override")
        end,
        callback = function()
            if addon.ResetFocusCastbarPosition then
                addon.ResetFocusCastbarPosition()
            end
            Panel:SelectTab("castbars")
        end,
    })

    AddCastbarControls(s, "castbar.focus", refresh, {
        sizeXMin = 50, sizeXMax = 400,
        sizeYMin = 5, sizeYMax = 50,
    })
end

-- ============================================================================
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    player = BuildPlayerCastbar,
    target = BuildTargetCastbar,
    focus  = BuildFocusCastbar,
}

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local function BuildCastbarsTab(scroll)
    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("castbars")
    end, subTabBuilders)

    if not Panel.indexing then
        local builder = subTabBuilders[activeSubTab]
        if builder then builder(scroll) end
    end
end

-- Register the tab
Panel:RegisterTab("castbars", LO["Cast Bars"], BuildCastbarsTab, 7)
