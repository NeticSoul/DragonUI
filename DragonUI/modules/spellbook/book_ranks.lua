-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule
local tr = addon.L

local ipairs, pairs = ipairs, pairs

local ARROW = "common-dropdown-a-button"
local GRID = Book.GRID
-- Body width 0.55 of the icon, as in the owner's reference; the art's body is 19 x 21 of 27 x 27.
local ART_SCALE = 0.55 * GRID.iconSize / 19
local CANVAS = 27 * ART_SCALE
local BODY_W, BODY_H, BODY_LEFT, BODY_TOP = 19 * ART_SCALE, 21 * ART_SCALE, 4 * ART_SCALE, 1 * ART_SCALE
local BODY_RISE = GRID.iconButton / 10 + 6 * GRID.iconButton / 40
local PLACE = { large = true, at = "BOTTOM", x = 0, y = -4 }

local casters, home = {}, nil
local owner, hooked

-- Menu rows ---------------------------------------------------------------------------------------

local function rankTip(tip, entry)
    tip:SetSpell(entry.rank.index, "spell")
    Book.MarkBars(entry.rank, tip:GetOwner())
end

-- The catalog lists lower ranks from the one just below the card down to rank 1; rows keep that.
function Book.RankMenuEntries(lower, casterFor)
    local entries = { { text = tr["Lower Ranks"], isTitle = true } }
    for number, rank in ipairs(lower) do
        entries[number + 1] = {
            text = rank.sub ~= "" and rank.sub or rank.name,
            icon = rank.icon,
            rank = rank,
            tooltip = rankTip,
            overlay = casterFor and casterFor(number, rank),
        }
    end
    return entries
end

-- Secure row surfaces -----------------------------------------------------------------------------

local function casterPostClick(surface)
    local rank = surface.rank
    if not rank then return end
    if IsModifiedClick("CHATLINK") then
        Book.InsertLink(rank)
        return
    end
    if IsModifiedClick("PICKUPACTION") then Book.PickUp(rank) end
    addon.Menu.Close()
end

local function casterDrag(surface)
    Book.PickUp(surface.rank)
    addon.Menu.Close()
end

-- Home is a hidden child of the root, so a surface handed back by the menu can never be clicked.
local function caster(number)
    if casters[number] then return casters[number] end
    if not home then
        home = CreateFrame("Frame", nil, Book.root)
        home:Hide()
        home:SetAllPoints(Book.root)
    end
    local surface = CreateFrame("Button", nil, home, "SecureActionButtonTemplate")
    surface:SetSize(16, 16)
    surface:SetPoint("TOPLEFT", home, "TOPLEFT", 0, 0)
    surface:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    surface:RegisterForDrag("LeftButton")
    Book.ArmCaster(surface)
    surface:SetAttribute("type2", "spell")
    surface:SetScript("PostClick", casterPostClick)
    surface:SetScript("OnDragStart", casterDrag)
    casters[number] = surface
    return surface
end

-- Out of combat only, right before the menu lends it to a row.
local function casterFor(number, rank)
    local surface = caster(number)
    surface:SetAttribute("spell", rank.spellID)
    surface.rank = rank
    return surface
end

-- Card button -------------------------------------------------------------------------------------

local function paintKnob(knob)
    local state = ""
    if addon.Menu.IsOpenFor(knob) then
        state = "-open"
    elseif knob.pressed then
        state = knob.over and "-pressedhover" or "-pressed"
    elseif knob.over then
        state = "-hover"
    end
    knob.art:SetAtlasTexture(ARROW .. state)
end

-- The menu closes itself on outside presses without telling its opener.
local function menuHidden()
    local knob = owner
    owner = nil
    if knob then paintKnob(knob) end
end

local function toggle(knob)
    if Book.RefuseInCombat() then return end
    if addon.Menu.IsOpenFor(knob) then
        addon.Menu.Close()
        return
    end
    Book.CloseFlyout()
    local entry = knob.card.entry
    -- Book indices are stale until the queued rebuild lands; the next frame has fresh ones.
    if Book.stale or not (entry and entry.lower) then return end
    owner = knob
    addon.Menu.Open(knob, Book.RankMenuEntries(entry.lower, casterFor), PLACE)
    if not hooked then
        hooked = true
        _G.DragonUIMenu:HookScript("OnHide", menuHidden)
    end
    PlaySound("igMainMenuOptionCheckBoxOn")
    paintKnob(knob)
end

function Book.CloseRanks()
    if Book.Locked() then return end
    if owner and addon.Menu.IsOpenFor(owner) then addon.Menu.Close() end
    Book.CloseFlyout()
end

function Book.RankStyle()
    return Book.Config().rankSelector == "dropdown" and "dropdown" or "flyout"
end

-- Saves a style if given; always closes an open selector and repaints (also after the on/off one).
function addon.RefreshSpellbookRankSelector(style)
    if style == "dropdown" or style == "flyout" then Book.Config().rankSelector = style end
    if not Book.applied then return end
    Book.CloseRanks()
    if Book.IsOpen() then Book.Sync(false) end
end

local BUTTON_SCRIPTS = {
    OnClick = toggle,
    OnEnter = function(knob)
        knob.over = true
        paintKnob(knob)
    end,
    OnLeave = function(knob)
        knob.over, knob.pressed = false, false
        paintKnob(knob)
    end,
    OnMouseDown = function(knob)
        knob.pressed = true
        paintKnob(knob)
    end,
    OnMouseUp = function(knob)
        knob.pressed = false
        paintKnob(knob)
    end,
}

function Book.BuildRankButton(card)
    -- The button is the art's visible body; its larger canvas hangs around it.
    local knob = CreateFrame("Button", nil, card)
    knob:SetSize(BODY_W, BODY_H)
    -- Body top well above the icon button's bottom: the gold frame's lower rim crosses its upper part.
    knob:SetPoint("TOP", card.well, "BOTTOM", 0, BODY_RISE)
    -- Above the icon's secure slot as well, since its top laps over the slot's lower edge.
    knob:SetFrameLevel(Book.Level("cardRanks"))
    knob:RegisterForClicks("LeftButtonUp")
    knob.card = card
    knob.art = knob:CreateTexture(nil, "ARTWORK")
    knob.art:SetSize(CANVAS, CANVAS)
    knob.art:SetPoint("TOPLEFT", knob, "TOPLEFT", -BODY_LEFT, BODY_TOP)
    for event, handler in pairs(BUTTON_SCRIPTS) do
        knob:SetScript(event, handler)
    end
    knob:Hide()
    card.ranks = knob
    paintKnob(knob)
    Book.BuildFlyoutTab(card)
end

function Book.DressRankButton(card)
    local entry, flyout = card.entry, Book.RankStyle() == "flyout"
    local offered = Book.Config().rankSelectorShown ~= false and entry.lower ~= nil and entry.book == "spell"
        and not entry.passive and not entry.grey
    Book.DressFlyoutTab(card, offered and flyout)
    card.ranks:SetShownCompat(offered and not flyout)
    paintKnob(card.ranks)
end
