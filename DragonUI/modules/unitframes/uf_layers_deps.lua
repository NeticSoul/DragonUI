-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Building blocks for unitframe_layers.lua: mana-cost data, the player loss bar and power feedback.
local kit = {}
addon.UnitFrameLayersKit = kit

local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local STATUSBAR_GLOW = "Interface\\TargetingFrame\\UI-StatusBar-Glow"
local LAYER_ART = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Layers\\"

kit.STATUSBAR = STATUSBAR
kit.LAYER_ART = LAYER_ART

local function unit01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

-- Game facts, not code: Blizzard spell costs and class base mana.

-- Flat (spell id, share of base mana) pairs; ids are turned into localized names below.
local COST_SHARES = {
    DRUID = {
        18658, 0.07,   26995, 0.06,   33786, 0.08,   48443, 0.29,
        48447, 0.70,   48461, 0.11,   48463, 0.21,   48465, 0.16,
        48467, 0.81,   50464, 0.18,   50763, 0.72,   53308, 0.07,
    },
    HUNTER = {
        1002, 0.01,    1515, 0.48,    14327, 0.02,   49052, 0.05,
    },
    MAGE = {
        3563, 0.08,    3566, 0.08,    3567, 0.08,    11417, 0.18,
        11418, 0.18,   11420, 0.18,   12826, 0.07,   27090, 0.40,
        32267, 0.18,   32272, 0.08,   33717, 0.40,   35715, 0.08,
        35717, 0.18,   42842, 0.11,   42859, 0.08,   42897, 0.07,
        42926, 0.30,   42956, 0.40,   42985, 0.75,   47610, 0.14,
        49358, 0.08,   49361, 0.18,   53140, 0.08,   53142, 0.18,
        58659, 0.80,
    },
    PALADIN = {
        10326, 0.09,   48782, 0.29,   48785, 0.07,   48801, 0.08,
        48950, 0.64,
    },
    PRIEST = {
        605, 0.12,     2053, 0.27,    6064, 0.32,    8129, 0.14,
        10955, 0.90,   32375, 0.33,   34914, 0.16,   48063, 0.32,
        48071, 0.18,   48072, 0.48,   48120, 0.27,   48123, 0.15,
        48127, 0.17,   48135, 0.11,   48171, 0.60,   53023, 0.28,
        64843, 0.63,
    },
    SHAMAN = {
        556, 0.05,     6196, 0.03,    49238, 0.10,   49271, 0.26,
        49273, 0.25,   49276, 0.15,   49277, 0.72,   51514, 0.03,
        55459, 0.19,   60043, 0.10,
    },
    WARLOCK = {
        126, 0.04,     688, 0.64,     697, 0.80,     6215, 0.12,
        17928, 0.08,   18647, 0.08,   30108, 0.15,   47809, 0.17,
        47811, 0.17,   47815, 0.08,   47825, 0.09,   47827, 0.20,
        47836, 0.34,   47838, 0.14,   47878, 0.53,   47884, 0.68,
        47888, 0.45,   48018, 0.15,   48181, 0.12,   58887, 0.80,
        59172, 0.07,   60220, 0.54,   61191, 0.27,
    },
}

-- Base mana by level, one decade per row (levels 1-10, 11-20, ... 71-80).
local BASE_MANA_DECADES = {
    DRUID = {
        { 50, 50, 50, 50, 50, 50, 50, 120, 134, 149 },
        { 165, 182, 200, 219, 239, 260, 282, 305, 329, 354 },
        { 380, 392, 420, 449, 479, 509, 524, 554, 614, 629 },
        { 659, 689, 704, 734, 749, 779, 809, 824, 854, 854 },
        { 869, 899, 914, 944, 959, 989, 1004, 1019, 1049, 1064 },
        { 1079, 1109, 1124, 1139, 1154, 1169, 1199, 1214, 1229, 1244 },
        { 1359, 1469, 1582, 1694, 1807, 1919, 2032, 2145, 2257, 2370 },
        { 2482, 2595, 2708, 2820, 2933, 3045, 3158, 3270, 3383, 3496 },
    },
    HUNTER = {
        { 65, 65, 65, 98, 98, 98, 98, 166, 166, 166 },
        { 166, 166, 166, 298, 298, 298, 298, 298, 298, 298 },
        { 298, 298, 298, 298, 298, 298, 298, 298, 298, 298 },
        { 298, 298, 298, 298, 298, 298, 298, 298, 1075, 1075 },
        { 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075 },
        { 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075, 1075 },
        { 1075, 2053, 2053, 2053, 2053, 2053, 2053, 2053, 2053, 3383 },
        { 3383, 3716, 3716, 3716, 3716, 3716, 3716, 3716, 3716, 5046 },
    },
    MAGE = {
        { 100, 110, 110, 110, 121, 121, 121, 121, 121, 196 },
        { 215, 215, 215, 263, 271, 295, 305, 331, 343, 371 },
        { 385, 415, 431, 431, 431, 515, 515, 556, 592, 613 },
        { 634, 634, 634, 712, 733, 733, 733, 811, 811, 853 },
        { 853, 853, 916, 916, 916, 916, 916, 1021, 1021, 1021 },
        { 1021, 1090, 1090, 1117, 1138, 1138, 1138, 1138, 1138, 1213 },
        { 1213, 1213, 1521, 1521, 1521, 1521, 1932, 2035, 2035, 2241 },
        { 2343, 2625, 2625, 2625, 2625, 2625, 2625, 3063, 3063, 3268 },
    },
    PALADIN = {
        { 60, 64, 84, 90, 112, 120, 129, 154, 165, 192 },
        { 205, 219, 249, 265, 282, 315, 334, 354, 390, 412 },
        { 435, 459, 499, 525, 552, 579, 621, 648, 675, 702 },
        { 729, 756, 798, 825, 852, 879, 906, 933, 960, 987 },
        { 1014, 1041, 1068, 1110, 1137, 1164, 1176, 1203, 1230, 1257 },
        { 1284, 1311, 1338, 1365, 1392, 1419, 1446, 1458, 1485, 1512 },
        { 1656, 1800, 1944, 2088, 2232, 2377, 2521, 2665, 2809, 2953 },
        { 3097, 3241, 3385, 3529, 3673, 3817, 3962, 4106, 4250, 4394 },
    },
    PRIEST = {
        { 110, 119, 119, 119, 119, 119, 164, 164, 164, 164 },
        { 164, 164, 164, 164, 164, 164, 164, 164, 164, 164 },
        { 164, 164, 164, 480, 480, 530, 530, 530, 530, 530 },
        { 530, 530, 530, 530, 530, 530, 530, 530, 530, 911 },
        { 911, 911, 911, 911, 911, 911, 911, 911, 911, 911 },
        { 911, 911, 911, 911, 911, 911, 911, 911, 911, 911 },
        { 911, 911, 911, 911, 911, 911, 911, 911, 911, 2620 },
        { 2620, 2868, 2868, 2868, 3242, 3242, 3242, 3242, 3242, 3863 },
    },
    SHAMAN = {
        { 55, 55, 55, 55, 55, 55, 121, 121, 121, 175 },
        { 190, 206, 223, 241, 260, 280, 301, 323, 346, 370 },
        { 395, 421, 448, 476, 505, 535, 566, 598, 631, 665 },
        { 699, 733, 767, 786, 820, 854, 888, 922, 941, 975 },
        { 1009, 1028, 1062, 1096, 1115, 1149, 1183, 1202, 1236, 1255 },
        { 1289, 1313, 1342, 1376, 1395, 1414, 1448, 1467, 1501, 1520 },
        { 1664, 1808, 1951, 2095, 2239, 2383, 2572, 2670, 2814, 2958 },
        { 3102, 3246, 3389, 3533, 3677, 3821, 3965, 4108, 4252, 4396 },
    },
    WARLOCK = {
        { 90, 90, 90, 90, 90, 90, 90, 90, 90, 90 },
        { 90, 90, 90, 90, 90, 90, 90, 90, 90, 90 },
        { 90, 90, 90, 90, 90, 90, 90, 90, 90, 90 },
        { 90, 90, 90, 90, 90, 90, 90, 90, 90, 90 },
        { 90, 965, 965, 1022, 1022, 1022, 1022, 1022, 1022, 1022 },
        { 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1022, 1522 },
        { 1522, 1522, 1522, 1522, 1522, 1522, 1522, 1522, 1522, 2871 },
        { 2871, 2871, 2871, 2871, 2871, 2871, 2871, 2871, 2871, 3856 },
    },
}

local MAX_TABLE_LEVEL = 80

local baseManaByLevel = {}
for class, decades in pairs(BASE_MANA_DECADES) do
    local levels = {}
    for d = 1, #decades do
        local row = decades[d]
        for i = 1, #row do
            levels[(d - 1) * 10 + i] = row[i]
        end
    end
    baseManaByLevel[class] = levels
end

-- class -> { [localized spell name] = share }
local sharesByName = {}
for class, flat in pairs(COST_SHARES) do
    local named = {}
    for i = 1, #flat - 1, 2 do
        local ok, spellName = pcall(GetSpellInfo, flat[i])
        if ok and type(spellName) == "string" and spellName ~= "" then
            named[spellName] = flat[i + 1]
        end
    end
    sharesByName[class] = named
end

local playerCosts = {}

local function rebuildPlayerCosts()
    local _, class = UnitClass("player")
    local named = class and sharesByName[class]
    local level = UnitLevel("player")
    local levels = class and baseManaByLevel[class]
    local base = levels and type(level) == "number" and levels[level]
    if not base then
        base = 1
    end
    local fresh = {}
    if named then
        for spellName, share in pairs(named) do
            fresh[spellName] = share * base
        end
    end
    playerCosts = fresh
end

function kit.PlayerCostFor(spellName)
    if spellName == nil then return nil end
    return playerCosts[spellName]
end

function kit.PredictManaCost(unit, spellName)
    if not unit or not spellName then return nil end
    local _, class = UnitClass(unit)
    local level = UnitLevel(unit)
    if not class or type(level) ~= "number" or level < 1 then return nil end
    if level > MAX_TABLE_LEVEL then level = MAX_TABLE_LEVEL end
    local named = sharesByName[class]
    local share = named and named[spellName]
    if not share then return nil end
    local levels = baseManaByLevel[class]
    local base = levels and levels[level]
    if not base or base <= 0 then return nil end
    return share * base
end

rebuildPlayerCosts()

-- The rebuild reads UnitLevel at event time, not the event's level argument.
local levelWatch = CreateFrame("Frame")
levelWatch:SetScript("OnEvent", function()
    rebuildPlayerCosts()
end)
levelWatch:RegisterEvent("PLAYER_LEVEL_UP")

function kit.ResolveLibraries()
    local stub = LibStub
    if type(stub) == "table" and type(stub.GetLibrary) == "function" then
        kit.heal = stub:GetLibrary("LibHealComm-4.0", true)
        kit.absorb = stub:GetLibrary("AbsorbsMonitor-1.0", true)
    else
        kit.heal, kit.absorb = nil, nil
    end
end

-- Player loss bar: a red block from the new health to the old one, held, then shrunk.

local LOSS_HOLD = 0.1
local LOSS_SHRINK = 0.25
local LOSS_POSTPONE = 0.05
local LOSS_REHIT_PAUSE = 0.05

local function lossTopAt(lb, bottom, now)
    local startAt = lb.startAt
    if not startAt then return 0, 1 end
    local elapsed = now - startAt
    if elapsed <= 0 then return lb.top, 0 end
    local p = elapsed / LOSS_SHRINK
    local top = lb.top
    if p < 1 and top > bottom then
        return top - p * (top - bottom), p
    end
    return 0, 1
end

function kit.LossCancel(lb)
    lb.startAt = nil
    lb.top = nil
    lb.progress = 0
    lb.bar:Hide()
end

function kit.LossSyncRange(lb)
    lb.bar:SetMinMaxValues(0, UnitHealthMax("player"))
end

function kit.NewLossBar(owner, healthBar)
    local sb = CreateFrame("StatusBar", nil, owner)
    sb:Hide()
    sb:SetStatusBarTexture(STATUSBAR)
    sb:SetStatusBarColor(1, 0, 0, 1)
    sb:SetAllPoints(healthBar)
    local level = healthBar:GetFrameLevel() - 1
    sb:SetFrameLevel(level > 0 and level or 0)
    local lb = { bar = sb, progress = 0 }
    kit.LossSyncRange(lb)
    return lb
end

function kit.LossHealthChanged(lb, prev, cur)
    if cur < prev then
        local now = GetTime()
        if not lb.startAt then
            lb.bar:Show()
            lb.bar:SetValue(prev)
            lb.top = prev
            lb.startAt = now + LOSS_HOLD
            lb.progress = 0
        elseif lb.progress == 0 then
            lb.startAt = lb.startAt + LOSS_POSTPONE
        else
            lb.top = (lossTopAt(lb, prev, now))
            lb.startAt = now + LOSS_REHIT_PAUSE
        end
    elseif lb.startAt and cur >= lb.top then
        kit.LossCancel(lb)
    end
end

function kit.LossStep(lb, current)
    local am = kit.absorb
    if am and am.Unit_Total then
        local shield = am.Unit_Total(UnitGUID("player"))
        if shield and shield > 0 then
            if lb.startAt or lb.bar:IsShown() then
                kit.LossCancel(lb)
            end
            return
        end
    end
    if not lb.startAt then return end
    local value, p = lossTopAt(lb, current, GetTime())
    lb.progress = p
    if p >= 1 then
        kit.LossCancel(lb)
    else
        lb.bar:SetValue(value)
    end
end

-- Player power feedback (builder/spender glows) and the full-power spike and pulse.

local GAIN_TIME = 0.5
local DROP_TIME = 0.6
local FEEDBACK_THRESHOLD = 0.1

local feedbackByFrame = {}

local function gainTick(fb, t)
    local glow = fb.rise
    if t > GAIN_TIME then
        glow:Hide()
        fb.gainAt = nil
        return
    end
    local live = UnitPower("player", fb.powerType)
    if type(live) == "number" and live > fb.gainTo then
        fb.gainTo = live
    end
    local from, to = fb.gainFrom, fb.gainTo
    local cur = from + (to - from) * t / GAIN_TIME
    local span = fb.maxPower
    if span <= 0 then span = 1 end
    local width = (to - cur) / span * fb.frame:GetWidth()
    if width < 0.5 then
        glow:Hide()
        fb.gainAt = nil
        return
    end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", fb.frame, "TOPLEFT", cur / span * fb.manaBar:GetWidth(), 0)
    glow:SetHeight(fb.frame:GetHeight())
    glow:SetWidth(width)
    glow:SetTexCoord(unit01(cur / span), unit01(to / span), 0, 1)
    glow:Show()
end

local function dropTick(fb, t)
    if t > DROP_TIME then
        fb.drop:Hide()
        fb.block:Hide()
        fb.dropAt = nil
        return
    end
    if t <= 0.25 then
        fb.drop:SetAlpha(0.75 * t / 0.25)
    else
        fb.drop:SetAlpha(0.75 * (0.6 - t) / 0.35)
    end
    if t < 0.4 then
        fb.block:SetAlpha(1)
    else
        fb.block:SetAlpha((0.6 - t) / 0.2)
    end
end

local function feedbackOnUpdate(frame)
    local fb = feedbackByFrame[frame]
    if fb then
        local now = GetTime()
        if fb.gainAt then gainTick(fb, now - fb.gainAt) end
        if fb.dropAt then dropTick(fb, now - fb.dropAt) end
        if fb.gainAt or fb.dropAt then return end
    end
    frame:SetScript("OnUpdate", nil)
end

local function placeSpan(tex, host, x, width, height, left, right)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", host, "TOPLEFT", x, 0)
    tex:SetWidth(width)
    tex:SetHeight(height)
    tex:SetTexCoord(left, right, 0, 1)
    tex:Show()
end

function kit.FeedbackChanged(fb, old, new)
    local top = fb.maxPower
    if top == 0 then return end
    local delta = new - old
    if delta < 0 then delta = -delta end
    if delta / top <= FEEDBACK_THRESHOLD then return end
    -- The direction is chosen on clamped values: a drop that stays above the stale maximum is a gain.
    if old < 0 then old = 0 elseif old > top then old = top end
    if new < 0 then new = 0 end
    local frame = fb.frame
    if new > old then
        fb.gainFrom, fb.gainTo = old, new
        fb.gainAt = GetTime()
    elseif new < old then
        local w, h = frame:GetWidth(), frame:GetHeight()
        local x, width = new / top * w, (old - new) / top * w
        placeSpan(fb.drop, frame, x, width, h, new / top, old / top)
        placeSpan(fb.block, frame, x, width, h, new / top, old / top)
        fb.drop:SetAlpha(0)
        fb.block:SetAlpha(1)
        fb.dropAt = GetTime()
    else
        return
    end
    frame:SetScript("OnUpdate", feedbackOnUpdate)
end

local FX_SHEET = LAYER_ART .. "PlayerFrameFX"
local FX_SHEET_W, FX_SHEET_H = 128, 64

-- Pixel rects on the FX sheet: left, right, top, bottom.
local FX_BIG_SPIKE = { 1, 28, 1, 35 }
local FX_SPIKE_STAY = { 74, 108, 1, 19 }
local FX_PULSE = { 1, 120, 35, 64 }

-- Every step is order 1 (parallel): kind, amount, duration, start delay, smoothing, LEFT origin x.
local BIG_SPIKE_STEPS = {
    { "Alpha", 1, 0.25, 0, "IN" },
    { "Scale", 0.25, 0, 0, "NONE" },
    { "Scale", 1.5, 0.1, 0, "NONE", 2 },
    { "Scale", 0.5, 0.2, 0.2, "IN", 6 },
    { "Alpha", 1, 0, 0.3, "NONE" },
    { "Alpha", -1, 0.25, 0.3, "NONE" },
}
local SPIKE_STAY_STEPS = {
    { "Alpha", 1, 0.25, 0, "IN" },
}
local PULSE_STEPS = {
    { "Alpha", 0.6, 0.2, 0, "IN" },
    { "Alpha", -0.6, 0.3, 0.1, "OUT" },
}

local function fxTexture(host, rect, blend)
    local tex = host:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(FX_SHEET)
    tex:SetTexCoord(rect[1] / FX_SHEET_W, rect[2] / FX_SHEET_W, rect[3] / FX_SHEET_H, rect[4] / FX_SHEET_H)
    tex:SetBlendMode(blend)
    tex:SetAlpha(0)
    return tex
end

local function buildTimeline(region, steps)
    local group = region:CreateAnimationGroup()
    for i = 1, #steps do
        local step = steps[i]
        local anim = group:CreateAnimation(step[1])
        if step[1] == "Alpha" then
            anim:SetChange(step[2])
        else
            anim:SetScale(step[2], step[2])
            if step[6] then
                anim:SetOrigin("LEFT", step[6], 0)
            end
        end
        anim:SetDuration(step[3])
        anim:SetStartDelay(step[4])
        anim:SetSmoothing(step[5])
        anim:SetOrder(1)
    end
    return group
end

local function pulsesAtFull(token)
    return token == "RAGE" or token == "ENERGY"
end

local function tintBlock(block, powerType, token)
    local palette = PowerBarColor
    local tint = palette and (palette[token] or palette[powerType] or palette.MANA)
    if tint then
        block:SetVertexColor(tint.r or 1, tint.g or 1, tint.b or 1)
    else
        block:SetVertexColor(1, 1, 1)
    end
end

local function newFullPower(manaBar, token)
    local holder = CreateFrame("Frame", nil, manaBar)
    holder:SetSize(119, 12)
    holder:SetPoint("TOPRIGHT", manaBar, "TOPRIGHT")

    local spikeHost = CreateFrame("Frame", nil, holder)
    spikeHost:SetSize(119, 12)
    spikeHost:SetPoint("TOPRIGHT", holder, "TOPRIGHT")
    local pulseHost = CreateFrame("Frame", nil, holder)
    pulseHost:SetSize(119, 12)
    pulseHost:SetPoint("TOPRIGHT", holder, "TOPRIGHT")

    local big = fxTexture(spikeHost, FX_BIG_SPIKE, "BLEND")
    big:SetSize(27, 34)
    big:SetPoint("RIGHT", spikeHost, "RIGHT", 21, 0)
    local stay = fxTexture(spikeHost, FX_SPIKE_STAY, "BLEND")
    stay:SetSize(34, 18)
    stay:SetPoint("RIGHT", spikeHost, "RIGHT", 11, 0)
    local pulse = fxTexture(pulseHost, FX_PULSE, "ADD")
    pulse:SetPoint("TOPRIGHT", pulseHost, "TOPRIGHT")

    return {
        frame = holder,
        bigSpike = big,
        spikeStay = stay,
        bigSpikeAnim = buildTimeline(big, BIG_SPIKE_STEPS),
        spikeStayAnim = buildTimeline(stay, SPIKE_STAY_STEPS),
        pulseAnim = buildTimeline(pulse, PULSE_STEPS),
        active = pulsesAtFull(token),
    }
end

function kit.FullPowerSetMax(fp, value)
    if type(value) == "number" and value > 0 then
        fp.maxPower = value
    end
end

-- Spikes replay only once the pulse has finished; nothing fades them back out after they are shown.
function kit.FullPowerChanged(fp, value)
    if value ~= fp.maxPower or not UnitAffectingCombat("player") then return end
    if not fp.pulseAnim:IsPlaying() then
        fp.bigSpike:SetAlpha(1)
        fp.bigSpike:Show()
        fp.spikeStay:SetAlpha(1)
        fp.spikeStay:Show()
        fp.bigSpikeAnim:Play()
        fp.spikeStayAnim:Play()
    end
    fp.frame:SetAlpha(1)
    fp.pulseAnim:Play()
end

function kit.NewPowerWidgets(unitFrame, manaBar)
    local frame = CreateFrame("Frame", nil, manaBar)
    frame:SetAllPoints(manaBar)
    local host = unitFrame:GetParent()
    frame:SetFrameLevel((host and host:GetFrameLevel() or 0) + 2)

    local height = frame:GetHeight()
    local block = frame:CreateTexture(nil, "ARTWORK")
    block:SetTexture(STATUSBAR)
    block:Hide()
    local drop = frame:CreateTexture(nil, "OVERLAY")
    drop:SetTexture(STATUSBAR_GLOW)
    drop:SetBlendMode("ADD")
    drop:Hide()
    local rise = frame:CreateTexture(nil, "OVERLAY")
    rise:SetTexture(STATUSBAR_GLOW)
    rise:SetBlendMode("ADD")
    rise:SetAlpha(0.75)
    rise:Hide()
    block:SetHeight(height)
    drop:SetHeight(height)
    rise:SetHeight(height)

    local powerType, token = UnitPowerType("player")
    tintBlock(block, powerType, token)

    local fb = {
        frame = frame,
        manaBar = manaBar,
        block = block,
        drop = drop,
        rise = rise,
        powerType = powerType,
        maxPower = UnitPowerMax("player", powerType) or 0,
    }
    feedbackByFrame[frame] = fb

    return fb, newFullPower(manaBar, token)
end

-- A shapeshift swaps the player's power under widgets built for the old one; returns true then.
function kit.PowerWidgetsFollow(fb, fp)
    local powerType, token = UnitPowerType("player")
    local swapped = powerType ~= fb.powerType
    if swapped then
        fb.powerType = powerType
        tintBlock(fb.block, powerType, token)
        if fp then fp.active = pulsesAtFull(token) end
    end
    fb.maxPower = UnitPowerMax("player", powerType) or 0
    return swapped
end
