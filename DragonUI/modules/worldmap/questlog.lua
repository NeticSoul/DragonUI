-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap
local QP = addon.QuestPOI

-- Retail's quest log over the client's list; only the selection goes back through Blizzard.

local TOP_BAND_H = 29
-- Retail leaves a band over the frame; the list starts below it, not at the panel's own top.
local LIST_TOP = TOP_BAND_H + 3
-- The gutter is the scrollbar's lane, outside the frame: at 20 the arrows sat right on the gold.
local LIST_X, LIST_GUTTER, LIST_BOTTOM = 4, 24, 8
local LIST_TOP_PADDING = 8
local RING_CORNER, RING_OUTSET = 53, 4
-- The frame's gold line ends 3px inside the list; rows clip below it so none is cut against it.
local LIST_CLIP_TOP = 5
local SEARCH_H = 20
-- Centred on the frame below it, gutter excluded: it has to sit squarely over the list.
local SEARCH_TOP, SEARCH_INSET = 6, 8
-- InputBoxTemplate hangs its left edge 5 out and its right flush, so the frame is not the box.
local SEARCH_BLEED = 5
-- The gear rides the scrollbar's own lane, straight above its top stepper.
local COG_SIZE, COG_GAP = 20, 4
-- Cancels ReskinScrollBar's own 7px end inset so the bar runs the frame's full height.
local BAR_INSET = 7
-- How far inside the frame's ends the arrow tips stop, so the bar does not run past it.
local BAR_MARGIN = 3
-- How far inside the frame the parchment stops, so no paper shows past the gold line.
local TOME_INSET = 4
local ROW_X, ROW_GAP = 4, 2
local HEADER_H, HEADER_GAP = 22, 6
local TOGGLE_SIZE = 16
local BADGE_SIZE, TAG_SIZE, TRACK_SIZE = QP.SIZE, 16, 16
local TEXT_INDENT = BADGE_SIZE + 6
local OBJECTIVE_INDENT = TEXT_INDENT + 6

local panel, search, settings, scroll, child
local query = ""
local rowPool, headerPool = {}, {}
local hoveredRow
local requestRepaint
-- Which sections this panel has shut. Ours alone: see toggleHeader.
local shut = {}
local queued

local function CP()
    return addon.CharacterPanel
end

-- ============================================================================
-- ART
-- ============================================================================

-- Retail's questlog-frame ring: four native corners, four stretched edges, an open middle.
local function drawRing(host, target, atlas, corner, outset)
    local file, width, height, left, right, top, bottom = addon.functions.atlas_unpack(atlas)
    local u, v = (right - left) * (corner / width), (bottom - top) * (corner / height)
    local function piece(l, r, t, b)
        local tex = host:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(file)
        tex:SetTexCoord(l, r, t, b)
        return tex
    end
    local tl = piece(left, left + u, top, top + v)
    local tr = piece(right - u, right, top, top + v)
    local bl = piece(left, left + u, bottom - v, bottom)
    local br = piece(right - u, right, bottom - v, bottom)
    for _, tex in ipairs({ tl, tr, bl, br }) do tex:SetSize(corner, corner) end
    tl:SetPoint("TOPLEFT", target, "TOPLEFT", -outset, outset)
    tr:SetPoint("TOPRIGHT", target, "TOPRIGHT", outset, outset)
    bl:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -outset, -outset)
    br:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", outset, -outset)

    local topEdge = piece(left + u, right - u, top, top + v)
    topEdge:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
    topEdge:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
    local bottomEdge = piece(left + u, right - u, bottom - v, bottom)
    bottomEdge:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
    bottomEdge:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    local leftEdge = piece(left, left + u, top + v, bottom - v)
    leftEdge:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
    leftEdge:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT", 0, 0)
    local rightEdge = piece(right - u, right, top + v, bottom - v)
    rightEdge:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, 0)
    rightEdge:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
end

-- ============================================================================
-- MODEL
-- ============================================================================

-- GetQuestLogTitle reports the tag as the client's localized string.
local TAG_ATLAS = {}
for _, pair in ipairs({
    { RAID, "raid" }, { LFG_TYPE_RAID, "raid" }, { LFG_TYPE_DUNGEON, "dungeon" },
    { LFG_TYPE_HEROIC_DUNGEON, "heroic" }, { PVP, "pvp" }, { GROUP, "group" }, { ELITE, "group" },
    { DAILY, "daily" },
}) do
    if pair[1] then TAG_ATLAS[pair[1]] = "questlog-questtypeicon-" .. pair[2] end
end

-- Read-only: Blizzard's map rows are the only place the POI number for a quest is published.
local function mapBadges()
    local badges = {}
    for i = 1, WorldMapFrame.numQuests or 0 do
        local row = _G["WorldMapQuestFrame" .. i]
        if row and row.questLogIndex and row.questLogIndex > 0 then
            badges[row.questLogIndex] = {
                frame = row,
                number = row.poiIcon and row.poiIcon.index,
                completed = row.completed,
            }
        end
    end
    return badges
end

-- Only this call knows where a quest is, and it moves the map: hence one batch, map closed.
local questArea, questFloor, questPending = {}, {}, {}

local function seedPending()
    for index = 1, GetNumQuestLogEntries() do
        local _, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
        if not isHeader and questID and questID > 0 and questArea[questID] == nil then
            questPending[questID] = true
        end
    end
end

-- Headers open for the pass: a collapsed one hides its quests from the log entirely.
local function withHeadersOpen(work)
    local collapsed = {}
    -- Expanding renumbers what follows, so the walk restarts and the restore goes by name.
    local changed = true
    while changed do
        changed = false
        for index = 1, GetNumQuestLogEntries() do
            local title, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)
            if isHeader and isCollapsed then
                collapsed[#collapsed + 1] = title
                ExpandQuestHeader(index)
                changed = true
                break
            end
        end
    end

    work()

    for _, name in ipairs(collapsed) do
        for index = 1, GetNumQuestLogEntries() do
            local title, _, _, _, isHeader = GetQuestLogTitle(index)
            if isHeader and title == name then
                CollapseQuestHeader(index)
                break
            end
        end
    end
end

local resolving

local function resolvePending()
    -- Expanding a header fires QUEST_LOG_UPDATE, which lands right back here.
    if resolving or WorldMapFrame:IsShown() or InCombatLockdown() then return end
    resolving = true
    local moved = false
    withHeadersOpen(function()
        seedPending()
        for questID in pairs(questPending) do
            questPending[questID] = nil
            local area, floor = GetQuestWorldMapAreaID(questID)
            questArea[questID] = (area and area > 0 and area) or false
            questFloor[questID] = (floor and floor > 0) and floor or nil
            moved = true
        end
    end)
    resolving = nil
    if moved then SetMapToCurrentZone() end
end

-- POI data lands after the log does: a 0 at login means "not yet". The cap stops a retry loop.
local POI_RETRY_LIMIT = 5
local poiRetries = 0

local function forgetFailures(reset)
    if reset then
        poiRetries = 0
    elseif poiRetries >= POI_RETRY_LIMIT then
        return
    else
        poiRetries = poiRetries + 1
    end
    for questID, where in pairs(questArea) do
        if not where then questArea[questID] = nil end
    end
end

-- nil is momentary and falls through; false is settled and does not.
local function questAreaOf(questID)
    local known = questID and questArea[questID]
    if known == nil and questID and questID > 0 then questPending[questID] = true end
    return known
end

-- GetCurrentMapAreaID is the WorldMapArea id plus one, and 0 for the world and cosmic views.
local function shownArea()
    return (GetCurrentMapAreaID() or 0) - 1
end

local function matches(title)
    return query == "" or (title and string.find(string.lower(title), query, 1, true) ~= nil)
end

local function objectiveText(index)
    local lines = {}
    for j = 1, GetNumQuestLeaderBoards(index) do
        local text, _, finished = GetQuestLogLeaderBoard(j, index)
        if text and not finished then lines[#lines + 1] = QUEST_DASH .. text end
    end
    local required = GetQuestLogRequiredMoney(index)
    if required and required > GetMoney() then
        lines[#lines + 1] = QUEST_DASH .. GetMoneyString(GetMoney()) .. " / " .. GetMoneyString(required)
    end
    return table.concat(lines, "\n")
end

-- The tags that promise an instance, and so licence the complex lookup below.
local INSTANCE_TAG = {}
for _, value in ipairs({ RAID, LFG_TYPE_RAID, LFG_TYPE_DUNGEON, LFG_TYPE_HEROIC_DUNGEON }) do
    if value then INSTANCE_TAG[value] = true end
end

-- An instance quest has no map area of its own; its log section names the instance.
local byInstance, byComplex

local function indexInstance(name, target)
    if not (target and name and name ~= "") then return end
    byInstance[name] = target
    -- The client names wings ("Blackrock Depths - Prison"); the log shows the instance they are in.
    local base = string.match(name, "^(.-) %- ")
    if base then byInstance[base] = target end
end

local function entranceFor(section, tagged)
    if not byInstance then
        byInstance, byComplex = {}, {}
        local named, byLfg = false, {}
        for zone, list in pairs(WM.Entrances or {}) do
            local area = WM.EntranceZone and WM.EntranceZone[zone]
            for _, entry in ipairs(list) do
                local localized = entry.lfg and GetLFGDungeonInfo(entry.lfg)
                local pin = localized or entry.name
                local target = { area = area, name = pin, pin = pin, raid = entry.raid }
                if area then
                    -- The client's name is localized like the section; the generated one fits enUS.
                    indexInstance(localized, target)
                    indexInstance(entry.header, target)
                    if entry.lfg then byLfg[entry.lfg] = target end
                end
                named = named or localized ~= nil
            end
        end
        -- What the client words differently from the log, read out of its own DBC per locale.
        local locale = GetLocale()
        local headers = WM.EntranceHeader
            and (WM.EntranceHeader[locale] or (locale == "esMX" and WM.EntranceHeader.esES))
        for header, lfgID in pairs(headers or {}) do
            indexInstance(header, byLfg[lfgID])
        end
        -- Every door of the complex lights: the client cannot say which wing a quest is in.
        local function addComplex(source)
            for name, ids in pairs(source or {}) do
                local pins, first = {}, nil
                for _, lfgID in ipairs(ids) do
                    local wing = byLfg[lfgID]
                    if wing then
                        first = first or wing
                        pins[#pins + 1] = wing.pin
                    end
                end
                if first then
                    byComplex[name] = { area = first.area, name = name, pins = pins, raid = first.raid }
                end
            end
        end
        local complexes = WM.EntranceComplex or {}
        addComplex(complexes.enUS)
        addComplex(complexes[locale])
        -- GetLFGDungeonInfo is empty for a moment after login; a half-built index must not stick.
        if not named then byInstance = nil end
    end
    if not (section and byInstance) then return nil end
    -- A complex can name an outdoor area too, so only the server calling it an instance counts.
    return byInstance[section] or (tagged and byComplex[section]) or nil
end

-- No location filter: the client places half a log at best, so one reads as quests gone missing.
local function collect()
    local badges = mapBadges()
    local view = shownArea()
    local details = WM:Config().objectives ~= false
    local flat, pending, section = {}, nil, nil
    for index = 1, GetNumQuestLogEntries() do
        local title, level, tag, _, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(index)
        if isHeader then
            section = title
            local closed = shut[title] or isCollapsed or false
            pending = { kind = "header", index = index, name = title, collapsed = closed,
                clientCollapsed = isCollapsed }
            if closed then
                flat[#flat + 1] = pending
                pending = nil
            end
        elseif shut[section] then
            -- Under a section this panel has shut; the client still lists it, we just do not.
        elseif matches(title) then
            local badge = badges[index]
            local known = questAreaOf(questID)
            local area = type(known) == "number" and known or nil
            if pending then
                flat[#flat + 1] = pending
                pending = nil
            end
            local complete = isComplete == 1 or (badge and badge.completed) or false
            -- The entrance wins over the area: that area is the instance's own map, not the way in.
            local entrance = entranceFor(section, INSTANCE_TAG[tag])
            local target = (entrance and entrance.area) or area
            local travel = (not badge) and target ~= nil and target ~= view or nil
            local style
            if badge then
                style = complete and "complete" or (badge.number and "numeric" or nil)
            elseif complete then
                style = "completeOut"
            elseif travel then
                style = "offMap"
            end
            flat[#flat + 1] = {
                kind = "quest", index = index, name = title, level = level,
                questID = questID, mapRow = badge and badge.frame,
                objectives = details and objectiveText(index) or "",
                -- The server leaves plenty of instance quests untagged; the entrance knows better.
                tag = (isComplete and isComplete < 0 and "questlog-questtypeicon-questfailed")
                    or (isDaily and "questlog-questtypeicon-daily") or (tag and TAG_ATLAS[tag])
                    or (entrance and ("questlog-questtypeicon-" .. (entrance.raid and "raid" or "dungeon"))),
                style = style, number = badge and badge.number, complete = complete,
                travel = travel, entrance = entrance,
            }
        end
    end
    return flat
end

-- ============================================================================
-- ACTIONS
-- ============================================================================

-- Ours, not the client's: collapsing there empties its enumeration and Blizzard hides the POIs.
local function toggleHeader(header)
    if header._clientCollapsed then
        shut[header._name] = nil
        ExpandQuestHeader(header._index)
        return
    end
    shut[header._name] = not shut[header._name] or nil
    requestRepaint()
end

local function setWatched(index, watched)
    if watched then
        if GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
            UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, MAX_WATCHABLE_QUESTS), 1.0, 0.1, 0.1, 1.0)
            return
        end
        AddQuestWatch(index)
    else
        RemoveQuestWatch(index)
    end
    -- No WatchFrame_Update(): it creates poiWatchFrameLines* under our taint, blocking the blob.
end

-- Two shapes at most, the selected quest and the row under the cursor, and they can differ. Kept
-- in one place because three callers used to draw straight onto the canvas and undo each other.
local drawn = {}

local function blobFor(questID)
    if not questID then return end
    for index = 1, #rowPool do
        local row = rowPool[index]
        if row:IsShown() and row._questID == questID then
            if row._mapRow and not row._complete then return questID end
            return
        end
    end
end

local function showBlob(questID)
    if not questID or drawn[questID] then return end
    WorldMapBlobFrame:DrawQuestBlob(questID, true)
    drawn[questID] = true
end

-- No combat guard: what is protected on this frame is Show/Hide and moving it, not drawing on it,
-- which is how the client's own map lights an area mid-fight.
local function applyBlob()
    local focus = blobFor(QP.GetFocus())
    local hover = blobFor(hoveredRow and hoveredRow._questID)
    for questID in pairs(drawn) do
        if questID ~= focus and questID ~= hover then
            WorldMapBlobFrame:DrawQuestBlob(questID, false)
            drawn[questID] = nil
        end
    end
    showBlob(focus)
    showBlob(hover)
end

-- WorldMapFrame_SelectQuestFrame writes WORLDMAP_SETTINGS.selectedQuest*, re-read before it rewrites.
local function selectOnMap(row, flash)
    if not (row and row._mapRow) then return end
    QP.SetFocus(row._questID)
    applyBlob()
    if flash and WM.FlashQuestPOI then WM.FlashQuestPOI(row._questID) end
end

-- Selectable only once the new map has a row for it, so the pick waits for the rebuild.
local pendingSelect

-- Asked at the moment it is wanted; the batch may not have reached this quest yet. No combat guard:
-- every call below is a C API, and the map this runs from is already open.
local function travelTo(row)
    local questID = row and row._questID
    if not questID then return end
    local entrance = row._entrance
    if entrance then
        PlaySound("igMainMenuOptionCheckBoxOn")
        SetMapByID(entrance.area)
        if WM.FlashEntrance then WM.FlashEntrance(entrance.pins or entrance.pin or entrance.name) end
        return
    end
    -- The call moves the map whatever it answers, so a quest it cannot place must not strand you.
    local before = (GetCurrentMapAreaID() or 0) - 1
    local area, floor = GetQuestWorldMapAreaID(questID)
    if area and area > 0 then
        questArea[questID] = area
        questFloor[questID] = (floor and floor > 0) and floor or nil
        pendingSelect = questID
        PlaySound("igMainMenuOptionCheckBoxOn")
        SetMapByID(area)
        -- A multi-floor instance opens on its default floor otherwise, which is not the quest's.
        if questFloor[questID] then SetDungeonMapLevel(questFloor[questID]) end
        return
    end
    questArea[questID] = false
    if before > 0 then SetMapByID(before) else SetMapToCurrentZone() end
end

-- A collapsed header hides its quests from UpdateQuests' sweep, so their shapes never get cleared.
local function clearBlobs()
    for questID in pairs(questArea) do
        WorldMapBlobFrame:DrawQuestBlob(questID, false)
    end
    -- questArea only holds what the batch has resolved, and ours may not be in it yet.
    for questID in pairs(drawn) do
        WorldMapBlobFrame:DrawQuestBlob(questID, false)
        drawn[questID] = nil
    end
end

WM.ClearBlobs = clearBlobs

-- The blob is rasterised where it was drawn and never travels, so moving the canvas re-lays it.
function WM.RefreshBlobs()
    clearBlobs()
    applyBlob()
end

-- Blizzard wiped its last pick and drew this one, so that alone IS the canvas now.
local function reclaimBlob(questFrame)
    for questID in pairs(drawn) do drawn[questID] = nil end
    local picked = questFrame and questFrame.questId
    if picked then drawn[picked] = true end
    applyBlob()
end

-- Ours: Blizzard's handler writes WorldMapQuestScrollFrame.highlightedFrame, and reads it back.
local function hoverRow(row, entering, onBadge)
    local previous = hoveredRow
    hoveredRow = nil
    if previous then
        previous.badge:UnlockHighlight()
        if not previous._focused and previous._color then
            previous.title:SetTextColor(previous._color.r, previous._color.g, previous._color.b)
        end
    end
    if entering and row then
        hoveredRow = row
        -- A grey badge is the only clickable part of its row, so nothing else should light it.
        if onBadge or row._style ~= "offMap" then row.badge:LockHighlight() end
        row.title:SetTextColor(1, 1, 1)
    end
    applyBlob()
end

-- ============================================================================
-- ROWS
-- ============================================================================

local function acquireHeader(index)
    local header = headerPool[index]
    if header then return header end

    header = CreateFrame("Button", nil, child)
    header:SetHeight(HEADER_H)
    header.toggle = CreateFrame("Button", nil, header)
    header.toggle:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
    header.toggle:SetPoint("LEFT", header, "LEFT", 0, 0)
    header.toggle:SetNormalTexture(addon._dir .. "UI\\ui-background-rock")
    header.toggle:SetPushedTexture(addon._dir .. "UI\\ui-background-rock")

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("LEFT", header.toggle, "RIGHT", 6, 0)
    header.text:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    header.text:SetJustifyH("LEFT")

    local hl = header:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(1, 1, 1)
    hl:SetAlpha(0.08)
    hl:SetAllPoints(header)

    local function click(self)
        toggleHeader(self._header or self)
    end
    header.toggle._header = header
    header.toggle:SetScript("OnClick", click)
    header:RegisterForClicks("LeftButtonUp")
    header:SetScript("OnClick", click)
    headerPool[index] = header
    return header
end

local function acquireRow(index)
    local row = rowPool[index]
    if row then return row end

    row = CreateFrame("Button", nil, child)
    row:RegisterForClicks("LeftButtonUp")

    row.glow = row:CreateTexture(nil, "BACKGROUND")
    row.glow:set_atlas("questlog-quest-glow-yellow")
    row.glow:SetPoint("TOPLEFT", row, "TOPLEFT", -6, 0)
    row.glow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 6, 0)
    row.glow:Hide()

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(1, 1, 1)
    hl:SetAlpha(0.08)
    hl:SetAllPoints(row)

    row.badge = QP.Create(row, BADGE_SIZE)
    row.badge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    row.badge:SetFrameLevel(row:GetFrameLevel() + 2)
    row.badge:RegisterForClicks("LeftButtonUp")
    -- Retail's split: the title opens the details, the badge is what takes you to the quest.
    row.badge:SetScript("OnClick", function(self)
        local owner = self:GetParent()
        if owner._mapRow then selectOnMap(owner, true) else travelTo(owner) end
    end)
    row.badge:SetScript("OnEnter", function(self)
        local owner = self:GetParent()
        hoverRow(owner, true, true)
        if owner._travel then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Click to view on Map"], 0.1, 1, 0.1)
            GameTooltip:Show()
        end
    end)
    row.badge:SetScript("OnLeave", function(self)
        hoverRow(self:GetParent(), false, true)
        GameTooltip:Hide()
    end)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_INDENT, -2)
    row.title:SetJustifyH("LEFT")

    row.objectives = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.objectives:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 6, -2)
    row.objectives:SetJustifyH("LEFT")
    row.objectives:SetTextColor(0.8, 0.8, 0.8)

    -- The dungeon/raid tag is the one mark those quests never lack, so it doubles as the way in.
    row.tagButton = CreateFrame("Button", nil, row)
    row.tagButton:SetSize(TAG_SIZE, TAG_SIZE)
    row.tag = row.tagButton:CreateTexture(nil, "OVERLAY")
    row.tag:SetAllPoints(row.tagButton)
    row.tagButton:SetHighlightTexture(addon._dir .. "UI\\ui-background-rock")
    row.tagButton:GetHighlightTexture():SetBlendMode("ADD")
    row.tagButton:GetHighlightTexture():SetAllPoints(row.tagButton)
    row.tagButton:SetScript("OnClick", function() travelTo(row) end)
    row.tagButton:SetScript("OnEnter", function(self)
        if not row._entrance then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(row._entrance.name, 1, 1, 1)
        GameTooltip:AddLine(L["Click to view on Map"], 0.1, 1, 0.1)
        GameTooltip:Show()
    end)
    row.tagButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.track = CreateFrame("CheckButton", nil, row)
    row.track:SetSize(TRACK_SIZE, TRACK_SIZE)
    row.track:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    row.track:SetNormalTexture(addon._dir .. "UI\\ui-background-rock")
    row.track:GetNormalTexture():set_atlas("questlog-icon-ticksquare")
    row.track:SetCheckedTexture(addon._dir .. "UI\\ui-background-rock")
    row.track:GetCheckedTexture():set_atlas("questlog-icon-checkmark-yellow")
    row.track:SetHighlightTexture(addon._dir .. "UI\\ui-background-rock")
    row.track:GetHighlightTexture():set_atlas("questlog-icon-ticksquare")
    row.track:GetHighlightTexture():SetBlendMode("ADD")
    row.track:SetScript("OnClick", function(self)
        setWatched(row._index, self:GetChecked())
    end)
    row.track:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TRACK_QUEST)
        GameTooltip:Show()
    end)
    row.track:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.tagButton:SetPoint("RIGHT", row.track, "LEFT", -2, 0)

    row:SetScript("OnClick", function(self)
        selectOnMap(self)
        if WM.ShowQuestDetail then WM.ShowQuestDetail(self._index) end
    end)
    row:SetScript("OnEnter", function(self) hoverRow(self, true) end)
    row:SetScript("OnLeave", function(self) hoverRow(self, false) end)
    rowPool[index] = row
    return row
end

local function fillRow(row, data, width)
    row._index, row._questID, row._mapRow = data.index, data.questID, data.mapRow
    row._complete, row._travel = data.complete, data.travel
    row._entrance = data.entrance
    row._style = data.style
    row._focused = data.questID ~= nil and data.questID == QP.GetFocus()
    row._color = GetQuestDifficultyColor(data.level or 0)
    -- Without objectives the row is still as tall as the badge, so its one line centres on it.
    local single = data.objectives == ""
    row.title:ClearAllPoints()
    row.track:ClearAllPoints()
    if single then
        row.title:SetPoint("LEFT", row, "LEFT", TEXT_INDENT, 0)
        row.track:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    else
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_INDENT, -2)
        row.track:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    end
    row.title:SetWidth(width - TEXT_INDENT - TRACK_SIZE - TAG_SIZE - 8)
    row.title:SetText(data.name or "")
    row.title:SetTextColor(row._color.r, row._color.g, row._color.b)

    if data.objectives ~= "" then
        row.objectives:SetWidth(width - OBJECTIVE_INDENT - 4)
        row.objectives:SetText(data.objectives)
        row.objectives:Show()
    else
        row.objectives:Hide()
    end

    if data.style then
        QP.SetStyle(row.badge, data.style, data.number, row._focused)
        row.badge:Show()
    else
        row.badge:Hide()
    end
    if data.tag then
        row.tag:set_atlas(data.tag)
        row.tagButton:GetHighlightTexture():set_atlas(data.tag)
        row.tagButton:EnableMouse(data.entrance ~= nil)
        row.tagButton:Show()
    else
        row.tagButton:Hide()
    end
    row.track:SetChecked(IsQuestWatched(data.index))
    if row._focused then
        row.glow:Show()
        row.title:SetTextColor(1, 1, 1)
    else
        row.glow:Hide()
    end

    local height = row.title:GetHeight() + 6
    if data.objectives ~= "" then height = height + row.objectives:GetHeight() + 2 end
    row:SetHeight(math.max(height, BADGE_SIZE + 4))
end

-- ============================================================================
-- LAYOUT
-- ============================================================================

local function repaint()
    if not (panel and panel:IsShown() and child) then return end
    local width = child:GetWidth() - ROW_X * 2
    if width <= 0 then return end

    -- Ours alone, and nothing is picked until the player picks it: seeding it from Blizzard's own
    -- auto-selection lit the area of a quest nobody had chosen.
    if not WorldMapFrame:IsShown() then QP.SetFocus(nil) end
    local wasHovering = hoveredRow and hoveredRow._questID
    hoverRow(nil, false)

    local flat = collect()
    local rows, headers, y = 0, 0, LIST_TOP_PADDING
    for _, data in ipairs(flat) do
        if data.kind == "header" then
            headers = headers + 1
            local header = acquireHeader(headers)
            header._index, header._collapsed = data.index, data.collapsed
            header._name, header._clientCollapsed = data.name, data.clientCollapsed
            header.text:SetText(data.name or "")
            local state = data.collapsed and "closed" or "open"
            header.toggle:GetNormalTexture():set_atlas("campaign_headericon_" .. state)
            header.toggle:GetPushedTexture():set_atlas("campaign_headericon_" .. state .. "pressed")
            header:ClearAllPoints()
            header:SetWidth(width)
            local gap = y > LIST_TOP_PADDING and HEADER_GAP or 0
            header:SetPoint("TOPLEFT", child, "TOPLEFT", ROW_X, -(y + gap))
            header:Show()
            y = y + gap + HEADER_H
        else
            rows = rows + 1
            local row = acquireRow(rows)
            row:ClearAllPoints()
            row:SetWidth(width)
            fillRow(row, data, width)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", ROW_X, -y)
            row:Show()
            y = y + row:GetHeight() + ROW_GAP
        end
    end
    for index = rows + 1, #rowPool do rowPool[index]:Hide() end
    for index = headers + 1, #headerPool do headerPool[index]:Hide() end

    child:SetHeight(math.max(y, scroll:GetHeight()))
    if #flat == 0 and scroll:IsShown() then panel.empty:Show() else panel.empty:Hide() end
    CP().SyncScrollBarVisibility(scroll)

    -- The map we travelled to has finished rebuilding, so the quest now has a row to select.
    if pendingSelect then
        local target = pendingSelect
        pendingSelect = nil
        for index = 1, rows do
            local row = rowPool[index]
            if row._questID == target and row._mapRow then
                selectOnMap(row, true)
                break
            end
        end
    end

    -- The hover follows the quest, not the spot: a rebuild slides a different one under the cursor.
    if wasHovering and scroll:IsMouseOver() then
        for index = 1, rows do
            local row = rowPool[index]
            if row._questID == wasHovering and row:IsMouseOver() then
                hoverRow(row, true, row.badge:IsShown() and row.badge:IsMouseOver())
                break
            end
        end
    end
end

-- Coalesced: anchors have no measurable width until the frame after the last trigger anyway.
function requestRepaint()
    if queued then return end
    queued = true
    addon:After(0, function()
        queued = nil
        repaint()
    end)
end

WM.RefreshQuestLog = requestRepaint

-- Diagnostics only: what the batch has managed to place so far.
function WM.DumpQuestAreas()
    for index = 1, GetNumQuestLogEntries() do
        local title, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
        if not isHeader and questID then
            local known = questArea[questID]
            addon:Print(tostring(known), title)
        end
    end
end

-- ============================================================================
-- PANEL
-- ============================================================================

-- Retail parks a search over the frame; the band the list already leaves for it is where it goes.
local function buildSearch()
    -- Named because InputBoxTemplate builds its border out of $parent-prefixed regions.
    search = CreateFrame("EditBox", "DragonUIWorldMapQuestSearch", panel, "InputBoxTemplate")
    search:SetHeight(SEARCH_H)
    local edge = LIST_X - RING_OUTSET + SEARCH_INSET
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", edge + SEARCH_BLEED, -SEARCH_TOP)
    search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(LIST_GUTTER - RING_OUTSET) - SEARCH_INSET, -SEARCH_TOP)
    search:SetAutoFocus(false)
    search:SetTextInsets(18, 6, 0, 0)

    local glass = search:CreateTexture(nil, "OVERLAY")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", search, "LEFT", 2, -1.5)
    glass:SetTexture(addon._dir .. "Collections\\UI-Searchbox-Icon")

    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", search, "LEFT", 20, 0)
    hint:SetText(L["Search Quest Log"])

    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then hint:Show() else hint:Hide() end
        query = string.lower(text)
        requestRepaint()
    end)
    search:SetScript("OnEditFocusGained", function() hint:Hide() end)
    search:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then hint:Show() end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local cog = CreateFrame("Button", "DragonUIWorldMapQuestSettings", panel)
    cog:SetSize(COG_SIZE, COG_SIZE)
    local bar = _G[scroll:GetName() .. "ScrollBar"]
    if bar then
        cog:SetPoint("BOTTOM", bar, "TOP", 0, COG_GAP)
    else
        cog:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(LIST_GUTTER - RING_OUTSET), -SEARCH_TOP)
    end
    local gear = cog:CreateTexture(nil, "ARTWORK")
    gear:set_atlas("questlog-icon-setting", true)
    gear:SetPoint("CENTER", cog, "CENTER", 0, 0)
    local glow = cog:CreateTexture(nil, "HIGHLIGHT")
    glow:set_atlas("questlog-icon-setting", true)
    glow:SetPoint("CENTER", cog, "CENTER", 0, 0)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.4)
    cog:SetScript("OnClick", function(self)
        addon.Menu.Open(self, {
            { text = L["Panel settings"], isTitle = true },
            {
                text = QUEST_OBJECTIVES,
                checked = function() return WM:Config().objectives ~= false end,
                keepShown = true,
                func = function()
                    WM:Config().objectives = not (WM:Config().objectives ~= false)
                    requestRepaint()
                end,
            },
        })
    end)
    cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["Panel settings"])
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
    settings = cog
end

local function buildPanel()
    panel = CreateFrame("Frame", "DragonUIWorldMapQuestLog", WM.border)
    panel:SetWidth(WM.PANEL_W)
    panel:SetPoint("TOPRIGHT", WM.border, "TOPRIGHT", -WM.INSET_R, -21)
    panel:SetPoint("BOTTOMRIGHT", WM.border, "BOTTOMRIGHT", -WM.INSET_R, WM.INSET_B)
    panel:SetFrameLevel(WM.border:GetFrameLevel() + 2)
    panel:EnableMouse(true)

    -- The framed area. The list clips inside it, so the art can stay where it was tuned.
    local list = CreateFrame("Frame", nil, panel)
    WM.listFrame = list

    -- The detail gives its buttons the stone below and takes the search box's band above.
    function WM.SetListInset(bottom, rise)
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, -(LIST_TOP - (rise or 0)))
        list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -LIST_GUTTER, LIST_BOTTOM + (bottom or 0))
    end
    WM.SetListInset(0)

    scroll = CreateFrame("ScrollFrame", "DragonUIWorldMapQuestList", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -LIST_CLIP_TOP)
    scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    scroll.scrollBarHideable = false
    scroll.hideThumbWhenUnscrollable = true
    -- The bar hangs in the gutter lane, its right edge 7 in from the panel so it clears the frame.
    WM.listBar = {
        top = LIST_TOP - RING_OUTSET - BAR_INSET + BAR_MARGIN,
        x = -7,
        bottom = LIST_BOTTOM - RING_OUTSET - BAR_INSET + BAR_MARGIN,
    }
    CP().ReskinScrollBar(scroll, panel, WM.listBar.top, WM.listBar.x, WM.listBar.bottom, true)

    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WM.PANEL_W - LIST_X - LIST_GUTTER, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(self)
        child:SetWidth(self:GetWidth())
        requestRepaint()
    end)
    -- Stops inside the gold line so no paper shows past it; the scrollbar stays out on the stone.
    local paper = RING_OUTSET - TOME_INSET
    local tome = panel:CreateTexture(nil, "BACKGROUND")
    tome:set_atlas("questlog-main-background")
    tome:SetPoint("TOPLEFT", list, "TOPLEFT", -paper, paper)
    tome:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", paper, -paper)

    -- The frame sits over the list so the rows scroll under its rounded corners.
    local ring = CreateFrame("Frame", nil, panel)
    ring:SetAllPoints(list)
    ring:SetFrameLevel(panel:GetFrameLevel() + 4)
    ring:EnableMouse(false)
    drawRing(ring, list, "questlog-frame", RING_CORNER, RING_OUTSET)
    local filigree = ring:CreateTexture(nil, "OVERLAY")
    filigree:set_atlas("questlog-frame-filigree", true)
    filigree:SetPoint("TOP", list, "TOP", 0, 4)
    local gradient = ring:CreateTexture(nil, "BORDER")
    WM.listGradient = gradient
    gradient:set_atlas("questlog-frame-gradient-bottom")
    gradient:SetHeight(66)
    gradient:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, 0)
    gradient:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("TOP", list, "TOP", 0, -24)
    panel.empty:SetWidth(240)
    panel.empty:SetText(L["No quests on this map."])

    buildSearch()
end

function WM.SetQuestLogShown(shown)
    if not shown then hoverRow(nil, false) end
    if shown then panel:Show() else panel:Hide() end
    if not shown and WM.HideQuestDetail then WM.HideQuestDetail() end
end

function WM.ShowQuestList()
    scroll:Show()
    search:Show()
    if settings then settings:Show() end
    requestRepaint()
end

function WM.HideQuestList()
    hoverRow(nil, false)
    scroll:Hide()
    search:Hide()
    -- Nothing on the detail page for it to act on, and retail drops it there too.
    if settings then settings:Hide() end
    panel.empty:Hide()
end

-- ============================================================================
-- BUILD
-- ============================================================================

function WM.BuildQuestLog()
    buildPanel()
    if WM.BuildQuestDetail then WM.BuildQuestDetail(panel, TOP_BAND_H) end

    panel:SetScript("OnShow", requestRepaint)
    panel:SetScript("OnHide", function()
        hoverRow(nil, false)
        QP.SetFocus(nil)
        addon:After(0, resolvePending)
    end)
    WM.SetQuestLogShown(WM.PanelShown())
    requestRepaint()

    -- Runs between UpdateQuests and its reselect, the one moment the canvas is meant to be blank.
    hooksecurefunc("WorldMapFrame_UpdateQuests", function()
        clearBlobs()
        requestRepaint()
        if WM.RefreshQuestDetail then WM.RefreshQuestDetail() end
    end)
    hooksecurefunc("WorldMapFrame_SelectQuestFrame", function(questFrame)
        reclaimBlob(questFrame)
        requestRepaint()
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("QUEST_WATCH_UPDATE")
    events:RegisterEvent("QUEST_POI_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            forgetFailures(true)
        elseif event == "QUEST_POI_UPDATE" then
            forgetFailures()
        end
        requestRepaint()
        resolvePending()
    end)
    addon:After(8, resolvePending)
end
