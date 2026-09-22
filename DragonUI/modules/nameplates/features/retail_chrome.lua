local addon = select(2, ...)
local NP = addon.Nameplates
NP.retail_chrome = NP.retail_chrome or {}
local C = NP.const
local A = NP.atlas

-- Retail nameplate chrome: capsule background, selection border, non-target dim,
-- mouseover wash and the scrolling aggro flare.

-- Every piece here rings a 10-unit cavity, so one scale keeps all their rims flush with the fill.
local SLICE_INTERIOR_H = 10
-- barBg 132x19: rim on rows 2/13 and cols 1/126; retail's own bgTexture inset
-- is TOPLEFT(-2,3)/BOTTOMRIGHT(6,-6) in Blizzard_NamePlateUnitFrame.lua:755.
local BG_L_UNITS, BG_R_UNITS = 2, 6
local BG_T_UNITS, BG_B_UNITS = 3, 6
-- selected 216x18: white line on rows 3/14 and cols 3/212.
local SEL_UNITS = 4
-- deselected 210x12: flat 30% wash over rows 1..10, cols 1..208.
local DESEL_UNITS = 1
-- castFrame 214x16: rail on rows 2/13; NewEra's +/-2 suits a plain stretch, not a nine-slice.
local CAST_FRAME_UNITS = 3

local MOUSEOVER_TEX = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
local MOUSEOVER_ALPHA = 0.25

-- Retail scrolls the flare one bar width every 40s (NamePlatesAggro.lua SCROLL_DURATION).
local FLARE_SCROLL_DURATION = 40
local FLARE_ADD_ALPHA = 0.4
-- Retail fades the flare in over 2s on aggro gain (AggroHighlightFadeInAnim).
local FLARE_FADE_IN = 2
-- The flare is sized off the bucket's own vertical scale, which is barH/20 (the health
-- bar is 20*v), not off the capsule scale.
local RETAIL_FLARE_BASE_H = 20
-- Retail's lose-aggro alert: two 0.25s yellow pulses over the bar.
local FLASH_PULSE = 0.25
local FLASH_PULSES = 2
local TANK_BORDER = { 1, 1, 0 }

-- Margin scale: native above the art's own cavity, shrinking proportionally below it.
local function SliceScale(h)
    local s = h / SLICE_INTERIOR_H
    return s < 1 and s or 1
end

local function CapsuleScale()
    local _, barH = NP.config.GetBarRefSize()
    return SliceScale(barH)
end

-- The StatusBar's own texture stays as the value carrier but is drawn at alpha 0.
local function SetFillSliceOn(bar, on)
    if not bar or not bar._retailFill then
        return
    end
    bar._retailFillOn = on or nil
    bar._fillClipRight = nil
    local r, g, b = bar:GetStatusBarColor()
    NP.discovery.SetBarColor(bar, r or 1, g or 1, b or 1)
    if not on then
        A.HideSlice(bar._retailFill)
    end
end

function NP.retail_chrome.LayoutFill(bar, fraction)
    local fill = bar._retailFill
    if not fill then
        return
    end
    local w, h = NP.config.GetBarRefSize()
    if A.LayoutSlice(fill, "barFill", bar, w * fraction, h, 0, 0, 0, 0) then
        A.ShowSlice(fill)
    end
end

local function RefreshFill(bar)
    if not bar or not bar._retailFillOn then
        return
    end
    local lo, hi = bar:GetMinMaxValues()
    bar._fillClipRight = nil
    NP.discovery.ClipBarFill(bar, bar:GetValue() - lo, hi - lo)
end

local function SetLegacyBarChrome(bar, shown)
    if not bar then
        return
    end
    if bar.minaBg then
        if shown then
            bar.minaBg:Show()
        else
            bar.minaBg:Hide()
        end
    end
    if bar.minaBr then
        if shown then
            bar.minaBr:Show()
        else
            bar.minaBr:Hide()
        end
    end
end

-- Flare strips

local flareDriver
local mouseoverLit
local activeFlares = setmetatable({}, { __mode = "k" })
local activeFlashes = setmetatable({}, { __mode = "k" })

local function SetFlarePieceShown(tex, shown)
    if tex._flareShown ~= shown then
        tex._flareShown = shown
        if shown then tex:Show() else tex:Hide() end
    end
end

-- NewEra clips the flare with a MaskTexture the width of the bar. With no mask API we
-- clip by hand: two pieces per layer, split at the wrap seam, never wider than the bar.
local function PlaceFlareLayer(f, first, hp, barW, off)
    local headW = barW - off
    local head, tail = f[first], f[first + 1]

    if headW > 0 then
        if head._flareAnchor ~= hp then
            head._flareAnchor = hp
            head:SetPoint("BOTTOMLEFT", hp, "TOPLEFT", 0, 0)
        end
        head:SetWidth(headW)
        head:SetTexCoord(off / barW, 1, 0, 1)
    end
    SetFlarePieceShown(head, f.shown and headW > 0)

    if off > 0 then
        tail:SetPoint("BOTTOMLEFT", hp, "TOPLEFT", headW, 0)
        tail:SetWidth(off)
        tail:SetTexCoord(0, off / barW, 0, 1)
    end
    SetFlarePieceShown(tail, f.shown and off > 0)
end

local function PlaceFlare(plateData, elapsed)
    local f = plateData._retailFlare
    local hp = plateData.minaHp
    local barW = hp and hp:GetWidth() or 0
    if not f or barW <= 0 then
        return false
    end
    if f.shown and f.fadeStart then
        local t = (GetTime() - f.fadeStart) / FLARE_FADE_IN
        if t >= 1 then
            f.fadeStart = nil
            t = 1
        end
        f[1]:SetAlpha(t)
        f[2]:SetAlpha(t)
        f[3]:SetAlpha(t * FLARE_ADD_ALPHA)
        f[4]:SetAlpha(t * FLARE_ADD_ALPHA)
    end
    local off = ((elapsed / FLARE_SCROLL_DURATION) * barW) % barW
    PlaceFlareLayer(f, 1, hp, barW, off)
    PlaceFlareLayer(f, 3, hp, barW, barW - off)
    return true
end

local function SetFlareShown(plateData, shown)
    local f = plateData._retailFlare
    if not f or f.shown == shown then
        return
    end
    f.shown = shown
    activeFlares[plateData] = shown or nil
    if shown then
        f.fadeStart = GetTime()
        PlaceFlare(plateData, flareDriver and flareDriver.elapsed or 0)
        if flareDriver then
            flareDriver:Show()
        end
    else
        for i = 1, 4 do
            SetFlarePieceShown(f[i], false)
        end
    end
end

local hoveredPlate

-- The client highlights the plate a click would hit, but only a highlight under the cursor is live.
local function FindHoveredPlate()
    local best, bestDepth
    local anyShown = false
    local overWorld = GetMouseFocus() == WorldFrame
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData.plate
        if plate and plate:IsShown() then
            anyShown = true
            local highlight = plateData.highlight
            if highlight and highlight:IsShown() then
                if plate:IsMouseOver() then
                    local depth = plate:GetEffectiveDepth() or 0
                    if overWorld and (not best or depth < bestDepth) then
                        best, bestDepth = plateData, depth
                    end
                else
                    -- A camera turn strands it on a plate the cursor left; the next real hover re-shows it.
                    highlight:Hide()
                end
            end
        end
    end
    return best, anyShown
end

local function IsPlateHovered(plateData)
    return plateData ~= nil and plateData == hoveredPlate
end

local function EnsureFlareDriver()
    if flareDriver then
        return
    end
    flareDriver = CreateFrame("Frame", nil, UIParent)
    flareDriver.elapsed = 0
    flareDriver:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        local any = false
        for plateData in pairs(activeFlares) do
            if PlaceFlare(plateData, self.elapsed) then
                any = true
            end
        end
        local now = GetTime()
        for plateData in pairs(activeFlashes) do
            local flash = plateData._retailFlash
            local until_ = plateData._flashUntil
            if flash and until_ then
                if now >= until_ then
                    flash:SetAlpha(0)
                    flash:Hide()
                    plateData._flashUntil = nil
                    activeFlashes[plateData] = nil
                else
                    any = true
                    -- Sawtooth: each pulse ramps 1 -> 0 over FLASH_PULSE.
                    local phase = ((now - plateData._flashStart) % FLASH_PULSE) / FLASH_PULSE
                    flash:SetAlpha(1 - phase)
                end
            else
                activeFlashes[plateData] = nil
            end
        end

        -- Hover fires no event: poll it here rather than adding a second OnUpdate.
        -- Only transitions reach SyncMouseover, so a quiet frame costs one getter per plate.
        if NP.config.IsRetailSkin() and NP.config.GetCfg().retailMouseoverHighlight ~= false then
            -- An empty screen lets the tick park; only the plates entering and leaving hover resync.
            local hovered, anyShown = FindHoveredPlate()
            if anyShown then
                any = true
            end
            if hovered ~= hoveredPlate then
                local previous = hoveredPlate
                hoveredPlate = hovered
                if previous then
                    NP.retail_chrome.SyncMouseover(previous)
                end
                if hovered then
                    NP.retail_chrome.SyncMouseover(hovered)
                end
            end
        end

        -- Park when nothing needs the tick; the show sites bring it back.
        if not any then
            self:Hide()
        end
    end)
end

local function EnsureChrome(plateData)
    local hp = plateData and plateData.minaHp
    if not hp then
        return false
    end
    if not plateData._retailBg then
        plateData._retailBg = A.CreateSlice(hp, "BACKGROUND")
        hp._retailFill = A.CreateSlice(hp, "BORDER")

        local flare = { shown = false }
        for i = 1, 4 do
            local t = hp:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(A.AGGRO_FLARE)
            if i > 2 then
                t:SetBlendMode("ADD")
                t:SetAlpha(FLARE_ADD_ALPHA)
            end
            t:Hide()
            flare[i] = t
        end
        plateData._retailFlare = flare
        EnsureFlareDriver()
        flareDriver:Show()

        plateData._retailDeselected = A.CreateSlice(hp, "OVERLAY")
        plateData._retailSelected = A.CreateSlice(hp, "OVERLAY")

        local flash = hp:CreateTexture(nil, "OVERLAY")
        flash:SetTexture(1, 1, 0, 1)
        flash:SetBlendMode("ADD")
        flash:SetAlpha(0)
        flash:Hide()
        plateData._retailFlash = flash

        local mo = hp:CreateTexture(nil, "OVERLAY")
        mo:SetTexture(MOUSEOVER_TEX)
        mo:SetAlpha(MOUSEOVER_ALPHA)
        mo:SetBlendMode("ADD")
        mo:Hide()
        plateData._retailMouseover = mo
    end
    local po = plateData.minaPo
    if po and not plateData._retailPoBg then
        plateData._retailPoBg = A.CreateSlice(po, "BACKGROUND")
        po._retailFill = A.CreateSlice(po, "BORDER")
        -- The power bar can appear after the first Ensure; force a relayout for it.
        plateData._retailChromeSig = nil
    end
    local cast = plateData.minaCast
    if cast and not plateData._retailCastFrame then
        plateData._retailCastFrame = A.CreateSlice(cast, "ARTWORK")
        plateData._retailChromeSig = nil
    end
    return true
end

local function LayoutChrome(plateData)
    local hp = plateData and plateData.minaHp
    if not hp then
        return false
    end
    local w, h = NP.config.GetBarRefSize()
    local castH = select(1, NP.config.GetCastBarMetrics())
    local sig = w .. ":" .. h .. ":" .. castH
    if plateData._retailChromeSig == sig then
        return true
    end
    plateData._retailChromeSig = sig

    SetFillSliceOn(hp, true)
    SetFillSliceOn(plateData.minaPo, true)
    RefreshFill(hp)
    RefreshFill(plateData.minaPo)

    local m = CapsuleScale()
    local padL, padR = BG_L_UNITS * m, BG_R_UNITS * m
    local padT, padB = BG_T_UNITS * m, BG_B_UNITS * m
    A.LayoutSlice(plateData._retailBg, "barBg", hp, w, h, padL, padT, padR, padB)
    local sel = SEL_UNITS * m
    A.LayoutSlice(plateData._retailSelected, "selected", hp, w, h, sel, sel, sel, sel)
    local des = DESEL_UNITS * m
    A.LayoutSlice(plateData._retailDeselected, "deselected", hp, w, h, des, des, des, des)

    local flare = plateData._retailFlare
    if flare then
        -- Retail compresses the 32px mask band by 0.7 so the flare reads as an accent.
        local sv = h / RETAIL_FLARE_BASE_H
        local bandH = math.max(10, math.floor(32 * sv * 0.7 + 0.5))
        for i = 1, 4 do
            flare[i]:SetHeight(bandH)
        end
        -- Size before the driver's first tick: an unsized texture falls back to its
        -- file width, which is what sprayed streaks across the screen.
        PlaceFlare(plateData, flareDriver and flareDriver.elapsed or 0)
    end

    local flash = plateData._retailFlash
    if flash then
        flash:ClearAllPoints()
        flash:SetPoint("TOPLEFT", hp, "TOPLEFT", 0, 0)
        flash:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", 0, 0)
    end

    local mo = plateData._retailMouseover
    if mo then
        mo:ClearAllPoints()
        mo:SetPoint("TOPLEFT", hp, "TOPLEFT", 0, 0)
        mo:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", 0, 0)
    end

    local po = plateData.minaPo
    if po and plateData._retailPoBg then
        -- Not only in SyncChrome: that runs once behind _retailChromeOn, and these bars
        -- can be built after it, which left their legacy chrome drawn over the capsule.
        SetLegacyBarChrome(po, false)
        A.LayoutSlice(plateData._retailPoBg, "barBg", po, w, h, padL, padT, padR, padB)
    end

    local cast = plateData.minaCast
    if cast and plateData._retailCastFrame then
        cast._cachedCastH = nil
        if cast.minaBr then
            cast.minaBr:Hide()
        end
        if cast.minaBg then
            A.Apply(cast.minaBg, "castBg")
            cast.minaBg:SetVertexColor(1, 1, 1, 1)
        end
        local cp = CAST_FRAME_UNITS * SliceScale(castH)
        A.LayoutSlice(plateData._retailCastFrame, "castFrame", cast, w, castH, cp, cp, cp, cp)
        -- Children of the cast bar: it hides them with itself, so show once here.
        A.ShowSlice(plateData._retailCastFrame)

        if cast._successFlash then
            A.Apply(cast._successFlash, "castGlow")
        end
    end
    return true
end

local function HideChrome(plateData, restoreLegacy)
    if not plateData then
        return
    end
    A.HideSlice(plateData._retailBg)
    A.HideSlice(plateData._retailSelected)
    A.HideSlice(plateData._retailDeselected)
    A.HideSlice(plateData._retailPoBg)
    A.HideSlice(plateData._retailCastFrame)
    SetFlareShown(plateData, false)
    if plateData._retailMouseover then
        plateData._retailMouseover:Hide()
        if mouseoverLit == plateData then
            mouseoverLit = nil
        end
    end
    if plateData._retailFlash then
        plateData._retailFlash:Hide()
        plateData._retailFlash:SetAlpha(0)
    end
    plateData._flashUntil = nil
    activeFlashes[plateData] = nil
    if restoreLegacy and plateData._retailChromeOn then
        plateData._retailChromeOn = nil
        plateData._retailChromeSig = nil
        SetFillSliceOn(plateData.minaHp, false)
        SetFillSliceOn(plateData.minaPo, false)
        SetLegacyBarChrome(plateData.minaHp, true)
        SetLegacyBarChrome(plateData.minaPo, true)
        local cast = plateData.minaCast
        if cast and cast.minaBg then
            cast.minaBg:SetTexCoord(0, 1, 0, 1)
            cast.minaBg:SetTexture(C.MINA_TEX .. "bar-bg")
        end
        if cast then
            cast._cachedCastH = nil
        end
        SetLegacyBarChrome(cast, true)
    end
end

local function StartFlash(plateData)
    local flash = plateData._retailFlash
    if not flash then
        return
    end
    plateData._flashStart = GetTime()
    plateData._flashUntil = plateData._flashStart + FLASH_PULSE * FLASH_PULSES
    flash:SetAlpha(1)
    flash:Show()
    activeFlashes[plateData] = true
    if flareDriver then
        flareDriver:Show()
    end
end

-- Retail tints the health-bar border yellow while a tank is not holding this unit.
local function SyncTankBorder(plateData, cfg)
    local want = false
    if cfg.tankMode == true and NP.module.playerInCombat then
        local status = NP.threat.ResolveAggroStatus(plateData)
        want = (status ~= nil and status < 3 and NP.threat.IsHostilePlateByColor(plateData))
    end
    if plateData._tankBorderOn == want then
        return
    end
    plateData._tankBorderOn = want
    if want then
        A.SetSliceVertexColor(plateData._retailBg, TANK_BORDER[1], TANK_BORDER[2], TANK_BORDER[3], 1)
    else
        A.SetSliceVertexColor(plateData._retailBg, 1, 1, 1, 1)
    end
end

local function SyncFlareInternal(plateData, cfg)
    local flare = plateData._retailFlare
    if not flare then
        return
    end
    if cfg.threatGlow == false then
        SetFlareShown(plateData, false)
        plateData._hadAggro = nil
        return
    end
    local r, g, b = NP.threat.GetAggroBarTint(plateData)
    if not r then
        if plateData._hadAggro and NP.module.playerInCombat then
            StartFlash(plateData)
        end
        plateData._hadAggro = nil
        SetFlareShown(plateData, false)
        return
    end
    plateData._hadAggro = true
    -- Reached on every health tick of an aggroed plate; the tint only moves on threat changes.
    if flare.r ~= r or flare.g ~= g or flare.b ~= b then
        flare.r, flare.g, flare.b = r, g, b
        for i = 1, 4 do
            flare[i]:SetVertexColor(r, g, b)
        end
    end
    SetFlareShown(plateData, true)
end

-- How far the capsule reaches above the bar, so callers can clear it.
function NP.retail_chrome.GetTopInset()
    if not NP.config.IsRetailSkin() then
        return 0
    end
    return BG_T_UNITS * CapsuleScale()
end

-- Mouseover changes never reach the widget sync list, so the wash is driven from the
-- mouseover refresh. Only the NEW plate gets refreshed on a move, so the plate that was
-- lit before has to be cleared here or it keeps the wash (most visible on the target).
-- The mouseover UNIT is not set by hovering a plate on 3.3.5a, so identity's
-- mouseoverPlate misses plate hovers entirely once a target exists. The plate's own
-- native highlight (and its rect) answer "is the cursor on this plate" directly.

function NP.retail_chrome.SyncMouseover(plateData)
    local mo = plateData and plateData._retailMouseover
    if not mo then
        return
    end
    local cfg = NP.config.GetCfg()
    local want = NP.config.IsRetailSkin() and cfg.retailMouseoverHighlight ~= false
        and not NP.gather.IsHeadlineActive(plateData)
        and IsPlateHovered(plateData)

    if want then
        if mouseoverLit and mouseoverLit ~= plateData then
            local prev = mouseoverLit._retailMouseover
            if prev then
                prev:Hide()
            end
        end
        mouseoverLit = plateData
        mo:Show()
    else
        if mouseoverLit == plateData then
            mouseoverLit = nil
        end
        mo:Hide()
    end
end

function NP.retail_chrome.SyncFlare(plateData)
    if not NP.config.IsRetailSkin() then
        return
    end
    SyncFlareInternal(plateData, NP.config.GetCfg())
end


local function SyncChrome(plateData, isTarget)
    local cfg = NP.config.GetCfg()

    if NP.gather.IsHeadlineActive(plateData) then
        HideChrome(plateData, false)
        return
    end

    if not plateData._retailChromeOn then
        plateData._retailChromeOn = true
        SetLegacyBarChrome(plateData.minaHp, false)
        SetLegacyBarChrome(plateData.minaPo, false)
        -- minaCast.minaBg carries the retail cast background, so only its border is legacy.
        local castBar = plateData.minaCast
        if castBar and castBar.minaBr then
            castBar.minaBr:Hide()
        end
    end

    A.ShowSlice(plateData._retailBg)
    if plateData.minaPo and plateData.minaPo:IsShown() then
        A.ShowSlice(plateData._retailPoBg)
    else
        A.HideSlice(plateData._retailPoBg)
    end

    local cast = plateData.minaCast
    if cast and cast._successFlash then
        A.Apply(cast._successFlash, cast.channelingEx and "castGlowChannel" or "castGlow")
    end

    -- The driver parks itself once every plate is hidden; a plate coming back has to restart it.
    if flareDriver and cfg.retailMouseoverHighlight ~= false then
        flareDriver:Show()
    end

    SyncFlareInternal(plateData, cfg)
    SyncTankBorder(plateData, cfg)

    if isTarget == nil then
        isTarget = NP.identity.IsTargetPlateVisual(plateData)
    end

    if isTarget and cfg.retailSelectionBorder ~= false and cfg.showTargetHighlight ~= false then
        A.ShowSlice(plateData._retailSelected)
    else
        A.HideSlice(plateData._retailSelected)
    end

    if not isTarget and cfg.retailDeselectedOverlay ~= false then
        A.ShowSlice(plateData._retailDeselected)
    else
        A.HideSlice(plateData._retailDeselected)
    end

    NP.retail_chrome.SyncMouseover(plateData)
end

NP.widgets.Register("RetailChrome", {
    ShouldShow = function()
        return NP.config.IsRetailSkin()
    end,
    Ensure = function(plateData)
        return EnsureChrome(plateData)
    end,
    Layout = function(plateData)
        return LayoutChrome(plateData)
    end,
    Sync = function(plateData, _context, state)
        local visible = state and state.showTargetHighlight
        SyncChrome(plateData, visible)
    end,
    Hide = function(plateData)
        HideChrome(plateData, true)
    end,
})
