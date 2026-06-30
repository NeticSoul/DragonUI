-- DragonUI Options Panel - Search
-- By Neticsoul

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local AceGUI = LibStub("AceGUI-3.0")

local Panel    = addon.OptionsPanel
local Controls = addon.PanelControls

-- ============================================================================
-- STATE FLAGS
-- ============================================================================

Panel.searchIndex        = nil   -- nil = dirty
Panel.indexing           = false
Panel._currentIndexTab   = nil
Panel._currentTabText    = nil
Panel._currentSection    = nil
Panel._currentSubTabLabel = nil
Panel._currentSubTabKey  = nil
Panel._pendingQuery      = nil
Panel._lastRenderedQuery = nil

local SEARCH_FULL_CHARS  = 3
local SEARCH_SHORT_LIMIT = 20

function Panel:NormalizeSearchQuery(q)
    q = q or ""
    q = string.gsub(q, "^%s+", "")
    q = string.gsub(q, "%s+$", "")
    return q
end

function Panel:RunSearchQuery(q)
    q = self:NormalizeSearchQuery(q)
    if q == "" then
        self._lastRenderedQuery = nil
        if self.currentTab then self:SelectTab(self.currentTab) end
        return
    end
    self:BuildSearchIndex()
    self:ShowSearchResults(q)
end

-- ============================================================================
-- INDEX HARVEST
-- ============================================================================

function Panel:BuildSearchIndex()
    if self.searchIndex then return end
    self.searchIndex = {}
    self.indexing    = true
    for _, key in ipairs(self.tabOrder) do
        local info = self.tabs[key]
        self._currentIndexTab    = key
        self._currentTabText     = info.text or key
        self._currentSection     = nil
        self._currentSubTabLabel = nil
        self._currentSubTabKey   = nil
        if info.builder then
            local ok, err = pcall(info.builder, Controls.MakeStub())
            if not ok and addon.Debug then
                addon:Debug("search harvest failed for " .. key .. ": " .. tostring(err))
            end
        end
    end
    self.indexing              = false
    self._currentIndexTab      = nil
    self._currentTabText       = nil
    self._currentSection       = nil
    self._currentSubTabLabel   = nil
    self._currentSubTabKey     = nil

    if self.searchIndex and #self.searchIndex == 0 then
        if addon.Debug then addon:Debug("search harvest produced empty index; will retry next search") end
        self.searchIndex = nil
    end
end

-- ============================================================================
-- FILTER + RANKING + HIGHLIGHT
-- ============================================================================

local function Tokenize(query)
    local tokens = {}
    for word in query:gmatch("%S+") do
        tokens[#tokens + 1] = string.lower(word)
    end
    return tokens
end

local function EntryMatches(entry, tokens)
    for _, tok in ipairs(tokens) do
        if not entry.haystack:find(tok, 1, true) then
            return false
        end
    end
    return true
end

local function ScoreEntry(entry, tokens)
    local labelLow   = string.lower(entry.label)
    local sectionLow = entry.section and string.lower(entry.section) or ""
    local score = 0
    for _, tok in ipairs(tokens) do
        if labelLow:find(tok, 1, true) then
            if labelLow == tok then
                score = score + 100   -- exact label match
            elseif labelLow:sub(1, #tok) == tok then
                score = score + 50    -- label starts with token
            else
                score = score + 20    -- token anywhere in label
            end
        elseif sectionLow:find(tok, 1, true) then
            score = score + 8
        else
            score = score + 2         -- token only in desc / dbPath
        end
    end
    return score
end

-- limit nil = all matches; otherwise keep the top N by score in one pass.
local function FilterAndRank(entries, tokens, limit)
    if not limit or limit <= 0 then
        local out = {}
        for i = 1, #entries do
            local e = entries[i]
            if EntryMatches(e, tokens) then
                out[#out + 1] = e
            end
        end
        table.sort(out, function(a, b)
            return ScoreEntry(a, tokens) > ScoreEntry(b, tokens)
        end)
        return out, false
    end

    local top = {}
    local truncated = false
    for i = 1, #entries do
        local e = entries[i]
        if not EntryMatches(e, tokens) then
        elseif #top < limit then
            top[#top + 1] = { entry = e, score = ScoreEntry(e, tokens) }
            if #top == limit then
                table.sort(top, function(a, b) return a.score > b.score end)
            end
        else
            truncated = true
            local score = ScoreEntry(e, tokens)
            if score > top[limit].score then
                top[limit] = { entry = e, score = score }
                table.sort(top, function(a, b) return a.score > b.score end)
            end
        end
    end
    table.sort(top, function(a, b) return a.score > b.score end)
    local out = {}
    for j = 1, #top do
        out[j] = top[j].entry
    end
    return out, truncated
end

local function HighlightTokens(text, tokens)
    if not tokens or #tokens == 0 then return text end
    local textLow = string.lower(text)
    local spans   = {}
    for _, tok in ipairs(tokens) do
        local s, e = textLow:find(tok, 1, true)
        while s do
            spans[#spans + 1] = { s = s, e = e }
            s, e = textLow:find(tok, e + 1, true)
        end
    end
    if #spans == 0 then return text end
    table.sort(spans, function(a, b) return a.s < b.s end)
    local merged = { spans[1] }
    for i = 2, #spans do
        local last = merged[#merged]
        if spans[i].s <= last.e + 1 then
            last.e = math.max(last.e, spans[i].e)
        else
            merged[#merged + 1] = spans[i]
        end
    end
    -- Right-to-left so string indices stay valid.
    local result = text
    for i = #merged, 1, -1 do
        local m = merged[i]
        result = result:sub(1, m.s - 1)
               .. "|cffFFDD44"
               .. result:sub(m.s, m.e)
               .. "|r"
               .. result:sub(m.e + 1)
    end
    return result
end

-- ============================================================================
-- HIGHLIGHT ENGINE
-- ============================================================================

local PULSE_DURATION = 2.0
local PULSE_ALPHA    = 0.75

local function PulseAlpha(t)
    if t < 0.5 then
        return t / 0.5 * PULSE_ALPHA
    elseif t < 1.0 then
        return (1.0 - t) / 0.5 * PULSE_ALPHA
    elseif t < 1.5 then
        return (t - 1.0) / 0.5 * PULSE_ALPHA
    elseif t < PULSE_DURATION then
        return (PULSE_DURATION - t) / 0.5 * PULSE_ALPHA
    end
    return 0
end

-- Reused overlay; detach from pooled AceGUI frames when done.
local _overlay = nil
local function EnsureOverlay()
    if _overlay then return _overlay end
    local f = CreateFrame("Frame", "DragonUISearchHighlight", UIParent)
    f:EnableMouse(false)
    f:Hide()
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    tex:SetVertexColor(0.09, 0.52, 0.82, 0)
    f._tex = tex
    _overlay = f
    return f
end

local pulseFrame = CreateFrame("Frame", nil, UIParent)
pulseFrame:Hide()
pulseFrame:SetScript("OnUpdate", function(self, dt)
    self.elapsed = (self.elapsed or 0) + dt
    local t = self.elapsed
    if t >= PULSE_DURATION or not _overlay then
        if _overlay then
            _overlay._tex:SetVertexColor(0.09, 0.52, 0.82, 0)
            _overlay:Hide()
            _overlay:SetParent(UIParent)
        end
        self:Hide()
        return
    end
    local alpha = PulseAlpha(t)
    _overlay._tex:SetVertexColor(0.09, 0.52, 0.82, alpha)
end)

local highlightDefer = CreateFrame("Frame", nil, UIParent)
highlightDefer:Hide()
local scrollHoldFrame = CreateFrame("Frame", nil, UIParent)
scrollHoldFrame:Hide()

local SCROLL_LOCK_EXTRA = 0.75

local function CancelPendingScrollFix(sf)
    if sf and sf.scrollframe then
        sf.scrollframe:SetScript("OnUpdate", nil)
    end
end

local function ApplyScrollValue(sf, scrollValue, pixelOffset)
    local status = sf.status or sf.localstatus
    status.offset = pixelOffset
    status.scrollvalue = scrollValue
    sf:SetScroll(scrollValue)
    if sf.scrollbar then
        sf.scrollbar:SetValue(scrollValue)
    end
end

local function ClearSearchScrollLock(sf)
    if sf then
        sf._dragonSearchScrollValue = nil
        sf._dragonSearchScrollOffset = nil
    end
    Panel._searchNavigationUntil = nil
end

-- Re-apply scroll offset when AceGUI FixScroll runs.
local function EnsureFixScrollHook(sf)
    if sf._dragonFixScrollWrapped then return end
    local origFixScroll = sf.FixScroll
    if not origFixScroll then return end
    sf._dragonFixScrollWrapped = true
    sf.FixScroll = function(self)
        origFixScroll(self)
        local v = self._dragonSearchScrollValue
        if v then
            ApplyScrollValue(self, v, self._dragonSearchScrollOffset)
            CancelPendingScrollFix(self)
        end
    end
end

local function ArmSearchScrollLock(sf, scrollValue, pixelOffset)
    Panel._searchNavigationUntil = GetTime() + PULSE_DURATION + SCROLL_LOCK_EXTRA

    if scrollValue then
        sf._dragonSearchScrollValue = scrollValue
        sf._dragonSearchScrollOffset = pixelOffset
        EnsureFixScrollHook(sf)
    end
    CancelPendingScrollFix(sf)

    scrollHoldFrame:SetScript("OnUpdate", function(self)
        if GetTime() <= (Panel._searchNavigationUntil or 0) then
            local live = Panel.scrollWidget
            if live then CancelPendingScrollFix(live) end
            return
        end
        ClearSearchScrollLock(Panel.scrollWidget)
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end)
    scrollHoldFrame:Show()
end

-- Called from SelectTab before the widget tree is released.
function Panel:CancelHighlight()
    pulseFrame:Hide()
    pulseFrame.elapsed = 0
    ClearSearchScrollLock(Panel.scrollWidget)
    scrollHoldFrame:SetScript("OnUpdate", nil)
    scrollHoldFrame:Hide()
    if highlightDefer then
        highlightDefer:SetScript("OnUpdate", nil)
        highlightDefer:Hide()
    end
    if _overlay then
        _overlay._tex:SetVertexColor(0.09, 0.52, 0.82, 0)
        _overlay:Hide()
        _overlay:SetParent(UIParent)
    end
end

local function StartPulse(widgetFrame)
    if not widgetFrame then return end
    local hl = EnsureOverlay()
    hl:SetParent(widgetFrame)
    hl:SetFrameStrata(widgetFrame:GetFrameStrata())
    hl:SetFrameLevel(widgetFrame:GetFrameLevel() + 20)
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", widgetFrame, "TOPLEFT", -4, 4)
    hl:SetPoint("BOTTOMRIGHT", widgetFrame, "BOTTOMRIGHT", 4, -4)
    hl._tex:SetVertexColor(0.09, 0.52, 0.82, 0)
    hl:Show()
    pulseFrame.elapsed = 0
    pulseFrame:Show()
end

-- ============================================================================
-- WIDGET FINDER + SCROLL
-- ============================================================================

local function WidgetMatchesEntry(child, entry)
    local id = child._dragonId
    if not id then return false end
    if entry.dbPath and id == entry.dbPath then return true end
    if entry.label and id == entry.label then return true end
    return false
end

local function FindWidget(container, entry)
    if not container or not container.children then return nil end
    for _, child in ipairs(container.children) do
        if WidgetMatchesEntry(child, entry) then
            return child
        end
        if child.children then
            local found = FindWidget(child, entry)
            if found then return found end
        end
    end
    return nil
end

-- AceGUI SetScroll uses 0-1000, not pixels.
local function ApplyScrollToWidget(sf, widget)
    if not sf or not widget or not widget.frame then return end
    local content = sf.content
    local view = sf.scrollframe
    if not content or not view then return end

    local contentH = content:GetHeight() or 0
    local viewH = view:GetHeight() or 0
    local maxPix = contentH - viewH
    if maxPix <= 0 then return end

    local cTop = content:GetTop()
    local wTop = widget.frame:GetTop()
    if not cTop or not wTop then return end

    local pixelFromTop = cTop - wTop
    local newOffset = math.floor(pixelFromTop - viewH * 0.25)
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxPix then newOffset = maxPix end

    local value = newOffset / maxPix * 1000
    ApplyScrollValue(sf, value, newOffset)
    return value, newOffset
end

local function FinishHighlight(container, widget)
    CancelPendingScrollFix(container)
    local value, offset = ApplyScrollToWidget(container, widget)
    ArmSearchScrollLock(container, value, offset)
    StartPulse(widget.frame)
end

function Panel:HighlightSearchTarget(container, entry)
    if container.FixScroll then container:FixScroll() end
    CancelPendingScrollFix(container)

    local widget = FindWidget(container, entry)
    if not widget then
        Panel._searchNavInProgress = nil
        return false
    end

    local content = container.content
    local wTop = widget.frame and widget.frame:GetTop()
    local cTop = content and content:GetTop()
    if not cTop or not wTop then
        highlightDefer:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            self:Hide()
            FinishHighlight(container, widget)
            Panel._searchNavInProgress = nil
        end)
        highlightDefer:Show()
        return true
    end

    FinishHighlight(container, widget)
    Panel._searchNavInProgress = nil
    return true
end

-- ============================================================================
-- FONT HELPER
-- ============================================================================

local SEARCH_RESULT_FONT_SIZE = 14

local function SafeSetFont(fs, size, flags, preferredFont)
    if not fs then return end
    local tryFonts = {
        preferredFont,
        Controls.Theme and Controls.Theme.font,
        addon.Fonts and addon.Fonts.PRIMARY,
        STANDARD_TEXT_FONT,
        "Fonts\\FRIZQT__.TTF",
    }
    for _, fp in ipairs(tryFonts) do
        if fp and fs.SetFont and fs:SetFont(fp, size or 12, flags or "") then return end
    end
    if fs.SetFontObject then fs:SetFontObject(GameFontNormal) end
end

local function ApplySearchResultFont(widget)
    if not widget then return end
    -- Clear sub-tab font tag so reskin keeps search row size.
    widget._dragonSubTabFont = nil
    widget._dragonSearchFont = {
        Controls.Theme and Controls.Theme.font,
        SEARCH_RESULT_FONT_SIZE,
        "",
    }
    if widget.label then
        SafeSetFont(widget.label, SEARCH_RESULT_FONT_SIZE, "", widget._dragonSearchFont[1])
    end
end

-- ============================================================================
-- SHOW RESULTS
-- ============================================================================

function Panel:ShowSearchResults(query)
    if not self.scrollWidget then return end
    if query == self._lastRenderedQuery then return end
    self._lastRenderedQuery = query

    local scroll = self.scrollWidget
    Controls:ClearSearchFontTags(scroll)
    scroll:ReleaseChildren()

    if self.frame and self.frame.content then
        scroll.content:SetWidth(self.frame.content:GetWidth() - 32)
    end

    if scroll.frame then scroll.frame:Show() end

    local tokens = Tokenize(query)
    local limit  = (#query < SEARCH_FULL_CHARS) and SEARCH_SHORT_LIMIT or nil
    local results, truncated = FilterAndRank(self.searchIndex, tokens, limit)

    if truncated then
        local hint = AceGUI:Create("Label")
        hint:SetFullWidth(true)
        hint:SetText("|cffFFDD44" .. string.format(LO["Showing top %d results. Type at least 3 characters for the full list."], SEARCH_SHORT_LIMIT) .. "|r")
        ApplySearchResultFont(hint)
        scroll:AddChild(hint)
    end

    if #results == 0 then
        local msg = AceGUI:Create("Label")
        msg:SetFullWidth(true)
        msg:SetText(string.format(LO["No settings match '%s'."], query))
        ApplySearchResultFont(msg)
        scroll:AddChild(msg)
        ApplySearchResultFont(msg)
        scroll:DoLayout()
        if scroll.scrollbar then scroll.scrollbar:SetValue(0) end
        if self.reskinFrame then
            self.reskinFrame.elapsed = 0
            self.reskinFrame:Show()
        end
        return
    end

    for _, entry in ipairs(results) do
        local pathParts = { entry.tabText }
        if entry.section then pathParts[2] = entry.section end
        local breadcrumb = "|cff3d6b8a" .. table.concat(pathParts, "  >>  ") .. "|r"

        local highlightedLabel = HighlightTokens(entry.label, tokens)

        local displayText = breadcrumb .. "\n" .. highlightedLabel

        local row = AceGUI:Create("InteractiveLabel")
        row:SetFullWidth(true)
        if row.label then
            row.label:SetWordWrap(true)
        end
        row:SetText(displayText)
        ApplySearchResultFont(row)

        if not row.frame._searchHover then
            local hl = row.frame:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            hl:SetVertexColor(0.15, 0.45, 0.75, 0.18)
            hl:Hide()
            row.frame._searchHover = hl
        end

        local e = entry
        row:SetCallback("OnClick", function(w)
            GameTooltip:Hide()
            AceGUI:ClearFocus()
            if w.frame._searchHover then w.frame._searchHover:Hide() end
            -- Cancel debounce so it does not rebuild the tab after navigation.
            Panel._pendingQuery = nil
            Panel._lastRenderedQuery = nil
            if Panel.searchDebounce then
                Panel.searchDebounce:Hide()
                Panel.searchDebounce.elapsed = 0
            end
            Panel:SelectTab(e.tab, e)
        end)
        row:SetCallback("OnEnter", function(w)
            w.frame._searchHover:Show()
            GameTooltip:SetOwner(w.frame, "ANCHOR_NONE")
            local cx, cy = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale()
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / uiScale + 60, cy / uiScale)
            GameTooltip:SetText(e.label, 1, 1, 1)
            if e.desc then GameTooltip:AddLine(e.desc, 0.9, 0.9, 0.9, true) end
            GameTooltip:Show()
        end)
        row:SetCallback("OnLeave", function(w)
            w.frame._searchHover:Hide()
            GameTooltip:Hide()
        end)

        scroll:AddChild(row)
        ApplySearchResultFont(row)
    end

    scroll:DoLayout()
    if scroll.scrollbar then scroll.scrollbar:SetValue(0) end

    if self.reskinFrame then
        self.reskinFrame.elapsed = 0
        self.reskinFrame:Show()
    end
end

-- ============================================================================
-- DEBOUNCE FRAME
-- ============================================================================

Panel.searchDebounce = CreateFrame("Frame")
Panel.searchDebounce:Hide()
Panel.searchDebounce:SetScript("OnUpdate", function(self, elapsed)
    if Panel._searchNavInProgress then
        self:Hide()
        return
    end
    if Panel._searchNavigationUntil and GetTime() < Panel._searchNavigationUntil then
        self:Hide()
        return
    end
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.2 then return end
    self:Hide()

    local q = Panel._pendingQuery or ""
    Panel:RunSearchQuery(q)
end)
