-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs, pairs, tonumber, sort, char = ipairs, pairs, tonumber, table.sort, string.char
local band = bit.band

local NONE = {}

-- Filters and search ------------------------------------------------------------------------------

-- string.lower folds ASCII only; Latin-1 and Cyrillic capitals are lowered here by their bytes.
local TWO_BYTE_LOWER = { ["\208\129"] = "\209\145" }
for byte = 128, 158 do
    if byte ~= 151 then TWO_BYTE_LOWER["\195" .. char(byte)] = "\195" .. char(byte + 32) end
end
for byte = 144, 159 do
    TWO_BYTE_LOWER["\208" .. char(byte)] = "\208" .. char(byte + 32)
end
for byte = 160, 175 do
    TWO_BYTE_LOWER["\208" .. char(byte)] = "\209" .. char(byte - 32)
end

function Book.FoldCase(text)
    local folded = text:gsub("[\195\208][\128-\191]", TWO_BYTE_LOWER)
    return folded:lower()
end

function Book.NormalizeQuery(text)
    if text == nil or text == "" then return nil end
    return Book.FoldCase(text)
end

-- Plain find: "(", "[" and "%" are typed text, never pattern syntax.
function Book.NameMatches(name, query)
    if query == nil then return true end
    return name ~= nil and Book.FoldCase(name):find(query, 1, true) ~= nil
end

local function kept(entry, filters)
    if filters.hidePassives and entry.passive then return false end
    return Book.NameMatches(entry.name, filters.query)
end

local function onlyKept(list, filters)
    local survivors = {}
    for _, entry in ipairs(list) do
        if kept(entry, filters) then survivors[#survivors + 1] = entry end
    end
    return survivors
end

-- The game's book ---------------------------------------------------------------------------------

function Book.LinkSpellID(link)
    return link and tonumber(link:match("spell:(%d+)"))
end

function Book.PetBook()
    local count, token = HasPetSpells()
    if count and count > 0 then return count, token end
end

function Book.ReadSlot(index, book)
    local name, sub = GetSpellName(index, book)
    local texture = name and GetSpellTexture(index, book)
    if not texture then return nil end
    local entry = {
        book = book,
        index = index,
        name = name,
        sub = sub or "",
        icon = texture,
        passive = IsPassiveSpell(index, book) and true or false,
        spellID = Book.LinkSpellID(GetSpellLink(index, book)),
    }
    if not entry.passive then
        -- Pet abilities go by name: casting them by ID is unverified on this client.
        if book == "pet" then entry.cast = name else entry.cast = entry.spellID end
        if book == "pet" and GetSpellAutocast(index, book) then
            entry.autocast = SLASH_PET_AUTOCASTTOGGLE1 .. " " .. name
        end
    end
    entry.key = book .. ":" .. (entry.spellID or name)
    return entry
end

-- Lower ranks sit right before the top one in the full list, so the walk stops at another name.
local function lowerRanks(entry, firstSlot)
    local ranks = {}
    for slot = entry.index - 1, firstSlot, -1 do
        local name, rank = GetSpellName(slot, "spell")
        if name ~= entry.name then break end
        ranks[#ranks + 1] = {
            book = "spell",
            index = slot,
            name = name,
            sub = rank or "",
            icon = GetSpellTexture(slot, "spell"),
            spellID = Book.LinkSpellID(GetSpellLink(slot, "spell")),
        }
    end
    if #ranks > 0 then return ranks end
end

-- The client already knows the top-rank slots; rank text differs by locale and is never read.
function Book.ReadTab(tab, allRanks)
    local _, _, offset, count, topOffset, topCount = GetSpellTabInfo(tab)
    local firstSlot = offset + 1
    if not allRanks then offset, count = topOffset, topCount end
    local shelf = {}
    for slot = offset + 1, offset + count do
        local index = slot
        if not allRanks then index = GetKnownSlotFromHighestRankSlot(slot) end
        local entry = index and index > 0 and Book.ReadSlot(index, "spell")
        if entry then
            if not allRanks and not entry.passive then entry.lower = lowerRanks(entry, firstSlot) end
            shelf[#shelf + 1] = entry
        end
    end
    return shelf
end

-- Trainer data ------------------------------------------------------------------------------------

local RACE_ORDINALS = {
    Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5,
    Tauren = 6, Gnome = 7, Troll = 8, BloodElf = 10, Draenei = 11,
}

function Book.RaceBit(token)
    local ordinal = RACE_ORDINALS[token]
    return ordinal and 2 ^ (ordinal - 1) or 0
end

local trainerIndexes = {}

function Book.TrainerIndex(classToken)
    local list = addon.SpellbookTrainerData[classToken]
    if not list then return nil end
    local cached = trainerIndexes[classToken]
    if cached then return cached end
    local links, byID = {}, {}
    for _, record in ipairs(list) do
        byID[record[2]] = record
        local previous = record[4]
        if previous ~= 0 then
            links[previous] = links[previous] or {}
            local successors = links[previous]
            successors[#successors + 1] = record
        end
    end
    trainerIndexes[classToken] = { list = list, after = links, byID = byID }
    return trainerIndexes[classToken]
end

-- Learning a rank can drop the lower ones from the book, so any higher known rank counts too.
local function knownInChain(spellID, filters)
    local memo = filters.memo
    if not memo then
        memo = {}
        filters.memo = memo
    end
    local answer = memo[spellID]
    if answer ~= nil then return answer end
    answer = IsSpellKnown(spellID) and true or false
    local successors = filters.trainer.after[spellID]
    if not answer and successors then
        for _, record in ipairs(successors) do
            if knownInChain(record[2], filters) then
                answer = true
                break
            end
        end
    end
    memo[spellID] = answer
    return answer
end

-- A missing seventh slot reads as nil, which counts as "no requirement" like 0.
local function met(spellID, filters)
    return spellID == nil or spellID == 0 or knownInChain(spellID, filters)
end

local function raceAllows(record, filters)
    return record[6] == 0 or band(record[6], filters.raceBit) ~= 0
end

local function nextRank(index, spellID, filters)
    for _, record in ipairs(index.after[spellID] or NONE) do
        if record[1] <= filters.level and raceAllows(record, filters) and not knownInChain(record[2], filters)
            and met(record[5], filters) and met(record[7], filters) then
            return record
        end
    end
end

-- The run of consecutive ranks the player could buy right now, as first and last records.
function Book.TrainerRanks(index, spellID, filters)
    local lowest, highest
    local record = nextRank(index, spellID, filters)
    while record do
        lowest = lowest or record
        highest = record
        record = nextRank(index, record[2], filters)
    end
    return lowest, highest
end

local function rankNumber(spellID)
    local _, rank = GetSpellInfo(spellID)
    return rank and tonumber(rank:match("%d+"))
end

-- Grey cards for spells not learned yet -----------------------------------------------------------

function Book.GreyState(record, filters)
    if not met(record[5], filters) then return "talent" end
    if not met(record[7], filters) then return "later", record[7] end
    if record[1] > filters.level then return "later" end
    return "ready"
end

local function greyEntry(record, filters)
    local name, rank, icon = GetSpellInfo(record[2])
    if not name or not Book.NameMatches(name, filters.query) then return nil end
    local state, needs = Book.GreyState(record, filters)
    return {
        grey = true,
        spellID = record[2],
        name = name,
        rank = rank or "",
        icon = icon,
        level = record[1],
        cost = record[3],
        state = state,
        needs = needs,
        higherRank = record[4] ~= 0,
        allRanks = filters.allRanks,
        key = "grey:" .. record[2],
    }
end

local function chainFrom(index, record, filters, out)
    out[#out + 1] = record
    for _, successor in ipairs(index.after[record[2]] or NONE) do
        if raceAllows(successor, filters) then chainFrom(index, successor, filters, out) end
    end
    return out
end

local function addGrey(list, record, filters)
    local entry = greyEntry(record, filters)
    if entry then list[#list + 1] = entry end
end

local function byLevelThenName(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if a.name ~= b.name then return a.name < b.name end
    return a.spellID < b.spellID
end

-- One card per unlearned chain (its first rank), or every rank with all ranks shown; keyed by tree.
function Book.UnlearnedByTree(filters)
    local index, trees = filters.trainer, {}
    if not index or filters.hideUnlearned then return trees end
    for _, record in ipairs(index.list) do
        local first = record[4] == 0 or not index.byID[record[4]]
        local root = record[4] ~= 0 and record[4] or record[2]
        if first and raceAllows(record, filters) and not knownInChain(root, filters) then
            local tree = record[8] or 0
            trees[tree] = trees[tree] or {}
            local ranks = filters.allRanks and chainFrom(index, record, filters, {}) or { record }
            for _, rankRecord in ipairs(ranks) do
                addGrey(trees[tree], rankRecord, filters)
            end
        end
    end
    for _, list in pairs(trees) do
        sort(list, byLevelThenName)
    end
    return trees
end

-- With all ranks shown, the ranks still to learn follow the last learned rank of the same spell.
local function futureRanks(index, spellID, filters)
    local future = {}
    for _, record in ipairs(index.after[spellID] or NONE) do
        if raceAllows(record, filters) then
            if knownInChain(record[2], filters) then return NONE end
            chainFrom(index, record, filters, future)
        end
    end
    return future
end

local function markTrainerRanks(entries, filters)
    local index = filters.trainer
    if not index or (filters.allRanks and not filters.hideUnlearned) then return end
    for _, entry in ipairs(entries) do
        local lowest, highest
        if entry.spellID then lowest, highest = Book.TrainerRanks(index, entry.spellID, filters) end
        if lowest then
            entry.trainer = { from = rankNumber(lowest[2]), to = rankNumber(highest[2]) }
        end
    end
end

-- Learned cards first in the game's order, then the grey ones.
local function withGreys(learned, greys, filters)
    local index = filters.trainer
    local cards = {}
    markTrainerRanks(learned, filters)
    for _, entry in ipairs(learned) do
        cards[#cards + 1] = entry
        local record = index and entry.spellID and index.byID[entry.spellID]
        if filters.allRanks and record then entry.rankLevel = record[1] end
        if index and filters.allRanks and not filters.hideUnlearned and entry.spellID then
            for _, future in ipairs(futureRanks(index, entry.spellID, filters)) do
                addGrey(cards, future, filters)
            end
        end
    end
    for _, grey in ipairs(greys or NONE) do
        cards[#cards + 1] = grey
    end
    return cards
end

-- Categories --------------------------------------------------------------------------------------

local function greysOf(filters)
    filters.greys = filters.greys or Book.UnlearnedByTree(filters)
    return filters.greys
end

-- Tab names and talent-tree names differ ("Shadow Magic" / "Shadow"); a known spell links them.
local function treeOfTab(spells, index)
    for _, entry in ipairs(spells) do
        local record = entry.spellID and (index.byID[entry.spellID] or (index.after[entry.spellID] or NONE)[1])
        local tree = record and record[8]
        if tree and tree > 0 then return tree end
    end
end

function Book.ClassSections(filters)
    local index, greys = filters.trainer, greysOf(filters)
    local shelves, placed = {}, {}
    for tab = 2, GetNumSpellTabs() do
        local spells = Book.ReadTab(tab, filters.allRanks)
        local tree = index and treeOfTab(spells, index)
        if tree and placed[tree] then tree = nil end
        if tree then placed[tree] = true end
        shelves[#shelves + 1] = { tree = tree, title = (GetSpellTabInfo(tab)), learned = onlyKept(spells, filters) }
    end
    for _, shelf in ipairs(shelves) do
        for tree = 1, 3 do
            if not shelf.tree and not placed[tree] and shelf.title == GetTalentTabInfo(tree) then
                shelf.tree, placed[tree] = tree, true
            end
        end
    end
    -- A tree the book has no tab for yet is placed among the others in tree order.
    for tree = 1, 3 do
        if not placed[tree] and greys[tree] then
            local position = #shelves + 1
            for slot, shelf in ipairs(shelves) do
                if shelf.tree and shelf.tree > tree then
                    position = slot
                    break
                end
            end
            table.insert(shelves, position, { tree = tree, title = (GetTalentTabInfo(tree)), learned = {} })
        end
    end
    local sections = {}
    for _, shelf in ipairs(shelves) do
        local cards = withGreys(shelf.learned, shelf.tree and greys[shelf.tree], filters)
        if #cards > 0 then sections[#sections + 1] = { title = shelf.title, entries = cards } end
    end
    return sections
end

local function generalSections(filters)
    if GetNumSpellTabs() < 1 then return {} end
    local cards = withGreys(onlyKept(Book.ReadTab(1, filters.allRanks), filters), greysOf(filters)[0], filters)
    if #cards == 0 then return {} end
    return { { entries = cards } }
end

local function petSections(filters)
    local abilities = {}
    for index = 1, Book.PetBook() or 0 do
        local entry = Book.ReadSlot(index, "pet")
        if entry and kept(entry, filters) then abilities[#abilities + 1] = entry end
    end
    if #abilities == 0 then return {} end
    return { { title = UnitName("pet"), entries = abilities } }
end

function Book.CategoryExists(cat)
    if cat == Book.PET then return Book.PetBook() ~= nil end
    return true
end

function Book.BuildSections(cat, filters)
    if cat == Book.CLASS then return Book.ClassSections(filters) end
    if cat == Book.GENERAL then return generalSections(filters) end
    return petSections(filters)
end

function Book.CategoryLabel(cat)
    if cat == Book.CLASS then return (UnitClass("player")) end
    if cat == Book.GENERAL then return (GetSpellTabInfo(1)) end
    local _, token = Book.PetBook()
    return _G["PET_TYPE_" .. (token or "PET")]
end
