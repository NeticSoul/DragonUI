-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

local ItemOwnershipModule = {
    initialized = false,
    applied = false,
    hooks = {},
}

if addon.RegisterModule then
    addon:RegisterModule("itemownership", ItemOwnershipModule,
        (L and L["Character Item Counts"]) or "Character Item Counts",
        (L and L["Shows per-character bag, bank, and equipped item counts in item tooltips."])
            or "Shows per-character bag, bank, and equipped item counts in item tooltips.", {
        lifecyclePrefix = "ItemOwnership",
        loadOnce = true,
    })
end

local DB_VERSION = 1
local currentPlayer
local currentRealm
local bankOpen = false

local pendingScans = {
    bags = false,
    bank = false,
    equipment = false,
}

local function IsModuleEnabled()
    return addon:IsModuleEnabled("itemownership")
end

local function GetItemID(itemLink)
    if type(itemLink) == "number" then
        return itemLink
    end
    if type(itemLink) ~= "string" then
        return nil
    end

    return tonumber(string.match(itemLink, "item:(%-?%d+)"))
end

local function GetDatabase()
    if not addon.db or not addon.db.global then
        return nil
    end

    local db = addon.db.global.itemOwnership
    if type(db) ~= "table" or db.version ~= DB_VERSION then
        db = {
            version = DB_VERSION,
            realms = {},
        }
        addon.db.global.itemOwnership = db
    end

    db.realms = db.realms or {}
    return db
end

local function GetRealmData()
    local db = GetDatabase()
    if not db then
        return nil
    end

    currentRealm = currentRealm or GetRealmName() or ""
    db.realms[currentRealm] = db.realms[currentRealm] or { characters = {} }
    db.realms[currentRealm].characters = db.realms[currentRealm].characters or {}
    return db.realms[currentRealm]
end

local function GetCharacterData()
    local realmData = GetRealmData()
    if not realmData then
        return nil
    end

    currentPlayer = currentPlayer or UnitName("player")
    if not currentPlayer then
        return nil
    end

    local characters = realmData.characters
    characters[currentPlayer] = characters[currentPlayer] or {}

    local data = characters[currentPlayer]
    data.class = select(2, UnitClass("player")) or data.class
    data.lastSeen = time and time() or 0
    return data
end

local function AddItemCount(counts, itemLink, count)
    local itemID = GetItemID(itemLink)
    if not itemID or itemID <= 0 then
        return
    end

    count = tonumber(count) or 1
    if count < 1 then
        count = 1
    end

    counts[itemID] = (counts[itemID] or 0) + count
end

local function ScanContainer(counts, bagID, size)
    size = size or GetContainerNumSlots(bagID) or 0
    for slot = 1, size do
        local itemLink = GetContainerItemLink(bagID, slot)
        if itemLink then
            local count = select(2, GetContainerItemInfo(bagID, slot))
            AddItemCount(counts, itemLink, count)
        end
    end
end

local function ScanBags()
    local data = GetCharacterData()
    if not data then
        return
    end

    local counts = {}
    ScanContainer(counts, BACKPACK_CONTAINER or 0)

    for bagID = 1, (NUM_BAG_SLOTS or 4) do
        ScanContainer(counts, bagID)
    end

    if KEYRING_CONTAINER then
        local keyringSize = GetKeyRingSize and GetKeyRingSize() or GetContainerNumSlots(KEYRING_CONTAINER)
        ScanContainer(counts, KEYRING_CONTAINER, keyringSize)
    end

    data.bags = counts
    data.bagsUpdated = time and time() or 0
end

local function ScanBank()
    if not bankOpen then
        return
    end

    local data = GetCharacterData()
    if not data then
        return
    end

    local counts = {}
    ScanContainer(counts, BANK_CONTAINER or -1, NUM_BANKGENERIC_SLOTS or 28)

    local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
    local purchasedBankBags = GetNumBankSlots and GetNumBankSlots() or (NUM_BANKBAGSLOTS or 7)
    local lastBankBag = (NUM_BAG_SLOTS or 4) + purchasedBankBags
    for bagID = firstBankBag, lastBankBag do
        ScanContainer(counts, bagID)
    end

    data.bank = counts
    data.bankUpdated = time and time() or 0
end

local function ScanEquipment()
    local data = GetCharacterData()
    if not data then
        return
    end

    local counts = {}
    -- Slot 0 is skipped: the ammo it reports is the stack in the bags, already counted there.
    for slotID = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            AddItemCount(counts, itemLink, 1)
        end
    end

    data.equipment = counts
    data.equipmentUpdated = time and time() or 0
end

local scanRunner = CreateFrame("Frame")
scanRunner:Hide()
scanRunner.elapsed = 0
scanRunner:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.15 then
        return
    end

    self:Hide()
    self.elapsed = 0

    if not IsModuleEnabled() then
        pendingScans.bags = false
        pendingScans.bank = false
        pendingScans.equipment = false
        return
    end

    if pendingScans.bags then
        pendingScans.bags = false
        ScanBags()
    end
    if pendingScans.bank then
        pendingScans.bank = false
        ScanBank()
    end
    if pendingScans.equipment then
        pendingScans.equipment = false
        ScanEquipment()
    end
end)

local function ScheduleScan(scanType)
    if pendingScans[scanType] == nil then
        return
    end

    pendingScans[scanType] = true
    scanRunner.elapsed = 0
    scanRunner:Show()
end

local function ScheduleFullScan(includeBank)
    ScheduleScan("bags")
    ScheduleScan("equipment")
    if includeBank then
        ScheduleScan("bank")
    end
end

local function FormatCountText(bagCount, bankCount, equipmentCount)
    local parts = {}
    local total = bagCount + bankCount + equipmentCount

    if bagCount > 0 then
        table.insert(parts, string.format((L and L["Bags: %d"]) or "Bags: %d", bagCount))
    end
    if bankCount > 0 then
        table.insert(parts, string.format((L and L["Bank: %d"]) or "Bank: %d", bankCount))
    end
    if equipmentCount > 0 then
        table.insert(parts, string.format((L and L["Equipped: %d"]) or "Equipped: %d", equipmentCount))
    end

    if #parts > 1 then
        return string.format((L and L["Total: %d (%s)"]) or "Total: %d (%s)", total, table.concat(parts, ", "))
    end

    return parts[1]
end

local function GetCharacterColor(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 0.2, 1, 0.6
end

local function AddOwnershipLines(tooltip, itemLink)
    if not IsModuleEnabled() or not tooltip then
        return
    end

    local itemID = GetItemID(itemLink)
    if not itemID or tooltip.__DragonUIOwnershipItemID == itemID then
        return
    end

    local realmData = GetRealmData()
    if not realmData or not realmData.characters then
        return
    end

    local rows = {}
    for name, data in pairs(realmData.characters) do
        local bagCount = data.bags and data.bags[itemID] or 0
        local bankCount = data.bank and data.bank[itemID] or 0
        local equipmentCount = data.equipment and data.equipment[itemID] or 0
        local total = bagCount + bankCount + equipmentCount
        if total > 0 then
            table.insert(rows, {
                name = name,
                class = data.class,
                bagCount = bagCount,
                bankCount = bankCount,
                equipmentCount = equipmentCount,
            })
        end
    end

    if #rows == 0 then
        return
    end

    table.sort(rows, function(a, b)
        if a.name == currentPlayer then
            return true
        end
        if b.name == currentPlayer then
            return false
        end
        return string.lower(a.name) < string.lower(b.name)
    end)

    tooltip.__DragonUIOwnershipItemID = itemID
    for _, row in ipairs(rows) do
        local r, g, b = GetCharacterColor(row.class)
        tooltip:AddDoubleLine(
            row.name,
            FormatCountText(row.bagCount, row.bankCount, row.equipmentCount),
            r, g, b,
            0.2, 1, 0.6
        )
    end
    tooltip:Show()
end

local function HookTooltip(tooltip)
    if not tooltip or ItemOwnershipModule.hooks[tooltip] then
        return
    end

    tooltip:HookScript("OnTooltipSetItem", function(self)
        local _, itemLink = self:GetItem()
        if itemLink then
            AddOwnershipLines(self, itemLink)
        end
    end)
    tooltip:HookScript("OnTooltipCleared", function(self)
        self.__DragonUIOwnershipItemID = nil
    end)

    ItemOwnershipModule.hooks[tooltip] = true
end

local function ApplyItemOwnershipSystem()
    HookTooltip(GameTooltip)
    HookTooltip(ItemRefTooltip)
    ScheduleFullScan(bankOpen)

    ItemOwnershipModule.applied = true
    ItemOwnershipModule.initialized = true
end

local function RestoreItemOwnershipSystem()
    ItemOwnershipModule.applied = false
end

local function RefreshItemOwnershipSystem()
    if IsModuleEnabled() then
        ApplyItemOwnershipSystem()
    else
        RestoreItemOwnershipSystem()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "BANKFRAME_OPENED" then
        bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        -- A scan still in its debounce would run after close, when ScanBank refuses to read the bank.
        if pendingScans.bank and IsModuleEnabled() then
            pendingScans.bank = false
            local data = GetCharacterData()
            local previous, previousTime = data and data.bank, data and data.bankUpdated
            ScanBank()
            -- Nothing read over a non-empty bank means the client had already dropped it: keep the old counts.
            if data and type(previous) == "table" and next(previous) and not next(data.bank or {}) then
                data.bank, data.bankUpdated = previous, previousTime
            end
        end
        bankOpen = false
    end

    if not IsModuleEnabled() then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        ApplyItemOwnershipSystem()
    elseif event == "BAG_UPDATE" then
        local bagID = tonumber(arg1)
        if bankOpen and bagID and (bagID == BANK_CONTAINER or bagID > (NUM_BAG_SLOTS or 4)) then
            ScheduleScan("bank")
        else
            ScheduleScan("bags")
        end
    elseif event == "BANKFRAME_OPENED" then
        ScheduleScan("bank")
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if bankOpen then
            ScheduleScan("bank")
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            ScheduleScan("equipment")
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ScheduleScan("equipment")
    end
end)

addon.ApplyItemOwnershipSystem = ApplyItemOwnershipSystem
addon.RestoreItemOwnershipSystem = RestoreItemOwnershipSystem
addon.RefreshItemOwnershipSystem = RefreshItemOwnershipSystem
