local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates clickbox sizing and debug overlay.

NP.clickbox = NP.clickbox or {}

local function ApplyClickboxForCombatPlate(plateData)
    -- Never enumerate or resize arbitrary protected WorldFrame children from a
    -- secure snippet. Keep the current clickbox stable during combat and apply
    -- the requested geometry to registered plates on PLAYER_REGEN_ENABLED.
    if plateData then
        plateData._clickAreaPending = true
    end
    NP.module._clickboxSecurePending = true
    NP.module._layoutPending = true
    return false
end

local function ApplyOverlayGeometry(plateData)
    local overlay = plateData.clickboxOverlay
    if not overlay then
        return
    end
    local plate = plateData.plate
    if not plate then
        return
    end

    overlay:ClearAllPoints()
    overlay:SetAllPoints(plate)
end

function NP.clickbox.InitSecureSystem(syncAttributes)
    return not InCombatLockdown()
end

function NP.clickbox.OnCombatStart()
    -- Existing geometry remains valid; changes are deferred until combat ends.
end

function NP.clickbox.OnPlateHidden(_plateData)
end

function NP.clickbox.CaptureBaseSize(plateData)
    if plateData._clickboxBaseW and plateData._clickboxBaseH then
        return
    end
    local plate = plateData.plate
    if not plate or not plate.GetSize then
        return
    end
    local w, h = plate:GetSize()
    -- Once only: post-Apply GetSize() already includes the clickbox factor.
    if w and w > 0 and h and h > 0 then
        plateData._clickboxBaseW = w
        plateData._clickboxBaseH = h
        if not NP.module._clickboxNativeW then
            NP.module._clickboxNativeW = w
        end
        if not NP.module._clickboxNativeH then
            NP.module._clickboxNativeH = h
        end
    end
end

-- Square clickbox for totem icon-only mode.
function NP.clickbox.GetTotemIconClickboxSize()
    local cfg = NP.config.GetCfg()
    local C = NP.const
    local base = math.max(C.TOTEM_ICON_W or 26, C.TOTEM_ICON_H or 26)
    local pad = tonumber(cfg.totemClickPadding) or 0
    local size = base + pad * 2
    return size, size
end

function NP.clickbox.GetClickboxSize(plateData)
    if NP.gather and NP.gather.IsTotemIconOnlyActive and NP.gather.IsTotemIconOnlyActive(plateData) then
        return NP.clickbox.GetTotemIconClickboxSize()
    end

    local cfg = NP.config.GetCfg()
    NP.clickbox.CaptureBaseSize(plateData)

    local baseW = NP.module._clickboxNativeW or plateData._clickboxBaseW or 120
    local baseH = NP.module._clickboxNativeH or plateData._clickboxBaseH or 20
    local wFactor = cfg.clickboxWidthFactor or 1
    local hFactor = cfg.clickboxHeightFactor or 1

    local w = baseW * wFactor
    local h = baseH * hFactor

    local plateName = plateData and (plateData.plateName
        or (NP.discovery and NP.discovery.GetPlateName(plateData)))
    if plateName and NP.widgets and NP.widgets.IsTotemName(plateName) then
        local pad = tonumber(cfg.totemClickPadding) or 0
        if pad > 0 then
            w = w + pad * 2
            h = h + pad * 2
        end
    end

    return w, h
end

function NP.clickbox.UpdateSecureAttributes()
    if InCombatLockdown() then
        NP.module._clickboxSecurePending = true
        return false
    end
    return true
end

function NP.clickbox.ShouldShowOverlay()
    return NP.config.GetCfg().showClickbox == true
end

function NP.clickbox.EnsureOverlay(plateData)
    if plateData.clickboxOverlay then
        return plateData.clickboxOverlay
    end
    local plate = plateData.plate
    if not plate or not plate.CreateTexture then
        return nil
    end
    -- Host on a child frame, not a plate region: GetRegions() order on the native
    -- plate is read positionally by external plate addons (and our own discovery.lua).
    local host = CreateFrame("Frame", nil, plate)
    host:SetAllPoints(plate)
    local tex = host:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(0.8, 0.1, 0.1, 0.45)
    tex:SetAllPoints(host)
    if tex.SetDrawLayer then
        tex:SetDrawLayer("OVERLAY", 7)
    end
    host:Hide()
    plateData.clickboxOverlay = host
    return host
end

function NP.clickbox.SyncOverlay(plateData)
    local overlay = NP.clickbox.EnsureOverlay(plateData)
    if not overlay then
        return
    end
    if NP.clickbox.ShouldShowOverlay() then
        overlay:Show()
    else
        overlay:Hide()
    end
end

function NP.clickbox.RefreshAllOverlays()
    for _, plateData in pairs(NP.module.plates) do
        NP.clickbox.SyncOverlay(plateData)
    end
end

function NP.clickbox.TickPreview()
    local idleUntil = NP.module._clickboxSliderIdleUntil
    if not idleUntil or GetTime() < idleUntil then
        return
    end
    NP.module._clickboxSliderIdleUntil = nil
    -- Only a Show the sliders switched on may be switched back off; a user-owned Show stays.
    if NP.module._clickboxSliderAutoShow then
        NP.module._clickboxSliderAutoShow = nil
        NP.config.GetCfg().showClickbox = false
        if NP.module._clickboxToggleRefresh then
            NP.module._clickboxToggleRefresh(false)
        end
    end
    NP.clickbox.RefreshAllOverlays()
end

function NP.clickbox.ApplyPlateClickbox(plateData)
    local plate = plateData and plateData.plate
    if not plate then
        return true
    end

    NP.clickbox.EnsureOverlay(plateData)
    ApplyOverlayGeometry(plateData)
    NP.clickbox.SyncOverlay(plateData)

    if InCombatLockdown() then
        plateData._clickAreaPending = true
        NP.module._clickboxSecurePending = true
        NP.module._layoutPending = true
        ApplyClickboxForCombatPlate(plateData)
        return false
    end

    NP.clickbox.CaptureBaseSize(plateData)
    NP.clickbox.UpdateSecureAttributes()

    if plate.SetSize then
        local w, h = NP.clickbox.GetClickboxSize(plateData)
        plate:SetSize(w, h)
    end

    if plate.SetHitRectInsets then
        plate:SetHitRectInsets(0, 0, 0, 0)
    end

    plateData._clickAreaPending = nil
    return true
end

function NP.clickbox.FlushPending()
    if InCombatLockdown() then
        return
    end
    if NP.module._clickboxSecurePending then
        NP.module._clickboxSecurePending = nil
        NP.clickbox.UpdateSecureAttributes()
    end
    for _, plateData in pairs(NP.module.plates) do
        if plateData._clickAreaPending then
            NP.clickbox.ApplyPlateClickbox(plateData)
        end
    end
end

function NP.clickbox.OnPlateShown(plateData)
    if not plateData then
        return
    end
    NP.clickbox.EnsureOverlay(plateData)
    ApplyOverlayGeometry(plateData)
    if InCombatLockdown() then
        plateData._clickAreaPending = true
        NP.module._clickboxSecurePending = true
        ApplyClickboxForCombatPlate(plateData)
    end
    NP.clickbox.SyncOverlay(plateData)
end

function NP.clickbox.RefreshAll()
    for _, plateData in pairs(NP.module.plates) do
        NP.clickbox.ApplyPlateClickbox(plateData)
    end
end

function NP.clickbox.RestorePlate(plateData)
    local plate = plateData and plateData.plate
    if not plate or InCombatLockdown() then
        return false
    end
    local width = NP.module._clickboxNativeW or plateData._clickboxBaseW
    local height = NP.module._clickboxNativeH or plateData._clickboxBaseH
    if width and height and plate.SetSize then
        plate:SetSize(width, height)
    end
    if plate.SetHitRectInsets then
        plate:SetHitRectInsets(0, 0, 0, 0)
    end
    return true
end

function NP.clickbox.ResetPlate(plateData)
    if not plateData then
        return
    end
    plateData._clickAreaPending = nil
    if plateData.clickboxOverlay then
        plateData.clickboxOverlay:Hide()
    end
end
