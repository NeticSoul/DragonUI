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

-- Retail lifts the level line from -42 to -36 whenever a second line sits under it, so the
-- pair centers as a block; our second line is Blizzard's guild text.
local function levelY()
    local guild = _G.CharacterGuildText
    return (guild and guild:IsShown()) and -36 or -42
end

local function reposition()
    local fs = _G.CharacterLevelText
    if not fs or not _G.PaperDollFrame or not CP:Enabled() then return end
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", _G.PaperDollFrame, "TOP", 0, levelY())
end

-- Wrath dropped the guild line: PaperDollFrame.lua has the SetGuild call commented out, so
-- CharacterGuildText exists and is shown but nothing ever fills it. Drive it ourselves.
local function rewriteGuild()
    if not _G.CharacterGuildText or not _G.PaperDollFrame_SetGuild then return end
    PaperDollFrame_SetGuild()
end

-- Gated here, not at the builder: the hooks and the event frame below survive a disable, and both
-- kept the guild line filled and the level line lifted on a window that no longer has room for it.
local function rewrite()
    local fs = _G.CharacterLevelText
    if not fs or not CP:Enabled() then return end
    if CP:Config().class_level_text then fs:SetText(levelString()) end
    rewriteGuild()
    reposition()
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

local setLevelHooked, setGuildHooked

local function build()
    if not _G.CharacterLevelText then return end

    rewrite()

    if _G.PaperDollFrame_SetLevel and not setLevelHooked then
        setLevelHooked = true
        hooksecurefunc("PaperDollFrame_SetLevel", rewrite)
    end
    if _G.PaperDollFrame_SetGuild and not setGuildHooked then
        setGuildHooked = true
        hooksecurefunc("PaperDollFrame_SetGuild", reposition)
    end
end

CP.RefreshLevelText = rewrite

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_GUILD_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function() rewrite() end)

CP:RegisterBuilder("leveltext", build)
