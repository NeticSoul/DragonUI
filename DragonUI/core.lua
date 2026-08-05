local addon = select(2, ...);

--[[
================================================================================
DragonUI - Core Initialization
================================================================================
This file handles the main addon initialization using AceAddon-3.0.
Utility functions have been moved to core/api.lua

Options are loaded on demand from DragonUI_Options addon (ElvUI pattern).
================================================================================
]]

-- Expose addon globally for DragonUI_Options to access
_G.DragonUI = addon

-- Localization (initialized early in config.lua so core/ files can use it)
local L = addon.L

-- Create addon object using AceAddon
addon.core = LibStub("AceAddon-3.0"):NewAddon("DragonUI", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0");

-- Pre-define Options table (will be filled by DragonUI_Options)
addon.Options = { type = "group", name = "DragonUI", args = {} }

-- Track if options addon is loaded
addon.OptionsLoaded = false

function addon.core:OnInitialize()
    -- Replace the temporary addon.db with the real AceDB
    addon.db = LibStub("AceDB-3.0"):New("DragonUIDB", addon.defaults);

    addon:ApplyDatabaseMigrations()

    -- Force defaults to be written to profile (check for specific key that should always exist)
    if not addon.db.profile.mainbars or not addon.db.profile.mainbars.scale_actionbar then
        -- Copy all defaults to profile to ensure they exist in SavedVariables
        addon.DeepCopy(addon.defaults.profile, addon.db.profile);
        addon:ApplyDatabaseMigrations()
    end

    -- Register callbacks for configuration changes
    addon.db.RegisterCallback(addon, "OnProfileChanged", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileCopied", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileReset", "RefreshConfig");

    -- Apply current profile configuration immediately
    -- This ensures the profile is loaded when the addon starts
    addon:RefreshConfig();
end

function addon.core:OnEnable()
    -- Register slash commands (using new commands.lua system)
    if addon.LoadCommands then
        addon.LoadCommands()
    else
        -- Fallback to legacy registration
        self:RegisterChatCommand("dragonui", "SlashCommand")
        self:RegisterChatCommand("pi", "SlashCommand")
    end

    -- Fire custom event to signal that DragonUI is fully initialized
    -- This ensures modules get the correct config values
    self:SendMessage("DRAGONUI_READY");
end

-- ============================================================================
-- OPTIONS UI LOADING (ElvUI Pattern)
-- ============================================================================

function addon:ToggleOptionsUI(msg)
    if InCombatLockdown() then
        addon:Error(L["Cannot open options in combat."])
        return
    end

    if not IsAddOnLoaded("DragonUI_Options") then
        local noConfig
        local reason = select(6, GetAddOnInfo("DragonUI_Options"))
        
        if reason ~= "MISSING" and reason ~= "DISABLED" then
            LoadAddOn("DragonUI_Options")
            
            -- Check if it actually loaded
            if not IsAddOnLoaded("DragonUI_Options") then 
                noConfig = true 
            else
                addon.OptionsLoaded = true
            end
        else
            noConfig = true
        end

        if noConfig then
            addon:Error(L["Error -- Addon 'DragonUI_Options' not found or is disabled."])
            return
        end
    end

    -- Use the custom panel
    if addon.OptionsPanel then
        addon.OptionsPanel:Toggle(msg)
    else
        addon:Error(L["Options panel not available. Try /reload."])
    end
end

-- Callback function that refreshes all modules when configuration changes
function addon:RefreshConfig()
    -- Also runs on profile switch: the newly-activated profile may be older than the current schema.
    addon:ApplyDatabaseMigrations()

    -- Initialize cooldown system if it hasn't been already
    if addon.InitializeCooldowns then
        addon.InitializeCooldowns()
    end

    local failed = addon:RefreshRegisteredSystems() or {}

    -- If some configurations failed, retry them after 2 seconds
    if #failed > 0 then
        addon.core:ScheduleTimer(function()
            addon:RefreshRegisteredSystems()
        end, 2);
    end
end

-- Legacy SlashCommand handler (fallback if commands.lua not loaded)
function addon.core:SlashCommand(input)
    -- Delegate to new command system if available
    if addon.CommandHandlers then
        if not input or input:trim() == "" then
            addon:ToggleOptionsUI()
        elseif input:lower() == "config" then
            addon:ToggleOptionsUI()
        elseif input:lower() == "edit" or input:lower() == "editor" then
            addon.CommandHandlers.ToggleEditorMode()
        elseif input:lower() == "help" then
            addon.CommandHandlers.ShowHelp()
        else
            addon.CommandHandlers.ShowHelp()
        end
    else
        -- Original fallback
        if not input or input:trim() == "" then
            addon:ToggleOptionsUI()
        elseif input:lower() == "config" then
            addon:ToggleOptionsUI()
        elseif input:lower() == "edit" or input:lower() == "editor" then
            if addon.EditorMode then
                addon.EditorMode:Toggle()
            else
                addon:Error(L["Editor mode not available."])
            end
        else
            addon:Print(L["Commands: /dragonui config, /dragonui edit"])
        end
    end
end
