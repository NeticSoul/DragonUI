-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local L = addon.L

-- Windows are ordered by strata because levels above ~120 misbehave; menus and popups sit in TOOLTIP above them.
local EditorUI = { STRATA = "FULLSCREEN_DIALOG", MANAGER = 20, DIALOG = 60, MODAL = 100, POPUP_STRATA = "TOOLTIP", POPUP = 70 }
addon.EditorUI = EditorUI

local max, min = math.max, math.min
local tinsert, tremove = table.insert, table.remove

-- The widest row (343) plus 2x26 of padding: the rails are thick, so the content needs room.
local DIALOG_WIDTH = 395
local ROW_WIDTH = 343
-- Dialogs with few settings narrow to just past the coordinate row (X box, two arrows).
local COMPACT_ROW_WIDTH = 306
local ROW_HEIGHT = 32
local ROW_GAP = 2
local LABEL_WIDTH = 118
local PAD_X, PAD_TOP, PAD_BOTTOM = 26, 48, 26
local SCREEN_MARGIN, SIDE_GAP = 8, 8
local COORD_INTERVAL, ROWS_INTERVAL = 0.05, 0.2

-- Assigned further down; api.lua reaches them through the addon.* wrappers.
local ApplySelectionTint, ClearSelectionTint
local selectedEditorFrame

local dialog
local dialogSet
local resetShown = false
local combatHidden = false
local dialogMoved = false
local placedFor

local RowKinds = {}
local brokenFns = setmetatable({}, { __mode = "k" })

-- A callback that errors is reported once and then ignored, so the 5/s poll cannot flood the handler.
local function Call(fn, ...)
    if type(fn) ~= "function" or brokenFns[fn] then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        brokenFns[fn] = true
        geterrorhandler()(result)
        return nil
    end
    return result
end

local function Safely(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        geterrorhandler()(err)
    end
    return ok
end

local function Resolve(value)
    if type(value) == "function" then
        return Call(value)
    end
    return value
end

-- ============================================================================
-- COORDINATES (Real-time X/Y + Nudge Buttons)
-- ============================================================================

-- GetCenter() is in the frame's own scaled space, so a raw cx-ux breaks once scale != 1.
local function GetFrameOffsetFromUIParent(frame)
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then return nil end
    local frameScale = frame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    local x = (cx * frameScale - ux * uiScale) / frameScale
    local y = (cy * frameScale - uy * uiScale) / frameScale
    return x, y
end

-- Polled so drags, nudges and module repositioning all show; skipped while typing.
local function UpdateCoords()
    if not dialog or not selectedEditorFrame then return end
    local x, y = GetFrameOffsetFromUIParent(selectedEditorFrame)
    if not (x and y) then return end
    local xText, yText = string.format("%.1f", x), string.format("%.1f", y)
    if not dialog.xBox:HasFocus() and dialog.xBox:GetText() ~= xText then
        dialog.xBox:SetText(xText)
    end
    if not dialog.yBox:HasFocus() and dialog.yBox:GetText() ~= yText then
        dialog.yBox:SetText(yText)
    end
end

local function MoveSelectedTo(x, y)
    selectedEditorFrame:ClearAllPoints()
    selectedEditorFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    selectedEditorFrame.DragonUI_WasAdjustedByEditor = true
    selectedEditorFrame.DragonUI_WasDragged = true
    selectedEditorFrame.DragonUI_LayoutOffset = nil
    -- Auto-save
    if addon.EditableFrames then
        for _, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == selectedEditorFrame then
                if frameData.configPath and #frameData.configPath == 2 then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                elseif frameData.configPath then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                -- Frames with their own save logic (no configPath, e.g. loot rolls) persist here.
                if frameData.onNudge then
                    frameData.onNudge()
                end
                break
            end
        end
    end
end

-- Apply coordinates typed by the user into the X/Y EditBoxes
local function ApplyTypedCoordinates()
    if not selectedEditorFrame or not dialog then return end
    local newX = tonumber(dialog.xBox:GetText())
    local newY = tonumber(dialog.yBox:GetText())
    if not newX or not newY then return end
    -- Position is relative to UIParent CENTER (matches what we display)
    MoveSelectedTo(newX, newY)
    -- Clear focus so live polling resumes
    dialog.xBox:ClearFocus()
    dialog.yBox:ClearFocus()
end

-- Move the selected frame by dx, dy pixels and auto-save
local function NudgeSelectedFrame(dx, dy)
    if not selectedEditorFrame then return end

    local relX, relY = GetFrameOffsetFromUIParent(selectedEditorFrame)
    if not relX or not relY then return end

    MoveSelectedTo(relX + dx, relY + dy)
    UpdateCoords()
end

local function GetSelectedEditableFrameData()
    if not selectedEditorFrame or not addon.EditableFrames then
        return nil, nil
    end

    for name, frameData in pairs(addon.EditableFrames) do
        if frameData.frame == selectedEditorFrame then
            return name, frameData
        end
    end

    return nil, nil
end

-- ============================================================================
-- PER-FRAME RESET
-- ============================================================================

local function ResetDetachedUnitframeToProfileDefaults(unitKey)
    local defaults = addon.defaults and addon.defaults.profile
    local profile = addon.db and addon.db.profile

    if not (defaults and profile and defaults.unitframe and defaults.unitframe[unitKey]) then
        return false
    end

    profile.unitframe = profile.unitframe or {}
    profile.unitframe[unitKey] = addon.DeepCopy(defaults.unitframe[unitKey], {})

    if defaults.widgets and defaults.widgets[unitKey] then
        profile.widgets = profile.widgets or {}
        profile.widgets[unitKey] = addon.DeepCopy(defaults.widgets[unitKey], {})
    end

    return true
end

local function GetDetachedResetActionForSelection()
    if not (addon and addon.db and addon.db.profile) then
        return nil, nil
    end

    local frameName, frameData = GetSelectedEditableFrameData()
    if not frameName then
        return nil, nil
    end

    if frameName == "TargetCastbar" then
        local cfg = addon.db.profile.castbar and addon.db.profile.castbar.target
        if cfg and cfg.override and addon.ResetTargetCastbarPosition then
            return function()
                addon.ResetTargetCastbarPosition()
            end, frameData
        end
    elseif frameName == "FocusCastbar" then
        local cfg = addon.db.profile.castbar and addon.db.profile.castbar.focus
        if cfg and cfg.override and addon.ResetFocusCastbarPosition then
            return function()
                addon.ResetFocusCastbarPosition()
            end, frameData
        end
    elseif frameName == "tot" then
        local cfg = addon.db.profile.unitframe and addon.db.profile.unitframe.tot
        if cfg and cfg.override and addon.TargetOfTarget and addon.TargetOfTarget.Refresh then
            return function()
                if ResetDetachedUnitframeToProfileDefaults("tot") then
                    addon.TargetOfTarget.Refresh()
                end
            end, frameData
        end
    elseif frameName == "fot" then
        local cfg = addon.db.profile.unitframe and addon.db.profile.unitframe.fot
        if cfg and cfg.override and addon.TargetOfFocus and addon.TargetOfFocus.Refresh then
            return function()
                if ResetDetachedUnitframeToProfileDefaults("fot") then
                    addon.TargetOfFocus.Refresh()
                end
            end, frameData
        end
    elseif frameName == "PetFrame" then
        local cfg = addon.db.profile.unitframe and addon.db.profile.unitframe.pet
        if cfg and cfg.override and addon.RefreshPetFrame then
            return function()
                if ResetDetachedUnitframeToProfileDefaults("pet") then
                    addon.RefreshPetFrame()
                end
            end, frameData
        end
    elseif frameName == "Debuffs" then
        local cfg = addon.db.profile.widgets and addon.db.profile.widgets.debuffs
        if cfg and cfg.custom_position and addon.BuffFrameModule and addon.BuffFrameModule.ResetDebuffPosition then
            return function()
                addon.BuffFrameModule:ResetDebuffPosition()
            end, frameData
        end
    elseif frameName == "buffs" then
        local cfg = addon.db.profile.widgets and addon.db.profile.widgets.buffs
        if cfg and cfg.custom_position and addon.BuffFrameModule and addon.BuffFrameModule.ResetBuffFramePosition then
            return function()
                addon.BuffFrameModule:ResetBuffFramePosition()
            end, frameData
        end
    elseif frameName == "durability" then
        local cfg = addon.db.profile.widgets and addon.db.profile.widgets.durability
        if cfg and cfg.custom_position and addon.MinimapModule and addon.MinimapModule.ResetDurabilityPosition then
            return function()
                addon.MinimapModule:ResetDurabilityPosition()
            end, frameData
        end
    end

    return nil, frameData
end

-- ============================================================================
-- ROW SETS (pooled rows bound to a registry def; shared by the settings dialog and the editor manager)
-- ============================================================================

local Layout, UpdateReset

local RowSet = {}
RowSet.__index = RowSet

-- Folded sections by scope (frame name) + header label, kept for the session so a re-selected frame looks the same.
local SectionState = {}
local Hiding

local function Shown(row)
    return not row.hidden and not row.folded
end

local function NewHolder(set, height)
    local holder = CreateFrame("Frame", nil, set.parent)
    holder:SetSize(set.rowWidth, height or ROW_HEIGHT)
    return holder
end

local function Commit(row, value)
    local def = row.def
    if not (def and def.set) then return end
    Safely(def.set, value)
    row.set:AfterChange()
end

local function SetDisabledState(row, control)
    local disabled = (row.set.locked or Call(row.def.disabled)) and true or false
    if row.disabled == disabled then return end
    row.disabled = disabled
    if disabled then
        control:Disable()
    else
        control:Enable()
    end
end

local function ItemsOf(def)
    if not def then return {} end
    local items = def.items
    if type(items) == "function" then
        items = Call(items)
    end
    return items or {}
end

RowKinds.slider = {
    height = ROW_HEIGHT,
    create = function(set)
        local row = { set = set }
        row.control = addon.ForeverUI.CreateSlider(set.parent, {
            label = " ", labelWidth = LABEL_WIDTH, min = 0, max = 1, step = 0.01, width = set.rowWidth,
            get = function() return row.def and Call(row.def.get) or 0 end,
            set = function(value)
                if IsMouseButtonDown("LeftButton") then row.dragging = true end
                Commit(row, value)
            end,
        })
        row.frame = row.control
        row.control.slider:HookScript("OnMouseDown", function() row.dragging = true end)
        return row
    end,
    bind = function(row, def)
        local control = row.control
        control:SetLabel(Resolve(def.label) or "")
        control:SetRange(def.min or 0, def.max or 1, def.step or 0.01)
        control:SetFormat(def.format)
    end,
    refresh = function(row)
        local control = row.control
        if row.dragging then
            if IsMouseButtonDown("LeftButton") then return end
            row.dragging = nil
        end
        local value = Call(row.def.get)
        if value ~= nil then
            control:SetValue(value)
        end
        SetDisabledState(row, control)
    end,
}

-- A tooltip of its own: GameTooltip is the editor's tooltip preview and sits below these windows.
local rowTooltip

local function ShowRowTooltip(row)
    local text = row.def and Resolve(row.def.tooltip)
    if not text or text == "" then return end
    if not rowTooltip then
        rowTooltip = CreateFrame("GameTooltip", "DragonUI_EditorRowTooltip", UIParent, "GameTooltipTemplate")
    end
    rowTooltip:SetOwner(row.control, "ANCHOR_RIGHT")
    rowTooltip:SetText(Resolve(row.def.label) or "", 1, 0.82, 0)
    rowTooltip:AddLine(text, 1, 1, 1, true)
    rowTooltip:Show()
end

local function HideRowTooltip()
    if rowTooltip then rowTooltip:Hide() end
end

RowKinds.checkbox = {
    height = ROW_HEIGHT,
    create = function(set)
        local row = { set = set }
        row.frame = NewHolder(set)
        row.control = addon.ForeverUI.CreateCheckbox(row.frame, " ", function(checked)
            Commit(row, checked and true or false)
        end, { style = "classic" })
        row.control:SetPoint("LEFT", row.frame, "LEFT", -4, 0)
        row.control.label:SetSize(set.rowWidth - 40, ROW_HEIGHT)
        row.control:SetScript("OnEnter", function() ShowRowTooltip(row) end)
        row.control:SetScript("OnLeave", HideRowTooltip)
        return row
    end,
    bind = function(row, def)
        row.control:SetLabel(Resolve(def.label) or "")
    end,
    refresh = function(row)
        row.control:SetChecked(Call(row.def.get) and true or false)
        SetDisabledState(row, row.control)
    end,
}

RowKinds.dropdown = {
    height = ROW_HEIGHT,
    create = function(set)
        local row = { set = set }
        row.frame = NewHolder(set)
        row.label = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.frame, "LEFT", 0, 0)
        row.label:SetWidth(LABEL_WIDTH)
        row.label:SetJustifyH("LEFT")
        -- The wow1 art overhangs the button by 8 per side, so the button starts 8 past label + gap.
        row.control = addon.ForeverUI.CreateDropdown(row.frame, {
            style = "wow1", width = set.rowWidth - LABEL_WIDTH - 21,
            get = function() return row.def and Call(row.def.get) end,
            set = function(value) Commit(row, value) end,
            builder = function() return ItemsOf(row.def) end,
        })
        row.control:SetPoint("LEFT", row.frame, "LEFT", LABEL_WIDTH + 13, 0)
        return row
    end,
    bind = function(row, def)
        row.label:SetText(Resolve(def.label) or "")
    end,
    refresh = function(row)
        row.control:Refresh()
        SetDisabledState(row, row.control)
    end,
}

RowKinds.button = {
    height = ROW_HEIGHT,
    create = function(set)
        local row = { set = set }
        row.frame = NewHolder(set)
        row.control = addon.ForeverUI.CreateButton(row.frame, " ", min(set.rowWidth - 13, 330), 28)
        row.control:SetPoint("CENTER", row.frame, "CENTER", 0, 0)
        row.control:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            if row.def and row.def.onClick then
                Safely(row.def.onClick)
                set:AfterChange()
            end
        end)
        return row
    end,
    bind = function(row, def)
        row.control:SetText(Resolve(def.label) or "")
    end,
    refresh = function(row)
        SetDisabledState(row, row.control)
    end,
}

-- The stock picker sits in DIALOG strata, under these windows; it is lifted while it serves a row and put back after.
local pickerOwner, pickerHooked

local function CloseOwnedPicker(set)
    local picker = _G.ColorPickerFrame
    if pickerOwner and pickerOwner.set == set and picker and picker:IsShown() then
        HideUIPanel(picker)
    end
end

local function ShowColorPicker(row)
    local def, picker = row.def, _G.ColorPickerFrame
    if not (def and picker) then return end

    local current = Call(def.get)
    local r0, g0, b0, a0 = 1, 1, 1, 1
    if type(current) == "table" then
        r0, g0, b0, a0 = current[1] or 1, current[2] or 1, current[3] or 1, current[4] or 1
    end
    local hasAlpha = def.hasAlpha and true or false

    HideUIPanel(picker)
    pickerOwner = row
    local opening = true
    local function apply(r, g, b, a)
        if opening then return end
        Safely(def.set, r, g, b, a)
        row.set:AfterChange()
    end

    picker.func = function()
        local r, g, b = picker:GetColorRGB()
        apply(r, g, b, hasAlpha and (1 - _G.OpacitySliderFrame:GetValue()) or 1)
    end
    picker.hasOpacity = hasAlpha
    picker.opacityFunc = picker.func
    if hasAlpha then picker.opacity = 1 - a0 end
    picker.cancelFunc = function()
        opening = false
        apply(r0, g0, b0, a0)
    end
    picker:SetColorRGB(r0, g0, b0)

    if not picker._dragonEditorStrata then
        picker._dragonEditorStrata = picker:GetFrameStrata()
    end
    if not pickerHooked then
        pickerHooked = true
        picker:HookScript("OnHide", function(self)
            if self._dragonEditorStrata then
                self:SetFrameStrata(self._dragonEditorStrata)
                self._dragonEditorStrata = nil
            end
        end)
    end
    picker:SetFrameStrata(EditorUI.POPUP_STRATA)
    ShowUIPanel(picker)
    picker:Raise()
    opening = false
end

RowKinds.color = {
    height = ROW_HEIGHT,
    create = function(set)
        local row = { set = set }
        row.frame = NewHolder(set)
        row.label = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.frame, "LEFT", 0, 0)
        row.label:SetWidth(LABEL_WIDTH)
        row.label:SetJustifyH("LEFT")

        local swatch = CreateFrame("Button", nil, row.frame)
        swatch:SetSize(46, 22)
        swatch:SetPoint("LEFT", row.frame, "LEFT", LABEL_WIDTH + 13, 0)
        local rim = swatch:CreateTexture(nil, "BACKGROUND")
        rim:SetAllPoints(swatch)
        rim:SetTexture(0.78, 0.62, 0.28, 1)
        local well = swatch:CreateTexture(nil, "BORDER")
        well:SetPoint("TOPLEFT", swatch, "TOPLEFT", 1, -1)
        well:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -1, 1)
        well:SetTexture(0.05, 0.05, 0.05, 1)
        row.fill = swatch:CreateTexture(nil, "ARTWORK")
        row.fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
        row.fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
        row.fill:SetTexture(1, 1, 1, 1)
        local glow = swatch:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(swatch)
        glow:SetTexture(1, 1, 1, 0.18)
        swatch:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            ShowColorPicker(row)
        end)
        row.control = swatch
        return row
    end,
    bind = function(row, def)
        row.label:SetText(Resolve(def.label) or "")
    end,
    refresh = function(row)
        local color = Call(row.def.get)
        if type(color) == "table" then
            row.fill:SetTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        end
        SetDisabledState(row, row.control)
        row.control:SetAlpha(row.disabled and 0.4 or 1)
    end,
}

-- Header rows are plain labels; with collapsible = true they fold the rows that follow them up to the next header.
local function UpdateHeaderArt(row)
    local section = row.headerSection
    if not section then return end
    local name = section.collapsed and "common-button-dropdown-closed" or "common-button-dropdown-open"
    addon.ForeverUI.SetAtlas(row.indicator, row.pressed and (name .. "pressed") or name, false)
end

RowKinds.header = {
    height = 30,
    create = function(set)
        local row = { set = set }
        row.frame = CreateFrame("Button", nil, set.parent)
        row.frame:SetSize(set.rowWidth, 30)
        row.indicator = row.frame:CreateTexture(nil, "ARTWORK")
        row.indicator:SetSize(22, 22)
        row.indicator:SetPoint("LEFT", row.frame, "LEFT", 0, 0)
        row.label = row.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        local hover = row.frame:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(row.frame)
        hover:SetTexture(1, 1, 1, 0.07)
        row.frame:SetScript("OnMouseDown", function()
            row.pressed = true
            UpdateHeaderArt(row)
        end)
        row.frame:SetScript("OnMouseUp", function()
            row.pressed = nil
            UpdateHeaderArt(row)
        end)
        row.frame:SetScript("OnClick", function()
            if row.headerSection then
                PlaySound("igMainMenuOptionCheckBoxOn")
                set:ToggleSection(row.headerSection)
            end
        end)
        return row
    end,
    bind = function(row, def)
        local foldable = row.headerSection ~= nil
        local sub = def.level == 2
        local indent = sub and 16 or 0
        row.pressed = nil
        row.frame:EnableMouse(foldable)
        row.indicator:ClearAllPoints()
        row.indicator:SetPoint("LEFT", row.frame, "LEFT", indent, 0)
        row.label:SetFontObject(sub and GameFontNormal or GameFontNormalLarge)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.frame, "LEFT", indent + (foldable and 28 or 5), 0)
        row.label:SetText(Resolve(def.label) or "")
        if foldable then
            row.indicator:Show()
            UpdateHeaderArt(row)
        else
            row.indicator:Hide()
        end
    end,
    refresh = function(row)
        row.label:SetText(Resolve(row.def.label) or "")
    end,
}

-- opts: overlayResize (fall back to addon.UpdateOverlaySizes after a set), onRelayout(set), onChange(set).
local function NewRowSet(parent, rowWidth, opts)
    opts = opts or {}
    return setmetatable({
        parent = parent, rowWidth = rowWidth, rows = {}, pools = {}, poolsByWidth = {}, sections = {}, count = 0,
        overlayResize = opts.overlayResize, onRelayout = opts.onRelayout, onChange = opts.onChange,
    }, RowSet)
end

-- Rows are built for one width, so each width keeps its own pool and a switch only rebuilds once.
function RowSet:SetRowWidth(width)
    if self.rowWidth == width then return end
    self:Clear()
    self.poolsByWidth[self.rowWidth] = self.pools
    self.rowWidth = width
    self.pools = self.poolsByWidth[width] or {}
end

function RowSet:Acquire(kind)
    local spec = RowKinds[kind]
    if not spec then return nil end
    local pool = self.pools[kind]
    if not pool then
        pool = {}
        self.pools[kind] = pool
    end
    local row = tremove(pool)
    if not row then
        row = spec.create(self)
        row.kind = kind
        row.height = spec.height
    end
    return row
end

function RowSet:Clear()
    CloseOwnedPicker(self)
    local rows = self.rows
    for index = #rows, 1, -1 do
        local row = rows[index]
        rows[index] = nil
        row.def, row.dragging, row.disabled, row.hidden = nil, nil, nil, nil
        row.section, row.headerSection, row.folded, row.pressed = nil, nil, nil, nil
        row.frame:Hide()
        row.frame:ClearAllPoints()
        tinsert(self.pools[row.kind], row)
    end
    self.def, self.count, self.keep = nil, 0, nil
    wipe(self.sections)
end

-- Same def and row count keep the widgets (a drag survives); scope (frame name) keys the remembered folds.
function RowSet:Load(def, scope)
    local settings = def and def.settings
    local count = settings and #settings or 0
    if def and def == self.def and count == self.count then
        return self:Refresh()
    end

    self:Clear()
    self.def, self.count = def, count
    local section, topSection
    if settings then
        for _, setting in ipairs(settings) do
            local row = self:Acquire(setting.type)
            if row then
                row.def = setting
                row.hidden = Call(setting.hidden) and true or false
                if setting.type == "header" then
                    -- A level-2 header folds inside the open level-1 section above it.
                    local owner = setting.level == 2 and topSection or nil
                    section = nil
                    if not owner then topSection = nil end
                    if setting.collapsible then
                        local key = (scope or "") .. "\n" .. (Resolve(setting.label) or "")
                        local collapsed = SectionState[key]
                        if collapsed == nil then collapsed = setting.collapsed == true end
                        section = { header = row, key = key, collapsed = collapsed, rows = {}, children = {}, parent = owner }
                        row.headerSection = section
                        self.sections[#self.sections + 1] = section
                        if owner then
                            owner.children[#owner.children + 1] = section
                        else
                            topSection = section
                        end
                    end
                    if owner then
                        row.section, row.folded = owner, Hiding(owner)
                        owner.rows[#owner.rows + 1] = row
                    end
                elseif section then
                    row.section, row.folded = section, Hiding(section)
                    section.rows[#section.rows + 1] = row
                end
                RowKinds[row.kind].bind(row, setting)
                self.rows[#self.rows + 1] = row
                if Shown(row) then
                    RowKinds[row.kind].refresh(row)
                end
            end
        end
    end
    return true
end

-- Re-reads values, `hidden` and `disabled`; true when a row appeared or disappeared.
function RowSet:Refresh()
    local changed = false
    for _, row in ipairs(self.rows) do
        if not row.folded then
            local hidden = Call(row.def.hidden) and true or false
            if hidden ~= row.hidden then
                row.hidden = hidden
                changed = true
            end
            if not hidden then
                RowKinds[row.kind].refresh(row)
            end
        end
    end
    return changed
end

-- A section's rows are folded by its own fold or by any section it sits inside.
function Hiding(section)
    while section do
        if section.collapsed then return true end
        section = section.parent
    end
    return false
end

local function ApplyFold(section)
    local folded = Hiding(section)
    for _, row in ipairs(section.rows) do
        row.folded = folded
    end
    for _, child in ipairs(section.children) do
        ApplyFold(child)
    end
end

function RowSet:SetCollapsed(section, collapsed, remember)
    section.collapsed = collapsed
    ApplyFold(section)
    if remember then
        SectionState[section.key] = collapsed
    end
    UpdateHeaderArt(section.header)
end

function RowSet:ToggleSection(section)
    local collapsed = not section.collapsed
    self:SetCollapsed(section, collapsed, true)
    self.keep = (not collapsed) and section or nil
    local onExpand = (not collapsed) and section.header.def and section.header.def.onExpand
    if onExpand then Safely(onExpand) end
    self:Refresh()
    if self.onRelayout then
        self.onRelayout(self)
    end
end

-- Height cap: folds the last open section that still shows rows, sparing the one the user just opened.
function RowSet:FoldLast()
    for index = #self.sections, 1, -1 do
        local section = self.sections[index]
        local covered = section.parent and Hiding(section.parent)
        if section ~= self.keep and not section.collapsed and not covered then
            for _, row in ipairs(section.rows) do
                if not row.hidden then
                    self:SetCollapsed(section, true)
                    return true
                end
            end
        end
    end
    return false
end

function RowSet:Poll()
    if self:Refresh() and self.onRelayout then
        self.onRelayout(self)
    end
end

function RowSet:AfterChange()
    local def = self.def
    local resize = def and def.resize
    if not resize and self.overlayResize then
        resize = addon.UpdateOverlaySizes
    end
    if resize and not InCombatLockdown() then
        Safely(resize)
    end
    self:Poll()
    if self.onChange then
        self.onChange(self)
    end
end

-- Combat lock on top of each row's own `disabled()`.
function RowSet:SetLocked(locked)
    locked = locked and true or false
    if self.locked == locked then return end
    self.locked = locked
    self:Poll()
end

function RowSet:VisibleCount()
    local visible = 0
    for _, row in ipairs(self.rows) do
        if Shown(row) then
            visible = visible + 1
        end
    end
    return visible
end

-- Stacks the visible rows from (x, y) under anchor's top-left; returns y after the last row's trailing gap.
function RowSet:Layout(anchor, x, y, gap)
    for _, row in ipairs(self.rows) do
        if not Shown(row) then
            row.frame:Hide()
        else
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
            row.frame:Show()
            y = y + row.height + gap
        end
    end
    return y
end

-- Windows never outgrow the screen: past this height the last open sections fold themselves.
local function MaxWindowHeight()
    return UIParent:GetHeight() - 80
end

local function GetRegistryDef(name)
    local registry = addon.EditorSettings
    if not (name and registry and registry.Get) then return nil end
    local ok, result = pcall(registry.Get, name)
    if not ok then
        geterrorhandler()(result)
        return nil
    end
    return result
end

-- ============================================================================
-- DIALOG LAYOUT AND PLACEMENT
-- ============================================================================

Layout = function()
    if not dialog then return end
    local y = PAD_TOP

    local function place(frame, height)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", dialog, "TOPLEFT", PAD_X, -y)
        y = y + height + ROW_GAP
    end

    place(dialog.xRow, ROW_HEIGHT)
    place(dialog.yRow, ROW_HEIGHT)
    y = dialogSet:Layout(dialog, PAD_X, y, ROW_GAP)

    if resetShown then
        dialog.divider:ClearAllPoints()
        dialog.divider:SetPoint("TOP", dialog, "TOP", 0, -(y + 2))
        dialog.divider:Show()
        y = y + 20
        dialog.resetButton:ClearAllPoints()
        dialog.resetButton:SetPoint("TOP", dialog, "TOP", 0, -y)
        dialog.resetButton:Show()
        y = y + 28 + ROW_GAP
    else
        dialog.divider:Hide()
        dialog.resetButton:Hide()
    end

    local height = y - ROW_GAP + PAD_BOTTOM
    if height > MaxWindowHeight() and dialogSet:FoldLast() then
        return Layout()
    end
    dialog:SetHeight(height)
end

UpdateReset = function()
    if not dialog then return end
    local show = GetDetachedResetActionForSelection() ~= nil
    if show ~= resetShown then
        resetShown = show
        Layout()
    end
end

-- Moves the dialog under the manager when they would overlap, so the two never stack.
local function AvoidManager(x, y, width, height)
    local manager = _G.DragonUI_EditorManager
    if not (manager and manager:IsShown()) then return y end
    local ml, mr, mt, mb = manager:GetLeft(), manager:GetRight(), manager:GetTop(), manager:GetBottom()
    if not (ml and mr and mt and mb) then return y end
    local ratio = manager:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ml, mr, mt, mb = ml * ratio, mr * ratio, mt * ratio, mb * ratio
    if x + width <= ml or x >= mr or y <= mb or y - height >= mt then return y end
    local below = mb - SIDE_GAP
    if below - height >= SCREEN_MARGIN then return below end
    return y
end

-- Opens on the side of the selected overlay with more room, top-aligned, inside the screen.
local function PlaceDialog(target)
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local width, height = dialog:GetWidth(), dialog:GetHeight()
    local left, right, top, bottom = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()
    local x, y
    if left and right and top and bottom then
        local ratio = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
        left, right, top = left * ratio, right * ratio, top * ratio
        if screenW - right >= width + SIDE_GAP or screenW - right >= left then
            x = right + SIDE_GAP
        else
            x = left - SIDE_GAP - width
        end
        y = top
    else
        x, y = screenW - width - 40, screenH - 140
    end
    x = max(SCREEN_MARGIN, min(x, screenW - width - SCREEN_MARGIN))
    y = AvoidManager(x, y, width, height)
    y = min(max(y, height + SCREEN_MARGIN), screenH - SCREEN_MARGIN)
    dialog:ClearAllPoints()
    dialog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

-- ============================================================================
-- DIALOG FRAME
-- ============================================================================

local NUDGE_BACK = {
    normal = "common-dropdown-c-button",
    hover = "common-dropdown-c-button-hover-2",
    pressed = "common-dropdown-c-button-pressed-2",
    pressedhover = "common-dropdown-c-button-pressedhover-2",
}

-- Dropdown-stepper art; the Y arrows reuse the side arrows rotated a quarter turn.
local function CreateNudgeButton(parent, iconName, rotated, dx, dy)
    local forever = addon.ForeverUI
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(26, 25)

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("CENTER", button, "CENTER", 0, 0)

    local info = addon.ForeverAtlas[iconName]
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(info[2], info[3])
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(info[1])
    if rotated then
        icon:SetTexCoord(info[5], info[6], info[4], info[6], info[5], info[7], info[4], info[7])
    else
        icon:SetTexCoord(info[4], info[5], info[6], info[7])
    end

    local function paint()
        local state = "normal"
        if button._down and button._over then
            state = "pressedhover"
        elseif button._over then
            state = "hover"
        elseif button._down then
            state = "pressed"
        end
        forever.SetAtlas(back, NUDGE_BACK[state], true)
    end

    button:SetScript("OnEnter", function(self)
        self._over = true
        paint()
    end)
    button:SetScript("OnLeave", function(self)
        self._over = false
        paint()
    end)
    button:SetScript("OnMouseDown", function(self)
        self._down = true
        paint()
    end)
    button:SetScript("OnMouseUp", function(self)
        self._down = false
        paint()
    end)
    button:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        NudgeSelectedFrame(dx, dy)
    end)
    paint()
    return button
end

local function CreateCoordRow(set, labelText, minus, plus)
    local row = NewHolder(set)
    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(LABEL_WIDTH)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local box = addon.ForeverUI.CreateEditBox(row, 80, 20)
    box:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH + 10, 0)
    box:SetJustifyH("CENTER")
    box:SetMaxLetters(10)
    box:SetScript("OnEnterPressed", ApplyTypedCoordinates)

    local back = CreateNudgeButton(row, minus.icon, minus.rotated, minus.dx, minus.dy)
    back:SetPoint("LEFT", box, "RIGHT", 10, 0)
    local forward = CreateNudgeButton(row, plus.icon, plus.rotated, plus.dx, plus.dy)
    forward:SetPoint("LEFT", back, "RIGHT", 4, 0)
    return row, box
end

local function OnResetClicked()
    local action, frameData = GetDetachedResetActionForSelection()
    if not action then
        UpdateReset()
        return
    end

    if selectedEditorFrame then
        selectedEditorFrame.DragonUI_WasDragged = nil
        selectedEditorFrame.DragonUI_WasAdjustedByEditor = nil
    end

    action()

    if frameData and frameData.showTest then
        frameData.showTest()
    end

    dialogSet:Poll()
    UpdateReset()
    UpdateCoords()
end

local function OnDialogUpdate(self, elapsed)
    self.coordElapsed = (self.coordElapsed or 0) + elapsed
    self.rowsElapsed = (self.rowsElapsed or 0) + elapsed
    if self.coordElapsed >= COORD_INTERVAL then
        self.coordElapsed = 0
        UpdateCoords()
    end
    if self.rowsElapsed >= ROWS_INTERVAL then
        self.rowsElapsed = 0
        -- Overlays hidden by a setting (e.g. weapon enchants merged back) leave nothing to edit.
        if selectedEditorFrame and not selectedEditorFrame:IsShown() then
            addon.DeselectEditorFrame()
            return
        end
        dialogSet:Poll()
        UpdateReset()
    end
end

local OpenSettingsDialog

local function OnDialogEvent(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if addon.Menu then addon.Menu.Close() end
        if selectedEditorFrame then
            combatHidden = true
        end
        self:Hide()
    elseif combatHidden then
        combatHidden = false
        if selectedEditorFrame then
            OpenSettingsDialog(selectedEditorFrame)
        end
    end
end

local function EnsureDialog()
    if dialog then return dialog end
    local forever = addon.ForeverUI

    local frame = CreateFrame("Frame", "DragonUI_EditorSettings", UIParent)
    frame:SetFrameStrata(EditorUI.STRATA)
    frame:SetFrameLevel(EditorUI.DIALOG)
    frame:SetSize(DIALOG_WIDTH, 160)
    frame:SetPoint("CENTER")
    forever.SkinDialog(frame, {
        closable = true,
        onClose = function() addon.DeselectEditorFrame() end,
    })
    frame:Hide()
    frame:HookScript("OnDragStop", function() dialogMoved = true end)
    dialog = frame
    dialogSet = NewRowSet(frame, ROW_WIDTH, { overlayResize = true, onRelayout = Layout, onChange = UpdateReset })

    frame.xRow, frame.xBox = CreateCoordRow(dialogSet, "X",
        { icon = "common-dropdown-icon-back", dx = -1, dy = 0 },
        { icon = "common-dropdown-icon-next", dx = 1, dy = 0 })
    frame.yRow, frame.yBox = CreateCoordRow(dialogSet, "Y",
        { icon = "common-dropdown-icon-back", rotated = true, dx = 0, dy = -1 },
        { icon = "common-dropdown-icon-next", rotated = true, dx = 0, dy = 1 })

    frame.divider = forever.CreateDivider(frame, "ornate")
    frame.divider:Hide()
    frame.resetButton = forever.CreateButton(frame, L["Reset"], 180, 28)
    frame.resetButton:SetScript("OnClick", OnResetClicked)
    frame.resetButton:Hide()

    frame:SetScript("OnUpdate", OnDialogUpdate)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", OnDialogEvent)
    return frame
end

OpenSettingsDialog = function(target)
    local editor = addon.EditorMode
    if not (editor and editor:IsActive()) then return end

    local frame = EnsureDialog()
    if InCombatLockdown() then
        combatHidden = true
        frame:Hide()
        return
    end
    combatHidden = false

    local name = GetSelectedEditableFrameData()
    local def = GetRegistryDef(name)

    local title = def and Resolve(def.title)
    if not title or title == "" then
        title = target.editorText and target.editorText.GetText and target.editorText:GetText()
    end
    frame:SetTitle((title and title ~= "") and title or name or "")

    dialogSet:Clear()
    local rowWidth = (not def or def.compact) and COMPACT_ROW_WIDTH or ROW_WIDTH
    dialogSet:SetRowWidth(rowWidth)
    frame:SetWidth(rowWidth + 2 * PAD_X)
    dialogSet:Load(def, name)

    resetShown = GetDetachedResetActionForSelection() ~= nil
    Layout()

    if placedFor ~= target then
        placedFor = target
        dialogMoved = false
    end
    if not dialogMoved then
        PlaceDialog(target)
    end

    UpdateCoords()
    if addon.ForeverUI.EnforceLayering then addon.ForeverUI.EnforceLayering(frame) end
    frame:Show()
end

local function CloseSettingsDialog()
    placedFor = nil
    dialogMoved = false
    combatHidden = false
    if not dialog then return end
    dialog.xBox:ClearFocus()
    dialog.yBox:ClearFocus()
    dialog:Hide()
    dialogSet:Clear()
    resetShown = false
end

-- ============================================================================
-- SELECTION
-- ============================================================================

-- Apply a green tint to the nineslice to visually mark the "selected" frame
ApplySelectionTint = function(frame)
    local slice = frame and frame.NineSlice
    if not slice then return end
    if slice.Center then slice.Center:SetVertexColor(0.2, 1.0, 0.3, 0.5) end
    for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                          "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
        if slice[key] then slice[key]:SetVertexColor(0.2, 1.0, 0.3) end
    end
end

-- Remove the selection tint (restore default texture color)
ClearSelectionTint = function(frame)
    local slice = frame and frame.NineSlice
    if not slice then return end
    if slice.Center then slice.Center:SetVertexColor(1, 1, 1, 1) end
    for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                          "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
        if slice[key] then slice[key]:SetVertexColor(1, 1, 1) end
    end
end

-- Select a frame for coordinate display, nudging and its settings
function addon.SelectEditorFrame(frame)
    if not frame then return end
    local changed = selectedEditorFrame ~= frame

    -- Deselect previous
    if selectedEditorFrame and changed then
        if selectedEditorFrame.NineSlice then
            ClearSelectionTint(selectedEditorFrame)
            addon.SetNinesliceState(selectedEditorFrame, false)
        end
    end

    selectedEditorFrame = frame
    addon.selectedEditorFrame = frame

    -- Show selected nineslice state with green tint
    if frame.NineSlice then
        addon.SetNinesliceState(frame, true)
        ApplySelectionTint(frame)
    end

    -- Every overlay press calls this again; only a different frame rebuilds the dialog.
    if changed then
        OpenSettingsDialog(frame)
    else
        UpdateCoords()
    end
end

-- Expose tint helpers and selectedEditorFrame for external modules
addon.ApplySelectionTint = function(f) ApplySelectionTint(f) end
addon.ClearSelectionTint = function(f) ClearSelectionTint(f) end
addon.selectedEditorFrame = nil  -- updated below via SelectEditorFrame

-- Clear selection state
function addon.DeselectEditorFrame()
    if selectedEditorFrame and selectedEditorFrame.NineSlice then
        ClearSelectionTint(selectedEditorFrame)
        addon.SetNinesliceState(selectedEditorFrame, false)
    end
    selectedEditorFrame = nil
    addon.selectedEditorFrame = nil
    CloseSettingsDialog()
end

-- Rebuild/refresh hooks for the settings registry (structural changes, external edits).
addon.EditorPanel = {
    GetDef = GetRegistryDef,
    CreateRowSet = NewRowSet,
    MaxHeight = MaxWindowHeight,
    -- Same rows keep their widgets so a slider being dragged survives the rebuild a set() asks for.
    Rebuild = function()
        if selectedEditorFrame then
            local def = dialog and dialog:IsShown() and dialogSet.def and GetRegistryDef(GetSelectedEditableFrameData())
            if def and def == dialogSet.def and #(def.settings or {}) == dialogSet.count then
                dialogSet:Poll()
                UpdateReset()
            else
                OpenSettingsDialog(selectedEditorFrame)
            end
        end
        local mode = addon.EditorMode
        if mode and mode.RebuildManager then
            mode:RebuildManager()
        end
    end,
    Refresh = function()
        if dialog and dialog:IsShown() then
            dialogSet:Poll()
            UpdateReset()
            UpdateCoords()
        end
    end,
    IsOpen = function()
        return dialog ~= nil and not not dialog:IsShown()
    end,
}

do
    local registry = addon.EditorSettings or {}
    addon.EditorSettings = registry
    registry.onRebuild = addon.EditorPanel.Rebuild
end

-- Show all frames in editor mode
function addon:ShowAllEditableFrames()
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            -- Skip frames that explicitly declare they shouldn't appear in editor
            if frameData.editorVisible and not frameData.editorVisible() then
                frameData.frame:Hide()
            else
                addon.HideUIFrame(frameData.frame) -- Show green overlay

                -- Show frame with fake data if needed
                if frameData.showTest then
                    frameData.showTest()
                end

                if frameData.onShow then
                    frameData.onShow()
                end
            end
        end
    end
    addon:Print((L and L["All editable frames shown for editing"] or "All editable frames shown for editing"))

    addon.DeselectEditorFrame()
end

-- Hide all frames and save positions
function addon:HideAllEditableFrames(refresh)
    addon.DeselectEditorFrame()

    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            addon.ShowUIFrame(frameData.frame) -- Hide green overlay

            -- Hide fake frame if it shouldn't be visible
            if frameData.hideTest then
                frameData.hideTest()
            end

            if refresh then
                -- Save position automatically (skip if configPath is nil - custom save logic)
                if frameData.configPath then
                    if #frameData.configPath == 2 then
                        addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                    else
                        addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                    end
                end

                if frameData.onHide then
                    frameData.onHide()
                end
            end
        end
    end
    addon:Print((L and L["All editable frames hidden, positions saved"] or "All editable frames hidden, positions saved"))
end

-- Check if a frame should be visible
function addon:ShouldFrameBeVisible(frameName)
    local frameData = self.EditableFrames[frameName]
    if not frameData then return false end

    if frameData.hasTarget then
        return frameData.hasTarget()
    end

    -- By default, frames are always visible (player, minimap)
    return true
end

-- Get information about a registered frame
function addon:GetEditableFrameInfo(frameName)
    return self.EditableFrames[frameName]
end
