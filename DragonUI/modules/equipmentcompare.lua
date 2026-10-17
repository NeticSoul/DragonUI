local addon = select(2, ...)
local L = addon.L

local EquipmentCompareModule = {
    initialized = false,
    applied = false,
    hooks = {},
}

if addon.RegisterModule then
    addon:RegisterModule("equipmentcompare", EquipmentCompareModule,
        (L and L["Automatic Equipment Comparison"]) or "Automatic Equipment Comparison",
        (L and L["Shows equipped item comparisons automatically without holding Shift, including chat item links."])
            or "Shows equipped item comparisons automatically without holding Shift, including chat item links.", {
        lifecyclePrefix = "EquipmentCompare",
    })
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("equipmentcompare")
end

local function GetComparisonTooltips(tooltip)
    if tooltip.shoppingTooltips and tooltip.shoppingTooltips[1]
        and tooltip.shoppingTooltips[2] and tooltip.shoppingTooltips[3] then
        return tooltip.shoppingTooltips
    end

    if tooltip == GameTooltip then
        if ShoppingTooltip1 and ShoppingTooltip2 and ShoppingTooltip3 then
            tooltip.shoppingTooltips = { ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }
        end
        return tooltip.shoppingTooltips
    end

    if tooltip == ItemRefTooltip then
        local first = ItemRefShoppingTooltip1
        local second = ItemRefShoppingTooltip2
        local third = ItemRefShoppingTooltip3

        if not first then
            first = CreateFrame("GameTooltip", "DragonUIItemRefShoppingTooltip1", ItemRefTooltip,
                "ShoppingTooltipTemplate")
        end
        if not second then
            second = CreateFrame("GameTooltip", "DragonUIItemRefShoppingTooltip2", ItemRefTooltip,
                "ShoppingTooltipTemplate")
        end
        if not third then
            third = CreateFrame("GameTooltip", "DragonUIItemRefShoppingTooltip3", ItemRefTooltip,
                "ShoppingTooltipTemplate")
        end

        tooltip.shoppingTooltips = { first, second, third }
        return tooltip.shoppingTooltips
    end
end

local function HideComparisonTooltips(tooltip)
    local tooltips = tooltip and tooltip.shoppingTooltips
    if not tooltips then
        return
    end

    for _, comparisonTooltip in ipairs(tooltips) do
        comparisonTooltip:Hide()
    end
end

local function IsCharacterEquipmentFrame(frame)
    local current = frame
    for _ = 1, 8 do
        if not current then
            break
        end

        if current == CharacterFrame then
            return true
        end

        local name = current.GetName and current:GetName() or ""
        if string.match(name, "^Character.*Slot$") then
            return true
        end

        current = current.GetParent and current:GetParent() or nil
    end

    return false
end

local function ShouldIgnoreTooltip(tooltip)
    if tooltip ~= GameTooltip then
        return false
    end

    local focus = GetMouseFocus and GetMouseFocus()
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if IsCharacterEquipmentFrame(focus) or IsCharacterEquipmentFrame(owner) then
        return true
    end

    local name = focus and focus.GetName and focus:GetName() or ""
    return string.match(name, "^TempEnchant%d+$")
        or string.match(name, "^TM_Button")
        or string.match(name, "^TrinketMenu")
end

local function ManualShowComparison(tooltip, itemLink)
    local comparisonTooltips = GetComparisonTooltips(tooltip)
    if not comparisonTooltips then
        return
    end

    local left = tooltip:GetLeft() or 0
    local right = tooltip:GetRight() or 0
    local placeOnLeft = left > ((GetScreenWidth() or 0) - right)
    local point = placeOnLeft and "TOPRIGHT" or "TOPLEFT"
    local relativePoint = placeOnLeft and "TOPLEFT" or "TOPRIGHT"
    local anchorFrame = tooltip

    for index, comparisonTooltip in ipairs(comparisonTooltips) do
        comparisonTooltip:SetOwner(tooltip, "ANCHOR_NONE")
        if comparisonTooltip:SetHyperlinkCompareItem(itemLink, index, 1, tooltip) then
            comparisonTooltip:ClearAllPoints()
            comparisonTooltip:SetPoint(point, anchorFrame, relativePoint, 0, 0)
            comparisonTooltip:SetScale(tooltip:GetScale())
            comparisonTooltip:Show()
            anchorFrame = comparisonTooltip
        else
            comparisonTooltip:Hide()
        end
    end
end

local function ShowComparison(tooltip)
    if not IsModuleEnabled() or not tooltip then
        return
    end

    if ShouldIgnoreTooltip(tooltip) then
        HideComparisonTooltips(tooltip)
        return
    end

    if IsControlKeyDown and IsControlKeyDown() then
        HideComparisonTooltips(tooltip)
        return
    end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then
        return
    end

    if not GetComparisonTooltips(tooltip) then
        return
    end

    if GameTooltip_ShowCompareItem then
        GameTooltip_ShowCompareItem(tooltip)
    else
        ManualShowComparison(tooltip, itemLink)
    end
end

local function HookTooltip(tooltip)
    if not tooltip or EquipmentCompareModule.hooks[tooltip] then
        return
    end

    tooltip:HookScript("OnTooltipSetItem", function(self)
        ShowComparison(self)
    end)
    tooltip:HookScript("OnTooltipCleared", function(self)
        HideComparisonTooltips(self)
    end)

    EquipmentCompareModule.hooks[tooltip] = true
end

local function ApplyEquipmentCompareSystem()
    HookTooltip(GameTooltip)
    HookTooltip(ItemRefTooltip)

    EquipmentCompareModule.applied = true
    EquipmentCompareModule.initialized = true
end

local function RestoreEquipmentCompareSystem()
    HideComparisonTooltips(GameTooltip)
    HideComparisonTooltips(ItemRefTooltip)
    EquipmentCompareModule.applied = false
end

local function RefreshEquipmentCompareSystem()
    if IsModuleEnabled() then
        ApplyEquipmentCompareSystem()
    else
        RestoreEquipmentCompareSystem()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    if IsModuleEnabled() then
        ApplyEquipmentCompareSystem()
    end
end)

addon.ApplyEquipmentCompareSystem = ApplyEquipmentCompareSystem
addon.RestoreEquipmentCompareSystem = RestoreEquipmentCompareSystem
addon.RefreshEquipmentCompareSystem = RefreshEquipmentCompareSystem
