local addon = select(2, ...)

local _G = _G
local type, tostring, tonumber, pcall, pairs, ipairs = type, tostring, tonumber, pcall, pairs, ipairs
local strfind, strlower, strmatch, strsub = string.find, string.lower, string.match, string.sub
local GetItemInfo = GetItemInfo

local SCANNER_NAME = "DragonUI_BagsterSearchScanner"
local PLAN_CACHE_LIMIT = 64

local BagsterItemSearch = {}
addon.BagsterItemSearch = BagsterItemSearch

local BIND_GLOBAL_BY_KEYWORD = {
    boe = "ITEM_BIND_ON_EQUIP",
    bop = "ITEM_BIND_ON_PICKUP",
    bou = "ITEM_BIND_ON_USE",
    quest = "ITEM_BIND_QUEST",
    boa = "ITEM_BIND_TO_BNETACCOUNT",
}

local function IsEqual(a, b) return a == b end
local function IsNotEqual(a, b) return a ~= b end

local COMPARE_BY_OPERATOR = {
    [":"] = IsEqual, ["="] = IsEqual, ["=="] = IsEqual,
    ["!="] = IsNotEqual, ["~="] = IsNotEqual,
    ["<"] = function(a, b) return a < b end,
    ["<="] = function(a, b) return a <= b end,
    [">"] = function(a, b) return a > b end,
    [">="] = function(a, b) return a >= b end,
}

-- User text is a live Lua pattern; a malformed one ("(", "[") must read as no match, never an error.
local function PatternHits(text, pattern)
    local ok, start = pcall(strfind, text, pattern)
    return ok and start ~= nil
end

local function TextFits(value, pattern)
    if value == nil then return false end
    local text = strlower(tostring(value))
    return text == pattern or PatternHits(text, pattern)
end

local function ItemIDOf(link)
    return strmatch(link, "item:(%d+)")
end

local scanner

local function ScanLink(link)
    if not scanner then
        scanner = CreateFrame("GameTooltip", SCANNER_NAME, UIParent, "GameTooltipTemplate")
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:SetHyperlink(link)
    return scanner:NumLines() or 0
end

local function ScannedLine(index)
    local fontString = _G[SCANNER_NAME .. "TextLeft" .. index]
    return fontString and fontString:GetText()
end

local function CategoryFits(pattern, class, subclass, equipLoc)
    if TextFits(class, pattern) or TextFits(subclass, pattern) then return true end
    if equipLoc == nil or equipLoc == "" then return false end
    return TextFits(_G[equipLoc], pattern)
end

local function MatchName(link, pattern)
    return TextFits((GetItemInfo(link)), pattern)
end

local function MatchType(link, pattern)
    local name, _, _, _, _, class, subclass, _, equipLoc = GetItemInfo(link)
    if name == nil then return false end
    return CategoryFits(pattern, class, subclass, equipLoc)
end

local function MatchPlain(link, pattern)
    local name, _, _, _, _, class, subclass, _, equipLoc = GetItemInfo(link)
    if name == nil then return false end
    return CategoryFits(pattern, class, subclass, equipLoc) or TextFits(name, pattern)
end

local function MatchQuality(link, compare, wanted)
    if not compare or not wanted then return false end
    local _, _, quality = GetItemInfo(link)
    if quality == nil then return false end
    return compare(quality, wanted)
end

local function MatchItemLevel(link, compare, wanted)
    if not compare then return false end
    local _, _, _, level = GetItemInfo(link)
    if level == nil then return false end
    return compare(level, wanted)
end

local function MatchBindLine(link, bindText, memo)
    local id = ItemIDOf(link)
    local known = id and memo[id]
    if known ~= nil then return known end
    local count = ScanLink(link)
    -- Heroic items carry an extra "Heroic" line that pushes the bind text down to line 3.
    local hit = (count >= 2 and ScannedLine(2) == bindText) or (count >= 3 and ScannedLine(3) == bindText)
    scanner:Hide()
    if id then memo[id] = hit end
    return hit
end

local function MatchTooltip(link, pattern)
    local count = ScanLink(link)
    local hit = false
    for index = 1, count do
        local text = ScannedLine(index)
        if text and PatternHits(strlower(text), pattern) then
            hit = true
            break
        end
    end
    scanner:Hide()
    return hit
end

local function WardrobeOutfits()
    local wardrobe = _G.Wardrobe
    local config = type(wardrobe) == "table" and wardrobe.CurrentConfig
    local outfits = type(config) == "table" and config.Outfit
    if type(outfits) == "table" then return outfits end
end

local function NameRank(name, wanted, prefixPattern)
    if type(name) ~= "string" then return nil end
    local lowered = strlower(name)
    if lowered == wanted then return "exact" end
    if PatternHits(lowered, prefixPattern) then return "prefix" end
end

local function ResolveSetName(wanted, prefixPattern)
    local fallback
    local total = GetNumEquipmentSets and GetNumEquipmentSets() or 0
    for index = 1, total do
        local name = GetEquipmentSetInfo(index)
        local rank = NameRank(name, wanted, prefixPattern)
        if rank == "exact" then return name end
        if rank == "prefix" then fallback = name end
    end
    local outfits = WardrobeOutfits()
    if outfits then
        for _, outfit in ipairs(outfits) do
            local name = type(outfit) == "table" and outfit.OutfitName or nil
            local rank = NameRank(name, wanted, prefixPattern)
            if rank == "exact" then return name end
            if rank == "prefix" then fallback = name end
        end
    end
    return fallback
end

local function InEquipmentSet(setName, itemID)
    if not itemID or not GetEquipmentSetItemIDs then return false end
    local ok, ids = pcall(GetEquipmentSetItemIDs, setName)
    if not ok or type(ids) ~= "table" then return false end
    for _, id in pairs(ids) do
        if id == itemID then return true end
    end
    return false
end

local function InWardrobeOutfit(setName, link)
    local outfits = WardrobeOutfits()
    if not outfits then return false end
    local itemName = GetItemInfo(link)
    if itemName == nil then return false end
    for _, outfit in ipairs(outfits) do
        local slots = type(outfit) == "table" and outfit.OutfitName == setName and outfit.Item
        if type(slots) == "table" then
            for _, slot in pairs(slots) do
                if type(slot) == "table" and slot.IsSlotUsed == 1 and slot.Name == itemName then
                    return true
                end
            end
        end
    end
    return false
end

local function MatchEquipmentSet(link, wanted, prefixPattern)
    local setName = ResolveSetName(wanted, prefixPattern)
    if not setName then return false end
    return InEquipmentSet(setName, tonumber(ItemIDOf(link))) or InWardrobeOutfit(setName, link)
end

local function AfterPrefix(term, prefix)
    local size = #prefix
    if #term > size and strsub(term, 1, size) == prefix then
        return strsub(term, size + 1)
    end
end

local function QualityNumber(word)
    local number = tonumber(word)
    if number then return number end
    local index = 0
    local label = _G.ITEM_QUALITY0_DESC
    while label ~= nil do
        if strlower(label) == word then return index end
        index = index + 1
        label = _G["ITEM_QUALITY" .. index .. "_DESC"]
    end
end

local bindMemos = {}

local function BindMemo(text)
    local memo = bindMemos[text]
    if not memo then
        memo = {}
        bindMemos[text] = memo
    end
    return memo
end

local function Classify(term)
    local rest = AfterPrefix(term, "n:")
    if rest then return MatchName, rest end
    rest = AfterPrefix(term, "t:")
    if rest then return MatchType, rest end
    rest = AfterPrefix(term, "tt:")
    if rest then return MatchTooltip, rest end
    rest = AfterPrefix(term, "s:")
    if rest then return MatchEquipmentSet, rest, "^" .. rest end
    local operator, value = strmatch(term, "^q([~:<>=!]+)(%w+)$")
    if operator then return MatchQuality, COMPARE_BY_OPERATOR[operator], QualityNumber(value) end
    operator, value = strmatch(term, "^ilvl([:<>=!]+)(%d+)$")
    if operator then return MatchItemLevel, COMPARE_BY_OPERATOR[operator], tonumber(value) end
    local globalName = BIND_GLOBAL_BY_KEYWORD[term]
    local bindText = globalName and _G[globalName]
    if bindText ~= nil then return MatchBindLine, bindText, BindMemo(bindText) end
    return MatchPlain, term
end

local function SplitSkippingEmpty(text, separator)
    local pieces, from = {}, 1
    local limit = #text + 1
    while from <= limit do
        local stop = strfind(text, separator, from, true) or limit
        if stop > from then pieces[#pieces + 1] = strsub(text, from, stop - 1) end
        from = stop + 1
    end
    return pieces
end

local function Compile(query)
    local plan = {}
    for _, alternative in ipairs(SplitSkippingEmpty(strlower(query), "|")) do
        local steps = {}
        for _, term in ipairs(SplitSkippingEmpty(alternative, "&")) do
            local negated = #term > 1 and strsub(term, 1, 1) == "!"
            if negated then term = strsub(term, 2) end
            local rule, first, second = Classify(term)
            steps[#steps + 1] = { rule = rule, first = first, second = second, negated = negated }
        end
        plan[#plan + 1] = steps
    end
    return plan
end

local plans, planCount = {}, 0

local function PlanFor(query)
    local plan = plans[query]
    if plan then return plan end
    if planCount >= PLAN_CACHE_LIMIT then
        plans, planCount = {}, 0
    end
    plan = Compile(query)
    plans[query] = plan
    planCount = planCount + 1
    return plan
end

local function AlternativeHolds(steps, link)
    for i = 1, #steps do
        local step = steps[i]
        local hit = step.rule(link, step.first, step.second)
        if step.negated then hit = not hit end
        if not hit then return false end
    end
    return true
end

function BagsterItemSearch:Find(link, query)
    if query == nil then return true end
    if link == nil then return false end
    local plan = PlanFor(query)
    for i = 1, #plan do
        if AlternativeHolds(plan[i], link) then return true end
    end
    return false
end
