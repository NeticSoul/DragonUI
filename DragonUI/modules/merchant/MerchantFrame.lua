-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Retail-style chrome on Blizzard's vendor window; FrameXML still owns buy, sell and repair.

local addon = select(2, ...)

local L = addon.L
local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local MARBLE = DIR .. "UI\\ui-background-marble"
local REDBUTTON = DIR .. "UI\\redbutton2x"
local LABEL_PLATE = DIR .. "Merchant\\labelslots"
local PAGE_BG = DIR .. "Merchant\\pagebutton-background"
local PAGE_HILITE = DIR .. "Merchant\\pagebutton-hover"
local QUICKSLOT_RING = DIR .. "UI\\ui-quickslot2"
local EMPTY_SLOT = DIR .. "Merchant\\emptyslot"
local TAB_TEX = DIR .. "UI\\uiframetabs"
local PAGE_BTN_TEX = {
    MerchantPrevPageButton = {
        up = DIR .. "Merchant\\pagebutton-prev-normal",
        down = DIR .. "Merchant\\pagebutton-prev-pressed",
        disabled = DIR .. "Merchant\\pagebutton-prev-disabled",
    },
    MerchantNextPageButton = {
        up = DIR .. "Merchant\\pagebutton-next-normal",
        down = DIR .. "Merchant\\pagebutton-next-pressed",
        disabled = DIR .. "Merchant\\pagebutton-next-disabled",
    },
}

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local MerchantModule = {
    initialized = false,
    applied = false,
    frames = {},
}

if addon.RegisterModule then
    addon:RegisterModule("merchant", MerchantModule,
        (L and L["Merchant"]) or "Merchant",
        (L and L["Retail-style vendor window chrome"]) or "Retail-style vendor window chrome",
        { lifecyclePrefix = "Merchant", loadOnce = true })
end

-- ============================================================================
-- CONFIG HELPERS
-- ============================================================================

local function IsModuleEnabled()
    return addon:IsModuleEnabled("merchant")
end

-- ============================================================================
-- INLINE HELPERS
-- ============================================================================

-- The link carries its own quality colour, so an uncached item still gets tinted.
local function TextColor(link)
    if not link then return nil end
    local quality = select(3, GetItemInfo(link))
    if quality then return ITEM_QUALITY_COLORS[quality] end
    local hex = link:match("^|c(%x%x%x%x%x%x%x%x)")
    if not hex then return nil end
    return {
        r = tonumber(hex:sub(3, 4), 16) / 255,
        g = tonumber(hex:sub(5, 6), 16) / 255,
        b = tonumber(hex:sub(7, 8), 16) / 255,
    }
end

local questScanTooltip
local questStarterCache = {}
local function ItemStartsQuestByLink(link)
    local itemID = link and tonumber(link:match("item:(%d+)"))
    if not itemID then return false end
    local cached = questStarterCache[itemID]
    if cached ~= nil then return cached end

    if not questScanTooltip then
        questScanTooltip = CreateFrame("GameTooltip", "DragonUI_MerchantQuestScan", nil, "GameTooltipTemplate")
        questScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    questScanTooltip:ClearLines()
    questScanTooltip:SetHyperlink(link)
    local lines = questScanTooltip:NumLines()
    local starts = false
    for i = 2, lines do
        local fs = _G["DragonUI_MerchantQuestScanTextLeft" .. i]
        if fs and fs:GetText() == ITEM_STARTS_QUEST then
            starts = true
            break
        end
    end
    -- A one-line tooltip means the item isn't cached yet; don't remember that as "no".
    if starts or lines > 1 then questStarterCache[itemID] = starts end
    return starts
end

-- ============================================================================
-- LOCAL HELPERS
-- ============================================================================

local function ForEachRegion(frame, kind, layer, fn)
    if not frame then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r:GetObjectType() == kind and (not layer or r:GetDrawLayer() == layer) then
            fn(r)
        end
    end
end

local function FindRegion(frame, kind, predicate)
    if not frame then return nil end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r:GetObjectType() == kind and predicate(r) then
            return r
        end
    end
    return nil
end

local function applyNineSlice(container, layoutName)
    if not (container and NineSliceUtils and NineSliceUtils.GetLayout) then return false end
    local layout = NineSliceUtils.GetLayout(layoutName)
    if not layout then return false end
    NineSliceUtils.ApplyLayout(container, layout)
    return true
end

local function attachInset(parent, tlx, tly, brx, bry)
    local inset = CreateFrame("Frame", nil, parent)
    inset:EnableMouse(false)
    inset:SetPoint("TOPLEFT", parent, "TOPLEFT", tlx, tly)
    inset:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", brx, bry)
    applyNineSlice(inset, "InsetFrameTemplate")
    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(MARBLE, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints(inset)
    return inset
end

local function applyPortraitCutout(tex, parent)
    if not tex or not parent or tex._duiCutout then return end
    tex:ClearAllPoints()
    -- The ring's 62 minus 3 a side: with no masks in 3.3.5a, a full-square face spills past the metal.
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", -2, 4)
    tex:SetSize(56, 56)
    tex:SetDrawLayer("ARTWORK")
    tex._duiCutout = true
end

local function ensureTitle(f, text)
    if not f then return nil end
    local fs = f.Title
    if not fs then
        fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.Title = fs
        fs:SetPoint("TOP", f, "TOP", 0, -5)
        fs:SetPoint("LEFT", f, "LEFT", 60, 0)
        fs:SetPoint("RIGHT", f, "RIGHT", -24, 0)
        fs:SetJustifyH("CENTER")
        fs:SetHeight(16)
    end
    if text then fs:SetText(text) end
    return fs
end

local function dressCloseButton(cb, owner)
    if not cb or cb._duiModernized then return end
    cb._duiModernized = true
    cb:SetSize(24, 24)
    cb:ClearAllPoints()
    cb:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 1, 0)
    local base = (owner.GetFrameLevel and owner:GetFrameLevel()) or 0
    cb:SetFrameLevel(base + 20)

    local function dress(getter, l, r, t, b, blend)
        local tex = cb[getter] and cb[getter](cb)
        if not tex then return end
        tex:SetTexture(REDBUTTON)
        tex:SetTexCoord(l, r, t, b)
        if blend then tex:SetBlendMode(blend) end
    end

    dress("GetNormalTexture", 39/256, 75/256, 1/128, 39/128)
    dress("GetPushedTexture", 39/256, 75/256, 81/128, 119/128)
    dress("GetDisabledTexture", 39/256, 75/256, 41/128, 79/128)
    dress("GetHighlightTexture", 115/256, 151/256, 1/128, 39/128, "ADD")
end

local updateMerchantTabHighlight

-- ============================================================================
-- LAYOUT CONSTANTS
-- ============================================================================

local ITEMS_PER_PAGE   = MERCHANT_ITEMS_PER_PAGE or 10
local BUYBACK_PER_PAGE = BUYBACK_ITEMS_PER_PAGE or 12
local PANEL_W, PANEL_H = 336, 444
local GRID_X, GRID_Y   = 11, -69
local PANEL_X_NUDGE    = 6
local INSET_TL_X, INSET_TL_Y = 4, -60
local INSET_BR_X, INSET_BR_Y = -6, 26
local ROW_GAP_MERCHANT, ROW_GAP_BUYBACK = -8, -15
local BAND_Y     = 26
local BAND_INSET = 1
local MONEY_X, MONEY_Y = -6, 10

-- ============================================================================
-- OUTER CHROME — classic art suppression + modern chrome
-- ============================================================================

local CLASSIC_PATHS = { "ui%-merchant%-top", "ui%-merchant%-bot", "ui%-buyback%-" }

-- The only classic pieces FrameXML re-Shows on its own (UpdateMerchantInfo / UpdateBuybackInfo).
local RESHOWN_CLASSIC = {
    "MerchantNameText", "MerchantRepairText", "MerchantFrameBottomLeftBorder", "MerchantFrameBottomRightBorder",
    "BuybackFrameTopLeft", "BuybackFrameTopRight", "BuybackFrameBotLeft", "BuybackFrameBotRight",
}

local function isClassicArt(r)
    local p = r:GetTexture()
    if type(p) ~= "string" then return false end
    p = p:lower()
    for _, pat in ipairs(CLASSIC_PATHS) do
        if p:find(pat) then return true end
    end
    return false
end

local function hideReshownClassic()
    for _, name in ipairs(RESHOWN_CLASSIC) do
        local t = _G[name]
        if t then t:Hide() end
    end
end

local function hideClassicChrome()
    local f = _G.MerchantFrame
    if not f then return end

    ForEachRegion(f, "Texture", nil, function(r)
        local layer = r:GetDrawLayer()
        if (layer == "BORDER" or layer == "ARTWORK") and r ~= f._duiStreaks and isClassicArt(r) then
            r:Hide()
        end
    end)

    local portrait = _G.MerchantFramePortrait
    ForEachRegion(f, "Texture", "BACKGROUND", function(r)
        if r ~= portrait then r:Hide() end
    end)

    hideReshownClassic()
end

-- ============================================================================
-- BODY FILL
-- ============================================================================

local function paintBody(f)
    local bg = f.Bg
    if not bg then
        bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
        f.Bg = bg
    end
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetTexCoord(0, 1, 0, 1)
    bg:SetVertexColor(1, 1, 1)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -21)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
    bg:Show()
end

local function applyStreaks(f)
    if f._duiStreaks then return end
    local streaks = f:CreateTexture(nil, "BORDER")
    streaks:set_atlas("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetHeight(43)
    streaks:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)
    f._duiStreaks = streaks
end

local function applyModernChrome()
    local f = _G.MerchantFrame
    if not f then return end
    if not f._duiNineSlice then
        applyNineSlice(f, "PortraitFrameTemplate")
        f._duiNineSlice = true
    end
    paintBody(f)
    applyStreaks(f)
end

-- ============================================================================
-- BOTTOM BAND
-- ============================================================================

local function buildBottomBand()
    local f = _G.MerchantFrame
    if not f or f._duiBotFrame then return end
    local band = CreateFrame("Frame", nil, f)
    band:SetHeight(61)
    band:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   BAND_INSET, BAND_Y)
    band:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -BAND_INSET, BAND_Y)
    local t = band:CreateTexture(nil, "ARTWORK")
    t:set_atlas("ui-merchant-botframe", false)
    t:SetAllPoints()
    band:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._duiBotFrame = band
end

-- ============================================================================
-- ROWS — slot reskin, quest bang, name clamping
-- ============================================================================

local function reskinSlot(prefix, showLabel)
    local slot = _G[prefix .. "SlotTexture"]
    if slot then slot:SetTexture(EMPTY_SLOT) end

    local ib = _G[prefix .. "ItemButton"]
    local nrm = ib and ib:GetNormalTexture()
    if nrm then
        nrm:SetTexture(QUICKSLOT_RING)
        nrm:ClearAllPoints()
        nrm:SetSize(64, 64)
        nrm:SetPoint("CENTER", ib, "CENTER", 0, -1)
    end

    local nameFrame = _G[prefix .. "NameFrame"]
    if nameFrame then
        if showLabel then
            nameFrame:SetTexture(LABEL_PLATE)
            nameFrame:SetVertexColor(0.5, 0.5, 0.5, 1)
            nameFrame:Show()
        else
            nameFrame:Hide()
        end
    end
end

local function reskinAllSlots()
    for i = 1, BUYBACK_PER_PAGE do
        if _G["MerchantItem" .. i] then reskinSlot("MerchantItem" .. i, true) end
    end
    if _G.MerchantBuyBackItem then reskinSlot("MerchantBuyBackItem", false) end
end

local QUEST_BANG_TEX = TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\QuestBang"
local function addQuestBang(prefix)
    local ib = _G[prefix .. "ItemButton"]
    if not ib or ib.IconQuestTexture then return end
    local t = ib:CreateTexture(nil, "OVERLAY")
    t:SetTexture(QUEST_BANG_TEX)
    t:SetSize(37, 38)
    t:SetPoint("TOP", ib, "TOP", 0, 0)
    t:Hide()
    ib.IconQuestTexture = t
end

local function addQuestBangs()
    for i = 1, BUYBACK_PER_PAGE do
        if _G["MerchantItem" .. i] then addQuestBang("MerchantItem" .. i) end
    end
end

local function clampName(nm, width)
    if not nm then return end
    if nm.SetWordWrap then nm:SetWordWrap(false) end
    if nm.SetMaxLines then nm:SetMaxLines(1) end
    if width then nm:SetWidth(width) end
end

-- ============================================================================
-- REPAIR ICONS
-- ============================================================================

local REPAIR_ICONS = {
    { button = "MerchantRepairAllButton",       icon = "MerchantRepairAllIcon",            atlas = "spellicon-256x256-repairall"      },
    { button = "MerchantRepairItemButton",      icon = nil,                                atlas = "spellicon-256x256-repair"         },
    { button = "MerchantGuildBankRepairButton", icon = "MerchantGuildBankRepairButtonIcon", atlas = "spellicon-256x256-repairallguild" },
}

local function repairIconRegion(btn, globalName)
    if globalName and _G[globalName] then return _G[globalName] end
    return FindRegion(btn, "Texture", function(r)
        local p = r.GetTexture and r:GetTexture()
        return type(p) == "string" and p:lower():find("ui%-merchant%-repairicons") ~= nil
    end)
end

local function reskinRepairIcons()
    for _, spec in ipairs(REPAIR_ICONS) do
        local btn = _G[spec.button]
        local icon = btn and repairIconRegion(btn, spec.icon)
        if icon then
            icon:set_atlas(spec.atlas, false)
            icon:ClearAllPoints()
            icon:SetAllPoints(btn)
        end
    end
end

local function addRetailSlotBg(buttonName)
    local btn = _G[buttonName]
    if not btn then return end
    if not btn._duiSlotBg then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(EMPTY_SLOT)
        bg:SetSize(64, 64)
        bg:SetPoint("TOPLEFT", btn, "TOPLEFT", -13, 14)
        btn._duiSlotBg = bg
    end
end

local function addRetailSlotBgs()
    addRetailSlotBg("MerchantRepairAllButton")
    addRetailSlotBg("MerchantRepairItemButton")
    addRetailSlotBg("MerchantGuildBankRepairButton")
    addRetailSlotBg("DragonUI_MerchantSellAllJunkButton")
end

-- ============================================================================
-- BOTTOM BUTTON CLUSTER
-- ============================================================================

local function postRepairButtons()
    local f = _G.MerchantFrame
    if not f or f.selectedTab ~= 1 then return end
    local sell = _G.DragonUI_MerchantSellAllJunkButton

    if CanMerchantRepair() then
        local repAll, repItem = _G.MerchantRepairAllButton, _G.MerchantRepairItemButton
        local guild = CanGuildBankRepair()
        -- 3.3.5a shrinks these to 32 beside the guild anvil; retail keeps every slot at 36.
        repAll:SetSize(36, 36)
        repItem:SetSize(36, 36)
        repAll:ClearAllPoints()
        repAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", guild and 96 or 118, 33)
        repItem:ClearAllPoints()
        repItem:SetPoint("RIGHT", repAll, "LEFT", guild and -9 or -8, 0)
        if guild then
            local gb = _G.MerchantGuildBankRepairButton
            gb:SetSize(36, 36)
            gb:ClearAllPoints()
            gb:SetPoint("LEFT", repAll, "RIGHT", 8, 0)
        end
        if sell then
            sell:ClearAllPoints()
            sell:SetPoint("RIGHT", repAll, "LEFT", guild and 128 or 80, 0)
        end
    elseif sell then
        sell:ClearAllPoints()
        sell:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -148, 33)
    end
end

-- ============================================================================
-- INSETS, PAGE NAV, CLOSE BUTTON
-- ============================================================================

local function buildGridInset()
    local f = _G.MerchantFrame
    if not f or f._duiGridInset then return end
    local inset = attachInset(f, INSET_TL_X, INSET_TL_Y, INSET_BR_X, INSET_BR_Y)
    inset:SetFrameLevel(f:GetFrameLevel() + 1)
    f._duiGridInset = inset
    local wash = inset:CreateTexture(nil, "ARTWORK")
    wash:SetTexture(1, 1, 1, 0.2)
    wash:SetAllPoints(inset)
    wash:Hide()
    f._duiBuybackWash = wash
end

-- Retail's MerchantMoneyInset, plus a stand-in for its ThinGoldEdge MerchantMoneyBg.
local function buildMoneyInset()
    local f = _G.MerchantFrame
    if not f or f._duiMoneyInset then return end
    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT", f, "BOTTOMRIGHT", -171, 36)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
    applyNineSlice(inset, "InsetFrameTemplate")
    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(MARBLE, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints(inset)
    inset:SetFrameLevel(f:GetFrameLevel() + 1)
    f._duiMoneyInset = inset

    local edge = CreateFrame("Frame", nil, inset)
    edge:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -7, 25)
    edge:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -166, 6)
    edge:SetFrameLevel(inset:GetFrameLevel() + 1)
    edge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
    edge:SetBackdropBorderColor(1, 0.82, 0.32, 1)
end

-- Only xoffset: GetUIPanelWindowInfo still copies area/pushable from UIPanelWindows itself.
local function applyPanelLayout(f)
    if f:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then return end
    f:SetAttribute("UIPanelLayout-xoffset", PANEL_X_NUDGE)
    if f:IsShown() and UpdateUIPanelPositions then UpdateUIPanelPositions(f) end
end

-- Must run again after the sell button exists: at f+1 it ties with the opaque band and loses.
local function raiseControls(f)
    local above = (f:GetFrameLevel() or 1) + 4
    for i = 1, BUYBACK_PER_PAGE do
        local row = _G["MerchantItem" .. i]
        if row then row:SetFrameLevel(above) end
    end
    for _, name in ipairs({
        "MerchantBuyBackItem", "MerchantPrevPageButton", "MerchantNextPageButton", "MerchantMoneyFrame",
        "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
        "DragonUI_MerchantSellAllJunkButton",
    }) do
        local b = _G[name]
        if b then b:SetFrameLevel(above) end
    end
    local pageText = _G.MerchantPageText
    if pageText and pageText._duiWrapper then pageText._duiWrapper:SetFrameLevel(above) end
end

local function applyLayout()
    local f = _G.MerchantFrame
    if not f then return end

    f:SetSize(PANEL_W, PANEL_H)
    applyPanelLayout(f)
    if f.SetHitRectInsets then f:SetHitRectInsets(0, 0, 0, 0) end

    local row1 = _G.MerchantItem1
    if row1 then
        row1:ClearAllPoints()
        row1:SetPoint("TOPLEFT", f, "TOPLEFT", GRID_X, GRID_Y)
    end

    local prev, nxt = _G.MerchantPrevPageButton, _G.MerchantNextPageButton
    if prev then
        prev:ClearAllPoints()
        prev:SetPoint("CENTER", f, "BOTTOMLEFT", 25, 96)
    end
    if nxt then
        nxt:ClearAllPoints()
        nxt:SetPoint("CENTER", f, "BOTTOMLEFT", 310, 96)
    end
    local pageText = _G.MerchantPageText
    if pageText then
        local pw = pageText._duiWrapper
        if not pw then
            pw = CreateFrame("Frame", nil, f)
            pageText:SetParent(pw)
            pageText._duiWrapper = pw
        end
        pw:ClearAllPoints()
        pw:SetPoint("BOTTOM", f, "BOTTOM", 0, 86)
        pw:SetSize(104, 20)
        pageText:ClearAllPoints()
        pageText:SetPoint("BOTTOM", pw, "BOTTOM", 0, 0)
        pageText:SetWidth(104)
        pageText:SetJustifyH("CENTER")
    end

    local money = _G.MerchantMoneyFrame
    if money then
        money:ClearAllPoints()
        money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", MONEY_X, MONEY_Y)
    end

    local buyback = _G.MerchantBuyBackItem
    if buyback then
        buyback:ClearAllPoints()
        buyback:SetPoint("TOPLEFT", _G.MerchantItem10, "BOTTOMLEFT", 30, -53)
    end

    raiseControls(f)
end

local function reskinPageNav(btnName)
    local btn = _G[btnName]
    local set = PAGE_BTN_TEX[btnName]
    if not (btn and set) then return end

    local function retexture(getter, path, blend)
        local t = path and btn[getter] and btn[getter](btn)
        if not t then return end
        t:SetTexture(path)
        if blend then t:SetBlendMode(blend) end
    end

    retexture("GetNormalTexture",    set.up)
    retexture("GetPushedTexture",    set.down)
    retexture("GetDisabledTexture",  set.disabled)
    retexture("GetHighlightTexture", PAGE_HILITE, "ADD")

    ForEachRegion(btn, "Texture", "BACKGROUND", function(r)
        r:SetTexture(PAGE_BG)
        r:Show()
    end)
end

local function reskinPageNavButtons()
    reskinPageNav("MerchantPrevPageButton")
    reskinPageNav("MerchantNextPageButton")
end

local function findCloseButton(f)
    if _G.MerchantFrameCloseButton then return _G.MerchantFrameCloseButton end
    for _, child in ipairs({ f:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" and child.GetNormalTexture then
            local t = child:GetNormalTexture()
            local p = t and t.GetTexture and t:GetTexture()
            if type(p) == "string" and p:lower():find("ui%-panel%-minimizebutton") then return child end
        end
    end
    return nil
end

local function modernizeCloseButton()
    local f = _G.MerchantFrame
    if not f then return end
    f.CloseButton = f.CloseButton or findCloseButton(f)
    if not f.CloseButton then return end
    dressCloseButton(f.CloseButton, f)
end

-- ============================================================================
-- PER-UPDATE SYNC
-- ============================================================================

local function setRowPitch(gap)
    local prev = _G.MerchantItem1
    for _, i in ipairs({ 3, 5, 7, 9 }) do
        local row = _G["MerchantItem" .. i]
        if not (row and prev) then return end
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, gap)
        prev = row
    end
    local row11, row9 = _G.MerchantItem11, _G.MerchantItem9
    if row11 and row9 then
        row11:ClearAllPoints()
        row11:SetPoint("TOPLEFT", row9, "BOTTOMLEFT", 0, gap)
    end
end

local function postMerchantUpdate()
    local f = _G.MerchantFrame
    if not f or not f._duiBuilt then return end

    hideReshownClassic()
    updateMerchantTabHighlight(f)
    if f.Title and _G.MerchantNameText then
        f.Title:SetText(_G.MerchantNameText:GetText() or "")
    end

    local onMerchant = (f.selectedTab == 1)
    if onMerchant then
        f._duiBuybackWash:Hide()
        f._duiBotFrame:Show()
        _G.DragonUI_MerchantSellAllJunkButton:Show()
    else
        f._duiBuybackWash:Show()
        f._duiBotFrame:Hide()
        _G.DragonUI_MerchantSellAllJunkButton:Hide()
    end

    for i = 1, BUYBACK_PER_PAGE do
        clampName(_G["MerchantItem" .. i .. "Name"], 84)
    end
    -- Sits 30px right of the rows, so it has less room before the frame edge.
    clampName(_G.MerchantBuyBackItemName, 74)
end

local function colourRow(prefix, link, showBang)
    local nm = _G[prefix .. "Name"]
    if nm then
        local c = TextColor(link)
        if c then
            nm:SetTextColor(c.r, c.g, c.b)
        else
            nm:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        end
    end

    local ib = _G[prefix .. "ItemButton"]
    local bang = ib and ib.IconQuestTexture
    if bang then
        if showBang and ItemStartsQuestByLink(link) then bang:Show() else bang:Hide() end
    end
end

local function postUpdateMerchantInfo()
    local f = _G.MerchantFrame
    if not f or not f._duiBuilt then return end
    setRowPitch(ROW_GAP_MERCHANT)
    local page = f.page or 1
    for i = 1, ITEMS_PER_PAGE do
        colourRow("MerchantItem" .. i, GetMerchantItemLink((page - 1) * ITEMS_PER_PAGE + i), true)
    end
    local n = GetNumBuybackItems()
    colourRow("MerchantBuyBackItem", n > 0 and GetBuybackItemLink(n) or nil, false)
end

local function postUpdateBuybackInfo()
    local f = _G.MerchantFrame
    if not f or not f._duiBuilt then return end
    setRowPitch(ROW_GAP_BUYBACK)
    for i = 1, BUYBACK_PER_PAGE do
        colourRow("MerchantItem" .. i, GetBuybackItemLink(i), false)
    end
end

-- ============================================================================
-- TAB RESKIN
-- ============================================================================

local CAP_OVERHANG = 5
local ACTIVE_OVERHANG_L, ACTIVE_OVERHANG_R = 4, 6
local HL_ALPHA, HL_H = 0.4, 30
local HL_LEFT_TC   = { 0.015625, 0.5625, 0.816406, 0.933594 }
local HL_RIGHT_TC  = { 0.015625, 0.59375, 0.667969, 0.785156 }
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }
local TEXT_ACTIVE_DROP, TEXT_NUDGE_X = -7, -2
local TAB_GAP = 1

local function reskinSingleTab(tabName)
    local tab = _G[tabName]
    if not tab or tab._duiTabReskinned then return end

    tab:SetFrameLevel(tab:GetFrameLevel() + 4)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)

    local left   = _G[tabName .. "Left"]
    local right  = _G[tabName .. "Right"]
    local middle = _G[tabName .. "Middle"]
    local leftD  = _G[tabName .. "LeftDisabled"]
    local rightD = _G[tabName .. "RightDisabled"]
    local midD   = _G[tabName .. "MiddleDisabled"]

    if left then
        left:ClearAllPoints()
        left:SetSize(35, 36)
        left:SetTexture(TAB_TEX)
        left:SetTexCoord(0.015625, 0.5625, 0.816406, 0.957031)
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", -CAP_OVERHANG, 0)
    end
    if right then
        right:ClearAllPoints()
        right:SetSize(37, 36)
        right:SetTexture(TAB_TEX)
        right:SetTexCoord(0.015625, 0.59375, 0.667969, 0.808594)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", CAP_OVERHANG, 0)
    end
    if middle and left and right then
        middle:ClearAllPoints()
        middle:SetSize(1, 36)
        middle:SetTexture(TAB_TEX)
        middle:SetTexCoord(0, 0.015625, 0.175781, 0.316406)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    end

    if leftD then
        leftD:ClearAllPoints()
        leftD:SetSize(35, 42)
        leftD:SetTexture(TAB_TEX)
        leftD:SetTexCoord(0.015625, 0.5625, 0.496094, 0.660156)
        leftD:SetPoint("TOPLEFT", tab, "TOPLEFT", -ACTIVE_OVERHANG_L, 0)
    end
    if rightD then
        rightD:ClearAllPoints()
        rightD:SetSize(37, 42)
        rightD:SetTexture(TAB_TEX)
        rightD:SetTexCoord(0.015625, 0.59375, 0.324219, 0.488281)
        rightD:SetPoint("TOPRIGHT", tab, "TOPRIGHT", ACTIVE_OVERHANG_R, 0)
    end
    if midD and leftD and rightD then
        midD:ClearAllPoints()
        midD:SetSize(1, 42)
        midD:SetTexture(TAB_TEX)
        midD:SetTexCoord(0, 0.015625, 0.00390625, 0.167969)
        midD:SetPoint("TOPLEFT", leftD, "TOPRIGHT")
        midD:SetPoint("TOPRIGHT", rightD, "TOPLEFT")
    end

    local stock = tab:GetHighlightTexture()
    if stock then stock:SetTexture(nil) end

    local function glow(tc, w, anchor)
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(tc))
        t:SetSize(w, HL_H)
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end

    local hlLeft  = left  and glow(HL_LEFT_TC,   35, left)
    local hlRight = right and glow(HL_RIGHT_TC,  37, right)
    local hlMid   = middle and (function()
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(HL_MIDDLE_TC))
        t:SetHeight(HL_H)
        t:SetPoint("TOPLEFT", hlLeft, "TOPRIGHT")
        t:SetPoint("TOPRIGHT", hlRight, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end)()

    tab._duiHighlight = { hlLeft, hlRight, hlMid }

    local w = tab:GetTextWidth() + 24
    if w < 64 then w = 64 end
    tab._duiWidth = w
    tab:SetWidth(w)

    tab._duiTabReskinned = true
end

local function reskinMerchantTabs(f)
    reskinSingleTab("MerchantFrameTab1")
    reskinSingleTab("MerchantFrameTab2")

    local prev
    for _, name in ipairs({ "MerchantFrameTab1", "MerchantFrameTab2" }) do
        local tab = _G[name]
        if tab and tab:IsShown() then
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
            else
                tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
            end
            prev = tab
        end
    end
end

-- ============================================================================
-- TAB LABEL STATE
-- ============================================================================

updateMerchantTabHighlight = function(f)
    if not f then return end
    for i = 1, 2 do
        local tab = _G["MerchantFrameTab" .. i]
        if tab then
            local active = (i == f.selectedTab)
            tab:SetNormalFontObject(GameFontNormalSmall)
            tab:SetHighlightFontObject(GameFontHighlightSmall)
            tab:SetDisabledFontObject(active and GameFontHighlightSmall or GameFontNormalSmall)
            if tab._duiWidth then tab:SetWidth(tab._duiWidth) end

            local text = _G[tab:GetName() .. "Text"]
            if text then
                text:ClearAllPoints()
                local offsetY = active and TEXT_ACTIVE_DROP or 0
                text:SetPoint("CENTER", tab, "CENTER", TEXT_NUDGE_X, offsetY)
            end

            for _, piece in ipairs(tab._duiHighlight or {}) do
                piece:SetAlpha(active and 0 or HL_ALPHA)
            end
        end
    end
end

-- ============================================================================
-- BUILD — deferred from login to first MERCHANT_SHOW
-- ============================================================================

local built = false

local function doBuild(f)
    applyModernChrome()
    ensureTitle(f, (_G.MerchantNameText and _G.MerchantNameText:GetText()) or "")
    if _G.MerchantFramePortrait then
        applyPortraitCutout(_G.MerchantFramePortrait, f)
    end

    buildGridInset()
    buildBottomBand()
    reskinAllSlots()
    addQuestBangs()
    reskinRepairIcons()
    buildMoneyInset()
    modernizeCloseButton()
    reskinPageNavButtons()
    reskinMerchantTabs(f)

    addon.MerchantSellAllJunkBuild()
    addon.MerchantBuybackUndoBuild()

    addRetailSlotBgs()
    raiseControls(f)
end

-- Runs inside MERCHANT_SHOW, after FrameXML's own handler has shown and filled the frame.
local function buildModernChrome()
    if built then return end
    local f = _G.MerchantFrame
    if not f then return end
    built = true

    local ok, err = pcall(doBuild, f)
    if not ok then
        addon:Error("Merchant build failed: " .. tostring(err))
        return
    end

    f._duiBuilt = true
    if f:IsShown() then
        -- Our SetTexture on the anvils dropped the desaturation OnShow had just applied.
        MerchantFrame_UpdateCanRepairAll()
        MerchantFrame_UpdateGuildBankRepair()
        MerchantFrame_Update()
    else
        postMerchantUpdate()
    end
end

-- ============================================================================
-- ARM — hooks and suppression, once per session
-- ============================================================================

local function ArmMerchant()
    if MerchantModule.initialized then return end
    MerchantModule.initialized = true

    hideClassicChrome()
    applyLayout()

    hooksecurefunc("MerchantFrame_Update", postMerchantUpdate)
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", postUpdateMerchantInfo)
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", postUpdateBuybackInfo)
    hooksecurefunc("MerchantFrame_UpdateRepairButtons", postRepairButtons)

    local showWatcher = CreateFrame("Frame")
    showWatcher:RegisterEvent("MERCHANT_SHOW")
    showWatcher:SetScript("OnEvent", function(self)
        buildModernChrome()
        self:UnregisterEvent("MERCHANT_SHOW")
    end)
    MerchantModule.frames.showWatcher = showWatcher
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

local function ApplyMerchantSystem()
    if not IsModuleEnabled() then return end
    MerchantModule.applied = true
    ArmMerchant()
end

-- Load-once: the hooks stay for the session, so turning the module off takes effect on reload.
local function RestoreMerchantSystem()
    MerchantModule.applied = false
end

addon.ApplyMerchantSystem = ApplyMerchantSystem
addon.RestoreMerchantSystem = RestoreMerchantSystem

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ApplyMerchantSystem()
end)
