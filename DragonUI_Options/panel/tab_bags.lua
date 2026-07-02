--[[
================================================================================
DragonUI Options Panel - Bags Tab
================================================================================
Combuctor settings: enable/disable, category tabs, left/right side filter.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

local function RefreshVisibility()
    if addon.RefreshActionBarVisibility then addon.RefreshActionBarVisibility() end
end

local function RefreshVisibilityAndCollapsedBags()
    RefreshVisibility()
    if addon.db and addon.db.profile and addon.db.profile.micromenu and addon.db.profile.micromenu.bags_collapsed then
        if addon.RefreshBags then addon.RefreshBags() end
    end
end

local SET_ALL = ALL or "All"
local SET_EQUIPMENT = "Equipment"
local SET_USABLE = "Usable"
local SET_NORMAL = "Normal"
local SET_TRADE = "Trade"

local function GetLocalizedCombuctorSetName(name)
    if name == SET_EQUIPMENT then
        return LO["Equipment"] or name
    elseif name == SET_USABLE then
        return LO["Usable"] or name
    elseif name == SET_NORMAL then
        return LO["Normal"] or name
    elseif name == SET_TRADE then
        return LO["Trade Bags"] or name
    end
    return name
end

local function NormalizeCombuctorSetName(name)
    if not name then return name end

    if name == SET_EQUIPMENT or name == (LO["Equipment"] or SET_EQUIPMENT) then
        return SET_EQUIPMENT
    elseif name == SET_USABLE or name == (LO["Usable"] or SET_USABLE) then
        return SET_USABLE
    elseif name == SET_NORMAL or name == (LO["Normal"] or SET_NORMAL) then
        return SET_NORMAL
    elseif name == SET_TRADE or name == (LO["Trade Bags"] or SET_TRADE) then
        return SET_TRADE
    end

    return name
end

-- ============================================================================
-- HELPERS
-- ============================================================================

local function GetCombuctorDB()
    local mc = addon.db.profile.modules and addon.db.profile.modules.combuctor
    return mc and mc.db
end

local function IsCombuctorEnabled()
    local mc = addon.db.profile.modules and addon.db.profile.modules.combuctor
    return mc and mc.enabled
end

local VALID_BAGSORT_HOTKEYS = {
    ALT_LEFT = true,
    CTRL_LEFT = true,
    SHIFT_LEFT = true,
    ALT_RIGHT = true,
    CTRL_RIGHT = true,
    SHIFT_RIGHT = true,
    ALT_MIDDLE = true,
    CTRL_MIDDLE = true,
    SHIFT_MIDDLE = true,
}

local function NormalizeBagSortHotkey(value)
    if type(value) ~= "string" then
        return "ALT_LEFT"
    end

    local normalized = string.upper(value)
    if VALID_BAGSORT_HOTKEYS[normalized] then
        return normalized
    end

    return "ALT_LEFT"
end

local function GetBagSortConfig(create)
    if not addon.db or not addon.db.profile then return nil end
    if create and not addon.db.profile.modules then
        addon.db.profile.modules = {}
    end

    local modules = addon.db.profile.modules
    if not modules then return nil end

    if create and not modules.bagsort then
        modules.bagsort = {}
    end

    return modules.bagsort
end

local function HasSetInDB(setName)
    local db = GetCombuctorDB()
    if not db or not db.inventory or not db.inventory.sets then return false end
    local normalizedName = NormalizeCombuctorSetName(setName)
    for _, s in ipairs(db.inventory.sets) do
        if NormalizeCombuctorSetName(s) == normalizedName then return true end
    end
    return false
end

local function HasBankSetInDB(setName)
    local db = GetCombuctorDB()
    if not db or not db.bank or not db.bank.sets then return false end
    local normalizedName = NormalizeCombuctorSetName(setName)
    for _, s in ipairs(db.bank.sets) do
        if NormalizeCombuctorSetName(s) == normalizedName then return true end
    end
    return false
end

local function ToggleSetInList(sets, setName, enabled)
    if not sets then return end
    local normalizedName = NormalizeCombuctorSetName(setName)
    if enabled then
        local found = false
        for _, s in ipairs(sets) do
            if NormalizeCombuctorSetName(s) == normalizedName then found = true; break end
        end
        if not found then
            if normalizedName == SET_ALL then
                table.insert(sets, 1, normalizedName)
            else
                table.insert(sets, normalizedName)
            end
        end
    else
        for i = #sets, 1, -1 do
            if NormalizeCombuctorSetName(sets[i]) == normalizedName then
                table.remove(sets, i)
            end
        end
    end
end

local function ToggleInventorySet(setName, enabled)
    local db = GetCombuctorDB()
    if db and db.inventory then
        ToggleSetInList(db.inventory.sets, setName, enabled)
    end
    if addon.RefreshCombuctorFrames then
        addon.RefreshCombuctorFrames()
    end
end

local function ToggleBankSet(setName, enabled)
    local db = GetCombuctorDB()
    if db and db.bank then
        ToggleSetInList(db.bank.sets, setName, enabled)
    end
    if addon.RefreshCombuctorFrames then
        addon.RefreshCombuctorFrames()
    end
end

-- Subtab exclude helpers
local function IsSubtabExcluded(key, parentName, childName)
    local db = GetCombuctorDB()
    if not db or not db[key] or not db[key].exclude then return false end
    local normalizedParent = NormalizeCombuctorSetName(parentName)
    local normalizedChild = NormalizeCombuctorSetName(childName)
    local list = db[key].exclude[normalizedParent] or db[key].exclude[parentName]
    if not list then return false end
    for _, name in ipairs(list) do
        if NormalizeCombuctorSetName(name) == normalizedChild then return true end
    end
    return false
end

local function ToggleSubtab(parentName, childName, enabled)
    local db = GetCombuctorDB()
    if not db then return end
    local normalizedParent = NormalizeCombuctorSetName(parentName)
    local normalizedChild = NormalizeCombuctorSetName(childName)
    for _, key in ipairs({"inventory", "bank"}) do
        if db[key] then
            if not db[key].exclude then db[key].exclude = {} end
            if enabled then
                local list = db[key].exclude[normalizedParent] or db[key].exclude[parentName]
                if list then
                    for i = #list, 1, -1 do
                        if NormalizeCombuctorSetName(list[i]) == normalizedChild then table.remove(list, i) end
                    end
                    if #list == 0 then
                        db[key].exclude[normalizedParent] = nil
                        db[key].exclude[parentName] = nil
                    end
                end
            else
                if not db[key].exclude[normalizedParent] then db[key].exclude[normalizedParent] = {} end
                local list = db[key].exclude[normalizedParent]
                local found = false
                for _, name in ipairs(list) do
                    if NormalizeCombuctorSetName(name) == normalizedChild then found = true; break end
                end
                if not found then table.insert(list, normalizedChild) end
            end
        end
    end

    if addon.RefreshCombuctorFrames then
        addon.RefreshCombuctorFrames()
    end
end

-- ============================================================================
-- TAB BUILDER
-- ============================================================================

local function BuildBagsTab(scroll)
    C:AddLabel(scroll, "|cffFFD700" .. LO["Bags"] .. "|r", { color = C.Theme.textGold })
    C:AddDescription(scroll, LO["Configure Combuctor bag replacement settings."])
    C:AddSpacer(scroll)

    -- ====================================================================
    -- BAG BAR
    -- ====================================================================
    local bagBarSection = C:AddSection(scroll, LO["Bags"])

    C:AddSlider(bagBarSection, {
        label = LO["Bag Bar Scale"],
        dbPath = "bags.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = function()
            if addon.RefreshBagsPosition then addon.RefreshBagsPosition() end
        end,
    })

    local bagVisibility = C:AddSection(scroll, LO["Visibility"])
    local logicValues = {
        ["and"] = LO["AND (both required)"],
        ["or"] = LO["OR (either condition)"],
    }

    C:AddToggle(bagVisibility, {
        label = LO["Show on Hover Only"],
        dbPath = "actionbars.bag_show_on_hover",
        callback = RefreshVisibilityAndCollapsedBags,
    })

    C:AddToggle(bagVisibility, {
        label = LO["Show in Combat Only"],
        dbPath = "actionbars.bag_show_in_combat",
        callback = RefreshVisibilityAndCollapsedBags,
    })

    C:AddSlider(bagVisibility, {
        label = LO["Visible Alpha"],
        desc = LO["Opacity when a bar is considered visible by hover/combat rules."],
        dbPath = "actionbars.bag_visibility_shown_alpha",
        min = 0, max = 1, step = 0.01,
        isPercent = true,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(bagVisibility, {
        label = LO["Hidden Alpha"],
        desc = LO["Opacity when a bar is hidden by hover/combat rules. Set above 0 to keep bars faintly visible."],
        dbPath = "actionbars.bag_visibility_hidden_alpha",
        min = 0, max = 1, step = 0.01,
        isPercent = true,
        width = 250,
        callback = RefreshVisibilityAndCollapsedBags,
    })

    C:AddSlider(bagVisibility, {
        label = LO["Fade In Duration"],
        desc = LO["Seconds used to fade bars in when they become visible."],
        dbPath = "actionbars.bag_visibility_fade_in_duration",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(bagVisibility, {
        label = LO["Fade Out Duration"],
        desc = LO["Seconds used to fade bars out when they become hidden."],
        dbPath = "actionbars.bag_visibility_fade_out_duration",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddSlider(bagVisibility, {
        label = LO["Fade Out Delay"],
        desc = LO["Delay before hover-out starts fading, useful to avoid flicker between buttons."],
        dbPath = "actionbars.bag_visibility_fade_out_delay",
        min = 0, max = 1, step = 0.01,
        width = 250,
        callback = RefreshVisibility,
    })

    C:AddDropdown(bagVisibility, {
        label = LO["Hover/Combat Logic"],
        desc = LO["When both hover and combat are enabled, choose whether both are required (AND) or either condition is enough (OR)."],
        dbPath = "actionbars.bag_visibility_logic",
        values = logicValues,
        callback = RefreshVisibility,
    })

    -- ====================================================================
    -- COMBUCTOR ENABLE
    -- ====================================================================
    local mainSection = C:AddSection(scroll, LO["Combuctor"])

    C:AddToggle(mainSection, {
        label = LO["Enable Combuctor"],
        desc = LO["All-in-one bag replacement with item filtering, search, quality indicators, and bank integration."],
        getFunc = function() return IsCombuctorEnabled() end,
        setFunc = function(val)
            if not addon.db.profile.modules then addon.db.profile.modules = {} end
            if not addon.db.profile.modules.combuctor then addon.db.profile.modules.combuctor = {} end
            addon.db.profile.modules.combuctor.enabled = val
        end,
        requiresReload = true,
    })

    -- ====================================================================
    -- BAG SORT
    -- ====================================================================
    local sortSection = C:AddSection(scroll, LO["Bag Sort"] or "Bag Sort")
    C:AddDescription(sortSection, LO["Sort buttons for bags and bank. Sorts items by type, rarity, level, and name."] or "Sort buttons for bags and bank. Sorts items by type, rarity, level, and name.")

    C:AddToggle(sortSection, {
        label = LO["Enable Bag Sort"] or "Enable Bag Sort",
        desc = LO["Add sort buttons to bag and bank frames. Also enables /sort and /sortbank slash commands."] or "Add sort buttons to bag and bank frames. Also enables /sort and /sortbank slash commands.",
        getFunc = function()
            local mc = GetBagSortConfig(false)
            return mc and mc.enabled
        end,
        setFunc = function(val)
            local cfg = GetBagSortConfig(true)
            if cfg then
                cfg.enabled = val
            end
        end,
        requiresReload = true,
    })

    local hotkeyValues = {
        ALT_LEFT = LO["Alt + Left Click"] or "Alt + Left Click",
        CTRL_LEFT = LO["Ctrl + Left Click"] or "Ctrl + Left Click",
        SHIFT_LEFT = LO["Shift + Left Click"] or "Shift + Left Click",
        ALT_RIGHT = LO["Alt + Right Click"] or "Alt + Right Click",
        CTRL_RIGHT = LO["Ctrl + Right Click"] or "Ctrl + Right Click",
        SHIFT_RIGHT = LO["Shift + Right Click"] or "Shift + Right Click",
        ALT_MIDDLE = LO["Alt + Middle Click"] or "Alt + Middle Click",
        CTRL_MIDDLE = LO["Ctrl + Middle Click"] or "Ctrl + Middle Click",
        SHIFT_MIDDLE = LO["Shift + Middle Click"] or "Shift + Middle Click",
    }

    C:AddDropdown(sortSection, {
        label = LO["Lock Toggle Hotkey"] or "Lock Toggle Hotkey",
        desc = LO["Choose the modifier + mouse button used to lock or unlock a bag slot while hovering it."] or "Choose the modifier + mouse button used to lock or unlock a bag slot while hovering it.",
        values = hotkeyValues,
        getFunc = function()
            local cfg = GetBagSortConfig(true)
            if not cfg then return "ALT_LEFT" end
            cfg.lock_hotkey = NormalizeBagSortHotkey(cfg.lock_hotkey)
            return cfg.lock_hotkey
        end,
        setFunc = function(value)
            local cfg = GetBagSortConfig(true)
            if cfg then
                cfg.lock_hotkey = NormalizeBagSortHotkey(value)
            end
        end,
        disabled = function()
            local cfg = GetBagSortConfig(false)
            return not (cfg and cfg.enabled)
        end,
        width = 240,
    })

    C:AddDescription(sortSection, LO["Use /sortlock to lock or unlock the currently hovered slot from chat."] or "Use /sortlock to lock or unlock the currently hovered slot from chat.")

    C:AddColorPicker(sortSection, {
        label = LO["Lock Icon Color"] or "Lock Icon Color",
        getFunc = function()
            local cfg = GetBagSortConfig(false)
            local c = (cfg and cfg.lock_color) or addon.BagSortDefaultLockColor or { 0.15, 0.80, 1.00, 0.95 }
            return c[1] or 0.15, c[2] or 0.80, c[3] or 1.00, c[4] or 0.95
        end,
        setFunc = function(r, g, b, a)
            local cfg = GetBagSortConfig(true)
            if cfg then
                cfg.lock_color = { r, g, b, a }
            end
            if addon.RefreshBagSortLockMarkers then addon.RefreshBagSortLockMarkers() end
        end,
        hasAlpha = true,
        disabled = function()
            local cfg = GetBagSortConfig(false)
            return not (cfg and cfg.enabled)
        end,
    })
    C:AddDescription(sortSection, LO["Color used to tint the padlock icon shown on locked bag/bank slots."] or "Color used to tint the padlock icon shown on locked bag/bank slots.")

    -- ====================================================================
    -- INVENTORY CATEGORY TABS
    -- ====================================================================
    local tabSection = C:AddSection(scroll, LO["Inventory Tabs"])
    C:AddDescription(tabSection, LO["Choose which category tabs appear on the inventory bag frame."])

    -- "All" tab
    C:AddToggle(tabSection, {
        label = LO["Show 'All' Tab"],
        desc = LO["Show the 'All' category tab that displays all items without filtering."],
        getFunc = function() return HasSetInDB(SET_ALL) end,
        setFunc = function(val) ToggleInventorySet(SET_ALL, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Category tabs (matching KPack Combuctor set names)
    local Equipment = SET_EQUIPMENT
    local Usable = SET_USABLE
    local Weapon, Armor, _, Consumable, _, TradeGood, _, _, Recipe, Gem, Misc, Quest = GetAuctionItemClasses()
    local Devices = select(10, GetAuctionItemSubClasses(6))

    C:AddToggle(tabSection, {
        label = LO["Show Equipment Tab"],
        desc = LO["Show the Equipment category tab for armor and weapons."],
        getFunc = function() return HasSetInDB(Equipment) end,
        setFunc = function(val) ToggleInventorySet(Equipment, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Usable
    C:AddToggle(tabSection, {
        label = LO["Show Usable Tab"],
        desc = LO["Show the Usable category tab for consumables and devices."],
        getFunc = function() return HasSetInDB(Usable) end,
        setFunc = function(val) ToggleInventorySet(Usable, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Quest
    C:AddToggle(tabSection, {
        label = LO["Show Quest Tab"],
        desc = LO["Show the Quest items category tab."],
        getFunc = function() return HasSetInDB(Quest) end,
        setFunc = function(val) ToggleInventorySet(Quest, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Trade Goods
    C:AddToggle(tabSection, {
        label = LO["Show Trade Goods Tab"],
        desc = LO["Show the Trade Goods category tab (includes gems and recipes)."],
        getFunc = function() return HasSetInDB(TradeGood) end,
        setFunc = function(val) ToggleInventorySet(TradeGood, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Miscellaneous
    C:AddToggle(tabSection, {
        label = LO["Show Miscellaneous Tab"],
        desc = LO["Show the Miscellaneous items category tab."],
        getFunc = function() return HasSetInDB(Misc) end,
        setFunc = function(val) ToggleInventorySet(Misc, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- ====================================================================
    -- BANK CATEGORY TABS
    -- ====================================================================
    local bankSection = C:AddSection(scroll, LO["Bank Tabs"])
    C:AddDescription(bankSection, LO["Choose which category tabs appear on the bank frame."])

    C:AddToggle(bankSection, {
        label = LO["Show 'All' Tab"],
        desc = LO["Show the 'All' category tab that displays all items without filtering."],
        getFunc = function() return HasBankSetInDB(SET_ALL) end,
        setFunc = function(val) ToggleBankSet(SET_ALL, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Equipment Tab"],
        desc = LO["Show the Equipment category tab for armor and weapons."],
        getFunc = function() return HasBankSetInDB(Equipment) end,
        setFunc = function(val) ToggleBankSet(Equipment, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Usable Tab"],
        desc = LO["Show the Usable category tab for consumables and devices."],
        getFunc = function() return HasBankSetInDB(Usable) end,
        setFunc = function(val) ToggleBankSet(Usable, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Quest Tab"],
        desc = LO["Show the Quest items category tab."],
        getFunc = function() return HasBankSetInDB(Quest) end,
        setFunc = function(val) ToggleBankSet(Quest, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Trade Goods Tab"],
        desc = LO["Show the Trade Goods category tab (includes gems and recipes)."],
        getFunc = function() return HasBankSetInDB(TradeGood) end,
        setFunc = function(val) ToggleBankSet(TradeGood, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Miscellaneous Tab"],
        desc = LO["Show the Miscellaneous items category tab."],
        getFunc = function() return HasBankSetInDB(Misc) end,
        setFunc = function(val) ToggleBankSet(Misc, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- ====================================================================
    -- SUBTABS (BOTTOM FILTER TABS)
    -- ====================================================================
    local subtabSection = C:AddSection(scroll, LO["Subtabs"])
    C:AddDescription(subtabSection, LO["Configure which bottom subtabs appear within each category tab. Applies to both inventory and bank."])

    -- "All" category subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. (LO["All"] or SET_ALL) .. "|r")
    C:AddToggle(subtabSection, {
        label = LO["Normal"],
        desc = LO["Show the Normal bags subtab (non-profession bags)."],
        getFunc = function() return not IsSubtabExcluded("inventory", SET_ALL, SET_NORMAL) end,
        setFunc = function(val) ToggleSubtab(SET_ALL, SET_NORMAL, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = LO["Trade Bags"],
        desc = LO["Show the Trade bags subtab (profession bags)."],
        getFunc = function() return not IsSubtabExcluded("inventory", SET_ALL, SET_TRADE) end,
        setFunc = function(val) ToggleSubtab(SET_ALL, SET_TRADE, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Equipment subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. (LO["Equipment"] or Equipment) .. "|r")
    C:AddToggle(subtabSection, {
        label = Armor,
        desc = LO["Show the Armor subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Equipment, Armor) end,
        setFunc = function(val) ToggleSubtab(Equipment, Armor, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Weapon,
        desc = LO["Show the Weapon subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Equipment, Weapon) end,
        setFunc = function(val) ToggleSubtab(Equipment, Weapon, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = INVTYPE_TRINKET,
        desc = LO["Show the Trinket subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Equipment, INVTYPE_TRINKET) end,
        setFunc = function(val) ToggleSubtab(Equipment, INVTYPE_TRINKET, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Usable subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. (LO["Usable"] or Usable) .. "|r")
    C:AddToggle(subtabSection, {
        label = Consumable,
        desc = LO["Show the Consumable subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Usable, Consumable) end,
        setFunc = function(val) ToggleSubtab(Usable, Consumable, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Devices,
        desc = LO["Show the Devices subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Usable, Devices) end,
        setFunc = function(val) ToggleSubtab(Usable, Devices, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- Trade Goods subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. TradeGood .. "|r")
    C:AddToggle(subtabSection, {
        label = TradeGood,
        desc = LO["Show the Trade Goods subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", TradeGood, TradeGood) end,
        setFunc = function(val) ToggleSubtab(TradeGood, TradeGood, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Gem,
        desc = LO["Show the Gem subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", TradeGood, Gem) end,
        setFunc = function(val) ToggleSubtab(TradeGood, Gem, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Recipe,
        desc = LO["Show the Recipe subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", TradeGood, Recipe) end,
        setFunc = function(val) ToggleSubtab(TradeGood, Recipe, val) end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    -- ====================================================================
    -- DISPLAY OPTIONS
    -- ====================================================================
    local displaySection = C:AddSection(scroll, LO["Display"])

    C:AddToggle(displaySection, {
        label = LO["Left Side Tabs"] .. " (" .. LO["Inventory"] .. ")",
        desc = LO["Place category filter tabs on the left side of the bag frame instead of the right."],
        getFunc = function()
            local db = GetCombuctorDB()
            return db and db.inventory and db.inventory.leftSideFilter or false
        end,
        setFunc = function(val)
            local db = GetCombuctorDB()
            if db and db.inventory then db.inventory.leftSideFilter = val end
            if addon.RefreshCombuctorFrames then addon.RefreshCombuctorFrames() end
        end,
        disabled = function() return not IsCombuctorEnabled() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Left Side Tabs"] .. " (" .. LO["Bank"] .. ")",
        desc = LO["Place category filter tabs on the left side of the bank frame instead of the right."],
        getFunc = function()
            local db = GetCombuctorDB()
            return db and db.bank and db.bank.leftSideFilter or false
        end,
        setFunc = function(val)
            local db = GetCombuctorDB()
            if db and db.bank then db.bank.leftSideFilter = val end
            if addon.RefreshCombuctorFrames then addon.RefreshCombuctorFrames() end
        end,
        disabled = function() return not IsCombuctorEnabled() end,
    })
end

-- Register the tab
Panel:RegisterTab("bags", LO["Bags"], BuildBagsTab, 13)
