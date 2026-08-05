-- FrameEvents relay, InventoryFrame class, template helpers and frame skinning.
local addon = select(2, ...)
local mod = addon.BagsterModule

local format = string.format
local tinsert = table.insert

-- ============================================================================
-- TEMPLATE HELPERS (moved from core: used by InventoryFrame)
-- ============================================================================


-- DragonUI_BagsterIconButtonTemplate (portrait)
local function SetupIconButton(btn, parentFrame)
    btn:SetSize(64, 64)
    btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 4, -4)

    -- HighlightTexture: UI-Minimap-ZoomButton-Highlight
    local ht = btn:CreateTexture(nil, "HIGHLIGHT")
    ht:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    ht:SetSize(78, 78)
    ht:SetPoint("CENTER")
    ht:SetBlendMode("ADD")
    btn:SetHighlightTexture(ht)

    btn:RegisterForClicks("anyUp")
    btn.icon = _G[parentFrame:GetName() .. "Icon"]
    btn.icon:ClearAllPoints()
    btn.icon:SetPoint("CENTER", btn)

    btn:SetScript("OnEvent", function(self, event, unit)
        if self:IsShown() and unit == "player" then
            SetPortraitTexture(self.icon, unit)
        end
    end)
    btn:SetScript("OnShow", function(self)
        SetPortraitTexture(self.icon, "player")
        self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    end)
    btn:SetScript("OnHide", function(self)
        self:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
    end)
    btn:SetScript("OnMouseDown", function(self)
        self.icon:SetWidth(56)
        self.icon:SetHeight(56)
        self.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.icon:SetWidth(62)
        self.icon:SetHeight(62)
        self.icon:SetTexCoord(0, 1, 0, 1)
    end)
    btn:SetScript("OnEnter", function() GameTooltip:Hide() end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- DragonUI_BagsterDragFrameTemplate (title/drag bar)
local function SetupDragFrame(btn, parentFrame)
    btn:SetSize(262, 14)
    btn:SetPoint("TOP", parentFrame, "TOP", 0, -16)

    btn:RegisterForClicks("anyUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnClick", function(self, button)
        if IsAltKeyDown() and button == "RightButton" then
            self:GetParent():SavePosition(nil)
        end
    end)
    btn:SetScript("OnMouseDown", function(self)
        self.isMoving = true
        self:GetParent():StartMoving()
    end)
    btn:SetScript("OnMouseUp", function(self)
        if self.isMoving then
            self.isMoving = nil
            self:GetParent():StopMovingOrSizing()
            self:GetParent():SavePosition(self:GetParent():GetPoint())
        end
    end)
    btn:SetScript("OnEnter", function(self)
        self:GetParent():OnTitleEnter(self)
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetNormalFontObject(GameFontNormal)
    btn:SetHighlightFontObject(GameFontHighlight)
end

-- DragonUI_BagsterSearchBoxTemplate
local function SetupSearchBox(eb, parentFrame)
    eb:SetAutoFocus(false)
    eb:SetHeight(24)

    -- Retail-style dark search box: hide the classic gold input art, add backdrop + magnifier
    local name = eb:GetName()
    for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
        local tex = _G[name .. suffix]
        if tex then
            tex:Hide()
            tex:SetTexture(nil)
        end
    end
    eb:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    eb:SetBackdropColor(0, 0, 0, 0.55)
    eb:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    eb:SetTextInsets(24, 20, 0, 0)

    local magnifier = eb:CreateTexture(nil, "OVERLAY")
    magnifier:SetTexture("Interface\\Minimap\\Tracking\\None")
    magnifier:SetSize(14, 14)
    magnifier:SetPoint("LEFT", eb, "LEFT", 7, 0)
    magnifier:SetVertexColor(0.6, 0.6, 0.6)

    local function UpdatePlaceholderColor(self)
        if self:GetText() == SEARCH then
            self:SetTextColor(0.55, 0.55, 0.55)
        else
            self:SetTextColor(1, 1, 1)
        end
    end

    eb:SetScript("OnShow", function(self)
        if self:GetText() == '' then
            self:SetText(SEARCH)
        end
        UpdatePlaceholderColor(self)
    end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- ClearFocus first: SetText while focused would fire OnTextChanged and search for "Search"
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(SEARCH)
        self:GetParent():SetSearch(nil)
        UpdatePlaceholderColor(self)
    end)
    eb:SetScript("OnTextChanged", function(self)
        if self:HasFocus() then
            local text = self:GetText()
            self:GetParent():SetSearch((text ~= '' and text:lower()) or nil)
        end
        UpdatePlaceholderColor(self)
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self:GetText() == '' then
            self:SetText(SEARCH)
        end
        UpdatePlaceholderColor(self)
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        if self:GetText() == SEARCH then
            self:SetText('')
        end
        self:SetTextColor(1, 1, 1)
    end)
end

-- Clear-search "X" tucked inside the search box, retail style
local function SetupResetButton(btn)
    btn:SetSize(14, 14)
    local icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
    local nt = btn:CreateTexture(nil, "ARTWORK")
    nt:SetTexture(icon)
    nt:SetAllPoints(btn)
    nt:SetVertexColor(0.7, 0.7, 0.7)
    btn:SetNormalTexture(nt)
    local ht = btn:CreateTexture(nil, "HIGHLIGHT")
    ht:SetTexture(icon)
    ht:SetBlendMode("ADD")
    ht:SetAllPoints(btn)
    btn:SetHighlightTexture(ht)
end

-- Built exactly like the dropdown Bag buttons so ring/glow/icon align identically
local function SetupBagToggle(btn, parentFrame)
    btn:SetSize(30, 30)

    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(36, 36)
    background:SetPoint("CENTER")
    background:SetTexture(mod.CT.bagslot)
    background:SetTexCoord(295 / 512, 356 / 512, 64 / 128, 125 / 128)

    local icon = btn:CreateTexture(btn:GetName() .. "Icon", "BORDER")
    icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    icon:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -5, -2.9)
    icon:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2.9, 5)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local ringBorder = btn:CreateTexture(nil, "OVERLAY")
    ringBorder:SetSize(36, 36)
    ringBorder:SetPoint("CENTER")
    ringBorder:SetTexture(mod.CT.bagslot)
    ringBorder:SetTexCoord(295 / 512, 356 / 512, 1 / 128, 62 / 128)

    btn:RegisterForClicks("anyUp")

    btn:SetScript("OnClick", function(self, button)
        self:GetParent():OnBagToggleClick(self, button)
    end)
    -- Same optical click-zoom as the portrait: crop in on press, restore on release
    btn:SetScript("OnMouseDown", function(self)
        icon:SetTexCoord(0.14, 0.86, 0.14, 0.86)
    end)
    btn:SetScript("OnMouseUp", function(self)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end)
    btn:SetScript("OnEnter", function(self)
        self:GetParent():OnBagToggleEnter(self)
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetHighlightTexture("")
    local ht = btn:GetHighlightTexture()
    ht:SetAllPoints()
    ht:SetBlendMode("ADD")
    ht:SetAlpha(0.4)
    ht:SetTexture(mod.CT.bagslot)
    ht:SetTexCoord(358 / 512, 419 / 512, 1 / 128, 62 / 128)
end

-- Replaces DragonUI_BagsterInventoryTemplate entirely
-- Creates the main inventory/bank frame with all children in pure Lua.
local function CreateInventoryFrame(name, parent)
    parent = parent or UIParent
    local f = CreateFrame("Frame", name, parent)
    f:SetSize(384, 512)
    f:SetResizable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetFrameStrata("HIGH")
    f:Hide()
    f:SetHitRectInsets(0, 35, 0, 75)

    -- BACKGROUND: $parentIcon (62x62, portrait target)
    local portraitTex = f:CreateTexture(name .. "Icon", "BACKGROUND")
    portraitTex:SetSize(62, 62)

    -- $parentCloseButton (UIPanelCloseButton)
    local closeBtn = CreateFrame("Button", name .. "CloseButton", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -20)

    -- $parentIconButton
    local iconBtn = CreateFrame("Button", name .. "IconButton", f)
    SetupIconButton(iconBtn, f)

    -- $parentTitle
    local titleBtn = CreateFrame("Button", name .. "Title", f)
    SetupDragFrame(titleBtn, f)

    -- $parentSearch
    local searchEb = CreateFrame("EditBox", name .. "Search", f, "InputBoxTemplate")
    SetupSearchBox(searchEb, f)

    -- $parentBagToggle (create first, anchor from RIGHT)
    local bagToggleBtn = CreateFrame("Button", name .. "BagToggle", f)
    SetupBagToggle(bagToggleBtn, f)

    -- $parentReset
    local resetBtn = CreateFrame("Button", name .. "Reset", f)
    SetupResetButton(resetBtn)
    resetBtn:SetScript("OnClick", function()
        searchEb:ClearFocus()
        searchEb:SetText(SEARCH)
        f:SetSearch(nil)
    end)

    -- Header: one row right of the portrait, buttons trailing the search box
    bagToggleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -30)

    searchEb:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -31)
    searchEb:SetWidth(200)

    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("RIGHT", searchEb, "RIGHT", -5, 0)
    -- Above the EditBox or it never receives the click
    resetBtn:SetFrameLevel(searchEb:GetFrameLevel() + 2)

    -- $parentResize
    local resizeBtn = CreateFrame("Button", name .. "Resize", f)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:GetNormalTexture():SetAllPoints(resizeBtn)
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:GetPushedTexture():SetAllPoints(resizeBtn)
    local resizeHt = resizeBtn:CreateTexture(nil, "HIGHLIGHT")
    resizeHt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHt:SetBlendMode("ADD")
    resizeHt:SetAllPoints(resizeBtn)
    resizeBtn:SetHighlightTexture(resizeHt)

    -- OnLoad never fires on frames built via CreateFrame; apply directly
    resizeBtn:SetFrameLevel(resizeBtn:GetFrameLevel() + 4)
    resizeBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0)
    resizeBtn:SetScript("OnMouseDown", function(self)
        self:GetParent():StartSizing()
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        self:GetParent():StopMovingOrSizing()
    end)

    -- OnSizeChanged
    f:SetScript("OnSizeChanged", function(self)
        self:OnSizeChanged(self:GetWidth(), self:GetHeight())
    end)

    return f
end


do
    local FrameEvents = mod:NewModule("FrameEvents")
    local frames = {}

    function FrameEvents:Load()
        local CSet = mod("Sets")
        CSet:RegisterMessage(self, "BAGSTER_SET_ADD", "UpdateSets")
        CSet:RegisterMessage(self, "BAGSTER_SET_UPDATE", "UpdateSets")
        CSet:RegisterMessage(self, "BAGSTER_SET_REMOVE", "UpdateSets")
        CSet:RegisterMessage(self, "BAGSTER_CONFIG_SET_ADD", "UpdateSetConfig")
        CSet:RegisterMessage(self, "BAGSTER_CONFIG_SET_REMOVE", "UpdateSetConfig")
        CSet:RegisterMessage(self, "BAGSTER_SUBSET_ADD", "UpdateSubSets")
        CSet:RegisterMessage(self, "BAGSTER_SUBSET_UPDATE", "UpdateSubSets")
        CSet:RegisterMessage(self, "BAGSTER_SUBSET_REMOVE", "UpdateSubSets")
        CSet:RegisterMessage(self, "BAGSTER_CONFIG_SUBSET_ADD", "UpdateSubSetConfig")
        CSet:RegisterMessage(self, "BAGSTER_CONFIG_SUBSET_REMOVE", "UpdateSubSetConfig")
    end

    function FrameEvents:UpdateSets(msg, name)
        for f in self:GetFrames() do
            if f:HasSet(name) then f:UpdateSets() end
        end
    end

    function FrameEvents:UpdateSetConfig(msg, key, name)
        for f in self:GetFrames() do
            if f.key == key then f:UpdateSets() end
        end
    end

    function FrameEvents:UpdateSubSetConfig(msg, key, name, parent)
        for f in self:GetFrames() do
            if f.key == key and f:GetCategory() == parent then f:UpdateSubSets() end
        end
    end

    function FrameEvents:UpdateSubSets(msg, name, parent)
        for f in self:GetFrames() do
            if f:GetCategory() == parent then f:UpdateSubSets() end
        end
    end

    function FrameEvents:Register(f) frames[f] = true end
    function FrameEvents:Unregister(f) frames[f] = nil end
    function FrameEvents:GetFrames() return pairs(frames) end

    FrameEvents:Load()
end


do
    local InventoryFrame = mod:NewClass("Frame")
    mod.Frame = InventoryFrame

    local BagsterSet = mod("Sets")
    local FrameEvents = mod("FrameEvents")

    local BASE_WIDTH = 384
    -- Right inset slightly tighter: last cell pitch already leaves spacing after the icon.
    local ITEM_FRAME_LEFT_INSET = 14
    local ITEM_FRAME_RIGHT_INSET = 12
    local ITEM_FRAME_WIDTH_OFFSET = -(ITEM_FRAME_LEFT_INSET + ITEM_FRAME_RIGHT_INSET)
    local BASE_HEIGHT = 512
    local ITEM_FRAME_HEIGHT_OFFSET = 417 - BASE_HEIGHT
    -- Bag column: 36px ring centered 33 from the right edge, so 52 leaves it 15px of air on both sides
    local BAG_COLUMN_RESERVE = 52
    -- Chrome takes 95px of height, so two item rows is the real floor; anything higher blocks trimming
    local MIN_HEIGHT = -ITEM_FRAME_HEIGHT_OFFSET + 78

    local lastID = 1
    function InventoryFrame:New(titleText, settings, isBank, key)
        local f = self:Bind(CreateInventoryFrame(format("DragonUI_BagsterFrame%d", lastID)))
        f:SetScript("OnShow", self.OnShow)
        f:SetScript("OnHide", self.OnHide)

        f.sets = settings
        f.isBank = isBank
        f.key = key
        f.titleText = titleText
        f.bagButtons = {}
        f.filter = { quality = 0 }

        f:SetWidth(settings.w or BASE_WIDTH)
        f:SetHeight(settings.h or BASE_HEIGHT)

        -- Override min resize to allow smaller heights than the NineSlice base
        f:SetMinResize(BASE_WIDTH, MIN_HEIGHT)

        f.title = _G[f:GetName() .. "Title"]
        f.sideFilter = mod.SideFilter:New(f, f:IsSideFilterOnLeft())
        f.bottomFilter = mod.BottomFilter:New(f)
        f.nameFilter = _G[f:GetName() .. "Search"]

        f.qualityFilter = mod.QualityFilter:New(f)
        f.qualityFilter:SetPoint("BOTTOM", 0, 9)

        f.itemFrame = mod.ItemFrame:New(f)
        f.itemFrame:SetPoint("TOPLEFT", ITEM_FRAME_LEFT_INSET, -65)

        -- Bottom band: bare money bottom-right, bare currency tokens bottom-left
        f.moneyFrame = mod.MoneyFrame:New(f)
        f.moneyFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 8)

        if not isBank then
            f.tokenBar = mod.TokenBar:New(f)
            f.tokenBar:SetSize(220, 19)
            f.tokenBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 8)
            f.tokenBar:Refresh()
        end

        f:UpdateBottomLayout()

        f:UpdateTitleText()
        f:UpdateBagToggleHighlight()
        f:UpdateBagFrame()
        f.sideFilter:UpdateFilters()
        f:LoadPosition()
        f:UpdateClampInsets()

        lastID = lastID + 1
        tinsert(UISpecialFrames, f:GetName())
        return f
    end

    function InventoryFrame:UpdateTitleText()
        self.title:SetFormattedText(self.titleText, self:GetPlayer())
    end

    function InventoryFrame:OnTitleEnter(title)
        GameTooltip:SetOwner(title, "ANCHOR_LEFT")
        local text = title:GetText()
        if text then
            GameTooltip:SetText(text, 1, 1, 1)
        end
        GameTooltip:AddLine(mod.L.MoveTip)
        GameTooltip:AddLine(mod.L.ResetPositionTip)
        GameTooltip:Show()
    end

    function InventoryFrame:OnBagToggleClick(toggle, button)
        if button == "LeftButton" then
            _G[toggle:GetName() .. "Icon"]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            self:ToggleBagFrame()
        else
            if self.isBank then
                mod:Toggle(BACKPACK_CONTAINER)
            else
                mod:Toggle(BANK_CONTAINER)
            end
        end
    end

    function InventoryFrame:OnBagToggleEnter(toggle)
        GameTooltip:SetOwner(toggle, "ANCHOR_LEFT")
        GameTooltip:SetText(mod.L.Bags, 1, 1, 1)
        GameTooltip:AddLine(mod.L.BagToggle)
        if self.isBank then
            GameTooltip:AddLine(mod.L.InventoryToggle)
        else
            GameTooltip:AddLine(mod.L.BankToggle)
        end
        GameTooltip:Show()
    end

    local ANIM_FADE = 0.15
    local ANIM_STAGGER = 0.05

    -- Hand-driven cascade: 3.3.5 Alpha animations misbehave with SetStartDelay
    function InventoryFrame:AnimateBags(opening)
        local n = #self.bagButtons
        if n == 0 then return end

        local driver = self._bagAnimDriver
        if not driver then
            driver = CreateFrame("Frame", nil, self)
            self._bagAnimDriver = driver
        end
        driver.elapsed = 0
        driver.opening = opening
        driver.total = (n - 1) * ANIM_STAGGER + ANIM_FADE

        for _, bag in ipairs(self.bagButtons) do
            bag:SetAlpha(opening and 0 or 1)
        end

        local owner = self
        driver:SetScript("OnUpdate", function(d, elapsed)
            d.elapsed = d.elapsed + elapsed
            local count = #owner.bagButtons
            for i, bag in ipairs(owner.bagButtons) do
                local step = d.opening and (i - 1) or (count - i)
                local p = (d.elapsed - step * ANIM_STAGGER) / ANIM_FADE
                if p < 0 then p = 0 elseif p > 1 then p = 1 end
                bag:SetAlpha(d.opening and p or (1 - p))
            end
            if d.elapsed >= d.total then
                d:SetScript("OnUpdate", nil)
                if not d.opening and owner._bagsClosing then
                    owner._bagsClosing = nil
                    owner:UpdateBagFrame()
                end
            end
        end)
    end

    function InventoryFrame:ToggleBagFrame()
        self.sets.showBags = not self.sets.showBags
        self:UpdateBagToggleHighlight()
        if self.sets.showBags then
            -- Cancels a pending close so a quick re-open just rebuilds
            self._bagsClosing = nil
            self:UpdateBagFrame()
            self:AnimateBags(true)
        else
            if #self.bagButtons == 0 then
                self:UpdateBagFrame()
                return
            end
            self._bagsClosing = true
            self:AnimateBags(false)
        end
    end

    function InventoryFrame:UpdateBagFrame()
        for i, bag in pairs(self.bagButtons) do
            self.bagButtons[i] = nil
            bag:Release()
        end
        if self.sets.showBags then
            for _, bagID in ipairs(self.sets.bags) do
                local bag = mod.Bag:Get()
                bag:Set(self, bagID)
                tinsert(self.bagButtons, bag)
            end
            for i, bag in ipairs(self.bagButtons) do
                bag:ClearAllPoints()
                if i > 1 then
                    bag:SetPoint("TOP", self.bagButtons[i - 1], "BOTTOM", 0, -6)
                else
                    -- Anchored to the toggle itself so the column shares its exact X axis
                    bag:SetPoint("TOP", _G[self:GetName() .. "BagToggle"], "BOTTOM", 0, -10)
                end
                bag:Show()
                if bag.UpdateToggle then
                    bag:UpdateToggle()
                end
            end
        end
        self:UpdateItemFrameSize()
    end

    function InventoryFrame:UpdateBagToggleHighlight()
        if self.sets.showBags then
            _G[self:GetName() .. "BagToggle"]:LockHighlight()
        else
            _G[self:GetName() .. "BagToggle"]:UnlockHighlight()
        end
    end

    -- hiddenBags[bag] omits that bag from the item grid
    function InventoryFrame:IsShowingBag(bag)
        local hidden = self.sets.hiddenBags
        return not (hidden and hidden[bag])
    end

    function InventoryFrame:ToggleBagFilter(bag)
        self.sets.hiddenBags = self.sets.hiddenBags or {}
        if self.sets.hiddenBags[bag] then
            self.sets.hiddenBags[bag] = nil
            PlaySound("igMainMenuOptionCheckBoxOn")
        else
            self.sets.hiddenBags[bag] = true
            PlaySound("igMainMenuOptionCheckBoxOff")
        end
        if self.itemFrame then
            self.itemFrame:Regenerate()
            self.itemFrame:RequestLayout()
        end
        self:UpdateBagFilterToggles()
    end

    function InventoryFrame:UpdateBagFilterToggles()
        for _, bag in ipairs(self.bagButtons) do
            if bag.UpdateToggle then
                bag:UpdateToggle()
            end
        end
    end

    function InventoryFrame:SetFilter(key, value)
        if self.filter[key] ~= value then
            self.filter[key] = value
            self.itemFrame:Regenerate()
            return true
        end
    end

    function InventoryFrame:GetFilter(key)
        return self.filter[key]
    end

    -- Search dims non-matching slots instead of filtering them out, so the grid never reshuffles
    function InventoryFrame:SetSearch(text)
        self.itemFrame:SetSearch(text)
    end

    function InventoryFrame:SetPlayer(player)
        if self:GetPlayer() ~= player then
            self.player = player
            self:UpdateTitleText()
            self:UpdateBagFrame()
            self:UpdateSets()
            self.itemFrame:SetPlayer(player)
            self.moneyFrame:Update()
        end
    end

    function InventoryFrame:GetPlayer()
        return self.player or mod.playerName
    end

    function InventoryFrame:UpdateSets(category)
        self.sideFilter:UpdateFilters()
        self:SetCategory(category or self:GetCategory())
        self:UpdateSubSets()
    end

    function InventoryFrame:UpdateSubSets(subCategory)
        self.bottomFilter:UpdateFilters()
        self:SetSubCategory(subCategory or self:GetSubCategory())
    end

    function InventoryFrame:HasSet(name)
        for _, setName in self:GetSets() do
            if setName == name then return true end
        end
        return false
    end

    function InventoryFrame:HasSubSet(name, parent)
        if self:HasSet(parent) then
            local excludeSets = self:GetExcludedSubsets(parent)
            if excludeSets then
                for _, childSet in pairs(excludeSets) do
                    if childSet == name then return false end
                end
            end
            return true
        end
        return false
    end

    function InventoryFrame:GetSets()
        local profile = mod:GetProfile()
        return ipairs(profile[self.key].sets)
    end

    function InventoryFrame:GetExcludedSubsets(parent)
        local profile = mod:GetProfile()
        return profile[self.key].exclude[parent]
    end

    function InventoryFrame:SetCategory(name)
        if not (self:HasSet(name) and BagsterSet:Get(name)) then
            name = self:GetDefaultCategory()
        end
        local set = name and BagsterSet:Get(name)
        if self:SetFilter("rule", (set and set.rule) or nil) then
            self.category = name
            self.sideFilter:UpdateHighlight()
            self:UpdateSubSets()
        end
    end

    function InventoryFrame:GetCategory()
        return self.category or self:GetDefaultCategory()
    end

    function InventoryFrame:GetDefaultCategory()
        for _, set in BagsterSet:GetParentSets() do
            if self:HasSet(set.name) then return set.name end
        end
    end

    function InventoryFrame:SetSubCategory(name)
        local parent = self:GetCategory()
        if not (parent and self:HasSubSet(name, parent) and BagsterSet:Get(name, parent)) then
            name = self:GetDefaultSubCategory()
        end
        local set = name and BagsterSet:Get(name, parent)
        if self:SetFilter("subRule", (set and set.rule) or nil) then
            self.subCategory = name
            self.bottomFilter:UpdateHighlight()
        end
    end

    function InventoryFrame:GetSubCategory()
        return self.subCategory or self:GetDefaultSubCategory()
    end

    function InventoryFrame:GetDefaultSubCategory()
        local parent = self:GetCategory()
        if parent then
            for _, set in BagsterSet:GetChildSets(parent) do
                if self:HasSubSet(set.name, parent) then return set.name end
            end
        end
    end

    function InventoryFrame:AddQuality(quality)
        self:SetFilter("quality", self:GetFilter("quality") + quality)
        self.qualityFilter:UpdateHighlight()
    end

    function InventoryFrame:RemoveQuality(quality)
        self:SetFilter("quality", self:GetFilter("quality") - quality)
        self.qualityFilter:UpdateHighlight()
    end

    function InventoryFrame:SetQuality(quality)
        self:SetFilter("quality", quality)
        self.qualityFilter:UpdateHighlight()
    end

    function InventoryFrame:GetQuality()
        return self:GetFilter("quality") or 0
    end

    function InventoryFrame:OnSizeChanged()
        local w, h = self:GetWidth(), self:GetHeight()
        self.sets.w = w
        self.sets.h = h
        -- One-frame debounce while dragging the resize corner
        if not self._resizeDriver then
            self._resizeDriver = CreateFrame("Frame", nil, self)
        end
        self._resizeDriver:SetScript("OnUpdate", function(driver)
            driver:SetScript("OnUpdate", nil)
            self:UpdateItemFrameSize()
        end)
    end

    function InventoryFrame:UpdateItemFrameSize()
        if not self.itemFrame then return end
        local prevW, prevH = self.itemFrame:GetWidth(), self.itemFrame:GetHeight()
        local newW = self:GetWidth() + ITEM_FRAME_WIDTH_OFFSET
        if self.sets.showBags then
            newW = newW - BAG_COLUMN_RESERVE
        end
        local newH = self:GetHeight() + ITEM_FRAME_HEIGHT_OFFSET
        if not (prevW == newW and prevH == newH) then
            self.itemFrame:SetWidth(newW)
            self.itemFrame:SetHeight(newH)
            self.itemFrame:RequestLayout()
        end
    end

    -- Quality filter (off by default) sits bottom-center on the bottom band
    function InventoryFrame:UpdateBottomLayout()
        local cfg = mod.GetModuleConfig()
        if cfg and cfg.show_quality_filter then
            self.qualityFilter:Show()
        else
            self.qualityFilter:Hide()
        end
    end

    function InventoryFrame:UpdateClampInsets()
        local l, r, t, b
        local bottomBase = self.bottomFilter:IsShown() and 35 or 65
        t, b = -15, bottomBase
        if self.sideFilter:IsShown() then
            if self.sideFilter:Reversed() then
                l, r = -20, -35
            else
                l, r = 15, 0
            end
        else
            l, r = 15, -35
        end
        self:SetClampRectInsets(l, r, t, b)
    end

    function InventoryFrame:SavePosition(point, parent, relPoint, x, y)
        if point then
            self.sets.position = { point, nil, relPoint, x, y }
        else
            self.sets.position = nil
        end
        self:LoadPosition()
    end

    function InventoryFrame:LoadPosition()
        if self.sets.position then
            local point, _, relPoint, x, y = unpack(self.sets.position)
            self:ClearAllPoints()
            self:SetPoint(point, self:GetParent(), relPoint, x, y)
            self:SetUserPlaced(true)
        else
            -- No saved position: anchor at a visible default so the frame actually renders
            self:ClearAllPoints()
            if self.isBank then
                self:SetPoint("LEFT", UIParent, "LEFT", 24, 0)
            else
                self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -64, 64)
            end
            self:SetUserPlaced(nil)
        end
    end

    function InventoryFrame:OnShow()
        PlaySound("igBackPackOpen")
        FrameEvents:Register(self)
        -- Hiding mid-fade freezes the driver's OnUpdate, so finish the pending close here
        if self._bagsClosing then
            self._bagsClosing = nil
            self:UpdateBagFrame()
        end
        self:UpdateSets(self:GetDefaultCategory())
        if self.tokenBar then
            self.tokenBar:Refresh()
        end
        self:UpdateItemFrameSize()
        if not self.isBank and mod.ScheduleHighlightMainMenuBags then
            mod.ScheduleHighlightMainMenuBags()
        elseif not self.isBank and mod.HighlightMainMenuBags then
            mod.HighlightMainMenuBags()
        end
    end

    function InventoryFrame:OnHide()
        PlaySound("igBackPackClose")
        FrameEvents:Unregister(self)
        if self:IsBank() and self:AtBank() then
            CloseBankFrame()
        end
        self:SetPlayer(mod.playerName)
        if not self.isBank and mod.ScheduleHighlightMainMenuBags then
            mod.ScheduleHighlightMainMenuBags()
        elseif not self.isBank and mod.HighlightMainMenuBags then
            mod.HighlightMainMenuBags()
        end
    end

    function InventoryFrame:ToggleFrame(auto)
        if self:IsShown() then self:HideFrame(auto) else self:ShowFrame(auto) end
    end

    function InventoryFrame:ShowFrame(auto)
        if not self:IsShown() then
            ShowUIPanel(self)
            self.autoShown = auto or nil
        end
    end

    function InventoryFrame:HideFrame(auto)
        if self:IsShown() then
            if not auto or self.autoShown then
                HideUIPanel(self)
                self.autoShown = nil
            end
        end
    end

    function InventoryFrame:SetLeftSideFilter(enable)
        self.sets.leftSideFilter = enable and true or nil
        self.sideFilter:SetReversed(enable)
    end

    function InventoryFrame:IsSideFilterOnLeft()
        return self.sets.leftSideFilter
    end

    function InventoryFrame:IsBank()
        return self.isBank
    end

    function InventoryFrame:AtBank()
        return mod("PlayerInfo"):AtBank()
    end
end

local function BagsterSkinFrame(frame)
    if not frame or frame._BagSkin_Bagster then return end
    frame._BagSkin_Bagster = true

    mod.BagsterAddNineSlice(frame)

    -- Adjust NineSlice so it doesn't cover the header
    if frame._BagSkin_NineSlice then
        local ns = frame._BagSkin_NineSlice
        ns.Bg:SetPoint('TOPLEFT',     frame, 'TOPLEFT',     2, -18)
        ns.Bg:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -3, 3)
    end

    -- Tweak only the portrait's size/point: click button and hover glow follow it automatically
    local icon = _G[frame:GetName() .. 'IconButton']
    if icon then
        local origIcon = icon.icon
        local portrait = frame:CreateTexture(nil, 'BORDER')
        portrait:SetSize(56, 56)
        portrait:SetPoint('TOPLEFT', frame, 'TOPLEFT', -3, 6)
        icon.icon = portrait
        if origIcon then
            origIcon:Hide()
        end

        icon:ClearAllPoints()
        icon:SetPoint('TOPLEFT', portrait, 'TOPLEFT', 0, 0)
        icon:SetPoint('BOTTOMRIGHT', portrait, 'BOTTOMRIGHT', 0, 0)

        icon:EnableMouse(true)
        -- Glow art is 54px of a 61px region, centered -2.5px; scale/shift so it matches the portrait
        local hl = icon:GetHighlightTexture()
        if hl then
            local size = portrait:GetWidth() * 61 / 54
            local shift = 2.5 * size / 61
            hl:SetTexture(mod.CT.bagslot)
            hl:SetTexCoord(358 / 512, 419 / 512, 1 / 128, 62 / 128)
            hl:SetBlendMode('ADD')
            hl:ClearAllPoints()
            hl:SetSize(size, size)
            hl:SetPoint('CENTER', portrait, 'CENTER', shift, -shift)
        end
        -- Click zoom: texcoord crop + center-kept 6px shrink keeps the circle inside the ring
        local pSize = portrait:GetWidth()
        local pPoint, pRel, pRelPoint, pX, pY = portrait:GetPoint(1)
        icon:SetScript('OnMouseDown', function()
            portrait:SetSize(pSize - 6, pSize - 6)
            portrait:SetPoint(pPoint, pRel, pRelPoint, pX + 3, pY - 3)
            portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end)
        icon:SetScript('OnMouseUp', function()
            portrait:SetSize(pSize, pSize)
            portrait:SetPoint(pPoint, pRel, pRelPoint, pX, pY)
            portrait:SetTexCoord(0, 1, 0, 1)
        end)
        icon:SetScript('OnClick', function()
            ToggleCharacter('PaperDollFrame')
        end)
    end


    -- CloseButton: reposition
    local close = _G[frame:GetName() .. 'CloseButton']
    if close then
        close:ClearAllPoints()
        close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    end

    -- Title keeps the dynamic "<player>'s Inventory" text; just sit it on the header band
    local title = _G[frame:GetName() .. 'Title']
    if title then
        title:ClearAllPoints()
        title:SetPoint('TOP', frame, 'TOP', 0, -5)
    end

    local bagToggle = _G[frame:GetName() .. 'BagToggle']
    if bagToggle then
        bagToggle:ClearAllPoints()
        bagToggle:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -18, -30)
    end

    -- Portrait click opens CharacterFrame
    local portBtn = _G[frame:GetName() .. 'PortraitButton']
    if portBtn then
        portBtn:EnableMouse(true)
        portBtn:SetScript('OnClick', function()
            ToggleCharacter('PaperDollFrame')
        end)
    end
end

local function BagsterSkinItems(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:GetObjectType() == 'Frame' then
            for _, subchild in ipairs({ child:GetChildren() }) do
                if subchild:GetObjectType() == 'Button' and subchild:GetName() then
                    if subchild:GetName():find('DragonUI_BagsterItem') then
                        mod.BagsterRetailItemSlot(subchild)
                    end
                end
            end
        end
    end
end

-- Action-bar bag buttons (backpack, CharacterBag0-3) belong to micromenu — never skin them here.
-- Bag dropdown buttons style themselves in Bag:New (micromenu treatment).
local function BagsterApplySkin()
    for i = 1, 2 do
        local frame = _G['DragonUI_BagsterFrame' .. i]
        if frame then
            mod.BagsterSkinFrame(frame)
            mod.BagsterSkinItems(frame)
        end
    end
end

mod.BagsterSkinFrame = BagsterSkinFrame
mod.BagsterSkinItems = BagsterSkinItems
mod.BagsterApplySkin = BagsterApplySkin
mod.SetupIconButton = SetupIconButton
mod.SetupDragFrame = SetupDragFrame
mod.SetupSearchBox = SetupSearchBox
mod.SetupResetButton = SetupResetButton
