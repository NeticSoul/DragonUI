-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs, pairs, max, min, cos, acos, pi = ipairs, pairs, math.max, math.min, math.cos, math.acos, math.pi
local tip = GameTooltip

local RUNG, GAP, INSET, TALL = 30, 4, 9, 42
local OPEN_TIME, CLOSE_TIME, FADE_TIME, VEIL_TIME = 0.28, 0.22, 0.15, 0.08
-- The narrowest strip drawn: cap and edge side by side, nothing between them.
local SHORTEST = 29 + 5
-- The tab and the strip's tuck under the icon are measured on a 40-unit icon button.
local GROW = Book.GRID.iconButton / 40
local TAB_W, TAB_H, TAB_OUT, TUCK = 16 * GROW, 28 * GROW, 13 * GROW, 4 * GROW
-- How far the closed tab reaches left of its icon button, into the gap and the previous column.
function Book.FlyoutTabReach()
    return TAB_OUT + TAB_W / 2
end

-- Open, the tab's open end reaches 3 into the strip, over the cap's 2 transparent units.
local TAB_TIP = TAB_W / 2 - 3
local CAP = "ui-hud-actionbar-iconframe-flyoutbutton-2x"
local ARROWS = {
    rest = "ui-hud-actionbar-flyout-2x",
    over = "ui-hud-actionbar-flyout-mouseover-2x",
    down = "ui-hud-actionbar-flyout-down-2x",
}

local rungs = {}
local strip, motion

-- Turned atlas cells ------------------------------------------------------------------------------

-- Eight texcoords name the drawn corners UL, LL, UR, LR; "left" means the art's top now faces left.
local function paintTurned(tex, atlas, facing)
    local info = addon.atlasinfo[atlas]
    local l, r, t, b = info[4], info[5], info[6], info[7]
    tex:SetTexture(info[1])
    if facing == "left" then
        tex:SetTexCoord(r, t, l, t, r, b, l, b)
    elseif facing == "right" then
        tex:SetTexCoord(l, b, r, b, l, t, r, t)
    elseif facing == "down" then
        tex:SetTexCoord(r, b, r, t, l, b, l, t)
    else
        tex:SetTexCoord(l, r, t, b)
    end
end

-- Geometry ----------------------------------------------------------------------------------------

-- Book units; room is the icon's distance to the screen's left edge. Entry 1 sits by the icon.
function Book.FlyoutLayout(count, iconLeft, iconRight, room)
    local width = 2 * INSET + count * RUNG + (count - 1) * GAP
    local leftward = room >= width + 8
    local stripLeft = iconRight - TUCK
    if leftward then stripLeft = iconLeft + TUCK - width end
    local spots = {}
    for number = 1, count do
        local reach = INSET + (number - 1) * (RUNG + GAP)
        if leftward then spots[number] = stripLeft + width - reach - RUNG else spots[number] = stripLeft + reach end
    end
    return leftward, stripLeft, width, spots
end

-- Sine ease-in-out growth from the icon; the close plays the same curve backwards over its span.
function Book.FlyoutWidthAt(clock, full, closing)
    local u = min(1, max(0, clock / (closing and CLOSE_TIME or OPEN_TIME)))
    if closing then u = 1 - u end
    return SHORTEST + (full - SHORTEST) * (1 - cos(pi * u)) / 2
end

-- Clock at which a close reaches this width, so a close can start from wherever the strip is.
function Book.FlyoutCloseClock(width, full)
    local shown = min(1, max(0, (width - SHORTEST) / (full - SHORTEST)))
    return CLOSE_TIME * (1 - acos(1 - 2 * shown) / pi)
end

-- The strip fades in over its first moments and out over its last: its narrowest width never pops.
function Book.FlyoutVeil(clock, closing)
    if closing then return min(1, max(0, (CLOSE_TIME - clock) / VEIL_TIME)) end
    return min(1, max(0, clock / VEIL_TIME))
end

-- Strip width at which entry n (1 = the one by the icon) is fully uncovered.
function Book.FlyoutEntryReach(number)
    return 2 * INSET + number * RUNG + (number - 1) * GAP
end

function Book.FlyoutFadeStep(alpha, elapsed, uncovered)
    if uncovered then return min(1, alpha + elapsed / FADE_TIME) end
    return max(0, alpha - elapsed / FADE_TIME)
end

-- Tab by the icon ---------------------------------------------------------------------------------

local function paintArrow(tab)
    local look = "rest"
    if tab.pressed then
        look = "down"
    elseif tab.over then
        look = "over"
    end
    paintTurned(tab.arrow, ARROWS[look], tab.pointing)
end

local function placeClosed(card)
    local tab = card.tab
    tab:SetFrameLevel(Book.Level("cardRanks"))
    tab:ClearAllPoints()
    tab:SetPoint("CENTER", card.well, "LEFT", -TAB_OUT, 0)
    paintTurned(tab.back, CAP, "left")
    tab.pointing = "left"
    paintArrow(tab)
end

-- Open, the tab caps the far end of the strip, round side out, its arrow pointing back at the icon.
local function dressOpenTab(card, leftward)
    local tab = card.tab
    tab:SetFrameLevel(Book.Level("stripTab"))
    paintTurned(tab.back, CAP, leftward and "left" or "right")
    tab.pointing = leftward and "right" or "left"
    paintArrow(tab)
end

-- Strip -------------------------------------------------------------------------------------------

local function setWidth(width)
    strip:SetWidth(width)
    strip.middle:SetShownCompat(width - SHORTEST >= 1)
end

local function dressStrip(leftward)
    local near, far = "RIGHT", "LEFT"
    if not leftward then near, far = "LEFT", "RIGHT" end
    local facing = leftward and "left" or "right"
    paintTurned(strip.edge, "ui-hud-actionbar-iconframe-flyoutbottom-2x", facing)
    paintTurned(strip.cap, CAP, facing)
    paintTurned(strip.middle, "_ui-hud-actionbar-iconframe-flyoutmidleft-2x", leftward and "down" or "up")
    strip.edge:ClearAllPoints()
    strip.edge:SetPoint(near, strip, near, 0, 0)
    strip.cap:ClearAllPoints()
    strip.cap:SetPoint(far, strip, far, 0, 0)
    strip.middle:ClearAllPoints()
    strip.middle:SetPoint("TOP" .. near, strip.edge, "TOP" .. far, 0, 0)
    strip.middle:SetPoint("BOTTOM" .. far, strip.cap, "BOTTOM" .. near, 0, 0)
end

local fold

-- No global click event on this client: a press starting outside the strip and its tab closes it.
local function watchPresses(self)
    local down = IsMouseButtonDown() and true or false
    local fresh = down and not self.wasDown
    self.wasDown = down
    if not fresh or not motion or motion.closing then return end
    if not self:IsMouseOver() and not motion.card.tab:IsMouseOver() then fold() end
end

local function buildStrip()
    strip = CreateFrame("Frame", nil, Book.stage)
    strip:SetFrameLevel(Book.Level("strip"))
    strip:SetHeight(TALL)
    -- Clicks on the strip's own backdrop stay on it instead of reaching the page below.
    strip:EnableMouse(true)
    strip:Hide()
    strip.edge = strip:CreateTexture(nil, "ARTWORK")
    strip.edge:SetSize(5, TALL)
    strip.cap = strip:CreateTexture(nil, "ARTWORK")
    strip.cap:SetSize(29, TALL)
    strip.middle = strip:CreateTexture(nil, "ARTWORK")
    strip:SetScript("OnUpdate", watchPresses)
end

-- Entries -----------------------------------------------------------------------------------------

local function rungEnter(rung)
    rung.art.lit:Show()
    if not rung.rank then return end
    Book.MarkBars(rung.rank, rung)
    tip:SetOwner(rung, "ANCHOR_LEFT")
    tip:SetSpell(rung.rank.index, "spell")
    tip:Show()
end

local function rungLeave(rung)
    rung.art.lit:Hide()
    Book.MarkBars(nil)
    if tip:IsOwned(rung) then tip:Hide() end
end

local function rungPostClick(rung)
    local rank = rung.rank
    if not rank then return end
    if IsModifiedClick("CHATLINK") then
        Book.InsertLink(rank)
        return
    end
    if IsModifiedClick("PICKUPACTION") then Book.PickUp(rank) end
    fold()
end

local function rungDrag(rung)
    Book.PickUp(rung.rank)
    fold()
end

-- Secure and anchored to the root alone; armed, placed and shown out of combat only.
local function makeRung(number)
    local root = Book.root
    local rung = CreateFrame("Button", nil, root, "SecureActionButtonTemplate")
    rung:Hide()
    rung:SetSize(RUNG, RUNG)
    rung:SetFrameLevel(Book.Level("stripEntry"))
    Book.ScaleWithContent(rung)
    rung:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    rung:RegisterForDrag("LeftButton")
    Book.ArmCaster(rung)
    rung:SetAttribute("type2", "spell")
    rung:SetScript("OnEnter", rungEnter)
    rung:SetScript("OnLeave", rungLeave)
    rung:SetScript("PostClick", rungPostClick)
    rung:SetScript("OnDragStart", rungDrag)

    local art = CreateFrame("Frame", nil, rung)
    art:SetAllPoints(rung)
    art:SetFrameLevel(rung:GetFrameLevel() + 1)
    art.icon = art:CreateTexture(nil, "BACKGROUND")
    art.icon:SetPoint("TOPLEFT", rung, "TOPLEFT", 1, -1)
    art.icon:SetPoint("BOTTOMRIGHT", rung, "BOTTOMRIGHT", -1, 1)
    art.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local rim = art:CreateTexture(nil, "BORDER")
    rim:SetAtlasTexture("ui-hud-actionbar-iconframe")
    rim:SetAllPoints(rung)
    art.digit = art:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    art.digit:SetPoint("TOPRIGHT", rung, "TOPRIGHT", -2, -3)
    art.lit = art:CreateTexture(nil, "ARTWORK")
    art.lit:SetAtlasTexture("_ui-hud-actionbar-iconborder-highlight")
    art.lit:SetAllPoints(rung)
    art.lit:Hide()
    rung.art = art
    rungs[number] = rung
    return rung
end

-- Opening and closing -----------------------------------------------------------------------------

-- Out of combat only: the entries are secure and are hidden here.
local function finish()
    local done = motion
    if not done or Book.Locked() then return end
    motion = nil
    Book.Animate("flyout", nil)
    for _, rung in ipairs(rungs) do
        rung:Hide()
        rung.rank = nil
    end
    strip:Hide()
    placeClosed(done.card)
    local tab = done.card.tab
    tab.over, tab.pressed = tab:IsShown() and tab:IsMouseOver() or false, false
    paintArrow(tab)
end

-- The tab rides the tip, easing out of its resting spot while the strip fades in.
local function paintMotion(now)
    local width = Book.FlyoutWidthAt(now.clock, now.full, now.closing)
    local veil = Book.FlyoutVeil(now.clock, now.closing)
    setWidth(width)
    strip:SetAlpha(veil)
    local tipX = now.near - width - TAB_TIP
    if not now.leftward then tipX = now.near + width + TAB_TIP end
    local tab = now.card.tab
    tab:ClearAllPoints()
    tab:SetPoint("CENTER", Book.stage, "TOPLEFT", now.rest + (tipX - now.rest) * veil, now.middle)
    return width
end

local function step(elapsed)
    local now = motion
    if not now then return false end
    now.clock = now.clock + elapsed
    local width = paintMotion(now)
    local settled = true
    for number = 1, now.count do
        local rung = rungs[number]
        local uncovered = width >= Book.FlyoutEntryReach(number) - 0.01
        -- Clickable only once the tip has uncovered it; never while still invisible under the fold.
        if uncovered and not now.closing and not rung.live and not Book.Locked() then
            rung:EnableMouse(true)
            rung.live = true
        end
        rung.alpha = Book.FlyoutFadeStep(rung.alpha, elapsed, uncovered)
        rung:SetAlpha(rung.alpha)
        if rung.alpha ~= (uncovered and 1 or 0) then settled = false end
    end
    if now.closing then
        if now.clock < CLOSE_TIME then return true end
        finish()
        return false
    end
    return now.clock < OPEN_TIME or not settled
end

-- The close picks up from the strip's current width, even halfway through opening.
fold = function()
    local now = motion
    if not now or now.closing or Book.Locked() then return end
    now.clock = Book.FlyoutCloseClock(strip:GetWidth(), now.full)
    now.closing = true
    for number = 1, now.count do
        rungs[number]:EnableMouse(false)
        rungs[number].live = false
    end
    Book.Animate("flyout", step)
end

local function open(card)
    local stage, well = Book.stage, card.well
    local ranks = card.entry.lower
    local iconLeft = well:GetLeft() - stage:GetLeft()
    local leftward, stripLeft, full, spots =
        Book.FlyoutLayout(#ranks, iconLeft, iconLeft + well:GetWidth(), well:GetLeft())
    local middle = (well:GetTop() + well:GetBottom()) / 2 - stage:GetTop()

    if not strip then buildStrip() end
    -- Pinned at the icon end, so a changing width grows or folds the strip from there.
    strip:ClearAllPoints()
    if leftward then
        strip:SetPoint("TOPRIGHT", stage, "TOPLEFT", stripLeft + full, middle + TALL / 2)
    else
        strip:SetPoint("TOPLEFT", stage, "TOPLEFT", stripLeft, middle + TALL / 2)
    end
    dressStrip(leftward)
    local shiftX, shiftY = Book.StageShift("TOPLEFT", Book.contentScale)
    for number, rank in ipairs(ranks) do
        local rung = rungs[number] or makeRung(number)
        rung:ClearAllPoints()
        rung:SetPoint("TOPLEFT", Book.root, "TOPLEFT", spots[number] + shiftX, middle + RUNG / 2 + shiftY)
        rung:SetAttribute("spell", rank.spellID)
        rung.rank, rung.alpha = rank, 0
        rung:SetAlpha(0)
        rung:EnableMouse(false)
        rung.live = false
        rung.art.icon:SetTexture(rank.icon)
        rung.art.digit:SetText(rank.sub:match("%d+") or "")
        rung.art.lit:Hide()
        rung:Show()
    end
    for number = #ranks + 1, #rungs do
        rungs[number]:Hide()
    end
    motion = {
        card = card, full = full, count = #ranks, clock = 0, closing = false, leftward = leftward,
        near = leftward and stripLeft + full or stripLeft, rest = iconLeft - TAB_OUT, middle = middle,
    }
    dressOpenTab(card, leftward)
    paintMotion(motion)
    strip.wasDown = IsMouseButtonDown() and true or false
    strip:Show()
    Book.Animate("flyout", step)
end

-- Instant close: view changes, the book closing, combat starting and a new strip elsewhere.
function Book.CloseFlyout()
    finish()
end

local function tabClick(tab)
    if Book.RefuseInCombat() then return end
    local card = tab.card
    if motion and motion.card == card and not motion.closing then return fold() end
    Book.CloseRanks()
    -- Book indices are stale until the queued rebuild lands; the next frame has fresh ones.
    if Book.stale or not (card.entry and card.entry.lower) then return end
    open(card)
end

-- Per card ----------------------------------------------------------------------------------------

local TAB_SCRIPTS = {
    OnClick = tabClick,
    OnEnter = function(tab)
        tab.over = true
        paintArrow(tab)
    end,
    OnLeave = function(tab)
        tab.over, tab.pressed = false, false
        paintArrow(tab)
    end,
    OnMouseDown = function(tab)
        tab.pressed = true
        paintArrow(tab)
    end,
    OnMouseUp = function(tab)
        tab.pressed = false
        paintArrow(tab)
    end,
}

function Book.BuildFlyoutTab(card)
    local tab = CreateFrame("Button", nil, card)
    tab:SetSize(TAB_W, TAB_H)
    tab:RegisterForClicks("LeftButtonUp")
    tab.card = card
    tab.back = tab:CreateTexture(nil, "BACKGROUND")
    tab.back:SetAllPoints(tab)
    tab.arrow = tab:CreateTexture(nil, "ARTWORK")
    tab.arrow:SetSize(7 * GROW, 18 * GROW)
    tab.arrow:SetPoint("CENTER", tab, "CENTER", -GROW, 0)
    for event, handler in pairs(TAB_SCRIPTS) do
        tab:SetScript(event, handler)
    end
    tab:Hide()
    card.tab = tab
    placeClosed(card)
end

function Book.DressFlyoutTab(card, offered)
    local tab = card.tab
    tab:SetShownCompat(offered)
    tab.over = offered and tab:IsMouseOver() or false
    tab.pressed = false
    paintArrow(tab)
end
