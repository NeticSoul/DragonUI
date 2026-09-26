-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

local PER_TIER = PLAYER_TALENTS_PER_TIER or 5
local PET_PER_TIER = PET_TALENTS_PER_TIER or 3
local TEX = addon._dir .. "Talents\\"

local EDGE_ACTIVE   = { 1.0, 0.82, 0.0, 0.95 }
local EDGE_INACTIVE = { 0.24, 0.24, 0.27, 0.38 }
local EDGE_WIDTH = 32

local PET_BG = {
    HunterPetFerocity = "Pet_Ferocity",
    HunterPetTenacity = "Pet_Tenacity",
    HunterPetCunning  = "Pet_Cunning",
}

-- ============================================================================
-- View state
-- ============================================================================
T._populateDirty = true

function T.MarkDirty() T._populateDirty = true end

function T.PetHasTalents()
    return (GetNumTalentGroups(false, true) or 0) > 0
end

function T.SetPetView(on)
    on = on and true or false
    if T._petView ~= on then T.MarkDirty() end
    T._petView = on
end

function T.PetViewActive()
    return T._petView and T.PetHasTalents() or false
end

-- The spec group on screen: the inspected or pet one is always active; the player may browse the other.
function T.ViewGroup()
    local inspect = T._mode == "inspect"
    local isPet = not inspect and T.PetViewActive()
    local active = GetActiveTalentGroup(inspect, isPet) or 1
    if inspect or isPet then return active, active, inspect, isPet end
    local view = T._viewGroup or active
    if view > (GetNumTalentGroups(false, false) or 1) then view = active end
    return view, active, inspect, isPet
end

function T.SetViewGroup(group)
    T._viewGroup = group
    T.MarkDirty()
end

local function previewOn()
    return GetCVarBool("previewTalents")
end

local function talentInfo(tab, i, inspect, isPet, group)
    local name, icon, tier, column, rank, maxRank, isExceptional, meetsPrereq, previewRank, meetsPreviewPrereq =
        GetTalentInfo(tab, i, inspect, isPet, group)
    if not name then return nil end
    return {
        name = name, icon = icon, tier = tier, column = column,
        rank = rank or 0, maxRank = maxRank or 1, isExceptional = isExceptional,
        meetsPrereq = meetsPrereq, previewRank = previewRank or rank or 0,
        meetsPreviewPrereq = meetsPreviewPrereq,
    }
end
T.TalentInfo = talentInfo

-- ============================================================================
-- Sounds
-- ============================================================================
function T.PlayStageSFX(add)
    PlaySound(add and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
end

-- ============================================================================
-- Node state (New Era's vocabulary over Blizzard's TalentFrame_Update rules)
-- ============================================================================
local function computeState(info, tabPointsSpent, preview, available, perTier)
    local displayRank = preview and info.previewRank or info.rank
    local meets
    if preview then meets = info.meetsPreviewPrereq else meets = info.meetsPrereq end
    local tierUnlocked = ((info.tier or 1) - 1) * perTier <= tabPointsSpent
    local forceDesat = available <= 0 and displayRank == 0
    local state
    if not (meets and tierUnlocked and not forceDesat) then
        state = (not tierUnlocked and displayRank == 0) and "locked" or "gray"
    elseif displayRank == 0 then
        state = "green"
    else
        state = "yellow"
    end
    return state, displayRank
end

-- ============================================================================
-- Node wiring
-- ============================================================================
local function nodeTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if T._mode == "edit" then
        if T.EditTooltip then T.EditTooltip(self) end
        return
    end
    GameTooltip:SetTalent(self._tab, self._index, self._inspect, self._isPet, self._group, self._preview)
    GameTooltip:Show()
end

local function refreshOwnedTooltip()
    local owner = GameTooltip:GetOwner()
    if owner and owner._talentNode and owner:IsVisible() then nodeTooltip(owner) end
end
T.RefreshNodeTooltip = refreshOwnedTooltip

local function previewRank(tab, index, isPet, group)
    local _, _, _, _, rank, _, _, _, preview = GetTalentInfo(tab, index, false, isPet, group)
    return preview or rank or 0
end

local function previewRankOf(node)
    return previewRank(node._tab, node._index, node._isPet, node._group)
end

-- Staged points per tree set; stepping back is always legal, since no later point can rest on the last one.
local history = {}

local function historyKey(isPet, group)
    return (isPet and "pet" or "player") .. tostring(group)
end

local function viewHistory()
    local group, _, _, isPet = T.ViewGroup()
    return history[historyKey(isPet, group)], group, isPet
end

function T.ClearUndo()
    history = {}
end

local function nodeClick(self, button)
    if IsModifiedClick("CHATLINK") and T._mode ~= "edit" then
        local link = GetTalentLink(self._tab, self._index, self._inspect, self._isPet, self._group, self._preview)
        if link then ChatEdit_InsertLink(link) end
        return
    end
    if T._mode == "edit" then
        if T.EditNodeClick then T.EditNodeClick(self, button) end
        return
    end
    if not self._editable then return end
    local before = previewRankOf(self)
    AddPreviewTalentPoints(self._tab, self._index, (button == "RightButton") and -1 or 1, self._isPet, self._group)
    local after = previewRankOf(self)
    if after ~= before then
        local key = historyKey(self._isPet, self._group)
        history[key] = history[key] or {}
        table.insert(history[key], { tab = self._tab, index = self._index, delta = after - before })
        T.PlayStageSFX(after > before)
    end
    if GameTooltip:IsOwned(self) then nodeTooltip(self) end
end

function T.WireNode(n)
    if n._talentNode then return end
    n._talentNode = true
    n:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    n:SetScript("OnClick", nodeClick)
    n:SetScript("OnEnter", function(self)
        self:ShowHover()
        nodeTooltip(self)
    end)
    n:SetScript("OnLeave", function(self)
        self:HideHover()
        GameTooltip:Hide()
    end)
end

-- ============================================================================
-- Edges: straight prereq-to-dependent lines with the arrowhead at the dependent (New Era)
-- ============================================================================
function T.DrawEdge(tf, ptier, pcol, dtier, dcol, active)
    local sx, sy = T.nodeCenter(ptier, pcol)
    local dx, dy = T.nodeCenter(dtier, dcol)
    local c = active and EDGE_ACTIVE or EDGE_INACTIVE
    local e = tf:AcquireEdge()
    DrawRouteLine(e.line, tf, sx, sy, dx, dy, EDGE_WIDTH, "TOPLEFT")
    e.line:SetVertexColor(c[1], c[2], c[3], c[4])
    local angle = math.atan2(sy - dy, sx - dx)
    local grow = (dtier >= T.CAPSTONE_TIER) and 1 or T.LAYOUT.NODE_SCALE
    local off = (T.LAYOUT.NODE / 2) * 1.2 * grow
    T.SetArrow(e.arrow, active, angle - math.pi / 2)
    e.arrow:ClearAllPoints()
    e.arrow:SetPoint("CENTER", tf, "TOPLEFT", dx + math.cos(angle) * off, dy + math.sin(angle) * off)
end

-- ============================================================================
-- Header
-- ============================================================================
function T.SetHeader(tf, name, points)
    tf.headerName:SetText(string.upper(name or ""))
    tf.headerPts:SetText(points and tostring(points) or "")
    if (points or 0) > 0 then
        tf.headerPts:SetTextColor(0.1, 1.0, 0.1)
    else
        tf.headerPts:SetTextColor(0.5, 0.5, 0.5)
    end
    local nameW = tf.headerName:GetStringWidth() or 0
    local ptsW = tf.headerPts:GetStringWidth() or 0
    tf.headerName:ClearAllPoints()
    tf.headerName:SetPoint("LEFT", tf, "TOPLEFT", (tf:GetWidth() - (nameW + 6 + ptsW)) / 2, T.LAYOUT.HEADER_CENTER_Y)
end

-- ============================================================================
-- Tree placement (the pet has one shallow tree)
-- ============================================================================
local function placeTrees(f, singleTree, maxTier)
    local s = T.LAYOUT.TREE_SCALE
    for i, tf in ipairs(f.trees) do
        tf:ClearAllPoints()
        local x = (singleTree and i == 1) and (T.FRAME.W - T.LAYOUT.TREE_W * s) / 2 or tf._x
        tf:SetPoint("TOPLEFT", f, "TOPLEFT", x / s, -T.LAYOUT.TREE_TOP / s)
    end
    T._nodeYShift = singleTree and math.max(0, T.Tiers() - maxTier) * T.LAYOUT.PITCH_Y / 2 or 0
end
T.PlaceTrees = placeTrees

local function playerTierDepth()
    if T._deepestTier then return T._deepestTier end
    local deepest = 0
    for tab = 1, GetNumTalentTabs(false, false) or 0 do
        for i = 1, GetNumTalents(tab, false, false) or 0 do
            local _, _, tier = GetTalentInfo(tab, i, false, false)
            if tier and tier > deepest then deepest = tier end
        end
    end
    if deepest > 0 then T._deepestTier = deepest end
    return T._deepestTier
end

-- ============================================================================
-- Populate (live grid, pet grid, inspected grid)
-- ============================================================================
local function petBackground(f, bgName)
    if not f.petBg then
        f.petBg = f:CreateTexture(nil, "BORDER")
        f.petBg:SetAllPoints(f.bg)
    end
    local file = bgName and PET_BG[bgName]
    if file then f.petBg:SetTexture(TEX .. file) end
end

function T.Populate()
    local f = T.frame
    if not (f and f:IsShown()) then return end
    if T._mode == "edit" then
        if T.PopulateEdit then T.PopulateEdit() end
        return
    end
    if T.GlyphViewActive() then
        if T.GlyphsRefresh then T.GlyphsRefresh() end
        T.ApplyChrome()
        return
    end
    if not T._populateDirty then return end

    local depth = playerTierDepth()
    if depth then T.SetTierDepth(depth) end

    local group, active, inspect, isPet = T.ViewGroup()
    if not inspect then T.SetTitle(TALENTS) end
    local editable = not inspect and (isPet or group == active)
    local preview = editable and previewOn()
    local perTier = isPet and PET_PER_TIER or PER_TIER
    local unspent = editable and (GetUnspentTalentPoints(false, isPet, group) or 0) or 0
    local staged = preview and (GetGroupPreviewTalentPointsSpent(isPet, group) or 0) or 0
    local available = unspent - staged
    local numTabs = GetNumTalentTabs(inspect, isPet) or 0

    local maxPetTier = 1
    if isPet then
        for i = 1, GetNumTalents(1, false, true) or 0 do
            local _, _, tier = GetTalentInfo(1, i, false, true, group)
            if tier and tier > maxPetTier then maxPetTier = tier end
        end
    end
    placeTrees(f, isPet, maxPetTier)

    local domSpent, domTab, petBgName = -1, 1, nil
    for tabIdx = 1, 3 do
        local tf = f.trees[tabIdx]
        tf:ResetEdges()
        local used = {}
        if tabIdx <= numTabs then
            tf:Show()
            local name, _, spent, background, previewSpent = GetTalentTabInfo(tabIdx, inspect, isPet, group)
            if isPet then petBgName = background end
            local tabPointsSpent = (spent or 0) + (preview and (previewSpent or 0) or 0)
            T.SetHeader(tf, name, tabPointsSpent)
            if (spent or 0) > domSpent then domSpent, domTab = spent or 0, tabIdx end

            local infos, byCell = {}, {}
            for i = 1, GetNumTalents(tabIdx, inspect, isPet) or 0 do
                local info = talentInfo(tabIdx, i, inspect, isPet, group)
                if info and info.tier and info.column then
                    infos[i] = info
                    byCell[info.tier * 10 + info.column] = info
                end
            end

            for i, info in pairs(infos) do
                local state, displayRank = computeState(info, tabPointsSpent, preview, available, perTier)
                local node = tf:AcquireNode(i)
                used[i] = true
                node._tab, node._index, node._group = tabIdx, i, group
                node._inspect, node._isPet, node._preview = inspect, isPet, preview
                node._editable = editable
                node._talentName = info.name
                node._info = info
                node:SetVisual(T.ResolveShape(info), state, info.icon, (displayRank > 0) and tostring(displayRank) or "")
                node:PlaceAt(tf, T.nodeCenter(info.tier, info.column))
                node:Show()
                T.WireNode(node)
            end

            for i, info in pairs(infos) do
                local pre = { GetTalentPrereqs(tabIdx, i, inspect, isPet, group) }
                for p = 1, #pre, 4 do
                    local ptier, pcol = pre[p], pre[p + 1]
                    local src = ptier and pcol and byCell[ptier * 10 + pcol]
                    if src then
                        local meets
                        if preview then meets = info.meetsPreviewPrereq else meets = info.meetsPrereq end
                        local srcRank = preview and src.previewRank or src.rank
                        T.DrawEdge(tf, ptier, pcol, info.tier, info.column, (meets and srcRank > 0) and true or false)
                    end
                end
            end
        else
            tf:Hide()
            tf.headerName:SetText("")
            tf.headerPts:SetText("")
        end
        tf:HideUnusedNodes(used)
        tf:HideUnusedEdges()
    end

    if isPet then
        T.SetPortraitUnit("pet")
        petBackground(f, petBgName)
        f.petBg:Show()
        f.bg:Hide()
    else
        local unit = inspect and T._inspectUnit or "player"
        local _, classFile = UnitClass(unit)
        T.SetPortraitClass(classFile)
        if f.petBg then f.petBg:Hide() end
        f.bg:Show()
        -- Blizzard greys the art of a spec you are only browsing.
        T.SetBackground(domTab, classFile, not inspect and group ~= active)
    end

    f.pointsText:SetText(("|cffffffff%d|r %s"):format(math.max(0, available), L["points available"]))
    T._staged = staged
    T.ApplyChrome()
    if T.ApplySearch then T.ApplySearch() end
    refreshOwnedTooltip()
    T._populateDirty = false
end

function T.Refresh()
    T.MarkDirty()
    local f = T.frame
    if not (f and f:IsShown()) then return end
    T.Populate()
    if T.RefreshSpecTabs then T.RefreshSpecTabs() end
end

-- ============================================================================
-- Footer
-- ============================================================================
StaticPopupDialogs["DUI_TALENTS_LEARN"] = {
    text = CONFIRM_LEARN_PREVIEW_TALENTS,
    button1 = YES, button2 = NO,
    OnAccept = function()
        LearnPreviewTalents(T.PetViewActive())
        PlaySound("igQuestListComplete")
    end,
    hideOnEscape = 1, timeout = 0, exclusive = 1, whileDead = 1,
}

local function discard()
    local group, _, _, isPet = T.ViewGroup()
    history[historyKey(isPet, group)] = nil
    ResetGroupPreviewTalentPoints(isPet, group)
end

local function undoStep()
    local steps, group, isPet = viewHistory()
    local step = steps and table.remove(steps)
    if not step then return end
    local before = previewRank(step.tab, step.index, isPet, group)
    AddPreviewTalentPoints(step.tab, step.index, -step.delta, isPet, group)
    if previewRank(step.tab, step.index, isPet, group) == before then
        history[historyKey(isPet, group)] = nil
        return
    end
    T.PlayStageSFX(step.delta < 0)
end

local function iconButton(parent, tex, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(25, 25)
    b:SetPoint("CENTER", tex, "CENTER")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function activationPending(group)
    local spell = TALENT_ACTIVATION_SPELLS[group]
    return spell and IsCurrentSpell(spell)
end

T.OnBuild(function(f)
    local bar = f.barFrame

    f.pointsText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    f.apply = CreateFrame("Button", "DragonUI_TalentApplyButton", bar, "UIPanelButtonTemplate")
    f.apply:SetSize(150, 22)
    f.apply:SetPoint("CENTER", bar, "CENTER", 0, 1)
    f.apply:SetText(L["Apply Changes"])
    f.apply:SetScript("OnClick", function()
        if T._mode == "edit" then
            if T.SaveEditBuild then T.SaveEditBuild() end
            return
        end
        StaticPopup_Show("DUI_TALENTS_LEARN")
    end)
    f.apply:SetScript("OnEnter", function(self)
        if T._mode == "edit" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TALENT_TOOLTIP_LEARNTALENTGROUP, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.apply:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addon.SkinRedButton(f.apply)

    -- 3.3.5a has no GlowEmitter; Blizzard's own button glow, tinted green, pulses the same way.
    f.applyGlow = bar:CreateTexture(nil, "OVERLAY")
    f.applyGlow:SetTexture("Interface\\Buttons\\UI-Panel-Button-Glow")
    f.applyGlow:SetTexCoord(0, 0.75, 0, 0.609375)
    f.applyGlow:SetBlendMode("ADD")
    f.applyGlow:SetVertexColor(0.2, 1, 0.2)
    f.applyGlow:SetPoint("TOPLEFT", f.apply, "TOPLEFT", -11, 7)
    f.applyGlow:SetPoint("BOTTOMRIGHT", f.apply, "BOTTOMRIGHT", 11, -7)
    f.applyGlow:SetAlpha(0.35)
    f.applyGlow:Hide()
    local pulse = f.applyGlow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetChange(0.65)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    f.applyGlow.pulse = pulse

    f.reset = bar:CreateTexture(nil, "OVERLAY")
    f.reset:SetSize(20, 20)
    f.reset:SetPoint("LEFT", f.apply, "RIGHT", 14, 0)
    f.reset:set_atlas("talents-button-reset")
    f.undo = bar:CreateTexture(nil, "OVERLAY")
    f.undo:SetSize(21, 20)
    f.undo:SetPoint("LEFT", f.reset, "RIGHT", 8, 0)
    f.undo:set_atlas("talents-button-undo")
    f.resetButton = iconButton(bar, f.reset, discard, TALENT_TOOLTIP_RESETTALENTGROUP)
    f.undoButton = iconButton(bar, f.undo, undoStep, L["Undo the last point"])

    f.activate = CreateFrame("Button", "DragonUI_TalentActivateButton", bar, "UIPanelButtonTemplate")
    f.activate:SetText(TALENT_SPEC_ACTIVATE)
    f.activate:SetSize(f.activate:GetTextWidth() + 40, 22)
    f.activate:SetPoint("LEFT", f.apply, "LEFT", 0, 0)
    f.activate:SetScript("OnClick", function()
        SetActiveTalentGroup((T.ViewGroup()))
    end)
    f.activate:SetScript("OnShow", function(self) self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED") end)
    f.activate:SetScript("OnHide", function(self) self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED") end)
    f.activate:SetScript("OnEvent", function() T.ApplyChrome() end)
    addon.SkinRedButton(f.activate)
    f.activate:Hide()

    f:HookScript("OnShow", function()
        T._savedPreviewCVar = GetCVar("previewTalents")
        SetCVar("previewTalents", "1")
        T.MarkDirty()
        T.Populate()
        if T.RefreshSpecTabs then T.RefreshSpecTabs() end
    end)
    f:HookScript("OnHide", function()
        if T._mode == "edit" and T.ExitEditor then T.ExitEditor() end
        T.ClearUndo()
        ResetGroupPreviewTalentPoints(false, GetActiveTalentGroup(false, false) or 1)
        if T.PetHasTalents() then ResetGroupPreviewTalentPoints(true, GetActiveTalentGroup(false, true) or 1) end
        if T._savedPreviewCVar then SetCVar("previewTalents", T._savedPreviewCVar) end
        T.ClearInspect()
    end)
end)

-- Footer visibility per mode: live, browsing the other spec, pet, glyphs, editor, inspect.
function T.ApplyChrome()
    local f = T.frame
    if not (f and f.apply) then return end
    local glyphs = T.GlyphViewActive()
    local group, active, inspect, isPet = T.ViewGroup()
    local edit = T._mode == "edit"
    local browsing = not inspect and not isPet and not glyphs and group ~= active
    local live = not inspect and not glyphs and not browsing

    local staged = not edit and (T._staged or 0) > 0
    f.apply:SetShownReq(live)
    f.apply:SetText(edit and L["Save Build"] or L["Apply Changes"])
    if edit or staged then f.apply:Enable() else f.apply:Disable() end
    local glow = live and staged
    f.applyGlow:SetShownReq(glow)
    if glow then
        if not f.applyGlow.pulse:IsPlaying() then f.applyGlow.pulse:Play() end
    else
        f.applyGlow.pulse:Stop()
    end

    local subs = live and not edit
    for _, r in ipairs({ f.reset, f.undo, f.resetButton, f.undoButton }) do r:SetShownReq(subs) end
    local steps = viewHistory()
    local canUndo = staged and steps ~= nil and #steps > 0
    if staged then f.resetButton:Enable() else f.resetButton:Disable() end
    if canUndo then f.undoButton:Enable() else f.undoButton:Disable() end
    f.reset:SetDesaturated(not staged)
    f.undo:SetDesaturated(not canUndo)

    f.activate:SetShownReq(browsing)
    if browsing then
        if activationPending(group) then f.activate:Disable() else f.activate:Enable() end
    end

    -- New Era seats it after the search box; in a 1214 window that spot runs into Apply.
    f.pointsText:SetShownReq(live)
    f.pointsText:ClearAllPoints()
    f.pointsText:SetPoint("LEFT", edit and f.editExit or f.undo, "RIGHT", 16, 0)
    if f.editExit then f.editExit:SetShownReq(edit) end
    if f.inspectImport then f.inspectImport:SetShownReq(inspect) end
    if f.loadout then f.loadout:SetShownReq(live and not isPet) end
    if f.search then f.search:SetShownReq(live or browsing) end
    if T.RefreshPvP then T.RefreshPvP(not inspect and not glyphs and not edit) end
end

-- ============================================================================
-- Events
-- ============================================================================
local events = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PREVIEW_TALENT_POINTS_CHANGED",
    "PREVIEW_PET_TALENT_POINTS_CHANGED", "PET_TALENT_UPDATE", "PLAYER_LEVEL_UP",
    "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_PET", "INSPECT_TALENT_READY", "UNIT_PORTRAIT_UPDATE",
}) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, arg1)
    if not T.applied then return end
    if event == "UNIT_PET" and arg1 ~= "player" then return end
    if event == "UNIT_PORTRAIT_UPDATE" then
        if arg1 == "pet" and T.frame:IsShown() and T.PetViewActive() then T.SetPortraitUnit("pet") end
        return
    end
    if event == "INSPECT_TALENT_READY" and T._mode ~= "inspect" then return end
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then T._viewGroup = nil end
    -- Learning, respeccing or swapping specs rebuilds the preview from scratch.
    if event == "PLAYER_TALENT_UPDATE" or event == "PET_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        T.ClearUndo()
    end
    if event == "UNIT_PET" and T._petView and not T.PetHasTalents() then T.SetPetView(false) end
    -- The editor is independent of the character's points; a live event must not repaint over it.
    if T._mode == "edit" and event ~= "ACTIVE_TALENT_GROUP_CHANGED" then
        T.MarkDirty()
        return
    end
    T.Refresh()
end)
