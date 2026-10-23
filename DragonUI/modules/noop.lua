-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI - Noop Module
-- Disables unused Blizzard UI elements (gryphons, extra bars, etc.)
-- ============================================================================
local addon = select(2, ...)
local pairs, hooksecurefunc, InCombatLockdown = pairs, hooksecurefunc, InCombatLockdown

local XP_ART_STEMS = { "MainMenuXPBarTexture", "ReputationXPBarTexture", "ReputationWatchBarTexture" }

-- MainMenuBar is only faded, never hidden: MainMenuExpBar and ReputationWatchBar are its children.
local RETIRED_BAR_PARTS = {
    "MainMenuBar", "MainMenuBarArtFrame", "MainMenuBarOverlayFrame", "BonusActionBarFrame",
    "PetActionBarFrame", "ShapeshiftBarFrame", "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
}

local UNMANAGED_POSITION_KEYS = {
    "MultiBarLeft", "MultiBarRight", "MultiBarBottomLeft", "MultiBarBottomRight", "ShapeshiftBarFrame",
    "PossessBarFrame", "PETACTIONBAR_YPOS", "MultiCastActionBarFrame", "MULTICASTACTIONBAR_YPOS",
}

-- PossessBarFrame is a child of the faded MainMenuBar; Blizzard still shows and hides it, we only move it.
local function RehomePossessBar()
    local additional = addon.db.profile.additional
    local size, gap = additional.size or 31, additional.spacing or 6
    -- Left edge from the action bars, height from the pet row: one anchor can't take an axis from each.
    local corner = CreateFrame("Frame", nil, UIParent)
    corner:SetPoint("BOTTOMLEFT", ActionButton1, "BOTTOMLEFT")
    corner:SetPoint("TOPRIGHT", PetActionButton1, "TOPRIGHT")
    local holder = CreateFrame("Frame", "DragonUI_PossessBar", UIParent, "SecureHandlerStateTemplate")
    holder:SetSize(NUM_POSSESS_SLOTS * (size + gap) - gap, size)
    holder:SetPoint("TOPLEFT", corner, "TOPLEFT")
    -- It covers the first pet slots, which an Eye of Kilrogg leaves empty but still clickable.
    holder:SetFrameLevel(10)
    RegisterStateDriver(holder, "visibility", "[vehicleui][@vehicle,exists] hide; show")
    PossessBarFrame:SetParent(holder)
    PossessBarFrame:ClearAllPoints()
    PossessBarFrame:SetAllPoints(holder)
    PossessBarFrame:EnableMouse(false)
    for index = 1, NUM_POSSESS_SLOTS do
        local button = _G["PossessButton" .. index]
        button:ClearAllPoints()
        button:SetSize(size, size)
        button:SetFrameLevel(PossessBarFrame:GetFrameLevel() + 1)
        button:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", (index - 1) * (size + gap), 0)
        _G["PossessBackground" .. index]:SetAlpha(0)
    end
end

-- Skinned at login like the pet and stance rows: buttons.lua reads its colours after our ADDON_LOADED.
local function SkinPossessButtons()
    if _G.DragonUI_PossessBar and addon.StylePossessButtons then
        addon:SafeExecute("noop", "skin_possess", addon.StylePossessButtons)
    end
end

local function MuteTalentSpecSwap()
    local talentFrame = _G.PlayerTalentFrame
    if talentFrame then
        talentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    end
end

-- Module state tracking
local NoopModule = {
    initialized = false,
    applied = false,
    pendingApply = false
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("noop", NoopModule,
        addon.L["Hide Blizzard"],
        addon.L["Hide default Blizzard UI elements"])
end

-- Forward declare the apply function
local ApplyNoopChanges

-- Check if noop module is enabled
local function IsNoopEnabled()
    return addon.db and addon.db.profile and addon.db.profile.modules and 
           addon.db.profile.modules.noop and addon.db.profile.modules.noop.enabled
end

-- Actual implementation of noop changes (called when not in combat)
local function ApplyNoopChangesImpl()
    if InCombatLockdown() then return end
    for _, bar in pairs({ MainMenuBar, PetActionBarFrame, ShapeshiftBarFrame, BonusActionBarFrame }) do
        bar:EnableMouse(false)
    end
    local bonusBar = BonusActionBarFrame
    if bonusBar then
        bonusBar:SetScale(0.001)
    end
    -- PossessBar_OnEvent re-Shows the event-less bonus bar on page change; keybinds then land on it.
    if PossessBarFrame then
        PossessBarFrame:UnregisterEvent("ACTIONBAR_PAGE_CHANGED")
        RehomePossessBar()
        if IsLoggedIn() then
            SkinPossessButtons()
        end
    end
    
    -- Kill ExhaustionTick OnUpdate to prevent Blizzard nil crashes
    -- (GetXPExhaustion() returns nil for non-rested players, Blizzard code doesn't check)
    if ExhaustionTick then
        ExhaustionTick:Hide()
        ExhaustionTick:SetScript("OnUpdate", nil)
    end
    if ExhaustionLevelFillBar then
        ExhaustionLevelFillBar:Hide()
    end

    for _, stem in pairs(XP_ART_STEMS) do
        for segment = 0, 3 do
            local art = _G[stem .. segment]
            if art then
                art:SetTexture(nil)
            end
        end
    end

    for _, partName in ipairs(RETIRED_BAR_PARTS) do
        local part = _G[partName]
        if part then
            if part:GetObjectType() == "Frame" then
                part:UnregisterAllEvents()
                -- Its OnEvent is what switches on the Currency tab once a token is earned.
                if partName == "MainMenuBarArtFrame" then
                    part:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
                end
            end
            if partName ~= "MainMenuBar" then
                part:Hide()
            end
            part:SetAlpha(0)
        end
    end

    -- Its own events refresh the health/power bars DragonUI adopts, and MainMenuBar_ToVehicleArt re-Shows it.
    local vehicleModuleEnabled = addon.db and addon.db.profile
        and addon.db.profile.modules and addon.db.profile.modules.vehicle
        and addon.db.profile.modules.vehicle.enabled
    if vehicleModuleEnabled then
        VehicleMenuBar:UnregisterAllEvents()
        VehicleMenuBar:Hide()
        VehicleMenuBar:SetAlpha(0)
        VehicleMenuBar:EnableMouse(false)
    end
    
    -- Left in the table, UIParent_ManageFramePositions would drag these bars back to Blizzard's layout.
    local managed = UIPARENT_MANAGED_FRAME_POSITIONS
    if managed then
        for index = 1, #UNMANAGED_POSITION_KEYS do
            managed[UNMANAGED_POSITION_KEYS[index]] = nil
        end
    end

    if not PlayerTalentFrame then
        hooksecurefunc("TalentFrame_LoadUI", MuteTalentSpecSwap)
    end
    MuteTalentSpecSwap()
    
    NoopModule.applied = true
    NoopModule.pendingApply = false
end

-- Function to apply all noop changes (uses CombatQueue if in combat)
ApplyNoopChanges = function()
    -- Use central CombatQueue system (inspired by ElvUI)
    if InCombatLockdown() then
        NoopModule.pendingApply = true
        -- Queue the operation - will execute after combat ends
        if addon.CombatQueue then
            addon.CombatQueue:Add("noop_apply", function()
                if IsNoopEnabled() and NoopModule.pendingApply then
                    ApplyNoopChangesImpl()
                end
            end)
        end
        return false
    end
    
    ApplyNoopChangesImpl()
    return true
end

-- Initialize noop when addon and config are ready
local function InitializeNoop()
    if IsNoopEnabled() and not NoopModule.applied then
        ApplyNoopChanges()
    end
end

-- Event frame to handle initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Config should be available now
        NoopModule.initialized = true
        InitializeNoop()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Backup check in case config wasn't ready before
        InitializeNoop()
        SkinPossessButtons()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Store frame reference
NoopModule.eventFrame = initFrame

-- Public API for options
function addon.RefreshNoopSystem()
    if IsNoopEnabled() and not NoopModule.applied then
        ApplyNoopChanges()
        return
    end
    -- Blizzard chrome is demolished in place; only a reload can put it back.
    if NoopModule.applied and not IsNoopEnabled() then
        addon:Print(addon.L["Changing this setting requires a UI reload to apply correctly."])
    end
end