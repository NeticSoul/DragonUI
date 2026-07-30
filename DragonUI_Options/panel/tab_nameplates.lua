--[[
================================================================================
DragonUI Options Panel - Nameplates Tab
================================================================================
Nameplate styling split into sub-tabs for easier navigation.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

local DB = "modules.nameplates"
local AceGUI = LibStub("AceGUI-3.0")

-- Blizzard nameplate visibility CVars (Interface → Names → Unit Nameplates).
local function CVarBool(cvar)
    if not GetCVar then
        return false
    end
    local ok, val = pcall(GetCVar, cvar)
    return ok and val == "1"
end

local function SetCVarBool(cvar, on)
    if SetCVar then
        SetCVar(cvar, on and "1" or "0")
    end
end

-- Prefer the client's localized global; fall back to DragonUI LO.
local function ClientStr(globalName, loKey)
    local s = _G[globalName]
    if type(s) == "string" and s ~= "" then
        return s
    end
    return LO[loKey]
end

local function AddNameplateCVarToggle(parent, opts)
    return C:AddToggle(parent, {
        label = ClientStr(opts.labelGlobal, opts.labelKey),
        disabled = opts.disabled,
        getFunc = function()
            return CVarBool(opts.cvar)
        end,
        setFunc = function(val)
            SetCVarBool(opts.cvar, val)
            if opts.onChanged then
                opts.onChanged(val)
            end
        end,
    })
end

local function AddNameplateCVarColumn(parent, titleKey, masterCvar, subCvars, refreshSubDisabled)
    local col = AceGUI:Create("SimpleGroup")
    col:SetLayout("List")
    col:SetWidth(290)
    parent:AddChild(col)

    AddNameplateCVarToggle(col, {
        cvar = masterCvar,
        labelGlobal = masterCvar == "nameplateShowFriends"
            and "UNIT_NAMEPLATES_SHOW_FRIENDS" or "UNIT_NAMEPLATES_SHOW_ENEMIES",
        labelKey = titleKey,
        onChanged = refreshSubDisabled,
    })

    for _, sub in ipairs(subCvars) do
        local w = AddNameplateCVarToggle(col, {
            cvar = sub.cvar,
            labelGlobal = sub.labelGlobal,
            labelKey = sub.labelKey,
            disabled = function()
                return not CVarBool(masterCvar)
            end,
        })
        sub._widget = w
    end
    refreshSubDisabled()
    return col
end

-- ============================================================================
-- REFRESH
-- ============================================================================

local function RefreshNameplates()
    if not addon.db or not addon.db.profile then
        return
    end
    local cfg = addon.db.profile.modules and addon.db.profile.modules.nameplates
    if cfg and cfg.enabled == false then
        return
    end
    if addon.RefreshNameplates then
        addon:RefreshNameplates()
    elseif addon.ApplyNameplatesSystem then
        addon:ApplyNameplatesSystem()
    end
end

local function RefreshAndRebuildNameplates()
    RefreshNameplates()
    if Panel and Panel.SelectTab then
        Panel:SelectTab("nameplates")
    end
end

-- Force the quest name/loot indexes to rebuild (provider or name-mode toggle changed).
local function RefreshQuestNameResolution()
    local np = addon.Nameplates
    if np and np.quest then
        if np.quest.ClearIndex then np.quest.ClearIndex() end
        if np.quest.OnQuestLogChanged then np.quest.OnQuestLogChanged() end
    end
    RefreshNameplates()
end

local function OnModuleToggle(val)
    if not addon.db.profile.modules then
        addon.db.profile.modules = {}
    end
    if not addon.db.profile.modules.nameplates then
        addon.db.profile.modules.nameplates = {}
    end
    addon.db.profile.modules.nameplates.enabled = val
    if val then
        RefreshNameplates()
    end
end

local function IsBattleGroundHealersLoaded()
    return IsAddOnLoaded and IsAddOnLoaded("BattleGroundHealers") or false
end

local bghTestMarkedNames = {}

local function GetBGHTestLayout()
    local np = addon.Nameplates
    return np and np.layout
end

local function ClearBGHTestMarks()
    local layout = GetBGHTestLayout()
    if layout and layout.ClearBGHTestMarks then
        layout.ClearBGHTestMarks()
    end
    bghTestMarkedNames = {}
end

local function ToggleBGHTestMarkTarget()
    local layout = GetBGHTestLayout()
    if not (layout and layout.SetBGHTestMark) then
        return
    end
    local name = UnitName("target")
    if not name or name == "" then
        return
    end

    local index = nil
    for i = 1, #bghTestMarkedNames do
        if bghTestMarkedNames[i] == name then
            index = i
            break
        end
    end

    if index then
        layout.SetBGHTestMark(name, nil)
        table.remove(bghTestMarkedNames, index)
        return
    end

    layout.SetBGHTestMark(name, UnitCanAttack("player", "target") and "ENEMY" or "FRIEND")
    bghTestMarkedNames[#bghTestMarkedNames + 1] = name
end

local function DisableBGHTestMode()
    local np = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.nameplates
    if not np then
        return
    end
    if np.bghTestMode then
        np.bghTestMode = false
    end
    ClearBGHTestMarks()
end

local function EnsureOptionsPanelHideHook()
    if not Panel or not Panel.frame or Panel._bghTestHideHooked then
        return
    end
    Panel._bghTestHideHooked = true
    Panel.frame:HookScript("OnHide", function()
        DisableBGHTestMode()
    end)
end

-- ============================================================================
-- ACTIVE SUB-TAB STATE
-- ============================================================================

local activeSubTab = "general"

local subTabs = {
    { key = "general",  label = LO["General"] },
    { key = "layout",   label = LO["Layout"] },
    { key = "behavior", label = LO["Behavior"] },
    { key = "health",   label = LO["Health Bar"] },
    { key = "target",   label = LO["Target & Threat"] },
    { key = "bars",     label = LO["Bars"] },
    { key = "icons",    label = LO["Icons"] },
    { key = "quest",    label = LO["Quest"] },
    { key = "debuffs",  label = LO["Debuffs"] },
}

function addon.SetNameplateSubTab(key)
    activeSubTab = key or "general"
end

-- Search navigation sub-tab setter.
Panel.subTabSetters = Panel.subTabSetters or {}
Panel.subTabSetters["nameplates"] = function(key) activeSubTab = key or "general" end

-- ============================================================================
-- SUB-TAB BUILDERS
-- ============================================================================

local function BuildGeneralSubTab(scroll)
    C:AddSpacer(scroll)

    local general = C:AddSection(scroll, LO["General"])

    C:AddToggle(general, {
        label = LO["Enable Nameplates Module"],
        desc = LO["Apply DragonUI nameplate styling."],
        requiresReload = true,
        getFunc = function()
            local m = addon.db.profile.modules and addon.db.profile.modules.nameplates
            return m and m.enabled ~= false
        end,
        setFunc = OnModuleToggle,
    })

    C:AddToggle(general, {
        label = LO["Allow Nameplate Overlap"],
        desc = LO["Allow native nameplates to overlap. Retail-like Stacking enables this automatically because its custom stacking algorithm requires overlap."],
        getFunc = function()
            return GetCVar("nameplateAllowOverlap") == "1"
        end,
        setFunc = function(val)
            SetCVar("nameplateAllowOverlap", val and "1" or "0")
        end,
    })

    local unitPlates = C:AddSection(scroll, LO["Unit Nameplates"])
    local unitCols = C:AddRow(unitPlates, { layout = "Flow" })

    local friendlySubCvars = {
        {
            cvar = "nameplateShowFriendlyPets",
            labelGlobal = "UNIT_NAMEPLATES_SHOW_FRIENDLY_PETS",
            labelKey = "Pets",
        },
        {
            cvar = "nameplateShowFriendlyGuardians",
            labelGlobal = "UNIT_NAMEPLATES_SHOW_FRIENDLY_GUARDIANS",
            labelKey = "Guardians",
        },
        {
            cvar = "nameplateShowFriendlyTotems",
            labelGlobal = "UNIT_NAMEPLATES_SHOW_FRIENDLY_TOTEMS",
            labelKey = "Totems",
        },
    }
    local enemySubCvars = {
        {
            cvar = "nameplateShowEnemyPets",
            labelGlobal = "UNIT_NAMEPLATES_SHOW_ENEMY_PETS",
            labelKey = "Pets",
        },
        {
            cvar = "nameplateShowEnemyGuardians",
            labelGlobal = "UNIT_NAMEPLATES_SHOW_ENEMY_GUARDIANS",
            labelKey = "Guardians",
        },
        {
            cvar = "nameplateShowEnemyTotems",
            labelGlobal = "UNIT_NAMEPLATES_SHOW_ENEMY_TOTEMS",
            labelKey = "Totems",
        },
    }

    local function RefreshFriendlySubDisabled()
        local on = CVarBool("nameplateShowFriends")
        for _, sub in ipairs(friendlySubCvars) do
            if sub._widget then
                sub._widget:SetDisabled(not on)
            end
        end
    end
    local function RefreshEnemySubDisabled()
        local on = CVarBool("nameplateShowEnemies")
        for _, sub in ipairs(enemySubCvars) do
            if sub._widget then
                sub._widget:SetDisabled(not on)
            end
        end
    end

    AddNameplateCVarColumn(unitCols, "Friendly Units", "nameplateShowFriends",
        friendlySubCvars, RefreshFriendlySubDisabled)
    AddNameplateCVarColumn(unitCols, "Enemy Units", "nameplateShowEnemies",
        enemySubCvars, RefreshEnemySubDisabled)

    local opacity = C:AddSection(scroll, LO["Opacity"])

    C:AddToggle(opacity, {
        label = LO["Disable Non-Target Fade"],
        desc = LO["Keep all nameplates fully opaque when you have a target."],
        dbPath = DB .. ".disableNonTargetFade",
        callback = RefreshNameplates,
    })

    C:AddSlider(opacity, {
        label = LO["Background Plates Opacity"],
        desc = LO["Controls the opacity of non-target nameplates while fade is active (0.0 - 1.0)."],
        dbPath = DB .. ".opacityNonTarget",
        min = 0.0, max = 1.0, step = 0.01,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddToggle(opacity, {
        label = LO["No Target: Full Opacity"],
        desc = LO["When you have no target, show all nameplates at full opacity."],
        dbPath = DB .. ".opacityFullNoTarget",
        callback = RefreshNameplates,
    })

    C:AddToggle(opacity, {
        label = LO["Party/Raid: Full Opacity"],
        desc = LO["Always show party and raid member nameplates at full opacity, regardless of target or fade settings. Does not affect pets or NPCs."],
        dbPath = DB .. ".opacityFullParty",
        callback = RefreshNameplates,
    })

    local addonCompat = C:AddSection(scroll, LO["Addon Compatibility"])
    C:AddDescription(addonCompat, LO["Enable this if you use an external nameplate addon (PlateBuffs, Crosshairs, ...) that isn't detecting DragonUI's nameplates correctly."])
    C:AddToggle(addonCompat, {
        label = LO["Nameplate Addon Compatibility"],
        desc = LO["Stops overriding the nameplate's native transparency/visibility, which some external addons rely on to find their target. Non-target nameplates will dim like vanilla."],
        dbPath = DB .. ".nameplateAlphaCompat",
        requiresReload = true,
    })
    C:AddDescription(addonCompat, LO["Enable this if you use an addon (Icicle, ...) that attaches its own widgets to DragonUI's nameplate health bar."])
    C:AddToggle(addonCompat, {
        label = LO["Nameplate Health Bar Compatibility"],
        desc = LO["Hides the native health bar by fading its individual textures instead of the whole bar, for addons that attach widgets directly to it."],
        dbPath = DB .. ".nameplateBarAlphaCompat",
        requiresReload = true,
    })

end

local function BuildBehaviorSubTab(scroll)
    C:AddSpacer(scroll)

    local behavior = C:AddSection(scroll, LO["Behavior"])
    local function IsRetailStackingDisabled()
        local m = addon.db.profile.modules and addon.db.profile.modules.nameplates
        if not m then
            return true
        end
        return m.retailStackingEnabled ~= true
    end

    C:AddToggle(behavior, {
        label = LO["Depth Ordering"],
        desc = LO["Order overlapping nameplates by depth."]
            .. " " .. (LO["(Requires Allow Nameplate Overlap.)"] or ""),
        dbPath = DB .. ".depthSortingEnabled",
        callback = RefreshNameplates,
    })

    C:AddToggle(behavior, {
        label = LO["Retail-like Stacking"],
        desc = (LO["Simulates Retail's nameplate stacking for enemies."] or "")
            .. " "
            .. (LO["May increase CPU use with many visible nameplates."] or ""),
        dbPath = DB .. ".retailStackingEnabled",
        callback = function(val)
            RefreshNameplates()
            if Panel and Panel.SelectTab then
                Panel:SelectTab("nameplates")
            end
        end,
    })

    C:AddSlider(behavior, {
        label = LO["Collider Width"],
        desc = LO["Sets the width of the virtual collider centered on each nameplate used to detect overlaps."],
        dbPath = DB .. ".retailStackingXSpace",
        min = 20, max = 200, step = 1,
        width = 200,
        disabled = IsRetailStackingDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(behavior, {
        label = LO["Collider Height"],
        desc = LO["Sets the height of the virtual collider centered on each nameplate used to detect overlaps."],
        dbPath = DB .. ".retailStackingYSpace",
        min = 5, max = 50, step = 1,
        width = 200,
        disabled = IsRetailStackingDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(behavior, {
        label = LO["Vertical Offset"],
        desc = LO["Vertical offset baseline for Retail-like stacking."],
        dbPath = DB .. ".retailStackingOriginY",
        min = 0, max = 50, step = 1,
        width = 200,
        disabled = IsRetailStackingDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(behavior, {
        label = LO["Freeze Mouseover"],
        desc = LO["Keeps the hovered nameplate fixed while stacking updates around it."],
        dbPath = DB .. ".retailStackingFreezeMouseover",
        disabled = IsRetailStackingDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(behavior, {
        label = LO["Disable in Open World"],
        desc = LO["Only apply Retail-like stacking inside party and raid instances. It remains disabled in the open world, battlegrounds, and arenas."],
        dbPath = DB .. ".retailStackingInInstance",
        disabled = IsRetailStackingDisabled,
        callback = RefreshNameplates,
    })
end

local function BuildLayoutSubTab(scroll)
    C:AddSpacer(scroll)

    local sizePos = C:AddSection(scroll, LO["Size & Position"])

    C:AddSlider(sizePos, {
        label = LO["Bar Width"],
        dbPath = DB .. ".barWidth",
        min = 80, max = 240, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddSlider(sizePos, {
        label = LO["Bar Height"],
        dbPath = DB .. ".barHeight",
        min = 3, max = 20, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddSlider(sizePos, {
        label = LO["Bar Stack Gap"],
        desc = LO["Vertical spacing between health, power, and cast bars (pixels)."],
        dbPath = DB .. ".castBarGap",
        min = 0, max = 15, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddSlider(sizePos, {
        label = LO["Offset X"],
        dbPath = DB .. ".offsetX",
        min = -50, max = 50, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddSlider(sizePos, {
        label = LO["Offset Y"],
        dbPath = DB .. ".offsetY",
        min = -50, max = 50, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    local clampControls = {}
    local function SetClampControlsDisabled(disabled)
        for _, w in ipairs(clampControls) do
            if w and w.SetDisabled then
                w:SetDisabled(disabled)
            end
        end
    end
    local function UpdateClampControlStates()
        local cfg = addon.db.profile.modules and addon.db.profile.modules.nameplates
        local anyClamp = cfg and (cfg.clampTarget == true or cfg.clampBoss == true)
        SetClampControlsDisabled(not anyClamp)
    end

    C:AddToggle(sizePos, {
        label = LO["Clamp Target to Screen"],
        desc = LO["Keep the target nameplate visible at the top of the screen. Extends WorldFrame height when enabled."],
        dbPath = DB .. ".clampTarget",
        callback = function()
            RefreshNameplates()
            UpdateClampControlStates()
        end,
    })

    C:AddToggle(sizePos, {
        label = LO["Clamp Bosses to Screen"],
        desc = LO["Keep hostile boss and world-boss nameplates visible at the top of the screen wherever they appear."],
        dbPath = DB .. ".clampBoss",
        callback = function()
            RefreshNameplates()
            UpdateClampControlStates()
        end,
    })

    clampControls[#clampControls + 1] = C:AddSlider(sizePos, {
        label = LO["Clamp Top Inset"],
        desc = LO["Distance below the top edge where clamped nameplates stop."],
        dbPath = DB .. ".clampTopInset",
        min = 0, max = 200, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    UpdateClampControlStates()

    local clickboxSection = C:AddSection(scroll, LO["Clickbox"])

    local CLICKBOX_AUTO_SHOW_IDLE = 3
    local showClickboxToggle

    local function RefreshShowClickboxWidget(value)
        local panel = addon.OptionsPanel
        if not (panel and panel.IsOpen and panel:IsOpen()) then return end
        if showClickboxToggle and showClickboxToggle.SetValue then
            showClickboxToggle:SetValue(value and true or false)
        end
    end

    local function OnClickboxSliderChanged()
        RefreshNameplates()
        local NP = addon.Nameplates
        if not (NP and NP.clickbox and NP.module) then return end
        if not C:GetDBValue(DB .. ".showClickbox") then
            C:SetDBValue(DB .. ".showClickbox", true)
            -- Flags the Show as ours, so only an auto-enable is auto-disabled when the sliders go idle.
            NP.module._clickboxSliderAutoShow = true
            RefreshShowClickboxWidget(true)
        end
        NP.module._clickboxSliderIdleUntil = GetTime() + CLICKBOX_AUTO_SHOW_IDLE
        NP.clickbox.RefreshAllOverlays()
    end

    C:AddSlider(clickboxSection, {
        label = LO["Clickbox Width Factor"],
        desc = LO["Scales the nameplate clickbox relative to its original size. Changes made during combat are applied when combat ends."],
        dbPath = DB .. ".clickboxWidthFactor",
        min = 0.25, max = 1.5, step = 0.01,
        width = 200,
        callback = OnClickboxSliderChanged,
    })

    C:AddSlider(clickboxSection, {
        label = LO["Clickbox Height Factor"],
        desc = LO["Scales the nameplate clickbox relative to its original size. Changes made during combat are applied when combat ends."],
        dbPath = DB .. ".clickboxHeightFactor",
        min = 0.25, max = 2.5, step = 0.01,
        width = 200,
        callback = OnClickboxSliderChanged,
    })

    C:AddSlider(clickboxSection, {
        label = LO["Totem Click Padding"],
        desc = LO["Extra clickable padding on totem nameplates (easier to click)."],
        dbPath = DB .. ".totemClickPadding",
        min = 0, max = 24, step = 1,
        width = 200,
        callback = OnClickboxSliderChanged,
    })

    showClickboxToggle = C:AddToggle(clickboxSection, {
        label = LO["Show Clickbox"],
        desc = LO["Displays the box selection space (clickbox) of nameplates."],
        dbPath = DB .. ".showClickbox",
        callback = function()
            local NP = addon.Nameplates
            if NP and NP.clickbox and NP.module then
                -- Toggling by hand takes ownership of the setting; drop any pending auto-off.
                NP.module._clickboxSliderAutoShow = nil
                NP.module._clickboxSliderIdleUntil = nil
                NP.clickbox.RefreshAll()
                NP.clickbox.RefreshAllOverlays()
            end
        end,
    })

    if addon.Nameplates and addon.Nameplates.module then
        addon.Nameplates.module._clickboxToggleRefresh = RefreshShowClickboxWidget
    end
end

local function BuildHealthSubTab(scroll)
    C:AddSpacer(scroll)

    local health = C:AddSection(scroll, LO["Health Bar"])

    C:AddDropdown(health, {
        label = LO["Health Bar Background"],
        desc = LO["Choose the background texture used behind the health bar fill."],
        dbPath = DB .. ".healthBarBackground",
        values = {
            black = LO["Black"],
            castbar = LO["Same as Castbar"],
        },
        width = 200,
        callback = RefreshNameplates,
    })

    local levelToggles = {}
    local simpleNameControls = {}
    local function IsCenterNameMode()
        local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
        return np and np.centerNameOnly == true
    end
    local function SetLevelToggleDisabled(disabled)
        for _, w in ipairs(levelToggles) do
            if w and w.SetDisabled then
                w:SetDisabled(disabled)
            end
        end
    end
    local function RegisterSimpleNameControl(widget)
        simpleNameControls[#simpleNameControls + 1] = widget
        return widget
    end
    local function UpdateSimpleNameControls()
        local center = IsCenterNameMode()
        for _, w in ipairs(simpleNameControls) do
            if w and w.SetDisabled then
                w:SetDisabled(center)
            end
        end
        local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
        SetLevelToggleDisabled(np and np.showLevelAlways == true)
    end

    RegisterSimpleNameControl(C:AddToggle(health, {
        label = LO["Show Health Percent"],
        dbPath = DB .. ".showHealthPercent",
        disabled = IsCenterNameMode,
        callback = RefreshNameplates,
    }))

    C:AddToggle(health, {
        label = LO["Show Health Number"],
        desc = LO["Shows HP as a number (e.g. 22k) and percent on the health bar."],
        dbPath = DB .. ".showHealthNumber",
        callback = RefreshNameplates,
    })

    C:AddSlider(health, {
        label = LO["Health Number Font Size"],
        desc = LO["Health number font scale (1-10)."],
        dbPath = DB .. ".healthNumberFontSize",
        min = 1, max = 10, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddSpacer(health)

    C:AddToggle(health, {
        label = LO["Gray Tapped Units"],
        desc = LO["Grays the health bar when a unit is tapped by another player or group."],
        dbPath = DB .. ".tapDeniedGray",
        callback = function()
            if addon.Nameplates and addon.Nameplates.tap then
                local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
                if np and np.tapDeniedGray == false then
                    addon.Nameplates.tap.WipeCache()
                end
            end
            RefreshNameplates()
        end,
    })

    C:AddColorPicker(health, {
        label = LO["Friendly Player Color"],
        dbPath = DB .. ".friendlyPlayerColor",
        callback = RefreshNameplates,
    })

    C:AddColorPicker(health, {
        label = LO["Friendly NPC Color"],
        dbPath = DB .. ".friendlyNPCColor",
        callback = RefreshNameplates,
    })

    local function ClearFriendlyNameClassIfNoBarClass()
        local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
        if np and not np.friendlyClassColors and not np.partyClassColors then
            np.friendlyNameClassColors = false
        end
    end

    local function RefreshNameplatesAndTab()
        RefreshNameplates()
        if Panel and Panel.SelectTab then
            Panel:SelectTab("nameplates")
        end
    end

    C:AddToggle(health, {
        label = LO["Party Class Colors"],
        desc = LO["Use class colors for party member nameplates instead of the friendly player color."],
        dbPath = DB .. ".partyClassColors",
        callback = function()
            ClearFriendlyNameClassIfNoBarClass()
            RefreshNameplatesAndTab()
        end,
    })

    C:AddToggle(health, {
        label = LO["Enemy Player Class Colors"],
        desc = LO["Use class colors for enemy player nameplates."],
        dbPath = DB .. ".enemyPlayerClassColors",
        callback = function(val)
            local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
            if np and not val then
                np.enemyNameClassColors = false
            end
            RefreshNameplatesAndTab()
        end,
    })

    C:AddToggle(health, {
        label = LO["Friendly Class Colors"],
        desc = LO["Class-color every friendly player, not just your group. Party and raid show automatically; others fill in when you target or mouse over them, or instantly with awesome_wotlk."],
        dbPath = DB .. ".friendlyClassColors",
        callback = function()
            ClearFriendlyNameClassIfNoBarClass()
            RefreshNameplatesAndTab()
        end,
    })

    local headline = C:AddSection(scroll, LO["Headline Mode"])

    local function IsHeadlineEnabled()
        local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
        return np and np.friendlyNameOnly == true
    end

    local function RebuildHeadlineSection()
        RefreshNameplates()
        if not Panel or not Panel.SelectTab then return end
        local savedScroll = Panel.scrollWidget and Panel.scrollWidget.scrollbar
            and Panel.scrollWidget.scrollbar:GetValue() or 0
        Panel:SelectTab("nameplates")
        if savedScroll > 0 and Panel.scrollWidget and Panel.scrollWidget.scrollbar then
            Panel.scrollWidget.scrollbar:SetValue(savedScroll)
            Panel.scrollWidget:SetScroll(savedScroll)
        end
    end

    C:AddToggle(headline, {
        label = LO["Enable Headline Mode"],
        desc = LO["Hide health, power and cast bars on friendly nameplates, showing only the name."],
        dbPath = DB .. ".friendlyNameOnly",
        callback = RebuildHeadlineSection,
    })

    if IsHeadlineEnabled() then
        C:AddColorPicker(headline, {
            label = LO["Name Text Color"],
            dbPath = DB .. ".friendlyNameOnlyColor",
            callback = RefreshNameplates,
        })

        C:AddLabel(headline, LO["Friendly Players"])
        C:AddDescription(headline, LO["Class colors, title, guild and AFK read from the unit: party/raid show automatically; others fill in when you target or mouse over them, or instantly with awesome_wotlk."])

        C:AddToggle(headline, {
            label = LO["Party / Raid Members"],
            desc = LO["Apply headline mode to your party and raid members."],
            dbPath = DB .. ".friendlyNameOnlyParty",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["All Friendly Players"],
            desc = LO["Apply headline mode to all friendly players, not just your group."],
            dbPath = DB .. ".friendlyNameOnlyAll",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["Show Class Colors"],
            desc = LO["Show friendly player names in their class color."],
            dbPath = DB .. ".friendlyNameOnlyClassColor",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["Show Player Title"],
            desc = LO["Show the player's title with their name (e.g. \"Arthas Jenkins\")."],
            dbPath = DB .. ".friendlyNameOnlyTitle",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["Show Guild Name"],
            desc = LO["Show the player's guild name below their name."],
            dbPath = DB .. ".friendlyNameOnlyGuild",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["Show AFK Status"],
            desc = LO["Show an <AFK> tag for away players."],
            dbPath = DB .. ".friendlyNameOnlyAFK",
            callback = RefreshNameplates,
        })

        C:AddLabel(headline, LO["Friendly NPCs"])
        C:AddDescription(headline, LO["NPC titles fill in when you target or mouse over the NPC, or instantly with awesome_wotlk."])

        C:AddToggle(headline, {
            label = LO["Headline Mode for NPCs"],
            desc = LO["Apply headline mode to friendly NPCs."],
            dbPath = DB .. ".friendlyNPCNameOnly",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["Show NPC Title"],
            desc = LO["Show the NPC's title or occupation below its name (e.g. <General Supplies>)."],
            dbPath = DB .. ".friendlyNPCNameOnlyTitle",
            callback = RefreshNameplates,
        })
        C:AddToggle(headline, {
            label = LO["Show Full Plate on Target"],
            desc = LO["When headline mode is active, show health, power and cast bars on your current target."],
            dbPath = DB .. ".headlineExcludeTarget",
            callback = RefreshNameplates,
        })
    end

    local nameLevel = C:AddSection(scroll, LO["Name & Level"])

    C:AddToggle(nameLevel, {
        label = LO["Center Name Only"],
        desc = LO["Centers the unit name and hides the health percent."],
        dbPath = DB .. ".centerNameOnly",
        callback = function()
            RefreshNameplates()
            UpdateSimpleNameControls()
        end,
    })

    C:AddDropdown(nameLevel, {
        label = LO["Name Font"],
        dbPath = DB .. ".nameFont",
        values = {
            primary = LO["Primary Font"],
            actionbar = LO["Actionbar Font"],
            narrow = LO["Narrow Font"],
            arial = LO["Arial Font"],
        },
        width = 220,
        callback = RefreshNameplates,
    })

    C:AddSlider(nameLevel, {
        label = LO["Font Size"],
        desc = LO["Name and health percent font scale (1-10, default 2)."],
        dbPath = DB .. ".fontSize",
        min = 1, max = 10, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddToggle(nameLevel, {
        label = LO["Overlay Name On Health Bar"],
        desc = LO["Anchor the name, level, health percent, and elite icon centered on the health bar instead of above it."],
        dbPath = DB .. ".nameOverlayHealthBar",
        callback = RefreshNameplates,
    })

    C:AddSlider(nameLevel, {
        label = LO["Overlay Vertical Offset"],
        desc = LO["Fine-tune the vertical position when 'Overlay Name On Health Bar' is enabled."],
        dbPath = DB .. ".nameOverlayOffsetY",
        min = -20, max = 20, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    C:AddSlider(nameLevel, {
        label = LO["Name Row Horizontal Padding"],
        desc = LO["Inset the name, level, and health percent from the left and right edges of the health bar. Does not affect the elite icon."],
        dbPath = DB .. ".nameRowPaddingX",
        min = 0, max = 40, step = 1,
        width = 200,
        callback = RefreshNameplates,
    })

    local function UpdateLevelToggleStates()
        UpdateSimpleNameControls()
    end

    C:AddToggle(nameLevel, {
        label = LO["Show Level Always"],
        desc = LO["Always show the unit level next to the name."],
        dbPath = DB .. ".showLevelAlways",
        callback = function()
            RefreshNameplates()
            UpdateLevelToggleStates()
        end,
    })

    C:AddDropdown(nameLevel, {
        label = LO["Level Format"],
        dbPath = DB .. ".levelTextFormat",
        values = {
            brackets = "[LVL]",
            parentheses = "(LVL)",
            plain = "LVL",
        },
        width = 220,
        callback = RefreshNameplates,
    })

    levelToggles[#levelToggles + 1] = C:AddToggle(nameLevel, {
        label = LO["Show Level In Name When Targeted"],
        dbPath = DB .. ".showLevelInName",
        callback = RefreshNameplates,
    })

    levelToggles[#levelToggles + 1] = C:AddToggle(nameLevel, {
        label = LO["Show Level on Hover"],
        dbPath = DB .. ".showLevelOnHover",
        callback = RefreshNameplates,
    })

    C:AddToggle(nameLevel, {
        label = LO["Name Reaction Colors"],
        desc = LO["Tint name text with the health bar reaction color (red/yellow/green/blue)."],
        dbPath = DB .. ".nameReactionColors",
        callback = RefreshNameplates,
    })

    C:AddToggle(nameLevel, {
        label = LO["Class Colors on Friendly Names"],
        desc = LO["Use class colors for friendly player name text."],
        dbPath = DB .. ".friendlyNameClassColors",
        disabled = function()
            local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
            if not np then return false end
            return not (np.friendlyClassColors or np.partyClassColors)
        end,
        callback = RefreshNameplates,
    })

    C:AddToggle(nameLevel, {
        label = LO["Class Colors on Enemy Names"],
        desc = LO["Use class colors for enemy player name text."],
        dbPath = DB .. ".enemyNameClassColors",
        disabled = function()
            local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
            return np and np.enemyPlayerClassColors == false or false
        end,
        callback = RefreshNameplates,
    })

    UpdateSimpleNameControls()
end

local function BuildTargetSubTab(scroll)
    C:AddSpacer(scroll)

    local targetThreat = C:AddSection(scroll, LO["Target & Threat"])

    C:AddToggle(targetThreat, {
        label = LO["Show Target Highlight"],
        desc = LO["White border glow on the current target nameplate."],
        dbPath = DB .. ".showTargetHighlight",
        callback = RefreshNameplates,
    })

    C:AddToggle(targetThreat, {
        label = LO["Show Target Arrows"],
        desc = LO["Left/right arrows on the targeted nameplate."],
        dbPath = DB .. ".showTargetArrows",
        callback = RefreshNameplates,
    })

    C:AddToggle(targetThreat, {
        label = LO["Show Threat Glow"],
        desc = LO["Color the glow and health bar by threat status (red = tanking, orange = losing, yellow = gaining)."],
        dbPath = DB .. ".threatGlow",
        callback = RefreshNameplates,
    })

    C:AddToggle(targetThreat, {
        label = LO["Tank Mode"],
        desc = LO["Inverts threat colors for a tank: green means you hold aggro, red means you lost it."],
        dbPath = DB .. ".tankMode",
        callback = RefreshNameplates,
    })
end

local function BuildBarsSubTab(scroll)
    C:AddSpacer(scroll)

    local powerSection = C:AddSection(scroll, LO["Power Bar"])
    local function IsPowerBarDisabled()
        return not C:GetDBValue(DB .. ".showPowerBar")
    end

    C:AddToggle(powerSection, {
        label = LO["Show Power Bar"],
        dbPath = DB .. ".showPowerBar",
        callback = RefreshAndRebuildNameplates,
    })

    C:AddToggle(powerSection, {
        label = LO["Power Bar — Players Only"],
        dbPath = DB .. ".powerPlayersOnly",
        disabled = IsPowerBarDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(powerSection, {
        label = LO["Show Power Bar Text"],
        desc = LO["Show numeric values (current / percent) on the power bar."],
        dbPath = DB .. ".showPowerBarText",
        disabled = IsPowerBarDisabled,
        callback = RefreshNameplates,
    })

    C:AddDropdown(powerSection, {
        label = LO["Power Bar Background"],
        desc = LO["Choose the background texture used behind the power bar fill."],
        dbPath = DB .. ".powerBarBackground",
        values = {
            black = LO["Black"],
            castbar = LO["Same as Castbar"],
        },
        width = 200,
        disabled = IsPowerBarDisabled,
        callback = RefreshNameplates,
    })

    local castSection = C:AddSection(scroll, LO["Cast Bar"])
    local function IsCastBarDisabled()
        return not C:GetDBValue(DB .. ".showCastBar")
    end

    C:AddToggle(castSection, {
        label = LO["Show Cast Bars"],
        desc = LO["Show cast bars when the unit is known for sure: your target, focus, mouseover, arena enemies, or a group member's target."],
        dbPath = DB .. ".showCastBar",
        callback = RefreshAndRebuildNameplates,
    })

    C:AddSlider(castSection, {
        label = LO["Cast Bar Height"],
        dbPath = DB .. ".castBarHeight",
        min = 3, max = 20, step = 1,
        width = 200,
        disabled = IsCastBarDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(castSection, {
        label = LO["Show Spell Name"],
        desc = LO["Show the spell name text on the cast bar."],
        dbPath = DB .. ".showCastBarSpellName",
        disabled = IsCastBarDisabled,
        callback = RefreshAndRebuildNameplates,
    })

    local function IsSpellNameDisabled()
        return IsCastBarDisabled() or not C:GetDBValue(DB .. ".showCastBarSpellName")
    end

    C:AddSlider(castSection, {
        label = LO["Spell Name Font Size"],
        dbPath = DB .. ".castBarSpellNameFontSize",
        min = 6, max = 16, step = 1,
        width = 200,
        disabled = IsSpellNameDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(castSection, {
        label = LO["Spell Name Offset X"],
        dbPath = DB .. ".castBarSpellNameOffsetX",
        min = -50, max = 50, step = 1,
        width = 200,
        disabled = IsSpellNameDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(castSection, {
        label = LO["Spell Name Offset Y"],
        dbPath = DB .. ".castBarSpellNameOffsetY",
        min = -20, max = 20, step = 1,
        width = 200,
        disabled = IsSpellNameDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(castSection, {
        label = LO["Show Party/Raid Cast Bars"],
        desc = LO["Also show cast bars on party and raid allies, even when you are not targeting them."],
        dbPath = DB .. ".showPartyRaidCastBars",
        disabled = IsCastBarDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(castSection, {
        label = LO["Hide Pet Casts"],
        desc = LO["Hide Pet Casts Desc"],
        dbPath = DB .. ".castBarHidePetCasts",
        disabled = IsCastBarDisabled,
        callback = RefreshNameplates,
    })

    local offTargetSection = C:AddSection(scroll, LO["Off-Target Cast Bars"])

    local function GetOffTargetCastMode()
        local mode = C:GetDBValue(DB .. ".castBarOffTargetMode")
        if mode == "off" or mode == "aggressive" or mode == "safe" or mode == "hybrid" then
            return mode
        end
        if C:GetDBValue(DB .. ".castBarOffTargetSafeOnly") then
            return "safe"
        end
        if C:GetDBValue(DB .. ".castBarOffTarget") then
            return "aggressive"
        end
        return "safe"
    end

    -- The three nested checkboxes (enable / aggressive / players-only) collapse to
    -- one of the four engine modes. Reaction filters (hostile/enemy-player only) are
    -- intentionally gone: 3.3.5a only ever shows enemy OR ally plates (CVar), so they
    -- were redundant; we clear their legacy DB values so they never affect this UI.
    local function ApplyOffTargetState(enabled, aggressive, playersOnly)
        local mode
        if not enabled then
            mode = "off"
        elseif not aggressive then
            mode = "safe"
        elseif playersOnly then
            mode = "hybrid"
        else
            mode = "aggressive"
        end
        C:SetDBValue(DB .. ".castBarOffTargetMode", mode)
        C:SetDBValue(DB .. ".castBarOffTarget", mode == "aggressive")
        C:SetDBValue(DB .. ".castBarOffTargetSafeOnly", mode == "safe")
        C:SetDBValue(DB .. ".castBarPvPAggressive", false)
        C:SetDBValue(DB .. ".castBarOffTargetHostileOnly", false)
    end

    local function RebuildNameplatesTab()
        RefreshNameplates()
        if Panel and Panel.SelectTab then
            Panel:SelectTab("nameplates")
        end
    end

    local offTargetMode = GetOffTargetCastMode()
    local offTargetEnabled = offTargetMode ~= "off"
    local offTargetAggressive = offTargetMode == "aggressive" or offTargetMode == "hybrid"
    local offTargetPlayersOnly = offTargetMode == "hybrid"

    C:AddToggle(offTargetSection, {
        label = LO["Enable Off-Target Detection"],
        desc = LO["Enable Off-Target Detection Desc"],
        getFunc = function() return GetOffTargetCastMode() ~= "off" end,
        setFunc = function(value)
            ApplyOffTargetState(value, offTargetAggressive, offTargetPlayersOnly)
        end,
        disabled = IsCastBarDisabled,
        callback = RebuildNameplatesTab,
    })

    if offTargetEnabled then
        local aggressiveDesc = LO["Off-Target Aggressive Mode Desc"]
        if offTargetAggressive and not offTargetPlayersOnly then
            aggressiveDesc = aggressiveDesc .. "\n\n" .. LO["Off-Target Aggressive Warning"]
        end

        C:AddToggle(offTargetSection, {
            label = LO["Off-Target Aggressive Mode"],
            desc = aggressiveDesc,
            getFunc = function()
                local m = GetOffTargetCastMode()
                return m == "aggressive" or m == "hybrid"
            end,
            setFunc = function(value)
                ApplyOffTargetState(true, value, offTargetPlayersOnly)
            end,
            disabled = IsCastBarDisabled,
            callback = RebuildNameplatesTab,
        })

        if offTargetAggressive then
            local playersOnlyDesc = LO["Off-Target Players Only Desc"]
            if offTargetPlayersOnly then
                playersOnlyDesc = playersOnlyDesc .. "\n\n" .. LO["Off-Target Players Only Warning"]
            end

            C:AddToggle(offTargetSection, {
                label = LO["Off-Target Players Only"],
                desc = playersOnlyDesc,
                getFunc = function() return GetOffTargetCastMode() == "hybrid" end,
                setFunc = function(value)
                    ApplyOffTargetState(true, true, value)
                end,
                disabled = IsCastBarDisabled,
                callback = RebuildNameplatesTab,
            })
        end
    end
end

local function BuildIconsSubTab(scroll)
    EnsureOptionsPanelHideHook()
    C:AddSpacer(scroll)

    local iconSection = C:AddSection(scroll, LO["Icons & Markers"])

    local function RebuildIconsSubTab()
        RefreshNameplates()
        if Panel and Panel.SelectTab then
            Panel:SelectTab("nameplates")
        end
    end

    C:AddToggle(iconSection, {
        label = LO["Show Raid Markers"],
        desc = LO["Show raid target markers (skull, cross, star, etc.) on nameplates."],
        dbPath = DB .. ".showRaidMarkers",
        callback = RebuildIconsSubTab,
    })

    -- Nested under Show Raid Markers (same pattern as off-target cast options).
    if (Panel and Panel.indexing) or C:GetDBValue(DB .. ".showRaidMarkers") then
        C:AddToggle(iconSection, {
            label = LO["Beside Bar Layout"],
            desc = LO["Place the raid marker beside the bar (as with DragonUI debuffs). Useful with other aura addons."],
            dbPath = DB .. ".raidMarkerDebuffLayout",
            indent = 18,
            callback = RefreshNameplates,
        })
    end

    C:AddToggle(iconSection, {
        label = LO["Color Health Bar by Raid Marker"],
        desc = LO["Colors the health bar with the raid marker's color, on both allies and enemies."],
        dbPath = DB .. ".raidMarkHealthColor",
        callback = RefreshNameplates,
    })

    C:AddToggle(iconSection, {
        label = LO["Show Elite Icon"],
        desc = LO["Show elite/rare dragon icon on nameplates."],
        dbPath = DB .. ".showEliteIcon",
        callback = RefreshAndRebuildNameplates,
    })

    C:AddDropdown(iconSection, {
        label = LO["Elite Icon Style"],
        desc = LO["Choose dragon or star style for elite and rare nameplate icons."],
        dbPath = DB .. ".eliteIconStyle",
        values = {
            dragon = LO["Dragon"],
            star = LO["Star"],
        },
        width = 220,
        disabled = function()
            return not C:GetDBValue(DB .. ".showEliteIcon")
        end,
        callback = RefreshNameplates,
    })

    C:AddSlider(iconSection, {
        label = LO["Elite Icon Vertical Offset"],
        desc = LO["Fine-tune the elite/rare icon's vertical position."],
        dbPath = DB .. ".eliteIconOffsetY",
        min = -20, max = 20, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue(DB .. ".showEliteIcon")
        end,
        callback = RefreshNameplates,
    })

    C:AddToggle(iconSection, {
        label = LO["Show Combo Points"],
        desc = LO["Show combo points on the current target nameplate."],
        dbPath = DB .. ".showComboPoints",
        callback = RefreshNameplates,
    })

    local function IsTotemIconsDisabled()
        return not C:GetDBValue(DB .. ".showTotemIcons")
    end
    local totemIconOnlyToggle, totemTimerToggle, totemNormalModeBox, totemPositionDropdown

    local function RefreshTotemControlStates(val)
        local disabled = not val
        if totemIconOnlyToggle and totemIconOnlyToggle.SetDisabled then
            totemIconOnlyToggle:SetDisabled(disabled)
        end
        if totemTimerToggle and totemTimerToggle.SetDisabled then
            totemTimerToggle:SetDisabled(disabled)
        end
        if totemNormalModeBox and totemNormalModeBox.SetDisabled then
            totemNormalModeBox:SetDisabled(disabled)
        end
        if totemPositionDropdown and totemPositionDropdown.SetDisabled then
            totemPositionDropdown:SetDisabled(disabled)
        end
    end

    C:AddToggle(iconSection, {
        label = LO["Show Totem Icons"],
        desc = LO["Show icons for recognized shaman totems. DragonUI uses localized spell names and automatically learns your own active totems."],
        dbPath = DB .. ".showTotemIcons",
        callback = RefreshAndRebuildNameplates,
    })

    totemIconOnlyToggle = C:AddToggle(iconSection, {
        label = LO["Totem Icon Only"],
        desc = LO["Hide the totem's nameplate entirely and show only its icon."],
        dbPath = DB .. ".totemIconOnly",
        disabled = IsTotemIconsDisabled,
        callback = RefreshNameplates,
    })

    totemTimerToggle = C:AddToggle(iconSection, {
        label = LO["Show Totem Life Timer"],
        desc = LO["Show remaining life on your own totems (requires their icon to be known)."],
        dbPath = DB .. ".showTotemTimer",
        disabled = IsTotemIconsDisabled,
        callback = RefreshNameplates,
    })

    totemNormalModeBox = C:AddEditBox(iconSection, {
        label = LO["Totems Without Icon"],
        desc = LO["Comma-separated, exact totem names (as shown in-game) that should never get a totem icon and render as a normal nameplate instead."],
        dbPath = DB .. ".totemNormalModeList",
        disabled = IsTotemIconsDisabled,
        callback = RefreshNameplates,
    })

    totemPositionDropdown = C:AddDropdown(iconSection, {
        label = LO["Totem Icon Position"],
        desc = LO["Choose where the totem icon is anchored around the nameplate."],
        dbPath = DB .. ".totemIconPosition",
        values = {
            top = LO["Top"],
            left = LO["Left"],
            right = LO["Right"],
        },
        width = 220,
        disabled = IsTotemIconsDisabled,
        callback = RefreshNameplates,
    })

    RefreshTotemControlStates(not IsTotemIconsDisabled())

    local bghCompat = C:AddSection(scroll, LO["BG Healer Icon"])
    if IsBattleGroundHealersLoaded() then
        C:AddDescription(bghCompat, LO["Override BattleGroundHealers icon position on DragonUI nameplates."])
    else
        C:AddDescription(bghCompat, LO["This feature is available only when BattleGroundHealers is loaded."])
    end

    local function IsBGHCompatConfigDisabled()
        local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
        return (not IsBattleGroundHealersLoaded()) or (np and np.bghCompatEnabled == false)
    end

    C:AddToggle(bghCompat, {
        label = LO["BattleGroundHealers Compatibility"],
        desc = LO["Keep BG healer marks attached to DragonUI nameplates."],
        dbPath = DB .. ".bghCompatEnabled",
        disabled = function()
            return not IsBattleGroundHealersLoaded()
        end,
        callback = function(val)
            if not val then
                ClearBGHTestMarks()
            end
            RefreshNameplates()
            if Panel and Panel.SelectTab then
                Panel:SelectTab("nameplates")
            end
        end,
    })

    C:AddDropdown(bghCompat, {
        label = LO["Anchor"],
        dbPath = DB .. ".bghIconAnchor",
        values = {
            left = LO["Left"],
            top = LO["Top"],
            right = LO["Right"],
            bottom = LO["Bottom"],
        },
        disabled = IsBGHCompatConfigDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(bghCompat, {
        label = LO["Offset X"],
        dbPath = DB .. ".bghIconOffsetX",
        min = -120, max = 120, step = 1,
        width = 200,
        disabled = IsBGHCompatConfigDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(bghCompat, {
        label = LO["Offset Y"],
        dbPath = DB .. ".bghIconOffsetY",
        min = -120, max = 120, step = 1,
        width = 200,
        disabled = IsBGHCompatConfigDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(bghCompat, {
        label = LO["Icon Size"],
        dbPath = DB .. ".bghIconSize",
        min = 12, max = 60, step = 1,
        width = 200,
        disabled = IsBGHCompatConfigDisabled,
        callback = RefreshNameplates,
    })

    local markTargetButton
    C:AddToggle(bghCompat, {
        label = LO["Enable Test Mode"],
        desc = LO["Enable manual marking for BattleGroundHealers compatibility checks."],
        dbPath = DB .. ".bghTestMode",
        disabled = IsBGHCompatConfigDisabled,
        callback = function(val)
            if not val then
                ClearBGHTestMarks()
            end
            if markTargetButton and markTargetButton.SetDisabled then
                markTargetButton:SetDisabled(not val)
            end
        end,
    })

    markTargetButton = C:AddButton(bghCompat, {
        label = LO["Mark Target"],
        desc = LO["Toggle BattleGroundHealers mark on your current target while test mode is enabled."],
        disabled = function()
            local np = addon.db.profile.modules and addon.db.profile.modules.nameplates
            if IsBGHCompatConfigDisabled() then
                return true
            end
            return not (np and np.bghTestMode == true)
        end,
        callback = ToggleBGHTestMarkTarget,
    })
end

local function BuildQuestSubTab(scroll)
    C:AddSpacer(scroll)

    local function IsQuestIconsDisabled()
        return not C:GetDBValue(DB .. ".questIcons.enabled")
    end

    -- X / Y / Size sliders in one row, bound to icons[keyGetter()] (the selected texture).
    local function AddIconRow(parent, keyGetter)
        local function field(f)
            return DB .. ".questIcons.icons." .. keyGetter() .. "." .. f
        end
        local row = C:AddRow(parent)
        C:AddSlider(row, {
            label = LO["Offset X"],
            getFunc = function() return C:GetDBValue(field("x")) end,
            setFunc = function(v) C:SetDBValue(field("x"), v) end,
            min = -200, max = 200, step = 1, width = 150,
            disabled = IsQuestIconsDisabled,
            callback = RefreshNameplates,
        })
        C:AddSlider(row, {
            label = LO["Offset Y"],
            getFunc = function() return C:GetDBValue(field("y")) end,
            setFunc = function(v) C:SetDBValue(field("y"), v) end,
            min = -200, max = 200, step = 1, width = 150,
            disabled = IsQuestIconsDisabled,
            callback = RefreshNameplates,
        })
        C:AddSlider(row, {
            label = LO["Size"],
            getFunc = function() return C:GetDBValue(field("size")) end,
            setFunc = function(v) C:SetDBValue(field("size"), v) end,
            min = 8, max = 128, step = 1, width = 150,
            disabled = IsQuestIconsDisabled,
            callback = RefreshNameplates,
        })
    end

    -- General
    local general = C:AddSection(scroll, LO["Quest Icons"])
    C:AddToggle(general, {
        label = LO["Show Quest Icons"],
        desc = LO["Show kill/loot icons over your quest-objective mobs. Without awesome_wotlk, only your target, mouseover and focus show them."],
        dbPath = DB .. ".questIcons.enabled",
        callback = RefreshAndRebuildNameplates,
    })
    C:AddToggle(general, {
        label = LO["Resolve By Name"],
        desc = LO["Match plate names to your active objectives so icons show on every plate without awesome_wotlk. Kill objectives work on their own; loot needs a quest addon below."],
        dbPath = DB .. ".questIcons.nameResolution",
        disabled = IsQuestIconsDisabled,
        callback = RefreshQuestNameResolution,
    })
    C:AddDropdown(general, {
        label = LO["Loot Database"],
        desc = LO["Which quest addon supplies loot data (which mob drops a quest item). Auto picks the best loaded one."],
        dbPath = DB .. ".questIcons.lootProvider",
        values = {
            auto = LO["Auto"],
            off = LO["Off"],
            pfquest = "pfQuest",
            questie = "Questie",
            questhelper = "QuestHelper",
        },
        width = 220,
        disabled = IsQuestIconsDisabled,
        callback = RefreshQuestNameResolution,
    })
    C:AddDropdown(general, {
        label = LO["Icons With Questie"],
        desc = LO["Who draws quest icons on plates when Questie is loaded with its own nameplate icons on. DragonUI disables Questie's (needs reload); Questie hides DragonUI's."],
        dbPath = DB .. ".questIcons.questieCoexist",
        values = {
            ask = LO["Ask"],
            dragonui = "DragonUI",
            questie = "Questie",
        },
        width = 220,
        disabled = function() return IsQuestIconsDisabled() or not (_G.Questie or _G.QuestieLoader) end,
        callback = function()
            local np = addon.Nameplates
            if not (np and np.quest_coexist) then return end
            local val = C:GetDBValue(DB .. ".questIcons.questieCoexist")
            if np.quest_coexist.ApplyChoice then np.quest_coexist.ApplyChoice(val) end
            if val == "ask" and np.quest_coexist.Check then np.quest_coexist.Check() end
        end,
    })
    C:AddToggle(general, {
        label = LO["Pointer Mode"],
        desc = LO["Show a single quest marker on any objective mob instead of separate kill/loot icons."],
        dbPath = DB .. ".questIcons.pointerMode",
        disabled = IsQuestIconsDisabled,
        callback = RefreshAndRebuildNameplates,
    })

    -- Test preview (tuning aid)
    local test = C:AddSection(scroll, LO["Test Preview"])
    C:AddDescription(test, LO["Force one icon on all enemy nameplates so you can position and size it. Set to Off when done."])
    C:AddDropdown(test, {
        label = LO["Preview Icon"],
        dbPath = DB .. ".questIcons.testIcon",
        values = {
            off = LO["Off"],
            sword = LO["Sword"],
            skull = LO["Skull"],
            elite = LO["Elite"],
            bag = LO["Bag"],
            chest = LO["Chest"],
            pointer = LO["Pointer"],
        },
        width = 220,
        disabled = IsQuestIconsDisabled,
        callback = RefreshNameplates,
    })

    -- Kill icon: style + position/size of the selected texture
    local killS = C:AddSection(scroll, LO["Kill Icon"])
    C:AddDropdown(killS, {
        label = LO["Icon"],
        desc = LO["Choose the icon shown for kill objectives."],
        dbPath = DB .. ".questIcons.killIcon",
        values = {
            sword = LO["Sword"],
            skull = LO["Skull"],
        },
        width = 220,
        disabled = IsQuestIconsDisabled,
        callback = RefreshAndRebuildNameplates,
    })
    AddIconRow(killS, function() return C:GetDBValue(DB .. ".questIcons.killIcon") end)

    -- Elite kill icon (auto-override for elite/rare kill objectives)
    local eliteS = C:AddSection(scroll, LO["Elite Kill Icon"])
    C:AddToggle(eliteS, {
        label = LO["Enabled"],
        desc = LO["Show a distinct icon on elite and rare kill objectives."],
        dbPath = DB .. ".questIcons.eliteKillIcon",
        disabled = IsQuestIconsDisabled,
        callback = RefreshNameplates,
    })
    AddIconRow(eliteS, function() return "elite" end)

    -- Loot icon
    local lootS = C:AddSection(scroll, LO["Loot Icon"])
    C:AddDropdown(lootS, {
        label = LO["Icon"],
        desc = LO["Choose the icon shown for loot/collect objectives."],
        dbPath = DB .. ".questIcons.lootIcon",
        values = {
            bag = LO["Bag"],
            chest = LO["Chest"],
        },
        width = 220,
        disabled = IsQuestIconsDisabled,
        callback = RefreshAndRebuildNameplates,
    })
    AddIconRow(lootS, function() return C:GetDBValue(DB .. ".questIcons.lootIcon") end)

    -- Pointer icon
    local ptrS = C:AddSection(scroll, LO["Pointer Icon"])
    AddIconRow(ptrS, function() return "pointer" end)
end

local function BuildDebuffsSubTab(scroll)
    C:AddSpacer(scroll)

    local debuffSection = C:AddSection(scroll, LO["Debuffs"])
    local function IsDebuffsDisabled()
        return not C:GetDBValue(DB .. ".showDebuffs")
    end
    local function IsCooldownTextDisabled()
        return IsDebuffsDisabled() or not C:GetDBValue(DB .. ".showDebuffCooldown")
    end
    local function IsCooldownSwipeDisabled()
        return IsDebuffsDisabled() or not C:GetDBValue(DB .. ".debuffCooldownSwipe")
    end

    C:AddToggle(debuffSection, {
        label = LO["Show Debuffs"],
        dbPath = DB .. ".showDebuffs",
        callback = RefreshAndRebuildNameplates,
    })

    C:AddSlider(debuffSection, {
        label = LO["Max Debuff Icons"],
        dbPath = DB .. ".maxDebuffs",
        min = 1, max = 9, step = 1,
        width = 200,
        disabled = IsDebuffsDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(debuffSection, {
        label = LO["Debuff Icon Size"],
        desc = LO["Size of debuff icons on nameplates."],
        dbPath = DB .. ".debuffIconSize",
        min = 10, max = 42, step = 1,
        width = 200,
        disabled = IsDebuffsDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(debuffSection, {
        label = LO["Show Debuff Cooldown Text"],
        desc = LO["Show remaining debuff time on each debuff icon."],
        dbPath = DB .. ".showDebuffCooldown",
        disabled = IsDebuffsDisabled,
        callback = RefreshAndRebuildNameplates,
    })

    C:AddToggle(debuffSection, {
        label = LO["Show Debuff Cooldown Swipe"],
        desc = LO["Also show a radial cooldown sweep on each debuff icon."],
        dbPath = DB .. ".debuffCooldownSwipe",
        disabled = IsDebuffsDisabled,
        callback = RefreshAndRebuildNameplates,
    })

    C:AddDropdown(debuffSection, {
        label = LO["Debuff Cooldown Swipe Style"],
        desc = LO["Choose the visual style of the cooldown sweep. These texture-based styles stay aligned while the nameplate is moving."],
        dbPath = DB .. ".debuffCooldownSwipeStyle",
        values = {
            vertical = LO["Shade Fill"],
            pie = LO["Quadrant Sweep"],
            squareSwirl = LO["Square Radial Sweep"],
        },
        width = 220,
        disabled = IsCooldownSwipeDisabled,
        callback = RefreshNameplates,
    })

    C:AddSlider(debuffSection, {
        label = LO["Debuff Cooldown Font Size"],
        desc = LO["Font size for debuff remaining time text."],
        dbPath = DB .. ".debuffCooldownFontSize",
        min = 6, max = 16, step = 1,
        width = 200,
        disabled = IsCooldownTextDisabled,
        callback = RefreshNameplates,
    })

    C:AddDropdown(debuffSection, {
        label = LO["Debuff Cooldown Text Position"],
        desc = LO["Choose where the debuff cooldown text is anchored on the icon."],
        dbPath = DB .. ".debuffCooldownTextAnchor",
        values = {
            center = LO["Center"],
            topleft = LO["Top Left"],
            topright = LO["Top Right"],
            bottomleft = LO["Bottom Left"],
            bottomright = LO["Bottom Right"],
        },
        width = 220,
        disabled = IsCooldownTextDisabled,
        callback = RefreshNameplates,
    })

    C:AddSpacer(scroll)

    local positionSection = C:AddSection(scroll, LO["Position"])

    local function OnDebuffPositionSliderChanged()
        RefreshNameplates()
        if addon.Nameplates and addon.Nameplates.auras then
            addon.Nameplates.auras.EnablePreview(10)
        end
    end

    C:AddSlider(positionSection, {
        label = LO["Debuff Horizontal Offset"],
        desc = LO["Shifts the debuff icon row left or right relative to its default position."],
        dbPath = DB .. ".debuffOffsetX",
        min = -240, max = 240, step = 1,
        width = 200,
        disabled = IsDebuffsDisabled,
        callback = OnDebuffPositionSliderChanged,
    })

    C:AddSlider(positionSection, {
        label = LO["Debuff Vertical Offset"],
        desc = LO["Shifts the debuff icon row up or down relative to its default position."],
        dbPath = DB .. ".debuffOffsetY",
        min = -240, max = 240, step = 1,
        width = 200,
        disabled = IsDebuffsDisabled,
        callback = OnDebuffPositionSliderChanged,
    })

    C:AddToggle(positionSection, {
        label = LO["Show Debuff Position Debug Box"],
        desc = LO["Displays a box showing where the debuff icon row starts and ends, even when no debuffs are active."],
        dbPath = DB .. ".showDebuffPositionDebug",
        disabled = IsDebuffsDisabled,
        callback = function()
            if addon.Nameplates and addon.Nameplates.auras then
                addon.Nameplates.module._debuffPreviewUntil = nil
                addon.Nameplates.auras.RefreshAllPreviewOverlays()
            end
        end,
    })

    C:AddSpacer(scroll)

    local filterSection = C:AddSection(scroll, LO["Filtering"])

    C:AddToggle(filterSection, {
        label = LO["Only Show on Target & Focus"],
        desc = LO["Hide debuffs on every nameplate except your current target and focus."],
        dbPath = DB .. ".debuffOnlyTargetFocus",
        disabled = IsDebuffsDisabled,
        callback = RefreshNameplates,
    })

    C:AddToggle(filterSection, {
        label = LO["Only My Debuffs"],
        desc = LO["Only show debuffs you applied yourself."],
        dbPath = DB .. ".debuffOnlyMine",
        disabled = IsDebuffsDisabled,
        callback = RefreshNameplates,
    })

    local dynamicWidgets = {}
    local function RegisterDynamicWidget(widget, disabledFunc)
        table.insert(dynamicWidgets, { widget = widget, disabledFunc = disabledFunc })
        return widget
    end
    local function RefreshFilterControlStates()
        for _, entry in ipairs(dynamicWidgets) do
            if entry.widget and entry.widget.SetDisabled and entry.disabledFunc then
                entry.widget:SetDisabled(entry.disabledFunc())
            end
        end
    end
    local function IsSpellListDisabled()
        local mode = C:GetDBValue(DB .. ".debuffFilterMode")
        return IsDebuffsDisabled() or (mode ~= "whitelist" and mode ~= "blacklist")
    end

    C:AddDropdown(filterSection, {
        label = LO["Debuff List Mode"],
        desc = LO["Choose whether the spell list below shows only listed debuffs or hides them."],
        dbPath = DB .. ".debuffFilterMode",
        values = {
            all = LO["All"],
            whitelist = LO["Whitelist"],
            blacklist = LO["Blacklist"],
        },
        width = 220,
        disabled = IsDebuffsDisabled,
        callback = function()
            RefreshFilterControlStates()
            RefreshNameplates()
            if Panel and Panel.SelectTab then
                Panel:SelectTab("nameplates")
            end
        end,
    })

    local function RebuildDebuffFilterUI()
        RefreshNameplates()
        if Panel and Panel.SelectTab then
            Panel:SelectTab("nameplates")
        end
    end

    C:AddSpellFilterList(filterSection, {
        dbPath = DB .. ".debuffFilterList",
        disabled = IsSpellListDisabled,
        callback = RefreshNameplates,
        rebuildUI = RebuildDebuffFilterUI,
        registerDynamic = RegisterDynamicWidget,
    })

    C:AddSpacer(scroll)

    local prioritySection = C:AddSection(scroll, LO["Priority Highlight"])

    C:AddToggle(prioritySection, {
        label = LO["Highlight Crowd Control"],
        desc = LO["Adds a colored border to stuns, fears, polymorphs, silences, and other crowd control."],
        dbPath = DB .. ".debuffHighlightCC",
        disabled = IsDebuffsDisabled,
        callback = RefreshNameplates,
    })
end

-- ============================================================================
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    general  = BuildGeneralSubTab,
    layout   = BuildLayoutSubTab,
    behavior = BuildBehaviorSubTab,
    health   = BuildHealthSubTab,
    target   = BuildTargetSubTab,
    bars     = BuildBarsSubTab,
    icons    = BuildIconsSubTab,
    quest    = BuildQuestSubTab,
    debuffs  = BuildDebuffsSubTab,
}

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local function BuildNameplatesTab(scroll)
    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("nameplates")
    end, subTabBuilders)

    if not Panel.indexing then
        local builder = subTabBuilders[activeSubTab]
        if builder then builder(scroll) end
    end
end

Panel:RegisterTab("nameplates", LO["Nameplates"], BuildNameplatesTab, 6.5)
