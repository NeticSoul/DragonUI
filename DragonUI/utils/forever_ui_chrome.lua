-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local ForeverUI = addon.ForeverUI
local ForeverAtlas = addon.ForeverAtlas
local Layouts = ForeverUI.ChromeLayouts
local Metrics = ForeverUI.ChromeMetrics

local type, pairs, ipairs, pcall = type, pairs, ipairs, pcall
local tinsert = table.insert
local max, floor = math.max, math.floor

local ONLINE_DIVIDER = "Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider"
local PLUS_HILIGHT = "Interface\\Buttons\\UI-PlusButton-Hilight"

local Colors = ForeverUI.Colors or {}
ForeverUI.Colors = Colors
for key, value in pairs(ForeverUI.ChromeColors) do
    if Colors[key] == nil then
        Colors[key] = value
    end
end
Colors.goldHex = Colors.goldHex or "ffd100"
Colors.whiteHex = Colors.whiteHex or "ffffff"
Colors.grayHex = Colors.grayHex or "808080"

local Fonts = ForeverUI.Fonts or {}
ForeverUI.Fonts = Fonts

local function MakeFont(name, base, size)
    local font = CreateFont(name)
    font:CopyFontObject(base)
    local path, _, flags = base:GetFont()
    if path then
        font:SetFont(path, size, flags)
    end
    return font
end

Fonts.Normal = Fonts.Normal or GameFontNormal
Fonts.Highlight = Fonts.Highlight or GameFontHighlight
Fonts.Disable = Fonts.Disable or GameFontDisable
Fonts.NormalSmall = Fonts.NormalSmall or GameFontNormalSmall
Fonts.HighlightSmall = Fonts.HighlightSmall or GameFontHighlightSmall
Fonts.HighlightLarge = Fonts.HighlightLarge or GameFontHighlightLarge
Fonts.HighlightMedium = Fonts.HighlightMedium or MakeFont("DragonUIForeverChromeHighlightMedium", GameFontHighlight, 14)
Fonts.HighlightHuge = Fonts.HighlightHuge or MakeFont("DragonUIForeverChromeHighlightHuge", GameFontHighlight, 20)

local function Enabled(button)
    local state = button:IsEnabled()
    return state == 1 or state == true
end

local function AddScript(frame, script, handler)
    if frame:GetScript(script) then
        frame:HookScript(script, handler)
    else
        frame:SetScript(script, handler)
    end
end

local function Put(texture, name)
    local info = ForeverAtlas[name]
    if info then
        texture:SetTexture(info[1])
        texture:SetTexCoord(info[4], info[5], info[6], info[7])
    end
    return info
end

local function Solid(texture, color)
    texture:SetTexture(color[1], color[2], color[3], color[4] or 1)
end

local function SetColor(texture, color)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

-- Corners sit on their own anchor point, edges span the gap between corners (stretched: the strips are uniform).
function ForeverUI.ApplyNineSlice(frame, layoutName, layer)
    local layout = type(layoutName) == "table" and layoutName or Layouts[layoutName]
    layer = layer or "BORDER"
    local scale = layout.scale or 1
    local pieces = {}

    local function Corner(position, point)
        local spec = layout.corners[position]
        local texture = frame:CreateTexture(nil, layer)
        local info = Put(texture, spec[1])
        texture:SetSize(info[2] * scale, info[3] * scale)
        texture:SetPoint(point, frame, point, spec[2], spec[3])
        pieces[position] = texture
        return texture
    end

    local topLeft = Corner("TopLeft", "TOPLEFT")
    local topRight = Corner("TopRight", "TOPRIGHT")
    local bottomLeft = Corner("BottomLeft", "BOTTOMLEFT")
    local bottomRight = Corner("BottomRight", "BOTTOMRIGHT")

    local edges = layout.edges
    local top = frame:CreateTexture(nil, layer)
    top:SetHeight(Put(top, edges.Top)[3] * scale)
    top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    top:SetPoint("TOPRIGHT", topRight, "TOPLEFT", 0, 0)

    local bottom = frame:CreateTexture(nil, layer)
    bottom:SetHeight(Put(bottom, edges.Bottom)[3] * scale)
    bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", 0, 0)

    local left = frame:CreateTexture(nil, layer)
    left:SetWidth(Put(left, edges.Left)[2] * scale)
    left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT", 0, 0)

    local right = frame:CreateTexture(nil, layer)
    right:SetWidth(Put(right, edges.Right)[2] * scale)
    right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT", 0, 0)

    pieces.Top, pieces.Bottom, pieces.Left, pieces.Right = top, bottom, left, right

    if layout.center then
        local center = frame:CreateTexture(nil, layer)
        Put(center, layout.center)
        center:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT", 0, 0)
        center:SetPoint("BOTTOMRIGHT", bottomRight, "TOPLEFT", 0, 0)
        pieces.Center = center
    end

    return pieces
end

local function MakeMovable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    AddScript(frame, "OnDragStart", function(self)
        self:StartMoving()
    end)
    AddScript(frame, "OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

local function LockedDown(frame)
    return InCombatLockdown() and frame.IsProtected and frame:IsProtected()
end

-- Frames that must keep their own strata/level (popups parented to a window) opt out of EnforceLayering.
function ForeverUI.KeepLayer(frame)
    frame._fuKeepLayer = true
    return frame
end

-- Top-down pass: every descendant gets root's strata and a level above its parent's; `Back` stays at the parent's.
function ForeverUI.EnforceLayering(root)
    local strata = root:GetFrameStrata()

    local function Walk(parent)
        local level = parent:GetFrameLevel()
        for _, child in ipairs({ parent:GetChildren() }) do
            if not child._fuKeepLayer and not LockedDown(child) then
                if child:GetFrameStrata() ~= strata then
                    child:SetFrameStrata(strata)
                end
                local wanted = child == parent.Back and level or level + 1
                local current = child:GetFrameLevel()
                if (child == parent.Back and current ~= wanted) or (child ~= parent.Back and current < wanted) then
                    child:SetFrameLevel(wanted)
                end
                Walk(child)
            end
        end
    end

    Walk(root)
    return root
end

-- Fill, border and title live on a child `Back` at the frame's own level: children above it, nothing of the parent's.
local function MakeBack(frame)
    local back = CreateFrame("Frame", nil, frame)
    back:SetAllPoints(frame)
    back:SetFrameLevel(frame:GetFrameLevel())
    frame.Back = back
    return back
end

local function Chrome(frame, back, opts, defaultFont, titleY, titleSide)
    frame.TitleText = back:CreateFontString(nil, "OVERLAY")
    frame.TitleText:SetFontObject(defaultFont)
    frame.TitleText:SetHeight(20)
    frame.TitleText:SetJustifyH("CENTER")
    frame.TitleText:SetPoint("TOPLEFT", frame, "TOPLEFT", titleSide, titleY)
    frame.TitleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -titleSide, titleY)
    frame.Title = frame.TitleText
    frame.SetTitle = function(self, title)
        self.TitleText:SetText(title or "")
    end
    frame:SetTitle(opts.title)

    if opts.strata then
        frame:SetFrameStrata(opts.strata)
    end
    if opts.width and opts.height then
        frame:SetSize(opts.width, opts.height)
    end
    if opts.movable ~= false then
        MakeMovable(frame)
    end
    if opts.escClose and frame:GetName() then
        tinsert(UISpecialFrames, frame:GetName())
    end
    frame.onClose = opts.onClose
    AddScript(frame, "OnShow", ForeverUI.EnforceLayering)
end

local function AddClose(frame, opts, x, y)
    if opts.closable == false then
        return
    end
    frame.CloseButton = ForeverUI.CreateCloseButton(frame, {
        size = Metrics.window.closeSize,
        onClick = function(button)
            frame:Hide()
            if frame.onClose then
                frame.onClose(frame)
            end
        end,
    })
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", x, y)
    frame.CloseButton:SetFrameLevel(frame:GetFrameLevel() + 10)
end

local function MakeContent(frame, level, left, top, right, bottom)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
    content:SetFrameLevel(level)
    return content
end

-- Skins an existing Frame as the metal Settings window; returns it. Put your own regions on `.Content`, never on the frame.
function ForeverUI.SkinWindow(frame, opts)
    opts = opts or {}
    if frame._foreverChrome then
        return frame
    end
    frame._foreverChrome = "window"
    local M = Metrics.window
    local back = MakeBack(frame)

    local panel = Colors.panel
    local topSection = back:CreateTexture(nil, "BACKGROUND")
    local bottomEdge = back:CreateTexture(nil, "BACKGROUND")
    local bottomLeft = back:CreateTexture(nil, "BACKGROUND")
    local bottomRight = back:CreateTexture(nil, "BACKGROUND")
    local cornerInfo = Put(bottomLeft, "uiframebackground-nineslice-cornerbottomleft")
    Put(bottomRight, "uiframebackground-nineslice-cornerbottomright")
    bottomLeft:SetSize(cornerInfo[2], cornerInfo[3])
    bottomRight:SetSize(cornerInfo[2], cornerInfo[3])
    SetColor(bottomLeft, panel)
    SetColor(bottomRight, panel)
    Solid(bottomEdge, panel)
    Solid(topSection, panel)
    bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", M.bgLeft, M.bgBottom)
    bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", M.bgRight, M.bgBottom)
    bottomEdge:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT", 0, 0)
    bottomEdge:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", 0, 0)
    topSection:SetPoint("TOPLEFT", frame, "TOPLEFT", M.bgLeft, M.bgTop)
    topSection:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT", 0, 0)
    frame.Bg = topSection

    frame.BorderPieces = ForeverUI.ApplyNineSlice(back, "metalframe", "BORDER")

    Chrome(frame, back, opts, Fonts.Normal, M.titleY, M.titleSide)
    AddClose(frame, opts, M.closeX, M.closeY)

    local level = frame:GetFrameLevel() + 1
    if opts.inset then
        frame.Inset = ForeverUI.CreateInnerFrame(frame)
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", M.insetLeft, M.insetTop)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", M.insetRight, M.insetBottom)
        frame.Inset:SetFrameLevel(level)
        frame.Content = frame.Inset
    else
        frame.Content = MakeContent(frame, level, M.plainLeft, M.plainTop, M.plainRight, M.plainBottom)
    end
    ForeverUI.EnforceLayering(frame)
    return frame
end

-- opts: width, height, title, strata, closable (default true), onClose, movable (default true), inset, escClose.
function ForeverUI.CreateWindow(name, parent, opts)
    local frame = CreateFrame("Frame", name, parent or UIParent)
    ForeverUI.SkinWindow(frame, opts)
    frame:Hide()
    return frame
end

-- Skins an existing Frame with the translucent diamond-metal dialog border; opts.solid paints it opaque.
function ForeverUI.SkinDialog(frame, opts)
    opts = opts or {}
    if frame._foreverChrome then
        return frame
    end
    frame._foreverChrome = "dialog"
    local M = Metrics.dialog
    local back = MakeBack(frame)

    local bg = back:CreateTexture(nil, "BACKGROUND")
    Solid(bg, opts.solid and Colors.dialogSolid or Colors.dialog)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", M.bgInset, -M.bgInset)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -M.bgInset, M.bgInset)
    frame.Bg = bg

    frame.BorderPieces = ForeverUI.ApplyNineSlice(back, "diamond", "BORDER")
    frame:EnableMouse(true)

    Chrome(frame, back, opts, Fonts.HighlightLarge, M.titleY, 24)
    AddClose(frame, opts, M.closeX, M.closeY)

    frame.Content = MakeContent(frame, frame:GetFrameLevel() + 1, M.contentLeft, M.contentTop, M.contentRight,
        M.contentBottom)
    ForeverUI.EnforceLayering(frame)
    return frame
end

-- opts: width, height, title, strata, closable (default false), onClose, movable (default true), solid, escClose.
function ForeverUI.CreateDialog(name, parent, opts)
    opts = opts or {}
    if opts.closable == nil then
        opts.closable = false
    end
    local frame = CreateFrame("Frame", name, parent or UIParent)
    ForeverUI.SkinDialog(frame, opts)
    frame:Hide()
    return frame
end

-- Retail's ThreeSliceButtonMixin:UpdateScale: slices scale to the button height and are trimmed when too wide.
local function LayoutThreeSlice(button)
    local width, height = button:GetWidth(), button:GetHeight()
    if not (width and height) or width <= 0 or height <= 0 then
        return
    end
    local scale = height / Metrics.button.sliceHeight
    local leftWidth = ForeverAtlas["128-redbutton-left"][2] * scale
    local rightWidth = ForeverAtlas["128-redbutton-right"][2] * scale
    local leftFraction, rightFraction = 1, 1

    if leftWidth + rightWidth > width then
        local extra = leftWidth + rightWidth - width
        local newLeft, newRight = leftWidth, rightWidth
        if leftWidth - extra > rightWidth then
            newLeft = leftWidth - extra
        elseif rightWidth - extra > leftWidth then
            newRight = rightWidth - extra
        else
            if leftWidth ~= rightWidth then
                extra = extra - math.abs(leftWidth - rightWidth)
                newLeft = math.min(leftWidth, rightWidth)
                newRight = newLeft
            end
            newLeft = newLeft - extra / 2
            newRight = newRight - extra / 2
        end
        leftFraction, rightFraction = newLeft / leftWidth, newRight / rightWidth
        leftWidth, rightWidth = newLeft, newRight
    end

    button._fuLeftFraction, button._fuRightFraction = leftFraction, rightFraction
    button._fuLeft:SetSize(leftWidth, height)
    button._fuRight:SetSize(rightWidth, height)
end

local STATE_SUFFIX = { normal = "", pressed = "-pressed", disabled = "-disabled" }

local function ApplyButtonState(button)
    local state = "normal"
    if not Enabled(button) then
        state = "disabled"
    elseif button._fuPushed then
        state = "pressed"
    end
    local suffix = STATE_SUFFIX[state]
    local left = ForeverAtlas["128-redbutton-left" .. suffix]
    local right = ForeverAtlas["128-redbutton-right" .. suffix]
    local center = ForeverAtlas["_128-redbutton-center" .. suffix]
    local leftFraction, rightFraction = button._fuLeftFraction or 1, button._fuRightFraction or 1
    button._fuLeft:SetTexCoord(left[4], left[4] + (left[5] - left[4]) * leftFraction, left[6], left[7])
    button._fuRight:SetTexCoord(right[5] - (right[5] - right[4]) * rightFraction, right[5], right[6], right[7])
    button._fuCenter:SetTexCoord(center[4], center[5], center[6], center[7])
end

local function RefreshButton(button)
    LayoutThreeSlice(button)
    ApplyButtonState(button)
end

local function HideNativeArt(button)
    local name = button:GetName()
    for _, part in ipairs({ "Left", "Middle", "Right" }) do
        local region = button[part]
        if region and region ~= button._fuLeft and region.Hide then
            region:Hide()
        end
        region = name and _G[name .. part]
        if region and region.Hide then
            region:Hide()
        end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local texture = button[getter](button)
        if texture then
            texture:SetTexture(nil)
        end
    end
end

-- Replaces a Button's art with the c60 red three-slice; safe to call on UIPanelButtonTemplate-style buttons.
function ForeverUI.SkinButton(button)
    if button._fuSkinned then
        return button
    end
    button._fuSkinned = true
    HideNativeArt(button)

    local sheet = ForeverAtlas["128-redbutton-left"][1]
    button._fuLeft = button:CreateTexture(nil, "BACKGROUND")
    button._fuRight = button:CreateTexture(nil, "BACKGROUND")
    button._fuCenter = button:CreateTexture(nil, "BACKGROUND")
    button._fuLeft:SetTexture(sheet)
    button._fuRight:SetTexture(sheet)
    button._fuCenter:SetTexture(sheet)
    button._fuLeft:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button._fuRight:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button._fuCenter:SetPoint("TOPLEFT", button._fuLeft, "TOPRIGHT", 0, 0)
    button._fuCenter:SetPoint("BOTTOMRIGHT", button._fuRight, "BOTTOMLEFT", 0, 0)

    local highlight = ForeverAtlas["128-redbutton-highlight"]
    button:SetHighlightTexture(highlight[1], "ADD")
    local texture = button:GetHighlightTexture()
    texture:SetTexCoord(highlight[4], highlight[5], highlight[6], highlight[7])
    texture:ClearAllPoints()
    texture:SetAllPoints(button)

    if not button:GetFontString() then
        local text = button:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER", button, "CENTER", 0, 0)
        button:SetFontString(text)
    end
    button:SetNormalFontObject(Fonts.Normal)
    button:SetHighlightFontObject(Fonts.Highlight)
    button:SetDisabledFontObject(Fonts.Disable)
    button:SetPushedTextOffset(Metrics.button.pushedX, Metrics.button.pushedY)

    AddScript(button, "OnMouseDown", function(self)
        self._fuPushed = true
        ApplyButtonState(self)
    end)
    AddScript(button, "OnMouseUp", function(self)
        self._fuPushed = nil
        ApplyButtonState(self)
    end)
    AddScript(button, "OnShow", function(self)
        self._fuPushed = nil
        RefreshButton(self)
    end)
    AddScript(button, "OnEnable", ApplyButtonState)
    AddScript(button, "OnDisable", ApplyButtonState)
    hooksecurefunc(button, "Enable", ApplyButtonState)
    hooksecurefunc(button, "Disable", ApplyButtonState)
    AddScript(button, "OnSizeChanged", RefreshButton)

    RefreshButton(button)
    return button
end

function ForeverUI.CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or Metrics.button.defaultWidth, height or Metrics.button.defaultHeight)
    ForeverUI.SkinButton(button)
    if text then
        button:SetText(text)
    end
    return button
end

-- opts: size (default 24), large (128-RedButton-Exit art), onClick (default hides the parent).
function ForeverUI.CreateCloseButton(parent, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent)
    local size = opts.size or Metrics.window.closeSize
    button:SetSize(size, size)
    local prefix = opts.large and "128-redbutton-exit" or "redbutton-exit"

    local function Skin(setter, getter, name)
        local info = ForeverAtlas[name]
        button[setter](button, info[1])
        local texture = button[getter](button)
        texture:SetTexCoord(info[4], info[5], info[6], info[7])
    end
    Skin("SetNormalTexture", "GetNormalTexture", prefix)
    Skin("SetPushedTexture", "GetPushedTexture", prefix .. "-pressed")
    Skin("SetDisabledTexture", "GetDisabledTexture", prefix .. "-disabled")

    local highlight = ForeverAtlas["redbutton-highlight"]
    button:SetHighlightTexture(highlight[1], "ADD")
    button:GetHighlightTexture():SetTexCoord(highlight[4], highlight[5], highlight[6], highlight[7])

    button:SetScript("OnClick", function(self)
        PlaySound("igMainMenuClose")
        if opts.onClick then
            opts.onClick(self)
        elseif self:GetParent() then
            self:GetParent():Hide()
        end
    end)
    return button
end

-- 886x618 art sliced 212/40/88/168; give it two anchors, the minimum useful size is 252x256.
function ForeverUI.CreateInnerFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.BorderPieces = ForeverUI.ApplyNineSlice(frame, "innerframe", "BACKGROUND")
    return frame
end

-- Boxed border (OptionsFrame art) around `target`; the offsets place the 1 px rail exactly where they did before the rail fix.
function ForeverUI.CreateSectionBorder(parent, target, left, top, right, bottom)
    local M = Metrics.optionsbox
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", target, "TOPLEFT", (left or M.defaultLeft) + M.railInsetX, (top or M.defaultTop) - M.railInsetY)
    frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", (right or M.defaultRight) - M.railInsetX,
        (bottom or M.defaultBottom) + M.railInsetY)
    frame.BorderPieces = ForeverUI.ApplyNineSlice(frame, "optionsbox", "BORDER")
    return frame
end

-- Child frame whose rail coincides with `frame`'s rect; `fill` (r,g,b,a) paints under the rail, inset so it never pokes out.
function ForeverUI.AttachBoxBorder(frame, fill)
    local M = Metrics.optionsbox
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    border.BorderPieces = ForeverUI.ApplyNineSlice(border, "optionsbox", "BORDER")
    if fill then
        border.Fill = border:CreateTexture(nil, "BACKGROUND")
        Solid(border.Fill, fill)
        border.Fill:SetPoint("TOPLEFT", border, "TOPLEFT", M.fillInset, -M.fillInset)
        border.Fill:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -M.fillInset, M.fillInset)
    end
    frame.BoxBorder = border
    return border
end

-- Dark banner behind a group name in the category list; index 1..3 picks the art (wraps).
function ForeverUI.CreateCategoryHeader(parent)
    local M = Metrics.category
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(M.headerWidth, M.headerHeight)
    header.Background = header:CreateTexture(nil, "ARTWORK")
    header.Background:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    header.Label = header:CreateFontString(nil, "OVERLAY")
    header.Label:SetFontObject(Fonts.HighlightMedium)
    header.Label:SetJustifyH("LEFT")
    header.Label:SetPoint("LEFT", header, "LEFT", M.headerLabelX, M.headerLabelY)
    header.Label:SetPoint("RIGHT", header, "RIGHT", -8, M.headerLabelY)

    function header:SetIndex(index)
        local name = "options_categoryheader_" .. (((index or 1) - 1) % 3 + 1)
        local info = Put(self.Background, name)
        self.Background:SetSize(info[2], info[3])
    end
    function header:SetLabel(text)
        self.Label:SetText(text or "")
    end
    header:SetIndex(1)
    return header
end

local function UpdateCategoryButton(button)
    local art
    if button._fuSelected then
        art = "options_list_active"
    elseif button._fuOver then
        art = "options_list_hover"
    end
    if art then
        local info = Put(button.Texture, art)
        button.Texture:SetSize(info[2], info[3])
        button.Texture:Show()
    else
        button.Texture:Hide()
    end
    if button._fuSelected or button._fuIndent > 0 then
        button.Label:SetFontObject(Fonts.Highlight)
    else
        button.Label:SetFontObject(Fonts.Normal)
    end
end

local function UpdateToggle(toggle)
    local expanded = toggle._fuExpanded
    local normal = ForeverAtlas[expanded and "common-button-dropdown-open" or "common-button-dropdown-closed"]
    local pushed = ForeverAtlas[expanded and "common-button-dropdown-openpressed" or "common-button-dropdown-closedpressed"]
    toggle:SetNormalTexture(normal[1])
    toggle:GetNormalTexture():SetTexCoord(normal[4], normal[5], normal[6], normal[7])
    toggle:SetPushedTexture(pushed[1])
    toggle:GetPushedTexture():SetTexCoord(pushed[4], pushed[5], pushed[6], pushed[7])
end

-- Category list row: SetText, SetSelected, SetIndent (sub-category), SetExpandable/SetExpanded (+/- toggle).
function ForeverUI.CreateCategoryButton(parent)
    local M = Metrics.category
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(M.rowWidth, M.rowHeight)
    button._fuIndent = 0
    button._fuLabelLeft = M.labelLeft

    button.Texture = button:CreateTexture(nil, "BACKGROUND")
    button.Texture:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.Texture:Hide()

    button.Label = button:CreateFontString(nil, "ARTWORK")
    button.Label:SetFontObject(Fonts.Normal)
    button.Label:SetJustifyH("LEFT")
    button.Label:SetPoint("TOPLEFT", button, "TOPLEFT", M.labelLeft, M.labelY)
    button.Label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, M.labelY)

    function button:SetText(text)
        self.Label:SetText(text or "")
    end
    function button:GetText()
        return self.Label:GetText()
    end
    function button:SetSelected(selected)
        self._fuSelected = selected and true or nil
        UpdateCategoryButton(self)
    end
    function button:IsSelected()
        return self._fuSelected and true or false
    end
    function button:SetIndent(indent)
        self._fuIndent = indent or 0
        self.Label:SetPoint("TOPLEFT", self, "TOPLEFT", self._fuLabelLeft + self._fuIndent, M.labelY)
        UpdateCategoryButton(self)
    end
    -- Rows with no +/- toggle can pull their text in from the toggle's room (default Metrics.category.labelLeft).
    function button:SetLabelLeft(left)
        self._fuLabelLeft = left
        self.Label:SetPoint("TOPLEFT", self, "TOPLEFT", left + self._fuIndent, M.labelY)
    end
    function button:SetExpandable(expandable, expanded, onToggle)
        if not self.Toggle then
            local toggle = CreateFrame("Button", nil, self)
            toggle:SetSize(M.toggleSize, M.toggleSize)
            toggle:SetHighlightTexture(PLUS_HILIGHT, "ADD")
            toggle:SetScript("OnClick", function(control)
                control._fuExpanded = not control._fuExpanded
                UpdateToggle(control)
                if control.onToggle then
                    control.onToggle(self, control._fuExpanded)
                end
            end)
            self.Toggle = toggle
        end
        local toggle = self.Toggle
        toggle:ClearAllPoints()
        toggle:SetPoint("LEFT", self, "LEFT", M.toggleX + self._fuIndent, 0)
        toggle.onToggle = onToggle or toggle.onToggle
        toggle._fuExpanded = expanded and true or false
        UpdateToggle(toggle)
        if expandable then
            toggle:Show()
        else
            toggle:Hide()
        end
    end
    function button:SetExpanded(expanded)
        if self.Toggle then
            self.Toggle._fuExpanded = expanded and true or false
            UpdateToggle(self.Toggle)
        end
    end

    button:SetScript("OnEnter", function(self)
        self._fuOver = true
        UpdateCategoryButton(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._fuOver = nil
        UpdateCategoryButton(self)
    end)
    UpdateCategoryButton(button)
    return button
end

-- Texture only: anchor two points to stretch it. kind "ornate" is the Edit Mode dialog's 330x16 flourish.
function ForeverUI.CreateDivider(parent, kind)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    if kind == "ornate" then
        texture:SetTexture(ONLINE_DIVIDER)
        texture:SetSize(Metrics.divider.ornateWidth, Metrics.divider.ornateHeight)
    else
        local info = Put(texture, "options_horizontaldivider")
        texture:SetSize(info[2], info[3])
    end
    return texture
end

local function UpdateTab(tab)
    local active = tab._fuSelected
    local prefix = active and "options_tab_active_" or "options_tab_"
    local left = Put(tab.Left, prefix .. "left")
    local right = Put(tab.Right, prefix .. "right")
    Put(tab.Middle, prefix .. "middle")
    tab.Left:SetSize(left[2], left[3])
    tab.Right:SetSize(right[2], right[3])
    tab.Text:ClearAllPoints()
    tab.Text:SetPoint("BOTTOM", tab, "BOTTOM", 0, active and Metrics.tab.textYSelected or Metrics.tab.textY)
    if active or tab._fuOver then
        tab.Text:SetFontObject(Fonts.HighlightSmall)
    else
        tab.Text:SetFontObject(Fonts.NormalSmall)
    end
end

-- Minimal tab: SetTabText sizes it to the text, SetSelected swaps to the active art.
function ForeverUI.CreateTab(parent)
    local M = Metrics.tab
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(100, M.height)

    tab.Left = tab:CreateTexture(nil, "ARTWORK")
    tab.Right = tab:CreateTexture(nil, "ARTWORK")
    tab.Middle = tab:CreateTexture(nil, "ARTWORK")
    tab.Left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    tab.Right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
    tab.Middle:SetPoint("TOPLEFT", tab.Left, "TOPRIGHT", 0, 0)
    tab.Middle:SetPoint("BOTTOMRIGHT", tab.Right, "BOTTOMLEFT", 0, 0)
    tab.Text = tab:CreateFontString(nil, "OVERLAY")

    function tab:SetTabText(text)
        self.Text:SetText(text or "")
        self:SetWidth(max(floor(self.Text:GetStringWidth() + M.textPad + 0.5), 20))
    end
    function tab:SetSelected(selected)
        self._fuSelected = selected and true or nil
        UpdateTab(self)
    end
    function tab:IsSelected()
        return self._fuSelected and true or false
    end

    tab:SetScript("OnEnter", function(self)
        self._fuOver = true
        UpdateTab(self)
    end)
    tab:SetScript("OnLeave", function(self)
        self._fuOver = nil
        UpdateTab(self)
    end)
    UpdateTab(tab)
    return tab
end
