local addon = select(2, ...)

-- ============================================================================
-- ITEM QUALITY BORDERS MODULE FOR DRAGONUI
-- Adds quality-colored glow borders to item slots across all inventory frames:
--   Character Panel, Inspect Frame, Bags, Bank, Merchant, Guild Bank
--
-- Special thanks to haste (https://github.com/haste) for oGlow, whose clean
-- implementation served as reference for the bank and guild bank systems.
-- ============================================================================

-- Module state tracking
local ItemQualityModule = {
    initialized = false,
    applied = false,
    hooks = {},
    frames = {},
    overlays = {} -- Track all created overlays for cleanup
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("itemquality", ItemQualityModule,
        (addon.L and addon.L["Item Quality"]) or "Item Quality",
        (addon.L and addon.L["Color item borders by quality in bags, character panel, bank, and merchant"]) or "Color item borders by quality in bags, character panel, bank, and merchant")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("itemquality")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("itemquality")
end

-- ============================================================================
-- QUALITY COLORS
-- ============================================================================

local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62, a = 0.5 },  -- Poor (gray)
    [1] = { r = 1.00, g = 1.00, b = 1.00, a = 0.5 },  -- Common (white)
    [2] = { r = 0.12, g = 1.00, b = 0.00, a = 0.8 },  -- Uncommon (green)
    [3] = { r = 0.00, g = 0.44, b = 0.87, a = 0.8 },  -- Rare (blue)
    [4] = { r = 0.64, g = 0.21, b = 0.93, a = 0.8 },  -- Epic (purple)
    [5] = { r = 1.00, g = 0.50, b = 0.00, a = 0.9 },  -- Legendary (orange)
    [6] = { r = 0.90, g = 0.80, b = 0.50, a = 0.9 },  -- Artifact (light gold)
    [7] = { r = 0.90, g = 0.80, b = 0.50, a = 0.9 },  -- Heirloom (gold/light-orange, matches WotLK 3.3.5a ITEM_QUALITY_COLORS[7] = e6cc80)
}

-- ============================================================================
-- OVERLAY CREATION
-- ============================================================================

-- Create or get the quality border overlay for any item frame
local function GetOrCreateOverlay(frame)
    if not frame then return nil end
    if frame.__DragonUI_QualityOverlay then
        return frame.__DragonUI_QualityOverlay
    end

    -- Use Blizzard's glow border texture in ADD blend mode
    local overlay = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    overlay:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    overlay:SetBlendMode("ADD")
    overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
    -- The glow texture must be ~1.7x the button size for a proper halo effect
    -- Bag/character item buttons are ~37px, so glow = ~62px
    local w, h = frame:GetWidth(), frame:GetHeight()
    if (not w or w == 0) then w = 37 end
    if (not h or h == 0) then h = 37 end
    overlay:SetWidth(w * 1.7)
    overlay:SetHeight(h * 1.7)
    overlay:Hide()

    frame.__DragonUI_QualityOverlay = overlay
    ItemQualityModule.overlays[frame] = overlay
    return overlay
end

-- Apply quality color to overlay, or hide if below min threshold
local function SetOverlayQuality(frame, quality)
    local overlay = GetOrCreateOverlay(frame)
    if not overlay then return end

    local config = GetModuleConfig()
    local minQuality = config and config.min_quality or 2

    if quality and quality >= minQuality and QUALITY_COLORS[quality] then
        local c = QUALITY_COLORS[quality]
        overlay:SetVertexColor(c.r, c.g, c.b, c.a or 0.8)
        overlay:Show()
    else
        overlay:Hide()
    end
end

-- ============================================================================
-- ITEM LINK QUALITY PARSING (shared lookup)
-- ============================================================================

-- Map known item link color hex codes → quality index
local COLOR_TO_QUALITY = {
    ["ff9d9d9d"] = 0, -- Poor
    ["ffffffff"] = 1, -- Common
    ["ff1eff00"] = 2, -- Uncommon
    ["ff0070dd"] = 3, -- Rare
    ["ffa335ee"] = 4, -- Epic
    ["ffff8000"] = 5, -- Legendary
    ["ffe6cc80"] = 6, -- Artifact
    ["ff00ccff"] = 7, -- Heirloom
}

-- Extract quality from an item link.
-- Tries GetItemInfo first; falls back to parsing the embedded color hex so
-- uncached items (first open of bank, etc.) still get colored correctly.
local function GetQualityFromLink(link)
    if not link then return nil end
    local _, _, quality = GetItemInfo(link)
    if not quality then
        local _, _, colorHex = string.find(link, "|c(%x+)|")
        if colorHex then
            quality = COLOR_TO_QUALITY[colorHex:lower()]
        end
    end
    return quality
end

-- ============================================================================
-- CHARACTER PANEL (equipped items)
-- ============================================================================

-- Equipment slot names → global frame names
-- GetInventorySlotInfo takes a NAME string, not a numeric ID
local EQUIP_SLOTS = {
    { name = "AmmoSlot",       frame = "CharacterAmmoSlot" },
    { name = "HeadSlot",       frame = "CharacterHeadSlot" },
    { name = "NeckSlot",       frame = "CharacterNeckSlot" },
    { name = "ShoulderSlot",   frame = "CharacterShoulderSlot" },
    { name = "ShirtSlot",      frame = "CharacterShirtSlot" },
    { name = "ChestSlot",      frame = "CharacterChestSlot" },
    { name = "WaistSlot",      frame = "CharacterWaistSlot" },
    { name = "LegsSlot",       frame = "CharacterLegsSlot" },
    { name = "FeetSlot",       frame = "CharacterFeetSlot" },
    { name = "WristSlot",      frame = "CharacterWristSlot" },
    { name = "HandsSlot",      frame = "CharacterHandsSlot" },
    { name = "Finger0Slot",    frame = "CharacterFinger0Slot" },
    { name = "Finger1Slot",    frame = "CharacterFinger1Slot" },
    { name = "Trinket0Slot",   frame = "CharacterTrinket0Slot" },
    { name = "Trinket1Slot",   frame = "CharacterTrinket1Slot" },
    { name = "BackSlot",       frame = "CharacterBackSlot" },
    { name = "MainHandSlot",   frame = "CharacterMainHandSlot" },
    { name = "SecondaryHandSlot", frame = "CharacterSecondaryHandSlot" },
    { name = "RangedSlot",     frame = "CharacterRangedSlot" },
    { name = "TabardSlot",     frame = "CharacterTabardSlot" },
}

-- Bag equipment slot IDs (20-23) — these live on the bag-bar and should NOT get
-- quality overlays.  Only character-panel gear slots should be decorated.
local BAG_EQUIP_SLOT_IDS = { [20] = true, [21] = true, [22] = true, [23] = true }

local function UpdateCharacterSlot(button)
    if not button then return end
    if not IsModuleEnabled() then return end

    local slotID = button:GetID()
    if not slotID or slotID < 0 then return end

    -- Skip bag equipment slots — they sit on the bag-bar, not the character panel
    if BAG_EQUIP_SLOT_IDS[slotID] then return end

    local hasItem = GetInventoryItemTexture("player", slotID)
    if hasItem then
        local quality = GetInventoryItemQuality("player", slotID)
        SetOverlayQuality(button, quality)
    else
        SetOverlayQuality(button, nil)
    end
end

local function UpdateAllCharacterSlots()
    if not IsModuleEnabled() then return end

    for _, slot in ipairs(EQUIP_SLOTS) do
        local button = _G[slot.frame]
        if button then
            UpdateCharacterSlot(button)
        end
    end
end

-- ============================================================================
-- INSPECT FRAME (inspected player's equipped items)
-- ============================================================================

local INSPECT_SLOTS = {
    "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectShirtSlot",
    "InspectChestSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
    "InspectWristSlot", "InspectHandsSlot", "InspectFinger0Slot", "InspectFinger1Slot",
    "InspectTrinket0Slot", "InspectTrinket1Slot", "InspectBackSlot",
    "InspectMainHandSlot", "InspectSecondaryHandSlot", "InspectRangedSlot",
    "InspectTabardSlot",
}

local function UpdateInspectSlot(button)
    if not button then return end
    if not IsModuleEnabled() then return end
    if not InspectFrame or not InspectFrame.unit then return end

    local slotID = button:GetID()
    if not slotID then return end
    if slotID >= 20 and slotID <= 23 then return end

    local unit = InspectFrame.unit
    local hasItem = GetInventoryItemTexture(unit, slotID)
    if hasItem then
        local quality = GetInventoryItemQuality(unit, slotID)
        if not quality then
            local link = GetInventoryItemLink(unit, slotID)
            quality = GetQualityFromLink(link)
        end
        SetOverlayQuality(button, quality)
    else
        SetOverlayQuality(button, nil)
    end
end

local function UpdateAllInspectSlots()
    if not IsModuleEnabled() then return end
    if not InspectFrame or not InspectFrame:IsShown() then return end
    for _, slotName in ipairs(INSPECT_SLOTS) do
        local button = _G[slotName]
        if button then
            UpdateInspectSlot(button)
        end
    end
end

-- ============================================================================
-- BAGS (container frames)
-- ============================================================================

local function GetBagItemQuality(bag, slot)
    return GetQualityFromLink(GetContainerItemLink(bag, slot))
end

local function UpdateBagSlot(frame, bag, slot)
    if not frame or not IsModuleEnabled() then return end
    local quality = GetBagItemQuality(bag, slot)
    SetOverlayQuality(frame, quality)
end

local function UpdateAllBags()
    if not IsModuleEnabled() then return end

    -- NUM_CONTAINER_FRAMES = 13 in 3.3.5a (bags 0-4)
    local numContainerFrames = NUM_CONTAINER_FRAMES or 13
    for i = 1, numContainerFrames do
        local containerFrame = _G["ContainerFrame" .. i]
        if containerFrame and containerFrame:IsShown() then
            local bag = containerFrame:GetID()
            local numSlots = GetContainerNumSlots(bag)
            for btnIdx = 1, numSlots do
                local itemButton = _G["ContainerFrame" .. i .. "Item" .. btnIdx]
                if itemButton then
                    -- Use the button's actual slot ID, NOT the loop index.
                    -- WoW 3.3.5a displays bag items in reverse order, so
                    -- ContainerFrame1Item1 may represent slot 16, not slot 1.
                    local realSlot = itemButton:GetID()
                    UpdateBagSlot(itemButton, bag, realSlot)
                end
            end
        end
    end
end

-- ============================================================================
-- BANK (personal bank slots + bank bag containers)
-- ============================================================================

local NUM_BANKGENERIC_SLOTS = 28 -- Standard bank slots in 3.3.5a

local function UpdateBankSlots()
    if not IsModuleEnabled() then return end
    if not BankFrame or not BankFrame:IsShown() then return end

    -- Bank slots use sequential IDs 1..28 matching BankFrameItem1..28
    for i = 1, NUM_BANKGENERIC_SLOTS do
        local button = _G["BankFrameItem" .. i]
        if button then
            local link = GetContainerItemLink(-1, i)
            SetOverlayQuality(button, GetQualityFromLink(link))
        end
    end

    -- Bank bag containers (bag IDs 5-11) are displayed as standard ContainerFrames.
    -- Items inside are displayed in reverse order, so use button:GetID() for the real slot.
    local numContainerFrames = NUM_CONTAINER_FRAMES or 13
    for i = 1, numContainerFrames do
        local containerFrame = _G["ContainerFrame" .. i]
        if containerFrame and containerFrame:IsShown() then
            local bag = containerFrame:GetID()
            if bag >= 5 and bag <= 11 then
                local numSlots = GetContainerNumSlots(bag)
                local frameName = containerFrame:GetName()
                for btnIdx = 1, numSlots do
                    local itemButton = _G[frameName .. "Item" .. btnIdx]
                    if itemButton then
                        local realSlot = itemButton:GetID()
                        local link = GetContainerItemLink(bag, realSlot)
                        SetOverlayQuality(itemButton, GetQualityFromLink(link))
                    end
                end
            end
        end
    end
end

-- Debug: dump bank quality state to chat
local function DebugBankSlots()
    if not addon.debugMode then return end
    addon:Print((addon.L and addon.L["=== BANK QUALITY DEBUG ==="]) or "=== BANK QUALITY DEBUG ===")
    addon:Print((addon.L and addon.L["Module enabled:"]) or "Module enabled:", IsModuleEnabled())
    addon:Print((addon.L and addon.L["BankFrame exists:"]) or "BankFrame exists:", BankFrame ~= nil)
    addon:Print((addon.L and addon.L["BankFrame shown:"]) or "BankFrame shown:", BankFrame and BankFrame:IsShown() or false)
    local found = 0
    for i = 1, NUM_BANKGENERIC_SLOTS do
        local button = _G["BankFrameItem" .. i]
        if button then
            local link = GetContainerItemLink(-1, i)
            local quality = GetQualityFromLink(link)
            if link then
                found = found + 1
                local overlay = button.__DragonUI_QualityOverlay
                addon:Print(string.format("Slot %d: link=%s quality=%s overlay=%s shown=%s",
                    i,
                    link and "YES" or "NO",
                    tostring(quality),
                    overlay and "YES" or "NO",
                    overlay and tostring(overlay:IsShown()) or "N/A"
                ))
            end
        end
    end
    addon:Print(string.format("Total slots with items: %d", found))
end

-- Expose for slash command
addon.DebugBankSlots = DebugBankSlots

-- ============================================================================
-- MERCHANT FRAME
-- ============================================================================

local MERCHANT_ITEMS_PER_PAGE = MERCHANT_ITEMS_PER_PAGE or 10
local BUYBACK_ITEMS_PER_PAGE = BUYBACK_ITEMS_PER_PAGE or 12

local function UpdateMerchantItems()
    if not IsModuleEnabled() then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    -- Same index math as FrameXML MerchantFrame_UpdateMerchantInfo
    local page = MerchantFrame.page or 1
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local index = ((page - 1) * MERCHANT_ITEMS_PER_PAGE) + i
            SetOverlayQuality(button, GetQualityFromLink(GetMerchantItemLink(index)))
        end
    end

    local buybackButton = _G["MerchantBuyBackItemItemButton"]
    if buybackButton then
        SetOverlayQuality(buybackButton, GetQualityFromLink(GetBuybackItemLink(GetNumBuybackItems())))
    end
end

local function UpdateBuybackItems()
    if not IsModuleEnabled() then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    for i = 1, BUYBACK_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            SetOverlayQuality(button, GetQualityFromLink(GetBuybackItemLink(i)))
        end
    end
end

-- ============================================================================
-- GUILD BANK
-- ============================================================================

local function UpdateGuildBankSlots()
    if not IsModuleEnabled() then return end
    -- Blizzard_GuildBankUI is a load-on-demand addon; bail if not loaded yet
    if not IsAddOnLoaded("Blizzard_GuildBankUI") then return end
    if not GuildBankFrame or not GuildBankFrame:IsShown() then return end

    local tab = GetCurrentGuildBankTab()
    -- Each tab has 98 slots arranged in 7 columns of 14 rows
    for i = 1, MAX_GUILDBANK_SLOTS_PER_TAB or 98 do
        -- Derive row (1-14) and column (1-7) from the linear slot index
        local index = math.fmod(i, 14)
        if index == 0 then index = 14 end
        local column = math.ceil((i - 0.5) / 14)

        local button = _G["GuildBankColumn" .. column .. "Button" .. index]
        if button then
            local link = GetGuildBankItemLink(tab, i)
            SetOverlayQuality(button, GetQualityFromLink(link))
        end
    end
end

-- ============================================================================
-- REFRESH ALL
-- ============================================================================

local function UpdateAllQualityBorders()
    if not IsModuleEnabled() then return end
    UpdateAllCharacterSlots()
    UpdateAllBags()
    UpdateBankSlots()
    if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 2 then
        UpdateBuybackItems()
    else
        UpdateMerchantItems()
    end
    UpdateGuildBankSlots()
end

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

local function InstallInspectHook()
    if ItemQualityModule.hooks["Inspect"] then return end
    if not InspectPaperDollItemSlotButton_Update then return end
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        if not IsModuleEnabled() then return end
        UpdateInspectSlot(button)
    end)

    -- Retargeting reuses the open frame: InspectFrame_UnitChanged calls this right
    -- after NotifyInspect, so slot data is still the previous unit's.
    if InspectPaperDollFrame_OnShow then
        hooksecurefunc("InspectPaperDollFrame_OnShow", function()
            if not IsModuleEnabled() then return end
            addon:After(0.1, UpdateAllInspectSlots)
            addon:After(0.6, UpdateAllInspectSlots)
        end)
    end

    ItemQualityModule.hooks["Inspect"] = true
end

local function ApplyItemQualitySystem()
    if ItemQualityModule.applied then return end

    -- Character Panel: hook PaperDollItemSlotButton_Update
    if not ItemQualityModule.hooks["PaperDoll"] and PaperDollItemSlotButton_Update then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            if not IsModuleEnabled() then return end
            UpdateCharacterSlot(button)
        end)
        ItemQualityModule.hooks["PaperDoll"] = true
    end

    -- Inspect Frame: installed via InstallInspectHook() when Blizzard_InspectUI loads
    InstallInspectHook()

    -- Bags: hook ContainerFrame_Update
    if not ItemQualityModule.hooks["ContainerFrame"] and ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function(frame)
            if not IsModuleEnabled() then return end
            if not frame then return end
            local bag = frame:GetID()
            local numSlots = GetContainerNumSlots(bag)
            local frameName = frame:GetName()
            for btnIdx = 1, numSlots do
                local itemButton = _G[frameName .. "Item" .. btnIdx]
                if itemButton then
                    -- Use button's actual slot ID (items are displayed in reverse order)
                    local realSlot = itemButton:GetID()
                    UpdateBagSlot(itemButton, bag, realSlot)
                end
            end
        end)
        ItemQualityModule.hooks["ContainerFrame"] = true
    end

    -- Also hook bag open/close
    if not ItemQualityModule.hooks["ToggleBackpack"] then
        hooksecurefunc("ToggleBackpack", function()
            if not IsModuleEnabled() then return end
            addon:After(0.1, UpdateAllBags)
        end)
        ItemQualityModule.hooks["ToggleBackpack"] = true
    end

    if not ItemQualityModule.hooks["ToggleBag"] then
        hooksecurefunc("ToggleBag", function()
            if not IsModuleEnabled() then return end
            addon:After(0.1, UpdateAllBags)
        end)
        ItemQualityModule.hooks["ToggleBag"] = true
    end

    -- Also hook OpenBackpack / OpenBag for the "open all bags" scenario
    if not ItemQualityModule.hooks["OpenBackpack"] and OpenBackpack then
        hooksecurefunc("OpenBackpack", function()
            if not IsModuleEnabled() then return end
            addon:After(0.1, UpdateAllBags)
        end)
        ItemQualityModule.hooks["OpenBackpack"] = true
    end

    -- Merchant: hook MerchantFrame_UpdateMerchantInfo
    if not ItemQualityModule.hooks["Merchant"] and MerchantFrame_UpdateMerchantInfo then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            if not IsModuleEnabled() then return end
            UpdateMerchantItems()
        end)
        ItemQualityModule.hooks["Merchant"] = true
    end

    -- Merchant Buyback tab (slots use GetBuybackItemLink, not merchant indices)
    if not ItemQualityModule.hooks["MerchantBuyback"] and MerchantFrame_UpdateBuybackInfo then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
            if not IsModuleEnabled() then return end
            UpdateBuybackItems()
        end)
        ItemQualityModule.hooks["MerchantBuyback"] = true
    end

    -- Bank: hook BankFrameItemButton_Update for per-slot real-time updates.
    -- BankFrameItemButton_Update is defined in Blizzard's BankFrame.lua which
    -- loads at startup, so it exists by the time this function runs.
    if not ItemQualityModule.hooks["BankFrame"] and BankFrameItemButton_Update then
        hooksecurefunc("BankFrameItemButton_Update", function(button)
            if not IsModuleEnabled() then return end
            if not BankFrame or not BankFrame:IsShown() then return end
            local slotID = button:GetID()
            local link = GetContainerItemLink(-1, slotID)
            SetOverlayQuality(button, GetQualityFromLink(link))
        end)
        ItemQualityModule.hooks["BankFrame"] = true
    end

    -- Guild Bank: hook is installed dynamically on GUILDBANKFRAME_OPENED
    -- because Blizzard_GuildBankUI is load-on-demand (not available at startup)

    -- Initial update
    addon:After(0.5, UpdateAllQualityBorders)

    ItemQualityModule.applied = true
    ItemQualityModule.initialized = true
end

local function RestoreItemQualitySystem()
    if not ItemQualityModule.applied then return end

    -- Hide all tracked quality overlays
    for frame, overlay in pairs(ItemQualityModule.overlays) do
        if overlay then overlay:Hide() end
    end

    ItemQualityModule.applied = false
end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    if IsModuleEnabled() then
        RestoreItemQualitySystem()
        ItemQualityModule.applied = false
        ApplyItemQualitySystem()
    else
        if addon:ShouldDeferModuleDisable("itemquality", ItemQualityModule) then
            return
        end
        RestoreItemQualitySystem()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("INSPECT_TALENT_READY")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
        if not IsModuleEnabled() then return end
        InstallInspectHook()

    elseif event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end

        -- Register profile callbacks
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(ItemQualityModule, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(ItemQualityModule, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(ItemQualityModule, "OnProfileReset", OnProfileChanged)
            end
        end)

        -- Inspect hook is installed when Blizzard_InspectUI loads (see ADDON_LOADED handler below)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        addon:After(1.0, function()
            ApplyItemQualitySystem()
        end)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if not IsModuleEnabled() then return end
        addon:After(0.2, UpdateAllCharacterSlots)

    elseif event == "BAG_UPDATE" then
        if not IsModuleEnabled() then return end
        -- One BAG_UPDATE per changed bag; without this a sweep is scheduled per event.
        if ItemQualityModule.bagSweepPending then return end
        ItemQualityModule.bagSweepPending = true
        addon:After(0.2, function()
            ItemQualityModule.bagSweepPending = false
            UpdateAllBags()
        end)

    elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if not IsModuleEnabled() then return end
        -- Call immediately AND schedule retries to handle servers that send
        -- bank slot data asynchronously after BANKFRAME_OPENED fires.
        UpdateBankSlots()
        addon:After(0.5, UpdateBankSlots)
        addon:After(1.5, UpdateBankSlots)

    elseif event == "INSPECT_TALENT_READY" then
        -- 3.3.5a has no INSPECT_READY; this is the only "inspect data arrived" signal
        if not IsModuleEnabled() then return end
        InstallInspectHook()
        addon:After(0.2, UpdateAllInspectSlots)

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if not IsModuleEnabled() then return end
        if InspectFrame and InspectFrame:IsShown() and InspectFrame.unit and arg1 == InspectFrame.unit then
            addon:After(0.2, UpdateAllInspectSlots)
        end

    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        if not IsModuleEnabled() then return end
        addon:After(0.2, function()
            if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 2 then
                UpdateBuybackItems()
            else
                UpdateMerchantItems()
            end
        end)

    elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
        if not IsModuleEnabled() then return end
        -- Install GuildBankFrame_Update hook on first open (load-on-demand addon)
        if not ItemQualityModule.hooks["GuildBank"] and GuildBankFrame_Update then
            hooksecurefunc("GuildBankFrame_Update", function()
                if not IsModuleEnabled() then return end
                UpdateGuildBankSlots()
            end)
            ItemQualityModule.hooks["GuildBank"] = true
        end
        UpdateGuildBankSlots()
    end
end)

-- Export for external use
addon.ApplyItemQualitySystem = ApplyItemQualitySystem
addon.RestoreItemQualitySystem = RestoreItemQualitySystem
addon.UpdateAllQualityBorders = UpdateAllQualityBorders
