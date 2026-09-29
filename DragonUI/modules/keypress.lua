-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Key-down casting technique inspired by SnowfallKeyPress (Dayn).

local addon = select(2, ...)

local _G = _G
local type, select, pairs, ipairs = type, select, pairs, ipairs
local pcall, error, tonumber, tostring = pcall, error, tonumber, tostring
local floor = math.floor
local strmatch, strsub, strchar, gmatch = string.match, string.sub, string.char, string.gmatch

local PROXY_PREFIX = "DragonUI_KeyPressButton_"
local EXTRA_BAR_PREFIX = "DragonUI_ExtraBarButton"
local FLASH_SECONDS = 0.12

local SLOT_ATTR = "dragonui-slot"
local CAP_ATTR = "dragonui-vehiclecap"
local TOTEM_ATTR = "dragonui-totemid"

local STALE_ATTRS = { "type", "clickbutton", "macro", "macrotext", "spell", "item", SLOT_ATTR, CAP_ATTR, TOTEM_ATTR }

local FRAME_REFS = {
    vehiclebar = "VehicleMenuBar",
    bonusbar = "BonusActionBarFrame",
    totemcall = "MultiCastSummonSpellButton",
}

local NAMED_KEYS = [[
    UP DOWN LEFT RIGHT HOME END PAGEUP PAGEDOWN INSERT DELETE
    BACKSPACE ENTER ESCAPE TAB SPACE PAUSE NUMLOCK SCROLLLOCK
    NUMPADDECIMAL NUMPADDIVIDE NUMPADMINUS NUMPADMULTIPLY NUMPADPLUS
]]

local ALLOWED_CLICK_TYPES = {}
for word in gmatch("actionbar action pet multispell spell item macro cancelaura stop target focus assist"
    .. " maintank mainassist", "%S+") do
    ALLOWED_CLICK_TYPES[word] = true
end

local CLICK_FAMILIES = {
    SHAPESHIFTBUTTON = "ShapeshiftButton",
    BONUSACTIONBUTTON = "PetActionButton",
}
for bar, family in ipairs({ "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton" }) do
    CLICK_FAMILIES["MULTIACTIONBAR" .. bar .. "BUTTON"] = family
end

local DIRECT_VERBS = { MACRO = "macro", SPELL = "spell", ITEM = "item" }

local EXPOSE_REFS = [[
    vehicleBar = self:GetFrameRef("vehiclebar")
    bonusBar = self:GetFrameRef("bonusbar")
    totemCall = self:GetFrameRef("totemcall")
]]

local ROUTE_SLOT = [[
    local slot = self:GetAttribute("dragonui-slot")
    if not slot then return end
    local family = "ActionButton"
    if vehicleBar and vehicleBar:IsProtected() and vehicleBar:IsShown()
        and slot <= self:GetAttribute("dragonui-vehiclecap") then
        family = "VehicleMenuBarActionButton"
    elseif bonusBar and bonusBar:IsProtected() and bonusBar:IsShown() then
        family = "BonusActionButton"
    end
    self:SetAttribute("macrotext", "/click " .. family .. slot)
]]

local TOTEM_BEFORE = [[
    local wanted = self:GetAttribute("dragonui-totemid")
    if totemCall and wanted then
        local previous = totemCall:GetID()
        totemCall:SetID(wanted)
        return nil, previous
    end
]]

local TOTEM_AFTER = [[
    if totemCall then totemCall:SetID(message) end
]]

local KeyPressModule = { initialized = false, applied = false }
local active = false
local hooked = false
local selfInitiated = false

local keyList, keySet
local proxies = {}
local wrapped = {}
local flashDeadline = {}

local owner = CreateFrame("Frame")
local flashTimer = CreateFrame("Frame")
flashTimer:Hide()

local function EnsureKeyList()
    if keyList then return end
    local bases = {}
    for code = 65, 90 do bases[#bases + 1] = strchar(code) end
    for digit = 0, 9 do
        bases[#bases + 1] = tostring(digit)
        bases[#bases + 1] = "NUMPAD" .. digit
    end
    for f = 1, 12 do bases[#bases + 1] = "F" .. f end
    for mouse = 3, 5 do bases[#bases + 1] = "BUTTON" .. mouse end
    for glyph in gmatch("`-=[]\\;',./", ".") do bases[#bases + 1] = glyph end
    for word in gmatch(NAMED_KEYS, "%S+") do bases[#bases + 1] = word end

    keyList, keySet = {}, {}
    for mask = 0, 7 do
        local mods = (mask % 2 == 1 and "ALT-" or "")
            .. (floor(mask / 2) % 2 == 1 and "CTRL-" or "")
            .. (mask >= 4 and "SHIFT-" or "")
        for i = 1, #bases do
            local key = mods .. bases[i]
            keyList[#keyList + 1] = key
            keySet[key] = true
        end
    end
end

local function IsConfiguredOn()
    local cfg = addon.GetModuleConfig and addon:GetModuleConfig("keypress")
    return type(cfg) == "table" and cfg.enabled == true
end

local function CallQuietly(api, ...)
    selfInitiated = true
    local ok, err = pcall(api, ...)
    selfInitiated = false
    if not ok then error(err, 0) end
end

local function CurrentSlotButton(slot)
    local vehicle, bonus = _G.VehicleMenuBar, _G.BonusActionBarFrame
    if vehicle and vehicle:IsProtected() and vehicle:IsShown() and slot <= (VEHICLE_MAX_ACTIONBUTTONS or 6) then
        return _G["VehicleMenuBarActionButton" .. slot]
    elseif bonus and bonus:IsProtected() and bonus:IsShown() then
        return _G["BonusActionButton" .. slot]
    end
    return _G["ActionButton" .. slot]
end

local function StartFlash(button)
    button:SetButtonState("PUSHED")
    flashDeadline[button] = GetTime() + FLASH_SECONDS
    flashTimer:Show()
end

flashTimer:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local waiting = false
    for button, deadline in pairs(flashDeadline) do
        if now < deadline then
            waiting = true
        else
            flashDeadline[button] = nil
            button:SetButtonState("NORMAL")
            if button:GetAttribute("action") ~= nil and ActionButton_UpdateState then
                ActionButton_UpdateState(button)
            end
        end
    end
    if not waiting then self:Hide() end
end)

-- Override clicks skip Blizzard's keyboard "pushed" state, so the bar button is flashed by hand.
local function OnProxyClicked(proxy)
    if not active then return end
    local slot = proxy:GetAttribute(SLOT_ATTR)
    local target
    if slot then
        target = CurrentSlotButton(slot)
    else
        target = proxy:GetAttribute("clickbutton")
    end
    if not target or not target.SetButtonState then return end
    local name = target:GetName()
    if name and strsub(name, 1, #EXTRA_BAR_PREFIX) == EXTRA_BAR_PREFIX then return end
    StartFlash(target)
end

local function TypeIsAllowed(target, button)
    local kind = SecureButton_GetModifiedAttribute(target, "type", button)
    return kind == nil or ALLOWED_CLICK_TYPES[kind] == true
end

local function CanDriveClick(target, mouse)
    if type(target) ~= "table" or type(target.IsObjectType) ~= "function" then return false end
    if not issecurevariable(target, "IsObjectType") then return false end
    if not target:IsObjectType("Button") then return false end
    if not select(2, target:IsProtected()) then return false end
    if target:GetAttribute("", "downbutton", mouse) then return false end
    local harm = SecureButton_GetModifiedAttribute(target, "harmbutton", mouse)
    local help = SecureButton_GetModifiedAttribute(target, "helpbutton", mouse)
    return TypeIsAllowed(target, mouse) and TypeIsAllowed(target, harm) and TypeIsAllowed(target, help)
end

local function Interpret(command)
    local verb, rest = strmatch(command, "^(%u+) (.+)$")
    if verb == "CLICK" then
        local frameName, mouse = strmatch(rest, "^(.+):([^:]+)$")
        local target = frameName and _G[frameName]
        if mouse and CanDriveClick(target, mouse) then
            return "click", target, mouse
        end
        return nil
    elseif verb and DIRECT_VERBS[verb] then
        return DIRECT_VERBS[verb], rest
    end

    if command == "MULTICASTRECALLBUTTON1" then
        return "click", _G.MultiCastRecallSpellButton
    end
    local stem, digits = strmatch(command, "^(.-)(%d+)$")
    if not stem then return nil end
    if stem == "ACTIONBUTTON" then
        return "slot", tonumber(digits)
    elseif stem == "MULTICASTSUMMONBUTTON" then
        return "totem", tonumber(digits)
    elseif CLICK_FAMILIES[stem] then
        return "click", _G[CLICK_FAMILIES[stem] .. digits]
    end
    return nil
end

local function GetProxy(key)
    local proxy = proxies[key]
    if proxy then return proxy end

    proxy = CreateFrame("Button", PROXY_PREFIX .. key, nil, "SecureActionButtonTemplate")
    proxy:RegisterForClicks("AnyDown")
    for label, globalName in pairs(FRAME_REFS) do
        local ref = _G[globalName]
        if ref then SecureHandlerSetFrameRef(proxy, label, ref) end
    end
    SecureHandlerExecute(proxy, EXPOSE_REFS)
    -- Hooked before any wrap, so each wrap saves and later restores the hooked handler.
    proxy:HookScript("OnClick", OnProxyClicked)
    proxies[key] = proxy
    return proxy
end

local function ResetProxy(proxy)
    if wrapped[proxy] then
        SecureHandlerUnwrapScript(proxy, "OnClick")
        wrapped[proxy] = nil
    end
    -- A leftover "macro" attribute outranks "macrotext" in SECURE_ACTIONS.macro.
    for i = 1, #STALE_ATTRS do
        proxy:SetAttribute(STALE_ATTRS[i], nil)
    end
end

local function WrapProxy(proxy, before, after)
    SecureHandlerWrapScript(proxy, "OnClick", proxy, before, after)
    wrapped[proxy] = true
end

local function Accelerate(key, command)
    local kind, payload, mouse = Interpret(command)
    if not kind then return end

    local proxy = GetProxy(key)
    ResetProxy(proxy)
    if kind == "slot" then
        proxy:SetAttribute("type", "macro")
        proxy:SetAttribute(SLOT_ATTR, payload)
        -- Restricted code cannot read VEHICLE_MAX_ACTIONBUTTONS itself.
        proxy:SetAttribute(CAP_ATTR, VEHICLE_MAX_ACTIONBUTTONS or 6)
        WrapProxy(proxy, ROUTE_SLOT)
    elseif kind == "totem" then
        proxy:SetAttribute("type", "click")
        proxy:SetAttribute("clickbutton", _G.MultiCastSummonSpellButton)
        proxy:SetAttribute(TOTEM_ATTR, payload)
        WrapProxy(proxy, TOTEM_BEFORE, TOTEM_AFTER)
    elseif kind == "click" then
        proxy:SetAttribute("type", "click")
        proxy:SetAttribute("clickbutton", payload)
    else
        proxy:SetAttribute("type", kind)
        proxy:SetAttribute(kind, payload)
    end
    CallQuietly(SetOverrideBindingClick, owner, true, key, PROXY_PREFIX .. key, mouse or "LeftButton")
end

local function AccelerateCurrent(key)
    local command = GetBindingAction(key, true)
    if command and command ~= "" then
        Accelerate(key, command)
    end
end

local function Rebuild()
    if InCombatLockdown() then return end
    CallQuietly(ClearOverrideBindings, owner)
    if not active then
        owner:UnregisterEvent("UPDATE_BINDINGS")
        return
    end
    EnsureKeyList()
    for i = 1, #keyList do
        AccelerateCurrent(keyList[i])
    end
end

local function OnOtherOverrideSet(_, _, key)
    if not active or selfInitiated or InCombatLockdown() then return end
    EnsureKeyList()
    if not keySet[key] then return end
    CallQuietly(SetOverrideBinding, owner, false, key, nil)
    AccelerateCurrent(key)
end

local function OnOtherOverridesCleared()
    if active and not selfInitiated then
        Rebuild()
    end
end

local function InstallHooks()
    if hooked then return end
    hooked = true
    for _, api in ipairs({ "SetOverrideBinding", "SetOverrideBindingSpell", "SetOverrideBindingClick",
        "SetOverrideBindingItem", "SetOverrideBindingMacro" }) do
        hooksecurefunc(api, OnOtherOverrideSet)
    end
    hooksecurefunc("ClearOverrideBindings", OnOtherOverridesCleared)
end

local function Enable()
    if active then return end
    active = true
    KeyPressModule.applied = true
    InstallHooks()
    owner:RegisterEvent("UPDATE_BINDINGS")
    Rebuild()
end

local function Disable()
    if not active then return end
    active = false
    KeyPressModule.applied = false
    owner:UnregisterEvent("UPDATE_BINDINGS")
    Rebuild()
end

local function Refresh()
    if InCombatLockdown() then
        owner:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if IsConfiguredOn() then
        Enable()
    else
        Disable()
    end
end

owner:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_BINDINGS" then
        Rebuild()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        Refresh()
    elseif event == "PLAYER_LOGIN" then
        Refresh()
    end
end)
owner:RegisterEvent("PLAYER_LOGIN")

addon.EnableKeyPress = Enable
addon.DisableKeyPress = Disable
addon.RefreshKeyPress = Refresh

-- RefreshConfig also runs at ADDON_LOADED; the PLAYER_LOGIN handler above owns the first build.
local function RefreshForProfile()
    if IsLoggedIn() then
        Refresh()
    end
end

if addon.RegisterModule then
    addon:RegisterModule("keypress", KeyPressModule, nil, nil, {
        lifecycle = { refresh = RefreshForProfile, restore = RefreshForProfile },
    })
end
