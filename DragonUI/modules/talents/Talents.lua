-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local L = addon.L
local T = addon.TalentModule

-- Module state (registry uses initialized/applied for load-once teardown;
-- the tracking tables mirror the module_base/darkmode conventions).
T.initialized      = T.initialized or false
T.applied          = T.applied or false
T.enteredWorld     = T.enteredWorld or false
T.hooks            = T.hooks or {}
T.registeredEvents = T.registeredEvents or {}
T.frames           = T.frames or {}

-- Class backgrounds (moved from Assets.lua)
T.CLASS_BACKGROUND = {
    WARRIOR     = { "talents-background-warrior-arms",          "talents-background-warrior-fury",        "talents-background-warrior-protection" },
    PALADIN     = { "talents-background-paladin-holy",          "talents-background-paladin-protection",  "talents-background-paladin-retribution" },
    HUNTER      = { "talents-background-hunter-beastmastery",   "talents-background-hunter-marksmanship", "talents-background-hunter-survival" },
    ROGUE       = { "talents-background-rogue-assassination",   "talents-background-rogue-outlaw",        "talents-background-rogue-subtlety" },
    PRIEST      = { "talents-background-priest-discipline",     "talents-background-priest-holy",         "talents-background-priest-shadow" },
    SHAMAN      = { "talents-background-shaman-elemental",      "talents-background-shaman-enhancement",  "talents-background-shaman-restoration" },
    MAGE        = { "talents-background-mage-arcane",           "talents-background-mage-fire",           "talents-background-mage-frost" },
    WARLOCK     = { "talents-background-warlock-affliction",    "talents-background-warlock-demonology",  "talents-background-warlock-destruction" },
    DRUID       = { "talents-background-druid-balance",         "talents-background-druid-feral",         "talents-background-druid-restoration" },
    DEATHKNIGHT = { "talents-background-deathknight-blood",     "talents-background-deathknight-frost",   "talents-background-deathknight-unholy" },
}

-- ============================================================================
-- Layout spec
-- ============================================================================
local NODE        = 36
local ICON        = 32
local SQUARE_NODE_FIT = 56 / 64
local ICON_INSET  = 0.84
local CIRCLE_ICON_INSET = ICON_INSET * 0.95
local CAPSTONE_SQUARE_SIZE = 56
local PITCH_X     = 54
local PITCH_Y     = 44
local LAST_TIER_EXTRA = 28
local TREE_Y_SHIFT    = 16
local COLS        = 4
local MAX_TIERS   = 11
local TIERS       = MAX_TIERS
local TREE_GAP    = 132
local HEADER_H    = 28
local BOTTOMBAR_H = 80
local INSET_L, INSET_R, INSET_T, INSET_B = 110, 84, 48, 20
local CHROME_T, CHROME_B, CHROME_L, CHROME_R = 22, 0, 0, 0
local HEADER_CENTER_Y = ((INSET_T + TREE_Y_SHIFT - CHROME_T) - HEADER_H) / 2
local TREE_W = (COLS - 1) * PITCH_X + NODE

-- ============================================================================
-- Frame geometry (derived from tree depth)
-- ============================================================================
local function geometryFor(tiers)
    local treeH = (tiers - 1) * PITCH_Y + NODE
    return treeH,
           HEADER_H + treeH,
           (INSET_T + TREE_Y_SHIFT) + NODE / 2 + HEADER_H + (tiers - 1) * PITCH_Y
             + LAST_TIER_EXTRA + CAPSTONE_SQUARE_SIZE / 2 + 28 + BOTTOMBAR_H
end
local TREE_H, CONTENT_H, TALENT_H = geometryFor(TIERS)
local TALENT_W = 1214
local FRAME_TOP_OFFSET = -55

-- ============================================================================
-- Node center (relative to tree frame TOPLEFT)
-- ============================================================================
local function nodeCenter(tier, column)
    local lay = T._colX
    local x = (lay and lay[column]) or ((column - 1) * PITCH_X + NODE / 2)
    local extraLast = (tier == TIERS) and LAST_TIER_EXTRA or 0
    local y = -((tier - 1) * PITCH_Y) - NODE / 2 - HEADER_H - extraLast - (T._nodeYShift or 0)
    return x, y
end

-- ============================================================================
-- Expose layout constants for Behavior / Glyphs / others
-- ============================================================================
T.LAYOUT = {
    NODE = NODE, ICON = ICON, PITCH_X = PITCH_X, PITCH_Y = PITCH_Y,
    COLS = COLS, TIERS = TIERS, HEADER_H = HEADER_H,
    HEADER_CENTER_Y = HEADER_CENTER_Y, TREE_W = TREE_W, ICON_INSET = ICON_INSET,
}
T.nodeCenter = nodeCenter

-- ============================================================================
-- Column layout (mass-centred per tab)
-- ============================================================================
function T.SetColumnLayout(occupied)
    local sum, n, minC, maxC = 0, 0, nil, nil
    for _, c in ipairs(occupied) do
        local col = c.column
        if col then
            sum, n = sum + col, n + 1
            if not minC or col < minC then minC = col end
            if not maxC or col > maxC then maxC = col end
        end
    end
    if n == 0 then T._colX = nil; return end
    local shift = (COLS + 1) / 2 - sum / n
    local hi, lo = (COLS - maxC) + 0.5, -((minC - 1) + 0.5)
    if shift > hi then shift = hi elseif shift < lo then shift = lo end
    local lay = {}
    for col = 1, COLS do lay[col] = (col - 1 + shift) * PITCH_X + NODE / 2 end
    T._colX = lay
end

-- ============================================================================
-- Frame geometry (consumed by Behavior / Glyphs)
-- ============================================================================
T.FRAME = {
    W = TALENT_W, H = TALENT_H,
    CHROME_T = CHROME_T, CHROME_B = CHROME_B, CHROME_L = CHROME_L, CHROME_R = CHROME_R,
    INSET_L = INSET_L, INSET_R = INSET_R, INSET_T = INSET_T, INSET_B = INSET_B,
    BOTTOMBAR_H = BOTTOMBAR_H,
}

-- ============================================================================
-- Tier depth override (custom-server shallow trees)
-- ============================================================================
function T.SetTierDepth(tiers)
    tiers = tonumber(tiers)
    if not tiers then return end
    if tiers < 1 then tiers = 1 elseif tiers > MAX_TIERS then tiers = MAX_TIERS end
    if tiers == TIERS then return end
    TIERS = tiers
    TREE_H, CONTENT_H, TALENT_H = geometryFor(TIERS)
    T.LAYOUT.TIERS = TIERS
    T.FRAME.H = TALENT_H
    local f = T.frame
    if not f then return end
    f:SetSize(TALENT_W, TALENT_H)
    for i = 1, 3 do
        local tf = f.trees and f.trees[i]
        if tf then tf:SetSize(TREE_W, CONTENT_H) end
    end
    if T.SetBackground then
        pcall(T.SetBackground, T._bgTab or 1)
    end
end

-- ============================================================================
-- Node button factory
-- ============================================================================
local MOCK_ICONS = {
    "Interface\\Icons\\Spell_Holy_PowerInfusion",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Holy_Smite",
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Nature_Lightning",
}

local function ringAtlas(shape, state)
    local stem = (T.SHAPE_ATLAS and T.SHAPE_ATLAS[shape]) or "talents-node-square"
    if state == "dimgreen" then state = "green" end
    return stem .. "-" .. state
end
local function shadowAtlas(shape)
    return (shape == "circle") and "talents-node-circle-shadow" or "talents-node-square-shadow"
end
local function glowAtlas(shape)
    return (shape == "circle") and "talents-node-circle-greenglow" or "talents-node-square-greenglow"
end

local HOVER_ALPHA = { yellow = 1, green = 1, gray = 0.4, locked = 0.4, red = 0.4, dimgreen = 0.4 }

local function CreateNode(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NODE, NODE)

    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetPoint("CENTER")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("CENTER")

    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetPoint("CENTER")

    b.hover = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.hover:SetPoint("CENTER")
    b.hover:SetBlendMode("ADD")
    b.hover:Hide()

    b.sheen = b:CreateTexture(nil, "ARTWORK", nil, 1)
    if b.sheen.set_atlas then
        b.sheen:set_atlas("talents-sheen-node", false)
    end
    b.sheen:SetBlendMode("ADD")
    b.sheen:SetPoint("CENTER")
    b.sheen:Hide()

    b.glow = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.glow:SetPoint("CENTER")
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    b.glowAnim = b.glow:CreateAnimationGroup()
    b.glowAnim:SetLooping("REPEAT")
    if b.glowAnim.SetToFinalAlpha then b.glowAnim:SetToFinalAlpha(true) end
    local gIn = b.glowAnim:CreateAnimation("Alpha")
    gIn:SetDuration(1); gIn:SetOrder(1); gIn:SetSmoothing("OUT")
    if gIn.SetFromAlpha then gIn:SetFromAlpha(0); gIn:SetToAlpha(0.15)
    else gIn:SetChange(0.15) end
    local gOut = b.glowAnim:CreateAnimation("Alpha")
    gOut:SetDuration(1); gOut:SetOrder(2); gOut:SetSmoothing("IN")
    if gOut.SetFromAlpha then gOut:SetFromAlpha(0.15); gOut:SetToAlpha(0)
    else gOut:SetChange(-0.15) end

    b.flash = b:CreateTexture(nil, "OVERLAY", nil, 3)
    b.flash:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.flash:SetBlendMode("ADD")
    b.flash:SetVertexColor(1, 0.9, 0.45)
    b.flash:SetPoint("CENTER")
    b.flash:Hide()
    b.flashAnim = b.flash:CreateAnimationGroup()
    local fIn = b.flashAnim:CreateAnimation("Alpha")
    fIn:SetDuration(0.07); fIn:SetOrder(1)
    if fIn.SetFromAlpha then fIn:SetFromAlpha(0); fIn:SetToAlpha(1) else fIn:SetChange(1) end
    local fOut = b.flashAnim:CreateAnimation("Alpha")
    fOut:SetDuration(0.38); fOut:SetOrder(2); fOut:SetSmoothing("OUT")
    if fOut.SetFromAlpha then fOut:SetFromAlpha(1); fOut:SetToAlpha(0) else fOut:SetChange(-1) end
    b.flashAnim:SetScript("OnFinished", function() b.flash:Hide() end)
    function b:PlaySpend()
        if not self.flash then return end
        self.flashAnim:Stop()
        self.flash:SetAlpha(0); self.flash:Show()
        self.flashAnim:Play()
    end

    b.rank = b:CreateFontString(nil, "OVERLAY")
    b.rank:SetJustifyH("CENTER")
    b.rank:SetFont((STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), 10, "OUTLINE")
    b.rank:SetPoint("TOP", b.icon, "BOTTOM", 0, -1)

    function b:SetVisual(shape, state, iconTex, rankText)
        self._shape = shape
        local big = (shape == "capstone") or (shape == "capstonesquare")
        local base
        if shape == "capstonesquare" or shape == "capstone" then
            base = CAPSTONE_SQUARE_SIZE
        elseif big then
            base = (NODE + 48) * SQUARE_NODE_FIT
        else
            base = NODE * SQUARE_NODE_FIT
        end
        local ringAdj = 0
        self._visualSize = base
        self.ring:SetSize(base + ringAdj, base + ringAdj)
        self.icon:SetTexture(iconTex or MOCK_ICONS[1])
        local insetForShape = (shape == "circle") and CIRCLE_ICON_INSET or ICON_INSET
        self.icon:SetSize(base * insetForShape, base * insetForShape)
        if self.sheen then self.sheen:SetSize(base * insetForShape, base * insetForShape); self._sheenSpan = base * insetForShape end
        if self.flash then self.flash:SetSize(base + ringAdj + 18, base + ringAdj + 18) end
        if self.ring.set_atlas then self.ring:set_atlas(ringAtlas(shape, state), false) end
        local shN = (shape == "circle") and 76 or 78
        local sc = base / 40
        self.shadow:SetSize(shN * sc, shN * sc)
        if self.shadow.set_atlas then self.shadow:set_atlas(shadowAtlas(shape), false) end
        local dim = (state == "gray" or state == "locked")
        local dimGreen = (state == "dimgreen")
        if self.icon.SetDesaturated then self.icon:SetDesaturated(dim) end
        local iconTint = dimGreen and 0.55 or (dim and 0.65 or 1)
        self.icon:SetVertexColor(iconTint, dimGreen and 0.8 or iconTint, iconTint)
        if self.ring.SetVertexColor then
            self.ring:SetVertexColor(dimGreen and 0.5 or 1, dimGreen and 0.8 or 1, dimGreen and 0.5 or 1)
        end
        if self.hover.set_atlas then self.hover:set_atlas(ringAtlas(shape, state), false) end
        self.hover:SetSize(base + ringAdj, base + ringAdj)
        self._hoverAlpha = HOVER_ALPHA[state] or 1
        self.hover:SetAlpha(self._hoverAlpha)
        self.hover:Hide()
        if state == "green" then
            if self.glow.set_atlas then self.glow:set_atlas(glowAtlas(shape), false) end
            self.glow:SetSize(base + 22, base + 22)
            self.glow:Show()
            if not self.glowAnim:IsPlaying() then self.glowAnim:Play() end
        else
            self.glowAnim:Stop()
            self.glow:Hide()
        end
        self.rank:SetText(rankText or "")
        if state == "green" then self.rank:SetTextColor(0.1, 1, 0.1)
        elseif state == "dimgreen" then self.rank:SetTextColor(0.15, 0.6, 0.15)
        elseif state == "gray" or state == "locked" then self.rank:SetTextColor(0.6, 0.6, 0.6)
        else self.rank:SetTextColor(1, 0.82, 0) end
    end

    function b:ShowHover()
        if not T.applied then return end
        if self.hover and (self._hoverAlpha or 0) > 0 then self.hover:Show() end
    end
    function b:HideHover()
        if not T.applied then return end
        if self.hover then self.hover:Hide() end
    end
    b:SetScript("OnEnter", b.ShowHover)
    b:SetScript("OnLeave", b.HideHover)

    return b
end
T.CreateNode = CreateNode

-- ============================================================================
-- Per-tree frame
-- ============================================================================
local function CreateTreeFrame(parent, index)
    local tf = CreateFrame("Frame", "DragonUI_TalentTreeFrame" .. index, parent)
    tf:SetSize(TREE_W, CONTENT_H)
    tf.index = index

    tf.headerName = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if _G.SystemFont_Shadow_Large2 then tf.headerName:SetFontObject(_G.SystemFont_Shadow_Large2) end
    if tf.headerName.SetTextScale then tf.headerName:SetTextScale(0.9) end
    tf.headerName:SetPoint("CENTER", tf, "TOP", 0, HEADER_CENTER_Y)
    tf.headerName:SetTextColor(1, 1, 1)

    tf.headerPts = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if _G.Game32Font_Shadow2 then tf.headerPts:SetFontObject(_G.Game32Font_Shadow2) end
    tf.headerPts:SetPoint("LEFT", tf.headerName, "RIGHT", 8, 0)
    tf.headerPts:SetTextColor(0.1, 1.0, 0.1)

    tf.nodePool, tf.edgeLinePool, tf.edgeArrowPool, tf.gatePool = {}, {}, {}, {}
    tf._edgeLineN, tf._edgeArrowN, tf._gateN = 0, 0, 0

    function tf:AcquireNode(idx)
        local n = self.nodePool[idx]
        if not n then n = CreateNode(self); self.nodePool[idx] = n end
        return n
    end
    function tf:HideUnusedNodes(used)
        for idx, n in pairs(self.nodePool) do if not used[idx] then n:Hide() end end
    end

    function tf:AcquireEdgeLine()
        self._edgeLineN = (self._edgeLineN or 0) + 1
        local t = self.edgeLinePool[self._edgeLineN]
        if not t then
            t = self:CreateTexture(nil, "ARTWORK", nil, -3)
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            self.edgeLinePool[self._edgeLineN] = t
        end
        t:Show()
        return t
    end
    function tf:AcquireEdgeArrow()
        self._edgeArrowN = (self._edgeArrowN or 0) + 1
        local a = self.edgeArrowPool[self._edgeArrowN]
        if not a then
            a = self:CreateTexture(nil, "OVERLAY", nil, 1)
            a:SetTexture("Interface\\Buttons\\WHITE8X8")
            self.edgeArrowPool[self._edgeArrowN] = a
        end
        a:Show()
        return a
    end
    function tf:ResetEdges()
        self._edgeLineN, self._edgeArrowN = 0, 0
    end
    function tf:HideUnusedEdges()
        for i = self._edgeLineN + 1, #self.edgeLinePool do self.edgeLinePool[i]:Hide() end
        for i = self._edgeArrowN + 1, #self.edgeArrowPool do self.edgeArrowPool[i]:Hide() end
    end

    function tf:AcquireGate()
        self._gateN = self._gateN + 1
        local g = self.gatePool[self._gateN]
        if not g then
            g = CreateFrame("Frame", nil, self)
            g:SetSize(124, 28)
            g.icon = g:CreateTexture(nil, "ARTWORK")
            g.icon:SetPoint("RIGHT", g, "RIGHT", 0, 0)
            if g.icon.set_atlas then g.icon:set_atlas("talents-gate", true) end
            g.text = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            g.text:SetPoint("RIGHT", g.icon, "LEFT", -4, 1)
            g.text:SetTextColor(1, 0.64, 0.56)
            self.gatePool[self._gateN] = g
        end
        g:Show()
        return g
    end
    function tf:ResetGates() self._gateN = 0 end
    function tf:HideUnusedGates()
        for i = self._gateN + 1, #self.gatePool do self.gatePool[i]:Hide() end
    end

    return tf
end

-- ============================================================================
-- Background painting (per spec, behind all three trees)
-- ============================================================================
function T.BackgroundNick(tab)
    local unit = (T.IsInspecting and T.IsInspecting() and T.InspectUnit and T.InspectUnit()) or "player"
    local _, classFile = UnitClass(unit)
    local list = T.CLASS_BACKGROUND and T.CLASS_BACKGROUND[classFile]
    return (list and list[tab or 1]) or (list and list[1]) or "talents-background-warrior-arms"
end

function T.SetBackground(tab)
    local f = T.frame
    if not (f and f.bg) then return end
    T._bgTab = tab
    local nick = T.BackgroundNick(tab)
    if f.bg.set_atlas then f.bg:set_atlas(nick, false) end
    if f.bg.SetDesaturated then
        f.bg:SetDesaturated((T._viewGroup or T._activeGroup or 1) ~= (T._activeGroup or 1))
    end
    local atlasinfo = addon.atlasinfo
    local a = atlasinfo and atlasinfo[nick:lower()]
    if not a then return end
    local dw = TALENT_W - CHROME_L - CHROME_R
    local dh = TALENT_H - CHROME_T - CHROME_B - BOTTOMBAR_H
    local destA = dw / dh
    local srcA  = a[2] / a[3]
    local Lc, Rc, Tp, Bp = a[4], a[5], a[6], a[7]
    if destA > srcA then
        Bp = Tp + (Bp - Tp) * (srcA / destA)
    else
        Lc = Rc - (Rc - Lc) * (destA / srcA)
    end
    f.bg:SetTexCoord(Lc, Rc, Tp, Bp)
end

local function classBackgroundNick() return T.BackgroundNick(1) end

-- ============================================================================
-- Build the standalone window
-- ============================================================================
local function buildWindow()
    if T.frame then return T.frame end
    if not addon:IsModuleEnabled("talents") then return nil end

    local f = CreateFrame("Frame", "DragonUI_TalentFrame", UIParent)
    f:SetSize(TALENT_W, TALENT_H)
    f:SetPoint("TOP", UIParent, "TOP", 0, FRAME_TOP_OFFSET)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)

    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()
    T.frame = f
    T.frames.window = f

    local layout = NineSliceUtils.GetLayout("PortraitFrameTemplate")
    if layout then
        NineSliceUtils.ApplyLayout(f, layout)
    end

    do
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if _G.SystemFont_Shadow_Large2 then title:SetFontObject(_G.SystemFont_Shadow_Large2) end
        title:SetPoint("TOP", f, "TOP", 0, -5)
        title:SetText(TALENTS or L["Talents"] or "Talents")
        title:SetTextColor(1, 0.82, 0)
        f._title = title
    end

    do
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
        close:SetSize(24, 24)
        local nt = close:GetNormalTexture()
        if nt then
            nt:SetTexture(addon._dir .. "UI\\redbutton2x")
            nt:SetTexCoord(0.152344, 0.292969, 0.0078125, 0.304688)
            nt:SetSize(24, 24)
        end
        local pt = close:GetPushedTexture()
        if pt then
            pt:SetTexture(addon._dir .. "UI\\redbutton2x")
            pt:SetTexCoord(0.152344, 0.292969, 0.320312, 0.617188)
            pt:SetSize(24, 24)
        end
    end

    do
        local ringFrame = f.NineSlice or f
        f.portrait = ringFrame:CreateTexture(nil, "ARTWORK")
        f.portrait:SetSize(60, 60)
        f.portrait:SetPoint("TOPLEFT", ringFrame, "TOPLEFT", -5, 8)
        f.portrait:SetTexture("Interface\\Icons\\Ability_Marksmanship")
    end

    do
        local tint = f:CreateTexture(nil, "BACKGROUND")
        if tint.SetColorTexture then
            tint:SetColorTexture(0.04, 0.04, 0.05, 1)
        else
            tint:SetTexture("Interface\\Buttons\\WHITE8X8")
            tint:SetVertexColor(0.04, 0.04, 0.05, 1)
        end
        tint:SetPoint("TOPLEFT", CHROME_L, -CHROME_T)
        tint:SetPoint("BOTTOMRIGHT", -CHROME_R, CHROME_B)
        f.bgTint = tint
    end

    do
        local bg = f:CreateTexture(nil, "BORDER")
        bg:SetPoint("TOPLEFT", CHROME_L, -CHROME_T)
        bg:SetPoint("BOTTOMRIGHT", -CHROME_R, CHROME_B + BOTTOMBAR_H)
        if bg.set_atlas then bg:set_atlas(classBackgroundNick(), false) end
        f.bg = bg
    end
    pcall(T.SetBackground, 1)

    do
        local bar = f:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", CHROME_L, CHROME_B)
        bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CHROME_R, CHROME_B)
        bar:SetHeight(BOTTOMBAR_H)
        if bar.set_atlas then bar:set_atlas("talents-background-bottombar", false) end
        f.bottomBar = bar
    end

    f.trees = {}
    local treesBlockW = 3 * TREE_W + 2 * TREE_GAP
    local treesLeft   = (TALENT_W - treesBlockW) / 2
    for i = 1, 3 do
        local tf = CreateTreeFrame(f, i)
        tf:SetPoint("TOPLEFT", f, "TOPLEFT",
            treesLeft + (i - 1) * (TREE_W + TREE_GAP),
            -(INSET_T + TREE_Y_SHIFT))
        f.trees[i] = tf
    end

    tinsert(UISpecialFrames, "DragonUI_TalentFrame")

    f:HookScript("OnShow", function()
        if T.BuildSearchBox then T.BuildSearchBox() end
        if T.Populate then pcall(T.Populate) end
        if T.GlyphsEnsureUI then pcall(T.GlyphsEnsureUI) end
        if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
        if T.GlyphsApplyPaneVisibility then pcall(T.GlyphsApplyPaneVisibility) end
    end)

    f:HookScript("OnHide", function()
        if T.ClearInspect then pcall(T.ClearInspect) end
    end)

    return f
end
T.Build = buildWindow

-- ============================================================================
-- Content root (Host)
-- ============================================================================
function T.Host()
    if T.host then return T.host end
    local f = T.frame or buildWindow()
    if not f then return nil end
    local host = CreateFrame("Frame", "DragonUI_TalentHost", f)
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", f, "TOPLEFT", CHROME_L, -CHROME_T)
    host:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CHROME_R, CHROME_B)
    host:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    T.host = host
    T.frames.host = host
    return host
end

-- ============================================================================
-- Level gate
-- ============================================================================
local TALENT_MIN_LEVEL = SHOW_TALENT_LEVEL or 10
T.MIN_LEVEL = TALENT_MIN_LEVEL

function T.IsUnlocked()
    return (UnitLevel("player") or 0) >= TALENT_MIN_LEVEL
end

local function refuseIfLocked()
    if T.IsUnlocked() then return false end
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(
            format(FEATURE_BECOMES_AVAILABLE_AT_LEVEL or "This feature becomes available at level %d.",
                   TALENT_MIN_LEVEL), 1.0, 0.1, 0.1, 1.0)
    end
    return true
end
T.RefuseIfLocked = refuseIfLocked

-- ============================================================================
-- Show / hide / toggle
-- ============================================================================
function T.SetShown(shown)
    if shown and refuseIfLocked() then return end
    local f = T.frame or buildWindow()
    if not f then return end
    if shown then f:Show() else f:Hide() end
end
function T.Open()  T.SetShown(true)  end
function T.Close() T.SetShown(false) end
function T.Toggle()
    if not (T.frame and T.frame:IsShown()) and refuseIfLocked() then return end
    local f = T.frame or buildWindow()
    if not f then return end
    if f:IsShown() then f:Hide() else f:Show() end
end

-- ============================================================================
-- Inspect mode
-- ============================================================================
function T.ShowInspect(unit)
    if not unit or not UnitExists(unit) then return end
    local f = T.frame or buildWindow()
    if not f then return end
    T._inspectUnit = unit
    T._petView = false
    if T.GlyphsSetActive then T.GlyphsSetActive(false) end
    if not f._inspectHooked then
        f._inspectHooked = true
        f:HookScript("OnHide", function() if T.ClearInspect then T.ClearInspect() end end)
    end
    local who = (GetUnitName and GetUnitName(unit, true)) or UnitName(unit) or ""
    if f._title then f._title:SetText(who) end
    if not f:IsShown() then f:Show() else if T.Populate then T.Populate() end end
end

-- INSPECT_TALENT_READY fills data after the first paint
if not T.registeredEvents["INSPECT_TALENT_READY"] then
    T.registeredEvents["INSPECT_TALENT_READY"] = true
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("INSPECT_TALENT_READY")
    ev:SetScript("OnEvent", function()
        if not T.applied then return end
        if T.IsInspecting and T.IsInspecting() and T.Refresh then T.Refresh() end
    end)
end

function T.ClearInspect()
    local f = T.frame
    T._inspectUnit = nil
    if not f then return end
    if f._title then f._title:SetText(TALENTS or L["Talents"] or "Talents") end
    if f.portrait then f.portrait:SetTexture("Interface\\Icons\\Ability_Marksmanship") end
end

function T.OpenGlyphTab()
    if not (T.frame and T.frame:IsShown()) and refuseIfLocked() then return end
    local f = T.frame or buildWindow()
    if not f then return end
    if type(HideUIPanel) == "function" then
        pcall(HideUIPanel, _G.PlayerTalentFrame)
        pcall(HideUIPanel, _G.GlyphFrame)
    end
    if not f:IsShown() then f:Show() end
    T._petView = false
    if T.GlyphsSetActive then T.GlyphsSetActive(true) end
    if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
    if T.GlyphsApplyPaneVisibility then pcall(T.GlyphsApplyPaneVisibility) end
    if T.RefreshSpecTabs then pcall(T.RefreshSpecTabs) end
end

-- ============================================================================
-- Blizzard reroute (ToggleTalentFrame + TalentMicroButton)
-- ============================================================================
local function interceptBlizzard()
    if not addon:IsModuleEnabled("talents") then return end

    if type(ToggleTalentFrame) == "function" and not T.hooks["ToggleTalentFrame"] then
        local orig = ToggleTalentFrame
        ToggleTalentFrame = function(...)
            if T.applied then
                T.Toggle()
            elseif orig then
                return orig(...)
            end
        end
        T.hooks["ToggleTalentFrame"] = orig
    end

    if TalentMicroButton and TalentMicroButton.SetScript and not T.hooks["TalentMicroButton"] then
        TalentMicroButton:SetScript("OnClick", function()
            if T.applied then T.Toggle() end
        end)
        T.hooks["TalentMicroButton"] = true
    end
end

-- ============================================================================
-- Slash command
-- ============================================================================
_G.SLASH_DRAGONUI_TALENTS1 = "/talents"
SlashCmdList["DRAGONUI_TALENTS"] = function()
    if addon:IsModuleEnabled("talents") then T.Toggle() end
end

-- ============================================================================
-- Module lifecycle + registry registration
-- ============================================================================
local function IsModuleEnabled()
    return addon:IsModuleEnabled("talents")
end

-- Build is deferred until the first world enter so the bag art and host exist
-- before the registry's load-once Apply can run at ADDON_LOADED.
local function ApplyTalents()
    if T.applied then return end
    if not IsModuleEnabled() then return end
    if not T.enteredWorld then return end
    T.applied = true
    if T.Build then T.Build() end
    if T.Host  then T.Host()  end
end

local function RestoreTalents() end

local function RefreshTalents()
    if not T.applied then ApplyTalents() end
    if T.Refresh then T.Refresh() end
end

function addon.ApplyTalentSystem()  ApplyTalents()   end
function addon.RestoreTalentSystem() RestoreTalents() end
function addon.RefreshTalentSystem() RefreshTalents() end

if addon.RegisterModule then
    addon:RegisterModule("talents", T, L["Talents"] or "Talents",
        L["Retail-style talent window"], { loadOnce = true })
end

-- ============================================================================
-- Bootstrap (deferred to PLAYER_ENTERING_WORLD)
-- ============================================================================
local booted = false
local boot = CreateFrame("Frame")
T.registeredEvents["PLAYER_ENTERING_WORLD"] = true
T.registeredEvents["ADDON_LOADED"] = true
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        if booted then return end
        booted = true
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        T.enteredWorld = true
        T.initialized = true
        ApplyTalents()
        if T.ApplyTierDepth then pcall(T.ApplyTierDepth) end
        if T.BuildWarmodeButton and T.frame then pcall(T.BuildWarmodeButton, T.frame) end
        interceptBlizzard()
    elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_TalentUI" or arg1 == "Blizzard_GlyphUI") then
        interceptBlizzard()
    end
end)
