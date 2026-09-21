local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The gear under the close button and the display options it opens. The settings themselves live
-- with the feature that owns them, so this file stays presentation-only.
local COG_SIZE = 20
-- Measured from the close button rather than the frame corner so the pair travels together.
local COG_X, COG_Y = -6, -3

-- The cogwheel the equipment manager's rename button uses, so both gears in the panel are the same
-- icon. (Interface\Buttons\UI-OptionsButton, tried before this, renders nothing on this client.)
local GEAR = "Interface\\WorldMap\\Gear_64Grey"

local cog

local function setDarkBackground(dark)
    CP:Config().dark_background = dark and true or false
    CP.ApplyBodyBackground()
end

local function setGreyBackdrop(grey)
    CP:Config().grey_model_backdrop = grey and true or false
    if CP.ApplyModelBackdrop then CP.ApplyModelBackdrop() end
end

local function addTitle(text, entries)
    entries[#entries + 1] = { text = text, isTitle = true }
end

-- checked is a function: the menu stays open on click, so a captured value would freeze the tick.
local function addOption(text, checked, onClick, entries)
    entries[#entries + 1] = { text = text, checked = checked, keepShown = true, func = onClick }
end

-- Never grey: disabled entries are grey, so a greyed action reads as unclickable.
local ACTION_COLOR = "|cffd07070"

local function addAction(text, colorCode, onClick, entries)
    entries[#entries + 1] = { text = colorCode .. text .. "|r", func = onClick }
end

local function setStatShown(key, shown)
    CP:Config()[key] = shown and true or false
    if CP.ApplyGearSummaryVisibility then CP.ApplyGearSummaryVisibility() end
end

StaticPopupDialogs["DRAGONUI_RESET_STAT_ORDER"] = {
    text = addon.L["Restore the stat categories to their default order?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if CP.ResetSidebarOrder then CP.ResetSidebarOrder() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function menuEntries(entries)
    local function isDark() return CP:Config().dark_background and true or false end
    local function isGrey() return CP:Config().grey_model_backdrop and true or false end

    addTitle(addon.L["Background"], entries)
    addOption(addon.L["Stone"], function() return not isDark() end, function() setDarkBackground(false) end, entries)
    addOption(addon.L["Dark"], isDark, function() setDarkBackground(true) end, entries)

    -- Only where there is a model to put a backdrop behind.
    local paperdoll = (CP.ActiveTabName and CP.ActiveTabName()) == "PaperDollFrame"
    if not paperdoll then return end

    addTitle(addon.L["Model backdrop"], entries)
    addOption(addon.L["Greyscale"], isGrey, function() setGreyBackdrop(true) end, entries)
    addOption(addon.L["Full colour"], function() return not isGrey() end, function() setGreyBackdrop(false) end, entries)

    addTitle(addon.L["Gear summary"], entries)
    addOption(addon.L["Item Level"], function() return CP:Config().show_item_level ~= false end, function()
        setStatShown("show_item_level", CP:Config().show_item_level == false)
    end, entries)
    addOption(addon.L["GearScore"], function() return CP:Config().show_gear_score and true or false end, function()
        setStatShown("show_gear_score", not CP:Config().show_gear_score)
    end, entries)

    -- Only where the stats pane exists, which is the same tab that gates this whole block. Set
    -- apart by colour, not a blank row: every entry costs a fixed 16px whatever is drawn in it.
    addAction(addon.L["Reset stat order"], ACTION_COLOR, function()
        StaticPopup_Show("DRAGONUI_RESET_STAT_ORDER")
    end, entries)
end

local function build()
    local cf = _G.CharacterFrame
    if cog or not cf then return end

    cog = CreateFrame("Button", "DragonUICharacterSettingsCog", cf)
    cog:SetSize(COG_SIZE, COG_SIZE)
    -- The nineslice corner and the title band both paint over this corner otherwise, the same way
    -- the close button has to clear them.
    cog:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 20)

    local close = _G.CharacterFrameCloseButton
    if close then
        cog:SetPoint("TOPRIGHT", close, "BOTTOMRIGHT", COG_X, COG_Y)
    else
        cog:SetPoint("TOPRIGHT", cf, "TOPRIGHT", COG_X - 6, COG_Y - 24)
    end

    local icon = cog:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GEAR)
    icon:SetAllPoints(cog)
    cog.Icon = icon

    local hl = cog:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(GEAR)
    hl:SetAllPoints(cog)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.4)

    cog:SetScript("OnClick", function(self)
        local entries = {}
        menuEntries(entries)
        addon.Menu.Open(self, entries)
    end)
    cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- Neutral wording: the same gear serves every tab we draw, so naming one of them is wrong
        -- on the others and would go stale again as more arrive.
        GameTooltip:SetText(addon.L["Panel settings"], 1, 1, 1)
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

CP.SettingsCog = function() return cog end

-- Only on the tabs we draw: on Blizzard's own the menu would have nothing to change.
function CP.SetSettingsCogShown(visible)
    if cog then cog:SetShownReq(visible) end
end

CP:RegisterBuilder("settingscog", build)
