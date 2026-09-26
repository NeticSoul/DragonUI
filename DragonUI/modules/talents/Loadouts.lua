-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

-- New Era's build manager: an offline editor and account-wide builds per class, shared as DragonUI codes.

local PER_TIER = PLAYER_TALENTS_PER_TIER or 5
local CODE_HEADER = "!DUIT1!"
local CODE_VERSION = 1
local CODE_MAX = 1024
local COMM_PREFIX = "DUI_Talents"
local MAX_NAME_BYTES = 120
local MAX_TALENTS_PER_TAB = 64
local INBOX_MAX = 5
-- Chat links travel as plain text (the server drops unknown |H links); receivers make them clickable.
local LINK_TAG = "DragonUI Talents"
local LINK_KEY = "player::duit:"
local LINK_PATTERN = "%[" .. LINK_TAG .. ": ([^%]]+)%]"
local REQUEST_TIMEOUT = 10
local VALID_CLASS = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    DEATHKNIGHT = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}

local LibDeflate = LibStub("LibDeflate")
local Serializer = {}
LibStub("AceSerializer-3.0"):Embed(Serializer)
local Comm = {}
LibStub("AceComm-3.0"):Embed(Comm)

local function maxLevel()
    return MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or 80
end

local function maxPoints()
    return math.max(1, maxLevel() - 9)
end

local function playerClass()
    return select(2, UnitClass("player"))
end

local function className(classFile)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile or "?"
end

local function message(text, r, g, b)
    UIErrorsFrame:AddMessage(text, r or 1, g or 0.82, b or 0)
end

-- ============================================================================
-- Store
-- ============================================================================
local function store()
    local global = addon.db and addon.db.global
    if not global then return nil end
    global.talentBuilds = global.talentBuilds or {}
    local class = playerClass()
    global.talentBuilds[class] = global.talentBuilds[class] or {}
    return global.talentBuilds[class]
end

function T.SaveBuildForClass(classFile, build)
    local global = addon.db and addon.db.global
    if not (global and classFile and build) then return nil end
    global.talentBuilds = global.talentBuilds or {}
    global.talentBuilds[classFile] = global.talentBuilds[classFile] or {}
    local bucket = global.talentBuilds[classFile]
    bucket[#bucket + 1] = build
    return #bucket
end

-- ============================================================================
-- Tree structure (own class, read once from the live API)
-- ============================================================================
local function buildStructure()
    local class = playerClass()
    if T._struct and T._struct.class == class then return T._struct end
    local numTabs = GetNumTalentTabs(false, false) or 0
    if numTabs == 0 then return nil end
    local s = { class = class, tabs = {} }
    for tab = 1, numTabs do
        local td = { name = GetTalentTabInfo(tab, false, false), talents = {}, cell = {} }
        for i = 1, GetNumTalents(tab, false, false) or 0 do
            local name, icon, tier, column, _, maxRank, isExceptional = GetTalentInfo(tab, i, false, false)
            if name and tier and column then
                local pre, arr = {}, { GetTalentPrereqs(tab, i, false, false) }
                for p = 1, #arr, 4 do pre[#pre + 1] = { tier = arr[p], col = arr[p + 1] } end
                td.talents[i] = {
                    tier = tier, col = column, maxRank = maxRank or 1, icon = icon, name = name,
                    isExceptional = isExceptional, prereqs = pre,
                }
                td.cell[tier * 10 + column] = i
            end
        end
        s.tabs[tab] = td
    end
    T._struct = s
    return s
end

-- ============================================================================
-- Simulation: build = { name, ranks = { [tab] = { [talentIndex] = rank } }, reqLevel }
-- ============================================================================
local function rankOf(b, tab, idx) return (b.ranks[tab] and b.ranks[tab][idx]) or 0 end

local function tabSpent(b, tab)
    local total = 0
    for _, v in pairs(b.ranks[tab] or {}) do total = total + v end
    return total
end

local function totalSpent(b)
    local total = 0
    for tab = 1, 3 do total = total + tabSpent(b, tab) end
    return total
end

local function tierUnlocked(b, tab, tier) return tabSpent(b, tab) >= (tier - 1) * PER_TIER end

-- Auto level (nil) grows with the build; an explicit one caps it, for a build meant for that level.
local function buildLevel(b) return b.reqLevel or math.max(10, 9 + totalSpent(b)) end
local function buildCap(b) return b.reqLevel and math.min(maxPoints(), b.reqLevel - 9) or maxPoints() end

local function prereqsMet(s, b, tab, idx)
    local td = s.tabs[tab]
    for _, pc in ipairs(td.talents[idx].prereqs) do
        local pidx = td.cell[pc.tier * 10 + pc.col]
        if pidx and rankOf(b, tab, pidx) < td.talents[pidx].maxRank then return false end
    end
    return true
end

local function isValid(s, b)
    for tab, td in pairs(s.tabs) do
        for idx, tal in pairs(td.talents) do
            if rankOf(b, tab, idx) > 0 then
                if not tierUnlocked(b, tab, tal.tier) or not prereqsMet(s, b, tab, idx) then return false end
            end
        end
    end
    return true
end

local function canAdd(s, b, tab, idx)
    local tal = s.tabs[tab].talents[idx]
    if rankOf(b, tab, idx) >= tal.maxRank then return false end
    if totalSpent(b) >= buildCap(b) then return false end
    if not tierUnlocked(b, tab, tal.tier) then return false end
    return prereqsMet(s, b, tab, idx)
end

-- Removing must leave the build valid: no stranded tiers, no orphaned dependents.
local function canRemove(s, b, tab, idx)
    if rankOf(b, tab, idx) <= 0 then return false end
    b.ranks[tab][idx] = b.ranks[tab][idx] - 1
    local ok = isValid(s, b)
    b.ranks[tab][idx] = b.ranks[tab][idx] + 1
    return ok
end

local function dominantTab(b)
    local best, bestTab = -1, 1
    for tab = 1, 3 do
        local spent = tabSpent(b, tab)
        if spent > best then best, bestTab = spent, tab end
    end
    return bestTab
end

-- Codes and shares carry ranks that were never checked against the real trees; a stuck build can't be edited.
local function fitsTrees(s, b)
    for tab, ranks in pairs(b.ranks) do
        local td = s.tabs[tab]
        for idx, r in pairs(ranks) do
            local tal = td and td.talents[idx]
            if not tal then
                ranks[idx] = nil
            elseif r > tal.maxRank then
                ranks[idx] = tal.maxRank
            end
        end
    end
    local spent = totalSpent(b)
    if b.reqLevel and b.reqLevel < 9 + spent then b.reqLevel = math.min(maxLevel(), 9 + spent) end
    return isValid(s, b) and spent <= buildCap(b)
end

-- ============================================================================
-- Codes: AceSerializer + LibDeflate like the profile export, ranks by talent index
-- ============================================================================
local function digitsOf(ranks)
    local top = 0
    for idx in pairs(ranks or {}) do
        if type(idx) == "number" and idx > top then top = idx end
    end
    local out = {}
    for idx = 1, top do out[idx] = tostring(math.min(9, ranks[idx] or 0)) end
    return (table.concat(out):gsub("0+$", ""))
end

local function encode(build, classFile)
    local r = {}
    for tab = 1, 3 do r[tab] = digitsOf(build.ranks and build.ranks[tab]) end
    local data = { v = CODE_VERSION, c = classFile, n = build.name, l = build.reqLevel, r = r }
    local compressed = LibDeflate:CompressDeflate(Serializer:Serialize(data))
    return CODE_HEADER .. LibDeflate:EncodeForPrint(compressed)
end

local function clipName(name)
    name = strtrim((name:gsub("[%c|]", "")))
    if #name <= MAX_NAME_BYTES then return name end
    -- Cut on a character boundary: a split UTF-8 sequence renders as garbage in the menu.
    return (name:sub(1, MAX_NAME_BYTES):gsub("[\192-\255][\128-\191]*$", ""))
end

-- Everything here arrives from a paste or another player, so nothing is trusted.
local function decode(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%s", "")
    if text:sub(1, #CODE_HEADER) ~= CODE_HEADER or #text > CODE_MAX then return nil end
    local compressed = LibDeflate:DecodeForPrint(text:sub(#CODE_HEADER + 1))
    local serialized = compressed and LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil end
    local ok, data = Serializer:Deserialize(serialized)
    if not (ok and type(data) == "table" and data.v == CODE_VERSION) then return nil end
    if not (VALID_CLASS[data.c] and type(data.r) == "table") then return nil end

    local build = { ranks = {} }
    for tab = 1, 3 do
        local seg = data.r[tab]
        if seg ~= nil then
            if type(seg) ~= "string" or #seg > MAX_TALENTS_PER_TAB or seg:find("%D") then return nil end
            for k = 1, #seg do
                local d = tonumber(seg:sub(k, k))
                if d > 0 then
                    build.ranks[tab] = build.ranks[tab] or {}
                    build.ranks[tab][k] = d
                end
            end
        end
    end
    local spent = totalSpent(build)
    if spent == 0 or spent > maxPoints() then return nil end

    local name = type(data.n) == "string" and clipName(data.n) or ""
    build.name = (name ~= "") and name or L["Imported"]
    local lvl = tonumber(data.l)
    if lvl then build.reqLevel = math.max(10, math.min(maxLevel(), math.floor(lvl))) end
    return build, data.c
end

function T.ExportCode(build)
    return build and encode(build, playerClass())
end

-- Own-class builds must fit the live trees; another class's wait in its bucket until that character opens them.
local function keepBuild(build, classFile)
    if classFile == playerClass() then
        local s = buildStructure()
        if not s then
            message(L["talent data unavailable"], 1, 0.3, 0.3)
            return false
        end
        if not fitsTrees(s, build) then
            message(L["Talent import: %s"]:format(L["that build doesn't fit your talent trees"]), 1, 0.3, 0.3)
            return false
        end
        local st = store()
        if not st then return false end
        st[#st + 1] = build
        message(L["Build saved: %s"]:format(build.name or "?"), 0.2, 1, 0.2)
        return true
    end
    if not T.SaveBuildForClass(classFile, build) then return false end
    message(L["Build saved for %s: %s"]:format(className(classFile), build.name or "?"), 0.2, 1, 0.2)
    return true
end

-- ============================================================================
-- Editor
-- ============================================================================
function T.EditNodeClick(node, button)
    local b, s = T._editBuild, T._struct
    if not (b and s and node._tab and node._index) then return end
    local tab, idx = node._tab, node._index
    if button == "LeftButton" and canAdd(s, b, tab, idx) then
        b.ranks[tab] = b.ranks[tab] or {}
        b.ranks[tab][idx] = rankOf(b, tab, idx) + 1
        T.PlayStageSFX(true)
    elseif button == "RightButton" and canRemove(s, b, tab, idx) then
        b.ranks[tab][idx] = b.ranks[tab][idx] - 1
        T.PlayStageSFX(false)
    else
        return
    end
    T.PopulateEdit()
    if GameTooltip:IsOwned(node) then
        GameTooltip:SetOwner(node, "ANCHOR_RIGHT")
        T.EditTooltip(node)
    end
end

-- SetTalent always shows the character's live rank, so the build's own rank goes underneath.
function T.EditTooltip(node)
    local s, b = T._struct, T._editBuild
    local tal = s and s.tabs[node._tab] and s.tabs[node._tab].talents[node._index]
    GameTooltip:SetTalent(node._tab, node._index, false, false, GetActiveTalentGroup(false, false))
    if tal and b then
        local rank = rankOf(b, node._tab, node._index)
        GameTooltip:AddLine(" ")
        if rank > 0 then
            GameTooltip:AddLine(L["In this build: rank %d / %d"]:format(rank, tal.maxRank), 0.12, 1, 0)
        else
            GameTooltip:AddLine(L["Not in this build"], 0.5, 0.5, 0.5)
        end
        if canAdd(s, b, node._tab, node._index) then GameTooltip:AddLine(TALENT_TOOLTIP_ADDPREVIEWPOINT, 0.2, 1, 0.2) end
        if canRemove(s, b, node._tab, node._index) then GameTooltip:AddLine(TALENT_TOOLTIP_REMOVEPREVIEWPOINT, 1, 0.4, 0.4) end
    end
    GameTooltip:Show()
end

function T.PopulateEdit()
    local f, s, b = T.frame, T._struct, T._editBuild
    if not (f and s and b) then return end
    T.PlaceTrees(f, false, 1)
    for tab = 1, 3 do
        local tf = f.trees[tab]
        tf:ResetEdges()
        local used = {}
        local td = s.tabs[tab]
        if td then
            tf:Show()
            T.SetHeader(tf, td.name, tabSpent(b, tab))
            for idx, tal in pairs(td.talents) do
                local node = tf:AcquireNode(idx)
                used[idx] = true
                local rank = rankOf(b, tab, idx)
                local state
                if rank > 0 then
                    state = "yellow"
                elseif canAdd(s, b, tab, idx) then
                    state = "green"
                elseif tierUnlocked(b, tab, tal.tier) then
                    state = "gray"
                else
                    state = "locked"
                end
                node._tab, node._index, node._isPet, node._inspect = tab, idx, false, false
                node._talentName = tal.name
                node:SetVisual(T.ResolveShape(tal), state, tal.icon, (rank > 0) and tostring(rank) or "")
                node:PlaceAt(tf, T.nodeCenter(tal.tier, tal.col))
                node:Show()
                T.WireNode(node)
            end
            for _, tal in pairs(td.talents) do
                for _, pc in ipairs(tal.prereqs) do
                    local pidx = td.cell[pc.tier * 10 + pc.col]
                    if pidx then
                        T.DrawEdge(tf, pc.tier, pc.col, tal.tier, tal.col, rankOf(b, tab, pidx) >= td.talents[pidx].maxRank)
                    end
                end
            end
        else
            tf:Hide()
        end
        tf:HideUnusedNodes(used)
        tf:HideUnusedEdges()
    end

    local auto = b.reqLevel and "" or (" |cff808080" .. L["(auto)"] .. "|r")
    f.pointsText:SetText(L["%d / %d points · Level %d"]:format(totalSpent(b), buildCap(b), buildLevel(b)) .. auto)
    T.SetPortraitClass(playerClass())
    if f.petBg then f.petBg:Hide() end
    f.bg:Show()
    T.SetBackground(dominantTab(b))
    if f.loadout then f.loadout:SetSelection(b.name) end
    T.ApplyChrome()
    if T.ApplySearch then T.ApplySearch() end
end

StaticPopupDialogs["DUI_TALENT_EXIT_EDITOR"] = {
    text = L["This build isn't saved — exit and discard it?"],
    button1 = L["Discard"], button2 = CANCEL,
    OnAccept = function() T.ExitEditor() end,
    hideOnEscape = 1, timeout = 0, whileDead = 1,
}

local function isStored(b)
    local st = store()
    if not (b and st) then return false end
    for _, e in ipairs(st) do if e == b then return true end end
    return false
end

function T.RequestExitEditor()
    local b = T._editBuild
    if b and not isStored(b) and totalSpent(b) > 0 then
        StaticPopup_Show("DUI_TALENT_EXIT_EDITOR")
        return
    end
    T.ExitEditor()
end

function T.EnterEditor(build)
    local s = buildStructure()
    if not s then
        message(L["talent data unavailable"], 1, 0.3, 0.3)
        return
    end
    build.ranks = build.ranks or {}
    if not fitsTrees(s, build) then
        message(L["that build doesn't fit your talent trees"], 1, 0.3, 0.3)
        return
    end
    if T._mode == "inspect" then T.ClearInspect() end
    T._editBuild = build
    T._mode = "edit"
    T.SetPetView(false)
    T.SetGlyphView(false)
    if T.frame:IsShown() then
        T.PopulateEdit()
        if T.RefreshSpecTabs then T.RefreshSpecTabs() end
    else
        T.frame:Show()
    end
end

function T.ExitEditor()
    if T._mode ~= "edit" then return end
    T._mode = nil
    T._editBuild = nil
    local f = T.frame
    if f and f.loadout then f.loadout:SetSelection(L["Talent Builds"]) end
    T.Refresh()
end

-- The PR's "save my current spec" lives on as a starting point for the editor.
local function currentBuild()
    local ranks = {}
    local group = GetActiveTalentGroup(false, false) or 1
    for tab = 1, GetNumTalentTabs(false, false) or 0 do
        for i = 1, GetNumTalents(tab, false, false) or 0 do
            local _, _, _, _, rank = GetTalentInfo(tab, i, false, false, group)
            if (rank or 0) > 0 then
                ranks[tab] = ranks[tab] or {}
                ranks[tab][i] = rank
            end
        end
    end
    return { name = L["New build"], ranks = ranks }
end

-- Wrath cannot un-learn points either: a build that drops a spent point needs a trainer reset.
StaticPopupDialogs["DUI_TALENT_NEEDS_RESET"] = {
    text = L["This build conflicts with talents you've already spent.\n\nVisit your class trainer to reset your talents, then load the build again."],
    button1 = OKAY, timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function T.ApplyBuildToCharacter(build)
    if InCombatLockdown() then
        message(ERR_NOT_IN_COMBAT, 1, 0.3, 0.3)
        return
    end
    local s = buildStructure()
    if not (build and s) then return end
    if not fitsTrees(s, build) then
        message(L["that build doesn't fit your talent trees"], 1, 0.3, 0.3)
        return
    end
    local group = GetActiveTalentGroup(false, false) or 1
    local diverges, needed = false, 0
    for tab, td in pairs(s.tabs) do
        for idx in pairs(td.talents) do
            local _, _, _, _, committed = GetTalentInfo(tab, idx, false, false, group)
            local target = rankOf(build, tab, idx)
            committed = committed or 0
            if target < committed then diverges = true end
            if target > committed then needed = needed + (target - committed) end
        end
    end
    if diverges then
        StaticPopup_Show("DUI_TALENT_NEEDS_RESET")
        return
    end
    if needed == 0 then
        message(L["Character already matches this build."], 0.8, 0.8, 0.2)
        return
    end
    local unspent = GetUnspentTalentPoints(false, false, group) or 0
    if needed > unspent then
        message(L["This build needs %d points; you have %d unspent."]:format(needed, unspent), 1, 0.3, 0.3)
        return
    end

    T.ExitEditor()
    T.SetViewGroup(nil)
    SetCVar("previewTalents", "1")
    ResetGroupPreviewTalentPoints(false, group)
    T.ClearUndo()
    -- AddPreviewTalentPoints enforces tiers and prereqs itself, so repeat until nothing more fits.
    for _ = 1, 120 do
        local added = false
        for tab, td in pairs(s.tabs) do
            for idx in pairs(td.talents) do
                local _, _, _, _, _, _, _, _, before = GetTalentInfo(tab, idx, false, false, group)
                if rankOf(build, tab, idx) > (before or 0) then
                    AddPreviewTalentPoints(tab, idx, 1, false, group)
                    local _, _, _, _, _, _, _, _, after = GetTalentInfo(tab, idx, false, false, group)
                    if (after or 0) > (before or 0) then added = true end
                end
            end
        end
        if not added then break end
    end
    T.Refresh()
    message(L["Build staged — click Apply Changes to learn it."], 0.2, 1, 0.2)
end

-- ============================================================================
-- Popups
-- ============================================================================
local function nameBox(self) return self.editBox end

StaticPopupDialogs["DUI_TALENT_BUILD_NAME"] = {
    text = L["Name this build:"],
    button1 = SAVE, button2 = CANCEL,
    hasEditBox = 1, maxLetters = 40, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self, data)
        local e = nameBox(self)
        e:SetText((data and data.preset) or "")
        e:HighlightText()
        e:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(nameBox(self):GetText() or "")
        if name ~= "" and data and data.cb then data.cb(name) end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopup_OnClick(parent, 1)
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

local function promptName(preset, cb)
    StaticPopup_Show("DUI_TALENT_BUILD_NAME", nil, nil, { preset = preset, cb = cb })
end

StaticPopupDialogs["DUI_TALENT_BUILD_LEVEL"] = {
    text = L["Level required for this build (10-%d).\nLeave blank for automatic (grows with the build)."],
    button1 = OKAY, button2 = CANCEL,
    hasEditBox = 1, maxLetters = 3, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self)
        local b = T._editBuild
        local e = nameBox(self)
        e:SetText((b and b.reqLevel) and tostring(b.reqLevel) or "")
        e:HighlightText()
        e:SetFocus()
    end,
    OnAccept = function(self)
        local b = T._editBuild
        if not b then return end
        local txt = strtrim(nameBox(self):GetText() or "")
        if txt == "" then
            b.reqLevel = nil
        else
            local n = tonumber(txt)
            if not n then return end
            -- A level below what the build already spends would strand its points.
            local floor = math.max(10, 9 + totalSpent(b))
            local clamped = math.max(floor, math.min(maxLevel(), math.floor(n)))
            if clamped ~= n then message(L["Level clamped to %d (build size / level cap)."]:format(clamped)) end
            b.reqLevel = clamped
        end
        if T._mode == "edit" then T.PopulateEdit() end
    end,
    EditBoxOnEnterPressed = function(self) StaticPopup_OnClick(self:GetParent(), 1) end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

StaticPopupDialogs["DUI_TALENT_IMPORT"] = {
    text = L["Paste a DragonUI talent code:"],
    button1 = L["Import"], button2 = CANCEL,
    hasEditBox = 1, hasWideEditBox = 1, maxLetters = 0, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self)
        self.wideEditBox:SetText("")
        self.wideEditBox:SetFocus()
    end,
    OnAccept = function(self)
        local build, classFile = decode(self.wideEditBox:GetText())
        if not build then
            message(L["Talent import: %s"]:format(L["couldn't read a talent code"]), 1, 0.3, 0.3)
        elseif keepBuild(build, classFile) and classFile == playerClass() then
            T.EnterEditor(build)
        end
    end,
    EditBoxOnEnterPressed = function(self) StaticPopup_OnClick(self:GetParent(), 1) end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

StaticPopupDialogs["DUI_TALENT_EXPORT"] = {
    text = L["Talent build code (Ctrl+C to copy):"],
    button1 = CLOSE,
    hasEditBox = 1, hasWideEditBox = 1, maxLetters = 0, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self, data)
        local e = self.wideEditBox
        e:SetText((data and data.code) or "")
        e:HighlightText()
        e:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

StaticPopupDialogs["DUI_TALENT_DELETE_BUILD"] = {
    text = L["Delete loadout '%s'? This cannot be undone."],
    button1 = DELETE, button2 = CANCEL,
    OnAccept = function(_, data)
        local st = store()
        if not (st and data) then return end
        for i, e in ipairs(st) do
            if e == data then
                if T._editBuild == e then T.ExitEditor() end
                table.remove(st, i)
                return
            end
        end
    end,
    hideOnEscape = 1, timeout = 0, whileDead = 1,
}

local function exportPopup(build)
    StaticPopup_Show("DUI_TALENT_EXPORT", nil, nil, { code = T.ExportCode(build) })
end

function T.SaveEditBuild()
    local b = T._editBuild
    local st = store()
    if not (b and st) then return end
    if isStored(b) then
        message(L["Build saved: %s"]:format(b.name or "?"), 0.2, 1, 0.2)
        return
    end
    promptName(b.name ~= L["New build"] and b.name or "", function(name)
        b.name = name
        st[#st + 1] = b
        message(L["Build saved: %s"]:format(name), 0.2, 1, 0.2)
        if T._mode == "edit" then T.PopulateEdit() end
    end)
end

local function renameBuild(b)
    promptName(b.name, function(name)
        b.name = name
        if T._editBuild == b then T.PopulateEdit() end
    end)
end

-- ============================================================================
-- Sharing with other DragonUI players (AceComm splits and rejoins long codes)
-- ============================================================================
local function shareWithGuild(build)
    Comm:SendCommMessage(COMM_PREFIX, T.ExportCode(build), "GUILD", nil, "BULK")
    message(L["Build sent (%s). Only DragonUI players will see it."]:format(GUILD), 0.2, 1, 0.2)
end

local inbox, seen, showing = {}, {}, false
local posted, requested, answered = {}, {}, {}

local function showNext()
    if showing or #inbox == 0 or InCombatLockdown() then return end
    local entry = table.remove(inbox, 1)
    local label = ("%s |cff808080(%s)|r"):format(entry.build.name, className(entry.class))
    showing = true
    if not StaticPopup_Show("DUI_TALENT_SHARED", entry.sender, label, entry) then
        showing = false
        table.insert(inbox, 1, entry)
    end
end

StaticPopupDialogs["DUI_TALENT_SHARED"] = {
    text = L["%s shared a talent build with you:"] .. "\n\n%s",
    button1 = SAVE, button2 = DECLINE,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(_, entry) if entry then keepBuild(entry.build, entry.class) end end,
    OnHide = function()
        showing = false
        addon:After(0.2, showNext)
    end,
}

-- Only builds this player posted this session are handed out, and at most once every few seconds per asker.
local function answerRequest(name, sender, dist)
    local code = posted[name]
    if dist ~= "WHISPER" or not code then return end
    local key = sender .. "\001" .. name
    local now = GetTime()
    if answered[key] and now - answered[key] < 3 then return end
    answered[key] = now
    Comm:SendCommMessage(COMM_PREFIX, code, "WHISPER", sender, "BULK")
end

-- A guild-wide stranger can reach us here, so every share waits for an explicit yes and the queue is capped.
Comm:RegisterComm(COMM_PREFIX, function(_, text, dist, sender)
    if not (T.applied and sender and text) or sender == UnitName("player") then return end
    if text:sub(1, 1) == "?" then
        answerRequest(text:sub(2), sender, dist)
        return
    end
    local key = sender .. "\001" .. text
    local now = GetTime()
    local asked = requested[sender] and now - requested[sender] < REQUEST_TIMEOUT
    requested[sender] = nil
    if seen[key] and now - seen[key] < 60 and not asked then return end
    seen[key] = now
    if #inbox >= INBOX_MAX then return end
    local build, classFile = decode(text)
    if not build then return end
    inbox[#inbox + 1] = { sender = sender, build = build, class = classFile }
    showNext()
end)

local inboxEvents = CreateFrame("Frame")
inboxEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
inboxEvents:SetScript("OnEvent", showNext)

local function linkName(name)
    return (strtrim(((name or "?"):gsub("[%c|%[%]]", ""))))
end

local function postLink(build)
    local name = linkName(build.name)
    if name == "" then name = L["Imported"] end
    posted[name] = T.ExportCode(build)
    local token = ("[%s: %s]"):format(LINK_TAG, name)
    if not ChatEdit_GetActiveWindow() then ChatFrame_OpenChat("") end
    ChatEdit_InsertLink(token)
end

local function requestBuild(owner, name)
    if owner == UnitName("player") then
        if posted[name] then StaticPopup_Show("DUI_TALENT_EXPORT", nil, nil, { code = posted[name] }) end
        return
    end
    local stamp = GetTime()
    requested[owner] = stamp
    Comm:SendCommMessage(COMM_PREFIX, "?" .. name, "WHISPER", owner, "BULK")
    message(L["Asking %s for the build…"]:format(owner), 0.8, 0.8, 0.8)
    addon:After(REQUEST_TIMEOUT, function()
        if requested[owner] == stamp then
            requested[owner] = nil
            message(L["%s didn't answer — they may be offline or not running DragonUI."]:format(owner), 1, 0.3, 0.3)
        end
    end)
end

local LINK_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL",
}

local function linkFilter(_, event, msg, sender, ...)
    if not (T.applied and type(msg) == "string" and sender) or not msg:find(LINK_TAG, 1, true) then return false end
    -- On a whisper we sent, the sender field is the recipient: the link is still ours.
    local owner = (event == "CHAT_MSG_WHISPER_INFORM") and UnitName("player") or sender
    local out = msg:gsub(LINK_PATTERN, function(name)
        return ("|cff71d5ff|H%s%s:%s|h[%s: %s]|h|r"):format(LINK_KEY, owner, name, LINK_TAG, name)
    end)
    return false, out, sender, ...
end

-- A "player::" link with no name is a no-op for SetItemRef, so the secure hook runs on a clean call.
T.OnBuild(function()
    for _, event in ipairs(LINK_EVENTS) do ChatFrame_AddMessageEventFilter(event, linkFilter) end
    hooksecurefunc("SetItemRef", function(link)
        if not (T.applied and type(link) == "string") or link:sub(1, #LINK_KEY) ~= LINK_KEY then return end
        local owner, name = link:sub(#LINK_KEY + 1):match("^([^:]+):(.*)$")
        if owner and name ~= "" then requestBuild(owner, name) end
    end)
end)

-- ============================================================================
-- Menu
-- ============================================================================
local function shareEntries(b)
    return {
        { text = L["Post link in chat"], func = function() postLink(b) end },
        { text = GUILD, disabled = not IsInGuild(), func = function() shareWithGuild(b) end },
        { text = L["Copy code"], func = function() exportPopup(b) end },
    }
end

local function buildEntries(b)
    return {
        { text = L["Load onto character"], func = function() T.ApplyBuildToCharacter(b) end },
        { text = L["Edit"], func = function() T.EnterEditor(b) end },
        { text = L["Rename"], func = function() renameBuild(b) end },
        { text = L["Share"], menu = function() return shareEntries(b) end },
        { text = DELETE, func = function() StaticPopup_Show("DUI_TALENT_DELETE_BUILD", b.name or "?", nil, b) end },
    }
end

-- Points per tree plus the level, the way the build list reads at a glance.
local function buildDetail(b)
    local parts = {}
    for tab = 1, 3 do parts[tab] = tostring(tabSpent(b, tab)) end
    return ("%s   %s %d"):format(table.concat(parts, "/"), LEVEL, buildLevel(b))
end

-- New Era's order: editor block, then the builds, then import, with the same dividers.
local function rootEntries()
    local entries = {}
    local function add(e) entries[#entries + 1] = e end
    local b = T._editBuild
    local editing = T._mode == "edit" and b
    if editing then
        add({ text = L["Editing: %s"]:format(b.name or ""), isTitle = true })
        add({ text = SAVE, func = T.SaveEditBuild })
        add({
            text = L["Level Required: %d"]:format(buildLevel(b)) .. (b.reqLevel and "" or (" " .. L["(auto)"])),
            func = function() StaticPopup_Show("DUI_TALENT_BUILD_LEVEL", maxLevel()) end,
        })
        add({ text = L["Exit Editor"], func = T.RequestExitEditor })
        add({ isDivider = true })
    end
    add({ text = L["Talent Builds"], isTitle = true })
    add({ text = L["New build"], func = function() T.EnterEditor({ name = L["New build"], ranks = {} }) end })
    add({ text = L["New build from current talents"], func = function() T.EnterEditor(currentBuild()) end })
    local st = store() or {}
    if #st > 0 then add({ isDivider = true }) end
    for _, stored in ipairs(st) do
        add({ text = stored.name or "?", detail = buildDetail(stored), menu = function() return buildEntries(stored) end })
    end
    add({ isDivider = true })
    add({ text = L["Import code…"], func = function() StaticPopup_Show("DUI_TALENT_IMPORT") end })
    if editing then
        add({ text = L["Load onto character"], func = function() T.ApplyBuildToCharacter(b) end })
        add({ text = L["Share"], menu = function() return shareEntries(b) end })
    end
    return entries
end

-- ============================================================================
-- Dropdown and editor footer
-- ============================================================================
local DROPDOWN_W, DROPDOWN_H = 200, 24
-- New Era's WowStyle1 shell (overhang (-8,7)/(8,-9), slices 16/14/16/18), shrunk from its 30px to our 24px bar.
local ART = DROPDOWN_H / 30
local BG_L, BG_T, BG_R, BG_B = -8 * ART, 7 * ART, 8 * ART, -9 * ART
local SLICE_L, SLICE_T, SLICE_R, SLICE_B = 16, 14, 16, 18
local ARROW_SIZE, ARROW_X, ARROW_Y, TEXT_X = 27 * ART, 1 * ART, -3 * ART, 10 * ART

-- 3.3.5a has no SetTextureSliceMargins, so the nine pieces are laid out by hand.
local function nineSlice(dd, atlas)
    local a = addon.atlasinfo[atlas]
    local file, w, h, l, r, t, b = a[1], a[2], a[3], a[4], a[5], a[6], a[7]
    local du, dv = (r - l) / w, (b - t) / h
    local us = { l, l + SLICE_L * du, r - SLICE_R * du, r }
    local vs = { t, t + SLICE_T * dv, b - SLICE_B * dv, b }
    local xs = { SLICE_L * ART, nil, SLICE_R * ART }
    local ys = { SLICE_T * ART, nil, SLICE_B * ART }
    local pieces = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = dd:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture(file)
            tex:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
            if xs[col] then tex:SetWidth(xs[col]) end
            if ys[row] then tex:SetHeight(ys[row]) end
            pieces[(row - 1) * 3 + col] = tex
        end
    end
    pieces[1]:SetPoint("TOPLEFT", dd, "TOPLEFT", BG_L, BG_T)
    pieces[3]:SetPoint("TOPRIGHT", dd, "TOPRIGHT", BG_R, BG_T)
    pieces[7]:SetPoint("BOTTOMLEFT", dd, "BOTTOMLEFT", BG_L, BG_B)
    pieces[9]:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", BG_R, BG_B)
    pieces[2]:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT")
    pieces[2]:SetPoint("TOPRIGHT", pieces[3], "TOPLEFT")
    pieces[8]:SetPoint("BOTTOMLEFT", pieces[7], "BOTTOMRIGHT")
    pieces[8]:SetPoint("BOTTOMRIGHT", pieces[9], "BOTTOMLEFT")
    pieces[4]:SetPoint("TOPLEFT", pieces[1], "BOTTOMLEFT")
    pieces[4]:SetPoint("BOTTOMLEFT", pieces[7], "TOPLEFT")
    pieces[6]:SetPoint("TOPRIGHT", pieces[3], "BOTTOMRIGHT")
    pieces[6]:SetPoint("BOTTOMRIGHT", pieces[9], "TOPRIGHT")
    pieces[5]:SetPoint("TOPLEFT", pieces[1], "BOTTOMRIGHT")
    pieces[5]:SetPoint("BOTTOMRIGHT", pieces[9], "TOPLEFT")
end

local function buildDropdown(parent)
    local dd = CreateFrame("Button", "DragonUI_TalentLoadoutDropdown", parent)
    dd:SetSize(DROPDOWN_W, DROPDOWN_H)
    nineSlice(dd, "common-dropdown-textholder")

    local arrow = dd:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("RIGHT", dd, "RIGHT", ARROW_X, ARROW_Y)

    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", dd, "LEFT", TEXT_X, 0)
    label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    label:SetJustifyH("LEFT")
    function dd:SetSelection(text) label:SetText(text or "") end
    dd:SetSelection(L["Talent Builds"])

    local over, down = false, false
    local function restate()
        local suffix = ""
        if addon.Menu.IsOpenFor(dd) then
            suffix = "-open"
        elseif down and over then
            suffix = "-pressedhover"
        elseif down then
            suffix = "-pressed"
        elseif over then
            suffix = "-hover"
        end
        arrow:set_atlas("common-dropdown-a-button" .. suffix)
    end
    restate()

    dd:SetScript("OnEnter", function(self)
        over = true
        restate()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Talent Builds"], 1, 1, 1)
        GameTooltip:AddLine(L["Design and save builds offline — no points needed."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    dd:SetScript("OnLeave", function()
        over = false
        restate()
        GameTooltip:Hide()
    end)
    dd:SetScript("OnMouseDown", function() down = true; restate() end)
    -- Next frame: the menu's shown state only settles after the click has been handled.
    dd:SetScript("OnMouseUp", function() down = false; addon:After(0, restate) end)
    dd:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        addon.Menu.Open(self, rootEntries())
        PlaySound("igMainMenuOptionCheckBoxOn")
        restate()
    end)
    dd:SetScript("OnHide", function() addon.Menu.Close() end)
    return dd
end

T.OnBuild(function(f)
    f.loadout = buildDropdown(f.barFrame)
    f.loadout:SetPoint("LEFT", f.barFrame, "LEFT", 14, 0)

    f.editExit = CreateFrame("Button", "DragonUI_TalentEditExit", f.barFrame, "UIPanelButtonTemplate")
    f.editExit:SetSize(100, 22)
    f.editExit:SetPoint("LEFT", f.apply, "RIGHT", 8, 0)
    f.editExit:SetText(L["Exit Editor"])
    f.editExit:SetScript("OnClick", function() T.RequestExitEditor() end)
    f.editExit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Exit Editor"], 1, 1, 1)
        GameTooltip:AddLine(L["Back to your live talents. Saved builds keep every change."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.editExit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addon.SkinRedButton(f.editExit)
    f.editExit:Hide()

    -- Inspect footer: the only action on someone else's build is keeping a copy of it.
    f.inspectImport = CreateFrame("Button", "DragonUI_TalentInspectImport", f.barFrame, "UIPanelButtonTemplate")
    f.inspectImport:SetSize(180, 22)
    f.inspectImport:SetPoint("CENTER", f.barFrame, "CENTER", 0, 1)
    f.inspectImport:SetText(L["Import to My Profiles"])
    f.inspectImport:SetScript("OnClick", function() T.ImportInspected() end)
    f.inspectImport:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Import to My Profiles"], 1, 1, 1)
        GameTooltip:AddLine(L["Save this build to your talent profiles."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.inspectImport:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addon.SkinRedButton(f.inspectImport)
    f.inspectImport:Hide()
end)

function T.SetInspectChrome()
    if T.frame then T.ApplyChrome() end
end

-- A build of another class is kept under that class, for when that character next opens the window.
function T.ImportInspected()
    local unit = T._inspectUnit
    if not unit then return end
    local _, classFile = UnitClass(unit)
    local group = GetActiveTalentGroup(true, false) or 1
    local ranks = {}
    for tab = 1, GetNumTalentTabs(true, false) or 0 do
        for i = 1, GetNumTalents(tab, true, false) or 0 do
            local _, _, _, _, rank = GetTalentInfo(tab, i, true, false, group)
            if (rank or 0) > 0 then
                ranks[tab] = ranks[tab] or {}
                ranks[tab][i] = rank
            end
        end
    end
    local name = GetUnitName(unit, true) or UnitName(unit) or "?"
    if T.SaveBuildForClass(classFile, { name = name, ranks = ranks }) then
        if classFile == playerClass() then
            message(L["Build saved: %s"]:format(name), 0.2, 1, 0.2)
        else
            message(L["Build saved for %s: %s"]:format(className(classFile), name), 0.2, 1, 0.2)
        end
    end
end
