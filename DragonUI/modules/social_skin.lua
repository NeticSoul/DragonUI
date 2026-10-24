-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local pairs = pairs
local type = type
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions
local hooksecurefunc = hooksecurefunc

local SocialModule = {
    initialized = false,
    applied = false,
}

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("socialskin", SocialModule,
        localized("Social Window"),
        localized("Retail-style friends, who and raid window"),
        { lifecyclePrefix = "SocialSkin", loadOnce = true })
end

local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local MARBLE = DIR .. "UI\\ui-background-marble"

-- A reskin, not a rebuild: every subframe is anchored by fixed offsets into the stock 384x512 frame,
-- so FriendsFrame keeps that size and the retail window is drawn over the rect its old art showed.
local WIDTH, HEIGHT = 338, 424
local CHROME_X, CHROME_Y = 12, -12
-- Left 12 / top 12 is the stock art's margin; right 34 and bottom 76 are what remains of 384x512.
local HIT_LEFT, HIT_RIGHT, HIT_TOP, HIT_BOTTOM = 12, 34, 12, 76

-- The panel slot puts FriendsFrame at the screen corner, 12px left of and above its art. These pull
-- the drawn window onto the spot retail windows use (CharacterFrame and MailFrame nudge to x = 6).
local PANEL_X_OFFSET, PANEL_Y_OFFSET = 6 - CHROME_X, -CHROME_Y

-- The window seat (nineslice.lua) in FriendsFrame space: bottom-row buttons and inset sides keep
-- its gap inside the bronze rails of the window drawn at CHROME_X / CHROME_Y.
local SEAT = addon.WindowSeat
local ROW_LEFT = CHROME_X + SEAT.buttonLeft
local ROW_RIGHT = CHROME_X + WIDTH - 384 + SEAT.buttonRight
local ROW_BOTTOM = 512 + CHROME_Y - HEIGHT + SEAT.buttonBottom

-- Inset rects in FriendsFrame space: TOPLEFT x, y from its top-left; BOTTOMRIGHT x, y from its
-- bottom-right. Each is cut from the stock anchors in FriendsFrame.xml so rows sit inside the trim,
-- and ends 3 above its tab's 21 or 22 tall bottom row.
-- Friends / ignore / pending lists start at y -99 (see LIST_NUDGES).
local INSET_LIST = { ROW_LEFT, -96, ROW_RIGHT, ROW_BOTTOM + 21 + SEAT.gap }
-- Who: column headers at y -70, 17 rows of 16 from -95, WhoFrameTotals under them at bottom 127.
local INSET_WHO = { ROW_LEFT, -66, ROW_RIGHT, 142 }
-- Retail wraps the who search box in its own 20 tall inset; the box is centred on it.
local WHO_EDIT_BOTTOM = ROW_BOTTOM + 22 + SEAT.gap
local INSET_WHO_EDIT = { ROW_LEFT, WHO_EDIT_BOTTOM + 20 - 512, ROW_RIGHT, WHO_EDIT_BOTTOM }
-- Chat and raid have no list geometry this file re-reads, so they get the whole body above the
-- bottom buttons; the guild one only shows if the retail guild window is off.
local INSET_BODY = { ROW_LEFT, -66, ROW_RIGHT, ROW_BOTTOM + 22 + SEAT.gap }

-- The stock bottom rows, re-seated: the left button of each on ROW_LEFT, the right on ROW_RIGHT
-- (the rest of each row hangs off them).
local SEATED_BUTTONS = {
    { "FriendsFrameAddFriendButton", "BOTTOMLEFT" }, { "FriendsFrameSendMessageButton", "BOTTOMRIGHT" },
    { "FriendsFrameIgnorePlayerButton", "BOTTOMLEFT" }, { "FriendsFrameUnsquelchButton", "BOTTOMRIGHT" },
    { "WhoFrameGroupInviteButton", "BOTTOMRIGHT" }, { "ChannelFrameNewButton", "BOTTOMRIGHT" },
    { "GuildFrameControlButton", "BOTTOMRIGHT" },
}
-- Rows wider than the 322 between the seats: Who / Add Friend / Invite was 325, the stock guild
-- row 329 (its 2 gaps included).
local NARROWED_BUTTONS = {
    WhoFrameWhoButton = 82,
    GuildFrameGuildInformationButton = 120,
    GuildFrameAddMemberButton = 94,
}
-- List contents moved by { dx, dy } off their stock anchors, and the scroll frames' new heights:
-- each list starts 3 inside its inset and its bar's steppers end 2.5 inside the other side.
local LIST_TOP = 99
local LIST_NUDGES = {
    { name = "FriendsFrameFriendsScrollFrame", dx = 1.5, dy = 0, height = 512 - 100 - INSET_LIST[4] - 1 },
    { name = "FriendsFrameIgnoreScrollFrame", dx = 1.5, dy = 0, height = 512 - LIST_TOP - INSET_LIST[4] },
    { name = "FriendsFramePendingScrollFrame", dx = 1.5, dy = 0, height = 512 - LIST_TOP - INSET_LIST[4] },
    -- 19 rows of 16 from -102 ran 1.5 past the raised inset; from -99 they end 1 inside it.
    { name = "FriendsFrameIgnoreButton1", dx = 1.5, dy = 102 - LIST_TOP },
    { name = "WhoFrameButton1", dx = 7.5, dy = 0 },
    -- Stock headers start at x 20, 5 right of the rows' 15: line them up with the rows instead.
    { name = "WhoFrameColumnHeader1", dx = 2.5, dy = 0 },
    { name = "WhoListScrollFrame", dx = 7.5, dy = 0 },
    { name = "WhoFrameEditBox", dx = 0.5, dy = WHO_EDIT_BOTTOM - 106 },
    { name = "ChannelListScrollFrame", dx = 2.5, dy = 0 },
}

local SUBFRAME_INSETS = {
    FriendsListFrame = INSET_LIST,
    IgnoreListFrame = INSET_LIST,
    PendingListFrame = INSET_LIST,
    WhoFrame = INSET_WHO,
    GuildFrame = INSET_BODY,
    ChannelFrame = INSET_BODY,
    RaidFrame = INSET_BODY,
}

local HEADER_SUBFRAMES = {
    FriendsListFrame = true,
    IgnoreListFrame = true,
    PendingListFrame = true,
}

-- Where each list's 8px bar goes, left edge from the scroll frame's right edge. That is the centre of
-- the stock 16px slider: UIPanelScrollFrameTemplate hangs it at +6, the friends list at -47 off the
-- frame (2px past its 302px scroll frame). `bottom` lifts a bar whose frame runs past its rows.
local SCROLL_BARS = {
    { name = "FriendsFrameFriendsScrollFrame", x = 2 },
    { name = "FriendsFrameIgnoreScrollFrame", x = 6 },
    { name = "FriendsFramePendingScrollFrame", x = 6 },
    { name = "WhoListScrollFrame", x = 2, bottom = 16 },
    { name = "ChannelListScrollFrame", x = 10 },
    { name = "ChannelRosterScrollFrame", x = 10 },
}

-- Panel buttons across every tab. Names that do not exist on this client are skipped, and only
-- buttons still carrying UI-Panel-Button art are touched, so a guessed name cannot skin a checkbox.
local ACTION_BUTTONS = {
    "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton",
    "FriendsFrameIgnorePlayerButton", "FriendsFrameUnsquelchButton", "FriendsFrameMutePlayerButton",
    "PendingListInfoFrameContinueButton",
    "WhoFrameWhoButton", "WhoFrameAddFriendButton", "WhoFrameGroupInviteButton",
    "ChannelFrameNewButton",
    "RaidFrameConvertToRaidButton", "RaidFrameRaidInfoButton", "RaidFrameRaidBrowserButton",
    "RaidFrameReadyCheckButton", "RaidFrameAddMemberButton",
}
local PENDING_BUTTONS = 4

-- Bottom strip: the character panel's own start and gap, hung off the drawn window's bottom edge.
local NUM_BOTTOM_TABS = 5
local TAB_START_X, TAB_START_Y = 11, 2
local TAB_GAP = 1
-- Friends / Ignore / Pending stand ON the list inset, nose up, 2px into its trim like the bottom
-- tabs overlap the window.
local NUM_HEADER_TABS = 3
local HEADER_TAB_X = INSET_LIST[1] + 6
local HEADER_TAB_Y = INSET_LIST[2] - 2
-- Retail tab art stands up to 36px (42 selected) where the stock header tabs used 24, so the status
-- row above them moves up to clear it.
local HEADER_ROW_LIFT = 8

local SLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

local chrome, listInset, editInset

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("socialskin")
    end
    return true
end

-- On the frame, not in UIPanelWindows: tainting that table blocks the first panel open in combat.
local function nudgePanel(window)
    if not window or not window.SetAttribute then return end
    if window:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_OFFSET
        and window:GetAttribute("UIPanelLayout-yoffset") == PANEL_Y_OFFSET then
        return
    end
    window:SetAttribute("UIPanelLayout-xoffset", PANEL_X_OFFSET)
    window:SetAttribute("UIPanelLayout-yoffset", PANEL_Y_OFFSET)
    if window:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(window)
    end
end

-- The pieces are FriendsFrame's own regions, anchored to `anchor`. A child frame holding them would
-- share a frame level with Blizzard's subframes, and its art could land on top of their rows.
-- `layer` overrides the layout's own draw layer; this client ignores sublevels, so a piece that
-- must sit above another region on the same frame needs a higher layer.
local function applySlicesOn(owner, anchor, layoutName, regions, layer)
    local slicer = _G.DragonUI_NineSlice
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if not (layout and slicer.ApplyLayout) then return end
    for _, piece in ipairs(SLICE_PIECES) do
        local spec = layout[piece]
        if spec and not anchor[piece] then
            local tex = owner:CreateTexture(nil, layer or spec.layer or "BORDER", nil, spec.subLevel or 0)
            anchor[piece] = tex
            if regions then
                regions[#regions + 1] = tex
            end
        end
    end
    slicer.ApplyLayout(anchor, layout)
end

local function dressCloseButton(cb, owner, window)
    if not cb or cb._duiModernized then return end
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then
        CP.ModernizeCloseButton(cb, owner)
        cb:SetFrameLevel((window:GetFrameLevel() or 1) + 22)
    end
end

local function neuterTexture(tex)
    if not tex or tex._duiNeutered then return end
    tex._duiNeutered = true
    tex:SetAlpha(0)
    tex:Hide()
    tex.Show = tex.Hide
end

-- FriendsFrame_Update re-points these four at a different sheet per tab; with Show gone and the
-- alpha at zero, those SetTexture calls land on art that never draws.
local function hideFriendsChromePieces()
    for _, name in ipairs({
        "FriendsFrameTopLeft", "FriendsFrameTopRight", "FriendsFrameBottomLeft", "FriendsFrameBottomRight",
    }) do
        neuterTexture(_G[name])
    end
end

-- No portrait: the tabs already say which window this is. The scroll icon is an unnamed region in
-- 3.3.5a's XML, so it is found by its file.
local function hidePortrait(window)
    for _, region in ipairs({ window:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            local tex = region:GetTexture()
            if type(tex) == "string" and tex:lower():find("friendsframescrollicon") then
                neuterTexture(region)
            end
        end
    end
end

-- The title is a FriendsFrame region like the nine-slice, so it is lifted above the metal it sits on.
local function dressTitle(host, label)
    if not label then return end
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", host, "TOPLEFT", 24, -5)
    label:SetPoint("TOPRIGHT", host, "TOPRIGHT", -24, -5)
    label:SetHeight(16)
    label:SetJustifyH("CENTER")
    if label.SetDrawLayer then
        label:SetDrawLayer("OVERLAY", 7)
    end
end

local function paintWindowChrome(window)
    local host = CreateFrame("Frame", nil, window)
    host:EnableMouse(false)
    host:SetSize(WIDTH, HEIGHT)
    host:SetPoint("TOPLEFT", window, "TOPLEFT", CHROME_X, CHROME_Y)
    window._duiChrome = host

    -- This client ignores sublevels, so the inset's marble and trim (buildInset) take BORDER and
    -- ARTWORK over the rock. The streaks stay on BACKGROUND: they reach 10px into the Who, Chat
    -- and Raid insets, and on BORDER they could draw over the marble there.
    local rock = window:CreateTexture(nil, "BACKGROUND")
    rock._duiOwned = true
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", host, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
    window._duiRockBg = rock

    local streaks = window:CreateTexture(nil, "BACKGROUND")
    streaks._duiOwned = true
    if streaks.SetAtlasTexture then
        streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -21)
        streaks:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -2, -64)
    else
        streaks:Hide()
    end
    window._duiStreaks = streaks

    applySlicesOn(window, host, "NoPortraitFrameTemplate")

    if window.SetHitRectInsets then
        window:SetHitRectInsets(HIT_LEFT, HIT_RIGHT, HIT_TOP, HIT_BOTTOM)
    end

    return host
end

-- An anchor-only frame; its marble and trim are FriendsFrame regions so every subframe draws above.
-- The marble goes on BORDER and the trim on ARTWORK (FriendsFrame's own ARTWORK pieces are hidden):
-- on BACKGROUND the marble tied with the rock and the rock won, so every tab showed one flat tone
-- where the guild window shows dark insets on rock.
local function buildInset(window)
    local inset = CreateFrame("Frame", nil, window)
    inset:EnableMouse(false)
    local regions = {}

    local marble = window:CreateTexture(nil, "BORDER")
    marble._duiOwned = true
    marble:SetTexture(MARBLE, "REPEAT", "REPEAT")
    marble:SetHorizTile(true)
    marble:SetVertTile(true)
    marble:SetAllPoints(inset)
    regions[#regions + 1] = marble

    applySlicesOn(window, inset, "InsetFrameTemplate", regions, "ARTWORK")
    inset._duiRegions = regions
    return inset
end

local function placeInset(inset, window, bounds)
    if not inset or not window or not bounds then return end
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", window, "TOPLEFT", bounds[1], bounds[2])
    inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", bounds[3], bounds[4])
end

local function setInsetShown(inset, shown)
    if not inset or not inset._duiRegions then return end
    for _, region in ipairs(inset._duiRegions) do
        if shown then region:Show() else region:Hide() end
    end
end

local function hideScrollBarBackground(scrollFrame)
    if not scrollFrame or not scrollFrame.GetRegions then return end
    for _, region in ipairs({ scrollFrame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            local tex = region:GetTexture()
            if type(tex) == "string" and tex:lower():find("ui%-character%-scrollbar") then
                neuterTexture(region)
            end
        end
    end
end

-- Without the reskin helper the stock slider keeps its stock anchors, which still fit this layout.
local function styleListScrollBar(spec)
    local scrollFrame = _G[spec.name]
    if not scrollFrame or scrollFrame._duiSocialBar then return end
    local CP = addon.CharacterPanel
    if not (CP and CP.ReskinScrollBar) then return end
    scrollFrame._duiSocialBar = true

    hideScrollBarBackground(scrollFrame)
    -- Retail's ScrollBarMixin hides the thumb when nothing scrolls and keeps the track.
    scrollFrame.hideThumbWhenUnscrollable = true
    CP.ReskinScrollBar(scrollFrame, scrollFrame, 0, 0, 0, true)

    local bar = _G[spec.name .. "ScrollBar"]
    if bar and bar._duiReskinned then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", spec.x, 0)
        bar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", spec.x, spec.bottom or 0)
    end
end

local function styleScrollBars()
    for _, spec in ipairs(SCROLL_BARS) do
        styleListScrollBar(spec)
    end
end

local function isPanelButtonArt(region)
    local tex = region and region.GetTexture and region:GetTexture()
    return type(tex) == "string" and tex:lower():find("ui%-panel%-button") ~= nil
end

-- Returns the stone regions and whether this is a panel button at all; UIPanelButtonTemplate keeps
-- its stone in the state textures, which SkinRedButton clears itself.
local function panelButtonArt(btn)
    local art = {}
    for _, region in ipairs({ btn:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and isPanelButtonArt(region) then
            art[#art + 1] = region
        end
    end
    local normal = btn.GetNormalTexture and btn:GetNormalTexture()
    return art, #art > 0 or isPanelButtonArt(normal)
end

-- UIPanelButtonTemplate2 draws its stone as named Left/Middle/Right regions its own scripts re-texture
-- on every state change, which SkinRedButton's state-texture strip never reaches.
local function skinActionButton(btn)
    if not btn or btn._duiRedButton or not addon.SkinRedButton then return end
    if not (btn.GetObjectType and btn:GetObjectType() == "Button") then return end
    local art, isPanelButton = panelButtonArt(btn)
    if not isPanelButton then return end
    for _, region in ipairs(art) do
        neuterTexture(region)
    end
    addon.SkinRedButton(btn)
end

-- Re-run on every tab switch: Blizzard_RaidUI loads on demand and adds its buttons late.
local function skinActionButtons()
    for _, name in ipairs(ACTION_BUTTONS) do
        skinActionButton(_G[name])
    end
    for i = 1, PENDING_BUTTONS do
        local row = "FriendsFramePendingButton" .. i
        skinActionButton(_G[row .. "AcceptButton"])
        skinActionButton(_G[row .. "DeclineButton"])
    end
end

-- tabs.lua re-chains through `_duiRelayout` whenever Blizzard's PanelTemplates_TabResize runs, so
-- these strips never fall back to the character panel's chain.
local relayoutBottomTabs, relayoutHeaderTabs

relayoutBottomTabs = function()
    local CP = addon.CharacterPanel
    if not (chrome and CP and CP.ReskinTab) then return end
    local prev
    for i = 1, NUM_BOTTOM_TABS do
        local tab = _G["FriendsFrameTab" .. i]
        if tab then
            tab._duiRelayout = relayoutBottomTabs
            if tab:IsShown() then
                CP.ReskinTab(tab)
                tab:ClearAllPoints()
                if prev then
                    tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
                else
                    tab:SetPoint("TOPLEFT", chrome, "BOTTOMLEFT", TAB_START_X, TAB_START_Y)
                end
                prev = tab
            end
        end
    end
end

relayoutHeaderTabs = function()
    local CP = addon.CharacterPanel
    local window = _G.FriendsFrame
    if not (window and chrome and CP and CP.ReskinTab) then return end
    local prev
    for i = 1, NUM_HEADER_TABS do
        local tab = _G["FriendsTabHeaderTab" .. i]
        if tab then
            tab._duiRelayout = relayoutHeaderTabs
            if tab:IsShown() then
                CP.ReskinTab(tab, true)
                tab:ClearAllPoints()
                if prev then
                    tab:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
                else
                    tab:SetPoint("BOTTOMLEFT", window, "TOPLEFT", HEADER_TAB_X, HEADER_TAB_Y)
                end
                prev = tab
            end
        end
    end
end

-- Tab 3 (Pending) hides without Battle.net, and the guild window may hide the guild tab.
local function hookTabVisibility(prefix, count, relayout)
    for i = 1, count do
        local tab = _G[prefix .. i]
        if tab and not tab._duiSocialTabHooked then
            tab._duiSocialTabHooked = true
            local function onVisibility()
                if IsModuleEnabled() then relayout() end
            end
            tab:HookScript("OnShow", onVisibility)
            tab:HookScript("OnHide", onVisibility)
        end
    end
end

-- The status dropdown and the Battle.net status both hang off FriendsTabHeader's top-left; the
-- broadcast box hangs off the dropdown and follows it. Only for the taller retail tabs.
local function liftHeaderRow()
    local CP = addon.CharacterPanel
    if not (CP and CP.ReskinTab) then return end
    for _, name in ipairs({ "FriendsFrameStatusDropDown", "FriendsFrameBattlenetStatus" }) do
        local frame = _G[name]
        if frame and not frame._duiLifted and frame:GetNumPoints() == 1 then
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
            frame._duiLifted = true
            frame:ClearAllPoints()
            frame:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) + HEADER_ROW_LIFT)
        end
    end
end

-- Once per frame: the stock anchors are set in XML and nothing re-applies them.
local function nudgeOnce(frame, dx, dy)
    if not frame or frame._duiSeatNudged or frame:GetNumPoints() ~= 1 then return end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    frame._duiSeatNudged = true
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, (x or 0) + dx, (y or 0) + dy)
end

-- Some of these live in Blizzard_RaidUI / the guild pane, so it runs again on every view sync.
local function seatBottomRows()
    local window = _G.FriendsFrame
    for _, entry in ipairs(SEATED_BUTTONS) do
        local button = _G[entry[1]]
        if button and not button._duiSeated then
            button._duiSeated = true
            button:ClearAllPoints()
            button:SetPoint(entry[2], window, entry[2], entry[2] == "BOTTOMLEFT" and ROW_LEFT or ROW_RIGHT,
                ROW_BOTTOM)
        end
    end
    for name, width in pairs(NARROWED_BUTTONS) do
        local button = _G[name]
        if button then button:SetWidth(width) end
    end
    for _, spec in ipairs(LIST_NUDGES) do
        local frame = _G[spec.name]
        nudgeOnce(frame, spec.dx, spec.dy)
        if frame and spec.height then frame:SetHeight(spec.height) end
    end
end

-- With no scrollbar WhoList_Update widens the zone column to 120, a 321 wide header row that ran
-- past the 322 wide inset; 5 off it leaves the row 3 inside on both sides, like the rows below.
local WHO_WIDE_COLUMN = 120
local WHO_COLUMN_TRIM = 5

local function fitWhoHeader()
    local header = _G.WhoFrameColumnHeader2
    if not (IsModuleEnabled() and header and header:GetWidth() == WHO_WIDE_COLUMN) then return end
    _G.WhoFrameColumn_SetWidth(header, WHO_WIDE_COLUMN - WHO_COLUMN_TRIM)
    _G.UIDropDownMenu_SetWidth(_G.WhoFrameDropDown, 95 - WHO_COLUMN_TRIM)
end

local function activeSubFrame()
    local names = _G.FRIENDSFRAME_SUBFRAMES
    if type(names) ~= "table" then return end
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            return name
        end
    end
end

local function syncView(frameName)
    if not IsModuleEnabled() then return end
    local window = _G.FriendsFrame
    if not (window and window._duiSkinned) then return end

    -- The hook hands over the frame Blizzard asked for; anything else asks which one is up.
    if type(frameName) ~= "string" then
        frameName = activeSubFrame()
    end

    hideFriendsChromePieces()
    local bounds = frameName and SUBFRAME_INSETS[frameName]
    if bounds then
        placeInset(listInset, window, bounds)
    end
    setInsetShown(listInset, bounds ~= nil)
    setInsetShown(editInset, frameName == "WhoFrame")

    if frameName and HEADER_SUBFRAMES[frameName] then
        relayoutHeaderTabs()
    end
    skinActionButtons()
    seatBottomRows()
    styleScrollBars()
    relayoutBottomTabs()
end

local function buildSocialFrame()
    local window = _G.FriendsFrame
    if not window or window._duiSkinned then return end
    window._duiSkinned = true

    hideFriendsChromePieces()
    nudgePanel(window)

    chrome = paintWindowChrome(window)
    hidePortrait(window)
    dressTitle(chrome, _G.FriendsFrameTitleText)
    dressCloseButton(_G.FriendsFrameCloseButton, chrome, window)

    listInset = buildInset(window)
    placeInset(listInset, window, INSET_LIST)
    editInset = buildInset(window)
    placeInset(editInset, window, INSET_WHO_EDIT)
    setInsetShown(editInset, false)

    styleScrollBars()
    skinActionButtons()

    liftHeaderRow()
    hookTabVisibility("FriendsFrameTab", NUM_BOTTOM_TABS, relayoutBottomTabs)
    hookTabVisibility("FriendsTabHeaderTab", NUM_HEADER_TABS, relayoutHeaderTabs)
    relayoutHeaderTabs()
    relayoutBottomTabs()

    -- Every tab and sub-tab switch funnels through here, with the frame it is about to show.
    if _G.FriendsFrame_ShowSubFrame and not window._duiSubFrameHooked then
        window._duiSubFrameHooked = true
        hooksecurefunc("FriendsFrame_ShowSubFrame", syncView)
    end
    if _G.WhoList_Update and not window._duiWhoHeaderHooked then
        window._duiWhoHeaderHooked = true
        hooksecurefunc("WhoList_Update", fitWhoHeader)
        fitWhoHeader()
    end

    -- First open: Blizzard's OnShow already picked the subframe before the hook above existed.
    syncView()
end

local function onFriendsFrameShow()
    if not IsModuleEnabled() then return end
    if not _G.FriendsFrame._duiSkinned then
        buildSocialFrame()
    else
        syncView()
    end
end

local function hookFriendsFrame()
    local window = _G.FriendsFrame
    if not window or window._duiSocialShowHooked then return end
    window._duiSocialShowHooked = true
    window:HookScript("OnShow", onFriendsFrameShow)
    if window:IsShown() then
        onFriendsFrameShow()
    end
end

-- Nothing is skinned until the window first opens; only the panel offsets go on now, so that first
-- open already lands where the drawn window belongs.
local function applySocialSkin()
    nudgePanel(_G.FriendsFrame)
    hookFriendsFrame()
end

function addon.ApplySocialSkinSystem()
    if not IsModuleEnabled() then return end
    SocialModule.initialized = true
    SocialModule.applied = true
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("socialskin_apply", applySocialSkin)
        return
    end
    applySocialSkin()
end

function addon.RestoreSocialSkinSystem()
    SocialModule.applied = false
end

function addon.RefreshSocialSkinSystem()
    if IsModuleEnabled() then
        addon.ApplySocialSkinSystem()
    else
        addon.RestoreSocialSkinSystem()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, name)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_LOGIN" then
        addon.ApplySocialSkinSystem()
    elseif event == "ADDON_LOADED" and name == "Blizzard_RaidUI" then
        local window = _G.FriendsFrame
        if window and window._duiSkinned then
            skinActionButtons()
        end
    end
end)
