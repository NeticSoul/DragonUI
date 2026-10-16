-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local unpack = unpack
local type = type
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local GetInboxNumItems = GetInboxNumItems
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxItem = GetInboxItem
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
local REDBUTTON = DIR .. "UI\\redbutton2x"
local PAGE_BG = DIR .. "Merchant\\pagebutton-background"
local PAGE_HILITE = DIR .. "Merchant\\pagebutton-hover"
local TAB_TEX = DIR .. "UI\\uiframetabs"
local PAGE_BTN_TEX = {
    InboxPrevPageButton = {
        up = DIR .. "Merchant\\pagebutton-prev-normal",
        down = DIR .. "Merchant\\pagebutton-prev-pressed",
        disabled = DIR .. "Merchant\\pagebutton-prev-disabled",
    },
    InboxNextPageButton = {
        up = DIR .. "Merchant\\pagebutton-next-normal",
        down = DIR .. "Merchant\\pagebutton-next-pressed",
        disabled = DIR .. "Merchant\\pagebutton-next-disabled",
    },
}

local WIDTH, HEIGHT = 338, 424
local INSET_INBOX = { 4, -60, -6, 4 }
local INSET_SEND  = { 4, -80, -6, 28 }
local INSET_OPEN  = { 4, -80, -6, 28 }
local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 7, -63, 321, 354
local PANEL_X_NUDGE = 6
local ATTACHMENTS_MAX = _G.ATTACHMENTS_MAX or 16
local ATTACHMENTS_MAX_RECEIVE = _G.ATTACHMENTS_MAX_RECEIVE or 16
local ATTACHMENTS_PER_ROW_RECEIVE = _G.ATTACHMENTS_PER_ROW_RECEIVE or 7
local ATTACHMENTS_MAX_SEND = _G.ATTACHMENTS_MAX_SEND or 12
local ATTACHMENTS_PER_ROW_SEND = _G.ATTACHMENTS_PER_ROW_SEND or 7

local TAB_H = 32
local CAP_OVERHANG = 5
local ACTIVE_OVERHANG_L, ACTIVE_OVERHANG_R = 4, 6
local TAB_TEXT_PAD = 30
local TAB_MIN_W = 62
local HL_ALPHA, HL_H = 0.4, 30
local HL_LEFT_TC   = { 0.015625, 0.5625, 0.816406, 0.933594 }
local HL_RIGHT_TC  = { 0.015625, 0.59375, 0.667969, 0.785156 }
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }
local TEXT_ACTIVE_DROP = -7
local TEXT_NUDGE_X = -2
local TAB_START_X = 11
local TAB_GAP = 1

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

local function neuterTexture(tex)
    if not tex or tex._duiNeutered then return end
    tex._duiNeutered = true
    tex:SetAlpha(0)
    tex:Hide()
    tex.Show = tex.Hide
end

local function hideMailIcons(window)
    if not window or not window.GetRegions then return end
    for _, region in ipairs({ window:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not region._duiOwned then
            local tex = region:GetTexture()
            if type(tex) == "string" and tex:lower():find("mail%-icon") then
                neuterTexture(region)
            end
        end
    end
end

local function paintWindowChrome(window, closeBtn, insetBounds)
    window:SetSize(WIDTH, HEIGHT)
    if window.SetHitRectInsets then
        window:SetHitRectInsets(0, 0, 0, 0)
    end
    nudgePanel(window)
    hideMailIcons(window)

    local rock = window:CreateTexture(nil, "BACKGROUND", nil, -6)
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
    streaks:SetPoint("TOPLEFT", window, "TOPLEFT", 2, -21)
    streaks:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -2, -64)
    window._duiStreaks = streaks

    applySlices(window, "NoPortraitFrameTemplate")

    if closeBtn then
        dressCloseButton(closeBtn, window)
    end

    local inset = CreateFrame("Frame", nil, window)
    inset:EnableMouse(false)
    inset:SetFrameLevel(window:GetFrameLevel())
    placeInset(inset, window, insetBounds or INSET_INBOX)
    applySlices(inset, "InsetFrameTemplate")

    local marble = window:CreateTexture(nil, "BORDER")
    marble._duiOwned = true
    marble:SetTexture(MARBLE)
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

local function styleMailScrollBar(scrollFrame, ownerFrame)
    if not scrollFrame or not ownerFrame then return end
    hideScrollBarBackground(scrollFrame)
    local CP = addon.CharacterPanel
    if CP and CP.ReskinScrollBar then
        CP.ReskinScrollBar(scrollFrame, ownerFrame, 83, -11, 143, true)
    end
    local bar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if bar then
        -- Anchor top and bottom to scrollFrame so dynamic height updates keep the bar aligned.
        bar:ClearAllPoints()
        bar:SetPoint("TOP", scrollFrame, "TOP", 0, -7)
        bar:SetPoint("BOTTOM", scrollFrame, "BOTTOM", 0, 7)
        bar:SetPoint("RIGHT", ownerFrame, "RIGHT", -13, 0)
    end
end

local function syncMailScrollThumb(scrollFrame)
    local CP = addon.CharacterPanel
    if CP and CP.SyncScrollThumb and scrollFrame then
        CP.SyncScrollThumb(scrollFrame)
    end
end

local function clampHorizontalBars(parentFrame)
    if not parentFrame or not parentFrame.GetRegions then return end
    for _, region in ipairs({ parentFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not region:GetName() then
            local tex = region:GetTexture()
            if type(tex) == "string" and tex:lower():find("ui%-classtrainer%-horizontalbar") then
                region:SetWidth(68)
            end
        end
    end
end

local function stretchEditBoxBorder(editBox)
    if not editBox or not editBox.GetName then return end
    local name = editBox:GetName()
    local left = _G[name .. "Left"]
    local middle = _G[name .. "Middle"]
    local right = _G[name .. "Right"]
    if left and middle and right then
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", 0, 0)
        middle:ClearAllPoints()
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    end
end

local function reskinPageNav(btnName)
    local btn = _G[btnName]
    local set = PAGE_BTN_TEX[btnName]
    if not (btn and set) then return end

    btn:SetSize(28, 28)

    if not btn._duiPageBg then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(PAGE_BG)
        bg:SetAllPoints(btn)
        btn._duiPageBg = bg
    end

    btn:SetNormalTexture(set.up)
    btn:SetPushedTexture(set.down)
    btn:SetDisabledTexture(set.disabled)
    btn:SetHighlightTexture(PAGE_HILITE, "ADD")
    local hl = btn:GetHighlightTexture()
    if hl then
        hl:SetBlendMode("ADD")
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

    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)
    tab:SetDisabledFontObject(GameFontNormalSmall)
end

local function syncMailTabState(tab)
    if not tab or not tab._duiTabReskinned then return end
    local name = tab:GetName()
    local activeArt = _G[name .. "MiddleDisabled"]
    local selected = activeArt and activeArt:IsShown()

    local text = _G[name .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", tab, "CENTER", TEXT_NUDGE_X, selected and TEXT_ACTIVE_DROP or 0)
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

    tab:SetDisabledFontObject(GameFontNormalSmall)
end

local function resizeMailTab(tab)
    if not tab then return end
    local text = _G[tab:GetName() .. "Text"]
    if not text then return end

    -- Clear FriendsFrameTabTemplate 88px clamp so localized labels never truncate.
    text:SetWidth(0)
    local w = math_max(TAB_MIN_W, (text:GetStringWidth() or 0) + TAB_TEXT_PAD)
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
                tab:SetPoint("TOPLEFT", mf, "BOTTOMLEFT", TAB_START_X, 2)
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

local isOpeningAll = false
local currentMailIndex = 0
local currentAttachIndex = 0
local lastInboxCount = 0
local waitTimer = 0
local WAIT_DELAY = 0.15

local waitingForServer = false
local serverTimeout = 0
local SERVER_TIMEOUT_DELAY = 1.0
local retryCount = 0
local MAX_RETRIES = 3
local lastActionType = nil
local lastActionSlot = nil
local lastMoneyAmount = nil
local skippedSlots = {}

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
        local _, _, _, _, money, codAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(i)
        if not isGM and (not codAmount or codAmount == 0) then
            if (money and money > 0) or (hasItem and hasItem > 0) then
                return true
            end
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
        openAllBtn:SetText(localized("Open All"))
        if HasLootableMail() then
            openAllBtn:Enable()
        else
            openAllBtn:Disable()
        end
    end
end

local function StopOpenAll(reasonMsg)
    isOpeningAll = false
    openAllFrame:Hide()
    openAllFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    openAllFrame:UnregisterEvent("MAIL_INBOX_UPDATE")
    openAllFrame:UnregisterEvent("MAIL_CLOSED")
    waitingForServer = false
    currentMailIndex = 0
    currentAttachIndex = 0
    retryCount = 0
    lastActionType = nil
    lastActionSlot = nil
    lastMoneyAmount = nil
    waitTimer = 0
    UpdateOpenAllButtonState()
    if reasonMsg and addon.Print then
        addon:Print(reasonMsg)
    end
end

local function ProcessNextMailAction()
    if not _G.MailFrame or not _G.MailFrame:IsShown() then
        StopOpenAll()
        return
    end

    local numItems = GetInboxNumItems() or 0
    if numItems ~= lastInboxCount then
        lastInboxCount = numItems
        if currentMailIndex > numItems then
            currentMailIndex = numItems
            currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
            retryCount = 0
        end
    end

    while currentMailIndex >= 1 do
        local _, _, _, _, money, codAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(currentMailIndex)

        if isGM or (codAmount and codAmount > 0) then
            currentMailIndex = currentMailIndex - 1
            currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
            retryCount = 0
        else
            if money and money > 0 and retryCount < MAX_RETRIES then
                waitingForServer = true
                serverTimeout = SERVER_TIMEOUT_DELAY
                lastActionType = "money"
                lastMoneyAmount = money
                waitTimer = WAIT_DELAY
                TakeInboxMoney(currentMailIndex)
                return
            end

            if hasItem and hasItem > 0 then
                while currentAttachIndex >= 1 do
                    local slotKey = currentMailIndex .. "_" .. currentAttachIndex
                    if not skippedSlots[slotKey] then
                        local itemName = GetInboxItem(currentMailIndex, currentAttachIndex)
                        if itemName then
                            if CountFreeBagSlots() == 0 then
                                StopOpenAll(localized("Inventory is full."))
                                return
                            end
                            waitingForServer = true
                            serverTimeout = SERVER_TIMEOUT_DELAY
                            lastActionType = "item"
                            lastActionSlot = currentAttachIndex
                            waitTimer = WAIT_DELAY
                            TakeInboxItem(currentMailIndex, currentAttachIndex)
                            return
                        end
                    end
                    currentAttachIndex = currentAttachIndex - 1
                    retryCount = 0
                end
            end

            currentMailIndex = currentMailIndex - 1
            currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
            retryCount = 0
        end
    end

    CheckInbox()
    StopOpenAll()
end

openAllFrame:SetScript("OnEvent", function(_, event, message)
    if not isOpeningAll then return end
    if event == "MAIL_CLOSED" then
        StopOpenAll()
    elseif event == "UI_ERROR_MESSAGE" then
        if message == _G.ERR_INV_FULL then
            StopOpenAll(localized("Inventory is full."))
        elseif message == _G.ERR_ITEM_MAX_COUNT then
            if lastActionType == "item" and lastActionSlot then
                skippedSlots[currentMailIndex .. "_" .. lastActionSlot] = true
            end
            waitingForServer = false
            currentAttachIndex = currentAttachIndex - 1
            retryCount = 0
            waitTimer = 0.05
        end
    elseif event == "MAIL_INBOX_UPDATE" then
        if waitingForServer then
            if lastActionType == "money" then
                local _, _, _, _, money = GetInboxHeaderInfo(currentMailIndex)
                if not money or money == 0 or money ~= lastMoneyAmount then
                    waitingForServer = false
                    retryCount = 0
                    waitTimer = 0.05
                end
            elseif lastActionType == "item" and lastActionSlot then
                local itemName = GetInboxItem(currentMailIndex, lastActionSlot)
                if not itemName then
                    waitingForServer = false
                    currentAttachIndex = currentAttachIndex - 1
                    retryCount = 0
                    waitTimer = 0.05
                end
            end
        end
    end
end)

openAllFrame:SetScript("OnUpdate", function(_, elapsed)
    if not isOpeningAll then
        openAllFrame:Hide()
        return
    end

    if waitingForServer then
        serverTimeout = serverTimeout - elapsed
        if serverTimeout <= 0 then
            waitingForServer = false
            retryCount = retryCount + 1
            if retryCount >= MAX_RETRIES then
                if lastActionType == "item" and lastActionSlot then
                    skippedSlots[currentMailIndex .. "_" .. lastActionSlot] = true
                    currentAttachIndex = currentAttachIndex - 1
                end
                retryCount = 0
            end
            waitTimer = WAIT_DELAY
        end
        return
    end

    waitTimer = waitTimer - elapsed
    if waitTimer <= 0 then
        waitTimer = WAIT_DELAY
        ProcessNextMailAction()
    end
end)

local function StartOpenAll()
    if isOpeningAll then return end
    local numItems = GetInboxNumItems() or 0
    if numItems == 0 or not HasLootableMail() then
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
    waitingForServer = false
    serverTimeout = 0
    retryCount = 0
    lastActionType = nil
    lastActionSlot = nil
    lastMoneyAmount = nil
    skippedSlots = {}
    lastInboxCount = numItems
    currentMailIndex = numItems
    currentAttachIndex = ATTACHMENTS_MAX_RECEIVE
    waitTimer = 0

    openAllFrame:RegisterEvent("UI_ERROR_MESSAGE")
    openAllFrame:RegisterEvent("MAIL_INBOX_UPDATE")
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
    local indentY = 82 + gapY2 + iconY
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
        _G.SendMailHorizontalBarLeft2:SetPoint("TOPLEFT", sendFrame, "BOTTOMLEFT", 4, 96 + height)
    end
    if _G.SendStationeryBackgroundLeft then
        _G.SendStationeryBackgroundLeft:SetWidth(256)
        _G.SendStationeryBackgroundLeft:SetHeight(math_min(scrollHeight, 256))
        _G.SendStationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    if _G.SendStationeryBackgroundRight then
        _G.SendStationeryBackgroundRight:SetWidth(68)
        _G.SendStationeryBackgroundRight:SetHeight(math_min(scrollHeight, 256))
        _G.SendStationeryBackgroundRight:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    syncMailScrollThumb(_G.SendMailScrollFrame)

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

    if _G.OpenMailFrameIcon then
        neuterTexture(_G.OpenMailFrameIcon)
    end

    local sender = _G.OpenMailSender
    if sender and _G.OpenMailSenderLabel then
        sender:ClearAllPoints()
        sender:SetPoint("LEFT", _G.OpenMailSenderLabel, "RIGHT", 6, 0)
        if _G.OpenMailReportSpamButton and _G.OpenMailReportSpamButton:IsShown() then
            sender:SetPoint("RIGHT", _G.OpenMailReportSpamButton, "LEFT", -6, 0)
        else
            sender:SetPoint("RIGHT", openFrame, "RIGHT", -12, 0)
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
        _G.OpenMailHorizontalBarLeft:SetPoint("TOPLEFT", openFrame, "BOTTOMLEFT", 4, 39 + height)
    end
    if _G.OpenStationeryBackgroundLeft then
        _G.OpenStationeryBackgroundLeft:SetWidth(256)
        _G.OpenStationeryBackgroundLeft:SetHeight(scrollHeight)
        _G.OpenStationeryBackgroundLeft:SetTexCoord(0, 1.0, 0, math_min(scrollHeight, 256) / 256)
    end
    if _G.OpenStationeryBackgroundRight then
        _G.OpenStationeryBackgroundRight:SetWidth(68)
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

local function syncMailTabView()
    local mailFrame = _G.MailFrame
    if not mailFrame or not mailFrame._duiInset then return end
    hideMailChromePieces()
    hideMailIcons(mailFrame)
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

    local inset = paintWindowChrome(mailFrame, _G.InboxCloseButton, INSET_INBOX)

    local inbox = _G.InboxFrame
    if inbox then
        inbox:ClearAllPoints()
        inbox:SetAllPoints(mailFrame)
        inbox:SetSize(WIDTH, HEIGHT)
        inbox:SetFrameLevel(inset:GetFrameLevel() + 2)

        local page = inbox:CreateTexture(nil, "BACKGROUND")
        page._duiOwned = true
        setAtlas(page, "questbg-parchment")
        page:SetSize(PAGE_W, PAGE_H)
        page:SetPoint("TOPLEFT", inbox, "TOPLEFT", PAGE_X, PAGE_Y)
        inbox._duiPage = page

        if _G.InboxTitleText then
            _G.InboxTitleText:ClearAllPoints()
            _G.InboxTitleText:SetPoint("TOPLEFT", mailFrame, "TOPLEFT", 24, -5)
            _G.InboxTitleText:SetPoint("TOPRIGHT", mailFrame, "TOPRIGHT", -24, -5)
            _G.InboxTitleText:SetHeight(16)
            _G.InboxTitleText:SetJustifyH("CENTER")
        end

        if _G.InboxTooMuchMail then
            _G.InboxTooMuchMail:ClearAllPoints()
            _G.InboxTooMuchMail:SetPoint("TOP", inbox, "TOP", 0, -24)
        end

        if _G.InboxCurrentPage then
            neuterTexture(_G.InboxCurrentPage)
        end

        -- Center 305x45 MailItem1..7 rows inside the 321px parchment page.
        if _G.MailItem1 then
            _G.MailItem1:ClearAllPoints()
            _G.MailItem1:SetPoint("TOPLEFT", inbox, "TOPLEFT", 15, -67)
        end

        reskinPageNav("InboxPrevPageButton")
        reskinPageNav("InboxNextPageButton")

        local prevBtn = _G.InboxPrevPageButton
        if prevBtn then
            prevBtn:ClearAllPoints()
            prevBtn:SetPoint("BOTTOMLEFT", inbox, "BOTTOMLEFT", 15, 10)
            for _, r in ipairs({ prevBtn:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" then
                    r:ClearAllPoints()
                    r:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
                end
            end
        end

        local nextBtn = _G.InboxNextPageButton
        if nextBtn then
            nextBtn:ClearAllPoints()
            nextBtn:SetPoint("BOTTOMRIGHT", inbox, "BOTTOMRIGHT", -18, 10)
            for _, r in ipairs({ nextBtn:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" then
                    r:ClearAllPoints()
                    r:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
                end
            end
        end

        if not openAllBtn then
            openAllBtn = CreateFrame("Button", "DragonUIOpenAllMailButton", inbox, "UIPanelButtonTemplate")
            skinActionButton(openAllBtn, 104, 22)
            openAllBtn:SetPoint("CENTER", inbox, "BOTTOM", -1, 24)
            openAllBtn:SetText(localized("Open All"))
            openAllBtn:SetScript("OnClick", StartOpenAll)
            openAllBtn:SetScript("OnEnter", function(self)
                if not _G.GameTooltip then return end
                _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(localized("Open All"), 1, 0.82, 0)
                _G.GameTooltip:AddLine(localized("Loot all mail attachments and gold (skips COD mail)"), 1, 1, 1, true)
                _G.GameTooltip:Show()
            end)
            openAllBtn:SetScript("OnLeave", function()
                if _G.GameTooltip then _G.GameTooltip:Hide() end
            end)
        end
    end

    local sendFrame = _G.SendMailFrame
    if sendFrame then
        sendFrame:ClearAllPoints()
        sendFrame:SetAllPoints(mailFrame)
        sendFrame:SetSize(WIDTH, HEIGHT)
        sendFrame:SetFrameLevel(inset:GetFrameLevel() + 2)
        clampHorizontalBars(sendFrame)

        if _G.SendMailTitleText then
            _G.SendMailTitleText:ClearAllPoints()
            _G.SendMailTitleText:SetPoint("TOPLEFT", mailFrame, "TOPLEFT", 24, -5)
            _G.SendMailTitleText:SetPoint("TOPRIGHT", mailFrame, "TOPRIGHT", -24, -5)
            _G.SendMailTitleText:SetHeight(16)
            _G.SendMailTitleText:SetJustifyH("CENTER")
        end

        if _G.SendMailHorizontalBarLeft then
            _G.SendMailHorizontalBarLeft:ClearAllPoints()
            _G.SendMailHorizontalBarLeft:SetPoint("TOPLEFT", sendFrame, "TOPLEFT", 4, -337)
        end

        if _G.SendMailNameEditBox then
            _G.SendMailNameEditBox:SetSize(115, 20)
            _G.SendMailNameEditBox:ClearAllPoints()
            _G.SendMailNameEditBox:SetPoint("TOPLEFT", sendFrame, "TOPLEFT", 68, -29)
            stretchEditBoxBorder(_G.SendMailNameEditBox)
        end

        if _G.SendMailSubjectEditBox and _G.SendMailNameEditBox then
            _G.SendMailSubjectEditBox:SetSize(255, 20)
            _G.SendMailSubjectEditBox:ClearAllPoints()
            _G.SendMailSubjectEditBox:SetPoint("TOPLEFT", _G.SendMailNameEditBox, "BOTTOMLEFT", 0, -4)
            stretchEditBoxBorder(_G.SendMailSubjectEditBox)
        end

        -- SmallMoneyFrameTemplate parks its copper coin 13px inside its right edge.
        if _G.SendMailCostMoneyFrame then
            _G.SendMailCostMoneyFrame:ClearAllPoints()
            _G.SendMailCostMoneyFrame:SetPoint("RIGHT", sendFrame, "TOPRIGHT", -2, -39)
        end

        if _G.SendMailScrollFrame then
            _G.SendMailScrollFrame:ClearAllPoints()
            _G.SendMailScrollFrame:SetPoint("TOPLEFT", sendFrame, "TOPLEFT", 7, -83)
            styleMailScrollBar(_G.SendMailScrollFrame, sendFrame)
        end

        if _G.SendMailMoneyButton then
            _G.SendMailMoneyButton:ClearAllPoints()
            _G.SendMailMoneyButton:SetPoint("BOTTOMLEFT", sendFrame, "BOTTOMLEFT", 12, 38)
        end

        if _G.SendMailMoney and _G.SendMailMoneyText then
            _G.SendMailMoney:ClearAllPoints()
            _G.SendMailMoney:SetPoint("TOPLEFT", _G.SendMailMoneyText, "BOTTOMLEFT", 2, -4)
        end

        -- Anchor radio buttons left of the right border so localized COD labels never overflow.
        if _G.SendMailSendMoneyButton then
            _G.SendMailSendMoneyButton:ClearAllPoints()
            _G.SendMailSendMoneyButton:SetPoint("TOPLEFT", sendFrame, "BOTTOMLEFT", 178, 73)
        end
        if _G.SendMailCODButton and _G.SendMailSendMoneyButton then
            _G.SendMailCODButton:ClearAllPoints()
            _G.SendMailCODButton:SetPoint("TOPLEFT", _G.SendMailSendMoneyButton, "BOTTOMLEFT", 0, -3)
        end

        local moneyInset = CreateFrame("Frame", nil, sendFrame)
        moneyInset:EnableMouse(false)
        moneyInset:SetFrameLevel(sendFrame:GetFrameLevel())
        moneyInset:SetPoint("BOTTOMLEFT", sendFrame, "BOTTOMLEFT", 4, 4)
        moneyInset:SetPoint("TOPRIGHT", sendFrame, "BOTTOMLEFT", 168, 26)
        applySlices(moneyInset, "InsetFrameTemplate")
        local moneyMarble = sendFrame:CreateTexture(nil, "BACKGROUND", nil, -2)
        moneyMarble._duiOwned = true
        moneyMarble:SetTexture(MARBLE)
        moneyMarble:SetHorizTile(true)
        moneyMarble:SetVertTile(true)
        moneyMarble:SetAllPoints(moneyInset)

        -- Overhangs moneyInset by 7px so SmallMoneyFrameTemplate's 13px right pad leaves 6px inside the rim.
        if _G.SendMailMoneyFrame then
            _G.SendMailMoneyFrame:ClearAllPoints()
            _G.SendMailMoneyFrame:SetPoint("BOTTOMRIGHT", moneyInset, "BOTTOMRIGHT", 7, 5)
            _G.SendMailMoneyFrame:SetFrameLevel(sendFrame:GetFrameLevel() + 2)
            if addon.RegisterBlizzardMoneyFrame then
                addon.RegisterBlizzardMoneyFrame(_G.SendMailMoneyFrame)
            end
        end

        if _G.SendMailCancelButton then
            _G.SendMailCancelButton:ClearAllPoints()
            _G.SendMailCancelButton:SetPoint("BOTTOMRIGHT", sendFrame, "BOTTOMRIGHT", -6, 4)
            skinActionButton(_G.SendMailCancelButton, 78, 22)
        end
        if _G.SendMailMailButton and _G.SendMailCancelButton then
            _G.SendMailMailButton:ClearAllPoints()
            _G.SendMailMailButton:SetPoint("RIGHT", _G.SendMailCancelButton, "LEFT", -4, 0)
            skinActionButton(_G.SendMailMailButton, 78, 22)
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
            "OpenMailFrameIcon",
            "OpenMailFrameTopLeft", "OpenMailFrameTopRight", "OpenMailFrameBotLeft", "OpenMailFrameBotRight",
        }) do
            local tex = _G[name]
            if tex then
                neuterTexture(tex)
            end
        end
        clampHorizontalBars(openFrame)

        local openInset = paintWindowChrome(openFrame, _G.OpenMailCloseButton, INSET_OPEN)
        openFrame:ClearAllPoints()
        openFrame:SetPoint("TOPLEFT", mailFrame, "TOPRIGHT", 10, 0)

        if _G.OpenMailTitleText then
            _G.OpenMailTitleText:ClearAllPoints()
            _G.OpenMailTitleText:SetPoint("TOPLEFT", openFrame, "TOPLEFT", 24, -5)
            _G.OpenMailTitleText:SetPoint("TOPRIGHT", openFrame, "TOPRIGHT", -24, -5)
            _G.OpenMailTitleText:SetHeight(16)
            _G.OpenMailTitleText:SetJustifyH("CENTER")
        end

        if _G.OpenMailSenderLabel then
            _G.OpenMailSenderLabel:ClearAllPoints()
            _G.OpenMailSenderLabel:SetPoint("TOPRIGHT", openFrame, "TOPLEFT", 68, -34)
        end
        if _G.OpenMailSubjectLabel then
            _G.OpenMailSubjectLabel:ClearAllPoints()
            _G.OpenMailSubjectLabel:SetPoint("TOPRIGHT", openFrame, "TOPLEFT", 68, -54)
        end
        if _G.OpenMailSender then
            _G.OpenMailSender:SetJustifyH("LEFT")
        end
        if _G.OpenMailSubject and _G.OpenMailSubjectLabel then
            _G.OpenMailSubject:ClearAllPoints()
            _G.OpenMailSubject:SetPoint("TOPLEFT", _G.OpenMailSubjectLabel, "TOPRIGHT", 6, -2)
            _G.OpenMailSubject:SetPoint("RIGHT", openFrame, "RIGHT", -12, 0)
        end
        if _G.OpenMailReportSpamButton then
            _G.OpenMailReportSpamButton:ClearAllPoints()
            _G.OpenMailReportSpamButton:SetPoint("TOPRIGHT", openFrame, "TOPRIGHT", -10, -30)
            skinActionButton(_G.OpenMailReportSpamButton, 106, 22)
        end

        if _G.OpenMailScrollFrame then
            _G.OpenMailScrollFrame:ClearAllPoints()
            _G.OpenMailScrollFrame:SetPoint("TOPLEFT", openFrame, "TOPLEFT", 7, -83)
            styleMailScrollBar(_G.OpenMailScrollFrame, openFrame)
        end

        if _G.OpenMailCancelButton then
            _G.OpenMailCancelButton:ClearAllPoints()
            _G.OpenMailCancelButton:SetPoint("BOTTOMRIGHT", openFrame, "BOTTOMRIGHT", -6, 4)
            skinActionButton(_G.OpenMailCancelButton, 80, 22)
        end
        if _G.OpenMailDeleteButton and _G.OpenMailCancelButton then
            _G.OpenMailDeleteButton:ClearAllPoints()
            _G.OpenMailDeleteButton:SetPoint("RIGHT", _G.OpenMailCancelButton, "LEFT", -4, 0)
            skinActionButton(_G.OpenMailDeleteButton, 80, 22)
        end
        if _G.OpenMailReplyButton and _G.OpenMailDeleteButton then
            _G.OpenMailReplyButton:ClearAllPoints()
            _G.OpenMailReplyButton:SetPoint("RIGHT", _G.OpenMailDeleteButton, "LEFT", -4, 0)
            skinActionButton(_G.OpenMailReplyButton, 80, 22)
        end

        for _, child in ipairs({ openFrame:GetChildren() }) do
            if child ~= openInset and child ~= _G.OpenMailCloseButton
                and child:GetFrameLevel() <= openInset:GetFrameLevel() then
                child:SetFrameLevel(openInset:GetFrameLevel() + 2)
            end
        end

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

    if _G.InboxFrame_Update and not mailFrame._duiUpdateHooked then
        mailFrame._duiUpdateHooked = true
        hooksecurefunc("InboxFrame_Update", function()
            if not IsModuleEnabled() then return end
            UpdateOpenAllButtonState()
        end)
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
boot:RegisterEvent("MAIL_INBOX_UPDATE")
boot:RegisterEvent("MAIL_CLOSED")
boot:SetScript("OnEvent", function(_, event)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_LOGIN" then
        addon.ApplyMailSystem()
    elseif event == "MAIL_SHOW" then
        buildMailFrame()
        syncMailTabView()
        UpdateOpenAllButtonState()
    elseif event == "MAIL_INBOX_UPDATE" then
        UpdateOpenAllButtonState()
    elseif event == "MAIL_CLOSED" then
        StopOpenAll()
    end
end)
