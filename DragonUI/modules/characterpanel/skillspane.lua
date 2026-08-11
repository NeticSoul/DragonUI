local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The Skills tab, rendered by us instead of SkillFrame, on the Reputation scaffold. Skill headers
-- report isExpanded where faction headers report isCollapsed, so the flag is flipped on the way in.

local ROW_H = 24
local BAR_W, BAR_H = 132, 13
local CHILD_INDENT = 12
local FILL = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"

-- The unlearn control. Idle alpha keeps a column of them from reading as a row of live buttons;
-- the glyph comes up to full on hover, which is the only cue needed for something destructive.
local UNLEARN_GLYPH = 14
local UNLEARN_HIT = 20
local UNLEARN_IDLE_ALPHA = 0.35

-- Stock paints every ordinary skill bar flat grey because it colours by skillCostType, which is nil
-- for almost everything; the reference reads progress off the colour instead.
local CAPPED = { 1.0, 0.94, 0.1 }
local TRAINABLE = { 0.2, 0.85, 0.2 }
local DORMANT = { 0.5, 0.5, 0.5 }

local pane, scroll, content
local headers, entries
local flat = {}
-- Declared here because toggleHeader hands it to the reveal driver, and it is defined further down.
local repaint

local function toggleHeader(index, collapsed)
    if collapsed then
        if ExpandSkillHeader then ExpandSkillHeader(index) end
        CP.RefreshSkillsPane()
        -- After the refresh, so the run being revealed is read off the rebuilt list.
        CP.RevealChildrenOf(flat, index, repaint)
    else
        -- The rows are still live here; collapsing for real is what `finish` does.
        CP.FadeOutChildrenOf(flat, index, repaint, function()
            if CollapseSkillHeader then CollapseSkillHeader(index) end
            CP.RefreshSkillsPane()
        end)
    end
end

local function buildEntry(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    -- Blizzard's own unlearn path: the popup carries the skill index and AbandonSkill runs from its
    -- OnAccept. Only professions report isAbandonable, so most rows never show this.
    local unlearn = CreateFrame("Button", nil, row)
    unlearn:SetSize(UNLEARN_HIT, ROW_H)
    unlearn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    unlearn:Hide()

    local glyph = unlearn:CreateTexture(nil, "OVERLAY")
    glyph:set_atlas("common-icon-delete")
    glyph:SetSize(UNLEARN_GLYPH, UNLEARN_GLYPH)
    glyph:SetPoint("CENTER", unlearn, "CENTER", 0, 0)
    glyph:SetAlpha(UNLEARN_IDLE_ALPHA)
    unlearn.Glyph = glyph

    unlearn:SetScript("OnClick", function(self)
        if not self._index then return end
        local dialog = StaticPopup_Show("UNLEARN_SKILL", self._name)
        if dialog then dialog.data = self._index end
    end)
    -- Not UNLEARN_SKILL_TOOLTIP: Blizzard hardcoded that one to "Unlearn this profession" and
    -- reuses it for anything abandonable, which lies on a faction-change language.
    unlearn:SetScript("OnEnter", function(self)
        self.Glyph:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(UNLEARN, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        GameTooltip:AddLine(self._name or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    unlearn:SetScript("OnLeave", function(self)
        self.Glyph:SetAlpha(UNLEARN_IDLE_ALPHA)
        GameTooltip:Hide()
    end)
    row.Unlearn = unlearn

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetPoint("RIGHT", unlearn, "LEFT", -2, 0)
    bar:SetStatusBarTexture(FILL)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    -- Pushed to BORDER so the outline below can sit above it without hiding the fill.
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetDrawLayer("BORDER") end

    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(bar)
    back:SetTexture(0, 0, 0)

    local function edge()
        local t = bar:CreateTexture(nil, "OVERLAY")
        t:SetTexture(0, 0, 0)
        t:SetAlpha(0.9)
        return t
    end
    local top = edge()
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    top:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
    top:SetHeight(1)
    local bottom = edge()
    bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
    bottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    bottom:SetHeight(1)
    local left = edge()
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
    left:SetWidth(1)
    local right = edge()
    right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
    right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    right:SetWidth(1)

    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    row.Bar = bar

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", row, "LEFT", CHILD_INDENT, 0)
    -- Bounded by the bar so a long skill name truncates instead of running under it.
    name:SetPoint("RIGHT", bar, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    row.Text = name

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(1, 1, 1)
    hl:SetAlpha(0.1)
    hl:SetAllPoints(row)

    -- Blizzard puts the skill description in a detail pane below the list. There is no room for one
    -- at this width, and it is the only thing that pane carried, so it moves into the tooltip.
    row:SetScript("OnEnter", function(self)
        if not self._description or self._description == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self._skillName or "", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
            NORMAL_FONT_COLOR.b)
        GameTooltip:AddLine(self._description, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

-- Blizzard's own rank string: the temporary points count toward the rank, and a buff or debuff on
-- the skill is spelled out in brackets rather than folded into the number.
local function rankText(rank, modifier, maxRank)
    if not modifier or modifier == 0 then
        return rank .. "/" .. maxRank
    end
    local color = (modifier > 0) and (GREEN_FONT_COLOR_CODE .. "+") or RED_FONT_COLOR_CODE
    return rank .. " (" .. color .. modifier .. FONT_COLOR_CODE_CLOSE .. ")/" .. maxRank
end

local function updateEntry(row, info)
    row.Text:SetText(info.name or "")
    row._skillName, row._description = info.name, info.description

    local unlearn = row.Unlearn
    unlearn._index, unlearn._name = info.index, info.name
    unlearn.Glyph:SetAlpha(UNLEARN_IDLE_ALPHA)
    if info.isAbandonable then unlearn:Show() else unlearn:Hide() end

    local bar = row.Bar
    local maxRank = info.maxRank or 0
    local rank = (info.rank or 0) + (info.tempPoints or 0)

    -- A max rank of one is a proficiency, not a track: it is either known or absent, so it shows
    -- as a full dormant bar with no numbers rather than as "1/1".
    if maxRank <= 1 then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetStatusBarColor(DORMANT[1], DORMANT[2], DORMANT[3])
        bar.Text:SetText("")
        return
    end

    bar:SetMinMaxValues(0, maxRank)
    bar:SetValue(rank)

    local color = DORMANT
    if rank >= maxRank then
        color = CAPPED
    elseif rank > 0 then
        color = TRAINABLE
    end
    bar:SetStatusBarColor(color[1], color[2], color[3])
    bar.Text:SetText(rankText(rank, info.modifier, maxRank))
end

repaint = function()
    if not (scroll and content) then return end
    CP.PaintListRows(scroll, content, flat, ROW_H, { headers, entries }, function(data)
        if data.kind == "header" then
            local row = headers:acquire()
            CP.UpdateListHeader(row, data.name, data.index, data.isCollapsed)
            return row, 0
        end
        local row = entries:acquire()
        updateEntry(row, data)
        return row, 0
    end)
end

local function refresh()
    if not pane or not pane:IsShown() then return end

    flat = {}
    for i = 1, (GetNumSkillLines and GetNumSkillLines() or 0) do
        local name, isHeader, isExpanded, rank, tempPoints, modifier, maxRank,
              isAbandonable, _, _, _, _, description = GetSkillLineInfo(i)
        if name and name ~= "" then
            flat[#flat + 1] = {
                kind = isHeader and "header" or "entry",
                index = i, name = name, isCollapsed = not isExpanded,
                rank = rank, tempPoints = tempPoints, modifier = modifier, maxRank = maxRank,
                isAbandonable = isAbandonable, description = description,
            }
        end
    end
    repaint()
end

CP.RefreshSkillsPane = refresh

-- Same treatment reputationpane.lua gives ReputationFrame: the bars are child FRAMES the chrome
-- sweep never reaches, and Show is redirected because the stock path re-shows them per tab switch.
local function suppressBlizzard(frame)
    if not frame or frame._duiSuppressed then return end
    frame._duiSuppressed = true

    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child.Show = child.Hide
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:Hide()
            region.Show = region.Hide
        end
    end
end

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.Inset then return end

    pane = CreateFrame("Frame", "DragonUISkillsPane", cf.Inset)
    pane:SetAllPoints(cf.Inset)
    pane:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 5)
    pane:Hide()

    scroll, content = CP.BuildListPane(pane, "DragonUISkillsScroll", ROW_H, repaint)
    headers = CP.NewRowPool(content, function(parent)
        return CP.BuildListHeader(parent, toggleHeader)
    end)
    entries = CP.NewRowPool(content, buildEntry)
    CP.PrewarmRowPools(scroll, ROW_H, { headers, entries })

    CP.WireListPaneShow(pane, refresh)
    scroll:HookScript("OnSizeChanged", repaint)

    local blizzard = _G.SkillFrame
    if blizzard then
        suppressBlizzard(blizzard)
        blizzard:HookScript("OnShow", function()
            suppressBlizzard(blizzard)
            pane:Show()
        end)
        blizzard:HookScript("OnHide", function() pane:Hide() end)
        if blizzard:IsShown() then pane:Show() end
    end
end

CP.SkillsPane = function() return pane end

local events = CreateFrame("Frame")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:SetScript("OnEvent", refresh)

CP:RegisterBuilder("skillspane", build)
