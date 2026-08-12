local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The scaffold Reputation, Skills and Currency share: a pane over the Inset, a scrolling viewport
-- and a pool of recycled rows -- the lists renumber on every expand, so the set is rebuilt constantly.

CP.LIST_ROW_H = 24

-- Retail hangs the bar off the list's right edge, not the pane's: content stops at -22, then 5 of
-- gap, then the 8 wide bar, which leaves it 9 clear of the trim rather than pinned against it.
CP.LIST_SCROLLBAR_X = -9

-- Right edge of the viewport with and without a scrollbar to leave room for. Retail's ScrollBox
-- takes 22 off its inset for the bar, which is what pulls its rows in from the trim.
local BAR_GUTTER, FLUSH_MARGIN = -22, -6

local HEADER_INDENT = 12

-- Blends ADD over the bar's own art, so this reads as brightness rather than a white film.
local HEADER_HL_ALPHA = 0.4

-- The bar's right cap IS the chevron: one atlas for collapsed, another for expanded.
function CP.BuildListHeader(parent, onToggle)
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(CP.LIST_ROW_H)
    -- Above the entry rows, so a section closing under one rolls up behind the bar, not across it.
    header:SetFrameLevel(parent:GetFrameLevel() + 2)

    local left = header:CreateTexture(nil, "BACKGROUND")
    left:set_atlas("options_listexpand_left", true)
    left:SetPoint("LEFT", header, "LEFT", 0, 0)

    local right = header:CreateTexture(nil, "BACKGROUND")
    right:set_atlas("options_listexpand_right", true)
    right:SetPoint("RIGHT", header, "RIGHT", 0, 0)

    local middle = header:CreateTexture(nil, "BACKGROUND")
    middle:set_atlas("_options_listexpand_middle")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

    -- Three pieces, not one wash: the caps are shaped, so a rectangle stops at their inner edge.
    local hlLeft = header:CreateTexture(nil, "HIGHLIGHT")
    hlLeft:set_atlas("options_listexpand_left", true)
    hlLeft:SetPoint("LEFT", header, "LEFT", 0, 0)
    hlLeft:SetBlendMode("ADD")
    hlLeft:SetAlpha(HEADER_HL_ALPHA)

    local hlRight = header:CreateTexture(nil, "HIGHLIGHT")
    hlRight:set_atlas("options_listexpand_right", true)
    hlRight:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    hlRight:SetBlendMode("ADD")
    hlRight:SetAlpha(HEADER_HL_ALPHA)

    local hlMiddle = header:CreateTexture(nil, "HIGHLIGHT")
    hlMiddle:set_atlas("_options_listexpand_middle")
    hlMiddle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    hlMiddle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    hlMiddle:SetBlendMode("ADD")
    hlMiddle:SetAlpha(HEADER_HL_ALPHA)

    local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", header, "LEFT", HEADER_INDENT, 0)
    text:SetJustifyH("LEFT")

    header.Chevron = right
    header.ChevronHighlight = hlRight
    header.Text = text
    header:RegisterForClicks("LeftButtonUp")
    header:SetScript("OnClick", function(self) onToggle(self._index, self._collapsed) end)
    return header
end

function CP.UpdateListHeader(header, name, index, collapsed)
    header.Text:SetText(name or "")
    header._index, header._collapsed = index, collapsed
    local cap = collapsed and "options_listexpand_right" or "options_listexpand_right_expanded"
    header.Chevron:set_atlas(cap, true)
    -- The two cap variants are different shapes, so the glow has to follow the chevron.
    header.ChevronHighlight:set_atlas(cap, true)
end

-- Retail's WowStyle1DropdownTemplate, which is what Reputation and Currency hang top right: a
-- textholder body with the gradient on the ARROW, so the states below are arrow art and the body
-- has none. `build` returns the entry list, rebuilt on every open so the checks stay live.
-- Only 25 of the plate's 41 rows are opaque, so the field draws a third shorter than this.
local DROPDOWN_H = 34

-- Native size of one textholder cap in the atlas; the cap width follows the row height from these.
local CAP_W, CAP_H = 18, 41

-- Square, and 27 to the plate's 41: sized off anything else the chevron outgrows the field it is in.
local ARROW_BOX = 27
-- 8 of field glow + 3 of padding - the arrow's own 4; the drop re-centres art that sits high in its box.
local ARROW_INSET, ARROW_DROP = 7, 2
-- 8 of field glow + 6 of padding, so the text starts inside the bevel rather than on it.
local TEXT_INSET = 14

-- One number for all three tabs: the widest label is Skills', and a filter that changes size from
-- tab to tab reads as three different controls.
CP.FILTER_DROPDOWN_W = 140

-- Right edge lined up with the settings cog's, which is the control this one stands in for.
local FILTER_X = -6

-- Centred in the strip between the close button and the top of the list rather than hung off the
-- close button: the eye reads that strip as one row, and hanging it leaves all the slack below.
function CP.AnchorFilterDropdown(pane, btn)
    local cf, close = _G.CharacterFrame, _G.CharacterFrameCloseButton
    if not close then
        btn:SetPoint("TOPRIGHT", cf, "TOPRIGHT", FILTER_X - 6, -27)
        return
    end
    local band = CreateFrame("Frame", nil, pane)
    band:SetWidth(1)
    band:SetPoint("TOPRIGHT", close, "BOTTOMRIGHT", FILTER_X, 0)
    band:SetPoint("BOTTOMRIGHT", pane, "TOPRIGHT", FILTER_X, 0)
    btn:SetPoint("RIGHT", band, "RIGHT", 0, 0)
end

-- The list is ours, not Blizzard's: DropDownList1 is one shared frame with its own backdrop and
-- strata, so reskinning it would repaint every other menu in the game. The geometry and the
-- backdrop below are UIDropDownListTemplate's own, because the reference leaves that frame alone --
-- what it shows on screen IS this.
local MENU_ROW_H = 16   -- UIDROPDOWNMENU_BUTTON_HEIGHT
local MENU_INSET = 15   -- UIDROPDOWNMENU_BORDER_HEIGHT, and where AddButton lands a checkable row
local MENU_EDGE = 12    -- the backdrop's own right inset
local MENU_TEXT_X, MENU_CHECK = 20, 16
local MENU_MIN_W, MENU_ROW_PAD, MENU_GAP = 120, 10, 2

local MENU_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 9 },
}

local openMenu

local function closeFilterMenu()
    if not openMenu then return end
    local menu = openMenu
    openMenu = nil
    menu:Hide()
    if menu.Blocker then menu.Blocker:Hide() end
    if menu.Owner and menu.Owner.Restate then menu.Owner.Restate() end
end
CP.CloseFilterMenu = closeFilterMenu

local function acquireMenuRow(menu, i)
    local row = menu.Rows[i]
    if row then return row end

    row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW_H)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetAllPoints(row)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(1, 1, 1, 0.12)

    local check = row:CreateTexture(nil, "ARTWORK")
    check:SetSize(MENU_CHECK, MENU_CHECK)
    check:SetPoint("LEFT", row, "LEFT", 0, 0)
    check:set_atlas("checkmark-minimal")
    row.Check = check

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "LEFT", MENU_TEXT_X, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    row.Text = text

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        closeFilterMenu()
        if self._func then self._func() end
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    menu.Rows[i] = row
    return row
end

local function buildFilterMenu(btn, name, build)
    local menu = CreateFrame("Frame", name .. "Menu", UIParent)
    -- Above the panel and its own tooltips; the character frame itself never leaves HIGH.
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(20)
    menu:Hide()
    menu.Rows = {}
    menu.Owner = btn

    menu:SetBackdrop(MENU_BACKDROP)

    -- Anything outside dismisses, the way a real menu behaves. Same strata, lower level, so the
    -- list stays clickable while everything behind it is not.
    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetFrameLevel(1)
    blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", closeFilterMenu)
    blocker:Hide()
    menu.Blocker = blocker

    function menu:Populate()
        local entries = build() or {}
        local widest = 0
        for i = 1, #entries do
            local entry = entries[i]
            local row = acquireMenuRow(self, i)
            row.Text:SetText(entry.text or "")
            if entry.checked then row.Check:Show() else row.Check:Hide() end
            row._func = entry.func
            local y = -(MENU_INSET + (i - 1) * MENU_ROW_H)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", MENU_INSET, y)
            row:SetPoint("TOPRIGHT", self, "TOPRIGHT", -MENU_EDGE, y)
            row:Show()
            widest = math.max(widest, row.Text:GetStringWidth() or 0)
        end
        for i = #entries + 1, #self.Rows do self.Rows[i]:Hide() end

        self:SetSize(
            math.max(MENU_MIN_W,
                math.ceil(widest) + MENU_TEXT_X + MENU_INSET + MENU_EDGE + MENU_ROW_PAD),
            MENU_INSET * 2 + math.max(1, #entries) * MENU_ROW_H)
    end

    return menu
end

function CP.CreateFilterDropdown(parent, name, width, build)
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(width, DROPDOWN_H)

    -- Three pieces, never one: the caps hold the corner aspect by taking their width from the row
    -- height, and only the flat middle stretches, which it does invisibly.
    -- Atlas before the anchors throughout: set_atlas re-asserts whatever size the region already had.
    local left = btn:CreateTexture(nil, "BACKGROUND")
    left:set_atlas("common-dropdown-textholder-left")
    left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)

    local right = btn:CreateTexture(nil, "BACKGROUND")
    right:set_atlas("common-dropdown-textholder-right")
    right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)

    local body = btn:CreateTexture(nil, "BACKGROUND")
    body:set_atlas("common-dropdown-textholder-center")
    body:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:set_atlas("common-dropdown-a-button")

    -- Retail's font. The text is the CURRENT SELECTION, not a static "Filter": this is a
    -- selection dropdown, which is why theirs reads "All" rather than naming itself.
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    label:SetJustifyH("LEFT")

    -- Caps, chevron and text all come off the row height: every number above is one 41px plate's.
    local function relayout()
        local scale = (btn:GetHeight() or DROPDOWN_H) / CAP_H
        left:SetWidth(CAP_W * scale)
        right:SetWidth(CAP_W * scale)
        arrow:SetSize(ARROW_BOX * scale, ARROW_BOX * scale)
        arrow:SetPoint("RIGHT", btn, "RIGHT", -ARROW_INSET * scale, -ARROW_DROP * scale)
        label:SetPoint("LEFT", btn, "LEFT", TEXT_INSET * scale, 0)
    end
    relayout()
    btn:HookScript("OnSizeChanged", relayout)
    btn.Label = label
    function btn:SetSelection(text) label:SetText(text or "") end

    local menu = buildFilterMenu(btn, name, build)
    btn.Menu = menu

    -- The ARROW is the state, the way retail paints it: the body is a static atlas with no variants.
    -- No white wash on top either -- `open` is a distinct art from `hover`, and an additive film
    -- cannot tell those two apart.
    local over, down = false, false
    local function restate()
        local suffix = ""
        if not btn:IsEnabled() then
            suffix = "-disabled"
        elseif menu:IsShown() then
            suffix = "-open"
        elseif down and over then
            suffix = "-pressedhover"
        elseif down then
            suffix = "-pressed"
        elseif over then
            suffix = "-hover"
        end
        arrow:set_atlas("common-dropdown-a-button" .. suffix)
    end

    btn:HookScript("OnEnter", function() over = true; restate() end)
    btn:HookScript("OnLeave", function() over = false; restate() end)
    btn:HookScript("OnMouseDown", function() down = true; restate() end)
    -- Next frame: the menu's shown state only settles after the click has been handled.
    btn:HookScript("OnMouseUp", function() down = false; addon:After(0, restate) end)
    btn:HookScript("OnEnable", restate)
    btn:HookScript("OnDisable", restate)
    btn.Restate = restate
    restate()

    btn:SetScript("OnClick", function(self)
        if menu:IsShown() then closeFilterMenu(); return end
        closeFilterMenu()
        menu:Populate()
        menu:ClearAllPoints()
        -- Right edges aligned, the way retail drops a filter list: the arrow is the anchor the eye
        -- follows, and these sit against the panel's right trim with no room to grow the other way.
        menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -MENU_GAP)
        menu.Blocker:Show()
        menu:Show()
        openMenu = menu
        restate()
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    -- Closing the panel with a list open would strand it on screen: it is parented to UIParent.
    parent:HookScript("OnHide", function()
        if openMenu == menu then closeFilterMenu() end
    end)
    return btn
end

-- Both row kinds share one pool, so a repaint never has to know how many of each the last one used.
function CP.NewRowPool(parent, builder)
    return {
        rows = {},
        acquire = function(self)
            for _, row in ipairs(self.rows) do
                if not row._inUse then row._inUse = true; row:Show(); return row end
            end
            local row = builder(parent)
            self.rows[#self.rows + 1] = row
            row._inUse = true
            return row
        end,
        releaseAll = function(self)
            for _, row in ipairs(self.rows) do row._inUse = false; row:Hide() end
        end,
    }
end

-- Building a frame mid-animation shows as a stutter, so build a screenful of each kind up front.
-- Deferred: the scroll frame has no height to divide until it has been through a layout pass.
function CP.PrewarmRowPools(scroll, rowHeight, pools)
    addon:After(0, function()
        local visible = math.floor((scroll:GetHeight() or 0) / rowHeight) + 2
        if visible < 1 then return end
        for _, pool in pairs(pools) do
            for _ = 1, visible do pool:acquire() end
            pool:releaseAll()
        end
    end)
end

-- Parented to the PANE: FauxScrollFrame_Update hides the scroll frame whenever the list fits.
function CP.BuildListPane(host, scrollName, rowHeight, repaint, bottomInset, topInset)
    topInset = topInset or 0
    local scroll = CreateFrame("ScrollFrame", scrollName, host, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -(6 + topInset))

    -- 3.3.5a has no SetClipsChildren, so the rows ride in a ScrollFrame purely for its clipping --
    -- that is what lets the entry on the bottom edge show as a half row instead of not at all.
    local clipper = CreateFrame("ScrollFrame", nil, host)
    clipper:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -(6 + topInset))
    clipper:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", BAR_GUTTER, 6 + (bottomInset or 0))

    -- The scroll frame's shown state IS whether a gutter is needed. Frozen mid-reveal: a list right
    -- on the threshold flips it back and forth, re-anchoring and repainting on every frame.
    local content, lastRight

    -- A scroll child takes its position from its frame, so it is resized to the viewport rather
    -- than anchored to it. The spare row of height keeps the half row inside its own bounds.
    local function sizeContent()
        if not content then return end
        content:SetSize(math.max(1, clipper:GetWidth() or 1),
            math.max(1, clipper:GetHeight() or 1) + rowHeight)
    end

    local function anchorRight()
        if CP.ListRevealActive and CP.ListRevealActive() then return end
        local right = scroll:IsShown() and BAR_GUTTER or FLUSH_MARGIN
        if right ~= lastRight then
            lastRight = right
            scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, 6 + (bottomInset or 0))
            clipper:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, 6 + (bottomInset or 0))
        end
        -- Unguarded: the paint reads the width straight after this, and a pane that only just
        -- gained a size never changes gutter, so the early-out would leave the rows 1px wide.
        sizeContent()
    end
    anchorRight()

    -- Called by the paint itself, after FauxScrollFrame_Update has decided on the bar and before the
    -- width is read. Off the scroll frame's own OnShow/OnHide it always fired too late.
    scroll._duiAnchorRight = anchorRight
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, repaint)
    end)

    -- The template's own slider drives the offset; the wheel has to be wired to it by hand.
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = _G[(self:GetName() or "") .. "ScrollBar"]
        if not bar then return end
        local min, max = bar:GetMinMaxValues()
        local value = bar:GetValue() - delta * rowHeight
        if value < min then value = min elseif value > max then value = max end
        bar:SetValue(value)
    end)
    if CP.ReskinScrollBar then
        CP.ReskinScrollBar(scroll, host, topInset, CP.LIST_SCROLLBAR_X, bottomInset, true)
    end

    -- In the clipper, not the faux frame: that one hides itself the moment the list fits, and
    -- everything hanging off it would go with it.
    content = CreateFrame("Frame", nil, clipper)
    content:SetSize(1, 1)
    clipper:SetScrollChild(content)
    content:SetFrameLevel(scroll:GetFrameLevel() + 5)
    sizeContent()
    clipper:SetScript("OnSizeChanged", sizeContent)

    return scroll, content
end

-- A pane laid out by anchors has no measurable width until the next layout pass, so painting inside
-- its own OnShow draws nothing the very first time it is shown.
function CP.WireListPaneShow(pane, refresh)
    pane:SetScript("OnShow", function()
        refresh()
        addon:After(0, refresh)
    end)
end

-- Lays out one screenful from `flat`. Guarded against re-entry: FauxScrollFrame_Update calls
-- SetValue(0) whenever the list fits, which fires OnVerticalScroll straight back into here.
local painting

function CP.PaintListRows(scroll, content, flat, rowHeight, pools, paint)
    if painting then return end
    painting = true

    for _, pool in pairs(pools) do pool:releaseAll() end

    local visible = math.max(1, math.floor((scroll:GetHeight() or rowHeight) / rowHeight))
    FauxScrollFrame_Update(scroll, #flat, visible, rowHeight)

    -- FauxScrollFrame_Update sizes the child to numItems*rowHeight while giving the slider a range
    -- of (numItems - visible)*rowHeight, and the viewport is not a whole number of rows, so the
    -- slider outruns what SetVerticalScroll accepts. The clamp then writes the slider back mid-drag
    -- and the thumb fights the cursor. Sized so both ranges agree and nothing clamps.
    local child = scroll:GetScrollChild()
    if child and scroll:IsShown() then
        child:SetHeight((scroll:GetHeight() or 0) + math.max(0, (#flat - visible) * rowHeight))
    end
    -- Between deciding whether the bar is needed and reading the width that depends on it.
    if scroll._duiAnchorRight then scroll._duiAnchorRight() end
    if CP.SyncScrollThumb then CP.SyncScrollThumb(scroll) end

    local offset = FauxScrollFrame_GetOffset(scroll) or 0
    local width = content:GetWidth() or 0
    if width <= 0 then
        painting = nil
        return
    end

    -- One past what fits: the clipper cuts it to a sliver, and that sliver is the only thing that
    -- tells the player there is more list below the fold.
    for i = 1, visible + 1 do
        local index = offset + i
        local data = flat[index]
        if data then
            local row, indent = paint(data)
            if row then
                indent = indent or 0
                row:ClearAllPoints()
                row:SetWidth(width - indent)
                -- Lets the tail follow a closing section up instead of jumping once it is gone.
                row:SetPoint("TOPLEFT", content, "TOPLEFT", indent,
                    -(i - 1) * rowHeight + CP.ListRevealShift(index, rowHeight))
                row:Show()
                -- Asked per index, not remembered per frame: rows are recycled between passes.
                row:SetAlpha(CP.ListRevealAlpha(index))
            end
        end
    end

    painting = nil
end
