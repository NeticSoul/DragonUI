-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local kit = addon.UnitFrameLayersKit
local MODULE_KEY = "unitframe_layers"

local LayersModule = { initialized = false, applied = false }
LayersModule.PredictManaCost = kit.PredictManaCost
LayersModule.PlayerCostFor = kit.PlayerCostFor

if addon.RegisterModule then
    addon:RegisterModule(MODULE_KEY, LayersModule, addon.L["Unit Frame Layers"],
        addon.L["Heal prediction, absorb shields, and animated health loss on unit frames"])
end

local ART = kit.LAYER_ART
local BAR_FILL = kit.STATUSBAR
local PREDICT_HORIZON = 5

local layered = {}       -- unit frame -> private state
local trackedNames = {}  -- tracked name -> unit frame
local installedHooks = {}
local lastHealth = {}    -- native health bar -> last observed UnitHealth
local lastShownPower = {} -- native mana bar -> last displayed power
local lossOf = {}        -- native health bar -> loss bar
local feedbackOf = {}    -- native mana bar -> feedback widget
local fullPowerOf = {}   -- native mana bar -> full-power widget

local function isLive()
    return addon:IsModuleEnabled(MODULE_KEY)
end

local function unitFor(st)
    return st.frame.unit or st.fallbackUnit
end

local function roundAway(x)
    if x >= 0 then
        return math.floor(x + 0.5)
    end
    return math.ceil(x - 0.5)
end

function addon.UFL_ShouldShowMissingHealthForUnit(unit)
    if type(unit) ~= "string" or not UnitExists(unit) then return false end
    if unit == "pet" then return false end
    if unit:find("^partypet%d+$") or unit:find("^raidpet%d+$") then return false end
    return not UnitCanAttack("player", unit)
end

local function textFormatFor(unit)
    local key = unit
    if type(key) == "string" and key:find("^party%d+$") then
        key = "party"
    end
    local profile = addon.db and addon.db.profile
    local frames = profile and profile.unitframe
    local entry = frames and key and frames[key]
    if type(entry) == "table" and entry.textFormat then
        return entry.textFormat
    end
    return "both"
end

local function updateMissingText(st, health, maxHealth)
    local label = st.missingText
    if not label then return end
    local cfg = addon:GetModuleConfig(MODULE_KEY)
    local missing = maxHealth - health
    local unit = unitFor(st)
    if not (cfg and cfg.missing_health == true and missing > 0
        and addon.UFL_ShouldShowMissingHealthForUnit(unit)) then
        label:Hide()
        return
    end

    local ts = addon.TextSystem
    local amount = missing
    if ts and ts.AbbreviateLargeNumbers then
        amount = ts.AbbreviateLargeNumbers(missing)
    end
    label:SetText("-" .. amount)

    local fmt = textFormatFor(unit)
    if fmt ~= st.anchoredFormat then
        local bar = st.frame.DragonUI_HealthBar or st.healthBar
        label:ClearAllPoints()
        if fmt == "both" then
            label:SetPoint("CENTER", bar, "CENTER", 0, 0)
            label:SetJustifyH("CENTER")
        else
            label:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
            label:SetJustifyH("RIGHT")
        end
        st.anchoredFormat = fmt
    end
    label:Show()
end

-- Unclamped amounts: all incoming heals, the player's own casted heals on this unit, total absorb.
local function incomingFor(unit)
    local guid = unit and UnitGUID(unit)
    if not guid then return 0, 0, 0 end
    local all, mine, shield = 0, 0, 0
    local hc = kit.heal
    if hc then
        local horizon = GetTime() + PREDICT_HORIZON
        all = hc:GetHealAmount(guid, hc.ALL_HEALS, horizon) or 0
        -- A nil caster GUID would make GetHealAmount sum every caster's heals.
        local me = UnitGUID("player")
        if me then
            mine = hc:GetHealAmount(guid, hc.CASTED_HEALS, horizon, me) or 0
        end
    end
    local am = kit.absorb
    if am and am.Unit_Total then
        shield = am.Unit_Total(guid) or 0
    end
    return all, mine, shield
end

local function chainSegment(seg, link, amount, barMax, barWidth)
    if amount == 0 or not barMax or barMax <= 0 then
        seg:Hide()
        return link, 0
    end
    local width = amount / barMax * barWidth
    seg:ClearAllPoints()
    seg:SetPoint("TOPLEFT", link, "TOPRIGHT", 0, 0)
    seg:SetPoint("BOTTOMLEFT", link, "BOTTOMRIGHT", 0, 0)
    seg:SetWidth(width)
    seg:Show()
    return seg, width
end

local STRIPE_SHEET = 32

local function hideStripes(st, from)
    local tiles = st.stripes
    if from == 1 then
        st.stripeWidth = nil
    end
    for i = from, #tiles do
        tiles[i]:Hide()
    end
end

-- One texture per 32px of shield, every coord inside 0..1: the client's own tiling blurred wide shields.
local function paintStripes(st, width, height)
    if not st.absorbFill:IsShown() or width <= 0 then
        if st.stripeWidth then
            hideStripes(st, 1)
        end
        return
    end
    if st.stripeWidth == width and st.stripeHeight == height then return end
    st.stripeWidth, st.stripeHeight = width, height
    local tiles = st.stripes
    local v = height / STRIPE_SHEET
    if v > 1 then v = 1 end
    local count, x = 0, 0
    while x < width do
        count = count + 1
        local tile = tiles[count]
        if not tile then
            tile = st.stripeOwner:CreateTexture(nil, "OVERLAY")
            tile:SetDrawLayer("OVERLAY", st.stripeSublevel)
            tile:SetTexture(ART .. "Shield-Overlay")
            tiles[count] = tile
        end
        local span = width - x
        if span > STRIPE_SHEET then span = STRIPE_SHEET end
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", st.absorbFill, "TOPLEFT", x, 0)
        tile:SetPoint("BOTTOMLEFT", st.absorbFill, "BOTTOMLEFT", x, 0)
        tile:SetWidth(span)
        tile:SetTexCoord(0, span / STRIPE_SHEET, 0, v)
        tile:Show()
        x = x + STRIPE_SHEET
    end
    hideStripes(st, count + 1)
end

local function paint(st)
    local native = st.healthBar
    local health = native:GetValue()
    local _, maxHealth = native:GetMinMaxValues()
    if not maxHealth or maxHealth <= 0 then return end

    updateMissingText(st, health, maxHealth)

    local all, mine, shield = incomingFor(unitFor(st))
    if health + all > maxHealth then
        all = maxHealth - health
    end
    local other = 0
    if all >= mine then
        other = all - mine
    else
        mine = all
    end
    local room = maxHealth - health - all
    if room < 0 then room = 0 end
    local shownShield = shield < room and shield or room

    if shield > 0 and health + all + shield >= maxHealth then
        st.overAbsorbGlow:Show()
    else
        st.overAbsorbGlow:Hide()
    end

    local bar = st.frame.DragonUI_HealthBar or native
    local _, barMax = bar:GetMinMaxValues()
    local barWidth = bar:GetWidth()
    local link = bar:GetStatusBarTexture()
    link = chainSegment(st.myHeal, link, mine, barMax, barWidth)
    link = chainSegment(st.otherHeal, link, other, barMax, barWidth)
    local _, shieldWidth = chainSegment(st.absorbFill, link, shownShield, barMax, barWidth)

    paintStripes(st, shieldWidth, bar:GetHeight())
end

local SPELLCAST_EVENTS = {
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
}

local function placeManaCost(st)
    local seg = st.manaCost
    local cost = st.cost or 0
    local bar = st.frame.DragonUI_ManaBar or st.manaBar
    local _, barMax = bar:GetMinMaxValues()
    if cost == 0 or not barMax or barMax <= 0 then
        seg:Hide()
        return
    end
    local fill = bar:GetStatusBarTexture()
    seg:ClearAllPoints()
    seg:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    seg:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
    seg:SetWidth(cost / barMax * bar:GetWidth())
    seg:Show()
end

-- The bar fields this taints are rewritten by Blizzard's secure updater before any secure read.
local function settleManaCost(st)
    UnitFrameManaBar_Update(st.manaBar, unitFor(st))
    placeManaCost(st)
end

-- A remembered cost survives while the unit keeps casting anything, even another spell.
local function keepOrDropCost(st)
    local unit = unitFor(st)
    if not (st.cost and unit and UnitCastingInfo(unit)) then
        st.cost = nil
    end
end

-- The client knows the player's real cost of every rank; the share table only lists some spells.
local function ownSpellCost(spellName, rank)
    if not spellName then return nil end
    local _, _, _, cost, _, powerType = GetSpellInfo((rank and rank ~= "") and (spellName .. "(" .. rank .. ")") or spellName)
    if not cost then
        _, _, _, cost, _, powerType = GetSpellInfo(spellName)
    end
    if cost and cost > 0 and powerType == 0 then return cost end
    return nil
end

local function onSpellcast(st, event, caster)
    local spellName, rank, _, _, startTime, endTime = UnitCastingInfo(caster)
    if event == "UNIT_SPELLCAST_START" and startTime ~= endTime then
        local unit = unitFor(st)
        local amount
        if unit == "player" then
            amount = ownSpellCost(spellName, rank) or kit.PlayerCostFor(spellName)
        else
            amount = kit.PredictManaCost(unit, spellName)
        end
        if not amount or st.manaBar.powerType ~= 0 then
            amount = 0
        end
        st.cost = amount
    else
        keepOrDropCost(st)
    end
    settleManaCost(st)
end

-- Library callbacks are registered per frame so a restore can drop them per frame.

local HEAL_TARGET_EVENTS = {
    "HealComm_HealStarted", "HealComm_HealUpdated", "HealComm_HealDelayed", "HealComm_HealStopped",
}
local HEAL_GUID_EVENTS = { "HealComm_ModifierChanged", "HealComm_GUIDDisappeared" }
local ABSORB_GUID_EVENTS = {
    "EffectUpdated", "EffectRemoved", "UnitUpdated", "UnitCleared", "AreaCreated", "AreaCleared",
}
local ABSORB_APPLIED = "EffectApplied"

local function repaintIfGuid(st, guid)
    if guid == nil then return end
    local unit = unitFor(st)
    if unit and UnitGUID(unit) == guid then
        paint(st)
    end
end

-- Only the heal's first target is matched; the caster never is.
local function onHealTargeted(st, _, _, _, _, _, firstTarget)
    repaintIfGuid(st, firstTarget)
end

local function onGuidFirst(st, _, guid)
    repaintIfGuid(st, guid)
end

local function onAbsorbApplied(st, _, _, _, destGUID)
    repaintIfGuid(st, destGUID)
end

local function listenHealComm(st, lib)
    for i = 1, #HEAL_TARGET_EVENTS do
        lib.RegisterCallback(st, HEAL_TARGET_EVENTS[i], onHealTargeted, st)
    end
    for i = 1, #HEAL_GUID_EVENTS do
        lib.RegisterCallback(st, HEAL_GUID_EVENTS[i], onGuidFirst, st)
    end
end

local function listenAbsorbs(st, lib)
    lib.RegisterCallback(st, ABSORB_APPLIED, onAbsorbApplied, st)
    for i = 1, #ABSORB_GUID_EVENTS do
        lib.RegisterCallback(st, ABSORB_GUID_EVENTS[i], onGuidFirst, st)
    end
end

local function subscribeLibraries(st)
    local hc = kit.heal
    if hc and type(hc.RegisterCallback) == "function" and pcall(listenHealComm, st, hc) then
        st.healLib = hc
    end
    local am = kit.absorb
    if am and type(am.RegisterCallback) == "function" and pcall(listenAbsorbs, st, am) then
        st.absorbLib = am
    end
end

local function dropCallbacks(lib, st, list)
    for i = 1, #list do
        pcall(lib.UnregisterCallback, st, list[i])
    end
end

local function unsubscribeLibraries(st)
    local hc = st.healLib
    if hc then
        dropCallbacks(hc, st, HEAL_TARGET_EVENTS)
        dropCallbacks(hc, st, HEAL_GUID_EVENTS)
        st.healLib = nil
    end
    local am = st.absorbLib
    if am then
        pcall(am.UnregisterCallback, st, ABSORB_APPLIED)
        dropCallbacks(am, st, ABSORB_GUID_EVENTS)
        st.absorbLib = nil
    end
end

local function newLayer(owner, layer, path, sublevel)
    local tex = owner:CreateTexture(nil, layer)
    if sublevel then
        tex:SetDrawLayer(layer, sublevel)
    end
    tex:SetTexture(path)
    tex:Hide()
    return tex
end

local function buildElements(st, frame, native, small)
    local box = CreateFrame("Frame", nil, frame)
    box:SetAllPoints(frame)
    box:SetFrameLevel(1)
    local glowHolder = CreateFrame("Frame", nil, box)
    glowHolder:SetFrameLevel(3)
    if small then
        -- Keeps everything above DragonUI's small-frame border, which sits at health bar level + 3.
        local strata, level = native:GetFrameStrata(), native:GetFrameLevel()
        box:SetFrameStrata(strata)
        box:SetFrameLevel(level + 1)
        glowHolder:SetFrameStrata(strata)
        glowHolder:SetFrameLevel(level + 4)
    end

    st.myHeal = newLayer(box, "BORDER", BAR_FILL)
    st.myHeal:SetVertexColor(0.0, 0.827, 0.765)
    st.otherHeal = newLayer(box, "BORDER", BAR_FILL)
    st.otherHeal:SetVertexColor(0.0, 0.631, 0.557)

    st.absorbFill = newLayer(box, "ARTWORK", ART .. "Shield-Fill", 0)
    st.stripes = {}
    st.stripeOwner = box
    st.stripeSublevel = small and 0 or 1

    st.overAbsorbGlow = newLayer(glowHolder, "OVERLAY", ART .. "Shield-Overshield", small and 2 or nil)
    st.overAbsorbGlow:SetBlendMode("ADD")

    st.manaCost = newLayer(box, "BORDER", BAR_FILL)
    st.manaCost:SetVertexColor(0.0, 0.447, 1.0)
end

local function anchorGlows(st, bar)
    local over = st.overAbsorbGlow
    over:SetPoint("TOPLEFT", bar, "TOPRIGHT", -7, 0)
    over:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -7, 0)
    over:SetWidth(16)
end

local function addPlayerExtras(st, frame, native, mana)
    local cfg = addon:GetModuleConfig(MODULE_KEY)
    if not (cfg and cfg.animated_loss == false) then
        st.lossBar = kit.NewLossBar(frame, native)
        lossOf[native] = st.lossBar
    end
    if cfg and cfg.builder_spender and mana then
        feedbackOf[mana], fullPowerOf[mana] = kit.NewPowerWidgets(frame, mana)
    end
end

local function takeOverUpdates(st)
    local native, mana = st.healthBar, st.manaBar
    if not st.savedUpdates then
        st.savedUpdates = true
        st.oldHealthUpdate = native:GetScript("OnUpdate")
        st.oldManaUpdate = mana and mana:GetScript("OnUpdate")
    end
    -- Bars that got their OnUpdate before the hooks existed still point at the unhooked function.
    native:SetScript("OnUpdate", UnitFrameHealthBar_OnUpdate)
    if mana then
        mana:SetScript("OnUpdate", UnitFrameManaBar_OnUpdate)
    end
end

local function fallbackUnitFor(name)
    local slot = name:match("^PartyMemberFrame(%d+)$")
    if slot then return "party" .. slot end
    slot = name:match("^PartyMemberFrame(%d+)PetFrame$")
    if slot then return "partypet" .. slot end
    return nil
end

local function attach(frame)
    if not frame then return nil end
    local known = layered[frame]
    if known then return known end
    local name = frame.GetName and frame:GetName()
    if not name then return nil end

    local native = frame.healthbar or _G[name .. "HealthBar"]
    local fallbackUnit = not frame.unit and fallbackUnitFor(name) or nil
    local unit = frame.unit or fallbackUnit
    if not native or not unit then return nil end
    local mana = frame.manabar or _G[name .. "ManaBar"]

    local st = { frame = frame, name = name, healthBar = native, manaBar = mana, fallbackUnit = fallbackUnit }
    local small = (frame == _G.TargetFrameToT) or (frame == _G.FocusFrameToT)
    local shownBar = frame.DragonUI_HealthBar or native

    buildElements(st, frame, native, small)
    anchorGlows(st, shownBar)

    if unit == "player" or unit == "target" then
        st.hasCostOverlay = true
        st.manaCost:ClearAllPoints()
        for event in pairs(SPELLCAST_EVENTS) do
            frame:RegisterEvent(event)
        end
    else
        st.manaCost:Hide()
    end

    frame:RegisterEvent("UNIT_MAXHEALTH")
    if addon.RegisterUnitEventSafe then
        addon.RegisterUnitEventSafe(frame, "UNIT_AURA", unit)
    else
        frame:RegisterEvent("UNIT_AURA")
    end

    kit.ResolveLibraries()
    subscribeLibraries(st)

    -- A player frame first seen in a vehicle ("vehicle" token) never gets the player extras.
    if unit == "player" then
        addPlayerExtras(st, frame, native, mana)
    end

    if not st.missingText then
        local label = shownBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        label:SetTextColor(1, 0.3, 0.3)
        label:SetPoint("RIGHT", shownBar, "RIGHT", -4, 0)
        label:SetJustifyH("RIGHT")
        label:Hide()
        st.missingText = label
    end

    takeOverUpdates(st)

    layered[frame] = st
    trackedNames[name] = frame

    paint(st)
    return st
end

local EAGER_FRAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "TargetFrameToT", "FocusFrameToT",
}
for i = 1, 4 do
    EAGER_FRAMES[#EAGER_FRAMES + 1] = "PartyMemberFrame" .. i
end
for i = 1, 4 do
    EAGER_FRAMES[#EAGER_FRAMES + 1] = "PartyMemberFrame" .. i .. "PetFrame"
end

-- Blizzard post-hooks are permanent; each one is inert while the module is off.

local function skipBar(bar)
    if bar.disconnected or bar.lockValues then return true end
    local unit = bar.unit
    if not unit then return true end
    return bar.ignoreNoUnit and not UnitGUID(unit)
end

local function afterHealthTick(bar)
    if not isLive() or skipBar(bar) then return end
    local current = UnitHealth(bar.unit)
    local previous = lastHealth[bar]
    if previous == nil then
        previous = bar.currValue or current
        lastHealth[bar] = previous
    end
    local loss = lossOf[bar]
    if current ~= previous then
        if loss then
            kit.LossHealthChanged(loss, previous, current)
        end
        local owner = layered[bar:GetParent()]
        if owner then
            paint(owner)
        end
        lastHealth[bar] = current
    end
    if loss then
        kit.LossStep(loss, current)
    end
end

local function afterManaTick(bar)
    if not isLive() or skipBar(bar) then return end
    local shown = UnitPower(bar.unit, bar.powerType)
    local owner = layered[bar:GetParent()]
    local cost = owner and owner.cost
    if cost then
        shown = shown - roundAway(cost)
    end
    -- Only write on a real difference: every write touches Blizzard's bar from addon code.
    if bar:GetValue() ~= shown or bar.forceUpdate then
        if bar.forceUpdate then
            bar.forceUpdate = nil
        end
        bar:SetValue(shown)
        bar.currValue = shown
        TextStatusBar_UpdateTextString(bar)
    end
    local before = lastShownPower[bar] or 0
    if before ~= shown then
        local fb = feedbackOf[bar]
        if fb then
            kit.FeedbackChanged(fb, before, shown)
        end
        local fp = fullPowerOf[bar]
        if fp and fp.active then
            kit.FullPowerChanged(fp, shown)
        end
        lastShownPower[bar] = shown
    end
end

-- Health bars get every unit's UNIT_HEALTH/UNIT_MAXHEALTH; Blizzard ignores the ones not for bar.unit.
local function afterHealthUpdate(bar, unit)
    if not bar or unit ~= bar.unit or not isLive() then return end
    local loss = lossOf[bar]
    if loss then
        kit.LossSyncRange(loss)
    end
    local owner = layered[bar:GetParent()]
    if owner then
        paint(owner)
    end
end

local function afterFrameUpdate(frame)
    if not isLive() then return end
    local st = layered[frame]
    if not st then return end
    paint(st)
    -- Elsewhere this would only repeat the UnitFrameManaBar_Update that UnitFrame_Update just ran.
    if st.manaBar and st.hasCostOverlay then
        keepOrDropCost(st)
        settleManaCost(st)
    end
end

-- The player's bar also gets other units' max-power events; only its own unit may set the maximum.
local function afterManaUpdate(bar, unit)
    if not isLive() or not bar or not unit or bar.lockValues or unit ~= bar.unit then return end
    local fp = fullPowerOf[bar]
    if fp then
        kit.FullPowerSetMax(fp, UnitPowerMax(unit, bar.powerType))
    end
    local fb = feedbackOf[bar]
    -- Reseeded on a power swap so a shapeshift is not animated as a spend or a gain.
    if fb and unit == "player" and kit.PowerWidgetsFollow(fb, fp) then
        lastShownPower[bar] = UnitPower(unit, bar.powerType)
    end
end

local function afterFrameEvent(frame, event, eventUnit)
    if not isLive() then return end
    local st = layered[frame] or attach(frame)
    if not st then return end
    local unit = unitFor(st)
    -- No RegisterUnitEvent in 3.3.5a: each frame hears every unit's UNIT_* events, paint reads only its own.
    if not (eventUnit and unit and eventUnit ~= unit and strfind(event, "^UNIT_")) then
        paint(st)
    end
    if SPELLCAST_EVENTS[event] and st.manaBar and eventUnit then
        if unit and UnitIsUnit(eventUnit, unit) then
            onSpellcast(st, event, eventUnit)
        end
    end
end

-- Blizzard global, diagnostic key, post-hook.
local HOOKS = {
    { "UnitFrameHealthBar_OnUpdate", "UnitFrameHealthBar_OnUpdate_override", afterHealthTick },
    { "UnitFrameManaBar_OnUpdate", "UnitFrameManaBar_OnUpdate_override", afterManaTick },
    { "UnitFrameHealthBar_Update", "UnitFrameHealthBar_Update", afterHealthUpdate },
    { "UnitFrame_Update", "UnitFrame_Update", afterFrameUpdate },
    { "UnitFrameManaBar_Update", "UnitFrameManaBar_Update", afterManaUpdate },
    { "UnitFrame_OnEvent", "UnitFrame_OnEvent", afterFrameEvent },
}

local function installHooks()
    for i = 1, #HOOKS do
        local global, key, post = HOOKS[i][1], HOOKS[i][2], HOOKS[i][3]
        if not installedHooks[key] and type(_G[global]) == "function" then
            hooksecurefunc(global, post)
            installedHooks[key] = true
        end
    end
end

local function applyLayers()
    if LayersModule.applied then return end
    kit.ResolveLibraries()
    installHooks()
    for i = 1, #EAGER_FRAMES do
        local frame = _G[EAGER_FRAMES[i]]
        if frame then
            attach(frame)
        end
    end
    LayersModule.applied = true
    LayersModule.initialized = true
end

local ELEMENT_KEYS = {
    "myHeal", "otherHeal", "absorbFill", "overAbsorbGlow", "manaCost",
}

-- Leaves UNIT_* registrations, the power widgets and the attached state alone.
local function restoreFrame(st)
    for i = 1, #ELEMENT_KEYS do
        st[ELEMENT_KEYS[i]]:Hide()
    end
    hideStripes(st, 1)
    if st.missingText then
        st.missingText:Hide()
    end
    if st.lossBar then
        kit.LossCancel(st.lossBar)
    end
    unsubscribeLibraries(st)
    if st.savedUpdates then
        st.healthBar:SetScript("OnUpdate", st.oldHealthUpdate)
        if st.manaBar then
            st.manaBar:SetScript("OnUpdate", st.oldManaUpdate)
        end
    end
end

local function restoreLayers()
    if not LayersModule.applied then return end
    for _, frame in pairs(trackedNames) do
        local st = layered[frame]
        if st then
            restoreFrame(st)
        end
    end
    LayersModule.applied = false
end

function addon.RefreshUnitFrameLayers()
    if isLive() then
        applyLayers()
    else
        restoreLayers()
    end
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(self)
    if isLive() then
        applyLayers()
    end
    self:UnregisterEvent("PLAYER_LOGIN")
end)

local DIAG_TAG = "|cFF00FF00[DragonUI UFL]|r "
local DIAG_OK = "|cFF00FF00OK|r"
local DIAG_FAIL = "|cFFFF0000FAIL|r"

-- Label printed by the diagnostic, state field that holds the element.
local DIAG_ELEMENTS = {
    { "myHealPredictionBar", "myHeal" },
    { "otherHealPredictionBar", "otherHeal" },
    { "totalAbsorbBar", "absorbFill" },
    { "overAbsorbGlow", "overAbsorbGlow" },
    { "myManaCostPredictionBar", "manaCost" },
}

-- Raw print keeps the output fixed; addon:Print would add its own prefix in front of the tag.
local function emit(text)
    print(DIAG_TAG .. text)
end

local function verdict(flag)
    return flag and DIAG_OK or DIAG_FAIL
end

local function yesNo(flag)
    return flag and "YES" or "no"
end

local function describeFrame(label, st)
    local frame, native = st.frame, st.healthBar
    local unit = unitFor(st)
    emit("Frame: " .. label)
    emit("  unit: " .. tostring(unit))
    for i = 1, #DIAG_ELEMENTS do
        local row = DIAG_ELEMENTS[i]
        emit("  " .. row[1] .. ": " .. verdict(st[row[2]]))
    end
    if st.lossBar then
        emit("  AnimatedLossBar: " .. DIAG_OK)
    end
    if native then
        local current = native:GetScript("OnUpdate") == UnitFrameHealthBar_OnUpdate
        emit("  healthbar OnUpdate is UFL override: " .. verdict(current))
    end
    if frame:IsEventRegistered("UNIT_AURA") then
        emit("  UNIT_AURA registered: " .. DIAG_OK)
    else
        emit("  UNIT_AURA registered: " .. DIAG_FAIL .. " (HoT/absorb updates need this!)")
    end
    emit("  UNIT_MAXHEALTH registered: " .. verdict(frame:IsEventRegistered("UNIT_MAXHEALTH")))

    if unit and UnitExists(unit) then
        local _, maxHealth = native:GetMinMaxValues()
        emit("  Health: " .. tostring(native:GetValue()) .. " / " .. tostring(maxHealth))
        local all, mine, shield = incomingFor(unit)
        emit("  myIncomingHeal (CASTED): " .. tostring(mine))
        emit("  allIncomingHeal (ALL): " .. tostring(all))
        emit("  HoT amount (all-my): " .. tostring(all - mine))
        emit("  totalAbsorb: " .. tostring(shield))
        emit("  myHealBar visible: " .. yesNo(st.myHeal:IsShown()))
        emit("  otherHealBar visible: " .. yesNo(st.otherHeal:IsShown()))
        emit("  absorbBar visible: " .. yesNo(st.absorbFill:IsShown()))
    end
end

function addon.DiagnoseUnitFrameLayers()
    emit("=== UnitFrameLayers Diagnostic ===")
    emit("Module enabled: " .. verdict(isLive()))
    emit("Module applied: " .. verdict(LayersModule.applied))
    emit("Module initialized: " .. verdict(LayersModule.initialized))
    local cfg = addon:GetModuleConfig(MODULE_KEY)
    emit("Config table: " .. verdict(cfg))
    if cfg then
        emit("  animated_loss: " .. tostring(cfg.animated_loss))
        emit("  builder_spender: " .. tostring(cfg.builder_spender))
    end

    kit.ResolveLibraries()
    local hc = kit.heal
    emit("LibHealComm-4.0: " .. verdict(hc))
    emit("AbsorbsMonitor-1.0: " .. verdict(kit.absorb))
    if hc then
        emit("  HealComm.ALL_HEALS: " .. tostring(hc.ALL_HEALS))
        emit("  HealComm.CASTED_HEALS: " .. tostring(hc.CASTED_HEALS))
        emit("  HealComm.HOT_HEALS: " .. tostring(hc.HOT_HEALS))
    end

    emit("Hooks:")
    for i = 1, #HOOKS do
        local key = HOOKS[i][2]
        if installedHooks[key] then
            emit("  " .. key .. ": true")
        end
    end

    local labels = {}
    for label in pairs(trackedNames) do
        labels[#labels + 1] = label
    end
    table.sort(labels)
    for i = 1, #labels do
        describeFrame(labels[i], layered[trackedNames[labels[i]]])
    end
    emit("Total tracked frames: " .. #labels)

    emit("Global UnitFrameHealthBar_OnUpdate overridden: "
        .. verdict(installedHooks.UnitFrameHealthBar_OnUpdate_override))
    emit("Global UnitFrameManaBar_OnUpdate overridden: "
        .. verdict(installedHooks.UnitFrameManaBar_OnUpdate_override))
    emit("=== End Diagnostic ===")
    emit("Tip: Cast a HoT or apply a shield, then run /dragonui ufl again to see live data.")
end
