-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local unpack = unpack
local type = type
local math_floor = math.floor
local math_min = math.min
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local GetInboxNumItems = GetInboxNumItems
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxItem = GetInboxItem
local GetSendMailItem = GetSendMailItem
local SetPortraitToTexture = SetPortraitToTexture
local TakeInboxMoney = TakeInboxMoney
local TakeInboxItem = TakeInboxItem
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local CheckInbox = CheckInbox
local HideUIPanel = HideUIPanel
local StaticPopup_Hide = StaticPopup_Hide

local MailModule = {
    initialized = false,
    applied = false,
}

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("mail", MailModule,
        localized("Mail"),
        localized("Retail-style mail window with Open All button"),
        { lifecyclePrefix = "Mail", loadOnce = true })
end

local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local MARBLE = DIR .. "UI\\ui-background-marble"
local INBOX_BG = DIR .. "Mail\\ui-mailframebg"
local ICON_BORDER = DIR .. "Mail\\whiteiconframe"
local MAIL_ICON = "Interface\\MailFrame\\Mail-Icon"
local MAIL_ICON_HD = DIR .. "Mail\\mail-icon"
local COINBOX = DIR .. "Coins\\commoncoinbox"
local TAB_TEX = DIR .. "UI\\uiframetabs"

-- SetItemButtonQuality's bag colours by item quality; poor items get no border.
local QUALITY_BORDER_COLORS = {
    [1] = { 0.65882, 0.65882, 0.65882 },
    [2] = { 0.08235, 0.70196, 0 },
    [3] = { 0, 0.56863, 0.94902 },
    [4] = { 0.78431, 0.27059, 0.98039 },
    [5] = { 1, 0.50196, 0 },
    [6] = { 0.90196, 0.8, 0.50196 },
    [7] = { 0, 0.8, 1 },
}

local WIDTH, HEIGHT = 338, 424
-- Retail's InboxFrame/SendMailFrame stay 384x512 behind a 338x424 window; ours fill the window.
local RETAIL_DROP, RETAIL_WIDEN = 512 - HEIGHT, 384 - WIDTH
local INSET_INBOX = { 4, -58, -6, 4 }
local INSET_SEND  = { 4, -80, -6, 26 }
local INSET_OPEN  = { 4, -80, -6, 26 }
local PANEL_X_NUDGE = 6
local ATTACHMENTS_MAX = _G.ATTACHMENTS_MAX or 16
local ATTACHMENTS_MAX_RECEIVE = _G.ATTACHMENTS_MAX_RECEIVE or 16
local ATTACHMENTS_PER_ROW_RECEIVE = _G.ATTACHMENTS_PER_ROW_RECEIVE or 7
local ATTACHMENTS_MAX_SEND = _G.ATTACHMENTS_MAX_SEND or 12
local ATTACHMENTS_PER_ROW_SEND = _G.ATTACHMENTS_PER_ROW_SEND or 7

-- Retail PanelTabButtonTemplate / PanelTemplates_TabResize values; MailFrame caps tabs at width / 3.
local TAB_H = 32
local TAB_LEFT_X, TAB_RIGHT_X = -3, 7
local TAB_ACTIVE_LEFT_X, TAB_ACTIVE_RIGHT_X = -1, 8
local TAB_SIDES_PADDING = 20
local TAB_MIN_W = 35 + 37
local TAB_MAX_W = math_floor(WIDTH / 3)
local TAB_TEXT_Y, TAB_SELECTED_TEXT_Y = 2, -3
local TAB_START_X, TAB_START_Y = 14, 2
local TAB_GAP = 3
local HL_ALPHA, HL_H = 0.4, 30
local HL_LEFT_TC   = { 0.015625, 0.5625, 0.816406, 0.933594 }
local HL_RIGHT_TC  = { 0.015625, 0.59375, 0.667969, 0.785156 }
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("mail")
    end
    return true
end

local function applySlices(host, layoutName)
    local slicer = _G.DragonUI_NineSlice
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if layout and slicer.ApplyLayout then
        slicer.ApplyLayout(host, layout)
    end
end

local function nudgePanel(window)
    if not window or not window.SetAttribute then return end
    if window:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then return end
    window:SetAttribute("UIPanelLayout-xoffset", PANEL_X_NUDGE)
    if window:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(window)
    end
end

local function dressCloseButton(cb, owner)
    if not cb or cb._duiModernized then return end
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then
        CP.ModernizeCloseButton(cb, owner)
        cb:SetFrameLevel((owner:GetFrameLevel() or 1) + 22)
    end
end

local function skinActionButton(btn, width, height)
    if not btn then return end
    if width and height then
        btn:SetSize(width, height)
    end
    if addon.SkinRedButton then
        addon.SkinRedButton(btn)
    end
end

local function placeInset(inset, window, bounds)
    if not inset or not window or not bounds then return end
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", window, "TOPLEFT", bounds[1], bounds[2])
    inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", bounds[3], bounds[4])
end

-- SetFrameLevel leaves existing children behind, so they could sink under the parchment.
local function liftChildren(frame)
    local base = frame:GetFrameLevel()
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:GetFrameLevel() <= base then
            child:SetFrameLevel(base + 1)
        end
        liftChildren(child)
    end
end

local function neuterTexture(tex)
    if not tex or tex._duiNeutered then return end
    tex._duiNeutered = true
    tex:SetAlpha(0)
    tex:Hide()
    tex.Show = tex.Hide
end

-- MailFrame's portrait is an unnamed region in 3.3.5a's XML.
local function findMailIcon(window)
    for _, region in ipairs({ window:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            local tex = region:GetTexture()
            if type(tex) == "string" and tex:lower():find("mail%-icon") then
                return region
            end
        end
    end
end

-- Where retail's CircleMask shows the portrait (62x62 at -5,7 inset 2,0,-2,4), under the OVERLAY ring.
local function seatPortrait(window, icon)
    if not icon then return end
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", window, "TOPLEFT", -3, 7)
    icon:SetSize(58, 58)
    icon:SetDrawLayer("ARTWORK")
end

local function dressTitle(window, label)
    if not label then return end
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", window, "TOPLEFT", 60, -5)
    label:SetPoint("TOPRIGHT", window, "TOPRIGHT", -24, -5)
    label:SetHeight(16)
    label:SetJustifyH("CENTER")
end

local function paintWindowChrome(window, closeBtn, insetBounds, portrait)
    window:SetSize(WIDTH, HEIGHT)
    if window.SetHitRectInsets then
        window:SetHitRectInsets(0, 0, 0, 0)
    end
    nudgePanel(window)
    seatPortrait(window, portrait)

    local rock = window:CreateTexture(nil, "BACKGROUND")
    rock._duiOwned = true
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", window, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -2, 2)
    window._duiRockBg = rock

    local streaks = window:CreateTexture(nil, "BORDER")
    streaks._duiOwned = true
    streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetPoint("TOPLEFT", window, "TOPLEFT", 6, -21)
    streaks:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -2, -64)
    window._duiStreaks = streaks

    applySlices(window, "PortraitFrameTemplate")

    if closeBtn then
        dressCloseButton(closeBtn, window)
    end

    local inset = CreateFrame("Frame", nil, window)
    inset:EnableMouse(false)
    inset:SetFrameLevel(window:GetFrameLevel() + 1)
    placeInset(inset, window, insetBounds or INSET_INBOX)
    applySlices(inset, "InsetFrameTemplate")

    local marble = window:CreateTexture(nil, "BORDER")
    marble._duiOwned = true
    marble:SetTexture(MARBLE, "REPEAT", "REPEAT")
    marble:SetHorizTile(true)
    marble:SetVertTile(true)
    marble:SetAllPoints(inset)
    window._duiMarble = marble
    window._duiInset = inset

    return inset
end

local function hideScrollBarBackground(scrollFrame)
    if not scrollFrame or not scrollFrame.GetRegions then return end
    for _, region in ipairs({ scrollFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            local tex = region:GetTexture()
            if type(tex) == "string" and tex:lower():find("ui%-character%-scrollbar") then
                neuterTexture(region)
            end
        end
    end
end

-- ScrollFrameTemplate's scrollBarX/TopY/BottomY; anchored to the scroll frame, it follows its resizes.
local function styleMailScrollBar(scrollFrame, ownerFrame, topY, bottomY)
    if not scrollFrame or not ownerFrame then return end
    hideScrollBarBackground(scrollFrame)
    -- Retail's ScrollBarMixin hides the thumb when nothing scrolls and keeps the track.
    scrollFrame.hideThumbWhenUnscrollable = true
    local CP = addon.CharacterPanel
    if CP and CP.ReskinScrollBar then
        CP.ReskinScrollBar(scrollFrame, ownerFrame, 83, -11, 143, true)
    end
    local bar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 10, topY)
        bar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 10, bottomY)
    end
end

local function syncMailScrollThumb(scrollFrame)
    local CP = addon.CharacterPanel
    if CP and CP.SyncScrollThumb and scrollFrame then
        CP.SyncScrollThumb(scrollFrame)
    end
end

local function place(region, point, relativeTo, relativePoint, x, y)
    if not region then return end
    region:ClearAllPoints()
    region:SetPoint(point, relativeTo, relativePoint, x, y)
end

-- Retail's Common-Input-Border layout: the left cap sits 8px out, the middle sets the visible width.
local function dressInputBorder(editBox, width, middleWidth, leftY)
    if not editBox then return end
    local name = editBox:GetName()
    local left, middle, right = _G[name .. "Left"], _G[name .. "Middle"], _G[name .. "Right"]
    if not (left and middle and right) then return end
    left:SetSize(8, 20)
    place(left, "TOPLEFT", editBox, "TOPLEFT", -8, leftY)
    middle:SetSize(middleWidth, 20)
    place(middle, "LEFT", left, "RIGHT", 0, 0)
    right:SetSize(8, 20)
    place(right, "LEFT", middle, "RIGHT", 0, 0)
    editBox:SetWidth(width)
end

-- ThinGoldEdgeTemplate, drawn with the bags' coin box: the same black plate and gold rim at 2x.
local function buildGoldEdge(parent, level)
    local edge = CreateFrame("Frame", nil, parent)
    edge:EnableMouse(false)
    edge:SetFrameLevel(level)
    local left = edge:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(COINBOX)
    left:SetTexCoord(0.03125, 0.53125, 0.289062, 0.554688)
    left:SetWidth(8)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    local right = edge:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(COINBOX)
    right:SetTexCoord(0.03125, 0.53125, 0.570312, 0.835938)
    right:SetWidth(8)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    local middle = edge:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture(COINBOX)
    middle:SetTexCoord(0, 0.5, 0.0078125, 0.273438)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    return edge
end

-- Retail's IconBorder: 37x37 centred on item buttons, over the icon (inset 0,0,-1,1) on inbox rows.
local function iconBorder(button, overIcon)
    local border = button._duiIconBorder
    if not border then
        border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture(ICON_BORDER)
        if overIcon then
            border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        else
            border:SetSize(37, 37)
            border:SetPoint("CENTER", button, "CENTER", 0, 0)
        end
        button._duiIconBorder = border
    end
    return border
end

local function showQuality(border, quality, dimmed)
    local color = quality and QUALITY_BORDER_COLORS[quality]
    if not color then
        border:Hide()
        return
    end
    if dimmed then
        border:SetVertexColor(0.5, 0.5, 0.5)
    else
        border:SetVertexColor(color[1], color[2], color[3])
    end
    border:Show()
end

local function firstAttachmentQuality(index)
    for slot = 1, ATTACHMENTS_MAX_RECEIVE do
        local name, _, _, quality = GetInboxItem(index, slot)
        if name then
            return quality
        end
    end
end

-- Retail borders each row by its first attachment and greys the border once the letter is read.
local function updateInboxBorders()
    if not IsModuleEnabled() then return end
    local inbox = _G.InboxFrame
    local perPage = _G.INBOXITEMS_TO_DISPLAY or 7
    local offset = ((inbox and inbox.pageNum or 1) - 1) * perPage
    local numItems = GetInboxNumItems() or 0
    for i = 1, perPage do
        local button = _G["MailItem" .. i .. "Button"]
        if button then
            local index = offset + i
            local quality, wasRead
            if index <= numItems then
                local _, _, _, _, _, _, _, itemCount, read = GetInboxHeaderInfo(index)
                wasRead = read
                if itemCount then
                    quality = firstAttachmentQuality(index)
                end
            end
            showQuality(iconBorder(button, true), quality, wasRead)
        end
    end
end

local function reskinSingleTab(tabName)
    local tab = _G[tabName]
    if not tab or tab._duiTabReskinned then return end
    tab._duiTabReskinned = true

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
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", TAB_LEFT_X, 0)
    end
    if right then
        right:ClearAllPoints()
        right:SetSize(37, 36)
        right:SetTexture(TAB_TEX)
        right:SetTexCoord(0.015625, 0.59375, 0.667969, 0.808594)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", TAB_RIGHT_X, 0)
    end
    if middle and left and right then
        middle:ClearAllPoints()
        middle:SetTexture(TAB_TEX)
        middle:SetTexCoord(0, 0.015625, 0.175781, 0.316406)
        middle:SetHorizTile(true)
        middle:SetHeight(36)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    end

    if leftD then
        leftD:ClearAllPoints()
        leftD:SetSize(35, 42)
        leftD:SetTexture(TAB_TEX)
        leftD:SetTexCoord(0.015625, 0.5625, 0.496094, 0.660156)
        leftD:SetPoint("TOPLEFT", tab, "TOPLEFT", TAB_ACTIVE_LEFT_X, 0)
    end
    if rightD then
        rightD:ClearAllPoints()
        rightD:SetSize(37, 42)
        rightD:SetTexture(TAB_TEX)
        rightD:SetTexCoord(0.015625, 0.59375, 0.324219, 0.488281)
        rightD:SetPoint("TOPRIGHT", tab, "TOPRIGHT", TAB_ACTIVE_RIGHT_X, 0)
    end
    if midD and leftD and rightD then
        midD:ClearAllPoints()
        midD:SetTexture(TAB_TEX)
        midD:SetTexCoord(0, 0.015625, 0.00390625, 0.16796875)
        midD:SetHorizTile(true)
        midD:SetHeight(42)
        midD:SetPoint("TOPLEFT", leftD, "TOPRIGHT")
        midD:SetPoint("TOPRIGHT", rightD, "TOPLEFT")
    end

    tab:SetHeight(TAB_H)

    local stock = tab:GetHighlightTexture()
    if stock then stock:SetTexture(nil) end

    local function glow(tc, w, anchor, point)
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(tc))
        t:SetSize(w, HL_H)
        t:SetPoint(point, anchor, point, 0, 0)
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end

    local hlLeft  = left  and glow(HL_LEFT_TC, 35, left, "TOPLEFT")
    local hlRight = right and glow(HL_RIGHT_TC, 37, right, "TOPRIGHT")
    local hlMid   = (hlLeft and hlRight) and (function()
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(HL_MIDDLE_TC))
        t:SetHorizTile(true)
        t:SetHeight(HL_H)
        t:SetPoint("TOPLEFT", hlLeft, "TOPRIGHT", 0, 0)
        t:SetPoint("TOPRIGHT", hlRight, "TOPLEFT", 0, 0)
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end)()

    tab._duiHighlight = { hlLeft, hlRight, hlMid }
    tab:SetHighlightFontObject(GameFontHighlightSmall)
end

local function syncMailTabState(tab)
    if not tab or not tab._duiTabReskinned then return end
    local name = tab:GetName()
    local activeArt = _G[name .. "MiddleDisabled"]
    local selected = activeArt and activeArt:IsShown()

    local text = _G[name .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", tab, "CENTER", 0, selected and TAB_SELECTED_TEXT_Y or TAB_TEXT_Y)
    end

    if tab._duiHighlight then
        for _, tex in ipairs(tab._duiHighlight) do
            if tex then
                tex:SetAlpha(selected and 0 or HL_ALPHA)
            end
        end
    end

    local mf = _G.MailFrame
    if mf then
        tab:SetFrameLevel((mf:GetFrameLevel() or 1) + (selected and 4 or 1))
    end

    -- The selected tab is disabled, so its label shows the disabled font: white in retail.
    local labelFont = selected and GameFontHighlightSmall or GameFontNormalSmall
    tab:SetNormalFontObject(labelFont)
    tab:SetDisabledFontObject(labelFont)
    if text then text:SetFontObject(labelFont) end
end

local function resizeMailTab(tab)
    if not tab then return end
    local text = _G[tab:GetName() .. "Text"]
    if not text then return end

    text:SetWidth(0)
    local w = (text:GetStringWidth() or 0) + TAB_SIDES_PADDING
    if w > TAB_MAX_W then
        w = TAB_MAX_W
        text:SetWidth(w - TAB_SIDES_PADDING)
    elseif w < TAB_MIN_W then
        w = TAB_MIN_W
    end
    tab:SetWidth(math_floor(w + 0.5))
    tab:SetHeight(TAB_H)
    syncMailTabState(tab)
end

local function rechainMailTabs()
    local mf = _G.MailFrame
    if not mf then return end
    local prev
    for i = 1, 2 do
        local tab = _G["MailFrameTab" .. i]
        if tab and tab:IsShown() then
            reskinSingleTab(tab:GetName())
            resizeMailTab(tab)
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
            else
                tab:SetPoint("TOPLEFT", mf, "BOTTOMLEFT", TAB_START_X, TAB_START_Y)
            end
            prev = tab
        end
    end
end

local tabResizeHooked = false
local tabSelectionHooked = false
local tabReasserting = false

local function setupMailTabHooks()
    if not tabResizeHooked and _G.PanelTemplates_TabResize then
        tabResizeHooked = true
        hooksecurefunc("PanelTemplates_TabResize", function(t)
            if tabReasserting or not t or not t._duiTabReskinned then return end
            tabReasserting = true
            rechainMailTabs()
            tabReasserting = false
        end)
    end

    if not tabSelectionHooked and _G.PanelTemplates_SelectTab then
        tabSelectionHooked = true
        local function onSelectChanged(t)
            if t and t._duiTabReskinned then
                syncMailTabState(t)
            end
        end
        hooksecurefunc("PanelTemplates_SelectTab", onSelectChanged)
        if _G.PanelTemplates_DeselectTab then
            hooksecurefunc("PanelTemplates_DeselectTab", onSelectChanged)
        end
    end

    for i = 1, 2 do
        local tab = _G["MailFrameTab" .. i]
        if tab and not tab._duiTabScriptHooked then
            tab._duiTabScriptHooked = true
            tab:HookScript("OnShow", rechainMailTabs)
            tab:HookScript("OnHide", rechainMailTabs)
        end
    end
end

local function HasPostal()
    if _G.PostalOpenAllButton then
        return true
    end
    if _G.Postal and _G.Postal.GetModule and _G.Postal:GetModule("OpenAll", true) then
        return true
    end
    if IsAddOnLoaded and (IsAddOnLoaded("Postal") or IsAddOnLoaded("Postal_OpenAll")) then
        return true
    end
    return false
end

-- Sequential mail looter that skips COD and Guild Master letters.
local openAllBtn
local openAllFrame = CreateFrame("Frame")
openAllFrame:Hide()

local STEP_DELAY = 0.05
local SERVER_TIMEOUT = 2.0

local isOpeningAll = false
local waitTimer = 0
local pending
local skipped = {}

local function CountFreeBagSlots()
    local totalFree = 0
    for bag = 0, (_G.NUM_BAG_SLOTS or 4) do
        local freeSlots, bagFamily = GetContainerNumFreeSlots(bag)
        if freeSlots and (bagFamily == 0 or bagFamily == nil) then
            totalFree = totalFree + freeSlots
        end
    end
    return totalFree
end

local function HasLootableMail()
    local numItems = GetInboxNumItems() or 0
    for i = 1, numItems do
        local _, _, _, _, money, codAmount, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(i)
        if not isGM and (codAmount or 0) == 0 and ((money or 0) > 0 or (itemCount or 0) > 0) then
            return true
        end
    end
    return false
end

local function UpdateOpenAllButtonState()
    if not openAllBtn then return end
    if HasPostal() then
        openAllBtn:Hide()
        return
    end
    openAllBtn:Show()
    if isOpeningAll then
        openAllBtn:Disable()
        openAllBtn:SetText(localized("Opening..."))
    else
        openAllBtn:Enable()
        openAllBtn:SetText(localized("Open All"))
    end
end

local function StopOpenAll()
    isOpeningAll = false
    pending = nil
    openAllFrame:Hide()
    openAllFrame:UnregisterAllEvents()
    UpdateOpenAllButtonState()
end

-- Letters have no id and indexes shift when one is deleted, so failed takes are keyed by content.
local function takeKey(sender, subject, slot, itemName)
    return (sender or "") .. "\031" .. (subject or "") .. "\031" .. (slot or "money") .. "\031" .. (itemName or "")
end

local function FindNextTake()
    for index = (GetInboxNumItems() or 0), 1, -1 do
        local _, _, sender, subject, money, codAmount, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(index)
        if not isGM and (codAmount or 0) == 0 then
            if (money or 0) > 0 then
                local key = takeKey(sender, subject)
                if not skipped[key] then
                    return "money", index, nil, money, key
                end
            end
            if (itemCount or 0) > 0 then
                for slot = ATTACHMENTS_MAX_RECEIVE, 1, -1 do
                    local itemName = GetInboxItem(index, slot)
                    if itemName then
                        local key = takeKey(sender, subject, slot, itemName)
                        if not skipped[key] then
                            return "item", index, slot, itemName, key
                        end
                    end
                end
            end
        end
    end
end

local function TakeNext()
    if not (_G.MailFrame and _G.MailFrame:IsShown()) then
        StopOpenAll()
        return
    end

    local kind, index, slot, value, key = FindNextTake()
    if not kind then
        StopOpenAll()
        local shown, total = GetInboxNumItems()
        if (total or 0) > (shown or 0) then
            CheckInbox()
        end
        return
    end
    if kind == "item" and CountFreeBagSlots() == 0 then
        StopOpenAll()
        return
    end

    pending = { kind = kind, index = index, slot = slot, value = value, key = key, timeout = SERVER_TIMEOUT }
    if kind == "money" then
        TakeInboxMoney(index)
    else
        TakeInboxItem(index, slot)
    end
end

-- Takes go from the last letter up, so deleting a finished letter never shifts the pending one.
local function PendingResolved()
    if pending.kind == "money" then
        local _, _, _, _, money = GetInboxHeaderInfo(pending.index)
        return money ~= pending.value
    end
    return GetInboxItem(pending.index, pending.slot) ~= pending.value
end

local function SkipPending()
    skipped[pending.key] = true
    pending = nil
    waitTimer = STEP_DELAY
end

openAllFrame:SetScript("OnEvent", function(_, event, message)
    if event == "MAIL_CLOSED" then
        StopOpenAll()
    elseif not pending then
        return
    elseif message == _G.ERR_INV_FULL then
        StopOpenAll()
    elseif (pending.kind == "item" and message == _G.ERR_ITEM_MAX_COUNT)
        or (pending.kind == "money" and message == _G.ERR_TOO_MUCH_GOLD) then
        SkipPending()
    end
end)

-- Polled rather than tied to MAIL_INBOX_UPDATE; a take is never resent while it may still land.
openAllFrame:SetScript("OnUpdate", function(_, elapsed)
    if pending then
        if PendingResolved() then
            pending = nil
            waitTimer = STEP_DELAY
        else
            pending.timeout = pending.timeout - elapsed
            if pending.timeout <= 0 then
                SkipPending()
            end
        end
        return
    end

    waitTimer = waitTimer - elapsed
    if waitTimer <= 0 then
        TakeNext()
    end
end)

local function StartOpenAll()
    if isOpeningAll then return end
    if not HasLootableMail() then
        UpdateOpenAllButtonState()
        return
    end

    for _, popup in ipairs({ "COD_CONFIRMATION", "COD_CONFIRMATION_AUTO_LOOT", "DELETE_MAIL", "DELETE_MONEY" }) do
        if StaticPopup_Hide then StaticPopup_Hide(popup) end
    end
    if _G.OpenMailFrame and _G.OpenMailFrame:IsShown() and HideUIPanel then
        HideUIPanel(_G.OpenMailFrame)
    end

    isOpeningAll = true
    pending = nil
    wipe(skipped)
    waitTimer = 0

    openAllFrame:RegisterEvent("UI_ERROR_MESSAGE")
    openAllFrame:RegisterEvent("MAIL_CLOSED")
    UpdateOpenAllButtonState()
    openAllFrame:Show()
end

local function afterSendMailUpdate()
    if not IsModuleEnabled() then return end
    local sendFrame = _G.SendMailFrame
    local first = _G.SendMailAttachment1
    if not (sendFrame and first) then return end

    local ranks = sendFrame.maxRowsShown or 1
    local width = sendFrame:GetWidth() - 14
    local iconX, iconY = first:GetWidth() + 2, first:GetHeight() + 2
    local gapX1 = math_floor((width - iconX * ATTACHMENTS_PER_ROW_SEND) / (ATTACHMENTS_PER_ROW_SEND - 1))
    local gapX2 = math_floor((width - iconX * ATTACHMENTS_PER_ROW_SEND - gapX1 * (ATTACHMENTS_PER_ROW_SEND - 1)) / 2)
    local gapY1, gapY2 = 5, 6
    local height = gapY2 * 2 + gapY1 * (ranks - 1) + iconY * ranks
    local indentX = 14 + gapX2
    local indentY = 170 - RETAIL_DROP + gapY2 + iconY
    local stepX = iconX + gapX1 - 2
    local stepY = iconY + gapY1
    local scrollHeight = 249 - height

    if _G.SendMailScrollFrame then
        _G.SendMailScrollFrame:SetHeight(scrollHeight)
    end
    if _G.SendMailScrollChildFrame then
        _G.SendMailScrollChildFrame:SetHeight(scrollHeight)
    end
    if _G.SendMailHorizontalBarLeft2 then
        _G.SendMailHorizontalBarLeft2:ClearAllPoints()
        _G.SendMailHorizontalBarLeft2:SetPoint("TOPLEFT", sendFrame, "BOTTOMLEFT", 2, 184 - RETAIL_DROP + height)
    end
    if _G.SendStationeryBackgroundLeft then
        _G.SendStationeryBackgroundLeft:SetHeight(math_min(scrollHeight, 256))
        _G.SendStationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    if _G.SendStationeryBackgroundRight then
        _G.SendStationeryBackgroundRight:SetHeight(math_min(scrollHeight, 256))
        _G.SendStationeryBackgroundRight:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    syncMailScrollThumb(_G.SendMailScrollFrame)

    for i = 1, ATTACHMENTS_MAX_SEND do
        local btn = _G["SendMailAttachment" .. i]
        if btn then
            local name, _, _, quality = GetSendMailItem(i)
            showQuality(iconBorder(btn), name and quality)
        end
    end

    local cx, cy = 0, ranks - 1
    for i = 1, ATTACHMENTS_MAX_SEND do
        local btn = _G["SendMailAttachment" .. i]
        if btn and cy >= 0 then
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", sendFrame, "BOTTOMLEFT", indentX + stepX * cx, indentY + stepY * cy)
            cx = cx + 1
            if cx >= ATTACHMENTS_PER_ROW_SEND then
                cy = cy - 1
                cx = 0
            end
        end
    end
end

local function afterOpenMailUpdate()
    if not IsModuleEnabled() then return end
    local openFrame = _G.OpenMailFrame
    local inbox = _G.InboxFrame
    local id = inbox and inbox.openMailID
    if not (openFrame and id and id > 0) then return end

    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local btn = _G["OpenMailAttachmentButton" .. i]
        if btn then
            local name, _, _, quality = GetInboxItem(id, i)
            showQuality(iconBorder(btn), name and quality)
        end
    end

    local sender = _G.OpenMailSender
    if sender and _G.OpenMailSenderLabel then
        sender:ClearAllPoints()
        sender:SetPoint("TOPLEFT", _G.OpenMailSenderLabel, "TOPRIGHT", 5, 0)
        if _G.OpenMailReportSpamButton and _G.OpenMailReportSpamButton:IsShown() then
            sender:SetPoint("BOTTOMRIGHT", _G.OpenMailReportSpamButton, "BOTTOMLEFT", -5, 0)
        else
            sender:SetPoint("BOTTOMRIGHT", openFrame, "TOPRIGHT", -12, -54)
        end
    end

    local first = _G.OpenMailAttachmentButton1
    local attachText = _G.OpenMailAttachmentText
    if not (first and attachText) then return end

    local ranks = openFrame.activeAttachmentRowPositions and #openFrame.activeAttachmentRowPositions or 0
    local width = openFrame:GetWidth() - 14 - 47
    local iconX, iconY = first:GetWidth() + 2, first:GetHeight() + 2
    local gapX1 = math_floor((width - iconX * ATTACHMENTS_PER_ROW_RECEIVE) / (ATTACHMENTS_PER_ROW_RECEIVE - 1))
    local gapX2 = math_floor((width - iconX * ATTACHMENTS_PER_ROW_RECEIVE - gapX1 * (ATTACHMENTS_PER_ROW_RECEIVE - 1)) / 2)
    local gapY1, gapY2 = 3, 3
    local textH = attachText:GetHeight() or 12
    local height = gapY2 + textH + gapY2 + iconY * ranks + gapY1 * (ranks - 1) + gapY2
    local indentX = 14 + gapX2
    local indentY = 28 + gapY2
    local stepX = iconX + gapX1 + 6
    local stepY = iconY + gapY1
    local scrollHeight = 305 - height
    if scrollHeight > 256 then
        scrollHeight = 256
        height = 305 - scrollHeight
    end

    if _G.OpenMailScrollFrame then
        _G.OpenMailScrollFrame:SetHeight(scrollHeight)
    end
    if _G.OpenMailScrollChildFrame then
        _G.OpenMailScrollChildFrame:SetHeight(scrollHeight)
    end
    if _G.OpenMailHorizontalBarLeft then
        _G.OpenMailHorizontalBarLeft:ClearAllPoints()
        _G.OpenMailHorizontalBarLeft:SetPoint("TOPLEFT", openFrame, "BOTTOMLEFT", 2, 39 + height)
    end
    if _G.OpenStationeryBackgroundLeft then
        _G.OpenStationeryBackgroundLeft:SetHeight(scrollHeight)
        _G.OpenStationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    if _G.OpenStationeryBackgroundRight then
        _G.OpenStationeryBackgroundRight:SetHeight(scrollHeight)
        _G.OpenStationeryBackgroundRight:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    syncMailScrollThumb(_G.OpenMailScrollFrame)

    attachText:ClearAllPoints()
    if (openFrame.itemButtonCount or 0) > 0 then
        attachText:SetPoint("TOPLEFT", openFrame, "BOTTOMLEFT", indentX,
            indentY + iconY * ranks + gapY1 * (ranks - 1) + gapY2 + textH)
    else
        attachText:SetPoint("TOPLEFT", openFrame, "BOTTOMLEFT",
            14 + (width - attachText:GetWidth()) / 2,
            indentY + (height - textH) / 2 + textH)
    end

    if ranks > 0 and openFrame.activeAttachmentButtons then
        local rowIndex = 1
        local cx = openFrame.activeAttachmentRowPositions[1].cursorxstart
        local cxEnd = openFrame.activeAttachmentRowPositions[1].cursorxend
        local cy = ranks - 1
        for _, btn in ipairs(openFrame.activeAttachmentButtons) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", openFrame, "BOTTOMLEFT", indentX + stepX * cx, indentY + iconY + stepY * cy)
            cx = cx + 1
            if cx > cxEnd then
                rowIndex = rowIndex + 1
                cy = cy - 1
                if rowIndex <= ranks then
                    cx = openFrame.activeAttachmentRowPositions[rowIndex].cursorxstart
                    cxEnd = openFrame.activeAttachmentRowPositions[rowIndex].cursorxend
                end
            end
        end
    end
end

local function hideMailChromePieces()
    for _, name in ipairs({
        "MailFrameTopLeft", "MailFrameTopRight", "MailFrameBotLeft", "MailFrameBotRight",
    }) do
        local tex = _G[name]
        if tex then
            neuterTexture(tex)
        end
    end
end

-- Our raised SendMailFrame takes the mouse (drop-to-attach), so addon buttons left on MailFrame went dead.
local function liftForeignChildren(mailFrame)
    local inbox, send = _G.InboxFrame, _G.SendMailFrame
    local top = math.max(inbox and inbox:GetFrameLevel() or 0, send and send:GetFrameLevel() or 0)
    for _, child in ipairs({ mailFrame:GetChildren() }) do
        if child ~= inbox and child ~= send and child ~= mailFrame._duiInset
            and child ~= _G.MailFrameTab1 and child ~= _G.MailFrameTab2 and child:GetFrameLevel() <= top then
            child:SetFrameLevel(top + 2)
            liftChildren(child)
        end
    end
end

local function postalModuleEnabled(name)
    local module = _G.Postal and _G.Postal.GetModule and _G.Postal:GetModule(name, true)
    return module and module.IsEnabled and module:IsEnabled() and true or false
end

-- Postal anchors these for Blizzard's 384x512 frame; on ours they sat over the parchment edge.
local function fitPostal()
    if _G.InboxCloseButton then
        place(_G.Postal_ModuleMenuButton, "RIGHT", _G.InboxCloseButton, "LEFT", 0, 0)
    end
    local inbox = _G.InboxFrame
    local headerY = (INSET_INBOX[2] - 21) / 2 - 2
    -- Shifted right to clear the portrait ring, the spacing Postal gets on Blizzard's frame.
    place(_G.PostalSelectOpenButton, "RIGHT", inbox, "TOP", 13, headerY)
    place(_G.PostalSelectReturnButton, "LEFT", inbox, "TOP", 18, headerY)
    if _G.Postal then
        -- Postal's Select re-anchors MailItem1 on enable/disable, indented 20 px for its checkboxes.
        place(_G.MailItem1, "TOPLEFT", inbox, "TOPLEFT", postalModuleEnabled("Select") and 33 or 13, -68)
        -- Blizzard's 264 px between arrow centres, which Postal's Open All offsets assume.
        place(_G.InboxPrevPageButton, "BOTTOMLEFT", inbox, "BOTTOMLEFT", 21, 13)
        place(_G.InboxNextPageButton, "BOTTOMRIGHT", inbox, "BOTTOMRIGHT", -21, 13)
        -- Button and menu arrow centred between the page arrows (frFR shifted in Postal too).
        place(_G.PostalOpenAllButton, "CENTER", inbox, "BOTTOM", GetLocale() == "frFR" and -22 or -12, 27)
    end
end

local function syncMailTabView()
    local mailFrame = _G.MailFrame
    if not mailFrame or not mailFrame._duiInset then return end
    hideMailChromePieces()
    liftForeignChildren(mailFrame)
    fitPostal()
    local selected = (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(mailFrame))
        or mailFrame.selectedTab or 1
    placeInset(mailFrame._duiInset, mailFrame, selected == 2 and INSET_SEND or INSET_INBOX)
    rechainMailTabs()
end

local function buildMailFrame()
    local mailFrame = _G.MailFrame
    if not mailFrame or mailFrame._duiSkinned then return end
    mailFrame._duiSkinned = true

    hideMailChromePieces()

    -- Pre-rounded HD portrait; without that file, SetPortraitToTexture cuts the client's icon to a circle.
    local mailIcon = findMailIcon(mailFrame)
    if mailIcon and not mailIcon:SetTexture(MAIL_ICON_HD) and SetPortraitToTexture then
        SetPortraitToTexture(mailIcon, MAIL_ICON)
    end
    local inset = paintWindowChrome(mailFrame, _G.InboxCloseButton, INSET_INBOX, mailIcon)

    local inbox = _G.InboxFrame
    if inbox then
        inbox:ClearAllPoints()
        inbox:SetAllPoints(mailFrame)
        inbox:SetSize(WIDTH, HEIGHT)
        inbox:SetFrameLevel(inset:GetFrameLevel() + 2)

        local bg = inbox:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(INBOX_BG)
        bg:SetSize(512, 512)
        bg:SetPoint("TOPLEFT", inbox, "TOPLEFT", 7, -62)
        inbox._duiBg = bg

        dressTitle(mailFrame, _G.InboxTitleText)
        place(_G.InboxTooMuchMail, "TOP", inbox, "TOP", 0, -25)
        if _G.InboxCurrentPage then
            neuterTexture(_G.InboxCurrentPage)
        end
        place(_G.MailItem1, "TOPLEFT", inbox, "TOPLEFT", 13, -70)
        place(_G.InboxPrevPageButton, "BOTTOMLEFT", inbox, "BOTTOMLEFT", 14, 10)
        place(_G.InboxNextPageButton, "BOTTOMRIGHT", inbox, "BOTTOMRIGHT", -14, 10)

        if not openAllBtn then
            openAllBtn = CreateFrame("Button", "DragonUIOpenAllMailButton", inbox, "UIPanelButtonTemplate")
            skinActionButton(openAllBtn, 120, 24)
            openAllBtn:SetPoint("CENTER", inbox, "BOTTOM", 0, 26)
            openAllBtn:SetText(localized("Open All"))
            openAllBtn:SetScript("OnClick", StartOpenAll)
            -- Like retail's OpenAllMailMixin: leaving the inbox (tab switch, close) ends the run.
            openAllBtn:SetScript("OnHide", function()
                if isOpeningAll then
                    StopOpenAll()
                end
            end)
        end

        liftChildren(inbox)
    end

    local sendFrame = _G.SendMailFrame
    if sendFrame then
        sendFrame:ClearAllPoints()
        sendFrame:SetAllPoints(mailFrame)
        sendFrame:SetSize(WIDTH, HEIGHT)
        sendFrame:SetFrameLevel(inset:GetFrameLevel() + 2)
        local level = sendFrame:GetFrameLevel()

        dressTitle(mailFrame, _G.SendMailTitleText)
        place(_G.SendMailHorizontalBarLeft, "TOPLEFT", sendFrame, "TOPLEFT", 2, -337)

        local nameBox, subjectBox = _G.SendMailNameEditBox, _G.SendMailSubjectEditBox
        if nameBox then
            nameBox:SetHeight(25)
            place(nameBox, "TOPLEFT", sendFrame, "TOPLEFT", 90, -30)
            dressInputBorder(nameBox, 109, 100, -2)
        end
        if subjectBox and nameBox then
            subjectBox:SetHeight(20)
            place(subjectBox, "TOPLEFT", nameBox, "BOTTOMLEFT", 0, 0)
            dressInputBorder(subjectBox, 220, 221, 0)
        end
        place(_G.SendMailCostMoneyFrame, "TOPRIGHT", sendFrame, "TOPRIGHT", RETAIL_WIDEN - 50, -34)

        if _G.SendMailScrollFrame then
            place(_G.SendMailScrollFrame, "TOPLEFT", sendFrame, "TOPLEFT", 8, -83)
            styleMailScrollBar(_G.SendMailScrollFrame, sendFrame, -4, 3)
        end

        place(_G.SendMailMoneyButton, "BOTTOMLEFT", sendFrame, "BOTTOMLEFT", 15, 125 - RETAIL_DROP)
        if _G.SendMailMoney then
            place(_G.SendMailSendMoneyButton, "TOPLEFT", _G.SendMailMoney, "TOPRIGHT", 20, 12)
        end

        local moneyInset = CreateFrame("Frame", nil, sendFrame)
        moneyInset:EnableMouse(false)
        moneyInset:SetFrameLevel(level + 1)
        moneyInset:SetPoint("BOTTOMLEFT", sendFrame, "BOTTOMLEFT", 4, 92 - RETAIL_DROP)
        moneyInset:SetPoint("TOPRIGHT", sendFrame, "BOTTOMLEFT", 170, 115 - RETAIL_DROP)
        applySlices(moneyInset, "InsetFrameTemplate")
        local moneyMarble = sendFrame:CreateTexture(nil, "BACKGROUND")
        moneyMarble:SetTexture(MARBLE, "REPEAT", "REPEAT")
        moneyMarble:SetHorizTile(true)
        moneyMarble:SetVertTile(true)
        moneyMarble:SetAllPoints(moneyInset)

        local moneyBg = buildGoldEdge(sendFrame, level + 2)
        moneyBg:SetPoint("BOTTOMLEFT", sendFrame, "BOTTOMLEFT", 7, 94 - RETAIL_DROP)
        moneyBg:SetPoint("TOPRIGHT", sendFrame, "BOTTOMLEFT", 166, 113 - RETAIL_DROP)

        -- SmallMoneyFrameTemplate parks the copper coin 13px inside its right edge: 5px clear of the rim.
        if _G.SendMailMoneyFrame then
            place(_G.SendMailMoneyFrame, "RIGHT", moneyBg, "RIGHT", 8, 0)
            _G.SendMailMoneyFrame:SetFrameLevel(level + 3)
            if addon.RegisterBlizzardMoneyFrame then
                addon.RegisterBlizzardMoneyFrame(_G.SendMailMoneyFrame)
            end
        end

        if _G.SendMailCancelButton then
            place(_G.SendMailCancelButton, "BOTTOMRIGHT", sendFrame, "BOTTOMRIGHT", RETAIL_WIDEN - 53, 92 - RETAIL_DROP)
            skinActionButton(_G.SendMailCancelButton, 80, 22)
        end
        if _G.SendMailMailButton and _G.SendMailCancelButton then
            place(_G.SendMailMailButton, "RIGHT", _G.SendMailCancelButton, "LEFT", 0, 0)
            skinActionButton(_G.SendMailMailButton, 80, 22)
        end

        for i = 1, ATTACHMENTS_MAX do
            local btn = _G["SendMailAttachment" .. i]
            if btn and btn.GetRegions then
                for _, r in ipairs({ btn:GetRegions() }) do
                    if r.GetObjectType and r:GetObjectType() == "Texture" and r:GetDrawLayer() == "BACKGROUND" then
                        r:ClearAllPoints()
                        r:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
                    end
                end
            end
        end

        liftChildren(sendFrame)

        if _G.SendMailFrame_Update and not sendFrame._duiSendHooked then
            sendFrame._duiSendHooked = true
            hooksecurefunc("SendMailFrame_Update", afterSendMailUpdate)
        end
        afterSendMailUpdate()
    end

    setupMailTabHooks()
    rechainMailTabs()

    local openFrame = _G.OpenMailFrame
    if openFrame and not openFrame._duiSkinned then
        openFrame._duiSkinned = true

        for _, name in ipairs({
            "OpenMailFrameTopLeft", "OpenMailFrameTopRight", "OpenMailFrameBotLeft", "OpenMailFrameBotRight",
        }) do
            neuterTexture(_G[name])
        end

        local openInset = paintWindowChrome(openFrame, _G.OpenMailCloseButton, INSET_OPEN, _G.OpenMailFrameIcon)
        place(openFrame, "TOPLEFT", mailFrame, "TOPRIGHT", RETAIL_WIDEN, 0)

        dressTitle(openFrame, _G.OpenMailTitleText)
        place(_G.OpenMailSenderLabel, "TOPRIGHT", openFrame, "TOPLEFT", 105, -33)
        place(_G.OpenMailSubjectLabel, "TOPRIGHT", openFrame, "TOPLEFT", 105, -55)
        if _G.OpenMailSender then
            _G.OpenMailSender:SetJustifyH("LEFT")
        end
        if _G.OpenMailReportSpamButton then
            place(_G.OpenMailReportSpamButton, "TOPRIGHT", openFrame, "TOPRIGHT", -12, -32)
            skinActionButton(_G.OpenMailReportSpamButton, 110, 22)
        end

        if _G.OpenMailScrollFrame then
            place(_G.OpenMailScrollFrame, "TOPLEFT", openFrame, "TOPLEFT", 8, -84)
            styleMailScrollBar(_G.OpenMailScrollFrame, openFrame, -3, 5)
        end

        if _G.OpenMailCancelButton then
            place(_G.OpenMailCancelButton, "BOTTOMRIGHT", openFrame, "BOTTOMRIGHT", -6, 4)
            skinActionButton(_G.OpenMailCancelButton, 80, 22)
        end
        if _G.OpenMailDeleteButton and _G.OpenMailCancelButton then
            place(_G.OpenMailDeleteButton, "RIGHT", _G.OpenMailCancelButton, "LEFT", 0, 0)
            skinActionButton(_G.OpenMailDeleteButton, 82, 22)
        end
        if _G.OpenMailReplyButton and _G.OpenMailDeleteButton then
            place(_G.OpenMailReplyButton, "RIGHT", _G.OpenMailDeleteButton, "LEFT", 0, 0)
            skinActionButton(_G.OpenMailReplyButton, 82, 22)
        end

        for _, child in ipairs({ openFrame:GetChildren() }) do
            if child ~= openInset and child ~= _G.OpenMailCloseButton
                and child:GetFrameLevel() <= openInset:GetFrameLevel() then
                child:SetFrameLevel(openInset:GetFrameLevel() + 2)
            end
        end
        liftChildren(openFrame)

        openFrame:HookScript("OnShow", function()
            if isOpeningAll then
                StopOpenAll()
            end
            afterOpenMailUpdate()
        end)

        if _G.OpenMail_Update and not openFrame._duiOpenHooked then
            openFrame._duiOpenHooked = true
            hooksecurefunc("OpenMail_Update", afterOpenMailUpdate)
        end
    end

    if _G.InboxFrame_Update and not mailFrame._duiInboxHooked then
        mailFrame._duiInboxHooked = true
        hooksecurefunc("InboxFrame_Update", updateInboxBorders)
    end

    if _G.MailFrameTab_OnClick and not mailFrame._duiTabHooked then
        mailFrame._duiTabHooked = true
        hooksecurefunc("MailFrameTab_OnClick", function()
            if not IsModuleEnabled() then return end
            syncMailTabView()
        end)
    end

    syncMailTabView()
end

function addon.ApplyMailSystem()
    if not IsModuleEnabled() then return end
    MailModule.initialized = true
    MailModule.applied = true
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("mail_apply", buildMailFrame)
        return
    end
    buildMailFrame()
    UpdateOpenAllButtonState()
end

function addon.RestoreMailSystem()
    StopOpenAll()
    MailModule.applied = false
end

function addon.RefreshMailSystem()
    if IsModuleEnabled() then
        addon.ApplyMailSystem()
    else
        addon.RestoreMailSystem()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("MAIL_SHOW")
boot:SetScript("OnEvent", function(_, event)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_LOGIN" then
        addon.ApplyMailSystem()
    elseif event == "MAIL_SHOW" then
        buildMailFrame()
        syncMailTabView()
        UpdateOpenAllButtonState()
    end
end)
