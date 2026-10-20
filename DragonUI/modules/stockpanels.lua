-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local type = type
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UpdateUIPanelPositions = UpdateUIPanelPositions

-- The stock windows DragonUI has no window of its own for: Quest Log, Dungeon Finder, PvP and the
-- Game Menu. Like social_skin.lua this is a reskin, not a rebuild: each keeps its stock size and
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
        localized("Retail-style quest log, dungeon finder, PvP and game menu chrome"),
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
local function addInset(window, bounds, parchment)
    local inset = CreateFrame("Frame", nil, window)
    inset:EnableMouse(false)
    inset:SetPoint("TOPLEFT", window, "TOPLEFT", bounds[1], bounds[2])
    inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", bounds[3], bounds[4])

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

-- List: QuestLogScrollFrame at 19,-75 (305x335) plus its hybrid bar's 16px on the right.
local QUEST_LIST_INSET = { 14, -70, -340, 37 }
-- Details: QuestLogDetailScrollFrame hangs TOPRIGHT -32,-77 (298x333), its bar 8 right of that.
-- Parchment, not marble: QuestInfo writes its text in the dark ink of the stock paper pane.
local QUEST_DETAIL_INSET = { 349, -70, -8, 37, parchment = true }

-- The bottom row lines up under the insets' outer edges and sits the seat's height above the rail
-- (stock it hung 13 in from the left and 1.5 off the right rail). The control panel is 26 tall with
-- its 21 buttons centred 1 high, so it sits 3.5 under their bottom edge.
local QUEST_ROW_BOTTOM = 2 + addon.WindowSeat.buttonBottom
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

-- Under the random/specific panes, from just below the Type dropdown to 3 above the bottom buttons,
-- which keep the seat's gap inside the rails (nineslice.lua).
local function lfdInsetBottom()
    local seat = addon.WindowSeat
    return LFD_RECT[4] + seat.buttonBottom + LFD_BUTTON_H + seat.gap
end
-- Random's scroll frame is 298x253 at BOTTOMRIGHT -34,30: it keeps its top and ends on the inset.
local LFD_RANDOM_SCROLL = { right = -34, top = 283 + 30 }

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
        close = _G.LFDParentFrameCloseButton,
    })
    local insetBottom = lfdInsetBottom()
    local inset = addInset(window, { 16, -152, -10, insetBottom })
    local scroll = _G.LFDQueueFrameRandomScrollFrame
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", LFD_RANDOM_SCROLL.right, insetBottom)
        scroll:SetHeight(LFD_RANDOM_SCROLL.top - insetBottom)
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
    -- The cooldown and backfill covers take mouse input and ended where the buttons began; on the
    -- inset they cover the panes without reaching the raised buttons.
    for _, name in ipairs({ "LFDQueueFrameCooldownFrame", "LFDQueueFramePartyBackfill" }) do
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

local BUILDERS = {
    { frame = "QuestLogFrame", build = buildQuestLog },
    { frame = "LFDParentFrame", build = buildLFD },
    { frame = "PVPParentFrame", build = buildPvP },
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

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    addon.ApplyStockPanelsSystem()
end)
