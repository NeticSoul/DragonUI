-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates totem icons.

local LayoutTotemIcon

-- Own totems via GetTotemInfo (localized name, icon, timer).

NP.widgets.TotemKnowledge = NP.widgets.TotemKnowledge or {} -- [name] = { icon = blizzardIconPath }
NP.widgets.OwnTotemBySlot = NP.widgets.OwnTotemBySlot or {} -- [slot] = { name, startTime, duration, icon }

local TOTEM_SLOTS = { 1, 2, 3, 4 }
local LocalizedTotemTextures

local function GetLocalizedTotemTextures()
    if LocalizedTotemTextures then
        return LocalizedTotemTextures
    end
    LocalizedTotemTextures = {}
    for i = 1, #(C.TOTEM_SPELL_TEXTURES or {}) do
        local entry = C.TOTEM_SPELL_TEXTURES[i]
        local localizedName = GetSpellInfo and GetSpellInfo(entry[1])
        if localizedName and localizedName ~= "" then
            LocalizedTotemTextures[localizedName] = entry[2]
        end
    end
    return LocalizedTotemTextures
end

function NP.widgets.RefreshOwnTotemSlot(slot)
    slot = tonumber(slot)
    if not slot or not GetTotemInfo then return end
    local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
    if haveTotem and name and name ~= "" then
        NP.widgets.OwnTotemBySlot[slot] = { name = name, startTime = startTime, duration = duration, icon = icon }
        local known = NP.widgets.TotemKnowledge[name]
        if known then
            known.icon = icon
        else
            NP.widgets.TotemKnowledge[name] = { icon = icon }
        end
    else
        NP.widgets.OwnTotemBySlot[slot] = nil
    end
end

function NP.widgets.RefreshAllOwnTotems()
    for i = 1, #TOTEM_SLOTS do
        NP.widgets.RefreshOwnTotemSlot(TOTEM_SLOTS[i])
    end
end

-- PLAYER_TOTEM_UPDATE passes slot number as first arg.
function NP.widgets.OnTotemUpdate(slot)
    NP.widgets.RefreshOwnTotemSlot(slot)
end

-- Own totem info for life timer (start/duration only known for our totems).
function NP.widgets.FindOwnTotemForName(plateName)
    if not plateName then return nil end
    for i = 1, #TOTEM_SLOTS do
        local info = NP.widgets.OwnTotemBySlot[TOTEM_SLOTS[i]]
        if info and info.name == plateName then
            return info
        end
    end
    return nil
end

function NP.widgets.IsTotemName(name)
    if not name then return false end
    if NP.widgets.TotemKnowledge[name] then
        return true
    end
    local localized = GetLocalizedTotemTextures()
    if localized[name] then
        return true
    end
    local bare = name:gsub("%s+[IVXLCDM]+$", "")
    if localized[bare] then
        return true
    end
    local locale = GetLocale and GetLocale() or "enUS"
    local terms = C.TOTEM_CREATURE_TERMS[locale] or C.TOTEM_CREATURE_TERMS.enUS
    for i = 1, #terms do
        if name:find(terms[i], 1, true) then
            return true
        end
    end
    return false
end

-- Strip Roman rank suffix for exact/alias table lookup.
local ROMAN_RANK_SUFFIX = "%s+[IVXLCDM]+$"

local function StripRomanRankSuffix(name)
    if not name then return nil end
    local stripped = name:gsub(ROMAN_RANK_SUFFIX, "")
    if stripped ~= name and stripped ~= "" then
        return stripped
    end
    return nil
end

function NP.widgets.ResolveTotemTexturePath(plateName)
    if not plateName then return nil end
    local localized = GetLocalizedTotemTextures()
    local basename = localized[plateName] or C.TOTEM_EXACT[plateName] or C.TOTEM_ALIASES[plateName]
    if basename then
        return C.TOTEM_TEX .. basename
    end
    local lower = plateName:lower()
    for i = 1, #C.TOTEM_SUBSTRING do
        local entry = C.TOTEM_SUBSTRING[i]
        if lower:find(entry[1], 1, true) then
            return C.TOTEM_TEX .. entry[2]
        end
    end
    local bare = StripRomanRankSuffix(plateName)
    if bare then
        basename = localized[bare] or C.TOTEM_EXACT[bare] or C.TOTEM_ALIASES[bare]
        if basename then
            return C.TOTEM_TEX .. basename
        end
    end
    return nil
end

-- Per-totem "normal" mode override (comma-separated names → full nameplate).

local parsedTotemModeCache = { raw = nil, set = nil }

local function GetTotemNormalModeSet(raw)
    raw = raw or ""
    if parsedTotemModeCache.raw == raw then
        return parsedTotemModeCache.set
    end
    local set = {}
    for token in string.gmatch(raw, "[^,]+") do
        local name = token:match("^%s*(.-)%s*$")
        if name and name ~= "" then
            set[name] = true
        end
    end
    parsedTotemModeCache.raw = raw
    parsedTotemModeCache.set = set
    return set
end

-- "icon" (default) | "normal" (force this totem to render as a plain plate)
function NP.widgets.GetTotemMode(plateName)
    if not plateName then return "icon" end
    local cfg = NP.config.GetCfg()
    local set = GetTotemNormalModeSet(cfg.totemNormalModeList)
    if set[plateName] then
        return "normal"
    end
    return "icon"
end

-- Life timer on own totems only.
local TOTEM_TIMER_UPDATE_INTERVAL = 0.2

local function FormatTotemTimeLeft(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end
    if seconds > 60 then
        return tostring(math.ceil(seconds / 60)) .. "m"
    end
    return tostring(math.ceil(seconds))
end

local function SetTotemTimerPoller(icon, enabled)
    if not icon then return end
    if enabled then
        icon:SetScript("OnUpdate", function(self, elapsed)
            self._timerElapsed = (self._timerElapsed or 0) + elapsed
            if self._timerElapsed < TOTEM_TIMER_UPDATE_INTERVAL then
                return
            end
            self._timerElapsed = 0
            local info = self._ownTotemInfo
            if not info or not self.timerText then return end
            local remaining = (info.startTime + info.duration) - GetTime()
            if remaining <= 0 then
                self.timerText:SetText("")
                self._ownTotemInfo = nil
            else
                self.timerText:SetText(FormatTotemTimeLeft(remaining))
            end
        end)
    else
        icon:SetScript("OnUpdate", nil)
        if icon.timerText then
            icon.timerText:SetText("")
        end
        icon._ownTotemInfo = nil
    end
end

-- Frame hosts timer FontString and OnUpdate poller.
local function EnsureTotemIcon(plateData)
    if plateData._totemIcon then return plateData._totemIcon end
    local plate = plateData and plateData.plate
    if not plate then return nil end
    local icon = CreateFrame("Frame", nil, plate)
    icon:SetSize(C.TOTEM_ICON_W, C.TOTEM_ICON_H)
    icon.tex = icon:CreateTexture(nil, "OVERLAY")
    icon.tex:SetAllPoints(icon)
    local fs = icon:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    fs:SetPoint("BOTTOM", icon, "BOTTOM", 0, -10)
    icon.timerText = fs
    icon:Hide()
    plateData._totemIcon = icon
    return icon
end

local function HideTotemIcon(plateData)
    local icon = plateData and plateData._totemIcon
    if not icon then return end
    icon:Hide()
    SetTotemTimerPoller(icon, false)
end

function NP.widgets.SyncTotemIcon(plateData)
    local cfg = NP.config.GetCfg()
    if cfg.showTotemIcons == false then
        HideTotemIcon(plateData)
        return
    end
    local plateName = plateData.plateName or NP.discovery.GetPlateName(plateData)
    if not plateName or not NP.widgets.IsTotemName(plateName) then
        HideTotemIcon(plateData)
        return
    end
    if NP.widgets.GetTotemMode(plateName) == "normal" then
        HideTotemIcon(plateData)
        return
    end
    -- Prefer own Blizzard totem icon; else curated family texture.
    local ownInfo = NP.widgets.FindOwnTotemForName(plateName)
    local texture = (ownInfo and ownInfo.icon) or NP.widgets.ResolveTotemTexturePath(plateName)
    if not texture then
        HideTotemIcon(plateData)
        return
    end
    local icon = EnsureTotemIcon(plateData)
    if not icon then return end
    icon.tex:SetTexture(texture)
    if ownInfo and cfg.showTotemTimer ~= false then
        icon._ownTotemInfo = ownInfo
        SetTotemTimerPoller(icon, true)
    else
        SetTotemTimerPoller(icon, false)
    end
    if LayoutTotemIcon(plateData) then
        icon:Show()
    end
end

LayoutTotemIcon = function(plateData)
    local icon = plateData and plateData._totemIcon
    local hp = plateData and plateData.minaHp
    local plate = plateData and plateData.plate
    local anchorFrame = hp or plate
    if not icon or not anchorFrame then return false end

    -- Icon-only: center on hp so icon aligns with shrunk clickbox.
    if hp and NP.gather and NP.gather.IsTotemIconOnlyActive and NP.gather.IsTotemIconOnlyActive(plateData) then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", hp, "CENTER", 0, 10)
        return true
    end

    local cfg = NP.config.GetCfg()
    local pos = cfg.totemIconPosition or "top"
    local point = "TOP"
    local relPoint = "TOP"
    local x = C.TOTEM_ICON_OFFSET_X
    local y = C.TOTEM_ICON_OFFSET_Y

    if pos == "right" then
        point = "RIGHT"
        relPoint = "RIGHT"
        x = C.TOTEM_ICON_RIGHT_OFFSET_X or 30
        y = C.TOTEM_ICON_RIGHT_OFFSET_Y or 6
    elseif pos == "left" then
        point = "LEFT"
        relPoint = "LEFT"
        x = C.TOTEM_ICON_LEFT_OFFSET_X or -30
        y = C.TOTEM_ICON_LEFT_OFFSET_Y or 6
    end

    icon:ClearAllPoints()
    icon:SetPoint(point, anchorFrame, relPoint, x, y)
    return true
end

NP.widgets.Register("Totem", {
    Ensure = function(plateData)
        return EnsureTotemIcon(plateData) ~= nil
    end,
    Layout = function(plateData)
        return LayoutTotemIcon(plateData)
    end,
    Sync = function(plateData)
        NP.widgets.SyncTotemIcon(plateData)
    end,
    Hide = function(plateData)
        if plateData and plateData._totemIcon then
            plateData._totemIcon:Hide()
            SetTotemTimerPoller(plateData._totemIcon, false)
        end
    end,
})
