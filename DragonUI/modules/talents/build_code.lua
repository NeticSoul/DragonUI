-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Standalone on purpose (no frames, no sibling files) so the codec can be tested alone.
local TM = addon.TalentModule or { initialized = false, applied = false }
addon.TalentModule = TM
TM.ns = TM.ns or {}
local ns = TM.ns

local floor, max, min = math.floor, math.max, math.min
local concat = table.concat

local CODE_TAG = "!DUIT1!"
local CODE_LIMIT = 1024
local DIGIT_LIMIT = 64
local NAME_LIMIT = 120

local knownClass = {}
for token in ("WARRIOR PALADIN HUNTER ROGUE PRIEST DEATHKNIGHT SHAMAN MAGE WARLOCK DRUID"):gmatch("%u+") do
    knownClass[token] = true
end
ns.KNOWN_CLASS = knownClass

local function levelCap()
    local byExpansion = _G.MAX_PLAYER_LEVEL_TABLE
    local expansion = _G.GetAccountExpansionLevel
    local cap = type(byExpansion) == "table" and expansion and tonumber(byExpansion[expansion()])
    return cap or 80
end

-- Wrath grants the first point at 10 and one per level after it.
local function pointCeiling()
    return max(1, levelCap() - 9)
end

local function scrub(text)
    return (text:gsub("[%c|]", ""))
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isContinuation(byte)
    return byte >= 128 and byte < 192
end

-- A cut ending on a non-ASCII byte drops that whole character, even a complete one.
local function cutBytes(text, limit)
    if #text <= limit then return text end
    local kept = text:sub(1, limit)
    local last = kept:byte(limit)
    if last < 128 then return kept end
    local lead = limit
    while lead > 1 and isContinuation(kept:byte(lead)) do
        lead = lead - 1
    end
    if kept:byte(lead) < 128 then lead = lead + 1 end
    return kept:sub(1, lead - 1)
end

ns.LevelCap = levelCap
ns.PointCeiling = pointCeiling
ns.Scrub = scrub
ns.Trim = trim
ns.CutBytes = cutBytes

local LibDeflate = LibStub("LibDeflate")
local Serializer = {}
LibStub("AceSerializer-3.0"):Embed(Serializer)

local function wholeRank(value)
    local n = tonumber(value)
    if not n or n ~= n then return 0 end
    return floor(n)
end

local function digitsOf(treeRanks)
    if type(treeRanks) ~= "table" then return "" end
    local highest = 0
    for index, rank in pairs(treeRanks) do
        if type(index) == "number" and index >= 1 and index <= 255 and wholeRank(rank) >= 1 then
            highest = max(highest, floor(index))
        end
    end
    local out = {}
    for index = 1, highest do
        out[index] = min(9, max(0, wholeRank(treeRanks[index])))
    end
    return concat(out)
end

function TM.EncodeBuildCode(classToken, name, ranks, reqLevel)
    if type(ranks) ~= "table" then ranks = {} end
    local body = {
        v = 1,
        c = classToken,
        n = name,
        l = reqLevel,
        r = { digitsOf(ranks[1]), digitsOf(ranks[2]), digitsOf(ranks[3]) },
    }
    local packed = LibDeflate:CompressDeflate(Serializer:Serialize(body))
    return CODE_TAG .. LibDeflate:EncodeForPrint(packed)
end

local function openPayload(printable)
    local deflated = LibDeflate:DecodeForPrint(printable)
    if not deflated then return nil end
    local serialized = LibDeflate:DecompressDeflate(deflated)
    if not serialized then return nil end
    local ok, value = Serializer:Deserialize(serialized)
    if ok then return value end
    return nil
end

local function readTrees(list)
    local ranks, total = { {}, {}, {} }, 0
    for tree = 1, 3 do
        local digits = list[tree]
        if digits ~= nil then
            if type(digits) ~= "string" or #digits > DIGIT_LIMIT or digits:find("%D") then
                return nil
            end
            local bucket = ranks[tree]
            for index = 1, #digits do
                local rank = digits:byte(index) - 48
                if rank > 0 then
                    bucket[index] = rank
                    total = total + rank
                end
            end
        end
    end
    return ranks, total
end

local function readName(raw)
    local name = type(raw) == "string" and cutBytes(trim(scrub(raw)), NAME_LIMIT) or ""
    if name == "" then
        name = addon.L["Imported"]
    end
    return name
end

local function readLevel(raw)
    local level = tonumber(raw)
    if not level or level ~= level then return nil end
    return min(levelCap(), max(10, floor(level)))
end

function TM.DecodeBuildCode(text)
    if type(text) ~= "string" then return nil end
    local compact = text:gsub("%s+", "")
    if compact:sub(1, #CODE_TAG) ~= CODE_TAG or #compact > CODE_LIMIT then return nil end

    local fine, data = pcall(openPayload, compact:sub(#CODE_TAG + 1))
    if not fine or type(data) ~= "table" or data.v ~= 1 then return nil end
    if type(data.c) ~= "string" or not knownClass[data.c] or type(data.r) ~= "table" then return nil end

    local ranks, total = readTrees(data.r)
    if not ranks or total < 1 or total > pointCeiling() then return nil end

    return {
        class = data.c,
        name = readName(data.n),
        ranks = ranks,
        reqLevel = readLevel(data.l),
    }
end
