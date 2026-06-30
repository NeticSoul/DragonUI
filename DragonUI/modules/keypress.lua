-- ============================================================================
-- DragonUI - Key Press module
-- Fires action-bar abilities on key DOWN instead of key release.
--
-- Minimal port of the proven SnowfallKeyPress mechanism: for every bound key
-- we build a hidden *secure* proxy button (RegisterForClicks "AnyDown") that
-- replicates the bound action, then use SetOverrideBindingClick to make the
-- key click that proxy on key-down. Everything is done through secure
-- templates + protected binding APIs, so there is no taint. All work is
-- skipped while in combat lockdown (the protected binding APIs are blocked
-- there); changes apply on leaving combat or /reload.
-- ============================================================================

local addon = select(2, ...)

-- ----------------------------------------------------------------------------
-- Binding templates (which kinds of bindings we can accelerate, and how to
-- replicate them onto a secure proxy button). Lifted from SnowfallKeyPress.
-- ----------------------------------------------------------------------------
local templates = {
    {command = "^ACTIONBUTTON(%d+)$",          attributes = {{"type", "macro"}, {"actionbutton", "%1"                         }}},
    {command = "^MULTIACTIONBAR1BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarBottomLeftButton%1" }}},
    {command = "^MULTIACTIONBAR2BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarBottomRightButton%1"}}},
    {command = "^MULTIACTIONBAR3BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarRightButton%1"      }}},
    {command = "^MULTIACTIONBAR4BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton",  "MultiBarLeftButton%1"       }}},
    {command = "^SHAPESHIFTBUTTON(%d+)$",      attributes = {{"type", "click"}, {"clickbutton",  "ShapeshiftButton%1"         }}},
    {command = "^BONUSACTIONBUTTON(%d+)$",     attributes = {{"type", "click"}, {"clickbutton",  "PetActionButton%1"          }}},
    {command = "^MULTICASTSUMMONBUTTON(%d+)$", attributes = {{"type", "click"}, {"multicastsummon", "%1"                      }}},
    {command = "^MULTICASTRECALLBUTTON1$",     attributes = {{"type", "click"}, {"clickbutton",  "MultiCastRecallSpellButton" }}},
    {command = "^CLICK (.+):([^:]+)$",         attributes = {{"type", "click"}, {"clickbutton",  "%1"                         }}},
    {command = "^MACRO (.+)$",                 attributes = {{"type", "macro"}, {"macro",        "%1"                         }}},
    {command = "^SPELL (.+)$",                 attributes = {{"type", "spell"}, {"spell",        "%1"                         }}},
    {command = "^ITEM (.+)$",                  attributes = {{"type", "item" }, {"item",         "%1"                         }}},
}

-- Click "type" attributes we are willing to accelerate (anything that doesn't
-- need to differentiate down/up presses).
local allowedTypeAttributes = {
    actionbar = true, action = true, pet = true, multispell = true,
    spell = true, item = true, macro = true, cancelaura = true, stop = true,
    target = true, focus = true, assist = true, maintank = true, mainassist = true,
}

-- ----------------------------------------------------------------------------
-- Static key list: every key on a standard keyboard, in every ALT/CTRL/SHIFT
-- combination (mirrors SnowfallKeyPress's default configuration). Built once.
-- ----------------------------------------------------------------------------
local baseKeys = {
    "A","B","C","D","E","F","G","H","I","J","K","L","M",
    "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "0","1","2","3","4","5","6","7","8","9",
    "`","-","=","[","]","\\",";","'",".",",","/",
    "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
    "BACKSPACE","DELETE","DOWN","END","ENTER","ESCAPE","HOME","INSERT","LEFT",
    "NUMLOCK","NUMPAD0","NUMPAD1","NUMPAD2","NUMPAD3","NUMPAD4","NUMPAD5",
    "NUMPAD6","NUMPAD7","NUMPAD8","NUMPAD9","NUMPADDECIMAL","NUMPADDIVIDE",
    "NUMPADMINUS","NUMPADMULTIPLY","NUMPADPLUS","PAGEDOWN","PAGEUP","PAUSE",
    "RIGHT","SCROLLLOCK","SPACE","TAB","UP",
    "BUTTON3","BUTTON4","BUTTON5",
}
local modifiers = { "ALT", "CTRL", "SHIFT" }

local acceleratedKeys -- built lazily
local function getKeyList()
    if acceleratedKeys then return acceleratedKeys end
    acceleratedKeys = {}
    -- All modifier combinations, including the empty (unmodified) combo.
    local combos = { "" }
    for _, mod in ipairs(modifiers) do
        local n = #combos
        for i = 1, n do
            combos[#combos + 1] = combos[i] .. mod .. "-"
        end
    end
    for _, key in ipairs(baseKeys) do
        for _, combo in ipairs(combos) do
            acceleratedKeys[#acceleratedKeys + 1] = combo .. key
        end
    end
    return acceleratedKeys
end

-- ----------------------------------------------------------------------------
-- Secure acceleration core (adapted from SnowfallKeyPress)
-- ----------------------------------------------------------------------------
local overrideFrame = CreateFrame("Frame")
local active = false  -- true while the feature is enabled and hooks should act
local hook = true     -- guards our own override-binding writes from re-entrancy

local stringmatch, stringgsub = string.match, string.gsub

local function isSecureButton(x)
    return not not (
        type(x) == "table"
        and type(x.IsObjectType) == "function"
        and issecurevariable(x, "IsObjectType")
        and x:IsObjectType("Button")
        and select(2, x:IsProtected())
    )
end

-- Accelerate a single key (key is not currently overridden by us when called).
local function accelerateKey(key, command)
    for _, template in ipairs(templates) do
        if stringmatch(command, template.command) then
            local mouseButton, clickButtonName, clickButton
            clickButtonName, mouseButton = stringmatch(command, "^CLICK (.+):([^:]+)$")
            if clickButtonName then
                clickButton = _G[clickButtonName]
                if not isSecureButton(clickButton) or clickButton:GetAttribute("", "downbutton", mouseButton) then
                    return
                end
                local harmButton = SecureButton_GetModifiedAttribute(clickButton, "harmbutton", mouseButton)
                local helpButton = SecureButton_GetModifiedAttribute(clickButton, "helpbutton", mouseButton)
                local mouseType = SecureButton_GetModifiedAttribute(clickButton, "type", mouseButton)
                local harmType  = SecureButton_GetModifiedAttribute(clickButton, "type", harmButton)
                local helpType  = SecureButton_GetModifiedAttribute(clickButton, "type", helpButton)
                if (mouseType and not allowedTypeAttributes[mouseType])
                    or (harmType and not allowedTypeAttributes[harmType])
                    or (helpType and not allowedTypeAttributes[helpType]) then
                    return
                end
            else
                mouseButton = "LeftButton"
            end

            local bindButtonName = "DragonUI_KeyPressButton_" .. key
            local bindButton = _G[bindButtonName]
            if not bindButton then
                bindButton = CreateFrame("Button", bindButtonName, nil, "SecureActionButtonTemplate")
                bindButton:RegisterForClicks("AnyDown")
                SecureHandlerSetFrameRef(bindButton, "VehicleMenuBar", VehicleMenuBar)
                SecureHandlerSetFrameRef(bindButton, "BonusActionBarFrame", BonusActionBarFrame)
                SecureHandlerSetFrameRef(bindButton, "MultiCastSummonSpellButton", MultiCastSummonSpellButton)
                SecureHandlerExecute(bindButton, [[
                    VehicleMenuBar = self:GetFrameRef("VehicleMenuBar");
                    BonusActionBarFrame = self:GetFrameRef("BonusActionBarFrame");
                    MultiCastSummonSpellButton = self:GetFrameRef("MultiCastSummonSpellButton");
                ]])
            end

            -- Clear any stale wrap from a previous acceleration of this key.
            SecureHandlerUnwrapScript(bindButton, "OnClick")

            for _, attribute in ipairs(template.attributes) do
                local attributeName = attribute[1]
                local attributeValue = stringgsub(command, template.command, attribute[2], 1)

                if attributeName == "clickbutton" then
                    bindButton:SetAttribute(attributeName, _G[attributeValue])
                elseif attributeName == "actionbutton" then
                    -- Decide vehicle/bonus/action at click time, like ActionButtonUp().
                    SecureHandlerWrapScript(bindButton, "OnClick", bindButton, [[
                        local clickMacro = "/click ActionButton]] .. attributeValue .. [[";
                        if (VehicleMenuBar:IsProtected() and VehicleMenuBar:IsShown() and ]] .. tostring(tonumber(attributeValue) <= VEHICLE_MAX_ACTIONBUTTONS) .. [[) then
                            clickMacro = "/click VehicleMenuBarActionButton]] .. attributeValue .. [[";
                        elseif (BonusActionBarFrame:IsProtected() and BonusActionBarFrame:IsShown()) then
                            clickMacro = "/click BonusActionButton]] .. attributeValue .. [[";
                        end
                        self:SetAttribute("macrotext", clickMacro);
                    ]])
                elseif attributeName == "multicastsummon" then
                    SecureHandlerWrapScript(bindButton, "OnClick", bindButton, [[
                        lastID = MultiCastSummonSpellButton:GetID();
                        MultiCastSummonSpellButton:SetID(]] .. attributeValue .. [[);
                    ]], [[
                        MultiCastSummonSpellButton:SetID(lastID);
                    ]])
                    bindButton:SetAttribute("clickbutton", MultiCastSummonSpellButton)
                else
                    bindButton:SetAttribute(attributeName, attributeValue)
                end
            end

            -- Priority override so the key clicks our proxy on key-down.
            hook = false
            SetOverrideBindingClick(overrideFrame, true, key, bindButtonName, mouseButton)
            hook = true
            return
        end
    end
end

-- Rebuild all of our overrides from the current bindings.
local function updateBindings()
    if InCombatLockdown() then
        return
    end

    hook = false
    ClearOverrideBindings(overrideFrame)
    hook = true

    if not active then
        overrideFrame:UnregisterEvent("UPDATE_BINDINGS")
        return
    end

    for _, key in ipairs(getKeyList()) do
        local command = GetBindingAction(key, true)
        if command and command ~= "" then
            accelerateKey(key, command)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Hooks: keep our acceleration in sync when other code touches override
-- bindings (vehicle / bonus / stance bar swaps, etc.). Installed once.
-- ----------------------------------------------------------------------------
local hooksInstalled = false
local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    local keySet -- lazy lookup of accelerated keys
    local function isAcceleratedKey(key)
        if not keySet then
            keySet = {}
            for _, k in ipairs(getKeyList()) do keySet[k] = true end
        end
        return keySet[key]
    end

    local function setOverrideBindingHook(_, _, overrideKey)
        if not active or not hook or InCombatLockdown() then return end
        if isAcceleratedKey(overrideKey) then
            hook = false
            SetOverrideBinding(overrideFrame, false, overrideKey, nil)
            hook = true
            local command = GetBindingAction(overrideKey, true)
            if command and command ~= "" then
                accelerateKey(overrideKey, command)
            end
        end
    end
    hooksecurefunc("SetOverrideBinding", setOverrideBindingHook)
    hooksecurefunc("SetOverrideBindingSpell", setOverrideBindingHook)
    hooksecurefunc("SetOverrideBindingClick", setOverrideBindingHook)
    hooksecurefunc("SetOverrideBindingItem", setOverrideBindingHook)
    hooksecurefunc("SetOverrideBindingMacro", setOverrideBindingHook)

    hooksecurefunc("ClearOverrideBindings", function()
        if active and hook then updateBindings() end
    end)
end

-- ----------------------------------------------------------------------------
-- Public API + db gating
-- ----------------------------------------------------------------------------
local function isConfiguredOn()
    local m = addon.db and addon.db.profile and addon.db.profile.modules
    return m and m.keypress and m.keypress.enabled == true
end

function addon.EnableKeyPress()
    if active then return end
    active = true
    installHooks()
    overrideFrame:RegisterEvent("UPDATE_BINDINGS")
    updateBindings()
end

function addon.DisableKeyPress()
    if not active then return end
    active = false
    overrideFrame:UnregisterEvent("UPDATE_BINDINGS")
    updateBindings() -- with active=false this just clears our overrides
end

-- Called by the options toggle. Applies the saved-variable state immediately
-- when out of combat; in combat the protected binding APIs are blocked, so the
-- change is deferred until combat ends (PLAYER_REGEN_ENABLED).
function addon.RefreshKeyPress()
    if InCombatLockdown() then
        overrideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if isConfiguredOn() then
        addon.EnableKeyPress()
    else
        addon.DisableKeyPress()
    end
end

overrideFrame:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_BINDINGS" then
        updateBindings()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Apply a toggle that was requested during combat, then stop listening.
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        addon.RefreshKeyPress()
    elseif event == "PLAYER_LOGIN" then
        addon.RefreshKeyPress()
    end
end)
overrideFrame:RegisterEvent("PLAYER_LOGIN")
