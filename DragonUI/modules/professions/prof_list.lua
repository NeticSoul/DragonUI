-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local L = addon.L
local Art, Model, F = P.Art, P.Model, P.Filters
local List = { offset = 0, rows = {}, data = {} }
P.List = List

local ROW_H, HEADER_H = 20, 25
local LIST_W, LIST_H = 304, 517
local AREA_X, AREA_TOP, AREA_BOTTOM = 8, 35, 5
local ROW_W = LIST_W - AREA_X - 20
local ROOM = LIST_H - AREA_TOP - AREA_BOTTOM
local WHEEL_STEP = 3
-- ProfessionsRecipeListMixin's tree view: indent, edge padding, spacing, and the padding round a group's recipes.
local INDENT, SPACING, PAD_EDGE, GROUP_TOP, GROUP_BOTTOM = 10, 1, 5, 1, 10
local RECIPE_W = ROW_W - INDENT
local RECIPE_COLOR = { 0.886, 0.863, 0.839 }
local SKILL_UP = {
    optimal = { "skill-high", 1, "Guaranteed chance of gaining %d skill ups" },
    medium = { "skill-medium", 0, "High chance of gaining skill" },
    easy = { "skill-low", 0, "Low chance of gaining skill" },
}

local function rowHeight(row)
    return (row.pad or (row.header and HEADER_H or ROW_H)) + SPACING
end

-- Offset (items skipped) at which the last item just fits: rows have several heights, so it is not N - visible.
local function maxOffset(data)
    local h = 0
    for i = #data, 1, -1 do
        h = h + rowHeight(data[i])
        if h > ROOM then return i end
    end
    return 0
end

local function copyAsFavorite(row)
    return { index = row.index, name = row.name, difficulty = row.difficulty, count = row.count,
             altVerb = row.altVerb, favorite = true }
end

-- Blizzard's flat header/recipe rows grouped the way Forever's data provider builds its tree, favourites first.
local function layout(rows)
    local data = { { pad = PAD_EDGE } }
    local function group(header, children)
        data[#data + 1] = header
        if #children == 0 then return end
        data[#data + 1] = { pad = GROUP_TOP }
        for _, row in ipairs(children) do data[#data + 1] = row end
        data[#data + 1] = { pad = GROUP_BOTTOM }
    end
    if not Model.IsSearching() then
        local set, favorites = Model.Favorites(), {}
        for _, row in ipairs(rows) do
            if not row.header and set[row.name] then favorites[#favorites + 1] = copyAsFavorite(row) end
        end
        if #favorites > 0 then
            local header = { header = true, favorites = true, name = L["Favorites"], expanded = not List.favoritesCollapsed }
            group(header, header.expanded and favorites or {})
        end
    end
    local header, children = nil, {}
    for _, row in ipairs(rows) do
        if row.header then
            if header then group(header, children) end
            header, children = row, {}
        elseif header then
            children[#children + 1] = row
        else
            data[#data + 1] = row
        end
    end
    if header then group(header, children) end
    data[#data + 1] = { pad = PAD_EDGE }
    return data
end

local function favoriteMenu(row)
    local on = Model.IsFavorite(row.name)
    return { { text = on and L["Remove Favorite"] or L["Set Favorite"], func = function() Model.SetFavorite(row.name, not on) end } }
end

local function onRowClick(self, button)
    local row = self.row
    if not row then return end
    if row.favorites then
        if button == "LeftButton" then
            List.favoritesCollapsed = not List.favoritesCollapsed
            List.selectedFavorite = false
            List.Refresh()
        end
    elseif row.header then
        if button == "LeftButton" then Model.Select(row.index) end
    elseif button == "RightButton" and not IsModifiedClick() then
        if Model.CanFavorite() then addon.Menu.Open(self, favoriteMenu(row), { style = "forever" }) end
    else
        List.clickedFavorite = row.favorite and true or false
        Model.Click(row.index, button)
        List.clickedFavorite = nil
    end
end

local function labelColor(b, lit)
    local c = lit and { 1, 1, 1 } or RECIPE_COLOR
    b.label:SetTextColor(c[1], c[2], c[3])
    b.count:SetTextColor(c[1], c[2], c[3])
end

local function onRowEnter(self)
    local row = self.row
    if not row or row.header then return end
    labelColor(self, true)
    -- 3.3.5a tooltips take a frame as owner, never a FontString (retail's Label owner errors here).
    if self.truncated then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.name, 1, 1, 1)
        GameTooltip:Show()
    end
end

local function onRowLeave(self)
    local row = self.row
    if not row or row.header then return end
    labelColor(self, false)
    if GameTooltip:IsOwned(self) or GameTooltip:IsOwned(self.skillHit) then GameTooltip:Hide() end
end

-- SkillUps in ProfessionsRecipeListRecipeTemplate: a 26 x 15 button at -9 whose icon sits on its right edge.
local function buildSkillUp(b)
    b.skill = b:CreateTexture(nil, "ARTWORK")
    local hit = CreateFrame("Button", nil, b)
    hit:SetSize(26, 15)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit:SetScript("OnClick", function(_, button) onRowClick(b, button) end)
    hit:SetScript("OnEnter", function(self)
        onRowEnter(b)
        local up = b.row and not List.runeforging and SKILL_UP[b.row.difficulty]
        if not up then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format(L[up[3]], 1), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() onRowLeave(b) end)
    b.skillHit = hit
end

local function newRow(n)
    local b = CreateFrame("Button", nil, List.area)
    b:SetWidth(ROW_W)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onRowClick)
    b:SetScript("OnEnter", onRowEnter)
    b:SetScript("OnLeave", onRowLeave)

    b.headerArt = { Art.ThreeSlice(b, "BACKGROUND", "header", 8) }
    b.headerHover = { Art.ThreeSlice(b, "HIGHLIGHT", "header", 8) }
    for _, t in ipairs(b.headerHover) do
        t:SetBlendMode("ADD")
        t:SetAlpha(0.4)
    end
    b.toggle = b:CreateTexture(nil, "ARTWORK")
    b.toggle:SetPoint("CENTER", b, "RIGHT", -16, 0)

    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
    b.count = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
    b.count:SetPoint("LEFT", b.label, "RIGHT", 0, 0)
    buildSkillUp(b)

    -- Text on ARTWORK and the glow on OVERLAY: 3.3.5a ignores sublevels, so the glow needs the higher layer.
    b.selected = b:CreateTexture(nil, "OVERLAY")
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetAlpha(0.5)

    List.rows[n] = b
    return b
end

-- Overlays centred on the indented recipe and clipped to the list, as Forever's scroll box clips them.
local function placeOverlay(texture, b, name)
    local w = P.Atlas[name][2]
    local left = INDENT + RECIPE_W / 2 - w / 2
    local from, to = math.max(0, left), math.min(ROW_W, left + w)
    Art.SetSpan(texture, name, from - left, to - left)
    texture:ClearAllPoints()
    texture:SetPoint("LEFT", b, "LEFT", from - INDENT, -1)
end

local function setShown(regions, shown)
    for _, r in ipairs(regions) do r:SetShownCompat(shown) end
end

local function paintRecipe(b, row)
    b.label:SetFontObject(GameFontHighlightLeft)
    b.label:SetPoint("LEFT", b, "LEFT", 21, 0)
    b.label:SetText(Model.Label(row))
    b.count:SetText(Model.CountText(row))
    labelColor(b, GetMouseFocus and GetMouseFocus() == b)
    local up = not List.runeforging and SKILL_UP[row.difficulty] or nil
    b.skill:SetShownCompat(up ~= nil)
    b.skillHit:SetShownCompat(up ~= nil)
    b.skillHit:ClearAllPoints()
    b.skillHit:SetPoint("LEFT", b, "LEFT", -9, up and up[2] or 0)
    if up then
        Art.Set(b.skill, up[1], true)
        b.skill:ClearAllPoints()
        b.skill:SetPoint("RIGHT", b.skillHit, "RIGHT", 0, -1)
    end
    local room = RECIPE_W - (b.count:GetText() ~= "" and b.count:GetStringWidth() or 0) - 10 - 26
    b.truncated = b.label:GetStringWidth() > room
    if b.truncated then b.label:SetWidth(room) end
end

local function paint(b, row, selected)
    b.row = row
    local header = row.header
    b:SetHeight(rowHeight(row) - SPACING)
    b:SetWidth(header and ROW_W or RECIPE_W)
    setShown(b.headerArt, header)
    setShown(b.headerHover, header)
    b.toggle:SetShownCompat(header)
    b.hover:SetShownCompat(not header)
    local isSelected = not header and row.index == selected
        and (row.favorite and true or false) == (List.selectedFavorite and true or false)
    b.selected:SetShownCompat(isSelected)

    b.label:ClearAllPoints()
    b.label:SetWidth(0)
    if header then
        b.skill:Hide()
        b.skillHit:Hide()
        b.label:SetFontObject(addon.ForeverUI.Fonts.HighlightMedium)
        b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.label:SetText(row.name)
        b.label:SetTextColor(Model.Color(row))
        b.count:SetText("")
        b.truncated = false
        Art.Set(b.toggle, row.expanded and "header-minus" or "header-plus", true)
        local room = ROW_W - 8 - 30
        if b.label:GetStringWidth() > room then b.label:SetWidth(room) end
    else
        placeOverlay(b.selected, b, "recipe-active")
        placeOverlay(b.hover, b, "recipe-hover")
        paintRecipe(b, row)
    end
end

-- MinimalScrollBar: always on screen; with nothing to scroll the thumb goes and both arrows grey out.
local function refreshBar(data, maxOff)
    local bar = List.bar
    local content = 0
    for _, row in ipairs(data) do content = content + rowHeight(row) end
    bar.silent = true
    bar:SetMinMaxValues(0, maxOff)
    bar:SetValue(List.offset)
    bar.silent = nil
    addon.ForeverUI.SetScrollBarFraction(bar, maxOff > 0 and ROOM / content or 1)
    if List.offset > 0 then bar.upButton:Enable() else bar.upButton:Disable() end
    if List.offset < maxOff then bar.downButton:Enable() else bar.downButton:Disable() end
    bar:Show()
end

function List.Refresh()
    if not List.frame or not TradeSkillFrame:IsShown() then return end
    -- Another addon's list stands in for ours (P.Host).
    if P.Host and P.Host.Replaces("list") then return end
    local data = layout(Model.Build(F.skillUpOnly, List.LocalSearch()))
    List.data = data
    -- Forever skips SkillUps while IsRuneforging(): runes are always 1/1, there is no skill to gain.
    local entry = P.Professions.EntryForLine(GetTradeSkillLine())
    List.runeforging = entry ~= nil and entry.key == "Runeforging"
    local maxOff = maxOffset(data)
    if List.offset > maxOff then List.offset = maxOff end
    if List.offset < 0 then List.offset = 0 end

    local selected = Model.SelectedIndex()
    local y, shown = 0, 0
    for i = List.offset + 1, #data do
        local row = data[i]
        local h = rowHeight(row)
        if y + h - SPACING > ROOM then break end
        if not row.pad then
            shown = shown + 1
            local b = List.rows[shown] or newRow(shown)
            paint(b, row, selected)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", List.area, "TOPLEFT", row.header and 0 or INDENT, -y)
            b:Show()
        end
        y = y + h
    end
    for j = shown + 1, #List.rows do
        List.rows[j]:Hide()
        List.rows[j].row = nil
    end

    -- Uncached items count as no match; GetItemInfo asked the server, so look again (three times at most).
    if Model.pendingItems and (List.retries or 0) < 3 then
        List.retries = (List.retries or 0) + 1
        addon:After(1, List.Refresh)
    end
    refreshBar(data, maxOff)
    List.empty:SetShownCompat(#data <= 2)
    List.RefreshFilterButton()
end

function List.ScrollTo(offset)
    List.offset = math.max(0, math.min(maxOffset(List.data), offset))
    List.Refresh()
end

function List.ResetScroll()
    List.offset = 0
end

function List.RefreshFilterButton()
    if List.reset then List.reset:SetShownCompat(F.IsActive()) end
end

-- WowStyle1FilterDropdownTemplate: the whole b-button art is the state; the label moves, the art stays.
local FILTER_H, FILTER_PAD, FILTER_MIN = 18, 60, 89

local function buildFilterButton(frame)
    local button = CreateFrame("Button", nil, frame)
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -9)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
    back:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetHeight(20)
    text:SetText(FILTER)
    button:SetSize(math.max(FILTER_MIN, math.floor(text:GetStringWidth() + FILTER_PAD + 0.5)), FILTER_H)

    local over, down = false, false
    local function restate()
        local open = addon.Menu.IsOpenFor(button)
        local suffix = (down and over) and "-pressedhover" or over and "-hover" or down and "-pressed"
            or open and "-open" or ""
        back:SetAtlasTexture("common-dropdown-b-button" .. suffix)
        text:ClearAllPoints()
        text:SetPoint("TOP", button, "TOP", down and 1 or 0, down and -1 or 0)
    end
    restate()
    -- The menu has no close callback; while it is up a tiny OnUpdate waits for it to go.
    local function watchMenu(self)
        if addon.Menu.IsOpenFor(self) then return end
        self:SetScript("OnUpdate", nil)
        restate()
    end
    button:SetScript("OnEnter", function() over = true restate() end)
    button:SetScript("OnLeave", function() over = false restate() end)
    button:SetScript("OnMouseDown", function() down = true restate() end)
    button:SetScript("OnMouseUp", function() down = false restate() end)
    button:SetScript("OnClick", function(self)
        addon.Menu.Open(self, F.MenuEntries(), { style = "forever" })
        restate()
        self:SetScript("OnUpdate", watchMenu)
    end)
    List.filter = button

    -- UIResetButtonTemplate, shown exactly while a filter is on.
    local reset = CreateFrame("Button", nil, frame)
    reset:SetSize(23, 23)
    reset:SetPoint("CENTER", button, "TOPRIGHT", -3, 0)
    reset:SetFrameLevel(button:GetFrameLevel() + 5)
    local normal = reset:CreateTexture(nil, "ARTWORK")
    Art.Set(normal, "reset-x")
    normal:SetAllPoints()
    local lit = reset:CreateTexture(nil, "HIGHLIGHT")
    Art.Set(lit, "reset-x")
    lit:SetAllPoints()
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.4)
    reset:SetScript("OnClick", function() F.Reset() end)
    reset:Hide()
    List.reset = reset
end

-- Blizzard hides its box and clears the name filter below 75 skill; Forever always searches, so ours is local there.
local function searchIsLocal()
    local _, rank = GetTradeSkillLine()
    return (rank or 0) < 75 and not IsTradeSkillLinked()
end

-- "N-M" as Blizzard reads it; a lone "N" or "~N" is N +-2 (exact levels rarely match); "N-" is N and up.
local function parseRange(text)
    local approx = text:match("^~?(%d+)$")
    if approx then return tonumber(approx) - 2, tonumber(approx) + 2 end
    local lo, dash, hi = text:match("^(%d+)%s*(%-*)%s*(%d*)$")
    lo, hi = tonumber(lo), tonumber(hi)
    if not lo then return nil end
    if not hi then return lo, dash ~= "" and math.huge or lo end
    return lo, math.max(lo, hi)
end

-- Blizzard's server filter only takes a name search at 75+; ranges and low-skill names are filtered in Model.Build.
local function applySearch(text)
    SetTradeSkillItemLevelFilter(0, 0)
    if text ~= "" and not parseRange(text) and not searchIsLocal() then
        SetTradeSkillItemNameFilter(text)
    else
        SetTradeSkillItemNameFilter("")
    end
end

function List.SearchText()
    return List.search and List.search:GetText() or ""
end

-- What Model.Build filters itself: an item level range, or a lower-cased name below 75; nil otherwise.
function List.LocalSearch()
    local text = List.SearchText()
    if text == "" then return nil end
    local lo, hi = parseRange(text)
    if lo then return { minLevel = lo, maxLevel = hi } end
    if searchIsLocal() then return { name = text:lower() } end
end

function List.Build()
    local craft = P.Frame.craft
    local frame = CreateFrame("Frame", nil, craft)
    frame:SetSize(LIST_W, LIST_H)
    frame:SetPoint("TOPLEFT", P.Frame.win, "TOPLEFT", 5, -72)
    List.frame = frame

    List.area = CreateFrame("Frame", nil, frame)
    List.area:SetPoint("TOPLEFT", frame, "TOPLEFT", AREA_X, -AREA_TOP)
    List.area:SetSize(ROW_W, ROOM)

    buildFilterButton(frame)

    -- ForeverUI's SearchBoxTemplate; the stock box goes, since Blizzard hides it and resets its text below 75.
    local search = addon.ForeverUI.CreateSearchBox(frame, 200, SEARCH)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -8)
    search:SetPoint("RIGHT", List.filter, "LEFT", -4, 0)
    search:HookScript("OnTextChanged", function(self)
        List.retries = 0
        applySearch(self:GetText())
        List.ResetScroll()
        List.Refresh()
    end)
    List.search = search
    P.Frame.Retire(TradeSkillFrameEditBox)

    local bar = addon.ForeverUI.CreateScrollBar(frame, {})
    bar:SetPoint("TOPLEFT", List.area, "TOPRIGHT", 0, -19)
    bar:SetHeight(ROOM - 38)
    bar:HookScript("OnValueChanged", function(self, value)
        if not self.silent then List.ScrollTo(math.floor(value + 0.5)) end
    end)
    bar.upButton:SetScript("OnClick", function() List.ScrollTo(List.offset - 1) end)
    bar.downButton:SetScript("OnClick", function() List.ScrollTo(List.offset + 1) end)
    List.bar = bar

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        List.ScrollTo(List.offset - delta * WHEEL_STEP)
    end)

    List.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    List.empty:SetWidth(200)
    List.empty:SetPoint("TOP", frame, "TOP", 0, -60)
    List.empty:SetText(L["No recipes found"])
    List.empty:Hide()

    for _, name in ipairs({ "TradeSkillFrameAvailableFilterCheckButton", "TradeSkillRankFrame", "TradeSkillExpandButtonFrame",
                            "TradeSkillInvSlotDropDown", "TradeSkillSubClassDropDown", "TradeSkillHighlightFrame",
                            "TradeSkillListScrollFrame" }) do
        P.Frame.Retire(_G[name])
    end
    for i = 1, TRADE_SKILLS_DISPLAYED or 8 do
        P.Frame.Retire(_G["TradeSkillSkill" .. i])
    end
end

P.On("Built", List.Build)
P.On("Update", List.Refresh)
-- A selection made anywhere but a favourite row (tracker, keyboard, Blizzard) lights the recipe's own row.
P.On("Selection", function()
    List.selectedFavorite = List.clickedFavorite and true or false
    List.Refresh()
end)
P.On("FavoritesChanged", List.Refresh)
P.On("FiltersChanged", function()
    List.ResetScroll()
    List.Refresh()
end)
P.On("ProfessionChanged", function()
    List.ResetScroll()
    List.selectedFavorite = false
    -- Forever's search starts empty in every profession it opens.
    if List.search and List.SearchText() ~= "" then List.search:SetText("") end
end)
-- As the stock box's OnShow did: every opening starts with no search.
P.On("Show", function()
    if List.search and List.SearchText() ~= "" then List.search:SetText("") end
end)

-- Blizzard jumps its own list to the top on a filter update (search text included); ours follows.
local events = CreateFrame("Frame")
events:RegisterEvent("TRADE_SKILL_FILTER_UPDATE")
events:SetScript("OnEvent", function()
    if P.active then List.ResetScroll() end
end)
