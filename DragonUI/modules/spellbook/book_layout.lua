-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs, floor, max, min = ipairs, math.floor, math.max, math.min

Book.WIDE_W, Book.NARROW_W, Book.HEIGHT = 1618, 809, 883

local ROWS, COLUMNS = 9, 3
local CARD_W = 650 / 3
local COLUMN_GAP = 15
local COLUMN_STEP, ROW_STEP = CARD_W + COLUMN_GAP, 70
local VIEW_TOP, LEFT_PAGE_X, RIGHT_PAGE_INSET = -148, 85, 730
local HEADER_DROP = 18

Book.GRID = {
    cardW = CARD_W,
    columnGap = COLUMN_GAP,
    cardH = 60,
    iconButton = 48,
    iconSize = 41,
    iconDrop = (60 - 48) / 2,
    viewTop = VIEW_TOP,
    viewW = 680,
    viewH = 620,
    headerH = 51,
}

-- Left edge of a page: side 1 is the left (or only) page, side 2 the right one.
function Book.PageLeft(side, width)
    if side == 1 then return LEFT_PAGE_X end
    return width - RIGHT_PAGE_INSET
end

-- Section headers start a fresh row, take the whole row and drop 18 unless they open a page.
function Book.FlowSections(sections, pagesPerSpread, width)
    local spreads = {}
    local page, row, column = 1, 0, 0

    local function locate()
        local number = floor((page - 1) / pagesPerSpread) + 1
        local spread = spreads[number]
        if not spread then
            spread = { cards = {}, headers = {} }
            spreads[number] = spread
        end
        return spread, Book.PageLeft((page - 1) % pagesPerSpread + 1, width)
    end

    local function turnWhenFull()
        if row >= ROWS then page, row, column = page + 1, 0, 0 end
    end

    for _, section in ipairs(sections) do
        if #section.entries > 0 then
            if section.title then
                if column > 0 then row, column = row + 1, 0 end
                turnWhenFull()
                -- On the last row the header would sit alone with its cards overleaf.
                if row == ROWS - 1 then page, row = page + 1, 0 end
                local spread, x = locate()
                spread.headers[#spread.headers + 1] = {
                    title = section.title,
                    x = x,
                    y = VIEW_TOP - row * ROW_STEP - (row > 0 and HEADER_DROP or 0),
                }
                row = row + 1
            end
            for _, entry in ipairs(section.entries) do
                turnWhenFull()
                local spread, x = locate()
                spread.cards[#spread.cards + 1] = {
                    entry = entry,
                    x = x + column * COLUMN_STEP,
                    y = VIEW_TOP - row * ROW_STEP,
                }
                if column == COLUMNS - 1 then row, column = row + 1, 0 else column = column + 1 end
            end
        end
    end
    if not spreads[1] then spreads[1] = { cards = {}, headers = {} } end
    return spreads
end

Book.SCREEN_MARGIN = 16
-- The frame stays at scale 1 around the scaled content: title band on top, fill edge elsewhere.
Book.BAND, Book.EDGE = 21, 2

function Book.WindowSize(wide, scale)
    local width = wide and Book.WIDE_W or Book.NARROW_W
    local edge, band = Book.EDGE, Book.BAND
    return 2 * edge + scale * (width - 2 * edge), band + edge + scale * (Book.HEIGHT - band - edge)
end

-- Two pages that overflow the screen drop to one at the chosen scale; only then content shrinks.
function Book.FitWindow(wantWide, forceWide, scale, screenW, screenH)
    local roomW = screenW - 2 * Book.SCREEN_MARGIN
    local roomH = screenH - 2 * Book.SCREEN_MARGIN
    local wide = wantWide
    if wide and not forceWide then
        local width, height = Book.WindowSize(true, scale)
        if width > roomW or height > roomH then wide = false end
    end
    local contentW = (wide and Book.WIDE_W or Book.NARROW_W) - 2 * Book.EDGE
    local contentH = Book.HEIGHT - Book.BAND - Book.EDGE
    return wide, min(scale, (roomW - 2 * Book.EDGE) / contentW, (roomH - Book.BAND - Book.EDGE) / contentH)
end

-- Content-unit offset that lands a content-scaled child of the root on that point of the stage.
function Book.StageShift(relativePoint, scale)
    local slack = (1 - scale) / scale
    local dx, dy = 0, (Book.EDGE - Book.BAND) / 2 * slack
    if relativePoint:find("LEFT") then
        dx = Book.EDGE * slack
    elseif relativePoint:find("RIGHT") then
        dx = -Book.EDGE * slack
    end
    if relativePoint:find("TOP") then
        dy = -Book.BAND * slack
    elseif relativePoint:find("BOTTOM") then
        dy = Book.EDGE * slack
    end
    return dx, dy
end

-- Root offset, at scale 1, of a stage point given in content units.
function Book.OnBook(relativePoint, x, y, scale)
    local dx, dy = Book.StageShift(relativePoint, scale)
    return (dx + x) * scale, (dy + y) * scale
end

function Book.ClampPage(page, pages)
    return max(1, min(page or 1, pages))
end

function Book.SpreadHolding(spreads, key)
    if not key then return nil end
    for number, spread in ipairs(spreads) do
        for _, cell in ipairs(spread.cards) do
            if cell.entry.key == key then return number end
        end
    end
end
