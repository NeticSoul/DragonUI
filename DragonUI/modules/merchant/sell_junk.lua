-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local parts = addon.merchantParts or {}
addon.merchantParts = parts
local localized = parts.localized

local BUTTON_NAME = "DragonUI_MerchantSellAllJunkButton"
local DIALOG_KEY = "DRAGONUI_SELL_ALL_JUNK"
local WARNING_KEY = "You are about to sell all junk items and will not be able to buy them back.\n\nAre you sure you want to proceed?"
local REFRESH_EVENTS = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "BAG_UPDATE" }

-- Grey links carry this colour code even while GetItemInfo knows nothing about the item.
local GREY_LINK_START = "|cff9d9d9d"

local stateQueued = false

local function isJunk(link)
    local grey = link ~= nil and link:sub(1, 10) == GREY_LINK_START
    -- An unknown price (nil) still counts; only an explicit zero means the vendor refuses it.
    return grey and select(11, GetItemInfo(link)) ~= 0
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

local function sellEveryJunkItem()
    local window = _G.MerchantFrame
    if not window or not window:IsShown() or window.selectedTab ~= 1 then
        return 0, 0
    end
    -- Counts calls that did not raise, not sales the server confirmed.
    local items, copper = 0, 0
    forEachJunkSlot(function(bag, slot, link)
        local _, count = GetContainerItemInfo(bag, slot)
        count = count or 1
        local price = select(11, GetItemInfo(link)) or 0
        if pcall(UseContainerItem, bag, slot) then
            items = items + count
            copper = copper + price * count
        end
    end)
    if items > 0 then
        addon:Print(string.format(localized("Selling %d junk item(s) for %s."), items, GetMoneyString(copper)))
    end
    return items, copper
end
parts.sellEveryJunkItem = sellEveryJunkItem

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
