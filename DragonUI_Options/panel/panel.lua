-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - Main Frame
================================================================================
Forever-style settings window: metal frame, category list on the left, header with
title and divider, AceGUI scroll on the right. Individual controls still use AceGUI
widgets (skinned by controls.lua).
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO

local AceGUI = LibStub("AceGUI-3.0")

local FUI = addon.ForeverUI

-- ============================================================================
-- PANEL MODULE
-- ============================================================================

local Panel = {}
addon.OptionsPanel = Panel

Panel.frame      = nil    -- window frame
Panel.tabs       = {}     -- { key = { text, builder, order } }
Panel.tabOrder   = {}     -- ordered keys
Panel.tabButtons = {}     -- category list buttons
Panel.groupHeaders = {}   -- category list banners after the first
Panel.currentTab = nil
Panel.scrollWidget = nil  -- current AceGUI ScrollFrame inside content

-- Search navigation sub-tab setters (tabKey -> function(subTabKey)).
Panel.subTabSetters = Panel.subTabSetters or {}

-- ============================================================================
-- LAYOUT
-- ============================================================================

local WINDOW_WIDTH      = 920
local WINDOW_HEIGHT     = 700
local WINDOW_MIN_WIDTH  = 760
local WINDOW_MIN_HEIGHT = 520
local WINDOW_MAX_WIDTH  = 1400
local WINDOW_MAX_HEIGHT = 900

-- The inner frame art draws its list divider at a fixed 197 from the left edge.
local LIST_WIDTH       = 197
local LIST_GAP         = 16
local LIST_MARGIN_TOP  = 12
local LIST_HEADER_H    = 30
local ROW_X            = 7
local ROW_WIDTH        = 183
local ROW_HEIGHT       = 20
local GROUP_GAP        = 12
-- Row text starts where the "DragonUI" header text does (header label x 20 minus ROW_X).
local ROW_LABEL_INSET  = 13

local INSET_SIDE       = 17
local INSET_VERTICAL   = 106
local CONTAINER_RIGHT  = 5
local HEADER_HEIGHT    = 50
local SCROLL_MARGIN    = 6

-- Content width the AceGUI flow layout gets: container minus the margins and its own scroll bar.
local SCROLL_CONTENT_OFFSET = 32

local FOOTER_LEFT        = 22
local FOOTER_RIGHT       = 16
local FOOTER_GAP         = 6
local FOOTER_BUTTON_W    = 110
local FOOTER_BUTTON_PAD  = 28
local FOOTER_BUTTON_MAX  = 190
local CLOSE_BUTTON_W     = 96
local FOOTER_TEXT_MARGIN = 14

local function PanelControls()
    return addon.PanelControls
end

local function GetVersion()
    return addon.RELEASE_VERSION or "2.5"
end

local function GetTitle()
    return LO["DragonUI"] .. " |cffffffff" .. GetVersion() .. "|r"
end

-- ============================================================================
-- TAB REGISTRATION
-- ============================================================================

function Panel:RegisterTab(key, text, builder, order)
    self.tabs[key] = {
        text    = text,
        value   = key,
        builder = builder,
        order   = order or 999,
    }
    self.tabOrder = {}
    for k in pairs(self.tabs) do
        table.insert(self.tabOrder, k)
    end
    table.sort(self.tabOrder, function(a, b)
        return (self.tabs[a].order or 999) < (self.tabs[b].order or 999)
    end)
    self.searchIndex = nil  -- mark dirty; rebuilt on next search
end

-- ============================================================================
-- CONTENT SIZING
-- ============================================================================

-- GetWidth can read 0 before the first layout pass, so fall back to the geometry we anchored.
function Panel:GetScrollContentWidth()
    local frame = self.frame
    local width = frame and frame.content and frame.content:GetWidth()
    if not width or width <= 0 then
        local windowWidth = (frame and frame:GetWidth()) or WINDOW_WIDTH
        width = windowWidth - 2 * INSET_SIDE - (1 + LIST_WIDTH) - LIST_GAP - CONTAINER_RIGHT
    end
    return width - SCROLL_CONTENT_OFFSET
end

function Panel:RefreshContentSize()
    if self.scrollWidget then
        self.scrollWidget.content:SetWidth(self:GetScrollContentWidth())
        self.scrollWidget:DoLayout()
    end
end

-- AceGUI builds frames under UIParent and reparents them, so strata and level must be re-asserted after a build.
function Panel:EnforceLayers()
    if self.frame then
        FUI.EnforceLayering(self.frame)
    end
end

function Panel:SetHeaderTitle(text)
    local frame = self.frame
    if frame and frame.headerTitle then
        frame.headerTitle:SetText(text or "")
    end
end

local function LayoutFooter()
    local frame = Panel.frame
    if not (frame and frame.commandsText) then return end
    local text = frame.commandsText
    text:SetText(frame.commandsFull)
    local PC = PanelControls()
    if not PC then return end
    local used = frame.footerLeftWidth + FOOTER_RIGHT + CLOSE_BUTTON_W + 2 * FOOTER_TEXT_MARGIN
    PC.ClampText(text, (frame:GetWidth() or WINDOW_WIDTH) - used)
end

-- ============================================================================
-- CREATE FRAME
-- ============================================================================

local function FitFooterButton(button)
    local PC = PanelControls()
    local fontString = button:GetFontString()
    if PC and fontString then
        button:SetWidth(PC.FitWidth(fontString, FOOTER_BUTTON_W, FOOTER_BUTTON_PAD, FOOTER_BUTTON_MAX))
    end
end

local function CreateSearchBox(f, container)
    local searchBox = FUI.CreateSearchBox(f, 350, LO["Search settings..."])
    searchBox:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 4, 20)
    searchBox:SetMaxLetters(64)
    searchBox:SetFrameLevel(f:GetFrameLevel() + 5)

    searchBox:SetScript("OnTextChanged", function(self)
        Panel:QueueLiveSearch(self:GetText())
    end)

    searchBox:SetScript("OnEnterPressed", function(self)
        if Panel._suppressSearch then return end
        if Panel.searchDebounce then Panel.searchDebounce:Hide() end
        Panel._queuedText = Panel:NormalizeSearchQuery(self:GetText())
        Panel:RunSearchQuery(self:GetText())
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        Panel._suppressSearch = true
        self:SetText("")
        self:ClearFocus()
        Panel._suppressSearch = false
        Panel._pendingQuery = ""
        Panel._lastRenderedQuery = nil
        if Panel.searchDebounce then Panel.searchDebounce:Hide() end
        if Panel.currentTab then
            Panel:SelectTab(Panel.currentTab)
        end
    end)

    searchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(LO["Type to find a setting"], 1, 1, 1)
        GameTooltip:Show()
    end)
    searchBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return searchBox
end

local function CreateFooter(f)
    local closeButton = FUI.CreateButton(f, CLOSE, CLOSE_BUTTON_W, 22)
    closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -FOOTER_RIGHT, 16)
    closeButton:SetScript("OnClick", function()
        PlaySound("igMainMenuClose")
        Panel:Close()
    end)
    f.closeButton = closeButton

    local editorButton = FUI.CreateButton(f, LO["Editor Mode"], FOOTER_BUTTON_W, 22)
    editorButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", FOOTER_LEFT, 16)
    FitFooterButton(editorButton)
    editorButton:SetScript("OnClick", function()
        Panel:Close()
        if addon.EditorMode then addon.EditorMode:Toggle() end
    end)
    f.editorButton = editorButton

    local keybindButton = FUI.CreateButton(f, LO["KeyBind Mode"], FOOTER_BUTTON_W, 22)
    keybindButton:SetPoint("LEFT", editorButton, "RIGHT", FOOTER_GAP, 0)
    FitFooterButton(keybindButton)
    keybindButton:SetScript("OnClick", function()
        Panel:Close()
        if addon.KeyBindingModule and LibStub and LibStub("LibKeyBound-1.0", true) then
            LibStub("LibKeyBound-1.0"):Toggle()
        end
    end)
    f.keybindButton = keybindButton

    f.footerLeftWidth = FOOTER_LEFT + editorButton:GetWidth() + FOOTER_GAP + keybindButton:GetWidth()

    local commands = f:CreateFontString(nil, "ARTWORK")
    commands:SetFontObject(GameFontDisableSmall)
    commands:SetJustifyH("LEFT")
    commands:SetPoint("LEFT", keybindButton, "RIGHT", FOOTER_TEXT_MARGIN, 0)
    f.commandsText = commands
    f.commandsFull = LO["Commands: /dragonui, /dui, /pi — /dragonui edit (editor) — /dragonui help"]
end

local function CreateResizeGrip(f)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(f:GetFrameLevel() + 12)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        Panel:RefreshContentSize()
    end)
    return grip
end

local function CreatePanel()
    local height = math.min(WINDOW_HEIGHT, math.max(WINDOW_MIN_HEIGHT, math.floor((UIParent:GetHeight() or WINDOW_HEIGHT) - 40)))

    local f = FUI.CreateWindow("DragonUIOptionsPanel", UIParent, {
        width    = WINDOW_WIDTH,
        height   = height,
        title    = GetTitle(),
        inset    = true,
        strata   = "DIALOG",
        movable  = true,
        escClose = true,
        onClose  = function() Panel:Close() end,
    })
    f:SetPoint("CENTER")
    f:SetResizable(true)
    f:SetMinResize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)
    f:SetMaxResize(WINDOW_MAX_WIDTH, WINDOW_MAX_HEIGHT)

    local inset = f.Inset

    local list = CreateFrame("Frame", nil, inset)
    list:SetPoint("TOPLEFT", inset, "TOPLEFT", 1, -LIST_MARGIN_TOP)
    list:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 1, LIST_MARGIN_TOP)
    list:SetWidth(LIST_WIDTH)
    f.tabStrip = list

    local header = FUI.CreateCategoryHeader(list)
    header:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    header:SetIndex(1)
    header:SetLabel(LO["DragonUI"])
    f.listHeader = header

    local content = CreateFrame("Frame", nil, inset)
    content:SetPoint("TOPLEFT", list, "TOPRIGHT", LIST_GAP, 0)
    content:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -CONTAINER_RIGHT, LIST_MARGIN_TOP)
    f.content = content

    local headerTitle = content:CreateFontString(nil, "ARTWORK")
    headerTitle:SetFontObject(FUI.Fonts.HighlightHuge)
    headerTitle:SetJustifyH("LEFT")
    headerTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 7, -22)
    headerTitle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -7, -22)
    f.headerTitle = headerTitle

    local divider = FUI.CreateDivider(content)
    divider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -HEADER_HEIGHT)
    divider:SetHeight(1)

    local searchBox = CreateSearchBox(f, content)
    f.searchBox         = searchBox
    f.searchPlaceholder = searchBox.hint

    -- Backup for the typed-text event: a 0.15 s text check that exists only while the box has focus.
    local poll = CreateFrame("Frame", nil, f)
    poll.idle = 0
    poll:Hide()
    poll:SetScript("OnUpdate", function(self, elapsed)
        self.idle = self.idle + elapsed
        if self.idle < 0.15 then return end
        self.idle = 0
        Panel:QueueLiveSearch(searchBox:GetText())
    end)
    searchBox:HookScript("OnEditFocusGained", function(self)
        Panel._queuedText = Panel:NormalizeSearchQuery(self:GetText())
        poll.idle = 0
        poll:Show()
    end)
    searchBox:HookScript("OnEditFocusLost", function() poll:Hide() end)
    searchBox:HookScript("OnHide", function() poll:Hide() end)

    CreateFooter(f)
    CreateResizeGrip(f)

    f:SetScript("OnSizeChanged", function()
        Panel:RefreshContentSize()
        LayoutFooter()
    end)

    return f
end

-- ============================================================================
-- BUILD TAB BUTTONS (category list)
-- ============================================================================

local function ShowTabTooltip(self)
    if self.fullText and self.Label:GetText() ~= self.fullText then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.fullText, 1, 1, 1)
        GameTooltip:Show()
    end
end

local function HideTabTooltip()
    GameTooltip:Hide()
end

-- Banners of the category list; a tab missing here is listed at the end of the last section.
local TAB_GROUPS = {
    { label = "Core", tabs = { "general", "modules", "enhancements", "profiles" } },
    { label = "Frames", tabs = { "unitframes", "nameplates", "auras" } },
    { label = "Bars", tabs = { "actionbars", "additionalbars", "xprepbars", "castbars" } },
    { label = "Interface", tabs = { "minimap", "questtracker", "chat", "micromenu", "bags", "panels" } },
}

local function GroupedTabs()
    local placed, groups = {}, {}
    for _, group in ipairs(TAB_GROUPS) do
        local keys = {}
        for _, key in ipairs(group.tabs) do
            if Panel.tabs[key] then
                keys[#keys + 1] = key
                placed[key] = true
            end
        end
        if #keys > 0 then
            groups[#groups + 1] = { label = group.label, keys = keys }
        end
    end
    local last = groups[#groups]
    if not last then
        last = { label = TAB_GROUPS[1].label, keys = {} }
        groups[1] = last
    end
    for _, key in ipairs(Panel.tabOrder) do
        if not placed[key] then
            table.insert(last.keys, key)
        end
    end
    return groups
end

local function BuildTabButtons()
    -- Clear old
    for _, btn in pairs(Panel.tabButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(Panel.tabButtons)
    for _, header in ipairs(Panel.groupHeaders) do
        header:Hide()
        header:SetParent(nil)
    end
    wipe(Panel.groupHeaders)

    local frame = Panel.frame
    local list = frame.tabStrip
    local PC = PanelControls()
    local y = 0

    for index, group in ipairs(GroupedTabs()) do
        local header = frame.listHeader
        if index > 1 then
            header = FUI.CreateCategoryHeader(list)
            Panel.groupHeaders[#Panel.groupHeaders + 1] = header
        end
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
        header:SetIndex(index)
        header:SetLabel(LO[group.label])
        header:Show()
        y = y - (LIST_HEADER_H + 4)

        for _, key in ipairs(group.keys) do
            local tabInfo = Panel.tabs[key]
            local btn = FUI.CreateCategoryButton(list)
            btn:SetSize(ROW_WIDTH, ROW_HEIGHT)
            btn:SetPoint("TOPLEFT", list, "TOPLEFT", ROW_X, y)
            btn:SetLabelLeft(ROW_LABEL_INSET)
            btn:SetText(tabInfo.text)
            btn.fullText = tabInfo.text
            btn.tabKey = key
            if PC then
                PC.ClampText(btn.Label, ROW_WIDTH - ROW_LABEL_INSET - 6)
            end

            btn:SetScript("OnClick", function(self)
                if Panel.currentTab ~= self.tabKey then
                    PlaySound("igMainMenuOptionCheckBoxOn")
                end
                Panel:SelectTab(self.tabKey)
            end)
            btn:HookScript("OnEnter", ShowTabTooltip)
            btn:HookScript("OnLeave", HideTabTooltip)

            Panel.tabButtons[key] = btn
            y = y - ROW_HEIGHT
        end
        y = y - GROUP_GAP
    end

    -- Every category must stay reachable: the list has no scroll of its own.
    local needed = INSET_VERTICAL + 2 * LIST_MARGIN_TOP - (y + GROUP_GAP)
    local minHeight = math.max(WINDOW_MIN_HEIGHT, needed)
    frame:SetMinResize(WINDOW_MIN_WIDTH, minHeight)
    if frame:GetHeight() < minHeight then
        frame:SetHeight(minHeight)
    end
end

-- ============================================================================
-- UPDATE TAB VISUALS
-- ============================================================================

local function UpdateTabVisuals()
    for key, btn in pairs(Panel.tabButtons) do
        btn:SetSelected(key == Panel.currentTab)
    end
    local info = Panel.currentTab and Panel.tabs[Panel.currentTab]
    Panel:SetHeaderTitle(info and info.text or "")
end

-- ============================================================================
-- SELECT TAB
-- ============================================================================

function Panel:SelectTab(key, highlight)
    if not self.tabs[key] then return end

    -- Re-selecting the current tab is a rebuild (a toggle refreshing disabled
    -- states), so keep the reading position instead of jumping to the top.
    local savedOffset
    if self.currentTab == key and not highlight and self.scrollWidget then
        local status = self.scrollWidget.status or self.scrollWidget.localstatus
        savedOffset = status and status.offset
    end

    self.currentTab = key
    UpdateTabVisuals()

    self._lastRenderedQuery = nil

    if self.CancelHighlight then self:CancelHighlight() end

    if highlight then
        self._searchNavInProgress = true
    end

    -- Clear search box when opening a result.
    if highlight and self.frame and self.frame.searchBox then
        self._suppressSearch = true
        self.frame.searchBox:SetText("")
        self.frame.searchBox:ClearFocus()
        self._suppressSearch = false
        self._pendingQuery = nil
        if self.searchDebounce then
            self.searchDebounce:Hide()
            self.searchDebounce.elapsed = 0
        end
    end

    -- Activate sub-tab before the tab builder runs.
    if highlight and highlight.subTab and self.subTabSetters[key] then
        self.subTabSetters[key](highlight.subTab)
    end

    -- Release old scroll widget if any
    if self.scrollWidget then
        local C = addon.PanelControls
        if C and C.ClearSearchFontTags then
            C:ClearSearchFontTags(self.scrollWidget)
        end
        self.scrollWidget:ReleaseChildren()
        AceGUI:Release(self.scrollWidget)
        self.scrollWidget = nil
    end

    -- Create AceGUI scroll inside the content frame
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")

    -- Attach the AceGUI scroll frame to our content area
    local sf = scroll.frame
    sf:SetParent(self.frame.content)
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", SCROLL_MARGIN, -(HEADER_HEIGHT + SCROLL_MARGIN))
    sf:SetPoint("BOTTOMRIGHT", self.frame.content, "BOTTOMRIGHT", -SCROLL_MARGIN, 4)
    sf:SetFrameStrata("DIALOG")
    sf:Show()
    FUI.SkinScrollBar(scroll)

    -- Fix content area sizing
    scroll.content:SetWidth(self:GetScrollContentWidth())

    self.scrollWidget = scroll

    -- Call the tab builder
    local tabInfo = self.tabs[key]
    if tabInfo and tabInfo.builder then
        local ok, err = pcall(tabInfo.builder, scroll)
        if not ok then
            local errLabel = AceGUI:Create("Label")
            errLabel:SetText("|cFFFF0000" .. LO["Error:"] .. "|r " .. tostring(err))
            errLabel:SetFullWidth(true)
            scroll:AddChild(errLabel)
        end
    end

    -- DoLayout is synchronous; scroll/highlight can run immediately after.
    scroll:DoLayout()
    self:EnforceLayers()

    if savedOffset and savedOffset ~= 0 then
        local status = scroll.status or scroll.localstatus
        if status then
            -- FixScroll derives the scrollbar value from status.offset
            status.offset = savedOffset
            scroll:FixScroll()
        end
    end

    if highlight and self.HighlightSearchTarget then
        self:HighlightSearchTarget(scroll, highlight)
    end

    -- AceGUI recycles widgets, so dress them again once the layout has settled.
    if not Panel.reskinFrame then
        Panel.reskinFrame = CreateFrame("Frame")
        Panel.reskinFrame:Hide()
        Panel.reskinFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 0.15 then
                self:Hide()
                local skipReskin = Panel._searchNavigationUntil and GetTime() < Panel._searchNavigationUntil
                if skipReskin then
                    return
                end
                local C = addon.PanelControls
                if Panel.scrollWidget and C and C.ReskinAll then
                    C:ReskinAll(Panel.scrollWidget)
                end
            end
        end)
    end
    Panel.reskinFrame.elapsed = 0
    Panel.reskinFrame:Show()
end

-- ============================================================================
-- OPEN / CLOSE / TOGGLE
-- ============================================================================

function Panel:Open(selectTab)
    if InCombatLockdown() then
        addon:Error(LO["Cannot open options during combat."])
        return
    end

    if not self.frame then
        self.frame = CreatePanel()
        BuildTabButtons()
        LayoutFooter()
    end

    self.frame:SetFrameLevel(100)
    self.frame:Show()

    local tab = selectTab or self.currentTab or (self.tabOrder[1] or nil)
    if tab then
        self:SelectTab(tab)
    end
end

function Panel:Close()
    if self.frame then
        if self.CancelHighlight then
            self:CancelHighlight()
        end
        -- Release the scroll widget properly
        if self.scrollWidget then
            local C = addon.PanelControls
            if C and C.ClearSearchFontTags then
                C:ClearSearchFontTags(self.scrollWidget)
            end
            self.scrollWidget:ReleaseChildren()
            AceGUI:Release(self.scrollWidget)
            self.scrollWidget = nil
        end
        -- Reset search box on close.
        if self.frame.searchBox then
            self._suppressSearch = true
            self.frame.searchBox:SetText("")
            self.frame.searchBox:ClearFocus()
            self._suppressSearch = false
        end
        self._pendingQuery       = nil
        self._lastRenderedQuery  = nil
        if self.searchDebounce then self.searchDebounce:Hide() end
        self.frame:Hide()
    end
end

function Panel:Toggle(selectTab)
    if self.frame and self.frame:IsShown() then
        self:Close()
    else
        self:Open(selectTab)
    end
end

function Panel:IsOpen()
    return self.frame and self.frame:IsShown()
end

-- Popups the panel opens must stay above its FULLSCREEN_DIALOG-strata AceGUI frames.
hooksecurefunc("StaticPopup_Show", function()
    if not Panel:IsOpen() then return end
    for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() then
            popup:SetFrameStrata("FULLSCREEN_DIALOG")
            popup:Raise()
        end
    end
end)
