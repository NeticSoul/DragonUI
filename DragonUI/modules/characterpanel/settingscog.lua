-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The equipment manager's rename button draws this gear too; UI-OptionsButton renders blank here.
local GEAR_ART = "Interface\\WorldMap\\Gear_64Grey"
local RESET_POPUP = "DRAGONUI_RESET_STAT_ORDER"
-- Muted red, never grey: grey is how a disabled entry looks, and this action is live.
local ACTION_COLOR = "|cffd07070"

local cog

local function resetStatOrder()
    local reset = CP.ResetSidebarOrder
    if reset then reset() end
end

StaticPopupDialogs[RESET_POPUP] = {
    text = addon.L["Restore the stat categories to their default order?"],
    OnAccept = resetStatOrder,
    button1 = YES, button2 = NO, timeout = 0, preferredIndex = 3,
    whileDead = true, hideOnEscape = true,
}

local PAINTER_OF = {
    dark_background = "ApplyBodyBackground",
    grey_model_backdrop = "ApplyModelBackdrop",
    show_item_level = "ApplyGearSummaryVisibility",
    show_gear_score = "ApplyGearSummaryVisibility",
}

local function store(key, value)
    CP:Config()[key] = not not value
    local repaint = CP[PAINTER_OF[key]]
    if repaint then repaint() end
end

local function heading(text)
    return { text = text, isTitle = true }
end

local function choice(text, key, side)
    return {
        text = text,
        keepShown = true,
        checked = function() return (not CP:Config()[key]) == (not side) end,
        func = function() store(key, side) end,
    }
end

-- `reads` turns the stored value into a tick, so each key keeps its own meaning for "absent".
local function toggle(text, key, reads)
    local function ticked() return reads(CP:Config()[key]) end
    return {
        text = text,
        keepShown = true,
        checked = ticked,
        func = function() store(key, not ticked()) end,
    }
end

local function absentMeansOn(value)
    return value ~= false
end

local function absentMeansOff(value)
    return value and true or false
end

local function menuEntries()
    local L = addon.L
    local list = {}
    local function add(entry) list[#list + 1] = entry end

    add(heading(L["Background"]))
    add(choice(L["Stone"], "dark_background", false))
    add(choice(L["Dark"], "dark_background", true))

    -- Only the paper doll has a model to back and a sidebar to summarise.
    local tab = CP.ActiveTabName and CP.ActiveTabName()
    if tab ~= "PaperDollFrame" then return list end

    add(heading(L["Model backdrop"]))
    add(choice(L["Greyscale"], "grey_model_backdrop", true))
    add(choice(L["Full colour"], "grey_model_backdrop", false))

    add(heading(L["Gear summary"]))
    add(toggle(L["Item Level"], "show_item_level", absentMeansOn))
    add(toggle(L["GearScore"], "show_gear_score", absentMeansOff))

    add({
        text = ACTION_COLOR .. L["Reset stat order"] .. "|r",
        func = function() StaticPopup_Show(RESET_POPUP) end,
    })
    return list
end

local function gearLayer(layer, alpha, blend)
    local tex = cog:CreateTexture(nil, layer)
    tex:SetTexture(GEAR_ART)
    tex:SetAllPoints()
    tex:SetAlpha(alpha)
    tex:SetBlendMode(blend or "BLEND")
    return tex
end

local function openMenu(self)
    addon.Menu.Open(self, menuEntries())
end

-- Neutral wording: the same gear serves every tab DragonUI draws.
local function showTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(addon.L["Panel settings"], 1, 1, 1)
    GameTooltip:Show()
end

local function hideTip()
    GameTooltip:Hide()
end

local function createCog()
    local frame = _G.CharacterFrame
    if cog or not frame then return end

    cog = CreateFrame("Button", "DragonUICharacterSettingsCog", frame)
    cog:SetSize(20, 20)
    -- Like the close button, it has to clear the nine-slice corner and the title band.
    cog:SetFrameLevel(frame:GetFrameLevel() + CP.SUBFRAME_LEVEL + 20)

    local closeButton = _G.CharacterFrameCloseButton
    if closeButton then
        cog:SetPoint("TOPRIGHT", closeButton, "BOTTOMRIGHT", -6, -3)
    else
        cog:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -27)
    end

    cog.Icon = gearLayer("ARTWORK", 1)
    gearLayer("HIGHLIGHT", 0.4, "ADD")

    cog:SetScript("OnClick", openMenu)
    cog:SetScript("OnEnter", showTip)
    cog:SetScript("OnLeave", hideTip)
end

function CP.SettingsCog()
    return cog
end

function CP.SetSettingsCogShown(visible)
    if cog then cog:SetShownCompat(visible) end
end

CP:RegisterBuilder("settingscog", createCog)
