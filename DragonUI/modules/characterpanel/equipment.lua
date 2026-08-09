local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Wrath ships the whole Equipment Manager natively (3.1.2). The dialog is docked into the sidebar
-- by panes.lua and driven by the third sidebar tab, so Blizzard's toggle button has nothing to do.
local function hideToggle()
    local btn = _G.GearManagerToggleButton
    if not btn or btn._duiHidden then return end
    btn._duiHidden = true
    btn:Hide()
    btn:HookScript("OnShow", function(self) self:Hide() end)
end

-- The sets API only reports anything once the feature is switched on, and the sidebar tab is a
-- dead end without it.
local function ensureEnabled()
    if GetCVarBool and not GetCVarBool("equipmentManager") and SetCVar then
        SetCVar("equipmentManager", 1)
    end
end

local function build()
    ensureEnabled()
    hideToggle()
end

CP.RefreshEquipmentManager = build

CP:RegisterBuilder("equipment", build)
