--[[
================================================================================
DragonUI Options Panel - Bags Tab
================================================================================
Bagster settings: enable/disable, category tabs, left/right side filter.
================================================================================
]]

local addon = DragonUI
if not addon then return end

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

local function NormalizeBagsterSetName(name)
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

local function GetBagsterDB()
    local mc = addon.db.profile.modules and addon.db.profile.modules.bagster
    return mc and mc.db
end

local function IsBagsterEnabled()
    local mc = addon.db.profile.modules and addon.db.profile.modules.bagster
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

local function GetAltMoneyConfig(create)
    if not addon.db or not addon.db.profile then return nil end
    if create and not addon.db.profile.modules then
        addon.db.profile.modules = {}
    end

    local modules = addon.db.profile.modules
    if not modules then return nil end

    if create and not modules.altmoney then
        modules.altmoney = {}
    end

    return modules.altmoney
end

local function HasSetInDB(setName)
    local db = GetBagsterDB()
    if not db or not db.inventory or not db.inventory.sets then return false end
    local normalizedName = NormalizeBagsterSetName(setName)
    for _, s in ipairs(db.inventory.sets) do
        if NormalizeBagsterSetName(s) == normalizedName then return true end
    end
    return false
end

local function HasBankSetInDB(setName)
    local db = GetBagsterDB()
    if not db or not db.bank or not db.bank.sets then return false end
    local normalizedName = NormalizeBagsterSetName(setName)
    for _, s in ipairs(db.bank.sets) do
        if NormalizeBagsterSetName(s) == normalizedName then return true end
    end
    return false
end

local function ToggleSetInList(sets, setName, enabled)
    if not sets then return end
    local normalizedName = NormalizeBagsterSetName(setName)
    if enabled then
        local found = false
        for _, s in ipairs(sets) do
            if NormalizeBagsterSetName(s) == normalizedName then found = true; break end
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
            if NormalizeBagsterSetName(sets[i]) == normalizedName then
                table.remove(sets, i)
            end
        end
    end
end

local function ToggleInventorySet(setName, enabled)
    local db = GetBagsterDB()
    if db and db.inventory then
        ToggleSetInList(db.inventory.sets, setName, enabled)
    end
    if addon.RefreshBagsterFrames then
        addon.RefreshBagsterFrames()
    end
end

local function ToggleBankSet(setName, enabled)
    local db = GetBagsterDB()
    if db and db.bank then
        ToggleSetInList(db.bank.sets, setName, enabled)
    end
    if addon.RefreshBagsterFrames then
        addon.RefreshBagsterFrames()
    end
end

-- Subtab exclude helpers
local function IsSubtabExcluded(key, parentName, childName)
    local db = GetBagsterDB()
    if not db or not db[key] or not db[key].exclude then return false end
    local normalizedParent = NormalizeBagsterSetName(parentName)
    local normalizedChild = NormalizeBagsterSetName(childName)
    local list = db[key].exclude[normalizedParent] or db[key].exclude[parentName]
    if not list then return false end
    for _, name in ipairs(list) do
        if NormalizeBagsterSetName(name) == normalizedChild then return true end
    end
    return false
end

local function ToggleSubtab(parentName, childName, enabled)
    local db = GetBagsterDB()
    if not db then return end
    local normalizedParent = NormalizeBagsterSetName(parentName)
    local normalizedChild = NormalizeBagsterSetName(childName)
    for _, key in ipairs({"inventory", "bank"}) do
        if db[key] then
            if not db[key].exclude then db[key].exclude = {} end
            if enabled then
                local list = db[key].exclude[normalizedParent] or db[key].exclude[parentName]
                if list then
                    for i = #list, 1, -1 do
                        if NormalizeBagsterSetName(list[i]) == normalizedChild then table.remove(list, i) end
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
                    if NormalizeBagsterSetName(name) == normalizedChild then found = true; break end
                end
                if not found then table.insert(list, normalizedChild) end
            end
        end
    end

    if addon.RefreshBagsterFrames then
        addon.RefreshBagsterFrames()
    end
end

-- ============================================================================
-- TAB BUILDER
-- ============================================================================

local function BuildBagsTab(scroll)
    C:AddLabel(scroll, "|cffFFD700" .. LO["Bags"] .. "|r", { color = C.Theme.textGold })
    C:AddDescription(scroll, LO["Configure Bagster bag replacement settings."])
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
        label = LO["Always Hidden"],
        dbPath = "actionbars.bag_always_hidden",
        callback = RefreshVisibilityAndCollapsedBags,
    })

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
    -- ITEM USABILITY TINT (stock bags + Bagster)
    -- ====================================================================
    local tintSection = C:AddSection(scroll, LO["Item Usability"] or "Item Usability")
    C:AddToggle(tintSection, {
        label = LO["Tint Unusable Items"] or "Tint Unusable Items",
        desc = LO["Color icons red for gear and usable items your character cannot equip or use (wrong armor type, level, class, etc.)."]
            or "Color icons red for gear and usable items your character cannot equip or use (wrong armor type, level, class, etc.).",
        getFunc = function()
            local bags = addon.db and addon.db.profile and addon.db.profile.bags
            return bags and bags.tint_unusable and true or false
        end,
        setFunc = function(val)
            if not addon.db.profile.bags then addon.db.profile.bags = {} end
            addon.db.profile.bags.tint_unusable = val and true or false
            if addon.RefreshUnusableItemTints then
                addon:RefreshUnusableItemTints()
            end
        end,
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

    C:AddToggle(sortSection, {
        label = LO["Fill Bank Stacks from Bags"] or "Fill Bank Stacks from Bags",
        desc = LO["Pull matching items from your bags into partial bank stacks when sorting the bank."] or "Pull matching items from your bags into partial bank stacks when sorting the bank.",
        getFunc = function()
            local cfg = GetBagSortConfig(false)
            if not cfg or cfg.bank_fill_from_bags == nil then
                return true
            end
            return cfg.bank_fill_from_bags
        end,
        setFunc = function(val)
            local cfg = GetBagSortConfig(true)
            if cfg then
                cfg.bank_fill_from_bags = val
            end
        end,
        disabled = function()
            local cfg = GetBagSortConfig(false)
            return not (cfg and cfg.enabled)
        end,
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

    C:AddToggle(sortSection, {
        label = LO["Reverse Stack Order"] or "Reverse Stack Order",
        desc = LO["Stack sorted items from the end of each bag so empty slots stay at the top."] or "Stack sorted items from the end of each bag so empty slots stay at the top.",
        getFunc = function()
            local cfg = GetBagSortConfig(false)
            return cfg and cfg.reverse_stack
        end,
        setFunc = function(val)
            local cfg = GetBagSortConfig(true)
            if cfg then cfg.reverse_stack = val end
        end,
        disabled = function()
            local cfg = GetBagSortConfig(false)
            return not (cfg and cfg.enabled)
        end,
    })

    -- ====================================================================
    -- ALT GOLD
    -- ====================================================================
    local altMoneySection = C:AddSection(scroll, LO["Alt Gold"] or "Alt Gold")
    C:AddDescription(altMoneySection, LO["Hover the coins in your bags to list the gold of every character that has logged in with DragonUI."] or "Hover the coins in your bags to list the gold of every character that has logged in with DragonUI.")

    C:AddToggle(altMoneySection, {
        label = LO["Enable Alt Gold"] or "Enable Alt Gold",
        desc = LO["Show a tooltip with your other characters' gold when hovering the money in bags."] or "Show a tooltip with your other characters' gold when hovering the money in bags.",
        getFunc = function()
            local cfg = GetAltMoneyConfig(false)
            return cfg and cfg.enabled
        end,
        setFunc = function(val)
            local cfg = GetAltMoneyConfig(true)
            if cfg then cfg.enabled = val end
            -- Hooks are installed lazily, so a first-time enable needs Apply to reach the stock bag frames.
            if val and addon.ApplyAltMoneySystem then addon.ApplyAltMoneySystem() end
        end,
    })

    C:AddToggle(altMoneySection, {
        label = LO["Show All Realms"] or "Show All Realms",
        desc = LO["List characters from every realm instead of only the realm you are playing on."] or "List characters from every realm instead of only the realm you are playing on.",
        getFunc = function()
            local cfg = GetAltMoneyConfig(false)
            return cfg and cfg.show_all_realms
        end,
        setFunc = function(val)
            local cfg = GetAltMoneyConfig(true)
            if cfg then cfg.show_all_realms = val end
        end,
        disabled = function()
            local cfg = GetAltMoneyConfig(false)
            return not (cfg and cfg.enabled)
        end,
    })

    -- ====================================================================
    -- BAGSTER ENABLE
    -- ====================================================================
    local mainSection = C:AddSection(scroll, LO["Bagster"])

    C:AddToggle(mainSection, {
        label = LO["Enable Bagster"],
        desc = LO["All-in-one bag replacement with item filtering, search, quality indicators, and bank integration."],
        getFunc = function() return IsBagsterEnabled() end,
        setFunc = function(val)
            if not addon.db.profile.modules then addon.db.profile.modules = {} end
            if not addon.db.profile.modules.bagster then addon.db.profile.modules.bagster = {} end
            addon.db.profile.modules.bagster.enabled = val
        end,
        requiresReload = true,
    })

    -- Everything below is Bagster-only; the enable toggle reloads, so the panel rebuilds right
    if not IsBagsterEnabled() then
        return
    end

    -- ====================================================================
    -- DISPLAY OPTIONS
    -- ====================================================================
    local displaySection = C:AddSection(scroll, LO["Display"])

    C:AddToggle(displaySection, {
        label = LO["Left Side Tabs"] .. " (" .. LO["Inventory"] .. ")",
        desc = LO["Place category filter tabs on the left side of the bag frame instead of the right."],
        getFunc = function()
            local db = GetBagsterDB()
            return db and db.inventory and db.inventory.leftSideFilter or false
        end,
        setFunc = function(val)
            local db = GetBagsterDB()
            if db and db.inventory then db.inventory.leftSideFilter = val end
            if addon.RefreshBagsterFrames then addon.RefreshBagsterFrames() end
        end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Left Side Tabs"] .. " (" .. LO["Bank"] .. ")",
        desc = LO["Place category filter tabs on the left side of the bank frame instead of the right."],
        getFunc = function()
            local db = GetBagsterDB()
            return db and db.bank and db.bank.leftSideFilter or false
        end,
        setFunc = function(val)
            local db = GetBagsterDB()
            if db and db.bank then db.bank.leftSideFilter = val end
            if addon.RefreshBagsterFrames then addon.RefreshBagsterFrames() end
        end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    local moneyValues = {
        text = (LO["Text Only"]) or "Text Only",
        icons = (LO["Gold Icons"]) or "Gold Icons",
    }
    C:AddDropdown(displaySection, {
        label = LO["Gold Display"] or "Gold Display",
        values = moneyValues,
        getFunc = function()
            local mc = addon.db.profile.modules and addon.db.profile.modules.bagster
            return (mc and mc.money_display) or "icons"
        end,
        setFunc = function(val)
            if not addon.db.profile.modules then addon.db.profile.modules = {} end
            if not addon.db.profile.modules.bagster then addon.db.profile.modules.bagster = {} end
            addon.db.profile.modules.bagster.money_display = val
            if addon.RefreshBagsterFrames then addon.RefreshBagsterFrames() end
        end,
        disabled = function() return not IsBagsterEnabled() end,
        width = 180,
    })

    local function GetBagsterConfig(create)
        if create then
            if not addon.db.profile.modules then addon.db.profile.modules = {} end
            if not addon.db.profile.modules.bagster then addon.db.profile.modules.bagster = {} end
        end
        return addon.db.profile.modules and addon.db.profile.modules.bagster
    end

    local function SetBagsterOption(key, val)
        local mc = GetBagsterConfig(true)
        mc[key] = val
        if addon.RefreshBagsterFrames then addon.RefreshBagsterFrames() end
    end

    C:AddSlider(displaySection, {
        label = LO["Item Scale"] or "Item Scale",
        desc = LO["Maximum size of item slots. The grid still shrinks them to fit the frame."] or "Maximum size of item slots. The grid still shrinks them to fit the frame.",
        min = 0.5, max = 1.5, step = 0.05, isPercent = true,
        getFunc = function()
            local mc = GetBagsterConfig(false)
            return (mc and mc.item_scale) or 1
        end,
        setFunc = function(val) SetBagsterOption("item_scale", val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddSlider(displaySection, {
        label = LO["Item Spacing"] or "Item Spacing",
        desc = LO["Gap between item slots in the grid."] or "Gap between item slots in the grid.",
        min = 0, max = 8, step = 1,
        getFunc = function()
            local mc = GetBagsterConfig(false)
            return (mc and mc.item_spacing) or 2
        end,
        setFunc = function(val) SetBagsterOption("item_spacing", val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Quality Filter Row"] or "Quality Filter Row",
        desc = LO["Show the rarity filter dots at the bottom of the bag frame."] or "Show the rarity filter dots at the bottom of the bag frame.",
        getFunc = function()
            local mc = GetBagsterConfig(false)
            return not mc or mc.show_quality_filter ~= false
        end,
        setFunc = function(val) SetBagsterOption("show_quality_filter", val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Quality Glow"] or "Quality Glow",
        desc = LO["Show a colored ring on uncommon and better items."] or "Show a colored ring on uncommon and better items.",
        getFunc = function()
            local mc = GetBagsterConfig(false)
            return not mc or mc.glow_quality ~= false
        end,
        setFunc = function(val) SetBagsterOption("glow_quality", val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Quest Item Glow"] or "Quest Item Glow",
        desc = LO["Highlight quest items with a golden border."] or "Highlight quest items with a golden border.",
        getFunc = function()
            local mc = GetBagsterConfig(false)
            return not mc or mc.glow_quest ~= false
        end,
        setFunc = function(val) SetBagsterOption("glow_quest", val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddSlider(displaySection, {
        label = LO["Glow Intensity"] or "Glow Intensity",
        desc = LO["Opacity of the quality ring on item slots."] or "Opacity of the quality ring on item slots.",
        min = 0.1, max = 1, step = 0.05, isPercent = true,
        getFunc = function()
            local mc = GetBagsterConfig(false)
            return (mc and mc.glow_alpha) or 1
        end,
        setFunc = function(val) SetBagsterOption("glow_alpha", val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- ====================================================================
    -- INVENTORY CATEGORY TABS
    -- ====================================================================
    local tabSection = C:AddSection(scroll, LO["Inventory Tabs"])
    C:AddDescription(tabSection, LO["Choose which category tabs appear on the inventory bag frame."])

    -- "All" tab
    C:AddToggle(tabSection, {
        label = LO["Show 'All' Tab"],
        tooltip = LO["Show the 'All' category tab that displays all items without filtering."],
        getFunc = function() return HasSetInDB(SET_ALL) end,
        setFunc = function(val) ToggleInventorySet(SET_ALL, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Category tabs (canonical set names)
    local Equipment = SET_EQUIPMENT
    local Usable = SET_USABLE
    local Weapon, Armor, _, Consumable, _, TradeGood, _, _, Recipe, Gem, Misc, Quest = GetAuctionItemClasses()
    local Devices = select(10, GetAuctionItemSubClasses(6))

    C:AddToggle(tabSection, {
        label = LO["Show Equipment Tab"],
        tooltip = LO["Show the Equipment category tab for armor and weapons."],
        getFunc = function() return HasSetInDB(Equipment) end,
        setFunc = function(val) ToggleInventorySet(Equipment, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Usable
    C:AddToggle(tabSection, {
        label = LO["Show Usable Tab"],
        tooltip = LO["Show the Usable category tab for consumables and devices."],
        getFunc = function() return HasSetInDB(Usable) end,
        setFunc = function(val) ToggleInventorySet(Usable, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Quest
    C:AddToggle(tabSection, {
        label = LO["Show Quest Tab"],
        tooltip = LO["Show the Quest items category tab."],
        getFunc = function() return HasSetInDB(Quest) end,
        setFunc = function(val) ToggleInventorySet(Quest, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Trade Goods
    C:AddToggle(tabSection, {
        label = LO["Show Trade Goods Tab"],
        tooltip = LO["Show the Trade Goods category tab (includes gems and recipes)."],
        getFunc = function() return HasSetInDB(TradeGood) end,
        setFunc = function(val) ToggleInventorySet(TradeGood, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Miscellaneous
    C:AddToggle(tabSection, {
        label = LO["Show Miscellaneous Tab"],
        tooltip = LO["Show the Miscellaneous items category tab."],
        getFunc = function() return HasSetInDB(Misc) end,
        setFunc = function(val) ToggleInventorySet(Misc, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- ====================================================================
    -- BANK CATEGORY TABS
    -- ====================================================================
    local bankSection = C:AddSection(scroll, LO["Bank Tabs"])
    C:AddDescription(bankSection, LO["Choose which category tabs appear on the bank frame."])

    C:AddToggle(bankSection, {
        label = LO["Show 'All' Tab"],
        tooltip = LO["Show the 'All' category tab that displays all items without filtering."],
        getFunc = function() return HasBankSetInDB(SET_ALL) end,
        setFunc = function(val) ToggleBankSet(SET_ALL, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Equipment Tab"],
        tooltip = LO["Show the Equipment category tab for armor and weapons."],
        getFunc = function() return HasBankSetInDB(Equipment) end,
        setFunc = function(val) ToggleBankSet(Equipment, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Usable Tab"],
        tooltip = LO["Show the Usable category tab for consumables and devices."],
        getFunc = function() return HasBankSetInDB(Usable) end,
        setFunc = function(val) ToggleBankSet(Usable, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Quest Tab"],
        tooltip = LO["Show the Quest items category tab."],
        getFunc = function() return HasBankSetInDB(Quest) end,
        setFunc = function(val) ToggleBankSet(Quest, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Trade Goods Tab"],
        tooltip = LO["Show the Trade Goods category tab (includes gems and recipes)."],
        getFunc = function() return HasBankSetInDB(TradeGood) end,
        setFunc = function(val) ToggleBankSet(TradeGood, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    C:AddToggle(bankSection, {
        label = LO["Show Miscellaneous Tab"],
        tooltip = LO["Show the Miscellaneous items category tab."],
        getFunc = function() return HasBankSetInDB(Misc) end,
        setFunc = function(val) ToggleBankSet(Misc, val) end,
        disabled = function() return not IsBagsterEnabled() end,
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
        tooltip = LO["Show the Normal bags subtab (non-profession bags)."],
        getFunc = function() return not IsSubtabExcluded("inventory", SET_ALL, SET_NORMAL) end,
        setFunc = function(val) ToggleSubtab(SET_ALL, SET_NORMAL, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = LO["Trade Bags"],
        tooltip = LO["Show the Trade bags subtab (profession bags)."],
        getFunc = function() return not IsSubtabExcluded("inventory", SET_ALL, SET_TRADE) end,
        setFunc = function(val) ToggleSubtab(SET_ALL, SET_TRADE, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Equipment subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. (LO["Equipment"] or Equipment) .. "|r")
    C:AddToggle(subtabSection, {
        label = Armor,
        tooltip = LO["Show the Armor subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Equipment, Armor) end,
        setFunc = function(val) ToggleSubtab(Equipment, Armor, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Weapon,
        tooltip = LO["Show the Weapon subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Equipment, Weapon) end,
        setFunc = function(val) ToggleSubtab(Equipment, Weapon, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = INVTYPE_TRINKET,
        tooltip = LO["Show the Trinket subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Equipment, INVTYPE_TRINKET) end,
        setFunc = function(val) ToggleSubtab(Equipment, INVTYPE_TRINKET, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Usable subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. (LO["Usable"] or Usable) .. "|r")
    C:AddToggle(subtabSection, {
        label = Consumable,
        tooltip = LO["Show the Consumable subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Usable, Consumable) end,
        setFunc = function(val) ToggleSubtab(Usable, Consumable, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Devices,
        tooltip = LO["Show the Devices subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", Usable, Devices) end,
        setFunc = function(val) ToggleSubtab(Usable, Devices, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

    -- Trade Goods subtabs
    C:AddLabel(subtabSection, "|cffAAAAAA" .. TradeGood .. "|r")
    C:AddToggle(subtabSection, {
        label = TradeGood,
        tooltip = LO["Show the Trade Goods subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", TradeGood, TradeGood) end,
        setFunc = function(val) ToggleSubtab(TradeGood, TradeGood, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Gem,
        tooltip = LO["Show the Gem subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", TradeGood, Gem) end,
        setFunc = function(val) ToggleSubtab(TradeGood, Gem, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })
    C:AddToggle(subtabSection, {
        label = Recipe,
        tooltip = LO["Show the Recipe subtab."],
        getFunc = function() return not IsSubtabExcluded("inventory", TradeGood, Recipe) end,
        setFunc = function(val) ToggleSubtab(TradeGood, Recipe, val) end,
        disabled = function() return not IsBagsterEnabled() end,
    })

end

-- Register the tab
Panel:RegisterTab("bags", LO["Bags"], BuildBagsTab, 13)
