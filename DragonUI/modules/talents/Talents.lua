-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

T.initialized = T.initialized or false
T.applied = T.applied or false

local TEX = addon._dir .. "Talents\\"
local FRAME_NAME = "DragonUI_TalentFrame"

T.CLASS_BACKGROUND = {
    WARRIOR     = { "talents-background-warrior-arms",        "talents-background-warrior-fury",        "talents-background-warrior-protection" },
    PALADIN     = { "talents-background-paladin-holy",        "talents-background-paladin-protection",  "talents-background-paladin-retribution" },
    HUNTER      = { "talents-background-hunter-beastmastery", "talents-background-hunter-marksmanship", "talents-background-hunter-survival" },
    ROGUE       = { "talents-background-rogue-assassination", "talents-background-rogue-outlaw",        "talents-background-rogue-subtlety" },
    PRIEST      = { "talents-background-priest-discipline",   "talents-background-priest-holy",         "talents-background-priest-shadow" },
    SHAMAN      = { "talents-background-shaman-elemental",    "talents-background-shaman-enhancement",  "talents-background-shaman-restoration" },
    MAGE        = { "talents-background-mage-arcane",         "talents-background-mage-fire",           "talents-background-mage-frost" },
    WARLOCK     = { "talents-background-warlock-affliction",  "talents-background-warlock-demonology",  "talents-background-warlock-destruction" },
    DRUID       = { "talents-background-druid-balance",       "talents-background-druid-feral",         "talents-background-druid-restoration" },
    DEATHKNIGHT = { "talents-background-deathknight-blood",   "talents-background-deathknight-frost",   "talents-background-deathknight-unholy" },
}

-- ============================================================================
-- Layout
-- ============================================================================
local NODE = 36
local SQUARE_NODE_FIT = 56 / 64
local CAPSTONE_SQUARE_SIZE = 56
local APEX_SIZE = NODE + 48
local APEX_ICON = 66
-- New Era's layout compacted to sit at scale 1 beside DragonUI's other panels on 3.3.5a's 768-unit screen.
local PITCH_X, PITCH_Y = 64, 46
-- Regular nodes draw at retail's ~40; the capstone art already has its own large footprint.
local NODE_SCALE = 1.12
local LAST_TIER_EXTRA = 28
local COLS = 4
-- 11 rows only fit that screen at a hair under full size, so the trees alone draw at 0.95.
local TREE_SCALE = 0.95
local TREE_GAP = 130
local HEADER_H = 28
local BOTTOMBAR_H = 80
local TREE_TOP = 46
local APEX_CLEAR = 8
local CHROME_T = 22
local FILL_T, FILL_B, FILL_L, FILL_R = 21, 2, 2, 2
local HEADER_CENTER_Y = ((TREE_TOP - CHROME_T) / TREE_SCALE - HEADER_H) / 2
local TREE_W = (COLS - 1) * PITCH_X + NODE
local TALENT_W = 1120
local tiers = 11

local function treeHeight()
    return HEADER_H + (tiers - 1) * PITCH_Y + NODE + LAST_TIER_EXTRA
end

local function frameHeight()
    local tree = NODE / 2 + HEADER_H + (tiers - 1) * PITCH_Y + LAST_TIER_EXTRA + APEX_SIZE / 2
    return math.floor(TREE_TOP + tree * TREE_SCALE + APEX_CLEAR + BOTTOMBAR_H + 0.5)
end

local function nodeCenter(tier, column)
    local x = (column - 1) * PITCH_X + NODE / 2
    local extra = (tier == tiers) and LAST_TIER_EXTRA or 0
    local y = -((tier - 1) * PITCH_Y) - NODE / 2 - HEADER_H - extra - (T._nodeYShift or 0)
    return x, y
end

T.nodeCenter = nodeCenter
T.LAYOUT = { NODE = NODE, PITCH_Y = PITCH_Y, TREE_W = TREE_W, TREE_TOP = TREE_TOP, HEADER_CENTER_Y = HEADER_CENTER_Y,
    TREE_SCALE = TREE_SCALE, NODE_SCALE = NODE_SCALE }
T.FRAME = { W = TALENT_W, CHROME_T = CHROME_T, BOTTOMBAR_H = BOTTOMBAR_H }

function T.Tiers() return tiers end

local function bgSize()
    return TALENT_W, frameHeight() - CHROME_T - BOTTOMBAR_H
end

-- ============================================================================
-- Nodes
-- ============================================================================
local HOVER_ALPHA = { yellow = 1, green = 1, gray = 0.4, locked = 0.4 }
local SHEEN_ALPHA = { yellow = 1, gray = 1, locked = 1 }
local SHEEN_SMALL = TEX .. "talents-sheen-small"
local SHEEN_CAPSQ, SHEEN_APEX = TEX .. "talents-sheen-capstonesquare", TEX .. "talents-sheen-apex"
local SHEEN_FRAMES = 32
-- New Era's talents-sheen-node x sheenmask, baked per shape over the offsets where it lights the ring.
local SHEEN = {
    square = { tex = SHEEN_SMALL, w = 1024, h = 256, x0 = 0, y0 = 0, cell = 60, stride = 64, cols = 8,
               size = 50.4, omin = 24, omax = 80.75 },
    circle = { tex = SHEEN_SMALL, w = 1024, h = 256, x0 = 512, y0 = 0, cell = 60, stride = 64, cols = 8,
               size = 57.6, omin = 30, omax = 84.5 },
    capstonesquare = { tex = SHEEN_CAPSQ, w = 1024, h = 512, x0 = 0, y0 = 0, cell = 92, stride = 96, cols = 10,
                       size = 89.6, omin = 28.75, omax = 129.5 },
    capstone = { tex = SHEEN_APEX, w = 1024, h = 512, x0 = 0, y0 = 0, cell = 124, stride = 128, cols = 8,
                 size = 108, omin = 55.5, omax = 163.75 },
}

local function hideSheen(n)
    if not n._sheenOn then return end
    n.sheenA:Hide()
    n.sheenB:Hide()
    n._sheenOn = false
end

local function ringAtlas(shape, state)
    return (T.SHAPE_ATLAS[shape] or "talents-node-square") .. "-" .. state
end

local function shadowAtlas(shape)
    return (shape == "circle") and "talents-node-circle-shadow" or "talents-node-square-shadow"
end

local function glowAtlas(shape)
    if shape == "capstone" then return "talents-node-apex-large-glow" end
    return (shape == "circle") and "talents-node-circle-greenglow" or "talents-node-square-greenglow"
end

local function createNode(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NODE, NODE)

    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetPoint("CENTER")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")

    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetPoint("CENTER")

    b.hover = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.hover:SetPoint("CENTER")
    b.hover:SetBlendMode("ADD")
    b.hover:Hide()

    -- Two neighbouring frames of the baked sweep, cross-faded so the glint glides instead of stepping.
    b.sheenA = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.sheenB = b:CreateTexture(nil, "OVERLAY", nil, 1)
    for _, s in ipairs({ b.sheenA, b.sheenB }) do
        s:SetPoint("CENTER")
        s:SetBlendMode("ADD")
        s:Hide()
    end

    b.glow = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.glow:SetPoint("CENTER")
    b.glow:SetBlendMode("ADD")
    b.glow:SetAlpha(0)
    b.glow:Hide()
    b.glowAnim = b.glow:CreateAnimationGroup()
    b.glowAnim:SetLooping("REPEAT")
    local gIn = b.glowAnim:CreateAnimation("Alpha")
    gIn:SetChange(0.15); gIn:SetDuration(1); gIn:SetOrder(1); gIn:SetSmoothing("OUT")
    local gOut = b.glowAnim:CreateAnimation("Alpha")
    gOut:SetChange(-0.15); gOut:SetDuration(1); gOut:SetOrder(2); gOut:SetSmoothing("IN")

    b.rank = b:CreateFontString(nil, "OVERLAY")
    b.rank:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
    b.rank:SetShadowOffset(1, -1)
    b.rank:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)

    function b:SetVisual(shape, state, iconTex, rankText)
        self:SetScale((shape == "capstone" or shape == "capstonesquare") and 1 or NODE_SCALE)
        local base
        if shape == "capstone" then
            base = APEX_SIZE
        elseif shape == "capstonesquare" then
            base = CAPSTONE_SQUARE_SIZE
        elseif shape == "square" then
            base = NODE * SQUARE_NODE_FIT
        else
            base = NODE
        end
        local squareArt = (shape == "square") or (shape == "capstonesquare")
        local sc = base / 40
        self._shape, self._base = shape, base
        -- The button stays NODE-sized so every shape shares one anchor; the apex needs a bigger hit box.
        local pad = (NODE - base) / 2
        self:SetHitRectInsets(pad, pad, pad, pad)

        self.ring:SetSize(base, base)
        self.ring:set_atlas(ringAtlas(shape, state))
        self.hover:SetSize(base, base)
        self.hover:set_atlas(ringAtlas(shape, state))
        self._hoverAlpha = HOVER_ALPHA[state] or 1
        self.hover:SetAlpha(self._hoverAlpha)
        self.hover:Hide()

        local shN = (shape == "circle") and 76 or 78
        self.shadow:SetSize(shN * sc, shN * sc)
        self.shadow:set_atlas(shadowAtlas(shape))

        -- No mask textures in 3.3.5a: SetPortraitToTexture is the only way to get a round icon.
        local iconKey = (iconTex or "") .. (squareArt and "#sq" or "#round")
        if self._iconKey ~= iconKey then
            self._iconKey = iconKey
            self.icon:SetTexCoord(0, 1, 0, 1)
            if squareArt or not iconTex then
                self.icon:SetTexture(iconTex)
            else
                SetPortraitToTexture(self.icon, iconTex)
            end
        end
        -- The apex ring is opaque from r26.5 to r33.5 (of 84); at 66px even thick icon bevels end under it.
        local iconSize = (shape == "capstone") and APEX_ICON or base
        self.icon:SetSize(iconSize, iconSize)
        local dim = (state == "gray" or state == "locked")
        self.icon:SetDesaturated(dim)
        local tint = dim and 0.65 or 1
        self.icon:SetVertexColor(tint, tint, tint)

        local sheen = SHEEN[shape] or SHEEN.square
        if self._sheen ~= sheen then
            self._sheen = sheen
            for _, s in ipairs({ self.sheenA, self.sheenB }) do
                s:SetTexture(sheen.tex)
                s:SetSize(sheen.size, sheen.size)
            end
        end
        self._wantSheen = SHEEN_ALPHA[state] ~= nil
        if not self._wantSheen then hideSheen(self) end

        if state == "green" then
            self.glow:SetSize(base + 22, base + 22)
            self.glow:set_atlas(glowAtlas(shape))
            self.glow:Show()
            if not self.glowAnim:IsPlaying() then self.glowAnim:Play() end
        else
            self.glowAnim:Stop()
            self.glow:Hide()
        end

        self.rank:SetText(rankText or "")
        if state == "green" then
            self.rank:SetTextColor(0.1, 1, 0.1)
        elseif dim then
            self.rank:SetTextColor(0.6, 0.6, 0.6)
        else
            self.rank:SetTextColor(1, 0.82, 0)
        end
    end

    -- Anchor offsets are read in the node's own scale.
    function b:PlaceAt(tree, x, y)
        local s = self:GetScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", tree, "TOPLEFT", x / s, y / s)
    end

    function b:ShowHover()
        if (self._hoverAlpha or 0) > 0 then self.hover:Show() end
    end

    function b:HideHover()
        self.hover:Hide()
    end

    return b
end
T.CreateNode = createNode

-- ============================================================================
-- Tree frames
-- ============================================================================
-- UI-Taxi-Line's core is near-black, so tinted edges read dark; this one has a white core.
local EDGE_LINE = TEX .. "talents-line"
T.EDGE_LINE = EDGE_LINE
local ARROWS = TEX .. "talents-arrows"

local function createTreeFrame(parent, index)
    local tf = CreateFrame("Frame", nil, parent)
    tf:SetSize(TREE_W, treeHeight())
    tf.index = index

    tf.headerName = tf:CreateFontString(nil, "OVERLAY")
    tf.headerName:SetFont(STANDARD_TEXT_FONT, 16)
    tf.headerName:SetShadowOffset(1, -1)
    tf.headerName:SetTextColor(1, 1, 1)
    tf.headerName:SetPoint("CENTER", tf, "TOP", 0, HEADER_CENTER_Y)

    tf.headerPts = tf:CreateFontString(nil, "OVERLAY")
    tf.headerPts:SetFont(STANDARD_TEXT_FONT, 16)
    tf.headerPts:SetShadowOffset(1, -1)
    tf.headerPts:SetPoint("LEFT", tf.headerName, "RIGHT", 6, 0)

    tf.nodePool, tf.edgePool = {}, {}
    tf._edgeN = 0

    function tf:AcquireNode(idx)
        local n = self.nodePool[idx]
        if not n then
            n = createNode(self)
            n:SetFrameLevel(self:GetFrameLevel() + 1)
            self.nodePool[idx] = n
        end
        return n
    end

    function tf:HideUnusedNodes(used)
        for idx, n in pairs(self.nodePool) do
            if not used[idx] then n:Hide() end
        end
    end

    function tf:AcquireEdge()
        self._edgeN = self._edgeN + 1
        local e = self.edgePool[self._edgeN]
        if not e then
            local line = self:CreateTexture(nil, "ARTWORK", nil, -2)
            line:SetTexture(EDGE_LINE)
            local arrow = self:CreateTexture(nil, "ARTWORK", nil, -1)
            arrow:SetTexture(ARROWS)
            arrow:SetSize(32, 32)
            e = { line = line, arrow = arrow }
            self.edgePool[self._edgeN] = e
        end
        e.line:Show()
        e.arrow:Show()
        return e
    end

    function tf:ResetEdges() self._edgeN = 0 end

    function tf:HideUnusedEdges()
        for i = self._edgeN + 1, #self.edgePool do
            self.edgePool[i].line:Hide()
            self.edgePool[i].arrow:Hide()
        end
    end

    return tf
end
T.CreateTreeFrame = createTreeFrame

-- Arrowhead cells are 64px with the art centred, so rotating the square never samples the other cell.
function T.SetArrow(tex, active, angle)
    local cellX = active and 0 or 64
    local c, s = math.cos(angle), math.sin(angle)
    local function corner(qx, qy)
        local rx = qx * c + qy * s
        local ry = -qx * s + qy * c
        return (cellX + 32 + rx) / 128, (32 - ry) / 64
    end
    local ulx, uly = corner(-32, 32)
    local llx, lly = corner(-32, -32)
    local urx, ury = corner(32, 32)
    local lrx, lry = corner(32, -32)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- ============================================================================
-- Background
-- ============================================================================
function T.BackgroundNick(tab, classFile)
    classFile = classFile or select(2, UnitClass("player"))
    local list = T.CLASS_BACKGROUND[classFile]
    return (list and (list[tab or 1] or list[1])) or "talents-background-warrior-arms"
end

-- Cover-crop: keep the top and the right, where the spec art puts its subject.
function T.SetBackground(tab, classFile, desaturate)
    local f = T.frame
    if not (f and f.bg) then return end
    local nick = T.BackgroundNick(tab, classFile)
    f.bg:set_atlas(nick)
    f.bg:SetDesaturated(desaturate and true or false)
    local a = addon.atlasinfo[nick]
    if not a then return end
    local dw, dh = bgSize()
    local destA, srcA = dw / dh, a[2] / a[3]
    local l, r, t, b = a[4], a[5], a[6], a[7]
    if destA > srcA then
        b = t + (b - t) * (srcA / destA)
    else
        l = r - (r - l) * (destA / srcA)
    end
    f.bg:SetTexCoord(l, r, t, b)
end

-- ============================================================================
-- Ambient background FX
-- ============================================================================
-- Clipped by cropping each layer's texcoords to the window: a ScrollFrame of animations froze drags.
local FX_FADE = 5
local FX_LAYERS = {
    { atlas = "talents-animations-clouds", alpha = 0.05, cover = true, dur = 80, offset = 0 },
    { atlas = "talents-animations-clouds", alpha = 0.05, cover = true, dur = 80, offset = 1 },
    { atlas = "talents-animations-particles", w = 1308, h = 774, startX = 300, driftX = -600, dur = 27,
      peak = 0.149, fadeOut = 22 },
    { atlas = "talents-animations-particles", w = 800, h = 473, flip = true, startX = 100, driftX = -200, dur = 36,
      peak = 0.137, fadeOut = 31 },
}

local function placeLayer(fx, tex, layer, x, y, lw, lh, W, H)
    local x0, y0 = math.max(0, x), math.max(0, y)
    local x1, y1 = math.min(W, x + lw), math.min(H, y + lh)
    if x1 - x0 < 1 or y1 - y0 < 1 then
        tex:Hide()
        return
    end
    local a = addon.atlasinfo[layer.atlas]
    local l, r, t, b = a[4], a[5], a[6], a[7]
    if layer.flip then l, r = r, l end
    local du, dv = (r - l) / lw, (b - t) / lh
    tex:SetTexCoord(l + (x0 - x) * du, l + (x1 - x) * du, t + (y0 - y) * dv, t + (y1 - y) * dv)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", fx, "TOPLEFT", x0, -y0)
    tex:SetSize(x1 - x0, y1 - y0)
    tex:Show()
end

local function stepAmbientFX(fx, elapsed)
    fx.t = fx.t + elapsed
    local W, H = fx.w, fx.h
    if not W then return end
    for i, layer in ipairs(FX_LAYERS) do
        local tex = fx.layers[i]
        local phase = (fx.t % layer.dur) / layer.dur
        if layer.cover then
            placeLayer(fx, tex, layer, (layer.offset - phase) * W, 0, W, H, W, H)
        else
            local lt = fx.t % layer.dur
            local alpha
            if lt < layer.fadeOut then
                alpha = layer.peak * math.min(1, lt / FX_FADE)
            else
                alpha = layer.peak * math.max(0, 1 - (lt - layer.fadeOut) / FX_FADE)
            end
            tex:SetAlpha(alpha)
            local cx = W / 2 + layer.startX + layer.driftX * phase
            placeLayer(fx, tex, layer, cx - layer.w / 2, (H - layer.h) / 2, layer.w, layer.h, W, H)
        end
    end
end

local function buildAmbientFX(f)
    local fx = CreateFrame("Frame", nil, f)
    fx:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CHROME_T)
    fx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, BOTTOMBAR_H)
    fx.t, fx.layers = 0, {}
    for i, layer in ipairs(FX_LAYERS) do
        local tex = fx:CreateTexture(nil, "BORDER", nil, layer.cover and 1 or 2)
        tex:SetTexture(addon.atlasinfo[layer.atlas][1])
        tex:SetBlendMode("ADD")
        tex:SetAlpha(layer.alpha or 0)
        tex:Hide()
        fx.layers[i] = tex
    end
    fx:SetScript("OnUpdate", stepAmbientFX)
    f.fx = fx
end

local function layoutAmbientFX(f)
    if not f.fx then return end
    f.fx.w, f.fx.h = bgSize()
    stepAmbientFX(f.fx, 0)
end

-- ============================================================================
-- Border sheen
-- ============================================================================
local SHEEN_CYCLE, SHEEN_DELAY, SHEEN_DUR = 22.0, 5.0, 6.5
local SHEEN_SPEED = 150 * (NODE / 40) / SHEEN_DUR
local SHEEN_STEP = 1 / 30
local SHEEN_EDGE = 0.12
-- New Era stops at 135px, mid-ring on the apex; each shape instead runs until its streak has left.
local SHEEN_END = 0
for _, v in pairs(SHEEN) do SHEEN_END = math.max(SHEEN_END, v.omax / SHEEN_SPEED) end

local function sheenCell(v, k)
    local pad = (v.stride - v.cell) / 2
    local x = v.x0 + (k % v.cols) * v.stride + pad
    local y = v.y0 + math.floor(k / v.cols) * v.stride + pad
    return x / v.w, (x + v.cell) / v.w, y / v.h, (y + v.cell) / v.h
end

local function paintSheen(n, offset)
    local v = n._sheen
    if not v or offset < v.omin or offset > v.omax then
        hideSheen(n)
        return
    end
    local u = (offset - v.omin) / (v.omax - v.omin)
    local fi = u * (SHEEN_FRAMES - 1)
    local k = math.min(SHEEN_FRAMES - 2, math.floor(fi))
    local f = fi - k
    local env = math.min(1, u / SHEEN_EDGE, (1 - u) / SHEEN_EDGE)
    n.sheenA:SetTexCoord(sheenCell(v, k))
    n.sheenA:SetAlpha((1 - f) * env)
    n.sheenB:SetTexCoord(sheenCell(v, k + 1))
    n.sheenB:SetAlpha(f * env)
    if not n._sheenOn then
        n.sheenA:Show()
        n.sheenB:Show()
        n._sheenOn = true
    end
end

local sheenDriver = CreateFrame("Frame")
sheenDriver:Hide()
local sheenAcc, sheenSweeping = 0, false

local function forEachNode(fn)
    local f = T.frame
    if not (f and f.trees) then return end
    for _, tf in ipairs(f.trees) do
        for _, n in pairs(tf.nodePool) do fn(n) end
    end
end

sheenDriver:SetScript("OnUpdate", function(_, elapsed)
    sheenAcc = sheenAcc + elapsed
    if sheenAcc < SHEEN_STEP then return end
    sheenAcc = 0
    local t = (GetTime() % SHEEN_CYCLE) - SHEEN_DELAY
    if t < 0 or t > SHEEN_END then
        if sheenSweeping then
            sheenSweeping = false
            forEachNode(hideSheen)
        end
        return
    end
    sheenSweeping = true
    local offset = t * SHEEN_SPEED
    forEachNode(function(n)
        if n._wantSheen and n:IsVisible() then
            paintSheen(n, offset)
        else
            hideSheen(n)
        end
    end)
end)

-- ============================================================================
-- Window
-- ============================================================================
local function CP() return addon.CharacterPanel end

-- The HD class icons are edge-to-edge discs: this ends them inside the ring's opaque band.
local PORTRAIT_CIRCLE, PORTRAIT_CIRCLE_X, PORTRAIT_CIRCLE_Y = 57, -3, 6
local PORTRAIT_FACE, PORTRAIT_FACE_X, PORTRAIT_FACE_Y = 58, -3, 7

function T.SetPortraitClass(classFile)
    local p = T.frame and T.frame.portrait
    local c = classFile and CLASS_ICON_TCOORDS[classFile]
    if not (p and c) then return end
    p:ClearAllPoints()
    p:SetSize(PORTRAIT_CIRCLE, PORTRAIT_CIRCLE)
    p:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PORTRAIT_CIRCLE_X, PORTRAIT_CIRCLE_Y)
    p:SetTexture(addon._dir .. "ClassIcons\\" .. classFile)
    p:SetTexCoord(0, 1, 0, 1)
end

function T.SetPortraitUnit(unit)
    local p = T.frame and T.frame.portrait
    if not p then return end
    p:ClearAllPoints()
    p:SetSize(PORTRAIT_FACE, PORTRAIT_FACE)
    p:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PORTRAIT_FACE_X, PORTRAIT_FACE_Y)
    -- The class icon leaves a sub-rect texcoord behind and SetPortraitTexture does not reset it.
    p:SetTexCoord(0, 1, 0, 1)
    SetPortraitTexture(p, unit)
end

function T.SetTitle(text)
    if T.frame and T.frame.title then T.frame.title:SetText(text or TALENTS) end
end

local SCALE_MIN, SCALE_MAX = 0.5, 1.5
local FIT_MARGIN = 8
-- The tab row hangs this far below the frame; the fit and the drag clamp both count it.
local TABS_BELOW = 34

-- A plain scale on top of the UI scale like DragonUI's other panels, with retail's checkFit on top.
local function wantedScale()
    local p = addon.db and addon.db.profile and addon.db.profile.talents
    local s = math.max(SCALE_MIN, math.min(SCALE_MAX, tonumber(p and p.scale) or 1))
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if w and h and w > 0 and h > 0 then
        local tall = frameHeight() + TABS_BELOW
        s = math.min(s, (w - 2 * FIT_MARGIN) / TALENT_W, (h - 2 * FIT_MARGIN) / tall)
    end
    return s
end

-- Centred with its tab row: the tabs hang below the frame, so the pair's middle sits half a tab row higher.
local function placeDefault(f)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, TABS_BELOW / 2)
end

-- Scales about the top edge: a window the player dragged stays where it is while the slider moves.
function T.ApplyScale()
    local f = T.frame
    if not f then return end
    local scale = wantedScale()
    if math.abs(f:GetScale() - scale) < 0.001 then
        if not f._duiMoved then placeDefault(f) end
        return
    end
    if not f._duiMoved then
        f:SetScale(scale)
        placeDefault(f)
        if T.PlacePvPCatcher then T.PlacePvPCatcher() end
        return
    end
    local x, top = f:GetCenter(), f:GetTop()
    local old = f:GetEffectiveScale()
    f:SetScale(scale)
    if x and top then
        local k = old / f:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("TOP", UIParent, "BOTTOMLEFT", x * k, top * k)
    end
    if T.PlacePvPCatcher then T.PlacePvPCatcher() end
end

-- The bottom metal is opaque only ~3px inside the frame edge; its shadow below would let the bar through.
local BAR_TUCK_X, BAR_TUCK_B = 2, 3

-- Crops the art instead of squeezing it, so the tucked bar keeps its scale.
local function tuckBar(tex, atlas, outerLeft)
    tex:set_atlas(atlas)
    local a = addon.atlasinfo[atlas]
    local l, r, t, b = a[4], a[5], a[6], a[7]
    local dx = (r - l) * BAR_TUCK_X / (TALENT_W / 2)
    if outerLeft then l = l + dx else r = r - dx end
    tex:SetTexCoord(l, r, t, b - (b - t) * BAR_TUCK_B / BOTTOMBAR_H)
end

local function buildWindow()
    if T.frame then return T.frame end

    local f = CreateFrame("Frame", FRAME_NAME, UIParent)
    f:SetSize(TALENT_W, frameHeight())
    f:SetPoint("CENTER", UIParent, "CENTER", 0, TABS_BELOW / 2)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetClampRectInsets(0, 0, 0, -TABS_BELOW)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._duiMoved = true
    end)
    f:Hide()
    T.frame = f
    f:SetScale(wantedScale())
    local base = f:GetFrameLevel()

    f.bgTint = f:CreateTexture(nil, "BACKGROUND", nil, -3)
    f.bgTint:SetTexture(0.04, 0.04, 0.05, 1)
    f.bgTint:SetPoint("TOPLEFT", f, "TOPLEFT", FILL_L, -FILL_T)
    f.bgTint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -FILL_R, FILL_B)

    f.bg = f:CreateTexture(nil, "BORDER")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CHROME_T)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, BOTTOMBAR_H)
    T.SetBackground(1)

    buildAmbientFX(f)
    f.fx:SetFrameLevel(base + 1)

    f.trees = {}
    for i = 1, 3 do
        local tf = createTreeFrame(f, i)
        tf:SetFrameLevel(base + 3)
        tf:SetScale(TREE_SCALE)
        local w = TREE_W * TREE_SCALE
        tf._x = (TALENT_W - (3 * w + 2 * TREE_GAP)) / 2 + (i - 1) * (w + TREE_GAP)
        -- Anchor offsets are read in the anchored frame's own scale.
        tf:SetPoint("TOPLEFT", f, "TOPLEFT", tf._x / TREE_SCALE, -TREE_TOP / TREE_SCALE)
        f.trees[i] = tf
    end

    -- Child frames draw above their parent's own regions, so the footer lives above the FX and trees.
    f.barFrame = CreateFrame("Frame", nil, f)
    f.barFrame:SetFrameLevel(base + 6)
    f.barFrame:SetHeight(BOTTOMBAR_H)
    f.barFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.barFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    -- Two halves: the whole 1612px bar would need a 2048-wide sheet, and the client crashes on that one.
    f.bottomBar = f.barFrame:CreateTexture(nil, "ARTWORK")
    f.bottomBar:SetPoint("TOPLEFT", f.barFrame, "TOPLEFT", BAR_TUCK_X, 0)
    f.bottomBar:SetPoint("BOTTOMRIGHT", f.barFrame, "BOTTOM", 0, BAR_TUCK_B)
    tuckBar(f.bottomBar, "talents-background-bottombar-left", true)
    f.bottomBarRight = f.barFrame:CreateTexture(nil, "ARTWORK")
    f.bottomBarRight:SetPoint("TOPLEFT", f.barFrame, "TOP")
    f.bottomBarRight:SetPoint("BOTTOMRIGHT", f.barFrame, "BOTTOMRIGHT", -BAR_TUCK_X, BAR_TUCK_B)
    tuckBar(f.bottomBarRight, "talents-background-bottombar-right", false)

    -- The metal has to frame the footer too, so it cannot be painted on f itself.
    f.chrome = CreateFrame("Frame", nil, f)
    f.chrome:SetAllPoints(f)
    f.chrome:SetFrameLevel(base + 8)
    local layout = NineSliceUtils and NineSliceUtils.GetLayout("PortraitFrameTemplate")
    if layout then NineSliceUtils.ApplyLayout(f.chrome, layout) end

    -- ARTWORK, under the OVERLAY corner piece whose cutout rings it.
    f.portrait = f.chrome:CreateTexture(nil, "ARTWORK")
    T.SetPortraitClass(select(2, UnitClass("player")))

    -- Retail's title band runs from the portrait (+58) to the close button (-24), not edge to edge.
    f.title = f.chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -6)
    f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -6)
    f.title:SetJustifyH("CENTER")
    f.title:SetText(TALENTS)

    f.close = CreateFrame("Button", FRAME_NAME .. "CloseButton", f, "UIPanelCloseButton")
    f.close:SetFrameLevel(base + 9)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 0)
    if CP() and CP().ModernizeCloseButton then CP().ModernizeCloseButton(f.close, f, 1, 0) end

    -- Tabs are levelled off their parent, so they need one that sits above the metal.
    f.tabHolder = CreateFrame("Frame", nil, f)
    f.tabHolder:SetAllPoints(f)
    f.tabHolder:SetFrameLevel(base + 8)

    tinsert(UISpecialFrames, FRAME_NAME)

    layoutAmbientFX(f)

    for _, builder in ipairs(T._builders or {}) do builder(f) end

    f:HookScript("OnShow", function()
        T.ApplyScale()
        sheenDriver:Show()
        PlaySound("TalentScreenOpen")
        SetButtonPulse(TalentMicroButton, 0, 1)
        UpdateMicroButtons()
    end)
    f:HookScript("OnHide", function()
        sheenDriver:Hide()
        if sheenSweeping then
            sheenSweeping = false
            forEachNode(hideSheen)
        end
        PlaySound("TalentScreenClose")
        UpdateMicroButtons()
    end)

    return f
end
T.Build = buildWindow

-- Sub-files register what they add to the window; the frame itself is built once, after login.
function T.OnBuild(fn)
    T._builders = T._builders or {}
    T._builders[#T._builders + 1] = fn
end

-- Custom servers can ship shallower trees; the window follows the deepest tier the class really uses.
function T.SetTierDepth(depth)
    depth = tonumber(depth)
    if not depth or depth < 1 or depth == tiers then return end
    tiers = depth
    T.CAPSTONE_TIER = depth
    local f = T.frame
    if not f then return end
    f:SetSize(TALENT_W, frameHeight())
    for _, tf in ipairs(f.trees) do tf:SetSize(TREE_W, treeHeight()) end
    layoutAmbientFX(f)
end

-- ============================================================================
-- Show / hide
-- ============================================================================
function T.IsUnlocked()
    return (UnitLevel("player") or 0) >= SHOW_TALENT_LEVEL
end

local function refuseIfLocked(level)
    level = level or SHOW_TALENT_LEVEL
    if (UnitLevel("player") or 0) >= level then return false end
    UIErrorsFrame:AddMessage(format(FEATURE_BECOMES_AVAILABLE_AT_LEVEL, level), 1.0, 0.1, 0.1, 1.0)
    return true
end

function T.IsShown()
    return T.frame ~= nil and T.frame:IsShown()
end

-- Every open starts on the active spec, the way ToggleTalentFrame passes GetActiveTalentGroup().
local function openFresh()
    T._viewGroup = nil
    T.SetPetView(false)
    T.SetGlyphView(false)
end

function T.Open()
    if not T.applied or refuseIfLocked() then return end
    if T._mode == "inspect" then T.ClearInspect() end
    if not T.frame:IsShown() then
        openFresh()
        T.frame:Show()
    end
end

function T.Close()
    if T.frame then T.frame:Hide() end
end

function T.Toggle()
    if not T.applied then return end
    if T.frame:IsShown() and T._mode ~= "inspect" and not T.GlyphViewActive() then
        T.frame:Hide()
        return
    end
    if refuseIfLocked() then return end
    if T._mode == "inspect" then T.ClearInspect() end
    local wasShown = T.frame:IsShown()
    openFresh()
    if wasShown then T.Refresh() else T.frame:Show() end
end

function T.ToggleGlyphs()
    if not T.applied then return end
    if T.frame:IsShown() and T.GlyphViewActive() then
        T.frame:Hide()
        return
    end
    T.OpenGlyphs()
end

function T.OpenGlyphs()
    if not T.applied or refuseIfLocked(SHOW_INSCRIPTION_LEVEL) then return end
    if T._mode == "inspect" then T.ClearInspect() end
    T._viewGroup = nil
    T.SetPetView(false)
    T.SetGlyphView(true)
    if T.frame:IsShown() then T.Refresh() else T.frame:Show() end
end

-- ============================================================================
-- Inspect
-- ============================================================================
function T.ShowInspect(unit)
    if not (T.applied and unit and UnitExists(unit)) then return end
    if T._mode == "edit" and T.ExitEditor then T.ExitEditor() end
    T._mode = "inspect"
    T._inspectUnit = unit
    T.SetPetView(false)
    T.SetGlyphView(false)
    T.SetTitle(GetUnitName(unit, true) or UnitName(unit))
    if T.SetInspectChrome then T.SetInspectChrome(true) end
    if T.frame:IsShown() then T.Refresh() else T.frame:Show() end
end

function T.ClearInspect()
    if T._mode ~= "inspect" then return end
    T._mode = nil
    T._inspectUnit = nil
    T.SetTitle(TALENTS)
    if T.SetInspectChrome then T.SetInspectChrome(false) end
    T.MarkDirty()
end

function T.InspectUnit() return T._inspectUnit end

-- ============================================================================
-- Entry points (no Blizzard global is reassigned)
-- ============================================================================
local toggleButton, bindingOwner

local function applyBindings()
    if InCombatLockdown() then
        T._rebindQueued = true
        return
    end
    T._rebindQueued = nil
    ClearOverrideBindings(bindingOwner)
    for _, key in ipairs({ GetBindingKey("TOGGLETALENTS") }) do
        SetOverrideBindingClick(bindingOwner, false, key, "DragonUI_TalentToggle", "LeftButton")
    end
    for _, key in ipairs({ GetBindingKey("TOGGLEINSCRIPTION") }) do
        SetOverrideBindingClick(bindingOwner, false, key, "DragonUI_TalentToggle", "RightButton")
    end
end

-- Anything that still reaches Blizzard's window (another addon, the trainer's talent wipe) lands on ours.
local function redirectBlizzardFrame()
    local blizz = _G.PlayerTalentFrame
    if not blizz or blizz._duiRedirect then return end
    blizz._duiRedirect = true
    blizz:HookScript("OnShow", function(self)
        -- Next frame: hiding it from inside its own ShowUIPanel re-enters the panel manager.
        addon:After(0, function()
            if not self:IsShown() then return end
            local glyphs = PanelTemplates_GetSelectedTab(self) == GLYPH_TALENT_TAB
            HideUIPanel(self)
            if glyphs then T.OpenGlyphs() else T.Open() end
        end)
    end)
end

local function hookInspectFrame()
    local tab = _G.InspectFrameTab3
    if not tab or tab._duiTalents then return end
    tab._duiTalents = true
    tab:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        if InspectFrame.unit then T.ShowInspect(InspectFrame.unit) end
    end)
    InspectFrame:HookScript("OnHide", function()
        if T._mode == "inspect" then T.Close() end
    end)
    hooksecurefunc("InspectFrame_UnitChanged", function()
        if T._mode == "inspect" and InspectFrame.unit then T.ShowInspect(InspectFrame.unit) end
    end)
end

local function installEntryPoints()
    toggleButton = CreateFrame("Button", "DragonUI_TalentToggle", UIParent)
    toggleButton:RegisterForClicks("AnyUp")
    toggleButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then T.ToggleGlyphs() else T.Toggle() end
    end)
    bindingOwner = CreateFrame("Frame")
    applyBindings()

    -- The micro button's XML binds the original ToggleTalentFrame by value, so it needs its own script.
    TalentMicroButton:SetScript("OnClick", function() T.Toggle() end)
    hooksecurefunc("UpdateMicroButtons", function()
        if T.IsShown() then TalentMicroButton:SetButtonState("PUSHED", 1) end
    end)

    -- Using a glyph item opens Blizzard's glyph window from UIParent; ours takes that job.
    UIParent:UnregisterEvent("USE_GLYPH")

    redirectBlizzardFrame()
    if IsAddOnLoaded("Blizzard_InspectUI") then hookInspectFrame() end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UPDATE_BINDINGS")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("ADDON_LOADED")
    ev:RegisterEvent("USE_GLYPH")
    ev:SetScript("OnEvent", function(_, event, arg1)
        if event == "UPDATE_BINDINGS" then
            applyBindings()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if T._rebindQueued then applyBindings() end
        elseif event == "USE_GLYPH" then
            T.OpenGlyphs()
        elseif arg1 == "Blizzard_TalentUI" then
            redirectBlizzardFrame()
        elseif arg1 == "Blizzard_InspectUI" then
            hookInspectFrame()
        end
    end)
end

_G.SLASH_DRAGONUI_TALENTS1 = "/talents"
SlashCmdList["DRAGONUI_TALENTS"] = function() T.Toggle() end

-- ============================================================================
-- Lifecycle
-- ============================================================================
local function applyTalents()
    if T.applied or not IsLoggedIn() or not addon:IsModuleEnabled("talents") then return end
    T.applied = true
    T.initialized = true
    buildWindow()
    installEntryPoints()
end

function addon.ApplyTalentSystem() applyTalents() end

-- Load-once: the entry points and hooks stay for the session, so there is nothing to tear down.
function addon.RestoreTalentSystem() end

function addon.RefreshTalentSystem()
    applyTalents()
    if T.applied then
        T.ApplyScale()
        T.Refresh()
    end
end

addon:RegisterModule("talents", T, L["Talents"], L["Retail-style talent window"],
    { lifecyclePrefix = "Talent", loadOnce = true })

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("UI_SCALE_CHANGED")
boot:RegisterEvent("DISPLAY_SIZE_CHANGED")
boot:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        applyTalents()
    elseif T.applied then
        T.ApplyScale()
    end
end)
