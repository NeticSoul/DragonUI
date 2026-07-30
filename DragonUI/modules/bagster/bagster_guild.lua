-- Guild bank: bagster-styled replacement for the stock guild vault UI.
local addon = select(2, ...)
local mod = addon.BagsterModule

local format = string.format
local floor, ceil, min, max, sqrt = math.floor, math.ceil, math.min, math.max, math.sqrt

local MAX_SLOTS = MAX_GUILDBANK_SLOTS_PER_TAB or 98
local MAX_TABS = MAX_GUILDBANK_TABS or 6

local QUEST_ITEM_SEARCH = format("t:%s|%s", select(12, GetAuctionItemClasses()) or "Quest", "quest")
local LOG_TIME = GUILD_BANK_LOG_TIME or " |cff009999(%s)|r"

-- ============================================================================
-- GUILD ITEM SLOT
-- ============================================================================

do
    local GuildItemSlot = mod:NewClass("Button")
    mod.GuildItemSlot = GuildItemSlot

    local slotId = 1

    function GuildItemSlot:New(parent, slot)
        local item = self:Bind(CreateFrame("Button", format("DragonUI_BagsterGuildItem%d", slotId), parent, "ItemButtonTemplate"))
        slotId = slotId + 1
        item:SetID(slot)
        item:RegisterForClicks("anyUp")
        item:RegisterForDrag("LeftButton")

        local border = item:CreateTexture(nil, "OVERLAY")
        border:SetSize(67, 67)
        border:SetPoint("CENTER", item, "CENTER", 0, -1)
        border:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
        border:SetBlendMode("ADD")
        border:SetDrawLayer("OVERLAY", 3)
        border:Hide()
        item.border = border

        item:SetScript("OnClick", self.OnClick)
        item:SetScript("OnDragStart", self.OnDragStart)
        item:SetScript("OnReceiveDrag", self.OnDragStart)
        item:SetScript("OnEnter", self.OnEnter)
        item:SetScript("OnLeave", self.OnLeave)
        item:SetScript("OnHide", self.OnHide)

        mod.BagsterRetailItemSlot(item)
        return item
    end

    function GuildItemSlot:GetSlot()
        return self:GetParent().tab or 1, self:GetID()
    end

    function GuildItemSlot:GetItem()
        return self.hasItem
    end

    function GuildItemSlot:GetCount()
        local _, count = GetGuildBankItemInfo(self:GetSlot())
        return count or 0
    end

    function GuildItemSlot:IsLocked()
        local _, _, locked = GetGuildBankItemInfo(self:GetSlot())
        return locked
    end

    function GuildItemSlot:OnClick(button)
        if HandleModifiedItemClick(self:GetItem()) then
            return
        end
        if IsModifiedClick("SPLITSTACK") then
            if not self:IsLocked() then
                OpenStackSplitFrame(self:GetCount(), self, "BOTTOMLEFT", "TOPLEFT")
            end
            return
        end
        local cursorType, money = GetCursorInfo()
        if cursorType == "money" then
            DepositGuildBankMoney(money)
            ClearCursor()
        elseif cursorType == "guildbankmoney" then
            DropCursorMoney()
            ClearCursor()
        elseif button == "RightButton" then
            AutoStoreGuildBankItem(self:GetSlot())
        else
            PickupGuildBankItem(self:GetSlot())
        end
    end

    -- StackSplitFrame callback contract
    function GuildItemSlot:SplitStack(split)
        local tab, slot = self:GetSlot()
        SplitGuildBankItem(tab, slot, split)
    end

    function GuildItemSlot:OnDragStart()
        PickupGuildBankItem(self:GetSlot())
    end

    function GuildItemSlot:OnEnter()
        if self:GetItem() then
            if self:GetRight() >= (GetScreenWidth() / 2) then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            end
            GameTooltip:SetGuildBankItem(self:GetSlot())
            GameTooltip:Show()
            CursorUpdate(self)
        end
    end

    function GuildItemSlot:OnLeave()
        GameTooltip:Hide()
        ResetCursor()
    end

    function GuildItemSlot:OnHide()
        if self.hasStackSplit and self.hasStackSplit == 1 then
            StackSplitFrame:Hide()
        end
    end

    function GuildItemSlot:MatchesSearch()
        local search = self:GetParent().search
        if not search then return true end
        local link = self:GetItem()
        return (link and mod.ItemSearch:Find(link, search)) and true or false
    end

    function GuildItemSlot:UpdateSearch()
        self:SetAlpha(self:MatchesSearch() and 1 or 0.3)
        SetItemButtonDesaturated(self, self:IsLocked() or not self:MatchesSearch())
    end

    function GuildItemSlot:UpdateLocked()
        SetItemButtonDesaturated(self, self:IsLocked() or not self:MatchesSearch())
    end

    function GuildItemSlot:UpdateBorder()
        local border = self.border
        local link = self:GetItem()
        local cfg = mod.GetModuleConfig()

        if link then
            if (not cfg or cfg.glow_quest ~= false) and mod.ItemSearch:Find(link, QUEST_ITEM_SEARCH) then
                border:SetVertexColor(1, 0.82, 0.2, (cfg and cfg.glow_alpha) or 1)
                border:Show()
                return
            end
            local _, _, quality = GetItemInfo(link)
            if (not cfg or cfg.glow_quality ~= false) and quality and quality > 1 then
                local r, g, b = GetItemQualityColor(quality)
                border:SetVertexColor(r, g, b, (cfg and cfg.glow_alpha) or 1)
                border:Show()
                return
            end
        end
        border:Hide()
    end

    function GuildItemSlot:Update()
        local tab, slot = self:GetSlot()
        local texture, count, locked = GetGuildBankItemInfo(tab, slot)
        self.hasItem = GetGuildBankItemLink(tab, slot)

        SetItemButtonTexture(self, texture)
        SetItemButtonCount(self, count)
        SetItemButtonDesaturated(self, locked or not self:MatchesSearch())
        self:UpdateBorder()
        if addon.UpdateItemLevelSlot then
            addon.UpdateItemLevelSlot(self, self.hasItem, nil, "guildbank")
        end
        self:SetAlpha(self:MatchesSearch() and 1 or 0.3)

        if GameTooltip:IsOwned(self) then
            self:OnEnter()
        end
    end
end

-- ============================================================================
-- GUILD ITEM FRAME (98 fixed slots of the current tab)
-- ============================================================================

do
    local GuildItemFrame = mod:NewClass("Frame")
    mod.GuildItemFrame = GuildItemFrame

    function GuildItemFrame:New(parent)
        local f = self:Bind(CreateFrame("Frame", nil, parent))
        f.items = {}
        f.tab = 1

        for slot = 1, MAX_SLOTS do
            f.items[slot] = mod.GuildItemSlot:New(f, slot)
        end

        -- One-frame layout throttle: bank queries burst GUILDBANKBAGSLOTS_CHANGED
        f.updater = CreateFrame("Frame", nil, f)
        f.updater:Hide()
        f.updater:SetScript("OnUpdate", function(u)
            u:Hide()
            f:Layout()
        end)

        f:SetScript("OnShow", function(self)
            self:UpdateAll()
            self:RequestLayout()
        end)
        return f
    end

    function GuildItemFrame:SetTab(tab)
        if self.tab ~= tab then
            self.tab = tab
            self:UpdateAll()
        end
    end

    function GuildItemFrame:UpdateAll()
        for _, item in ipairs(self.items) do
            item:Update()
        end
    end

    function GuildItemFrame:UpdateLock(tab, slot)
        if tab == self.tab and slot and self.items[slot] then
            self.items[slot]:UpdateLocked()
        end
    end

    function GuildItemFrame:SetSearch(text)
        text = (text and text ~= '') and text or nil
        if self.search ~= text then
            self.search = text
            for _, item in ipairs(self.items) do
                item:UpdateSearch()
            end
        end
    end

    function GuildItemFrame:RequestLayout()
        self.updater:Show()
    end

    function GuildItemFrame:Layout()
        local width, height = self:GetWidth(), self:GetHeight()
        if width <= 0 or height <= 0 then return end

        local cfg = mod.GetModuleConfig()
        local spacing = (cfg and cfg.item_spacing) or 2
        local size = 36 + spacing * 2

        -- Fixed 14x7 grid: icons grow with the frame (1.5x hard cap, resize is clamped there too)
        local cols, rows = 14, 7
        local scale = min(width / (cols * size), height / (rows * size), 1.5)

        for i, item in ipairs(self.items) do
            local col = (i - 1) % cols
            local row = ceil(i / cols) - 1
            item:ClearAllPoints()
            item:SetScale(scale)
            item:SetPoint("TOPLEFT", self, "TOPLEFT", size * col + spacing, -(size * row + spacing))
            item:Show()
        end
    end
end

-- ============================================================================
-- GUILD FRAME
-- ============================================================================

do
    local GuildFrame = mod:NewClass("Frame")
    mod.GuildFrame = GuildFrame

    -- Static vault portrait: the ornate coffer icon, round-masked
    function GuildFrame:UpdateEmblem()
        if self.portraitDisc then
            SetPortraitToTexture(self.portraitDisc, [[Interface\Icons\INV_Misc_Coin_02]])
            self.portraitDisc:SetVertexColor(1, 1, 1)
        end
    end

    local function CreateGuildTabButton(f, i)
        local tab = CreateFrame("CheckButton", f:GetName() .. "SideTab" .. i, f)
        mod.SetupSideTabButton(tab)
        tab:SetID(i)
        if i > 1 then
            tab:SetPoint("TOP", f.tabButtons[i - 1], "BOTTOM", 0, -10)
        else
            tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 1, -60)
        end
        tab:RegisterForClicks("anyUp")
        tab:SetScript("OnClick", function(self, button)
            if self.buyTab then
                StaticPopup_Show("DRAGONUI_BUY_GUILDBANK_TAB")
                f:UpdateTabChecks()
                return
            end
            SetCurrentGuildBankTab(self:GetID())
            QueryGuildBankTab(self:GetID())
            f.itemFrame:SetTab(self:GetID())
            f:UpdateTabChecks()
            if f.mode ~= "bank" then
                f:RefreshMode()
            end
            -- Vanilla behavior: right-click opens the tab icon/name editor
            if button == "RightButton" and CanEditGuildTabInfo(self:GetID()) then
                f:ShowTabEditPopup(self:GetID())
            end
        end)
        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.buyTab then
                GameTooltip:SetText(GUILDBANK_BUYTAB or "Buy Tab", 1, 1, 1)
                GameTooltip:AddLine(GetDenominationsFromCopper(GetGuildBankTabCost() or 0))
                GameTooltip:Show()
                return
            end
            local name, _, isViewable, canDeposit, numWithdrawals = GetGuildBankTabInfo(self:GetID())
            GameTooltip:SetText(name or UNKNOWN)
            local access
            if not canDeposit and numWithdrawals == 0 then
                access = RED_FONT_COLOR_CODE .. "(" .. GUILDBANK_TAB_LOCKED .. ")" .. FONT_COLOR_CODE_CLOSE
            elseif not canDeposit then
                access = RED_FONT_COLOR_CODE .. "(" .. GUILDBANK_TAB_WITHDRAW_ONLY .. ")" .. FONT_COLOR_CODE_CLOSE
            elseif numWithdrawals == 0 then
                access = RED_FONT_COLOR_CODE .. "(" .. GUILDBANK_TAB_DEPOSIT_ONLY .. ")" .. FONT_COLOR_CODE_CLOSE
            else
                access = GREEN_FONT_COLOR_CODE .. "(" .. GUILDBANK_TAB_FULL_ACCESS .. ")" .. FONT_COLOR_CODE_CLOSE
            end
            GameTooltip:AddLine(access)
            GameTooltip:Show()
        end)
        return tab
    end

    StaticPopupDialogs["DRAGONUI_BUY_GUILDBANK_TAB"] = {
        text = CONFIRM_BUY_GUILDBANK_TAB or "Buy guild bank tab?",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            BuyGuildBankTab()
        end,
        OnShow = function(self)
            MoneyFrame_Update(self:GetName() .. "MoneyFrame", GetGuildBankTabCost() or 0)
        end,
        hasMoneyFrame = 1,
        timeout = 0,
        hideOnEscape = 1,
    }

    function GuildFrame:New()
        local name = "DragonUI_BagsterFrame3"
        local f = self:Bind(CreateFrame("Frame", name, UIParent))
        f.sets = mod.DB.guild
        f:SetSize(f.sets.w or 512, f.sets.h or 512)
        f:SetResizable(true)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:SetFrameStrata("HIGH")
        f:SetMinResize(384, 350)
        f:SetHitRectInsets(0, 35, 0, 10)
        f:Hide()

        local portraitTex = f:CreateTexture(name .. "Icon", "BACKGROUND")
        portraitTex:SetSize(62, 62)

        local closeBtn = CreateFrame("Button", name .. "CloseButton", f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -20)

        local iconBtn = CreateFrame("Button", name .. "IconButton", f)
        mod.SetupIconButton(iconBtn, f)

        local titleBtn = CreateFrame("Button", name .. "Title", f)
        mod.SetupDragFrame(titleBtn, f)
        f.title = titleBtn

        local searchEb = CreateFrame("EditBox", name .. "Search", f, "InputBoxTemplate")
        mod.SetupSearchBox(searchEb, f)
        searchEb:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -31)
        searchEb:SetWidth(200)

        local resetBtn = CreateFrame("Button", name .. "Reset", f)
        mod.SetupResetButton(resetBtn)
        resetBtn:SetPoint("RIGHT", searchEb, "RIGHT", -5, 0)
        resetBtn:SetFrameLevel(searchEb:GetFrameLevel() + 2)
        resetBtn:SetScript("OnClick", function()
            searchEb:ClearFocus()
            searchEb:SetText(SEARCH)
            f:SetSearch(nil)
        end)

        local resizeBtn = CreateFrame("Button", name .. "Resize", f)
        resizeBtn:SetSize(16, 16)
        resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeBtn:GetNormalTexture():SetAllPoints(resizeBtn)
        resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeBtn:GetPushedTexture():SetAllPoints(resizeBtn)
        resizeBtn:SetFrameLevel(resizeBtn:GetFrameLevel() + 4)
        resizeBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0)
        resizeBtn:SetScript("OnMouseDown", function(self)
            self:GetParent():StartSizing()
        end)
        resizeBtn:SetScript("OnMouseUp", function(self)
            self:GetParent():StopMovingOrSizing()
        end)

        f.itemFrame = mod.GuildItemFrame:New(f)
        f.itemFrame:SetPoint("TOPLEFT", 14, -62)

        -- Money display reused with guild funds and deposit/withdraw clicks
        f.GetPlayer = function() return mod.playerName end
        f.moneyFrame = mod.MoneyFrame:New(f)
        f.moneyFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 8)
        f.moneyFrame.GetMoneyValue = function() return GetGuildBankMoney() end
        f.moneyFrame.isGuildFunds = true
        f.moneyFrame:UnregisterEvent("PLAYER_MONEY")
        f.moneyFrame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
        f.moneyFrame:RegisterEvent("GUILDBANK_UPDATE_WITHDRAWMONEY")
        f.moneyFrame:SetScript("OnEvent", function(s) s:Update() end)

        local function GuildMoneyClick(_, button)
            local cursorMoney = GetCursorMoney() or 0
            if cursorMoney > 0 then
                DepositGuildBankMoney(cursorMoney)
                DropCursorMoney()
                return
            end
            if button == "RightButton" or IsShiftKeyDown() then
                if not CanWithdrawGuildBankMoney() then return end
                StaticPopup_Hide("GUILDBANK_DEPOSIT")
                StaticPopup_Show("GUILDBANK_WITHDRAW")
            else
                StaticPopup_Hide("GUILDBANK_WITHDRAW")
                StaticPopup_Show("GUILDBANK_DEPOSIT")
            end
        end
        local function GuildMoneyEnter(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(GUILD_BANK, 1, 1, 1)
            GameTooltip:AddLine("|cff00ff00" .. KEY_BUTTON1 .. "|r " .. DEPOSIT)
            if CanWithdrawGuildBankMoney() then
                GameTooltip:AddLine("|cff00ff00" .. KEY_BUTTON2 .. "|r " .. WITHDRAW)
            end
            GameTooltip:Show()
        end
        for _, b in pairs({ f.moneyFrame.btnGold, f.moneyFrame.btnSilver, f.moneyFrame.btnCopper, f.moneyFrame.btnText }) do
            b:RegisterForClicks("anyUp")
            b:SetScript("OnClick", GuildMoneyClick)
            b:SetScript("OnEnter", GuildMoneyEnter)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        f.tabButtons = {}

        -- Log / money log / tab info share one scrolling viewer in place of the grid
        local logFrame = CreateFrame("ScrollingMessageFrame", nil, f)
        logFrame:SetFontObject(GameFontHighlightSmall)
        logFrame:SetJustifyH("LEFT")
        logFrame:SetFading(false)
        logFrame:SetMaxLines(128)
        logFrame:SetInsertMode("TOP")
        logFrame:SetPoint("TOPLEFT", 20, -68)
        logFrame:EnableMouseWheel(true)
        logFrame:SetScript("OnMouseWheel", function(s, delta)
            if delta > 0 then s:ScrollUp() else s:ScrollDown() end
        end)
        logFrame:SetHyperlinksEnabled(true)
        logFrame:SetScript("OnHyperlinkClick", function(_, link, text, button)
            SetItemRef(link, text, button)
        end)
        logFrame:SetScript("OnHyperlinkEnter", function(s, link)
            GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end)
        logFrame:SetScript("OnHyperlinkLeave", function()
            GameTooltip:Hide()
        end)
        logFrame:Hide()
        f.logFrame = logFrame

        -- Editable tab info: fixed dark box with an inner scroll, like the stock vault's info tab
        local infoBox = CreateFrame("Frame", nil, f)
        infoBox:SetPoint("TOPLEFT", 20, -68)
        infoBox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        infoBox:SetBackdropColor(0, 0, 0, 0.55)
        infoBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        infoBox:Hide()
        f.infoBox = infoBox

        local infoScroll = CreateFrame("ScrollFrame", name .. "InfoScroll", infoBox, "UIPanelScrollFrameTemplate")
        infoScroll:SetPoint("TOPLEFT", 8, -8)
        infoScroll:SetPoint("BOTTOMRIGHT", -30, 8)

        local infoEdit = CreateFrame("EditBox", nil, infoScroll)
        infoEdit:SetMultiLine(true)
        infoEdit:SetMaxLetters(500)
        infoEdit:SetAutoFocus(false)
        infoEdit:SetFontObject(GameFontHighlightSmall)
        -- ScrollingEdit_* helpers do math on these before any cursor event fires
        infoEdit.cursorOffset = 0
        infoEdit.cursorHeight = 0
        infoEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        infoEdit:SetScript("OnCursorChanged", function(s, x, y, w, h)
            ScrollingEdit_OnCursorChanged(s, x, y, w, h)
        end)
        infoEdit:SetScript("OnUpdate", function(s, elapsed)
            ScrollingEdit_OnUpdate(s, elapsed, infoScroll)
        end)
        infoEdit:SetScript("OnTextChanged", function(s)
            ScrollingEdit_OnTextChanged(s, infoScroll)
        end)
        infoScroll:SetScrollChild(infoEdit)
        f.infoEdit = infoEdit

        -- Click anywhere in the box to start typing
        for _, region in ipairs({ infoBox, infoScroll }) do
            region:EnableMouse(true)
            region:SetScript("OnMouseDown", function() infoEdit:SetFocus() end)
        end

        local infoSave = CreateFrame("Button", name .. "InfoSave", f, "UIPanelButtonTemplate")
        infoSave:SetSize(80, 22)
        infoSave:SetText(SAVE)
        infoSave:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 6)
        infoSave:SetScript("OnClick", function()
            SetGuildBankText(GetCurrentGuildBankTab() or 1, infoEdit:GetText() or "")
            infoEdit:ClearFocus()
        end)
        infoSave:Hide()
        f.infoSave = infoSave

        -- Bottom mode tabs, same retail chips as the category tabs
        f.modeTabs = {}
        local modes = {
            { label = BANK or "Bank", mode = "bank" },
            { label = "Log", mode = "log" },
            { label = MONEY or "Money", mode = "moneylog" },
            { label = "Info", mode = "info" },
        }
        for i, info in ipairs(modes) do
            local tab = CreateFrame("Button", name .. "Tab" .. i, f, "CharacterFrameTabButtonTemplate")
            mod.SetupBottomTabButton(tab)
            tab:SetID(i)
            tab.mode = info.mode
            tab:SetText(info.label)
            local width = tab:GetTextWidth() + 24
            if width < 64 then width = 64 end
            tab:SetWidth(width)
            tab:GetHighlightTexture():SetWidth(width)
            if i > 1 then
                tab:SetPoint("LEFT", f.modeTabs[i - 1], "RIGHT", 8, 0)
            else
                tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 13, 2)
            end
            tab:SetScript("OnClick", function(self)
                f:SetMode(self.mode)
            end)
            f.modeTabs[i] = tab
        end

        f:SetScript("OnShow", self.OnShow)
        f:SetScript("OnHide", self.OnHide)
        f:SetScript("OnSizeChanged", self.OnSizeChanged)
        f:SetScript("OnEvent", self.OnEvent)

        tinsert(UISpecialFrames, name)
        mod.BagsterSkinFrame(f)
        f.title:SetText(GUILD_BANK)

        -- Guild emblem takes the portrait's spot: the portrait texture becomes the round disc
        local skinnedIcon = _G[name .. "IconButton"]
        if skinnedIcon and skinnedIcon.icon then
            skinnedIcon:SetScript("OnShow", nil)
            skinnedIcon:SetScript("OnEvent", nil)
            f.portraitDisc = skinnedIcon.icon

            -- Press zoom: texcoords would break the file-portrait mask, so GROW the disc
            -- instead — the image zooms in and its edge slides under the ring, which clips it
            local disc = f.portraitDisc
            local pSize = disc:GetWidth()
            local pPoint, pRel, pRelPoint, pX, pY = disc:GetPoint(1)
            skinnedIcon:SetScript("OnMouseDown", function()
                disc:SetSize(pSize + 4, pSize + 4)
                disc:SetPoint(pPoint, pRel, pRelPoint, pX - 2, pY + 2)
            end)
            skinnedIcon:SetScript("OnMouseUp", function()
                disc:SetSize(pSize, pSize)
                disc:SetPoint(pPoint, pRel, pRelPoint, pX, pY)
            end)
            -- Same action as the TOGGLEGUILDTAB key binding
            skinnedIcon:SetScript("OnClick", function()
                ToggleFriendsFrame(3)
            end)
        end

        f:LoadPosition()
        f:UpdateItemFrameSize()
        f:SetMode("bank")
        return f
    end

    function GuildFrame:SetSearch(text)
        self.itemFrame:SetSearch(text)
    end

    -- Own tiny icon/name editor: same public APIs as the stock popup, zero dependency
    -- on the suppressed vault addon (loading it lets UIParent resurrect the stock frame)
    local EDIT_COLS, EDIT_ROWS = 5, 4
    local EDIT_PER_PAGE = EDIT_COLS * EDIT_ROWS

    local function CreateTabEditor(f)
        local ed = CreateFrame("Frame", f:GetName() .. "TabEditor", f)
        ed:SetSize(EDIT_COLS * 38 + 26, 288)
        ed:SetPoint("TOPLEFT", f, "TOPRIGHT", 42, 0)
        ed:SetFrameStrata("DIALOG")
        ed:EnableMouse(true)
        ed:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        ed:SetBackdropColor(0, 0, 0, 0.85)
        ed:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        tinsert(UISpecialFrames, ed:GetName())

        local nameBox = CreateFrame("EditBox", ed:GetName() .. "Name", ed, "InputBoxTemplate")
        nameBox:SetSize(EDIT_COLS * 38 - 12, 20)
        nameBox:SetPoint("TOP", 4, -14)
        nameBox:SetAutoFocus(false)
        nameBox:SetMaxLetters(15)
        nameBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        nameBox:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
        ed.nameBox = nameBox

        ed.icons = {}
        for i = 1, EDIT_PER_PAGE do
            local b = CreateFrame("CheckButton", nil, ed)
            b:SetSize(36, 36)
            local col, row = (i - 1) % EDIT_COLS, floor((i - 1) / EDIT_COLS)
            b:SetPoint("TOPLEFT", ed, "TOPLEFT", 14 + col * 38, -42 - row * 38)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints(b)
            b.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            b:GetHighlightTexture():SetBlendMode("ADD")
            b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
            b:GetCheckedTexture():SetBlendMode("ADD")
            b:SetScript("OnClick", function(self)
                ed.selectedIcon = self.iconIndex
                ed:Refresh()
            end)
            ed.icons[i] = b
        end

        ed:EnableMouseWheel(true)
        ed:SetScript("OnMouseWheel", function(self, delta)
            self.page = max(0, min(self.maxPage or 0, (self.page or 0) - delta))
            self:Refresh()
        end)

        local prev = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
        prev:SetSize(24, 20)
        prev:SetPoint("BOTTOMLEFT", 10, 36)
        prev:SetText("<")
        prev:SetScript("OnClick", function()
            ed.page = max(0, (ed.page or 0) - 1)
            ed:Refresh()
        end)

        local nxt = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
        nxt:SetSize(24, 20)
        nxt:SetPoint("BOTTOMRIGHT", -10, 36)
        nxt:SetText(">")
        nxt:SetScript("OnClick", function()
            ed.page = min(ed.maxPage or 0, (ed.page or 0) + 1)
            ed:Refresh()
        end)

        ed.pageText = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ed.pageText:SetPoint("BOTTOM", 0, 40)

        local okay = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
        okay:SetSize(70, 20)
        okay:SetPoint("BOTTOMLEFT", 10, 10)
        okay:SetText(OKAY)
        okay:SetScript("OnClick", function()
            local name = ed.nameBox:GetText()
            if not name or name == "" then
                name = format(GUILDBANK_TAB_NUMBER or "Tab %d", ed.tabID)
            end
            SetGuildBankTabInfo(ed.tabID, name, ed.selectedIcon)
            ed:Hide()
        end)

        local cancel = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
        cancel:SetSize(70, 20)
        cancel:SetPoint("BOTTOMRIGHT", -10, 10)
        cancel:SetText(CANCEL)
        cancel:SetScript("OnClick", function() ed:Hide() end)

        function ed:Refresh()
            local total = GetNumMacroItemIcons()
            self.maxPage = max(0, ceil(total / EDIT_PER_PAGE) - 1)
            for i, b in ipairs(self.icons) do
                local index = (self.page or 0) * EDIT_PER_PAGE + i
                if index <= total then
                    b.iconIndex = index
                    b.icon:SetTexture(GetMacroItemIconInfo(index))
                    b:SetChecked(index == self.selectedIcon)
                    b:Show()
                else
                    b:Hide()
                end
            end
            self.pageText:SetFormattedText("%d / %d", (self.page or 0) + 1, self.maxPage + 1)
        end

        ed:Hide()
        return ed
    end

    function GuildFrame:ShowTabEditPopup(tabID)
        if not self.tabEditor then
            self.tabEditor = CreateTabEditor(self)
        end
        local ed = self.tabEditor
        local name, icon = GetGuildBankTabInfo(tabID)
        ed.tabID = tabID
        ed.page = 0
        ed.selectedIcon = nil
        -- Preselect the tab's current icon and jump to its page
        for i = 1, GetNumMacroItemIcons() do
            if GetMacroItemIconInfo(i) == icon then
                ed.selectedIcon = i
                ed.page = floor((i - 1) / EDIT_PER_PAGE)
                break
            end
        end
        ed.nameBox:SetText(name or "")
        ed:Refresh()
        ed:Show()
    end

    function GuildFrame:OnTitleEnter(title)
        GameTooltip:SetOwner(title, "ANCHOR_LEFT")
        GameTooltip:SetText(GUILD_BANK, 1, 1, 1)
        GameTooltip:AddLine(mod.L.MoveTip)
        GameTooltip:AddLine(mod.L.ResetPositionTip)
        GameTooltip:Show()
    end

    function GuildFrame:SavePosition(point, parent, relPoint, x, y)
        if point then
            self.sets.position = { point, nil, relPoint, x, y }
        else
            self.sets.position = nil
        end
        self:LoadPosition()
    end

    function GuildFrame:LoadPosition()
        self:ClearAllPoints()
        if self.sets.position then
            local point, _, relPoint, x, y = unpack(self.sets.position)
            self:SetPoint(point, UIParent, relPoint, x, y)
        else
            self:SetPoint("LEFT", UIParent, "LEFT", 24, 0)
        end
    end

    function GuildFrame:OnSizeChanged()
        self.sets.w = self:GetWidth()
        self.sets.h = self:GetHeight()
        self:UpdateItemFrameSize()
    end

    function GuildFrame:UpdateItemFrameSize()
        -- Clamp resizing to where the 14x7 grid hits its 1.5x icon cap
        local cfg = mod.GetModuleConfig()
        local spacing = (cfg and cfg.item_spacing) or 2
        local size = (36 + spacing * 2) * 1.5
        self:SetMaxResize(14 * size + 34, 7 * size + 96)

        self.itemFrame:SetWidth(self:GetWidth() - 30)
        self.itemFrame:SetHeight(self:GetHeight() - 92)
        self.itemFrame:RequestLayout()
        self.logFrame:SetWidth(self:GetWidth() - 44)
        self.logFrame:SetHeight(self:GetHeight() - 104)
        self.infoBox:SetWidth(self:GetWidth() - 44)
        self.infoBox:SetHeight(self:GetHeight() - 132)
        self.infoEdit:SetWidth(self:GetWidth() - 90)
    end

    function GuildFrame:SetMode(mode)
        self.mode = mode
        self.logFrame:Hide()
        self.infoBox:Hide()
        self.infoSave:Hide()
        self.itemFrame:Hide()
        if mode == "bank" then
            self.itemFrame:Show()
        else
            self:RefreshMode()
        end
        for _, tab in ipairs(self.modeTabs) do
            local active = tab.mode == mode
            if active then
                PanelTemplates_SelectTab(tab)
                tab:SetDisabledFontObject(GameFontHighlight)
            else
                PanelTemplates_DeselectTab(tab)
            end
            tab:GetHighlightTexture():SetAlpha(active and 0 or 1)
        end
    end

    function GuildFrame:RefreshMode()
        local tab = GetCurrentGuildBankTab() or 1
        if self.mode == "log" then
            QueryGuildBankLog(tab)
            self.logFrame:Show()
            self:UpdateLog()
        elseif self.mode == "moneylog" then
            QueryGuildBankLog(MAX_TABS + 1)
            self.logFrame:Show()
            self:UpdateMoneyLog()
        elseif self.mode == "info" then
            QueryGuildBankText(tab)
            self:UpdateInfo()
        end
    end

    -- Verbatim ports of the stock vault's log formatting
    function GuildFrame:UpdateLog()
        local tab = GetCurrentGuildBankTab() or 1
        local log = self.logFrame
        log:Clear()
        for i = 1, GetNumGuildBankTransactions(tab) do
            local kind, who, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i)
            who = NORMAL_FONT_COLOR_CODE .. (who or UNKNOWN) .. FONT_COLOR_CODE_CLOSE
            local msg
            if kind == "deposit" then
                msg = format(GUILDBANK_DEPOSIT_FORMAT, who, itemLink)
                if count > 1 then
                    msg = msg .. format(GUILDBANK_LOG_QUANTITY, count)
                end
            elseif kind == "withdraw" then
                msg = format(GUILDBANK_WITHDRAW_FORMAT, who, itemLink)
                if count > 1 then
                    msg = msg .. format(GUILDBANK_LOG_QUANTITY, count)
                end
            elseif kind == "move" then
                msg = format(GUILDBANK_MOVE_FORMAT, who, itemLink, count, GetGuildBankTabInfo(tab1), GetGuildBankTabInfo(tab2))
            end
            if msg then
                log:AddMessage(msg .. LOG_TIME:format(RecentTimeDate(year, month, day, hour)))
            end
        end
    end

    function GuildFrame:UpdateMoneyLog()
        local log = self.logFrame
        log:Clear()
        for i = 1, GetNumGuildBankMoneyTransactions() do
            local kind, who, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i)
            who = NORMAL_FONT_COLOR_CODE .. (who or UNKNOWN) .. FONT_COLOR_CODE_CLOSE
            local money = GetDenominationsFromCopper(amount or 0)
            local msg
            if kind == "deposit" then
                msg = GUILDBANK_DEPOSIT_MONEY_FORMAT:format(who, money)
            elseif kind == "withdraw" then
                msg = GUILDBANK_WITHDRAW_MONEY_FORMAT:format(who, money)
            elseif kind == "repair" then
                msg = GUILDBANK_REPAIR_MONEY_FORMAT:format(who, money)
            elseif kind == "withdrawForTab" then
                msg = GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT:format(who, money)
            elseif kind == "buyTab" then
                msg = GUILDBANK_BUYTAB_MONEY_FORMAT:format(who, money)
            end
            if msg then
                log:AddMessage(msg .. LOG_TIME:format(RecentTimeDate(year, month, day, hour)))
            end
        end
    end

    function GuildFrame:UpdateInfo()
        local tab = GetCurrentGuildBankTab() or 1
        local text = GetGuildBankText(tab) or ""
        if CanEditGuildTabInfo(tab) then
            self.logFrame:Hide()
            -- Don't clobber in-progress typing when the server echoes the text back
            if not self.infoEdit:HasFocus() then
                self.infoEdit:SetText(text)
            end
            self.infoBox:Show()
            self.infoSave:Show()
        else
            self.infoBox:Hide()
            self.infoSave:Hide()
            local log = self.logFrame
            log:Clear()
            if text ~= "" then
                log:AddMessage(text, 1, 1, 1)
            end
            log:Show()
        end
    end

    function GuildFrame:UpdateTabs()
        local numTabs = GetNumGuildBankTabs()
        local showBuy = IsGuildLeader() and numTabs < MAX_TABS
        local total = numTabs + (showBuy and 1 or 0)

        for i = 1, total do
            local tab = self.tabButtons[i]
            if not tab then
                tab = CreateGuildTabButton(self, i)
                self.tabButtons[i] = tab
            end
            tab.buyTab = showBuy and i == total or nil
            local icon, isViewable
            if not tab.buyTab then
                local _, tabIcon, viewable = GetGuildBankTabInfo(i)
                icon, isViewable = tabIcon, viewable
            end
            tab:SetNormalTexture(icon or [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]])
            local nt = tab:GetNormalTexture()
            nt:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            nt:ClearAllPoints()
            nt:SetAllPoints(tab)
            if tab.buyTab or not isViewable then
                nt:SetVertexColor(1, 0.1, 0.1)
            else
                nt:SetVertexColor(1, 1, 1)
            end
            tab:Show()
        end
        for i = total + 1, #self.tabButtons do
            self.tabButtons[i]:Hide()
        end
        self:UpdateTabChecks()
    end

    function GuildFrame:UpdateTabChecks()
        local current = GetCurrentGuildBankTab() or 1
        for i, tab in ipairs(self.tabButtons) do
            tab:SetChecked(i == current)
        end
    end

    function GuildFrame:OnEvent(event, arg1, arg2)
        if event == "GUILDBANKBAGSLOTS_CHANGED" then
            self.itemFrame:UpdateAll()
            self:UpdateTabs()
        elseif event == "GUILDBANK_ITEM_LOCK_CHANGED" then
            self.itemFrame:UpdateLock(arg1, arg2)
        elseif event == "GUILDBANK_UPDATE_TABS" then
            self:UpdateTabs()
        elseif event == "GUILDBANKLOG_UPDATE" then
            if self.mode == "log" then
                self:UpdateLog()
            elseif self.mode == "moneylog" then
                self:UpdateMoneyLog()
            end
        elseif event == "GUILDBANK_UPDATE_TEXT" then
            if self.mode == "info" then
                self:UpdateInfo()
            end
        end
    end

    function GuildFrame:OnShow()
        PlaySound("GuildVaultOpen")
        self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
        self:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED")
        self:RegisterEvent("GUILDBANK_UPDATE_TABS")
        self:RegisterEvent("GUILDBANKLOG_UPDATE")
        self:RegisterEvent("GUILDBANK_UPDATE_TEXT")
        self.itemFrame:SetTab(GetCurrentGuildBankTab() or 1)
        self:UpdateTabs()
        self:UpdateEmblem()
        self.itemFrame:UpdateAll()
        self.moneyFrame:Update()
        self:UpdateItemFrameSize()
        self:SetMode(self.mode or "bank")
    end

    function GuildFrame:OnHide()
        PlaySound("GuildVaultClose")
        self:UnregisterAllEvents()
        StaticPopup_Hide("GUILDBANK_DEPOSIT")
        StaticPopup_Hide("GUILDBANK_WITHDRAW")
        if self.tabEditor then
            self.tabEditor:Hide()
        end
        CloseGuildBankFrame()
    end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function mod.ShowGuildFrame()
    if not mod.DB then return end
    if not mod.guildFrame then
        mod.guildFrame = mod.GuildFrame:New()
    end
    mod.guildFrame.itemFrame.tab = GetCurrentGuildBankTab() or 1
    mod.guildFrame:Show()
    QueryGuildBankTab(GetCurrentGuildBankTab() or 1)
end

function mod.HideGuildFrame()
    if mod.guildFrame then
        mod.guildFrame:Hide()
    end
end

do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GUILDBANKFRAME_OPENED")
    watcher:RegisterEvent("GUILDBANKFRAME_CLOSED")
    watcher:SetScript("OnEvent", function(_, event)
        if not mod.BagsterModule.applied then return end
        if event == "GUILDBANKFRAME_OPENED" then
            mod.ShowGuildFrame()
        else
            mod.HideGuildFrame()
        end
    end)
end
