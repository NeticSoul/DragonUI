local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const
local abs = NP.abs
local min = NP.min
local max = NP.max
local sqrt = math.sqrt

-- Nameplates castbar: target sync, CLEU monitor, party casts.
-- Paths: target/focus/mouseover hooks; arena tokens; off-target CLEU; party/raid UNIT_SPELLCAST_*.

NP.castbar = NP.castbar or {}

function NP.castbar.GetCastBarFillProgress(bar)
    if not bar or not bar.GetMinMaxValues or not bar.GetValue then
        return nil
    end
    local minV, maxV = bar:GetMinMaxValues()
    local cur = bar:GetValue()
    if not maxV or maxV <= (minV or 0) or cur == nil then
        return nil
    end
    return (cur - minV) / (maxV - minV)
end

function NP.castbar.CastBarEndedEarly(bar, now)
    if not bar or not (bar.castingEx or bar.channelingEx) then
        return false
    end
    now = now or (GetTime and GetTime() or 0)
    if bar.castEndTime and now < bar.castEndTime - 0.15 then
        return true
    end
    local prog = NP.castbar.GetCastBarFillProgress(bar)
    if prog ~= nil and prog < 0.90 then
        return true
    end
    return false
end

function NP.castbar.ShouldInterruptOnCastLoss(plateData, bar)
    bar = bar or (plateData and plateData.minaCast)
    if not bar or bar._intHideAt or bar._interrupted then
        return false
    end
    if bar._notInterruptible or bar._nativeCastShield then
        return false
    end
    if not (bar.castingEx or bar.channelingEx) then
        return false
    end
    if not (bar.IsShown and bar:IsShown()) then
        return false
    end
    return NP.castbar.CastBarEndedEarly(bar)
end

-- Cache native castBarShield on OnShow for the full cast (Lua 5.1 forward decl).
local function ReadNativeCastShieldShown(plateData)
    local shield = plateData and plateData.castBarShield
    return shield and shield.IsShown and shield:IsShown() or false
end

local function ApplyNativeCastShieldSnap(plateData, bar)
    if not plateData or not bar then
        return
    end
    local shieldNow = ReadNativeCastShieldShown(plateData)
    bar._nativeCastShield = shieldNow
    bar._notInterruptible = shieldNow
end

local function ResolveCastNotInterruptible(plateData, bar, fromCastInfo)
    -- Off-target shield from native OnShow snap, not UnitCastingInfo.
    if bar and bar._nativeCastShield ~= nil then
        return bar._nativeCastShield
    end
    if fromCastInfo == true then
        return true
    end
    if fromCastInfo == false then
        return false
    end
    return ReadNativeCastShieldShown(plateData)
end

-- Native cast value tracking; early drop to zero treated as interrupt.
local function ResetNativeCastTrack(plateData)
    if not plateData then return end
    plateData._nativeCastMaxVal = nil
    plateData._nativeCastLastVal = nil
    plateData._nativeCastFirstVal = nil
    plateData._nativeCastSecondVal = nil
    plateData._nativeChanneling = nil
end

local function UpdateNativeCastTrack(plateData, val)
    val = tonumber(val) or 0
    if val < 0.002 then
        return
    end
    local src = plateData and plateData.castBar
    if not src or not src.GetMinMaxValues then
        return
    end
    local _, maxV = src:GetMinMaxValues()
    maxV = tonumber(maxV) or 0
    if maxV <= 0 then
        return
    end
    plateData._nativeCastMaxVal = maxV
    plateData._nativeCastLastVal = val
    if not plateData._nativeCastFirstVal then
        plateData._nativeCastFirstVal = val
    elseif not plateData._nativeCastSecondVal then
        plateData._nativeCastSecondVal = val
        if val < plateData._nativeCastFirstVal then
            plateData._nativeChanneling = true
        else
            plateData._nativeChanneling = false
        end
    end
end

local function NativeCastLooksInterrupted(plateData, bar)
    bar = bar or (plateData and plateData.minaCast)
    if bar and (bar._notInterruptible or bar._nativeCastShield) then
        return false
    end
    local peak = plateData and plateData._nativeCastLastVal
    local maxV = plateData and plateData._nativeCastMaxVal
    if not peak or not maxV or maxV <= 0 then
        return false
    end
    if plateData._nativeChanneling then
        return false
    end
    return (maxV - peak) >= 0.05
end

-- Native cast bar Hide/Show can fire spuriously (plate rebuilds, duel state) unrelated to the actual cast.
local function IsCastAuthoritativelyBound(bar)
    return bar ~= nil and bar._castSourceGUID ~= nil and not bar._fromCombatLog
end

local function ShouldShowNativeInterrupt(plateData, bar)
    bar = bar or (plateData and plateData.minaCast)
    if IsCastAuthoritativelyBound(bar) then
        return false
    end
    if NP.castbar.ShouldInterruptOnCastLoss(plateData, bar) then
        return true
    end
    return NativeCastLooksInterrupted(plateData, bar)
end

local function TryShowNativeInterrupt(plateData)
    if not plateData or not ShouldShowNativeInterrupt(plateData, plateData.minaCast) then
        return false
    end
    -- A pet/clone whose cast bar is hidden must not flash the interrupt visual
    -- when it dies/expires mid-cast.
    if NP.castbar.PlateCastHiddenAsPet(plateData) then
        return false
    end
    NP.layout.EnsureMinaStack(plateData)
    local bar = plateData.minaCast
    if not bar or bar._intHideAt or bar._interrupted then
        return false
    end
    NP.castbar.ShowInterruptedState(bar, plateData, false)
    return true
end

function NP.castbar.BindNativeCastPlateIdentity(plateData)
    if not plateData then
        return
    end
    NP.identity.UpdatePlateUnitToken(plateData)
    local bar = plateData.minaCast
    if bar then
        -- Recomputed below when a token resolves; cleared otherwise so a prior
        -- pet cast on a recycled plate cannot leak its flag into a new cast.
        bar._castOwnerIsPet = nil
    end
    local token = plateData.namePlateUnitToken
    if token and token ~= "" and UnitExists and UnitExists(token) then
        local guid = UnitGUID and UnitGUID(token)
        if guid and NP.state.GetPlateGUID(plateData) ~= guid then
            NP.state.SetPlateGUID(plateData, guid, {
                source = "NAMEPLATE_TOKEN",
                confidence = C.GUID_CONFIDENCE.NAMEPLATE_TOKEN,
            })
        end
        if bar then
            bar._castSourceGUID = guid
            bar._castOwnerIsPet = NP.castbar.IsPetCastUnit(token)
        end
    end
end

function NP.castbar.OnNativeCastShown(plateData)
    ResetNativeCastTrack(plateData)
    NP.layout.EnsureMinaStack(plateData)
    local bar = plateData.minaCast
    if bar then
        ApplyNativeCastShieldSnap(plateData, bar)
    end
    NP.castbar.BindNativeCastPlateIdentity(plateData)
    NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
    -- Shield may appear one frame after native cast OnShow.
    local snapFrame = plateData._castShieldSnapFrame
    if not snapFrame then
        snapFrame = CreateFrame("Frame")
        snapFrame:Hide()
        plateData._castShieldSnapFrame = snapFrame
    end
    snapFrame:SetScript("OnUpdate", function(self)
        self:Hide()
        if not NP.castbar.IsNativeCastVisible(plateData) then
            return
        end
        local b = plateData.minaCast
        if b and ReadNativeCastShieldShown(plateData) and not b._nativeCastShield then
            b._nativeCastShield = true
            b._notInterruptible = true
            if b.IsShown and b:IsShown() then
                NP.castbar.UpdateCastInterruptibleVisuals(b, plateData, false)
            end
            NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
        end
    end)
    snapFrame:Show()
end

function NP.castbar.OnNativeCastHidden(plateData)
    local snapFrame = plateData._castShieldSnapFrame
    if snapFrame then
        snapFrame:Hide()
        snapFrame:SetScript("OnUpdate", nil)
    end
    if TryShowNativeInterrupt(plateData) then
        if plateData.minaCast then
            plateData.minaCast._nativeCastShield = nil
        end
        ResetNativeCastTrack(plateData)
        return
    end
    if plateData.minaCast then
        plateData.minaCast._nativeCastShield = nil
    end
    ResetNativeCastTrack(plateData)
    NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
end

-- Cast bar texture helpers

local function PrepareCastFillTexture(tex)
    if not tex then return end
    if tex.SetHorizTile then tex:SetHorizTile(false) end
    if tex.SetVertTile then tex:SetVertTile(false) end
    if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
end

local function ForceCastBarTextureLayer(bar)
    local tex = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if tex and tex.SetDrawLayer then
        tex:SetDrawLayer("BORDER", 0)
    end
end

local function ApplyInterruptedHoldVisual(bar)
    if not bar then return end
    bar._applyingInterruptVisual = true
    if bar.InvalidateTextureCache then
        bar:InvalidateTextureCache()
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture(C.CAST_TEX_STANDARD)
    bar:SetStatusBarColor(1, 1, 1, 1)
    local tex = bar:GetStatusBarTexture()
    if tex and tex.SetTexCoord then
        tex:SetTexCoord(0, 1, 0, 1)
    end
    if tex and tex.SetVertexColor then
        tex:SetVertexColor(1, 1, 1, 1)
    end

    if bar._intBg then
        bar._intBg:SetTexture(C.MINA_TEX .. "bar-bar")
        if bar._intBg.SetVertexColor then
            bar._intBg:SetVertexColor(1, 1, 1, 1)
        end
        if bar._intBg.SetDrawLayer then
            bar._intBg:SetDrawLayer("ARTWORK", 2)
        end
        bar._intBg:Show()
    end

    if bar.UpdateTextureClipping then
        bar:UpdateTextureClipping(0, false)
    end
    ForceCastBarTextureLayer(bar)
    bar._applyingInterruptVisual = nil
end

local function GetInterruptedFadeDuration()
    return (C.CAST_INTERRUPT_HOLD or 0) + (C.CAST_INTERRUPT_FADE or 0.8)
end

local function GetSuccessFadeTimings()
    return 0.3, 0.5
end

local SUCCESS_FLASH_UV = {
    0.0009765625, 0.4169921875, 0.2421875, 0.30078125,
}

local function ShowSuccessFlashVisual(bar)
    local flash = bar and bar._successFlash
    if not flash then return end
    flash:SetAlpha(1)
    flash:Show()
end

local function HideSuccessFlashVisual(bar)
    local flash = bar and bar._successFlash
    if not flash then return end
    flash:SetAlpha(1)
    flash:Hide()
end

local function StartSuccessFade(bar)
    if not bar then return end
    if bar._successHoldUntil or bar._successHideAt then
        return
    end
    local holdDuration, fadeDuration = GetSuccessFadeTimings()
    local now = GetTime()
    bar._successHoldUntil = now + holdDuration
    bar._successFadeDuration = fadeDuration
    bar._successHideAt = nil
    bar._successFading = nil
    ShowSuccessFlashVisual(bar)
end

function NP.castbar.ShowInterruptedState(bar, plateData, isPartyBar)
    if not bar or not bar._intBg then
        return
    end
    if bar._intHideAt then
        return
    end

    bar.castingEx = false
    bar.channelingEx = false
    bar.castStartTime = nil
    bar.castEndTime = nil
    bar.spellName = nil
    bar._monitorGUID = nil
    bar._monitorConfidence = nil
    bar._fromCombatLog = nil
    bar:SetScript("OnUpdate", nil)

    if not isPartyBar and plateData and plateData.minaCastSpark then
        plateData.minaCastSpark:Hide()
    elseif isPartyBar and plateData and plateData.minaPartyCastSpark then
        plateData.minaPartyCastSpark:Hide()
    end

    if not isPartyBar and bar.minaCastIcon then
        bar.minaCastIcon:Hide()
    elseif isPartyBar and bar.minaIcon then
        bar.minaIcon:Hide()
    end
    if not isPartyBar and bar.minaCastShield then
        bar.minaCastShield:Hide()
    elseif isPartyBar and bar.minaShield then
        bar.minaShield:Hide()
    end

    ApplyInterruptedHoldVisual(bar)
    bar._interrupted = true
    bar._interruptFadeActive = true
    bar._successHoldUntil = nil
    bar._successHideAt = nil
    bar._successFadeDuration = nil
    bar._successFading = nil
    HideSuccessFlashVisual(bar)
    bar._intBg:Show()
    bar:Show()
    -- Preserve stack alpha from engine dimming.
    local fadeFrom = bar:GetAlpha() or 1
    local duration = GetInterruptedFadeDuration()
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(bar)
    end
    if UIFrameFadeOut then
        UIFrameFadeOut(bar, duration, fadeFrom, 0.0)
    end
    local now = GetTime()
    bar._intFadeAt = now
    bar._intHideAt = now + duration
    if plateData then
        NP.castbar.RegisterCastTick(plateData)
    end
end

local function ApplyCastShieldTexture(tex)
    if not tex then return end
    tex:SetTexture(C.CAST_TEX_ATLAS)
    tex:SetTexCoord(unpack(C.CAST_SHIELD_UV))
    tex:SetVertexColor(1, 1, 1, 1)
end

function NP.castbar.CreateCastIconShield(parentBar)
    local shield = CreateFrame("Frame", nil, parentBar)
    shield:SetFrameLevel(parentBar:GetFrameLevel() - 1)
    local tex = shield:CreateTexture(nil, "ARTWORK", nil, 3)
    tex:SetAllPoints(shield)
    ApplyCastShieldTexture(tex)
    shield:Hide()
    return shield
end

function NP.castbar.LayoutCastIconShield(shield, iconRef, iconSize, parentBar)
    if not shield or not iconRef then return end
    local size = iconSize or 14
    shield:SetSize(size * C.CAST_SHIELD_SIZE_W, size * C.CAST_SHIELD_SIZE_H)
    shield:ClearAllPoints()
    shield:SetPoint("CENTER", iconRef, "CENTER", C.CAST_SHIELD_OFFSET_X, C.CAST_SHIELD_OFFSET_Y)
    if parentBar and parentBar.GetFrameLevel then
        shield:SetFrameLevel(parentBar:GetFrameLevel() - 1)
    end
end

function NP.castbar.GetCastSpellIconSize(notInterruptible)
    local castH = select(1, NP.config.GetCastBarMetrics())
    local base = max(castH + 4, 14)
    if notInterruptible then
        return max(math.floor(base * C.CAST_NOTINT_ICON_SCALE + 0.5), 10)
    end
    return base
end

function NP.castbar.LayoutCastSpellIcon(icon, bar, notInterruptible)
    if not icon or not bar then return 14 end
    local iconSize = NP.castbar.GetCastSpellIconSize(notInterruptible)
    local anchorX, anchorY = -2, 0
    if notInterruptible then
        anchorX = anchorX + C.CAST_NOTINT_ICON_OFFSET_X
        anchorY = anchorY + C.CAST_NOTINT_ICON_OFFSET_Y
    end
    icon:ClearAllPoints()
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("RIGHT", bar, "LEFT", anchorX, anchorY)
    return iconSize
end

function NP.castbar.EnsureCastIconShieldFrame(bar, shieldKey, parentBar)
    local existing = bar[shieldKey]
    if existing and existing.GetObjectType and existing:GetObjectType() == "Frame" then
        if existing.GetParent and existing:GetParent() == parentBar then
            return existing
        end
        existing:Hide()
    elseif existing and existing.Hide then
        existing:Hide()
    end
    bar[shieldKey] = NP.castbar.CreateCastIconShield(parentBar)
    return bar[shieldKey]
end

-- Texture clipping

-- Shared clipping setup. allowZero=true lets progress<=0 clip to 0 (party bars);
-- otherwise the fill never drops below 0.01 (main bar).
local function AttachTextureClipping(statusBar, allowZero)
    local cachedTexture = nil
    local lastProgress = -1
    local lastChanneling = nil

    statusBar.UpdateTextureClipping = function(self, progress, isChanneling)
        if not cachedTexture then
            cachedTexture = self:GetStatusBarTexture()
            PrepareCastFillTexture(cachedTexture)
        end
        if not cachedTexture then return end
        if abs(progress - lastProgress) < 0.001 and isChanneling == lastChanneling then
            return
        end
        lastProgress = progress
        lastChanneling = isChanneling
        local right
        if allowZero and progress <= 0 then
            right = 0
        else
            right = max(0.01, min(0.99, progress))
        end
        cachedTexture:SetTexCoord(0, right, 0, 1)
    end

    statusBar.InvalidateTextureCache = function(self)
        cachedTexture = nil
        lastProgress = -1
        lastChanneling = nil
    end
end

function NP.castbar.CreateTextureClipping(statusBar)
    AttachTextureClipping(statusBar, false)
end

function NP.castbar.CreatePartyCastClipping(statusBar)
    AttachTextureClipping(statusBar, true)
end

-- Cast bar construction

-- Create the additive cast spark frame and attach it as bar.minaSpark.
local function CreateCastSpark(bar)
    local spark = CreateFrame("Frame", nil, bar)
    spark:SetFrameLevel(bar:GetFrameLevel() + 3)
    spark:SetSize(16, 16)
    spark:Hide()
    local sparkTex = spark:CreateTexture(nil, "OVERLAY")
    sparkTex:SetTexture(C.CAST_TEX_SPARK)
    sparkTex:SetAllPoints(spark)
    if sparkTex.SetBlendMode then
        sparkTex:SetBlendMode("ADD")
    end
    bar.minaSpark = spark
    return spark
end

function NP.castbar.CreateCastMinaBar(parent, plateData)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar._ownerPlateData = plateData
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(C.MINA_TEX .. "bar-bg")
    bar.minaBg = bg

    NP.discovery.AttachBarBorder(bar)
    NP.castbar.CreateTextureClipping(bar)

    plateData.minaCastSpark = CreateCastSpark(bar)

    bar.minaCastIcon = bar:CreateTexture(nil, "ARTWORK")
    bar.minaCastIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.minaCastIcon:Hide()
    bar.minaCastShield = NP.castbar.CreateCastIconShield(bar)
    bar._notInterruptible = false

    NP.castbar.EnsureCastInterruptOverlay(bar)
    bar._intHideAt = nil

    bar._successFlash = bar:CreateTexture(nil, "OVERLAY")
    bar._successFlash:SetAllPoints(bar)
    bar._successFlash:SetTexture(C.CAST_TEX_ATLAS)
    bar._successFlash:SetTexCoord(unpack(SUCCESS_FLASH_UV))
    bar._successFlash:SetBlendMode("ADD")
    bar._successFlash:Hide()

    bar.minaCastSpellName = bar:CreateFontString(nil, "OVERLAY")
    bar.minaCastSpellName:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.minaCastSpellName:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.minaCastSpellName:SetJustifyH("CENTER")
    bar.minaCastSpellName:SetWordWrap(false)
    bar.minaCastSpellName:Hide()

    return bar
end

function NP.castbar.CreatePartyCastBar(parent, plateData)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar._ownerPlateData = plateData
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(C.MINA_TEX .. "bar-bg")
    NP.discovery.AttachBarBorder(bar)
    NP.castbar.CreatePartyCastClipping(bar)
    plateData.minaPartyCastSpark = CreateCastSpark(bar)
    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:Hide()
    bar.minaIcon = icon
    bar.minaShield = NP.castbar.CreateCastIconShield(bar)
    NP.castbar.EnsureCastInterruptOverlay(bar)
    bar._intHideAt = nil
    return bar
end

-- Hard reset on recycled plates (bypasses fades)

local function HardResetCastBar(bar)
    if not bar then return end
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(bar)
    end
    bar.castingEx = false
    bar.channelingEx = false
    bar.castStartTime = nil
    bar.castEndTime = nil
    bar.spellName = nil
    bar._notInterruptible = false
    bar._castOwnerIsPet = nil
    bar._monitorGUID = nil
    bar._monitorConfidence = nil
    bar._fromCombatLog = nil
    bar._castSourceGUID = nil
    bar._interrupted = nil
    bar._interruptFadeActive = nil
    bar._applyingInterruptVisual = nil
    bar._intHideAt = nil
    bar._intFadeAt = nil
    bar._successHoldUntil = nil
    bar._successHideAt = nil
    bar._successFadeDuration = nil
    bar._successFading = nil
    bar._recentStopAt = nil
    bar:SetScript("OnUpdate", nil)
    bar:SetValue(0)
    bar:SetAlpha(1)
    if bar._intBg then bar._intBg:Hide() end
    HideSuccessFlashVisual(bar)
    if bar.minaCastIcon then bar.minaCastIcon:Hide() end
    if bar.minaCastShield then bar.minaCastShield:Hide() end
    if bar.minaCastSpellName then bar.minaCastSpellName:Hide() end
    if bar.minaIcon then bar.minaIcon:Hide() end
    if bar.minaShield then bar.minaShield:Hide() end
    if bar.minaSpark then bar.minaSpark:Hide() end
    bar:Hide()
end

function NP.castbar.ResetPlateCastBar(plateData)
    if not plateData then return end
    HardResetCastBar(plateData.minaCast)
    HardResetCastBar(plateData.minaPartyCast)
    NP.discovery.HideCastChrome(plateData)
end

-- Shared cast-unit helpers

local function UnitHasActiveCast(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    return UnitCastingInfo(unit) or UnitChannelInfo(unit)
end

-- 3.3.5a: no notInterruptible in UnitCastingInfo; do not treat spellId slot as shield flag.
local function IsCastNotInterruptibleFlag(value)
    return value == true
end

-- Buff spell IDs with interrupt immunity not reflected in native notInterruptible.
local PROTECTED_CAST_AURAS = {
    [642] = true, -- Divine Shield
    [54748] = true, -- Burning Determination (Dwarf racial: interrupt immunity after stun/fear)
    [45438] = true, -- Ice Block
    [31224] = true, -- Cloak of Shadows (spell immunity; imprecise for melee-based interrupts
                     -- like Kick/Pummel, same tolerance already accepted by this table)
}
local AURA_MASTERY_SPELLID = 31821
local CONCENTRATION_AURA_SPELLID = 19746

local function IsUnitProtectedFromInterrupt(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    local hasAuraMastery, hasConcentrationAura = false, false
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
        if not name then break end
        if PROTECTED_CAST_AURAS[spellID] then
            return true
        elseif spellID == AURA_MASTERY_SPELLID then
            hasAuraMastery = true
        elseif spellID == CONCENTRATION_AURA_SPELLID then
            hasConcentrationAura = true
        end
    end
    return hasAuraMastery and hasConcentrationAura
end

local function ShouldInterruptPartyEarlyEnd(unit, bar)
    if not unit or not bar or not (bar.castingEx or bar.channelingEx) then
        return false
    end
    if UnitHasActiveCast(unit) then
        return false
    end
    local endT = bar.castEndTime
    if endT then
        return GetTime() < (endT - 0.25)
    end
    return true
end

-- Party/raid cast tracker (group GUID, not name alone)

local PartyRaidCastTracker = { activeCasts = {} }
NP.castbar.PartyRaidCastTracker = PartyRaidCastTracker

local activeTickPlates = setmetatable({}, { __mode = "k" })

function NP.castbar.RegisterCastTick(plateData)
    if plateData then
        activeTickPlates[plateData] = true
    end
end

function NP.castbar.UnregisterCastTick(plateData)
    if plateData then
        activeTickPlates[plateData] = nil
    end
end

local function PlateNeedsCastTick(plateData)
    if not plateData then
        return false
    end
    local bar = plateData.minaCast
    if bar then
        if bar._intHideAt or bar._successHoldUntil or bar._successHideAt then
            return true
        end
        if bar.IsShown and bar:IsShown() and (bar.castingEx or bar.channelingEx) then
            return true
        end
    end
    local partyBar = plateData.minaPartyCast
    if partyBar then
        if partyBar._intHideAt then
            return true
        end
        if partyBar.IsShown and partyBar:IsShown()
            and (partyBar.castingEx or partyBar.channelingEx) then
            return true
        end
    end
    return false
end

local function RefreshCastTickRegistration(plateData)
    if PlateNeedsCastTick(plateData) then
        activeTickPlates[plateData] = true
    else
        activeTickPlates[plateData] = nil
    end
end

local function PlateHasActivePartyCast(plateData)
    return plateData and PartyRaidCastTracker.activeCasts[plateData] ~= nil
end

function NP.castbar.LayoutPartyCastBar(plateData)
    local bar = plateData.minaPartyCast
    local border = plateData.border
    if not bar or not border then return end

    local cfg = NP.config.GetCfg()
    if cfg.showPartyRaidCastBars ~= true then return end

    local anchor = NP.layout.GetCastStackAnchor(plateData)
    if not anchor then return end

    -- Match main castbar stack: below power (when shown) or health, same width/height/gap.
    local visW = select(1, NP.native_style.GetBarMetrics(border))
    local castH = select(1, NP.config.GetCastBarMetrics())
    local stackGap = NP.config.GetStackBarGap()

    bar:ClearAllPoints()
    bar:SetSize(visW, castH)
    bar:SetPoint("TOP", anchor, "BOTTOM", 0, -stackGap)

    if bar.minaIcon then
        NP.castbar.LayoutCastSpellIcon(bar.minaIcon, bar, bar._notInterruptible)
    end

    if bar.minaShield and bar.minaIcon and bar._notInterruptible then
        local iconSize = NP.castbar.GetCastSpellIconSize(true)
        NP.castbar.LayoutCastIconShield(bar.minaShield, bar.minaIcon, iconSize, bar)
    end
end

function PartyRaidCastTracker:HideBar(plateData)
    if not plateData then return end
    self.activeCasts[plateData] = nil
    local bar = plateData.minaPartyCast
    if bar then
        local wasInterrupted = bar._interrupted
        bar.castingEx = false
        bar.channelingEx = false
        bar.castStartTime = nil
        bar.castEndTime = nil
        bar.spellName = nil
        bar._notInterruptible = false
        bar:SetScript("OnUpdate", nil)
        bar:SetValue(0)
        if wasInterrupted and bar._intBg then
            NP.castbar.ShowInterruptedState(bar, plateData, true)
        else
            bar:Hide()
        end
    end
    if plateData.minaPartyCastSpark then
        plateData.minaPartyCastSpark:Hide()
    end
    if bar and bar.minaIcon then
        bar.minaIcon:Hide()
    end
    if bar and bar.minaShield then
        bar.minaShield:Hide()
    end
    RefreshCastTickRegistration(plateData)
end

-- Group plate: GUID map first, unique name fallback.
local function FindPlateForGroupUnit(unit)
    local guid = UnitExists(unit) and UnitGUID(unit)
    if not guid then return nil end
    local name = NP.native_style.StripRealm(UnitName(unit))
    return NP.identity.FindPlateForGroupGUID(guid, name)
end

function PartyRaidCastTracker:StartCast(unit, isChannel)
    local name, _, _, texture, startMS, endMS, notInterruptible
    if isChannel then
        name, _, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
    else
        name, _, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
    end
    startMS = tonumber(startMS)
    endMS = tonumber(endMS)
    if not name or not startMS or not endMS then return end

    local plateData = FindPlateForGroupUnit(unit)
    if not plateData or not plateData.minaPartyCast then return end

    -- Headline mode shows only the name for party/raid plates: no cast bar.
    if NP.gather.IsFriendlyNameOnlyActive(plateData) then return end

    -- Plates resolved as target/focus already render the main castbar.
    local resolvedUnit = NP.identity.ResolvePlateUnit(plateData)
    if resolvedUnit == "target" or resolvedUnit == "focus" then return end

    -- Keep the party bar exclusive with minaCast; residual monitor state may
    -- otherwise leave the main cast spark visible.
    NP.castbar.HideNativeCastVisual(plateData)
    NP.castbar.HidePlateCastBar(plateData, true)

    local bar = plateData.minaPartyCast
    local startT = startMS / 1000
    local endT = endMS / 1000

    self.activeCasts[plateData] = { unit = unit, guid = UnitGUID(unit), channeling = isChannel }

    bar._interrupted = nil
    bar._intHideAt = nil
    bar._intFadeAt = nil
    if bar._intBg then bar._intBg:Hide() end

    bar._notInterruptible = IsCastNotInterruptibleFlag(notInterruptible) or IsUnitProtectedFromInterrupt(unit)
    bar.castStartTime = startT
    bar.castEndTime = endT
    bar.spellName = name

    if bar.InvalidateTextureCache then
        bar:InvalidateTextureCache()
    end
    if isChannel then
        bar:SetStatusBarTexture(C.CAST_TEX_CHANNEL)
        bar:SetStatusBarColor(C.CAST_COLOR_CHANNEL[1], C.CAST_COLOR_CHANNEL[2], C.CAST_COLOR_CHANNEL[3], 1)
        bar.channelingEx = true
        bar.castingEx = false
    else
        bar:SetStatusBarTexture(C.CAST_TEX_STANDARD)
        bar:SetStatusBarColor(C.CAST_COLOR_STANDARD[1], C.CAST_COLOR_STANDARD[2], C.CAST_COLOR_STANDARD[3], 1)
        bar.castingEx = true
        bar.channelingEx = false
    end
    PrepareCastFillTexture(bar:GetStatusBarTexture())
    ForceCastBarTextureLayer(bar)

    NP.castbar.LayoutPartyCastBar(plateData)

    bar:SetMinMaxValues(0, 1)
    bar:Show()
    NP.castbar.SyncPartyCastProgress(bar)

    if bar.minaIcon then
        if texture and texture ~= "" then
            bar.minaIcon:SetTexture(texture)
            bar.minaIcon:Show()
        else
            bar.minaIcon:Hide()
        end
    end
    NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, true)
    NP.castbar.RegisterCastTick(plateData)
end

function PartyRaidCastTracker:FindPlateForUnit(unit)
    for plateData, info in pairs(self.activeCasts) do
        if info.unit == unit then
            return plateData
        end
    end
    return nil
end

function PartyRaidCastTracker:StopCast(unit, interrupted)
    if not unit then return end
    local plateData = self:FindPlateForUnit(unit)
    if not plateData then return end
    local bar = plateData.minaPartyCast
    if bar and (interrupted or ShouldInterruptPartyEarlyEnd(unit, bar)) then
        NP.castbar.ShowInterruptedState(bar, plateData, true)
        self.activeCasts[plateData] = nil
        return
    end
    self:HideBar(plateData)
end

function PartyRaidCastTracker:UpdateCastTime(unit)
    if not unit then return end
    local plateData = self:FindPlateForUnit(unit)
    if not plateData then return end
    local bar = plateData.minaPartyCast
    if bar and bar:IsShown() and bar.castStartTime and bar.castEndTime then
        local _, _, _, _, startMS, endMS = UnitCastingInfo(unit)
        startMS = tonumber(startMS)
        endMS = tonumber(endMS)
        if not startMS then
            _, _, _, _, startMS, endMS = UnitChannelInfo(unit)
            startMS = tonumber(startMS)
            endMS = tonumber(endMS)
        end
        if startMS and endMS then
            bar.castStartTime = startMS / 1000
            bar.castEndTime = endMS / 1000
        end
    end
end

function PartyRaidCastTracker:OnEvent(event, unit, ...)
    if not unit then return end
    if not unit:match("^party[1-4]$") and not unit:match("^raid%d+$") then
        return
    end
    local cfg = NP.config.GetCfg()
    if cfg.showPartyRaidCastBars ~= true then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        self:StartCast(unit, event == "UNIT_SPELLCAST_CHANNEL_START")
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        self:UpdateCastTime(unit)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        self:StopCast(unit, true)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        self:StopCast(unit, event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_FAILED_QUIET")
    end
end

function PartyRaidCastTracker:Cleanup()
    for pd in pairs(self.activeCasts) do
        self:HideBar(pd)
    end
    self.activeCasts = {}
end

-- CLEU cast monitor for off-target plates

local RAID_ICON_NAMES = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }
local CLEU_WARMUP_EVENTS = {
    SWING_DAMAGE = true,
    SWING_MISSED = true,
    RANGE_DAMAGE = true,
    RANGE_MISSED = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    SPELL_MISSED = true,
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_CAST_SUCCESS = true,
    SPELL_HEAL = true,
    SPELL_PERIODIC_HEAL = true,
    SPELL_ENERGIZE = true,
    SPELL_PERIODIC_ENERGIZE = true,
}
-- Exported for engine CLEU subevent gating.
NP.castbar.CLEU_WARMUP_EVENTS = CLEU_WARMUP_EVENTS
local CLEU_GUID_WARMUP_AT = {}

local function IsOffTargetMonitorEnabled(cfg)
    if not cfg or cfg.showCastBar == false then
        return false
    end
    return NP.config.IsOffTargetCastMonitorActive(cfg)
end

-- Hybrid CLEU routing: stash player vs NPC for mode helpers during event handling.
local CurrentCastSourceIsPlayer = nil

local function EffectiveCastMode(cfg)
    return NP.config.ResolveEffectiveCastMode(cfg, CurrentCastSourceIsPlayer)
end

local function IsOffTargetSafeOnly(cfg)
    return cfg and EffectiveCastMode(cfg) == "safe"
end

local function IsAggressiveCastMonitor(cfg)
    return cfg and EffectiveCastMode(cfg) == "aggressive"
end

local function IsVisiblePlate(pd)
    return pd and pd.plate and pd.plate.IsShown and pd.plate:IsShown()
end

-- Strong identity sources; block aggressive CLEU on GUID owned elsewhere.
local STRONG_PLATE_GUID_SOURCES = {
    TOKEN_TARGET = true,
    TOKEN_MOUSEOVER = true,
    TOKEN_FOCUS = true,
    NAMEPLATE_TOKEN = true,
    ARENA_TOKEN = true,
    GROUP_TARGET = true,
    RAID_ICON = true,
}

local function IsStrongPlateGUIDSource(source)
    return source and STRONG_PLATE_GUID_SOURCES[source] == true
end

local function PlateHasStrongForeignGUID(plateData, sourceGUID)
    if not plateData or not sourceGUID then
        return false
    end
    local plateGuid = NP.state.GetPlateGUID(plateData)
    if not plateGuid or plateGuid == sourceGUID then
        return false
    end
    if NP.state.IsGUIDLocked(plateData) then
        return true
    end
    if IsStrongPlateGUIDSource(plateData._guidSource) then
        return true
    end
    return (NP.state.GetPlateGUIDConfidence(plateData) or 0)
        >= (C.GUID_CONFIDENCE.GROUP_TARGET or 70)
end

local function PlateMayReceiveMonitorCast(plateData, sourceGUID)
    -- Skip mirror-image / clone plates for monitor cast binding.
    if NP.identity.IsLikelyMirrorImagePlate(plateData) then
        return false
    end
    return not PlateHasStrongForeignGUID(plateData, sourceGUID)
end

-- Aggressive monitor: sticky guid→plate map, name-verified on reuse.
local CastMonitorGuidToPlate = {}
local CastMonitorPlateToGuid = setmetatable({}, { __mode = "k" })

local function StripCastSourceName(sourceName)
    -- Do not strsplit first: that turns "Blood-Queen Lana'thel" into "Blood"
    -- before StripRealm can preserve the spaced NPC compound.
    return sourceName and NP.native_style.StripRealm(sourceName) or nil
end

local function ClearCastMonitorStickyForGUID(guid)
    if not guid then
        return
    end
    local plateData = CastMonitorGuidToPlate[guid]
    if plateData then
        CastMonitorPlateToGuid[plateData] = nil
    end
    CastMonitorGuidToPlate[guid] = nil
end

local function ClearCastMonitorStickyForPlate(plateData)
    if not plateData then
        return
    end
    local guid = CastMonitorPlateToGuid[plateData]
    if guid then
        if CastMonitorGuidToPlate[guid] == plateData then
            CastMonitorGuidToPlate[guid] = nil
        end
        CastMonitorPlateToGuid[plateData] = nil
    end
end

local function CommitCastMonitorSticky(sourceGUID, plateData)
    if not sourceGUID or not plateData or not IsAggressiveCastMonitor(NP.config.GetCfg()) then
        return
    end
    if not PlateMayReceiveMonitorCast(plateData, sourceGUID) then
        return
    end
    local plateGuid = NP.state.GetPlateGUID(plateData)
    if plateGuid and plateGuid ~= sourceGUID then
        return
    end
    local oldGuid = CastMonitorPlateToGuid[plateData]
    if oldGuid and oldGuid ~= sourceGUID then
        if CastMonitorGuidToPlate[oldGuid] == plateData then
            CastMonitorGuidToPlate[oldGuid] = nil
        end
    end
    local oldPlate = CastMonitorGuidToPlate[sourceGUID]
    if oldPlate and oldPlate ~= plateData then
        CastMonitorPlateToGuid[oldPlate] = nil
    end
    CastMonitorGuidToPlate[sourceGUID] = plateData
    CastMonitorPlateToGuid[plateData] = sourceGUID
end

local function TryCastMonitorStickyMatch(sourceGUID, sourceName, cfg)
    if not IsAggressiveCastMonitor(cfg) or not sourceGUID then
        return nil
    end
    local plateData = CastMonitorGuidToPlate[sourceGUID]
    if not plateData or not IsVisiblePlate(plateData) then
        if plateData then
            ClearCastMonitorStickyForGUID(sourceGUID)
        end
        return nil
    end
    local wantName = StripCastSourceName(sourceName)
    if wantName and plateData.plateName ~= wantName then
        ClearCastMonitorStickyForGUID(sourceGUID)
        return nil
    end
    if not PlateMayReceiveMonitorCast(plateData, sourceGUID) then
        ClearCastMonitorStickyForGUID(sourceGUID)
        return nil
    end
    local plateGuid = NP.state.GetPlateGUID(plateData)
    if plateGuid and plateGuid ~= sourceGUID then
        ClearCastMonitorStickyForGUID(sourceGUID)
        return nil
    end
    local confidence = C.CAST_AGGRESSIVE_MONITOR_MIN_CONFIDENCE or 50
    if NP.state.GetPlateGUID(plateData) == sourceGUID then
        confidence = max(confidence, C.GUID_CONFIDENCE.GROUP_TARGET or 70)
    end
    return plateData, confidence + 10, "CAST_MONITOR_STICKY"
end

local function ResetCastMonitorStickyMaps()
    for guid in pairs(CastMonitorGuidToPlate) do
        CastMonitorGuidToPlate[guid] = nil
    end
    for plateData in pairs(CastMonitorPlateToGuid) do
        CastMonitorPlateToGuid[plateData] = nil
    end
end

local function IsPlayersOnlyMonitor(cfg)
    if not cfg or not NP.config.IsOffTargetCastMonitorActive(cfg) then
        return false
    end
    -- Hybrid does its own per-source routing; legacy players-only filter does not apply.
    if NP.config.IsHybridCastMode(cfg) then
        return false
    end
    if cfg.castBarPvPAggressive ~= true then
        return false
    end
    -- When Safe: players-only only applies with hostile-only (enemy players, not allies).
    if IsOffTargetSafeOnly(cfg) and cfg.castBarOffTargetHostileOnly ~= true then
        return false
    end
    return true
end

local function ShouldRequireHostileReaction(cfg)
    if not cfg or not NP.config.IsOffTargetCastMonitorActive(cfg) then
        return false
    end
    -- Hybrid intentionally tracks both factions (enemy players and allies); the
    -- legacy hostile-only filter is ignored.
    if NP.config.IsHybridCastMode(cfg) then
        return false
    end
    return cfg.castBarOffTargetHostileOnly == true
end

local function ShouldUseNativePatchSync(cfg)
    if not cfg or cfg.showCastBar == false then
        return false
    end
    return true
end

local function RaidIconNameFromFlags(flags)
    if not flags or not COMBATLOG_OBJECT_RAIDTARGET_MASK then return nil end
    if bit.band(flags, COMBATLOG_OBJECT_RAIDTARGET_MASK) == 0 then return nil end
    for i = 1, 8 do
        local mask = _G["COMBATLOG_OBJECT_RAIDTARGET" .. i]
        if mask and bit.band(flags, mask) ~= 0 then
            return RAID_ICON_NAMES[i]
        end
    end
    return nil
end

local function NormalizeCombatLogFlags(flags)
    if type(flags) == "string" then
        return tonumber(flags) or tonumber(flags, 16)
    end
    return flags
end

local function IsHostileCombatLogFlags(flags)
    flags = NormalizeCombatLogFlags(flags)
    if not flags or not COMBATLOG_OBJECT_REACTION_HOSTILE then
        return false
    end
    return bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
end

local function IsPlayerUnitFlags(flags)
    flags = NormalizeCombatLogFlags(flags)
    if not flags or not COMBATLOG_OBJECT_TYPE_PLAYER then
        return false
    end
    return bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
end

-- TYPE_PET / TYPE_GUARDIAN for pets and guardians.
local function IsPetOrGuardianFlags(flags)
    flags = NormalizeCombatLogFlags(flags)
    if not flags then
        return false
    end
    if COMBATLOG_OBJECT_TYPE_PET and bit.band(flags, COMBATLOG_OBJECT_TYPE_PET) ~= 0 then
        return true
    end
    if COMBATLOG_OBJECT_TYPE_GUARDIAN and bit.band(flags, COMBATLOG_OBJECT_TYPE_GUARDIAN) ~= 0 then
        return true
    end
    return false
end

-- Pet units on unit/native paths (arenapetN, party pets).
function NP.castbar.IsPetCastUnit(unit)
    if not unit or unit == "" then
        return false
    end
    if string.find(unit, "^arenapet%d+$") then
        return true
    end
    if not UnitExists(unit) then
        return false
    end
    if UnitIsPlayer(unit) then
        return false
    end
    return UnitPlayerControlled(unit) == true
end

local function IsAuthoritativeCastUnit(unit)
    return unit == "target" or unit == "mouseover" or unit == "focus"
end

-- arena1..5 / arenapet1..5: same tokens the default arena enemy frames use.
-- UnitCastingInfo + UNIT_SPELLCAST_* work without target or mouseover.
local function IsArenaCastUnit(unit)
    if not unit or not NP.module.inArena then
        return false
    end
    return string.find(unit, "^arena%d+$") ~= nil
        or string.find(unit, "^arenapet%d+$") ~= nil
end

local function IsReliableCastUnit(unit)
    return IsAuthoritativeCastUnit(unit) or IsArenaCastUnit(unit)
end

local function GetPlateCastOwnerGUID(plateData, bar)
    bar = bar or (plateData and plateData.minaCast)
    if bar then
        if bar._castSourceGUID then
            return bar._castSourceGUID
        end
        if bar._monitorGUID then
            return bar._monitorGUID
        end
    end
    if plateData then
        return NP.state.GetPlateGUID(plateData)
    end
    return nil
end

-- UNIT_SPELLCAST_* unit tokens are reused on retarget; match by GUID, not token name.
local function PlateCastMatchesEventUnit(plateData, unit, bar)
    bar = bar or (plateData and plateData.minaCast)
    if not plateData or not unit or not UnitExists(unit) then
        return false
    end
    local eventGUID = UnitGUID(unit)
    if not eventGUID then
        return false
    end
    local ownerGUID = GetPlateCastOwnerGUID(plateData, bar)
    if ownerGUID then
        return ownerGUID == eventGUID
    end
    local castResolved = NP.identity.ResolvePlateCastUnit(plateData)
    if castResolved == unit then
        local resolvedGUID = UnitGUID(castResolved)
        return resolvedGUID and resolvedGUID == eventGUID
    end
    return false
end

local function GetAuthoritativeCastUnit(plateData)
    if not plateData then
        return nil
    end
    local bar = plateData.minaCast
    local ownerGUID = GetPlateCastOwnerGUID(plateData, bar)
    local unit = NP.identity.ResolvePlateCastUnit(plateData)
    if unit and UnitExists(unit) then
        local unitGUID = UnitGUID(unit)
        if IsReliableCastUnit(unit) then
            if ownerGUID and unitGUID and ownerGUID ~= unitGUID then
                return nil
            end
            return unit
        end
        -- Trust group-target tokens for early-end once GUID-verified against cast owner.
        if ownerGUID and unitGUID and ownerGUID == unitGUID then
            return unit
        end
    end
    if ownerGUID then
        if UnitExists("target") and UnitGUID("target") == ownerGUID then
            return "target"
        end
        if UnitExists("focus") and UnitGUID("focus") == ownerGUID then
            return "focus"
        end
        if UnitExists("mouseover") and UnitGUID("mouseover") == ownerGUID then
            return "mouseover"
        end
    end
    return nil
end

-- Detect target/focus/mouseover casts that end before castEndTime.
local function ShouldInterruptAuthoritativeEarlyEnd(plateData, bar, now)
    now = now or GetTime()
    bar = bar or (plateData and plateData.minaCast)
    if not bar or not (bar.castingEx or bar.channelingEx) then
        return false
    end
    local unit = GetAuthoritativeCastUnit(plateData)
    if not unit or UnitHasActiveCast(unit) then
        return false
    end
    local endT = bar.castEndTime
    if endT then
        return now < (endT - 0.25)
    end
    -- Native-driven bar (no stored end); unit API already cleared.
    return true
end

local function ShouldIgnoreUnitCastStop(bar, unit, eventSpell)
    if not bar or not bar._fromCombatLog then
        return false
    end
    -- CLEU monitor casts end via combat log; nameplate/group tokens lie off-target.
    if not IsAuthoritativeCastUnit(unit) and not IsArenaCastUnit(unit) then
        return true
    end
    if eventSpell and bar.spellName and eventSpell ~= bar.spellName then
        return true
    end
    return false
end

local AUTHORITATIVE_GUID_SOURCE = {
    target = "TOKEN_TARGET",
    mouseover = "TOKEN_MOUSEOVER",
    focus = "TOKEN_FOCUS",
}

local function BindCastSourceIdentity(plateData, unit, bar)
    if not plateData or not unit or not IsReliableCastUnit(unit) then
        return nil
    end
    if not UnitExists(unit) then
        return nil
    end
    local guid = UnitGUID(unit)
    if not guid then
        return nil
    end
    local source = AUTHORITATIVE_GUID_SOURCE[unit]
    if not source and IsArenaCastUnit(unit) then
        source = "ARENA_TOKEN"
    end
    if not source then
        return nil
    end
    local confidence = (C.GUID_CONFIDENCE and C.GUID_CONFIDENCE[source]) or 60
    NP.state.SetPlateGUID(plateData, guid, {
        source = source,
        confidence = confidence,
    })
    if bar then
        bar._castSourceGUID = guid
    end
    return guid
end

-- Incapacitate/disorient auras that stop casts without SPELL_INTERRUPT in CLEU.
local function AuraBreaksActiveCast(spellId, combatSpellName)
    local name = combatSpellName
    if spellId then
        local infoName = GetSpellInfo(spellId)
        if infoName and infoName ~= "" then
            name = infoName
        end
    end
    if not name or name == "" then
        return false
    end
    if name:find("^Polymorph") then return true end
    if name == "Cyclone" then return true end
    if name == "Hibernate" then return true end
    if name == "Repentance" then return true end
    if name == "Banish" then return true end
    if name:find("^Shackle Undead") then return true end
    if name == "Sap" then return true end
    if name == "Blind" then return true end
    return false
end

local function CastEndMatchesBar(bar, endingSpellName)
    if not bar then
        return false
    end
    if not endingSpellName or endingSpellName == "" then
        return true
    end
    if not bar.spellName or bar.spellName == "" then
        return true
    end
    if bar.spellName == endingSpellName then
        return true
    end
    -- Monitor already owns a newer cast; ignore stale SUCCESS from the prior spell.
    if bar._fromCombatLog then
        return false
    end
    return false
end

-- Safe-only GUID binds: strong unit/token sources only (no CLEU warmup / aura hints).
local function IsStrongSafeGUIDSource(source)
    return IsStrongPlateGUIDSource(source)
end

local function TryGUIDMapMatch(sourceGUID, cfg)
    local plateData = NP.state.GUIDToPlate[sourceGUID]
    if not IsVisiblePlate(plateData) then
        plateData = nil
    end
    if plateData then
        local plateGuid = NP.state.GetPlateGUID(plateData)
        if plateGuid and plateGuid ~= sourceGUID then
            if NP.state.GUIDToPlate[sourceGUID] == plateData then
                NP.state.GUIDToPlate[sourceGUID] = nil
            end
            ClearCastMonitorStickyForGUID(sourceGUID)
            plateData = nil
        end
    end
    if not plateData then
        for _, pd in pairs(NP.module.plates) do
            if IsVisiblePlate(pd) and NP.state.GetPlateGUID(pd) == sourceGUID then
                plateData = pd
                NP.state.GUIDToPlate[sourceGUID] = pd
                break
            end
        end
    end
    if not plateData then
        return nil
    end
    if IsAggressiveCastMonitor(cfg) and not PlateMayReceiveMonitorCast(plateData, sourceGUID) then
        return nil
    end
    local guidConfidence = NP.state.GetPlateGUIDConfidence(plateData) or 0
    if IsOffTargetSafeOnly(cfg) then
        if not IsStrongSafeGUIDSource(plateData._guidSource) then
            return nil
        end
        return plateData, guidConfidence, "GUID_MAP"
    end
    return plateData, max(guidConfidence, C.GUID_CONFIDENCE.NAMEPLATE_TOKEN or 0), "GUID_MAP"
end

-- Hover/target cast sync can teach a GUID before plate.guid / GUIDToPlate are populated.
local function TryCastTaughtGUIDMatch(sourceGUID, cfg)
    if not IsOffTargetSafeOnly(cfg) or not sourceGUID then
        return nil
    end
    for _, pd in pairs(NP.module.plates) do
        if IsVisiblePlate(pd) then
            local bar = pd.minaCast
            local taughtGUID = bar and bar._castSourceGUID
            if NP.identity.FriendlyPlateMayUseGUID(pd, sourceGUID)
                and (taughtGUID == sourceGUID or NP.state.GetPlateGUID(pd) == sourceGUID
                    or (bar and bar._monitorGUID == sourceGUID)) then
                if not IsStrongSafeGUIDSource(pd._guidSource) then
                    NP.state.SetPlateGUID(pd, sourceGUID, {
                        source = "TOKEN_MOUSEOVER",
                        confidence = C.GUID_CONFIDENCE.TOKEN_MOUSEOVER or 90,
                    })
                end
                if bar and not bar._castSourceGUID then
                    bar._castSourceGUID = sourceGUID
                end
                return pd, NP.state.GetPlateGUIDConfidence(pd) or (C.GUID_CONFIDENCE.TOKEN_MOUSEOVER or 90), "CAST_TAUGHT_GUID"
            end
        end
    end
    return nil
end

local function TryGroupTargetMatch(sourceGUID)
    for _, pd in pairs(NP.module.plates) do
        if pd and pd._matchedCastUnit and IsVisiblePlate(pd) then
            local unitGuid = UnitGUID(pd._matchedCastUnit)
            if unitGuid and unitGuid == sourceGUID then
                return pd, C.GUID_CONFIDENCE.GROUP_TARGET or 0, "GROUP_TARGET"
            end
        end
    end
    return nil
end

local function TryRaidIconMatch(sourceFlags)
    local iconName = RaidIconNameFromFlags(sourceFlags)
    if not iconName then
        return nil
    end
    local found
    local count = 0
    for _, pd in pairs(NP.module.plates) do
        if IsVisiblePlate(pd)
            and NP.native_style.GetPlateRaidIconName(pd) == iconName then
            count = count + 1
            found = pd
            if count > 1 then
                return nil
            end
        end
    end
    if found then
        return found, C.GUID_CONFIDENCE.RAID_ICON or 0, "RAID_ICON"
    end
    return nil
end

local function ScoreCastSourceCandidate(pd, sourceGUID, cfg)
    if not IsVisiblePlate(pd) then
        return -math.huge, false
    end
    if IsAggressiveCastMonitor(cfg) and PlateHasStrongForeignGUID(pd, sourceGUID) then
        return -math.huge, false
    end

    local score = 0
    local hasStrongHint = false
    local aggressive = IsAggressiveCastMonitor(cfg)
    if aggressive then
        score = score + (C.CAST_AGGRESSIVE_NAME_BASE_BONUS or 50)
        if sourceGUID then
            local authoritative = C.CAST_AGGRESSIVE_AUTHORITATIVE_BONUS or 10000
            if NP.state.GetPlateGUID(pd) == sourceGUID then
                score = score + authoritative
                hasStrongHint = true
            elseif pd._matchedCastUnit and UnitGUID(pd._matchedCastUnit) == sourceGUID then
                score = score + authoritative
                hasStrongHint = true
            end
            local claimPenalty = C.CAST_AGGRESSIVE_GUID_CLAIM_PENALTY or 200
            local plateGuid = NP.state.GetPlateGUID(pd)
            if plateGuid and plateGuid ~= sourceGUID then
                score = score - claimPenalty
            end
            local stickyGuid = CastMonitorPlateToGuid[pd]
            if stickyGuid and stickyGuid ~= sourceGUID then
                score = score - claimPenalty
            end
        end
    end
    local hb = pd.healthBar
    if hb and hb.GetValue and hb.GetMinMaxValues then
        local cur = hb:GetValue()
        local _, maxVal = hb:GetMinMaxValues()
        if maxVal and maxVal > 0 and cur and cur < (maxVal - 1) then
            score = score + (C.CAST_NAME_SCORE_DAMAGED_BONUS or 10)
        end
    end

    local plate = pd.plate
    if plate and plate.GetCenter then
        local px, py = plate:GetCenter()
        if px and py and GetScreenWidth and GetScreenHeight then
            local sx = GetScreenWidth() * 0.5
            local sy = GetScreenHeight() * 0.5
            local dx = px - sx
            local dy = py - sy
            local dist = sqrt(dx * dx + dy * dy)
            local centerBonus = C.CAST_NAME_SCORE_CENTER_BONUS or 30
            score = score + max(0, centerBonus - dist * 0.05)
        end
    end

    if sourceGUID then
        if pd._matchedCastUnit and UnitGUID(pd._matchedCastUnit) == sourceGUID then
            score = score + (C.CAST_NAME_SCORE_MATCHED_UNIT_BONUS or 35)
            hasStrongHint = true
        end
        local bar = pd.minaCast
        if bar and bar._monitorGUID and bar._monitorGUID == sourceGUID then
            score = score + (C.CAST_NAME_SCORE_MONITOR_GUID_BONUS or 40)
            hasStrongHint = true
        end
    end

    return score, hasStrongHint
end

local function FindBestScoredNameMatch(sourceName, sourceGUID, cfg)
    if IsOffTargetSafeOnly(cfg) then
        return nil
    end
    if not sourceName then
        return nil
    end

    local best, second
    local bestStrongHint = false
    local bestScore, secondScore = -math.huge, -math.huge

    local aggressive = IsAggressiveCastMonitor(cfg)

    for _, pd in pairs(NP.module.plates) do
        if IsVisiblePlate(pd) and NP.native_style.UnitNameEquals(pd.plateName, sourceName) then
            local score, hasStrongHint = ScoreCastSourceCandidate(pd, sourceGUID, cfg)
            if score > bestScore then
                second, secondScore = best, bestScore
                best, bestScore = pd, score
                bestStrongHint = hasStrongHint
            elseif score > secondScore then
                second, secondScore = pd, score
            end
        end
    end

    if not best then
        return nil
    end

    local minScore = C.CAST_NAME_SCORE_MIN or 32
    if bestScore < minScore then
        return nil
    end
    local noHintMin = aggressive and minScore or (C.CAST_NAME_SCORE_NOHINT_MIN or 44)
    if not bestStrongHint and bestScore < noHintMin then
        return nil
    end

    if second and not aggressive then
        local minGap = C.CAST_NAME_SCORE_GAP or 8
        if (bestScore - secondScore) < minGap then
            return nil
        end
    end

    local confidence = aggressive
        and (C.CAST_AGGRESSIVE_MONITOR_MIN_CONFIDENCE or 50)
        or (C.CAST_MONITOR_MIN_CONFIDENCE or 60)
    if bestStrongHint then
        confidence = confidence + 8
    end
    return best, confidence, "NAME_SCORE"
end

local function TryNameMatch(sourceName, sourceFlags, sourceGUID, cfg)
    if not sourceName then
        return nil
    end
    local found
    local count = 0
    for _, pd in pairs(NP.module.plates) do
        if IsVisiblePlate(pd) and NP.native_style.UnitNameEquals(pd.plateName, sourceName) then
            count = count + 1
            found = pd
        end
    end
    if count >= 1 and IsAggressiveCastMonitor(cfg) and not IsOffTargetSafeOnly(cfg) then
        return FindBestScoredNameMatch(sourceName, sourceGUID, cfg)
    end
    if count == 1 and found then
        local isPlayer = IsPlayerUnitFlags(sourceFlags)
        local safeOnly = IsOffTargetSafeOnly(cfg)
        local playersOnly = IsPlayersOnlyMonitor(cfg)
        if isPlayer and (safeOnly or playersOnly) then
            local conf = C.CAST_PLAYER_NAME_CONFIDENCE or (C.CAST_MONITOR_MIN_CONFIDENCE or 60)
            return found, conf, "PLAYER_NAME_UNIQUE"
        end
    end
    return nil
end

local function FindPlateForCastSource(sourceGUID, sourceName, sourceFlags, cfg)
    local safeOnly = IsOffTargetSafeOnly(cfg)
    local isPlayer = IsPlayerUnitFlags(sourceFlags)

    -- Safe mode: player sources prefer name/GUID-map; NPC sources use GUID/raid/group.
    -- After a strong hover/token bind, GUID_MAP is also valid for players.
    if safeOnly and isPlayer then
        local plateData, confidence, route = TryGUIDMapMatch(sourceGUID, cfg)
        if plateData then
            return plateData, confidence, route
        end
        plateData, confidence, route = TryCastTaughtGUIDMatch(sourceGUID, cfg)
        if plateData then
            return plateData, confidence, route
        end
        return TryNameMatch(sourceName, sourceFlags, sourceGUID, cfg)
    end
    if safeOnly and not isPlayer then
        local plateData, confidence, route = TryGUIDMapMatch(sourceGUID, cfg)
        if plateData then
            return plateData, confidence, route
        end
        plateData, confidence, route = TryCastTaughtGUIDMatch(sourceGUID, cfg)
        if plateData then
            return plateData, confidence, route
        end
        plateData, confidence, route = TryGroupTargetMatch(sourceGUID)
        if plateData then
            return plateData, confidence, route
        end
        return TryRaidIconMatch(sourceFlags)
    end

    -- Full monitor path (aggressive / players-only without safe split).
    local plateData, confidence, route = TryCastMonitorStickyMatch(sourceGUID, sourceName, cfg)
    if plateData then
        return plateData, confidence, route
    end
    plateData, confidence, route = TryGUIDMapMatch(sourceGUID, cfg)
    if plateData then
        return plateData, confidence, route
    end
    plateData, confidence, route = TryGroupTargetMatch(sourceGUID)
    if plateData then
        return plateData, confidence, route
    end
    plateData, confidence, route = TryRaidIconMatch(sourceFlags)
    if plateData then
        return plateData, confidence, route
    end
    return TryNameMatch(sourceName, sourceFlags, sourceGUID, cfg)
end

local function FinalizeCastPlateResult(plateData, confidence, route, sourceGUID, cfg)
    if not plateData or not sourceGUID or not IsAggressiveCastMonitor(cfg) then
        return plateData, confidence, route
    end
    if not PlateMayReceiveMonitorCast(plateData, sourceGUID) then
        return nil
    end
    local plateGuid = NP.state.GetPlateGUID(plateData)
    if plateGuid and plateGuid ~= sourceGUID then
        return nil
    end
    return plateData, confidence, route
end

local function WarmupCastSourceGUID(sourceGUID, sourceName, sourceFlags, event, cfg)
    if not sourceGUID then return end
    if event and not CLEU_WARMUP_EVENTS[event] then
        return
    end
    -- Hybrid: this GUID's player/NPC nature drives the effective mode below.
    CurrentCastSourceIsPlayer = IsPlayerUnitFlags(sourceFlags)
    if ShouldRequireHostileReaction(cfg) and not IsHostileCombatLogFlags(sourceFlags) then
        return
    end
    local now = GetTime and GetTime() or 0
    local cooldown = C.CAST_WARMUP_COOLDOWN or 1.0
    local nextAt = CLEU_GUID_WARMUP_AT[sourceGUID] or 0
    if now < nextAt then
        return
    end
    CLEU_GUID_WARMUP_AT[sourceGUID] = now + cooldown

    local plateData, confidence, route = FindPlateForCastSource(sourceGUID, sourceName, sourceFlags, cfg)
    plateData, confidence, route = FinalizeCastPlateResult(plateData, confidence, route, sourceGUID, cfg)
    if not plateData then return end
    if not NP.identity.FriendlyPlateMayUseGUID(plateData, sourceGUID) then
        return
    end
    local aggressive = IsAggressiveCastMonitor(cfg)
    if not aggressive then
        if route == "NAME_UNIQUE" or route == "NAME_SCORE" or route == "PLAYER_NAME_UNIQUE" then
            return
        end
    elseif route == "PLAYER_NAME_UNIQUE" then
        return
    end
    local shownAt = plateData._shownAt or 0
    local minAge = aggressive and (C.CAST_AGGRESSIVE_WARMUP_MIN_AGE or 0.1) or (C.CAST_WARMUP_MIN_AGE or 0.3)
    if shownAt > 0 and (now - shownAt) < minAge then
        return
    end
    local currentGUID = NP.state.GetPlateGUID(plateData)
    if currentGUID and currentGUID ~= sourceGUID then
        return
    end
    local source = "CLEU_WARMUP"
    if route == "RAID_ICON" then
        source = "RAID_ICON"
    elseif route == "GROUP_TARGET" then
        source = "GROUP_TARGET"
    elseif route == "NAME_SCORE" or route == "CAST_MONITOR_STICKY" then
        source = route
    end
    NP.state.SetPlateGUID(plateData, sourceGUID, {
        source = source,
        confidence = confidence or (C.GUID_CONFIDENCE.CLEU_WARMUP or 0),
    })
    if aggressive then
        CommitCastMonitorSticky(sourceGUID, plateData)
    end
end

local function PlateCastBarIsActive(bar)
    if not bar then return false end
    if bar._intHideAt or bar._successHoldUntil or bar._successHideAt then
        return false
    end
    if bar.castingEx or bar.channelingEx then return true end
    if bar.castEndTime and GetTime() < bar.castEndTime then return true end
    return bar.IsShown and bar:IsShown()
end

local function FindPlateForActiveCastByName(destName, endingSpellName)
    if not destName then
        return nil
    end
    local want = NP.native_style.StripRealm(destName)
    for _, pd in pairs(NP.module.plates) do
        local bar = pd.minaCast
        if pd.plateName == want and PlateCastBarIsActive(bar)
            and CastEndMatchesBar(bar, endingSpellName) then
            return pd
        end
    end
    return nil
end

local function FindPlateForActiveCast(guid, endingSpellName, destName)
    if guid then
        local plateData = CastMonitorGuidToPlate[guid]
        if plateData and IsVisiblePlate(plateData)
            and PlateCastBarIsActive(plateData.minaCast)
            and CastEndMatchesBar(plateData.minaCast, endingSpellName) then
            return plateData
        end
        plateData = NP.state.GUIDToPlate[guid]
        if plateData and PlateCastBarIsActive(plateData.minaCast)
            and CastEndMatchesBar(plateData.minaCast, endingSpellName) then
            return plateData
        end
        for _, pd in pairs(NP.module.plates) do
            local bar = pd.minaCast
            if PlateCastBarIsActive(bar) then
                local plateGUID = NP.state.GetPlateGUID(pd)
                if plateGUID == guid
                    or bar._monitorGUID == guid
                    or bar._castSourceGUID == guid then
                    if CastEndMatchesBar(bar, endingSpellName) then
                        return pd
                    end
                end
            end
        end
    end
    return FindPlateForActiveCastByName(destName, endingSpellName)
end

local function SyncMonitorCastFromNative(plateData, bar)
    if not plateData or not bar or not bar._fromCombatLog then
        return false
    end
    local cfg = NP.config.GetCfg()
    if not ShouldUseNativePatchSync(cfg) then
        return false
    end
    local src = plateData.castBar
    if not src or not NP.castbar.IsNativeCastVisible(plateData) then
        return false
    end
    local minVal, maxVal = src:GetMinMaxValues()
    local cur = src:GetValue()
    if not maxVal or maxVal <= (minVal or 0) or cur == nil then
        return false
    end
    bar:SetMinMaxValues(minVal, maxVal)
    bar:SetValue(cur)
    local range = maxVal - (minVal or 0)
    local progress
    if range > 0 then
        progress = (cur - minVal) / range
        progress = max(0, min(1, progress))
        if bar.UpdateTextureClipping then
            bar:UpdateTextureClipping(progress, bar.channelingEx)
        end
    end
    if progress and bar.minaSpark and (bar.castingEx or bar.channelingEx) then
        local castH = select(1, NP.config.GetCastBarMetrics())
        bar.minaSpark:SetSize(max(castH, 14), max(castH * 2, 14))
        local w = bar:GetWidth()
        if w and w > 0 then
            bar.minaSpark:ClearAllPoints()
            bar.minaSpark:SetPoint("CENTER", bar, "LEFT", progress * w, 0)
            bar.minaSpark:Show()
        else
            bar.minaSpark:Hide()
        end
    end
    return true
end

-- Recent interrupt cache (CLEU may follow cancel/stop)

local CAST_INTERRUPT_CACHE_TTL = 1.0
local CastInterrupts = {}
local CastInterruptsByName = {}

local function NormalizeCastGUID(guid)
    if not guid then return nil end
    return string.lower(tostring(guid))
end

local function NormalizeCastName(name)
    if not name or name == "" then return nil end
    return string.lower(tostring(name))
end

function NP.castbar.RecordRecentInterrupt(destGUID, destName)
    local now = GetTime()
    local guidKey = NormalizeCastGUID(destGUID)
    local stripped = destName and NP.native_style.StripRealm(destName) or destName
    local nameKey = NormalizeCastName(stripped)
    local info = {
        time = now,
        destGUID = destGUID,
        destName = stripped or destName,
    }
    if guidKey then
        CastInterrupts[guidKey] = info
    end
    if nameKey then
        CastInterruptsByName[nameKey] = info
    end
end

function NP.castbar.GetRecentInterrupt(guid, name)
    local now = GetTime()
    local guidKey = NormalizeCastGUID(guid)
    local info = guidKey and CastInterrupts[guidKey] or nil
    if not info then
        local stripped = name and NP.native_style.StripRealm(name) or name
        local nameKey = NormalizeCastName(stripped)
        info = nameKey and CastInterruptsByName[nameKey] or nil
    end
    if not info then
        return nil
    end
    if now - (info.time or 0) > CAST_INTERRUPT_CACHE_TTL then
        if guidKey then
            CastInterrupts[guidKey] = nil
        end
        if info.destName then
            CastInterruptsByName[NormalizeCastName(info.destName)] = nil
        end
        return nil
    end
    return info
end

local function ShouldTreatCastAsInterrupted(plateData, guid, name)
    if guid and NP.castbar.GetRecentInterrupt(guid, nil) then
        return true
    end
    if plateData then
        local ownerGUID = guid or GetPlateCastOwnerGUID(plateData)
        if ownerGUID and NP.castbar.GetRecentInterrupt(ownerGUID, nil) then
            return true
        end
        -- Name fallback only when the plate has no cast owner GUID (unsafe duplicate-name NPCs otherwise).
        if not ownerGUID then
            local plateName = name or plateData.plateName
            if plateName and NP.castbar.GetRecentInterrupt(nil, plateName) then
                return true
            end
        end
    elseif name and NP.castbar.GetRecentInterrupt(nil, name) then
        return true
    end
    return false
end

local function PlateMatchesInterruptTarget(plateGUID, plateName, guidKey, wantName)
    if guidKey then
        return plateGUID and NormalizeCastGUID(plateGUID) == guidKey
    end
    return wantName and plateName == wantName
end

local function MonitorStopCast(plateData, interrupted)
    local bar = plateData and plateData.minaCast
    if plateData then
        plateData._monitorBackup = nil
    end
    if not PlateCastBarIsActive(bar) then
        return
    end
    if not interrupted and ShouldTreatCastAsInterrupted(plateData) then
        interrupted = true
    end
    if interrupted then
        bar._recentStopAt = nil
        NP.castbar.ShowInterruptedState(bar, plateData, false)
    else
        -- Monitor casts stop immediately; unit-driven bars may survive destarget by design.
        bar._recentStopAt = GetTime()
        bar._monitorGUID = nil
        bar._monitorConfidence = nil
        bar._fromCombatLog = nil
        bar.castingEx = false
        bar.channelingEx = false
        bar.castStartTime = nil
        bar.castEndTime = nil
        bar.spellName = nil
        bar._notInterruptible = false
        bar._nativeCastShield = nil
        bar:SetScript("OnUpdate", nil)
        bar:SetValue(0)
        if plateData.minaCastSpark then
            plateData.minaCastSpark:Hide()
        end
        if bar.minaCastIcon then bar.minaCastIcon:Hide() end
        if bar.minaCastShield then bar.minaCastShield:Hide() end
        HideSuccessFlashVisual(bar)
        bar:Hide()
        NP.discovery.HideCastChrome(plateData)
    end
end

local function CorrectRecentInterruptedPlate(destGUID, destName)
    local wantName = destName and NP.native_style.StripRealm(destName) or nil
    local guidKey = NormalizeCastGUID(destGUID)
    local now = GetTime()

    for _, plateData in pairs(NP.module.plates) do
        local bar = plateData.minaCast
        if not bar or bar._intHideAt or bar._interrupted then
        elseif bar.IsShown and bar:IsShown() and (bar.castingEx or bar.channelingEx) then
            local plateGUID = GetPlateCastOwnerGUID(plateData, bar)
            if PlateMatchesInterruptTarget(plateGUID, plateData.plateName, guidKey, wantName) then
                MonitorStopCast(plateData, true)
            end
        elseif bar._recentStopAt and (now - bar._recentStopAt) <= CAST_INTERRUPT_CACHE_TTL then
            local plateGUID = GetPlateCastOwnerGUID(plateData, bar)
            if PlateMatchesInterruptTarget(plateGUID, plateData.plateName, guidKey, wantName) then
                bar._recentStopAt = nil
                NP.castbar.ShowInterruptedState(bar, plateData, false)
            end
        end
    end
end

function NP.castbar.StartMonitorCast(plateData, sourceGUID, spellName, spellIcon, isChannel, castTimeMS, monitorConfidence)
    local cfg = NP.config.GetCfg()
    if not IsOffTargetMonitorEnabled(cfg) then
        return false
    end
    if IsAggressiveCastMonitor(cfg) and sourceGUID then
        if not PlateMayReceiveMonitorCast(plateData, sourceGUID) then
            return false
        end
        local boundGuid = NP.state.GetPlateGUID(plateData)
        if boundGuid and boundGuid ~= sourceGUID then
            return false
        end
    end
    if PlateHasActivePartyCast(plateData) then
        return false
    end
    NP.layout.EnsureMinaStack(plateData)
    local bar = plateData and plateData.minaCast
    if not bar then
        return false
    end
    local resolvedUnit = NP.identity.ResolvePlateCastUnit(plateData)
    -- Nameplate tokens are hints only off-target; do not block CLEU monitor when
    -- UnitCastingInfo is empty on nameplateN (common on 3.3.5a without target).
    if IsReliableCastUnit(resolvedUnit) and UnitHasActiveCast(resolvedUnit) then
        return false
    end
    local incomingConfidence = tonumber(monitorConfidence) or 0
    -- Never override a reliable (unit-resolved) cast owner while it is still running.
    if bar.IsShown and bar:IsShown() and not bar._fromCombatLog then
        local transientState = bar._successHoldUntil or bar._successHideAt
            or bar._intHideAt or bar._interruptFadeActive
        local castStillRunning = bar.castEndTime and GetTime() < bar.castEndTime
            and (bar.castingEx or bar.channelingEx)
        if not transientState and castStillRunning
            and IsReliableCastUnit(resolvedUnit) and UnitHasActiveCast(resolvedUnit) then
            return false
        end
    end
    if bar._fromCombatLog and bar.castEndTime and GetTime() < bar.castEndTime
        and (tonumber(bar._monitorConfidence) or 0) > incomingConfidence then
        return false
    end

    local duration = tonumber(castTimeMS or 0) or 0
    if duration <= 0 then
        duration = 60000 -- fallback sentinel for unknown cast length
    end

    local now = GetTime()
    bar._interrupted = nil
    bar._interruptFadeActive = nil
    bar._intHideAt = nil
    bar._intFadeAt = nil
    bar._successHoldUntil = nil
    bar._successHideAt = nil
    bar._successFadeDuration = nil
    bar._successFading = nil
    if bar._intBg then bar._intBg:Hide() end
    HideSuccessFlashVisual(bar)
    bar._monitorGUID = sourceGUID
    bar._castSourceGUID = sourceGUID
    bar._monitorConfidence = incomingConfidence
    bar._fromCombatLog = true
    bar._notInterruptible = false
    bar._nativeCastShield = nil
    bar.spellName = spellName
    bar.castStartTime = now
    bar.castEndTime = now + duration / 1000

    NP.castbar.SuppressNativeCastVisual(plateData)
    NP.castbar.ApplyPlateCastTextures(bar, isChannel and true or false, plateData)
    NP.layout.LayoutCastBarStack(plateData)
    NP.castbar.SyncTargetCastIcon(bar, plateData, spellIcon)
    bar:SetMinMaxValues(0, 1)
    if isChannel then
        bar:SetValue(1)
        if bar.UpdateTextureClipping then
            bar:UpdateTextureClipping(1.0, true)
        end
    else
        bar:SetValue(0)
        if bar.UpdateTextureClipping then
            bar:UpdateTextureClipping(0, false)
        end
    end
    bar:Show()
    NP.castbar.SyncPlateCastProgress(bar)
    NP.castbar.RegisterCastTick(plateData)
    return true
end

local function ParseCombatLogSpellEvent(arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    local destGUID, destName, destFlags, spellId, combatSpellName
    -- Variants seen in 3.3.5 packs:
    --  A) srcFlags, destGUID, destName, destFlags, spellId, spellName
    --  B) srcFlags, srcRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName
    if type(arg1) == "number" and type(arg2) == "string" and type(arg4) == "number" then
        destGUID = arg2
        destName = arg3
        destFlags = arg4
        spellId = arg6
        combatSpellName = arg7
    else
        destGUID = arg1
        destName = arg2
        destFlags = arg3
        spellId = arg4
        combatSpellName = arg5
    end
    return destGUID, destName, destFlags, spellId, combatSpellName
end

-- CC/interrupt handler for unit-driven bars; gate before parsing suffix args.
local CAST_BREAK_EVENTS = {
    SPELL_INTERRUPT = true,
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
}
-- Exported for engine CLEU subevent gating.
NP.castbar.CAST_BREAK_EVENTS = CAST_BREAK_EVENTS

function NP.castbar.HandleCombatLogCastBreak(timestamp, event, sourceGUID, sourceName, sourceFlags, ...)
    if not CAST_BREAK_EVENTS[event] then
        return
    end
    local destGUID, destName, destFlags, spellId, combatSpellName = ParseCombatLogSpellEvent(...)
    local cfg = NP.config.GetCfg()

    if event == "SPELL_INTERRUPT" then
        NP.castbar.RecordRecentInterrupt(destGUID, destName)
        CorrectRecentInterruptedPlate(destGUID, destName)
        local plateData = FindPlateForActiveCast(destGUID, nil, destName)
        if plateData then
            MonitorStopCast(plateData, true)
        end
        return
    end

    if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        spellId = tonumber(spellId)
        local auraBreak = destGUID and AuraBreaksActiveCast(spellId, combatSpellName)
        if auraBreak then
            if not ShouldRequireHostileReaction(cfg)
                or not destFlags or IsHostileCombatLogFlags(destFlags) then
                local plateData = FindPlateForActiveCast(destGUID, nil, destName)
                if plateData then
                    MonitorStopCast(plateData, true)
                end
            end
        end
    end
end

-- Monitor cast events; gate other traffic unless also a warmup event.
local CAST_MONITOR_CLEU_EVENTS = {
    SPELL_CAST_START = true,
    SPELL_CHANNEL_START = true,
    SPELL_CAST_SUCCESS = true,
    SPELL_CAST_FAILED = true,
    SPELL_CAST_FAILED_QUIET = true,
    SPELL_CAST_INTERRUPTED = true,
    SPELL_CHANNEL_STOP = true,
}
-- Exported for engine CLEU subevent gating.
NP.castbar.CAST_MONITOR_CLEU_EVENTS = CAST_MONITOR_CLEU_EVENTS

function NP.castbar.CastMonitorOnCombatLog(timestamp, event, sourceGUID, sourceName, sourceFlags, ...)
    if not CAST_MONITOR_CLEU_EVENTS[event] and not CLEU_WARMUP_EVENTS[event] then
        return
    end
    local cfg = NP.config.GetCfg()
    if not IsOffTargetMonitorEnabled(cfg) then return end
    if not sourceGUID then return end
    local destGUID, destName, destFlags, spellId, combatSpellName = ParseCombatLogSpellEvent(...)
    if event == "SPELL_CAST_START" or event == "SPELL_CHANNEL_START" then
        -- Hybrid: route this source's casts through aggressive (player) or safe (NPC).
        CurrentCastSourceIsPlayer = IsPlayerUnitFlags(sourceFlags)
        -- Safe mode cannot observe early player cancellations without a stop event.
        if CurrentCastSourceIsPlayer and IsOffTargetSafeOnly(cfg) then return end
        if ShouldRequireHostileReaction(cfg) and not IsHostileCombatLogFlags(sourceFlags) then
            return
        end
        if sourceGUID == UnitGUID("player") then return end
        if NP.config.HidePetCasts(cfg) and IsPetOrGuardianFlags(sourceFlags) then return end
        if IsPlayersOnlyMonitor(cfg) and not IsPlayerUnitFlags(sourceFlags) then return end

        spellId = tonumber(spellId)
        if not spellId then return end
        local spellName, _, spellIcon, _, _, _, castTimeMS = GetSpellInfo(spellId)
        spellName = spellName or combatSpellName
        if not spellName then return end
        if event == "SPELL_CAST_START" and (tonumber(castTimeMS) or 0) <= 0 then
            return
        end

        local plateData, sourceConfidence, route = FindPlateForCastSource(sourceGUID, sourceName, sourceFlags, cfg)
        plateData, sourceConfidence, route = FinalizeCastPlateResult(
            plateData, sourceConfidence, route, sourceGUID, cfg)
        if not plateData then return end
        if PlateHasActivePartyCast(plateData) then return end
        local minConfidence = C.CAST_MONITOR_MIN_CONFIDENCE or 60
        if IsAggressiveCastMonitor(cfg) then
            minConfidence = C.CAST_AGGRESSIVE_MONITOR_MIN_CONFIDENCE or 50
        end
        if (tonumber(sourceConfidence) or 0) < minConfidence then
            return
        end

        if IsAggressiveCastMonitor(cfg) then
            CommitCastMonitorSticky(sourceGUID, plateData)
        end

        -- Record this cast even while the source is our current target/focus/
        -- mouseover: StartMonitorCast itself refuses to take over visuals while
        -- the authoritative UnitCastingInfo path is active, but we still want
        -- a backup for transitions away from target/focus/mouseover during the
        -- cast, allowing SyncCastBar to retain the active cast.
        do
            local castStart = GetTime()
            local durationMS = tonumber(castTimeMS) or 0
            plateData._monitorBackup = {
                guid = sourceGUID,
                spellName = spellName,
                spellIcon = spellIcon,
                channeling = event == "SPELL_CHANNEL_START",
                castStartTime = castStart,
                castEndTime = castStart + durationMS / 1000,
                confidence = sourceConfidence,
            }
        end

        NP.castbar.StartMonitorCast(
            plateData,
            sourceGUID,
            spellName,
            spellIcon,
            event == "SPELL_CHANNEL_START",
            castTimeMS,
            sourceConfidence
        )
        if NP.engine and NP.engine.QueuePlate and NP.engine.Callbacks then
            NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
        end
        return
    end

    if event == "SPELL_CAST_SUCCESS" or event == "SPELL_CAST_FAILED"
        or event == "SPELL_CAST_FAILED_QUIET"
        or event == "SPELL_CAST_INTERRUPTED" or event == "SPELL_CHANNEL_STOP" then
        local endingSpellName = combatSpellName
        if spellId then
            local resolvedName = GetSpellInfo(spellId)
            endingSpellName = resolvedName or endingSpellName
        end
        local plateData = FindPlateForActiveCast(sourceGUID, endingSpellName)
        if plateData then
            local interrupted = (event == "SPELL_CAST_FAILED"
                or event == "SPELL_CAST_FAILED_QUIET"
                or event == "SPELL_CAST_INTERRUPTED")
            if not interrupted and ShouldTreatCastAsInterrupted(plateData, sourceGUID, sourceName) then
                interrupted = true
            end
            MonitorStopCast(plateData, interrupted)
        end
        return
    end

    -- Opportunistically warm GUID->plate ownership from non-cast CLEU events
    -- so SPELL_CAST_START can resolve off-target mobs without prior hover/target.
    local playerGUID = UnitGUID("player")
    if sourceGUID and sourceGUID ~= playerGUID then
        WarmupCastSourceGUID(sourceGUID, sourceName, sourceFlags, event, cfg)
    end
    if destGUID and destGUID ~= playerGUID then
        WarmupCastSourceGUID(destGUID, destName, destFlags, event, cfg)
    end
end

function NP.castbar.OnPlateGUIDBound(plateData, guid)
    if not plateData or not guid then
        return
    end
    ClearCastMonitorStickyForPlate(plateData)
    local stickyPlate = CastMonitorGuidToPlate[guid]
    if stickyPlate and stickyPlate ~= plateData then
        ClearCastMonitorStickyForGUID(guid)
    end
    local bar = plateData.minaCast
    if bar and bar._fromCombatLog and bar._monitorGUID and bar._monitorGUID ~= guid then
        MonitorStopCast(plateData, false)
    end
end

function NP.castbar.OnPlateHidden(plateData)
    ClearCastMonitorStickyForPlate(plateData)
    if plateData then
        plateData._monitorBackup = nil
    end
    local bar = plateData and plateData.minaCast
    if bar and bar._fromCombatLog then
        MonitorStopCast(plateData, false)
        bar._recentStopAt = nil
        bar._castSourceGUID = nil
    end
end

-- Prune monitor state for hidden plates only.
function NP.castbar.PruneCastMonitorStaleState()
    for guid, plateData in pairs(CastMonitorGuidToPlate) do
        if not plateData or not IsVisiblePlate(plateData) then
            ClearCastMonitorStickyForGUID(guid)
        end
    end
    for plateData in pairs(CastMonitorPlateToGuid) do
        if not IsVisiblePlate(plateData) then
            ClearCastMonitorStickyForPlate(plateData)
        end
    end
    for guid in pairs(CLEU_GUID_WARMUP_AT) do
        CLEU_GUID_WARMUP_AT[guid] = nil
    end
end

function NP.castbar.ResetAllMonitorCasts()
    ResetCastMonitorStickyMaps()
    for guid in pairs(CLEU_GUID_WARMUP_AT) do
        CLEU_GUID_WARMUP_AT[guid] = nil
    end
    for _, plateData in pairs(NP.module.plates) do
        local bar = plateData and plateData.minaCast
        if plateData then
            plateData._monitorBackup = nil
        end
        if bar and bar._fromCombatLog then
            MonitorStopCast(plateData, false)
            -- Config/mode reset is not a cast cancel; do not arm interrupt race tracking.
            bar._recentStopAt = nil
            bar._castSourceGUID = nil
        elseif bar then
            bar._monitorGUID = nil
            bar._monitorConfidence = nil
            bar._fromCombatLog = nil
        end
    end
end

function NP.castbar.Shutdown()
    NP.castbar.ResetAllMonitorCasts()
    for plateData in pairs(activeTickPlates) do
        activeTickPlates[plateData] = nil
    end
    for key in pairs(CastInterrupts) do
        CastInterrupts[key] = nil
    end
    for key in pairs(CastInterruptsByName) do
        CastInterruptsByName[key] = nil
    end
    if PartyRaidCastTracker and PartyRaidCastTracker.Cleanup then
        PartyRaidCastTracker:Cleanup()
    end
end

function NP.castbar.SyncOffTargetMonitorFromConfig(cfg)
    cfg = cfg or NP.config.GetCfg()
    local signature
    if cfg.showCastBar == false then
        signature = "master:off"
    else
        local mode = NP.config.GetOffTargetCastMode(cfg)
        local hostileOnly = (cfg.castBarOffTargetHostileOnly == true) and 1 or 0
        local playersOnly = IsPlayersOnlyMonitor(cfg) and 1 or 0
        local hidePets = NP.config.HidePetCasts(cfg) and 1 or 0
        signature = string.format("%s:%d:%d:%d", mode, hostileOnly, playersOnly, hidePets)
    end

    local monitorEnabled = (signature ~= "master:off")
        and NP.config.IsOffTargetCastMonitorActive(cfg)

    local prevSignature = NP.module._castMonitorSignature
    if prevSignature ~= nil and prevSignature ~= signature then
        NP.castbar.ResetAllMonitorCasts()
    elseif NP.module._castMonitorEnabled and not monitorEnabled then
        NP.castbar.ResetAllMonitorCasts()
    end

    NP.module._castMonitorSignature = signature
    NP.module._castMonitorEnabled = monitorEnabled
    return monitorEnabled
end

-- Cast info and interrupt handling

function NP.castbar.GetPlateCastInfo(plateData)
    local unit = NP.identity.ResolvePlateCastUnit(plateData)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local name, _, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
    startMS = tonumber(startMS)
    endMS = tonumber(endMS)
    if name and startMS and endMS then
        local isNotInt = IsCastNotInterruptibleFlag(notInterruptible) or IsUnitProtectedFromInterrupt(unit)
        return name, startMS, endMS, false, isNotInt, texture, unit
    end
    name, _, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
    startMS = tonumber(startMS)
    endMS = tonumber(endMS)
    if name and startMS and endMS then
        local isNotInt = IsCastNotInterruptibleFlag(notInterruptible) or IsUnitProtectedFromInterrupt(unit)
        return name, startMS, endMS, true, isNotInt, texture, unit
    end
    return nil
end

function NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, isPartyBar)
    if not bar then return end
    local isNotInt = bar._notInterruptible and true or false
    local sbTex = bar:GetStatusBarTexture()
    if sbTex and sbTex.SetDesaturated then
        sbTex:SetDesaturated(isNotInt)
    end
    local iconRef = isPartyBar and bar.minaIcon or bar.minaCastIcon
    local shieldKey = isPartyBar and "minaShield" or "minaCastShield"
    if iconRef and iconRef.IsShown and iconRef:IsShown() then
        local iconSize = NP.castbar.LayoutCastSpellIcon(iconRef, bar, isNotInt)
        if isNotInt then
            local shield = NP.castbar.EnsureCastIconShieldFrame(bar, shieldKey, bar)
            NP.castbar.LayoutCastIconShield(shield, iconRef, iconSize, bar)
            shield:Show()
        elseif bar[shieldKey] then
            bar[shieldKey]:Hide()
        end
    elseif isNotInt and iconRef then
        iconRef:Show()
        local iconSize = NP.castbar.LayoutCastSpellIcon(iconRef, bar, true)
        local shield = NP.castbar.EnsureCastIconShieldFrame(bar, shieldKey, bar)
        NP.castbar.LayoutCastIconShield(shield, iconRef, iconSize, bar)
        shield:Show()
    elseif bar[shieldKey] then
        bar[shieldKey]:Hide()
    end
end

function NP.castbar.PlateCastStoppedEarly(bar, unit, event)
    if not bar or not (bar.castingEx or bar.channelingEx) then
        return false
    end
    if ShouldIgnoreUnitCastStop(bar, unit, nil) then
        return false
    end
    if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        return false
    end
    if unit and (UnitCastingInfo(unit) or UnitChannelInfo(unit)) then
        return false
    end
    local now = GetTime()
    if bar.castEndTime and now >= bar.castEndTime - 0.15 then
        return false
    end
    if bar.castEndTime and now < bar.castEndTime - 0.35 then
        return true
    end
    local minVal, maxVal = bar:GetMinMaxValues()
    local cur = bar:GetValue()
    if maxVal and maxVal > (minVal or 0) and cur ~= nil then
        local progress = (cur - minVal) / (maxVal - minVal)
        if progress < 0.90 then
            return true
        end
    end
    if bar.castEndTime and now < bar.castEndTime then
        return true
    end
    return false
end

function NP.castbar.ShouldPlateCastShowInterrupt(bar, unit, event, eventSpell, isChannelStop)
    if not bar then return false end
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        return bar.castingEx or bar.channelingEx
    end
    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        if not (bar.castingEx or bar.channelingEx) then return false end
        if bar.channelingEx and unit then
            local activeChannelSpell = UnitChannelInfo(unit)
            if activeChannelSpell and bar.spellName and activeChannelSpell == bar.spellName then
                return false
            end
        end
        if eventSpell and bar.spellName and eventSpell ~= bar.spellName then
            return false
        end
        return true
    end
    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        return NP.castbar.PlateCastStoppedEarly(bar, unit, event)
    end
    return false
end

function NP.castbar.EnsureCastInterruptOverlay(bar)
    if not bar then return end
    if not bar._intBg and bar.CreateTexture then
        bar._intBg = bar:CreateTexture(nil, "BACKGROUND")
        bar._intBg:SetAllPoints(bar)
        bar._intBg:SetTexture(C.MINA_TEX .. "bar-bar")
        if bar._intBg.SetDrawLayer then
            bar._intBg:SetDrawLayer("ARTWORK", 2)
        end
        bar._intBg:Hide()
    end
end

function NP.castbar.MarkPlateCastEnd(bar, unit, event, eventSpell)
    if not bar then return end
    if ShouldIgnoreUnitCastStop(bar, unit, eventSpell) then
        return false
    end
    local isChannelStop = event == "UNIT_SPELLCAST_CHANNEL_STOP"
    if NP.castbar.ShouldPlateCastShowInterrupt(bar, unit, event, eventSpell, isChannelStop) then
        bar._interrupted = true
        NP.castbar.EnsureCastInterruptOverlay(bar)
        return true
    end
    return false
end

function NP.castbar.HideNativeCastVisual(plateData)
    local src = plateData.castBar
    if not src then return end
    if src.SetAlpha then src:SetAlpha(0) end
    if plateData.castBarBorder and plateData.castBarBorder.Hide then
        plateData.castBarBorder:Hide()
    end
    if plateData.castBarShield and plateData.castBarShield.Hide then
        plateData.castBarShield:Hide()
    end
    if plateData.castBarIcon and plateData.castBarIcon.Hide then
        plateData.castBarIcon:Hide()
        if plateData.castBarIcon.SetAlpha then
            plateData.castBarIcon:SetAlpha(0)
        end
    end
    -- Hide any extra native cast textures (recycled plates can re-show them).
    if src.GetNumRegions and src.GetRegions then
        local statusTex = src.GetStatusBarTexture and src:GetStatusBarTexture() or nil
        for i = 1, src:GetNumRegions() do
            local region = select(i, src:GetRegions())
            if region and region ~= statusTex
                and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetAlpha then
                    region:SetAlpha(0)
                end
                if region.Hide then
                    region:Hide()
                end
            end
        end
    end
end

function NP.castbar.SuppressNativeCastVisual(plateData)
    if not plateData or plateData._nativeCastSuppressed then
        return
    end
    NP.castbar.HideNativeCastVisual(plateData)
    plateData._nativeCastSuppressed = true
end

function NP.castbar.HidePlateCastBar(plateData, force)
    local bar = plateData.minaCast
    if not bar then
        NP.discovery.HideCastChrome(plateData)
        return
    end
    if not force and ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
        NP.castbar.ShowInterruptedState(bar, plateData, false)
        return
    end
    if not force and (bar._successHoldUntil or bar._successHideAt) then
        return
    end
    -- Destarget drops unit/native cast sources while the timed bar is still valid.
    local castStillRunning = bar.castEndTime and GetTime() < bar.castEndTime
        and (bar.castingEx or bar.channelingEx)
    if not force and castStillRunning
        and not ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
        return
    end
    local wasInterrupted = bar._interrupted
    local hadActiveCast = (bar.castingEx or bar.channelingEx or bar.castStartTime or bar.castEndTime) and true or false
    local endedEarly = NP.castbar.CastBarEndedEarly(bar)
    local canSuccessFade = not force
        and not wasInterrupted
        and not endedEarly
        and hadActiveCast
        and bar.IsShown
        and bar:IsShown()
    local ownerGUID = GetPlateCastOwnerGUID(plateData, bar)

    bar._monitorGUID = nil
    bar._monitorConfidence = nil
    bar._fromCombatLog = nil
    bar.castingEx = false
    bar.channelingEx = false
    bar.castStartTime = nil
    bar.castEndTime = nil
    bar.spellName = nil
    bar:SetScript("OnUpdate", nil)
    if plateData.minaCastSpark then
        plateData.minaCastSpark:Hide()
    end
    NP.discovery.HideCastChrome(plateData)

    if canSuccessFade then
        bar._castSourceGUID = nil
        -- Reset so the next cast doesn't inherit this one's shield/interrupt state.
        bar._notInterruptible = false
        bar._nativeCastShield = nil
        bar._recentStopAt = nil
        StartSuccessFade(bar)
        NP.castbar.RegisterCastTick(plateData)
        return
    end

    bar._notInterruptible = false
    bar._nativeCastShield = nil
    plateData._nativeCastSuppressed = nil
    bar:SetValue(0)
    HideSuccessFlashVisual(bar)
    if bar.minaCastIcon then bar.minaCastIcon:Hide() end
    if bar.minaCastShield then bar.minaCastShield:Hide() end
    if bar.minaCastSpellName then bar.minaCastSpellName:Hide() end
    if wasInterrupted and bar._intBg then
        bar._castSourceGUID = nil
        NP.castbar.ShowInterruptedState(bar, plateData, false)
    elseif ShouldTreatCastAsInterrupted(plateData, ownerGUID) then
        bar._recentStopAt = nil
        bar._castSourceGUID = nil
        NP.castbar.ShowInterruptedState(bar, plateData, false)
    else
        -- Only track recent cancel for early-end paths; natural completion must not
        -- inherit a later unrelated kick on the same name.
        bar._recentStopAt = endedEarly and GetTime() or nil
        if not bar._recentStopAt then
            bar._castSourceGUID = nil
        end
        bar:Hide()
    end
    RefreshCastTickRegistration(plateData)
end

function NP.castbar.ResetPlateCastIfIdentityChanged(plateData, freshName)
    if not plateData or not freshName then return end
    if plateData._castIdentityName and plateData._castIdentityName ~= freshName then
        NP.castbar.ResetPlateCastBar(plateData)
        PartyRaidCastTracker:HideBar(plateData)
    end
    plateData._castIdentityName = freshName
end

-- Cast progress

function NP.castbar.GetPlateCastClipProgress(bar, now)
    if bar.castStartTime and bar.castEndTime then
        local duration = bar.castEndTime - bar.castStartTime
        if duration > 0 then
            now = now or GetTime()
            if bar.channelingEx then
                return (bar.castEndTime - now) / duration
            end
            if bar.castingEx then
                return (min(now, bar.castEndTime) - bar.castStartTime) / duration
            end
        end
    end
    local minVal, maxVal = bar:GetMinMaxValues()
    local cur = bar:GetValue()
    local range = maxVal - minVal
    if not range or range <= 0 then return nil end
    return (cur - minVal) / range
end

-- Size and anchor the cast spark to the current progress (no-op without a spark).
local function PositionCastSpark(bar, progress)
    local spark = bar.minaSpark
    if not spark then return end
    local castH = bar._cachedCastH
    if not castH then
        castH = select(1, NP.config.GetCastBarMetrics())
        bar._cachedCastH = castH
    end
    spark:SetSize(max(castH, 14), max(castH * 2, 14))
    local w = bar:GetWidth()
    if w and w > 0 then
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", bar, "LEFT", progress * w, 0)
        spark:Show()
    else
        spark:Hide()
    end
end

function NP.castbar.SyncPlateCastProgress(bar, now)
    local progress = NP.castbar.GetPlateCastClipProgress(bar, now)
    if not progress then return end
    progress = max(0, min(1, progress))
    if bar.castStartTime and bar.castEndTime then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(progress)
    end
    if bar.UpdateTextureClipping then
        bar:UpdateTextureClipping(progress, bar.channelingEx)
    end
    if bar.castingEx or bar.channelingEx then
        PositionCastSpark(bar, progress)
    end
end

function NP.castbar.SyncPartyCastProgress(bar, now)
    local progress = NP.castbar.GetPlateCastClipProgress(bar, now)
    if not progress then return end
    progress = max(0, min(1, progress))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(progress)
    if bar.UpdateTextureClipping then
        bar:UpdateTextureClipping(progress, bar.channelingEx)
    end
    if bar.castingEx or bar.channelingEx then
        PositionCastSpark(bar, progress)
    elseif bar.minaSpark then
        bar.minaSpark:Hide()
    end
end

local function TickPlateCastBars(plateData, now)
    local partyCastActive = PartyRaidCastTracker.activeCasts[plateData] ~= nil
    local bar = plateData.minaCast
    if not partyCastActive and bar and bar.IsShown and bar:IsShown()
        and (bar.castingEx or bar.channelingEx) then
        if ShouldInterruptAuthoritativeEarlyEnd(plateData, bar, now) then
            MonitorStopCast(plateData, true)
        elseif bar._fromCombatLog then
            local endT = bar.castEndTime
            if endT and now >= endT then
                NP.castbar.HidePlateCastBar(plateData)
            elseif endT then
                if NP.castbar.IsNativeCastVisible(plateData) then
                    plateData._nativeCastSuppressed = nil
                end
                NP.castbar.SuppressNativeCastVisual(plateData)
                if not SyncMonitorCastFromNative(plateData, bar) then
                    NP.castbar.SyncPlateCastProgress(bar, now)
                end
            end
        else
            local endT = bar.castEndTime
            local shouldHide = (not endT) or (now >= endT)
            shouldHide = shouldHide and not NP.castbar.PlateStillCasting(plateData)
            if shouldHide then
                NP.castbar.HidePlateCastBar(plateData)
            elseif endT then
                if NP.castbar.IsNativeCastVisible(plateData) then
                    plateData._nativeCastSuppressed = nil
                end
                NP.castbar.SuppressNativeCastVisual(plateData)
                if not SyncMonitorCastFromNative(plateData, bar) then
                    NP.castbar.SyncPlateCastProgress(bar, now)
                end
            end
        end
    elseif bar and bar.IsShown and bar:IsShown()
        and not bar._intHideAt
        and not bar._successHoldUntil
        and not bar._successHideAt
        and not bar.castStartTime and not bar.castEndTime
        and not NP.castbar.PlateStillCasting(plateData) then
        NP.castbar.HidePlateCastBar(plateData)
    elseif bar and bar._intHideAt then
        if now >= bar._intHideAt then
            bar._intHideAt = nil
            bar._intFadeAt = nil
            bar._interrupted = nil
            bar._interruptFadeActive = nil
            bar._applyingInterruptVisual = nil
            if bar._intBg then
                bar._intBg:Hide()
            end
            HideSuccessFlashVisual(bar)
            bar:Hide()
            bar:SetAlpha(1)
        end
    elseif bar and bar._successHoldUntil then
        if now >= bar._successHoldUntil then
            bar._successHoldUntil = nil
            local fadeDuration = bar._successFadeDuration or 0.5
            bar._successFading = true
            bar._interruptFadeActive = true
            HideSuccessFlashVisual(bar)
            if UIFrameFadeRemoveFrame then
                UIFrameFadeRemoveFrame(bar)
            end
            if UIFrameFadeOut then
                UIFrameFadeOut(bar, fadeDuration, bar:GetAlpha() or 1.0, 0.0)
            end
            bar._successHideAt = now + fadeDuration
        end
    elseif bar and bar._successHideAt then
        if now >= bar._successHideAt then
            bar._successHideAt = nil
            bar._successFadeDuration = nil
            bar._successFading = nil
            bar._interruptFadeActive = nil
            bar:SetValue(0)
            if bar.minaCastIcon then bar.minaCastIcon:Hide() end
            if bar.minaCastShield then bar.minaCastShield:Hide() end
            HideSuccessFlashVisual(bar)
            bar:Hide()
            bar:SetAlpha(1)
            plateData._nativeCastSuppressed = nil
        end
    end

    local partyBar = plateData.minaPartyCast
    local partyInfo = PartyRaidCastTracker.activeCasts[plateData]
    if partyBar and partyBar.IsShown and partyBar:IsShown()
        and (partyBar.castingEx or partyBar.channelingEx) then
        local partyUnit = partyInfo and partyInfo.unit
        if partyUnit and ShouldInterruptPartyEarlyEnd(partyUnit, partyBar) then
            NP.castbar.ShowInterruptedState(partyBar, plateData, true)
            PartyRaidCastTracker.activeCasts[plateData] = nil
        elseif partyBar.castStartTime and partyBar.castEndTime then
            if now >= partyBar.castEndTime then
                PartyRaidCastTracker:HideBar(plateData)
            else
                NP.castbar.SyncPartyCastProgress(partyBar, now)
            end
        end
    elseif partyBar and partyBar._intHideAt then
        if now >= partyBar._intHideAt then
            partyBar._intHideAt = nil
            partyBar._intFadeAt = nil
            partyBar._interrupted = nil
            partyBar._interruptFadeActive = nil
            partyBar._applyingInterruptVisual = nil
            partyBar._intBg:Hide()
            partyBar:Hide()
            partyBar:SetAlpha(1)
            PartyRaidCastTracker.activeCasts[plateData] = nil
        end
    end

    RefreshCastTickRegistration(plateData)
end

function NP.castbar.TickAllPlateCastBars()
    local now = GetTime()
    for plateData in pairs(activeTickPlates) do
        local plate = plateData and plateData.plate
        if not plate or not plate.IsShown or not plate:IsShown() then
            activeTickPlates[plateData] = nil
        else
            TickPlateCastBars(plateData, now)
        end
    end
end

-- Cast sync helpers

function NP.castbar.ResolvePlateChanneling(plateData, channelingHint)
    if channelingHint ~= nil then return channelingHint end
    if NP.identity.IsTargetPlate(plateData) and UnitExists("target") then
        if UnitChannelInfo("target") then return true end
        if UnitCastingInfo("target") then return false end
    end
    local src = plateData.castBar
    if src and src.GetStatusBarTexture then
        local tex = src:GetStatusBarTexture()
        if tex and tex.GetTexture then
            local path = tex:GetTexture()
            if type(path) == "string" and path:find("[Cc]hannel") then
                return true
            end
        end
    end
    return false
end

function NP.castbar.ApplyPlateCastTextures(bar, channeling, plateData)
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(bar)
    end
    bar._interrupted = nil
    bar._interruptFadeActive = nil
    bar._intHideAt = nil
    bar._intFadeAt = nil
    bar._successHoldUntil = nil
    bar._successHideAt = nil
    bar._successFadeDuration = nil
    bar._successFading = nil
    bar._recentStopAt = nil
    if bar._intBg then bar._intBg:Hide() end
    HideSuccessFlashVisual(bar)
    if bar.SetAlpha then
        bar:SetAlpha(1)
    end

    local wasChanneling = bar.channelingEx
    if channeling then
        if not wasChanneling and bar.InvalidateTextureCache then
            bar:InvalidateTextureCache()
        end
        bar._cachedCastH = nil
        bar:SetStatusBarTexture(C.CAST_TEX_CHANNEL)
        bar:SetStatusBarColor(C.CAST_COLOR_CHANNEL[1], C.CAST_COLOR_CHANNEL[2], C.CAST_COLOR_CHANNEL[3], 1)
        bar.channelingEx = true
        bar.castingEx = false
    else
        if wasChanneling and bar.InvalidateTextureCache then
            bar:InvalidateTextureCache()
        end
        bar._cachedCastH = nil
        bar:SetStatusBarTexture(C.CAST_TEX_STANDARD)
        bar:SetStatusBarColor(C.CAST_COLOR_STANDARD[1], C.CAST_COLOR_STANDARD[2], C.CAST_COLOR_STANDARD[3], 1)
        bar.castingEx = true
        bar.channelingEx = false
    end
    PrepareCastFillTexture(bar:GetStatusBarTexture())
    ForceCastBarTextureLayer(bar)
    if plateData then
        NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, false)
    end
end

function NP.castbar.PlateStillCasting(plateData)
    local bar = plateData.minaCast
    local authUnit = GetAuthoritativeCastUnit(plateData)
    if authUnit then
        -- Unit API is authoritative for target/focus/mouseover plates.
        return UnitHasActiveCast(authUnit) and true or false
    end
    -- Timed cast still within its window (survives destarget; keep
    -- the animation until it finishes or combat-log says otherwise).
    if bar and bar.castEndTime and GetTime() < bar.castEndTime
        and (bar.castingEx or bar.channelingEx) then
        return true
    end
    if bar and bar._monitorGUID and bar.castEndTime and GetTime() < bar.castEndTime then
        return true
    end
    if NP.castbar.IsNativeCastVisible(plateData) then return true end
    return NP.castbar.GetPlateCastInfo(plateData) ~= nil
end

function NP.castbar.IsNativeCastVisible(plateData)
    local src = plateData.castBar
    if not src or not src.IsShown or not src:IsShown() then
        return false
    end
    -- Do not gate on alpha here: DragonUI intentionally drives native castbar
    -- alpha to 0 while keeping it alive as a timing/data source.
    if src.GetMinMaxValues then
        local minVal, maxVal = src:GetMinMaxValues()
        if not maxVal or maxVal <= (minVal or 0) then
            return false
        end
    end
    return true
end

function NP.castbar.ShouldSkipCastSync(plateData)
    local castBar = plateData.minaCast
    if not castBar or not castBar.castStartTime or not castBar.castEndTime then
        return false
    end
    if not castBar.IsShown or not castBar:IsShown()
        or (not castBar.castingEx and not castBar.channelingEx) then
        return false
    end
    -- Monitor casts have no unit source; skip sync while they run.
    if castBar._monitorGUID then
        local confidence = tonumber(castBar._monitorConfidence) or 0
        if confidence < (C.CAST_MONITOR_ACTIVE_MIN_CONFIDENCE or 0) then
            return false
        end
        return GetTime() < castBar.castEndTime
    end
    if not NP.castbar.PlateStillCasting(plateData) then return false end
    local _, startMS = NP.castbar.GetPlateCastInfo(plateData)
    if startMS then
        if abs(castBar.castStartTime - (startMS / 1000)) > 0.15 then
            return false
        end
    end
    return true
end

function NP.castbar.RefreshPlateCastTimes(plateData)
    local bar = plateData.minaCast
    if not bar or not bar.IsShown or not bar:IsShown() then return end
    if not bar.castStartTime or not bar.castEndTime then return end
    local _, startMS, endMS = NP.castbar.GetPlateCastInfo(plateData)
    if not startMS or not endMS then return end
    bar.castStartTime = startMS / 1000
    bar.castEndTime = endMS / 1000
    NP.castbar.SyncPlateCastProgress(bar)
end

function NP.castbar.SyncTargetCastIcon(bar, plateData, texture)
    if not bar then return end
    if not bar.minaCastIcon then
        bar.minaCastIcon = bar:CreateTexture(nil, "ARTWORK")
        bar.minaCastIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    if (not texture or texture == "") and plateData and plateData.castBarIcon
        and plateData.castBarIcon.GetTexture then
        texture = plateData.castBarIcon:GetTexture()
    end
    if texture and texture ~= "" then
        bar.minaCastIcon:SetTexture(texture)
        bar.minaCastIcon:Show()
        NP.castbar.LayoutCastSpellIcon(bar.minaCastIcon, bar, bar._notInterruptible)
    else
        bar.minaCastIcon:Hide()
    end
    if plateData and plateData.castBarIcon then
        plateData.castBarIcon:Hide()
    end
end

-- Pet/guardian detection for the native HD path (AwesomeWotlk). Off-target
-- allied-pet casts arrive through the native nameplate castbar with no resolved
-- unit token, so the unit-based IsPetCastUnit guard never fires. Fall back to the
-- cast owner GUID type (3.3.5a: high nibble 0xF14 = pet) when no token exists.
local function GuidIsPet(guid)
    return type(guid) == "string" and string.sub(guid, 1, 5) == "0xF14"
end

local function NativeCastOwnerIsPet(plateData)
    -- Use the plate's authoritative identity, which OnHideNameplate clears on
    -- recycle, rather than bar._castSourceGUID (can linger from a previous cast).
    -- This only matters on the no-token native path; with a token, plan A
    -- (bar._castOwnerIsPet) already answers.
    return GuidIsPet(NP.state.GetPlateGUID(plateData))
end

-- Language-independent layer: match the cast owner by creature entry id from the
-- plate GUID (Mirror Image, Treant, ghouls... are 0xF13 guardians, not 0xF14, so
-- GuidIsPet misses them). Needs a GUID; the name table covers the no-GUID case.
local function NativeCastNpcIsPet(plateData)
    local guid = NP.state.GetPlateGUID(plateData)
    if not guid then
        return false
    end
    local entry = NP.native_style.ParseNpcCreatureId(guid)
    return entry ~= nil and C.HIDE_PET_CAST_NPCIDS[entry] == true
end

-- Name blacklist (RefinedBlizzPlates-style) for pet/guardian/clone summons that
-- expose no usable token and are not 0xF14 pets (Mirror Image, Shadowfiend,
-- Treant, ghouls, ...). Last resort, gated by the Hide Pet Castbar option.
local function NativeCastNameIsPet(plateData)
    local name = plateData and plateData.plateName
    return name ~= nil and C.HIDE_PET_CAST_NAMES[name] == true
end

-- Sticky pet/clone snapshot (RBP-style). Mage Mirror Images spawn named
-- "Mirror Image", then the server renames them to the caster's own name. RBP
-- freezes the name at spawn and never re-reads it; we replicate that by latching
-- the blacklist match the first time the plate carries a known clone name and
-- keeping it for the plate's life, so the rename cannot un-hide the cast. The
-- latch is cleared on plate show/hide reset (PrepareNameplate / OnHideNameplate).
function NP.castbar.NotePlateNameForPetSnapshot(plateData, name)
    if not plateData or plateData._petCloneSnapshot then
        return
    end
    name = name or plateData.plateName
    if name and C.HIDE_PET_CAST_NAMES[name] == true then
        plateData._petCloneSnapshot = true
    end
end

-- Single source of truth for "this plate's cast is suppressed because it is a
-- pet/clone" (Hide Pet Castbar). Used both to hide the cast in SyncCastBar and to
-- suppress the interrupt/fade visual when such a cast ends -- e.g. a Gargoyle that
-- expires mid-cast must not flash the interrupted texture even though its cast
-- bar was hidden the whole time.
function NP.castbar.PlateCastHiddenAsPet(plateData, resolvedUnit)
    if not plateData or not NP.config.HidePetCasts(NP.config.GetCfg()) then
        return false
    end
    if plateData._petCloneSnapshot then
        return true
    end
    if resolvedUnit == nil then
        resolvedUnit = NP.identity.ResolvePlateCastUnit(plateData)
    end
    if NP.castbar.IsPetCastUnit(resolvedUnit) then return true end
    local bar = plateData.minaCast
    if bar and bar._castOwnerIsPet then return true end
    if NativeCastOwnerIsPet(plateData) then return true end
    if NativeCastNpcIsPet(plateData) then return true end
    if NativeCastNameIsPet(plateData) then return true end
    -- Own Mirror Images take the caster's exact name (unique per realm), so a
    -- plate named like the player is our clone. Survives the
    -- hide/re-show-while-already-renamed case the sticky snapshot cannot.
    local name = plateData.plateName
    if name and name ~= "" and UnitName and name == UnitName("player") then
        return true
    end
    -- Enemy Mirror Images: structural detection independent of the renamed text
    -- (several same-name low-HP plates plus a full-size owner). Cheap for normal
    -- units -- IsLikelyMirrorImagePlate early-outs on full max health.
    if NP.identity.IsLikelyMirrorImagePlate
        and NP.identity.IsLikelyMirrorImagePlate(plateData) then
        return true
    end
    return false
end

-- Main cast sync (target path)

function NP.castbar.SyncCastBar(plateData)
    local cfg = NP.config.GetCfg()
    local src = plateData.castBar
    local bar = plateData.minaCast
    if not bar then return end

    if NP.gather.IsTotemIconOnlyActive(plateData) then
        NP.castbar.HidePlateCastBar(plateData)
        return
    end

    if PlateHasActivePartyCast(plateData) then
        NP.castbar.HidePlateCastBar(plateData, true)
        return
    end

    if cfg.showCastBar == false then
        NP.castbar.HidePlateCastBar(plateData)
        return
    end

    local resolvedUnit = NP.identity.ResolvePlateCastUnit(plateData)

    -- Pet/clone filter (token, native bind flag, GUID 0xF14, npcID, name list, and
    -- the sticky Mirror-Image snapshot). Force-hide so a pet whose cast ends early
    -- cannot flash the interrupted/success visual. See PlateCastHiddenAsPet.
    if NP.castbar.PlateCastHiddenAsPet(plateData, resolvedUnit) then
        NP.castbar.HideNativeCastVisual(plateData)
        NP.castbar.HidePlateCastBar(plateData, true)
        return
    end

    local hasResolvedCast = resolvedUnit and (UnitCastingInfo(resolvedUnit) or UnitChannelInfo(resolvedUnit))
    if hasResolvedCast and IsReliableCastUnit(resolvedUnit) then
        BindCastSourceIdentity(plateData, resolvedUnit, bar)
    end

    -- An active combat-log monitor cast owns the bar until a reliable unit path
    -- takes over or the monitor timer ends.
    if bar._monitorGUID and bar.castEndTime and GetTime() < bar.castEndTime and not hasResolvedCast then
        if ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
            MonitorStopCast(plateData, true)
            return
        end
        NP.castbar.HideNativeCastVisual(plateData)
        NP.layout.LayoutCastBarStack(plateData)
        if not SyncMonitorCastFromNative(plateData, bar) then
            NP.castbar.SyncPlateCastProgress(bar)
        end
        return
    end

    -- A CLEU-confirmed cast may be recorded while the unit is resolved through
    -- target/focus/mouseover. Promote that backup when the authoritative unit
    -- path is lost so the cast bar remains visible until completion.
    if not hasResolvedCast then
        local backup = plateData._monitorBackup
        if backup and backup.guid and backup.castEndTime and GetTime() < backup.castEndTime
            and not (bar._monitorGUID and bar.castEndTime and GetTime() < bar.castEndTime) then
            local remainingMS = (backup.castEndTime - GetTime()) * 1000
            if NP.castbar.StartMonitorCast(plateData, backup.guid, backup.spellName, backup.spellIcon,
                backup.channeling, remainingMS, backup.confidence) then
                bar.castStartTime = backup.castStartTime
                bar.castEndTime = backup.castEndTime
                NP.castbar.HideNativeCastVisual(plateData)
                NP.layout.LayoutCastBarStack(plateData)
                if not SyncMonitorCastFromNative(plateData, bar) then
                    NP.castbar.SyncPlateCastProgress(bar)
                end
                return
            end
        end
    end

    -- Timed cast still running after destarget: keep progress without unit/native
    -- sources (keep the bar until finish; no success-fade on hide).
    if bar.castStartTime and bar.castEndTime and GetTime() < bar.castEndTime
        and (bar.castingEx or bar.channelingEx)
        and not (hasResolvedCast and IsReliableCastUnit(resolvedUnit)) then
        if ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
            MonitorStopCast(plateData, true)
            return
        end
        if not bar._monitorGUID then
            local guid = NP.state.GetPlateGUID(plateData) or bar._castSourceGUID
            if guid then
                bar._monitorGUID = guid
                if not bar._castSourceGUID then
                    bar._castSourceGUID = guid
                end
            end
        end
        NP.castbar.HideNativeCastVisual(plateData)
        NP.layout.LayoutCastBarStack(plateData)
        NP.castbar.SyncPlateCastProgress(bar)
        return
    end

    local castName, startMS, endMS, channeling, notInterruptible, castTexture = NP.castbar.GetPlateCastInfo(plateData)
    local monitorStillOwns = false
    if bar._fromCombatLog and bar._monitorGUID and bar.castEndTime and GetTime() < bar.castEndTime then
        if not hasResolvedCast then
            monitorStillOwns = true
        elseif castName then
            local monitorName = bar.spellName
            local monitorStart = bar.castStartTime
            local resolvedStart = startMS and (startMS / 1000) or nil
            local nameMatches = (not monitorName) or (monitorName == castName)
            local startMatches = (not monitorStart) or (not resolvedStart)
                or abs(monitorStart - resolvedStart) <= 0.20
            monitorStillOwns = not (nameMatches and startMatches)
        end
    end
    if monitorStillOwns then
        if ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
            MonitorStopCast(plateData, true)
            return
        end
        NP.castbar.HideNativeCastVisual(plateData)
        NP.layout.LayoutCastBarStack(plateData)
        if not SyncMonitorCastFromNative(plateData, bar) then
            NP.castbar.SyncPlateCastProgress(bar)
        end
        return
    end
    local authUnit = GetAuthoritativeCastUnit(plateData)
    local nativeCastingVisible = NP.castbar.IsNativeCastVisible(plateData)
    channeling = NP.castbar.ResolvePlateChanneling(plateData, channeling)
    local casting
    if authUnit then
        -- Unit API wins over stale native nameplate cast chrome on target/focus.
        casting = UnitHasActiveCast(authUnit) and true or false
    elseif castName ~= nil then
        casting = true
    else
        casting = nativeCastingVisible
    end

    if not casting then
        local earlyEnd = ShouldInterruptAuthoritativeEarlyEnd(plateData, bar)
        if (bar.castingEx or bar.channelingEx) and earlyEnd then
            MonitorStopCast(plateData, true)
            return
        end
        if bar._fromCombatLog and bar._monitorGUID and bar.castEndTime
            and GetTime() < bar.castEndTime then
            if earlyEnd then
                MonitorStopCast(plateData, true)
                return
            end
            NP.castbar.HideNativeCastVisual(plateData)
            NP.layout.LayoutCastBarStack(plateData)
            if not SyncMonitorCastFromNative(plateData, bar) then
                NP.castbar.SyncPlateCastProgress(bar)
            end
            return
        end
        if earlyEnd or NP.castbar.ShouldInterruptOnCastLoss(plateData, bar) then
            MonitorStopCast(plateData, true)
            return
        end
        NP.castbar.HidePlateCastBar(plateData)
        return
    end

    -- The main castbar must be the only castbar on this plate.
    if PartyRaidCastTracker.HideBar then
        PartyRaidCastTracker:HideBar(plateData)
    end

    local previousSpellName = bar.spellName
    bar._monitorGUID = nil
    bar._monitorConfidence = nil
    bar._fromCombatLog = nil
    bar._notInterruptible = ResolveCastNotInterruptible(plateData, bar, notInterruptible)
    bar.spellName = castName

    NP.castbar.HideNativeCastVisual(plateData)
    NP.layout.LayoutCastBarStack(plateData)
    NP.castbar.SyncTargetCastIcon(bar, plateData, castTexture)
    NP.castbar.EnsureCastIconShieldFrame(bar, "minaCastShield", bar)

    local useSmoothTimes = startMS and endMS
    local smoothActive = useSmoothTimes and bar.castStartTime and bar.castEndTime
        and bar.IsShown and bar:IsShown() and (bar.castingEx or bar.channelingEx)

    if smoothActive then
        local currentStart = bar.castStartTime or 0
        local newStart = startMS and (startMS / 1000) or 0
        local castChanged = (castName and castName ~= previousSpellName)
            or (startMS and abs(currentStart - newStart) > 0.15)
            or (bar.channelingEx ~= channeling)
        if castChanged then
            smoothActive = false
        end
    end

    if smoothActive then
        if ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
            MonitorStopCast(plateData, true)
            return
        end
        NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, false)
        return
    end

    if not useSmoothTimes then
        local minVal, maxVal, cur
        if src and nativeCastingVisible then
            minVal, maxVal = src:GetMinMaxValues()
            cur = src:GetValue()
        end
        if not maxVal or maxVal <= 0 or cur == nil then
            if NP.castbar.ShouldInterruptOnCastLoss(plateData, bar) then
                MonitorStopCast(plateData, true)
            else
                NP.castbar.HidePlateCastBar(plateData)
            end
            return
        end
        bar.castStartTime = nil
        bar.castEndTime = nil
        NP.castbar.ApplyPlateCastTextures(bar, channeling, plateData)
        bar:SetMinMaxValues(minVal, maxVal)
        bar:SetValue(cur)
        bar:Show()
        NP.castbar.SyncPlateCastProgress(bar)
    else
        bar.castStartTime = startMS / 1000
        bar.castEndTime = endMS / 1000

        local alreadyActive = bar.IsShown and bar:IsShown()
            and (bar.castingEx or bar.channelingEx)

        if not alreadyActive then
            NP.castbar.ApplyPlateCastTextures(bar, channeling, plateData)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            if bar.UpdateTextureClipping then
                local initial = channeling and 1.0 or 0.0
                bar:UpdateTextureClipping(initial, channeling)
            end
            bar:Show()
        elseif bar.channelingEx ~= channeling then
            NP.castbar.ApplyPlateCastTextures(bar, channeling, plateData)
        end

        NP.castbar.SyncPlateCastProgress(bar)
    end

    NP.castbar.SyncTargetCastIcon(bar, plateData, castTexture)
    NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, false)
    if bar and bar.IsShown and bar:IsShown() and (bar.castingEx or bar.channelingEx) then
        NP.castbar.RegisterCastTick(plateData)
    end
end

-- Native castbar hook handler (lifecycle)

function NP.castbar.OnNativeCastValueChanged(plateData, val)
    val = tonumber(val)
    if val and val >= 0.002 then
        UpdateNativeCastTrack(plateData, val)
    elseif val and val < 0.002 and TryShowNativeInterrupt(plateData) then
        if plateData.minaCast then
            plateData.minaCast._nativeCastShield = nil
        end
        ResetNativeCastTrack(plateData)
        return
    end

    local bar = plateData.minaCast
    local cfg = NP.config.GetCfg()
    local allowMonitorNativeSync = ShouldUseNativePatchSync(cfg)
    if bar and bar.castStartTime and bar.castEndTime
        and not (bar._fromCombatLog and allowMonitorNativeSync) then
        return
    end
    -- Keep the interrupted hold visual stable while the interrupt timer runs.
    if bar and (bar._intHideAt or bar._interrupted or bar._applyingInterruptVisual) then
        return
    end
    -- Success fade owns the bar until SyncCastBar clears it; do not patch fill mid-fade.
    if bar and (bar._successHoldUntil or bar._successHideAt or bar._successFading) then
        NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
        return
    end
    if bar and ShouldInterruptAuthoritativeEarlyEnd(plateData, bar) then
        MonitorStopCast(plateData, true)
        return
    end
    if bar and bar.IsShown and bar:IsShown() then
        local src = plateData.castBar
        if src and NP.castbar.IsNativeCastVisible(plateData) then
            NP.castbar.HideNativeCastVisual(plateData)
            local minVal, maxVal = src:GetMinMaxValues()
            local cur = src:GetValue()
            if maxVal and maxVal > (minVal or 0) and cur ~= nil then
                bar:SetMinMaxValues(minVal, maxVal)
                bar:SetValue(cur)
            end
            NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, false)
        end
        NP.castbar.SyncPlateCastProgress(bar)
    else
        NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
    end
end

-- UNIT_SPELLCAST_* handlers (engine)

local function ForEachPlateResolvedToUnit(unit, func)
    for _, plateData in pairs(NP.module.plates) do
        local resolved = NP.identity.ResolvePlateUnit(plateData)
        local castResolved = NP.identity.ResolvePlateCastUnit(plateData)
        if resolved == unit or castResolved == unit then
            func(plateData)
        end
    end
end

local function IsEventRoutedCastUnit(unit)
    if unit == "target" or unit == "focus" or unit == "mouseover" then
        return true
    end
    return NP.identity.IsArenaUnitToken(unit) and NP.module.inArena
end

local function RouteCastEventToPlate(unit, func)
    if not unit or not func then
        return
    end
    if IsEventRoutedCastUnit(unit) then
        local eventGUID = UnitGUID(unit)
        if eventGUID then
            local plateData = NP.state.GUIDToPlate[eventGUID]
            if not plateData and NP.module.inArena and NP.identity.IsArenaUnitToken(unit) then
                plateData = NP.identity.FindPlateForArenaUnit(unit)
                if plateData then
                    NP.identity.BindArenaPlateUnit(plateData, unit)
                end
            end
            if plateData then
                func(plateData)
            end
        end
        return
    end
    ForEachPlateResolvedToUnit(unit, func)
end

function NP.castbar.OnInterruptibleChanged(unit, isNotInt)
    ForEachPlateResolvedToUnit(unit, function(plateData)
        local bar = plateData.minaCast
        if bar and (bar.castingEx or bar.channelingEx) then
            bar._notInterruptible = isNotInt
            NP.castbar.UpdateCastInterruptibleVisuals(bar, plateData, false)
        end
    end)
    local trackedPlate = PartyRaidCastTracker:FindPlateForUnit(unit)
    if trackedPlate then
        local pBar = trackedPlate.minaPartyCast
        if pBar and (pBar.castingEx or pBar.channelingEx) then
            pBar._notInterruptible = isNotInt
            NP.castbar.UpdateCastInterruptibleVisuals(pBar, trackedPlate, true)
        end
    end
end

function NP.castbar.OnCastStartEvent(event, unit, ...)
    RouteCastEventToPlate(unit, function(plateData)
        NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
    end)
    PartyRaidCastTracker:OnEvent(event, unit, ...)
end

function NP.castbar.OnCastStopEvent(event, unit, ...)
    local eventSpell = (event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET")
        and select(1, ...) or nil
    local isHardInterrupt = (event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET")

    local function HandlePlateStop(plateData)
        local bar = plateData.minaCast
        if not bar or bar._intHideAt then
            return
        end
        if not PlateCastMatchesEventUnit(plateData, unit, bar) then
            return
        end
        if ShouldIgnoreUnitCastStop(bar, unit, eventSpell) then
            return
        end
        local markEnd = NP.castbar.MarkPlateCastEnd(bar, unit, event, eventSpell)
        local stoppedEarly = NP.castbar.PlateCastStoppedEarly(bar, unit, event)
        if isHardInterrupt then
            NP.castbar.ShowInterruptedState(bar, plateData, false)
        elseif markEnd or stoppedEarly then
            NP.castbar.ShowInterruptedState(bar, plateData, false)
        else
            NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
        end
    end

    -- Authoritative tokens are reassigned on retarget; route by event GUID only.
    RouteCastEventToPlate(unit, HandlePlateStop)
    PartyRaidCastTracker:OnEvent(event, unit, ...)
end

function NP.castbar.OnCastDelayedEvent(event, unit, ...)
    ForEachPlateResolvedToUnit(unit, function(plateData)
        NP.castbar.RefreshPlateCastTimes(plateData)
        NP.engine.QueuePlate(plateData, NP.engine.Callbacks.OnUpdateCastbar)
    end)
    PartyRaidCastTracker:OnEvent(event, unit, ...)
end
