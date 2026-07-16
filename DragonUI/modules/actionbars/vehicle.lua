local addon = select(2,...);
local config = addon.config;
local class = addon._class;
local unpack = unpack;
local ipairs = ipairs;
local RegisterStateDriver = RegisterStateDriver;
local UnregisterStateDriver = UnregisterStateDriver;
local UnitVehicleSkin = UnitVehicleSkin;
local UIParent = UIParent;
local InCombatLockdown = InCombatLockdown;
local _G = getfenv(0);

-- ============================================================================
-- VEHICLE MODULE FOR DRAGONUI
-- ============================================================================
-- Approach: Kill VehicleMenuBar in noop.lua (prevents Blizzard's vehicle
-- transition code from interfering). Use secure state drivers and
-- _onstate-* snippets (combat-safe) for vehicle bar show/hide.
-- Matches the pretty_actionbar pattern.
-- ============================================================================

-- Module state tracking
local VehicleModule = {
    initialized = false,
    applied = false,
    pendingApply = false,
    stateDrivers = {},
    events = {},
    hooks = {},
    frames = {}
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("vehicle", VehicleModule,
        (addon.L and addon.L["Vehicle"]) or "Vehicle",
        (addon.L and addon.L["Vehicle interface enhancements"]) or "Vehicle interface enhancements")
end

-- Frame variables
local pUiMainBar = nil
local vehicleBarBackground = nil
local vehiclebar = nil
local vehicleExitButton = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("vehicle")
end

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

-- ============================================================================
-- STANCE/BONUS BAR PAGE HANDLING
-- ============================================================================

local stance = {
    ['DRUID'] = '[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;',
    ['WARRIOR'] = '[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;',
    ['PRIEST'] = '[bonusbar:1] 7;',
    ['ROGUE'] = '[bonusbar:1] 7; [bonusbar:2] 8;',
    ['DEFAULT'] = '[bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6;',
}

local function getbarpage()
    local condition = stance['DEFAULT']
    local page = stance[class]
    if page then
        condition = condition..' '..page
    end
    condition = condition..' 1'
    return condition
end

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

    -- Textures
    vehicleExitButton:SetNormalTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up')
    vehicleExitButton:GetNormalTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    vehicleExitButton:SetPushedTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down')
    vehicleExitButton:GetPushedTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    vehicleExitButton:SetHighlightTexture('Interface\\Vehicles\\UI-Vehicles-Button-Highlight')
    vehicleExitButton:GetHighlightTexture():SetTexCoord(0.130625, 0.879375, 0.130625, 0.879375)
    vehicleExitButton:GetHighlightTexture():SetBlendMode('ADD')

    -- Dragonflight-style background (matches action button styling)
    local bg = vehicleExitButton:CreateTexture(nil, 'BACKGROUND', nil, -1)
    bg:SetPoint('TOPRIGHT', vehicleExitButton, 3, 3)
    bg:SetPoint('BOTTOMLEFT', vehicleExitButton, -3, -3)
    if bg.set_atlas then
        bg:set_atlas('ui-hud-actionbar-iconframe-slot')
    else
        bg:SetColorTexture(0, 0, 0, 0.6)
    end
    vehicleExitButton.background = bg

    -- Border shadow (Dragonflight style)
    local shadow = vehicleExitButton:CreateTexture(nil, 'BACKGROUND', nil, -2)
    shadow:SetPoint('TOPRIGHT', vehicleExitButton, 5, 5)
    shadow:SetPoint('BOTTOMLEFT', vehicleExitButton, -5, -5)
    if shadow.set_atlas then
        shadow:set_atlas('ui-hud-actionbar-iconframe-flyoutbordershadow', true)
    end
    vehicleExitButton.shadow = shadow

    -- Scripts
    vehicleExitButton:RegisterForClicks('AnyUp')
    vehicleExitButton:SetScript('OnEnter', function(self)
        GameTooltip_AddNewbieTip(self, LEAVE_VEHICLE, 1.0, 1.0, 1.0, nil)
    end)
    vehicleExitButton:SetScript('OnLeave', GameTooltip_Hide)
    vehicleExitButton:SetScript('OnClick', function(self)
        VehicleExit()
        self:SetChecked(true)
    end)
    vehicleExitButton:SetScript('OnShow', function(self)
        self:SetChecked(false)
    end)
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

-- Set up secure snippet on vehiclebar (child) — shows/hides parent
-- (vehicleBarBackground) when [vehicleui] changes. Uses custom state name
-- 'vehicleupdate' (NOT 'visibility') to avoid conflicts with other state
-- drivers. Combat-safe: secure snippets execute in the restricted
-- environment. Matches pretty_actionbar's vehiclebutton_state() pattern.
local function vehiclebutton_state()
    if not vehiclebar then return end
    for index = 1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G['VehicleMenuBarActionButton'..index]
        if button then
            vehiclebar:SetFrameRef('VehicleMenuBarActionButton'..index, button)
        end
    end
    vehiclebar:SetAttribute('_onstate-vehicleupdate', [[
        if newstate == 's1' then
            self:GetParent():Show()
        else
            self:GetParent():Hide()
        end
    ]])
    VehicleModule.stateDrivers.vehicleArtVisibility = {frame = vehiclebar, state = 'vehicleupdate'}
    RegisterStateDriver(vehiclebar, 'vehicleupdate', '[vehicleui] s1; s2')
end

local function vehiclebar_power_setup()
    if not vehiclebar then return end

    VehicleMenuBarLeaveButton:SetParent(vehiclebar)
    VehicleMenuBarLeaveButton:SetSize(47, 50)
    VehicleMenuBarLeaveButton:SetClearPoint('BOTTOMRIGHT', -178, 14)
    VehicleMenuBarLeaveButton:SetHighlightTexture('Interface\\Vehicles\\UI-Vehicles-Button-Highlight')
    VehicleMenuBarLeaveButton:GetHighlightTexture():SetTexCoord(0.130625, 0.879375, 0.130625, 0.879375)
    VehicleMenuBarLeaveButton:GetHighlightTexture():SetBlendMode('ADD')

    if not VehicleMenuBarLeaveButton.DragonUIClickHooked then
        VehicleMenuBarLeaveButton:HookScript('OnClick', VehicleExit)
        VehicleMenuBarLeaveButton.DragonUIClickHooked = true
    end

    VehicleMenuBarHealthBar:SetParent(vehiclebar)
    VehicleMenuBarHealthBarOverlay:SetParent(VehicleMenuBarHealthBar)
    VehicleMenuBarHealthBarOverlay:SetSize(46, 105)
    VehicleMenuBarHealthBarOverlay:SetClearPoint('BOTTOMLEFT', -5, -9)
    VehicleMenuBarHealthBarBackground:SetParent(VehicleMenuBarHealthBar)
    VehicleMenuBarHealthBarBackground:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
    VehicleMenuBarHealthBarBackground:SetTexCoord(0.0, 1.0, 0.0, 1.0)
    VehicleMenuBarHealthBarBackground:SetVertexColor(
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
    )

    VehicleMenuBarPowerBar:SetParent(vehiclebar)
    VehicleMenuBarPowerBarOverlay:SetParent(VehicleMenuBarPowerBar)
    VehicleMenuBarPowerBarOverlay:SetSize(46, 105)
    VehicleMenuBarPowerBarOverlay:SetClearPoint('BOTTOMLEFT', -5, -9)
    VehicleMenuBarPowerBarBackground:SetParent(VehicleMenuBarPowerBar)
    VehicleMenuBarPowerBarBackground:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
    VehicleMenuBarPowerBarBackground:SetTexCoord(0.5390625, 0.953125, 0.0, 1.0)
    VehicleMenuBarPowerBarBackground:SetVertexColor(
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
        TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
    )
end

local function vehiclebar_mechanical_setup()
    if not vehicleBarBackground then return end

    vehicleBarBackground.OrganicUi:Hide()
    vehicleBarBackground.MechanicUi:Show()

    VehicleMenuBarLeaveButton:SetNormalTexture(addon._dir..'mechanical2')
    VehicleMenuBarLeaveButton:GetNormalTexture():SetTexCoord(45/512, 84/512, 185/512, 224/512)
    VehicleMenuBarLeaveButton:SetPushedTexture(addon._dir..'mechanical2')
    VehicleMenuBarLeaveButton:GetPushedTexture():SetTexCoord(2/512, 40/512, 185/512, 223/512)

    VehicleMenuBarHealthBar:SetSize(38, 84)
    VehicleMenuBarPowerBar:SetSize(38, 84)
    VehicleMenuBarPowerBar:SetClearPoint('BOTTOMRIGHT', -94, 6)
    VehicleMenuBarHealthBar:SetClearPoint('BOTTOMLEFT', 74, 6)
    VehicleMenuBarHealthBarBackground:SetSize(40, 92)
    VehicleMenuBarPowerBarBackground:SetSize(40, 92)
    VehicleMenuBarHealthBarBackground:SetClearPoint('BOTTOMLEFT', -2, -6)
    VehicleMenuBarPowerBarBackground:SetClearPoint('BOTTOMLEFT', -2, -6)
    VehicleMenuBarHealthBarOverlay:SetTexture(addon._dir..'mechanical2')
    VehicleMenuBarHealthBarOverlay:SetTexCoord(4/512, 44/512, 263/512, 354/512)
    VehicleMenuBarPowerBarOverlay:SetTexture(addon._dir..'mechanical2')
    VehicleMenuBarPowerBarOverlay:SetTexCoord(4/512, 44/512, 263/512, 354/512)

    VehicleMenuBarPitchUpButton:SetParent(vehicleBarBackground.MechanicUi)
    VehicleMenuBarPitchUpButton:SetSize(32, 31)
    VehicleMenuBarPitchUpButton:SetClearPoint('BOTTOMLEFT', 156, 46)
    VehicleMenuBarPitchUpButton:SetNormalTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchUpButton:SetPushedTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchUpButton:GetNormalTexture():SetTexCoord(1/512, 34/512, 227/512, 259/512)
    VehicleMenuBarPitchUpButton:GetPushedTexture():SetTexCoord(36/512, 69/512, 227/512, 259/512)

    VehicleMenuBarPitchDownButton:SetParent(vehicleBarBackground.MechanicUi)
    VehicleMenuBarPitchDownButton:SetSize(32, 31)
    VehicleMenuBarPitchDownButton:SetClearPoint('BOTTOMLEFT', 156, 8)
    VehicleMenuBarPitchDownButton:SetNormalTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchDownButton:SetPushedTexture(addon._dir..'mechanical2')
    VehicleMenuBarPitchDownButton:GetNormalTexture():SetTexCoord(148/512, 180/512, 289/512, 320/512)
    VehicleMenuBarPitchDownButton:GetPushedTexture():SetTexCoord(148/512, 180/512, 323/512, 354/512)

    VehicleMenuBarPitchSlider:SetParent(vehicleBarBackground.MechanicUi)
    VehicleMenuBarPitchSlider:SetSize(20, 82)
    VehicleMenuBarPitchSlider:SetClearPoint('BOTTOMLEFT', 124, 2)

    local bg1 = _G['DragonUI_VehicleBarBackgroundBACKGROUND1']
    if bg1 then
        bg1:SetDrawLayer('BACKGROUND', -1)
    end

    VehicleMenuBarPitchSliderBG:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap]])
    VehicleMenuBarPitchSliderBG:SetTexCoord(0.46875, 0.50390625, 0.31640625, 0.62109375)
    VehicleMenuBarPitchSliderBG:SetVertexColor(0, 0.85, 0.99)

    VehicleMenuBarPitchSliderMarker:SetWidth(20)
    VehicleMenuBarPitchSliderMarker:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap]])
    VehicleMenuBarPitchSliderMarker:SetTexCoord(0.46875, 0.50390625, 0.45, 0.55)
    VehicleMenuBarPitchSliderMarker:SetVertexColor(1, 0, 0)

    VehicleMenuBarPitchSliderOverlayThing:SetPoint('TOPLEFT', -5, 2)
    VehicleMenuBarPitchSliderOverlayThing:SetPoint('BOTTOMRIGHT', 3, -4)
end

local function vehiclebar_organic_setup()
    if not vehicleBarBackground then return end

    vehicleBarBackground.OrganicUi:Show()
    vehicleBarBackground.MechanicUi:Hide()
    VehicleMenuBarHealthBar:SetSize(38, 74)
    VehicleMenuBarPowerBar:SetSize(38, 74)
    VehicleMenuBarPowerBar:SetClearPoint('BOTTOMRIGHT', -119, 3)
    VehicleMenuBarHealthBar:SetClearPoint('BOTTOMLEFT', 119, 3)
    VehicleMenuBarHealthBarBackground:SetSize(40, 83)
    VehicleMenuBarPowerBarBackground:SetSize(40, 83)
    VehicleMenuBarHealthBarBackground:SetClearPoint('BOTTOMLEFT', -2, -9)
    VehicleMenuBarPowerBarBackground:SetClearPoint('BOTTOMLEFT', -2, -9)
    VehicleMenuBarLeaveButton:SetNormalTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up')
    VehicleMenuBarLeaveButton:GetNormalTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    VehicleMenuBarLeaveButton:SetPushedTexture('Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down')
    VehicleMenuBarLeaveButton:GetPushedTexture():SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    VehicleMenuBarHealthBarOverlay:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap-Organic-bottle]])
    VehicleMenuBarHealthBarOverlay:SetTexCoord(0.46484375, 0.66015625, 0.0390625, 0.9375)
    VehicleMenuBarPowerBarOverlay:SetTexture([[Interface\Vehicles\UI-Vehicles-Endcap-Organic-bottle]])
    VehicleMenuBarPowerBarOverlay:SetTexCoord(0.46484375, 0.66015625, 0.0390625, 0.9375)
end

local function vehiclebar_layout_setup()
    if IsVehicleAimAngleAdjustable() then
        vehiclebar_mechanical_setup()
    else
        vehiclebar_organic_setup()
    end
end

local function vehiclebutton_position()
    if not vehiclebar then return end
    if InCombatLockdown() then return end

    -- Center vehicle buttons within the visible action area of the vehicle art.
    -- The art frame is 800px wide, but the usable area differs between organic
    -- and mechanical vehicles:
    --   Organic: symmetric endcaps, buttons shifted ~48px left of center
    --   Mechanical: pitch controls on the left add ~40px, shift buttons right
    local btnSize = 52
    local btnGap = 6
    local numButtons = VEHICLE_MAX_ACTIONBUTTONS
    local totalWidth = numButtons * btnSize + (numButtons - 1) * btnGap
    local artOffset = IsVehicleAimAngleAdjustable() and -20 or -48
    local startOffset = -(totalWidth / 2) + artOffset

    for index = 1, numButtons do
        local button = _G['VehicleMenuBarActionButton'..index]
        if button then
            button:ClearAllPoints()
            button:SetParent(vehiclebar)
            button:SetSize(btnSize, btnSize)
            button:Show()
            if index == 1 then
                button:SetPoint('BOTTOMLEFT', vehiclebar, 'BOTTOM', startOffset, 21)
            else
                local previous = _G['VehicleMenuBarActionButton'..(index-1)]
                if previous then
                    button:SetPoint('LEFT', previous, 'RIGHT', btnGap, 0)
                end
            end
        end
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
        mainBar:SetAttribute('_onstate-vehicleupdate', [[
            if newstate == '1' then
                self:Hide()
            else
                self:Show()
            end
        ]])
        VehicleModule.stateDrivers.mainBarVehicle = {frame = mainBar, state = 'vehicleupdate'}
        RegisterStateDriver(mainBar, 'vehicleupdate', '[vehicleui] 1; 2')
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

    if not pUiMainBar then return end

    for i = 1, 12 do
        local actionButton = _G['ActionButton'..i]
        if actionButton then
            pUiMainBar:SetFrameRef('ActionButton'..i, actionButton)
        end
    end

    pUiMainBar:Execute([[
        buttons = newtable()
        for i = 1, 12 do
            local button = self:GetFrameRef('ActionButton'..i)
            if button then
                table.insert(buttons, button)
            end
        end
    ]])

    pUiMainBar:SetAttribute('_onstate-page', [[
        for i, button in ipairs(buttons) do
            button:SetAttribute('actionpage', tonumber(newstate))
        end
    ]])

    VehicleModule.stateDrivers.bonusBarPage = {frame = pUiMainBar, state = 'page'}
    RegisterStateDriver(pUiMainBar, 'page', getbarpage())
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

        -- Pre-parent and pre-position vehicle action buttons on vehiclebar.
        -- This ensures buttons are visible when [vehicleui] state driver shows
        -- vehicleBarBackground during mid-combat vehicle entry (e.g., Malygos
        -- Phase 3 drakes). Default organic layout is used; correct layout
        -- (organic/mechanical) is applied by UNIT_ENTERED_VEHICLE handler when
        -- not in combat, or deferred to PLAYER_REGEN_ENABLED otherwise.
        -- (MCP Ch.25: secure snippets can Show()/Hide() in combat, but
        --  SetParent/SetPoint on secure frames cannot be called in combat.)
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
        -- Pretty_actionbar confirms [target=vehicle,...] works in 3.3.5a state drivers.
        if vehicleExitButton then
            vehicleExitButton:SetAttribute('_onstate-vehicleshow', [[
                if newstate == 's1' then
                    self:Show()
                else
                    self:Hide()
                end
            ]])
            VehicleModule.stateDrivers.exitButtonVehicle = {frame = vehicleExitButton, state = 'vehicleshow'}
            RegisterStateDriver(vehicleExitButton, 'vehicleshow', '[vehicleui] s2; [target=vehicle,exists] s1; s2')
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
            vehicleExitButton:SetAttribute('_onstate-vehicleshow', [[
                if newstate == 's1' then
                    self:Show()
                else
                    self:Hide()
                end
            ]])
            VehicleModule.stateDrivers.exitButtonVehicle = {frame = vehicleExitButton, state = 'vehicleshow'}
            RegisterStateDriver(vehicleExitButton, 'vehicleshow', '[target=vehicle,exists] s1; s2')
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
            addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
            addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
            addon.db.RegisterCallback(addon, "OnProfileReset", function()
                addon.core:ScheduleTimer(function()
                    addon.RefreshVehicleSystem()
                end, 0.1)
            end)
        end

        self:UnregisterEvent("PLAYER_LOGIN")
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
