-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- New-item tracking adapted from AdiBags (see THIRD_PARTY_NOTICES).

-- Marks items gained since the last reset with a rotating glow and sorts them
-- to the front of the grid. The "N" button on each frame resets the marks.
local addon = select(2, ...)
local mod = addon.BagsterModule

local _G = _G
local pairs, ipairs, next, select = pairs, ipairs, next, select
local strmatch = string.match
local tonumber, max = tonumber, math.max
local wipe = wipe
local GetTime, GetCursorInfo = GetTime, GetCursorInfo
local GetItemCount, GetItemInfo = GetItemCount, GetItemInfo
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetInventoryItemID = _G.GetInventoryItemID

local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local BANK_CONTAINER = _G.BANK_CONTAINER
local KEYRING_CONTAINER = _G.KEYRING_CONTAINER
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = _G.NUM_BANKBAGSLOTS

-- ============================================================================
-- MODULE + STATE
-- ============================================================================

local NewItems = mod:NewModule("NewItems")

local DEFAULT_SCALE = 1.5
local DEFAULT_COLOR = { 0.3, 1, 0.3, 0.7 }
local GLOW_TEXTURE = [[Interface\Cooldown\starburst]]

local SCAN_DELAY = 0.2
local RETRY_DELAY = 0.5
local SUPPRESS_EXTEND = 1
local LOGIN_FREEZE = 2

local states = {
    inventory = { counts = {}, newItems = {}, first = true },
    bank = { counts = {}, newItems = {}, first = true },
}
NewItems.states = states

local frozen = true
local scanScheduled = false
local wasEnabled = nil
local lastIgnoreJunk = nil

local MarkDirty, RunScan, ScheduleScan, UpdateResetButton, InstallSortHooks

-- ============================================================================
-- HELPERS
-- ============================================================================

local function IsEnabled()
    local cfg = mod.GetModuleConfig()
    return (cfg and cfg.new_items) and true or false
end

local function ItemIDFromLink(link)
    return link and tonumber(strmatch(link, "item:(%d+)")) or nil
end

local function SlotItemID(bag, slot)
    local id = GetContainerItemID and GetContainerItemID(bag, slot)
    if id then return id end
    local link = GetContainerItemInfo and select(7, GetContainerItemInfo(bag, slot))
    return ItemIDFromLink(link)
end

local function StateKeyForBag(bag)
    if bag == BANK_CONTAINER then return "bank" end
    if bag and bag > NUM_BAG_SLOTS and bag <= NUM_BAG_SLOTS + NUM_BANKBAGSLOTS then
        return "bank"
    end
    return "inventory"
end

local INVENTORY_CONTAINERS = { BACKPACK_CONTAINER, 1, 2, 3, 4, KEYRING_CONTAINER }

local BANK_CONTAINERS = { BANK_CONTAINER }
for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
    BANK_CONTAINERS[#BANK_CONTAINERS + 1] = bag
end

-- Equipped gear is seeded into the baseline, so wearing something is not loot.
local EQUIPPED_SLOTS = {}
for slot = 0, 20 do EQUIPPED_SLOTS[#EQUIPPED_SLOTS + 1] = slot end
for slot = 68, 74 do EQUIPPED_SLOTS[#EQUIPPED_SLOTS + 1] = slot end

local function GetBagCount(id)
    return GetItemCount(id) or 0
end

local function GetBankCount(id)
    return max((GetItemCount(id, true) or 0) - (GetItemCount(id) or 0), 0)
end

local function SeedEquipped(counts)
    if not GetInventoryItemID then return end
    for _, slot in ipairs(EQUIPPED_SLOTS) do
        local id = GetInventoryItemID("player", slot)
        if id and not counts[id] then
            counts[id] = 0
        end
    end
end

local function FrameForKey(key)
    local frames = mod.frames
    if not frames then return nil end
    for _, frame in pairs(frames) do
        if frame and frame.key == key then return frame end
    end
end

local function IsStateVisible(key)
    local frame = FrameForKey(key)
    return frame ~= nil and frame:IsShown() and true or false
end

-- ============================================================================
-- SCANNING
-- ============================================================================

local function ScanState(key)
    local state = states[key]
    local counts = state.counts
    local newItems = state.newItems
    local cfg = mod.GetModuleConfig()
    local ignoreJunk = cfg and cfg.new_ignore_junk

    -- An id we have never seen had a count of "none".
    local BagSlotInfo = mod.BagSlotInfo
    local containers = (key == "bank") and BANK_CONTAINERS or INVENTORY_CONTAINERS
    for _, bag in ipairs(containers) do
        local size = BagSlotInfo:GetSize(mod.playerName, bag) or 0
        for slot = 1, size do
            local id = SlotItemID(bag, slot)
            if id and not counts[id] then
                counts[id] = 0
            end
        end
    end
    SeedEquipped(counts)

    local now = GetTime()
    local suppressing = state.suppressUntil and state.suppressUntil > now
    local first = state.first
    local getCount = (key == "bank") and GetBankCount or GetBagCount
    local changed = false

    for id, oldCount in pairs(counts) do
        local newCount = getCount(id)
        if newCount ~= oldCount then
            counts[id] = newCount
            if ignoreJunk and select(3, GetItemInfo(id)) == 0 then
                if newItems[id] then
                    newItems[id] = nil
                    changed = true
                end
            elseif not (first or suppressing) and oldCount < newCount then
                if not newItems[id] then
                    newItems[id] = true
                    changed = true
                end
            end
        end
    end

    state.first = false
    return changed
end

RunScan = function()
    if not IsEnabled() then return end
    local changed = false
    -- The inventory is scanned even while the bags are shut: loot can land from a
    -- trade, mail or a pickup macro.
    if ScanState("inventory") then changed = true end
    -- The bank is only counted while it is open.
    if IsStateVisible("bank") and ScanState("bank") then changed = true end
    if changed then
        NewItems:RefreshFrames(true)
    end
end

ScheduleScan = function(delay)
    if scanScheduled then return end
    scanScheduled = true
    addon:After(delay or SCAN_DELAY, function()
        scanScheduled = false
        if not (IsEnabled() and mod.BagsterModule.applied) then return end
        -- Items on the cursor or a gear swap must not read as "new"
        if frozen or GetCursorInfo() then
            ScheduleScan(RETRY_DELAY)
            return
        end
        RunScan()
    end)
end

MarkDirty = function()
    if not IsEnabled() then return end
    -- A sort moves many slots at once; its own moves must not light up.
    local now = GetTime()
    for _, state in pairs(states) do
        if state.suppressUntil and state.suppressUntil > now then
            state.suppressUntil = now + SUPPRESS_EXTEND
        end
    end
    ScheduleScan(SCAN_DELAY)
end

-- ============================================================================
-- PUBLIC STATE API
-- ============================================================================

function NewItems:IsNewItemID(bag, id)
    if not (id and bag) then return false end
    local state = states[StateKeyForBag(bag)]
    return state.newItems[id] == true
end

function NewItems:IsNewLink(bag, link)
    return self:IsNewItemID(bag, ItemIDFromLink(link))
end

function NewItems:ResetState(key, suppress)
    local state = states[key]
    if not state then return end
    local hadMarks = next(state.newItems) ~= nil
    wipe(state.newItems)
    if suppress then
        state.suppressUntil = GetTime() + SUPPRESS_EXTEND
    end
    self:RefreshFrames(hadMarks)
end

function NewItems:RefreshFrames(regen)
    if not mod.frames then return end
    for _, frame in pairs(mod.frames) do
        if frame then
            local itemFrame = frame.itemFrame
            if itemFrame then
                if regen then itemFrame:Regenerate() end
                for _, item in pairs(itemFrame.items) do
                    mod.UpdateNewItemGlow(item)
                end
                itemFrame:RequestLayout()
            end
            UpdateResetButton(frame)
            if not frame._bagsterNewHooked then
                frame._bagsterNewHooked = true
                frame:HookScript("OnShow", function()
                    UpdateResetButton(frame)
                    InstallSortHooks()
                    MarkDirty()
                end)
            end
        end
    end
end

-- ============================================================================
-- ITEM GLOW
-- ============================================================================

function NewItems:CreateGlow(button)
    local glow = CreateFrame("Frame", nil, button)
    glow:SetFrameLevel(button:GetFrameLevel() + 15)
    glow:SetPoint("CENTER")
    glow:SetSize(37, 37)

    local texture = glow:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(GLOW_TEXTURE)
    texture:SetBlendMode("ADD")
    texture:SetAllPoints(glow)
    glow.Texture = texture

    local group = glow:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local anim = group:CreateAnimation("Rotation")
    anim:SetOrder(1)
    anim:SetDuration(10)
    anim:SetDegrees(360)
    anim:SetOrigin("CENTER", 0, 0)
    group:Play()

    button._BagsterNewGlow = glow
    return glow
end

-- Called from ItemSlot:Update, also while hidden so the first Layout can sort.
function mod.UpdateNewItemGlow(slot)
    local cfg = mod.GetModuleConfig()
    local enabled = cfg and cfg.new_items
    local glow = slot._BagsterNewGlow
    local id = enabled and ItemIDFromLink(slot:GetItem()) or nil
    local isNew = id and NewItems:IsNewItemID(slot:GetBag(), id) or false

    slot._BagsterNewItem = isNew or nil

    if not (isNew and enabled and cfg.new_glow ~= false) then
        if glow and glow:IsShown() then glow:Hide() end
        return
    end

    if not glow then glow = NewItems:CreateGlow(slot) end
    local scale = cfg.new_glow_scale or DEFAULT_SCALE
    if glow:GetScale() ~= scale then glow:SetScale(scale) end
    local c = cfg.new_glow_color or DEFAULT_COLOR
    glow.Texture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    glow:Show()
end

-- Layout hook: the button list with new items first, or nil when nothing moves.
function mod.NewItemsReorderItems(frame, buttons)
    local cfg = mod.GetModuleConfig()
    if not (cfg and cfg.new_items) or cfg.new_first == false then return nil end

    local count = #buttons
    local hasNew = false
    for i = 1, count do
        if buttons[i]._BagsterNewItem then hasNew = true; break end
    end
    if not hasNew then return nil end

    local ordered = {}
    for i = 1, count do
        local button = buttons[i]
        if button._BagsterNewItem then ordered[#ordered + 1] = button end
    end
    for i = 1, count do
        local button = buttons[i]
        if not button._BagsterNewItem then ordered[#ordered + 1] = button end
    end
    return ordered
end

-- ============================================================================
-- "N" RESET BUTTON
-- ============================================================================

local function SearchBoxOf(frame)
    local name = frame:GetName()
    return name and _G[name .. "Search"] or nil
end

local function SetSearchBoxShifted(frame, shifted)
    if frame._bagsterNewSearchShifted == shifted then return end
    local search = SearchBoxOf(frame)
    if not search then return end
    frame._bagsterNewSearchShifted = shifted
    search:ClearAllPoints()
    if shifted then
        search:SetPoint("TOPLEFT", frame, "TOPLEFT", 84, -31)
        search:SetWidth(176)
    else
        search:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -31)
        search:SetWidth(200)
    end
end

local function CreateResetButton(frame)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(20, 20)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -31)
    button:SetFrameLevel(frame:GetFrameLevel() + 15)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    background:SetTexture([[Interface\Buttons\WHITE8X8]])
    background:SetVertexColor(0.05, 0.05, 0.05, 0.6)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.5)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText("N")
    button.label = label

    button:SetScript("OnClick", function(self)
        if not self._hasNew then return end
        NewItems:ResetState(frame.isBank and "bank" or "inventory")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local L = addon.L
        GameTooltip:SetText((L and L["Reset new items"]) or "Reset new items", 1, 1, 1)
        GameTooltip:AddLine((L and L["Click to reset item status."]) or "Click to reset item status.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame._bagsterNewReset = button
    return button
end

UpdateResetButton = function(frame)
    if not IsEnabled() then
        if frame._bagsterNewReset then frame._bagsterNewReset:Hide() end
        SetSearchBoxShifted(frame, false)
        return
    end
    local button = frame._bagsterNewReset
    if not button then button = CreateResetButton(frame) end
    SetSearchBoxShifted(frame, true)

    local state = states[frame.isBank and "bank" or "inventory"]
    local hasNew = state and next(state.newItems) ~= nil
    button._hasNew = hasNew and true or false
    if hasNew then
        button.label:SetTextColor(1, 0.82, 0)
    else
        button.label:SetTextColor(0.5, 0.5, 0.5)
    end
    button:Show()
end

-- ============================================================================
-- SORT BUTTON RESET
-- ============================================================================

local function HookSortButton(button, key)
    if not button or button._bagsterNewSortHooked then return end
    button._bagsterNewSortHooked = true
    button:HookScript("OnClick", function()
        local cfg = mod.GetModuleConfig()
        if cfg and cfg.new_items and cfg.new_reset_on_sort ~= false then
            -- Suppress while the sort runs, so its own moves do not light up
            NewItems:ResetState(key, true)
        end
    end)
end

InstallSortHooks = function()
    if not IsEnabled() then return end
    HookSortButton(_G.DragonUI_BagsterBagSortBtn, "inventory")
    HookSortButton(_G.DragonUI_BagsterBankSortBtn, "bank")
end

-- ============================================================================
-- CONFIG CHANGES (called by RefreshBagsterFrames)
-- ============================================================================

local function ClearJunkMarks()
    local cleared = false
    for _, state in pairs(states) do
        for id in pairs(state.newItems) do
            if select(3, GetItemInfo(id)) == 0 then
                state.newItems[id] = nil
                cleared = true
            end
        end
    end
    return cleared
end

function NewItems:OnRefresh()
    local cfg = mod.GetModuleConfig()
    local enabled = IsEnabled()

    if enabled then
        InstallSortHooks()
    end

    if enabled ~= wasEnabled then
        wasEnabled = enabled
        if not enabled then
            wipe(states.inventory.newItems)
            wipe(states.bank.newItems)
        end
        -- Fresh baseline: never flag what was already owned or gained while off.
        states.inventory.first = true
        states.bank.first = true
        if enabled then
            ScheduleScan(SCAN_DELAY)
        end
    end

    local ignoreJunk = cfg and cfg.new_ignore_junk
    if ignoreJunk ~= lastIgnoreJunk then
        lastIgnoreJunk = ignoreJunk
        if ignoreJunk and ClearJunkMarks() then
            self:RefreshFrames(true)
            return
        end
    end

    self:RefreshFrames(false)
end

function mod.RefreshNewItems()
    NewItems:OnRefresh()
end

-- ============================================================================
-- EVENT WIRING
-- ============================================================================

do
    local function onSlotEvent() MarkDirty() end

    -- Its own bus object: the bus keeps one handler per object and message.
    local InventoryEvents = mod("InventoryEvents")
    InventoryEvents:Register(NewItems, "ITEM_SLOT_ADD", onSlotEvent)
    InventoryEvents:Register(NewItems, "ITEM_SLOT_REMOVE", onSlotEvent)
    InventoryEvents:Register(NewItems, "ITEM_SLOT_UPDATE", onSlotEvent)
    InventoryEvents:Register(NewItems, "BAG_EMPTIED", onSlotEvent)
    InventoryEvents:Register(NewItems, "BANK_OPENED", onSlotEvent)
    InventoryEvents:Register(NewItems, "BANK_CLOSED", onSlotEvent)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    eventFrame:RegisterEvent("EQUIPMENT_SWAP_PENDING")
    eventFrame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            addon:After(LOGIN_FREEZE, function()
                frozen = false
                MarkDirty()
                if IsEnabled() then NewItems:RefreshFrames(false) end
            end)
            return
        end
        if not IsEnabled() then return end
        if event == "EQUIPMENT_SWAP_PENDING" then
            frozen = true
        elseif event == "EQUIPMENT_SWAP_FINISHED" then
            frozen = false
            MarkDirty()
        elseif event == "UNIT_INVENTORY_CHANGED" then
            if arg1 == "player" then MarkDirty() end
        end
    end)
end
