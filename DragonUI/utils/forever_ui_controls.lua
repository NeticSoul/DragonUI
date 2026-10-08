-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local ForeverUI = addon.ForeverUI
local Atlas = addon.ForeverAtlas
if not (ForeverUI and Atlas) then
    return
end

local floor, max, min = math.floor, math.max, math.min
local format = string.format

local SetAtlas = ForeverUI.SetAtlas

-- Row and control metrics copied from Forever's settings panel and Edit Mode templates.
local ROW_H = 32
local LABEL_W = 100
local LABEL_GAP = 5
local SLIDER_VALUE_W = 38
local SLIDER_INSET = 19
local DROPDOWN_H = 25
local SEARCH_H = 22
local SCROLL_GAP = 8
local SCROLL_BAR_W = 17
local SCROLL_MIN_THUMB = 23
-- WoW maps a drag across (track - thumb): a thumb that fills the track leaves nothing to divide by and reads backwards.
local SCROLL_MIN_TRAVEL = 12

local function isEnabled(frame)
    local state = frame:IsEnabled()
    return state ~= nil and state ~= false and state ~= 0
end

local function setDesaturated(texture, on)
    if texture and texture.SetDesaturated then
        texture:SetDesaturated(on and true or false)
    end
end

-- SetFrameLevel does not move children: keep child frames at fixed offsets when a consumer re-levels the owner.
local function trackLevels(frame, kids)
    frame._fuKids = frame._fuKids or {}
    for _, kid in ipairs(kids) do
        frame._fuKids[#frame._fuKids + 1] = kid
    end
    if not frame._fuLevelWrapped then
        frame._fuLevelWrapped = true
        local native = frame.SetFrameLevel
        frame.SetFrameLevel = function(self, level)
            native(self, level)
            for _, kid in ipairs(self._fuKids) do
                kid[1]:SetFrameLevel(level + kid[2])
            end
        end
    end
end

local function applyButtonTexture(button, kind, name, blend)
    local info = Atlas[name]
    if not info then
        return nil
    end
    button["Set" .. kind .. "Texture"](button, info[1])
    local texture = button["Get" .. kind .. "Texture"](button)
    if texture then
        texture:SetTexCoord(info[4], info[5], info[6], info[7])
        if blend then
            texture:SetBlendMode(blend)
        end
    end
    return texture
end

local function clearButtonTexture(button, kind)
    local texture = button["Get" .. kind .. "Texture"](button)
    if texture then
        texture:SetTexture(nil)
    end
end

local measurer

local function textWidth(fontName, text)
    if not measurer then
        measurer = UIParent:CreateFontString(nil, "ARTWORK")
        measurer:Hide()
    end
    measurer:SetFontObject(_G[fontName])
    measurer:SetText(text)
    return measurer:GetStringWidth()
end

-- 3.3.5a has no FontString:SetWordWrap, so a too-wide label wraps onto a second line; cut it on UTF-8 boundaries.
local function fitText(fontString, fontName, text, maxWidth)
    text = text or ""
    if maxWidth > 0 and textWidth(fontName, text) > maxWidth then
        local cut = #text
        while cut > 1 do
            cut = cut - 1
            local byte = text:byte(cut + 1)
            while cut > 1 and byte and byte >= 128 and byte < 192 do
                cut = cut - 1
                byte = text:byte(cut + 1)
            end
            local try = text:sub(1, cut) .. "..."
            if textWidth(fontName, try) <= maxWidth then
                text = try
                break
            end
        end
    end
    fontString:SetText(text)
end

local function stepDecimals(step)
    local decimals = 0
    step = math.abs(step)
    while decimals < 6 and math.abs(step * 10 ^ decimals - floor(step * 10 ^ decimals + 0.5)) > 1e-7 do
        decimals = decimals + 1
    end
    return decimals
end

-- ---------------------------------------------------------------------------
-- Three-slice strips (horizontal stretch only)
-- ---------------------------------------------------------------------------

local function createSlice(owner, layer)
    return {
        left = owner:CreateTexture(nil, layer),
        middle = owner:CreateTexture(nil, layer),
        right = owner:CreateTexture(nil, layer),
    }
end

local function setSlice(slice, prefix)
    if slice.prefix == prefix then
        return
    end
    slice.prefix = prefix
    SetAtlas(slice.left, prefix .. "-left", true)
    SetAtlas(slice.right, prefix .. "-right", true)
    SetAtlas(slice.middle, prefix .. "-middle", false)
end

local function placeSlice(slice, owner, leftX, rightX, y)
    slice.left:ClearAllPoints()
    slice.left:SetPoint("LEFT", owner, "LEFT", leftX, y)
    slice.right:ClearAllPoints()
    slice.right:SetPoint("RIGHT", owner, "RIGHT", rightX, y)
    slice.middle:ClearAllPoints()
    slice.middle:SetPoint("TOPLEFT", slice.left, "TOPRIGHT", 0, 0)
    slice.middle:SetPoint("BOTTOMRIGHT", slice.right, "BOTTOMLEFT", 0, 0)
end

local function showSlice(slice, shown)
    for _, texture in pairs(slice) do
        if type(texture) == "table" then
            if shown then
                texture:Show()
            else
                texture:Hide()
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Checkbox
-- ---------------------------------------------------------------------------

local CLASSIC_BOX = {
    normal = "Interface\\Buttons\\UI-CheckBox-Up",
    pushed = "Interface\\Buttons\\UI-CheckBox-Down",
    highlight = "Interface\\Buttons\\UI-CheckBox-Highlight",
    checked = "Interface\\Buttons\\UI-CheckBox-Check",
    disabled = "Interface\\Buttons\\UI-CheckBox-Check-Disabled",
}

local function skinCheckButtonFrame(button, style)
    if style == "classic" then
        button:SetNormalTexture(CLASSIC_BOX.normal)
        button:SetPushedTexture(CLASSIC_BOX.pushed)
        button:SetHighlightTexture(CLASSIC_BOX.highlight, "ADD")
        button:SetCheckedTexture(CLASSIC_BOX.checked)
        button:SetDisabledCheckedTexture(CLASSIC_BOX.disabled)
        button:SetSize(32, 32)
        return
    end
    applyButtonTexture(button, "Normal", "checkbox-minimal")
    applyButtonTexture(button, "Pushed", "checkbox-minimal")
    applyButtonTexture(button, "Highlight", "checkbox-minimal", "ADD")
    applyButtonTexture(button, "Checked", "checkmark-minimal")
    applyButtonTexture(button, "DisabledChecked", "checkmark-minimal-disabled")
    local info = Atlas["checkbox-minimal"]
    if info then
        button:SetSize(info[2], info[3])
    end
end

local function applyAceCheckDisabled(widget)
    local atlasName = widget.disabled and "checkmark-minimal-disabled" or "checkmark-minimal"
    SetAtlas(widget.check, atlasName, false)
end

function ForeverUI.SkinCheckButton(target, opts)
    if not target then
        return
    end
    opts = opts or {}
    if target.checkbg and target.check then
        local info = Atlas["checkbox-minimal"]
        if not info then
            return
        end
        local indent = opts.indent or target._dragonCheckIndent or 0
        SetAtlas(target.checkbg, "checkbox-minimal", false)
        target.checkbg:SetSize(info[2], info[3])
        target.checkbg:ClearAllPoints()
        target.checkbg:SetPoint("TOPLEFT", indent - 3, 3)
        target.check:SetBlendMode("BLEND")
        applyAceCheckDisabled(target)
        if target.highlight then
            SetAtlas(target.highlight, "checkbox-minimal", false)
            target.highlight:SetBlendMode("ADD")
        end
        if not target._fuCheckWrapped and target.SetDisabled then
            target._fuCheckWrapped = true
            local original = target.SetDisabled
            target.SetDisabled = function(self, disabled)
                original(self, disabled)
                applyAceCheckDisabled(self)
            end
        end
        return
    end
    skinCheckButtonFrame(target, opts.style)
end

-- Returns a CheckButton; opts: { style = "minimal" | "classic", font = "GameFontHighlight", width = total row width }.
function ForeverUI.CreateCheckbox(parent, label, onToggle, opts)
    opts = opts or {}
    local button = CreateFrame("CheckButton", nil, parent)
    skinCheckButtonFrame(button, opts.style)
    button.onToggle = onToggle
    button.style = opts.style
    button.fontEnabled = opts.font or "GameFontHighlight"
    button.labelGap = opts.style == "classic" and 5 or 2
    if opts.width then
        button.labelRoom = opts.width - button:GetWidth() - button.labelGap
    end

    local text = button:CreateFontString(nil, "ARTWORK", button.fontEnabled)
    text:SetJustifyH("LEFT")
    text:SetPoint("LEFT", button, "RIGHT", button.labelGap, 1)
    button.label = text

    local nativeEnable, nativeDisable, nativeGetChecked = button.Enable, button.Disable, button.GetChecked

    function button:GetChecked()
        return nativeGetChecked(self) and true or false
    end

    local function dim(self, on)
        if self.style == "classic" then
            return
        end
        for _, kind in ipairs({ "Normal", "Pushed", "Highlight" }) do
            setDesaturated(self["Get" .. kind .. "Texture"](self), on)
        end
    end

    function button:Enable()
        nativeEnable(self)
        self.label:SetFontObject(_G[self.fontEnabled])
        dim(self, false)
    end

    function button:Disable()
        nativeDisable(self)
        self.label:SetFontObject(GameFontDisable)
        dim(self, true)
    end

    function button:SetLabel(value)
        local room = self.labelRoom
        if room then
            fitText(self.label, self.fontEnabled, value or "", room)
        else
            self.label:SetText(value or "")
        end
        self:SetHitRectInsets(0, -(self.labelGap + self.label:GetStringWidth() + 2), 0, 0)
    end

    function button:GetLabelWidth()
        return self.label:GetStringWidth()
    end

    button:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        if self.onToggle then
            self.onToggle(checked, self)
        end
    end)

    button:SetLabel(label)
    return button
end

-- ---------------------------------------------------------------------------
-- Slider with steppers
-- ---------------------------------------------------------------------------

local function createBar(slider)
    local bar = {}
    bar.left = slider:CreateTexture(nil, "BACKGROUND")
    bar.right = slider:CreateTexture(nil, "BACKGROUND")
    bar.middle = slider:CreateTexture(nil, "BACKGROUND")
    SetAtlas(bar.left, "minimal_sliderbar_left", true)
    SetAtlas(bar.right, "minimal_sliderbar_right", true)
    SetAtlas(bar.middle, "_minimal_sliderbar_middle", false)
    bar.left:SetPoint("LEFT", slider, "LEFT", 0, 0)
    bar.right:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    bar.middle:SetPoint("TOPLEFT", bar.left, "TOPRIGHT", 0, 0)
    bar.middle:SetPoint("BOTTOMRIGHT", bar.right, "BOTTOMLEFT", 0, 0)
    return bar
end

local function setThumb(slider)
    local info = Atlas["minimal_sliderbar_button"]
    if not info then
        return
    end
    slider:SetThumbTexture(info[1])
    local thumb = slider:GetThumbTexture()
    thumb:SetTexCoord(info[4], info[5], info[6], info[7])
    thumb:SetSize(info[2], info[3])
    return thumb
end

local function createStepper(slider, side)
    local button = CreateFrame("Button", nil, slider)
    local name = side == "back" and "minimal_sliderbar_button_left" or "minimal_sliderbar_button_right"
    local info = Atlas[name]
    button:SetSize(info and info[2] or 10, info and info[3] or 19)
    button:SetFrameLevel(slider:GetFrameLevel() + 2)
    button:SetHitRectInsets(0, 0, -6, -6)
    local art = button:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints(button)
    SetAtlas(art, name, false)
    button.art = art
    if side == "back" then
        button:SetPoint("RIGHT", slider, "LEFT", -4, 0)
    else
        button:SetPoint("LEFT", slider, "RIGHT", 4, 0)
    end
    return button
end

local function setStepperState(button, on)
    if button.stepEnabled == on then
        return
    end
    button.stepEnabled = on
    if on then
        button:Enable()
    else
        button:Disable()
    end
    button:SetAlpha(on and 1 or 0.5)
    setDesaturated(button.art, not on)
end

local function formatValue(opts, value)
    local fmt = opts.format
    if type(fmt) == "function" then
        return fmt(value)
    elseif type(fmt) == "string" then
        return format(fmt, value)
    end
    return tostring(value)
end

local function snapValue(self, value)
    local lo, hi, step = self.minValue, self.maxValue, self.step
    if step and step > 0 then
        value = lo + floor((value - lo) / step + 0.5) * step
    end
    value = max(lo, min(hi, value))
    return tonumber(format("%." .. self.decimals .. "f", value))
end

local SliderMethods = {}

function SliderMethods:UpdateDisplay()
    local value = self.value or self.minValue
    self.valueText:SetText(formatValue(self.opts, value))
    local on = self.enabled
    setStepperState(self.back, on and value > self.minValue + self.step * 0.5)
    setStepperState(self.forward, on and value < self.maxValue - self.step * 0.5)
end

function SliderMethods:SetRange(lo, hi, step)
    self.minValue, self.maxValue, self.step = lo, hi, step or 1
    self.decimals = stepDecimals(self.step)
    self.silent = true
    self.slider:SetMinMaxValues(lo, hi)
    self.slider:SetValueStep(self.step)
    self.silent = nil
    if self.value then
        self:SetValue(self.value)
    end
end

function SliderMethods:SetValue(value)
    value = snapValue(self, tonumber(value) or self.minValue)
    self.silent = true
    self.slider:SetValue(value)
    self.silent = nil
    self.value = value
    self:UpdateDisplay()
end

function SliderMethods:GetValue()
    return self.value
end

function SliderMethods:Refresh()
    if self.opts.get then
        self:SetValue(self.opts.get())
    end
end

function SliderMethods:Bind(get, set)
    self.opts.get, self.opts.set = get, set
end

function SliderMethods:SetFormat(fmt)
    self.opts.format = fmt
    self:UpdateDisplay()
end

function SliderMethods:SetLabel(text)
    if self.label then
        fitText(self.label, "GameFontHighlight", text or "", self.labelRoom)
    end
end

function SliderMethods:Step(direction)
    if not self.enabled then
        return
    end
    local value = snapValue(self, (self.value or self.minValue) + direction * self.step)
    if value == self.value then
        return
    end
    PlaySound("igMainMenuOptionCheckBoxOn")
    self.silent = true
    self.slider:SetValue(value)
    self.silent = nil
    self.value = value
    self:UpdateDisplay()
    if self.opts.set then
        self.opts.set(value)
    end
end

-- Forever's slider rows can drop the number and name the two ends of the track instead.
function SliderMethods:SetValueHidden(hidden)
    hidden = hidden and true or false
    local slider = self.slider
    slider:ClearAllPoints()
    slider:SetPoint("TOPLEFT", self, "TOPLEFT", self.sliderLeft, 0)
    slider:SetPoint("TOPRIGHT", self, "TOPRIGHT", -(hidden and SLIDER_INSET or (SLIDER_VALUE_W + SLIDER_INSET)), 0)
    if self.valueText then
        if hidden then
            self.valueText:Hide()
        else
            self.valueText:Show()
        end
    end
end

-- Returns the row height this needs: 38 with end texts, the plain row otherwise.
function SliderMethods:SetEndTexts(minText, maxText)
    if (minText or maxText) and not self.minText then
        self.minText = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        self.minText:SetPoint("TOP", self.slider, "BOTTOMLEFT", 0, 6)
        self.maxText = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        self.maxText:SetPoint("TOP", self.slider, "BOTTOMRIGHT", 0, 6)
    end
    if self.minText then
        self.minText:SetText(minText or "")
        self.maxText:SetText(maxText or "")
    end

    local height = (minText or maxText) and 38 or ROW_H
    self:SetHeight(height)
    return height
end

function SliderMethods:Enable()
    self.enabled = true
    self.slider:EnableMouse(true)
    if self.label then
        self.label:SetFontObject(GameFontHighlight)
    end
    self.valueText:SetFontObject(GameFontNormal)
    self.slider:GetThumbTexture():SetAlpha(1)
    self:UpdateDisplay()
end

function SliderMethods:Disable()
    self.enabled = false
    self.slider:EnableMouse(false)
    if self.label then
        self.label:SetFontObject(GameFontDisable)
    end
    self.valueText:SetFontObject(GameFontDisable)
    self.slider:GetThumbTexture():SetAlpha(0.7)
    self:UpdateDisplay()
end

function SliderMethods:IsEnabledState()
    return self.enabled
end

local function onSliderValueChanged(slider, value)
    local owner = slider.owner
    if owner.silent then
        return
    end
    local snapped = snapValue(owner, value)
    if snapped ~= value then
        owner.silent = true
        slider:SetValue(snapped)
        owner.silent = nil
    end
    if snapped == owner.value then
        return
    end
    owner.value = snapped
    owner:UpdateDisplay()
    if owner.opts.set then
        owner.opts.set(snapped)
    end
end

-- opts: { label, labelWidth, min, max, step, get, set, format (string|function), width }.
function ForeverUI.CreateSlider(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, parent)
    for key, method in pairs(SliderMethods) do
        frame[key] = method
    end
    frame.opts = opts
    frame.enabled = true
    frame:SetSize(opts.width or 343, ROW_H)

    local leftOffset = 0
    if opts.label then
        local labelWidth = opts.labelWidth or LABEL_W
        frame.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        frame.label:SetPoint("LEFT", frame, "TOPLEFT", 0, -ROW_H / 2)
        frame.label:SetWidth(labelWidth)
        frame.label:SetJustifyH("LEFT")
        frame.labelRoom = labelWidth
        frame:SetLabel(opts.label)
        leftOffset = labelWidth + LABEL_GAP
    end

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("HORIZONTAL")
    frame.slider = slider
    frame.sliderLeft = leftOffset + SLIDER_INSET
    slider:SetHeight(ROW_H)
    slider.owner = frame
    frame:SetValueHidden(false)
    frame.bar = createBar(slider)
    setThumb(slider)

    frame.back = createStepper(slider, "back")
    frame.forward = createStepper(slider, "forward")
    trackLevels(slider, { { frame.back, 2 }, { frame.forward, 2 } })
    trackLevels(frame, { { slider, 1 } })
    frame.back:SetScript("OnClick", function()
        frame:Step(-1)
    end)
    frame.forward:SetScript("OnClick", function()
        frame:Step(1)
    end)

    frame.valueText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.valueText:SetPoint("LEFT", slider, "RIGHT", 25, 0)
    frame.valueText:SetJustifyH("LEFT")

    slider:SetScript("OnValueChanged", onSliderValueChanged)
    slider:SetScript("OnMouseDown", function()
        if frame.enabled then
            PlaySound("igMainMenuOptionCheckBoxOn")
        end
    end)

    frame:SetRange(opts.min or 0, opts.max or 1, opts.step or 0.01)
    frame:SetValue(opts.get and opts.get() or opts.min or 0)
    return frame
end

local function resolveSlider(target)
    if target.slider and target.editbox then
        return target.slider, target
    end
    return target, nil
end

-- target: an AceGUI Slider widget or a plain horizontal Slider; opts: { steppers = true }.
function ForeverUI.SkinSlider(target, opts)
    if not target then
        return
    end
    opts = opts or {}
    local slider, widget = resolveSlider(target)
    slider:SetBackdrop(nil)
    if not slider._fuBar then
        slider._fuBar = createBar(slider)
    end
    setThumb(slider)

    if opts.steppers ~= false then
        if not slider._fuBack then
            slider._fuBack = createStepper(slider, "back")
            slider._fuForward = createStepper(slider, "forward")
            local function nudge(direction)
                local lo, hi = slider:GetMinMaxValues()
                local step = slider:GetValueStep() or 1
                local value = max(lo, min(hi, slider:GetValue() + direction * step))
                PlaySound("igMainMenuOptionCheckBoxOn")
                slider:SetValue(value)
                if widget and widget.Fire then
                    widget:Fire("OnMouseUp", slider:GetValue())
                end
            end
            slider._fuBack:SetScript("OnClick", function()
                nudge(-1)
            end)
            slider._fuForward:SetScript("OnClick", function()
                nudge(1)
            end)
            local function refreshSteppers(self)
                local lo, hi = self:GetMinMaxValues()
                local value, step = self:GetValue(), self:GetValueStep() or 1
                local on = not self._fuDisabled
                setStepperState(self._fuBack, on and value > lo + step * 0.5)
                setStepperState(self._fuForward, on and value < hi - step * 0.5)
            end
            slider:HookScript("OnValueChanged", refreshSteppers)
            slider._fuRefreshSteppers = refreshSteppers
        end
        if widget and widget.label and widget.frame then
            slider:ClearAllPoints()
            slider:SetPoint("TOP", widget.label, "BOTTOM", 0, 0)
            slider:SetPoint("LEFT", widget.frame, "LEFT", 3 + 15, 0)
            slider:SetPoint("RIGHT", widget.frame, "RIGHT", -(3 + 13), 0)
        end
        slider._fuBack:Show()
        slider._fuForward:Show()
        slider._fuRefreshSteppers(slider)
        if widget and widget.SetDisabled and not widget._fuSliderWrapped then
            widget._fuSliderWrapped = true
            local original = widget.SetDisabled
            widget.SetDisabled = function(self, disabled)
                original(self, disabled)
                slider._fuDisabled = disabled and true or false
                slider:GetThumbTexture():SetAlpha(disabled and 0.7 or 1)
                slider._fuRefreshSteppers(slider)
            end
        end
    elseif slider._fuBack then
        slider._fuBack:Hide()
        slider._fuForward:Hide()
    end
    if widget and widget.editbox then
        ForeverUI.SkinEditBox(widget.editbox, { font = GameFontHighlight, height = 20 })
        widget.editbox:SetWidth(60)
        if widget.SetHeight then
            widget:SetHeight(50)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Edit box and search box
-- ---------------------------------------------------------------------------

local CARET_HALF = 0.5
local FOCUS_RGB = { 1, 0.82, 0 }
local FOCUS_ALPHA = 0.8
local SEARCH_TEXT_COLOR = { 0.35, 0.35, 0.35 }

local function stripTextures(frame, keep)
    for index = 1, frame:GetNumRegions() do
        local region = select(index, frame:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region ~= keep and not region._fuOwn then
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

-- Only the InputBoxTemplate border parts go: stripping the engine's own regions (caret, highlight) hides the caret.
local function stripEditBoxArt(box)
    local name = box:GetName()
    for _, part in ipairs({ "Left", "Middle", "Right" }) do
        local region = box[part] or (name and _G[name .. part])
        if region and region.SetTexture and region.Hide then
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

local function skinEditBoxFrame(box)
    if not box._fuSlice then
        stripEditBoxArt(box)
        box._fuSlice = createSlice(box, "BACKGROUND")
        for _, texture in pairs(box._fuSlice) do
            texture._fuOwn = true
        end
        setSlice(box._fuSlice, "common-search-border")
        placeSlice(box._fuSlice, box, -5, 0, 0)
    end
    box:SetBackdrop(nil)
    showSlice(box._fuSlice, true)
end

-- Second pass of the border art, additive and gold: it follows the rounded outline exactly.
local function focusSlice(box)
    if not box._fuFocusSlice then
        local slice = createSlice(box, "OVERLAY")
        setSlice(slice, "common-search-border")
        placeSlice(slice, box, -5, 0, 0)
        for _, texture in pairs(slice) do
            if type(texture) == "table" then
                texture._fuOwn = true
                texture:SetBlendMode("ADD")
                texture:SetVertexColor(FOCUS_RGB[1], FOCUS_RGB[2], FOCUS_RGB[3], FOCUS_ALPHA)
            end
        end
        showSlice(slice, false)
        box._fuFocusSlice = slice
    end
    return box._fuFocusSlice
end

local function setFocusVisual(box, on)
    showSlice(focusSlice(box), on)
end

-- First `count` UTF-8 characters of text.
local function charPrefix(text, count)
    local position, taken = 1, 0
    while taken < count and position <= #text do
        local byte = text:byte(position)
        position = position + (byte >= 240 and 4 or (byte >= 224 and 3 or (byte >= 192 and 2 or 1)))
        taken = taken + 1
    end
    return text:sub(1, position - 1)
end
ForeverUI.CharPrefix = charPrefix

local caretMeasurer

local function boxTextWidth(box, text)
    if text == "" then
        return 0
    end
    if not caretMeasurer then
        caretMeasurer = UIParent:CreateFontString(nil, "ARTWORK")
        caretMeasurer:Hide()
    end
    local path, size, flags = box:GetFont()
    if not (path and caretMeasurer:SetFont(path, size, flags)) then
        return nil
    end
    caretMeasurer:SetText(text)
    return caretMeasurer:GetStringWidth()
end

-- The native caret never shows in these boxes, so each draws its own; flip live with /run DragonUI.ForeverUI.CustomCaret = false
ForeverUI.CustomCaret = true

-- The blink phase comes from one global clock read by the shared focus watcher, so no cursor event can freeze it lit.
local function createCaret(box)
    local frame = CreateFrame("Frame", nil, box)
    frame:SetAllPoints(box)
    local line = frame:CreateTexture(nil, "OVERLAY")
    line:SetTexture(1, 1, 1, 1)
    line:SetSize(1, 14)
    frame.line = line
    frame.lit = true
    frame:Hide()
    box._fuCaret = frame
    return frame
end

-- The blink restarts only when asked or when the caret really moved, since OnCursorChanged can fire without a change.
local function updateCaret(box, restart)
    local caret = box._fuCaret
    if not caret then
        return
    end
    if not (ForeverUI.CustomCaret and box._fuFocus and not box._fuDisabled and not box._fuSelected) then
        caret:Hide()
        box._fuLastX = nil
        return
    end
    local left, right = box:GetTextInsets()
    local x
    if box._fuRawX then
        x = box._fuRawX + (box._fuShift or left)
    else
        local width = boxTextWidth(box, charPrefix(box:GetText() or "", box:GetCursorPosition() or 0))
        x = left + (width or 0)
    end
    x = max(left - 1, min((box:GetWidth() or 0) - right + 1, x))
    local height = min(box._fuCaretH or 14, max(8, (box:GetHeight() or 20) - 4))
    caret:SetFrameLevel(box:GetFrameLevel() + 3)
    if x ~= box._fuLastX or height ~= box._fuLastH then
        box._fuLastX, box._fuLastH = x, height
        caret.line:SetHeight(height)
        caret.line:ClearAllPoints()
        caret.line:SetPoint("LEFT", box, "LEFT", x, 0)
    end
    if restart or not caret:IsShown() then
        box._fuBlinkStart = GetTime()
        caret.lit = true
        caret.line:Show()
    end
    caret:Show()
end

-- One shared watcher drops the focus of a library edit box when the left button goes down anywhere outside it.
local clickAway = { boxes = {} }

local function insideBox(box, frame)
    local depth = 0
    while frame and depth < 10 do
        if frame == box then
            return true
        end
        frame = frame:GetParent()
        depth = depth + 1
    end
    return false
end

local function watchClicks(box, on)
    local boxes = clickAway.boxes
    boxes[box] = on and true or nil
    local watcher = clickAway.frame
    if on then
        if not watcher then
            watcher = CreateFrame("Frame")
            clickAway.frame = watcher
            -- 20 Hz is plenty for a half-second blink and a click check, and it only runs while a box has focus.
            watcher:SetScript("OnUpdate", function(self, elapsed)
                self.idle = (self.idle or 0) + elapsed
                if self.idle < 0.05 then return end
                self.idle = 0
                local down = IsMouseButtonDown("LeftButton") and true or false
                local pressed = down and not self.wasDown
                self.wasDown = down
                if pressed then
                    local focus = GetMouseFocus()
                    for owner in pairs(clickAway.boxes) do
                        if not insideBox(owner, focus) then
                            owner:ClearFocus()
                        end
                    end
                end
                local now = GetTime()
                for owner in pairs(clickAway.boxes) do
                    local caret = owner._fuCaret
                    if caret and caret:IsShown() then
                        local lit = (now - (owner._fuBlinkStart or now)) % (CARET_HALF * 2) < CARET_HALF
                        if lit ~= caret.lit then
                            caret.lit = lit
                            if lit then
                                caret.line:Show()
                            else
                                caret.line:Hide()
                            end
                        end
                    end
                end
            end)
        end
        watcher.wasDown = IsMouseButtonDown("LeftButton") and true or false
        watcher:Show()
    elseif watcher and next(boxes) == nil then
        watcher:Hide()
    end
end

-- Works out once whether OnCursorChanged x already includes the text insets, by comparing with the measured text.
local function calibrateCaret(box, x)
    if box._fuShift ~= nil then
        return
    end
    local left = box:GetTextInsets()
    local width = boxTextWidth(box, charPrefix(box:GetText() or "", box:GetCursorPosition() or 0))
    if not width or left < 3 then
        return
    end
    if math.abs(x - (left + width)) <= 2.5 then
        box._fuShift = 0
    elseif math.abs(x + left - (left + width)) <= 2.5 then
        box._fuShift = left
    end
end

local function caretHandlers(withCaret)
    local ours = {}
    ours.OnEditFocusGained = function(self)
        self._fuFocus = true
        self._fuSelected = false
        if self.fuHighlightOnFocus and self:GetText() ~= "" then
            self:HighlightText()
            self._fuSelected = true
        end
        setFocusVisual(self, true)
        watchClicks(self, true)
        if self._fuFocusExtra then
            self._fuFocusExtra(self, true)
        end
        if withCaret then
            updateCaret(self, true)
        end
    end
    ours.OnEditFocusLost = function(self)
        self._fuFocus = false
        self:HighlightText(0, 0)
        setFocusVisual(self, false)
        watchClicks(self, false)
        if self._fuFocusExtra then
            self._fuFocusExtra(self, false)
        end
        if withCaret then
            updateCaret(self)
        end
    end
    ours.OnCursorChanged = function(self, x, _, _, height)
        self._fuRawX = x
        if height and height >= 6 and height <= (self:GetHeight() or 99) then
            self._fuCaretH = height
        end
        self._fuSelected = false
        if withCaret then
            calibrateCaret(self, x)
            updateCaret(self)
        end
    end
    ours.OnTextChanged = function(self, userInput)
        self._fuSelected = false
        if withCaret then
            updateCaret(self, userInput and true or false)
        end
    end
    ours.OnHide = function(self)
        self._fuFocus = false
        setFocusVisual(self, false)
        watchClicks(self, false)
        if self._fuFocusExtra then
            self._fuFocusExtra(self, false)
        end
        if withCaret then
            updateCaret(self)
        end
    end
    ours.OnShow = function(self)
        if self:HasFocus() then
            self._fuFocus = true
            setFocusVisual(self, true)
            watchClicks(self, true)
            if withCaret then
                updateCaret(self, true)
            end
        end
    end
    return ours
end

-- Installs our handlers on the real script slots and routes later SetScript/GetScript calls for those names to a user slot.
local function installScripts(box, ours)
    box._fuUser = box._fuUser or {}
    local nativeSetScript, nativeGetScript = box.SetScript, box.GetScript
    for name, handler in pairs(ours) do
        nativeSetScript(box, name, function(self, ...)
            handler(self, ...)
            local user = self._fuUser[name]
            if user then
                user(self, ...)
            end
        end)
    end
    box.SetScript = function(self, name, handler)
        if ours[name] then
            self._fuUser[name] = handler
        else
            nativeSetScript(self, name, handler)
        end
    end
    box.GetScript = function(self, name)
        if ours[name] then
            return self._fuUser[name]
        end
        return nativeGetScript(self, name)
    end
    box._fuInstalled = true
end

-- target: an EditBox or an AceGUI widget holding one; opts: { font, height }. Keeps the native caret and scripts.
function ForeverUI.SkinEditBox(target, opts)
    if not target then
        return
    end
    opts = opts or {}
    local box = target.editbox or target
    skinEditBoxFrame(box)
    box:SetFontObject(opts.font or ChatFontNormal)
    box:SetTextInsets(4, 4, 0, 0)
    if opts.height then
        box:SetHeight(opts.height)
    end
    if not box._fuInstalled and not box._fuFocusHooked then
        box._fuFocusHooked = true
        box:HookScript("OnEditFocusGained", function(self)
            setFocusVisual(self, true)
        end)
        box:HookScript("OnEditFocusLost", function(self)
            setFocusVisual(self, false)
        end)
        box:HookScript("OnHide", function(self)
            setFocusVisual(self, false)
        end)
    end
end

local function editBoxEnable(self)
    self._fuDisabled = nil
    self:EnableMouse(true)
    self:SetFontObject(ChatFontNormal)
    self:SetAlpha(1)
    updateCaret(self, true)
end

local function editBoxDisable(self)
    self._fuDisabled = true
    self:ClearFocus()
    self:EnableMouse(false)
    self:SetFontObject(GameFontDisable)
    updateCaret(self)
end

local function newEditBox(parent, width, height, ours)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, height)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(4, 4, 0, 0)
    -- XML edit boxes carry blinkSpeed; one made in Lua may not, and a caret that never blinks may never show.
    if box.SetBlinkSpeed then
        box:SetBlinkSpeed(0.5)
    end
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box.Enable = editBoxEnable
    box.Disable = editBoxDisable
    skinEditBoxFrame(box)
    local caret = createCaret(box)
    if caret then
        trackLevels(box, { { caret, 3 } })
    end
    installScripts(box, ours)
    return box
end

-- Keep the text left-aligned: the drawn caret is placed for left-aligned text.
function ForeverUI.CreateEditBox(parent, width, height)
    local box = newEditBox(parent, width or 150, height or 20, caretHandlers(true))
    box.fuHighlightOnFocus = true
    return box
end

-- OnTextChanged and the other scripts the box owns go to a user slot: assign them with SetScript as usual.
function ForeverUI.CreateSearchBox(parent, width, placeholder)
    local box, hint, clear, refresh, fitHint
    local ours = caretHandlers(true)
    local sharedText = ours.OnTextChanged
    ours.OnTextChanged = function(self, ...)
        sharedText(self, ...)
        refresh(self)
    end
    ours.OnSizeChanged = function(self)
        fitHint(self)
        updateCaret(self)
    end
    box = newEditBox(parent, width or 350, SEARCH_H, ours)
    box:SetTextInsets(16, 20, 0, 0)

    local icon = box:CreateTexture(nil, "OVERLAY")
    SetAtlas(icon, "common-search-magnifyingglass", false)
    icon:SetSize(10, 10)
    icon:SetPoint("LEFT", box, "LEFT", 1, -1)
    icon:SetVertexColor(0.6, 0.6, 0.6)
    box.searchIcon = icon

    hint = box:CreateFontString(nil, "BORDER", "GameFontDisableSmall")
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("MIDDLE")
    hint:SetTextColor(SEARCH_TEXT_COLOR[1], SEARCH_TEXT_COLOR[2], SEARCH_TEXT_COLOR[3])
    box.hint = hint

    local function placeHint(self)
        local shift = self._fuFocus and 3 or 0
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", self, "TOPLEFT", 16 + shift, 0)
        hint:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -20, 0)
        hint:SetAlpha(self._fuFocus and 0.6 or 1)
    end
    placeHint(box)

    clear = CreateFrame("Button", nil, box)
    clear:SetSize(17, 17)
    clear:SetFrameLevel(box:GetFrameLevel() + 2)
    trackLevels(box, { { clear, 2 } })
    clear:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    local cross = clear:CreateTexture(nil, "ARTWORK")
    SetAtlas(cross, "common-search-clearbutton", false)
    cross:SetSize(10, 10)
    cross:SetPoint("TOPLEFT", clear, "TOPLEFT", 3, -3)
    cross:SetAlpha(0.5)
    clear:SetScript("OnEnter", function()
        cross:SetAlpha(1)
    end)
    clear:SetScript("OnLeave", function()
        cross:SetAlpha(0.5)
    end)
    clear:SetScript("OnMouseDown", function()
        cross:SetPoint("TOPLEFT", clear, "TOPLEFT", 4, -4)
    end)
    clear:SetScript("OnMouseUp", function()
        cross:SetPoint("TOPLEFT", clear, "TOPLEFT", 3, -3)
    end)
    clear:SetScript("OnClick", function()
        box:SetText("")
        box:ClearFocus()
    end)
    clear:Hide()
    box.clearButton = clear

    refresh = function(self)
        if self:GetText() == "" then
            hint:Show()
            clear:Hide()
        else
            hint:Hide()
            clear:Show()
        end
    end

    box._fuFocusExtra = function(self, on)
        if on then
            icon:SetVertexColor(1, 1, 1)
        elseif self:GetText() == "" then
            icon:SetVertexColor(0.6, 0.6, 0.6)
        end
        placeHint(self)
    end

    fitHint = function(self)
        fitText(hint, "GameFontDisableSmall", self.placeholderText or "", (self:GetWidth() or 0) - 36)
    end

    function box:SetPlaceholder(text)
        self.placeholderText = text or ""
        fitHint(self)
    end

    box:SetPlaceholder(placeholder or SEARCH)
    refresh(box)
    return box
end

-- ---------------------------------------------------------------------------
-- Dropdown
-- ---------------------------------------------------------------------------

local STYLE_KEYS = {
    wow1 = { arrow = { pressedhover = "-pressedhover", hover = "-hover", pressed = "-pressed", open = "-open", normal = "", disabled = "-disabled" } },
    wow2 = { back = { pressedhover = "-pressedhover-1", hover = "-hover-1", pressed = "-pressed-1", open = "-open", normal = "", disabled = "-disabled" } },
}

local function stateOf(button)
    if not isEnabled(button) then
        return "disabled"
    end
    if button._down and button._over then
        return "pressedhover"
    elseif button._over then
        return "hover"
    elseif button._down then
        return "pressed"
    elseif addon.Menu and addon.Menu.IsOpenFor and addon.Menu.IsOpenFor(button) then
        return "open"
    end
    return "normal"
end

local function updateDropdownTextFit(button)
    local text = button._fuText
    local width = button:GetWidth() or 0
    local fontName = button._fuFont
    local avail = button._fuStyle == "wow1" and (width - 34) or (width - 26)
    fitText(button.text, fontName, text, avail)
end

local function updateDropdown(button)
    local style = button._fuStyle
    local state = stateOf(button)
    local fontName
    if state == "disabled" then
        fontName = "GameFontDisable"
    else
        fontName = style == "wow1" and "GameFontHighlight" or "GameFontNormal"
    end
    if button._fuFont ~= fontName then
        button._fuFont = fontName
        button.text:SetFontObject(_G[fontName])
        updateDropdownTextFit(button)
    end
    if style == "wow1" then
        SetAtlas(button.arrow, "common-dropdown-a-button" .. STYLE_KEYS.wow1.arrow[state], false)
    else
        setSlice(button._fuBack, "common-dropdown-c-button" .. STYLE_KEYS.wow2.back[state] .. "-slice")
        if (state == "hover" or state == "pressedhover") then
            button.hoverArrow:Show()
        else
            button.hoverArrow:Hide()
        end
        local shift = (state == "pressed" or state == "pressedhover") and 1 or 0
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", button, "LEFT", 13 + shift * 2, -shift)
        button.text:SetPoint("RIGHT", button, "RIGHT", -13 + shift * 2, -shift)
    end
end

local function buildDropdownVisual(button, style)
    button._fuStyle = style
    button:SetHeight(DROPDOWN_H)
    if style == "wow1" then
        button._fuBack = createSlice(button, "BACKGROUND")
        setSlice(button._fuBack, "common-dropdown-textholder")
        placeSlice(button._fuBack, button, -8, 8, -1)
        local arrow = button:CreateTexture(nil, "OVERLAY")
        SetAtlas(arrow, "common-dropdown-a-button", true)
        arrow:SetPoint("RIGHT", button, "RIGHT", 1, -3)
        button.arrow = arrow
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetHeight(12)
        text:SetPoint("LEFT", button, "LEFT", 8, 0)
        text:SetPoint("RIGHT", arrow, "LEFT", 0, 0)
        button.text = text
    else
        button._fuBack = createSlice(button, "BACKGROUND")
        setSlice(button._fuBack, "common-dropdown-c-button-slice")
        placeSlice(button._fuBack, button, -7, 7, 0)
        local arrow = button:CreateTexture(nil, "OVERLAY")
        SetAtlas(arrow, "common-dropdown-c-button-hover-arrow", true)
        arrow:SetPoint("BOTTOM", button, "BOTTOM", 0, -5)
        arrow:Hide()
        button.hoverArrow = arrow
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetJustifyH("CENTER")
        text:SetHeight(12)
        text:SetPoint("LEFT", button, "LEFT", 13, 0)
        text:SetPoint("RIGHT", button, "RIGHT", -13, 0)
        button.text = text
    end
    button._fuFont = style == "wow1" and "GameFontHighlight" or "GameFontNormal"
end

local function hookDropdownMouse(button)
    button:SetScript("OnEnter", function(self)
        self._over = true
        updateDropdown(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._over = false
        updateDropdown(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        if isEnabled(self) then
            self._down = true
            updateDropdown(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        self._down = false
        updateDropdown(self)
    end)
    button:SetScript("OnSizeChanged", updateDropdownTextFit)
end

local function itemParts(item)
    if type(item) == "table" then
        local value = item.value
        if value == nil then
            value = item[1]
        end
        local text = item.text or item[2]
        if text == nil then
            text = tostring(value)
        end
        return value, text, item.disabled
    end
    return item, tostring(item), nil
end

local function itemsOf(dropdown)
    if dropdown.builder then
        return dropdown.builder() or {}
    end
    return dropdown.items or {}
end

local function currentValue(dropdown)
    if dropdown.getter then
        return dropdown.getter()
    end
    return dropdown.selected
end

local DropdownMethods = {}

function DropdownMethods:SetText(text)
    self._fuText = text or ""
    updateDropdownTextFit(self)
end

function DropdownMethods:GetText()
    return self._fuText
end

function DropdownMethods:UpdateSteppers()
    local steppers = self.steppers
    if not steppers then
        return
    end
    local on = isEnabled(self)
    local list, index = itemsOf(self), nil
    local current = currentValue(self)
    for position, item in ipairs(list) do
        if (itemParts(item)) == current then
            index = position
        end
    end
    local function neighbour(from, direction)
        local position = from + direction
        while list[position] do
            local _, _, disabled = itemParts(list[position])
            if not disabled then
                return position
            end
            position = position + direction
        end
    end
    steppers.prevTarget = index and neighbour(index, -1) or nil
    steppers.nextTarget = index and neighbour(index, 1) or nil
    steppers.prev:RefreshState(on and steppers.prevTarget ~= nil)
    steppers.next:RefreshState(on and steppers.nextTarget ~= nil)
end

function DropdownMethods:Refresh()
    local current = currentValue(self)
    local shown
    for _, item in ipairs(itemsOf(self)) do
        local value, text = itemParts(item)
        if value == current then
            shown = text
            break
        end
    end
    self:SetText(shown or self.placeholder or "")
    self:UpdateSteppers()
    updateDropdown(self)
end

function DropdownMethods:SetSelection(value)
    self.selected = value
    self:Refresh()
end

function DropdownMethods:GetSelection()
    return currentValue(self)
end

function DropdownMethods:SetItems(items)
    self.items = items
    self.builder = nil
    self:Refresh()
end

function DropdownMethods:Choose(value)
    self.selected = value
    if self.setter then
        self.setter(value)
    end
    self:Refresh()
end

function DropdownMethods:OpenMenu()
    if not (addon.Menu and addon.Menu.Open) then
        return
    end
    local current = currentValue(self)
    local entries = {}
    for _, item in ipairs(itemsOf(self)) do
        local value, text, disabled = itemParts(item)
        entries[#entries + 1] = {
            text = text,
            checked = value == current,
            disabled = disabled,
            func = function()
                self:Choose(value)
            end,
        }
    end
    addon.Menu.Open(self, entries, { large = true, at = "BOTTOMLEFT", x = -4, y = 0, minWidth = self:GetWidth(), style = "forever" })
    self:SetScript("OnUpdate", function(button)
        if not addon.Menu.IsOpenFor(button) then
            button:SetScript("OnUpdate", nil)
            updateDropdown(button)
        end
    end)
    updateDropdown(self)
end

local function createStepperButton(dropdown, direction)
    local button = CreateFrame("Button", nil, dropdown)
    button:SetSize(26, 25)
    button:SetFrameLevel(dropdown:GetFrameLevel() + 2)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("CENTER", button, "CENTER", 0, 0)
    SetAtlas(back, "common-dropdown-c-button", true)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    local iconName = direction < 0 and "common-dropdown-icon-back" or "common-dropdown-icon-next"
    SetAtlas(icon, iconName, true)
    button._over, button._down, button._on = false, false, true

    function button:Paint()
        local key
        if not self._on then
            key = "-disabled"
        elseif self._down and self._over then
            key = "-pressedhover-2"
        elseif self._over then
            key = "-hover-2"
        elseif self._down then
            key = "-pressed-2"
        else
            key = ""
        end
        SetAtlas(back, "common-dropdown-c-button" .. key, true)
        SetAtlas(icon, iconName .. (self._on and "" or "-disabled"), true)
    end

    function button:RefreshState(on)
        self._on = on
        if on then
            self:Enable()
        else
            self:Disable()
        end
        self:Paint()
    end

    button:SetScript("OnEnter", function(self)
        self._over = true
        self:Paint()
    end)
    button:SetScript("OnLeave", function(self)
        self._over = false
        self:Paint()
    end)
    button:SetScript("OnMouseDown", function(self)
        self._down = true
        self:Paint()
    end)
    button:SetScript("OnMouseUp", function(self)
        self._down = false
        self:Paint()
    end)
    button:SetScript("OnClick", function()
        local steppers = dropdown.steppers
        local list = itemsOf(dropdown)
        local target = steppers[direction < 0 and "prevTarget" or "nextTarget"]
        if target and list[target] then
            PlaySound("igMainMenuOptionCheckBoxOn")
            dropdown:Choose((itemParts(list[target])))
        end
    end)
    if direction < 0 then
        button:SetPoint("RIGHT", dropdown, "LEFT", -5, 0)
    else
        button:SetPoint("LEFT", dropdown, "RIGHT", 4, 0)
    end
    return button
end

-- opts: { width, items = {value | {value=,text=,disabled=}}, builder, get, set, label, style = "wow1" | "wow2", steppers, placeholder }.
function ForeverUI.CreateDropdown(parent, opts)
    opts = opts or {}
    local style = opts.style == "wow2" and "wow2" or "wow1"
    local holder = parent
    local button = CreateFrame("Button", nil, holder)
    button:SetWidth(opts.width or (style == "wow2" and 220 or 150))
    for key, method in pairs(DropdownMethods) do
        button[key] = method
    end
    button.items, button.builder = opts.items, opts.builder
    button.getter, button.setter = opts.get, opts.set
    button.placeholder = opts.placeholder or addon.L["Click to select"]
    button:RegisterForClicks("LeftButtonUp")

    buildDropdownVisual(button, style)
    hookDropdownMouse(button)
    button:SetScript("OnClick", function(self)
        PlaySound("igMainMenuOptionCheckBoxOn")
        self:OpenMenu()
    end)

    local nativeEnable, nativeDisable = button.Enable, button.Disable
    function button:Enable()
        nativeEnable(self)
        self:Refresh()
    end
    function button:Disable()
        if addon.Menu and addon.Menu.IsOpenFor and addon.Menu.IsOpenFor(self) then
            addon.Menu.Close()
        end
        nativeDisable(self)
        self:Refresh()
    end

    if opts.label then
        button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        button.label:SetPoint("RIGHT", button, "LEFT", -(opts.steppers and 41 or 8), 0)
        button.label:SetText(opts.label)
    end

    if opts.steppers then
        button.steppers = {
            prev = createStepperButton(button, -1),
            next = createStepperButton(button, 1),
        }
        trackLevels(button, { { button.steppers.prev, 2 }, { button.steppers.next, 2 } })
    end

    button:Refresh()
    return button
end

-- Strips an existing Button or AceGUI dropdown widget and dresses it; opts: { style = "wow2" | "wow1" }.
function ForeverUI.SkinDropdownButton(target, opts)
    if not target then
        return
    end
    opts = opts or {}
    local style = opts.style == "wow1" and "wow1" or "wow2"
    local widget = target.dropdown and target.button and target or nil
    local holder = widget and widget.dropdown or target
    local arrowButton = widget and widget.button or nil
    local textString = widget and widget.text or (target.GetFontString and target:GetFontString()) or nil

    if not holder._fuSkin then
        stripTextures(holder)
        local back = CreateFrame("Frame", nil, holder)
        back:SetFrameLevel(holder:GetFrameLevel() + 1)
        if widget then
            back:SetPoint("TOPLEFT", holder, "TOPLEFT", 15, -2)
            back:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -21, 0)
        else
            back:SetAllPoints(holder)
        end
        local skin = { frame = back, style = style }
        skin.slice = createSlice(back, "BACKGROUND")
        holder._fuSkin = skin
        if arrowButton then
            arrowButton:SetParent(back)
            arrowButton:ClearAllPoints()
            skin.arrowButton = arrowButton
        end
        skin.hover = back:CreateTexture(nil, "OVERLAY")
        SetAtlas(skin.hover, "common-dropdown-c-button-hover-arrow", true)
        skin.hover:SetPoint("BOTTOM", back, "BOTTOM", 0, -5)
        skin.hover:Hide()
        local function repaint()
            local on = true
            if widget then
                on = not widget.disabled
            else
                on = isEnabled(holder)
            end
            local state = on and "normal" or "disabled"
            if on and skin.down and skin.over then
                state = "pressedhover"
            elseif on and skin.over then
                state = "hover"
            elseif on and skin.down then
                state = "pressed"
            end
            if skin.style == "wow1" then
                setSlice(skin.slice, "common-dropdown-textholder")
                if skin.arrowButton then
                    local key = STYLE_KEYS.wow1.arrow[state]
                    applyButtonTexture(skin.arrowButton, "Normal", "common-dropdown-a-button" .. key)
                    applyButtonTexture(skin.arrowButton, "Pushed", "common-dropdown-a-button-pressed")
                    applyButtonTexture(skin.arrowButton, "Disabled", "common-dropdown-a-button-disabled")
                end
            else
                setSlice(skin.slice, "common-dropdown-c-button" .. STYLE_KEYS.wow2.back[state] .. "-slice")
                if state == "hover" or state == "pressedhover" then
                    skin.hover:Show()
                else
                    skin.hover:Hide()
                end
                return
            end
            skin.hover:Hide()
        end
        skin.repaint = repaint
        local function track(frame)
            frame:HookScript("OnEnter", function()
                skin.over = true
                repaint()
            end)
            frame:HookScript("OnLeave", function()
                skin.over = false
                repaint()
            end)
            frame:HookScript("OnMouseDown", function()
                skin.down = true
                repaint()
            end)
            frame:HookScript("OnMouseUp", function()
                skin.down = false
                repaint()
            end)
        end
        track(arrowButton or holder)
        if widget and widget.SetDisabled and not widget._fuDropWrapped then
            widget._fuDropWrapped = true
            local original = widget.SetDisabled
            widget.SetDisabled = function(self, disabled)
                original(self, disabled)
                skin.repaint()
            end
        end
    end

    local skin = holder._fuSkin
    skin.style = style
    local back = skin.frame
    if style == "wow1" then
        placeSlice(skin.slice, back, -8, 8, -1)
        if skin.arrowButton then
            skin.arrowButton:ClearAllPoints()
            skin.arrowButton:SetSize(27, 27)
            skin.arrowButton:SetPoint("RIGHT", back, "RIGHT", 1, -3)
            skin.arrowButton:SetFrameLevel(back:GetFrameLevel() + 2)
        end
        if textString then
            textString:SetParent(back)
            textString:ClearAllPoints()
            textString:SetJustifyH("LEFT")
            textString:SetPoint("LEFT", back, "LEFT", 8, 0)
            textString:SetPoint("RIGHT", back, "RIGHT", -28, 0)
            textString:SetFontObject(GameFontHighlight)
        end
    else
        placeSlice(skin.slice, back, -7, 7, 0)
        if skin.arrowButton then
            skin.arrowButton:ClearAllPoints()
            skin.arrowButton:SetAllPoints(back)
            skin.arrowButton:SetFrameLevel(back:GetFrameLevel() + 2)
            clearButtonTexture(skin.arrowButton, "Normal")
            clearButtonTexture(skin.arrowButton, "Pushed")
            clearButtonTexture(skin.arrowButton, "Disabled")
            clearButtonTexture(skin.arrowButton, "Highlight")
        end
        if textString then
            textString:SetParent(back)
            textString:ClearAllPoints()
            textString:SetJustifyH("CENTER")
            textString:SetPoint("LEFT", back, "LEFT", 13, 0)
            textString:SetPoint("RIGHT", back, "RIGHT", -13, 0)
            textString:SetFontObject(GameFontNormal)
        end
    end
    skin.repaint()
end

-- ---------------------------------------------------------------------------
-- Menu panel art (9-slice), for addon.Menu levels or any popup frame
-- ---------------------------------------------------------------------------

local MENU_STYLES = {
    bg = { prefix = "common-dropdown-bg", left = -10, top = 3, right = 10, bottom = -3, cap = 20 },
    cbg = { prefix = "common-dropdown-c-bg", left = -17, top = 12, right = 17, bottom = -22, cap = 26 },
}

local CELLS = { "tl", "t", "tr", "l", "c", "r", "bl", "b", "br" }

-- A menu shorter than two corners squeezes them instead of letting them overlap.
local function FitMenuCorners(frame)
    local def, cells = frame._fuMenuDef, frame._fuMenuBg
    if not (def and cells and cells.tl:IsShown()) then return end
    local height = min(def.cap, ((frame:GetHeight() or 0) + def.top - def.bottom) / 2)
    for _, key in ipairs({ "tl", "tr", "bl", "br" }) do
        cells[key]:SetSize(def.cap, height)
    end
end

-- Returns the 9 textures table; `style` is "bg" (editor menus) or "cbg" (settings menus).
function ForeverUI.SkinMenuBackground(frame, style)
    local def = MENU_STYLES[style or "bg"] or MENU_STYLES.bg
    local cells = frame._fuMenuBg
    if not cells then
        cells = {}
        for _, key in ipairs(CELLS) do
            cells[key] = frame:CreateTexture(nil, "BACKGROUND")
        end
        frame._fuMenuBg = cells
        frame:HookScript("OnSizeChanged", FitMenuCorners)
    end
    frame._fuMenuDef = def
    frame:SetBackdrop(nil)
    for _, key in ipairs(CELLS) do
        local texture = cells[key]
        SetAtlas(texture, def.prefix .. "-" .. key, false)
        texture:ClearAllPoints()
        texture:Show()
    end
    FitMenuCorners(frame)
    cells.tl:SetPoint("TOPLEFT", frame, "TOPLEFT", def.left, def.top)
    cells.tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", def.right, def.top)
    cells.bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", def.left, def.bottom)
    cells.br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", def.right, def.bottom)
    cells.t:SetPoint("TOPLEFT", cells.tl, "TOPRIGHT", 0, 0)
    cells.t:SetPoint("BOTTOMRIGHT", cells.tr, "BOTTOMLEFT", 0, 0)
    cells.b:SetPoint("TOPLEFT", cells.bl, "TOPRIGHT", 0, 0)
    cells.b:SetPoint("BOTTOMRIGHT", cells.br, "BOTTOMLEFT", 0, 0)
    cells.l:SetPoint("TOPLEFT", cells.tl, "BOTTOMLEFT", 0, 0)
    cells.l:SetPoint("BOTTOMRIGHT", cells.bl, "TOPRIGHT", 0, 0)
    cells.r:SetPoint("TOPLEFT", cells.tr, "BOTTOMLEFT", 0, 0)
    cells.r:SetPoint("BOTTOMRIGHT", cells.br, "TOPRIGHT", 0, 0)
    cells.c:SetPoint("TOPLEFT", cells.tl, "BOTTOMRIGHT", 0, 0)
    cells.c:SetPoint("BOTTOMRIGHT", cells.br, "TOPLEFT", 0, 0)
    -- A pullout takes no mouse and the art reaches past the frame: border clicks fell through.
    frame:EnableMouse(true)
    frame:SetHitRectInsets(def.left, -def.right, -def.top, def.bottom)
    return cells
end

function ForeverUI.HideMenuBackground(frame)
    local cells = frame._fuMenuBg
    if cells then
        for _, texture in pairs(cells) do
            texture:Hide()
        end
        frame:SetHitRectInsets(0, 0, 0, 0)
    end
end

-- ---------------------------------------------------------------------------
-- Scroll bar
-- ---------------------------------------------------------------------------

local THUMB_SUFFIX = { up = "", over = "-over", down = "-down" }

local function paintThumb(state, name)
    if state.thumbState == name then
        return
    end
    state.thumbState = name
    local suffix = THUMB_SUFFIX[name]
    SetAtlas(state.thumbTop, "minimal-scrollbar-small-thumb-top" .. suffix, false)
    SetAtlas(state.thumbBottom, "minimal-scrollbar-small-thumb-bottom" .. suffix, false)
    SetAtlas(state.thumbMiddle, "minimal-scrollbar-small-thumb-middle" .. suffix, false)
end

-- The visible thumb is placed from the slider's value and dragged from the cursor, never through WoW's own
-- drag math, which comes out backwards on some clients when the thumb nearly fills the track (#516).
local function syncThumb(state)
    local slider, scrollFrame, holder = state.slider, state.scrollFrame, state.thumb
    local trackHeight = slider:GetHeight() or 0
    if trackHeight <= 0 then
        return
    end
    local extent = SCROLL_MIN_THUMB
    if scrollFrame then
        local view = scrollFrame:GetHeight() or 0
        local range = scrollFrame:GetVerticalScrollRange() or 0
        local child = scrollFrame:GetScrollChild()
        local total = max(view + range, child and child:GetHeight() or 0)
        if view > 0 and total > view then
            extent = floor(trackHeight * view / total + 0.5)
        end
    elseif state.fraction then
        extent = floor(trackHeight * state.fraction + 0.5)
    end
    extent = min(max(SCROLL_MIN_THUMB, extent), max(1, trackHeight - SCROLL_MIN_TRAVEL))

    local low, high = slider:GetMinMaxValues()
    low, high = low or 0, high or 0
    local travel = trackHeight - extent
    state.travel = travel
    holder:SetHeight(extent)
    holder:ClearAllPoints()
    if high - low <= 0 then
        holder:Hide()
        return
    end
    holder:Show()
    holder:SetPoint("TOP", slider, "TOP", 0, -floor(travel * (slider:GetValue() - low) / (high - low) + 0.5))
end

-- Distance from the track's top to the cursor, in the slider's own units.
local function cursorBelowTop(slider)
    local top = slider:GetTop()
    if not top then
        return nil
    end
    local _, cursorY = GetCursorPosition()
    return top - cursorY / slider:GetEffectiveScale()
end

local function setValueFromThumbTop(state, thumbTop)
    local slider, travel = state.slider, state.travel or 0
    local low, high = slider:GetMinMaxValues()
    if travel <= 0 or not low or high <= low then
        return
    end
    local ratio = thumbTop / travel
    if ratio < 0 then
        ratio = 0
    elseif ratio > 1 then
        ratio = 1
    end
    slider:SetValue(low + ratio * (high - low))
end

-- Polled rather than taken from OnMouseUp: releasing with the cursor off the bar never delivers it.
local dragger = CreateFrame("Frame")
dragger:Hide()
dragger:SetScript("OnUpdate", function(self)
    local state = self.state
    if not state or not IsMouseButtonDown("LeftButton") then
        self:Hide()
        if state then
            state.down = false
            state.watcher:Show()
        end
        return
    end
    local cursor = cursorBelowTop(state.slider)
    if cursor then
        setValueFromThumbTop(state, cursor - (self.grab or 0))
    end
end)

local function beginDrag(state)
    local slider, holder = state.slider, state.thumb
    local cursor = cursorBelowTop(slider)
    if not cursor or not holder:IsShown() then
        return
    end
    local thumbTop = (slider:GetTop() or 0) - (holder:GetTop() or slider:GetTop() or 0)
    local grab = cursor - thumbTop
    local height = holder:GetHeight() or 0
    -- Pressing the bare track picks the thumb up by its middle instead of jumping by a page.
    if grab < 0 or grab > height then
        grab = height / 2
    end
    dragger.state, dragger.grab = state, grab
    state.down = true
    state.watcher:Show()
    dragger:Show()
    setValueFromThumbTop(state, cursor - grab)
end

-- The track art is SCROLL_BAR_W wide even on an 8px pullout slider: the grab area widens to match it.
local function layoutGrabber(state)
    local slider, base, grabber = state.slider, state.baseInsets, state.grabber
    local width = slider:GetWidth() or 0
    local pad = (width > 0 and width < SCROLL_BAR_W) and (SCROLL_BAR_W - width) / 2 or 0
    grabber:ClearAllPoints()
    grabber:SetPoint("TOPLEFT", slider, "TOPLEFT", base[1] - pad, -base[3])
    grabber:SetPoint("BOTTOMRIGHT", slider, "BOTTOMRIGHT", pad - base[2], base[4])
end

local function findScrollParts(target)
    if target.scrollbar and target.scrollframe then
        return target.scrollbar, target.scrollframe
    end
    local kind = target.GetObjectType and target:GetObjectType()
    if kind == "Slider" then
        local parent = target:GetParent()
        if parent and parent.GetObjectType and parent:GetObjectType() == "ScrollFrame" then
            return target, parent
        end
        return target, nil
    elseif kind == "ScrollFrame" then
        local name = target:GetName()
        local slider = name and _G[name .. "ScrollBar"]
        if not slider then
            for index = 1, target:GetNumChildren() do
                local child = select(index, target:GetChildren())
                if child.GetObjectType and child:GetObjectType() == "Slider" then
                    slider = child
                    break
                end
            end
        end
        return slider, target
    end
end

local function findArrows(slider)
    local name = slider:GetName()
    local up = name and _G[name .. "ScrollUpButton"]
    local down = name and _G[name .. "ScrollDownButton"]
    if up and down then
        return up, down
    end
    local buttons = {}
    for index = 1, slider:GetNumChildren() do
        local child = select(index, slider:GetChildren())
        if child.GetObjectType and child:GetObjectType() == "Button" then
            buttons[#buttons + 1] = child
        end
    end
    return buttons[1], buttons[2]
end

local function skinArrow(button, which)
    applyButtonTexture(button, "Normal", "minimal-scrollbar-arrow-" .. which)
    applyButtonTexture(button, "Pushed", "minimal-scrollbar-arrow-" .. which .. "-down")
    applyButtonTexture(button, "Highlight", "minimal-scrollbar-arrow-" .. which .. "-over", "BLEND")
    local disabled = applyButtonTexture(button, "Disabled", "minimal-scrollbar-arrow-" .. which)
    setDesaturated(disabled, true)
    button:SetSize(SCROLL_BAR_W, 11)
end

local function buildScrollState(slider, scrollFrame, upButton, downButton, opts)
    local state = { slider = slider, scrollFrame = scrollFrame, baseInsets = { slider:GetHitRectInsets() } }
    slider._fuScroll = state

    local gap = opts.gap or SCROLL_GAP
    local track = {
        top = slider:CreateTexture(nil, "BACKGROUND"),
        bottom = slider:CreateTexture(nil, "BACKGROUND"),
        middle = slider:CreateTexture(nil, "BACKGROUND"),
    }
    for _, texture in pairs(track) do
        texture._fuOwn = true
    end
    SetAtlas(track.top, "minimal-scrollbar-track-top", true)
    SetAtlas(track.bottom, "minimal-scrollbar-track-bottom", true)
    SetAtlas(track.middle, "!minimal-scrollbar-track-middle", false)
    track.top:SetPoint("TOP", slider, "TOP", 0, 0)
    track.bottom:SetPoint("BOTTOM", slider, "BOTTOM", 0, 0)
    track.middle:SetPoint("TOPLEFT", track.top, "BOTTOMLEFT", 0, 0)
    track.middle:SetPoint("BOTTOMRIGHT", track.bottom, "TOPRIGHT", 0, 0)
    state.track = track

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local native = slider:GetThumbTexture()
    native:SetAlpha(0)
    native:SetSize(8, SCROLL_MIN_THUMB)
    state.nativeThumb = native

    local holder = CreateFrame("Frame", nil, slider)
    holder:SetWidth(8)
    holder:SetFrameLevel(slider:GetFrameLevel() + 1)
    state.thumb = holder
    state.thumbTop = holder:CreateTexture(nil, "ARTWORK")
    state.thumbBottom = holder:CreateTexture(nil, "ARTWORK")
    state.thumbMiddle = holder:CreateTexture(nil, "ARTWORK")
    for _, texture in pairs({ state.thumbTop, state.thumbBottom, state.thumbMiddle }) do
        texture._fuOwn = true
    end
    state.thumbTop:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    state.thumbTop:SetSize(8, 8)
    state.thumbBottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    state.thumbBottom:SetSize(8, 8)
    state.thumbMiddle:SetPoint("TOPLEFT", state.thumbTop, "BOTTOMLEFT", 0, 0)
    state.thumbMiddle:SetPoint("BOTTOMRIGHT", state.thumbBottom, "TOPRIGHT", 0, 0)
    paintThumb(state, "up")

    if upButton then
        skinArrow(upButton, "top")
        upButton:SetFrameLevel(slider:GetFrameLevel() + 2)
        upButton:ClearAllPoints()
        upButton:SetPoint("BOTTOM", slider, "TOP", 0, gap)
    end
    if downButton then
        skinArrow(downButton, "bottom")
        downButton:SetFrameLevel(slider:GetFrameLevel() + 2)
        downButton:ClearAllPoints()
        downButton:SetPoint("TOP", slider, "BOTTOM", 0, -gap)
    end

    -- The slider keeps the value and the range; this takes over its mouse, between the steppers.
    local grabber = CreateFrame("Button", nil, slider)
    grabber:SetFrameLevel(slider:GetFrameLevel() + 1)
    state.grabber = grabber
    slider:EnableMouse(false)

    local kids = { { holder, 1 }, { grabber, 1 } }
    if upButton then
        kids[#kids + 1] = { upButton, 2 }
    end
    if downButton then
        kids[#kids + 1] = { downButton, 2 }
    end
    trackLevels(slider, kids)

    local watcher = CreateFrame("Frame", nil, slider)
    watcher:Hide()
    state.watcher = watcher
    watcher:SetScript("OnUpdate", function(self)
        local over = MouseIsOver(holder)
        paintThumb(state, state.down and "down" or (over and "over" or "up"))
        if not over and not state.down then
            self:Hide()
        end
    end)
    grabber:SetScript("OnEnter", function()
        watcher:Show()
    end)
    grabber:SetScript("OnLeave", function()
        if not state.down then
            watcher:Show()
        end
    end)
    grabber:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            beginDrag(state)
        end
    end)

    local function sync()
        syncThumb(state)
    end
    slider:HookScript("OnValueChanged", sync)
    -- Not every client's Slider has this script; the range also arrives through the scroll frame below.
    pcall(slider.HookScript, slider, "OnMinMaxChanged", sync)
    slider:HookScript("OnSizeChanged", function()
        layoutGrabber(state)
        syncThumb(state)
    end)
    slider:HookScript("OnShow", sync)
    if scrollFrame then
        scrollFrame:HookScript("OnSizeChanged", sync)
        scrollFrame:HookScript("OnScrollRangeChanged", sync)
        local child = scrollFrame:GetScrollChild()
        if child then
            child:HookScript("OnSizeChanged", sync)
        end
    end
    layoutGrabber(state)
    syncThumb(state)
    return state
end

-- target: Slider, ScrollFrame (UIPanelScrollFrameTemplate-like) or an AceGUI ScrollFrame widget; opts: { gap }.
function ForeverUI.SkinScrollBar(target, opts)
    if not target then
        return
    end
    opts = opts or {}
    local slider, scrollFrame = findScrollParts(target)
    if not slider then
        return
    end
    local state = slider._fuScroll
    if not state then
        stripTextures(slider, slider:GetThumbTexture())
        if scrollFrame then
            local name = scrollFrame:GetName()
            if name then
                for _, suffix in ipairs({ "ScrollBarTop", "ScrollBarBottom", "ScrollBarMiddle" }) do
                    local region = _G[name .. suffix]
                    if region and region.SetTexture then
                        region:SetTexture(nil)
                        region:Hide()
                    end
                end
            end
        end
        local up, down = findArrows(slider)
        state = buildScrollState(slider, scrollFrame, up, down, opts)
    elseif scrollFrame and not state.scrollFrame then
        state.scrollFrame = scrollFrame
    end
    syncThumb(state)
    return slider
end

function ForeverUI.BindScrollBar(scrollFrame, slider, step)
    local function refreshRange(self)
        local range = scrollFrame:GetVerticalScrollRange() or 0
        slider.fuSilent = true
        slider:SetMinMaxValues(0, range)
        slider.fuSilent = nil
        if range <= 0 then
            slider:Hide()
        else
            slider:Show()
        end
    end
    slider:SetScript("OnValueChanged", function(self, value)
        -- SetScript dropped the skin's hook, so the thumb follows the value from here.
        local state = self._fuScroll
        if state then
            syncThumb(state)
        end
        if self.fuSilent then
            return
        end
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:HookScript("OnScrollRangeChanged", refreshRange)
    scrollFrame:HookScript("OnVerticalScroll", function(self, offset)
        slider.fuSilent = true
        slider:SetValue(offset)
        slider.fuSilent = nil
    end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:HookScript("OnMouseWheel", function(self, delta)
        local range = scrollFrame:GetVerticalScrollRange() or 0
        local amount = step or max(20, (scrollFrame:GetHeight() or 0) / 5)
        scrollFrame:SetVerticalScroll(max(0, min(range, scrollFrame:GetVerticalScroll() - delta * amount)))
    end)
    refreshRange()
end

-- Builds a bar of its own; opts: { scrollFrame, height, step, x }. With a scrollFrame it anchors and binds itself.
function ForeverUI.CreateScrollBar(parent, opts)
    opts = opts or {}
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(SCROLL_BAR_W)
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(1)
    slider:SetValue(0)
    local up = CreateFrame("Button", nil, slider)
    local down = CreateFrame("Button", nil, slider)
    local sf = opts.scrollFrame
    local state = buildScrollState(slider, sf, up, down, opts)
    slider.upButton, slider.downButton = up, down

    if sf then
        slider:SetPoint("TOPLEFT", sf, "TOPRIGHT", opts.x or 6, -(SCROLL_BAR_W + 2))
        slider:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", opts.x or 6, SCROLL_BAR_W + 2)
        ForeverUI.BindScrollBar(sf, slider, opts.step)
        local function stepBy(direction)
            local range = sf:GetVerticalScrollRange() or 0
            local amount = opts.step or max(20, (sf:GetHeight() or 0) / 5)
            sf:SetVerticalScroll(max(0, min(range, sf:GetVerticalScroll() + direction * amount)))
        end
        up:SetScript("OnClick", function()
            stepBy(-1)
        end)
        down:SetScript("OnClick", function()
            stepBy(1)
        end)
    elseif opts.height then
        slider:SetHeight(opts.height)
    end
    return slider, state
end

-- A bar with no scroll frame sizes its thumb from the share of the content in view.
function ForeverUI.SetScrollBarFraction(slider, fraction)
    local state = slider and slider._fuScroll
    if not state then
        return
    end
    state.fraction = fraction
    syncThumb(state)
end
