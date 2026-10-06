-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local E = addon.EditorSettings or {}
addon.EditorSettings = E
E.frames = E.frames or {}

local floor = math.floor

-- ============================================================================
-- COMBAT / ERROR HELPERS
-- ============================================================================

local function Locked()
    return InCombatLockdown() and true or false
end
E.IsLocked = Locked

local function EditorActive()
    local mode = addon.EditorMode
    return mode and mode.IsActive and mode:IsActive() and true or false
end

local function Report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- ============================================================================
-- DATABASE ACCESS (same keys and semantics as DragonUI_Options Controls:Get/SetDBValue)
-- ============================================================================

local function Walk(root, path)
    local value = root
    for key in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[key]
    end
    return value
end

local function GetDB(path)
    local value = Walk(addon.db and addon.db.profile, path)
    if value == nil then
        value = Walk(addon.defaults and addon.defaults.profile, path)
    end
    return value
end

local function SetDB(path, value)
    local profile = addon.db and addon.db.profile
    if not profile then return false end

    local keys = { strsplit(".", path) }
    local node = profile
    for i = 1, #keys - 1 do
        if type(node[keys[i]]) ~= "table" then node[keys[i]] = {} end
        node = node[keys[i]]
    end
    node[keys[#keys]] = value
    return true
end

local function GetNumber(path, fallback)
    return tonumber(GetDB(path)) or fallback
end

E.GetDB = GetDB
E.SetDB = SetDB

-- ============================================================================
-- LABELS (addon.L is strict: an unknown key would fire the error handler)
-- ============================================================================

local function LocaleHas(appName, active, key)
    if type(active) == "table" and rawget(active, key) ~= nil then return true end

    local acl = LibStub and LibStub("AceLocale-3.0-DragonUI", true)
    local app = acl and acl.apps and rawget(acl.apps, appName)
    if type(app) ~= "table" then return false end

    local default = acl.defaultlocales and acl.defaultlocales[appName] or "enUS"
    local base = rawget(app, default)
    return type(base) == "table" and rawget(base, key) ~= nil
end

function E.Label(key)
    if type(key) ~= "string" then return tostring(key) end

    local core = addon.L
    local meta = core and getmetatable(core)
    if core and LocaleHas("DragonUI", meta and meta.__index, key) then
        return core[key]
    end

    local options = addon.LO
    if options and LocaleHas("DragonUI_Options", options, key) then
        return options[key]
    end

    return key
end

local Label = E.Label

-- Marks a label key; rows keep it so RefreshLabels can translate again once the language override is readable.
local function T(key) return key end

-- ============================================================================
-- COALESCED REFRESH QUEUE
-- ============================================================================

local DEFER_DELAY = 0.05
-- Refreshes that rebuild whole skins can run at most this often while a slider is being dragged.
local SLOW_REFRESH = { ["r:darkmode"] = 0.2 }
local lastRun = {}

local refreshQueue, refreshOrder = {}, {}
local syncQueue, syncOrder = {}, {}
local timerArmed = false

local function RunNow(fn, id)
    if Locked() then
        if addon.CombatQueue and addon.CombatQueue.Add then
            addon.CombatQueue:Add("editor_settings:" .. id, fn)
        end
        return
    end

    local ok, err = pcall(fn)
    if not ok then Report(err) end
end

local function Enqueue(queue, order, key, fn)
    if queue[key] == nil then order[#order + 1] = key end
    queue[key] = fn
end

local function Arm()
    if timerArmed then return end
    timerArmed = true
    addon:After(DEFER_DELAY, function()
        timerArmed = false
        E.Flush(true)
    end)
end

local function Drain(queue, order, throttled)
    for i = 1, #order do
        local key = order[i]
        local fn = queue[key]
        if fn then
            local interval = throttled and SLOW_REFRESH[key]
            local now = GetTime and GetTime() or 0
            if interval and lastRun[key] and now - lastRun[key] < interval then
                Enqueue(refreshQueue, refreshOrder, key, fn)
                Arm()
            else
                lastRun[key] = now
                RunNow(fn, key)
            end
        end
    end
end

-- With `throttled` (the timer) slow refreshes may wait; otherwise everything pending runs now.
function E.Flush(throttled)
    local rq, ro, sq, so = refreshQueue, refreshOrder, syncQueue, syncOrder
    refreshQueue, refreshOrder, syncQueue, syncOrder = {}, {}, {}, {}
    Drain(rq, ro, throttled == true)
    Drain(sq, so, false)
end

function E.Defer(key, fn)
    if type(fn) ~= "function" then return end
    Enqueue(refreshQueue, refreshOrder, key, fn)
    Arm()
end

local function HasPendingRefresh()
    return #refreshOrder > 0
end

-- ============================================================================
-- REFRESH ENTRY POINTS (the same functions the Options tabs call)
-- ============================================================================

local R = {}

R.player = function()
    local frame = addon.PlayerFrame
    if frame and frame.RefreshPlayerFrame then frame.RefreshPlayerFrame() end
end
R.target = function()
    local frame = addon.TargetFrame
    if frame and frame.RefreshTargetFrame then frame.RefreshTargetFrame() end
end
R.targetAuras = function()
    if addon.RefreshTargetFocusAuraLayout then addon.RefreshTargetFocusAuraLayout() end
end
R.focus = function()
    if addon.RefreshFocusFrame then addon:RefreshFocusFrame() end
end
R.pet = function()
    if addon.RefreshPetFrame then addon.RefreshPetFrame() end
end
R.tot = function()
    local frame = addon.TargetOfTarget
    if frame and frame.RefreshToTFrame then frame.RefreshToTFrame() end
end
R.fot = function()
    local frame = addon.TargetOfFocus
    if frame and frame.RefreshToFFrame then frame.RefreshToFFrame() end
end
R.party = function()
    local party = addon.PartyFrames
    if party and party.ApplyLiveLayout then
        party:ApplyLiveLayout()
    elseif addon.RefreshPartyFrames then
        addon:RefreshPartyFrames()
    end
end
R.boss = function()
    if addon.RefreshBossFrames then addon.RefreshBossFrames() end
end
-- The preview bar has no real cast behind it, so the icon needs the preview routine to run again.
local function RefreshCastbarPreview(frameName)
    if not EditorActive() then return end
    local data = addon.EditableFrames and addon.EditableFrames[frameName]
    if data and data.showTest and data.frame and addon.frames and addon.frames[data.frame] then
        data.showTest()
    end
end
R.castbarPlayer = function()
    if addon.RefreshCastbar then addon.RefreshCastbar() end
    RefreshCastbarPreview("PlayerCastbar")
end
R.castbarTarget = function()
    if addon.RefreshTargetCastbar then addon.RefreshTargetCastbar() end
    RefreshCastbarPreview("TargetCastbar")
end
R.castbarFocus = function()
    if addon.RefreshFocusCastbar then addon.RefreshFocusCastbar() end
    RefreshCastbarPreview("FocusCastbar")
end
R.bars = function()
    local refresh = addon.RefreshMainbars or addon.RefreshMainbarsSystem
    if refresh then refresh() end
end
R.extrabar = function()
    if addon.RefreshExtrabarFrame then addon.RefreshExtrabarFrame() end
end
R.xprep = function()
    if addon.RefreshXpRepBars then addon.RefreshXpRepBars() end
end
R.micromenu = function()
    if addon.RefreshMicromenu then addon.RefreshMicromenu() end
end
R.bags = function()
    if addon.RefreshBagsPosition then addon.RefreshBagsPosition() end
end
R.minimap = function()
    if addon.RefreshMinimap then addon:RefreshMinimap() end
end
R.minimapDecor = function()
    local decor = addon.MinimapDecorations
    if decor and decor.Refresh then
        decor:Refresh()
    elseif addon.RefreshMinimap then
        addon:RefreshMinimap()
    end
end
R.petbar = function()
    if addon.RefreshPetbarFrame then addon.RefreshPetbarFrame() end
end
R.petbarGrid = function()
    if addon.RefreshPetbarGrid then addon.RefreshPetbarGrid() end
end
R.quest = function()
    if addon.RefreshQuestTracker then addon.RefreshQuestTracker() end
end
R.auras = function()
    local module = addon.BuffFrameModule
    if module and module.RefreshAuraSpacing then
        module:RefreshAuraSpacing()
        return
    end
    if BuffFrame_UpdateAllBuffAnchors then BuffFrame_UpdateAllBuffAnchors() end
    if module and module.UpdatePosition then module:UpdatePosition() end
end

R.partyText = function()
    if addon.RefreshPartyFrames then addon:RefreshPartyFrames() end
end
R.stance = function()
    if addon.RefreshStance then addon.RefreshStance() end
end
R.multicast = function()
    if addon.RefreshMulticast then addon.RefreshMulticast(true) end
end
R.hotkeys = function()
    if addon.RefreshAdditionalBarHotkeys then
        addon.RefreshAdditionalBarHotkeys()
    elseif addon.RefreshAllHotkeys then
        addon.RefreshAllHotkeys()
    elseif addon.RefreshButtons then
        addon.RefreshButtons()
    end
end
R.hotkeyStyle = function()
    if addon.RefreshHotkeyStyle then
        addon.RefreshHotkeyStyle()
    elseif addon.RefreshAllHotkeys then
        addon.RefreshAllHotkeys()
        if addon.RefreshExtrabarHotkeys then addon.RefreshExtrabarHotkeys() end
    end
end
R.extrabarHotkeys = function()
    if addon.RefreshExtrabarHotkeys then addon.RefreshExtrabarHotkeys() end
end
R.buttons = function()
    if addon.RefreshButtons then addon.RefreshButtons() end
end
R.cooldowns = function()
    if addon.RefreshCooldowns then addon.RefreshCooldowns() end
end
R.darkmode = function()
    if addon.RefreshDarkMode then addon.RefreshDarkMode(true) end
end
R.auraBorders = function()
    if addon.RefreshAuraBordersSystem then addon.RefreshAuraBordersSystem() end
end
R.microVehicle = function()
    if addon.RefreshMicromenuVehicle then addon.RefreshMicromenuVehicle() end
    if addon.RefreshBagsVehicle then addon.RefreshBagsVehicle() end
end
R.skins = function()
    if addon.UF and addon.UF.RefreshSkins then addon.UF.RefreshSkins() end
end
R.barVisibility = function()
    if addon.RefreshActionBarVisibility then addon.RefreshActionBarVisibility() end
end
R.bagVisibility = function()
    if addon.RefreshActionBarVisibility then addon.RefreshActionBarVisibility() end
    local micro = addon.db and addon.db.profile and addon.db.profile.micromenu
    if micro and micro.bags_collapsed and addon.RefreshBags then addon.RefreshBags() end
end
R.extrabarVisibility = function()
    if addon.VisibilityFade then addon.VisibilityFade.Update("extrabar1") end
end
R.minimapVisibility = function()
    local module = addon.MinimapModule
    if module and module.SyncMinimapVisibility then module.SyncMinimapVisibility() end
end
R.questVisibility = function()
    local module = addon.QuestTrackerModule
    if module and module.SyncHoverVisibility then module:SyncHoverVisibility() end
end
-- The fake party frames skip the normal refresh, so their fade is updated directly.
R.partyVisibility = function()
    local fade = addon.VisibilityFade
    if fade then
        for i = 1, 4 do fade.Update("party" .. i) end
    end
    R.partyText()
end
-- Same as the Options toggles: apply the bar, then push the flags to Blizzard's own action bar settings.
R.barToggle = function()
    R.barVisibility()
    if addon.SyncBarCVarsFromProfile then addon.SyncBarCVarsFromProfile() end
end
R.extrabarToggle = function()
    if addon.RefreshExtrabarSystem then addon.RefreshExtrabarSystem() end
end

E.refresh = R

local REFRESH_NAME = {}
for name, fn in pairs(R) do REFRESH_NAME[fn] = name end

local function Deferred(refresh)
    if refresh then E.Defer("r:" .. (REFRESH_NAME[refresh] or "custom"), refresh) end
end

local function Immediate(refresh)
    if not refresh then return end
    E.Flush()
    RunNow(refresh, "r:" .. (REFRESH_NAME[refresh] or "custom"))
end

-- ============================================================================
-- ROW CONSTRUCTORS
-- ============================================================================

local function Snap(value, step, min, max)
    value = tonumber(value)
    if not value then return nil end
    if step and step > 0 then
        local inverse = 1 / step
        value = floor(value * inverse + 0.5) / inverse
    end
    if min and value < min then value = min end
    if max and value > max then value = max end
    return value
end

local function ItemText(item)
    local text = Label(item.textKey)
    if item.textFormat then text = string.format(item.textFormat, text) end
    return text
end

local function Items(list)
    local items = {}
    for i = 1, #list do
        local item = { value = list[i][1], textKey = list[i][2], textFormat = list[i][3] }
        item.text = ItemText(item)
        items[i] = item
    end
    return items
end

local function Slider(labelKey, path, min, max, step, refresh, o)
    o = o or {}
    local row = {
        type = "slider",
        key = o.key or path,
        labelKey = labelKey,
        label = Label(labelKey),
        path = path,
        min = min,
        max = max,
        step = step,
        format = o.format or (step < 1 and "%.2f" or "%d"),
        get = o.get or function() return GetNumber(path, min) end,
        hidden = o.hidden,
        disabled = o.disabled,
        needsOverlayResize = o.resize and true or false,
    }
    local apply = o.set or function(value)
        SetDB(path, value)
        Deferred(refresh)
    end
    row.set = function(value)
        value = Snap(value, step, min, max)
        if value == nil then return end
        apply(value)
        if o.after then o.after(value) end
    end
    return row
end

local function Check(labelKey, path, refresh, o)
    o = o or {}
    local row = {
        type = "checkbox",
        key = o.key or path,
        labelKey = labelKey,
        label = Label(labelKey),
        path = path,
        get = o.get or function() return GetDB(path) and true or false end,
        hidden = o.hidden,
        disabled = o.disabled,
        needsOverlayResize = o.resize and true or false,
        tooltipKey = o.tooltip,
        tooltip = o.tooltip and Label(o.tooltip) or nil,
    }
    local apply = o.set or function(value)
        SetDB(path, value)
        Immediate(refresh)
    end
    row.set = function(value)
        value = value and true or false
        apply(value)
        if o.after then o.after(value) end
    end
    return row
end

local function Drop(labelKey, path, list, refresh, o)
    o = o or {}
    local row = {
        type = "dropdown",
        key = o.key or path,
        labelKey = labelKey,
        label = Label(labelKey),
        path = path,
        items = type(list) == "function" and function() return Items(list()) end or Items(list),
        get = o.get or function() return GetDB(path) end,
        hidden = o.hidden,
        disabled = o.disabled,
        needsOverlayResize = o.resize and true or false,
    }
    local apply = o.set or function(value)
        SetDB(path, value)
        Immediate(refresh)
    end
    row.set = function(value)
        if value == nil then return end
        apply(value)
        if o.after then o.after(value) end
    end
    return row
end

local function Header(labelKey, o)
    o = o or {}
    local row = { type = "header", labelKey = labelKey, label = Label(labelKey) }
    if o.collapsible then
        row.collapsible = true
        row.collapsed = o.collapsed and true or false
    end
    return row
end

local function Hidden(row, hidden)
    row.hidden = hidden
    return row
end

-- A foldable group: the rows after it belong to it until the next header.
local function Section(labelKey, collapsed, hidden, onExpand)
    local row = Hidden(Header(labelKey, { collapsible = true, collapsed = collapsed }), hidden)
    row.onExpand = onExpand
    return row
end

-- A fold inside the section above it; its rows follow it until the next header.
local function SubSection(labelKey, collapsed, hidden)
    local row = Section(labelKey, collapsed, hidden)
    row.level = 2
    return row
end

-- A swatch that opens the color picker; get() returns { r, g, b, a } and set(r, g, b, a) saves one.
local function ColorRow(labelKey, o)
    return { type = "color", key = o.key, labelKey = labelKey, label = Label(labelKey),
        hasAlpha = o.hasAlpha, get = o.get, set = o.set, hidden = o.hidden, disabled = o.disabled }
end

-- Rows and lists of rows may be mixed freely; the result is one flat list.
local function Flatten(out, item)
    if item.type then
        out[#out + 1] = item
    else
        for i = 1, #item do Flatten(out, item[i]) end
    end
end

local function Join(...)
    local out = {}
    for i = 1, select("#", ...) do
        local item = select(i, ...)
        if item then Flatten(out, item) end
    end
    return out
end

-- The shared hover/combat visibility engine's switches; `field(name)` builds the db path for one of them.
local LOGIC_ITEMS = {
    { "and", T("AND (both required)") },
    { "or", T("OR (either condition)") },
}

local function Dotted(prefix)
    return function(name) return prefix .. "." .. name end
end

local function Underscored(prefix)
    return function(name) return prefix .. "_" .. name end
end

-- Show and Hide in Combat exclude each other, like the Options toggles.
local function CombatSwitch(labelKey, field, own, other, refresh)
    return Check(labelKey, field(own), refresh, {
        set = function(value)
            SetDB(field(own), value)
            if value then SetDB(field(other), false) end
            Immediate(refresh)
        end })
end

local function VisibilityRows(field, refresh, o)
    o = o or {}
    local rows = { Section(T("Visibility"), true) }
    if o.alwaysHidden then
        rows[#rows + 1] = Check(T("Always Hidden"), field("always_hidden"), refresh)
    end
    rows[#rows + 1] = Check(T("Show on Hover Only"), field("show_on_hover"), refresh)
    rows[#rows + 1] = CombatSwitch(T("Show in Combat Only"), field, "show_in_combat", "hide_in_combat", refresh)
    if o.hideInCombat then
        rows[#rows + 1] = CombatSwitch(T("Hide in Combat"), field, "hide_in_combat", "show_in_combat", refresh)
    end
    rows[#rows + 1] = Drop(T("Hover/Combat Logic"), field("visibility_logic"), LOGIC_ITEMS, refresh, {
        get = function() return GetDB(field("visibility_logic")) == "or" and "or" or "and" end })
    return rows
end

-- ============================================================================
-- OVERLAY / LIST SYNCHRONISATION
-- ============================================================================

local needsSync = false

local function ReapplyBarPositions()
    if Locked() then return end
    if addon.ApplyActionBarPositions then addon.ApplyActionBarPositions() end
    if addon.PositionActionBarsToContainers then addon.PositionActionBarsToContainers() end
end

-- Their overlays are only sized inside showTest, which also resets the green selection tint.
local function ReRunShowTest(frameName)
    if Locked() or not EditorActive() then return end

    local data = addon.EditableFrames and addon.EditableFrames[frameName]
    local frame = data and data.frame
    if not (frame and data.showTest and addon.frames and addon.frames[frame]) then return end

    data.showTest()
    if addon.selectedEditorFrame == frame then
        if addon.SetNinesliceState then addon.SetNinesliceState(frame, true) end
        if addon.ApplySelectionTint then addon.ApplySelectionTint(frame) end
    end
end

-- RefreshMainbars resizes around the centre; without this the next tick snaps back to the saved edge.
local SYNC = {
    mainbar = ReapplyBarPositions,
    rightbar = ReapplyBarPositions,
    leftbar = ReapplyBarPositions,
    bottombarleft = ReapplyBarPositions,
    bottombarright = ReapplyBarPositions,
    stance = function() ReRunShowTest("stance") end,
    totembar = function() ReRunShowTest("totembar") end,
}

function E.SyncOverlay(first, second)
    local frameName = (first == E) and second or first
    local sync = frameName and SYNC[frameName]
    if not sync then return end

    if HasPendingRefresh() then
        Enqueue(syncQueue, syncOrder, "s:" .. frameName, sync)
        Arm()
    else
        RunNow(sync, "s:" .. frameName)
    end
end

local function SyncEntry(data, frames)
    local frame = data.frame
    if not frame then return false end

    local wanted = true
    if data.editorVisible then wanted = data.editorVisible() and true or false end
    local active = frames[frame] ~= nil

    if wanted and not active then
        if data.editorVisible then frame:Show() end
        addon.HideUIFrame(frame)
        if data.showTest then data.showTest() end
        if data.onShow then data.onShow() end
        return true
    elseif active and not wanted then
        addon.ShowUIFrame(frame)
        if data.hideTest then data.hideTest() end
        frame:Hide()
        return true
    end
    return false
end

function E.SyncFrames()
    if not EditorActive() then return false end
    if Locked() then
        needsSync = true
        return false
    end

    needsSync = false
    local changed = false
    local frames = addon.frames or {}

    for _, data in pairs(addon.EditableFrames or {}) do
        local ok, result = pcall(SyncEntry, data, frames)
        if not ok then
            Report(result)
        elseif result then
            changed = true
        end
    end

    local selected = addon.selectedEditorFrame
    if selected and (frames[selected] == nil or not selected:IsShown()) then
        if addon.DeselectEditorFrame then addon.DeselectEditorFrame() end
        changed = true
    end

    if changed then E.Rebuild() end
    return changed
end

function E.Rebuild()
    local callback = E.onRebuild
    if type(callback) ~= "function" then return end

    local ok, err = pcall(callback)
    if not ok then Report(err) end
end

function E.OnEditorClose()
    E.Flush()
    if GetDB("buffs.layout_preview") then
        SetDB("buffs.layout_preview", false)
        RunNow(R.auras, "r:auras")
    end
end

-- ============================================================================
-- REGISTRY
-- ============================================================================

local function GuardRow(row)
    if row.type == "header" then return end

    local disabled = row.disabled
    row.disabled = function()
        if Locked() then return true end
        return disabled and disabled() and true or false
    end

    local set = row.set
    if set then
        row.set = function(...)
            if Locked() then return end
            return set(...)
        end
    end

    local onClick = row.onClick
    if onClick then
        row.onClick = function(...)
            if Locked() then return end
            return onClick(...)
        end
    end
end

function E.Register(first, second, third)
    local frameName, def = first, second
    if first == E then frameName, def = second, third end
    if type(frameName) ~= "string" or type(def) ~= "table" then return end

    def.settings = def.settings or {}
    for i = 1, #def.settings do
        GuardRow(def.settings[i])
    end
    if not def.resize then
        def.resize = function() E.SyncOverlay(frameName) end
    end

    E.frames[frameName] = def
    return def
end

function E.Get(first, second)
    local frameName = (first == E) and second or first
    return frameName and E.frames[frameName]
end

-- ============================================================================
-- RELOAD-REQUIRED SETTINGS (Options may not be loaded, so the popup lives here)
-- ============================================================================

local RELOAD_POPUP = "DRAGONUI_EDITOR_SETTING_RELOAD"
local RELOAD_DEBOUNCE = 0.5
local lastReloadPrompt
local sessionValues = {}
local pendingRevert = {}

-- Raw saved values taken at login; a setting is "pending" while it differs from what this session loaded.
local RELOAD_PATHS = {
    "micromenu.grayscale_icons",
    "micromenu.show_latency_indicator",
    "xprepbar.style",
    "style.xpbar",
    "buttons.hide_main_bar_background",
    "modules.bagster.enabled",
}

local function RevertPending()
    for path in pairs(pendingRevert) do
        local loaded = sessionValues[path]
        if loaded ~= nil then SetDB(path, loaded) end
        pendingRevert[path] = nil
    end
    E.Rebuild()
end

local function BuildReloadPopup()
    return {
        text = Label("Changing this setting requires a UI reload to apply correctly."),
        button1 = Label("Reload Now"),
        button2 = Label("Later"),
        OnAccept = function() ReloadUI() end,
        OnCancel = function() RevertPending() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

if StaticPopupDialogs then
    StaticPopupDialogs[RELOAD_POPUP] = BuildReloadPopup()
end

-- `revertPaths` are restored if the user answers "Later" (what Options does for the XP bar style).
function E.PromptReload(revertPaths)
    if type(revertPaths) == "table" then
        for i = 1, #revertPaths do pendingRevert[revertPaths[i]] = true end
    end
    if not (StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs[RELOAD_POPUP]) then return end
    if StaticPopup_Visible and StaticPopup_Visible(RELOAD_POPUP) then return end

    local now = GetTime and GetTime() or 0
    if lastReloadPrompt and now - lastReloadPrompt < RELOAD_DEBOUNCE then return end
    lastReloadPrompt = now
    StaticPopup_Show(RELOAD_POPUP)
end

local function DismissReloadPrompt()
    for path in pairs(pendingRevert) do pendingRevert[path] = nil end
    if StaticPopup_Hide then StaticPopup_Hide(RELOAD_POPUP) end
end

local function CaptureSessionValue(path)
    local value = GetDB(path)
    if value == nil then value = false end
    sessionValues[path] = value
end

-- True while the saved value differs from the one this session was loaded with.
function E.IsReloadPending(path)
    local loaded = sessionValues[path]
    if loaded == nil then return false end
    local current = GetDB(path)
    if current == nil then current = false end
    return current ~= loaded
end

local function AnyReloadPending()
    for path in pairs(sessionValues) do
        if E.IsReloadPending(path) then return true end
    end
    return false
end

local function ReloadSet(path, o)
    return function(value)
        SetDB(path, value)
        local paths = { path }
        if o.extraPaths then
            for i = 1, #o.extraPaths do
                SetDB(o.extraPaths[i], value)
                paths[#paths + 1] = o.extraPaths[i]
            end
        end
        if E.IsReloadPending(path) then
            E.PromptReload(o.revert and paths or nil)
        elseif not AnyReloadPending() then
            DismissReloadPrompt()
        end
        E.Rebuild()
    end
end

-- Same as Options: the value is saved now, applied after a reload, and the dependent rows stay frozen until then.
local function ReloadCheck(labelKey, path, o)
    o = o or {}
    return Check(labelKey, path, nil, { set = ReloadSet(path, o), hidden = o.hidden, disabled = o.disabled,
        tooltip = o.tooltip })
end

local function ReloadDrop(labelKey, path, list, o)
    o = o or {}
    return Drop(labelKey, path, list, nil, { set = ReloadSet(path, o), hidden = o.hidden, disabled = o.disabled })
end

local function Append(frameName, ...)
    local def = E.Get(frameName)
    if not def then return end
    for i = 1, select("#", ...) do
        local rows = select(i, ...)
        if rows.type then rows = { rows } end
        for j = 1, #rows do
            GuardRow(rows[j])
            def.settings[#def.settings + 1] = rows[j]
        end
    end
end

-- ============================================================================
-- DEFINITIONS: UNIT FRAMES
-- ============================================================================

local function TextFormatItems()
    return {
        { "numeric", T("Current Value") },
        { "percentage", T("Percentage") },
        { "both", T("Numbers + %") },
        { "formatted", T("Current / Max") },
    }
end

local PVP_STYLES = {
    { "auto", T("Auto") },
    { "classic", T("DragonUI") },
    { "forever", T("Forever") },
}

-- Any text setting reveals the frame's numbers for a few seconds, so the change is visible without "always show".
local function PreviewTexts(key)
    return function()
        local system = addon.TextSystem
        if system and system.PreviewTexts then system.PreviewTexts(key) end
    end
end

-- "Always show" is a state, not a format change: it repaints from the settings and shows only what it asks for.
local function RepaintTexts(key)
    return function()
        local system = addon.TextSystem
        if system and system.RefreshTexts then system.RefreshTexts(key) end
    end
end

local function TextRows(key, refresh)
    local base = "unitframe." .. key
    local preview = { after = PreviewTexts(key) }
    local repaint = { after = RepaintTexts(key) }
    return {
        Drop(T("Text Format"), base .. ".textFormat", TextFormatItems(), refresh, preview),
        Check(T("Format Large Numbers"), base .. ".breakUpLargeNumbers", refresh, preview),
        Check(T("Always Show Health Text"), base .. ".showHealthTextAlways", refresh, repaint),
        Check(T("Always Show Mana Text"), base .. ".showManaTextAlways", refresh, repaint),
    }
end

local STYLE_ITEMS = {
    { "auto", T("Auto") },
    { "dragonui", T("DragonUI") },
    { "forever", T("Forever") },
}

local function LevelStyleRow()
    return Drop(T("Level Style"), "unitframe.level_style", STYLE_ITEMS, R.skins, {
        after = function() E.Rebuild() end })
end

-- Turning the class portrait on also turns the alternative icons on, as the Options tab does.
local function PortraitRows(key, refresh)
    local base = "unitframe." .. key
    return {
        Check(T("Class Portrait"), base .. ".classPortrait", refresh, {
            set = function(value)
                SetDB(base .. ".classPortrait", value)
                if value then SetDB(base .. ".alternativeClassIcons", true) end
                Immediate(refresh)
                E.Rebuild()
            end }),
        Check(T("Alternative Class Icons"), base .. ".alternativeClassIcons", refresh, {
            disabled = function() return not GetDB(base .. ".classPortrait") end }),
    }
end

local function PvPRows(key, refresh)
    local base = "unitframe." .. key
    return {
        Check(T("Show PvP Icon"), base .. ".show_pvp_icon", refresh),
        Drop(T("PvP Icon Style"), base .. ".pvp_icon_style", PVP_STYLES, refresh),
    }
end

local function FatOn()
    return GetDB("unitframe.player.fat_healthbar") and true or false
end

local function NotDruid()
    return select(2, UnitClass("player")) ~= "DRUID"
end

E.Register("player", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.player.scale", 0.5, 2.0, 0.01, R.player),
    Check(T("Fat Health Bar"), "unitframe.player.fat_healthbar", R.player, {
        after = function() E.SyncFrames(); E.Rebuild() end }),
    Check(T("Hide Mana Bar"), "unitframe.player.fat_manabar_hidden", R.player, {
        hidden = function() return not FatOn() end,
        after = function() E.Rebuild() end }),
    Drop(T("Dragon Decoration"), "unitframe.player.dragon_decoration", {
        { "none", T("None") },
        { "elite", T("Elite (Retail)") },
        { "rareelite", T("RareElite (Retail)") },
        { "elite_forever", T("Elite (Forever)") },
        { "rareelite_forever", T("RareElite (Forever)") },
        { "worldboss_forever", T("World Boss (Forever)") },
    }, R.player),
    Check(T("Class Color Health"), "unitframe.player.classcolor", R.player),
    Section(T("Text Display"), true, nil, PreviewTexts("player")),
    TextRows("player", R.player),
    Section(T("Appearance"), true),
    PortraitRows("player", R.player),
    LevelStyleRow(),
    PvPRows("player", R.player),
    Section(T("Glow Effects"), true),
    Check(T("Show Rest Glow"), "unitframe.player.show_rest_glow", R.player),
    Check(T("Show Combat Flash"), "unitframe.player.combat_flash_enabled", R.player, {
        after = function() E.Rebuild() end }),
    Slider(T("Combat Flash Opacity"), "unitframe.player.combat_flash_opacity", 0.1, 1.0, 0.05, R.player, {
        disabled = function() return not GetDB("unitframe.player.combat_flash_enabled") end }),
    Section(T("Alternate Mana (Druid)"), true, NotDruid),
    Check(T("Always Show"), "unitframe.player.alwaysShowAlternateManaText", R.player, { hidden = NotDruid }),
    Drop(T("Text Format"), "unitframe.player.alternateManaFormat", {
        { "numeric", T("Current Value") },
        { "formatted", T("Current / Max") },
        { "percentage", T("Percentage") },
        { "both", T("Percentage + Current/Max") },
    }, R.player, { hidden = NotDruid }),
}) })

E.Register("fat_manabar", { settings = {
    Slider(T("Mana Bar Width"), "unitframe.player.fat_manabar_width", 50, 300, 1, R.player, { resize = true }),
    Slider(T("Mana Bar Height"), "unitframe.player.fat_manabar_height", 4, 30, 1, R.player, { resize = true }),
    Drop(T("Mana Bar Texture"), "unitframe.player.manabar_texture", {
        { "dragonui", T("DragonUI (Default)") },
        { "blizzard", T("Blizzard Classic") },
        { "blizzard_flat", T("Flat Solid") },
        { "smooth", T("Smooth") },
        { "aluminium", T("Aluminium") },
        { "litestep", T("LiteStep") },
    }, R.player),
} })

E.Register("target", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.target.scale", 0.5, 2.0, 0.01, R.target),
    Check(T("Show Buffs"), "unitframe.target.show_buffs", R.targetAuras),
    Check(T("Show Debuffs"), "unitframe.target.show_debuffs", R.targetAuras),
    Check(T("Class Color Health"), "unitframe.target.classcolor", R.target),
    Section(T("Text Display"), true, nil, PreviewTexts("target")),
    TextRows("target", R.target),
    Section(T("Appearance"), true),
    PortraitRows("target", R.target),
    Check(T("Show Name Background"), "unitframe.target.show_name_background", R.target),
    LevelStyleRow(),
    PvPRows("target", R.target),
}) })

E.Register("focus", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.focus.scale", 0.5, 2.0, 0.01, R.focus),
    Check(T("Show Buff/Debuff on Focus"), "unitframe.focus.show_buff_debuff", R.focus),
    Check(T("Class Color Health"), "unitframe.focus.classcolor", R.focus),
    Section(T("Text Display"), true, nil, PreviewTexts("focus")),
    TextRows("focus", R.focus),
    Section(T("Appearance"), true),
    PortraitRows("focus", R.focus),
    Check(T("Show Name Background"), "unitframe.focus.show_name_background", R.focus),
    LevelStyleRow(),
    PvPRows("focus", R.focus),
}) })

E.Register("tot", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.tot.scale", 0.5, 2.0, 0.01, R.tot),
    Check(T("Class Color Health"), "unitframe.tot.classcolor", R.tot),
    Section(T("Appearance"), true),
    PortraitRows("tot", R.tot),
}) })

E.Register("fot", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.fot.scale", 0.5, 2.0, 0.01, R.fot),
    Check(T("Class Color Health"), "unitframe.fot.classcolor", R.fot),
    Section(T("Appearance"), true),
    PortraitRows("fot", R.fot),
}) })

local function PetDetached()
    return GetDB("unitframe.pet.override") == true
end

E.Register("PetFrame", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.pet.scale", 0.5, 2.0, 0.01, R.pet),
    Slider(T("X Position"), "unitframe.pet.x", -2500, 2500, 1, R.pet, { hidden = PetDetached }),
    Slider(T("Y Position"), "unitframe.pet.y", -2500, 2500, 1, R.pet, { hidden = PetDetached }),
    Section(T("Text Display"), true, nil, PreviewTexts("pet")),
    TextRows("pet", R.pet),
    Section(T("Glow Effects"), true),
    Check(T("Threat Glow"), "unitframe.pet.enableThreatGlow", R.pet),
}) })

E.Register("party", { settings = Join({
    Section(T("General"), false),
    Slider(T("Scale"), "unitframe.party.scale", 0.5, 2.0, 0.01, R.party, { resize = true }),
    Drop(T("Orientation"), "unitframe.party.orientation", {
        { "vertical", T("Vertical") },
        { "horizontal", T("Horizontal") },
    }, R.party, { resize = true, after = function() E.Rebuild() end }),
    Slider(T("Vertical Padding"), "unitframe.party.padding_vertical", 10, 150, 1, R.party, {
        resize = true,
        hidden = function() return GetDB("unitframe.party.orientation") == "horizontal" end }),
    Slider(T("Horizontal Padding"), "unitframe.party.padding_horizontal", 10, 150, 1, R.party, {
        resize = true,
        hidden = function() return GetDB("unitframe.party.orientation") ~= "horizontal" end }),
    Section(T("Appearance"), true),
    Check(T("Class Color Health"), "unitframe.party.classcolor", R.partyText),
    Section(T("Text Display"), true, nil, PreviewTexts("party")),
    TextRows("party", R.partyText),
}) })

E.Register("boss", { settings = {
    Slider(T("Scale"), "unitframe.boss.scale", 0.5, 2.0, 0.01, R.boss, { resize = true }),
} })

-- ============================================================================
-- DEFINITIONS: CAST BARS
-- ============================================================================

local function CastbarSettings(prefix, refresh, widthMin, widthMax, heightMin, heightMax, withLatency)
    local function IconOff() return not GetDB(prefix .. ".showIcon") end
    local function SimpleText() return GetDB(prefix .. ".text_mode") == "simple" end

    local rows = Join({
        Section(T("General"), false),
        Slider(T("Width"), prefix .. ".sizeX", widthMin, widthMax, 1, refresh, { resize = true }),
        Slider(T("Height"), prefix .. ".sizeY", heightMin, heightMax, 1, refresh, { resize = true }),
        Slider(T("Scale"), prefix .. ".scale", 0.5, 2.0, 0.01, refresh, { resize = true }),
        Check(T("Show Icon"), prefix .. ".showIcon", refresh, { after = function() E.Rebuild() end }),
        Slider(T("Icon Size"), prefix .. ".sizeIcon", 1, 64, 1, refresh, { disabled = IconOff }),
        Check(T("Modern Icon Border"), prefix .. ".modernIconBorder", refresh, { disabled = IconOff }),
        Section(T("Text Display"), true),
        Drop(T("Text Mode"), prefix .. ".text_mode", {
            { "simple", T("Simple (Name Only)") },
            { "detailed", T("Detailed (Name + Time)") },
        }, refresh, { after = function() E.Rebuild() end }),
        Slider(T("Time Precision"), prefix .. ".precision_time", 0, 3, 1, refresh, { disabled = SimpleText }),
        Slider(T("Max Time Precision"), prefix .. ".precision_max", 0, 3, 1, refresh, { disabled = SimpleText }),
        Section(T("Behavior"), true),
        Slider(T("Hold Time (Success)"), prefix .. ".holdTime", 0, 2, 0.1, refresh),
        Slider(T("Hold Time (Interrupt)"), prefix .. ".holdTimeInterrupt", 0, 2, 0.1, refresh),
    })

    if withLatency then
        local function LatencyOff() return not GetDB("castbar.latency.enabled") end
        rows = Join(rows, {
            Section(T("Latency Indicator"), true),
            Check(T("Enable Latency Indicator"), "castbar.latency.enabled", refresh, {
                after = function() E.Rebuild() end }),
            Slider(T("Latency Alpha"), "castbar.latency.alpha", 0.1, 1.0, 0.05, refresh, {
                disabled = LatencyOff }),
        })
    end
    return { settings = rows }
end

E.Register("PlayerCastbar", CastbarSettings("castbar", R.castbarPlayer, 80, 512, 10, 64, true))
E.Register("TargetCastbar", CastbarSettings("castbar.target", R.castbarTarget, 50, 400, 5, 50))
E.Register("FocusCastbar", CastbarSettings("castbar.focus", R.castbarFocus, 50, 400, 5, 50))

-- ============================================================================
-- DEFINITIONS: ACTION BARS, XP/REP, MICRO MENU, BAGS
-- ============================================================================

local BUTTON_ORDER = {
    { "top_left", T("Top Left") },
    { "bottom_left", T("Bottom Left") },
    { "top_right", T("Top Right") },
    { "bottom_right", T("Bottom Right") },
}

local BAR_KEYS = {
    mainbar = { "player", "scale_actionbar" },
    rightbar = { "right", "scale_rightbar" },
    leftbar = { "left", "scale_leftbar" },
    bottombarleft = { "bottom_left", "scale_bottomleft" },
    bottombarright = { "bottom_right", "scale_bottomright" },
}

local function BarSettings(barKey, scaleKey)
    local prefix = "mainbars." .. barKey
    return { settings = {
        Section(T("General"), false),
        Slider(T("Scale"), "mainbars." .. scaleKey, 0.5, 2.0, 0.01, R.bars, { resize = true }),
        Slider(T("Columns"), prefix .. ".columns", 1, 12, 1, R.bars, { resize = true }),
        Slider(T("Buttons Shown"), prefix .. ".buttons_shown", 1, 12, 1, R.bars, { resize = true }),
        Slider(T("Button Spacing"), prefix .. ".button_spacing", 0, 20, 1, R.bars, {
            resize = true,
            get = function()
                local bars = GetDB("mainbars")
                local cfg = bars and bars[barKey]
                return (cfg and cfg.button_spacing) or (bars and bars.button_spacing) or 7
            end }),
        Section(T("Layout"), true),
        Check(T("Change Button Order"), prefix .. ".change_button_order", R.bars, {
            resize = true,
            set = function(value)
                SetDB(prefix .. ".change_button_order", value)
                if value and not GetDB(prefix .. ".button_order") then
                    SetDB(prefix .. ".button_order", "top_left")
                end
                Immediate(R.bars)
                E.Rebuild()
            end }),
        Drop(T("Button Order"), prefix .. ".button_order", BUTTON_ORDER, R.bars, {
            resize = true,
            hidden = function() return not GetDB(prefix .. ".change_button_order") end }),
    } }
end

for frameName, keys in pairs(BAR_KEYS) do
    E.Register(frameName, BarSettings(keys[1], keys[2]))
end

Append("mainbar",
    Section(T("Gryphons"), true),
    Drop(T("Style"), "style.gryphons", {
        { "old", T("Classic") },
        { "new", T("Dragonflight") },
        { "flying", T("Flying") },
        { "forever", T("Forever") },
        { "none", T("Hidden") },
    }, R.bars),
    Slider(T("Gryphon Scale"), "style.gryphonScale", 0.5, 2, 0.01, R.bars),
    Slider(T("Gryphon Offset X"), "style.gryphonOffsetX", -200, 200, 1, R.bars),
    Slider(T("Gryphon Offset Y"), "style.gryphonOffsetY", -200, 200, 1, R.bars))

local function XpRepHeightPath()
    local style = GetDB("xprepbar.style") or "dragonflightui"
    return style == "dragonflightui" and "xprepbar.bar_height_dfui" or "xprepbar.bar_height_retailui"
end

-- With a style change waiting for a reload, RefreshXpRepBars would mix both styles, so the rows freeze.
local function XpRepPending()
    return E.IsReloadPending("xprepbar.style")
end

local function XpRepSettings(scaleLabel, scalePath, isExperience)
    local rows = Join({
        Section(T("Size & Scale"), false),
        Slider(T("Bar Width"), "xprepbar.bar_width", 200, 1500, 1, R.xprep, {
            resize = true, disabled = XpRepPending }),
        Slider(T("Bar Height"), "xprepbar.bar_height", 6, 30, 1, R.xprep, {
            resize = true,
            disabled = XpRepPending,
            get = function() return GetNumber(XpRepHeightPath(), 6) end,
            set = function(value)
                SetDB(XpRepHeightPath(), value)
                Deferred(R.xprep)
            end }),
        Slider(scaleLabel, scalePath, 0.5, 1.5, 0.05, R.xprep, { disabled = XpRepPending }),
    })

    if isExperience then
        rows = Join(rows, {
            Section(T("Rested XP"), true),
            Check(T("Show Rested XP Background"), "xprepbar.show_rested_bar", R.xprep, {
                disabled = function() return XpRepPending() or GetDB("xprepbar.style") == "retailui" end }),
            Check(T("Show Exhaustion Tick"), "style.exhaustion_tick", R.xprep, { disabled = XpRepPending }),
        })
    end

    return { settings = Join(rows, {
        Section(T("Text Display"), true),
        Check(T("Always Show Text"), "xprepbar.always_show_text", R.xprep, { disabled = XpRepPending }),
        Check(T("Show XP Percentage"), "xprepbar.show_xp_percent", R.xprep, { disabled = XpRepPending }),
        Section(T("Style"), true),
        ReloadDrop(T("XP / Rep Bar Style"), "xprepbar.style", {
            { "dragonflightui", T("DragonflightUI") },
            { "retailui", T("RetailUI") },
        }, { extraPaths = { "style.xpbar" }, revert = true }),
    }) }
end

E.Register("xpbar", XpRepSettings(T("Experience Bar Scale"), "xprepbar.expbar_scale", true))
E.Register("repbar", XpRepSettings(T("Reputation Bar Scale"), "xprepbar.repbar_scale", false))

local function MicroPrefix()
    return "micromenu." .. (GetDB("micromenu.grayscale_icons") and "grayscale" or "normal")
end

local function GrayscalePending()
    return E.IsReloadPending("micromenu.grayscale_icons")
end

E.Register("micromenu", { settings = {
    Section(T("General"), false),
    ReloadCheck(T("Grayscale Icons"), "micromenu.grayscale_icons"),
    Slider(T("Scale"), "micromenu.scale_menu", 0.5, 3.0, 0.01, R.micromenu, {
        resize = true,
        disabled = GrayscalePending,
        get = function() return GetNumber(MicroPrefix() .. ".scale_menu", 1) end,
        set = function(value)
            SetDB(MicroPrefix() .. ".scale_menu", value)
            Deferred(R.micromenu)
        end }),
    Slider(T("Icon Spacing"), "micromenu.icon_spacing", -20, 40, 1, R.micromenu, {
        resize = true,
        disabled = GrayscalePending,
        get = function() return GetNumber(MicroPrefix() .. ".icon_spacing", 0) end,
        set = function(value)
            SetDB(MicroPrefix() .. ".icon_spacing", value)
            Deferred(R.micromenu)
        end }),
    Slider(T("Columns"), "micromenu.columns", 1, 12, 1, R.micromenu, {
        resize = true,
        disabled = GrayscalePending,
        get = function() return GetNumber(MicroPrefix() .. ".columns", 12) end,
        set = function(value)
            SetDB(MicroPrefix() .. ".columns", value)
            Deferred(R.micromenu)
        end }),
    Check(T("Invert Button Order"), "micromenu.invert_order", R.micromenu, {
        resize = true,
        disabled = GrayscalePending,
        get = function() return GetDB(MicroPrefix() .. ".invert_order") == true end,
        set = function(value)
            SetDB(MicroPrefix() .. ".invert_order", value)
            Immediate(R.micromenu)
        end }),
    Check(T("Hide on Vehicle"), "micromenu.hide_on_vehicle", R.microVehicle),
    Section(T("Latency Indicator"), true),
    ReloadCheck(T("Show Latency Indicator"), "micromenu.show_latency_indicator"),
} })

E.Register("bagsbar", { compact = true, settings = {
    Slider(T("Scale"), "bags.scale", 0.5, 2.0, 0.01, R.bags),
    ReloadCheck(T("Enable Bagster"), "modules.bagster.enabled", {
        tooltip = T("All-in-one bag replacement with filtering and search") }),
} })

-- ============================================================================
-- DEFINITIONS: PET BAR, STANCE, TOTEM, EXTRA BAR
-- ============================================================================

local function PetBarValue(key, fallback)
    local value = GetDB("additional.pet." .. key)
    if value == nil then value = GetDB("additional." .. key) end
    return tonumber(value) or fallback
end

E.Register("petbar", { settings = {
    Section(T("General"), false),
    Slider(T("Scale"), "additional.pet.scale", 0.5, 2.0, 0.05, R.petbar, { resize = true }),
    Slider(T("Button Size"), "additional.pet.size", 16, 64, 1, R.petbar, {
        resize = true, get = function() return PetBarValue("size", 30) end }),
    Slider(T("Button Spacing"), "additional.pet.spacing", 0, 20, 1, R.petbar, {
        resize = true, get = function() return PetBarValue("spacing", 6) end }),
    Check(T("Show Empty Slots"), "additional.pet.grid", R.petbarGrid),
    Section(T("Text Visibility"), true),
    Check(T("Show Hotkey Text"), "additional.pet.show_hotkey", R.hotkeys),
} })

E.Register("stance", { settings = {
    Slider(T("Button Size"), "additional.stance.button_size", 16, 64, 1, R.stance, { resize = true }),
    Slider(T("Button Spacing"), "additional.stance.button_spacing", 0, 20, 1, R.stance, { resize = true }),
    Check(T("Show Hotkey Text"), "additional.stance.show_hotkey", R.hotkeys),
} })

-- The totem bar falls back to the shared additional.size/spacing, like its Options sliders.
local function TotemValue(key, shared, fallback)
    local value = GetDB("additional.totem." .. key)
    if value == nil then value = GetDB("additional." .. shared) end
    return tonumber(value) or fallback
end

E.Register("totembar", { settings = {
    Slider(T("Button Size"), "additional.totem.button_size", 16, 64, 1, R.multicast, {
        resize = true, get = function() return TotemValue("button_size", "size", 31) end }),
    Slider(T("Button Spacing"), "additional.totem.button_spacing", 0, 20, 1, R.multicast, {
        resize = true, get = function() return TotemValue("button_spacing", "spacing", 6) end }),
    Check(T("Show Hotkey Text"), "additional.totem.show_hotkey", R.hotkeys),
} })

E.Register("extrabar1", { settings = {
    Section(T("General"), false),
    Slider(T("Scale"), "additional.extrabar1.scale", 0.5, 2.0, 0.01, R.extrabar, { resize = true }),
    Slider(T("Button Spacing"), "additional.extrabar1.spacing", 0, 20, 1, R.extrabar, {
        resize = true,
        get = function()
            local value = GetDB("additional.extrabar1.spacing")
            if value == nil then value = 7 end
            return value
        end }),
    Slider(T("Columns"), "additional.extrabar1.columns", 1, 12, 1, R.extrabar, { resize = true }),
    Slider(T("Buttons Shown"), "additional.extrabar1.buttons_shown", 1, 12, 1, R.extrabar, { resize = true }),
    Section(T("Layout"), true),
    Check(T("Change Button Order"), "additional.extrabar1.change_button_order", R.extrabar, {
        after = function() E.Rebuild() end }),
    Drop(T("Button Order"), "additional.extrabar1.button_order", BUTTON_ORDER, R.extrabar, {
        hidden = function() return not GetDB("additional.extrabar1.change_button_order") end }),
    Section(T("Text Visibility"), true),
    Check(T("Show Hotkey Text"), "additional.extrabar1.show_hotkey", R.extrabarHotkeys),
} })

-- ============================================================================
-- DEFINITIONS: MINIMAP, AURAS, TOOLTIP, QUEST TRACKER, LFG EYE
-- ============================================================================

local function SexyMapMode()
    return GetDB("modules.minimap.sexymap_mode")
end

local function DecorationsOff()
    local mode = SexyMapMode()
    return GetDB("minimap.animated_border_enabled") ~= true or mode == "hybrid" or mode == "sexymap"
end

local function NoDecorations()
    return not (addon.MinimapDecorations and addon.MinimapDecorations.Refresh)
end

local function DecorationPresets()
    local decor = addon.MinimapDecorations
    local names = decor and decor.GetPresetList and decor:GetPresetList() or {}
    local ids = {}
    for id in pairs(names) do ids[#ids + 1] = id end
    table.sort(ids)

    local list = {}
    for i = 1, #ids do list[i] = { ids[i], names[ids[i]] } end
    return list
end

-- Mirrors the Options tab: the scale follows the border unless the user has set it by hand.
local function ApplyDecorationAutoScale()
    if GetDB("minimap.animated_border_scale_auto") == false then return end
    local hidden = GetDB("minimap.animated_border_hide_dragonui_border") == true
    SetDB("minimap.animated_border_scale", hidden and 1 or 0.9)
    SetDB("minimap.animated_border_scale_auto", true)
end

-- The Forever ring has no arrow collector, so the collector style is locked to the circle there.
local function ForeverMinimap()
    return GetDB("minimap.style") == "forever" and SexyMapMode() ~= "hybrid"
end

local function CollectorOff()
    return GetDB("minimap.collector_enabled") == false
end

E.Register("minimap", { settings = {
    Section(T("General"), false),
    Slider(T("Scale"), "minimap.scale", 0.5, 2.0, 0.01, R.minimap),
    Drop(T("Style"), "minimap.style", {
        { "dragonui", T("DragonUI") },
        { "forever", T("Forever") },
    }, R.minimap, { after = function() E.Rebuild() end }),
    Section(T("Minimap Buttons Collector"), true),
    Check(T("Enable"), "minimap.collector_enabled", R.minimap, {
        get = function() return GetDB("minimap.collector_enabled") ~= false end,
        after = function() E.Rebuild() end }),
    Drop(T("Style"), "minimap.collector_style", {
        { "dragonui", T("Circle") },
        { "classic", T("Arrow") },
    }, R.minimap, {
        get = function() return ForeverMinimap() and "dragonui" or (GetDB("minimap.collector_style") or "dragonui") end,
        disabled = function() return CollectorOff() or ForeverMinimap() end }),
    Check(T("Addon Button Skin"), "minimap.addon_button_skin", R.minimap),
    Check(T("Addon Button Fade"), "minimap.addon_button_fade", R.minimap),
    Section(T("Basic Settings"), true),
    Slider(T("Border Alpha"), "minimap.border_alpha", 0, 1, 0.1, nil, {
        set = function(value)
            SetDB("minimap.border_alpha", value)
            if MinimapBorderTop then MinimapBorderTop:SetAlpha(value) end
        end }),
    Check(T("New Blip Style"), "minimap.blip_skin", R.minimap),
    Slider(T("Player Arrow Size"), "minimap.player_arrow_size", 8, 50, 1, R.minimap),
    Section(T("Time & Calendar"), true),
    Check(T("Show Clock"), "minimap.clock", R.minimap),
    Slider(T("Clock Font Size"), "minimap.clock_font_size", 8, 20, 1, R.minimap),
    Check(T("Show Calendar"), "minimap.calendar", nil, {
        set = function(value)
            SetDB("minimap.calendar", value)
            if GameTimeFrame then
                if value then GameTimeFrame:Show() else GameTimeFrame:Hide() end
            end
        end }),
    Section(T("Display Settings"), true),
    Check(T("Tracking Icons"), "minimap.tracking_icons", nil, {
        set = function(value)
            SetDB("minimap.tracking_icons", value)
            local module = addon.MinimapModule
            if module and module.UpdateTrackingIcon then module:UpdateTrackingIcon() end
        end }),
    Check(T("Zoom Buttons"), "minimap.zoom_buttons", R.minimap),
    Slider(T("Zone Text Font Size"), "minimap.zonetext_font_size", 8, 20, 1, R.minimap),
    Section(T("Minimap Decorations"), true, NoDecorations),
    Check(T("Enable Minimap Decorations"), "minimap.animated_border_enabled", R.minimapDecor, {
        hidden = NoDecorations,
        set = function(value)
            SetDB("minimap.animated_border_enabled", value)
            if not value then SetDB("minimap.animated_border_hide_dragonui_border", false) end
            Immediate(R.minimapDecor)
            E.Rebuild()
        end }),
    Drop(T("Preset"), "minimap.animated_border_preset", DecorationPresets, R.minimapDecor, {
        hidden = NoDecorations, disabled = DecorationsOff }),
    Check(T("Animated Effects"), "minimap.animated_border_animations", R.minimapDecor, {
        hidden = NoDecorations, disabled = DecorationsOff }),
    Check(T("Hide DragonUI Border"), "minimap.animated_border_hide_dragonui_border", R.minimapDecor, {
        hidden = NoDecorations,
        disabled = DecorationsOff,
        set = function(value)
            SetDB("minimap.animated_border_hide_dragonui_border", value)
            ApplyDecorationAutoScale()
            Immediate(R.minimapDecor)
            E.Rebuild()
        end }),
    Slider(T("Scale"), "minimap.animated_border_scale", 0.5, 2, 0.01, R.minimapDecor, {
        hidden = NoDecorations,
        disabled = DecorationsOff,
        set = function(value)
            SetDB("minimap.animated_border_scale", value)
            SetDB("minimap.animated_border_scale_auto", false)
            Deferred(R.minimapDecor)
        end }),
    Slider(T("Opacity"), "minimap.animated_border_opacity", 0, 1, 0.05, R.minimapDecor, {
        hidden = NoDecorations, disabled = DecorationsOff }),
} })

local function SeparateWeaponEnchantsRow()
    return Check(T("Separate Weapon Enchants"), "buffs.separate_weapon_enchants", nil, {
        set = function(value)
            E.Flush()
            SetDB("buffs.separate_weapon_enchants", value)
            local module = addon.BuffFrameModule
            if module and module.ToggleWeaponEnchantSeparation then
                RunNow(function() module:ToggleWeaponEnchantSeparation(value) end, "weapon_separation")
            end
            E.SyncFrames()
            E.Rebuild()
        end })
end

local function PreviewOff()
    return not GetDB("buffs.layout_preview")
end

local function BordersOff()
    return GetDB("modules.auraborders.enabled") ~= true
end

local function TooltipOff()
    return GetDB("modules.tooltip.enabled") ~= true
end

local function SpellIdRow()
    return Check(T("Show Aura Spell ID"), "modules.tooltip.show_aura_spell_id", nil, {
        get = function() return GetDB("modules.tooltip.show_aura_spell_id") == true end,
        disabled = TooltipOff })
end

E.Register("buffs", { settings = {
    Section(T("General"), false),
    Slider(T("Buff Icon Scale"), "buffs.buff_scale", 0.5, 2, 0.05, R.auras),
    Slider(T("Buffs Per Row"), "buffs.buffs_per_row", 1, 32, 1, R.auras),
    Slider(T("Max Buff Rows"), "buffs.max_buff_rows", 0, 10, 1, R.auras),
    Slider(T("Buff Horizontal Gap"), "buffs.buff_horizontal_gap", 0, 20, 1, R.auras),
    Slider(T("Buff Vertical Gap"), "buffs.buff_vertical_gap", 0, 40, 1, R.auras),
    Section(T("Appearance"), true),
    Drop(T("Buff Order"), "buffs.buff_order", {
        { "blizzard", T("Default (Blizzard)") },
        { "player_first", T("Player Buffs First") },
        { "other_first", T("Other Player Buffs First") },
        { "duration", T("Duration Buffs First") },
    }, R.auras),
    Check(T("Show Toggle Button"), "buffs.show_toggle_button", R.auras),
    SeparateWeaponEnchantsRow(),
    Section(T("Layout Preview"), true),
    Check(T("Enable Layout Preview"), "buffs.layout_preview", R.auras, { after = function() E.Rebuild() end }),
    Slider(T("Preview Buff Count"), "buffs.layout_preview_buffs", 0, 64, 1, R.auras, { hidden = PreviewOff }),
    Section(T("Aura Borders"), true),
    Check(T("Enable Aura Borders"), "modules.auraborders.enabled", R.auraBorders, {
        get = function() return GetDB("modules.auraborders.enabled") == true end,
        after = function() E.Rebuild() end }),
    Drop(T("Border Style"), "modules.auraborders.border_style", {
        { "detailed", T("Detailed") },
        { "rounded", T("Rounded") },
        { "square", T("Square") },
    }, R.auraBorders, { disabled = BordersOff }),
    Section(T("Aura Tooltips"), true),
    SpellIdRow(),
} })

E.Register("Debuffs", { settings = {
    Section(T("General"), false),
    Check(T("Show Debuffs"), "buffs.show_debuffs", R.auras),
    Slider(T("Debuff Icon Scale"), "buffs.debuff_scale", 0.5, 2, 0.05, R.auras),
    Slider(T("Debuffs Per Row"), "buffs.debuffs_per_row", 1, 32, 1, R.auras),
    Slider(T("Max Debuff Rows"), "buffs.max_debuff_rows", 0, 10, 1, R.auras),
    Slider(T("Debuff Horizontal Gap"), "buffs.debuff_horizontal_gap", 0, 20, 1, R.auras),
    Slider(T("Debuff Vertical Gap"), "buffs.debuff_vertical_gap", 0, 40, 1, R.auras),
    Slider(T("Debuff Attached Offset Y"), "buffs.debuff_offset_y", 0, 120, 1, R.auras, {
        hidden = function() return GetDB("widgets.debuffs.custom_position") == true end }),
    Section(T("Layout Preview"), true),
    Check(T("Enable Layout Preview"), "buffs.layout_preview", R.auras, { after = function() E.Rebuild() end }),
    Slider(T("Preview Debuff Count"), "buffs.layout_preview_debuffs", 0, 40, 1, R.auras, { hidden = PreviewOff }),
} })

E.Register("weapon_enchants", { settings = { SeparateWeaponEnchantsRow() } })

-- The tooltip hooks read these on every tooltip, so a plain write is all Options does too.
local function TooltipSwitch(labelKey, field)
    local path = "modules.tooltip." .. field
    return Check(labelKey, path, nil, {
        get = function() return GetDB(path) ~= false end,
        disabled = TooltipOff })
end

E.Register("tooltip", { settings = {
    Section(T("General"), false),
    Check(T("Anchor to Cursor"), "modules.tooltip.anchor_cursor", nil, {
        get = function() return GetDB("modules.tooltip.anchor_cursor") == true end,
        set = function(value)
            SetDB("modules.tooltip.anchor_cursor", value)
            E.SyncFrames()
            E.Rebuild()
        end,
        disabled = TooltipOff }),
    Section(T("Tooltip"), true),
    TooltipSwitch(T("Class-Colored Border"), "class_colored_border"),
    TooltipSwitch(T("Class-Colored Name"), "class_colored_name"),
    TooltipSwitch(T("Target of Target"), "target_of_target"),
    TooltipSwitch(T("Styled Health Bar"), "health_bar"),
    TooltipSwitch(T("Show Aura Source"), "show_aura_source"),
    SpellIdRow(),
} })

E.Register("questtracker", { settings = {
    Check(T("Show Header Background"), "questtracker.show_header", R.quest, {
        get = function() return GetDB("questtracker.show_header") ~= false end }),
    Slider(T("Font Size"), "questtracker.font_size", 8, 18, 1, R.quest, { resize = true }),
    Check(T("Custom Height"), "questtracker.custom_height", R.quest, {
        get = function() return GetDB("questtracker.custom_height") == true end,
        after = function() E.Rebuild() end }),
    Slider(T("Height"), "questtracker.height", 400, 1000, 10, R.quest, {
        resize = true,
        disabled = function() return GetDB("questtracker.custom_height") ~= true end }),
} })

local LFG_POSITIONS = { TOP = true, BOTTOM = true, LEFT = true, RIGHT = true }

E.Register("lfgframe", { settings = {
    Drop(T("Status Tooltip:"), "widgets.lfgframe.tooltip_position", {
        { "TOP", T("Top") },
        { "BOTTOM", T("Bottom") },
        { "LEFT", T("Left") },
        { "RIGHT", T("Right") },
    }, nil, {
        get = function()
            local position = GetDB("widgets.lfgframe.tooltip_position")
            return LFG_POSITIONS[position] and position or "TOP"
        end,
        set = function(value)
            if not LFG_POSITIONS[value] then return end
            SetDB("widgets.lfgframe.tooltip_position", value)
            if addon.ReanchorLFDSearchStatus then addon.ReanchorLFDSearchStatus() end
        end }),
} })

-- ============================================================================
-- DEFINITIONS: EDITOR MANAGER (global settings, not tied to one frame)
-- ============================================================================

local function ModuleField(module, field)
    return GetDB("modules." .. module .. "." .. field)
end

local function NoDarkMode() return not addon.ApplyDarkMode end
local function NoButtons() return not addon.RefreshButtons end
local function NoCooldowns() return not addon.RefreshCooldowns end

local function DarkOff()
    return ModuleField("darkmode", "enabled") ~= true
end

-- Options keeps the font size in two places; the second one is what the hotkey styling reads.
local function SyncHotkeyFontSize()
    local hotkey = GetDB("buttons.hotkey")
    if type(hotkey) == "table" and type(hotkey.font) == "table" then
        hotkey.font[2] = hotkey.font_size or hotkey.font[2] or 12
    end
end

local function TintColorRow()
    local base = "modules.darkmode.custom_color."
    return ColorRow(T("Color"), {
        key = "modules.darkmode.custom_color",
        hidden = NoDarkMode,
        get = function()
            return { GetNumber(base .. "r", 0.15), GetNumber(base .. "g", 0.15), GetNumber(base .. "b", 0.15), 1 }
        end,
        set = function(r, g, b)
            SetDB(base .. "r", r)
            SetDB(base .. "g", g)
            SetDB(base .. "b", b)
            Deferred(R.darkmode)
        end,
        disabled = function() return DarkOff() or ModuleField("darkmode", "use_custom_color") ~= true end })
end

local function RightBarOn()
    return GetDB("actionbars.right_enabled") ~= false
end

local function ForeverLevelStyle()
    return not not (addon.UF and addon.UF.GetLevelStyle and addon.UF.GetLevelStyle() == "forever")
end

local function CooldownOff()
    return ModuleField("cooldowns", "enabled") ~= true
end

local function CooldownColorRow()
    return ColorRow(T("Color"), {
        key = "buttons.cooldown.color",
        hasAlpha = true,
        hidden = NoCooldowns,
        disabled = CooldownOff,
        get = function()
            local saved = GetDB("buttons.cooldown.color")
            local color = { 1, 1, 1, 1 }
            if type(saved) == "table" then
                for i = 1, 4 do color[i] = tonumber(saved[i]) or color[i] end
            end
            return color
        end,
        set = function(r, g, b, a)
            SetDB("buttons.cooldown.color", { r, g, b, a })
            Deferred(R.cooldowns)
        end })
end

E.Register("__manager", { settings = {
    Section(T("Dark Mode"), true, NoDarkMode),
    Check(T("Enable Dark Mode"), "modules.darkmode.enabled", nil, {
        hidden = NoDarkMode,
        get = function() return ModuleField("darkmode", "enabled") == true end,
        set = function(value)
            E.Flush()
            SetDB("modules.darkmode.enabled", value)
            RunNow(function()
                if value then
                    if addon.ApplyDarkMode then addon.ApplyDarkMode(true) end
                elseif addon.RestoreDarkMode then
                    addon.RestoreDarkMode(true)
                end
            end, "darkmode_toggle")
            E.PromptReload()
            E.Rebuild()
        end }),
    Drop(T("Intensity"), "modules.darkmode.intensity_preset", {
        { 1, T("Light (subtle)") },
        { 2, T("Medium (balanced)") },
        { 3, T("Dark (maximum)") },
    }, R.darkmode, {
        hidden = NoDarkMode,
        get = function() return tonumber(ModuleField("darkmode", "intensity_preset")) or 3 end,
        disabled = function() return DarkOff() or ModuleField("darkmode", "use_custom_color") == true end }),
    Check(T("Custom Color"), "modules.darkmode.use_custom_color", R.darkmode, {
        hidden = NoDarkMode,
        get = function() return ModuleField("darkmode", "use_custom_color") == true end,
        disabled = DarkOff,
        after = function() E.Rebuild() end }),
    TintColorRow(),

    Section(T("Unit Frame Appearance"), true),
    Drop(T("Unit Frame Art"), "unitframe.frame_style", {
        { "dragonui", T("DragonUI") },
        { "forever", T("Forever") },
    }, R.skins, { after = function() E.Rebuild() end }),
    Drop(T("Elite Dragons"), "unitframe.dragon_style", STYLE_ITEMS, R.skins),
    Check(T("Center Names"), "unitframe.center_names", R.skins, {
        hidden = function() return not ForeverLevelStyle() end }),

    Section(T("Action Bars"), true),
    Check(T("Bottom Left Bar"), "actionbars.bottom_left_enabled", R.barToggle),
    Check(T("Bottom Right Bar"), "actionbars.bottom_right_enabled", R.barToggle),
    Check(T("Right Bar"), "actionbars.right_enabled", R.barToggle, {
        set = function(value)
            SetDB("actionbars.right_enabled", value)
            -- Blizzard greys the left bar out and turns it off with the right one.
            if not value then SetDB("actionbars.left_enabled", false) end
            Immediate(R.barToggle)
        end }),
    Check(T("Left Bar"), "actionbars.left_enabled", R.barToggle, {
        get = function() return GetDB("actionbars.left_enabled") ~= false and RightBarOn() end,
        disabled = function() return not RightBarOn() end }),
    Check(T("Extra Bar"), "modules.extrabar1.enabled", R.extrabarToggle, {
        tooltip = T("A 12-button action bar independent of every class's bonus bar (stance/stealth/vehicle)."),
        after = function() E.SyncFrames(); E.Rebuild() end }),

    Section(T("Button Appearance"), true, NoButtons),
    Check(T("Main Bar Only Background"), "buttons.only_actionbackground", R.buttons, { hidden = NoButtons }),
    ReloadCheck(T("Hide Main Bar Background"), "buttons.hide_main_bar_background", { hidden = NoButtons }),
    Drop(T("Button Tooltips"), "buttons.tooltips", {
        { "always", T("Always") },
        { "combat", T("Hide in Combat") },
        { "never", T("Never") },
    }, nil, { hidden = NoButtons }),
    Check(T("Show Count Text"), "buttons.count.show", R.buttons, { hidden = NoButtons }),
    Check(T("Show Hotkey Text"), "buttons.hotkey.show", R.buttons, { hidden = NoButtons }),
    Check(T("Show Macro Names"), "buttons.macros.show", R.buttons, { hidden = NoButtons }),
    Slider(T("Hotkey Font Size"), "buttons.hotkey.font_size", 8, 24, 1, R.hotkeyStyle, {
        hidden = NoButtons,
        set = function(value)
            SetDB("buttons.hotkey.font_size", value)
            SyncHotkeyFontSize()
            Deferred(R.hotkeyStyle)
        end }),

    SubSection(T("Cooldown Text"), true, NoCooldowns),
    Check(T("Show Cooldown Text"), "modules.cooldowns.enabled", R.cooldowns, {
        hidden = NoCooldowns,
        get = function() return ModuleField("cooldowns", "enabled") == true end,
        after = function() E.Rebuild() end }),
    Slider(T("Min Duration"), "buttons.cooldown.min_duration", 1, 10, 1, R.cooldowns, {
        hidden = NoCooldowns, disabled = CooldownOff }),
    Slider(T("Font Size"), "buttons.cooldown.font_size", 8, 24, 1, R.cooldowns, {
        hidden = NoCooldowns, disabled = CooldownOff }),
    CooldownColorRow(),
} })

-- Every frame the shared hover/combat engine fades gets the same folded group.
local function Fades(frameName, field, refresh, o)
    Append(frameName, VisibilityRows(field, refresh, o))
end

for frameName, keys in pairs({
    mainbar = "actionbars.main", rightbar = "actionbars.right", leftbar = "actionbars.left",
    bottombarleft = "actionbars.bottom_left", bottombarright = "actionbars.bottom_right",
}) do
    Fades(frameName, Underscored(keys), R.barVisibility, { hideInCombat = true })
end
Fades("micromenu", Underscored("actionbars.micro"), R.barVisibility, { alwaysHidden = true, hideInCombat = true })
Fades("bagsbar", Underscored("actionbars.bag"), R.bagVisibility, { alwaysHidden = true, hideInCombat = true })
Fades("extrabar1", Dotted("additional.extrabar1"), R.extrabarVisibility)
Fades("stance", Dotted("additional.stance"), R.stance)
Fades("petbar", Dotted("additional.pet"), R.petbar)
Fades("totembar", Dotted("additional.totem"), R.multicast)
Fades("xpbar", Dotted("xprepbar"), R.xprep, { hideInCombat = true })
Fades("repbar", Dotted("xprepbar"), R.xprep, { hideInCombat = true })
Fades("minimap", Dotted("minimap"), R.minimapVisibility, { hideInCombat = true })
Fades("questtracker", Dotted("questtracker"), R.questVisibility, { hideInCombat = true })
Fades("player", Dotted("unitframe.player"), R.player)
Fades("target", Dotted("unitframe.target"), R.target)
Fades("focus", Dotted("unitframe.focus"), R.focus)
Fades("PetFrame", Dotted("unitframe.pet"), R.pet)
Fades("party", Dotted("unitframe.party"), R.partyVisibility)
Fades("boss", Dotted("unitframe.boss"), R.boss)

-- Dialogs with few settings and no wide dropdowns shrink to the width of their coordinate rows.
for _, frameName in ipairs({
    "boss", "bagsbar", "stance", "totembar", "xpbar", "repbar", "tooltip", "questtracker",
    "weapon_enchants", "tot", "fot", "petbar",
}) do
    local def = E.Get(frameName)
    if def then def.compact = true end
end

-- The language override is only readable after AceDB exists, so labels resolved at load can be stale.
function E.RefreshLabels()
    for _, def in pairs(E.frames) do
        for _, row in ipairs(def.settings) do
            if row.labelKey then row.label = Label(row.labelKey) end
            if row.tooltipKey then row.tooltip = Label(row.tooltipKey) end
            if type(row.items) == "table" then
                for _, item in ipairs(row.items) do
                    if item.textKey then item.text = ItemText(item) end
                end
            end
        end
    end

    if StaticPopupDialogs and StaticPopupDialogs[RELOAD_POPUP] then
        StaticPopupDialogs[RELOAD_POPUP] = BuildReloadPopup()
    end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

local function OnProfileChanged()
    addon:After(0.3, function()
        if EditorActive() then
            E.SyncFrames()
            E.Rebuild()
        end
    end)
end

local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("PLAYER_REGEN_ENABLED")
lifecycle:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if needsSync and EditorActive() then E.SyncFrames() end
        return
    end

    E.RefreshLabels()
    for i = 1, #RELOAD_PATHS do CaptureSessionValue(RELOAD_PATHS[i]) end

    if type(addon.HideAllEditableFrames) == "function" then
        hooksecurefunc(addon, "HideAllEditableFrames", function() E.OnEditorClose() end)
    end

    local db = addon.db
    if db and db.RegisterCallback then
        db.RegisterCallback(E, "OnProfileChanged", OnProfileChanged)
        db.RegisterCallback(E, "OnProfileCopied", OnProfileChanged)
        db.RegisterCallback(E, "OnProfileReset", OnProfileChanged)
    end
end)
