-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Reload-only changes are staged, never saved early, so the saved settings always describe what is running.
local Reload = {}
addon.Reload = Reload

local POPUP = "DRAGONUI_RELOAD_PENDING"

local staged = {}
local order = {}
local discardListeners = {}

local function Report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function Walk(root, path)
    local value = root
    for key in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[key]
    end
    return value
end

local function Root(scope)
    local db = addon.db
    if not db then return nil end
    if scope == "global" then return db.global end
    return db.profile
end

local function Saved(path, scope)
    local value = Walk(Root(scope), path)
    if value == nil and scope ~= "global" then
        value = Walk(addon.defaults and addon.defaults.profile, path)
    end
    return value
end

local function Write(path, value, scope)
    local node = Root(scope)
    if not node then return end
    local keys = { strsplit(".", path) }
    for i = 1, #keys - 1 do
        if type(node[keys[i]]) ~= "table" then node[keys[i]] = {} end
        node = node[keys[i]]
    end
    node[keys[#keys]] = value
end

-- A checkbox reports false where the profile may hold nil; both mean "off".
local function Same(a, b)
    return a == b or (not a and not b)
end

local function Put(key, entry)
    if not staged[key] then order[#order + 1] = key end
    staged[key] = entry
end

local function Drop(key)
    if not staged[key] then return end
    staged[key] = nil
    for i = #order, 1, -1 do
        if order[i] == key then table.remove(order, i) end
    end
end

local function Clear(fromPopup)
    wipe(staged)
    wipe(order)
    if not fromPopup and StaticPopup_Visible(POPUP) then StaticPopup_Hide(POPUP) end
    for i = 1, #discardListeners do
        local ok, err = pcall(discardListeners[i])
        if not ok then Report(err) end
    end
end

local function Dialog()
    local L = addon.L
    return {
        text = L["Changing this setting requires a UI reload to apply correctly."],
        button1 = L["Reload Now"],
        button2 = CANCEL,
        OnAccept = function()
            Reload.Commit()
            ReloadUI()
        end,
        -- Button, Esc and logout all land here; OnHide also fires when Alt+Z hides UIParent, so it can't discard.
        OnCancel = function() Clear(true) end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        noCancelOnReuse = 1,
        preferredIndex = 3,
    }
end

-- Re-showing a visible StaticPopup cancels and hides it first, so it is only shown when it isn't up.
local function Sync()
    if next(staged) then
        if StaticPopup_Visible(POPUP) then return end
        StaticPopupDialogs[POPUP] = Dialog()
        -- No free popup slot means nothing could ever commit this stage, so it must not linger.
        if not StaticPopup_Show(POPUP) then Clear() end
    elseif StaticPopup_Visible(POPUP) then
        StaticPopup_Hide(POPUP)
    end
end

local function ProfileKey(path, scope)
    return (scope or "profile") .. ":" .. path
end

-- `scope` is nil for the profile or "global" for db.global; staging the saved value unstages it.
function Reload.Stage(path, value, scope)
    local key = ProfileKey(path, scope)
    if Same(value, Saved(path, scope)) then
        Drop(key)
    else
        Put(key, { path = path, scope = scope, value = value })
    end
    Sync()
end

function Reload.Get(path, scope)
    local entry = staged[ProfileKey(path, scope)]
    if entry then return entry.value end
    return Saved(path, scope)
end

function Reload.IsStaged(path, scope)
    return staged[ProfileKey(path, scope)] ~= nil
end

local function Running(name)
    local registry = addon.ModuleRegistry
    return registry and registry:IsEnabled(name) and true or false
end

function Reload.StageModule(name, enabled)
    local key = "module:" .. name
    enabled = enabled and true or false
    if enabled == Running(name) then
        Drop(key)
    else
        Put(key, { module = name, value = enabled })
    end
    Sync()
end

-- What a module toggle should show: the staged choice, else the state that is running.
function Reload.ModuleState(name)
    local entry = staged["module:" .. name]
    if entry then return entry.value end
    return Running(name)
end

-- Actions (profile switches) run on commit after every staged value, so those land in the profile they were made in.
function Reload.StageAction(key, fn)
    Put("action:" .. key, { action = fn })
    Sync()
end

function Reload.UnstageAction(key)
    Drop("action:" .. key)
    Sync()
end

function Reload.HasStaged()
    return next(staged) ~= nil
end

function Reload.Discard()
    Clear()
end

function Reload.OnDiscard(fn)
    discardListeners[#discardListeners + 1] = fn
end

function Reload.Commit()
    local registry = addon.ModuleRegistry
    local actions = {}
    for i = 1, #order do
        local entry = staged[order[i]]
        if entry.action then
            actions[#actions + 1] = entry.action
        elseif entry.module then
            local paths = registry and registry:GetEnabledPaths(entry.module)
                or { "modules." .. entry.module .. ".enabled" }
            for j = 1, #paths do Write(paths[j], entry.value) end
        else
            Write(entry.path, entry.value, entry.scope)
        end
    end
    wipe(staged)
    wipe(order)
    for i = 1, #actions do
        local ok, err = pcall(actions[i])
        if not ok then Report(err) end
    end
end
