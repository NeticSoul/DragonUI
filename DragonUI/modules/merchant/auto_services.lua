-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local parts = addon.merchantParts or {}
addon.merchantParts = parts
local localized = parts.localized

local CHECK_INTERVAL = 0.25
local CHECK_TRIES = 20

-- Bumped on every vendor open and close so checks left from an earlier visit give up.
local visit = 0

local function repairCost()
    local cost, canRepair = GetRepairAllCost()
    if not canRepair then
        return 0
    end
    return cost or 0
end

local function guildRepairFunds()
    local allowance = GetGuildBankWithdrawMoney() or 0
    local bank = GetGuildBankMoney() or 0
    -- Blizzard's guild repair tooltip reads -1 as "no daily cap" (guild master).
    if allowance == -1 then
        return bank
    end
    return math.min(allowance, bank)
end

local function waitFor(check, onTimeout)
    local thisVisit, triesLeft = visit, CHECK_TRIES
    local function step()
        if thisVisit ~= visit or check() then
            return
        end
        triesLeft = triesLeft - 1
        if triesLeft > 0 then
            addon:After(CHECK_INTERVAL, step)
        elseif onTimeout then
            onTimeout()
        end
    end
    addon:After(CHECK_INTERVAL, step)
end

local function repair(cost, useGuild, onFailure)
    RepairAllItems(useGuild and 1 or nil)
    waitFor(function()
        if repairCost() > 0 then
            return false
        end
        local text = GetMoneyString(cost)
        if useGuild then
            addon:Print(string.format(localized("Repaired all items for %s using guild funds."), text))
        else
            addon:Print(string.format(localized("Repaired all items for %s."), text))
        end
        return true
    end, onFailure)
end

local function repairWithOwnGold()
    local cost = repairCost()
    if cost <= 0 then
        return
    end
    if GetMoney() < cost then
        addon:Print(localized("Not enough gold to repair all items."))
        return
    end
    repair(cost, false)
end

local function autoRepair(cfg, incoming)
    if not CanMerchantRepair() then
        return
    end
    local cost = repairCost()
    if cost <= 0 then
        return
    end
    if cfg.autoRepairGuild and CanGuildBankRepair() and guildRepairFunds() >= cost then
        -- The client's guild figures can be stale; whatever the guild leaves unpaid falls to the player.
        repair(cost, true, repairWithOwnGold)
    elseif GetMoney() >= cost or GetMoney() + incoming < cost then
        repairWithOwnGold()
    else
        -- The junk just sold covers the gap, but GetMoney() only grows once the server pays out.
        waitFor(function()
            if GetMoney() < cost then
                return false
            end
            repairWithOwnGold()
            return true
        end, repairWithOwnGold)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    visit = visit + 1
    if event ~= "MERCHANT_SHOW" or not addon:IsModuleEnabled("merchant") then
        return
    end
    local cfg = addon:GetModuleConfig("merchant") or {}
    local incoming = 0
    if cfg.autoSellJunk then
        incoming = select(2, parts.sellEveryJunkItem())
    end
    if cfg.autoRepair then
        autoRepair(cfg, incoming)
    end
end)
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
