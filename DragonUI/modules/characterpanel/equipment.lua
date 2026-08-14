local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Wrath ships the whole Equipment Manager natively (3.1.2). The dialog is docked into the sidebar
-- by panes.lua and driven by the third sidebar tab, so Blizzard's toggle button has nothing to do.
local CVAR = "equipmentManager"

local function hideToggle()
    local btn = _G.GearManagerToggleButton
    if not btn or btn._duiHidden then return end
    btn._duiHidden = true
    btn:Hide()
    btn:HookScript("OnShow", function(self) self:Hide() end)
end

-- The sets API only reports anything once the feature is switched on, and the sidebar tab is a
-- dead end without it -- but flipping the player's own CVar for them is not ours to do silently.
local function isEnabled()
    return GetCVarBool and GetCVarBool(CVAR) and true or false
end
CP.IsEquipmentManagerEnabled = isEnabled

StaticPopupDialogs["DRAGONUI_ENABLE_EQUIPMENT_MANAGER"] = {
    text = addon.L["Equipment Manager is turned off. Enable it now?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if SetCVar then SetCVar(CVAR, 1) end
        if CP.RefreshEquipmentTabState then CP.RefreshEquipmentTabState() end
        if isEnabled() and CP.SelectSidebarTab then CP.SelectSidebarTab(CP.PANE_EQUIPMENT) end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

function CP.PromptEnableEquipmentManager()
    StaticPopup_Show("DRAGONUI_ENABLE_EQUIPMENT_MANAGER")
end

-- Re-checked on every open: catches the CVar having been flipped from Interface Options meanwhile.
local function hookRecheckOnShow()
    local cf = _G.CharacterFrame
    if not cf or cf._duiEquipMgrShowHooked then return end
    cf._duiEquipMgrShowHooked = true
    cf:HookScript("OnShow", function()
        if CP.RefreshEquipmentTabState then CP.RefreshEquipmentTabState() end
    end)
end

local function build()
    hideToggle()
    hookRecheckOnShow()
    if CP.RefreshEquipmentTabState then CP.RefreshEquipmentTabState() end
end

CP.RefreshEquipmentManager = build

CP:RegisterBuilder("equipment", build)
