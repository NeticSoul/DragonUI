-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions

-- Lets another professions addon fill this window instead of opening its own: its recipe list,
-- the content of the recipe card, the craft controls, buttons beside the link button, whole
-- pages and side tabs. The window, its art, the rank bar, the profession tabs and the Overview
-- stay ours. With no provider nothing here changes the window.
--
-- Any addon (provider or not) can also add a standalone page and its side tab, with
-- standalone = true in the page's and the tab's spec: such a page is built with or without a
-- provider and stays when the provider goes (Archaeology's research window, for one).
--
-- provider = {
--     list(parent), card(parent), controls(parent), header(parent): optional builders returning a
--         frame; each replaces our piece in that spot (list column, card form, create strip,
--         right of the link button). Called again after an Unregister/Register: return the same frame.
--     title(): optional, the window title on the crafting page (nil keeps Blizzard's).
--     overview(): optional, the key of an added page that stands in for the Overview (nil keeps it):
--         the Overview's tab goes and the window opens on that page where it would open on the Overview.
--     onShow(), onHide(), onPage(page), onCraftingTab(prof), onScale(scale): optional notifications.
-- }
local Host = { VERSION = 3, pages = {}, tabs = {}, parked = {}, regions = {}, nextCatcher = 500 }
P.Host = Host

local function safe(fn, ...)
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        addon:Debug("professions host:", a)
        return nil
    end
    return a, b
end

local function notify(key, ...)
    local provider = Host.provider
    if provider then safe(provider[key], ...) end
end
Host.Notify = notify

-- Whether this window takes the professions: the module is on and no replacement addon has it.
function Host.Enabled()
    return addon:IsModuleEnabled("professions") and not P.YieldsTo()
end

-- Loads Blizzard's trade skill UI if need be and builds the window; true once it is up.
function Host.Ensure()
    return P.EnsureHost()
end

function Host.Active()
    return P.active and P.Frame.built and Host.provider ~= nil
end

-- The page the window opens on without a profession: the provider's stand-in, else the Overview.
function Host.OverviewPage()
    local provider = Host.provider
    local key = provider and provider.overview and safe(provider.overview)
    if key and Host.pages[key] and Host.pages[key].frame then return key end
    return "overview"
end

function Host.ToggleOverview()
    if P.Frame.ToggleOverview then P.Frame.ToggleOverview() end
end

-- Our pieces a provider replaces go to the hidden holder; where they were is kept for Unregister.
local function park(widget)
    if not widget or Host.parked[widget] then return end
    local points = {}
    for i = 1, widget:GetNumPoints() do points[i] = { widget:GetPoint(i) } end
    Host.parked[widget] = { parent = widget:GetParent(), points = points, width = widget:GetWidth(),
                            height = widget:GetHeight() }
    P.Frame.Retire(widget)
end

local function unparkAll()
    for widget, saved in pairs(Host.parked) do
        widget:SetParent(saved.parent)
        widget:ClearAllPoints()
        for _, point in ipairs(saved.points) do widget:SetPoint(unpack(point)) end
    end
    wipe(Host.parked)
end

-- A provider frame where a parked piece of ours was, at its size.
local function takePlace(frame, widget)
    local saved = Host.parked[widget]
    frame:ClearAllPoints()
    for _, point in ipairs(saved.points) do frame:SetPoint(unpack(point)) end
    frame:SetSize(saved.width, saved.height)
end

local CONTROLS = { "TradeSkillCreateButton", "TradeSkillCreateAllButton", "TradeSkillInputBox",
                   "TradeSkillDecrementButton", "TradeSkillIncrementButton" }

local function buildPage(key)
    local page = Host.pages[key]
    if not page or page.frame or not P.Frame.built then return end
    if not (Host.applied or page.spec.standalone) then return end
    local frame = safe(page.spec.build, P.Frame.scaler)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetAllPoints(P.Frame.win)
    frame:SetFrameLevel(P.Frame.craft:GetFrameLevel())
    frame:SetShownCompat(P.Frame.page == key)
    page.frame = frame
end

local function apply()
    local provider = Host.provider
    if not (provider and P.Frame.built) or Host.applied then return end
    Host.applied = true
    local craft, Details = P.Frame.craft, P.Details

    local list = provider.list and safe(provider.list, craft)
    if list then
        park(P.List.frame)
        takePlace(list, P.List.frame)
        list:Show()
        Host.regions.list = list
    end

    local card = provider.card and safe(provider.card, craft)
    if card then
        -- The form (with its favorite star) and the Track Recipe box; the card's art stays.
        park(TradeSkillDetailScrollFrame)
        if P.Track and P.Track.box then park(P.Track.box) end
        card:ClearAllPoints()
        card:SetAllPoints(Details.card)
        card:Show()
        Host.regions.card = card
    end

    local controls = provider.controls and safe(provider.controls, craft)
    if controls then
        for _, name in ipairs(CONTROLS) do park(_G[name]) end
        controls:ClearAllPoints()
        controls:SetPoint("TOPLEFT", Details.card, "BOTTOMLEFT", 0, -4)
        controls:SetPoint("BOTTOMRIGHT", P.Frame.win, "BOTTOMRIGHT", -9, 4)
        controls:Show()
        Host.regions.controls = controls
    end

    local header = provider.header and safe(provider.header, craft)
    if header then
        header:ClearAllPoints()
        header:SetPoint("LEFT", TradeSkillLinkButton, "RIGHT", 4, 0)
        header:Show()
        Host.regions.header = header
    end

    for key in pairs(Host.pages) do buildPage(key) end
    Host.RefreshTabs()
end

-- Takes the window over (see the top of this file). One provider at a time.
function Host.Register(provider)
    if Host.provider and Host.provider ~= provider then Host.Unregister(Host.provider) end
    Host.provider = provider
    apply()
    return true
end

-- Gives the window back: our pieces return, the provider's pages and tabs go (standalone ones stay).
function Host.Unregister(provider)
    if not provider or Host.provider ~= provider then return end
    local current = P.Frame.built and P.Frame.page
    local onOverview = current and current == Host.OverviewPage()
    for _, frame in pairs(Host.regions) do frame:Hide() end
    wipe(Host.regions)
    for key, page in pairs(Host.pages) do
        if not page.spec.standalone then
            if page.frame then page.frame:Hide() end
            Host.pages[key] = nil
        end
    end
    for i = #Host.tabs, 1, -1 do
        if not Host.tabs[i].standalone then table.remove(Host.tabs, i) end
    end
    unparkAll()
    Host.provider, Host.applied = nil, false
    if P.Frame.built then
        local stays = current and Host.IsPage(current)
        P.Frame.ShowPage(onOverview and "overview" or stays and current or "crafting")
        Host.RefreshTabs()
        if TradeSkillFrame:IsShown() then TradeSkillFrame_Update() end
    end
end

function Host.Replaces(region)
    return Host.regions[region] ~= nil
end

-- Pages -------------------------------------------------------------------------------------------

-- spec = { build(parent) -> frame over the whole window, title (string or function), portrait (path),
--          standalone = true for a page that doesn't belong to the provider }
function Host.AddPage(key, spec)
    local old = Host.pages[key]
    Host.pages[key] = { spec = spec, frame = old and old.frame }
    buildPage(key)
end

function Host.IsPage(key)
    return key ~= nil and Host.pages[key] ~= nil
end

-- Shows the page `key` names and hides the others; true when it is one of these pages.
function Host.ShowPage(key)
    for k, page in pairs(Host.pages) do
        if page.frame then page.frame:SetShownCompat(k == key) end
    end
    return Host.IsPage(key)
end

-- The page the window shows, and a way to switch it ("overview", "crafting" or an added page).
function Host.Page()
    return P.Frame.page
end

function Host.SetPage(key)
    if P.Frame.built then P.Frame.ShowPage(key) end
end

-- Opens the window on an added page, or switches it there; on that page already, closes it.
-- It opens with no trade skill behind it, as the Overview does.
function Host.TogglePage(key)
    if not (Host.IsPage(key) and P.EnsureHost()) then return false end
    local host = TradeSkillFrame
    if host:IsShown() then
        if P.Frame.page == key then HideUIPanel(host) else P.Frame.ShowPage(key) end
        return true
    end
    P.Frame.openOnPage = key
    ShowUIPanel(host)
    P.Frame.openOnPage = nil
    return true
end

function Host.PageHeader(key)
    local page = Host.pages[key]
    if not page then return nil end
    local title = page.spec.title
    if type(title) == "function" then title = safe(title) end
    return title, page.spec.portrait
end

-- Reads the title and portrait again (after the provider's own view changed).
function Host.RefreshHeader()
    if P.Frame.built then P.Frame.RefreshHeader() end
end

function Host.Title()
    local provider = Host.provider
    return provider and provider.title and safe(provider.title) or nil
end

-- Side tabs ---------------------------------------------------------------------------------------

-- spec = { key, label and icon (each a value or a function), after = "overview" | "professions",
--          page = key it shows | spell (name or function: the spell to cast first, nil when none),
--          onClick(spec) for a click that casts nothing, onDown() before a cast,
--          shown() and selected(page) optional, standalone = true to stay without the provider }
function Host.AddTab(spec)
    for i, tab in ipairs(Host.tabs) do
        if tab.key == spec.key then
            Host.tabs[i] = spec
            return
        end
    end
    Host.tabs[#Host.tabs + 1] = spec
end

local function value(field)
    if type(field) == "function" then return safe(field) end
    return field
end

function Host.TabsAt(where)
    local out = {}
    for _, spec in ipairs(Host.tabs) do
        if (spec.after or "professions") == where and (spec.shown == nil or safe(spec.shown)) then
            out[#out + 1] = spec
        end
    end
    return out
end

function Host.TabLabel(spec)
    return value(spec.label)
end

function Host.TabIcon(spec)
    return value(spec.icon)
end

function Host.TabSpell(spec)
    return value(spec.spell)
end

function Host.TabSelected(spec, page)
    if spec.page then return page == spec.page end
    return spec.selected and safe(spec.selected, page) and true or false
end

function Host.ClickTab(spec)
    if spec.page then P.Frame.ShowPage(spec.page) end
    safe(spec.onClick, spec)
    if P.Tabs then P.Tabs.RefreshSelection() end
end

function Host.RefreshTabs()
    if P.Tabs and P.Frame.built and TradeSkillFrame and TradeSkillFrame:IsShown() then P.Tabs.Rebuild() end
end

-- Objective tracker -------------------------------------------------------------------------------

function Host.TrackerEnabled()
    return addon:IsModuleEnabled("questtracker") and addon.ObjectiveTracker ~= nil
end

-- fn(blocks) appends blocks as Track's recipes are: { kind = "recipe", title, icon, lines = { { text } },
-- ref, menu(block), onClick(block, button), onEnter(block) }.
function Host.AddTrackerCollector(fn)
    local OT = addon.ObjectiveTracker
    if not (OT and OT.AddCollector) then return false end
    OT.AddCollector(function(blocks)
        if addon:IsModuleEnabled("professions") then safe(fn, blocks) end
    end)
    return true
end

function Host.RefreshTracker()
    local OT = addon.ObjectiveTracker
    if OT and OT.Refresh and addon:IsModuleEnabled("questtracker") then OT.Refresh() end
end

function Host.HighlightBlock(block, on)
    local OT = addon.ObjectiveTracker
    if OT and OT.Highlight then OT.Highlight(block, on) end
end

function Host.ClickBlock(block, button)
    local OT = addon.ObjectiveTracker
    if OT and OT.ClickBlock then OT.ClickBlock(block, button) end
end

-- Secure catchers for a provider's own buttons that cast a profession (see Prof.Catchers).
function Host.NewCatcherId()
    local id = Host.nextCatcher
    Host.nextCatcher = id + 1
    return id
end

Host.Catchers = P.Professions.Catchers

-- Standalone pages are built with the window; the provider's (and the rest) when it registers.
P.On("Built", function()
    for key in pairs(Host.pages) do buildPage(key) end
    apply()
end)
P.On("Show", function() notify("onShow") end)
P.On("Hide", function() notify("onHide") end)
P.On("Page", function(page) notify("onPage", page) end)
P.On("Scale", function(scale) notify("onScale", scale) end)
