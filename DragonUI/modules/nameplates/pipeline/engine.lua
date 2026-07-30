local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates engine: OnUpdate driver, queues, events.
-- OnUpdate queue order: reset > fn > mass > budgeted full-refresh > per-plate.
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
-- Pending full refreshes; weak-keyed, budgeted in ProcessQueues.
E.pendingFullRefresh = E.pendingFullRefresh or setmetatable({}, weakKey)

local function ForEachVisiblePlate(func)
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData and plateData.plate
        if plate and plate.IsShown and plate:IsShown() then
            func(plateData)
        end
    end
end

local function MarkPendingFullRefresh(plateData)
    E.pendingFullRefresh[plateData] = true
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
    for plate in pairs(E.pendingFullRefresh) do
        E.pendingFullRefresh[plate] = nil
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

function CB.OnUpdateQuest(plateData)
    -- Elite after Quest: the elite dragon must reappear when a quest elite completes.
    NP.widgets.Sync("Quest", plateData)
    NP.widgets.Sync("Elite", plateData)
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

-- Drain: functions > mass-full (budgeted) > mass-partial > per-plate.
function E.ProcessQueues()
    for queuedFunction in pairs(E.functionQueue) do
        E.functionQueue[queuedFunction] = nil
        queuedFunction()
    end

    if E.massQueue[CB.OnUpdateNameplate] then
        for queuedFunction in pairs(E.massQueue) do
            E.massQueue[queuedFunction] = nil
        end
        -- Defer full refresh to budgeted pendingFullRefresh drain.
        ForEachVisiblePlate(MarkPendingFullRefresh)
    else
        for queuedFunction in pairs(E.massQueue) do
            E.massQueue[queuedFunction] = nil
            ForEachVisiblePlate(queuedFunction)
        end
    end

    -- Budget full refreshes per tick to avoid mass-event spikes; light refreshes unaffected.
    if next(E.pendingFullRefresh) then
        local budget = C.FULL_REFRESH_PLATES_PER_TICK or 8
        for plateData in pairs(E.pendingFullRefresh) do
            E.pendingFullRefresh[plateData] = nil
            if plateData and plateData.plate and plateData.plate.IsShown and plateData.plate:IsShown() then
                CB.OnUpdateNameplate(plateData)
            end
            budget = budget - 1
            if budget <= 0 then
                break
            end
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
    -- Shared with unitframes threat-%; forced for whole session, not just nameplate glow.
    if not NP.module.threatCVarApplied then
        NP.module.savedThreatWarning = GetCVar("threatWarning")
        NP.module.threatCVarApplied = true
    end
    -- Skip SetCVar when already at target value.
    if GetCVar("threatWarning") ~= "3" then
        SetCVar("threatWarning", "3")
    end
end

function E.SyncEnemyClassColorCVar()
    if not GetCVar or not SetCVar then return end
    local cfg = NP.config.GetCfg()
    if not NP.module.classColorCVarApplied then
        NP.module.savedShowClassColorInNameplate = GetCVar("ShowClassColorInNameplate")
        NP.module.classColorCVarApplied = true
    end
    local want = (cfg.enemyPlayerClassColors ~= false) and "1" or "0"
    if GetCVar("ShowClassColorInNameplate") ~= want then
        SetCVar("ShowClassColorInNameplate", want)
    end
end

-- Force off a native plate-stacking engine (some servers have one) while DragonUI clamps/stacks itself; no-op on stock 3.3.5a.
function E.SyncRetailStackingCVars()
    local cfg = NP.config.GetCfg()
    if not GetCVar or not SetCVar then return end

    -- Only SetCVar if the name already resolves (unrecognized names error unlike GetCVar).
    local currentSmoothStacking = GetCVar("nameplateSmoothStacking")
    if currentSmoothStacking ~= nil then
        local wantExclusive = NP.module._clampTargetEnabled or NP.module._clampBossEnabled
            or NP.layout.ShouldRunRetailStacking()
        if wantExclusive then
            if NP.module.savedNameplateSmoothStacking == nil then
                NP.module.savedNameplateSmoothStacking = currentSmoothStacking
            end
            if currentSmoothStacking ~= "0" then
                SetCVar("nameplateSmoothStacking", "0")
            end
        elseif NP.module.savedNameplateSmoothStacking ~= nil then
            SetCVar("nameplateSmoothStacking", NP.module.savedNameplateSmoothStacking)
            NP.module.savedNameplateSmoothStacking = nil
        end
    end

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
        if GetCVar(cvar) ~= "1" then
            SetCVar(cvar, "1")
        end
        return
    end

    -- Restore saved value when auto-forcing no longer applies.
    if NP.module.showVKeyCVarManaged and NP.module.savedShowVKeyCastbar ~= nil then
        SetCVar(cvar, NP.module.savedShowVKeyCastbar)
        NP.module.showVKeyCVarManaged = nil
        NP.module.savedShowVKeyCastbar = nil
    end
end

-- skipStackingCVar: true from the periodic scan tick, since only config-apply and zone-load need to re-run it.
function E.SyncConfigSnapshot(skipStackingCVar)
    local cfg = NP.config.GetCfg()
    NP.castbar.SyncOffTargetMonitorFromConfig(cfg)
    -- Snapshot CLEU flags; avoid per-event cfg resolution.
    NP.module._cleuCastbarEnabled = (cfg.showCastBar ~= false)
    NP.module._cleuCastMonitorActive = NP.module._cleuCastbarEnabled
        and NP.config.IsOffTargetCastMonitorActive(cfg) or false
    NP.module._opacityEnabled = (cfg.disableNonTargetFade ~= true)
    NP.module._opacityValue = cfg.opacityNonTarget or 0.5
    NP.module._opacityFullNoTarget = (cfg.opacityFullNoTarget ~= false)
    NP.module._opacityFullParty = (cfg.opacityFullParty == true)
    NP.module._retailBehavior = NP.config.IsRetailBehavior()
    NP.module._plateAlphaCompat = cfg.nameplateAlphaCompat == true
    NP.module._barAlphaCompat = cfg.nameplateBarAlphaCompat == true
    NP.module._clampTargetEnabled = cfg.clampTarget == true
    NP.module._clampBossEnabled = cfg.clampBoss == true
    NP.module._clampTopInset = cfg.clampTopInset or 0

    -- Re-verify WorldFrame height each sync; external resets can invalidate the cached flag.
    local wantExtended = (NP.module._clampTargetEnabled or NP.module._clampBossEnabled) and true or false
    NP.layout.UpdateWorldFrameHeight(wantExtended)

    E.SyncEnemyClassColorCVar()
    if not skipStackingCVar then
        E.SyncRetailStackingCVars()
    end
    E.SyncShowVKeyCastbarCVar()
    E.SyncThreatCVar()
    if not NP.module._retailBehavior then
        NP.layout.ResetRetailStacking()
    end
end

-- Single OnUpdate driver

local function EngineOnUpdate(_, elapsed)
    if not NP.config.IsModuleEnabled() or not NP.module.applied then return end

    -- Engine tick counter for per-frame memoization.
    NP.module._engineFrame = (NP.module._engineFrame or 0) + 1

    if NP.quest and NP.quest.TickDeferredRebuild then
        NP.quest.TickDeferredRebuild(NP.module._engineFrame)
    end

    -- 0. Castbar progress on active plates.
    NP.castbar.TickAllPlateCastBars()

    local hasTarget = UnitExists("target") and true or false

    -- 1. Harvest native alpha, then force plate root to 1 when target exists.
    -- retailCfg hoisted out of per-plate path (was 40 GetCfg/frame).
    -- awesome_wotlk: skip forcing alpha to 1 (stock dims non-target plates; awesome manages alpha/LoS).
    -- nameplateAlphaCompat: skip forcing alpha to 1 for addons that read native plate alpha as target identity.
    local skipAlphaForce = C_NamePlate ~= nil or NP.module._plateAlphaCompat
    local retailBehavior = NP.module._retailBehavior
    local retailCfg = retailBehavior and NP.config.GetCfg() or nil
    local levelSettleNow = GetTime and GetTime() or 0
    -- Single roster pass (was three pairs() sweeps).
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
        if retailBehavior then
            NP.layout.ApplyRetailPlateScale(pd, NP.identity.IsTargetPlateVisual(pd, hasTarget), retailCfg)
        elseif pd._retailScale or pd._pendingRetailScale then
            NP.layout.SetRetailPlateScale(pd, 1)
        end
        if pd._levelSettleAt and levelSettleNow >= pd._levelSettleAt then
            pd._levelSettleAt = nil
            NP.gather.RefreshPlateName(pd, "level_settle")
        end
    end

    -- 2. Deferred queues.
    E.ProcessQueues()

    if NP.module._deferredTargetResolveFrames and NP.module._deferredTargetResolveFrames > 0 then
        NP.module._deferredTargetResolveFrames = NP.module._deferredTargetResolveFrames - 1
        if NP.module._deferredTargetResolveFrames == 0 then
            NP.identity.UpdateTargetContext()
            E.QueueMass(CB.OnUpdateNameplate)
        end
    end

    -- 3. Identity transitions (target / mouseover / focus / threat).
    NP.identity.ProcessContextTransitions()

    -- Client re-reveals native chrome on hover/target; name+level+bar fill on any plate.
    if NP.module.targetPlate then
        NP.discovery.ReassertHotChrome(NP.module.targetPlate)
    end
    if NP.module.mouseoverPlate and NP.module.mouseoverPlate ~= NP.module.targetPlate then
        NP.discovery.ReassertHotChrome(NP.module.mouseoverPlate)
    end
    for _, pd in pairs(NP.module.plates) do
        local pl = pd.plate
        if pl and pl.IsShown and pl:IsShown() then
            NP.discovery.ReassertNativeFontChrome(pd)
            -- Reassert native health-bar hide (cheap SetAlpha or texture-only if bar-compat on).
            NP.native_style.NeutralizeStatusBarVisual(pd.healthBar)
        end
    end

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
    if NP.auras and NP.auras.TickPreview then
        NP.auras.TickPreview()
    end

    if NP.module._layoutPending and not InCombatLockdown() then
        NP.layout.FlushPendingPlateLayout()
    end

    -- 5. Stacking and clamping.
    NP.layout.UpdateStacking()

    -- 6. Depth sort (50ms throttle).
    NP.layout.UpdateDepthOrdering(elapsed)

    -- 7. Visual alpha on shown plates only; hidden re-apply on first tick after show.
    if NP.module._opacityEnabled then
        local fullParty = NP.module._opacityFullParty
        for _, pd in pairs(NP.module.plates) do
            local pl = pd.plate
            if pl and pl.IsShown and pl:IsShown() then
                local visualAlpha = NP.module._opacityValue
                if NP.identity.IsTargetPlateVisual(pd, hasTarget)
                    or ((not hasTarget) and NP.module._opacityFullNoTarget)
                    or (fullParty and NP.gather.IsGroupMemberPlate(pd)) then
                    visualAlpha = 1.0
                end
                NP.layout.SetPlateVisualAlpha(pd, visualAlpha)
            end
        end
    else
        for _, pd in pairs(NP.module.plates) do
            local pl = pd.plate
            if pl and pl.IsShown and pl:IsShown() then
                NP.layout.SetPlateVisualAlpha(pd, 1.0)
            end
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
        E.SyncConfigSnapshot(true)
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
        if NP.quest and NP.quest.OnMouseover then
            NP.quest.OnMouseover()
        end
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
    if event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        if NP.quest and NP.quest.OnQuestLogChanged then
            NP.quest.OnQuestLogChanged()
        end
        return
    end
    if event == "LOOT_OPENED" then
        if NP.quest and NP.quest.OnLootOpened then
            NP.quest.OnLootOpened()
        end
        return
    end
    if event == "PLAYER_TOTEM_UPDATE" then
        NP.widgets.OnTotemUpdate(unit)
        E.QueueMass(CB.OnUpdateNameplate)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        E.UpdateInstanceContext()
        E.SyncRetailStackingCVars()
        E.UpdatePartyArenaTokenMaps()
        NP.widgets.RefreshAllOwnTotems()
        if NP.module.inArena and NP.identity.UpdateArenaCastBindings then
            NP.identity.UpdateArenaCastBindings()
        end
        NP.identity.RefreshGroupTargetMatches()
        NP.auras.PruneCaches()
        if NP.tap then
            NP.tap.PruneCache()
        end
        if NP.module._clampBossEnabled then
            E.QueueMass(CB.OnUpdateNameplate)
        end
        E.QueueMass(CB.OnUpdateCastbar)
        if NP.quest_coexist and NP.quest_coexist.Check then
            NP.quest_coexist.Check()
        end
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
    -- awesome_wotlk only; no-op on stock 3.3.5a (4 Hz poll remains).
    -- NAME_PLATE_CREATED: unitless frame with wrong bar color — register only, do not style.
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
    -- NAME_PLATE_UNIT_ADDED: valid reaction color; style here instead of next poll.
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
            -- Style immediately (no OnShow re-entrancy); avoids 1-frame native chrome flash.
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
        if NP.tap then
            NP.tap.PruneCache()
        end
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
        -- Gate CLEU once via exported event sets and config snapshot.
        local timestamp = unit
        local subevent = ...
        if NP.auras.AURA_COMBATLOG_EVENTS[subevent] then
            NP.auras.HandleCombatLog(timestamp, ...)
        end
        if NP.module._cleuCastbarEnabled then
            if NP.castbar.CAST_BREAK_EVENTS[subevent] then
                NP.castbar.HandleCombatLogCastBreak(timestamp, ...)
            end
            if NP.module._cleuCastMonitorActive
                and (NP.castbar.CAST_MONITOR_CLEU_EVENTS[subevent]
                    or NP.castbar.CLEU_WARMUP_EVENTS[subevent]) then
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
        -- ResolvePlateUnit only covers target/focus/mouseover; skip O(n) scan for other units.
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

-- Re-run on every apply: RegisterEvent is idempotent, and restore unregisters the whole set.
local function RegisterEngineEvents(f)
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
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    f:RegisterEvent("LOOT_OPENED")
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
end

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
        f:SetScript("OnEvent", EngineOnEvent)
        NP.module.eventFrame = f
    end
    RegisterEngineEvents(NP.module.eventFrame)
    NP.module.eventFrame:Show()

    if NP.clickbox and NP.clickbox.InitSecureSystem then
        NP.clickbox.InitSecureSystem()
    end
    if NP.module.playerInCombat and NP.clickbox and NP.clickbox.OnCombatStart then
        NP.clickbox.OnCombatStart()
    end

    NP.module.applied = true
    NP.module.initialized = true
    NP.state.BindPersistentAuraDurations()
    NP.widgets.RefreshAllOwnTotems()
    NP.lifecycle.ScanNameplates()
    E.QueueMass(CB.OnUpdateNameplate)
end

local function RunNameplatesRestore()
    -- Disable hook dispatch before restore (HookScript callbacks are permanent).
    NP.module.applied = false
    if NP.module.scannerFrame then
        NP.module.scannerFrame:SetScript("OnUpdate", nil)
        NP.module.scannerFrame:Hide()
    end
    if NP.module.eventFrame then
        -- Hidden frames still fire OnEvent; unregister so CLEU stops dispatching while disabled.
        NP.module.eventFrame:UnregisterAllEvents()
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
    if NP.module.savedNameplateSmoothStacking ~= nil and SetCVar then
        SetCVar("nameplateSmoothStacking", NP.module.savedNameplateSmoothStacking)
    end
    NP.module.threatCVarApplied = nil
    NP.module.savedThreatWarning = nil
    NP.module.classColorCVarApplied = nil
    NP.module.savedShowClassColorInNameplate = nil
    NP.module.showVKeyCVarManaged = nil
    NP.module.savedShowVKeyCastbar = nil
    NP.module.savedNameplateAllowOverlap = nil
    NP.module.savedNameplateSmoothStacking = nil

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
    if NP.state.PlateTapCache then
        for guid in pairs(NP.state.PlateTapCache) do
            NP.state.PlateTapCache[guid] = nil
        end
    end
    for guid in pairs(NP.auras.DRState or {}) do
        NP.auras.DRState[guid] = nil
    end
    for name in pairs(NP.state.AuraGUIDByName) do
        NP.state.AuraGUIDByName[name] = nil
    end
    if NP.quest and NP.quest.ClearIndex then
        NP.quest.ClearIndex()
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
    NP.module._clickboxSliderAutoShow = nil
    NP.module._clickboxSliderIdleUntil = nil
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
                addon.db.RegisterCallback(NP, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(NP, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(NP, "OnProfileReset", OnProfileChanged)
            end
        end)
    end
end)

if addon.core and addon.core.RegisterMessage then
    addon.core.RegisterMessage(NP, "DRAGONUI_READY", BootstrapNameplates)
end
