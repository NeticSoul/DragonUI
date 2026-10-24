-- Run from the repository root with Lua 5.1.
local loaded = {}
local frames = {}
function IsAddOnLoaded(name) return loaded[name] or false end
function GetNumAddOns() return 0 end
function GetAddOnInfo() return nil end
function GetCVar() return nil end
function CreateFrame()
    local frame = { scripts = {}, events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    frames[#frames + 1] = frame
    return frame
end
StaticPopupDialogs, SlashCmdList = {}, {}
local printed = {}
function print(text) printed[#printed + 1] = text end

-- Bartender4's AceAddon modules as its OnInitialize leaves them: state set, not yet enabled.
local function newBartenderModule(enabled)
    local module = { db = { profile = { enabled = enabled } }, enabledState = enabled, live = false }
    function module:SetEnabledState(state) self.enabledState = state end
    function module:IsEnabled() return self.live end
    function module:Disable() self.live = false end
    function module:ToggleModule(info, value)
        if value ~= nil then self.db.profile.enabled = value end
        self.live = self.db.profile.enabled
    end
    return module
end
local bartenderModules = {
    MicroMenu = newBartenderModule(true),
    BagBar = newBartenderModule(true),
    PetBar = newBartenderModule(true),
    XPBar = newBartenderModule(true),
    RepBar = newBartenderModule(false),
}
Bartender4 = { GetModule = function(_, name) return bartenderModules[name] end }

local HANDED = { "vehicle", "stance", "petbar", "multicast", "buttons" }
local KEPT = { "mainbars", "noop", "micromenu", "keypress", "minimap" }

local function newProfile()
    local modules = {}
    for _, name in ipairs(HANDED) do modules[name] = { enabled = true } end
    for _, name in ipairs(KEPT) do modules[name] = { enabled = true } end
    return { modules = modules, compatibility = { bartender_bars = true } }
end

local function newAddon()
    local addon = {
        db = { profile = newProfile() },
        L = setmetatable({}, { __index = function(_, key) return key end }),
        After = function() end,
    }
    function addon:IsModuleEnabled(name)
        local cfg = self.db.profile.modules[name]
        return cfg and cfg.enabled or false
    end
    frames = {}
    assert(loadfile('DragonUI/modules/compatibility.lua'))('DragonUI', addon)
    return addon
end

local function login()
    printed = {}
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_LOGIN then frame.scripts.OnEvent(frame, 'PLAYER_LOGIN') end
    end
    for _, text in ipairs(printed) do
        if text:find('Bartender4', 1, true) then return true end
    end
    return false
end

-- Without Bartender4 nothing changes, and Bartender4's own modules are left alone.
local addon = newAddon()
local compat, modules, cfg = addon.compatibility, addon.db.profile.modules, addon.db.profile.compatibility
compat:ApplyBartenderHandoff()
assert(compat.bartenderActive == false)
for _, name in ipairs(HANDED) do assert(modules[name].enabled, name .. ' changed without Bartender4') end
assert(cfg.bartender_handed == nil)
assert(not login(), 'login line without Bartender4')

-- With Bartender4: the bars go to it, the XP bars (mainbars, noop), micro menu and key press stay.
loaded.Bartender4 = true
addon = newAddon()
compat, modules, cfg = addon.compatibility, addon.db.profile.modules, addon.db.profile.compatibility
compat:ApplyBartenderHandoff()
assert(compat.bartenderActive == true)
for _, name in ipairs(HANDED) do assert(modules[name].enabled == false, name .. ' still on with Bartender4') end
for _, name in ipairs(KEPT) do assert(modules[name].enabled, name .. ' was switched off') end
for _, name in ipairs(HANDED) do assert(cfg.bartender_handed[name]) end
assert(login(), 'no login line on the load that handed the bars over')

-- Bartender4's micro menu, bag bar and XP/Rep bars stay off without touching its saved settings;
-- its pet bar is untouched.
local micro, bags = bartenderModules.MicroMenu, bartenderModules.BagBar
assert(micro.enabledState == false and bags.enabledState == false)
assert(bartenderModules.XPBar.enabledState == false and bartenderModules.RepBar.enabledState == false)
assert(micro.db.profile.enabled and bags.db.profile.enabled, 'Bartender4 settings were changed')
assert(bartenderModules.PetBar.enabledState == true)
micro:ToggleModule()             -- Bartender4 profile switch
micro:ToggleModule(nil, true)    -- its options checkbox
assert(not micro:IsEnabled(), 'Bartender4 micro menu came back')
assert(micro.db.profile.enabled == true)

-- A later RefreshConfig (profile switch) keeps the load's decision.
cfg.bartender_bars = false
compat:ApplyBartenderHandoff()
assert(compat.bartenderActive == true, 'active state changed mid-session')
assert(modules.stance.enabled == false, 'bars restored mid-session, over Bartender4')
assert(cfg.bartender_handed.stance, 'hand-off record dropped before the next load')
cfg.bartender_bars = true

-- The next load finds nothing new to hand over and stays quiet.
local savedProfile = addon.db.profile
addon = newAddon()
addon.db.profile = savedProfile
compat, modules, cfg = addon.compatibility, savedProfile.modules, savedProfile.compatibility
compat:ApplyBartenderHandoff()
assert(cfg.bartender_handed.stance and cfg.bartender_handed.buttons)
assert(not login(), 'login line repeated on a load that changed nothing')

-- Bartender4 removed: the handed modules come back.
loaded.Bartender4 = false
addon = newAddon()
addon.db.profile = savedProfile
addon.compatibility:ApplyBartenderHandoff()
for _, name in ipairs(HANDED) do assert(modules[name].enabled, name .. ' not restored') end
assert(cfg.bartender_handed == nil)

-- Opting out with Bartender4 loaded also restores DragonUI's bars.
loaded.Bartender4 = true
addon = newAddon()
addon.db.profile = savedProfile
addon.compatibility:ApplyBartenderHandoff()
assert(modules.stance.enabled == false)
cfg.bartender_bars = false
addon = newAddon()
addon.db.profile = savedProfile
assert(not addon.compatibility:BartenderOwnsBars())
addon.compatibility:ApplyBartenderHandoff()
assert(addon.compatibility.bartenderActive == false)
assert(modules.stance.enabled and modules.buttons.enabled)
assert(cfg.bartender_handed == nil)

-- A bar the player turned off before Bartender4 arrived stays off after it leaves.
cfg.bartender_bars = true
modules.stance.enabled = false
addon = newAddon()
addon.db.profile = savedProfile
addon.compatibility:ApplyBartenderHandoff()
assert(not cfg.bartender_handed.stance)
loaded.Bartender4 = false
addon = newAddon()
addon.db.profile = savedProfile
addon.compatibility:ApplyBartenderHandoff()
assert(modules.stance.enabled == false and modules.petbar.enabled)

-- With DragonUI's micro menu or main bars module off, Bartender4 keeps its own micro menu or XP bar.
loaded.Bartender4 = true
bartenderModules.MicroMenu = newBartenderModule(true)
bartenderModules.XPBar = newBartenderModule(true)
local profile = newProfile()
profile.modules.micromenu.enabled = false
profile.modules.mainbars.enabled = false
addon = newAddon()
addon.db.profile = profile
addon.compatibility:ApplyBartenderHandoff()
assert(bartenderModules.MicroMenu.enabledState == true, 'Bartender4 micro menu blocked with no DragonUI one')
assert(bartenderModules.XPBar.enabledState == true, 'Bartender4 XP bar blocked with no DragonUI one')

io.write('bartender hand-off test passed\n')
