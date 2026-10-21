-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Retail-style new-item marks per bag slot: losses leave short-lived credit, uncovered bag gains mark.
local addon = select(2, ...)

local NewItems = {}
addon.NewItems = NewItems

local _G, pairs, next, select, type, wipe, GetTime = _G, pairs, next, select, type, wipe, GetTime
local GetContainerItemID, GetContainerItemInfo = GetContainerItemID, GetContainerItemInfo
local GetInventoryItemID, BankButtonIDToInvSlotID = GetInventoryItemID, BankButtonIDToInvSlotID

local NUM_BAGS, NUM_BANK_BAGS, NUM_BANK_SLOTS = NUM_BAG_SLOTS, NUM_BANKBAGSLOTS, NUM_BANKGENERIC_SLOTS
local KEYRING, BANK, EQUIP, BANK_BAG_SLOTS = KEYRING_CONTAINER, BANK_CONTAINER, "equip", "bankbags"
-- Ammo (slot 0) only mirrors ammo still sitting in the bags, so it is never a source.
local LAST_EQUIP_SLOT = ContainerIDToInventoryID(NUM_BAGS)
local CREDIT_TTL, SETTLE_MIN, SETTLE_QUIET, SETTLE_MAX = 2, 2, 1, 10
local CELL_PITCH, CELL_W, CELL_H = 48 / 512, 39 / 512, 39 / 64
local GLOW_TEXTURE = addon._dir .. "UI\\bagster-newitem-glow"
local FLASH_TEXTURE = addon._dir .. "UI\\bagster-newitem-flash"

local INVENTORY_KEYS = { BACKPACK_CONTAINER, 1, 2, 3, 4, KEYRING }
local BANK_KEYS = { BANK, BANK_BAG_SLOTS }
local isBankKey = { [BANK] = true, [BANK_BAG_SLOTS] = true }
for bag = NUM_BAGS + 1, NUM_BAGS + NUM_BANK_BAGS do
    BANK_KEYS[#BANK_KEYS + 1] = bag
    isBankKey[bag] = true
end

local marks, snapID, snapCount = {}, {}, {}
for _, key in pairs(INVENTORY_KEYS) do marks[key] = {} end
for _, keys in pairs({ INVENTORY_KEYS, BANK_KEYS, { EQUIP } }) do
    for _, key in pairs(keys) do snapID[key], snapCount[key] = {}, {} end
end

local active, entered, settling, loading, worldSettled, settleFull = false, false, false, false, false, false
local checkPending, settleStart, lastActivity, bankOpen, cursorHeld, cursorFreeAt = false, 0, 0, false, false, 0
local marksChanged, snapSize, dirty, silentOnce, scanned, glowing = false, {}, {}, {}, {}, {}
local decAmt, decMarked, bagNeed, credit, creditMarked, creditAt = {}, {}, {}, {}, {}, {}
local transient = { snapSize, dirty, silentOnce, scanned, decAmt, decMarked, bagNeed, credit, creditMarked, creditAt }
local incKey, incSlot, incID, incCount, incQuality, incN = {}, {}, {}, {}, {}, 0

local function Config() return addon.db.profile.bags end

local BAGSTER, CONTAINER = {}, { On = function() return false end }

function BAGSTER.On()
    local b = addon.BagsterModule
    return b and b.BagsterModule.applied and b.IsModuleEnabled()
end

function BAGSTER.Bag(slot) return not slot:IsCached() and slot:GetBag() end
function CONTAINER.Bag(button) return button:GetParent():GetID() end

local function SlotCount(key)
    if key == EQUIP then return LAST_EQUIP_SLOT end
    if key == BANK_BAG_SLOTS then return NUM_BANK_BAGS end
    if key == KEYRING then return GetKeyRingSize() end
    if key == BANK then return NUM_BANK_SLOTS end
    -- Some servers keep reporting a removed bag's old size, so trust the bag slot instead.
    local bagSlot = key > NUM_BAGS and BankButtonIDToInvSlotID(key, 1) or key > 0 and ContainerIDToInventoryID(key)
    if bagSlot and not GetInventoryItemID("player", bagSlot) then return 0 end
    return GetContainerNumSlots(key)
end

-- 3.3.5a reports quality -1 for some items (recipes among them); the link still carries the real one.
local function ContainerQuality(bag, slot)
    local _, count, _, quality, _, _, link = GetContainerItemInfo(bag, slot)
    if link and (not quality or quality < 0) then quality = select(3, GetItemInfo(link)) end
    return quality, count
end

local function Read(key, slot)
    if type(key) == "string" then
        local id = GetInventoryItemID("player", key == EQUIP and slot or BankButtonIDToInvSlotID(NUM_BAGS + slot, 1))
        return id, id and 1
    end
    local id = GetContainerItemID(key, slot)
    if id then
        local quality, count = ContainerQuality(key, slot)
        return id, count or 1, quality
    end
end

local function Record(key, slot, oldID, oldCount, id, count, quality)
    local m = marks[key]
    if oldID and (oldID ~= id or count < oldCount) then
        local lost = oldID == id and oldCount - count or oldCount
        decAmt[oldID] = (decAmt[oldID] or 0) + lost
        if m and m[slot] then
            decMarked[oldID] = (decMarked[oldID] or 0) + lost
            if oldID ~= id then m[slot], marksChanged = nil, true end
        end
    end
    if id and (oldID ~= id or count > oldCount) then
        local n, gained = incN + 1, oldID == id and count - oldCount or count
        incKey[n], incSlot[n], incID[n], incCount[n], incQuality[n], incN = key, slot, id, gained, quality, n
        if m then bagNeed[id] = (bagNeed[id] or 0) + gained end
    end
end

local function Scan(key, silent)
    local ids, counts = snapID[key], snapCount[key]
    local size, last = SlotCount(key), snapSize[key] or 0
    for slot = 1, size > last and size or last do
        local id, count, quality
        if slot <= size then id, count, quality = Read(key, slot) end
        if id ~= ids[slot] or count ~= counts[slot] then
            if not silent then Record(key, slot, ids[slot], counts[slot], id, count, quality) end
            ids[slot], counts[slot] = id, count
        end
    end
    snapSize[key] = size
end

local function ScanAll(silent)
    for key in pairs(snapID) do
        if not scanned[key] and (bankOpen or not isBankKey[key]) then Scan(key, silent) end
    end
end

local function ValidCredit(id, now)
    local amount = credit[id]
    if amount and not cursorHeld then
        local since = creditAt[id]
        if cursorFreeAt > since then since = cursorFreeAt end
        if now - since > CREDIT_TTL then
            credit[id], creditMarked[id], creditAt[id] = nil, nil, nil
            return 0
        end
    end
    return amount or 0
end

local function PurgeCredits(now) for id in pairs(credit) do ValidCredit(id, now) end end

-- Marked units are spent first, so a moved new item keeps its mark wherever it lands.
local function Spend(id, amount, now)
    local have, flagged = ValidCredit(id, now), creditMarked[id] or 0
    local used = have < amount and have or amount
    local carried = flagged < used and flagged or used
    if have > used then
        credit[id], creditMarked[id] = have - used, flagged > carried and flagged - carried or nil
    else
        credit[id], creditMarked[id], creditAt[id] = nil, nil, nil
    end
    return used, carried
end

-- Credit keeps ticking only while the cursor is empty, so a held item can be dropped late.
local function ObserveCursor(now)
    if GetCursorInfo() == "item" then
        if not cursorHeld then PurgeCredits(now) end
        cursorHeld = true
    elseif cursorHeld then
        cursorHeld, cursorFreeAt = false, now
    end
end

local function HideFlash(group) group:GetParent():Hide() end

local function AddAlpha(group, order, change, duration, smoothing)
    local anim = group:CreateAnimation("Alpha")
    anim:SetOrder(order); anim:SetChange(change); anim:SetDuration(duration); anim:SetSmoothing(smoothing)
end

local function AddTexture(glow, layer, file, size)
    local tex = glow:CreateTexture(nil, layer)
    tex:SetTexture(file); tex:SetSize(size, size); tex:SetPoint("CENTER"); tex:SetBlendMode("ADD"); tex:Hide()
    return tex, tex:CreateAnimationGroup()
end

local function CreateGlow(slot)
    local glow = CreateFrame("Frame", nil, slot)
    glow:SetAllPoints(slot)
    glow.ring, glow.pulse = AddTexture(glow, "OVERLAY", GLOW_TEXTURE, 39)
    AddAlpha(glow.pulse, 1, -0.8, 0.5, "NONE")
    AddAlpha(glow.pulse, 2, 0.8, 0.5, "NONE")
    glow.pulse:SetLooping("REPEAT")

    glow.star, glow.spin = AddTexture(glow, "ARTWORK", [[Interface\Cooldown\starburst]], 50)
    local turn = glow.spin:CreateAnimation("Rotation")
    turn:SetDegrees(-360); turn:SetDuration(10); turn:SetOrigin("CENTER", 0, 0); turn:SetSmoothing("NONE")
    glow.spin:SetLooping("REPEAT")

    glow.flash, glow.flashAnim = AddTexture(glow, "OVERLAY", FLASH_TEXTURE, 90)
    glow.flash:SetTexCoord(0, 0.703125, 0, 0.703125)
    AddAlpha(glow.flashAnim, 1, -1, 0.6, "OUT")
    -- A finished group drops its alpha change, so hide or the flash snaps back to full.
    glow.flashAnim:SetScript("OnFinished", HideFlash)
    glow.flashAnim:SetScript("OnStop", HideFlash)
    slot._duiNewGlow = glow
    return glow
end

local function ShowGlow(slot, quality, cfg, display)
    local glow = slot._duiNewGlow or CreateGlow(slot)
    local user = cfg.new_glow_color_mode == "user"
    local cell = not user and quality and quality >= 2 and quality <= 7 and quality - 1 or 0
    local c = user and cfg.new_glow_color
    local r, g, b, a = c and c[1] or 1, c and c[2] or 1, c and c[3] or 1, c and c[4] or 1

    glow:SetFrameLevel(slot:GetFrameLevel() + 2)
    -- Vertex alpha and region alpha share one channel here, so user alpha lives on the frame.
    glow:SetAlpha(a)
    glow:Show()
    if cfg.new_glow_style == "starburst" then
        if cell > 0 then r, g, b = GetItemQualityColor(quality) end
        glow.pulse:Stop(); glow.ring:Hide()
        glow.star:SetVertexColor(r, g, b); glow.star:Show()
        if not glow.spin:IsPlaying() then glow.spin:Play() end
    else
        glow.spin:Stop(); glow.star:Hide()
        glow.ring:SetTexCoord(cell * CELL_PITCH, cell * CELL_PITCH + CELL_W, 0, CELL_H)
        glow.ring:SetVertexColor(r, g, b); glow.ring:Show()
        if not glow.pulse:IsPlaying() then glow.pulse:Play() end
    end
    if not glowing[slot] then glow.flash:Show(); glow.flashAnim:Play() end
    glowing[slot] = display
end

local function HideGlow(slot)
    local glow = slot._duiNewGlow
    glowing[slot] = nil
    glow.pulse:Stop(); glow.spin:Stop(); glow.flashAnim:Stop(); glow:Hide()
end

local function Paint(slot, display, quality)
    local bag, id = display.Bag(slot), slot:GetID()
    local m = active and marks[bag]
    if m and m[id] and display.On() then
        local cfg = Config()
        if not quality or quality < 0 then quality = ContainerQuality(bag, id) end
        if not (cfg.new_ignore_junk and quality == 0) then return ShowGlow(slot, quality, cfg, display) end
    end
    if glowing[slot] then HideGlow(slot) end
end

function NewItems:UpdateSlot(slot, quality) Paint(slot, BAGSTER, quality) end

function NewItems:UpdateContainer(frame)
    local name = frame:GetName()
    for i = 1, frame.size do Paint(_G[name .. "Item" .. i], CONTAINER) end
end

local function RepaintVisible()
    if BAGSTER.On() then
        for _, f in pairs(addon.BagsterModule.frames) do
            if not f.isBank and f:IsVisible() then
                for _, item in pairs(f.itemFrame.items) do
                    if item:IsVisible() then Paint(item, BAGSTER) end
                end
            end
        end
    end
    if CONTAINER.On() then
        for i = 1, NUM_CONTAINER_FRAMES do
            local f = _G["ContainerFrame" .. i]
            if f:IsShown() then NewItems:UpdateContainer(f) end
        end
    end
end

local function ClearAll()
    for _, m in pairs(marks) do wipe(m) end
    wipe(creditMarked)
    for slot in pairs(glowing) do HideGlow(slot) end
end

local function Reset()
    for key, ids in pairs(snapID) do wipe(ids); wipe(snapCount[key]) end
    for _, t in pairs(transient) do wipe(t) end
    incN = 0
end

local frame = CreateFrame("Frame")
frame:Hide()

local function RunBatch()
    frame:Hide()
    if not active or settling or loading then return end
    local now = GetTime()
    ObserveCursor(now)
    for key in pairs(dirty) do
        dirty[key] = nil
        if bankOpen or not isBankKey[key] then
            Scan(key, silentOnce[key])
            scanned[key] = true
        end
        silentOnce[key] = nil
    end

    -- The other half of a move can raise its event a frame later; its data is already current.
    for id, need in pairs(bagNeed) do
        if ValidCredit(id, now) + (decAmt[id] or 0) < need then
            ScanAll(false)
            break
        end
    end
    wipe(scanned)
    wipe(bagNeed)

    -- Decreases land first so a move caught in one batch nets out whatever the event order.
    for id, amount in pairs(decAmt) do
        credit[id], creditAt[id] = ValidCredit(id, now) + amount, now
        if decMarked[id] then creditMarked[id] = (creditMarked[id] or 0) + decMarked[id] end
        decAmt[id], decMarked[id] = nil, nil
    end

    -- Non-bag gains spend first, so whatever stays uncovered lands on the bag slots.
    local ignoreJunk = Config().new_ignore_junk
    for pass = 1, 2 do
        for i = 1, incN do
            local m = marks[incKey[i]]
            if (m ~= nil) == (pass == 2) then
                local used, carried = Spend(incID[i], incCount[i], now)
                if m and (used < incCount[i] or carried > 0) and not (ignoreJunk and incQuality[i] == 0) then
                    marksChanged = marksChanged or not m[incSlot[i]]
                    m[incSlot[i]] = true
                end
            end
        end
    end
    incN = 0
    PurgeCredits(now)

    if marksChanged then
        marksChanged = false
        RepaintVisible()
    end
end

local function MarkDirty(key)
    dirty[key] = true
    if settling or loading then lastActivity = GetTime() else frame:Show() end
end

local function SettleCheck()
    checkPending = false
    if not active or not settling or loading then return end
    local now = GetTime()
    local wait = SETTLE_MIN - (now - settleStart)
    local quiet = SETTLE_QUIET - (now - lastActivity)
    if quiet > wait then wait = quiet end
    if wait > 0 and now - settleStart < SETTLE_MAX then
        checkPending = true
        return addon:After(wait, SettleCheck)
    end
    settling, worldSettled = false, true
    if settleFull then
        settleFull = false
        Reset(); ScanAll(true)
    elseif next(dirty) then
        frame:Show()
    end
end

local function BeginSettle(full)
    settling, settleFull, settleStart, lastActivity = true, settleFull or full, GetTime(), GetTime()
    frame:Hide()
    if not checkPending then
        checkPending = true
        addon:After(SETTLE_MIN, SettleCheck)
    end
end

frame:SetScript("OnUpdate", RunBatch)
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "BAG_UPDATE" then
        if marks[arg1] or (bankOpen and isBankKey[arg1]) then MarkDirty(arg1) end
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == "player" or event == "PLAYER_EQUIPMENT_CHANGED" then MarkDirty(EQUIP) end
    elseif event == "PLAYERBANKSLOTS_CHANGED" and bankOpen then
        if arg1 > NUM_BANK_SLOTS then
            MarkDirty(BANK_BAG_SLOTS); MarkDirty(NUM_BAGS + arg1 - NUM_BANK_SLOTS)
        else
            MarkDirty(BANK)
        end
    elseif event == "CURSOR_UPDATE" or event == "ITEM_LOCK_CHANGED" then
        ObserveCursor(GetTime())
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        for _, key in pairs(BANK_KEYS) do silentOnce[key] = true; MarkDirty(key) end
    elseif event == "BANKFRAME_CLOSED" then
        -- Flush now: a withdrawal's bank half must be read before the bank stops answering.
        if bankOpen and next(dirty) then RunBatch() end
        bankOpen = false
    elseif event == "PLAYER_LEAVING_WORLD" then
        loading = true
        frame:Hide()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Displays apply before the world is up; scanning that early would mark the login bag fill.
        if not entered then
            entered = true
            NewItems:Refresh()
        elseif loading then
            loading = false
            BeginSettle(false)
        end
    end
end)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local EVENTS = { "BAG_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYERBANKSLOTS_CHANGED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "CURSOR_UPDATE", "ITEM_LOCK_CHANGED", "PLAYER_LEAVING_WORLD",
    "PLAYER_ENTERING_WORLD" }

function NewItems:Refresh()
    local wanted = entered and Config().new_items and (BAGSTER.On() or CONTAINER.On())
    if wanted and not active then
        active = true
        for _, event in pairs(EVENTS) do frame:RegisterEvent(event) end
        local atBank = BAGSTER.On() and addon.BagsterModule("InventoryEvents"):AtBank()
        bankOpen = (atBank or BankFrame:IsShown()) and true or false
        cursorHeld = GetCursorInfo() == "item"
        if worldSettled then
            Reset(); ScanAll(true)
        else
            BeginSettle(true)
        end
    elseif not wanted and active then
        active, settling, loading, settleFull = false, false, false, false
        frame:UnregisterAllEvents(); frame:Hide()
        ClearAll(); Reset()
    end
    for slot, display in pairs(glowing) do Paint(slot, display) end
    RepaintVisible()
end

function NewItems:AttachContainers(isActive) CONTAINER.On = isActive end

function NewItems:OnSlotEnter(slot)
    local display = glowing[slot]
    local m = display and marks[display.Bag(slot)]
    if m then m[slot:GetID()] = nil; HideGlow(slot) end
end

function NewItems:OnFrameHide(f)
    if active and not f.isBank and Config().new_clear_on_close then ClearAll() end
end

-- Retail clears per bag: closing one ContainerFrame forgets only that bag's marks.
function NewItems:OnContainerHide(f)
    local m = active and Config().new_clear_on_close and marks[f:GetID()]
    if m and next(m) then wipe(m); self:UpdateContainer(f) end
end

function NewItems:GetState()
    return active, settling, loading, bankOpen, marks, credit
end
