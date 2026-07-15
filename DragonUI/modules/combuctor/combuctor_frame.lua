-- FrameEvents relay, InventoryFrame class, template helpers and frame skinning.
local addon = select(2, ...)
local mod = addon.CombuctorModule

local format = string.format
local tinsert = table.insert

-- ============================================================================
-- TEMPLATE HELPERS (moved from core: used by InventoryFrame)
-- ============================================================================


-- DragonUI_CombuctorIconButtonTemplate (portrait)
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

    btn:SetScript("OnEvent", function(self, event, ...)
        if self:IsShown() and arg1 == "player" then
            SetPortraitTexture(self.icon, arg1)
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

-- DragonUI_CombuctorDragFrameTemplate (title/drag bar)
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

-- DragonUI_CombuctorSearchBoxTemplate
local function SetupSearchBox(eb, parentFrame)
    eb:SetAutoFocus(false)
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT",  parentFrame, "TOPLEFT",  84, -44)
    eb:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -116, -44)

    eb:SetScript("OnShow", function(self)
        if self:GetText() == '' then
            self:SetText(SEARCH)
        end
    end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(SEARCH)
        self:ClearFocus()
        self:GetParent():SetFilter('name', nil, true)
    end)
    eb:SetScript("OnTextChanged", function(self)
        if self:HasFocus() then
            local text = self:GetText()
            self:GetParent():SetFilter('name', (text ~= '' and text:lower()) or nil, true)
        end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self:GetText() == '' then
            self:SetText(SEARCH)
        end
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        if self:GetText() == SEARCH then
            self:SetText('')
        end
    end)
end

-- DragonUI_CombuctorResetButtonTemplate
local function SetupResetButton(btn)
    btn:SetSize(20, 20)
    local icon = "Interface\\Icons\\INV_Pet_Broom"
    local nt = btn:CreateTexture(nil, "ARTWORK")
    nt:SetTexture(icon)
    nt:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    nt:SetAllPoints(btn)
    btn:SetNormalTexture(nt)
    local pt = btn:CreateTexture(nil, "OVERLAY")
    pt:SetTexture(icon)
    pt:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    pt:SetAllPoints(btn)
    pt:Hide()
    btn:SetPushedTexture(pt)
    local ht = btn:CreateTexture(nil, "HIGHLIGHT")
    ht:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    ht:SetBlendMode("ADD")
    ht:SetAllPoints(btn)
    btn:SetHighlightTexture(ht)
end

-- DragonUI_CombuctorBagToggleTemplate
local function SetupBagToggle(btn, parentFrame)
    btn:SetSize(32, 32)

    -- $parentIcon: Button-Backpack-Up
    local icon = btn:CreateTexture(btn:GetName() .. "Icon", "BACKGROUND")
    icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
    icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)

    -- $parentBorder: MiniMap-TrackingBorder
    local border = btn:CreateTexture(btn:GetName() .. "Border", "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT")
    border:SetDesaturated(true)
    border:SetAlpha(0.6)

    btn:RegisterForClicks("anyUp")

    btn:SetScript("OnClick", function(self, button)
        self:GetParent():OnBagToggleClick(self, button)
    end)
    btn:SetScript("OnMouseDown", function(self)
        icon:SetTexCoord(0, 1, 0, 1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
    end)
    btn:SetScript("OnEnter", function(self)
        self:GetParent():OnBagToggleEnter(self)
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- HighlightTexture
    local ht = btn:CreateTexture(nil, "HIGHLIGHT")
    ht:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    ht:SetBlendMode("ADD")
    btn:SetHighlightTexture(ht)
end

-- Replaces DragonUI_CombuctorInventoryTemplate entirely
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
        searchEb:SetText(SEARCH)
        searchEb:ClearFocus()
        f:SetFilter('name', nil, true)
    end)

    -- bagToggle (32x32) anchored top-right
    bagToggleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -38)

    -- ClearAllPoints required: SetPoint alone adds a second anchor that fights the first
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("TOPRIGHT", bagToggleBtn, "TOPLEFT", 3, -11)

    -- searchBox (20px tall): TOPRIGHT Y=0 keeps it horizontal with resetBtn
    searchEb:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -44)
    searchEb:SetPoint("TOPRIGHT", resetBtn, "TOPLEFT", -4, 0)

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
        CSet:RegisterMessage(self, "COMBUCTOR_SET_ADD", "UpdateSets")
        CSet:RegisterMessage(self, "COMBUCTOR_SET_UPDATE", "UpdateSets")
        CSet:RegisterMessage(self, "COMBUCTOR_SET_REMOVE", "UpdateSets")
        CSet:RegisterMessage(self, "COMBUCTOR_CONFIG_SET_ADD", "UpdateSetConfig")
        CSet:RegisterMessage(self, "COMBUCTOR_CONFIG_SET_REMOVE", "UpdateSetConfig")
        CSet:RegisterMessage(self, "COMBUCTOR_SUBSET_ADD", "UpdateSubSets")
        CSet:RegisterMessage(self, "COMBUCTOR_SUBSET_UPDATE", "UpdateSubSets")
        CSet:RegisterMessage(self, "COMBUCTOR_SUBSET_REMOVE", "UpdateSubSets")
        CSet:RegisterMessage(self, "COMBUCTOR_CONFIG_SUBSET_ADD", "UpdateSubSetConfig")
        CSet:RegisterMessage(self, "COMBUCTOR_CONFIG_SUBSET_REMOVE", "UpdateSubSetConfig")
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

    local CombuctorSet = mod("Sets")
    local FrameEvents = mod("FrameEvents")

    local BASE_WIDTH = 384
    local ITEM_FRAME_WIDTH_OFFSET = 354 - BASE_WIDTH
    local BASE_HEIGHT = 512
    local ITEM_FRAME_HEIGHT_OFFSET = 432 - BASE_HEIGHT

    local lastID = 1
    function InventoryFrame:New(titleText, settings, isBank, key)
        local f = self:Bind(CreateInventoryFrame(format("DragonUI_CombuctorFrame%d", lastID)))
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
        f:SetMinResize(BASE_WIDTH, 350)

        f.title = _G[f:GetName() .. "Title"]
        f.sideFilter = mod.SideFilter:New(f, f:IsSideFilterOnLeft())
        f.bottomFilter = mod.BottomFilter:New(f)
        f.nameFilter = _G[f:GetName() .. "Search"]

        f.qualityFilter = mod.QualityFilter:New(f)
        f.qualityFilter:SetPoint("BOTTOMLEFT", 14, 10)

        f.itemFrame = mod.ItemFrame:New(f)
        f.itemFrame:SetPoint("TOPLEFT", 14, -70)

        -- Token bar (honor/emblem tracking) — inventory only, at the very bottom
        if not isBank then
            f.tokenBar = mod.TokenBar:New(f)
            f.tokenBar:SetSize(180, 19)
            f.tokenBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -9, 10)
            f.tokenBar:Refresh()
        end

        -- Coinbox frame (pill background for money, shifted up when token bar exists)
        local coinY = not isBank and (10 + 19 + 3) or 10
        f.coinFrame = CreateFrame("Frame", nil, f)
        f.coinFrame:SetSize(180, 19)
        f.coinFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -9, coinY)

        local coinLeft = f.coinFrame:CreateTexture(nil, "BACKGROUND")
        coinLeft:SetSize(8, 19)
        coinLeft:SetPoint("LEFT", f.coinFrame, "LEFT")
        coinLeft:SetTexture(mod.CT.coinbox)
        coinLeft:SetTexCoord(0.03125, 0.53125, 0.289062, 0.554688)

        local coinRight = f.coinFrame:CreateTexture(nil, "BACKGROUND")
        coinRight:SetSize(8, 19)
        coinRight:SetPoint("RIGHT", f.coinFrame, "RIGHT")
        coinRight:SetTexture(mod.CT.coinbox)
        coinRight:SetTexCoord(0.03125, 0.53125, 0.570312, 0.835938)

        local coinMiddle = f.coinFrame:CreateTexture(nil, "BACKGROUND")
        coinMiddle:SetPoint("TOPLEFT", coinLeft, "TOPRIGHT")
        coinMiddle:SetPoint("BOTTOMRIGHT", coinRight, "BOTTOMLEFT")
        coinMiddle:SetTexture(mod.CT.coinbox)
        coinMiddle:SetTexCoord(0, 0.5, 0.0078125, 0.273438)

        f.moneyFrame = mod.MoneyFrame:New(f)
        f.moneyFrame:SetPoint("BOTTOMRIGHT", -12, coinY)

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
            _G[toggle:GetName() .. "Icon"]:SetTexCoord(0.075, 0.925, 0.075, 0.925)
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

    function InventoryFrame:ToggleBagFrame()
        self.sets.showBags = not self.sets.showBags
        self:UpdateBagToggleHighlight()
        self:UpdateBagFrame()
    end

    function InventoryFrame:UpdateBagFrame()
        for i, bag in pairs(self.bagButtons) do
            self.bagButtons[i] = nil
            bag:Release()
        end
        if self.sets.showBags then
            for _, bagID in ipairs(self.sets.bags) do
                if bagID ~= KEYRING_CONTAINER then
                    local bag = mod.Bag:Get()
                    bag:Set(self, bagID)
                    tinsert(self.bagButtons, bag)
                end
            end
            for i, bag in ipairs(self.bagButtons) do
                bag:ClearAllPoints()
                if i > 1 then
                    bag:SetPoint("TOP", self.bagButtons[i - 1], "BOTTOM", 0, -6)
                else
                    bag:SetPoint("TOPRIGHT", -14, -70)
                end
                bag:Show()
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
        if not (self:HasSet(name) and CombuctorSet:Get(name)) then
            name = self:GetDefaultCategory()
        end
        local set = name and CombuctorSet:Get(name)
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
        for _, set in CombuctorSet:GetParentSets() do
            if self:HasSet(set.name) then return set.name end
        end
    end

    function InventoryFrame:SetSubCategory(name)
        local parent = self:GetCategory()
        if not (parent and self:HasSubSet(name, parent) and CombuctorSet:Get(name, parent)) then
            name = self:GetDefaultSubCategory()
        end
        local set = name and CombuctorSet:Get(name, parent)
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
            for _, set in CombuctorSet:GetChildSets(parent) do
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
        self:UpdateItemFrameSize()
    end

    function InventoryFrame:UpdateItemFrameSize()
        if not self.itemFrame then return end
        local prevW, prevH = self.itemFrame:GetWidth(), self.itemFrame:GetHeight()
        local newW = self:GetWidth() + ITEM_FRAME_WIDTH_OFFSET
        if next(self.bagButtons) then
            newW = newW - 36
        end
        local newH = self:GetHeight() + ITEM_FRAME_HEIGHT_OFFSET
        -- Reserve bottom space for token bar (19px) + gap (3px) when visible
        local tokenBarVisible = not self.isBank and self.tokenBar and self.tokenBar:IsShown()
        if tokenBarVisible then
            newH = newH - 25
        end
        if not (prevW == newW and prevH == newH) then
            self.itemFrame:SetWidth(newW)
            self.itemFrame:SetHeight(newH)
            self.itemFrame:RequestLayout()
        end

        -- Reposition coin/money frame based on token bar visibility
        if not self.isBank and self.coinFrame then
            local coinY = tokenBarVisible and (10 + 19 + 3) or 10
            self.coinFrame:ClearAllPoints()
            self.coinFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -9, coinY)
            if self.moneyFrame then
                self.moneyFrame:ClearAllPoints()
                self.moneyFrame:SetPoint("BOTTOMRIGHT", -12, coinY)
            end
        end
    end

    function InventoryFrame:UpdateClampInsets()
        local l, r, t, b
        -- Base bottom: room for coinFrame (19px at y=10) + padding
        local bottomBase = self.bottomFilter:IsShown() and 35 or 65
        -- Reserve extra space for token bar when visible
        if not self.isBank and self.tokenBar and self.tokenBar:IsShown() then
            bottomBase = bottomBase + 25
        end
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
        self:UpdateSets(self:GetDefaultCategory())
        if self.tokenBar then
            self.tokenBar:Refresh()
        end
        -- Ensure coin/money frame is positioned correctly for current token bar state
        self:UpdateItemFrameSize()
    end

    function InventoryFrame:OnHide()
        PlaySound("igBackPackClose")
        FrameEvents:Unregister(self)
        if self:IsBank() and self:AtBank() then
            CloseBankFrame()
        end
        self:SetPlayer(mod.playerName)
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

local function CombuctorSkinFrame(frame)
    if not frame or frame._BagSkin_Combuctor then return end
    frame._BagSkin_Combuctor = true

    mod.CombuctorAddNineSlice(frame)

    -- Adjust NineSlice so it doesn't cover the header
    if frame._BagSkin_NineSlice then
        local ns = frame._BagSkin_NineSlice
        ns.Bg:SetPoint('TOPLEFT',     frame, 'TOPLEFT',     3, -18)
        ns.Bg:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -3, 3)
    end

    -- Icon/Portrait — shrink, move above nineslice background
    local icon = _G[frame:GetName() .. 'IconButton']
    if icon then
        icon:SetSize(36, 36)
        icon:ClearAllPoints()
        icon:SetPoint('TOPLEFT', frame, 'TOPLEFT', -4, 4)
        local origIcon = icon.icon
        local portrait = icon:CreateTexture(nil, 'ARTWORK')
        portrait:SetSize(36, 36)
        portrait:SetPoint('CENTER', icon)
        icon.icon = portrait
        if origIcon then
            origIcon:Hide()
        end

        icon:EnableMouse(true)
        -- Kill old SetupIconButton resize handlers that blow icon to 56-62px
        icon:SetScript('OnMouseDown', nil)
        icon:SetScript('OnMouseUp', nil)
        icon:SetScript('OnClick', function()
            ToggleCharacter('PaperDollFrame')
        end)
    end

    -- Bag border frame on top of icon
    if icon and not frame._BagSkin_PortraitBorder then
        local borderFrame = CreateFrame('Frame', nil, frame)
        borderFrame:SetSize(48, 48)
        borderFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', -10, 8)

        local iconLevel = 0
        if icon.GetFrameLevel then
            iconLevel = icon:GetFrameLevel()
        elseif frame.GetFrameLevel then
            iconLevel = frame:GetFrameLevel()
        end
        borderFrame:SetFrameLevel(iconLevel + 10)

        local pp = borderFrame:CreateTexture(nil, 'OVERLAY')
        pp:SetTexture(mod.CT.bag_border)
        pp:SetAllPoints(borderFrame)
        pp:SetDrawLayer('OVERLAY', 7)

        frame._BagSkin_PortraitBorder = borderFrame
    end

    -- CloseButton: reposition
    local close = _G[frame:GetName() .. 'CloseButton']
    if close then
        close:ClearAllPoints()
        close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    end

    -- Title: centered "Combuctor" label on the header border
    local title = _G[frame:GetName() .. 'Title']
    if title then
        title:SetText('Combuctor')
        title:ClearAllPoints()
        title:SetPoint('TOP', frame, 'TOP', 0, -5)
    end

    -- Bag toggle — reposition
    local bagToggle = _G[frame:GetName() .. 'BagToggle']
    if bagToggle then
        bagToggle:ClearAllPoints()
        bagToggle:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -14, -38)
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

local function CombuctorSkinItems(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:GetObjectType() == 'Frame' then
            for _, subchild in ipairs({ child:GetChildren() }) do
                if subchild:GetObjectType() == 'Button' and subchild:GetName() then
                    if subchild:GetName():find('DragonUI_CombuctorItem') then
                        mod.CombuctorRetailItemSlot(subchild)
                    end
                end
            end
        end
    end
end

local function CombuctorSkinBagSlots(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:GetObjectType() == 'Frame' then
            for _, subchild in ipairs({ child:GetChildren() }) do
                if subchild:GetObjectType() == 'Button' and subchild:GetName() then
                    local name = subchild:GetName()
                    if name:find('DragonUI_CombuctorBag') then
                        mod.CombuctorRetailBagSlot(subchild)
                    end
                end
            end
        end
    end
end

-- Action-bar bag buttons (backpack, CharacterBag0-3) belong to micromenu — never skin them here.
local function CombuctorApplySkin()
    for i = 1, 2 do
        local frame = _G['DragonUI_CombuctorFrame' .. i]
        if frame then
            mod.CombuctorSkinFrame(frame)
            mod.CombuctorSkinItems(frame)
            mod.CombuctorSkinBagSlots(frame)
        end
    end
end

mod.CombuctorSkinFrame = CombuctorSkinFrame
mod.CombuctorSkinItems = CombuctorSkinItems
mod.CombuctorSkinBagSlots = CombuctorSkinBagSlots
mod.CombuctorApplySkin = CombuctorApplySkin
