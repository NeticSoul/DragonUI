local addon = select(2, ...)
local compatibility = {}
addon.compatibility = compatibility
local L = addon.L

--[[
* DragonUI Compatibility Manager
* 
* Modular system to detect specific addons and apply custom behaviors.
* Each addon can have its own detection and behavior logic.
]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = {
    warningDelay = 0.5,
    scanDelay = 0.1,
    d3d9ExWarningDelay = 1.0
}

local ADDON_REGISTRY

-- ============================================================================
-- OPTIMIZED SYSTEMS
-- ============================================================================

-- Timer helper: delegates to centralized addon:After() (note: arg order is func, delay)
local function DelayedCall(func, delay)
    addon:After(delay, func)
end

-- Cache system for addon loading checks
local addonLoadCache = {}
local function IsAddonLoadedCached(addonName)
    if addonLoadCache[addonName] == nil then
        addonLoadCache[addonName] = IsAddOnLoaded(addonName)
    end
    return addonLoadCache[addonName]
end

local function ResolveRegistryKey(addonName)
    if not addonName then return nil end
    if ADDON_REGISTRY and ADDON_REGISTRY[addonName] then
        return addonName
    end

    local lowered = string.lower(addonName)
    if ADDON_REGISTRY and ADDON_REGISTRY[lowered] then
        return lowered
    end

    -- Compact raid frame addon can appear with different names/casing.
    if lowered == "compactraidframes" or lowered == "blizzard_compactraidframes" then
        return "compactraidframe"
    end

    return nil
end

local function IsRegistryAddonLoaded(addonName)
    if IsAddonLoadedCached(addonName) then
        return true
    end

    if addonName == "compactraidframe" then
        return IsAddonLoadedCached("compactraidframes")
            or IsAddonLoadedCached("CompactRaidFrame")
            or IsAddonLoadedCached("CompactRaidFrames")
            or IsAddonLoadedCached("Blizzard_CompactRaidFrames")
            or _G.CompactRaidFrameManager ~= nil
    end

    return false
end

-- ============================================================================
-- INTERFACE SETTINGS FIXER (UNIFIED BLIZZARD SETTINGS)
-- ============================================================================

local InterfaceSettingsFixer = {
    popupName = "DRAGONUI_INTERFACE_SETTINGS_FIXER",
    initialized = false,
    scanPending = false,
    popupVisible = false,
    applyingFixes = false,
    dismissedForSession = false,
    lastIssues = nil,
    settings = {
        {
            setting = "showPartyBackground",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Party/Arena Background"
        },
        {
            setting = "statusText",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        },
        {
            setting = "playerStatusText",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        },
        {
            setting = "petStatusText",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        },
        {
            setting = "partyStatusText",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        },
        {
            setting = "targetStatusText",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        },
        {
            setting = "statusTextPercentage",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        },
        {
            setting = "xpBarText",
            desiredValue = "0",
            type = "CVar",
            category = "conflict",
            displayName = "Default Status Text"
        }
    }
}

local function NormalizeSettingValue(value)
    if value == nil then return "" end
    return tostring(value):lower()
end

local function GetSettingValue(def)
    if def.type == "CVar" then
        return GetCVar(def.setting)
    elseif def.type == "API" and def.getter then
        return def.getter()
    end
    return nil
end

local function SetSettingValue(def, value)
    if def.type == "CVar" then
        SetCVar(def.setting, tostring(value))
    elseif def.type == "API" and def.setter then
        def.setter(value)
    end
end

local function IsSettingOutOfSpec(def)
    local currentValue = GetSettingValue(def)

    -- If a CVar is unavailable in this client/version, skip it.
    if def.type == "CVar" and (currentValue == nil or currentValue == "") then
        return false
    end

    return NormalizeSettingValue(currentValue) ~= NormalizeSettingValue(def.desiredValue)
end

local function GetOutOfSpecInterfaceSettings()
    local issues = {}
    for _, def in ipairs(InterfaceSettingsFixer.settings) do
        if IsSettingOutOfSpec(def) then
            table.insert(issues, def)
        end
    end
    return issues
end

local function ApplyInterfaceSettingsFixes(issues)
    InterfaceSettingsFixer.applyingFixes = true
    for _, def in ipairs(issues) do
        SetSettingValue(def, def.desiredValue)
    end

    -- Force immediate visual refresh where Blizzard normally reacts to CVar changes.
    if MainMenuBar_Update then
        MainMenuBar_Update()
    end
    if UpdateTextStatusBarText then
        UpdateTextStatusBarText()
    end

    InterfaceSettingsFixer.applyingFixes = false
end

local function BuildInterfaceSettingsIssueLines(issues)
    local seen = {}
    local lines = {}

    for _, def in ipairs(issues) do
        local key = def.category .. ":" .. (def.displayName or def.setting)
        if not seen[key] then
            seen[key] = true
            local categoryLabel
            if def.category == "conflict" then
                categoryLabel = L["Conflict"] or "Conflict"
            else
                categoryLabel = L["Recommended"] or "Recommended"
            end
            local displayName = L[def.displayName] or def.displayName or def.setting
            table.insert(lines, string.format("- %s: %s", categoryLabel, displayName))
        end
    end

    return table.concat(lines, "\n")
end

local function ShowInterfaceSettingsFixerPopup(issues)
    if InterfaceSettingsFixer.popupVisible then
        return
    end

    InterfaceSettingsFixer.lastIssues = issues

    if not StaticPopupDialogs[InterfaceSettingsFixer.popupName] then
        StaticPopupDialogs[InterfaceSettingsFixer.popupName] = {
            text = "",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                local activeIssues = InterfaceSettingsFixer.lastIssues or GetOutOfSpecInterfaceSettings()
                ApplyInterfaceSettingsFixes(activeIssues)
                InterfaceSettingsFixer.dismissedForSession = false
                InterfaceSettingsFixer.popupVisible = false
                ReloadUI()
            end,
            OnCancel = function()
                InterfaceSettingsFixer.dismissedForSession = true
                InterfaceSettingsFixer.popupVisible = false
            end,
            OnHide = function()
                InterfaceSettingsFixer.popupVisible = false
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
    end

    local issueLines = BuildInterfaceSettingsIssueLines(issues)
    local popupText = "|cFF00CCFFDragonUI|r\n\n" ..
        (L["Some interface settings are not configured optimally for DragonUI."] or "Some interface settings are not configured optimally for DragonUI.") ..
        "\n\n" ..
        (L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] or
        "This includes settings that conflict with DragonUI and settings recommended for the best visual experience.") ..
        "\n\n" ..
        (L["Affected settings:"] or "Affected settings:") .. "\n" ..
        issueLines ..
        "\n\n" ..
        (L["Do you want to fix them now?"] or "Do you want to fix them now?")

    StaticPopupDialogs[InterfaceSettingsFixer.popupName].text = popupText
    InterfaceSettingsFixer.popupVisible = true
    StaticPopup_Show(InterfaceSettingsFixer.popupName)
end

local function ScanAndPromptInterfaceSettingsFixer()
    if InterfaceSettingsFixer.applyingFixes then
        return
    end

    local issues = GetOutOfSpecInterfaceSettings()
    if #issues == 0 then
        InterfaceSettingsFixer.lastIssues = nil
        InterfaceSettingsFixer.dismissedForSession = false
        return
    end

    if InterfaceSettingsFixer.dismissedForSession then
        return
    end

    ShowInterfaceSettingsFixerPopup(issues)
end

local function ScheduleInterfaceSettingsScan(delay)
    if InterfaceSettingsFixer.scanPending then
        return
    end

    InterfaceSettingsFixer.scanPending = true
    DelayedCall(function()
        InterfaceSettingsFixer.scanPending = false
        ScanAndPromptInterfaceSettingsFixer()
    end, delay or 0.2)
end

local function IsFixerMonitoredCVar(cvarName)
    if not cvarName then return false end

    for _, def in ipairs(InterfaceSettingsFixer.settings) do
        if def.type == "CVar" and def.setting == cvarName then
            return true
        end
    end

    return false
end

-- ============================================================================
-- BEHAVIOR SYSTEM
-- ============================================================================

local behaviors = {}

-- Behavior: Show conflict warning with disable option
behaviors.ConflictWarning = function(addonName, addonInfo)
    local popupName = "DRAGONUI_CONFLICT_" .. string.upper(addonName)
    
    StaticPopupDialogs[popupName] = {
        text = "|cFFFF0000" .. L["DragonUI Conflict Warning"] .. "|r\n\n" ..
            string.format(L["The addon |cFFFFFF00%s|r conflicts with DragonUI."], addonInfo.name) .. "\n\n" ..
            "|cFFFF9999" .. L["Reason:"] .. "|r " .. addonInfo.reason .. "\n\n" ..
            L["Disable the conflicting addon now?"],
        button1 = L["Disable"],
        button2 = L["Keep Both"],
        OnAccept = function()
            DisableAddOn(addonName)
            ReloadUI()
        end,
        OnCancel = function() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3
    }
    
    StaticPopup_Show(popupName)
end

-- Behavior: UnitFrameLayers overlap resolution
behaviors.UnitFrameLayersCompatibility = function(addonName, addonInfo)
    local popupName = "DRAGONUI_UNITFRAMELAYERS_DETECTED"

    StaticPopupDialogs[popupName] = {
        text = "|cFFFF0000" .. L["DragonUI Conflict Warning"] .. "|r\n\n" ..
            "|cFFFFFF00" .. L["DragonUI - UnitFrameLayers Detected"] .. "|r\n\n" ..
            L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] .. "\n\n" ..
            L["Choose how to resolve this overlap:"] .. "\n" ..
            "- " .. L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] .. "\n" ..
            "- " .. L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."],
        button1 = L["Use DragonUI"],
        button2 = L["Disable Both"],
        OnAccept = function()
            DisableAddOn(addonName)

            addon.db = addon.db or {}
            addon.db.profile = addon.db.profile or {}
            addon.db.profile.modules = addon.db.profile.modules or {}
            addon.db.profile.modules.unitframe_layers = addon.db.profile.modules.unitframe_layers or {}
            addon.db.profile.modules.unitframe_layers.enabled = true

            ReloadUI()
        end,
        OnCancel = function()
            DisableAddOn(addonName)

            addon.db = addon.db or {}
            addon.db.profile = addon.db.profile or {}
            addon.db.profile.modules = addon.db.profile.modules or {}
            addon.db.profile.modules.unitframe_layers = addon.db.profile.modules.unitframe_layers or {}
            addon.db.profile.modules.unitframe_layers.enabled = false

            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3
    }

    StaticPopup_Show(popupName)
end

-- Behavior: CompactRaidFrame taint mitigation
behaviors.CompactRaidFrameFix = function(addonName, addonInfo)

    -- Simple cleanup system for party frames
    local function CleanPartyFrames()
        -- Non-destructive cleanup: only reconcile visibility and request refresh.
        for i = 1, 4 do
            local frameName = 'PartyMemberFrame' .. i
            local frame = _G[frameName]
            
            if frame then
                local unit = "party" .. i
                if UnitExists(unit) then
                    frame:Show()
                else
                    frame:Hide()
                end
            end
        end
        
        -- Simple refresh of party system
        DelayedCall(function()
            if _G.PartyMemberFrame_UpdateParty then
                _G.PartyMemberFrame_UpdateParty()
            end
            
            -- Apply DragonUI refresh if available
            if addon and addon.RefreshPartyFrames then
                addon.RefreshPartyFrames()
            end
        end, 0.2)
    end
    
    -- Show reload dialog for party frame creation issues
    local function ShowPartyReloadDialog()
        StaticPopupDialogs["DRAGONUI_PARTY_RELOAD"] = {
            text = "|cFFFFFF00" .. L["DragonUI - Party Frame Issue"] .. "|r\n\n" ..
                   L["You joined a party while in combat. Due to CompactRaidFrame taint issues, party frames may not display correctly."] ..
                   "\n\n|cFFFF9999" .. L["Reload the UI to fix party frame display?"] .. "|r",
            button1 = L["Reload UI"],
            button2 = L["Skip"],
            OnAccept = function()
                ReloadUI()
            end,
            OnCancel = function() end,
            timeout = 15, -- Auto-dismiss after 15 seconds
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
        
        StaticPopup_Show("DRAGONUI_PARTY_RELOAD")
    end

    -- Highest concurrent party size seen this session. CompactRaidFrame-style addons
    -- pool/reuse unit frames, so a new one is only ever forced into existence past this peak.
    local sessionMaxPartySize = GetNumPartyMembers()
    local lastKnownPartySize = sessionMaxPartySize
    local needsReload = false
    local needsClean = false

    local QUEUE_ID = "compatibility_compactraidframe_partyfix"

    local function ApplyPendingFix()
        if needsReload then
            ShowPartyReloadDialog()
        elseif needsClean then
            CleanPartyFrames()
        end
        needsReload = false
        needsClean = false
    end

    -- Event-driven (no polling): reacts to roster changes, comparing against the
    -- session peak instead of "was I solo when this fight started".
    local function OnPartyRosterChanged()
        local currentPartySize = GetNumPartyMembers()
        if currentPartySize == lastKnownPartySize then
            return
        end

        if currentPartySize > sessionMaxPartySize then
            if InCombatLockdown() then
                needsReload = true
            end
            sessionMaxPartySize = currentPartySize
        elseif InCombatLockdown() and (currentPartySize > 0 or lastKnownPartySize > 0) then
            needsClean = true
        end

        lastKnownPartySize = currentPartySize

        if InCombatLockdown() and (needsReload or needsClean) then
            addon.CombatQueue:Add(QUEUE_ID, ApplyPendingFix)
        end
    end

    compatibility.raidUpdateHandlers = compatibility.raidUpdateHandlers or {}
    compatibility.raidUpdateHandlers[addonName] = OnPartyRosterChanged
end


-- ============================================================================
-- ADDON REGISTRY
-- ============================================================================

-- Behavior: Carbonite minimap texture re-application
-- Carbonite resets minimap mask via SetMaskTexture during its ADDON_LOADED init,
-- and starts a repeating timer that calls SetBlipTexture every ~0.2s (node glow).
-- The SetBlipTexture override in minimap.lua blocks the timer calls, but we still
-- need to re-apply mask and POI textures after Carbonite's one-time init.
behaviors.CarboniteMinimapFix = function(addonName, addonInfo)
    -- Re-apply minimap textures after Carbonite finishes its init
    local elapsed = 0
    local reapplyFrame = CreateFrame("Frame")
    reapplyFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed > 1.5 then
            if addon.MinimapModule and addon.MinimapModule.applied
                and addon:IsModuleEnabled("minimap") then
                addon.MinimapModule.ReapplyMinimapTextures()
            end
            self:SetScript("OnUpdate", nil)
        end
    end)
end



-- ============================================================================
-- SEXYMAP COMPATIBILITY SYSTEM
-- ============================================================================

-- Behavior: SexyMap compatibility with 3-option popup
-- Detects SexyMap and offers:  Use SexyMap only / Use DragonUI only / Hybrid mode
behaviors.SexyMapCompatibility = function(addonName, addonInfo)
    -- Check if user has already made a choice (stored in DB)
    local minimapConfig = addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.minimap
    if not minimapConfig then return end

    local savedMode = minimapConfig.sexymap_mode

    -- If a mode was already chosen, apply it silently
    if savedMode then
        -- Delay application to ensure both addons have finished loading
        DelayedCall(function()
            behaviors._ApplySexyMapMode(savedMode)
        end, 1.0)
        return
    end

    -- Show the 3-option popup after a short delay (let both addons finish loading)
    DelayedCall(function()
        behaviors._ShowSexyMapPopup()
    end, 1.5)
end

-- Internal: Show the SexyMap compatibility popup with 3 options
behaviors._ShowSexyMapPopup = function()
    local popupName = "DRAGONUI_SEXYMAP_COMPAT"

    StaticPopupDialogs[popupName] = {
        text = "|cFF00CCFF" .. L["DragonUI - SexyMap Detected"] .. "|r\n\n" ..
            L["Which minimap do you want to use?"] .. "\n\n" ..
            "|cFFFFFF00" .. L["Hybrid"] .. " (" .. L["Recommended"] .. "):|r " .. L["SexyMap visuals with DragonUI editor and positioning."],
        button1 = L["SexyMap"],
        button2 = L["DragonUI"],
        button3 = L["Hybrid"],
        OnAccept = function()
            -- Button1: Use SexyMap Only
            behaviors._SaveSexyMapMode("sexymap")
            -- Pre-disable button skins so they don't conflict with SexyMap
            if addon.db and addon.db.profile and addon.db.profile.minimap then
                addon.db.profile.minimap.addon_button_skin = false
            end
            ReloadUI()
        end,
        OnCancel = function()
            -- Button2: Use DragonUI Only
            behaviors._SaveSexyMapMode("dragonui")
            DisableAddOn("SexyMap")
            ReloadUI()
        end,
        OnAlt = function()
            -- Button3: Hybrid Mode
            behaviors._SaveSexyMapMode("hybrid")
            -- Pre-disable button skins so they don't flash on reload
            if addon.db and addon.db.profile and addon.db.profile.minimap then
                addon.db.profile.minimap.addon_button_skin = false
            end
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
        showAlert = true
    }

    StaticPopup_Show(popupName)
end

-- Internal: Save the user's SexyMap mode choice to DB
behaviors._SaveSexyMapMode = function(mode)
    if addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.minimap then
        addon.db.profile.modules.minimap.sexymap_mode = mode
    end
end

-- Internal: Exempt MiniMapLFGFrame (Dungeon Eye) from SexyMap's hover-fade.
-- DragonUI's micromenu reparents MiniMapLFGFrame out of MinimapCluster into
-- its own moveable wrapper.  SexyMap's Buttons module registers it as a hover
-- button (fades to alpha 0 when mouse is not over the minimap), but since the
-- frame is no longer a child of MinimapCluster the mouse-over detection never
-- fires → the Dungeon Eye becomes permanently invisible.
-- Fix: Unregister it from SexyMap's hover system and hook SetAlpha as safety net.
behaviors._ExemptLFGFromSexyMapFade = function()
    if not MiniMapLFGFrame then return end
    -- Already applied?
    if MiniMapLFGFrame._DragonUI_SexyMapFadeExempt then return end
    MiniMapLFGFrame._DragonUI_SexyMapFadeExempt = true

    local sexyMapObj = _G["SexyMap"]
    -- Unregister from SexyMap's hover system
    if sexyMapObj and sexyMapObj.UnregisterHoverButton then
        sexyMapObj:UnregisterHoverButton(MiniMapLFGFrame)
    end
    -- Force full alpha
    MiniMapLFGFrame:SetAlpha(1)

    -- Safety net: hook SetAlpha to prevent SexyMap from fading it
    local origLFGSetAlpha = MiniMapLFGFrame.SetAlpha
    MiniMapLFGFrame.SetAlpha = function(self, alpha)
        -- If DragonUI has reparented the LFG frame out of the minimap
        -- hierarchy, block external fade attempts
        local parent = self:GetParent()
        if parent and parent ~= Minimap and parent ~= MinimapCluster
           and parent ~= MinimapBackdrop then
            origLFGSetAlpha(self, 1)
            return
        end
        origLFGSetAlpha(self, alpha)
    end
end

local function OnCollectorManagedButtonSetAlpha(self, alpha)
    if not self.DragonUI_ForceCollectorAlpha then
        return
    end

    if alpha and alpha >= 0.99 then
        return
    end

    local collector = _G.DragonUI_MinimapIconCollector
    if not collector or not collector.isOpen or self:GetParent() ~= collector then
        return
    end

    if self.DragonUI_CollectorAlphaFixing then
        return
    end

    self.DragonUI_CollectorAlphaFixing = true
    self:SetAlpha(1)
    self.DragonUI_CollectorAlphaFixing = nil
end

function compatibility:ApplySexyMapCollectorVisibilityFix(button, collector)
    if not button then
        return
    end

    if not self:IsSexyMapHybridMode() or not IsAddOnLoaded("SexyMap") then
        button.DragonUI_ForceCollectorAlpha = nil
        return
    end

    button.DragonUI_ForceCollectorAlpha = true

    local sexyMapObj = _G["SexyMap"]
    if sexyMapObj and sexyMapObj.UnregisterHoverButton then
        sexyMapObj:UnregisterHoverButton(button)
    end

    if not button.DragonUI_CollectorAlphaHooked then
        button.DragonUI_CollectorAlphaHooked = true
        hooksecurefunc(button, "SetAlpha", OnCollectorManagedButtonSetAlpha)
    end

    -- Force visible now so collector-open state does not depend on minimap hover.
    button:SetAlpha(1)
end

local function HideCalendarDayTextIfPresent()
    if not GameTimeFrame or not GameTimeFrame.GetFontString then
        return
    end

    local dayText = GameTimeFrame:GetFontString()
    if dayText then
        dayText:Hide()
    end
end

function compatibility:ApplySexyMapHybridCalendarFix()
    if not self:IsSexyMapHybridMode() or not IsAddOnLoaded("SexyMap") then
        return false
    end

    HideCalendarDayTextIfPresent()

    if GameTimeFrame and not GameTimeFrame.DragonUI_HybridCalendarTextHooked then
        GameTimeFrame.DragonUI_HybridCalendarTextHooked = true
        GameTimeFrame:HookScript("OnShow", HideCalendarDayTextIfPresent)
        GameTimeFrame:HookScript("OnEvent", HideCalendarDayTextIfPresent)
    end

    return true
end

local function UpdateCollectorToggleHoverVisibility()
    local button = compatibility._collectorToggleButton
    if not button then
        return
    end

    if not compatibility:IsSexyMapHybridMode() or not IsAddOnLoaded("SexyMap") then
        return
    end

    if Minimap and Minimap:IsMouseOver() then
        button:SetAlpha(1)
    else
        button:SetAlpha(0)
    end
end

function compatibility:ApplySexyMapCollectorToggleVisibilityFix(button)
    if not button then
        return false
    end

    if not self:IsSexyMapHybridMode() or not IsAddOnLoaded("SexyMap") then
        button.DragonUI_HybridCollectorHoverManaged = nil
        return false
    end

    button.DragonUI_HybridCollectorHoverManaged = true
    self._collectorToggleButton = button

    local sexyMapObj = _G["SexyMap"]
    if sexyMapObj and sexyMapObj.RegisterHoverButton then
        sexyMapObj:RegisterHoverButton(button)
        return true
    end

    if Minimap and not self._collectorToggleHoverHooksInstalled then
        self._collectorToggleHoverHooksInstalled = true
        Minimap:HookScript("OnEnter", UpdateCollectorToggleHoverVisibility)
        Minimap:HookScript("OnLeave", UpdateCollectorToggleHoverVisibility)
    end

    UpdateCollectorToggleHoverVisibility()
    return true
end

-- Internal: Apply the chosen SexyMap compatibility mode (called on login with saved choice)
behaviors._ApplySexyMapMode = function(mode)
    if mode == "hybrid_v2" then
        behaviors._SaveSexyMapMode("dragonui")
        mode = "dragonui"
    end

    if mode == "sexymap" then
        -- ================================================================
        -- USE SEXYMAP ONLY: DragonUI minimap module skips initialization
        -- when sexymap_mode == "sexymap" is in DB (checked in Initialize/Apply).
        -- Also disable addon button skin to avoid conflicts.
        -- Ensure SexyMap is enabled at addon level (may have been disabled
        -- by a previous "dragonui" mode switch).
        -- ================================================================
        EnableAddOn("SexyMap")
        if addon.db and addon.db.profile and addon.db.profile.minimap then
            addon.db.profile.minimap.addon_button_skin = false
        end
        -- Exempt LFG icon from SexyMap fade (DragonUI micromenu reparents it)
        DelayedCall(behaviors._ExemptLFGFromSexyMapFade, 2.0)

    elseif mode == "dragonui" then
        -- ================================================================
        -- USE DRAGONUI ONLY: Disable SexyMap addon so it won't load
        -- on next reload. Also disable if currently loaded.
        -- ================================================================
        DisableAddOn("SexyMap")

    elseif mode == "hybrid" then
        -- ================================================================
        -- HYBRID MODE: Mark module for hybrid behavior
        -- The minimap module reads sexymap_mode from DB during init
        -- and adjusts its ReplaceBlizzardFrame/RemoveBlizzardFrames logic.
        -- Ensure SexyMap is enabled at addon level (may have been disabled
        -- by a previous "dragonui" mode switch).
        -- ================================================================
        EnableAddOn("SexyMap")
        if addon.MinimapModule then
            addon.MinimapModule.sexyMapHybridMode = true
        end
        -- Apply runtime adjustments after minimap is initialized
        behaviors._WaitAndAdjustHybrid()
    end
end

-- Internal: Wait for minimap module to initialize then apply hybrid adjustments
behaviors._WaitAndAdjustHybrid = function()
    if addon.MinimapModule and addon.MinimapModule.applied then
        behaviors._AdjustForHybridMode()
    else
        local waitFrame = CreateFrame("Frame")
        local waitElapsed = 0
        waitFrame:SetScript("OnUpdate", function(self, dt)
            waitElapsed = waitElapsed + dt
            if waitElapsed > 3.0 then
                if addon.MinimapModule and addon.MinimapModule.applied then
                    behaviors._AdjustForHybridMode()
                end
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Internal: Adjust DragonUI minimap for hybrid coexistence with SexyMap
-- In hybrid mode:
--   SexyMap controls: borders, shapes/mask, fading, button orbit/visibility
--   DragonUI controls: positioning (editor mode), tracking icons, calendar,
--                      instance difficulty, POI textures, blip textures
behaviors._AdjustForHybridMode = function()
    -- 1. Hide DragonUI's custom border top (SexyMap hides the default and uses its own)
    if MinimapBorderTop then
        MinimapBorderTop:Hide()
    end

    -- 2. Allow SexyMap to control the minimap mask (shape)
    if addon.MinimapModule then
        addon.MinimapModule._allowExternalMask = true
    end

    -- 3. Allow SexyMap to control MinimapBorder visibility
    if addon.MinimapModule then
        addon.MinimapModule._allowExternalBorderControl = true
    end

    -- 4. Hide DragonUI's custom border frame and circle texture (conflicts with SexyMap borders)
    if addon.MinimapModule and addon.MinimapModule.borderFrame then
        addon.MinimapModule.borderFrame:Hide()
        addon.MinimapModule._borderHiddenForHybrid = true
    end
    if Minimap and Minimap.Circle then
        Minimap.Circle:Hide()
    end

    -- 5. Fix zone text: Let SexyMap's ZoneText module handle styling/position
    --    but preserve DragonUI's click-to-open-map functionality
    if MinimapZoneTextButton then
        local sexyMapObj = _G["SexyMap"]
        local sexyMapZoneText = sexyMapObj and sexyMapObj.GetModule and sexyMapObj:GetModule("ZoneText", true)
        if sexyMapZoneText then
            -- Re-apply click handler after SexyMap modifies the button
            MinimapZoneTextButton:EnableMouse(true)
            MinimapZoneTextButton:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    if WorldMapFrame:IsShown() then
                        HideUIPanel(WorldMapFrame)
                    else
                        ShowUIPanel(WorldMapFrame)
                    end
                end
            end)
        end
    end

    -- 6. Lock SexyMap's built-in drag so DragonUI editor handles positioning
    local sexyMapObj = _G["SexyMap"]
    if sexyMapObj then
        local sexyMapGeneral = sexyMapObj.GetModule and sexyMapObj:GetModule("General", true)
        if sexyMapGeneral then
            if sexyMapGeneral.db and sexyMapGeneral.db.profile then
                sexyMapGeneral.db.profile.lock = true
            end
            -- Also call SetLock directly to clear any drag scripts already set up
            if sexyMapGeneral.SetLock then
                sexyMapGeneral:SetLock(true)
            end
        end
    end

    -- 7. Let SexyMap's Borders, Fader, and Buttons modules work freely
    --    (no interference needed — they operate on Minimap children)

    -- 8. Restore SexyMap's mask if it was overridden by DragonUI
    if sexyMapObj then
        local sexyMapShapes = sexyMapObj.GetModule and sexyMapObj:GetModule("Shapes", true)
        if sexyMapShapes and sexyMapShapes.Apply then
            -- Let SexyMap re-apply its shape
            sexyMapShapes:Apply()
        end
    end

    -- 9. Disable DragonUI's addon button skin (conflicts with SexyMap button management)
    if addon.db and addon.db.profile and addon.db.profile.minimap then
        addon.db.profile.minimap.addon_button_skin = false
    end

    -- Also unskin any buttons already skinned this session so no second reload is needed
    if addon.MinimapModule and addon.MinimapModule.UnskinAllMinimapButtons then
        addon.MinimapModule.UnskinAllMinimapButtons()
    end

    -- 10. Re-trigger SexyMap's button hover/hide system so buttons hide properly after unskinning
    if sexyMapObj then
        local sexyMapButtons = sexyMapObj.GetModule and sexyMapObj:GetModule("Buttons", true)
        if sexyMapButtons and sexyMapButtons.Update then
            sexyMapButtons:Update()
        end
    end

    -- 11. Exempt LFG icon from SexyMap fade (shared with sexymap-only mode)
    behaviors._ExemptLFGFromSexyMapFade()

    -- 12. Hide calendar day text in hybrid (SexyMap icon already contains the day number)
    compatibility:ApplySexyMapHybridCalendarFix()

end

-- Public API: Check if hybrid mode is active
function compatibility:IsSexyMapHybridMode()
    if not addon.db or not addon.db.profile or not addon.db.profile.modules
        or not addon.db.profile.modules.minimap then
        return false
    end
    local mode = addon.db.profile.modules.minimap.sexymap_mode
    return mode == "hybrid"
end

-- Public API: Get current SexyMap mode
function compatibility:GetSexyMapMode()
    if not addon.db or not addon.db.profile or not addon.db.profile.modules
        or not addon.db.profile.modules.minimap then
        return nil
    end
    return addon.db.profile.modules.minimap.sexymap_mode
end

-- Public API: Reset SexyMap mode choice (will re-prompt on next login)
function compatibility:ResetSexyMapMode()
    if addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.minimap then
        addon.db.profile.modules.minimap.sexymap_mode = nil
    end
end

ADDON_REGISTRY = {
    ["unitframelayers"] = {
        name = "UnitFrameLayers",
        reason = L["Conflicts with DragonUI's custom unit frame textures and power bar system."],
        behavior = behaviors.UnitFrameLayersCompatibility,
        checkOnce = true
    },
    ["compactraidframe"] = {
        name = "CompactRaidFrame",
        reason = L["Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes."],
        behavior = behaviors.CompactRaidFrameFix,
        checkOnce = true,
        listenToRaidEvents = true -- Enable raid event monitoring
    },
    ["carbonite"] = {
        name = "Carbonite",
        reason = L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."],
        behavior = behaviors.CarboniteMinimapFix,
        checkOnce = true
    },
    ["sexymap"] = {
        name = "SexyMap",
        reason = L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."],
        behavior = behaviors.SexyMapCompatibility,
        checkOnce = true
    },
}

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

local state = {
    processedAddons = {},
    activeAddons = {},
    initialized = false,
    d3d9ExWarningShown = false,
    d3d9ExWarningFrame = nil
}

local function IsD3D9ExActive()
    local gxApi = GetCVar("gxApi")
    return gxApi and string.lower(gxApi) == "d3d9ex"
end

local function GetCompatibilityConfig()
    if not addon.db or not addon.db.profile then
        return nil
    end

    addon.db.profile.compatibility = addon.db.profile.compatibility or {}
    return addon.db.profile.compatibility
end

local function HasSeenD3D9ExWarning()
    local cfg = GetCompatibilityConfig()
    return cfg and cfg.d3d9ex_warning_seen == true
end

local function MarkD3D9ExWarningSeen()
    local cfg = GetCompatibilityConfig()
    if cfg then
        cfg.d3d9ex_warning_seen = true
    end
end

local function HideD3D9ExGryphons()
    if addon.db and addon.db.profile then
        addon.db.profile.style = addon.db.profile.style or {}
        addon.db.profile.style.gryphons = "none"
    end

    if addon.RefreshMainbars then
        addon.RefreshMainbars()
    elseif addon.UpdateGryphonStyle then
        addon.UpdateGryphonStyle()
    end

    if state.d3d9ExWarningFrame then
        state.d3d9ExWarningFrame:Hide()
    end
end

local function CreateD3D9ExWarningFrame()
    local frame = CreateFrame("Frame", "DragonUI_D3D9ExWarning", UIParent)
    frame:SetSize(580, 232)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
            left = 4,
            right = 4,
            top = 4,
            bottom = 4
        }
    })
    frame:SetBackdropColor(0.08, 0.06, 0.02, 0.96)
    frame:SetBackdropBorderColor(1, 0.82, 0.12, 1)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 54, -18)
    title:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.82, 0.12)
    title:SetText(L["DragonUI - D3D9Ex Warning"])

    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    message:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -52)
    message:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetText(
        L["DragonUI detected that your client is using D3D9Ex."] .. "\n" ..
        L["DragonUI's action bar system is not compatible with D3D9Ex."] .. "\n" ..
        L["Some DragonUI action bar textures will be missing while this mode is active."]
    )

    local configHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    configHeader:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -14)
    configHeader:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    configHeader:SetJustifyH("LEFT")
    configHeader:SetText(L["If you want to disable this mode, open WTF\\Config.wtf."])

    local oldHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    oldHeader:SetPoint("TOPLEFT", configHeader, "BOTTOMLEFT", 0, -8)
    oldHeader:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    oldHeader:SetJustifyH("LEFT")
    oldHeader:SetText(L["Delete this line:"])

    local oldLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    oldLine:SetPoint("TOPLEFT", oldHeader, "BOTTOMLEFT", 0, -4)
    oldLine:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    oldLine:SetJustifyH("LEFT")
    oldLine:SetText('|cFFFF6666SET gxApi "d3d9ex"|r')

    local newHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    newHeader:SetPoint("TOPLEFT", oldLine, "BOTTOMLEFT", 0, -8)
    newHeader:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    newHeader:SetJustifyH("LEFT")
    newHeader:SetText(L["Or replace it with:"])

    local newLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    newLine:SetPoint("TOPLEFT", newHeader, "BOTTOMLEFT", 0, -4)
    newLine:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    newLine:SetJustifyH("LEFT")
    newLine:SetText('|cFF66FF99SET gxApi "d3d9"|r')

    local hideGryphonsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    hideGryphonsButton:SetWidth(170)
    hideGryphonsButton:SetHeight(22)
    hideGryphonsButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 118, 16)
    hideGryphonsButton:SetText(L["Hide Gryphons"])
    hideGryphonsButton:SetScript("OnClick", HideD3D9ExGryphons)

    local acknowledgeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    acknowledgeButton:SetWidth(120)
    acknowledgeButton:SetHeight(22)
    acknowledgeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -118, 16)
    acknowledgeButton:SetText(L["Understood"])
    acknowledgeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    return frame
end

local function ShowD3D9ExWarning()
    if state.d3d9ExWarningShown or not IsD3D9ExActive() or HasSeenD3D9ExWarning() then
        return
    end

    state.d3d9ExWarningShown = true
    MarkD3D9ExWarningSeen()

    if not state.d3d9ExWarningFrame then
        state.d3d9ExWarningFrame = CreateD3D9ExWarningFrame()
    end

    state.d3d9ExWarningFrame:Show()
end

-- ============================================================================
-- EVENT SYSTEM (ADDON SPECIFIC)
-- ============================================================================

local activeEventFrames = {}

local function RegisterEventsForAddon(addonName, addonInfo)
    if not addonInfo.listenToRaidEvents then
        return
    end
    
    local eventFrame = CreateFrame("Frame", "DragonUI_Events_" .. addonName)
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if compatibility.raidUpdateHandlers and compatibility.raidUpdateHandlers[addonName] then
            compatibility.raidUpdateHandlers[addonName]()
        end
    end)
    
    activeEventFrames[addonName] = eventFrame
end

local function UnregisterEventsForAddon(addonName)
    if activeEventFrames[addonName] then
        activeEventFrames[addonName]:UnregisterAllEvents()
        activeEventFrames[addonName] = nil
    end
end

-- ============================================================================
-- CORE DETECTION & EXECUTION
-- ============================================================================

local function ValidateRegistryEntry(addonName, addonInfo)
    if not addonInfo.name or not addonInfo.reason or not addonInfo.behavior then
        return false
    end
    return true
end

local function ProcessAddon(addonName, addonInfo)
    if not ValidateRegistryEntry(addonName, addonInfo) then
        return
    end

    if addonInfo.checkOnce and state.processedAddons[addonName] then
        return
    end

    if addonInfo.checkOnce then
        state.processedAddons[addonName] = true
    end

    state.activeAddons[addonName] = addonInfo

    if addonInfo.behavior then
        addonInfo.behavior(addonName, addonInfo)
    end
    
    if addonInfo.listenToRaidEvents then
        RegisterEventsForAddon(addonName, addonInfo)
    end
end

local function ScanForRegisteredAddons()
    local foundAddons = {}
    
    for addonName, addonInfo in pairs(ADDON_REGISTRY) do
        if IsRegistryAddonLoaded(addonName) then
            foundAddons[addonName] = addonInfo
        end
    end
    
    return foundAddons
end

-- ============================================================================
-- MAIN EVENT SYSTEM
-- ============================================================================

local function InitializeEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("CVAR_UPDATE")

    eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
        if event == "ADDON_LOADED" then
            if loadedAddonName then
                addonLoadCache[loadedAddonName] = true
                addonLoadCache[string.lower(loadedAddonName)] = true
            end

            if loadedAddonName == "DragonUI" then
                -- Auto-reset SexyMap mode ONLY if SexyMap is completely uninstalled
                -- (not in the addon list at all). If it's just disabled, the user's
                -- chosen mode should persist so it applies when they re-enable it.
                local minimapCfg = addon.db and addon.db.profile and addon.db.profile.modules
                    and addon.db.profile.modules.minimap
                if minimapCfg and minimapCfg.sexymap_mode then
                    local sexyMapExists = false
                    for i = 1, GetNumAddOns() do
                        local name = GetAddOnInfo(i)
                        if name and name:lower() == "sexymap" then
                            sexyMapExists = true
                            break
                        end
                    end
                    if not sexyMapExists then
                        local oldMode = minimapCfg.sexymap_mode
                        minimapCfg.sexymap_mode = nil
                        -- Restore addon_button_skin if sexymap/hybrid mode had disabled it
                        if oldMode and oldMode ~= "dragonui" and addon.db.profile.minimap then
                            addon.db.profile.minimap.addon_button_skin = true
                        end
                    end
                end

                DelayedCall(function()
                    local foundAddons = ScanForRegisteredAddons()
                    for addonName, addonInfo in pairs(foundAddons) do
                        ProcessAddon(addonName, addonInfo)
                    end
                end, CONFIG.scanDelay)

            else
                local registryKey = ResolveRegistryKey(loadedAddonName)
                if registryKey then
                DelayedCall(function()
                        ProcessAddon(registryKey, ADDON_REGISTRY[registryKey])
                end, CONFIG.warningDelay)
                end
            end

        elseif event == "PLAYER_LOGIN" then
            state.initialized = true

            if not InterfaceSettingsFixer.initialized then
                InterfaceSettingsFixer.initialized = true
                ScheduleInterfaceSettingsScan(0.5)
            end

            DelayedCall(ShowD3D9ExWarning, CONFIG.d3d9ExWarningDelay)

        elseif event == "CVAR_UPDATE" then
            local cvarName = loadedAddonName
            if InterfaceSettingsFixer.initialized and IsFixerMonitoredCVar(cvarName) then
                ScheduleInterfaceSettingsScan(0.2)
            end
        end
    end)
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

local function InitializeCommands()
    SLASH_DRAGONUI_COMPAT1 = "/duicomp"
    
    SlashCmdList["DRAGONUI_COMPAT"] = function(msg)
        local cmd = msg and msg:lower():trim() or ""
        
        if cmd == "sexymap reset" then
            -- Reset SexyMap mode choice — will re-prompt on next login
            compatibility:ResetSexyMapMode()
            print("|cFF00CCFFDragonUI:|r " .. L["SexyMap compatibility mode has been reset. Reload UI to choose again."])
            return
        elseif cmd == "sexymap" then
            -- Show current SexyMap mode
            local mode = compatibility:GetSexyMapMode()
            if mode then
                print("|cFF00CCFFDragonUI:|r " .. string.format(L["Current SexyMap mode: |cFFFFFF00%s|r"], mode))
            else
                print("|cFF00CCFFDragonUI:|r " .. L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."])
            end
            return
        end
        
        -- Default: list loaded addons
        print("|cFF00CCFF" .. L["DragonUI Compatibility:"] .. "|r")
        print("  /duicomp sexymap - " .. L["Show current SexyMap compatibility mode"])
        print("  /duicomp sexymap reset - " .. L["Reset SexyMap mode choice (re-prompts on reload)"])
        print("")
        print(L["Loaded addons:"])
        for i = 1, GetNumAddOns() do
            local name = select(1, GetAddOnInfo(i))
            local title = GetAddOnMetadata(i, "Title") or "Unknown"
            local loaded = IsAddOnLoaded(i)
            if loaded then
                print("  - " .. title .. " |cFFFFFF00(" .. name .. ")|r")
            end
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function compatibility:RegisterAddon(addonName, addonInfo)
    if not ValidateRegistryEntry(addonName, addonInfo) then
        return false
    end
    
    ADDON_REGISTRY[addonName] = addonInfo
    
    if IsAddonLoadedCached(addonName) then
        ProcessAddon(addonName, addonInfo)
    end
    
    return true
end

function compatibility:UnregisterAddon(addonName)
    if ADDON_REGISTRY[addonName] then
        UnregisterEventsForAddon(addonName)
        state.activeAddons[addonName] = nil
        if compatibility.raidUpdateHandlers then
            compatibility.raidUpdateHandlers[addonName] = nil
        end
        
        ADDON_REGISTRY[addonName] = nil
        
        return true
    end
    return false
end

function compatibility:IsRegistered(addonName)
    return ADDON_REGISTRY[addonName] ~= nil
end

function compatibility:GetActiveAddons()
    return state.activeAddons
end

-- ============================================================================
-- CLEANUP FUNCTIONS
-- ============================================================================

local function Cleanup()
    for addonName, _ in pairs(activeEventFrames) do
        UnregisterEventsForAddon(addonName)
    end
    activeEventFrames = {}
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

InitializeEvents()
InitializeCommands()

-- ============================================================================
-- OPTIONS PANEL: SexyMap mode selector (registered from compatibility module
-- so it is visible regardless of minimap module state)
-- ============================================================================

local function IsSexyMapInstalled()
    -- Check if SexyMap exists in the addon list at all (enabled or disabled).
    -- We do NOT check enabled state because DragonUI itself disables SexyMap
    -- in "DragonUI Only" mode, and the user needs the options to switch back.
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if name and name:lower() == "sexymap" then
            return true
        end
    end
    return false
end

-- Cache result at load time (addon list doesn't change mid-session)
local sexyMapInstalled = IsSexyMapInstalled()
-- Expose on addon object so options panel can read it without re-detecting
addon._sexyMapInstalled = sexyMapInstalled

if sexyMapInstalled then
    local sexyMapOptions = {
        name = L["SexyMap Compatibility"],
        type = "group",
        order = 11, -- right after minimap
        args = {
            description = {
                type = 'description',
                name = L["Choose how DragonUI and SexyMap share the minimap."],
                order = 1
            },
            sexymap_mode = {
                type = 'select',
                name = L["Minimap Mode"],
                desc = L["Requires UI reload to apply."],
                values = {
                    ["sexymap"]  = L["SexyMap"],
                    ["dragonui"] = L["DragonUI"],
                    ["hybrid"]   = L["Hybrid"],
                },
                get = function()
                    local cfg = addon.db and addon.db.profile and addon.db.profile.modules
                        and addon.db.profile.modules.minimap
                    return cfg and cfg.sexymap_mode or "dragonui"
                end,
                set = function(_, val)
                    if addon.db and addon.db.profile and addon.db.profile.modules
                        and addon.db.profile.modules.minimap then
                        addon.db.profile.modules.minimap.sexymap_mode = val
                    end
                    StaticPopup_Show("DRAGONUI_SEXYMAP_MODE_RELOAD")
                end,
                order = 2,
            },
            mode_desc = {
                type = 'description',
                name = function()
                    return "\n|cFF888888" .. L["SexyMap"] .. ":|r " .. L["Uses SexyMap for the minimap."] .. "\n" ..
                           "|cFF888888" .. L["DragonUI"] .. ":|r " .. L["Uses DragonUI for the minimap."] .. "\n" ..
                              "|cFF888888" .. L["Hybrid"] .. ":|r " .. L["SexyMap visuals with DragonUI editor and positioning."]
                end,
                order = 3
            }
        }
    }

    StaticPopupDialogs["DRAGONUI_SEXYMAP_MODE_RELOAD"] = {
        text = "|cFF00CCFFDragonUI|r\n\n" .. L["Minimap mode changed. Reload UI to apply?"],
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    -- DragonUI_Options is LoadOnDemand — RegisterOptionsGroup may not exist yet.
    -- Queue the table; it gets picked up when the first RegisterOptionsGroup call runs.
    if addon.RegisterOptionsGroup then
        addon:RegisterOptionsGroup("sexymap", sexyMapOptions)
    else
        addon._pendingOptionsGroups = addon._pendingOptionsGroups or {}
        table.insert(addon._pendingOptionsGroups, { name = "sexymap", table = sexyMapOptions })
    end
end