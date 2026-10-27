-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local pairs, type, time = pairs, type, time

-- Clique hangs its window and binding overlays on Blizzard's book; this mirrors both on ours.
local DOCK_GAP = 40

local overlays = {}
local painted = setmetatable({}, { __mode = "k" })

-- Only Clique's public calls; if one goes missing Clique still works on its own through /clique.
local function api()
    local core, config = _G.Clique, _G.CliqueConfig
    if core and config and config.page1 and type(core.AddBinding) == "function"
        and type(core.GetCapturedKey) == "function" then
        return core, config
    end
end

local function eligible(entry)
    return entry ~= nil and not entry.grey and not entry.passive
end

local function bindingMode()
    local _, config = api()
    return config ~= nil and Book.IsOpen() and config.page1:IsVisible() ~= nil
end

-- Same steps as Clique's own overlay on SpellButton1-12 (CliqueConfig:Spellbook_OnBinding).
local function bind(overlay, key)
    local core, config = api()
    if not core then return end
    if key == "ESCAPE" then
        HideUIPanel(config)
        return
    end
    local entry = overlay:GetParent().entry
    local captured = eligible(entry) and core:GetCapturedKey(key)
    if not captured then return end
    local sub = entry.sub ~= "" and entry.sub or nil
    core:AddBinding({ key = captured, type = "spell", spell = entry.name, spellSubName = sub, icon = entry.icon })
    if type(config.UpdateList) == "function" then config:UpdateList() end
end

local function overlayEnter(self)
    Book.CardEnter(self:GetParent())
    self:EnableKeyboard(true)
end

local function overlayLeave(self)
    Book.CardLeave(self:GetParent())
    self:EnableKeyboard(false)
end

local function overlayWheel(self, delta)
    local now = time()
    if now == self.lastWheel then return end
    self.lastWheel = now
    bind(self, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function overlayFor(card)
    local overlay = overlays[card]
    if overlay then return overlay end
    overlay = CreateFrame("Button", nil, card)
    overlay:Hide()
    overlay:SetAllPoints(card)
    overlay:RegisterForClicks("AnyDown")
    overlay:EnableMouseWheel(true)
    overlay:SetScript("OnEnter", overlayEnter)
    overlay:SetScript("OnLeave", overlayLeave)
    overlay:SetScript("OnHide", function(self) self:EnableKeyboard(false) end)
    overlay:SetScript("OnClick", function(self, button) bind(self, button) end)
    overlay:SetScript("OnKeyDown", function(self, key) bind(self, key) end)
    overlay:SetScript("OnMouseWheel", overlayWheel)
    overlays[card] = overlay
    return overlay
end

local function syncCard(card, active)
    painted[card] = true
    if active and eligible(card.entry) then
        local overlay = overlayFor(card)
        -- Above the secure slot over the icon, which would otherwise cast instead of binding.
        overlay:SetFrameLevel(Book.Level("catcher"))
        overlay:Show()
    elseif overlays[card] then
        overlays[card]:Hide()
    end
end

local function refresh()
    local active = bindingMode()
    for card in pairs(painted) do
        syncCard(card, active)
    end
    local _, config = api()
    local alert = config and config.bindAlert
    if not alert then return end
    if active then
        -- Clique's XML pins it above SpellButton1, inside Blizzard's hidden book.
        alert:ClearAllPoints()
        alert:SetPoint("BOTTOMLEFT", config, "TOPLEFT", 20, 16)
        alert:Show()
    elseif not SpellButton1:IsVisible() then
        alert:Hide()
    end
end

local function placeDocked(config)
    local root = Book.root
    config:ClearAllPoints()
    local left, right, screen = root:GetLeft(), root:GetRight(), UIParent:GetRight()
    local roomRight = (right and screen) and screen - right or math.huge
    if roomRight < config:GetWidth() + DOCK_GAP and left and left > roomRight then
        config:SetPoint("RIGHT", root, "LEFT", -8, 0)
    else
        config:SetPoint("LEFT", root, "RIGHT", DOCK_GAP, 0)
    end
end

-- Shown with Show() like Clique's ShowWithSpellBook, never as a managed panel the panel manager would move.
local function dock()
    local _, config = api()
    if not config or Book.Locked() or not addon:IsModuleEnabled("spellbook") then return end
    if config:GetParent() == Book.root and config:IsShown() then return end
    HideUIPanel(config)
    config._duiOwnParent = config._duiOwnParent or config:GetParent()
    config:SetParent(Book.root)
    -- The wide book can leave no room either side, so stay on screen and draw over its edge.
    config:SetClampedToScreen(true)
    config:SetFrameStrata("DIALOG")
    config._duiDocked = true
    placeDocked(config)
    config:Show()
end

-- The book gets its place when it opens (after a "Bind spell" dock) and its width on compact/wide.
local function redock()
    local _, config = api()
    if config and config:GetParent() == Book.root then placeDocked(config) end
end

local function bookShown()
    redock()
    refresh()
end

local function placeSideTab(tab)
    if tab:GetParent() ~= Book.root then return end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", Book.root, "TOPRIGHT", 4, -65)
    tab:SetFrameLevel(Book.Level("catcher"))
end

function Book.AdoptSideTab()
    local borrowed = IsAddOnLoaded("Clique") and _G.CliqueSpellTab
    if not borrowed then return end
    borrowed._duiOwnParent = borrowed._duiOwnParent or borrowed:GetParent()
    borrowed:SetParent(Book.root)
    if not borrowed._duiPlaced then
        borrowed._duiPlaced = true
        -- Its own OnShow pins it back beside Blizzard's skill line tabs.
        borrowed:HookScript("OnShow", placeSideTab)
    end
    placeSideTab(borrowed)
    borrowed:Show()
end

-- The book turned off: Clique's tab and window go back to the parents Clique gave them.
function Book.ReleaseClique()
    local tab = _G.CliqueSpellTab
    if tab and tab._duiOwnParent and tab:GetParent() == Book.root then
        tab:SetParent(tab._duiOwnParent)
    end
    local _, config = api()
    if config and config._duiOwnParent and config:GetParent() == Book.root then
        config:Hide()
        config:SetParent(config._duiOwnParent)
        config._duiDocked = nil
    end
end

function Book.InstallClique()
    local _, config = api()
    if not config or Book.cliqueInstalled then return end
    Book.cliqueInstalled = true

    hooksecurefunc(Book, "PaintCard", function(card) syncCard(card, bindingMode()) end)
    hooksecurefunc(Book, "ApplyScale", redock)
    config.page1:HookScript("OnShow", refresh)
    config.page1:HookScript("OnHide", refresh)
    config:HookScript("OnShow", refresh)
    config:HookScript("OnHide", function(self)
        if not self._duiDocked then return end
        self._duiDocked = nil
        self:SetFrameStrata("MEDIUM")
    end)
    Book.root:HookScript("OnShow", bookShown)
    Book.root:HookScript("OnHide", refresh)

    -- "Bind spell" opens Blizzard's book, which ours replaces a frame later, taking Clique's window with it.
    if type(config.ShowWithSpellBook) == "function" then
        hooksecurefunc(config, "ShowWithSpellBook", dock)
    end
    -- With no Blizzard book open, the side tab shows the window loose on the left.
    if type(config.SpellTab_OnClick) == "function" then
        hooksecurefunc(config, "SpellTab_OnClick", function()
            if Book.IsOpen() and config:IsShown() then dock() end
        end)
    end
end
