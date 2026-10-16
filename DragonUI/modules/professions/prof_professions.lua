-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local Prof = {}
P.Professions = Prof

-- Spell ids checked against the 3.3.5a Spell.dbc and AzerothCore spell_ranks (docs/ports/professions/port.yaml).
Prof.CATALOG = {
    { key = "Alchemy", kind = "primary", ranks = { 2259, 3101, 3464, 11611, 28596, 51304 }, crafts = true },
    { key = "Blacksmithing", kind = "primary", ranks = { 2018, 3100, 3538, 9785, 29844, 51300 }, crafts = true },
    { key = "Enchanting", kind = "primary", ranks = { 7411, 7412, 7413, 13920, 28029, 51313 }, crafts = true, extra = { 13262 } },
    { key = "Engineering", kind = "primary", ranks = { 4036, 4037, 4038, 12656, 30350, 51306 }, crafts = true },
    { key = "Inscription", kind = "primary", ranks = { 45357, 45358, 45359, 45360, 45361, 45363 }, crafts = true, extra = { 51005 } },
    { key = "Jewelcrafting", kind = "primary", ranks = { 25229, 25230, 28894, 28895, 28897, 51311 }, crafts = true, extra = { 31252 } },
    { key = "Leatherworking", kind = "primary", ranks = { 2108, 3104, 3811, 10662, 32549, 51302 }, crafts = true },
    { key = "Tailoring", kind = "primary", ranks = { 3908, 3909, 3910, 12180, 26790, 51309 }, crafts = true },
    { key = "Mining", kind = "primary", ranks = { 2575, 2576, 3564, 10248, 29354, 50310 }, craftSpell = 2656, extra = { 2580 } },
    { key = "Herbalism", kind = "primary", ranks = { 2366, 2368, 3570, 11993, 28695, 50300 }, extra = { 2383 } },
    { key = "Skinning", kind = "primary", ranks = { 8613, 8617, 8618, 10768, 32678, 50305 } },
    { key = "Cooking", kind = "secondary", ranks = { 2550, 3102, 3413, 18260, 33359, 51296 }, crafts = true, extra = { 818 } },
    { key = "FirstAid", kind = "secondary", ranks = { 3273, 3274, 7924, 10846, 27028, 45542 }, crafts = true },
    { key = "Fishing", kind = "secondary", ranks = { 7620, 7731, 7732, 18248, 33095, 51294 }, castsRank = true },
    { key = "Runeforging", kind = "class", ranks = { 53428 }, crafts = true },
    { key = "Poisons", kind = "class", ranks = { 2842 }, crafts = true },
}

local byId = {}
for _, entry in ipairs(Prof.CATALOG) do
    for _, id in ipairs(entry.ranks) do byId[id] = { entry = entry, role = "rank" } end
    if entry.craftSpell then byId[entry.craftSpell] = { entry = entry, role = "craft" } end
    for _, id in ipairs(entry.extra or {}) do byId[id] = { entry = entry, role = "extra" } end
end

local byLine = {}

-- The open window's skill line (GetTradeSkillLine) is the localized name of the profession's first rank spell.
function Prof.EntryForLine(line)
    if not line then return nil end
    if byLine[line] == nil then
        byLine[line] = false
        for _, entry in ipairs(Prof.CATALOG) do
            if GetSpellInfo(entry.ranks[1]) == line then
                byLine[line] = entry
                break
            end
        end
    end
    return byLine[line] or nil
end

function Prof.IconFor(entry)
    return entry and select(3, GetSpellInfo(entry.ranks[1])) or nil
end

local function spellBookIds()
    local found = {}
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local link = GetSpellLink(i, BOOKTYPE_SPELL)
        local id = link and tonumber(link:match("spell:(%d+)"))
        if id then found[id] = i end
        i = i + 1
    end
    return found
end

-- The spellbook slot of a spell by name, its highest rank last; PickupSpell in 3.3.5a takes a slot, not a name.
function Prof.SpellSlot(name)
    local slot
    local i = 1
    while true do
        local found = GetSpellName(i, BOOKTYPE_SPELL)
        if not found then break end
        if found == name then slot = i end
        i = i + 1
    end
    return slot
end

-- Puts a spell on the cursor the way SpellButton_OnDrag does, so it can go on an action bar.
function Prof.PickupSpell(name)
    local slot = name and Prof.SpellSlot(name)
    if slot then PickupSpell(slot, BOOKTYPE_SPELL) end
end

-- Expanding a collapsed skill header shows its lines; it is folded back right after reading.
local function skillLines()
    local lines, refold = {}, {}
    local i = 1
    while i <= GetNumSkillLines() do
        local headerName, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded then
            ExpandSkillHeader(i)
            refold[#refold + 1] = headerName
        end
        local name, header, _, rank, _, modifier, maxRank = GetSkillLineInfo(i)
        lines[#lines + 1] = { name = name, header = header and true or false, rank = rank or 0, modifier = modifier or 0, maxRank = maxRank or 0 }
        i = i + 1
    end
    -- Our own expand/collapse fires SKILL_LINES_CHANGED next frame; listeners skip that echo.
    if #refold > 0 then Prof.echoUntil = GetTime() + 1 end
    for n = #refold, 1, -1 do
        for j = 1, GetNumSkillLines() do
            local name, isHeader = GetSkillLineInfo(j)
            if isHeader and name == refold[n] then
                CollapseSkillHeader(j)
                break
            end
        end
    end
    return lines
end

-- Known professions with their spells and rank; Herbalism's spell is "Herb Gathering", so it is paired by elimination.
function Prof.Discover()
    local ids = spellBookIds()
    local known, list = {}, {}
    for id in pairs(ids) do
        local hit = byId[id]
        if hit then
            local e = hit.entry
            local p = known[e.key]
            if not p then
                p = { key = e.key, kind = e.kind, entry = e, spells = {} }
                known[e.key] = p
                list[#list + 1] = p
            end
            if hit.role == "rank" then
                p.rankSpell = GetSpellInfo(id)
                p.icon = GetSpellTexture(ids[id], BOOKTYPE_SPELL)
            end
            if hit.role == "craft" or (hit.role == "rank" and e.crafts) then p.craftSpell = GetSpellInfo(id) end
            if hit.role == "extra" then p.spells[#p.spells + 1] = GetSpellInfo(id) end
        end
    end
    local byName = {}
    for _, p in pairs(known) do
        p.skillName = GetSpellInfo(p.entry.ranks[1])
        byName[p.skillName] = p
    end
    local header, primaryHeader, unmatched = nil, nil, {}
    for _, line in ipairs(skillLines()) do
        if line.header then
            header = line.name
        else
            local p = byName[line.name]
            if p then
                p.rank, p.maxRank, p.modifier = line.rank, line.maxRank, line.modifier
                if p.kind == "primary" then primaryHeader = header end
            else
                unmatched[#unmatched + 1] = { line = line, header = header }
            end
        end
    end
    for _, p in pairs(known) do
        if p.kind == "primary" and not p.rank then
            for n, u in ipairs(unmatched) do
                if u.header == primaryHeader then
                    p.rank, p.maxRank, p.modifier, p.skillName = u.line.rank, u.line.maxRank, u.line.modifier, u.line.name
                    table.remove(unmatched, n)
                    break
                end
            end
        end
    end
    table.sort(list, function(a, b)
        local order = { primary = 1, secondary = 2, class = 3 }
        if order[a.kind] ~= order[b.kind] then return order[a.kind] < order[b.kind] end
        return a.key < b.key
    end)
    return list
end

-- Professions whose spell opens a crafting window: the side tabs.
function Prof.Tabs(list)
    local tabs = {}
    for _, p in ipairs(list or Prof.Discover()) do
        if p.craftSpell then tabs[#tabs + 1] = p end
    end
    return tabs
end

-- Secure catchers ---------------------------------------------------------------------------------

-- On UIParent: a secure child of TradeSkillFrame would protect it and break opening First Aid in combat.
local Catchers = { pool = {}, bound = {} }
Prof.Catchers = Catchers

local function call(self, key, ...)
    local bind = Catchers.bound[self:GetID()]
    if bind and bind[key] then bind[key](self, ...) end
end

local function catcher(i)
    local b = Catchers.pool[i]
    if b then return b end
    b = CreateFrame("Button", "DragonUI_ProfessionsCatcher" .. i, UIParent, "SecureActionButtonTemplate")
    b:SetAttribute("type", "spell")
    b:RegisterForClicks("LeftButtonUp")
    b:Hide()
    b:SetScript("OnEnter", function(self) call(self, "onEnter") end)
    b:SetScript("OnLeave", function(self)
        call(self, "onLeave")
        if not InCombatLockdown() then self:Hide() end
    end)
    b:SetScript("OnMouseDown", function(self, button) call(self, "onDown", button) end)
    b:SetScript("OnMouseUp", function(self, button) call(self, "onUp", button) end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) call(self, "onDrag") end)
    b:SetID(i)
    Catchers.pool[i] = b
    return b
end

-- handlers: onEnter, onLeave, onDown, onUp, onDrag, all optional, called with the catcher. Binding never shows it.
function Catchers.Bind(i, owner, spell, handlers, attributes)
    if InCombatLockdown() then return false end
    handlers = handlers or {}
    Catchers.bound[i] = { owner = owner, spell = spell, onEnter = handlers.onEnter, onLeave = handlers.onLeave,
                          onDown = handlers.onDown, onUp = handlers.onUp, onDrag = handlers.onDrag }
    local b = catcher(i)
    b:SetAttribute("spell", spell)
    for key, value in pairs(attributes or {}) do b:SetAttribute(key, value) end
    return true
end

-- The hide below fires OnLeave after the binding is gone, so the owner hears it here first.
function Catchers.Unbind(i)
    local bind = Catchers.bound[i]
    Catchers.bound[i] = nil
    local b = Catchers.pool[i]
    if bind and bind.onLeave then bind.onLeave(b) end
    if b and not InCombatLockdown() then b:Hide() end
end

-- HIGH, because UIPanel updates re-raise TradeSkillFrame above any level a MEDIUM frame could hold.
function Catchers.Arm(i)
    local bind, b = Catchers.bound[i], Catchers.pool[i]
    if not (bind and b) or InCombatLockdown() then return end
    local owner = bind.owner
    local x, y
    if owner:IsVisible() then x, y = owner:GetCenter() end
    if not x then return end
    local ratio = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
    b:SetSize(owner:GetWidth() * ratio, owner:GetHeight() * ratio)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(1)
    b:Show()
end

-- Owners call this from OnEnter: a catcher exists on screen only under the cursor, over an owner nothing covers.
function Catchers.ArmFor(owner)
    for i, bind in pairs(Catchers.bound) do
        if bind.owner == owner then
            Catchers.Arm(i)
            return true
        end
    end
end

function Catchers.HideAll()
    if InCombatLockdown() then return end
    for _, b in pairs(Catchers.pool) do b:Hide() end
end

-- The lock is not on yet during PLAYER_REGEN_DISABLED, so the catchers can still be hidden then.
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", function()
    for _, b in pairs(Catchers.pool) do b:Hide() end
end)

function Prof.IsEcho()
    return Prof.echoUntil and GetTime() < Prof.echoUntil
end

-- Skill index for AbandonSkill as the list stands now; a collapsed header is opened and left open.
function Prof.SkillIndex(skillName)
    local i = 1
    while i <= GetNumSkillLines() do
        local name, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded then ExpandSkillHeader(i) end
        if not isHeader and name == skillName then return i end
        i = i + 1
    end
end

-- The professions in the spellbook, keyed by catalog key; unlike Discover it leaves the skill headers alone.
function Prof.KnownKeys()
    local keys = {}
    for id in pairs(spellBookIds()) do
        local hit = byId[id]
        if hit then keys[hit.entry.key] = true end
    end
    return keys
end
