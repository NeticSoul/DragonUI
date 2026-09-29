-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule
local tr = addon.L

local floor, max, ipairs, pairs, next, tonumber = math.floor, math.max, ipairs, pairs, next, tonumber
local tip = GameTooltip

local cards, headers = {}, {}

local GRID = Book.GRID
local TEXT_LEFT, TEXT_RIGHT = GRID.iconButton + 10, 4
local TEXT_W = GRID.cardW - TEXT_LEFT - TEXT_RIGHT
-- Icon art offsets below are measured on a 40-unit icon button and grow with it.
local GROW = GRID.iconButton / 40
local nameLine, subLine = 16, 13

local SHAPES = {
    square = {
        ring = "spellbook-item-iconframe", hover = "spellbook-item-iconframe-hover",
        scroll = "spellbook-item-needtrainer-iconframe-backplate", -11, 1, 1, -7,
    },
    squareOff = {
        ring = "spellbook-item-iconframe-inactive", hover = "spellbook-item-iconframe-hover",
        scroll = "spellbook-item-needtrainer-iconframe-backplate", -10, 1, 2, -5,
    },
    round = {
        ring = "talents-node-circle-gray", hover = "spellbook-item-iconframe-passive-hover",
        scroll = "spellbook-item-needtrainer-passive-backplate", 0, 0, 0, 0,
    },
}

local SPARK_SIZES = { 13, 10, 7, 4 }
local SPARK_LAPS = { 8, 16, 24, 32 }

-- Shared helpers ----------------------------------------------------------------------------------

-- The template guarantees a font even if the size change below were ever refused.
function Book.InkLabel(parent, layer, fontObject, size)
    local ink = parent:CreateFontString(nil, layer, fontObject)
    ink:SetFont((_G[fontObject]:GetFont()), size)
    ink:SetTextColor(Book.INK[1], Book.INK[2], Book.INK[3])
    ink:SetShadowColor(0, 0, 0, 0)
    ink:SetShadowOffset(0, 0)
    ink:SetJustifyH("LEFT")
    return ink
end

local SHAPE_PARTS = { "ring", "hover", "scroll" }

local function onWell(piece, well, shape)
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", well, "TOPLEFT", shape[1] * GROW, shape[2] * GROW)
    piece:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", shape[3] * GROW, shape[4] * GROW)
end

-- After a book change the recorded slot may hold another spell; identity is spellID or pet name.
local function sameSpell(entry, index)
    if entry.book == "pet" then return GetSpellName(index, "pet") == entry.name end
    return Book.LinkSpellID(GetSpellLink(index, "spell")) == entry.spellID
end

local function indexHolds(card)
    if not Book.stale then return true end
    if card.epoch ~= Book.epoch then
        card.epoch = Book.epoch
        card.holds = sameSpell(card.entry, card.entry.index)
    end
    return card.holds
end

-- Animation: one driver, running only while something is animating ------------------------------

local animator
local tracks = {}

function Book.Animate(name, step)
    tracks[name] = step
    animator:Show()
end

local function animate(self, elapsed)
    for name, step in pairs(tracks) do
        if not step(elapsed) then tracks[name] = nil end
    end
    if not next(tracks) then self:Hide() end
end

local glowClock, sparkClock = 0, 0

local function glowStep(elapsed)
    glowClock = (glowClock + elapsed) % 1
    local u = glowClock < 0.5 and 1 - glowClock / 0.5 or (glowClock - 0.5) / 0.5
    local alpha = 1 - 0.5 * u * u
    local any = false
    for slot = 1, Book.SLOTS do
        local card = cards[slot]
        if card and card:IsShown() and card.glow:IsShown() then
            card.glow:SetAlpha(alpha)
            any = true
        end
    end
    return any
end

local function perimeter(t, side)
    local u = (t % 1) * 4
    local edge = floor(u)
    local f = u - edge
    if edge == 0 then return f * side, 0 end
    if edge == 1 then return side, -f * side end
    if edge == 2 then return side - f * side, -side end
    return 0, f * side - side
end

local function sparkStep(elapsed)
    sparkClock = sparkClock + elapsed
    local any = false
    for slot = 1, Book.SLOTS do
        local card = cards[slot]
        local sparks = card and card:IsShown() and card.sparks
        if sparks and sparks:IsShown() then
            any = true
            local side = sparks:GetWidth()
            for _, dot in ipairs(sparks.dots) do
                dot:SetPoint("CENTER", sparks, "TOPLEFT", perimeter(sparkClock / dot.lap + dot.lane, side))
            end
        end
    end
    return any
end

-- Action bars -------------------------------------------------------------------------------------

function Book.ScanActionBars()
    local bound = {}
    for action = 1, 120 do
        local kind, index, _, spellID = GetActionInfo(action)
        if kind == "spell" then
            local name = tonumber(spellID) and GetSpellInfo(tonumber(spellID)) or GetSpellName(index, "spell")
            if name then bound[name] = true end
        end
    end
    Book.bound = bound
end

-- Card construction -------------------------------------------------------------------------------

local function buildSparks(card)
    local sparks = CreateFrame("Frame", nil, card)
    sparks:SetFrameLevel(Book.Level("cardSparks"))
    sparks:SetAllPoints(card.icon)
    sparks.dots = {}
    for lane = 0, 3 do
        for size = 1, 4 do
            local dot = sparks:CreateTexture(nil, "ARTWORK")
            dot:SetSize(SPARK_SIZES[size] * GROW, SPARK_SIZES[size] * GROW)
            dot:SetTexture("Interface\\ItemSocketingFrame\\UI-ItemSockets")
            dot:SetBlendMode("ADD")
            dot:SetTexCoord(0.3984375, 0.4453125, 0.40234375, 0.44921875)
            dot.lap, dot.lane = SPARK_LAPS[size], lane / 4
            sparks.dots[#sparks.dots + 1] = dot
        end
    end
    sparks:Hide()
    return sparks
end

local function buildCard(slot)
    local card = CreateFrame("Button", nil, Book.stage)
    card:SetSize(Book.GRID.cardW, Book.GRID.cardH)
    card:SetFrameLevel(Book.Level("content"))
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:Hide()

    local well = CreateFrame("Frame", nil, card)
    well:SetSize(GRID.iconButton, GRID.iconButton)
    well:SetPoint("LEFT", card, "LEFT", 0, 0)
    card.well = well

    card.plate = card:CreateTexture(nil, "BACKGROUND")
    card.plate:SetAtlasTexture("spellbook-item-backplate", true)
    card.plate:SetPoint("CENTER", card, "CENTER", 5, -5)

    card.halo = card:CreateTexture(nil, "BORDER")
    card.halo:SetAtlasTexture("spellbook-item-needtrainer-shadow")
    card.halo:SetSize(56 * GROW, 56 * GROW)
    card.halo:SetPoint("CENTER", well, "CENTER", 0, 0)

    card.scroll = card:CreateTexture(nil, "ARTWORK")
    card.icon = card:CreateTexture(nil, "OVERLAY")
    card.icon:SetSize(GRID.iconSize, GRID.iconSize)
    card.icon:SetPoint("CENTER", well, "CENTER", 0, 0)

    card.name = Book.InkLabel(card, "OVERLAY", "GameFontHighlightLarge", 16)
    card.name:SetWidth(TEXT_W)
    card.name:SetPoint("TOPLEFT", well, "TOPRIGHT", 10, -1)
    card.sub = Book.InkLabel(card, "OVERLAY", "GameFontNormalSmall", 13)
    card.sub:SetWidth(TEXT_W)
    card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -2)

    card.sweep = CreateFrame("Cooldown", nil, card)
    card.sweep:SetFrameLevel(Book.Level("cardSweep"))
    card.sweep:SetPoint("TOPLEFT", card.icon, "TOPLEFT", 2 * GROW, -2 * GROW)
    card.sweep:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", -2 * GROW, 2 * GROW)

    local rings = CreateFrame("Frame", nil, card)
    rings:SetFrameLevel(Book.Level("cardRing"))
    rings:SetAllPoints(card)
    card.ring = rings:CreateTexture(nil, "ARTWORK")
    card.corners = rings:CreateTexture(nil, "OVERLAY")
    card.corners:SetAtlasTexture("spellbook-item-petautocast-corners")
    card.corners:SetPoint("TOPLEFT", card.icon, "TOPLEFT", 0, -1.5 * GROW)
    card.corners:SetPoint("BOTTOMRIGHT", card.icon, "BOTTOMRIGHT", -1.5 * GROW, 1 * GROW)

    card.sparks = buildSparks(card)

    local shine = CreateFrame("Frame", nil, card)
    shine:SetFrameLevel(Book.Level("cardGlow"))
    shine:SetAllPoints(card)
    card.glow = shine:CreateTexture(nil, "ARTWORK")
    card.glow:SetPoint("TOPLEFT", well, "TOPLEFT", -4 * GROW, 3 * GROW)
    card.glow:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", 3 * GROW, -3 * GROW)
    card.glow:SetAtlasTexture("spellbook-item-unassigned-glow")
    card.glow:SetBlendMode("ADD")
    card.hover = shine:CreateTexture(nil, "OVERLAY")
    card.hover:SetBlendMode("ADD")

    card.extras = { card.sweep, card.corners, card.sparks, card.glow }
    Book.BuildRankButton(card)
    card:SetScript("OnEnter", Book.CardEnter)
    card:SetScript("OnLeave", Book.CardLeave)
    card:SetScript("OnClick", Book.CardClick)

    if slot == 1 then
        card.name:SetText("Wg")
        nameLine = card.name:GetStringHeight()
        card.sub:SetText("Wg")
        subLine = card.sub:GetStringHeight()
    end
    card.sub:SetHeight(subLine + 1)
    cards[slot] = card
    return card
end

function Book.BuildCards()
    animator = CreateFrame("Frame", nil, Book.root)
    animator:Hide()
    animator:SetScript("OnUpdate", animate)
    buildCard(1)
end

-- Painting ----------------------------------------------------------------------------------------

local function paintHover(card)
    local entry = card.entry
    local live = entry ~= nil and not entry.grey
    card.plate:SetAlpha(live and card.over and 1 or 0.25)
    local level = 0
    if live and (card.selected or card.pressed) then
        level = 0.65
    elseif live and card.over then
        level = 0.35
    end
    card.hover:SetAlpha(level)
end

function Book.SetCardPointer(card, over, pressed)
    card.over, card.pressed = over, pressed
    paintHover(card)
end

local function paintIcon(card, path)
    if not path then return end
    if card.entry.passive then
        SetPortraitToTexture(card.icon, path)
        card.icon:SetTexCoord(0, 1, 0, 1)
    else
        card.icon:SetTexture(path)
        card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function trainerSuffix(trainer)
    if not trainer.from then return "" end
    local text
    if trainer.to and trainer.to ~= trainer.from then
        text = tr["Ranks %d-%d at trainer"]:format(trainer.from, trainer.to)
    else
        text = tr["Rank %d at trainer"]:format(trainer.from)
    end
    return "  |cff0f730f" .. text .. "|r"
end

local function withRank(entry, note)
    return entry.rank .. "  (" .. note .. ")"
end

local function greySubtitle(entry)
    local ranked = entry.higherRank and entry.rank ~= ""
    if entry.state == "talent" then
        return ranked and withRank(entry, tr["Requires talent"]) or tr["Requires talent"]
    end
    if entry.needs then return ITEM_REQ_SKILL:format(GetSpellInfo(entry.needs) or "") end
    local detailed = ranked and entry.allRanks
    if entry.state == "ready" then
        return detailed and withRank(entry, tr["Trainable"]) or tr["Trainable"]
    end
    if detailed then return withRank(entry, LEVEL_GAINED:format(entry.level)) end
    return tr["Available at level %d"]:format(entry.level)
end

local function subtitle(entry)
    if entry.grey then return greySubtitle(entry) end
    local text = entry.sub
    if entry.rankLevel then text = text .. "  (" .. LEVEL_GAINED:format(entry.rankLevel) .. ")" end
    if entry.trainer then text = text .. trainerSuffix(entry.trainer) end
    return text
end

-- With flyout tabs on, every card's text stops 2 short of the next card's tab reaching into it.
function Book.CardTextWidth()
    if Book.Config().rankSelectorShown == false or Book.RankStyle() ~= "flyout" then return TEXT_W end
    local intrusion = Book.FlyoutTabReach() - GRID.columnGap
    return GRID.cardW - TEXT_LEFT - max(TEXT_RIGHT, intrusion + 2)
end

-- No line-count cap on this client: a two-line height lets the engine add the ellipsis.
local function fitName(card)
    local height = card.name:GetStringHeight()
    if height > nameLine * 2 then height = nameLine * 2 end
    card.name:SetHeight(height + 1)
end

local function paintStates(card, jobs)
    if card.entry.grey then return end
    local entry, fresh = card.entry, indexHolds(card)
    if jobs.cooldown then
        local since, span, usable
        if fresh then
            since, span, usable = GetSpellCooldown(entry.index, entry.book)
        else
            since, span, usable = GetSpellCooldown(entry.spellID or entry.name)
        end
        CooldownFrame_SetTimer(card.sweep, since or 0, span or 0, usable or 0)
        -- Parity with the stock book: only the cooldown's third value dims the icon.
        local shade = usable == 0 and 0.4 or 1
        card.icon:SetVertexColor(shade, shade, shade)
    end
    if jobs.icons then
        if fresh then
            paintIcon(card, GetSpellTexture(entry.index, entry.book))
        elseif entry.spellID then
            paintIcon(card, (select(3, GetSpellInfo(entry.spellID))))
        end
    end
    if jobs.selection then
        if fresh then
            card.selected = IsSelectedSpell(entry.index, entry.book) and true or false
        else
            card.selected = IsSelectedSpell(entry.name) and true or false
        end
        paintHover(card)
    end
    if jobs.autocast and entry.book == "pet" and fresh then
        local allowed, enabled = GetSpellAutocast(entry.index, "pet")
        card.corners:SetShownCompat(allowed)
        card.sparks:SetShownCompat(enabled)
        if enabled then Book.Animate("sparks", sparkStep) end
    end
    if jobs.glow then
        local lonely = Book.Config().highlightUnbound and entry.book == "spell" and not entry.passive
            and not Book.bound[entry.name]
        card.glow:SetShownCompat(lonely)
        if lonely then Book.Animate("glow", glowStep) end
    end
end

local EVERYTHING = { cooldown = true, icons = true, selection = true, autocast = true, glow = true }

function Book.PaintCard(card, entry)
    card.entry = entry
    card.epoch = nil
    local grey = entry.grey
    -- The client cannot tell whether an unlearned spell is passive, so grey cards are all square.
    local shape = SHAPES[grey and "squareOff" or (entry.passive and "round" or "square")]
    for _, part in ipairs(SHAPE_PARTS) do
        onWell(card[part], card.well, shape)
        card[part]:SetAtlasTexture(shape[part])
    end

    local trainer
    if grey then trainer = entry.state == "ready" else trainer = entry.trainer ~= nil end
    card.halo:SetShownCompat(trainer)
    card.scroll:SetShownCompat(trainer)

    paintIcon(card, entry.icon)
    card.icon:SetVertexColor(1, 1, 1)
    card.icon:SetDesaturated(grey)
    local alpha = grey and 0.6 or 1
    card.icon:SetAlpha(alpha)
    card.name:SetAlpha(alpha)
    card.sub:SetAlpha(alpha)
    local width = Book.CardTextWidth()
    card.name:SetWidth(width)
    card.sub:SetWidth(width)
    card.name:SetHeight(0)
    card.name:SetText(entry.name)
    fitName(card)
    card.sub:SetText(subtitle(entry))

    for _, extra in ipairs(card.extras) do
        extra:Hide()
    end
    card.selected = false
    paintStates(card, EVERYTHING)
    paintHover(card)
    Book.DressRankButton(card)
end

function Book.RefreshVisible(jobs)
    if jobs.money and tip:IsShown() then
        for slot = 1, Book.SLOTS do
            local card = cards[slot]
            if card and tip:IsOwned(card) and card.entry and card.entry.grey then Book.CardEnter(card) end
        end
    end
    if jobs.rebuild then jobs = EVERYTHING end
    if jobs.glow then Book.ScanActionBars() end
    for slot = 1, Book.SLOTS do
        local card = cards[slot]
        if card and card:IsShown() and card.entry then paintStates(card, jobs) end
    end
end

-- Headers -----------------------------------------------------------------------------------------

local function buildHeader()
    local header = CreateFrame("Frame", nil, Book.stage)
    header:SetSize(Book.GRID.viewW, Book.GRID.headerH)
    -- A header's plate reaches up over the previous row, so headers sit a level below the cards.
    header:SetFrameLevel(Book.Level("header"))

    local plate = header:CreateTexture(nil, "BACKGROUND")
    plate:SetAtlasTexture("spellbook-list-backplate")
    plate:SetSize(416, 106)
    plate:SetPoint("LEFT", header, "LEFT", -85, 10)
    plate:SetAlpha(0.65)

    local rule = header:CreateTexture(nil, "BORDER")
    rule:SetAtlasTexture("spellbook-divider")
    rule:SetHeight(11)
    rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -32, 0)
    rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -60, 0)

    header.title = Book.InkLabel(header, "ARTWORK", "GameFontNormalHuge", 24)
    header.title:SetPoint("TOPLEFT", header, "TOPLEFT", -8, 0)
    header.title:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -60, 0)
    header.title:SetJustifyV("MIDDLE")
    headers[#headers + 1] = header
    return header
end

-- Drawing one spread ------------------------------------------------------------------------------

function Book.DrawSpread(cat, page)
    local model = Book.models[cat]
    local spread = model and model.spreads[page]
    local stage = Book.stage
    for slot = 1, Book.SLOTS do
        local cell = spread and spread.cards[slot]
        local card = cards[slot]
        if cell then
            card = card or buildCard(slot)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", stage, "TOPLEFT", cell.x, cell.y)
            Book.PaintCard(card, cell.entry)
            card:Show()
        elseif card then
            card:Hide()
            card.entry, card.over, card.pressed = nil, false, false
        end
    end
    local count = spread and #spread.headers or 0
    for number = 1, math.max(count, #headers) do
        local item = spread and spread.headers[number]
        local banner = headers[number]
        if item then
            banner = banner or buildHeader()
            banner:ClearAllPoints()
            banner:SetPoint("TOPLEFT", stage, "TOPLEFT", item.x, item.y)
            banner.title:SetText(item.title)
            banner:Show()
        elseif banner then
            banner:Hide()
        end
    end
end

-- Paging swaps the spell under a pointer that has not moved; hover and tooltip follow the new card.
function Book.RefreshHoverTooltip()
    local hovered
    for slot = 1, Book.SLOTS do
        local card = cards[slot]
        if card and card:IsShown() then
            local over = card:IsMouseOver() and true or false
            if over ~= (card.over and true or false) then Book.SetCardPointer(card, over, false) end
            if over then hovered = card end
        end
    end
    if hovered then return Book.CardEnter(hovered) end
    local owner = tip:GetOwner()
    for slot = 1, Book.SLOTS do
        if owner ~= nil and owner == cards[slot] then return tip:Hide() end
    end
end

function Book.FirstShownKey()
    local card = cards[1]
    return card and card:IsShown() and card.entry and card.entry.key or nil
end

-- Tooltips ----------------------------------------------------------------------------------------

local function costColor(cost)
    if GetMoney() < cost then return 1, 0.13, 0.13 end
    return 1, 1, 1
end

-- Costs are the trainer list's own, before any reputation discount.
local function greyTooltip(entry)
    tip:SetHyperlink("spell:" .. entry.spellID)
    local gold = NORMAL_FONT_COLOR
    local level = Book.PlayerLevel() < entry.level and TRAINER_REQ_LEVEL_RED or TRAINER_REQ_LEVEL
    tip:AddLine(REQUIRES_LABEL .. " " .. level:format(entry.level), gold.r, gold.g, gold.b)
    tip:AddDoubleLine(tr["Training Cost"], GetMoneyString(entry.cost), gold.r, gold.g, gold.b, costColor(entry.cost))
    if entry.state == "talent" then tip:AddLine(tr["Requires talent"], 1, 0.1, 0.1) end
    if entry.needs then tip:AddLine(ITEM_REQ_SKILL:format(GetSpellInfo(entry.needs) or ""), 1, 0.1, 0.1) end
end

function Book.CardEnter(card)
    local shown = card.entry
    if shown == nil then return end
    Book.SetCardPointer(card, true, card.pressed)
    tip:SetOwner(card, "ANCHOR_RIGHT")
    local keepFresh
    if shown.grey then
        greyTooltip(shown)
    elseif indexHolds(card) then
        keepFresh = tip:SetSpell(shown.index, shown.book)
    elseif shown.spellID then
        tip:SetHyperlink("spell:" .. shown.spellID)
    else
        tip:SetText(shown.name)
    end
    if shown.trainer then
        tip:AddLine(tr["Available from your class trainer"], 0.1, 1, 0.1)
    end
    -- GameTooltip_OnUpdate calls this back every 0.2 s so cooldowns and costs stay current.
    card.UpdateTooltip = keepFresh and Book.CardEnter or nil
    tip:Show()
end

function Book.CardLeave(card)
    Book.SetCardPointer(card, false, false)
    if tip:IsOwned(card) then tip:Hide() end
end

-- Clicks ------------------------------------------------------------------------------------------

local function liveIndex(entry)
    if not Book.stale or sameSpell(entry, entry.index) then return entry.index end
    if entry.book == "pet" then
        for index = 1, Book.PetBook() or 0 do
            if sameSpell(entry, index) then return index end
        end
        return nil
    end
    local _, _, offset, count = GetSpellTabInfo(GetNumSpellTabs())
    for index = 1, (offset or 0) + (count or 0) do
        if sameSpell(entry, index) then return index end
    end
end

function Book.InsertLink(entry)
    if entry.grey then
        ChatEdit_InsertLink((GetSpellLink(entry.spellID)))
        return
    end
    local index = liveIndex(entry)
    local macros = _G.MacroFrame
    if macros and macros:IsShown() then
        if entry.passive then return end
        local name, sub = entry.name, entry.sub
        if index then name, sub = GetSpellName(index, entry.book) end
        if sub and sub ~= "" then name = name .. "(" .. sub .. ")" end
        ChatEdit_InsertLink(name)
        return
    end
    local link, tradeLink
    if index then
        link, tradeLink = GetSpellLink(index, entry.book)
    else
        link, tradeLink = GetSpellLink(entry.spellID or entry.name)
    end
    ChatEdit_InsertLink(tradeLink or link)
end

-- Plain pickup, out of combat only; card drags in combat go through the slots' secure drag handler.
function Book.PickUp(entry)
    if Book.Locked() or not entry or entry.grey or entry.passive then return end
    local index = liveIndex(entry)
    if index then PickupSpell(index, entry.book) end
end

function Book.CardClick(card)
    if card.entry and IsModifiedClick("CHATLINK") then Book.InsertLink(card.entry) end
end

function Book.SlotPostClick(slot)
    local card = cards[slot:GetID()]
    local clicked = card and card.entry
    if clicked == nil then return end
    if IsModifiedClick("CHATLINK") then
        Book.InsertLink(clicked)
    elseif IsModifiedClick("PICKUPACTION") then
        Book.PickUp(clicked)
    end
    Book.Queue("selection")
end

function Book.SlotEnter(slot)
    local card = cards[slot:GetID()]
    if card and card:IsShown() then Book.CardEnter(card) end
end

function Book.SlotLeave(slot)
    local card = cards[slot:GetID()]
    if card then Book.CardLeave(card) end
end

function Book.SlotPress(slot)
    local card = cards[slot:GetID()]
    if card and card.entry then Book.SetCardPointer(card, card.over, true) end
end

function Book.SlotRelease(slot)
    local card = cards[slot:GetID()]
    if card and card.entry then Book.SetCardPointer(card, card.over, false) end
end
