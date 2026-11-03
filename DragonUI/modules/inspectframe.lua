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

local ROCK = addon._dir .. "UI\\ui-background-rock"

-- Where Blizzard's 384x512 art shows: from here the retail ring circles Blizzard's own portrait.
local LEFT, TOP, RIGHT, BOTTOM = 11, -12, -32, 76

local NINESLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

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

local NUM_TABS = 3

local chrome

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

local function buildChrome(frame)
    chrome = CreateFrame("Frame", nil, frame)
    chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, TOP)
    chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", RIGHT, BOTTOM)

    local rock = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", chrome, "TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -2, 2)
    chrome.rock = rock

    local streaks = frame:CreateTexture(nil, "BORDER")
    streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetHeight(43)
    streaks:SetPoint("TOPLEFT", chrome, "TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -2, -21)
    chrome.streaks = streaks

    -- On the window, under every subframe like Blizzard's art; on `chrome` it would share their level.
    local layout = DragonUI_NineSlice and DragonUI_NineSlice.GetLayout("PortraitFrameTemplate")
    if layout then
        for _, key in ipairs(NINESLICE_PIECES) do
            chrome[key] = frame:CreateTexture(nil, layout[key].layer or "OVERLAY")
        end
        DragonUI_NineSlice.ApplyLayout(chrome, layout)
    end

    frame:SetHitRectInsets(LEFT, -RIGHT, -TOP, BOTTOM)
end

-- The character panel's face portrait: same centre as Blizzard's 60x60, shrunk to clear the ring.
local function fitPortrait()
    local portrait = _G.InspectFramePortrait
    if not portrait then return end
    portrait:SetSize(56, 56)
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT", chrome, "TOPLEFT", -2, 4)
end

local function tintBody()
    local tint = CP.BodyTint()
    chrome.rock:SetVertexColor(tint.body, tint.body, tint.body)
    chrome.streaks:SetAlpha(tint.streak)
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
    local model = _G.InspectModelFrame
    if not paperDoll then return end
    local ground = paperDoll:CreateTexture(nil, "BACKGROUND", nil, -8)
    ground:SetAtlasTexture("character-panel-background")
    ground:SetPoint("TOPLEFT", chrome, "TOPLEFT", 6, -60)
    ground:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -6, 4)
    CP.DrawPaneBorder(paperDoll, ground)
    if model then CP.DrawModelTrim(paperDoll, model, ground, {}) end
end

-- The race art only matches each race's camera at retail's 231x320; Blizzard's TOPLEFT is retail's.
local function fitViewport()
    local model = _G.InspectModelFrame
    if not model then return end
    model:SetSize(CP.MODEL_W, CP.MODEL_H)
    model._duiItemLevelY = ITEM_LEVEL_LIFT
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
    if not model then return end
    model._duiRaceBg, model._duiRaceBgShade = CP.CreateRaceBackdrop(model)
end

local function paintBackdrop()
    if CP.InspectPreview then return CP.InspectPreview() end
    local model = _G.InspectModelFrame
    local unit = _G.InspectFrame and _G.InspectFrame.unit
    if not (model and model._duiRaceBg and unit) then return end
    local _, fileName = UnitRace(unit)
    CP.PaintRaceBackdrop(model._duiRaceBg, model._duiRaceBgShade, fileName, UnitSex(unit))
end
CP.RepaintInspectBackdrop = paintBackdrop

local function styleRotateButtons()
    if not CP.StyleModelButton then return end
    -- Same glyph pairing as the character panel: retail names the arrows the other way round.
    if _G.InspectModelRotateLeftButton then
        CP.StyleModelButton(_G.InspectModelRotateLeftButton, "common-icon-rotateright")
    end
    if _G.InspectModelRotateRightButton then
        CP.StyleModelButton(_G.InspectModelRotateRightButton, "common-icon-rotateleft")
    end
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
    buildChrome(frame)
    fitPortrait()
    tintBody()

    CP.ModernizeCloseButton(_G.InspectFrameCloseButton, chrome)
    -- The talent tab draws its own close button over the window's, in the same spot.
    CP.ModernizeCloseButton(_G.InspectTalentFrameCloseButton, chrome)

    fitViewport()
    dressSlots()
    buildGround()
    buildBackdrop()
    styleRotateButtons()
    dressTabs()

    frame:HookScript("OnShow", tintBody)
    if _G.InspectPaperDollFrame then
        _G.InspectPaperDollFrame:HookScript("OnShow", paintBackdrop)
    end
    -- Called directly on a target switch, so the paperdoll's OnShow never fires for it.
    hooksecurefunc("InspectFrame_UnitChanged", paintBackdrop)
    if frame:IsShown() then paintBackdrop() end
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
