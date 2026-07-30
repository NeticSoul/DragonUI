local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

-- Nameplates raid marker layout.

local function IsComboVisible(plateData)
    local host = plateData and plateData._comboHost
    return host and host.IsShown and host:IsShown() or false
end

-- On the region, not plateData: plateData is rebuilt on re-apply.
local function RememberNativeRaidIconAnchor(native)
    if native._duiOrigPoints then
        return
    end
    local points = {}
    for i = 1, (native.GetNumPoints and native:GetNumPoints()) or 0 do
        points[i] = { native:GetPoint(i) }
    end
    native._duiOrigPoints = points
    native._duiOrigParent = native.GetParent and native:GetParent() or nil
    local w, h = native:GetWidth(), native:GetHeight()
    if w and w > 0.01 and h and h > 0.01 then
        native._duiOrigW, native._duiOrigH = w, h
    end
end

-- Undo ReflowTopOverlays reparent/alpha; Blizzard chrome has no other restore path.
function NP.widgets.RestoreNativeRaidIcon(plateData)
    local native = plateData and plateData.raidIcon
    if not native then
        return
    end
    if native._duiOrigParent and native.SetParent then
        native:SetParent(native._duiOrigParent)
    end
    local points = native._duiOrigPoints
    if points and #points > 0 then
        native:ClearAllPoints()
        for i = 1, #points do
            native:SetPoint(unpack(points[i], 1, 5))
        end
    end
    if native._duiOrigW and native._duiOrigH then
        native:SetSize(native._duiOrigW, native._duiOrigH)
    end
    if native.SetAlpha then
        native:SetAlpha(1)
    end
end

function NP.widgets.ReflowTopOverlays(plateData)
    if not plateData then return end

    local cfg = NP.config.GetCfg()
    local comboVisible = IsComboVisible(plateData)

    local debuffHost = plateData.minaDebuffHost
    if debuffHost and plateData.minaNameRow then
        local debuffY = C.DEBUFF_HOST_OFFSET_Y or 3
        if comboVisible then
            debuffY = C.DEBUFF_HOST_OFFSET_Y_WITH_COMBO or 15
        end
        debuffHost:ClearAllPoints()
        debuffHost:SetPoint("BOTTOMLEFT", plateData.minaNameRow, "TOPLEFT",
            cfg.debuffOffsetX or 0, debuffY + (cfg.debuffOffsetY or 0))
    end

    local native = plateData.raidIcon
    local hp = plateData.minaHp
    if native and hp then
        -- Reparent to hp for depth ordering with visual stack. In headline mode
        -- hp itself is hidden (SyncHealth), which would hide the marker too
        -- since it inherits its parent's visibility — keep it on visualRoot
        -- instead, which is never hidden, while still anchoring to hp's position.
        local headline = NP.gather.IsHeadlineActive and NP.gather.IsHeadlineActive(plateData)
        RememberNativeRaidIconAnchor(native)
        if native.SetParent then
            native:SetParent((headline and plateData.visualRoot) or hp)
        end
        local reaction = select(1, NP.native_style.GetPlateReaction(plateData))
        local isFriendly = (reaction == "FRIENDLY")
        local markerX = C.RAID_MARKER_OFFSET_X or 0
        local markerY = C.RAID_MARKER_OFFSET_Y

        -- Override: beside bar on all plates. Else hostile+debuffs. Else Y adjusts for combo.
        if cfg.raidMarkerDebuffLayout or ((not isFriendly) and cfg.showDebuffs) then
            local barW = (hp.GetWidth and hp:GetWidth()) or select(1, NP.config.GetBarRefSize())
            local markerSize = C.RAID_MARKER_SIZE or 24
            local sideGap = C.RAID_MARKER_SIDE_GAP or 8
            -- CENTER-anchored bar; offset from TOP-center.
            markerX = (barW * 0.5) + (markerSize * 0.5) + sideGap
            markerY = C.RAID_MARKER_OFFSET_Y_WITH_DEBUFFS or 0
        elseif comboVisible then
            markerY = C.RAID_MARKER_OFFSET_Y_WITH_COMBO
        end
        native:ClearAllPoints()
        native:SetPoint("TOP", hp, "TOP", markerX, markerY)
        native:SetSize(C.RAID_MARKER_SIZE, C.RAID_MARKER_SIZE)
    end
end

function NP.widgets.LayoutRaidMarker(plateData)
    local native = plateData.raidIcon
    local hp = plateData.minaHp
    if not native or not hp then return false end
    NP.widgets.ReflowTopOverlays(plateData)
    return true
end

function NP.widgets.SyncRaidMarker(plateData)
    local cfg = NP.config.GetCfg()
    local native = plateData.raidIcon
    if not native then return end
    if cfg.showRaidMarkers == false then
        if native.SetAlpha then native:SetAlpha(0) end
        return
    end
    -- Layout already reflowed via widgets.Sync; alpha/Show only here.
    if native.IsShown and native:IsShown() then
        if native.SetAlpha then native:SetAlpha(1) end
        native:Show()
    elseif native.SetAlpha then
        native:SetAlpha(0)
    end
end

NP.widgets.Register("RaidMarker", {
    Ensure = function(plateData)
        return plateData and plateData.raidIcon ~= nil
    end,
    Layout = function(plateData)
        return NP.widgets.LayoutRaidMarker(plateData)
    end,
    Sync = function(plateData)
        NP.widgets.SyncRaidMarker(plateData)
    end,
    Hide = function(plateData)
        local native = plateData and plateData.raidIcon
        if not native then return end
        -- Alpha 0 only; :Hide() breaks persistence on camera rotate.
        if native.SetAlpha then
            native:SetAlpha(0)
        end
    end,
})
