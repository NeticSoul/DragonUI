-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2,...);
local L = addon.L

-- ============================================================================
-- DragonUI - Game Menu Button Module
-- Injects a "DragonUI" button into the Escape menu that opens the config panel.
-- ============================================================================

local CreateFrame = CreateFrame
local HideUIPanel = HideUIPanel

local function GetGameMenuFrame()
    return _G and _G.GameMenuFrame
end

local dragonUIButton = nil
local buttonAdded = false
local heightAdjustedHost = nil
local hookInstalled = false
local updateHookInstalled = false
local onShowHookInstalled = false
local ascensionHookInstalled = false
local CreateDragonUIButton

local KNOWN_MENU_BUTTON_NAMES = {
    "EscapeMenuButton1", -- Ascension custom: Close
    "GameMenuButtonHelp",
    "GameMenuButtonWhatsNew",
    "GameMenuButtonStore",
    "GameMenuButtonOptions",
    "GameMenuButtonUIOptions",
    "GameMenuButtonKeybindings",
    "GameMenuButtonMacros",
    "GameMenuButtonAddons",
    "GameMenuButtonLogout",
    "GameMenuButtonQuit",
    "GameMenuButtonContinue"
}

local function IsDescendantOf(frame, parent)
    if not frame or not parent then return false end
    local current = frame
    while current do
        if current == parent then return true end
        current = current:GetParent()
    end
    return false
end

local function IsAscensionMenuEnvironment()
    if not _G then return false end

    if _G.EscapeMenu and _G.EscapeMenu.IsShown and _G.EscapeMenu:IsShown() then
        return true
    end

    if _G.EscapeMenuButton1 and _G.EscapeMenuButton1.IsShown and _G.EscapeMenuButton1:IsShown() then
        return true
    end

    return false
end

local function DetectCustomMenuHostFrame()
    if not IsAscensionMenuEnvironment() then return nil end

    -- Ascension custom menu host found via fstack.
    if _G.EscapeMenu and _G.EscapeMenu.IsShown and _G.EscapeMenu:IsShown() then
        return _G.EscapeMenu
    end

    if _G.EscapeMenuButton1 then
        local p = _G.EscapeMenuButton1:GetParent()
        if p then return p end
    end

    return nil
end

local function GetMenuHostFrame()
    if IsAscensionMenuEnvironment() then
        local custom = DetectCustomMenuHostFrame()
        if custom then return custom end
    end
    return GetGameMenuFrame()
end

local function IsOptionsAddonUnavailable()
    local reason = select(6, GetAddOnInfo("DragonUI_Options"))
    return reason == "MISSING" or reason == "DISABLED"
end

local function FindClassicInsertButton(menuHost)
    local candidates = {
        -- Prefer bottom-area insertion on classic clients.
        "GameMenuButtonContinue",
        "GameMenuButtonQuit",
        "GameMenuButtonLogout",
        "GameMenuButtonAddons",
        "GameMenuButtonMacros",
        "GameMenuButtonKeybindings",
        "GameMenuButtonUIOptions",
        "GameMenuButtonOptions"
    }

    for _, name in ipairs(candidates) do
        local btn = _G[name]
        if btn and btn.IsShown and btn:IsShown() and IsDescendantOf(btn, menuHost) then
            return btn
        end
    end
    return nil
end

local function FindBottomButtons(menuHost)
    local closeButton = _G["EscapeMenuButton1"] or _G["GameMenuButtonContinue"]
    if closeButton and menuHost and (not IsDescendantOf(closeButton, menuHost)) then
        closeButton = nil
    end

    local bottomMost = nil

    local function considerButton(btn)
        if not btn or btn == dragonUIButton then return end
        if not (btn.IsShown and btn:IsShown()) then return end
        if not (btn.IsObjectType and btn:IsObjectType("Button")) then return end
        if not IsDescendantOf(btn, menuHost) then return end

        -- Menu buttons in this frame are usually centered and wide.
        local hostCenterX = menuHost:GetCenter()
        local btnCenterX = btn:GetCenter()
        local btnWidth = btn:GetWidth() or 0
        if hostCenterX and btnCenterX and math.abs(btnCenterX - hostCenterX) > 80 then return end
        if btnWidth < 120 then return end

        if (not bottomMost) or ((btn:GetTop() or 0) < (bottomMost:GetTop() or 0)) then
            bottomMost = btn
        end
    end

    for _, name in ipairs(KNOWN_MENU_BUTTON_NAMES) do
        considerButton(_G[name])
    end

    return closeButton, bottomMost
end

-- Anchors the button below its reference and extends GameMenuFrame height once.
local function PositionDragonUIButton()
    local menuHost = GetMenuHostFrame()
    if not menuHost then return end
    if not dragonUIButton then return end

    dragonUIButton:SetParent(menuHost)
    dragonUIButton:SetFrameStrata(menuHost:GetFrameStrata())
    dragonUIButton:SetFrameLevel((menuHost:GetFrameLevel() or 1) + 20)
    if dragonUIButton._dragonHeads then
        dragonUIButton._dragonHeads:SetFrameLevel(dragonUIButton:GetFrameLevel() - 1)
    end

    if IsAscensionMenuEnvironment() then
        local closeButton, bottomMost = FindBottomButtons(menuHost)

        -- Ascension: keep DragonUI near the bottom around Close.
        if closeButton and closeButton:IsShown() then
            dragonUIButton:ClearAllPoints()
            dragonUIButton:SetPoint("BOTTOM", closeButton, "TOP", 0, -2)
        elseif bottomMost then
            dragonUIButton:ClearAllPoints()
            dragonUIButton:SetPoint("TOP", bottomMost, "BOTTOM", 0, -2)
        else
            dragonUIButton:ClearAllPoints()
            dragonUIButton:SetPoint("TOP", menuHost, "TOP", 0, -200)
        end
    else
        -- Classic clients: use original-style insertion anchor.
        local afterButton = FindClassicInsertButton(menuHost)
        dragonUIButton:ClearAllPoints()
        if afterButton then
            dragonUIButton:SetPoint("TOP", afterButton, "BOTTOM", 0, -2)
        else
            dragonUIButton:SetPoint("TOP", menuHost, "TOP", 0, -200)
        end
    end

    -- Grow the frame to accommodate the new button (runs exactly once).
    if heightAdjustedHost ~= menuHost then
        local buttonHeight = dragonUIButton:GetHeight() or 16
        local spacing = 1
        local currentHeight = menuHost:GetHeight()
        menuHost:SetHeight(currentHeight + buttonHeight + spacing)
        heightAdjustedHost = menuHost
    end

    -- Custom servers can reset frame height after layout updates.
    -- Ensure our injected button remains inside visible bounds.
    local frameBottom = menuHost:GetBottom()
    local buttonBottom = dragonUIButton:GetBottom()
    local bottomPadding = 10
    if frameBottom and buttonBottom and buttonBottom < (frameBottom + bottomPadding) then
        local deficit = (frameBottom + bottomPadding) - buttonBottom
        menuHost:SetHeight(menuHost:GetHeight() + deficit + 2)
    end
end

local function EnsureDragonUIButton()
    if IsOptionsAddonUnavailable() then
        if dragonUIButton then
            dragonUIButton:Hide()
        end
        return
    end

    if not buttonAdded then
        CreateDragonUIButton()
    elseif dragonUIButton then
        dragonUIButton:Show()
        PositionDragonUIButton()
    end
end

local function QueueEnsureAfterShow()
    -- Some custom clients re-skin/re-layout asynchronously after opening menu.
    -- Re-apply our button a few times shortly after show.
    local delays = { 0, 0.05, 0.15, 0.35, 0.7 }
    for _, delay in ipairs(delays) do
        addon:After(delay, function()
            local menuHost = GetMenuHostFrame()
            if menuHost and menuHost:IsShown() then
                EnsureDragonUIButton()
            end
        end)
    end
end

local function OpenDragonUIConfig()
    local menuHost = GetMenuHostFrame()
    if menuHost then
        HideUIPanel(menuHost)
    end

    if addon and addon.ToggleOptionsUI then
        addon:ToggleOptionsUI()
        return
    end

    -- ToggleOptionsUI not available yet; fall back to slash command.
    if SlashCmdList and SlashCmdList["DRAGONUI"] then
        SlashCmdList["DRAGONUI"]("config")
        return
    end

    addon:Error(L["Unable to open configuration"])
end

-- ============================================================================
-- BUTTON CREATION
-- ============================================================================

CreateDragonUIButton = function()
    if IsOptionsAddonUnavailable() then return true end

    if dragonUIButton or buttonAdded then return true end
    local menuHost = GetMenuHostFrame()
    if not menuHost then return false end

    -- GameMenuButtonTemplate sets the correct hit rect and default sizing.
    dragonUIButton = CreateFrame("Button", "DragonUIGameMenuButton", menuHost, "GameMenuButtonTemplate")
    dragonUIButton:SetWidth(140)
    dragonUIButton:SetText(L["DragonUI"])

    local forever = addon.ForeverUI
    if forever and forever.SkinButton then
        forever.SkinButton(dragonUIButton)
        addon.GameMenuDragons.Attach(dragonUIButton)
    end

    dragonUIButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then OpenDragonUIConfig() end
    end)

    PositionDragonUIButton()
    buttonAdded = true
    return true
end

local function InstallGameMenuHook()
    if hookInstalled then return true end
    local gameMenuFrame = GetGameMenuFrame()
    if not gameMenuFrame then return false end

    -- Hook Show instead of overriding it to avoid UI taint on the secure frame.
    hooksecurefunc(gameMenuFrame, "Show", function(self)
        EnsureDragonUIButton()
        QueueEnsureAfterShow()
    end)

    if not onShowHookInstalled then
        gameMenuFrame:HookScript("OnShow", function(self)
            EnsureDragonUIButton()
            QueueEnsureAfterShow()
        end)
        onShowHookInstalled = true
    end

    -- Many custom clients rebuild button layout every time the menu is shown.
    -- Hook the update routine so our button is re-shown/repositioned afterwards.
    if not updateHookInstalled and _G.GameMenuFrame_UpdateVisibleButtons then
        hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", function()
            EnsureDragonUIButton()
        end)
        updateHookInstalled = true
    end

    if ToggleGameMenu then
        hooksecurefunc("ToggleGameMenu", function()
            QueueEnsureAfterShow()
        end)
    end

    if IsAscensionMenuEnvironment() and (not ascensionHookInstalled) and _G.EscapeMenu and _G.EscapeMenu.HookScript then
        _G.EscapeMenu:HookScript("OnShow", function(self)
            EnsureDragonUIButton()
            QueueEnsureAfterShow()
        end)
        ascensionHookInstalled = true
    end

    hookInstalled = true
    return true
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Retries up to maxAttempts times in case GameMenuFrame isn't ready yet.
local function TryCreateButton()
    local attempts = 0
    local maxAttempts = 20

    local function attempt()
        attempts = attempts + 1
        InstallGameMenuHook()
        if CreateDragonUIButton() then
            QueueEnsureAfterShow()
            return
        end
        if attempts < maxAttempts then
            addon:After(0.5, attempt)
        end
    end

    attempt()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        InstallGameMenuHook()
        TryCreateButton()

    elseif event == "PLAYER_LOGIN" then
        -- Second attempt in case the first ran before GameMenuFrame existed.
        addon:After(1.0, function()
            InstallGameMenuHook()
            if not buttonAdded then TryCreateButton() end
        end)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

