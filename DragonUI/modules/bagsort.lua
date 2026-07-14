local addon = select(2, ...)
local L = addon.L

local function T(key, fallback)
    return (L and L[key]) or fallback or key
end

-- ============================================================================
-- BAG SORT MODULE FOR DRAGONUI
-- Sorts items in bags and bank by type, rarity, level, name.
-- Adds sort buttons to both Combustor frames and vanilla bag/bank frames.
-- Inspired by BankStack sorting algorithm adapted for DragonUI.
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
        T("Sort bags and bank items with buttons", "Sort bags and bank items with buttons"))
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

local function IsCombuctorEnabled()
    return addon:IsModuleEnabled("combuctor")
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

-- ============================================================================
-- SORTING ENGINE
-- ============================================================================

-- Bag group definitions
local PLAYER_BAGS = {}
for i = 0, NUM_BAG_SLOTS do
    tinsert(PLAYER_BAGS, i)
end

local BANK_BAGS = { BANK_CONTAINER }
for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
    tinsert(BANK_BAGS, i)
end

local ALL_BAGS = { BANK_CONTAINER }
for i = 0, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
    tinsert(ALL_BAGS, i)
end

-- Internal caches
local bag_ids = {}
local bag_stacks = {}
local bag_maxstacks = {}
local item_cache = {}  -- keyed by itemID, stores GetItemInfo results
local moves = {}
local running = false
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

-- Encoding helpers
local function encode_bagslot(bag, slot) return (bag * 100) + slot end
local function decode_bagslot(int) return math.floor(int / 100), int % 100 end
local function encode_move(source, target) return (source * 10000) + target end
local function decode_move(move)
    local s = math.floor(move / 10000)
    local t = move % 10000
    s = (t > 9000) and (s + 1) or s
    t = (t > 9000) and (t - 10000) or t
    return s, t
end
local function link_to_id(link)
    return link and tonumber(string.match(link, "item:(%d+)"))
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

    -- Combuctor item buttons expose GetBag/GetID.
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

    -- Combuctor item buttons expose GetBag/GetID.
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

        -- Combuctor item slots
        for idx = 1, 400 do
            local btn = _G["DragonUI_CombuctorItem" .. idx]
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
        HookKnownSlotButtons()
        RefreshAllLockMarkers()
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

-- Bag iteration
local function IterateBags(baglist)
    local items = {}
    for _, bag in ipairs(baglist) do
        local numSlots = IsGuildBankBag(bag) and GetGuildBankTabSlotCount(bag - GUILDBANK_TAB_OFFSET) or GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            tinsert(items, { bag = bag, slot = slot, bagslot = encode_bagslot(bag, slot) })
        end
    end
    local i = 0
    return function()
        i = i + 1
        if items[i] then
            return items[i].bag, items[i].slot, items[i].bagslot
        end
    end
end

-- Scan all items in given bags into cache
local function ScanBags(bags)
    for bag, slot, bagslot in IterateBags(bags) do
        local itemLink = BagGetItemLink(bag, slot)
        local itemid = link_to_id(itemLink)
        if itemid then
            bag_ids[bagslot] = itemid
            local _, count = BagGetItemInfo(bag, slot)
            bag_stacks[bagslot] = count or 0
            -- Cache GetItemInfo by itemID (not bagslot) so it's stable
            if not item_cache[itemid] then
                local name, _, rarity, level, _, itype, subType, maxStack, equipLoc = GetItemInfo(itemid)
                item_cache[itemid] = {
                    name = name or "",
                    rarity = rarity or 0,
                    level = level or 0,
                    itype = itype or "",
                    subType = subType or "",
                    maxStack = maxStack or 1,
                    equipLoc = equipLoc or "",
                }
            end
            bag_maxstacks[bagslot] = item_cache[itemid].maxStack
        end
    end
end

-- Check if a bag is a specialty bag (quiver, soul bag, etc.)
local function IsSpecialtyBag(bagid)
    if bagid == BANK_CONTAINER or bagid == 0 then return false end
    local invslot = ContainerIDToInventoryID(bagid)
    if not invslot then return false end
    local bagLink = GetInventoryItemLink("player", invslot)
    if not bagLink then return false end
    local itemType, itemSubType = select(6, GetItemInfo(bagLink))
    -- Check for localized "Container" / "Bag" types
    if itemType and itemSubType then
        -- Normal bag: Container > Bag
        local containerClass = GetAuctionItemClasses() -- first item is typically "Weapon"
        -- Simple check: if subtype ~= first subclass of Container type, it's specialty
        if itemType == (select(2, GetAuctionItemClasses())) then
            return false -- It's armor, not a container
        end
    end
    return false -- Assume normal for safety
end

-- Build sort order from auction item classes
local item_types, item_subtypes
local function BuildSortOrder()
    item_types = {}
    item_subtypes = {}
    for i, itype in ipairs({ GetAuctionItemClasses() }) do
        item_types[itype] = i
        item_subtypes[itype] = {}
        for ii, istype in ipairs({ GetAuctionItemSubClasses(i) }) do
            item_subtypes[itype][istype] = ii
        end
    end
end

-- Equipment slot sort order
local EQUIP_SLOTS = {
    INVTYPE_AMMO = 0, INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3,
    INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_CLOAK = 13,
    INVTYPE_WEAPON = 14, INVTYPE_SHIELD = 15, INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 18, INVTYPE_WEAPONOFFHAND = 19, INVTYPE_HOLDABLE = 20,
    INVTYPE_RANGED = 21, INVTYPE_THROWN = 22, INVTYPE_RANGEDRIGHT = 23,
    INVTYPE_RELIC = 24, INVTYPE_TABARD = 25,
}

-- Primary sort tiebreaker: level then name (uses cache, never GetItemInfo)
local function PrimeSort(a, b)
    local a_info = item_cache[bag_ids[a]]
    local b_info = item_cache[bag_ids[b]]
    local a_level = a_info and a_info.level or 0
    local b_level = b_info and b_info.level or 0
    if a_level == b_level then
        local a_name = a_info and a_info.name or ""
        local b_name = b_info and b_info.name or ""
        return a_name < b_name
    else
        return a_level > b_level
    end
end

-- Main sorting comparator (uses cache, never GetItemInfo)
local function DefaultSorter(a, b)
    local a_id = bag_ids[a]
    local b_id = bag_ids[b]

    -- Empty slots to back
    if (not a_id) or (not b_id) then return a_id end

    -- Same item: sort by stack count
    if a_id == b_id then
        local a_count = bag_stacks[a]
        local b_count = bag_stacks[b]
        if a_count == b_count then
            return a < b
        else
            return a_count < b_count
        end
    end

    local a_info = item_cache[a_id]
    local b_info = item_cache[b_id]
    local a_rarity = a_info and a_info.rarity or 0
    local b_rarity = b_info and b_info.rarity or 0
    local a_type = a_info and a_info.itype or ""
    local b_type = b_info and b_info.itype or ""
    local a_subType = a_info and a_info.subType or ""
    local b_subType = b_info and b_info.subType or ""
    local a_equipLoc = a_info and a_info.equipLoc or ""
    local b_equipLoc = b_info and b_info.equipLoc or ""

    -- Junk (gray) to back
    if not (a_rarity == b_rarity) then
        if a_rarity == 0 then return false end
        if b_rarity == 0 then return true end
    end

    -- Soul shards to back
    if a_id == 6265 then return false end
    if b_id == 6265 then return true end

    -- Sort by item type
    if (item_types[a_type] or 99) == (item_types[b_type] or 99) then
        if a_rarity == b_rarity then
            local weaponType = select(1, GetAuctionItemClasses())
            local armorType = select(2, GetAuctionItemClasses())
            if a_type == armorType or a_type == weaponType then
                local a_slot = EQUIP_SLOTS[a_equipLoc] or -1
                local b_slot = EQUIP_SLOTS[b_equipLoc] or -1
                if a_slot == b_slot then
                    return PrimeSort(a, b)
                else
                    return a_slot < b_slot
                end
            else
                if a_subType == b_subType then
                    return PrimeSort(a, b)
                else
                    return ((item_subtypes[a_type] or {})[a_subType] or 99) < ((item_subtypes[b_type] or {})[b_subType] or 99)
                end
            end
        else
            return a_rarity > b_rarity
        end
    else
        return (item_types[a_type] or 99) < (item_types[b_type] or 99)
    end
end

-- Update location cache after scheduling a move
local function UpdateLocation(from, to)
    if (bag_ids[from] == bag_ids[to]) and (bag_stacks[to] < bag_maxstacks[to]) then
        local stack_size = bag_maxstacks[to]
        if (bag_stacks[to] + bag_stacks[from]) > stack_size then
            bag_stacks[from] = bag_stacks[from] - (stack_size - bag_stacks[to])
            bag_stacks[to] = stack_size
        else
            bag_stacks[to] = bag_stacks[to] + bag_stacks[from]
            bag_stacks[from] = nil
            bag_ids[from] = nil
            bag_maxstacks[from] = nil
        end
    else
        bag_ids[from], bag_ids[to] = bag_ids[to], bag_ids[from]
        bag_stacks[from], bag_stacks[to] = bag_stacks[to], bag_stacks[from]
        bag_maxstacks[from], bag_maxstacks[to] = bag_maxstacks[to], bag_maxstacks[from]
    end
end

local function AddMove(source, destination)
    UpdateLocation(source, destination)
    tinsert(moves, 1, encode_move(source, destination))
end

-- Fill partial stacks in target_bags using items from source_bags
-- (BankStack's core.Stack from stack.lua, ported -- this is what powers BankStack's
-- /stack command, e.g. topping off bank stacks using items from your bags).
-- Unlike CompressStacks, the source slot doesn't need to itself be partial:
-- a full stack in source_bags can still top off a partial stack in target_bags.
local function StackBagsAcross(source_bags, target_bags)
    local target_items = {}
    local target_slots = {}
    local source_used = {}

    -- Model target_bags: any partial stack is a place items can land.
    for bag, slot, bagslot in IterateBags(target_bags) do
        if not IsSlotLocked(bag, slot) then
            local itemid = bag_ids[bagslot]
            if itemid and bag_stacks[bagslot] and bag_maxstacks[bagslot] and (bag_stacks[bagslot] ~= bag_maxstacks[bagslot]) then
                target_items[itemid] = (target_items[itemid] or 0) + 1
                tinsert(target_slots, bagslot)
            end
        end
    end

    -- Go through source_bags in reverse (matching BankStack), looking for matches.
    local source_slots = {}
    for bag, slot, bagslot in IterateBags(source_bags) do
        if not IsSlotLocked(bag, slot) then
            tinsert(source_slots, bagslot)
        end
    end
    for si = #source_slots, 1, -1 do
        local source_slot = source_slots[si]
        local itemid = bag_ids[source_slot]
        if itemid and target_items[itemid] then
            for ti = #target_slots, 1, -1 do
                local target_slot = target_slots[ti]
                if bag_ids[source_slot]
                    and bag_ids[target_slot] == itemid
                    and target_slot ~= source_slot
                    and not (bag_stacks[target_slot] == bag_maxstacks[target_slot])
                    and not source_used[target_slot]
                then
                    AddMove(source_slot, target_slot)
                    source_used[source_slot] = true
                    if bag_stacks[target_slot] == bag_maxstacks[target_slot] then
                        target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
                    end
                    if bag_stacks[source_slot] == 0 then
                        target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
                        break
                    end
                    if not target_items[itemid] then break end
                end
            end
        end
    end
end

-- Compress partial stacks (BankStack's Stack with is_partial filter)
local function CompressStacks(bags)
    local target_items = {}
    local target_slots = {}
    local source_used = {}

    -- Model the target bags: find partial stacks
    for bag, slot, bagslot in IterateBags(bags) do
        if not IsSlotLocked(bag, slot) then
        local itemid = bag_ids[bagslot]
        if itemid and bag_stacks[bagslot] and bag_maxstacks[bagslot] and (bag_stacks[bagslot] ~= bag_maxstacks[bagslot]) then
            -- is_partial filter: (maxstack - count) > 0
            if (bag_maxstacks[bagslot] - bag_stacks[bagslot]) > 0 then
                target_items[itemid] = (target_items[itemid] or 0) + 1
                tinsert(target_slots, bagslot)
            end
        end
        end
    end

    -- Go through source bags in reverse (matching BankStack)
    local all_slots = {}
    for bag, slot, bagslot in IterateBags(bags) do
        if not IsSlotLocked(bag, slot) then
            tinsert(all_slots, { bag = bag, slot = slot, bagslot = bagslot })
        end
    end
    for si = #all_slots, 1, -1 do
        local source_slot = all_slots[si].bagslot
        local itemid = bag_ids[source_slot]
        if itemid and target_items[itemid] and (bag_maxstacks[source_slot] - bag_stacks[source_slot]) > 0 then
            for ti = #target_slots, 1, -1 do
                local target_slot = target_slots[ti]
                if bag_ids[source_slot]
                    and bag_ids[target_slot] == itemid
                    and target_slot ~= source_slot
                    and not (bag_stacks[target_slot] == bag_maxstacks[target_slot])
                    and not source_used[target_slot]
                then
                    AddMove(source_slot, target_slot)
                    source_used[source_slot] = true
                    if bag_stacks[target_slot] == bag_maxstacks[target_slot] then
                        target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
                    end
                    if bag_stacks[source_slot] == 0 then
                        target_items[itemid] = (target_items[itemid] > 1) and (target_items[itemid] - 1) or nil
                        break
                    end
                    if not target_items[itemid] then break end
                end
            end
        end
    end
end

-- Check if a move actually needs to happen (exact BankStack logic)
local function ShouldActuallyMove(source, destination)
    if destination == source then return end
    if not bag_ids[source] then return end
    local sBag, sSlot = decode_bagslot(source)
    local dBag, dSlot = decode_bagslot(destination)
    if IsSlotLocked(sBag, sSlot) or IsSlotLocked(dBag, dSlot) then return end
    if bag_ids[source] == bag_ids[destination] and bag_stacks[source] == bag_stacks[destination] then return end
    return true
end

-- Update sorted array after scheduling a move (exact BankStack logic)
local function UpdateSorted(sorted, source, destination)
    for i, bs in pairs(sorted) do
        if bs == source then
            sorted[i] = destination
        elseif bs == destination then
            sorted[i] = source
        end
    end
end

-- Sort items in the given bags (exact BankStack core.Sort logic)
local function SortItems(bags)
    if not item_types then BuildSortOrder() end

    -- Sort only unlocked slots; locked slots remain in-place and are never moved.
    local sources = {}
    local destinations = {}
    for bag, slot, bagslot in IterateBags(bags) do
        if not IsSlotLocked(bag, slot) then
            tinsert(sources, bagslot)
            tinsert(destinations, bagslot)
        end
    end

    table.sort(sources, DefaultSorter)

    local bag_locked = {}
    local another_pass = true
    while another_pass do
        another_pass = false
        for i = 1, #destinations do
            local destination = destinations[i]
            local source = sources[i]
            if ShouldActuallyMove(source, destination) then
                if not (bag_locked[source] or bag_locked[destination]) then
                    AddMove(source, destination)
                    UpdateSorted(sources, source, destination)
                    bag_locked[source] = true
                    bag_locked[destination] = true
                else
                    another_pass = true
                end
            end
        end
        wipe(bag_locked)
    end
end

-- Move execution frame
local moveFrame = CreateFrame("Frame")
local moveTimer = 0
local current_id, current_target

moveFrame:SetScript("OnUpdate", function(self, elapsed)
    moveTimer = moveTimer + elapsed
    if moveTimer < GetSortMoveInterval() then return end
    moveTimer = 0

    -- Safety: check for unexpected cursor items
    if CursorHasItem() then
        local itemid = link_to_id(select(3, GetCursorInfo()))
        if current_id ~= itemid then
            StopSorting("DragonUI: Sort interrupted.")
            return
        end
    end

    -- Wait for previous move to complete
    if current_target and (link_to_id(BagGetItemLink(decode_bagslot(current_target))) ~= current_id) then
        return
    end

    current_id = nil
    current_target = nil

    if #moves > 0 then
        for i = #moves, 1, -1 do
            if CursorHasItem() then return end
            local source, target = decode_move(moves[i])
            local source_bag, source_slot = decode_bagslot(source)
            local target_bag, target_slot = decode_bagslot(target)
            local _, source_count, source_locked = BagGetItemInfo(source_bag, source_slot)
            local _, target_count, target_locked = BagGetItemInfo(target_bag, target_slot)

            if source_locked or target_locked then return end

            tremove(moves, i)
            local source_link = BagGetItemLink(source_bag, source_slot)
            local source_itemid = link_to_id(source_link)
            if not source_itemid then
                StopSorting("DragonUI: Sort confused, stopping.")
                return
            end

            local stack_size = select(8, GetItemInfo(source_itemid)) or 1
            current_target = target
            current_id = source_itemid

            local target_link = BagGetItemLink(target_bag, target_slot)
            local target_itemid = link_to_id(target_link)

            if (source_itemid == target_itemid) and target_count and (target_count ~= stack_size) and ((target_count + (source_count or 0)) > stack_size) then
                BagSplitItem(source_bag, source_slot, stack_size - target_count)
            else
                BagPickupItem(source_bag, source_slot)
            end
            local isGuildBankMove = IsGuildBankBag(source_bag)
            if CursorHasItem() or isGuildBankMove then
                BagPickupItem(target_bag, target_slot)
            end
            -- One guild-bank move per tick: state doesn't update predictively like bags.
            if isGuildBankMove then return end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Sort complete.", "Sort complete."), 0.4, 1, 0.4)
    StopSorting()
end)
moveFrame:Hide()

StopSorting = function(message)
    running = false
    guildBankSortActive = false
    current_id = nil
    current_target = nil
    wipe(moves)
    moveFrame:Hide()
    if message then
        DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0.4, 0.4)
    end
end

local function StartSorting()
    wipe(bag_maxstacks)
    wipe(bag_stacks)
    wipe(bag_ids)
    wipe(item_cache)

    if #moves > 0 then
        running = true
        moveFrame:Show()
    end
end

-- ============================================================================
-- PUBLIC SORT FUNCTIONS
-- ============================================================================

local function SortPlayerBags()
    if running then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Sort already in progress.", "Sort already in progress."), 1, 0.8, 0)
        return
    end

    ScanBags(ALL_BAGS)
    CompressStacks(PLAYER_BAGS)
    SortItems(PLAYER_BAGS)
    StartSorting()

    if #moves == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Bags already sorted!", "Bags already sorted!"), 0.4, 1, 0.4)
    end
end

local function SortBankBags()
    if running then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Sort already in progress.", "Sort already in progress."), 1, 0.8, 0)
        return
    end
    if not bank_open then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("You must be at the bank.", "You must be at the bank."), 1, 0.4, 0.4)
        return
    end

    ScanBags(ALL_BAGS)

    -- Debug: print what ScanBags found for bank items
    if addon.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66" .. T("=== BANK SCAN DEBUG ===", "=== BANK SCAN DEBUG ===") .. "|r")
        for bag, slot, bagslot in IterateBags(BANK_BAGS) do
            local id = bag_ids[bagslot]
            if id then
                local info = item_cache[id]
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] bag%d/s%d: %s (id=%d r=%d lv=%d t=%s st=%s eq=%s x%d)",
                    bagslot, bag, slot,
                    info and info.name or "NIL_NAME",
                    id,
                    info and info.rarity or -1,
                    info and info.level or -1,
                    info and info.itype or "NIL",
                    info and info.subType or "NIL",
                    info and info.equipLoc or "NIL",
                    bag_stacks[bagslot] or 0))
            end
        end
    end

    -- Top off partial bank stacks using matching items from your bags first
    -- (this is the BankStack /stack behavior -- items from both inventories
    -- get consolidated into the bank before the bank itself gets sorted).
    StackBagsAcross(PLAYER_BAGS, BANK_BAGS)
    CompressStacks(BANK_BAGS)
    SortItems(BANK_BAGS)

    -- Debug: print sorted order and moves
    if addon.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00cc66=== %d MOVES ===|r", #moves))
        for i = #moves, 1, -1 do
            local s, t = decode_move(moves[i])
            local sid = bag_ids[s] or 0
            local tid = bag_ids[t] or 0
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  move: [%d]->  [%d]", s, t))
        end
    end

    StartSorting()

    if #moves == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Bank already sorted!", "Bank already sorted!"), 0.4, 1, 0.4)
    end
end

-- ============================================================================
-- GUILD BANK SORTING (single tab only, never crosses tabs)
-- ============================================================================
-- Crossing tabs would spend withdrawal allowance on both ends just to reorder.

local function PerformGuildBankSort()
    if running then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Sort already in progress.", "Sort already in progress."), 1, 0.8, 0)
        return
    end
    if not guild_bank_open then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("You must be at the guild bank.", "You must be at the guild bank."), 1, 0.4, 0.4)
        return
    end
    if type(GetCurrentGuildBankTab) ~= "function" then
        return
    end

    local tab = GetCurrentGuildBankTab()
    if not tab or tab < 1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("Could not determine the current guild bank tab.", "Could not determine the current guild bank tab."), 1, 0.4, 0.4)
        return
    end

    if GetGuildBankTabSlotCount(tab) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("You need full deposit and withdraw access to this tab to sort it.", "You need full deposit and withdraw access to this tab to sort it."), 1, 0.4, 0.4)
        return
    end

    local tabBags = { GUILDBANK_TAB_OFFSET + tab }
    ScanBags(tabBags)
    CompressStacks(tabBags)
    SortItems(tabBags)

    if #moves == 0 then
        StartSorting() -- still wipes the scratch scan caches
        DEFAULT_CHAT_FRAME:AddMessage("|cff00cc66DragonUI:|r " .. T("This guild bank tab is already sorted!", "This guild bank tab is already sorted!"), 0.4, 1, 0.4)
        return
    end

    guildBankSortActive = true
    StartSorting()
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
-- COMBUSTOR BUTTON INTEGRATION
-- ============================================================================

local combustorBagSortBtn, combustorBankSortBtn
local combustorBagClearBtn, combustorBankClearBtn
local bagnonBagSortBtn, bagnonBankSortBtn
local bagnonBagClearBtn, bagnonBankClearBtn
local vanillaGuildBankSortBtn, bagnonGuildBankSortBtn

local function GetCombuctorFrame(index)
    return _G["DragonUI_CombuctorFrame" .. index]
end

local function AttachCombuctorButtons(frame, sortRef, clearRef, sortFunc, sortBtnName, clearBtnName, tooltipText)
    if sortRef and clearRef then return sortRef, clearRef end

    local frameName = frame:GetName()
    local searchBox = _G[frameName .. "Search"]
    local resetBtn = _G[frameName .. "Reset"]
    local bagToggle = _G[frameName .. "BagToggle"]

    -- Shrink the search bar to make room for the sort button
    if searchBox then
        searchBox:ClearAllPoints()
        searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 84, -44)
        -- Reserve extra room for sort + clear-locks buttons.
        searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -176, -44)
    end

    local sortBtn = sortRef or CreateSortButton(sortBtnName, frame, sortFunc, tooltipText, 0.70)
    local clearBtn = clearRef or CreateClearLocksButton(clearBtnName, frame, 0.70)

    -- Insert between Reset and BagToggle in the anchor chain
    if resetBtn then
        sortBtn:SetPoint("LEFT", resetBtn, "RIGHT", -6, 2)
        clearBtn:SetPoint("RIGHT", sortBtn, "LEFT", -2, 0)
    else
        sortBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -42)
        clearBtn:SetPoint("RIGHT", sortBtn, "LEFT", -2, 0)
    end

    -- Re-anchor BagToggle to the right of our sort button
    if bagToggle then
        bagToggle:ClearAllPoints()
        bagToggle:SetPoint("LEFT", sortBtn, "RIGHT", 0, 0)
    end

    sortBtn:Show()
    clearBtn:Show()
    return sortBtn, clearBtn
end

local function CreateCombuctorSortButtons()
    local inventoryFrame = GetCombuctorFrame(1)
    local bankFrame = GetCombuctorFrame(2)

    if inventoryFrame and (not combustorBagSortBtn or not combustorBagClearBtn) then
        combustorBagSortBtn, combustorBagClearBtn = AttachCombuctorButtons(
            inventoryFrame, combustorBagSortBtn, combustorBagClearBtn,
            SortPlayerBags, "DragonUI_CombuctorBagSortBtn", "DragonUI_CombuctorBagClearBtn", T("Sort Bags", "Sort Bags")
        )
        BagSortModule.frames.combustorBagSortBtn = combustorBagSortBtn
        BagSortModule.frames.combustorBagClearBtn = combustorBagClearBtn
    end

    if bankFrame and (not combustorBankSortBtn or not combustorBankClearBtn) then
        combustorBankSortBtn, combustorBankClearBtn = AttachCombuctorButtons(
            bankFrame, combustorBankSortBtn, combustorBankClearBtn,
            SortBankBags, "DragonUI_CombuctorBankSortBtn", "DragonUI_CombuctorBankClearBtn", T("Sort Bank", "Sort Bank")
        )
        BagSortModule.frames.combustorBankSortBtn = combustorBankSortBtn
        BagSortModule.frames.combustorBankClearBtn = combustorBankClearBtn
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
    vanillaBagSortBtn:Hide()
    vanillaBagClearBtn:Hide()
    BagSortModule.frames.vanillaBagSortBtn = vanillaBagSortBtn
    BagSortModule.frames.vanillaBagClearBtn = vanillaBagClearBtn
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
        vanillaBagSortBtn:ClearAllPoints()
        vanillaBagClearBtn:ClearAllPoints()
        local titleAnchor = _G[backpack:GetName() .. "Name"]
        local skinChrome = backpack._dragonuiBagChrome
        if addon:IsModuleEnabled("bags_skin")
            and skinChrome and skinChrome.title and skinChrome.title:IsShown()
        then
            titleAnchor = skinChrome.title
        end
        vanillaBagSortBtn:SetPoint("TOP", titleAnchor, "BOTTOM", 70.5, -6.5)
        vanillaBagClearBtn:SetPoint("RIGHT", vanillaBagSortBtn, "LEFT", -3, 0)
        vanillaBagSortBtn:SetFrameLevel(backpack:GetFrameLevel() + 10)
        vanillaBagClearBtn:SetFrameLevel(backpack:GetFrameLevel() + 10)
        vanillaBagSortBtn:Show()
        vanillaBagClearBtn:Show()
    else
        vanillaBagSortBtn:Hide()
        vanillaBagClearBtn:Hide()
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
    local combuctorActive = IsCombuctorEnabled()
    local combuctorApplied = GetCombuctorFrame(1) ~= nil

    if combuctorActive and combuctorApplied then
        CreateCombuctorSortButtons()
        if combustorBagSortBtn then combustorBagSortBtn:Show() end
        if combustorBagClearBtn then combustorBagClearBtn:Show() end
        if combustorBankSortBtn then combustorBankSortBtn:Show() end
        if combustorBankClearBtn then combustorBankClearBtn:Show() end
        if bagnonBagSortBtn then bagnonBagSortBtn:Hide() end
        if bagnonBagClearBtn then bagnonBagClearBtn:Hide() end
        if bagnonBankSortBtn then bagnonBankSortBtn:Hide() end
        if bagnonBankClearBtn then bagnonBankClearBtn:Hide() end
        if vanillaBagSortBtn then vanillaBagSortBtn:Hide() end
        if vanillaBagClearBtn then vanillaBagClearBtn:Hide() end
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
        if vanillaBankSortBtn then vanillaBankSortBtn:Hide() end
        if vanillaBankClearBtn then vanillaBankClearBtn:Hide() end
        if combustorBagSortBtn then combustorBagSortBtn:Hide() end
        if combustorBagClearBtn then combustorBagClearBtn:Hide() end
        if combustorBankSortBtn then combustorBankSortBtn:Hide() end
        if combustorBankClearBtn then combustorBankClearBtn:Hide() end
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
        if combustorBagSortBtn then combustorBagSortBtn:Hide() end
        if combustorBagClearBtn then combustorBagClearBtn:Hide() end
        if combustorBankSortBtn then combustorBankSortBtn:Hide() end
        if combustorBankClearBtn then combustorBankClearBtn:Hide() end
    end

    CreateVanillaGuildBankSortButton()
    CreateBagnonGuildBankSortButton()
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

    -- Hook combustor frames if they exist (they show/hide dynamically)
    local cFrame1 = GetCombuctorFrame(1)
    local cFrame2 = GetCombuctorFrame(2)
    if cFrame1 then
        hooksecurefunc(cFrame1, "Show", function()
            if BagSortModule.applied and not combustorBagSortBtn then
                UpdateButtonVisibility()
            end
        end)
    end
    if cFrame2 then
        hooksecurefunc(cFrame2, "Show", function()
            if BagSortModule.applied and not combustorBankSortBtn then
                UpdateButtonVisibility()
            end
        end)
    end

    -- Hook vanilla ContainerFrame open/close for backpack-only sort button
    if not IsCombuctorEnabled() then
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
            if BagSortModule.applied and not vanillaBankSortBtn and not IsCombuctorEnabled() then
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
        elseif event == "GUILDBANKFRAME_CLOSED" then
            guild_bank_open = false
        end
    end)
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")
    BagSortModule.registeredEvents["BANKFRAME_OPENED"] = true
    BagSortModule.registeredEvents["BANKFRAME_CLOSED"] = true
    BagSortModule.registeredEvents["GUILDBANKFRAME_OPENED"] = true
    BagSortModule.registeredEvents["GUILDBANKFRAME_CLOSED"] = true

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

    -- Delay button creation to ensure combustor frames are ready, then install hooks
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
    if combustorBagSortBtn then combustorBagSortBtn:Hide() end
    if combustorBagClearBtn then combustorBagClearBtn:Hide() end
    if combustorBankSortBtn then combustorBankSortBtn:Hide() end
    if combustorBankClearBtn then combustorBankClearBtn:Hide() end
    if bagnonBagSortBtn then bagnonBagSortBtn:Hide() end
    if bagnonBagClearBtn then bagnonBagClearBtn:Hide() end
    if bagnonBankSortBtn then bagnonBankSortBtn:Hide() end
    if bagnonBankClearBtn then bagnonBankClearBtn:Hide() end
    if vanillaBagSortBtn then vanillaBagSortBtn:Hide() end
    if vanillaBagClearBtn then vanillaBagClearBtn:Hide() end
    if vanillaBankSortBtn then vanillaBankSortBtn:Hide() end
    if vanillaBankClearBtn then vanillaBankClearBtn:Hide() end
    if vanillaGuildBankSortBtn then vanillaGuildBankSortBtn:Hide() end
    if bagnonGuildBankSortBtn then bagnonGuildBankSortBtn:Hide() end

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

-- Expose sort functions for other modules/macros
addon.SortPlayerBags = SortPlayerBags
addon.SortBankBags = SortBankBags
addon.SortGuildBankTab = SortGuildBankTab
-- Lets the options panel re-tint visible lock icons live when the color changes.
addon.RefreshBagSortLockMarkers = RefreshAllLockMarkers
addon.BagSortDefaultLockColor = DEFAULT_LOCK_MARKER_COLOR
