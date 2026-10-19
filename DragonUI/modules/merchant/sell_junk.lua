-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local parts = addon.merchantParts or {}
addon.merchantParts = parts
local localized = parts.localized

local BUTTON_NAME = "DragonUI_MerchantSellAllJunkButton"
local DIALOG_KEY = "DRAGONUI_SELL_ALL_JUNK"
local WARNING_KEY = "You are about to sell all junk items and will not be able to buy them back.\n\nAre you sure you want to proceed?"
local REFRESH_EVENTS = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "BAG_UPDATE", "GET_ITEM_INFO_RECEIVED" }

-- Only cached, priced grey items are eligible for automatic sales.
local GREY_LINK_START = "|cff9d9d9d"

local stateQueued = false

local function isJunk(link)
    local grey = link ~= nil and link:sub(1, 10) == GREY_LINK_START
    if not grey then return false end
    local price = select(11, GetItemInfo(link))
    return type(price) == "number" and price > 0
end

local function forEachJunkSlot(visit)
    for container = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetContainerNumSlots(container) or 0 do
            local link = GetContainerItemLink(container, slot)
            if isJunk(link) then
                visit(container, slot, link)
            end
        end
    end
end

local function countJunk()
    local total = 0
    forEachJunkSlot(function()
        total = total + 1
    end)
    return total
end

local sale
local function merchantOpen()
    local window = _G.MerchantFrame
    return window and window:IsShown() and window.selectedTab == 1
end

local function finishSale(completed)
    local done = sale
    sale = nil
    if not done then return end
    if done.items > 0 then
        addon:Print(string.format(localized("Sold %d junk item(s) for %s."), done.items, GetMoneyString(done.copper)))
    end
    if done.unconfirmed then addon:Print(localized("Some junk sales could not be confirmed. Check your bags and buyback.")) end
    if completed and done.onComplete then done.onComplete() end
end

-- One request at a time; a Lua call succeeding does not mean the server sold the item.
local function sellEveryJunkItem(onComplete)
    if sale then return false end
    if not merchantOpen() then return false end
    local run = { queue = {}, index = 0, items = 0, copper = 0, onComplete = onComplete }
    forEachJunkSlot(function(bag, slot, link)
        local _, count, locked = GetContainerItemInfo(bag, slot)
        if not locked and count and count > 0 then
            run.queue[#run.queue + 1] = { bag = bag, slot = slot, link = link, count = count,
                price = select(11, GetItemInfo(link)) }
        end
    end)
    sale = run
    local nextItem
    nextItem = function()
        if sale ~= run then return end
        if not merchantOpen() then finishSale(false); return end
        run.index = run.index + 1
        local item = run.queue[run.index]
        if not item then finishSale(true); return end
        local link = GetContainerItemLink(item.bag, item.slot)
        local _, count, locked = GetContainerItemInfo(item.bag, item.slot)
        -- Do not use a stale slot after the player or another addon moved its contents.
        if link ~= item.link or count ~= item.count or locked then
            nextItem()
            return
        end
        local before = GetMoney()
        if not pcall(UseContainerItem, item.bag, item.slot) then finishSale(false); return end
        local tries = 0
        local function check()
            if sale ~= run then return end
            if not merchantOpen() then finishSale(false); return end
            local current = GetContainerItemLink(item.bag, item.slot)
            -- The whole stack must leave and its payment must arrive before it counts.
            if current ~= item.link and GetMoney() >= before + item.price * item.count then
                run.items = run.items + item.count
                run.copper = run.copper + item.price * item.count
                nextItem()
                return
            end
            tries = tries + 1
            if tries >= 50 then
                -- Never resend an uncertain request, but do not abandon later stacks.
                run.unconfirmed = true
                nextItem()
                return
            end
            addon:After(0.1, check)
        end
        addon:After(0.1, check)
    end
    nextItem()
    return true
end
parts.sellEveryJunkItem = sellEveryJunkItem

local visits = CreateFrame("Frame")
visits:RegisterEvent("MERCHANT_CLOSED")
visits:SetScript("OnEvent", function() finishSale(false) end)

local function applyJunkState(button)
    stateQueued = false
    if not button:IsVisible() then
        return
    end
    local junk = countJunk()
    SetDesaturation(button.Icon, junk == 0)
    if junk > 0 then
        button:Enable()
    else
        button:Disable()
    end
end

local function queueJunkState(button)
    if stateQueued or not button:IsVisible() then
        return
    end
    stateQueued = true
    addon:After(0, function()
        applyJunkState(button)
    end)
end

local function defineDialog()
    if StaticPopupDialogs[DIALOG_KEY] then
        return
    end
    local dialog = { timeout = 0, whileDead = 1, hideOnEscape = 1 }
    dialog.text = localized(WARNING_KEY)
    dialog.button1, dialog.button2 = YES, NO
    -- A truthy return from OnAccept keeps the popup open, so drop the sale totals.
    dialog.OnAccept = function()
        sellEveryJunkItem()
    end
    StaticPopupDialogs[DIALOG_KEY] = dialog
end

local function askToSell()
    GameTooltip:Hide()
    StaticPopup_Show(DIALOG_KEY)
end

local function describe(button)
    local tip = GameTooltip
    tip:SetOwner(button, "ANCHOR_RIGHT")
    tip:SetText(localized("Sell all junk items"))
    tip:Show()
end

function parts.buildSellButton()
    local window = _G.MerchantFrame
    if not window or _G[BUTTON_NAME] then
        return
    end

    local button = CreateFrame("Button", BUTTON_NAME, window)
    button:SetSize(36, 36)
    button:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 160, 33)

    local icon = button:CreateTexture(nil, "BORDER")
    icon:SetAtlasTexture("spellicon-256x256-selljunk", false)
    icon:SetAllPoints(button)
    button.Icon = icon

    local shine = button:CreateTexture(nil, "HIGHLIGHT")
    shine:SetAllPoints(button)
    shine:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    shine:SetBlendMode("ADD")
    button:SetHighlightTexture(shine)
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    defineDialog()

    local handlers = {
        OnEvent = queueJunkState,
        OnShow = queueJunkState,
        OnClick = askToSell,
        OnEnter = describe,
        OnLeave = GameTooltip_Hide,
    }
    for script, handler in pairs(handlers) do
        button:SetScript(script, handler)
    end
    for _, event in ipairs(REFRESH_EVENTS) do
        button:RegisterEvent(event)
    end

    queueJunkState(button)
end
