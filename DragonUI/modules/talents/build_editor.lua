-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local format, min = string.format, math.min
local ResetGroupPreviewTalentPoints = _G.ResetGroupPreviewTalentPoints

local SOUND_ADD, SOUND_REMOVE = "igMainMenuOptionCheckBoxOn", "igMainMenuOptionCheckBoxOff"
local STAGE_ATTEMPTS = 400

local function className(classToken)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] or classToken
end

-- Saved state of the build being edited -------------------------------------------------------------

local function copyRanks(ranks)
    local copy = {}
    for tab, bucket in pairs(type(ranks) == "table" and ranks or {}) do
        if type(bucket) == "table" then
            local inner = {}
            for index, rank in pairs(bucket) do inner[index] = rank end
            copy[tab] = inner
        end
    end
    return copy
end

local function ranksCovered(a, b)
    for tab, bucket in pairs(a) do
        if type(bucket) == "table" then
            local other = type(b[tab]) == "table" and b[tab] or {}
            for index, rank in pairs(bucket) do
                if (tonumber(rank) or 0) ~= (tonumber(other[index]) or 0) then return false end
            end
        end
    end
    return true
end

local function snapshot(build)
    return { ranks = copyRanks(build.ranks), reqLevel = build.reqLevel }
end

-- The editor works on the stored record itself, so this is what Discard puts back.
function ns.MarkEditorSaved()
    if ns.edit then ns.editBaseline = snapshot(ns.edit) end
end

function ns.EditorDirty()
    local build, base = ns.edit, ns.editBaseline
    if not build then return false end
    if not base then return ns.BuildPoints(build) > 0 end
    local ranks = type(build.ranks) == "table" and build.ranks or {}
    return build.reqLevel ~= base.reqLevel or not ranksCovered(ranks, base.ranks) or not ranksCovered(base.ranks, ranks)
end

-- Entering and leaving ----------------------------------------------------------------------------

function ns.EnterEditor(build)
    local data = ns.TreeData()
    if not data then
        ns.Notify(L["talent data unavailable"], "error")
        return
    end
    if type(build.ranks) ~= "table" then build.ranks = {} end
    if not ns.NormalizeBuild(build, data) then
        ns.Notify(L["that build doesn't fit your talent trees"], "error")
        return
    end
    ns.LeaveInspect()
    if ns.edit ~= build then
        ns.LeaveEditorNow()
        ns.edit = build
        ns.editBaseline = ns.IsStored(build) and snapshot(build) or nil
    end
    ns.wantPet = false
    ns.SetGlyphPage(false)
    ns.viewGroup = ns.ActiveGroup()
    ns.SetTitle(TALENTS)
    ns.Call("SetDropdownLabel", build.name)
    if ns.win:IsShown() then
        ns.Repaint()
    else
        ns.win:Show()
    end
end

function ns.ExitEditor()
    if not ns.edit then return end
    ns.edit = nil
    ns.editBaseline = nil
    ns.Call("SetDropdownLabel", L["Talent Builds"])
    ns.Refresh()
end

local function pendingJob()
    local build = ns.edit
    return { build = build, base = ns.editBaseline }
end

local function saveAndLeave(_, job)
    if not job then return end
    local build = job.build
    if ns.IsStored(build) then
        ns.Notify(format(L["Build saved: %s"], build.name or "?"), "ok")
        if ns.edit == build then ns.ExitEditor() end
    else
        StaticPopup_Show("DUI_TALENT_BUILD_NAME", nil, nil, { build = build, storing = true, leave = true })
    end
end

local function discardAndLeave(_, job)
    if not job then return end
    local build, base = job.build, job.base
    if base then
        build.ranks = copyRanks(base.ranks)
        build.reqLevel = base.reqLevel
    end
    if ns.edit == build then ns.ExitEditor() end
end

-- Asked from inside the window: Cancel and Escape keep editing.
function ns.RequestExitEditor()
    local build = ns.edit
    if not build then return end
    if ns.EditorDirty() then
        StaticPopup_Show("DUI_TALENT_UNSAVED", build.name or "?", nil, pendingJob())
    else
        ns.ExitEditor()
    end
end

-- The window or the view is already gone, so the choice comes after leaving and cannot be escaped.
function ns.LeaveEditorNow()
    local build = ns.edit
    if not build then return end
    local job = ns.EditorDirty() and pendingJob()
    ns.ExitEditor()
    if job then StaticPopup_Show("DUI_TALENT_UNSAVED_LEFT", build.name or "?", nil, job) end
end

ns.DefinePopup("DUI_TALENT_UNSAVED", L["You have unsaved changes in '%s'. Save them?"], SAVE, CANCEL, {
    button3 = L["Discard"],
    OnAccept = saveAndLeave,
    OnAlt = discardAndLeave,
}, "dead")

ns.DefinePopup("DUI_TALENT_UNSAVED_LEFT", L["You have unsaved changes in '%s'. Save them?"], SAVE, L["Discard"], {
    OnAccept = saveAndLeave,
    OnCancel = discardAndLeave,
}, "dead").hideOnEscape = nil

-- Painting ----------------------------------------------------------------------------------------

local function editorState(build, data, tab, talent, rank)
    if rank > 0 then return "yellow" end
    if ns.CanAddPoint(build, data, tab, talent.index) then return "green" end
    if ns.TierOpen(build, tab, talent.tier) then return "gray" end
    return "locked"
end

local function editorTree(build, data, tab)
    local tree = data[tab]
    local drawn = {}
    for _, talent in ipairs(tree.order) do
        local rank = ns.BuildRank(build, tab, talent.index)
        local links = {}
        for _, cell in ipairs(talent.needs) do
            local source = tree.cells[ns.CellKey(cell[1], cell[2])]
            if source then
                local full = ns.BuildRank(build, tab, source) >= tree.talents[source].maxRank
                links[#links + 1] = { tier = cell[1], column = cell[2], active = full }
            end
        end
        drawn[#drawn + 1] = {
            index = talent.index, name = talent.name, icon = talent.icon,
            tier = talent.tier, column = talent.column, exceptional = talent.exceptional,
            rank = rank, state = editorState(build, data, tab, talent, rank), links = links,
        }
    end
    return { name = tree.name, points = ns.TreePoints(build, tab), talents = drawn }
end

function ns.PaintEditor()
    local build, data = ns.edit, ns.TreeData()
    if not build or not data then return end
    local count = min(3, data.count)
    local view = { count = count, trees = {} }
    for tab = 1, count do
        view.trees[tab] = editorTree(build, data, tab)
    end
    ns.PaintTrees(view)

    local level, automatic = ns.BuildLevel(build)
    local text = format(L["%d / %d points · Level %d"], ns.BuildPoints(build), ns.BuildBudget(build), level)
    if automatic then text = text .. " |cff808080" .. L["(auto)"] .. "|r" end
    ns.SetPointsText(text)

    local classToken = ns.PlayerClass()
    ns.SetPortraitClass(classToken)
    ns.SetClassArt(classToken, ns.DominantBuildTree(build, count), false)
    ns.SetTitle(TALENTS)
    ns.Call("SetDropdownLabel", build.name)

    local owner = GameTooltip:GetOwner()
    if owner and owner.isTalentNode and owner:IsVisible() then ns.EditorTooltip(owner) end
end

function ns.EditorTooltip(node)
    local build, data = ns.edit, ns.TreeData()
    if not build or not data then return end
    local talent = data[node.tree] and data[node.tree].talents[node.index]
    if not talent then return end
    local rank = ns.BuildRank(build, node.tree, node.index)
    local tip = GameTooltip
    tip:SetOwner(node, "ANCHOR_RIGHT")
    tip:SetTalent(node.tree, node.index, false, false, ns.ActiveGroup())
    tip:AddLine(" ")
    if rank >= 1 then
        tip:AddLine(format(L["In this build: rank %d / %d"], rank, talent.maxRank), 0.12, 1, 0)
    else
        tip:AddLine(L["Not in this build"], 0.5, 0.5, 0.5)
    end
    if ns.CanAddPoint(build, data, node.tree, node.index) then
        tip:AddLine(TALENT_TOOLTIP_ADDPREVIEWPOINT, 0.2, 1, 0.2)
    end
    if ns.CanRemovePoint(build, data, node.tree, node.index) then
        tip:AddLine(TALENT_TOOLTIP_REMOVEPREVIEWPOINT, 1, 0.4, 0.4)
    end
    tip:Show()
end

function ns.EditorClick(node, button)
    local build, data = ns.edit, ns.TreeData()
    if not build or not data then return end
    local tab, index = node.tree, node.index
    if button == "LeftButton" and ns.CanAddPoint(build, data, tab, index) then
        ns.AdjustRank(build, tab, index, 1)
        PlaySound(SOUND_ADD)
    elseif button == "RightButton" and ns.CanRemovePoint(build, data, tab, index) then
        ns.AdjustRank(build, tab, index, -1)
        PlaySound(SOUND_REMOVE)
    else
        return
    end
    ns.Repaint()
    if GameTooltip:IsOwned(node) then ns.EditorTooltip(node) end
end

-- Saving and naming -------------------------------------------------------------------------------

function ns.SaveBuild(build)
    if not build then return end
    if ns.IsStored(build) then
        if ns.edit == build then ns.MarkEditorSaved() end
        ns.Notify(format(L["Build saved: %s"], build.name or "?"), "ok")
        return
    end
    StaticPopup_Show("DUI_TALENT_BUILD_NAME", nil, nil, { build = build, storing = true })
end

function ns.RenameBuild(build)
    StaticPopup_Show("DUI_TALENT_BUILD_NAME", nil, nil, { build = build })
end

ns.DefinePopup("DUI_TALENT_BUILD_NAME", L["Name this build:"], SAVE, CANCEL, {
    hasEditBox = 1,
    maxLetters = 40,
    OnShow = function(self, job)
        local name = job and job.build.name or ""
        if job and job.storing and name == L["New build"] then name = "" end
        local edit = ns.PopupEdit(self)
        edit:SetText(name)
        edit:HighlightText()
        edit:SetFocus()
    end,
    OnAccept = function(self, job)
        if not job then return end
        local name = ns.Trim(ns.Scrub(ns.PopupEdit(self):GetText() or ""))
        if name == "" then return end
        local build = job.build
        build.name = name
        if job.storing then
            if not ns.IsStored(build) then table.insert(ns.OwnBuilds(), build) end
            if ns.edit == build then ns.MarkEditorSaved() end
            ns.Notify(format(L["Build saved: %s"], name), "ok")
        end
        if job.leave and ns.edit == build then
            ns.ExitEditor()
        elseif ns.edit == build then
            ns.Repaint()
        end
    end,
    EditBoxOnEnterPressed = ns.EnterAccepts,
    EditBoxOnEscapePressed = ns.EscapeCloses,
}, "dead")

-- New builds, inspect import, received builds -----------------------------------------------------

function ns.NewBuild(fromCurrent)
    ns.EnterEditor({ name = L["New build"], ranks = fromCurrent and ns.CommittedRanks(false) or {} })
end

function ns.ImportFromInspect()
    local unit = ns.inspectUnit
    if not unit then return end
    local classToken = select(2, UnitClass(unit))
    if not classToken then return end
    local name = GetUnitName(unit, true) or UnitName(unit) or "?"
    table.insert(ns.BuildBucket(classToken), { name = name, ranks = ns.CommittedRanks(true) })
    if classToken == ns.PlayerClass() then
        ns.Notify(format(L["Build saved: %s"], name), "ok")
    else
        ns.Notify(format(L["Build saved for %s: %s"], className(classToken), name), "ok")
    end
end

-- Own-class builds must fit the trees; other classes wait untouched in their bucket.
function ns.KeepBuild(decoded)
    local record = { name = decoded.name, ranks = decoded.ranks, reqLevel = decoded.reqLevel }
    if decoded.class ~= ns.PlayerClass() then
        table.insert(ns.BuildBucket(decoded.class), record)
        ns.Notify(format(L["Build saved for %s: %s"], className(decoded.class), record.name), "ok")
        return record, false
    end
    local data = ns.TreeData()
    if not data then
        ns.Notify(L["talent data unavailable"], "error")
        return nil
    end
    if not ns.NormalizeBuild(record, data) then
        ns.Notify(format(L["Talent import: %s"], L["that build doesn't fit your talent trees"]), "error")
        return nil
    end
    table.insert(ns.OwnBuilds(), record)
    ns.Notify(format(L["Build saved: %s"], record.name), "ok")
    return record, true
end

-- Loading a build onto the character as staged preview points -------------------------------------

local function previewRank(tab, index, group)
    local _, _, _, _, _, _, _, _, rank = GetTalentInfo(tab, index, false, false, group)
    return rank or 0
end

-- Blizzard refuses points whose tier or prerequisite isn't staged yet, so sweep until stuck.
local function stagePoints(build, data, group)
    local attempts, moved = 0, true
    while moved and attempts < STAGE_ATTEMPTS do
        moved = false
        for tab = 1, data.count do
            for _, talent in ipairs(data[tab].order) do
                local want = ns.BuildRank(build, tab, talent.index)
                local have = previewRank(tab, talent.index, group)
                while have < want and attempts < STAGE_ATTEMPTS do
                    attempts = attempts + 1
                    AddPreviewTalentPoints(tab, talent.index, 1, false, group)
                    local now = previewRank(tab, talent.index, group)
                    if now <= have then break end
                    have, moved = now, true
                end
            end
        end
    end
end

local function pointsMissing(build, data, group)
    local needed = 0
    for tab = 1, data.count do
        for _, talent in ipairs(data[tab].order) do
            local _, _, _, _, learned = GetTalentInfo(tab, talent.index, false, false, group)
            local want = ns.BuildRank(build, tab, talent.index)
            learned = learned or 0
            if want < learned then return nil end
            needed = needed + (want - learned)
        end
    end
    return needed
end

function ns.LoadOntoCharacter(build)
    local fighting = InCombatLockdown()
    if fighting then
        ns.Notify(ERR_NOT_IN_COMBAT, "error")
        return
    end
    local data = ns.TreeData()
    if not data or not build then return end
    if not ns.NormalizeBuild(build, data) then
        ns.Notify(L["that build doesn't fit your talent trees"], "error")
        return
    end
    local group = ns.ActiveGroup()
    local needed = pointsMissing(build, data, group)
    if not needed then
        -- Wrath cannot un-learn a point; a rank below the character's needs a trainer reset.
        StaticPopup_Show("DUI_TALENT_NEEDS_RESET")
        return
    end
    if needed == 0 then
        ns.Notify(L["Character already matches this build."], "match")
        return
    end
    local unspent = GetUnspentTalentPoints(false, false, group) or 0
    if unspent < needed then
        ns.Notify(format(L["This build needs %d points; you have %d unspent."], needed, unspent), "error")
        return
    end

    ns.ExitEditor()
    ns.viewGroup = group
    SetCVar("previewTalents", "1")
    ResetGroupPreviewTalentPoints(false, group)
    wipe(ns.undo)
    stagePoints(build, data, group)
    ns.Refresh()
    ns.Notify(L["Build staged — click Apply Changes to learn it."], "ok")
end

ns.DefinePopup("DUI_TALENT_NEEDS_RESET",
    L["This build conflicts with talents you've already spent.\n\nVisit your class trainer to reset your talents, then load the build again."],
    OKAY, nil, nil, "dead")
