-- Event bus (Envoy), inventory event tracking, bank cache, player/bag/item slot info.
local addon = select(2, ...)
local mod = addon.BagsterModule

-- ============================================================================
-- ENVOY (EVENT BUS)
-- ============================================================================

do
    local Envoy = mod:NewModule("Envoy")

    function Envoy:New()
        return setmetatable({ listeners = {} }, { __index = Envoy })
    end

    function Envoy:Send(msg, ...)
        local listeners = self.listeners[msg]
        if listeners then
            for obj, method in pairs(listeners) do
                if type(method) == "string" then
                    obj[method](obj, msg, ...)
                elseif type(method) == "function" then
                    method(msg, ...)
                end
            end
        end
    end

    function Envoy:Register(obj, msg, method)
        if not self.listeners[msg] then
            self.listeners[msg] = {}
        end
        self.listeners[msg][obj] = method or msg
    end

    function Envoy:RegisterMany(obj, ...)
        for i = 1, select("#", ...) do
            local msg = select(i, ...)
            self:Register(obj, msg)
        end
    end

    function Envoy:RegisterMessage(obj, msg, method)
        self:Register(obj, msg, method or msg)
    end

    function Envoy:Unregister(obj, msg)
        local listeners = self.listeners[msg]
        if listeners then
            listeners[obj] = nil
            if not next(listeners) then
                self.listeners[msg] = nil
            end
        end
    end

    function Envoy:UnregisterAll(obj)
        for msg in pairs(self.listeners) do
            self:Unregister(obj, msg)
        end
    end
end

-- ============================================================================
-- INVENTORY EVENTS (BAG TRACKING)
-- ============================================================================

do
    local InventoryEvents = mod:NewModule("InventoryEvents", mod("Envoy"):New())
    local AtBank = false

    function InventoryEvents:AtBank()
        return AtBank
    end

    local function sendMessage(msg, ...)
        InventoryEvents:Send(msg, ...)
    end

    local Slots
    do
        local function getIndex(bagId, slotId)
            return (bagId < 0 and bagId * 100 - slotId) or bagId * 100 + slotId
        end

        Slots = {
            Set = function(self, bagId, slotId, itemLink, count, isLocked, onCooldown)
                local index = getIndex(bagId, slotId)
                local item = self[index] or {}
                item[1] = itemLink
                item[2] = count
                item[4] = onCooldown
                self[index] = item
            end,
            Remove = function(self, bagId, slotId)
                local index = getIndex(bagId, slotId)
                if self[index] then
                    self[index] = nil
                    return true
                end
            end,
            Get = function(self, bagId, slotId)
                return self[getIndex(bagId, slotId)]
            end
        }
        setmetatable(Slots, { __call = Slots.Get })
    end

    local BagTypes = {}
    local BagSizes = {}

    -- Forward declaration for deferred cleanup (defined after updateBag).
    -- Lua 5.1 does NOT hoist local function bindings; a forward reference
    -- from updateBag would resolve as a global nil without this.
    local scheduleDeferredBagCheck

    local function addItem(bagId, slotId)
        local texture, count, locked, quality, readable, lootable, itemLink =
            GetContainerItemInfo(bagId, slotId)
        local start, duration, enable = GetContainerItemCooldown(bagId, slotId)
        local onCooldown = (start > 0 and duration > 0 and enable > 0)

        Slots:Set(bagId, slotId, itemLink, count, locked, onCooldown)
        sendMessage("ITEM_SLOT_ADD", bagId, slotId, itemLink, count, onCooldown)
    end

    local function removeItem(bagId, slotId)
        if Slots:Remove(bagId, slotId) then
            sendMessage("ITEM_SLOT_REMOVE", bagId, slotId)
        end
    end

    local function updateItem(bagId, slotId)
        local item = Slots(bagId, slotId)
        if item then
            local prevLink = item[1]
            local prevCount = item[2]
            local texture, count, locked, quality, readable, lootable, itemLink =
                GetContainerItemInfo(bagId, slotId)
            if not (prevLink == itemLink and prevCount == count) then
                item[1] = itemLink
                item[2] = count
                sendMessage("ITEM_SLOT_UPDATE", bagId, slotId, itemLink, count)
            end
        else
            addItem(bagId, slotId)
        end
    end

    local function getBagSize(bagId)
        -- Gate: skip cached container data if the bag is not equipped.
        -- Some 3.3.5a servers return stale GetContainerNumSlots values
        -- after a bag is unequipped.
        if bagId >= 1 and bagId <= 4 then
            local invSlot = ContainerIDToInventoryID(bagId)
            if not GetInventoryItemLink("player", invSlot) then
                return 0
            end
        end

        if bagId == KEYRING_CONTAINER then
            return GetKeyRingSize()
        end
        if bagId == BANK_CONTAINER then
            return NUM_BANKGENERIC_SLOTS
        end
        return GetContainerNumSlots(bagId)
    end

    local function updateBag(bagId)
        local size = getBagSize(bagId)
        local prevSize = BagSizes[bagId] or 0

        -- Check bag type change
        local _, newType = GetContainerNumFreeSlots(bagId)
        local prevType = BagTypes[bagId]
        if prevType ~= newType then
            BagTypes[bagId] = newType
            if prevType then
                sendMessage("BAG_UPDATE_TYPE", bagId, newType)
            end
        end

        BagSizes[bagId] = size

        if size > prevSize then
            for slot = prevSize + 1, size do
                addItem(bagId, slot)
            end
        elseif size < prevSize then
            for slot = size + 1, prevSize do
                removeItem(bagId, slot)
            end
            if size == 0 then
                sendMessage("BAG_EMPTIED", bagId, prevSize)
            end
        end

        for slot = 1, size do
            updateItem(bagId, slot)
        end

        -- Deferred verification for bag slots: if the bag still appears
        -- to have items (BagSizes > 0), schedule a re-check in 0.5s.
        -- Some 3.3.5a servers cache GetContainerNumSlots and report the
        -- old value at BAG_UPDATE time, so we can't always trust size==0
        -- or size==prevSize immediately after unequip.
        if bagId >= 1 and bagId <= 4 and BagSizes[bagId] and BagSizes[bagId] > 0 then
            scheduleDeferredBagCheck(bagId)
        end
    end

    local function updateCooldowns(bagId)
        local size = getBagSize(bagId)
        for slot = 1, size do
            local item = Slots(bagId, slot)
            if item then
                local start, duration, enable = GetContainerItemCooldown(bagId, slot)
                local onCooldown = (start > 0 and duration > 0 and enable > 0)
                item[4] = onCooldown
                sendMessage("ITEM_SLOT_UPDATE_COOLDOWN", bagId, slot)
            end
        end
    end

    -- Deferred bag cleanup: some 3.3.5a servers cache GetContainerNumSlots
    -- at BAG_UPDATE time, so we re-verify after a short delay when we
    -- suspect a bag may have been unequipped (size == prevSize implies
    -- the data may be cached rather than truly unchanged).
    local pendingCleanups = {}
    local cleanupFrame = CreateFrame("Frame")
    cleanupFrame:Hide()
    cleanupFrame:SetScript("OnUpdate", function(self)
        local now = GetTime()
        for bagId, deadline in pairs(pendingCleanups) do
            if now >= deadline then
                pendingCleanups[bagId] = nil

                local invSlot = ContainerIDToInventoryID(bagId)
                if not GetInventoryItemLink("player", invSlot) then
                    local prevSize = BagSizes[bagId] or 0
                    if prevSize > 0 then
                        for slot = 1, prevSize do
                            Slots:Remove(bagId, slot)
                        end
                        BagSizes[bagId] = 0
                        sendMessage("BAG_EMPTIED", bagId, prevSize)
                    end
                end

                if not next(pendingCleanups) then
                    self:Hide()
                end
            end
        end
    end)

    scheduleDeferredBagCheck = function(bagId)
        if pendingCleanups[bagId] then return end
        pendingCleanups[bagId] = GetTime() + 0.5
        cleanupFrame:Show()
    end

    -- Iterate bags
    local function forEachBag(func)
        func(KEYRING_CONTAINER)
        for bag = BACKPACK_CONTAINER, BACKPACK_CONTAINER + NUM_BAG_SLOTS do
            func(bag)
        end
        if AtBank then
            func(BANK_CONTAINER)
            for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
                func(bag)
            end
        end
    end

    -- Event handlers
    local eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if not mod.BagsterModule.applied then return end
        if event == "PLAYER_LOGIN" then
            forEachBag(updateBag)
        elseif event == "BAG_UPDATE" then
            local bag = ...
            updateBag(bag)
            if AtBank and mod("BankCache"):IsBankStorage(bag) then
                if bag == BANK_CONTAINER then
                    for slot = 1, NUM_BANKGENERIC_SLOTS do
                        mod("BankCache"):SaveBankSlot(slot)
                    end
                else
                    mod("BankCache"):ScanBankBag(bag)
                end
            end
        elseif event == "BAG_UPDATE_COOLDOWN" then
            forEachBag(updateCooldowns)
        elseif event == "PLAYERBANKSLOTS_CHANGED" then
            local slotId = ...
            if slotId and slotId > NUM_BANKGENERIC_SLOTS then
                local bagId = (slotId - NUM_BANKGENERIC_SLOTS) + NUM_BAG_SLOTS
                updateBag(bagId)
            else
                updateBag(BANK_CONTAINER)
            end
            mod("BankCache"):OnBankSlotsChanged(slotId)
        elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
            if AtBank then
                mod("BankCache"):ScanBankAll()
            end
        end
    end)
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

    -- Bank detection (Show/Hide pattern)
    local bankWatcher = CreateFrame("Frame")
    bankWatcher:Hide()

    bankWatcher:SetScript("OnShow", function(self)
        AtBank = true
        updateBag(BANK_CONTAINER)
        forEachBag(updateBag)
        mod("BankCache"):ScanBankAll()
        sendMessage("BANK_OPENED")
        -- After first open, simplify subsequent handler
        self:SetScript("OnShow", function(self)
            AtBank = true
            mod("BankCache"):ScanBankAll()
            sendMessage("BANK_OPENED")
        end)
    end)

    bankWatcher:SetScript("OnHide", function(self)
        AtBank = false
        sendMessage("BANK_CLOSED")
    end)

    bankWatcher:SetScript("OnEvent", function(self, event)
        if not mod.BagsterModule.applied then return end
        if event == "BANKFRAME_OPENED" then
            self:Show()
        else
            self:Hide()
        end
    end)
    bankWatcher:RegisterEvent("BANKFRAME_OPENED")
    bankWatcher:RegisterEvent("BANKFRAME_CLOSED")
end

-- ============================================================================
-- BANK CACHE (offline bank view)
-- ============================================================================

do
    local BankCache = mod:NewModule("BankCache")

    local function getCharKey()
        return (GetRealmName() or "") .. "|" .. mod.playerName
    end

    local function getCharCache()
        if not addon.db or not addon.db.global then return end
        local root = addon.db.global.bagsterCache
        if not root then
            addon.db.global.bagsterCache = {}
            root = addon.db.global.bagsterCache
        end
        local key = getCharKey()
        if not root[key] then
            root[key] = { bank = { slots = {} }, bankBags = {} }
        end
        return root[key]
    end

    function BankCache:IsBankStorage(bag)
        return bag == BANK_CONTAINER or (bag > NUM_BAG_SLOTS and bag <= NUM_BAG_SLOTS + NUM_BANKBAGSLOTS)
    end

    function BankCache:SaveBankSlot(slot)
        if not mod("InventoryEvents"):AtBank() then return end
        local cache = getCharCache()
        if not cache then return end
        cache.bank.slots = cache.bank.slots or {}
        local _, count, _, _, _, _, link = GetContainerItemInfo(BANK_CONTAINER, slot)
        if link then
            cache.bank.slots[slot] = { link = link, count = count }
        else
            cache.bank.slots[slot] = nil
        end
        cache.bank.lastScan = time()
    end

    function BankCache:ScanBankBag(bag)
        if not mod("InventoryEvents"):AtBank() then return end
        local cache = getCharCache()
        if not cache then return end

        local invSlot = BankButtonIDToInvSlotID(bag, 1)
        local bagLink = invSlot and GetInventoryItemLink("player", invSlot)
        if not bagLink then
            cache.bankBags[bag] = nil
            return
        end

        local size = GetContainerNumSlots(bag)
        local bagCache = { size = size, link = bagLink, slots = {} }
        for slot = 1, size do
            local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
            if link then
                bagCache.slots[slot] = { link = link, count = count }
            end
        end
        cache.bankBags[bag] = bagCache
    end

    function BankCache:ScanBankAll()
        if not mod("InventoryEvents"):AtBank() then return end
        local cache = getCharCache()
        if not cache then return end

        cache.bank.slots = cache.bank.slots or {}
        for slot = 1, NUM_BANKGENERIC_SLOTS do
            self:SaveBankSlot(slot)
        end

        for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            self:ScanBankBag(bag)
        end
    end

    function BankCache:OnBankSlotsChanged(slotId)
        if not mod("InventoryEvents"):AtBank() then return end
        if not slotId or slotId <= NUM_BANKGENERIC_SLOTS then
            if slotId then
                self:SaveBankSlot(slotId)
            else
                for slot = 1, NUM_BANKGENERIC_SLOTS do
                    self:SaveBankSlot(slot)
                end
            end
        else
            local bagId = (slotId - NUM_BANKGENERIC_SLOTS) + NUM_BAG_SLOTS
            self:ScanBankBag(bagId)
        end
    end

    function BankCache:GetCachedItem(bag, slot)
        local cache = getCharCache()
        if not cache then return end

        if bag == BANK_CONTAINER then
            local entry = cache.bank.slots and cache.bank.slots[slot]
            if entry and entry.link then
                return entry.link, entry.count
            end
            return
        end

        local bagCache = cache.bankBags[bag]
        if bagCache and bagCache.slots then
            local entry = bagCache.slots[slot]
            if entry and entry.link then
                return entry.link, entry.count
            end
        end
    end

    function BankCache:GetCachedBagSize(bag)
        local cache = getCharCache()
        if not cache then return end
        local bagCache = cache.bankBags[bag]
        if bagCache and bagCache.size and bagCache.size > 0 then
            return bagCache.size
        end
    end

    function BankCache:GetCachedBagLink(bag)
        local cache = getCharCache()
        if not cache then return end
        local bagCache = cache.bankBags[bag]
        if bagCache and bagCache.link then
            return bagCache.link
        end
    end

    mod.BankCache = BankCache
end

-- ============================================================================
-- PLAYER INFO
-- ============================================================================

do
    local PlayerInfo = mod:NewModule("PlayerInfo")

    function PlayerInfo:AtBank()
        return mod("InventoryEvents"):AtBank()
    end

    function PlayerInfo:GetMoney(player)
        if player == mod.playerName then
            return GetMoney()
        end
        return (addon.GetCharacterMoney and addon.GetCharacterMoney(player)) or 0
    end
end

-- ============================================================================
-- BAG SLOT INFO
-- ============================================================================

do
    local BagSlotInfo = mod:NewModule("BagSlotInfo")

    local IsBank = {}
    IsBank[BANK_CONTAINER] = true

    function BagSlotInfo:IsBank(bag)
        return IsBank[bag]
    end

    function BagSlotInfo:IsBankBag(bag)
        return bag > NUM_BAG_SLOTS and bag <= NUM_BAG_SLOTS + NUM_BANKBAGSLOTS
    end

    function BagSlotInfo:IsBackpack(bag)
        return bag == BACKPACK_CONTAINER
    end

    function BagSlotInfo:IsKeyRing(bag)
        return bag == KEYRING_CONTAINER
    end

    function BagSlotInfo:IsCached(player, bag)
        if player ~= mod.playerName then
            return true
        end
        if self:IsBank(bag) or self:IsBankBag(bag) then
            return not mod("InventoryEvents"):AtBank()
        end
        return false
    end

    function BagSlotInfo:IsBackpackBag(bag)
        return bag > 0 and bag < (NUM_BAG_SLOTS + 1)
    end

    function BagSlotInfo:IsEquipped(player, bag)
        if player ~= mod.playerName then return false end
        -- Non-slot containers are always "equipped" by definition.
        if self:IsBackpack(bag) or self:IsBank(bag) or self:IsKeyRing(bag) then
            return true
        end
        if self:IsBankBag(bag) then
            if mod("InventoryEvents"):AtBank() then
                return true
            end
            -- Offline: only if ScanBankBag cached this bag (unlocks GetCachedBagSize/GetCachedItem).
            return mod("BankCache"):GetCachedBagSize(bag) ~= nil
        end
        -- For bag slots 1-4, verify the inventory slot actually has a bag.
        local invSlot = self:ToInventorySlot(bag)
        if invSlot then
            return GetInventoryItemLink("player", invSlot) ~= nil
        end
        return false
    end

    function BagSlotInfo:GetSize(player, bag)
        if player == mod.playerName then
            -- If the bag is not equipped, return 0 regardless of what
            -- GetContainerNumSlots may cache (some 3.3.5a servers return
            -- stale values after unequip).
            if not self:IsEquipped(player, bag) then
                return 0
            end

            if bag == KEYRING_CONTAINER then
                return GetKeyRingSize()
            elseif bag == BANK_CONTAINER then
                return NUM_BANKGENERIC_SLOTS
            elseif self:IsBankBag(bag) and not mod("InventoryEvents"):AtBank() then
                local cachedSize = mod("BankCache"):GetCachedBagSize(bag)
                if cachedSize then
                    return cachedSize
                end
            end
            return GetContainerNumSlots(bag)
        end
        return 0
    end

    function BagSlotInfo:GetBagType(player, bag)
        if self:IsBank(bag) or self:IsBackpack(bag) then
            return 0
        end
        -- keyring family is 9
        if self:IsKeyRing(bag) then
            return 9
        end
        if player == mod.playerName then
            -- Live container family (herb/enchant/…); matches InventoryEvents BagTypes
            if not self:IsCached(player, bag) then
                local _, bagType = GetContainerNumFreeSlots(bag)
                if bagType then
                    return bagType
                end
            end
            local itemLink = self:GetItemInfo(player, bag)
            if itemLink then
                return GetItemFamily(itemLink)
            end
        end
        return 0
    end

    function BagSlotInfo:IsTradeBag(player, bag)
        -- Keyring family is non-zero but empty slots must not use trade-bag tint
        if self:IsKeyRing(bag) then return false end
        return (self:GetBagType(player, bag) or 0) > 0
    end

    function BagSlotInfo:ToInventorySlot(bag)
        if self:IsBackpack(bag) or self:IsBank(bag) or self:IsKeyRing(bag) then return nil end
        if self:IsBankBag(bag) then
            return BankButtonIDToInvSlotID(bag, 1)
        end
        return ContainerIDToInventoryID(bag)
    end

    function BagSlotInfo:IsLocked(player, bag)
        if self:IsBackpack(bag) or self:IsBank(bag) or self:IsKeyRing(bag) or self:IsCached(player, bag) then
            return false
        end
        return IsInventoryItemLocked(self:ToInventorySlot(bag))
    end

    function BagSlotInfo:IsPurchasable(player, bag)
        if not self:IsBankBag(bag) then return false end
        local purchasedSlots = GetNumBankSlots()
        return bag > (purchasedSlots + NUM_BAG_SLOTS)
    end

    function BagSlotInfo:GetItemInfo(player, bag)
        if self:IsBackpack(bag) or self:IsBank(bag) then return nil end
        if player == mod.playerName then
            if self:IsBankBag(bag) and not mod("InventoryEvents"):AtBank() then
                local link = mod("BankCache"):GetCachedBagLink(bag)
                if link then
                    return link, 1, GetItemIcon(link)
                end
                return nil
            end
            local invSlot = self:ToInventorySlot(bag)
            if invSlot then
                local link = GetInventoryItemLink("player", invSlot)
                local texture = GetInventoryItemTexture("player", invSlot)
                local count = GetInventoryItemCount("player", invSlot)
                return link, count, texture
            end
        end
        return nil
    end

    -- Global reference for other modules
    mod.BagSlotInfo = BagSlotInfo
end

-- ============================================================================
-- ITEM SLOT INFO
-- ============================================================================

do
    local ItemSlotInfo = mod:NewModule("ItemSlotInfo")

    function ItemSlotInfo:GetItemInfo(player, bag, slot)
        if player ~= mod.playerName then
            return nil
        end

        local BagSlotInfo = mod.BagSlotInfo
        -- If the bag is not equipped, return nil immediately.
        -- GetContainerItemInfo may return stale cached data on some
        -- 3.3.5a servers after a bag has been unequipped.
        if not BagSlotInfo:IsEquipped(player, bag) then
            return nil
        end

        local isBankStorage = BagSlotInfo:IsBank(bag) or BagSlotInfo:IsBankBag(bag)
        if isBankStorage and not mod("InventoryEvents"):AtBank() then
            local link, count = mod("BankCache"):GetCachedItem(bag, slot)
            if not link then
                return nil
            end
            local texture = GetItemIcon(link)
            local quality = select(3, GetItemInfo(link))
            return texture, count, false, quality, false, false, link
        end

        local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
        if link and quality and quality < 0 then
            quality = select(3, GetItemInfo(link))
        end
        return texture, count, locked, quality, readable, lootable, link
    end

    function ItemSlotInfo:IsLocked(player, bag, slot)
        if self:IsCached(player, bag, slot) then
            return false
        end
        return select(3, GetContainerItemInfo(bag, slot))
    end

    function ItemSlotInfo:IsCached(player, bag, slot)
        return mod("BagSlotInfo"):IsCached(player, bag)
    end

    mod.ItemSlotInfo = ItemSlotInfo
end
