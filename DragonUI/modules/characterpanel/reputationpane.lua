local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The Reputation tab, rendered by us instead of ReputationFrame. GetFactionInfo puts isHeader at
-- position NINE, and expanding or collapsing renumbers the list, so it is rebuilt after each.

local ROW_H = 24
-- Retail's ReputationBarTemplate to the pixel: a 99x13 bar under a 60+39 frame that overhangs it by
-- a pixel top and bottom. UI-Character-ReputationBar is a 3.3.5a path, so the art needs no shipping.
local BAR_W, BAR_H = 99, 13
local FRAME_TEX = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar"
local FRAME_LEFT_W, FRAME_H = 60, 15
local DETAIL_FONT_SIZE = 11
local CHILD_INDENT = 12
-- Retail's own: a sub-header sits all but flush with a top-level one, because its ROW SHAPE is what
-- separates them, not how far it is pushed in.
local SUBHEADER_INDENT = 2
local TOGGLE_SIZE = 18
local FILL = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"

local pane, scroll, content
local headers, entries, subheaders
local flat = {}
-- Declared here because toggleHeader hands it to the reveal driver, and it is defined further down.
local repaint

-- Filtering by standing, not sorting: Blizzard already hands the list alphabetical inside each
-- header, so a name sort changed nothing visible. Labels are the client's own globals, already
-- translated in every locale. Kept in the profile so the choice survives a reload.
local STANDINGS = 8

local function standingLabel(id)
    return _G["FACTION_STANDING_LABEL" .. id] or tostring(id)
end

local function standingFilter() return CP:Config().rep_standing or 0 end

local filterButton

local function updateSelection()
    if not filterButton then return end
    local id = standingFilter()
    filterButton:SetSelection(id == 0 and addon.L["All"] or standingLabel(id))
end

local function filterMenuEntries()
    local entries = {}
    local function entry(text, id)
        entries[#entries + 1] = {
            text = text,
            checked = (standingFilter() == id),
            func = function()
                CP:Config().rep_standing = id
                updateSelection()
                CP.RefreshReputationPane()
            end,
        }
    end

    entry(addon.L["All"], 0)
    -- Descending: Exalted is what a player scans for, and it reads as the ladder they climb.
    for id = STANDINGS, 1, -1 do entry(standingLabel(id), id) end
    return entries
end

local function toggleHeader(index, collapsed)
    if collapsed then
        if ExpandFactionHeader then ExpandFactionHeader(index) end
        CP.RefreshReputationPane()
        -- After the refresh, so the run being revealed is read off the rebuilt list.
        CP.RevealChildrenOf(flat, index, repaint)
    else
        -- The rows are still live here; collapsing for real is what `finish` does.
        CP.FadeOutChildrenOf(flat, index, repaint, function()
            if CollapseFactionHeader then CollapseFactionHeader(index) end
            CP.RefreshReputationPane()
        end)
    end
end

-- Filled here rather than by ReputationFrame_Update: that only populates the detail frame for a
-- faction inside Blizzard's own displayed window, so anything past a screenful opened blank.
function CP.PopulateReputationDetail(index)
    local detail = _G.ReputationDetailFrame
    if not detail or not index then return end

    local name, description, _, _, _, _, atWarWith, canToggleAtWar,
          isHeader, _, _, isWatched = GetFactionInfo(index)

    _G.ReputationDetailFactionName:SetText(name or "")

    -- Re-asserted on every open: this is the only place the description's text is written, and it
    -- has to be bigger and dark for Blizzard's light parchment.
    local body = _G.ReputationDetailFactionDescription
    body:SetFontObject(GameFontHighlight)
    -- Face from the font object, size ours: the object has no size knob to turn.
    local face = body:GetFont()
    if face then body:SetFont(face, DETAIL_FONT_SIZE) end

    local color = CP.DETAIL_TEXT_COLOR or { 1, 1, 1 }
    body:SetTextColor(color[1], color[2], color[3])
    -- After SetFontObject: a font object carries its own shadow AND justification, and
    -- GameFontHighlight is centred, so alignment set at build time was thrown away here.
    body:SetShadowColor(0, 0, 0, 1)
    body:SetShadowOffset(1, -1)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText(description or "")
    -- The scroll child measures the string, so it can only be sized once the text is in.
    if CP.UpdateDetailScroll then CP.UpdateDetailScroll() end

    local atWar = _G.ReputationDetailAtWarCheckBox
    atWar:SetChecked(atWarWith and 1 or nil)
    local warColor = (canToggleAtWar and not isHeader) and RED_FONT_COLOR or GRAY_FONT_COLOR
    if canToggleAtWar and not isHeader then atWar:Enable() else atWar:Disable() end
    _G.ReputationDetailAtWarCheckBoxText:SetTextColor(warColor.r, warColor.g, warColor.b)

    local inactive = _G.ReputationDetailInactiveCheckBox
    if isHeader then inactive:Disable() else inactive:Enable() end
    inactive:SetChecked(IsFactionInactive(index) and 1 or nil)

    _G.ReputationDetailMainScreenCheckBox:SetChecked(isWatched and 1 or nil)
end

local function buildEntry(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    bar:SetStatusBarTexture(FILL)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    -- Pushed to BORDER so the outline below can sit above it without hiding the fill.
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetDrawLayer("BORDER") end

    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(bar)
    back:SetTexture(0, 0, 0)

    -- Retail's own two-piece frame, and its texcoords: the sheet is a 3.3.5a path the client already
    -- ships, so this is the real art rather than the hand-drawn outline it replaces.
    local left = bar:CreateTexture(nil, "OVERLAY")
    left:SetTexture(FRAME_TEX)
    left:SetSize(FRAME_LEFT_W, FRAME_H)
    left:SetPoint("LEFT", bar, "LEFT", 0, 0)
    left:SetTexCoord(0.765625, 1, 0.046875, 0.28125)

    local right = bar:CreateTexture(nil, "OVERLAY")
    right:SetTexture(FRAME_TEX)
    right:SetSize(BAR_W - FRAME_LEFT_W, FRAME_H)
    right:SetPoint("LEFT", left, "RIGHT", 0, 0)
    right:SetTexCoord(0, 0.15234375, 0.390625, 0.625)

    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    row.Bar = bar

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", row, "LEFT", CHILD_INDENT, 0)
    -- Bounded by the bar so a long faction name truncates instead of running under it.
    name:SetPoint("RIGHT", bar, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    row.Text = name

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(1, 1, 1)
    hl:SetAlpha(0.1)
    hl:SetAllPoints(row)

    -- Blizzard's ReputationBar_OnClick gates on a hasRep that is only true for headers carrying a
    -- bar, which left every ordinary faction inert. Every row here is already a faction.
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        local detail = _G.ReputationDetailFrame
        if not detail or not self._index then return end
        if detail:IsShown() and GetSelectedFaction() == self._index then
            detail:Hide()
        else
            SetSelectedFaction(self._index)
            detail:Show()
            CP.PopulateReputationDetail(self._index)
        end
    end)
    -- Hovering trades the standing label for the raw numbers, which is the only place they appear.
    row:SetScript("OnEnter", function(self) self.Bar.Text:SetText(self.Bar._progress or "") end)
    row:SetScript("OnLeave", function(self) self.Bar.Text:SetText(self.Bar._standing or "") end)
    return row
end

local function updateEntry(row, info)
    row.Text:SetText(info.name or "")
    row._index, row._hasRep = info.index, info.hasRep

    local bar = row.Bar
    local max = (info.barMax or 0) - (info.barMin or 0)
    local value = (info.barValue or 0) - (info.barMin or 0)
    if max <= 0 then max, value = 1, 0 end
    bar:SetMinMaxValues(0, max)
    bar:SetValue(value)

    local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[info.standingID or 4]
    if color then bar:SetStatusBarColor(color.r, color.g, color.b) end

    bar._standing = _G["FACTION_STANDING_LABEL" .. (info.standingID or 4)] or ""
    bar._progress = string.format("%d / %d", value, max)
    bar.Text:SetText(bar._standing)
end

-- ReputationSubHeaderTemplate inherits the ENTRY template, not the header one: a nested header is
-- an ordinary row carrying a collapse box, so it never wears the big bar its parent does.
local function buildSubHeader(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    local toggle = CreateFrame("Button", nil, row)
    toggle:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
    toggle:SetPoint("LEFT", row, "LEFT", CHILD_INDENT, 0)
    -- Seeded with any path purely so the texture objects exist; updateSubHeader atlases them.
    toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Up")
    toggle:GetNormalTexture():SetAllPoints(toggle)
    toggle:GetPushedTexture():SetAllPoints(toggle)
    toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    row.Toggle = toggle

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    name:SetJustifyH("LEFT")
    row.Text = name

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(1, 1, 1)
    hl:SetAlpha(0.1)
    hl:SetAllPoints(row)

    -- The box and the row do the same thing, so the box just forwards to the row that owns it.
    local function click(self)
        local owner = self._row or self
        if owner._index then toggleHeader(owner._index, owner._collapsed) end
    end
    toggle._row = row
    toggle:SetScript("OnClick", click)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", click)
    return row
end

local function updateSubHeader(row, info)
    row._index, row._collapsed = info.index, info.isCollapsed
    row.Text:SetText(info.name or "")
    local state = info.isCollapsed and "closed" or "open"
    row.Toggle:GetNormalTexture():set_atlas("campaign_headericon_" .. state)
    row.Toggle:GetPushedTexture():set_atlas("campaign_headericon_" .. state .. "pressed")
end

repaint = function()
    if not (scroll and content) then return end
    CP.PaintListRows(scroll, content, flat, ROW_H, { headers, entries, subheaders }, function(data)
        if data.kind == "header" then
            if data.isChild then
                local row = subheaders:acquire()
                updateSubHeader(row, data)
                return row, SUBHEADER_INDENT
            end
            local row = headers:acquire()
            CP.UpdateListHeader(row, data.name, data.index, data.isCollapsed)
            return row, 0
        end
        local row = entries:acquire()
        updateEntry(row, data)
        return row, data.isChild and CHILD_INDENT or 0
    end)
end

local function refresh()
    if not pane or not pane:IsShown() then return end

    local wanted = standingFilter()

    flat = {}
    for i = 1, (GetNumFactions and GetNumFactions() or 0) do
        local name, _, standingID, barMin, barMax, barValue,
              _, _, isHeader, isCollapsed, hasRep, _, isChild = GetFactionInfo(i)
        -- Headers stay through the filter: dropping one strands the factions under it with no way back.
        local hidden = wanted ~= 0 and not isHeader and standingID ~= wanted
        if name and not hidden then
            flat[#flat + 1] = {
                kind = isHeader and "header" or "entry",
                index = i, name = name, standingID = standingID,
                barMin = barMin, barMax = barMax, barValue = barValue,
                isCollapsed = isCollapsed, isChild = isChild, hasRep = hasRep,
            }
        end
    end

    -- Repeated because headers nest: emptying an inner one can leave its parent empty in turn.
    local pruning = wanted ~= 0
    while pruning do
        local kept = {}
        for i = 1, #flat do
            local row, nextRow = flat[i], flat[i + 1]
            -- An expanded header whose whole run got filtered out is just noise; a collapsed one
            -- may still hide matches, so it stays clickable.
            local empty = row.kind == "header" and not row.isCollapsed and not row.hasRep
                and (not nextRow or nextRow.kind == "header")
            if not empty then kept[#kept + 1] = row end
        end
        pruning = #kept < #flat
        flat = kept
    end

    repaint()
end

CP.RefreshReputationPane = refresh

-- Blizzard's faction bars are child FRAMES, so chrome.lua's texture sweep never reaches them. Show
-- is redirected the same way, because the stock code re-shows them on every tab switch.
local function suppressBlizzard(frame)
    if not frame or frame._duiSuppressed then return end
    frame._duiSuppressed = true

    for _, child in ipairs({ frame:GetChildren() }) do
        -- The detail popup stays live: it is the only way to watch a faction.
        if child ~= _G.ReputationDetailFrame then
            child:Hide()
            child.Show = child.Hide
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:Hide()
            region.Show = region.Hide
        end
    end
end

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.Inset then return end

    pane = CreateFrame("Frame", "DragonUIReputationPane", cf.Inset)
    pane:SetAllPoints(cf.Inset)
    pane:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 5)
    pane:Hide()

    -- Centred in the title strip, on the same right edge as the paperdoll tab's cog.
    if CP.CreateFilterDropdown then
        local cf = _G.CharacterFrame
        filterButton = CP.CreateFilterDropdown(pane, "DragonUIReputationFilter", CP.FILTER_DROPDOWN_W, filterMenuEntries)
        filterButton:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 20)
        CP.AnchorFilterDropdown(pane, filterButton)
        updateSelection()
    end

    scroll, content = CP.BuildListPane(pane, "DragonUIReputationScroll", ROW_H, repaint)
    headers = CP.NewRowPool(content, function(parent)
        return CP.BuildListHeader(parent, toggleHeader)
    end)
    entries = CP.NewRowPool(content, buildEntry)
    subheaders = CP.NewRowPool(content, buildSubHeader)
    CP.PrewarmRowPools(scroll, ROW_H, { headers, entries, subheaders })

    CP.WireListPaneShow(pane, refresh)
    scroll:HookScript("OnSizeChanged", repaint)

    -- Geometry and skin belong to reputationdetail.lua; this only keeps its contents current.
    local detail = _G.ReputationDetailFrame
    if detail then
        detail:HookScript("OnShow", function()
            CP.PopulateReputationDetail(GetSelectedFaction())
        end)
    end

    local blizzard = _G.ReputationFrame
    if blizzard then
        suppressBlizzard(blizzard)
        blizzard:HookScript("OnShow", function()
            suppressBlizzard(blizzard)
            pane:Show()
        end)
        blizzard:HookScript("OnHide", function() pane:Hide() end)
        if blizzard:IsShown() then pane:Show() end
    end
end

CP.ReputationPane = function() return pane end

local events = CreateFrame("Frame")
events:RegisterEvent("UPDATE_FACTION")
events:SetScript("OnEvent", refresh)

CP:RegisterBuilder("reputationpane", build)
