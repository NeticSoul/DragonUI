-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates clickbox sizing and debug overlay.

NP.clickbox = NP.clickbox or {}

-- Above Blizzard's highest pushable (7), so the trigger panel never displaces an open window.
local TRIGGER_PUSHABLE = 8
local SECURE_RETRY_INTERVAL = 0.5
local SIZE_TOLERANCE = 0.5

-- Plates the client creates mid-combat come up at native size; only those are touched.
local RESIZE_SNIPPET = [[
    local world = self:GetFrameRef("world")
    local nativeW, nativeH = self:GetAttribute("nativew"), self:GetAttribute("nativeh")
    local width, height = self:GetAttribute("width"), self:GetAttribute("height")
    if not (world and nativeW and nativeH and width and height) then
        return
    end
    local children = newtable(world:GetChildren())
    for i = 1, #children do
        local plate = children[i]
        if plate:IsShown() and abs(plate:GetWidth() - nativeW) < 0.5
            and abs(plate:GetHeight() - nativeH) < 0.5 then
            plate:SetWidth(width)
            plate:SetHeight(height)
        end
    end
]]

local secureTrigger
local secureArmed = false

local function EnsureSecureTrigger()
    if secureTrigger or InCombatLockdown() then
        return secureTrigger
    end
    -- No parent: a UIParent child would not fire OnShow while the UI is hidden (Alt+Z).
    local trigger = CreateFrame("Frame", nil, nil, "SecureHandlerShowHideTemplate")
    trigger:SetSize(1, 1)
    trigger:Hide()
    trigger:SetAttribute("UIPanelLayout-defined", true)
    trigger:SetAttribute("UIPanelLayout-enabled", true)
    trigger:SetAttribute("UIPanelLayout-area", "left")
    trigger:SetAttribute("UIPanelLayout-pushable", TRIGGER_PUSHABLE)
    trigger:SetAttribute("UIPanelLayout-whileDead", 1)
    SecureHandlerSetFrameRef(trigger, "world", WorldFrame)
    trigger:SetAttribute("_onshow", RESIZE_SNIPPET)
    secureTrigger = trigger
    return trigger
end

local function IsAtNativeSize(plate)
    local nativeW, nativeH = NP.module._clickboxNativeW, NP.module._clickboxNativeH
    if not (nativeW and nativeH and plate and plate.GetSize) then
        return false
    end
    local w, h = plate:GetSize()
    return math.abs(w - nativeW) < SIZE_TOLERANCE and math.abs(h - nativeH) < SIZE_TOLERANCE
end

-- Insecure code cannot Show a protected frame in combat; ShowUIPanel hands it to Blizzard's secure delegate.
local function FireSecureResize()
    local trigger = secureTrigger
    if not (secureArmed and trigger) or trigger:IsShown() then
        return false
    end
    -- A right panel means three are open, where showing another would close the left one.
    if GetUIPanel("fullscreen") or GetUIPanel("right") then
        return false
    end
    ShowUIPanel(trigger)
    if not trigger:IsShown() then
        return false
    end
    HideUIPanel(trigger)
    return true
end

local function RequestSecureResize(plateData)
    local plate = plateData and plateData.plate
    if not (secureArmed and plate and IsAtNativeSize(plate)) then
        return
    end
    -- Capture before the snippet resizes it, or visualRoot would be built from the scaled size.
    NP.clickbox.CaptureBaseSize(plateData)
    if not FireSecureResize() or IsAtNativeSize(plate) then
        NP.module._clickboxSecureRetryAt = GetTime() + SECURE_RETRY_INTERVAL
    end
end

local function ApplyClickboxForCombatPlate(plateData)
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

function NP.clickbox.InitSecureSystem()
    return NP.clickbox.UpdateSecureAttributes()
end

function NP.clickbox.OnCombatStart()
    -- Existing geometry remains valid; changes are deferred until combat ends.
end

function NP.clickbox.OnPlateHidden(_plateData)
end

function NP.clickbox.CaptureBaseSize(plateData)
    local plate = plateData and plateData.plate
    if not plate then
        return
    end

    local w, h = plate._dragonUIClickboxNativeW, plate._dragonUIClickboxNativeH
    if not (w and h) then
        -- The combat snippet resizes plates without setting _dragonUIClickboxSized.
        w, h = NP.module._clickboxNativeW, NP.module._clickboxNativeH
        if not (w and h) and not plate._dragonUIClickboxSized and plate.GetSize then
            w, h = plate:GetSize()
        end
        if not (w and w > 0 and h and h > 0) then
            return
        end
        -- Blizzard recycles plate frames, so GetSize() on one we already sized reads back scaled.
        plate._dragonUIClickboxNativeW = w
        plate._dragonUIClickboxNativeH = h
    end

    plateData._clickboxBaseW = w
    plateData._clickboxBaseH = h
    if not NP.module._clickboxNativeW then
        NP.module._clickboxNativeW = w
    end
    if not NP.module._clickboxNativeH then
        NP.module._clickboxNativeH = h
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
    local trigger = EnsureSecureTrigger()
    local nativeW, nativeH = NP.module._clickboxNativeW, NP.module._clickboxNativeH
    local width, height
    if nativeW and nativeH then
        local cfg = NP.config.GetCfg()
        width = nativeW * (cfg.clickboxWidthFactor or 1)
        height = nativeH * (cfg.clickboxHeightFactor or 1)
        if math.abs(width - nativeW) < SIZE_TOLERANCE and math.abs(height - nativeH) < SIZE_TOLERANCE then
            width, height = nil, nil
        end
    end
    secureArmed = width ~= nil
    if trigger:GetAttribute("width") ~= width or trigger:GetAttribute("height") ~= height
        or trigger:GetAttribute("nativew") ~= nativeW or trigger:GetAttribute("nativeh") ~= nativeH then
        trigger:SetAttribute("nativew", nativeW)
        trigger:SetAttribute("nativeh", nativeH)
        trigger:SetAttribute("width", width)
        trigger:SetAttribute("height", height)
    end
    return true
end

function NP.clickbox.TickSecureResize()
    local retryAt = NP.module._clickboxSecureRetryAt
    if not retryAt or GetTime() < retryAt then
        return
    end
    NP.module._clickboxSecureRetryAt = nil
    if not InCombatLockdown() then
        return
    end
    for _, plateData in pairs(NP.module.plates) do
        local plate = plateData.plate
        if plate and plate:IsShown() and IsAtNativeSize(plate) then
            RequestSecureResize(plateData)
            return
        end
    end
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

    -- The only-target gate owns a shrunk plate's size until it lets the plate back.
    if plate._duiOnlyTargetShrunk then
        plateData._clickAreaPending = nil
        return true
    end

    if plate.SetSize then
        local w, h = NP.clickbox.GetClickboxSize(plateData)
        plate:SetSize(w, h)
        plate._dragonUIClickboxSized = true
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
    NP.module._clickboxSecureRetryAt = nil
    if secureTrigger and secureTrigger:IsShown() then
        HideUIPanel(secureTrigger)
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
        RequestSecureResize(plateData)
    end
    NP.clickbox.SyncOverlay(plateData)
end

function NP.clickbox.RefreshAll()
    NP.clickbox.UpdateSecureAttributes()
    for _, plateData in pairs(NP.module.plates) do
        NP.clickbox.ApplyPlateClickbox(plateData)
    end
end

function NP.clickbox.RestorePlate(plateData)
    local plate = plateData and plateData.plate
    if not plate or InCombatLockdown() then
        return false
    end
    plate._duiOnlyTargetShrunk = nil
    local width = NP.module._clickboxNativeW or plate._dragonUIClickboxNativeW or plateData._clickboxBaseW
    local height = NP.module._clickboxNativeH or plate._dragonUIClickboxNativeH or plateData._clickboxBaseH
    if width and height and plate.SetSize then
        plate:SetSize(width, height)
        plate._dragonUIClickboxSized = nil
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
