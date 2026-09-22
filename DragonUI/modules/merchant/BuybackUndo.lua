-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Buyback undo arrow on the vendor window's buyback slot.

local addon = select(2, ...)

local arrowTex

local function refreshDesaturation()
    SetDesaturation(arrowTex, GetNumBuybackItems() == 0)
end

function addon.MerchantBuybackUndoBuild()
    local itemBtn = _G.MerchantBuyBackItemItemButton
    if not itemBtn or itemBtn.UndoFrame then return end

    local undo = CreateFrame("Frame", nil, itemBtn)
    undo:SetAllPoints(itemBtn)
    undo:SetFrameLevel(itemBtn:GetFrameLevel() + 2)

    arrowTex = undo:CreateTexture(nil, "ARTWORK")
    arrowTex:set_atlas("common-icon-undo", false)
    arrowTex:SetSize(20, 20)
    arrowTex:SetPoint("CENTER", 0, -1)
    undo.Arrow = arrowTex
    itemBtn.UndoFrame = undo

    refreshDesaturation()
    hooksecurefunc("MerchantFrame_Update", refreshDesaturation)
end
