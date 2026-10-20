-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail SharedUIPanelTemplates PANEL_INSET_* places, moved to the window seat (nineslice.lua):
-- retail's 4 / -6 / 4 put the filigree on the bronze rails, which run 4.5 / 5.5 / 4.5 deep, so
-- every side now keeps the seat's 3 of stone between them. The slots and list panes ride the Inset.
local SEAT = addon.WindowSeat
local INSET_LEFT = SEAT.buttonLeft
local INSET_RIGHT = SEAT.buttonRight
local INSET_BOTTOM = SEAT.buttonBottom
local INSET_ATTIC = -60

-- The stats pane meets the window's own right and bottom edges; its filigree (pushed 2.5 out,
-- paneborder.lua) keeps the same gap to the rails there.
local STATS_RIGHT = SEAT.buttonRight
local STATS_BOTTOM = SEAT.buttonBottom

-- Sized from the Inset, not self-queried: right after Show(), this texture's own GetSize() lags.
local function paintPanelGround(inset)
    if not inset._duiPanelGroundTex then
        inset._duiPanelGroundTex = inset:CreateTexture(nil, "BACKGROUND", nil, -4)
    end
    local bg = inset._duiPanelGroundTex
    bg:SetAtlasTexture("character-panel-background")
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
    bg:SetWidth(inset:GetWidth())
    bg:SetHeight(inset:GetHeight())
end

local function newInset(cf, name, first, second)
    local frame = CreateFrame("Frame", name, cf)
    frame:SetPoint(unpack(first))
    frame:SetPoint(unpack(second))
    return frame
end

local function buildInset()
    local owner = _G.CharacterFrame
    if owner and owner.Inset == nil then
        owner.Inset = newInset(owner, "DragonUICharacterFrameInset",
            { "TOPLEFT", owner, "TOPLEFT", INSET_LEFT, INSET_ATTIC },
            { "BOTTOMRIGHT", owner, "BOTTOMLEFT", CP.PANEL_WIDTH + INSET_RIGHT, INSET_BOTTOM })
        paintPanelGround(owner.Inset)
    end
    return owner and owner.Inset
end

local function buildInsetRight()
    local owner = _G.CharacterFrame
    if owner and owner.Inset and owner.InsetRight == nil then
        local pane = newInset(owner, "DragonUICharacterFrameInsetRight",
            { "TOPLEFT", owner.Inset, "TOPRIGHT", 1, 0 },
            { "BOTTOMRIGHT", owner, "BOTTOMRIGHT", STATS_RIGHT, STATS_BOTTOM })
        -- PaperDollFrame spans the whole window and would otherwise eat the stat rows' mouseover.
        pane:SetFrameLevel(owner:GetFrameLevel() + CP.SUBFRAME_LEVEL + 10)
        pane:Hide()
        owner.InsetRight = pane
    end
    return owner and owner.InsetRight
end

-- Only PaperDoll gets the retail geometry, the only tab whose contents we re-anchored. The rest run
-- Blizzard's layout, built against the stock 384x512 window, so they keep exactly those dimensions.
local function setInsetForTab(tabName)
    local cf = _G.CharacterFrame
    if not cf or not cf.Inset or not CP:CanLayout() then return end
    local inset = cf.Inset

    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", cf, "TOPLEFT", INSET_LEFT, INSET_ATTIC)

    if tabName == "PaperDollFrame" then
        -- Pinned to the frame's LEFT so the model and slots hold still when the sidebar widens it.
        inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", CP.PANEL_WIDTH + INSET_RIGHT, INSET_BOTTOM)
        -- Width is the sidebar's to set here: it widens the frame when the stats pane is out.
        cf:SetHeight(CP.PANEL_HEIGHT)
    elseif CP.OWNED_TABS[tabName] then
        -- No sidebar here, so the inset follows the frame's own right edge instead.
        inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
        cf:SetWidth(CP.WidthForTabs and CP.WidthForTabs(CP.LIST_WIDTH) or CP.LIST_WIDTH)
        cf:SetHeight(CP.PANEL_HEIGHT)
    else
        inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", CP.PANEL_WIDTH + INSET_RIGHT, INSET_BOTTOM)
        -- Blizzard's content is untouched on these tabs, so give it back the exact window it was
        -- laid out against; chrome.lua hides our Inset for them.
        cf:SetWidth(CP.VANILLA_WIDTH)
        cf:SetHeight(CP.VANILLA_HEIGHT)
    end

    -- Tab switches resize the Inset without CharacterFrame re-firing OnShow, so repaint here too.
    paintPanelGround(inset)
end

CP.BuildInset = buildInset
CP.BuildInsetRight = buildInsetRight
CP.SetInsetForTab = setInsetForTab

function CP.RepaintPanelGround()
    local cf = _G.CharacterFrame
    if cf and cf.Inset then paintPanelGround(cf.Inset) end
end

CP:RegisterBuilder("insets", function()
    buildInset()
    buildInsetRight()
end)
