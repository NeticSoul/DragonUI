local addon = select(2, ...)
local CP = addon.CharacterPanel

local ROW_H = 24
local CHECK_SIZE = 16
local NONE_ID = -1

local pane, scroll, scrollChild
local rows = {}

-- The scroll child had a hardcoded 180 width, so the rows stopped short of the pane whatever the
-- panel measured. Taken from the scroll frame once it has real dimensions instead.
local function layout()
    if not scroll or not scrollChild then return end
    local width = scroll:GetWidth() or 0
    if width > 0 then scrollChild:SetWidth(width) end
end

local function currentTitle()
    return GetCurrentTitle and GetCurrentTitle() or NONE_ID
end

-- IsTitleKnown returns a number on 3.3.5a, not a boolean, so compare against 0 rather than
-- truth-testing it.
local function knownTitles()
    local out = { { id = NONE_ID, name = NONE or "None" } }
    for i = 1, (GetNumTitles and GetNumTitles() or 0) do
        if IsTitleKnown(i) and IsTitleKnown(i) ~= 0 then
            local name = GetTitleName(i)
            if name and name ~= "" then
                out[#out + 1] = { id = i, name = strtrim(name) }
            end
        end
    end
    return out
end

local function makeRow(index)
    local row = CreateFrame("Button", "DragonUITitleRow" .. index, scrollChild)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(index - 1) * ROW_H)

    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(row)
    stripe:SetTexture(1, 1, 1)
    stripe:SetAlpha(0)
    row.Stripe = stripe

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", row, "LEFT", 10, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -(CHECK_SIZE + 12), 0)
    text:SetJustifyH("LEFT")
    row.Text = text

    -- The gold tick, not the green one: this marks the title you are wearing, not a completed task.
    local check = row:CreateTexture(nil, "OVERLAY")
    check:set_atlas("common-icon-checkmark-yellow")
    check:SetSize(CHECK_SIZE, CHECK_SIZE)
    check:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    check:Hide()
    row.Check = check

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local hl = row:GetHighlightTexture()
    if hl then hl:SetAlpha(0.4) end

    row:SetScript("OnClick", function(self)
        if self.titleId == NONE_ID then
            SetCurrentTitle(NONE_ID)
        else
            SetCurrentTitle(self.titleId)
        end
        if CP.RefreshTitlesPane then CP.RefreshTitlesPane() end
    end)

    rows[index] = row
    return row
end

local function refresh()
    if not pane or not pane:IsShown() then return end
    layout()

    local list = knownTitles()
    local current = currentTitle()

    for i, entry in ipairs(list) do
        local row = rows[i] or makeRow(i)
        row.titleId = entry.id
        row.Text:SetText(entry.name)
        row.Check:SetShownReq(entry.id == current)
        row.Stripe:SetAlpha(i % 2 == 0 and 0.06 or 0)
        row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end

    scrollChild:SetHeight(math.max(1, #list * ROW_H))
    if CP.SyncScrollBarVisibility then CP.SyncScrollBarVisibility(scroll) end
end

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.InsetRight then return end

    pane = CreateFrame("Frame", "DragonUICharacterTitlesPane", cf.InsetRight)
    pane:SetPoint("TOPLEFT", cf.InsetRight, "TOPLEFT", 3, -3)
    pane:SetPoint("BOTTOMRIGHT", cf.InsetRight, "BOTTOMRIGHT", -3, 2)
    pane:Hide()

    scroll = CreateFrame("ScrollFrame", "DragonUICharacterTitlesScroll", pane,
                         "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -12, 0)
    if CP.ReskinScrollBar then CP.ReskinScrollBar(scroll, pane) end
    if CP.AutoHideScrollBar then CP.AutoHideScrollBar(scroll, pane, 12, 0, layout) end

    scrollChild = CreateFrame("Frame", "DragonUICharacterTitlesScrollChild", scroll)
    scroll:SetScrollChild(scrollChild)
    pane:SetScript("OnShow", layout)

    CP._titlesPane = pane
end

CP.TitlesPane = function() return pane end
CP.RefreshTitlesPane = refresh
CP.BuildTitlesPane = build

local events = CreateFrame("Frame")
events:RegisterEvent("KNOWN_TITLES_UPDATE")
events:RegisterEvent("UNIT_NAME_UPDATE")
events:SetScript("OnEvent", function() refresh() end)

CP:RegisterBuilder("titlespane", build)
