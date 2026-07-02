local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates engine: OnUpdate driver, queues, events.
-- One WorldFrame OnUpdate drains weak-key queues (reset > fn > mass > per-plate).
-- Identity uses fresh alpha each frame. Plate root alpha harvested then forced to 1;
-- visual alpha and frame levels have single owners (engine / layout).

NP.engine = NP.engine or {}
local E = NP.engine

local DRIFT_INTERVAL = 0.2

-- 3.3.5a CLEU: OnEvent(_, event, timestamp, subevent, sourceGUID, ...) — no hideCaster slot.

-- Queues (weak keys)

local weakKey = { __mode = "k" }
E.massQueue = E.massQueue or setmetatable({}, weakKey)
E.functionQueue = E.functionQueue or setmetatable({}, weakKey)
E.targetQueue = E.targetQueue or setmetatable({}, weakKey)

local function ForEachVisiblePlate(func)
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        if plate and plate.IsShown and plate:IsShown() then
            func(plateData)
        end
    end
end

function E.ResetQueues()
    for fn in pairs(E.massQueue) do
        E.massQueue[fn] = nil
    end
    for fn in pairs(E.functionQueue) do
        E.functionQueue[fn] = nil
    end
    for plate in pairs(E.targetQueue) do
        E.targetQueue[plate] = nil
    end
end

function E.QueueMass(func)
    if func then
        E.massQueue[func] = true
    end
end

function E.QueueFunction(func)
    if func then
        E.functionQueue[func] = true
    end
end

function E.QueuePlate(plateData, func)
    if plateData and func then
        E.targetQueue[plateData] = func
    end
end

E.Callbacks = E.Callbacks or {}
local CB = E.Callbacks

function CB.OnResetNameplate(plateData)
    NP.lifecycle.OnResetNameplate(plateData)
end

function CB.OnUpdateNameplate(plateData)
    NP.gather.RefreshPlateFull(plateData, "queue_update")
end

function CB.OnUpdateThreatSituation(plateData)
    NP.widgets.Sync("ThreatGlow", plateData, nil, { reason = "queue_threat" })
end

function CB.OnUpdateRaidMarker(plateData)
    NP.widgets.Sync("RaidMarker", plateData)
end

function CB.OnUpdateCombo(plateData)
    NP.widgets.Sync("Combo", plateData)
end

function CB.OnUpdateAuras(plateData)
    NP.gather.RefreshPlateAuras(plateData, nil, "queue_auras")
end

function CB.OnUpdateCastbar(plateData)
    NP.gather.RefreshPlateCastbar(plateData, "queue_castbar")
end

function CB.OnUpdateHealth(plateData)
    NP.gather.RefreshPlateHealth(plateData, nil, "queue_health")
end

function CB.OnUpdatePower(plateData)
    NP.gather.RefreshPlatePower(plateData, "queue_power")
end

-- Drain: reset > functions > mass-full > mass-partial > per-plate.
function E.ProcessQueues()
    if E.massQueue[CB.OnResetNameplate] then
        ForEachVisiblePlate(CB.OnResetNameplate)
        E.ResetQueues()
        return
    end

    for queuedFunction in pairs(E.functionQueue) do
        E.functionQueue[queuedFunction] = nil
        queuedFunction()
    end

    if E.massQueue[CB.OnUpdateNameplate] then
        for queuedFunction in pairs(E.massQueue) do
            E.massQueue[queuedFunction] = nil
        end
        ForEachVisiblePlate(CB.OnUpdateNameplate)
    else
        for queuedFunction in pairs(E.massQueue) do
            E.massQueue[queuedFunction] = nil
            ForEachVisiblePlate(queuedFunction)
        end
    end

    for plateData, queuedFunction in pairs(E.targetQueue) do
        E.targetQueue[plateData] = nil
        if plateData and plateData.plate and plateData.plate.IsShown and plateData.plate:IsShown() then
            queuedFunction(plateData)
        end
    end
end

-- Instance / group context

function E.UpdateInstanceContext()
    local inInstance, instanceType = IsInInstance()
    NP.module.inPvEInstance = inInstance
        and (instanceType == "party" or instanceType == "raid")
        or false
    NP.module.inArena = inInstance and instanceType == "arena" or false
end

local function StripRealmName(name)
    if not name or name == "" then
        return nil
    end
    return NP.native_style.StripRealm(name)
end

function E.UpdatePartyArenaTokenMaps()
    NP.module.partyTokenByName = NP.module.partyTokenByName or {}
    NP.module.arenaTokenByName = NP.module.arenaTokenByName or {}
    local partyMap = NP.module.partyTokenByName
    local arenaMap = NP.module.arenaTokenByName

    for key in pairs(partyMap) do
        partyMap[key] = nil
    end
    for key in pairs(arenaMap) do
        arenaMap[key] = nil
    end

    for i = 1, GetNumPartyMembers() do
        local token = "party" .. i
        local name = StripRealmName(UnitName(token))
        if name then
            partyMap[name] = token
        end
    end

    for i = 1, GetNumArenaOpponents() do
        local token = "arena" .. i
        local name = StripRealmName(UnitName(token))
        if name then
            arenaMap[name] = token
        end
        local petToken = "arenapet" .. i
        if UnitExists(petToken) then
            local petName = StripRealmName(UnitName(petToken))
            if petName then
                arenaMap[petName] = petToken
            end
        end
    end

    NP.identity.UpdateGroupCache()
    NP.module._arenaMapLastUpdate = GetTime()
end

-- CVars and config snapshot

function E.SyncThreatCVar()
    if not GetCVar or not SetCVar then return end
    -- Shared with unitframes target/focus threat-% (target_style.lua UpdateThreat) — must
    -- stay forced on for the whole nameplates session, not just while nameplate glow is on.
    if not NP.module.threatCVarApplied then
        NP.module.savedThreatWarning = GetCVar("threatWarning")
        NP.module.threatCVarApplied = true
    end
    SetCVar("threatWarning", "3")
end

function E.SyncEnemyClassColorCVar()
    if not GetCVar or not SetCVar then return end
    local cfg = NP.config.GetCfg()
    if not NP.module.classColorCVarApplied then
        NP.module.savedShowClassColorInNameplate = GetCVar("ShowClassColorInNameplate")
        NP.module.classColorCVarApplied = true
    end
    SetCVar("ShowClassColorInNameplate", (cfg.enemyPlayerClassColors ~= false) and "1" or "0")
end

function E.SyncRetailStackingCVars()
    local cfg = NP.config.GetCfg()
    if not GetCVar or not SetCVar then return end
    if NP.config.IsRetailBehavior() and cfg.retailStackingEnabled == true then
        if NP.module.savedNameplateAllowOverlap == nil then
            NP.module.savedNameplateAllowOverlap = GetCVar("nameplateAllowOverlap")
        end
        SetCVar("nameplateAllowOverlap", "1")
    elseif NP.module.savedNameplateAllowOverlap ~= nil then
        SetCVar("nameplateAllowOverlap", NP.module.savedNameplateAllowOverlap)
        NP.module.savedNameplateAllowOverlap = nil
    end
end

function E.SyncShowVKeyCastbarCVar()
    if not GetCVar or not SetCVar then return end
    local cfg = NP.config.GetCfg()
    local cvar = "showVKeyCastbar"

    local function EnsureSaved()
        if NP.module.savedShowVKeyCastbar == nil then
            NP.module.savedShowVKeyCastbar = GetCVar(cvar)
        end
    end

    local nativeCastWanted = (cfg.showCastBar ~= false)
    local likelyHDClient = (C_NamePlate and C_NamePlate.GetNamePlateForUnit)
        or (UnitExists and UnitExists("nameplate1"))
    likelyHDClient = likelyHDClient and true or false
    local shouldForceOn = nativeCastWanted and likelyHDClient

    if shouldForceOn then
        EnsureSaved()
        NP.module.showVKeyCVarManaged = true
        SetCVar(cvar, "1")
        return
    end

    -- Restore saved value when auto-forcing no longer applies.
    if NP.module.showVKeyCVarManaged and NP.module.savedShowVKeyCastbar ~= nil then
        SetCVar(cvar, NP.module.savedShowVKeyCastbar)
        NP.module.showVKeyCVarManaged = nil
        NP.module.savedShowVKeyCastbar = nil
    end
end

function E.SyncConfigSnapshot()
    local cfg = NP.config.GetCfg()
    NP.castbar.SyncOffTargetMonitorFromConfig(cfg)
    NP.module._opacityEnabled = (cfg.disableNonTargetFade ~= true)
    NP.module._opacityValue = cfg.opacityNonTarget or 0.5
    NP.module._opacityFullNoTarget = (cfg.opacityFullNoTarget ~= false)
    NP.module._retailBehavior = NP.config.IsRetailBehavior()
    NP.module._clampTargetEnabled = cfg.clampTarget == true
    NP.module._clampBossEnabled = cfg.clampBoss == true
    NP.module._clampTopInset = cfg.clampTopInset or 0

    -- Re-verify WorldFrame height each sync; external resets can invalidate the cached flag.
    local wantExtended = (NP.module._clampTargetEnabled or NP.module._clampBossEnabled) and true or false
    NP.layout.UpdateWorldFrameHeight(wantExtended)

    E.SyncEnemyClassColorCVar()
    E.SyncRetailStackingCVars()
    E.SyncShowVKeyCastbarCVar()
    E.SyncThreatCVar()
    if not NP.module._retailBehavior then
        NP.layout.ResetRetailStacking()
    end
end

-- Single OnUpdate driver

local function EngineOnUpdate(_, elapsed)
    if not NP.config.IsModuleEnabled() or not NP.module.applied then return end

    -- 0. Castbar progress on active plates.
    NP.castbar.TickAllPlateCastBars()

    local hasTarget = UnitExists("target") == 1

    -- 1. Harvest native alpha, then force plate root to 1 when target exists.
    -- cfg is hoisted out of the per-plate retail-scale path (was 40 GetCfg/frame).
    -- awesome_wotlk only: never force alpha back to 1. The anti-dim re-assert
    -- below exists for a stock 3.3.5a quirk (Blizzard dims non-target plates);
    -- awesome_wotlk manages plate alpha itself, including its own wall/LoS
    -- occlusion hiding, and forcing it to 1 here was fighting that.
    local skipAlphaForce = C_NamePlate ~= nil
    local retailCfg = NP.module._retailBehavior and NP.config.GetCfg() or nil
    for _, pd in pairs(NP.module.plates) do
        local pl = pd.plate
        if not pl or not pl.IsShown or not pl:IsShown() then
        elseif pl.GetAlpha then
            local nativeAlpha = pl:GetAlpha() or 1.0
            pd._tokenNativeAlpha = nativeAlpha
            if hasTarget and pl.SetAlpha and not skipAlphaForce then
                -- Blizzard dims non-target plates; only re-assert 1 when it
                -- actually dimmed (skip the no-op SetAlpha on plates already at 1).
                if nativeAlpha < 0.9999 then
                    pl:SetAlpha(1)
                end
                pd._nativeAlpha = 1.0
            else
                pd._nativeAlpha = nativeAlpha
            end
        end
        if NP.module._retailBehavior then
            NP.layout.ApplyRetailPlateScale(pd, {
                isTarget = NP.identity.PlateHasTargetAlpha(pd),
            }, retailCfg)
        elseif pd._retailScale or pd._pendingRetailScale then
            NP.layout.SetRetailPlateScale(pd, 1)
        end
    end

    -- 2. Deferred queues.
    E.ProcessQueues()

    local levelSettleNow = GetTime and GetTime() or 0
    for _, pd in pairs(NP.module.plates) do
        if pd._levelSettleAt and levelSettleNow >= pd._levelSettleAt then
            pd._levelSettleAt = nil
            NP.gather.RefreshPlateName(pd, "level_settle")
        end
    end

    if NP.module._deferredTargetResolveFrames and NP.module._deferredTargetResolveFrames > 0 then
        NP.module._deferredTargetResolveFrames = NP.module._deferredTargetResolveFrames - 1
        if NP.module._deferredTargetResolveFrames == 0 then
            NP.identity.UpdateTargetContext()
            E.QueueMass(CB.OnUpdateNameplate)
        end
    end

    -- 3. Identity transitions (target / mouseover / focus / threat).
    NP.identity.ProcessContextTransitions()
    local threatBuckets = (C and C.THREAT_BUDGET_BUCKETS) or 4
    NP.module._budgetFrame = ((NP.module._budgetFrame or 0) + 1) % threatBuckets
    NP.gather.ProcessThreatTransitions()
    NP.widgets.UpdateComboTargetPlate()
    -- Re-show combo if target plate returned without a pointer change.
    if UnitExists("target") and NP.module.comboTargetPlate then
        local host = NP.module.comboTargetPlate._comboHost
        local points = NP.widgets.GetPlayerComboPoints()
        if points > 0 and points <= 5 and host and host.IsShown and not host:IsShown() then
            NP.widgets.SyncComboPoints(NP.module.comboTargetPlate)
        end
    end

    -- 4. Reaction drift safety net (200ms).
    NP.module._driftElapsed = (NP.module._driftElapsed or 0) + elapsed
    if NP.module._driftElapsed >= DRIFT_INTERVAL then
        NP.module._driftElapsed = 0
        NP.gather.ProcessReactionDrift()
    end

    if NP.clickbox and NP.clickbox.TickPreview then
        NP.clickbox.TickPreview()
    end

    if NP.module._layoutPending and not InCombatLockdown() then
        NP.layout.FlushPendingPlateLayout()
    end

    -- 5. Stacking and clamping.
    NP.layout.UpdateStacking()

    -- 6. Depth sort (50ms throttle).
    NP.layout.UpdateDepthOrdering(elapsed)

    -- 7. Visual alpha on the stack only.
    if NP.module._opacityEnabled then
        for _, pd in pairs(NP.module.plates) do
            local visualAlpha = NP.module._opacityValue
            if NP.identity.IsTargetPlateVisual(pd, hasTarget)
                or ((not hasTarget) and NP.module._opacityFullNoTarget) then
                visualAlpha = 1.0
            end
            NP.layout.SetPlateVisualAlpha(pd, visualAlpha)
        end
    else
        for _, pd in pairs(NP.module.plates) do
            NP.layout.SetPlateVisualAlpha(pd, 1.0)
        end
    end

    -- 8. Rescan when WorldFrame child count changes.
    local n = NP.WorldGetNumChildren(WorldFrame)
    if n ~= NP.module.lastChildCount then
        NP.module.lastChildCount = n
        E.QueueFunction(NP.lifecycle.ScanNameplates)
    end

    -- 9. Periodic resync (CVars, caches).
    NP.module.scanElapsed = NP.module.scanElapsed + elapsed
    if NP.module.scanElapsed >= C.SCAN_INTERVAL then
        NP.module.scanElapsed = 0
        E.UpdateInstanceContext()
        E.SyncConfigSnapshot()
        local expiredGUIDs = NP.auras.CleanExpiredAuras()
        E.QueueFunction(NP.lifecycle.ScanNameplates)
        NP.gather.RefreshExpiredAuraPlates(expiredGUIDs, "scan_interval")
    end
end

-- Event handling

local function FindPlateDataByNameplateFrame(frame)
    if not frame then
        return nil
    end
    for _, plateData in pairs(NP.module.plates) do
        if plateData and (plateData.plate == frame or plateData.widgetHost == frame) then
            return plateData
        end
    end
    return nil
end

local function EngineOnEvent(_, event, unit, ...)
    if not NP.module.applied or not NP.config.IsModuleEnabled() then return end

    if event == "PLAYER_TARGET_CHANGED" then
        -- Target alpha stale at event time; resolved on next engine tick.
        NP.module.targetGUID = UnitGUID("target")
        NP.module._deferredTargetResolveFrames = 1
        return
    end
    if event == "PLAYER_FOCUS_CHANGED" then
        NP.module.focusGUID = UnitGUID("focus")
        E.QueueMass(CB.OnUpdateCastbar)
        return
    end
    if event == "UPDATE_MOUSEOVER_UNIT" then
        NP.module.mouseoverGUID = UnitGUID("mouseover")
        return
    end
    if event == "UNIT_TARGET" and unit then
        if unit:match("^party%d+$") or unit:match("^raid%d+$") then
            NP.identity.RefreshGroupTargetMatches()
            E.QueueMass(CB.OnUpdateCastbar)
            return
        end
    end
    if event == "RAID_TARGET_UPDATE" then
        E.QueueMass(CB.OnUpdateRaidMarker)
        if NP.config.GetCfg().raidMarkHealthColor then
            E.QueueMass(CB.OnUpdateHealth)
        end
        return
    end
    if event == "UNIT_COMBO_POINTS" then
        E.QueueMass(CB.OnUpdateCombo)
        return
    end
    if event == "PLAYER_TOTEM_UPDATE" then
        NP.widgets.OnTotemUpdate(unit)
        E.QueueMass(CB.OnUpdateNameplate)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        E.UpdateInstanceContext()
        E.UpdatePartyArenaTokenMaps()
        NP.widgets.RefreshAllOwnTotems()
        if NP.module.inArena and NP.identity.UpdateArenaCastBindings then
            NP.identity.UpdateArenaCastBindings()
        end
        NP.identity.RefreshGroupTargetMatches()
        NP.auras.PruneCaches()
        if NP.module._clampBossEnabled then
            E.QueueMass(CB.OnUpdateNameplate)
        end
        E.QueueMass(CB.OnUpdateCastbar)
        return
    end
    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        E.UpdatePartyArenaTokenMaps()
        NP.identity.RefreshGroupTargetMatches()
        E.QueueMass(CB.OnUpdateCastbar)
        return
    end
    if event == "ARENA_OPPONENT_UPDATE" then
        -- Refresh arena maps on every ARENA_OPPONENT_UPDATE reason.
        E.UpdatePartyArenaTokenMaps()
        if NP.identity.UpdateArenaCastBindings then
            NP.identity.UpdateArenaCastBindings()
        end
        NP.identity.RefreshGroupTargetMatches()
        E.QueueMass(CB.OnUpdateCastbar)
        return
    end
    -- awesome_wotlk only. No-op on stock 3.3.5a (C_NamePlate is nil there, so
    -- neither event is even registered) — the 4 Hz poll remains the only path.
    --
    -- NAME_PLATE_CREATED fires for a bare frame that isn't attached to a unit
    -- yet: the native health bar hasn't been given its real reaction color at
    -- this point. Styling here (as a first attempt did) captures whatever the
    -- bar's color defaults to, which matches none of GetPlateReaction's known
    -- colors and falls through to its "HOSTILE/PLAYER" default — friendly
    -- units render with a red bar and never get headline mode. So this only
    -- registers the plate (captures region references) and applies no visuals.
    if event == "NAME_PLATE_CREATED" and C_NamePlate then
        local namePlateFrame = unit
        if namePlateFrame and not FindPlateDataByNameplateFrame(namePlateFrame) then
            local plateData = NP.lifecycle.RegisterPlate(namePlateFrame)
            if addon.debugMode then
                local bar = plateData and plateData.healthBar
                local r, g, b = bar and bar.GetStatusBarColor and bar:GetStatusBarColor()
                print(string.format("|cFFFFFF00[DUI nameplate debug]|r NAME_PLATE_CREATED t=%.3f registered=%s barColor=%s,%s,%s",
                    GetTime(), tostring(plateData ~= nil), tostring(r), tostring(g), tostring(b)))
            end
        end
        return
    end
    -- NAME_PLATE_UNIT_ADDED fires once the plate is actually attached to a
    -- unit, which is when the native reaction color is set — the first safe
    -- point to style it. This is what replaces waiting for the next poll tick.
    if event == "NAME_PLATE_UNIT_ADDED" and C_NamePlate and unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then
            nameplate.namePlateUnitToken = unit
        end
        local plateData = FindPlateDataByNameplateFrame(nameplate)
        if not plateData and nameplate then
            -- Fallback in case NAME_PLATE_CREATED didn't fire for this frame.
            plateData = NP.lifecycle.RegisterPlate(nameplate)
        end
        local isNewSetup = plateData and not plateData.setupDone
        if addon.debugMode then
            local bar = plateData and plateData.healthBar
            local r, g, b
            if bar and bar.GetStatusBarColor then
                r, g, b = bar:GetStatusBarColor()
            end
            print(string.format("|cFFFFFF00[DUI nameplate debug]|r NAME_PLATE_UNIT_ADDED t=%.3f unit=%s hadPlateData=%s setupDone=%s barColor=%s,%s,%s",
                GetTime(), tostring(unit), tostring(plateData ~= nil), tostring(plateData and plateData.setupDone),
                tostring(r), tostring(g), tostring(b)))
        end
        if isNewSetup then
            NP.lifecycle.SetupPlate(plateData)
            -- We're in a plain event handler here, not inside the plate's own
            -- OnShow hookscript, so there's no re-entrancy risk in styling it
            -- right now instead of waiting for the queued OnUpdate tick (that
            -- 1-frame gap is what was still showing native unstyled chrome,
            -- including its own default health bar color, for an instant).
            if plateData.plate and plateData.plate.IsShown and plateData.plate:IsShown() then
                NP.gather.RefreshPlateFull(plateData, "awesome_wotlk_unit_added")
            end
        end
        if plateData then
            plateData.namePlateUnitToken = unit
            if plateData.plate then
                plateData.plate.namePlateUnitToken = unit
            end
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        NP.module.playerInCombat = true
        if NP.clickbox and NP.clickbox.OnCombatStart then
            NP.clickbox.OnCombatStart()
        end
        E.QueueMass(CB.OnUpdateThreatSituation)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        NP.module.playerInCombat = false
        -- Let ProcessThreatTransitions run one flush pass to revert glow/tint.
        NP.module._threatNeedsFlush = true
        E.QueueMass(CB.OnUpdateThreatSituation)
        NP.module._deferredTargetResolveFrames = 1
        NP.auras.PruneCaches()
        NP.layout.FlushPendingPlateLayout()
        if NP.config.IsOffTargetCastMonitorActive(NP.config.GetCfg())
            and NP.castbar.PruneCastMonitorStaleState then
            NP.castbar.PruneCastMonitorStaleState()
        end
        return
    end
    if event == "UNIT_THREAT_SITUATION_UPDATE" then
        E.QueueMass(CB.OnUpdateThreatSituation)
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- CLEU: `unit` is timestamp; forward `...` intact (dose stacks are extra args).
        local timestamp = unit
        NP.auras.HandleCombatLog(timestamp, ...)
        local cfg = NP.config.GetCfg()
        if cfg.showCastBar ~= false then
            NP.castbar.HandleCombatLogCastBreak(timestamp, ...)
            if NP.config.IsOffTargetCastMonitorActive(cfg) then
                NP.castbar.CastMonitorOnCombatLog(timestamp, ...)
            end
        end
        return
    end

    if not unit then return end

    if event == "UNIT_AURA" then
        if unit == "target" or unit == "mouseover" or unit == "focus" then
            local refreshedGUID = NP.auras.DebuffRuntime.UpdateAuraCacheFromUnit(unit)
            local owner
            if unit == "target" or unit == "mouseover" then
                owner = NP.identity.FindUniquePlateForUnit(unit)
                if owner and refreshedGUID and not NP.state.GetPlateGUID(owner) then
                    NP.state.SetPlateGUID(owner, refreshedGUID, {
                        source = "AURA_HINT",
                        confidence = C.GUID_CONFIDENCE.AURA_HINT,
                    })
                end
            end
            if refreshedGUID then
                owner = owner or NP.state.GUIDToPlate[refreshedGUID]
                    or NP.auras.FindFallbackPlateForGUID(refreshedGUID)
            end
            if owner then
                E.QueuePlate(owner, CB.OnUpdateAuras)
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        NP.castbar.OnInterruptibleChanged(unit, event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
        return
    end
    if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET"
        or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        NP.castbar.OnCastStopEvent(event, unit, ...)
        return
    end
    if event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        NP.castbar.OnCastDelayedEvent(event, unit, ...)
        return
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        NP.castbar.OnCastStartEvent(event, unit, ...)
        return
    end

    -- Health / power: prefer GUID map over full scan.
    if event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_MAXMANA" then
        local unitGUID = UnitGUID(unit)
        local plateData = unitGUID and NP.state.GUIDToPlate[unitGUID]
        -- ResolvePlateUnit can only discover these three tokens. Avoid an O(n)
        -- scan for party/raid and other unit events that cannot match a plate.
        if not plateData and (unit == "target" or unit == "focus" or unit == "mouseover") then
            for _, candidate in pairs(NP.module.plates) do
                if NP.identity.ResolvePlateUnit(candidate) == unit then
                    plateData = candidate
                    break
                end
            end
        end
        if plateData then
            if event == "UNIT_HEALTH" then
                E.QueuePlate(plateData, CB.OnUpdateHealth)
            else
                E.QueuePlate(plateData, CB.OnUpdatePower)
            end
        end
    end
end

-- Apply / Restore / Refresh

local function RunNameplatesRefresh()
    if not NP.config.IsModuleEnabled() then
        addon:RestoreNameplatesSystem()
        return
    end
    if NP.module.applied then
        NP.module._cfgRev = (NP.module._cfgRev or 0) + 1
        E.SyncConfigSnapshot()
        NP.lifecycle.ScanNameplates()
        E.QueueMass(CB.OnUpdateNameplate)
    else
        addon:ApplyNameplatesSystem()
    end
end

local function RunNameplatesApply()
    if NP.module.applied then
        NP.lifecycle.ScanNameplates()
        E.SyncConfigSnapshot()
        return
    end
    if not NP.config.IsModuleEnabled() then return end

    NP.module.playerInCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    NP.module._cfgRev = (NP.module._cfgRev or 0) + 1
    E.UpdateInstanceContext()
    E.UpdatePartyArenaTokenMaps()
    if NP.module.inArena and NP.identity.UpdateArenaCastBindings then
        NP.identity.UpdateArenaCastBindings()
    end
    E.SyncConfigSnapshot()

    NP.module.lastChildCount = NP.WorldGetNumChildren(WorldFrame)
    NP.module.scanElapsed = 0
    NP.module._depthSortElapsed = 0
    NP.module._driftElapsed = 0
    NP.module._castTickElapsed = 0

    if not NP.module.scannerFrame then
        NP.module.scannerFrame = CreateFrame("Frame", nil, WorldFrame)
        -- Late strata so native target alpha has settled.
        NP.module.scannerFrame:SetFrameStrata("TOOLTIP")
        NP.module.scannerFrame:SetFrameLevel(1)
    end
    NP.module.scannerFrame:SetScript("OnUpdate", EngineOnUpdate)
    NP.module.scannerFrame:Show()

    if not NP.module.eventFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
        f:RegisterEvent("PLAYER_FOCUS_CHANGED")
        f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        f:RegisterEvent("UNIT_TARGET")
        f:RegisterEvent("UNIT_HEALTH")
        f:RegisterEvent("UNIT_MANA")
        f:RegisterEvent("UNIT_MAXMANA")
        f:RegisterEvent("UNIT_AURA")
        f:RegisterEvent("UNIT_SPELLCAST_START")
        f:RegisterEvent("UNIT_SPELLCAST_STOP")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        f:RegisterEvent("UNIT_SPELLCAST_FAILED")
        f:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
        f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
        f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
        f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        f:RegisterEvent("RAID_TARGET_UPDATE")
        f:RegisterEvent("UNIT_COMBO_POINTS")
        f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
        f:RegisterEvent("PLAYER_TOTEM_UPDATE")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        f:RegisterEvent("PARTY_MEMBERS_CHANGED")
        f:RegisterEvent("RAID_ROSTER_UPDATE")
        f:RegisterEvent("ARENA_OPPONENT_UPDATE")
        if C_NamePlate then
            f:RegisterEvent("NAME_PLATE_CREATED")
            f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        end
        f:SetScript("OnEvent", EngineOnEvent)
        NP.module.eventFrame = f
    end
    NP.module.eventFrame:Show()

    if NP.clickbox and NP.clickbox.InitSecureSystem then
        NP.clickbox.InitSecureSystem()
    end
    if NP.module.playerInCombat and NP.clickbox and NP.clickbox.OnCombatStart then
        NP.clickbox.OnCombatStart()
    end

    NP.module.applied = true
    NP.module.initialized = true
    NP.widgets.RefreshAllOwnTotems()
    NP.lifecycle.ScanNameplates()
    E.QueueMass(CB.OnUpdateNameplate)
end

local function RunNameplatesRestore()
    -- Disable hook dispatch before native frames are shown again. HookScript
    -- callbacks are permanent and would otherwise enqueue stale plateData while
    -- restoration is still in progress.
    NP.module.applied = false
    if NP.module.scannerFrame then
        NP.module.scannerFrame:SetScript("OnUpdate", nil)
        NP.module.scannerFrame:Hide()
    end
    if NP.module.eventFrame then
        NP.module.eventFrame:Hide()
    end
    E.ResetQueues()

    if NP.castbar and NP.castbar.Shutdown then
        NP.castbar.Shutdown()
    end

    if NP.module.threatCVarApplied and NP.module.savedThreatWarning and SetCVar then
        SetCVar("threatWarning", NP.module.savedThreatWarning)
    end
    if NP.module.classColorCVarApplied and NP.module.savedShowClassColorInNameplate ~= nil and SetCVar then
        SetCVar("ShowClassColorInNameplate", NP.module.savedShowClassColorInNameplate)
    end
    if NP.module.showVKeyCVarManaged and NP.module.savedShowVKeyCastbar ~= nil and SetCVar then
        SetCVar("showVKeyCastbar", NP.module.savedShowVKeyCastbar)
    end
    if NP.module.savedNameplateAllowOverlap ~= nil and SetCVar then
        SetCVar("nameplateAllowOverlap", NP.module.savedNameplateAllowOverlap)
    end
    NP.module.threatCVarApplied = nil
    NP.module.savedThreatWarning = nil
    NP.module.classColorCVarApplied = nil
    NP.module.savedShowClassColorInNameplate = nil
    NP.module.showVKeyCVarManaged = nil
    NP.module.savedShowVKeyCastbar = nil
    NP.module.savedNameplateAllowOverlap = nil

    NP.layout.UpdateWorldFrameHeight(false)
    NP.layout.ResetRetailStacking()
    if NP.layout.RestoreDepthOrdering then
        NP.layout.RestoreDepthOrdering()
    end
    NP.module._clampTargetEnabled = nil
    NP.module._clampBossEnabled = nil
    NP.module._clampTopInset = nil
    NP.module.inPvEInstance = nil
    NP.module._layoutPending = nil
    NP.module._depthSortElapsed = nil
    NP.module._castTickElapsed = nil
    if not NP.module._pendingWorldFrameExtend then
        NP.module._worldFrameExtended = nil
    end

    for guid in pairs(NP.state.GUIDToPlate) do
        NP.state.GUIDToPlate[guid] = nil
    end
    for guid in pairs(NP.state.PlateAuraCache) do
        NP.state.PlateAuraCache[guid] = nil
    end
    for guid in pairs(NP.auras.DRState or {}) do
        NP.auras.DRState[guid] = nil
    end
    for name in pairs(NP.state.AuraGUIDByName) do
        NP.state.AuraGUIDByName[name] = nil
    end
    for icon in pairs(NP.state.AuraGUIDByRaidIcon) do
        NP.state.AuraGUIDByRaidIcon[icon] = nil
    end

    for _, plateData in pairs(NP.module.plates) do
        -- Hide module visuals and restore native chrome.
        NP.lifecycle.InvalidatePlateVisuals(plateData, true)
        NP.layout.HideMinaStack(plateData)
        NP.layout.SetPlateVisualAlpha(plateData, 1.0)
        NP.discovery.RestoreNativeChrome(plateData)

        local plate = plateData.plate
        if plate then
            if not InCombatLockdown() then
                if NP.clickbox and NP.clickbox.RestorePlate then
                    NP.clickbox.RestorePlate(plateData)
                elseif plate.SetHitRectInsets then
                    plate:SetHitRectInsets(0, 0, 0, 0)
                end
                if plate.SetScale then plate:SetScale(1) end
                if plate.SetClampedToScreen then
                    plate:SetClampedToScreen(false)
                    plate:SetClampRectInsets(0, 0, 0, 0)
                end
            end
            if plate.BGHframe and plate.BGHframe.ModifyIcon then
                plate.BGHframe:ModifyIcon()
            end
            plate.shouldModifyBGH = nil
        end
        plateData._clamped = nil
        plateData._clickAreaPending = nil
        plateData._retailScale = nil
        plateData._retailStackingApplied = nil
        plateData._bghCompatApplied = nil
        plateData._layoutSig = nil
        if NP.clickbox and NP.clickbox.ResetPlate then
            NP.clickbox.ResetPlate(plateData)
        end
        if plate and plate._dragonUINameplateHookState
            and plate._dragonUINameplateHookState.plateData == plateData then
            plate._dragonUINameplateHookState.plateData = nil
        end
        plateData.plateLevel = nil
    end

    NP.module.plates = {}
    NP.module.targetPlate = nil
    NP.module.targetGUID = nil
    NP.module.focusPlate = nil
    NP.module.focusGUID = nil
    NP.module.mouseoverPlate = nil
    NP.module.mouseoverGUID = nil
    NP.module.comboTargetPlate = nil
    NP.module.playerInCombat = nil
    NP.module._castMonitorEnabled = nil
    NP.module._castMonitorSignature = nil
    NP.module._clickboxPreviewUntil = nil
    NP.module._clickboxNativeW = nil
    NP.module._clickboxNativeH = nil
    NP.module._clickboxSecurePending = nil
    NP.module.applied = false
end

function addon:RefreshNameplates()
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("nameplates_refresh", RunNameplatesRefresh)
        return
    end
    RunNameplatesRefresh()
end

function addon:ApplyNameplatesSystem()
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("nameplates_apply", RunNameplatesApply)
        return
    end
    RunNameplatesApply()
end

function addon:RestoreNameplatesSystem()
    if InCombatLockdown() and addon.CombatQueue then
        addon.CombatQueue:Add("nameplates_restore", RunNameplatesRestore)
        return
    end
    RunNameplatesRestore()
end

-- Profile change bootstrap

local function OnProfileChanged()
    if NP.config.IsModuleEnabled() then
        addon:ApplyNameplatesSystem()
    elseif addon:ShouldDeferModuleDisable("nameplates", NP.module) then
        return
    else
        addon:RestoreNameplatesSystem()
    end
end

local function BootstrapNameplates()
    if NP.module._bootstrapped then
        return
    end
    NP.module._bootstrapped = true
    if NP.config.IsModuleEnabled() then
        addon:ApplyNameplatesSystem()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileReset", OnProfileChanged)
            end
        end)
    end
end)

if addon.core and addon.core.RegisterMessage then
    addon.core.RegisterMessage(addon, "DRAGONUI_READY", BootstrapNameplates)
end
