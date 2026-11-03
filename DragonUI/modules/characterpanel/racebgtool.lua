-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

local RACES = { "Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Scourge", "Tauren", "Troll", "BloodElf" }
local SEXES = { { id = 2, folder = "Male" }, { id = 3, folder = "Female" } }
local FACING = 0.61

local bar, page, sexIndex

-- The race's own model file carries the camera a player of that race gets.
local function apply()
    local model = _G.InspectModelFrame
    if not (bar and model and model._duiRaceBg) then return end
    local race, sex = RACES[page], SEXES[sexIndex]
    model:SetModel("Character\\" .. race .. "\\" .. sex.folder .. "\\" .. race .. sex.folder .. ".mdx")
    model.rotation = FACING
    model:SetRotation(FACING)
    CP.PaintRaceBackdrop(model._duiRaceBg, model._duiRaceBgShade, race, sex.id)
    local lift = CP.RaceBackdropLift(CP.RaceLiftKey(race, sex.id))
    bar.label:SetText(string.format("%s %s\n%d / %d   lift %+d", race, sex.folder, page, #RACES, lift))
end

local function turn(step)
    page = (page - 1 + step) % #RACES + 1
    apply()
end

local function toggleSex()
    sexIndex = 3 - sexIndex
    apply()
end

local function button(text, width, onClick)
    local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function build()
    bar = CreateFrame("Frame", "DragonUIRaceBgPreview", _G.InspectFrame)
    bar:Hide()
    bar:SetSize(172, 108)
    bar:SetPoint("TOPLEFT", _G.InspectFrame, "TOPRIGHT", -26, -24)
    bar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    bar:EnableMouse(true)

    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.label:SetPoint("TOP", bar, "TOP", 0, -16)

    local prev = button("< Prev", 70, function() turn(-1) end)
    prev:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 14, 40)
    local nextRace = button("Next >", 70, function() turn(1) end)
    nextRace:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    local sex = button("Male / Female", 144, toggleSex)
    sex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 14, 16)

    -- Closing the inspect window ends the preview and hands the viewport back to real units.
    bar:SetScript("OnHide", function() CP.InspectPreview = nil end)
end

local function start()
    if not _G.InspectFrame then LoadAddOn("Blizzard_InspectUI") end
    if not (_G.InspectFrame and _G.InspectSwitchTabs) then return end
    if not bar then build() end
    if not page then
        local _, own = UnitRace("player")
        page, sexIndex = 1, UnitSex("player") == 3 and 2 or 1
        for i, race in ipairs(RACES) do
            if race == own then page = i end
        end
    end
    CP.InspectPreview = apply
    _G.InspectFrame.unit = "player"
    _G.InspectSwitchTabs(1)
    bar:Show()
    apply()
end

function addon.ToggleRaceBackdropTool()
    if bar and bar:IsShown() then
        HideUIPanel(_G.InspectFrame)
    else
        start()
    end
end
