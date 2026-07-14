local addon = select(2, ...)
local mod = addon.CombuctorModule
-- ============================================================================
-- COMBUCTOR CLASSES MODULE
-- Contains all UI class definitions: ItemSlot, ItemFrame, Bag, MoneyFrame,
-- TokenBar, FilterButton/QualityFilter, SideTab/SideFilter, BottomTab/BottomFilter.
--
-- Load order: combuctor.lua -> combuctor_data.lua -> combuctor_sets.lua ->
--             combuctor_classes.lua -> combuctor_frame.lua -> combuctor_system.lua
-- ============================================================================


local format = string.format

-- ============================================================================
-- TEMPLATE HELPERS (moved from core: used by SideTab and BottomTab)
-- ============================================================================

-- DragonUI_CombuctorSideTabButtonTemplate
local function SetupSideTabButton(btn)
    btn:SetSize(32, 32)
    btn:Hide()

    -- $parentBorder: SpellBook-SkillLineTab
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    border:SetSize(64, 64)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 11)
    btn._BagSkin_SideBorder = border

    -- NormalTexture (blank so GetNormalTexture() works)
    btn:SetNormalTexture("")

    -- HighlightTexture
    local ht = btn:CreateTexture(nil, "HIGHLIGHT")
    ht:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    ht:SetBlendMode("ADD")
    btn:SetHighlightTexture(ht)

    -- CheckedTexture
    local ct = btn:CreateTexture(nil, "HIGHLIGHT")
    ct:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    ct:SetBlendMode("ADD")
    btn:SetCheckedTexture(ct)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip)
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
end

-- DragonUI_CombuctorFrameTabButtonTemplate
local function SetupBottomTabButton(btn)
    btn:SetFrameLevel(btn:GetFrameLevel() + 4)
end

-- ============================================================================
-- QUALITY FLAGS
-- ============================================================================

mod.QualityFlags = {}
for i = 0, 7 do
    mod.QualityFlags[i] = 2 ^ i
end

do
    local ItemSlot = mod:NewClass("Button")
    mod.ItemSlot = ItemSlot

    local BagSlotInfo = mod.BagSlotInfo
    local ItemSlotInfo = mod.ItemSlotInfo
    local PlayerInfo = mod("PlayerInfo")

    local unused = {}
    local id = 1

    local function DebugItemSlot(btn)
        local name = btn:GetName() or "?"
        print("=== " .. name .. " ===")
        print("NormalTexture:", btn:GetNormalTexture() and btn:GetNormalTexture():GetTexture() or "nil")
        local i = 0
        for _, region in ipairs({ btn:GetRegions() }) do
            i = i + 1
            if region:GetObjectType() == 'Texture' then
                local layer, sublayer = region:GetDrawLayer()
                print(string.format("  Region %d: layer=%s sublayer=%d tex=%s alpha=%.2f",
                    i, layer, sublayer or 0,
                    tostring(region:GetTexture()):sub(1, 40),
                    region:GetAlpha()))
            end
        end
    end

    function ItemSlot:GetNextItemSlotID()
        local nextID = id
        id = id + 1
        return nextID
    end

    function ItemSlot:New()
        local item = next(unused)
        if item then
            unused[item] = nil
            return item
        end

        local itemID = self:GetNextItemSlotID()
        local item = self:Bind(CreateFrame("Button", format("DragonUI_CombuctorItem%d", itemID), nil, "ContainerFrameItemButtonTemplate"))

        local name = item:GetName()
        item:SetID(itemID)
        item:SetScript("OnEnter", self.OnEnter)
        item:SetScript("OnLeave", self.OnLeave)
        item:SetScript("OnShow", self.OnShow)
        item:SetScript("OnHide", self.OnHide)
        item:SetScript("OnUpdate", self.OnUpdate)
        item:RegisterForClicks("anyUp")
        item.UpdateTooltip = nil

        -- Quality border (gold ring for uncommon+ items)
        local border = item:CreateTexture(nil, "OVERLAY")
        border:SetWidth(67)
        border:SetHeight(67)
        border:SetPoint("CENTER", item, "CENTER", 0, -1)
        border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
        border:SetBlendMode("ADD")
        border:SetDrawLayer("OVERLAY", 3)
        border:Hide()
        item.border = border

        -- Kill template's built-in IconQuestTexture and IconBorder to avoid overlap
        local templateQuest = _G[name .. "IconQuestTexture"]
        if templateQuest then
            templateQuest:SetTexture(nil)
            templateQuest:Hide()
        end
        local templateBorder = _G[name .. "IconBorder"]
        if templateBorder then
            templateBorder:Hide()
        end

        -- Quest item border (yellow overlay for quest items)
        local questBorder = item:CreateTexture(nil, "OVERLAY")
        questBorder:SetSize(item:GetWidth(), item:GetHeight())
        questBorder:SetPoint("CENTER")
        questBorder:SetTexture(mod.TEXTURE_ITEM_QUEST_BORDER)
        questBorder:SetDrawLayer("OVERLAY", 4)
        questBorder:Hide()
        item.questBorder = questBorder

        -- Cooldown
        item.cooldown = _G[name .. "Cooldown"]

        return item
    end

    function ItemSlot:Free()
        self:Hide()
        self:SetParent(nil)
        self:UnlockHighlight()
        unused[self] = true
    end

    function ItemSlot:Set(parent, bag, slot)
        self:SetParent(ItemSlot:GetDummyBag(parent, bag))
        self:SetID(slot)
        self:Update()

        -- Apply retail skin from bags_skin module (if available).
        -- The _BagSkin_Applied guard prevents duplicate work.
        -- This is necessary because ItemSlots are created dynamically
        -- and mod.CombuctorSkinItems() may run before the slot exists.
        if not self._BagSkin_Applied then
            mod.CombuctorRetailItemSlot(self)
        end
    end

    function ItemSlot:OnShow()
        self:Update()
    end

    function ItemSlot:OnHide()
        if self.hasStackSplit and self.hasStackSplit == 1 then
            StackSplitFrame:Hide()
        end
    end

    function ItemSlot:OnEnter()
        local dummySlot = self:GetDummyItemSlot()
        if self:IsCached() then
            dummySlot:SetParent(self)
            dummySlot:SetAllPoints(self)
            dummySlot:Show()
        else
            dummySlot:Hide()
            self._lastShiftState = nil  -- reset so OnUpdate detects shift on first hover
            if self:IsBank() then
                -- BANK_CONTAINER slots: use SetInventoryItem (bank-specific API)
                if self:GetItem() then
                    self:AnchorTooltip()
                    GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(self:GetID()))
                    GameTooltip:Show()
                    CursorUpdate(self)
                    if IsModifiedClick("COMPAREITEMS") then
                        GameTooltip_ShowCompareItem()
                    end
                    self.UpdateTooltip = self.OnEnter
                end
            else
                -- Inventory/bank-bag slots: native Blizzard handler correctly shows
                -- Soulbound, durability, and handles initial shift+compare
                ContainerFrameItemButton_OnEnter(self)
                -- Keep tooltip content in sync while the hovered slot updates
                -- (for example, right-click equip swaps the hovered item).
                self.UpdateTooltip = ContainerFrameItemButton_OnEnter
            end
        end
    end

    function ItemSlot:OnUpdate()
        -- Detect shift key state change WHILE hovering and show/hide the comparison
        -- tooltip WITHOUT rebuilding the main GameTooltip (which would corrupt
        -- Soulbound/durability text).
        if not self:IsMouseOver() or self:IsCached() then
            self._lastShiftState = nil
            return
        end
        if not GameTooltip:IsOwned(self) then return end
        local shiftDown = IsModifiedClick("COMPAREITEMS")
        if self._lastShiftState == shiftDown then return end
        self._lastShiftState = shiftDown
        if shiftDown then
            -- Shift just pressed: show comparison side-tooltip (does NOT touch main GameTooltip)
            GameTooltip_ShowCompareItem()
        else
            -- Shift released: hide comparison side-tooltips
            if GameTooltip.shoppingTooltips then
                for _, tt in ipairs(GameTooltip.shoppingTooltips) do
                    tt:Hide()
                end
            end
        end
    end

    function ItemSlot:OnLeave()
        self._lastShiftState = nil
        self.UpdateTooltip = nil
        GameTooltip:Hide()
        if GameTooltip.shoppingTooltips then
            for _, tt in ipairs(GameTooltip.shoppingTooltips) do
                tt:Hide()
            end
        end
        ResetCursor()
    end

    function ItemSlot:OnModifiedClick(button)
        local link = self:IsCached() and self:GetItem()
        if link then
            HandleModifiedItemClick(link)
        end
    end

    function ItemSlot:Update()
        if not self:IsVisible() then return end

        local texture, count, locked, quality, readable, lootable, link = self:GetItemSlotInfo()
        self:SetItem(link)
        self:SetTexture(texture)
        self:SetCount(count)
        self:SetLocked(locked)
        self:SetReadable(readable)
        self:SetBorderQuality(quality)
        self:UpdateSlotColor()
        self:UpdateCooldown()
        if GameTooltip:IsOwned(self) and self.UpdateTooltip then
            self:UpdateTooltip()
        end
    end

    function ItemSlot:SetItem(itemLink)
        self.hasItem = itemLink or nil
    end

    function ItemSlot:GetItem()
        return self.hasItem
    end

    function ItemSlot:SetTexture(texture)
        SetItemButtonTexture(self, texture)
    end

    function ItemSlot:GetEmptyItemTexture()
        return [[Interface\PaperDoll\UI-Backpack-EmptySlot]]
    end

    function ItemSlot:UpdateSlotColor()
        if (not self:GetItem()) and self:IsTradeBagSlot() then
            SetItemButtonTextureVertexColor(self, 0.5, 1, 0.5)
            return
        end
        SetItemButtonTextureVertexColor(self, 1, 1, 1)
    end

    function ItemSlot:SetCount(count)
        SetItemButtonCount(self, count)
    end

    function ItemSlot:SetReadable(readable)
        self.readable = readable
    end

    function ItemSlot:SetLocked(locked)
        SetItemButtonDesaturated(self, locked)
    end

    function ItemSlot:UpdateLocked()
        self:SetLocked(self:IsLocked())
    end

    function ItemSlot:IsLocked()
        return ItemSlotInfo:IsLocked(self:GetPlayer(), self:GetBag(), self:GetID())
    end

    function ItemSlot:UpdateCooldown()
        if self:GetItem() and not self:IsCached() then
            local start, duration, enable = GetContainerItemCooldown(self:GetBag(), self:GetID())
            CooldownFrame_SetTimer(self.cooldown, start or 0, duration or 0, enable or 0)
        else
            CooldownFrame_SetTimer(self.cooldown, 0, 0, 0)
            SetItemButtonTextureVertexColor(self, 1, 1, 1)
        end
    end

    function ItemSlot:SetBorderQuality(quality)
        local border = self.border
        local qBorder = self.questBorder

        -- Quest item check
        local isQuestItem, isQuestStarter = self:IsQuestItem()
        if isQuestItem then
            qBorder:SetTexture(mod.TEXTURE_ITEM_QUEST_BORDER)
            qBorder:SetAlpha(1)
            qBorder:Show()
            border:Hide()
            return
        end
        if isQuestStarter then
            qBorder:SetTexture(mod.TEXTURE_ITEM_QUEST_BANG)
            qBorder:SetAlpha(1)
            qBorder:Show()
            border:Hide()
            return
        end

        -- Quality border
        if self:GetItem() and quality and quality > 1 then
            local r, g, b = GetItemQualityColor(quality)
            border:SetVertexColor(r, g, b, 0.5)
            border:Show()
            qBorder:Hide()
            return
        end

        qBorder:Hide()
        border:Hide()
    end

    function ItemSlot:UpdateBorder()
        local _, _, _, quality = self:GetItemSlotInfo()
        self:SetBorderQuality(quality)
    end

    -- UpdateTooltip is set to nil per-instance in Create() to prevent
    -- Update() from re-triggering OnEnter and clearing bank tooltips.
    ItemSlot.UpdateTooltip = nil

    function ItemSlot:AnchorTooltip()
        if self:GetRight() >= (GetScreenWidth() / 2) then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        else
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        end
    end

    function ItemSlot:Highlight(enable)
        if enable then
            self:LockHighlight()
        else
            self:UnlockHighlight()
        end
    end

    function ItemSlot:GetPlayer()
        local player
        if self:GetParent() then
            local p = self:GetParent():GetParent()
            player = p and p.GetPlayer and p:GetPlayer()
        end
        return player or mod.playerName
    end

    function ItemSlot:GetBag()
        return self:GetParent() and self:GetParent():GetID() or -1
    end

    function ItemSlot:IsSlot(bag, slot)
        return self:GetBag() == bag and self:GetID() == slot
    end

    function ItemSlot:IsCached()
        return BagSlotInfo:IsCached(self:GetPlayer(), self:GetBag())
    end

    function ItemSlot:IsBank()
        return BagSlotInfo:IsBank(self:GetBag())
    end

    function ItemSlot:IsBankSlot()
        local bag = self:GetBag()
        return BagSlotInfo:IsBank(bag) or BagSlotInfo:IsBankBag(bag)
    end

    function ItemSlot:AtBank()
        return PlayerInfo:AtBank()
    end

    function ItemSlot:GetItemSlotInfo()
        return ItemSlotInfo:GetItemInfo(self:GetPlayer(), self:GetBag(), self:GetID())
    end

    local QUEST_ITEM_SEARCH = format("t:%s|%s", select(10, GetAuctionItemClasses()), "quest")
    function ItemSlot:IsQuestItem()
        local itemLink = self:GetItem()
        if not itemLink then return false, false end
        if self:IsCached() then
            return mod.ItemSearch:Find(itemLink, QUEST_ITEM_SEARCH), false
        else
            local isQuestItem, questID, isActive = GetContainerItemQuestInfo(self:GetBag(), self:GetID())
            return isQuestItem, (questID and not isActive)
        end
    end

    function ItemSlot:IsTradeBagSlot()
        return BagSlotInfo:IsTradeBag(self:GetPlayer(), self:GetBag())
    end

    function ItemSlot:GetDummyBag(parent, bag)
        local dummyBags = parent.dummyBags
        if not dummyBags then
            dummyBags = setmetatable({}, { __index = function(t, k)
                local f = CreateFrame("Frame", nil, parent)
                f:SetID(k)
                t[k] = f
                return f
            end })
            parent.dummyBags = dummyBags
        end
        return dummyBags[bag]
    end

    function ItemSlot:GetDummyItemSlot()
        if not ItemSlot.dummySlot then
            ItemSlot.dummySlot = ItemSlot:CreateDummyItemSlot()
        end
        return ItemSlot.dummySlot
    end

    function ItemSlot:CreateDummyItemSlot()
        local slot = CreateFrame("Button")
        slot:RegisterForClicks("anyUp")
        slot:SetToplevel(true)
        slot:Hide()

        local function Slot_OnEnter(self)
            local parent = self:GetParent()
            parent:LockHighlight()
            if parent:IsCached() and parent:GetItem() then
                ItemSlot.AnchorTooltip(self)
                GameTooltip:SetHyperlink(parent:GetItem())
                GameTooltip:Show()
            end
        end

        local function Slot_OnLeave(self)
            GameTooltip:Hide()
            self:Hide()
        end

        local function Slot_OnHide(self)
            local parent = self:GetParent()
            if parent then parent:UnlockHighlight() end
        end

        local function Slot_OnClick(self, button)
            self:GetParent():OnModifiedClick(button)
        end

        slot.UpdateTooltip = Slot_OnEnter
        slot:SetScript("OnClick", Slot_OnClick)
        slot:SetScript("OnEnter", Slot_OnEnter)
        slot:SetScript("OnLeave", Slot_OnLeave)
        slot:SetScript("OnShow", Slot_OnEnter)
        slot:SetScript("OnHide", Slot_OnHide)

        return slot
    end
end

do
    local FrameEvents = mod:NewModule("ItemFrameEvents")
    local frames = {}

    function FrameEvents:ITEM_LOCK_CHANGED(msg, ...) self:UpdateSlotLock(...) end
    function FrameEvents:ITEM_SLOT_ADD(msg, ...) self:UpdateSlot(...) end
    function FrameEvents:ITEM_SLOT_REMOVE(msg, ...) self:RemoveItem(...) end

    function FrameEvents:ITEM_SLOT_UPDATE(msg, ...) self:UpdateSlot(...) end
    function FrameEvents:ITEM_SLOT_UPDATE_COOLDOWN(msg, ...) self:UpdateSlotCooldown(...) end
    function FrameEvents:BANK_OPENED(msg, ...) self:UpdateBankFrames(...) end
    function FrameEvents:BANK_CLOSED(msg, ...) self:UpdateBankFrames(...) end
    function FrameEvents:BAG_UPDATE_TYPE(msg, ...) self:UpdateSlotColor(...) end
    function FrameEvents:BAG_EMPTIED(msg, bag, prevSize)
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then
                -- Remove stale items first (Regenerate won't clean them
                -- because GetBagSize(bag) returns 0 for unequipped bags,
                -- so the bag's items would remain in self.items).
                for slot = 1, prevSize do
                    f:RemoveItem(bag, slot)
                end
                f:Regenerate()
                f:RequestLayout()
            end
        end
    end

    function FrameEvents:UpdateSlotColor(...)
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then f:UpdateSlotColor(...) end
        end
    end

    function FrameEvents:UpdateSlot(...)
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then
                if f:UpdateSlot(...) then f:RequestLayout() end
            end
        end
    end

    function FrameEvents:RemoveItem(...)
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then
                if f:RemoveItem(...) then f:RequestLayout() end
            end
        end
    end

    function FrameEvents:UpdateSlotLock(...)
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then f:UpdateSlotLock(...) end
        end
    end

    function FrameEvents:UpdateSlotCooldown(...)
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then f:UpdateSlotCooldown(...) end
        end
    end

    function FrameEvents:UpdateBankFrames()
        for f in self:GetFrames() do f:Regenerate() end
    end

    function FrameEvents:LayoutFrames()
        for f in self:GetFrames() do
            if f.needsLayout then
                f.needsLayout = nil
                f:Layout()
            end
        end
    end

    function FrameEvents:RequestLayout()
        self.Updater:Show()
    end

    function FrameEvents:GetFrames()
        return pairs(frames)
    end

    function FrameEvents:Register(f)
        frames[f] = true
    end

    function FrameEvents:Unregister(f)
        frames[f] = nil
    end

    -- Initialization
    do
        local f = CreateFrame("Frame")
        f:Hide()
        f:SetScript("OnEvent", function(self, event, ...)
            local method = FrameEvents[event]
            if method then method(FrameEvents, event, ...) end
        end)
        f:SetScript("OnUpdate", function(self)
            FrameEvents:LayoutFrames()
            self:Hide()
        end)
        f:RegisterEvent("ITEM_LOCK_CHANGED")
        f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
        f:RegisterEvent("QUEST_ACCEPTED")
        FrameEvents.Updater = f

        mod("InventoryEvents"):RegisterMany(
            FrameEvents,
            "ITEM_SLOT_ADD", "ITEM_SLOT_REMOVE", "ITEM_SLOT_UPDATE",
            "ITEM_SLOT_UPDATE_COOLDOWN", "BANK_OPENED", "BANK_CLOSED", "BAG_UPDATE_TYPE",
            "BAG_EMPTIED"
        )
    end
end

do
    local ItemFrame = mod:NewClass("Button")
    mod.ItemFrame = ItemFrame

    local FrameEvents = mod("ItemFrameEvents")
    local BagSlotInfo = mod.BagSlotInfo
    local ItemSlotInfo = mod.ItemSlotInfo

    local function ToIndex(bag, slot)
        return (bag < 0 and bag * 100 - slot) or (bag * 100 + slot)
    end

    function ItemFrame:New(parent)
        local f = self:Bind(CreateFrame("Button", nil, parent))
        f.items = {}
        f.bags = parent.sets.bags
        f.filter = parent.filter
        f.count = 0
        f:RegisterForClicks("anyUp")
        f:SetScript("OnShow", self.OnShow)
        f:SetScript("OnHide", self.OnHide)
        f:SetScript("OnClick", self.PlaceItem)
        return f
    end

    function ItemFrame:OnShow()
        self:UpdateUpdatable()
        self:Regenerate()
    end

    function ItemFrame:OnHide()
        self:UpdateUpdatable()
    end

    function ItemFrame:UpdateUpdatable()
        if self:IsVisible() then
            FrameEvents:Register(self)
        else
            FrameEvents:Unregister(self)
        end
    end

    function ItemFrame:SetPlayer(player)
        self.player = player
        self:ReloadAllItems()
    end

    function ItemFrame:GetPlayer()
        return self.player or mod.playerName
    end

    function ItemFrame:HasItem(bag, slot, link)
        local hasBag = false
        for _, bagID in pairs(self.bags) do
            if bag == bagID then hasBag = true; break end
        end
        if not hasBag then return false end

        local f = self.filter
        if next(f) then
            local player = self:GetPlayer()
            local bagType = self:GetBagType(bag)
            link = link or self:GetItemLink(bag, slot)

            local name, quality, level, ilvl, itemType, subType, stackCount, equipLoc
            if link then
                name, link, quality, level, ilvl, itemType, subType, stackCount, equipLoc = GetItemInfo(link)
            end

            if f.quality and f.quality > 0 and not (quality and bit.band(f.quality, mod.QualityFlags[quality] or 0) > 0) then
                return false
            elseif f.rule and not f.rule(player, bagType, name, link, quality, level, ilvl, itemType, subType, stackCount, equipLoc) then
                return false
            elseif f.subRule and not f.subRule(player, bagType, name, link, quality, level, ilvl, itemType, subType, stackCount, equipLoc) then
                return false
            elseif f.name then
                return mod.ItemSearch:Find(link, f.name)
            end
        end
        return true
    end

    function ItemFrame:AddItem(bag, slot)
        local index = ToIndex(bag, slot)
        local item = self.items[index]
        if item then
            item:Update()
            item:Highlight(self.highlightBag == bag)
        else
            item = mod.ItemSlot:New()
            item:Set(self, bag, slot)
            item:Highlight(self.highlightBag == bag)
            self.items[index] = item
            self.count = self.count + 1
            return true
        end
    end

    function ItemFrame:RemoveItem(bag, slot)
        local index = ToIndex(bag, slot)
        local item = self.items[index]
        if item then
            item:Free()
            self.items[index] = nil
            self.count = self.count - 1
            return true
        end
    end

    function ItemFrame:UpdateSlot(bag, slot, link)
        if self:HasItem(bag, slot, link) then
            return self:AddItem(bag, slot)
        end
        return self:RemoveItem(bag, slot)
    end

    function ItemFrame:UpdateSlotLock(bag, slot)
        if not slot then return end
        local item = self.items[ToIndex(bag, slot)]
        if item then item:UpdateLocked() end
    end

    function ItemFrame:UpdateSlotCooldown(bag, slot)
        local item = self.items[ToIndex(bag, slot)]
        if item then item:UpdateCooldown() end
    end

    function ItemFrame:UpdateSlotColor(bagId)
        for _, item in pairs(self.items) do
            if item:GetBag() == bagId then item:UpdateSlotColor() end
        end
    end

    function ItemFrame:Regenerate()
        if not self:IsVisible() then return end
        local changed = false
        for _, bag in pairs(self.bags) do
            for slot = 1, self:GetBagSize(bag) do
                if self:UpdateSlot(bag, slot) then changed = true end
            end
        end
        if changed then self:RequestLayout() end
    end

    function ItemFrame:RemoveAllItems()
        local changed = false
        for i, item in pairs(self.items) do
            changed = true
            item:Free()
            self.items[i] = nil
        end
        self.count = 0
        return changed
    end

    function ItemFrame:ReloadAllItems()
        if self:RemoveAllItems() and self:IsVisible() then
            self:Regenerate()
        end
    end

    function ItemFrame:RequestLayout()
        self.needsLayout = true
        self:TriggerLayout()
    end

    function ItemFrame:TriggerLayout()
        if self:IsVisible() and self.needsLayout then
            FrameEvents:RequestLayout(self)
        end
    end

    function ItemFrame:Layout(spacing)
        local width, height = self:GetWidth(), self:GetHeight()
        spacing = spacing or 2
        local count = self.count
        local size = 36 + spacing * 2
        local cols = 0
        local scale, rows
        local maxScale = mod:GetMaxItemScale()

        repeat
            cols = cols + 1
            scale = width / (size * cols)
            rows = floor(height / (size * scale))
        until (scale <= maxScale and cols * rows >= count)

        local items = self.items
        local i = 0

        for _, bag in ipairs(self.bags) do
            for slot = 1, self:GetBagSize(bag) do
                local item = items[ToIndex(bag, slot)]
                if item then
                    i = i + 1
                    local row = (i - 1) % cols
                    local col = ceil(i / cols) - 1
                    item:ClearAllPoints()
                    item:SetScale(scale)
                    item:SetPoint("TOPLEFT", self, "TOPLEFT", size * row + spacing, -(size * col + spacing))
                    item:Show()
                end
            end
        end
    end

    function ItemFrame:HighlightBag(bag)
        self.highlightBag = bag
        for _, item in pairs(self.items) do
            item:Highlight(item:GetBag() == bag)
        end
    end

    function ItemFrame:GetBagSize(bag)
        return BagSlotInfo:GetSize(self:GetPlayer(), bag)
    end

    function ItemFrame:GetBagType(bag)
        return BagSlotInfo:GetBagType(self:GetPlayer(), bag)
    end

    function ItemFrame:IsBagCached(bag)
        return BagSlotInfo:IsCached(self:GetPlayer(), bag)
    end

    function ItemFrame:GetItemLink(bag, slot)
        return select(7, ItemSlotInfo:GetItemInfo(self:GetPlayer(), bag, slot))
    end

    function ItemFrame:PlaceItem()
        if CursorHasItem() then
            for _, bag in ipairs(self.bags) do
                if not self:IsBagCached(bag) then
                    for slot = 1, self:GetBagSize(bag) do
                        if not GetContainerItemLink(bag, slot) then
                            PickupContainerItem(bag, slot)
                        end
                    end
                end
            end
        end
    end
end

do
    local Bag = mod:NewClass("Button")
    mod.Bag = Bag

    local SIZE = 30
    local NORMAL_TEXTURE_SIZE = 64 * (SIZE / 36)
    local BagSlotInfo = mod.BagSlotInfo
    local unused = {}
    local bagId = 1

    function Bag:New()
        local bag = self:Bind(CreateFrame("Button", format("DragonUI_CombuctorBag%d", bagId)))
        local name = bag:GetName()
        bag:SetSize(SIZE, SIZE)

        -- Expand hit rect to match the visual NormalTexture size
        local inset = (SIZE - NORMAL_TEXTURE_SIZE) / 2
        bag:SetHitRectInsets(inset, inset, inset, inset)

        local icon = bag:CreateTexture(name .. "IconTexture", "BORDER")
        icon:SetAllPoints(bag)

        local count = bag:CreateFontString(name .. "Count", "OVERLAY")
        count:SetFontObject("NumberFontNormalSmall")
        count:SetJustifyH("RIGHT")
        count:SetPoint("BOTTOMRIGHT", -2, 2)

        -- Bag toggle buttons get NO NormalTexture/PushedTexture/HighlightTexture.
        -- Only the IconTexture (bag icon) is shown — clean, no background frame.
        -- Retail skinning is handled independently by bags_skin.lua if enabled.
        local nt = bag:CreateTexture(name .. "NormalTexture")
        nt:SetTexture(nil)
        nt:SetAlpha(0)
        nt:Hide()
        bag:SetNormalTexture(nt)

        local pt = bag:CreateTexture()
        pt:SetTexture(nil)
        pt:SetAlpha(0)
        pt:Hide()
        bag:SetPushedTexture(pt)

        local ht = bag:CreateTexture()
        ht:SetTexture(nil)
        ht:SetAlpha(0)
        ht:Hide()
        bag:SetHighlightTexture(ht)

        bag:RegisterForClicks("anyUp")
        bag:RegisterForDrag("LeftButton")

        bag:SetScript("OnEnter", self.OnEnter)
        bag:SetScript("OnShow", self.OnShow)
        bag:SetScript("OnLeave", self.OnLeave)
        bag:SetScript("OnClick", self.OnClick)
        bag:SetScript("OnDragStart", self.OnDrag)
        bag:SetScript("OnReceiveDrag", self.OnClick)
        bag:SetScript("OnEvent", self.OnEvent)

        bagId = bagId + 1
        return bag
    end

    function Bag:Get()
        local f = next(unused)
        if f then
            unused[f] = nil
            return f
        end
        return self:New()
    end

    function Bag:Set(parent, id)
        self:SetID(id)
        self:SetParent(parent)

        if BagSlotInfo:IsBank(id) or BagSlotInfo:IsBackpack(id) then
            SetItemButtonTexture(self, [[Interface\Buttons\Button-Backpack-Up]])
            SetItemButtonTextureVertexColor(self, 1, 1, 1)
        else
            self:Update()
            self:RegisterEvent("ITEM_LOCK_CHANGED")
            self:RegisterEvent("CURSOR_UPDATE")
            self:RegisterEvent("BAG_UPDATE")
            self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
            if BagSlotInfo:IsBankBag(id) then
                self:RegisterEvent("BANKFRAME_OPENED")
                self:RegisterEvent("BANKFRAME_CLOSED")
                self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
            end

            -- NOTE: Bag toggle dropdown buttons (DragonUI_CombuctorBag1-5)
            -- have blank NormalTexture by default (only icon visible).
            -- CharacterBag0-3Slot skinning is handled by bags_skin.lua.
        end
    end

    function Bag:Release()
        self:Hide()
        self:SetParent(nil)
        self:UnregisterAllEvents()
        _G[self:GetName() .. "Count"]:Hide()
        unused[self] = true
    end

    -- Helper to get the correct inventory slot
    function Bag:GetInventorySlot()
        return BagSlotInfo:ToInventorySlot(self:GetID())
    end

    function Bag:IsBagSlot()
        local id = self:GetID()
        return BagSlotInfo:IsBackpackBag(id) or BagSlotInfo:IsBankBag(id)
    end

    function Bag:IsPurchasable()
        return BagSlotInfo:IsPurchasable(mod.playerName, self:GetID())
    end

    function Bag:Update()
        if not self:IsVisible() then return end
        local id = self:GetID()
        if BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id) then return end

        -- Actualizar bloqueo
        if self:IsBagSlot() then
            SetItemButtonDesaturated(self, BagSlotInfo:IsLocked(mod.playerName, id))
        end

        -- Update slot info (texture)
        if self:IsBagSlot() then
            local link, count, texture = BagSlotInfo:GetItemInfo(mod.playerName, id)
            if link then
                SetItemButtonTexture(self, texture or GetItemIcon(link))
                SetItemButtonTextureVertexColor(self, 1, 1, 1)
            else
                SetItemButtonTexture(self, [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]])
                if self:IsPurchasable() then
                    SetItemButtonTextureVertexColor(self, 1, 0.1, 0.1)
                else
                    SetItemButtonTextureVertexColor(self, 1, 1, 1)
                end
            end
        end

        -- Update cursor highlight
        if self:IsBagSlot() then
            local invSlot = self:GetInventorySlot()
            if invSlot and CursorCanGoInSlot(invSlot) then
                self:LockHighlight()
            else
                self:UnlockHighlight()
            end
        end
    end

    function Bag:OnShow()
        self:Update()
    end

    function Bag:OnEnter()
        local id = self:GetID()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id) then
            GameTooltip:SetText(BACKPACK_TOOLTIP)
        else
            local invSlot = self:GetInventorySlot()
            if invSlot then
                if not GameTooltip:SetInventoryItem("player", invSlot) then
                    if self:IsPurchasable() then
                        GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
                    else
                        GameTooltip:SetText(EQUIP_CONTAINER)
                    end
                end
            else
                GameTooltip:SetText(EQUIP_CONTAINER)
            end
        end
        GameTooltip:Show()
        -- Highlight items in this bag
        local parent = self:GetParent()
        if parent and parent.itemFrame then
            parent.itemFrame:HighlightBag(id)
        end
    end

    function Bag:OnLeave()
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
        local parent = self:GetParent()
        if parent and parent.itemFrame then
            parent.itemFrame:HighlightBag(nil)
        end
    end

    function Bag:OnClick(button)
        local id = self:GetID()
        if BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id) then return end

        if self:IsPurchasable() then
            self:PurchaseSlot()
        elseif CursorHasItem() then
            local invSlot = self:GetInventorySlot()
            if invSlot then
                PutItemInBag(invSlot)
            end
        else
            local invSlot = self:GetInventorySlot()
            if invSlot then
                PickupBagFromSlot(invSlot)
            end
        end
    end

    function Bag:OnDrag()
        local id = self:GetID()
        if not (BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id)) then
            local invSlot = self:GetInventorySlot()
            if invSlot then
                PickupBagFromSlot(invSlot)
            end
        end
    end

    function Bag:PurchaseSlot()
        if not StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_COMBUCTOR"] then
            StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_COMBUCTOR"] = {
                text = CONFIRM_BUY_BANK_SLOT,
                button1 = YES,
                button2 = NO,
                OnAccept = function()
                    PurchaseSlot()
                end,
                OnShow = function(self)
                    MoneyFrame_Update(self:GetName() .. "MoneyFrame", GetBankSlotCost(GetNumBankSlots()))
                end,
                hasMoneyFrame = 1,
                timeout = 0,
                hideOnEscape = 1
            }
        end
        PlaySound("igMainMenuOption")
        StaticPopup_Show("CONFIRM_BUY_BANK_SLOT_COMBUCTOR")
    end

    function Bag:OnEvent(event)
        self:Update()
    end
end

do
    local MoneyFrame = mod:NewClass("Frame")
    mod.MoneyFrame = MoneyFrame

    local moneyId = 1

    function MoneyFrame:OnShow()
        self:Update()
    end

    function MoneyFrame:GetDisplayMode()
        local mc = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.combuctor
        return (mc and mc.money_display) or "icons"
    end

    function MoneyFrame:New(parent)
        local f = self:Bind(CreateFrame("Frame", format("DragonUI_CombuctorMoney%d", moneyId), parent))
        f:SetHeight(19)
        f:SetWidth(120)
        f:SetScript("OnShow", self.OnShow)
        f:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_MONEY" then
                self:Update()
            end
        end)
        f:RegisterEvent("PLAYER_MONEY")
        f:SetFrameLevel(f:GetFrameLevel() + 4)

        -- Coin textures use DragonUI retail-style round icons (20x20 on 32x32 canvas)
        local COIN_TEXCOORD = { 0.1875, 0.8125, 0.1875, 0.8125 }

        -- Copper (ancla a la derecha)
        f.iconCopper = f:CreateTexture(nil, "OVERLAY")
        f.iconCopper:SetTexture(mod.CT.coinCopper)
        f.iconCopper:SetTexCoord(unpack(COIN_TEXCOORD))
        f.iconCopper:SetSize(13, 13)
        f.iconCopper:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        f.amtCopper = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.amtCopper:SetPoint("RIGHT", f.iconCopper, "LEFT", -2, 0)

        -- Silver
        f.iconSilver = f:CreateTexture(nil, "OVERLAY")
        f.iconSilver:SetTexture(mod.CT.coinSilver)
        f.iconSilver:SetTexCoord(unpack(COIN_TEXCOORD))
        f.iconSilver:SetSize(13, 13)
        f.iconSilver:SetPoint("RIGHT", f.amtCopper, "LEFT", -4, 0)
        f.amtSilver = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.amtSilver:SetPoint("RIGHT", f.iconSilver, "LEFT", -2, 0)

        -- Gold
        f.iconGold = f:CreateTexture(nil, "OVERLAY")
        f.iconGold:SetTexture(mod.CT.coinGold)
        f.iconGold:SetTexCoord(unpack(COIN_TEXCOORD))
        f.iconGold:SetSize(13, 13)
        f.iconGold:SetPoint("RIGHT", f.amtSilver, "LEFT", -4, 0)
        f.amtGold = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.amtGold:SetPoint("RIGHT", f.iconGold, "LEFT", -2, 0)

        local txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetAllPoints(f)
        txt:SetJustifyH("RIGHT")
        txt:SetJustifyV("MIDDLE")
        txt:Hide()
        f.textFull = txt

        moneyId = moneyId + 1
        f:Update()
        return f
    end

    function MoneyFrame:Update()
        local money = mod("PlayerInfo"):GetMoney(self:GetParent():GetPlayer())
        local mode = self:GetDisplayMode()

        local gold   = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100

        if mode == "text" then
            self.iconGold:Hide();  self.amtGold:Hide()
            self.iconSilver:Hide(); self.amtSilver:Hide()
            self.iconCopper:Hide(); self.amtCopper:Hide()

            self.textFull:SetText(format("|cffffd700%d %s |r|cffc7c7cf%d %s |r|cffeda55f%d %s|r",
                gold, "g", silver, "s", copper, "c"))
            self.textFull:Show()
        else
            self.textFull:Hide()

            -- Gold: solo se muestra si hay > 0
            if gold > 0 then
                self.iconGold:Show(); self.amtGold:Show()
                self.amtGold:SetText(gold)
            else
                self.iconGold:Hide(); self.amtGold:Hide()
            end

            -- Silver: se muestra si hay gold O si hay silver
            if gold > 0 or silver > 0 then
                self.iconSilver:Show(); self.amtSilver:Show()
                self.amtSilver:SetText(silver)
            else
                self.iconSilver:Hide(); self.amtSilver:Hide()
            end

            -- Copper: siempre se muestra
            self.iconCopper:Show(); self.amtCopper:Show()
            self.amtCopper:SetText(copper)
        end
    end

    function MoneyFrame:RefreshDisplay()
        if self:IsShown() then
            self:Update()
        end
    end
end

do
    local TokenBar = mod:NewClass("Frame")
    local MAX_WATCHED_TOKENS = MAX_WATCHED_TOKENS or 20

    local TOKENBAR_HEIGHT = 19
    local TOKEN_ICON_SIZE = 14
    local TOKEN_GAP = 6

    -- Build the three-piece chrome pill background (same as bags_skin.lua ApplyPillChrome)
    local function ApplyPillChrome(bar)
        if bar._dragonuiPill then return end
        bar._dragonuiPill = true

        local left = bar:CreateTexture(nil, "BACKGROUND")
        left:SetSize(8, TOKENBAR_HEIGHT)
        left:SetPoint("LEFT", bar, "LEFT")
        left:SetTexture(mod.CT.currencybox)
        left:SetTexCoord(0.03125, 0.53125, 0.289062, 0.554688)

        local right = bar:CreateTexture(nil, "BACKGROUND")
        right:SetSize(8, TOKENBAR_HEIGHT)
        right:SetPoint("RIGHT", bar, "RIGHT")
        right:SetTexture(mod.CT.currencybox)
        right:SetTexCoord(0.03125, 0.53125, 0.570312, 0.835938)

        local middle = bar:CreateTexture(nil, "BACKGROUND")
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        middle:SetTexture(mod.CT.currencybox)
        middle:SetTexCoord(0, 0.5, 0.0078125, 0.273438)
    end

    function TokenBar:New(parent)
        local bar = self:Bind(CreateFrame("Frame", nil, parent))
        bar:SetHeight(TOKENBAR_HEIGHT)
        bar.tokenButtons = {}
        bar._tokenCount = 0

        ApplyPillChrome(bar)

        bar:SetScript("OnEvent", function(self, event)
            if event == "CURRENCY_DISPLAY_UPDATE" then
                self:Refresh()
            end
        end)
        bar:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

        -- Also refresh when the frame is shown (e.g., after /reload or module toggle)
        bar:SetScript("OnShow", function(self)
            self:Refresh()
        end)

        return bar
    end

    function TokenBar:Refresh()
        local numTokens = 0
        for i = 1, MAX_WATCHED_TOKENS do
            local name, count, extraCurrencyType, icon = GetBackpackCurrencyInfo(i)
            if name then
                numTokens = numTokens + 1
                local btn = self.tokenButtons[i]
                if not btn then
                    btn = self:_CreateTokenButton(i)
                    self.tokenButtons[i] = btn
                end

                -- Icon selection (matches Blizzard BackpackTokenFrame logic)
                if extraCurrencyType == 1 then
                    btn.icon:SetTexture("Interface\\PVPFrame\\PVP-ArenaPoints-Icon")
                    btn.icon:SetTexCoord(0, 1, 0, 1)
                elseif extraCurrencyType == 2 then
                    local factionGroup = UnitFactionGroup("player")
                    if factionGroup then
                        btn.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. factionGroup)
                        btn.icon:SetTexCoord(0.03125, 0.59375, 0.03125, 0.59375)
                    else
                        btn.icon:SetTexCoord(0, 1, 0, 1)
                    end
                else
                    btn.icon:SetTexture(icon)
                    btn.icon:SetTexCoord(0, 1, 0, 1)
                end

                if count <= 99999 then
                    btn.count:SetText(count)
                else
                    btn.count:SetText("*")
                end
                btn:Show()
            else
                local btn = self.tokenButtons[i]
                if btn then
                    btn:Hide()
                end
            end
        end

        -- Layout visible buttons right-to-left (bar is right-anchored)
        local wasShown = self:IsShown()
        if numTokens > 0 then
            self._tokenCount = numTokens
            local previous = nil
            for i = 1, MAX_WATCHED_TOKENS do
                local btn = self.tokenButtons[i]
                if btn and btn:IsShown() then
                    btn:ClearAllPoints()
                    if previous then
                        btn:SetPoint("RIGHT", previous, "LEFT", -TOKEN_GAP, 0)
                    else
                        btn:SetPoint("RIGHT", self, "RIGHT", -10, 1)
                    end
                    previous = btn
                end
            end
            self:Show()
        else
            self._tokenCount = 0
            self:Hide()
        end
        -- Notify parent to relayout if visibility changed
        if wasShown ~= self:IsShown() then
            local parent = self:GetParent()
            if parent and parent.UpdateItemFrameSize then
                parent:UpdateItemFrameSize()
                parent:UpdateClampInsets()
            end
        end
    end

    function TokenBar:_CreateTokenButton(index)
        local btn = CreateFrame("Button", nil, self)
        btn:SetHeight(TOKENBAR_HEIGHT - 2)

        -- Count text on the right
        btn.count = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.count:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        btn.count:SetJustifyH("RIGHT")

        -- Icon to the left of count
        btn.icon = btn:CreateTexture(nil, "OVERLAY")
        btn.icon:SetSize(TOKEN_ICON_SIZE, TOKEN_ICON_SIZE)
        btn.icon:SetPoint("RIGHT", btn.count, "LEFT", -3, 0)

        -- Set button width based on count text width
        btn.count:SetText("99999")
        btn:SetWidth(TOKEN_ICON_SIZE + 3 + btn.count:GetStringWidth() + 2)

        -- Tooltip on enter (show currency name)
        btn:SetScript("OnEnter", function(self)
            local id = self._tokenIndex
            if not id then return end
            local name = GetBackpackCurrencyInfo(id)
            if name then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(name, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn._tokenIndex = index

        return btn
    end

    -- Register with module
    mod.TokenBar = TokenBar
end

do
    local FilterButton = mod:NewClass("CheckButton")
    local SIZE = 20
    local IsModifierKeyDown = IsModifierKeyDown

    function FilterButton:Create(parent, quality, qualityFlag)
        local button = self:Bind(CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate"))
        button:SetWidth(SIZE)
        button:SetHeight(SIZE)
        button:SetScript("OnClick", self.OnClick)
        button:SetScript("OnEnter", self.OnEnter)
        button:SetScript("OnLeave", self.OnLeave)

        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(SIZE / 3, SIZE / 3)
        bg:SetPoint("CENTER")

        local r, g, b = GetItemQualityColor(quality)
        bg:SetTexture(r * 1.25, g * 1.25, b * 1.25, 0.75)

        button:SetCheckedTexture(bg)
        button:GetNormalTexture():SetVertexColor(r, g, b)

        button.quality = quality
        button.qualityFlag = qualityFlag
        return button
    end

    function FilterButton:OnClick()
        local frame = self:GetParent():GetParent()
        if bit.band(frame:GetQuality(), self.qualityFlag) > 0 then
            if IsModifierKeyDown() or frame:GetQuality() == self.qualityFlag then
                frame:RemoveQuality(self.qualityFlag)
            else
                frame:SetQuality(self.qualityFlag)
            end
        elseif IsModifierKeyDown() then
            frame:AddQuality(self.qualityFlag)
        else
            frame:SetQuality(self.qualityFlag)
        end
    end

    function FilterButton:OnEnter()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local quality = self.quality
        if quality then
            local r, g, b = GetItemQualityColor(quality)
            GameTooltip:SetText(_G[format("ITEM_QUALITY%d_DESC", quality)], r, g, b)
        else
            GameTooltip:SetText(ALL)
        end
        GameTooltip:Show()
    end

    function FilterButton:OnLeave()
        GameTooltip:Hide()
    end

    function FilterButton:UpdateHighlight(quality)
        self:SetChecked(bit.band(quality, self.qualityFlag) > 0)
    end

    local QualityFilter = mod:NewClass("Frame")
    mod.QualityFilter = QualityFilter

    function QualityFilter:New(parent)
        local f = self:Bind(CreateFrame("Frame", nil, parent))

        f:AddQualityButton(0)
        f:AddQualityButton(1)
        f:AddQualityButton(2)
        f:AddQualityButton(3)
        f:AddQualityButton(4)
        f:AddQualityButton(5, mod.QualityFlags[5] + mod.QualityFlags[6])
        f:AddQualityButton(7)

        f:SetWidth(SIZE * 6)
        f:SetHeight(SIZE)
        f:UpdateHighlight()

        return f
    end

    function QualityFilter:AddQualityButton(quality, qualityFlags)
        local button = FilterButton:Create(self, quality, qualityFlags or mod.QualityFlags[quality])
        if self.prev then
            button:SetPoint("LEFT", self.prev, "RIGHT", 1, 0)
        else
            button:SetPoint("LEFT")
        end
        self.prev = button
    end

    function QualityFilter:UpdateHighlight()
        local quality = self:GetParent():GetQuality()
        for i = 1, select("#", self:GetChildren()) do
            select(i, self:GetChildren()):UpdateHighlight(quality)
        end
    end
end

do
    local SideTab = mod:NewClass("CheckButton")

    function SideTab:New(parent, id)
        local tab = self:Bind(CreateFrame("CheckButton", format("%sSideTab%d", parent:GetParent():GetName(), id), parent))
        SetupSideTabButton(tab)
        tab.border = tab._BagSkin_SideBorder
        return tab
    end

    function SideTab:Set(set)
        self.set = set
        self.tooltip = mod.GetSetDisplayName(set.name)
        if set.icon then
            self:SetNormalTexture(set.icon)
            self:GetNormalTexture():SetTexCoord(0.06, 0.94, 0.06, 0.94)
        end
    end

    function SideTab:SetReversed(reversed)
        self.reversed = reversed and true or nil
        if self.border then
            self.border:ClearAllPoints()
            if reversed then
                self.border:SetTexCoord(1, 0, 0, 1)
                self.border:SetPoint("TOPRIGHT", 3, 11)
            else
                self.border:SetTexCoord(0, 1, 0, 1)
                self.border:SetPoint("TOPLEFT", -3, 11)
            end
        end
    end

    function SideTab:UpdateHighlight(setName)
        self:SetChecked(self.set.name == setName)
    end

    local SideFilter = mod:NewClass("Frame")
    mod.SideFilter = SideFilter

    function SideFilter:New(parent, reversed)
        local f = self:Bind(CreateFrame("Frame", parent:GetName() .. "SideFilter", parent))
        f.buttons = setmetatable({}, { __index = function(t, k)
            local tab = SideTab:New(f, k)
            if k > 1 then
                tab:SetPoint("TOP", f.buttons[k - 1], "BOTTOM", 0, -17)
            end
            tab:SetScript("OnClick", function(self)
                parent:SetCategory(self.set.name)
            end)
            t[k] = tab
            return tab
        end })
        f.reversed = reversed
        f:SetReversed(reversed)
        return f
    end

    function SideFilter:SetReversed(enable)
        self.reversed = enable
        self:UpdateAnchoring()
    end

    function SideFilter:Reversed()
        return self.reversed
    end

    function SideFilter:UpdateAnchoring()
        local parent = self:GetParent()
        if self.reversed then
            if self.buttons[1] then
                self.buttons[1]:ClearAllPoints()
                self.buttons[1]:SetPoint("TOPRIGHT", parent, "TOPLEFT", -1, -60)
            end
        else
            if self.buttons[1] then
                self.buttons[1]:ClearAllPoints()
                self.buttons[1]:SetPoint("TOPLEFT", parent, "TOPRIGHT", -1, -60)
            end
        end
        -- Update border flip and icon offset for all visible buttons
        for _, button in pairs(self.buttons) do
            if button:IsShown() and button.SetReversed then
                button:SetReversed(self.reversed)
            end
        end
    end

    function SideFilter:UpdateFilters()
        local CombuctorSet = mod("Sets")
        local parent = self:GetParent()
        local numFilters = 0

        for _, set in CombuctorSet:GetParentSets() do
            if parent:HasSet(set.name) then
                numFilters = numFilters + 1
                self.buttons[numFilters]:Set(set)
                self.buttons[numFilters]:Show()
            end
        end

        -- Hide excess buttons (important after profile reset)
        for i = numFilters + 1, #self.buttons do
            self.buttons[i]:Hide()
            self.buttons[i]:SetHeight(0.001)
        end
        -- Restore height for visible buttons
        for i = 1, numFilters do
            self.buttons[i]:SetHeight(32)
        end

        self:UpdateAnchoring()
        if numFilters > 0 then
            self:Show()
        else
            self:Hide()
        end
    end

    function SideFilter:UpdateHighlight()
        local category = self:GetParent():GetCategory()
        for _, button in pairs(self.buttons) do
            if button:IsShown() then
                button:UpdateHighlight(category)
            end
        end
    end
end

do
    local BottomTab = mod:NewClass("Button")

    function BottomTab:New(parent, id)
        local tab = self:Bind(CreateFrame("Button", parent:GetName() .. "Tab" .. id, parent, "CharacterFrameTabButtonTemplate"))
        SetupBottomTabButton(tab)
        tab:SetID(id)
        tab:SetScript("OnClick", function(self)
            parent:GetParent():SetSubCategory(self.set.name)
        end)
        return tab
    end

    function BottomTab:Set(set)
        self.set = set
        local displayName = mod.GetSetDisplayName(set.name)
        if set.icon then
            self:SetFormattedText("|T%s:%d|t %s", set.icon, 16, displayName)
        else
            self:SetText(displayName)
        end
        PanelTemplates_TabResize(self, 0)
        self:GetHighlightTexture():SetWidth(self:GetTextWidth() + 30)
    end

    function BottomTab:UpdateHighlight(setName)
        if self.set.name == setName then
            PanelTemplates_SetTab(self:GetParent(), self:GetID())
        end
    end

    local BottomFilter = mod:NewClass("Frame")
    mod.BottomFilter = BottomFilter

    function BottomFilter:New(parent)
        local f = self:Bind(CreateFrame("Frame", parent:GetName() .. "BottomFilter", parent))
        f.buttons = setmetatable({}, { __index = function(t, k)
            local tab = BottomTab:New(f, k)
            if k > 1 then
                -- Horizontal chain only — Y comes from separate BOTTOM anchor
                tab:SetPoint("LEFT", f.buttons[k - 1], "RIGHT", -16, 0)
            else
                tab:SetPoint("LEFT", parent, "BOTTOMLEFT", 60, 0)
            end
            -- Shared vertical baseline; active tab overrides in UpdateHighlight
            tab:SetPoint("BOTTOM", parent, "BOTTOMLEFT", 0, -26)
            t[k] = tab
            return tab
        end })
        return f
    end

    function BottomFilter:UpdateFilters()
        local numFilters = 0
        local parent = self:GetParent()
        local CombuctorSet = mod("Sets")

        for _, set in CombuctorSet:GetChildSets(parent:GetCategory()) do
            if parent:HasSubSet(set.name, set.parent) then
                numFilters = numFilters + 1
                self.buttons[numFilters]:Set(set)
            end
        end

        if numFilters > 1 then
            for i = 1, numFilters do self.buttons[i]:Show() end
            for i = numFilters + 1, #self.buttons do self.buttons[i]:Hide() end
            PanelTemplates_SetNumTabs(self, numFilters)
            self:UpdateHighlight()
            self:Show()
        else
            PanelTemplates_SetNumTabs(self, 0)
            self:Hide()
        end
        self:GetParent():UpdateClampInsets()
    end

    function BottomFilter:UpdateHighlight()
        local category = self:GetParent():GetSubCategory()
        for _, button in pairs(self.buttons) do
            if button:IsShown() then
                button:UpdateHighlight(category)
                -- Only Y moves — LEFT/RIGHT chain is untouched
                local isActive = (button.set and button.set.name == category)
                button:SetPoint("BOTTOM", self:GetParent(), "BOTTOMLEFT", 0, isActive and -31 or -26)
            end
        end
    end
end
