-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local L = addon.L
local T = addon.TalentModule

local PER_TIER     = 5
local PET_PER_TIER = 3

local function petHasTalents()
    if not GetPetTalentTree then return false end
    local ok, tree = pcall(GetPetTalentTree)
    return (ok and tree ~= nil and tree ~= "") and true or false
end
T.PetHasTalents = petHasTalents

function T.PetViewActive() return (T._petView and petHasTalents()) and true or false end
function T.SetPetView(on)
    T._petView = on and true or false
    if T._petView and T.GlyphsSetActive then T.GlyphsSetActive(false) end
end

-- ============================================================================
-- Inspect mode
-- ============================================================================
function T.InspectUnit() return T._inspectUnit end
local function inspecting() return (T._inspectUnit and true) or false end
T.IsInspecting = inspecting

local EDGE_ACTIVE   = { 1.0, 0.82, 0.0,  0.95 }
local EDGE_INACTIVE = { 0.62, 0.58, 0.48, 0.85 }

local SOUNDS = {
    add    = "igMainMenuOptionCheckBoxOn",
    remove = "igCharacterInfoTab",
    apply  = "gsTitleOptionOK",
    spec   = "igMainMenuOpen",
}
local function playSound(key)
    local s = SOUNDS[key]
    if s and PlaySound then pcall(PlaySound, s) end
end

-- ============================================================================
-- API adapter: GetTalentInfo flat tuple -> renderer table
-- ============================================================================
local function talentInfo(tab, i, group, isPet)
    if not GetTalentInfo then return nil end
    local name, icon, tier, column, rank, maxRank, isExceptional,
          meetsPrereq, previewRank, meetsPreviewPrereq = GetTalentInfo(tab, i, inspecting(), isPet or false, group)
    if not name then return nil end
    return {
        name               = name,
        icon               = icon,
        tier               = tier,
        column             = column,
        rank               = rank or 0,
        maxRank            = maxRank or 0,
        isExceptional      = isExceptional,
        meetsPrereq        = meetsPrereq,
        previewRank        = previewRank,
        meetsPreviewPrereq = meetsPreviewPrereq,
    }
end

local function previewOn()
    local ok, v
    if GetCVarBool then ok, v = pcall(GetCVarBool, "previewTalents"); if ok then return v end end
    if GetCVar then ok, v = pcall(GetCVar, "previewTalents"); if ok then return v == "1" end end
    return false
end

local function unspentPoints(group, isPet)
    if inspecting() then return 0 end
    if GetUnspentTalentPoints then
        local ok, v = pcall(GetUnspentTalentPoints, false, isPet or false, group)
        if ok and v then return v end
    end
    if not isPet and UnitCharacterPoints then return UnitCharacterPoints("player") or 0 end
    return 0
end

local function previewSpent(group, isPet)
    if GetGroupPreviewTalentPointsSpent then
        local ok, v = pcall(GetGroupPreviewTalentPointsSpent, isPet or false, group)
        if ok and v then return v end
    end
    return 0
end

local function discardPreview(group, isPet)
    if InCombatLockdown and InCombatLockdown() then return end
    isPet = isPet or false
    if ResetPreviewTalentPoints then pcall(ResetPreviewTalentPoints) end
    if ResetGroupPreviewTalentPoints then
        pcall(ResetGroupPreviewTalentPoints, isPet, group)
        pcall(ResetGroupPreviewTalentPoints, group)
    end
    if not (AddPreviewTalentPoints and GetTalentInfo and GetNumTalentTabs) then return end
    for _pass = 1, 2 do
        for t = 1, (GetNumTalentTabs(false, isPet) or 0) do
            local n = (GetNumTalents and GetNumTalents(t, false, isPet)) or 0
            for i = n, 1, -1 do
                local info = talentInfo(t, i, group, isPet)
                if info then
                    local staged = (info.previewRank or 0) - (info.rank or 0)
                    if staged > 0 then pcall(AddPreviewTalentPoints, t, i, -staged, isPet, group) end
                end
            end
        end
    end
end
T.DiscardPreview = discardPreview

-- ============================================================================
-- State machine
-- ============================================================================

local function prereqsMetByRank(pre, byCell, preview)
    if not pre then return true end
    for p = 1, #pre, 4 do
        local ptier, pcol = pre[p], pre[p + 1]
        local src = ptier and pcol and byCell[ptier * 10 + pcol]
        if src then
            local srcRank = (preview and src.previewRank) or src.rank or 0
            local needed  = src.maxRank or 0
            if needed > 0 and srcRank < needed then
                return false
            end
        end
    end
    return true
end

local function computeState(info, prereqs, byCell, tabPointsSpent, preview, available, perTier)
    perTier = perTier or PER_TIER
    local liveRank    = info.rank or 0
    local displayRank = (preview and info.previewRank) or liveRank
    local prereqsOk   = prereqsMetByRank(prereqs, byCell, preview)
    local tierUnlocked= ((info.tier or 1) - 1) * perTier <= tabPointsSpent
    local notMaxed    = not (info.maxRank and info.maxRank > 0 and displayRank >= info.maxRank)
    local outOfPoints = (available <= 0) and notMaxed
    local spendable   = prereqsOk and tierUnlocked
    local colored     = spendable and not outOfPoints
    local state
    if preview and displayRank < liveRank then
        state = "red"
    elseif colored then
        state = (displayRank == 0 or notMaxed) and "green" or "yellow"
    elseif outOfPoints and displayRank > 0 and spendable then
        state = "dimgreen"
    else
        state = (not tierUnlocked and displayRank == 0) and "locked" or "gray"
    end
    return state, displayRank
end

-- ============================================================================
-- Node interactions
-- ============================================================================
local function nodeAddForbidden(self)
    if self._prereqsOk == false then return true end
    return false
end

local function nodeLeftClick(self)
    if not AddPreviewTalentPoints then return end
    if nodeAddForbidden(self) then return end
    if self._isPet then
        pcall(AddPreviewTalentPoints, self._tab, self._index, 1, true, T._activeGroup or 1)
    else
        pcall(AddPreviewTalentPoints, self._tab, self._index, 1)
    end
end

local function nodeRightClick(self)
    if not AddPreviewTalentPoints then return end
    if (self._shownRank or 0) <= 0 then return end
    if self._isPet then
        pcall(AddPreviewTalentPoints, self._tab, self._index, -1, true, T._activeGroup or 1)
    else
        pcall(AddPreviewTalentPoints, self._tab, self._index, -1)
    end
end

local function nodeTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self._tab and self._index and GameTooltip.SetTalent then
        local isPet   = self._isPet or false
        local inspect = inspecting()
        local group   = isPet and (T._activeGroup or 1) or (T._viewGroup or T._activeGroup or 1)
        local preview = (not inspect) and previewOn() or false
        local ok = pcall(GameTooltip.SetTalent, GameTooltip, self._tab, self._index, inspect, isPet, group, preview)
        if not ok then
            ok = pcall(GameTooltip.SetTalent, GameTooltip, self._tab, self._index, inspect, isPet, group)
        end
        if ok then
            GameTooltip:Show()
            local lines = {}
            local n = GameTooltip:NumLines() or 0
            for i = 2, n do
                local lt = _G["GameTooltipTextLeft" .. i]
                if lt and lt.GetText then
                    local t = lt:GetText()
                    if t and t ~= "" then lines[#lines + 1] = t end
                end
            end
            self._tipDesc = table.concat(lines, " ")
            return
        end
    end
    if self._tipName then
        GameTooltip:SetText(self._tipName, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function wireNode(n)
    if n._wired then return end
    n._wired = true
    n:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    n:SetScript("OnClick", function(self, btn)
        if InCombatLockdown and InCombatLockdown() then return end
        if T.IsInspecting and T.IsInspecting() then return end
        if not self._isPet and (T._viewGroup or 1) ~= (T._activeGroup or 1) then return end
        if btn == "LeftButton" then nodeLeftClick(self)
        elseif btn == "RightButton" then nodeRightClick(self) end
        nodeTooltip(self)
    end)
    n:SetScript("OnEnter", function(self)
        if self.ShowHover then self:ShowHover() end
        nodeTooltip(self)
    end)
    n:SetScript("OnLeave", function(self)
        if self.HideHover then self:HideHover() end
        GameTooltip:Hide()
    end)
end
T._WireNode = wireNode

-- ============================================================================
-- Edge drawing & flow engine (fixed axis-aligned lines + destination arrow)
-- ============================================================================
local sqrt, abs = math.sqrt, math.abs
local EDGE_LINE_W = 4
local ARROW_W, ARROW_H = 22, 20
local ARROW_TIP_REACH = ARROW_H / 4

local ARROW_TC = {
    down  = function(L, R, T, B) return L, T, L, B, R, T, R, B end,
    right = function(L, R, T, B) return R, T, L, T, R, B, L, B end,
    up    = function(L, R, T, B) return R, B, R, T, L, B, L, T end,
    left  = function(L, R, T, B) return L, B, R, B, L, T, R, T end,
}

local NODE_PAD  = 2
local HIT_HARD, HIT_SOFT, BEND_COST = 1000, 6, 4
local SIDE_EXIT = 7
local RANK_HALF_W, RANK_DROP, RANK_H = 11, 1, 12
local EMPTY = {}

local function addNodeRect(tf, tier, col, x, y, visual)
    local rects = tf._nodeRects
    if not rects then return end
    local vs   = visual or T.LAYOUT.NODE
    local half = vs / 2 + NODE_PAD
    local key  = tier * 10 + col
    tf._nodeHalf[key] = vs / 2
    rects[#rects + 1] = { key = key, cost = HIT_HARD, tier = tier, cx = x,
                          x0 = x - half, x1 = x + half, y0 = y - half, y1 = y + half }
    local top = y - vs * (T.LAYOUT.ICON_INSET or 0.84) / 2 - RANK_DROP
    rects[#rects + 1] = { key = key, cost = HIT_SOFT, tier = tier, cx = x,
                          x0 = x - RANK_HALF_W, x1 = x + RANK_HALF_W, y0 = top - RANK_H, y1 = top }
end

local function sideLanes(rects, lo, hi, sx)
    local pitch = (T.LAYOUT and T.LAYOUT.PITCH_X) or 54
    local xs, seen = {}, {}
    for i = 1, #rects do
        local r = rects[i]
        if r.cost == HIT_HARD and r.tier > lo and r.tier < hi and not seen[r.cx] then
            seen[r.cx] = true
            xs[#xs + 1] = r.cx
        end
    end
    if #xs == 0 then return { sx } end
    table.sort(xs)
    local lanes = { xs[1] - pitch * 0.5, xs[#xs] + pitch * 0.5 }
    for i = 1, #xs - 1 do
        if xs[i + 1] - xs[i] > ((T.LAYOUT and T.LAYOUT.NODE) or 36) then
            lanes[#lanes + 1] = (xs[i] + xs[i + 1]) / 2
        end
    end
    local width = (T.LAYOUT and T.LAYOUT.TREE_W) or ((((T.LAYOUT and T.LAYOUT.COLS) or 4) - 1) * pitch + 36)
    local function rank(x)
        return abs(x - sx) + ((x < 0 or x > width) and 1000 or 0)
    end
    table.sort(lanes, function(a, b) return rank(a) < rank(b) end)
    return lanes
end

local function buildGapY()
    local tiers = (T.LAYOUT and T.LAYOUT.TIERS) or 11
    local g = {}
    for t = 1, tiers - 1 do
        local _, y1 = T.nodeCenter(t, 1)
        local _, y2 = T.nodeCenter(t + 1, 1)
        g[t] = (y1 + y2) / 2
    end
    return g
end

local function pathCost(pts, rects, skipA, skipB)
    local n = #pts / 2
    local cost = (n - 2) * BEND_COST
    if n > 2 and abs(pts[3] - pts[1]) < 0.5 then cost = cost + SIDE_EXIT end
    for i = 1, n - 1 do
        local ax, ay = pts[i * 2 - 1], pts[i * 2]
        local bx, by = pts[i * 2 + 1], pts[i * 2 + 2]
        cost = cost + abs(bx - ax) + abs(by - ay)
        local x0, x1 = ax, bx; if x0 > x1 then x0, x1 = x1, x0 end
        local y0, y1 = ay, by; if y0 > y1 then y0, y1 = y1, y0 end
        for k = 1, #rects do
            local r = rects[k]
            if r.key ~= skipA and r.key ~= skipB
               and not (x1 < r.x0 or x0 > r.x1 or y1 < r.y0 or y0 > r.y1) then
                cost = cost + r.cost
            end
        end
    end
    return cost
end

local function tidyPath(pts)
    local out = {}
    for i = 1, #pts, 2 do
        local x, y = pts[i], pts[i + 1]
        local n = #out
        if not (n >= 2 and abs(out[n - 1] - x) < 0.5 and abs(out[n] - y) < 0.5) then
            out[n + 1], out[n + 2] = x, y
        end
    end
    local k = 2
    while k * 2 <= #out - 2 do
        local ax, ay = out[k * 2 - 3], out[k * 2 - 2]
        local bx, by = out[k * 2 - 1], out[k * 2]
        local cx, cy = out[k * 2 + 1], out[k * 2 + 2]
        if (abs(ax - bx) < 0.5 and abs(bx - cx) < 0.5) or (abs(ay - by) < 0.5 and abs(by - cy) < 0.5) then
            table.remove(out, k * 2); table.remove(out, k * 2 - 1)
        else
            k = k + 1
        end
    end
    return out
end

local function routeCandidates(tf, sx, sy, ex, ey, sTier, dTier)
    local gapY, rects = tf._gapY or EMPTY, tf._nodeRects or EMPTY
    local out = {}
    if abs(ex - sx) < 0.5 or abs(ey - sy) < 0.5 then
        out[#out + 1] = { sx, sy, ex, ey }
    end
    local lo, hi = sTier, dTier
    if lo > hi then lo, hi = hi, lo end
    local corridors = {}
    if hi > lo then
        if dTier >= sTier then
            for t = hi - 1, lo, -1 do corridors[#corridors + 1] = gapY[t] end
        else
            for t = lo, hi - 1 do corridors[#corridors + 1] = gapY[t] end
        end
    else
        corridors[#corridors + 1] = gapY[lo - 1]
        corridors[#corridors + 1] = gapY[lo]
    end
    for i = 1, #corridors do
        local g = corridors[i]
        if g then out[#out + 1] = { sx, sy, sx, g, ex, g, ex, ey } end
    end
    out[#out + 1] = { sx, sy, ex, sy, ex, ey }
    out[#out + 1] = { sx, sy, sx, ey, ex, ey }
    local g1, g2 = gapY[lo], gapY[hi - 1]
    if g1 and g2 and abs(g1 - g2) > 0.5 then
        local lanes = sideLanes(rects, lo, hi, sx)
        for i = 1, math.min(#lanes, 2) do
            local jx = lanes[i]
            out[#out + 1] = { sx, sy, sx, g1, jx, g1, jx, g2, ex, g2, ex, ey }
        end
    end
    return out
end

local function trimStart(pts, amount)
    while amount > 0 and #pts >= 4 do
        local dx, dy = pts[3] - pts[1], pts[4] - pts[2]
        local len = sqrt(dx * dx + dy * dy)
        if len > amount + 0.01 then
            pts[1] = pts[1] + dx / len * amount
            pts[2] = pts[2] + dy / len * amount
            return true
        end
        table.remove(pts, 1); table.remove(pts, 1)
        amount = amount - len
    end
    return #pts >= 4
end

local function trimEnd(pts, amount)
    while amount > 0 and #pts >= 4 do
        local n = #pts
        local dx, dy = pts[n - 3] - pts[n - 1], pts[n - 2] - pts[n]
        local len = sqrt(dx * dx + dy * dy)
        if len > amount + 0.01 then
            pts[n - 1] = pts[n - 1] + dx / len * amount
            pts[n]     = pts[n] + dy / len * amount
            return true
        end
        pts[n] = nil; pts[n - 1] = nil
        amount = amount - len
    end
    return #pts >= 4
end

local SHEEN_SWEEP, SHEEN_PEAK = 0.7, 0.40
local GLINT_MIN, GLINT_MAX    = 0.25, 0.95
local sin, pi, random = math.sin, math.pi, math.random

local function updateSheen(node, clock)
    if not node._sheenAllowed then return end
    local s = node.sheen
    if not s then return end
    local st = node._sheenStart
    if not st then if s:IsShown() then s:Hide() end return end
    local t = (clock - st) / SHEEN_SWEEP
    if t < 0 or t >= 1 then node._sheenStart = nil; s:Hide(); return end
    local env  = sin(pi * t)
    local full = node._sheenSpan or 28
    local sz = full * env
    if sz < 1 then sz = 1 end
    s:SetSize(sz, sz)
    local d = full * (t - 0.5)
    s:ClearAllPoints()
    s:SetPoint("CENTER", node, "CENTER", d, -d)
    s:SetAlpha(SHEEN_PEAK)
    s:Show()
end

local function ensureFlowDriver(f)
    if f._edgeFlow then return end
    f._edgeFlow = true
    T._sheenClock = 0
    T._nextGlint = 0
    f:HookScript("OnUpdate", function(self, dt)
        dt = dt or 0
        local clock = (T._sheenClock or 0) + dt
        if clock > 1e6 then clock = 0; T._nextGlint = 0 end
        T._sheenClock = clock
        local trees = self.trees
        if not trees then return end
        for i = 1, 3 do
            local tf = trees[i]
            if tf then
                local sl = tf._sheenList
                if sl then for j = 1, #sl do if sl[j]._sheenAllowed then updateSheen(sl[j], clock) end end end
            end
        end
        if clock >= (T._nextGlint or 0) then
            local cand = {}
            for i = 1, 3 do
                local sl = trees[i] and trees[i]._sheenList
                if sl then for j = 1, #sl do cand[#cand + 1] = sl[j] end end
            end
            local n = #cand
            if (available or 0) <= 0 then
                for i = 1, 3 do
                    local tf2 = trees[i]
                    if tf2 and tf2._sheenList then
                        for j = #tf2._sheenList, 1, -1 do
                            local nd = tf2._sheenList[j]
                            if nd then nd._sheenStart = nil; if nd.sheen then nd.sheen:Hide() end end
                        end
                        tf2._sheenList = {}
                    end
                end
            elseif n > 0 then
                if n > 1 and T._lastGlint then
                    for k = n, 1, -1 do if cand[k] == T._lastGlint then table.remove(cand, k); break end end
                end
                local pick = cand[random(#cand)]
                pick._sheenStart = clock
                T._lastGlint = pick
            end
            local mult = math.max(1, 6 - n)
            T._nextGlint = clock + (GLINT_MIN + random(0, math.floor((GLINT_MAX - GLINT_MIN) * 1000)) / 1000) * mult
        end
    end)
end

local function drawEdge(tf, sTier, sCol, dTier, dCol, color)
    local sx, sy = T.nodeCenter(sTier, sCol)
    local ex, ey = T.nodeCenter(dTier, dCol)
    if abs(ex - sx) < 1 and abs(ey - sy) < 1 then return end

    local rects = tf._nodeRects or EMPTY
    local skipA, skipB = sTier * 10 + sCol, dTier * 10 + dCol
    local cands = routeCandidates(tf, sx, sy, ex, ey, sTier, dTier)
    local best, bestCost
    for i = 1, #cands do
        local pts = tidyPath(cands[i])
        if #pts >= 4 then
            local cost = pathCost(pts, rects, skipA, skipB)
            if not bestCost or cost < bestCost then best, bestCost = pts, cost end
        end
    end
    if not best then return end

    local halves = tf._nodeHalf or EMPTY
    local fallback = T.LAYOUT.NODE / 2
    if not (trimStart(best, (halves[skipA] or fallback) + 1)) then return end
    if not (trimEnd(best, (halves[skipB] or fallback) + 1)) then return end

    local n = #best / 2
    for i = 1, n - 1 do
        local x1, y1 = best[i * 2 - 1], best[i * 2]
        local x2, y2 = best[i * 2 + 1], best[i * 2 + 2]
        local dx, dy = x2 - x1, y2 - y1
        local len = sqrt(dx * dx + dy * dy)
        if len > EDGE_LINE_W then
            local line = tf:AcquireEdgeLine()
            line:SetVertexColor(color[1], color[2], color[3], color[4])
            if abs(dx) > abs(dy) then
                line:SetSize(len, EDGE_LINE_W)
            else
                line:SetSize(EDGE_LINE_W, len)
            end
            line:ClearAllPoints()
            line:SetPoint("CENTER", tf, "TOPLEFT", (x1 + x2) / 2, (y1 + y2) / 2)
        end
    end

    local lx, ly = best[n * 2 - 3], best[n * 2 - 2]
    local tx, ty = best[n * 2 - 1], best[n * 2]
    local dx, dy = tx - lx, ty - ly
    local len = sqrt(dx * dx + dy * dy)
    if len > 1 then
        dx, dy = dx / len, dy / len
        local dir
        if abs(dx) > abs(dy) then
            dir = (dx > 0) and "right" or "left"
        else
            dir = (dy < 0) and "down" or "up"
        end
        local off = ARROW_TIP_REACH
        local a = tf:AcquireEdgeArrow()
        local nick = (color == EDGE_ACTIVE) and "talents-arrow-head-yellow" or "talents-arrow-head-gray"
        a:set_atlas(nick, true)
        local at = addon.atlasinfo[nick]
        a:SetTexCoord(ARROW_TC[dir](at[4], at[5], at[6], at[7]))
        a:SetSize(ARROW_W, ARROW_H)
        a:ClearAllPoints()
        a:SetPoint("CENTER", tf, "TOPLEFT", tx - dx * off, ty - dy * off)
    end
end

-- ============================================================================
-- Bottom bar setup
-- ============================================================================
StaticPopupDialogs["DUI_TALENTS_LEARN"] = {
    text = CONFIRM_LEARN_PREVIEW_TALENTS or "Learn the selected talents? Spent points cannot be refunded without a respec.",
    button1 = YES, button2 = NO,
    OnAccept = function()
        if LearnPreviewTalents then pcall(LearnPreviewTalents, T.PetViewActive and T.PetViewActive() or false) end
        playSound("apply")
    end,
    hideOnEscape = 1, timeout = 0, exclusive = 1, whileDead = 1,
}

local function buildBottomBar(f)
    if f._barBuilt then return end
    f._barBuilt = true
    if T.LO_TogglePanel and not (T.IsInspecting and T.IsInspecting()) and not T._petView and not (T.GlyphsIsActive and T.GlyphsIsActive()) then T.LO_TogglePanel() end

    f.pointsText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.pointsText:SetPoint("TOPLEFT", f, "TOPLEFT", -(T.FRAME.CHROME_R or 0) - -10, -(T.FRAME.CHROME_T or 0) - 590)
    f.pointsText:SetText("")

    local apply = CreateFrame("Button", "DragonUI_TalentApplyButton", f, "UIPanelButtonTemplate")
    apply:SetSize(160, 20)
    apply:SetPoint("BOTTOM", f, "BOTTOM", 0, (T.FRAME.CHROME_B or 0) + 27)
    apply:SetText("Apply Changes")
    apply:SetScript("OnClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        if self.IsEnabled and not self:IsEnabled() then return end
        StaticPopup_Show("DUI_TALENTS_LEARN")
    end)
    addon.SkinRedButton(apply)
    f.apply = apply

    local reset = CreateFrame("Button", "DragonUI_TalentResetButton", f)
    reset:SetSize(18, 18)
    reset:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    local resetIcon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
    local resetNT = reset:CreateTexture(nil, "ARTWORK")
    resetNT:SetTexture(resetIcon)
    resetNT:SetAllPoints(reset)
    resetNT:SetVertexColor(0.7, 0.7, 0.7)
    reset:SetNormalTexture(resetNT)
    local resetHT = reset:CreateTexture(nil, "HIGHLIGHT")
    resetHT:SetTexture(resetIcon)
    resetHT:SetBlendMode("ADD")
    resetHT:SetAllPoints(reset)
    reset:SetHighlightTexture(resetHT)
    reset:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then return end
        discardPreview(T._activeGroup or 1, T.PetViewActive and T.PetViewActive() or false)
        if T.Refresh then T.Refresh() end
    end)
    f.reset = reset

    local activate = CreateFrame("Button", "DragonUI_TalentActivateButton", f, "UIPanelButtonTemplate")
    activate:SetSize(160, 20)
    activate:SetPoint("BOTTOM", f, "BOTTOM", 0, (T.FRAME.CHROME_B or 0) + 27)
    activate:SetText(L["Activate"] or "Activate")
    activate:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then return end
        if SetActiveTalentGroup and T._viewGroup then pcall(SetActiveTalentGroup, T._viewGroup) end
    end)
    addon.SkinRedButton(activate)
    activate:Hide()
    f.activate = activate

    f._setSubButtonsEnabled = function(on)
        if apply.EnableMouse then apply:EnableMouse(on) end
        if reset.EnableMouse then reset:EnableMouse(on) end
        if apply.SetEnabled then apply:SetEnabled(on) else
            if on then apply:Enable() else apply:Disable() end
        end
        if reset.SetEnabled then reset:SetEnabled(on) else
            if on then reset:Enable() else reset:Disable() end
        end
    end
end

-- ============================================================================
-- Pet background / portrait
-- ============================================================================
local PET_BG_PATH = addon._dir .. "Talents\\"
local PET_BG_FILE = {
    HunterPetFerocity = "Pet_Ferocity",
    HunterPetTenacity = "Pet_Tenacity",
    HunterPetCunning   = "Pet_Cunning",
}
local function applyPetBackground(f, bgName)
    if not f then return end
    if not f.petBg then
        local tx = f:CreateTexture(nil, "BORDER")
        tx:SetPoint("TOPLEFT",     f, "TOPLEFT",     (T.FRAME.CHROME_L or 0), -(T.FRAME.CHROME_T or 0))
        tx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(T.FRAME.CHROME_R or 0), (T.FRAME.CHROME_B or 0) + (T.FRAME.BOTTOMBAR_H or 0))
        tx:SetTexCoord(0, 1, 0, 1)
        f.petBg = tx
    end
    local file = bgName and PET_BG_FILE[bgName]
    if file then f.petBg:SetTexture(PET_BG_PATH .. file) end
    if f.bg then f.bg:Hide() end
    f.petBg:Show()
end

local function refreshPetPortrait(f)
    local p = f and f.portrait
    if not (p and SetPortraitTexture) then return end
    if not (T.PetViewActive and T.PetViewActive()) then return end
    if UnitExists and not UnitExists("pet") then return end
    p:SetTexCoord(0, 1, 0, 1)
    pcall(SetPortraitTexture, p, "pet")
end

local function ensurePetPortrait(f)
    refreshPetPortrait(f)
    addon:After(0,   function() refreshPetPortrait(f) end)
    addon:After(0.3, function() refreshPetPortrait(f) end)
    if not f._duiPetPortraitWatcher then
        local w = CreateFrame("Frame", nil, f)
        w:RegisterEvent("UNIT_PORTRAIT_UPDATE")
        w:RegisterEvent("UNIT_PET")
        w:SetScript("OnEvent", function(_, _, unit)
            if unit == nil or unit == "pet" or unit == "player" then refreshPetPortrait(f) end
        end)
        f._duiPetPortraitWatcher = w
    end
end
T._ApplyPetBackground = applyPetBackground

-- ============================================================================
-- Tier depth from live data
-- ============================================================================
local function playerTierDepth()
    if T._playerTiers then return T._playerTiers end
    local maxTier = 0
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs(false, false)) or 0
    for tab = 1, numTabs do
        local n = (GetNumTalents and GetNumTalents(tab, false, false)) or 0
        for i = 1, n do
            local _, _, tier = GetTalentInfo(tab, i, false, false)
            if tier and tier > maxTier then maxTier = tier end
        end
    end
    if maxTier < 1 then return nil end
    T._playerTiers = maxTier
    return maxTier
end

function T.ApplyTierDepth()
    if not T.SetTierDepth then return end
    local depth = playerTierDepth()
    if depth then T.SetTierDepth(depth) end
end

-- ============================================================================
-- Main data refresh (T.Populate)
-- ============================================================================
function T.Populate()
    local f = T.frame
    if not f or not GetTalentInfo then return end
    buildBottomBar(f)
    ensureFlowDriver(f)

    T.ApplyTierDepth()

    if T._petView and not petHasTalents() then T._petView = false end
    local isPet   = T._petView and true or false
    local perTier = isPet and PET_PER_TIER or PER_TIER

    local inspect = inspecting()
    local active = (GetActiveTalentGroup
                    and (inspect and GetActiveTalentGroup(true, isPet) or GetActiveTalentGroup())) or 1
    if T._viewGroup == nil or T._lastActive ~= active then T._viewGroup = active end
    T._activeGroup, T._lastActive = active, active
    local numGroups = (GetNumTalentGroups and (GetNumTalentGroups() or 1)) or 1
    if numGroups < 2 then T._viewGroup = active end

    local group    = (isPet or inspect) and active or T._viewGroup
    local editable = (not inspect) and (isPet or (group == active))
    local viewChanged = (T._lastViewGroup ~= group) or (T._lastPetView ~= isPet)
    T._lastViewGroup, T._lastPetView = group, isPet
    T._group = group
    local preview = previewOn() and editable
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs(inspect, isPet)) or 0

    for i = 1, 3 do
        local tf = f.trees[i]
        if tf and not tf._defPoint then tf._defPoint = { tf:GetPoint() } end
    end
    if isPet and numTabs <= 1 then
        local tf = f.trees[1]
        local dp = tf._defPoint
        local treeW = (T.LAYOUT and T.LAYOUT.TREE_W) or tf:GetWidth() or 0
        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", f, "TOPLEFT", (T.FRAME.W - treeW) / 2, dp and dp[5] or -64)
    else
        for i = 1, 3 do
            local tf = f.trees[i]
            local dp = tf and tf._defPoint
            if dp then tf:ClearAllPoints(); tf:SetPoint(unpack(dp)) end
        end
    end

    T._nodeYShift = 0
    if isPet then
        local layTiers = (T.LAYOUT and T.LAYOUT.TIERS) or 11
        local pitchY   = (T.LAYOUT and T.LAYOUT.PITCH_Y) or 44
        local maxTier, nt = 1, (GetNumTalents and GetNumTalents(1, false, true)) or 0
        for i = 1, nt do
            local info = talentInfo(1, i, group, true)
            if info and info.tier and info.tier > maxTier then maxTier = info.tier end
        end
        T._nodeYShift = math.max(0, layTiers - maxTier) * pitchY / 2
    end

    local unspent       = unspentPoints(group, isPet)
    local previewSpentAll = preview and previewSpent(group, isPet) or 0
    local available     = unspent - previewSpentAll

    local domIcon, domSpent, domTab = nil, -1, 1
    local petBgName

    for tabIdx = 1, 3 do
        local tf = f.trees[tabIdx]
        tf:ResetEdges(); tf:ResetGates()
        tf._sheenList = {}
        tf._nodeRects, tf._nodeHalf = {}, {}
        local used = {}

        if tabIdx <= numTabs then
            local name, icon, spent, _bg, prevSpent = GetTalentTabInfo(tabIdx, inspect, isPet, group)
            if isPet and _bg then petBgName = _bg end
            local tabPointsSpent = (spent or 0) + (preview and (prevSpent or 0) or 0)
            tf.headerName:SetText(string.upper(name or ("Tree " .. tabIdx)))
            tf.headerPts:SetText(tostring(tabPointsSpent))
            if (available or 0) <= 0 and (tabPointsSpent or 0) > 0 then
                tf.headerPts:SetTextColor(0, 0.6, 0)
            elseif (tabPointsSpent or 0) > 0 then
                tf.headerPts:SetTextColor(0.1, 1.0, 0.1)
            else
                tf.headerPts:SetTextColor(0.5, 0.5, 0.5)
            end

            local nameW = (tf.headerName:GetStringWidth() or 0) * 0.9
            local ptsW  = tf.headerPts:GetStringWidth() or 0
            tf.headerName:ClearAllPoints()
            tf.headerName:SetPoint("LEFT", tf, "TOPLEFT", (tf:GetWidth() - (nameW + 8 + ptsW)) / 2, (T.LAYOUT and T.LAYOUT.HEADER_CENTER_Y) or -13)
            tf.headerPts:ClearAllPoints()
            tf.headerPts:SetPoint("TOP", tf.headerName, "BOTTOM", -5, 2)

            if (spent or 0) > domSpent then domSpent = (spent or 0); domIcon = icon; domTab = tabIdx end

            local numTalents = (GetNumTalents and GetNumTalents(tabIdx, inspect, isPet)) or 0
            local byCell, infos, prereqs = {}, {}, {}

            local occupied = {}
            for i = 1, numTalents do
                local info = talentInfo(tabIdx, i, group, isPet)
                if info and info.tier and info.column then
                    infos[i] = info
                    occupied[#occupied + 1] = { tier = info.tier, column = info.column }
                    if GetTalentPrereqs then
                        prereqs[i] = { GetTalentPrereqs(tabIdx, i, inspect, isPet, group) }
                    end
                end
            end
            if T.SetColumnLayout then T.SetColumnLayout(occupied) end

            for i = 1, numTalents do
                if infos[i] and infos[i].tier and infos[i].column then
                    byCell[infos[i].tier * 10 + infos[i].column] = infos[i]
                end
            end

            for i = 1, numTalents do
                local info = infos[i]
                if info and info.tier and info.column then
                    local shape = T.ResolveShape(info)
                    local state, displayRank = computeState(info, prereqs[i], byCell, tabPointsSpent, preview, (editable and available) or 0, perTier)
                    local node = tf:AcquireNode(i); used[i] = true
                    node._tab, node._index = tabIdx, i
                    node._isPet = isPet
                    node._tipName = info.name
                    node._info = info
                    node._prereqs = prereqs[i]
                    node._prereqsOk = prereqsMetByRank(prereqs[i], byCell, preview)
                    node._tipDesc = ""
                    local rankText = (info.maxRank and info.maxRank > 0) and (tostring(displayRank) .. "/" .. tostring(info.maxRank)) or ""
                    node:SetVisual(shape, state, info.icon, rankText)

                    if editable and not viewChanged and node._shownRank then
                        if displayRank > node._shownRank then
                            if node.PlaySpend then node:PlaySpend() end
                            playSound("add")
                        elseif displayRank < node._shownRank then
                            playSound("remove")
                        end
                    end
                    node._shownRank = displayRank

                    local dimmed = (not editable) and (not inspect)
                    node:SetAlpha(dimmed and 0.66 or 1)
                    if dimmed and node.icon and node.icon.SetDesaturated then node.icon:SetDesaturated(true) end
                    if not dimmed and node.icon and node.icon.SetDesaturated then node.icon:SetDesaturated(false) end
                    local x, y = T.nodeCenter(info.tier, info.column)
                    node:ClearAllPoints(); node:SetPoint("CENTER", tf, "TOPLEFT", x, y); node:Show()
                    addNodeRect(tf, info.tier, info.column, x, y, node._visualSize)
                    wireNode(node)

                    if editable and (displayRank or 0) > 0 and (available or 0) > 0 then
                        node._sheenAllowed = true
                        tf._sheenList[#tf._sheenList + 1] = node
                    else
                        node._sheenStart = nil
                        node._sheenAllowed = nil
                        if node.sheen then node.sheen:Hide() end
                    end
                end
            end

            if editable or inspect then
                tf._gapY = buildGapY()
                for i = 1, numTalents do
                    local info = infos[i]
                    local pre  = prereqs[i]
                    if info and pre then
                        for p = 1, #pre, 4 do
                            local ptier, pcol = pre[p], pre[p + 1]
                            local srcInfo = ptier and pcol and byCell[ptier * 10 + pcol]
                            if srcInfo then
                                local srcRank = (preview and srcInfo.previewRank) or srcInfo.rank or 0
                                local needed  = srcInfo.maxRank or 0
                                local active  = (needed > 0 and srcRank >= needed) or (needed == 0 and srcRank > 0)
                                local color   = active and EDGE_ACTIVE or EDGE_INACTIVE
                                drawEdge(tf, ptier, pcol, info.tier, info.column, color)
                            end
                        end
                    end
                end
            end
        else
            tf.headerName:SetText(""); tf.headerPts:SetText("")
        end

        tf:HideUnusedNodes(used)
        tf:HideUnusedEdges()
        tf:HideUnusedGates()
    end

    if f.portrait then
        if isPet then
            ensurePetPortrait(f)
        else
            local _, classFile = UnitClass((inspect and T._inspectUnit) or "player")
            local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
            if c then
                f.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                f.portrait:SetTexCoord(c[1], c[2], c[3], c[4])
            elseif domIcon then
                f.portrait:SetTexCoord(0, 1, 0, 1); f.portrait:SetTexture(domIcon)
            end
        end
    end

    if isPet then
        applyPetBackground(f, petBgName)
    else
        if f.petBg then f.petBg:Hide() end
        if f.bg then f.bg:Show() end
        if T.SetBackground then T.SetBackground(domTab) end
    end

    if f.pointsText then
        if inspect then
            local unit  = T._inspectUnit
            local who   = (unit and GetUnitName and GetUnitName(unit, true)) or (unit and UnitName(unit)) or ""
            local total = 0
            for tabIdx = 1, numTabs do
                local _, _, spent = GetTalentTabInfo(tabIdx, true, isPet, group)
                total = total + (spent or 0)
            end
            f.pointsText:SetText(who .. ("  |cffffffff%d|r"):format(total) .. (L["points spent"] or ""))
        else
            f.pointsText:SetText(("|cffffffff%d|r points available"):format(math.max(0, available)))
        end
    end
    local hasStaged = previewSpentAll > 0
    if f.apply then
        if f._setSubButtonsEnabled then f._setSubButtonsEnabled(hasStaged) end
    end

    if inspect then
        if f.apply then f.apply:Hide() end
        if f.reset then f.reset:Hide() end
        if f.activate then f.activate:Hide() end
    elseif editable then
        if f.activate then f.activate:Hide() end
        if f.apply then f.apply:Show() end
        if f.reset then f.reset:Show() end
    else
        if f.apply then f.apply:Hide() end
        if f.reset then f.reset:Hide() end
        if f.activate then
            f.activate:Show()
            f.activate:SetText(L["Activate"] or "Activate")
            f.activate:Enable()
        end
    end

    if f._loBtn then if (isPet or inspect) then f._loBtn:Hide() else f._loBtn:Show() end end

    if T.RefreshSpecTabs then T.RefreshSpecTabs() end
    if T.GlyphsEnsureUI then pcall(T.GlyphsEnsureUI) end
    if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
    if T.GlyphsApplyPaneVisibility then pcall(T.GlyphsApplyPaneVisibility) end
end

function T.Refresh()
    local f = T.frame
    if not (f and f:IsShown()) then return end
    T.Populate()
end

-- ============================================================================
-- Initialization root boot
-- ============================================================================
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    local f = T.frame or (T.Build and T.Build()) or nil
    if not f then return end
    buildBottomBar(f)

    f:HookScript("OnShow", function()
        if GetCVar then pcall(function() T._savedPreviewCVar = GetCVar("previewTalents") end) end
        if SetCVar then pcall(SetCVar, "previewTalents", "1") end
        if T.Populate then T.Populate() end
    end)
    f:HookScript("OnHide", function()
        discardPreview(T._activeGroup or 1, false)
        if petHasTalents() then discardPreview(T._activeGroup or 1, true) end
        if SetCVar and T._savedPreviewCVar then pcall(SetCVar, "previewTalents", T._savedPreviewCVar) end
    end)

    local ev = CreateFrame("Frame")
    for _, e in ipairs({
        "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PREVIEW_TALENT_POINTS_CHANGED",
        "PLAYER_LEVEL_UP", "ACTIVE_TALENT_GROUP_CHANGED",
        "PET_TALENT_UPDATE", "PREVIEW_PET_TALENT_POINTS_CHANGED", "UNIT_PET",
    }) do pcall(function() ev:RegisterEvent(e) end) end
    ev:SetScript("OnEvent", function(_, event, arg1)
        if event == "UNIT_PET" and arg1 ~= "player" then return end
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then playSound("spec") end
        T.Refresh()
    end)
end)
