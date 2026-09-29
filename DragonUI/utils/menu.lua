-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Not UIDropDownMenu: UIDROPDOWNMENU_OPEN_MENU never clears and blocks the map blobs in combat.

local DIVIDER_H = 9
local INSET_X, INSET_Y = 12, 10
local CHECK_W = 16
local ARROW_W = 16
local ICON_W = 16
local DETAIL_GAP = 16
-- UIDropDownMenu's own idle timeout.
local HIDE_DELAY = 2

-- The large look is asked for per Open; it has no idle timeout and closes on outside presses.
local STYLES = {
    small = {
        row = 16, minW = 100, iconGap = 4, title = "GameFontNormalSmallLeft",
        text = "GameFontHighlightSmallLeft", disabled = "GameFontDisableSmallLeft",
    },
    large = {
        row = 21, minW = 60, iconGap = 10, title = "GameFontNormal",
        text = "GameFontHighlight", disabled = "GameFontDisable", dark = true,
    },
}

local menu
local levels = {}

local function readPoints(frame, skip)
    local points = {}
    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        -- A nil relativeTo means the parent, which during a loan is the row itself.
        if not skip or (relativeTo and relativeTo ~= skip) then
            points[#points + 1] = { point, relativeTo, relativePoint, x, y }
        end
    end
    return points
end

-- Anchors go back too (other addons hang widgets off it); ones its owner set during the loan win.
local function releaseOverlays()
    -- A lent frame may be protected; its records wait for the end of combat rather than half-return.
    if InCombatLockdown() then return end
    for index = #menu.lent, 1, -1 do
        local lent = menu.lent[index]
        menu.lent[index] = nil
        lent.button:UnlockHighlight()
        local frame = lent.frame
        local rewritten = readPoints(frame, lent.button)
        frame:SetParent(lent.parent)
        frame:SetFrameStrata(lent.strata)
        frame:SetFrameLevel(lent.level)
        frame:SetHitRectInsets(lent.insets[1], lent.insets[2], lent.insets[3], lent.insets[4])
        frame:SetAlpha(lent.alpha)
        frame:ClearAllPoints()
        for _, p in ipairs(#rewritten > 0 and rewritten or lent.points) do
            frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    end
end

-- A real click on that frame runs its own handler as its owner's code, not as ours.
local function lendOverlay(frame, button)
    if InCombatLockdown() then return end
    menu.lent[#menu.lent + 1] = {
        frame = frame, button = button, parent = frame:GetParent(), strata = frame:GetFrameStrata(),
        level = frame:GetFrameLevel(), insets = { frame:GetHitRectInsets() }, alpha = frame:GetAlpha(),
        points = readPoints(frame),
    }
    frame:SetParent(button)
    frame:SetFrameStrata(menu:GetFrameStrata())
    frame:SetFrameLevel(button:GetFrameLevel() + 1)
    frame:ClearAllPoints()
    frame:SetAllPoints(button)
    frame:SetHitRectInsets(0, 0, 0, 0)
    frame:SetAlpha(0)
    frame:Show()
end

local function closeFrom(depth)
    for d = #levels, depth, -1 do
        if levels[d]:IsShown() then levels[d]:Hide() end
    end
end

local acquire

local function paintBackdrop(level, style)
    if style.dark then
        level:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        level:SetBackdropBorderColor(0.5, 0.5, 0.5)
        return
    end
    level:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
    level:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
end

local function refresh(level)
    if level == menu then releaseOverlays() end
    local style = menu.style
    paintBackdrop(level, style)
    local checkable, width = false, style.minW
    for _, entry in ipairs(level.entries) do
        if entry.checked ~= nil then checkable = true end
        if entry.tooltip then menu.tips = true end
    end
    local indent = checkable and CHECK_W + 2 or 2
    local y = INSET_Y
    for index, entry in ipairs(level.entries) do
        local button = level.buttons[index] or acquire(level, index)
        button.entry = entry
        local divider = entry.isDivider
        button:SetHeight(divider and DIVIDER_H or style.row)
        if divider then button.divider:Show() else button.divider:Hide() end
        local font = entry.isTitle and style.title or entry.disabled and style.disabled or style.text
        button.text:SetFontObject(font)
        button.text:SetJustifyH("LEFT")
        button.text:SetText(not divider and entry.text or "")
        local shift = entry.indent or 0
        local textLeft = (entry.isTitle and 2 or indent) + shift
        local pictured = entry.icon ~= nil and not divider
        local reach = indent + shift
        if pictured then
            button.icon:SetTexture(entry.icon)
            button.icon:SetPoint("LEFT", button, "LEFT", textLeft, 0)
            button.icon:Show()
            textLeft = textLeft + ICON_W + style.iconGap
            reach = textLeft
        else
            button.icon:Hide()
        end
        button.text:SetPoint("LEFT", button, "LEFT", textLeft, 0)
        button.detail:SetText(not divider and entry.detail or "")
        button.detail:ClearAllPoints()
        button.detail:SetPoint("RIGHT", button, "RIGHT", entry.menu and -ARROW_W or 0, 0)
        button.text:SetPoint("RIGHT", entry.detail and button.detail or button, entry.detail and "LEFT" or "RIGHT",
            entry.detail and -DETAIL_GAP or 0, 0)
        local checked = entry.checked
        if type(checked) == "function" then checked = checked() end
        button.check:SetPoint("LEFT", button, "LEFT", shift, 0)
        if checked then button.check:Show() else button.check:Hide() end
        if entry.menu then button.arrow:Show() else button.arrow:Hide() end
        button:EnableMouse(not (entry.isTitle or entry.disabled or divider))
        button:UnlockHighlight()
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", level, "TOPLEFT", INSET_X, -y)
        button:SetPoint("RIGHT", level, "RIGHT", -INSET_X, 0)
        button:Show()
        if entry.overlay and level == menu then lendOverlay(entry.overlay, button) end
        if not divider then
            local w = button.text:GetStringWidth() + reach + 8 + (entry.menu and ARROW_W or 0)
            if entry.detail then w = w + DETAIL_GAP + button.detail:GetStringWidth() end
            width = math.max(width, w)
        end
        y = y + (divider and DIVIDER_H or style.row)
    end
    for index = #level.entries + 1, #level.buttons do level.buttons[index]:Hide() end
    level:SetSize(width + INSET_X * 2, y + INSET_Y)
end

-- Opens to the right of its row, or to the left when the screen edge is in the way.
local function placeChild(child, button)
    child:ClearAllPoints()
    local right, edge = button:GetRight(), UIParent:GetRight()
    if right and edge and right + INSET_X + child:GetWidth() > edge then
        child:SetPoint("TOPRIGHT", button, "TOPLEFT", -INSET_X, INSET_Y)
    else
        child:SetPoint("TOPLEFT", button, "TOPRIGHT", INSET_X, INSET_Y)
    end
end

local function refreshAll()
    for _, level in ipairs(levels) do
        if level:IsShown() then refresh(level) end
    end
    for depth = 2, #levels do
        local child = levels[depth]
        if child:IsShown() and child.parentButton then child.parentButton:LockHighlight() end
    end
end

local newLevel

local function openChild(level, button)
    local child = levels[level.depth + 1] or newLevel(level.depth + 1)
    if child:IsShown() and child.parentButton == button then return end
    closeFrom(level.depth + 1)
    child.entries = button.entry.menu()
    child.parentButton = button
    child:SetFrameLevel(level:GetFrameLevel() + 10)
    refresh(child)
    placeChild(child, button)
    child:Show()
    button:LockHighlight()
end

acquire = function(level, index)
    local button = CreateFrame("Button", nil, level)
    button:SetHeight(menu.style.row)
    button.level = level
    local highlight = button:CreateTexture(nil, "BACKGROUND")
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)
    button:SetHighlightTexture(highlight)
    button.check = button:CreateTexture(nil, "ARTWORK")
    button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button.check:SetSize(CHECK_W, CHECK_W)
    button.check:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_W, ICON_W)
    button.icon:Hide()
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmallLeft")
    button.text:SetJustifyH("LEFT")
    button.detail = button:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    button.detail:SetJustifyH("RIGHT")
    button.arrow = button:CreateTexture(nil, "ARTWORK")
    button.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    button.arrow:SetSize(ARROW_W, ARROW_W)
    button.arrow:SetPoint("RIGHT", button, "RIGHT", 0, 0)
    button.divider = button:CreateTexture(nil, "ARTWORK")
    button.divider:SetTexture(1, 1, 1, 0.14)
    button.divider:SetHeight(1)
    button.divider:SetPoint("LEFT", button, "LEFT", 2, 0)
    button.divider:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    button.divider:Hide()
    button:SetScript("OnEnter", function(self)
        if self.entry.menu then openChild(self.level, self) else closeFrom(self.level.depth + 1) end
    end)
    button:SetScript("OnClick", function(self)
        PlaySound("igMainMenuOptionCheckBoxOn")
        if self.entry.menu then
            openChild(self.level, self)
            return
        end
        if self.entry.func then self.entry.func() end
        if self.entry.keepShown and menu:IsShown() then
            refreshAll()
        else
            menu:Hide()
        end
    end)
    level.buttons[index] = button
    return button
end

local function anchorVisible(anchor)
    return type(anchor) ~= "table" or anchor:IsVisible()
end

local function overAnyLevel()
    for _, level in ipairs(levels) do
        if level:IsShown() and level:IsMouseOver() then return true end
    end
    return false
end

local function tipRowUnderMouse()
    for _, level in ipairs(levels) do
        if level:IsShown() then
            for _, button in ipairs(level.buttons) do
                if button:IsShown() and button.entry and button.entry.tooltip and button:IsMouseOver() then
                    return button
                end
            end
        end
    end
end

-- Polled rather than OnEnter: a lent overlay covers its row and takes the row's mouse events.
local function syncTip()
    local row = tipRowUnderMouse()
    if row == menu.tipRow then return end
    if menu.tipRow and GameTooltip:IsOwned(menu.tipRow) then GameTooltip:Hide() end
    menu.tipRow = row
    if not row then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    row.entry.tooltip(GameTooltip, row.entry)
    GameTooltip:Show()
end

-- Only a press that starts outside counts, so dragging out of a row keeps the menu.
local function pressedOutside()
    local down = IsMouseButtonDown() and true or false
    local fresh = down and not menu.wasDown
    menu.wasDown = down
    if not fresh or overAnyLevel() then return false end
    return not (type(menu.anchor) == "table" and menu.anchor:IsMouseOver())
end

newLevel = function(depth)
    local level = CreateFrame("Frame", depth == 1 and "DragonUIMenu" or ("DragonUIMenu" .. depth), UIParent)
    level.depth, level.buttons, level.entries = depth, {}, {}
    level:SetFrameStrata("TOOLTIP")
    level:SetClampedToScreen(true)
    level:EnableMouse(true)
    level:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    paintBackdrop(level, STYLES.small)
    level:Hide()
    if depth > 1 then
        level:SetScript("OnHide", function(self)
            if self.parentButton then self.parentButton:UnlockHighlight() end
            self.parentButton = nil
            closeFrom(self.depth + 1)
        end)
    end
    levels[depth] = level
    return level
end

local function build()
    menu = newLevel(1)
    menu.place = function()
        menu:ClearAllPoints()
        local anchor = menu.anchor
        if anchor == "cursor" then
            menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", menu.cursorX, menu.cursorY)
            return
        end
        -- Clamping alone would slide a list that does not fit below its anchor up over the anchor itself.
        local bottom = anchor:GetBottom()
        local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if bottom and bottom * scale + menu.dy < menu:GetHeight() then
            menu:SetPoint("BOTTOMLEFT", anchor, (menu.at:gsub("BOTTOM", "TOP")), menu.dx, -menu.dy)
        else
            menu:SetPoint("TOPLEFT", anchor, menu.at, menu.dx, menu.dy)
        end
    end
    menu.idle = 0
    menu.lent = {}
    menu.style = STYLES.small
    menu:SetScript("OnUpdate", function(self, elapsed)
        -- The overlay takes the mouse, so the row under it never lights on its own.
        for _, lent in ipairs(self.lent) do
            if lent.frame:IsMouseOver() then lent.button:LockHighlight() else lent.button:UnlockHighlight() end
        end
        if self.tips then syncTip() end
        if not anchorVisible(self.anchor) then
            self:Hide()
            return
        end
        if self.style == STYLES.large then
            if pressedOutside() then self:Hide() end
            return
        end
        if overAnyLevel() or (type(self.anchor) == "table" and self.anchor:IsMouseOver()) then
            self.idle = 0
            return
        end
        self.idle = self.idle + elapsed
        if self.idle >= HIDE_DELAY then self:Hide() end
    end)
    menu:SetScript("OnHide", function(self)
        -- Hidden through an ancestor (say Alt+Z): close for real so no loan outlives the menu.
        if self:IsShown() and not (InCombatLockdown() and #self.lent > 0) then self:Hide() end
        self.anchor = nil
        closeFrom(2)
        releaseOverlays()
        if self.tipRow and GameTooltip:IsOwned(self.tipRow) then GameTooltip:Hide() end
        self.tipRow = nil
    end)
    -- The lock is not on yet during PLAYER_REGEN_DISABLED, so lent frames can still go home then.
    menu:RegisterEvent("PLAYER_REGEN_DISABLED")
    menu:RegisterEvent("PLAYER_REGEN_ENABLED")
    menu:SetScript("OnEvent", function(self)
        if #self.lent == 0 then return end
        if self:IsShown() then self:Hide() else releaseOverlays() end
    end)
    -- Blizzard closes its menus on most clicks around its panels; this one follows.
    hooksecurefunc("CloseDropDownMenus", function() menu:Hide() end)
end

addon.Menu = {}

-- entries: { text, detail, func, checked, keepShown, isTitle, isDivider, disabled, overlay, menu, icon, tooltip, indent }; anchor: frame or "cursor".
function addon.Menu.Open(anchor, entries, options)
    if not menu then build() end
    if menu:IsShown() and menu.anchor == anchor then
        menu:Hide()
        return
    end
    closeFrom(2)
    options = options or {}
    menu.style = options.large and STYLES.large or STYLES.small
    menu.at, menu.dx, menu.dy = options.at or "BOTTOMLEFT", options.x or 0, options.y or 0
    if menu.tipRow and GameTooltip:IsOwned(menu.tipRow) then GameTooltip:Hide() end
    menu.tips, menu.tipRow, menu.wasDown = false, nil, IsMouseButtonDown() and true or false
    menu.entries, menu.anchor, menu.idle = entries, anchor, 0
    if anchor == "cursor" then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        menu.cursorX, menu.cursorY = x / scale, y / scale
    end
    refresh(menu)
    menu.place()
    menu:Show()
end

function addon.Menu.Close()
    if menu then menu:Hide() end
end

function addon.Menu.Refresh()
    if menu and menu:IsShown() then refreshAll() end
end

function addon.Menu.IsOpenFor(anchor)
    return menu ~= nil and menu:IsShown() and menu.anchor == anchor
end
