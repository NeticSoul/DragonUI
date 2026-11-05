-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

local DressUpModule = { initialized = false, applied = false }

if addon.RegisterModule then
    addon:RegisterModule("dressupframe", DressUpModule,
        addon.L["Dressing Room"],
        addon.L["Retail-style frame for the dressing room"],
        { lifecyclePrefix = "DressUpFrame", loadOnce = true })
end

-- The inspect window's rect: Blizzard draws both windows on the same 384x512 sheets.
local LEFT, TOP, RIGHT, BOTTOM = 11, -12, -32, 76

-- Retail look: Blizzard's top-left backdrop quarter takes the whole art rect, under the stock model.
local ART_W, ART_H = 318, 331
local SPARE_QUARTERS = { "DressUpBackgroundTopRight", "DressUpBackgroundBotLeft", "DressUpBackgroundBotRight" }

-- DressUpModel's own size and BOTTOM anchor in fx:DressUpFrame.xml.
local MODEL_W, MODEL_H, MODEL_X, MODEL_Y = 316, 331, -11, 105

-- Retail's dressingroom-background-<class>: 478x500 at (1,1) of each file; 2 top rows keep its aspect.
local CLASS_ART = addon._dir .. "CharacterPanel\\DressingRoom\\dressingroom"
local CLASS_TC = { 1 / 512, 479 / 512, 3 / 512, 501 / 512 }

-- WotLK look: RACE_LIFT's measured 320 px height, widened to Blizzard's full 318 px of art.
local VIEW_X, VIEW_Y = 22, -86

-- Retail's ModelScene sits this far inside its Inset; the rim fills the gap.
local RIM_OUTSET = 3

-- Narrowed from 260 so a wrapped translation stays clear of the cog under the close button.
local DESCRIPTION_W = 240

-- Px the race art slides up on this 318x320 view, per race and sex, measured in game.
local WRATH_LIFT = {
    BLOODELFF = 8, BLOODELFM = 25, DRAENEIF = -7, DRAENEIM = 0, DWARFF = -32, DWARFM = -28,
    GNOMEF = -31, GNOMEM = -24, HUMANF = -8, HUMANM = -7, NIGHTELFF = 17, NIGHTELFM = 18,
    ORCF = -10, ORCM = -10, SCOURGEF = -4, SCOURGEM = -1, TAURENF = 9, TAURENM = 11,
    TROLLF = -10, TROLLM = -10,
}

local chrome, stage, well, raceArt, raceShade

local function config()
    return addon:GetModuleConfig("dressupframe") or {}
end

-- Before the database the config is {}: a missing key must read as the default, race art.
local function wotlkLook()
    return config().backdrop ~= "retail"
end

local function hideStockArt(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" and not region:GetName()
            and region:GetDrawLayer() == "ARTWORK" then
            region:Hide()
        end
    end
    for _, name in ipairs(SPARE_QUARTERS) do
        if _G[name] then _G[name]:Hide() end
    end
end

local function fitArt()
    local art = _G.DressUpBackgroundTopLeft
    if not art then return end
    art:SetSize(ART_W, ART_H)
    art:SetTexCoord(unpack(CLASS_TC))
end

-- Under the model, not in it: a translucent model fades its whole frame, textures and children too.
local function buildStage(frame)
    local model = _G.DressUpModel
    if not model then return end
    stage = CreateFrame("Frame", nil, frame)
    stage:SetSize(CP.FULL_ART_W, CP.MODEL_H)
    stage:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_X, VIEW_Y)
    stage:SetFrameLevel(model:GetFrameLevel())
    model:SetFrameLevel(model:GetFrameLevel() + 1)
    raceArt, raceShade = CP.CreateRaceBackdrop(stage, true)
end

-- On a child frame: in the window's own BORDER layer the rim would tie with the title streaks.
local function buildRim(frame)
    well = CreateFrame("Frame", nil, frame)
    CP.DrawPaneBorder(well, well, RIM_OUTSET)
end

-- FontStrings have no frame level: left on the window, the metal's OVERLAY covers the title.
local function liftTitle(frame)
    local title = _G.DressUpFrameTitleText
    if not title then return end
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(chrome)
    title:SetParent(holder)
end

local function placeModel(race)
    local model, art = _G.DressUpModel, _G.DressUpBackgroundTopLeft
    if not (model and art and stage and well) then return end
    model:ClearAllPoints()
    well:ClearAllPoints()
    if race then
        model:SetAllPoints(stage)
        well:SetAllPoints(stage)
    else
        model:SetSize(MODEL_W, MODEL_H)
        model:SetPoint("BOTTOM", model:GetParent(), "BOTTOM", MODEL_X, MODEL_Y)
        well:SetAllPoints(art)
    end
end

-- Always in colour, as retail and Forever draw the dressing room: only the paperdoll and inspect go grey.
local function paintRace(fileName, sex)
    if not raceArt then return end
    CP.PaintRaceBackdrop(raceArt, raceShade, fileName, sex, true)
    local key = CP.RaceLiftKey(fileName, sex)
    CP.SlideRaceBackdrop(raceArt, WRATH_LIFT[key] or CP.RaceBackdropLift(key))
end

local function paintArt()
    local race = wotlkLook()
    placeModel(race)
    local art = _G.DressUpBackgroundTopLeft
    if race then
        if art then art:Hide() end
        local _, fileName = UnitRace("player")
        paintRace(fileName, UnitSex("player"))
        return
    end
    if raceArt then CP.HideRaceBackdrop(raceArt, raceShade) end
    local _, classFile = UnitClass("player")
    if art and classFile then
        art:SetTexture(CLASS_ART .. strlower(classFile))
        art:Show()
    end
end

local function styleRotateButtons()
    local left, right = _G.DressUpModelRotateLeftButton, _G.DressUpModelRotateRightButton
    if left and well then
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", well, "TOPLEFT", 0, 0)
    end
    if not CP.StyleModelButton then return end
    -- Same glyph pairing as the character panel: retail names the arrows the other way round.
    if left then CP.StyleModelButton(left, "common-icon-rotateright") end
    if right then CP.StyleModelButton(right, "common-icon-rotateleft") end
end

local function backdropChoice(text, value)
    return {
        text = text,
        keepShown = true,
        checked = function() return (wotlkLook() and "wotlk" or "retail") == value end,
        func = function()
            config().backdrop = value
            paintArt()
        end,
    }
end

local function openMenu(self)
    local L = addon.L
    addon.Menu.Open(self, {
        { text = L["Model backdrop"], isTitle = true },
        backdropChoice(L["Retail (by class)"], "retail"),
        backdropChoice(L["Wrath (by race)"], "wotlk"),
    })
end

local function buildCog(frame)
    if not (CP.CreateSettingsCog and addon.Menu) then return end
    CP.CreateSettingsCog("DragonUIDressUpSettingsCog", frame, _G.DressUpFrameCloseButton, openMenu)
    local description = _G.DressUpFrameDescriptionText
    if description then description:SetWidth(DESCRIPTION_W) end
end

local function refresh()
    CP.TintWindowChrome(chrome)
    paintArt()
end

local function build()
    local frame = _G.DressUpFrame
    if not frame or frame._duiSkinned then return end
    frame._duiSkinned = true

    hideStockArt(frame)
    chrome = CP.BuildWindowChrome(frame, LEFT, TOP, RIGHT, BOTTOM)

    local portrait = _G.DressUpFramePortrait
    -- Blizzard's BACKGROUND would tie with the rock; same-layer order is random on 3.3.5a.
    if portrait then portrait:SetDrawLayer("ARTWORK") end
    CP.FitWindowPortrait(portrait, chrome)
    CP.ModernizeCloseButton(_G.DressUpFrameCloseButton, chrome)
    liftTitle(frame)

    fitArt()
    buildStage(frame)
    buildRim(frame)
    styleRotateButtons()
    addon:WireModelDragRotate(_G.DressUpModel, well)
    if addon.SkinRedButton then
        addon.SkinRedButton(_G.DressUpFrameResetButton)
        addon.SkinRedButton(_G.DressUpFrameCancelButton)
    end
    buildCog(frame)

    frame:HookScript("OnShow", refresh)
    refresh()
end

local function safeBuild()
    local ok, err = pcall(build)
    if not ok then
        addon:Error("Dressing room reskin failed: " .. tostring(err))
    end
end

local function ApplyDressUpFrameSystem()
    if not addon:IsModuleEnabled("dressupframe") then return end
    DressUpModule.initialized = true
    DressUpModule.applied = true
    safeBuild()
end

local function RestoreDressUpFrameSystem()
    DressUpModule.applied = false
end

addon.ApplyDressUpFrameSystem = ApplyDressUpFrameSystem
addon.RestoreDressUpFrameSystem = RestoreDressUpFrameSystem

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", ApplyDressUpFrameSystem)
