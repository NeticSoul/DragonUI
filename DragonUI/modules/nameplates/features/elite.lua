local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates elite/rare icon.

function NP.widgets.GetEliteIconTextures()
    local suffix = NP.config.GetCfg().eliteIconStyle == "star" and "-old" or ""
    return C.ELITE_ICON_TEX_BASE .. suffix, C.RARE_ICON_TEX_BASE .. suffix
end

function NP.widgets.SyncEliteIcon(plateData, unit)
    local cfg = NP.config.GetCfg()
    if cfg.showEliteIcon == false then
        if plateData._eliteIcon then plateData._eliteIcon:Hide() end
        return
    end
    -- Quest widget shows kill_elite here; drop the duplicate dragon icon.
    if plateData._questElite then
        if plateData._eliteIcon then plateData._eliteIcon:Hide() end
        return
    end
    NP.native_style.NoteNativePlateClassification(plateData)
    if not unit or not UnitExists(unit) then
        unit = NP.match.ResolvePlateUnit(plateData)
    end
    local classification = NP.native_style.ResolvePlateClassification(plateData, unit)
    if not classification then
        if plateData._eliteIcon then plateData._eliteIcon:Hide() end
        return
    end
    local hp = plateData.minaHp
    if not plateData._eliteIcon then
        local parent = hp or plateData.visualRoot or plateData.plate
        local icon = parent:CreateTexture(nil, "OVERLAY")
        icon:SetSize(22, 22)
        icon:Hide()
        plateData._eliteIcon = icon
    end
    local icon = plateData._eliteIcon
    local eliteTex, rareTex = NP.widgets.GetEliteIconTextures()
    icon:SetTexture(classification == "rare" and rareTex or eliteTex)
    if hp then
        if icon.SetParent then
            icon:SetParent(hp)
        end
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", hp, "LEFT", -20, NP.layout.GetNameOverlayIconY())
        icon:Show()
    end
end

local function EnsureEliteIcon(plateData)
    if plateData._eliteIcon then return plateData._eliteIcon end
    local parent = plateData.minaHp or plateData.visualRoot or plateData.plate
    if not parent then return nil end
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(22, 22)
    icon:Hide()
    plateData._eliteIcon = icon
    return icon
end

local function LayoutEliteIcon(plateData)
    local icon = plateData and plateData._eliteIcon
    local hp = plateData and plateData.minaHp
    if not icon or not hp then return false end
    if icon.SetParent then
        icon:SetParent(hp)
    end
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", hp, "LEFT", -20, NP.layout.GetNameOverlayIconY())
    return true
end

NP.widgets.Register("Elite", {
    Ensure = function(plateData)
        return EnsureEliteIcon(plateData) ~= nil
    end,
    Layout = function(plateData)
        return LayoutEliteIcon(plateData)
    end,
    Sync = function(plateData, context)
        NP.widgets.SyncEliteIcon(plateData, context and context.resolvedUnit or nil)
    end,
    Hide = function(plateData)
        if plateData and plateData._eliteIcon then
            plateData._eliteIcon:Hide()
        end
    end,
})
