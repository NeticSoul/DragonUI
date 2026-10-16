-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Retail-style guild window in place of the Social window's Guild tab. The stock tab, the guild
-- key binding (ToggleFriendsFrame(3)) and the Social window landing on that tab all open it.
-- Guild levels, perks and news come from the GuildLevels addon (mod-guild-levels) when it is
-- loaded and its server answers; without it the window is roster, info and the event log.

local GuildModule = { initialized = false, applied = false }
addon.Guild = addon.Guild or {}
local GU = addon.Guild

local function localized(key)
    local strings = addon.L
    local ok, text = pcall(function() return strings and strings[key] end)
    if not ok or type(text) ~= "string" or text == "" then return key end
    return text
end
GU.L = localized

if addon.RegisterModule then
    addon:RegisterModule("guild", GuildModule,
        localized("Guild Window"),
        localized("Retail-style guild window with roster, news and guild perks"),
        { lifecyclePrefix = "Guild", loadOnce = true })
end

function GU:Enabled()
    return addon:IsModuleEnabled("guild")
end

GU.DIR = addon._dir
GU.GOLD = { 1, 0.82, 0 }
GU.GRAY = { 0.5, 0.5, 0.5 }

-- ---------------------------------------------------------------------------------------------
-- GuildLevels bridge
-- ---------------------------------------------------------------------------------------------

-- The GuildLevels table, only once its server has answered: before that, or without
-- mod-guild-levels on the realm, there is no level to show.
function GU.Levels()
    local gl = _G.GuildLevels
    if type(gl) == "table" and gl.connected and (gl.level or 0) > 0 then return gl end
end

-- Asks the server for everything the window shows. The server throttles each kind to once a second.
function GU.RequestLevels(what)
    local gl = _G.GuildLevels
    if type(gl) ~= "table" or not gl.Send then return end
    if what then
        gl.Send(what)
    else
        gl.Send("STATE")
        gl.Send("ROSTER")
        gl.Send("NEWS")
    end
end

local hooked
local function hookLevels()
    local gl = _G.GuildLevels
    if hooked or type(gl) ~= "table" then return end
    hooked = true
    local previous = gl.OnUpdate
    gl.OnUpdate = function(...)
        if previous then previous(...) end
        if GU.IsShown() and GU.Refresh then GU.Refresh() end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Roster
-- ---------------------------------------------------------------------------------------------

GU.roster = {}
GU.sortKey, GU.sortAscending = "online", true

local function classFile(className)
    if not className then return end
    for file, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
        if name == className then return file end
    end
    for file, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
        if name == className then return file end
    end
end

-- Guild XP this week by member name, from the GuildLevels roster.
local function contributions()
    local gl = GU.Levels()
    local byName = {}
    if gl then
        for _, row in ipairs(gl.roster or {}) do byName[row.name] = row end
    end
    return byName
end

local SORTERS = {
    name = function(a, b) return a.name < b.name end,
    level = function(a, b) return a.level < b.level end,
    zone = function(a, b) return (a.zone or "") < (b.zone or "") end,
    rank = function(a, b) return a.rankIndex < b.rankIndex end,
    note = function(a, b) return (a.note or "") < (b.note or "") end,
    xp = function(a, b) return a.weekXP > b.weekXP end,
    class = function(a, b) return (a.class or "") < (b.class or "") end,
}

-- Online first, then by the column; name breaks ties so the order never jumps between refreshes.
local function sortRoster()
    local key, ascending = GU.sortKey, GU.sortAscending
    local primary = SORTERS[key]
    table.sort(GU.roster, function(a, b)
        if key == "online" or not primary then
            if a.online ~= b.online then return a.online end
            if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
            return a.name < b.name
        end
        if primary(a, b) then return ascending end
        if primary(b, a) then return not ascending end
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
end

function GU.SortBy(key)
    if GU.sortKey == key then
        GU.sortAscending = not GU.sortAscending
    else
        GU.sortKey, GU.sortAscending = key, true
    end
    sortRoster()
    if GU.RefreshRoster then GU.RefreshRoster() end
end

function GU.BuildRoster()
    wipe(GU.roster)
    GU.numMembers, GU.numOnline = 0, 0
    if not IsInGuild() then return end

    -- With offline members hidden the client only indexes the online ones, so the total comes
    -- from GetNumGuildMembers(true) and the loop runs until the roster runs out.
    local xp = contributions()
    local total = GetNumGuildMembers(true)
    GU.numMembers = total
    for i = 1, total do
        local name, rank, rankIndex, level, class, zone, note, officerNote, online, status, file = GetGuildRosterInfo(i)
        if not name then break end
        if online then GU.numOnline = GU.numOnline + 1 end
        local contribution = xp[name]
        GU.roster[#GU.roster + 1] = {
            index = i, name = name, rank = rank, rankIndex = rankIndex or 0, level = level or 0,
            class = class, classFile = file or classFile(class), zone = zone, note = note,
            officerNote = officerNote, online = online and true or false, status = status,
            weekXP = contribution and contribution.week or 0,
            totalXP = contribution and contribution.total or 0,
        }
    end
    sortRoster()
    -- The stock note popups read GetGuildRosterSelection() when they accept, and the index a
    -- member sits at moves with every rebuild: keep it on the selected member.
    if GU.selectedName then
        local member = GU.FindMember(GU.selectedName)
        SetGuildRosterSelection(member and member.index or 0)
    end
end

-- The roster as the list shows it: offline members only when the box is ticked.
function GU.VisibleRoster()
    if GetGuildRosterShowOffline() then return GU.roster end
    local list = {}
    for _, member in ipairs(GU.roster) do
        if member.online then list[#list + 1] = member end
    end
    return list
end

function GU.FindMember(name)
    for _, member in ipairs(GU.roster) do
        if member.name == name then return member end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Formatting
-- ---------------------------------------------------------------------------------------------

function GU.Number(n)
    local text = tostring(math.floor(n or 0))
    local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

function GU.ClassColor(file)
    local color = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- "3 hours ago" from seconds.
function GU.Ago(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 60 then return localized("Just now") end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return format(localized("%d |4minute:minutes; ago"), minutes) end
    local hours = math.floor(minutes / 60)
    if hours < 24 then return format(localized("%d |4hour:hours; ago"), hours) end
    local days = math.floor(hours / 24)
    if days < 30 then return format(localized("%d |4day:days; ago"), days) end
    local months = math.floor(days / 30)
    if months < 12 then return format(localized("%d |4month:months; ago"), months) end
    return format(localized("%d |4year:years; ago"), math.floor(months / 12))
end

-- GetGuildEventInfo and GetGuildRosterLastOnline count back in years, months, days and hours.
function GU.ElapsedSeconds(years, months, days, hours)
    return ((((years or 0) * 12 + (months or 0)) * 30 + (days or 0)) * 24 + (hours or 0)) * 3600
end

-- The event log's age: whole hours, so 0 is anything under an hour.
function GU.EventAge(years, months, days, hours)
    local seconds = GU.ElapsedSeconds(years, months, days, hours)
    if seconds == 0 then return 1800, localized("Less than an hour ago") end
    return seconds
end

function GU.LastOnline(index)
    local years, months, days, hours = GetGuildRosterLastOnline(index)
    if not years then return end
    if years == 0 and months == 0 and days == 0 and hours == 0 then return localized("Less than an hour ago") end
    return GU.Ago(GU.ElapsedSeconds(years, months, days, hours))
end

-- ---------------------------------------------------------------------------------------------
-- Social window hand-off
-- ---------------------------------------------------------------------------------------------

local GUILD_TAB = 3
local handoffInstalled
local friendsOpen   -- the Social window was already up before this FriendsFrame_Update

-- The Social window never shows its Guild tab. Clicking the tab opens the guild window; the
-- "Toggle Guild Tab" key binding and other addons call ToggleFriendsFrame(3), which lands in
-- FriendsFrame_Update with the tab selected, and that toggles the guild window instead. That
-- runs inside ShowUIPanel, so the Social window is only made invisible here and handed back to
-- the panel manager to close on the next frame.
-- When the Social window was already open, it stays open on Friends instead.
local function takeOverGuildTab()
    if not (GU:Enabled() and FriendsFrame and FriendsFrame:IsShown() and FriendsFrame.selectedTab == GUILD_TAB) then return end
    PanelTemplates_SetTab(FriendsFrame, 1)
    if friendsOpen then
        FriendsFrame_Update()
        GU.Toggle()
        return
    end
    FriendsFrame:SetAlpha(0)
    addon:After(0, function()
        HideUIPanel(FriendsFrame)
        FriendsFrame:SetAlpha(1)
    end)
    GU.Toggle()
end

local function installHandoff()
    if handoffInstalled or not FriendsFrame then return end
    handoffInstalled = true

    local tab = _G.FriendsFrameTab3
    if tab then
        local stockClick = tab:GetScript("OnClick")
        tab:SetScript("OnClick", function(self, ...)
            if not GU:Enabled() then
                if stockClick then stockClick(self, ...) end
                return
            end
            PlaySound("igCharacterInfoTab")
            HideUIPanel(FriendsFrame)
            GU.Open()
        end)
    end

    hooksecurefunc("FriendsFrame_Update", takeOverGuildTab)
    -- Post-hooks: they run after the stock OnShow, so during it friendsOpen still says whether
    -- the window was up before. Opening the Social window also clears the roster selection.
    FriendsFrame:HookScript("OnShow", function()
        friendsOpen = true
        if GU.selectedName then GU.BuildRoster() end
    end)
    FriendsFrame:HookScript("OnHide", function() friendsOpen = false end)
end

-- ---------------------------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GUILD_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_GUILD_UPDATE")
events:RegisterEvent("GUILD_MOTD")
events:RegisterEvent("GUILD_EVENT_LOG_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        hookLevels()
        if GU:Enabled() then installHandoff() end
        return
    end
    if not GU.IsShown() then return end
    if event == "PLAYER_GUILD_UPDATE" then
        if not IsInGuild() then GU.Close() return end
        GU.RequestLevels("STATE")
    end
    if event == "GUILD_EVENT_LOG_UPDATE" then
        if GU.MarkNewsDirty then GU.MarkNewsDirty() end
        if GU.RefreshNews then GU.RefreshNews() end
        return
    end
    GU.Refresh()
end)

function GuildModule:ApplyGuildSystem()
    hookLevels()
    installHandoff()
end

function GuildModule:RestoreGuildSystem()
    GU.Close()
end

addon.ApplyGuildSystem = function() GuildModule:ApplyGuildSystem() end
addon.RestoreGuildSystem = function() GuildModule:RestoreGuildSystem() end
