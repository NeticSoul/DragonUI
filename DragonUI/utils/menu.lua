local addon = select(2, ...)

-- Not UIDropDownMenu: UIDROPDOWNMENU_OPEN_MENU never clears and blocks the map blobs in combat.

local BUTTON_H = 16
local INSET_X, INSET_Y = 12, 10
local MIN_W = 100
local CHECK_W = 16
-- UIDropDownMenu's own idle timeout.
local HIDE_DELAY = 2

local menu
local buttons = {}

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

local function refresh()
    releaseOverlays()
    local checkable, width = false, MIN_W
    for _, entry in ipairs(menu.entries) do
        if entry.checked ~= nil then checkable = true end
    end
    local indent = checkable and CHECK_W + 2 or 2
    for index, entry in ipairs(menu.entries) do
        local button = buttons[index] or menu.acquire(index)
        button.entry = entry
        local font = entry.isTitle and "GameFontNormalSmallLeft"
            or entry.disabled and "GameFontDisableSmallLeft" or "GameFontHighlightSmallLeft"
        button.text:SetFontObject(font)
        button.text:SetText(entry.text)
        button.text:SetPoint("LEFT", button, "LEFT", entry.isTitle and 2 or indent, 0)
        local checked = entry.checked
        if type(checked) == "function" then checked = checked() end
        if checked then button.check:Show() else button.check:Hide() end
        button:EnableMouse(not (entry.isTitle or entry.disabled))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", INSET_X, -(INSET_Y + (index - 1) * BUTTON_H))
        button:SetPoint("RIGHT", menu, "RIGHT", -INSET_X, 0)
        button:Show()
        if entry.overlay then lendOverlay(entry.overlay, button) end
        width = math.max(width, button.text:GetStringWidth() + indent + 8)
    end
    for index = #menu.entries + 1, #buttons do buttons[index]:Hide() end
    menu:SetSize(width + INSET_X * 2, #menu.entries * BUTTON_H + INSET_Y * 2)
end

local function acquire(index)
    local button = CreateFrame("Button", nil, menu)
    button:SetHeight(BUTTON_H)
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
    button.text:SetPoint("RIGHT", button, "RIGHT", 0, 0)
    button.text:SetJustifyH("LEFT")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        PlaySound("igMainMenuOptionCheckBoxOn")
        local handler = (mouseButton == "RightButton" and self.entry.funcRight) or self.entry.func
        if handler then handler() end
        if self.entry.keepShown and menu:IsShown() then refresh() else menu:Hide() end
    end)
    button:SetScript("OnEnter", function(self)
        if self.entry.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if type(self.entry.tooltip) == "table" then
                for i, line in ipairs(self.entry.tooltip) do
                    GameTooltip:AddLine(line, 1, 1, 1)
                end
            else
                GameTooltip:AddLine(self.entry.tooltip, 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    buttons[index] = button
    return button
end

local function anchorVisible(anchor)
    return type(anchor) ~= "table" or anchor:IsVisible()
end

local function build()
    menu = CreateFrame("Frame", "DragonUIMenu", UIParent)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    menu:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
    menu:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
    menu.acquire = acquire
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
        if self:IsMouseOver() or (type(self.anchor) == "table" and self.anchor:IsMouseOver()) then
            self.idle = 0
            return
        end
        self.idle = self.idle + elapsed
        if self.idle >= HIDE_DELAY then self:Hide() end
    end)
    menu:SetScript("OnHide", function(self)
        self.anchor = nil
        releaseOverlays()
    end)
    menu:Hide()
    -- Blizzard closes its menus on most clicks around its panels; this one follows.
    hooksecurefunc("CloseDropDownMenus", function() menu:Hide() end)
end

addon.Menu = {}

-- entries: { text, func, checked, keepShown, isTitle, disabled, overlay }; anchor is a frame or "cursor".
function addon.Menu.Open(anchor, entries)
    if not menu then build() end
    if menu:IsShown() and menu.anchor == anchor then
        menu:Hide()
        return
    end
    menu.entries, menu.anchor, menu.idle = entries, anchor, 0
    menu:ClearAllPoints()
    if anchor == "cursor" then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    else
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
    end
    refresh()
    menu:Show()
end

function addon.Menu.Close()
    if menu then menu:Hide() end
end

function addon.Menu.Refresh()
    if menu and menu:IsShown() then refresh() end
end

function addon.Menu.IsOpenFor(anchor)
    return menu ~= nil and menu:IsShown() and menu.anchor == anchor
end
