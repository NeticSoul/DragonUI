-- Buyback undo arrow on the vendor window's buyback slot.

local addon = select(2, ...)
if not addon then return end

local arrowTex

local function refreshDesaturation()
    if not arrowTex then return end
    SetDesaturation(arrowTex, ((GetNumBuybackItems and GetNumBuybackItems()) or 0) == 0)
end

function addon.MerchantBuybackUndoBuild()
    local itemBtn = _G.MerchantBuyBackItemItemButton
    if not itemBtn or itemBtn._duiUndoBuilt then return end

    local undo = CreateFrame("Frame", nil, itemBtn)
    undo:SetAllPoints(itemBtn)
    undo:SetFrameLevel((itemBtn:GetFrameLevel() or 0) + 2)

    local tex = undo:CreateTexture(nil, "ARTWORK")
    if addon.atlasinfo and addon.atlasinfo["common-icon-undo"] then
        tex:set_atlas("common-icon-undo", false)
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", 0, -1)
        arrowTex = tex
        undo.Arrow = tex
        itemBtn.UndoFrame = undo
        itemBtn._duiUndoBuilt = true
        refreshDesaturation()

        if _G.MerchantFrame_Update then
            hooksecurefunc("MerchantFrame_Update", refreshDesaturation)
        end
    else
        undo:Hide()
    end
end
