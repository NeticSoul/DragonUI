-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Personal Resource Display as Forever (Camelot) ships it: health, power and alternate power bars only.

local addon = select(2, ...)
local L = addon.L

local KEY = "personalresource"
local BASE_WIDTH = 200
local MIN_PADDING = 4
local MIN_FRAME_HEIGHT = 15
local HEAL_WINDOW = 3
local TEXT_INSET = 5
local FONT = addon.Fonts.PRIMARY

local ART = addon._dir .. "PersonalResource\\"
local FILL_TEXTURES = { ART .. "bar_top", ART .. "bar_middle", ART .. "bar_bottom" }
local FRAME_TEXTURE = ART .. "bg"
local RIM_TEXTURE = ART .. "rim"
local SPENDER_TEXTURE = ART .. "statusbar"
local GLOW_TEXTURE = ART .. "glow"
local ALERT_TEXTURE = ART .. "fullalert"
local PREDICTION_TEXTURE = ART .. "healfill"
local SHIELD_FILL = addon._dir .. "UnitFrames\\Layers\\Shield-Fill"
local SHIELD_OVERLAY = addon._dir .. "UnitFrames\\Layers\\Shield-Overlay"
local SHIELD_OVERSHIELD = addon._dir .. "UnitFrames\\Layers\\Shield-Overshield"

-- The frame art overhangs the bar by these units (Forever's XML anchors).
local FRAME_LEFT, FRAME_TOP, FRAME_RIGHT, FRAME_BOTTOM = 2, 3, 6, 7
-- Sheet 512x64, sliced by the client's UiTextureAtlasElementSliceData (121/7/10/11 units, 2 px each).
local SHEET_W, SHEET_H = 512, 64
local SLICE_X, SLICE_Y = { 0, 242, 244, 264 }, { 0, 14, 16, 38 }
local SLICE_LEFT, SLICE_RIGHT = SLICE_X[2] / 2, (SLICE_X[4] - SLICE_X[3]) / 2
local SLICE_TOP, SLICE_BOTTOM = SLICE_Y[2] / 2, (SLICE_Y[4] - SLICE_Y[3]) / 2
-- The fill atlas is sliced too: 5 units on top, 4 below, one file per band so each StatusBar crops it.
local FILL_TOP, FILL_BOTTOM = 5, 4

-- 128x64 sheet of the full-resource alert: BigSpike, SoftCurveGlow, YellowCurveGlow, FrameGlow.
local ALERT_COORDS = {
    spike = { 1 / 128, 28 / 128, 1 / 64, 35 / 64 },
    soft = { 30 / 128, 50 / 128, 1 / 64, 38 / 64 },
    yellow = { 52 / 128, 72 / 128, 1 / 64, 38 / 64 },
    frame = { 74 / 128, 108 / 128, 1 / 64, 19 / 64 },
}

local HEALTH_COLOR = { r = 0, g = 0.8, b = 0 }
local HEAL_PREDICTION_COLOR = { r = 0, g = 0.659, b = 0.608 }
local MANA_BAR_COLOR = { r = 0.1, g = 0.25, b = 1 }

-- Prediction colours and the full-power pulse per power token, as in Forever's PowerBarColor.
local POWER_INFO = {
    MANA = { prediction = { r = 0, g = 0.176, b = 0.408 } },
    RAGE = { prediction = { r = 0.4, g = 0, b = 0 }, fullPowerAnim = true },
    FOCUS = { prediction = { r = 0.4, g = 0.133, b = 0 }, fullPowerAnim = true },
    ENERGY = { prediction = { r = 0.451, g = 0.4, b = 0 }, fullPowerAnim = true },
    RUNIC_POWER = { prediction = { r = 0, g = 0.325, b = 0.4 }, fullPowerAnim = true },
}

local POWER_EVENTS = {
    UNIT_MANA = true, UNIT_RAGE = true, UNIT_ENERGY = true, UNIT_FOCUS = true, UNIT_RUNIC_POWER = true,
    UNIT_MAXMANA = true, UNIT_MAXRAGE = true, UNIT_MAXENERGY = true, UNIT_MAXFOCUS = true,
    UNIT_MAXRUNIC_POWER = true,
}

local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
}

local HEALCOMM_EVENTS = {
    "HealComm_HealStarted", "HealComm_HealUpdated", "HealComm_HealDelayed", "HealComm_HealStopped",
    "HealComm_ModifierChanged", "HealComm_GUIDDisappeared",
}

local PersonalResource = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule(KEY, PersonalResource,
        L["Personal Resource Display"],
        L["Add Health and Resource below your Character."],
        { lifecyclePrefix = "PersonalResource" })
end

local anchor, content
local health, power, alt
local playerClass, playerGUID
local previewing = false
local inCombat = false
local altActive = false
local powerType, powerToken = 0, nil
local predictedPowerCost
local currPowerValue
local healDirty = false

local eventFrame = CreateFrame("Frame")
local dataFrame = CreateFrame("Frame")
local callbackOwner = {}

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
local format = string.format

local function PlayerClass()
    if not playerClass then
        playerClass = select(2, UnitClass("player"))
    end
    return playerClass
end

local function Cfg()
    return addon.db.profile.personalresource
end

local function Clamp(value, low, high, fallback)
    value = tonumber(value) or fallback
    if value < low then return low end
    if value > high then return high end
    return value
end

local function Lerp(from, to, progress)
    return from + (to - from) * progress
end

local function EditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive() and true or false
end

-- Forever's FIRST/SECOND/THIRD_NUMBER_CAP_NO_SPACE; the Asian clients keep DragonUI's own units.
local LOCAL_UNITS = { zhCN = true, zhTW = true, koKR = true }
local useLocalUnits = LOCAL_UNITS[GetLocale()]

local function Scaled(value, divisor, suffix)
    return (format("%.1f", value / divisor):gsub("%.0$", "")) .. suffix
end

local function Abbreviate(value)
    if useLocalUnits and addon.TextSystem then
        return addon.TextSystem.AbbreviateLargeNumbers(value)
    end
    if value >= 1e9 then return Scaled(value, 1e9, "B") end
    if value >= 1e6 then return Scaled(value, 1e6, "M") end
    if value >= 1e3 then return Scaled(value, 1e3, "K") end
    return tostring(floor(value))
end

-- =============================================================================
-- Bars
-- =============================================================================

local function CreateText(parent, point, x)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 10, "OUTLINE")
    text:SetPoint(point, x, 0)
    return text
end

local LEVEL_BAR, LEVEL_EFFECTS, LEVEL_RIM, LEVEL_PULSE, LEVEL_TEXT = 1, 2, 3, 4, 5

-- The middle strips sample texel centres so the filter does not pull in the neighbouring slice.
local function SlicePixels(edges, index)
    local from, to = edges[index], edges[index + 1]
    if index == 2 then return from + 0.5, to - 0.5 end
    return from, to
end

local function Between(texture, from, fromPoint, to, toPoint)
    texture:SetPoint("TOPLEFT", from, fromPoint, 0, 0)
    texture:SetPoint("BOTTOMRIGHT", to, toPoint, 0, 0)
end

-- Nine textures laid over `parent`: corners keep their size, the strips between them stretch.
local function CreateSlices(parent, file, withCenter)
    local pieces = {}
    for row = 1, 3 do
        pieces[row] = {}
        for column = 1, 3 do
            if withCenter or row ~= 2 or column ~= 2 then
                local left, right = SlicePixels(SLICE_X, column)
                local top, bottom = SlicePixels(SLICE_Y, row)
                local texture = parent:CreateTexture(nil, "BACKGROUND")
                texture:SetTexture(file)
                texture:SetTexCoord(left / SHEET_W, right / SHEET_W, top / SHEET_H, bottom / SHEET_H)
                pieces[row][column] = texture
            end
        end
    end

    local topLeft, topRight, bottomLeft, bottomRight = pieces[1][1], pieces[1][3], pieces[3][1], pieces[3][3]
    topLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bottomLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottomRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    Between(pieces[1][2], topLeft, "TOPRIGHT", topRight, "BOTTOMLEFT")
    Between(pieces[3][2], bottomLeft, "TOPRIGHT", bottomRight, "BOTTOMLEFT")
    Between(pieces[2][1], topLeft, "BOTTOMLEFT", bottomLeft, "TOPRIGHT")
    Between(pieces[2][3], topRight, "BOTTOMLEFT", bottomRight, "TOPRIGHT")
    if withCenter then
        Between(pieces[2][2], topLeft, "BOTTOMRIGHT", bottomRight, "TOPLEFT")
    end
    return pieces
end

-- Below ~65% width the two side slices shrink together; the height never gets that small.
local function LayoutSlices(pieces, width)
    local shrink = min(1, width / (SLICE_LEFT + SLICE_RIGHT))
    pieces[1][1]:SetSize(SLICE_LEFT * shrink, SLICE_TOP)
    pieces[1][3]:SetSize(SLICE_RIGHT * shrink, SLICE_TOP)
    pieces[3][1]:SetSize(SLICE_LEFT * shrink, SLICE_BOTTOM)
    pieces[3][3]:SetSize(SLICE_RIGHT * shrink, SLICE_BOTTOM)
end

local function CreateFrameArt(holder, level, file, withCenter)
    local art = CreateFrame("Frame", nil, holder)
    art:SetFrameLevel(level)
    art:SetPoint("TOPLEFT", holder, "TOPLEFT", -FRAME_LEFT, FRAME_TOP)
    art:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", FRAME_RIGHT, -FRAME_BOTTOM)
    art.pieces = CreateSlices(art, file, withCenter)
    return art
end

-- Three StatusBars (top, stretching middle, bottom) acting as one; each crops its own texture by value.
local FillMethods = {}

function FillMethods:SetMinMaxValues(minimum, maximum)
    for _, band in ipairs(self.bands) do band:SetMinMaxValues(minimum, maximum) end
end

function FillMethods:GetMinMaxValues()
    return self.bands[1]:GetMinMaxValues()
end

function FillMethods:SetValue(value)
    for _, band in ipairs(self.bands) do band:SetValue(value) end
end

function FillMethods:GetValue()
    return self.bands[1]:GetValue()
end

function FillMethods:SetStatusBarColor(r, g, b)
    for _, band in ipairs(self.bands) do band:SetStatusBarColor(r, g, b) end
end

local function CreateFill(holder, level)
    local fill = CreateFrame("Frame", nil, holder)
    fill:SetAllPoints(holder)
    fill:SetFrameLevel(level)

    local bands = {}
    for index, file in ipairs(FILL_TEXTURES) do
        local band = CreateFrame("StatusBar", nil, fill)
        band:SetFrameLevel(level)
        band:SetStatusBarTexture(file)
        band:SetMinMaxValues(0, 1)
        band:SetValue(1)
        bands[index] = band
    end
    bands[1]:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    bands[1]:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
    bands[1]:SetHeight(FILL_TOP)
    bands[2]:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, -FILL_TOP)
    bands[2]:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, FILL_BOTTOM)
    bands[3]:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
    bands[3]:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    bands[3]:SetHeight(FILL_BOTTOM)

    fill.bands = bands
    for name, method in pairs(FillMethods) do fill[name] = method end
    return fill
end

local function CreateBar()
    local holder = CreateFrame("Frame", nil, content)
    local level = holder:GetFrameLevel()

    holder.trough = CreateFrameArt(holder, level, FRAME_TEXTURE, true)
    holder.bar = CreateFill(holder, level + LEVEL_BAR)
    holder.rim = CreateFrameArt(holder, level + LEVEL_RIM, RIM_TEXTURE, false)

    -- Drawn above the prediction overlays so the numbers stay readable.
    holder.textFrame = CreateFrame("Frame", nil, holder)
    holder.textFrame:SetAllPoints(holder)
    holder.textFrame:SetFrameLevel(level + LEVEL_TEXT)
    holder.left = CreateText(holder.textFrame, "LEFT", TEXT_INSET)
    holder.right = CreateText(holder.textFrame, "RIGHT", -TEXT_INSET)

    return holder
end

local function CreateHealthOverlay()
    local overlay = CreateFrame("Frame", nil, health.bar)
    overlay:SetAllPoints(health.bar)
    overlay:SetFrameLevel(health:GetFrameLevel() + LEVEL_EFFECTS)

    for _, key in ipairs({ "myHeal", "otherHeal" }) do
        local texture = overlay:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(PREDICTION_TEXTURE)
        texture:SetVertexColor(HEAL_PREDICTION_COLOR.r, HEAL_PREDICTION_COLOR.g, HEAL_PREDICTION_COLOR.b)
        texture:Hide()
        health[key] = texture
    end

    health.absorb = overlay:CreateTexture(nil, "ARTWORK")
    health.absorb:SetTexture(SHIELD_FILL)
    health.absorb:Hide()

    local tile = overlay:CreateTexture(nil, "OVERLAY")
    tile:SetTexture(SHIELD_OVERLAY, "REPEAT", "REPEAT")
    tile:SetHorizTile(true)
    tile:SetVertTile(true)
    tile:SetAllPoints(health.absorb)
    tile:Hide()
    health.absorb.overlay = tile

    -- The overshield glow marks the bar's end and is meant to spill over the rim.
    local glowFrame = CreateFrame("Frame", nil, health.bar)
    glowFrame:SetAllPoints(health.bar)
    glowFrame:SetFrameLevel(health:GetFrameLevel() + LEVEL_PULSE)
    health.overGlow = glowFrame:CreateTexture(nil, "OVERLAY")
    health.overGlow:SetTexture(SHIELD_OVERSHIELD)
    health.overGlow:SetBlendMode("ADD")
    health.overGlow:SetWidth(16)
    health.overGlow:SetPoint("BOTTOMLEFT", health.bar, "BOTTOMRIGHT", -4, -1)
    health.overGlow:SetPoint("TOPLEFT", health.bar, "TOPRIGHT", -4, 1)
    health.overGlow:Hide()
end

-- Spent and gained power flash (Forever's BuilderSpender).
local function CreateFeedback()
    local feedback = CreateFrame("Frame", nil, power.bar)
    feedback:SetAllPoints(power.bar)
    feedback:SetFrameLevel(power:GetFrameLevel() + LEVEL_EFFECTS)

    feedback.barTexture = feedback:CreateTexture(nil, "ARTWORK")
    feedback.barTexture:SetTexture(SPENDER_TEXTURE)
    feedback.lossGlow = feedback:CreateTexture(nil, "OVERLAY")
    feedback.lossGlow:SetTexture(GLOW_TEXTURE)
    feedback.lossGlow:SetBlendMode("ADD")
    feedback.gainGlow = feedback:CreateTexture(nil, "OVERLAY")
    feedback.gainGlow:SetTexture(GLOW_TEXTURE)
    feedback.gainGlow:SetBlendMode("ADD")
    feedback.gainGlow:SetAlpha(0.75)
    for _, texture in ipairs({ feedback.barTexture, feedback.lossGlow, feedback.gainGlow }) do
        texture:Hide()
    end

    feedback.maxValue = 1
    power.feedback = feedback
end

-- Pulse and spike shown when a resource tops up in combat (Forever's FullResourcePulse).
local function CreateFullPower()
    local pulse = CreateFrame("Frame", nil, power.bar)
    pulse:SetSize(86, 6)
    pulse:SetPoint("RIGHT", power.bar, "RIGHT", 0, 0)
    pulse:SetFrameLevel(power:GetFrameLevel() + LEVEL_PULSE)
    pulse:SetAlpha(0)

    local function Glow(coords, width, height, point, x, y)
        local texture = pulse:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(ALERT_TEXTURE)
        texture:SetTexCoord(unpack(coords))
        texture:SetSize(width, height)
        texture:SetPoint(point, pulse, point, x, y)
        texture:SetAlpha(0)
        return texture
    end

    pulse.spike = Glow(ALERT_COORDS.spike, 27, 34, "RIGHT", 21, 0)
    pulse.stay = Glow(ALERT_COORDS.frame, 30, 12, "RIGHT", 11, 0)
    pulse.yellow = Glow(ALERT_COORDS.yellow, 20, 20, "RIGHT", -1, -1)
    pulse.soft = Glow(ALERT_COORDS.soft, 20, 20, "RIGHT", -1, -1)
    pulse.maxValue = 0
    power.fullPower = pulse
end

local function CreateFrames()
    anchor = addon.CreateUIFrame(BASE_WIDTH, 2 * 15 + MIN_PADDING, "PersonalResource")

    content = CreateFrame("Frame", "DragonUI_PersonalResourceFrame", UIParent)
    content:SetFrameStrata("MEDIUM")
    content:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)

    health = CreateBar()
    power = CreateBar()
    alt = CreateBar()
    CreateHealthOverlay()
    CreateFeedback()
    CreateFullPower()

    power.prediction = power.bar:CreateTexture(nil, "ARTWORK")
    power.prediction:SetTexture(SPENDER_TEXTURE)
    power.prediction:Hide()

    alt.bar:SetStatusBarColor(PowerBarColor.MANA.r, PowerBarColor.MANA.g, PowerBarColor.MANA.b)
end

-- =============================================================================
-- Text (Forever's TextStatusBar: percentage left and value right, capped numbers)
-- =============================================================================

local function ShowText()
    return Cfg().bar_text and true or false
end

local function UpdateBothText(holder)
    local value = holder.bar:GetValue()
    local _, maximum = holder.bar:GetMinMaxValues()
    if not ShowText() or maximum <= 0 then
        holder.left:SetText("")
        holder.right:SetText("")
        return
    end

    holder.left:SetText(ceil(value / maximum * 100) .. "%")
    holder.right:SetText(Abbreviate(value))
end

local function UpdateNumericText(holder)
    local value = holder.bar:GetValue()
    local _, maximum = holder.bar:GetMinMaxValues()
    holder.left:SetText("")
    holder.right:SetText((ShowText() and maximum > 0) and Abbreviate(value) or "")
end

-- =============================================================================
-- Health
-- =============================================================================

local function UpdateHealthColor()
    local color = HEALTH_COLOR
    if Cfg().class_color then
        color = RAID_CLASS_COLORS[PlayerClass()] or color
    end
    health.bar:SetStatusBarColor(color.r, color.g, color.b)
end

local healCommLib, absorbsLib

local function Libraries()
    if healCommLib == nil then
        healCommLib = LibStub("LibHealComm-4.0", true) or false
        absorbsLib = LibStub("AbsorbsMonitor-1.0", true) or false
    end
    return healCommLib or nil, absorbsLib or nil
end

-- Chains segments after the fill; `x` is where the previous one ended, measured from the bar's left edge.
local function UpdateFillBar(x, bar, amount)
    local width = health.width or 0
    local _, maximum = health.bar:GetMinMaxValues()
    if width == 0 or amount <= 0 or maximum <= 0 then
        bar:Hide()
        if bar.overlay then bar.overlay:Hide() end
        return x
    end

    local size = amount / maximum * width
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", health.bar, "TOPLEFT", x, 0)
    bar:SetPoint("BOTTOMLEFT", health.bar, "BOTTOMLEFT", x, 0)
    bar:SetWidth(size)
    bar:SetTexCoord(x / width, (x + size) / width, 0, 1)
    bar:Show()
    if bar.overlay then bar.overlay:Show() end
    return x + size
end

local function UpdateHealthPrediction()
    if not health then return end

    local current = health.bar:GetValue()
    local _, maximum = health.bar:GetMinMaxValues()
    if maximum <= 0 then return end

    local healComm, absorbs = Libraries()
    local guid = playerGUID
    local mine, incoming, absorb = 0, 0, 0
    if healComm and guid then
        local horizon = GetTime() + HEAL_WINDOW
        incoming = healComm:GetHealAmount(guid, healComm.ALL_HEALS, horizon) or 0
        mine = healComm:GetHealAmount(guid, healComm.ALL_HEALS, horizon, guid) or 0
    end
    if absorbs and guid then
        absorb = absorbs.Unit_Total(guid) or 0
    end

    if current + incoming > maximum then
        incoming = maximum - current
    end

    local others = 0
    if incoming >= mine then
        others = incoming - mine
    else
        mine = incoming
    end

    local overAbsorb = false
    if current + incoming + absorb >= maximum or current + absorb >= maximum then
        if absorb > 0 then overAbsorb = true end
        absorb = max(0, maximum - (current + incoming))
    end
    if overAbsorb then
        health.overGlow:Show()
    else
        health.overGlow:Hide()
    end

    local x = Clamp(current / maximum, 0, 1, 0) * (health.width or 0)
    x = UpdateFillBar(x, health.myHeal, mine)
    x = UpdateFillBar(x, health.otherHeal, others)
    UpdateFillBar(x, health.absorb, absorb)
end

local function UpdateHealth()
    local maximum = UnitHealthMax("player")
    health.bar:SetMinMaxValues(0, maximum > 0 and maximum or 1)
    health.bar:SetValue(UnitHealth("player"))
    UpdateBothText(health)
    UpdateHealthPrediction()
end

-- =============================================================================
-- Power
-- =============================================================================

local function UpdatePredictedPowerCost(queryCurrentCastingInfo)
    local cost = 0
    if queryCurrentCastingInfo then
        local name, rank = UnitCastingInfo("player")
        if name then
            local spell = (rank and rank ~= "") and (name .. "(" .. rank .. ")") or name
            local _, _, _, spellCost, _, spellPowerType = GetSpellInfo(spell)
            if not spellCost then
                _, _, _, spellCost, _, spellPowerType = GetSpellInfo(name)
            end
            if spellCost and spellCost > 0 and spellPowerType == powerType then
                cost = spellCost
            end
        end
    end
    predictedPowerCost = cost
end

local function AnchorPrediction()
    local _, maximum = power.bar:GetMinMaxValues()
    local width = power.width or 0
    if width == 0 or maximum <= 0 or not predictedPowerCost or predictedPowerCost == 0 then
        power.prediction:Hide()
        return
    end

    local x = Clamp(power.bar:GetValue() / maximum, 0, 1, 0) * width
    local size = min(predictedPowerCost / maximum * width, width - x)
    power.prediction:ClearAllPoints()
    power.prediction:SetPoint("TOPLEFT", power.bar, "TOPLEFT", x, 0)
    power.prediction:SetPoint("BOTTOMLEFT", power.bar, "BOTTOMLEFT", x, 0)
    power.prediction:SetWidth(size)
    power.prediction:SetTexCoord(x / width, (x + size) / width, 0, 1)
    power.prediction:Show()
end

local function UpdatePower()
    if not predictedPowerCost then
        UpdatePredictedPowerCost(true)
    end

    power.bar:SetValue(UnitPower("player", powerType) - predictedPowerCost)
    UpdateBothText(power)
    AnchorPrediction()
end

local function UpdateMaxPower()
    local maximum = UnitPowerMax("player", powerType)
    power.bar:SetMinMaxValues(0, maximum > 0 and maximum or 1)
    power.feedback.maxValue = maximum
    power.fullPower.maxValue = maximum
    UpdatePower()
end

local function UpdateAlt()
    local maximum = UnitPowerMax("player", 0)
    alt.bar:SetMinMaxValues(0, maximum > 0 and maximum or 1)
    alt.bar:SetValue(UnitPower("player", 0))
    UpdateNumericText(alt)
end

local function SyncAlt()
    local reserved = PlayerClass() == "DRUID" and not Cfg().hide_alt_power
    if reserved and altActive then
        alt:Show()
    else
        alt:Hide()
    end
end

local function EndFeedback()
    local feedback = power.feedback
    feedback.updatingGain, feedback.updatingLoss = false, false
    feedback.barTexture:Hide()
    feedback.lossGlow:Hide()
    feedback.gainGlow:Hide()
    feedback:SetScript("OnUpdate", nil)
end

local function RemoveFullPowerAnims()
    local pulse = power.fullPower
    pulse.spikeTime, pulse.pulseTime, pulse.fadeTime = nil, nil, nil
    pulse:SetAlpha(0)
    pulse.spike:SetAlpha(0)
    pulse.stay:SetAlpha(0)
    pulse.yellow:SetAlpha(0)
    pulse.soft:SetAlpha(0)
    pulse:SetScript("OnUpdate", nil)
end

local function UpdatePowerBar()
    local newType, token, altR, altG, altB = UnitPowerType("player")
    local color = (token == "MANA" and MANA_BAR_COLOR) or PowerBarColor[token]
    if not color then
        color = altR and { r = altR, g = altG, b = altB } or PowerBarColor[newType] or MANA_BAR_COLOR
    end
    power.bar:SetStatusBarColor(color.r, color.g, color.b)

    local info = POWER_INFO[token] or POWER_INFO.MANA
    power.feedback.barTexture:SetVertexColor(color.r, color.g, color.b)
    power.fullPower.active = info.fullPowerAnim and true or false

    if powerType ~= newType or powerToken ~= token then
        powerType, powerToken = newType, token
        RemoveFullPowerAnims()
        EndFeedback()
        UpdatePredictedPowerCost(true)
        local prediction = info.prediction
        power.prediction:SetVertexColor(prediction.r, prediction.g, prediction.b)
    end

    if not predictedPowerCost then
        UpdatePredictedPowerCost(true)
    end
    currPowerValue = UnitPower("player", powerType) - predictedPowerCost

    -- Same rule as Blizzard's own alternate power bar: mana while another power is shown.
    altActive = powerType ~= 0 and (UnitPowerMax("player", 0) or 0) > 0
    SyncAlt()
    UpdateAlt()
    UpdateMaxPower()
end

-- =============================================================================
-- Power effects
-- =============================================================================

local function StartFeedback(oldValue, newValue)
    local feedback = power.feedback
    local maximum = feedback.maxValue
    if maximum <= 0 then return end

    oldValue = Clamp(oldValue, 0, maximum, 0)
    newValue = max(newValue, 0)
    local width = power.width or 0
    local height = power.height or 0

    if newValue > oldValue then
        feedback.updatingGain = true
        feedback.oldValue, feedback.newValue = oldValue, newValue
        feedback.gainStart = GetTime()
    elseif newValue < oldValue then
        local left = newValue / maximum * width
        local size = (oldValue - newValue) / maximum * width
        local minX, maxX = newValue / maximum, oldValue / maximum

        for _, texture in ipairs({ feedback.lossGlow, feedback.barTexture }) do
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", feedback, "TOPLEFT", left, 0)
            texture:SetSize(size, height)
            texture:SetTexCoord(minX, maxX, 0, 1)
            texture:Show()
        end
        feedback.lossGlow:SetAlpha(0)
        feedback.barTexture:SetAlpha(1)
        feedback.updatingLoss = true
        feedback.lossStart = GetTime()
    else
        return
    end

    feedback:SetScript("OnUpdate", function(self)
        local now = GetTime()
        if self.updatingGain then
            local elapsed = now - self.gainStart
            if elapsed > 0.5 then
                self.gainGlow:Hide()
                self.updatingGain = false
            else
                local currentPower = UnitPower("player", powerType)
                if currentPower > self.newValue then self.newValue = currentPower end

                local current = self.oldValue + (self.newValue - self.oldValue) * (elapsed / 0.5)
                local total = self.maxValue > 0 and self.maxValue or 1
                local gainWidth = (self.newValue - current) / total * (power.width or 0)
                if gainWidth < 0.5 then
                    self.gainGlow:Hide()
                    self.updatingGain = false
                else
                    self.gainGlow:ClearAllPoints()
                    self.gainGlow:SetPoint("TOPLEFT", self, "TOPLEFT", current / total * (power.width or 0), 0)
                    self.gainGlow:SetSize(gainWidth, power.height or 0)
                    self.gainGlow:SetTexCoord(Clamp(current / total, 0, 1, 0), Clamp(self.newValue / total, 0, 1, 0), 0, 1)
                    self.gainGlow:Show()
                end
            end
        end

        if self.updatingLoss then
            local elapsed = now - self.lossStart
            if elapsed > 0.6 then
                self.lossGlow:Hide()
                self.barTexture:Hide()
                self.updatingLoss = false
            else
                if elapsed < 0.25 then
                    self.lossGlow:SetAlpha(Lerp(0, 0.75, elapsed / 0.25))
                else
                    self.lossGlow:SetAlpha(Lerp(0.75, 0, (elapsed - 0.25) / 0.35))
                end
                self.barTexture:SetAlpha(elapsed < 0.4 and 1 or Lerp(1, 0, (elapsed - 0.4) / 0.2))
            end
        end

        if not self.updatingGain and not self.updatingLoss then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function EaseIn(progress) return progress * progress end
local function EaseOut(progress) return 1 - (1 - progress) * (1 - progress) end
local function Ramp(time, start, duration) return Clamp((time - start) / duration, 0, 1, 0) end

-- One OnUpdate drives the spike, the looping pulse and the fade out, like Forever's three animation groups.
local function TickFullPower(pulse, elapsed)
    if pulse.fadeTime then
        pulse.fadeTime = pulse.fadeTime + elapsed
        if pulse.fadeTime >= 0.5 then
            RemoveFullPowerAnims()
            return
        end
        pulse:SetAlpha(1 - pulse.fadeTime / 0.5)
    end

    if pulse.spikeTime then
        local time = pulse.spikeTime + elapsed
        pulse.spikeTime = time
        local appear = EaseIn(Ramp(time, 0, 0.25))
        pulse.spike:SetAlpha(time < 0.3 and appear or (1 - Ramp(time, 0.3, 0.25)))
        pulse.stay:SetAlpha(appear)

        local scale
        if time < 0.1 then
            scale = Lerp(0.25, 1.4, time / 0.1)
        elseif time < 0.2 then
            scale = 1
        else
            scale = Lerp(1, 0.5, EaseIn(Ramp(time, 0.2, 0.2)))
        end
        pulse.spike:SetWidth(27 * scale)
        pulse.spike:ClearAllPoints()
        pulse.spike:SetPoint("RIGHT", pulse, "RIGHT", -6 + 27 * scale, 0)
    end

    if pulse.pulseTime then
        local time = (pulse.pulseTime + elapsed) % 0.7
        pulse.pulseTime = time

        local yellow = Ramp(time, 0, 0.1) * (1 - Ramp(time, 0.4, 0.1))
        pulse.yellow:SetAlpha(yellow)
        pulse.yellow:ClearAllPoints()
        pulse.yellow:SetPoint("RIGHT", pulse, "RIGHT", -1 + 20 * EaseOut(Ramp(time, 0, 0.5)), -1)

        local soft = Ramp(time, 0, 0.1) * (1 - Ramp(time, 0.6, 0.1))
        pulse.soft:SetAlpha(soft)
        pulse.soft:ClearAllPoints()
        pulse.soft:SetPoint("RIGHT", pulse, "RIGHT", -1 + 20 * EaseOut(Ramp(time, 0, 0.7)), -1)
    end
end

local function StartFullPowerIfFull(value)
    local pulse = power.fullPower
    local playing = pulse.spikeTime or pulse.pulseTime

    if value == pulse.maxValue and inCombat then
        if pulse.fadeTime or not pulse.pulseTime then
            pulse.spikeTime = 0
        end
        pulse.fadeTime = nil
        pulse:SetAlpha(1)
        pulse.pulseTime = pulse.pulseTime or 0
        pulse:SetScript("OnUpdate", TickFullPower)
    elseif not pulse.fadeTime and playing then
        pulse.fadeTime = 0
        pulse:SetScript("OnUpdate", TickFullPower)
    end
end

local function OnFrameUpdate()
    if not predictedPowerCost then
        UpdatePredictedPowerCost(true)
    end

    if healDirty then
        healDirty = false
        UpdateHealthPrediction()
    end

    local value = UnitPower("player", powerType) - predictedPowerCost
    local old = currPowerValue or 0
    if value ~= currPowerValue and power:IsShown() then
        local maximum = power.feedback.maxValue
        if maximum ~= 0 and abs(value - old) / maximum > 0.1 then
            StartFeedback(old, value)
        end
        if power.fullPower.active then
            StartFullPowerIfFull(value)
        end
        currPowerValue = value
    end
end

-- =============================================================================
-- Layout
-- =============================================================================

local function Place(frame, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    frame:SetSize(width, height)
    frame.width, frame.height = width, height
    LayoutSlices(frame.trough.pieces, width + FRAME_LEFT + FRAME_RIGHT)
    LayoutSlices(frame.rim.pieces, width + FRAME_LEFT + FRAME_RIGHT)
    return y + height
end

local function Layout()
    if not content then return end

    local cfg = Cfg()
    local width = floor(BASE_WIDTH * Clamp(cfg.bar_width, 50, 150, 100) / 100 + 0.5)
    local scale = Clamp(cfg.size, 70, 150, 100) / 100
    local gap = MIN_PADDING + Clamp(cfg.padding, 0, 10, 0)
    local healthHeight = Clamp(cfg.health_height, 10, 30, 15)
    local powerHeight = Clamp(cfg.power_height, 10, 30, 15)
    local y = 0

    if cfg.hide_health then
        health:Hide()
    else
        y = Place(health, y, width, healthHeight) + gap
        health:Show()
    end

    if cfg.hide_power then
        power:Hide()
    else
        y = Place(power, y, width, powerHeight) + gap
        power:Show()
        AnchorPrediction()
    end

    -- Last in the stack, so reserving its slot for druids keeps the other bars still while shapeshifting.
    if PlayerClass() == "DRUID" and not cfg.hide_alt_power then
        y = Place(alt, y, width, powerHeight) + gap
    end

    local total = y > 0 and (y - gap) or 0
    if total < MIN_FRAME_HEIGHT then total = MIN_FRAME_HEIGHT end

    content:SetSize(width, total)
    content:SetScale(scale)
    content:SetAlpha(Clamp(cfg.opacity, 50, 100, 100) / 100)
    anchor:SetSize(width * scale, total * scale)

    SyncAlt()
end

local function ApplyPosition()
    if EditorActive() and anchor:GetNumPoints() > 0 then return end

    local widgets = addon.db.profile.widgets
    local cfg = widgets and widgets[KEY] or addon.defaults.profile.widgets[KEY]

    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY)
end

-- =============================================================================
-- Shown state and events
-- =============================================================================

local function RefreshAll()
    UpdateHealthColor()
    UpdateHealth()
    UpdatePowerBar()
end

local function ShouldShow()
    if not PersonalResource.applied then return false end
    if EditorActive() or previewing then return true end

    local mode = Cfg().visibility
    if mode == "combat" then return inCombat end
    return mode ~= "hidden"
end

local function UpdateShownState()
    if not content then return end

    if ShouldShow() then
        content:Show()
    else
        content:Hide()
    end
end

local function RegisterDataEvents()
    dataFrame:UnregisterAllEvents()
    dataFrame:RegisterEvent("UNIT_HEALTH")
    dataFrame:RegisterEvent("UNIT_MAXHEALTH")
    dataFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    for event in pairs(POWER_EVENTS) do dataFrame:RegisterEvent(event) end
    for event in pairs(CAST_EVENTS) do dataFrame:RegisterEvent(event) end
end

local function MarkHealDirty()
    healDirty = true
end

local function RegisterPredictionCallbacks()
    local healComm, absorbs = Libraries()
    if healComm then
        for _, event in ipairs(HEALCOMM_EVENTS) do
            healComm.RegisterCallback(callbackOwner, event, MarkHealDirty)
        end
    end

    if absorbs then
        absorbs.RegisterCallback(callbackOwner, "UnitUpdated", MarkHealDirty)
        absorbs.RegisterCallback(callbackOwner, "UnitCleared", MarkHealDirty)
    end
end

local function UnregisterPredictionCallbacks()
    local healComm, absorbs = Libraries()
    if healComm then healComm.UnregisterAllCallbacks(callbackOwner) end
    if absorbs then absorbs.UnregisterAllCallbacks(callbackOwner) end
end

dataFrame:SetScript("OnEvent", function(_, event, unit)
    if unit ~= "player" then return end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth()
    elseif POWER_EVENTS[event] then
        if event:find("^UNIT_MAX") then
            UpdateMaxPower()
        else
            UpdatePower()
        end
        if alt:IsShown() then UpdateAlt() end
    elseif event == "UNIT_DISPLAYPOWER" then
        UpdatePowerBar()
    elseif CAST_EVENTS[event] then
        UpdatePredictedPowerCost(event == "UNIT_SPELLCAST_START")
        UpdatePower()
    end
end)

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        local pulse = power and power.fullPower
        if pulse and pulse.active and (pulse.spikeTime or pulse.pulseTime) and not pulse.fadeTime then
            pulse.fadeTime = 0
            pulse:SetScript("OnUpdate", TickFullPower)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
        if content and content:IsShown() then RefreshAll() end
    end
    UpdateShownState()
end)

-- =============================================================================
-- Editor
-- =============================================================================

local function StartPreview()
    if not content then return end

    previewing = true
    UpdateShownState()
    RefreshAll()
end

local function StopPreview()
    previewing = false
    if not (content and PersonalResource.applied) then return end

    UpdateShownState()
    Layout()
end

local function CreateEditorFrame()
    addon:RegisterEditableFrame({
        name = KEY,
        frame = anchor,
        configPath = { "widgets", KEY },
        editorVisible = function()
            return addon:IsModuleEnabled(KEY)
        end,
        showTest = StartPreview,
        hideTest = StopPreview,
        onHide = function()
            ApplyPosition()
            if PersonalResource.applied then
                Layout()
                UpdateShownState()
            end
        end,
        module = PersonalResource,
    })
end

local function DarkModeChrome()
    local textures = {}
    for _, holder in ipairs({ health, power, alt }) do
        for _, art in ipairs({ holder.trough, holder.rim }) do
            for row = 1, 3 do
                for column = 1, 3 do
                    local piece = art.pieces[row][column]
                    if piece then textures[#textures + 1] = piece end
                end
            end
        end
    end
    return textures
end

-- =============================================================================
-- Lifecycle
-- =============================================================================

function addon.ApplyPersonalResourceSystem()
    if not content then
        CreateFrames()
        content:SetScript("OnShow", function()
            RegisterDataEvents()
            RegisterPredictionCallbacks()
            Layout()
            RefreshAll()
        end)
        content:SetScript("OnHide", function()
            dataFrame:UnregisterAllEvents()
            UnregisterPredictionCallbacks()
            EndFeedback()
            RemoveFullPowerAnims()
        end)
        content:SetScript("OnUpdate", OnFrameUpdate)
        CreateEditorFrame()
        if addon.RegisterDarkModeChrome then addon.RegisterDarkModeChrome(DarkModeChrome) end
    end

    PersonalResource.initialized = true
    PersonalResource.applied = true
    playerGUID = UnitGUID("player")
    inCombat = UnitAffectingCombat("player") and true or false

    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    ApplyPosition()
    Layout()
    if content:IsShown() then
        RegisterDataEvents()
        RegisterPredictionCallbacks()
        RefreshAll()
    end
    UpdateShownState()
end

function addon.RestorePersonalResourceSystem()
    PersonalResource.applied = false
    previewing = false

    eventFrame:UnregisterAllEvents()
    if content then content:Hide() end
end

function addon.RefreshPersonalResourceSystem()
    if addon:IsModuleEnabled(KEY) then
        addon.ApplyPersonalResourceSystem()
    else
        addon.RestorePersonalResourceSystem()
    end
end

-- Entry point for the editor sliders and toggles.
function addon.RefreshPersonalResource()
    if not PersonalResource.applied then return end

    Layout()
    UpdateHealthColor()
    UpdateHealth()
    UpdatePower()
    UpdateAlt()
    UpdateShownState()
end
