-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

local STOCK_ICON = "Interface\\WorldMap\\WorldMapPartyIcon"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local BLIPS = "Interface\\Minimap\\PartyRaidBlips"
-- The minimap's own class blips: an 8x4 grid in class-ID order, the raid variant in the lower half.
local BLIP_CELL = {
    WARRIOR = 0, PALADIN = 1, HUNTER = 2, ROGUE = 3, PRIEST = 4,
    DEATHKNIGHT = 5, SHAMAN = 6, MAGE = 7, WARLOCK = 8, DRUID = 10,
}
-- Class emblems blur at the stock pin size; on the world map theirs holds on screen, like the arrow.
local WORLD_ICON_SIZE, BATTLEFIELD_ICON_SIZE = 17, 18
local POLL = 0.2
local NAME_HEALTH = "%s |cffb3b3b3%s|r"
local MENU_STYLES = { { "icon", "Class Icons" }, { "color", "Class Colors" }, { "blizzard", "Default (Blizzard)" } }

-- Looks are { texture, left, right, top, bottom }, compared by identity to skip unchanged pins.
local STOCK = { STOCK_ICON, 0, 1, 0, 1 }
local ICONS, PARTY_BLIPS, RAID_BLIPS, NAME_COLORS = {}, {}, {}, {}

for class, c in pairs(CLASS_ICON_TCOORDS) do
    ICONS[class] = { CLASS_ICONS, c[1], c[2], c[3], c[4] }
end
for class, cell in pairs(BLIP_CELL) do
    local left, top = cell % 8 / 8, math.floor(cell / 8) / 4
    PARTY_BLIPS[class] = { BLIPS, left, left + 0.125, top, top + 0.25 }
    RAID_BLIPS[class] = { BLIPS, left, left + 0.125, top + 0.5, top + 0.75 }
end
for class, c in pairs(RAID_CLASS_COLORS) do
    NAME_COLORS[class] = format("|cff%02x%02x%02x%%s|r", c.r * 255, c.g * 255, c.b * 255)
end

local pinStyle = "color"
local pins, looks, owners, drivers, roster, sets = {}, {}, {}, {}, {}, {}

local function lookFor(who, unit)
    if pinStyle == "blizzard" or not who then return STOCK end
    local _, class = UnitClass(who)
    if pinStyle == "icon" then return ICONS[class] or STOCK end
    local blips = unit and UnitInParty(unit) and PARTY_BLIPS or RAID_BLIPS
    return blips[class] or STOCK
end

-- In a raid Blizzard re-shows a pin every frame, so an unchanged owner costs one compare.
local function dress(pin)
    local who = pin.unit or pin.name
    if not pins[pin] or owners[pin] == who then return end
    owners[pin] = who
    local look = lookFor(who, pin.unit)
    if looks[pin] == look then return end
    looks[pin] = look
    -- Only texture and coords: Blizzard's own vertex colour carries the PvP-inactive tint.
    pin.icon:SetTexture(look[1])
    pin.icon:SetTexCoord(look[2], look[3], look[4], look[5])
end

-- Roster and style changes alter a look behind an unchanged owner, so they start over.
local function dressAll()
    wipe(owners)
    for pin in pairs(pins) do dress(pin) end
end

-- When a raid member leaves the map the later pins shift to other units with no fresh OnShow.
local function watch(map, prefix, size, iconSize, onCanvas)
    local set, raid = { size = size, iconSize = iconSize, onCanvas = onCanvas }, {}
    for i = 1, MAX_PARTY_MEMBERS do set[#set + 1] = _G[prefix .. "Party" .. i] end
    for i = 1, MAX_RAID_MEMBERS do
        raid[i] = _G[prefix .. "Raid" .. i]
        set[#set + 1] = raid[i]
    end
    for i = 1, #set do pins[set[i]] = true end
    sets[#sets + 1] = set

    local since = 0
    local driver = CreateFrame("Frame", nil, map)
    driver:SetScript("OnUpdate", function(_, elapsed)
        since = since + elapsed
        if since < POLL then return end
        since = 0
        for i = 1, MAX_RAID_MEMBERS do
            local pin = raid[i]
            if owners[pin] ~= (pin.unit or pin.name) and pin:IsShown() then dress(pin) end
        end
    end)
    drivers[#drivers + 1] = driver
end

-- ============================================================================
-- TOOLTIP
-- ============================================================================

local function fillRoster()
    wipe(roster)
    roster[UnitName("player")] = "player"
    local prefix, count = "raid", GetNumRaidMembers()
    if count == 0 then prefix, count = "party", GetNumPartyMembers() end
    for i = 1, count do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name then roster[name] = unit end
    end
end

local function decorate(line)
    local unit = roster[line]
    if not unit then return end
    local _, class = UnitClass(unit)
    local health = UnitIsDeadOrGhost(unit) and DEAD
        or format("%d%%", 100 * UnitHealth(unit) / math.max(UnitHealthMax(unit), 1))
    return format(NAME_HEALTH, format(NAME_COLORS[class] or "%s", line), health)
end

-- Blizzard writes every hovered name as one line of TextLeft1, so only whole lines are matched.
local function decorateTooltip(tooltip)
    if pinStyle == "blizzard" then return end
    local text = _G[tooltip:GetName() .. "TextLeft1"]:GetText()
    if not text then return end
    fillRoster()
    tooltip:SetText((text:gsub("[^\n]+", decorate)))
    tooltip:Show()
end

-- ============================================================================
-- BUILD
-- ============================================================================

local function attachBattlefieldMap()
    watch(BattlefieldMinimap, "BattlefieldMinimap", 12, BATTLEFIELD_ICON_SIZE, false)
    hooksecurefunc("BattlefieldMinimapUnit_OnEnter", function() decorateTooltip(GameTooltip) end)
end

local function pinSize(set, icons)
    if not set.onCanvas then return icons and set.iconSize or set.size end
    if not icons then return set.size / (WM.zoom or 1) end
    return set.iconSize * WorldMapFrame:GetEffectiveScale() / WorldMapButton:GetEffectiveScale()
end

-- Size, not scale: Blizzard re-anchors these every frame in the button's own units.
function WM.SizeGroupPins()
    local icons = pinStyle == "icon"
    for _, set in ipairs(sets) do
        local size = pinSize(set, icons)
        for i = 1, #set do set[i]:SetSize(size, size) end
    end
end

function WM.RefreshGroupPins()
    pinStyle = WM:Config().groupPins or "color"
    for i = 1, #drivers do
        if pinStyle == "blizzard" then drivers[i]:Hide() else drivers[i]:Show() end
    end
    WM.SizeGroupPins()
    dressAll()
end

-- The quest log cog's copy of the option, listed only when there are group pins to restyle.
function WM.AddGroupPinEntries(entries)
    if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then return end
    entries[#entries + 1] = { isDivider = true }
    entries[#entries + 1] = { text = L["Group Member Pins"], isTitle = true }
    for _, option in ipairs(MENU_STYLES) do
        local style = option[1]
        entries[#entries + 1] = {
            text = L[option[2]],
            checked = function() return pinStyle == style end,
            keepShown = true,
            func = function()
                WM:Config().groupPins = style
                WM.RefreshGroupPins()
            end,
        }
    end
end

function WM.BuildGroupPins()
    watch(WorldMapFrame, "WorldMap", 16, WORLD_ICON_SIZE, true)
    hooksecurefunc("WorldMapUnit_Update", dress)
    hooksecurefunc("WorldMapUnit_OnEnter", function() decorateTooltip(WorldMapTooltip) end)

    -- The battlefield map's roster handler refreshes the world map's pins instead of its own.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PARTY_MEMBERS_CHANGED")
    events:RegisterEvent("RAID_ROSTER_UPDATE")
    if IsAddOnLoaded("Blizzard_BattlefieldMinimap") then
        attachBattlefieldMap()
    else
        events:RegisterEvent("ADDON_LOADED")
    end
    events:SetScript("OnEvent", function(self, event, name)
        if event ~= "ADDON_LOADED" then return dressAll() end
        if name ~= "Blizzard_BattlefieldMinimap" then return end
        self:UnregisterEvent("ADDON_LOADED")
        attachBattlefieldMap()
        WM.RefreshGroupPins()
    end)

    WM.RefreshGroupPins()
end
