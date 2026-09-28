local addon = select(2, ...)
local config = addon.config
local _G, ipairs, UIParent = _G, ipairs, UIParent
local InCombatLockdown, UnitVehicleSkin = InCombatLockdown, UnitVehicleSkin
local RegisterStateDriver, UnregisterStateDriver = RegisterStateDriver, UnregisterStateDriver

local VEHICLE_ART = "Interface\\Vehicles\\"
local EXIT_UP = VEHICLE_ART .. "UI-Vehicles-Button-Exit-Up"
local EXIT_DOWN = VEHICLE_ART .. "UI-Vehicles-Button-Exit-Down"
local EXIT_GLOW = VEHICLE_ART .. "UI-Vehicles-Button-Highlight"
local EXIT_CROP = { 0.140625, 0.859375, 0.140625, 0.859375 }
local GLOW_CROP = { 0.130625, 0.879375, 0.130625, 0.879375 }

local function CropRegion(region, box)
    region:SetTexCoord(box[1], box[2], box[3], box[4])
end

local function DressButtonFace(button, face, file, box, blend)
    button["Set" .. face .. "Texture"](button, file)
    local art = button["Get" .. face .. "Texture"](button)
    if not art then return end
    CropRegion(art, box)
    if blend then art:SetBlendMode(blend) end
end

-- ============================================================================
-- VEHICLE MODULE FOR DRAGONUI
-- ============================================================================
-- noop.lua kills VehicleMenuBar; secure _onstate-* drivers toggle our bar, so it works in combat.
-- ============================================================================

-- Module state tracking
local VehicleModule = {
    initialized = false,
    applied = false,
    pendingApply = false,
    firstEnteringWorld = true,
    slideNeedsSnap = false,
    stateDrivers = {},
    events = {},
    hooks = {},
    frames = {}
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("vehicle", VehicleModule,
        addon.L["Vehicle"],
        addon.L["Vehicle interface enhancements"])
end

-- Frame variables
local pUiMainBar = nil
local vehicleBarBackground = nil
local vehiclebar = nil
local vehicleExitButton = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function IsModuleEnabled()
    return addon:IsModuleEnabled("vehicle")
end

local function IsMainbarsModuleEnabled()
    local cfg = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.mainbars
    return cfg and cfg.enabled
end

local function CheckDependencies()
    if not IsMainbarsModuleEnabled() then
        return false
    end
    local mainBar = addon.pUiMainBar or _G.pUiMainBar
    if not mainBar then
        return false
    end
    return true
end

-- Slide transition: Blizzard's MainMenuBar feel (0.30s / 130px), driven locally. FrameXML's SetUpAnimation
-- stamps its start from a shared clock, and the inflated `elapsed` of the first post-reload tick consumes the
-- whole slide at once; taking t0 from the first tick we actually receive avoids that entirely.

local SLIDE_TIME = 0.30
local SLIDE_GONEYPOS = 130
local slideDriver = CreateFrame('Frame')
local slideReverse, slideStart

local function VehicleSlide_SetAnchor(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return end
    if not point then
        point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if not point then return end
    end
    frame.dragonSlideAnchor = {
        point,
        relativeTo or frame:GetParent() or UIParent,
        relativePoint or point,
        x or 0,
        y or 0
    }
end

local function VehicleSlide_QueueSnap()
    VehicleModule.slideNeedsSnap = true
    if addon.CombatQueue then
        addon.CombatQueue:Add('vehicle_slide_snap', function()
            if not VehicleModule.slideNeedsSnap then return end
            VehicleModule.slideNeedsSnap = false
            if VehicleModule.SlideSnapAll then VehicleModule.SlideSnapAll() end
        end)
    end
end

-- fraction 0 = configured resting anchor, fraction 1 = fully off screen below
local function VehicleSlide_Place(frame, fraction)
    if not frame then return end
    if not frame.dragonSlideAnchor then VehicleSlide_SetAnchor(frame) end
    local a = frame.dragonSlideAnchor
    if not a then return end
    frame:SetPoint(a[1], a[2], a[3], a[4], a[5] + (sin(fraction * 90 + 90) - 1) * SLIDE_GONEYPOS)
end

-- Returns false when combat blocks the move; these frames are secure so SetPoint is protected.
local function VehicleSlide_PlaceAll(fraction)
    if InCombatLockdown() then
        VehicleModule.slideNeedsSnap = true
        return false
    end
    VehicleSlide_Place(vehicleBarBackground, fraction)
    VehicleSlide_Place(vehicleExitButton, fraction)
    return true
end

local function VehicleSlide_Stop()
    slideStart = nil
    slideDriver:SetScript('OnUpdate', nil)
end

local function VehicleSlide_SnapAll()
    VehicleSlide_Stop()
    if not VehicleSlide_PlaceAll(0) then VehicleSlide_QueueSnap() end
end
VehicleModule.SlideSnapAll = VehicleSlide_SnapAll

local function VehicleSlide_OnUpdate()
    local now = GetTime()
    if not slideStart then slideStart = now end
    local fraction = (now - slideStart) / SLIDE_TIME
    if fraction >= 1 then
        VehicleSlide_Stop()
        -- A finished slide always rests at the configured anchor, even the outbound one (hidden by then).
        if not VehicleSlide_PlaceAll(0) then VehicleSlide_QueueSnap() end
            return
    end
    if not VehicleSlide_PlaceAll(slideReverse and (1 - fraction) or fraction) then VehicleSlide_Stop() end
end

local function VehicleSlide_Start(reverse)
    if not VehicleModule.applied then return end
    VehicleSlide_Stop()
    slideReverse = reverse
    if not VehicleSlide_PlaceAll(reverse and 1 or 0) then
        VehicleSlide_QueueSnap()
        return
    end
    slideDriver:SetScript('OnUpdate', VehicleSlide_OnUpdate)
end

local function VehicleSlide_IsAnimating()
    return slideDriver:GetScript('OnUpdate') ~= nil
end

local slideFrame = CreateFrame('Frame')
VehicleModule.slideFrame = slideFrame
slideFrame:RegisterEvent('UNIT_ENTERING_VEHICLE')
slideFrame:RegisterEvent('UNIT_ENTERED_VEHICLE')
slideFrame:RegisterEvent('UNIT_EXITING_VEHICLE')
slideFrame:RegisterEvent('UNIT_EXITED_VEHICLE')
slideFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
slideFrame:SetScript('OnEvent', function(_, event, unit)
    if event == 'PLAYER_REGEN_ENABLED' then
        if VehicleModule.slideNeedsSnap then
            VehicleModule.slideNeedsSnap = false
            VehicleSlide_SnapAll()
        end
        return
    end
    if unit ~= 'player' then return end
    -- Only the art bar slides; with artstyle off the lone exit button popping in is the stock look.
    if not VehicleModule.applied or not config.additional.vehicle.artstyle then
        VehicleSlide_SnapAll()
        return
    end
    -- ENTERING/EXITING fire before [vehicleui] flips, so the start position lands before the driver Shows
    if event == 'UNIT_ENTERING_VEHICLE' then
        -- Skin the art before the slide, or the decorations pop in only once the buttons have arrived
        if VehicleModule.ApplyArtLayout and not InCombatLockdown() then
            pcall(VehicleModule.ApplyArtLayout)
        end
        VehicleSlide_Start(true)
    elseif event == 'UNIT_EXITING_VEHICLE' then
        VehicleSlide_Start(false)
    elseif not VehicleSlide_IsAnimating() then
        VehicleSlide_SnapAll()
    end
end)

-- ============================================================================
-- VEHICLE EXIT BUTTON (always created — standalone leave vehicle button)
-- Independent positioning via widgets.vehicleExit (BOTTOM anchor).
-- Supports dual-bar offset when XP+Rep are both visible.
-- ============================================================================

-- Helper: read vehicle exit widget position from DB
local function GetVehicleExitWidgetConfig()
    return addon.db and addon.db.profile and addon.db.profile.widgets
           and addon.db.profile.widgets.vehicleExit
end

-- Helper: position vehicle exit button using widgets.vehicleExit config
local function PositionVehicleExitButton()
    if not vehicleExitButton then return end
    -- Vehicle exit button is a secure frame — cannot reposition during combat
    if InCombatLockdown() then return end
    local cfg = GetVehicleExitWidgetConfig()
    if not cfg or not cfg.anchor then return end

    -- Dual-bar offset (only when at default position)
    local extraY = 0
    if addon.IsWidgetAtDefaultPosition and addon.GetDualBarVerticalOffset then
        if addon.IsWidgetAtDefaultPosition("vehicleExit") then
            extraY = addon.GetDualBarVerticalOffset()
        end
    end

    vehicleExitButton:ClearAllPoints()
    vehicleExitButton:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY + extraY)
    VehicleSlide_SetAnchor(vehicleExitButton, cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY + extraY)
end

local function CreateVehicleExitButton()
    if vehicleExitButton then return end

    vehicleExitButton = CreateFrame(
        'CheckButton',
        'DragonUI_VehicleExitButton',
        UIParent,
        'SecureHandlerClickTemplate,SecureHandlerStateTemplate'
    )

    local btnsize = config.additional.size or 30
    vehicleExitButton:SetSize(btnsize, btnsize)

    -- Position from widgets DB (independent, BOTTOM-anchored)
    PositionVehicleExitButton()

    DressButtonFace(vehicleExitButton, "Normal", EXIT_UP, EXIT_CROP)
    DressButtonFace(vehicleExitButton, "Pushed", EXIT_DOWN, EXIT_CROP)
    DressButtonFace(vehicleExitButton, "Highlight", EXIT_GLOW, GLOW_CROP, "ADD")

    if not vehicleExitButton.background then
        local rings = {
            { key = "background", sub = -1, pad = 3, atlas = "ui-hud-actionbar-iconframe-slot" },
            { key = "shadow", sub = -2, pad = 5, atlas = "ui-hud-actionbar-iconframe-flyoutbordershadow", native = true },
        }
        for _, ring in ipairs(rings) do
            local layer = vehicleExitButton:CreateTexture(nil, "BACKGROUND", nil, ring.sub)
            layer:SetPoint("TOPRIGHT", vehicleExitButton, "TOPRIGHT", ring.pad, ring.pad)
            layer:SetPoint("BOTTOMLEFT", vehicleExitButton, "BOTTOMLEFT", -ring.pad, -ring.pad)
            if layer.set_atlas then
                layer:set_atlas(ring.atlas, ring.native)
            end
            vehicleExitButton[ring.key] = layer
        end
    end

    vehicleExitButton:RegisterForClicks("AnyUp")
    -- OnShow must be set here, before the HookScript below, or replacing it would drop that hook.
    local exitHandlers = {
        OnEnter = function(btn) GameTooltip_AddNewbieTip(btn, LEAVE_VEHICLE, 1, 1, 1) end,
        OnLeave = GameTooltip_Hide,
        OnClick = function(btn)
            VehicleExit()
            btn:SetChecked(true)
        end,
        OnShow = function(btn) btn:SetChecked(false) end,
    }
    for script, handler in pairs(exitHandlers) do
        vehicleExitButton:SetScript(script, handler)
    end

    -- Ensure alpha is always 1 when shown — combat dismount sets alpha=0 as a
    -- visual-only hide fallback; this resets it on any subsequent Show().
    -- Runs in insecure env so SetAlpha works even when Show() comes from a
    -- secure state driver snippet (where SetAlpha is NOT whitelisted).
    vehicleExitButton:HookScript('OnShow', function(self)
        self:SetAlpha(1)
    end)

    vehicleExitButton:Hide()

    -- State driver for visibility is registered separately in ApplyVehicleSystem
    -- so the editor overlay is always available regardless of artstyle setting

    VehicleModule.frames.vehicleExitButton = vehicleExitButton

    -- Create editor overlay for positioning (standard widget system)
    if addon.CreateUIFrame then
        local editorOverlay = addon.CreateUIFrame(btnsize + 10, btnsize + 10, 'VehicleExitOverlay')
        editorOverlay:SetFrameStrata('FULLSCREEN')
        editorOverlay:SetFrameLevel(100)
        editorOverlay:Hide()
        VehicleModule.frames.editorOverlay = editorOverlay

        -- Register with editor mode system (standard widget-based drag)
        if addon.RegisterEditableFrame then
            addon:RegisterEditableFrame({
                name = 'vehicleExit',
                frame = editorOverlay,
                configPath = {'widgets', 'vehicleExit'},

                showTest = function()
                    editorOverlay:SetSize(btnsize + 10, btnsize + 10)
                    editorOverlay:ClearAllPoints()
                    -- Copy vehicleExitButton's UIParent-relative position so that
                    -- SaveUIFramePosition records correct coordinates instead of
                    -- (0,0) relative to the button itself (which caused center drift).
                    local point, _, relPoint, x, y = vehicleExitButton:GetPoint(1)
                    if point then
                        editorOverlay:SetPoint(point, UIParent, relPoint or point, x or 0, y or 0)
                    else
                        editorOverlay:SetPoint('CENTER', vehicleExitButton, 'CENTER', 0, 0)
                    end
                    editorOverlay:Show()
                    if addon.ShowNineslice then
                        addon.SetNinesliceState(editorOverlay, false)
                        addon.ShowNineslice(editorOverlay)
                    end
                    if editorOverlay.editorText then
                        editorOverlay.editorText:Show()
                    end
                end,

                hideTest = function()
                    editorOverlay:Hide()
                    if addon.HideNineslice then
                        addon.HideNineslice(editorOverlay)
                    end
                    if editorOverlay.editorText then
                        editorOverlay.editorText:Hide()
                    end
                    -- Re-apply position (may have been dragged)
                    PositionVehicleExitButton()
                end,

                module = VehicleModule
            })
        end
    end
end

-- ============================================================================
-- CUSTOM VEHICLE ART (artstyle=true only)
-- ============================================================================

local function CreateVehicleArtFrames()
    if vehicleBarBackground then return end

    vehicleBarBackground = CreateFrame(
        'Frame',
        'DragonUI_VehicleBarBackground',
        UIParent,
        'VehicleBarUiTemplate'
    )
    vehicleBarBackground:SetScale(config.mainbars.scale_vehicle or 1)
    vehicleBarBackground:Hide()
    VehicleSlide_SetAnchor(vehicleBarBackground)

    -- vehiclebar: content container (buttons, health, power go here)
    -- Inherits visibility from parent — do NOT explicitly Hide() it
    vehiclebar = CreateFrame(
        'Frame',
        'DragonUI_VehicleBar',
        vehicleBarBackground,
        'SecureHandlerStateTemplate'
    )
    vehiclebar:SetAllPoints(vehicleBarBackground)
    -- vehiclebar is NOT hidden — it inherits visibility from vehicleBarBackground

    VehicleModule.frames.vehicleBarBackground = vehicleBarBackground
    VehicleModule.frames.vehiclebar = vehiclebar
end

-- Shows the handler's parent (the art frame), so the art can appear mid-combat from secure code.
local ART_TOGGLE_SNIPPET = [[
    local art = self:GetParent()
    if newstate == "s1" then art:Show() else art:Hide() end
]]
local MAINBAR_TOGGLE_SNIPPET = [[
    if tonumber(newstate) == 1 then self:Hide() else self:Show() end
]]
local EXIT_TOGGLE_SNIPPET = [[
    if newstate == "s1" then self:Show() else self:Hide() end
]]

local function ArmStateDriver(key, frame, state, snippet, rule)
    frame:SetAttribute("_onstate-" .. state, snippet)
    VehicleModule.stateDrivers[key] = { frame = frame, state = state }
    RegisterStateDriver(frame, state, rule)
end

local function vehiclebutton_state()
    if not vehiclebar then return end
    for slot = 1, VEHICLE_MAX_ACTIONBUTTONS do
        local label = "VehicleMenuBarActionButton" .. slot
        local ref = _G[label]
        if ref then vehiclebar:SetFrameRef(label, ref) end
    end
    ArmStateDriver("vehicleArtVisibility", vehiclebar, "vehicleupdate", ART_TOGGLE_SNIPPET, "[vehicleui] s1; s2")
end

local GEARS_SHEET = addon._dir .. "ActionBars\\mechanical2"
local ENDCAP_SHEET = VEHICLE_ART .. "UI-Vehicles-Endcap"

-- mechanical2 is a 512-px sheet; power-of-two division stays exact at any FPU precision.
local function GearBox(left, right, top, bottom)
    return { left / 512, right / 512, top / 512, bottom / 512 }
end

-- box = { width, height, point, x, y }, anchored to the region's own (possibly new) parent.
local function FitRegion(region, box, parent)
    if parent then region:SetParent(parent) end
    region:SetSize(box[1], box[2])
    region:SetClearPoint(box[3], box[4], box[5])
end

local LEAVE_BOX = { 47, 50, "BOTTOMRIGHT", -178, 14 }
local GLASS_BOX = { 46, 105, "BOTTOMLEFT", -5, -9 }

local GAUGE_BARS = {
    { name = "VehicleMenuBarHealthBar", backing = { 0, 1, 0, 1 } },
    { name = "VehicleMenuBarPowerBar", backing = { 0.5390625, 0.953125, 0, 1 } },
}

local VEHICLE_SKINS = {
    mechanical = {
        show = "MechanicUi", hide = "OrganicUi",
        exitUp = { GEARS_SHEET, GearBox(45, 84, 185, 224) },
        exitDown = { GEARS_SHEET, GearBox(2, 40, 185, 223) },
        bars = {
            VehicleMenuBarHealthBar = { 38, 84, "BOTTOMLEFT", 74, 6 },
            VehicleMenuBarPowerBar = { 38, 84, "BOTTOMRIGHT", -94, 6 },
        },
        backing = { 40, 92, "BOTTOMLEFT", -2, -6 },
        glass = { GEARS_SHEET, GearBox(4, 44, 263, 354) },
        pitch = true,
    },
    organic = {
        show = "OrganicUi", hide = "MechanicUi",
        exitUp = { EXIT_UP, EXIT_CROP },
        exitDown = { EXIT_DOWN, EXIT_CROP },
        bars = {
            VehicleMenuBarHealthBar = { 38, 74, "BOTTOMLEFT", 119, 3 },
            VehicleMenuBarPowerBar = { 38, 74, "BOTTOMRIGHT", -119, 3 },
        },
        backing = { 40, 83, "BOTTOMLEFT", -2, -9 },
        glass = { VEHICLE_ART .. "UI-Vehicles-Endcap-Organic-bottle", { 0.46484375, 0.66015625, 0.0390625, 0.9375 } },
    },
}

local PITCH_WIDGETS = {
    { "VehicleMenuBarPitchUpButton", { 32, 31, "BOTTOMLEFT", 156, 46 }, GearBox(1, 34, 227, 259), GearBox(36, 69, 227, 259) },
    { "VehicleMenuBarPitchDownButton", { 32, 31, "BOTTOMLEFT", 156, 8 }, GearBox(148, 180, 289, 320), GearBox(148, 180, 323, 354) },
    { "VehicleMenuBarPitchSlider", { 20, 82, "BOTTOMLEFT", 124, 2 } },
}

local PITCH_TRACK = {
    { "VehicleMenuBarPitchSliderBG", { 0.46875, 0.50390625, 0.31640625, 0.62109375 }, { 0, 0.85, 0.99 } },
    { "VehicleMenuBarPitchSliderMarker", { 0.46875, 0.50390625, 0.45, 0.55 }, { 1, 0, 0 }, 20 },
}

local function vehiclebar_power_setup()
    if not vehiclebar then return end

    local leave = VehicleMenuBarLeaveButton
    FitRegion(leave, LEAVE_BOX, vehiclebar)
    DressButtonFace(leave, "Highlight", EXIT_GLOW, GLOW_CROP, "ADD")
    -- HookScript only: Blizzard's own OnClick on this button has to keep running.
    if not leave.DragonUIClickHooked then
        leave:HookScript("OnClick", VehicleExit)
        leave.DragonUIClickHooked = true
    end

    local tint = TOOLTIP_DEFAULT_BACKGROUND_COLOR
    for _, gauge in ipairs(GAUGE_BARS) do
        local bar = _G[gauge.name]
        bar:SetParent(vehiclebar)
        FitRegion(_G[gauge.name .. "Overlay"], GLASS_BOX, bar)

        local fill = _G[gauge.name .. "Background"]
        fill:SetParent(bar)
        fill:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        CropRegion(fill, gauge.backing)
        fill:SetVertexColor(tint.r, tint.g, tint.b)
    end
end

local function FitPitchControls(holder)
    for _, entry in ipairs(PITCH_WIDGETS) do
        local control = _G[entry[1]]
        FitRegion(control, entry[2], holder)
        if entry[3] then
            DressButtonFace(control, "Normal", GEARS_SHEET, entry[3])
            DressButtonFace(control, "Pushed", GEARS_SHEET, entry[4])
        end
    end

    local base = _G.DragonUI_VehicleBarBackgroundBACKGROUND1
    if base then base:SetDrawLayer("BACKGROUND", -1) end

    for _, entry in ipairs(PITCH_TRACK) do
        local piece = _G[entry[1]]
        if entry[4] then piece:SetWidth(entry[4]) end
        piece:SetTexture(ENDCAP_SHEET)
        CropRegion(piece, entry[2])
        piece:SetVertexColor(entry[3][1], entry[3][2], entry[3][3])
    end

    -- Deliberately no ClearAllPoints: these points extend the stock anchors, not replace them.
    local frame = _G.VehicleMenuBarPitchSliderOverlayThing
    frame:SetPoint("TOPLEFT", -5, 2)
    frame:SetPoint("BOTTOMRIGHT", 3, -4)
end

-- Touches only insecure widgets, so callers may run it in combat.
local function ApplyVehicleSkin(skin)
    if not vehicleBarBackground then return end
    vehicleBarBackground[skin.hide]:Hide()
    vehicleBarBackground[skin.show]:Show()

    local leave = VehicleMenuBarLeaveButton
    DressButtonFace(leave, "Normal", skin.exitUp[1], skin.exitUp[2])
    DressButtonFace(leave, "Pushed", skin.exitDown[1], skin.exitDown[2])

    for _, gauge in ipairs(GAUGE_BARS) do
        FitRegion(_G[gauge.name], skin.bars[gauge.name])
        FitRegion(_G[gauge.name .. "Background"], skin.backing)

        local glass = _G[gauge.name .. "Overlay"]
        glass:SetTexture(skin.glass[1])
        CropRegion(glass, skin.glass[2])
    end

    if skin.pitch then
        FitPitchControls(vehicleBarBackground[skin.show])
    end
end

-- Only the skin name picks the art; pitch support is no reliable hint of a mechanical vehicle.
local function vehiclebar_layout_setup()
    if UnitVehicleSkin("player") == "Natural" then
        ApplyVehicleSkin(VEHICLE_SKINS.organic)
    else
        ApplyVehicleSkin(VEHICLE_SKINS.mechanical)
    end
end

-- Exposed so the slide handler (declared earlier) can skin the art before the transition starts.
VehicleModule.ApplyArtLayout = vehiclebar_layout_setup

local SLOT_SIZE, SLOT_GAP = 52, 6

local function vehiclebutton_position()
    if not vehiclebar or InCombatLockdown() then return end

    local count = VEHICLE_MAX_ACTIONBUTTONS
    local rowWidth = count * SLOT_SIZE + (count - 1) * SLOT_GAP
    local shift = IsVehicleAimAngleAdjustable() and -20 or -48
    local firstX = shift - rowWidth / 2

    local previous
    for slot = 1, count do
        local action = _G["VehicleMenuBarActionButton" .. slot]
        if action then
            action:ClearAllPoints()
            action:SetParent(vehiclebar)
            action:Show()
            action:SetSize(SLOT_SIZE, SLOT_SIZE)
            if slot == 1 then
                action:SetPoint("BOTTOMLEFT", vehiclebar, "BOTTOM", firstX, 21)
            elseif previous then
                action:SetPoint("LEFT", previous, "RIGHT", SLOT_GAP, 0)
            end
        end
        previous = action
    end
end

-- Hide vehicle buttons that have no action assigned (empty slots).
-- Uses icon:IsShown() to detect empty slots — Blizzard's ActionButton_Update
-- hides the icon widget for buttons without actions, so we piggyback on that.
-- HasAction() / GetActionTexture() don't work reliably for vehicle action
-- slots in WoW 3.3.5a because the internal slot IDs differ from standard bars.
-- Safety: only hides buttons if at least ONE button has a visible icon.
-- If all icons are hidden, Blizzard hasn't populated slot data yet — we skip
-- and let the next timer/event retry.
local function HideEmptyVehicleButtons()
    if not UnitHasVehicleUI('player') then return end

    local inCombat = InCombatLockdown()
    local anyVisible = false
    local emptyButtons = {}

    for index = 1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G['VehicleMenuBarActionButton'..index]
        if button then
            local icon = _G[button:GetName()..'Icon']
            if icon and icon:IsShown() then
                anyVisible = true
                button:SetAlpha(1)
                -- EnableMouse is protected on secure frames — skip in combat
                if not inCombat then
                    button:EnableMouse(true)
                end
            else
                emptyButtons[#emptyButtons + 1] = button
            end
        end
    end

    -- Only hide empty buttons once we've confirmed at least one slot
    -- has an action (icon visible). If ALL icons are hidden, Blizzard
    -- hasn't finished updating yet — skip and wait for the next call.
    if anyVisible then
        for _, button in ipairs(emptyButtons) do
            button:SetAlpha(0)
            if not inCombat then
                button:EnableMouse(false)
            end
        end
    end
end

-- Restore all vehicle buttons to normal state when exiting vehicle
local function RestoreVehicleButtons()
    -- Seat swaps fire EXITED while still mounted; restoring there re-lights the empty slots.
    if UnitHasVehicleUI('player') then return end
    local inCombat = InCombatLockdown()
    for index = 1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G['VehicleMenuBarActionButton'..index]
        if button then
            button:SetAlpha(1)
            -- EnableMouse is protected on secure frames — defer if in combat
            if not inCombat then
                button:EnableMouse(true)
            end
        end
    end
    -- If in combat, schedule EnableMouse restore for after combat ends
    if inCombat then
        local restoreFrame = VehicleModule.frames.restoreMouseFrame
        if not restoreFrame then
            restoreFrame = CreateFrame('Frame')
            VehicleModule.frames.restoreMouseFrame = restoreFrame
        end
        restoreFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
        restoreFrame:SetScript('OnEvent', function(self)
            self:UnregisterEvent('PLAYER_REGEN_ENABLED')
            for i = 1, VEHICLE_MAX_ACTIONBUTTONS do
                local btn = _G['VehicleMenuBarActionButton'..i]
                if btn then btn:EnableMouse(true) end
            end
        end)
    end
end

-- ============================================================================
-- ARTSTYLE EVENT HANDLING
-- ============================================================================

-- Apply full vehicle art layout (called when NOT in combat lockdown)
local function ApplyFullVehicleArtLayout()
    vehiclebar_layout_setup()
    vehiclebutton_position()
    if addon.vehiclebuttons_template then
        addon.vehiclebuttons_template()
    end
    HideEmptyVehicleButtons()
    if VehicleMenuBarHealthBar then
        pcall(UnitFrameHealthBar_Update, VehicleMenuBarHealthBar, 'vehicle')
    end
    if VehicleMenuBarPowerBar then
        pcall(UnitFrameManaBar_Update, VehicleMenuBarPowerBar, 'vehicle')
    end

    -- State drivers are already registered with [vehicleui] conditions
    -- from SetupArtStyleStateDrivers/SetupVehicleBarHiding — they auto-toggle.
    -- No need to re-register them here.

    VehicleModule.pendingCombatVehicleSetup = false
end

local function OnVehicleEvent(self, event, ...)
    local unit = ...
    -- These fire for every unit in range; a stray copy re-runs the player's whole layout.
    if (event == 'UNIT_ENTERED_VEHICLE' or event == 'UNIT_EXITED_VEHICLE') and unit ~= 'player' then
        return
    end
    if event == 'UNIT_ENTERED_VEHICLE' then
        if InCombatLockdown() then
            -- MID-COMBAT VEHICLE ENTRY (e.g., Malygos Phase 3 drakes):
            -- State drivers are already set up with [vehicleui] condition —
            -- they auto-toggle visibility (main bar hides, vehicle art shows).
            -- Vehicle buttons are pre-parented to vehiclebar at init time,
            -- so they become visible when the state driver shows vehicleBarBackground.
            -- RegisterStateDriver is PROTECTED and CANNOT be called in combat.
            -- Full art layout (organic/mechanical textures, health/power bar sizes,
            -- overlay positions, leave button textures) runs here — these operate
            -- on non-secure widgets (StatusBars, Textures) which are combat-safe.
            -- Only secure frame repositioning (vehiclebutton_position) is deferred
            -- to PLAYER_REGEN_ENABLED.
            VehicleModule.pendingCombatVehicleSetup = true
            -- Combat-safe full vehicle art layout: sets bar sizes, positions,
            -- overlay textures, leave button textures AND toggles OrganicUi/MechanicUi.
            -- Without this, vehicleBarBackground appears with wrong/missing decorations.
            pcall(vehiclebar_layout_setup)
            -- Button styling with skipCombatGuard=true: bypasses the
            -- InCombatLockdown + UnitHasVehicleUI guards in buttons.lua.
            -- All operations are texture-level (NormalTexture, atlas, draw layers)
            -- which are combat-safe in 3.3.5a.
            if addon.vehiclebuttons_template then
                pcall(addon.vehiclebuttons_template, true)
            end
            -- Health/power bar updates are safe even in combat
            if VehicleMenuBarHealthBar then
                pcall(UnitFrameHealthBar_Update, VehicleMenuBarHealthBar, 'vehicle')
            end
            if VehicleMenuBarPowerBar then
                pcall(UnitFrameManaBar_Update, VehicleMenuBarPowerBar, 'vehicle')
            end
            -- Schedule empty-button hiding AND button styling retries.
            -- Action data arrives after a short delay; __styled flag prevents
            -- double-styling if the immediate call already succeeded.
            if addon.core and addon.core.ScheduleTimer then
                addon.core:ScheduleTimer(HideEmptyVehicleButtons, 0.3)
                addon.core:ScheduleTimer(HideEmptyVehicleButtons, 0.6)
                addon.core:ScheduleTimer(HideEmptyVehicleButtons, 1.0)
                -- Retry button styling in case buttons weren't ready yet
                local function retryVehicleButtons() addon.vehiclebuttons_template(true) end
                addon.core:ScheduleTimer(retryVehicleButtons, 0.3)
                addon.core:ScheduleTimer(retryVehicleButtons, 0.6)
            end
            return
        end

        vehiclebar_layout_setup()
        vehiclebutton_position()
        if addon.vehiclebuttons_template then
            addon.vehiclebuttons_template()
        end
        UnitFrameHealthBar_Update(VehicleMenuBarHealthBar, 'vehicle')
        UnitFrameManaBar_Update(VehicleMenuBarPowerBar, 'vehicle')
        -- Action data isn't populated when UNIT_ENTERED_VEHICLE fires.
        -- Schedule multiple delayed checks to catch when the data arrives.
        -- ACTIONBAR_UPDATE_STATE / ACTIONBAR_SLOT_CHANGED also trigger this
        -- but timers provide a reliable fallback.
        if addon.core and addon.core.ScheduleTimer then
            addon.core:ScheduleTimer(HideEmptyVehicleButtons, 0.3)
            addon.core:ScheduleTimer(HideEmptyVehicleButtons, 0.6)
            addon.core:ScheduleTimer(HideEmptyVehicleButtons, 1.0)
        end
    elseif event == 'UNIT_EXITED_VEHICLE' then
        RestoreVehicleButtons()
        -- State drivers auto-restore via [vehicleui] condition — no need to
        -- call RegisterStateDriver again. Just clean up the pending flag.
        VehicleModule.pendingCombatVehicleSetup = false
    elseif event == 'ACTIONBAR_UPDATE_STATE' or event == 'ACTIONBAR_SLOT_CHANGED' then
        -- Fires when vehicle action slots are populated/changed.
        if UnitHasVehicleUI('player') then
            HideEmptyVehicleButtons()
        end
    elseif event == 'UNIT_DISPLAYPOWER' then
        UnitFrameManaBar_Update(VehicleMenuBarPowerBar, 'vehicle')
    elseif event == 'PLAYER_REGEN_ENABLED' then
        -- Combat ended: if we deferred vehicle art setup, apply it now
        if VehicleModule.pendingCombatVehicleSetup and UnitHasVehicleUI('player') then
            ApplyFullVehicleArtLayout()
        elseif VehicleModule.pendingCombatVehicleSetup then
            -- Exited vehicle during combat, just clean up the flag
            VehicleModule.pendingCombatVehicleSetup = false
        end
    end
end

-- ============================================================================
-- ARTSTYLE VISIBILITY STATE DRIVERS
-- ============================================================================
-- vehiclebar inherits visibility from vehicleBarBackground (SetAllPoints,
-- NOT explicitly hidden) so buttons parented to it become visible when
-- vehicleBarBackground is shown.

-- ============================================================================
-- BAR HIDING DURING VEHICLE (common to both artstyle modes)
-- ============================================================================
-- Uses SECURE STATE DRIVERS for ALL bars (main + secondary).
-- This is combat-safe and fires immediately on vehicle state change.
-- Previous event-based approach was unreliable because:
--   1) wasShown captured at setup time (not vehicle-entry time)
--   2) Other code could call :Show() overriding event-based :Hide()
--   3) InCombatLockdown() blocked event handler during combat vehicle entry

local function SetupVehicleBarHiding(hideMainBar)
    local mainBar = pUiMainBar or addon.pUiMainBar or _G.pUiMainBar
    if not mainBar then return end

    -- 1) pUiMainBar: hide during vehicle ONLY if artstyle=true.
    --    When artstyle=false, the main bar stays visible because it shows
    --    vehicle abilities via BonusActionBar page switching (bonusbar:5 → page 11).
    --    Uses custom state name 'vehicleupdate' with secure snippet (NOT
    --    'visibility') to avoid conflicts with other state drivers on pUiMainBar.
    if hideMainBar and not VehicleModule.stateDrivers.mainBarVehicle then
        ArmStateDriver("mainBarVehicle", mainBar, "vehicleupdate", MAINBAR_TOGGLE_SNIPPET, "[vehicleui] 1; 2")
    end

    -- 2) Secondary bars: register 'visibility' state driver DIRECTLY on each bar.
    --    The 'visibility' state driver uses Blizzard's C-level enforcement which
    --    blocks :Show() calls when state is 'hide'. This is essential because
    --    Blizzard's MultiActionBar_Update() re-shows bars during loading —
    --    the previous approach (helper hider frame with manual Hide() calls)
    --    could be overridden by those Show() calls.
    --    Skip if already registered (e.g. during combat-safe early setup).
    -- ExtraBar1Container: owned solely by extrabar.lua (SetupExtrabarVehicleVisibility).
    local secondaryBars = {
        {key = 'vehicleHide_bl', bar = MultiBarBottomLeft},
        {key = 'vehicleHide_br', bar = MultiBarBottomRight},
        {key = 'vehicleHide_r',  bar = MultiBarRight},
        {key = 'vehicleHide_l',  bar = MultiBarLeft},
    }
    for _, entry in ipairs(secondaryBars) do
        if entry.bar and not VehicleModule.stateDrivers[entry.key] then
            VehicleModule.stateDrivers[entry.key] = {frame = entry.bar, state = 'visibility'}
            RegisterStateDriver(entry.bar, 'visibility', '[vehicleui] hide; show')
        end
    end

    -- 3) Belt-and-suspenders: hook MultiActionBar_Update to re-hide secondary bars
    --    for non-combat scenarios where the state driver might not catch edge cases.
    if not VehicleModule.hooks.multiActionBarUpdate and MultiActionBar_Update then
        hooksecurefunc('MultiActionBar_Update', function()
            if not UnitHasVehicleUI('player') then return end
            if InCombatLockdown() then return end
            if MultiBarBottomLeft  then MultiBarBottomLeft:Hide()  end
            if MultiBarBottomRight then MultiBarBottomRight:Hide() end
            if MultiBarRight       then MultiBarRight:Hide()       end
            if MultiBarLeft        then MultiBarLeft:Hide()        end
        end)
        VehicleModule.hooks.multiActionBarUpdate = true
    end
end

-- ============================================================================
-- ARTSTYLE VISIBILITY STATE DRIVERS (artstyle=true only)
-- ============================================================================

local function SetupArtStyleStateDrivers()
    if not vehiclebar or not vehicleBarBackground then return end

    -- Show/hide vehicle art via secure snippet on vehiclebar — the child's
    -- _onstate-vehicleupdate snippet calls Show()/Hide() on parent
    -- (vehicleBarBackground). This is combat-safe and avoids 'visibility'
    -- state driver conflicts.
    vehiclebutton_state()
end

-- ============================================================================
-- BONUS BAR PAGE SWITCHING
-- ============================================================================

local function SetupBonusBarVehicle()
    -- Mainbars owns the page driver so bonus/stance bars keep working even
    -- when vehicle module is disabled.
    if addon.SetupMainBarPageDriver then
        addon.SetupMainBarPageDriver(pUiMainBar or addon.pUiMainBar or _G.pUiMainBar)
        return
    end
end

-- ============================================================================
-- APPLY / RESTORE
-- ============================================================================

local function CleanupVehicleFrames()
    local globalFrames = {
        'mixin2template',
        'pUiVehicleBar',
        'vehicleExit',
        'pUiVehicleLeaveButton'
    }
    for _, frameName in ipairs(globalFrames) do
        local frame = _G[frameName]
        if frame and frame.Hide then
            frame:Hide()
            frame:SetParent(nil)
            if frame.UnregisterAllEvents then
                frame:UnregisterAllEvents()
            end
            _G[frameName] = nil
        end
    end
end

local function ApplyVehicleSystem()
    if VehicleModule.applied or not IsModuleEnabled() then return end

    if InCombatLockdown() then
        VehicleModule.pendingApply = true

        -- COMBAT: RegisterStateDriver is PROTECTED — cannot be called here.
        -- Defer all state driver setup to after combat ends (PLAYER_REGEN_ENABLED).
        -- The only safe operations in combat are creating non-secure frames
        -- and hooking functions.

        -- Hook MultiActionBar_Update (safe — just a hooksecurefunc call)
        if not VehicleModule.hooks.multiActionBarUpdate and MultiActionBar_Update then
            hooksecurefunc('MultiActionBar_Update', function()
                if not UnitHasVehicleUI('player') then return end
                if InCombatLockdown() then return end
                if MultiBarBottomLeft  then MultiBarBottomLeft:Hide()  end
                if MultiBarBottomRight then MultiBarBottomRight:Hide() end
                if MultiBarRight       then MultiBarRight:Hide()       end
                if MultiBarLeft        then MultiBarLeft:Hide()        end
            end)
            VehicleModule.hooks.multiActionBarUpdate = true
        end

        -- COMBAT-SAFE EXIT BUTTON: For artstyle=false, we need the exit button
        -- to be visible on reload in combat in a vehicle. Create it during combat
        -- (it's not a secure frame issue), and show it if in a vehicle.
        if UnitHasVehicleUI('player') or CanExitVehicle() then
            local cfg = addon.config
            if cfg and cfg.additional and cfg.additional.vehicle and not cfg.additional.vehicle.artstyle then
                CreateVehicleExitButton()
                if vehicleExitButton then
                    vehicleExitButton:Show()
                end
            end
        end

        if addon.CombatQueue then
            addon.CombatQueue:Add("vehicle_apply", function()
                if IsModuleEnabled() and VehicleModule.pendingApply then
                    ApplyVehicleSystem()
                end
            end)
        end
        -- Fallback: also register on initFrame in case CombatQueue doesn't fire
        if VehicleModule.eventFrame then
            VehicleModule.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end

    if not CheckDependencies() then
        return
    end

    pUiMainBar = addon.pUiMainBar or _G.pUiMainBar
    CleanupVehicleFrames()

    -- 1. Bonus bar page switching (always needed for action page management)
    SetupBonusBarVehicle()

    -- 2. Always create exit button + editor overlay (editor works in both modes)
    CreateVehicleExitButton()

    -- 3. Custom vehicle art OR simple exit button visibility
    if config.additional.vehicle.artstyle then
        -- artstyle=true: full vehicle art overlay + built-in leave button
        -- Exit button stays hidden (art has VehicleMenuBarLeaveButton)
        CreateVehicleArtFrames()
        vehiclebar_power_setup()

        -- Pre-parent now: SetParent/SetPoint on secure frames are blocked in combat, and the [vehicleui]
        -- driver can Show the bar mid-combat (Malygos drakes). The skin is applied on UNIT_ENTERING_VEHICLE.
        vehiclebutton_position()

        -- Pre-style vehicle buttons NOW so they already have Dragonflight
        -- borders when the state driver shows them. Without this, buttons
        -- flash with Blizzard's default large borders for a split second
        -- before UNIT_ENTERED_VEHICLE handler styles them.
        if addon.vehiclebuttons_template then
            addon.vehiclebuttons_template(true)
        end

        -- Register vehicle events for layout and health bar updates
        local artEvents = {
            'UNIT_ENTERED_VEHICLE',
            'UNIT_EXITED_VEHICLE',
            'UNIT_DISPLAYPOWER',
            'ACTIONBAR_UPDATE_STATE',
            'ACTIONBAR_SLOT_CHANGED',
            'PLAYER_REGEN_ENABLED',
        }
        for _, event in ipairs(artEvents) do
            vehiclebar:RegisterEvent(event)
            VehicleModule.events[event] = vehiclebar
        end
        vehiclebar:SetScript('OnEvent', OnVehicleEvent)

        -- State drivers: show art when [vehicleui], hide main bar + all secondary bars
        SetupArtStyleStateDrivers()
        SetupVehicleBarHiding(true)  -- true = hide mainbar (art overlay replaces it)

        -- Standalone exit button for ANY vehicle without full vehicleui.
        -- [target=vehicle,exists] checks UnitExists('vehicle') which is true for ALL
        -- vehicle types: EoE hover disks, multi-seat mounts, bonusbar:5 vehicles.
        -- Hidden when [vehicleui] is active because the art bar has its own leave button.
        -- 3.3.5a state drivers accept [target=vehicle,exists] as a macro condition.
        if vehicleExitButton then
            ArmStateDriver("exitButtonVehicle", vehicleExitButton, "vehicleshow", EXIT_TOGGLE_SNIPPET,
                "[vehicleui] s2; [target=vehicle,exists] s1; s2")
        end

        -- Fallback event handler for edge cases where the 'vehicle' unit token
        -- may not exist yet when UNIT_ENTERED_VEHICLE fires (race condition).
        -- The state driver [target=vehicle,exists] covers most cases; this is
        -- a safety net for out-of-combat transitions.
        if not VehicleModule.hooks.exitButtonVehicleEvents then
            local exitBtnEventFrame = CreateFrame('Frame')
            exitBtnEventFrame:RegisterEvent('UNIT_ENTERED_VEHICLE')
            exitBtnEventFrame:RegisterEvent('UNIT_EXITED_VEHICLE')
            exitBtnEventFrame:SetScript('OnEvent', function(self, event, unit)
                if unit ~= 'player' then return end
                if not vehicleExitButton then return end
                if event == 'UNIT_ENTERED_VEHICLE' then
                    if InCombatLockdown() then return end
                    -- Mount-type vehicles: no [vehicleui] but CanExitVehicle() is true
                    if not UnitHasVehicleUI('player') and CanExitVehicle() then
                        vehicleExitButton:SetAlpha(1)
                        vehicleExitButton:Show()
                    end
                elseif event == 'UNIT_EXITED_VEHICLE' then
                    if not UnitHasVehicleUI('player') and not CanExitVehicle() then
                        if InCombatLockdown() then
                            vehicleExitButton:SetAlpha(0)
                            local restoreFrame = VehicleModule.frames.exitBtnCombatRestore
                            if not restoreFrame then
                                restoreFrame = CreateFrame('Frame')
                                VehicleModule.frames.exitBtnCombatRestore = restoreFrame
                            end
                            restoreFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
                            restoreFrame:SetScript('OnEvent', function(f)
                                f:UnregisterEvent('PLAYER_REGEN_ENABLED')
                                if vehicleExitButton then
                                    vehicleExitButton:Hide()
                                    vehicleExitButton:SetAlpha(1)
                                end
                            end)
                        else
                            vehicleExitButton:Hide()
                        end
                    end
                end
            end)
            VehicleModule.frames.exitBtnEventFrame = exitBtnEventFrame
            VehicleModule.hooks.exitButtonVehicleEvents = true
        end

        -- If player is ALREADY in a vehicle (e.g. after /reload), immediately
        -- apply vehicle layout — UNIT_ENTERED_VEHICLE won't fire again.
        if UnitHasVehicleUI('player') then
            vehiclebar_layout_setup()
            vehiclebutton_position()
            HideEmptyVehicleButtons()  -- Action data is ready on reload
            if addon.vehiclebuttons_template then
                addon.vehiclebuttons_template()
            end
            -- Safe to call only if VehicleMenuBarHealthBar exists (it should in vehicle UI)
            if VehicleMenuBarHealthBar then
                pcall(UnitFrameHealthBar_Update, VehicleMenuBarHealthBar, 'vehicle')
            end
            if VehicleMenuBarPowerBar then
                pcall(UnitFrameManaBar_Update, VehicleMenuBarPowerBar, 'vehicle')
            end
            -- Explicitly hide secondary bars on reload in vehicle.
            -- The state driver fires first, but Blizzard's MultiActionBar_Update()
            -- runs later during loading and re-shows bars based on CVars.
            -- The MultiActionBar_Update hook can't catch it because VehicleModule.applied
            -- isn't true yet at this point. So we hide bars now AND schedule a delayed
            -- re-hide to catch any Blizzard code that runs after ApplyVehicleSystem.
            if not InCombatLockdown() then
                if MultiBarBottomLeft  then MultiBarBottomLeft:Hide()  end
                if MultiBarBottomRight then MultiBarBottomRight:Hide() end
                if MultiBarRight       then MultiBarRight:Hide()       end
                if MultiBarLeft        then MultiBarLeft:Hide()        end
            end
        end
    else
        -- artstyle=false: no vehicle art overlay.
        -- Main bar stays VISIBLE (it shows vehicle abilities via page switching).
        -- Secondary bars also stay VISIBLE (only hidden when artstyle=true).

        -- Exit button visibility: SECURE STATE DRIVER with [target=vehicle,exists].
        -- Covers ALL vehicle types: EoE hover disks, multi-seat mounts, bonusbar:5
        -- vehicles. [target=vehicle,exists] checks UnitExists('vehicle') which is true
        -- whenever the player occupies any vehicle seat.
        -- Combat-safe: secure snippet Show()/Hide() execute in restricted env (MCP Ch.25).
        -- Uses custom state 'vehicleshow' (NOT 'visibility') so mount-type vehicle
        -- Show() calls from the event handler aren't blocked by C-level enforcement.
        if vehicleExitButton then
            ArmStateDriver("exitButtonVehicle", vehicleExitButton, "vehicleshow", EXIT_TOGGLE_SNIPPET,
                "[target=vehicle,exists] s1; s2")
        end

        -- Fallback event handler for edge cases where the 'vehicle' unit token
        -- may not exist yet when UNIT_ENTERED_VEHICLE fires (race condition).
        -- The state driver [target=vehicle,exists] covers most cases; this is
        -- a safety net for out-of-combat transitions and clean dismount handling.
        if not VehicleModule.hooks.exitButtonVehicleEvents then
            local exitBtnEventFrame = CreateFrame('Frame')
            exitBtnEventFrame:RegisterEvent('UNIT_ENTERED_VEHICLE')
            exitBtnEventFrame:RegisterEvent('UNIT_EXITED_VEHICLE')
            exitBtnEventFrame:SetScript('OnEvent', function(self, event, unit)
                if unit ~= 'player' then return end
                if not vehicleExitButton then return end
                if event == 'UNIT_ENTERED_VEHICLE' then
                    if InCombatLockdown() then return end
                    -- Mount-type vehicles only: no [vehicleui], state driver won't fire
                    if not UnitHasVehicleUI('player') and CanExitVehicle() then
                        vehicleExitButton:SetAlpha(1)
                        vehicleExitButton:Show()
                    end
                elseif event == 'UNIT_EXITED_VEHICLE' then
                    if not CanExitVehicle() then
                        if InCombatLockdown() then
                            -- Can't Hide() a secure frame in combat — visually hide via alpha
                            vehicleExitButton:SetAlpha(0)
                            -- Schedule proper Hide() + restore alpha after combat
                            local restoreFrame = VehicleModule.frames.exitBtnCombatRestore
                            if not restoreFrame then
                                restoreFrame = CreateFrame('Frame')
                                VehicleModule.frames.exitBtnCombatRestore = restoreFrame
                            end
                            restoreFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
                            restoreFrame:SetScript('OnEvent', function(f)
                                f:UnregisterEvent('PLAYER_REGEN_ENABLED')
                                if vehicleExitButton then
                                    vehicleExitButton:Hide()
                                    vehicleExitButton:SetAlpha(1)
                                end
                            end)
                        else
                            vehicleExitButton:Hide()
                        end
                    end
                end
            end)
            VehicleModule.frames.exitBtnEventFrame = exitBtnEventFrame
            VehicleModule.hooks.exitButtonVehicleEvents = true
        end

        -- If player is ALREADY in a vehicle (e.g. after /reload), show exit button.
        -- UNIT_ENTERED_VEHICLE won't fire again after reload. The state driver
        -- handles [vehicleui] case automatically; this covers mount vehicles.
        if (UnitHasVehicleUI('player') or CanExitVehicle()) and vehicleExitButton then
            vehicleExitButton:Show()
        end
    end

    VehicleModule.applied = true
    VehicleModule.pendingApply = false

    -- Delayed re-hide: Blizzard's MultiActionBar_Update can fire AFTER
    -- ApplyVehicleSystem completes (e.g. via PLAYER_ENTERING_WORLD).
    -- Only needed when artstyle=true (secondary bars should stay visible otherwise).
    if config.additional.vehicle.artstyle and UnitHasVehicleUI('player') and not InCombatLockdown() then
        local function rehideBars()
            if not VehicleModule.applied then return end
            if not UnitHasVehicleUI('player') then return end
            if InCombatLockdown() then return end
            if MultiBarBottomLeft  then MultiBarBottomLeft:Hide()  end
            if MultiBarBottomRight then MultiBarBottomRight:Hide() end
            if MultiBarRight       then MultiBarRight:Hide()       end
            if MultiBarLeft        then MultiBarLeft:Hide()        end
        end
        addon.core:ScheduleTimer(rehideBars, 0.05)
        addon.core:ScheduleTimer(rehideBars, 0.15)
    end
end

local function RestoreVehicleSystem()
    if not VehicleModule.applied then return end
    if InCombatLockdown() then return end

    -- Unregister events
    for key, frame in pairs(VehicleModule.events) do
        if frame and type(frame) == "table" and frame.UnregisterAllEvents then
            pcall(frame.UnregisterAllEvents, frame)
        end
    end
    VehicleModule.events = {}

    -- Unregister state drivers
    for name, data in pairs(VehicleModule.stateDrivers) do
        if data.frame and UnregisterStateDriver then
            pcall(UnregisterStateDriver, data.frame, data.state)
        end
    end
    VehicleModule.stateDrivers = {}

    -- Hide custom frames
    if vehicleBarBackground then vehicleBarBackground:Hide() end
    if vehicleExitButton then vehicleExitButton:Hide() end

    -- Clean up secure handler attributes
    local mainBar = pUiMainBar or addon.pUiMainBar or _G.pUiMainBar
    if mainBar then
        mainBar:SetAttribute('_onstate-vehicleupdate', nil)
    end
    if vehiclebar then
        vehiclebar:SetAttribute('_onstate-vehicleupdate', nil)
    end
    if vehicleExitButton then
        vehicleExitButton:SetAttribute('_onstate-vehicleshow', nil)
    end

    -- Clean up vehicle hider frame (secure state driver for secondary bars)
    if VehicleModule.frames.vehicleHider then
        VehicleModule.frames.vehicleHider:SetAttribute('_onstate-vehiclehide', nil)
        VehicleModule.frames.vehicleHider:Hide()
        VehicleModule.frames.vehicleHider = nil
    end

    -- Clean up mount-type vehicle exit button event frame
    if VehicleModule.frames.exitBtnEventFrame then
        VehicleModule.frames.exitBtnEventFrame:UnregisterAllEvents()
        VehicleModule.frames.exitBtnEventFrame:SetScript('OnEvent', nil)
        VehicleModule.frames.exitBtnEventFrame = nil
    end

    -- Restore secondary bars via Blizzard's MultiActionBar_Update
    -- (it reads CVars and shows/hides bars appropriately)
    if MultiActionBar_Update then
        pcall(MultiActionBar_Update)
    end

    CleanupVehicleFrames()
    if VehicleMenuBar then VehicleMenuBar:Show() end

    VehicleModule.frames = {}
    vehicleBarBackground = nil
    vehiclebar = nil
    vehicleExitButton = nil
    pUiMainBar = nil

    VehicleModule.applied = false
    VehicleModule.hooks = {}
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Export for dual-bar offset notifications (called by mainbars.lua)
addon.UpdateVehicleExitPosition = PositionVehicleExitButton

function addon.RefreshVehicleSystem()
    if IsModuleEnabled() then
        if not VehicleModule.applied then
            ApplyVehicleSystem()
        else
            if addon.RefreshVehicle then
                addon.RefreshVehicle()
            end
        end
    else
        if addon:ShouldDeferModuleDisable("vehicle", VehicleModule) then
            return
        end
        RestoreVehicleSystem()
    end
end

function addon.RefreshVehicle()
    if not IsModuleEnabled() or not VehicleModule.applied then return end
    if InCombatLockdown() then return end

    local btnsize = config.additional.size

    if vehicleExitButton then
        vehicleExitButton:SetSize(btnsize, btnsize)
        PositionVehicleExitButton()
    end

    if vehicleBarBackground then
        vehicleBarBackground:SetScale(config.mainbars.scale_vehicle or 1)
    end
end

-- ============================================================================
-- DEBUG COMMAND
-- ============================================================================

function addon.DebugVehicle()
    if not addon.debugMode then return end
    local p = function(msg) print("|cff00ccff[DragonUI Vehicle]|r " .. msg) end
    p("--- Vehicle Module Debug ---")
    p("Module enabled: " .. tostring(IsModuleEnabled()))
    p("Module applied: " .. tostring(VehicleModule.applied))
    p("artstyle: " .. tostring(config.additional.vehicle.artstyle))
    p("pUiMainBar: " .. tostring(pUiMainBar ~= nil) .. (pUiMainBar and (" shown=" .. tostring(pUiMainBar:IsShown())) or ""))
    p("vehicleBarBackground: " .. tostring(vehicleBarBackground ~= nil) .. (vehicleBarBackground and (" shown=" .. tostring(vehicleBarBackground:IsShown())) or ""))
    p("vehiclebar: " .. tostring(vehiclebar ~= nil) .. (vehiclebar and (" shown=" .. tostring(vehiclebar:IsShown()) .. " visible=" .. tostring(vehiclebar:IsVisible())) or ""))
    p("vehicleExitButton: " .. tostring(vehicleExitButton ~= nil) .. (vehicleExitButton and (" shown=" .. tostring(vehicleExitButton:IsShown()) .. " visible=" .. tostring(vehicleExitButton:IsVisible()) .. " parent=" .. tostring(vehicleExitButton:GetParent() and vehicleExitButton:GetParent():GetName())) or ""))
    p("UnitInVehicle: " .. tostring(UnitInVehicle("player")))
    p("UnitHasVehicleUI: " .. tostring(UnitHasVehicleUI("player")))
    p("GetBonusBarOffset: " .. tostring(GetBonusBarOffset()))
    p("VehicleMenuBar: shown=" .. tostring(VehicleMenuBar and VehicleMenuBar:IsShown()) .. " alpha=" .. tostring(VehicleMenuBar and VehicleMenuBar:GetAlpha()))
    if VehicleMenuBarActionButtonFrame then
        p("VehicleMenuBarActionButtonFrame: shown=" .. tostring(VehicleMenuBarActionButtonFrame:IsShown()))
    else
        p("VehicleMenuBarActionButtonFrame: nil")
    end
    p("MultiBarBottomLeft shown: " .. tostring(MultiBarBottomLeft and MultiBarBottomLeft:IsShown()))
    p("MultiBarBottomRight shown: " .. tostring(MultiBarBottomRight and MultiBarBottomRight:IsShown()))
    p("State drivers:")
    for name, data in pairs(VehicleModule.stateDrivers) do
        p("  " .. name .. " -> " .. tostring(data.frame and data.frame:GetName()) .. " [" .. data.state .. "]")
    end
    p("--- End Debug ---")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function WaitForDependencies(callback, attempts)
    attempts = attempts or 0
    if attempts > 20 then return end

    if CheckDependencies() then
        callback()
    else
        addon.core:ScheduleTimer(function()
            WaitForDependencies(callback, attempts + 1)
        end, 0.5)
    end
end

local initFrame = CreateFrame("Frame")
VehicleModule.eventFrame = initFrame

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        VehicleModule.initialized = true
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if IsModuleEnabled() then
            WaitForDependencies(function()
                ApplyVehicleSystem()
            end)
        end

        if addon.db then
            addon.db.RegisterCallback(VehicleModule, "OnProfileChanged", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
            addon.db.RegisterCallback(VehicleModule, "OnProfileCopied", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
            addon.db.RegisterCallback(VehicleModule, "OnProfileReset", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
        end

        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        local reloadInVehicle = false
        if VehicleModule.firstEnteringWorld then
            VehicleModule.firstEnteringWorld = false
            if IsModuleEnabled() and not VehicleModule.applied and CheckDependencies() then
                ApplyVehicleSystem()
            end
            reloadInVehicle = VehicleModule.applied and config.additional.vehicle.artstyle
                and UnitHasVehicleUI('player') and not InCombatLockdown()
        end
        if reloadInVehicle then
            -- The state driver already showed the bar at rest and the entry events only arrive later,
            -- so park it here or the first frames draw it in place before the slide.
            if VehicleModule.ApplyArtLayout then pcall(VehicleModule.ApplyArtLayout) end
            VehicleSlide_Start(true)
        else
            VehicleSlide_SnapAll()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if VehicleModule.pendingApply and IsModuleEnabled() then
            VehicleModule.pendingApply = false
            WaitForDependencies(function()
                ApplyVehicleSystem()
            end)
        end
    end
end)
