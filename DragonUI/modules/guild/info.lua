-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local GU = addon.Guild
local L = GU.L

-- Guild Info pane, laid out like retail's: the message of the day and the guild information on
-- the left, the news feed on the right. News is GuildLevels' feed (levels, bosses, epic loot and
-- crafts, achievements) merged with the guild event log (joins, promotions, departures).

local NEWS_ROW_H = 36
local LEFT_W = 250

local pane, motdText, motdEdit, infoScroll, infoText, infoEdit, infoButton
local newsInset, newsScroll, newsRows, newsEmpty = nil, nil, {}, nil
local news = {}
local editingInfo = false

-- ---------------------------------------------------------------------------------------------
-- Message of the day and guild information
-- ---------------------------------------------------------------------------------------------

local function refreshText()
    local motd = GetGuildRosterMOTD and GetGuildRosterMOTD() or ""
    motdText:SetText(motd ~= "" and motd or ("|cff808080" .. L("No message of the day.") .. "|r"))
    motdEdit:SetShownCompat(CanEditMOTD())

    infoButton:SetShownCompat(CanEditGuildInfo())
    if editingInfo then return end
    local info = GetGuildInfoText() or ""
    infoText:SetText(info ~= "" and info or ("|cff808080" .. L("No guild information.") .. "|r"))
    infoEdit:Hide()
    infoText:Show()
end

local function setEditingInfo(on)
    editingInfo = on
    infoButton:SetText(on and SAVE or EDIT)
    if on then
        infoText:Hide()
        infoEdit:SetText(GetGuildInfoText() or "")
        infoEdit:Show()
        infoEdit:SetFocus()
    else
        infoEdit:ClearFocus()
        infoEdit:Hide()
        infoText:Show()
    end
end

-- ---------------------------------------------------------------------------------------------
-- News
-- ---------------------------------------------------------------------------------------------

local EVENT_ICONS = {
    invite = "INV_Misc_GroupNeedMore", join = "INV_Misc_GroupNeedMore",
    promote = "Spell_ChargePositive", demote = "Spell_ChargeNegative",
    remove = "Ability_Vanish", quit = "Ability_Vanish",
}

local function eventText(kind, player1, player2, rank)
    if kind == "invite" then return format(GUILDEVENT_TYPE_INVITE, player1, player2) end
    if kind == "join" then return format(GUILDEVENT_TYPE_JOIN, player1) end
    if kind == "promote" then return format(GUILDEVENT_TYPE_PROMOTE, player1, player2, rank) end
    if kind == "demote" then return format(GUILDEVENT_TYPE_DEMOTE, player1, player2, rank) end
    if kind == "remove" then return format(GUILDEVENT_TYPE_REMOVE, player1, player2) end
    if kind == "quit" then return format(GUILDEVENT_TYPE_QUIT, player1) end
end

local function itemLink(entry, name, quality)
    local _, link = GetItemInfo(entry)
    if link then return link end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 4]
    local hex = color and color.hex or "|cffa335ee"
    return format("%s|Hitem:%d:0:0:0:0:0:0:0:0|h[%s]|h|r", hex, entry, name ~= "" and name or ("item " .. entry))
end

local function who(name)
    return name and ("|cffffffff" .. name .. "|r") or ""
end

-- One GuildLevels news item as { icon, text, ago, link }.
local function levelsItem(item, now)
    local gl = _G.GuildLevels
    local entry = { ago = now - (item.time or now), sort = item.time or now }
    if item.type == gl.NEWS_GUILD_LEVEL then
        entry.icon = "Interface\\Icons\\Achievement_Reputation_01"
        entry.text = format(L("The guild reached |cff40ff40level %d|r."), item.value)
        if item.text ~= "" then entry.text = entry.text .. " " .. format(L("New perk: |cffffd200%s|r"), item.text) end
    elseif item.type == gl.NEWS_ENCOUNTER then
        entry.icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
        local boss = "|cffffd200" .. (item.text ~= "" and item.text or UNKNOWN) .. "|r"
        if item.text2 ~= "" then
            entry.text = format(L("Guild group defeated %s in %s."), boss, item.text2)
        else
            entry.text = format(L("Guild group defeated %s."), boss)
        end
    elseif item.type == gl.NEWS_ITEM_LOOTED or item.type == gl.NEWS_ITEM_CRAFTED then
        local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(item.value)
        entry.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        entry.link = "item:" .. item.value
        local link = itemLink(item.value, item.text, item.extra)
        entry.text = format(item.type == gl.NEWS_ITEM_CRAFTED and L("%s crafted %s.") or L("%s obtained %s."), who(item.who), link)
    elseif item.type == gl.NEWS_ACHIEVEMENT then
        local _, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(item.value)
        entry.icon = icon or "Interface\\Icons\\Achievement_General"
        local link = GetAchievementLink and GetAchievementLink(item.value)
        entry.text = format(L("%s earned %s."), who(item.who), link or ("|cffffff00[" .. (name or item.text) .. "]|r"))
        entry.achievement = item.value
    else
        return
    end
    return entry
end

local function buildNews()
    wipe(news)
    local gl = GU.Levels()
    if gl then
        local now = time() + (gl.newsClockOffset or 0)
        for _, item in ipairs(gl.news or {}) do
            local entry = levelsItem(item, now)
            if entry then news[#news + 1] = entry end
        end
    end
    for i = 1, (GetNumGuildEvents and GetNumGuildEvents() or 0) do
        local kind, player1, player2, rank, years, months, days, hours = GetGuildEventInfo(i)
        local text = kind and eventText(kind, who(player1), who(player2), rank)
        if text then
            local ago, label = GU.EventAge(years, months, days, hours)
            news[#news + 1] = {
                icon = "Interface\\Icons\\" .. (EVENT_ICONS[kind] or "INV_Misc_Note_01"),
                text = text, ago = ago, agoText = label, activity = true,
            }
        end
    end
    -- The event log only knows hours: one from the last hour counts as half an hour old.
    table.sort(news, function(a, b)
        if a.ago ~= b.ago then return a.ago < b.ago end
        return (a.activity and 1 or 0) < (b.activity and 1 or 0)
    end)
end

local function newsRow(i)
    if newsRows[i] then return newsRows[i] end
    local row = CreateFrame("Button", nil, newsInset)
    row:SetHeight(NEWS_ROW_H)
    row:SetPoint("TOPLEFT", newsInset, "TOPLEFT", 8, -30 - (i - 1) * NEWS_ROW_H)
    row:SetPoint("RIGHT", newsInset, "RIGHT", -24, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:GetHighlightTexture():SetAlpha(0.25)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -3)
    row.time:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 2)
    row.text:SetPoint("RIGHT", row, "RIGHT", -70, 0)
    row.text:SetHeight(30)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("MIDDLE")

    row:SetScript("OnEnter", function(self)
        local entry = self.entry
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if entry.link then
            GameTooltip:SetHyperlink(entry.link)
        elseif entry.achievement and GetAchievementLink then
            GameTooltip:SetHyperlink(GetAchievementLink(entry.achievement))
        else
            GameTooltip:SetText(entry.text, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        local entry = self.entry
        if entry and entry.link and IsModifiedClick("CHATLINK") then
            local _, link = GetItemInfo(entry.link)
            if link then ChatEdit_InsertLink(link) end
        end
    end)
    newsRows[i] = row
    return row
end

function GU.RefreshNews()
    if not (pane and pane:IsShown()) then return end
    buildNews()
    local count = math.max(1, math.floor((newsInset:GetHeight() - 36) / NEWS_ROW_H))
    FauxScrollFrame_Update(newsScroll, #news, count, NEWS_ROW_H)
    local offset = FauxScrollFrame_GetOffset(newsScroll)
    for i = 1, count do
        local row, entry = newsRow(i), news[offset + i]
        row.entry = entry
        if entry then
            row.icon:SetTexture(entry.icon)
            row.text:SetText(entry.text)
            row.time:SetText(entry.agoText or GU.Ago(entry.ago))
            row:Show()
        else
            row:Hide()
        end
    end
    for i = count + 1, #newsRows do newsRows[i]:Hide() end
    newsEmpty:SetShownCompat(#news == 0)
end

-- ---------------------------------------------------------------------------------------------
-- Pane
-- ---------------------------------------------------------------------------------------------

local function build(frame)
    pane = frame

    -- Message of the day
    local motdInset = GU.BuildInset("DragonUIGuildMOTDInset", pane)
    motdInset:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    motdInset:SetSize(LEFT_W, 120)
    local motdHeading = GU.Heading(motdInset, GUILD_MOTD or L("Message of the Day"))
    motdHeading:SetPoint("TOPLEFT", motdInset, "TOPLEFT", 10, -10)
    motdText = motdInset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    motdText:SetPoint("TOPLEFT", motdHeading, "BOTTOMLEFT", 0, -10)
    motdText:SetPoint("BOTTOMRIGHT", motdInset, "BOTTOMRIGHT", -10, 8)
    motdText:SetJustifyH("LEFT")
    motdText:SetJustifyV("TOP")
    motdEdit = GU.Button(motdInset, EDIT, 60)
    motdEdit:SetHeight(18)
    motdEdit:SetPoint("TOPRIGHT", motdInset, "TOPRIGHT", -8, -6)
    motdEdit:SetScript("OnClick", function() StaticPopup_Show("SET_GUILDMOTD") end)

    -- Guild information
    local infoInset = GU.BuildInset("DragonUIGuildInfoInset", pane)
    infoInset:SetPoint("TOPLEFT", motdInset, "BOTTOMLEFT", 0, -10)
    infoInset:SetPoint("BOTTOM", pane, "BOTTOM", 0, 0)
    infoInset:SetWidth(LEFT_W)
    local infoHeading = GU.Heading(infoInset, GUILD_INFORMATION or L("Guild Information"))
    infoHeading:SetPoint("TOPLEFT", infoInset, "TOPLEFT", 10, -10)

    infoScroll = CreateFrame("ScrollFrame", "DragonUIGuildInfoScroll", infoInset, "UIPanelScrollFrameTemplate")
    infoScroll:SetPoint("TOPLEFT", infoHeading, "BOTTOMLEFT", 0, -10)
    infoScroll:SetPoint("BOTTOMRIGHT", infoInset, "BOTTOMRIGHT", -26, 8)
    local child = CreateFrame("Frame", nil, infoScroll)
    child:SetSize(LEFT_W - 46, 400)
    infoScroll:SetScrollChild(child)
    GU.SkinScroll(infoScroll, infoInset)

    infoText = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    infoText:SetWidth(LEFT_W - 46)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")

    infoEdit = CreateFrame("EditBox", nil, child)
    infoEdit:SetMultiLine(true)
    infoEdit:SetMaxLetters(500)
    infoEdit:SetAutoFocus(false)
    infoEdit:SetFontObject(GameFontHighlightSmall)
    infoEdit:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    infoEdit:SetWidth(LEFT_W - 46)
    infoEdit:SetHeight(400)
    infoEdit:SetScript("OnEscapePressed", function() setEditingInfo(false) refreshText() end)
    infoEdit:SetScript("OnTextChanged", function(self)
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, infoScroll) end
    end)
    infoEdit:SetScript("OnCursorChanged", function(self, ...)
        if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, ...) end
    end)
    infoEdit:SetScript("OnUpdate", function(self, elapsed)
        if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, infoScroll) end
    end)
    infoEdit:Hide()

    infoButton = GU.Button(infoInset, EDIT, 60)
    infoButton:SetHeight(18)
    infoButton:SetPoint("TOPRIGHT", infoInset, "TOPRIGHT", -8, -6)
    infoButton:SetScript("OnClick", function()
        if editingInfo then
            SetGuildInfoText(infoEdit:GetText())
            setEditingInfo(false)
            -- The server's copy arrives with the next roster update.
            GuildRoster()
            infoText:SetText(infoEdit:GetText())
        else
            setEditingInfo(true)
        end
    end)

    -- News
    newsInset = GU.BuildInset("DragonUIGuildNewsInset", pane)
    newsInset:SetPoint("TOPLEFT", motdInset, "TOPRIGHT", 10, 0)
    newsInset:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    local newsHeading = GU.Heading(newsInset, L("News"))
    newsHeading:SetPoint("TOPLEFT", newsInset, "TOPLEFT", 10, -10)

    newsScroll = CreateFrame("ScrollFrame", "DragonUIGuildNewsScroll", newsInset, "FauxScrollFrameTemplate")
    newsScroll:SetPoint("TOPLEFT", newsInset, "TOPLEFT", 0, -30)
    newsScroll:SetPoint("BOTTOMRIGHT", newsInset, "BOTTOMRIGHT", -24, 6)
    newsScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, NEWS_ROW_H, GU.RefreshNews)
    end)
    GU.SkinScroll(newsScroll, newsInset)

    newsEmpty = newsInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    newsEmpty:SetPoint("CENTER", newsInset, "CENTER", 0, 0)
    newsEmpty:SetWidth(240)
    newsEmpty:SetText(L("Nothing has happened in the guild yet."))
end

GU.RegisterPane({
    key = "info", label = L("Guild Info"), icon = "INV_Misc_Note_01",
    build = build,
    refresh = function()
        refreshText()
        GU.RefreshNews()
    end,
    shown = function()
        if editingInfo then setEditingInfo(false) end
        QueryGuildEventLog()
        GU.RequestLevels("NEWS")
    end,
})
