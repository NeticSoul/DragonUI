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
    if not fs or not _G.PaperDollFrame then return end
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", _G.PaperDollFrame, "TOP", 0, levelY())
end

-- Wrath dropped the guild line: PaperDollFrame.lua has the SetGuild call commented out, so
-- CharacterGuildText exists and is shown but nothing ever fills it. Drive it ourselves.
local function rewriteGuild()
    if not _G.CharacterGuildText or not _G.PaperDollFrame_SetGuild then return end
    PaperDollFrame_SetGuild()
end

local function rewrite()
    local fs = _G.CharacterLevelText
    if not fs then return end
    if CP:Config().class_level_text then fs:SetText(levelString()) end
    rewriteGuild()
    reposition()
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
