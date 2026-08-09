-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- ============================================================================
-- ITEM LEVEL MODULE FOR DRAGONUI
-- Draws the item level on item icons across every frame that shows items:
--   Bags, Bank, Guild Bank, Character, Inspect, Merchant, Trade,
--   Loot, Loot Roll, Mail, Auction House
--
-- Gear only: stackables do carry an ilvl in the DBC (Frostweave Cloth = 70)
-- but the client never displays it, so we mirror what the game considers
-- to have an item level.
-- ============================================================================

local ItemLevelModule = {
    initialized = false,
    applied = false,
    hooks = {},
    texts = {} -- Track every created FontString for cleanup
}

if addon.RegisterModule then
    addon:RegisterModule("itemlevel", ItemLevelModule,
        addon.L["Item Level"],
        addon.L["Show item level on gear icons in bags, character panel, bank, and more"],
        { lifecyclePrefix = "ItemLevel" })
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("itemlevel")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("itemlevel")
end

-- Every display context has its own checkbox; missing key defaults to on
local function IsContextEnabled(context)
    if not IsModuleEnabled() then return false end
    local config = GetModuleConfig()
    return (not config) or config[context] ~= false
end

-- ============================================================================
-- ITEM LEVEL LOOKUP
-- ============================================================================

-- equipSlot tokens that carry an ilvl but are not gear worth labelling
local NON_GEAR_SLOTS = {
    [""] = true,
    ["INVTYPE_NON_EQUIP"] = true,
    ["INVTYPE_BAG"] = true,
    ["INVTYPE_QUIVER"] = true,
    ["INVTYPE_AMMO"] = true,
    ["INVTYPE_BODY"] = true,   -- Shirt
    ["INVTYPE_TABARD"] = true,
}

-- [itemID] = ilvl*10 + quality, or false for "not gear, never ask again".
-- Packed into a number so browsing an auction house does not allocate a table per item.
local levelCache = {}

-- Average item level strings, keyed "player"/"inspect"
local averageTexts = {}

local UpdateAll -- forward declaration (retry scheduler runs before it is defined)

-- 3.3.5a has no GET_ITEM_INFO_RECEIVED, so uncached items need a timed retry
local retryScheduled = false
local retryBudget = 0

local function ScheduleRetry()
    if retryScheduled or retryBudget <= 0 then return end
    retryScheduled = true
    retryBudget = retryBudget - 1
    addon:After(0.5, function()
        retryScheduled = false
        if UpdateAll then UpdateAll() end
    end)
end

-- Called when a frame opens: items may arrive from the server over a second or two
local function RefillRetryBudget()
    retryBudget = 3
end

-- BAG_UPDATE, AUCTION_ITEM_LIST_UPDATE and friends arrive in bursts; without this
-- a single sell or mail sweep would trigger one full repaint per event.
local pendingUpdates = {}

local function Debounce(key, delay, callback)
    if pendingUpdates[key] then return end
    pendingUpdates[key] = true
    addon:After(delay, function()
        pendingUpdates[key] = nil
        callback()
    end)
end

-- Returns ilvl, quality, needsRetry
local function GetLevelInfo(link)
    if not link then return nil end

    local itemID = link:match("item:(%d+)")
    if itemID then
        local cached = levelCache[itemID]
        if cached == false then return nil end
        if cached then return math.floor(cached / 10), cached % 10 end
    end

    local _, _, quality, ilvl, _, _, _, _, equipSlot = GetItemInfo(link)
    if not ilvl then
        -- Not in the client's local item cache yet
        return nil, nil, true
    end

    if ilvl <= 0 or NON_GEAR_SLOTS[equipSlot or ""] then
        if itemID then levelCache[itemID] = false end
        return nil
    end

    if itemID then levelCache[itemID] = (ilvl * 10) + (quality or 1) end
    return ilvl, quality
end

local function WipeLevelCache()
    wipe(levelCache)
end

-- ============================================================================
-- TEXT OVERLAY
-- ============================================================================

-- Routed through addon.Fonts so CJK/Cyrillic clients get a font with glyphs
local function ResolveFontPath()
    local config = GetModuleConfig()
    local choice = (config and config.font_family) or "expressway"
    local fonts = addon.Fonts

    if choice == "expressway" then
        return fonts and fonts.ACTIONBAR
    elseif choice == "primary" then
        return fonts and fonts.PRIMARY
    elseif choice == "narrow" then
        return fonts and fonts.NARROW
    elseif choice == "skurri" then
        return (fonts and fonts.needsSystemFont) and fonts.PRIMARY or "Fonts\\SKURRI.TTF"
    elseif choice == "morpheus" then
        return (fonts and fonts.needsSystemFont) and fonts.PRIMARY or "Fonts\\MORPHEUS.TTF"
    end

    return nil -- "default": whatever NumberFontNormalSmall uses
end

-- 3.3.5a has no synthetic bold; a thicker outline is the only way to add weight
local VALID_OUTLINES = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

local function ApplyFont(fontString, sizeDelta)
    local config = GetModuleConfig()
    local size = ((config and config.font_size) or 12) + (sizeDelta or 0)
    local path = ResolveFontPath() or NumberFontNormalSmall:GetFont()
    local outline = VALID_OUTLINES[config and config.font_outline] or "THICKOUTLINE"

    fontString:SetFont(path, size, outline)
    -- A missing font file leaves the string unrendered, so verify and fall back
    if not fontString:GetFont() then
        fontString:SetFont(NumberFontNormalSmall:GetFont(), size, outline)
    end
end

local TEXT_POSITIONS = {
    BOTTOM = { "BOTTOM", "BOTTOM", 0, 2 },
    CENTER = { "CENTER", "CENTER", 0, 0 },
    TOP = { "TOP", "TOP", 0, -2 },
}

local function ResolveTextPosition()
    local config = GetModuleConfig()
    local pos = config and config.position
    if pos and TEXT_POSITIONS[pos] then return pos end
    return "BOTTOM"
end

local function ApplyTextPosition(fontString, anchor)
    local pos = ResolveTextPosition()
    local p = TEXT_POSITIONS[pos]
    if fontString.__DragonUI_ILvlPos == pos and fontString.__DragonUI_ILvlAnchor == anchor then
        return
    end
    fontString:ClearAllPoints()
    fontString:SetPoint(p[1], anchor, p[2], p[3], p[4])
    fontString.__DragonUI_ILvlPos = pos
    fontString.__DragonUI_ILvlAnchor = anchor
end

local function RefreshAllPositions()
    for button, fontString in pairs(ItemLevelModule.texts) do
        if fontString then
            ApplyTextPosition(fontString, fontString.__DragonUI_ILvlAnchor or button)
        end
    end
end

local function GetOrCreateText(button, anchorTo)
    local anchor = anchorTo or button
    local fontString = button.__DragonUI_ILvl
    if not fontString then
        fontString = button:CreateFontString(nil, "OVERLAY")
        fontString:SetDrawLayer("OVERLAY", 7)
        fontString:SetJustifyH("CENTER")
        ApplyFont(fontString)
        button.__DragonUI_ILvl = fontString
        ItemLevelModule.texts[button] = fontString
    end
    ApplyTextPosition(fontString, anchor)
    return fontString
end

-- anchorTo covers frames where the icon is not the whole button (loot, loot roll).
-- context is passed by external callers (Bagster) that cannot check it themselves.
local function HideButtonItemLevel(button)
    local fontString = button and button.__DragonUI_ILvl
    if fontString then fontString:Hide() end
end

-- Paints an already-resolved value; callers that read the number from somewhere
-- other than GetItemInfo (inspect tooltips) go through here.
local function DrawItemLevel(button, ilvl, r, g, b, anchorTo)
    if not ilvl then
        HideButtonItemLevel(button)
        return
    end

    local fontString = GetOrCreateText(button, anchorTo)
    fontString:SetText(ilvl)
    fontString:SetTextColor(r or 1, g or 1, b or 1)
    fontString:Show()
end

local function SetButtonItemLevel(button, link, anchorTo, context)
    if not button then return end

    if not IsModuleEnabled() or (context and not IsContextEnabled(context)) then
        HideButtonItemLevel(button)
        return
    end

    if not link then
        HideButtonItemLevel(button)
        return
    end

    local ilvl, quality, needsRetry = GetLevelInfo(link)
    if needsRetry then ScheduleRetry() end

    if not ilvl then
        HideButtonItemLevel(button)
        return
    end

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    if color then
        DrawItemLevel(button, ilvl, color.r, color.g, color.b, anchorTo)
    else
        DrawItemLevel(button, ilvl, 1, 1, 1, anchorTo)
    end
end

-- Bagster calls this directly for its own recycled slots
addon.UpdateItemLevelSlot = SetButtonItemLevel

local function HideAllTexts()
    for _, fontString in pairs(ItemLevelModule.texts) do
        if fontString then fontString:Hide() end
    end
end

local function RefreshAllFonts()
    for _, fontString in pairs(ItemLevelModule.texts) do
        if fontString then ApplyFont(fontString) end
    end
    for _, fontString in pairs(averageTexts) do
        if fontString then ApplyFont(fontString, 1) end
    end
end

-- ============================================================================
-- BAGS / BANK BAGS
-- ============================================================================

-- Bank bags (5-11) render as regular ContainerFrames but belong to the bank toggle
local function ContainerContext(bag)
    if bag and bag >= 5 and bag <= 11 then return "bank" end
    return "bags"
end

local function UpdateContainerFrame(frame)
    if not frame or not IsModuleEnabled() then return end

    local bag = frame:GetID()
    if not IsContextEnabled(ContainerContext(bag)) then return end

    local frameName = frame:GetName()
    local size = frame.size or GetContainerNumSlots(bag)
    for i = 1, size do
        local button = _G[frameName .. "Item" .. i]
        if button then
            -- Bag items render in reverse order, so the button's own ID is the real slot
            SetButtonItemLevel(button, GetContainerItemLink(bag, button:GetID()))
        end
    end
end

local function UpdateAllContainerFrames()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            UpdateContainerFrame(frame)
        end
    end
end

-- ============================================================================
-- BANK
-- ============================================================================

local NUM_BANKGENERIC_SLOTS = 28

local function UpdateBankSlots()
    if not IsContextEnabled("bank") then return end
    if not BankFrame or not BankFrame:IsShown() then return end

    for i = 1, NUM_BANKGENERIC_SLOTS do
        local button = _G["BankFrameItem" .. i]
        if button then
            SetButtonItemLevel(button, GetContainerItemLink(-1, button:GetID()))
        end
    end
end

-- ============================================================================
-- GUILD BANK
-- ============================================================================

local function UpdateGuildBankSlots()
    if not IsContextEnabled("guildbank") then return end
    if not IsAddOnLoaded("Blizzard_GuildBankUI") then return end
    if not GuildBankFrame or not GuildBankFrame:IsShown() then return end

    local tab = GetCurrentGuildBankTab()
    for i = 1, (MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
        -- 7 columns of 14 rows, filled column-first
        local index = math.fmod(i, 14)
        if index == 0 then index = 14 end
        local column = math.ceil((i - 0.5) / 14)

        local button = _G["GuildBankColumn" .. column .. "Button" .. index]
        if button then
            SetButtonItemLevel(button, GetGuildBankItemLink(tab, i))
        end
    end
end

-- ============================================================================
-- CHARACTER PANEL / INSPECT
-- ============================================================================

local EQUIP_SLOT_FRAMES = {
    "CharacterAmmoSlot", "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot",
    "CharacterShirtSlot", "CharacterChestSlot", "CharacterWaistSlot", "CharacterLegsSlot",
    "CharacterFeetSlot", "CharacterWristSlot", "CharacterHandsSlot", "CharacterFinger0Slot",
    "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot", "CharacterBackSlot",
    "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot", "CharacterTabardSlot",
}

local INSPECT_SLOT_FRAMES = {
    "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectShirtSlot",
    "InspectChestSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
    "InspectWristSlot", "InspectHandsSlot", "InspectFinger0Slot", "InspectFinger1Slot",
    "InspectTrinket0Slot", "InspectTrinket1Slot", "InspectBackSlot",
    "InspectMainHandSlot", "InspectSecondaryHandSlot", "InspectRangedSlot", "InspectTabardSlot",
}

-- Never labelled: ammo, cosmetic slots, and the bag bar's own equipment slots.
-- Needed by slot ID too, since the inspect path reads tooltips, not equipSlot.
local SKIPPED_SLOT_IDS = {
    [0] = true,  -- Ammo
    [4] = true,  -- Shirt
    [19] = true, -- Tabard
    [20] = true, [21] = true, [22] = true, [23] = true, -- Bag slots
}

-- Inventory slot IDs counted for the average: gear only (no ammo/shirt/tabard)
local AVERAGE_SLOT_IDS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function UpdateCharacterSlot(button)
    if not button or not IsContextEnabled("character") then return end

    local slotID = button:GetID()
    if not slotID or slotID < 0 then return end
    if SKIPPED_SLOT_IDS[slotID] then
        HideButtonItemLevel(button)
        return
    end

    SetButtonItemLevel(button, GetInventoryItemLink("player", slotID))
end

-- Plain-text prefix of the localized "Item Level %d" line. Matched literally
-- because a localized string may contain Lua pattern magic characters.
local ITEM_LEVEL_PREFIX = string.gsub(ITEM_LEVEL or "Item Level %d", "%%d.*", "")

local scanTip, scanTipName

-- Until the server answers NotifyInspect the tooltips still describe the previous
-- unit (or the transmog skin), so nothing is drawn rather than drawing a wrong number.
local inspectDataReady = false

-- Transmog servers (Warmane) publish the skin's item in the visible-item fields that
-- GetInventoryItemLink reads, but build the tooltip from the item really equipped —
-- so for inspect the tooltip is the only truthful source.
-- Returns ilvl, link, r, g, b
local function ScanInspectSlot(unit, slotID)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "DragonUIItemLevelScanTip", nil, "GameTooltipTemplate")
        scanTipName = scanTip:GetName()
    end

    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetInventoryItem(unit, slotID)

    local ilvl
    for i = 2, (scanTip:NumLines() or 0) do
        local line = _G[scanTipName .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text and string.find(text, ITEM_LEVEL_PREFIX, 1, true) then
            ilvl = tonumber(string.match(text, "(%d+)"))
            if ilvl then break end
        end
    end

    -- Line 1 carries the rarity color, available even when the link is not
    local r, g, b
    local nameLine = _G[scanTipName .. "TextLeft1"]
    if nameLine then r, g, b = nameLine:GetTextColor() end

    local _, link = scanTip:GetItem()
    scanTip:Hide()

    return ilvl, link, r, g, b
end

local function UpdateInspectSlot(button)
    if not button or not IsContextEnabled("inspect") then return end
    if not InspectFrame or not InspectFrame.unit then return end

    local slotID = button:GetID()
    if not slotID or slotID < 0 then return end
    if SKIPPED_SLOT_IDS[slotID] then
        HideButtonItemLevel(button)
        return
    end

    local unit = InspectFrame.unit
    if not inspectDataReady or not GetInventoryItemTexture(unit, slotID) then
        HideButtonItemLevel(button)
        return
    end

    local ilvl, link, r, g, b = ScanInspectSlot(unit, slotID)

    if ilvl then
        DrawItemLevel(button, ilvl, r, g, b)
        return
    end

    -- No item level line (showItemLevel off): fall back to the tooltip's own link
    SetButtonItemLevel(button, link or GetInventoryItemLink(unit, slotID))
end

local function CalculateAverage(unit, useTooltipScan)
    local total, count = 0, 0
    local incomplete = false

    for _, slotID in ipairs(AVERAGE_SLOT_IDS) do
        local ilvl
        if useTooltipScan then
            if GetInventoryItemTexture(unit, slotID) then
                local scanned, link = ScanInspectSlot(unit, slotID)
                ilvl = scanned or (link and GetLevelInfo(link)) or nil
                if not ilvl then incomplete = true end
            end
        else
            local link = GetInventoryItemLink(unit, slotID)
            if link then
                local resolved, _, needsRetry = GetLevelInfo(link)
                ilvl = resolved
                if needsRetry then incomplete = true end
            end
        end

        if ilvl then
            total = total + ilvl
            count = count + 1
        end
    end

    if count == 0 then return nil, incomplete end
    return math.floor((total / count) + 0.5), incomplete
end

-- Model frames draw the 3D model over their own regions, so the text needs its own
-- frame at a higher level; a FontString inside the model frame stays invisible.
-- Height above the model frame's bottom edge; the two panels need different clearance
local AVERAGE_Y_OFFSET = { player = 24, inspect = 0 }

local function GetOrCreateAverageText(key, parent, modelFrame)
    if averageTexts[key] then return averageTexts[key] end
    if not parent or not modelFrame then return nil end

    local y = AVERAGE_Y_OFFSET[key] or 0
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetFrameLevel(modelFrame:GetFrameLevel() + 5)
    holder:SetPoint("BOTTOMLEFT", modelFrame, "BOTTOMLEFT", 0, y)
    holder:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", 0, y)
    holder:SetHeight(20)

    local fontString = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontString:SetPoint("BOTTOM", holder, "BOTTOM", 0, 4)
    fontString:SetTextColor(1, 0.82, 0)
    ApplyFont(fontString, 1)
    averageTexts[key] = fontString
    return fontString
end

local function UpdateAverageFor(key, context, unit, parent, modelFrame, useTooltipScan)
    local existing = averageTexts[key]
    local config = GetModuleConfig()

    if not IsContextEnabled(context) or (config and config.show_average == false) then
        if existing then existing:Hide() end
        return
    end
    if not parent or not parent:IsShown() then
        if existing then existing:Hide() end
        return
    end

    local average, incomplete = CalculateAverage(unit, useTooltipScan)
    if incomplete then ScheduleRetry() end

    local fontString = existing or GetOrCreateAverageText(key, parent, modelFrame)
    if not fontString then return end

    if not average then
        fontString:Hide()
        return
    end

    fontString:SetFormattedText(addon.L["Item Level: %d"], average)
    fontString:Show()
end

local function HideAllAverages()
    for _, fontString in pairs(averageTexts) do
        if fontString then fontString:Hide() end
    end
end

-- The character panel shows the average as a stat row instead of floating it over the model, so
-- it suppresses this copy rather than having both on screen.
local suppressCharacterAverage = false

function addon.SetCharacterAverageSuppressed(value)
    suppressCharacterAverage = value and true or false
    if suppressCharacterAverage and averageTexts["player"] then
        averageTexts["player"]:Hide()
    end
end

-- Exposed so the character panel can reuse the number instead of rescanning the same 16 slots.
addon.GetAverageItemLevel = CalculateAverage

local function UpdateCharacterAverage()
    if suppressCharacterAverage then
        if averageTexts["player"] then averageTexts["player"]:Hide() end
        return
    end
    UpdateAverageFor("player", "character", "player", PaperDollFrame, CharacterModelFrame)
end

local function HideInspectTexts()
    for _, frameName in ipairs(INSPECT_SLOT_FRAMES) do
        local button = _G[frameName]
        if button then HideButtonItemLevel(button) end
    end
    if averageTexts["inspect"] then averageTexts["inspect"]:Hide() end
end

local function UpdateInspectAverage()
    if not InspectFrame or not InspectFrame.unit then return end
    if not inspectDataReady then
        if averageTexts["inspect"] then averageTexts["inspect"]:Hide() end
        return
    end
    UpdateAverageFor("inspect", "inspect", InspectFrame.unit, InspectPaperDollFrame, InspectModelFrame, true)
end

-- Slot hooks fire once per slot; without this the inspect average would rescan
-- every tooltip for every slot updated.
local function ScheduleAverageUpdate(which)
    Debounce("average:" .. which, 0.1, function()
        if which == "inspect" then
            UpdateInspectAverage()
        else
            UpdateCharacterAverage()
        end
    end)
end

local function UpdateAllCharacterSlots()
    if not IsContextEnabled("character") then return end
    for _, frameName in ipairs(EQUIP_SLOT_FRAMES) do
        local button = _G[frameName]
        if button then UpdateCharacterSlot(button) end
    end
    UpdateCharacterAverage()
end

local function UpdateAllInspectSlots()
    if not IsContextEnabled("inspect") then return end
    if not InspectFrame or not InspectFrame:IsShown() then return end
    for _, frameName in ipairs(INSPECT_SLOT_FRAMES) do
        local button = _G[frameName]
        if button then UpdateInspectSlot(button) end
    end
    UpdateInspectAverage()
end

-- ============================================================================
-- MERCHANT
-- ============================================================================

local function UpdateMerchantItems()
    if not IsContextEnabled("merchant") then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            SetButtonItemLevel(button, GetMerchantItemLink(((page - 1) * perPage) + i))
        end
    end

    local buyback = _G["MerchantBuyBackItemItemButton"]
    if buyback then
        SetButtonItemLevel(buyback, GetBuybackItemLink(GetNumBuybackItems()))
    end
end

local function UpdateBuybackItems()
    if not IsContextEnabled("merchant") then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    for i = 1, (BUYBACK_ITEMS_PER_PAGE or 12) do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            SetButtonItemLevel(button, GetBuybackItemLink(i))
        end
    end
end

local function UpdateMerchantActiveTab()
    if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 2 then
        UpdateBuybackItems()
    else
        UpdateMerchantItems()
    end
end

-- ============================================================================
-- TRADE
-- ============================================================================

local MAX_TRADE_ITEMS = 7

local function UpdateTradeItems()
    if not IsContextEnabled("trade") then return end
    if not TradeFrame or not TradeFrame:IsShown() then return end

    for i = 1, MAX_TRADE_ITEMS do
        local playerButton = _G["TradePlayerItem" .. i .. "ItemButton"]
        if playerButton then
            SetButtonItemLevel(playerButton, GetTradePlayerItemLink(i))
        end
        local targetButton = _G["TradeRecipientItem" .. i .. "ItemButton"]
        if targetButton then
            SetButtonItemLevel(targetButton, GetTradeTargetItemLink(i))
        end
    end
end

-- ============================================================================
-- LOOT / LOOT ROLL
-- ============================================================================

local function UpdateLootButton(index)
    if not IsContextEnabled("loot") then return end

    local button = _G["LootButton" .. index]
    if not button then return end

    -- Loot rows are wide name plates; the icon is only the left square
    local icon = _G["LootButton" .. index .. "IconTexture"]
    local link = button.slot and GetLootSlotLink(button.slot) or nil
    SetButtonItemLevel(button, button:IsShown() and link or nil, icon)
end

local function UpdateAllLootButtons()
    if not IsContextEnabled("loot") then return end
    if not LootFrame or not LootFrame:IsShown() then return end
    for i = 1, (LOOTFRAME_NUMBUTTONS or 4) do
        UpdateLootButton(i)
    end
end

local function UpdateLootRollFrame(frame)
    if not frame or not IsContextEnabled("lootroll") then return end

    local id = frame:GetID()
    local iconFrame = _G["GroupLootFrame" .. id .. "IconFrame"]
    if not iconFrame then return end

    SetButtonItemLevel(iconFrame, frame.rollID and GetLootRollItemLink(frame.rollID) or nil)
end

-- ============================================================================
-- MAIL
-- ============================================================================

local ATTACHMENTS_MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16
local ATTACHMENTS_MAX_SEND = ATTACHMENTS_MAX_SEND or 12

local function UpdateOpenMailAttachments()
    if not IsContextEnabled("mail") then return end
    if not OpenMailFrame or not OpenMailFrame:IsShown() then return end

    local mailID = InboxFrame and InboxFrame.openMailID
    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local button = _G["OpenMailAttachmentButton" .. i]
        if button then
            SetButtonItemLevel(button, mailID and GetInboxItemLink(mailID, i) or nil)
        end
    end
end

local function UpdateSendMailAttachments()
    if not IsContextEnabled("mail") then return end
    if not SendMailFrame or not SendMailFrame:IsShown() then return end

    for i = 1, ATTACHMENTS_MAX_SEND do
        local button = _G["SendMailAttachment" .. i]
        if button then
            SetButtonItemLevel(button, GetSendMailItemLink and GetSendMailItemLink(i) or nil)
        end
    end
end

-- ============================================================================
-- AUCTION HOUSE
-- ============================================================================

local AUCTION_LISTS = {
    { prefix = "Browse", list = "list", scroll = "BrowseScrollFrame", count = "NUM_BROWSE_TO_DISPLAY" },
    { prefix = "Bid", list = "bidder", scroll = "BidScrollFrame", count = "NUM_BIDS_TO_DISPLAY" },
    { prefix = "Auctions", list = "owner", scroll = "AuctionsScrollFrame", count = "NUM_AUCTIONS_TO_DISPLAY" },
}

local function UpdateAuctionList(entry)
    local scroll = _G[entry.scroll]
    if not scroll then return end

    local offset = FauxScrollFrame_GetOffset(scroll) or 0
    local numButtons = _G[entry.count] or 8
    for i = 1, numButtons do
        local button = _G[entry.prefix .. "Button" .. i .. "Item"]
        if button then
            local link = button:GetParent() and button:GetParent():IsShown()
                and GetAuctionItemLink(entry.list, offset + i) or nil
            SetButtonItemLevel(button, link)
        end
    end
end

local function UpdateAuctionItems()
    if not IsContextEnabled("auction") then return end
    if not IsAddOnLoaded("Blizzard_AuctionUI") then return end
    if not AuctionFrame or not AuctionFrame:IsShown() then return end

    for _, entry in ipairs(AUCTION_LISTS) do
        UpdateAuctionList(entry)
    end
end

-- ============================================================================
-- BAGSTER
-- ============================================================================

-- Bagster paints its own slots on Update(); this repaints them when an option changes
local function RefreshBagsterItemLevels()
    local mod = addon.BagsterModule
    if not mod then return end

    -- mod.frames = inventory/bank frames only (not RegisterModule.frames)
    local frames = mod.frames
    if frames then
        for i = 1, 2 do
            local items = frames[i] and frames[i].itemFrame and frames[i].itemFrame.items
            if items then
                for _, item in pairs(items) do
                    local context = (item.IsBank and item:IsBank()) and "bank" or "bags"
                    SetButtonItemLevel(item, item.GetItem and item:GetItem() or nil, nil, context)
                end
            end
        end
    end

    local guildItems = mod.guildFrame and mod.guildFrame.itemFrame and mod.guildFrame.itemFrame.items
    if guildItems then
        for _, item in pairs(guildItems) do
            SetButtonItemLevel(item, item.GetItem and item:GetItem() or nil, nil, "guildbank")
        end
    end
end

-- ============================================================================
-- REFRESH ALL
-- ============================================================================

function UpdateAll()
    if not IsModuleEnabled() then return end
    RefreshBagsterItemLevels()
    UpdateAllContainerFrames()
    UpdateBankSlots()
    UpdateGuildBankSlots()
    UpdateAllCharacterSlots()
    UpdateAllInspectSlots()
    UpdateMerchantActiveTab()
    UpdateTradeItems()
    UpdateAllLootButtons()
    UpdateOpenMailAttachments()
    UpdateSendMailAttachments()
    UpdateAuctionItems()
end

-- ============================================================================
-- TOOLTIP CVAR
-- ============================================================================

local function ApplyTooltipCVar()
    local config = GetModuleConfig()
    if config and config.tooltip_cvar and IsModuleEnabled() then
        SetCVar("showItemLevel", 1)
    end
end

-- ============================================================================
-- HOOK INSTALLATION
-- ============================================================================

local function InstallInspectHooks()
    if ItemLevelModule.hooks["Inspect"] then return end
    if not InspectPaperDollItemSlotButton_Update then return end

    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateInspectSlot(button)
        ScheduleAverageUpdate("inspect")
    end)

    -- Retargeting reuses the open frame: InspectFrame_UnitChanged calls this right
    -- after NotifyInspect, so the tooltips still hold the previous unit's gear.
    if InspectPaperDollFrame_OnShow then
        hooksecurefunc("InspectPaperDollFrame_OnShow", function()
            RefillRetryBudget()
            inspectDataReady = false
            HideInspectTexts()
            -- Safety net: draw anyway if INSPECT_TALENT_READY never arrives
            Debounce("inspectfallback", 1.5, function()
                if not inspectDataReady then
                    inspectDataReady = true
                    UpdateAllInspectSlots()
                end
            end)
        end)
    end

    ItemLevelModule.hooks["Inspect"] = true
end

local function InstallGuildBankHooks()
    if ItemLevelModule.hooks["GuildBank"] then return end
    if not GuildBankFrame_Update then return end

    hooksecurefunc("GuildBankFrame_Update", UpdateGuildBankSlots)
    ItemLevelModule.hooks["GuildBank"] = true
end

local function InstallAuctionHooks()
    if ItemLevelModule.hooks["Auction"] then return end
    if not AuctionFrameBrowse_Update then return end

    hooksecurefunc("AuctionFrameBrowse_Update", UpdateAuctionItems)
    if AuctionFrameBid_Update then
        hooksecurefunc("AuctionFrameBid_Update", UpdateAuctionItems)
    end
    if AuctionFrameAuctions_Update then
        hooksecurefunc("AuctionFrameAuctions_Update", UpdateAuctionItems)
    end
    ItemLevelModule.hooks["Auction"] = true
end

local function ApplyItemLevelSystem()
    if ItemLevelModule.applied then return end

    if not ItemLevelModule.hooks["ContainerFrame"] and ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", UpdateContainerFrame)
        ItemLevelModule.hooks["ContainerFrame"] = true
    end

    if not ItemLevelModule.hooks["BankFrame"] and BankFrameItemButton_Update then
        hooksecurefunc("BankFrameItemButton_Update", function(button)
            if not IsContextEnabled("bank") then return end
            if not BankFrame or not BankFrame:IsShown() or button.isBag then return end
            SetButtonItemLevel(button, GetContainerItemLink(-1, button:GetID()))
        end)
        ItemLevelModule.hooks["BankFrame"] = true
    end

    if not ItemLevelModule.hooks["PaperDoll"] and PaperDollItemSlotButton_Update then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            UpdateCharacterSlot(button)
            ScheduleAverageUpdate("player")
        end)
        ItemLevelModule.hooks["PaperDoll"] = true
    end

    -- Safety net: the average has no slot update of its own to ride on
    if not ItemLevelModule.hooks["PaperDollShow"] and PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            addon:After(0.05, UpdateAllCharacterSlots)
        end)
        ItemLevelModule.hooks["PaperDollShow"] = true
    end

    if not ItemLevelModule.hooks["Merchant"] and MerchantFrame_UpdateMerchantInfo then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", UpdateMerchantItems)
        ItemLevelModule.hooks["Merchant"] = true
    end

    if not ItemLevelModule.hooks["MerchantBuyback"] and MerchantFrame_UpdateBuybackInfo then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", UpdateBuybackItems)
        ItemLevelModule.hooks["MerchantBuyback"] = true
    end

    if not ItemLevelModule.hooks["Trade"] and TradeFrame_UpdatePlayerItem then
        hooksecurefunc("TradeFrame_UpdatePlayerItem", function(id)
            if not IsContextEnabled("trade") then return end
            local button = _G["TradePlayerItem" .. id .. "ItemButton"]
            if button then SetButtonItemLevel(button, GetTradePlayerItemLink(id)) end
        end)
        hooksecurefunc("TradeFrame_UpdateTargetItem", function(id)
            if not IsContextEnabled("trade") then return end
            local button = _G["TradeRecipientItem" .. id .. "ItemButton"]
            if button then SetButtonItemLevel(button, GetTradeTargetItemLink(id)) end
        end)
        ItemLevelModule.hooks["Trade"] = true
    end

    if not ItemLevelModule.hooks["Loot"] and LootFrame_UpdateButton then
        hooksecurefunc("LootFrame_UpdateButton", UpdateLootButton)
        ItemLevelModule.hooks["Loot"] = true
    end

    if not ItemLevelModule.hooks["LootRoll"] and GroupLootFrame_OnShow then
        hooksecurefunc("GroupLootFrame_OnShow", UpdateLootRollFrame)
        ItemLevelModule.hooks["LootRoll"] = true
    end

    if not ItemLevelModule.hooks["OpenMail"] and OpenMail_Update then
        hooksecurefunc("OpenMail_Update", UpdateOpenMailAttachments)
        ItemLevelModule.hooks["OpenMail"] = true
    end

    if not ItemLevelModule.hooks["SendMail"] and SendMailFrame_Update then
        hooksecurefunc("SendMailFrame_Update", UpdateSendMailAttachments)
        ItemLevelModule.hooks["SendMail"] = true
    end

    -- Load-on-demand UIs: installed here if already loaded, else on ADDON_LOADED
    InstallInspectHooks()
    InstallGuildBankHooks()
    InstallAuctionHooks()

    ApplyTooltipCVar()

    RefillRetryBudget()
    addon:After(0.5, UpdateAll)

    ItemLevelModule.applied = true
    ItemLevelModule.initialized = true
end

local function RestoreItemLevelSystem()
    if not ItemLevelModule.applied then return end

    HideAllTexts()
    HideAllAverages()

    ItemLevelModule.applied = false
end

addon.ApplyItemLevelSystem = ApplyItemLevelSystem
addon.RestoreItemLevelSystem = RestoreItemLevelSystem

-- Options panel entry points
function addon:RefreshItemLevel()
    if IsModuleEnabled() then
        -- Clear everything first: a context just turned off has no update path left to hide it
        HideAllTexts()
        HideAllAverages()
        RefillRetryBudget()
        UpdateAll()
    else
        RestoreItemLevelSystem()
    end
end

function addon:RefreshItemLevelFont()
    RefreshAllFonts()
    self:RefreshItemLevel()
end

function addon:RefreshItemLevelPosition()
    RefreshAllPositions()
end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    WipeLevelCache()
    if IsModuleEnabled() then
        RestoreItemLevelSystem()
        ItemLevelModule.applied = false
        ApplyItemLevelSystem()
        RefreshAllFonts()
        RefreshAllPositions()
    else
        if addon:ShouldDeferModuleDisable("itemlevel", ItemLevelModule) then
            return
        end
        RestoreItemLevelSystem()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
eventFrame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_SLOT_CLEARED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventFrame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
eventFrame:RegisterEvent("INSPECT_TALENT_READY")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "DragonUI" then
            addon:After(0.5, function()
                if addon.db and addon.db.RegisterCallback then
                    addon.db.RegisterCallback(ItemLevelModule, "OnProfileChanged", OnProfileChanged)
                    addon.db.RegisterCallback(ItemLevelModule, "OnProfileCopied", OnProfileChanged)
                    addon.db.RegisterCallback(ItemLevelModule, "OnProfileReset", OnProfileChanged)
                end
            end)
        elseif not IsModuleEnabled() then
            return
        elseif arg1 == "Blizzard_InspectUI" then
            InstallInspectHooks()
        elseif arg1 == "Blizzard_GuildBankUI" then
            InstallGuildBankHooks()
        elseif arg1 == "Blizzard_AuctionUI" then
            InstallAuctionHooks()
        end
        return
    end

    if not IsModuleEnabled() then return end

    if event == "PLAYER_ENTERING_WORLD" then
        addon:After(1.0, ApplyItemLevelSystem)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        Debounce("character", 0.2, UpdateAllCharacterSlots)

    elseif event == "BAG_UPDATE" then
        Debounce("bags", 0.2, UpdateAllContainerFrames)

    elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED"
        or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        RefillRetryBudget()
        Debounce("bank", 0.2, UpdateBankSlots)

    elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
        RefillRetryBudget()
        InstallGuildBankHooks()
        Debounce("guildbank", 0.2, UpdateGuildBankSlots)

    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        RefillRetryBudget()
        Debounce("merchant", 0.2, UpdateMerchantActiveTab)

    elseif event == "TRADE_SHOW" or event == "TRADE_PLAYER_ITEM_CHANGED"
        or event == "TRADE_TARGET_ITEM_CHANGED" then
        Debounce("trade", 0.1, UpdateTradeItems)

    elseif event == "LOOT_OPENED" or event == "LOOT_SLOT_CLEARED" then
        RefillRetryBudget()
        Debounce("loot", 0.1, UpdateAllLootButtons)

    elseif event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
        RefillRetryBudget()
        Debounce("mail", 0.2, UpdateOpenMailAttachments)

    elseif event == "MAIL_SEND_INFO_UPDATE" then
        Debounce("sendmail", 0.1, UpdateSendMailAttachments)

    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_ITEM_LIST_UPDATE" then
        RefillRetryBudget()
        InstallAuctionHooks()
        Debounce("auction", 0.2, UpdateAuctionItems)

    elseif event == "INSPECT_TALENT_READY" then
        -- 3.3.5a has no INSPECT_READY; this is the only "inspect data arrived" signal
        RefillRetryBudget()
        InstallInspectHooks()
        inspectDataReady = true
        Debounce("inspect", 0.1, UpdateAllInspectSlots)

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if InspectFrame and InspectFrame:IsShown() and InspectFrame.unit and arg1 == InspectFrame.unit then
            Debounce("inspect", 0.2, UpdateAllInspectSlots)
        end
    end
end)
