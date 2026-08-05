-- ============================================================================
-- DragonUI - Keybinding Module
-- Integrates LibKeyBound-1.0 for intuitive hover + key press binding.
-- ============================================================================

local addon = select(2, ...)
local L = addon.L
local LibKeyBound

-- Safe loading of LibKeyBound
local success, result = pcall(function()
    return LibStub("LibKeyBound-1.0")
end)

if success then
    LibKeyBound = result
else
    addon:Error(L["LibKeyBound-1.0 not found or failed to load:"], result)
    return
end

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

local KeyBindingModule = {
    enabled = false,
    registeredButtons = {},
    originalMethods = {}
}

addon.KeyBindingModule = KeyBindingModule

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("keybinding", KeyBindingModule,
        addon.L["Key Binding"],
        addon.L["LibKeyBound integration for intuitive keybinding"])
end

-- ============================================================================
-- BUTTON ENHANCEMENT SYSTEM
-- ============================================================================

-- Make any button compatible with LibKeyBound (Bartender4 style)
function KeyBindingModule:MakeButtonBindable(button, bindingAction, actionName)
    if not LibKeyBound or not button or self.registeredButtons[button] then
        return
    end

    -- Store original methods
    self.originalMethods[button] = {
        GetHotkey = button.GetHotkey,
        SetKey = button.SetKey,
        ClearBindings = button.ClearBindings,
        GetActionName = button.GetActionName,
        GetBindings = button.GetBindings
    }

    -- Store binding info
    button._bindingAction = bindingAction
    button._actionName = actionName

    -- GetHotkey - returns the primary hotkey for display on button
    button.GetHotkey = function(self)
        local key = GetBindingKey(self._bindingAction)
        if key then
            return LibKeyBound:ToShortKey(key)
        end
        return ""
    end

    -- SetKey - assigns a key to this button
    button.SetKey = function(self, key)
        if InCombatLockdown() then return end
        SetBinding(key, self._bindingAction)
    end

    -- ClearBindings - removes all keys from this button
    button.ClearBindings = function(self)
        if InCombatLockdown() then return end
        local keys = {GetBindingKey(self._bindingAction)}
        for i = 1, #keys do
            if keys[i] then
                SetBinding(keys[i], nil)
            end
        end
    end

    -- GetActionName - for tooltip display
    button.GetActionName = function(self)
        return self._actionName or self:GetName()
    end

    -- GetBindings - returns formatted string of all bindings
    button.GetBindings = function(self)
        local keys = {GetBindingKey(self._bindingAction)}
        if #keys > 0 then
            local bindings = {}
            for i = 1, #keys do
                if keys[i] then
                    table.insert(bindings, GetBindingText(keys[i], 'KEY_'))
                end
            end
            return table.concat(bindings, ', ')
        end
        return nil
    end

    -- FreeKey - required by LibKeyBound for proper conflict resolution
    button.FreeKey = function(self, key)
        if InCombatLockdown() then return end
        local action = GetBindingAction(key)
        if action and action ~= "" then
            SetBinding(key, nil)
            return action
        end
        return nil
    end

    -- Simple hover handling (let LibKeyBound manage its own state)
    button:HookScript("OnEnter", function(self)
        if KeyBindingModule.enabled and LibKeyBound:IsShown() then
            LibKeyBound:Set(self)
        end
    end)

    -- Don't hook OnLeave - LibKeyBound handles this internally

    -- Register the button
    self.registeredButtons[button] = true
end

-- Remove LibKeyBound compatibility from a button
function KeyBindingModule:RemoveButtonBinding(button)
    if not button or not self.registeredButtons[button] then
        return
    end

    -- Restore original methods
    local original = self.originalMethods[button]
    if original then
        button.GetHotkey = original.GetHotkey
        button.SetKey = original.SetKey
        button.ClearBindings = original.ClearBindings
        button.GetActionName = original.GetActionName
        button.GetBindings = original.GetBindings
    end

    -- Clean up binding info
    button._bindingAction = nil
    button._actionName = nil

    -- Unregister
    self.registeredButtons[button] = nil
    self.originalMethods[button] = nil
end

-- ============================================================================
-- MODULE CONTROL
-- ============================================================================
function KeyBindingModule:Enable()
    if self.enabled or not LibKeyBound then
        return
    end
    
    -- Initialize LibKeyBound if not already done
    if not LibKeyBound.initialized then
        LibKeyBound:Initialize()
    end
    
    -- Ensure the binder frame exists
    if not LibKeyBound.frame then
        LibKeyBound.frame = LibKeyBound.Binder:Create()
    end
    
    self.enabled = true
    
    -- Register LibKeyBound events using proper callback system
    LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_ENABLED")
    LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_DISABLED")
    

    
    -- Add slash commands for DragonUI
    SLASH_DRAGONUI_KEYBIND1 = "/dukeybind"
    SLASH_DRAGONUI_KEYBIND2 = "/dukb"
    SlashCmdList["DRAGONUI_KEYBIND"] = function(msg)
        local command = msg:lower():trim()
        if command == "help" then
            print("|cFF00FF00[DragonUI KeyBind]|r " .. L["Commands:"])
            print("  " .. L["/dukb - Toggle keybinding mode"])
            print("  " .. L["/dukb help - Show this help"])
        else
            LibKeyBound:Toggle()
        end
    end
    

end

function KeyBindingModule:Disable()
    if not self.enabled then
        return
    end
    
    -- Deactivate LibKeyBound if active
    if LibKeyBound:IsShown() then
        LibKeyBound:Deactivate()
    end
    
    -- Remove all button bindings
    for button in pairs(self.registeredButtons) do
        self:RemoveButtonBinding(button)
    end
    
    -- Unregister slash commands
    SlashCmdList["DRAGONUI_KEYBIND"] = nil
    
    self.enabled = false
    print("|cFF00FF00[DragonUI KeyBind]|r " .. L["Module disabled."])
end

-- ============================================================================
-- LIBKEYBOUND CALLBACKS
-- ============================================================================

function KeyBindingModule:LIBKEYBOUND_ENABLED()
    if addon.SetKeybindVisualMode then
        addon.SetKeybindVisualMode(true)
    end
    print("|cFF00FF00[DragonUI KeyBind]|r " .. L["Keybinding mode activated. Hover over buttons and press keys to bind them."])
end

function KeyBindingModule:LIBKEYBOUND_DISABLED()
    if addon.SetKeybindVisualMode then
        addon.SetKeybindVisualMode(false)
    elseif addon.RefreshButtons then
        addon.RefreshButtons()
    end
    print("|cFF00FF00[DragonUI KeyBind]|r " .. L["Keybinding mode deactivated."])
end



-- ============================================================================
-- AUTO-REGISTRATION SYSTEM
-- ============================================================================

-- Auto-register DragonUI action buttons when they're created
function KeyBindingModule:AutoRegisterActionButtons()
    if not self.enabled then
        return
    end

    local function ResolveBindingCommand(command, fallbackClick)
        if command and _G["BINDING_NAME_" .. command] then
            return command
        end
        return fallbackClick
    end

    -- Register main action buttons
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button and not self.registeredButtons[button] then
            self:MakeButtonBindable(button, "ACTIONBUTTON" .. i, "Action Button " .. i)
        end
    end

    -- Register bonus action buttons
    for i = 1, 12 do
        local button = _G["BonusActionButton" .. i]
        if button and not self.registeredButtons[button] then
            self:MakeButtonBindable(button, "BONUSACTIONBUTTON" .. i, string.format(L["Bonus Action Button %d"], i))
        end
    end

    -- Register multibar buttons with proper keybind mappings
    local multibarMappings = {
        {frame = "MultiBarBottomLeftButton", binding = "MULTIACTIONBAR1BUTTON", name = L["Bottom Left Button"]},
        {frame = "MultiBarBottomRightButton", binding = "MULTIACTIONBAR2BUTTON", name = L["Bottom Right Button"]},
        {frame = "MultiBarRightButton", binding = "MULTIACTIONBAR3BUTTON", name = L["Right Button"]},
        {frame = "MultiBarLeftButton", binding = "MULTIACTIONBAR4BUTTON", name = L["Left Button"]}
    }
    
    for _, mapping in pairs(multibarMappings) do
        for i = 1, 12 do
            local button = _G[mapping.frame .. i]
            if button and not self.registeredButtons[button] then
                self:MakeButtonBindable(button, mapping.binding .. i, mapping.name .. " " .. i)
            end
        end
    end

    -- Register stance/shapeshift buttons
    for i = 1, (NUM_SHAPESHIFT_SLOTS or 10) do
        local button = _G["ShapeshiftButton" .. i]
        if button and not self.registeredButtons[button] then
            local binding = ResolveBindingCommand("SHAPESHIFTBUTTON" .. i, "CLICK ShapeshiftButton" .. i .. ":LeftButton")
            self:MakeButtonBindable(button, binding, string.format(L["Stance Button %d"] or "Stance Button %d", i))
        end
    end

    -- Register pet action buttons (Wrath commonly maps these to BONUSACTIONBUTTON)
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local button = _G["PetActionButton" .. i]
        if button and not self.registeredButtons[button] then
            local binding = ResolveBindingCommand("BONUSACTIONBUTTON" .. i, "CLICK PetActionButton" .. i .. ":LeftButton")
            self:MakeButtonBindable(button, binding, string.format(L["Pet Action Button %d"] or "Pet Action Button %d", i))
        end
    end

    -- Register multicast/totem action buttons (Shaman)
    for i = 1, 12 do
        local button = _G["MultiCastActionButton" .. i]
        if button and not self.registeredButtons[button] then
            local binding = ResolveBindingCommand("MULTICASTACTIONBUTTON" .. i, "CLICK MultiCastActionButton" .. i .. ":LeftButton")
            self:MakeButtonBindable(button, binding, string.format(L["Multicast Button %d"] or "Multicast Button %d", i))
        end
    end

    local summonButton = _G.MultiCastSummonSpellButton
    if summonButton and not self.registeredButtons[summonButton] then
        local binding = ResolveBindingCommand("MULTICASTSUMMONSPELL", "CLICK MultiCastSummonSpellButton:LeftButton")
        self:MakeButtonBindable(summonButton, binding, L["Totem Call Button"] or "Totem Call Button")
    end

    local recallButton = _G.MultiCastRecallSpellButton
    if recallButton and not self.registeredButtons[recallButton] then
        local binding = ResolveBindingCommand("MULTICASTRECALLSPELL", "CLICK MultiCastRecallSpellButton:LeftButton")
        self:MakeButtonBindable(recallButton, binding, L["Totem Recall Button"] or "Totem Recall Button")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Auto-enable when DragonUI loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Check if keybinding module should be enabled
        local isEnabled = addon.db and addon.db.profile and addon.db.profile.modules and 
                         addon.db.profile.modules.keybinding and addon.db.profile.modules.keybinding.enabled
        
        if isEnabled ~= false then -- Default to enabled
            KeyBindingModule:Enable()
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Auto-register action buttons after world load (no timer)
        if KeyBindingModule.enabled then
            KeyBindingModule:AutoRegisterActionButtons()
        end
        
        self:UnregisterAllEvents()
    end
end)

-- Global access
addon.KeyBindingModule = KeyBindingModule