-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

--[[
================================================================================
DragonUI - Merchant Auto Services
================================================================================
Vendor automation for the merchant module:
  - Auto Repair: repairs equipped items when a merchant window opens
  - Auto Sell Junk: sells grey (junk) items when a merchant window opens
Both are opt-in per profile (see database.lua, modules.merchant).
================================================================================
]]

local parts = addon.merchantParts or {}
addon.merchantParts = parts
local localized = parts.localized

local function config()
    return addon:GetModuleConfig("merchant") or {}
end

-- Repair everything the merchant can fix. Guild funds are used only when the
-- player has the right; a player-funded repair is skipped when it cannot be
-- afforded, so no half-repaired equipment is left behind.
local function autoRepair(cfg)
    if not CanMerchantRepair() then
        return
    end
    local cost = GetRepairAllCost() or 0
    if cost <= 0 then
        return
    end
    local useGuild = cfg.autoRepairGuild and CanGuildBankRepair()
    if not useGuild and GetMoney() < cost then
        addon:Print(localized("Not enough gold to repair all items."))
        return
    end
    RepairAllItems(useGuild)
    local text = GetCoinTextureString(cost)
    if useGuild then
        addon:Print(string.format(localized("Repaired all items for %s using guild funds."), text))
    else
        addon:Print(string.format(localized("Repaired all items for %s."), text))
    end
end

-- Sells every grey stack the vendor accepts and reports the haul, counting
-- whole stacks the same way the manual sell-all button does.
local function autoSellJunk()
    local isJunk = parts.isJunk
    if not isJunk then
        return
    end
    local items, copper = 0, 0
    for container = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetContainerNumSlots(container) or 0 do
            local link = GetContainerItemLink(container, slot)
            if isJunk(link) then
                local _, count = GetContainerItemInfo(container, slot)
                count = count or 1
                if pcall(UseContainerItem, container, slot) then
                    items = items + count
                    copper = copper + (select(11, GetItemInfo(link)) or 0) * count
                end
            end
        end
    end
    if items > 0 then
        addon:Print(string.format(localized("Sold %d junk item(s) for %s."), items, GetCoinTextureString(copper)))
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event)
    if event ~= "MERCHANT_SHOW" or not addon:IsModuleEnabled("merchant") then
        return
    end
    local cfg = config()
    local window = _G.MerchantFrame
    if cfg.autoSellJunk and window and window:IsShown() and window.selectedTab == 1 then
        autoSellJunk()
    end
    if cfg.autoRepair then
        autoRepair(cfg)
    end
end)
eventFrame:RegisterEvent("MERCHANT_SHOW")
