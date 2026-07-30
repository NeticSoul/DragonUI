-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

local function T(key, fallback)
    return (L and L[key]) or fallback or key
end

-- ============================================================================
-- ALT MONEY MODULE FOR DRAGONUI
-- Hovering the coins in the bags lists the gold of every character that has
-- logged in with DragonUI. Same realm by default, all realms is opt-in.
-- Works on the Bagster money display and on the stock backpack money frame.
-- ============================================================================

local AltMoneyModule = {
    initialized = false,
    applied = false
}

if addon.RegisterModule then
    addon:RegisterModule("altmoney", AltMoneyModule,
        T("Alt Gold"),
        T("Show the gold of your other characters when hovering the money in your bags"),
        { lifecyclePrefix = "AltMoney" })
end

local GameTooltip = GameTooltip
local GetMoney, UnitName, UnitClass, GetRealmName = GetMoney, UnitName, UnitClass, GetRealmName
local floor, sort, format = math.floor, table.sort, string.format

local playerName = UnitName("player")
local playerRealm = GetRealmName() or ""
local playerKey = playerRealm .. "|" .. playerName

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("altmoney")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("altmoney")
end

local function ShowsAllRealms()
    local cfg = GetModuleConfig()
    return (cfg and cfg.show_all_realms) and true or false
end

-- ============================================================================
-- STORAGE (global scope: the only AceDB scope shared across characters)
-- ============================================================================

local function GetStore(create)
    if not addon.db or not addon.db.global then return nil end
    local store = addon.db.global.characterMoney
    if not store then
        if not create then return nil end
        store = {}
        addon.db.global.characterMoney = store
    end
    return store
end

local function SaveCurrentCharacter()
    local store = GetStore(true)
    if not store then return end
    local entry = store[playerKey]
    if not entry then
        entry = {}
        store[playerKey] = entry
    end
    entry.copper = GetMoney() or 0
    entry.class = select(2, UnitClass("player"))
end

-- Bagster's offline bank view needs an alt's gold; the live API only knows the current character.
function addon.GetCharacterMoney(name, realm)
    if not name then return nil end
    local store = GetStore(false)
    if not store then return nil end
    local entry = store[(realm or playerRealm) .. "|" .. name]
    return entry and entry.copper or nil
end

-- ============================================================================
-- TOOLTIP
-- ============================================================================

local GOLD_SYMBOL = GOLD_AMOUNT_SYMBOL or "g"
local SILVER_SYMBOL = SILVER_AMOUNT_SYMBOL or "s"
local COPPER_SYMBOL = COPPER_AMOUNT_SYMBOL or "c"

local function FormatMoney(copper)
    copper = copper or 0
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return format("|cffffd700%d%s|r |cffc7c7cf%d%s|r |cffeda55f%d%s|r",
        floor(copper / 10000), GOLD_SYMBOL,
        floor((copper % 10000) / 100), SILVER_SYMBOL,
        copper % 100, COPPER_SYMBOL)
end

local function ClassColor(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local entries = {}

local function CollectEntries()
    for i = #entries, 1, -1 do
        entries[i] = nil
    end

    local store = GetStore(false)
    if not store then return end

    local allRealms = ShowsAllRealms()
    for key, data in pairs(store) do
        local realm, name = string.match(key, "^(.-)|(.+)$")
        if name and type(data) == "table" and (allRealms or realm == playerRealm) then
            entries[#entries + 1] = {
                name = name,
                realm = realm,
                copper = data.copper or 0,
                class = data.class
            }
        end
    end

    sort(entries, function(a, b)
        if a.realm ~= b.realm then
            if a.realm == playerRealm then return true end
            if b.realm == playerRealm then return false end
            return a.realm < b.realm
        end
        if a.copper ~= b.copper then return a.copper > b.copper end
        return a.name < b.name
    end)
end

local function ShowMoneyTooltip(owner)
    SaveCurrentCharacter()
    CollectEntries()

    GameTooltip:SetOwner(owner, "ANCHOR_TOPRIGHT")
    GameTooltip:AddLine(T("Character Gold"), 1, 0.82, 0)

    local allRealms = ShowsAllRealms()
    local total, lastRealm = 0, nil

    for i = 1, #entries do
        local entry = entries[i]
        if allRealms and entry.realm ~= lastRealm then
            lastRealm = entry.realm
            GameTooltip:AddLine((entry.realm ~= "" and entry.realm) or UNKNOWN, 0.6, 0.6, 0.6)
        end

        local label = entry.name
        if entry.name == playerName and entry.realm == playerRealm then
            label = label .. " |cff808080" .. T("(current)") .. "|r"
        end

        local r, g, b = ClassColor(entry.class)
        GameTooltip:AddDoubleLine(label, FormatMoney(entry.copper), r, g, b, 1, 1, 1)
        total = total + entry.copper
    end

    if #entries <= 1 then
        GameTooltip:AddLine(T("No other characters recorded yet"), 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T("Total"), FormatMoney(total), 1, 0.82, 0, 1, 1, 1)
    end

    GameTooltip:Show()
end

-- ============================================================================
-- MONEY FRAME HOOKS
-- ============================================================================

local hookedButtons = {}

local function OnMoneyEnter(self)
    if not IsModuleEnabled() then return end
    local frame = self:GetParent()
    if frame and frame.isGuildFunds then return end
    ShowMoneyTooltip(self)
end

local function OnMoneyLeave(self)
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

-- HookScript keeps the coin OnClick (CoinPickupFrame) intact; SetScript would replace it.
local function HookButton(button)
    if not button or hookedButtons[button] then return end
    hookedButtons[button] = true
    button:HookScript("OnEnter", OnMoneyEnter)
    button:HookScript("OnLeave", OnMoneyLeave)
end

local function HookBlizzardMoneyFrames()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local name = "ContainerFrame" .. i .. "MoneyFrame"
        HookButton(_G[name .. "GoldButton"])
        HookButton(_G[name .. "SilverButton"])
        HookButton(_G[name .. "CopperButton"])
    end
end

-- Bagster builds its money displays at runtime and calls this for each instance.
function addon.RegisterAltMoneyFrame(frame)
    if not frame then return end
    HookButton(frame.btnGold)
    HookButton(frame.btnSilver)
    HookButton(frame.btnCopper)
    HookButton(frame.btnText)
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

local function ApplyAltMoneySystem()
    HookBlizzardMoneyFrames()
    SaveCurrentCharacter()
    AltMoneyModule.initialized = true
    AltMoneyModule.applied = true
end

-- Every hook body re-checks IsModuleEnabled(), so leaving them installed is inert.
local function RestoreAltMoneySystem()
    AltMoneyModule.applied = false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event)
    if not IsModuleEnabled() then return end
    if event == "PLAYER_ENTERING_WORLD" then
        ApplyAltMoneySystem()
    else
        SaveCurrentCharacter()
    end
end)

-- Registry lifecycle resolves these off `addon` via lifecyclePrefix "AltMoney".
addon.ApplyAltMoneySystem = ApplyAltMoneySystem
addon.RestoreAltMoneySystem = RestoreAltMoneySystem
