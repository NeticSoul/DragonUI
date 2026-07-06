local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates combo points widget.

function NP.widgets.GetPlayerComboPoints()
    if not UnitExists("target") then return 0 end
    return GetComboPoints("player") or 0
end

function NP.widgets.UpdateComboTargetPlate()
    if not UnitExists("target") then
        NP.module.comboTargetPlate = nil
        return
    end
    -- Keyed by target GUID; survives plate hide/show. Both callers run right
    -- after UpdateTargetContext in the same tick, which already tried the
    -- unique-plate scan — GetTargetPlate() is that scan's cached result.
    local plate = NP.identity.GetTargetPlate()
    if not plate then
        local targetGUID = UnitGUID("target")
        if targetGUID then
            plate = NP.state.GUIDToPlate[targetGUID]
        end
    end
    NP.module.comboTargetPlate = plate
end

function NP.widgets.IsPlateComboTarget(plateData)
    if not plateData or not UnitExists("target") then
        return false
    end
    if NP.identity.PlateHasUniqueUnitMatch(plateData, "target") then
        return true
    end
    local targetGUID = UnitGUID("target")
    if targetGUID then
        local plateGUID = NP.state.GetPlateGUID(plateData)
        if plateGUID and plateGUID == targetGUID then
            return true
        end
    end
    return NP.module.comboTargetPlate ~= nil
        and plateData == NP.module.comboTargetPlate
end

function NP.widgets.EnsureComboWidget(plateData)
    if plateData._comboHost then return plateData._comboHost end
    local plate = plateData.plate
    if not plate then return nil end
    local host = CreateFrame("Frame", nil, plate)
    host:SetSize(C.COMBO_ICON_W, C.COMBO_ICON_H)
    host:Hide()
    local tex = host:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(host)
    if tex.SetHorizTile then tex:SetHorizTile(false) end
    if tex.SetVertTile then tex:SetVertTile(false) end
    host.icon = tex
    plateData._comboHost = host
    plateData._comboIcon = tex
    -- New level-managed frame; force the next depth pass to re-level this plate.
    plateData._depthDirty = true
    return host
end

function NP.widgets.LayoutComboWidget(plateData)
    local host = plateData._comboHost
    local hp = plateData.minaHp
    local plate = plateData.plate
    if not host or not hp or not plate then return false end
    -- Frame level owned by layout depth sort.
    host:SetSize(C.COMBO_ICON_W, C.COMBO_ICON_H)
    host:ClearAllPoints()
    host:SetPoint("BOTTOM", hp, "TOP", 0, 3)
    return true
end

function NP.widgets.SyncComboPoints(plateData)
    local cfg = NP.config.GetCfg()
    local host = plateData._comboHost
    if cfg.showComboPoints == false then
        if host then host:Hide() end
        if NP.widgets and NP.widgets.ReflowTopOverlays then
            NP.widgets.ReflowTopOverlays(plateData)
        end
        return
    end
    if not NP.widgets.IsPlateComboTarget(plateData) then
        if host then host:Hide() end
        if NP.widgets and NP.widgets.ReflowTopOverlays then
            NP.widgets.ReflowTopOverlays(plateData)
        end
        return
    end
    local points = NP.widgets.GetPlayerComboPoints()
    if points <= 0 or points > 5 then
        if host then host:Hide() end
        if NP.widgets and NP.widgets.ReflowTopOverlays then
            NP.widgets.ReflowTopOverlays(plateData)
        end
        return
    end
    host = NP.widgets.EnsureComboWidget(plateData)
    if not host or not NP.widgets.LayoutComboWidget(plateData) then
        if host then host:Hide() end
        return
    end
    host.icon:SetTexture(C.COMBO_TEX .. points)
    host:Show()
    if NP.widgets and NP.widgets.ReflowTopOverlays then
        NP.widgets.ReflowTopOverlays(plateData)
    end
end

function NP.widgets.RefreshAllComboPoints()
    NP.widgets.UpdateComboTargetPlate()
    local targetPlate = NP.module.comboTargetPlate
    for _, plateData in pairs(NP.module.plates) do
        if plateData ~= targetPlate then
            local host = plateData._comboHost
            if host then host:Hide() end
        else
            NP.widgets.SyncComboPoints(plateData)
        end
    end
end

NP.widgets.Register("Combo", {
    Ensure = function(plateData)
        return NP.widgets.EnsureComboWidget(plateData) ~= nil
    end,
    Layout = function(plateData)
        return NP.widgets.LayoutComboWidget(plateData)
    end,
    Sync = function(plateData)
        NP.widgets.SyncComboPoints(plateData)
    end,
    Hide = function(plateData)
        local host = plateData and plateData._comboHost
        if host then
            host:Hide()
        end
    end,
})
