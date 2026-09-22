-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- One-click sell-all-junk on the vendor window.
-- 3.3.5a has no C_MerchantFrame.SellAllJunkItems; this walks bags with UseContainerItem.

local addon = select(2, ...)

local L = addon.L

local POPUP = "DRAGONUI_SELL_ALL_JUNK"
local POOR_LINK_COLOR = "|cff9d9d9d"

-- Quality comes from the link colour because GetItemInfo is nil until the item is cached.
local function junkAt(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link or link:sub(1, 10) ~= POOR_LINK_COLOR then return false end
    local sellPrice = select(11, GetItemInfo(link))
    return sellPrice ~= 0
end

local function forEachBagSlot(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            fn(bag, slot)
        end
    end
end

local function countJunkItems()
    local n = 0
    forEachBagSlot(function(bag, slot)
        if junkAt(bag, slot) then n = n + 1 end
    end)
    return n
end

local function sellAllJunk()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if MerchantFrame.selectedTab ~= 1 then return end

    local sold = 0
    forEachBagSlot(function(bag, slot)
        if junkAt(bag, slot) and pcall(UseContainerItem, bag, slot) then
            sold = sold + 1
        end
    end)

    if sold > 0 then
        addon:Print(string.format(L["Sold %d junk item(s)."], sold))
    end
end

-- ============================================================================
-- Button
-- ============================================================================

local refreshPending
local function refreshState()
    local btn = _G.DragonUI_MerchantSellAllJunkButton
    if not btn or not btn:IsVisible() or refreshPending then return end
    refreshPending = true
    addon:After(0, function()
        refreshPending = false
        if not btn:IsVisible() then return end
        local has = countJunkItems() > 0
        SetDesaturation(btn.Icon, not has)
        if has then btn:Enable() else btn:Disable() end
    end)
end

local function onClick()
    GameTooltip:Hide()
    StaticPopup_Show(POPUP)
end

local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Sell all junk items"])
    GameTooltip:Show()
end

function addon.MerchantSellAllJunkBuild()
    if _G.DragonUI_MerchantSellAllJunkButton or not _G.MerchantFrame then return end

    StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
        text         = L["You are about to sell all junk items and will not be able to buy them back.\n\nAre you sure you want to proceed?"],
        button1      = YES,
        button2      = NO,
        OnAccept     = sellAllJunk,
        timeout      = 0,
        whileDead    = 1,
        hideOnEscape = 1,
    }

    local btn = CreateFrame("Button", "DragonUI_MerchantSellAllJunkButton", _G.MerchantFrame)
    btn:SetSize(36, 36)
    btn:SetPoint("BOTTOMRIGHT", _G.MerchantFrame, "BOTTOMLEFT", 160, 33)

    local icon = btn:CreateTexture(nil, "BORDER")
    icon:set_atlas("spellicon-256x256-selljunk", false)
    icon:SetAllPoints(btn)
    btn.Icon = icon

    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)
    btn:SetHighlightTexture(hl)

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    btn:RegisterEvent("MERCHANT_SHOW")
    btn:RegisterEvent("MERCHANT_UPDATE")
    btn:RegisterEvent("BAG_UPDATE")
    btn:SetScript("OnEvent", refreshState)
    btn:SetScript("OnShow", refreshState)
    refreshState()
end
