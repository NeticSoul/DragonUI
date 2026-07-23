-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
local addon = select(2, ...)
local NP = addon.Nameplates

-- Loot side of token-less resolution. CollectLootMobs returns false if the addon DB isn't ready.

-- pfQuest: flat public globals, no decompression needed.
NP.quest.RegisterLootProvider({
    id = "pfquest",
    priority = 30,
    IsAvailable = function()
        local pfDB = _G.pfDB
        return pfDB and pfDB.quests and pfDB.quests.data
            and pfDB.items and pfDB.items.data and pfDB.units and pfDB.units.loc and true or false
    end,
    CollectLootMobs = function(questID, out)
        local pfDB = _G.pfDB
        local qd = pfDB.quests.data[questID]
        if not qd or not qd.obj or not qd.obj.I then return true end
        local idata, loc = pfDB.items.data, pfDB.units.loc
        for _, itemID in pairs(qd.obj.I) do
            local it = idata[itemID]
            if it and it.U then
                for npcID in pairs(it.U) do
                    local nm = loc[npcID]
                    if nm then out[#out + 1] = nm end
                end
            end
        end
        return true
    end,
})

-- Questie: modules live behind QuestieLoader (QuestieDB is only a global when Questie debug is on).
local function QuestieModule()
    return QuestieLoader and QuestieLoader:ImportModule("QuestieDB")
end

-- Questie: compiled DB by id; objectives[3] holds item objectives.
NP.quest.RegisterLootProvider({
    id = "questie",
    priority = 20,
    IsAvailable = function()
        local db = QuestieModule()
        return db and db.QueryQuestSingle and db.QueryItemSingle and db.QueryNPCSingle and true or false
    end,
    CollectLootMobs = function(questID, out)
        local db = QuestieModule()
        if not (db and db.QueryQuestSingle) then return false end
        local objectives = db.QueryQuestSingle(questID, "objectives")
        local itemObjectives = objectives and objectives[3]
        if not itemObjectives then return true end
        for _, io in pairs(itemObjectives) do
            local itemId = io[1]
            if itemId then
                local npcIds = db.QueryItemSingle(itemId, "npcDrops")
                if npcIds then
                    for _, npcId in pairs(npcIds) do
                        local nm = db.QueryNPCSingle(npcId, "name")
                        if nm then out[#out + 1] = nm end
                    end
                end
            end
        end
        return true
    end,
})

-- QuestHelper: LZW-compressed DB; every DB_GetItem(register=true) must be DB_ReleaseItem'd or it leaks.
do
    local function qhCollectFrom(node, out, seen, depth)
        if not node or depth > 3 or seen[node] then return end
        seen[node] = true
        for _, v in ipairs(node) do
            local st, sid = v.sourcetype, v.sourceid
            if st == "monster" and sid then
                local m = _G.DB_GetItem("monster", sid, true, true)
                if m then
                    if m.name then out[#out + 1] = m.name end
                    _G.DB_ReleaseItem(m)
                end
            elseif (st == "item" or st == "object") and sid then
                local sub = _G.DB_GetItem(st, sid, true, true)
                if sub then
                    qhCollectFrom(sub, out, seen, depth + 1)
                    _G.DB_ReleaseItem(sub)
                end
            end
        end
        seen[node] = nil
    end

    NP.quest.RegisterLootProvider({
        id = "questhelper",
        priority = 10,
        IsAvailable = function()
            return _G.DB_GetItem and _G.DB_ReleaseItem and _G.DB_Ready and _G.QHDB and true or false
        end,
        CollectLootMobs = function(questID, out)
            if not _G.DB_Ready() then return false end
            local q = _G.DB_GetItem("quest", questID, true, true)
            if not q then return true end
            if q.criteria then
                local seen = {}
                for _, crit in ipairs(q.criteria) do
                    for _, v in ipairs(crit) do
                        -- Only item/object sources (loot); direct monster criteria are kill objectives.
                        if (v.sourcetype == "item" or v.sourcetype == "object") and v.sourceid then
                            local sub = _G.DB_GetItem(v.sourcetype, v.sourceid, true, true)
                            if sub then
                                qhCollectFrom(sub, out, seen, 0)
                                _G.DB_ReleaseItem(sub)
                            end
                        end
                    end
                end
            end
            _G.DB_ReleaseItem(q)
            return true
        end,
    })
end
