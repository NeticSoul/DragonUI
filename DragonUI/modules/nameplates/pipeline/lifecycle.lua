local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates lifecycle: hooks, show/hide reset, scan.

NP.lifecycle = NP.lifecycle or {}

-- Per-plate visual invalidation

function NP.lifecycle.InvalidatePlateVisuals(plateData, clearGuid)
    if not plateData then return end
    plateData._lastThreatStatus = nil
    plateData._lastThreatCombat = nil
    if clearGuid then
        NP.state.ClearPlateGUID(plateData)
    end
    NP.state.HidePlateDebuffs(plateData)
    if NP.widgets then
        NP.widgets.Hide("ThreatGlow", plateData)
        NP.widgets.Hide("TargetHighlight", plateData)
        NP.widgets.Hide("Combo", plateData)
        NP.widgets.Hide("RaidMarker", plateData)
        NP.widgets.Hide("Elite", plateData)
        NP.widgets.Hide("Totem", plateData)
        NP.widgets.Hide("Quest", plateData)
    end
    if NP.castbar then
        NP.castbar.ResetPlateCastBar(plateData)
        if plateData._castShieldSnapFrame then
            plateData._castShieldSnapFrame:SetScript("OnUpdate", nil)
            plateData._castShieldSnapFrame:Hide()
            plateData._castShieldSnapFrame = nil
        end
        if NP.castbar.PartyRaidCastTracker and NP.castbar.PartyRaidCastTracker.HideBar then
            NP.castbar.PartyRaidCastTracker:HideBar(plateData)
        end
    end
end

-- PrepareNameplate: full reset on every show

function NP.lifecycle.PrepareNameplate(plateData)
    -- Recycled frames must not inherit prior occupant state.
    local freshName = NP.discovery.GetPlateName(plateData)
    -- A recycled frame can silently get a new occupant; drop the stale GUID first.
    if freshName and plateData._lastKnownOccupantName and freshName ~= plateData._lastKnownOccupantName then
        NP.state.ClearPlateGUID(plateData)
    end
    if freshName then
        plateData._lastKnownOccupantName = freshName
    end
    plateData.plateName = freshName
    plateData._petCloneSnapshot = nil
    NP.castbar.NotePlateNameForPetSnapshot(plateData, plateData.plateName)
    plateData._castIdentityName = nil
    plateData._debuffIdentityName = nil
    plateData._eliteIdentityName = nil
    plateData._plateClassification = nil
    plateData._tokenProbeAt = nil
    plateData.plateLevel = nil
    plateData._plateLevelName = nil
    plateData._subtitleText = nil
    plateData._pvpTitleName = nil
    plateData._questScan = nil
    plateData._questPersist = nil
    plateData._questElite = nil
    plateData._headlineClass = nil
    plateData._friendlyHealthClass = nil
    plateData._afkState = nil
    plateData.namePlateUnitToken = nil
    plateData.unitToken = nil
    if plateData.plate then
        plateData.plate.namePlateUnitToken = nil
    end
    local now = GetTime and GetTime() or 0
    plateData._shownAt = now
    plateData._levelSettleAt = now + (NP.const and NP.const.LEVEL_TEXT_SETTLE or 0.15)
    plateData._lastDirectHover = nil
    plateData._layoutSig = nil
    plateData._lastAppliedVisualAlpha = nil
    -- Reset rendering-guard caches so a recycled plate doesn't inherit stale values.
    plateData._styledChromeCfgRev = nil
    plateData._styledChromeCombo = nil
    plateData._styledChromeHeadline = nil
    plateData._styledChromeReaction = nil
    plateData._nameCenteredWidth = nil
    plateData._nameTextLast = nil
    plateData._nameTextR = nil
    plateData._nameTextG = nil
    plateData._nameTextB = nil
    if NP.gather and NP.gather.InvalidatePlateGates then
        NP.gather.InvalidatePlateGates(plateData)
    end

    -- Fresh native bar color (reaction source).
    NP.native_style.CaptureBarColor(plateData)
    NP.native_style.NoteNativePlateClassification(plateData)

    -- Clear visuals from previous occupant.
    NP.lifecycle.InvalidatePlateVisuals(plateData, false)
end

-- Hooks (once per Blizzard frame)

function NP.lifecycle.SetupPlateHooks(plateData)
    if plateData.hooksDone then return end
    plateData.hooksDone = true

    local plate = plateData.plate
    local healthBar = plateData.healthBar

    -- One HookScript dispatcher per plate; plateData replaced only on restore/rediscover.
    local hookState = plate and plate._dragonUINameplateHookState
    if hookState then
        hookState.plateData = plateData
        return
    end
    hookState = { plateData = plateData }
    if plate then
        plate._dragonUINameplateHookState = hookState
    end

    local function CurrentPlateData()
        return hookState.plateData
    end

    if healthBar and healthBar.HookScript then
        healthBar:HookScript("OnValueChanged", function(_, val)
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if not current then return end
            NP.native_style.NeutralizeStatusBarVisual(healthBar)
            NP.native_style.CaptureBarColor(current)
            NP.gather.SyncHealth(current, val)
            NP.widgets.Sync("ThreatGlow", current)
        end)
        healthBar:HookScript("OnShow", function()
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if not current then return end
            NP.native_style.NeutralizeStatusBarVisual(healthBar)
            NP.lifecycle.OnShowNameplate(current, "healthbar_show")
        end)
        healthBar:HookScript("OnHide", function()
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if current then NP.lifecycle.OnHideNameplate(current, "healthbar_hide") end
        end)
    end

    local castBar = plateData.castBar
    if castBar and castBar.HookScript then
        castBar:HookScript("OnShow", function()
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if current then NP.castbar.OnNativeCastShown(current) end
        end)
        castBar:HookScript("OnHide", function()
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if current then NP.castbar.OnNativeCastHidden(current) end
        end)
        castBar:HookScript("OnValueChanged", function(_, val)
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if current then NP.castbar.OnNativeCastValueChanged(current, val) end
        end)
    end

    if plate and plate.HookScript then
        plate:HookScript("OnShow", function()
            if NP.config.IsModuleEnabled() and NP.module.applied then
                local current = CurrentPlateData()
                if current then NP.lifecycle.OnShowNameplate(current, "plate_show") end
            end
        end)
        plate:HookScript("OnHide", function()
            if not NP.module.applied then return end
            local current = CurrentPlateData()
            if current then NP.lifecycle.OnHideNameplate(current, "plate_hide") end
        end)
    end

    local raidIcon = plateData.raidIcon
    if raidIcon and raidIcon.HookScript then
        raidIcon:HookScript("OnShow", function()
            if NP.config.IsModuleEnabled() and NP.module.applied then
                local current = CurrentPlateData()
                if current then NP.widgets.Sync("RaidMarker", current) end
            end
        end)
    end

    local function OnNativeEliteShown()
        if not NP.config.IsModuleEnabled() or not NP.module.applied then return end
        local current = CurrentPlateData()
        if not current then return end
        NP.native_style.NoteNativePlateClassification(current)
        if NP.config.GetCfg().showEliteIcon ~= false then
            NP.native_style.SuppressNativePlateIcon(current.eliteIcon)
            NP.native_style.SuppressNativePlateIcon(current.bossIcon)
            NP.widgets.Sync("Elite", current)
        end
    end
    local function OnNativeEliteHidden()
        if not NP.config.IsModuleEnabled() or not NP.module.applied then return end
        local current = CurrentPlateData()
        if not current then return end
        NP.native_style.NoteNativePlateClassification(current)
        NP.widgets.Sync("Elite", current)
    end
    local eliteIcon = plateData.eliteIcon
    if eliteIcon and eliteIcon.HookScript then
        eliteIcon:HookScript("OnShow", OnNativeEliteShown)
        eliteIcon:HookScript("OnHide", OnNativeEliteHidden)
    end
    local bossIcon = plateData.bossIcon
    if bossIcon and bossIcon.HookScript then
        bossIcon:HookScript("OnShow", OnNativeEliteShown)
        bossIcon:HookScript("OnHide", OnNativeEliteHidden)
    end
end

-- Lifecycle events

function NP.lifecycle.OnNewNameplate(plateData)
    NP.lifecycle.SetupPlateHooks(plateData)
    plateData._isRegistered = true
end

function NP.lifecycle.OnShowNameplate(plateData, reason)
    plateData._isVisible = true
    NP.lifecycle.PrepareNameplate(plateData)
    NP.identity.UpdatePlateGroupTargetMatch(plateData, true)
    if NP.module.inArena and NP.identity.UpdateArenaCastBindingForPlate then
        NP.identity.UpdateArenaCastBindingForPlate(plateData)
    end
    if NP.clickbox and NP.clickbox.OnPlateShown then
        NP.clickbox.OnPlateShown(plateData)
    end
    if plateData._matchedCastUnit then
        NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
    end
    -- Defer full refresh to queue (avoid re-entrancy in OnShow).
    NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateNameplate)
end

function NP.lifecycle.OnHideNameplate(plateData, _reason)
    -- Preserve focus GUID through hide/show; no native re-acquire signal.
    local isFocusPlate = NP.identity and NP.identity.IsFocusPlate and NP.identity.IsFocusPlate(plateData)
    NP.lifecycle.InvalidatePlateVisuals(plateData, not isFocusPlate)
    plateData._isVisible = false
    plateData.plateName = nil
    plateData._petCloneSnapshot = nil
    plateData._castIdentityName = nil
    plateData._debuffIdentityName = nil
    plateData._eliteIdentityName = nil
    plateData.namePlateUnitToken = nil
    plateData.unitToken = nil
    plateData._plateClassification = nil
    plateData._nativeAlpha = nil
    plateData._tokenNativeAlpha = nil
    plateData._lastAppliedVisualAlpha = nil
    plateData._layoutSig = nil
    plateData._shownAt = nil
    plateData._levelSettleAt = nil
    plateData.plateLevel = nil
    plateData._plateLevelName = nil
    if plateData.plate then
        plateData.plate.namePlateUnitToken = nil
    end
    plateData._matchedCastUnit = nil
    plateData.arenaCastUnit = nil
    plateData._clickAreaPending = nil
    if NP.clickbox then
        NP.clickbox.OnPlateHidden(plateData)
        NP.clickbox.ResetPlate(plateData)
    end
    if NP.castbar and NP.castbar.OnPlateHidden then
        NP.castbar.OnPlateHidden(plateData)
    end
    NP.identity.InvalidatePlate(plateData)
end

-- Registration and scan

function NP.lifecycle.SetupPlate(plateData)
    if plateData.setupDone then return end
    plateData.setupDone = true
    NP.lifecycle.OnNewNameplate(plateData)
    if plateData.plate and plateData.plate.IsShown and plateData.plate:IsShown() then
        NP.lifecycle.OnShowNameplate(plateData, "setup_plate")
    end
end

function NP.lifecycle.RegisterPlate(plateKey, parts)
    if NP.module.plates[plateKey] then
        return NP.module.plates[plateKey]
    end
    if not plateKey or not NP.discovery.IsBlizzardNameplate(plateKey) then
        return nil
    end
    parts = parts or NP.discovery.ExtractBlizzardPlateParts(plateKey)
    if not parts or not parts.border then
        return nil
    end

    local plateData = {}
    for k, v in pairs(parts) do
        plateData[k] = v
    end

    local buckets = (NP.const and NP.const.THREAT_BUDGET_BUCKETS) or 4
    NP.module._budgetCounter = ((NP.module._budgetCounter or 0) + 1) % buckets
    plateData._budgetBucket = NP.module._budgetCounter

    NP.module.plates[plateKey] = plateData
    return plateData
end

function NP.lifecycle.UnregisterPlate(plateKey)
    local plateData = NP.module.plates[plateKey]
    if plateData then
        if NP.layout and NP.layout.RestorePlateDepthOrdering then
            NP.layout.RestorePlateDepthOrdering(plateData)
        end
        NP.state.ClearPlateGUID(plateData)
        NP.identity.InvalidatePlate(plateData)
        if plateData.plate and plateData.plate._dragonUINameplateHookState
            and plateData.plate._dragonUINameplateHookState.plateData == plateData then
            plateData.plate._dragonUINameplateHookState.plateData = nil
        end
    end
    NP.module.plates[plateKey] = nil
end

-- Reused per scan; ScanNameplates is synchronous and non-reentrant, so a single
-- module-scoped table avoids allocating a fresh set on every 4 Hz scan.
local scratchSeen = {}

function NP.lifecycle.ScanNameplates()
    if not NP.config.IsModuleEnabled() then return end

    local discovered = NP.discovery.EnumerateBlizzardNameplates()
    local seen = scratchSeen
    wipe(seen)

    -- Phase 1: register all plates (same-name GUID safety).
    for plateKey, parts in pairs(discovered) do
        seen[plateKey] = true
        NP.lifecycle.RegisterPlate(plateKey, parts)
    end

    -- Phase 2: hooks and initial refresh.
    for plateKey in pairs(seen) do
        local plateData = NP.module.plates[plateKey]
        if plateData then
            NP.lifecycle.SetupPlate(plateData)
        end
    end

    for plateKey in pairs(NP.module.plates) do
        if not seen[plateKey] then
            NP.lifecycle.UnregisterPlate(plateKey)
        end
    end
end
