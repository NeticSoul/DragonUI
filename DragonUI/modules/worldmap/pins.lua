-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L
local WM = addon.WorldMap
local QP = addon.QuestPOI

-- What sits on the canvas: landmark pins, quest POIs, the zone label and the filter button.

-- The retail sheet is twice as tall, so Blizzard's crop lands right once its rows are halved.
local POI_SHEET = addon._dir .. "WorldMap\\poiicons"
local POI_SHEET_ROWS = 0.5
local PIN_SCALE = 1
local LABEL_FONT_SIZE, DESCRIPTION_FONT_SIZE = 24, 16
-- The ring's circle is off-centre in Blizzard's border sheet, hence the icon nudge.
local FILTER_ICON = 26
local FILTER_ICON_X, FILTER_ICON_Y = 2, -2
-- The numbered glyph needs a larger scale to match the completed quest icon.
local QUEST_POI_SCALE, QUEST_POI_NUMERIC_SCALE = 0.7, 1.05
local ROCK = addon._dir .. "UI\\ui-background-rock"
local GLOW = "Interface\\WorldMap\\UI-QuestPoi-IconGlow"
local RING_SHEET = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons"
-- QuestPOITemplate's turn-in glyph is 24px inside its 32px ring.
local TURNIN_SHARE = 24 / 32
local FLASH_SECONDS, FLASH_PULSES, FLASH_GROW = 2.5, 3, 0.35
local FLASH_PATIENCE = 5

local objectivesPlate
local pendingQuestFlash, pendingQuestFlashUntil

-- ============================================================================
-- LANDMARKS AND QUEST POIS
-- ============================================================================

function WM.SetPOIIcon(texture, index)
    local x1, x2, y1, y2 = WorldMap_GetPOITextureCoords(index)
    texture:SetTexture(POI_SHEET)
    texture:SetTexCoord(x1, x2, y1 * POI_SHEET_ROWS, y2 * POI_SHEET_ROWS)
end

-- Blizzard anchors pins in the map's own units and scales them with it; retail keeps pins one size.
local function restyleLandmarks()
    local scale = WM.canvasScale
    if not scale then return end
    local shown = WM:Config().landmarks ~= false
    local pinScale = PIN_SCALE / scale
    local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
    for index = 1, GetNumMapLandmarks() do
        local pin = _G["WorldMapFramePOI" .. index]
        if pin then
            if shown then
                local _, _, textureIndex, x, y = GetMapLandmarkInfo(index)
                WM.SetPOIIcon(_G[pin:GetName() .. "Texture"], textureIndex)
                pin:SetScale(pinScale)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x * width / pinScale, -y * height / pinScale)
                -- Only WorldMapFrame_Update shows these, so re-enabling the filter waits for a map change.
                pin:Show()
            else
                pin:Hide()
            end
        end
    end
end

-- Offsets are read in the button's own space, so the badge scale has to come back out of them.
local function placeQuestPOI(button)
    if button.duiRawX and WM.poiScale then
        local scale = button.type == QUEST_POI_NUMERIC and QUEST_POI_NUMERIC_SCALE or QUEST_POI_SCALE
        button:SetScale(scale)
        -- The template insets 8 of 32 a side, leaving the ring we draw mostly unclickable.
        button:SetHitRectInsets(0, 0, 0, 0)
        local factor = WM.poiScale / scale
        button:SetPoint("CENTER", WorldMapPOIFrame, "TOPLEFT", button.duiRawX * factor, button.duiRawY * factor)
    end
end

-- Blizzard only re-anchors a POI it has a position for; the offset it just wrote is the raw one.
local function onQuestPOIDisplayed(questFrame)
    local button = questFrame.poiIcon
    if not button then return end
    local _, posX = QuestPOIGetIconInfo(questFrame.questId)
    if posX then
        local _, _, _, x, y = button:GetPoint(1)
        button.duiRawX, button.duiRawY = x, y
        placeQuestPOI(button)
    end
end

-- Resized, not rescaled: it hangs off an offset in its own scale, so scaling slides it away.
local function sizeQuestPOI(button, size)
    local rings = { button.normalTexture or button.ring, button.pushedTexture or button.ringPushed,
        button.highlightTexture or button.ringHighlight }
    for _, texture in ipairs(rings) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        texture:SetSize(size, size)
    end
    if button.number then
        button.number:ClearAllPoints()
        button.number:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.number:SetSize(size, size)
    end
    if button.duiRing then button.duiRing:SetSize(size / TURNIN_SHARE, size / TURNIN_SHARE) end
    -- A held map's QP pin: its number fills the badge, its turn-in glyph sits at 24 of 32.
    if button.icon then
        local glyph = button.duiStyle == "numeric" and size or size * TURNIN_SHARE
        button.icon:SetSize(glyph, glyph)
    end
end

-- Blizzard rings a completed pin only via the twin its own pick swaps in; ours rings the shared focus.
local function ringCompletedPOI(button, selected)
    local ring = button.duiRing
    if not ring then
        if not selected then return end
        ring = button:CreateTexture(nil, "BORDER")
        ring:SetTexture(RING_SHEET)
        local box = QP.SELECTED_RING
        ring:SetTexCoord(box[1], box[2], box[3], box[4])
        ring:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.duiRing = ring
        sizeQuestPOI(button, button:GetWidth())
        local glow = button.selectionGlow:GetWidth() / TURNIN_SHARE
        button.selectionGlow:SetSize(glow, glow)
    end
    if selected then
        ring:Show()
        button.selectionGlow:Show()
    else
        ring:Hide()
        button.selectionGlow:Hide()
    end
end

-- These are Blizzard's pooled buttons: one handed to another quest must drop the pulse it was
-- running, or the next quest to land on it inherits the animation. Hidden ones freeze mid-pulse.
local flashing = {}

local function poiQuest(button)
    return button.questId or (button.quest and button.quest.questId) or (button.row and button.row.questId)
end

local function stopQuestFlash(button)
    flashing[button] = nil
    if not button.duiFlashTime then return end
    button:SetScript("OnUpdate", nil)
    sizeQuestPOI(button, button:GetWidth())
    button.duiFlashTime = nil
    button.duiFlashGlow:Hide()
end

local function dropStaleFlashes()
    for button, questID in pairs(flashing) do
        if not button:IsShown() or poiQuest(button) ~= questID then stopQuestFlash(button) end
    end
end

local function flashQuestPOI(button)
    flashing[button] = poiQuest(button)
    local glow = button.duiFlashGlow
    if not glow then
        glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(GLOW)
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.duiFlashGlow = glow
    end
    button.duiFlashTime = 0
    glow:Show()
    button:SetScript("OnUpdate", function(self, elapsed)
        local time = self.duiFlashTime + elapsed
        self.duiFlashTime = time
        if time >= FLASH_SECONDS then
            stopQuestFlash(self)
            return
        end
        local beat = math.sin(time / FLASH_SECONDS * FLASH_PULSES * math.pi * 2) * 0.5 + 0.5
        local fade = 1 - time / FLASH_SECONDS
        local grow = 1 + FLASH_GROW * beat * fade
        sizeQuestPOI(self, self:GetWidth() * grow)
        self.duiFlashGlow:SetSize(self:GetWidth() * 2 * grow, self:GetHeight() * 2 * grow)
        self.duiFlashGlow:SetAlpha(beat * fade)
    end)
end

local function cropQuestPOI(button, selected)
    if button.type == QUEST_POI_COMPLETE_SWAP then return ringCompletedPOI(button, selected) end
    QP.CropBlizzardPOI(button, selected)
end

-- ============================================================================
-- QUEST PIN GUARD
-- ============================================================================

-- Completed pins are named by row: one sorted under an open quest leaves a hole HideButtons indexes.
local SWAP_PIN = "poiWorldMapPOIFrame" .. QUEST_POI_COMPLETE_SWAP .. "_"
local updateMapQuests = QuestMapUpdateAllQuests
-- QuestPOICompletedTemplate's glyph fills its 32px, where QP draws the turn-in at 24.
local HELD_COMPLETE_SCALE = QUEST_POI_SCALE / TURNIN_SHARE
local NO_ROWS = {}
local pinsHeld = false
-- Rows numbered as Blizzard would have; on a held map our pins and the panel's badges read them.
local heldRows, heldPool = {}, {}

-- WorldMapFrame_UpdateQuests' own rows and completion rule, replayed before it runs.
local function wouldLeaveHole()
    local money, count, open, lastNew = GetMoney(), 0, 0, 0
    for i = 1, updateMapQuests() do
        local questID, logIndex = QuestPOIGetQuestIDByVisibleIndex(i)
        if logIndex and logIndex > 0 then
            count = count + 1
            local _, _, _, _, _, _, done = GetQuestLogTitle(logIndex)
            if done and done < 0 then
                done = false
            elseif GetNumQuestLeaderBoards(logIndex) == 0 and money >= GetQuestLogRequiredMoney(logIndex) then
                done = true
            end
            local row = heldRows[count] or {}
            heldRows[count] = row
            row.questId, row.questLogIndex, row.completed = questID, logIndex, done and true or false
            row.number = nil
            if done then
                if not _G[SWAP_PIN .. count] then lastNew = count end
            else
                open = open + 1
                row.number = open
            end
        end
    end
    for index = #heldRows, count + 1, -1 do heldRows[index] = nil end
    for index = 1, lastNew - 1 do
        if not (heldRows[index].completed or _G[SWAP_PIN .. index]) then return true end
    end
    return false
end

-- Only right after the list is built: QuestPOIGetIconInfo answers for whichever map was last.
local function readHeldPositions()
    QuestPOIUpdateIcons()
    for _, row in ipairs(heldRows) do
        local _, x, y = QuestPOIGetIconInfo(row.questId)
        row.x, row.y = x, y
    end
end

-- Blizzard's lines, not its handler: WorldMapQuestPOI_OnEnter writes WorldMapPOIFrame.allowBlobTooltip.
local function showHeldTooltip(pin)
    local logIndex = pin.row.questLogIndex
    WorldMapTooltip:SetOwner(WorldMapFrame, "ANCHOR_CURSOR_RIGHT", 5, 2)
    WorldMapTooltip:SetText((GetQuestLogTitle(logIndex)))
    if pin.row.completed then
        local text = GetQuestLogCompletionText(logIndex)
        if text then WorldMapTooltip:AddLine("- " .. text, 1, 1, 1, 1) end
    else
        for i = 1, GetNumQuestLeaderBoards(logIndex) do
            local text, _, finished = GetQuestLogLeaderBoard(i, logIndex)
            if text and not finished then
                WorldMapTooltip:AddLine("- " .. WorldMapFrame_ReverseQuestObjective(text), 1, 1, 1, 1)
            end
        end
    end
    WorldMapTooltip:Show()
end

local function heldPin(index)
    local pin = heldPool[index]
    if pin then return pin end
    -- Blizzard hides WorldMapPOIFrame on a held map; zoom clips and mutes the button's children.
    pin = QP.Create(WorldMapButton)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 3)
    pin:RegisterForClicks("LeftButtonUp")
    pin:SetScript("OnEnter", showHeldTooltip)
    pin:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
    pin:SetScript("OnClick", function(self)
        PlaySound("igMainMenuOptionCheckBoxOn")
        if WM.PickQuestFromCanvas then WM.PickQuestFromCanvas(self.row.questId) end
    end)
    heldPool[index] = pin
    return pin
end

local function styleHeldPin(pin, selected)
    local done = pin.row.completed
    QP.SetStyle(pin, done and "complete" or "numeric", pin.row.number, selected)
    -- QuestPOICompletedTemplate is the bare glyph; only a picked one gets a ring.
    local ring = (done and not selected) and 0 or 1
    pin.ring:SetAlpha(ring)
    pin.ringPushed:SetAlpha(ring)
    pin.ringHighlight:SetAlpha(ring)
end

local function placeHeldPins()
    local shown = 0
    if pinsHeld and WM.IsWindowed() then
        local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
        -- Against the frame Blizzard's own pins hang off, so both kinds come out one size on screen.
        local poiScale = WorldMapPOIFrame:GetEffectiveScale() / WorldMapButton:GetEffectiveScale()
        local focus = QP.GetFocus()
        for _, row in ipairs(heldRows) do
            if row.x and row.y then
                shown = shown + 1
                local pin = heldPin(shown)
                pin.row = row
                styleHeldPin(pin, row.questId == focus)
                local pinScale = (row.completed and HELD_COMPLETE_SCALE or QUEST_POI_NUMERIC_SCALE) * poiScale
                pin:SetScale(pinScale)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", row.x * width / pinScale, -row.y * height / pinScale)
                pin:Show()
            end
        end
    end
    for index = shown + 1, #heldPool do heldPool[index]:Hide() end
end

local function releaseQuestPins()
    if pinsHeld then
        pinsHeld = false
        if WatchFrame.showObjectives then SetCVar("questPOI", "1") end
    end
    placeHeldPins()
end

-- Off, the CVar makes the client count no quests, so Blizzard's next pass builds no pins at all.
local function guardQuestPins()
    if not WatchFrame.showObjectives then
        -- The player switched objectives off: the CVar is theirs again.
        pinsHeld = false
    elseif not WorldMapFrame:IsShown() then
        return releaseQuestPins()
    else
        if pinsHeld then SetCVar("questPOI", "1") end
        pinsHeld = wouldLeaveHole()
        if pinsHeld then
            readHeldPositions()
            SetCVar("questPOI", "0")
        end
    end
    placeHeldPins()
end

function WM.HeldQuestRows()
    return pinsHeld and heldRows or NO_ROWS
end

function WM.SelectQuestPOI(questID)
    for index = 1, WorldMapFrame.numQuests or 0 do
        local row = _G["WorldMapQuestFrame" .. index]
        if row and row.poiIcon then cropQuestPOI(row.poiIcon, row.questId == questID) end
    end
    for _, pin in ipairs(heldPool) do
        if pin:IsShown() then styleHeldPin(pin, pin.row.questId == questID) end
    end
end

local function tryFlashQuestPOI()
    dropStaleFlashes()
    if not pendingQuestFlash then return end
    if GetTime() > pendingQuestFlashUntil then
        pendingQuestFlash = nil
        return
    end
    for index = 1, WorldMapFrame.numQuests or 0 do
        local row = _G["WorldMapQuestFrame" .. index]
        if row and row.questId == pendingQuestFlash then
            local button = row.poiIcon
            if button and button:IsShown() then
                flashQuestPOI(button)
                pendingQuestFlash = nil
            end
            return
        end
    end
    for _, pin in ipairs(heldPool) do
        if pin:IsShown() and pin.row.questId == pendingQuestFlash then
            flashQuestPOI(pin)
            pendingQuestFlash = nil
            return
        end
    end
end

function WM.FlashQuestPOI(questID)
    if not questID then return end
    pendingQuestFlash, pendingQuestFlashUntil = questID, GetTime() + FLASH_PATIENCE
    tryFlashQuestPOI()
end

WM.RefreshLandmarks = restyleLandmarks

function WM.RefreshPins()
    restyleLandmarks()
    for index = 1, WorldMapFrame.numQuests or 0 do
        local row = _G["WorldMapQuestFrame" .. index]
        if row and row.poiIcon then placeQuestPOI(row.poiIcon) end
    end
    placeHeldPins()
end

local function styleAreaLabel()
    local font = addon.Fonts.PRIMARY
    WorldMapFrameAreaLabel:SetFont(font, LABEL_FONT_SIZE)
    WorldMapFrameAreaLabel:SetTextColor(1, 0.82, 0)
    WorldMapFrameAreaLabel:SetShadowColor(0, 0, 0, 1)
    WorldMapFrameAreaLabel:SetShadowOffset(1, -1)
    WorldMapFrameAreaDescription:SetFont(font, DESCRIPTION_FONT_SIZE)
    WorldMapFrameAreaDescription:SetTextColor(1, 1, 1)
    WorldMapFrameAreaDescription:SetShadowColor(0, 0, 0, 1)
    WorldMapFrameAreaDescription:SetShadowOffset(1, -1)
end

-- UpdateMapHighlight hands its map file only to the texture, so that path is the one clue to the zone.
local HIGHLIGHT_FILE = "WorldMap\\(.-)\\"
local rawLabel, shownLabel

local function appendZoneLevel()
    local text = WorldMapFrameAreaLabel:GetText()
    if not text or text == "" or text == shownLabel then return end
    if text ~= rawLabel then
        local file = not WorldMapFrame.poiHighlight and WorldMapHighlight:IsShown()
            and strmatch(WorldMapHighlight:GetTexture() or "", HIGHLIGHT_FILE) or nil
        rawLabel = text
        shownLabel = text .. WM.ZoneLevelSuffix(file)
    end
    WorldMapFrameAreaLabel:SetText(shownLabel)
end

-- The suffix is cached against the hovered name, so a toggle only lands once that cache is dropped.
function WM.RefreshZoneLabel()
    rawLabel, shownLabel = nil, nil
end

local function refreshZoneLevels()
    WM.RefreshZoneLabel()
    WM.RefreshNavBar()
end

-- ============================================================================
-- FILTER BUTTON
-- ============================================================================

-- The Lua gate is read from the CVar only at load, while the client honours the CVar live.
function WM.ObjectivesShown()
    return (WatchFrame.showObjectives and (pinsHeld or GetCVarBool("questPOI"))) and true or false
end

local function filterEntries()
    local entries = { { text = FILTERS, isTitle = true } }
    local function toggle(text, key, onChanged)
        entries[#entries + 1] = {
            text = text,
            checked = function() return WM:Config()[key] ~= false end,
            keepShown = true,
            func = function()
                WM:Config()[key] = not (WM:Config()[key] ~= false)
                onChanged()
            end,
        }
    end
    -- Blizzard's own checkbox takes the click: run from our code, its handler taints the blob.
    entries[#entries + 1] = {
        text = SHOW_QUEST_OBJECTIVES_ON_MAP_TEXT,
        checked = function() return WorldMapQuestShowObjectives:GetChecked() end,
        overlay = WorldMapQuestShowObjectives,
    }
    local npcScan = WM.NPCScanToggle()
    if npcScan then
        entries[#entries + 1] = {
            text = _G[npcScan:GetName() .. "Text"]:GetText(),
            checked = function() return npcScan:GetChecked() end,
            overlay = npcScan,
        }
    end
    toggle(L["Show Landmarks"], "landmarks", restyleLandmarks)
    toggle(L["Show Undiscovered Areas"], "fog", WM.RefreshFog)
    toggle(L["Show Dungeon Entrances"], "entrances", WM.RefreshMapPins)
    toggle(L["Show Graveyards"], "graveyards", WM.RefreshMapPins)
    toggle(L["Show Flight Points"], "flightPoints", WM.RefreshMapPins)
    toggle(L["Show Inns"], "inns", WM.RefreshMapPins)
    toggle(L["Show Zone Levels"], "zoneLevels", refreshZoneLevels)
    toggle(L["Show Map Coordinates"], "coordinates", WM.RefreshCoords)
    return entries
end

local function buildFilterButton()
    local button = CreateFrame("Button", "DragonUIWorldMapFilterButton", WM.border)
    button:SetSize(32, 32)
    button:SetFrameLevel(WM.border:GetFrameLevel() + 5)
    button:SetPoint("TOPRIGHT", WM.spacer, "BOTTOMRIGHT", -4, -4)

    -- Blizzard's tracking button: a 54px ring hung off the top-left corner of a 32px button.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAtlasTexture("map-tracking-border", true)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local function face(setter, getter, atlas)
        button[setter](button, ROCK)
        local tex = button[getter](button)
        tex:SetAtlasTexture(atlas)
        tex:ClearAllPoints()
        tex:SetSize(FILTER_ICON, FILTER_ICON)
        tex:SetPoint("CENTER", button, "CENTER", FILTER_ICON_X, FILTER_ICON_Y)
        return tex
    end
    face("SetNormalTexture", "GetNormalTexture", "map-filter-button")
    face("SetPushedTexture", "GetPushedTexture", "map-filter-button-down")
    -- MiniMapTracking's highlight fills the button unoffset; only the icon needs the nudge.
    button:SetHighlightTexture(ROCK)
    local highlight = button:GetHighlightTexture()
    highlight:SetAtlasTexture("map-zoom-highlight")
    highlight:SetBlendMode("ADD")
    highlight:ClearAllPoints()
    highlight:SetAllPoints(button)

    button:SetScript("OnClick", function(self)
        -- Blizzard syncs the tick to the CVar only at load, so a /console change leaves it stale.
        WorldMapQuestShowObjectives:SetChecked(WM.ObjectivesShown())
        addon.Menu.Open(self, filterEntries())
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(FILTERS)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- ============================================================================
-- CANVAS SHADOW
-- ============================================================================

-- Where Blizzard's "show quest objectives" box sat before it moved into the filter menu.
local function buildCanvasShadow()
    objectivesPlate = WM.border:CreateTexture(nil, "ARTWORK")
    objectivesPlate:SetAtlasTexture("mapcornershadow-left", true)
    objectivesPlate:SetPoint("BOTTOMLEFT", WM.spacer, "BOTTOMLEFT", 0, -(WM.canvasH or 465))
end

-- ============================================================================
-- BUILD
-- ============================================================================

function WM.BuildPins()
    styleAreaLabel()
    -- The handler is bound in XML, so only a script hook runs in the frame Blizzard rewrites the text.
    WorldMapButton:HookScript("OnUpdate", appendZoneLevel)
    buildFilterButton()
    buildCanvasShadow()

    hooksecurefunc("WorldMapFrame_Update", restyleLandmarks)
    hooksecurefunc("WorldMapFrame_Update", tryFlashQuestPOI)
    -- Blizzard reselects a pin of its own on every rebuild, so ours is re-cropped after it.
    hooksecurefunc("WorldMapFrame_SelectQuestFrame", function()
        -- Blizzard's pick is not ours: undo the twin it swaps in, as its numbered crop is undone below.
        local swap = QUEST_POI_SWAP_BUTTONS and QUEST_POI_SWAP_BUTTONS.WorldMapPOIFrame
        if swap and swap:IsShown() then
            swap:Hide()
            local source = swap.quest and swap.quest.poiIcon
            if source then source:Show() end
        end
        WM.SelectQuestPOI(QP.GetFocus())
    end)
    -- The lent checkbox flips its own state; our row's tick and anchor follow it.
    hooksecurefunc("WorldMapQuestShowObjectives_Toggle", function() addon.Menu.Refresh() end)
    hooksecurefunc("WorldMapQuestShowObjectives_AdjustPosition", function() addon.Menu.Refresh() end)
    local npcScan = WM.NPCScanToggle()
    if npcScan then npcScan:HookScript("OnClick", function() addon.Menu.Refresh() end) end
    QP.RegisterFocusListener(WM.SelectQuestPOI)
    hooksecurefunc("WorldMapFrame_UpdateQuests", dropStaleFlashes)
    hooksecurefunc("WorldMapFrame_DisplayQuestPOI", onQuestPOIDisplayed)

    -- Each runs ahead of a Blizzard quest pass: the map rebuild, or whoever hears a quest event first.
    hooksecurefunc("WorldMapFrame_SetMapName", guardQuestPins)
    hooksecurefunc("WatchFrame_GetCurrentMapQuests", guardQuestPins)
    -- Not WM.border: fullscreen mode hides that one while the map stays open.
    local guard = CreateFrame("Frame", nil, WorldMapFrame)
    guard:SetScript("OnHide", releaseQuestPins)
    guard:RegisterEvent("QUEST_LOG_UPDATE")
    guard:RegisterEvent("QUEST_POI_UPDATE")
    guard:RegisterEvent("PLAYER_LOGOUT")
    guard:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGOUT" then releaseQuestPins() else guardQuestPins() end
    end)
    -- Blizzard's empty pass hid the shape layer, but a quest picked on our pins still lights its area.
    hooksecurefunc("WorldMapFrame_DisplayQuests", function()
        if pinsHeld and WM.IsWindowed() and not InCombatLockdown() then WorldMapBlobFrame:Show() end
        -- WorldMapFrame_Update runs before the guard places held pins, so the flash looks again here.
        tryFlashQuestPOI()
    end)

    local onLayout = WM.OnLayout
    WM.OnLayout = function()
        if onLayout then onLayout() end
        objectivesPlate:SetPoint("BOTTOMLEFT", WM.spacer, "BOTTOMLEFT", 0, -(WM.canvasH or 465))
    end

    local onMode = WM.OnModeChanged
    WM.OnModeChanged = function(windowed)
        if onMode then onMode(windowed) end
        if objectivesPlate then
            if windowed then objectivesPlate:Show() else objectivesPlate:Hide() end
        end
    end
end
