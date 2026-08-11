local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The staggered fade the list tabs use when a section opens or closes. Keyed on the flat INDEX,
-- never the row frame: the lists are virtualised, so state parked on a frame is lost on any repaint.

-- Starts spread across SPREAD however many rows there are, so a long section is a wave. FADE stays
-- well under it: a row at half alpha counts as half gone, so long fades let the tail climb over rows.
local SPREAD = 0.18
local FADE = 0.08
-- Ceiling on the row-to-row gap: a two-row section spreading the full window reads as two events.
local MAX_STAGGER = 0.045

local first, last, elapsed, total, stagger, repaintFn, fadingOut, finishFn
local shift, shiftStale
local driver

local function stop()
    local finish = finishFn
    first, last, repaintFn, fadingOut, finishFn = nil, nil, nil, nil, nil
    if driver then driver:Hide() end
    -- After the state is cleared, so anything it repaints reads a plain alpha of 1.
    if finish then finish() end
end

local function step(_, delta)
    elapsed = elapsed + (delta or 0)
    shiftStale = true
    if repaintFn then repaintFn() end
    if elapsed >= total then stop() end
end

-- `from`..`to` are flat indices, inclusive. `out` fades them away instead of in, and `finish` runs
-- once the last one is gone -- which is where a collapse actually drops the rows.
function CP.StartListReveal(from, to, repaint, out, finish)
    if not from or not to or to < from then
        if finish then finish() end
        return
    end

    first, last = from, to
    stagger = math.min(SPREAD / math.max(1, to - from), MAX_STAGGER)
    elapsed, total = 0, (to - from) * stagger + FADE
    repaintFn, fadingOut, finishFn = repaint, out, finish
    shift, shiftStale = 0, true

    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", step)
    end
    driver:Show()
    if repaint then repaint() end
end

-- Opening runs top-down, closing bottom-up. The rows below ride up by how much of the block has
-- gone, and that space has to be at the BOTTOM of the block, next to them.
function CP.ListRevealActive()
    return first ~= nil
end

function CP.ListRevealAlpha(index)
    if not first or index < first or index > last then return 1 end
    local order = fadingOut and (last - index) or (index - first)
    local p = (elapsed - order * stagger) / FADE
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    return fadingOut and (1 - p) or p
end

-- How far the rows below ride up: summing (1 - alpha) rather than easing on raw time means the list
-- only ever closes over space that is genuinely empty.
function CP.ListRevealShift(index, rowHeight)
    if not first or index <= last then return 0 end
    if shiftStale then
        shift = 0
        for i = first, last do
            shift = shift + (1 - CP.ListRevealAlpha(i)) * rowHeight
        end
        shiftStale = false
    end
    return shift
end

-- Everything a header owns, sub-headers included. 3.3.5a nests one level deep and marks the inner
-- ones isChild, so that flag IS the depth; a run ends at the next header no deeper than itself.
local function depthOf(entry)
    return entry.isChild and 1 or 0
end

local function childRange(flat, headerIndex)
    if not flat or not headerIndex or not flat[headerIndex] then return nil end
    local depth = depthOf(flat[headerIndex])
    local tail = headerIndex
    for i = headerIndex + 1, #flat do
        local entry = flat[i]
        if entry.kind == "header" and depthOf(entry) <= depth then break end
        tail = i
    end
    if tail <= headerIndex then return nil end
    return headerIndex + 1, tail
end

function CP.RevealChildrenOf(flat, headerIndex, repaint)
    local from, to = childRange(flat, headerIndex)
    if from then CP.StartListReveal(from, to, repaint) end
end

-- Fade out FIRST and drop the run in `finish`: calling the API up front leaves nothing to animate.
function CP.FadeOutChildrenOf(flat, headerIndex, repaint, finish)
    local from, to = childRange(flat, headerIndex)
    if from then
        CP.StartListReveal(from, to, repaint, true, finish)
    elseif finish then
        finish()
    end
end
