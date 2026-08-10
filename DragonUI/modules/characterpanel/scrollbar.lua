local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's minimal scrollbar over 3.3.5a's UIPanelScrollFrameTemplate slider: an 8px track with
-- 8x8 caps instead of Blizzard's 16px carved groove and chunky arrow buttons.
local BAR_W = 8
-- Keeps the track clear of the pane trim at both ends.
local TRACK_INSET = 7
local BAR_X_INSET = -1

local function stripRegions(frame)
    if not frame then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetTexture(nil) end
    end
end

local function buildTrack(bar)
    if bar._duiTrack then return end
    bar._duiTrack = true

    local top = bar:CreateTexture(nil, "BACKGROUND")
    top:set_atlas("minimal-scrollbar-track-top", true)
    top:SetPoint("TOP", bar, "TOP", 0, 0)

    local bottom = bar:CreateTexture(nil, "BACKGROUND")
    bottom:set_atlas("minimal-scrollbar-track-bottom", true)
    bottom:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

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

    -- A real 3-slice: run full height under the caps, the middle showed through their margins.
    local mid = bar:CreateTexture(nil, "ARTWORK")
    mid:set_atlas("minimal-scrollbar-thumb-middle")
    mid:SetWidth(BAR_W)
    mid:SetPoint("TOP", top, "BOTTOM", 0, 0)
    mid:SetPoint("BOTTOM", bottom, "TOP", 0, 0)

    bar._duiGrip = grip
end

-- The arrows read as clutter; Blizzard still needs the buttons, so blank them rather than remove.
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

local MIN_THUMB_H = 20

-- Blizzard's thumb is a fixed 24px whatever the list length; size it to the visible fraction.
local function syncThumb(scroll, bar, thumb)
    local grip = bar._duiGrip
    if not thumb or not grip then return end
    local child = scroll:GetScrollChild()
    local viewport = scroll:GetHeight() or 0
    local content = child and child:GetHeight() or 0
    local trackH = bar:GetHeight() or 0
    if viewport <= 0 or content <= 0 or trackH <= 0 then return end

    -- Nothing to scroll: the grip fills the track. Anchored to the bar rather than the slider's
    -- thumb, which WoW has hidden by now.
    if content <= viewport then
        grip:SetHeight(trackH)
        grip:ClearAllPoints()
        grip:SetPoint("TOP", bar, "TOP", 0, 0)
        return
    end

    local h = trackH * (viewport / content)
    if h < MIN_THUMB_H then h = MIN_THUMB_H end
    if h > trackH then h = trackH end

    -- Only when it genuinely differs: this fires on every frame of a drag, and resizing the thumb
    -- mid-drag makes WoW recompute the value-to-position mapping under the cursor.
    if math.abs((thumb:GetHeight() or 0) - h) > 0.5 then thumb:SetHeight(h) end
    grip:SetHeight(h)
    grip:ClearAllPoints()
    grip:SetPoint("CENTER", thumb, "CENTER", 0, 0)
end

local function hookThumbSync(scroll, bar, thumb)
    local function sync() syncThumb(scroll, bar, thumb) end
    scroll:HookScript("OnScrollRangeChanged", sync)
    scroll:HookScript("OnVerticalScroll", sync)
    scroll:HookScript("OnShow", sync)
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
function CP.ReskinScrollBar(scroll, host, topInset, xInset, bottomInset)
    if not scroll or not scroll.GetName then return end
    local name = scroll:GetName()
    local bar = _G[name .. "ScrollBar"]
    if not bar or bar._duiReskinned then return end
    bar._duiReskinned = true

    stripRegions(bar)
    bar:SetWidth(BAR_W)
    bar:ClearAllPoints()
    local x = xInset or BAR_X_INSET
    bar:SetPoint("TOPRIGHT", host, "TOPRIGHT", x, -(TRACK_INSET + (topInset or 0)))
    bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", x, TRACK_INSET + (bottomInset or 0))

    local thumb = _G[name .. "ScrollBarThumbTexture"]
    buildTrack(bar)
    buildThumb(bar, thumb)

    hideArrow(_G[name .. "ScrollBarScrollUpButton"])
    hideArrow(_G[name .. "ScrollBarScrollDownButton"])

    hookThumbSync(scroll, bar, thumb)
end
