-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CO = addon.Collections

-- The window shell; journal.lua fills the panes. PortraitFrameTemplate, not MetalFrameTemplate:
-- the latter pairs 32px corners with 75px side edges, so every edge meets its corner at a step.

local FRAME_NAME = "DragonUICollectionsFrame"
local FRAME_W, FRAME_H = 640, 480

local SIDE_PAD = 14
local LEFT_W = 244
local INSET_GAP = 16
local TITLE_H = 24
local TOP_H = 34
local BOTTOM_H = 30

-- The character panel's own band geometry, so the rock and streak strip line up with it.
local STREAK_Y, STREAK_H = 21, 43
local ROCK = addon._dir .. "UI\\ui-background-rock"

-- Measured off the corner atlas: the cutout is r22.75, the metal turns opaque by r29 and its outer
-- edge is r33. Our art is full bleed, so it needs r29 -- not the panel's 62, whose icons have padding.
local PORTRAIT_SIZE, PORTRAIT_X, PORTRAIT_Y = 58, -2, 6

local TABS = {
    { kind = "MOUNT", label = MOUNTS },
    { kind = "CRITTER", label = PETS },
}

local frame, title, portrait, tabsBuilt

-- Lazy: the character panel loads later in modules.xml, but nothing here runs before first open.
local function CP()
    return addon.CharacterPanel
end

local function buildChrome()
    local layout = NineSliceUtils and NineSliceUtils.GetLayout("PortraitFrameTemplate")
    if layout then NineSliceUtils.ApplyLayout(frame, layout) end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -STREAK_Y)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    local streaks = frame:CreateTexture(nil, "BORDER")
    streaks:set_atlas("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetHeight(STREAK_H)
    streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -STREAK_Y)
    streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -STREAK_Y)

    -- ARTWORK, under the OVERLAY corner piece whose cutout is the ring around it.
    portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -5)

    local close = CreateFrame("Button", FRAME_NAME .. "CloseButton", frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    if CP() and CP().ModernizeCloseButton then
        CP().ModernizeCloseButton(close, frame, 1, 0)
    end
end

local function buildInset(name)
    local inset = CreateFrame("Frame", name, frame)
    inset:SetFrameLevel(frame:GetFrameLevel() + 2)
    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints(inset)
    if CP() and CP().DrawPaneBorder then CP().DrawPaneBorder(inset, inset) end
    return inset
end

local function buildBand(name, level)
    local band = CreateFrame("Frame", name, frame)
    band:SetFrameLevel(frame:GetFrameLevel() + level)
    return band
end

-- The tab's own hover highlight, forced visible and animated: a companion learned into the tab you
-- are not looking at would otherwise announce itself nowhere.
local alertTabs = {}
local TAB_PULSE_SPEED = 5.5

local function tabLabel(tab)
    local name = tab.GetName and tab:GetName()
    return name and _G[name .. "Text"]
end

local function setTabAlert(tab, on)
    if not (tab and tab._duiHighlight) then return end
    local label = tabLabel(tab)
    if on then
        if tab._duiAlertAlpha then return end
        -- Saved, not reset to a literal: the resting alpha and colour live in tabs.lua, not here.
        tab._duiAlertAlpha = tab._duiHighlight[1]:GetAlpha() or 0
        if label then
            tab._duiAlertRest = { label:GetTextColor() }
            local hover = tab.GetHighlightFontObject and tab:GetHighlightFontObject()
            tab._duiAlertHover = hover and { hover:GetTextColor() } or { 1, 1, 1 }
        end
        tab:LockHighlight()
    else
        if not tab._duiAlertAlpha then return end
        tab:UnlockHighlight()
        for _, tex in ipairs(tab._duiHighlight) do tex:SetAlpha(tab._duiAlertAlpha) end
        if label and tab._duiAlertRest then label:SetTextColor(unpack(tab._duiAlertRest)) end
        tab._duiAlertAlpha, tab._duiAlertRest, tab._duiAlertHover = nil, nil, nil
    end
end

-- Highlight and label together: hovering a tab both lights it and whitens its text, and half of
-- that reads as a glitch rather than an alert.
local function pulseTabAlerts()
    local alpha, phase = CO.PulseAlpha(TAB_PULSE_SPEED)
    for i = 1, #alertTabs do
        local tab = alertTabs[i]
        for _, tex in ipairs(tab._duiHighlight) do
            tex:SetAlpha(alpha)
        end
        local label, rest, hover = tabLabel(tab), tab._duiAlertRest, tab._duiAlertHover
        if label and rest and hover then
            label:SetTextColor(rest[1] + (hover[1] - rest[1]) * phase,
                rest[2] + (hover[2] - rest[2]) * phase,
                rest[3] + (hover[3] - rest[3]) * phase)
        end
    end
end

function CO.RefreshTabAlerts()
    if not (frame and tabsBuilt) then return end
    wipe(alertTabs)
    for i, info in ipairs(TABS) do
        local tab = _G[FRAME_NAME .. "Tab" .. i]
        local alert = info.kind ~= CO.Kind and CO.HasNew and CO.HasNew(info.kind)
        setTabAlert(tab, alert)
        if alert and tab then alertTabs[#alertTabs + 1] = tab end
    end
    frame:SetScript("OnUpdate", #alertTabs > 0 and pulseTabAlerts or nil)
end

local function layoutTabs()
    local prev
    for i = 1, #TABS do
        local tab = _G[FRAME_NAME .. "Tab" .. i]
        if tab and tab:IsShown() then
            if CP() and CP().ReskinTab then CP().ReskinTab(tab) end
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
            else
                tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
            end
            prev = tab
        end
    end
end

local function buildTabs()
    if tabsBuilt then return end
    tabsBuilt = true

    for i, info in ipairs(TABS) do
        local tab = CreateFrame("Button", FRAME_NAME .. "Tab" .. i, frame, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(info.label)
        tab:SetScript("OnClick", function(self)
            CO.SelectKind(TABS[self:GetID()].kind)
            PlaySound("igCharacterInfoTab")
        end)
        -- How tabs.lua's PanelTemplates_TabResize hook re-chains this strip, not the character one.
        tab._duiRelayout = layoutTabs
    end

    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(frame, #TABS) end
    layoutTabs()
end

local function build()
    if frame then return frame end

    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    buildChrome()

    CO.TopBand = buildBand(FRAME_NAME .. "TopBand", 3)
    CO.TopBand:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_PAD, -(TITLE_H + 6))
    CO.TopBand:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SIDE_PAD, -(TITLE_H + 6))
    CO.TopBand:SetHeight(TOP_H)

    CO.LeftInset = buildInset(FRAME_NAME .. "LeftInset")
    CO.LeftInset:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_PAD, -(TITLE_H + TOP_H + 8))
    CO.LeftInset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDE_PAD, BOTTOM_H + 6)
    CO.LeftInset:SetWidth(LEFT_W)

    CO.RightInset = buildInset(FRAME_NAME .. "RightInset")
    CO.RightInset:SetPoint("TOPLEFT", CO.LeftInset, "TOPRIGHT", INSET_GAP, 0)
    CO.RightInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SIDE_PAD, BOTTOM_H + 6)

    CO.BottomBand = buildBand(FRAME_NAME .. "BottomBand", 3)
    CO.BottomBand:SetPoint("TOPLEFT", CO.LeftInset, "BOTTOMLEFT", 0, -2)
    CO.BottomBand:SetPoint("TOPRIGHT", CO.RightInset, "BOTTOMRIGHT", 0, -2)
    CO.BottomBand:SetHeight(BOTTOM_H)

    buildTabs()
    if CO.BuildJournal then CO.BuildJournal(frame) end

    frame:SetScript("OnShow", function()
        PlaySound("igCharacterInfoOpen")
        local btn = _G.CollectionsMicroButton
        if btn and btn.SetButtonState then btn:SetButtonState("PUSHED", true) end
        -- The learned-companion alert has served its purpose once the window is open.
        if btn and SetButtonPulse then SetButtonPulse(btn, 0, 1) end
        CO.SelectKind(CO.Kind or "MOUNT")
        -- No measurable pane width until the next layout pass; the first paint is otherwise empty.
        addon:After(0, function() if CO.RefreshJournal then CO.RefreshJournal() end end)
    end)
    frame:SetScript("OnHide", function()
        PlaySound("igCharacterInfoClose")
        local btn = _G.CollectionsMicroButton
        if btn and btn.SetButtonState then btn:SetButtonState("NORMAL") end
        -- Closing spends the pulse of whatever was on screen; anything never scrolled to keeps it.
        if CO.MarkShownSeen then CO.MarkShownSeen() end
    end)

    -- Escape closes it, the way every non-UIPanel Blizzard window is wired.
    tinsert(UISpecialFrames, FRAME_NAME)

    return frame
end

CO.Kind = "MOUNT"

function CO.SelectKind(kind)
    if not frame then return end
    CO.Kind = kind

    for i, info in ipairs(TABS) do
        if info.kind == kind then
            if PanelTemplates_SetTab then PanelTemplates_SetTab(frame, i) end
            title:SetText(info.label)
            portrait:SetTexture(kind == "MOUNT" and CO.TEX.mountPortrait or CO.TEX.petPortrait)
        end
    end
    layoutTabs()
    CO.RefreshTabAlerts()
    if CO.RefreshJournal then CO.RefreshJournal() end
end

function CO.Open(kind)
    if not CO:Enabled() then return end
    build()
    if kind then CO.Kind = kind end
    frame:Show()
end

function CO.Close()
    if frame then frame:Hide() end
end

function CO.IsShown()
    return frame ~= nil and frame:IsShown()
end

function CO.Toggle(kind)
    if frame and frame:IsShown() and (not kind or kind == CO.Kind) then
        CO.Close()
        return
    end
    CO.Open(kind)
end

addon.ToggleCollections = CO.Toggle
