-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CO = addon.Collections

-- One journal serves both tabs: the panes are identical and only the companion kind changes, so the
-- widgets are built once and repopulated on every tab switch instead of twice over.

-- 46, not a round 44: that is the height its plate is cut at, and retail's row, so nothing scales.
local ROW_H = 46
local ICON_SIZE = 38
local SEARCH_H = 20
local INFO_ICON = 40

-- The opening is measured where the ring turns solid: its fully transparent core is far smaller
-- than the gold bars actually enclose, and its centre sits high and left of the art.
local INFO_FRAME_TEX = addon._dir .. "Collections\\IconFrameGold"
local INFO_FRAME_OPEN, INFO_FRAME_CX, INFO_FRAME_CY = 0.4922, 0.4727, 0.4336
local INFO_FRAME_SIZE = INFO_ICON / INFO_FRAME_OPEN
local INFO_FRAME_X = (0.5 - INFO_FRAME_CX) * INFO_FRAME_SIZE
local INFO_FRAME_Y = (INFO_FRAME_CY - 0.5) * INFO_FRAME_SIZE
local ACTIVE_STROKE = 2
local ACTIVE_SIZE = ICON_SIZE * 64 / (64 - 2 * ACTIVE_STROKE)

-- auraborders.lua's chrome geometry verbatim, scaled off its 37px reference: same white art tinted,
-- same overhang, same extra pixel on top. The stroke frames the icon from outside, never on its edge.
-- Retail's own tooltip proportions for this button: a body wide enough not to wrap every clause,
-- and the gold its spell text is printed in.
local TOOLTIP_MIN_W = 260
local TOOLTIP_BODY = { 1, 0.82, 0 }

-- retail MountJournal.MountCount: a fixed 130x20 box with its label and number pinned 10 from each
-- end, which is what puts the air between them.
local COUNT_W, COUNT_H, COUNT_PAD = 130, 20, 10

local RANDOM_SIZE = 30
local FRAME_TEXTURE = addon._dir .. "ActionBars\\uiactionbariconframe_white.tga"
local FRAME_SCALE = RANDOM_SIZE / 37
local FRAME_X, FRAME_TOP = 2.2 * FRAME_SCALE, 2.3 * FRAME_SCALE
local FRAME_COLOR = { 0.08, 0.08, 0.08 }

local frame, scroll, content, rows
local searchBox, filterButton, filterMenu, rowMenu
local countBox, countText, countLabel, randomButton
local infoIcon, infoFrame, infoDrag, infoName, infoSource, infoDesc, infoStar, model, actionButton
local emptyText, uncollectedHint

local flat = {}
local selected = { MOUNT = nil, CRITTER = nil }
local query = ""
local menuEntry
local repaint, refresh, updateRandomIcon

-- Filter state, shared by both tabs except the mount-only ones.
local filters = {
    favoritesOnly = false,
    collected = true,
    notCollected = true,
    unusable = true,
    ground = true,
    flying = true,
    aquatic = true,
    hiddenSources = {},
}

local function kind()
    return CO.Kind or "MOUNT"
end

local function isMount()
    return kind() == "MOUNT"
end

local function selectedEntry()
    return CO.Find(kind(), selected[kind()])
end

local function showCreature(creatureID)
    if not model then return end
    if not creatureID then
        model._creature = nil
        model:Hide()
        return
    end
    model:Show()
    -- Only on a real change: SetCreature restarts the idle animation, and refresh() runs on every
    -- companion event, so re-setting the same creature made the model loop its intro forever.
    if model._creature == creatureID and not model._duiStale then return end
    model._duiStale = nil

    -- A new creature is framed at its own distance, so the previous one's zoom means nothing here.
    if model._creature ~= creatureID then
        model._creature = creatureID
        -- The zoom resets itself on the reload below; the pose is ours to put back.
        addon:ResetModelRotation(model, 0.5)
    end
    model:SetCreature(creatureID)
end

local function buildModel(parent)
    model = CreateFrame("PlayerModel", nil, parent)
    model:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -132)
    model:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)

    -- A hidden model can drop its content, and showCreature's guard would never re-issue SetCreature.
    model:SetScript("OnHide", function(self) self._duiStale = true end)

    -- Last, so it hooks the OnHide above instead of being overwritten by it.
    addon:WireModelView(model, { facing = 0.5, pivot = addon.ModelPivot.creature })
    addon:ResetModelRotation(model, 0.5)
end

local function updateInfo()
    local entry = selectedEntry()

    if not entry then
        infoIcon:Hide()
        infoFrame:Hide()
        infoDrag:Hide()
        infoStar:Hide()
        infoName:SetText("")
        infoSource:SetText("")
        infoDesc:SetText("")
        uncollectedHint:Hide()
        showCreature(nil)
        actionButton:Disable()
        actionButton:SetText(isMount() and MOUNT or SUMMON)
        return
    end

    infoIcon:SetTexture(entry.icon)
    infoIcon:Show()
    infoFrame:Show()
    infoDrag:Show()
    infoName:SetText(entry.name)

    infoSource:SetFormattedText("|cffffd200%s:|r %s", addon.L["Source"],
        CO.SourceLabel(CO.SourceIndex(kind(), entry.spellID)))
    infoDesc:SetText(CO.Description(entry.spellID) or "")

    -- Only a learned companion has a creature the client can pose, and only it can be favorited.
    if entry.index then
        infoStar:Show()
        local fav = CO.IsFavorite(kind(), entry.creatureID)
        infoStar._star:SetDesaturated(not fav)
        infoStar._star:SetAlpha(fav and 1 or 0.75)
        uncollectedHint:Hide()
        showCreature(entry.creatureID)
    else
        infoStar:Hide()
        showCreature(nil)
        uncollectedHint:Show()
    end

    if not entry.index then
        actionButton:Disable()
        actionButton:SetText(isMount() and MOUNT or SUMMON)
    elseif entry.active then
        actionButton:Enable()
        actionButton:SetText(isMount() and BINDING_NAME_DISMOUNT or PET_DISMISS)
    else
        actionButton:Enable()
        actionButton:SetText(isMount() and MOUNT or SUMMON)
    end
end

local function buildInfo(host)
    -- Its own child frame, not the inset: sharing the inset's BACKGROUND band made the model backdrop
    -- and the rock fill trade places between loads. Inset 4px so it stays inside the gold trim.
    local parent = CreateFrame("Frame", nil, host)
    parent:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -4)
    parent:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -4, 4)
    parent:SetFrameLevel(host:GetFrameLevel() + 1)

    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(parent)
    bg:SetTexture(CO.TEX.modelBg)
    bg:SetTexCoord(unpack(CO.MODEL_BG_COORD))

    -- The ornament is pinned, and the icon hangs off its opening: the flourishes run past the frame
    -- on two sides, so anchoring the other way round would push them outside the pane.
    infoFrame = parent:CreateTexture(nil, "OVERLAY")
    infoFrame:SetTexture(INFO_FRAME_TEX)
    infoFrame:SetSize(INFO_FRAME_SIZE, INFO_FRAME_SIZE)
    infoFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)

    infoIcon = parent:CreateTexture(nil, "ARTWORK")
    infoIcon:SetSize(INFO_ICON, INFO_ICON)
    infoIcon:SetPoint("CENTER", infoFrame, "CENTER", -INFO_FRAME_X, -INFO_FRAME_Y)
    infoIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- The ornament is a texture, and textures take no input, so it cannot shadow this button: the
    -- whole opening stays clickable even where the gold overlaps the icon.
    infoDrag = CreateFrame("Button", nil, parent)
    infoDrag:SetAllPoints(infoIcon)
    infoDrag:RegisterForClicks("RightButtonUp")
    infoDrag:RegisterForDrag("LeftButton")
    infoDrag:SetScript("OnDragStart", function()
        local entry = selectedEntry()
        if entry and entry.index then PickupCompanion(kind(), entry.index) end
    end)
    infoDrag:SetScript("OnClick", function()
        local entry = selectedEntry()
        if not (entry and entry.index) then return end
        menuEntry = entry
        if rowMenu then ToggleDropDownMenu(1, nil, rowMenu, "cursor", 0, 0) end
    end)
    infoDrag:SetScript("OnEnter", function(self)
        local entry = selectedEntry()
        if not (entry and entry.spellID) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. entry.spellID)
        GameTooltip:AddLine(addon.L["Drag to place it on an action bar."], 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    infoDrag:SetScript("OnLeave", function() GameTooltip:Hide() end)

    infoStar = CreateFrame("Button", nil, parent)
    infoStar:SetSize(24, 24)
    infoStar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    local star = infoStar:CreateTexture(nil, "ARTWORK")
    star:SetAllPoints(infoStar)
    star:SetTexture(CO.TEX.favorite)
    star:SetTexCoord(unpack(CO.FAV_COORD))
    infoStar._star = star
    -- The star glowing itself rather than a square wash: retail has no favourite BUTTON to copy a
    -- highlight from -- it favourites through the row's right-click menu -- and a square hilight
    -- flares well past the star's silhouette.
    local starHL = infoStar:CreateTexture(nil, "HIGHLIGHT")
    starHL:SetAllPoints(infoStar)
    starHL:SetTexture(CO.TEX.favorite)
    starHL:SetTexCoord(unpack(CO.FAV_COORD))
    starHL:SetBlendMode("ADD")
    starHL:SetAlpha(0.4)
    infoStar:SetScript("OnClick", function()
        local entry = selectedEntry()
        if not entry then return end
        CO.ToggleFavorite(kind(), entry.creatureID)
        PlaySound("igMainMenuOptionCheckBoxOn")
        refresh()
    end)
    infoStar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(addon.L["Favorite"], 1, 0.82, 0)
        GameTooltip:AddLine(addon.L["Keeps this at the front of the list."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    infoStar:SetScript("OnLeave", function() GameTooltip:Hide() end)

    infoName = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    -- Off the icon, not the ornament: the frame's right side is mostly transparent margin, so
    -- anchoring there left the title floating away from what it names.
    infoName:SetPoint("LEFT", infoIcon, "RIGHT", 14, 0)
    infoName:SetPoint("RIGHT", infoStar, "LEFT", -8, 0)
    infoName:SetJustifyH("LEFT")

    -- Anchor pairs alone do not constrain wrapping width; long text would clip to a single line.
    local textWidth = 320

    infoSource = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- Below the whole ornament rather than the icon: the flourishes hang past the icon's bottom.
    infoSource:SetPoint("TOPLEFT", infoFrame, "BOTTOMLEFT", 12, -4)
    infoSource:SetWidth(textWidth)
    infoSource:SetJustifyH("LEFT")

    infoDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoDesc:SetPoint("TOPLEFT", infoSource, "BOTTOMLEFT", 0, -6)
    infoDesc:SetWidth(textWidth)
    infoDesc:SetJustifyH("LEFT")
    infoDesc:SetJustifyV("TOP")
    infoDesc:SetTextColor(0.82, 0.82, 0.82)

    buildModel(parent)

    uncollectedHint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    uncollectedHint:SetPoint("CENTER", model, "CENTER", 0, 0)
    uncollectedHint:SetText(addon.L["Not collected yet"])
    uncollectedHint:Hide()
end

local function buildRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetTexture(CO.TEX.rows)
    row.Background:SetTexCoord(unpack(CO.ROW_COORDS.background))
    row.Background:SetAllPoints(row)

    row.Selected = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.Selected:SetTexture(CO.TEX.rows)
    row.Selected:SetTexCoord(unpack(CO.ROW_COORDS.selected))
    row.Selected:SetAllPoints(row)
    row.Selected:Hide()

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(CO.TEX.rows)
    hl:SetTexCoord(unpack(CO.ROW_COORDS.highlight))
    hl:SetAllPoints(row)

    row.Icon = row:CreateTexture(nil, "BORDER")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- CheckButtonHilight peaks 2px into its 64px tile, so this is the size that lands that peak on
    -- the icon's edge instead of flaring past it.
    row.Active = row:CreateTexture(nil, "OVERLAY")
    row.Active:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.Active:SetSize(ACTIVE_SIZE, ACTIVE_SIZE)
    row.Active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    row.Active:SetBlendMode("ADD")
    row.Active:Hide()

    row.Faction = row:CreateTexture(nil, "ARTWORK")
    row.Faction:SetSize(32, 36)
    row.Faction:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Faction:SetTexture(CO.TEX.faction)
    row.Faction:SetAlpha(0.55)
    row.Faction:Hide()

    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 10, 0)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -26, 0)
    row.Text:SetJustifyH("LEFT")

    row.Star = row:CreateTexture(nil, "OVERLAY")
    row.Star:SetSize(20, 20)
    row.Star:SetPoint("TOPLEFT", row.Icon, "TOPLEFT", -7, 7)
    row.Star:SetTexture(CO.TEX.favorite)
    row.Star:SetTexCoord(unpack(CO.FAV_COORD))
    row.Star:Hide()

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        if self._entry and self._entry.index then PickupCompanion(kind(), self._entry.index) end
    end)
    row:SetScript("OnClick", function(self, button)
        if not self._entry then return end
        -- A catalog row has nothing to summon or favorite, so it only ever selects.
        if button == "RightButton" and self._entry.index then
            menuEntry = self._entry
            if rowMenu then ToggleDropDownMenu(1, nil, rowMenu, "cursor", 0, 0) end
            return
        end
        selected[kind()] = self._entry.spellID
        CO.MarkSeen(kind(), self._entry.creatureID)
        refresh()
    end)
    row:SetScript("OnEnter", function(self)
        if not (self._entry and self._entry.spellID) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self._entry.spellID)
        if self._entry.index then
            GameTooltip:AddLine(addon.L["Right-click for more options"], 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine(addon.L["Not collected yet"], 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function updateRow(row, entry)
    row._entry = entry
    row.Icon:SetTexture(entry.icon)
    row.Text:SetText(entry.name)

    -- Only "not collected" greys out. Where you happen to be standing is not a property of the
    -- collection, and the game already refuses with its own message if you cannot mount here.
    local collected = entry.index ~= nil
    row.Icon:SetDesaturated(not collected)
    row.Icon:SetAlpha(collected and 1 or 0.35)
    row.Text:SetFontObject(collected and "GameFontNormal" or "GameFontDisable")

    if entry.active then row.Active:Show() else row.Active:Hide() end
    if CO.IsFavorite(kind(), entry.creatureID) then row.Star:Show() else row.Star:Hide() end

    -- The selection art doubles as the "just learned" marker: selected holds it steady, new pulses it.
    local isSelected = entry.spellID == selected[kind()]
    row._pulse = (not isSelected) and collected and CO.IsNew(kind(), entry.creatureID) or nil
    if isSelected or row._pulse then
        row.Selected:SetAlpha(isSelected and 1 or CO.PulseAlpha())
        row.Selected:Show()
    else
        row.Selected:Hide()
    end

    local faction = isMount() and CO.MountFaction(entry.spellID)
    if faction and CO.FACTION_COORDS[faction] then
        row.Faction:SetTexCoord(unpack(CO.FACTION_COORDS[faction]))
        row.Faction:Show()
    else
        row.Faction:Hide()
    end
end

-- One handler for the whole list instead of one per row, and only while something is actually new,
-- so a collection with nothing to announce costs nothing per frame.
local pulsingRows = {}

-- Only rows that were actually painted count as shown: one buried below the fold never reached the
-- player, so closing the window must not spend its pulse.
local shownNew = { MOUNT = {}, CRITTER = {} }

function CO.MarkShownSeen()
    for kind, ids in pairs(shownNew) do
        for creatureID in pairs(ids) do
            CO.MarkSeen(kind, creatureID)
        end
        wipe(ids)
    end
end

local function pulseNewRows()
    local alpha = CO.PulseAlpha()
    for i = 1, #pulsingRows do
        pulsingRows[i].Selected:SetAlpha(alpha)
    end
end

repaint = function()
    if not (scroll and content) then return end
    wipe(pulsingRows)
    addon.CharacterPanel.PaintListRows(scroll, content, flat, ROW_H, { rows }, function(entry)
        local row = rows:acquire()
        updateRow(row, entry)
        if row._pulse then
            pulsingRows[#pulsingRows + 1] = row
            shownNew[kind()][entry.creatureID] = true
        end
        return row, 0
    end)
    scroll:SetScript("OnUpdate", #pulsingRows > 0 and pulseNewRows or nil)
end

local function matches(entry)
    local collected = entry.index ~= nil
    if not (collected and filters.collected or (not collected) and filters.notCollected) then return false end
    if filters.favoritesOnly and not CO.IsFavorite(kind(), entry.creatureID) then return false end
    if query ~= "" and not string.find(string.lower(entry.name), query, 1, true) then return false end
    if filters.hiddenSources[CO.SourceIndex(kind(), entry.spellID)] then return false end
    if not isMount() then return true end

    local ground, flying, aquatic = CO.MountCategory(entry.spellID)
    if not ((ground and filters.ground) or (flying and filters.flying) or (aquatic and filters.aquatic)) then
        return false
    end
    -- "Usable here" is only meaningful for something you own; a catalog row is never filtered by it.
    if collected and not filters.unusable and not CO.MountUsableNow(entry.spellID) then return false end
    return true
end

-- Favorites first, then everything else, alphabetical within each group -- the retail ordering.
local function rebuild()
    local list = CO.List(kind())
    wipe(flat)
    local rest = {}
    for _, entry in ipairs(list) do
        if matches(entry) then
            if CO.IsFavorite(kind(), entry.creatureID) then
                flat[#flat + 1] = entry
            else
                rest[#rest + 1] = entry
            end
        end
    end
    for _, entry in ipairs(rest) do flat[#flat + 1] = entry end
end

-- Mounts are ridden, not summoned; the pet wording would read as a second companion for them.
local function randomLabel()
    if kind() == "MOUNT" then return addon.L["Mount Random Favorite"] end
    return addon.L["Summon Random Favorite"]
end

-- Retail's own spell wording; the caption keeps the short label, which is all that strip fits.
local function randomTooltip()
    if kind() == "MOUNT" then
        return addon.L["Summon Random Favorite Mount"],
            addon.L["Summons and dismisses a favorite mount that is usable in the current area."],
            addon.L["If you don't have any favorite mounts, it'll choose from your whole collection."]
    end
    return addon.L["Summon Random Favorite Pet"],
        addon.L["Summons and dismisses a favorite pet."],
        addon.L["If you don't have any favorite pets, it'll choose from your whole collection."]
end

updateRandomIcon = function()
    if not randomButton then return end
    randomButton._icon:SetTexture(CO.RandomIcon[kind()])
    randomButton._caption:SetText(randomLabel())
end

refresh = function()
    if not (frame and frame:IsShown()) then return end

    rebuild()
    if CO.RefreshTabAlerts then CO.RefreshTabAlerts() end
    local collected = CO.CollectedCount(kind())

    -- The selection can be gone (unlearned or filtered out): fall back to what is out, then the head.
    if not CO.Find(kind(), selected[kind()]) then
        local active = CO.Active(kind())
        selected[kind()] = active and active.spellID or (flat[1] and flat[1].spellID)
    end

    -- The pill counts what you actually own, like retail -- not the catalog rows beside them.
    countLabel:SetText(isMount() and addon.L["Total Mounts"] or addon.L["Total Pets"])
    countText:SetText(collected)
    updateRandomIcon()
    if collected == 0 and #flat == 0 then emptyText:Show() else emptyText:Hide() end

    repaint()
    updateInfo()
end

CO.RefreshJournal = refresh

local function rowMenuInit()
    local entry = menuEntry
    if not entry then return end
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true

    if entry.active then
        info.text = isMount() and BINDING_NAME_DISMOUNT or PET_DISMISS
    else
        info.text = isMount() and MOUNT or SUMMON
    end
    info.func = function() CO.Summon(kind(), entry); refresh() end
    UIDropDownMenu_AddButton(info)

    local fav = CO.IsFavorite(kind(), entry.creatureID)
    info.text = fav and addon.L["Remove Favorite"] or addon.L["Favorite"]
    info.func = function() CO.ToggleFavorite(kind(), entry.creatureID); refresh() end
    UIDropDownMenu_AddButton(info)

    info.text = CANCEL
    info.func = nil
    UIDropDownMenu_AddButton(info)
end

-- Only the sources actually present, so the submenu never lists a category that filters nothing.
local function presentSources()
    local seen, out = {}, {}
    for _, entry in ipairs(CO.List(kind())) do
        local index = CO.SourceIndex(kind(), entry.spellID)
        if not seen[index] then
            seen[index] = true
            out[#out + 1] = index
        end
    end
    table.sort(out)
    return out
end

local function addToggle(level, text, key)
    local info = UIDropDownMenu_CreateInfo()
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.text = text
    info.checked = function() return filters[key] end
    info.func = function(_, _, _, checked)
        filters[key] = checked and true or false
        refresh()
    end
    UIDropDownMenu_AddButton(info, level)
end

-- UIDropDownMenu_Refresh on 3.3.5a is the SELECTION redraw: it hides every check whose button does
-- not match the dropdown's selected value, which wipes a multi-toggle menu. Re-assert them here.
local function syncMenuChecks(level)
    for i = 1, UIDROPDOWNMENU_MAXBUTTONS do
        local button = _G["DropDownList" .. level .. "Button" .. i]
        local check = _G["DropDownList" .. level .. "Button" .. i .. "Check"]
        if button and check then
            if button:IsShown() and type(button.checked) == "function" and button.checked() then
                check:Show()
            else
                check:Hide()
            end
        end
    end
end

local function filterMenuInit(_, level)
    level = level or 1

    if level == 1 then
        addToggle(level, addon.L["Collected"], "collected")
        addToggle(level, addon.L["Not Collected"], "notCollected")
        addToggle(level, addon.L["Favorites"], "favoritesOnly")

        if isMount() then
            addToggle(level, addon.L["Unusable here"], "unusable")

            local header = UIDropDownMenu_CreateInfo()
            header.text = TYPE
            header.isTitle = true
            header.notCheckable = true
            UIDropDownMenu_AddButton(header, level)

            addToggle(level, addon.L["Ground"], "ground")
            addToggle(level, addon.L["Flying"], "flying")
            addToggle(level, addon.L["Aquatic"], "aquatic")
        end

        local sources = UIDropDownMenu_CreateInfo()
        sources.text = addon.L["Sources"]
        sources.notCheckable = true
        sources.hasArrow = true
        sources.value = "sources"
        UIDropDownMenu_AddButton(sources, level)
        return
    end

    if level == 2 and UIDROPDOWNMENU_MENU_VALUE == "sources" then
        local function redraw()
            refresh()
            syncMenuChecks(level)
        end

        local all = UIDropDownMenu_CreateInfo()
        all.notCheckable = true
        all.keepShownOnClick = true
        all.text = addon.L["Check All"]
        all.func = function() wipe(filters.hiddenSources); redraw() end
        UIDropDownMenu_AddButton(all, level)

        all.text = addon.L["Uncheck All"]
        all.func = function()
            wipe(filters.hiddenSources)
            for _, index in ipairs(presentSources()) do filters.hiddenSources[index] = true end
            redraw()
        end
        UIDropDownMenu_AddButton(all, level)

        for _, index in ipairs(presentSources()) do
            local info = UIDropDownMenu_CreateInfo()
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.text = CO.SourceLabel(index)
            info.checked = function() return not filters.hiddenSources[index] end
            info.func = function(_, _, _, checked)
                filters.hiddenSources[index] = (not checked) and true or nil
                refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

-- Retail's grey filter dropdown in place of the red panel button: a three-slice holder so the ends
-- keep their radius, with the arrow box sitting on its right end.
-- Sized near the art's native 97x26 so the baked-in chevron barely stretches, and the 2px of
-- transparent margin the rect carries is pushed back past the button edge.
local FILTER_W = 92
local HOLDER_PAD = 2

local function dressFilterButton(btn)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture",
                              "GetDisabledTexture", "GetHighlightTexture" }) do
        local tex = btn[getter] and btn[getter](btn)
        if tex then tex:SetTexture(nil) end
    end
    local holder = btn:CreateTexture(nil, "BACKGROUND")
    holder:set_atlas("common-dropdown-b-button")
    holder:SetPoint("TOPLEFT", btn, "TOPLEFT", -HOLDER_PAD, HOLDER_PAD)
    holder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", HOLDER_PAD, -HOLDER_PAD)

    -- The whole background is the state, the way WowStyle1FilterDropdownMixin drives it. No wash
    -- over the top: `open` is a distinct art from `hover`, and a white overlay cannot say that.
    local over, down = false, false
    local function restate()
        local suffix = ""
        if not btn:IsEnabled() then
            suffix = "-disabled"
        elseif UIDROPDOWNMENU_OPEN_MENU == filterMenu and DropDownList1 and DropDownList1:IsShown() then
            suffix = "-open"
        elseif down and over then
            suffix = "-pressedhover"
        elseif down then
            suffix = "-pressed"
        elseif over then
            suffix = "-hover"
        end
        holder:set_atlas("common-dropdown-b-button" .. suffix)
    end

    btn:HookScript("OnEnter", function() over = true; restate() end)
    btn:HookScript("OnLeave", function() over = false; restate() end)
    btn:HookScript("OnMouseDown", function() down = true; restate() end)
    -- Next frame: the menu's shown state is only settled after the click has been handled.
    btn:HookScript("OnMouseUp", function() down = false; addon:After(0, restate) end)
    btn:HookScript("OnEnable", restate)
    btn:HookScript("OnDisable", restate)
    -- Retail displaces the LABEL and leaves the art still; Wrath's template shifts it by (1,-1).
    if btn.SetPushedTextOffset then btn:SetPushedTextOffset(2, -1) end
    btn._duiRestate = restate
end

local function buildSearch(parent)
    filterButton = CreateFrame("Button", "DragonUICollectionsFilterButton", parent, "UIPanelButtonTemplate")
    filterButton:SetSize(FILTER_W, SEARCH_H)
    filterButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    filterButton:SetText(FILTER)
    dressFilterButton(filterButton)
    local label = filterButton:GetFontString()
    if label then
        label:ClearAllPoints()
        -- The chevron lives in the art's last fifth, so the label stops short of it.
        label:SetPoint("LEFT", filterButton, "LEFT", 8, 0)
        label:SetPoint("RIGHT", filterButton, "RIGHT", -math.floor(FILTER_W * 0.2), 0)
        label:SetJustifyH("CENTER")
    end
    filterButton:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, filterMenu, self, 0, 0)
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    -- Named because InputBoxTemplate builds its border out of $parent-prefixed regions.
    searchBox = CreateFrame("EditBox", "DragonUICollectionsSearchBox", parent, "InputBoxTemplate")
    searchBox:SetHeight(SEARCH_H)
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -8)
    searchBox:SetPoint("RIGHT", filterButton, "LEFT", -8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(18, 6, 0, 0)

    local glass = searchBox:CreateTexture(nil, "OVERLAY")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", searchBox, "LEFT", 2, -1.5)
    glass:SetTexture(CO.TEX.search)

    local hint = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", searchBox, "LEFT", 20, 0)
    hint:SetText(SEARCH)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then hint:Show() else hint:Hide() end
        query = string.lower(text)
        refresh()
    end)
    searchBox:SetScript("OnEditFocusGained", function() hint:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then hint:Show() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
end

local function buildTopBand(parent)
    -- A recessed pill rather than bare floating text, the way retail houses its collected count.
    countBox = CreateFrame("Frame", nil, parent)
    countBox:SetPoint("LEFT", parent, "LEFT", 48, 0)
    countBox:SetSize(COUNT_W, COUNT_H)
    countBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    countBox:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    countBox:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    -- Two strings, not one formatted line: that is why retail shows no colon. The number rides
    -- GameFontHighlight (white) against the label's GameFontNormal (gold), pinned to opposite ends.
    countText = countBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", countBox, "RIGHT", -COUNT_PAD, 0)
    countText:SetJustifyH("RIGHT")

    countLabel = countBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("LEFT", countBox, "LEFT", COUNT_PAD, 0)
    countLabel:SetPoint("RIGHT", countText, "LEFT", -3, 0)
    countLabel:SetJustifyH("LEFT")

    randomButton = CreateFrame("Button", nil, parent)
    randomButton:SetSize(RANDOM_SIZE, RANDOM_SIZE)
    randomButton:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
    local icon = randomButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(randomButton)
    -- 0.08, like every other icon here: 0.05 leaves the client bevel's bright corner pixel showing.
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    randomButton._icon = icon
    local border = randomButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture(FRAME_TEXTURE)
    border:SetVertexColor(unpack(FRAME_COLOR))
    border:SetPoint("TOPRIGHT", randomButton, FRAME_X, FRAME_TOP)
    border:SetPoint("BOTTOMLEFT", randomButton, -FRAME_X, -FRAME_X)
    randomButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    randomButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("RIGHT", randomButton, "LEFT", -6, 0)
    caption:SetWidth(150)
    caption:SetJustifyH("RIGHT")
    randomButton._caption = caption

    randomButton:SetScript("OnClick", function()
        CO.SummonRandomFavorite(kind())
        refresh()
    end)
    -- Hands over the macro already picked up; it is only created the first time someone drags it.
    randomButton:RegisterForDrag("LeftButton")
    randomButton:SetScript("OnDragStart", function()
        local index = CO.EnsureRandomMacro(kind())
        if index then PickupMacro(index) end
    end)
    randomButton:SetScript("OnEnter", function(self)
        local title, desc, fallback = randomTooltip()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(TOOLTIP_MIN_W, 1) end
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(desc, TOOLTIP_BODY[1], TOOLTIP_BODY[2], TOOLTIP_BODY[3], true)
        GameTooltip:AddLine(fallback, TOOLTIP_BODY[1], TOOLTIP_BODY[2], TOOLTIP_BODY[3], true)
        GameTooltip:AddLine(addon.L["Drag to place it on an action bar."], 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    -- The tooltip is shared, so the widened frame has to be handed back the way it was found.
    randomButton:SetScript("OnLeave", function()
        if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(0, 0) end
        GameTooltip:Hide()
    end)
end

function CO.BuildJournal(parent)
    local CP = addon.CharacterPanel
    if not (CP and CP.BuildListPane) then return end
    frame = parent

    rowMenu = CreateFrame("Frame", "DragonUICollectionsRowMenu", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(rowMenu, rowMenuInit, "MENU")
    filterMenu = CreateFrame("Frame", "DragonUICollectionsFilterMenu", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(filterMenu, filterMenuInit, "MENU")

    buildSearch(CO.LeftInset)
    scroll, content = CP.BuildListPane(CO.LeftInset, "DragonUICollectionsScroll", ROW_H, repaint, 0, SEARCH_H + 12)
    rows = CP.NewRowPool(content, buildRow)
    CP.PrewarmRowPools(scroll, ROW_H, { rows })
    scroll:HookScript("OnSizeChanged", repaint)

    emptyText = CO.LeftInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", CO.LeftInset, "CENTER", 0, 0)
    emptyText:SetText(addon.L["Nothing collected yet."])
    emptyText:Hide()

    buildInfo(CO.RightInset)
    buildTopBand(CO.TopBand)

    actionButton = CreateFrame("Button", "DragonUICollectionsActionButton", CO.BottomBand, "UIPanelButtonTemplate")
    -- Retail anchors this BOTTOMLEFT of the journal at 140x22, under the list; it is not centred.
    actionButton:SetSize(140, 22)
    actionButton:SetPoint("LEFT", CO.BottomBand, "LEFT", 0, 0)
    actionButton:SetScript("OnClick", function()
        CO.Summon(kind(), selectedEntry())
        refresh()
    end)
    -- Only the action button: the filter wears retail's grey dropdown, dressed in buildSearch.
    addon.SkinRedButton(actionButton)
end

CO.Subscribe(function()
    if frame and frame:IsShown() then refresh() end
end)
