-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

local function T(key, fallback)
    return (L and L[key]) or fallback or key
end

-- ============================================================================
-- BAG SORT MODULE FOR DRAGONUI
-- Sorts items in bags and bank by type, rarity, level, name.
-- Adds sort buttons to both Bagster frames and vanilla bag/bank frames.
-- ============================================================================

-- Module state tracking
local BagSortModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    frames = {}
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("bagsort", BagSortModule,
        T("Bag Sort", "Bag Sort"),
        T("Sort bags and bank items with buttons", "Sort bags and bank items with buttons"),
        { lifecyclePrefix = "BagSort" })
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("bagsort")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("bagsort")
end

local function IsBankFillFromBagsEnabled()
    local cfg = GetModuleConfig()
    if not cfg or cfg.bank_fill_from_bags == nil then
        return true
    end
    return cfg.bank_fill_from_bags
end

local function IsBagsterEnabled()
    return addon:IsModuleEnabled("bagster")
end

-- Cached after the first check since addons can't load/unload mid-session.
local bagnonLoadedCache
local function IsBagnonLoaded()
    if bagnonLoadedCache == nil then
        bagnonLoadedCache = ((IsAddOnLoaded and IsAddOnLoaded("Bagnon")) or _G.Bagnon ~= nil) and true or false
    end
    return bagnonLoadedCache
end

-- True only during an active guild bank sort; doesn't affect bag/bank sorting.
local guildBankSortActive = false
local GUILDBANK_MOVE_THROTTLE = 0.4

local function GetSortMoveInterval()
    local cfg = GetModuleConfig()
    local interval = cfg and tonumber(cfg.move_interval) or 0.1
    if guildBankSortActive and interval < GUILDBANK_MOVE_THROTTLE then
        interval = GUILDBANK_MOVE_THROTTLE
    end
    if interval < 0.05 then return 0.05 end
    if interval > 0.5 then return 0.5 end
    return interval
end

local DEFAULT_LOCK_HOTKEY = "ALT_LEFT"
local LOCK_HOTKEY_MAP = {
    ALT_LEFT = { modifier = "ALT", button = "LeftButton" },
    CTRL_LEFT = { modifier = "CTRL", button = "LeftButton" },
    SHIFT_LEFT = { modifier = "SHIFT", button = "LeftButton" },
    ALT_RIGHT = { modifier = "ALT", button = "RightButton" },
    CTRL_RIGHT = { modifier = "CTRL", button = "RightButton" },
    SHIFT_RIGHT = { modifier = "SHIFT", button = "RightButton" },
    ALT_MIDDLE = { modifier = "ALT", button = "MiddleButton" },
    CTRL_MIDDLE = { modifier = "CTRL", button = "MiddleButton" },
    SHIFT_MIDDLE = { modifier = "SHIFT", button = "MiddleButton" },
}

local function NormalizeLockHotkey(value)
    if type(value) ~= "string" then
        return DEFAULT_LOCK_HOTKEY
    end

    local normalized = string.upper(value)
    if LOCK_HOTKEY_MAP[normalized] then
        return normalized
    end

    return DEFAULT_LOCK_HOTKEY
end

local function GetConfiguredLockHotkey()
    local cfg = GetModuleConfig()
    local hotkey = NormalizeLockHotkey(cfg and cfg.lock_hotkey)
    if cfg and cfg.lock_hotkey ~= hotkey then
        cfg.lock_hotkey = hotkey
    end
    return hotkey
end

local function GetLocalizedModifierName(modifier)
    if modifier == "ALT" then
        return T("Alt", "Alt")
    elseif modifier == "CTRL" then
        return T("Ctrl", "Ctrl")
    end
    return T("Shift", "Shift")
end

local function GetLocalizedMouseButtonName(button)
    if button == "LeftButton" then
        return T("Left Click", "Left Click")
    elseif button == "RightButton" then
        return T("Right Click", "Right Click")
    end
    return T("Middle Click", "Middle Click")
end

local function GetLockHotkeyLabel()
    local hotkey = GetConfiguredLockHotkey()
    local bindData = LOCK_HOTKEY_MAP[hotkey] or LOCK_HOTKEY_MAP[DEFAULT_LOCK_HOTKEY]
    return string.format("%s + %s", GetLocalizedModifierName(bindData.modifier), GetLocalizedMouseButtonName(bindData.button))
end

local function IsLockHotkeyPressed(mouseButton)
    local hotkey = GetConfiguredLockHotkey()
    local bindData = LOCK_HOTKEY_MAP[hotkey] or LOCK_HOTKEY_MAP[DEFAULT_LOCK_HOTKEY]
    if mouseButton ~= bindData.button then
        return false
    end

    local altDown = IsAltKeyDown and IsAltKeyDown()
    local ctrlDown = IsControlKeyDown and IsControlKeyDown()
    local shiftDown = IsShiftKeyDown and IsShiftKeyDown()

    if bindData.modifier == "ALT" then
        return altDown and not ctrlDown and not shiftDown
    elseif bindData.modifier == "CTRL" then
        return ctrlDown and not altDown and not shiftDown
    end

    return shiftDown and not altDown and not ctrlDown
end

local function GetBagnonFrame(frameType)
    if not IsBagnonLoaded() then return nil end

    local names
    if frameType == "bank" then
        names = { "BagnonFramebank", "BagnonBankFrame", "BagnonFrameBank", "BagnonFrame2" }
    elseif frameType == "guildbank" then
        names = { "BagnonFrameguildbank", "BagnonGuildBankFrame", "BagnonFrameGuildBank" }
    else
        names = { "BagnonFrameinventory", "BagnonInventoryFrame", "BagnonFrameInventory", "BagnonFrame1" }
    end

    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then
            return frame
        end
    end

    local bagnon = _G.Bagnon
    if bagnon and type(bagnon) == "table" then
        if bagnon.GetFrame then
            local frame = bagnon:GetFrame(frameType)
            if frame then
                return frame
            end
        end

        local frames = bagnon.frames or bagnon.Frames
        if frames then
            return frames[frameType] or frames[string.upper(frameType)] or frames[frameType == "bank" and 2 or 1]
        end
    end

    return nil
end

-- Bag, bank and guild-tab sorts share this flag, the move plan and the tick driver: one sort at a time.
local running = false
local plannedMoves = {}
local nextMoveIndex = 1
local awaitedDrop
local tickAccumulator = 0

local bank_open = false
local guild_bank_open = false
local guildBankTabHookInstalled = false
local clickHooksInstalled = false
local hookedSlotButtons = {}
local lockVisualFrame
local bagnonSlotScanRequested = false
local bagnonSlotScanPasses = 0
local bagnonIntegrationHooked = false
local bagnonFrameHooksInstalled = false
local bagnonSortingHooked = false
local bagnonMoveHooked = false
local bagnonOriginalGetSpaces
local bagnonOriginalMove

-- Forward declarations
local StopSorting
local UpdateButtonVisibility

local function ItemIDFromLink(link)
    local digits = link and string.match(link, "item:(%d+)")
    return digits and tonumber(digits)
end

local function GetLockedSlotsTable()
    local cfg = GetModuleConfig()
    if not cfg then return nil end
    if type(cfg.lockedSlots) ~= "table" then
        cfg.lockedSlots = {}
    end
    return cfg.lockedSlots
end

local function MakeSlotKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

local function IsSlotLocked(bag, slot)
    local locks = GetLockedSlotsTable()
    if not locks then return false end
    return locks[MakeSlotKey(bag, slot)] == true
end

local function SetSlotLocked(bag, slot, locked)
    local locks = GetLockedSlotsTable()
    if not locks then return false end
    local key = MakeSlotKey(bag, slot)
    if locked then
        locks[key] = true
    else
        locks[key] = nil
    end
    return true
end

local GetBagSlotFromButton

-- Guild bank item slots use `.tab` instead of a bag id; not a real bag/bank slot.
local function IsBagnonGuildBankSlot(widget)
    return widget.tab ~= nil and not (widget.GetBag or widget.GetBagID or widget.bag or widget.bagID or widget.bagId)
end

-- Bagnon's per-bag toggle icons; GetID() is a bag index, not a slot number.
local function IsBagnonBagToggleButton(widget)
    return type(widget.ToggleSlot) == "function" and type(widget.CanToggleSlot) == "function"
end

-- Lock icon texture, sized 12x12 and anchored to the slot's top-right corner.
local LOCK_MARKER_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\UI\\BagSortLock"
local LOCK_MARKER_SIZE = 12
local LOCK_MARKER_OFFSET_X = -1
local LOCK_MARKER_OFFSET_Y = -1
local DEFAULT_LOCK_MARKER_COLOR = { 0.15, 0.80, 1.00, 0.95 }

-- Icon art is plain white so it can be tinted (Bags > Bag Sort > Lock Icon Color).
local function GetLockMarkerColor()
    local cfg = GetModuleConfig()
    local c = cfg and cfg.lock_color
    if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then
        return c[1], c[2], c[3], type(c[4]) == "number" and c[4] or 1
    end
    return DEFAULT_LOCK_MARKER_COLOR[1], DEFAULT_LOCK_MARKER_COLOR[2], DEFAULT_LOCK_MARKER_COLOR[3], DEFAULT_LOCK_MARKER_COLOR[4]
end

local function EnsureLockMarker(button)
    if not button or button._dragonUISortLockMarker then return end
    -- No CreateTexture sub-level param on this client; last-created wins draw order.
    local marker = button:CreateTexture(nil, "OVERLAY")
    marker:SetTexture(LOCK_MARKER_TEXTURE)
    marker:SetSize(LOCK_MARKER_SIZE, LOCK_MARKER_SIZE)
    marker:ClearAllPoints()
    -- Top-right corner keeps it clear of the stack-count text (bottom-right).
    marker:SetPoint("TOPRIGHT", button, "TOPRIGHT", LOCK_MARKER_OFFSET_X, LOCK_MARKER_OFFSET_Y)
    marker:Hide()
    button._dragonUISortLockMarker = marker
end

local function UpdateButtonLockMarker(button)
    if not button then return end
    EnsureLockMarker(button)

    local marker = button._dragonUISortLockMarker
    if not marker then return end

    local bag, slot = GetBagSlotFromButton(button)
    if bag and slot and IsSlotLocked(bag, slot) then
        marker:SetVertexColor(GetLockMarkerColor())
        marker:Show()
    else
        marker:Hide()
    end
end

local function RefreshAllLockMarkers()
    for button, _ in pairs(hookedSlotButtons) do
        UpdateButtonLockMarker(button)
    end
end

local function HasLockedSlots()
    local locks = GetLockedSlotsTable()
    return locks ~= nil and next(locks) ~= nil
end

local BAGSTER_FRAME_COUNT = 3
local BAGNON_SLOT_FRAMES = { "inventory", "bank" }

-- Markers only render on visible slot buttons, and each button re-syncs its own marker on OnShow.
local function IsAnyBagUIVisible()
    if BankFrame and BankFrame:IsShown() then
        return true
    end
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            return true
        end
    end
    for i = 1, BAGSTER_FRAME_COUNT do
        local frame = _G["DragonUI_BagsterFrame" .. i]
        if frame and frame:IsShown() then
            return true
        end
    end
    for _, frameType in ipairs(BAGNON_SLOT_FRAMES) do
        local frame = GetBagnonFrame(frameType)
        if frame and frame.IsShown and frame:IsShown() then
            return true
        end
    end
    return false
end

local function ToggleSlotLockByBagSlot(bag, slot)
    local newState = not IsSlotLocked(bag, slot)
    SetSlotLocked(bag, slot, newState)
    if newState then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00cc66DragonUI:|r " .. T("Slot locked (bag %d, slot %d).", "Slot locked (bag %d, slot %d)."), bag, slot), 0.4, 1, 0.4)
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00cc66DragonUI:|r " .. T("Slot unlocked (bag %d, slot %d).", "Slot unlocked (bag %d, slot %d)."), bag, slot), 0.4, 1, 0.4)
    end

    RefreshAllLockMarkers()
end

GetBagSlotFromButton = function(btn)
    if not btn then return nil, nil end

    local bag, slot

    -- Neither is a real slot; falling through would misread it as bag 0.
    if IsBagnonGuildBankSlot(btn) or IsBagnonBagToggleButton(btn) then
        return nil, nil
    end

    -- Bagster item buttons expose GetBag/GetID.
    if btn.GetBag and btn.GetID then
        bag = btn:GetBag()
        slot = btn:GetID()
    end

    -- Bagnon variants commonly expose bag/slot as fields or GetBagID/GetSlotID methods.
    if (not bag) and btn.GetBagID and btn.GetSlotID then
        bag = btn:GetBagID()
        slot = btn:GetSlotID()
    end

    if (not bag) then
        bag = btn.bag or btn.bagID or btn.bagId or btn:GetParent() and (btn:GetParent().bag or btn:GetParent().bagID or btn:GetParent().bagId)
        slot = btn.slot or btn.slotID or btn.slotId or btn.id
    end

    -- Vanilla bank generic slots (BankFrameItem1..N).
    -- Must be checked BEFORE the parent-frame path: BankFrame:GetID() returns 0
    -- (truthy in Lua), which would cause the parent check to match and store the
    -- lock under bag=0 (backpack) instead of BANK_CONTAINER.
    if (not bag) and btn.GetName then
        local name = btn:GetName()
        if name then
            local bankSlot = tonumber(string.match(name, "^BankFrameItem(%d+)$"))
            if bankSlot then
                bag = BANK_CONTAINER
                slot = bankSlot
            end
        end
    end

    -- Vanilla container item buttons: bag id comes from parent frame.
    if (not bag) and btn.GetParent and btn.GetID then
        local parent = btn:GetParent()
        if parent and parent.GetID then
            bag = parent:GetID()
            slot = btn:GetID()
        end
    end

    if bag == nil or slot == nil then return nil, nil end
    bag = tonumber(bag)
    slot = tonumber(slot)
    if bag == nil or slot == nil then return nil, nil end
    if type(slot) ~= "number" or slot < 1 then return nil, nil end
    return bag, slot
end

local function GetHoveredBagSlot()
    if not GameTooltip or not GameTooltip:IsShown() then return nil, nil end
    local owner = GameTooltip:GetOwner()
    if not owner then return nil, nil end

    local bag, slot

    -- Neither is a real slot; falling through would misread it as bag 0.
    if IsBagnonGuildBankSlot(owner) or IsBagnonBagToggleButton(owner) then
        return nil, nil
    end

    -- Bagster item buttons expose GetBag/GetID.
    if owner.GetBag and owner.GetID then
        bag = owner:GetBag()
        slot = owner:GetID()
    end

    if (not bag) and owner.GetBagID and owner.GetSlotID then
        bag = owner:GetBagID()
        slot = owner:GetSlotID()
    end

    if (not bag) then
        bag = owner.bag or owner.bagID or owner.bagId or owner:GetParent() and (owner:GetParent().bag or owner:GetParent().bagID or owner:GetParent().bagId)
        slot = owner.slot or owner.slotID or owner.slotId or owner.id
    end

    -- Vanilla bank generic slots (BankFrameItem1..N).
    -- Must be checked BEFORE the parent-frame path for the same reason as
    -- GetBagSlotFromButton: BankFrame:GetID() returns 0 which is truthy.
    if (not bag) and owner.GetName then
        local name = owner:GetName()
        if name then
            local bankSlot = tonumber(string.match(name, "^BankFrameItem(%d+)$"))
            if bankSlot then
                bag = BANK_CONTAINER
                slot = bankSlot
            end
        end
    end

    -- Vanilla container item buttons: bag id is on parent frame.
    if (not bag) and owner.GetParent and owner.GetID then
        local parent = owner:GetParent()
        if parent and parent.GetID then
            bag = parent:GetID()
            slot = owner:GetID()
        end
    end

    if bag == nil or slot == nil then return nil, nil end
    bag = tonumber(bag)
    slot = tonumber(slot)
    if bag == nil or slot == nil then return nil, nil end
    if type(slot) ~= "number" or slot < 1 then return nil, nil end
    return bag, slot
end

local function ToggleHoveredSlotLock()
    local bag, slot = GetHoveredBagSlot()
    if not bag or not slot then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Hover an item or slot, then type /sortlock.", "Hover an item or slot, then type /sortlock."), 1, 0.8, 0)
        return
    end

    ToggleSlotLockByBagSlot(bag, slot)
end

-- ============================================================================
-- BAGNON COMPATIBILITY: NATIVE SORT INTEGRATION
-- ============================================================================
-- Hooks Bagnon's own Sorting.GetSpaces so it respects DragonUI's locked slots.

-- Min delay between moves from Bagnon's own sort (avoids flooding high-latency realms).
local BAGNON_MOVE_THROTTLE = 0.15

local function GetBagnonFrameKind(itemFrame)
    if type(itemFrame) ~= "table" then return "unknown" end
    if type(itemFrame.GetVisibleBags) == "function" and type(itemFrame.GetBagSize) == "function" then
        return "bags" -- inventory or personal bank; both share this API
    end
    if type(itemFrame.GetCurrentTab) == "function" then
        return "guildbank"
    end
    return "unknown"
end

local function GetBagnonSpaces(sortModule, originalGetSpaces, ...)
    if type(originalGetSpaces) ~= "function" then return {} end

    local itemFrame = sortModule and sortModule.itemFrame
    if GetBagnonFrameKind(itemFrame) == "guildbank" then
        -- Not supported: skip the real GetSpaces entirely.
        return {}
    end

    local ok, spaces = pcall(originalGetSpaces, sortModule, ...)
    if not ok then
        -- Fail gracefully instead of propagating a Lua error to the user.
        return {}
    end
    if type(spaces) ~= "table" then
        return spaces
    end

    if not BagSortModule.applied then
        return spaces
    end

    local filteredSpaces = {}
    for _, space in ipairs(spaces) do
        if not (space and space.bag and space.slot and IsSlotLocked(space.bag, space.slot)) then
            if space then
                space.index = #filteredSpaces
                if space.item then
                    space.item.space = space
                end
                tinsert(filteredSpaces, space)
            end
        end
    end

    return filteredSpaces
end

local function InstallAltClickHooks()
    if clickHooksInstalled then return end
    clickHooksInstalled = true

    local function HookSlotButton(button)
        if not button or button._dragonUISortLockHooked then return end

        local objectType = button.GetObjectType and button:GetObjectType()
        if objectType ~= "Button" and objectType ~= "CheckButton" then
            return
        end

        button._dragonUISortLockHooked = true
        hookedSlotButtons[button] = true
        EnsureLockMarker(button)

        button:HookScript("OnShow", function(self)
            UpdateButtonLockMarker(self)
        end)

        button:HookScript("OnHide", function(self)
            if self._dragonUISortLockMarker then
                self._dragonUISortLockMarker:Hide()
            end
        end)

        local function HandleAltClick(self, mouseButton)
            if not BagSortModule.applied then return end
            if not IsLockHotkeyPressed(mouseButton) then return end
            local now = GetTime and GetTime() or 0
            if self._dragonUISortLockLastClick and now > 0 and (now - self._dragonUISortLockLastClick) < 0.15 then
                return
            end
            self._dragonUISortLockLastClick = now

            local bag, slot = GetBagSlotFromButton(self)
            if not bag or not slot then return end

            ToggleSlotLockByBagSlot(bag, slot)

            -- Cancel pickup side effect from default click handlers.
            if CursorHasItem() then
                PickupContainerItem(bag, slot)
                if CursorHasItem() then
                    ClearCursor()
                end
            end
        end

        button:HookScript("OnClick", HandleAltClick)
        button:HookScript("PostClick", HandleAltClick)
        button:HookScript("OnMouseUp", HandleAltClick)

        UpdateButtonLockMarker(button)
    end

    local function HookKnownSlotButtons()
        -- Vanilla container bag items
        for frameIndex = 1, NUM_CONTAINER_FRAMES do
            for slot = 1, 36 do
                local btn = _G["ContainerFrame" .. frameIndex .. "Item" .. slot]
                if btn then HookSlotButton(btn) end
            end
        end

        -- Vanilla bank main container slots
        for slot = 1, (NUM_BANKGENERIC_SLOTS or 28) do
            local btn = _G["BankFrameItem" .. slot]
            if btn then HookSlotButton(btn) end
        end

        -- Bagster item slots
        for idx = 1, 400 do
            local btn = _G["DragonUI_BagsterItem" .. idx]
            if btn then HookSlotButton(btn) end
        end
    end

    local function HookBagnonSlotButtons()
        local function HookBagnonItemFrame(itemFrame)
            if type(itemFrame) ~= "table" then return end

            -- Guild bank slots may reach here too; GetBagSlotFromButton() rejects them safely.
            if type(itemFrame.GetAllItemSlots) == "function" then
                for _, itemSlot in itemFrame:GetAllItemSlots() do
                    if itemSlot then
                        HookSlotButton(itemSlot)
                    end
                end
            elseif type(itemFrame.itemSlots) == "table" then
                for _, itemSlot in pairs(itemFrame.itemSlots) do
                    if itemSlot then
                        HookSlotButton(itemSlot)
                    end
                end
            end
        end

        local function HookBagnonFrameObject(frame)
            if type(frame) ~= "table" then return end
            if type(frame.GetItemFrame) == "function" then
                HookBagnonItemFrame(frame:GetItemFrame())
            end
            HookBagnonItemFrame(frame.itemFrame)
        end

        local function HookFrameChildren(frame, depth)
            if not frame or depth > 5 or not frame.GetChildren then return end
            local children = { frame:GetChildren() }
            for _, child in ipairs(children) do
                if GetBagSlotFromButton(child) then
                    HookSlotButton(child)
                end
                HookFrameChildren(child, depth + 1)
            end
        end

        local inventoryFrame = GetBagnonFrame("inventory")
        local bankFrame = GetBagnonFrame("bank")
        HookBagnonFrameObject(inventoryFrame)
        HookBagnonFrameObject(bankFrame)
        HookFrameChildren(inventoryFrame, 1)
        HookFrameChildren(bankFrame, 1)

        local bagnon = _G.Bagnon
        local frames = bagnon and (bagnon.frames or bagnon.Frames)
        if type(frames) == "table" then
            for _, frame in pairs(frames) do
                HookBagnonFrameObject(frame)
            end
        end
    end

    local function InstallBagnonIntegrationHooks()
        local bagnon = _G.Bagnon
        if not bagnon then return end

        if not bagnonSortingHooked and bagnon.Sorting and type(bagnon.Sorting.GetSpaces) == "function" then
            bagnonSortingHooked = true
            bagnonOriginalGetSpaces = bagnon.Sorting.GetSpaces
            bagnon.Sorting.GetSpaces = function(sortModule, ...)
                return GetBagnonSpaces(sortModule, bagnonOriginalGetSpaces, ...)
            end
        end

        -- Refusing a move here just leaves it unsorted; Bagnon retries shortly after.
        if not bagnonMoveHooked and bagnon.Sorting and type(bagnon.Sorting.Move) == "function" then
            bagnonMoveHooked = true
            bagnonOriginalMove = bagnon.Sorting.Move
            local lastBagnonMoveTime = 0
            bagnon.Sorting.Move = function(sortModule, ...)
                if not BagSortModule.applied then
                    return bagnonOriginalMove(sortModule, ...)
                end
                local now = GetTime and GetTime() or 0
                if lastBagnonMoveTime > 0 and (now - lastBagnonMoveTime) < BAGNON_MOVE_THROTTLE then
                    return false
                end
                lastBagnonMoveTime = now
                return bagnonOriginalMove(sortModule, ...)
            end
        end

        if not bagnonFrameHooksInstalled then
            bagnonFrameHooksInstalled = true

            local function RefreshBagnonIntegration()
                if not BagSortModule.applied then return end
                if addon.After then
                    addon:After(0.1, function()
                        if BagSortModule.applied then
                            UpdateButtonVisibility()
                            HookBagnonSlotButtons()
                        end
                    end)
                else
                    UpdateButtonVisibility()
                    HookBagnonSlotButtons()
                end
            end

            if type(bagnon.ShowFrame) == "function" then
                hooksecurefunc(bagnon, "ShowFrame", RefreshBagnonIntegration)
            end
            if type(bagnon.CreateFrame) == "function" then
                hooksecurefunc(bagnon, "CreateFrame", RefreshBagnonIntegration)
            end
        end

        if not bagnonIntegrationHooked then
            if type(bagnon.ItemFrame) == "table" and type(bagnon.ItemFrame.AddItemSlot) == "function" then
                bagnonIntegrationHooked = true
                hooksecurefunc(bagnon.ItemFrame, "AddItemSlot", function(itemFrame, bag, slot)
                    if not BagSortModule.applied or type(itemFrame) ~= "table" or type(itemFrame.GetItemSlot) ~= "function" then return end
                    local itemSlot = itemFrame:GetItemSlot(bag, slot)
                    if itemSlot then
                        HookSlotButton(itemSlot)
                        UpdateButtonLockMarker(itemSlot)
                    end
                end)
            elseif type(bagnon.Frame) == "table" and type(bagnon.Frame.CreateItemFrame) == "function" then
                bagnonIntegrationHooked = true
                hooksecurefunc(bagnon.Frame, "CreateItemFrame", function(frame)
                    if not BagSortModule.applied then return end
                    if type(frame) == "table" and type(frame.GetItemFrame) == "function" then
                        local itemFrame = frame:GetItemFrame()
                        if itemFrame then
                            HookBagnonSlotButtons()
                        end
                    end
                end)
            end
        end
    end

    local function RequestBagnonSlotScan()
        bagnonSlotScanRequested = true
        bagnonSlotScanPasses = 0
    end

    BagSortModule.RequestBagnonSlotScan = RequestBagnonSlotScan
    BagSortModule.ScanBagnonSlots = HookBagnonSlotButtons

    InstallBagnonIntegrationHooks()
    HookKnownSlotButtons()
    HookBagnonSlotButtons()
    RefreshAllLockMarkers()

    lockVisualFrame = CreateFrame("Frame")
    local elapsed = 0
    local bagnonElapsed = 0
    lockVisualFrame:SetScript("OnUpdate", function(self, dt)
        if not BagSortModule.applied then return end
        elapsed = elapsed + dt
        if bagnonSlotScanRequested then
            bagnonElapsed = bagnonElapsed + dt
            if bagnonElapsed >= 1 then
                bagnonElapsed = 0
                HookBagnonSlotButtons()
                bagnonSlotScanPasses = bagnonSlotScanPasses + 1
                if bagnonSlotScanPasses >= 4 then
                    bagnonSlotScanRequested = false
                end
            end
        end
        if elapsed < 0.4 then return end
        elapsed = 0
        InstallBagnonIntegrationHooks()
        -- Closed bags show no marker and create no slot button, so there is nothing to find.
        if not IsAnyBagUIVisible() then return end
        HookKnownSlotButtons()
        if HasLockedSlots() then
            RefreshAllLockMarkers()
        end
    end)
end

local function ClearAllLockedSlots()
    local locks = GetLockedSlotsTable()
    if not locks then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Could not clear locks (config not ready).", "Could not clear locks (config not ready)."), 1, 0.4, 0.4)
        return
    end
    wipe(locks)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Cleared all sort-locked slots.", "Cleared all sort-locked slots."), 0.4, 1, 0.4)
    RefreshAllLockMarkers()
end



-- ============================================================================
-- GUILD BANK COMPATIBILITY: SYNTHETIC BAG IDS
-- ============================================================================
-- Guild bank tab N is treated as bag id (GUILDBANK_TAB_OFFSET + N), reusing
-- the whole scan/compress/sort/move pipeline instead of duplicating it.
local GUILDBANK_TAB_OFFSET = 50

local function IsGuildBankBag(bag)
    return bag > GUILDBANK_TAB_OFFSET
end

-- Returns 0 for tabs without full view+deposit+withdraw access.
local function GetGuildBankTabSlotCount(tab)
    if type(GetGuildBankTabInfo) ~= "function" then return 0 end
    local name, _, canView, canDeposit, numWithdrawals = GetGuildBankTabInfo(tab)
    -- numWithdrawals is negative when withdrawals are unlimited for this rank.
    if name and canView and canDeposit and numWithdrawals ~= 0 then
        return 98 -- MAX_GUILDBANK_SLOTS_PER_TAB; no reliable global constant for this in 3.3.5a
    end
    return 0
end

local function BagGetItemLink(bag, slot)
    if IsGuildBankBag(bag) then
        return GetGuildBankItemLink(bag - GUILDBANK_TAB_OFFSET, slot)
    end
    return GetContainerItemLink(bag, slot)
end

local function BagGetItemInfo(bag, slot)
    if IsGuildBankBag(bag) then
        return GetGuildBankItemInfo(bag - GUILDBANK_TAB_OFFSET, slot)
    end
    return GetContainerItemInfo(bag, slot)
end

local function BagPickupItem(bag, slot)
    if IsGuildBankBag(bag) then
        return PickupGuildBankItem(bag - GUILDBANK_TAB_OFFSET, slot)
    end
    return PickupContainerItem(bag, slot)
end

local function BagSplitItem(bag, slot, amount)
    if IsGuildBankBag(bag) then
        return SplitGuildBankItem(bag - GUILDBANK_TAB_OFFSET, slot, amount)
    end
    return SplitContainerItem(bag, slot, amount)
end

-- Pairs of inclusive (first, last) bag id spans, flattened in the order given.
local function ListBags(...)
    local bags = {}
    for i = 1, select("#", ...), 2 do
        local first, last = select(i, ...)
        for bag = first, last do
            bags[#bags + 1] = bag
        end
    end
    return bags
end

local carriedBags = ListBags(0, 4)
local playerPoolBags = ListBags(0, 4, -2, -2)
local bankPoolBags = ListBags(-1, -1, 5, 11)
local personalBags = ListBags(-1, 11, -2, -2)

local SOUL_SHARD_ID = 6265
local UNRANKED = 99

local classRankByName, subclassRankByClass, weaponClassName, armorClassName

-- A repeated name ends up with its last position.
local function PositionsByName(...)
    local positions = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            positions[value] = index
        end
    end
    return positions
end

local function LoadAuctionRanks()
    if classRankByName then return end
    classRankByName = PositionsByName(GetAuctionItemClasses())
    subclassRankByClass = {}
    for _, rank in pairs(classRankByName) do
        subclassRankByClass[rank] = PositionsByName(GetAuctionItemSubClasses(rank))
    end
    weaponClassName, armorClassName = GetAuctionItemClasses()
end

-- Only the relative order matters; unlisted equip locations rank below all of these.
local gearRankByEquipLoc = {}
for rank, group in ipairs({
    "AMMO", "HEAD", "NECK", "SHOULDER", "BODY", "CHEST ROBE", "WAIST", "LEGS", "FEET", "WRIST", "HAND",
    "FINGER", "TRINKET", "CLOAK", "WEAPON", "SHIELD", "2HWEAPON", "WEAPONMAINHAND", "WEAPONOFFHAND",
    "HOLDABLE", "RANGED", "THROWN", "RANGEDRIGHT", "RELIC", "TABARD",
}) do
    for suffix in string.gmatch(group, "%S+") do
        gearRankByEquipLoc["INVTYPE_" .. suffix] = rank
    end
end

local itemFacts = {}
local slotGrid = {}

local function LearnItem(itemID)
    local facts = itemFacts[itemID]
    if facts then return facts end
    LoadAuctionRanks()
    local name, _, quality, level, _, class, subclass, stack, equipLoc = GetItemInfo(itemID)
    facts = {
        name = name or "",
        quality = quality or 0,
        level = level or 0,
        class = class or "",
        subclass = subclass or "",
        stack = stack or 1,
        equipLoc = equipLoc or "",
    }
    local classRank = classRankByName[facts.class] or UNRANKED
    local siblings = subclassRankByClass[classRank]
    facts.classRank = classRank
    facts.subclassRank = siblings and siblings[facts.subclass] or UNRANKED
    facts.isGear = facts.class == weaponClassName or facts.class == armorClassName
    facts.gearRank = gearRankByEquipLoc[facts.equipLoc] or 0
    itemFacts[itemID] = facts
    return facts
end

local function BagSlotCount(bag)
    if IsGuildBankBag(bag) then
        return GetGuildBankTabSlotCount(bag - GUILDBANK_TAB_OFFSET)
    end
    return GetContainerNumSlots(bag) or 0
end

-- Sort locks are read here only; a lock toggled mid-sort applies to the next sort.
local function CaptureBags(bags)
    wipe(slotGrid)
    wipe(itemFacts)
    for _, bag in ipairs(bags) do
        local column = {}
        for slot = 1, BagSlotCount(bag) do
            local cell = { bag = bag, slot = slot, pinned = IsSlotLocked(bag, slot) }
            local itemID = ItemIDFromLink(BagGetItemLink(bag, slot))
            if itemID then
                local _, count = BagGetItemInfo(bag, slot)
                cell.item = itemID
                cell.qty = count or 0
                cell.cap = LearnItem(itemID).stack
            end
            column[slot] = cell
        end
        slotGrid[bag] = column
    end
end

local function ReleaseSnapshot()
    wipe(slotGrid)
    wipe(itemFacts)
end

-- Bag family (0 = normal). Specialty bags (herb/enchant/…) sort in their own pool.
local function GetBagFamily(bag)
    if bag == BACKPACK_CONTAINER or bag == BANK_CONTAINER then
        return 0
    end
    -- Own pool (GetItemFamily 0x0100); never mix keys into normal/profession bags
    if bag == KEYRING_CONTAINER then
        return 0x0100
    end
    if IsGuildBankBag(bag) then
        return 0
    end
    local _, bagType = GetContainerNumFreeSlots(bag)
    return bagType or 0
end

-- Specialty families first, then normal (0), so profession bags never share a sort pool.
local function GroupBagsByFamily(bags)
    local groups, families = {}, {}
    for _, bag in ipairs(bags) do
        local family = GetBagFamily(bag)
        if not groups[family] then
            groups[family] = {}
            tinsert(families, family)
        end
        tinsert(groups[family], bag)
    end
    table.sort(families, function(a, b)
        if a == 0 then return false end
        if b == 0 then return true end
        return a > b
    end)
    return families, groups
end

local SORT_CHAT_PREFIX = "|cff00cc66DragonUI:|r "

local function Notify(key, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage(SORT_CHAT_PREFIX .. T(key, key), r, g, b)
end

local function ResetPlan()
    wipe(plannedMoves)
    nextMoveIndex = 1
end

-- Mirrors what the executor's drop does: a merge tops the target up and leaves the rest behind.
local function QueueMove(from, to)
    if from.item and from.item == to.item and to.qty < to.cap then
        local total = from.qty + to.qty
        if total > to.cap then
            from.qty, to.qty = total - to.cap, to.cap
        else
            to.qty = total
            from.item, from.qty, from.cap = nil, nil, nil
        end
    else
        from.item, to.item = to.item, from.item
        from.qty, to.qty = to.qty, from.qty
        from.cap, to.cap = to.cap, from.cap
    end
    plannedMoves[#plannedMoves + 1] = { fromBag = from.bag, fromSlot = from.slot, toBag = to.bag, toSlot = to.slot }
end

local function UnlockedCells(bags)
    local cells = {}
    for _, bag in ipairs(bags) do
        local column = slotGrid[bag]
        if column then
            for slot = 1, #column do
                local cell = column[slot]
                if not cell.pinned then
                    cells[#cells + 1] = cell
                end
            end
        end
    end
    return cells
end

local function CopyList(list, backwards)
    local copy, size = {}, #list
    for i = 1, size do
        copy[i] = list[backwards and (size + 1 - i) or i]
    end
    return copy
end

local function TopUpStacks(donorBags, receiverBags, fullDonorsAllowed)
    local openStacks = {}
    for _, cell in ipairs(UnlockedCells(receiverBags)) do
        if cell.qty ~= cell.cap then
            openStacks[#openStacks + 1] = cell
        end
    end
    local receiversLastFirst = CopyList(openStacks, true)
    local gaveAway = {}
    for _, donor in ipairs(CopyList(UnlockedCells(donorBags), true)) do
        if donor.item and (fullDonorsAllowed or donor.qty < donor.cap) then
            for _, receiver in ipairs(receiversLastFirst) do
                if donor.item and receiver.item == donor.item and receiver ~= donor
                    and receiver.qty ~= receiver.cap and not gaveAway[receiver] then
                    gaveAway[donor] = true
                    QueueMove(donor, receiver)
                end
            end
        end
    end
end

-- Not a strict weak order (unranked classes, equal names, empties); table.sort's pass order decides those.
local function ComesBefore(a, b)
    local itemA, itemB = a.item, b.item
    if not itemB then return itemA ~= nil end
    if not itemA then return false end
    if itemA == itemB then
        if a.qty ~= b.qty then return a.qty < b.qty end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end
    local fa, fb = itemFacts[itemA], itemFacts[itemB]
    if fa.quality ~= fb.quality then
        if fa.quality == 0 then return false end
        if fb.quality == 0 then return true end
    end
    if itemA == SOUL_SHARD_ID then return false end
    if itemB == SOUL_SHARD_ID then return true end
    if fa.classRank ~= fb.classRank then return fa.classRank < fb.classRank end
    if fa.quality ~= fb.quality then return fa.quality > fb.quality end
    if fa.isGear then
        if fa.gearRank ~= fb.gearRank then return fa.gearRank < fb.gearRank end
    elseif fa.subclass ~= fb.subclass then
        return fa.subclassRank < fb.subclassRank
    end
    if fa.level ~= fb.level then return fa.level > fb.level end
    return fa.name < fb.name
end

local function ReverseStackEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.reverse_stack
end

-- Moves planned in one round touch disjoint slots, so the executor can issue them in a single tick.
local function ArrangePool(bags)
    local order = UnlockedCells(bags)
    local total = #order
    local homes = CopyList(order, ReverseStackEnabled())
    table.sort(order, ComesBefore)

    local positionOf = {}
    for i = 1, total do
        positionOf[order[i]] = i
    end

    local busy = {}
    local deferred = true
    while deferred do
        deferred = false
        wipe(busy)
        for i = 1, total do
            local holder, home = order[i], homes[i]
            local needed = holder ~= home and holder.item
                and not (holder.item == home.item and holder.qty == home.qty)
            if needed and (busy[holder] or busy[home]) then
                deferred = true
            elseif needed then
                busy[holder], busy[home] = true, true
                QueueMove(holder, home)
                local displaced = positionOf[home]
                order[displaced], positionOf[holder] = holder, displaced
                order[i], positionOf[home] = home, i
            end
        end
    end
end

local function PlanFamilyPools(candidates)
    local familyOrder, bagsByFamily = GroupBagsByFamily(candidates)
    for _, family in ipairs(familyOrder) do
        local poolBags = bagsByFamily[family]
        TopUpStacks(poolBags, poolBags, false)
        ArrangePool(poolBags)
    end
end

local tickDriver = CreateFrame("Frame")
tickDriver:Hide()

StopSorting = function(reason)
    running = false
    guildBankSortActive = false
    awaitedDrop = nil
    ResetPlan()
    tickDriver:Hide()
    if reason then
        DEFAULT_CHAT_FRAME:AddMessage(reason, 1, 0.4, 0.4)
    end
end

local function IsSlotBusy(bag, slot)
    local _, _, busy = BagGetItemInfo(bag, slot)
    return busy
end

local function IssueNextMoves()
    if CursorHasItem() then
        local _, _, cursorLink = GetCursorInfo()
        if ItemIDFromLink(cursorLink) ~= (awaitedDrop and awaitedDrop.item) then
            StopSorting("DragonUI: Sort interrupted.")
            return
        end
    end
    if awaitedDrop then
        if ItemIDFromLink(BagGetItemLink(awaitedDrop.bag, awaitedDrop.slot)) ~= awaitedDrop.item then
            return
        end
        awaitedDrop = nil
    end

    while nextMoveIndex <= #plannedMoves do
        if CursorHasItem() then return end
        local move = plannedMoves[nextMoveIndex]
        local fromBag, fromSlot, toBag, toSlot = move.fromBag, move.fromSlot, move.toBag, move.toSlot
        if IsSlotBusy(fromBag, fromSlot) or IsSlotBusy(toBag, toSlot) then return end
        nextMoveIndex = nextMoveIndex + 1

        local sourceLink = BagGetItemLink(fromBag, fromSlot)
        if not sourceLink then
            StopSorting("DragonUI: Sort confused, stopping.")
            return
        end
        local itemID = ItemIDFromLink(sourceLink)
        awaitedDrop = { bag = toBag, slot = toSlot, item = itemID }
        local stackLimit = itemID and select(8, GetItemInfo(itemID)) or 1

        local _, targetCount = BagGetItemInfo(toBag, toSlot)
        local _, sourceCount = BagGetItemInfo(fromBag, fromSlot)
        local sameItem = ItemIDFromLink(BagGetItemLink(toBag, toSlot)) == itemID
        -- Uncached items fall back to a limit of 1, so this amount can be zero or negative; passed as is.
        if sameItem and targetCount and targetCount ~= stackLimit
            and targetCount + (sourceCount or 0) > stackLimit then
            BagSplitItem(fromBag, fromSlot, stackLimit - targetCount)
        else
            BagPickupItem(fromBag, fromSlot)
        end

        local guildSource = IsGuildBankBag(fromBag)
        if guildSource or CursorHasItem() then
            BagPickupItem(toBag, toSlot)
        end
        -- The guild bank updates cursor and slots late, so only one guild move goes out per tick.
        if guildSource then return end
    end

    Notify("Sort complete.", 0.4, 1, 0.4)
    StopSorting()
end

tickDriver:SetScript("OnUpdate", function(_, elapsed)
    tickAccumulator = tickAccumulator + elapsed
    if tickAccumulator >= GetSortMoveInterval() then
        tickAccumulator = 0
        IssueNextMoves()
    end
end)

local function BeginMoves()
    ReleaseSnapshot()
    if #plannedMoves == 0 then
        return false
    end
    running = true
    tickDriver:Show()
    return true
end

local function SlotCode(bag, slot)
    return bag * 100 + slot
end

local function PrintBankScan()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66" .. T("=== BANK SCAN DEBUG ===", "=== BANK SCAN DEBUG ===") .. "|r")
    for _, bag in ipairs(bankPoolBags) do
        local column = slotGrid[bag] or {}
        for slot = 1, #column do
            local cell = column[slot]
            if cell.item then
                local facts = itemFacts[cell.item]
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] bag%s/s%s: %s (id=%s r=%s lv=%s t=%s st=%s eq=%s x%s)",
                    SlotCode(bag, slot), bag, slot, facts.name, cell.item, facts.quality, facts.level,
                    facts.class, facts.subclass, facts.equipLoc, cell.qty))
            end
        end
    end
end

local function PrintPlannedMoves()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66=== " .. #plannedMoves .. " MOVES ===|r")
    for _, move in ipairs(plannedMoves) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  move: [%s]->  [%s]",
            SlotCode(move.fromBag, move.fromSlot), SlotCode(move.toBag, move.toSlot)))
    end
end

local function SortPlayerBags()
    if running then
        Notify("Sort already in progress.", 1, 0.8, 0)
        return
    end
    ResetPlan()
    CaptureBags(personalBags)
    PlanFamilyPools(playerPoolBags)
    if not BeginMoves() then
        Notify("Bags already sorted!", 0.4, 1, 0.4)
    end
end

local function SortBankBags()
    if running then
        Notify("Sort already in progress.", 1, 0.8, 0)
        return
    end
    if not bank_open then
        Notify("You must be at the bank.", 1, 0.4, 0.4)
        return
    end
    ResetPlan()
    CaptureBags(personalBags)
    if addon.debugMode then
        PrintBankScan()
    end
    -- Families are ignored here on purpose: any carried stack may top up any open bank stack.
    if IsBankFillFromBagsEnabled() then
        TopUpStacks(carriedBags, bankPoolBags, true)
    end
    PlanFamilyPools(bankPoolBags)
    if addon.debugMode then
        PrintPlannedMoves()
    end
    if not BeginMoves() then
        Notify("Bank already sorted!", 0.4, 1, 0.4)
    end
end

-- Only the shown tab is touched; crossing tabs would spend withdrawal allowance just to reorder.
local function PerformGuildBankSort()
    if running then
        Notify("Sort already in progress.", 1, 0.8, 0)
        return
    end
    if not guild_bank_open then
        Notify("You must be at the guild bank.", 1, 0.4, 0.4)
        return
    end
    if not GetCurrentGuildBankTab then return end
    local tab = GetCurrentGuildBankTab()
    if not tab or tab < 1 then
        Notify("Could not determine the current guild bank tab.", 1, 0.4, 0.4)
        return
    end
    if GetGuildBankTabSlotCount(tab) == 0 then
        Notify("You need full deposit and withdraw access to this tab to sort it.", 1, 0.4, 0.4)
        return
    end
    local tabBags = { GUILDBANK_TAB_OFFSET + tab }
    ResetPlan()
    CaptureBags(tabBags)
    TopUpStacks(tabBags, tabBags, false)
    ArrangePool(tabBags)
    if #plannedMoves == 0 then
        ReleaseSnapshot()
        Notify("This guild bank tab is already sorted!", 0.4, 1, 0.4)
        return
    end
    guildBankSortActive = true
    BeginMoves()
end

StaticPopupDialogs["DRAGONUI_CONFIRM_GUILDBANK_SORT"] = {
    text = T("Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand.", "Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."),
    button1 = T("Sort", "Sort"),
    button2 = CANCEL,
    OnAccept = PerformGuildBankSort,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function SortGuildBankTab()
    if running then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Sort already in progress.", "Sort already in progress."), 1, 0.8, 0)
        return
    end
    if not guild_bank_open then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("You must be at the guild bank.", "You must be at the guild bank."), 1, 0.4, 0.4)
        return
    end
    StaticPopup_Show("DRAGONUI_CONFIRM_GUILDBANK_SORT")
end

local function HandleSortLockCommand(msg)
    local command = msg and string.lower(string.gsub(msg, "^%s*(.-)%s*$", "%1")) or ""
    if command == "clear" or command == "reset" then
        ClearAllLockedSlots()
        return
    end
    ToggleHoveredSlotLock()
end

-- ============================================================================
-- BUTTON CREATION HELPERS
-- ============================================================================

local function CreateActionButton(name, parent, onClick, tooltipTitle, scale, iconPath, tooltipLines)
    scale = scale or 1.0
    local size = 32 * scale
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(size, size)
    btn:EnableMouse(true)
    btn:SetFrameLevel(parent:GetFrameLevel() + 10)

    -- Icon fills the button
    local icon = btn:CreateTexture(name .. "Icon", "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconPath or "Interface\\Icons\\INV_Enchant_EssenceCosmicGreater")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Square border (action button style)
    local border = btn:CreateTexture(name .. "Border", "OVERLAY")
    border:SetSize(size * 62/36, size * 62/36)
    border:SetPoint("CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    btn.border = border

    -- Highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    btn.highlight = highlight

    -- Pushed feedback
    btn:SetScript("OnMouseDown", function(self)
        self.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipTitle or T("Sort Items", "Sort Items"))
        local lines = tooltipLines
        if type(lines) == "function" then
            lines = lines()
        end
        if type(lines) == "table" then
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line, 1, 1, 1, true)
            end
        elseif type(lines) == "string" then
            GameTooltip:AddLine(lines, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click handler
    btn:SetScript("OnClick", function()
        if onClick then onClick() end
    end)

    return btn
end

local function CreateSortButton(name, parent, onClick, tooltipText, scale)
    local function BuildTooltipLines()
        return {
            T("Click to sort items by type, rarity, and name.", "Click to sort items by type, rarity, and name."),
            string.format(T("%s any bag slot (item or empty) to lock or unlock it.", "%s any bag slot (item or empty) to lock or unlock it."), GetLockHotkeyLabel()),
            T("Click the lock-clear button to remove all locked slots.", "Click the lock-clear button to remove all locked slots.")
        }
    end

    return CreateActionButton(
        name,
        parent,
        onClick,
        tooltipText,
        scale,
        "Interface\\Icons\\INV_Enchant_EssenceCosmicGreater",
        BuildTooltipLines
    )
end

local function CreateClearLocksButton(name, parent, scale)
    local function BuildTooltipLines()
        return {
            T("Click to clear all locked bag slots.", "Click to clear all locked bag slots."),
            string.format(T("%s any bag slot (item or empty) to lock or unlock it.", "%s any bag slot (item or empty) to lock or unlock it."), GetLockHotkeyLabel())
        }
    end

    return CreateActionButton(
        name,
        parent,
        ClearAllLockedSlots,
        T("Clear Locked Slots", "Clear Locked Slots"),
        scale,
        "Interface\\Icons\\INV_Misc_Key_14",
        BuildTooltipLines
    )
end

-- ============================================================================
-- SELL SCRAP
-- ============================================================================

local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = copper % 100
    if gold > 0 then
        return string.format("|cffffd700%dg|r |cffc0c0c0%ds|r |cffeda55f%dc|r", gold, silver, copperRem)
    elseif silver > 0 then
        return string.format("|cffc0c0c0%ds|r |cffeda55f%dc|r", silver, copperRem)
    else
        return string.format("|cffeda55f%dc|r", copperRem)
    end
end

local function SellScrapItems()
    if not MerchantFrame or not MerchantFrame:IsShown() then
        print("|cffff9900DragonUI|r: " .. T("Open a merchant window first to sell scrap items.", "Open a merchant window first to sell scrap items."))
        return
    end

    local soldCount = 0
    local totalValue = 0

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                local _, _, quality, _, iType, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
                if quality == 0 and iType and iType ~= "Quest" and sellPrice and sellPrice > 0 then
                    local stackCount = select(2, GetContainerItemInfo(bag, slot)) or 1
                    UseContainerItem(bag, slot)
                    soldCount = soldCount + 1
                    totalValue = totalValue + (sellPrice * stackCount)
                end
            end
        end
    end

    if soldCount > 0 then
        print("|cffff9900DragonUI|r: " .. string.format(T("Sold %d scrap item(s) for %s.", "Sold %d scrap item(s) for %s."), soldCount, FormatMoney(totalValue)))
    else
        print("|cffff9900DragonUI|r: " .. T("No scrap items to sell.", "No scrap items to sell."))
    end
end

local function CreateSellScrapButton(name, parent, scale)
    local function BuildTooltipLines()
        return {
            T("Click to sell all gray (poor) items to vendor.", "Click to sell all gray (poor) items to vendor."),
            T("A merchant window must be open.", "A merchant window must be open.")
        }
    end

    return CreateActionButton(
        name,
        parent,
        SellScrapItems,
        T("Sell Scrap", "Sell Scrap"),
        scale,
        "Interface\\Icons\\INV_Misc_Coin_01",
        BuildTooltipLines
    )
end

-- ============================================================================
-- BAGSTER BUTTON INTEGRATION
-- ============================================================================

local bagsterBagSortBtn, bagsterBankSortBtn
local bagsterBagClearBtn, bagsterBankClearBtn
local bagsterBagSellScrapBtn, bagsterBankSellScrapBtn
local bagnonBagSortBtn, bagnonBankSortBtn
local bagnonBagClearBtn, bagnonBankClearBtn
local vanillaGuildBankSortBtn, bagnonGuildBankSortBtn

local function GetBagsterFrame(index)
    return _G["DragonUI_BagsterFrame" .. index]
end

local function AttachBagsterButtons(frame, sortRef, clearRef, sellScrapRef, sortFunc, sortBtnName, clearBtnName, sellScrapBtnName, tooltipText)
    if sortRef and clearRef and (not sellScrapBtnName or sellScrapRef) then
        return sortRef, clearRef, sellScrapRef
    end

    local frameName = frame:GetName()
    local searchBox = _G[frameName .. "Search"]
    local bagToggle = _G[frameName .. "BagToggle"]

    local sortBtn = sortRef or CreateSortButton(sortBtnName, frame, sortFunc, tooltipText, 0.55)
    local clearBtn = clearRef or CreateClearLocksButton(clearBtnName, frame, 0.55)
    local sellScrapBtn = sellScrapRef
    if sellScrapBtnName and not sellScrapRef then
        sellScrapBtn = CreateSellScrapButton(sellScrapBtnName, frame, 0.55)
    end

    -- Dragonflight action-button chrome for the header buttons (same recipe as buttons.lua)
    local function StyleHeaderButton(b)
        if not b or b._bagsterStyled then return end
        b._bagsterStyled = true
        b:SetSize(22, 22)
        b.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        b.border:SetTexture(addon._dir .. "ActionBars\\uiactionbariconframe")
        b.border:ClearAllPoints()
        b.border:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2.2, 2.3)
        b.border:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -2.2, -2.2)
        if b.highlight then
            b.highlight:SetTexture(addon._dir .. "ActionBars\\uiactionbariconframehighlight")
            b.highlight:ClearAllPoints()
            b.highlight:SetAllPoints(b.border)
        end
        b:SetScript("OnMouseDown", function(self)
            self.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        end)
        b:SetScript("OnMouseUp", function(self)
            self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        end)
    end
    StyleHeaderButton(sortBtn)
    StyleHeaderButton(clearBtn)
    StyleHeaderButton(sellScrapBtn)

    -- Single header row: [ searchBox ][ sellScrap ][ clearBtn ][ sortBtn ][ bagToggle ]
    if bagToggle then
        bagToggle:ClearAllPoints()
        bagToggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -30)
    end

    sortBtn:ClearAllPoints()
    if bagToggle then
        sortBtn:SetPoint("RIGHT", bagToggle, "LEFT", -6, 0)
    else
        sortBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -32)
    end

    clearBtn:ClearAllPoints()
    clearBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)

    if sellScrapBtn then
        sellScrapBtn:ClearAllPoints()
        sellScrapBtn:SetPoint("RIGHT", clearBtn, "LEFT", -4, 0)
    end

    -- Search box is fixed-width on the left; nothing to shrink anymore

    sortBtn:Show()
    clearBtn:Show()
    if sellScrapBtn then sellScrapBtn:Show() end
    return sortBtn, clearBtn, sellScrapBtn
end

local function CreateBagsterSortButtons()
    local inventoryFrame = GetBagsterFrame(1)
    local bankFrame = GetBagsterFrame(2)

    if inventoryFrame and (not bagsterBagSortBtn or not bagsterBagClearBtn or not bagsterBagSellScrapBtn) then
        bagsterBagSortBtn, bagsterBagClearBtn, bagsterBagSellScrapBtn = AttachBagsterButtons(
            inventoryFrame, bagsterBagSortBtn, bagsterBagClearBtn, bagsterBagSellScrapBtn,
            SortPlayerBags, "DragonUI_BagsterBagSortBtn", "DragonUI_BagsterBagClearBtn", "DragonUI_BagsterBagSellScrapBtn",
            T("Sort Bags", "Sort Bags")
        )
        BagSortModule.frames.bagsterBagSortBtn = bagsterBagSortBtn
        BagSortModule.frames.bagsterBagClearBtn = bagsterBagClearBtn
        BagSortModule.frames.bagsterBagSellScrapBtn = bagsterBagSellScrapBtn
    end

    if bankFrame and (not bagsterBankSortBtn or not bagsterBankClearBtn) then
        bagsterBankSortBtn, bagsterBankClearBtn = AttachBagsterButtons(
            bankFrame, bagsterBankSortBtn, bagsterBankClearBtn, nil,
            SortBankBags, "DragonUI_BagsterBankSortBtn", "DragonUI_BagsterBankClearBtn", nil,
            T("Sort Bank", "Sort Bank")
        )
        BagSortModule.frames.bagsterBankSortBtn = bagsterBankSortBtn
        BagSortModule.frames.bagsterBankClearBtn = bagsterBankClearBtn
    end
end

local function AttachBagnonButtons(frame, sortRef, clearRef, sortFunc, sortBtnName, clearBtnName, tooltipText)
    if not frame then return sortRef, clearRef end

    local sortBtn = sortRef
    local clearBtn = clearRef or CreateClearLocksButton(clearBtnName, frame, 0.62)

    if sortBtn then
        sortBtn:SetParent(frame)
        sortBtn:SetFrameStrata("HIGH")
        sortBtn:Hide()
    end
    clearBtn:SetParent(frame)
    clearBtn:ClearAllPoints()
    clearBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, -10)
    -- Bagnon's title bar keeps re-raising itself; a higher strata always wins.
    clearBtn:SetFrameStrata("HIGH")
    clearBtn:SetFrameLevel(frame:GetFrameLevel() + 20)
    clearBtn:Show()

    return sortBtn, clearBtn
end

local function CreateBagnonSortButtons()
    if not IsBagnonLoaded() then return end

    local inventoryFrame = GetBagnonFrame("inventory")
    local bankFrame = GetBagnonFrame("bank")

    if inventoryFrame and (bagnonBagSortBtn or not bagnonBagClearBtn) then
        bagnonBagSortBtn, bagnonBagClearBtn = AttachBagnonButtons(
            inventoryFrame, bagnonBagSortBtn, bagnonBagClearBtn,
            SortPlayerBags, "DragonUI_BagnonBagSortBtn", "DragonUI_BagnonBagClearBtn", T("Sort Bags", "Sort Bags")
        )
        BagSortModule.frames.bagnonBagSortBtn = bagnonBagSortBtn
        BagSortModule.frames.bagnonBagClearBtn = bagnonBagClearBtn
    end

    if bankFrame and (bagnonBankSortBtn or not bagnonBankClearBtn) then
        bagnonBankSortBtn, bagnonBankClearBtn = AttachBagnonButtons(
            bankFrame, bagnonBankSortBtn, bagnonBankClearBtn,
            SortBankBags, "DragonUI_BagnonBankSortBtn", "DragonUI_BagnonBankClearBtn", T("Sort Bank", "Sort Bank")
        )
        BagSortModule.frames.bagnonBankSortBtn = bagnonBankSortBtn
        BagSortModule.frames.bagnonBankClearBtn = bagnonBankClearBtn
    end
end

-- ============================================================================
-- GUILD BANK BUTTON INTEGRATION
-- ============================================================================
-- No "Clear Locks" button here -- guild bank slots are never lockable.

local function CreateGuildBankSortButton(name, parent)
    local function BuildTooltipLines()
        return {
            T("Click to sort items in the currently open guild bank tab.", "Click to sort items in the currently open guild bank tab."),
            T("Never moves items between tabs.", "Never moves items between tabs."),
        }
    end

    return CreateActionButton(
        name,
        parent,
        SortGuildBankTab,
        T("Sort Guild Bank Tab", "Sort Guild Bank Tab"),
        0.61,
        "Interface\\Icons\\INV_Enchant_EssenceCosmicGreater",
        BuildTooltipLines
    )
end

local function CreateVanillaGuildBankSortButton()
    if vanillaGuildBankSortBtn then return end
    local frame = _G.GuildBankFrame
    if not frame then return end

    vanillaGuildBankSortBtn = CreateGuildBankSortButton("DragonUI_VanillaGuildBankSortBtn", frame)
    vanillaGuildBankSortBtn:ClearAllPoints()
    vanillaGuildBankSortBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -212.5, 38)
    BagSortModule.frames.vanillaGuildBankSortBtn = vanillaGuildBankSortBtn
end

local bagsterGuildSortBtn
local function CreateBagsterGuildBankSortButton()
    if bagsterGuildSortBtn then return end
    local frame = _G["DragonUI_BagsterFrame3"]
    if not frame or not frame.itemFrame then return end

    -- Parented to the item grid so it auto-hides on the Log/Money/Info mode tabs
    bagsterGuildSortBtn = CreateGuildBankSortButton("DragonUI_BagsterGuildSortBtn", frame.itemFrame)
    bagsterGuildSortBtn:SetSize(22, 22)
    bagsterGuildSortBtn.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    bagsterGuildSortBtn.border:SetTexture(addon._dir .. "ActionBars\\uiactionbariconframe")
    bagsterGuildSortBtn.border:ClearAllPoints()
    bagsterGuildSortBtn.border:SetPoint("TOPRIGHT", bagsterGuildSortBtn, "TOPRIGHT", 2.2, 2.3)
    bagsterGuildSortBtn.border:SetPoint("BOTTOMLEFT", bagsterGuildSortBtn, "BOTTOMLEFT", -2.2, -2.2)
    if bagsterGuildSortBtn.highlight then
        bagsterGuildSortBtn.highlight:SetTexture(addon._dir .. "ActionBars\\uiactionbariconframehighlight")
        bagsterGuildSortBtn.highlight:ClearAllPoints()
        bagsterGuildSortBtn.highlight:SetAllPoints(bagsterGuildSortBtn.border)
    end
    bagsterGuildSortBtn:ClearAllPoints()
    bagsterGuildSortBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -31)
    BagSortModule.frames.bagsterGuildSortBtn = bagsterGuildSortBtn
end

local function CreateBagnonGuildBankSortButton()
    if bagnonGuildBankSortBtn then return end
    local frame = GetBagnonFrame("guildbank")
    if not frame then return end

    bagnonGuildBankSortBtn = CreateGuildBankSortButton("DragonUI_BagnonGuildBankSortBtn", frame)
    bagnonGuildBankSortBtn:SetParent(frame)
    -- See AttachBagnonButtons: needs its own strata to stay reliably clickable.
    bagnonGuildBankSortBtn:SetFrameStrata("HIGH")
    bagnonGuildBankSortBtn:ClearAllPoints()
    bagnonGuildBankSortBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -57, -9)
    bagnonGuildBankSortBtn:SetFrameLevel(frame:GetFrameLevel() + 20)
    BagSortModule.frames.bagnonGuildBankSortBtn = bagnonGuildBankSortBtn
end

-- ============================================================================
-- VANILLA FRAME BUTTON INTEGRATION
-- ============================================================================

local vanillaBagSortBtn, vanillaBankSortBtn
local vanillaBagClearBtn, vanillaBankClearBtn
local vanillaBagSellScrapBtn

local function CreateVanillaBagSortButton()
    if vanillaBagSortBtn then return end

    vanillaBagSortBtn = CreateSortButton(
        "DragonUI_VanillaBagSortBtn",
        UIParent,
        SortPlayerBags,
        T("Sort Bags", "Sort Bags"),
        0.63
    )
    vanillaBagClearBtn = CreateClearLocksButton("DragonUI_VanillaBagClearBtn", UIParent, 0.63)
    vanillaBagSellScrapBtn = CreateSellScrapButton("DragonUI_VanillaBagSellScrapBtn", UIParent, 0.63)
    vanillaBagSortBtn:Hide()
    vanillaBagClearBtn:Hide()
    vanillaBagSellScrapBtn:Hide()
    BagSortModule.frames.vanillaBagSortBtn = vanillaBagSortBtn
    BagSortModule.frames.vanillaBagClearBtn = vanillaBagClearBtn
    BagSortModule.frames.vanillaBagSellScrapBtn = vanillaBagSellScrapBtn
end

-- Find which ContainerFrame is currently showing bag 0 (backpack)
local function GetBackpackFrame()
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() and frame:GetID() == 0 then
            return frame
        end
    end
end

local function UpdateVanillaBagSortButton()
    if not vanillaBagSortBtn or not vanillaBagClearBtn then return end
    local backpack = GetBackpackFrame()
    if backpack then
        vanillaBagSortBtn:SetParent(backpack)
        vanillaBagClearBtn:SetParent(backpack)
        vanillaBagSellScrapBtn:SetParent(backpack)
        vanillaBagSortBtn:ClearAllPoints()
        vanillaBagClearBtn:ClearAllPoints()
        vanillaBagSellScrapBtn:ClearAllPoints()
        local titleAnchor = _G[backpack:GetName() .. "Name"]
        local skinChrome = backpack._dragonuiBagChrome
        if addon:IsModuleEnabled("bags_skin")
            and skinChrome and skinChrome.title and skinChrome.title:IsShown()
        then
            titleAnchor = skinChrome.title
        end
        vanillaBagSortBtn:SetPoint("TOP", titleAnchor, "BOTTOM", 70.5, -6.5)
        vanillaBagClearBtn:SetPoint("RIGHT", vanillaBagSortBtn, "LEFT", -3, 0)
        vanillaBagSellScrapBtn:SetPoint("RIGHT", vanillaBagClearBtn, "LEFT", -3, 0)
        vanillaBagSortBtn:SetFrameLevel(backpack:GetFrameLevel() + 10)
        vanillaBagClearBtn:SetFrameLevel(backpack:GetFrameLevel() + 10)
        vanillaBagSellScrapBtn:SetFrameLevel(backpack:GetFrameLevel() + 10)
        vanillaBagSortBtn:Show()
        vanillaBagClearBtn:Show()
        vanillaBagSellScrapBtn:Show()
    else
        vanillaBagSortBtn:Hide()
        vanillaBagClearBtn:Hide()
        vanillaBagSellScrapBtn:Hide()
    end
end

local function CreateVanillaBankSortButton()
    if vanillaBankSortBtn then return end

    local bankFrameUI = BankFrame
    if not bankFrameUI then return end

    vanillaBankSortBtn = CreateSortButton(
        "DragonUI_VanillaBankSortBtn",
        bankFrameUI,
        SortBankBags,
        T("Sort Bank", "Sort Bank"),
        0.70
    )
    vanillaBankClearBtn = CreateClearLocksButton("DragonUI_VanillaBankClearBtn", bankFrameUI, 0.70)
    -- Position near top-right, to the left of the close button
    local closeBtn = _G["BankCloseButton"]
    if closeBtn then
        vanillaBankSortBtn:SetPoint("RIGHT", closeBtn, "LEFT", 1, -33)
        vanillaBankClearBtn:SetPoint("RIGHT", vanillaBankSortBtn, "LEFT", -2, 0)
    else
        vanillaBankSortBtn:SetPoint("TOPRIGHT", bankFrameUI, "TOPRIGHT", -60, -8)
        vanillaBankClearBtn:SetPoint("RIGHT", vanillaBankSortBtn, "LEFT", -2, 0)
    end
    vanillaBankSortBtn:Show()
    vanillaBankClearBtn:Show()
    BagSortModule.frames.vanillaBankSortBtn = vanillaBankSortBtn
    BagSortModule.frames.vanillaBankClearBtn = vanillaBankClearBtn
end

-- ============================================================================
-- BUTTON VISIBILITY MANAGEMENT
-- ============================================================================

UpdateButtonVisibility = function()
    local bagsterActive = IsBagsterEnabled()
    local bagsterApplied = GetBagsterFrame(1) ~= nil

    if bagsterActive and bagsterApplied then
        CreateBagsterSortButtons()
        if bagsterBagSortBtn then bagsterBagSortBtn:Show() end
        if bagsterBagClearBtn then bagsterBagClearBtn:Show() end
        if bagsterBagSellScrapBtn then bagsterBagSellScrapBtn:Show() end
        if bagsterBankSortBtn then bagsterBankSortBtn:Show() end
        if bagsterBankClearBtn then bagsterBankClearBtn:Show() end
        if bagnonBagSortBtn then bagnonBagSortBtn:Hide() end
        if bagnonBagClearBtn then bagnonBagClearBtn:Hide() end
        if bagnonBankSortBtn then bagnonBankSortBtn:Hide() end
        if bagnonBankClearBtn then bagnonBankClearBtn:Hide() end
        if vanillaBagSortBtn then vanillaBagSortBtn:Hide() end
        if vanillaBagClearBtn then vanillaBagClearBtn:Hide() end
        if vanillaBagSellScrapBtn then vanillaBagSellScrapBtn:Hide() end
        if vanillaBankSortBtn then vanillaBankSortBtn:Hide() end
        if vanillaBankClearBtn then vanillaBankClearBtn:Hide() end
    elseif IsBagnonLoaded() then
        CreateBagnonSortButtons()
        if bagnonBagSortBtn then bagnonBagSortBtn:Hide() end
        if bagnonBagClearBtn then bagnonBagClearBtn:Show() end
        if bagnonBankSortBtn then bagnonBankSortBtn:Hide() end
        if bagnonBankClearBtn then bagnonBankClearBtn:Show() end
        if vanillaBagSortBtn then vanillaBagSortBtn:Hide() end
        if vanillaBagClearBtn then vanillaBagClearBtn:Hide() end
        if vanillaBagSellScrapBtn then vanillaBagSellScrapBtn:Hide() end
        if vanillaBankSortBtn then vanillaBankSortBtn:Hide() end
        if vanillaBankClearBtn then vanillaBankClearBtn:Hide() end
        if bagsterBagSortBtn then bagsterBagSortBtn:Hide() end
        if bagsterBagClearBtn then bagsterBagClearBtn:Hide() end
        if bagsterBagSellScrapBtn then bagsterBagSellScrapBtn:Hide() end
        if bagsterBankSortBtn then bagsterBankSortBtn:Hide() end
        if bagsterBankClearBtn then bagsterBankClearBtn:Hide() end
    else
        CreateVanillaBagSortButton()
        CreateVanillaBankSortButton()
        UpdateVanillaBagSortButton()
        if vanillaBankSortBtn then vanillaBankSortBtn:Show() end
        if vanillaBankClearBtn then vanillaBankClearBtn:Show() end
        if bagnonBagSortBtn then bagnonBagSortBtn:Hide() end
        if bagnonBagClearBtn then bagnonBagClearBtn:Hide() end
        if bagnonBankSortBtn then bagnonBankSortBtn:Hide() end
        if bagnonBankClearBtn then bagnonBankClearBtn:Hide() end
        if bagsterBagSortBtn then bagsterBagSortBtn:Hide() end
        if bagsterBagClearBtn then bagsterBagClearBtn:Hide() end
        if bagsterBagSellScrapBtn then bagsterBagSellScrapBtn:Hide() end
        if bagsterBankSortBtn then bagsterBankSortBtn:Hide() end
        if bagsterBankClearBtn then bagsterBankClearBtn:Hide() end
    end

    CreateVanillaGuildBankSortButton()
    CreateBagnonGuildBankSortButton()
    CreateBagsterGuildBankSortButton()
    if bagsterGuildSortBtn then
        if guild_bank_open and IsBagsterEnabled() then
            bagsterGuildSortBtn:Show()
        else
            bagsterGuildSortBtn:Hide()
        end
    end
    if vanillaGuildBankSortBtn then
        -- Only "bank" mode shows item slots (vs. log/money log/info sub-tabs).
        if guild_bank_open and _G.GuildBankFrame and _G.GuildBankFrame.mode == "bank" then
            vanillaGuildBankSortBtn:Show()
        else
            vanillaGuildBankSortBtn:Hide()
        end
    end
    if bagnonGuildBankSortBtn then
        if guild_bank_open then bagnonGuildBankSortBtn:Show() else bagnonGuildBankSortBtn:Hide() end
    end
end

-- Hook into frame show events for lazy/reliable button creation
local hooksInstalled = false
local function InstallShowHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    -- Hook bagster frames if they exist (they show/hide dynamically)
    local cFrame1 = GetBagsterFrame(1)
    local cFrame2 = GetBagsterFrame(2)
    if cFrame1 then
        hooksecurefunc(cFrame1, "Show", function()
            if BagSortModule.applied and not bagsterBagSortBtn then
                UpdateButtonVisibility()
            end
        end)
    end
    if cFrame2 then
        hooksecurefunc(cFrame2, "Show", function()
            if BagSortModule.applied and not bagsterBankSortBtn then
                UpdateButtonVisibility()
            end
        end)
    end

    -- Hook vanilla ContainerFrame open/close for backpack-only sort button
    if not IsBagsterEnabled() then
        for i = 1, NUM_CONTAINER_FRAMES do
            local frame = _G["ContainerFrame" .. i]
            if frame then
                frame:HookScript("OnShow", function()
                    if BagSortModule.applied then UpdateVanillaBagSortButton() end
                end)
                frame:HookScript("OnHide", function()
                    if BagSortModule.applied then UpdateVanillaBagSortButton() end
                end)
            end
        end
    end

    -- Hook BankFrame OnShow
    if BankFrame then
        hooksecurefunc(BankFrame, "Show", function()
            if BagSortModule.applied and not vanillaBankSortBtn and not IsBagsterEnabled() then
                UpdateButtonVisibility()
            end
        end)
    end

    for _, frameType in ipairs({ "inventory", "bank" }) do
        local frame = GetBagnonFrame(frameType)
        if frame and frame.HookScript then
            frame:HookScript("OnShow", function()
                if BagSortModule.applied then
                    UpdateButtonVisibility()
                    if BagSortModule.RequestBagnonSlotScan then
                        BagSortModule.RequestBagnonSlotScan()
                    end
                end
            end)
        end
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

-- Forward declaration
local ApplyBagSortSystem

ApplyBagSortSystem = function()
    if BagSortModule.applied then return end

    -- Register bank events
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "BANKFRAME_OPENED" then
            bank_open = true
            UpdateButtonVisibility()
        elseif event == "BANKFRAME_CLOSED" then
            bank_open = false
        elseif event == "GUILDBANKFRAME_OPENED" then
            guild_bank_open = true
            -- Guild bank UI loads on demand; this function doesn't exist at startup.
            if not guildBankTabHookInstalled and type(GuildBankFrameTab_OnClick) == "function" then
                guildBankTabHookInstalled = true
                hooksecurefunc("GuildBankFrameTab_OnClick", function()
                    if BagSortModule.applied then
                        UpdateButtonVisibility()
                    end
                end)
            end
            UpdateButtonVisibility()
            -- Second pass: the Bagster guild frame may be created lazily by this same event
            addon:After(0.3, function()
                if BagSortModule.applied and guild_bank_open then
                    UpdateButtonVisibility()
                end
            end)
        elseif event == "GUILDBANKFRAME_CLOSED" then
            guild_bank_open = false
        end
    end)
    for _, eventName in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED" }) do
        eventFrame:RegisterEvent(eventName)
        BagSortModule.registeredEvents[eventName] = true
    end

    -- Register slash commands
    SlashCmdList["DRAGONUI_SORT"] = SortPlayerBags
    SLASH_DRAGONUI_SORT1 = "/sort"
    SLASH_DRAGONUI_SORT2 = "/sortbags"

    SlashCmdList["DRAGONUI_SORTBANK"] = SortBankBags
    SLASH_DRAGONUI_SORTBANK1 = "/sortbank"

    SlashCmdList["DRAGONUI_SORTGUILDBANK"] = SortGuildBankTab
    SLASH_DRAGONUI_SORTGUILDBANK1 = "/sortguildbank"

    SlashCmdList["DRAGONUI_SORTLOCK"] = HandleSortLockCommand
    SLASH_DRAGONUI_SORTLOCK1 = "/sortlock"
    SLASH_DRAGONUI_SORTLOCK2 = "/sortignore"

    -- Delay button creation to ensure bagster frames are ready, then install hooks
    InstallAltClickHooks()

    if addon.After then
        addon:After(0.5, function()
            if BagSortModule.applied then
                UpdateButtonVisibility()
                InstallShowHooks()
            end
        end)
    else
        UpdateButtonVisibility()
        InstallShowHooks()
    end

    BagSortModule.applied = true
end

local function RestoreBagSortSystem()
    if not BagSortModule.applied then return end

    -- Stop any running sort
    StopSorting()

    -- Unregister events
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    wipe(BagSortModule.registeredEvents)

    -- Hide and clean up buttons
    if bagsterBagSortBtn then bagsterBagSortBtn:Hide() end
    if bagsterBagClearBtn then bagsterBagClearBtn:Hide() end
    if bagsterBankSortBtn then bagsterBankSortBtn:Hide() end
    if bagsterBankClearBtn then bagsterBankClearBtn:Hide() end
    if bagnonBagSortBtn then bagnonBagSortBtn:Hide() end
    if bagnonBagClearBtn then bagnonBagClearBtn:Hide() end
    if bagnonBankSortBtn then bagnonBankSortBtn:Hide() end
    if bagnonBankClearBtn then bagnonBankClearBtn:Hide() end
    if vanillaBagSortBtn then vanillaBagSortBtn:Hide() end
    if vanillaBagClearBtn then vanillaBagClearBtn:Hide() end
    if vanillaBagSellScrapBtn then vanillaBagSellScrapBtn:Hide() end
    if vanillaBankSortBtn then vanillaBankSortBtn:Hide() end
    if vanillaBankClearBtn then vanillaBankClearBtn:Hide() end
    if vanillaGuildBankSortBtn then vanillaGuildBankSortBtn:Hide() end
    if bagnonGuildBankSortBtn then bagnonGuildBankSortBtn:Hide() end
    if bagsterGuildSortBtn then bagsterGuildSortBtn:Hide() end

    -- Remove slash commands
    SlashCmdList["DRAGONUI_SORT"] = nil
    SlashCmdList["DRAGONUI_SORTBANK"] = nil
    SlashCmdList["DRAGONUI_SORTGUILDBANK"] = nil
    SlashCmdList["DRAGONUI_SORTLOCK"] = nil

    if lockVisualFrame then
        lockVisualFrame:SetScript("OnUpdate", nil)
        lockVisualFrame:Hide()
        lockVisualFrame = nil
    end

    for button, _ in pairs(hookedSlotButtons) do
        if button and button._dragonUISortLockMarker then
            button._dragonUISortLockMarker:Hide()
        end
    end

    -- Undo the Sorting hooks so a disabled module stops intercepting Bagnon's native sort.
    local bagnon = _G.Bagnon
    if bagnon and bagnon.Sorting then
        if bagnonOriginalGetSpaces then
            bagnon.Sorting.GetSpaces = bagnonOriginalGetSpaces
            bagnonOriginalGetSpaces = nil
        end
        if bagnonOriginalMove then
            bagnon.Sorting.Move = bagnonOriginalMove
            bagnonOriginalMove = nil
        end
    end
    bagnonSortingHooked = false
    bagnonMoveHooked = false

    BagSortModule.applied = false
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

-- Profile change callbacks (handled via ADDON_LOADED registration)
local function OnProfileChanged()
    if IsModuleEnabled() then
        if not BagSortModule.applied then
            ApplyBagSortSystem()
        else
            UpdateButtonVisibility()
        end
    else
        if addon:ShouldDeferModuleDisable("bagsort", BagSortModule) then
            return
        end
        RestoreBagSortSystem()
    end
end

-- Initialization via events
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end

        -- Register profile callbacks after DB is ready
        -- Use After to ensure DB is fully initialized
        if addon.After then
            addon:After(0.6, function()
                if addon.db and addon.db.RegisterCallback then
                    -- Use a unique callback object to avoid overwriting other modules
                    local callbackObj = {}
                    addon.db.RegisterCallback(callbackObj, "OnProfileChanged", OnProfileChanged)
                    addon.db.RegisterCallback(callbackObj, "OnProfileCopied", OnProfileChanged)
                    addon.db.RegisterCallback(callbackObj, "OnProfileReset", OnProfileChanged)
                end
            end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        ApplyBagSortSystem()
    end
end)

-- Registry lifecycle resolves these off `addon` via lifecyclePrefix "BagSort".
addon.ApplyBagSortSystem = ApplyBagSortSystem
addon.RestoreBagSortSystem = RestoreBagSortSystem

-- Expose sort functions for other modules/macros
addon.SortPlayerBags = SortPlayerBags
addon.SortBankBags = SortBankBags
addon.SortGuildBankTab = SortGuildBankTab
-- Lets the options panel re-tint visible lock icons live when the color changes.
addon.RefreshBagSortLockMarkers = RefreshAllLockMarkers
addon.BagSortDefaultLockColor = DEFAULT_LOCK_MARKER_COLOR
