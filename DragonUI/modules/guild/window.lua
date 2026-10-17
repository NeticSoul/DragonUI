-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local GU = addon.Guild
local L = GU.L

-- The window shell, after retail's Guild & Communities frame (minus its portrait): the guild's
-- card on the left, the active pane on the right, and the panes' tabs standing on the right edge.
-- The guild's level and XP bar run along the top. roster.lua, info.lua and benefits.lua fill it.

local FRAME_NAME = "DragonUIGuildFrame"
local FRAME_W, FRAME_H = 800, 520

local SIDE_PAD = 14
local LEFT_W = 212
local INSET_GAP = 12
local TITLE_H = 24
local TOP_H = 40
local BOTTOM_H = 26

-- The character panel's band geometry, so the rock and streak strip line up with it.
local STREAK_Y, STREAK_H = 21, 43
local ROCK = GU.DIR .. "UI\\ui-background-rock"
local MARBLE = GU.DIR .. "UI\\ui-background-marble"
local SIDETAB = GU.DIR .. "UI\\sidetab"
local TABARD_ICON = "Interface\\Icons\\INV_Shirt_GuildTabard_01"

local REFRESH_ROSTER_EVERY = 20
-- Panels beside the window start past the side tabs, whose plates reach 61px out.
GU.FLYOUT_X = 64

local frame, title
local panes, paneOrder, tabs = {}, {}, {}
GU.activePane = nil

local function CP()
    return addon.CharacterPanel
end

-- SetAtlasTexture raises on a name the atlas table doesn't have; a missing piece of art should
-- only cost that piece.
local function atlas(texture, name)
    return addon:SafeSetAtlas(texture, name)
end

-- ---------------------------------------------------------------------------------------------
-- Panes
-- ---------------------------------------------------------------------------------------------

-- A pane: key, label, icon, build(pane) once, refresh(pane) on every update, and shown(pane)
-- each time it is selected.
function GU.RegisterPane(info)
    panes[info.key] = info
    paneOrder[#paneOrder + 1] = info
end

-- ---------------------------------------------------------------------------------------------
-- Chrome
-- ---------------------------------------------------------------------------------------------

local function buildChrome()
    -- No portrait: the window's title already names the guild.
    local layout = DragonUI_NineSlice and DragonUI_NineSlice.GetLayout("NoPortraitFrameTemplate")
    if layout then DragonUI_NineSlice.ApplyLayout(frame, layout) end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -STREAK_Y)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    local streaks = frame:CreateTexture(nil, "BORDER")
    atlas(streaks, "_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetHeight(STREAK_H)
    streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -STREAK_Y)
    streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -STREAK_Y)

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -5)

    local close = CreateFrame("Button", FRAME_NAME .. "CloseButton", frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    if CP() and CP().ModernizeCloseButton then CP().ModernizeCloseButton(close, frame, 1, 0) end
end

function GU.BuildInset(name, parent)
    local inset = CreateFrame("Frame", name, parent or frame)
    inset:SetFrameLevel((parent or frame):GetFrameLevel() + 2)
    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(MARBLE, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints(inset)
    if CP() and CP().DrawPaneBorder then CP().DrawPaneBorder(inset, inset) end
    return inset
end

-- A section heading: gold text over a thin gold rule, the way retail heads the info panes.
function GU.Heading(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetJustifyH("LEFT")
    label:SetText(text)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(1, 0.82, 0, 0.35)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    rule:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    label.rule = rule
    return label
end

function GU.Button(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, 22)
    button:SetText(text)
    if addon.SkinRedButton then addon.SkinRedButton(button) end
    return button
end

-- The scroll bar of a UIPanelScrollFrameTemplate or FauxScrollFrameTemplate, retail-thin.
function GU.SkinScroll(scroll, host)
    if CP() and CP().ReskinScrollBar then CP().ReskinScrollBar(scroll, host, 0, -2, 0, true) end
end

-- ---------------------------------------------------------------------------------------------
-- Top band: guild level and XP
-- ---------------------------------------------------------------------------------------------

local band = {}

local function buildTopBand()
    local top = CreateFrame("Frame", FRAME_NAME .. "TopBand", frame)
    top:SetFrameLevel(frame:GetFrameLevel() + 3)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_PAD, -(TITLE_H + 4))
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SIDE_PAD, -(TITLE_H + 4))
    top:SetHeight(TOP_H)
    band.frame = top

    band.level = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    band.level:SetPoint("LEFT", top, "LEFT", 6, 0)

    -- The main bar's experience bar art (mainbars.lua): its background and border atlas around
    -- the stock fill, tinted guild green.
    local bar = CreateFrame("StatusBar", nil, top)
    bar:SetPoint("LEFT", top, "LEFT", 170, -1)
    bar:SetPoint("RIGHT", top, "RIGHT", -170, -1)
    bar:SetHeight(10)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.25, 0.85, 0.35)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 0)
    back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, 0)
    if not atlas(back, "ExperienceBar-Background") then back:SetTexture(0, 0, 0, 0.6) end
    local border = bar:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -6)
    atlas(border, "ExperienceBar-Border")
    band.bar = bar

    local text = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    text:SetPoint("CENTER", bar, "CENTER", 0, 1)
    band.barText = text

    band.right = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    band.right:SetPoint("RIGHT", top, "RIGHT", -6, 0)
    band.right:SetJustifyH("RIGHT")

    -- Without guild levels the band is the guild's head count.
    band.plain = top:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    band.plain:SetPoint("LEFT", top, "LEFT", 6, 0)

    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        local gl = GU.Levels()
        if not gl then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(format(L("Guild Level %d"), gl.level), 1, 1, 1)
        if gl.level < gl.MAX_LEVEL then
            GameTooltip:AddLine(format(L("%s / %s guild XP to level %d"), GU.Number(gl.xp), GU.Number(gl.needed), gl.level + 1), 1, 0.82, 0)
        end
        if (gl.cap or 0) > 0 then
            GameTooltip:AddLine(format(L("Today: %s / %s"), GU.Number(gl.today), GU.Number(gl.cap)), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(format(L("Total guild XP: %s"), GU.Number(gl.total)), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("Guild XP comes from members' quests and from dungeon and raid bosses killed in a guild group."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)
end

local function refreshTopBand()
    local gl = GU.Levels()
    local levels = gl ~= nil
    band.level:SetShownCompat(levels)
    band.bar:SetShownCompat(levels)
    band.right:SetShownCompat(levels)
    band.plain:SetShownCompat(not levels)

    if not levels then
        band.plain:SetText(format(L("%d Members  |cff808080·|r  %d Online"), GU.numMembers or 0, GU.numOnline or 0))
        return
    end

    band.level:SetText(format(L("Guild Level %d"), gl.level))
    if gl.level >= gl.MAX_LEVEL then
        band.bar:SetMinMaxValues(0, 1)
        band.bar:SetValue(1)
        band.barText:SetText(L("Max Level"))
    else
        band.bar:SetMinMaxValues(0, math.max(1, gl.needed))
        band.bar:SetValue(gl.xp)
        band.barText:SetText(format("%s / %s", GU.Number(gl.xp), GU.Number(gl.needed)))
    end
    if (gl.cap or 0) > 0 then
        band.right:SetText(format(L("Today: %s / %s"), GU.Number(gl.today), GU.Number(gl.cap)))
    else
        band.right:SetText(format(L("%d Online"), GU.numOnline or 0))
    end
end

-- ---------------------------------------------------------------------------------------------
-- Left: the guild card
-- ---------------------------------------------------------------------------------------------

local card = {}

local function cardLine(parent, anchor, gap)
    local line = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 6))
    line:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    line:SetJustifyH("LEFT")
    return line
end

local function buildCard(inset)
    card.inset = inset

    local emblem = inset:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(64, 64)
    emblem:SetPoint("TOP", inset, "TOP", 0, -16)
    emblem:SetTexture(TABARD_ICON)
    emblem:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.emblem = emblem
    local ring = inset:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("TOPLEFT", emblem, "TOPLEFT", -4, 4)
    ring:SetPoint("BOTTOMRIGHT", emblem, "BOTTOMRIGHT", 4, -4)
    ring:SetTexture(GU.DIR .. "Collections\\IconFrameGold")

    card.name = inset:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.name:SetPoint("TOP", emblem, "BOTTOM", 0, -10)
    card.name:SetWidth(LEFT_W - 20)

    card.levelText = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.levelText:SetPoint("TOP", card.name, "BOTTOM", 0, -4)

    card.rank = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.rank:SetPoint("TOP", card.levelText, "BOTTOM", 0, -4)

    local stats = GU.Heading(inset, L("Guild"))
    stats:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -166)
    card.members = cardLine(inset, stats, 10)
    card.online = cardLine(inset, card.members)

    local mine = GU.Heading(inset, L("Your Contribution"))
    mine:SetPoint("TOPLEFT", card.online, "BOTTOMLEFT", 0, -16)
    card.mineHeading = mine
    card.week = cardLine(inset, mine, 10)
    card.total = cardLine(inset, card.week)
    card.cash = cardLine(inset, card.total)

    local nextHeading = GU.Heading(inset, L("Next Perk"))
    nextHeading:SetPoint("TOPLEFT", card.cash, "BOTTOMLEFT", 0, -16)
    card.nextHeading = nextHeading
    card.nextIcon = inset:CreateTexture(nil, "ARTWORK")
    card.nextIcon:SetSize(28, 28)
    card.nextIcon:SetPoint("TOPLEFT", nextHeading, "BOTTOMLEFT", 0, -10)
    card.nextName = inset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.nextName:SetPoint("TOPLEFT", card.nextIcon, "TOPRIGHT", 6, -1)
    card.nextName:SetPoint("RIGHT", inset, "RIGHT", -10, 0)
    card.nextName:SetJustifyH("LEFT")
    card.nextLevel = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.nextLevel:SetPoint("TOPLEFT", card.nextName, "BOTTOMLEFT", 0, -2)
end

local function refreshCard()
    local guildName, rankName = GetGuildInfo("player")
    card.name:SetText(guildName or "")
    card.rank:SetText(rankName or "")
    card.members:SetText(format(L("Members: |cffffffff%d|r"), GU.numMembers or 0))
    card.online:SetText(format(L("Online: |cff40ff40%d|r"), GU.numOnline or 0))

    local gl = GU.Levels()
    local levels = gl ~= nil
    card.levelText:SetShownCompat(levels)
    for _, region in ipairs({ card.mineHeading, card.mineHeading.rule, card.week, card.total, card.cash }) do
        region:SetShownCompat(levels)
    end
    local nextPerk = levels and gl.NextPerk and gl.NextPerk()
    for _, region in ipairs({ card.nextHeading, card.nextHeading.rule, card.nextIcon, card.nextName, card.nextLevel }) do
        region:SetShownCompat(nextPerk ~= nil)
    end
    if not levels then return end

    card.levelText:SetText(format(L("Level %d Guild"), gl.level))
    card.week:SetText(format(L("This week: |cffffffff%s|r guild XP"), GU.Number(gl.myWeek)))
    card.total:SetText(format(L("In all: |cffffffff%s|r guild XP"), GU.Number(gl.myTotal)))
    card.cash:SetText(format(L("Cash Flow this week: %s"), gl.Money and gl.Money(gl.myCashWeek) or GU.Number(gl.myCashWeek)))
    if nextPerk then
        card.nextIcon:SetTexture("Interface\\Icons\\" .. ((gl.ICONS and gl.ICONS[nextPerk.level]) or "INV_Misc_QuestionMark"))
        card.nextName:SetText(nextPerk.name)
        card.nextLevel:SetText(format(L("Guild level %d"), nextPerk.level))
    end
end

-- ---------------------------------------------------------------------------------------------
-- Side tabs
-- ---------------------------------------------------------------------------------------------

-- Retail's spellbook side tab art, the tab's icon inside it.
local function buildSideTab(index, info)
    local tab = CreateFrame("CheckButton", FRAME_NAME .. "SideTab" .. index, frame)
    tab:SetSize(32, 32)
    local plate = tab:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture(SIDETAB)
    plate:SetSize(64, 64)
    plate:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    tab:SetNormalTexture("Interface\\Icons\\" .. info.icon)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    tab:GetHighlightTexture():SetBlendMode("ADD")
    tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    tab:GetCheckedTexture():SetBlendMode("ADD")
    if index == 1 then
        tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -48)
    else
        tab:SetPoint("TOP", tabs[index - 1], "BOTTOM", 0, -22)
    end
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(info.label)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    tab:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        GU.SelectPane(info.key)
    end)
    tab.key = info.key
    tabs[index] = tab
end

-- ---------------------------------------------------------------------------------------------
-- Build, show, refresh
-- ---------------------------------------------------------------------------------------------

local function build()
    if frame then return frame end

    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    GU.frame = frame

    buildChrome()
    buildTopBand()

    local top = -(TITLE_H + TOP_H + 8)
    local left = GU.BuildInset(FRAME_NAME .. "LeftInset")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_PAD, top)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDE_PAD, 10)
    left:SetWidth(LEFT_W)
    buildCard(left)

    local right = CreateFrame("Frame", FRAME_NAME .. "Right", frame)
    right:SetFrameLevel(frame:GetFrameLevel() + 2)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", INSET_GAP, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SIDE_PAD, 10)
    GU.Right = right
    -- Panes leave this much room under them for their own buttons.
    GU.BOTTOM_H = BOTTOM_H

    -- Not in a guild: retail's empty state.
    local empty = right:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    empty:SetPoint("CENTER", right, "CENTER", 0, 20)
    empty:SetText(L("You are not in a guild."))
    GU.emptyText = empty

    for index, info in ipairs(paneOrder) do
        local pane = CreateFrame("Frame", FRAME_NAME .. "Pane" .. info.key, right)
        pane:SetAllPoints(right)
        pane:Hide()
        info.frame = pane
        if info.build then info.build(pane) end
        buildSideTab(index, info)
    end

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= REFRESH_ROSTER_EVERY then
            elapsed = 0
            GuildRoster()
        end
    end)

    frame:SetScript("OnShow", function()
        PlaySound("igCharacterInfoOpen")
        elapsed = 0
        GuildRoster()
        QueryGuildEventLog()
        GU.RequestLevels()
        GU.SelectPane(GU.activePane or (paneOrder[1] and paneOrder[1].key))
        GU.Refresh()
        -- The lists have no measurable height until the next layout pass.
        addon:After(0, GU.Refresh)
        if UpdateMicroButtons then UpdateMicroButtons() end
    end)
    frame:SetScript("OnHide", function()
        PlaySound("igCharacterInfoClose")
        if GU.OnHidePanes then GU.OnHidePanes() end
        if UpdateMicroButtons then UpdateMicroButtons() end
    end)

    tinsert(UISpecialFrames, FRAME_NAME)
    return frame
end

function GU.SelectPane(key)
    if not frame or not panes[key] then return end
    GU.activePane = key
    for _, info in ipairs(paneOrder) do
        info.frame:SetShownCompat(info.key == key and IsInGuild())
    end
    for _, tab in ipairs(tabs) do
        tab:SetChecked(tab.key == key)
    end
    local info = panes[key]
    if info.shown and IsInGuild() then info.shown(info.frame) end
    if info.refresh and IsInGuild() then info.refresh(info.frame) end
    -- The member detail belongs to the roster.
    if GU.RefreshDetail then GU.RefreshDetail() end
end

function GU.Refresh()
    if not (frame and frame:IsShown()) then return end
    local inGuild = IsInGuild()
    GU.BuildRoster()

    local guildName = GetGuildInfo("player")
    title:SetText(guildName or GUILD)
    GU.emptyText:SetShownCompat(not inGuild)
    card.inset:SetShownCompat(inGuild)
    band.frame:SetShownCompat(inGuild)
    for _, tab in ipairs(tabs) do
        tab:SetShownCompat(inGuild)
    end
    if not inGuild then
        for _, info in ipairs(paneOrder) do info.frame:Hide() end
        return
    end

    refreshTopBand()
    refreshCard()
    local info = GU.activePane and panes[GU.activePane]
    if info then
        if not info.frame:IsShown() then info.frame:Show() end
        if info.refresh then info.refresh(info.frame) end
    end
end

function GU.Open(key)
    if not GU:Enabled() then return end
    build()
    if key then GU.activePane = key end
    if frame:IsShown() then
        if key then GU.SelectPane(key) end
        return
    end
    frame:Show()
end

function GU.Close()
    if frame then frame:Hide() end
end

function GU.IsShown()
    return frame ~= nil and frame:IsShown()
end

function GU.Toggle(key)
    if frame and frame:IsShown() and (not key or key == GU.activePane) then
        GU.Close()
        return
    end
    GU.Open(key)
end
