local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's three sidebar tabs above the stats pane: character / titles / equipment manager. Drawn
-- from the stock Cata+ PaperDollSidebarTabs sheet (shipped here) at its own native texcoords.
local SHEET = addon._dir .. "CharacterPanel\\paperdollsidebartabs"

local STRIP_W, STRIP_H = 168, 35
local TAB_W, TAB_H = 33, 35
local TAB_GAP = 4
-- Leaves the right-hand decoration its own 28px.
local TAB_RIGHT_INSET = 30

local TC = {
    decorLeft = { 0.015625, 0.453125, 0.00390625, 0.046875 },
    decorRight = { 0.015625, 0.453125, 0.0546875, 0.10546875 },
    tabBg = { 0.015625, 0.796875, 0.61328125, 0.78125 },
    tabBgActive = { 0.015625, 0.796875, 0.7890625, 0.95703125 },
    tabHider = { 0.015625, 0.546875, 0.11328125, 0.1875 },
    tabHighlight = { 0.015625, 0.5, 0.1953125, 0.31640625 },
    titlesIcon = { 0.015625, 0.53125, 0.32421875, 0.4609375 },
    equipIcon = { 0.015625, 0.53125, 0.46875, 0.60546875 },
}

-- SetPortraitTexture hands back the full round portrait; crop into the face so the tab is filled.
local PORTRAIT_CROP = { 0.109375, 0.890625, 0.09375, 0.90625 }

local tabs, strip = {}, nil
local selected = 1

-- Retail drops the hider on the selected tab, but the strip is a CHILD of InsetRight and always
-- draws over it, so that overhang read as the tab sitting on the pane. Kept on every tab instead.
local function styleTab(tab, isSelected)
    if not tab then return end
    tab.Highlight:SetShownReq(not isSelected)
    tab.TabBg:SetTexCoord(unpack(isSelected and TC.tabBgActive or TC.tabBg))
end

local function selectTab(index)
    selected = index
    for i, tab in ipairs(tabs) do
        styleTab(tab, i == index)
    end
    if CP.ShowSidebarPane then CP.ShowSidebarPane(index) end
end

CP.SelectSidebarTab = selectTab
CP.SelectedSidebarTab = function() return selected end

function CP.RestyleSidebarTabs()
    for i, tab in ipairs(tabs) do
        styleTab(tab, i == selected)
    end
end

local function buildTab(index, tooltip)
    local tab = CreateFrame("Button", "DragonUICharacterSidebarTab" .. index, strip)
    tab:SetSize(TAB_W, TAB_H)

    -- The plate hangs past its button on purpose; that overhang is the shoulder meeting the next tab.
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(SHEET)
    bg:SetSize(50, 43)
    bg:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", -9, -2)
    bg:SetTexCoord(unpack(TC.tabBg))
    tab.TabBg = bg

    local icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Icon = icon

    -- Dropped to the PLATE's floor, not the button's: those 2px are the lip over the pane.
    local hider = tab:CreateTexture(nil, "OVERLAY")
    hider:SetTexture(SHEET)
    hider:SetSize(34, 19)
    hider:SetPoint("BOTTOM", tab, "BOTTOM", 0, -2)
    hider:SetTexCoord(unpack(TC.tabHider))
    tab.Hider = hider

    -- styleTab takes the HIGHLIGHT away from the selected tab, which already carries the lit plate.
    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(SHEET)
    hl:SetSize(31, 31)
    hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -3)
    hl:SetTexCoord(unpack(TC.tabHighlight))
    tab.Highlight = hl

    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip, 1, 1, 1)
        if not self:IsEnabled() and self._duiDisabledHint then
            GameTooltip:AddLine(self._duiDisabledHint, 1, 0.1, 0.1, true)
        end
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

    tab:SetScript("OnEnable", function(self)
        self:SetAlpha(1)
        self.Icon:SetDesaturated(false)
    end)
    tab:SetScript("OnDisable", function(self)
        self:SetAlpha(0.5)
        self.Icon:SetDesaturated(true)
    end)

    tab:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        selectTab(index)
    end)

    tabs[index] = tab
    return tab
end

local function setSheetIcon(tab, texCoord)
    tab.Icon:SetSize(TAB_W, TAB_H)
    tab.Icon:SetPoint("BOTTOM", tab, "BOTTOM", 1, -2)
    tab.Icon:SetTexture(SHEET)
    tab.Icon:SetTexCoord(unpack(texCoord))
end

local function refreshPortrait(tab)
    if not tab or not SetPortraitTexture then return end
    SetPortraitTexture(tab.Icon, "player")
    tab.Icon:SetTexCoord(unpack(PORTRAIT_CROP))
end

-- Inset from the tab so the plate's own border still shows around the face.
local function setPortraitIcon(tab)
    tab.Icon:SetSize(29, 31)
    tab.Icon:SetPoint("BOTTOM", tab, "BOTTOM", 1, 0)
    tab._duiPortrait = true
    refreshPortrait(tab)
end

-- IsTitleKnown returns a number on 3.3.5a, not a boolean.
local function hasAnyTitle()
    for i = 1, (GetNumTitles and GetNumTitles() or 0) do
        local known = IsTitleKnown(i)
        if known and known ~= 0 then return true end
    end
    return false
end

-- Nothing to pick means nothing to open, so the tab greys out rather than leading to an empty pane.
function CP.RefreshTitlesTabState()
    local tab = tabs[2]
    if not tab then return end
    -- SetEnabled is modern API; 3.3.5a has Enable/Disable.
    if hasAnyTitle() then tab:Enable() else tab:Disable() end
    if not hasAnyTitle() and selected == 2 then selectTab(1) end
end

function CP.RefreshSidebarTabPortrait()
    local tab = tabs[1]
    if tab and tab._duiPortrait then refreshPortrait(tab) end
end

-- The portrait comes back blank until the model streams in, so re-apply on Blizzard's own events.
local portraitEvents = CreateFrame("Frame")
portraitEvents:RegisterEvent("UNIT_PORTRAIT_UPDATE")
portraitEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
portraitEvents:RegisterEvent("KNOWN_TITLES_UPDATE")
portraitEvents:SetScript("OnEvent", function(_, event, unit)
    if event == "KNOWN_TITLES_UPDATE" then
        CP.RefreshTitlesTabState()
        return
    end
    if event == "UNIT_PORTRAIT_UPDATE" and unit ~= "player" then return end
    CP.RefreshSidebarTabPortrait()
    CP.RefreshTitlesTabState()
end)

local function build()
    local cf = _G.CharacterFrame
    if strip or not cf or not cf.InsetRight then return end

    -- Parented to the frame and levelled below InsetRight: a child can never draw behind its parent,
    -- so inside the pane every tab sat over the stats. It still anchors to InsetRight across parents.
    strip = CreateFrame("Frame", "DragonUICharacterSidebarTabs", cf)
    strip:SetSize(STRIP_W, STRIP_H)
    strip:SetPoint("BOTTOMRIGHT", cf.InsetRight, "TOPRIGHT", -6, -1)
    strip:SetFrameLevel(math.max(0, cf.InsetRight:GetFrameLevel() - 2))

    local decorLeft = strip:CreateTexture(nil, "ARTWORK")
    decorLeft:SetTexture(SHEET)
    decorLeft:SetSize(28, 11)
    decorLeft:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
    decorLeft:SetTexCoord(unpack(TC.decorLeft))

    local decorRight = strip:CreateTexture(nil, "ARTWORK")
    decorRight:SetTexture(SHEET)
    decorRight:SetSize(28, 13)
    decorRight:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    decorRight:SetTexCoord(unpack(TC.decorRight))

    -- Chained right to left, which is the order the plate shoulders were cut to overlap in.
    local tab3 = buildTab(3, EQUIPMENT_MANAGER)
    tab3:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -TAB_RIGHT_INSET, 0)
    setSheetIcon(tab3, TC.equipIcon)

    local tab2 = buildTab(2, PAPERDOLL_SELECT_TITLE)
    tab2:SetPoint("RIGHT", tab3, "LEFT", -TAB_GAP, 0)
    setSheetIcon(tab2, TC.titlesIcon)
    tab2._duiDisabledHint = addon.L["You have not earned any titles yet."]

    local tab1 = buildTab(1, CHARACTER)
    tab1:SetPoint("RIGHT", tab2, "LEFT", -TAB_GAP, 0)
    setPortraitIcon(tab1)

    -- Pinned equal and explicit: 50-wide plates on 33-wide tabs overlap, and with no level the order
    -- fell to creation order -- selecting a tab must not change where it sits in that stack.
    for _, tab in ipairs(tabs) do
        tab:SetFrameLevel(strip:GetFrameLevel() + 1)
    end

    selectTab(1)
    CP.RefreshTitlesTabState()
end

CP.SidebarTabsStrip = function() return strip end

-- The strip belongs to the paperdoll's right pane; elsewhere it would float over Blizzard's content.
function CP.SetSidebarTabsShown(visible)
    if strip then strip:SetShownReq(visible) end
end

CP:RegisterBuilder("sidebartabs", build)
