local addon = select(2, ...)
local CP = addon.CharacterPanel

-- Retail SharedUIPanelTemplates PANEL_INSET_* constants.
local INSET_LEFT = 4
local INSET_RIGHT = -6
local INSET_BOTTOM = 4
local INSET_ATTIC = -60

-- Retail's InsetFrameTemplate ground, shipped with the addon: the near-black marble is what makes
-- a pane read as recessed against the body rock, and it stays dark whichever body the cog picks.
local MARBLE = addon._dir .. "UI\\ui-background-marble"

local function decorate(inset)
    if inset._duiDecorated then return end
    inset._duiDecorated = true

    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(MARBLE, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetAllPoints(inset)
    inset.Bg = bg
end

-- Retail's CharacterFrame paints this across its Inset, so the marble underneath never shows on that
-- side. Atlas first, then the anchors: set_atlas freezes a size it reads off an already-sized region.
local function paintPanelGround(inset)
    if inset._duiPanelGround then return end
    inset._duiPanelGround = true

    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -4)
    bg:set_atlas("character-panel-background")
    bg:SetAllPoints(inset)
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
    -- Only this one: the sidebar carries no such override in retail and keeps the bare marble.
    paintPanelGround(inset)
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
