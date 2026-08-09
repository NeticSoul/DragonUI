local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Width chain: InsetRight = W - 332 - 4, pane = InsetRight - 6, viewport = pane - gutter. The
-- gutter is reserved permanently, so no header changes width when a collapse drops the scrollbar.
local SCROLLBAR_GUTTER = 11
local EXPANDED_WIDTH = 551

-- Resting widths only; the real ones are derived per relayout from the viewport.
local HEADER_W, HEADER_H = 197, 40
local ROW_W, ROW_H = 191, 15
local ROW_INSET = 3

-- Breathing room: two collapsed bars flush together read as one wider block.
local SECTION_GAP = 3
local ROWS_PER_SECTION = 6

-- Blizzard's own UpdatePaperdollStats drives these, so every Wrath formula comes from the client.
local SECTIONS = {
    { prefix = "DragonUIStatBase", index = "PLAYERSTAT_BASE_STATS" },
    { prefix = "DragonUIStatMelee", index = "PLAYERSTAT_MELEE_COMBAT" },
    { prefix = "DragonUIStatRanged", index = "PLAYERSTAT_RANGED_COMBAT" },
    { prefix = "DragonUIStatSpell", index = "PLAYERSTAT_SPELL_COMBAT" },
    { prefix = "DragonUIStatDefense", index = "PLAYERSTAT_DEFENSES" },
}

local RESIST_SCHOOLS = { 2, 3, 4, 5, 6 }

local pane, scrollChild, ilvlRow
local resistRows = {}

-- Sections in draw order, each owning its header and rows so collapsing one can re-flow the rest.
local layout = {}
local collapsed = {}

-- No +/- glyph: swapping the art made the header look like it shifted, and the glow says enough.
local HEADER_HL_ALPHA = 0.35

-- One texture sized outright: the viewport is always the art's native width, so slicing bought
-- nothing and cost a three-deep anchor chain that re-resolved on every frame of every collapse.
local function buildBar(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetSize(HEADER_W, HEADER_H)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    tex:set_atlas("UI-Character-Info-Title")
    return tex
end

local function buildHeader(parent, key, text)
    local header = CreateFrame("Button", nil, parent)
    header:SetSize(HEADER_W, HEADER_H)

    header.Bg = buildBar(header, "ARTWORK", 0)

    local label = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetDrawLayer("ARTWORK", 1)
    label:SetPoint("CENTER", header, "CENTER", 0, 1)
    label:SetText(text)

    -- The bar's own art on HIGHLIGHT, so the glow has the bar's shape rather than a rectangle's.
    local hl = buildBar(header, "HIGHLIGHT")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(HEADER_HL_ALPHA)
    header.Hl = hl

    header:SetScript("OnClick", function()
        if CP.ToggleSidebarSectionAnimated then CP.ToggleSidebarSectionAnimated(key) end
    end)

    header.key = key
    return header
end

-- Blizzard's setters address the label and value by global name, so each row has to be named
-- and carry <name>Label / <name>StatText children.
local function buildStatRow(parent, name, isEven)
    local row = CreateFrame("Frame", name, parent)
    row:SetSize(ROW_W, ROW_H)

    -- A flat neutral wash, not the Line-Bounce strip: that art is brown and tints every other row.
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("CENTER", row, "CENTER", 0, 0)
    bg:SetSize(ROW_W, ROW_H)
    bg:SetTexture(1, 1, 1)
    bg:SetAlpha(0.05)
    if not isEven then bg:Hide() end
    row.Bg = bg

    local label = row:CreateFontString(name .. "Label", "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 11, 0)

    local value = row:CreateFontString(name .. "StatText", "ARTWORK", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    row:EnableMouse(true)
    row:SetScript("OnEnter", PaperDollStatTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

-- Retail colours this by content tier, which 3.3.5a has no data for; the average quality of what is
-- equipped is the closest honest stand-in.
local ILVL_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

local function averageQuality()
    local total, count = 0, 0
    for _, slot in ipairs(ILVL_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local ok, _, _, quality = pcall(GetItemInfo, link)
            if ok and quality then
                total = total + quality
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return math.floor(total / count + 0.5)
end

-- A headline block rather than a label:value row: just the number, large and centred.
local function buildItemLevelRow(parent)
    local row = CreateFrame("Frame", "DragonUIStatItemLevel", parent)
    row:SetSize(ROW_W, 22)

    local value = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    value:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.Value = value

    row:EnableMouse(true)
    row:SetScript("OnEnter", PaperDollStatTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function buildResistRow(parent, index, school, isEven)
    local row = buildStatRow(parent, "DragonUIStatResist" .. index, isEven)
    row.school = school
    resistRows[index] = row
    return row
end

-- How far open each section is, 0 to 1. Separate from `collapsed`, which stays the logical state.
local progress = {}
local ANIM_DURATION = 0.18
local animator

local function openness(key)
    local p = progress[key]
    if p ~= nil then return p end
    return collapsed[key] and 0 or 1
end

local function stepAnimation(_, elapsed)
    local step = (elapsed or 0) / ANIM_DURATION
    local moving = false
    for _, section in ipairs(layout) do
        local key = section.key
        local target = collapsed[key] and 0 or 1
        local p = openness(key)
        if p ~= target then
            p = (p < target) and math.min(target, p + step) or math.max(target, p - step)
            progress[key] = p
            if p ~= target then moving = true end
        end
    end
    if CP.RelayoutSidebar then CP.RelayoutSidebar() end
    if not moving then animator:Hide() end
end

-- Freeze the openness before flipping the flag: otherwise the default openness IS the new target
-- the instant `collapsed` changes, and the animator stops on its first frame.
function CP.ToggleSidebarSectionAnimated(key)
    progress[key] = openness(key)
    collapsed[key] = not collapsed[key]

    if not animator then
        animator = CreateFrame("Frame")
        animator:SetScript("OnUpdate", stepAnimation)
    end
    animator:Show()
end

-- Re-flows every section from the top. Widths come from the viewport rather than a constant: when
-- the scrollbar drops out the viewport grows, and fixed-width content anchored TOPRIGHT would slide.
local relayouting

function CP.RelayoutSidebar()
    if not scrollChild or relayouting then return end
    relayouting = true

    -- One anchor plus an explicit size everywhere, never two opposing anchors on something sized:
    -- the relayout re-anchors on every frame of a collapse and the engine reconciles both each time.
    local width = math.floor(scrollChild:GetWidth() or 0)
    if width <= 0 then width = HEADER_W end
    local rowWidth = width - ROW_INSET * 2

    local y = 0
    for _, section in ipairs(layout) do
        local open = openness(section.key)
        local header = section.header
        header:SetSize(width, HEADER_H)
        if header.Bg then header.Bg:SetSize(width, HEADER_H) end
        if header.Hl then header.Hl:SetSize(width, HEADER_H) end
        header:ClearAllPoints()
        header:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
        y = y + HEADER_H

        -- Blizzard hides the 6th Ranged row itself; honour that so we do not re-flow a blank.
        local blockH = 0
        for _, row in ipairs(section.rows) do
            -- The item level block is taller than a stat row, so read the real height.
            if not row._duiBlizzHidden then blockH = blockH + (row:GetHeight() or ROW_H) end
        end

        -- Rows never move; they are uncovered as the block's edge sweeps past, each fading over its
        -- own height. Sliding the stack made rows surface above the bar before disappearing.
        local revealed = blockH * open
        local offset = 0
        for _, row in ipairs(section.rows) do
            if row._duiBlizzHidden then
                row:Hide()
            else
                local h = row:GetHeight() or ROW_H
                -- Sized even while hidden, or a row collapsed at the last width returns with the old one.
                row:SetWidth(rowWidth)
                if row.Bg then row.Bg:SetWidth(rowWidth) end
                if offset >= revealed then
                    row:Hide()
                else
                    row:ClearAllPoints()
                    row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -ROW_INSET, -(y + offset))
                    row:SetAlpha(math.min(1, (revealed - offset) / h))
                    row:Show()
                end
                offset = offset + h
            end
        end
        y = y + revealed + SECTION_GAP
    end
    scrollChild:SetHeight(math.max(1, y))
    if CP.SyncScrollThumb then CP.SyncScrollThumb(_G.DragonUICharacterStatsScroll) end
    relayouting = false
end

-- The class plate is opaque and dark at full strength, so at alpha 1 it buries the pane. Just over
-- half reads as a crest showing through the rock and keeps the stat text legible.
local CLASS_BG_ALPHA = 0.55

local function applyClassBackground()
    if not pane then return end
    local _, classFile = UnitClass("player")
    if not classFile then return end

    local atlas = "ui-character-info-" .. classFile:lower() .. "-bg"
    if not addon.atlasinfo[atlas] then return end

    local bg = pane._duiClassBg
    if not bg then
        -- Below every other background piece, not level with them.
        bg = pane:CreateTexture(nil, "BACKGROUND", nil, -3)
        bg:SetAlpha(CLASS_BG_ALPHA)
        pane._duiClassBg = bg
    end
    -- set_atlas stamps the width too, so the spanning anchors go on afterwards and win.
    bg:set_atlas(atlas, true)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    bg:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
end

local function buildSidebar()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.InsetRight then return end

    pane = CreateFrame("Frame", "DragonUICharacterStatsPane", cf.InsetRight)
    pane:SetPoint("TOPLEFT", cf.InsetRight, "TOPLEFT", 3, -3)
    pane:SetPoint("BOTTOMRIGHT", cf.InsetRight, "BOTTOMRIGHT", -3, 2)

    local scroll = CreateFrame("ScrollFrame", "DragonUICharacterStatsScroll", pane,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -SCROLLBAR_GUTTER, 0)
    -- Deliberately does NOT hide, unlike every other pane: hiding it frees the gutter, and a width
    -- that changes on the same event as a collapse reads as the header stretching on its own.

    if CP.ReskinScrollBar then CP.ReskinScrollBar(scroll, pane) end

    scrollChild = CreateFrame("Frame", "DragonUICharacterStatsScrollChild", scroll)
    scrollChild:SetWidth(HEADER_W)
    scroll:SetScrollChild(scrollChild)

    -- Re-derived rather than trusted: one pixel of overhang brings the sideways slide back.
    scroll:HookScript("OnSizeChanged", function(_, w)
        if not (w and w > 0) or w == scrollChild:GetWidth() then return end
        scrollChild:SetWidth(w)
        -- We are normally already inside a relayout, so let it finish and re-flow next frame -- or
        -- the new width never reaches the rows.
        if relayouting then
            addon:After(0, function()
                if CP.RelayoutSidebar then CP.RelayoutSidebar() end
            end)
        elseif CP.RelayoutSidebar then
            CP.RelayoutSidebar()
        end
    end)

    applyClassBackground()

    local function addSection(key, text, rows)
        local header = buildHeader(scrollChild, key, text)
        -- Above the rows, so a folding section slides up behind its own bar instead of over it.
        header:SetFrameLevel(scrollChild:GetFrameLevel() + 2)
        layout[#layout + 1] = { key = key, header = header, rows = rows }
    end

    -- Item level leads the list as its own headline stat, the way retail does.
    ilvlRow = buildItemLevelRow(scrollChild)
    addSection("itemlevel", addon.L["Item Level"], { ilvlRow })

    for _, section in ipairs(SECTIONS) do
        local rows = {}
        for i = 1, ROWS_PER_SECTION do
            rows[i] = buildStatRow(scrollChild, section.prefix .. i, i % 2 == 0)
        end
        addSection(section.index, _G[section.index] or section.index, rows)
    end

    local resists = {}
    for i, school in ipairs(RESIST_SCHOOLS) do
        resists[i] = buildResistRow(scrollChild, i, school, i % 2 == 0)
    end
    addSection("resistance", RESISTANCE_LABEL, resists)

    CP.RelayoutSidebar()
    CP._sidebar = pane
end

local function resistanceLevel(resistance)
    local level = max(UnitLevel("player") or 1, 20)
    local ratio = resistance / level
    if ratio > 5 then return RESISTANCE_EXCELLENT end
    if ratio > 3.75 then return RESISTANCE_VERYGOOD end
    if ratio > 2.5 then return RESISTANCE_GOOD end
    if ratio > 1.25 then return RESISTANCE_FAIR end
    if ratio > 0 then return RESISTANCE_POOR end
    return RESISTANCE_NONE
end

-- Mirrors PaperDollFrame_SetResistances, the "( base +x -y )" breakdown tooltip included.
local function refreshResistances()
    for _, row in ipairs(resistRows) do
        local school = row.school
        local base, resistance, positive, negative = UnitResistance("player", school)
        local name = row:GetName()
        local schoolName = _G["RESISTANCE" .. school .. "_NAME"] or ""

        _G[name .. "Label"]:SetText(format(STAT_FORMAT, schoolName))

        local text = tostring(resistance)
        if abs(negative) > positive then
            text = RED_FONT_COLOR_CODE .. resistance .. FONT_COLOR_CODE_CLOSE
        elseif abs(negative) < positive then
            text = GREEN_FONT_COLOR_CODE .. resistance .. FONT_COLOR_CODE_CLOSE
        end
        _G[name .. "StatText"]:SetText(text)

        local tooltip = format(PAPERDOLLFRAME_TOOLTIP_FORMAT, schoolName) .. " " .. resistance
        if positive ~= 0 or negative ~= 0 then
            tooltip = tooltip .. " ( " .. HIGHLIGHT_FONT_COLOR_CODE .. base
            if positive > 0 then tooltip = tooltip .. GREEN_FONT_COLOR_CODE .. " +" .. positive end
            if negative < 0 then tooltip = tooltip .. " " .. RED_FONT_COLOR_CODE .. negative end
            tooltip = tooltip .. FONT_COLOR_CODE_CLOSE .. " )"
        end
        row.tooltip = tooltip
        row.tooltip2 = format(RESISTANCE_TOOLTIP_SUBTEXT, _G["RESISTANCE_TYPE" .. school] or "",
                              max(UnitLevel("player") or 1, 20), resistanceLevel(resistance))
    end
end

local function refreshItemLevel()
    if not ilvlRow then return end

    local average = addon.GetAverageItemLevel and addon.GetAverageItemLevel("player")
    ilvlRow.Value:SetText(average and tostring(average) or "--")

    local quality = averageQuality()
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        ilvlRow.Value:SetTextColor(color.r, color.g, color.b)
    else
        ilvlRow.Value:SetTextColor(1, 0.82, 0)
    end

    ilvlRow.tooltip = addon.L["Item Level"]
    ilvlRow.tooltip2 = addon.L["Average item level of your equipped gear."]
end

local function refresh()
    if not pane then return end
    refreshItemLevel()

    for _, section in ipairs(SECTIONS) do
        UpdatePaperdollStats(section.prefix, section.index)
        -- Capture what Blizzard chose to hide before the re-flow overwrites visibility.
        for i = 1, ROWS_PER_SECTION do
            local row = _G[section.prefix .. i]
            if row then row._duiBlizzHidden = not row:IsShown() end
        end
    end

    refreshResistances()
    CP.RelayoutSidebar()
end

local function expand()
    local cf = _G.CharacterFrame
    if not cf or InCombatLockdown() then return end
    buildSidebar()
    if not pane then return end
    cf:SetWidth(EXPANDED_WIDTH)
    cf.InsetRight:Show()
    refresh()

    -- The pane is created visible, so re-assert whichever sidebar tab the user last picked.
    if CP.ShowSidebarPane and CP.SelectedSidebarTab then
        CP.ShowSidebarPane(CP.SelectedSidebarTab())
    end
    if CP.RestyleSidebarTabs then CP.RestyleSidebarTabs() end
end

local function collapse(keepWidth)
    local cf = _G.CharacterFrame
    if not cf or InCombatLockdown() then return end
    -- This runs after SetInsetForTab, so forcing the narrow width here would silently undo it.
    if not keepWidth then cf:SetWidth(CP.PANEL_WIDTH) end
    if cf.InsetRight then cf.InsetRight:Hide() end
end

-- Only PaperDoll gets the stats pane; the list tabs manage their own width.
local function applyForTab(tabName)
    local isPaperDoll = tabName == "PaperDollFrame"
    if isPaperDoll then expand() else collapse(CP.OWNED_TABS[tabName]) end
    if CP.SetSidebarTabsShown then CP.SetSidebarTabsShown(isPaperDoll) end
end

CP.ExpandSidebar = expand
CP.CollapseSidebar = collapse
CP.ApplySidebarForTab = applyForTab
CP.RefreshSidebar = refresh
CP.EXPANDED_WIDTH = EXPANDED_WIDTH

local events = CreateFrame("Frame")
events:RegisterEvent("UNIT_STATS")
events:RegisterEvent("UNIT_ATTACK_POWER")
events:RegisterEvent("UNIT_RANGED_ATTACK_POWER")
events:RegisterEvent("UNIT_RESISTANCES")
events:RegisterEvent("UNIT_ATTACK")
events:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
events:RegisterEvent("COMBAT_RATING_UPDATE")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function(_, _, unit)
    if unit and unit ~= "player" then return end
    if pane and pane:IsVisible() then refresh() end
end)

CP:RegisterBuilder("sidebar", function()
    if not _G.PaperDollFrame then return end
    -- Ours replaces the overlay itemlevel.lua draws across the model.
    if addon.SetCharacterAverageSuppressed then addon.SetCharacterAverageSuppressed(true) end
    if _G.PaperDollFrame:IsShown() then expand() end
    if not _G.PaperDollFrame._duiSidebarHooked then
        _G.PaperDollFrame._duiSidebarHooked = true
        _G.PaperDollFrame:HookScript("OnShow", function() expand() end)
    end
end)
