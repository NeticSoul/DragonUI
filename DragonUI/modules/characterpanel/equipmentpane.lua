local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The equipment manager as a sidebar pane instead of Blizzard's floating GearManagerDialog.
-- Written against Wrath's NAME-keyed API, so names are the identity throughout.
local ROW_H = 40
local ICON_SIZE = 34
local BUTTON_H = 22
local BUTTON_GAP = 4
local BUTTON_INSET = 2
-- Everything below the button row: their height plus the inset above and the gap under them.
local LIST_TOP = BUTTON_H + BUTTON_INSET + BUTTON_GAP
local ACTION_SIZE = 15
local CHECK_SIZE = 16
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

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

-- This client has no RenameEquipmentSet, so a rename is a save under the new name plus a delete of
-- the old. Both write the gear worn right now, which is what SaveEquipmentSet does regardless.
local function pickerOkayForEdit()
    local popup = _G.GearManagerDialogPopup
    local newName = popup and popup.name
    if not newName or newName == "" or not popup.selectedIcon then return end

    local orig = picker.origName
    if newName ~= orig and setInfo(newName) then
        UIErrorsFrame:AddMessage(addon.L["A set with that name already exists."], 1, 0.1, 0.1, 1)
        return
    end

    local _, iconIndex = GetEquipmentSetIconInfo(popup.selectedIcon)
    SaveEquipmentSet(newName, iconIndex)
    if orig and newName ~= orig then DeleteEquipmentSet(orig) end

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
    if name then
        picker.origName = name
        local okay = _G.GearManagerDialogPopupOkay
        if okay then
            picker.okayScript = okay:GetScript("OnClick")
            okay:SetScript("OnClick", pickerOkayForEdit)
        end
    end

    popup:Show()
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
        DeleteEquipmentSet(name)
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
    row.Edit:SetShownReq(wanted)
    row.Delete:SetShownReq(wanted)
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

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    text:SetPoint("LEFT", row, "LEFT", 42, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -CHECK_SIZE - 12, 0)
    text:SetJustifyH("LEFT")
    row.Text = text

    -- The vanilla UI-CheckBox-Check has uneven padding inside its art; the atlas glyph is cut tight.
    local check = row:CreateTexture(nil, "OVERLAY")
    check:set_atlas("common-icon-checkmark")
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

    row.Edit = buildActionButton(row, "Interface\\WorldMap\\Gear_64Grey",
        addon.L["Rename or change the icon"],
        addon.L["This client can only re-save a set, so the gear you are wearing now replaces its contents."],
        function(self)
            local parentRow = self:GetParent()
            if parentRow.setName then openPicker(parentRow.setName, parentRow.Icon:GetTexture()) end
        end)
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

    local half = math.floor((width - BUTTON_GAP - BUTTON_INSET * 2) / 2)
    equipButton:SetWidth(half)
    saveButton:SetWidth(half)
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

        row.Check:SetShownReq(isEquipped(info.name))
        row.Selected:SetShownReq(info.name == selectedName)
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
    newRow:SetShownReq(#sets < maxSets())

    scrollChild:SetHeight(math.max(1, (#sets + 1) * ROW_H))
    if CP.SyncScrollBarVisibility then CP.SyncScrollBarVisibility(scroll) end
    if CP.SyncScrollThumb then CP.SyncScrollThumb(scroll) end

    -- Matches the reference: a set you are already wearing offers neither action.
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

    equipButton = CreateFrame("Button", "DragonUIEquipSetButton", pane, "UIPanelButtonTemplate")
    equipButton:SetHeight(BUTTON_H)
    equipButton:SetPoint("TOPLEFT", pane, "TOPLEFT", BUTTON_INSET, -BUTTON_INSET)
    equipButton:SetText(addon.L["Equip"])
    equipButton:SetScript("OnClick", function() equipSet(selectedName) end)

    -- Its own width rather than chained off Equip's edge: chaining made one bad width break both.
    saveButton = CreateFrame("Button", "DragonUISaveSetButton", pane, "UIPanelButtonTemplate")
    saveButton:SetHeight(BUTTON_H)
    saveButton:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -BUTTON_INSET, -BUTTON_INSET)
    saveButton:SetText(addon.L["Save"])
    saveButton:SetScript("OnClick", function()
        if selectedName then
            StaticPopup_Show("DRAGONUI_SAVE_EQUIPMENT_SET", selectedName, nil, selectedName)
        end
    end)

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

    CP._equipmentPane = pane
end

CP.EquipmentPane = function() return pane end

local events = CreateFrame("Frame")
events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
events:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Losing a set's item to a drop, a sale or a bank deposit announces nothing the equipment API sees.
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
events:SetScript("OnEvent", function(_, event, completed, setName)
    if event == "EQUIPMENT_SWAP_FINISHED" and completed and setName then
        selectedName = setName
    end
    refresh()
end)

CP:RegisterBuilder("equipmentpane", build)
