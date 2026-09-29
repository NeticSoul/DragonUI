-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns

local max, min = math.max, math.min

-- Storage -----------------------------------------------------------------------------------------

function ns.BuildBucket(classToken)
    local global = addon.db and addon.db.global
    if not global then return {} end
    global.talentBuilds = global.talentBuilds or {}
    local bucket = global.talentBuilds[classToken]
    if type(bucket) ~= "table" then
        bucket = {}
        global.talentBuilds[classToken] = bucket
    end
    return bucket
end

function ns.OwnBuilds()
    return ns.BuildBucket(ns.PlayerClass())
end

function ns.StoredAt(build)
    for position, stored in ipairs(ns.OwnBuilds()) do
        if stored == build then return position end
    end
    return nil
end

function ns.IsStored(build)
    return ns.StoredAt(build) ~= nil
end

function ns.ForgetBuild(build)
    local bucket = ns.OwnBuilds()
    for index = #bucket, 1, -1 do
        if bucket[index] == build then table.remove(bucket, index) end
    end
end

-- Tree structure, read once per class from the live API -------------------------------------------

local structures = {}

local function readStructure()
    local trees = GetNumTalentTabs(false, false) or 0
    if trees < 1 then return nil end
    local data = { count = trees }
    for tab = 1, trees do
        local tree = { name = GetTalentTabInfo(tab, false, false), talents = {}, cells = {}, order = {} }
        for index = 1, GetNumTalents(tab, false, false) or 0 do
            local name, icon, tier, column, _, maxRank, exceptional = GetTalentInfo(tab, index, false, false)
            if name and tier then
                local talent = {
                    index = index, name = name, icon = icon, tier = tier, column = column,
                    maxRank = maxRank or 1, exceptional = exceptional and true or false,
                    needs = ns.PrereqCells(GetTalentPrereqs(tab, index, false, false)),
                }
                tree.talents[index] = talent
                tree.cells[ns.CellKey(tier, column)] = index
                tree.order[#tree.order + 1] = talent
            end
        end
        table.sort(tree.order, function(a, b) return a.tier * 64 + a.index < b.tier * 64 + b.index end)
        data[tab] = tree
    end
    return data
end

function ns.TreeData()
    local classToken = ns.PlayerClass()
    local data = structures[classToken]
    if not data then
        data = readStructure()
        structures[classToken] = data
    end
    return data
end

-- Counting ----------------------------------------------------------------------------------------

local function rankIn(build, tab, index)
    local ranks = build.ranks and build.ranks[tab]
    return ranks and tonumber(ranks[index]) or 0
end
ns.BuildRank = rankIn

function ns.TreePoints(build, tab)
    local sum, ranks = 0, build.ranks and build.ranks[tab]
    if type(ranks) == "table" then
        for _, rank in pairs(ranks) do
            sum = sum + max(0, tonumber(rank) or 0)
        end
    end
    return sum
end

function ns.BuildPoints(build)
    local sum = 0
    for tab in pairs(type(build.ranks) == "table" and build.ranks or {}) do
        sum = sum + ns.TreePoints(build, tab)
    end
    return sum
end

-- Returns the level and whether it is the automatic one (it grows with the build).
function ns.BuildLevel(build)
    if build.reqLevel then return build.reqLevel, false end
    return max(10, ns.BuildPoints(build) + 9), true
end

function ns.BuildBudget(build)
    local ceiling = ns.PointCeiling()
    if build.reqLevel then return min(ceiling, build.reqLevel - 9) end
    return ceiling
end

-- Rules -------------------------------------------------------------------------------------------

-- Only rows above the tier count, as in the game: deeper points never hold a tier open.
local function pointsAbove(build, data, tab, tier)
    local sum, ranks, tree = 0, build.ranks and build.ranks[tab], data[tab]
    if type(ranks) ~= "table" or not tree then return 0 end
    for index, rank in pairs(ranks) do
        local talent = tree.talents[index]
        if talent and talent.tier < tier then
            sum = sum + max(0, tonumber(rank) or 0)
        end
    end
    return sum
end

local function tierOpen(build, data, tab, tier)
    return pointsAbove(build, data, tab, tier) >= (tier - 1) * (PLAYER_TALENTS_PER_TIER or 5)
end
ns.TierOpen = tierOpen

local function needsMet(build, data, tab, talent)
    local tree = data[tab]
    for _, cell in ipairs(talent.needs) do
        local source = tree.cells[ns.CellKey(cell[1], cell[2])]
        if source and rankIn(build, tab, source) < tree.talents[source].maxRank then
            return nil
        end
    end
    return true
end

function ns.BuildValid(build, data)
    for tab = 1, data.count do
        for _, talent in ipairs(data[tab].order) do
            if rankIn(build, tab, talent.index) > 0 then
                if not (tierOpen(build, data, tab, talent.tier) and needsMet(build, data, tab, talent)) then
                    return nil
                end
            end
        end
    end
    return true
end

function ns.CanAddPoint(build, data, tab, index)
    local talent = data[tab] and data[tab].talents[index]
    if not talent then return false end
    return rankIn(build, tab, index) < talent.maxRank
        and ns.BuildPoints(build) < ns.BuildBudget(build)
        and tierOpen(build, data, tab, talent.tier)
        and needsMet(build, data, tab, talent)
end

-- A removal must leave a valid build: no stranded tier, no orphaned dependent.
function ns.CanRemovePoint(build, data, tab, index)
    local rank = rankIn(build, tab, index)
    if rank <= 0 then return false end
    local ranks = build.ranks[tab]
    ranks[index] = rank - 1
    local fine = ns.BuildValid(build, data)
    ranks[index] = rank
    return fine
end

function ns.AdjustRank(build, tab, index, delta)
    local bucket = build.ranks[tab] or {}
    build.ranks[tab] = bucket
    local rank = rankIn(build, tab, index) + delta
    bucket[index] = rank > 0 and rank or nil
end

-- Normalising mutates the stored table in place; the result says whether the build fits.
function ns.NormalizeBuild(build, data)
    if type(build.ranks) ~= "table" then build.ranks = {} end
    for tab, ranks in pairs(build.ranks) do
        if type(ranks) == "table" then
            local tree = type(tab) == "number" and data[tab]
            for index, rank in pairs(ranks) do
                local talent = tree and tree.talents[index]
                rank = tonumber(rank)
                if not talent or not rank or rank <= 0 then
                    ranks[index] = nil
                elseif rank > talent.maxRank then
                    ranks[index] = talent.maxRank
                end
            end
        else
            build.ranks[tab] = nil
        end
    end
    local points = ns.BuildPoints(build)
    if build.reqLevel and build.reqLevel < points + 9 then
        build.reqLevel = min(ns.LevelCap(), points + 9)
    end
    return ns.BuildValid(build, data) and points <= ns.BuildBudget(build)
end

function ns.DominantBuildTree(build, count)
    local points = {}
    for tab = 1, count do points[tab] = ns.TreePoints(build, tab) end
    return ns.DominantTree(points, count)
end

-- Ranks the character has learned (committed, never preview) in its active group.
function ns.CommittedRanks(inspect)
    local group = GetActiveTalentGroup(inspect, false) or 1
    local learned = {}
    for tab = 1, GetNumTalentTabs(inspect, false) or 0 do
        local tree = {}
        for index = 1, GetNumTalents(tab, inspect, false) or 0 do
            local _, _, _, _, rank = GetTalentInfo(tab, index, inspect, false, group)
            if (rank or 0) >= 1 then tree[index] = rank end
        end
        learned[tab] = tree
    end
    return learned
end
