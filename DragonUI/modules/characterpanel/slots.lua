local addon = select(2, ...)
local CP = addon.CharacterPanel

local PARTS = addon._dir .. "CharacterPanel\\charpaperdollparts"

-- Slices of Char-Paperdoll-Parts per retail's PaperDollItemSlotButton templates: 3.3.5a's slot
-- buttons inherit bare ItemButtonTemplate, so the metal frame simply does not exist on this client.
local LEFT_SLICE = { w = 49, h = 44, 0.20703125, 0.39843750, 0.59375, 0.93750 }
local RIGHT_SLICE = { w = 50, h = 44, 0.00390625, 0.19921875, 0.59375, 0.93750 }
local BOTTOM_SLICE = { w = 42, h = 53, 0.67187500, 0.83593750, 0.00781, 0.42188 }
local GAP_LEFT = { w = 6, h = 54, 0.70703125, 0.73046875, 0.43750, 0.85938 }
local GAP_RIGHT = { w = 7, h = 54, 0.67187500, 0.69921875, 0.43750, 0.85938 }

local LEFT_COLUMN = {
    "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
}
local RIGHT_COLUMN = {
    "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
}
local WEAPON_ROW = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }

local function decorate(slotName, slice, point, x, y)
    local slot = _G[slotName]
    if not slot or slot._duiSlotFrame then return end

    local tex = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(PARTS)
    tex:SetTexCoord(slice[1], slice[2], slice[3], slice[4])
    tex:SetSize(slice.w, slice.h)
    tex:SetPoint(point, slot, point, x, y)
    slot._duiSlotFrame = tex
end

local function decorateAll()
    for _, name in ipairs(LEFT_COLUMN) do decorate(name, LEFT_SLICE, "TOPLEFT", -4, 0) end
    for _, name in ipairs(RIGHT_COLUMN) do decorate(name, RIGHT_SLICE, "TOPRIGHT", 4, 0) end
    for _, name in ipairs(WEAPON_ROW) do decorate(name, BOTTOM_SLICE, "TOPLEFT", -4, 8) end
end

local function gapFiller(slot, slice, point, relPoint)
    if not slot or not slot._duiSlotFrame or slot._duiGap then return end
    local tex = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(PARTS)
    tex:SetTexCoord(slice[1], slice[2], slice[3], slice[4])
    tex:SetSize(slice.w, slice.h)
    tex:SetPoint(point, slot._duiSlotFrame, relPoint, 0, 0)
    slot._duiGap = tex
end

-- Blizzard anchors the columns to PaperDollFrame with offsets built for a 384-wide frame. Re-pin
-- both to the Inset; the rest of each column chains off the first slot, so only the heads move.
local function anchorColumns()
    local cf = _G.CharacterFrame
    if not cf or not cf.Inset then return end
    local inset = cf.Inset

    local head = _G.CharacterHeadSlot
    if head and not head._duiAnchored then
        head._duiAnchored = true
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -2)
    end

    local hands = _G.CharacterHandsSlot
    if hands and not hands._duiAnchored then
        hands._duiAnchored = true
        hands:ClearAllPoints()
        hands:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -4, -2)
    end

    -- The row sits between the columns rather than below them, so all four Wrath slots fit:
    -- 37+5+37+5+37+15+27 = 163 wide, centred in the 328-wide Inset. Ammo stays — hunters need it.
    local mh = _G.CharacterMainHandSlot
    if mh and not mh._duiAnchored then
        mh._duiAnchored = true
        mh:ClearAllPoints()
        mh:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 83, 20)
    end

    gapFiller(mh, GAP_LEFT, "TOPRIGHT", "TOPLEFT")
    gapFiller(_G.CharacterRangedSlot, GAP_RIGHT, "TOPLEFT", "TOPRIGHT")
end

-- Wrath's stat readouts are replaced wholesale by the sidebar, and at 338 wide they would
-- otherwise sit on top of the model.
local VANILLA_STAT_FRAMES = { "CharacterAttributesFrame", "CharacterResistanceFrame" }

local function hideVanillaStats()
    for _, name in ipairs(VANILLA_STAT_FRAMES) do
        local f = _G[name]
        if f and not f._duiStatsHidden then
            f._duiStatsHidden = true
            f:Hide()
            f:HookScript("OnShow", function(self) self:Hide() end)
        end
    end
end

-- Model and slot buttons are siblings at the same frame level, so draw order falls to creation
-- order -- and a zoomed-in model paints straight over the weapon row beneath it.
local function raiseSlots()
    local model = _G.CharacterModelFrame
    if not model then return end
    local level = model:GetFrameLevel() + 2

    for _, group in ipairs({ CP.LEFT_COLUMN, CP.RIGHT_COLUMN, CP.WEAPON_ROW }) do
        for _, name in ipairs(group) do
            local slot = _G[name]
            if slot then slot:SetFrameLevel(level) end
        end
    end
    if _G.CharacterAmmoSlot then _G.CharacterAmmoSlot:SetFrameLevel(level) end
end

local function build()
    decorateAll()
    anchorColumns()
    hideVanillaStats()
    raiseSlots()
end

CP.LEFT_COLUMN = LEFT_COLUMN
CP.RIGHT_COLUMN = RIGHT_COLUMN
CP.WEAPON_ROW = WEAPON_ROW

CP:RegisterBuilder("slots", build)
