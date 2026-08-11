--[[
================================================================================
DragonUI Options Panel - Controls Library
================================================================================
Reusable control builders with auto-binding to addon.db.profile.
Post-skins AceGUI widgets for a clean, dark look.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO

local AceGUI = LibStub("AceGUI-3.0")

-- ============================================================================
-- MODULE
-- ============================================================================

local Controls = {}
addon.PanelControls = Controls

-- ============================================================================
-- SEARCH INDEX STUBS
-- ============================================================================

local STUB_NOOP = function() end
local STUB_MT   = { __index = function() return STUB_NOOP end }

-- Keep frame/content nil on stubs; __index would return a truthy noop.
local STUB_NIL_FIELDS = { content = true, frame = true, titletext = true, label = true }

local function MakeStub(extra)
    local t = extra or {}
    for field in pairs(STUB_NIL_FIELDS) do
        if rawget(t, field) == nil then
            t[field] = nil
        end
    end
    return setmetatable(t, STUB_MT)
end
Controls.MakeStub = MakeStub

local function safestr(v)
    if type(v) == "string" then return v end
    if v == nil then return "" end
    return tostring(v)
end

local function RecordSearchEntry(opts)
    local Panel = addon.OptionsPanel
    if not Panel or not Panel.searchIndex then return end
    local label    = safestr(opts.label)
    local desc     = safestr(opts.desc ~= nil and opts.desc or opts.tooltip)
    local dbPath   = safestr(opts.dbPath)
    local subTab   = safestr(Panel._currentSubTabLabel)
    local subTabKey = safestr(Panel._currentSubTabKey)
    local section  = safestr(Panel._currentSection)
    local tabText  = safestr(Panel._currentTabText)
    if label == "" and dbPath == "" then return end

    -- Fallback to sub-tab label when the control has no section.
    local displaySection
    if section ~= "" then
        displaySection = section
    elseif subTab ~= "" then
        displaySection = subTab
    end

    -- Include subTab in haystack for controls without a section.
    local haystack = string.lower(
        strjoin(" ", tabText, subTab, section, label, desc, dbPath)
    )
    Panel.searchIndex[#Panel.searchIndex + 1] = {
        tab      = Panel._currentIndexTab,
        tabText  = tabText,
        section  = displaySection,
        subTab   = (subTabKey ~= "" and subTabKey) or nil,
        label    = label,
        desc     = (desc ~= "" and desc) or nil,
        dbPath   = (dbPath ~= "" and dbPath) or nil,
        haystack = haystack,
    }
end

-- Stable widget id for search navigation (dbPath or label).
local function TagSearchId(widget, opts)
    if not widget or not opts then return end
    local id = opts.dbPath
    if not id or id == "" then id = opts.label end
    widget._dragonId = id
end

-- ============================================================================
-- THEME
-- ============================================================================

Controls.Theme = {
    accent      = { 0.09, 0.52, 0.82, 1 },
    accentHex   = "1784d1",
    headerBg    = { 0.12, 0.12, 0.14, 0.9 },
    sectionBg   = { 0.10, 0.10, 0.12, 0.8 },
    sectionBorder = { 0.22, 0.22, 0.24, 1 },
    textNormal  = { 0.9, 0.9, 0.9, 1 },
    textDim     = { 0.72, 0.72, 0.72, 1 },
    textGold    = { 1.0, 0.82, 0.0, 1 },
    warning     = { 1.0, 0.4, 0.0, 1 },
    success     = { 0.0, 1.0, 0.0, 1 },
    danger      = { 1.0, 0.2, 0.2, 1 },
    widgetBg    = { 0.14, 0.14, 0.16, 1 },
    widgetBorder = { 0.25, 0.25, 0.28, 1 },
    buttonBg    = { 0.16, 0.16, 0.18, 1 },
    buttonHover = { 0.09, 0.52, 0.82, 0.3 },
    font        = (addon.Fonts and addon.Fonts.NARROW) or "Interface\\AddOns\\DragonUI_Options\\fonts\\PTSansNarrow.ttf",
    fontSize    = 13,
}

local BD_WIDGET = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- Ensure widgets always receive a valid font even when a custom/system font path is unavailable.
local function SafeSetFont(fs, size, flags, preferredFont)
    if not fs then return end

    local tryFonts = {
        preferredFont,
        Controls.Theme.font,
        addon.Fonts and addon.Fonts.PRIMARY,
        STANDARD_TEXT_FONT,
        "Fonts\\FRIZQT__.TTF",
    }

    for _, fontPath in ipairs(tryFonts) do
        if fontPath and fs.SetFont and fs:SetFont(fontPath, size or 12, flags or "") then
            return
        end
    end

    if fs.SetFontObject then
        fs:SetFontObject(GameFontNormal)
    end
end

local function NormalizeText(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end
    if value == nil then
        return fallback
    end
    local converted = tostring(value)
    if converted == "" then
        return fallback
    end
    return converted
end

local function NormalizeDescription(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function NormalizeDropdownValues(values)
    if type(values) ~= "table" then
        return {}
    end
    local normalized = {}
    for key, label in pairs(values) do
        normalized[key] = NormalizeText(label, NormalizeText(key, ""))
    end
    return normalized
end

-- ============================================================================
-- DB PATH HELPERS
-- ============================================================================

function Controls:GetDBValue(dbPath)
    if not dbPath or not addon.db or not addon.db.profile then return nil end
    local path = { strsplit(".", dbPath) }
    local value = addon.db.profile
    for _, key in ipairs(path) do
        if type(value) ~= "table" then return nil end
        value = value[key]
    end
    return value
end

function Controls:SetDBValue(dbPath, val)
    if not dbPath or not addon.db or not addon.db.profile then return end
    local path = { strsplit(".", dbPath) }
    local target = addon.db.profile
    for i = 1, #path - 1 do
        if not target[path[i]] then target[path[i]] = {} end
        target = target[path[i]]
    end
    target[path[#path]] = val
end

function Controls:EnsureModuleTable(moduleName)
    if not addon.db or not addon.db.profile then
        return {}
    end

    if not addon.db.profile.modules then
        addon.db.profile.modules = {}
    end

    if not addon.db.profile.modules[moduleName] then
        addon.db.profile.modules[moduleName] = {}
    end

    return addon.db.profile.modules[moduleName]
end

-- ============================================================================
-- WIDGET SKINNING
-- ============================================================================

local function SkinCheckBox(widget)
    -- Darken the checkbox background
    if widget.checkbg then
        -- AceGUI reuses CheckBox widgets; always re-anchor so prior indent does not leak.
        local indent = widget._dragonCheckIndent or 0
        widget.checkbg:ClearAllPoints()
        widget.checkbg:SetPoint("TOPLEFT", indent, 0)
        widget.checkbg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        widget.checkbg:SetVertexColor(0.14, 0.14, 0.16, 1)
        widget.checkbg:SetWidth(18)
        widget.checkbg:SetHeight(18)
    end
    if widget.check then
        widget.check:SetVertexColor(0.09, 0.72, 1.0, 1)
    end
    if widget.highlight then
        widget.highlight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        widget.highlight:SetVertexColor(0.09, 0.52, 0.82, 0.2)
    end
    -- Style text
    if widget.text then
        SafeSetFont(widget.text, 12, "")
    end
    if widget.desc then
        SafeSetFont(widget.desc, 11, "")
    end
end

local function SkinSlider(widget)
    -- Skin once; re-applying backdrop/thumb causes a one-frame thumb blink.
    if widget.slider and not widget.slider._dragonSkinned then
        widget.slider:SetBackdrop(BD_WIDGET)
        widget.slider:SetBackdropColor(0.14, 0.14, 0.16, 1)
        widget.slider:SetBackdropBorderColor(0.22, 0.22, 0.24, 1)

        local thumb = widget.slider:GetThumbTexture()
        if thumb then
            thumb:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            thumb:SetVertexColor(0.09, 0.52, 0.82, 1)
            thumb:SetWidth(12)
            thumb:SetHeight(12)
        end

        widget.slider._dragonSkinned = true
    end
    if widget.editbox and not widget.editbox._dragonSkinned then
        widget.editbox:SetBackdrop(BD_WIDGET)
        widget.editbox:SetBackdropColor(0.12, 0.12, 0.14, 1)
        widget.editbox:SetBackdropBorderColor(0.22, 0.22, 0.24, 1)
        widget.editbox._dragonSkinned = true
    end
    if widget.editbox then
        SafeSetFont(widget.editbox, 11, "")
    end
    if widget.label then
        SafeSetFont(widget.label, 12, "")
    end
end

local function SkinDropdown(widget)
    local dd = widget.dropdown
    if not dd or dd._dragonSkinned then return end
    dd._dragonSkinned = true

    local function SyncDropdownButtonState()
        local disabled = widget.disabled == true
        if widget.button and widget.button.GetNormalTexture and widget.button:GetNormalTexture() then
            widget.button:GetNormalTexture():SetVertexColor(disabled and 0.4 or 0.7, disabled and 0.4 or 0.7, disabled and 0.4 or 0.7, disabled and 0.8 or 1)
        end
        if widget.button and widget.button.GetHighlightTexture and widget.button:GetHighlightTexture() then
            if disabled then
                widget.button:GetHighlightTexture():SetVertexColor(0, 0, 0, 0)
            else
                widget.button:GetHighlightTexture():SetVertexColor(0.09, 0.52, 0.82, 0.6)
            end
        end
    end

    local originalSetDisabled = widget.SetDisabled
    widget.SetDisabled = function(self, disabled)
        originalSetDisabled(self, disabled)
        SyncDropdownButtonState()
    end

    -- 1. Strip all texture regions from UIDropDownMenuTemplate
    if dd.GetNumRegions then
        for i = 1, dd:GetNumRegions() do
            local region = select(i, dd:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end
    end

    -- 2. Create dark backdrop on the dropdown frame itself
    local bg = CreateFrame("Frame", nil, dd)
    bg:SetFrameLevel(dd:GetFrameLevel())
    bg:SetBackdrop(BD_WIDGET)
    bg:SetBackdropColor(0.14, 0.14, 0.16, 1)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    bg:SetPoint("TOPLEFT", dd, "TOPLEFT", 15, -2)
    bg:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", -21, 0)
    dd.backdrop = bg

    -- 3. Reposition arrow button to the right edge of the backdrop
    local btn = widget.button
    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", bg, "TOPRIGHT", -22, -2)
        btn:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -2, 2)
        btn:SetParent(bg)
        if btn:GetNormalTexture() then
            btn:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1)
        end
        if btn:GetHighlightTexture() then
            btn:GetHighlightTexture():SetVertexColor(0.09, 0.52, 0.82, 0.6)
        end
    end

    -- 4. Reposition display text inside the backdrop (MUST reparent so it draws above)
    local text = widget.text
    if text then
        text:SetParent(bg)
        text:ClearAllPoints()
        text:SetJustifyH("LEFT")
        text:SetPoint("LEFT", bg, "LEFT", 5, 0)
        if btn then
            text:SetPoint("RIGHT", btn, "LEFT", -3, 0)
        end
        SafeSetFont(text, 12, "")
        text:SetVertexColor(1, 1, 1)
    end

    -- 5. Label above the backdrop
    if widget.label then
        widget.label:ClearAllPoints()
        widget.label:SetPoint("BOTTOMLEFT", bg, "TOPLEFT", 2, 1)
        SafeSetFont(widget.label, 12, "")
        widget.label:SetTextColor(1, 0.82, 0)
    end

    -- 6. Pullout skinning (immediate + lazy via button hook)
    local function SkinPullout()
        local po = widget.pullout
        if po and po.frame and not po.frame._dragonSkinned then
            po.frame._dragonSkinned = true
            po.frame:SetBackdrop(BD_WIDGET)
            po.frame:SetBackdropColor(0.10, 0.10, 0.12, 0.98)
            po.frame:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
            if po.slider then
                po.slider:SetBackdrop(BD_WIDGET)
                po.slider:SetBackdropColor(0.14, 0.14, 0.16, 1)
                po.slider:SetBackdropBorderColor(0.20, 0.20, 0.22, 1)
                local thumb = po.slider:GetThumbTexture()
                if thumb then
                    thumb:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                    thumb:SetVertexColor(0.09, 0.52, 0.82, 1)
                    thumb:SetWidth(8)
                    thumb:SetHeight(16)
                end
            end
        end
    end
    SkinPullout()
    if btn then
        btn:HookScript("OnClick", SkinPullout)
    end

    originalSetDisabled(widget, widget.disabled == true)
    SyncDropdownButtonState()
end

local function SkinButton(widget)
    local f = widget.frame
    if f then
        -- Strip ALL texture regions from UIPanelButtonTemplate2 (Left/Middle/Right)
        -- Use the same texture-stripping approach as the dropdown skinning
        if f.GetNumRegions then
            for i = 1, f:GetNumRegions() do
                local region = select(i, f:GetRegions())
                if region and region.IsObjectType and region:IsObjectType("Texture") then
                    region:SetTexture(nil)
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
        end

        -- Also strip named button textures if they exist
        local name = f:GetName()
        if name then
            for _, suffix in ipairs({"Left", "Middle", "Right", "left", "middle", "right"}) do
                local tex = _G[name .. suffix]
                if tex and tex.SetTexture then
                    tex:SetTexture(nil)
                    tex:SetAlpha(0)
                    tex:Hide()
                end
            end
        end

        f:SetBackdrop(BD_WIDGET)
        f:SetBackdropColor(0.16, 0.16, 0.18, 1)
        f:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

        -- Re-create highlight as a child frame texture so it draws above backdrop
        if not f._dragonHighlight then
            local hl = f:CreateTexture(nil, "HIGHLIGHT")
            hl:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            hl:SetVertexColor(0.09, 0.52, 0.82, 0.25)
            hl:SetAllPoints()
            f._dragonHighlight = hl
        end

        -- Strip the template highlight/normal/pushed/disabled if still lingering
        if f:GetNormalTexture() then f:GetNormalTexture():SetTexture(nil); f:GetNormalTexture():SetAlpha(0) end
        if f:GetPushedTexture() then f:GetPushedTexture():SetTexture(nil); f:GetPushedTexture():SetAlpha(0) end
        if f:GetHighlightTexture() then f:GetHighlightTexture():SetTexture(nil); f:GetHighlightTexture():SetAlpha(0) end
        if f:GetDisabledTexture() then f:GetDisabledTexture():SetTexture(nil); f:GetDisabledTexture():SetAlpha(0) end

        -- Style text
        if widget.text then
            SafeSetFont(widget.text, 11, "")
        end
    end
end

local function SkinLabel(widget)
    if widget.label then
        SafeSetFont(widget.label, 11, "")
    end
end

local function SkinHeading(widget)
    if widget.label then
        SafeSetFont(widget.label, 13, "OUTLINE")
        widget.label:SetTextColor(unpack(Controls.Theme.accent))
    end
    -- Make the separator lines match theme
    if widget.left then
        widget.left:SetVertexColor(0.22, 0.22, 0.24, 1)
    end
    if widget.right then
        widget.right:SetVertexColor(0.22, 0.22, 0.24, 1)
    end
end

-- Skin InlineGroup to match dark theme
local function SkinInlineGroup(widget)
    -- The border frame
    local border = widget.content and widget.content:GetParent()
    if border and border.SetBackdrop then
        border:SetBackdrop(BD_WIDGET)
        border:SetBackdropColor(0.08, 0.08, 0.10, 0.6)
        border:SetBackdropBorderColor(0.20, 0.20, 0.22, 0.8)
    end
    if widget.titletext then
        SafeSetFont(widget.titletext, 13, "OUTLINE")
        widget.titletext:SetTextColor(unpack(Controls.Theme.textGold))
    end
end

-- ============================================================================
-- DEFERRED RE-SKIN (fixes vanilla texture bleed-through after reload)
-- ============================================================================

function Controls:ClearSearchFontTags(container)
    if not container or not container.children then return end
    for _, child in ipairs(container.children) do
        child._dragonSearchFont = nil
        if child.children then
            self:ClearSearchFontTags(child)
        end
    end
end

local function ReskinWidget(widget)
    if not widget or not widget.type then return end
    local t = widget.type
    if t == "CheckBox" then
        SkinCheckBox(widget)
    elseif t == "Slider" then
        SkinSlider(widget)
    elseif t == "Dropdown" then
        -- Force re-skin by clearing the flag
        if widget.dropdown then widget.dropdown._dragonSkinned = nil end
        SkinDropdown(widget)
    elseif t == "Button" then
        SkinButton(widget)
    elseif t == "Label" then
        if widget._dragonSearchFont and widget.label then
            SafeSetFont(widget.label, widget._dragonSearchFont[2], widget._dragonSearchFont[3], widget._dragonSearchFont[1])
        else
            SkinLabel(widget)
        end
    elseif t == "InteractiveLabel" then
        if widget._dragonSubTabFont and widget.label then
            SafeSetFont(widget.label, widget._dragonSubTabFont[2], widget._dragonSubTabFont[3], widget._dragonSubTabFont[1])
        elseif widget._dragonSearchFont and widget.label then
            SafeSetFont(widget.label, widget._dragonSearchFont[2], widget._dragonSearchFont[3], widget._dragonSearchFont[1])
        end
    elseif t == "Heading" then
        SkinHeading(widget)
    elseif t == "InlineGroup" then
        SkinInlineGroup(widget)
    end
end

local function ReskinContainer(container)
    if not container or not container.children then return end
    for _, child in ipairs(container.children) do
        ReskinWidget(child)
        -- Recurse into containers (InlineGroup, SimpleGroup, ScrollFrame)
        if child.children then
            ReskinContainer(child)
        end
    end
end

function Controls:ReskinAll(scrollWidget)
    if scrollWidget then
        ReskinContainer(scrollWidget)
    end
end

-- ============================================================================
-- HEADING / SECTION SEPARATOR
-- ============================================================================

function Controls:AddHeading(parent, text)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    SkinHeading(heading)
    parent:AddChild(heading)
    return heading
end

-- ============================================================================
-- DESCRIPTION / LABEL
-- ============================================================================

function Controls:AddLabel(parent, text, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    opts = opts or {}
    local label = AceGUI:Create("Label")
    label:SetText(text)
    label:SetFullWidth(true)
    if opts.color then
        label:SetColor(unpack(opts.color))
    end
    SkinLabel(label)
    parent:AddChild(label)
    return label
end

function Controls:AddDescription(parent, text)
    return self:AddLabel(parent, text, { color = self.Theme.textDim })
end

function Controls:AddCopyableText(parent, text)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    local editBox = AceGUI:Create("EditBox")
    editBox:SetText(text)
    editBox:SetFullWidth(true)
    editBox:DisableButton(true)
    editBox:SetCallback("OnEnterPressed", function(w)
        if w and w.ClearFocus then
            w:ClearFocus()
            return
        end
        if w and w.editbox and w.editbox.ClearFocus then
            w.editbox:ClearFocus()
        end
    end)
    editBox:SetCallback("OnTextChanged", function(w) w:SetText(text) end)
    parent:AddChild(editBox)
    return editBox
end

-- ============================================================================
-- SPACER
-- ============================================================================

function Controls:AddSpacer(parent)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    parent:AddChild(spacer)
    return spacer
end

-- ============================================================================
-- TOGGLE (CheckBox)
-- ============================================================================

function Controls:AddToggle(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local cb = AceGUI:Create("CheckBox")
    local label = NormalizeText(opts.label, "Toggle")
    local desc = NormalizeDescription(opts.desc)
    cb:SetLabel(label)
    if desc then cb:SetDescription(desc) end
    -- relWidth packs toggles into columns inside a Flow container (e.g. 0.33 = 3 per row)
    if opts.relWidth then
        cb:SetRelativeWidth(opts.relWidth)
    elseif opts.width then
        cb:SetWidth(opts.width)
    else
        cb:SetFullWidth(true)
    end

    -- `tooltip` shows the text on hover instead of as an always-visible description
    local tooltip = NormalizeDescription(opts.tooltip)
    if tooltip then
        -- ANCHOR_CURSOR: the AceGUI row spans the full panel width, so frame anchors land far away
        cb.frame:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb.frame:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if opts.getFunc then
        cb:SetValue(opts.getFunc() and true or false)
    elseif opts.dbPath then
        cb:SetValue(self:GetDBValue(opts.dbPath) and true or false)
    end

    if opts.disabled then
        if type(opts.disabled) == "function" then
            cb:SetDisabled(opts.disabled())
        else
            cb:SetDisabled(opts.disabled)
        end
    end

    -- Must assign every time: AceGUI recycles CheckBoxes and a prior indent would leak.
    cb._dragonCheckIndent = opts.indent

    cb:SetCallback("OnValueChanged", function(_, _, value)
        if opts.setFunc then
            opts.setFunc(value)
        elseif opts.dbPath then
            self:SetDBValue(opts.dbPath, value)
        end
        if opts.callback then opts.callback(value) end
        if opts.requiresReload then StaticPopup_Show("DRAGONUI_RELOAD_UI") end
    end)

    SkinCheckBox(cb)
    TagSearchId(cb, opts)
    parent:AddChild(cb)
    return cb
end

-- ============================================================================
-- SLIDER
-- ============================================================================

function Controls:AddSlider(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local slider = AceGUI:Create("Slider")
    local label = NormalizeText(opts.label, "Slider")
    local desc = NormalizeDescription(opts.desc)
    slider:SetLabel(label)
    slider:SetSliderValues(opts.min or 0, opts.max or 1, opts.step or 0.01)
    if opts.isPercent then slider:SetIsPercent(true) end
    if opts.width then slider:SetWidth(opts.width) end

    local val
    if opts.getFunc then
        val = opts.getFunc()
    elseif opts.dbPath then
        val = self:GetDBValue(opts.dbPath)
    end
    slider:SetValue(val or opts.default or opts.min or 0)

    if opts.disabled then
        if type(opts.disabled) == "function" then
            slider:SetDisabled(opts.disabled())
        else
            slider:SetDisabled(opts.disabled)
        end
    end

    slider:SetCallback("OnValueChanged", function(_, _, value)
        if opts.setFunc then
            opts.setFunc(value)
        elseif opts.dbPath then
            self:SetDBValue(opts.dbPath, value)
        end
        if opts.callback then opts.callback(value) end
    end)

    if desc then
        slider:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(desc, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        slider:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    end

    SkinSlider(slider)
    TagSearchId(slider, opts)
    parent:AddChild(slider)
    return slider
end

-- ============================================================================
-- EDITBOX
-- ============================================================================

function Controls:AddEditBox(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local box = AceGUI:Create("EditBox")
    local label = NormalizeText(opts.label, "")
    local desc = NormalizeDescription(opts.desc)
    box:SetLabel(label)
    if opts.width then box:SetWidth(opts.width) else box:SetFullWidth(true) end

    local val
    if opts.getFunc then
        val = opts.getFunc()
    elseif opts.dbPath then
        val = self:GetDBValue(opts.dbPath)
    end
    box:SetText(val or opts.default or "")

    if opts.disabled then
        if type(opts.disabled) == "function" then
            box:SetDisabled(opts.disabled())
        else
            box:SetDisabled(opts.disabled)
        end
    end

    box:SetCallback("OnEnterPressed", function(w, _, value)
        if opts.setFunc then
            opts.setFunc(value)
        elseif opts.dbPath then
            self:SetDBValue(opts.dbPath, value)
        end
        if w and w.ClearFocus then w:ClearFocus() end
        if opts.callback then opts.callback(value) end
    end)

    if desc then
        box:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(desc, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        box:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    end

    TagSearchId(box, opts)
    parent:AddChild(box)
    return box
end

-- ============================================================================
-- DROPDOWN
-- ============================================================================

function Controls:AddDropdown(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(NormalizeText(opts.label, "Select"))
    dd:SetList(NormalizeDropdownValues(opts.values))
    if opts.width then dd:SetWidth(opts.width) end

    local val
    if opts.getFunc then
        val = opts.getFunc()
    elseif opts.dbPath then
        val = self:GetDBValue(opts.dbPath)
    end
    if val then dd:SetValue(val) end

    if opts.disabled then
        if type(opts.disabled) == "function" then
            dd:SetDisabled(opts.disabled())
        else
            dd:SetDisabled(opts.disabled)
        end
    end

    dd:SetCallback("OnValueChanged", function(_, _, value)
        if opts.setFunc then
            opts.setFunc(value)
        elseif opts.dbPath then
            self:SetDBValue(opts.dbPath, value)
        end
        if opts.callback then opts.callback(value) end
    end)

    SkinDropdown(dd)
    TagSearchId(dd, opts)
    parent:AddChild(dd)
    return dd
end

-- ============================================================================
-- VISIBILITY FADE TOGGLES (Show on Hover / Show in Combat / AND-OR logic)
-- ============================================================================
-- dbPrefix must resolve to a profile subtable used by addon.VisibilityFade (core/visibility_fade.lua).

function Controls:AddVisibilityFadeToggles(parent, opts)
    local dbPrefix = opts.dbPrefix
    local callback = opts.callback

    self:AddToggle(parent, {
        label = LO["Show on Hover Only"],
        desc = opts.hoverDesc,
        dbPath = dbPrefix .. ".show_on_hover",
        callback = callback,
    })

    if opts.hideInCombat then
        -- Show in Combat / Hide in Combat are mutually exclusive — enabling one clears the other.
        self:AddToggle(parent, {
            label = LO["Show in Combat Only"],
            desc = opts.combatDesc,
            dbPath = dbPrefix .. ".show_in_combat",
            callback = function()
                local conflicted = self:GetDBValue(dbPrefix .. ".show_in_combat")
                    and self:GetDBValue(dbPrefix .. ".hide_in_combat")
                if conflicted then self:SetDBValue(dbPrefix .. ".hide_in_combat", false) end
                if callback then callback() end
                local _P = addon.OptionsPanel
                if conflicted and _P and _P.currentTab then _P:SelectTab(_P.currentTab) end
            end,
        })

        self:AddToggle(parent, {
            label = LO["Hide in Combat"],
            desc = opts.hideInCombatDesc,
            dbPath = dbPrefix .. ".hide_in_combat",
            callback = function()
                local conflicted = self:GetDBValue(dbPrefix .. ".hide_in_combat")
                    and self:GetDBValue(dbPrefix .. ".show_in_combat")
                if conflicted then self:SetDBValue(dbPrefix .. ".show_in_combat", false) end
                if callback then callback() end
                local _P = addon.OptionsPanel
                if conflicted and _P and _P.currentTab then _P:SelectTab(_P.currentTab) end
            end,
        })
    else
        self:AddToggle(parent, {
            label = LO["Show in Combat Only"],
            desc = opts.combatDesc,
            dbPath = dbPrefix .. ".show_in_combat",
            callback = callback,
        })
    end

    self:AddDropdown(parent, {
        label = LO["Hover/Combat Logic"],
        desc = LO["When both hover and combat are enabled, choose whether both are required (AND) or either condition is enough (OR)."],
        dbPath = dbPrefix .. ".visibility_logic",
        values = {
            ["and"] = LO["AND (both required)"],
            ["or"] = LO["OR (either condition)"],
        },
        callback = callback,
    })
end

-- ============================================================================
-- COLOR PICKER
-- ============================================================================

function Controls:AddColorPicker(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local cp = AceGUI:Create("ColorPicker")
    cp:SetLabel(opts.label or "Color")
    cp:SetHasAlpha(opts.hasAlpha or false)

    if opts.disabled then
        if type(opts.disabled) == "function" then
            cp:SetDisabled(opts.disabled())
        else
            cp:SetDisabled(opts.disabled)
        end
    end

    local color
    if opts.getFunc then
        color = { opts.getFunc() }
    elseif opts.dbPath then
        color = self:GetDBValue(opts.dbPath)
    end
    if color and type(color) == "table" then
        cp:SetColor(color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1)
    end

    cp:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        if opts.setFunc then
            opts.setFunc(r, g, b, a)
        elseif opts.dbPath then
            self:SetDBValue(opts.dbPath, { r = r, g = g, b = b, a = a or 1 })
        end
        if opts.callback then opts.callback(r, g, b, a) end
    end)

    TagSearchId(cp, opts)
    parent:AddChild(cp)
    return cp
end

-- ============================================================================
-- BUTTON
-- ============================================================================

function Controls:AddButton(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local btn = AceGUI:Create("Button")
    local label = NormalizeText(opts.label, "Button")
    local desc = NormalizeDescription(opts.desc)
    btn:SetText(label)
    if opts.width then btn:SetWidth(opts.width) end
    if opts.disabled then
        if type(opts.disabled) == "function" then
            btn:SetDisabled(opts.disabled())
        else
            btn:SetDisabled(opts.disabled)
        end
    end
    btn:SetCallback("OnClick", function()
        GameTooltip:Hide()
        if opts.callback then opts.callback() end
    end)
    if desc then
        btn:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(desc, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    end
    SkinButton(btn)
    TagSearchId(btn, opts)
    parent:AddChild(btn)
    return btn
end

-- ============================================================================
-- KEYBINDING
-- ============================================================================

-- Binds `opts.action`, a Bindings.xml command name, straight through the client's own binding set
-- rather than a database field, so the Key Bindings window and this control cannot disagree.
function Controls:AddKeybinding(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        RecordSearchEntry(opts)
        return MakeStub()
    end
    local kb = AceGUI:Create("Keybinding")
    local label = NormalizeText(opts.label, "Keybinding")
    local desc = NormalizeDescription(opts.desc)

    kb:SetLabel(label)
    kb:SetWidth(opts.width or 240)
    kb:SetKey(GetBindingKey(opts.action) or "")

    kb:SetCallback("OnKeyChanged", function(widget, _, key)
        -- SetBinding is protected in combat, and the widget has already painted the new key.
        if InCombatLockdown() then
            widget:SetKey(GetBindingKey(opts.action) or "")
            addon:Print(LO["Key bindings cannot be changed in combat."])
            return
        end
        for _, bound in ipairs({ GetBindingKey(opts.action) }) do
            SetBinding(bound, nil)
        end
        if key and key ~= "" then SetBinding(key, opts.action) end
        SaveBindings(GetCurrentBindingSet())
        if opts.callback then opts.callback(key) end
    end)

    if desc then
        kb:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(desc, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        kb:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    end

    -- The widget's `frame` is a container; the clickable part is `button`, so that is what is skinned.
    SkinButton({ frame = kb.button })
    TagSearchId(kb, opts)
    parent:AddChild(kb)
    return kb
end

-- ============================================================================
-- SECTION (InlineGroup)
-- ============================================================================

function Controls:AddSection(parent, title)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        local prefix = _P._currentSubTabLabel
        _P._currentSection = prefix and (prefix .. " / " .. (title or "")) or title
        return MakeStub()
    end
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(title or "")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    SkinInlineGroup(group)
    parent:AddChild(group)
    return group
end

-- ============================================================================
-- ROW (SimpleGroup)
-- ============================================================================

function Controls:AddRow(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    opts = opts or {}
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout(opts.layout or "Flow")
    parent:AddChild(group)
    return group
end

-- ============================================================================
-- TEXTURE PREVIEW (for Gryphons etc.)
-- ============================================================================

function Controls:AddTexturePreview(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    -- opts: { label, texture, texCoord, width, height }
    -- Uses AceGUI Icon widget
    local icon = AceGUI:Create("Icon")
    icon:SetImage(opts.texture, unpack(opts.texCoord or { 0, 1, 0, 1 }))
    icon:SetImageSize(opts.width or 64, opts.height or 64)
    icon:SetLabel(opts.label or "")
    if opts.fullWidth then
        icon:SetFullWidth(true)
    else
        icon:SetWidth((opts.width or 64) + 16)
    end
    -- Disable click behavior and remove hover highlight
    icon:SetCallback("OnClick", function() end)
    icon:SetCallback("OnEnter", function() end)
    icon:SetCallback("OnLeave", function() end)
    if icon.highlight then
        icon.highlight:SetTexture(nil)
    end
    if icon.frame then
        icon.frame:EnableMouse(false)
    end
    parent:AddChild(icon)
    return icon
end

-- ============================================================================
-- SUB-TAB BAR (horizontal navigation within a tab)
-- ============================================================================

function Controls:AddSubTabs(parent, tabs, activeKey, onSelect, builders)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then
        -- Harvest all sub-tabs during index build.
        if builders then
            local savedSection   = _P._currentSection
            local savedSubTab    = _P._currentSubTabLabel
            local savedSubTabKey = _P._currentSubTabKey
            for _, tab in ipairs(tabs) do
                local builder = builders[tab.key]
                if builder then
                    _P._currentSubTabLabel = tab.label
                    _P._currentSubTabKey   = tab.key
                    _P._currentSection     = nil
                    local ok, err = pcall(builder, Controls.MakeStub())
                    if not ok and addon.Debug then
                        addon:Debug("search sub-tab harvest: " .. tostring(tab.key) .. ": " .. tostring(err))
                    end
                end
            end
            _P._currentSubTabLabel = savedSubTab
            _P._currentSubTabKey   = savedSubTabKey
            _P._currentSection     = savedSection
        end
        return MakeStub()
    end
    -- tabs = { { key="player", label="Player" }, ... }
    -- activeKey = currently selected sub-tab key
    -- onSelect(key) = callback when a sub-tab is clicked
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    parent:AddChild(row)

    for _, tab in ipairs(tabs) do
        local btn = AceGUI:Create("InteractiveLabel")
        btn:SetWidth(math.max(#tab.label * 8.5, 70))

        -- Clear pooled search-row hover texture from recycled frames.
        if btn.frame._searchHover then btn.frame._searchHover:Hide() end
        btn._dragonSearchFont = nil

        local isActive = (tab.key == activeKey)
        if isActive then
            btn:SetText("|cff1784d1" .. tab.label .. "|r")
        else
            btn:SetText("|cffaaaaaa" .. tab.label .. "|r")
        end

        -- Font sizing — stored on widget for deferred re-skin pass
        local fontFlags = isActive and "OUTLINE" or ""
        btn._dragonSubTabFont = { self.Theme.font, 12, fontFlags }
        if btn.label then
            SafeSetFont(btn.label, 12, fontFlags, self.Theme.font)
        end

        btn:SetCallback("OnClick", function()
            if onSelect then onSelect(tab.key) end
        end)
        btn:SetCallback("OnEnter", function(w)
            if not isActive and w.label then
                w:SetText("|cffdddddd" .. tab.label .. "|r")
            end
        end)
        btn:SetCallback("OnLeave", function(w)
            if not isActive and w.label then
                w:SetText("|cffaaaaaa" .. tab.label .. "|r")
            end
        end)

        row:AddChild(btn)

        -- Re-apply font after AddChild (guards against AceGUI pool/layout resets)
        if btn.label then
            SafeSetFont(btn.label, 12, fontFlags, self.Theme.font)
        end
    end

    -- Separator line under the sub-tab bar
    local sep = AceGUI:Create("Heading")
    sep:SetText("")
    sep:SetFullWidth(true)
    SkinHeading(sep)
    parent:AddChild(sep)

    return row
end

-- ============================================================================
-- SPELL FILTER LIST (NotPlater-style debuff whitelist/blacklist picker)
-- Options-only: reads/writes a comma-separated spell ID string in the DB.
-- GetSpellInfo runs only when the panel is used — not on nameplate ticks.
-- ============================================================================

local spellFilterPopupContext = nil
local spellFilterExportDialog = nil
local spellFilterNameCache = nil

local function EnsureSpellFilterNameCache()
    if spellFilterNameCache then
        return spellFilterNameCache
    end
    -- Reuse the nameplate runtime's shared name->id index when available so the
    -- ~70k GetSpellInfo scan runs at most once per session across both panels.
    local NP = _G.DragonUI and _G.DragonUI.Nameplates
    if NP and NP.auras and NP.auras.GetSpellNameIndex then
        spellFilterNameCache = NP.auras.GetSpellNameIndex()
        return spellFilterNameCache
    end
    -- DragonUI_Options declares DragonUI as a required dependency, so this is
    -- only a defensive fallback for a partially loaded/broken installation.
    -- Never reintroduce a synchronous full spell-table scan here.
    spellFilterNameCache = {}
    return spellFilterNameCache
end

local function SpellFilterPrint(msg)
    if addon and addon.Print then
        addon:Print(msg)
    else
        print("|cff1784d1DragonUI:|r " .. tostring(msg))
    end
end

local function ParseSpellFilterIDs(raw)
    local ids = {}
    local seen = {}
    for token in string.gmatch(raw or "", "[^,%s]+") do
        local id = tonumber(token)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function SpellFilterIDsToCSV(ids)
    if not ids or #ids == 0 then
        return ""
    end
    local parts = {}
    for i = 1, #ids do
        parts[i] = tostring(ids[i])
    end
    return table.concat(parts, ", ")
end

local function ResolveSpellFilterToken(token)
    if not token or token == "" then
        return
    end
    token = string.gsub(token, "^%s+", "")
    token = string.gsub(token, "%s+$", "")

    local numericID = tonumber(token)
    if numericID and numericID > 0 then
        local name, _, icon = GetSpellInfo(numericID)
        if not name then
            return
        end
        return numericID, name, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local lower = string.lower(token)
    local cache = EnsureSpellFilterNameCache()
    local spellID = cache[lower]
    if spellID then
        local name, _, icon = GetSpellInfo(spellID)
        if name then
            return spellID, name, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        end
    end
end

local function EnsureSpellFilterPopup()
    if Controls._spellFilterPopupRegistered then
        return
    end
    Controls._spellFilterPopupRegistered = true

    StaticPopupDialogs["DRAGONUI_SPELL_FILTER_PROMPT"] = {
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self)
            self:SetFrameStrata("FULLSCREEN_DIALOG")
            self:Raise()
        end,
        OnAccept = function(self)
            local text = self.editBox and self.editBox:GetText() or ""
            local ctx = spellFilterPopupContext
            if ctx and ctx.onAccept then
                ctx.onAccept(text)
            end
            if self.editBox then
                self.editBox:SetText("")
            end
        end,
        OnHide = function(self)
            if self.editBox then
                self.editBox:SetText("")
            end
            spellFilterPopupContext = nil
        end,
        EditBoxOnEnterPressed = function(editBox)
            local parent = editBox:GetParent()
            if parent and parent.button1 and parent.button1.Click then
                parent.button1:Click()
            end
        end,
        EditBoxOnEscapePressed = function(editBox)
            local parent = editBox:GetParent()
            if parent then
                parent:Hide()
            end
        end,
        text = "",
    }
end

local function ShowSpellFilterPrompt(inputType, onAccept)
    EnsureSpellFilterPopup()
    spellFilterPopupContext = { onAccept = onAccept }
    local dialog = StaticPopup_Show("DRAGONUI_SPELL_FILTER_PROMPT")
    if not dialog then
        return
    end
    local prompt = (inputType == "ID") and LO["Enter a spell ID"] or LO["Enter a spell name"]
    if dialog.text then
        dialog.text:SetText(prompt)
    end
    if dialog.editBox then
        dialog.editBox:SetNumeric(inputType == "ID")
        dialog.editBox:SetAutoFocus(true)
        dialog.editBox:SetText("")
        dialog.editBox:SetFocus()
    end
end

local function EnsureSpellFilterExportDialog()
    if spellFilterExportDialog then
        return spellFilterExportDialog
    end

    local frame = CreateFrame("Frame", "DragonUISpellFilterExportDialog", UIParent)
    frame:SetSize(420, 320)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText(LO["Export/Import Spell IDs"])

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetText(LO["Paste spell IDs separated by commas."])

    -- UIPanelScrollFrameTemplate builds a $parentScrollBar child whose OnLoad
    -- concatenates the parent's name; a nil name crashes it, so name it.
    local scrollFrame = CreateFrame("ScrollFrame", "DragonUISpellFilterExportScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 52)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(360)
    editBox:SetHeight(140)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        self:Insert("\n")
    end)
    scrollFrame:SetScrollChild(editBox)

    local okButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    okButton:SetText(ACCEPT)
    okButton:SetSize(110, 22)
    okButton:SetPoint("BOTTOMLEFT", 16, 16)
    okButton:SetScript("OnClick", function()
        if frame.onImport then
            frame.onImport(editBox:GetText())
        end
        frame:Hide()
    end)

    local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelButton:SetText(CANCEL)
    cancelButton:SetSize(110, 22)
    cancelButton:SetPoint("BOTTOMRIGHT", -16, 16)
    cancelButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.editBox = editBox
    spellFilterExportDialog = frame
    frame:Hide()
    return frame
end

local function BuildSpellFilterExportText(raw)
    local ids = ParseSpellFilterIDs(raw)
    if #ids == 0 then
        return ""
    end
    local lines = {}
    for i = 1, #ids do
        lines[i] = tostring(ids[i]) .. ","
    end
    return table.concat(lines, "\n")
end

local function ImportSpellFilterText(raw, setFunc)
    local ids = ParseSpellFilterIDs(raw)
    if #ids == 0 and raw and raw:match("%d") then
        SpellFilterPrint(LO["Invalid spell name or ID"])
    end
    setFunc(SpellFilterIDsToCSV(ids))
end

function Controls:AddSpellFilterList(parent, opts)
    local _P = addon.OptionsPanel
    if _P and _P.indexing then return MakeStub() end
    opts = opts or {}
    local dbPath = opts.dbPath
    local disabledFunc = opts.disabled
    local registerDynamic = opts.registerDynamic

    local function IsDisabled()
        if type(disabledFunc) == "function" then
            return disabledFunc()
        end
        return disabledFunc == true
    end

    local function GetListRaw()
        return self:GetDBValue(dbPath) or ""
    end

    local function SetListRaw(value)
        self:SetDBValue(dbPath, value or "")
        if opts.callback then
            opts.callback(value)
        end
        if opts.rebuildUI then
            opts.rebuildUI()
        end
    end

    local function AddSpellToken(token)
        local spellID, name, icon = ResolveSpellFilterToken(token)
        if not spellID then
            SpellFilterPrint(LO["Invalid spell name or ID"])
            return
        end
        local ids = ParseSpellFilterIDs(GetListRaw())
        for i = 1, #ids do
            if ids[i] == spellID then
                SetListRaw(SpellFilterIDsToCSV(ids))
                return
            end
        end
        ids[#ids + 1] = spellID
        table.sort(ids)
        SetListRaw(SpellFilterIDsToCSV(ids))
    end

    local function RemoveSpellAtIndex(index)
        local ids = ParseSpellFilterIDs(GetListRaw())
        if ids[index] then
            table.remove(ids, index)
            SetListRaw(SpellFilterIDsToCSV(ids))
        end
    end

    local function RegisterWidget(widget)
        if registerDynamic and widget then
            return registerDynamic(widget, disabledFunc)
        end
        if widget and widget.SetDisabled then
            widget:SetDisabled(IsDisabled())
        end
        return widget
    end

    local btnRow = self:AddRow(parent, { layout = "Flow" })
    RegisterWidget(self:AddButton(btnRow, {
        label = LO["Add Debuff by Name"],
        width = 160,
        disabled = disabledFunc,
        callback = function()
            -- Populate the shared name index while the user types instead of
            -- blocking the Accept click with a full spell-table scan.
            EnsureSpellFilterNameCache()
            ShowSpellFilterPrompt("NAME", AddSpellToken)
        end,
    }))
    RegisterWidget(self:AddButton(btnRow, {
        label = LO["Add Debuff by ID"],
        width = 150,
        disabled = disabledFunc,
        callback = function()
            ShowSpellFilterPrompt("ID", AddSpellToken)
        end,
    }))
    RegisterWidget(self:AddButton(btnRow, {
        label = LO["Export/Import Spell IDs"],
        width = 170,
        disabled = disabledFunc,
        callback = function()
            local dialog = EnsureSpellFilterExportDialog()
            dialog.onImport = function(text)
                ImportSpellFilterText(text, SetListRaw)
            end
            dialog.editBox:SetText(BuildSpellFilterExportText(GetListRaw()))
            dialog.editBox:HighlightText()
            dialog:Show()
            dialog.editBox:SetFocus()
        end,
    }))

    local ids = ParseSpellFilterIDs(GetListRaw())
    if #ids == 0 then
        local empty = AceGUI:Create("Label")
        empty:SetFullWidth(true)
        empty:SetText("|cff888888" .. LO["Spell filter list is empty."] .. "|r")
        parent:AddChild(empty)
        if IsDisabled() and empty.SetDisabled then
            empty:SetDisabled(true)
        end
        return empty
    end

    local listLabel = AceGUI:Create("Label")
    listLabel:SetFullWidth(true)
    listLabel:SetText(LO["Click an entry to remove it."])
    parent:AddChild(listLabel)

    -- Long lists get their own scroll box; a curated list of 20+ would otherwise own the panel.
    local rowHost = parent
    local maxRows = opts.maxRows or 6
    if #ids > maxRows then
        local box = AceGUI:Create("SimpleGroup")
        box:SetFullWidth(true)
        box:SetLayout("Fill")
        box:SetHeight(opts.listHeight or 150)
        local scroller = AceGUI:Create("ScrollFrame")
        scroller:SetLayout("List")
        box:AddChild(scroller)
        parent:AddChild(box)
        rowHost = scroller
    end

    for index, spellID in ipairs(ids) do
        local name, _, icon = GetSpellInfo(spellID)
        name = name or LO["Unknown"]
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        local rowText = string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t %s (%d)", icon, name, spellID)

        local row = AceGUI:Create("InteractiveLabel")
        row:SetFullWidth(true)
        row:SetText(rowText)
        if row.label then
            SafeSetFont(row.label, 12, "", self.Theme.font)
        end
        row:SetCallback("OnClick", function()
            if not IsDisabled() then
                RemoveSpellAtIndex(index)
            end
        end)
        row:SetCallback("OnEnter", function(w)
            GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(string.format(LO["Spell ID: %d"], spellID), nil, nil, nil, true)
            GameTooltip:AddLine(LO["Click to remove."], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        row:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        if IsDisabled() and row.SetDisabled then
            row:SetDisabled(true)
        end
        RegisterWidget(row)
        rowHost:AddChild(row)
    end

    return listLabel
end
