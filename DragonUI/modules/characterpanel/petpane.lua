-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The pet stats retail deleted with PetPaperDollFrame, on tab 2 -- Blizzard's own pet slot. Vanilla's
-- own arrangement (model centred, resistances down the right, stats boxed below) in retail chrome.

local FRAME_NAME = "DragonUIPetFrame"
local TAB_INDEX = 2

local PAD = 10
local HEADER_H = 44
local ROW_H = 15
local STATS_H = 94
local XP_H = 12
-- Matches a resistance icon's OUTER size: those are 28 plus the frame's overhang, and this art
-- carries its own frame, so equal inner sizes would read as two different sizes on screen.
local HAPPY_SIZE = 31

local RESIST_SIZE = 28
local RESIST_GAP = 5
local RESIST_COL_W = RESIST_SIZE + 8

-- Our own sheets: the client's art upscaled and cut out of its 2004 frame, in square cells, so the
-- action bar's own chrome can frame them the way every other icon in DragonUI is framed.
local RESIST_SHEET = addon._dir .. "CharacterPanel\\resistanceicons.tga"
local RESIST_CELL = 0.125
local HAPPY_SHEET = addon._dir .. "CharacterPanel\\happinessicons.tga"
local HAPPY_CELL = 0.25

-- The action bar's frame, not the white one: that exists to be tinted, and this panel wants the
-- bar's own colouring rather than a flat black rectangle.
local ICON_FRAME = addon._dir .. "ActionBars\\uiactionbariconframe.tga"
-- Overhang measured off the 37px art the border is cut at, scaled to whatever size it frames.
local function frameOverhang(size)
    local k = size / 37
    return 2.2 * k, 2.3 * k
end

-- GetPetHappiness counts up from unhappy, which is the order the frog sheet is stacked in.
local HAPPY_CELL_OF = { [1] = 0, [2] = 1, [3] = 2 }

-- Blizzard's own display order, which is not UnitResistance's index order. Retail deleted
-- resistances outright, so this art has no modern counterpart to port.
local RESISTANCES = { 6, 2, 3, 4, 5 }
-- Cell order on our sheet, which follows the source's: fire, nature, arcane, frost, shadow.
local RESIST_CELL_OF = { [2] = 0, [3] = 1, [6] = 2, [4] = 3, [5] = 4 }

local NUM_PET_STATS = 5

local pane, host
local model, petName, petLevel, petDiet, happy, xpBar, xpText, emptyText, statsBlock
local attrRows, combatRows, resistIcons = {}, {}, {}

local function hasPet()
    if not HasPetUI then return false end
    return (HasPetUI()) and UnitExists("pet") and true or false
end

local function isHunterPet()
    if not HasPetUI then return false end
    return (select(2, HasPetUI())) and true or false
end

CP.PetTabAvailable = hasPet

local function colored(value, positive, negative)
    if negative and negative < 0 then
        return RED_FONT_COLOR_CODE .. value .. FONT_COLOR_CODE_CLOSE
    end
    if positive and positive > 0 then
        return GREEN_FONT_COLOR_CODE .. value .. FONT_COLOR_CODE_CLOSE
    end
    return tostring(value)
end

local function showTooltip(self)
    if not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tooltip, 1, 1, 1)
    if self.tooltip2 then
        GameTooltip:AddLine(self.tooltip2, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
                            NORMAL_FONT_COLOR.b, true)
    end
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

-- Label gold, value white, both on one line: vanilla's stat block, which is what makes it read as
-- two dense columns rather than a list.
local function buildStatRow(column, previous, index)
    local row = CreateFrame("Frame", nil, column)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)

    if previous then
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, 0)
    else
        row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, 0)
    end

    -- Same zebra wash the character sidebar uses: a flat white at 5%, never the brown Line-Bounce
    -- strip, which tints every other row. Only the even rows carry it.
    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", row, "TOPLEFT", -6, 0)
        bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 6, 0)
        bg:SetTexture(1, 1, 1)
        bg:SetAlpha(0.05)
    end

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    value:SetJustifyH("RIGHT")
    row.Value = value

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetPoint("RIGHT", value, "LEFT", -4, 0)
    label:SetJustifyH("LEFT")
    row.Text = label

    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", hideTooltip)
    return row
end

local function buildResistIcon(parent, school, index)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(RESIST_SIZE, RESIST_SIZE)
    frame:SetPoint("TOP", parent, "TOP", 0, -(index - 1) * (RESIST_SIZE + RESIST_GAP))
    frame:EnableMouse(true)
    frame.school = school

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(RESIST_SHEET)
    local cell = RESIST_CELL_OF[school] or 0
    icon:SetTexCoord(0, 1, cell * RESIST_CELL, (cell + 1) * RESIST_CELL)

    local ox, oy = frameOverhang(RESIST_SIZE)
    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetTexture(ICON_FRAME)
    border:SetPoint("TOPRIGHT", frame, ox, oy)
    border:SetPoint("BOTTOMLEFT", frame, -ox, -ox)

    -- Shadowed on the gem itself: the art has no well cut for a number now that its frame is gone.
    local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    value:SetShadowOffset(1, -1)
    value:SetShadowColor(0, 0, 0, 1)
    frame.Value = value

    frame:SetScript("OnEnter", showTooltip)
    frame:SetScript("OnLeave", hideTooltip)
    return frame
end

local function resistanceLevel(resistance)
    local level = math.max(UnitLevel("pet") or 1, 20)
    local ratio = resistance / level
    if ratio > 5 then return RESISTANCE_EXCELLENT end
    if ratio > 3.75 then return RESISTANCE_VERYGOOD end
    if ratio > 2.5 then return RESISTANCE_GOOD end
    if ratio > 1.25 then return RESISTANCE_FAIR end
    if ratio > 0 then return RESISTANCE_POOR end
    return RESISTANCE_NONE
end

-- Mirrors PaperDollFrame_SetResistances, the "( base +x -y )" breakdown included.
local function refreshResistances()
    for _, frame in ipairs(resistIcons) do
        local school = frame.school
        local base, resistance, positive, negative = UnitResistance("pet", school)
        local name = _G["RESISTANCE" .. school .. "_NAME"] or ""
        frame.Value:SetText(colored(resistance or 0, positive, negative))

        local tooltip = string.format(PAPERDOLLFRAME_TOOLTIP_FORMAT, name) .. " " .. (resistance or 0)
        if (positive or 0) ~= 0 or (negative or 0) ~= 0 then
            tooltip = tooltip .. " ( " .. HIGHLIGHT_FONT_COLOR_CODE .. base
            if positive > 0 then tooltip = tooltip .. GREEN_FONT_COLOR_CODE .. " +" .. positive end
            if negative < 0 then tooltip = tooltip .. " " .. RED_FONT_COLOR_CODE .. negative end
            tooltip = tooltip .. FONT_COLOR_CODE_CLOSE .. " )"
        end
        frame.tooltip = tooltip
        frame.tooltip2 = string.format(RESISTANCE_TOOLTIP_SUBTEXT,
            _G["RESISTANCE_TYPE" .. school] or "", math.max(UnitLevel("pet") or 1, 20),
            resistanceLevel(resistance or 0))
    end
end

local function refreshAttributes()
    for i = 1, NUM_PET_STATS do
        local row = attrRows[i]
        local name = _G["SPELL_STAT" .. i .. "_NAME"] or ""
        local stat, effective, positive, negative = UnitStat("pet", i)
        row.Text:SetText(string.format(STAT_FORMAT, name))
        row.Value:SetText(colored(effective, positive, negative))

        local tooltip = string.format(PAPERDOLLFRAME_TOOLTIP_FORMAT, name) .. " " .. effective
        if positive ~= 0 or negative ~= 0 then
            tooltip = tooltip .. " ( " .. HIGHLIGHT_FONT_COLOR_CODE .. (stat - positive - negative)
            if positive > 0 then tooltip = tooltip .. GREEN_FONT_COLOR_CODE .. " +" .. positive end
            if negative < 0 then tooltip = tooltip .. " " .. RED_FONT_COLOR_CODE .. negative end
            tooltip = tooltip .. FONT_COLOR_CODE_CLOSE .. " )"
        end
        row.tooltip = tooltip
        row.tooltip2 = _G["DEFAULT_STAT" .. i .. "_TOOLTIP"]
    end
end

local function refreshCombat()
    local minDamage, maxDamage = UnitDamage("pet")
    local power, powerPos, powerNeg = UnitAttackPower("pet")
    local _, effectiveArmor = UnitArmor("pet")
    local bonus = GetPetSpellBonusDamage and GetPetSpellBonusDamage() or 0

    combatRows[1].Text:SetText(string.format(STAT_FORMAT, ATTACK_POWER))
    combatRows[1].Value:SetText(colored((power or 0) + (powerPos or 0) + (powerNeg or 0),
                                        powerPos, powerNeg))
    combatRows[1].tooltip = MELEE_ATTACK_POWER

    combatRows[2].Text:SetText(string.format(STAT_FORMAT, DAMAGE))
    combatRows[2].Value:SetText(string.format("%d-%d",
        math.max(math.floor(minDamage or 0), 1), math.max(math.ceil(maxDamage or 0), 1)))
    combatRows[2].tooltip = DAMAGE

    combatRows[3].Text:SetText(string.format(STAT_FORMAT, SPELL_BONUS))
    combatRows[3].Value:SetText(colored(bonus, bonus > 0 and 1 or 0, bonus < 0 and -1 or 0))
    combatRows[3].tooltip = SPELL_BONUS
    combatRows[3].tooltip2 = DEFAULT_STATSPELLBONUS_TOOLTIP

    combatRows[4].Text:SetText(string.format(STAT_FORMAT, ARMOR))
    combatRows[4].Value:SetText(tostring(effectiveArmor or 0))
    combatRows[4].tooltip = ARMOR
end

local function refreshHappiness()
    local level, damagePercent
    if GetPetHappiness then level, damagePercent = GetPetHappiness() end
    if not (level and isHunterPet() and HAPPY_CELL_OF[level]) then
        happy:Hide()
        return
    end
    happy:Show()
    local cell = HAPPY_CELL_OF[level] or 0
    happy._icon:SetTexCoord(0, 1, cell * HAPPY_CELL, (cell + 1) * HAPPY_CELL)
    happy._title = _G["PET_HAPPINESS" .. level]
    happy._damage = damagePercent and string.format(PET_DAMAGE_PERCENTAGE, damagePercent) or nil
    -- Guarded on the first return: a pet with no diet hands BuildListString nothing at all.
    local diet = GetPetFoodTypes and GetPetFoodTypes()
    happy._diet = diet and string.format(PET_DIET_TEMPLATE, BuildListString(GetPetFoodTypes())) or nil
end

local function refreshDiet()
    local diet = GetPetFoodTypes and GetPetFoodTypes()
    if not diet then
        petDiet:Hide()
        return
    end
    petDiet:SetText(string.format(PET_DIET_TEMPLATE, BuildListString(GetPetFoodTypes())))
    petDiet:Show()
end

local function refreshXP()
    if not (isHunterPet() and GetPetExperience) then
        xpBar:Hide()
        return
    end
    local current, maximum = GetPetExperience()
    -- A pet at the player's own level reports 0/0, and an empty bar reading "XP 0 / 0" is noise.
    if not maximum or maximum <= 0 then
        xpBar:Hide()
        return
    end
    xpBar:Show()
    xpBar:SetMinMaxValues(0, math.max(maximum or 1, 1))
    xpBar:SetValue(current or 0)
    xpText:SetFormattedText("%s  %d / %d", XP, current or 0, maximum or 0)
end

local function setContentShown(shown)
    for _, row in ipairs(attrRows) do if shown then row:Show() else row:Hide() end end
    for _, row in ipairs(combatRows) do if shown then row:Show() else row:Hide() end end
    for _, icon in ipairs(resistIcons) do if shown then icon:Show() else icon:Hide() end end
    if shown then model:Show() else model:Hide() end
    if shown then statsBlock:Show() else statsBlock:Hide() end
end

local function refresh()
    if not (host and host:IsShown()) then return end

    if not hasPet() then
        setContentShown(false)
        happy:Hide()
        xpBar:Hide()
        petName:SetText("")
        petLevel:SetText("")
        petDiet:Hide()
        emptyText:Show()
        return
    end

    emptyText:Hide()
    setContentShown(true)

    -- Only on a real swap: UNIT_STATS fires constantly in combat and each SetUnit resets the camera.
    local guid = UnitGUID and UnitGUID("pet")
    if guid ~= model._duiGUID then
        model._duiGUID = guid
        model:SetUnit("pet")
    end

    petName:SetText(UnitName("pet") or "")
    local family = UnitCreatureFamily("pet")
    local tree = GetPetTalentTree and GetPetTalentTree()
    local line = family and string.format(UNIT_TYPE_LEVEL_TEMPLATE, UnitLevel("pet") or 0, family)
        or string.format("%s %d", LEVEL, UnitLevel("pet") or 0)
    if tree and tree ~= "" then line = line .. "  |cff808080-|r  " .. tree end
    petLevel:SetText(line)

    refreshAttributes()
    refreshCombat()
    refreshResistances()
    refreshHappiness()
    refreshDiet()
    refreshXP()
end

CP.RefreshPetPane = refresh

local function buildStatsBlock(parent)
    statsBlock = CreateFrame("Frame", nil, parent)
    statsBlock:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", PAD, XP_H + PAD + 6)
    statsBlock:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PAD, XP_H + PAD + 6)
    statsBlock:SetHeight(STATS_H)

    local bg = statsBlock:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(statsBlock)
    bg:SetTexture(0, 0, 0, 0.35)
    if CP.DrawPaneBorder then CP.DrawPaneBorder(statsBlock, statsBlock) end

    -- Split on the block's own CENTER, so the two columns stay even at any panel width.
    local left = CreateFrame("Frame", nil, statsBlock)
    left:SetPoint("TOPLEFT", statsBlock, "TOPLEFT", 12, -9)
    left:SetPoint("BOTTOMRIGHT", statsBlock, "BOTTOM", -8, 9)

    local right = CreateFrame("Frame", nil, statsBlock)
    right:SetPoint("TOPLEFT", statsBlock, "TOP", 8, -9)
    right:SetPoint("BOTTOMRIGHT", statsBlock, "BOTTOMRIGHT", -12, 9)

    local previous
    for i = 1, NUM_PET_STATS do
        attrRows[i] = buildStatRow(left, previous, i)
        previous = attrRows[i]
    end

    previous = nil
    for i = 1, 4 do
        combatRows[i] = buildStatRow(right, previous, i)
        previous = combatRows[i]
    end
end

local function buildContents(parent)
    buildStatsBlock(parent)

    model = CreateFrame("PlayerModel", "DragonUIPetModel", parent)
    model:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -HEADER_H)
    model:SetPoint("BOTTOMRIGHT", statsBlock, "TOPRIGHT", -RESIST_COL_W, 6)

    -- Hung from the bottom, not the top: that lines the last gem up with the happiness icon across
    -- the model, and frees the top-right corner for the diet line.
    local resistCol = CreateFrame("Frame", nil, parent)
    resistCol:SetWidth(RESIST_SIZE)
    resistCol:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", RESIST_COL_W -2, 4)
    resistCol:SetHeight(#RESISTANCES * RESIST_SIZE + (#RESISTANCES - 1) * RESIST_GAP)
    for i, school in ipairs(RESISTANCES) do
        resistIcons[i] = buildResistIcon(resistCol, school, i)
    end

    -- The pane's own corner, on the same padding as everything else: the title no longer spans the
    -- full width, so this corner is free and the strip reads as flush rather than floating.
    local strip = CP.WirePetModelControls and CP.WirePetModelControls(model)
    if strip then
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -PAD)
    end

    happy = CreateFrame("Frame", nil, parent)
    happy:SetSize(HAPPY_SIZE, HAPPY_SIZE)
    happy:SetPoint("BOTTOMLEFT", model, "BOTTOMLEFT", 4, 4)
    happy:SetFrameLevel(model:GetFrameLevel() + 2)
    happy:EnableMouse(true)
    -- No border texture here: unlike the resistance gems, this art carries its own frame.
    local face = happy:CreateTexture(nil, "ARTWORK")
    face:SetAllPoints(happy)
    face:SetTexture(HAPPY_SHEET)
    happy._icon = face
    happy:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self._title or "", 1, 1, 1)
        if self._damage then GameTooltip:AddLine(self._damage, 1, 1, 1) end
        if self._diet then GameTooltip:AddLine(self._diet, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    happy:SetScript("OnLeave", hideTooltip)
end

-- The frame stays pinned shut for good: its secure CompanionButtons are what made the whole panel
-- protected, and ToggleCharacter checks `hidden` first, so nothing can ever bring it back up.
function CP.RetirePetPaperDoll()
    local pet = _G.PetPaperDollFrame
    if pet then pet.hidden = true end

    local companions = _G.PetPaperDollFrameCompanionFrame
    if companions and not companions._duiRetired then
        companions._duiRetired = true
        -- A hidden holder, never UIParent: PetPaperDollFrame_UpdateTabs still Shows this off pet events.
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        companions:SetParent(holder)
        companions:ClearAllPoints()
        companions:SetPoint("TOPLEFT", holder, "TOPLEFT")
    end

    -- It clears `hidden` and re-anchors tab 3 onto tab 2 on every pet change, over-constraining a
    -- tab our own chain has already placed.
    if pet and _G.PetPaperDollFrame_UpdateIsAvailable and not pet._duiAvailabilityHooked then
        pet._duiAvailabilityHooked = true
        hooksecurefunc("PetPaperDollFrame_UpdateIsAvailable", function()
            if _G.PetPaperDollFrame then _G.PetPaperDollFrame.hidden = true end
            if CP.RefreshPetTab then CP.RefreshPetTab() end
        end)
    end
end

-- Tab 2 is Blizzard's own pet slot, so the pane goes back where every Wrath player looks for it.
-- CharacterFrameTab_OnClick routes it to PetPaperDollFrame, which is pinned, hence our own handler.
function CP.BuildPetTab()
    local tab = _G["CharacterFrameTab" .. TAB_INDEX]
    if not tab or tab._duiPetWired then return end
    tab._duiPetWired = true
    tab:SetText(PETS)
    tab:SetScript("OnClick", function()
        ToggleCharacter(FRAME_NAME)
        PlaySound("igCharacterInfoTab")
    end)
    CP.RefreshPetTab()
end

local tabShown

function CP.RefreshPetTab()
    local tab = _G["CharacterFrameTab" .. TAB_INDEX]
    if not (tab and tab._duiPetWired) then return end

    -- Only when it actually changes: re-laying the strip and re-measuring the panel on every stat
    -- event would churn the whole window through a fight. The widget is checked too, because
    -- PetPaperDollFrame_UpdateIsAvailable shows and hides this tab behind our back.
    local available = hasPet()
    if available == tabShown and tab:IsShown() == available then return end
    tabShown = available

    if available then tab:Show() else tab:Hide() end
    if CP.RechainTabs then CP.RechainTabs() end
    -- A sixth tab needs more room than the stock widths allow, so the panel is re-measured after.
    if CP.SetInsetForTab and CP.ActiveTabName then CP.SetInsetForTab(CP.ActiveTabName()) end

    -- IsVisible, not IsShown: a closed panel leaves the child's own flag set, and ToggleCharacter
    -- would then reopen the whole window in the player's face just because a pet was dismissed.
    if not available and pane and pane:IsVisible() then ToggleCharacter("PaperDollFrame") end
end

local function build()
    local cf = _G.CharacterFrame
    if pane or not cf or not cf.Inset then return end

    CP.RetirePetPaperDoll()

    pane = CreateFrame("Frame", FRAME_NAME, cf)
    pane:SetAllPoints(cf)
    pane:SetID(TAB_INDEX)
    pane:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL)
    pane:Hide()

    -- Kept out of CHARACTERFRAME_SUBFRAMES: writing to that table taints the loop ToggleCharacter runs.
    hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
        local mine = frameName == FRAME_NAME
        if mine then pane:Show() else pane:Hide() end
        local tab = _G["CharacterFrameTab" .. TAB_INDEX]
        if tab then
            if mine then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end)

    host = CreateFrame("Frame", nil, cf.Inset)
    host:SetAllPoints(cf.Inset)
    host:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 5)
    host:Hide()

    -- Spans exactly what the model spans, so the title centres over the pet rather than over the
    -- pane: the resistance column eats the right side and a pane-centred name reads visibly off.
    local header = CreateFrame("Frame", nil, host)
    header:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, -PAD)
    header:SetPoint("TOPRIGHT", host, "TOPRIGHT", -(PAD + RESIST_COL_W), -PAD)
    header:SetHeight(1)

    petName = host:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    petName:SetPoint("TOP", header, "TOP", 0, 0)

    petLevel = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    petLevel:SetPoint("TOP", petName, "BOTTOM", 0, -3)

    -- No addon string here: PET_DIET_TEMPLATE and the food names both come from the client already
    -- translated, which is why this line costs no locale work. There is no diet icon in any client.
    petDiet = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petDiet:SetPoint("TOPRIGHT", host, "TOPRIGHT", -PAD, -PAD)
    petDiet:SetJustifyH("RIGHT")

    xpBar = CreateFrame("StatusBar", nil, host)
    xpBar:SetHeight(XP_H)
    xpBar:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", PAD, PAD)
    xpBar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -PAD, PAD)
    xpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    xpBar:SetStatusBarColor(0.58, 0.0, 0.55)
    local xpBg = xpBar:CreateTexture(nil, "BACKGROUND")
    xpBg:SetAllPoints(xpBar)
    xpBg:SetTexture(0, 0, 0, 0.5)
    xpText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpText:SetPoint("CENTER", xpBar, "CENTER", 0, 0)

    emptyText = host:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    emptyText:SetPoint("CENTER", host, "CENTER", 0, 0)
    emptyText:SetText(addon.L["No pet active"])
    emptyText:Hide()

    buildContents(host)

    pane:SetScript("OnShow", function()
        if CP.ApplyChromeForTab then CP.ApplyChromeForTab(FRAME_NAME) end
        host:Show()
        refresh()
    end)
    pane:SetScript("OnHide", function() host:Hide() end)

    CP.BuildPetTab()
end

CP.PetPane = function() return pane end

local STAT_EVENTS = {
    "UNIT_PET", "PET_UI_UPDATE", "PET_BAR_UPDATE", "UNIT_STATS", "UNIT_RESISTANCES",
    "UNIT_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_ATTACK", "UNIT_LEVEL", "UNIT_PET_EXPERIENCE",
    "UNIT_HAPPINESS", "PET_SPELL_POWER_UPDATE", "UNIT_NAME_UPDATE",
}

-- These fire for every unit in the group, so without the filter a party member taking a hit would
-- wake this pane up. PetPaperDollFrame_OnEvent gates the same set on arg1 == "pet".
local PET_UNIT_ONLY = {
    UNIT_STATS = true, UNIT_RESISTANCES = true, UNIT_ATTACK_POWER = true, UNIT_DAMAGE = true,
    UNIT_ATTACK = true, UNIT_LEVEL = true, UNIT_NAME_UPDATE = true,
}

local events = CreateFrame("Frame")
for _, event in ipairs(STAT_EVENTS) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, unit)
    if PET_UNIT_ONLY[event] and unit ~= "pet" then return end
    -- UNIT_PET reports the OWNER, which is how gaining and losing a pet arrives here.
    if event == "UNIT_PET" and unit ~= "player" then return end
    -- The tab comes and goes with the pet, so the strip is re-laid and re-measured, not just repainted.
    if CP.RefreshPetTab then CP.RefreshPetTab() end
    refresh()
end)

CP:RegisterBuilder("petpane", build)
