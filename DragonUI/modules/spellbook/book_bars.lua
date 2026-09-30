-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs, pairs, next, tonumber, wipe = ipairs, pairs, next, tonumber, wipe
local strlower = string.lower

local BUTTON_PREFIXES = { "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }

-- Stands in for the rank of a spell named without one, which casts the highest rank known.
local TOP = "\1"

local slotSpells, extraSpells = {}, {}
local refreshMarks

-- Spells a slot holds: one key per rank, each mapped to the bare lower-case name ---------------

local function exactKey(name, rank)
    return strlower(name) .. "\0" .. strlower(rank or "")
end

local function topKey(name)
    return strlower(name) .. "\0" .. TOP
end

local function noteExact(into, name, rank)
    into[exactKey(name, rank)] = strlower(name)
end

local function noteTyped(into, text)
    local name, rank = text:match("^[%s!]*(.-)%s*%((.-)%)%s*$")
    if not name then name = text:match("^[%s!]*(.-)%s*$") end
    if name == "" then return end
    if rank and rank ~= "" then
        noteExact(into, name, rank)
    else
        into[topKey(name)] = strlower(name)
    end
end

local VERBS = {}
local FAMILIES = { "SLASH_CAST", "SLASH_USE", "SLASH_CASTRANDOM", "SLASH_USERANDOM", "SLASH_CASTSEQUENCE" }
local LISTED = { SLASH_CASTRANDOM = true, SLASH_USERANDOM = true, SLASH_CASTSEQUENCE = true }

for _, family in ipairs(FAMILIES) do
    local number = 1
    while _G[family .. number] do
        VERBS[strlower(_G[family .. number])] = family
        number = number + 1
    end
end

local function bodySpells(body, into)
    for line in body:gmatch("[^\r\n]+") do
        local word, rest = line:match("^%s*(%S+)%s*(.*)$")
        word = word and strlower(word)
        local family = word and (word:sub(1, 5) == "#show" and "SLASH_CAST" or VERBS[word])
        if family then
            rest = rest:gsub("%b[]", "")
            if family == "SLASH_CASTSEQUENCE" then rest = rest:gsub("reset=%S+", "") end
            for piece in rest:gmatch(LISTED[family] and "[^;,]+" or "[^;]+") do
                noteTyped(into, piece)
            end
        end
    end
end

local function macroSpells(index)
    local spells = {}
    local name, rank = GetMacroSpell(index)
    if name then noteExact(spells, name, rank) end
    local _, _, body = GetMacroInfo(index)
    if body then bodySpells(body, spells) end
    return next(spells) and spells or nil
end

local function actionSpells(action)
    local kind, index, _, spellID = GetActionInfo(action)
    if kind == "macro" then return macroSpells(index) end
    if kind ~= "spell" then return nil end
    local id, name, rank = tonumber(spellID), nil, nil
    if id then name, rank = GetSpellInfo(id) end
    if not name then name, rank = GetSpellName(index, "spell") end
    if not name then return nil end
    local spells = {}
    noteExact(spells, name, rank)
    return spells
end

local function extraSlotSpells(data)
    if type(data) ~= "table" then return nil end
    local spells = {}
    if data.type == "spell" then
        local id, name, rank = tonumber(data.spellID), nil, nil
        if id then name, rank = GetSpellInfo(id) end
        if name then
            noteExact(spells, name, rank)
        elseif data.spell then
            noteTyped(spells, data.spell)
        end
    elseif data.type == "macro" and data.macrotext then
        bodySpells(data.macrotext, spells)
    end
    return next(spells) and spells or nil
end

local function learn(bound, spells)
    for _, name in pairs(spells) do bound[name] = true end
end

function Book.ScanActionBars()
    local bound, bySlot, extras = {}, {}, {}
    for action = 1, 120 do
        local spells = actionSpells(action)
        if spells then
            bySlot[action] = spells
            learn(bound, spells)
        end
    end
    if addon.ForEachExtrabarButton then
        addon.ForEachExtrabarButton(function(button, data)
            local spells = extraSlotSpells(data)
            if spells then
                extras[button] = spells
                learn(bound, spells)
            end
        end)
    end
    Book.bound, slotSpells, extraSpells = bound, bySlot, extras
    refreshMarks(true)
end

-- Any rank on a bar counts: the glow is about the spell, the pulse is about the rank.
function Book.IsBound(name)
    return Book.bound[strlower(name)] == true
end

-- Pulse on the buttons holding the hovered or dragged rank ----------------------------------------

local marks, lit = {}, {}
local hovered, hoverOwner
local sourceA, sourceB, shownExact, shownTop, shownPet

local function buildMark(button, checked)
    local mark = button:CreateTexture(nil, "OVERLAY")
    mark:SetBlendMode("ADD")
    mark:SetAllPoints(checked)
    mark:Hide()
    local pulse = mark:CreateAnimationGroup()
    local dim = pulse:CreateAnimation("Alpha")
    dim:SetDuration(0.5)
    dim:SetChange(-0.65)
    dim:SetSmoothing("IN_OUT")
    pulse:SetLooping("BOUNCE")
    mark.pulse = pulse
    marks[button] = mark
    return mark
end

local function light(button)
    local checked = button:GetCheckedTexture()
    if not checked then return end
    local mark = marks[button] or buildMark(button, checked)
    mark:SetDrawLayer(checked:GetDrawLayer())
    mark:SetTexture(checked:GetTexture())
    mark:SetTexCoord(checked:GetTexCoord())
    lit[button] = mark
    mark:Show()
    mark.pulse:Play()
end

local function unlight()
    for button, mark in pairs(lit) do
        mark.pulse:Stop()
        mark:Hide()
        lit[button] = nil
    end
    shownExact, shownTop, shownPet = nil, nil, nil
end

local function holds(spells, exact, top)
    return spells[exact] ~= nil or (top ~= nil and spells[top] ~= nil)
end

local function lightActionButtons(exact, top)
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for index = 1, NUM_ACTIONBAR_BUTTONS do
            local button = _G[prefix .. index]
            local spells = button and button.action and slotSpells[button.action]
            if spells and holds(spells, exact, top) and button:IsVisible() then light(button) end
        end
    end
    for button, spells in pairs(extraSpells) do
        if holds(spells, exact, top) and button:IsVisible() then light(button) end
    end
end

local function lightPetButtons(wanted)
    for index = 1, NUM_PET_ACTION_SLOTS do
        local name = GetPetActionInfo(index)
        local button = name and _G["PetActionButton" .. index]
        if button and button:IsVisible() and strlower(name) == wanted then light(button) end
    end
end

local petHeld, pickedIndex, pickedBook = false, nil, nil

-- The pet grid events, not the cursor type, vouch for a pet ability on the cursor.
local function heldSpell()
    local kind, index, book = GetCursorInfo()
    if kind == "spell" and index then return index, book or "spell" end
    if petHeld then return pickedBook == "pet" and pickedIndex or 0, "pet" end
end

function Book.NotePickup(index, book)
    pickedIndex, pickedBook = index, book
end

-- A spell on the cursor outranks the hovered one, so the pulse carries on through a drag.
local function source()
    if not Book.IsOpen() then return nil, nil end
    local index, book = heldSpell()
    if index then return book, index end
    return hovered, nil
end

-- Ranks sit together in the book in rising order, so the top one is the last of its name.
local function resolve(a, b)
    local name, rank, index, book
    if b then
        name, rank = GetSpellName(b, a)
        index, book = b, a
    elseif a then
        name, rank, index, book = a.name, a.sub, a.index, a.book
    end
    if not name then return nil end
    if book == "pet" then return strlower(name), nil, true end
    local top = GetSpellName(index + 1, book) ~= name and topKey(name) or nil
    return exactKey(name, rank), top, false
end

function refreshMarks(force)
    local a, b = source()
    -- The tooltip re-enters every 0.2 s and the poll every 0.1 s; an unchanged source costs nothing.
    if not force and a == sourceA and b == sourceB then return end
    sourceA, sourceB = a, b
    local exact, top, pet = resolve(a, b)
    -- Picking up the hovered rank changes the source, not the target, so the pulse keeps its beat.
    if not force and exact == shownExact and top == shownTop and pet == shownPet then return end
    unlight()
    if not exact then return end
    shownExact, shownTop, shownPet = exact, top, pet
    if pet then
        lightPetButtons(exact)
    else
        lightActionButtons(exact, top)
    end
end

-- Rank rows can vanish or stop taking the mouse without a leave event, so their owner is watched.
function Book.MarkBars(entry, owner)
    local live = entry ~= nil and not entry.grey and not entry.passive
    hovered = live and entry or nil
    hoverOwner = live and owner or nil
    refreshMarks()
end

-- Only for a closing book: it stops watching the cursor, so a held spell's pulse goes too.
function Book.ClearMarks()
    hovered, hoverOwner, sourceA, sourceB = nil, nil, nil, nil
    unlight()
end

local function ownerLeft()
    return hoverOwner ~= nil and not (hoverOwner:IsVisible() and hoverOwner:IsMouseOver())
end

-- Dragging a spell out of the book ---------------------------------------------------------------

local heldIndex, heldBook = nil, nil
local was, raised, NONE = {}, {}, {}
local watch, sinceCheck = CreateFrame("Frame"), 0

local function record(frame)
    if was[frame] == nil then was[frame] = frame:GetFrameStrata() end
    for _, child in ipairs({ frame:GetChildren() }) do record(child) end
end

-- Frames built mid-drag were never recorded, so they fall back to their root's own strata.
local function paint(frame, strata, home)
    local target = strata or was[frame] or home
    if frame:GetFrameStrata() ~= target then frame:SetFrameStrata(target) end
    for _, child in ipairs({ frame:GetChildren() }) do paint(child, strata, home) end
end

local function isTotem(name)
    for slot = 1, MAX_TOTEMS do
        for _, id in ipairs({ GetMultiCastTotemSpells(slot) }) do
            if GetSpellInfo(id) == name then return true end
        end
    end
    return false
end

-- The frames holding the buttons this spell can be dropped on, whichever module lays them out.
local function dropTargets(index, book)
    local targets = {}
    local function add(frame)
        if frame and frame ~= UIParent then targets[frame] = true end
    end
    if book == "pet" then
        add(PetActionButton1:GetParent())
        return targets
    end
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        local button = _G[prefix .. 1]
        add(button and button:GetParent())
    end
    if addon.ForEachExtrabarButton then
        addon.ForEachExtrabarButton(function(button) add(button:GetParent()) end)
    end
    local name = GetSpellName(index, book)
    if name and isTotem(name) then add(MultiCastActionBarFrame) end
    return targets
end

-- Only bars that can take the spell rise over the book; they are protected, so combat waits.
local function setRaised(index, book)
    if Book.Locked() then return end
    local targets = index and dropTargets(index, book) or NONE
    for frame, home in pairs(raised) do
        if not targets[frame] then
            raised[frame] = nil
            paint(frame, nil, home)
        end
    end
    for frame in pairs(targets) do
        if not raised[frame] then
            record(frame)
            raised[frame] = was[frame]
            paint(frame, "DIALOG")
        end
    end
    if not next(raised) then wipe(was) end
end

function Book.SyncLayer()
    local open = Book.IsOpen()
    if open then watch:Show() else watch:Hide() end
    if open then setRaised(heldSpell()) else setRaised(nil) end
end

-- Last unlocked moment before a fight: raised bars would otherwise sit over every window until it ends.
function Book.ResetLayer()
    setRaised(nil)
end

local function tick()
    if ownerLeft() then hovered, hoverOwner = nil, nil end
    refreshMarks()
    local index, book = heldSpell()
    if index == heldIndex and book == heldBook then return end
    local wasHeld = heldIndex ~= nil
    heldIndex, heldBook = index, book
    Book.SyncLayer()
    -- A drop or a swap can change what the bars hold, the Extra Bar included, which fires no slot event.
    if wasHeld then Book.Queue("glow") end
end

watch:Hide()
watch:SetScript("OnUpdate", function(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck < 0.1 then return end
    sinceCheck = 0
    tick()
end)

-- The poll is what decides; these events only bring its next check forward.
local function checkSoon()
    sinceCheck = 1
end

local function petGridShown()
    petHeld = true
    checkSoon()
end

local function petGridHidden()
    petHeld, pickedIndex, pickedBook = false, nil, nil
    checkSoon()
end

function Book.ListenToBars()
    Book.On("CURSOR_UPDATE", checkSoon)
    Book.On("ACTIONBAR_SHOWGRID", checkSoon)
    Book.On("ACTIONBAR_HIDEGRID", checkSoon)
    Book.On("PET_BAR_SHOWGRID", petGridShown)
    Book.On("PET_BAR_HIDEGRID", petGridHidden)
    Book.On("UPDATE_MACROS", function() Book.Queue("glow") end)
end
