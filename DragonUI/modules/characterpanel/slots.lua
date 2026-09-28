-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail's slot metal from Char-Paperdoll-Parts: 3.3.5a slots are a bare ItemButtonTemplate.
local PARTS = addon._dir .. "CharacterPanel\\charpaperdollparts"

-- Width, height, then left/right/top/bottom texcoords; some are rounded on purpose, keep them.
local SLICE = {
    left = { 49, 44, 0.20703125, 0.3984375, 0.59375, 0.9375 },
    right = { 50, 44, 0.00390625, 0.19921875, 0.59375, 0.9375 },
    bottom = { 42, 53, 0.671875, 0.8359375, 0.00781, 0.42188 },
    gapLeft = { 6, 54, 0.70703125, 0.73046875, 0.4375, 0.85938 },
    gapRight = { 7, 54, 0.671875, 0.69921875, 0.4375, 0.85938 },
}

local function slotNames(...)
    local names = {}
    for i = 1, select("#", ...) do
        names[i] = "Character" .. select(i, ...) .. "Slot"
    end
    return names
end

CP.LEFT_COLUMN = slotNames("Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist")
CP.RIGHT_COLUMN = slotNames("Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1")
CP.WEAPON_ROW = slotNames("MainHand", "SecondaryHand", "Ranged")

local GROUPS = {
    { list = "LEFT_COLUMN", slice = SLICE.left, point = "TOPLEFT", x = -4, y = 0 },
    { list = "RIGHT_COLUMN", slice = SLICE.right, point = "TOPRIGHT", x = 4, y = 0 },
    { list = "WEAPON_ROW", slice = SLICE.bottom, point = "TOPLEFT", x = -4, y = 8 },
}

-- Only each chain's head moves; the rest of a column follows it through Blizzard's own anchors.
local HEADS = {
    { "CharacterHeadSlot", "TOPLEFT", "TOPLEFT", 4, -2 },
    { "CharacterHandsSlot", "TOPRIGHT", "TOPRIGHT", -4, -2 },
    -- Three 37px weapons plus two 5px gaps are 121 wide; Ammo hangs off the right of that.
    { "CharacterMainHandSlot", "BOTTOMLEFT", "BOTTOM", -60, 20 },
}

-- The sidebar replaces these readouts; at the panel's 338 width they would sit on the model.
local STAT_FRAMES = { "CharacterAttributesFrame", "CharacterResistanceFrame" }

local GAPS = {
    { "CharacterMainHandSlot", SLICE.gapLeft, "TOPRIGHT", "TOPLEFT" },
    { "CharacterRangedSlot", SLICE.gapRight, "TOPLEFT", "TOPRIGHT" },
}

local function cutPiece(slot, slice, point, anchor, anchorPoint, x, y)
    local piece = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
    piece:SetSize(slice[1], slice[2])
    piece:SetTexture(PARTS)
    piece:SetTexCoord(unpack(slice, 3))
    piece:SetPoint(point, anchor, anchorPoint, x, y)
    return piece
end

local function eachGroupSlot(fn)
    for _, group in ipairs(GROUPS) do
        for _, name in ipairs(CP[group.list]) do
            if _G[name] then fn(_G[name], group) end
        end
    end
end

local function dressSlot(slot, group)
    slot._duiSlotFrame = slot._duiSlotFrame
        or cutPiece(slot, group.slice, group.point, slot, group.point, group.x, group.y)
end

local function fillWeaponGaps()
    for _, gap in ipairs(GAPS) do
        local slot = _G[gap[1]]
        local metal = slot and slot._duiSlotFrame
        if metal and not slot._duiGap then
            slot._duiGap = cutPiece(slot, gap[2], gap[3], metal, gap[4], 0, 0)
        end
    end
end

local function pinColumnHeads(inset)
    for _, head in ipairs(HEADS) do
        local slot = _G[head[1]]
        if slot and not slot._duiAnchored then
            slot._duiAnchored = true
            slot:ClearAllPoints()
            slot:SetPoint(head[2], inset, head[3], head[4], head[5])
        end
    end
    fillWeaponGaps()
end

local function hideAgain(self)
    self:Hide()
end

local function retireStatFrame(stats)
    if stats and not stats._duiStatsHidden then
        stats._duiStatsHidden = true
        stats:Hide()
        stats:HookScript("OnShow", hideAgain)
    end
end

-- Model and slots are siblings at one level, so a zoomed model would paint over the weapon row.
local function raiseOverModel(model)
    local level = model:GetFrameLevel() + 2
    eachGroupSlot(function(slot) slot:SetFrameLevel(level) end)
    local ammo = _G.CharacterAmmoSlot
    if ammo then ammo:SetFrameLevel(level) end
end

CP:RegisterBuilder("slots", function()
    eachGroupSlot(dressSlot)
    local panel = _G.CharacterFrame
    if panel and panel.Inset then pinColumnHeads(panel.Inset) end
    for _, name in ipairs(STAT_FRAMES) do retireStatFrame(_G[name]) end
    if _G.CharacterModelFrame then raiseOverModel(_G.CharacterModelFrame) end
end)
