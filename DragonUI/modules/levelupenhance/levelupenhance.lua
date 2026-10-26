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
-- Retail's redrawn LevelUpUI pieces, truecolor: LevelUpTex's DXT copies band the gold into flat steps.
local PIECES = addon._dir .. "NewLevelUp\\levelup_retail"
local FONT = addon.Fonts.PRIMARY

local BADGE_BOOK = { 2 / 512, 42 / 512, 2 / 64, 40 / 64 }
local BADGE_LOCK = { 46 / 512, 76 / 512, 2 / 64, 37 / 64 }
local BADGE_ARROW = { 80 / 512, 110 / 512, 2 / 64, 36 / 64 }
local DOT = { 114 / 512, 135 / 512, 2 / 64, 24 / 64 }
local LINE = { 2 / 512, 420 / 512, 44 / 64, 51 / 64 }
-- Regions of Blizzard's LevelUpTex sheet (512x512).
local SHADOW = { 0.00195313, 0.63867188, 0.03710938, 0.23828125 }
local LIST_SHADOW = { 0.00195313, 0.55664063, 0.24218750, 0.82031250 }

-- WIDTH is the shadow's and the list's; the gold lines run wider, as in LevelUpDisplay.
local WIDTH, HEIGHT, LINE_HEIGHT, BANNER_WIDTH = 326, 72, 7, 418
local SHADOW_HEIGHT, SHADOW_ALPHA = 103, 0.6
-- The list shadow fades to nothing at its foot, so the rows only cover its darker top.
local LIST_SHADOW_SPAN = 0.75
-- Retail's unlock layout (EventToastWithIconNormalTemplate, LevelUpSkillTemplate's 44 px rows + 1).
local ICON_SIZE, BADGE_SIZE, ROW_HEIGHT, TEXT_GAP = 36, 22, 45, 10
-- 8 rows hold 89% of level-ups whole; the rest fold by kind (Condense), so the list never scrolls.
local MAX_TEXT_WIDTH, MIN_ROWS, MAX_ROWS = 245, 4, 8
local LIST_TOP, LIST_BOTTOM = 8, 6
local SCREEN_MARGIN = 140
-- GameFontNormalLarge title over a GameFontNormal subtitle; long names shrink to fit.
local TITLE_SIZE, TITLE_MIN, SUB_SIZE, SUB_MIN = 16, 11, 12, 9

-- Icons come with or without a baked bevel: crop it and frame them all with the aura borders' ring.
local RING_TEXTURE = addon._dir .. "ActionBars\\uiactionbar2x_new"
local RING_COORDS = { 359 / 512, 451 / 512, 649 / 1024, 739 / 1024 }
-- The ring's rounded corners can't cover a square's: the icon sits 1 px inside a darkened copy of itself.
local RING_SCALE = ICON_SIZE / 45 * 1.1375
local RING_X, RING_Y = -1.8, 1.8
local ICON_CROP, ICON_INSET, ICON_BACK_SHADE = 0.06, 1, 0.3

-- Blizzard's LevelUpDisplay timeline; the delay lets the ding spell visual play first.
local TIME_DELAY, TIME_LINES, SHADOW_DELAY, TIME_SHADOW, TIME_TEXT_IN = 1.5, 0.5, 0.25, 0.15, 0.7
local TIME_TEXT_OUT, TIME_FADE, TIME_LIST_IN, TIME_ROW_IN = 0.5, 1.0, 0.5, 0.4
-- One-at-a-time cards, timed as LevelUpSkillTemplate's showAnim.
local CARD_IN, CARD_HOLD, CARD_OUT = 0.5, 1.8, 0.5
local HOLD_COLLAPSED, HOLD_LIST, HOLD_PER_ROW, HOLD_LIST_MAX, HOLD_QUEUED = 4, 4, 1, 10, 5
-- Levels in a row that get a banner each, as retail queues them; the rest share one banner.
local MAX_SINGLE_BANNERS = 3
local CHAT_DELAY = 0.5

-- NORMAL_FONT_COLOR and GREEN_FONT_COLOR.
local COLOR_TITLE = { 1, 0.82, 0 }
local COLOR_SUB = { 0.1, 1, 0.1 }

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

local function SpellEntry(spellID, kind, hint, level)
    local name, rank, icon = GetSpellInfo(spellID)
    if not name then return nil end
    local text = name
    if kind == "rank" and rank and rank ~= "" then
        text = format("%s |cffb3b3b3(%s)|r", name, rank)
    end
    return { kind = kind, text = text, name = name, icon = icon or ICON_UNKNOWN, spellID = spellID, hint = hint,
        level = level }
end

local function Add(list, entry)
    if entry then list[#list + 1] = entry end
end

local function AddFeatures(out, from, to)
    for level = from, to do
        for _, feature in ipairs(FEATURES[level] or EMPTY) do
            Add(out, { kind = "feature", text = feature[1], icon = feature[2], level = level })
        end
        if GLYPH_SLOT_AT[level] then
            Add(out, { kind = "feature", text = GLYPH_SLOT_AT[level], icon = ICON_GLYPHS, level = level })
        end
    end
end

local function AddRiding(out, data, from, to)
    local Book = addon.SpellbookModule
    for _, row in ipairs(data.riding or EMPTY) do
        local level = Book and Book.TrainerLevel and Book.TrainerLevel(row[2]) or row[1]
        if level >= from and level <= to then
            Add(out, SpellEntry(row[2], "feature", HINT_RIDING, level))
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
            -- Known spells stay: servers that teach on level-up still unlocked them at this level.
            if level >= from and level <= to and not seen[spellID] and RaceAllows(record[6], raceBit)
                and (talent == 0 or KnownInChain(index, talent, memo)
                    or (previous ~= 0 and KnownInChain(index, previous, memo))) then
                seen[spellID] = true
                if FEATURE_SPELLS[spellID] then
                    Add(features, SpellEntry(spellID, "feature", HINT_TRAINER, level))
                else
                    Add(spells, SpellEntry(spellID, previous ~= 0 and "rank" or "spell", HINT_TRAINER, level))
                end
            end
        end
    end

    for _, row in ipairs(data.questSpells and data.questSpells[class] or EMPTY) do
        local spellID = row[2]
        if row[1] >= from and row[1] <= to and not seen[spellID] and RaceAllows(row[3], raceBit) then
            seen[spellID] = true
            Add(spells, SpellEntry(spellID, "spell", HINT_QUEST, row[1]))
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
            Add(out, { kind = "battleground", text = names[row[2]] or row[4], icon = "Interface\\Icons\\" .. row[3],
                level = row[1] })
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
                icon = row[4] and (LFG_ICON .. row[4]) or ICON_DUNGEON, level = row[1] })
        end
    end
    for _, row in ipairs(data.heroics or EMPTY) do
        local name = _G["EXPANSION_NAME" .. row[2]]
        if row[1] >= from and row[1] <= to and name then
            Add(heroics, { kind = "heroic", text = name, icon = HEROIC_ICONS[row[2]] or ICON_DUNGEON, level = row[1] })
        end
    end
    for _, row in ipairs(data.raids or EMPTY) do
        if row[1] >= from and row[1] <= to then
            Add(raids, { kind = "raid", text = GetLFGDungeonInfo(row[2]) or row[4], hint = LevelRangeHint(row[2]),
                icon = row[3] and (LFG_ICON .. row[3]) or ICON_RAID, level = row[1] })
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
    if from < to then
        for _, entry in ipairs(out) do
            if entry.level and entry.level < to then
                entry.tag = format(L["Level %d"], entry.level)
                entry.sub = format("%s |cffb3b3b3(%s)|r", SUBTEXT[entry.kind] or SUBTEXT.feature, entry.tag)
            end
        end
    end
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
    -- A spell the server already taught got the client's own "You have learned" line.
    if not prefix or (entry.spellID and IsSpellKnown(entry.spellID)) then return nil end
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
    addon:After(CHAT_DELAY, function()
        local lines = {}
        if header then lines[1] = header end
        for _, entry in ipairs(entries) do
            local line = ChatLine(entry)
            if line then lines[#lines + 1] = line end
        end
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
local animState, stateTimer, revealDelay = "IDLE", 0, 0
local cascade
local cardIndex = 0
local queuedPet
-- Player banners waiting their turn: { level, talents, unlocks } or, past the limit, { from, level, talents }.
local playerQueue = {}
local runLength = 0
local loading = false

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive()
end

local function FitText(text, startSize, minSize)
    local size = startSize
    measure:SetFont(FONT, size)
    measure:SetText(text)
    while measure:GetStringWidth() > MAX_TEXT_WIDTH and size > minSize do
        size = size - 1
        measure:SetFont(FONT, size)
    end
    return size, measure:GetStringWidth()
end

local function GroupTitle(group)
    local items, n = group.items, #group.items
    measure:SetFont(FONT, TITLE_MIN + 3)
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
        entry.width = max(width, subWidth)
        widest = max(widest, entry.width)
    end
    return widest
end

local function RowEnter(self)
    local entry = self.entry
    if not entry then return end
    GameTooltip:SetOwner(self.tooltipOwner or self, self.tooltipAnchor or "ANCHOR_RIGHT")
    if entry.items then
        GameTooltip:SetText(entry.sub, 1, 1, 1)
        for _, item in ipairs(entry.items) do
            local line = format("|T%s:16|t %s", item.icon, item.text)
            if item.tag then line = format("%s |cffb3b3b3(%s)|r", line, item.tag) end
            GameTooltip:AddLine(line, COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        end
    elseif entry.spellID then
        GameTooltip:SetHyperlink("spell:" .. entry.spellID)
    else
        GameTooltip:SetText(entry.text, 1, 1, 1)
    end
    if entry.hint and not (entry.spellID and IsSpellKnown(entry.spellID)) then
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

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(WIDTH, ROW_HEIGHT)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", RowClick)

    row.iconBack = row:CreateTexture(nil, "BACKGROUND")
    row.iconBack:SetSize(ICON_SIZE, ICON_SIZE)
    row.iconBack:SetVertexColor(ICON_BACK_SHADE, ICON_BACK_SHADE, ICON_BACK_SHADE)

    row.icon = row:CreateTexture(nil, "BORDER")
    row.icon:SetPoint("TOPLEFT", row.iconBack, "TOPLEFT", ICON_INSET, -ICON_INSET)
    row.icon:SetPoint("BOTTOMRIGHT", row.iconBack, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    for _, texture in ipairs({ row.iconBack, row.icon }) do
        texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    end

    row.ring = row:CreateTexture(nil, "ARTWORK")
    row.ring:SetTexture(RING_TEXTURE)
    row.ring:SetTexCoord(unpack(RING_COORDS))
    row.ring:SetSize(46 * RING_SCALE, 45 * RING_SCALE)
    row.ring:SetPoint("TOPLEFT", row.iconBack, "TOPLEFT", RING_X, RING_Y)

    row.badge = row:CreateTexture(nil, "OVERLAY")
    row.badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    row.badge:SetPoint("CENTER", row.iconBack, "BOTTOMLEFT", 2, 2)
    row.badge:SetTexture(PIECES)

    row.title = row:CreateFontString(nil, "ARTWORK")
    row.title:SetPoint("BOTTOMLEFT", row.iconBack, "BOTTOMRIGHT", TEXT_GAP, 4)
    row.title:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])

    row.sub = row:CreateFontString(nil, "ARTWORK")
    row.sub:SetPoint("BOTTOMLEFT", row.title, "TOPLEFT", 0, 1)
    row.sub:SetTextColor(COLOR_SUB[1], COLOR_SUB[2], COLOR_SUB[3])

    for _, text in ipairs({ row.title, row.sub }) do
        text:SetWordWrap(false)
        text:SetJustifyH("LEFT")
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
    end
    return row
end

local function FillRow(row, entry, left)
    row.entry = entry
    row.iconBack:ClearAllPoints()
    row.iconBack:SetPoint("LEFT", row, "LEFT", left, -2)
    row.icon:SetTexture(entry.icon)
    row.iconBack:SetTexture(entry.icon)
    -- Dark mode shades the ring exactly as it shades the aura and action-button rings.
    local tint = addon.GetDarkModeTint and addon.GetDarkModeTint()
    if tint then
        row.ring:SetVertexColor(tint[1], tint[2], tint[3])
    else
        row.ring:SetVertexColor(1, 1, 1)
    end
    row.badge:SetTexCoord(unpack(BADGE[entry.of or entry.kind] or BADGE_LOCK))
    row.sub:SetFont(FONT, entry.subSize)
    row.sub:SetText(entry.sub)
    row.title:SetFont(FONT, entry.titleSize)
    row.title:SetText(entry.text)
    row:Show()
end

local function RowsThatFit()
    local bottom = banner:GetBottom()
    if not bottom then return MAX_ROWS end
    local fit = floor((bottom - SCREEN_MARGIN - LIST_TOP - LIST_BOTTOM) / ROW_HEIGHT)
    return min(MAX_ROWS, max(MIN_ROWS, fit))
end

local function DisplayList(fit)
    fit = fit or RowsThatFit()
    if entries.fit ~= fit then
        entries.fit = fit
        entries.display = Condense(entries, fit)
        entries.widest = MeasureEntries(entries.display)
    end
    return entries.display
end

local function Progress(t, duration)
    return max(0, min(1, t / duration))
end

-- The drawer fades in, then its rows one after another, as LevelUpDisplaySide does.
local function ApplyCascade()
    local count = #(entries.display or EMPTY)
    if not cascade then
        banner.list:SetAlpha(1)
        for i = 1, count do rows[i]:SetAlpha(1) end
        return
    end
    banner.list:SetAlpha(Progress(cascade, TIME_LIST_IN))
    for i = 1, count do
        rows[i]:SetAlpha(Progress(cascade - TIME_LIST_IN - (i - 1) * TIME_ROW_IN, TIME_ROW_IN))
    end
    if cascade >= TIME_LIST_IN + count * TIME_ROW_IN then cascade = nil end
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
        local row = rows[i] or CreateRow(list)
        rows[i] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -LIST_TOP - (i - 1) * ROW_HEIGHT)
        FillRow(row, entry, left)
    end
    for i = #display + 1, #rows do
        rows[i].entry = nil
        rows[i]:Hide()
    end
    local height = LIST_TOP + #display * ROW_HEIGHT + LIST_BOTTOM
    list:SetHeight(height)
    list.back:SetHeight(height / LIST_SHADOW_SPAN)
    ApplyCascade()
    list:Show()
end

local function SetExpanded(value)
    local opening = value and not expanded
    expanded = value and #entries > 0
    -- The editor's still preview has no OnUpdate to run the cascade.
    if not expanded then
        cascade = nil
    elseif opening then
        cascade = animState ~= "PREVIEW" and 0 or nil
    end
    if expanded then
        banner.toggle.dot:SetVertexColor(1, 1, 1, 1)
    else
        banner.toggle.dot:SetVertexColor(0.92, 0.92, 0.92, 0.85)
    end
    RefreshList()
end

local function HoldTime()
    local hold = HOLD_COLLAPSED
    if expanded then hold = min(HOLD_LIST + HOLD_PER_ROW * #(entries.display or entries), HOLD_LIST_MAX) end
    if playerQueue[1] or queuedPet then hold = min(hold, HOLD_QUEUED) end
    return hold
end

local function IsHovered()
    -- Mouselook freezes the hidden cursor where it was, which could hold the banner up for good.
    if IsMouselooking() then return false end
    return (banner.list:IsVisible() and banner.list:IsMouseOver())
        or (banner.toggle:IsVisible() and banner.toggle:IsMouseOver())
        or (banner.card:IsVisible() and banner.card:IsMouseOver())
end

-- unlock_style: "banner" gives each unlock the banner in turn, as retail; "list" opens a drawer under it.
local function ListMode()
    return Setting("unlock_style") == "list"
end

local function CardMode()
    return not ListMode() and #entries > 0
end

local function ShowCard(index)
    local entry = DisplayList(MAX_ROWS)[index]
    animState, stateTimer, cardIndex = "CARDS", 0, index
    if not entry then
        banner.card:Hide()
        -- The level text faded before the first card, so the fade starts at its second step.
        animState, stateTimer = "FADE", TIME_TEXT_OUT
        return
    end
    FillRow(banner.card, entry, max(12, floor((WIDTH - (ICON_SIZE + TEXT_GAP + entry.width)) / 2)))
    banner.card:SetAlpha(0)
end

-- Scaled like LevelUpDisplay's grow animations: lines from the centre, the shadow up from the bottom line.
local function SetRevealed(lines, shadow)
    for _, texture in ipairs(banner.lines) do
        texture:SetWidth(max(1, BANNER_WIDTH * lines))
    end
    if shadow > 0 then
        banner.art:SetHeight(SHADOW_HEIGHT * shadow)
        banner.art:Show()
    else
        banner.art:Hide()
    end
end

local ShowNext

local function Finish()
    animState, stateTimer = "IDLE", 0
    current, entries = nil, EMPTY
    expanded, cascade, cardIndex = false, nil, 0
    if banner then
        banner:SetScript("OnUpdate", nil)
        banner.list:Hide()
        banner.toggle:Hide()
        banner.card:Hide()
        banner:Hide()
    end
end

local function Unfade()
    animState, stateTimer = "HOLD", 0
    banner:SetAlpha(1)
    banner.content:SetAlpha(1)
    banner.list:SetAlpha(1)
end

local function EnterHold()
    Unfade()
    SetRevealed(1, 1)
    if #entries > 0 and ListMode() then
        banner.toggle:Show()
        SetExpanded(expanded or Setting("auto_expand"))
    end
end

local function OnUpdate(_, elapsed)
    stateTimer = stateTimer + elapsed
    if cascade then
        cascade = cascade + elapsed
        ApplyCascade()
    end
    if animState == "EXPAND" then
        local t = stateTimer - revealDelay
        if t >= TIME_TEXT_IN then
            EnterHold()
        elseif t >= 0 then
            banner:SetAlpha(1)
            SetRevealed(Progress(t, TIME_LINES), Progress(t - SHADOW_DELAY, TIME_SHADOW))
            banner.content:SetAlpha(Progress(t, TIME_TEXT_IN))
        end
    elseif animState == "HOLD" then
        if IsHovered() then
            stateTimer = 0
        elseif stateTimer >= HoldTime() then
            if CardMode() then
                animState, stateTimer, cardIndex = "CARDS", 0, 0
            else
                animState, stateTimer = "FADE", 0
            end
        end
    elseif animState == "CARDS" then
        if cardIndex == 0 then
            banner.content:SetAlpha(1 - Progress(stateTimer, TIME_TEXT_OUT))
            if stateTimer >= TIME_TEXT_OUT then ShowCard(1) end
        else
            -- The mouse keeps the card up, as retail pauses its toasts under the cursor.
            if IsHovered() then stateTimer = min(stateTimer, CARD_IN) end
            if stateTimer >= CARD_IN + CARD_HOLD + CARD_OUT then
                ShowCard(cardIndex + 1)
            else
                banner.card:SetAlpha(min(Progress(stateTimer, CARD_IN),
                    1 - Progress(stateTimer - CARD_IN - CARD_HOLD, CARD_OUT)))
            end
        end
    elseif animState == "FADE" then
        -- Text and list go first, then the lines and shadow, as LevelUpDisplay fades out.
        if IsHovered() then
            Unfade()
        elseif stateTimer >= TIME_TEXT_OUT + TIME_FADE then
            Finish()
            ShowNext()
        else
            local text = 1 - Progress(stateTimer, TIME_TEXT_OUT)
            banner.content:SetAlpha(text)
            banner.list:SetAlpha(text)
            banner:SetAlpha(1 - Progress(stateTimer - TIME_TEXT_OUT, TIME_FADE))
        end
    end
end

-- request = { kind = "player"|"pet", level, from, talents, unlocks, header, preview }
local function Present(request, fresh)
    Finish()
    current = request
    entries = request.unlocks
    entries.fit = nil

    banner.header:SetText(request.header)
    banner.footer:SetFormattedText(L["Level %d"], request.level)
    banner.toggle:Hide()
    banner:Show()
    -- Retail centres the block on the banner; measured, as this client may cap the 32 px level font.
    local block = 3 + banner.header:GetStringHeight() + 3 + banner.footer:GetStringHeight()
    banner.header:SetPoint("TOP", banner.content, "CENTER", 0, floor(block / 2) - 3)

    if request.preview then
        EnterHold()
        animState = "PREVIEW"
        SetExpanded(false)
        return
    end
    animState, stateTimer = "EXPAND", 0
    -- Only a banner shown at the ding waits for its spell visual; one that queued has none left.
    revealDelay = fresh and TIME_DELAY or 0
    SetRevealed(0, 0)
    banner:SetAlpha(0)
    banner.content:SetAlpha(0)
    banner:SetScript("OnUpdate", OnUpdate)
end

local function CreateBanner()
    anchor = addon.CreateUIFrame(BANNER_WIDTH, HEIGHT, "LevelUpFrame")

    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetFrameStrata("HIGH")
    banner:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    banner:SetSize(BANNER_WIDTH, HEIGHT)
    banner:Hide()

    banner.art = banner:CreateTexture(nil, "BACKGROUND")
    banner.art:SetTexture(TEXTURE)
    banner.art:SetTexCoord(unpack(SHADOW))
    banner.art:SetPoint("BOTTOM")
    banner.art:SetSize(WIDTH, SHADOW_HEIGHT)
    banner.art:SetAlpha(SHADOW_ALPHA)

    local topLine = banner:CreateTexture(nil, "BORDER")
    topLine:SetHeight(LINE_HEIGHT)
    topLine:SetPoint("TOP")
    local bottomLine = banner:CreateTexture(nil, "OVERLAY")
    bottomLine:SetHeight(LINE_HEIGHT)
    bottomLine:SetPoint("BOTTOM")
    banner.lines = { topLine, bottomLine }
    for _, texture in ipairs(banner.lines) do
        texture:SetTexture(PIECES)
        texture:SetTexCoord(unpack(LINE))
        texture:SetWidth(BANNER_WIDTH)
    end

    banner.content = CreateFrame("Frame", nil, banner)
    banner.content:SetAllPoints()

    -- Retail's SystemFont_Shadow_Large over GameFont_Gigantic; 3.3.5a has no Gigantic font object.
    banner.header = banner.content:CreateFontString(nil, "OVERLAY")
    banner.header:SetFont(FONT, 16)
    banner.header:SetTextColor(1, 1, 1)

    banner.footer = banner.content:CreateFontString(nil, "OVERLAY")
    banner.footer:SetFont(FONT, 32)
    banner.footer:SetPoint("TOP", banner.header, "BOTTOM", 0, -3)
    banner.footer:SetTextColor(1, 0.82, 0)

    for _, text in ipairs({ banner.footer, banner.header }) do
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
    end

    banner.card = CreateRow(banner)
    banner.card:SetPoint("CENTER")
    banner.card:Hide()
    -- Retail hangs a toast's tooltip off its title, to the left (EventToastAnimationsMixin:MouseOverTitle).
    banner.card.tooltipOwner = CreateFrame("Frame", nil, banner.card)
    banner.card.tooltipOwner:SetAllPoints(banner.card.title)
    banner.card.tooltipAnchor = "ANCHOR_LEFT"

    local list = CreateFrame("Frame", nil, banner)
    list:SetPoint("TOP", bottomLine, "BOTTOM")
    list:SetWidth(WIDTH)
    list:EnableMouse(true)
    list:Hide()
    banner.list = list

    list.back = list:CreateTexture(nil, "BACKGROUND")
    list.back:SetPoint("TOP")
    list.back:SetWidth(WIDTH)
    list.back:SetTexture(TEXTURE)
    list.back:SetTexCoord(unpack(LIST_SHADOW))
    list.back:SetAlpha(SHADOW_ALPHA)

    local toggle = CreateFrame("Button", nil, banner)
    toggle:SetSize(21, 22)
    -- Whole pixels (centred, the 21x22 dot blurs); the bar's gold is its bottom row, so centre on that.
    toggle:SetPoint("TOPLEFT", bottomLine, "BOTTOM", -10, 12)
    toggle:SetFrameLevel(banner:GetFrameLevel() + 10)
    toggle:Hide()
    toggle.dot = toggle:CreateTexture(nil, "ARTWORK")
    toggle.dot:SetAllPoints()
    toggle.dot:SetTexture(PIECES)
    toggle.dot:SetTexCoord(unpack(DOT))
    toggle:SetScript("OnClick", function()
        if animState == "HOLD" or animState == "FADE" or animState == "PREVIEW" then
            if animState == "FADE" then Unfade() end
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

-- from: first level of a banner that covers several (the run past MAX_SINGLE_BANNERS).
local function CharacterRequest(level, talents, preview, unlocks, from)
    return {
        kind = "player", level = level, from = from, talents = talents, preview = preview,
        header = L["You've Reached"],
        unlocks = unlocks or Setting("show_unlocks") and BuildCharacterUnlocks(from or level, level, talents) or {},
    }
end

local function PetRequest(level, name)
    return {
        kind = "pet", level = level,
        header = format(L["%s Has Reached"], name),
        unlocks = Setting("show_unlocks") and BuildPetUnlocks(level) or {},
    }
end

ShowNext = function(fresh)
    if loading or IsEditorActive() then return end
    local nextPlayer = table.remove(playerQueue, 1)
    if nextPlayer then
        Present(CharacterRequest(nextPlayer.level, nextPlayer.talents, nil, nextPlayer.unlocks, nextPlayer.from), fresh)
        return
    end
    runLength = 0
    if queuedPet then
        local request = queuedPet
        queuedPet = nil
        Present(request)
    end
end

-- A banner cut short (loading screen, editor, test) plays again first.
local function Requeue(request)
    if request.kind == "player" then
        table.insert(playerQueue, 1, { from = request.from, level = request.level, talents = request.talents or 0,
            unlocks = request.unlocks })
    else
        queuedPet = request
    end
end

local function QueuePlayerLevel(level, talents, unlocks)
    local last = playerQueue[#playerQueue]
    if last and last.from then
        last.level, last.talents, last.unlocks = level, last.talents + talents, nil
    elseif runLength < MAX_SINGLE_BANNERS then
        playerQueue[#playerQueue + 1] = { level = level, talents = talents, unlocks = unlocks }
    else
        playerQueue[#playerQueue + 1] = { from = level, level = level, talents = talents }
    end
    runLength = runLength + 1
end

local function OnPlayerLevelUp(level, talents, unlocks)
    if current and current.kind == "pet" then
        Requeue(current)
        Finish()
    end
    QueuePlayerLevel(level, talents, unlocks)
    if not current then ShowNext(true) end
end

-- =============================================================================
-- EVENTS
-- =============================================================================

local shownLevel, playerLevel
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
    if loading or IsEditorActive() or playerQueue[1] or (current and current.kind == "player") then
        queuedPet = request
    else
        Present(request, true)
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
            Requeue(current)
            Finish()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        loading = false
        local level = UnitLevel("player")
        if level and level > 0 then
            if not shownLevel or level < shownLevel then shownLevel = level end
            playerLevel = level
        end
        TrackPet()
        if not current then ShowNext() end
    elseif event == "UNIT_PET" then
        if arg1 == "player" then TrackPet() end
    elseif event == "UNIT_LEVEL" then
        if arg1 == "pet" then
            OnPetLevel()
        elseif arg1 == "player" then
            -- Only a real drop (GM command, level reset) re-arms levels already shown.
            local level = UnitLevel("player")
            if level and level > 0 then
                if playerLevel and level < playerLevel and shownLevel and level < shownLevel then shownLevel = level end
                playerLevel = level
            end
        end
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
    local level = UnitLevel("player")
    return level and level > 0 and level or 1
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
            if current and not current.preview then Requeue(current) end
            local level = PreviewLevel()
            anchor:Show()
            Present(CharacterRequest(level, level > FIRST_TALENT_LEVEL and 1 or 0, true))
        end,
        hideTest = function()
            if current and current.preview then Finish() end
        end,
        onHide = function()
            ApplyWidgetPosition()
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
    if level and level > 0 then
        shownLevel = max(shownLevel or 0, level)
        playerLevel = level
    end
    TrackPet()
    LevelUpEnhance.initialized = true
    LevelUpEnhance.applied = true
end

function addon.RestoreLevelUpEnhanceSystem()
    eventFrame:UnregisterAllEvents()
    playerQueue, runLength, queuedPet, loading = {}, 0, nil, false
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
        Present(CharacterRequest(current.level, current.talents, true))
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
    local request = CharacterRequest(level, talents)
    if Setting("show_unlocks") and Setting("chat_unlocks") then
        PrintToChat(nil, request.unlocks)
    end
    if current and not current.preview then Requeue(current) end
    Present(request, true)
end

SLASH_DRAGONUI_TESTLEVEL1 = "/testlevel"
SLASH_DRAGONUI_TESTLEVEL2 = "/lvltest"
SlashCmdList["DRAGONUI_TESTLEVEL"] = function(msg)
    addon.TestLevelUpEnhance(strtrim(msg or ""))
end
