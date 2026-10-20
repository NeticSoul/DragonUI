-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

-- GameTooltip compares on its own via the alwaysCompareItems CVar; ItemRefTooltip needs filling.

local EquipmentCompareModule = {
    initialized = false,
    applied = false,
    hooks = {},
}

if addon.RegisterModule then
    addon:RegisterModule("equipmentcompare", EquipmentCompareModule,
        (L and L["Automatic Equipment Comparison"]) or "Automatic Equipment Comparison",
        (L and L["Compare equippable items with your equipped gear without holding Shift, including item links opened from chat."])
            or "Compare equippable items with your equipped gear without holding Shift, including item links opened from chat.", {
        lifecyclePrefix = "EquipmentCompare",
    })
end

local CVAR = "alwaysCompareItems"
local ITEMREF_SLOTS = { "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3" }

local function IsModuleEnabled()
    return addon:IsModuleEnabled("equipmentcompare")
end

-- Ctrl suppresses the comparison while held; Shift keeps its own meaning.
local function IsSuppressed()
    return IsControlKeyDown and IsControlKeyDown() or false
end

-- ============================================================================
-- GameTooltip: the CVar does the work
-- ============================================================================

-- Remembered so turning the module off restores what the player had.
local previousCvar

local function ApplyCvar()
    if not GetCVar or not SetCVar then
        return
    end
    local current = GetCVar(CVAR)
    if current == "1" then
        return
    end
    if previousCvar == nil then
        previousCvar = current
    end
    SetCVar(CVAR, "1")
end

local function RestoreCvar()
    if previousCvar == nil or not SetCVar then
        return
    end
    SetCVar(CVAR, previousCvar)
    previousCvar = nil
end

-- ============================================================================
-- ItemRefTooltip: fill Blizzard's own comparison tooltips
-- ============================================================================

local function HideComparison()
    for index = 1, #ITEMREF_SLOTS do
        local tooltip = _G[ITEMREF_SLOTS[index]]
        if tooltip then
            tooltip:Hide()
        end
    end
end

local function ShowComparison()
    local frame = _G.ItemRefTooltip
    if not frame or not frame:IsShown() then
        return
    end
    if not IsModuleEnabled() or IsSuppressed() then
        HideComparison()
        return
    end

    -- Same self-comparison check the client uses on GameTooltip.
    if frame:IsEquippedItem() then
        HideComparison()
        return
    end

    local _, link = frame:GetItem()
    if not link then
        HideComparison()
        return
    end

    local left = frame:GetLeft() or 0
    local right = frame:GetRight() or 0
    local placeOnLeft = left > ((GetScreenWidth() or 0) - right)
    local point = placeOnLeft and "TOPRIGHT" or "TOPLEFT"
    local relativePoint = placeOnLeft and "TOPLEFT" or "TOPRIGHT"
    local anchor = frame

    for index = 1, #ITEMREF_SLOTS do
        local tooltip = _G[ITEMREF_SLOTS[index]]
        if tooltip then
            tooltip:SetOwner(frame, "ANCHOR_NONE")
            if tooltip:SetHyperlinkCompareItem(link, index, 1) then
                tooltip:ClearAllPoints()
                tooltip:SetPoint(point, anchor, relativePoint, 0, 0)
                tooltip:Show()
                anchor = tooltip
            else
                tooltip:Hide()
            end
        end
    end
end

-- ============================================================================
-- MODIFIER WATCH
-- ============================================================================

-- Watched by event so Ctrl takes effect mid-hover, not only when the tooltip is set.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent", function(_, _, key, down)
    if key ~= "LCTRL" and key ~= "RCTRL" then
        return
    end
    if not IsModuleEnabled() then
        return
    end
    if down then
        HideComparison()
    else
        ShowComparison()
    end
end)

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

local function InstallItemRefHooks()
    local frame = _G.ItemRefTooltip
    if not frame or EquipmentCompareModule.hooks[frame] then
        return
    end
    EquipmentCompareModule.hooks[frame] = true

    -- Runs after Blizzard's Shift-only handler and fills the tooltips either way.
    frame:HookScript("OnTooltipSetItem", function(self)
        if not IsModuleEnabled() then
            return
        end
        if IsSuppressed() then
            HideComparison()
            return
        end
        ShowComparison()
    end)

    frame:HookScript("OnHide", HideComparison)
    frame:HookScript("OnTooltipCleared", HideComparison)
end

local function ApplyEquipmentCompareSystem()
    if not IsModuleEnabled() then
        return
    end
    ApplyCvar()
    InstallItemRefHooks()

    EquipmentCompareModule.applied = true
    EquipmentCompareModule.initialized = true
end

local function RestoreEquipmentCompareSystem()
    RestoreCvar()
    HideComparison()
    EquipmentCompareModule.applied = false
end

local function RefreshEquipmentCompareSystem()
    if IsModuleEnabled() then
        ApplyEquipmentCompareSystem()
    else
        RestoreEquipmentCompareSystem()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    if IsModuleEnabled() then
        ApplyEquipmentCompareSystem()
    end
end)

addon.ApplyEquipmentCompareSystem = ApplyEquipmentCompareSystem
addon.RestoreEquipmentCompareSystem = RestoreEquipmentCompareSystem
addon.RefreshEquipmentCompareSystem = RefreshEquipmentCompareSystem
