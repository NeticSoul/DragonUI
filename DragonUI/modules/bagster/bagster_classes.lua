-- UI classes: ItemSlot, ItemFrame, Bag, MoneyFrame, TokenBar, quality/side/bottom filters.
local addon = select(2, ...)
local mod = addon.BagsterModule

local format = string.format
local floor, ceil, min, max, sqrt = math.floor, math.ceil, math.min, math.max, math.sqrt

-- ============================================================================
-- TEMPLATE HELPERS (moved from core: used by SideTab and BottomTab)
-- ============================================================================

-- Modern retail spellbook side-tab art (drop-in replacement for SpellBook-SkillLineTab)
local function SetupSideTabButton(btn)
    btn:SetSize(32, 32)
    btn:Hide()

    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetTexture(mod.CT.sidetab)
    border:SetSize(64, 64)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 11)
    btn._BagSkin_SideBorder = border

    -- Blank so GetNormalTexture() works before Set() assigns the category icon
    btn:SetNormalTexture("")

    -- Managed state textures: passing texture objects leaves them unanchored (zero size)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:GetHighlightTexture():SetBlendMode("ADD")

    btn:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    btn:GetCheckedTexture():SetBlendMode("ADD")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip)
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
end

-- Retail tab art layered over the stock tab template
-- No SetScale here: fractional scaling breaks the seams between the three art pieces
local function SetupBottomTabButton(btn)
    btn:SetFrameLevel(btn:GetFrameLevel() + 4)
    btn:SetNormalFontObject(GameFontNormal)
    btn:SetHighlightFontObject(GameFontHighlight)
    local name = btn:GetName()
    local tex = mod.CT.tabs

    local left = _G[name .. 'Left']
    left:ClearAllPoints()
    left:SetSize(35, 36)
    left:SetTexture(tex)
    left:SetTexCoord(0.015625, 0.5625, 0.816406, 0.957031)
    left:SetPoint('TOPLEFT', -3, 0)

    local right = _G[name .. 'Right']
    right:ClearAllPoints()
    right:SetSize(37, 36)
    right:SetTexture(tex)
    right:SetTexCoord(0.015625, 0.59375, 0.667969, 0.808594)
    right:SetPoint('TOPRIGHT', 7, 0)

    -- Retail atlas tiles this 1px strip; 3.3.5 has no SetHorizTile, stretching looks identical
    local middle = _G[name .. 'Middle']
    middle:ClearAllPoints()
    middle:SetSize(1, 36)
    middle:SetTexture(tex)
    middle:SetTexCoord(0, 0.015625, 0.175781, 0.316406)
    middle:SetPoint('TOPLEFT', left, 'TOPRIGHT')
    middle:SetPoint('TOPRIGHT', right, 'TOPLEFT')

    local leftD = _G[name .. 'LeftDisabled']
    leftD:ClearAllPoints()
    leftD:SetSize(35, 42)
    leftD:SetTexture(tex)
    leftD:SetTexCoord(0.015625, 0.5625, 0.496094, 0.660156)
    leftD:SetPoint('TOPLEFT', -1, 0)

    local rightD = _G[name .. 'RightDisabled']
    rightD:ClearAllPoints()
    rightD:SetSize(37, 42)
    rightD:SetTexture(tex)
    rightD:SetTexCoord(0.015625, 0.59375, 0.324219, 0.488281)
    rightD:SetPoint('TOPRIGHT', 8, 0)

    local middleD = _G[name .. 'MiddleDisabled']
    middleD:ClearAllPoints()
    middleD:SetSize(1, 42)
    middleD:SetTexture(tex)
    middleD:SetTexCoord(0, 0.015625, 0.00390625, 0.167969)
    middleD:SetPoint('TOPLEFT', leftD, 'TOPRIGHT')
    middleD:SetPoint('TOPRIGHT', rightD, 'TOPLEFT')
end

mod.SetupSideTabButton = SetupSideTabButton
mod.SetupBottomTabButton = SetupBottomTabButton

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

    -- Empty-slot tint by bag family (GetItemFamily bitflags)
    local SLOT_COLOR_BY_FAMILY = {
        [0x0001] = {1, 0.87, 0.68},      -- quiver
        [0x0002] = {1, 0.87, 0.68},      -- ammo
        [0x0004] = {0.64, 0.39, 1},      -- soul
        [0x0008] = {1, 0.6, 0.45},       -- leather
        [0x0010] = {0.64, 1, 0.82},      -- inscription
        [0x0020] = {0.5, 1, 0.5},        -- herb
        [0x0040] = {0.64, 0.83, 1},      -- enchant
        [0x0080] = {0.36, 0.68, 0.52},   -- engineer
        [0x0200] = {1, 0.65, 0.98},      -- gem
        [0x0400] = {0.65, 0.53, 0.25},   -- mine
    }

    local unused = {}
    local id = 1

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
        local item = self:Bind(CreateFrame("Button", format("DragonUI_BagsterItem%d", itemID), nil, "ContainerFrameItemButtonTemplate"))

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
        self:SetAlpha(1)
        unused[self] = true
    end

    function ItemSlot:Set(parent, bag, slot)
        self:SetParent(ItemSlot:GetDummyBag(parent, bag))
        self:SetID(slot)
        self:Update()

        -- Slots spawn on demand, so BagsterSkinItems may have run before this one existed
        if not self._BagSkin_Applied then
            mod.BagsterRetailItemSlot(self)
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
                -- BANK_CONTAINER slots need the bank-specific tooltip API
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
                -- Native handler shows Soulbound/durability and initial shift+compare
                ContainerFrameItemButton_OnEnter(self)
                -- Keeps tooltip in sync when the hovered item changes (e.g. right-click equip)
                self.UpdateTooltip = ContainerFrameItemButton_OnEnter
            end
        end
    end

    -- Toggles the compare tooltip on shift without rebuilding GameTooltip (would corrupt Soulbound text)
    function ItemSlot:OnUpdate()
        if not self:IsMouseOver() or self:IsCached() then
            self._lastShiftState = nil
            return
        end
        if not GameTooltip:IsOwned(self) then return end
        local shiftDown = IsModifiedClick("COMPAREITEMS")
        if self._lastShiftState == shiftDown then return end
        self._lastShiftState = shiftDown
        if shiftDown then
            GameTooltip_ShowCompareItem()
        else
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
        self:UpdateItemLevel(link)
        self:UpdateSlotColor()
        self:UpdateCooldown()
        self:SetAlpha(self:MatchesSearch() and 1 or 0.3)
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
        if texture then
            SetItemButtonTexture(self, texture)
        elseif self._BagSkin_Applied then
            -- Retail chrome is NormalTexture; hide classic empty-slot icon
            SetItemButtonTexture(self, nil)
        else
            SetItemButtonTexture(self, self:GetEmptyItemTexture())
        end
    end

    function ItemSlot:GetEmptyItemTexture()
        return [[Interface\PaperDoll\UI-Backpack-EmptySlot]]
    end

    -- Retail skin shows empty chrome on NormalTexture; tint that too
    function ItemSlot:SetSlotChromeColor(r, g, b)
        SetItemButtonTextureVertexColor(self, r, g, b)
        local nt = self:GetNormalTexture()
        if nt then
            nt:SetVertexColor(r, g, b)
        end
        if self._dragonuiSlotBorder then
            self._dragonuiSlotBorder:SetVertexColor(r, g, b)
        end
    end

    function ItemSlot:UpdateSlotColor()
        if (not self:GetItem()) and self:IsTradeBagSlot() then
            local family = BagSlotInfo:GetBagType(self:GetPlayer(), self:GetBag()) or 0
            local color = SLOT_COLOR_BY_FAMILY[family]
            if color then
                self:SetSlotChromeColor(color[1], color[2], color[3])
            else
                self:SetSlotChromeColor(0.5, 1, 0.5)
            end
            return
        end
        -- Leave gray from SetItemButtonDesaturated alone while locked/search-dimmed.
        if self:IsLocked() or not self:MatchesSearch() then
            return
        end
        local link = self:GetItem()
        if link and addon:IsUnusableItemTintEnabled() then
            local bag, slot = self:GetBag(), self:GetID()
            if self:IsCached() then
                bag, slot = nil, nil
            end
            if addon:IsItemUnusableForTint(link, bag, slot) then
                SetItemButtonTextureVertexColor(self, 0.9, 0, 0)
                local nt = self:GetNormalTexture()
                if nt then nt:SetVertexColor(1, 1, 1) end
                if self._dragonuiSlotBorder then
                    self._dragonuiSlotBorder:SetVertexColor(1, 1, 1)
                end
                return
            end
        end
        self:SetSlotChromeColor(1, 1, 1)
    end

    function ItemSlot:SetCount(count)
        SetItemButtonCount(self, count)
    end

    function ItemSlot:SetReadable(readable)
        self.readable = readable
    end

    function ItemSlot:SetLocked(locked)
        SetItemButtonDesaturated(self, locked or not self:MatchesSearch())
    end

    function ItemSlot:UpdateLocked()
        self:SetLocked(self:IsLocked())
        self:UpdateSlotColor()
    end

    function ItemSlot:GetSearch()
        local p = self:GetParent()
        p = p and p:GetParent()
        return p and p.search
    end

    function ItemSlot:MatchesSearch()
        local search = self:GetSearch()
        if not search then return true end
        local link = self:GetItem()
        return (link and mod.ItemSearch:Find(link, search)) and true or false
    end

    -- Search dims non-matching slots in place; the grid never reshuffles
    function ItemSlot:UpdateSearch()
        self:SetAlpha(self:MatchesSearch() and 1 or 0.3)
        self:SetLocked(self:IsLocked())
        self:UpdateSlotColor()
    end

    function ItemSlot:IsLocked()
        return ItemSlotInfo:IsLocked(self:GetPlayer(), self:GetBag(), self:GetID())
    end

    function ItemSlot:UpdateCooldown()
        if self:GetItem() and not self:IsCached() then
            local start, duration, enable = GetContainerItemCooldown(self:GetBag(), self:GetID())
            CooldownFrame_SetTimer(self.cooldown, start or 0, duration or 0, enable or 0)
            -- Match ContainerFrame_UpdateCooldown: gray while on CD with enable==0, else restore tint.
            if duration and duration > 0 and enable == 0 then
                SetItemButtonTextureVertexColor(self, 0.4, 0.4, 0.4)
            else
                self:UpdateSlotColor()
            end
        else
            CooldownFrame_SetTimer(self.cooldown, 0, 0, 0)
            self:UpdateSlotColor()
        end
    end

    function ItemSlot:SetBorderQuality(quality)
        local border = self.border
        local qBorder = self.questBorder
        local cfg = mod.GetModuleConfig()

        if not cfg or cfg.glow_quest ~= false then
            local isQuestItem, isQuestStarter = self:IsQuestItem()
            if isQuestStarter then
                qBorder:SetTexture(mod.TEXTURE_ITEM_QUEST_BANG)
                qBorder:SetAlpha(1)
                qBorder:Show()
                border:Hide()
                return
            end
            if isQuestItem then
                qBorder:SetTexture(mod.TEXTURE_ITEM_QUEST_BORDER)
                qBorder:SetAlpha(1)
                qBorder:Show()
                border:Hide()
                return
            end
        end

        if (not cfg or cfg.glow_quality ~= false) and self:GetItem() and quality and quality > 1 then
            local r, g, b = GetItemQualityColor(quality)
            border:SetVertexColor(r, g, b, (cfg and cfg.glow_alpha) or 1)
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

    function ItemSlot:UpdateItemLevel(link)
        if addon.UpdateItemLevelSlot then
            addon.UpdateItemLevelSlot(self, link, nil, self:IsBank() and "bank" or "bags")
        end
    end

    -- nil per-instance so Update() can't re-trigger OnEnter and clear bank tooltips
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

    -- Native events registered directly on Updater (below), not through the InventoryEvents bus.
    function FrameEvents:QUEST_ACCEPTED()
        for f in self:GetFrames() do
            if f:GetPlayer() == mod.playerName then f:UpdateQuestBorders() end
        end
    end
    FrameEvents.UNIT_QUEST_LOG_CHANGED = FrameEvents.QUEST_ACCEPTED

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
        -- Flush a layout requested while hidden (e.g. option changed with bags closed)
        self:TriggerLayout()
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

        local parent = self:GetParent()
        if parent and parent.IsShowingBag and not parent:IsShowingBag(bag) then
            return false
        end

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
            end
        end
        return true
    end

    function ItemFrame:SetSearch(text)
        text = (text and text ~= '') and text or nil
        if self.search ~= text then
            self.search = text
            for _, item in pairs(self.items) do
                item:UpdateSearch()
            end
        end
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

    function ItemFrame:UpdateQuestBorders()
        for _, item in pairs(self.items) do
            item:UpdateBorder()
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

    function ItemFrame:Layout()
        local width, height = self:GetWidth(), self:GetHeight()
        if width <= 0 or height <= 0 then return end

        local cfg = mod.GetModuleConfig()
        local spacing = (cfg and cfg.item_spacing) or 2
        local size = 37 + spacing
        local maxScale = (cfg and cfg.item_scale) or 1
        local bagBreak = (cfg and cfg.bag_break)
        if bagBreak == nil then bagBreak = 1 end
        local breakSpace = (cfg and cfg.break_space) or 1.3

        local buttons, breaks, group = {}, { 0 }, 0
        local parent = self:GetParent()
        local items = self.items

        for _, bag in ipairs(self.bags) do
            local numSlots = self:GetBagSize(bag)
            local showing = not parent or not parent.IsShowingBag or parent:IsShowingBag(bag)
            if numSlots > 0 and showing then
                local family = self:GetBagType(bag) or 0
                -- ByType: normal↔specialty; keyring always starts its own block
                local byType = family ~= group
                    and (family * group <= 0 or BagSlotInfo:IsKeyRing(bag))
                if (bagBreak > 1 or (bagBreak > 0 and byType)) and #buttons > breaks[#breaks] then
                    table.insert(breaks, #buttons)
                end
                for slot = 1, numSlots do
                    local item = items[ToIndex(bag, slot)]
                    if item then
                        table.insert(buttons, item)
                    end
                end
                group = family
            end
        end

        local n = #buttons
        if n == 0 then return end

        -- A block whose slots were all filtered out leaves a trailing break: phantom rows.
        while #breaks > 1 and breaks[#breaks] >= n do
            table.remove(breaks)
        end

        local b = #breaks - 1
        local function CountRows(cols)
            local rows = b * (breakSpace - 1)
            for k, index in ipairs(breaks) do
                rows = rows + ceil(((breaks[k + 1] or n) - index) / cols)
            end
            return max(rows, 1)
        end

        local cap = maxScale * size
        local maxCols = max(1, min(n, floor(width / max(size * 0.5, 1))))
        local bestFit = 0
        for cols = 1, maxCols do
            local fit = min(width / cols, height / CountRows(cols), cap)
            if fit > bestFit then bestFit = fit end
        end
        if bestFit <= 0 then
            bestFit = min(width, height, cap)
        end

        -- Nearest column count, then the cell itself absorbs the leftover so the width fills exactly.
        local gridCols = max(1, floor(width / bestFit + 0.5))
        local columns = min(n, gridCols)
        bestFit = min(width / gridCols, height / CountRows(columns))
        local scale = bestFit / size

        -- Falls back to widening the gaps when the height caps the cell before the width is filled.
        local pitchX = size
        if columns == gridCols and gridCols > 1 then
            pitchX = min((width - bestFit) / (gridCols - 1), bestFit * 1.25) / scale
        end

        local breakpoint, stage, x, y = breaks[2] or n, 2, 0, 0
        for i, button in ipairs(buttons) do
            if i > breakpoint then
                stage = stage + 1
                breakpoint = breaks[stage] or n
                x, y = 0, y + breakSpace
            elseif x == columns then
                x, y = 0, y + 1
            end
            button:ClearAllPoints()
            button:SetScale(scale)
            button:SetPoint("TOPLEFT", self, "TOPLEFT", pitchX * x, -size * y)
            button:Show()
            x = x + 1
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
            local parent = self:GetParent()
            for _, bag in ipairs(self.bags) do
                if (not parent or not parent.IsShowingBag or parent:IsShowingBag(bag))
                    and not self:IsBagCached(bag) then
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
    local BagSlotInfo = mod.BagSlotInfo
    local unused = {}
    local bagId = 1

    function Bag:New()
        local bag = self:Bind(CreateFrame("Button", format("DragonUI_BagsterBag%d", bagId)))
        local name = bag:GetName()
        bag:SetSize(SIZE, SIZE)
        bag:SetHitRectInsets(-2, -2, -2, -2)

        -- Micromenu bag-slot treatment: dark socket, inset round icon, ring border
        local background = bag:CreateTexture(nil, "BACKGROUND")
        background:SetSize(36, 36)
        background:SetPoint("CENTER")
        background:SetTexture(mod.CT.bagslot)
        background:SetTexCoord(295 / 512, 356 / 512, 64 / 128, 125 / 128)

        local icon = bag:CreateTexture(name .. "IconTexture", "BORDER")
        icon:SetPoint("TOPRIGHT", bag, "TOPRIGHT", -5, -2.9)
        icon:SetPoint("BOTTOMLEFT", bag, "BOTTOMLEFT", 2.9, 5)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local ringBorder = bag:CreateTexture(nil, "OVERLAY")
        ringBorder:SetSize(36, 36)
        ringBorder:SetPoint("CENTER")
        ringBorder:SetTexture(mod.CT.bagslot)
        ringBorder:SetTexCoord(295 / 512, 356 / 512, 1 / 128, 62 / 128)

        local count = bag:CreateFontString(name .. "Count", "OVERLAY")
        count:SetFontObject("NumberFontNormalSmall")
        count:SetJustifyH("RIGHT")
        count:SetPoint("BOTTOMRIGHT", -2, 2)

        -- Blank normal so SetItemButton* APIs don't restore a default backdrop
        local nt = bag:CreateTexture(name .. "NormalTexture")
        nt:SetTexture(nil)
        nt:SetAlpha(0)
        nt:Hide()
        bag:SetNormalTexture(nt)

        -- Inner edge glow: managed highlight filling the button
        bag:SetHighlightTexture("")
        local ht = bag:GetHighlightTexture()
        ht:SetAllPoints()
        ht:SetBlendMode("ADD")
        ht:SetAlpha(0.4)
        ht:SetTexture(mod.CT.bagslot)
        ht:SetTexCoord(358 / 512, 419 / 512, 1 / 128, 62 / 128)

        -- Checked = bag currently shown in the item grid
        local checked = bag:CreateTexture(nil, "OVERLAY")
        checked:SetAllPoints()
        checked:SetBlendMode("ADD")
        checked:SetAlpha(0.55)
        checked:SetTexture(mod.CT.bagslot)
        checked:SetTexCoord(358 / 512, 419 / 512, 1 / 128, 62 / 128)
        checked:Hide()
        bag.checkedTex = checked

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
        elseif BagSlotInfo:IsKeyRing(id) then
            SetItemButtonTexture(self, [[Interface\ContainerFrame\KeyRing-Bag-Icon]])
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
        end
        self:UpdateToggle()
        self:UpdateFreeSlots()
    end

    function Bag:Release()
        self:SetAlpha(1)
        self:Hide()
        self:SetParent(nil)
        self:UnregisterAllEvents()
        if self.checkedTex then
            self.checkedTex:Hide()
        end
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

    function Bag:IsShowing()
        local parent = self:GetParent()
        return parent and parent.IsShowingBag and parent:IsShowingBag(self:GetID())
    end

    function Bag:UpdateToggle()
        if self.checkedTex then
            if self:IsShowing() then
                self.checkedTex:Show()
            else
                self.checkedTex:Hide()
            end
        end
        self:SetAlpha(self:IsShowing() and 1 or 0.45)
    end

    function Bag:UpdateFreeSlots()
        local countFS = _G[self:GetName() .. "Count"]
        if not countFS then return end
        local id = self:GetID()
        if BagSlotInfo:IsCached(mod.playerName, id) then
            countFS:Hide()
            return
        end
        local free = GetContainerNumFreeSlots(id)
        if free and free > 0 then
            countFS:SetText(free)
            countFS:Show()
        else
            countFS:SetText("")
            countFS:Hide()
        end
    end

    function Bag:Update()
        if not self:IsVisible() then return end
        local id = self:GetID()
        if not (BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id) or BagSlotInfo:IsKeyRing(id)) then
            if self:IsBagSlot() then
                SetItemButtonDesaturated(self, BagSlotInfo:IsLocked(mod.playerName, id))
                local link, _, texture = BagSlotInfo:GetItemInfo(mod.playerName, id)
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
                local invSlot = self:GetInventorySlot()
                if invSlot and CursorCanGoInSlot(invSlot) then
                    self:LockHighlight()
                else
                    self:UnlockHighlight()
                end
            end
        end
        self:UpdateToggle()
        self:UpdateFreeSlots()
    end

    function Bag:OnShow()
        self:Update()
    end

    function Bag:OnEnter()
        local id = self:GetID()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id) then
            GameTooltip:SetText(BACKPACK_TOOLTIP)
        elseif BagSlotInfo:IsKeyRing(id) then
            GameTooltip:SetText(KEYRING, 1, 1, 1)
        elseif BagSlotInfo:IsBankBag(id) and BagSlotInfo:IsCached(mod.playerName, id) then
            -- Offline bank: inventory API is empty; use cached bag link (name + slot count).
            local link = mod("BankCache"):GetCachedBagLink(id)
            if link then
                GameTooltip:SetHyperlink(link)
            else
                GameTooltip:SetText(EQUIP_CONTAINER)
            end
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
        -- Show/hide bag filter hint
        if self:IsShowing() then
            GameTooltip:AddLine(mod.L.HideBag)
        else
            GameTooltip:AddLine(mod.L.ShowBag)
        end
        if self:IsBagSlot() then
            GameTooltip:AddLine(mod.L.DragBag)
        end
        GameTooltip:Show()
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
        local parent = self:GetParent()

        if CursorHasItem() then
            if BagSlotInfo:IsKeyRing(id) then
                PutKeyInKeyRing()
            elseif BagSlotInfo:IsBackpack(id) then
                PutItemInBackpack()
            elseif not BagSlotInfo:IsBank(id) then
                local invSlot = self:GetInventorySlot()
                if invSlot then
                    PutItemInBag(invSlot)
                end
            end
            return
        end

        if self:IsPurchasable() then
            self:PurchaseSlot()
            return
        end

        -- Left-click toggles bag visibility; right-click unused (no bag menu on 3.3.5a)
        if button == "RightButton" then
            return
        end
        if parent and parent.ToggleBagFilter then
            parent:ToggleBagFilter(id)
        end
    end

    function Bag:OnDrag()
        local id = self:GetID()
        if BagSlotInfo:IsBackpack(id) or BagSlotInfo:IsBank(id) or BagSlotInfo:IsKeyRing(id) then
            return
        end
        local invSlot = self:GetInventorySlot()
        if invSlot then
            PickupBagFromSlot(invSlot)
        end
    end

    function Bag:PurchaseSlot()
        if not StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_BAGSTER"] then
            StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT_BAGSTER"] = {
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
        StaticPopup_Show("CONFIRM_BUY_BANK_SLOT_BAGSTER")
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
        local mc = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.bagster
        return (mc and mc.money_display) or "icons"
    end

    function MoneyFrame:New(parent)
        local f = self:Bind(CreateFrame("Frame", format("DragonUI_BagsterMoney%d", moneyId), parent))
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
        f.iconCopper:SetSize(15, 15)
        f.iconCopper:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        f.amtCopper = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.amtCopper:SetPoint("RIGHT", f.iconCopper, "LEFT", -2, 0)

        -- Silver
        f.iconSilver = f:CreateTexture(nil, "OVERLAY")
        f.iconSilver:SetTexture(mod.CT.coinSilver)
        f.iconSilver:SetTexCoord(unpack(COIN_TEXCOORD))
        f.iconSilver:SetSize(15, 15)
        f.iconSilver:SetPoint("RIGHT", f.amtCopper, "LEFT", -4, 0)
        f.amtSilver = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.amtSilver:SetPoint("RIGHT", f.iconSilver, "LEFT", -2, 0)

        -- Gold
        f.iconGold = f:CreateTexture(nil, "OVERLAY")
        f.iconGold:SetTexture(mod.CT.coinGold)
        f.iconGold:SetTexCoord(unpack(COIN_TEXCOORD))
        f.iconGold:SetSize(15, 15)
        f.iconGold:SetPoint("RIGHT", f.amtSilver, "LEFT", -4, 0)
        f.amtGold = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.amtGold:SetPoint("RIGHT", f.iconGold, "LEFT", -2, 0)

        local txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txt:SetAllPoints(f)
        txt:SetJustifyH("RIGHT")
        txt:SetJustifyV("MIDDLE")
        txt:Hide()
        f.textFull = txt

        -- Vanilla coin split: moneyType="PLAYER" is the contract CoinPickupFrame expects
        local function OnCoinClick(self)
            if f:GetParent():GetPlayer() ~= mod.playerName then return end
            if GetCursorMoney() > 0 then
                DropCursorMoney()
                return
            end
            if self.hasPickup == 1 then
                CoinPickupFrame:Hide()
                return
            end
            OpenCoinPickupFrame(self.multiplier, GetMoney(), self)
            self.hasPickup = 1
        end

        local function CoinButton(amount, coinIcon, multiplier)
            local b = CreateFrame("Button", nil, f)
            b.moneyType = "PLAYER"
            b.multiplier = multiplier
            b:SetPoint("TOPLEFT", amount, "TOPLEFT", -2, 2)
            b:SetPoint("BOTTOMRIGHT", coinIcon, "BOTTOMRIGHT", 2, -2)
            b:SetScript("OnClick", OnCoinClick)
            return b
        end
        f.btnGold = CoinButton(f.amtGold, f.iconGold, COPPER_PER_GOLD)
        f.btnSilver = CoinButton(f.amtSilver, f.iconSilver, COPPER_PER_SILVER)
        f.btnCopper = CoinButton(f.amtCopper, f.iconCopper, 1)

        f.btnText = CreateFrame("Button", nil, f)
        f.btnText.moneyType = "PLAYER"
        f.btnText.multiplier = COPPER_PER_GOLD
        f.btnText:SetAllPoints(f)
        f.btnText:SetScript("OnClick", OnCoinClick)
        f.btnText:Hide()

        if addon.RegisterAltMoneyFrame then
            addon.RegisterAltMoneyFrame(f)
        end

        moneyId = moneyId + 1
        f:Update()
        return f
    end

    local function FormatThousands(n)
        local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,")
        s = s:reverse():gsub("^,", "")
        return s
    end

    -- Overridable per instance: the guild frame feeds guild funds through the same display
    function MoneyFrame:GetMoneyValue()
        return mod("PlayerInfo"):GetMoney(self:GetParent():GetPlayer())
    end

    function MoneyFrame:Update()
        local money = self:GetMoneyValue()
        local mode = self:GetDisplayMode()

        local gold   = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100

        if mode == "text" then
            self.iconGold:Hide();  self.amtGold:Hide(); self.btnGold:Hide()
            self.iconSilver:Hide(); self.amtSilver:Hide(); self.btnSilver:Hide()
            self.iconCopper:Hide(); self.amtCopper:Hide(); self.btnCopper:Hide()

            self.textFull:SetText(format("|cffffd700%s %s |r|cffc7c7cf%d %s |r|cffeda55f%d %s|r",
                FormatThousands(gold), "g", silver, "s", copper, "c"))
            self.textFull:Show()
            self.btnText:Show()
        else
            self.textFull:Hide()
            self.btnText:Hide()

            -- Gold: solo se muestra si hay > 0
            if gold > 0 then
                self.iconGold:Show(); self.amtGold:Show(); self.btnGold:Show()
                self.amtGold:SetText(FormatThousands(gold))
            else
                self.iconGold:Hide(); self.amtGold:Hide(); self.btnGold:Hide()
            end

            -- Silver: se muestra si hay gold O si hay silver
            if gold > 0 or silver > 0 then
                self.iconSilver:Show(); self.amtSilver:Show(); self.btnSilver:Show()
                self.amtSilver:SetText(silver)
            else
                self.iconSilver:Hide(); self.amtSilver:Hide(); self.btnSilver:Hide()
            end

            -- Copper: siempre se muestra
            self.iconCopper:Show(); self.amtCopper:Show(); self.btnCopper:Show()
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
    local TOKEN_ICON_SIZE = 16
    local TOKEN_GAP = 6

    -- The parent box (nineslice) provides the chrome; this bar only lays out token buttons
    function TokenBar:New(parent)
        local bar = self:Bind(CreateFrame("Frame", nil, parent))
        bar:SetHeight(TOKENBAR_HEIGHT)
        bar.tokenButtons = {}
        bar._tokenCount = 0

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
            local name, count, extraCurrencyType, icon, itemID = GetBackpackCurrencyInfo(i)
            if name then
                numTokens = numTokens + 1
                local btn = self.tokenButtons[i]
                if not btn then
                    btn = self:_CreateTokenButton(i)
                    self.tokenButtons[i] = btn
                end
                btn.extraCurrencyType = extraCurrencyType
                btn.itemID = itemID

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
                btn:SetWidth(TOKEN_ICON_SIZE + 3 + btn.count:GetStringWidth() + 2)
                btn:Show()
            else
                local btn = self.tokenButtons[i]
                if btn then
                    btn:Hide()
                end
            end
        end

        -- Bare tokens laid left-to-right on the bottom band
        if numTokens > 0 then
            self._tokenCount = numTokens
            local previous
            for i = 1, MAX_WATCHED_TOKENS do
                local btn = self.tokenButtons[i]
                if btn and btn:IsShown() then
                    btn:ClearAllPoints()
                    if previous then
                        btn:SetPoint("LEFT", previous, "RIGHT", TOKEN_GAP, 0)
                    else
                        btn:SetPoint("LEFT", self, "LEFT", 0, 0)
                    end
                    previous = btn
                end
            end
            self:Show()
        else
            self._tokenCount = 0
            self:Hide()
        end
    end

    function TokenBar:_CreateTokenButton(index)
        local btn = CreateFrame("Button", nil, self)
        btn:SetHeight(TOKENBAR_HEIGHT - 2)

        -- Count then icon, like retail's backpack token row
        btn.icon = btn:CreateTexture(nil, "OVERLAY")
        btn.icon:SetSize(TOKEN_ICON_SIZE, TOKEN_ICON_SIZE)
        btn.icon:SetPoint("RIGHT", btn, "RIGHT", 0, 0)

        btn.count = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.count:SetPoint("RIGHT", btn.icon, "LEFT", -3, 0)
        btn.count:SetJustifyH("RIGHT")

        -- Set button width based on count text width
        btn.count:SetText("99999")
        btn:SetWidth(TOKEN_ICON_SIZE + 3 + btn.count:GetStringWidth() + 2)

        -- Vanilla tooltip, same as Blizzard's BackpackTokenTemplate
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            if self.extraCurrencyType == 1 then
                GameTooltip:SetText(ARENA_POINTS, 1, 1, 1)
                GameTooltip:AddLine(TOOLTIP_ARENA_POINTS, nil, nil, nil, 1)
                GameTooltip:Show()
            elseif self.extraCurrencyType == 2 then
                GameTooltip:SetText(HONOR_POINTS, 1, 1, 1)
                GameTooltip:AddLine(TOOLTIP_HONOR_POINTS, nil, nil, nil, 1)
                GameTooltip:Show()
            elseif self.itemID then
                GameTooltip:SetHyperlink("item:" .. self.itemID)
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        return btn
    end

    -- Register with module
    mod.TokenBar = TokenBar
end

do
    local FilterButton = mod:NewClass("CheckButton")
    local SIZE = 20
    local IsModifierKeyDown = IsModifierKeyDown

    local GEM_ATLAS = [[Interface\AddOns\DragonUI\Textures\UI\RarityGemAtlas]]
    local GEM_COORDS = {
        border    = { 0.015625, 0.234375, 0.015625, 0.234375 },
        highlight = { 0.515625, 0.734375, 0.015625, 0.234375 },
        flash     = { 0.765625, 0.984375, 0.015625, 0.234375 },
        [0] = { 0.765625, 0.984375, 0.515625, 0.734375 }, -- poor
        [1] = { 0.015625, 0.234375, 0.515625, 0.734375 }, -- common
        [2] = { 0.015625, 0.234375, 0.265625, 0.484375 }, -- uncommon
        [3] = { 0.265625, 0.484375, 0.265625, 0.484375 }, -- rare
        [4] = { 0.515625, 0.734375, 0.265625, 0.484375 }, -- epic
        [5] = { 0.765625, 0.984375, 0.265625, 0.484375 }, -- legendary (covers the artifact flag too)
        [7] = { 0.265625, 0.484375, 0.515625, 0.734375 }, -- heirloom (atlas slot "gem6")
    }

    function FilterButton:Create(parent, quality, qualityFlag)
        local button = self:Bind(CreateFrame("CheckButton", nil, parent))
        button:SetSize(SIZE, SIZE)
        button:SetScript("OnClick", self.OnClick)
        button:SetScript("OnEnter", self.OnEnter)
        button:SetScript("OnLeave", self.OnLeave)

        local border = button:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints(button)
        border:SetTexture(GEM_ATLAS)
        border:SetTexCoord(unpack(GEM_COORDS.border))

        local gem = button:CreateTexture(nil, "ARTWORK")
        gem:SetAllPoints(button)
        gem:SetTexture(GEM_ATLAS)
        gem:SetTexCoord(unpack(GEM_COORDS[quality] or GEM_COORDS[1]))
        button.gem = gem

        -- Flash tinted with the rarity color, both on hover and while selected
        local r, g, b = GetItemQualityColor(quality)

        button:SetHighlightTexture(GEM_ATLAS)
        local hl = button:GetHighlightTexture()
        hl:SetAllPoints(button)
        hl:SetTexCoord(unpack(GEM_COORDS.flash))
        hl:SetBlendMode("ADD")
        hl:SetVertexColor(r, g, b)

        button:SetCheckedTexture(GEM_ATLAS)
        local ct = button:GetCheckedTexture()
        ct:SetAllPoints(button)
        ct:SetTexCoord(unpack(GEM_COORDS.flash))
        ct:SetBlendMode("ADD")
        ct:SetVertexColor(r, g, b)

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

    -- Inactive gems dim so the active filter reads at a glance
    function FilterButton:UpdateHighlight(quality)
        local active = bit.band(quality, self.qualityFlag) > 0
        self:SetChecked(active)
        self.gem:SetAlpha(active and 1 or 0.4)
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

        -- 7 buttons, 1px apart: real width keeps the row properly centered
        f:SetWidth(SIZE * 7 + (-2) * 6)
        f:SetHeight(SIZE)
        f:UpdateHighlight()

        return f
    end

    function QualityFilter:AddQualityButton(quality, qualityFlags)
        local button = FilterButton:Create(self, quality, qualityFlags or mod.QualityFlags[quality])
        if self.prev then
            button:SetPoint("LEFT", self.prev, "RIGHT", -2, 0)
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
            local nt = self:GetNormalTexture()
            nt:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            nt:ClearAllPoints()
            nt:SetAllPoints(self)
        end
    end

    -- The tab wing points outward, so flip the border when docked on the left side
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
                self.buttons[1]:SetPoint("TOPLEFT", parent, "TOPRIGHT", 1, -60)
            end
        end
        for _, button in pairs(self.buttons) do
            if button:IsShown() and button.SetReversed then
                button:SetReversed(self.reversed)
            end
        end
    end

    function SideFilter:UpdateFilters()
        local BagsterSet = mod("Sets")
        local parent = self:GetParent()
        local numFilters = 0

        for _, set in BagsterSet:GetParentSets() do
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
            self:SetFormattedText("|T%s:%d|t %s", set.icon, 14, displayName)
        else
            self:SetText(displayName)
        end
        -- Width follows the localized text, so long translations never overflow
        local width = self:GetTextWidth() + 24
        if width < 64 then
            width = 64
        end
        self:SetWidth(width)
        self:GetHighlightTexture():SetWidth(width)
    end

    function BottomTab:UpdateHighlight(setName)
        local active = self.set.name == setName
        if active then
            PanelTemplates_SelectTab(self)
            -- SelectTab forces GameFontHighlightSmall; we want the bigger font
            self:SetDisabledFontObject(GameFontHighlight)
        else
            PanelTemplates_DeselectTab(self)
        end
        -- Active tab mutes its own hover highlight
        self:GetHighlightTexture():SetAlpha(active and 0 or 1)
    end

    local BottomFilter = mod:NewClass("Frame")
    mod.BottomFilter = BottomFilter

    function BottomFilter:New(parent)
        local f = self:Bind(CreateFrame("Frame", parent:GetName() .. "BottomFilter", parent))
        f.buttons = setmetatable({}, { __index = function(t, k)
            local tab = BottomTab:New(f, k)
            if k > 1 then
                tab:SetPoint("LEFT", f.buttons[k - 1], "RIGHT", 8, 0)
            else
                -- Tab row hangs just under the frame's bottom edge
                tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 13, 2)
            end
            t[k] = tab
            return tab
        end })
        return f
    end

    function BottomFilter:UpdateFilters()
        local numFilters = 0
        local parent = self:GetParent()
        local BagsterSet = mod("Sets")

        for _, set in BagsterSet:GetChildSets(parent:GetCategory()) do
            if parent:HasSubSet(set.name, set.parent) then
                numFilters = numFilters + 1
                self.buttons[numFilters]:Set(set)
            end
        end

        if numFilters > 1 then
            for i = 1, numFilters do self.buttons[i]:Show() end
            for i = numFilters + 1, #self.buttons do self.buttons[i]:Hide() end
            self:UpdateHighlight()
            self:Show()
        else
            self:Hide()
        end
        self:GetParent():UpdateClampInsets()
    end

    function BottomFilter:UpdateHighlight()
        local category = self:GetParent():GetSubCategory()
        for _, button in pairs(self.buttons) do
            if button:IsShown() then
                button:UpdateHighlight(category)
            end
        end
    end
end
