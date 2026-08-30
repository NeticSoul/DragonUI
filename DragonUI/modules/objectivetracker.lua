-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Our objectives tracker over the watch APIs; Blizzard's WatchFrame is silenced, never moved.

local OT = {}
addon.ObjectiveTracker = OT

local CONTAINER_W = 230
local HEADER_DROP = 6
-- WatchFrame's own layout numbers, so the rows land where Blizzard's did.
local LINE_H = 16                -- WATCHFRAME_LINEHEIGHT
local MULTI_LINE_H = 29          -- WATCHFRAME_MULTIPLE_LINEHEIGHT, the cap for a wrapped objective
local QUEST_GAP = 10             -- WATCHFRAME_QUEST_OFFSET, the gap between one quest and the next
-- The old module anchored WatchFrameLines to the header's BOTTOMLEFT at -15, which put the first
-- title 37 below the frame top. Blizzard's stock 30 is tighter; this keeps the spacing you had.
local HEADER_GAP = 15
local CRITERIA_PER_ACHIEVEMENT = 5
-- QuestPOI_DisplayButton scales the tracker's own buttons to 0.9 of the template's 32px.
local BADGE_SIZE, ICON_SIZE = addon.QuestPOI.SIZE, 16
-- The title column IS the frame's left edge; the badge hangs outside it, off the title's TOPLEFT.
local BADGE_LIFT = 5
local BUTTON_INSET = -12

-- Measured the way WatchFrame_OnLoad measures it, from a line's own dash at the current font.
local dashWidth = 10

-- WatchFrameLinkButtonTemplate_Highlight recolours the text instead of washing a texture over it.
local TITLE_IDLE = { 0.75, 0.61, 0 }
local LINE_IDLE = { 0.8, 0.8, 0.8 }

local QP = addon.QuestPOI

local frame, content, header, measure
local blockPool = {}
-- `anchor` swallows every drag at FULLSCREEN so the tracker can sit at LOW, under the panels.
local anchor

-- Declared up here because build() and Refresh() close over them.
local savePosition, syncFadeHoverFrames

-- The same CVar WatchFrame_SetWidth reads, so the two layouts cannot drift apart.
local function trackerMetrics()
    local cvar = GetCVar and GetCVar("watchFrameWidth")
    if cvar and cvar ~= "0" then return 306, 294, true end
    return 204, 192, false
end

local function fontSize()
    local config = addon.db and addon.db.profile and addon.db.profile.questtracker
    return (config and config.font_size) or 12
end

local function showHeader()
    local config = addon.db and addon.db.profile and addon.db.profile.questtracker
    return not config or config.show_header ~= false
end

-- WatchFrame forgets its collapse on every reload; ours is our own state and keeps it.
local function setCollapsed(collapsed)
    OT.collapsed = collapsed
    local config = addon.db and addon.db.profile and addon.db.profile.questtracker
    if config then config.collapsed = collapsed or nil end
end

-- ============================================================================
-- MODEL
-- ============================================================================

-- Ours, so the rows never depend on Blizzard's tracker having run its own pass first.
local mapQuests = {}

local function refreshMapQuests()
    for id in pairs(mapQuests) do mapQuests[id] = nil end
    if not (QuestMapUpdateAllQuests and QuestPOIGetQuestIDByVisibleIndex) then return end
    local count = QuestMapUpdateAllQuests()
    for i = 1, count or 0 do
        local questID = QuestPOIGetQuestIDByVisibleIndex(i)
        if questID then mapQuests[questID] = i end
    end
end

-- Blizzard's own rule: a quest on the map being shown gets a numbered pin, one off it only gets a
-- marker when it is ready to hand in.
local function badgeFor(questID, isComplete, counters)
    if questID and mapQuests[questID] then
        if isComplete then return { style = "complete" } end
        counters.numeric = counters.numeric + 1
        return { style = "numeric", number = counters.numeric }
    elseif isComplete then
        return { style = "completeOut" }
    end
end

-- "Lynx Collar: 0/8" reads as "0/8 Lynx Collar" in the tracker; Blizzard flips it the same way.
local function reverseObjective(text)
    local _, _, name, count = string.find(text, "(.*):%s(.*)")
    if name and count then return count .. " " .. name end
    return text
end

local function questObjectives(index)
    local lines = {}
    for i = 1, GetNumQuestLeaderBoards(index) do
        local text, _, finished = GetQuestLogLeaderBoard(i, index)
        -- A finished objective drops off entirely, same as WatchFrame_DisplayTrackedQuests.
        if text and not finished then lines[#lines + 1] = { text = reverseObjective(text) } end
    end
    local required = GetQuestLogRequiredMoney(index)
    if required and required > 0 then
        local money = GetMoney()
        if money < required then
            lines[#lines + 1] = { text = GetMoneyString(money) .. " / " .. GetMoneyString(required) }
        end
    end
    return lines
end

local function collectQuests(blocks, counters)
    for watch = 1, GetNumQuestWatches() do
        local index = GetQuestIndexForWatch(watch)
        if index and index > 0 then
            local title, level, _, _, _, _, isComplete, _, questID = GetQuestLogTitle(index)
            local objectives = questObjectives(index)
            -- Blizzard treats an objectiveless quest as ready to hand in.
            local complete = (isComplete and isComplete > 0) or #objectives == 0
            blocks[#blocks + 1] = {
                kind = "quest", watchIndex = watch, questLogIndex = index, questID = questID,
                title = title, level = level, complete = complete,
                lines = objectives, badge = badgeFor(questID, complete, counters),
            }
        end
    end
end

-- A criterion with a required count above one carries its own "3/8" string; a progress-bar
-- achievement reports a single criterion and nothing else, so its bar text is the whole line.
local function achievementLines(id)
    local lines = {}
    for i = 1, math.min(GetAchievementNumCriteria(id), CRITERIA_PER_ACHIEVEMENT) do
        local text, _, done, quantity, required, _, _, _, quantityString = GetAchievementCriteriaInfo(id, i)
        if text and text ~= "" and not done then
            if required and required > 1 then
                text = text .. ": " .. (quantityString or (tostring(quantity) .. "/" .. tostring(required)))
            end
            lines[#lines + 1] = { text = text }
        elseif (not text or text == "") and quantityString and not done then
            lines[#lines + 1] = { text = quantityString }
        end
    end
    return lines
end

local function collectAchievements(blocks)
    if not GetTrackedAchievements then return end
    for _, id in ipairs({ GetTrackedAchievements() }) do
        if id and id > 0 then
            local _, name, _, completed, _, _, _, _, _, icon = GetAchievementInfo(id)
            if name and not completed then
                blocks[#blocks + 1] = {
                    kind = "achievement", achievementID = id, title = name, icon = icon,
                    lines = achievementLines(id),
                }
            end
        end
    end
end

-- Blizzard ticks its countdowns from WatchFrameLines' OnUpdate (WatchFrame_HandleQuestTimerUpdate);
-- ours would sit frozen between events, so the timer rows get their own second-by-second pass.
local timerBlocks = {}

local function tickTimers()
    if #timerBlocks == 0 or not GetQuestTimers then return end
    local seconds = { GetQuestTimers() }
    for index, block in ipairs(timerBlocks) do
        local line = block.lines and block.lines[1]
        if line and seconds[index] then line.text:SetText(SecondsToTime(seconds[index])) end
    end
end

local function collectTimers(blocks)
    if not GetQuestTimers then return end
    for i, seconds in ipairs({ GetQuestTimers() }) do
        local index = GetQuestIndexForTimer(i)
        if index and index > 0 then
            blocks[#blocks + 1] = {
                kind = "timer", questLogIndex = index, title = GetQuestLogTitle(index),
                lines = { { text = SecondsToTime(seconds) } },
            }
        end
    end
end

local function collect()
    local blocks = {}
    local counters = { numeric = 0 }
    refreshMapQuests()
    collectTimers(blocks)
    collectAchievements(blocks)
    collectQuests(blocks, counters)
    return blocks
end

-- ============================================================================
-- INTERACTION
-- ============================================================================

-- QuestLog_OpenToQuest writes QuestLogFrame.selectedIndex, read on line 1 of Show Map's OnClick.
local function openQuestLogTo(index)
    if not (index and index > 0) then return end
    SelectQuestLogEntry(index)
    -- QuestLog_Update returns early while the frame is hidden, so the open has to do the redraw.
    if QuestLogFrame:IsShown() then QuestLog_Update() else ShowUIPanel(QuestLogFrame) end
end

-- Same entries WatchFrameDropDown_Initialize builds, in the same order.
local function blockMenu(block)
    local entries = { { text = block.title, isTitle = true } }
    if block.kind == "quest" then
        local index = GetQuestIndexForWatch(block.watchIndex)
        if not index then return entries end
        entries[#entries + 1] = { text = OBJECTIVES_VIEW_IN_QUESTLOG, func = function()
            openQuestLogTo(GetQuestIndexForWatch(block.watchIndex))
        end }
        entries[#entries + 1] = { text = OBJECTIVES_STOP_TRACKING, func = function()
            RemoveQuestWatch(GetQuestIndexForWatch(block.watchIndex))
            OT.Refresh()
        end }
        local grouped = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 1
        if GetQuestLogPushable(index) and grouped then
            entries[#entries + 1] = { text = SHARE_QUEST, func = function()
                SelectQuestLogEntry(GetQuestIndexForWatch(block.watchIndex))
                QuestLogPushQuest()
            end }
        end
    elseif block.kind == "achievement" then
        entries[#entries + 1] = { text = OBJECTIVES_STOP_TRACKING, func = function()
            RemoveTrackedAchievement(block.achievementID)
            OT.Refresh()
        end }
    end
    return entries
end

-- Our own popup, never UIDropDownMenu: that system keeps the last menu any addon opened in
-- UIDROPDOWNMENU_OPEN_MENU and the map re-reads it on every update.
local function onBlockClick(block, button)
    if button == "RightButton" then
        if addon.Menu then addon.Menu.Open(block, blockMenu(block)) end
        return
    end
    if block.kind == "quest" then
        local index = GetQuestIndexForWatch(block.watchIndex)
        if not index then return end
        if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
            local link = GetQuestLink(index)
            if link then ChatEdit_InsertLink(link) end
            return
        end
        if IsModifiedClick("QUESTWATCHTOGGLE") then
            RemoveQuestWatch(index)
            OT.Refresh()
            return
        end
        -- The log renumbers when a collapsed header opens, so the index is fetched again after.
        ExpandQuestHeader(GetQuestSortIndex(index))
        openQuestLogTo(GetQuestIndexForWatch(block.watchIndex))
    elseif block.kind == "achievement" then
        if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
            local link = GetAchievementLink(block.achievementID)
            if link then ChatEdit_InsertLink(link) end
            return
        end
        if not AchievementFrame then AchievementFrame_LoadUI() end
        if not AchievementFrame:IsShown() then AchievementFrame_ToggleAchievementFrame() end
        AchievementFrame_SelectAchievement(block.achievementID)
    elseif block.kind == "timer" and block.questLogIndex then
        openQuestLogTo(block.questLogIndex)
    end
end

local function highlight(block, onEnter)
    if onEnter then
        block.title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
        block.title:SetTextColor(TITLE_IDLE[1], TITLE_IDLE[2], TITLE_IDLE[3])
    end
    for _, line in ipairs(block.lines) do
        if line.text:IsShown() then
            local r, g, b
            if onEnter then
                r, g, b = HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b
            else
                r, g, b = LINE_IDLE[1], LINE_IDLE[2], LINE_IDLE[3]
            end
            line.text:SetTextColor(r, g, b)
            line.dash:SetTextColor(r, g, b)
        end
    end
end

-- ============================================================================
-- ROWS
-- ============================================================================

-- QuestPOITemplate is a plain Button, so borrowing Blizzard's own POI costs the rows no protection
-- and keeps the click secure: WatchFrameQuestPOI_OnClick opens the map even in combat.
local POI_KINDS = { QUEST_POI_NUMERIC, QUEST_POI_COMPLETE_IN, QUEST_POI_COMPLETE_OUT }
local borrowed = {}

local function findPOI(questID)
    if not questID then return end
    for _, kind in ipairs(POI_KINDS) do
        local index = 1
        local button = _G["poiWatchFrameLines" .. kind .. "_" .. index]
        while button do
            if button.questId == questID and button:IsShown() then return button end
            index = index + 1
            button = _G["poiWatchFrameLines" .. kind .. "_" .. index]
        end
    end
end

-- Given back hidden: Blizzard's next pass re-parents nothing but does re-anchor and re-show it.
local function releasePOI(button)
    if not (button and borrowed[button]) then return end
    borrowed[button] = nil
    button:SetParent(WatchFrameLines)
    button:ClearAllPoints()
    button:Hide()
end

local function releaseBlockPOI(block)
    if block.poi then
        releasePOI(block.poi)
        block.poi = nil
    end
end

-- Alpha does not stop a click landing, and their rows are laid out under ours at alpha 0.
local muted = {}

local function muteRows(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.IsMouseEnabled and child:IsMouseEnabled() then
            muted[child] = true
            child:EnableMouse(false)
        end
        muteRows(child)
    end
end

-- Only what we actually took, so nothing comes back clickable that Blizzard never made clickable.
local function unmuteRows()
    for child in pairs(muted) do
        child:EnableMouse(true)
        muted[child] = nil
    end
end

-- Blizzard re-anchors every POI to its own hidden lines on each pass of its tracker.
local function afterWatchFrameUpdate()
    if not OT.silenced then return end
    muteRows(WatchFrameLines)
    for button, block in pairs(borrowed) do
        if block.poi == button and button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", block.title, "TOPLEFT", 0, BADGE_LIFT)
        end
    end
    -- Their pass is what builds the buttons, so the first one always lands after our rows exist.
    for _, block in ipairs(blockPool) do
        if block:IsShown() and block.questID and not block.poi and findPOI(block.questID) then
            OT.Refresh()
            return
        end
    end
end

local function styleBadge(block, data)
    local poi = block.questID and findPOI(block.questID)
    if block.poi and block.poi ~= poi then releaseBlockPOI(block) end
    if poi then
        block.poi, borrowed[poi] = poi, block
        poi:SetParent(block)
        -- muteRows took its mouse while it still hung off WatchFrameLines.
        muted[poi] = nil
        poi:EnableMouse(true)
        poi:ClearAllPoints()
        poi:SetPoint("TOPRIGHT", block.title, "TOPLEFT", 0, BADGE_LIFT)
        block.badge:Hide()
        return
    end
    local badge = data.badge
    if not badge then
        block.badge:Hide()
        return
    end
    QP.SetStyle(block.badge, badge.style, badge.number,
        block.questID ~= nil and block.questID == QP.GetFocus())
    block.badge:Show()
end

local function acquireBlock(index)
    local block = blockPool[index]
    if block then return block end

    block = CreateFrame("Button", nil, content)
    block:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    block.title = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    block.title:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
    block.title:SetJustifyH("LEFT")

    -- WatchFrame anchors the POI button here and WatchFrameQuestPOI_OnClick opens the map to it.
    block.badge = QP.Create(block, BADGE_SIZE)
    block.badge:SetPoint("TOPRIGHT", block.title, "TOPLEFT", 0, BADGE_LIFT)
    block.badge:RegisterForClicks("LeftButtonUp")
    block.badge:SetScript("OnClick", function(self)
        local questID = self:GetParent().questID
        local worldMap = addon.WorldMap
        if not (questID and worldMap and worldMap.OpenToQuest) then return end
        local locked = InCombatLockdown()
        -- The map is protected, so a closed one stays closed in combat and the click is dropped.
        if locked and not WorldMapFrame:IsShown() then return end
        -- Focused first: SetMapByID can drive Blizzard's reselect before OpenToQuest returns.
        QP.SetFocus(questID)
        if not locked then worldMap.OpenToQuest(questID) end
        if worldMap.FlashQuestPOI then worldMap.FlashQuestPOI(questID) end
    end)
    -- Hovering the badge lights the quest it belongs to, same as hovering its text.
    block.badge:SetScript("OnEnter", function(self) highlight(self:GetParent(), true) end)
    block.badge:SetScript("OnLeave", function(self) highlight(self:GetParent(), false) end)

    block.icon = block:CreateTexture(nil, "ARTWORK")
    block.icon:SetSize(ICON_SIZE, ICON_SIZE)
    block.icon:SetPoint("RIGHT", block.title, "LEFT", -4, 0)
    block.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    block.lines = {}
    block:SetScript("OnClick", function(self, button) onBlockClick(self, button) end)
    block:SetScript("OnEnter", function(self) highlight(self, true) end)
    block:SetScript("OnLeave", function(self) highlight(self, false) end)
    blockPool[index] = block
    return block
end

local function acquireLine(block, index)
    local line = block.lines[index]
    if line then return line end
    line = {}
    line.dash = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    line.dash:SetJustifyH("LEFT")
    line.text = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    line.text:SetJustifyH("LEFT")
    block.lines[index] = line
    return line
end

local function fillBlock(block, data, width, size)
    block.kind = data.kind
    block.watchIndex, block.questLogIndex = data.watchIndex, data.questLogIndex
    block.questID, block.achievementID = data.questID, data.achievementID
    block.title:SetText(data.title or "")

    if data.icon then
        block.icon:SetTexture(data.icon)
        block.icon:Show()
        block.badge:Hide()
        releaseBlockPOI(block)
    else
        block.icon:Hide()
        styleBadge(block, data)
    end

    -- Only the size changes: keeping each widget's own font path is what the old module did, and
    -- swapping in a narrow face made everything read a size smaller than it claimed.
    local titlePath, _, titleFlags = block.title:GetFont()
    block.title:SetFont(titlePath, size, titleFlags)
    block.title:SetWidth(width)

    -- WatchFrame chains its lines with a +FONTSPACING overlap, so a 16px row advances by 14.
    local spacing = (LINE_H - size) / 2
    local function rowHeight(region)
        return region:GetStringHeight() > LINE_H and MULTI_LINE_H or LINE_H
    end

    local y = rowHeight(block.title) - spacing
    local shown = 0
    for _, entry in ipairs(data.lines) do
        shown = shown + 1
        local line = acquireLine(block, shown)
        local path, _, flags = line.text:GetFont()
        line.dash:SetFont(path, size, flags)
        line.text:SetFont(path, size, flags)
        line.dash:SetText(QUEST_DASH)
        line.dash:ClearAllPoints()
        -- Dash sits on the title's own left edge; only the text is pushed in by its width.
        line.dash:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -y)
        line.text:SetWidth(width - dashWidth)
        line.text:SetText(entry.text)
        line.text:ClearAllPoints()
        line.text:SetPoint("TOPLEFT", block, "TOPLEFT", dashWidth, -y)
        local height = rowHeight(line.text)
        -- Blizzard clamps a wrapped objective to two lines rather than letting it grow.
        if height == MULTI_LINE_H then line.text:SetHeight(MULTI_LINE_H) else line.text:SetHeight(0) end
        line.dash:Show()
        line.text:Show()
        y = y + height - spacing
    end
    for index = shown + 1, #block.lines do
        block.lines[index].dash:Hide()
        block.lines[index].text:Hide()
    end

    block:SetWidth(width)
    block:SetHeight(math.max(y, BADGE_SIZE))
    highlight(block, false)
end

-- ============================================================================
-- HEADER
-- ============================================================================

local function refreshHeaderArt(count, width, wide)
    local btnW, btnH = wide and 18 or 13, wide and 19 or 14

    header.background:set_atlas("QuestTracker-Header", true)
    header.background:SetSize(width, width / 8)
    header.background:SetAlpha(0.9)
    header.background:ClearAllPoints()
    header.background:SetPoint("RIGHT", header.toggle, "RIGHT", 0, 0)
    if count > 0 and showHeader() and not (IsAddOnLoaded and IsAddOnLoaded("QuestHelper")) then
        header.background:Show()
    else
        header.background:Hide()
    end

    local path, _, flags = header.text:GetFont()
    header.text:SetFont(path, wide and 14 or 12, flags)
    header.text:SetText(OBJECTIVES_TRACKER_LABEL .. " (" .. count .. ")")

    header.toggle:SetSize(btnW, btnH)
    local normal = OT.collapsed and "QuestTracker-Expand" or "QuestTracker-Collapse"
    local pushed = OT.collapsed and "QuestTracker-Expand-Pressed" or "QuestTracker-Collapse-Pressed"
    local function skin(tex, atlas, blend)
        if not (tex and addon.functions and addon.functions.atlas_unpack) then return end
        local file, _, _, left, right, top, bottom = addon.functions.atlas_unpack(atlas)
        if not file then return end
        tex:SetTexture(file)
        tex:SetTexCoord(left, right, top, bottom)
        tex:SetAllPoints(header.toggle)
        if blend then tex:SetBlendMode(blend) end
    end
    skin(header.toggle:GetNormalTexture(), normal)
    skin(header.toggle:GetPushedTexture(), pushed)
    skin(header.toggle:GetHighlightTexture(), "QuestTracker-Red-Highlight", "ADD")
end

-- ============================================================================
-- LAYOUT
-- ============================================================================

function OT.Refresh()
    if not (frame and content and OT.enabled) then return end
    local blocks = collect()
    local width, lineWidth, wide = trackerMetrics()
    local size = fontSize()

    -- Nothing tracked means no tracker at all, header included -- WatchFrame hides its own header
    -- the same way once totalObjectives drops to zero.
    if #blocks == 0 and not OT.editing then
        for _, block in ipairs(blockPool) do block:Hide() end
        frame:Hide()
        return
    end
    frame:Show()

    -- DASH_WIDTH the way WatchFrame_OnLoad takes it: from a dash rendered at the current font.
    local dashPath, _, dashFlags = measure:GetFont()
    measure:SetFont(dashPath, size, dashFlags)
    measure:SetText(QUEST_DASH)
    dashWidth = measure:GetStringWidth()

    refreshHeaderArt(#blocks, width, wide)
    local y = HEADER_DROP + header:GetHeight() + HEADER_GAP

    local shown = 0
    for index = #timerBlocks, 1, -1 do timerBlocks[index] = nil end
    if not OT.collapsed then
        for _, data in ipairs(blocks) do
            shown = shown + 1
            local block = acquireBlock(shown)
            fillBlock(block, data, lineWidth, size)
            block:ClearAllPoints()
            block:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            block:Show()
            if data.kind == "timer" then timerBlocks[#timerBlocks + 1] = block end
            y = y + block:GetHeight() + QUEST_GAP
        end
    end
    for index = shown + 1, #blockPool do
        blockPool[index]:Hide()
        releaseBlockPOI(blockPool[index])
    end

    -- The frame itself has to follow the CVar too: leaving it at the narrow width while the header
    -- art and the line budget grew is what pushed the title off to one side in wide mode.
    content:SetSize(width, math.max(y, 1))
    local height = math.max(y, header:GetHeight() + HEADER_DROP)
    frame:SetSize(width, height)
    -- The anchor is the drag surface, so it has to cover the tracker.
    anchor:SetSize(width, height)
    syncFadeHoverFrames()
end

-- Selecting a quest on the map lights its badge here too; only the badge restyles.
QP.RegisterFocusListener(function(questID)
    for _, block in ipairs(blockPool) do
        if block.badge:IsShown() then
            QP.SetSelected(block.badge, block.questID ~= nil and block.questID == questID)
        end
    end
end)

-- ============================================================================
-- BUILD
-- ============================================================================

local function build()
    if frame then return end

    -- The anchor: empty, above everything, mouse off until the editor turns it on. Nothing of the
    -- tracker lives on it, so in editor mode there is no child button left to steal a drag.
    anchor = CreateFrame("Frame", "DragonUI_QuestTrackerFrame", UIParent)
    anchor:SetSize(CONTAINER_W, 32)
    anchor:SetFrameStrata("FULLSCREEN")
    anchor:SetFrameLevel(100)
    anchor:EnableMouse(false)
    anchor:SetMovable(false)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self)
        self:StartMoving()
        if addon.selectedEditorFrame ~= self and addon.SelectEditorFrame then
            addon.SelectEditorFrame(self)
        end
        if addon.ClearSelectionTint then addon.ClearSelectionTint(self) end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if addon.ApplySelectionTint then addon.ApplySelectionTint(self) end
        savePosition()
    end)
    anchor:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and addon.SelectEditorFrame then addon.SelectEditorFrame(self) end
    end)

    if addon.AddNineslice then
        addon.AddNineslice(anchor)
        addon.SetNinesliceState(anchor, false)
        addon.HideNineslice(anchor)
        anchor.editorTexture = anchor.NineSlice and anchor.NineSlice.Center
    end
    anchor.editorText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    anchor.editorText:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    anchor.editorText:SetText(addon.L["Quest Tracker"])
    anchor.editorText:Hide()

    -- The tracker proper, at WatchFrame's own strata so the addon's panels draw over it.
    frame = CreateFrame("Frame", "DragonUIObjectiveTracker", anchor)
    frame:SetSize(CONTAINER_W, 32)
    frame:SetFrameStrata("LOW")
    frame:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
    frame:Hide()

    header = CreateFrame("Frame", nil, frame)
    header:SetHeight(16)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_DROP)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -HEADER_DROP)

    header.background = frame:CreateTexture(nil, "BACKGROUND")

    -- Lined up with the quest titles, not with the badges hanging left of them.
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    header.text:SetTextColor(1, 0.82, 0)

    header.toggle = CreateFrame("Button", nil, header)
    header.toggle:SetPoint("TOPRIGHT", header, "TOPRIGHT", BUTTON_INSET, 1)
    local rock = addon._dir .. "UI\\ui-background-rock"
    header.toggle:SetNormalTexture(rock)
    header.toggle:SetPushedTexture(rock)
    header.toggle:SetHighlightTexture(rock)
    header.toggle:SetScript("OnClick", function()
        setCollapsed(not OT.collapsed)
        OT.Refresh()
    end)

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    content:SetSize(CONTAINER_W, 1)

    measure = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    measure:Hide()

    local sinceTick = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceTick = sinceTick + elapsed
        if sinceTick < 1 then return end
        sinceTick = 0
        tickTimers()
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("QUEST_WATCH_UPDATE")
    events:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_MONEY")
    -- Both of these WatchFrame registers too: a loading screen rebuilds the rows, and a resolution
    -- change moves the anchor. PLAYER_LOGIN alone misses every zone-in after the first.
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    -- Badge numbers follow whichever map is set; never SetMapToCurrentZone from here, that would
    -- drive WorldMapFrame_UpdateMap from our own execution and block the blob frame in combat.
    events:RegisterEvent("WORLD_MAP_UPDATE")
    events:RegisterEvent("QUEST_POI_UPDATE")
    events:SetScript("OnEvent", OT.Refresh)

    if WatchFrame_Update then hooksecurefunc("WatchFrame_Update", afterWatchFrameUpdate) end

    -- The borrowed POI carries Blizzard's OnClick, so the focus and the pulse hang off the call it
    -- ends in. Catches their quest log's Show Map button and their own tracker for free.
    if WorldMap_OpenToQuest then
        hooksecurefunc("WorldMap_OpenToQuest", function(questID)
            QP.SetFocus(questID)
            local worldMap = addon.WorldMap
            if worldMap and worldMap.FlashQuestPOI then worldMap.FlashQuestPOI(questID) end
        end)
    end

    -- The options panel calls this straight through when the "wider quest tracker" box is flipped.
    if WatchFrame_SetWidth then
        hooksecurefunc("WatchFrame_SetWidth", function() OT.Refresh() end)
    end

    -- Tracking from the quest log or the achievement UI fires nothing we can listen for on this
    -- client, so the calls themselves are the signal.
    for _, name in ipairs({ "AddQuestWatch", "RemoveQuestWatch",
                            "AddTrackedAchievement", "RemoveTrackedAchievement" }) do
        if _G[name] then hooksecurefunc(name, function() OT.Refresh() end) end
    end
end

-- Invisible, not mute: WatchFrame_Update has to keep running from Blizzard's own events or the POI
-- buttons the rows borrow are never built, and calling it ourselves would build them tainted.
local function silenceBlizzardTracker()
    if not WatchFrame or OT.silenced then return end
    OT.silenced = true
    WatchFrame:SetAlpha(0)
    WatchFrame:EnableMouse(false)
end

-- Turning the module off has to hand the player back a working tracker, POI buttons included.
local function restoreBlizzardTracker()
    if not WatchFrame or not OT.silenced then return end
    OT.silenced = nil
    for _, block in ipairs(blockPool) do releaseBlockPOI(block) end
    unmuteRows()
    WatchFrame:SetAlpha(1)
    WatchFrame:EnableMouse(true)
end

-- The old module's own maths, kept so a position saved by either lands in the same place: measured
-- off the edges rather than GetPoint, which reads back scale-skewed, and rounded.
savePosition = function()
    local config = addon.db and addon.db.profile and addon.db.profile.questtracker
    if not (config and anchor and anchor:GetRight()) then return end
    local x = math.floor(anchor:GetRight() - UIParent:GetRight() + 0.5)
    local y = math.floor(anchor:GetTop() - UIParent:GetTop() + 0.5)
    config.anchor, config.x, config.y = "TOPRIGHT", x, y
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    -- Only legal while the frame is movable, and leaving the editor clears that before this runs.
    if anchor:IsMovable() then anchor:SetUserPlaced(false) end
end

function OT.Place()
    if not anchor then return end
    local x, y, point = -210, -255, "TOPRIGHT"
    local config = addon.db and addon.db.profile and addon.db.profile.questtracker
    if config then x, y, point = config.x or x, config.y or y, config.anchor or point end
    anchor:ClearAllPoints()
    anchor:SetPoint(point, UIParent, point, x, y)
end

-- The old module needed a hit-rect proxy because WatchFrame was padded to 600px; ours is exactly
-- the content, so the frame itself is the hover target.
local function registerFade()
    if not (addon.VisibilityFade and frame) or OT.faded then return end
    OT.faded = true
    addon.VisibilityFade.Register("questtracker", frame, {
        dbTable = function()
            if not addon:IsModuleEnabled("questtracker") then return nil end
            return addon.db and addon.db.profile and addon.db.profile.questtracker
        end,
        hoverFrames = { frame },
        enableMouse = false,
        clickThrough = true,
        mouseSafeInCombat = true,
    })
end

-- Rows and badges are buttons sitting on the frame, so they steal its OnEnter unless the engine
-- knows about them too. Re-fed after every paint because the pool grows.
syncFadeHoverFrames = function()
    if not (addon.VisibilityFade and addon.VisibilityFade.AddHoverFrames) then return end
    local found = {}
    for _, block in ipairs(blockPool) do
        found[#found + 1] = block
        if block.badge then found[#found + 1] = block.badge end
        if block.poi then found[#found + 1] = block.poi end
    end
    if header then found[#found + 1] = header.toggle end
    if #found > 0 then addon.VisibilityFade.AddHoverFrames("questtracker", found) end
end

function OT.Enable()
    build()
    silenceBlizzardTracker()
    OT.enabled = true
    local config = addon.db and addon.db.profile and addon.db.profile.questtracker
    OT.collapsed = config and config.collapsed or nil
    OT.Place()
    OT.Refresh()
    registerFade()
    if addon.VisibilityFade then addon.VisibilityFade.Update("questtracker") end
end

function OT.Disable()
    OT.enabled = nil
    if frame then frame:Hide() end
    if addon.VisibilityFade and addon.VisibilityFade.Reset then
        addon.VisibilityFade.Reset("questtracker", 1)
    end
    restoreBlizzardTracker()
end

OT.Preview, OT.HidePreview = OT.Enable, OT.Disable

-- ============================================================================
-- MODULE
-- ============================================================================

local TrackerModule = { initialized = false, applied = false }
addon.ObjectiveTrackerModule = TrackerModule
-- The options panel and the module registry both reach for this name; the old module owned it.
addon.QuestTrackerModule = TrackerModule

-- What the visibility toggles in the options panel call. Without it their callback was a no-op and
-- the fade engine only picked the change up on the next hover or reload.
function TrackerModule:SyncHoverVisibility()
    if addon.VisibilityFade then addon.VisibilityFade.Update("questtracker") end
end

-- Registered under the id the options panel, the module list and the position presets already use.
if addon.RegisterModule then
    addon:RegisterModule("questtracker", TrackerModule,
        addon.L["Quest Tracker"],
        addon.L["Quest tracker positioning and styling"],
        { lifecyclePrefix = "QuestTracker", loadOnce = true })
end

-- core/api.lua maps the questtracker module to this name.
function addon.RefreshQuestTracker()
    if addon:IsModuleEnabled("questtracker") then
        TrackerModule.applied = true
        OT.Enable()
    else
        TrackerModule.applied = false
        OT.Disable()
    end
end

local function registerEditor()
    if not (addon.RegisterEditableFrame and frame) then return end
    addon:RegisterEditableFrame({
        name = "questtracker",
        frame = anchor,
        configPath = nil, -- saved by the anchor's OnDragStop
        -- Held visible while positioning even with nothing tracked, or there is nothing to grab.
        showTest = function()
            OT.editing = true
            anchor:SetMovable(true)
            anchor:EnableMouse(true)
            -- The fade engine may have it hidden; positioning something invisible is no good.
            if addon.VisibilityFade and addon.VisibilityFade.Reset then
                addon.VisibilityFade.Reset("questtracker", 1)
            end
            OT.Refresh()
        end,
        hideTest = function()
            OT.editing = nil
            anchor:SetMovable(false)
            anchor:EnableMouse(false)
            OT.Refresh()
            if addon.VisibilityFade then addon.VisibilityFade.Update("questtracker") end
        end,
        onShow = function() anchor:SetClampedToScreen(true) end,
        onHide = function()
            anchor:SetClampedToScreen(false)
            savePosition()
        end,
        module = TrackerModule,
    })
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    build()
    registerEditor()
    TrackerModule.initialized = true
    addon.RefreshQuestTracker()
end)
