-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local L = addon.L
local Art = P.Art
local Prof = P.Professions
local Catchers = Prof.Catchers
local Overview = { cards = {}, buttons = {}, primary = {}, primaries = {}, offset = 0 }
P.Overview = Overview

-- Side tabs hold catchers 1-14 and the tracker 40 up; a card per primary can need dozens here.
local CATCHER_BASE = 200
-- Primary cards overlap by 5; while they scroll they give up GUTTER on the right to the scroll bar.
local CARD_W, CARD_H, BANNER_W = 664, 142, 332
local STRIDE, GUTTER = 137, 16
-- Clip at the cards' top border line: clear of the window portrait, and the card above stays hidden.
local CLIP_TOP = 6
-- Forever's order: SecondaryProfession1..3 = cooking, fishing, first aid.
local SECONDARY = { "Cooking", "Fishing", "FirstAid" }
-- The book's ProfessionsRankBarTemplate overrides: an 18-high frame with its 23-high art hanging from the top.
local BAR_W, SMALL_BAR_W = 441, 190
local FRAME_H, ART_H, FILL_H = 18, 23, 18
-- overrideMaskRightOffset per width: the mask stops this short of bar width x progress.
-- Not Forever's -5 on the small bar: its three-sliced frame keeps the rim 3 in, so -5 ran past it.
local MASK_OFFSET = { [BAR_W] = -7, [SMALL_BAR_W] = -7 }

-- GameFontHighlightSmall2 (11 pt) does not exist in 3.3.5a.
local missingFont = CreateFont("DragonUI_ProfessionsMissingFont")
missingFont:CopyFontObject(GameFontHighlightSmall)
do
    local path, _, flags = GameFontHighlightSmall:GetFont()
    missingFont:SetFont(path, 11, flags)
end

-- PROFESSIONS_*_MISSING in Forever.
local MISSING = {
    Cooking = L["Visit a trainer to learn cooking. Cooking lets you learn recipes to create food that heals you out of combat and grants you temporary buffs."],
    Fishing = L["Visit a trainer to learn fishing. Fishing lets you catch fish and other strange things from water. Fish can be cooked into delicious meals with the Cooking skill."],
    FirstAid = L["Visit a trainer to learn first aid. First aid lets you turn cloth into bandages for healing yourself and others."],
}

-- TRADESKILL_NAME_RANK(_WITH_MODIFIER): the book's bars use the same rank text as the crafting page.
local function rankPrefix(p)
    local rank = tostring(p.rank or 0)
    if p.modifier and p.modifier > 0 then rank = rank .. " |cff20ff20(+" .. p.modifier .. ")|r" end
    return string.format("%s %s", p.skillName or "", rank)
end

local function newBar(parent, width)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, FRAME_H)
    local art = CreateFrame("Frame", nil, bar)
    art:SetPoint("TOPLEFT")
    art:SetSize(width, ART_H)
    -- The full 441 art at overrideFillAnchorLeft = 2 on both widths: the small bars uncover its left part, unsquashed.
    bar.fx = P.Fill.Create(art, width, MASK_OFFSET[width], FILL_H)
    bar.fx:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -3)
    -- Forever's frame is the top sublevel of the fill's layer; here it needs a frame over the fill stack.
    local over = CreateFrame("Frame", nil, art)
    over:SetAllPoints()
    over:SetFrameLevel(bar.fx:GetFrameLevel() + 1)
    if width == BAR_W then
        -- Forever stretches the 374-wide art to the override width.
        bar.bg = art:CreateTexture(nil, "BACKGROUND")
        Art.Set(bar.bg, "progress-bg")
        bar.bg:SetAllPoints()
        bar.frame = over:CreateTexture(nil, "ARTWORK")
        Art.Set(bar.frame, "progress-frame")
        bar.frame:SetAllPoints()
    else
        Art.ThreeSlice(art, "BACKGROUND", "progress-bg", 12)
        Art.ThreeSlice(over, "ARTWORK", "progress-frame", 12)
    end
    -- The template's Rank frame sits 3 below the bar's centre.
    bar.rank = Art.RankText(over)
    bar.rank:SetCenter(bar, "CENTER", 0, -3)
    return bar
end

local function setBar(bar, p)
    local maxRank = p.maxRank or 0
    local ratio = maxRank > 0 and math.min((p.rank or 0) / maxRank, 1) or 0
    P.Fill.Update(bar.fx, p.key, ratio, maxRank > 0 and (p.rank or 0) >= maxRank)
    bar.rank:Set(rankPrefix(p), p.maxRank or 0)
end

local function spellTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local link = button.spell and GetSpellLink(button.spell)
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(button.spell or "", 1, 1, 1)
    end
    if InCombatLockdown() then GameTooltip:AddLine(L["Not available in combat"], 1, 0.125, 0.125) end
    GameTooltip:Show()
end

local function newSpellButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(40, 40)
    -- 36 inside the 40 button, bevel cropped: the frame's ring then sits just outside the icon instead of over it.
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.border = b:CreateTexture(nil, "OVERLAY")
    Art.Set(b.border, "square-frame", true)
    b.border:SetPoint("CENTER", b, "CENTER", -0.5, -0.5)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.name:SetWidth(100)
    b.name:SetJustifyH("LEFT")
    b.name:SetPoint("LEFT", b, "RIGHT", 5, 7)
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.sub:SetWidth(95)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1)
    b.highlight = b:CreateTexture(nil, "OVERLAY")
    b.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    b.highlight:SetBlendMode("ADD")
    -- ProfessionButtonTemplate's highlight covers the icon; ours is inset, so it follows the icon, not the button.
    b.highlight:SetAllPoints(b.icon)
    b.highlight:Hide()
    b:SetScript("OnEnter", function(self)
        self.highlight:Show()
        spellTooltip(self)
        Catchers.ArmFor(self)
    end)
    b:SetScript("OnLeave", function(self) self.highlight:Hide() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
        if InCombatLockdown() then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1, 1) end
    end)
    -- ProfessionSpellButtonMixin:OnDragStart: the spell goes onto the cursor, for the action bars.
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) Prof.PickupSpell(self.spell) end)
    Overview.buttons[#Overview.buttons + 1] = b
    b.catcherId = CATCHER_BASE + #Overview.buttons
    return b
end

local function setSpell(b, spell)
    b.spell = spell
    if not spell then
        b:Hide()
        return
    end
    local _, rank, icon = GetSpellInfo(spell)
    b.icon:SetTexture(icon or GetSpellTexture(spell))
    b.name:SetText(spell)
    b.sub:SetText(rank or "")
    b:Show()
end

-- Main spell first (the craft, or Fishing's cast), then the profession's extra spells.
local function spellsOf(p)
    local list = {}
    if p.craftSpell then
        list[1] = p.craftSpell
    elseif p.entry.castsRank and p.rankSpell then
        list[1] = p.rankSpell
    end
    for _, s in ipairs(p.spells) do list[#list + 1] = s end
    return list
end

local function unlearnClick(self)
    local card = self:GetParent()
    local p = card.prof
    if not p or not p.skillName then return end
    local index = Prof.SkillIndex(p.skillName)
    if index then StaticPopup_Show("UNLEARN_SKILL", p.skillName, nil, index) end
end

local function newPrimary(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    local layout = P.ArtLayout
    card.bgLeft = card:CreateTexture(nil, "BACKGROUND")
    Art.Set(card.bgLeft, "banner-left", true)
    card.bgLeft:SetPoint("TOPLEFT")
    card.bgRight = card:CreateTexture(nil, "BACKGROUND")
    Art.Set(card.bgRight, "banner-right", true)
    card.bgRight:SetPoint("TOPLEFT", card, "TOPLEFT", layout.bannerSplit, 0)
    local left, top, _, bottom, right = card.bgRight:GetTexCoord()
    card.bgRightCoords = { left, right, top, bottom }
    card.draw = card:CreateTexture(nil, "BORDER")
    card.draw:SetPoint("TOPLEFT", card, "TOPLEFT", layout.bannerDraw[1], layout.bannerDraw[2])
    card.name = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -24)
    card.missing = card:CreateFontString(nil, "ARTWORK")
    card.missing:SetFontObject(missingFont)
    card.missing:SetJustifyH("LEFT")
    card.missing:SetWidth(485)
    card.missing:SetPoint("CENTER")
    card.bar = newBar(card, BAR_W)
    card.bar:SetPoint("RIGHT", card, "RIGHT", -40, 0)

    local unlearn = CreateFrame("Button", nil, card)
    unlearn:SetSize(20, 20)
    unlearn:SetPoint("LEFT", card.bar, "RIGHT", 1, -4)
    -- ProfessionsUnlearnButtonMixin: no highlight art; the cross rests at 0.75, lights to 1, shifts 1 on press.
    unlearn.icon = unlearn:CreateTexture(nil, "ARTWORK")
    Art.Set(unlearn.icon, "unlearn", true)
    unlearn.icon:SetPoint("CENTER")
    unlearn.icon:SetAlpha(0.75)
    unlearn:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", self, "CENTER", 1, -1) end)
    unlearn:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", self, "CENTER", 0, 0) end)
    unlearn:SetScript("OnClick", unlearnClick)
    unlearn:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(UNLEARN_SKILL_TOOLTIP)
        GameTooltip:Show()
    end)
    unlearn:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(0.75)
        self.icon:SetPoint("CENTER", self, "CENTER", 0, 0)
        GameTooltip:Hide()
    end)
    card.unlearn = unlearn

    card.spellButtons = { newSpellButton(card), newSpellButton(card) }
    return card
end

local function newSecondary(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(225, 275)
    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.name = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    card.name:SetPoint("TOP", card, "TOP", 0, -25)
    card.missing = card:CreateFontString(nil, "ARTWORK")
    card.missing:SetFontObject(missingFont)
    card.missing:SetJustifyH("LEFT")
    card.missing:SetWidth(175)
    card.missing:SetJustifyV("TOP")
    card.missing:SetPoint("TOP", card.name, "BOTTOM", 5, -13)
    card.bar = newBar(card, SMALL_BAR_W)
    card.bar:SetPoint("TOP", card, "TOP", 0, -47)
    card.spellButtons = {}
    for i = 1, 4 do
        local b = newSpellButton(card)
        if i == 1 then
            b:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 20, 25)
        else
            b:SetPoint("BOTTOM", card.spellButtons[i - 1], "TOP", 0, 0)
        end
        card.spellButtons[i] = b
    end
    return card
end

-- The right banner loses part of its plain left edge (a seam under 1/255 off), so the border stays.
local function fitCard(card, width)
    if card.fitWidth == width then return end
    card.fitWidth = width
    local cut, c, layout = CARD_W - width, card.bgRightCoords, P.ArtLayout
    card:SetWidth(width)
    card.bgRight:SetWidth(BANNER_W - cut)
    card.bgRight:SetTexCoord(c[1] + (c[2] - c[1]) * cut / BANNER_W, c[2], c[3], c[4])
    card.draw:SetPoint("TOPLEFT", card, "TOPLEFT", layout.bannerDraw[1] - cut, layout.bannerDraw[2])
end

local function primaryCard(i)
    local card = Overview.primary[i]
    if not card then
        card = newPrimary(Overview.child)
        card:SetPoint("TOPLEFT", Overview.child, "TOPLEFT", 0, CLIP_TOP - (i - 1) * STRIDE)
        Overview.primary[i] = card
    end
    return card
end

-- Clipped cards still take the mouse, so only the two resting in view keep it.
local function setInteractive(card, on)
    for _, b in ipairs(card.spellButtons) do
        b:EnableMouse(on)
        if not on then
            b.highlight:Hide()
            if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
        end
    end
    card.unlearn:EnableMouse(on)
    if not on and GameTooltip:IsOwned(card.unlearn) then GameTooltip:Hide() end
end

local function settle()
    local o = Overview.offset
    for i, card in ipairs(Overview.primary) do setInteractive(card, i == o + 1 or i == o + 2) end
end

function Overview.Build()
    local page = P.Frame.overview
    local c = Overview.cards
    -- 3.3.5a has no SetClipsChildren, so the primary cards ride in a scroll frame for its clipping.
    local view = CreateFrame("ScrollFrame", nil, page)
    view:SetPoint("TOPLEFT", P.Frame.win, "TOPLEFT", 5, -41 - CLIP_TOP)
    view:SetSize(CARD_W, CARD_H + STRIDE - CLIP_TOP)
    local child = CreateFrame("Frame", nil, view)
    child:SetSize(CARD_W, CARD_H + STRIDE - CLIP_TOP)
    view:SetScrollChild(child)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function(_, delta) Overview.ScrollTo(Overview.offset - delta) end)
    Overview.view, Overview.child = view, child
    c[1], c[2] = primaryCard(1), primaryCard(2)
    c[3] = newSecondary(page)
    c[3]:SetPoint("TOPLEFT", view, "BOTTOMLEFT", 0, 4)
    c[4] = newSecondary(page)
    c[4]:SetPoint("TOPLEFT", c[3], "TOPRIGHT", -6, 0)
    c[5] = newSecondary(page)
    c[5]:SetPoint("TOPLEFT", c[4], "TOPRIGHT", -6, 0)

    -- Some servers allow more than two primaries; the bar then takes the column the cards give up.
    local bar = addon.ForeverUI.CreateScrollBar(page, {})
    -- Arrows included it spans the banners' border lines (6 down, 4 up), 2 right of the cards' line.
    bar:SetPoint("TOPLEFT", view, "TOPRIGHT", -4, CLIP_TOP - 25)
    bar:SetHeight(CARD_H + STRIDE - 10 - 38)
    bar:SetFrameLevel(view:GetFrameLevel() + 10)
    bar:HookScript("OnValueChanged", function(self, value)
        if not self.silent then Overview.ScrollTo(math.floor(value + 0.5)) end
    end)
    bar.upButton:SetScript("OnClick", function() Overview.ScrollTo(Overview.offset - 1) end)
    bar.downButton:SetScript("OnClick", function() Overview.ScrollTo(Overview.offset + 1) end)
    bar:Hide()
    Overview.bar = bar
end

local function fillSpells(card, p)
    local spells = p and spellsOf(p) or {}
    for i, b in ipairs(card.spellButtons) do setSpell(b, spells[i]) end
    return #spells
end

-- Forever: a lone spell sits at 46; with two, the main one goes to 60 and the second under it at 10.
local function placePrimarySpells(card, count)
    local first, second = card.spellButtons[1], card.spellButtons[2]
    first:ClearAllPoints()
    second:ClearAllPoints()
    first:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 15, count == 1 and 46 or 60)
    second:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 15, 10)
end

local function fillPrimary(card, p, slot)
    card.prof = p
    local learned = p ~= nil
    card.name:SetText(learned and p.skillName or (slot == 1 and L["First Profession"] or L["Second Profession"]))
    local drawing = learned and Art.BannerDrawing(p.key)
    if drawing then Art.Set(card.draw, drawing, true) end
    card.draw:SetShownCompat(drawing and true or false)
    card.missing:SetText(learned and "" or L["Visit a profession trainer in a major city to learn a new profession. You may have two professions. You may have any combination of gathering and production professions."])
    card.bar:SetShownCompat(learned)
    card.unlearn:SetShownCompat(learned)
    if learned then setBar(card.bar, p) end
    placePrimarySpells(card, fillSpells(card, p))
end

local function fillSecondary(card, key, p)
    card.prof = p
    local entry
    for _, e in ipairs(Prof.CATALOG) do
        if e.key == key then entry = e end
    end
    local learned = p ~= nil
    card.name:SetText(learned and p.skillName or GetSpellInfo(entry.ranks[1]))
    Art.Set(card.bg, Art.Small(key))
    card.missing:SetText(learned and "" or MISSING[key] or "")
    card.bar:SetShownCompat(learned)
    if learned then setBar(card.bar, p) end
    fillSpells(card, p)
end

function Overview.Bind()
    if InCombatLockdown() then
        Overview.pendingBind = true
        return
    end
    Overview.pendingBind = false
    local shown = P.Frame.page == "overview" and TradeSkillFrame:IsShown()
    for _, b in ipairs(Overview.buttons) do
        if shown and b.spell and b:IsVisible() then
            -- The catcher covers the button while hovered, so the drag starts on the catcher.
            Catchers.Bind(b.catcherId, b, b.spell, {
                onDrag = function() Prof.PickupSpell(b.spell) end,
                onEnter = function() b.highlight:Show() spellTooltip(b) end,
                onLeave = function()
                    b.highlight:Hide()
                    if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
                end,
            })
        else
            Catchers.Unbind(b.catcherId)
        end
    end
end

local function syncBar()
    local bar, o = Overview.bar, Overview.offset
    local maxOff = math.max(0, #Overview.primaries - 2)
    if maxOff == 0 then
        bar:Hide()
        return
    end
    bar.silent = true
    bar:SetMinMaxValues(0, maxOff)
    bar:SetValue(o)
    bar.silent = nil
    addon.ForeverUI.SetScrollBarFraction(bar, 2 / #Overview.primaries)
    if o > 0 then bar.upButton:Enable() else bar.upButton:Disable() end
    if o < maxOff then bar.downButton:Enable() else bar.downButton:Disable() end
    bar:Show()
end

-- One card per primary; with more than two they narrow for the bar and the view scrolls.
local function layoutPrimaries()
    local list, view = Overview.primaries, Overview.view
    local count = math.max(2, #list)
    local width = count > 2 and CARD_W - GUTTER or CARD_W
    Overview.offset = math.max(0, math.min(count - 2, Overview.offset))
    for i = 1, count do
        local card = primaryCard(i)
        fitCard(card, width)
        fillPrimary(card, list[i], i)
        card:Show()
    end
    for i = count + 1, #Overview.primary do
        Overview.primary[i]:Hide()
        Overview.primary[i].prof = nil
    end
    view:SetWidth(width)
    Overview.child:SetSize(width, CARD_H - CLIP_TOP + (count - 1) * STRIDE)
    view:UpdateScrollChildRect()
    view:SetScript("OnUpdate", nil)
    view:SetVerticalScroll(Overview.offset * STRIDE)
    syncBar()
    settle()
end

-- Eases toward the resting offset, a card at a time; the cards take the mouse back once it lands.
local function glide(view, elapsed)
    local target, now = Overview.offset * STRIDE, view:GetVerticalScroll()
    if math.abs(target - now) < 1 then
        view:SetVerticalScroll(target)
        view:SetScript("OnUpdate", nil)
        settle()
        Overview.Bind()
    else
        view:SetVerticalScroll(now + (target - now) * math.min(1, elapsed * 16))
    end
end

function Overview.ScrollTo(offset)
    local maxOff = math.max(0, #Overview.primaries - 2)
    offset = math.max(0, math.min(maxOff, offset))
    if offset == Overview.offset then return end
    Overview.offset = offset
    -- An armed catcher would stay put while the card under it slides away.
    Catchers.HideAll()
    for _, card in ipairs(Overview.primary) do setInteractive(card, false) end
    syncBar()
    Overview.view:SetScript("OnUpdate", glide)
end

function Overview.Refresh()
    if not Overview.cards[1] then return end
    local primaries, byKey = {}, {}
    for _, p in ipairs(Prof.Discover()) do
        if p.kind == "primary" then primaries[#primaries + 1] = p end
        byKey[p.key] = p
    end
    Overview.primaries = primaries
    layoutPrimaries()
    for i, key in ipairs(SECONDARY) do
        fillSecondary(Overview.cards[2 + i], key, byKey[key])
    end
    Overview.Bind()
end

P.On("Built", Overview.Build)

P.On("Page", function(page)
    if page == "overview" then
        Overview.Refresh()
    elseif Overview.cards[1] then
        Overview.Bind()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if not (P.active and P.Frame.built and TradeSkillFrame:IsShown() and P.Frame.page == "overview") then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if Overview.pendingBind then Overview.Bind() end
    elseif not Prof.IsEcho() then
        Overview.Refresh()
    end
end)
