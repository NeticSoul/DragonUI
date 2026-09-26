local addon = select(2, ...)

-- Not UIDropDownMenu: UIDROPDOWNMENU_OPEN_MENU never clears and blocks the map blobs in combat.

local BUTTON_H = 16
local DIVIDER_H = 9
local INSET_X, INSET_Y = 12, 10
local MIN_W = 100
local CHECK_W = 16
local ARROW_W = 16
local DETAIL_GAP = 16
-- UIDropDownMenu's own idle timeout.
local HIDE_DELAY = 2

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

local function refresh(level)
    if level == menu then releaseOverlays() end
    local checkable, width = false, MIN_W
    for _, entry in ipairs(level.entries) do
        if entry.checked ~= nil then checkable = true end
    end
    local indent = checkable and CHECK_W + 2 or 2
    local y = INSET_Y
    for index, entry in ipairs(level.entries) do
        local button = level.buttons[index] or acquire(level, index)
        button.entry = entry
        local divider = entry.isDivider
        button:SetHeight(divider and DIVIDER_H or BUTTON_H)
        if divider then button.divider:Show() else button.divider:Hide() end
        local font = entry.isTitle and "GameFontNormalSmallLeft"
            or entry.disabled and "GameFontDisableSmallLeft" or "GameFontHighlightSmallLeft"
        button.text:SetFontObject(font)
        button.text:SetText(not divider and entry.text or "")
        button.text:SetPoint("LEFT", button, "LEFT", entry.isTitle and 2 or indent, 0)
        button.detail:SetText(not divider and entry.detail or "")
        button.detail:ClearAllPoints()
        button.detail:SetPoint("RIGHT", button, "RIGHT", entry.menu and -ARROW_W or 0, 0)
        button.text:SetPoint("RIGHT", entry.detail and button.detail or button, entry.detail and "LEFT" or "RIGHT",
            entry.detail and -DETAIL_GAP or 0, 0)
        local checked = entry.checked
        if type(checked) == "function" then checked = checked() end
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
            local w = button.text:GetStringWidth() + indent + 8 + (entry.menu and ARROW_W or 0)
            if entry.detail then w = w + DETAIL_GAP + button.detail:GetStringWidth() end
            width = math.max(width, w)
        end
        y = y + (divider and DIVIDER_H or BUTTON_H)
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
    button:SetHeight(BUTTON_H)
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
    level:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
    level:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
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
        if bottom and bottom * scale < menu:GetHeight() then
            menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 0)
        else
            menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
        end
    end
    menu.idle = 0
    menu.lent = {}
    menu:SetScript("OnUpdate", function(self, elapsed)
        -- The overlay takes the mouse, so the row under it never lights on its own.
        for _, lent in ipairs(self.lent) do
            if lent.frame:IsMouseOver() then lent.button:LockHighlight() else lent.button:UnlockHighlight() end
        end
        if not anchorVisible(self.anchor) then
            self:Hide()
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
        self.anchor = nil
        closeFrom(2)
        releaseOverlays()
    end)
    -- Blizzard closes its menus on most clicks around its panels; this one follows.
    hooksecurefunc("CloseDropDownMenus", function() menu:Hide() end)
end

addon.Menu = {}

-- entries: { text, detail, func, checked, keepShown, isTitle, isDivider, disabled, overlay, menu }; anchor: frame or "cursor".
function addon.Menu.Open(anchor, entries)
    if not menu then build() end
    if menu:IsShown() and menu.anchor == anchor then
        menu:Hide()
        return
    end
    closeFrom(2)
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
