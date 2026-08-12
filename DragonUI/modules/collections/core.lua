-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Mounts and companion pets over the pre-Cataclysm Companions API. It carries no mount type,
-- faction, source or description: those come from data/companion_traits.lua and the spell tooltip.

local CollectionsModule = { initialized = false, applied = false }
addon.Collections = addon.Collections or {}
local CO = addon.Collections

if addon.RegisterModule then
    addon:RegisterModule("collections", CollectionsModule,
        addon.L["Pets & Mounts"],
        addon.L["Dedicated window for your mounts and pets, opened from the micro menu"],
        { lifecyclePrefix = "Collections", loadOnce = true })
end

function CO:Enabled()
    return addon:IsModuleEnabled("collections")
end

local ART = addon._dir .. "Collections\\"

CO.TEX = {
    rows = ART .. "ListButtons",
    favorite = ART .. "FavoritesIcon",
    modelBg = ART .. "MountJournal-BG",
    faction = ART .. "MountJournalIcons",
    mountPortrait = ART .. "MountPortrait",
    petPortrait = ART .. "PetPortrait",
    search = ART .. "UI-Searchbox-Icon",
}

-- ListButtons is a 256-wide sheet whose three 208x46 row states stack down the left edge.
CO.ROW_COORDS = {
    background = { 0.00390625, 0.8203125, 0.00390625, 0.18359375 },
    highlight = { 0.00390625, 0.8203125, 0.19140625, 0.37109375 },
    selected = { 0.00390625, 0.8203125, 0.37890625, 0.55859375 },
}
CO.FAV_COORD = { 0.03125, 0.8125, 0.03125, 0.8125 }
-- The two crests on MountJournalIcons are not the same width, so an even split stretches both.
CO.FACTION_COORDS = {
    [0] = { 56 / 128, 96 / 128, 0, 48 / 64 },
    [1] = { 4 / 128, 48 / 128, 0, 48 / 64 },
}
CO.MODEL_BG_COORD = { 0, 0.78515625, 0, 1 }

local COMPANION_KINDS = { "MOUNT", "CRITTER" }
local lists = { MOUNT = {}, CRITTER = {} }
local counts = { MOUNT = 0, CRITTER = 0 }
local dirty = { MOUNT = true, CRITTER = true }
local listeners = {}

-- Only owned entries carry an API index, and those go first: the catalog is a browsing aid, so
-- burying the player's own collection alphabetically among it is the wrong default.
local function byOwnedThenName(a, b)
    if (a.index ~= nil) ~= (b.index ~= nil) then return a.index ~= nil end
    return a.name < b.name
end

-- The catalog of what exists at all: GetSpellInfo resolves any spell in the client's own data,
-- learned or not. Opposite-faction mount racials are dropped -- they can never be earned.
local function appendCatalog(kind, list, owned)
    local catalog = (kind == "MOUNT") and addon.MountTraits or addon.PetSources
    if not catalog then return end
    local faction = (kind == "MOUNT") and UnitFactionGroup and UnitFactionGroup("player")

    for spellID in pairs(catalog) do
        if not owned[spellID] then
            local side = faction and CO.MountFaction(spellID)
            local wrongSide = (side == 0 and faction == "Alliance") or (side == 1 and faction == "Horde")
            if not wrongSide then
                local name, _, icon = GetSpellInfo(spellID)
                if name then
                    list[#list + 1] = { name = name, spellID = spellID, icon = icon, active = false }
                end
            end
        end
    end
end

-- The API index renumbers on learn/unlearn and CallCompanion takes it, so entries carry the index
-- they were read with. An entry with no index is a catalog row: nothing to summon or preview.
function CO.List(kind)
    local list = lists[kind]
    if not dirty[kind] then return list end
    dirty[kind] = false

    wipe(list)
    local owned = {}
    for i = 1, (GetNumCompanions and GetNumCompanions(kind) or 0) do
        local creatureID, name, spellID, icon, active = GetCompanionInfo(kind, i)
        if creatureID then
            list[#list + 1] = {
                index = i, creatureID = creatureID, name = name or UNKNOWN,
                spellID = spellID, icon = icon, active = active and true or false,
            }
            if spellID then owned[spellID] = true end
        end
    end
    counts[kind] = #list

    appendCatalog(kind, list, owned)
    table.sort(list, byOwnedThenName)
    return list
end

function CO.CollectedCount(kind)
    CO.List(kind)
    return counts[kind]
end

function CO.Find(kind, spellID)
    if not spellID then return nil end
    for _, entry in ipairs(CO.List(kind)) do
        if entry.spellID == spellID then return entry end
    end
    return nil
end

function CO.Active(kind)
    for _, entry in ipairs(CO.List(kind)) do
        if entry.active then return entry end
    end
    return nil
end

function CO.Subscribe(fn)
    listeners[#listeners + 1] = fn
end

local function invalidate()
    dirty.MOUNT, dirty.CRITTER = true, true
    for _, fn in ipairs(listeners) do fn() end
end

-- A scripted hybrid counts as both ground and flying. Aquatic comes from the flags word, not from
-- type bit 0x2 -- that bit only means "does not dismount you while wading".
function CO.MountCategory(spellID)
    local row = addon.MountTraits and spellID and addon.MountTraits[spellID]
    local ty, flags = (row and row[1]) or 0, (row and row[2]) or 0
    if bit.band(ty, 0x4) ~= 0 then return true, true, false end
    if bit.band(flags, 0x10) ~= 0 then return false, false, true end
    if bit.band(ty, 0x1) ~= 0 then return false, true, false end
    return true, false, false
end

function CO.MountUsableNow(spellID)
    if IsOutdoors and not IsOutdoors() then return false end
    local row = addon.MountTraits and spellID and addon.MountTraits[spellID]
    local ty = (row and row[1]) or 0
    if bit.band(ty, 0x1) ~= 0 and IsFlyableArea and not IsFlyableArea() then return false end
    if bit.band(ty, 0x2) == 0 and IsSwimming and IsSwimming() then return false end
    return true
end

function CO.MountFaction(spellID)
    return spellID and addon.MountFaction and addon.MountFaction[spellID] or nil
end

function CO.SourceIndex(kind, spellID)
    if not spellID then return 12 end
    if kind == "MOUNT" then
        local row = addon.MountTraits and addon.MountTraits[spellID]
        return (row and row[3]) or 12
    end
    return (addon.PetSources and addon.PetSources[spellID]) or 12
end

local SOURCE_KEYS = {
    [1] = "Drop", [2] = "Quest", [3] = "Vendor", [4] = "Profession",
    [6] = "Achievement", [7] = "World Event", [8] = "Promotion",
    [9] = "Trading Card Game", [10] = "In-Game Shop", [11] = "Discovery",
}

function CO.SourceLabel(index)
    local key = SOURCE_KEYS[index]
    return (key and addon.L[key]) or OTHER
end

-- Per character, not per profile: profiles are routinely shared between characters.
local function favTable(kind)
    if not (addon.db and addon.db.char) then return nil end
    local root = addon.db.char.collectionFavorites
    if not root then
        root = {}
        addon.db.char.collectionFavorites = root
    end
    root[kind] = root[kind] or {}
    return root[kind]
end

-- Seeded the first time companion data actually exists, never on an empty read: seeding from a list
-- the server has not sent yet would flag the player's whole collection as new.
local function seenTable(kind)
    local db = addon.db and addon.db.char
    if not db then return nil end

    if not db.collectionSeen then
        local owned = {}
        local total = 0
        for _, k in ipairs(COMPANION_KINDS) do
            owned[k] = {}
            for i = 1, (GetNumCompanions and GetNumCompanions(k) or 0) do
                local creatureID = GetCompanionInfo(k, i)
                if creatureID then
                    owned[k][creatureID] = true
                    total = total + 1
                end
            end
        end
        if total == 0 then return nil end
        db.collectionSeen = owned
    end

    db.collectionSeen[kind] = db.collectionSeen[kind] or {}
    return db.collectionSeen[kind]
end

function CO.IsNew(kind, creatureID)
    local t = seenTable(kind)
    return (t and creatureID and not t[creatureID]) and true or false
end

function CO.HasNew(kind)
    local t = seenTable(kind)
    if not t then return false end
    for i = 1, (GetNumCompanions and GetNumCompanions(kind) or 0) do
        local creatureID = GetCompanionInfo(kind, i)
        if creatureID and not t[creatureID] then return true end
    end
    return false
end

-- One curve for every marker in the window; callers that need a different rhythm pass their own
-- speed, since the same swing reads slower on a small additive highlight than on a full row plate.
local PULSE_MIN, PULSE_MAX, PULSE_SPEED = 0.15, 0.6, 2.2
local PULSE_MID, PULSE_HALF = (PULSE_MAX + PULSE_MIN) / 2, (PULSE_MAX - PULSE_MIN) / 2

-- Second return is the same curve as a plain 0..1, for callers that also fade a colour along it.
function CO.PulseAlpha(speed)
    local phase = (math.sin(GetTime() * (speed or PULSE_SPEED)) + 1) / 2
    return PULSE_MIN + (PULSE_MAX - PULSE_MIN) * phase, phase
end

function CO.MarkSeen(kind, creatureID)
    local t = seenTable(kind)
    if t and creatureID then t[creatureID] = true end
end

function CO.IsFavorite(kind, creatureID)
    local t = favTable(kind)
    return (t and creatureID and t[creatureID]) and true or false
end

function CO.ToggleFavorite(kind, creatureID)
    local t = favTable(kind)
    if not (t and creatureID) then return false end
    local on = not t[creatureID]
    t[creatureID] = on or nil
    return on
end

function CO.Summon(kind, entry)
    if not (entry and entry.index) then return end
    if entry.active then
        DismissCompanion(kind)
        PlaySound("igMainMenuOptionCheckBoxOff")
    else
        CallCompanion(kind, entry.index)
        PlaySound("igMainMenuOptionCheckBoxOn")
    end
end

-- Usable favorite, then any favorite, then any usable, then anything -- retail's order. Within the
-- chosen pool, flying wins wherever flight works and aquatic wins while swimming.
local function tierOf(spellID, swimming, flyable)
    local row = addon.MountTraits and spellID and addon.MountTraits[spellID]
    local ty, flags = (row and row[1]) or 0, (row and row[2]) or 0
    if bit.band(flags, 0x30) ~= 0 and swimming then return 1 end
    if bit.band(ty, 0x5) ~= 0 and flyable and not swimming then return 1 end
    return 2
end

local function bestTier(kind, pool)
    if kind ~= "MOUNT" or #pool <= 1 then return pool end
    local swimming = IsSwimming and IsSwimming() and true or false
    local flyable = IsFlyableArea and IsFlyableArea() and true or false
    local first, second = {}, {}
    for _, entry in ipairs(pool) do
        local t = tierOf(entry.spellID, swimming, flyable)
        table.insert(t == 1 and first or second, entry)
    end
    return #first > 0 and first or second
end

function CO.SummonRandomFavorite(kind)
    local active = CO.Active(kind)
    if active then
        DismissCompanion(kind)
        PlaySound("igMainMenuOptionCheckBoxOff")
        return
    end

    local owned, fav = {}, {}
    for _, entry in ipairs(CO.List(kind)) do
        if entry.index then
            owned[#owned + 1] = entry
            if CO.IsFavorite(kind, entry.creatureID) then fav[#fav + 1] = entry end
        end
    end

    -- The whole collection only comes in when nothing is favorited -- an unusable favorite does not.
    local source = #fav > 0 and fav or owned
    local usable = {}
    for _, entry in ipairs(source) do
        if kind ~= "MOUNT" or CO.MountUsableNow(entry.spellID) then
            usable[#usable + 1] = entry
        end
    end

    if #usable == 0 then
        local message = addon.L["Nothing collected yet."]
        if #fav > 0 then
            message = addon.L["None of your favorites can be used here."]
        elseif #owned > 0 then
            message = addon.L["Nothing you own can be used here."]
        end
        addon:Print(message)
        return
    end

    local pool = bestTier(kind, usable)

    CallCompanion(kind, pool[math.random(#pool)].index)
    PlaySound("igMainMenuOptionCheckBoxOn")
end

-- An action slot only takes a spell, item or macro, so the draggable form is a real macro that
-- re-enters the picker at cast time. Keyed by body so a second drag reuses it.
local MACRO_BODY = {
    MOUNT = "/script DragonUI.Collections.SummonRandomFavorite(\"MOUNT\")",
    CRITTER = "/script DragonUI.Collections.SummonRandomFavorite(\"CRITTER\")",
}
-- MacroPopupEditBox is letters="16", so every translation has to fit or the client cuts it short.
local function macroName(kind)
    if kind == "MOUNT" then return addon.L["Random Mount"] end
    return addon.L["Random Pet"]
end

-- Shared with the button art on purpose: a dragged macro that lands wearing a different icon than
-- the button it came from reads as the wrong macro.
CO.RandomIcon = {
    MOUNT = "Interface\\Icons\\Ability_Mount_Charger",
    CRITTER = "Interface\\Icons\\Ability_Hunter_BeastCall",
}

-- Everything after the last path separator, lowercased. GetMacroIconInfo is not consistent about
-- returning the Interface\Icons prefix, so the file name is the only safe thing to compare.
local BACKSLASH = 92

local function iconFile(texture)
    texture = string.lower(tostring(texture or ""))
    local cut = 0
    for i = 1, #texture do
        if string.byte(texture, i) == BACKSLASH then cut = i end
    end
    return string.sub(texture, cut + 1)
end

-- CreateMacro takes an index into the macro icon list, not a path.
local function macroIconIndex(path)
    if not (GetNumMacroIcons and GetMacroIconInfo) then return 1 end
    local wanted = iconFile(path)
    for i = 1, GetNumMacroIcons() do
        if iconFile(GetMacroIconInfo(i)) == wanted then return i end
    end
    return 1
end

-- ActionButton_Update stamps a macro's name across the button, and these two exist only to be
-- dragged, so an abbreviated "Random Mo..." over the icon is noise. The tooltip still names them.
local macroLabelsHooked = false

local function hideMacroLabels()
    if macroLabelsHooked or not (ActionButton_Update and GetActionText) then return end
    macroLabelsHooked = true

    hooksecurefunc("ActionButton_Update", function(self)
        local slot = self and self.action
        local name = slot and self.GetName and self:GetName()
        local label = name and _G[name .. "Name"]
        if not label then return end
        local text = GetActionText(slot)
        if text and (text == macroName("MOUNT") or text == macroName("CRITTER")) then
            label:SetText("")
        end
    end)
end

-- Blizzard_MacroUI is load-on-demand, so its MAX_*_MACROS globals stay nil until the player has
-- opened the macro window; these are the 3.3.5a values the character macros are indexed above.
local ACCOUNT_MACROS, CHARACTER_MACROS = 36, 18

-- Match on the name too, and on a trimmed body: the client hands the body back with its own
-- whitespace, so comparing it raw missed our own macro and every drag minted another one.
local function findMacro(name, body)
    local account, perChar = GetNumMacros()
    local base = MAX_ACCOUNT_MACROS or ACCOUNT_MACROS
    local wanted = strtrim(body)

    local function scan(from, to)
        for i = from, to do
            local found, _, stored = GetMacroInfo(i)
            if found == name or strtrim(stored or "") == wanted then return i end
        end
    end

    return scan(1, account or 0) or scan(base + 1, base + (perChar or 0))
end

function CO.EnsureRandomMacro(kind)
    local body = MACRO_BODY[kind]
    if not (body and CreateMacro and GetNumMacros) then return nil end

    local existing = findMacro(macroName(kind), body)
    if existing then return existing end
    if InCombatLockdown() then return nil end

    local account, perChar = GetNumMacros()
    local useCharacterSlot = (account or 0) >= (MAX_ACCOUNT_MACROS or ACCOUNT_MACROS)
    if useCharacterSlot and (perChar or 0) >= (MAX_CHARACTER_MACROS or CHARACTER_MACROS) then
        addon:Print(addon.L["No free macro slot for the random favorite button."])
        return nil
    end

    return CreateMacro(macroName(kind), macroIconIndex(CO.RandomIcon[kind]), body, useCharacterSlot)
end

-- GetCompanionInfo returns no description, and GetSpellInfo carries none either; the companion's
-- own spell tooltip is where the localized text lives. Its last body line is the description.
local scanner, descriptions = nil, {}

function CO.Description(spellID)
    if not spellID then return nil end
    if descriptions[spellID] then return descriptions[spellID] end

    if not scanner then
        scanner = CreateFrame("GameTooltip", "DragonUICollectionsScanTooltip", nil, "GameTooltipTemplate")
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink("spell:" .. spellID)

    local text
    for i = 2, scanner:NumLines() do
        local line = _G["DragonUICollectionsScanTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if value and value ~= "" then text = value end
    end
    -- An empty read is not cached: spell data can still be resolving on the first frames after login.
    descriptions[spellID] = text
    return text
end

-- The button has to be created at load for the micro menu to see the slot at all, so switching the
-- module off flags it instead; micromenu.lua drops flagged buttons from the strip and its layout.
local function suppressMicroButton(suppressed)
    local btn = _G.CollectionsMicroButton
    if not btn then return end
    btn.dragonUISuppressed = suppressed
    if suppressed then btn:Hide() end
    if addon.RefreshMicromenu then addon.RefreshMicromenu() end
end

-- Enabling only clears the flag; the skin and placement come from the micro menu's own pass.
local function ApplyCollectionsSystem()
    CollectionsModule.initialized = true
    CollectionsModule.applied = CO:Enabled()
    suppressMicroButton(not CollectionsModule.applied)
    hideMacroLabels()
end

local function RestoreCollectionsSystem()
    CollectionsModule.applied = false
    if CO.Close then CO.Close() end
    suppressMicroButton(true)
    addon:Print(addon.L["Pets & Mounts disabled. Reload the UI to remove its micro menu button."])
end

addon.ApplyCollectionsSystem = ApplyCollectionsSystem
addon.RestoreCollectionsSystem = RestoreCollectionsSystem

-- PetPaperDollFrame_OnEvent still flashes CharacterMicroButton and the pet tab we removed whenever a
-- companion is learned. Companions live here now, so the alert belongs on this button.
local PULSE_SECONDS, PULSE_RATE = 60, 1

local function movePulse()
    if not SetButtonPulse then return end
    local btn = _G.CollectionsMicroButton
    if not btn or btn.dragonUISuppressed then return end

    if _G.CharacterMicroButton then SetButtonPulse(_G.CharacterMicroButton, 0, PULSE_RATE) end
    if _G.CharacterFrameTab2 then SetButtonPulse(_G.CharacterFrameTab2, 0, PULSE_RATE) end
    if not (CO.IsShown and CO.IsShown()) then SetButtonPulse(btn, PULSE_SECONDS, PULSE_RATE) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("COMPANION_LEARNED")
events:RegisterEvent("COMPANION_UNLEARNED")
events:RegisterEvent("COMPANION_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ApplyCollectionsSystem()
        return
    end
    invalidate()
    -- Next frame: PetPaperDollFrame registered at client load, so its pulse is set after this runs.
    if event == "COMPANION_LEARNED" then addon:After(0, movePulse) end
end)
