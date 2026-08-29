-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

-- One quest in place of the list; the log's cursor is shared, so every read re-selects it first.

local TEXT_INSET = 14
-- The text clips where each band's art turns opaque, so it slides under instead of stopping short.
local UNDER_HEADER, UNDER_DIVIDER = 8, 11
-- And the page itself starts and ends clear of both, so nothing rests against a band.
local BODY_TOP, BODY_BOTTOM = 10, 17
local REWARD_SIZE = 32
local BUTTON_H, BUTTON_GAP = 22, 4
-- Retail keeps the three buttons off the page; the frame gives up this much of its foot for them.
local BUTTON_ROW = 24
-- Both bands keep the height retail cut them at, or their carving comes out squashed.
local HEADER_H, HEADER_RISE = 52, 28
-- The band's art fills its top 44px; centring in the whole 52 would read low.
local BACK_X, BACK_LIFT = 10, 4
local DIVIDER_H, FOOTER_PAD = 56, 8
-- Retail pairs each currency with its own icon and sinks the figure into a field beside it.
local CHIP_H, CHIP_GAP = REWARD_SIZE + 4, 6
-- The rewards column sits wider than the page text, which is what retail gives its currencies.
local FOOTER_INSET = 10
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local XP_ICON = addon._dir .. "WorldMap\\xp_icon"
-- The band's carving sits a little low in its cell, so the word follows it down.
local LABEL_DROP = 2

local detail, body, scroll, footer
local questIndex, questID

local function CP()
    return addon.CharacterPanel
end

local function idAt(index)
    return select(9, GetQuestLogTitle(index))
end

-- ============================================================================
-- REWARDS
-- ============================================================================

local function acquireReward(pool, index)
    local button = pool[index]
    if button then return button end

    button = CreateFrame("Button", nil, footer)
    button:SetHeight(REWARD_SIZE + 4)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(REWARD_SIZE, REWARD_SIZE)
    button.icon:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.ring = button:CreateTexture(nil, "OVERLAY")
    button.ring:SetTexture(addon._dir .. "UI\\ui-quickslot2")
    button.ring:SetTexCoord(12 / 64, 51 / 64, 12 / 64, 51 / 64)
    button.ring:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -2, 2)
    button.ring:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 2, -2)
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -2, 2)
    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.name:SetPoint("LEFT", button.icon, "RIGHT", 5, 0)
    button.name:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    button.name:SetJustifyH("LEFT")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:SetScript("OnEnter", function(self)
        SelectQuestLogEntry(questIndex)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.kind == "spell" then
            GameTooltip:SetQuestLogRewardSpell()
        else
            GameTooltip:SetQuestLogItem(self.kind, self.slot)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pool[index] = button
    return button
end

local function dressReward(button, kind, slot, name, texture, count, quality)
    button.kind, button.slot = kind, slot
    button.icon:SetTexture(texture)
    button.name:SetText(name or "")
    local color = quality and ITEM_QUALITY_COLORS[quality]
    if color then
        button.name:SetTextColor(color.r, color.g, color.b)
    else
        button.name:SetTextColor(1, 1, 1)
    end
    button.count:SetText(count and count > 1 and count or "")
    button:Show()
end

-- An icon and a sunken field: what retail shows experience and money in.
local function acquireChip(key, icon)
    if detail[key] then return detail[key] end

    local chip = CreateFrame("Frame", nil, footer)
    chip:SetHeight(CHIP_H)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetSize(REWARD_SIZE, REWARD_SIZE)
    chip.icon:SetPoint("LEFT", chip, "LEFT", 0, 0)
    chip.icon:SetTexture(icon)
    chip.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    chip.ring = chip:CreateTexture(nil, "OVERLAY")
    chip.ring:SetTexture(addon._dir .. "UI\\ui-quickslot2")
    chip.ring:SetTexCoord(12 / 64, 51 / 64, 12 / 64, 51 / 64)
    chip.ring:SetPoint("TOPLEFT", chip.icon, "TOPLEFT", -2, 2)
    chip.ring:SetPoint("BOTTOMRIGHT", chip.icon, "BOTTOMRIGHT", 2, -2)

    chip.field = CreateFrame("Frame", nil, chip)
    chip.field:SetPoint("LEFT", chip.icon, "RIGHT", 4, 0)
    chip.field:SetPoint("RIGHT", chip, "RIGHT", 0, 0)
    chip.field:SetHeight(CHIP_H - 4)
    chip.field:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    chip.field:SetBackdropColor(0, 0, 0, 0.55)
    chip.field:SetBackdropBorderColor(0.45, 0.36, 0.26, 1)
    chip.text = chip.field:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chip.text:SetPoint("LEFT", chip.field, "LEFT", 7, 0)
    chip.text:SetPoint("RIGHT", chip.field, "RIGHT", -5, 0)
    chip.text:SetJustifyH("LEFT")

    detail[key] = chip
    return chip
end

local function hidePool(pool, from)
    for i = from or 1, #pool do pool[i]:Hide() end
end

-- ============================================================================
-- LAYOUT
-- ============================================================================

-- Regions stack from the top; heights are read back after SetText so wrapped text lays out true.
local function stack(host, region, y, gap)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", host, "TOPLEFT", host == footer and FOOTER_INSET or 0, -(y + gap))
    region:Show()
    return y + gap + region:GetHeight()
end

local function placeRewards(pool, kind, count, getter, y, width)
    for i = 1, count do
        local button = acquireReward(pool, i)
        dressReward(button, kind, i, getter(i))
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", footer, "TOPLEFT", FOOTER_INSET, -y)
        y = y + REWARD_SIZE + 6
    end
    hidePool(pool, count + 1)
    return y
end

-- Side by side when both are owed, full width when only one is.
local function layoutChips(y, width, money)
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
    local chips = {}
    if xp > 0 then
        local chip = acquireChip("xpChip", XP_ICON)
        chip.text:SetText(tostring(xp))
        chips[#chips + 1] = chip
    elseif detail.xpChip then
        detail.xpChip:Hide()
    end
    if money > 0 then
        local chip = acquireChip("moneyChip", COIN_ICON)
        chip.text:SetText(GetCoinTextureString(money))
        chips[#chips + 1] = chip
    elseif detail.moneyChip then
        detail.moneyChip:Hide()
    end
    if #chips == 0 then return y end

    -- Half the row whether there are one or two, or a lone chip stretches the whole way over.
    local span = (width - CHIP_GAP) / 2
    for index, chip in ipairs(chips) do
        chip:ClearAllPoints()
        chip:SetWidth(span)
        chip:SetPoint("TOPLEFT", footer, "TOPLEFT", FOOTER_INSET + (index - 1) * (span + CHIP_GAP), -y)
        chip:Show()
    end
    return y + CHIP_H + 4
end

-- Its own ground under the page, and it never scrolls: the rewards stay in sight.
local function fillFooter()
    local choices, rewards = GetNumQuestLogChoices(), GetNumQuestLogRewards()
    local spellTexture, spellName = GetQuestLogRewardSpell()
    local money = GetQuestLogRewardMoney()
    local width = footer:GetWidth() - FOOTER_INSET * 2

    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
    if choices == 0 and rewards == 0 and not spellTexture and money <= 0 and xp <= 0 then
        detail.choiceHeader:Hide()
        detail.rewardHeader:Hide()
        if detail.xpChip then detail.xpChip:Hide() end
        if detail.moneyChip then detail.moneyChip:Hide() end
        hidePool(detail.choices)
        hidePool(detail.rewards)
        hidePool(detail.spell)
        footer:SetHeight(1)
        footer:Hide()
        return
    end

    footer:Show()
    detail.choiceHeader:SetWidth(width)
    detail.rewardHeader:SetWidth(width)
    local y = DIVIDER_H + FOOTER_PAD

    if choices > 0 then
        detail.choiceHeader:SetText(REWARD_CHOOSE)
        y = stack(footer, detail.choiceHeader, y, 0) + 4
        y = placeRewards(detail.choices, "choice", choices, GetQuestLogChoiceInfo, y, width)
    else
        detail.choiceHeader:Hide()
        hidePool(detail.choices)
    end

    if rewards > 0 or spellTexture or money > 0 or xp > 0 then
        detail.rewardHeader:SetText(REWARD_ITEMS_ONLY)
        y = stack(footer, detail.rewardHeader, y, choices > 0 and 6 or 0) + 4
        y = placeRewards(detail.rewards, "reward", rewards, GetQuestLogRewardInfo, y, width)
        if spellTexture then
            local button = acquireReward(detail.spell, 1)
            dressReward(button, "spell", 1, spellName, spellTexture)
            button:SetWidth(width)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", footer, "TOPLEFT", FOOTER_INSET, -y)
            y = y + REWARD_SIZE + 6
        else
            hidePool(detail.spell)
        end
        y = layoutChips(y, width, money)
    else
        detail.rewardHeader:Hide()
        if detail.xpChip then detail.xpChip:Hide() end
        if detail.moneyChip then detail.moneyChip:Hide() end
        hidePool(detail.rewards)
        hidePool(detail.spell)
    end

    footer:SetHeight(y + FOOTER_PAD)
end

local function fill()
    -- OnSizeChanged may not have run yet the first time the panel is opened.
    local width = scroll:GetWidth() or 0
    if width > 0 and body:GetWidth() ~= width then
        body:SetWidth(width)
        for _, fs in ipairs(detail.texts) do fs:SetWidth(width) end
        for _, line in ipairs(detail.lines) do line:SetWidth(width - 8) end
    end
    SelectQuestLogEntry(questIndex)
    local title = GetQuestLogTitle(questIndex)
    local description, objectivesText = GetQuestLogQuestText()

    detail.title:SetText(title or "")
    local y = stack(body, detail.title, BODY_TOP, 0)

    local numObjectives = GetNumQuestLeaderBoards(questIndex)
    if (objectivesText and objectivesText ~= "") or numObjectives > 0 then
        y = stack(body, detail.objectivesHeader, y, 12)
    else
        detail.objectivesHeader:Hide()
    end
    if objectivesText and objectivesText ~= "" then
        detail.objectives:SetText(objectivesText)
        y = stack(body, detail.objectives, y, 4)
    else
        detail.objectives:Hide()
    end
    for i = 1, numObjectives do
        local line = detail.lines[i]
        if not line then
            line = body:CreateFontString(nil, "OVERLAY", "QuestFont")
            line:SetWidth(body:GetWidth() - 8)
            line:SetJustifyH("LEFT")
            detail.lines[i] = line
        end
        local text, _, finished = GetQuestLogLeaderBoard(i, questIndex)
        line:SetText(QUEST_DASH .. (text or ""))
        if finished then line:SetTextColor(0.35, 0.35, 0.35) else line:SetTextColor(0, 0, 0) end
        y = stack(body, line, y, 2)
    end
    for i = numObjectives + 1, #detail.lines do detail.lines[i]:Hide() end

    if description and description ~= "" then
        y = stack(body, detail.descriptionHeader, y, 12)
        detail.description:SetText(description)
        y = stack(body, detail.description, y, 4)
    else
        detail.descriptionHeader:Hide()
        detail.description:Hide()
    end

    body:SetHeight(y + BODY_BOTTOM)
    local span = WM.listFrame:GetWidth() or 0
    if span > 0 then
        local width = math.floor((span - BUTTON_GAP * 2) / 3)
        detail.track:SetWidth(width)
        detail.abandon:SetWidth(width)
        detail.share:SetWidth(width)
    end
    fillFooter()
    CP().SyncScrollBarVisibility(scroll)
    detail.track:SetText(IsQuestWatched(questIndex) and L["Untrack"] or TRACK_QUEST_ABBREV)
    if GetQuestLogPushable() and GetNumPartyMembers() > 0 then detail.share:Enable() else detail.share:Disable() end
end

-- ============================================================================
-- BUILD
-- ============================================================================

local function actionButton(text, onClick)
    local button = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    button:SetHeight(BUTTON_H)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    addon.SkinRedButton(button)
    return button
end

function WM.BuildQuestDetail(panel)
    local list = WM.listFrame
    detail = CreateFrame("Frame", "DragonUIWorldMapQuestDetail", panel)
    detail:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    -- Two below the frame art: the bands inside sit one up and still under its rounded corners.
    detail:SetFrameLevel(panel:GetFrameLevel() + 2)
    detail:Hide()

    -- The frame reaches up over the search box's band, so the way back sits inside it.
    local header = CreateFrame("Frame", nil, detail)
    header:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:set_atlas("questlog-reward-top-frame")
    header.bg:SetAllPoints(header)

    local back = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    back:SetSize(70, BUTTON_H)
    back:SetPoint("LEFT", header, "LEFT", BACK_X, BACK_LIFT)
    back:SetText(BACK)
    back:SetScript("OnClick", function() WM.HideQuestDetail() end)
    addon.SkinRedButton(back)

    -- Up behind the band: the sheet's top edge is torn, and retail hides it the same way.
    local page = detail:CreateTexture(nil, "BACKGROUND")
    page:set_atlas("questbg-parchment")
    page:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)

    footer = CreateFrame("Frame", nil, detail)
    page:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
    footer:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(1)
    footer.divider = footer:CreateTexture(nil, "ARTWORK")
    footer.divider:set_atlas("questlog-reward-header-top")
    footer.divider:SetHeight(DIVIDER_H)
    footer.divider:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footer.divider:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    -- Below the band, never behind it: its top 11px are clear and would show this as a black strip.
    footer.bg = footer:CreateTexture(nil, "BACKGROUND")
    footer.bg:set_atlas("questlog-reward-tile-vertical")
    footer.bg:SetPoint("TOPLEFT", footer.divider, "BOTTOMLEFT", 0, 0)
    footer.bg:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", 0, 0)
    -- The carving sits in the band's lower two thirds; the word rides with it.
    footer.label = footer:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
    footer.label:SetPoint("CENTER", footer.divider, "CENTER", 0, -LABEL_DROP)
    footer.label:SetTextColor(1, 0.95, 0.85)
    footer.label:SetText(QUEST_REWARDS)

    scroll = CreateFrame("ScrollFrame", "DragonUIWorldMapQuestDetailScroll", detail, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", TEXT_INSET, UNDER_HEADER)
    scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -TEXT_INSET, -UNDER_DIVIDER)
    scroll.scrollBarHideable = false
    scroll.hideThumbWhenUnscrollable = true
    -- The list's own bar, in its lane and at its length: the two views must not shift it.
    CP().ReskinScrollBar(scroll, panel, WM.listBar.top, WM.listBar.x, WM.listBar.bottom, true)

    body = CreateFrame("Frame", nil, scroll)
    body:SetSize(1, 1)
    scroll:SetScrollChild(body)

    detail.texts = {}
    local function text(fontObject)
        local fs = body:CreateFontString(nil, "OVERLAY", fontObject)
        fs:SetJustifyH("LEFT")
        detail.texts[#detail.texts + 1] = fs
        return fs
    end
    -- What QuestInfo dresses the client's own quest book with: all of it black, for parchment.
    detail.title = text("QuestTitleFont")
    detail.objectivesHeader = text("QuestTitleFont")
    detail.objectivesHeader:SetText(QUEST_OBJECTIVES)
    detail.objectives = text("QuestFont")
    detail.lines = {}
    detail.descriptionHeader = text("QuestTitleFont")
    detail.descriptionHeader:SetText(QUEST_DESCRIPTION)
    detail.description = text("QuestFont")

    local function footerText(fontObject)
        local fs = footer:CreateFontString(nil, "OVERLAY", fontObject)
        fs:SetJustifyH("LEFT")
        return fs
    end
    detail.choiceHeader = footerText("GameFontNormal")
    detail.rewardHeader = footerText("GameFontNormal")
    detail.choices, detail.rewards, detail.spell = {}, {}, {}

    scroll:SetScript("OnSizeChanged", function(self)
        local width = self:GetWidth()
        if width <= 0 then return end
        body:SetWidth(width)
        for _, fs in ipairs(detail.texts) do fs:SetWidth(width) end
        for _, line in ipairs(detail.lines) do line:SetWidth(width - 8) end
        if questIndex then fill() end
    end)

    detail.track = actionButton(TRACK_QUEST_ABBREV, function()
        SelectQuestLogEntry(questIndex)
        if IsQuestWatched(questIndex) then RemoveQuestWatch(questIndex) else AddQuestWatch(questIndex) end
        -- No WatchFrame_Update() here; see setWatched in questlog.lua.
        fill()
    end)
    detail.abandon = actionButton(L["Abandon"], function()
        SelectQuestLogEntry(questIndex)
        SetAbandonQuest()
        local items = GetAbandonQuestItems()
        StaticPopup_Show(items and "ABANDON_QUEST_WITH_ITEMS" or "ABANDON_QUEST", GetAbandonQuestName(), items)
    end)
    detail.share = actionButton(L["Share"], function()
        SelectQuestLogEntry(questIndex)
        QuestLogPushQuest()
    end)
    -- On the stone under the frame, spanning it, which SetListInset has shortened to make room.
    detail.track:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -BUTTON_GAP)
    detail.abandon:SetPoint("TOP", list, "BOTTOM", 0, -BUTTON_GAP)
    detail.share:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -BUTTON_GAP)
end

function WM.ShowQuestDetail(index)
    if not index or index <= 0 then return end
    questIndex, questID = index, idAt(index)
    WM.HideQuestList()
    WM.SetListInset(BUTTON_ROW, HEADER_RISE)
    -- The frame's own bottom fade would muddy the rewards ground it now sits on.
    if WM.listGradient then WM.listGradient:Hide() end
    detail:Show()
    fill()
end

function WM.HideQuestDetail()
    questIndex, questID = nil, nil
    detail:Hide()
    if WM.listGradient then WM.listGradient:Show() end
    WM.SetListInset(0)
    WM.ShowQuestList()
end

-- The log renumbers on every change; the quest is found again by ID or the view falls back.
function WM.RefreshQuestDetail()
    if not questIndex then return end
    if idAt(questIndex) ~= questID then
        questIndex = nil
        for index = 1, GetNumQuestLogEntries() do
            if idAt(index) == questID then questIndex = index break end
        end
    end
    if questIndex then fill() else WM.HideQuestDetail() end
end
