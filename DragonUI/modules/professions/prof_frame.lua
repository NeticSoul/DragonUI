-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local Art = P.Art
local Frame = { page = "crafting", built = false }
P.Frame = Frame

-- Forever's window is 673 x 594; it registers 750 with UIPanel so the side tabs fit (changes.md #1).
Frame.WIDTH, Frame.HEIGHT, Frame.HOST_WIDTH = 673, 594, 750

local CHROME_LEVEL, TOP_LEVEL = 20, 22
Frame.OVERVIEW_ICON = addon._dir .. "Professions\\OverviewIcon"

local function ForeverAtlas()
    return addon.ForeverAtlas
end

-- No portrait: the title says which window it is, so the top-left is the plain metal corner (the
-- same 95px piece as the portrait one, kept at its -13 so the left edge still lines up).
local function chromeLayout()
    return {
        corners = {
            TopLeft = { "ui-frame-metal-cornertopleft", -13, 16 },
            TopRight = { "ui-frame-metal-cornertopright", 2, 16 },
            BottomLeft = { "ui-frame-metal-cornerbottomleft", -13, -8 },
            BottomRight = { "ui-frame-metal-cornerbottomright", 2, -8 },
        },
        edges = { Top = "_ui-frame-metal-edgetop", Bottom = "_ui-frame-metal-edgebottom",
                  Left = "!ui-frame-metal-edgeleft", Right = "!ui-frame-metal-edgeright" },
    }
end

local function skinCloseButton(button)
    local atlas = ForeverAtlas()
    local function put(setter, getter, name)
        local info = atlas[name]
        button[setter](button, info[1])
        button[getter](button):SetTexCoord(info[4], info[5], info[6], info[7])
    end
    put("SetNormalTexture", "GetNormalTexture", "redbutton-exit")
    put("SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed")
    put("SetDisabledTexture", "GetDisabledTexture", "redbutton-exit-disabled")
    local hl = atlas["redbutton-highlight"]
    button:SetHighlightTexture(hl[1], "ADD")
    button:GetHighlightTexture():SetTexCoord(hl[4], hl[5], hl[6], hl[7])
    button:SetSize(24, 24)
end

-- Parks a stock widget we no longer show; Blizzard keeps driving it (state, events, scripts) out of sight.
function Frame.Retire(widget)
    if widget then widget:SetParent(Frame.holder) end
end

-- Moves a stock widget into our layout, keeping its scripts and name.
function Frame.Adopt(widget, parent, ...)
    widget:SetParent(parent)
    widget:ClearAllPoints()
    widget:SetPoint(...)
    return widget
end

function Frame.SetTitle(text)
    if Frame.title then Frame.title:SetText(text or "") end
end

-- The window carries no portrait; the pages still name their icon, so this stays as a no-op for them.
function Frame.SetPortrait() end

function Frame.ApplyScale(scale)
    if not Frame.built then return end
    scale = tonumber(scale) or 1
    local host = TradeSkillFrame
    Frame.scaler:SetScale(scale)
    TradeSkillFrameCloseButton:SetScale(scale)
    host:SetSize(Frame.HOST_WIDTH * scale, Frame.HEIGHT * scale)
    host:SetHitRectInsets(0, (Frame.HOST_WIDTH - Frame.WIDTH) * scale, 0, 0)
    P.Fire("Scale", scale)
end

function Frame.Scale()
    local cfg = addon:GetModuleConfig("professions")
    return cfg and tonumber(cfg.scale) or 1
end

-- "overview", "crafting", or a page another addon added through P.Host. "overview" opens the
-- page that stands in for it when there is one.
function Frame.ShowPage(page)
    local Host = P.Host
    if page == "overview" and Host then page = Host.OverviewPage() end
    if page ~= "overview" and not (Host and Host.IsPage(page)) then page = "crafting" end
    Frame.page = page
    local overview = page == "overview"
    local hosted = Host and Host.ShowPage(page)
    Frame.craft:SetShownCompat(not overview and not hosted)
    Frame.overview:SetShownCompat(overview)
    if overview then
        Art.Set(Frame.bg, "bg-overview")
        Frame.bg:SetPoint("TOPLEFT", Frame.win, "TOPLEFT", 2, -21)
        Frame.bg:SetSize(669, 571)
    else
        Art.Set(Frame.bg, "bg-crafting", true)
        Frame.bg:SetPoint("TOPLEFT", Frame.win, "TOPLEFT", 3, -21)
    end
    P.Fire("Page", page)
end

function Frame.Build()
    if Frame.built then return end
    local host = TradeSkillFrame

    for _, region in ipairs({ host:GetRegions() }) do
        region:Hide()
    end

    Frame.holder = CreateFrame("Frame", nil, host)
    Frame.holder:Hide()

    local scaler = CreateFrame("Frame", "DragonUI_ProfessionsFrame", host)
    scaler:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    scaler:SetSize(Frame.HOST_WIDTH, Frame.HEIGHT)
    Frame.scaler = scaler

    local win = CreateFrame("Frame", nil, scaler)
    win:SetPoint("TOPLEFT", scaler, "TOPLEFT", 0, 0)
    win:SetSize(Frame.WIDTH, Frame.HEIGHT)
    Frame.win = win

    -- Regions of the scaler draw under every child.
    Frame.bg = scaler:CreateTexture(nil, "BACKGROUND")

    local level = scaler:GetFrameLevel()
    Frame.craft = CreateFrame("Frame", nil, scaler)
    Frame.craft:SetAllPoints(win)
    Frame.craft:SetFrameLevel(level + 2)
    Frame.overview = CreateFrame("Frame", nil, scaler)
    Frame.overview:SetAllPoints(win)
    Frame.overview:SetFrameLevel(level + 2)
    Frame.overview:Hide()

    -- The metal frame sits above the pages, as in the approved target; it takes no mouse input.
    local chrome = CreateFrame("Frame", nil, scaler)
    chrome:SetAllPoints(win)
    chrome:SetFrameLevel(level + CHROME_LEVEL)
    addon.ForeverUI.ApplyNineSlice(chrome, chromeLayout(), "BORDER")
    Frame.chrome = chrome

    Frame.title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Frame.title:SetHeight(12)
    Frame.title:SetPoint("TOPLEFT", win, "TOPLEFT", 24, -5)
    Frame.title:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24, -5)
    Frame.title:SetJustifyH("CENTER")

    -- Its click hides the parent panel, so it stays TradeSkillFrame's child and only moves above the chrome.
    local close = TradeSkillFrameCloseButton
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, 1)
    skinCloseButton(close)
    close:SetFrameLevel(level + TOP_LEVEL)

    Frame.Retire(TradeSkillCancelButton)

    Frame.built = true
    Frame.ApplyScale(Frame.Scale())
    Frame.ShowPage("crafting")
    P.Fire("Built")
    addon.ForeverUI.EnforceLayering(scaler)
    addon.WindowPositions:Register(host, "TradeSkillFrame", { parent = chrome, anchor = win })
end

function Frame.TopLevel()
    return Frame.scaler:GetFrameLevel() + TOP_LEVEL
end

-- Blizzard keeps writing the title into its own (hidden) font string; the Forever title mirrors it.
function Frame.RefreshHeader()
    if not Frame.built then return end
    local Host = P.Host
    if Frame.page == "overview" then
        Frame.SetTitle(TRADE_SKILLS)
        Frame.SetPortrait(Frame.OVERVIEW_ICON)
    elseif Host and Host.IsPage(Frame.page) then
        local title, portrait = Host.PageHeader(Frame.page)
        Frame.SetTitle(title or TRADE_SKILLS)
        Frame.SetPortrait(portrait or Frame.OVERVIEW_ICON)
    else
        Frame.SetTitle(Host and Host.Title() or TradeSkillFrameTitleText:GetText())
        local Prof = P.Professions
        Frame.SetPortrait(Prof.IconFor(Prof.EntryForLine(P.Model.Rank())))
    end
end

P.On("Activate", Frame.Build)
P.On("Update", Frame.RefreshHeader)
P.On("Page", Frame.RefreshHeader)
P.On("ProfessionChanged", function()
    if Frame.built then Frame.ShowPage("crafting") end
end)

P.On("Show", function()
    if not Frame.built then return end
    Frame.ShowPage(Frame.openOnPage or (Frame.openOnOverview and "overview") or "crafting")
    addon.ForeverUI.EnforceLayering(Frame.scaler)
end)

-- The Overview reads skill lines and the spellbook, so it opens with no trade skill behind the window.
function Frame.ToggleOverview()
    if not P.EnsureHost() then return end
    local host = TradeSkillFrame
    if host:IsShown() then
        local home = P.Host and P.Host.OverviewPage() or "overview"
        if Frame.page == home then HideUIPanel(host) else Frame.ShowPage("overview") end
        return
    end
    Frame.openOnOverview = true
    ShowUIPanel(host)
    Frame.openOnOverview = nil
end
addon.ToggleProfessionsBook = Frame.ToggleOverview

-- Pushed while the Overview is up, as Forever's button is while its professions book is open.
local function syncMicroButton(page)
    local button = _G.ProfessionMicroButton
    if not button then return end
    if page and page == (P.Host and P.Host.OverviewPage() or "overview") then
        button:SetButtonState("PUSHED", 1)
    else
        button:SetButtonState("NORMAL")
    end
end
P.On("Page", syncMicroButton)
P.On("Hide", syncMicroButton)

addon.RefreshProfessionsScale = function(scale)
    Frame.ApplyScale(scale or Frame.Scale())
end

-- ARL docks its scan button on TradeSkillFrame by the close button, under our chrome.
local function liftScanButton()
    local arl = _G.AckisRecipeList
    local button = type(arl) == "table" and arl.scan_button
    if not (P.active and Frame.built and button and button:GetParent() == TradeSkillFrame) then return end
    addon.ForeverUI.SkinButton(button)
    button:SetScale(Frame.scaler:GetScale())
    button:SetFrameStrata(Frame.scaler:GetFrameStrata())
    button:SetFrameLevel(Frame.TopLevel() - 1)
    -- Only ARL's default spot: its +4 offset tucks the button under our close button.
    if arl.db and arl.db.profile.scanbuttonlocation == "TR" then
        button:ClearAllPoints()
        button:SetPoint("RIGHT", TradeSkillFrameCloseButton, "LEFT", -4, 0)
    end
end
P.On("Scale", liftScanButton)

local scanHooked = false
local function hookScanButton()
    local arl = _G.AckisRecipeList
    if scanHooked or type(arl) ~= "table" or type(arl.TRADE_SKILL_SHOW) ~= "function" then return end
    scanHooked = true
    hooksecurefunc(arl, "TRADE_SKILL_SHOW", liftScanButton)
end

-- Everything the two pages draw for this character's professions; the TGA sheets are what slow PCs stall on.
addon:RegisterTextureWarmup(function()
    if not (P.Module.applied and addon:IsModuleEnabled("professions")) or P.YieldsTo() then return nil end
    local files = {}
    local function add(name)
        local info = name and P.Atlas[name]
        if info then files[#files + 1] = info[1] end
    end
    for _, name in ipairs({ "bg-crafting", "bg-overview", "banner-left", "card-base", "rankbar-fill", "favorite",
                            "small-Cooking", "small-Fishing", "small-FirstAid" }) do
        add(name)
    end
    for key in pairs(P.Professions.KnownKeys()) do
        add(Art.CardDrawing(key))
        add(Art.BannerDrawing(key))
        add(Art.Fill(key))
    end
    local edge = ForeverAtlas()["_ui-frame-metal-edgetop"]
    if edge then files[#files + 1] = edge[1] end
    return files
end)

hookScanButton()
-- AddonLoader can load ARL on the first TRADE_SKILL_SHOW, long after us.
if not scanHooked then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self)
        hookScanButton()
        if scanHooked then self:UnregisterEvent("ADDON_LOADED") end
    end)
end
