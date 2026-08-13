local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Width chain: InsetRight = W - 332 - 4, pane = InsetRight - 6, viewport = pane - gutter. The
-- gutter is reserved permanently, so no header changes width when a collapse drops the scrollbar.
local SCROLLBAR_GUTTER = 11
local EXPANDED_WIDTH = 551

-- Resting widths only; the real ones are derived per relayout from the viewport.
local HEADER_W, HEADER_H = 197, 40
local ROW_W, ROW_H = 191, 15
local ROW_INSET = 2

-- Breathing room: two collapsed bars flush together read as one wider block.
local SECTION_GAP = 3
local ROWS_PER_SECTION = 6

-- Blizzard's own UpdatePaperdollStats drives these, so every Wrath formula comes from the client.
local SECTIONS = {
    { prefix = "DragonUIStatBase", index = "PLAYERSTAT_BASE_STATS" },
    { prefix = "DragonUIStatMelee", index = "PLAYERSTAT_MELEE_COMBAT" },
    { prefix = "DragonUIStatRanged", index = "PLAYERSTAT_RANGED_COMBAT" },
    { prefix = "DragonUIStatSpell", index = "PLAYERSTAT_SPELL_COMBAT" },
    { prefix = "DragonUIStatDefense", index = "PLAYERSTAT_DEFENSES" },
}

local RESIST_SCHOOLS = { 2, 3, 4, 5, 6 }

-- statIndex matches UnitStat / PaperDollFrame_SetStat's own numbering: 1 Str, 2 Agi, 3 Sta, 4 Int, 5 Spirit.
-- Classes whose class-defining stat and combat category never change across their 3 talent trees.
local CLASS_PROFILE = {
    ROGUE   = { stat = 2, combat = "PLAYERSTAT_MELEE_COMBAT" },
    HUNTER  = { stat = 2, combat = "PLAYERSTAT_RANGED_COMBAT" },
    PRIEST  = { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" },
    MAGE    = { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" },
    WARLOCK = { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" },
}

-- Everyone else flips with spec. Tanking trees read Stamina rather than Strength/Agility: Wrath tank
-- itemization leads with Stamina once Defense/Hit/Expertise are capped, on every one of these. Tab
-- order (1/2/3) is the client's own, unchanged since each class' introduction.
local SPEC_PROFILE = {
    WARRIOR = {
        { stat = 1, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Arms
        { stat = 1, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Fury
        { stat = 3, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Protection
    },
    DEATHKNIGHT = {
        { stat = 3, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Blood, Wrath's tanking tree
        { stat = 1, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Frost
        { stat = 1, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Unholy
    },
    PALADIN = {
        { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" }, -- Holy
        { stat = 3, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Protection
        { stat = 1, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Retribution
    },
    SHAMAN = {
        { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" }, -- Elemental
        { stat = 2, combat = "PLAYERSTAT_MELEE_COMBAT" }, -- Enhancement
        { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" }, -- Restoration
    },
    DRUID = {
        { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" }, -- Balance
        -- Feral Combat covers both Cat and Bear -- 3.3.5a never split a separate Guardian tree the
        -- way later expansions did, so the two roles are told apart by shapeshift form instead.
        { feral = true, combat = "PLAYERSTAT_MELEE_COMBAT" },
        { stat = 4, combat = "PLAYERSTAT_SPELL_COMBAT" }, -- Restoration
    },
}

-- Bear Form absorbed Dire Bear Form's bonuses in patch 3.2, but both icons are checked in case an
-- older rank is somehow still what's active. Comparing icons rather than names stays locale-safe.
local BEAR_FORM_ICON = GetSpellInfo and select(3, GetSpellInfo(5487))
local DIRE_BEAR_FORM_ICON = GetSpellInfo and select(3, GetSpellInfo(9634))

-- Same loop-and-check BonusActionBarFrame's own ShapeshiftBar_UpdateState uses to find the active form.
local function inBearForm()
    for i = 1, GetNumShapeshiftForms() do
        local icon, _, isActive = GetShapeshiftFormInfo(i)
        if isActive then
            return icon ~= nil and (icon == BEAR_FORM_ICON or icon == DIRE_BEAR_FORM_ICON)
        end
    end
    return false
end

-- Same rule Blizzard's own talent UI uses for "which spec is active" (TalentFrame_UpdateSpecInfoCache):
-- the tree with the most points spent wins. Ties, and a fresh character with none spent, fall to tree 1.
local function activeTalentTab()
    local best, bestPoints = 1, -1
    for tab = 1, GetNumTalentTabs() do
        local _, _, pointsSpent = GetTalentTabInfo(tab)
        if pointsSpent and pointsSpent > bestPoints then
            bestPoints, best = pointsSpent, tab
        end
    end
    return best
end

local function detectedProfile()
    local _, classToken = UnitClass("player")
    local trees = SPEC_PROFILE[classToken]
    local profile = trees and trees[activeTalentTab()] or CLASS_PROFILE[classToken]
    if profile and profile.feral then
        return { stat = inBearForm() and 3 or 2, combat = profile.combat }
    end
    return profile
end

local STAT_TOKENS = { STRENGTH = 1, AGILITY = 2, STAMINA = 3, INTELLECT = 4, SPIRIT = 5 }

-- Auto pick first, then whichever half the user overrode in Settings. "off" drops that half
-- entirely (no highlight / no promoted category) instead of falling back to the auto pick.
function CP.GetPrimaryStatProfile()
    local cfg = CP:Config()
    local profile = detectedProfile()

    local stat = profile and profile.stat
    local statOverride = cfg.stat_highlight
    if statOverride == "off" then
        stat = nil
    elseif statOverride and statOverride ~= "auto" then
        stat = STAT_TOKENS[statOverride]
    end

    local combat = profile and profile.combat
    local combatOverride = cfg.combat_order
    if combatOverride == "off" then
        combat = nil
    elseif combatOverride and combatOverride ~= "auto" then
        combat = combatOverride
    end

    return stat, combat
end

local pane, scrollChild, ilvlRow, gsRow
local resistRows = {}

-- Sections in draw order, each owning its header and rows so collapsing one can re-flow the rest.
local layout = {}
local collapsed = {}
-- Snapshotted at build time, before any saved order is applied: what "default" resets back to.
local defaultOrder = {}

-- No +/- glyph: swapping the art made the header look like it shifted, and the glow says enough.
local HEADER_HL_ALPHA = 0.35

-- Reorder arrows, revealed only while the cursor is over their header: two chevrons on every bar at
-- rest would read as decoration and compete with the section names. Drawn from the action bar's
-- page arrows, cut from a 2x sheet: the scrollbar's are 17x11 of source art and came out chewed.
local MOVE_W, MOVE_H = 14, 12
local MOVE_X, MOVE_OFFSET = 165, 5
-- That art ships gold; the rest of the pane's small furniture is steel. Desaturated first, because
-- a cool vertex colour multiplied over gold only muddies it.
local MOVE_TINT = { 0.82, 0.85, 0.90 }
-- One arrow for both directions, flipped for the down one: the sheet's own down arrow is a separate
-- cut whose glyph does not sit at the same offset inside the cell, so the pair read as misaligned.
local MOVE_ATLAS = "ui-hud-actionbar-pageuparrow"
-- Present but faint until the cursor is actually on one, so the pair never shouts over the label.
local MOVE_ALPHA, MOVE_ALPHA_OVER = 0.45, 1

-- One texture sized outright: the viewport is always the art's native width, so slicing bought
-- nothing and cost a three-deep anchor chain that re-resolved on every frame of every collapse.
local function buildBar(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetSize(HEADER_W, HEADER_H)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    tex:set_atlas("UI-Character-Info-Title")
    return tex
end

-- Geometric, so it stays true over the arrows the header owns: their own OnLeave fires instead of
-- the header's, and hiding on that one would flicker the pair away under the cursor.
local function refreshHover(header)
    local over = header:IsMouseOver()
    for _, btn in ipairs(header.Move) do
        if over and btn._duiUsable then
            btn:SetAlpha(btn:IsMouseOver() and MOVE_ALPHA_OVER or MOVE_ALPHA)
            btn:Show()
        else
            btn:Hide()
        end
    end
end

local function applyArrow(tex, atlas, flip)
    tex:set_atlas(atlas)
    if not flip then return end
    local _, _, _, left, right, top, bottom = addon.functions.atlas_unpack(atlas)
    -- Swapping top and bottom mirrors the cell, so both directions are the very same glyph.
    if left then tex:SetTexCoord(left, right, bottom, top) end
end

local function buildMoveButton(header, delta, y, flip)
    local btn = CreateFrame("Button", nil, header)
    btn:SetSize(MOVE_W, MOVE_H)
    btn:SetPoint("LEFT", header, "LEFT", MOVE_X, y)
    btn:SetFrameLevel(header:GetFrameLevel() + 1)
    btn:Hide()

    local icon = btn:CreateTexture(nil, "OVERLAY")
    applyArrow(icon, MOVE_ATLAS .. "-normal", flip)
    icon:SetAllPoints(btn)
    icon:SetDesaturated(true)
    icon:SetVertexColor(unpack(MOVE_TINT))

    -- Its own glow rather than the same art blended over itself, which is what the sheet ships it for.
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    applyArrow(hl, MOVE_ATLAS .. "-highlight", flip)
    hl:SetAllPoints(btn)
    hl:SetDesaturated(true)
    hl:SetVertexColor(unpack(MOVE_TINT))
    hl:SetBlendMode("ADD")

    btn:SetScript("OnClick", function()
        if CP.MoveSidebarSection then CP.MoveSidebarSection(header.key, delta) end
    end)
    btn:SetScript("OnEnter", function() refreshHover(header) end)
    btn:SetScript("OnLeave", function() refreshHover(header) end)
    return btn
end

local function buildHeader(parent, key, text)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(HEADER_W, HEADER_H)

    header.Bg = buildBar(header, "ARTWORK", 0)

    local label = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetDrawLayer("ARTWORK", 1)
    label:SetPoint("CENTER", header, "CENTER", 0, 1)
    label:SetText(text)

    -- The bar's own art on HIGHLIGHT, so the glow has the bar's shape rather than a rectangle's.
    local hl = buildBar(header, "HIGHLIGHT")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(HEADER_HL_ALPHA)
    header.Hl = hl

    header:SetScript("OnClick", function()
        if CP.ToggleSidebarSectionAnimated then CP.ToggleSidebarSectionAnimated(key) end
    end)

    header.key = key
    header.MoveUp = buildMoveButton(header, -1, MOVE_OFFSET, false)
    header.MoveDown = buildMoveButton(header, 1, -MOVE_OFFSET, true)
    header.Move = { header.MoveUp, header.MoveDown }

    header:SetScript("OnEnter", function(self) refreshHover(self) end)
    header:SetScript("OnLeave", function(self) refreshHover(self) end)
    return header
end

-- Blizzard's setters address the label and value by global name, so each row has to be named
-- and carry <name>Label / <name>StatText children.
local function buildStatRow(parent, name, isEven, ownerStatIndex)
    local row = CreateFrame("Frame", name, parent)
    row:SetSize(ROW_W, ROW_H)

    -- A flat neutral wash, not the Line-Bounce strip: that art is brown and tints every other row.
    -- Left-anchored and widened past the row's own right edge rather than centered: the row stops
    -- ROW_INSET short of the scroll viewport, which reads closer to the left border than to the
    -- scrollbar. Bleeding the wash out to the viewport's clip edge (bleeding further gets clipped
    -- by the ScrollFrame) puts it the same distance from the scrollbar as the row is from the left.
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("LEFT", row, "LEFT", 0, 0)
    bg:SetSize(ROW_W + ROW_INSET, ROW_H)
    bg:SetTexture(1, 1, 1)
    bg:SetAlpha(0.05)
    if not isEven then bg:Hide() end
    row.Bg = bg

    -- Sublevel above the zebra wash, so the glow reads the same on odd and even rows.
    if ownerStatIndex then
        local hl = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        hl:SetPoint("LEFT", row, "LEFT", 0, 0)
        hl:SetSize(ROW_W + ROW_INSET, ROW_H)
        hl:SetTexture(1, 1, 1)
        hl:Hide()
        row.Highlight = hl
    end

    local label = row:CreateFontString(name .. "Label", "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 11, 0)

    local value = row:CreateFontString(name .. "StatText", "ARTWORK", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    row:EnableMouse(true)
    row:SetScript("OnEnter", PaperDollStatTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

-- Retail colours this by content tier, which 3.3.5a has no data for; the average quality of what is
-- equipped is the closest honest stand-in.
local ILVL_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

local function averageQuality()
    local total, count = 0, 0
    for _, slot in ipairs(ILVL_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local ok, _, _, quality = pcall(GetItemInfo, link)
            if ok and quality then
                total = total + quality
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return math.floor(total / count + 0.5)
end

-- A headline block rather than a label:value row: just the number, large and centred.
local function buildHeadlineRow(parent, name)
    local row = CreateFrame("Frame", name, parent)
    row:SetSize(ROW_W, 22)

    local value = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    value:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.Value = value

    row:EnableMouse(true)
    row:SetScript("OnEnter", PaperDollStatTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function buildResistRow(parent, index, school, isEven)
    local row = buildStatRow(parent, "DragonUIStatResist" .. index, isEven)
    row.school = school
    resistRows[index] = row
    return row
end

-- How far open each section is, 0 to 1. Separate from `collapsed`, which stays the logical state.
local progress = {}
local ANIM_DURATION = 0.18
local animator

local function openness(key)
    local p = progress[key]
    if p ~= nil then return p end
    return collapsed[key] and 0 or 1
end

-- Blizzard hides the 6th Ranged row itself, and the headline blocks are taller than a stat row.
local function sectionBlockHeight(section)
    local h = 0
    for _, row in ipairs(section.rows) do
        if not row._duiBlizzHidden then h = h + (row:GetHeight() or ROW_H) end
    end
    return h
end

-- Pixels each swapped section still has to travel back to its slot, and the rate that closes it.
-- Both halves share one duration whatever the distance; that is what reads as an exchange.
local slide, slideRate = {}, {}
local SLIDE_DURATION = 0.18
local raised

-- Same-level bars cross in creation order, which makes a swap look arbitrary; the section the
-- player clicked passes in front of the one it trades with.
local RAISE = 4

local function setSectionRaised(section, on)
    if not scrollChild then return end
    local base = scrollChild:GetFrameLevel()
    local lift = on and RAISE or 0
    section.header:SetFrameLevel(base + 2 + lift)
    for _, row in ipairs(section.rows) do
        row:SetFrameLevel(base + 1 + lift)
    end
end

local function stepAnimation(_, elapsed)
    local step = (elapsed or 0) / ANIM_DURATION
    local moving = false
    for _, section in ipairs(layout) do
        local key = section.key
        local target = collapsed[key] and 0 or 1
        local p = openness(key)
        if p ~= target then
            p = (p < target) and math.min(target, p + step) or math.max(target, p - step)
            progress[key] = p
            if p ~= target then moving = true end
        end
    end

    for key, offset in pairs(slide) do
        local delta = (slideRate[key] or 0) * (elapsed or 0)
        offset = (offset > 0) and math.max(0, offset - delta) or math.min(0, offset + delta)
        if offset == 0 then
            slide[key], slideRate[key] = nil, nil
        else
            slide[key] = offset
            moving = true
        end
    end

    if raised and not slide[raised.key] then
        setSectionRaised(raised, false)
        raised = nil
    end

    if CP.RelayoutSidebar then CP.RelayoutSidebar() end
    if not moving then animator:Hide() end
end

local function startAnimator()
    if not animator then
        animator = CreateFrame("Frame")
        animator:SetScript("OnUpdate", stepAnimation)
    end
    animator:Show()
end

-- Base Stats and Defense never move; only which combat category leads is class/spec-dependent.
local function orderedSections()
    local _, combatKey = CP.GetPrimaryStatProfile()
    if not combatKey then return SECTIONS end

    local base, defense, promoted, others = nil, nil, nil, {}
    for _, section in ipairs(SECTIONS) do
        if section.index == "PLAYERSTAT_BASE_STATS" then
            base = section
        elseif section.index == "PLAYERSTAT_DEFENSES" then
            defense = section
        elseif section.index == combatKey then
            promoted = section
        else
            others[#others + 1] = section
        end
    end
    if not promoted then return SECTIONS end

    local out = {}
    if base then out[#out + 1] = base end
    out[#out + 1] = promoted
    for _, section in ipairs(others) do out[#out + 1] = section end
    if defense then out[#out + 1] = defense end
    return out
end

local function defaultKeyOrder()
    local out = { "itemlevel", "gearscore" }
    for _, section in ipairs(orderedSections()) do out[#out + 1] = section.index end
    out[#out + 1] = "resistance"
    return out
end

-- Same rearrange applySavedOrder/ResetSidebarOrder already do: walk the wanted key order, pull
-- matching sections out of the current layout, then tack on anything the list didn't mention.
local function reorderLayoutTo(keyOrder)
    local byKey = {}
    for _, section in ipairs(layout) do byKey[section.key] = section end

    local sorted = {}
    for _, key in ipairs(keyOrder) do
        if byKey[key] then
            sorted[#sorted + 1] = byKey[key]
            byKey[key] = nil
        end
    end
    for _, section in ipairs(layout) do
        if byKey[section.key] then sorted[#sorted + 1] = section end
    end
    layout = sorted
end

local function saveCollapsed()
    local store = {}
    for _, section in ipairs(layout) do
        if collapsed[section.key] then store[section.key] = true end
    end
    CP:Config().stats_collapsed = store
end

local function saveOrder()
    local order = {}
    for i, section in ipairs(layout) do order[i] = section.key end
    CP:Config().stats_order = order
end

-- Freeze the openness before flipping the flag: otherwise the default openness IS the new target
-- the instant `collapsed` changes, and the animator stops on its first frame.
function CP.ToggleSidebarSectionAnimated(key)
    progress[key] = openness(key)
    collapsed[key] = not collapsed[key]
    saveCollapsed()
    startAnimator()
end

-- The ends of the list have nowhere to go, so their arrow is withheld rather than drawn dead. The
-- ends are the outermost SHOWN sections: a hidden one is not somewhere a section can be moved to.
local function refreshMoveButtons()
    local first, last
    for i, section in ipairs(layout) do
        if not section.hidden then
            first = first or i
            last = i
        end
    end
    for i, section in ipairs(layout) do
        local header = section.header
        if header and header.Move then
            header.MoveUp._duiUsable = first ~= nil and i > first
            header.MoveDown._duiUsable = last ~= nil and i < last
            refreshHover(header)
        end
    end
end

-- Mirrors the accumulation in flowSection; the two must agree or a swap animates to the wrong slot.
local function restingOffsets()
    local out, y = {}, 0
    for _, section in ipairs(layout) do
        if not section.hidden then
            out[section.key] = y
            y = y + HEADER_H + sectionBlockHeight(section) * openness(section.key) + SECTION_GAP
        end
    end
    return out
end

-- Where the sections are DRAWN, not where they rest, so a second click mid-slide carries on from
-- the current position instead of snapping back to the slot first.
local function drawnOffsets()
    local out = restingOffsets()
    for key, offset in pairs(slide) do
        if out[key] then out[key] = out[key] + offset end
    end
    return out
end

-- Walks every section, not just a swapped pair: a reset moves several at once, and one that did
-- not move comes out with a zero shift and is skipped anyway.
local function startSlide(before, lift)
    local after = restingOffsets()
    for _, section in ipairs(layout) do
        local key = section.key
        local shift = (before[key] or 0) - (after[key] or 0)
        if shift ~= 0 then
            slide[key] = shift
            slideRate[key] = math.abs(shift) / SLIDE_DURATION
        end
    end

    if raised then setSectionRaised(raised, false) end
    raised = lift
    if lift then setSectionRaised(lift, true) end
    startAnimator()
end

function CP.MoveSidebarSection(key, delta)
    local from
    for i, section in ipairs(layout) do
        if section.key == key then from = i break end
    end
    if not from then return end

    -- Steps over anything hidden, or a click beside a switched-off section would read as a no-op.
    local to = from + delta
    while layout[to] and layout[to].hidden do to = to + delta end
    if not layout[to] then return end

    -- Captured before the swap: the pair animates from where it was to where it now belongs.
    local before = drawnOffsets()
    local moved = layout[from]

    layout[from], layout[to] = layout[to], layout[from]
    saveOrder()
    refreshMoveButtons()
    startSlide(before, moved)
    CP.RelayoutSidebar()
end

-- Clearing the setting rather than storing the default order back: nothing stale is left to
-- reapply, and a later version that adds a category still gets to place it itself.
function CP.ResetSidebarOrder()
    if #defaultOrder == 0 then return end
    CP:Config().stats_order = nil

    local before = drawnOffsets()
    local byKey = {}
    for _, section in ipairs(layout) do byKey[section.key] = section end

    local sorted = {}
    for _, key in ipairs(defaultOrder) do
        if byKey[key] then
            sorted[#sorted + 1] = byKey[key]
            byKey[key] = nil
        end
    end
    for _, section in ipairs(layout) do
        if byKey[section.key] then sorted[#sorted + 1] = section end
    end
    layout = sorted

    refreshMoveButtons()
    -- Nothing lifted: a whole list re-flowing reads as a reset, not as one section being carried.
    startSlide(before)
    CP.RelayoutSidebar()
end

-- Re-picks the class/spec order (talents, form, or a Settings override may have changed) and re-flows.
-- A saved order is a hint the user set on purpose, so it still outranks this, same as applySavedOrder.
function CP.ApplyStatsAutoSort()
    if not scrollChild or CP:Config().stats_order then return end

    local before = drawnOffsets()
    reorderLayoutTo(defaultKeyOrder())

    -- Reset's baseline follows the live pick too, or resetting after a respec would restore the order
    -- computed at login instead of the one that matches the character right now.
    defaultOrder = {}
    for _, section in ipairs(layout) do defaultOrder[#defaultOrder + 1] = section.key end

    refreshMoveButtons()
    startSlide(before)
    CP.RelayoutSidebar()
end

-- A saved order is a hint, never the list itself: an unknown key is dropped and a section the saved
-- order predates keeps its build position, so a future section can never go missing.
local function applySavedOrder()
    local order = CP:Config().stats_order
    if type(order) ~= "table" then return end

    local byKey = {}
    for _, section in ipairs(layout) do byKey[section.key] = section end

    local sorted, taken = {}, {}
    for _, key in ipairs(order) do
        if byKey[key] and not taken[key] then
            taken[key] = true
            sorted[#sorted + 1] = byKey[key]
        end
    end
    for _, section in ipairs(layout) do
        if not taken[section.key] then sorted[#sorted + 1] = section end
    end
    layout = sorted
end

-- Seeded straight into `progress` as well: restored sections have to start at their resting state,
-- or every collapsed one would animate open on the first paint of the session.
local function applySavedCollapsed()
    local store = CP:Config().stats_collapsed
    if type(store) ~= "table" then return end
    for _, section in ipairs(layout) do
        collapsed[section.key] = store[section.key] and true or nil
        progress[section.key] = collapsed[section.key] and 0 or 1
    end
end

-- Item level reads `~= false` and GearScore reads plainly: the panel has always led with the item
-- level, so only the opt-in number defaults to off.
local function sectionVisible(key)
    local cfg = CP:Config()
    if key == "itemlevel" then return cfg.show_item_level ~= false end
    if key == "gearscore" then return cfg.show_gear_score and true or false end
    return true
end

function CP.ApplyGearSummaryVisibility()
    for _, section in ipairs(layout) do
        section.hidden = not sectionVisible(section.key)
    end
    refreshMoveButtons()
    -- A number that was hidden holds whatever it last read, so it is filled before it is revealed.
    if CP.RefreshSidebar then CP.RefreshSidebar() end
    CP.RelayoutSidebar()
end

-- Re-flows every section from the top. Widths come from the viewport rather than a constant: when
-- the scrollbar drops out the viewport grows, and fixed-width content anchored TOPRIGHT would slide.
local relayouting

function CP.RelayoutSidebar()
    if not scrollChild or relayouting then return end
    relayouting = true

    -- One anchor plus an explicit size everywhere, never two opposing anchors on something sized:
    -- the relayout re-anchors on every frame of a collapse and the engine reconciles both each time.
    local width = math.floor(scrollChild:GetWidth() or 0)
    if width <= 0 then width = HEADER_W end
    local rowWidth = width - ROW_INSET * 2

    -- Laid out one section at a time so a section the settings have switched off can drop out of the
    -- flow entirely rather than reserving its bar's height.
    local function flowSection(section, y)
        local open = openness(section.key)
        local header = section.header
        -- A section mid-swap is drawn away from its slot while everything below it stays put.
        local drawY = y + (slide[section.key] or 0)

        header:Show()
        header:SetSize(width, HEADER_H)
        if header.Bg then header.Bg:SetSize(width, HEADER_H) end
        if header.Hl then header.Hl:SetSize(width, HEADER_H) end
        header:ClearAllPoints()
        header:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -drawY)

        local blockH = sectionBlockHeight(section)

        -- Rows never move; they are uncovered as the block's edge sweeps past, each fading over its
        -- own height. Sliding the stack made rows surface above the bar before disappearing.
        local revealed = blockH * open
        local offset = 0
        for _, row in ipairs(section.rows) do
            if row._duiBlizzHidden then
                row:Hide()
            else
                local h = row:GetHeight() or ROW_H
                -- Sized even while hidden, or a row collapsed at the last width returns with the old one.
                row:SetWidth(rowWidth)
                if row.Bg then row.Bg:SetWidth(rowWidth + ROW_INSET) end
                if row.Highlight then row.Highlight:SetWidth(rowWidth + ROW_INSET) end
                if offset >= revealed then
                    row:Hide()
                else
                    row:ClearAllPoints()
                    row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -ROW_INSET,
                                 -(drawY + HEADER_H + offset))
                    row:SetAlpha(math.min(1, (revealed - offset) / h))
                    row:Show()
                end
                offset = offset + h
            end
        end
        return y + HEADER_H + revealed + SECTION_GAP
    end

    local y = 0
    for _, section in ipairs(layout) do
        if section.hidden then
            section.header:Hide()
            for _, row in ipairs(section.rows) do row:Hide() end
        else
            y = flowSection(section, y)
        end
    end
    scrollChild:SetHeight(math.max(1, y))
    if CP.SyncScrollThumb then CP.SyncScrollThumb(_G.DragonUICharacterStatsScroll) end
    relayouting = false
end

-- The class plate is opaque and dark at full strength, so at alpha 1 it buries the pane. Just over
-- half reads as a crest showing through the rock and keeps the stat text legible.
local CLASS_BG_ALPHA = 0.55

local function applyClassBackground()
    if not pane then return end
    local _, classFile = UnitClass("player")
    if not classFile then return end

    local atlas = "ui-character-info-" .. classFile:lower() .. "-bg"
    if not addon.atlasinfo[atlas] then return end

    local bg = pane._duiClassBg
    if not bg then
        -- Below every other background piece, not level with them.
        bg = pane:CreateTexture(nil, "BACKGROUND", nil, -3)
        bg:SetAlpha(CLASS_BG_ALPHA)
        pane._duiClassBg = bg
    end
    -- set_atlas stamps the width too, so the spanning anchors go on afterwards and win.
    bg:set_atlas(atlas, true)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    bg:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
end

local function buildSidebar()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.InsetRight then return end

    pane = CreateFrame("Frame", "DragonUICharacterStatsPane", cf.InsetRight)
    pane:SetPoint("TOPLEFT", cf.InsetRight, "TOPLEFT", 3, -3)
    pane:SetPoint("BOTTOMRIGHT", cf.InsetRight, "BOTTOMRIGHT", -3, 2)

    local scroll = CreateFrame("ScrollFrame", "DragonUICharacterStatsScroll", pane,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -SCROLLBAR_GUTTER, 0)
    -- Deliberately does NOT hide, unlike every other pane: hiding it frees the gutter, and a width
    -- that changes on the same event as a collapse reads as the header stretching on its own.

    if CP.ReskinScrollBar then CP.ReskinScrollBar(scroll, pane) end

    scrollChild = CreateFrame("Frame", "DragonUICharacterStatsScrollChild", scroll)
    scrollChild:SetWidth(HEADER_W)
    scroll:SetScrollChild(scrollChild)

    -- Re-derived rather than trusted: one pixel of overhang brings the sideways slide back.
    scroll:HookScript("OnSizeChanged", function(_, w)
        if not (w and w > 0) or w == scrollChild:GetWidth() then return end
        scrollChild:SetWidth(w)
        -- We are normally already inside a relayout, so let it finish and re-flow next frame -- or
        -- the new width never reaches the rows.
        if relayouting then
            addon:After(0, function()
                if CP.RelayoutSidebar then CP.RelayoutSidebar() end
            end)
        elseif CP.RelayoutSidebar then
            CP.RelayoutSidebar()
        end
    end)

    applyClassBackground()

    local function addSection(key, text, rows)
        local header = buildHeader(scrollChild, key, text)
        -- Above the rows, so a folding section slides up behind its own bar instead of over it.
        header:SetFrameLevel(scrollChild:GetFrameLevel() + 2)
        layout[#layout + 1] = { key = key, header = header, rows = rows }
    end

    -- Item level leads the list as its own headline stat, the way retail does. GearScore is the
    -- same block under its own header, so either can be switched off or reordered on its own.
    ilvlRow = buildHeadlineRow(scrollChild, "DragonUIStatItemLevel")
    addSection("itemlevel", addon.L["Item Level"], { ilvlRow })

    gsRow = buildHeadlineRow(scrollChild, "DragonUIStatGearScore")
    addSection("gearscore", addon.L["GearScore"], { gsRow })

    for _, section in ipairs(SECTIONS) do
        local rows = {}
        local isBaseStats = section.index == "PLAYERSTAT_BASE_STATS"
        for i = 1, ROWS_PER_SECTION do
            rows[i] = buildStatRow(scrollChild, section.prefix .. i, i % 2 == 0,
                                   isBaseStats and i <= 5 and i or nil)
        end
        addSection(section.index, _G[section.index] or section.index, rows)
    end

    local resists = {}
    for i, school in ipairs(RESIST_SCHOOLS) do
        resists[i] = buildResistRow(scrollChild, i, school, i % 2 == 0)
    end
    addSection("resistance", RESISTANCE_LABEL, resists)

    -- Class/spec order becomes the baseline "default" a saved order overrides and Reset returns to.
    reorderLayoutTo(defaultKeyOrder())
    for _, section in ipairs(layout) do defaultOrder[#defaultOrder + 1] = section.key end

    applySavedOrder()
    applySavedCollapsed()
    CP.ApplyGearSummaryVisibility()

    CP.RelayoutSidebar()
    CP._sidebar = pane
end

local function resistanceLevel(resistance)
    local level = max(UnitLevel("player") or 1, 20)
    local ratio = resistance / level
    if ratio > 5 then return RESISTANCE_EXCELLENT end
    if ratio > 3.75 then return RESISTANCE_VERYGOOD end
    if ratio > 2.5 then return RESISTANCE_GOOD end
    if ratio > 1.25 then return RESISTANCE_FAIR end
    if ratio > 0 then return RESISTANCE_POOR end
    return RESISTANCE_NONE
end

-- Mirrors PaperDollFrame_SetResistances, the "( base +x -y )" breakdown tooltip included.
local function refreshResistances()
    for _, row in ipairs(resistRows) do
        local school = row.school
        local base, resistance, positive, negative = UnitResistance("player", school)
        local name = row:GetName()
        local schoolName = _G["RESISTANCE" .. school .. "_NAME"] or ""

        _G[name .. "Label"]:SetText(format(STAT_FORMAT, schoolName))

        local text = tostring(resistance)
        if abs(negative) > positive then
            text = RED_FONT_COLOR_CODE .. resistance .. FONT_COLOR_CODE_CLOSE
        elseif abs(negative) < positive then
            text = GREEN_FONT_COLOR_CODE .. resistance .. FONT_COLOR_CODE_CLOSE
        end
        _G[name .. "StatText"]:SetText(text)

        local tooltip = format(PAPERDOLLFRAME_TOOLTIP_FORMAT, schoolName) .. " " .. resistance
        if positive ~= 0 or negative ~= 0 then
            tooltip = tooltip .. " ( " .. HIGHLIGHT_FONT_COLOR_CODE .. base
            if positive > 0 then tooltip = tooltip .. GREEN_FONT_COLOR_CODE .. " +" .. positive end
            if negative < 0 then tooltip = tooltip .. " " .. RED_FONT_COLOR_CODE .. negative end
            tooltip = tooltip .. FONT_COLOR_CODE_CLOSE .. " )"
        end
        row.tooltip = tooltip
        row.tooltip2 = format(RESISTANCE_TOOLTIP_SUBTEXT, _G["RESISTANCE_TYPE" .. school] or "",
                              max(UnitLevel("player") or 1, 20), resistanceLevel(resistance))
    end
end

local function colorByAverageQuality(fontString)
    local quality = averageQuality()
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        fontString:SetTextColor(color.r, color.g, color.b)
    else
        fontString:SetTextColor(1, 0.82, 0)
    end
end

-- Both refreshes walk every equipped slot, and the stat events behind them fire throughout a fight,
-- so a switched-off number is skipped rather than computed into a hidden row.
local function refreshItemLevel()
    if not ilvlRow or CP:Config().show_item_level == false then return end

    local average = addon.GetAverageItemLevel and addon.GetAverageItemLevel("player")
    ilvlRow.Value:SetText(average and tostring(average) or "--")
    colorByAverageQuality(ilvlRow.Value)

    ilvlRow.tooltip = addon.L["Item Level"]
    ilvlRow.tooltip2 = addon.L["Average item level of your equipped gear."]
end

-- Shares the item level's colour rather than GearScore's own ramp: two different scales sitting one
-- above the other read as a contradiction when they disagree on the same gear.
local function refreshGearScore()
    if not gsRow or not CP:Config().show_gear_score then return end

    local score = CP.GetGearScore and CP.GetGearScore("player") or 0
    gsRow.Value:SetText(score > 0 and tostring(score) or "--")
    colorByAverageQuality(gsRow.Value)

    gsRow.tooltip = addon.L["GearScore"]
    gsRow.tooltip2 = addon.L["Weighted score of your equipped gear."]
end

-- SECTIONS[1] is Base Stats by construction; that's the only section its 5 rows can highlight.
local function refreshStatHighlight()
    local statIndex = CP.GetPrimaryStatProfile()
    local _, classToken = UnitClass("player")
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]

    for i = 1, 5 do
        local row = _G[SECTIONS[1].prefix .. i]
        local hl = row and row.Highlight
        if hl then
            if statIndex == i then
                if color then
                    hl:SetVertexColor(color.r, color.g, color.b)
                else
                    hl:SetVertexColor(1, 0.82, 0)
                end
                hl:SetAlpha(0.22)
                hl:Show()
            else
                hl:Hide()
            end
        end
    end
end

local function refresh()
    if not pane then return end
    refreshItemLevel()
    refreshGearScore()

    for _, section in ipairs(SECTIONS) do
        UpdatePaperdollStats(section.prefix, section.index)
        -- Capture what Blizzard chose to hide before the re-flow overwrites visibility.
        for i = 1, ROWS_PER_SECTION do
            local row = _G[section.prefix .. i]
            if row then row._duiBlizzHidden = not row:IsShown() end
        end
    end

    refreshStatHighlight()
    refreshResistances()
    CP.RelayoutSidebar()
end

-- PaperDollFrame's OnShow hook outlives a disable, and re-widening CharacterFrame for a sidebar the
-- restore has already put away is what left the window stretched with nothing in the gap.
local function expand()
    local cf = _G.CharacterFrame
    if not cf or not CP:CanLayout() or not CP:Enabled() then return end
    buildSidebar()
    if not pane then return end
    cf:SetWidth(EXPANDED_WIDTH)
    cf.InsetRight:Show()
    refresh()

    -- The pane is created visible, so re-assert whichever sidebar tab the user last picked.
    if CP.ShowSidebarPane and CP.SelectedSidebarTab then
        CP.ShowSidebarPane(CP.SelectedSidebarTab())
    end
    if CP.RestyleSidebarTabs then CP.RestyleSidebarTabs() end
end

local function collapse(keepWidth)
    local cf = _G.CharacterFrame
    if not cf or not CP:CanLayout() or not CP:Enabled() then return end
    -- This runs after SetInsetForTab, so forcing the narrow width here would silently undo it.
    if not keepWidth then cf:SetWidth(CP.PANEL_WIDTH) end
    if cf.InsetRight then cf.InsetRight:Hide() end
end

-- Deliberately ungated, unlike collapse(): the module flag is already off by the time a restore
-- runs, so anything that asks CP:Enabled() first would decline to clean up after itself.
function CP.RestoreSidebar()
    local cf = _G.CharacterFrame
    if cf and cf.InsetRight then cf.InsetRight:Hide() end
    -- Hand the average back to itemlevel.lua, which has been holding it hidden for us.
    if addon.SetCharacterAverageSuppressed then addon.SetCharacterAverageSuppressed(false) end
    if CP.SetSidebarTabsShown then CP.SetSidebarTabsShown(false) end
end

-- Only PaperDoll gets the stats pane; the list tabs manage their own width.
local function applyForTab(tabName)
    local isPaperDoll = tabName == "PaperDollFrame"
    if isPaperDoll then expand() else collapse(CP.OWNED_TABS[tabName]) end
    if CP.SetSidebarTabsShown then CP.SetSidebarTabsShown(isPaperDoll) end
end

CP.ExpandSidebar = expand
CP.CollapseSidebar = collapse
CP.ApplySidebarForTab = applyForTab
CP.RefreshSidebar = refresh
CP.EXPANDED_WIDTH = EXPANDED_WIDTH

local events = CreateFrame("Frame")
events:RegisterEvent("UNIT_STATS")
events:RegisterEvent("UNIT_ATTACK_POWER")
events:RegisterEvent("UNIT_RANGED_ATTACK_POWER")
events:RegisterEvent("UNIT_RESISTANCES")
events:RegisterEvent("UNIT_ATTACK")
events:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
events:RegisterEvent("COMBAT_RATING_UPDATE")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
-- Only Feral's Cat/Bear split needs this, and every other class fires it too (stances share the API).
if select(2, UnitClass("player")) == "DRUID" then
    events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end
events:SetScript("OnEvent", function(_, event, unit)
    -- None of these three carry a unit arg, so they can't share the generic unit-check branch below.
    if event == "CHARACTER_POINTS_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
       or event == "UPDATE_SHAPESHIFT_FORM" then
        CP.ApplyStatsAutoSort()
        if pane and pane:IsVisible() then refresh() end
        return
    end
    if unit and unit ~= "player" then return end
    if pane and pane:IsVisible() then refresh() end
end)

CP:RegisterBuilder("sidebar", function()
    if not _G.PaperDollFrame then return end
    -- Ours replaces the overlay itemlevel.lua draws across the model.
    if addon.SetCharacterAverageSuppressed then addon.SetCharacterAverageSuppressed(true) end
    if _G.PaperDollFrame:IsShown() then expand() end
    if not _G.PaperDollFrame._duiSidebarHooked then
        _G.PaperDollFrame._duiSidebarHooked = true
        _G.PaperDollFrame:HookScript("OnShow", function() expand() end)
    end
end)
