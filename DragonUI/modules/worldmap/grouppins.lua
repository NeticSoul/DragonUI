-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap

local STOCK_ICON = "Interface\\WorldMap\\WorldMapPartyIcon"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CIRCLE = addon._dir .. "WorldMap\\whitecircle-raidblips"
local DOT_CIRCLE = addon._dir .. "WorldMap\\whitedotcircle-raidblips"
-- party/raid are retail's GroupMembersDataProvider sizes; class emblems blur any smaller.
local WORLD_SIZES = { blizzard = 12, icon = 17, party = 11, raid = 8.25 }
local BATTLEFIELD_SIZES = { blizzard = 12, icon = 18, party = 8, raid = 8 }
local PVP_INACTIVE = { r = 0.5, g = 0.2, b = 0.8 }
local POLL = 0.2
local NAME_HEALTH = "%s |cffb3b3b3%s|r"
local MENU_STYLES = { { "icon", "Class Icons" }, { "color", "Class Colors" }, { "blizzard", "Default (Blizzard)" } }

-- Looks are { texture, left, right, top, bottom, size key }, compared by identity to skip unchanged pins.
local STOCK = { STOCK_ICON, 0, 1, 0, 1, "blizzard" }
-- Retail's circles: in a raid your own subgroup carries the centre dot and the rest draw smaller.
local PARTY = { CIRCLE, 0, 1, 0, 1, "party" }
local SUBGROUP = { DOT_CIRCLE, 0, 1, 0, 1, "party" }
local RAID = { CIRCLE, 0, 1, 0, 1, "raid" }
local ICONS, NAME_COLORS = {}, {}

for class, c in pairs(CLASS_ICON_TCOORDS) do
    ICONS[class] = { CLASS_ICONS, c[1], c[2], c[3], c[4], "icon" }
end
for class, c in pairs(RAID_CLASS_COLORS) do
    NAME_COLORS[class] = format("|cff%02x%02x%02x%%s|r", c.r * 255, c.g * 255, c.b * 255)
end

local pinStyle = "color"
local pins, partyPins, looks, owners, colors, drivers, roster, sets = {}, {}, {}, {}, {}, {}, {}, {}

local function lookFor(pin, who)
    if pinStyle == "blizzard" or not who then return STOCK end
    local _, class = UnitClass(who)
    if pinStyle == "icon" then return ICONS[class] or STOCK end
    local color = RAID_CLASS_COLORS[class]
    if not color then return STOCK end
    if partyPins[pin] then return PARTY, color end
    return pin.unit and UnitInParty(pin.unit) and SUBGROUP or RAID, color
end

local function canvasFactor(set)
    if not set.onCanvas then return 1 end
    return WorldMapFrame:GetEffectiveScale() / WorldMapButton:GetEffectiveScale()
end

-- Size, not scale: Blizzard re-anchors these every frame in the button's own units.
local function resize(pin, set, factor)
    local size = set.sizes[(looks[pin] or STOCK)[6]] * factor
    pin:SetSize(size, size)
end

-- Each WorldMapUnit_Update resets the colour to white or PvP-AFK purple; ours goes back on after it.
local function tint(pin, who)
    local c = who and PlayerIsPVPInactive(who) and PVP_INACTIVE or colors[pin]
    if c then pin.icon:SetVertexColor(c.r, c.g, c.b) else pin.icon:SetVertexColor(1, 1, 1) end
end

-- In a raid Blizzard re-shows a pin every frame, so an unchanged owner only gets its colour back.
local function dress(pin)
    local set = pins[pin]
    if not set then return end
    local who = pin.unit or pin.name
    if owners[pin] ~= who then
        owners[pin] = who
        local look, color = lookFor(pin, who)
        colors[pin] = color
        if looks[pin] ~= look then
            looks[pin] = look
            pin.icon:SetTexture(look[1])
            pin.icon:SetTexCoord(look[2], look[3], look[4], look[5])
            resize(pin, set, canvasFactor(set))
        end
    end
    tint(pin, who)
end

-- Roster and style changes alter a look behind an unchanged owner, so they start over.
local function dressAll()
    wipe(owners)
    for pin in pairs(pins) do dress(pin) end
end

-- When a raid member leaves the map the later pins shift to other units with no fresh OnShow.
local function watch(map, prefix, sizes, onCanvas)
    local set, raid = { sizes = sizes, onCanvas = onCanvas }, {}
    for i = 1, MAX_PARTY_MEMBERS do
        local pin = _G[prefix .. "Party" .. i]
        partyPins[pin] = true
        set[#set + 1] = pin
    end
    for i = 1, MAX_RAID_MEMBERS do
        raid[i] = _G[prefix .. "Raid" .. i]
        set[#set + 1] = raid[i]
    end
    for i = 1, #set do pins[set[i]] = set end
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
    watch(BattlefieldMinimap, "BattlefieldMinimap", BATTLEFIELD_SIZES, false)
    hooksecurefunc("BattlefieldMinimapUnit_OnEnter", function() decorateTooltip(GameTooltip) end)
end

-- The canvas scale carries map size and zoom; pins cancel both to hold one screen size, like retail.
function WM.SizeGroupPins()
    for _, set in ipairs(sets) do
        local factor = canvasFactor(set)
        for i = 1, #set do resize(set[i], set, factor) end
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

-- The quest log cog's copy of the option; listed solo too, as many only open this menu once.
function WM.AddGroupPinEntries(entries)
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
                addon.core:SendMessage("DRAGONUI_WINDOW_SETTING_CHANGED", "worldmap")
            end,
        }
    end
end

function WM.BuildGroupPins()
    watch(WorldMapFrame, "WorldMap", WORLD_SIZES, true)
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
