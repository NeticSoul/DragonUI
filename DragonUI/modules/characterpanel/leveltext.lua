-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

local function classColored(text, classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not c then return text end
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

local function levelString()
    local classDisplay, classFile = UnitClass("player")
    return string.format(PLAYER_LEVEL, UnitLevel("player") or 1, UnitRace("player") or "",
                         classColored(classDisplay or "", classFile))
end

-- Retail lifts the level line from -42 to -36 when a second line shows under it, centring the pair.
local LEVEL_Y_ALONE, LEVEL_Y_PAIRED = -42, -36

local function placeLevelLine()
    local line, pane = _G.CharacterLevelText, _G.PaperDollFrame
    if not (line and pane) or not CP:Enabled() then return end

    local guildLine = _G.CharacterGuildText
    local y = LEVEL_Y_ALONE
    if guildLine and guildLine:IsShown() then y = LEVEL_Y_PAIRED end
    line:ClearAllPoints()
    line:SetPoint("CENTER", pane, "TOP", 0, y)
end

-- Wrath dropped the guild line: PaperDollFrame.lua has the SetGuild call commented out, so
-- CharacterGuildText exists and is shown but nothing ever fills it. Drive it ourselves.
local function rewriteGuild()
    if not _G.CharacterGuildText or not _G.PaperDollFrame_SetGuild then return end
    PaperDollFrame_SetGuild()
end

-- Guild line before placement: the level line's Y depends on whether that line ended up shown.
local function rewriteLevelLine()
    local line = _G.CharacterLevelText
    if line == nil or not CP:Enabled() then return end

    if CP:Config().class_level_text then line:SetText(levelString()) end
    rewriteGuild()
    placeLevelLine()
end

-- Blizzard anchors the pair in XML only, so nothing but this puts them back.
function CP.RestoreLevelText()
    local fs = _G.CharacterLevelText
    if not fs or not _G.CharacterNameText then return end
    fs:ClearAllPoints()
    fs:SetPoint("TOP", _G.CharacterNameText, "BOTTOM", 0, -6)
    if _G.PaperDollFrame_SetLevel then PaperDollFrame_SetLevel() end
    -- Wrath never fills this; leaving our text behind would be the one line vanilla does not draw.
    if _G.CharacterGuildText then _G.CharacterGuildText:SetText("") end
end

local hookedSetLevel, hookedSetGuild = false, false

local function build()
    if _G.CharacterLevelText == nil then return end
    rewriteLevelLine()

    if not hookedSetLevel and _G.PaperDollFrame_SetLevel then
        hooksecurefunc("PaperDollFrame_SetLevel", rewriteLevelLine)
        hookedSetLevel = true
    end
    -- Placement only: the rewrite step calls PaperDollFrame_SetGuild itself and would recurse.
    if not hookedSetGuild and _G.PaperDollFrame_SetGuild then
        hooksecurefunc("PaperDollFrame_SetGuild", placeLevelLine)
        hookedSetGuild = true
    end
end

CP.RefreshLevelText = rewriteLevelLine

local levelEvents = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_GUILD_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    levelEvents:RegisterEvent(event)
end
levelEvents:SetScript("OnEvent", rewriteLevelLine)

CP:RegisterBuilder("leveltext", build)
