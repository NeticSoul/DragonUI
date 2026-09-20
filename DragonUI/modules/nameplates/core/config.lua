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

-- "legacy" (and the earlier "classic" spelling) opt out; anything else is the modern skin.
function NP.config.IsRetailSkin()
    local style = NP.config.GetCfg().plateStyle
    return style ~= "legacy" and style ~= "classic"
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

function NP.config.GetStackOffset()
    local cfg = NP.config.GetCfg()
    return cfg.offsetX or 0, cfg.offsetY or 0
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
        local fills = NP.atlas.CAST_FILL
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

function NP.config.IsPowerShown(plateData)
    local cfg = NP.config.GetCfg()
    if cfg.showPowerBar == false then return false end
    local po = plateData.minaPo
    return po and po.IsShown and po:IsShown()
end
