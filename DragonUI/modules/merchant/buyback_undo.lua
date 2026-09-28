-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local parts = addon.merchantParts or {}
addon.merchantParts = parts

local function greyWhenNothingStored(arrow)
    SetDesaturation(arrow, GetNumBuybackItems() == 0)
end

function parts.buildUndoArrow()
    local slot = _G.MerchantBuyBackItemItemButton
    if not slot or slot.UndoFrame then
        return
    end

    -- Mouse stays off so clicks fall through to the buyback button underneath.
    local overlay = CreateFrame("Frame", nil, slot)
    overlay:EnableMouse(false)
    overlay:SetAllPoints(slot)
    overlay:SetFrameLevel(slot:GetFrameLevel() + 2)

    local arrow = overlay:CreateTexture(nil, "ARTWORK")
    arrow:SetAtlasTexture("common-icon-undo", false)
    arrow:SetSize(20, 20)
    arrow:SetPoint("CENTER", overlay, "CENTER", 0, -1)

    overlay.Arrow = arrow
    slot.UndoFrame = overlay

    greyWhenNothingStored(arrow)
    hooksecurefunc("MerchantFrame_Update", function()
        greyWhenNothingStored(arrow)
    end)
end
