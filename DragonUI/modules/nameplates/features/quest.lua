local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates quest icons: mark a plate's mob as a kill/loot objective with our own
-- texture. Backend picked once at load: C_QuestLog.GetUnitQuestInfo if present, else a
-- tooltip scan + quest-log crossref. Needs a token (stock: target/mouseover/focus).

NP.quest = NP.quest or {}

local strmatch = string.match

-- Capability probe (once): improved clients expose this; stock 3.3.5a does not.
local hasQuestApi = (C_QuestLog and type(C_QuestLog.GetUnitQuestInfo) == "function") and true or false

-- Tooltip backend only: hidden scanner (never GameTooltip, so it can't fight the
-- visible tooltip) and threat-line filter. Not created on API clients.
local QuestScanTip, threatPattern
if not hasQuestApi then
    QuestScanTip = CreateFrame("GameTooltip", "DragonUINPQuestScan", UIParent, "GameTooltipTemplate")
    QuestScanTip:SetOwner(UIParent, "ANCHOR_NONE")
    -- Threat % line ("50% Threat") also parses as percent progress; filter it out.
    threatPattern = THREAT_TOOLTIP and THREAT_TOOLTIP:gsub("%%d", "%%d+")
end

local function IsThreatLine(text)
    return threatPattern ~= nil and strmatch(text, threatPattern) ~= nil
end

-- normalizedObjectiveText -> "loot" | "kill"
local objectiveTypeIndex = {}
local indexBuilt = false
-- Bumped on every quest log event; part of each plate's scan cache key.
local questLogVersion = 0
-- Engine tick of the last rebuild; coalesces QUEST_LOG_UPDATE bursts within a tick.
local lastBuildFrame = nil

local SCAN_TTL = 0.7

-- Normalize tooltip lines and leaderboard text to one locale-agnostic key.
local function NormalizeObjectiveText(text)
    if not text then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("%b[]", "")
    text = text:gsub("%b()", "")
    text = text:gsub("%d+%s*/%s*%d+", "")
    text = text:gsub("[%d%.]+%%", "")
    text = text:gsub("%p", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s*(.-)%s*$", "%1")
    return text:lower()
end

local function RebuildObjectiveIndex()
    wipe(objectiveTypeIndex)
    local selection = GetQuestLogSelection()
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if not isHeader and not isComplete then
            SelectQuestLogEntry(i)
            local numObj = GetNumQuestLeaderBoards(i)
            for o = 1, numObj do
                local desc, objType, finished = GetQuestLogLeaderBoard(o, i)
                if desc and not finished then
                    local norm = NormalizeObjectiveText(desc)
                    if norm and norm ~= "" then
                        objectiveTypeIndex[norm] =
                            (objType == "item" or objType == "object") and "loot" or "kill"
                    end
                end
            end
        end
    end
    SelectQuestLogEntry(selection)
    indexBuilt = true
end

local function EnsureIndexBuilt()
    if not indexBuilt then
        RebuildObjectiveIndex()
    end
end

-- Returns hasObj, objType, tag; pointerMode skips the kill/loot crossref.
local function ScanUnitForQuest(unit, pointerMode)
    -- Show() populates the dynamic quest lines; same-frame Hide() = no visible flicker.
    QuestScanTip:SetOwner(UIParent, "ANCHOR_NONE")
    QuestScanTip:ClearLines()
    QuestScanTip:SetUnit(unit)
    QuestScanTip:Show()
    local numLines = QuestScanTip:NumLines()

    local hasObj = false
    local foundKill, foundLoot = false, false
    local killKey, lootKey
    for i = 2, numLines do
        local fs = _G["DragonUINPQuestScanTextLeft" .. i]
        local text = fs and fs.GetText and fs:GetText()
        if text and text ~= "" and not IsThreatLine(text) then
            local incomplete = false
            local done, total = strmatch(text, "(%d+)%s*/%s*(%d+)")
            if done and total then
                incomplete = tonumber(done) < tonumber(total)
            else
                local pct = tonumber(strmatch(text, "([%d%.]+)%%"))
                if pct then incomplete = pct < 100 end
            end
            if incomplete then
                if pointerMode then
                    hasObj = true
                    break
                end
                local norm = NormalizeObjectiveText(text) or ""
                local t = objectiveTypeIndex[norm]
                if t == "loot" then
                    foundLoot, lootKey = true, norm
                elseif t == "kill" then
                    foundKill, killKey = true, norm
                end
            end
        end
    end
    QuestScanTip:Hide()

    if not pointerMode then
        if foundLoot and not foundKill then
            return true, "loot", lootKey
        elseif foundKill or foundLoot then
            return true, "kill", killKey or lootKey
        end
        return false, nil, nil
    end
    return hasObj, nil, nil
end

-- API backend: collect -> loot, objective -> kill; a set talkToMe = quest-giver (skip).
local function ResolveQuestViaApi(unit, pointerMode)
    local questStatus, questID, talkToMe = C_QuestLog.GetUnitQuestInfo(unit)
    if talkToMe and talkToMe ~= "" then return false, nil, nil end
    if not questStatus then return false, nil, nil end
    if questID and questID > 0 and GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(questID)
        if idx and idx > 0 then
            local _, _, _, _, _, _, isComplete = GetQuestLogTitle(idx)
            if isComplete then return false, nil, nil end
        end
    end
    if questStatus == "collect" then
        return true, (not pointerMode) and "loot" or nil, questID
    elseif questStatus == "objective" then
        return true, (not pointerMode) and "kill" or nil, questID
    end
    return false, nil, nil
end

-- Revalidate a token-less persisted icon; drop it once its objective/quest completes.
local function IsPersistValid(p)
    if p.ver == questLogVersion then return true end
    if p.pointer then return false end
    if hasQuestApi then
        if not (p.tag and GetQuestLogIndexByID) then return false end
        local idx = GetQuestLogIndexByID(p.tag)
        if not idx or idx == 0 then return false end
        local _, _, _, _, _, _, isComplete = GetQuestLogTitle(idx)
        if isComplete then return false end
    else
        if not (p.tag and objectiveTypeIndex[p.tag]) then return false end
    end
    p.ver = questLogVersion
    return true
end

local function QueryObjective(unit, pointerMode)
    if hasQuestApi then
        return ResolveQuestViaApi(unit, pointerMode)
    end
    if not pointerMode then
        EnsureIndexBuilt()
    end
    return ScanUnitForQuest(unit, pointerMode)
end

local function ResolveQuestForPlate(plateData, unit, pointerMode)
    local now = GetTime and GetTime() or 0
    local key = (plateData.plateName or "?") .. "|" .. questLogVersion .. "|" .. (pointerMode and "p" or "t")
    local cache = plateData._questScan
    if cache and cache.key == key and cache.at and now < cache.at + SCAN_TTL then
        return cache.hasObj, cache.objType, cache.tag
    end
    local hasObj, objType, tag = QueryObjective(unit, pointerMode)
    plateData._questScan = { key = key, at = now, hasObj = hasObj, objType = objType, tag = tag }
    return hasObj, objType, tag
end

-- Which texture shows for this objective, given the current config.
local function GetActiveIconKey(q, objType, isElite)
    if q.pointerMode then return "pointer" end
    if objType == "loot" then
        return (q.lootIcon == "chest") and "chest" or "bag"
    end
    if isElite and q.eliteKillIcon then return "elite" end
    return (q.killIcon == "skull") and "skull" or "sword"
end

local function EnsureQuestIcon(plateData)
    if plateData._questIcon then return plateData._questIcon end
    local parent = plateData.minaHp or plateData.visualRoot or plateData.plate
    if not parent then return nil end
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:Hide()
    plateData._questIcon = icon
    return icon
end

local function HideQuestIcon(plateData)
    if not plateData then return end
    plateData._questElite = nil
    if plateData._questIcon then
        plateData._questIcon:Hide()
    end
end

-- Apply the given icon key's texture, per-icon size and per-icon x/y, then show.
local function ShowQuestIcon(plateData, q, key)
    local hp = plateData.minaHp
    if not hp or not key then HideQuestIcon(plateData); return end
    local icon = EnsureQuestIcon(plateData)
    if not icon then return end
    local ic = q.icons and q.icons[key]
    -- Signals the Elite widget to drop its dragon icon (avoids duplicate elite marks).
    plateData._questElite = (key == "elite")
    icon:SetTexture(C.QUEST_ICON_TEX[key])
    -- Shared texture: mirror the sword horizontally, reset the others.
    if key == "sword" then
        icon:SetTexCoord(1, 0, 0, 1)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
    local size = (ic and ic.size) or 22
    icon:SetSize(size, size)
    if icon.SetParent then icon:SetParent(hp) end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", hp, "CENTER", (ic and ic.x) or 0, (ic and ic.y) or 20)
    icon:Show()
end

local function SyncQuestIcon(plateData, context)
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true then
        HideQuestIcon(plateData)
        return
    end

    -- Test preview: force one chosen icon on enemy/neutral plates for tuning.
    if q.testIcon and q.testIcon ~= "off" then
        local reaction = NP.native_style.GetPlateReaction(plateData)
        if reaction == "FRIENDLY" then
            HideQuestIcon(plateData)
            return
        end
        ShowQuestIcon(plateData, q, q.testIcon)
        return
    end

    local pointerMode = q.pointerMode == true
    local unit = context and context.resolvedUnit or NP.gather.ResolvePlateToken(plateData)

    local hasObj, objType
    if unit and UnitExists(unit) and not UnitIsPlayer(unit) then
        -- Token available: resolve live and remember it for token-less persistence.
        local tag
        hasObj, objType, tag = ResolveQuestForPlate(plateData, unit, pointerMode)
        if hasObj then
            local p = plateData._questPersist or {}
            p.objType, p.tag, p.ver, p.pointer = objType, tag, questLogVersion, pointerMode
            plateData._questPersist = p
        else
            plateData._questPersist = nil
        end
    else
        -- No token: keep the last-known icon while its objective stays active.
        local p = plateData._questPersist
        if p and IsPersistValid(p) then
            hasObj, objType = true, p.objType
        else
            plateData._questPersist = nil
        end
    end

    if not hasObj then
        HideQuestIcon(plateData)
        return
    end
    local isElite = false
    if objType == "kill" and not pointerMode and q.eliteKillIcon then
        isElite = NP.native_style.ResolvePlateClassification(plateData, unit) ~= nil
    end
    ShowQuestIcon(plateData, q, GetActiveIconKey(q, objType, isElite))
end

NP.widgets.Register("Quest", {
    ShouldShow = function(plateData)
        local q = NP.config.GetCfg().questIcons
        return q ~= nil and q.enabled == true
    end,
    Ensure = function(plateData)
        return EnsureQuestIcon(plateData) ~= nil
    end,
    Sync = function(plateData, context)
        SyncQuestIcon(plateData, context)
    end,
    Hide = HideQuestIcon,
})

-- Quest changed: rebuild the tooltip index (fresh data, event context), bump version, refresh.
function NP.quest.OnQuestLogChanged()
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true then return end
    local frame = NP.module and NP.module._engineFrame
    if frame == nil or lastBuildFrame ~= frame then
        lastBuildFrame = frame
        if not hasQuestApi then
            RebuildObjectiveIndex()
        end
        questLogVersion = questLogVersion + 1
    end
    if NP.engine and NP.engine.QueueMass and NP.engine.Callbacks then
        NP.engine.QueueMass(NP.engine.Callbacks.OnUpdateQuest)
    end
end

function NP.quest.ClearIndex()
    wipe(objectiveTypeIndex)
    indexBuilt = false
    lastBuildFrame = nil
end
