--[[
================================================================================
DragonUI Options - Core
================================================================================
This file provides the options registration system and initialization.
Based on ElvUI_OptionsUI pattern - accesses DragonUI addon via global.
================================================================================
]]

-- Access the main DragonUI addon (exposed globally in DragonUI/core.lua)
local addon = DragonUI

-- Initialize localization before any fallback/error path uses it.
local L = LibStub("AceLocale-3.0"):GetLocale("DragonUI")
local LO = LibStub("AceLocale-3.0"):GetLocale("DragonUI_Options")

if not addon then
    print("|cFFFF0000[DragonUI_Options]|r " .. ((LO and LO["Error: DragonUI addon not found!"]) or "Error: DragonUI addon not found!"))
    return
end

addon.LO = LO  -- Expose for other option files

-- ============================================================================
-- STATIC POPUP FOR RELOAD
-- ============================================================================

StaticPopupDialogs["DRAGONUI_RELOAD_UI"] = {
    text = LO["Changing this setting requires a UI reload to apply correctly."],
    button1 = LO["Reload UI"],
    button2 = LO["Not Now"],
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

StaticPopupDialogs["DRAGONUI_DELETE_PROFILE"] = {
    text = LO["Are you sure you want to delete the profile '%s'? This cannot be undone."],
    button1 = LO["Delete"],
    button2 = LO["Not Now"],
    OnAccept = function(self)
        local profileName = self.data
        if profileName and addon.db then
            addon.db:DeleteProfile(profileName, true)
            print("|cFF00FF00[DragonUI]|r " .. (LO["Deleted profile: "] or "Deleted profile: ") .. profileName)
            if addon.OptionsPanel then
                addon.OptionsPanel:SelectTab("profiles")
            end
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3
}

-- ============================================================================
-- INITIALIZE OPTIONS (called after all option files are loaded)
-- ============================================================================

function addon:InitializeOptions()
    -- Register a minimal BlizzOptions entry that redirects to the custom panel
    addon.Options.args.open_panel = {
        type = "execute",
        name = "|cff1784d1" .. (LO["Open DragonUI Settings"] or "Open DragonUI Settings") .. "|r",
        desc = LO["Open the DragonUI configuration panel."] or "Open the DragonUI configuration panel.",
        func = function()
            local AceConfigDialog = LibStub("AceConfigDialog-3.0")
            if AceConfigDialog then
                AceConfigDialog:Close("DragonUI")
            end
            if addon.OptionsPanel then
                addon.OptionsPanel:Toggle()
            end
        end,
        order = 1,
        width = "full"
    }
    addon.Options.args.info = {
        type = "description",
        name = "\n" .. (LO["Use /dragonui to open the full settings panel."] or "Use /dragonui to open the full settings panel."),
        order = 2
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("DragonUI", addon.Options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DragonUI", "DragonUI")

    addon.OptionsLoaded = true
end

-- Initialize when this addon finishes loading
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "DragonUI_Options" then
        addon:InitializeOptions()
        self:UnregisterAllEvents()
    end
end)
