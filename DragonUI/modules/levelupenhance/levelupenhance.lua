-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- =============================================================================
-- Level Up Enhance
-- Level-up banner listing everything the new level unlocks, as retail's Level Up Display does.
-- =============================================================================

local addon = select(2, ...)
local L = addon.L

local band = bit.band
local floor, min, max = math.floor, math.min, math.max
local format = string.format

local LevelUpEnhance = { initialized = false, applied = false }

if addon.RegisterModule then
    addon:RegisterModule("levelupenhance", LevelUpEnhance,
        L["Level Up Enhance"],
        L["Enhanced level-up notification with animated frame"],
        { lifecyclePrefix = "LevelUpEnhance" })
end

local EMPTY = {}

-- =============================================================================
-- ART AND LAYOUT
-- =============================================================================

local TEXTURE = addon._dir .. "NewLevelUp\\levelup"
local FONT = addon.Fonts.PRIMARY

-- Regions of Blizzard's LevelUpTex sheet (512x512).
local BADGE_BOOK = { 0.64257813, 0.72070313, 0.03710938, 0.11132813 }
local BADGE_LOCK = { 0.64257813, 0.70117188, 0.11523438, 0.18359375 }
local BADGE_ARROW = { 0.72460938, 0.78320313, 0.03710938, 0.10351563 }
local DOT = { 0.64257813, 0.68359375, 0.18750000, 0.23046875 }
local LINE_LEFT, LINE_RIGHT, LINE_TOP, LINE_BOTTOM = 0.00195313, 0.81835938, 0.01953125, 0.03320313
local BACK_LEFT, BACK_RIGHT, BACK_TOP, BACK_BOTTOM = 0.00195313, 0.55859375, 0.24609375, 0.38671875
local LINE_CENTER, LINE_HALF = (LINE_LEFT + LINE_RIGHT) / 2, (LINE_RIGHT - LINE_LEFT) / 2
local BACK_CENTER, BACK_HALF = (BACK_LEFT + BACK_RIGHT) / 2, (BACK_RIGHT - BACK_LEFT) / 2

local WIDTH, HEIGHT, LINE_HEIGHT = 326, 72, 7
local ICON_SIZE, ROW_HEIGHT, TEXT_GAP = 34, 42, 12
-- 8 rows hold 89% of level-ups whole; the rest fold by kind (Condense), so the list never scrolls.
local MAX_TEXT_WIDTH, MIN_ROWS, MAX_ROWS = 245, 4, 8
local LIST_TOP, LIST_BOTTOM = 8, 6
local SCREEN_MARGIN = 140
local TITLE_SIZE, TITLE_MIN, SUB_SIZE, SUB_MIN = 14, 9, 11, 8

local TIME_EXPAND, TIME_TEXT_IN, TIME_FADE = 1.75, 1.85, 0.35
local HOLD_COLLAPSED, HOLD_LIST, HOLD_PER_ROW, HOLD_LIST_MAX = 4, 4, 1, 10
local CHAT_DELAY = 0.5

local COLOR_TITLE = { 0.96, 0.82, 0.45 }
local COLOR_SUB = { 0.12, 0.95, 0.12 }
local COLOR_SUB_PLACE = { 0.25, 0.78, 0.92 }

-- =============================================================================
-- UNLOCK DEFINITIONS
-- =============================================================================

local ICON_TALENTS = "Interface\\Icons\\Ability_Marksmanship"
local ICON_BATTLEGROUNDS = "Interface\\Icons\\Ability_DualWield"
local ICON_DUNGEON_FINDER = "Interface\\Icons\\INV_Helmet_08"
local ICON_GLYPHS = "Interface\\Icons\\INV_Inscription_Tradeskill01"
local ICON_DUAL_SPEC = "Interface\\Icons\\INV_Misc_Coin_01"
local ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_DUNGEON = "Interface\\LFGFrame\\LFGIcon-Dungeon"
local ICON_RAID = "Interface\\LFGFrame\\LFGIcon-Raid"
local LFG_ICON = "Interface\\LFGFrame\\LFGIcon-"
local HEROIC_ICONS = {
    "Interface\\Icons\\Achievement_Zone_Outland_01",
    "Interface\\Icons\\Achievement_Zone_Northrend_01",
}

local FEATURES = {
    [10] = { { TALENT_POINTS, ICON_TALENTS }, { BATTLEGROUNDS, ICON_BATTLEGROUNDS } },
    [15] = { { LOOKING_FOR_DUNGEON, ICON_DUNGEON_FINDER }, { GLYPHS, ICON_GLYPHS } },
    [40] = { { L["Dual Talent Specialization"], ICON_DUAL_SPEC } },
}
local FIRST_TALENT_LEVEL = 10
-- Sockets opened after the two at 15 (Player::InitGlyphsForLevel), typed by GlyphSlot.dbc.
local GLYPH_SLOT_AT = {
    [30] = L["Major Glyph Slot"], [50] = L["Minor Glyph Slot"], [70] = L["Minor Glyph Slot"], [80] = L["Major Glyph Slot"],
}
-- Plate Mail and Mail: retail lists armor skills as features, not abilities.
local FEATURE_SPELLS = { [750] = true, [8737] = true }

local SUBTEXT = {
    feature = L["Feature Unlocked!"],
    talent = L["Ready to Spend!"],
    spell = L["New Ability!"],
    rank = L["New Rank!"],
    battleground = L["New Battleground!"],
    dungeon = L["New Dungeon!"],
    raid = L["New Raid!"],
    heroic = L["Heroic Dungeons!"],
}
local BADGE = { spell = BADGE_BOOK, rank = BADGE_BOOK, talent = BADGE_ARROW }
local PLACE = { battleground = true, dungeon = true, raid = true, heroic = true }

local CHAT_PREFIX = {
    feature = L["New feature unlocked:"],
    spell = L["New ability available:"],
    rank = L["New ability available:"],
    battleground = L["New battleground unlocked:"],
    dungeon = L["New dungeon unlocked:"],
    raid = L["New raid unlocked:"],
    heroic = L["New heroic dungeons unlocked:"],
}

local HINT_TRAINER = L["Learn it from your class trainer."]
local HINT_QUEST = L["Learned from a class quest."]
local HINT_RIDING = L["Learn it from a riding trainer."]

-- =============================================================================
-- SETTINGS
-- =============================================================================

local function Setting(key)
    local cfg = addon.db and addon.db.profile and addon.db.profile.levelupenhance
    local value = cfg and cfg[key]
    if value == nil then
        local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.levelupenhance
        value = defaults and defaults[key]
    end
    return value
end

-- =============================================================================
-- UNLOCK LIST
-- =============================================================================

local function RaceAllows(mask, raceBit)
    return mask == 0 or band(mask, raceBit) ~= 0
end

-- Learning a rank can drop the lower ones from the book, so a known higher rank counts too.
local function KnownInChain(index, spellID, memo)
    local answer = memo[spellID]
    if answer ~= nil then return answer end
    memo[spellID] = false
    answer = IsSpellKnown(spellID) and true or false
    if not answer then
        for _, record in ipairs(index.after[spellID] or EMPTY) do
            if KnownInChain(index, record[2], memo) then
                answer = true
                break
            end
        end
    end
    memo[spellID] = answer
    return answer
end

local function SpellEntry(spellID, kind, hint)
    local name, rank, icon = GetSpellInfo(spellID)
    if not name then return nil end
    local text = name
    if kind == "rank" and rank and rank ~= "" then
        text = format("%s |cffb3b3b3(%s)|r", name, rank)
    end
    return { kind = kind, text = text, name = name, icon = icon or ICON_UNKNOWN, spellID = spellID, hint = hint }
end

local function Add(list, entry)
    if entry then list[#list + 1] = entry end
end

local function AddFeatures(out, from, to)
    for level = from, to do
        for _, feature in ipairs(FEATURES[level] or EMPTY) do
            Add(out, { kind = "feature", text = feature[1], icon = feature[2] })
        end
        if GLYPH_SLOT_AT[level] then
            Add(out, { kind = "feature", text = GLYPH_SLOT_AT[level], icon = ICON_GLYPHS })
        end
    end
end

local function AddRiding(out, data, from, to)
    for _, row in ipairs(data.riding or EMPTY) do
        if row[1] >= from and row[1] <= to and not IsSpellKnown(row[2]) then
            Add(out, SpellEntry(row[2], "feature", HINT_RIDING))
        end
    end
end

local function SpellSort(a, b)
    if (a.kind == "rank") ~= (b.kind == "rank") then return b.kind == "rank" end
    return a.text < b.text
end

local function AddClassSpells(features, spells, data, from, to)
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local Book = addon.SpellbookModule
    local raceBit = Book and Book.RaceBit and Book.RaceBit(race) or 0
    local index = Book and Book.TrainerIndex and class and Book.TrainerIndex(class)
    local seen = {}

    if index then
        local memo = {}
        for _, record in ipairs(index.list) do
            local level, spellID, previous, talent = record[1], record[2], record[4], record[5]
            if level >= from and level <= to and not seen[spellID] and RaceAllows(record[6], raceBit)
                and not IsSpellKnown(spellID)
                and (talent == 0 or KnownInChain(index, talent, memo)
                    or (previous ~= 0 and KnownInChain(index, previous, memo))) then
                seen[spellID] = true
                if FEATURE_SPELLS[spellID] then
                    Add(features, SpellEntry(spellID, "feature", HINT_TRAINER))
                else
                    Add(spells, SpellEntry(spellID, previous ~= 0 and "rank" or "spell", HINT_TRAINER))
                end
            end
        end
    end

    for _, row in ipairs(data.questSpells and data.questSpells[class] or EMPTY) do
        local spellID = row[2]
        if row[1] >= from and row[1] <= to and not seen[spellID] and RaceAllows(row[3], raceBit)
            and not IsSpellKnown(spellID) then
            seen[spellID] = true
            Add(spells, SpellEntry(spellID, "spell", HINT_QUEST))
        end
    end
    table.sort(spells, SpellSort)
end

local function BattlegroundNames()
    local names = {}
    for i = 1, GetNumBattlegroundTypes() do
        local name, _, _, _, id = GetBattlegroundInfo(i)
        if name and id then names[id] = name end
    end
    return names
end

local function FirstBattlegroundLevel(data)
    local first
    for _, row in ipairs(data.battlegrounds or EMPTY) do
        if not first or row[1] < first then first = row[1] end
    end
    return first
end

local function AddBattlegrounds(out, data, from, to)
    -- The first battleground is the "Battlegrounds" feature itself.
    local first, names = FirstBattlegroundLevel(data)
    for _, row in ipairs(data.battlegrounds or EMPTY) do
        if row[1] >= from and row[1] <= to and row[1] ~= first then
            names = names or BattlegroundNames()
            Add(out, { kind = "battleground", text = names[row[2]] or row[4], icon = "Interface\\Icons\\" .. row[3] })
        end
    end
end

local function LevelRangeHint(id)
    local _, _, minLevel, maxLevel = GetLFGDungeonInfo(id)
    if minLevel and maxLevel then
        return format("%s: %d-%d", LEVEL_RANGE, minLevel, maxLevel)
    end
end

local function AddInstances(dungeons, heroics, raids, data, from, to)
    local faction = UnitFactionGroup("player") == "Horde" and 0 or 1
    for _, row in ipairs(data.dungeons or EMPTY) do
        if row[1] >= from and row[1] <= to and (row[3] == -1 or row[3] == faction) then
            Add(dungeons, { kind = "dungeon", text = GetLFGDungeonInfo(row[2]) or row[5], hint = LevelRangeHint(row[2]),
                icon = row[4] and (LFG_ICON .. row[4]) or ICON_DUNGEON })
        end
    end
    for _, row in ipairs(data.heroics or EMPTY) do
        local name = _G["EXPANSION_NAME" .. row[2]]
        if row[1] >= from and row[1] <= to and name then
            Add(heroics, { kind = "heroic", text = name, icon = HEROIC_ICONS[row[2]] or ICON_DUNGEON })
        end
    end
    for _, row in ipairs(data.raids or EMPTY) do
        if row[1] >= from and row[1] <= to then
            Add(raids, { kind = "raid", text = GetLFGDungeonInfo(row[2]) or row[4], hint = LevelRangeHint(row[2]),
                icon = row[3] and (LFG_ICON .. row[3]) or ICON_RAID })
        end
    end
end

local function Append(out, list)
    for i = 1, #list do out[#out + 1] = list[i] end
end

-- Every level in from..to; talentPoints is what PLAYER_LEVEL_UP reported for them.
local function BuildCharacterUnlocks(from, to, talentPoints)
    local data = addon.LevelUpData or EMPTY
    local features, talents, spells, battlegrounds = {}, {}, {}, {}
    local dungeons, heroics, raids = {}, {}, {}

    AddFeatures(features, from, to)
    AddRiding(features, data, from, to)
    -- At 10 the first point is the "Talent Points" feature itself.
    if talentPoints and talentPoints > 0 and not (from == FIRST_TALENT_LEVEL and to == FIRST_TALENT_LEVEL) then
        Add(talents, { kind = "talent", icon = ICON_TALENTS,
            text = talentPoints == 1 and L["Talent Point"] or format(L["%d Talent Points"], talentPoints) })
    end
    AddClassSpells(features, spells, data, from, to)
    AddBattlegrounds(battlegrounds, data, from, to)
    AddInstances(dungeons, heroics, raids, data, from, to)

    local out = {}
    Append(out, features)
    Append(out, talents)
    Append(out, spells)
    Append(out, battlegrounds)
    Append(out, dungeons)
    Append(out, heroics)
    Append(out, raids)
    return out
end

-- Hunter pets get their first talent point at 20 and one more every 4 levels (Pet::GetMaxTalentPointsForLevel).
local function BuildPetUnlocks(level)
    local out = {}
    if level >= 20 and (level - 16) % 4 == 0 then
        Add(out, { kind = "talent", text = L["Pet Talent Point"], icon = ICON_TALENTS })
    end
    return out
end

-- Retail never scrolls this list, so kinds that overflow it (Wrath's ranks, raid tiers) fold into one row.
local FOLD_ORDER = { "rank", "raid", "dungeon", "battleground", "spell" }
local FOLD_SUBTEXT = {
    rank = L["%d New Ranks!"],
    raid = L["%d New Raids!"],
    dungeon = L["%d New Dungeons!"],
    battleground = L["%d New Battlegrounds!"],
    spell = L["%d New Abilities!"],
}

local function Condense(list, maxRows)
    local out = list
    for _, kind in ipairs(FOLD_ORDER) do
        if #out <= maxRows then break end
        local folded, group = {}, nil
        for _, entry in ipairs(out) do
            if entry.kind == kind then
                if not group then
                    group = { kind = "group", of = kind, items = {}, icon = entry.icon }
                    folded[#folded + 1] = group
                end
                group.items[#group.items + 1] = entry
            else
                folded[#folded + 1] = entry
            end
        end
        if group and #group.items > 1 then
            group.sub = format(FOLD_SUBTEXT[kind], #group.items)
            out = folded
        end
    end
    return out
end

LevelUpEnhance.BuildCharacterUnlocks = BuildCharacterUnlocks
LevelUpEnhance.BuildPetUnlocks = BuildPetUnlocks
LevelUpEnhance.Condense = Condense

-- =============================================================================
-- CHAT
-- =============================================================================

local function ChatFrames()
    local frames = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and frame:IsEventRegistered("PLAYER_LEVEL_UP") then frames[#frames + 1] = frame end
    end
    if #frames == 0 and DEFAULT_CHAT_FRAME then frames[1] = DEFAULT_CHAT_FRAME end
    return frames
end

local function ChatLine(entry)
    local prefix = CHAT_PREFIX[entry.kind]
    if not prefix then return nil end
    local link
    if entry.spellID then
        link = GetSpellLink(entry.spellID)
        local _, rank = GetSpellInfo(entry.spellID)
        if link and entry.kind == "rank" and rank and rank ~= "" then
            link = link .. " |cffb3b3b3(" .. rank .. ")|r"
        end
    end
    if not link then
        link = (PLACE[entry.kind] and "|cff00ccff[" or "|cffff4040[") .. entry.text .. "]|r"
    end
    return prefix .. " " .. link
end

-- Mirrors the client's own level-up lines: same windows, system color, after them.
local function PrintToChat(header, entries)
    local lines = {}
    if header then lines[1] = header end
    for _, entry in ipairs(entries) do
        local line = ChatLine(entry)
        if line then lines[#lines + 1] = line end
    end
    if #lines == 0 then return end
    addon:After(CHAT_DELAY, function()
        local info = ChatTypeInfo["SYSTEM"]
        for _, frame in ipairs(ChatFrames()) do
            for _, line in ipairs(lines) do
                frame:AddMessage(line, info.r, info.g, info.b, info.id)
            end
        end
    end)
end

-- =============================================================================
-- BANNER
-- =============================================================================

local anchor, banner
local rows = {}
local measure
local current
local entries = EMPTY
local expanded = false
local animState, stateTimer = "IDLE", 0
local queuedPet

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive()
end

local function EntryColor(entry)
    return PLACE[entry.of or entry.kind] and COLOR_SUB_PLACE or COLOR_SUB
end

local function FitText(text, startSize, minSize)
    local size = startSize
    measure:SetFont(FONT, size, "OUTLINE")
    measure:SetText(text)
    while measure:GetStringWidth() > MAX_TEXT_WIDTH and size > minSize do
        size = size - 1
        measure:SetFont(FONT, size, "OUTLINE")
    end
    return size, measure:GetStringWidth()
end

local function GroupTitle(group)
    local items, n = group.items, #group.items
    measure:SetFont(FONT, TITLE_MIN + 3, "OUTLINE")
    for shown = n, 1, -1 do
        local names = {}
        for i = 1, shown do names[i] = items[i].name or items[i].text end
        local text = table.concat(names, ", ")
        if shown < n then text = format("%s, +%d", text, n - shown) end
        measure:SetText(text)
        if shown == 1 or measure:GetStringWidth() <= MAX_TEXT_WIDTH then return text end
    end
end

local function MeasureEntries(list)
    if not measure then
        measure = UIParent:CreateFontString(nil, "ARTWORK")
        measure:Hide()
    end
    local widest = 0
    for _, entry in ipairs(list) do
        if entry.items then entry.text = GroupTitle(entry) end
        local width, subWidth
        entry.titleSize, width = FitText(entry.text, TITLE_SIZE, TITLE_MIN)
        entry.sub = entry.sub or SUBTEXT[entry.kind] or SUBTEXT.feature
        entry.subSize, subWidth = FitText(entry.sub, SUB_SIZE, SUB_MIN)
        widest = max(widest, width, subWidth)
    end
    return widest
end

local function RowEnter(self)
    local entry = self.entry
    if not entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if entry.items then
        GameTooltip:SetText(entry.sub, 1, 1, 1)
        for _, item in ipairs(entry.items) do
            GameTooltip:AddLine(format("|T%s:16|t %s", item.icon, item.text), COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        end
    elseif entry.spellID then
        GameTooltip:SetHyperlink("spell:" .. entry.spellID)
    else
        GameTooltip:SetText(entry.text, 1, 1, 1)
    end
    if entry.hint then
        GameTooltip:AddLine(entry.hint, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    end
    GameTooltip:Show()
end

local function RowClick(self)
    local entry = self.entry
    if entry and entry.spellID and IsModifiedClick("CHATLINK") then
        local link = GetSpellLink(entry.spellID)
        if link then ChatEdit_InsertLink(link) end
    end
end

local function CreateRow()
    local row = CreateFrame("Button", nil, banner.list)
    row:SetSize(WIDTH, ROW_HEIGHT)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", RowClick)

    local iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    iconFrame:SetBackdropBorderColor(0.12, 0.12, 0.12, 0.95)
    row.iconFrame = iconFrame

    row.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.badge = iconFrame:CreateTexture(nil, "OVERLAY")
    row.badge:SetSize(16, 18)
    row.badge:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", -5, -4)
    row.badge:SetTexture(TEXTURE)

    row.sub = row:CreateFontString(nil, "ARTWORK")
    row.sub:SetWordWrap(false)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetPoint("LEFT", iconFrame, "RIGHT", TEXT_GAP, 7)

    row.title = row:CreateFontString(nil, "ARTWORK")
    row.title:SetWordWrap(false)
    row.title:SetJustifyH("LEFT")
    row.title:SetPoint("LEFT", iconFrame, "RIGHT", TEXT_GAP, -7)
    row.title:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    return row
end

local function RowsThatFit()
    local bottom = banner:GetBottom()
    if not bottom then return MAX_ROWS end
    local fit = floor((bottom - SCREEN_MARGIN - LIST_TOP - LIST_BOTTOM) / ROW_HEIGHT)
    return min(MAX_ROWS, max(MIN_ROWS, fit))
end

local function DisplayList()
    local fit = RowsThatFit()
    if entries.fit ~= fit then
        entries.fit = fit
        entries.display = Condense(entries, fit)
        entries.widest = MeasureEntries(entries.display)
    end
    return entries.display
end

local function RefreshList()
    local list = banner.list
    if not expanded or #entries == 0 then
        list:Hide()
        return
    end

    local display = DisplayList()
    local left = max(12, floor((WIDTH - (ICON_SIZE + TEXT_GAP + entries.widest)) / 2))
    for i, entry in ipairs(display) do
        local row = rows[i] or CreateRow()
        rows[i] = row
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -LIST_TOP - (i - 1) * ROW_HEIGHT)
        row.iconFrame:ClearAllPoints()
        row.iconFrame:SetPoint("LEFT", row, "LEFT", left, 0)
        row.icon:SetTexture(entry.icon)
        row.badge:SetTexCoord(unpack(BADGE[entry.of or entry.kind] or BADGE_LOCK))

        local color = EntryColor(entry)
        row.sub:SetFont(FONT, entry.subSize, "OUTLINE")
        row.sub:SetText(entry.sub)
        row.sub:SetTextColor(color[1], color[2], color[3])
        row.title:SetFont(FONT, entry.titleSize, "OUTLINE")
        row.title:SetText(entry.text)
        row:Show()
    end
    for i = #display + 1, #rows do
        rows[i].entry = nil
        rows[i]:Hide()
    end
    list:SetHeight(LIST_TOP + #display * ROW_HEIGHT + LIST_BOTTOM)
    list:Show()
end

local function SetExpanded(value)
    expanded = value and #entries > 0
    if expanded then
        banner.toggle.dot:SetVertexColor(1, 1, 1, 1)
    else
        banner.toggle.dot:SetVertexColor(0.92, 0.92, 0.92, 0.85)
    end
    RefreshList()
end

local function HoldTime()
    if not expanded then return HOLD_COLLAPSED end
    return min(HOLD_LIST + HOLD_PER_ROW * #(entries.display or entries), HOLD_LIST_MAX)
end

local function IsHovered()
    -- Mouselook freezes the hidden cursor where it was, which could hold the banner up for good.
    if IsMouselooking() then return false end
    return (banner.list:IsVisible() and banner.list:IsMouseOver())
        or (banner.toggle:IsVisible() and banner.toggle:IsMouseOver())
end

local function SetRevealed(progress)
    local width = max(2, WIDTH * progress)
    banner:SetWidth(width)
    local back = BACK_HALF * progress
    banner.art:SetTexCoord(BACK_CENTER - back, BACK_CENTER + back, BACK_TOP, BACK_BOTTOM)
    local line = LINE_HALF * progress
    for _, texture in ipairs(banner.lines) do
        texture:SetWidth(width)
        texture:SetTexCoord(LINE_CENTER - line, LINE_CENTER + line, LINE_TOP, LINE_BOTTOM)
    end
end

local ShowNext

local function Finish()
    animState, stateTimer = "IDLE", 0
    current, entries = nil, EMPTY
    expanded = false
    if banner then
        banner:SetScript("OnUpdate", nil)
        banner.list:Hide()
        banner.toggle:Hide()
        banner:Hide()
    end
end

local function EnterHold()
    animState, stateTimer = "HOLD", 0
    SetRevealed(1)
    banner:SetAlpha(1)
    banner.content:SetAlpha(1)
    if #entries > 0 then
        banner.toggle:Show()
        SetExpanded(expanded or Setting("auto_expand"))
    end
end

local function OnUpdate(_, elapsed)
    stateTimer = stateTimer + elapsed
    if animState == "EXPAND" then
        local p = min(1, stateTimer / TIME_EXPAND)
        SetRevealed(1 - (1 - p) ^ 3)
        banner:SetAlpha(min(1, p * 2))
        banner.content:SetAlpha(min(1, stateTimer / TIME_TEXT_IN))
        if stateTimer >= max(TIME_EXPAND, TIME_TEXT_IN) then EnterHold() end
    elseif animState == "HOLD" then
        if IsHovered() then
            stateTimer = 0
        elseif stateTimer >= HoldTime() then
            animState, stateTimer = "FADE", 0
        end
    elseif animState == "FADE" then
        if IsHovered() then
            animState, stateTimer = "HOLD", 0
            banner:SetAlpha(1)
        elseif stateTimer >= TIME_FADE then
            Finish()
            ShowNext()
        else
            banner:SetAlpha(1 - stateTimer / TIME_FADE)
        end
    end
end

-- request = { kind = "player"|"pet", level, from, talents, unlocks, header, preview }
local function Present(request)
    Finish()
    current = request
    entries = request.unlocks
    entries.fit = nil

    banner.header:SetText(request.header)
    banner.footer:SetFormattedText(L["Level %d"], request.level)
    banner.toggle:Hide()
    banner:Show()

    if request.preview then
        EnterHold()
        animState = "PREVIEW"
        SetExpanded(true)
        return
    end
    animState, stateTimer = "EXPAND", 0
    SetRevealed(0)
    banner:SetAlpha(0)
    banner.content:SetAlpha(0)
    banner:SetScript("OnUpdate", OnUpdate)
end

ShowNext = function()
    if queuedPet and not IsEditorActive() then
        local request = queuedPet
        queuedPet = nil
        Present(request)
    end
end

local function CreateBanner()
    anchor = addon.CreateUIFrame(WIDTH, HEIGHT, "LevelUpFrame")

    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetFrameStrata("HIGH")
    banner:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    banner:SetSize(WIDTH, HEIGHT)
    banner:Hide()

    banner.art = banner:CreateTexture(nil, "BACKGROUND")
    banner.art:SetTexture(TEXTURE)
    banner.art:SetPoint("TOPLEFT", 0, -6)
    banner.art:SetPoint("BOTTOMRIGHT", 0, -1)
    banner.art:SetAlpha(0.85)

    local topLine = banner:CreateTexture(nil, "BORDER")
    topLine:SetHeight(LINE_HEIGHT)
    topLine:SetPoint("TOP")
    topLine:SetTexture(TEXTURE)
    local bottomLine = banner:CreateTexture(nil, "OVERLAY")
    bottomLine:SetHeight(LINE_HEIGHT)
    bottomLine:SetPoint("BOTTOM")
    bottomLine:SetTexture(TEXTURE)
    banner.lines = { topLine, bottomLine }

    banner.content = CreateFrame("Frame", nil, banner)
    banner.content:SetAllPoints()

    banner.header = banner.content:CreateFontString(nil, "OVERLAY")
    banner.header:SetFont(FONT, 14, "OUTLINE")
    banner.header:SetPoint("CENTER", 0, 14)
    banner.header:SetTextColor(237 / 255, 217 / 255, 150 / 255)

    banner.footer = banner.content:CreateFontString(nil, "OVERLAY")
    banner.footer:SetFont(FONT, 28, "OUTLINE")
    banner.footer:SetPoint("CENTER", 0, -12)
    banner.footer:SetTextColor(1, 215 / 255, 0)

    local list = CreateFrame("Frame", nil, banner)
    list:SetPoint("TOP", bottomLine, "BOTTOM")
    list:SetWidth(WIDTH)
    list:EnableMouse(true)
    list:Hide()
    banner.list = list

    local listBack = list:CreateTexture(nil, "BACKGROUND")
    listBack:SetAllPoints()
    listBack:SetTexture(TEXTURE)
    listBack:SetTexCoord(BACK_LEFT, BACK_RIGHT, BACK_TOP, BACK_BOTTOM)
    listBack:SetAlpha(0.85)

    local toggle = CreateFrame("Button", nil, banner)
    toggle:SetSize(21, 22)
    toggle:SetPoint("CENTER", bottomLine, "CENTER", 0, -3)
    toggle:SetFrameLevel(banner:GetFrameLevel() + 10)
    toggle:Hide()
    toggle.dot = toggle:CreateTexture(nil, "ARTWORK")
    toggle.dot:SetAllPoints()
    toggle.dot:SetTexture(TEXTURE)
    toggle.dot:SetTexCoord(unpack(DOT))
    toggle:SetScript("OnClick", function()
        if animState == "HOLD" or animState == "FADE" or animState == "PREVIEW" then
            if animState == "FADE" then
                animState = "HOLD"
                banner:SetAlpha(1)
            end
            stateTimer = 0
            SetExpanded(not expanded)
        end
    end)
    toggle:SetScript("OnEnter", function(self) self.dot:SetVertexColor(1, 1, 0.4, 1) end)
    toggle:SetScript("OnLeave", function(self)
        if expanded then
            self.dot:SetVertexColor(1, 1, 1, 1)
        else
            self.dot:SetVertexColor(0.92, 0.92, 0.92, 0.85)
        end
    end)
    banner.toggle = toggle
end

-- =============================================================================
-- REQUESTS
-- =============================================================================

local function CharacterRequest(from, to, talents, preview, unlocks)
    return {
        kind = "player", from = from, level = to, talents = talents, preview = preview,
        header = L["You've Reached"],
        unlocks = unlocks or Setting("show_unlocks") and BuildCharacterUnlocks(from, to, talents) or {},
    }
end

local function PetRequest(level, name)
    return {
        kind = "pet", level = level,
        header = format(L["%s Has Reached"], name),
        unlocks = Setting("show_unlocks") and BuildPetUnlocks(level) or {},
    }
end

local pendingPlayer
local loading = false

-- unlocks: the list already built for this single level, reused unless a burst widens the range.
local function ShowPlayerLevel(level, talents, unlocks)
    -- A burst (several levels in a row) keeps one banner that lists every level it covers.
    local from = level
    if current and current.kind == "player" and not current.preview and current.level < level then
        from, unlocks = current.from, nil
        talents = talents + (current.talents or 0)
    elseif current and current.kind == "pet" then
        queuedPet = current
    end
    Present(CharacterRequest(from, level, talents, nil, unlocks))
end

local function OnPlayerLevelUp(level, talents, unlocks)
    if IsEditorActive() or loading then
        if pendingPlayer and pendingPlayer.level < level then
            pendingPlayer = { from = pendingPlayer.from, level = level, talents = pendingPlayer.talents + talents }
        elseif not pendingPlayer then
            pendingPlayer = { from = level, level = level, talents = talents }
        end
        return
    end
    ShowPlayerLevel(level, talents, unlocks)
end

local function FlushPending()
    if not pendingPlayer or loading or IsEditorActive() then return end
    local request = pendingPlayer
    pendingPlayer = nil
    Present(CharacterRequest(request.from, request.level, request.talents))
end

-- =============================================================================
-- EVENTS
-- =============================================================================

local shownLevel
local petGUID, petLevel

local function TrackPet()
    petGUID = UnitGUID("pet")
    local level = petGUID and UnitLevel("pet")
    petLevel = level and level > 0 and level or nil
end

local function OnPetLevel()
    local guid, level = UnitGUID("pet"), UnitLevel("pet")
    -- Summons and swaps also fire UNIT_LEVEL: only the same pet gaining one level counts.
    if not guid or guid ~= petGUID or not petLevel or level ~= petLevel + 1 then
        TrackPet()
        return
    end
    petLevel = level
    local name = UnitName("pet")
    local _, isHunterPet = HasPetUI()
    if not Setting("pet_levelup") or not isHunterPet or not name or name == UNKNOWNOBJECT then return end

    local request = PetRequest(level, name)
    if Setting("show_unlocks") and Setting("chat_unlocks") then
        PrintToChat(format(L["%s has reached level %d!"], name, level), request.unlocks)
    end
    if loading or IsEditorActive() or (current and current.kind == "player") then
        queuedPet = request
    else
        Present(request)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, arg1, _, _, arg4)
    if event == "PLAYER_LEVEL_UP" then
        local level = tonumber(arg1)
        -- Some servers resend the current level after a loading screen.
        if not level or (shownLevel and level <= shownLevel) then return end
        shownLevel = level
        local talents = tonumber(arg4) or 0
        local unlocks = Setting("show_unlocks") and BuildCharacterUnlocks(level, level, talents)
        if unlocks and Setting("chat_unlocks") then PrintToChat(nil, unlocks) end
        OnPlayerLevelUp(level, talents, unlocks)
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Like retail, a banner cut by a loading screen starts over once the world is back.
        loading = true
        if current and not current.preview then
            if current.kind == "player" then
                pendingPlayer = { from = current.from, level = current.level, talents = current.talents or 0 }
            else
                queuedPet = current
            end
            Finish()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        loading = false
        local level = UnitLevel("player")
        if level and level > 0 and (not shownLevel or level < shownLevel) then shownLevel = level end
        TrackPet()
        FlushPending()
        if not current then ShowNext() end
    elseif event == "UNIT_PET" then
        if arg1 == "player" then TrackPet() end
    elseif event == "UNIT_LEVEL" then
        if arg1 == "pet" then OnPetLevel() end
    end
end)
LevelUpEnhance.eventFrame = eventFrame

-- =============================================================================
-- POSITION AND EDITOR
-- =============================================================================

local function ApplyWidgetPosition()
    if IsEditorActive() then return end
    local cfg = addon.db.profile.widgets.levelupenhance or addon.defaults.profile.widgets.levelupenhance
    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY)
end

local function ApplyScale()
    local scale = Setting("scale") or 1
    banner:SetScale(scale)
    addon.SetEditorBoxScale(anchor, scale)
end

local function PreviewLevel()
    local level = UnitLevel("player") or 1
    if level < 80 then level = level + 1 end
    return level
end

local function RegisterEditor()
    addon:RegisterEditableFrame({
        name = "levelupenhance",
        frame = anchor,
        blizzardFrame = banner,
        configPath = { "widgets", "levelupenhance" },
        editorVisible = function()
            return addon:IsModuleEnabled("levelupenhance")
        end,
        showTest = function()
            if current and not current.preview then
                if current.kind == "player" then
                    pendingPlayer = { from = current.from, level = current.level, talents = current.talents or 0 }
                else
                    queuedPet = current
                end
            end
            local level = PreviewLevel()
            anchor:Show()
            Present(CharacterRequest(level, level, level > FIRST_TALENT_LEVEL and 1 or 0, true))
        end,
        hideTest = function()
            if current and current.preview then Finish() end
        end,
        onHide = function()
            ApplyWidgetPosition()
            FlushPending()
            if not current then ShowNext() end
        end,
        module = LevelUpEnhance,
    })
end

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

local EVENTS = { "PLAYER_LEVEL_UP", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "UNIT_PET", "UNIT_LEVEL" }

function addon.ApplyLevelUpEnhanceSystem()
    if not banner then
        CreateBanner()
        RegisterEditor()
    end
    ApplyWidgetPosition()
    ApplyScale()
    for _, event in ipairs(EVENTS) do eventFrame:RegisterEvent(event) end

    local level = UnitLevel("player")
    if level and level > 0 then shownLevel = max(shownLevel or 0, level) end
    TrackPet()
    LevelUpEnhance.initialized = true
    LevelUpEnhance.applied = true
end

function addon.RestoreLevelUpEnhanceSystem()
    eventFrame:UnregisterAllEvents()
    pendingPlayer, queuedPet, loading = nil, nil, false
    if banner then Finish() end
    LevelUpEnhance.applied = false
end

function addon.RefreshLevelUpEnhanceSystem()
    if addon:IsModuleEnabled("levelupenhance") then
        addon.ApplyLevelUpEnhanceSystem()
    else
        addon.RestoreLevelUpEnhanceSystem()
    end
end

function addon.RefreshLevelUpEnhance()
    if not banner then return end
    ApplyScale()
    if current and current.preview then
        local level = current.level
        Present(CharacterRequest(level, level, current.talents, true))
    end
end

-- =============================================================================
-- TEST
-- =============================================================================

function addon.TestLevelUpEnhance(level)
    if not LevelUpEnhance.applied then
        addon:Print(L["Module disabled."])
        return
    end
    level = tonumber(level)
    if not level or level < 1 or level > 80 then level = PreviewLevel() end
    level = floor(level)
    local talents = level >= FIRST_TALENT_LEVEL and 1 or 0
    local request = CharacterRequest(level, level, talents)
    if Setting("show_unlocks") and Setting("chat_unlocks") then
        PrintToChat(nil, request.unlocks)
    end
    Present(request)
end

SLASH_DRAGONUI_TESTLEVEL1 = "/testlevel"
SLASH_DRAGONUI_TESTLEVEL2 = "/lvltest"
SlashCmdList["DRAGONUI_TESTLEVEL"] = function(msg)
    addon.TestLevelUpEnhance(strtrim(msg or ""))
end
