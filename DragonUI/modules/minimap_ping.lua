-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local label

local function enabled()
    local settings = addon.db and addon.db.profile.minimap
    return settings and settings.ping_sender ~= false and addon:IsModuleEnabled("minimap")
end

local function onPing(_, _, unit)
    if not (unit and enabled()) or UnitIsUnit(unit, "player") then
        if label then label:SetText("") end
        return
    end
    if not label then
        -- On the ping itself, so it fades and hides along with it.
        label = MinimapPing:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", MinimapPing, "CENTER", 0, -12)
    end
    local _, class = UnitClass(unit)
    local color = class and RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR
    label:SetText(UnitName(unit))
    label:SetTextColor(color.r, color.g, color.b)
end

local events = CreateFrame("Frame")
events:RegisterEvent("MINIMAP_PING")
events:SetScript("OnEvent", onPing)
