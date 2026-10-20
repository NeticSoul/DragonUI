-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local GU = addon.Guild
local L = GU.L

-- Roster pane: retail's roster columns (sortable), offline members on request, and the member
-- detail panel beside the window for notes, rank and removal. Notes and removal go through the
-- stock popups, which read GetGuildRosterSelection and GuildFrame.selectedName.

local ROW_H = 20
local HEADER_H = 22
local CLASS_ICONS = "Interface\\WorldStateFrame\\Icons-Classes"

-- Widths with and without the Guild XP column; Note takes what XP leaves.
local COLUMNS = {
    { key = "name", label = NAME, width = 128, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", width = 34, justify = "CENTER" },
    { key = "zone", label = ZONE, width = 112, justify = "LEFT" },
    { key = "rank", label = RANK, width = 88, justify = "LEFT" },
    { key = "note", label = L("Note"), width = 96, justify = "LEFT" },
    { key = "xp", label = L("Guild XP"), width = 64, justify = "RIGHT", levels = true },
}

local pane, list, scroll, rows, headers = nil, nil, nil, {}, {}
local showOffline, countText, addButton, controlButton
local detail
GU.selectedName = nil

local function hasLevels()
    return GU.Levels() ~= nil
end

local function columnWidth(column)
    if column.key == "note" and not hasLevels() then return column.width + 64 end
    return column.width
end

-- ---------------------------------------------------------------------------------------------
-- Column headers: retail draws no header art on this client, so a dark strip with a gold rule,
-- a faint wash on hover and the stock sort arrow tinted gold.
-- ---------------------------------------------------------------------------------------------

local function buildHeader(column, x)
    local header = CreateFrame("Button", nil, list)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT", list, "TOPLEFT", x, -4)
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetTexture(0, 0, 0, 0.45)
    local rule = header:CreateTexture(nil, "BORDER")
    rule:SetTexture(1, 0.82, 0, 0.5)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -1, 0)
    local hover = header:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(header)
    hover:SetTexture(1, 1, 1, 0.06)

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT", header, "LEFT", 6, 0)
    header.text:SetPoint("RIGHT", header, "RIGHT", -14, 0)
    header.text:SetJustifyH(column.justify == "RIGHT" and "RIGHT" or "LEFT")
    header.text:SetText(column.label)

    header.arrow = header:CreateTexture(nil, "OVERLAY")
    header.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    header.arrow:SetSize(9, 8)
    header.arrow:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    header.arrow:SetVertexColor(1, 0.82, 0)
    header.arrow:Hide()

    header:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        GU.SortBy(column.key)
    end)
    header.column = column
    headers[#headers + 1] = header
end

local function layoutHeaders()
    local x = 6
    for _, header in ipairs(headers) do
        local column = header.column
        local shown = not column.levels or hasLevels()
        header:SetShownCompat(shown)
        if shown then
            local width = columnWidth(column)
            header:SetWidth(width - 1)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", list, "TOPLEFT", x, -4)
            x = x + width
        end
        local sorted = GU.sortKey == column.key
        header.arrow:SetShownCompat(sorted)
        if sorted then
            -- The sheet's arrow points down; ascending flips it.
            if GU.sortAscending then
                header.arrow:SetTexCoord(0, 0.5625, 1, 0)
            else
                header.arrow:SetTexCoord(0, 0.5625, 0, 1)
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------------------------

local function cell(row, justify)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetJustifyH(justify)
    text:SetHeight(ROW_H)
    return text
end

local function buildRow(i)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -(HEADER_H + 6) - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", list, "RIGHT", -20, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.stripe:SetTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)

    row.selected = row:CreateTexture(nil, "BORDER")
    row.selected:SetAllPoints(row)
    row.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.selected:SetBlendMode("ADD")
    row.selected:SetVertexColor(1, 0.82, 0, 0.5)
    row.selected:Hide()

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:GetHighlightTexture():SetAlpha(0.35)

    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(14, 14)
    row.classIcon:SetTexture(CLASS_ICONS)

    row.cells = {}
    for _, column in ipairs(COLUMNS) do
        row.cells[column.key] = cell(row, column.justify)
    end

    row:SetScript("OnClick", function(self, button)
        local member = self.member
        if not member then return end
        if button == "RightButton" then
            GU.ShowMemberMenu(member)
            return
        end
        if GU.selectedName == member.name and detail and detail:IsShown() then
            GU.SelectMember(nil)
        else
            GU.SelectMember(member.name)
        end
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    row:SetScript("OnDoubleClick", function(self)
        if self.member and self.member.online and ChatFrame_SendTell then ChatFrame_SendTell(self.member.name) end
    end)
    row:SetScript("OnEnter", function(self)
        local member = self.member
        if not member then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(member.name, GU.ClassColor(member.classFile))
        GameTooltip:AddLine(format(L("Level %d %s"), member.level, member.class or ""), 1, 1, 1)
        GameTooltip:AddLine(member.rank or "", 1, 0.82, 0)
        if member.online then
            GameTooltip:AddLine(member.zone or "", 0.8, 0.8, 0.8)
        else
            local last = GU.LastOnline(member.index)
            if last then GameTooltip:AddLine(format(L("Last online: %s"), last), 0.6, 0.6, 0.6) end
        end
        if member.note and member.note ~= "" then GameTooltip:AddLine(member.note, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = row
    return row
end

local function layoutRow(row)
    local x = 0
    for _, column in ipairs(COLUMNS) do
        local text = row.cells[column.key]
        local shown = not column.levels or hasLevels()
        text:SetShownCompat(shown)
        if shown then
            local width = columnWidth(column)
            local left = x + 6
            if column.key == "name" then
                row.classIcon:ClearAllPoints()
                row.classIcon:SetPoint("LEFT", row, "LEFT", x + 2, 0)
                left = x + 20
            end
            text:ClearAllPoints()
            text:SetPoint("LEFT", row, "LEFT", left, 0)
            text:SetWidth(width - (left - x) - 6)
            x = x + width
        end
    end
end

local function fillRow(row, member)
    row.member = member
    if not member then
        row:Hide()
        return
    end
    row:Show()
    layoutRow(row)

    local coords = member.classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[member.classFile]
    if coords then
        row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        row.classIcon:SetTexCoord(unpack(coords))
        row.classIcon:Show()
    else
        row.classIcon:Hide()
    end

    local r, g, b = GU.ClassColor(member.classFile)
    local dim = member.online and 1 or 0.5
    local cells = row.cells
    cells.name:SetText(member.name .. (member.status and member.status ~= "" and (" |cff808080" .. member.status .. "|r") or ""))
    cells.name:SetTextColor(r * dim, g * dim, b * dim)
    cells.level:SetText(member.level)
    cells.zone:SetText(member.online and (member.zone or "") or (GU.LastOnline(member.index) or ""))
    cells.rank:SetText(member.rank or "")
    cells.note:SetText(member.note or "")
    cells.xp:SetText(member.weekXP > 0 and GU.Number(member.weekXP) or "|cff808080-|r")
    for key, text in pairs(cells) do
        if key ~= "name" then
            if member.online then text:SetTextColor(1, 1, 1) else text:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    row.classIcon:SetDesaturated(not member.online)
    row.selected:SetShownCompat(member.name == GU.selectedName)
end

local function visibleRows()
    return math.max(1, math.floor((list:GetHeight() - HEADER_H - 12) / ROW_H))
end

function GU.RefreshRoster()
    if not (pane and pane:IsShown()) then return end
    layoutHeaders()

    local members = GU.VisibleRoster()
    local count = visibleRows()
    FauxScrollFrame_Update(scroll, #members, count, ROW_H)
    local offset = FauxScrollFrame_GetOffset(scroll)
    for i = 1, count do
        fillRow(rows[i] or buildRow(i), members[offset + i])
    end
    for i = count + 1, #rows do rows[i]:Hide() end

    countText:SetText(format(L("%d Members  |cff808080·|r  |cff40ff40%d Online|r"), GU.numMembers or 0, GU.numOnline or 0))
    showOffline:SetChecked(GetGuildRosterShowOffline())
    if CanGuildInvite() then addButton:Enable() else addButton:Disable() end
    controlButton:SetShownCompat(IsGuildLeader())

    if GU.selectedName and not GU.FindMember(GU.selectedName) then GU.SelectMember(nil) end
    if GU.RefreshDetail then GU.RefreshDetail() end
end

-- ---------------------------------------------------------------------------------------------
-- Member detail, beside the window like retail's
-- ---------------------------------------------------------------------------------------------

local function noteBox(parent, label, anchor)
    local heading = GU.Heading(parent, label)
    heading:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    local box = CreateFrame("Button", nil, parent)
    box:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    box:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    box:SetHeight(36)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(box)
    bg:SetTexture(0, 0, 0, 0.35)
    local hl = box:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(box)
    hl:SetTexture(1, 1, 1, 0.06)
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.text:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -5)
    box.text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 5)
    box.text:SetJustifyH("LEFT")
    box.text:SetJustifyV("TOP")
    box.heading = heading
    return box
end

local function buildDetail()
    detail = CreateFrame("Frame", "DragonUIGuildMemberDetail", GU.frame)
    detail:SetSize(250, 372)
    detail:SetPoint("TOPLEFT", GU.frame, "TOPRIGHT", GU.FLYOUT_X, -26)
    detail:EnableMouse(true)
    detail:SetFrameLevel(GU.frame:GetFrameLevel() + 5)
    local layout = DragonUI_NineSlice and DragonUI_NineSlice.GetLayout("NoPortraitFrameTemplate")
    if layout then DragonUI_NineSlice.ApplyLayout(detail, layout) end
    local bg = detail:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetTexture(GU.DIR .. "UI\\ui-background-rock", "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetPoint("TOPLEFT", detail, "TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -2, 2)
    detail:Hide()

    local close = CreateFrame("Button", nil, detail, "UIPanelCloseButton")
    addon.SeatCloseButton(close, detail)
    if addon.CharacterPanel and addon.CharacterPanel.ModernizeCloseButton then
        addon.CharacterPanel.ModernizeCloseButton(close, detail)
    end
    close:SetScript("OnClick", function() GU.SelectMember(nil) end)

    detail.name = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detail.name:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -30)
    detail.name:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.name:SetJustifyH("LEFT")
    detail.info = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.info:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
    detail.where = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detail.where:SetPoint("TOPLEFT", detail.info, "BOTTOMLEFT", 0, -3)
    detail.where:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.where:SetJustifyH("LEFT")

    -- Rank with demote / promote arrows either side, as retail has them.
    local rankHeading = GU.Heading(detail, RANK)
    rankHeading:SetPoint("TOPLEFT", detail.where, "BOTTOMLEFT", 0, -14)
    detail.rank = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detail.rank:SetPoint("TOPLEFT", rankHeading, "BOTTOMLEFT", 22, -8)
    local function arrow(direction, x)
        local b = CreateFrame("Button", nil, detail)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", detail.rank, x < 0 and "LEFT" or "RIGHT", x, 0)
        local up = direction == "up"
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. (up and "Next" or "Prev") .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. (up and "Next" or "Prev") .. "Page-Down")
        b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. (up and "Next" or "Prev") .. "Page-Disabled")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(up and L("Promote") or L("Demote"))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", function()
            if not GU.selectedName then return end
            if up then GuildPromote(GU.selectedName) else GuildDemote(GU.selectedName) end
        end)
        return b
    end
    detail.demote = arrow("down", -22)
    detail.promote = arrow("up", 4)

    detail.note = noteBox(detail, L("Public Note"), detail.rank)
    detail.note.heading:ClearAllPoints()
    detail.note.heading:SetPoint("TOPLEFT", rankHeading, "BOTTOMLEFT", 0, -36)
    detail.note:SetScript("OnClick", function()
        if CanEditPublicNote() and GU.ReselectMember() then StaticPopup_Show("SET_GUILDPLAYERNOTE") end
    end)
    detail.officer = noteBox(detail, L("Officer Note"), detail.note)
    detail.officer:SetScript("OnClick", function()
        if CanEditOfficerNote() and GU.ReselectMember() then StaticPopup_Show("SET_GUILDOFFICERNOTE") end
    end)

    detail.xpHeading = GU.Heading(detail, L("Guild XP"))
    detail.xpHeading:SetPoint("TOPLEFT", detail.officer, "BOTTOMLEFT", 0, -14)
    detail.xp = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.xp:SetPoint("TOPLEFT", detail.xpHeading, "BOTTOMLEFT", 0, -8)
    detail.xp:SetJustifyH("LEFT")

    detail.whisper = GU.Button(detail, WHISPER, 108)
    detail.whisper:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 38)
    detail.whisper:SetScript("OnClick", function()
        if GU.selectedName and ChatFrame_SendTell then ChatFrame_SendTell(GU.selectedName) end
    end)
    detail.invite = GU.Button(detail, INVITE, 108)
    detail.invite:SetPoint("LEFT", detail.whisper, "RIGHT", 6, 0)
    detail.invite:SetScript("OnClick", function()
        if GU.selectedName then InviteUnit(GU.selectedName) end
    end)
    detail.remove = GU.Button(detail, L("Remove from Guild"), 222)
    detail.remove:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 12)
    detail.remove:SetScript("OnClick", function()
        if not GU.selectedName then return end
        -- The stock popup names and removes GuildFrame.selectedName.
        if GuildFrame then GuildFrame.selectedName = GU.selectedName end
        StaticPopup_Show("REMOVE_GUILDMEMBER", GU.selectedName)
    end)
end

function GU.RefreshDetail()
    if not detail then return end
    local member = GU.selectedName and GU.FindMember(GU.selectedName)
    if not member or not GU.IsShown() or GU.activePane ~= "roster" then
        detail:Hide()
        return
    end
    detail:Show()

    detail.name:SetText(member.name)
    detail.name:SetTextColor(GU.ClassColor(member.classFile))
    detail.info:SetText(format(L("Level %d %s"), member.level, member.class or ""))
    if member.online then
        detail.where:SetText(member.zone or "")
    else
        detail.where:SetText(format(L("Last online: %s"), GU.LastOnline(member.index) or UNKNOWN))
    end
    detail.rank:SetText(member.rank or "")

    -- Promote and demote are only offered where the server would allow them.
    local myRank = select(3, GetGuildInfo("player")) or 0
    local canPromote = CanGuildPromote() and member.rankIndex > myRank + 1
    local canDemote = CanGuildDemote() and member.rankIndex > myRank and member.rankIndex < GuildControlGetNumRanks() - 1
    if canPromote then detail.promote:Enable() else detail.promote:Disable() end
    if canDemote then detail.demote:Enable() else detail.demote:Disable() end

    local note = member.note ~= "" and member.note or (CanEditPublicNote() and ("|cff808080" .. L("Click to add a note") .. "|r") or "")
    detail.note.text:SetText(note or "")
    local viewOfficer = CanViewOfficerNote()
    detail.officer:SetShownCompat(viewOfficer)
    detail.officer.heading:SetShownCompat(viewOfficer)
    detail.officer.heading.rule:SetShownCompat(viewOfficer)
    if viewOfficer then
        local text = member.officerNote ~= "" and member.officerNote or (CanEditOfficerNote() and ("|cff808080" .. L("Click to add a note") .. "|r") or "")
        detail.officer.text:SetText(text or "")
    end

    local levels = hasLevels()
    detail.xpHeading:SetShownCompat(levels)
    detail.xpHeading.rule:SetShownCompat(levels)
    detail.xp:SetShownCompat(levels)
    detail.xpHeading:ClearAllPoints()
    detail.xpHeading:SetPoint("TOPLEFT", viewOfficer and detail.officer or detail.note, "BOTTOMLEFT", 0, -14)
    if levels then
        detail.xp:SetText(format(L("This week: |cffffffff%s|r\nIn all: |cffffffff%s|r"), GU.Number(member.weekXP), GU.Number(member.totalXP)))
    end

    local me = member.name == UnitName("player")
    if member.online and not me then detail.whisper:Enable() detail.invite:Enable() else detail.whisper:Disable() detail.invite:Disable() end
    detail.remove:SetShownCompat(CanGuildRemove() and not me and member.rankIndex > myRank)
end

-- The stock note popups edit GetGuildRosterSelection(), an index that moves whenever the roster
-- is rebuilt, offline members are shown or hidden, or the Social window opens (it clears it). So
-- the index is looked up again by name right before a popup.
function GU.ReselectMember()
    GU.BuildRoster()
    local member = GU.selectedName and GU.FindMember(GU.selectedName)
    SetGuildRosterSelection(member and member.index or 0)
    return member ~= nil
end

local menuFrame
local function menuItem(text, func, disabled)
    return { text = text, func = func, notCheckable = true, disabled = disabled }
end

-- Our own menu rather than the Social window's: built from addon code, that one's Target entry
-- would be a blocked action.
function GU.ShowMemberMenu(member)
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "DragonUIGuildMemberMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local me = member.name == UnitName("player")
    local myRank = select(3, GetGuildInfo("player")) or 0
    local name = member.name
    local menu = {
        { text = name, isTitle = true, notCheckable = true },
        menuItem(WHISPER, function() ChatFrame_SendTell(name) end, me or not member.online),
        menuItem(INVITE, function() InviteUnit(name) end, me or not member.online),
    }
    if CanGuildPromote() and member.rankIndex > myRank + 1 then
        menu[#menu + 1] = menuItem(L("Promote"), function() GuildPromote(name) end)
    end
    if CanGuildDemote() and member.rankIndex > myRank and member.rankIndex < GuildControlGetNumRanks() - 1 then
        menu[#menu + 1] = menuItem(L("Demote"), function() GuildDemote(name) end)
    end
    if CanGuildRemove() and not me and member.rankIndex > myRank then
        menu[#menu + 1] = menuItem(L("Remove from Guild"), function()
            if GuildFrame then GuildFrame.selectedName = name end
            StaticPopup_Show("REMOVE_GUILDMEMBER", name)
        end)
    end
    menu[#menu + 1] = menuItem(CANCEL, function() end)
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

function GU.SelectMember(name)
    GU.selectedName = name
    local member = name and GU.FindMember(name)
    -- The stock note popups read the roster selection.
    SetGuildRosterSelection(member and member.index or 0)
    if not detail and name then buildDetail() end
    GU.RefreshRoster()
end

-- ---------------------------------------------------------------------------------------------
-- Pane
-- ---------------------------------------------------------------------------------------------

-- The stock popup's show and hide widen and narrow the Social window in UIPanelWindows; run from
-- here that would taint the panel table and block panels in combat. These do the rest of what
-- they do, the window sizing left out.
local function adoptControlPopup()
    local popup = _G.GuildControlPopupFrame
    if not popup or popup._duiAdopted then return end
    popup._duiAdopted = true
    popup:SetScript("OnShow", function()
        if FriendsFrame then FriendsFrame.guildControlShow = 1 end
        if GuildControlPopupAcceptButton then GuildControlPopupAcceptButton:Disable() end
        GuildControlPopupframe_Update()
    end)
    popup:SetScript("OnHide", function(self)
        if FriendsFrame then FriendsFrame.guildControlShow = 0 end
        self.goldChanged = nil
        self:UnregisterEvent("GUILD_ROSTER_UPDATE")
    end)
end

local function build(frame)
    pane = frame
    adoptControlPopup()
    list = GU.BuildInset("DragonUIGuildRosterInset", pane)
    list:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    list:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, GU.BOTTOM_H + 6)

    for _, column in ipairs(COLUMNS) do buildHeader(column, 0) end

    scroll = CreateFrame("ScrollFrame", "DragonUIGuildRosterScroll", list, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(HEADER_H + 6))
    scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -24, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, GU.RefreshRoster)
    end)
    GU.SkinScroll(scroll, list)

    showOffline = CreateFrame("CheckButton", "DragonUIGuildShowOffline", pane, "UICheckButtonTemplate")
    showOffline:SetSize(24, 24)
    showOffline:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 1)
    _G[showOffline:GetName() .. "Text"]:SetText(L("Show Offline"))
    showOffline:SetScript("OnClick", function(self)
        SetGuildRosterShowOffline(self:GetChecked() and true or false)
        -- The client re-indexes its roster at once; rebuild before any row is clicked.
        GU.Refresh()
        GuildRoster()
    end)

    countText = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", showOffline, "RIGHT", 90, 0)

    controlButton = GU.Button(pane, GUILDCONTROL or L("Guild Control"), 110)
    controlButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 2)
    controlButton:SetScript("OnClick", function()
        local popup = _G.GuildControlPopupFrame
        if not popup then return end
        if popup:IsShown() then popup:Hide() return end
        -- Stock initialises it from the guild tab's roster updates, which never run now.
        if GuildControlPopupFrame_Initialize then GuildControlPopupFrame_Initialize() end
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", GU.frame, "TOPRIGHT", GU.FLYOUT_X, -6)
        popup:SetFrameStrata("DIALOG")
        popup:Show()
    end)

    addButton = GU.Button(pane, ADDMEMBER or L("Add Member"), 110)
    addButton:SetPoint("RIGHT", controlButton, "LEFT", -6, 0)
    addButton:SetScript("OnClick", function() StaticPopup_Show("ADD_GUILDMEMBER") end)
end

local function shown()
    GuildRoster()
end

GU.OnHidePanes = function()
    if detail then detail:Hide() end
    if _G.GuildControlPopupFrame then _G.GuildControlPopupFrame:Hide() end
    GU.selectedName = nil
    SetGuildRosterSelection(0)
end

GU.RegisterPane({
    key = "roster", label = L("Roster"), icon = "INV_Misc_GroupNeedMore",
    build = build, refresh = function() GU.RefreshRoster() end, shown = shown,
})
