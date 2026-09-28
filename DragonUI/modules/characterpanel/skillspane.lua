-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The Skills tab, rendered by us instead of SkillFrame, on the Reputation scaffold. Skill headers
-- report isExpanded where faction headers report isCollapsed, so the flag is flipped on the way in.

local ROW_H = 24
-- Matched to reputationpane.lua: same bar, same frame, same texcoords.
local BAR_W, BAR_H = 99, 13
local FRAME_TEX = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar"
local FRAME_LEFT_W, FRAME_H = 60, 15
local CHILD_INDENT = 12
local FILL = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"

-- The unlearn control. Idle alpha keeps a column of them from reading as a row of live buttons;
-- the glyph comes up to full on hover, which is the only cue needed for something destructive.
local UNLEARN_GLYPH = 14
local UNLEARN_HIT = 20
local UNLEARN_IDLE_ALPHA = 0.35

-- SkillFrame tints by skillCostType, nil for nearly every skill; here the tint tells progress.
local SHADE_CAPPED = { 1.0, 0.94, 0.1 }
local SHADE_TRAINABLE = { 0.2, 0.85, 0.2 }
local SHADE_DORMANT = { 0.5, 0.5, 0.5 }

local pane, scroll, content

-- Retail dropped this tab entirely, so there is no filter of theirs to copy. Hiding what is already
-- capped is the practical one here: what is left is exactly what still has room to move.
-- In the profile, not a local: a filter that silently forgets itself on every reload reads as the
-- setting having failed rather than as it never having been kept.
local filterButton

local function hideMaxed()
    return CP:Config().skills_hide_maxed and true or false
end

-- The label carries the state, the way retail's reads "All": a static "Filter" says nothing about
-- whether anything is being filtered right now.
local function updateSelection()
    if filterButton then
        filterButton:SetSelection(hideMaxed() and addon.L["Hide maxed out"] or addon.L["All"])
    end
end

local function filterMenuEntries()
    local function entry(text, wanted)
        return {
            text = text,
            checked = hideMaxed() == wanted,
            func = function()
                CP:Config().skills_hide_maxed = wanted
                updateSelection()
                if CP.RefreshSkillsPane then CP.RefreshSkillsPane() end
            end,
        }
    end
    return { entry(addon.L["All"], false), entry(addon.L["Hide maxed out"], true) }
end
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
    glyph:SetAtlasTexture("common-icon-delete")
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

    -- Hung off the unlearn slot even while it is hidden, so every bar in the column lines up.
    row.Meter = CP.BuildRowBar(row, unlearn, "LEFT", -2, {
        width = BAR_W,
        height = BAR_H,
        fill = FILL,
        frame = FRAME_TEX,
        capWidth = FRAME_LEFT_W,
        frameHeight = FRAME_H,
    })

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetJustifyH("LEFT")
    title:SetPoint("RIGHT", row.Meter, "LEFT", -8, 0)
    title:SetPoint("LEFT", row, "LEFT", CHILD_INDENT, 0)
    row.Title = title

    local wash = row:CreateTexture(nil, "HIGHLIGHT")
    wash:SetTexture(1, 1, 1)
    wash:SetAlpha(0.1)
    wash:SetAllPoints(row)

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
    local unlearn, name = row.Unlearn, info.name
    unlearn._index, unlearn._name = info.index, name
    unlearn.Glyph:SetAlpha(UNLEARN_IDLE_ALPHA)
    unlearn:SetShownCompat(info.isAbandonable)

    row.Title:SetText(name or "")
    row._skillName, row._description = name, info.description

    local ceiling = info.maxRank or 0
    local rank = (info.rank or 0) + (info.tempPoints or 0)

    -- A max of one is a proficiency: known or not, there is no track to show.
    local span, filled, shade, caption = 1, 1, SHADE_DORMANT, ""
    if ceiling > 1 then
        span, filled = ceiling, rank
        caption = rankText(rank, info.modifier, ceiling)
        if rank >= ceiling then
            shade = SHADE_CAPPED
        elseif rank > 0 then
            shade = SHADE_TRAINABLE
        end
    end

    local meter = row.Meter
    meter:SetMinMaxValues(0, span)
    meter:SetValue(filled)
    meter:SetStatusBarColor(shade[1], shade[2], shade[3])
    meter.Caption:SetText(caption)
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
        -- A max rank of one is a proficiency, not a track, so it is never "maxed out" for this.
        local capped = hideMaxed() and not isHeader and (maxRank or 0) > 1
                       and (rank or 0) >= maxRank
        if name and name ~= "" and not capped then
            flat[#flat + 1] = {
                kind = isHeader and "header" or "entry",
                index = i, name = name, isCollapsed = not isExpanded,
                rank = rank, tempPoints = tempPoints, modifier = modifier, maxRank = maxRank,
                isAbandonable = isAbandonable, description = description,
            }
        end
    end

    -- A category whose every skill was filtered out would otherwise sit there with nothing under it.
    -- Collapsed ones stay: the API omits their children, so emptiness cannot be told from hidden.
    if hideMaxed() then
        local kept = {}
        for i = 1, #flat do
            local row, nextRow = flat[i], flat[i + 1]
            local empty = row.kind == "header" and not row.isCollapsed
                and (not nextRow or nextRow.kind == "header")
            if not empty then kept[#kept + 1] = row end
        end
        flat = kept
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

    -- Up in the title strip, on the same right edge as the paperdoll tab's cog. Anchored inside the
    -- pane instead, it sat in the list and ate a row.
    if CP.CreateFilterDropdown then
        local cf = _G.CharacterFrame
        filterButton = CP.CreateFilterDropdown(pane, "DragonUISkillsFilter", CP.FILTER_DROPDOWN_W, filterMenuEntries)
        filterButton:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 20)
        CP.AnchorFilterDropdown(pane, filterButton)
        updateSelection()
    end

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
