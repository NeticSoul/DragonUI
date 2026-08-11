local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail SharedUIPanelTemplates PANEL_INSET_* constants.
local INSET_LEFT = 4
local INSET_RIGHT = -6
local INSET_BOTTOM = 4
local INSET_ATTIC = -60

-- Retail's InsetFrameTemplate fills with UI-Background-Marble, which is a Cata+ path that does
-- not exist on 3.3.5a; DragonUI ships its own rock tile, so use that instead.
local ROCK = addon._dir .. "UI\\ui-background-rock"

local function decorate(inset)
    if inset._duiDecorated then return end
    inset._duiDecorated = true

    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints(inset)
    -- Tint owned by chrome.lua, which drives every ground in the panel from one setting.
    inset.Bg = bg
    if CP.ApplyBodyBackground then CP.ApplyBodyBackground() end
end

local function buildInset()
    local cf = _G.CharacterFrame
    if not cf or cf.Inset then return cf and cf.Inset end

    local inset = CreateFrame("Frame", "DragonUICharacterFrameInset", cf)
    inset:SetPoint("TOPLEFT", cf, "TOPLEFT", INSET_LEFT, INSET_ATTIC)
    -- Pinned to the frame's LEFT, not its RIGHT, so slots and model hold still when the
    -- sidebar widens the panel.
    inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", CP.PANEL_WIDTH + INSET_RIGHT, INSET_BOTTOM)
    -- Stays at the default child level: it must sit above CharacterFrame's own rock backdrop
    -- but below the tab subframes, which chrome.lua raises to make room.
    cf.Inset = inset

    decorate(inset)
    return inset
end

local function buildInsetRight()
    local cf = _G.CharacterFrame
    if not cf or cf.InsetRight then return cf and cf.InsetRight end
    local inset = cf.Inset
    if not inset then return nil end

    local insetRight = CreateFrame("Frame", "DragonUICharacterFrameInsetRight", cf)
    insetRight:SetPoint("TOPLEFT", inset, "TOPRIGHT", 1, 0)
    insetRight:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -4, 4)
    -- PaperDollFrame is setAllPoints, so once the panel expands it covers this pane too and
    -- would swallow the stat rows' mouseover unless the sidebar sits above it.
    insetRight:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 10)
    insetRight:Hide()
    cf.InsetRight = insetRight

    decorate(insetRight)
    return insetRight
end

-- Only PaperDoll gets the retail geometry, the only tab whose contents we re-anchored. The rest run
-- Blizzard's layout, built against the stock 384x512 window, so they keep exactly those dimensions.
local function setInsetForTab(tabName)
    local cf = _G.CharacterFrame
    if not cf or not cf.Inset or InCombatLockdown() then return end
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
        cf:SetWidth(CP.LIST_WIDTH)
        cf:SetHeight(CP.PANEL_HEIGHT)
    else
        inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", CP.PANEL_WIDTH + INSET_RIGHT, INSET_BOTTOM)
        -- Blizzard's content is untouched on these tabs, so give it back the exact window it was
        -- laid out against; chrome.lua hides our Inset for them.
        cf:SetWidth(CP.VANILLA_WIDTH)
        cf:SetHeight(CP.VANILLA_HEIGHT)
    end
end

CP.BuildInset = buildInset
CP.BuildInsetRight = buildInsetRight
CP.SetInsetForTab = setInsetForTab

CP:RegisterBuilder("insets", function()
    buildInset()
    buildInsetRight()
end)
