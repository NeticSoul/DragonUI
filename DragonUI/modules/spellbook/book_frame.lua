-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs, max, min = ipairs, math.max, math.min

local art = {}

Book.INK = { 0.1804, 0.1059, 0.0588 }

-- Texture sublevels are ignored on this client, so overlapping pieces get their own frame level.
Book.LEVEL = {
    paper = 1, corner = 2, header = 2, content = 3, cardSweep = 4, cardRing = 5, cardSparks = 6, cardGlow = 7,
    slot = 8, cardRanks = 9, catcher = 10, chrome = 11, title = 12, buttons = 13,
    strip = 40, stripEntry = 41, stripTab = 43,
}

function Book.Level(name)
    return Book.root:GetFrameLevel() + Book.LEVEL[name]
end

local function sheet(parent, layer, atlas)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetAtlasTexture(atlas)
    return tex
end

-- Paper, ribbon, wood strip and page corner ------------------------------------------------------

local function buildPaper(stage)
    local paper = CreateFrame("Frame", nil, stage)
    paper:SetAllPoints(stage)
    paper:SetFrameLevel(Book.Level("paper"))

    art.left = sheet(paper, "BACKGROUND", "spellbook-background-evergreen-left")
    art.left:SetPoint("TOPLEFT", stage, "TOPLEFT", 2, -82)
    art.left:SetPoint("BOTTOMRIGHT", stage, "BOTTOM", -1, 2)

    art.right = sheet(paper, "BACKGROUND", "spellbook-background-evergreen-right")

    art.ribbon = sheet(paper, "BORDER", "spellbook-background-evergreen-ribbon")
    art.ribbon:SetWidth(102)
    art.ribbon:SetPoint("TOP", stage, "TOP", 0, -82)
    art.ribbon:SetPoint("BOTTOM", stage, "BOTTOM", 0, 2)

    -- Part of the pager block, drawn at scale 1; Book.PlaceControls puts it on the page.
    local fold = CreateFrame("Frame", nil, Book.root)
    fold:SetAllPoints(Book.root)
    fold:SetFrameLevel(Book.Level("corner"))
    Book.corner = sheet(fold, "ARTWORK", "spellbook-corner-flipbook-evergreen")
    Book.corner:SetSize(150, 155)

    art.wood = paper:CreateTexture(nil, "ARTWORK")
    art.wood:SetHeight(58)
    art.wood:SetPoint("TOPLEFT", stage, "TOPLEFT", 8, -26)
    art.wood:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -8, -26)
end

-- Metal frame, portrait and title -----------------------------------------------------------------

local function buildChrome(root)
    local chrome = CreateFrame("Frame", nil, root)
    chrome:SetAllPoints(root)
    chrome:SetFrameLevel(Book.Level("chrome"))
    DragonUI_NineSlice.ApplyLayout(chrome, DragonUI_NineSlice.GetLayout("PortraitFrameTemplateMinimizable"))

    local portrait = chrome:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(57, 57)
    portrait:SetPoint("TOPLEFT", root, "TOPLEFT", -3, 6)
    portrait:SetTexture(addon._dir .. "ClassIcons\\" .. select(2, UnitClass("player")))

    local band = CreateFrame("Frame", nil, root)
    band:SetAllPoints(root)
    band:SetFrameLevel(Book.Level("title"))
    local title = band:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 58, -6)
    title:SetPoint("TOPRIGHT", root, "TOPRIGHT", -24, -6)
    title:SetJustifyH("CENTER")
    title:SetText(SPELLBOOK)
end

-- One or two pages --------------------------------------------------------------------------------

function Book.LayoutMode()
    local wide, stage = Book.Wide(), Book.stage
    stage:SetSize(Book.WindowWidth(), Book.HEIGHT)
    art.left:SetShownCompat(wide)
    art.ribbon:SetShownCompat(wide)
    art.right:ClearAllPoints()
    if wide then
        art.right:SetPoint("TOPLEFT", stage, "TOP", 1, -82)
        art.right:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -2, 2)
    else
        art.right:SetPoint("TOPLEFT", stage, "TOPLEFT", 2, -82)
        art.right:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", 0, 2)
    end
    art.wood:SetAtlasTexture(wide and "spellbook-background-evergreen-header" or "spellbook-header-left-half")
    Book.PaintModeButton()
end

-- Scale and placement (out of combat: the root is protected) -------------------------------------

-- Session-only position of the top-left corner after a drag, in UIParent units (the root is at 1).
function Book.RememberPlace()
    local root = Book.root
    local left, top = root:GetLeft(), root:GetTop()
    if left and top then Book.position = { left, top } end
end

-- Secure buttons stay direct children of the root, so they carry the content scale themselves.
function Book.ScaleWithContent(frame)
    Book.scaledSecure[#Book.scaledSecure + 1] = frame
    frame:SetScale(Book.contentScale)
end

-- Out of combat only: the root and its secure children are protected.
local function placeStage(wide, scale)
    Book.CloseRanks()
    local root, stage = Book.root, Book.stage
    root:SetSize(Book.WindowSize(wide, scale))
    stage:SetScale(scale)
    stage:ClearAllPoints()
    stage:SetPoint("TOPLEFT", root, "TOPLEFT", Book.StageShift("TOPLEFT", scale))
    for _, frame in ipairs(Book.scaledSecure) do
        frame:SetScale(scale)
    end
    if Book.PlaceControls then Book.PlaceControls() end
end

function Book.ApplyScale()
    local root = Book.root
    local wanted = min(1.2, max(0.5, tonumber(Book.Config().scale) or 0.8))
    local config = Book.Config()
    local wide, scale = Book.FitWindow(not config.minimized, config.forceWide, wanted,
        UIParent:GetWidth(), UIParent:GetHeight())
    if wide ~= Book.shownWide or scale ~= Book.contentScale then
        Book.shownWide, Book.contentScale = wide, scale
        placeStage(wide, scale)
        Book.LayoutMode()
        -- Secure slot positions are published in content units at this scale.
        Book.MarkAllDirty()
    end
    root:ClearAllPoints()
    local spot = Book.position
    -- Centred like the talent window until the player drags it; the drag holds for the session.
    if not spot then
        root:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        return
    end
    local left = max(0, min(spot[1], UIParent:GetWidth() - root:GetWidth()))
    local top = min(UIParent:GetHeight(), max(spot[2], root:GetHeight()))
    root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- The place is taken first so the left edge stays put while the width changes.
function Book.SetMinimized(minimized)
    if Book.RefuseInCombat() then return end
    local first = Book.FirstShownKey()
    if Book.position then Book.RememberPlace() end
    local config = Book.Config()
    -- Only the button forces two pages; until then FitWindow drops to one where they overflow.
    config.minimized, config.forceWide = minimized, not minimized
    Book.ApplyScale()
    local root = Book.root
    local cat = root:GetAttribute("cat")
    Book.MarkAllDirty()
    Book.Rebuild()
    local model = Book.models[cat]
    local spread = model and Book.SpreadHolding(model.spreads, first)
    if spread then
        root:SetAttribute("page-" .. cat, spread)
        Book.ApplySecure()
    end
end

-- Dragging ----------------------------------------------------------------------------------------

function Book.StopDrag()
    Book.dragging = false
    Book.root:StopMovingOrSizing()
    -- A named movable frame would otherwise land in layout-local.txt; the position is session-only.
    Book.root:SetUserPlaced(false)
    Book.RememberPlace()
end

local function dragStart(root)
    if Book.RefuseInCombat() then return end
    Book.dragging = true
    root:StartMoving()
end

local function dragStop()
    if Book.dragging then Book.StopDrag() end
end

-- Root --------------------------------------------------------------------------------------------

function Book.BuildWindow()
    local root = CreateFrame("Frame", "DragonUI_SpellbookFrame", UIParent,
        "SecureHandlerShowHideTemplate,SecureHandlerMouseWheelTemplate")
    Book.root = root
    root:Hide()
    root:SetSize(Book.WIDE_W, Book.HEIGHT)
    root:SetFrameStrata("HIGH")
    -- Toplevel: the client raises it on click by itself, combat included.
    root:SetToplevel(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(true)
    root:SetClampedToScreen(true)
    root:SetScript("OnDragStart", dragStart)
    root:SetMovable(true)
    root:SetScript("OnDragStop", dragStop)
    root:EnableMouseWheel(true)
    root:SetAttribute("cat", Book.CLASS)
    root:SetAttribute("cat-book", Book.CLASS)

    -- Everything inside the frame hangs off this stage at the book's content scale.
    local stage = CreateFrame("Frame", nil, root)
    stage:SetSize(Book.WIDE_W, Book.HEIGHT)
    stage:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    Book.stage = stage
    Book.contentScale, Book.scaledSecure = 1, {}

    local fill = root:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(0.03, 0.04, 0.03, 1)
    fill:SetPoint("TOPLEFT", root, "TOPLEFT", 2, -21)
    fill:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -2, 2)

    buildPaper(stage)
    buildChrome(root)

    root:HookScript("OnShow", Book.WindowShown)
    root:HookScript("OnHide", Book.WindowHidden)
end
