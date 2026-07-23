local addon = select(2, ...)

-- ============================================================================
-- COMBUCTOR MODULE FOR DRAGONUI
-- All-in-one bag replacement with item filtering, search, bank integration.
-- ============================================================================

if _G.Combuctor then return end -- Don't load if standalone Combuctor is present

local _G = _G
local pairs, ipairs, next, select = pairs, ipairs, next, select
local format, strsplit = string.format, strsplit
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local tonumber, tostring, type = tonumber, tostring, type
local GetItemInfo, GetItemIcon = GetItemInfo, GetItemIcon
local GetContainerItemInfo, GetContainerItemLink = GetContainerItemInfo, GetContainerItemLink
local GetContainerItemCooldown, GetContainerNumSlots = GetContainerItemCooldown, GetContainerNumSlots
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetKeyRingSize = GetKeyRingSize
local GetNumBankSlots = GetNumBankSlots
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemCount = GetInventoryItemCount
local GetItemFamily = GetItemFamily
local IsInventoryItemLocked = IsInventoryItemLocked
local ContainerIDToInventoryID = ContainerIDToInventoryID
local BankButtonIDToInvSlotID = BankButtonIDToInvSlotID
local ContainerFrame_UpdateCooldown = ContainerFrame_UpdateCooldown
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local SetItemButtonCount = SetItemButtonCount
local SetItemButtonDesaturated, SetItemButtonTextureVertexColor = SetItemButtonDesaturated, SetItemButtonTextureVertexColor
local CursorHasItem, PickupContainerItem = CursorHasItem, PickupContainerItem
local SetPortraitTexture = SetPortraitTexture
local IsAltKeyDown = IsAltKeyDown
local PlaySound = PlaySound
local UnitName = UnitName
local GetRealmName = GetRealmName
local time = time
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS
local KEYRING_CONTAINER = KEYRING_CONTAINER
local BACKPACK_CONTAINER = BACKPACK_CONTAINER
local BANK_CONTAINER = BANK_CONTAINER
local NUM_BANKGENERIC_SLOTS = NUM_BANKGENERIC_SLOTS

local TEXTURE_ITEM_QUEST_BORDER = TEXTURE_ITEM_QUEST_BORDER or [[Interface\ContainerFrame\UI-ContainerQuestBorder]]
local TEXTURE_ITEM_QUEST_BANG = TEXTURE_ITEM_QUEST_BANG or [[Interface\ContainerFrame\UI-ContainerQuestBorder]]

local ItemSearch = LibStub("LibItemSearch-1.0")
local playerName = UnitName("player")
local playerClass = select(2, UnitClass("player"))

-- Module state tracking
local CombuctorModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    hooks = {},
    frames = {}
}

-- Register with ModuleRegistry
if addon.RegisterModule then
    addon:RegisterModule("combuctor", CombuctorModule,
        (addon.L and addon.L["Combuctor"]) or "Combuctor",
        (addon.L and addon.L["All-in-one bag replacement with filtering and search"]) or "All-in-one bag replacement with filtering and search")
end


-- ============================================================================
-- SELF-CONTAINED RETAIL SKINNING (no dependency on bags_skin)
-- ============================================================================

local CombuctorAssets = addon._dir

local CT = {
    slot_bg           = CombuctorAssets .. 'bagsitemslot2x',
    slot_depress      = CombuctorAssets .. 'ui-quickslot-depress',
    slot_highlight    = CombuctorAssets .. 'buttonhilight-square',
    frame_metal       = CombuctorAssets .. 'uiframemetal2x',
    frame_metal_h     = CombuctorAssets .. 'uiframemetalhorizontal2x',
    frame_metal_v     = CombuctorAssets .. 'uiframemetalvertical2x',
    frame_bg          = CombuctorAssets .. 'ui-background-rock',
    close_btn         = CombuctorAssets .. 'redbutton2x',
    bagslot           = CombuctorAssets .. 'bagslots2x',
    bag_border        = CombuctorAssets .. 'bagborder2',
    slot_border       = CombuctorAssets .. 'ui-quickslot2',
    tabs              = CombuctorAssets .. 'uiframetabs',
    sidetab           = CombuctorAssets .. 'sidetab',
    coinGold          = CombuctorAssets .. 'coingold',
    coinSilver        = CombuctorAssets .. 'coinsilver',
    coinCopper        = CombuctorAssets .. 'coincopper',
}


-- Retail-style nineslice border for Combuctor frames
local function CombuctorAddNineSlice(frame)
    if frame._BagSkin_NineSlice then return end

    local ns = {}
    frame._BagSkin_NineSlice = ns

    ns.TopLeftCorner     = frame:CreateTexture(nil, 'OVERLAY')
    ns.TopRightCorner    = frame:CreateTexture(nil, 'OVERLAY')
    ns.BottomLeftCorner  = frame:CreateTexture(nil, 'OVERLAY')
    ns.BottomRightCorner = frame:CreateTexture(nil, 'OVERLAY')
    ns.TopEdge           = frame:CreateTexture(nil, 'OVERLAY')
    ns.BottomEdge        = frame:CreateTexture(nil, 'OVERLAY')
    ns.LeftEdge          = frame:CreateTexture(nil, 'OVERLAY')
    ns.RightEdge         = frame:CreateTexture(nil, 'OVERLAY')

    local bg = CreateFrame('Frame', nil, frame)
    bg:SetPoint('TOPLEFT', frame, 'TOPLEFT', 2, -18)
    bg:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -3, 3)
    bg:SetFrameLevel(0)
    ns.Bg = bg

    local bgTex = bg:CreateTexture(nil, 'BACKGROUND')
    bgTex:SetTexture(CT.frame_bg)
    bgTex:SetAllPoints(bg)
    bgTex:SetAlpha(0.8)
    ns.BgTex = bgTex

    -- Corner variant with the big portrait circle baked in (bags_skin "large")
    local tlc = ns.TopLeftCorner
    tlc:SetTexture(CT.frame_metal)
    tlc:SetTexCoord(0.00195312, 0.294922, 0.298828, 0.591797)
    tlc:SetSize(75, 75)
    tlc:SetPoint('TOPLEFT', -13, 16)

    local trc = ns.TopRightCorner
    trc:SetTexture(CT.frame_metal)
    trc:SetTexCoord(0.298828, 0.591797, 0.00195312, 0.294922)
    trc:SetSize(75, 75)
    trc:SetPoint('TOPRIGHT', 4, 16)

    -- Same -13 as the top-left corner or the LeftEdge connects two misaligned corners
    local blc = ns.BottomLeftCorner
    blc:SetTexture(CT.frame_metal)
    blc:SetTexCoord(0.298828, 0.423828, 0.298828, 0.423828)
    blc:SetSize(32, 32)
    blc:SetPoint('BOTTOMLEFT', -13, -3)

    local brc = ns.BottomRightCorner
    brc:SetTexture(CT.frame_metal)
    brc:SetTexCoord(0.427734, 0.552734, 0.298828, 0.423828)
    brc:SetSize(32, 32)
    brc:SetPoint('BOTTOMRIGHT', 4, -3)

    local te = ns.TopEdge
    te:SetTexture(CT.frame_metal_h)
    te:SetTexCoord(0, 1, 0.00390625, 0.589844)
    te:SetSize(32, 75)
    te:SetPoint('TOPLEFT', tlc, 'TOPRIGHT', -4, 0)
    te:SetPoint('TOPRIGHT', trc, 'TOPLEFT', 4, 0)

    local be = ns.BottomEdge
    be:SetTexture(CT.frame_metal_h)
    be:SetTexCoord(0, 0.5, 0.597656, 0.847656)
    be:SetSize(16, 32)
    be:SetPoint('TOPLEFT', blc, 'TOPRIGHT', 0, 0)
    be:SetPoint('TOPRIGHT', brc, 'TOPLEFT', 0, 0)

    local le = ns.LeftEdge
    le:SetTexture(CT.frame_metal_v)
    le:SetTexCoord(0.00195312, 0.294922, 0, 1)
    le:SetSize(75, 16)
    le:SetPoint('TOPLEFT', tlc, 'BOTTOMLEFT', 0, 0)
    le:SetPoint('BOTTOMLEFT', blc, 'TOPLEFT', 0, 0)

    local re = ns.RightEdge
    re:SetTexture(CT.frame_metal_v)
    re:SetTexCoord(0.298828, 0.591797, 0, 1)
    re:SetSize(75, 16)
    re:SetPoint('TOPRIGHT', trc, 'BOTTOMRIGHT', 0, 0)
    re:SetPoint('BOTTOMRIGHT', brc, 'TOPRIGHT', 0, 0)

    local closeBtn = frame.ClosePanelButton or _G[frame:GetName() .. 'CloseButton']
    if closeBtn then
        closeBtn:SetSize(24, 24)
        local nt = closeBtn:GetNormalTexture()
        if nt then
            nt:SetTexture(CT.close_btn)
            nt:SetTexCoord(0.152344, 0.292969, 0.0078125, 0.304688)
        end
        local pt = closeBtn:GetPushedTexture()
        if pt then
            pt:SetTexture(CT.close_btn)
            pt:SetTexCoord(0.152344, 0.292969, 0.320312, 0.617188)
        end
    end
end

-- Retail-style item slot restyle for Combuctor item buttons
local function CombuctorRetailItemSlot(btn)
    if btn._BagSkin_Applied then return end
    btn._BagSkin_Applied = true

    local nt = btn:GetNormalTexture()
    if nt then
        nt:SetTexture(CT.slot_bg)
        nt:SetSize(37, 37)
        nt:ClearAllPoints()
        nt:SetPoint('CENTER', btn, 'CENTER')
        nt:SetDrawLayer('BACKGROUND')
        nt:Show()
        nt:SetAlpha(1)
    end

    -- Slot border ring overlay (64x64), reused from cache if present
    local border = btn._dragonuiSlotBorder
    if not border then
        border = btn:CreateTexture(nil, 'BORDER')
        btn._dragonuiSlotBorder = border
    end
    border:SetTexture(CT.slot_border)
    border:SetSize(64, 64)
    border:ClearAllPoints()
    border:SetPoint('CENTER', btn, 'CENTER', 0, -1)
    border:Show()

    local pt = btn:GetPushedTexture()
    if pt then
        pt:SetTexture(CT.slot_depress)
        pt:SetSize(37, 37)
        pt:ClearAllPoints()
        pt:SetPoint('CENTER', btn, 'CENTER')
    end

    local ht = btn:GetHighlightTexture()
    if ht then
        ht:SetTexture(CT.slot_highlight)
        ht:SetSize(37, 37)
        ht:ClearAllPoints()
        ht:SetPoint('CENTER', btn, 'CENTER')
    end

    local name = btn:GetName()
    if not name then return end

    local icon = _G[name .. 'IconTexture']
    if icon then
        icon:SetDrawLayer('BORDER')
        icon:SetTexCoord(0, 1, 0, 1)
        icon:ClearAllPoints()
        icon:SetAllPoints(btn)
        icon:Show()
    end

    local count = _G[name .. 'Count']
    if count then
        count:SetDrawLayer('BORDER')
    end

    local stock = _G[name .. 'Stock']
    if stock then
        stock:SetDrawLayer('BORDER')
    end
end


local function GetModuleConfig()
    return addon:GetModuleConfig("combuctor")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("combuctor")
end

-- ============================================================================
-- MODULE INTERNALS (minimal class factory and module registry)
-- ============================================================================

local mod = {}
mod.modules = {}

function mod:NewClass(ftype, parent)
    local class = CreateFrame(ftype)
    class:Hide()
    class.mt = { __index = class }
    if parent then
        class = setmetatable(class, { __index = parent })
        class.super = function(self, method, ...)
            return parent[method](self, ...)
        end
    end
    class.Bind = function(self, obj)
        return setmetatable(obj, self.mt)
    end
    return class
end

function mod:NewModule(name, proto)
    local m
    if proto then
        m = setmetatable({}, { __index = proto })
    else
        m = {}
    end
    self.modules[name] = m
    return m
end

function mod:GetModule(name)
    return self.modules[name]
end

-- Callable access: mod("ModuleName") returns module
setmetatable(mod, {
    __call = function(self, name)
        return self.modules[name]
    end
})

-- mod.CombuctorModule stays the registry metadata table; addon.CombuctorModule is the split-file namespace.
addon.CombuctorModule = mod

-- ============================================================================
-- DATABASE
-- ============================================================================

local DB
local SET_ALL = ALL or "All"
local SET_EQUIPMENT = "Equipment"
local SET_USABLE = "Usable"
local SET_NORMAL = "Normal"
local SET_TRADE = "Trade"

local defaults = {
    inventory = {
        -- KEYRING last: keys render after bag slots (BagBrother InventoryBags order)
        bags = { 0, 1, 2, 3, 4, KEYRING_CONTAINER },
        position = { "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -64, 64 },
        showBags = false,
        leftSideFilter = true,
        w = 384,
        h = 512,
        sets = {},
        exclude = {},
        hiddenBags = {}, -- BagBrother: per-bag filter; true = omit from item grid
    },
    bank = {
        bags = { -1, 5, 6, 7, 8, 9, 10, 11 },
        position = { "LEFT", nil, "LEFT", 24, 0 },
        showBags = false,
        leftSideFilter = false,
        w = 512,
        h = 512,
        sets = {},
        exclude = {},
        hiddenBags = {},
    },
    guild = {
        position = { "LEFT", nil, "LEFT", 24, 0 },
        w = 512,
        h = 512
    }
}

-- Localization strings
local L = {}
L.InventoryTitle = (addon.L and addon.L["%s's Inventory"]) or "%s's Inventory"
L.BankTitle = (addon.L and addon.L["%s's Bank"]) or "%s's Bank"
L.Inventory = (addon.L and addon.L["Inventory"]) or "Inventory"
L.Bank = (addon.L and addon.L["Bank"]) or "Bank"
L.Bags = (addon.L and addon.L["Bags"]) or "Bags"
L.BagToggle = (addon.L and addon.L["|cff00ff00Left-Click|r to toggle bag display"]) or "|cff00ff00Left-Click|r to toggle bag display"
L.InventoryToggle = (addon.L and addon.L["|cff00ff00Right-Click|r to toggle inventory"]) or "|cff00ff00Right-Click|r to toggle inventory"
L.BankToggle = (addon.L and addon.L["|cff00ff00Right-Click|r to toggle bank"]) or "|cff00ff00Right-Click|r to toggle bank"
L.MoveTip = (addon.L and addon.L["|cff00ff00Drag|r to move"]) or "|cff00ff00Drag|r to move"
L.ResetPositionTip = (addon.L and addon.L["|cff00ff00Alt+Right-Click|r to reset position"]) or "|cff00ff00Alt+Right-Click|r to reset position"
L.ToggleInventory = (addon.L and addon.L["Toggle Inventory"]) or "Toggle Inventory"
L.ToggleBank = (addon.L and addon.L["Toggle Bank"]) or "Toggle Bank"
L.ShowBag = (addon.L and addon.L["|cff00ff00Left-Click|r to show this bag's items"]) or "|cff00ff00Left-Click|r to show this bag's items"
L.HideBag = (addon.L and addon.L["|cff00ff00Left-Click|r to hide this bag's items"]) or "|cff00ff00Left-Click|r to hide this bag's items"
L.DragBag = (addon.L and addon.L["|cff00ff00Drag|r to move this bag"]) or "|cff00ff00Drag|r to move this bag"

local function GetSetDisplayName(name)
    if name == SET_EQUIPMENT then
        return (addon.L and addon.L["Equipment"]) or (addon.LO and addon.LO["Equipment"]) or name
    elseif name == SET_USABLE then
        return (addon.L and addon.L["Usable"]) or (addon.LO and addon.LO["Usable"]) or name
    elseif name == SET_NORMAL then
        return (addon.L and addon.L["Normal"]) or name
    elseif name == SET_TRADE then
        return (addon.L and addon.L["Trade"]) or name
    end
    return name
end

-- Localize auction item classes
L.Weapon, L.Armor, L.Container, L.Consumable, L.Glyph, L.TradeGood, _, _, L.Recipe, L.Gem, L.Misc, L.Quest = GetAuctionItemClasses()
L.Devices, L.Explosives = select(10, GetAuctionItemSubClasses(6))
L.SimpleGem = select(8, GetAuctionItemSubClasses(7))

local function SetupDatabase()
    if not addon.db then return end
    if not addon.db.profile.modules then addon.db.profile.modules = {} end
    if not addon.db.profile.modules.combuctor then addon.db.profile.modules.combuctor = {} end

    -- Option defaults live in database.lua (modules.combuctor); only the frame layout db is lazy
    local mc = addon.db.profile.modules.combuctor
    if not mc.db then mc.db = {} end

    DB = mc.db
    mod.DB = DB
    if not DB.inventory then
        DB.inventory = {}
        for k, v in pairs(defaults.inventory) do
            if type(v) == "table" then
                DB.inventory[k] = {}
                for kk, vv in pairs(v) do DB.inventory[k][kk] = vv end
            else
                DB.inventory[k] = v
            end
        end
    end
    if not DB.bank then
        DB.bank = {}
        for k, v in pairs(defaults.bank) do
            if type(v) == "table" then
                DB.bank[k] = {}
                for kk, vv in pairs(v) do DB.bank[k][kk] = vv end
            else
                DB.bank[k] = v
            end
        end
    end
    if not DB.guild then
        DB.guild = {}
        for k, v in pairs(defaults.guild) do
            if type(v) == "table" then
                DB.guild[k] = {}
                for kk, vv in pairs(v) do DB.guild[k][kk] = vv end
            else
                DB.guild[k] = v
            end
        end
    end
    if not DB.inventory.sets then DB.inventory.sets = {} end
    if not DB.inventory.exclude then DB.inventory.exclude = {} end
    if not DB.inventory.hiddenBags then DB.inventory.hiddenBags = {} end
    if not DB.bank.sets then DB.bank.sets = {} end
    if not DB.bank.exclude then DB.bank.exclude = {} end
    if not DB.bank.hiddenBags then DB.bank.hiddenBags = {} end

    -- Existing profiles predate keyring-in-inventory; append without wiping bag order
    if DB.inventory.bags then
        local hasKeyring = false
        for _, bagID in pairs(DB.inventory.bags) do
            if bagID == KEYRING_CONTAINER then
                hasKeyring = true
                break
            end
        end
        if not hasKeyring then
            tinsert(DB.inventory.bags, KEYRING_CONTAINER)
        end
    end

    local localizedEquipment = (addon.L and addon.L["Equipment"]) or (addon.LO and addon.LO["Equipment"])
    local localizedUsable = (addon.L and addon.L["Usable"]) or (addon.LO and addon.LO["Usable"])
    local function NormalizeLocalizedSetName(name)
        if not name then return name end
        if name == SET_EQUIPMENT or (localizedEquipment and name == localizedEquipment) then
            return SET_EQUIPMENT
        end
        if name == SET_USABLE or (localizedUsable and name == localizedUsable) then
            return SET_USABLE
        end
        return name
    end

    local function NormalizeSetList(list)
        if not list then return end
        for i, name in ipairs(list) do
            list[i] = NormalizeLocalizedSetName(name)
        end
    end

    local function NormalizeExcludeTable(exclude)
        if not exclude then return end
        local normalized = {}
        for parentName, childList in pairs(exclude) do
            normalized[NormalizeLocalizedSetName(parentName)] = childList
        end
        for key in pairs(exclude) do
            exclude[key] = nil
        end
        for key, value in pairs(normalized) do
            exclude[key] = value
        end
    end

    NormalizeSetList(DB.inventory.sets)
    NormalizeSetList(DB.bank.sets)
    NormalizeExcludeTable(DB.inventory.exclude)
    NormalizeExcludeTable(DB.bank.exclude)
end

function mod:GetProfile()
    return DB
end

-- ============================================================================
-- BAG TOGGLE
-- ============================================================================

function mod:Show(bag, auto)
    for _, frame in pairs(self.frames) do
        for _, bagID in pairs(frame.sets.bags) do
            if bagID == bag then
                frame:ShowFrame(auto)
                return
            end
        end
    end
end

function mod:Hide(bag, auto)
    for _, frame in pairs(self.frames) do
        for _, bagID in pairs(frame.sets.bags) do
            if bagID == bag then
                frame:HideFrame(auto)
                return
            end
        end
    end
end

function mod:Toggle(bag)
    for _, frame in pairs(self.frames) do
        for _, bagID in pairs(frame.sets.bags) do
            if bagID == bag then
                frame:ToggleFrame()
                return
            end
        end
    end
end

-- ============================================================================
-- SHARED LOCALS EXPORTED FOR THE SPLIT FILES
-- ============================================================================

mod.CT = CT
mod.L = L
mod.DB = DB
mod.defaults = defaults
mod.playerName = playerName
mod.ItemSearch = ItemSearch
mod.GetModuleConfig = GetModuleConfig
mod.IsModuleEnabled = IsModuleEnabled
mod.SetupDatabase = SetupDatabase
mod.CombuctorModule = CombuctorModule
mod.CombuctorAddNineSlice = CombuctorAddNineSlice
mod.CombuctorRetailItemSlot = CombuctorRetailItemSlot
mod.GetSetDisplayName = GetSetDisplayName
mod.TEXTURE_ITEM_QUEST_BORDER = TEXTURE_ITEM_QUEST_BORDER
mod.TEXTURE_ITEM_QUEST_BANG = TEXTURE_ITEM_QUEST_BANG


