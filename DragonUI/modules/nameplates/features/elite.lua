local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates elite/rare icon.

local LEGACY_ICON_SIZE = 22
local LEGACY_ICON_X = -20

-- Retail derives both the bar height and the classification size from the same bucket
-- multiplier (healthBarHeight = 20 * vertical, classification = 20 * classification, and the
-- two columns are equal in every row of NAMEPLATE_SCALES), so the icon is bar-height square.
local RETAIL_BASE = 20

local function ClassificationScale()
    local _, barH = NP.config.GetBarRefSize()
    return barH / RETAIL_BASE
end

function NP.widgets.GetEliteIconTextures()
    local suffix = NP.config.GetCfg().eliteIconStyle == "star" and "-old" or ""
    return C.ELITE_ICON_TEX_BASE .. suffix, C.RARE_ICON_TEX_BASE .. suffix
end

local function EnsureEliteIcon(plateData)
    if plateData._eliteIcon then return plateData._eliteIcon end
    local parent = plateData.minaHp or plateData.visualRoot or plateData.plate
    if not parent then return nil end
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(LEGACY_ICON_SIZE, LEGACY_ICON_SIZE)
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
    if NP.config.IsRetailSkin() then
        local cs = ClassificationScale()
        local gap = math.max(2, math.floor(4 * cs + 0.5))
        -- Retail's own is 20*cs, bar-height square; 22 is DragonUI's and reads better at our sizes.
        icon:SetSize(LEGACY_ICON_SIZE, LEGACY_ICON_SIZE)
        icon:SetPoint("RIGHT", hp, "LEFT", -gap, NP.config.GetCfg().eliteIconOffsetY or 0)
    else
        icon:SetSize(LEGACY_ICON_SIZE, LEGACY_ICON_SIZE)
        icon:SetPoint("LEFT", hp, "LEFT", LEGACY_ICON_X, NP.layout.GetNameOverlayIconY())
    end
    return true
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
    local retail = NP.config.IsRetailSkin()
    -- Retail gives no dragon to friendly elites (city guards); only gate when we know the unit.
    if retail and unit and UnitExists(unit) and UnitCanAttack and not UnitCanAttack("player", unit) then
        if plateData._eliteIcon then plateData._eliteIcon:Hide() end
        return
    end
    local icon = EnsureEliteIcon(plateData)
    if not icon then return end
    -- Retail's sheet is DXT5 and bands the gold; same dragon, so take the uncompressed file.
    local eliteTex, rareTex = NP.widgets.GetEliteIconTextures()
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetTexture(classification == "rare" and rareTex or eliteTex)
    if LayoutEliteIcon(plateData) then
        icon:Show()
    end
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
