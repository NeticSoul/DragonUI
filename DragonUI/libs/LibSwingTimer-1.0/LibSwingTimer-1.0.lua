--[[
LibSwingTimer-1.0
Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.txt in this folder.

Player swing timers for World of Warcraft 3.3.5a: main hand, off hand and ranged (Auto Shot, wands, Shoot, Throw).
The 3.3.5a combat log does not say which hand swung, so dual-wield swings are assigned by timing.

Callbacks (CallbackHandler-1.0):
  SWING_START   (hand, startTime, duration)
  SWING_UPDATE  (hand, startTime, duration, pausedAt)  haste change, parry haste, Slam pause/resume
  SWING_STOP    (hand)
  SWING_RANGE   (hand, inRange)                        inRange: true, false, or nil when unknown
  SWING_WEAPONS (hasOffHand, hasRanged)
Queries: lib:GetSwing(hand), lib:GetSpeed(hand), lib:HasWeapon(hand), lib:IsInRange(hand),
         lib:IsAutoAttacking(), lib:IsAutoRepeating().  hand = "mainhand" | "offhand" | "ranged".
The library stays dormant (no events) until something registers a callback.
]]

local MAJOR, MINOR = "LibSwingTimer-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local CallbackHandler = LibStub("CallbackHandler-1.0")
lib.callbacks = lib.callbacks or CallbackHandler:New(lib)
lib.frame = lib.frame or CreateFrame("Frame")

local callbacks, frame = lib.callbacks, lib.frame
local GetTime, UnitGUID, UnitAttackSpeed, UnitRangedDamage = GetTime, UnitGUID, UnitAttackSpeed, UnitRangedDamage
local UnitExists, GetSpellInfo, GetInventoryItemLink = UnitExists, GetSpellInfo, GetInventoryItemLink
local GetItemInfo, UnitClass, UnitCastingInfo = GetItemInfo, UnitClass, UnitCastingInfo
local IsActionInRange, IsAttackAction, IsSpellInRange = IsActionInRange, IsAttackAction, IsSpellInRange
local pairs, select = pairs, select

local MAIN, OFF, RANGED = "mainhand", "offhand", "ranged"
local OPENER_OFFHAND_DELAY = 0.5   -- the off hand waits half its speed when auto attack starts
local EXTRA_ATTACK_WINDOW = 1      -- seconds an announced extra attack may take to show up in the log
local DUE_TOLERANCE = 0.2          -- a swing this close to a hand's schedule is that hand's real swing
local RANGE_INTERVAL = 0.2

local function SpellName(id)
    return (GetSpellInfo(id))
end

-- Abilities that replace the next main-hand swing (all ranks share the name).
local NEXT_MELEE = {}
for _, id in pairs({ 78, 845, 6807, 2973, 56815 }) do -- Heroic Strike, Cleave, Maul, Raptor Strike, Rune Strike
    local name = SpellName(id)
    if name then NEXT_MELEE[name] = true end
end

-- Ranged swings: Auto Shot, wand Shoot, Shoot Bow, Shoot Gun, Shoot Crossbow, Throw.
local RANGED_SPELLS, RANGED_ORDER = {}, {}
for _, id in pairs({ 75, 5019, 2480, 7918, 7919, 2764 }) do
    local name = SpellName(id)
    if name then
        RANGED_SPELLS[name] = true
        RANGED_ORDER[#RANGED_ORDER + 1] = name
    end
end

local AUTO_SHOT = SpellName(75)
local SLAM = SpellName(1464)
local ATTACK = SpellName(6603)

local RANGED_SLOT = 18
local RANGED_EQUIP = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local RELIC_CLASSES = { DRUID = true, PALADIN = true, SHAMAN = true, DEATHKNIGHT = true }

local swings = { [MAIN] = {}, [OFF] = {}, [RANGED] = {} }
local speeds = {}
local inRange = {}
local expected = {}
local weaponLinks = {}
local announced = {}
local playerGUID
local autoAttacking, autoRepeating = false, false
local extraAttacks, extraAttackAt = 0, 0
local castingName, castingID, lastRangedName
local attackSlot
local active = false

local function Fire(event, ...)
    callbacks:Fire(event, ...)
end

-- Relics share the ranged slot and UnitRangedDamage still reports a speed for them, so the item decides.
local function HasRangedWeapon()
    local link = GetInventoryItemLink("player", RANGED_SLOT)
    if not link then return false end
    local equipLoc = select(9, GetItemInfo(link))
    if equipLoc then return RANGED_EQUIP[equipLoc] == true end
    return not RELIC_CLASSES[select(2, UnitClass("player"))]
end

local function RefreshSpeeds()
    local main, off = UnitAttackSpeed("player")
    speeds[MAIN] = main
    speeds[OFF] = (off and off > 0) and off or nil
    local ranged = UnitRangedDamage("player")
    speeds[RANGED] = (ranged and ranged > 0 and HasRangedWeapon()) and ranged or nil
end

-- Compares with what listeners were last told: speed and item events reach us in either order.
local function AnnounceWeapons()
    local hasOff, hasRanged = speeds[OFF] ~= nil, speeds[RANGED] ~= nil
    if hasOff ~= announced[OFF] or hasRanged ~= announced[RANGED] then
        announced[OFF], announced[RANGED] = hasOff, hasRanged
        Fire("SWING_WEAPONS", hasOff, hasRanged)
    end
end

local function Remaining(swing, now)
    if not swing.start then return nil end
    local paused = swing.pausedAt and (now - swing.pausedAt) or 0
    return swing.start + swing.duration + paused - now
end

local function StartSwing(hand, duration)
    duration = duration or speeds[hand]
    if not duration or duration <= 0 then return end
    local swing = swings[hand]
    swing.start, swing.duration, swing.pausedAt = GetTime(), duration, nil
    expected[hand] = nil
    Fire("SWING_START", hand, swing.start, swing.duration)
end

local function StopSwing(hand)
    local swing = swings[hand]
    if swing.start then
        swing.start, swing.duration, swing.pausedAt = nil, nil, nil
        Fire("SWING_STOP", hand)
    end
end

local function UpdateSwing(hand)
    local swing = swings[hand]
    Fire("SWING_UPDATE", hand, swing.start, swing.duration, swing.pausedAt)
end

-- Seconds until the hand may swing; an overdue hand (held out of range, late opener) is simply ready.
local function DueIn(hand, now)
    local remaining = Remaining(swings[hand], now) or ((expected[hand] or now) - now)
    return remaining > 0 and remaining or 0
end

-- The hand that is ready soonest takes this swing; when both are ready the main hand goes first.
local function PickHand()
    if not speeds[OFF] then return MAIN end
    local now = GetTime()
    return DueIn(MAIN, now) <= DueIn(OFF, now) and MAIN or OFF
end

-- A melee swing restarts Auto Shot and Auto Shot restarts melee (blue post: matches 3.3.5).
local function RestartIfRunning(hand)
    local swing = swings[hand]
    if swing.start and (Remaining(swing, GetTime()) or 0) > 0 then
        StartSwing(hand)
    end
end

-- An announced extra attack lands while no hand is due; a swing that fits a hand's schedule stays a real one.
local function IsExtraAttack(now)
    if extraAttacks <= 0 then return false end
    if now - extraAttackAt > EXTRA_ATTACK_WINDOW then
        extraAttacks = 0
        return false
    end
    if DueIn(MAIN, now) <= DUE_TOLERANCE or (speeds[OFF] and DueIn(OFF, now) <= DUE_TOLERANCE) then
        return false
    end
    extraAttacks = extraAttacks - 1
    return true
end

local function OnMeleeSwing()
    if IsExtraAttack(GetTime()) then return end
    StartSwing(PickHand())
    RestartIfRunning(RANGED)
end

-- Parry haste on the main hand: >60% left loses 40% of the swing, 20-60% drops to 20%, under 20% is untouched.
local function OnParry()
    local swing = swings[MAIN]
    local now = GetTime()
    local remaining = Remaining(swing, now)
    if not remaining or remaining <= 0 then return end
    local share = remaining / swing.duration
    if share > 0.6 then
        swing.start = swing.start - 0.4 * swing.duration
    elseif share > 0.2 then
        swing.start = swing.start - (remaining - 0.2 * swing.duration)
    else
        return
    end
    UpdateSwing(MAIN)
end

-- A haste change keeps the share of the swing already done and rescales what is left.
local function Rescale(hand, newSpeed)
    local swing = swings[hand]
    if not (swing.start and newSpeed and swing.duration) or newSpeed == swing.duration then return end
    local now = GetTime()
    local done = ((swing.pausedAt or now) - swing.start) / swing.duration
    if done >= 1 then return end
    swing.start = (swing.pausedAt or now) - done * newSpeed
    swing.duration = newSpeed
    UpdateSwing(hand)
end

-- Slam pauses the melee swing during its cast since 3.0.2.
local function PauseMelee(paused)
    local now = GetTime()
    for _, hand in pairs({ MAIN, OFF }) do
        local swing = swings[hand]
        if swing.start then
            if paused and not swing.pausedAt then
                swing.pausedAt = now
                UpdateSwing(hand)
            elseif not paused and swing.pausedAt then
                swing.start = swing.start + (now - swing.pausedAt)
                swing.pausedAt = nil
                UpdateSwing(hand)
            end
        end
    end
end

local function RefreshWeapons(restart)
    RefreshSpeeds()
    for slot, hand in pairs({ [16] = MAIN, [17] = OFF, [RANGED_SLOT] = RANGED }) do
        local link = GetInventoryItemLink("player", slot)
        if restart and link ~= weaponLinks[slot] then
            -- Swapping a weapon restarts a swing in progress; a finished one stays finished.
            if speeds[hand] then
                RestartIfRunning(hand)
            elseif hand ~= MAIN then
                StopSwing(hand)
            end
        end
        weaponLinks[slot] = link
    end
    AnnounceWeapons()
end

-- ---------------------------------------------------------------------------
-- Range (polled only while a swing runs or auto attack/auto repeat is on, and a target exists)
-- ---------------------------------------------------------------------------

local function FindAttackSlot()
    attackSlot = nil
    for slot = 1, 120 do
        if IsAttackAction(slot) then
            attackSlot = slot
            return
        end
    end
end

local function ToFlag(value)
    if value == 1 or value == true then return true end
    if value == 0 or value == false then return false end
    return nil
end

local function MeleeInRange()
    if attackSlot then
        local value = ToFlag(IsActionInRange(attackSlot))
        if value ~= nil then return value end
    end
    if ATTACK then
        return ToFlag(IsSpellInRange(ATTACK, "target"))
    end
end

local function RangedInRange()
    if lastRangedName then
        local value = ToFlag(IsSpellInRange(lastRangedName, "target"))
        if value ~= nil then return value end
    end
    for i = 1, #RANGED_ORDER do
        local value = ToFlag(IsSpellInRange(RANGED_ORDER[i], "target"))
        if value ~= nil then return value end
    end
    return nil
end

local function SetRange(hand, value)
    if inRange[hand] ~= value then
        inRange[hand] = value
        Fire("SWING_RANGE", hand, value)
    end
end

-- Plain ifs on purpose: `x and false or nil` would turn "out of range" into "unknown".
local function UpdateRange()
    local melee, ranged
    if UnitExists("target") then
        melee = MeleeInRange()
        if speeds[RANGED] then ranged = RangedInRange() end
    end
    SetRange(MAIN, melee)
    if speeds[OFF] then SetRange(OFF, melee) else SetRange(OFF, nil) end
    SetRange(RANGED, ranged)
end

local function NeedsRange()
    if autoAttacking or autoRepeating then return true end
    local now = GetTime()
    for _, swing in pairs(swings) do
        if (Remaining(swing, now) or 0) > 0 then return true end
    end
    return false
end

local rangeElapsed = 0
local function OnUpdate(_, elapsed)
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < RANGE_INTERVAL then return end
    rangeElapsed = 0
    if NeedsRange() then
        UpdateRange()
    else
        SetRange(MAIN, nil)
        SetRange(OFF, nil)
        SetRange(RANGED, nil)
        frame:SetScript("OnUpdate", nil)
    end
end

local function WakeRange()
    if active then
        frame:SetScript("OnUpdate", OnUpdate)
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

-- 3.3.5a CLEU: timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
local function OnCombatLog(_, subEvent, srcGUID, _, _, dstGUID, _, _, ...)
    if srcGUID == playerGUID then
        if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
            OnMeleeSwing()
        elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED" then
            local _, spellName = ...
            if NEXT_MELEE[spellName] then
                StartSwing(MAIN)
            end
        elseif subEvent == "SPELL_EXTRA_ATTACKS" then
            local _, _, _, amount = ...
            extraAttacks = extraAttacks + (amount or 1)
            extraAttackAt = GetTime()
        end
    elseif dstGUID == playerGUID then
        if subEvent == "SWING_MISSED" then
            if ... == "PARRY" then OnParry() end
        elseif subEvent == "SPELL_MISSED" then
            local _, _, _, missType = ...
            if missType == "PARRY" then OnParry() end
        end
    end
end

local handlers = {}

function handlers.PLAYER_ENTERING_WORLD()
    playerGUID = UnitGUID("player")
    RefreshWeapons(false)
    FindAttackSlot()
    -- A /reload mid-fight keeps auto attack on without firing PLAYER_ENTER_COMBAT again.
    if not autoAttacking and ATTACK and IsCurrentSpell and IsCurrentSpell(ATTACK) then
        handlers.PLAYER_ENTER_COMBAT()
    end
end

function handlers.PLAYER_ENTER_COMBAT()
    autoAttacking = true
    local now = GetTime()
    -- A finished swing from an earlier fight must not steer the opener's hand assignment.
    for _, hand in pairs({ MAIN, OFF }) do
        local swing = swings[hand]
        if swing.start and (Remaining(swing, now) or 0) <= 0 then
            swing.start, swing.duration, swing.pausedAt = nil, nil, nil
        end
    end
    expected[MAIN] = now
    expected[OFF] = speeds[OFF] and (now + OPENER_OFFHAND_DELAY * speeds[OFF]) or nil
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    WakeRange()
end

function handlers.PLAYER_LEAVE_COMBAT()
    autoAttacking = false
    extraAttacks = 0
    expected[MAIN], expected[OFF] = nil, nil
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function handlers.START_AUTOREPEAT_SPELL()
    autoRepeating = true
    WakeRange()
end

function handlers.STOP_AUTOREPEAT_SPELL()
    autoRepeating = false
end

-- 3.3.5a events: unit, spellName, rank, castID. Blizzard's casting bar reads the ID the same way.
function handlers.UNIT_SPELLCAST_START(unit, spellName, _, castID)
    if unit ~= "player" then return end
    castingName, castingID = spellName, select(8, UnitCastingInfo("player")) or castID
    if spellName == SLAM then
        PauseMelee(true)
    end
end

-- FAILED also fires for every press rejected during the cast; only the cast's own ID may end it.
local function IsOwnCast(spellName, castID)
    return castingName ~= nil and spellName == castingName and (castID == nil or castingID == nil or castID == castingID)
end

local function EndCast(succeeded)
    if castingName == SLAM then
        PauseMelee(false)
    elseif succeeded and autoAttacking and not RANGED_SPELLS[castingName] then
        -- A finished cast restarts melee even if the swing ran out mid-cast; instants never fire START.
        StartSwing(MAIN)
        StartSwing(OFF)
    end
    castingName, castingID = nil, nil
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, spellName)
    if unit ~= "player" then return end
    if RANGED_SPELLS[spellName] then
        lastRangedName = spellName
        RefreshSpeeds()
        StartSwing(RANGED)
        if spellName == AUTO_SHOT then
            RestartIfRunning(MAIN)
            RestartIfRunning(OFF)
        end
        WakeRange()
    end
    if castingName ~= nil and spellName == castingName then
        EndCast(true)
    end
end

function handlers.UNIT_SPELLCAST_INTERRUPTED(unit, spellName, _, castID)
    if unit == "player" and IsOwnCast(spellName, castID) then EndCast(false) end
end
handlers.UNIT_SPELLCAST_FAILED = handlers.UNIT_SPELLCAST_INTERRUPTED

-- STOP can arrive before SUCCEEDED, so it only lifts Slam's pause and leaves the cast to SUCCEEDED.
function handlers.UNIT_SPELLCAST_STOP(unit, spellName, _, castID)
    if unit == "player" and spellName == SLAM and IsOwnCast(spellName, castID) then
        PauseMelee(false)
    end
end

function handlers.UNIT_ATTACK_SPEED(unit)
    if unit ~= "player" then return end
    local oldOff = speeds[OFF]
    RefreshSpeeds()
    Rescale(MAIN, speeds[MAIN])
    if speeds[OFF] then
        Rescale(OFF, speeds[OFF])
    end
    if (oldOff ~= nil) ~= (speeds[OFF] ~= nil) then
        RefreshWeapons(true)
    end
    AnnounceWeapons()
end

function handlers.UNIT_RANGEDDAMAGE(unit)
    if unit ~= "player" then return end
    RefreshSpeeds()
    Rescale(RANGED, speeds[RANGED])
    AnnounceWeapons()
end

function handlers.UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then RefreshWeapons(true) end
end

function handlers.ACTIONBAR_SLOT_CHANGED()
    FindAttackSlot()
end

function handlers.PLAYER_TARGET_CHANGED()
    WakeRange()
end

function handlers.PLAYER_DEAD()
    StopSwing(MAIN)
    StopSwing(OFF)
    StopSwing(RANGED)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog(...)
    else
        local handler = handlers[event]
        if handler then handler(...) end
    end
end)

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL",
    "STOP_AUTOREPEAT_SPELL", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE",
    "UNIT_INVENTORY_CHANGED", "ACTIONBAR_SLOT_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_DEAD",
}

local function Activate()
    if active then return end
    active = true
    for i = 1, #EVENTS do
        frame:RegisterEvent(EVENTS[i])
    end
    handlers.PLAYER_ENTERING_WORLD()
end

-- Nothing tracks while dormant, so every remembered swing, range and cast would be stale on wake-up.
local function Deactivate()
    if not active then return end
    active = false
    frame:UnregisterAllEvents()
    frame:SetScript("OnUpdate", nil)
    autoAttacking, autoRepeating = false, false
    for _, swing in pairs(swings) do
        swing.start, swing.duration, swing.pausedAt = nil, nil, nil
    end
    for _, list in pairs({ inRange, expected, announced }) do
        for key in pairs(list) do list[key] = nil end
    end
    extraAttacks, extraAttackAt = 0, 0
    castingName, castingID = nil, nil
end

local used = 0
function callbacks:OnUsed()
    used = used + 1
    Activate()
end

function callbacks:OnUnused()
    used = used - 1
    if used <= 0 then
        used = 0
        Deactivate()
    end
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function lib:GetSwing(hand)
    local swing = swings[hand]
    if swing then
        return swing.start, swing.duration, swing.pausedAt
    end
end

function lib:GetSpeed(hand)
    if not active then RefreshSpeeds() end
    return speeds[hand]
end

function lib:HasWeapon(hand)
    if hand == MAIN then return true end
    return self:GetSpeed(hand) ~= nil
end

function lib:IsInRange(hand)
    return inRange[hand]
end

function lib:IsAutoAttacking()
    return autoAttacking
end

function lib:IsAutoRepeating()
    return autoRepeating
end
