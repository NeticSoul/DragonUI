-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The equipment manager as a sidebar pane instead of Blizzard's floating GearManagerDialog.
-- Written against Wrath's NAME-keyed API, so names are the identity throughout.
local ROW_H = 40
local ICON_SIZE = 34
-- retail PaperDollFrame.xml gives EquipSet and SaveSet 87x22 over a 172-wide pane -- half each.
-- The height is the number worth copying; the width is derived in layout() from our own pane.
local BUTTON_H = 22
local BUTTON_GAP = 4
local BUTTON_INSET = 2
-- Everything below the button row: their height plus the inset above and the gap under them.
local LIST_TOP = BUTTON_H + BUTTON_INSET + BUTTON_GAP
local ACTION_SIZE = 15
local CHECK_SIZE = 16
local SPEC_BADGE_SIZE = 16
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
-- The talent frame's spec tab shows this while a spec has no points spent.
local NO_POINTS_SPEC_ICON = "Interface\\Icons\\Ability_Marksmanship"

local NORMAL = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
local RED = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
local GREEN = GREEN_FONT_COLOR or { r = 0.1, g = 1, b = 0.1 }

local pane, scroll, scrollChild, equipButton, saveButton
local rows, newRow = {}, nil
local selectedName
local refresh

-- Backend: everything touching the equipment API, so the UI never cares that sets are keyed by name.

local function maxSets()
    return MAX_EQUIPMENT_SETS_PER_PLAYER or 10
end

local function setList()
    local out = {}
    for i = 1, (GetNumEquipmentSets and GetNumEquipmentSets() or 0) do
        local name, texture = GetEquipmentSetInfo(i)
        if name then out[#out + 1] = { name = name, texture = texture } end
    end
    return out
end

local function setInfo(name)
    if not name or not GetEquipmentSetInfoByName then return nil end
    return GetEquipmentSetInfoByName(name)
end

-- GetEquipmentSetItemIDs returns sentinels alongside item IDs: 0 wants the slot bare, 1 ignores it,
-- -1 means the item is gone. Treating those as items left a set "equipped" while you wore something.
local EMPTY_SLOT = EQUIPMENT_SET_EMPTY_SLOT or 0
local IGNORED_SLOT = EQUIPMENT_SET_IGNORED_SLOT or 1
local ITEM_MISSING = EQUIPMENT_SET_ITEM_MISSING or -1

local function setItemIDs(name)
    if not name or not GetEquipmentSetItemIDs then return nil end
    local ok, ids = pcall(GetEquipmentSetItemIDs, name)
    if not ok then return nil end
    return ids
end

-- Computed: GetEquipmentSetInfoByName's isEquipped is only populated once the set is touched.
local function isEquipped(name)
    local ids = setItemIDs(name)
    if not ids then return false end

    for slot, wanted in pairs(ids) do
        if wanted == IGNORED_SLOT then
            -- the set has no opinion on this slot
        elseif wanted == ITEM_MISSING then
            return false
        elseif wanted == EMPTY_SLOT then
            if GetInventoryItemID("player", slot) then return false end
        elseif GetInventoryItemID("player", slot) ~= wanted then
            return false
        end
    end
    return true
end

local function missingCount(name)
    local ids = setItemIDs(name)
    if not ids then return 0 end

    local missing = 0
    for _, wanted in pairs(ids) do
        if wanted == ITEM_MISSING then missing = missing + 1 end
    end
    return missing
end

-- SaveEquipmentSet takes an INDEX into the icon list, never a path. GetEquipmentSetIconInfo walks
-- the equipped items first, so their count bounds the scan above GetNumMacroIcons.
local function iconIndexForTexture(path)
    if type(path) == "number" then return path end
    if not path or not GetEquipmentSetIconInfo or not GetNumMacroIcons then return 1 end

    if RefreshEquipmentSetIconInfo then RefreshEquipmentSetIconInfo() end
    local total = (GetNumMacroIcons() or 0) + 19
    for i = 1, total do
        local texture, realIndex = GetEquipmentSetIconInfo(i)
        if texture == path then return realIndex or i end
    end
    return 1
end

-- The slot flyout arrows belong to the paperdoll, but GearManagerDialog_OnShow is what reveals them.
local function setSlotFlyoutsShown(shown)
    if shown then
        if EquipmentManagerClearIgnoredSlotsForSave then EquipmentManagerClearIgnoredSlotsForSave() end
        if PaperDollFrameItemPopoutButton_ShowAll then PaperDollFrameItemPopoutButton_ShowAll() end
    else
        if PaperDollFrame_ClearIgnoredSlots then PaperDollFrame_ClearIgnoredSlots() end
        if PaperDollFrameItemPopoutButton_HideAll then PaperDollFrameItemPopoutButton_HideAll() end
    end
end

-- Only on an explicit selection: refresh also fires on bag changes, and running it there would wipe
-- ignores toggled by hand.
local function syncIgnoredSlots()
    if PaperDollFrame_ClearIgnoredSlots then PaperDollFrame_ClearIgnoredSlots() end
    if selectedName and PaperDollFrame_IgnoreSlotsForSet then
        PaperDollFrame_IgnoreSlotsForSet(selectedName)
    end
end

local function equipSet(name)
    if not name then return end
    -- EquipmentManager_EquipSet guards locked items and an in-progress swap; UseEquipmentSet does not.
    if EquipmentManager_EquipSet then
        EquipmentManager_EquipSet(name)
    else
        UseEquipmentSet(name)
    end
end

local function pickupSet(name)
    if not name then return end
    if PickupEquipmentSetByName then
        PickupEquipmentSetByName(name)
    elseif PickupEquipmentSet then
        PickupEquipmentSet(name)
    end
end

-- db.char.specEquipmentSets[talent group] = set name: one set per spec and one spec per set, as in retail.
local function specSets()
    return addon.db and addon.db.char and addon.db.char.specEquipmentSets
end

local function specForSet(name)
    local sets = specSets()
    if not sets or not name then return nil end
    for group = 1, MAX_TALENT_GROUPS or 2 do
        if sets[group] == name then return group end
    end
end

-- name nil frees the spec; a set given to this spec leaves the one it served before.
function CP.AssignSpecSet(group, name)
    local char = addon.db and addon.db.char
    if not char then return end
    char.specEquipmentSets = char.specEquipmentSets or {}
    local previous = specForSet(name)
    if previous then char.specEquipmentSets[previous] = nil end
    char.specEquipmentSets[group] = name
    refresh()
end

local function specName(group)
    return addon.GetTalentSpecName and addon.GetTalentSpecName(group)
        or (group == 2 and TALENT_SPEC_SECONDARY or TALENT_SPEC_PRIMARY)
end

-- The talent frame's spec-tab rule: the icon of the tree with the most points.
local function specIcon(group)
    local icon, most = NO_POINTS_SPEC_ICON, 0
    for tab = 1, GetNumTalentTabs(false, false) or 0 do
        local _, texture, points = GetTalentTabInfo(tab, false, false, group)
        if (points or 0) > most then icon, most = texture, points end
    end
    return icon
end

-- Icon picker. Blizzard's GearManagerDialogPopup already is one, and it is a child of the hidden
-- GearManagerDialog, so it only needs reparenting to be usable on its own.

local picker = {}

local function restorePickerOkay()
    local okay = _G.GearManagerDialogPopupOkay
    if okay and picker.okayScript then
        okay:SetScript("OnClick", picker.okayScript)
        picker.okayScript = nil
    end
    picker.origName = nil
end

-- Blizzard's MacroPopup art goes; the faction detail popup's dressing (reputationdetail.lua) comes in.
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_INSET = 7
-- Clear of the Dialog rail, which runs 16.5 in from every edge.
local PICKER_BUTTON_INSET = 20
-- Below the icon grid (3 rows from -85 end at -209); the spec section adds its own height under it.
local PICKER_H, PICKER_SPEC_H = 262, 43
local PICKER_SPEC_TOP = 219
-- The scrollbar's column, right of the icon grid; ReskinScrollBar insets its track 7 from each end.
local PICKER_BAR_RIGHT, PICKER_BAR_TOP, PICKER_BAR_BOTTOM = 24, 85 - 7, 209 + 7

local specSection

local function dressPicker(popup)
    for _, region in ipairs({ popup:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:Hide() end
    end
    local ground = popup:CreateTexture(nil, "BACKGROUND")
    ground:SetTexture(DIALOG_BG, "REPEAT", "REPEAT")
    ground:SetHorizTile(true)
    ground:SetVertTile(true)
    ground:SetPoint("TOPLEFT", popup, "TOPLEFT", DIALOG_INSET, -DIALOG_INSET)
    ground:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -DIALOG_INSET, DIALOG_INSET)
    CP.DialogGrounds = CP.DialogGrounds or {}
    tinsert(CP.DialogGrounds, ground)
    CP.ApplyBodyBackground()

    local border = CreateFrame("Frame", nil, popup)
    border:SetAllPoints(popup)
    border:SetFrameLevel(popup:GetFrameLevel() + 2)
    local layout = DragonUI_NineSlice and DragonUI_NineSlice.GetLayout("Dialog")
    if layout then DragonUI_NineSlice.ApplyLayout(border, layout) end

    local cancel = _G.GearManagerDialogPopupCancel
    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -PICKER_BUTTON_INSET, PICKER_BUTTON_INSET)
    end
    if addon.SkinRedButton then
        addon.SkinRedButton(_G.GearManagerDialogPopupOkay)
        addon.SkinRedButton(cancel)
    end

    local scroll = _G.GearManagerDialogPopupScrollFrame
    if scroll and CP.ReskinScrollBar then
        -- The scroll frame's own regions are the carved trainer groove.
        for _, region in ipairs({ scroll:GetRegions() }) do
            if region:GetObjectType() == "Texture" then region:Hide() end
        end
        local column = CreateFrame("Frame", nil, popup)
        -- Without a width it has no rect at all, and the bar anchored to it gets none either.
        column:SetWidth(1)
        column:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PICKER_BAR_RIGHT, -PICKER_BAR_TOP)
        column:SetPoint("BOTTOMRIGHT", popup, "TOPRIGHT", -PICKER_BAR_RIGHT, -PICKER_BAR_BOTTOM)
        CP.ReskinScrollBar(scroll, column, 0, 0, 0, true)
    end
end

-- "Assign To:" inside the picker, so a set gets its spec while it is created or edited.
local function buildSpecSection(popup)
    specSection = CreateFrame("Frame", nil, popup)
    specSection:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -PICKER_SPEC_TOP)
    specSection:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, -PICKER_SPEC_TOP)
    specSection:SetHeight(PICKER_SPEC_H)

    local title = specSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", specSection, "TOPLEFT", 24, -2)
    title:SetText(addon.L["Assign To:"])

    specSection.checks = {}
    for group = 1, MAX_TALENT_GROUPS or 2 do
        local check = CreateFrame("CheckButton", "DragonUIEquipSetSpecCheck" .. group, specSection,
            "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", specSection, "TOPLEFT", 20 + (group - 1) * 130, -14)
        _G[check:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
        CP.SkinCheckbox(check)
        -- One spec per set: ticking one clears the other.
        check:SetScript("OnClick", function(self)
            for _, other in ipairs(specSection.checks) do
                if other ~= self then other:SetChecked(false) end
            end
        end)
        specSection.checks[group] = check
    end
end

local function syncSpecSection(popup, name)
    local groups = GetNumTalentGroups and GetNumTalentGroups(false, false) or 1
    if groups < 2 then
        if specSection then specSection:Hide() end
        popup:SetHeight(PICKER_H)
        return
    end
    if not specSection then buildSpecSection(popup) end
    local current = specForSet(name)
    for group, check in ipairs(specSection.checks) do
        _G[check:GetName() .. "Text"]:SetFormattedText("|T%s:14:14|t %s", specIcon(group), specName(group))
        check:SetChecked(group == current)
        check:SetShownCompat(group <= groups)
    end
    specSection:Show()
    popup:SetHeight(PICKER_H + PICKER_SPEC_H)
end

local function chosenSpec()
    if not specSection or not specSection:IsShown() then return nil end
    for group, check in ipairs(specSection.checks) do
        if check:GetChecked() then return group end
    end
end

-- This client has no RenameEquipmentSet, so a rename is a save under the new name plus a delete of
-- the old. Both write the gear worn right now, which is what SaveEquipmentSet does regardless.
local function pickerOkay(...)
    local popup = _G.GearManagerDialogPopup
    local newName = popup and popup.name
    if not newName or newName == "" or not popup.selectedIcon then return end

    local orig = picker.origName
    if newName ~= orig and setInfo(newName) then
        -- A new set under a taken name keeps Blizzard's own overwrite confirmation.
        if not orig and picker.okayScript then return picker.okayScript(...) end
        UIErrorsFrame:AddMessage(addon.L["A set with that name already exists."], 1, 0.1, 0.1, 1)
        return
    end

    local _, iconIndex = GetEquipmentSetIconInfo(popup.selectedIcon)
    local spec = orig and specForSet(orig)
    if specSection and specSection:IsShown() then spec = chosenSpec() end
    SaveEquipmentSet(newName, iconIndex)
    if orig and newName ~= orig then DeleteEquipmentSet(orig) end
    local old = orig and specForSet(orig)
    if old then CP.AssignSpecSet(old, nil) end
    if spec then CP.AssignSpecSet(spec, newName) end

    selectedName = newName
    popup:Hide()
    refresh()
end

local function preparePicker()
    local popup = _G.GearManagerDialogPopup
    if not popup then return nil end

    if not popup._duiAdopted then
        popup._duiAdopted = true
        popup:SetParent(UIParent)
        popup:SetFrameStrata("DIALOG")
        popup:SetToplevel(true)
        dressPicker(popup)
        popup:HookScript("OnHide", restorePickerOkay)
        if not tContains(UISpecialFrames, "GearManagerDialogPopup") then
            tinsert(UISpecialFrames, "GearManagerDialogPopup")
        end
    end

    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", _G.CharacterFrame, "TOPRIGHT", 4, 0)
    return popup
end

local function openPicker(name, texture)
    local popup = preparePicker()
    if not popup then return end

    -- Blizzard's OnShow reads GearManagerDialog.selectedSet and would pull its own selection in.
    if _G.GearManagerDialog then _G.GearManagerDialog.selectedSet = nil end

    restorePickerOkay()
    picker.origName = name
    local okay = _G.GearManagerDialogPopupOkay
    if okay then
        picker.okayScript = okay:GetScript("OnClick")
        okay:SetScript("OnClick", pickerOkay)
    end

    popup:Show()
    syncSpecSection(popup, name)
    if texture then popup:SetSelection(true, texture) end
    local editBox = _G.GearManagerDialogPopupEditBox
    if editBox then
        editBox:SetText(name or "")
        editBox:SetFocus()
        if name then editBox:HighlightText() end
    end
    if RecalculateGearManagerDialogPopup then RecalculateGearManagerDialogPopup() end
end

StaticPopupDialogs["DRAGONUI_DELETE_EQUIPMENT_SET"] = {
    text = addon.L["Delete the equipment set '%s'?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name)
        local spec = specForSet(name)
        DeleteEquipmentSet(name)
        if spec then CP.AssignSpecSet(spec, nil) end
        if selectedName == name then selectedName = nil end
        refresh()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

StaticPopupDialogs["DRAGONUI_SAVE_EQUIPMENT_SET"] = {
    text = addon.L["Overwrite '%s' with your currently equipped items?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name)
        SaveEquipmentSet(name, iconIndexForTexture(setInfo(name)))
        refresh()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

-- Entering a child button fires the row's OnLeave, so both ends re-test the row rect (which stays
-- true over a child) instead of hiding blind.
local function updateRowActions(row)
    local wanted = row.setName ~= nil and row:IsMouseOver()
    row.Edit:SetShownCompat(wanted)
    row.Delete:SetShownCompat(wanted)
end

local function buildActionButton(row, texture, tooltip, warning, onClick)
    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(ACTION_SIZE, ACTION_SIZE)

    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(texture)
    tex:SetAllPoints(btn)
    tex:SetAlpha(0.6)

    btn:SetScript("OnEnter", function(self)
        tex:SetAlpha(1)
        if not tooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        if warning then GameTooltip:AddLine(warning, 1, 0.4, 0.4, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        tex:SetAlpha(0.6)
        GameTooltip:Hide()
        updateRowActions(row)
    end)
    btn:SetScript("OnClick", onClick)
    btn:Hide()
    return btn
end

-- Retail's gear menu: rename/icon, then the specs to equip this set on.
local function openSetMenu(row)
    local name = row.setName
    if not name then return end
    local L = addon.L
    local entries = {
        {
            text = L["Rename or change the icon"],
            func = function() openPicker(name, row.Icon:GetTexture()) end,
            tooltip = function(tip)
                tip:SetText(L["Rename or change the icon"], 1, 1, 1)
                tip:AddLine(L["This client can only re-save a set, so the gear you are wearing now replaces its contents."],
                    1, 0.4, 0.4, true)
            end,
        },
    }
    -- Without dual specialization there is no swap to equip on.
    local groups = GetNumTalentGroups and GetNumTalentGroups(false, false) or 1
    if groups > 1 then
        entries[#entries + 1] = { text = L["Assign To:"], isTitle = true }
        for group = 1, groups do
            entries[#entries + 1] = {
                text = specName(group),
                icon = specIcon(group),
                keepShown = true,
                checked = function() return specForSet(name) == group end,
                func = function() CP.AssignSpecSet(group, specForSet(name) ~= group and name or nil) end,
            }
        end
    end
    -- At the cursor, like retail's context menu: the gear itself hides once the mouse leaves the row.
    addon.Menu.Open("cursor", entries, { clickAway = true })
end

function CP.BuildEquipmentRow(parent, index)
    local row = CreateFrame("Button", "DragonUIEquipSetRow" .. index, parent)
    row:SetHeight(ROW_H)

    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(row)
    stripe:SetTexture(0.9, 0.9, 1)
    stripe:SetAlpha(index % 2 == 0 and 0.1 or 0)

    local selected = row:CreateTexture(nil, "BORDER")
    selected:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
    selected:SetTexCoord(0.2, 0.8, 0, 1)
    selected:SetBlendMode("ADD")
    selected:SetAlpha(0.4)
    selected:SetAllPoints(row)
    selected:Hide()
    row.Selected = selected

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.Icon = icon

    -- Retail's spec badge on the icon's lower right; its own frame so it draws over the icon.
    local badge = CreateFrame("Frame", nil, row)
    badge:SetSize(SPEC_BADGE_SIZE, SPEC_BADGE_SIZE)
    badge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    local badgeEdge = badge:CreateTexture(nil, "BACKGROUND")
    badgeEdge:SetTexture(0, 0, 0, 1)
    badgeEdge:SetAllPoints(badge)
    badge.Icon = badge:CreateTexture(nil, "ARTWORK")
    badge.Icon:SetPoint("TOPLEFT", badge, "TOPLEFT", 1, -1)
    badge.Icon:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -1, 1)
    badge.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badge:Hide()
    row.SpecBadge = badge

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    text:SetPoint("LEFT", row, "LEFT", 42, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -CHECK_SIZE - 12, 0)
    text:SetJustifyH("LEFT")
    row.Text = text

    -- The vanilla UI-CheckBox-Check has uneven padding inside its art; the atlas glyph is cut tight.
    local check = row:CreateTexture(nil, "OVERLAY")
    check:SetAtlasTexture("common-icon-checkmark")
    check:SetSize(CHECK_SIZE, CHECK_SIZE)
    check:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    check:Hide()
    row.Check = check

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local hl = row:GetHighlightTexture()
    if hl then
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
    end

    row.Delete = buildActionButton(row, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", DELETE, nil,
        function(self)
            local parentRow = self:GetParent()
            if parentRow.setName then
                StaticPopup_Show("DRAGONUI_DELETE_EQUIPMENT_SET", parentRow.setName, nil, parentRow.setName)
            end
        end)
    -- Chained leftwards off the tick instead of sharing the same corner with it.
    row.Delete:SetPoint("RIGHT", check, "LEFT", -6, 0)

    row.Edit = buildActionButton(row, "Interface\\WorldMap\\Gear_64Grey", nil, nil,
        function(self) openSetMenu(self:GetParent()) end)
    row.Edit:SetPoint("RIGHT", row.Delete, "LEFT", -2, 0)

    row:RegisterForClicks("LeftButtonUp")
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self) pickupSet(self.setName) end)

    row:SetScript("OnClick", function(self)
        if not self.setName then
            openPicker(nil, nil)
            return
        end
        selectedName = self.setName
        syncIgnoredSlots()
        refresh()
    end)
    row:SetScript("OnDoubleClick", function(self) equipSet(self.setName) end)

    row:SetScript("OnEnter", function(self)
        updateRowActions(self)
        if not self.setName then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetEquipmentSet(self.setName)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        updateRowActions(self)
        GameTooltip:Hide()
    end)

    return row
end

-- Sized here rather than in build: the pane takes its width from InsetRight, which has none while
-- the builders run, so a width computed there came out negative.
local function layout()
    local width = pane:GetWidth() or 0
    if width <= 0 then return end

    -- Half the pane each, butted together. Retail hardcodes 87, but its pane is 172 wide, so that
    -- IS half -- the pair is meant to span the pane, and a literal 87 leaves a gap on a wider one.
    local half = math.floor(width / 2)
    equipButton:SetWidth(half)
    saveButton:SetWidth(width - half)
    scrollChild:SetWidth(scroll:GetWidth() or width)
end

function refresh()
    if not pane or not pane:IsShown() then return end
    layout()

    local sets = setList()
    for i, info in ipairs(sets) do
        local row = rows[i] or CP.BuildEquipmentRow(scrollChild, i)
        rows[i] = row
        row.setName = info.name
        row.Icon:Show()
        row.Icon:SetTexture(info.texture or QUESTION_MARK)
        row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.Text:SetText(info.name)

        if missingCount(info.name) > 0 then
            row.Text:SetTextColor(RED.r, RED.g, RED.b)
        else
            row.Text:SetTextColor(NORMAL.r, NORMAL.g, NORMAL.b)
        end

        row.Check:SetShownCompat(isEquipped(info.name))
        row.Selected:SetShownCompat(info.name == selectedName)
        local spec = specForSet(info.name)
        if spec then row.SpecBadge.Icon:SetTexture(specIcon(spec)) end
        row.SpecBadge:SetShownCompat(spec ~= nil)
        updateRowActions(row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * ROW_H)
        row:Show()
    end
    for i = #sets + 1, #rows do rows[i]:Hide() end

    newRow:ClearAllPoints()
    newRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -#sets * ROW_H)
    newRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -#sets * ROW_H)
    newRow:SetShownCompat(#sets < maxSets())

    scrollChild:SetHeight(math.max(1, (#sets + 1) * ROW_H))
    if CP.SyncScrollBarVisibility then CP.SyncScrollBarVisibility(scroll) end
    if CP.SyncScrollThumb then CP.SyncScrollThumb(scroll) end

    -- A set you are already wearing offers neither action.
    local actionable = selectedName ~= nil and not isEquipped(selectedName)
    if actionable then equipButton:Enable() else equipButton:Disable() end
    if actionable then saveButton:Enable() else saveButton:Disable() end
end

CP.RefreshEquipmentPane = refresh

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.InsetRight then return end

    pane = CreateFrame("Frame", "DragonUIEquipmentPane", cf.InsetRight)
    pane:SetPoint("TOPLEFT", cf.InsetRight, "TOPLEFT", 3, -3)
    pane:SetPoint("BOTTOMRIGHT", cf.InsetRight, "BOTTOMRIGHT", -3, 2)
    pane:Hide()

    -- Retail's own geometry: a fixed 87x22 pair butted together at the pane's top left, not one
    -- button per corner. Labels come from the client's globals, which are already localized.
    equipButton = CreateFrame("Button", "DragonUIEquipSetButton", pane, "UIPanelButtonTemplate")
    equipButton:SetHeight(BUTTON_H)
    equipButton:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    equipButton:SetText(EQUIPSET_EQUIP or addon.L["Equip"])
    equipButton:SetScript("OnClick", function() equipSet(selectedName) end)

    saveButton = CreateFrame("Button", "DragonUISaveSetButton", pane, "UIPanelButtonTemplate")
    saveButton:SetHeight(BUTTON_H)
    saveButton:SetPoint("LEFT", equipButton, "RIGHT", 0, 0)
    saveButton:SetText(SAVE or addon.L["Save"])
    saveButton:SetScript("OnClick", function()
        if selectedName then
            StaticPopup_Show("DRAGONUI_SAVE_EQUIPMENT_SET", selectedName, nil, selectedName)
        end
    end)

    -- Retail's UIPanelButtonTemplate carries modern art; Wrath's is the carved grey one, so the
    -- template alone is not enough to match it. Same skin the collections buttons already wear.
    if addon.SkinRedButton then
        addon.SkinRedButton(equipButton)
        addon.SkinRedButton(saveButton)
    end
    -- Above the list, the way retail raises them in its OnLoad: the scroll box starts at the pane's
    -- own top edge, so at the same level the rows would draw over the buttons.
    equipButton:SetFrameLevel(pane:GetFrameLevel() + 3)
    saveButton:SetFrameLevel(pane:GetFrameLevel() + 3)

    scroll = CreateFrame("ScrollFrame", "DragonUIEquipmentScroll", pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -LIST_TOP)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -12, 0)
    if CP.ReskinScrollBar then CP.ReskinScrollBar(scroll, pane, LIST_TOP) end
    if CP.AutoHideScrollBar then CP.AutoHideScrollBar(scroll, pane, 12, 0, layout) end

    scrollChild = CreateFrame("Frame", "DragonUIEquipmentScrollChild", scroll)
    scroll:SetScrollChild(scrollChild)
    pane:SetScript("OnShow", function()
        layout()
        setSlotFlyoutsShown(true)
        syncIgnoredSlots()
    end)
    pane:SetScript("OnHide", function() setSlotFlyoutsShown(false) end)

    -- No icon: 3.3.5a ships no Character-Plus, and a pooled row would keep the set above's art.
    newRow = CP.BuildEquipmentRow(scrollChild, 0)
    newRow.setName = nil
    newRow.Icon:Hide()
    newRow.Text:SetPoint("LEFT", newRow, "LEFT", 8, 0)
    newRow.Text:SetText(addon.L["New Equipment Set"])
    newRow.Text:SetTextColor(GREEN.r, GREEN.g, GREEN.b)
    newRow:SetScript("OnDoubleClick", nil)
end

CP.EquipmentPane = function() return pane end

local function equipSpecSet(group)
    local sets = specSets()
    local name = sets and sets[group]
    if name and setInfo(name) and not isEquipped(name) then
        equipSet(name)
    end
end

local activeGroup
local specEvents = CreateFrame("Frame")
specEvents:RegisterEvent("PLAYER_LOGIN")
specEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
specEvents:SetScript("OnEvent", function(_, event)
    local group = GetActiveTalentGroup and GetActiveTalentGroup()
    -- Only a real swap equips: the login value is just the baseline to compare against.
    if event == "PLAYER_LOGIN" or not group or group == activeGroup then
        activeGroup = group
        return
    end
    activeGroup = group
    if InCombatLockdown() then
        addon.CombatQueue:Add("spec_equipment_set", equipSpecSet, group)
    else
        equipSpecSet(group)
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
events:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Losing a set's item to a drop, a sale or a bank deposit announces nothing the equipment API sees.
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
-- The spec badges show each spec's main talent tree.
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:SetScript("OnEvent", function(_, event, completed, setName)
    if event == "EQUIPMENT_SWAP_FINISHED" and completed and setName then
        selectedName = setName
    end
    refresh()
end)

CP:RegisterBuilder("equipmentpane", build)
