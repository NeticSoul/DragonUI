local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The Honor tab. The reference ships one too, but as a fixed board of stat boxes over a retail
-- conquest-panel atlas we do not have; this is the same data on the scaffold the other three list
-- tabs already use, so it inherits their collapsing, their reveal animation and their scrollbar
-- rather than carrying a second look and a second set of bugs.
--
-- All native 3.3.5a API, tuples as PVPFrame.lua and HonorFrame.lua read them:
--   GetPVPSessionStats()   -> honourableKills, honor          (today)
--   GetPVPYesterdayStats() -> honourableKills, honor
--   GetPVPLifetimeStats()  -> honourableKills, highestRank
--   GetArenaTeam(i)        -> name, size, rating, weekPlayed, weekWins, seasonPlayed, seasonWins
-- There is deliberately no this-week or last-week section: GetPVPThisWeekStats and
-- GetPVPLastWeekStats are commented out in the client's own HonorFrame.lua, having gone with the
-- vanilla ranking system. The three periods above are exactly what PVPHonor_Update still reads.
-- Labels come from the client's own globals, so the tab is localised without adding a single key.

local ROW_H = 24
local LABEL_INSET = 12

-- Masthead above the list: rank insignia, rank name, and who the board belongs to. Its height is
-- what the scroll viewport starts below.
-- The badges are 2004 client art and small; drawn at the reference's 46 they are visibly upscaled.
-- Kept near their native size so they stay crisp.
-- The ring's opening is smaller than the ring, so the insignia is sized to the hole, not to the
-- frame -- and to the SMALLEST insignia's hole, since the fourteen are not all the same footprint
-- and the widest ones were spilling onto the metal.
local CREST_SIZE = 24
local RING_W, RING_H = 62, 64
local MASTHEAD_INSET_X, MASTHEAD_INSET_Y = 14, 10

-- Gap between the ring and the label, and how far the first line rides above the ring's centre.
local TEXT_GAP, TEXT_RISE = 4, 9
local MASTHEAD_H = 76
-- Badge index is the SECOND return of GetPVPRankInfo, not the raw rank, and it is zero-padded --
-- the same format HonorFrame.lua builds. Vanilla shipped fourteen badges shared by both factions;
-- only the names differ per faction, and those come from the API, so nothing here is hardcoded and
-- a server that renames or reorders its ranks still lands on the right art.
local MAX_RANK = 14

-- The client's own insignia. There is no higher-resolution set of these anywhere -- the rank system
-- went away in WotLK and nothing since has redrawn them -- so the frame around them is where the
-- modern art goes, not the badge itself.
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

-- There is no CURRENT pvp rank to read on this client. Ranking went away in 2.0 and the old ranks
-- became titles, so UnitPVPRank returns 0 -- it survives only in HonorFrame.lua, the dead vanilla
-- frame, while the live PVPHonor_Update shows no rank at all. What does persist is the historical
-- best in GetPVPLifetimeStats, and that is what this pane reports. Passed to GetPVPRankInfo raw,
-- which is the form it expects.
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
    -- Ring and label live in one block rather than each being pinned to the pane separately. That
    -- is what keeps them aligned to each other: the label hangs off the ring, the ring off the
    -- block, and only the block touches the pane.
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

local function updateMasthead(m)
    if not m then return end

    local name, number = rankInfo()
    if name and number and number > 0 then
        m.rank:SetFormattedText("%s  (%s %d)", name, RANK or "Rank", number)
        -- Only for a number vanilla actually shipped art for: a server handing back something
        -- outside that range would otherwise ask for a texture that does not exist, and the badge
        -- would render as the green placeholder block rather than simply not appearing.
        if number <= MAX_RANK then
            m.crest:SetTexture(string.format(RANK_BADGE, number))
            m.crest:Show()
            -- Only if the ring art is actually installed; the badge stands on its own without it.
            local faction = UnitFactionGroup("player")
            local ring = faction and ("honorsystem-portrait-" .. faction:lower())
            if ring and addon.atlasinfo and addon.atlasinfo[ring] then
                m.ring:set_atlas(ring, true)
                -- After, always: set_atlas re-stamps the atlas's own 50x52 and would undo the size
                -- this pane draws the ring at.
                m.ring:SetSize(RING_W, RING_H)
                m.ring:Show()
            else
                m.ring:Hide()
            end
        else
            m.crest:Hide()
            m.ring:Hide()
        end
    else
        m.rank:SetText(name or addon.L["Unranked"])
        m.crest:Hide()
        m.ring:Hide()
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

-- Where each section's header currently sits in `flat`. The other list tabs get this for free --
-- one API entry makes one row, so a faction's index IS its row number -- but here a section spans
-- a header plus however many lines it produces, and the reveal helpers address rows by flat
-- position. Handing them the section number instead animated the wrong run entirely.
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
        -- Faded out first, then dropped: collapsing up front would take the rows off the list
        -- before there was anything left on screen to animate. The position is read from the list
        -- as it stands now, which is the one still holding them.
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

-- Blizzard's tab strip is a fixed row of five buttons wired by name in CharacterFrameTab_OnClick,
-- so a sixth has to be built and driven here. It still has to be NAMED CharacterFrameTab6:
-- PanelTemplates_UpdateTabs finds tabs by that pattern, and without it selection would never
-- highlight ours.
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

    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(cf, TAB_INDEX) end
    if CP.RechainTabs then CP.RechainTabs() end
end

-- The pet tab goes away here rather than in tabs.lua because this is what replaces it. The frame
-- itself is left alone and still in CHARACTERFRAME_SUBFRAMES, so it keeps being hidden with the
-- others and stays available to whatever gives pets their own window later.
local function removePetTab()
    local tab = _G.CharacterFrameTab2
    if not tab or tab._duiRetired then return end
    tab._duiRetired = true
    tab:Hide()
    tab.Show = tab.Hide
end

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.Inset then return end

    removePetTab()

    pane = CreateFrame("Frame", FRAME_NAME, cf)
    pane:SetAllPoints(cf)
    pane:SetID(TAB_INDEX)
    pane:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL)
    pane:Hide()

    -- Registered with Blizzard's own list so CharacterFrame_ShowSubFrame hides it for us when any
    -- other tab is picked, exactly as it does for the five it shipped with.
    if CHARACTERFRAME_SUBFRAMES then
        CHARACTERFRAME_SUBFRAMES[#CHARACTERFRAME_SUBFRAMES + 1] = FRAME_NAME
    end

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
