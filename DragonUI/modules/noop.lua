-- ============================================================================
-- DragonUI - Noop Module
-- Disables unused Blizzard UI elements (gryphons, extra bars, etc.)
-- ============================================================================
local addon = select(2,...);
local pairs = pairs;
local hooksecurefunc = hooksecurefunc;
local InCombatLockdown = InCombatLockdown;

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
    -- Phase 3D: Defensive combat guard — secure frame operations must not run in combat
    if InCombatLockdown() then return end
    MainMenuBar:EnableMouse(false)
    PetActionBarFrame:EnableMouse(false)
    ShapeshiftBarFrame:EnableMouse(false)
    if BonusActionBarFrame then
        BonusActionBarFrame:EnableMouse(false)
        BonusActionBarFrame:SetScale(0.001)
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

    local elements_texture = {
        MainMenuXPBarTexture0,
        MainMenuXPBarTexture1,
        MainMenuXPBarTexture2,
        MainMenuXPBarTexture3,
        ReputationXPBarTexture0,
        ReputationXPBarTexture1,
        ReputationXPBarTexture2,
        ReputationXPBarTexture3,
        ReputationWatchBarTexture0,
        ReputationWatchBarTexture1,
        ReputationWatchBarTexture2,
        ReputationWatchBarTexture3,
    };for _,tex in pairs(elements_texture) do
        tex:SetTexture(nil)
    end;

    local elements = {
        MainMenuBar,
        MainMenuBarArtFrame,
        MainMenuBarOverlayFrame,
        -- VehicleMenuBar,  -- RetailUI pattern: handled separately below (keep events alive)
        -- VehicleMenuBarArtFrame,
        BonusActionBarFrame,
        PetActionBarFrame,
        ShapeshiftBarFrame,
        ShapeshiftBarLeft,
        ShapeshiftBarMiddle,
        ShapeshiftBarRight,
    };for _,element in pairs(elements) do
        if element:GetObjectType() == 'Frame' then
            element:UnregisterAllEvents()
            if element == MainMenuBarArtFrame then
                element:RegisterEvent('CURRENCY_DISPLAY_UPDATE');
            end
        end
        if element ~= MainMenuBar then
            element:Hide()
        end
        element:SetAlpha(0)
    end
    elements = nil
    
    -- VehicleMenuBar handling depends on whether the vehicle module is enabled.
    -- When enabled, DragonUI's vehicle module provides its own UI, so we KILL
    -- VehicleMenuBar completely. Keeping its events alive causes Blizzard's
    -- vehicle transition code (MainMenuBar_ToVehicleArt etc.) to interfere by
    -- reparenting VehicleMenuBarActionButtons and repositioning frames —
    -- this is the root cause of vehicle UI not showing. Matches the
    -- pretty_actionbar pattern which also kills VehicleMenuBar.
    local vehicleModuleEnabled = addon.db and addon.db.profile
        and addon.db.profile.modules and addon.db.profile.modules.vehicle
        and addon.db.profile.modules.vehicle.enabled
    if vehicleModuleEnabled then
        VehicleMenuBar:UnregisterAllEvents()
        VehicleMenuBar:Hide()
        VehicleMenuBar:SetAlpha(0)
        VehicleMenuBar:EnableMouse(false)
    else
        -- Vehicle module disabled — keep VehicleMenuBar fully functional
        -- so Blizzard's native vehicle transitions display correctly.
    end
    
    local uiManagedFrames = {
        'MultiBarLeft',
        'MultiBarRight',
        'MultiBarBottomLeft',
        'MultiBarBottomRight',
        'ShapeshiftBarFrame',
        'PETACTIONBAR_YPOS',
        'MultiCastActionBarFrame',
        'MULTICASTACTIONBAR_YPOS',
    }
    local UIPARENT_MANAGED_FRAME_POSITIONS = UIPARENT_MANAGED_FRAME_POSITIONS;
    for _, frame in pairs(uiManagedFrames) do
        UIPARENT_MANAGED_FRAME_POSITIONS[frame] = nil
    end
    uiManagedFrames = nil

    -- Prevent Blizzard from repositioning the chat dock when bar layout
    -- changes.  DragonUI manages all bottom bars independently, so the
    -- Blizzard bottomOffset calculation is meaningless and would move the
    -- chat frame every time the dual-bar offset changes.
    if FCF_UpdateDockPosition then
        FCF_UpdateDockPosition = function() end
    end

    if PlayerTalentFrame then
        PlayerTalentFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
    else
        hooksecurefunc('TalentFrame_LoadUI', function()
            PlayerTalentFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
        end)
    end
    
    NoopModule.applied = true
    NoopModule.pendingApply = false
end

-- Function to apply all noop changes (uses CombatQueue if in combat)
ApplyNoopChanges = function()
    -- Use central CombatQueue system (ElvUI pattern)
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