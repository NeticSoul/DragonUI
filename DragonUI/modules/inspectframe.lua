-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

local InspectModule = { initialized = false, applied = false }

if addon.RegisterModule then
    addon:RegisterModule("inspectframe", InspectModule,
        addon.L["Inspect Window"],
        addon.L["Retail-style frame and tabs for the inspect window"],
        { lifecyclePrefix = "InspectFrame", loadOnce = true })
end

-- Where Blizzard's 384x512 art shows: from here the retail ring circles Blizzard's own portrait.
local LEFT, TOP, RIGHT, BOTTOM = 11, -12, -32, 76

-- Blizzard's frame art in each subframe: unnamed textures in one layer, which no Blizzard code reaches.
local STOCK_ART = {
    InspectPaperDollFrame = "BACKGROUND",
    InspectPVPFrame = "BACKGROUND",
    InspectTalentFrame = "BORDER",
}

local SLOT_GROUPS = {
    { slice = "left", point = "TOPLEFT", x = -4, y = 0,
      slots = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" } },
    { slice = "right", point = "TOPRIGHT", x = 4, y = 0,
      slots = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" } },
    { slice = "bottom", point = "TOPLEFT", x = -4, y = 8, slots = { "MainHand", "SecondaryHand", "Ranged" } },
}
local WEAPON_CAPS = {
    { "InspectMainHandSlot", "gapLeft", "TOPRIGHT", "TOPLEFT" },
    { "InspectRangedSlot", "gapRight", "TOPLEFT", "TOPRIGHT" },
}

-- Same lift as the character panel's: the weapon row now covers the model's foot.
local ITEM_LEVEL_LIFT = 24

-- InspectModelFrame's anchor in Blizzard's XML.
local MODEL_X, MODEL_Y = 65, -78

local NUM_TABS = 3

local chrome, stage, raceArt, raceShade

local function hideStockArt()
    for frameName, layer in pairs(STOCK_ART) do
        local frame = _G[frameName]
        if frame then
            for _, region in ipairs({ frame:GetRegions() }) do
                if region:GetObjectType() == "Texture" and not region:GetName()
                    and region:GetDrawLayer() == layer then
                    region:Hide()
                end
            end
        end
    end
end

local function tintBody()
    CP.TintWindowChrome(chrome)
end

local function dressSlots()
    for _, group in ipairs(SLOT_GROUPS) do
        local slice = CP.SLOT_SLICE[group.slice]
        for _, suffix in ipairs(group.slots) do
            local slot = _G["Inspect" .. suffix .. "Slot"]
            if slot and not slot._duiSlotFrame then
                local piece = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
                piece:SetSize(slice[1], slice[2])
                piece:SetTexture(CP.SLOT_PARTS)
                piece:SetTexCoord(unpack(slice, 3))
                piece:SetPoint(group.point, slot, group.point, group.x, group.y)
                slot._duiSlotFrame = piece
            end
        end
    end
    for _, cap in ipairs(WEAPON_CAPS) do
        local slot = _G[cap[1]]
        local metal = slot and slot._duiSlotFrame
        if metal then
            local slice = CP.SLOT_SLICE[cap[2]]
            local piece = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
            piece:SetSize(slice[1], slice[2])
            piece:SetTexture(CP.SLOT_PARTS)
            piece:SetTexCoord(unpack(slice, 3))
            piece:SetPoint(cap[3], metal, cap[4], 0, 0)
        end
    end
end

-- Flush with the columns' metal on both sides, as the character panel's Inset is.
local function buildGround()
    local paperDoll = _G.InspectPaperDollFrame
    if not paperDoll then return end
    local ground = paperDoll:CreateTexture(nil, "BACKGROUND", nil, -8)
    ground:SetAtlasTexture("character-panel-background")
    ground:SetPoint("TOPLEFT", chrome, "TOPLEFT", 6, -60)
    ground:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -6, 4)
    CP.DrawPaneBorder(paperDoll, ground)
    if stage then CP.DrawModelTrim(paperDoll, stage, ground, {}) end
end

-- The race art only matches each race's camera at retail's 231x320; Blizzard's TOPLEFT is retail's.
local function fitViewport()
    local model, paperDoll = _G.InspectModelFrame, _G.InspectPaperDollFrame
    if not (model and paperDoll) then return end
    -- The model's own rect, which everything else holds to so a form's model can move alone.
    stage = CreateFrame("Frame", nil, paperDoll)
    stage:SetSize(CP.MODEL_W, CP.MODEL_H)
    stage:SetPoint("TOPLEFT", paperDoll, "TOPLEFT", MODEL_X, MODEL_Y)
    -- Under the model, not in it: a translucent model (Ghost Wolf) fades its whole frame.
    stage:SetFrameLevel(model:GetFrameLevel())
    model:SetFrameLevel(model:GetFrameLevel() + 1)
    model:SetSize(CP.MODEL_W, CP.MODEL_H)
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
    model._duiItemLevelY = ITEM_LEVEL_LIFT
    model._duiItemLevelAnchor = stage
    -- Siblings at one level, so the weapon row over the model's foot needs the higher level.
    local level = model:GetFrameLevel() + 2
    for _, group in ipairs(SLOT_GROUPS) do
        for _, suffix in ipairs(group.slots) do
            local slot = _G["Inspect" .. suffix .. "Slot"]
            if slot then slot:SetFrameLevel(level) end
        end
    end
end

local function buildBackdrop()
    local model = _G.InspectModelFrame
    if not (model and stage) then return end
    raceArt, raceShade = CP.CreateRaceBackdrop(stage)
end

-- Form auras (spellId is UnitAura's 11th return) and the form whose model each one shows.
local FORM_BY_SPELL = {
    [768] = "CAT", [57655] = "CAT", [5487] = "BEAR", [9634] = "BEAR", [24858] = "MOONKIN",
    [33891] = "TREE", [783] = "TRAVEL", [1066] = "AQUATIC", [33943] = "FLIGHT", [40120] = "SWIFTFLIGHT",
    [47241] = "DEMON", [2645] = "WOLF",
}

-- Px each form's model moves on top of its race art's lift; colour variants share one model.
local FORM_SHIFT = {
    ["CAT@NIGHTELF"] = -107, ["CAT@TAUREN"] = -55,
    ["BEAR@NIGHTELF"] = -70, ["BEAR@TAUREN"] = -60,
    ["MOONKIN@NIGHTELF"] = -65, ["MOONKIN@TAUREN"] = -45,
    ["TREE@NIGHTELF"] = -50, ["TREE@TAUREN"] = 0,
    ["TRAVEL@NIGHTELF"] = -65, ["TRAVEL@TAUREN"] = -48,
    ["AQUATIC@NIGHTELF"] = -34, ["AQUATIC@TAUREN"] = -25,
    ["FLIGHT@NIGHTELF"] = -70, ["FLIGHT@TAUREN"] = -40,
    ["SWIFTFLIGHT@NIGHTELF"] = -65, ["SWIFTFLIGHT@TAUREN"] = -30,
    ["DEMON@HUMAN"] = -30, ["DEMON@GNOME"] = 0, ["DEMON@ORC"] = -17, ["DEMON@SCOURGE"] = -31,
    ["DEMON@BLOODELF"] = -45,
    ["WOLF@TAUREN"] = -62, ["WOLF@ORC"] = -45, ["WOLF@TROLL"] = -50, ["WOLF@DRAENEI"] = -55,
}

-- Classless races get the server's fallback model: Night Elf's, or Tauren's for a Horde Moonkin.
local FALLBACK_RACE = { DEMON = "HUMAN", WOLF = "ORC" }

local function shiftFor(form, race, horde)
    local value = FORM_SHIFT[form .. "@" .. race]
    if value then return value end
    if form == "MOONKIN" and horde then return FORM_SHIFT["MOONKIN@TAUREN"] end
    return FORM_SHIFT[form .. "@" .. (FALLBACK_RACE[form] or "NIGHTELF")]
end

local function formShift(form, race, sex, horde)
    local base = form and race and shiftFor(form, strupper(race), horde)
    if not base then return 0 end
    return base + CP.RaceBackdropLift(CP.RaceLiftKey(race, sex))
end

local function unitForm(unit)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then return nil end
        if FORM_BY_SPELL[spellId] then return FORM_BY_SPELL[spellId] end
    end
end

-- Moving the frame, never SetPosition: model loads re-fit the view but leave anchors alone.
local shift = 0
local function setShift(px)
    local model = _G.InspectModelFrame
    if not (model and stage) or px == shift then return end
    shift = px
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, px)
end

local function placeModel()
    local unit = _G.InspectFrame and _G.InspectFrame.unit
    if not unit then return setShift(0) end
    local _, race = UnitRace(unit)
    setShift(formShift(unitForm(unit), race, UnitSex(unit), UnitFactionGroup(unit) == "Horde"))
end

local function refreshModel()
    local unit = _G.InspectFrame and _G.InspectFrame.unit
    if raceArt and unit then
        local _, fileName = UnitRace(unit)
        CP.PaintRaceBackdrop(raceArt, raceShade, fileName, UnitSex(unit))
    end
    placeModel()
end

local function styleRotateButtons()
    local left, right = _G.InspectModelRotateLeftButton, _G.InspectModelRotateRightButton
    if left and stage then
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
    end
    if not CP.StyleModelButton then return end
    -- Same glyph pairing as the character panel: retail names the arrows the other way round.
    if left then CP.StyleModelButton(left, "common-icon-rotateright") end
    if right then CP.StyleModelButton(right, "common-icon-rotateleft") end
end

local function chainTabs()
    local prev
    for i = 1, NUM_TABS do
        local tab = _G["InspectFrameTab" .. i]
        if tab then
            CP.ReskinTab(tab)
            -- The shared reskin restores the label font; Blizzard greys a disabled tab (talents under 10).
            if tab.isDisabled then
                tab:SetDisabledFontObject(GameFontDisableSmall)
                local text = _G[tab:GetName() .. "Text"]
                if text then text:SetFontObject(GameFontDisableSmall) end
            end
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", CP.TAB_GAP, 0)
            else
                tab:SetPoint("TOPLEFT", chrome, "BOTTOMLEFT", CP.TAB_START_X, 2)
            end
            prev = tab
        end
    end
end

local function dressTabs()
    for i = 1, NUM_TABS do
        local tab = _G["InspectFrameTab" .. i]
        if tab then tab._duiRelayout = chainTabs end
    end
    chainTabs()
    -- Disabling swaps the tab art without a resize, so nothing else re-places that tab's label.
    hooksecurefunc("PanelTemplates_DisableTab", function(owner)
        if owner == _G.InspectFrame then chainTabs() end
    end)
end

local function build()
    local frame = _G.InspectFrame
    if not frame or frame._duiSkinned then return end
    frame._duiSkinned = true

    hideStockArt()
    chrome = CP.BuildWindowChrome(frame, LEFT, TOP, RIGHT, BOTTOM)
    CP.FitWindowPortrait(_G.InspectFramePortrait, chrome)
    tintBody()

    CP.ModernizeCloseButton(_G.InspectFrameCloseButton, chrome)
    -- The talent tab draws its own close button over the window's, in the same spot.
    CP.ModernizeCloseButton(_G.InspectTalentFrameCloseButton, chrome)

    fitViewport()
    dressSlots()
    buildGround()
    buildBackdrop()
    styleRotateButtons()
    addon:WireModelDragRotate(_G.InspectModelFrame)
    dressTabs()

    frame:HookScript("OnShow", tintBody)
    local paperDoll = _G.InspectPaperDollFrame
    if paperDoll then
        local auras = CreateFrame("Frame")
        auras:SetScript("OnEvent", function(_, _, unit)
            if unit == frame.unit then placeModel() end
        end)
        paperDoll:HookScript("OnShow", function()
            auras:RegisterEvent("UNIT_AURA")
            refreshModel()
        end)
        paperDoll:HookScript("OnHide", function() auras:UnregisterEvent("UNIT_AURA") end)
        -- A shapeshift reloads the model, and servers set the unit's sex to the form model's: repaint.
        paperDoll:HookScript("OnEvent", function(_, event, unit)
            if event == "UNIT_MODEL_CHANGED" and unit == frame.unit then refreshModel() end
        end)
        if paperDoll:IsVisible() then auras:RegisterEvent("UNIT_AURA") end
    end
    -- Called directly on a target switch, so the paperdoll's OnShow never fires for it.
    hooksecurefunc("InspectFrame_UnitChanged", refreshModel)
    if frame:IsShown() then refreshModel() end
end

local function safeBuild()
    local ok, err = pcall(build)
    if not ok then
        addon:Error("Inspect window reskin failed: " .. tostring(err))
    end
end

local function ApplyInspectFrameSystem()
    if not addon:IsModuleEnabled("inspectframe") then return end
    InspectModule.initialized = true
    InspectModule.applied = true
    safeBuild()
end

local function RestoreInspectFrameSystem()
    InspectModule.applied = false
end

addon.ApplyInspectFrameSystem = ApplyInspectFrameSystem
addon.RestoreInspectFrameSystem = RestoreInspectFrameSystem

-- Blizzard_InspectUI loads on demand, the first time anyone is inspected.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_InspectUI" then return end
    ApplyInspectFrameSystem()
end)
