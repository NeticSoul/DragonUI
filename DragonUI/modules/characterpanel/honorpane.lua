local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The Honor tab, on the same list scaffold as Reputation, Skills and Currency. There is
-- deliberately no this-week section: GetPVPThisWeekStats is commented out in Blizzard's own file.

local ROW_H = 24
local LABEL_INSET = 12

-- Masthead above the list; its height is where the scroll viewport starts. The badges are 2004 art
-- and small, sized to the ring's OPENING and to the smallest insignia's footprint.
local CREST_SIZE = 24
local RING_W, RING_H = 62, 64
local MASTHEAD_INSET_X, MASTHEAD_INSET_Y = 14, 10

-- Gap between the ring and the label, and how far the first line rides above the ring's centre.
local TEXT_GAP, TEXT_RISE = 4, 9
local MASTHEAD_H = 76
-- Badge index is the SECOND return of GetPVPRankInfo, zero-padded, as HonorFrame.lua builds it.
-- Fourteen badges shared by both factions; only the names differ, and those come from the API.
local MAX_RANK = 14

-- The client's own insignia; no higher-resolution set exists, so the frame is where the new art is.
local RANK_BADGE = "Interface\\PvPRankBadges\\PvPRank%02d"
local FRAME_NAME = "DragonUIHonorFrame"
local TAB_INDEX = 6

local pane, scroll, content, masthead
local headers, entries
local flat = {}
local collapsed = {}
local repaint

local function num(v)
    return tostring(tonumber(v) or 0)
end

-- There is no CURRENT pvp rank on this client: ranking went away in 2.0 and UnitPVPRank returns 0.
-- The historical best from GetPVPLifetimeStats is what this reports, passed to GetPVPRankInfo raw.
local function rankInfo()
    local _, highest = GetPVPLifetimeStats()
    if not highest or highest <= 0 then return nil, nil end
    local name, number = GetPVPRankInfo(highest)
    return name, tonumber(number)
end

local function highestRankName()
    return (rankInfo()) or addon.L["Unranked"]
end

-- Each section is { key, title, rows() } and only runs its reader when the section is open, so a
-- collapsed board costs nothing to rebuild.
local SECTIONS = {
    { key = "today", title = HONOR_TODAY, rows = function()
        local hk, honor = GetPVPSessionStats()
        return { { HONORABLE_KILLS, num(hk) }, { HONOR_CONTRIBUTION_POINTS, num(honor) } }
    end },
    { key = "yesterday", title = HONOR_YESTERDAY, rows = function()
        local hk, honor = GetPVPYesterdayStats()
        return { { HONORABLE_KILLS, num(hk) }, { HONOR_CONTRIBUTION_POINTS, num(honor) } }
    end },
    { key = "lifetime", title = HONOR_LIFETIME, rows = function()
        local hk = GetPVPLifetimeStats()
        return { { HONORABLE_KILLS, num(hk) }, { HONOR_HIGHEST_RANK, highestRankName() } }
    end },
    { key = "points", title = CURRENCY or "Currency", rows = function()
        return {
            { HONOR_POINTS, num(GetHonorCurrency and GetHonorCurrency()) },
            { ARENA_POINTS, num(GetArenaCurrency and GetArenaCurrency()) },
        }
    end },
    { key = "arena", title = ARENA_TEAM, rows = function()
        local out = {}
        for i = 1, (MAX_ARENA_TEAMS or 3) do
            local name, size, rating, weekPlayed, weekWins = GetArenaTeam(i)
            if name then
                out[#out + 1] = {
                    string.format("%dv%d  %s", size or 0, size or 0, name), num(rating),
                }
                out[#out + 1] = {
                    "   " .. ARENA_THIS_WEEK,
                    string.format("%d - %d", weekWins or 0, (weekPlayed or 0) - (weekWins or 0)),
                }
            end
        end
        if #out == 0 then out[1] = { ARENA_TEAM, NONE or "None" } end
        return out
    end },
}

local function buildMasthead(host)
    -- Ring and label live in one block rather than each pinned to the pane, which is what keeps
    -- them aligned to each other.
    local block = CreateFrame("Frame", nil, host)
    block:SetHeight(RING_H)
    block:SetPoint("TOPLEFT", host, "TOPLEFT", MASTHEAD_INSET_X, -MASTHEAD_INSET_Y)

    local ring = block:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(RING_W, RING_H)
    ring:SetPoint("LEFT", block, "LEFT", 0, 0)
    ring:Hide()

    local crest = block:CreateTexture(nil, "ARTWORK")
    crest:SetSize(CREST_SIZE, CREST_SIZE)
    crest:SetPoint("CENTER", ring, "CENTER", 0, 0)
    crest:Hide()

    local rank = block:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rank:SetPoint("LEFT", ring, "RIGHT", TEXT_GAP, TEXT_RISE)
    rank:SetJustifyH("LEFT")

    local who = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    who:SetPoint("TOPLEFT", rank, "BOTTOMLEFT", 0, -5)
    who:SetJustifyH("LEFT")

    return { block = block, ring = ring, crest = crest, rank = rank, who = who }
end

-- The ring is the masthead's own furniture, not part of the insignia, so it stays up with nothing
-- to frame; only the badge inside it depends on having earned a rank.
local function updateRing(m)
    local faction = UnitFactionGroup("player")
    local ring = faction and ("honorsystem-portrait-" .. faction:lower())
    -- Only if the ring art is actually installed; the badge stands on its own without it.
    if ring and addon.atlasinfo and addon.atlasinfo[ring] then
        m.ring:set_atlas(ring, true)
        -- After, always: set_atlas re-stamps the atlas's own 50x52 and would undo the size this
        -- pane draws the ring at.
        m.ring:SetSize(RING_W, RING_H)
        m.ring:Show()
    else
        m.ring:Hide()
    end
end

local function updateMasthead(m)
    if not m then return end

    updateRing(m)

    local name, number = rankInfo()
    if name and number and number > 0 then
        m.rank:SetFormattedText("%s  (%s %d)", name, RANK or "Rank", number)
        -- Only for a number vanilla shipped art for: anything else asks for a texture that does not
        -- exist and renders as the green placeholder block.
        if number <= MAX_RANK then
            m.crest:SetTexture(string.format(RANK_BADGE, number))
            m.crest:Show()
        else
            m.crest:Hide()
        end
    else
        m.rank:SetText(name or addon.L["Unranked"])
        m.crest:Hide()
    end

    -- The title bar already carries the character's name, but not the level, and on this tab there
    -- is no paperdoll to read it off.
    m.who:SetFormattedText("%s  %s %d",
        UnitName("player") or "", LEVEL or "Level", UnitLevel("player") or 0)

    -- Sized to what it actually holds, once both lines carry their final text. GetStringWidth, not
    -- GetWidth: on a FontString the latter reports the box rather than the text.
    local text = math.max(m.rank:GetStringWidth() or 0, m.who:GetStringWidth() or 0)
    m.block:SetWidth(RING_W + TEXT_GAP + text)
end

local function buildEntry(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)

    -- Small faces: this board is dense label/value pairs, and the full-size fonts the other tabs
    -- use for faction and skill names read as oversized here.
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", row, "RIGHT", -LABEL_INSET, 0)
    value:SetJustifyH("RIGHT")
    row.Value = value

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", LABEL_INSET, 0)
    -- Bounded by the value so a long team name truncates instead of running under its rating.
    label:SetPoint("RIGHT", value, "LEFT", -8, 0)
    label:SetJustifyH("LEFT")
    row.Text = label

    return row
end

-- Where each section's header sits in `flat`. A section spans a header plus however many lines it
-- produces, and the reveal helpers address rows by flat position, not by section.
local headerRow = {}

local function rebuild()
    flat = {}
    headerRow = {}
    for i, section in ipairs(SECTIONS) do
        local isCollapsed = collapsed[section.key] and true or false
        flat[#flat + 1] = {
            kind = "header", index = i, name = section.title, isCollapsed = isCollapsed,
        }
        headerRow[i] = #flat
        if not isCollapsed then
            for _, entry in ipairs(section.rows()) do
                flat[#flat + 1] = { kind = "entry", label = entry[1], value = entry[2] }
            end
        end
    end
end

local function toggleHeader(index, isCollapsed)
    local section = SECTIONS[index]
    if not section then return end

    if isCollapsed then
        collapsed[section.key] = false
        rebuild()
        repaint()
        -- Read after the rebuild: the rows being revealed only exist in the new list.
        CP.RevealChildrenOf(flat, headerRow[index], repaint)
    else
        -- Faded out first, then dropped: collapsing up front takes the rows off the list before
        -- there is anything left on screen to animate.
        CP.FadeOutChildrenOf(flat, headerRow[index], repaint, function()
            collapsed[section.key] = true
            rebuild()
            repaint()
        end)
    end
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
        row.Text:SetText(data.label or "")
        row.Value:SetText(data.value or "")
        return row, 0
    end)
end

local function refresh()
    if not pane or not pane:IsShown() then return end
    updateMasthead(masthead)
    rebuild()
    repaint()
end

CP.RefreshHonorPane = refresh

-- Blizzard's strip is five buttons wired by name, so a sixth is built here. It still has to be
-- NAMED CharacterFrameTab6: PanelTemplates_UpdateTabs finds tabs by that pattern.
local function buildTab()
    local cf = _G.CharacterFrame
    if not cf or _G["CharacterFrameTab" .. TAB_INDEX] then return end

    local tab = CreateFrame("Button", "CharacterFrameTab" .. TAB_INDEX, cf,
                            "CharacterFrameTabButtonTemplate")
    tab:SetID(TAB_INDEX)
    tab:SetText(HONOR)
    tab:SetScript("OnClick", function()
        ToggleCharacter(FRAME_NAME)
        PlaySound("igCharacterInfoTab")
    end)

    -- No PanelTemplates_SetNumTabs: raising numTabs is what makes UpdateTabs read our own global.
    if CP.RechainTabs then CP.RechainTabs() end
end

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.Inset then return end

    pane = CreateFrame("Frame", FRAME_NAME, cf)
    pane:SetAllPoints(cf)
    pane:SetID(TAB_INDEX)
    pane:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL)
    pane:Hide()

    -- Kept out of CHARACTERFRAME_SUBFRAMES: writing to that table taints the loop ToggleCharacter runs.
    hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
        local mine = frameName == FRAME_NAME
        if mine then pane:Show() else pane:Hide() end
        local tab = _G["CharacterFrameTab" .. TAB_INDEX]
        if tab then
            if mine then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end)

    local host = CreateFrame("Frame", nil, cf.Inset)
    host:SetAllPoints(cf.Inset)
    host:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 5)
    host:Hide()

    masthead = buildMasthead(host)
    scroll, content = CP.BuildListPane(host, "DragonUIHonorScroll", ROW_H, repaint, nil, MASTHEAD_H)
    headers = CP.NewRowPool(content, function(parent)
        return CP.BuildListHeader(parent, toggleHeader)
    end)
    entries = CP.NewRowPool(content, buildEntry)
    CP.PrewarmRowPools(scroll, ROW_H, { headers, entries })

    CP.WireListPaneShow(host, refresh)
    scroll:HookScript("OnSizeChanged", repaint)

    pane:SetScript("OnShow", function()
        if CP.ApplyChromeForTab then CP.ApplyChromeForTab(FRAME_NAME) end
        host:Show()
    end)
    pane:SetScript("OnHide", function() host:Hide() end)

    buildTab()
end

CP.HonorPane = function() return pane end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
events:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
events:RegisterEvent("HONOR_CURRENCY_UPDATE")
events:RegisterEvent("ARENA_TEAM_UPDATE")
events:SetScript("OnEvent", refresh)

CP:RegisterBuilder("honorpane", build)
