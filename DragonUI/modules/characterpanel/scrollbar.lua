local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's minimal scrollbar over 3.3.5a's UIPanelScrollFrameTemplate slider: an 8px track with
-- 8x8 caps instead of Blizzard's 16px carved groove and chunky arrow buttons.
local BAR_W = 8
local THUMB_OVERLAP = 1
-- Keeps the track clear of the pane trim at both ends.
local TRACK_INSET = 7
-- Retail's MinimalScrollBar holds its Track 19px off each end and parks a 17x11 stepper there.
local ARROW_SPACE = 19
local ARROW_W, ARROW_H = 17, 11
-- The stats sidebar leaves an 11px gutter and its rows run right up to it, so this stays where it
-- always was. NOT the list panes' -9: those pull their content in by 22 first, the sidebar does not.
local BAR_X_INSET = -2

local function stripRegions(frame)
    if not frame then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetTexture(nil) end
    end
end

-- Zero unless this bar carries steppers: the stats sidebar has no room for them, so its track runs
-- the full height the way it did before they existed.
local function arrowSpace(bar)
    return bar._duiSteppers and ARROW_SPACE or 0
end

local function buildTrack(bar)
    if bar._duiTrack then return end
    bar._duiTrack = true

    local gap = arrowSpace(bar)

    local top = bar:CreateTexture(nil, "BACKGROUND")
    top:set_atlas("minimal-scrollbar-track-top", true)
    top:SetPoint("TOP", bar, "TOP", 0, -gap)

    local bottom = bar:CreateTexture(nil, "BACKGROUND")
    bottom:set_atlas("minimal-scrollbar-track-bottom", true)
    bottom:SetPoint("BOTTOM", bar, "BOTTOM", 0, gap)

    local middle = bar:CreateTexture(nil, "BACKGROUND")
    middle:set_atlas("!minimal-scrollbar-track-middle")
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
end

-- Three pieces we own, with the real ThumbTexture left blank purely for hit-testing: WoW hides that
-- texture whenever the slider's range is zero, and anything anchored to it vanished with it.
local function buildThumb(bar, thumb)
    if not thumb or bar._duiThumb then return end
    bar._duiThumb = true

    thumb:SetTexture(nil)
    thumb:SetWidth(BAR_W)

    -- Invisible driver: the only piece we position, so the grip is described in one place.
    local grip = bar:CreateTexture(nil, "BACKGROUND")
    grip:SetTexture(nil)
    grip:SetWidth(BAR_W)

    local top = bar:CreateTexture(nil, "ARTWORK")
    top:set_atlas("minimal-scrollbar-thumb-top", true)
    top:SetPoint("TOP", grip, "TOP", 0, 0)

    local bottom = bar:CreateTexture(nil, "ARTWORK")
    bottom:set_atlas("minimal-scrollbar-thumb-bottom", true)
    bottom:SetPoint("BOTTOM", grip, "BOTTOM", 0, 0)

    -- Under the caps and a pixel into each. Butted edge to edge, the middle and the cap round their
    -- shared edge independently once the UI scale is not 1, and a hairline of track blinks through
    -- as the grip travels. Only one pixel, so it never reaches the rounded ends and show through.
    local mid = bar:CreateTexture(nil, "ARTWORK", nil, -1)
    mid:set_atlas("minimal-scrollbar-thumb-middle")
    mid:SetWidth(BAR_W)
    mid:SetPoint("TOP", top, "BOTTOM", 0, THUMB_OVERLAP)
    mid:SetPoint("BOTTOM", bottom, "TOP", 0, -THUMB_OVERLAP)

    bar._duiGrip = grip
end

-- Blanked rather than removed: Blizzard's template still drives these buttons, and a bar with no
-- gutter for steppers has nowhere to put them without covering its own pane.
local function hideArrow(button)
    if not button or button._duiArrow then return end
    button._duiArrow = true

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture",
                              "GetDisabledTexture", "GetHighlightTexture" }) do
        local tex = button[getter] and button[getter](button)
        if tex then tex:SetTexture(nil) end
    end
    button:SetSize(1, 1)
    button:EnableMouse(false)
end

-- Blizzard's carved arrows swapped for the minimal pair, sized and parked where retail puts them.
local function skinArrow(button, bar, atlas, point)
    if not button or button._duiArrow then return end
    button._duiArrow = true

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture",
                              "GetDisabledTexture", "GetHighlightTexture" }) do
        local tex = button[getter] and button[getter](button)
        if tex then tex:SetTexture(nil) end
    end

    button:SetSize(ARROW_W, ARROW_H)
    button:ClearAllPoints()
    button:SetPoint(point, bar, point, 0, 0)

    -- Its own texture rather than the button's: the template re-asserts those on every state change.
    local art = button:CreateTexture(nil, "ARTWORK")
    art:set_atlas(atlas, true)
    art:SetPoint("CENTER", button, "CENTER", 0, 0)
    button._duiArt = art
end

local MIN_THUMB_H = 20

-- WoW maps a slider's value across (track - thumb), so a thumb that fills its track leaves nothing
-- to divide by and the drag reads backwards. This is the travel the thumb always leaves behind.
local MIN_TRAVEL = 12

local function snap(v)
    return math.floor(v + 0.5)
end

-- Blizzard's thumb is a fixed 24px whatever the list length; size it to the visible fraction.
-- Places the grip from the slider's value rather than following the real thumb, so nothing depends
-- on where WoW decided to put a texture we never show.
local function syncThumb(scroll, bar)
    local grip = bar._duiGrip
    if not grip then return end
    local viewport = scroll:GetHeight() or 0
    -- The track is what the grip travels, and the steppers own a slice of each end of the bar.
    local trackH = (bar:GetHeight() or 0) - 2 * arrowSpace(bar)
    if viewport <= 0 or trackH <= 0 then return end

    local minV, maxV = bar:GetMinMaxValues()
    minV, maxV = minV or 0, maxV or 0
    local range = maxV - minV

    -- Nothing to scroll: the grip fills the track.
    if range <= 0 then
        bar._duiTravel = 0
        grip:SetHeight(snap(trackH))
        grip:ClearAllPoints()
        grip:SetPoint("TOP", bar, "TOP", 0, -arrowSpace(bar))
        return
    end

    local maxGrip = math.max(1, trackH - MIN_TRAVEL)
    local h = trackH * (viewport / (viewport + range))
    if h < math.min(MIN_THUMB_H, maxGrip) then h = math.min(MIN_THUMB_H, maxGrip) end
    if h > maxGrip then h = maxGrip end
    -- Both of these come out of a ratio. The caps are placed at their native size, so half a pixel
    -- of grip leaves the bottom one meeting the stretched middle across a seam.
    h = snap(h)

    local travel = trackH - h
    bar._duiTravel = travel

    grip:SetHeight(h)
    grip:ClearAllPoints()
    grip:SetPoint("TOP", bar, "TOP", 0,
        -(arrowSpace(bar) + snap(travel * ((bar:GetValue() - minV) / range))))
end

-- WoW maps a thumb drag through (track - thumb) inside C, and on short lists that mapping has come
-- out backwards more than once. The grip is placed and driven straight from the slider's value
-- instead, so the bar behaves identically whatever the list length.
local dragger = CreateFrame("Frame")
dragger:Hide()

-- The one seam the drag math reads its origin through, so insetting it here is all the steppers cost.
local function trackTopOf(bar)
    local top = bar:GetTop()
    if not top then return nil end
    return top - arrowSpace(bar)
end

local function cursorTopIn(bar)
    local trackTop = trackTopOf(bar)
    if not trackTop then return nil end
    local _, cy = GetCursorPosition()
    return trackTop - (cy / bar:GetEffectiveScale())
end

local function applyGripTop(bar, top)
    local travel = bar._duiTravel or 0
    local minV, maxV = bar:GetMinMaxValues()
    if travel <= 0 or maxV <= minV then return end
    local ratio = top / travel
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
    bar:SetValue(minV + ratio * (maxV - minV))
end

-- Polled rather than taken from OnMouseUp: releasing with the cursor off the bar never delivers it.
dragger:SetScript("OnUpdate", function(self)
    if not IsMouseButtonDown("LeftButton") then self:Hide(); return end
    local bar = self.bar
    local cursorTop = bar and cursorTopIn(bar)
    if not cursorTop then return end
    applyGripTop(bar, cursorTop - (self.grab or 0))
end)

local function beginDrag(bar)
    local grip = bar._duiGrip
    local cursorTop = grip and cursorTopIn(bar)
    if not cursorTop then return end

    local gripTop = (bar:GetTop() or 0) - (grip:GetTop() or bar:GetTop() or 0)
    local within = cursorTop - gripTop
    local height = grip:GetHeight() or 0
    -- Pressing the bare track picks the grip up by its middle instead of jumping by a page.
    if within < 0 or within > height then within = height / 2 end

    dragger.bar, dragger.grab = bar, within
    dragger:Show()
    applyGripTop(bar, cursorTop - within)
end

local function wireDrag(bar, host)
    if bar._duiDrag then return end
    bar._duiDrag = true
    -- The slider keeps the value and the range; it just stops handling the mouse itself.
    bar:EnableMouse(false)

    local grabber = CreateFrame("Button", nil, host)
    grabber:SetAllPoints(bar)
    grabber:SetFrameLevel(bar:GetFrameLevel() + 2)
    grabber:SetScript("OnMouseDown", function() beginDrag(bar) end)
    bar._duiGrabber = grabber
end

local function hookThumbSync(scroll, bar)
    local function sync() syncThumb(scroll, bar) end
    scroll:HookScript("OnScrollRangeChanged", sync)
    scroll:HookScript("OnVerticalScroll", sync)
    scroll:HookScript("OnShow", sync)
    -- FauxScrollFrame_Update writes the range straight onto the slider, which never reaches the
    -- scroll frame's own OnScrollRangeChanged.
    bar:HookScript("OnMinMaxChanged", sync)
    bar._duiSync = sync
    sync()
end

CP.SyncScrollThumb = function(scroll)
    local bar = scroll and _G[scroll:GetName() .. "ScrollBar"]
    if bar and bar._duiSync then bar._duiSync() end
end

-- Blizzard drops the bar once there is nothing to scroll, but only when asked, and the viewport then
-- takes the gutter back. `onResize` is whatever the caller re-runs once the width has changed.
function CP.AutoHideScrollBar(scroll, host, gutter, bottomY, onResize)
    if not scroll or not scroll.GetName then return end
    scroll.scrollBarHideable = true

    local bar = _G[(scroll:GetName() or "") .. "ScrollBar"]
    if not bar or bar._duiAutoHide then return end
    bar._duiAutoHide = true

    local function anchorRight()
        scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT",
            bar:IsShown() and -gutter or 0, bottomY or 0)
        if onResize then onResize() end
    end
    bar:HookScript("OnShow", anchorRight)
    bar:HookScript("OnHide", anchorRight)
end

-- The template only re-evaluates on a range CHANGE, so a list short from the first paint keeps the
-- bar it was created with. Deferred a frame: GetVerticalScrollRange is stale until the next layout.
function CP.SyncScrollBarVisibility(scroll)
    if not scroll or not scroll.GetName or not ScrollFrame_OnScrollRangeChanged then return end
    addon:After(0, function()
        if scroll:GetName() then ScrollFrame_OnScrollRangeChanged(scroll) end
    end)
end

-- `host` is the pane the bar sits flush inside; the template would hang it outside the scroll frame.
-- The insets drop it below or lift it above whatever occupies that pane's top and bottom.
function CP.ReskinScrollBar(scroll, host, topInset, xInset, bottomInset, withSteppers)
    if not scroll or not scroll.GetName then return end
    local name = scroll:GetName()
    local bar = _G[name .. "ScrollBar"]
    if not bar or bar._duiReskinned then return end
    bar._duiReskinned = true
    -- Opt in: only the list panes leave a gutter wide enough for steppers to sit in.
    bar._duiSteppers = withSteppers and true or false

    stripRegions(bar)
    bar:SetWidth(BAR_W)
    bar:ClearAllPoints()
    local x = xInset or BAR_X_INSET
    bar:SetPoint("TOPRIGHT", host, "TOPRIGHT", x, -(TRACK_INSET + (topInset or 0)))
    bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", x, TRACK_INSET + (bottomInset or 0))

    local thumb = _G[name .. "ScrollBarThumbTexture"]
    buildTrack(bar)
    buildThumb(bar, thumb)

    local up, down = _G[name .. "ScrollBarScrollUpButton"], _G[name .. "ScrollBarScrollDownButton"]
    if bar._duiSteppers then
        skinArrow(up, bar, "minimal-scrollbar-arrow-top", "TOP")
        skinArrow(down, bar, "minimal-scrollbar-arrow-bottom", "BOTTOM")
    else
        hideArrow(up)
        hideArrow(down)
    end

    wireDrag(bar, host)
    hookThumbSync(scroll, bar)
end
