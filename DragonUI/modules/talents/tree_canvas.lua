-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns

local abs, floor, max, min, sqrt = math.abs, math.floor, math.max, math.min, math.sqrt

-- Column left edges and the top offset in tree units: window units divided by the 0.95 tree scale.
local COLUMN_LEFT = { 110.63158, 475.47368, 840.31579 }
local TREE_TOP = -48.42105
local TREE_W = 228

-- Node shapes -------------------------------------------------------------------------------------

local SHAPES = {}
local function shape(key, family, ring, icon, shadowKind, shadowSize, glowAtlas, hitInset, round)
    SHAPES[key] = {
        family = family, ring = ring, icon = icon, round = round, inset = hitInset,
        shadow = "talents-node-" .. shadowKind .. "-shadow", shadowSize = shadowSize, glow = glowAtlas,
    }
end
shape("square", "square", 31.5, 31.5, "square", 61.425, "talents-node-square-greenglow", 2.25, false)
shape("circle", "circle", 36, 36, "circle", 68.4, "talents-node-circle-greenglow", 0, true)
shape("capstone", "square", 56, 56, "square", 109.2, "talents-node-square-greenglow", -10, false)
shape("apex", "apex-large", 84, 66, "square", 163.8, "talents-node-apex-large-glow", -24, true)

-- Baked 32-frame glint sheets; every cell sits centred in its stride.
local SHEENS = {}
local function sheen(key, file, sheetW, sheetH, originX, cell, stride, perRow, drawn, first, last)
    local pad = (stride - cell) / 2
    local frames = {}
    for k = 0, 31 do
        local x = originX + (k % perRow) * stride + pad
        local y = floor(k / perRow) * stride + pad
        frames[k] = { x / sheetW, (x + cell) / sheetW, y / sheetH, (y + cell) / sheetH }
    end
    SHEENS[key] = { file = "Talents\\" .. file, frames = frames, size = drawn, first = first, last = last }
end
sheen("square", "talents-sheen-small", 1024, 256, 0, 60, 64, 8, 50.4, 24, 80.75)
sheen("circle", "talents-sheen-small", 1024, 256, 512, 60, 64, 8, 57.6, 30, 84.5)
sheen("capstone", "talents-sheen-capstonesquare", 1024, 512, 0, 92, 96, 10, 89.6, 28.75, 129.5)
sheen("apex", "talents-sheen-apex", 1024, 512, 0, 124, 128, 8, 108, 55.5, 163.75)

local SWEEP_CYCLE, SWEEP_START, SWEEP_END = 22, 5, 163.75
local SWEEP_RATE = 20.769231
local ENVELOPE = 0.12

local trees = {}

function ns.ShapeFor(tier, exceptional)
    if tier >= ns.depth then return exceptional and "apex" or "capstone" end
    return exceptional and "circle" or "square"
end

local function cellCentre(tier, column, shift)
    local x = 18 + 64 * (column - 1)
    local y = 46 + 46 * (tier - 1) + (shift or 0)
    if tier >= ns.depth then y = y + 28 end
    return x, y
end

-- Node buttons ------------------------------------------------------------------------------------

local function hideSheen(node)
    node.sheenLow:Hide()
    node.sheenHigh:Hide()
end

local function startPulse(node)
    local glow = node.glow
    if not node.pulse then
        local group = glow:CreateAnimationGroup()
        local rise = group:CreateAnimation("Alpha")
        rise:SetOrder(1)
        rise:SetDuration(1)
        rise:SetChange(0.15)
        rise:SetSmoothing("OUT")
        local sink = group:CreateAnimation("Alpha")
        sink:SetOrder(2)
        sink:SetDuration(1)
        sink:SetChange(-0.15)
        sink:SetSmoothing("IN")
        group:SetLooping("REPEAT")
        node.pulse = group
    end
    glow:SetAlpha(0)
    glow:Show()
    if not node.pulse:IsPlaying() then node.pulse:Play() end
end

local function stopPulse(node)
    if node.pulse then node.pulse:Stop() end
    node.glow:Hide()
end

local function nodeEnter(node)
    node.hover:Show()
    ns.Call("NodeTooltip", node)
end

local function nodeLeave(node)
    node.hover:Hide()
    GameTooltip_Hide()
end

local function nodeClick(node, button)
    ns.Call("NodeClicked", node, button)
end

local function newNode(tree)
    local node = CreateFrame("Button", nil, tree)
    node:SetSize(36, 36)
    node:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    node.isTalentNode = true

    -- On the tree, not the node, so edges (BORDER/ARTWORK) draw above the shadow but under the node.
    node.shadow = tree:CreateTexture(nil, "BACKGROUND")
    node.icon = node:CreateTexture(nil, "ARTWORK")
    node.ring = node:CreateTexture(nil, "OVERLAY")
    node.hover = node:CreateTexture(nil, "OVERLAY", nil, 1)
    node.hover:SetBlendMode("ADD")
    node.hover:Hide()
    node.glow = node:CreateTexture(nil, "OVERLAY", nil, 2)
    node.glow:SetBlendMode("ADD")
    node.glow:Hide()
    node.sheenLow = node:CreateTexture(nil, "OVERLAY", nil, 1)
    node.sheenHigh = node:CreateTexture(nil, "OVERLAY", nil, 1)
    for _, tex in ipairs({ node.shadow, node.icon, node.ring, node.hover, node.glow, node.sheenLow, node.sheenHigh }) do
        tex:SetPoint("CENTER", node, "CENTER", 0, 0)
    end
    node.sheenLow:SetBlendMode("ADD")
    node.sheenHigh:SetBlendMode("ADD")
    hideSheen(node)

    local rank = node:CreateFontString(nil, "OVERLAY")
    rank:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
    rank:SetShadowOffset(1, -1)
    rank:SetPoint("BOTTOMRIGHT", node, "BOTTOMRIGHT", 2, -1)
    node.rank = rank

    node:SetScript("OnEnter", nodeEnter)
    node:SetScript("OnLeave", nodeLeave)
    node:SetScript("OnClick", nodeClick)
    return node
end

local function setShape(node, key)
    if node.shapeKey == key then return end
    node.shapeKey = key
    local look, glint = SHAPES[key], SHEENS[key]
    node.shadow:SetAtlasTexture(look.shadow)
    node.icon:SetSize(look.icon, look.icon)
    node.glow:SetAtlasTexture(look.glow)
    node.glow:SetSize(look.ring + 22, look.ring + 22)
    node:SetHitRectInsets(look.inset, look.inset, look.inset, look.inset)
    for _, tex in ipairs({ node.sheenLow, node.sheenHigh }) do
        tex:SetTexture(addon._dir .. glint.file)
        tex:SetSize(glint.size, glint.size)
    end
end

-- 3.3.5a has no masks, so round icons are baked by SetPortraitToTexture from the icon's file path.
local function setIcon(node, path, round)
    if node.iconPath == path and node.iconRound == round then return end
    node.iconPath, node.iconRound = path, round
    if round and path then
        SetPortraitToTexture(node.icon, path)
    else
        node.icon:SetTexture(path)
    end
    node.icon:SetTexCoord(0, 1, 0, 1)
end

local function dressNode(node, entry)
    local key = ns.ShapeFor(entry.tier, entry.exceptional)
    setShape(node, key)
    local look = SHAPES[key]
    setIcon(node, entry.icon, look.round)

    local state = entry.state
    local ringAtlas = "talents-node-" .. look.family .. "-" .. state
    node.ring:SetAtlasTexture(ringAtlas)
    node.ring:SetSize(look.ring, look.ring)
    node.hover:SetAtlasTexture(ringAtlas)
    node.hover:SetSize(look.ring, look.ring)

    local dim = state == "gray" or state == "locked"
    node.icon:SetDesaturated(dim)
    if dim then
        node.icon:SetVertexColor(0.65, 0.65, 0.65)
    else
        node.icon:SetVertexColor(1, 1, 1)
    end
    node.hover:SetAlpha(dim and 0.4 or 1)
    node.hover:Hide()

    if state == "green" then
        startPulse(node)
        node.rank:SetTextColor(0.1, 1, 0.1)
    else
        stopPulse(node)
        if dim then
            node.rank:SetTextColor(0.6, 0.6, 0.6)
        else
            node.rank:SetTextColor(1, 0.82, 0)
        end
    end
    node.rank:SetText((entry.rank or 0) > 0 and entry.rank or "")

    node.state = state
    node.glints = state ~= "green"
    if not node.glints then hideSheen(node) end
    node.index = entry.index
    node.tier = entry.tier
    node.talentName = entry.name
end

local function placeNode(node, tree, entry, shift)
    local x, y = cellCentre(entry.tier, entry.column, shift)
    local scale = entry.tier >= ns.depth and 1 or 1.12
    node:SetScale(scale)
    local shadowSize = SHAPES[node.shapeKey].shadowSize * scale
    node.shadow:SetSize(shadowSize, shadowSize)
    node:ClearAllPoints()
    -- Offsets are read in the node's own scale, so divide to land its centre on the grid point.
    node:SetPoint("CENTER", tree, "TOPLEFT", x / scale, -y / scale)
end

-- Prerequisite edges ------------------------------------------------------------------------------

-- Arrow art at 0.56 units/px (28x24 px -> 15.68 x 13.44); the solid tip ends 6 px past centre.
local ARROW_PX = 0.56
local ARROW_SIZE = 64 * ARROW_PX
local ARROW_HALF_U, ARROW_HALF_V = 32 / 128, 32 / 64
local TIP_REACH, TIP_GAP = 6 * ARROW_PX, 1
-- Both edge textures span 8.4 * 32/30 = 8.96 units (16 rows of 0.56 or 8 of 1.12); band 2.24.
local LINE_WIDTH, LINE_BAND = 8.4, 2.24
local EDGE_FINE, EDGE_COARSE = "Talents\\talents-edge.tga", "Talents\\talents-edge-coarse.tga"
-- Unsnapped or thinner shafts alias on the 4-texel band, so they take the 2-texel one.
local FINE_BAND_PX = 2.75
-- Unmasked square icons fill the ring's whole box; round outlines are these fractions of it.
local ROUND_OUTLINE = { circle = 0.5, apex = 34 / 84 }

local function outlineReach(shapeKey, scale, along)
    local size = SHAPES[shapeKey].ring * scale
    local round = ROUND_OUTLINE[shapeKey]
    if round then return size * round end
    return size / 2 / along
end

local function edgeTexture(tree, pool, layer)
    tree.used[pool] = tree.used[pool] + 1
    local list = tree[pool]
    local tex = list[tree.used[pool]]
    if not tex then
        tex = tree:CreateTexture(nil, layer)
        list[tree.used[pool]] = tex
    end
    return tex
end

-- The arrow art points down unrotated; c and s are the cosine and sine of the turn onto the edge.
local function pointArrow(tex, active, c, s)
    local cu = active and 0.25 or 0.75
    local cv = 0.5
    local function corner(px, py)
        local qx, qy = c * px + s * py, -s * px + c * py
        return cu + qx * ARROW_HALF_U, cv - qy * ARROW_HALF_V
    end
    local ulx, uly = corner(-1, 1)
    local llx, lly = corner(-1, -1)
    local urx, ury = corner(1, 1)
    local lrx, lry = corner(1, -1)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- Straight shafts sit on a pixel edge (even width) or centre (odd), so every one renders alike.
local function snapShift(origin, at, pixels, bandPx)
    local px = (origin + at) * pixels
    local target = floor(bandPx + 0.5) % 2 == 1 and floor(px) + 0.5 or floor(px + 0.5)
    return (target - px) / pixels
end

local function placeEdge(tree, line, grid)
    local edge = line.edge
    local shiftX, shiftY, file = 0, 0, EDGE_COARSE
    if grid.pixels and edge.axis then
        local bandPx = LINE_BAND * grid.pixels
        if bandPx >= FINE_BAND_PX then file = EDGE_FINE end
        if edge.axis == "x" then
            shiftX = snapShift(grid.left, edge.ex, grid.pixels, bandPx)
        else
            shiftY = snapShift(grid.top, edge.ey, grid.pixels, bandPx)
        end
    end
    line:SetTexture(addon._dir .. file)
    -- Stop under the arrow's opaque middle; a line under the translucent tip shows past it.
    DrawRouteLine(line, tree, edge.sx + shiftX, edge.sy + shiftY, edge.ex + shiftX, edge.ey + shiftY,
        LINE_WIDTH, "TOPLEFT")
    edge.arrow:ClearAllPoints()
    edge.arrow:SetPoint("CENTER", tree, "TOPLEFT", edge.ex + shiftX, edge.ey + shiftY)
end

-- The UI is 768 units tall; dragging or rescaling moves the shafts off the grid, so this re-runs.
local function snapEdges(tree, force)
    local grid = tree.grid
    local left, top, scale = tree:GetLeft(), tree:GetTop(), tree:GetEffectiveScale()
    local mode = GetCVar("gxResolution")
    if not force and left == grid.left and top == grid.top and scale == grid.scale and mode == grid.mode then
        return
    end
    grid.left, grid.top, grid.scale, grid.mode = left, top, scale, mode
    local height = left and top and mode and tonumber(mode:match("%d+x(%d+)"))
    grid.pixels = height and height > 0 and scale * height / 768 or nil
    for i = 1, tree.used.lines do
        placeEdge(tree, tree.lines[i], grid)
    end
end

local function drawEdge(tree, fromX, fromY, toX, toY, active, shapeKey, scale)
    local dx, dy = toX - fromX, fromY - toY
    local length = sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    dx, dy = dx / length, dy / length
    local back = outlineReach(shapeKey, scale, max(abs(dx), abs(dy))) + TIP_GAP + TIP_REACH

    -- 3.3.5a has no texture sublevels, so shaft and arrowhead need separate layers to stack reliably.
    local line = edgeTexture(tree, "lines", "BORDER")
    if active then
        line:SetVertexColor(1, 0.82, 0, 0.95)
    else
        line:SetVertexColor(0.24, 0.24, 0.27, 0.38)
    end
    line:Show()

    local arrow = edgeTexture(tree, "arrows", "ARTWORK")
    arrow:SetTexture(addon._dir .. "Talents\\talents-arrows")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    pointArrow(arrow, active, -dy, dx)
    arrow:Show()

    local edge = line.edge or {}
    line.edge = edge
    edge.arrow = arrow
    edge.sx, edge.sy = fromX, -fromY
    edge.ex, edge.ey = toX - back * dx, -toY - back * dy
    edge.axis = dx == 0 and "x" or dy == 0 and "y" or nil
end

local drawnFrom = {}

local function resetEdges(tree)
    tree.used.lines, tree.used.arrows = 0, 0
end

local function trimEdges(tree)
    for pool, list in pairs({ lines = tree.lines, arrows = tree.arrows }) do
        for i = tree.used[pool] + 1, #list do
            list[i]:Hide()
        end
    end
end

-- Trees -------------------------------------------------------------------------------------------

local function setHeader(tree, name, points)
    tree.title:SetText(name and name:upper() or "")
    tree.count:SetText(points or 0)
    if (points or 0) > 0 then
        tree.count:SetTextColor(0.1, 1, 0.1)
    else
        tree.count:SetTextColor(0.5, 0.5, 0.5)
    end
    local span = tree.title:GetStringWidth() + 6 + tree.count:GetStringWidth()
    tree.title:ClearAllPoints()
    tree.title:SetPoint("LEFT", tree, "TOP", -span / 2, -1.37)
end

local function headerString(tree)
    local text = tree:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 16)
    text:SetShadowOffset(1, -1)
    return text
end

function ns.BuildTrees(win, level)
    for t = 1, 3 do
        local tree = CreateFrame("Frame", nil, win)
        tree:SetScale(ns.TREE_SCALE)
        tree:SetFrameLevel(level)
        tree.nodes, tree.lines, tree.arrows, tree.used = {}, {}, {}, { lines = 0, arrows = 0 }
        tree.grid = {}
        tree.title = headerString(tree)
        tree.title:SetTextColor(1, 1, 1)
        tree.count = headerString(tree)
        tree.count:SetPoint("LEFT", tree.title, "RIGHT", 6, 0)
        tree:Hide()
        trees[t] = tree
    end
    local driver = CreateFrame("Frame", nil, win)
    driver:Hide()
    driver.wait = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.wait = self.wait + elapsed
        if self.wait < 0.0333 then return end
        self.wait = 0
        ns.StepSheen()
        for t = 1, 3 do
            if trees[t]:IsShown() then snapEdges(trees[t]) end
        end
    end)
    ns.sheenDriver = driver
    ns.LayoutTrees()
end

function ns.LayoutTrees()
    for t = 1, 3 do
        local tree = trees[t]
        if tree then
            tree:SetSize(TREE_W, 92 + 46 * (ns.depth - 1))
            tree:ClearAllPoints()
            tree:SetPoint("TOPLEFT", ns.win, "TOPLEFT", COLUMN_LEFT[t], TREE_TOP)
        end
    end
end

function ns.HideTrees()
    for t = 1, 3 do
        if trees[t] then trees[t]:Hide() end
    end
end

-- Entries: index, name, icon, tier, column, exceptional, state, rank, links.
function ns.PaintTrees(view)
    for t = 1, 3 do
        local tree = trees[t]
        local data = view.trees[t]
        if t <= (view.count or 0) and data then
            tree:ClearAllPoints()
            tree:SetPoint("TOPLEFT", ns.win, "TOPLEFT", COLUMN_LEFT[view.single and 2 or t], TREE_TOP)
            tree:Show()
            setHeader(tree, data.name, data.points)
            resetEdges(tree)
            local shift = view.shift or 0
            for k, entry in ipairs(data.talents) do
                local node = tree.nodes[k] or newNode(tree)
                tree.nodes[k] = node
                node.tree = t
                dressNode(node, entry)
                placeNode(node, tree, entry, shift)
                node:Show()
                node.shadow:Show()
                local toX, toY = cellCentre(entry.tier, entry.column, shift)
                local shapeKey, scale = ns.ShapeFor(entry.tier, entry.exceptional), node:GetScale()
                -- A cell can be listed twice (pet alternatives); a doubled dim line would brighten.
                wipe(drawnFrom)
                for _, link in ipairs(entry.links or {}) do
                    local cell = ns.CellKey(link.tier, link.column)
                    if not drawnFrom[cell] then
                        drawnFrom[cell] = true
                        local fromX, fromY = cellCentre(link.tier, link.column, shift)
                        drawEdge(tree, fromX, fromY, toX, toY, link.active, shapeKey, scale)
                    end
                end
            end
            for k = #data.talents + 1, #tree.nodes do
                tree.nodes[k]:Hide()
                tree.nodes[k].shadow:Hide()
            end
            snapEdges(tree, true)
            trimEdges(tree)
        else
            tree:Hide()
            tree.title:SetText("")
            tree.count:SetText("")
        end
    end
    ns.ApplySearch()
end

function ns.EachNode(visit)
    for t = 1, 3 do
        local tree = trees[t]
        if tree and tree:IsShown() then
            for _, node in ipairs(tree.nodes) do
                if node:IsShown() then visit(node) end
            end
        end
    end
end

function ns.ApplySearch()
    local query = ns.query or ""
    ns.EachNode(function(node)
        local hit = query == "" or (node.talentName or ""):lower():find(query, 1, true)
        node:SetAlpha(hit and 1 or 0.25)
        node.shadow:SetAlpha(hit and 1 or 0.25)
    end)
end

-- Border glint ------------------------------------------------------------------------------------

local sweeping = false

local function hideAllSheens()
    sweeping = false
    for t = 1, 3 do
        local tree = trees[t]
        if tree then
            for _, node in ipairs(tree.nodes) do hideSheen(node) end
        end
    end
end

local function showGlint(tex, glint, frame, weight)
    if weight <= 0 then
        tex:Hide()
        return
    end
    local coords = glint.frames[frame]
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    tex:SetAlpha(weight)
    tex:Show()
end

local function glintNode(node, offset)
    local glint = SHEENS[node.shapeKey]
    if not glint or offset < glint.first or offset > glint.last then
        hideSheen(node)
        return
    end
    local progress = (offset - glint.first) / (glint.last - glint.first)
    local position = progress * 31
    local low = min(floor(position), 30)
    local blend = position - low
    local envelope = 1
    if progress < ENVELOPE then
        envelope = progress / ENVELOPE
    elseif progress > 1 - ENVELOPE then
        envelope = (1 - progress) / ENVELOPE
    end
    showGlint(node.sheenLow, glint, low, (1 - blend) * envelope)
    showGlint(node.sheenHigh, glint, low + 1, blend * envelope)
end

function ns.StepSheen()
    local phase = GetTime() % SWEEP_CYCLE
    local offset = (phase - SWEEP_START) * SWEEP_RATE
    if phase < SWEEP_START or offset > SWEEP_END then
        if sweeping then hideAllSheens() end
        return
    end
    sweeping = true
    ns.EachNode(function(node)
        if node.glints then
            glintNode(node, offset)
        else
            hideSheen(node)
        end
    end)
end

function ns.StartSheen()
    if ns.sheenDriver then ns.sheenDriver:Show() end
end

function ns.StopSheen()
    if ns.sheenDriver then ns.sheenDriver:Hide() end
    hideAllSheens()
end
