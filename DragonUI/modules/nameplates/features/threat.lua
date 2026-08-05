local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates threat: glow and aggro bar tint.

NP.threat = NP.threat or {}

function NP.threat.IsHostilePlateByColor(plateData)
    if not plateData then
        return false
    end
    -- Exclude friendly plates only.
    local reaction = NP.native_style.GetPlateReaction and NP.native_style.GetPlateReaction(plateData)
    if not reaction then
        return false
    end
    return reaction ~= "FRIENDLY"
end

function NP.threat.GetAggroStatus(threat)
    if not threat or not threat.GetVertexColor then
        return 0
    end
    if threat.IsShown and not threat:IsShown() then
        return 0
    end
    local r, g, _ = threat:GetVertexColor()
    if not r or r == 0 then
        return 0
    end
    if g and g < 0.5 then
        return 3
    end
    if g and g < 0.9 then
        return 2
    end
    return 1
end

-- Suppress in arena; native threat vs players is misleading.
function NP.threat.IsThreatSuppressedContext()
    return NP.module.inArena == true
end

-- With unit token: UnitDetailedThreatSituation; else native glow color buckets.
-- Memoize per tick; threat tint/glow/scan share unit resolution.
function NP.threat.ResolveAggroStatus(plateData)
    if not plateData then
        return 0
    end
    local tick = NP.module._engineFrame
    if tick and plateData._aggroStatusTick == tick then
        return plateData._aggroStatus
    end
    local status
    local unit = NP.identity and NP.identity.ResolvePlateCastUnit
        and NP.identity.ResolvePlateCastUnit(plateData)
    if unit and UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitDetailedThreatSituation then
        local _, detailed = UnitDetailedThreatSituation("player", unit)
        if detailed ~= nil then
            status = detailed
        end
    end
    if status == nil then
        status = NP.threat.GetAggroStatus(plateData.threat)
    end
    if tick then
        plateData._aggroStatusTick = tick
        plateData._aggroStatus = status
    end
    return status
end

function NP.threat.IsTankMode()
    return NP.config.GetCfg().tankMode == true
end

-- Mutually exclusive with tankMode; tank wins if both are somehow true.
function NP.threat.IsDpsMode()
    local cfg = NP.config.GetCfg()
    return cfg.dpsMode == true and cfg.tankMode ~= true
end

-- Tank "lost aggro" only when the hostile is already engaged (needs unit token).
local function ResolveTankLostColor(plateData)
    local unit = NP.identity and NP.identity.ResolvePlateCastUnit
        and NP.identity.ResolvePlateCastUnit(plateData)
    if unit and UnitExists(unit) and UnitAffectingCombat(unit) then
        return C.AGGRO_COLORS.tankLost
    end
    return nil
end

-- Default: any aggro warns. Tank: hold=safe / lose=warn.
-- DPS matches ThreatPlates: LOW=green, MEDIUM=yellow, HIGH=red (no unit-token gate).
local function ResolveAggroColor(plateData, status)
    if NP.threat.IsDpsMode() then
        if status >= 3 then
            return C.AGGRO_COLORS.dpsDanger
        elseif status >= 1 then
            return C.AGGRO_COLORS.dpsWarning
        end
        return C.AGGRO_COLORS.dpsSafe
    end
    if status <= 0 then
        if NP.threat.IsTankMode() then
            return ResolveTankLostColor(plateData)
        end
        return nil
    end
    if NP.threat.IsTankMode() then
        if status == 3 then
            return C.AGGRO_COLORS.tankHolding
        elseif status == 2 then
            return C.AGGRO_COLORS.tankWarning
        end
        return nil
    end
    if status == 3 then
        return C.AGGRO_COLORS.tanking
    elseif status == 2 then
        return C.AGGRO_COLORS.losing
    end
    return C.AGGRO_COLORS.gaining
end

-- Combat-only aggro bar tint; nil out of combat or with no threat status.
function NP.threat.GetAggroBarTint(plateData)
    if not NP.module.playerInCombat or NP.threat.IsThreatSuppressedContext()
        or not NP.threat.IsHostilePlateByColor(plateData) then
        return nil
    end
    local status = NP.threat.ResolveAggroStatus(plateData)
    local c = ResolveAggroColor(plateData, status)
    if not c then
        return nil
    end
    return c[1], c[2], c[3]
end

function NP.threat.ApplyThreatGlow(plateData)
    local cfg = NP.config.GetCfg()
    if cfg.threatGlow == false then
        if plateData.minaThreatTex then
            plateData.minaThreatTex:Hide()
        end
        return
    end

    local threat = plateData.threat
    local glow = plateData.minaThreatTex
    local hp = plateData.minaHp
    if not threat or not glow or not hp then return end

    -- Blizzard may restore threat texcoords on aggro change.
    if threat.SetTexCoord then
        threat:SetTexCoord(0, 0, 0, 0)
    end

    local inCombat = NP.module.playerInCombat and true or false
    if not inCombat or NP.threat.IsThreatSuppressedContext()
        or not NP.threat.IsHostilePlateByColor(plateData) then
        glow:Hide()
        return
    end

    local status = NP.threat.ResolveAggroStatus(plateData)
    local c = ResolveAggroColor(plateData, status)
    if c then
        glow:SetVertexColor(c[1], c[2], c[3], 0.75)
        glow:SetAlpha(plateData._lastAppliedVisualAlpha or 1.0)
        glow:Show()
    else
        glow:Hide()
    end
end

NP.widgets.Register("ThreatGlow", {
    Ensure = function(plateData)
        return plateData and plateData.minaThreatTex ~= nil
    end,
    Layout = function(plateData)
        return plateData and plateData.minaHp ~= nil
    end,
    Sync = function(plateData)
        NP.threat.ApplyThreatGlow(plateData)
    end,
    Hide = function(plateData)
        if plateData and plateData.minaThreatTex then
            plateData.minaThreatTex:Hide()
        end
    end,
})
