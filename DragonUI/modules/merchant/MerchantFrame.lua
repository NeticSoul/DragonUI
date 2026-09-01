-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Retail-style chrome on Blizzard's vendor window. FrameXML keeps buy/sell/repair;

local addon = select(2, ...)
if not addon then return end

local L = addon.L
local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local REDBUTTON = DIR .. "UI\\redbutton2x"
local LABEL_PLATE = DIR .. "Merchant\\labelslots"
local PAGE_BG = DIR .. "Merchant\\pagebutton-background"
local PAGE_HILITE = DIR .. "Merchant\\pagebutton-hover"
local QUICKSLOT_BG = DIR .. "UI\\ui-quickslot2"
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
    hooks = {},
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

local function GetModuleConfig()
    return addon:GetModuleConfig("merchant")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("merchant")
end

-- ============================================================================
-- INLINE HELPERS
-- ============================================================================

local function TextColor(quality)
    return quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or nil
end

local _questScanTooltip
local function ItemStartsQuestByLink(link)
    if not link then return false end
    if not _questScanTooltip then
        _questScanTooltip = CreateFrame("GameTooltip", "DragonUI_MerchantQuestScan", nil, "GameTooltipTemplate")
        _questScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    _questScanTooltip:ClearLines()
    _questScanTooltip:SetHyperlink(link)
    for i = 1, _questScanTooltip:NumLines() do
        local text = _G["DragonUI_MerchantQuestScanTextLeft" .. i] and _G["DragonUI_MerchantQuestScanTextLeft" .. i]:GetText()
        if text and text == ITEM_SPELL_STARTS_QUEST then
            return true
        end
    end
    return false
end

-- ============================================================================
-- LOCAL HELPERS
-- ============================================================================

local function setAtlas(tex, name, useSize)
    if not tex or not name or not addon.atlasinfo or not addon.atlasinfo[name] then
        return false
    end
    tex:set_atlas(name, useSize and true or false)
    return true
end

local function ForEachRegion(frame, kind, layer, fn)
    if not (frame and frame.GetNumRegions) then return end
    local n = frame:GetNumRegions()
    for i = 1, n do
        local r = select(i, frame:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == kind then
            if not layer or (r.GetDrawLayer and r:GetDrawLayer() == layer) then
                fn(r)
            end
        end
    end
end

local function FindRegion(frame, kind, predicate)
    if not (frame and frame.GetNumRegions) then return nil end
    local n = frame:GetNumRegions()
    for i = 1, n do
        local r = select(i, frame:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == kind and predicate(r) then
            return r
        end
    end
    return nil
end

local function keep(f, obj)
    if not (f and obj) then return end
    f._duiKeep = f._duiKeep or {}
    f._duiKeep[obj] = true
end

local function applyNineSlice(container, layoutName)
    if not (container and NineSliceUtils and NineSliceUtils.GetLayout) then return false end
    local layout = NineSliceUtils.GetLayout(layoutName)
    if not layout then return false end
    NineSliceUtils.ApplyLayout(container, layout)
    return true
end

local function attachInset(parent, tlx, tly, brx, bry)
    if not parent then return nil end
    local inset = CreateFrame("Frame", nil, parent)
    inset:EnableMouse(false)
    inset:SetPoint("TOPLEFT", parent, "TOPLEFT", tlx, tly)
    inset:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", brx, bry)
    applyNineSlice(inset, "InsetFrameTemplate")
    return inset
end

local function applyPortraitCutout(tex, parent)
    if not tex or not parent or tex._duiCutout then return end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", -5, 8)
    tex:SetSize(60, 60)
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
local INSET_TL_X, INSET_TL_Y = 2, -59
local INSET_BR_X, INSET_BR_Y = -6, 26
local INSET_BR_Y_BUYBACK = 27
local ROW_GAP_MERCHANT, ROW_GAP_BUYBACK = -8, -15
local BAND_Y     = 26
local BAND_INSET = 1
local TILE_BLEED = 14
local MONEY_X, MONEY_Y = -10, 8

-- ============================================================================
-- CLASSIC ART DETECTION (must be defined before diagnose and hideClassicChrome)
-- ============================================================================

local CLASSIC_PATHS = { "ui%-merchant%-top", "ui%-merchant%-bot", "ui%-buyback%-" }

local function isClassicArt(r)
    local p = r.GetTexture and r:GetTexture()
    if type(p) ~= "string" then return false end
    p = p:lower()
    for _, pat in ipairs(CLASSIC_PATHS) do
        if p:find(pat) then return true end
    end
    return false
end

-- ============================================================================
-- OUTER CHROME — classic art suppression + modern chrome
-- ============================================================================

local function hideClassicChrome()
    local f = _G.MerchantFrame
    if not f then return end

    if _G.MerchantFramePortrait then keep(f, _G.MerchantFramePortrait) end

    ForEachRegion(f, "Texture", "BORDER", function(r)
        if r ~= f._duiStreaks and isClassicArt(r) then r:Hide() end
    end)
    ForEachRegion(f, "Texture", "ARTWORK", function(r)
        if r ~= f._duiStreaks and isClassicArt(r) then r:Hide() end
    end)

    local kept = f._duiKeep or {}
    if f.Bg then kept[f.Bg] = true end
    if f._duiGridInsetBg then kept[f._duiGridInsetBg] = true end
    if f._duiMoneyInsetBg then kept[f._duiMoneyInsetBg] = true end
    ForEachRegion(f, "Texture", "BACKGROUND", function(r)
        if not kept[r] then r:Hide() end
    end)

    if _G.MerchantNameText then _G.MerchantNameText:Hide() end

    for _, name in ipairs({
        "MerchantRepairText", "MerchantFrameBottomLeftBorder", "MerchantFrameBottomRightBorder",
        "BuybackFrameTopLeft", "BuybackFrameTopRight", "BuybackFrameBotLeft", "BuybackFrameBotRight",
    }) do
        local t = _G[name]
        if t and t.Hide then t:Hide() end
    end
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
    if not setAtlas(t, "ui-merchant-botframe", false) then
        band:Hide()
        return
    end
    t:SetAllPoints()
    band:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._duiBotFrame = band
end

-- ============================================================================
-- ROWS — slot reskin, quest bang, name clamping
-- ============================================================================

local function rowTexture(row, prefix, suffix, pathPattern)
    local t = _G[prefix .. suffix]
    if t then return t end
    if not row then return nil end
    return FindRegion(row, "Texture", function(r)
        local p = r.GetTexture and r:GetTexture()
        return type(p) == "string" and p:lower():find(pathPattern) ~= nil
    end)
end

local function reskinSlot(prefix, showLabel)
    local row = _G[prefix]
    local slot = rowTexture(row, prefix, "SlotTexture", "ui%-emptyslot")
    if slot then
        slot:Show()
    end

    local ib  = _G[prefix .. "ItemButton"]
    local nrm = (ib and ib.GetNormalTexture and ib:GetNormalTexture())
                or _G[prefix .. "ItemButtonNormalTexture"]
    if nrm then
        nrm:ClearAllPoints()
        nrm:SetSize(64, 64)
        nrm:SetPoint("CENTER", ib, "CENTER", 0, -1)
    end

    local nameFrame = rowTexture(row, prefix, "NameFrame", "ui%-merchant%-labelslots")
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

local function fitBuybackIcon()
    local ib = _G.MerchantBuyBackItemItemButton
    if not ib then return end
    local icon = _G.MerchantBuyBackItemItemButtonIconTexture or ib.icon
    if not icon then return end
    icon:ClearAllPoints()
    icon:SetAllPoints(ib)
end

local function fitBuybackQualityGlow()
    local ib = _G.MerchantBuyBackItemItemButton
    local glow = ib and ib.__DragonUI_QualityOverlay
    if not glow then return end
    local n = (ib:GetWidth() or 37) * 1.7
    if math.abs((glow:GetWidth() or 0) - n) < 0.5 then return end
    glow:SetSize(n, n)
end

local BUYBACK_BTN = 37

local function fitBuybackToBar()
    local ib = _G.MerchantBuyBackItemItemButton
    if not ib then return end
    ib:SetSize(BUYBACK_BTN, BUYBACK_BTN)
    local row = _G.MerchantBuyBackItem
    if row then row:SetSize(BUYBACK_BTN, BUYBACK_BTN) end
    fitBuybackIcon()
    local slot = _G.MerchantBuyBackItemSlotTexture
    if slot then slot:Show() end
    local nrm = ib.GetNormalTexture and ib:GetNormalTexture()
    if nrm then nrm:Show() end
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
    { button = "MerchantGuildBankRepairButton", icon = "MerchantGuildBankRepairButtonIcon", atlas = "spellicon-256x256-repairallguild", size = 36 },
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
        if btn and spec.size then btn:SetSize(spec.size, spec.size) end
        local icon = btn and repairIconRegion(btn, spec.icon)
        if icon and setAtlas(icon, spec.atlas, false) then
            icon:ClearAllPoints()
            icon:SetAllPoints(btn)
            btn._duiIcon = icon
        end
    end
end

local function addRetailSlotBg(buttonName)
    local btn = _G[buttonName]
    if not btn then return end
    if not btn._duiSlotBg then
        local bg = btn:CreateTexture(nil, "OVERLAY", nil, -2)
        bg:SetTexture(QUICKSLOT_BG)
        bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -(TILE_BLEED + 3) + 1,  (TILE_BLEED + 3) - 1)
        bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  (TILE_BLEED + 3) + 1, -(TILE_BLEED + 3) - 1)
        bg:SetVertexColor(1, 0.82, 0.32, 1)
        btn._duiSlotBg = bg
        bg:Show()
        local highlight = btn:GetHighlightTexture()
        if highlight then
            highlight:SetBlendMode("ADD")
        end
    end
end

local function syncSlotBg(buttonName, shown)
    local btn = _G[buttonName]
    local bg = btn and btn._duiSlotBg
    if not bg then return end
    if shown then bg:Show() else bg:Hide() end
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

    addRetailSlotBgs()

    local sell    = _G.DragonUI_MerchantSellAllJunkButton
    local repAll  = _G.MerchantRepairAllButton
    local repItem = _G.MerchantRepairItemButton
    local gb      = _G.MerchantGuildBankRepairButton

    if CanMerchantRepair and CanMerchantRepair() then
        local guild = CanGuildBankRepair and CanGuildBankRepair()

        if repAll then
            repAll:ClearAllPoints()
            if guild then
                repAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 96, 33)
            else
                repAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 118, 33)
            end
            repAll:Show()
        end
        syncSlotBg("MerchantRepairAllButton", true)

        if repItem then
            repItem:ClearAllPoints()
            repItem:SetPoint("RIGHT", repAll, "LEFT", guild and -9 or -8, 0)
            repItem:Show()
        end
        syncSlotBg("MerchantRepairItemButton", true)

        if sell then
            sell:ClearAllPoints()
            sell:SetPoint("RIGHT", repAll, "LEFT", guild and 128 or 80, 0)
        end
        syncSlotBg("DragonUI_MerchantSellAllJunkButton", true)

        if gb then
            if guild then
                gb:ClearAllPoints()
                gb:SetPoint("LEFT", repAll, "RIGHT", 8, 0)
                gb:Show()
            else
                gb:Hide()
            end
        end
        syncSlotBg("MerchantGuildBankRepairButton", guild and true or false)
    else
        if repAll then repAll:Hide() end
        syncSlotBg("MerchantRepairAllButton", false)

        if repItem then repItem:Hide() end
        syncSlotBg("MerchantRepairItemButton", false)

        if gb then gb:Hide() end
        syncSlotBg("MerchantGuildBankRepairButton", false)

        if sell then
            sell:ClearAllPoints()
            sell:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -148, 33)
        end
        syncSlotBg("DragonUI_MerchantSellAllJunkButton", true)
    end
end

-- ============================================================================
-- INSETS, PAGE NAV, CLOSE BUTTON
-- ============================================================================

local INSET_TONE          = { 0.22, 0.22, 0.23 }
local INSET_TONE_BUYBACK  = { 0.22, 0.22, 0.23 }

local function insetFill(f, key, rect, tone)
    if f[key] then return f[key] end
    local t = f:CreateTexture(nil, "ARTWORK", nil, -8)
    t:SetPoint("TOPLEFT",     rect, "TOPLEFT",     0, 0)
    t:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", 0, 0)
    t:SetTexture(ROCK, "REPEAT", "REPEAT")
    t:SetHorizTile(true)
    t:SetVertTile(true)
    t:SetVertexColor(tone[1], tone[2], tone[3])
    keep(f, t)
    f[key] = t
    return t
end

local function buildGridInset()
    local f = _G.MerchantFrame
    if not f or f._duiGridInset then return end
    local inset = attachInset(f, INSET_TL_X, INSET_TL_Y, INSET_BR_X, INSET_BR_Y)
    if not inset then return end
    inset:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._duiGridInset = inset
    insetFill(f, "_duiGridInsetBg", inset, INSET_TONE)
    local ov = f:CreateTexture(nil, "ARTWORK", nil, -7)
    ov:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ov:SetVertexColor(1, 1, 1)
    ov:SetAlpha(0.2)
    ov:SetPoint("TOPLEFT",     inset, "TOPLEFT",     0, 0)
    ov:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
    ov:Hide()
    keep(f, ov)
    f._duiBuybackOverlay = ov
end

local function buildMoneyInset()
    local f = _G.MerchantFrame
    local money = _G.MerchantMoneyFrame
    if not (f and money) or f._duiMoneyInset then return end
    if money.SetWidth then
        money:SetWidth(160)
    end
    if not money._duiWidthHooked and hooksecurefunc then
        local moneyName = money:GetName()
        hooksecurefunc("MoneyFrame_Update", function(name)
            if name == moneyName and money.GetWidth and money:GetWidth() > 160 then
                money:SetWidth(160)
            end
        end)
        money._duiWidthHooked = true
    end

    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT",     money, "TOPLEFT",     -8, 6)
    inset:SetPoint("BOTTOMRIGHT", money, "BOTTOMRIGHT",  6, -6)
    inset:EnableMouse(false)
    applyNineSlice(inset, "InsetFrameTemplate")
    inset:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    f._duiMoneyInset = inset
    if inset.SetBackdrop then
        local box = CreateFrame("Frame", nil, inset)
        box:SetPoint("TOPLEFT",     inset, "TOPLEFT",      3, -2)
        box:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT",  0,  2)
        box:SetFrameLevel((inset:GetFrameLevel() or 0) + 2)
        box:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
            bgFile = nil,
        })
        box:SetBackdropBorderColor(1, 0.82, 0.32, 1)
        keep(f, box)
        f._duiMoneyTooltipBorder = box
    end

    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetVertexColor(INSET_TONE[1], INSET_TONE[2], INSET_TONE[3])
    keep(f, bg)
    f._duiMoneyInsetBg = bg
end

local function applyPanelLayout(f)
    if not f.SetAttribute then return end
    if f:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then return end
    f:SetAttribute("UIPanelLayout-area",     "left")
    f:SetAttribute("UIPanelLayout-pushable", 0)
    f:SetAttribute("UIPanelLayout-xoffset",  PANEL_X_NUDGE)
    f:SetAttribute("UIPanelLayout-enabled",  true)
    f:SetAttribute("UIPanelLayout-defined",  true)
    if f:IsShown() and UpdateUIPanelPositions then UpdateUIPanelPositions(f) end
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

    local sellJunk = _G.MerchantFrameSellJunkFrame
    if sellJunk then
        sellJunk:ClearAllPoints()
        sellJunk:SetPoint("BOTTOMRIGHT", money, "BOTTOMLEFT", -4, 0)
    end

    local repairSettings = _G.MerchantRepairSettingsButton
    if repairSettings then
        repairSettings:ClearAllPoints()
        repairSettings:SetPoint("BOTTOMRIGHT", sellJunk, "BOTTOMLEFT", -4, 0)
    end

    local above = (f:GetFrameLevel() or 1) + 4
    for i = 1, BUYBACK_PER_PAGE do
        local row = _G["MerchantItem" .. i]
        if row then row:SetFrameLevel(above) end
    end
    if _G.MerchantBuyBackItem then _G.MerchantBuyBackItem:SetFrameLevel(above) end
    if prev then prev:SetFrameLevel(above) end
    if nxt  then nxt:SetFrameLevel(above)  end
    if pageText and pageText._duiWrapper then pageText._duiWrapper:SetFrameLevel(above) end
    if money then money:SetFrameLevel(above) end
    for _, name in ipairs({
        "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
        "DragonUI_MerchantSellAllJunkButton"
    }) do
        local b = _G[name]
        if b then b:SetFrameLevel(above) end
    end
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

local function setInsetForTab(f)
    local inset = f._duiGridInset
    if not inset then return end
    local buyback = (f.selectedTab == 2)

    if f._duiBuybackOverlay then
        if buyback then f._duiBuybackOverlay:Show() else f._duiBuybackOverlay:Hide() end
    end

    local y = buyback and INSET_BR_Y_BUYBACK or INSET_BR_Y
    if inset._duiBottom == y then return end
    inset._duiBottom = y
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", INSET_BR_X, y)
    local tone = buyback and INSET_TONE_BUYBACK or INSET_TONE
    local bg = f._duiGridInsetBg
    if bg then bg:SetVertexColor(tone[1], tone[2], tone[3]) end
end

local function postMerchantUpdate()
    local f = _G.MerchantFrame
    if not f or not f._duiBuilt then return end

    hideClassicChrome()
    setInsetForTab(f)
    updateMerchantTabHighlight(f)
    if f.Bg then f.Bg:Show() end

    if f.Title and _G.MerchantNameText then
        f.Title:SetText(_G.MerchantNameText:GetText() or "")
    end

    local p = _G.MerchantFramePortrait
    if p then
        p:Show()
        if f.selectedTab == 2 then
            p:SetTexture("Interface\\MerchantFrame\\UI-BuyBack-Icon")
            p:SetTexCoord(0, 1, 0, 1)
        elseif SetPortraitTexture then
            SetPortraitTexture(p, "NPC")
        end
    end

    local onMerchant = (f.selectedTab == 1)

    if f._duiBotFrame then
        if onMerchant then f._duiBotFrame:Show() else f._duiBotFrame:Hide() end
    end
    local sell = _G.DragonUI_MerchantSellAllJunkButton
    if sell then
        if onMerchant then sell:Show() else sell:Hide() end
    end

    local buyback = _G.MerchantBuyBackItem
    if buyback then
        if onMerchant then buyback:Show() else buyback:Hide() end
    end
    if not onMerchant then
        for _, name in ipairs({
            "MerchantGuildBankRepairButton", "MerchantRepairAllButton", "MerchantRepairItemButton",
        }) do
            local b = _G[name]
            if b then b:Hide() end
        end
    end

    for i = 1, BUYBACK_PER_PAGE do
        clampName(_G["MerchantItem" .. i .. "Name"], 84)
    end
    if _G.MerchantBuyBackItemName then _G.MerchantBuyBackItemName:Hide() end
    if _G.MerchantBuyBackItemMoneyFrame then _G.MerchantBuyBackItemMoneyFrame:Hide() end
    fitBuybackIcon()
    fitBuybackToBar()
    fitBuybackQualityGlow()

    postRepairButtons()
end

local function colourRow(prefix, link)
    if not _G[prefix] then return end
    local quality = link and select(3, GetItemInfo(link)) or nil

    local nm = _G[prefix .. "Name"]
    if nm then
        local c = TextColor(quality)
        if c then
            nm:SetTextColor(c.r, c.g, c.b)
        else
            nm:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        end
    end

    local ib = _G[prefix .. "ItemButton"]
    local bang = ib and ib.IconQuestTexture
    if bang then
        if link and ItemStartsQuestByLink(link) then bang:Show() else bang:Hide() end
    end
end

local function postUpdateMerchantInfo()
    local f = _G.MerchantFrame
    if not f or not f._duiBuilt then return end
    setRowPitch(ROW_GAP_MERCHANT)
    local page = f.page or 1
    for i = 1, ITEMS_PER_PAGE do
        local index = ((page - 1) * ITEMS_PER_PAGE) + i
        colourRow("MerchantItem" .. i, GetMerchantItemLink and GetMerchantItemLink(index))
    end
    local n = (GetNumBuybackItems and GetNumBuybackItems()) or 0
    colourRow("MerchantBuyBackItem",
              (n > 0 and GetBuybackItemLink) and GetBuybackItemLink(n) or nil)
end

local function postUpdateBuybackInfo()
    local f = _G.MerchantFrame
    if not f or not f._duiBuilt then return end
    setRowPitch(ROW_GAP_BUYBACK)
    for i = 1, BUYBACK_PER_PAGE do
        colourRow("MerchantItem" .. i, GetBuybackItemLink and GetBuybackItemLink(i))
        local ib = _G["MerchantItem" .. i .. "ItemButton"]
        if ib and ib.IconQuestTexture then ib.IconQuestTexture:Hide() end
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
-- TAB LABEL STATE —
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

local function buildModernChrome()
    if built then return end
    local f = _G.MerchantFrame
    if not f then return end
    built = true

    local function _doBuild()
        applyModernChrome()
        ensureTitle(f, (_G.MerchantNameText and _G.MerchantNameText:GetText()) or "")
        if _G.MerchantFramePortrait then
            applyPortraitCutout(_G.MerchantFramePortrait, f)
        end

        buildGridInset()
        buildBottomBand()
        reskinAllSlots()
        fitBuybackToBar()
        addQuestBangs()
        reskinRepairIcons()
        buildMoneyInset()
        modernizeCloseButton()
        reskinPageNavButtons()
        reskinMerchantTabs(f)

        for i = 1, BUYBACK_PER_PAGE do clampName(_G["MerchantItem" .. i .. "Name"], 84) end

        if addon.MerchantSellAllJunkBuild then addon.MerchantSellAllJunkBuild() end
        if addon.MerchantBuybackUndoBuild then addon.MerchantBuybackUndoBuild() end

        addRetailSlotBgs()
    end

    local ok, err = xpcall(_doBuild, function(e) return tostring(e) end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1DragonUI|r Merchant build error: " .. tostring(err))
        return
    end

    f._duiBuilt = true

    if f:IsShown() and _G.MerchantFrame_Update then
        MerchantFrame_Update()
    else
        postMerchantUpdate()
    end
end

local syncPending
local function syncSoon()
    local f = _G.MerchantFrame
    if not f or syncPending then return end
    syncPending = true
    addon:After(0, function()
        syncPending = false
        local frame = _G.MerchantFrame
        if not frame or not frame:IsShown() then return end
        if not built then
            buildModernChrome()
        end
        if not frame._duiBuilt then return end
        postMerchantUpdate()
        if frame.selectedTab == 2 then postUpdateBuybackInfo() else postUpdateMerchantInfo() end
    end)
end

-- ============================================================================
-- ARM — called once at login to set up hooks and suppression
-- ============================================================================

local function ArmMerchant()
    if MerchantModule.applied then return end

    hideClassicChrome()
    applyLayout()

    -- Hook FrameXML updaters
    if _G.MerchantFrame_Update and not MerchantModule.hooks["MerchantFrame_Update"] then
        hooksecurefunc("MerchantFrame_Update", postMerchantUpdate)
        MerchantModule.hooks["MerchantFrame_Update"] = true
    end
    if _G.MerchantFrame_UpdateMerchantInfo and not MerchantModule.hooks["MerchantFrame_UpdateMerchantInfo"] then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", postUpdateMerchantInfo)
        MerchantModule.hooks["MerchantFrame_UpdateMerchantInfo"] = true
    end
    if _G.MerchantFrame_UpdateBuybackInfo and not MerchantModule.hooks["MerchantFrame_UpdateBuybackInfo"] then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", postUpdateBuybackInfo)
        MerchantModule.hooks["MerchantFrame_UpdateBuybackInfo"] = true
    end
    if _G.MerchantFrame_UpdateRepairButtons and not MerchantModule.hooks["MerchantFrame_UpdateRepairButtons"] then
        hooksecurefunc("MerchantFrame_UpdateRepairButtons", postRepairButtons)
        MerchantModule.hooks["MerchantFrame_UpdateRepairButtons"] = true
    end

    for _, tabName in ipairs({ "MerchantFrameTab1", "MerchantFrameTab2" }) do
        local tab = _G[tabName]
        if tab and tab.HookScript and not MerchantModule.hooks["tab_" .. tabName] then
            tab:HookScript("OnClick", function()
                syncSoon()
            end)
            MerchantModule.hooks["tab_" .. tabName] = true
        end
    end

    local syncFrame = CreateFrame("Frame")
    syncFrame:RegisterEvent("MERCHANT_SHOW")
    syncFrame:RegisterEvent("MERCHANT_UPDATE")
    syncFrame:RegisterEvent("MERCHANT_CLOSED")
    syncFrame:SetScript("OnEvent", function()
        syncSoon()
    end)
    MerchantModule.frames.syncFrame = syncFrame

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    watcher:SetScript("OnEvent", function()
        local f = _G.MerchantFrame
        if not (f and f._duiBuilt and f:IsShown()) then return end
        if f.selectedTab == 2 then postUpdateBuybackInfo() else postUpdateMerchantInfo() end
    end)
    MerchantModule.frames.watcher = watcher

    MerchantModule.applied = true
end

-- ============================================================================
-- LIFECYCLE: Apply / Restore / Refresh
-- ============================================================================

local function ApplyMerchant(force)
    if MerchantModule.applied and not force then return end
    if not IsModuleEnabled() then return end
    if MerchantModule.applied then
        RestoreMerchant(false)
        MerchantModule.applied = false
    end
    ArmMerchant()
end

local function RestoreMerchant(resetDeps)
    if not MerchantModule.applied then return end
    MerchantModule.applied = false
end

local function RefreshMerchant(forceSync)
    if MerchantModule.applied then
        RestoreMerchant(false)
    end
    if IsModuleEnabled() then
        ApplyMerchant(forceSync == true)
    end
end

-- ============================================================================
-- EXPOSE ON ADDON NAMESPACE
-- ============================================================================

function addon.ApplyMerchantSystem() ApplyMerchant() end
function addon.RestoreMerchantSystem() RestoreMerchant() end
function addon.RefreshMerchantSystem() RefreshMerchant() end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    if IsModuleEnabled() then
        RefreshMerchant()
    else
        if (addon.ShouldDeferModuleDisable and addon:ShouldDeferModuleDisable("merchant", MerchantModule)) then
            return
        end
        RestoreMerchant()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileReset", OnProfileChanged)
            end
        end)
        MerchantModule.initialized = true
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        ApplyMerchant()
        addon:After(0.5, function()
            if not IsModuleEnabled() then return end
            ArmMerchant()
        end)
    end
end)

