-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs, pairs, next = ipairs, pairs, next

-- Snippets: restricted code rejects any body naming the closure keyword; @PET@/@SLOTS@ are filled.

local LAYOUT = [[
local cat = root:GetAttribute("cat")
local pages = root:GetAttribute("pages-" .. cat) or 1
local page = root:GetAttribute("page-" .. cat) or 1
if page > pages then page = pages end
if page < 1 then page = 1 end
root:SetAttribute("page-" .. cat, page)
for slot = 1, @SLOTS@ do
    local seat = root:GetFrameRef("slot" .. slot)
    local key = cat .. "-" .. page .. "-" .. slot
    local x = root:GetAttribute("x-" .. key)
    if x then
        seat:ClearAllPoints()
        seat:SetPoint("TOPLEFT", root, "TOPLEFT", x, root:GetAttribute("y-" .. key))
        seat:Show()
    else
        seat:Hide()
    end
end
local back, forward = root:GetFrameRef("back"), root:GetFrameRef("forward")
if page > 1 then back:Enable() else back:Disable() end
if page < pages then forward:Enable() else forward:Disable() end
]]

local TOGGLE = [[
local root = self:GetFrameRef("root")
local cat = root:GetAttribute("cat")
if wantPet then
    if not root:GetAttribute("has-@PET@") then return end
    if root:IsShown() and cat == @PET@ then
        root:Hide()
        return
    end
    cat = @PET@
else
    if root:IsShown() and cat ~= @PET@ then
        root:Hide()
        return
    end
    cat = root:GetAttribute("cat-book")
end
root:SetAttribute("cat", cat)
]] .. LAYOUT .. [[
if root:IsShown() then
    control:CallMethod("SpellbookSync")
else
    root:Show()
end
]]

local STEP = [[
local root = self:GetFrameRef("root")
local cat = root:GetAttribute("cat")
local page = (root:GetAttribute("page-" .. cat) or 1) + self:GetAttribute("step")
if page < 1 or page > (root:GetAttribute("pages-" .. cat) or 1) then return end
root:SetAttribute("page-" .. cat, page)
]] .. LAYOUT .. [[
control:CallMethod("SpellbookSync")
]]

local WHEEL = [[
if self:GetAttribute("wheel-off") then return end
local root = self
local cat = root:GetAttribute("cat")
local page = root:GetAttribute("page-" .. cat) or 1
if delta > 0 then page = page - 1 else page = page + 1 end
if page < 1 or page > (root:GetAttribute("pages-" .. cat) or 1) then return end
root:SetAttribute("page-" .. cat, page)
]] .. LAYOUT .. [[
control:CallMethod("SpellbookSync")
]]

local TAB = [[
local root = self:GetFrameRef("root")
local cat = self:GetID()
if root:GetAttribute("cat") == cat then return end
root:SetAttribute("cat", cat)
if cat ~= @PET@ then root:SetAttribute("cat-book", cat) end
]] .. LAYOUT .. [[
control:CallMethod("SpellbookSync")
]]

-- Resolved at click time from what the current page holds, like an action button's action.
local PRE_CLICK = [[
local cat = owner:GetAttribute("cat")
local key = cat .. "-" .. (owner:GetAttribute("page-" .. cat) or 1) .. "-" .. self:GetID()
local cast = owner:GetAttribute("c-" .. key)
if not cast then return false end
local auto = owner:GetAttribute("a-" .. key)
self:SetAttribute("spell", cast)
self:SetAttribute("macrotext", auto)
if cat ~= @PET@ then
    self:SetAttribute("type2", "spell")
elseif auto then
    self:SetAttribute("type2", "macro")
else
    self:SetAttribute("type2", nil)
end
]]

-- Blizzard's secure drag handler picks up, so it works in combat; pet indices may shift then.
local DRAG = [[
local root = self:GetFrameRef("root")
local cat = root:GetAttribute("cat")
if cat == @PET@ and PlayerInCombat() then return end
local key = cat .. "-" .. (root:GetAttribute("page-" .. cat) or 1) .. "-" .. self:GetID()
local index = root:GetAttribute("i-" .. key)
if not index then return end
return "spell", index, root:GetAttribute("b-" .. key)
]]

local ESCAPE_ON = [[
for position = 1, select("#", GetBindingKey("TOGGLEGAMEMENU")) do
    local key = select(position, GetBindingKey("TOGGLEGAMEMENU"))
    self:SetBindingClick(true, key, "DragonUI_SpellbookFrameCloseButton")
end
]]

-- Not re-shown here: the micro buttons may have moved; out-of-combat placement brings it back.
local VEHICLE = [[
if newstate == "hide" then self:Hide() end
]]

local function fill(body)
    return (body:gsub("@PET@", Book.PET):gsub("@SLOTS@", Book.SLOTS))
end

Book.SNIPPET = {
    keys = fill('local wantPet = button == "RightButton"\n' .. TOGGLE),
    micro = fill("local wantPet = false\n" .. TOGGLE),
    vehicle = VEHICLE,
}

local APPLY_NOW = fill("local root = self\n" .. LAYOUT .. 'control:CallMethod("SpellbookQuietSync")')
local OPEN = fill("local root = self\n" .. LAYOUT
    .. 'if root:IsShown() then control:CallMethod("SpellbookQuietSync") else root:Show() end')

-- Publishing the models ---------------------------------------------------------------------------

local published = {}

-- Only castable slots get a position, so a hidden secure button leaves the card to the mouse.
function Book.Publish(cat)
    local root = Book.root
    local shiftX, shiftY = Book.StageShift("TOPLEFT", Book.contentScale)
    local wanted = {}
    local model = Book.models[cat]
    if model then
        wanted["has-" .. cat] = true
        wanted["pages-" .. cat] = #model.spreads
        for page = 1, #model.spreads do
            local cells = model.spreads[page].cards
            for slot = 1, #cells do
                local cell = cells[slot]
                if cell.entry.cast then
                    local key = cat .. "-" .. page .. "-" .. slot
                    wanted["c-" .. key] = cell.entry.cast
                    wanted["a-" .. key] = cell.entry.autocast
                    wanted["i-" .. key] = cell.entry.index
                    wanted["b-" .. key] = cell.entry.book
                    wanted["x-" .. key] = cell.x + shiftX
                    wanted["y-" .. key] = cell.y - Book.GRID.iconDrop + shiftY
                end
            end
        end
    end
    local previous = published[cat] or {}
    for name in pairs(previous) do
        if wanted[name] == nil then root:SetAttribute(name, nil) end
    end
    for name, value in pairs(wanted) do
        if previous[name] ~= value then root:SetAttribute(name, value) end
    end
    published[cat] = wanted
end

function Book.PublishPresence()
    for cat = 1, Book.CATEGORIES do
        local shown = published[cat] or {}
        local exists = Book.CategoryExists(cat) or nil
        if shown["has-" .. cat] ~= exists then
            Book.root:SetAttribute("has-" .. cat, exists)
            shown["has-" .. cat] = exists
            published[cat] = shown
        end
    end
end

function Book.ApplySecure()
    SecureHandlerExecute(Book.root, APPLY_NOW)
end

-- Out of combat only: the root is protected and shown or hidden through its own snippets.
function Book.OpenBook(pet)
    if Book.Locked() then return end
    if next(Book.dirty) then Book.Rebuild() end
    local root = Book.root
    local cat = root:GetAttribute("cat-book")
    if pet and root:GetAttribute("has-" .. Book.PET) then cat = Book.PET end
    root:SetAttribute("cat", cat)
    SecureHandlerExecute(root, OPEN)
end

function Book.CloseBook()
    if Book.IsOpen() and not Book.Locked() then SecureHandlerExecute(Book.root, "self:Hide()") end
end

-- Secure pieces -----------------------------------------------------------------------------------

local function linked(frame, snippet)
    SecureHandlerSetFrameRef(frame, "root", Book.root)
    frame:SetAttribute("_onclick", snippet)
    frame.SpellbookSync = Book.SyncLoud
end

-- Chat-link and pickup clicks resolve to no action; PostClick handles them in plain code.
function Book.ArmCaster(button)
    button:SetAttribute("modifiers", "CHATLINK:link,PICKUPACTION:pick,SELFCAST:self")
    button:SetAttribute("checkselfcast", true)
    button:SetAttribute("type1", "spell")
    button:SetAttribute("self-type*", "spell")
end

local function buildSlot(root, slot)
    local seat = CreateFrame("Button", nil, root, "SecureActionButtonTemplate,SecureHandlerDragTemplate")
    seat:Hide()
    seat:SetID(slot)
    seat:SetSize(Book.GRID.iconButton, Book.GRID.iconButton)
    seat:SetFrameLevel(Book.Level("slot"))
    Book.ScaleWithContent(seat)
    seat:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    seat:RegisterForDrag("LeftButton")
    Book.ArmCaster(seat)
    seat:SetScript("OnEnter", Book.SlotEnter)
    seat:SetScript("OnLeave", Book.SlotLeave)
    seat:SetScript("OnMouseDown", Book.SlotPress)
    seat:SetScript("OnMouseUp", Book.SlotRelease)
    seat:SetScript("PostClick", Book.SlotPostClick)
    seat:HookScript("OnDragStart", Book.SlotDragged)
    SecureHandlerSetFrameRef(seat, "root", root)
    seat:SetAttribute("_ondragstart", fill(DRAG))
    seat:SetAttribute("_onreceivedrag", fill(DRAG))
    SecureHandlerWrapScript(seat, "OnClick", root, fill(PRE_CLICK))
    SecureHandlerSetFrameRef(root, "slot" .. slot, seat)
end

local function buildClose(root)
    local close = CreateFrame("Button", "DragonUI_SpellbookFrameCloseButton", root, "SecureHandlerClickTemplate")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", 1, 0)
    close:SetFrameLevel(Book.Level("buttons"))
    close:RegisterForClicks("AnyUp")
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetDisabledTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    SecureHandlerSetFrameRef(close, "root", root)
    close:SetAttribute("_onclick", [[self:GetFrameRef("root"):Hide()]])
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then CP.ModernizeCloseButton(close, root, 1, 0) end
end

local turners = {}

-- Out of combat only. Drawn at scale 1, spaced in UI units from the pager's spot on the page.
function Book.PlaceArrows()
    local x, y = Book.OnBook("BOTTOMRIGHT", -75, 40, Book.contentScale)
    for _, turner in ipairs(turners) do
        turner:ClearAllPoints()
        turner:SetPoint("BOTTOMRIGHT", Book.root, "BOTTOMRIGHT", x + turner.offset, y)
    end
end

local function buildArrow(root, direction, step, offset)
    local turner = CreateFrame("Button", nil, root, "SecureHandlerClickTemplate")
    turner:SetSize(32, 32)
    turner.offset = offset
    turners[#turners + 1] = turner
    turner:SetFrameLevel(Book.Level("catcher"))
    turner:RegisterForClicks("LeftButtonUp")
    local art = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
    turner:SetNormalTexture(art .. "Up")
    turner:SetPushedTexture(art .. "Down")
    turner:SetDisabledTexture(art .. "Disabled")
    turner:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    turner:SetAttribute("step", step)
    linked(turner, fill(STEP))
    turner:SetScript("OnEnter", Book.PagerEnter)
    return turner
end

local function buildTabCatcher(root, cat)
    local catcher = CreateFrame("Button", nil, root, "SecureHandlerClickTemplate")
    catcher:Hide()
    catcher:SetID(cat)
    catcher:SetFrameLevel(Book.Level("catcher"))
    catcher:RegisterForClicks("LeftButtonUp")
    linked(catcher, fill(TAB))
    catcher:SetScript("OnEnter", Book.TabEnter)
    catcher:SetScript("OnLeave", Book.TabLeave)
    catcher:SetScript("PostClick", Book.TabClicked)
    return catcher
end

function Book.BuildSecure()
    local root = Book.root
    root.SpellbookSync, root.SpellbookQuietSync = Book.SyncLoud, Book.SyncQuiet
    root:SetAttribute("_onshow", ESCAPE_ON)
    root:SetAttribute("_onhide", "self:ClearBindings()")
    root:SetAttribute("_onmousewheel", fill(WHEEL))

    for slot = 1, Book.SLOTS do
        buildSlot(root, slot)
    end
    buildClose(root)
    SecureHandlerSetFrameRef(root, "forward", buildArrow(root, "Next", 1, 0))
    SecureHandlerSetFrameRef(root, "back", buildArrow(root, "Prev", -1, -32 - 8))
    Book.PlaceArrows()
    Book.tabCatchers = {}
    for cat = 1, Book.CATEGORIES do
        Book.tabCatchers[cat] = buildTabCatcher(root, cat)
    end
end
