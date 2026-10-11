-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local L = addon.L
local Art = P.Art
local Prof = P.Professions
local Catchers = Prof.Catchers
local Tabs = { buttons = {}, list = {}, pendingBind = false }
P.Tabs = Tabs

-- Forever sizes the tab to the art minus its 5 transparent rows (55 x 55) and centres the 55 x 60 art on it.
local TAB_SIZE, TAB_GAP, FIRST_Y = 55, 2, -60
-- Ten tabs fit at the default scale; servers allowing every profession need up to fourteen.
local FIT_TABS, MAX_TABS = 10, 14
-- What Forever's 50 x 50 icon (4 left, texcoords 1/32 in) shows through common-sidetab-mask: a 45 x 44 hole at (2, 5.5).
local ICON_X, ICON_Y, ICON_W, ICON_H = 2, -5.5, 45, 44
local ICON_L, ICON_R, ICON_T, ICON_B = 0.096875, 0.940625, 0.0875, 0.9125
-- One texel of that 50-texel icon: pressing moves the art under the mask, the hole stays.
local ICON_PRESS = 0.9375 / 50

local function isCurrent(prof)
    return prof and not P.currentLinked and Prof.EntryForLine(P.currentLine) == prof.entry
end

local function showTooltip(tab)
    GameTooltip:SetOwner(tab, "ANCHOR_RIGHT", -4, -4)
    GameTooltip:SetText(tab.label or "", 1, 1, 1)
    if tab.prof and not isCurrent(tab.prof) and InCombatLockdown() then
        GameTooltip:AddLine(L["Not available in combat"], 1, 0.125, 0.125)
    end
    GameTooltip:Show()
end

local function hideTooltip(tab)
    if GameTooltip:IsOwned(tab) then GameTooltip:Hide() end
end

local function setHover(tab, on)
    tab.hoverLock:SetShownCompat(on)
    if on then showTooltip(tab) else hideTooltip(tab) end
end

local function pressIcon(tab, down)
    local d = down and ICON_PRESS or 0
    tab.icon:SetTexCoord(ICON_L - d, ICON_R - d, ICON_T - d, ICON_B - d)
end

local function onClick(tab)
    if not tab.prof then
        P.Frame.ShowPage("overview")
    elseif isCurrent(tab.prof) then
        P.Frame.ShowPage("crafting")
    elseif InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1, 1)
    else
        Catchers.ArmFor(tab)
    end
end

local function centred(tab, layer, piece)
    local t = tab:CreateTexture(nil, layer)
    Art.Set(t, piece, true)
    t:SetPoint("CENTER", tab, "CENTER", 0, 0)
    return t
end

local function tabScale()
    local cfg = addon:GetModuleConfig("professions")
    local scale = cfg and tonumber(cfg.tabScale) or 0.9
    local n = Tabs.count or 0
    if n > FIT_TABS then
        scale = math.min(scale, (P.Frame.HEIGHT + FIRST_Y - 10) / (n * TAB_SIZE + (n - 1) * TAB_GAP))
    end
    return scale
end

-- A scaled frame reads its own offsets in its own units, so the first tab's drop is divided back out.
function Tabs.ApplyScale()
    local scale = tabScale()
    for _, tab in ipairs(Tabs.buttons) do tab:SetScale(scale) end
    local first = Tabs.buttons[1]
    if not first then return end
    first:ClearAllPoints()
    first:SetPoint("TOPLEFT", P.Frame.win, "TOPRIGHT", 0, FIRST_Y / scale)
end
addon.RefreshProfessionsTabScale = Tabs.ApplyScale

-- Layers as in LargeSideTabButtonTemplate; the border copy over the icon stands in for its mask.
local function newTab(i)
    local tab = CreateFrame("Button", nil, P.Frame.scaler)
    tab:SetSize(TAB_SIZE, TAB_SIZE)
    tab:SetID(i)
    tab:SetScale(tabScale())
    if i == 1 then
        tab:SetPoint("TOPLEFT", P.Frame.win, "TOPRIGHT", 0, FIRST_Y / tabScale())
    else
        tab:SetPoint("TOPLEFT", Tabs.buttons[i - 1], "BOTTOMLEFT", 0, -TAB_GAP)
    end
    centred(tab, "BACKGROUND", "sidetab")
    tab.icon = tab:CreateTexture(nil, "BORDER")
    tab.icon:SetSize(ICON_W, ICON_H)
    tab.icon:SetPoint("TOPLEFT", tab, "TOPLEFT", ICON_X, ICON_Y)
    pressIcon(tab, false)
    centred(tab, "ARTWORK", "sidetab-border")
    tab.selected = centred(tab, "OVERLAY", "sidetab-selected")
    tab.selected:Hide()
    centred(tab, "HIGHLIGHT", "sidetab-hover")
    -- The secure catcher above a tab takes the mouse, so it lights the tab through this copy.
    tab.hoverLock = centred(tab, "OVERLAY", "sidetab-hover")
    tab.hoverLock:Hide()
    tab:SetScript("OnClick", onClick)
    tab:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then pressIcon(self, true) end end)
    tab:SetScript("OnMouseUp", function(self) pressIcon(self, false) end)
    tab:SetScript("OnEnter", function(self)
        showTooltip(self)
        Catchers.ArmFor(self)
    end)
    tab:SetScript("OnLeave", hideTooltip)
    Tabs.buttons[i] = tab
    return tab
end

function Tabs.RefreshSelection()
    local overview = P.Frame.page == "overview"
    for _, tab in ipairs(Tabs.buttons) do
        local selected = tab:IsShown() and ((not tab.prof and overview) or (not overview and isCurrent(tab.prof)))
        tab.selected:SetShownCompat(selected)
    end
end

-- Catchers cast the profession spell; the open profession's tab keeps its own click (back to its page).
function Tabs.Bind()
    if InCombatLockdown() then
        Tabs.pendingBind = true
        return
    end
    Tabs.pendingBind = false
    for i, tab in ipairs(Tabs.buttons) do
        if tab:IsShown() and tab.prof and not isCurrent(tab.prof) then
            Catchers.Bind(i, tab, tab.prof.craftSpell, {
                onEnter = function() setHover(tab, true) end,
                onLeave = function() setHover(tab, false) end,
                onDown = function(_, button) if button == "LeftButton" then pressIcon(tab, true) end end,
                onUp = function() pressIcon(tab, false) end,
            })
        else
            Catchers.Unbind(i)
        end
    end
end

function Tabs.Rebuild()
    local list = Prof.Tabs(Prof.Discover())
    Tabs.list = list
    local entries = { { label = TRADE_SKILLS, icon = P.Frame.OVERVIEW_ICON } }
    for _, prof in ipairs(list) do
        if #entries >= MAX_TABS then break end
        entries[#entries + 1] = { label = prof.craftSpell, icon = prof.icon or Prof.IconFor(prof.entry), prof = prof }
    end
    Tabs.count = #entries
    for i, e in ipairs(entries) do
        local tab = Tabs.buttons[i] or newTab(i)
        tab.label, tab.prof = e.label, e.prof
        tab.icon:SetTexture(e.icon)
        tab:SetFrameLevel(P.Frame.TopLevel())
        tab:Show()
    end
    for i = #entries + 1, #Tabs.buttons do
        Tabs.buttons[i]:Hide()
        Tabs.buttons[i].prof = nil
        if not InCombatLockdown() then Catchers.Unbind(i) end
    end
    Tabs.ApplyScale()
    Tabs.RefreshSelection()
    Tabs.Bind()
end

P.On("Show", function()
    if not P.Frame.built then return end
    Tabs.Rebuild()
end)

P.On("Hide", function()
    if not InCombatLockdown() then Catchers.HideAll() end
end)

P.On("ProfessionChanged", function()
    if not P.Frame.built or not TradeSkillFrame:IsShown() then return end
    Tabs.RefreshSelection()
    Tabs.Bind()
end)

P.On("Page", function()
    if Tabs.buttons[1] then Tabs.RefreshSelection() end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if Tabs.pendingBind and P.active and TradeSkillFrame and TradeSkillFrame:IsShown() then Tabs.Bind() end
end)
