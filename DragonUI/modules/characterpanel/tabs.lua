local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Six, not Blizzard's five: honorpane.lua adds a Honor tab at the end.
local NUM_TABS = 6

-- Blizzard's tab order is NOT CHARACTERFRAME_SUBFRAMES order: 3 is Reputation, 4 is Skills. Slot 2
-- keeps its own meaning -- petpane.lua takes it over and shows it only while there is a pet.
local TAB_SUBFRAME = {
    [1] = "PaperDollFrame",
    [2] = "DragonUIPetFrame",
    [3] = "ReputationFrame",
    [4] = "SkillFrame",
    [5] = "TokenFrame",
    [6] = "DragonUIHonorFrame",
}

local TAB_START_X = 11
local TAB_GAP = 1

-- Same sheet and texcoords bagster uses, so the character tabs read as the same retail metal as
-- the bag windows. Blizzard's CharacterFrameTabButtonTemplate already provides every region.
local TAB_TEX = addon._dir .. "UI\\uiframetabs"

-- The button is 32 tall; inactive art is 36 and the selected *Disabled* set 42, both flush to the
-- top, so the extra grows DOWNWARD and the selected tab drops below the strip.
local TAB_H, ACTIVE_LIFT = 32, 0

-- Overhangs read off where the art sits inside each rect: inactive caps carry 1px on their outer
-- edge, the ACTIVE right cap 2px and its left none. Both states span -4 .. W+4 of visible art.
local CAP_OVERHANG = 5
local ACTIVE_OVERHANG_L, ACTIVE_OVERHANG_R = 4, 6
local TAB_PIECES = {
    { key = "Left", w = 35, h = 36, tc = { 0.015625, 0.5625, 0.816406, 0.957031 }, p = "TOPLEFT", x = -CAP_OVERHANG, y = 0 },
    { key = "Right", w = 37, h = 36, tc = { 0.015625, 0.59375, 0.667969, 0.808594 }, p = "TOPRIGHT", x = CAP_OVERHANG, y = 0 },
    { key = "LeftDisabled", w = 35, h = 42, tc = { 0.015625, 0.5625, 0.496094, 0.660156 }, p = "TOPLEFT", x = -ACTIVE_OVERHANG_L, y = ACTIVE_LIFT },
    { key = "RightDisabled", w = 37, h = 42, tc = { 0.015625, 0.59375, 0.324219, 0.488281 }, p = "TOPRIGHT", x = ACTIVE_OVERHANG_R, y = ACTIVE_LIFT },
}

-- PanelTemplates_TabResize bills 2 * Left:GetWidth() as padding and our caps are 35 wide, so we
-- size to the text ourselves and re-assert after Blizzard's OnShow resize.
local TAB_TEXT_PAD = 30
-- The caps must not meet: below 62 they overlap, and while that is invisible on the opaque plate
-- the additive highlight sums the shared strip twice and draws a brighter band down the tab.
local TAB_MIN_W = 62

-- The template's highlight lights a rectangle, not the tab. Retail lights the tab's own silhouette
-- by drawing the inactive art again additively, so this is a 3-slice from the same rects.
local HL_ALPHA = 0.4
-- Cut to the tab's SOLID body, 30 of the art's 36 rows: the last six are a drop shadow, and adding
-- a shadow to itself read as the background spilling out below the border.
local HL_H = 30
local HL_PIECES = {
    { key = "Left", w = 35, h = HL_H, tc = { 0.015625, 0.5625, 0.816406, 0.933594 }, p = "TOPLEFT" },
    { key = "Right", w = 37, h = HL_H, tc = { 0.015625, 0.59375, 0.667969, 0.785156 }, p = "TOPRIGHT" },
}
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }

local function tab(i)
    return _G["CharacterFrameTab" .. i]
end

local function buildHighlight(t)
    if t._duiHighlight then return end
    local name = t:GetName()

    -- The template's own highlight would light a plain rectangle on top of ours.
    local stock = t:GetHighlightTexture()
    if stock then stock:SetTexture(nil) end

    local pieces, ends = {}, {}
    for _, piece in ipairs(HL_PIECES) do
        local anchor = _G[name .. piece.key]
        if not anchor then return end
        local tex = t:CreateTexture(nil, "HIGHLIGHT")
        tex:SetTexture(TAB_TEX)
        tex:SetTexCoord(unpack(piece.tc))
        tex:SetSize(piece.w, piece.h)
        tex:SetPoint(piece.p, anchor, piece.p, 0, 0)
        tex:SetBlendMode("ADD")
        tex:SetAlpha(HL_ALPHA)
        pieces[#pieces + 1] = tex
        ends[piece.key] = tex
    end

    local middle = t:CreateTexture(nil, "HIGHLIGHT")
    middle:SetTexture(TAB_TEX)
    middle:SetTexCoord(unpack(HL_MIDDLE_TC))
    middle:SetHorizTile(true)
    middle:SetHeight(HL_H)
    middle:SetPoint("TOPLEFT", ends.Left, "TOPRIGHT", 0, 0)
    middle:SetPoint("TOPRIGHT", ends.Right, "TOPLEFT", 0, 0)
    middle:SetBlendMode("ADD")
    middle:SetAlpha(HL_ALPHA)
    pieces[#pieces + 1] = middle

    t._duiHighlight = pieces
end

local function reskin(t)
    if not t or t._duiReskinned then return end
    t._duiReskinned = true
    local name = t:GetName()

    for _, piece in ipairs(TAB_PIECES) do
        local tex = _G[name .. piece.key]
        if tex then
            tex:ClearAllPoints()
            tex:SetTexture(TAB_TEX)
            tex:SetTexCoord(unpack(piece.tc))
            tex:SetSize(piece.w, piece.h)
            tex:SetPoint(piece.p, t, piece.p, piece.x, piece.y)
        end
    end

    -- The selected tab needs its OWN strip; using the inactive one painted it as a solid gold block.
    local MIDDLES = {
        { key = "Middle", cap = "", h = 36, tc = { 0, 0.015625, 0.175781, 0.316406 } },
        { key = "MiddleDisabled", cap = "Disabled", h = 42, tc = { 0, 0.015625, 0.00390625, 0.16796875 } },
    }
    for _, m in ipairs(MIDDLES) do
        local tex = _G[name .. m.key]
        local left, right = _G[name .. "Left" .. m.cap], _G[name .. "Right" .. m.cap]
        if tex and left and right then
            tex:ClearAllPoints()
            tex:SetTexture(TAB_TEX)
            tex:SetTexCoord(unpack(m.tc))
            -- Height only, never width: the strip spans between the caps by anchor, and a width on
            -- top leaves the engine reconciling a 1px column against the span.
            tex:SetHorizTile(true)
            tex:SetHeight(m.h)
            tex:SetPoint("TOPLEFT", left, "TOPRIGHT")
            tex:SetPoint("TOPRIGHT", right, "TOPLEFT")
        end
    end

    t:SetHeight(TAB_H)
    buildHighlight(t)

    -- Deterministic rather than inherited: PanelTemplates_SelectTab rewrites the disabled font, and
    -- syncState puts it back, so all three states have to be pinned in one place.
    t:SetNormalFontObject(GameFontNormalSmall)
    t:SetHighlightFontObject(GameFontHighlightSmall)
    t:SetDisabledFontObject(GameFontNormalSmall)
end

-- The selected art is 42 tall against 36, both flush to the top, so its centre falls 3px lower --
-- and PanelTemplates_SelectTab only swaps textures, never touching the label.
local TEXT_ACTIVE_DROP = -7
-- Tuned by eye: the label lands right of the tab's optical centre and neither the art extent nor
-- PanelTemplates_TabResize nor the font accounts for it.
local TEXT_NUDGE_X = -2
local function syncState(t)
    local activeArt = _G[t:GetName() .. "MiddleDisabled"]
    local selected = activeArt and activeArt:IsShown()

    local text = _G[t:GetName() .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", t, "CENTER", TEXT_NUDGE_X, selected and TEXT_ACTIVE_DROP or 0)
    end

    -- Muted rather than hidden while selected: the highlight is cut for the 36px inactive body, so
    -- over the taller active art it lights a band that stops short of the tab's own edge.
    if t._duiHighlight then
        for _, tex in ipairs(t._duiHighlight) do
            tex:SetAlpha(selected and 0 or HL_ALPHA)
        end
    end

    -- Adjacent tabs overlap by 7px of cap art, so draw order decides where the seam lands. The
    -- selected one goes above its neighbours; the rest share a level and resolve left to right.
    local owner = t:GetParent()
    if owner then t:SetFrameLevel(owner:GetFrameLevel() + (selected and 4 or 1)) end

    -- PanelTemplates_SelectTab swaps the disabled font to the highlight one, which is what turned
    -- the selected label white. White belongs to hover alone.
    t:SetDisabledFontObject(GameFontNormalSmall)

    -- SelectTab also disables the tab, and a disabled button gets no OnEnter -- 3.3.5a has no
    -- SetMotionScriptsWhileDisabled. Re-enabling costs nothing: clicking the active tab reselects it.
    t:Enable()
end

local function resize(t)
    local text = _G[t:GetName() .. "Text"]
    if not text then return end

    -- GetStringWidth with the box cleared first: CharacterFrame_TabBoundsCheck stamps an explicit
    -- width on the labels it wants to fit, so GetWidth returns Blizzard's clamp, not the label.
    text:SetWidth(0)
    local w = math.max(TAB_MIN_W, text:GetStringWidth() + TAB_TEXT_PAD)
    -- Whole pixels: a fractional width puts a tab's edge between two and the next tab inherits it.
    t:SetWidth(math.floor(w + 0.5))
    t:SetHeight(TAB_H)
    syncState(t)
end

-- Blizzard sits the tabs at BOTTOMLEFT+(11,46), i.e. inside the frame where our nineslice
-- now runs; retail hangs them off the bottom edge instead.
local function rechain()
    local prev
    for i = 1, NUM_TABS do
        local t = tab(i)
        if t and t:IsShown() then
            reskin(t)
            resize(t)
            t:ClearAllPoints()
            if prev then
                t:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
            else
                t:SetPoint("TOPLEFT", _G.CharacterFrame, "BOTTOMLEFT", TAB_START_X, 2)
            end
            prev = t
        end
    end
end

-- Tab widths come from the TRANSLATED label, so a wider panel cannot be a constant: six tabs fit
-- in 430 in English and overflow it in German. Measured, the strip is right in every locale.
local TAB_RIGHT_MARGIN = 6

function CP.TabStripWidth()
    local total, first = TAB_START_X, true
    for i = 1, NUM_TABS do
        local t = tab(i)
        if t and t:IsShown() then
            if not first then total = total + TAB_GAP end
            total = total + (t:GetWidth() or 0)
            first = false
        end
    end
    return total
end

function CP.WidthForTabs(base)
    return math.max(base or 0, CP.TabStripWidth() + TAB_RIGHT_MARGIN)
end

function CP.TabStripRight()
    local right, cf = nil, _G.CharacterFrame
    if not cf then return nil end
    for i = 1, NUM_TABS do
        local t = tab(i)
        if t and t:IsShown() then
            local r = t:GetRight()
            if r then
                local base = cf:GetLeft()
                if base then
                    local rel = r - base
                    if not right or rel > right then right = rel end
                end
            end
        end
    end
    return right
end

local function activeTabName()
    for _, name in ipairs(CP.SUBFRAMES) do
        local f = _G[name]
        if f and f:IsShown() then return name end
    end
    return "PaperDollFrame"
end

CP.ActiveTabName = activeTabName

local showSubFrameHooked, resizeHooked, reasserting, selectionHooked

-- Selecting a tab swaps which art is shown without resizing anything, so the label has to be
-- re-placed at that moment; nothing else in the chain runs then.
local function hookTabSelection()
    if selectionHooked or not _G.PanelTemplates_SelectTab then return end
    selectionHooked = true
    local function onSelectionChanged(t)
        if t and t._duiReskinned then syncState(t) end
    end
    hooksecurefunc("PanelTemplates_SelectTab", onSelectionChanged)
    hooksecurefunc("PanelTemplates_DeselectTab", onSelectionChanged)
end

-- Each tab's OnShow runs PanelTemplates_TabResize(self, 0), which recomputes the width from our
-- 35px caps and undoes the strip every time a tab is displayed.
local function hookBlizzardResize()
    if resizeHooked or not _G.PanelTemplates_TabResize then return end
    resizeHooked = true
    hooksecurefunc("PanelTemplates_TabResize", function(t)
        if reasserting or not t or not t._duiReskinned then return end
        reasserting = true
        -- Tabs on a window of ours other than the character panel carry their own chain.
        if t._duiRelayout then t._duiRelayout() else rechain() end
        reasserting = false
    end)
end

local function build()
    if not _G.CharacterFrame then return end
    rechain()
    hookBlizzardResize()
    hookTabSelection()

    -- Tab5 (Currency) starts hidden and Blizzard shows it once the player owns a currency,
    -- so the chain has to be rebuilt at that moment, not only at login.
    for i = 1, NUM_TABS do
        local t = tab(i)
        if t and not t._duiTabHooked then
            t._duiTabHooked = true
            t:HookScript("OnShow", rechain)
            t:HookScript("OnHide", rechain)
        end
    end

    if _G.CharacterFrame_ShowSubFrame and not showSubFrameHooked then
        showSubFrameHooked = true
        hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
            if CP.SetInsetForTab then CP.SetInsetForTab(frameName) end
            if CP.ApplySidebarForTab then CP.ApplySidebarForTab(frameName) end
            if CP.UpdatePortrait then CP.UpdatePortrait(frameName) end
        end)
    end
end

CP.RechainTabs = rechain
CP.TAB_SUBFRAME = TAB_SUBFRAME

-- Shared so a DragonUI window outside the character panel gets the same tab art. The hooks come
-- with it: Blizzard's PanelTemplates applies the selected state, so a tab elsewhere needs re-syncing.
function CP.ReskinTab(t)
    if not t then return end
    hookTabSelection()
    hookBlizzardResize()
    reskin(t)
    resize(t)
end

CP:RegisterBuilder("tabs", build)
