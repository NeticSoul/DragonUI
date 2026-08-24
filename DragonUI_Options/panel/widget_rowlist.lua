-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local Type, Version = "DragonUIRowList", 1
if (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs, floor, max = pairs, math.floor, math.max
local CreateFrame, GameTooltip, UIParent = CreateFrame, GameTooltip, UIParent
local FauxScrollFrame_Update, FauxScrollFrame_OnVerticalScroll =
    FauxScrollFrame_Update, FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_GetOffset, FauxScrollFrame_SetOffset =
    FauxScrollFrame_GetOffset, FauxScrollFrame_SetOffset

local ROW_HEIGHT, BAR_WIDTH = 18, 22
local listCount = 0

local function Update(self)
    local rows, items, labels = self.rows, self.items, self.labels
    FauxScrollFrame_Update(self.scroll, #items, self.numRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.scroll) or 0

    for i = 1, self.numRows do
        local row, index = rows[i], offset + i
        row.item, row.index = items[index], index
        if row.item then
            row.text:SetText(labels[index])
            row:Show()
        else
            row:Hide()
        end
    end
end

local function Row_OnEnter(row)
    local self = row.obj
    if row.item and self.tooltip then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        self.tooltip(row.item)
        GameTooltip:Show()
    end
end

local function Row_OnLeave()
    GameTooltip:Hide()
end

local function Row_OnClick(row)
    local self = row.obj
    if row.item and self.click and not self.disabled then
        self.click(row.index, row.item)
    end
end

local function OnMouseWheel(frame, delta)
    local bar = frame.obj.bar
    if bar:IsShown() then
        bar:SetValue(bar:GetValue() - delta * ROW_HEIGHT)
    end
end

local function UpdateFromScroll(scroll)
    Update(scroll.obj)
end

local function OnVerticalScroll(scroll, offset)
    FauxScrollFrame_OnVerticalScroll(scroll, offset, ROW_HEIGHT, UpdateFromScroll)
end

-- A custom font path can fail to load, and a FontString left without a font renders nothing.
local function ApplyFont(row, font)
    if font and row.text:SetFont(font[1], font[2], font[3]) then return end
    row.text:SetFontObject("GameFontHighlightSmall")
end

local function Rewind(self)
    FauxScrollFrame_SetOffset(self.scroll, 0)
    self.bar:SetValue(0)
end

local methods = {
    ["OnAcquire"] = function(self)
        self.font = nil
        self.tooltip, self.click = nil, nil
        self:SetWidth(200)
        self:SetHeight(ROW_HEIGHT * 6)
        self:SetDisabled(false)
    end,

    ["OnRelease"] = function(self)
        for i = 1, #self.items do
            self.items[i], self.labels[i] = nil, nil
        end
        self.tooltip, self.click = nil, nil
        Rewind(self)
        Update(self)
    end,

    -- handlers: format(item) -> string, tooltip(item) fills an owned GameTooltip, click(index, item)
    ["SetList"] = function(self, items, handlers)
        handlers = handlers or {}
        local own, labels, format = self.items, self.labels, handlers.format
        local count = items and #items or 0

        -- Labels are built once here so scrolling never re-runs the caller's formatter.
        for i = 1, max(count, #own) do
            local item = items and items[i]
            own[i] = item
            labels[i] = item ~= nil and format and format(item) or nil
        end

        self.tooltip, self.click = handlers.tooltip, handlers.click
        Rewind(self)
        Update(self)
    end,

    ["SetRowFont"] = function(self, path, size, flags)
        self.font = { path, size, flags }
        for i = 1, #self.rows do
            ApplyFont(self.rows[i], self.font)
        end
    end,

    ["SetDisabled"] = function(self, disabled)
        disabled = disabled and true or false
        self.disabled = disabled
        local tint = disabled and 0.5 or 1
        for i = 1, #self.rows do
            self.rows[i]:EnableMouse(not disabled)
            self.rows[i].text:SetTextColor(tint, tint, tint)
        end
    end,

    ["OnHeightSet"] = function(self, height)
        local wanted = max(1, floor((height or 0) / ROW_HEIGHT))
        if wanted == self.numRows then return end

        local rows, frame = self.rows, self.frame
        for i = #rows + 1, wanted do
            local row = CreateFrame("Button", nil, frame)
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", frame, "RIGHT", -BAR_WIDTH, 0)
            row:SetScript("OnEnter", Row_OnEnter)
            row:SetScript("OnLeave", Row_OnLeave)
            row:SetScript("OnClick", Row_OnClick)
            row:EnableMouse(not self.disabled)

            local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            text:SetPoint("LEFT", 2, 0)
            text:SetPoint("RIGHT", -2, 0)
            text:SetJustifyH("LEFT")
            row.text, row.obj = text, self

            ApplyFont(row, self.font)
            local tint = self.disabled and 0.5 or 1
            text:SetTextColor(tint, tint, tint)
            rows[i] = row
        end

        for i = wanted + 1, #rows do
            rows[i]:Hide()
        end
        self.numRows = wanted
        Update(self)
    end,
}

local function Constructor()
    listCount = listCount + 1
    local name = "DragonUIRowListScroll" .. listCount

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", OnMouseWheel)

    -- FauxScrollFrame_Update resolves its scrollbar through _G, so this frame has to be named.
    local scroll = CreateFrame("ScrollFrame", name, frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -BAR_WIDTH, 0)
    scroll:SetScript("OnVerticalScroll", OnVerticalScroll)

    local widget = {
        frame = frame,
        scroll = scroll,
        bar = _G[name .. "ScrollBar"],
        rows = {},
        items = {},
        labels = {},
        numRows = 0,
        disabled = false,
        type = Type,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end
    frame.obj, scroll.obj = widget, widget

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
