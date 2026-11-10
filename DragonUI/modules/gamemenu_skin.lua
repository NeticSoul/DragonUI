-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon then return end

local _G = _G
local ipairs = ipairs
local type = type
local max = math.max
local CreateFrame = CreateFrame

local GameMenuSkinModule = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("gamemenu_skin", GameMenuSkinModule,
        addon.L["Game Menu"],
        addon.L["Retail-style Game Menu chrome"],
        { lifecyclePrefix = "GameMenuSkin", loadOnce = true })
end

-- The retail menu title sits in a small plaque straddling the top border: a bronze
-- line frame with the same diamond "dots" the window uses in its corners.
-- The diamond-metal rail's centre is 7px inside the frame's top edge.
local PLAQUE_HEIGHT = 26
local PLAQUE_PAD = 44
local PLAQUE_MIN_WIDTH = 90
local PLAQUE_TOP_OFFSET = -7
local PLAQUE_FILL = "Interface\\ChatFrame\\ChatFrameBackground"
local PLAQUE_LINE = "Interface\\Buttons\\WHITE8X8"
local PLAQUE_LINE_SIZE = 2
local PLAQUE_DOT_SIZE = 8
local PLAQUE_DOT_ART = 32
local PLAQUE_DOT_INSET = 10
local PLAQUE_LINE_COLOR = { 0.52, 0.40, 0.22 }
-- Atlas name, art-pixel offset of the diamond inside its corner cell, place on the plaque.
local CORNER_DOTS = {
    { "ui-frame-diamondmetal-cornertopleft", PLAQUE_DOT_INSET, PLAQUE_DOT_INSET, "TOPLEFT", 2, -2 },
    { "ui-frame-diamondmetal-cornertopright", 128 - PLAQUE_DOT_INSET - PLAQUE_DOT_ART, PLAQUE_DOT_INSET, "TOPRIGHT", -2, -2 },
    { "ui-frame-diamondmetal-cornerbottomleft", PLAQUE_DOT_INSET, 128 - PLAQUE_DOT_INSET - PLAQUE_DOT_ART, "BOTTOMLEFT", 2, 2 },
    { "ui-frame-diamondmetal-cornerbottomright", 128 - PLAQUE_DOT_INSET - PLAQUE_DOT_ART, 128 - PLAQUE_DOT_INSET - PLAQUE_DOT_ART, "BOTTOMRIGHT", -2, 2 },
}
local BUTTON_PREFIXES = { "^GameMenuButton", "^EscapeMenuButton", "^DragonUIGameMenuButton" }
local STOCK_CHROME = { "GameMenuFrameHeader", "GameMenuFrameTitle", "GameMenuFrameCloseButton" }
-- Every stock menu button shares one size; the injected buttons do not, so match this one.
local REFERENCE_BUTTONS = {
    "GameMenuButtonOptions", "GameMenuButtonSoundOptions", "GameMenuButtonUIOptions",
    "GameMenuButtonMacros", "GameMenuButtonLogout", "GameMenuButtonQuit",
}

local function IsModuleEnabled()
    if addon.IsModuleEnabled then
        return addon:IsModuleEnabled("gamemenu_skin")
    end
    return true
end

local function stockTitle()
    local stock = _G.GameMenuFrameTitle
    local text = stock and stock:GetText()
    if type(text) == "string" and text ~= "" then
        return text
    end
    return _G.MAIN_MENU or addon.L["Game Menu"]
end

-- 3.3.5a draws the menu with a tiled dialog backdrop, border, header art and a title
-- FontString. Hide every direct region, not just textures: some clients leave the title
-- standing over the new window.
local function hideStockChrome(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    for _, name in ipairs(STOCK_CHROME) do
        local region = _G[name]
        if region and region.Hide then
            region:Hide()
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.Hide then
            region:Hide()
        end
    end
end

local function isMenuButton(child)
    local name = child.GetName and child:GetName()
    if not name then
        return false
    end
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        if name:find(prefix) then
            return true
        end
    end
    return false
end

local function menuButtonSize()
    for _, name in ipairs(REFERENCE_BUTTONS) do
        local button = _G[name]
        if button then
            local width, height = button:GetWidth(), button:GetHeight()
            if width and height and width > 0 and height > 0 then
                return width, height
            end
        end
    end
end

local function skinButtons(frame)
    local forever = addon.ForeverUI
    if not (forever and forever.SkinButton) then
        return
    end
    -- The DragonUI and AddOns buttons are added on show at their own sizes; SkinButton is idempotent.
    local width, height = menuButtonSize()
    for _, child in ipairs({ frame:GetChildren() }) do
        if isMenuButton(child) and child:IsObjectType("Button") then
            if width and height and (child:GetWidth() ~= width or child:GetHeight() ~= height) then
                child:SetSize(width, height)
            end
            forever.SkinButton(child)
        end
    end
end

local function solid(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(PLAQUE_LINE)
    texture:SetVertexColor(color[1], color[2], color[3], 1)
    return texture
end

local function createTitlePlaque(frame, title)
    local plaque = CreateFrame("Frame", nil, frame)
    plaque:SetHeight(PLAQUE_HEIGHT)
    plaque:SetPoint("CENTER", frame, "TOP", 0, PLAQUE_TOP_OFFSET)

    local fill = plaque:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(PLAQUE_FILL)
    fill:SetAllPoints(plaque)
    fill:SetVertexColor(0, 0, 0, 0.92)

    -- Line frame, inset one pixel so the outer edge stays crisp.
    local top = solid(plaque, "BORDER", PLAQUE_LINE_COLOR)
    top:SetPoint("TOPLEFT", plaque, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", plaque, "TOPRIGHT", -1, -1)
    top:SetHeight(PLAQUE_LINE_SIZE)

    local bottom = solid(plaque, "BORDER", PLAQUE_LINE_COLOR)
    bottom:SetPoint("BOTTOMLEFT", plaque, "BOTTOMLEFT", 1, 1)
    bottom:SetPoint("BOTTOMRIGHT", plaque, "BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(PLAQUE_LINE_SIZE)

    local left = solid(plaque, "BORDER", PLAQUE_LINE_COLOR)
    left:SetPoint("TOPLEFT", plaque, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", plaque, "BOTTOMLEFT", 1, 1)
    left:SetWidth(PLAQUE_LINE_SIZE)

    local right = solid(plaque, "BORDER", PLAQUE_LINE_COLOR)
    right:SetPoint("TOPRIGHT", plaque, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", plaque, "BOTTOMRIGHT", -1, 1)
    right:SetWidth(PLAQUE_LINE_SIZE)

    -- The window's own corner diamonds, cropped from its four corner pieces.
    for _, dot in ipairs(CORNER_DOTS) do
        local info = addon.ForeverAtlas and addon.ForeverAtlas[dot[1]]
        if info then
            local texture = plaque:CreateTexture(nil, "OVERLAY")
            texture:SetTexture(info[1])
            local u = info[4] + dot[2] / 512
            local v = info[6] + dot[3] / 512
            texture:SetTexCoord(u, u + PLAQUE_DOT_ART / 512, v, v + PLAQUE_DOT_ART / 512)
            texture:SetSize(PLAQUE_DOT_SIZE, PLAQUE_DOT_SIZE)
            texture:SetPoint("CENTER", plaque, dot[4], dot[5], dot[6])
        end
    end

    local label = plaque:CreateFontString(nil, "OVERLAY")
    local fonts = addon.ForeverUI.Fonts
    label:SetFontObject((fonts and fonts.Normal) or GameFontNormal)
    label:SetJustifyH("CENTER")
    label:SetPoint("CENTER", plaque, "CENTER", 0, 0)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:SetText(title)

    plaque:SetWidth(max(PLAQUE_MIN_WIDTH, label:GetStringWidth() + PLAQUE_PAD))
    plaque:SetFrameLevel(frame:GetFrameLevel() + 1)
end

local function skinFrame(frame, title)
    local forever = addon.ForeverUI
    if not (forever and forever.SkinDialog) or frame._duiGameMenuSkinned then
        return
    end
    frame._duiGameMenuSkinned = true

    -- The plaque replaces SkinDialog's title: no title, no fontstring over the buttons.
    forever.SkinDialog(frame, { closable = false, movable = false })
    if frame.TitleText then
        frame.TitleText:Hide()
    end
    createTitlePlaque(frame, title)
end

local hooked = false

-- Everything that can come back after the first pass: a client re-showing its regions,
-- buttons added by later OnShow hooks, a custom client rebuilding its button list.
local function redress(frame)
    hideStockChrome(frame)
    skinButtons(frame)
end

local function dress(frame)
    -- Read the client's title before hiding the fontstring that carries it.
    local title = stockTitle()
    hideStockChrome(frame)
    skinFrame(frame, title)
    skinButtons(frame)
    -- Other OnShow hooks (the AddOns button) may run after ours; catch their buttons and
    -- any stock region a custom client re-shows.
    addon:After(0, function()
        if frame:IsShown() then
            redress(frame)
        end
    end)
end

local function ensureHooks(frame)
    if hooked then
        return
    end
    hooked = true

    frame:HookScript("OnShow", function(self)
        if IsModuleEnabled() then
            dress(self)
        end
    end)

    -- Custom clients rebuild the button list on each open; re-skin after they do.
    if _G.GameMenuFrame_UpdateVisibleButtons then
        hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", function()
            local menu = _G.GameMenuFrame
            if menu and menu:IsShown() and IsModuleEnabled() then
                redress(menu)
            end
        end)
    end
end

function addon.ApplyGameMenuSkinSystem()
    if not IsModuleEnabled() then return end
    GameMenuSkinModule.initialized = true
    GameMenuSkinModule.applied = true

    local frame = _G.GameMenuFrame
    if not frame then return end
    ensureHooks(frame)
    dress(frame)
end

function addon.RestoreGameMenuSkinSystem()
    GameMenuSkinModule.applied = false
end

function addon.RefreshGameMenuSkinSystem()
    if IsModuleEnabled() then
        addon.ApplyGameMenuSkinSystem()
    else
        addon.RestoreGameMenuSkinSystem()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    addon.ApplyGameMenuSkinSystem()
end)
