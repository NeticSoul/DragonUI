-- Item filtering / category set registry (CombuctorSet/Sets).
local addon = select(2, ...)
local mod = addon.CombuctorModule
local tinsert = table.insert

local SET_ALL = ALL or "All"
local SET_EQUIPMENT = "Equipment"
local SET_USABLE = "Usable"
local SET_NORMAL = "Normal"
local SET_TRADE = "Trade"

-- ============================================================================
-- SETS (ITEM FILTERING)
-- ============================================================================

do
    local CombuctorSet = mod:NewModule("Sets", mod("Envoy"):New())

    local parentSets = {}
    local childSets = {}

    function CombuctorSet:Register(name, icon, rule, parent)
        local set = { name = name, icon = icon, rule = rule, parent = parent }
        if parent then
            childSets[parent] = childSets[parent] or {}
            tinsert(childSets[parent], set)
            self:Send("COMBUCTOR_SUBSET_ADD", name, parent)
        else
            tinsert(parentSets, set)
            self:Send("COMBUCTOR_SET_ADD", name)
        end
    end

    function CombuctorSet:Get(name, parent)
        if parent then
            local children = childSets[parent]
            if children then
                for _, set in ipairs(children) do
                    if set.name == name then
                        return set
                    end
                end
            end
        else
            for _, set in ipairs(parentSets) do
                if set.name == name then
                    return set
                end
            end
        end
    end

    function CombuctorSet:GetParentSets()
        return ipairs(parentSets)
    end

    function CombuctorSet:GetChildSets(parent)
        return ipairs(childSets[parent] or {})
    end

    -- Profession bag type bitmask
    local BAGTYPE_PROFESSION = 0x0008 + 0x0010 + 0x0020 + 0x0040 + 0x0080 + 0x0200 + 0x0400 + 0x8000

    -- Additional localization for sets
    mod.L.Equipment = SET_EQUIPMENT
    mod.L.Usable = SET_USABLE
    mod.L.Normal = SET_NORMAL
    mod.L.Trade = SET_TRADE

    -- Register default item sets (matching KPack Combuctor structure)

    -- ALL: parent set
    CombuctorSet:Register(SET_ALL, [[Interface\Icons\INV_Misc_EngGizmos_17]], function() return true end)
    -- ALL subtabs: All, Normal, Trade
    CombuctorSet:Register(SET_ALL, nil, nil, SET_ALL)
    CombuctorSet:Register(mod.L.Normal, nil, function(player, bagType) return bagType and bagType == 0 end, SET_ALL)
    CombuctorSet:Register(mod.L.Trade, nil, function(player, bagType) return bagType and bit.band(bagType, BAGTYPE_PROFESSION) > 0 end, SET_ALL)

    -- EQUIPMENT: parent set (armor + weapons)
    do
        local function isEquipment(_, _, _, _, _, _, _, itype)
            return (itype == mod.L.Armor or itype == mod.L.Weapon)
        end
        CombuctorSet:Register(mod.L.Equipment, [[Interface\Icons\INV_Chest_Chain_04]], isEquipment)
        -- Equipment subtabs: All, Armor, Weapon, Trinket
        CombuctorSet:Register(SET_ALL, nil, nil, mod.L.Equipment)
    end
    do
        local function isArmor(_, _, _, _, _, _, _, itype, _, _, equipLoc)
            return itype == mod.L.Armor and equipLoc ~= "INVTYPE_TRINKET"
        end
        CombuctorSet:Register(mod.L.Armor, nil, isArmor, mod.L.Equipment)
    end
    do
        local function isWeapon(_, _, _, _, _, _, _, itype)
            return itype == mod.L.Weapon
        end
        CombuctorSet:Register(mod.L.Weapon, nil, isWeapon, mod.L.Equipment)
    end
    do
        local function isTrinket(_, _, _, _, _, _, _, _, _, _, equipLoc)
            return equipLoc == "INVTYPE_TRINKET"
        end
        CombuctorSet:Register(INVTYPE_TRINKET, nil, isTrinket, mod.L.Equipment)
    end

    -- USABLE: parent set (consumables + devices/explosives)
    do
        local function isUsable(_, _, _, _, _, _, _, itype, subType)
            if itype == mod.L.Consumable then
                return true
            elseif itype == mod.L.TradeGood then
                if subType == mod.L.Devices or subType == mod.L.Explosives then
                    return true
                end
            end
        end
        CombuctorSet:Register(mod.L.Usable, [[Interface\Icons\INV_Potion_93]], isUsable)
        -- Usable subtabs: All, Consumable, Devices
        CombuctorSet:Register(SET_ALL, nil, nil, mod.L.Usable)
    end
    do
        local function isConsumable(_, _, _, _, _, _, _, itype)
            return itype == mod.L.Consumable
        end
        CombuctorSet:Register(mod.L.Consumable, nil, isConsumable, mod.L.Usable)
    end
    do
        local function isDevice(_, _, _, _, _, _, _, itype)
            return itype == mod.L.TradeGood
        end
        CombuctorSet:Register(mod.L.Devices, nil, isDevice, mod.L.Usable)
    end

    -- QUEST: parent set (no subtabs)
    do
        local function isQuestItem(_, _, _, _, _, _, _, itype)
            return itype == mod.L.Quest
        end
        CombuctorSet:Register(mod.L.Quest, [[Interface\QuestFrame\UI-QuestLog-BookIcon]], isQuestItem)
        CombuctorSet:Register(SET_ALL, nil, nil, mod.L.Quest)
    end

    -- TRADE GOODS: parent set (trade goods + gems + recipes, excluding devices/explosives)
    do
        local function isTradeGood(_, _, _, _, _, _, _, itype, subType)
            if itype == mod.L.TradeGood then
                return not (subType == mod.L.Devices or subType == mod.L.Explosives)
            end
            return itype == mod.L.Recipe or itype == mod.L.Gem
        end
        CombuctorSet:Register(mod.L.TradeGood, [[Interface\Icons\INV_Fabric_Silk_02]], isTradeGood)
        -- Trade Goods subtabs: All, Trade Goods, Gem, Recipe
        CombuctorSet:Register(SET_ALL, nil, nil, mod.L.TradeGood)
    end
    do
        local function isTradeGoodOnly(_, _, _, _, _, _, _, itype)
            return itype == mod.L.TradeGood
        end
        CombuctorSet:Register(mod.L.TradeGood, nil, isTradeGoodOnly, mod.L.TradeGood)
    end
    do
        local function isGem(_, _, _, _, _, _, _, itype)
            return itype == mod.L.Gem
        end
        CombuctorSet:Register(mod.L.Gem, nil, isGem, mod.L.TradeGood)
    end
    do
        local function isRecipe(_, _, _, _, _, _, _, itype)
            return itype == mod.L.Recipe
        end
        CombuctorSet:Register(mod.L.Recipe, nil, isRecipe, mod.L.TradeGood)
    end

    -- MISCELLANEOUS: parent set (no subtabs)
    do
        local function isMiscItem(_, _, _, link, _, _, _, itype)
            return itype == mod.L.Misc and (link:match("%d+") ~= "6265")
        end
        CombuctorSet:Register(mod.L.Misc, [[Interface\Icons\INV_Misc_Rune_01]], isMiscItem)
        CombuctorSet:Register(SET_ALL, nil, nil, mod.L.Misc)
    end
end
