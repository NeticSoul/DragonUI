-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Buff Reminder: flask, food and raid buffs (Kings/Might/Wisdom/Gift/Fortitude/
-- Intellect) with remaining time next to the minimap. Missing buffs show gray;
-- only buffs useful for your class and spec are shown.

local addon = select(2, ...)
local L = addon.L

local KEY = "buff_reminder"

local BuffReminder = {
    initialized = false,
    applied = false,
}
addon.BuffReminderModule = BuffReminder

if addon.RegisterModule then
    addon:RegisterModule(KEY, BuffReminder,
        L["Buff Reminder"],
        L["Buff reminder next to the minimap with remaining time."],
        { lifecyclePrefix = "BuffReminder" })
end

-- Spell IDs (WotLK 3.3.5a effects). Matched by localized aura name via
-- GetSpellInfo, so all client languages work if the ID lists are complete.

local FLASK_IDS = {
    53755, 53758, -- Frost Wyrm
    54212, -- Endless Rage
    54221, -- Pure Mojo
    53760, 53761, -- Stoneblood
    -- TBC flasks
    28518, 28519, 28520, 28521, 28540, 28563, 28562,
    42735, 42736, 42772,
    17626, 17627, 17629, 17624, 17628,
}

local BATTLE_ELIXIR_IDS = {
    53748, -- Mighty Strength
    53747, 60333, -- Mighty Agility
    54232, -- Deadly Strikes
    44308, 60341, -- Accuracy
    60340, -- Armor Piercing
    60346, -- Lightning Speed
    60344, -- Expertise
    41674, -- Guru's
    33720, -- Onslaught
    38954, -- Fel Strength
    28453, -- Major Strength
    54494, -- Major Agility
}

local GUARDIAN_ELIXIR_IDS = {
    53751, -- Mighty Mageblood
    53764, -- Spirit
    53752, -- Mighty Fortitude
    60343, -- Mighty Defense
    53763, -- Protection
    54229, -- Major Defense
    49045, -- Major Fortitude
    41466, -- Draenic Wisdom
    39628, -- Major Mageblood
}

local FOOD_IDS = {
    -- Fish Feast / Great Feast share the "Well Fed" aura
    57325, 57327, 57334, 57356, 57360, 57363, 57399,
    45548, 45549, 45550, 45551,
    35272, -- generic
    43770, 43772, 43774, 43776, 43778, 43780, 43782, 43784, 43786,
    33052, 33053, 33054, 33055, 33056,
    27657, 27658, 27659, 27660, 27661,
}

local KINGS_IDS = { 20217, 25898 }
local MIGHT_IDS = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932, 25782, 25916, 48933, 48934 }
local WISDOM_IDS = { 19742, 19850, 19852, 19853, 19854, 25290, 27142, 48936, 48937, 25894, 25918, 48938, 48939 }
local GIFT_IDS = { 1126, 5232, 6756, 5234, 17446, 26990, 48469, 21849, 21850, 26991, 48470 }
local FORT_IDS = { 1243, 1244, 1245, 2791, 10937, 10938, 25389, 48063, 48064, 21562, 21564, 25392, 48066, 48067 }
local INTELLECT_IDS = { 1459, 1460, 1461, 10156, 10157, 27126, 42995, 42996, 23028, 27127, 43002, 43003, 54424, 57567 }

-- Display order: consumables, blessings, then fortitude/intellect.
local GROUP_ORDER = { "flask", "food", "kings", "might", "wisdom", "gift", "fort", "intellect" }

local GROUP_DEFS = {
    flask = { label = "Flask", ids = FLASK_IDS, iconSpell = 53755, fallbackIcon = "Interface\\Icons\\INV_Potion_119" },
    food = { label = "Food", ids = FOOD_IDS, iconSpell = 57325, fallbackIcon = "Interface\\Icons\\INV_Misc_Food_64" },
    kings = { label = "Kings", ids = KINGS_IDS, iconSpell = 25898, fallbackIcon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings" },
    might = { label = "Might", ids = MIGHT_IDS, iconSpell = 25782, fallbackIcon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings" },
    wisdom = { label = "Wisdom", ids = WISDOM_IDS, iconSpell = 25894, fallbackIcon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom" },
    gift = { label = "Gift", ids = GIFT_IDS, iconSpell = 21849, fallbackIcon = "Interface\\Icons\\Spell_Nature_GiftoftheWild" },
    fort = { label = "Fortitude", ids = FORT_IDS, iconSpell = 21562, fallbackIcon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
    intellect = { label = "Intellect", ids = INTELLECT_IDS, iconSpell = 1459, fallbackIcon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
}

local DEFAULT_TRACK = {
    flask = true, food = true,
    kings = true, might = true, wisdom = true, gift = true,
    fort = true, intellect = true,
}

-- Config (nil-tolerant for old profiles)

local function Cfg()
    local cfg = addon.db and addon.db.profile and addon.db.profile.buff_reminder
    if cfg then return cfg end
    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.buff_reminder
    return defaults or {}
end

local function TrackEnabled(groupKey)
    local cfg = Cfg()
    if cfg.track and cfg.track[groupKey] ~= nil then
        return cfg.track[groupKey] == true
    end
    if DEFAULT_TRACK[groupKey] ~= nil then
        return DEFAULT_TRACK[groupKey]
    end
    return false
end

local function GetIconSize()
    local v = tonumber(Cfg().icon_size)
    if not v or v <= 0 then return 30 end
    if v < 16 then return 16 end
    if v > 64 then return 64 end
    return v
end

local function GetSpacing()
    local v = tonumber(Cfg().spacing)
    if not v then return 4 end
    if v < 0 then return 0 end
    if v > 20 then return 20 end
    return v
end

local function GetDirection()
    local d = Cfg().direction
    if d == "LEFT" or d == "RIGHT" or d == "UP" or d == "DOWN" then
        return d
    end
    return "DOWN"
end

local function GetTimerFontSize()
    local v = tonumber(Cfg().timer_font_size)
    if not v or v <= 0 then return 8 end
    if v < 8 then return 8 end
    if v > 24 then return 24 end
    return v
end

local function GetWarnBelow()
    local v = tonumber(Cfg().warn_below)
    if not v or v < 0 then return 2 end
    return v
end

-- Class/spec relevance: only useful buffs shown (no Wisdom for rogues, Might
-- for Ret and Wisdom for Holy). Unknown/unspecced sees everything tracked.

local NO_MANA_CLASSES = {
    WARRIOR = true,
    ROGUE = true,
    DEATHKNIGHT = true,
}

local function GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- Talent tab with most points spent, or nil when nothing spent yet.
local function GetActiveSpecIndex()
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then
        return nil
    end
    local okNum, numTabs = pcall(GetNumTalentTabs)
    if not okNum or type(numTabs) ~= "number" or numTabs <= 0 then
        return nil
    end
    local best, bestPoints = nil, 0
    for i = 1, numTabs do
        local ok, _, _, points = pcall(GetTalentTabInfo, i)
        if ok and type(points) == "number" and points > bestPoints then
            best, bestPoints = i, points
        end
    end
    return best
end

local function IsGroupRelevant(groupKey)
    if Cfg().class_filter == false then
        return true
    end
    if groupKey == "might" then
        local class = GetPlayerClass()
        if class == "MAGE" or class == "WARLOCK" or class == "PRIEST" then
            return false
        end
        local spec = GetActiveSpecIndex()
        if class == "PALADIN" then
            return spec ~= 1 -- Holy gets Wisdom instead
        end
        if class == "SHAMAN" then
            -- Ele/Resto: Wisdom; Enhance/unknown: Might
            return spec ~= 1 and spec ~= 3
        end
        if class == "DRUID" then
            -- Balance/Resto: Wisdom; Feral/unknown: Might
            return spec ~= 1 and spec ~= 3
        end
        return true
    elseif groupKey == "wisdom" then
        local class = GetPlayerClass()
        if NO_MANA_CLASSES[class] then
            return false
        end
        if class == "HUNTER" then
            return false -- physical DPS: Might is the useful one
        end
        local spec = GetActiveSpecIndex()
        if class == "PALADIN" then
            return spec ~= 3 -- Retribution gets Might instead
        end
        if class == "SHAMAN" then
            return spec ~= 2 -- Enhancement gets Might instead
        end
        if class == "DRUID" then
            return spec ~= 2 -- Feral gets Might instead
        end
        return true
    elseif groupKey == "intellect" then
        return not NO_MANA_CLASSES[GetPlayerClass()]
    end
    return true -- flask, food, kings, gift, fort: useful for everyone
end

-- Localized aura names and icons via GetSpellInfo

local nameSets = {}
local groupIcons = {}

local function BuildNameSet(groupKey)
    if nameSets[groupKey] then return nameSets[groupKey] end
    local set = {}
    local def = GROUP_DEFS[groupKey]
    if def and def.ids then
        for _, spellId in ipairs(def.ids) do
            local ok, name = pcall(GetSpellInfo, spellId)
            if ok and type(name) == "string" and name ~= "" then
                set[name] = true
            end
        end
    end
    nameSets[groupKey] = set
    return set
end

local function GroupIcon(groupKey)
    if groupIcons[groupKey] then return groupIcons[groupKey] end
    local def = GROUP_DEFS[groupKey]
    local icon
    if def and def.iconSpell then
        local ok, _, _, tex = pcall(GetSpellInfo, def.iconSpell)
        if ok and tex then icon = tex end
    end
    if not icon and def and def.ids then
        for _, spellId in ipairs(def.ids) do
            local ok, _, _, tex = pcall(GetSpellInfo, spellId)
            if ok and tex then icon = tex break end
        end
    end
    icon = icon or (def and def.fallbackIcon) or "Interface\\Icons\\INV_Misc_QuestionMark"
    groupIcons[groupKey] = icon
    return icon
end

local function BuildAllNameSets()
    for _, key in ipairs(GROUP_ORDER) do
        BuildNameSet(key)
    end
end

-- Battle/guardian sets for the flask-or-elixirs rule.
local function BattleNameSet()
    if nameSets["battle_fallback"] and next(nameSets["battle_fallback"]) then
        return nameSets["battle_fallback"]
    end
    local set = {}
    for _, spellId in ipairs(BATTLE_ELIXIR_IDS) do
        local ok, name = pcall(GetSpellInfo, spellId)
        if ok and type(name) == "string" and name ~= "" then
            set[name] = true
        end
    end
    nameSets["battle_fallback"] = set
    return set
end

local function GuardianNameSet()
    if nameSets["guardian_fallback"] and next(nameSets["guardian_fallback"]) then
        return nameSets["guardian_fallback"]
    end
    local set = {}
    for _, spellId in ipairs(GUARDIAN_ELIXIR_IDS) do
        local ok, name = pcall(GetSpellInfo, spellId)
        if ok and type(name) == "string" and name ~= "" then
            set[name] = true
        end
    end
    nameSets["guardian_fallback"] = set
    return set
end

-- Aura scanning

-- name -> { expiration, duration, icon }
local auraCache = {}

local function ScanPlayerAuras()
    wipe(auraCache)
    for i = 1, 40 do
        local name, _, icon, _, _, duration, expiration = UnitBuff("player", i)
        if not name then break end
        if not auraCache[name] then
            auraCache[name] = { expiration = expiration or 0, duration = duration or 0, icon = icon }
        else
            -- Same name twice (e.g. Gift + Mark ranks): keep the longest remaining.
            local cur = auraCache[name]
            if (expiration or 0) > (cur.expiration or 0) then
                cur.expiration = expiration or 0
                cur.duration = duration or 0
                cur.icon = icon or cur.icon
            end
        end
    end
    return auraCache
end

local function FindGroupAura(groupKey)
    local set = BuildNameSet(groupKey)
    local best, bestName
    for name in pairs(set) do
        local entry = auraCache[name]
        if entry then
            if not best or (entry.expiration or 0) > (best.expiration or 0) then
                best = entry
                bestName = name
            end
        end
    end
    -- English fallback for food / flask so unlisted ranks still match.
    if not best and groupKey == "food" then
        for name, entry in pairs(auraCache) do
            local lower = string.lower(name)
            if lower:find("well fed", 1, true) then
                if not best or (entry.expiration or 0) > (best.expiration or 0) then
                    best = entry
                    bestName = name
                end
            end
        end
    end
    if not best and groupKey == "flask" then
        for name, entry in pairs(auraCache) do
            local lower = string.lower(name)
            if lower:find("flask of", 1, true) then
                if not best or (entry.expiration or 0) > (best.expiration or 0) then
                    best = entry
                    bestName = name
                end
            end
        end
    end
    return best, bestName
end

local function GetGroupState(groupKey)
    if groupKey == "flask" and Cfg().flask_also_elixirs ~= false then
        local flaskAura, flaskName = FindGroupAura("flask")
        if flaskAura then
            local remaining = (flaskAura.expiration or 0) > 0 and math.max(0, flaskAura.expiration - GetTime()) or 0
            return true, remaining, flaskAura.duration or 0, flaskAura.icon or GroupIcon("flask"), flaskName
        end
        -- Flask-or-elixirs: battle + guardian counts as flasked.
        local battleBest, battleName
        local guardianBest, guardianName
        local bset, gset = BattleNameSet(), GuardianNameSet()
        for name, entry in pairs(auraCache) do
            if bset[name] and (not battleBest or (entry.expiration or 0) > (battleBest.expiration or 0)) then
                battleBest, battleName = entry, name
            end
            if gset[name] and (not guardianBest or (entry.expiration or 0) > (guardianBest.expiration or 0)) then
                guardianBest, guardianName = entry, name
            end
        end
        if not battleBest or not guardianBest then
            -- English fallback: any "Elixir of" aura; need two distinct ones.
            local found = {}
            for name, entry in pairs(auraCache) do
                if string.lower(name):find("elixir", 1, true) then
                    found[#found + 1] = { name = name, entry = entry }
                end
            end
            if #found >= 2 then
                table.sort(found, function(a, b) return (a.entry.expiration or 0) < (b.entry.expiration or 0) end)
                local remaining = math.max(0, (found[1].entry.expiration or 0) - GetTime())
                return true, remaining, found[1].entry.duration or 0, found[1].entry.icon or GroupIcon("flask"), found[1].name .. " + " .. found[2].name
            end
            return false, 0, 0, GroupIcon("flask"), nil
        end
        local remaining = math.max(0, math.min(battleBest.expiration or 0, guardianBest.expiration or 0) - GetTime())
        return true, remaining, math.min(battleBest.duration or 0, guardianBest.duration or 0), battleBest.icon or GroupIcon("flask"), (battleName or "?") .. " + " .. (guardianName or "?")
    end
    local aura, auraName = FindGroupAura(groupKey)
    if aura then
        local remaining = (aura.expiration or 0) > 0 and math.max(0, aura.expiration - GetTime()) or 0
        return true, remaining, aura.duration or 0, aura.icon or GroupIcon(groupKey), auraName
    end
    return false, 0, 0, GroupIcon(groupKey), nil
end

-- Frames

local anchor, container -- editor mover, icon holder
local iconPool = {} -- [groupKey] = frame
local eventFrame
local ticker = 0
local previewing = false

local function EditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive() and true or false
end

local function FormatRemaining(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    if seconds <= 0 then return "" end
    if seconds >= 3600 then
        local h = seconds / 3600
        if h >= 10 then
            return string.format("%dh", math.floor(h + 0.5))
        end
        return string.format("%.1fh", h)
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60 + 0.5))
    else
        return string.format("%ds", seconds)
    end
end

local function AcquireIcon(groupKey)
    local f = iconPool[groupKey]
    if f then return f end
    f = CreateFrame("Frame", "DragonUI_BuffReminder_" .. groupKey, container)
    f.groupKey = groupKey

    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetAllPoints(f)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.missing = f:CreateTexture(nil, "OVERLAY")
    f.missing:SetAllPoints(f)
    f.missing:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.missing:SetVertexColor(0.4, 0.4, 0.4, 0.55)
    f.missing:Hide()

    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
    f.timer:SetJustifyH("CENTER")
    f.timer:SetDrawLayer("OVERLAY", 7) -- above the swipe; see actionbars/extrabar.lua

    f.cooldown = CreateFrame("Cooldown", nil, f)
    f.cooldown:SetAllPoints(f)
    f.cooldown:Hide()

    f:SetScript("OnEnter", function(self)
        if not BuffReminder.applied and not previewing then return end
        local def = GROUP_DEFS[self.groupKey]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Buff Reminder: " .. (def and def.label or self.groupKey), 1, 1, 1)
        local present, remaining, _, _, auraName = GetGroupState(self.groupKey)
        if present then
            GameTooltip:AddLine(auraName or "Active", 0, 1, 0)
            if remaining and remaining > 0 then
                GameTooltip:AddLine("Remaining: " .. FormatRemaining(remaining), 1, 1, 1)
            end
        else
            GameTooltip:AddLine("Missing", 1, 0.2, 0.2)
            if def and def.label == "Flask" and Cfg().flask_also_elixirs ~= false then
                GameTooltip:AddLine("Flask, or a battle + guardian elixir.", 0.7, 0.7, 0.7, true)
            end
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if addon.StyleAuraButton then
        pcall(addon.StyleAuraButton, f, false)
    end

    iconPool[groupKey] = f
    return f
end

local function TrackedGroups()
    local list = {}
    for _, key in ipairs(GROUP_ORDER) do
        if TrackEnabled(key) then
            list[#list + 1] = key
        end
    end
    return list
end

local function RelevantGroups()
    local list = {}
    for _, key in ipairs(TrackedGroups()) do
        if IsGroupRelevant(key) then
            list[#list + 1] = key
        end
    end
    return list
end

local function LayoutIcons(groups)
    if not container then return end
    local size = GetIconSize()
    local spacing = GetSpacing()
    local direction = GetDirection()
    groups = groups or RelevantGroups()

    local fontSize = GetTimerFontSize()
    local fontPath = (addon.Fonts and addon.Fonts.PRIMARY) or "Fonts\\FRIZQT__.TTF"

    local shown = 0
    for index, key in ipairs(groups) do
        local f = AcquireIcon(key)
        f:SetSize(size, size)
        f:ClearAllPoints()
        if direction == "LEFT" then
            if index == 1 then
                f:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
            else
                f:SetPoint("TOPRIGHT", iconPool[groups[index - 1]], "TOPLEFT", -spacing, 0)
            end
        elseif direction == "RIGHT" then
            if index == 1 then
                f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            else
                f:SetPoint("TOPLEFT", iconPool[groups[index - 1]], "TOPRIGHT", spacing, 0)
            end
        elseif direction == "UP" then
            if index == 1 then
                f:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
            else
                f:SetPoint("BOTTOMLEFT", iconPool[groups[index - 1]], "TOPLEFT", 0, spacing)
            end
        else -- DOWN
            if index == 1 then
                f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            else
                f:SetPoint("TOPLEFT", iconPool[groups[index - 1]], "BOTTOMLEFT", 0, -spacing)
            end
        end
        f.timer:SetFont(fontPath, fontSize, "OUTLINE")
        f:Show()
        shown = shown + 1
    end

    -- Hide icons not in this pass.
    local wanted = {}
    for _, key in ipairs(groups) do wanted[key] = true end
    for key, f in pairs(iconPool) do
        if not wanted[key] then
            f:Hide()
            f:ClearAllPoints()
        end
    end

    local n = math.max(shown, 1)
    local w, h
    if direction == "LEFT" or direction == "RIGHT" then
        w, h = n * size + (n - 1) * spacing, size
    else
        w, h = size, n * size + (n - 1) * spacing
    end
    container:SetSize(w, h)
    if anchor then
        anchor:SetSize(w, h)
    end
end

local function UpdateIconVisual(groupKey, present, remaining, duration)
    local f = iconPool[groupKey]
    if not f or not f:IsShown() then return end
    local cfg = Cfg()
    local _, _, liveDuration, liveIcon = GetGroupState(groupKey)
    if previewing then
        -- Preview: fake everything present with ~1h left.
        present, remaining, duration = true, 3600, 3600
        liveIcon = GroupIcon(groupKey)
    else
        duration = duration or liveDuration
    end
    f.icon:SetTexture(liveIcon or GroupIcon(groupKey))
    local function HideCooldown()
        if f.cooldown then
            f.cooldown:Hide()
        end
        f._cdStart, f._cdDuration = nil, nil
    end
    if present then
        f.icon:SetDesaturated(false)
        f.icon:SetAlpha(1)
        f.missing:Hide()
        if cfg.show_timer ~= false and remaining and remaining > 0 then
            f.timer:Show()
            f.timer:SetText(FormatRemaining(remaining))
            local warnSec = GetWarnBelow() * 60
            if remaining < warnSec then
                f.timer:SetTextColor(1, 0.25, 0.25)
            else
                f.timer:SetTextColor(1, 1, 1)
            end
        else
            f.timer:Hide()
        end
        -- Clock swipe on active buffs.
        if cfg.show_cooldown ~= false and f.cooldown and duration and duration > 0
            and remaining and remaining > 0 then
            local start = GetTime() - (duration - remaining)
            if f._cdStart == nil or f._cdDuration ~= duration
                or math.abs(f._cdStart - start) > 0.5 then
                f._cdStart, f._cdDuration = start, duration
                f.cooldown:SetCooldown(start, duration)
            end
            f.cooldown:Show()
        else
            HideCooldown()
        end
        if cfg.show_only_missing then
            f:Hide()
        end
    else
        f:Show()
        f.icon:SetDesaturated(true)
        f.icon:SetAlpha(0.75)
        f.missing:Show()
        f.timer:Hide()
        HideCooldown()
    end
end

local function IsGroupRestricted()
    local cfg = Cfg()
    if cfg.only_in_instance then
        local inInstance = IsInInstance and IsInInstance()
        if not inInstance then return true end
    end
    if cfg.only_in_group then
        local inParty = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
        local inRaid = (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
        if not (inParty or inRaid) then return true end
    end
    return false
end

local function ShouldShow()
    if not BuffReminder.applied then return false end
    if EditorActive() or previewing then return true end
    if IsGroupRestricted() then return false end
    return #RelevantGroups() > 0
end

function BuffReminder:Update()
    if not container then return end
    ScanPlayerAuras()
    if IsGroupRestricted() and not (EditorActive() or previewing) then
        container:Hide()
        return
    end
    local groups = RelevantGroups()
    if #groups == 0 then
        container:Hide()
        return
    end
    container:Show()
    -- Missing-only mode: lay out just the missing icons to collapse gaps.
    local cfg = Cfg()
    local layoutGroups = groups
    if cfg.show_only_missing and not (EditorActive() or previewing) then
        layoutGroups = {}
        for _, key in ipairs(groups) do
            local present = GetGroupState(key)
            if not present then
                layoutGroups[#layoutGroups + 1] = key
            end
        end
        if #layoutGroups == 0 then
            container:Hide()
            return
        end
        -- Hide present ones so no stale icons linger.
        for _, key in ipairs(groups) do
            local f = iconPool[key]
            if f then
                local present = GetGroupState(key)
                if present then f:Hide() end
            end
        end
    end
    LayoutIcons(layoutGroups)
    for _, key in ipairs(groups) do
        local f = iconPool[key]
        if f and f:IsShown() then
            local present, remaining, duration = GetGroupState(key)
            UpdateIconVisual(key, present, remaining, duration)
        end
    end
end

local function UpdateTimersOnly()
    if not container or not container:IsShown() then return end
    ScanPlayerAuras()
    for _, key in ipairs(RelevantGroups()) do
        local f = iconPool[key]
        if f and f:IsShown() then
            local present, remaining, duration = GetGroupState(key)
            UpdateIconVisual(key, present, remaining, duration)
        end
    end
end

local function ApplyPosition()
    if not anchor then return end
    if EditorActive() and anchor:GetNumPoints() > 0 then return end
    local widgets = addon.db and addon.db.profile and addon.db.profile.widgets
    local cfg = (widgets and widgets[KEY]) or (addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets and addon.defaults.profile.widgets[KEY])
    if not cfg then return end
    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor or "TOPRIGHT", UIParent, cfg.anchor or "TOPRIGHT", cfg.posX or -228, cfg.posY or -15)
end

-- Editor

local function StartPreview()
    previewing = true
    if container then container:Show() end
    local groups = TrackedGroups()
    LayoutIcons(groups)
    for _, key in ipairs(groups) do
        UpdateIconVisual(key, true, 3600, 3600)
    end
end

local function StopPreview()
    previewing = false
    if not BuffReminder.applied then return end
    BuffReminder:Update()
end

local function CreateEditorFrame()
    addon:RegisterEditableFrame({
        name = "buff_reminder",
        frame = anchor,
        configPath = { "widgets", KEY },
        editorVisible = function()
            return addon:IsModuleEnabled(KEY)
        end,
        showTest = StartPreview,
        hideTest = StopPreview,
        onHide = function()
            ApplyPosition()
            if BuffReminder.applied then
                LayoutIcons()
                BuffReminder:Update()
            end
        end,
        module = BuffReminder,
    })
end

function BuffReminder:ResetPosition()
    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets and addon.defaults.profile.widgets[KEY]
    if addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets[KEY] and defaults then
        local w = addon.db.profile.widgets[KEY]
        w.anchor = defaults.anchor
        w.posX = defaults.posX
        w.posY = defaults.posY
    end
    ApplyPosition()
end

-- Lifecycle

local function EnsureFrames()
    if container then return end
    anchor = addon.CreateUIFrame(120, 120, "BuffReminder")
    container = CreateFrame("Frame", "DragonUI_BuffReminder", UIParent)
    container:SetFrameStrata("MEDIUM")
    container:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    container:Hide()
    CreateEditorFrame()
end

local function RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_AURA" and unit and unit ~= "player" and unit ~= "vehicle" then return end
            BuffReminder:Update()
        end)
        eventFrame:SetScript("OnUpdate", function(_, elapsed)
            ticker = ticker + elapsed
            if ticker >= 0.5 then
                ticker = 0
                if container and container:IsShown() and not previewing then
                    UpdateTimersOnly()
                end
            end
        end)
    end
    eventFrame:UnregisterAllEvents()
    addon.RegisterUnitEventSafe(eventFrame, "UNIT_AURA", "player", "vehicle")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_ALIVE")
    eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

local function SetShown(frame, show)
    if not frame then return end
    if frame.SetShownCompat then
        frame:SetShownCompat(show and true or false)
    elseif show then
        frame:Show()
    else
        frame:Hide()
    end
end

function addon.ApplyBuffReminderSystem()
    EnsureFrames()
    BuildAllNameSets()
    BuffReminder.initialized = true
    BuffReminder.applied = true
    RegisterEvents()
    ApplyPosition()
    LayoutIcons()
    BuffReminder:Update()
    if container then
        SetShown(container, ShouldShow())
    end
end

function addon.RestoreBuffReminderSystem()
    BuffReminder.applied = false
    previewing = false
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    if container then
        container:Hide()
    end
end

function addon.RefreshBuffReminderSystem()
    if addon:IsModuleEnabled(KEY) then
        addon.ApplyBuffReminderSystem()
    else
        addon.RestoreBuffReminderSystem()
    end
end

function addon.RefreshBuffReminder()
    if not BuffReminder.applied then return end
    ApplyPosition()
    LayoutIcons()
    BuffReminder:Update()
    if container then
        SetShown(container, ShouldShow())
    end
end
