local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates gather: read native regions, apply visuals.
-- Native regions are read-only; reaction from bar color. Visual alpha owned by engine.

NP.gather = NP.gather or {}

-- Snapshot (read-only native sampling)

function NP.gather.GatherPlateSnapshot(plateData, reason, hpValue)
    local healthBar = plateData.healthBar
    local healthCur = hpValue
    local healthMin, healthMax
    if healthBar and healthBar.GetMinMaxValues then
        healthMin, healthMax = healthBar:GetMinMaxValues()
    end
    if healthCur == nil and healthBar and healthBar.GetValue then
        healthCur = healthBar:GetValue()
    end

    local nativeAlpha = plateData._nativeAlpha
    local plate = plateData.plate
    if nativeAlpha == nil and plate and plate.GetAlpha then
        nativeAlpha = plate:GetAlpha()
    end

    return {
        reason = reason,
        plateName = NP.discovery.GetPlateName(plateData),
        plateGUID = NP.state.GetPlateGUID(plateData),
        healthCur = healthCur,
        healthMin = healthMin,
        healthMax = healthMax,
        nativeAlpha = nativeAlpha,
        targetGUID = UnitGUID("target"),
        mouseoverGUID = UnitGUID("mouseover"),
        targetExists = UnitExists("target") == 1,
        mouseoverExists = UnitExists("mouseover") == 1,
        raidIconVisible = plateData.raidIcon and plateData.raidIcon.IsShown
            and plateData.raidIcon:IsShown() or false,
        castVisible = plateData.castBar and plateData.castBar.IsShown
            and plateData.castBar:IsShown() or false,
    }
end

-- Identity invalidation and fresh bar color capture.
function NP.gather.PreparePlateForRefresh(plateData, snapshot)
    -- Invalidate gate memos before identity/color/config may change.
    NP.gather.InvalidatePlateGates(plateData)
    local freshName = snapshot.plateName
    NP.native_style.ResetPlateEliteIfIdentityChanged(plateData, freshName)
    NP.castbar.ResetPlateCastIfIdentityChanged(plateData, freshName)
    NP.gather.ResetPlateDebuffsIfIdentityChanged(plateData, freshName)
    if freshName then
        plateData.plateName = freshName
        NP.castbar.NotePlateNameForPetSnapshot(plateData, freshName)
    end
    NP.native_style.CaptureBarColor(plateData)
    NP.identity.UpdatePlateUnitToken(plateData)
    if NP.module.inArena and NP.identity.UpdateArenaCastBindingForPlate then
        NP.identity.UpdateArenaCastBindingForPlate(plateData)
    end

    if not plateData.guid then
        NP.identity.TryMatchGUID(plateData)
        snapshot.plateGUID = NP.state.GetPlateGUID(plateData)
    end
end

function NP.gather.ResetPlateDebuffsIfIdentityChanged(plateData, freshName)
    if not plateData or not freshName then return end
    if plateData._debuffIdentityName and plateData._debuffIdentityName ~= freshName then
        NP.state.ClearPlateGUID(plateData)
        NP.state.HidePlateDebuffs(plateData)
    end
    plateData._debuffIdentityName = freshName
end

-- Context and visual state

function NP.gather.ResolveContext(plateData, snapshot, reason)
    if snapshot then
        if snapshot.targetGUID ~= NP.identity.GetTargetGUID()
            or (snapshot.targetExists and not NP.identity.GetTargetPlate()) then
            NP.identity.UpdateTargetContext()
        end
        if snapshot.mouseoverGUID ~= NP.identity.GetMouseoverGUID()
            or (snapshot.mouseoverExists and not NP.identity.GetMouseoverPlate()) then
            NP.identity.UpdateMouseoverContext()
        end
    end

    local resolvedUnit = NP.identity.GetUnitForPlate(plateData)
    local isTarget = NP.identity.IsTargetPlate(plateData)
    return {
        reason = reason,
        plateGUID = NP.state.GetPlateGUID(plateData),
        resolvedUnit = resolvedUnit,
        isTarget = isTarget,
        isMouseover = NP.identity.IsMouseoverPlate(plateData),
        classification = NP.native_style.ResolvePlateClassification(plateData, resolvedUnit),
    }
end

function NP.gather.ComputeVisualState(plateData, snapshot, context, reason)
    local npCfg = NP.config.GetCfg()
    -- Headline mode hides power and cast bars (health is hidden in SyncHealth).
    local nameOnly = NP.gather.IsHeadlineActive(plateData)
    return {
        reason = reason,
        showPower = (not nameOnly) and (npCfg.showPowerBar ~= false),
        showDebuffs = npCfg.showDebuffs ~= false,
        showCastbar = (not nameOnly) and (npCfg.showCastBar ~= false),
        showTargetHighlight = NP.identity.IsTargetPlateVisual(plateData),
    }
end

function NP.gather.BuildPlateState(plateData, reason, hpValue)
    local snapshot = NP.gather.GatherPlateSnapshot(plateData, reason, hpValue)
    NP.gather.PreparePlateForRefresh(plateData, snapshot)
    local context = NP.gather.ResolveContext(plateData, snapshot, reason)
    local state = NP.gather.ComputeVisualState(plateData, snapshot, context, reason)
    return snapshot, context, state
end

-- Style application

local function BuildLayoutSignature(plateData)
    local isPlayer = NP.gather.IsPlayerPlate(plateData) and "p" or "n"
    return tostring(NP.module._cfgRev or 0) .. ":" .. isPlayer
end

local function ComputeTotemIconOnlyActive(plateData)
    local cfg = NP.config.GetCfg()
    if cfg.totemIconOnly ~= true or cfg.showTotemIcons == false then
        return false
    end
    local plateName = plateData.plateName or NP.discovery.GetPlateName(plateData)
    if not plateName or not NP.widgets.IsTotemName(plateName) then
        return false
    end
    if NP.widgets.GetTotemMode and NP.widgets.GetTotemMode(plateName) == "normal" then
        return false
    end
    local ownInfo = NP.widgets.FindOwnTotemForName and NP.widgets.FindOwnTotemForName(plateName)
    if ownInfo and ownInfo.icon then
        return true
    end
    return NP.widgets.ResolveTotemTexturePath(plateName) ~= nil
end

-- Totem icon-only (hide bar/name/cast); memoized per tick, busted on input change.
function NP.gather.IsTotemIconOnlyActive(plateData)
    if not plateData then return false end
    local tick = NP.module._engineFrame
    if tick and plateData._totemOnlyTick == tick then
        return plateData._totemOnlyVal
    end
    local result = ComputeTotemIconOnlyActive(plateData) and true or false
    if tick then
        plateData._totemOnlyTick = tick
        plateData._totemOnlyVal = result
    end
    return result
end

function NP.gather.InvalidatePlateGates(plateData)
    if plateData then
        plateData._totemOnlyTick = nil
        plateData._headlineTick = nil
    end
end

function NP.gather.EnsurePlateVisualRoot(plateData, state, context)
    -- Reapply chrome suppression on every full refresh; subsequent calls are idempotent.
    NP.discovery.SuppressNativeChrome(plateData)
    NP.layout.EnsureMinaStack(plateData)
    local sig = BuildLayoutSignature(plateData)
    if plateData._layoutSig ~= sig then
        plateData._layoutSig = sig
        NP.layout.LayoutMinaStack(plateData)
    end
end

-- Module-scoped sync lists to avoid per-refresh allocation.
local FULL_SYNC_WIDGETS = {
    "Debuffs",
    "ThreatGlow",
    "RaidMarker",
    "Elite",
    "Combo",
    "Totem",
    "TargetHighlight",
}
local TARGET_SYNC_WIDGETS = {
    "Debuffs",
    "ThreatGlow",
    "Elite",
    "Combo",
    "TargetHighlight",
}

function NP.gather.ApplyVisualState(plateData, snapshot, context, state, reason)
    NP.gather.EnsurePlateVisualRoot(plateData, state, context)

    NP.gather.SyncHealth(plateData, snapshot.healthCur)
    NP.gather.SyncPower(plateData, state.showPower and context.resolvedUnit or nil)
    NP.gather.SyncName(plateData, context.resolvedUnit)
    NP.widgets.SyncList(FULL_SYNC_WIDGETS, plateData, context, state)
    if state.showCastbar and NP.castbar.ShouldSkipCastSync(plateData) then
        NP.castbar.HideNativeCastVisual(plateData)
        NP.layout.LayoutCastBarStack(plateData)
    elseif state.showCastbar then
        NP.castbar.SyncCastBar(plateData)
    else
        NP.castbar.HidePlateCastBar(plateData)
    end
end

-- Health, power, name sync

local function GetPartyUnitForPlate(plateData)
    if not plateData.plateName then
        return nil
    end
    local name = plateData.plateName
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        if UnitExists(unit) and NP.native_style.StripRealm(UnitName(unit)) == name then
            return unit
        end
    end
    return nil
end

-- Resolve group unit by name (~0.3s cache); realm-unique player names are reliable identifiers.
function NP.gather.GetGroupUnitForPlate(plateData)
    local name = plateData and plateData.plateName
    if not name then
        return nil
    end
    local now = GetTime and GetTime() or 0
    local cached = plateData._groupUnit
    if cached and plateData._groupUnitProbeAt and now < plateData._groupUnitProbeAt
        and UnitExists(cached) and NP.native_style.StripRealm(UnitName(cached)) == name then
        return cached
    end
    plateData._groupUnitProbeAt = now + 0.3
    plateData._groupUnit = nil
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local unit = "raid" .. i
            if UnitExists(unit) and NP.native_style.StripRealm(UnitName(unit)) == name then
                plateData._groupUnit = unit
                return unit
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            if UnitExists(unit) and NP.native_style.StripRealm(UnitName(unit)) == name then
                plateData._groupUnit = unit
                return unit
            end
        end
    end
    return nil
end

-- True for friendly player plates matched to a party/raid unit; excludes pets and NPCs.
function NP.gather.IsGroupMemberPlate(plateData)
    if not plateData then
        return false
    end
    local reaction, unitType = NP.native_style.GetPlateReaction(plateData)
    if reaction ~= "FRIENDLY" or unitType ~= "PLAYER" then
        return false
    end
    return NP.gather.GetGroupUnitForPlate(plateData) ~= nil
end

-- Headline mode for party/raid: name only; reaction checked before group lookup.
function NP.gather.IsFriendlyNameOnlyActive(plateData)
    if not plateData then
        return false
    end
    local cfg = NP.config.GetCfg()
    if cfg.friendlyNameOnly ~= true then
        return false
    end
    local reaction, unitType = NP.native_style.GetPlateReaction(plateData)
    if reaction ~= "FRIENDLY" or unitType ~= "PLAYER" then
        return false
    end
    -- "All friendly players" is a superset of party/raid and works on stock
    -- 3.3.5a (reaction comes from the bar color, no unit token needed).
    if cfg.friendlyNameOnlyAll == true then
        return true
    end
    if cfg.friendlyNameOnlyParty ~= false then
        return NP.gather.GetGroupUnitForPlate(plateData) ~= nil
    end
    return false
end

-- Headline mode for friendly NPCs; title subtitle needs awesome_wotlk (tooltip scan needs token).
function NP.gather.IsFriendlyNPCNameOnlyActive(plateData)
    if not plateData then
        return false
    end
    local cfg = NP.config.GetCfg()
    if cfg.friendlyNameOnly ~= true or cfg.friendlyNPCNameOnly ~= true then
        return false
    end
    local reaction, unitType = NP.native_style.GetPlateReaction(plateData)
    return reaction == "FRIENDLY" and unitType == "NPC"
end

local function ComputeHeadlineActive(plateData)
    if not (NP.gather.IsFriendlyNameOnlyActive(plateData)
        or NP.gather.IsFriendlyNPCNameOnlyActive(plateData)) then
        return false
    end
    local cfg = NP.config.GetCfg()
    if cfg.headlineExcludeTarget and NP.identity.IsTargetPlate(plateData) then
        return false
    end
    return true
end

-- Headline suppression gate (players + NPCs); excludes target when configured.
-- Memoized per tick; PreparePlateForRefresh busts on target transition.
function NP.gather.IsHeadlineActive(plateData)
    if not plateData then return false end
    local tick = NP.module._engineFrame
    if tick and plateData._headlineTick == tick then
        return plateData._headlineVal
    end
    local result = ComputeHeadlineActive(plateData) and true or false
    if tick then
        plateData._headlineTick = tick
        plateData._headlineVal = result
    end
    return result
end

-- Subtitle tooltip; stock resolves on target/mouseover only, awesome_wotlk resolves all plates.
local SubtitleScanTip = CreateFrame("GameTooltip", "DragonUINPSubtitleScan", UIParent, "GameTooltipTemplate")
SubtitleScanTip:SetOwner(UIParent, "ANCHOR_NONE")

-- Best-effort unit token for a plate, preferring the most stable source.
local function ResolvePlateToken(plateData)
    local groupUnit = NP.gather.GetGroupUnitForPlate(plateData)
    if groupUnit then
        return groupUnit
    end
    local resolved = NP.identity.ResolvePlateUnit(plateData)
    if resolved and UnitExists(resolved) then
        return resolved
    end
    local native = plateData.namePlateUnitToken or (plateData.plate and plateData.plate.unit)
    if native and UnitExists(native) then
        return native
    end
    return nil
end

-- Static subtitle (guild/title); nil until resolvable, then cached.
function NP.gather.GetPlateSubtitleText(plateData, unit)
    local cfg = NP.config.GetCfg()
    unit = unit or ResolvePlateToken(plateData)
    if not (unit and UnitExists(unit)) then
        return nil
    end
    if NP.gather.IsFriendlyNameOnlyActive(plateData) then
        if cfg.friendlyNameOnlyGuild then
            local guild = GetGuildInfo(unit)
            if guild and guild ~= "" then
                return "<" .. guild .. ">"
            end
        end
    elseif NP.gather.IsFriendlyNPCNameOnlyActive(plateData) then
        if cfg.friendlyNPCNameOnlyTitle then
            SubtitleScanTip:ClearLines()
            SubtitleScanTip:SetUnit(unit)
            if SubtitleScanTip:NumLines() >= 2 then
                local line2 = _G["DragonUINPSubtitleScanTextLeft2"]
                local txt = line2 and line2.GetText and line2:GetText()
                -- Line 2 holds the subname only when it is not the "Level X ..." line.
                if txt and txt ~= "" and not txt:find("%d") and not txt:find(LEVEL or "Level") then
                    if not txt:find("^<") then
                        txt = "<" .. txt .. ">"
                    end
                    return txt
                end
            end
        end
    end
    return nil
end

-- Friendly player name including the current title via UnitPVPName
-- (e.g. "Arthas Jenkins"). Returns nil when not resolvable yet.
function NP.gather.GetPlateTitleName(plateData, unit)
    unit = unit or ResolvePlateToken(plateData)
    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        local pvp = UnitPVPName(unit)
        if pvp and pvp ~= "" then
            return NP.native_style.StripRealm(pvp)
        end
    end
    return nil
end

function NP.gather.IsPlayerPlate(plateData)
    local unit = NP.identity.ResolvePlateUnit(plateData)
    if unit then
        return UnitIsPlayer(unit) and true or false
    end
    local classKey = plateData and plateData.classKey
    if classKey and classKey ~= "FRIENDLY_PLAYER" then
        return RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey] ~= nil
    end
    return classKey == "FRIENDLY_PLAYER"
end

-- Health color: tap denied > raid marker tint > aggro tint > friendly overrides > native bar.
function NP.gather.GetHealthBarColor(plateData)
    local cfg = NP.config.GetCfg()
    -- cfg gate first: disabled = zero tap work on the SyncHealth hot path.
    if cfg.tapDeniedGray ~= false and NP.tap and NP.tap.IsTapDenied(plateData) then
        return NP.tap.GetTapDeniedColor()
    end
    if cfg.raidMarkHealthColor then
        local markName = NP.native_style.GetPlateRaidIconName(plateData)
        local markColor = markName and C.RAID_MARK_HEALTH_COLORS[markName]
        if markColor then
            return markColor[1], markColor[2], markColor[3]
        end
    end

    local aggroR, aggroG, aggroB = NP.threat.GetAggroBarTint(plateData)
    if aggroR then
        return aggroR, aggroG, aggroB
    end

    local reaction, unitType = NP.native_style.GetPlateReaction(plateData)
    if reaction == "FRIENDLY" and unitType == "PLAYER"
        and plateData.barB
        and plateData.barB > 0.5 and (plateData.barR or 0) < 0.3 and (plateData.barG or 0) < 0.3 then
        -- Friendly class color from any resolved token; cached, fills in on hover/target in stock.
        if cfg.friendlyClassColors then
            if not plateData._friendlyHealthClass then
                local token = ResolvePlateToken(plateData)
                if token and UnitExists(token) and UnitIsPlayer(token) then
                    local _, class = UnitClass(token)
                    if class then
                        plateData._friendlyHealthClass = class
                    end
                end
            end
            local cc = plateData._friendlyHealthClass and RAID_CLASS_COLORS
                and RAID_CLASS_COLORS[plateData._friendlyHealthClass]
            if cc then
                return cc.r, cc.g, cc.b
            end
        end
        if cfg.partyClassColors then
            local partyUnit = GetPartyUnitForPlate(plateData)
            if partyUnit then
                local _, class = UnitClass(partyUnit)
                if class and RAID_CLASS_COLORS[class] then
                    return RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
                end
            end
        end
        if cfg.friendlyPlayerColor then
            return cfg.friendlyPlayerColor.r, cfg.friendlyPlayerColor.g, cfg.friendlyPlayerColor.b
        end
    end
    if reaction == "FRIENDLY" and unitType == "NPC" and cfg.friendlyNPCColor then
        return cfg.friendlyNPCColor.r, cfg.friendlyNPCColor.g, cfg.friendlyNPCColor.b
    end
    if plateData.barR then
        return plateData.barR, plateData.barG, plateData.barB
    end
    return 1, 0.1, 0.1
end

function NP.gather.SyncHealth(plateData, value)
    local src = plateData.healthBar
    local bar = plateData.minaHp
    if not src or not bar then return end

    if NP.gather.IsTotemIconOnlyActive(plateData) then
        bar:Hide()
        if plateData.minaHpPct then plateData.minaHpPct:Hide() end
        return
    end

    -- Headline mode: no health bar, only the name (see SyncName).
    if NP.gather.IsHeadlineActive(plateData) then
        bar:Hide()
        if plateData.minaHpPct then plateData.minaHpPct:Hide() end
        return
    end

    local minVal, maxVal = src:GetMinMaxValues()
    local cur = value or src:GetValue()
    bar:SetMinMaxValues(minVal, maxVal)
    bar:SetValue(cur)

    local r, g, b = NP.gather.GetHealthBarColor(plateData)
    bar:SetStatusBarColor(r, g, b, 1)
    bar:Show()

    local cfg = NP.config.GetCfg()
    local showHpNum = cfg.showHealthNumber == true
    -- Guard SetText on unchanged health values.
    if showHpNum and maxVal and maxVal > 0 then
        if plateData.minaHpPct then plateData.minaHpPct:Hide() end
        if plateData.minaHpNum then
            if plateData._lastHpNumValue ~= cur then
                plateData._lastHpNumValue = cur
                local abbr = addon.TextSystem and addon.TextSystem.AbbreviateLargeNumbers(cur) or tostring(math.floor(cur))
                plateData.minaHpNum:SetText(abbr)
            end
            plateData.minaHpNum:Show()
        end
        if plateData.minaHpBarPct then
            local pct = math.floor(cur / maxVal * 100 + 0.5)
            if plateData._lastHpBarPct ~= pct then
                plateData._lastHpBarPct = pct
                plateData.minaHpBarPct:SetText(pct .. "%")
            end
            plateData.minaHpBarPct:Show()
        end
    else
        if plateData.minaHpNum then plateData.minaHpNum:Hide() end
        if plateData.minaHpBarPct then plateData.minaHpBarPct:Hide() end
        if plateData.minaHpPct and cfg.showHealthPercent ~= false and cfg.centerNameOnly ~= true then
            if maxVal and maxVal > 0 then
                local pct = math.floor(cur / maxVal * 100 + 0.5)
                if plateData._lastHpPct ~= pct then
                    plateData._lastHpPct = pct
                    plateData.minaHpPct:SetText(pct .. "%")
                end
                plateData.minaHpPct:Show()
            else
                plateData.minaHpPct:Hide()
            end
        elseif plateData.minaHpPct then
            plateData.minaHpPct:Hide()
        end
    end
end

local function HidePowerBar(plateData)
    if plateData.minaPo then plateData.minaPo:Hide() end
    if plateData.minaPoCur then plateData.minaPoCur:Hide() end
    if plateData.minaPoPct then plateData.minaPoPct:Hide() end
end

function NP.gather.SyncPower(plateData, unit)
    local bar = plateData.minaPo
    if not bar then return end

    local function finish()
        NP.layout.RelayoutCastStack(plateData)
    end

    if NP.gather.IsTotemIconOnlyActive(plateData) then
        HidePowerBar(plateData)
        finish()
        return
    end

    local cfg = NP.config.GetCfg()
    if cfg.showPowerBar == false then
        HidePowerBar(plateData)
        finish()
        return
    end

    unit = unit or NP.identity.ResolvePlateUnit(plateData)
    if not unit or not UnitExists(unit) then
        HidePowerBar(plateData)
        finish()
        return
    end

    if unit == "target" and not NP.identity.IsTargetPlate(plateData) then
        HidePowerBar(plateData)
        finish()
        return
    elseif unit == "mouseover" and not NP.identity.IsMouseoverPlate(plateData) then
        HidePowerBar(plateData)
        finish()
        return
    end

    if cfg.powerPlayersOnly ~= false and UnitIsPlayer and not UnitIsPlayer(unit) then
        HidePowerBar(plateData)
        finish()
        return
    end

    local powerType, powerToken = UnitPowerType(unit)
    local cur = UnitPower(unit, powerType)
    local maxVal = UnitPowerMax(unit, powerType)
    if not maxVal or maxVal <= 0 then
        HidePowerBar(plateData)
        finish()
        return
    end

    if PowerBarColor and powerToken and PowerBarColor[powerToken] then
        local c = PowerBarColor[powerToken]
        bar:SetStatusBarColor(c.r, c.g, c.b, 1)
    end

    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(cur)
    bar:Show()

    if plateData.minaPoCur then
        if cfg.showPowerBarText ~= false then
            if plateData._lastPoCurValue ~= cur then
                plateData._lastPoCurValue = cur
                plateData.minaPoCur:SetText(tostring(cur))
            end
            plateData.minaPoCur:Show()
        else
            plateData._lastPoCurValue = nil
            plateData.minaPoCur:SetText("")
            plateData.minaPoCur:Hide()
        end
    end
    if plateData.minaPoPct then
        if cfg.showPowerBarText ~= false then
            local pct = math.floor(cur / maxVal * 100 + 0.5)
            if plateData._lastPoPct ~= pct then
                plateData._lastPoPct = pct
                plateData.minaPoPct:SetText(pct .. "%")
            end
            plateData.minaPoPct:Show()
        else
            plateData._lastPoPct = nil
            plateData.minaPoPct:SetText("")
            plateData.minaPoPct:Hide()
        end
    end
    finish()
end

-- Native level text snapshot for a plate (settle-gated; "??" for boss plates).
local function ReadNativeLevelSnapshot(plateData)
    local nativeBoss = plateData.bossIcon and plateData.bossIcon.IsShown and plateData.bossIcon:IsShown()
    if nativeBoss then
        -- Recycled plates may show stale numeric level beside boss skull.
        return "??"
    end
    -- Use cached level when available; settle window protects recycled-plate fallback read.
    if plateData.plateLevel and plateData._plateLevelName == plateData.plateName then
        return plateData.plateLevel
    end
    local now = GetTime and GetTime() or 0
    local shownAt = plateData._shownAt or 0
    local settle = (NP.const and NP.const.LEVEL_TEXT_SETTLE) or 0.15
    if now < shownAt + settle then
        return nil
    end
    local lvlText = plateData.levelText
    local raw = nil
    if lvlText and lvlText.GetText then
        raw = lvlText:GetText()
        if raw == "" then
            raw = nil
        end
    end
    if raw then
        return raw
    end
    return nil
end

function NP.gather.SyncName(plateData, unit)
    if not plateData.minaName then return end
    if NP.gather.IsTotemIconOnlyActive(plateData) then
        plateData.minaName:Hide()
        if plateData.minaBossSkull then plateData.minaBossSkull:Hide() end
        if plateData.minaHpPct then plateData.minaHpPct:Hide() end
        if plateData.minaSubTitle then plateData.minaSubTitle:Hide() end
        return
    end
    local bossSkullSize = 14
    local bossSkullGap = -1
    local bossSkullNameLeftShift = 0
    unit = unit or NP.identity.ResolvePlateUnit(plateData)
    local cfg = NP.config.GetCfg()
    local headline = NP.gather.IsHeadlineActive(plateData) -- players or NPCs (false for excluded target)
    local nameOnly = headline and NP.gather.IsFriendlyNameOnlyActive(plateData) -- friendly PLAYER headline
    -- Resolve headline data even when headlineExcludeTarget; ready on un-target.
    local nameOnlyResolve = NP.gather.IsFriendlyNameOnlyActive(plateData)
    local centerOnly = cfg.centerNameOnly == true or headline
    local suppressLevel = headline  -- centerNameOnly alone no longer hides level

    local displayUnit = nil
    if suppressLevel then
        displayUnit = nil
    elseif cfg.showLevelAlways then
        displayUnit = unit
    elseif unit == "target" then
        if NP.identity.IsTargetPlate(plateData) and cfg.showLevelInName ~= false then
            displayUnit = unit
        end
    end
    local plateHover = plateData.plate and plateData.plate.IsMouseOver and plateData.plate:IsMouseOver() or false
    local hoverEligible = NP.identity.IsMouseoverPlate(plateData)
        or (NP.identity.IsTargetPlate(plateData) and plateHover)
    if not displayUnit and cfg.showLevelOnHover ~= false and hoverEligible then
        displayUnit = unit
    end
    local showLevelPrefix = not suppressLevel and ((displayUnit ~= nil) or (cfg.showLevelAlways == true))
    local levelUnit = nil
    if showLevelPrefix then
        if displayUnit and UnitExists(displayUnit) then
            levelUnit = displayUnit
        else
            local token = NP.identity.UpdatePlateUnitToken(plateData)
            if token and UnitExists(token) then
                levelUnit = token
            end
        end
    end
    local fallbackLevel = nil
    if showLevelPrefix and not levelUnit then
        fallbackLevel = ReadNativeLevelSnapshot(plateData)
    end
    if levelUnit then
        plateData._levelSettleAt = nil
    end
    local showsBossSkull = false
    if showLevelPrefix then
        if levelUnit then
            showsBossSkull = NP.native_style.IsBossLevel(UnitLevel(levelUnit))
        else
            showsBossSkull = NP.native_style.IsBossLevel(fallbackLevel)
        end
    end

    local r, g, b = 1, 1, 1
    local classKey = plateData.classKey
    local classColor = classKey and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]
    local isEnemyPlayer = classColor and classKey ~= "FRIENDLY_PLAYER"
    local allowEnemyNameClass = cfg.enemyPlayerClassColors ~= false and cfg.enemyNameClassColors == true
    if cfg.nameReactionColors then
        r, g, b = NP.gather.GetHealthBarColor(plateData)
        if isEnemyPlayer then
            if allowEnemyNameClass then
                r, g, b = classColor.r, classColor.g, classColor.b
            else
                r, g, b = 1, 0.1, 0.1
            end
        end
    elseif isEnemyPlayer and allowEnemyNameClass then
        r, g, b = classColor.r, classColor.g, classColor.b
    end
    -- Headline mode base name color (white by default); class color overrides it
    -- below when enabled and resolved.
    if headline then
        local nc = cfg.friendlyNameOnlyColor
        if nc then
            r, g, b = nc.r or 1, nc.g or 1, nc.b or 1
        else
            r, g, b = 1, 1, 1
        end
    end
    -- Resolve headline class color even when headlineExcludeTarget; ready on un-target.
    if nameOnlyResolve and cfg.friendlyNameOnlyClassColor and not plateData._headlineClass then
        local token = ResolvePlateToken(plateData)
        if token and UnitExists(token) and UnitIsPlayer(token) then
            local _, class = UnitClass(token)
            if class then plateData._headlineClass = class end
        end
    end
    if nameOnly and cfg.friendlyNameOnlyClassColor then
        local cc = plateData._headlineClass and RAID_CLASS_COLORS
            and RAID_CLASS_COLORS[plateData._headlineClass]
        if cc then r, g, b = cc.r, cc.g, cc.b end
    end
    local displayName
    if showLevelPrefix then
        displayName = NP.discovery.FormatPlateName(plateData, levelUnit, fallbackLevel)
    else
        displayName = plateData.plateName or "?"
    end
    -- Headline mode: optionally show the player's title inline (UnitPVPName), e.g.
    -- "Arthas Jenkins". Resolved lazily from any available token and cached.
    if nameOnlyResolve and cfg.friendlyNameOnlyTitle and not plateData._pvpTitleName then
        local titled = NP.gather.GetPlateTitleName(plateData, unit)
        if titled then plateData._pvpTitleName = titled end
    end
    if nameOnly and cfg.friendlyNameOnlyTitle and plateData._pvpTitleName then
        displayName = plateData._pvpTitleName
    end
    if plateData.minaBossSkull and plateData.minaBossSkull.SetSize then
        plateData.minaBossSkull:SetSize(bossSkullSize, bossSkullSize)
        if showsBossSkull then
            plateData.minaBossSkull:Show()
        else
            plateData.minaBossSkull:Hide()
        end
    end
    if plateData.minaNameRow and plateData.minaName.SetPoint and plateData.minaName.ClearAllPoints then
        if centerOnly then
            local visW = select(1, NP.config.GetBarRefSize())
            plateData._nameBossShift = nil
            -- Skip re-anchor when already centered at this width.
            if plateData._nameCenteredWidth ~= visW then
                plateData._nameCenteredWidth = visW
                plateData.minaName:SetJustifyH("CENTER")
                plateData.minaName:ClearAllPoints()
                plateData.minaName:SetPoint("CENTER", plateData.minaNameRow, "CENTER", 0, 0)
                plateData.minaName:SetWidth(visW)
            end
        else
            plateData._nameCenteredWidth = nil
            plateData.minaName:SetJustifyH("LEFT")
            local desiredOffset = 0
            if showsBossSkull then
                desiredOffset = bossSkullSize + bossSkullGap + bossSkullNameLeftShift
            end
            if plateData._nameBossShift ~= desiredOffset then
                plateData._nameBossShift = desiredOffset
                plateData.minaName:ClearAllPoints()
                plateData.minaName:SetPoint("LEFT", plateData.minaNameRow, "LEFT", desiredOffset, 0)
            end
        end
    end
    -- Skip SetTextColor/SetText when unchanged; both re-shape the font string.
    if plateData._nameTextR ~= r or plateData._nameTextG ~= g or plateData._nameTextB ~= b then
        plateData._nameTextR, plateData._nameTextG, plateData._nameTextB = r, g, b
        plateData.minaName:SetTextColor(r, g, b)
    end
    if plateData._nameTextLast ~= displayName then
        plateData._nameTextLast = displayName
        plateData.minaName:SetText(displayName)
    end
    plateData.minaName:Show()

    if plateData.minaSubTitle then
        -- Cache subtitle even when headlineExcludeTarget; ready on un-target.
        local wantStaticResolve = (nameOnlyResolve and cfg.friendlyNameOnlyGuild == true)
            or (NP.gather.IsFriendlyNPCNameOnlyActive(plateData) and cfg.friendlyNPCNameOnlyTitle == true)
        if wantStaticResolve and not plateData._subtitleText then
            local s = NP.gather.GetPlateSubtitleText(plateData, unit)
            if s then plateData._subtitleText = s end
        end

        -- Resolve AFK state whenever we have a token; display only when in headline.
        if nameOnlyResolve and cfg.friendlyNameOnlyAFK then
            local afkUnit = ResolvePlateToken(plateData)
            if afkUnit and UnitExists(afkUnit) then
                plateData._afkState = UnitIsAFK(afkUnit) and true or false
            end
        end

        local wantStatic = false
        if nameOnly then
            wantStatic = cfg.friendlyNameOnlyGuild == true
        elseif headline and NP.gather.IsFriendlyNPCNameOnlyActive(plateData) then
            wantStatic = cfg.friendlyNPCNameOnlyTitle == true
        end
        local parts = {}
        if wantStatic and plateData._subtitleText then
            parts[#parts + 1] = plateData._subtitleText
        end
        if nameOnly and cfg.friendlyNameOnlyAFK and plateData._afkState then
            parts[#parts + 1] = "<AFK>"
        end

        if #parts > 0 then
            plateData.minaSubTitle:SetText(table.concat(parts, " "))
            plateData.minaSubTitle:Show()
        else
            plateData.minaSubTitle:Hide()
        end
    end
end

function NP.gather.SyncTargetHighlight(plateData, isTargeted)
    local target = plateData.minaTarget
    if not target then return end
    local cfg = NP.config.GetCfg()

    -- Headline mode shows only the name: no target glow or arrows.
    if NP.gather.IsHeadlineActive(plateData) then
        target:Hide()
        if target.arrowL then target.arrowL:Hide() end
        if target.arrowR then target.arrowR:Hide() end
        return
    end

    if isTargeted == nil then
        isTargeted = NP.identity.IsTargetPlateVisual(plateData)
    end

    if isTargeted then
        target:Show()
        if cfg.showTargetHighlight ~= false then
            if target.tex then target.tex:Show() end
        else
            if target.tex then target.tex:Hide() end
        end
        if cfg.showTargetArrows == true then
            if target.arrowL then target.arrowL:Show() end
            if target.arrowR then target.arrowR:Show() end
        else
            if target.arrowL then target.arrowL:Hide() end
            if target.arrowR then target.arrowR:Hide() end
        end
    else
        target:Hide()
        if target.arrowL then target.arrowL:Hide() end
        if target.arrowR then target.arrowR:Hide() end
    end
end

NP.widgets.Register("TargetHighlight", {
    Ensure = function(plateData)
        return plateData and plateData.minaTarget ~= nil
    end,
    Layout = function(plateData)
        return plateData and plateData.minaHp ~= nil
    end,
    Sync = function(plateData, context, state)
        local visible = state and state.showTargetHighlight
        if visible == nil then
            visible = NP.identity.IsTargetPlateVisual(plateData)
        end
        NP.gather.SyncTargetHighlight(plateData, visible)
    end,
    Hide = function(plateData)
        local target = plateData and plateData.minaTarget
        if not target then return end
        target:Hide()
        if target.arrowL then target.arrowL:Hide() end
        if target.arrowR then target.arrowR:Hide() end
    end,
})

-- Refresh entry points

function NP.gather.RefreshPlateFull(plateData, reason, hpValue)
    local snapshot, context, state = NP.gather.BuildPlateState(plateData, reason, hpValue)
    NP.gather.ApplyVisualState(plateData, snapshot, context, state, reason)
end

-- Light refresh skips BuildPlateState once styled; unstyled plates use full path.

-- Escalate to full refresh on plateName drift (native name may settle after OnShow).
local function PlateIdentityDrifted(plateData)
    return NP.discovery.GetPlateName(plateData) ~= plateData.plateName
end

function NP.gather.RefreshPlateHealth(plateData, value, reason)
    if not plateData.minaHp or PlateIdentityDrifted(plateData) then
        local snapshot, context, state = NP.gather.BuildPlateState(plateData, reason or "health_update", value)
        NP.gather.EnsurePlateVisualRoot(plateData, state, context)
        NP.gather.SyncHealth(plateData, snapshot.healthCur)
        NP.widgets.Sync("ThreatGlow", plateData, context, state)
        NP.gather.SyncName(plateData, context.resolvedUnit)
        return
    end
    NP.native_style.CaptureBarColor(plateData)
    NP.gather.SyncHealth(plateData, value)
    NP.widgets.Sync("ThreatGlow", plateData)
    NP.gather.SyncName(plateData)
end

function NP.gather.RefreshPlatePower(plateData, reason)
    if not plateData.minaPo or PlateIdentityDrifted(plateData) then
        local _, context, state = NP.gather.BuildPlateState(plateData, reason or "power_update")
        NP.gather.EnsurePlateVisualRoot(plateData, state, context)
        NP.gather.SyncPower(plateData, state.showPower and context.resolvedUnit or nil)
        return
    end
    local cfg = NP.config.GetCfg()
    local showPower = (not NP.gather.IsHeadlineActive(plateData)) and (cfg.showPowerBar ~= false)
    NP.gather.SyncPower(plateData, showPower and NP.identity.ResolvePlateUnit(plateData) or nil)
end

function NP.gather.RefreshPlateName(plateData, reason)
    if not plateData.minaName or PlateIdentityDrifted(plateData) then
        local _, context, state = NP.gather.BuildPlateState(plateData, reason or "name_update")
        NP.gather.EnsurePlateVisualRoot(plateData, state, context)
        NP.gather.SyncName(plateData, context.resolvedUnit)
        return
    end
    NP.gather.SyncName(plateData)
end

local scratchAuraContext = {}

function NP.gather.RefreshPlateAuras(plateData, hintedUnit, reason)
    if not plateData.minaDebuffHost or PlateIdentityDrifted(plateData) then
        local _, context, state = NP.gather.BuildPlateState(plateData, reason or "unit_aura")
        NP.gather.EnsurePlateVisualRoot(plateData, state, context)
        scratchAuraContext.resolvedUnit = hintedUnit or context.resolvedUnit
        NP.widgets.Sync("Debuffs", plateData, scratchAuraContext, state)
        return
    end
    scratchAuraContext.resolvedUnit = hintedUnit or NP.identity.ResolvePlateUnit(plateData)
    NP.widgets.Sync("Debuffs", plateData, scratchAuraContext)
end

function NP.gather.RefreshPlateCastbar(plateData, reason)
    local refreshReason = reason or "cast_update"
    -- Headline mode hides the castbar regardless of the cast event path.
    if NP.gather.IsHeadlineActive(plateData) then
        NP.castbar.HidePlateCastBar(plateData)
        return
    end
    local ownershipValid = NP.identity.ValidatePlateGUIDOwnership(plateData)
    NP.identity.UpdatePlateGroupTargetMatch(plateData, false)
    NP.identity.UpdatePlateUnitToken(plateData)
    local cfg = NP.config.GetCfg()
    local showCastbar = cfg.showCastBar ~= false
    if plateData.minaCast or showCastbar then
        NP.layout.EnsureMinaStack(plateData)
    end
    if not ownershipValid and not NP.castbar.PlateStillCasting(plateData) then
        NP.castbar.HidePlateCastBar(plateData)
    elseif showCastbar and NP.castbar.ShouldSkipCastSync(plateData) then
        NP.castbar.HideNativeCastVisual(plateData)
        NP.layout.LayoutCastBarStack(plateData)
        local bar = plateData.minaCast
        if bar then
            NP.castbar.SyncPlateCastProgress(bar)
        end
    elseif showCastbar then
        NP.castbar.SyncCastBar(plateData)
    else
        NP.castbar.HidePlateCastBar(plateData)
    end
end

function NP.gather.RefreshPlateTargetState(plateData, reason)
    local refreshReason = reason or "target_changed"
    local snapshot, context, state = NP.gather.BuildPlateState(plateData, refreshReason)
    NP.gather.EnsurePlateVisualRoot(plateData, state, context)
    NP.gather.SyncHealth(plateData, snapshot.healthCur)
    NP.gather.SyncPower(plateData, state.showPower and context.resolvedUnit or nil)
    NP.gather.SyncName(plateData, context.resolvedUnit)
    NP.widgets.SyncList(TARGET_SYNC_WIDGETS, plateData, context, state)
    local ownershipValid = NP.identity.ValidatePlateGUIDOwnership(plateData)
    if not ownershipValid and not NP.castbar.PlateStillCasting(plateData) then
        NP.castbar.HidePlateCastBar(plateData)
    elseif state.showCastbar and NP.castbar.ShouldSkipCastSync(plateData) then
        NP.castbar.HideNativeCastVisual(plateData)
        NP.layout.LayoutCastBarStack(plateData)
        local bar = plateData.minaCast
        if bar then
            NP.castbar.SyncPlateCastProgress(bar)
        end
    elseif state.showCastbar then
        NP.castbar.SyncCastBar(plateData)
    else
        NP.castbar.HidePlateCastBar(plateData)
    end
end

function NP.gather.RefreshPlateMouseoverState(plateData, reason)
    local refreshReason = reason or "mouseover_changed"
    local snapshot, context, state = NP.gather.BuildPlateState(plateData, refreshReason)
    NP.gather.EnsurePlateVisualRoot(plateData, state, context)
    NP.gather.SyncHealth(plateData, snapshot.healthCur)
    NP.gather.SyncPower(plateData, state.showPower and context.resolvedUnit or nil)
    NP.gather.SyncName(plateData, context.resolvedUnit)
    NP.widgets.Sync("Debuffs", plateData, context, state)
end

-- Threat transitions (engine): sync glow and health tint when status changes.
function NP.gather.ProcessThreatTransitions()
    local inCombat = NP.module.playerInCombat and true or false
    -- Skip out of combat except one post-combat flush (reverts glow/tint without per-frame resolution).
    if not inCombat and not NP.module._threatNeedsFlush then
        return
    end
    local currentBucket = NP.module._budgetFrame or 0
    for _, plateData in pairs(NP.module.plates) do
        -- Target/focus full-rate; post-combat flush bypasses bucket stagger.
        local isPriority = NP.identity.IsTargetPlate(plateData) or NP.identity.IsFocusPlate(plateData)
        if isPriority or not inCombat or (plateData._budgetBucket or 0) == currentBucket then
            local status = NP.threat.ResolveAggroStatus(plateData)
            if plateData._lastThreatStatus ~= status or plateData._lastThreatCombat ~= inCombat then
                plateData._lastThreatStatus = status
                plateData._lastThreatCombat = inCombat
                NP.widgets.Sync("ThreatGlow", plateData, nil, {
                    reason = "scan_threat_transition",
                })
                -- Threat tint and health bar stay in sync.
                NP.gather.SyncHealth(plateData)
            end
        end
    end
    -- Flush pass complete: stop running until the next combat.
    if not inCombat then
        NP.module._threatNeedsFlush = nil
    end
end

-- Reaction drift (200ms): re-gather when native bar color changes.
function NP.gather.ProcessReactionDrift()
    for _, plateData in pairs(NP.module.plates) do
        local bar = plateData.healthBar
        if bar and bar.GetStatusBarColor and plateData.barR then
            local r, g, b = bar:GetStatusBarColor()
            if math.abs(r - plateData.barR) > 0.1
                or math.abs(g - plateData.barG) > 0.1
                or math.abs(b - plateData.barB) > 0.1 then
                if addon.debugMode then
                    print(string.format(
                        "|cFFFFFF00[DUI nameplate debug]|r ProcessReactionDrift name=%s t=%.3f stored=%.3f,%.3f,%.3f live=%.3f,%.3f,%.3f",
                        tostring(plateData.plateName), GetTime(),
                        plateData.barR, plateData.barG, plateData.barB, r, g, b))
                end
                NP.gather.RefreshPlateFull(plateData, "reaction_drift")
            end
        end
    end
end

function NP.gather.RefreshExpiredAuraPlates(expiredGUIDs, reason)
    if not expiredGUIDs then return end
    for guid in pairs(expiredGUIDs) do
        local plateData = NP.state.GUIDToPlate[guid]
        if plateData then
            NP.gather.RefreshPlateAuras(plateData, nil, reason or "expired_auras")
        end
    end
end
