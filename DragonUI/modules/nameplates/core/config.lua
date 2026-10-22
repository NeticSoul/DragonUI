-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates config accessors.

NP.config = NP.config or {}

function NP.config.GetCfg()
    return addon:GetModuleConfig("nameplates") or {}
end

-- off | hybrid | safe | aggressive
-- hybrid: players aggressive; NPCs safe (names can collide).
function NP.config.GetOffTargetCastMode(cfg)
    cfg = cfg or NP.config.GetCfg()
    local mode = cfg.castBarOffTargetMode
    if mode == "off" or mode == "aggressive" or mode == "safe" or mode == "hybrid" then
        return mode
    end
    if cfg.castBarOffTargetSafeOnly == true then
        return "safe"
    end
    if cfg.castBarOffTarget == true then
        return "aggressive"
    end
    return "hybrid"
end

function NP.config.IsOffTargetCastMonitorActive(cfg)
    local mode = NP.config.GetOffTargetCastMode(cfg)
    return mode == "aggressive" or mode == "safe" or mode == "hybrid"
end

function NP.config.IsHybridCastMode(cfg)
    return NP.config.GetOffTargetCastMode(cfg) == "hybrid"
end

-- Effective off-target mode for one CLEU source (hybrid splits player vs NPC).
function NP.config.ResolveEffectiveCastMode(cfg, sourceIsPlayer)
    local mode = NP.config.GetOffTargetCastMode(cfg)
    -- Unit tokens (awesome_wotlk) or plate cast bars on every plate (patched exe) already say who casts.
    if (mode == "aggressive" or mode == "hybrid") and (C_NamePlate or NP.module._nativeCastPatch) then
        return "safe"
    end
    if mode ~= "hybrid" then
        return mode
    end
    if sourceIsPlayer == true then
        return "aggressive"
    end
    return "safe"
end

-- Hide pet/guardian cast bars (default on).
function NP.config.HidePetCasts(cfg)
    cfg = cfg or NP.config.GetCfg()
    return cfg.castBarHidePetCasts ~= false
end

function NP.config.IsModuleEnabled()
    local cfg = NP.config.GetCfg()
    return cfg.enabled ~= false
end

function NP.config.IsRetailBehavior()
    local cfg = NP.config.GetCfg()
    return cfg.retailStackingEnabled == true
end

-- "legacy" (and the earlier "classic" spelling) opt out; anything else is a retail-style skin (Modern or Forever).
function NP.config.IsRetailSkin()
    local style = NP.config.GetCfg().plateStyle
    return style ~= "legacy" and style ~= "classic"
end

function NP.config.IsForeverSkin()
    return NP.config.GetCfg().plateStyle == "forever"
end

-- A skin switch may seed its layout, but must not destroy a tuned previous
-- style. All fields changed by a preset are saved/restored together.
local STYLE_FIELDS = {
    "barWidth", "barHeight", "castBarHeight", "fontSize", "castBarSpellNameFontSize",
    "debuffCooldownFontSize", "nameFont", "showCastBarSpellName", "threatGlow",
    "castBarGap", "centerNameOnly", "nameOverlayHealthBar", "retailTextOutlineAbove",
    "healthTextPosition", "showLevelAlways", "showLevelInName", "showLevelOnHover",
    "levelPosition", "levelTextFormat", "showEliteIcon", "castBarModernIconLeft",
    "castBarModernIconBorder", "showTargetArrows", "showCastBar", "showPowerBar",
    "retailSelectionBorder", "retailDeselectedOverlay", "retailMouseoverHighlight", "showTargetHighlight",
}

function NP.config.ApplyPlateStyle(previousStyle)
    local cfg = NP.config.GetCfg()
    local style = cfg.plateStyle or "legacy"
    previousStyle = previousStyle or "legacy"
    if style == previousStyle then return end
    cfg.plateStyleSettings = cfg.plateStyleSettings or {}
    local profiles = cfg.plateStyleSettings
    local previous = {}
    for _, key in ipairs(STYLE_FIELDS) do
        previous[key] = cfg[key]
    end
    profiles[previousStyle] = previous
    local saved = profiles[style]
    if saved then
        for _, key in ipairs(STYLE_FIELDS) do
            cfg[key] = saved[key]
        end
        return
    end

    -- Keep unrelated behavior choices from the previous style. Only Forever
    -- introduces a different text/level arrangement; leaving it for a style
    -- never selected before starts from the pre-Forever arrangement.
    if previousStyle == "forever" and profiles._beforeForever then
        for _, key in ipairs(STYLE_FIELDS) do
            cfg[key] = profiles._beforeForever[key]
        end
    elseif style == "forever" then
        profiles._beforeForever = previous
    end
    local modern = style == "modern"
    cfg.barWidth = modern and 148 or 150
    cfg.barHeight = modern and 16 or 9
    cfg.castBarHeight = modern and 8 or 9
    cfg.fontSize = 2
    cfg.castBarSpellNameFontSize = modern and 8 or 9
    local iconSize = cfg.debuffIconSize or 24
    cfg.debuffCooldownFontSize = modern and math.min(16, math.max(8, math.floor(iconSize * 0.55 + 0.5))) or 10
    cfg.threatGlow = not modern
    if modern then
        cfg.nameFont = "primary"
        cfg.showCastBarSpellName = true
    elseif style == "forever" then
        cfg.barWidth, cfg.barHeight, cfg.castBarHeight = 166, 13, 6
        cfg.fontSize, cfg.castBarSpellNameFontSize = 5, 10
        cfg.castBarGap = 2
        cfg.centerNameOnly, cfg.nameOverlayHealthBar = true, false
        cfg.retailTextOutlineAbove = true
        cfg.healthTextPosition = "barRight"
        cfg.showLevelAlways, cfg.showLevelInName, cfg.showLevelOnHover = true, true, true
        cfg.levelPosition, cfg.levelTextFormat = "name", "plain"
        cfg.nameFont = "primary"
        cfg.showCastBar, cfg.showCastBarSpellName = true, true
        cfg.retailSelectionBorder, cfg.retailDeselectedOverlay = true, true
        cfg.retailMouseoverHighlight, cfg.showTargetHighlight = true, true
        cfg.castBarModernIconLeft, cfg.castBarModernIconBorder = false, false
        cfg.showEliteIcon, cfg.threatGlow, cfg.showTargetArrows, cfg.showPowerBar = false, false, false, false
    end
end

function NP.config.IsBattleGroundHealersLoaded()
    return IsAddOnLoaded and IsAddOnLoaded("BattleGroundHealers") or false
end

function NP.config.IsBGHCompatEnabled()
    local cfg = NP.config.GetCfg()
    return cfg.bghCompatEnabled ~= false and NP.config.IsBattleGroundHealersLoaded()
end

-- Skips native-alpha force that fights external plate addons reading alpha/IsShown as identity.
function NP.config.IsPlateAlphaCompatEnabled()
    local cfg = NP.config.GetCfg()
    return cfg.nameplateAlphaCompat == true
end

function NP.config.GetBarRefSize()
    local cfg = NP.config.GetCfg()
    return cfg.barWidth or 150, cfg.barHeight or 9
end

function NP.config.GetStackBarGap()
    local cfg = NP.config.GetCfg()
    return cfg.castBarGap or 3
end

function NP.config.GetCastBarMetrics()
    local cfg = NP.config.GetCfg()
    local _, barH = NP.config.GetBarRefSize()
    return cfg.castBarHeight or barH, NP.config.GetStackBarGap()
end

-- The click area is the plate's rect, so a raised stack lifts the plate; retail stacking owns that clamp.
function NP.config.GetClickLift()
    local cfg = NP.config.GetCfg()
    local oy = cfg.offsetY or 0
    if oy > 0 and cfg.retailStackingEnabled ~= true then
        return oy
    end
    return 0
end

function NP.config.GetStackOffset()
    local cfg = NP.config.GetCfg()
    return cfg.offsetX or 0, (cfg.offsetY or 0) - NP.config.GetClickLift()
end

function NP.config.GetNameplateFontSizes()
    local cfg = NP.config.GetCfg()
    local scale = cfg.fontSize or 2
    return 9 + scale, 7 + scale
end

function NP.config.GetNameplateFont()
    local key = NP.config.GetCfg().nameFont or "primary"
    local addonKey = C.NAMEPLATE_FONT_MAP[key]
    if addonKey and addon.Fonts then
        return addon.Fonts[addonKey] or "Fonts\\FRIZQT__.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Retail swaps the whole fill per cast type; the legacy skin only ever had two.
function NP.config.GetCastFillTexture(isChannel, notInterruptible, interrupted)
    if NP.config.IsRetailSkin() then
        local fills = NP.config.IsForeverSkin() and NP.atlas.FOREVER_CAST_FILL or NP.atlas.CAST_FILL
        if interrupted then
            return fills.interrupted
        elseif notInterruptible then
            return fills.uninterruptible
        end
        return isChannel and fills.channel or fills.standard
    end
    return isChannel and C.CAST_TEX_CHANNEL or C.CAST_TEX_STANDARD
end

-- Retail's Modern style sets nameInsideBar, but the name stays above the bar here
-- unless the user opts in, so the existing toggle keeps owning the choice.
function NP.config.IsNameOverlayBar()
    return NP.config.GetCfg().nameOverlayHealthBar == true
end

local HEALTH_TEXT_FORMATS = { none = true, percent = true, value = true, valuePercent = true }
local HEALTH_TEXT_PLACEMENTS = { afterName = true, barRight = true, barCenter = true, barSplit = true }

function NP.config.GetHealthTextFormat()
    local fmt = NP.config.GetCfg().healthTextFormat
    return HEALTH_TEXT_FORMATS[fmt] and fmt or "percent"
end

-- A name inside the bar already owns its left side, so the health text has to share its line.
function NP.config.GetHealthTextPlacement()
    if NP.config.IsNameOverlayBar() then
        return "afterName"
    end
    local placement = NP.config.GetCfg().healthTextPosition
    return HEALTH_TEXT_PLACEMENTS[placement] and placement or "afterName"
end

function NP.config.IsPowerShown(plateData)
    local cfg = NP.config.GetCfg()
    if cfg.showPowerBar == false then return false end
    local po = plateData.minaPo
    return po and po.IsShown and po:IsShown()
end
