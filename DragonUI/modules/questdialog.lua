-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local QuestDialog = { initialized = false, applied = false }

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end

if addon.RegisterModule then
    addon:RegisterModule("questdialog", QuestDialog, localized("Quest Dialog"),
        localized("Retail-style quest and gossip window chrome"), {
            lifecyclePrefix = "QuestDialog",
            loadOnce = true,
        })
end

local WIDTH, HEIGHT = 338, 496
-- Inside the inset's 3px bevel on every side; retail's 407px page overlaps it top and bottom.
local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 7, -63, 299, 404
-- Takes the bar's strip when unscrollable, stopping short of the dark right bevel, lost on paper.
local PAGE_W_FULL = 321
-- Clips 6px inside the page at both ends, so scrolled text fades out on paper, not on the torn edge.
local SCROLL_X, SCROLL_Y, SCROLL_W, SCROLL_H = 10, -69, 296, 392
-- Retail's ButtonFrameTemplate Inset; the page sits in it and the scrollbar owns its right strip.
local INSET_LEFT, INSET_TOP, INSET_RIGHT, INSET_BOTTOM = 4, -60, -6, 26
-- Top, right and bottom insets that centre the minimal bar in the channel (see CP.ReskinScrollBar).
local BAR_TOP, BAR_X, BAR_BOTTOM = 57, -15, 22
-- Where the stock 239/64 x 241/128 material quarters split, scaled to the page.
local MATERIAL_SPLIT_X, MATERIAL_SPLIT_Y = 236, 264
-- The bottom quarters end in 28 blank rows of 128, so they hang past the page to meet its edge.
local MATERIAL_OVERHANG = math.floor((PAGE_H - MATERIAL_SPLIT_Y) * 28 / 100 + 0.5)
local PANEL_X_NUDGE = 6

local ICONS = addon._dir .. "Quest\\"
local ICON_SIZE = 16
local FULL_CROP = { 0, 1, 0, 1 }
local STOCK_ICON = {}
local IN_PROGRESS = { file = ICONS .. "inprogressquesticons", w = 14, h = 16,
    coords = { 0.578125, 0.828125, 0.015625, 0.296875 } }
local REPEATABLE = { file = ICONS .. "repeatablequesticon" }
local AVAILABLE = { file = ICONS .. "availablequesticon" }
local TURN_IN = { file = ICONS .. "activequesticon" }

-- Keyed by file name so a button already carrying our art maps to itself.
local QUEST_ICONS = {
    availablequesticon = AVAILABLE,
    activequesticon = TURN_IN,
    dailyactivequesticon = REPEATABLE,
    repeatablequesticon = REPEATABLE,
    incompletequesticon = IN_PROGRESS,
    inprogressquesticons = IN_PROGRESS,
}

local QUEST_PANELS = {
    { "QuestFrameDetailPanel", "QuestDetailScrollFrame" },
    { "QuestFrameProgressPanel", "QuestProgressScrollFrame" },
    { "QuestFrameRewardPanel", "QuestRewardScrollFrame" },
    { "QuestFrameGreetingPanel", "QuestGreetingScrollFrame" },
}

local QUEST_BUTTONS = {
    { "QuestFrameAcceptButton", "BOTTOMLEFT" },
    { "QuestFrameCompleteButton", "BOTTOMLEFT" },
    { "QuestFrameCompleteQuestButton", "BOTTOMLEFT" },
    { "QuestFrameDeclineButton", "BOTTOMRIGHT" },
    { "QuestFrameGoodbyeButton", "BOTTOMRIGHT" },
    { "QuestFrameCancelButton", "BOTTOMRIGHT" },
    { "QuestFrameGreetingGoodbyeButton", "BOTTOMRIGHT" },
}

local function fileName(texture)
    local path = texture and texture:GetTexture()
    if type(path) ~= "string" then
        return ""
    end
    local name = path:lower():match("([^\\/]+)$") or ""
    return (name:gsub("%.%a+$", ""))
end

local function nudgePanel(window)
    if window:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then
        return
    end
    -- On the frame, not in UIPanelWindows: tainting that table blocks the first panel open in combat.
    window:SetAttribute("UIPanelLayout-xoffset", PANEL_X_NUDGE)
    if window:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(window)
    end
end

local function applySlices(host, layoutName)
    local slicer = _G.DragonUI_NineSlice
    local layout = slicer and slicer.GetLayout and slicer.GetLayout(layoutName)
    if layout then
        slicer.ApplyLayout(host, layout)
    end
end

local function tiled(window, layer, left, top, corner, right, bottom)
    local tex = window:CreateTexture(nil, layer)
    tex:SetPoint("TOPLEFT", window, "TOPLEFT", left, top)
    tex:SetPoint("BOTTOMRIGHT", window, corner, right, bottom)
    return tex
end

-- Both hang below the 21px title bar; the streaks fade out over the rock's first 43px.
local function paintBody(window)
    local rock = tiled(window, "BACKGROUND", 2, -21, "BOTTOMRIGHT", -2, 2)
    rock:SetTexture(addon._dir .. "UI\\ui-background-rock")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)

    local streaks = tiled(window, "BORDER", 6, -21, "TOPRIGHT", -2, -64)
    streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
end

-- A frame of its own so the panels, lifted one level above it, keep the page on top of the marble.
local function buildInset(window)
    local inset = CreateFrame("Frame", nil, window)
    inset:SetPoint("TOPLEFT", window, "TOPLEFT", INSET_LEFT, INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
    applySlices(inset, "InsetFrameTemplate")

    local marble = inset:CreateTexture(nil, "BACKGROUND")
    marble:SetTexture(addon._dir .. "UI\\ui-background-marble")
    marble:SetHorizTile(true)
    marble:SetVertTile(true)
    marble:SetAllPoints(inset)
    return inset
end

-- No masks in 3.3.5a: a bigger face would spill past the nine-slice ring.
local function seatPortrait(window, face)
    if not face then
        return
    end
    face:ClearAllPoints()
    face:SetPoint("TOPLEFT", window, "TOPLEFT", -2, 4)
    face:SetSize(56, 56)
end

local function dressTitle(window, holder, label)
    if not holder or not label then
        return
    end
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", window, "TOPLEFT", 60, -5)
    holder:SetPoint("TOPRIGHT", window, "TOPRIGHT", -24, -5)
    holder:SetHeight(16)

    label:SetFontObject(GameFontNormal)
    label:ClearAllPoints()
    label:SetAllPoints(holder)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
end

-- Quest and Gossip name their parts alike: QuestFramePortrait, QuestNpcNameFrame, ...
local function dressWindow(stem)
    local window = _G[stem .. "Frame"]
    window:SetSize(WIDTH, HEIGHT)
    window:SetHitRectInsets(0, 0, 0, 0)
    nudgePanel(window)
    applySlices(window, "PortraitFrameTemplate")
    paintBody(window)
    seatPortrait(window, _G[stem .. "FramePortrait"])
    dressTitle(window, _G[stem .. "NpcNameFrame"], _G[stem .. "FrameNpcNameText"])

    local CP = addon.CharacterPanel
    local close = _G[stem .. "FrameCloseButton"]
    if CP and CP.ModernizeCloseButton and close then
        CP.ModernizeCloseButton(close, window)
    end
    return window, buildInset(window)
end

local function hideStockArt(panel)
    for _, region in ipairs({ panel:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            local layer = region:GetDrawLayer()
            if layer == "BACKGROUND" or (layer == "ARTWORK" and fileName(region) == "ui-quest-botleftpatch") then
                region:Hide()
            end
        end
    end
end

local function coverWithMaterial(panel, page)
    local name = panel:GetName()
    local topLeft, topRight = _G[name .. "MaterialTopLeft"], _G[name .. "MaterialTopRight"]
    local botLeft, botRight = _G[name .. "MaterialBotLeft"], _G[name .. "MaterialBotRight"]
    if not (topLeft and topRight and botLeft and botRight) then
        return
    end
    topLeft:ClearAllPoints()
    topLeft:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    topLeft:SetSize(MATERIAL_SPLIT_X, MATERIAL_SPLIT_Y)

    topRight:ClearAllPoints()
    topRight:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 0, 0)
    topRight:SetPoint("BOTTOMRIGHT", page, "TOPRIGHT", 0, -MATERIAL_SPLIT_Y)

    botLeft:ClearAllPoints()
    botLeft:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT", 0, 0)
    botLeft:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", MATERIAL_SPLIT_X, -MATERIAL_OVERHANG)

    botRight:ClearAllPoints()
    botRight:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT", 0, 0)
    botRight:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, -MATERIAL_OVERHANG)
end

local function fitScrollBar(panel, scroll, window, page)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", SCROLL_X, SCROLL_Y)
    scroll:SetSize(SCROLL_W, SCROLL_H)

    local bar = _G[scroll:GetName() .. "ScrollBar"]
    if not bar then
        return
    end
    scroll.scrollBarHideable = true
    local CP = addon.CharacterPanel
    if CP and CP.ReskinScrollBar then
        CP.ReskinScrollBar(scroll, panel, BAR_TOP, BAR_X, BAR_BOTTOM, true)
    end

    local function fitPage()
        page:SetWidth(bar:IsShown() and PAGE_W or PAGE_W_FULL)
    end
    bar:HookScript("OnShow", fitPage)
    bar:HookScript("OnHide", fitPage)
    -- The template only re-evaluates on a range change, and the stock bar starts out shown.
    if ScrollFrame_OnScrollRangeChanged then
        ScrollFrame_OnScrollRangeChanged(scroll)
    end
    fitPage()
end

local function dressPanel(panel, scroll, window, inset)
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetFrameLevel(inset:GetFrameLevel() + 1)
    hideStockArt(panel)

    local page = panel:CreateTexture(nil, "BACKGROUND")
    page:SetAtlasTexture("questbg-parchment")
    page:SetSize(PAGE_W, PAGE_H)
    page:SetPoint("TOPLEFT", panel, "TOPLEFT", PAGE_X, PAGE_Y)

    coverWithMaterial(panel, page)
    if scroll then
        fitScrollBar(panel, scroll, window, page)
    end
end

local function dressButton(name, corner, window)
    local button = _G[name]
    if not button then
        return
    end
    button:ClearAllPoints()
    button:SetPoint(corner, window, corner, corner == "BOTTOMLEFT" and 6 or -6, 4)
    if addon.SkinRedButton then
        addon.SkinRedButton(button)
    end
end

-- Blizzard re-stamps every shown row before this runs, so each one is read fresh from its own path.
local function restyleIcons(prefix, suffix, count)
    for index = 1, count do
        local button = _G[prefix .. index]
        local icon = _G[prefix .. index .. suffix]
        if button and icon and button:IsShown() then
            -- Unmatched rows (gossip, daily) are still reset: the same icon may carry a quest crop.
            local look = QUEST_ICONS[fileName(icon)] or STOCK_ICON
            if look.file then
                icon:SetTexture(look.file)
            end
            local crop = look.coords or FULL_CROP
            icon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
            icon:SetSize(look.w or ICON_SIZE, look.h or ICON_SIZE)
        end
    end
end

local function raiseAbove(frame, base, locked)
    if frame:GetFrameLevel() <= base and not (locked and frame:IsProtected()) then
        frame:SetFrameLevel(base + 1)
    end
end

-- Children can land at or below their parent's level here and then draw under the page.
local function liftChildren(frame, locked)
    local base = frame:GetFrameLevel()
    for _, child in ipairs({ frame:GetChildren() }) do
        raiseAbove(child, base, locked)
        liftChildren(child, locked)
    end
end

local function settleLayers(window, inset, panels)
    local locked = InCombatLockdown()
    -- Siblings of the inset, so the parent rule alone would let them tie with it.
    for _, panel in ipairs(panels) do
        raiseAbove(panel, inset:GetFrameLevel(), locked)
    end
    liftChildren(window, locked)
end

local function buildQuestFrame()
    local window, inset = dressWindow("Quest")
    local panels = {}
    local function settle()
        settleLayers(window, inset, panels)
    end
    for _, entry in ipairs(QUEST_PANELS) do
        local panel = _G[entry[1]]
        if panel then
            panels[#panels + 1] = panel
            dressPanel(panel, _G[entry[2]], window, inset)
            -- After Blizzard's own OnShow, which has just reparented QuestInfo's frames into the panel.
            panel:HookScript("OnShow", settle)
        end
    end
    settle()
    for _, entry in ipairs(QUEST_BUTTONS) do
        dressButton(entry[1], entry[2], window)
    end

    -- The XML binds this OnShow to the function itself, so hooking the global would never fire.
    local greeting = _G.QuestFrameGreetingPanel
    if greeting then
        greeting:HookScript("OnShow", function()
            restyleIcons("QuestTitleButton", "QuestIcon", MAX_NUM_QUESTS or 32)
        end)
    end
end

local function buildGossipFrame()
    local window, inset = dressWindow("Gossip")
    local panels = {}
    local panel = _G.GossipFrameGreetingPanel
    if panel then
        panels[1] = panel
        dressPanel(panel, _G.GossipGreetingScrollFrame, window, inset)
    end
    dressButton("GossipFrameGreetingGoodbyeButton", "BOTTOMRIGHT", window)
    settleLayers(window, inset, panels)

    if _G.GossipFrameUpdate then
        hooksecurefunc("GossipFrameUpdate", function()
            restyleIcons("GossipTitleButton", "GossipIcon", NUMGOSSIPBUTTONS or 32)
            settleLayers(window, inset, panels)
        end)
    end
end

function addon.ApplyQuestDialogSystem()
    if not addon:IsModuleEnabled("questdialog") then
        return
    end
    QuestDialog.applied = true
    if QuestDialog.initialized then
        return
    end
    QuestDialog.initialized = true

    if _G.QuestFrame then
        local ok, err = pcall(buildQuestFrame)
        if not ok then
            addon:Error("Quest dialog build failed: " .. tostring(err))
        end
    end
    if _G.GossipFrame then
        local ok, err = pcall(buildGossipFrame)
        if not ok then
            addon:Error("Gossip dialog build failed: " .. tostring(err))
        end
    end
end

function addon.RestoreQuestDialogSystem()
    QuestDialog.applied = false
end

local loginWatcher = CreateFrame("Frame")
loginWatcher:RegisterEvent("PLAYER_LOGIN")
loginWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    addon.ApplyQuestDialogSystem()
end)
