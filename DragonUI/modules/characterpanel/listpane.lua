local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The scaffold Reputation, Skills and Currency share: a pane over the Inset, a scrolling viewport
-- and a pool of recycled rows -- the lists renumber on every expand, so the set is rebuilt constantly.

CP.LIST_ROW_H = 24

CP.LIST_SCROLLBAR_X = -4

-- Right edge of the viewport with and without a scrollbar to leave room for.
local BAR_GUTTER, FLUSH_MARGIN = -14, -6

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

    -- The scroll frame's shown state IS whether a gutter is needed. Frozen mid-reveal: a list right
    -- on the threshold flips it back and forth, re-anchoring and repainting on every frame.
    local content, lastRight

    local function anchorRight()
        if CP.ListRevealActive and CP.ListRevealActive() then return end
        local right = scroll:IsShown() and BAR_GUTTER or FLUSH_MARGIN
        if right == lastRight then return end
        lastRight = right

        scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, 6 + (bottomInset or 0))
        if content then content:SetPoint("RIGHT", host, "RIGHT", right, 0) end
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
        CP.ReskinScrollBar(scroll, host, topInset, CP.LIST_SCROLLBAR_X, bottomInset)
    end

    -- Anchored to the HOST: FauxScrollFrame_Update hides the scroll frame the moment the list fits,
    -- and everything hanging off it goes indeterminate with it.
    content = CreateFrame("Frame", nil, host)
    content:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -(6 + topInset))
    content:SetPoint("RIGHT", host, "RIGHT", BAR_GUTTER, 0)
    content:SetHeight(1)
    content:SetFrameLevel(scroll:GetFrameLevel() + 5)
    -- Re-run now the content exists, so its right edge starts in step with the viewport's.
    anchorRight()

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

    for i = 1, visible do
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
