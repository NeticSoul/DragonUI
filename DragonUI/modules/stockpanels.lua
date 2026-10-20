-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local type = type
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc
local UpdateUIPanelPositions = UpdateUIPanelPositions

-- The stock windows DragonUI has no window of its own for: Quest Log, Dungeon Finder, PvP,
-- Achievements and the Game Menu. Like social_skin.lua this is a reskin, not a rebuild: each keeps its stock size and
-- every Blizzard anchor, and the bronze window is drawn over the rect its old art showed.
local StockPanels = { initialized = false, applied = false }

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("stockpanels", StockPanels,
        localized("Stock Windows"),
        localized("Retail-style quest log, dungeon finder, PvP, achievements and game menu chrome"),
        { lifecyclePrefix = "StockPanels", loadOnce = true })
end

local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local MARBLE = DIR .. "UI\\ui-background-marble"

local SLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- Bottom tab strip, the character panel's own start and gap off the drawn window's bottom edge.
local TAB_START_X, TAB_START_Y, TAB_GAP = 11, 2, 1

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("stockpanels")
    end
    return true
end

local function neuterTexture(tex)
    if not tex or tex._duiNeutered then return end
    tex._duiNeutered = true
    tex:SetAlpha(0)
    tex:Hide()
    tex.Show = tex.Hide
end

local function neuterFrame(frame)
    if not frame or frame._duiNeutered then return end
    frame._duiNeutered = true
    frame:SetAlpha(0)
    frame:Hide()
    frame.Show = frame.Hide
end

local function fileOf(region)
    local tex = region and region.GetTexture and region:GetTexture()
    return type(tex) == "string" and tex:lower() or ""
end

-- Several stock chrome pieces are unnamed in the XML, so they are found by their file.
local function hideArtByFile(frame, patterns)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            local file = fileOf(region)
            for _, pattern in ipairs(patterns) do
                if file:find(pattern) then
                    neuterTexture(region)
                    break
                end
            end
        end
    end
end

local function hideNamed(names)
    for _, name in ipairs(names) do
        local object = _G[name]
        if object and object.GetObjectType then
            if object:GetObjectType() == "Texture" then
                neuterTexture(object)
            else
                neuterFrame(object)
            end
        end
    end
end

-- The unnamed title string, found by the text Blizzard gave it.
local function fontStringByText(frame, text)
    if not frame or not text then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "FontString" and region:GetText() == text then
            return region
        end
    end
end

-- On the frame, not in UIPanelWindows: tainting that table blocks the first panel open in combat.
-- Pulls the drawn window onto the spot retail windows use (CharacterFrame nudges to x = 6).
local function nudgePanel(window, x, y)
    if not window or not window.SetAttribute then return end
    if window:GetAttribute("UIPanelLayout-xoffset") == x and window:GetAttribute("UIPanelLayout-yoffset") == y then
        return
    end
    window:SetAttribute("UIPanelLayout-xoffset", x)
    window:SetAttribute("UIPanelLayout-yoffset", y)
    if window:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(window)
    end
end

-- The pieces are the window's own regions anchored to `anchor`: a child frame holding them would
-- tie with Blizzard's subframes and could draw over their rows. This client ignores sublevels, so
-- `layer` overrides the layout's when a piece must sit above another region of the same frame.
local function applySlicesOn(owner, anchor, layoutName, regions, layer)
    local slicer = _G.DragonUI_NineSlice
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if not (layout and slicer.ApplyLayout) then return end
    for _, piece in ipairs(SLICE_PIECES) do
        local spec = layout[piece]
        if spec and not anchor[piece] then
            local tex = owner:CreateTexture(nil, layer or spec.layer or "BORDER", nil, spec.subLevel or 0)
            anchor[piece] = tex
            if regions then regions[#regions + 1] = tex end
        end
    end
    slicer.ApplyLayout(anchor, layout)
end

-- `rect` is { left, top, right, bottom }: TOPLEFT offsets from the window's top-left, BOTTOMRIGHT
-- offsets from its bottom-right. The body is rock under the 21px title band, streaks fading below.
local function paintChrome(window, rect)
    local host = CreateFrame("Frame", nil, window)
    host:EnableMouse(false)
    host:SetPoint("TOPLEFT", window, "TOPLEFT", rect[1], rect[2])
    host:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", rect[3], rect[4])

    local rock = window:CreateTexture(nil, "BACKGROUND")
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", host, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)

    local streaks = window:CreateTexture(nil, "BACKGROUND")
    if streaks.SetAtlasTexture then
        streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -21)
        streaks:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", -2, -64)
    else
        streaks:Hide()
    end

    applySlicesOn(window, host, "NoPortraitFrameTemplate")
    window._duiChrome = host
    return host
end

-- Ground on BORDER and the filigree on ARTWORK, both the window's own regions so every subframe
-- draws above them (on BACKGROUND the ground ties with the rock and the rock wins). The ground is
-- marble, or the quest parchment for a pane whose text was written for paper.
-- `bounds` are offsets from the window's corners, or from `bounds.topLeft` / `bounds.bottomRight`
-- when the inset follows a pane Blizzard resizes.
local function addInset(window, bounds, parchment)
    local inset = CreateFrame("Frame", nil, window)
    inset:EnableMouse(false)
    inset:SetPoint("TOPLEFT", bounds.topLeft or window, "TOPLEFT", bounds[1], bounds[2])
    inset:SetPoint("BOTTOMRIGHT", bounds.bottomRight or window, "BOTTOMRIGHT", bounds[3], bounds[4])

    local ground = window:CreateTexture(nil, "BORDER")
    if parchment and ground.SetAtlasTexture then
        ground:SetAtlasTexture("questbg-parchment")
    else
        ground:SetTexture(MARBLE, "REPEAT", "REPEAT")
        ground:SetHorizTile(true)
        ground:SetVertTile(true)
    end
    ground:SetAllPoints(inset)

    applySlicesOn(window, inset, "InsetFrameTemplate", nil, "ARTWORK")
    return inset
end

local function dressTitle(host, label)
    if not (host and label) then return end
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", host, "TOPLEFT", 24, -5)
    label:SetPoint("TOPRIGHT", host, "TOPRIGHT", -24, -5)
    label:SetHeight(16)
    label:SetJustifyH("CENTER")
    if label.SetDrawLayer then label:SetDrawLayer("OVERLAY") end
end

local function dressCloseButton(cb, host, window)
    local CP = addon.CharacterPanel
    if not (cb and CP and CP.ModernizeCloseButton) or cb._duiModernized then return end
    CP.ModernizeCloseButton(cb, host)
    cb:SetFrameLevel((window:GetFrameLevel() or 1) + 20)
end

-- Same strip as the Social window: retail tabs chained off the drawn window's bottom-left.
local function dressTabs(host, prefix, count)
    local CP = addon.CharacterPanel
    if not (CP and CP.ReskinTab) then return end
    local function relayout()
        local prev
        for i = 1, count do
            local tab = _G[prefix .. i]
            if tab then
                tab._duiRelayout = relayout
                if tab:IsShown() then
                    CP.ReskinTab(tab)
                    tab:ClearAllPoints()
                    if prev then
                        tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
                    else
                        tab:SetPoint("TOPLEFT", host, "BOTTOMLEFT", TAB_START_X, TAB_START_Y)
                    end
                    prev = tab
                end
            end
        end
    end
    for i = 1, count do
        local tab = _G[prefix .. i]
        if tab and not tab._duiStockTabHooked then
            tab._duiStockTabHooked = true
            tab:HookScript("OnShow", relayout)
            tab:HookScript("OnHide", relayout)
        end
    end
    relayout()
end

-- The stock gutter art behind a UIPanelScrollFrameTemplate bar, replaced by the minimal bar that
-- hangs `x` right of the scroll frame.
local function dressScrollBar(scrollName, x)
    local scroll = _G[scrollName]
    local CP = addon.CharacterPanel
    if not (scroll and CP and CP.ReskinScrollBar) or scroll._duiStockBar then return end
    scroll._duiStockBar = true
    hideArtByFile(scroll, { "ui%-character%-scrollbar" })
    scroll.hideThumbWhenUnscrollable = true
    CP.ReskinScrollBar(scroll, scroll, 0, 0, 0, true)
    local bar = _G[scrollName .. "ScrollBar"]
    if bar and bar._duiReskinned then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", x, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", x, 0)
    end
end

-- Draws the bronze window over `spec.rect` of the stock frame. Everything else is the caller's.
local function skinWindow(window, spec)
    local host = paintChrome(window, spec.rect)
    nudgePanel(window, 6 - spec.rect[1], -spec.rect[2])
    if spec.hit and window.SetHitRectInsets then
        window:SetHitRectInsets(spec.hit[1], spec.hit[2], spec.hit[3], spec.hit[4])
    end
    dressTitle(host, spec.title)
    dressCloseButton(spec.close, host, window)
    for _, bounds in ipairs(spec.insets or {}) do
        addInset(window, bounds, bounds.parchment)
    end
    return host
end

-- ============================================================================
-- QUEST LOG (682x447 double-wide; the dual-pane art fills it below a 12px lip)
-- ============================================================================

-- The bottom row sits the seat's height above the rail (stock it hung 13 in from the left and 1.5
-- off the right rail), and the insets' outer sides and bottoms keep the seat's gap to the rails and
-- the row. The control panel is 26 tall with its 21 buttons centred 1 high, so it sits 3.5 under
-- their bottom edge.
local QUEST_ROW_BOTTOM = 2 + addon.WindowSeat.buttonBottom
local QUEST_INSET_BOTTOM = QUEST_ROW_BOTTOM + 21 + addon.WindowSeat.gap
-- List: QuestLogScrollFrame (305x335) plus its hybrid bar's 16px on the right, moved 5 left of its
-- stock 19,-75 so it sits 6.5 / 7 inside the inset.
local QUEST_LIST_SCROLL_X = 14
local QUEST_LIST_INSET = { addon.WindowSeat.buttonLeft, -70, -340, QUEST_INSET_BOTTOM }
-- Details: QuestLogDetailScrollFrame hangs TOPRIGHT -32,-77 (298x333), its bar 8 right of that.
-- Parchment, not marble: QuestInfo writes its text in the dark ink of the stock paper pane.
local QUEST_DETAIL_INSET = { 349, -70, addon.WindowSeat.buttonRight, QUEST_INSET_BOTTOM, parchment = true }

local QUEST_PANEL_X, QUEST_PANEL_Y = QUEST_LIST_INSET[1], QUEST_ROW_BOTTOM - 3.5

-- Blizzard re-anchors the panel each time the log or the detached detail window shows or hides.
local function placeQuestControls()
    local panel, window = _G.QuestLogControlPanel, _G.QuestLogFrame
    if not (panel and window and window._duiStockSkinned) or panel:GetParent() ~= window then return end
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", QUEST_PANEL_X, QUEST_PANEL_Y)
end

local function buildQuestLog()
    local window = _G.QuestLogFrame
    if not window or window._duiStockSkinned then return end
    window._duiStockSkinned = true

    hideArtByFile(window, { "ui%-questlogdualpane", "ui%-questlog%-bookicon" })
    skinWindow(window, {
        rect = { 0, -12, 0, 2 },
        title = _G.QuestLogTitleText,
        close = _G.QuestLogFrameCloseButton,
        insets = { QUEST_LIST_INSET, QUEST_DETAIL_INSET },
    })
    dressScrollBar("QuestLogDetailScrollFrame", 8)
    local list = _G.QuestLogScrollFrame
    if list and list:GetNumPoints() == 1 then
        local point, relativeTo, relativePoint, _, y = list:GetPoint(1)
        list:ClearAllPoints()
        list:SetPoint(point, relativeTo, relativePoint, QUEST_LIST_SCROLL_X, y)
    end

    local cancel = _G.QuestLogFrameCancelButton
    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", QUEST_DETAIL_INSET[3], QUEST_ROW_BOTTOM)
    end
    if _G.QuestLogControlPanel_UpdatePosition then
        hooksecurefunc("QuestLogControlPanel_UpdatePosition", placeQuestControls)
    end
    placeQuestControls()
end

-- ============================================================================
-- DUNGEON FINDER (355x440; the art's frame runs 12 in from the top-left)
-- ============================================================================

local LFD_RECT = { 12, -12, -6, 2 }
local LFD_BUTTON_H = 22

-- Top to bottom under the band: the role row, the Type row, then one inset holding the random and
-- specific panes. The 48 role buttons' 80 glows run from the band's bottom edge (32 down) to the
-- top of the Type row's art.
local LFD_ROLE_TOP, LFD_ROLE_GAP = -48, 24
local LFD_ROLES = { "Tank", "Healer", "DPS", "Leader" }
local LFD_TYPE_Y = -124 -- centre of the Type row
local LFD_INSET_TOP = -144
local LFD_PAD = 4 -- the panes inside the inset
-- LFDQueueFrameTypeDropDown_SetUp sizes the menu 180, so the frame is 230: its art starts 18 in from
-- the frame's left and ends 20 short of its right (measured from an in-game screenshot).
local LFD_TYPE_FRAME_W, LFD_TYPE_ART_LEFT, LFD_TYPE_ART_RIGHT = 230, 18, 20
local LFD_TYPE_LABEL_GAP = 6
-- The minimal bar (characterpanel/scrollbar.lua) is 8 wide; both panes end it LFD_PAD inside.
local LFD_BAR_W = 8
-- Stock rows are 315 wide, or 295 beside the list's bar: both lose what the inset's padding takes.
local LFD_ROW_TRIM = 2

-- Everything inside keeps the seat's gap off the rails (nineslice.lua), as the bottom buttons do.
-- Returns the content's left, right and bottom offsets from the window's corners.
local function lfdContent()
    local seat = addon.WindowSeat
    return LFD_RECT[1] + seat.left + seat.gap,
        LFD_RECT[3] + seat.right - seat.gap,
        LFD_RECT[4] + seat.buttonBottom + LFD_BUTTON_H + seat.gap
end

-- LFDParentFrame's close button is the one child the XML leaves unnamed.
local function lfdCloseButton(window)
    for _, child in ipairs({ window:GetChildren() }) do
        local isButton = child:GetObjectType() == "Button"
        if isButton and fileOf(child:GetNormalTexture()):find("ui%-panel%-minimizebutton") then
            return child
        end
    end
end

-- Stock the roles start 65 in with gaps of 25, 23 and 32: centred on the content with even gaps.
local function placeRoles(window, centre)
    local buttons, total = {}, 0
    for _, role in ipairs(LFD_ROLES) do
        local button = _G["LFDQueueFrameRoleButton" .. role]
        if button then
            buttons[#buttons + 1] = button
            total = total + button:GetWidth()
        end
    end
    if #buttons == 0 then return end
    total = total + LFD_ROLE_GAP * (#buttons - 1)
    for i, button in ipairs(buttons) do
        button:ClearAllPoints()
        if i == 1 then
            button:SetPoint("TOPLEFT", window, "TOPLEFT", centre - total / 2, LFD_ROLE_TOP)
        else
            button:SetPoint("LEFT", buttons[i - 1], "RIGHT", LFD_ROLE_GAP, 0)
        end
    end
end

-- Stock the label hung 115 wide off the menu's transparent left and the menu ran onto the right
-- rail; now "Type:" and the menu's art are one row, centred.
local function placeTypeRow(window, centre)
    local menu, label = _G.LFDQueueFrameTypeDropDown, _G.LFDQueueFrameTypeDropDownName
    if not menu then return end
    local labelW = label and label:GetStringWidth() or 0
    local artW = LFD_TYPE_FRAME_W - LFD_TYPE_ART_LEFT - LFD_TYPE_ART_RIGHT
    local rowLeft = centre - (labelW + LFD_TYPE_LABEL_GAP + artW) / 2
    menu:ClearAllPoints()
    menu:SetPoint("LEFT", window, "TOPLEFT",
        rowLeft + labelW + LFD_TYPE_LABEL_GAP - LFD_TYPE_ART_LEFT, LFD_TYPE_Y)
    if label then
        label:ClearAllPoints()
        label:SetPoint("RIGHT", menu, "LEFT", LFD_TYPE_ART_LEFT - LFD_TYPE_LABEL_GAP, 2)
    end
end

local function trimSpecificRows()
    local scroll = _G.LFDQueueFrameSpecificListScrollFrame
    local count = _G.NUM_LFD_CHOICE_BUTTONS or 15
    for i = 1, count do
        local row = _G["LFDQueueFrameSpecificListButton" .. i]
        if row then
            row:SetWidth((scroll and scroll:IsShown() and 295 or 315) - 2 * LFD_ROW_TRIM)
        end
    end
end

local function buildLFD()
    local window = _G.LFDParentFrame
    if not window or window._duiStockSkinned then return end
    window._duiStockSkinned = true

    -- The parchment goes too: its text is white and gold, written for the dark inset it now sits on.
    hideNamed({ "LFDQueueFrameLayout", "LFDQueueFrameBackground", "LFDParentFramePortrait" })
    local host = skinWindow(window, {
        rect = LFD_RECT,
        hit = { 12, 6, 12, 2 },
        title = _G.LFDQueueFrameTitleText,
        close = lfdCloseButton(window),
    })

    local left, right, bottom = lfdContent()
    local centre = (left + window:GetWidth() + right) / 2
    placeRoles(window, centre)
    placeTypeRow(window, centre)
    local inset = addInset(window, { left, LFD_INSET_TOP, right, bottom })

    -- Random: one scroll pane inside the inset, the minimal bar LFD_BAR_W right of it in place of
    -- the stock gutter.
    local paneTop, paneBottom = LFD_INSET_TOP - LFD_PAD, bottom + LFD_PAD
    local barLeft = right - LFD_PAD - LFD_BAR_W -- from the window's right, like `right`
    local scroll = _G.LFDQueueFrameRandomScrollFrame
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", window, "TOPLEFT", left + LFD_PAD, paneTop)
        scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", barLeft - LFD_BAR_W, paneBottom)
        dressScrollBar("LFDQueueFrameRandomScrollFrame", LFD_BAR_W)
    end

    -- Specific: the 16-tall rows start under the inset's top; their faux scroll frame spans them 7
    -- over and under, so the first row drops 7 more to keep that frame inside the inset too.
    local first = _G.LFDQueueFrameSpecificListButton1
    if first then
        first:ClearAllPoints()
        first:SetPoint("TOPLEFT", window, "TOPLEFT", left + LFD_PAD, paneTop - 7)
    end
    if _G.LFDQueueFrameSpecificList_Update then
        hooksecurefunc("LFDQueueFrameSpecificList_Update", trimSpecificRows)
    end
    trimSpecificRows()
    local list = _G.LFDQueueFrameSpecificListScrollFrame
    if list then
        -- The bar ends where Random's does: the frame's right is the 293 rows' plus 1.
        local listRight = left + LFD_PAD + 295 - 2 * LFD_ROW_TRIM + 1
        local barX = window:GetWidth() + barLeft - listRight
        dressScrollBar("LFDQueueFrameSpecificListScrollFrame", barX)
    end

    -- Stock, both buttons sit on the bottom rail and Close half into the right one.
    local seat = addon.WindowSeat
    local find, cancel = _G.LFDQueueFrameFindGroupButton, _G.LFDQueueFrameCancelButton
    if find then
        find:ClearAllPoints()
        find:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", seat.buttonLeft, seat.buttonBottom)
    end
    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", seat.buttonRight, seat.buttonBottom)
    end
    -- The cooldown, backfill and raid-finder covers take mouse input and ended where the buttons
    -- began; on the inset they cover the panes without reaching the raised buttons.
    local covers = { "LFDQueueFrameCooldownFrame", "LFDQueueFramePartyBackfill", "LFDQueueFrameNoLFDWhileLFR" }
    for _, name in ipairs(covers) do
        local cover = _G[name]
        if cover then
            cover:ClearAllPoints()
            cover:SetAllPoints(inset)
        end
    end
end

-- ============================================================================
-- PVP (384x512 like the old character window; art at 2,-1, so 14 in from the left)
-- ============================================================================

local PVP_RECT = { 14, -13, -32, 75 }
-- Group Join / Join / Cancel ran 136 + 109 + 2 + 83 = 330, past the 322 between the seats.
local PVP_GROUP_JOIN_W = 128

local function buildPvP()
    local window = _G.PVPParentFrame
    if not window or window._duiStockSkinned then return end
    window._duiStockSkinned = true

    -- The honor and arena panels (PVPFrameBackground, PvpRandomBg) are content, not chrome; they stay.
    hideArtByFile(_G.PVPFrame, { "ui%-character%-general" })
    hideArtByFile(_G.PVPBattlegroundFrame, { "ui%-battlefield%-top", "ui%-queuefromanywhere%-bot" })
    hideNamed({ "PVPFramePortrait", "PVPBattlegroundFramePortrait" })

    local host = skinWindow(window, {
        rect = PVP_RECT,
        hit = { 14, 32, 13, 75 },
        close = _G.PVPParentFrameCloseButton,
    })
    -- Each tab's own title, both re-seated in the one title band.
    dressTitle(host, fontStringByText(_G.PVPFrame, _G.PLAYER_V_PLAYER))
    dressTitle(host, _G.PVPBattlegroundFrameFrameLabel)
    dressTabs(host, "PVPParentFrameTab", 2)

    -- Stock, the queue row hung 2 past the right rail and the team toggle sat on the bottom one; both
    -- take the seat (the rest of the row hangs off Cancel).
    local seat = addon.WindowSeat
    local cancel, groupJoin = _G.PVPBattlegroundFrameCancelButton, _G.PVPBattlegroundFrameGroupJoinButton
    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", seat.buttonRight, seat.buttonBottom)
    end
    if groupJoin then groupJoin:SetWidth(PVP_GROUP_JOIN_W) end
    local toggle = _G.PVPFrameToggleButton
    if toggle then
        toggle:ClearAllPoints()
        toggle:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", seat.buttonRight, seat.buttonBottom)
    end
end

-- ============================================================================
-- GAME MENU (a 195-wide dialog box; the bronze window takes its whole rect)
-- ============================================================================

local function buildGameMenu()
    local window = _G.GameMenuFrame
    if not window or window._duiStockSkinned then return end
    window._duiStockSkinned = true

    if window.SetBackdrop then window:SetBackdrop(nil) end
    local header = _G.GameMenuFrameHeader
    local title = fontStringByText(window, _G.MAIN_MENU)
    neuterTexture(header)
    local host = paintChrome(window, { 0, 0, 0, 0 })
    dressTitle(host, title)
end

-- ============================================================================
-- ACHIEVEMENTS (768x500 load-on-demand; wood border, metal rails and a header hung above the top)
-- ============================================================================

-- The bronze title band takes the room the stock header used above the frame, so the window grows
-- by one toolbar strip under the band for the Filter dropdown and DragonUI's Search button.
local ACH_RECT = { 10, 7, -16, 8 }
local ACH_TOOLBAR_H = 26
local ACH_CATEGORIES_TOP = -19 - ACH_TOOLBAR_H
-- Content inset: the panes' left edge (the category scroll bar sits in the gap before it), out to
-- the achievement list's scroll bar, then the seat's gap inside the right and bottom rails.
local ACH_CONTENT_RIGHT, ACH_CONTENT_BOTTOM = -26, 17
local ACH_PAD = 3
-- A pane's own scroll bar hangs 1 right of it; the summary has none and spans that column too.
local ACH_BAR_COLUMN = 17
local ACH_TOOLBAR_Y = -17

local function stripPane(pane, keepNamed)
    if not pane then return end
    for _, region in ipairs({ pane:GetRegions() }) do
        if region:GetObjectType() == "Texture" and not (keepNamed and keepNamed[region:GetName() or ""]) then
            neuterTexture(region)
        end
    end
    -- The tooltip-border boxes are unnamed setAllPoints children.
    for _, child in ipairs({ pane:GetChildren() }) do
        if not child:GetName() and child.SetBackdrop then
            child:SetBackdrop(nil)
        end
    end
end

-- Blizzard re-anchors a tab's label on click (0,-5 selected / 0,-3 other) after SelectTab, so the
-- label is re-synced afterwards. Addons such as Overachiever add more tabs on the same template.
local function achievementTabCount()
    local count = 2
    while _G["AchievementFrameTab" .. (count + 1)] do count = count + 1 end
    return count
end

local function dressAchievementTabs(host)
    local CP = addon.CharacterPanel
    local count = achievementTabCount()
    for i = 1, count do
        local tab = _G["AchievementFrameTab" .. i]
        if tab and not tab._duiAchievementTab then
            tab._duiAchievementTab = true
            local name = tab:GetName()
            hideNamed({ name .. "LeftHighlight", name .. "MiddleHighlight", name .. "RightHighlight" })
            tab:HookScript("OnClick", function()
                for j = 1, achievementTabCount() do
                    local other = _G["AchievementFrameTab" .. j]
                    if other and other._duiReskinned and CP and CP.ReskinTab then CP.ReskinTab(other) end
                end
            end)
        end
    end
    dressTabs(host, "AchievementFrameTab", count)
end

-- Toolbar: Search button at the content inset's right edge, the Filter dropdown (label + arrow, no
-- box of its own) to its left.
local function placeAchievementToolbar(window)
    local search = addon.AchievementSearch
    local button = search and search.button
    if button then
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", window, "TOPRIGHT", ACH_CONTENT_RIGHT, ACH_TOOLBAR_Y)
    end
    local filter = _G.AchievementFrameFilterDropDown
    if filter then
        filter:ClearAllPoints()
        if button then
            filter:SetPoint("TOPRIGHT", button, "TOPLEFT", -8, 1)
        else
            filter:SetPoint("TOPRIGHT", window, "TOPRIGHT", ACH_CONTENT_RIGHT, ACH_TOOLBAR_Y + 1)
        end
    end
end

local function buildAchievements()
    local window = _G.AchievementFrame
    if not window or window._duiStockSkinned then return end
    window._duiStockSkinned = true

    if window.SetBackdrop then window:SetBackdrop(nil) end
    hideNamed({
        "AchievementFrameBackground", "AchievementFrameCategoriesBG", "AchievementFrameWaterMark",
        "AchievementFrameMetalBorderLeft", "AchievementFrameMetalBorderRight",
        "AchievementFrameMetalBorderTop", "AchievementFrameMetalBorderBottom",
        "AchievementFrameMetalBorderTopLeft", "AchievementFrameMetalBorderTopRight",
        "AchievementFrameMetalBorderBottomLeft", "AchievementFrameMetalBorderBottomRight",
        "AchievementFrameWoodBorderTopLeft", "AchievementFrameWoodBorderTopRight",
        "AchievementFrameWoodBorderBottomLeft", "AchievementFrameWoodBorderBottomRight",
        "AchievementFrameHeaderLeft", "AchievementFrameHeaderRight",
        "AchievementFrameHeaderPointBorder", "AchievementFrameHeaderRightDDLInset",
    })
    -- The header frame hangs 67 above the window and would swallow clicks on the title band.
    local header = _G.AchievementFrameHeader
    if header then header:EnableMouse(false) end

    window:SetHeight(window:GetHeight() + ACH_TOOLBAR_H)
    local categories = _G.AchievementFrameCategories
    if categories then
        categories:ClearAllPoints()
        categories:SetPoint("TOPLEFT", window, "TOPLEFT", 21, ACH_CATEGORIES_TOP)
        categories:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 21, 20)
        categories:SetBackdrop(nil)
    end

    local title = _G.AchievementFrameHeaderTitle
    if title then title:SetText(_G.ACHIEVEMENTS or title:GetText()) end
    local host = skinWindow(window, {
        rect = ACH_RECT,
        hit = { ACH_RECT[1], -ACH_RECT[3], 0, ACH_RECT[4] },
        title = title,
        close = _G.AchievementFrameCloseButton,
    })

    -- Points and shield at the right of the band, clear of the close button.
    local shield, points = _G.AchievementFrameHeaderShield, _G.AchievementFrameHeaderPoints
    if shield and points then
        shield:ClearAllPoints()
        shield:SetPoint("RIGHT", host, "TOPRIGHT", -28, -11)
        points:ClearAllPoints()
        points:SetPoint("RIGHT", shield, "LEFT", -2, 1)
    end

    -- Every pane draws on the insets' grounds instead of its own paper and tooltip border.
    local list = _G.AchievementFrameAchievements
    stripPane(list)
    stripPane(_G.AchievementFrameSummary)
    stripPane(_G.AchievementFrameStats)
    hideNamed({ "AchievementFrameStatsBG" })
    local comparison = _G.AchievementFrameComparison
    stripPane(comparison, { AchievementFrameComparisonWatermark = true })

    -- The summary was 529 wide off the category list's edge and ran into the right rail; it now
    -- spans the achievement list plus that list's scroll-bar column.
    local summary = _G.AchievementFrameSummary
    if summary and list then
        summary:ClearAllPoints()
        summary:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
        summary:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", ACH_BAR_COLUMN, 0)
    end

    if categories then
        addInset(window, { -ACH_PAD, ACH_PAD, ACH_PAD, -ACH_PAD, topLeft = categories, bottomRight = categories })
    end
    if list then
        addInset(window, { -ACH_PAD, ACH_PAD, ACH_CONTENT_RIGHT, ACH_CONTENT_BOTTOM, topLeft = list })
    end

    for _, scroll in ipairs({
        "AchievementFrameCategoriesContainer", "AchievementFrameAchievementsContainer",
        "AchievementFrameStatsContainer", "AchievementFrameComparisonContainer",
        "AchievementFrameComparisonStatsContainer",
    }) do
        dressScrollBar(scroll, 1)
    end

    -- DragonUI's search panel covered the old content rect; it now covers the content inset.
    local search = addon.AchievementSearch
    if search and search.panel and list then
        search.panel:ClearAllPoints()
        search.panel:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
        search.panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT",
            ACH_CONTENT_RIGHT - ACH_PAD, ACH_CONTENT_BOTTOM + ACH_PAD)
    end
    placeAchievementToolbar(window)
    dressAchievementTabs(host)
    window:HookScript("OnShow", function() dressAchievementTabs(host) end)

    -- Comparison writes its own x offsets (38 wide, 80 back) on show and hide; the bronze window
    -- keeps the left edge every other DragonUI window uses.
    if comparison then
        local function reseat()
            nudgePanel(window, 6 - ACH_RECT[1], -ACH_RECT[2])
        end
        comparison:HookScript("OnShow", reseat)
        comparison:HookScript("OnHide", reseat)
    end
end

local BUILDERS = {
    { frame = "QuestLogFrame", build = buildQuestLog },
    { frame = "LFDParentFrame", build = buildLFD },
    { frame = "PVPParentFrame", build = buildPvP },
    { frame = "AchievementFrame", build = buildAchievements },
    { frame = "GameMenuFrame", build = buildGameMenu },
}

-- Built on first open, like the Social window; only the panel offsets would matter before that and
-- skinWindow sets them, so the first build also re-seats a window that is already up.
local function hookWindows()
    for _, entry in ipairs(BUILDERS) do
        local window = _G[entry.frame]
        if window and not window._duiStockShowHooked then
            window._duiStockShowHooked = true
            local function build()
                if not IsModuleEnabled() or window._duiStockSkinned then return end
                local ok, err = pcall(entry.build)
                if not ok and addon.Error then
                    addon:Error(entry.frame .. " skin failed: " .. tostring(err))
                end
            end
            window:HookScript("OnShow", build)
            if window:IsShown() then build() end
        end
    end
end

function addon.ApplyStockPanelsSystem()
    if not IsModuleEnabled() then return end
    StockPanels.initialized = true
    StockPanels.applied = true
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("stockpanels_apply", hookWindows)
        return
    end
    hookWindows()
end

function addon.RestoreStockPanelsSystem()
    StockPanels.applied = false
end

function addon.RefreshStockPanelsSystem()
    if IsModuleEnabled() then
        addon.ApplyStockPanelsSystem()
    else
        addon.RestoreStockPanelsSystem()
    end
end

-- The Achievement window is load-on-demand: hooked when Blizzard_AchievementUI loads.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        addon.ApplyStockPanelsSystem()
    elseif name == "Blizzard_AchievementUI" then
        self:UnregisterEvent("ADDON_LOADED")
        if StockPanels.initialized then addon.ApplyStockPanelsSystem() end
    end
end)
