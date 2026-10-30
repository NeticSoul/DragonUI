-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Totem timers: Blizzard's TotemFrame under the player with the HD ring; shamans move it in the editor.
-- Blizzard keeps the logic. Its buttons hold the slot DestroyTotem reads, so nothing here writes a field on them.

local addon = select(2, ...)
local L = addon.L
local UF = addon.UF

local KEY = "totemframe"
local MAX_BUTTONS = 4
local BUTTON_SIZE = 37
-- Retail's row and ring offset; the ring's art sits 1.5 up and left of its cell, over a soft shadow.
local BUTTON_GAP = -6
local RING_SIZE, RING_X, RING_Y = 30, 1, -1.5
local ICON_SIZE = 22
-- 3.3.5a's swipe is square: at 19 its corners stop under the ring, at the icon's 22 they stick out.
local SWIPE_SIZE = 19
-- Blizzard's anchor (TotemFrame.xml); only a reset ever writes it back.
local HOME_X, HOME_Y = 99, 38
local BOX_WIDTH = MAX_BUTTONS * BUTTON_SIZE + (MAX_BUTTONS - 1) * BUTTON_GAP
local PREVIEW_ICONS = {
    "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    "Interface\\Icons\\Spell_Fire_SearingTotem",
    "Interface\\Icons\\INV_Spear_04",
    "Interface\\Icons\\Spell_Nature_Windfury",
}

local Totems = { applied = false }
addon.TotemFrameModule = Totems

if addon.RegisterModule then
    addon:RegisterModule(KEY, Totems,
        L["Totem Timers"],
        L["The round totem timers under the player frame, with the HD ring and their own spot in the editor."],
        { lifecyclePrefix = "TotemFrame", loadOnce = true })
end

-- Own table, keyed by button: a field on Blizzard's buttons would taint them.
local pieces = {}
-- Handed to dark mode's unit frame sweep: real rings and the editor's fake ones.
local rings = {}
local box, preview
local previewing, rowOnBox = false, false

local function Enabled()
    return addon:IsModuleEnabled(KEY) and UF.IsEnabled("player")
end

-- =============================================================================
-- Skin
-- =============================================================================

local function FindPieces(button)
    local name = button:GetName()
    local found = {
        background = _G[name .. "Background"],
        iconFrame = _G[name .. "Icon"],
        icon = _G[name .. "IconTexture"],
        cooldown = _G[name .. "IconCooldown"],
    }
    -- The template's only unnamed piece: a child frame holding the ring.
    for _, child in ipairs({ button:GetChildren() }) do
        if child ~= found.iconFrame then
            for _, region in ipairs({ child:GetRegions() }) do
                if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "OVERLAY" then
                    found.ring, found.ringFrame = region, child
                end
            end
        end
    end
    if found.background and found.iconFrame and found.icon and found.cooldown and found.ring then
        return found
    end
end

-- False on a client whose frame differs: the stock frame is left alone.
local function FindAllPieces()
    if not (_G.TotemFrame and _G.TotemButton_Update and _G.TotemFrameTotem1) then return false end
    for i = 1, MAX_BUTTONS do
        local button = _G["TotemFrameTotem" .. i]
        if not button then return false end
        if not pieces[button] then
            pieces[button] = FindPieces(button)
            if not pieces[button] then return false end
            rings[#rings + 1] = pieces[button].ring
        end
    end
    return true
end

local function RaiseRing(piece)
    piece.ringFrame:SetFrameLevel(piece.cooldown:GetFrameLevel() + 1)
end

local function SkinButton(button)
    local piece = pieces[button]
    local art = UF.GetFrameSkin().totem
    piece.background:Hide()
    piece.ring:SetTexture(art.file)
    piece.ring:SetTexCoord(unpack(art.tc))
    piece.ring:SetSize(RING_SIZE, RING_SIZE)
    piece.ring:ClearAllPoints()
    piece.ring:SetPoint("CENTER", button, "CENTER", RING_X, RING_Y)
    piece.cooldown:ClearAllPoints()
    piece.cooldown:SetPoint("CENTER", piece.iconFrame, "CENTER", 0, 0)
    piece.cooldown:SetSize(SWIPE_SIZE, SWIPE_SIZE)
    RaiseRing(piece)
end

-- For totems already down when the skin arrives; GetTotemInfo errors on the 0 of a free button.
local function RepaintIcons()
    for button, piece in pairs(pieces) do
        local slot = button.slot
        if button:IsShown() and slot and slot > 0 then
            local _, _, _, duration, icon = GetTotemInfo(slot)
            if duration > 0 and icon and icon ~= "" then
                SetPortraitToTexture(piece.icon, icon)
            end
        end
    end
end

local function InstallHooks()
    if Totems.hooked then return end
    Totems.hooked = true
    -- Blizzard's SetTexture just made the icon square again.
    hooksecurefunc("TotemButton_Update", function(button, _, duration, icon)
        local piece = pieces[button]
        if Totems.applied and piece and duration > 0 and type(icon) == "string" and icon ~= "" then
            SetPortraitToTexture(piece.icon, icon)
            RaiseRing(piece)
        end
    end)
end

-- =============================================================================
-- Position (shamans only: Blizzard re-anchors a death knight's row by itself)
-- =============================================================================

local function Spot()
    local widgets = addon.db.profile.widgets
    return widgets and widgets[KEY]
end

-- Only Detach saves CENTER: closing the editor saves every box, and an unmoved one lands here as TOPLEFT.
local function Moved()
    local spot = Spot()
    return box ~= nil and spot ~= nil and spot.anchor == "CENTER" and spot.posX ~= nil
end

-- Onto UIParent's centre where it stands (it may hang from the row), so its offsets are screen ones.
local function Pin()
    local x, y = box:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if not (x and cx) then return false end
    box:ClearAllPoints()
    box:SetPoint("CENTER", UIParent, "CENTER", x - cx, y - cy)
    return true
end

local function Place()
    if Moved() then
        local spot = Spot()
        -- Not ApplyWidgetPositionFromDB: it returns in combat, and a reload in combat must land here too.
        box:ClearAllPoints()
        box:SetPoint("CENTER", UIParent, "CENTER", spot.posX, spot.posY or 0)
        TotemFrame:ClearAllPoints()
        TotemFrame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
        rowOnBox = true
    else
        TotemFrame:ClearAllPoints()
        TotemFrame:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", HOME_X, HOME_Y)
        rowOnBox = false
    end
end

local function LayPreview()
    local scale = PlayerFrame:GetScale()
    for i, piece in ipairs(preview) do
        local x = (BUTTON_SIZE / 2 + (i - 1) * (BUTTON_SIZE + BUTTON_GAP)) * scale
        local y = -BUTTON_SIZE / 2 * scale
        piece.icon:SetSize(ICON_SIZE * scale, ICON_SIZE * scale)
        piece.icon:SetPoint("CENTER", box, "TOPLEFT", x, y)
        piece.ring:SetSize(RING_SIZE * scale, RING_SIZE * scale)
        piece.ring:SetPoint("CENTER", box, "TOPLEFT", x + RING_X * scale, y + RING_Y * scale)
    end
end

local function SyncBox()
    if not Moved() then
        -- A reset or profile change dropped the spot under the row: hanging the box from it would close a loop.
        if rowOnBox then Place() end
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", TotemFrame, "TOPLEFT", 0, 0)
    end
    addon.SetEditorBoxScale(box, PlayerFrame:GetScale(), "TOPLEFT")
    LayPreview()
end

local function Detach()
    if Pin() then
        addon.SaveUIFramePosition(box, "widgets", KEY)
    end
    Place()
end

-- Attached, the box rides on the row; turned around before the drag, the row follows from the first move.
local function Grab()
    if Moved() or not Pin() then return end
    TotemFrame:ClearAllPoints()
    TotemFrame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    rowOnBox = true
end

-- =============================================================================
-- Editor
-- =============================================================================

local function UpdatePreview()
    local show = previewing and not TotemFrame:IsShown()
    for _, piece in ipairs(preview) do
        if show then
            piece.icon:Show()
            piece.ring:Show()
        else
            piece.icon:Hide()
            piece.ring:Hide()
        end
    end
end

local function PaintPreview()
    local art = UF.GetFrameSkin().totem
    for _, piece in ipairs(preview) do
        piece.ring:SetTexture(art.file)
        piece.ring:SetTexCoord(unpack(art.tc))
    end
end

local function CreateEditor()
    if box or select(2, UnitClass("player")) ~= "SHAMAN" then return end
    box = addon.CreateUIFrame(BOX_WIDTH, BUTTON_SIZE, "TotemFrame")
    -- Before the stock handler's StartMoving: re-anchoring a frame mid-move breaks the drag.
    local startDrag = box:GetScript("OnDragStart")
    box:SetScript("OnDragStart", function(self, ...)
        Grab()
        if startDrag then return startDrag(self, ...) end
    end)
    box:HookScript("OnDragStop", Detach)

    -- Its own frame under the box: on the box itself the fake row would draw over its BACKGROUND fill.
    local under = CreateFrame("Frame", nil, UIParent)
    under:SetFrameStrata(box:GetFrameStrata())
    under:SetFrameLevel(box:GetFrameLevel() - 1)
    under:SetAllPoints(box)
    preview = {}
    for i = 1, MAX_BUTTONS do
        local icon = under:CreateTexture(nil, "BORDER")
        SetPortraitToTexture(icon, PREVIEW_ICONS[i])
        icon:Hide()
        local ring = under:CreateTexture(nil, "ARTWORK")
        ring:Hide()
        preview[i] = { icon = icon, ring = ring }
        rings[#rings + 1] = ring
    end
    TotemFrame:HookScript("OnShow", UpdatePreview)
    TotemFrame:HookScript("OnHide", UpdatePreview)

    addon:RegisterEditableFrame({
        name = KEY,
        frame = box,
        configPath = { "widgets", KEY },
        editorVisible = function() return Totems.applied end,
        showTest = function()
            previewing = true
            SyncBox()
            UpdatePreview()
        end,
        hideTest = function()
            previewing = false
            UpdatePreview()
        end,
        onNudge = Detach,
        resetPosition = function()
            addon.db.profile.widgets[KEY] = nil
            Place()
            SyncBox()
        end,
        isDefaultPosition = function()
            return not Moved()
        end,
        applyPosition = function()
            Place()
            SyncBox()
        end,
        module = Totems,
    })
end

-- =============================================================================
-- Lifecycle
-- =============================================================================

-- Nothing here is protected (measured in and out of combat), so it never waits for combat to end.
function addon.ApplyTotemFrameSystem()
    if not FindAllPieces() then return end
    Totems.applied = true
    InstallHooks()
    -- The combat and rest glows sit in LOW at levels 900+, out of reach of a level from BACKGROUND.
    TotemFrame:SetFrameStrata("MEDIUM")
    for i = 1, MAX_BUTTONS do
        local button = _G["TotemFrameTotem" .. i]
        SkinButton(button)
        if i > 1 then
            button:SetPoint("LEFT", _G["TotemFrameTotem" .. (i - 1)], "RIGHT", BUTTON_GAP, 0)
        end
    end
    RepaintIcons()
    CreateEditor()
    if box then
        PaintPreview()
        if Moved() then Place() end
        SyncBox()
    end
    -- Dark mode's first sweep may run before the rings exist.
    if addon.RefreshDarkModeUnitFrames then addon.RefreshDarkModeUnitFrames() end
end

function addon.GetTotemRings()
    return rings
end

function addon.RestoreTotemFrameSystem()
    Totems.applied = false
end

function addon.RefreshTotemFrameSystem()
    if Enabled() then
        addon.ApplyTotemFrameSystem()
    else
        addon.RestoreTotemFrameSystem()
    end
end
