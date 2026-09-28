-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local max, min, format = math.max, math.min, string.format
local ResetGroupPreviewTalentPoints, LearnPreviewTalents = _G.ResetGroupPreviewTalentPoints, _G.LearnPreviewTalents

local SOUND_ADD, SOUND_REMOVE = "igMainMenuOptionCheckBoxOn", "igMainMenuOptionCheckBoxOff"

-- GetTalentPrereqs returns tier, column and two flags per prerequisite; the flags may be nil.
local function prereqCells(...)
    local cells = {}
    for k = 1, select("#", ...), 4 do
        local tier, column = select(k, ...)
        if tier and column then cells[#cells + 1] = { tier, column } end
    end
    return cells
end
ns.PrereqCells = prereqCells

local function cellKey(tier, column)
    return tier * 8 + column
end
ns.CellKey = cellKey

-- Custom servers ship shallower trees, so the window follows the class's real depth.
function ns.MeasureDepth()
    if ns.depthKnown then return end
    local deepest, tabs = 0, GetNumTalentTabs(false, false) or 0
    for tab = 1, tabs do
        for index = 1, GetNumTalents(tab, false, false) or 0 do
            local _, _, tier = GetTalentInfo(tab, index, false, false)
            if tier and tier > deepest then deepest = tier end
        end
    end
    if deepest < 1 then return end
    ns.depthKnown = true
    ns.SetDepth(deepest)
end

local function liveState(open, met, shown, available)
    if not open and shown == 0 then return "locked" end
    if not met or not open or (available <= 0 and shown == 0) then return "gray" end
    if shown == 0 then return "green" end
    return "yellow"
end

local function readTree(ctx, tab, perTier, available)
    local tabName, _, spent, background, previewSpent = GetTalentTabInfo(tab, ctx.inspect, ctx.pet, ctx.group)
    local treePoints = (spent or 0) + (ctx.preview and (previewSpent or 0) or 0)
    local talents, byCell, deepest = {}, {}, 0
    for index = 1, GetNumTalents(tab, ctx.inspect, ctx.pet) or 0 do
        local name, icon, tier, column, rank, _, exceptional, met, previewRank, previewMet =
            GetTalentInfo(tab, index, ctx.inspect, ctx.pet, ctx.group)
        if name and tier then
            local shown = (ctx.preview and previewRank or rank) or 0
            local ok = ctx.preview and previewMet or met
            local open = (tier - 1) * perTier <= treePoints
            local entry = {
                index = index, name = name, icon = icon, tier = tier, column = column,
                exceptional = exceptional and true or false, rank = shown, met = ok and true or false,
                state = liveState(open, ok, shown, available),
                needs = prereqCells(GetTalentPrereqs(tab, index, ctx.inspect, ctx.pet, ctx.group)),
            }
            talents[#talents + 1] = entry
            byCell[cellKey(tier, column)] = entry
            if tier > deepest then deepest = tier end
        end
    end
    for _, entry in ipairs(talents) do
        local links = {}
        for _, cell in ipairs(entry.needs) do
            local source = byCell[cellKey(cell[1], cell[2])]
            if source then
                links[#links + 1] = { tier = cell[1], column = cell[2], active = entry.met and source.rank > 0 }
            end
        end
        entry.links = links
    end
    return { name = tabName, points = treePoints, talents = talents, background = background },
        spent or 0, deepest
end

function ns.PaintLive()
    ns.MeasureDepth()
    local ctx = ns.ViewContext()
    local perTier = ctx.pet and (PET_TALENTS_PER_TIER or 3) or (PLAYER_TALENTS_PER_TIER or 5)
    local available = ns.UnspentPoints(ctx) - ns.StagedPoints(ctx)
    local count = GetNumTalentTabs(ctx.inspect, ctx.pet) or 0
    if ctx.pet then count = min(count, 1) end

    local view = { count = count, single = ctx.pet, trees = {} }
    local committed, petDeepest = {}, 0
    for tab = 1, count do
        local tree, spent, deepest = readTree(ctx, tab, perTier, available)
        view.trees[tab] = tree
        committed[tab] = spent
        petDeepest = max(petDeepest, deepest)
    end
    if ctx.pet then view.shift = max(0, ns.depth - petDeepest) * 23 end
    ns.PaintTrees(view)

    if ctx.pet then
        ns.SetPetArt(view.trees[1] and view.trees[1].background)
        ns.SetPortraitUnit("pet")
        ns.SetTitle(TALENTS)
    elseif ctx.inspect then
        local classToken = select(2, UnitClass(ns.inspectUnit))
        ns.SetClassArt(classToken, ns.DominantTree(committed, count), false)
        ns.SetPortraitClass(classToken)
        ns.SetTitle(GetUnitName(ns.inspectUnit, true) or UnitName(ns.inspectUnit) or "")
    else
        ns.SetClassArt(ns.PlayerClass(), ns.DominantTree(committed, count), ns.Browsing())
        ns.SetPortraitClass(ns.PlayerClass())
        ns.SetTitle(TALENTS)
    end

    ns.Call("SetPointsText", format("|cffffffff%d|r %s", max(0, available), L["points available"]))

    local owner = GameTooltip:GetOwner()
    if owner and owner.isTalentNode and owner:IsVisible() then ns.NodeTooltip(owner) end
end

-- Undo history, one stack per (player or pet, spec group) -----------------------------------------

function ns.UndoKey(ctx)
    return (ctx.pet and "pet" or "own") .. ctx.group
end

function ns.UndoDepth(ctx)
    local stack = ns.undo[ns.UndoKey(ctx)]
    return stack and #stack or 0
end

local function previewRankOf(tab, index, ctx)
    local _, _, _, _, _, _, _, _, previewRank = GetTalentInfo(tab, index, false, ctx.pet, ctx.group)
    return previewRank or 0
end

function ns.UndoLast()
    local ctx = ns.ViewContext()
    if not ctx.editable then return end
    local key = ns.UndoKey(ctx)
    local stack = ns.undo[key]
    if not stack or #stack == 0 then return end
    local step = table.remove(stack)
    local before = previewRankOf(step.tab, step.index, ctx)
    AddPreviewTalentPoints(step.tab, step.index, -step.delta, ctx.pet, ctx.group)
    if previewRankOf(step.tab, step.index, ctx) == before then
        ns.undo[key] = nil
    else
        PlaySound(step.delta < 0 and SOUND_ADD or SOUND_REMOVE)
    end
    ns.Call("UpdateFooter")
end

function ns.ResetView()
    local ctx = ns.ViewContext()
    if not ctx.editable then return end
    ns.undo[ns.UndoKey(ctx)] = nil
    ResetGroupPreviewTalentPoints(ctx.pet, ctx.group)
end

-- Nodes: clicks and tooltips ----------------------------------------------------------------------

function ns.NodeTooltip(node)
    if ns.edit then return ns.Call("EditorTooltip", node) end
    local ctx = ns.ViewContext()
    GameTooltip:SetOwner(node, "ANCHOR_RIGHT")
    GameTooltip:SetTalent(node.tree, node.index, ctx.inspect, ctx.pet, ctx.group, ctx.preview)
end

function ns.NodeClicked(node, button)
    if ns.edit then return ns.Call("EditorClick", node, button) end
    local ctx = ns.ViewContext()
    if IsModifiedClick("CHATLINK") then
        local link = GetTalentLink(node.tree, node.index, ctx.inspect, ctx.pet, ctx.group, ctx.preview)
        if link then ChatEdit_InsertLink(link) end
        return
    end
    if not ctx.editable then return end
    local delta = (button == "LeftButton" and 1) or (button == "RightButton" and -1) or nil
    if not delta then return end

    local before = previewRankOf(node.tree, node.index, ctx)
    AddPreviewTalentPoints(node.tree, node.index, delta, ctx.pet, ctx.group)
    if previewRankOf(node.tree, node.index, ctx) ~= before then
        local key = ns.UndoKey(ctx)
        ns.undo[key] = ns.undo[key] or {}
        table.insert(ns.undo[key], { tab = node.tree, index = node.index, delta = delta })
        PlaySound(delta > 0 and SOUND_ADD or SOUND_REMOVE)
    end
    if GameTooltip:IsOwned(node) then ns.NodeTooltip(node) end
end

local function learnStaged()
    LearnPreviewTalents(ns.PetView() and true or false)
    PlaySound("igQuestListComplete")
end
ns.DefinePopup("DUI_TALENTS_LEARN", CONFIRM_LEARN_PREVIEW_TALENTS, YES, NO, { OnAccept = learnStaged }, "dead solo")

-- Inspect -----------------------------------------------------------------------------------------

function ns.ShowInspect(unit)
    if not TM.applied or not ns.win or not unit or not UnitExists(unit) then return end
    if ns.edit then ns.Call("LeaveEditorNow") end
    ns.inspectUnit = unit
    ns.wantPet = false
    ns.SetGlyphPage(false)
    ns.SetTitle(GetUnitName(unit, true) or UnitName(unit) or "")
    ns.Call("UpdateFooter")
    if ns.win:IsShown() then
        ns.Repaint()
    else
        ns.win:Show()
    end
end

function ns.LeaveInspect()
    if not ns.inspectUnit then return end
    ns.inspectUnit = nil
    ns.SetTitle(TALENTS)
    ns.Call("UpdateFooter")
end

-- Live repaint triggers ---------------------------------------------------------------------------

local CLEARS_HISTORY = {
    PLAYER_TALENT_UPDATE = true,
    PET_TALENT_UPDATE = true,
    ACTIVE_TALENT_GROUP_CHANGED = true,
}

local function onTalentEvent(event, unit)
    if not TM.applied then return end
    if event == "UNIT_PORTRAIT_UPDATE" then
        if unit == "pet" and ns.win:IsShown() and ns.PetView() and not ns.edit and not ns.GlyphView() then
            ns.SetPortraitUnit("pet")
        end
        return
    end
    if event == "UNIT_PET" then
        if unit ~= "player" then return end
        if not ns.PetHasTalents() then ns.wantPet = false end
    elseif event == "INSPECT_TALENT_READY" and not ns.inspectUnit then
        return
    end
    if CLEARS_HISTORY[event] then wipe(ns.undo) end
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then
        ns.viewGroup = ns.ActiveGroup()
    elseif ns.edit then
        -- The editor is independent of the character's points; exiting it repaints the live view.
        return
    end
    ns.Refresh()
end

function ns.InstallLiveEvents()
    for event in ("PLAYER_TALENT_UPDATE CHARACTER_POINTS_CHANGED PREVIEW_TALENT_POINTS_CHANGED "
        .. "PREVIEW_PET_TALENT_POINTS_CHANGED PET_TALENT_UPDATE PLAYER_LEVEL_UP "
        .. "ACTIVE_TALENT_GROUP_CHANGED UNIT_PET INSPECT_TALENT_READY UNIT_PORTRAIT_UPDATE"):gmatch("%S+") do
        ns.Listen(event, onTalentEvent)
    end
end
