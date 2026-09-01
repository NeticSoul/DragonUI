-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- One-click sell-all-junk on the vendor window.
-- 3.3.5a has no C_MerchantFrame.SellAllJunkItems; this walks bags with UseContainerItem.

local addon = select(2, ...)
if not addon then return end

local L = addon.L

local POPUP = "DRAGONUI_SELL_ALL_JUNK"

-- Poor quality, vendor takes it, and not a quest item
local function junkAt(bag, slot)
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not link then return nil end
    local _, _, quality, _, _, itemType, _, _, _, _, sellPrice = GetItemInfo(link)
    if quality ~= 0 then return nil end
    if not sellPrice or sellPrice <= 0 then return nil end
    if itemType == "Quest" then return nil end
    return true
end

local function forEachBagSlot(fn)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
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
        if junkAt(bag, slot) then
            if pcall(UseContainerItem, bag, slot) then sold = sold + 1 end
        end
    end)

    if sold > 0 and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(L["Sold %d junk item(s)."], sold))
    end
end

-- ============================================================================
-- Button
-- ============================================================================

local refreshPending
local function refreshState()
    local btn = _G.DragonUI_MerchantSellAllJunkButton
    if not btn then return end
    if not btn:IsVisible() then return end
    if refreshPending then return end
    refreshPending = true
    addon:After(0, function()
        refreshPending = false
        if not btn:IsVisible() then return end
        local has = countJunkItems() > 0
        if btn.Icon then SetDesaturation(btn.Icon, not has) end
        if has then btn:Enable() else btn:Disable() end
    end)
end

local function onClick(self)
    GameTooltip:Hide()
    StaticPopup_Show(POPUP)
end

local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Sell all junk items"])
    GameTooltip:Show()
end

function addon.MerchantSellAllJunkBuild()
    if _G.DragonUI_MerchantSellAllJunkButton then return end
    if not _G.MerchantFrame then return end

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

    local icon = btn:CreateTexture(nil, "ARTWORK")
    if addon.atlasinfo and addon.atlasinfo["spellicon-256x256-selljunk"] then
        icon:set_atlas("spellicon-256x256-selljunk", false)
    end
    icon:SetAllPoints(btn)
    btn.Icon = icon

    -- Use the atlas icon as the button's normal texture so it's always visible
    btn:SetNormalTexture(icon)
    btn:GetNormalTexture():SetAllPoints(btn)

    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterEvent("MERCHANT_SHOW")
    btn:RegisterEvent("MERCHANT_UPDATE")
    btn:RegisterEvent("BAG_UPDATE")
    btn:SetScript("OnEvent", refreshState)
    btn:SetScript("OnShow", refreshState)
    refreshState()
end
