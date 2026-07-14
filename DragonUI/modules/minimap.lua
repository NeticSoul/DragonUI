-- ============================================================================
-- DragonUI - Minimap Module
-- Based on RetailUI by Dmitriy, adapted for DragonUI.
-- ============================================================================

local addon = select(2, ...);
local L = addon.L

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local MinimapModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    frames = {},
    -- Legacy properties for compatibility
    minimapFrame = nil,
    borderFrame = nil,
    isEnabled = false,
    originalMinimapSettings = {},
    originalMask = nil
}
addon.MinimapModule = MinimapModule;

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("minimap", MinimapModule,
        (L and L["Minimap"]) or "Minimap",
        (L and L["Custom minimap styling, positioning, tracking icons and calendar"]) or "Custom minimap styling, positioning, tracking icons and calendar")
end

-- Module config helpers (centralized in api.lua)
local function GetModuleConfig()
    return addon:GetModuleConfig("minimap")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("minimap")
end

local function IsMinimapSystemActive()
    return IsModuleEnabled() and MinimapModule.applied
end

local function IsDragonUIMinimapControlling()
    return MinimapModule.applied or MinimapModule._initializingMinimapSystem
end

local DEFAULT_MINIMAP_WIDTH = Minimap:GetWidth() * 1.36
local DEFAULT_MINIMAP_HEIGHT = Minimap:GetHeight() * 1.36
local blipScale = 1.12
local BORDER_SIZE = 71 * 2 * 2 ^ 1
local BORDER_TO_MAP_RATIO = BORDER_SIZE / (DEFAULT_MINIMAP_WIDTH / blipScale)
local DRAGONUI_MINIMAP_MASK = "Interface\\AddOns\\DragonUI\\assets\\uiminimapmask.tga"
local VANILLA_MINIMAP_MASK = "Textures\\MinimapMask"

local ADDON_ORBIT_RADIUS = 15
local DRAGONUI_SETTINGS_BUTTON_SIZE = 21
local DRAGONUI_SETTINGS_BUTTON_ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
local DRAGONUI_SETTINGS_BUTTON_ICON_FALLBACK = "Interface\\Icons\\Ability_Mount_RedDragonhawk"
local DRAGONUI_CLASSIC_COLLECTOR_ICON = "Interface\\AddOns\\DragonUI\\assets\\dfrl_collector_toggle.tga"

-- Addon icon whitelist: define before ReplaceBlizzardFrame
local WHITE_LIST = {'MiniMapBattlefieldFrame', 'MiniMapTrackingButton', 'MiniMapMailFrame', 'HelpOpenTicketButton',
                    'GatherMatePin', 'HandyNotesPin', 'TimeManagerClockButton', 'Archy', 'GatherNote', 'MinimMap',
                    'Spy_MapNoteList_mini', 'ZGVMarker', 'poiWorldMapPOIFrame', 'WorldMapPOIFrame', 'QuestMapPOI',
                    'GameTimeFrame',
                    -- Quest helper POI icons (quest markers inside the minimap)
                    'QuestieFrame', 'Questie_MiniMapNote', 'pfQuest', 'pfquest', 'pfMap', 'pfMinimap'}

-- Keep launcher buttons skinnable while still excluding internal quest pins.
-- Questie launcher is LibDBIcon-based (LibDBIcon10_Questie), while pfQuest
-- uses a named minimap button (pfQuestIcon).
local QUEST_ADDON_LAUNCHER_BUTTONS = {
    ["pfQuestIcon"] = true,
    ["LibDBIcon10_Questie"] = true,
}

local function IsQuestAddonLauncherButton(button)
    if not button or not button.GetName then
        return false
    end

    local frameName = button:GetName()
    if not frameName then
        return false
    end

    if QUEST_ADDON_LAUNCHER_BUTTONS[frameName] then
        return true
    end

    -- Defensive future-proofing for Questie forks that keep the same LibDBIcon prefix.
    if frameName:find("LibDBIcon10_Questie", 1, true) == 1 then
        return true
    end

    return false
end

local function IsFrameWhitelisted(frameName)
    if not frameName then
        return false
    end

    for i, buttons in pairs(WHITE_LIST) do
        if frameName ~= nil then
            if frameName:match(buttons) then
                return true
            end
        end
    end
    return false
end

local function IsQuestMinimapPin(button)
    if not button then
        return false
    end

    -- Cache positive detections: quest pins are stable frame objects and this
    -- avoids repeated texture/region scans on frequent minimap button rescans.
    if button.DragonUI_IsQuestPin then
        return true
    end

    -- Do not classify the actual addon launcher icon as an internal quest pin.
    -- This lets DragonUI skin the launcher button while still skipping map pins.
    if IsQuestAddonLauncherButton(button) then
        return false
    end

    local frameName = button:GetName()
    if IsFrameWhitelisted(frameName) then
        button.DragonUI_IsQuestPin = true
        return true
    end

    local parent = button:GetParent()
    local parentName = parent and parent.GetName and parent:GetName()
    if IsFrameWhitelisted(parentName) then
        button.DragonUI_IsQuestPin = true
        return true
    end

    if button.GetNumChildren then
        local children = { button:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            local childName = child and child.GetName and child:GetName()
            if IsFrameWhitelisted(childName) then
                button.DragonUI_IsQuestPin = true
                return true
            end
        end
    end

    -- pfQuest/Questie/TomTom pins and TotemRadius rings are nameless Buttons on Minimap that name checks miss;
    -- detect them (read-only) by their own AddOn folder in a region texture path so the skin leaves them alone.
    if button.GetNumRegions then
        for i = 1, button:GetNumRegions() do
            local region = select(i, button:GetRegions())
            if region and region.GetTexture then
                local tex = region:GetTexture()
                if type(tex) == "string" then
                    local lower = tex:lower()
                    if lower:find("pfquest", 1, true)
                       or lower:find("pfmap", 1, true)
                       or lower:find("pfminimap", 1, true)
                       or lower:find("questie", 1, true)
                       or lower:find("totemradius", 1, true)
                       or lower:find("\\tomtom\\", 1, true) then
                        button.DragonUI_IsQuestPin = true
                        return true
                    end
                end
            end
        end
    end

    local isQuestPin = button.miniMapIcon or button.miniMapIconData or button.pfQuest or button.pfquest
    if isQuestPin then
        button.DragonUI_IsQuestPin = true
        return true
    end

    return false
end

local function UpdateMinimapCircleSize()
    if not Minimap or not Minimap.Circle then return end

    local mapSize = math.max(Minimap:GetWidth(), Minimap:GetHeight())
    if not mapSize or mapSize <= 0 then return end

    local borderSize = mapSize * BORDER_TO_MAP_RATIO
    if MinimapModule.activeCircleSize ~= borderSize then
        Minimap.Circle:SetSize(borderSize, borderSize)
        Minimap.Circle:ClearAllPoints()
        Minimap.Circle:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        MinimapModule.activeCircleSize = borderSize
    end
end

local function IsSexyMapHybridModeValue(mode)
    return mode == "hybrid"
end

local function UpdateMinimapMaskForRotation()
    if not Minimap or not IsDragonUIMinimapControlling() then return end

    local isHybridMode = MinimapModule.sexyMapHybridMode
        or MinimapModule._allowExternalMask
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))

    -- In hybrid mode, SexyMap owns the minimap shape/mask.
    if isHybridMode then
        MinimapModule.activeMask = nil
        return
    end

    local minimapConfig = addon.db and addon.db.profile and addon.db.profile.minimap
    local useVanillaMask = minimapConfig and minimapConfig.animated_border_hide_dragonui_border == true
    local desiredMask = useVanillaMask and VANILLA_MINIMAP_MASK or DRAGONUI_MINIMAP_MASK

    if MinimapModule.activeMask ~= desiredMask then
        Minimap:SetMaskTexture(desiredMask)
        MinimapModule.activeMask = desiredMask
    end
end

local function IsHybridMinimapModeActive()
    return MinimapModule.sexyMapHybridMode
        or MinimapModule._allowExternalMask
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))
end

local function GetStoredRotatePreference()
    local minimapConfig = addon and addon.db and addon.db.profile and addon.db.profile.minimap
    if minimapConfig and (minimapConfig.indoorRotatePreference == "0" or minimapConfig.indoorRotatePreference == "1") then
        return minimapConfig.indoorRotatePreference
    end
    return nil
end

local function SetStoredRotatePreference(value)
    if value ~= "0" and value ~= "1" then return end
    local minimapConfig = addon and addon.db and addon.db.profile and addon.db.profile.minimap
    if minimapConfig then
        minimapConfig.indoorRotatePreference = value
    end
end

local function SyncStoredRotatePreference(currentRotate, isIndoor, isForced)
    if currentRotate ~= "0" and currentRotate ~= "1" then return end

    -- Always persist explicit ON preference.
    if currentRotate == "1" then
        SetStoredRotatePreference("1")
        return
    end

    -- For OFF, only persist when in stable outdoor non-forced context.
    local inInstance = IsInInstance and IsInInstance()
    if not isIndoor and not isForced and not inInstance then
        SetStoredRotatePreference("0")
    end
end

local function ApplyRotateCVar(value)
    if value ~= "0" and value ~= "1" then return end
    if GetCVar("rotateMinimap") == value then return end

    MinimapModule._rotationPolicyUpdating = true
    SetCVar("rotateMinimap", value)
    if MinimapModule.UpdateRotation then
        MinimapModule.UpdateRotation()
    end
    MinimapModule._rotationPolicyUpdating = false
end

local function UpdateIndoorRotationPolicy()
    if not Minimap or not IsDragonUIMinimapControlling() then return end
    if MinimapModule._rotationPolicyUpdating then return end

    -- In SexyMap hybrid mode, DragonUI must not control rotateMinimap.
    if IsHybridMinimapModeActive() then
        if MinimapModule.forcingIndoorRotation then
            MinimapModule.forcingIndoorRotation = false
            local restoreRotate = GetStoredRotatePreference() or MinimapModule.userRotatePreference
            if restoreRotate == "0" or restoreRotate == "1" then
                ApplyRotateCVar(restoreRotate)
            end
        else
            local current = GetCVar("rotateMinimap")
            MinimapModule.userRotatePreference = current
            SyncStoredRotatePreference(current, IsIndoors and IsIndoors(), false)
        end
        return
    end

    local isIndoor = IsIndoors and IsIndoors()
    local shouldForceIndoorDisable = isIndoor
    local currentRotate = GetCVar("rotateMinimap")
    local preferredRotate = GetStoredRotatePreference() or MinimapModule.userRotatePreference or currentRotate

    -- While in instance interiors, force rotateMinimap off if preferred/outdoor setting is ON.
    if shouldForceIndoorDisable then
        if currentRotate == "1" then
            preferredRotate = "1"
            MinimapModule.userRotatePreference = "1"
            SetStoredRotatePreference("1")
        end

        if preferredRotate == "1" then
            MinimapModule.forcingIndoorRotation = true
            ApplyRotateCVar("0")
        else
            MinimapModule.forcingIndoorRotation = false
        end
        return
    end

    -- Outdoors, restore user preference after indoor force-disable.
    if MinimapModule.forcingIndoorRotation then
        local restoreRotate = preferredRotate or "1"
        MinimapModule.forcingIndoorRotation = false
        ApplyRotateCVar(restoreRotate)
    end

    -- Outdoors without force: treat current CVar as the user's chosen preference.
    MinimapModule.userRotatePreference = currentRotate
    SyncStoredRotatePreference(currentRotate, shouldForceIndoorDisable, MinimapModule.forcingIndoorRotation)
end

local function UpdateMinimapBackdropAlignment(force)
    if not Minimap or not MinimapBackdrop then return end

    local rotateEnabled = GetCVar("rotateMinimap") == "1"
    local isIndoor = IsIndoors and IsIndoors()
    local desiredYOffset = (rotateEnabled and isIndoor) and 0 or 3

    if force or MinimapModule.backdropYOffset ~= desiredYOffset then
        MinimapBackdrop:ClearAllPoints()
        MinimapBackdrop:SetPoint("CENTER", Minimap, "CENTER", 0, desiredYOffset)
        MinimapModule.backdropYOffset = desiredYOffset
    end
end

local function UpdateIndoorRotateScale()
    if not Minimap then return end

    local desiredScale = blipScale

    if MinimapModule.activeMinimapScale ~= desiredScale then
        Minimap:SetScale(desiredScale)
        MinimapModule.activeMinimapScale = desiredScale
    end
end

local function ApplyTextureRotation(texture, angle)
    if not texture then return end

    if texture.SetRotation then
        texture:SetRotation(angle)
        return
    end

    local c = math.cos(angle)
    local s = math.sin(angle)
    local cx, cy = 0.5, 0.5

    local function RotatePoint(x, y)
        local dx = x - cx
        local dy = y - cy
        return cx + dx * c - dy * s, cy + dx * s + dy * c
    end

    local ulx, uly = RotatePoint(0, 0)
    local llx, lly = RotatePoint(0, 1)
    local urx, ury = RotatePoint(1, 0)
    local lrx, lry = RotatePoint(1, 1)
    texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- SECURE HOOKS: Add secure hooks for critical functions
local function SetupSecureHooks()
    if MinimapModule.hooks.CloseDropDownMenus then
        return -- Already hooked
    end

    -- Secure hook for CloseDropDownMenus
    MinimapModule.hooks.CloseDropDownMenus = function()
        if not MinimapModule.applied then return end
        if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
        end
    end
    hooksecurefunc("CloseDropDownMenus", MinimapModule.hooks.CloseDropDownMenus)

    -- Secure hook for SetTracking
    MinimapModule.hooks.SetTracking = function()
        if MinimapModule.applied then
            MinimapModule:UpdateTrackingIcon()
        end
    end
    hooksecurefunc("SetTracking", MinimapModule.hooks.SetTracking)

    -- Hook for Minimap_UpdateRotationSetting if it exists
    -- Uses indirection via MinimapModule.UpdateRotation to avoid infinite recursion
    -- (calling the global from a post-hook would re-trigger the hook)
    if Minimap_UpdateRotationSetting then
        MinimapModule.hooks.Minimap_UpdateRotationSetting = function()
            if MinimapModule.applied and MinimapModule.UpdateRotation then
                MinimapModule.UpdateRotation()
            end
        end
        hooksecurefunc("Minimap_UpdateRotationSetting", MinimapModule.hooks.Minimap_UpdateRotationSetting)
    end
end

-- CLEANUP: Function for cleaning up hooks
-- Phase 3B: Use flag-based approach instead of clearing table
-- (hooksecurefunc can't be undone; clearing the table enables re-registration and duplication)
local function CleanupSecureHooks()
    MinimapModule.hooksDisabled = true
end

local function UpdateCalendarDate()
    local _, _, day = CalendarGetDate()
    if not day or day < 1 or day > 31 then
        return
    end

    local gameTimeFrame = GameTimeFrame
    if not gameTimeFrame then
        return
    end

    local normalTexture = gameTimeFrame:GetNormalTexture()
    if not normalTexture then
        return
    end
    normalTexture:SetAllPoints(gameTimeFrame)
    normalTexture:set_atlas('Minimap-Calendar-' .. day .. '-Normal', true)

    local highlightTexture = gameTimeFrame:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetAllPoints(gameTimeFrame)
        highlightTexture:set_atlas('Minimap-Calendar-' .. day .. '-Highlight', true)
    end

    local pushedTexture = gameTimeFrame:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetAllPoints(gameTimeFrame)
        pushedTexture:set_atlas('Minimap-Calendar-' .. day .. '-Pushed', true)
    end
end

local function ReplaceBlizzardFrame(frame)
    -- Check combat lockdown before making secure frame changes
    if InCombatLockdown() then
        MinimapModule.registeredEvents.PLAYER_REGEN_ENABLED = function()
            ReplaceBlizzardFrame(frame)
            MinimapModule.registeredEvents.PLAYER_REGEN_ENABLED = nil
        end
        return
    end

    -- Store original states before modification
    if not MinimapModule.originalStates.MinimapCluster then
        MinimapModule.originalStates.MinimapCluster = {
            points = {},
            scale = MinimapCluster:GetScale()
        }
        for i = 1, MinimapCluster:GetNumPoints() do
            MinimapModule.originalStates.MinimapCluster.points[i] = {MinimapCluster:GetPoint(i)}
        end
    end

    -- Store DurabilityFrame original state
    if DurabilityFrame and not MinimapModule.originalStates.DurabilityFrame then
        MinimapModule.originalStates.DurabilityFrame = {
            points = {},
            scale = DurabilityFrame:GetScale()
        }
        for i = 1, DurabilityFrame:GetNumPoints() do
            MinimapModule.originalStates.DurabilityFrame.points[i] = {DurabilityFrame:GetPoint(i)}
        end
    end

    local minimapCluster = MinimapCluster
    minimapCluster:ClearAllPoints()
    minimapCluster:SetPoint("CENTER", frame, "CENTER", 0, 0)

    -- In hybrid mode with SexyMap, skip border/zone text customization
    -- SexyMap handles: borders, zone text styling, shapes
    -- DragonUI handles: positioning, tracking icons, calendar, POI textures
    local isHybridMode = MinimapModule.sexyMapHybridMode
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))

    if not isHybridMode then
        -- DragonUI border top styling (skipped in hybrid mode)
        local minimapBorderTop = MinimapBorderTop
        minimapBorderTop:ClearAllPoints()
        minimapBorderTop:SetPoint("TOP", 0, 5)
        minimapBorderTop:set_atlas('Minimap-Border-Top', true)
        minimapBorderTop:SetSize(156, 20)

        local minimapZoneButton = MinimapZoneTextButton
        minimapZoneButton:ClearAllPoints()
        minimapZoneButton:SetPoint("LEFT", minimapBorderTop, "LEFT", 7, 1)
        minimapZoneButton:SetWidth(108)

        minimapZoneButton:EnableMouse(true)
        minimapZoneButton:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                if WorldMapFrame:IsShown() then
                    HideUIPanel(WorldMapFrame)
                else
                    ShowUIPanel(WorldMapFrame)
                end
            end
        end)

        local minimapZoneText = MinimapZoneText
        minimapZoneText:SetAllPoints(minimapZoneButton)
        minimapZoneText:SetJustifyH("LEFT")
    else
        -- In hybrid mode, only add the click handler for world map (SexyMap handles styling)
        MinimapZoneTextButton:EnableMouse(true)
        MinimapZoneTextButton:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                if WorldMapFrame:IsShown() then
                    HideUIPanel(WorldMapFrame)
                else
                    ShowUIPanel(WorldMapFrame)
                end
            end
        end)
    end

    if not isHybridMode then
        -- DragonUI clock/calendar positioning (anchored to DragonUI's border top)
        local timeClockButton = TimeManagerClockButton
        timeClockButton:GetRegions():Hide()
        timeClockButton:ClearAllPoints()
        timeClockButton:SetPoint("RIGHT", MinimapBorderTop, "RIGHT", -5, 0)
        timeClockButton:SetWidth(30)

        local gameTimeFrame = GameTimeFrame
        gameTimeFrame:ClearAllPoints()
        gameTimeFrame:SetPoint("LEFT", MinimapBorderTop, "RIGHT", 3, -1)
        gameTimeFrame:SetSize(26, 24)
        gameTimeFrame:SetHitRectInsets(0, 0, 0, 0)
        gameTimeFrame:GetFontString():Hide()

        UpdateCalendarDate()

        -- Blizzard refreshes calendar visuals on several events; re-apply our atlas after each update.
        if not gameTimeFrame.DragonUI_CalendarHooked then
            gameTimeFrame.DragonUI_CalendarHooked = true
            gameTimeFrame:HookScript("OnEvent", function()
                if MinimapModule.applied then
                    UpdateCalendarDate()
                end
            end)
            gameTimeFrame:HookScript("OnShow", function()
                if MinimapModule.applied then
                    UpdateCalendarDate()
                end
            end)
        end
    end

    -- Configure DurabilityFrame properly
    local durabilityFrame = DurabilityFrame
    if durabilityFrame then
        durabilityFrame:ClearAllPoints()
        -- Position below the minimap with appropriate offset
        durabilityFrame:SetPoint("TOP", Minimap, "BOTTOM", -15, -5)
        -- Adjust scale to match the minimap
        durabilityFrame:SetScale(3 / blipScale)
    end

    -- Track whether capture bar is currently active
    local durability_captureBarActive = false

    -- Reposition DurabilityFrame when a capture bar is visible to avoid overlap
    -- forceState: true = capture bar definitely visible, false = definitely hidden, nil = auto-detect
    local function UpdateDurabilityPosition(forceState)
        if not durabilityFrame then return end
        local captureBarVisible
        if forceState ~= nil then
            captureBarVisible = forceState
        else
            captureBarVisible = false
            for i = 1, 5 do
                local bar = _G['WorldStateCaptureBar' .. i]
                if bar and bar:IsVisible() then
                    captureBarVisible = true
                    break
                end
            end
        end
        durability_captureBarActive = captureBarVisible
        if not durabilityFrame.DragonUI_SettingPoint then
            durabilityFrame.DragonUI_SettingPoint = true
            durabilityFrame:ClearAllPoints()
            if captureBarVisible then
                -- Move down below the capture bar (shifted left to align)
                durabilityFrame:SetPoint("TOP", Minimap, "BOTTOM", -15, -35)
            else
                -- Default position: slightly left of center below the minimap
                durabilityFrame:SetPoint("TOP", Minimap, "BOTTOM", -15, -5)
            end
            durabilityFrame.DragonUI_SettingPoint = nil
        end
    end

    -- Hook DurabilityFrame:SetPoint to prevent Blizzard from overriding our position
    if durabilityFrame and not durabilityFrame._dragonUISetPointHooked then
        hooksecurefunc(durabilityFrame, "SetPoint", function(self)
            if not self.DragonUI_SettingPoint then
                self.DragonUI_SettingPoint = true
                self:ClearAllPoints()
                if durability_captureBarActive then
                    self:SetPoint("TOP", Minimap, "BOTTOM", -15, -35)
                else
                    self:SetPoint("TOP", Minimap, "BOTTOM", -15, -5)
                end
                self.DragonUI_SettingPoint = nil
            end
        end)
        durabilityFrame._dragonUISetPointHooked = true
    end

    local minimapBattlefieldFrame = MiniMapBattlefieldFrame
    minimapBattlefieldFrame:ClearAllPoints()
    minimapBattlefieldFrame:SetPoint("BOTTOMLEFT", 8, 2)

    if not isHybridMode then
        -- DragonUI positioning for elements anchored to the border top
        local minimapInstanceFrame = MiniMapInstanceDifficulty
        minimapInstanceFrame:ClearAllPoints()
        minimapInstanceFrame:SetPoint("TOP", MinimapBorderTop, 'BOTTOMRIGHT', -20, 6)
        minimapInstanceFrame:SetScale(0.85) -- Fixed scale for difficulty icon

        local minimapTracking = MiniMapTracking
        minimapTracking:ClearAllPoints()
        minimapTracking:SetPoint("RIGHT", MinimapBorderTop, "LEFT", -3, 0)
        minimapTracking:SetSize(26, 24)

        local minimapMailFrame = MiniMapMailFrame
        minimapMailFrame:ClearAllPoints()
        minimapMailFrame:SetPoint("TOP", minimapTracking, "BOTTOM", 0, -3)
        minimapMailFrame:SetSize(20, 14)
        minimapMailFrame:SetHitRectInsets(0, 0, 0, 0)

        local minimapMailIconTexture = MiniMapMailIcon
        minimapMailIconTexture:SetAllPoints(minimapMailFrame)
        minimapMailIconTexture:set_atlas('Minimap-Mail-Normal', true)

        local backgroundTexture = _G[minimapTracking:GetName() .. "Background"]
        backgroundTexture:SetAllPoints(minimapTracking)
        backgroundTexture:set_atlas('Minimap-Tracking-Background', true)

        local minimapTrackingButton = _G[minimapTracking:GetName() .. 'Button']
        minimapTrackingButton:ClearAllPoints()
        minimapTrackingButton:SetPoint("CENTER", 0, 0)

        minimapTrackingButton:SetSize(17, 15)
        minimapTrackingButton:SetHitRectInsets(0, 0, 0, 0)

        --  Enable right-click functionality
        minimapTrackingButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local shineTexture = _G[minimapTrackingButton:GetName() .. "Shine"]
        shineTexture:SetTexture(nil)

        local normalTexture = minimapTrackingButton:GetNormalTexture() or minimapTrackingButton:CreateTexture(nil, "BORDER")
        normalTexture:SetAllPoints(minimapTrackingButton)
        normalTexture:set_atlas('Minimap-Tracking-Normal', true)

        minimapTrackingButton:SetNormalTexture(normalTexture)

        local highlightTexture = minimapTrackingButton:GetHighlightTexture()
        highlightTexture:SetAllPoints(minimapTrackingButton)
        highlightTexture:set_atlas('Minimap-Tracking-Highlight', true)

        local pushedTexture = minimapTrackingButton:GetPushedTexture() or minimapTrackingButton:CreateTexture(nil, "BORDER")
        pushedTexture:SetAllPoints(minimapTrackingButton)
        pushedTexture:set_atlas('Minimap-Tracking-Pushed', true)

        minimapTrackingButton:SetPushedTexture(pushedTexture)
    end
    -- else: In hybrid mode, SexyMap's Buttons module handles tracking/mail positioning

    -- Resolve minimapTrackingButton at outer scope for click scripts below
    -- (the local above is only in the non-hybrid block)
    local minimapTrackingButton = _G[MiniMapTracking:GetName() .. 'Button']

    local minimapFrame = Minimap
    minimapFrame:ClearAllPoints()
    minimapFrame:SetPoint("CENTER", minimapCluster, "CENTER", 0, -25)
    minimapFrame:SetWidth(DEFAULT_MINIMAP_WIDTH / blipScale)
    minimapFrame:SetHeight(DEFAULT_MINIMAP_HEIGHT / blipScale)
    minimapFrame:SetScale(blipScale)
    MinimapModule.activeMinimapScale = blipScale

    -- In hybrid mode, don't override SexyMap's mask (it controls shape)
    if not isHybridMode then
        UpdateMinimapMaskForRotation()
    end

    -- POI (Point of Interest) Custom Textures
    minimapFrame:SetStaticPOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-static")
    minimapFrame:SetCorpsePOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-corpse")
    minimapFrame:SetPOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-guard")
    minimapFrame:SetPlayerTexture("Interface\\AddOns\\DragonUI\\assets\\poi-player")

    -- Player arrow size (configurable)
    local playerArrowSize = addon.db and addon.db.profile and addon.db.profile.minimap and
                                addon.db.profile.minimap.player_arrow_size or 16
    minimapFrame:SetPlayerTextureHeight(playerArrowSize)
    minimapFrame:SetPlayerTextureWidth(playerArrowSize)

    -- Blip texture (configurable: new DragonUI icons vs old Blizzard icons)
    local useNewBlipStyle = addon.db and addon.db.profile and addon.db.profile.minimap and
                                addon.db.profile.minimap.blip_skin
    if useNewBlipStyle == nil then
        useNewBlipStyle = true -- Default to new style
    end

    local blipTexture = useNewBlipStyle and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or
                            'Interface\\Minimap\\ObjectIcons'
    minimapFrame:SetBlipTexture(blipTexture)

    -- =====================================================================
    -- BLIP TEXTURE PROTECTION: Override SetBlipTexture with a filter wrapper.
    -- Uses method override (pre-hook) instead of hooksecurefunc (post-hook)
    -- to intercept BEFORE the texture changes, eliminating any flicker from
    -- addons like Carbonite that call SetBlipTexture on a repeating timer.
    -- =====================================================================
    if not MinimapModule.hooks.SetBlipTexture then
        -- Public function: re-applies all DragonUI minimap textures
        -- Called by compatibility module after conflicting addons load
        MinimapModule.ReapplyMinimapTextures = function()
            local useNew = addon.db and addon.db.profile and addon.db.profile.minimap and
                               addon.db.profile.minimap.blip_skin
            if useNew == nil then useNew = true end

            local tex = useNew and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or
                            'Interface\\Minimap\\ObjectIcons'

            MinimapModule._settingBlipTexture = true
            Minimap:SetBlipTexture(tex)
            MinimapModule._settingBlipTexture = false

            -- Re-apply POI textures (Carbonite resets these on init)
            Minimap:SetStaticPOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-static")
            Minimap:SetCorpsePOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-corpse")
            Minimap:SetPOIArrowTexture("Interface\\AddOns\\DragonUI\\assets\\poi-guard")
            Minimap:SetPlayerTexture("Interface\\AddOns\\DragonUI\\assets\\poi-player")
            -- Only re-apply mask if not in hybrid mode (SexyMap controls the mask/shape)
            local hybridCheck = MinimapModule.sexyMapHybridMode
                or (addon.db and addon.db.profile and addon.db.profile.modules
                    and addon.db.profile.modules.minimap
                    and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))
            if not hybridCheck then
                UpdateMinimapMaskForRotation()
            end
        end

        -- Override SetBlipTexture: blocks external calls when our custom blip skin is active,
        -- passes through when using classic style or module is disabled
        local origSetBlipTexture = Minimap.SetBlipTexture
        Minimap.SetBlipTexture = function(self, texture)
            -- DragonUI's own calls always pass through
            if MinimapModule._settingBlipTexture then
                return origSetBlipTexture(self, texture)
            end
            -- If module is active with custom blip skin, block external changes
            if IsModuleEnabled() and MinimapModule.applied then
                local useNew = addon.db and addon.db.profile and addon.db.profile.minimap
                                   and addon.db.profile.minimap.blip_skin
                if useNew then
                    return -- Block: keep our custom texture
                end
            end
            -- Module disabled or classic blip style: let it through
            return origSetBlipTexture(self, texture)
        end
        MinimapModule.hooks.SetBlipTexture = true
        MinimapModule._origSetBlipTexture = origSetBlipTexture
    end

    local MINIMAP_POINTS = {}
    for i = 1, Minimap:GetNumPoints() do
        MINIMAP_POINTS[i] = {Minimap:GetPoint(i)}
    end

    for _, regions in ipairs {Minimap:GetChildren()} do
        if regions ~= WatchFrame and regions ~= _G.WatchFrame then
            if regions:GetObjectType() == "Button" and not IsFrameWhitelisted(regions:GetName()) then
                regions:SetScale((1 / blipScale) * (1 + ADDON_ORBIT_RADIUS / 100))
            else
                regions:SetScale(1 / blipScale)
            end
        end
    end

    for _, points in ipairs(MINIMAP_POINTS) do
        Minimap:SetPoint(points[1], points[2], points[3], points[4] / blipScale, points[5] / blipScale)
    end
    function GetMinimapShape()
        return "ROUND"
    end

    -- Enable mouse wheel zooming on minimap
    minimapFrame:EnableMouseWheel(true)
    minimapFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            -- Scroll up = Zoom in
            Minimap_ZoomIn()
        else
            -- Scroll down = Zoom out
            Minimap_ZoomOut()
        end
    end)

    -- In hybrid mode, don't touch MinimapBackdrop, border, circle, or zoom button skins
    -- SexyMap controls all visual elements; DragonUI only handles positioning
    if not isHybridMode then
        local minimapBackdropTexture = MinimapBackdrop
        minimapBackdropTexture:ClearAllPoints()
        minimapBackdropTexture:SetPoint("CENTER", minimapFrame, "CENTER", 0, 3)
        MinimapModule.backdropYOffset = 3

        local minimapBorderTexture = MinimapBorder
        minimapBorderTexture:Hide()
        if not Minimap.Circle then
            Minimap.Circle = MinimapBackdrop:CreateTexture(nil, 'ARTWORK')
            Minimap.Circle:SetTexture("Interface\\AddOns\\DragonUI\\assets\\uiminimapborder.tga")
        end
        UpdateMinimapCircleSize()

        local zoomInButton = MinimapZoomIn
        zoomInButton:ClearAllPoints()
        zoomInButton:SetPoint("BOTTOMRIGHT", 0, 15)

        zoomInButton:SetSize(25, 24)
        zoomInButton:SetHitRectInsets(0, 0, 0, 0)

        normalTexture = zoomInButton:GetNormalTexture()
        normalTexture:SetAllPoints(zoomInButton)
        normalTexture:set_atlas('Minimap-ZoomIn-Normal', true)

        highlightTexture = zoomInButton:GetHighlightTexture()
        highlightTexture:SetAllPoints(zoomInButton)
        highlightTexture:set_atlas('Minimap-ZoomIn-Highlight', true)

        pushedTexture = zoomInButton:GetPushedTexture()
        pushedTexture:SetAllPoints(zoomInButton)
        pushedTexture:set_atlas('Minimap-ZoomIn-Pushed', true)

        local disabledTexture = zoomInButton:GetDisabledTexture()
        disabledTexture:SetAllPoints(zoomInButton)
        disabledTexture:set_atlas('Minimap-ZoomIn-Pushed', true)

        local zoomOutButton = MinimapZoomOut
        zoomOutButton:ClearAllPoints()
        zoomOutButton:SetPoint("BOTTOMRIGHT", -22, 0)

        zoomOutButton:SetSize(20, 12)
        zoomOutButton:SetHitRectInsets(0, 0, 0, 0)

        normalTexture = zoomOutButton:GetNormalTexture()
        normalTexture:SetAllPoints(zoomOutButton)
        normalTexture:set_atlas('Minimap-ZoomOut-Normal', true)

        highlightTexture = zoomOutButton:GetHighlightTexture()
        highlightTexture:SetAllPoints(zoomOutButton)
        highlightTexture:set_atlas('Minimap-ZoomOut-Highlight', true)

        pushedTexture = zoomOutButton:GetPushedTexture()
        pushedTexture:SetAllPoints(zoomOutButton)
        pushedTexture:set_atlas('Minimap-ZoomOut-Pushed', true)

        disabledTexture = zoomOutButton:GetDisabledTexture()
        disabledTexture:SetAllPoints(zoomOutButton)
        disabledTexture:set_atlas('Minimap-ZoomOut-Pushed', true)
    end -- not isHybridMode (backdrop, border, circle, zoom buttons)

    -- Reposition a single WorldStateCaptureBar to below the minimap
    local function RepositionCaptureBar(bar)
        if not bar then return end
        if not bar._dragonUISetPointHooked then
            -- Post-hook SetPoint to re-apply our positioning after any Blizzard repositioning
            hooksecurefunc(bar, "SetPoint", function(self, point, relativeTo, relativePoint)
                if not (point == 'CENTER' and relativeTo == minimapFrame and relativePoint == 'BOTTOM') then
                    if not self.DragonUI_SettingPoint then
                        self.DragonUI_SettingPoint = true
                        self:ClearAllPoints()
                        self:SetPoint('CENTER', minimapFrame, 'BOTTOM', 0, -20)
                        self.DragonUI_SettingPoint = nil
                    end
                end
            end)
            -- Hook Show/Hide to update durability position dynamically
            hooksecurefunc(bar, "Show", function() UpdateDurabilityPosition(true) end)
            hooksecurefunc(bar, "Hide", function() UpdateDurabilityPosition(false) end)
            -- OnHide fires after the frame is actually hidden (more reliable than Hide hook)
            bar:HookScript("OnHide", function() UpdateDurabilityPosition(false) end)
            bar:HookScript("OnShow", function() UpdateDurabilityPosition(true) end)
            bar._dragonUISetPointHooked = true
        end
        -- Always force our position (safe even with the hook's recursion guard)
        if not bar.DragonUI_SettingPoint then
            bar.DragonUI_SettingPoint = true
            bar:ClearAllPoints()
            bar:SetPoint('CENTER', minimapFrame, 'BOTTOM', 0, -20)
            bar.DragonUI_SettingPoint = nil
        end
    end

    -- Check and reposition all capture bars (there can be multiple in some BGs)
    local function SetupWorldStateCaptureBar()
        local anyVisible = false
        for i = 1, 5 do
            local bar = _G['WorldStateCaptureBar' .. i]
            if bar then
                RepositionCaptureBar(bar)
                if bar:IsVisible() then
                    anyVisible = true
                end
            end
        end
        -- Update durability frame position based on capture bar visibility
        UpdateDurabilityPosition(anyVisible)
        return anyVisible
    end

    -- Try to setup immediately (frame rarely exists at load time)
    SetupWorldStateCaptureBar()

    -- Hook UIParent_ManageFramePositions -Blizzard calls this AFTER creating/repositioning
    -- capture bars, so by the time our post-hook runs the frame is guaranteed to exist
    if UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", SetupWorldStateCaptureBar)
    end

    -- Also listen for key events as a safety net
    local captureBarWatcher = CreateFrame("Frame")
    local captureBarDelayFrame = CreateFrame("Frame")
    local captureBarDelayElapsed = 0
    local captureBarDelayRetries = 0
    captureBarWatcher:RegisterEvent("UPDATE_WORLD_STATES")
    captureBarWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    captureBarWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    captureBarWatcher:RegisterEvent("ZONE_CHANGED")
    captureBarWatcher:SetScript("OnEvent", function(self, event)
        SetupWorldStateCaptureBar()
        -- After reload/login, capture bars may not exist yet -do delayed re-checks
        if event == "PLAYER_ENTERING_WORLD" then
            captureBarDelayElapsed = 0
            captureBarDelayRetries = 0
            captureBarDelayFrame:SetScript("OnUpdate", function(delaySelf, dt)
                captureBarDelayElapsed = captureBarDelayElapsed + dt
                if captureBarDelayElapsed >= 0.5 then
                    captureBarDelayElapsed = 0
                    captureBarDelayRetries = captureBarDelayRetries + 1
                    SetupWorldStateCaptureBar()
                    -- Stop after 5 retries (2.5 seconds total)
                    if captureBarDelayRetries >= 5 then
                        delaySelf:SetScript("OnUpdate", nil)
                    end
                end
            end)
        end
    end)

    -- In hybrid mode, don't override tracking button scripts -SexyMap's Buttons module handles them
    if not isHybridMode then
        --  Add right-click functionality to clear tracking
        minimapTrackingButton:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                -- Set tracking to none
                SetTracking()
                -- Update the tracking display
                MinimapModule:UpdateTrackingIcon()

            else
                -- Left click - use default behavior
                ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "MiniMapTrackingButton")
            end
        end)

        --  MANUALLY CONTROL BUTTON MOVEMENT
        minimapTrackingButton:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                -- Move the icon/button manually - YOU CONTROL HOW MUCH
                if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                    -- Move icon OLD STYLE: 1 pixel down-right (subtle)
                    MiniMapTrackingIcon:ClearAllPoints()
                    MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 2, -2)
                end
            end
        end)

        minimapTrackingButton:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                -- Restore original position on release
                if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                    MiniMapTrackingIcon:ClearAllPoints()
                    MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
                end
            end
        end)

        --  HOOK TO RESET ICON POSITION AFTER CLICKS
        local function ResetTrackingIconPosition()
            if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                MiniMapTrackingIcon:ClearAllPoints()
                MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
            end
        end
    end -- not isHybridMode (tracking button scripts)

    -- Setup secure hooks after frame modifications (handles CloseDropDownMenus)
    SetupSecureHooks()

end -- End of ReplaceBlizzardFrame function

local function CreateMinimapBorderFrame(width, height)
    local minimapBorderFrame = CreateFrame('Frame', UIParent)
    minimapBorderFrame:SetSize(width, height)
    minimapBorderFrame._duiHeavyUpdateElapsed = 0
    minimapBorderFrame._duiRotationElapsed = 0
    minimapBorderFrame._duiLastRotateEnabled = nil
    minimapBorderFrame._duiLastAppliedAngle = nil
    minimapBorderFrame:SetScript("OnUpdate", function(self, elapsed)
        if not IsDragonUIMinimapControlling() then return end

        local rotateEnabled = GetCVar("rotateMinimap") == "1"
        local rotationInterval = rotateEnabled and 0.016 or 0.05

        self._duiRotationElapsed = self._duiRotationElapsed + elapsed
        if self._duiRotationElapsed >= rotationInterval then
            self._duiRotationElapsed = 0

            local facing = GetPlayerFacing()
            if Minimap and Minimap.Circle and facing then
                if rotateEnabled then
                    local desiredAngle = -facing
                    local shouldApply = true

                    if self._duiLastAppliedAngle then
                        local delta = math.abs(desiredAngle - self._duiLastAppliedAngle)
                        if delta > math.pi then
                            delta = (2 * math.pi) - delta
                        end
                        -- Skip tiny angle changes to keep CPU stable while preserving smoothness.
                        shouldApply = delta >= 0.0025
                    end

                    if shouldApply then
                        ApplyTextureRotation(Minimap.Circle, desiredAngle)
                        self._duiLastAppliedAngle = desiredAngle
                    end
                elseif self._duiLastRotateEnabled then
                    if Minimap.Circle.SetRotation then
                        Minimap.Circle:SetRotation(0)
                    else
                        Minimap.Circle:SetTexCoord(0, 1, 0, 1)
                    end
                    self._duiLastAppliedAngle = nil
                end
            end

            self._duiLastRotateEnabled = rotateEnabled
        end

        self._duiHeavyUpdateElapsed = self._duiHeavyUpdateElapsed + elapsed
        if self._duiHeavyUpdateElapsed >= 0.1 then
            self._duiHeavyUpdateElapsed = 0
            UpdateIndoorRotationPolicy()
            UpdateMinimapMaskForRotation()
            UpdateMinimapBackdropAlignment(false)
            UpdateIndoorRotateScale()
            UpdateMinimapCircleSize()
        end
    end)

    do
        local texture = minimapBorderFrame:CreateTexture(nil, "BORDER")
        texture:SetAllPoints(minimapBorderFrame)
        texture:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\Minimap\\MinimapBorder.blp")
        texture:SetAlpha(0)

        minimapBorderFrame.border = texture
    end

    minimapBorderFrame:Hide()
    return minimapBorderFrame
end

-- Helper: is addon button fade currently enabled?
local function IsFadeEnabled()
    return addon.db and addon.db.profile and addon.db.profile.minimap
        and addon.db.profile.minimap.addon_button_fade or false
end

-- Collector buttons should stay fully visible inside the collector box.
local function IsInsideCollector(button)
    local collector = MinimapModule.frames and MinimapModule.frames.iconCollector
    return collector and button and button:GetParent() == collector
end

-- Fade functions for hover effect (check setting dynamically)
local function fadein(self)
    if IsInsideCollector(self) then
        self:SetAlpha(1)
        return
    end
    if not IsFadeEnabled() then return end
    securecall(UIFrameFadeIn, self, 0.2, self:GetAlpha(), 1.0)
end

local function fadeout(self)
    if IsInsideCollector(self) then
        self:SetAlpha(1)
        return
    end
    if not IsFadeEnabled() then return end
    securecall(UIFrameFadeOut, self, 0.2, self:GetAlpha(), 0.2)
end

-- Function to apply custom skin to addon icons
-- Non-destructive: repositions originals, creates border overlay; all reversible.
local function ApplyAddonIconSkin(button)
    if not button or button:GetObjectType() ~= 'Button' then
        return
    end

    local frameName = button:GetName()
    if IsQuestMinimapPin(button) then
        return
    end

    -- First-time setup: catalogue regions and create overlay (only once)
    if not button.DragonUI_Skinned then
        button.DragonUI_Skinned = true

        -- Save original size
        button.DragonUI_OrigW, button.DragonUI_OrigH = button:GetSize()

        -- Classify original regions into "decoration" (border/bg), "highlight" (hover effect), and "icon"
        button.DragonUI_DecoRegions = {}
        button.DragonUI_HighlightRegions = {}
        button.DragonUI_IconRegions = {}
        button.DragonUI_PrimaryIconRegions = {}
        button.DragonUI_ExtraIconRegions = {}
        button.DragonUI_UsesStateTextures = false
        local seenRegions = {}

        local function SaveRegionState(region)
            if not region or seenRegions[region] then
                return
            end
            seenRegions[region] = true

            local numPoints = region:GetNumPoints()
            region.DragonUI_OrigPoints = {}
            for p = 1, numPoints do
                region.DragonUI_OrigPoints[p] = { region:GetPoint(p) }
            end
            region.DragonUI_OrigW, region.DragonUI_OrigH = region:GetWidth(), region:GetHeight()
            region.DragonUI_OrigLayer = region:GetDrawLayer()
            region.DragonUI_OrigAlpha = region:GetAlpha()
            region.DragonUI_OrigTexCoord = { region:GetTexCoord() }
        end

        local normalTex = button:GetNormalTexture()
        local pushedTex = button:GetPushedTexture()
        if normalTex and pushedTex and normalTex:GetTexture() and pushedTex:GetTexture() then
            button.DragonUI_UsesStateTextures = true
        end

        for index = 1, button:GetNumRegions() do
            local region = select(index, button:GetRegions())
            if region:GetObjectType() == 'Texture' then
                local tex = region:GetTexture()
                local texStr = tex and tostring(tex) or ""
                local layer = region:GetDrawLayer()
                if layer == 'HIGHLIGHT' then
                    -- Highlight textures: save original state for restore
                    SaveRegionState(region)
                    table.insert(button.DragonUI_HighlightRegions, region)
                elseif texStr:find('Border') or texStr:find('Background') or texStr:find('AlphaMask') then
                    region.DragonUI_OrigAlpha = region:GetAlpha()
                    table.insert(button.DragonUI_DecoRegions, region)
                else
                    -- Save original anchoring/size for icon regions
                    SaveRegionState(region)
                    table.insert(button.DragonUI_IconRegions, region)
                end
            end
        end

        -- Ensure state textures are tracked even when not exposed by GetRegions().
        if normalTex and normalTex:GetObjectType() == 'Texture' and not seenRegions[normalTex] then
            SaveRegionState(normalTex)
            table.insert(button.DragonUI_IconRegions, normalTex)
        end
        if pushedTex and pushedTex:GetObjectType() == 'Texture' and not seenRegions[pushedTex] then
            SaveRegionState(pushedTex)
            table.insert(button.DragonUI_IconRegions, pushedTex)
        end

        local highlightTex = button:GetHighlightTexture()
        if highlightTex and highlightTex:GetObjectType() == 'Texture' and not seenRegions[highlightTex] then
            SaveRegionState(highlightTex)
            table.insert(button.DragonUI_HighlightRegions, highlightTex)
        end

        -- Select icon textures to skin: for stateful buttons use normal+pushed only.
        if button.DragonUI_UsesStateTextures and normalTex and normalTex:GetObjectType() == 'Texture' then
            table.insert(button.DragonUI_PrimaryIconRegions, normalTex)
            if pushedTex and pushedTex:GetObjectType() == 'Texture' then
                table.insert(button.DragonUI_PrimaryIconRegions, pushedTex)
            end
            for _, region in ipairs(button.DragonUI_IconRegions) do
                if region ~= normalTex and region ~= pushedTex then
                    table.insert(button.DragonUI_ExtraIconRegions, region)
                end
            end
        else
            button.DragonUI_PrimaryIconRegions = button.DragonUI_IconRegions
        end

        -- Create circle border overlay (once)
        button.circle = button:CreateTexture(nil, 'OVERLAY')
        button.circle:SetSize(23, 23)
        button.circle:SetPoint('CENTER', button)
        button.circle:SetTexture("Interface\\AddOns\\DragonUI\\assets\\border_buttons.tga")

        -- Hook fade (once, permanent; functions check IsFadeEnabled() dynamically)
        if not button.DragonUI_FadeHooked then
            button.DragonUI_FadeHooked = true
            button:HookScript('OnEnter', fadein)
            button:HookScript('OnLeave', fadeout)
        end
    end

    -- === ACTIVATE skinned state ===
    button.DragonUI_SkinActive = true
    local skinSize = button.DragonUI_UsesStateTextures and 24 or 21
    button:SetSize(skinSize, skinSize)

    -- Hide decoration regions (borders, backgrounds)
    for _, region in ipairs(button.DragonUI_DecoRegions) do
        region:SetAlpha(0)
    end

    -- Keep only primary icon regions visible while skinned.
    for _, region in ipairs(button.DragonUI_ExtraIconRegions) do
        region:SetAlpha(0)
    end

    -- Reposition primary icon regions.
    for _, region in ipairs(button.DragonUI_PrimaryIconRegions) do
        region:SetAlpha(1)
        region:ClearAllPoints()
        local inset = button.DragonUI_UsesStateTextures and 0 or 2
        region:SetPoint('TOPLEFT', button, 'TOPLEFT', inset, -inset)
        region:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -inset, inset)

        if button.DragonUI_UsesStateTextures and region.DragonUI_OrigTexCoord then
            region:SetTexCoord(unpack(region.DragonUI_OrigTexCoord))
        else
            region:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        end

        region:SetDrawLayer('ARTWORK')
    end

    -- Reposition highlight regions to fit skinned button (auto-show on hover by WoW)
    for _, region in ipairs(button.DragonUI_HighlightRegions) do
        region:ClearAllPoints()
        region:SetAllPoints(button)
    end

    -- Show DragonUI circle border
    if button.circle then
        button.circle:SetSize(button.DragonUI_UsesStateTextures and 26 or 23, button.DragonUI_UsesStateTextures and 26 or 23)
        button.circle:Show()
    end

    -- Set alpha based on fade setting
    button:SetAlpha(IsFadeEnabled() and 0.2 or 1)
end

-- Restore original button appearance (non-destructive toggle)
local function UnskinAddonButton(button)
    if not button or not button.DragonUI_Skinned then return end

    button.DragonUI_SkinActive = false

    -- Restore original size
    if button.DragonUI_OrigW then
        button:SetSize(button.DragonUI_OrigW, button.DragonUI_OrigH)
    end

    -- Restore decoration regions
    if button.DragonUI_DecoRegions then
        for _, region in ipairs(button.DragonUI_DecoRegions) do
            region:SetAlpha(region.DragonUI_OrigAlpha or 1)
        end
    end

    -- Restore icon regions to original positioning
    if button.DragonUI_IconRegions then
        for _, region in ipairs(button.DragonUI_IconRegions) do
            region:SetAlpha(region.DragonUI_OrigAlpha or 1)
            if region.DragonUI_OrigTexCoord then
                region:SetTexCoord(unpack(region.DragonUI_OrigTexCoord))
            else
                region:SetTexCoord(0, 1, 0, 1)
            end
            region:SetDrawLayer(region.DragonUI_OrigLayer or 'ARTWORK')
            region:ClearAllPoints()
            if region.DragonUI_OrigPoints then
                for _, pt in ipairs(region.DragonUI_OrigPoints) do
                    region:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
                end
            else
                region:SetAllPoints(button)
            end
            if region.DragonUI_OrigW then
                region:SetSize(region.DragonUI_OrigW, region.DragonUI_OrigH)
            end
        end
    end

    -- Restore highlight regions to original positioning
    if button.DragonUI_HighlightRegions then
        for _, region in ipairs(button.DragonUI_HighlightRegions) do
            region:ClearAllPoints()
            if region.DragonUI_OrigPoints then
                for _, pt in ipairs(region.DragonUI_OrigPoints) do
                    region:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
                end
            else
                region:SetAllPoints(button)
            end
            if region.DragonUI_OrigW then
                region:SetSize(region.DragonUI_OrigW, region.DragonUI_OrigH)
            end
        end
    end

    -- Hide DragonUI circle border
    if button.circle then button.circle:Hide() end

    -- Full alpha
    button:SetAlpha(1)
end

-- Skin addon icons by removing borders

-- Collect all minimap-related buttons from multiple parent frames
-- Some addons (e.g. Carbonite) parent buttons to MinimapBackdrop instead of Minimap
-- NOTE: Do NOT scan MinimapCluster - it contains Blizzard UI buttons (zone text,
-- zoom buttons, clock, etc.) that should never be skinned as addon icons.
local BLIZZARD_MINIMAP_BUTTONS = {
    ['MinimapZoneTextButton'] = true,
    ['MinimapZoomIn'] = true,
    ['MinimapZoomOut'] = true,
    ['MiniMapWorldMapButton'] = true,
    ['MinimapBackdrop'] = true,
    ['MiniMapBattlefieldFrame'] = true,
    ['MiniMapTrackingButton'] = true,
    ['MiniMapMailFrame'] = true,
    ['GameTimeFrame'] = true,
    ['TimeManagerClockButton'] = true,
    ['MiniMapInstanceDifficulty'] = true,
    ['MiniMapLFGFrame'] = true,   -- dungeon eye -has its own styling, skip skin
    ['MiniMapVoiceChatFrame'] = true,
    ['MiniMapVoiceChatFrameIcon'] = true,
    ['DragonUI_MinimapSettingsButton'] = true,
}

local function GetAllMinimapButtons()
    local buttons = {}
    local seen = {}

    local function TryAddButton(button)
        if not button or seen[button] or button:GetObjectType() ~= "Button" then
            return
        end

        local buttonName = button:GetName()
        if buttonName and BLIZZARD_MINIMAP_BUTTONS[buttonName] then
            return
        end
        if IsQuestMinimapPin(button) then
            return
        end

        seen[button] = true
        table.insert(buttons, button)
    end

    -- Scan direct Button children, plus one level of Frame wrappers (e.g. AtlasButtonFrame > AtlasButton).
    local function ScanFrame(parentFrame, nested)
        if not parentFrame then
            return
        end
        
        -- Addons like Questie parent hundreds of map pins directly to Minimap, which overflows the Lua
        -- C stack before we can filter them. pcall catches that error so we fail gracefully instead of
        -- spamming an error every frame.
        local ok, children = pcall(function() return { parentFrame:GetChildren() } end)
        if not ok then return end
        for i = 1, #children do
            local child = children[i]
            if not child then
            elseif child:GetObjectType() == "Button" then
                TryAddButton(child)
            elseif not nested and child:GetObjectType() == "Frame" then
                local childName = child:GetName()
                if not (childName and BLIZZARD_MINIMAP_BUTTONS[childName]) then
                    ScanFrame(child, true)
                end
            end
        end
    end

    -- Scan Minimap and MinimapBackdrop only
    -- MinimapCluster is excluded: it contains Blizzard frames (zone text, zoom, etc.)
    ScanFrame(Minimap, false)
    ScanFrame(MinimapBackdrop, false)

    return buttons
end

-- EnableMouse doesn't cascade to children, so every clickable minimap element (native Blizzard
-- buttons, third-party addon icons, collected icons) needs to be listed individually for the
-- hidden-minimap click-through to actually let clicks pass through everywhere, not just the circle.
local function CollectMinimapClickThroughFrames()
    local frames = {}
    for name in pairs(BLIZZARD_MINIMAP_BUTTONS) do
        -- MinimapBackdrop excluded: mouse-off overlay over the circle; enabling it eats native blip tooltips.
        local namedFrame = name ~= 'MinimapBackdrop' and _G[name]
        if namedFrame then table.insert(frames, namedFrame) end
    end
    for _, btn in ipairs(GetAllMinimapButtons()) do
        table.insert(frames, btn)
    end
    local iconCollector = MinimapModule.frames and MinimapModule.frames.iconCollector
    if iconCollector then
        local ok, children = pcall(function() return { iconCollector:GetChildren() } end)
        if ok then
            for _, child in ipairs(children) do
                if child and child.EnableMouse then table.insert(frames, child) end
            end
        end
    end
    return frames
end

-- Compatibility: some addons ship LibDBIcon with a larger default radius,
-- which pushes minimap addon buttons farther from the map edge.
-- Keep this defensive and minimal: only clamp excessive defaults while DragonUI minimap is active.
local function NormalizeLibDBIconRadius()
    if not LibStub or not LibStub.GetLibrary then
        return
    end

    local ok, libDBIcon = pcall(LibStub.GetLibrary, LibStub, "LibDBIcon-1.0", true)
    if not ok or not libDBIcon or type(libDBIcon.SetButtonRadius) ~= "function" then
        return
    end

    local currentRadius = tonumber(libDBIcon.radius)
    if not currentRadius or currentRadius <= 5 then
        return
    end

    if MinimapModule.originalStates.LibDBIconRadius == nil then
        MinimapModule.originalStates.LibDBIconRadius = currentRadius
    end

    libDBIcon:SetButtonRadius(-5)
end

local function RestoreLibDBIconRadius()
    local originalRadius = MinimapModule.originalStates.LibDBIconRadius
    if originalRadius == nil then
        return
    end

    if not LibStub or not LibStub.GetLibrary then
        return
    end

    local ok, libDBIcon = pcall(LibStub.GetLibrary, LibStub, "LibDBIcon-1.0", true)
    if ok and libDBIcon and type(libDBIcon.SetButtonRadius) == "function" then
        libDBIcon:SetButtonRadius(originalRadius)
    end

    MinimapModule.originalStates.LibDBIconRadius = nil
end

-- ============================================================================
-- MINIMAP ICON COLLECTOR (bridge to minimap_collector.lua)
-- ============================================================================

local function GetConfiguredMinimapCollector()
    local collector = addon and addon.MinimapCollector
    if not collector or type(collector.Configure) ~= "function" then
        return nil
    end

    collector:Configure({
        addon = addon,
        L = L,
        MinimapModule = MinimapModule,
        DRAGONUI_SETTINGS_BUTTON_SIZE = DRAGONUI_SETTINGS_BUTTON_SIZE,
        DRAGONUI_SETTINGS_BUTTON_ICON = DRAGONUI_SETTINGS_BUTTON_ICON,
        DRAGONUI_SETTINGS_BUTTON_ICON_FALLBACK = DRAGONUI_SETTINGS_BUTTON_ICON_FALLBACK,
        DRAGONUI_CLASSIC_COLLECTOR_ICON = DRAGONUI_CLASSIC_COLLECTOR_ICON,
        GetAllMinimapButtons = GetAllMinimapButtons,
        IsQuestMinimapPin = IsQuestMinimapPin,
        ApplyAddonIconSkin = ApplyAddonIconSkin,
        UnskinAddonButton = UnskinAddonButton,
        IsFadeEnabled = IsFadeEnabled,
        fadein = fadein,
        fadeout = fadeout,
    })

    return collector
end

local function RefreshIntegratedMinimapCollector()
    local collector = GetConfiguredMinimapCollector()
    if collector and collector.Refresh then
        collector:Refresh()
    end
end

local function ToggleIntegratedMinimapCollector()
    local collector = GetConfiguredMinimapCollector()
    if collector and collector.Toggle then
        collector:Toggle()
    end
end

local function HideIntegratedAddonMinimapButtons()
    local collector = GetConfiguredMinimapCollector()
    if collector and collector.HideIntegratedAddonButtons then
        collector:HideIntegratedAddonButtons()
    end
end

local function HideIntegratedMinimapCollector()
    local collector = GetConfiguredMinimapCollector()
    if collector and collector.Hide then
        collector:Hide()
    end
end

local function RestoreCollectedButtonsToOrigin()
    local collector = GetConfiguredMinimapCollector()
    if collector and collector.Restore then
        collector:Restore()
    end
end

local function UpdateDragonUISettingsButton()
    local collector = GetConfiguredMinimapCollector()
    if collector and collector.UpdateSettingsButton then
        collector:UpdateSettingsButton()
    end
end

-- Function to apply skins to all minimap buttons (exposed for re-application on addon load)
local function ApplySkinsToAllMinimapButtons()
    if not IsMinimapSystemActive() then return end

    local skinEnabled = addon.db and addon.db.profile and addon.db.profile.minimap and
                            addon.db.profile.minimap.addon_button_skin
    if not skinEnabled then return end

    local buttons = GetAllMinimapButtons()
    for _, child in ipairs(buttons) do
        -- Always re-apply. Some addons/editor transitions mutate existing icon regions in-place.
        ApplyAddonIconSkin(child)
    end
end

-- Update fade alpha on all addon buttons (works with or without skin)
local function UpdateAddonButtonFade()
    local fadeEnabled = IsFadeEnabled()
    local buttons = GetAllMinimapButtons()
    for _, child in ipairs(buttons) do
        if not IsQuestMinimapPin(child) then
            -- Hook fade scripts once if not already hooked
            if not child.DragonUI_FadeHooked then
                child.DragonUI_FadeHooked = true
                child:HookScript('OnEnter', fadein)
                child:HookScript('OnLeave', fadeout)
            end
            child:SetAlpha(fadeEnabled and 0.2 or 1)
        end
    end
end

-- Expose for options to trigger
MinimapModule.ApplySkinsToAllMinimapButtons = ApplySkinsToAllMinimapButtons

-- Unskin all addon buttons (toggle back to original Blizzard appearance)
local function UnskinAllMinimapButtons()
    local buttons = GetAllMinimapButtons()
    for _, child in ipairs(buttons) do
        if child.DragonUI_Skinned then
            UnskinAddonButton(child)
        end
    end
end
MinimapModule.UnskinAllMinimapButtons = UnskinAllMinimapButtons

local function RemoveAllMinimapIconBorders()

    -- PVP/Battlefield borders
    if MiniMapBattlefieldIcon then
        MiniMapBattlefieldIcon:Hide()
    end
    if MiniMapBattlefieldBorder then
        MiniMapBattlefieldBorder:Hide()
    end

    -- LFG border
    if MiniMapLFGFrameBorder then
        MiniMapLFGFrameBorder:SetTexture(nil)
    end

    -- Apply immediately
    ApplySkinsToAllMinimapButtons()
end

-- Create frame to re-apply skins when new addons load or after reload
local minimapButtonSkinFrame = CreateFrame("Frame")
minimapButtonSkinFrame:RegisterEvent("ADDON_LOADED")
minimapButtonSkinFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
minimapButtonSkinFrame:SetScript("OnEvent", function(self, event, addonName)
    if not IsMinimapSystemActive() then
        self:SetScript("OnUpdate", nil)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Watch for new minimap children for a few seconds after login/reload.
        -- Re-scan periodically: some addons mutate existing icon regions without changing child count.
        local skinEnabled = addon.db and addon.db.profile and addon.db.profile.minimap and
            addon.db.profile.minimap.addon_button_skin
        if skinEnabled then
            ApplySkinsToAllMinimapButtons()
        end
        UpdateCalendarDate()
        RefreshIntegratedMinimapCollector()
        local elapsed = 0
        local checkInterval = 0
        self:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed > 6.0 then
                self:SetScript("OnUpdate", nil)
                return
            end
            checkInterval = checkInterval + dt
            if checkInterval >= 0.3 then
                checkInterval = 0
                if skinEnabled then
                    ApplySkinsToAllMinimapButtons()
                end
                UpdateCalendarDate()
                RefreshIntegratedMinimapCollector()
            end
        end)
        return
    end

    -- ADDON_LOADED handling
    -- Skip DragonUI's own loading to avoid double-processing
    if addonName == "DragonUI" then return end

    -- Apply defensive LibDBIcon compatibility for late-loading addons.
    NormalizeLibDBIconRadius()

    -- Allow the loading addon to create its minimap button before we rescan.
    local skinEnabled = addon.db and addon.db.profile and addon.db.profile.minimap and
        addon.db.profile.minimap.addon_button_skin
    local elapsed = 0
    self:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed > 0.5 then
            if skinEnabled then
                ApplySkinsToAllMinimapButtons()
            end
            RefreshIntegratedMinimapCollector()
            self:SetScript("OnUpdate", nil)
        end
    end)
end)

local function GetUnmanagedCollectorButtonCount()
    local buttons = GetAllMinimapButtons()
    local settingsButton = MinimapModule.frames and MinimapModule.frames.settingsButton
    local count = 0

    for _, child in ipairs(buttons) do
        if child ~= settingsButton and not IsQuestMinimapPin(child) and not child.DragonUI_CollectorManaged then
            count = count + 1
        end
    end

    return count
end

local minimapCollectorSyncFrame = CreateFrame("Frame")
do
    local elapsed = 0
    local syncInterval = 1.00
    local lastUnmanagedCount = 0
    local lastMinimapChildCount = -1
    local lastBackdropChildCount = -1

    local function ResetSyncState()
        lastUnmanagedCount = 0
        lastMinimapChildCount = -1
        lastBackdropChildCount = -1
    end

    minimapCollectorSyncFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < syncInterval then
            return
        end
        elapsed = 0

        if not IsMinimapSystemActive() then
            ResetSyncState()
            return
        end

        local minimapConfig = addon.db and addon.db.profile and addon.db.profile.minimap
        if minimapConfig and minimapConfig.collector_enabled == false then
            ResetSyncState()
            return
        end

        local iconCollector = MinimapModule.frames and MinimapModule.frames.iconCollector
        if iconCollector and iconCollector.isOpen then
            ResetSyncState()
            return
        end

        local minimapChildCount = (Minimap and Minimap.GetNumChildren and Minimap:GetNumChildren()) or 0
        local backdropChildCount = (MinimapBackdrop and MinimapBackdrop.GetNumChildren and MinimapBackdrop:GetNumChildren()) or 0
        local childCountChanged = minimapChildCount ~= lastMinimapChildCount
            or backdropChildCount ~= lastBackdropChildCount

        if not childCountChanged then
            return
        end

        lastMinimapChildCount = minimapChildCount
        lastBackdropChildCount = backdropChildCount

        local unmanagedCount = GetUnmanagedCollectorButtonCount()
        if unmanagedCount <= 0 then
            lastUnmanagedCount = 0
            return
        end

        local shouldRefresh = unmanagedCount ~= lastUnmanagedCount

        lastUnmanagedCount = unmanagedCount

        if shouldRefresh then
            RefreshIntegratedMinimapCollector()
            if addon.VisibilityFade then
                addon.VisibilityFade.AddHoverFrames("minimap", CollectMinimapClickThroughFrames())
            end
        end
    end)
end

-- Style PVP battleground frame with faction detection
local function StylePVPBattlefieldFrame()
    if not MiniMapBattlefieldFrame then
        return
    end

    -- Configure the PVP frame like in minimapa_old.lua
    MiniMapBattlefieldFrame:SetSize(44, 44)
    MiniMapBattlefieldFrame:ClearAllPoints()
    MiniMapBattlefieldFrame:SetPoint('BOTTOMLEFT', Minimap, 0, 18)
    MiniMapBattlefieldFrame:SetNormalTexture('')
    MiniMapBattlefieldFrame:SetPushedTexture('')

    -- Detect player faction and apply appropriate textures
    local faction = string.lower(UnitFactionGroup('player'))

    -- Apply textures using set_atlas
    if MiniMapBattlefieldFrame:GetNormalTexture() then
        MiniMapBattlefieldFrame:GetNormalTexture():set_atlas('Minimap-PVP-' .. faction .. '-Normal', true)
    end
    if MiniMapBattlefieldFrame:GetPushedTexture() then
        MiniMapBattlefieldFrame:GetPushedTexture():set_atlas('Minimap-PVP-' .. faction .. '-Pushed', true)
    end

    -- Configure click script like in minimapa_old.lua
    MiniMapBattlefieldFrame:SetScript('OnClick', function(self, button)
        GameTooltip:Hide()
        if MiniMapBattlefieldFrame.status == "active" then
            if button == "RightButton" then
                ToggleDropDownMenu(1, nil, MiniMapBattlefieldDropDown, "MiniMapBattlefieldFrame", 0, -5)
            elseif IsShiftKeyDown() then
                ToggleBattlefieldMinimap()
            else
                ToggleWorldStateScoreFrame()
            end
        elseif button == "RightButton" then
            ToggleDropDownMenu(1, nil, MiniMapBattlefieldDropDown, "MiniMapBattlefieldFrame", 0, -5)
        else
            --  SIMPLE: Use the same function as the PVP micromenu button
            TogglePVPFrame()
        end
    end)
end

local function RemoveBlizzardFrames()
    -- Determine if hybrid mode is active
    local isHybridMode = MinimapModule.sexyMapHybridMode
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))

    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Hide()
        MiniMapWorldMapButton:UnregisterAllEvents()
        MiniMapWorldMapButton:SetScript("OnClick", nil)
        MiniMapWorldMapButton:SetScript("OnEnter", nil)
        MiniMapWorldMapButton:SetScript("OnLeave", nil)
    end

    -- In hybrid mode, don't hide tracking/mail elements -SexyMap's Buttons module manages them
    if not isHybridMode then
        local blizzFrames =
            {MiniMapTrackingIcon, MiniMapTrackingIconOverlay, MiniMapMailBorder, MiniMapTrackingButtonBorder}

        for _, frame in pairs(blizzFrames) do
            frame:SetAlpha(0)
        end
    end

    -- Hide vanilla north indicator and compass -DragonUI doesn't use them
    if MinimapNorthTag then MinimapNorthTag:Hide() end
    if MinimapCompassTexture then MinimapCompassTexture:Hide() end

    --  CALL THE NEW FUNCTIONS
    RemoveAllMinimapIconBorders()
    StylePVPBattlefieldFrame()
    UpdateDragonUISettingsButton()
end

-- Stored on module table so the hooksecurefunc post-hook can reference it
-- without calling the global (which would cause infinite recursion)
MinimapModule.UpdateRotation = function()
    if not IsDragonUIMinimapControlling() then return end

    UpdateIndoorRotationPolicy()

    -- In hybrid mode, let SexyMap control the border visibility
    local isHybridMode = MinimapModule.sexyMapHybridMode
        or MinimapModule._allowExternalBorderControl

    if not isHybridMode then
        -- Always hide the vanilla MinimapBorder -DragonUI uses Minimap.Circle instead.
        -- Blizzard's Minimap_UpdateRotationSetting re-shows MinimapBorder when rotation
        -- is toggled off (e.g. closing Interface Options); our post-hook must counteract that.
        if MinimapBorder then
            MinimapBorder:Hide()
        end
    end

    local rotateEnabled = GetCVar("rotateMinimap") == "1"
    local keepPolicyLoop = MinimapModule.forcingIndoorRotation == true

    -- Keep borderFrame visible while forcing indoor rotation OFF so OnUpdate can
    -- detect leaving indoor areas and restore the user's rotation preference.
    if rotateEnabled or keepPolicyLoop then
        if MinimapModule.borderFrame then
            MinimapModule.borderFrame:Show()
        end
        UpdateMinimapMaskForRotation()
        UpdateMinimapBackdropAlignment(false)
        UpdateIndoorRotateScale()
        UpdateMinimapCircleSize()
    else
        if MinimapModule.borderFrame then
            MinimapModule.borderFrame:Hide()
        end
        UpdateMinimapMaskForRotation()
        UpdateMinimapBackdropAlignment(false)
        UpdateIndoorRotateScale()
        UpdateMinimapCircleSize()
        if Minimap and Minimap.Circle then
            if Minimap.Circle.SetRotation then
                Minimap.Circle:SetRotation(0)
            else
                Minimap.Circle:SetTexCoord(0, 1, 0, 1)
            end
        end
    end

    MinimapNorthTag:Hide()
    MinimapCompassTexture:Hide()
end

local selectedRaidDifficulty
local allowedRaidDifficulty

-- Update tracking icon using atlas textures
function MinimapModule:UpdateTrackingIcon()
    -- In hybrid mode, don't override tracking icon -SexyMap controls it
    local isHybridMode = self.sexyMapHybridMode
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))
    if isHybridMode then return end

    local texture = GetTrackingTexture()

    local useOldStyle = addon.db and addon.db.profile and addon.db.profile.minimap and
                            addon.db.profile.minimap.tracking_icons

    --  SECURITY CHECK
    if not addon or not addon.db then
        return
    end

    if useOldStyle == nil then
        useOldStyle = false
    end

    --  ADDITIONAL CHECK: Ensure frames exist
    if not MiniMapTrackingIcon or not MiniMapTrackingButton then
        return
    end

    if useOldStyle then

        if texture == 'Interface\\Minimap\\Tracking\\None' then

            -- OLD STYLE + No tracking = Show default magnifying glass icon
            MiniMapTrackingIcon:SetTexture('')
            MiniMapTrackingIcon:SetAlpha(0)

            -- Show the modern button as default "magnifying glass icon"
            local normalTexture = MiniMapTrackingButton:GetNormalTexture()
            if normalTexture then
                normalTexture:set_atlas('Minimap-Tracking-Normal', true)
            end

            local pushedTexture = MiniMapTrackingButton:GetPushedTexture()
            if pushedTexture then
                pushedTexture:set_atlas('Minimap-Tracking-Pushed', true)
            end

            local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
            if highlightTexture then
                highlightTexture:set_atlas('Minimap-Tracking-Highlight', true)
            end
        else

            -- OLD STYLE + Tracking active = Show the specific tracking icon
            MiniMapTrackingIcon:SetTexture(texture)
            MiniMapTrackingIcon:SetTexCoord(0, 1, 0, 1)
            MiniMapTrackingIcon:SetSize(20, 20)
            MiniMapTrackingIcon:SetAlpha(1)
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)

            -- Clear button textures so they don't interfere with the specific icon
            MiniMapTrackingButton:SetNormalTexture('')
            MiniMapTrackingButton:SetPushedTexture('')
            local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
            if highlightTexture then
                highlightTexture:SetTexture('')
            end
        end
    else

        --  MODERN STYLE: Always show modern button (RetailUI style)

        -- Clear the classic icon so it doesn't interfere
        MiniMapTrackingIcon:SetTexture('')
        MiniMapTrackingIcon:SetAlpha(0)

        -- Use the RetailUI textures that already work (the ones from ReplaceBlizzardFrame)
        local normalTexture = MiniMapTrackingButton:GetNormalTexture()
        if normalTexture then
            normalTexture:set_atlas('Minimap-Tracking-Normal', true)
        end

        local pushedTexture = MiniMapTrackingButton:GetPushedTexture()
        if pushedTexture then
            pushedTexture:set_atlas('Minimap-Tracking-Pushed', true)
        end

        local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
        if highlightTexture then
            highlightTexture:set_atlas('Minimap-Tracking-Highlight', true)
        end

    end

    -- Always hide overlay
    if MiniMapTrackingIconOverlay then
        MiniMapTrackingIconOverlay:SetAlpha(0)
    end
end

local function MiniMapInstanceDifficulty_OnEvent(self)
    local _, instanceType, difficulty, _, maxPlayers, playerDifficulty, isDynamicInstance = GetInstanceInfo()
    if (instanceType == "party" or instanceType == "raid") and not (difficulty == 1 and maxPlayers == 5) then
        local isHeroic = false
        if instanceType == "party" and difficulty == 2 then
            isHeroic = true
        elseif instanceType == "raid" then
            if isDynamicInstance then
                selectedRaidDifficulty = difficulty
                if playerDifficulty == 1 then
                    if selectedRaidDifficulty <= 2 then
                        selectedRaidDifficulty = selectedRaidDifficulty + 2
                    end
                    isHeroic = true
                end
                -- if modified difficulty is normal then you are allowed to select heroic, and vice-versa
                if selectedRaidDifficulty == 1 then
                    allowedRaidDifficulty = 3
                elseif selectedRaidDifficulty == 2 then
                    allowedRaidDifficulty = 4
                elseif selectedRaidDifficulty == 3 then
                    allowedRaidDifficulty = 1
                elseif selectedRaidDifficulty == 4 then
                    allowedRaidDifficulty = 2
                end
                allowedRaidDifficulty = "RAID_DIFFICULTY" .. allowedRaidDifficulty
            elseif difficulty > 2 then
                isHeroic = true
            end
        end

        MiniMapInstanceDifficultyText:SetText(maxPlayers)

        -- Position text: slightly to the left and downward (scale 0.85 handles the size)
        MiniMapInstanceDifficultyText:ClearAllPoints()
        MiniMapInstanceDifficultyText:SetPoint("CENTER", self, "CENTER", -1, -8)

        local minimapInstanceTexture = MiniMapInstanceDifficultyTexture
        self:SetScale(0.85) -- Fixed scale for difficulty icon
        self:Show()
    else
        self:Hide()
    end
end

-- =================================================================
-- MODULE ENABLE/DISABLE SYSTEM
-- =================================================================

local function RestoreVanillaMinimapChrome()
    if Minimap_UpdateRotationSetting then
        Minimap_UpdateRotationSetting()
    end
    if MinimapBorder then
        MinimapBorder:Show()
    end
    if MinimapBackdrop and MinimapCluster then
        MinimapBackdrop:ClearAllPoints()
        MinimapBackdrop:SetPoint("CENTER", MinimapCluster, "CENTER", 0, -20)
        MinimapModule.backdropYOffset = nil
    end
    if MinimapBorderTop then
        MinimapBorderTop:ClearAllPoints()
        MinimapBorderTop:SetPoint("TOPRIGHT")
        MinimapBorderTop:SetTexture("Interface\\Minimap\\UI-Minimap-Border")
        MinimapBorderTop:SetTexCoord(0.25, 1.0, 0.0, 0.125)
        MinimapBorderTop:SetSize(192, 32)
        MinimapBorderTop:SetAlpha(1)
        MinimapBorderTop:Show()
    end
    if Minimap and MinimapModule.activeMinimapScale then
        Minimap:SetScale(1)
        MinimapModule.activeMinimapScale = nil
    end
    local blizzFrames = {
        MiniMapTrackingIcon, MiniMapTrackingIconOverlay, MiniMapMailBorder, MiniMapTrackingButtonBorder,
    }
    for _, frame in pairs(blizzFrames) do
        if frame then
            frame:SetAlpha(1)
        end
    end
end

function MinimapModule:StoreOriginalSettings()
    -- Store original Blizzard minimap settings
    if MinimapCluster then
        local point, relativeTo, relativePoint, xOfs, yOfs = MinimapCluster:GetPoint()
        self.originalMinimapSettings = {
            scale = MinimapCluster:GetScale(),
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
            isStored = true
        }
    end

    -- Store original DurabilityFrame settings
    if DurabilityFrame then
        local point, relativeTo, relativePoint, xOfs, yOfs = DurabilityFrame:GetPoint(1)
        self.originalMinimapSettings.durability = {
            scale = DurabilityFrame:GetScale(),
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end

    -- Store that we need to restore to Blizzard default mask
    if not self.originalMask then
        self.originalMask = "Textures\\MinimapMask" -- Standard Blizzard default

    end
end

-- Dungeon Eye editor frame -separate from full minimap init so it works
--    even when sexymap_mode == "sexymap" (micromenu styles LFG independently)
function MinimapModule:RegisterLFGEditorFrame()
    if not MiniMapLFGFrame then return end
    if self.lfgWrapper then return end  -- already registered

    -- Size wrapper to match the eye frame (hardcoded fallback: eye is ~52Ã—56)
    local lfgW = (MiniMapLFGFrame:GetWidth()  > 0 and MiniMapLFGFrame:GetWidth())  or 52
    local lfgH = (MiniMapLFGFrame:GetHeight() > 0 and MiniMapLFGFrame:GetHeight()) or 56
    local lfgWrapper = addon.CreateUIFrame(lfgW, lfgH, "LFGFrame")

    -- Apply saved or default position
    local lfgCfg    = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.lfgframe
    local lfgAnchor = (lfgCfg and lfgCfg.anchor) or "TOPRIGHT"
    local lfgX      = (lfgCfg and lfgCfg.posX)   or -20
    local lfgY      = (lfgCfg and lfgCfg.posY)   or -220
    lfgWrapper:SetPoint(lfgAnchor, UIParent, lfgAnchor, lfgX, lfgY)

    -- Hook SetPoint/ClearAllPoints BEFORE reparenting so Blizzard can't move it
    local origLFGSetPoint       = MiniMapLFGFrame.SetPoint
    local origLFGClearAllPoints = MiniMapLFGFrame.ClearAllPoints
    local lfgLocked = false

    MiniMapLFGFrame.SetPoint = function(self, ...)
        if lfgLocked then return end
        origLFGSetPoint(self, ...)
    end
    MiniMapLFGFrame.ClearAllPoints = function(self)
        if lfgLocked then return end
        origLFGClearAllPoints(self)
    end

    -- Reparent and lock in place
    MiniMapLFGFrame:SetParent(lfgWrapper)
    origLFGClearAllPoints(MiniMapLFGFrame)
    origLFGSetPoint(MiniMapLFGFrame, "TOPLEFT", lfgWrapper, "TOPLEFT", 0, 0)
    lfgLocked = true

    -- Keep track of original Show/Hide so we can force-show in editor mode
    local origLFGShow = MiniMapLFGFrame.Show
    local origLFGHide = MiniMapLFGFrame.Hide
    local lfgWasVisible = false  -- tracks state before editor opened

    -- Register wrapper in editor so it becomes a moveable mover
    addon:RegisterEditableFrame({
        name    = "lfgframe",
        frame   = lfgWrapper,
        configPath = {"widgets", "lfgframe"},
        showTest = function()
            -- Hide the real eye so the wrapper can receive mouse/drag events
            lfgWasVisible = MiniMapLFGFrame:IsShown()
            origLFGHide(MiniMapLFGFrame)
            lfgWrapper:Show()
        end,
        hideTest = function()
            -- Restore eye visibility after editor closes
            if lfgWasVisible then
                origLFGShow(MiniMapLFGFrame)
            end
        end,
        module  = self
    })

    self.lfgWrapper = lfgWrapper
end

function MinimapModule:ApplyMinimapSystem()
    if self.applied then
        return -- Already applied
    end

    -- Check module enabled state
    if not IsModuleEnabled() then
        return
    end

    -- If SexyMap-only mode, don't apply any DragonUI minimap modifications
    local minimapModuleConfig = addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.minimap
    if minimapModuleConfig and minimapModuleConfig.sexymap_mode == "sexymap" then
        -- Still register the LFG editor frame -micromenu styles it independently
        self:RegisterLFGEditorFrame()
        return
    end

    -- Check combat lockdown
    if InCombatLockdown() then
        self.registeredEvents.PLAYER_REGEN_ENABLED = function()
            self:ApplyMinimapSystem()
        end
        return
    end

    -- Store original settings before applying DragonUI changes
    self:StoreOriginalSettings()

    -- Defensive compatibility for LibDBIcon-based addon buttons.
    NormalizeLibDBIconRadius()
    HideIntegratedAddonMinimapButtons()
    
    -- Initialize the DragonUI minimap system
    self._initializingMinimapSystem = true
    self:InitializeMinimapSystem()
    self.applied = true
    self._initializingMinimapSystem = nil
    self.isEnabled = true -- Legacy compatibility
    

end

-- EVENT HANDLING: Proper event registration/cleanup
local function RegisterModuleEvents()
    if MinimapModule.registeredEvents.PLAYER_REGEN_ENABLED then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:SetScript("OnEvent", function(self, event)
            if MinimapModule.registeredEvents.PLAYER_REGEN_ENABLED then
                MinimapModule.registeredEvents.PLAYER_REGEN_ENABLED()
                MinimapModule.registeredEvents.PLAYER_REGEN_ENABLED = nil
                self:UnregisterAllEvents()
            end
        end)
        MinimapModule.frames.eventFrame = eventFrame
    end
end

function MinimapModule:RestoreMinimapSystem()
    if not self.applied then
        return -- Already restored
    end

    -- Check combat lockdown
    if InCombatLockdown() then
        self.registeredEvents.PLAYER_REGEN_ENABLED = function()
            self:RestoreMinimapSystem()
        end
        return
    end

    if addon.VisibilityFade then addon.VisibilityFade.Reset("minimap", 1) end

    -- Hide DragonUI frames
    if self.minimapFrame then
        self.minimapFrame:Hide()
        self.frames.minimapFrame = nil
    end
    if self.borderFrame then
        self.borderFrame:SetScript("OnUpdate", nil)
        self.borderFrame:Hide()
        self.frames.borderFrame = nil
    end
    if self.frames.settingsButton then
        self.frames.settingsButton:Hide()
    end
    HideIntegratedMinimapCollector()
    RestoreCollectedButtonsToOrigin()

    -- Restore original MinimapCluster state
    if MinimapCluster and self.originalStates.MinimapCluster then
        MinimapCluster:ClearAllPoints()
        local originalState = self.originalStates.MinimapCluster
        for _, point in ipairs(originalState.points) do
            MinimapCluster:SetPoint(unpack(point))
        end
        MinimapCluster:SetScale(originalState.scale)
    elseif MinimapCluster and self.originalMinimapSettings.isStored then
        -- Fallback to legacy method
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint(self.originalMinimapSettings.point or "TOPRIGHT",
            self.originalMinimapSettings.relativeTo or UIParent,
            self.originalMinimapSettings.relativePoint or "TOPRIGHT", self.originalMinimapSettings.xOfs or -16,
            self.originalMinimapSettings.yOfs or -116)
        MinimapCluster:SetScale(self.originalMinimapSettings.scale or 1.0)
    end

    -- Restore original DurabilityFrame state
    if DurabilityFrame and self.originalStates.DurabilityFrame then
        DurabilityFrame:ClearAllPoints()
        local originalState = self.originalStates.DurabilityFrame
        for _, point in ipairs(originalState.points) do
            DurabilityFrame:SetPoint(unpack(point))
        end
        DurabilityFrame:SetScale(originalState.scale)
    elseif DurabilityFrame and self.originalMinimapSettings.durability then
        -- Fallback to legacy method
        local durSettings = self.originalMinimapSettings.durability
        DurabilityFrame:ClearAllPoints()
        DurabilityFrame:SetPoint(
            durSettings.point or "TOPLEFT",
            durSettings.relativeTo or MinimapCluster,
            durSettings.relativePoint or "BOTTOMLEFT",
            durSettings.xOfs or -15,
            durSettings.yOfs or -10
        )
        DurabilityFrame:SetScale(durSettings.scale or 1.0)
    end

    -- Restore other original states
    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Show()
    end
    if Minimap.Circle then
        Minimap.Circle:Hide()
    end

    -- CRITICAL: Restore original Blizzard minimap mask
    if Minimap and self.originalMask then
        Minimap:SetMaskTexture(self.originalMask)
    end

    -- Restore original Blizzard blip texture
    if Minimap then
        MinimapModule._settingBlipTexture = true
        Minimap:SetBlipTexture('Interface\\Minimap\\ObjectIcons')
        MinimapModule._settingBlipTexture = false
    end

    -- Restore external LibDBIcon radius if we normalized it.
    RestoreLibDBIconRadius()

    -- Fully disable minimap icon/calendar styling when the module is toggled off.
    UnskinAllMinimapButtons()
    if GameTimeFrame and GameTimeFrame.GetFontString then
        local gameTimeText = GameTimeFrame:GetFontString()
        if gameTimeText then
            gameTimeText:Show()
        end
    end
    if GameTimeFrame_Update then
        GameTimeFrame_Update()
    end

    -- Cleanup hooks (tracked for debugging)
    CleanupSecureHooks()

    -- Stop DragonUI control before decoration teardown re-syncs rotation/mask state.
    self.applied = false
    self._initializingMinimapSystem = nil
    self.isEnabled = false -- Legacy compatibility

    if addon.MinimapDecorations and addon.MinimapDecorations.Restore then
        addon.MinimapDecorations:Restore()
    end

    RestoreVanillaMinimapChrome()

    addon:Print(L["Minimap module restored to Blizzard defaults"])
end

-- Blips don't respect MinimapCluster's cascaded alpha (confirmed: swapping to Blizzard's stock
-- atlas only restyles them, doesn't hide them — they're still fully opaque). A nonexistent texture
-- path renders nothing at all, so point there while hidden instead of touching Minimap's own alpha,
-- which risks blips not refreshing until /reload.
local function ApplyBlipTextureForFadeVisibility(shouldShow)
    if not Minimap then return end
    local settings = addon.db and addon.db.profile and addon.db.profile.minimap
    if not settings then return end
    local texture
    if shouldShow then
        texture = settings.blip_skin and "Interface\\AddOns\\DragonUI\\assets\\objecticons"
            or 'Interface\\Minimap\\ObjectIcons'
    else
        texture = "Interface\\AddOns\\DragonUI\\assets\\blip_blank"
    end
    MinimapModule._settingBlipTexture = true
    Minimap:SetBlipTexture(texture)
    MinimapModule._settingBlipTexture = false
end

-- After the minimap's effective alpha (even cascaded, not just its own) sits at 0 for a while, the
-- client stops refreshing the terrain texture — it comes back frozen/blank until something like a
-- zoom change wakes it up. Bump the zoom a level and immediately revert it to force that refresh
-- without an actual visible zoom change.
local function ForceMinimapTerrainRefresh()
    if not Minimap or not Minimap.GetZoom or not Minimap.SetZoom then return end
    local currentZoom = Minimap:GetZoom()
    Minimap:SetZoom(currentZoom + 1)
    if Minimap:GetZoom() == currentZoom then
        Minimap:SetZoom(math.max(0, currentZoom - 1))
    end
    Minimap:SetZoom(currentZoom)
end

local function OnMinimapFadeComplete(shouldShow)
    if shouldShow then
        ForceMinimapTerrainRefresh()
    end
end

-- Alpha-only fade on MinimapCluster (never Minimap itself, and never Hide/Show) — Minimap's own
-- SetAlpha/Hide has been reported to stall blip texture updates in 3.3.5a until /reload.
local function SyncMinimapVisibility()
    if not MinimapCluster or not addon.VisibilityFade then return end
    local isHybridMode = MinimapModule.sexyMapHybridMode
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))
    if isHybridMode then
        -- SexyMap owns the minimap's visuals in hybrid mode; don't fight it with our own fade.
        addon.VisibilityFade.Reset("minimap", 1)
        return
    end
    -- MinimapCluster's cascade covers Minimap/zone text/buttons, but DragonUI's own border ring
    -- (self.borderFrame) and the addon-icon collector are siblings parented to UIParent, not
    -- children — fade them explicitly too.
    local extraFrames = {}
    if MinimapModule.borderFrame then table.insert(extraFrames, MinimapModule.borderFrame) end
    local iconCollector = MinimapModule.frames and MinimapModule.frames.iconCollector
    if iconCollector then table.insert(extraFrames, iconCollector) end
    -- MinimapBackdrop excluded on purpose: mouse-off overlay over the circle; enabling it eats native blip tooltips.
    local hoverFrames = { MinimapCluster }
    if Minimap then table.insert(hoverFrames, Minimap) end
    if iconCollector then table.insert(hoverFrames, iconCollector) end
    addon.VisibilityFade.Register("minimap", MinimapCluster, {
        frames = extraFrames,
        hoverFrames = hoverFrames,
        -- IsMouseOver() polling (not OnEnter/OnLeave) so hovering any button drawn on top of the
        -- minimap (settings gear, addon icon collector, zoom, tracking...) still counts as hover —
        -- a plain geometric check doesn't care which frame actually wins the hit-test at that pixel.
        pollHover = true,
        -- Minimap isn't a secure/protected frame, so EnableMouse can react live even mid-combat.
        clickThrough = true,
        mouseSafeInCombat = true,
        onVisibilityChange = ApplyBlipTextureForFadeVisibility,
        onFadeComplete = OnMinimapFadeComplete,
        dbTable = function() return addon.db and addon.db.profile and addon.db.profile.minimap end,
    })
    addon.VisibilityFade.AddHoverFrames("minimap", CollectMinimapClickThroughFrames())
    addon.VisibilityFade.Update("minimap")
end
MinimapModule.SyncMinimapVisibility = SyncMinimapVisibility

function MinimapModule:InitializeMinimapSystem()
    -- Load TimeManager addon if not loaded
    if not IsAddOnLoaded('Blizzard_TimeManager') then
        LoadAddOn('Blizzard_TimeManager')
    end

    self.minimapFrame = CreateUIFrame(230, 230, "MinimapFrame")
    -- Simple visual tweak: keep minimap editor overlay 10px lower.
    do
        local slice = self.minimapFrame and self.minimapFrame.NineSlice
        if slice then
            slice.TopLeftCorner:ClearAllPoints();     slice.TopLeftCorner:SetPoint("TOPLEFT", -8, -2)
            slice.TopRightCorner:ClearAllPoints();    slice.TopRightCorner:SetPoint("TOPRIGHT", 8, -2)
            slice.BottomLeftCorner:ClearAllPoints();  slice.BottomLeftCorner:SetPoint("BOTTOMLEFT", -8, -18)
            slice.BottomRightCorner:ClearAllPoints(); slice.BottomRightCorner:SetPoint("BOTTOMRIGHT", 8, -18)
            slice.Center:ClearAllPoints();            slice.Center:SetPoint("TOPLEFT", 0, -10); slice.Center:SetPoint("BOTTOMRIGHT", 0, -10)
        end
        if self.minimapFrame and self.minimapFrame.editorText then
            self.minimapFrame.editorText:ClearAllPoints()
            self.minimapFrame.editorText:SetPoint("CENTER", self.minimapFrame, "CENTER", 0, -10)
        end
    end

    --  AUTOMATIC REGISTRATION IN THE CENTRALIZED SYSTEM
    addon:RegisterEditableFrame({
        name = "minimap",
        frame = self.minimapFrame,
        blizzardFrame = MinimapCluster,
        configPath = {"widgets", "minimap"},
        onShow = function()
            -- Match quest tracker behavior: clamp while editing.
            -- Allow a small overflow so users can fine-tune near edges.
            self.minimapFrame:SetClampedToScreen(true)
            self.minimapFrame:SetClampRectInsets(20, -20, -20, -5)
            -- Force full opacity while dragging so the user can actually see what they're moving.
            if addon.VisibilityFade then addon.VisibilityFade.Reset("minimap", 1) end
        end,
        onHide = function()
            -- Remove custom clamp settings after editor mode.
            self.minimapFrame:SetClampRectInsets(0, 0, 0, 0)
            self.minimapFrame:SetClampedToScreen(false)
            self:UpdateWidgets() -- Apply new configuration on editor exit
            addon:RefreshMinimap()
        end,
        module = self
    })

    -- Dungeon Eye (MiniMapLFGFrame) -independent moveable frame
    self:RegisterLFGEditorFrame()

    local defaultX, defaultY = -7, 0
    local widgetConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.minimap

    if widgetConfig then
        self.minimapFrame:SetPoint(widgetConfig.anchor or "TOPRIGHT", UIParent, widgetConfig.anchor or "TOPRIGHT",
            widgetConfig.posX or defaultX, widgetConfig.posY or defaultY)
    else
        self.minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", defaultX, defaultY)
    end

    -- Determine hybrid mode for conditional border creation
    local isHybridMode = self.sexyMapHybridMode
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))

    if not isHybridMode then
        self.borderFrame = CreateMinimapBorderFrame(232, 232)
        self.borderFrame:SetPoint("CENTER", MinimapBorder, "CENTER", 0, -2)
    end

    RemoveBlizzardFrames()
    ReplaceBlizzardFrame(self.minimapFrame)
    UpdateDragonUISettingsButton()

    --  ADD THIS LINE TO APPLY ALL SETTINGS AT STARTUP
    self:UpdateSettings()

    -- Must run AFTER UpdateSettings(): it unconditionally applies settings.blip_skin's texture,
    -- which would otherwise stomp the fade-aware blip texture chosen here right after login.
    SyncMinimapVisibility()

    if self.UpdateRotation then
        self.UpdateRotation()
    end

    -- Hook tracking changes to update icon automatically (not in hybrid mode)
    if not isHybridMode then
        MiniMapTrackingButton:HookScript("OnEvent", function()
            self:UpdateTrackingIcon()
        end)

        -- Initial tracking icon update
        self:UpdateTrackingIcon()
    end

end

function MinimapModule:Initialize()
    if self.initialized then
        return -- Already initialized
    end
    
    -- Check if minimap module is enabled
    if not IsModuleEnabled() then
        RestoreVanillaMinimapChrome()
        return
    end

    -- If SexyMap-only mode is saved, skip all DragonUI minimap modifications
    -- so SexyMap gets a clean, unmodified minimap to work with
    local minimapModuleConfig = addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.minimap
    if minimapModuleConfig and minimapModuleConfig.sexymap_mode == "sexymap" then
        -- Still register the LFG editor frame -the eye lives independently
        self:RegisterLFGEditorFrame()
        return
    end

    -- Only apply DragonUI modifications if module is enabled
    self:ApplyMinimapSystem()
    
    self.initialized = true
end

-- Remove functions that no longer exist and convert to DragonUI functions
function MinimapModule:UpdateSettings()
    local scale = addon.db.profile.minimap.scale or 1.0

    if self.minimapFrame then
        --  HANDLE POSITION: Priority to widgets (editor mode), fallback to x,y
        local x, y, anchor

        -- 1. Try to use editor mode position (widgets)
        if addon.db.profile.widgets and addon.db.profile.widgets.minimap then
            local widgetConfig = addon.db.profile.widgets.minimap
            anchor = widgetConfig.anchor or "TOPRIGHT"
            x = widgetConfig.posX or 0
            y = widgetConfig.posY or 0

        else
            -- 2. Fallback to legacy position (x, y)
            x = addon.db.profile.minimap.x or -7
            y = addon.db.profile.minimap.y or 0
            anchor = "TOPRIGHT"

        end

        -- Update DurabilityFrame position
        if DurabilityFrame then
            DurabilityFrame:ClearAllPoints()
            DurabilityFrame:SetPoint("TOP", Minimap, "BOTTOM", 0, 0)
            DurabilityFrame:SetScale(scale)
        end
        
        --  APPLY POSITION
        self.minimapFrame:ClearAllPoints()
        self.minimapFrame:SetPoint(anchor, UIParent, anchor, x, y)

        --  APPLY SCALE (works perfectly now)
        if MinimapCluster then
            MinimapCluster:SetScale(scale)

        end

        if self.borderFrame then
            self.borderFrame:SetScale(scale)
        end

        UpdateMinimapCircleSize()

        --  APPLY ALL SETTINGS
        self:ApplyAllSettings()
    end

    --  GLOBAL MINIMAP SETTINGS
    if Minimap then
        -- Apply blip texture based on user setting (new vs old style)
        local useNewBlipStyle = addon.db.profile.minimap.blip_skin
        if useNewBlipStyle == nil then
            useNewBlipStyle = true -- Default to new style
        end

        local blipTexture = useNewBlipStyle and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or
                                'Interface\\Minimap\\ObjectIcons'
        -- Use re-entrancy guard to avoid triggering our own SetBlipTexture hook
        MinimapModule._settingBlipTexture = true
        Minimap:SetBlipTexture(blipTexture)
        MinimapModule._settingBlipTexture = false

        local playerArrowSize = addon.db.profile.minimap.player_arrow_size
        if playerArrowSize then
            Minimap:SetPlayerTextureHeight(playerArrowSize)
            Minimap:SetPlayerTextureWidth(playerArrowSize)
        end
    end

    --  REFRESH OTHER ELEMENTS
    self:UpdateTrackingIcon()

    if addon.MinimapDecorations and addon.MinimapDecorations.Refresh then
        addon.MinimapDecorations:Refresh()
    end

end

local function GetClockTextFrame()
    if not TimeManagerClockButton then
        return nil
    end

    -- Try multiple methods to find the clock text
    local clockText = TimeManagerClockButton.text
    if clockText then
        return clockText
    end

    clockText = TimeManagerClockButton:GetFontString()
    if clockText then
        return clockText
    end

    -- Search in children
    local children = { TimeManagerClockButton:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.GetFont then
            return child
        end
    end

    -- Search in regions
    for i = 1, TimeManagerClockButton:GetNumRegions() do
        local region = select(i, TimeManagerClockButton:GetRegions())
        if region and region.GetFont then
            return region
        end
    end

    return nil
end

local function SetShowClockCVar(enabled)
    if not (GetCVar and SetCVar) then
        return
    end

    local desired = enabled and "1" or "0"
    local current = GetCVar("showClock")
    if current ~= desired then
        SetCVar("showClock", desired)
    end
end

local function ApplyClockAndZoneLayout(showClock)
    if TimeManagerClockButton then
        if showClock then
            TimeManagerClockButton:Show()
        else
            TimeManagerClockButton:Hide()
        end
    end

    if MinimapZoneTextButton and MinimapBorderTop then
        MinimapZoneTextButton:ClearAllPoints()
        if showClock then
            -- Restore default DragonUI position when clock is visible.
            MinimapZoneTextButton:SetPoint("LEFT", MinimapBorderTop, "LEFT", 7, 1)
            MinimapZoneTextButton:SetWidth(108)
        else
            -- Center the zone text when clock is hidden.
            MinimapZoneTextButton:SetPoint("CENTER", MinimapBorderTop, "CENTER", 0, 1)
            MinimapZoneTextButton:SetWidth(150)
        end
    end

    if MinimapZoneText then
        MinimapZoneText:SetJustifyH(showClock and "LEFT" or "CENTER")
        if MinimapZoneTextButton then
            MinimapZoneText:SetAllPoints(MinimapZoneTextButton)
        end
    end
end

-- Apply all minimap settings from the database
function MinimapModule:ApplyAllSettings()
    if not addon.db or not addon.db.profile or not addon.db.profile.minimap then
        return
    end

    local settings = addon.db.profile.minimap

    -- In hybrid mode, skip settings that modify DragonUI-styled elements
    -- (border top, zone text positioning, clock anchoring, calendar)
    -- SexyMap controls those visual elements
    local isHybridMode = self.sexyMapHybridMode
        or (addon.db and addon.db.profile and addon.db.profile.modules
            and addon.db.profile.modules.minimap
            and IsSexyMapHybridModeValue(addon.db.profile.modules.minimap.sexymap_mode))

    if not isHybridMode then
        --  APPLY BORDER ALPHA
        if MinimapBorderTop and settings.border_alpha then
            MinimapBorderTop:SetAlpha(settings.border_alpha)
        end

        --  APPLY CALENDAR VISIBILITY
        if settings.calendar ~= nil then
            if GameTimeFrame then
                if settings.calendar then
                    GameTimeFrame:Show()
                else
                    GameTimeFrame:Hide()
                end
            end
        end

        --  APPLY CLOCK VISIBILITY AND ADJUST ZONE TEXT
        if settings.clock ~= nil then
            SetShowClockCVar(settings.clock)
            ApplyClockAndZoneLayout(settings.clock)
        end
    end -- not isHybridMode (border, calendar, clock, zone text)

    --  APPLY ZOOM BUTTONS VISIBILITY (applies in all modes)
    if settings.zoom_buttons ~= nil then
        if MinimapZoomIn and MinimapZoomOut then
            if settings.zoom_buttons then
                MinimapZoomIn:Show()
                MinimapZoomOut:Show()
            else
                MinimapZoomIn:Hide()
                MinimapZoomOut:Hide()
            end
        end
    end

    -- Apply clock font size (skip in hybrid mode)
    if not isHybridMode and settings.clock_font_size and TimeManagerClockButton then
        local clockText = GetClockTextFrame()
        if clockText then
            local font, _, flags = clockText:GetFont()
            clockText:SetFont(font, settings.clock_font_size, flags)

        else

        end
    end

    --  APPLY ZONE TEXT FONT SIZE -skip in hybrid mode
    if not isHybridMode and settings.zonetext_font_size and MinimapZoneText then
        local font, _, flags = MinimapZoneText:GetFont()
        MinimapZoneText:SetFont(font, settings.zonetext_font_size, flags)
    end

    --  APPLY BLIP TEXTURE (NEW VS OLD STYLE)
    if settings.blip_skin ~= nil and Minimap then
        local blipTexture = settings.blip_skin and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or
                                'Interface\\Minimap\\ObjectIcons'
        Minimap:SetBlipTexture(blipTexture)
    end

    --  APPLY PLAYER ARROW SIZE
    if settings.player_arrow_size and Minimap then
        Minimap:SetPlayerTextureHeight(settings.player_arrow_size)
        Minimap:SetPlayerTextureWidth(settings.player_arrow_size)
    end
end
-- Editor mode interface
function MinimapModule:LoadDefaultSettings()
    -- Use correct database: addon.db (not addon.core.db)
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    addon.db.profile.widgets.minimap = {
        anchor = "TOPRIGHT",
        posX = 0,
        posY = 0
    }
end

function MinimapModule:UpdateWidgets()
    -- Use correct database: addon.db (not addon.core.db)
    if not addon.db or not addon.db.profile.widgets or not addon.db.profile.widgets.minimap then

        self:LoadDefaultSettings()
        return
    end

    local widgetOptions = addon.db.profile.widgets.minimap
    self.minimapFrame:SetPoint(widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY)

end

-- Editor mode uses centralized system

-- Refresh function to be called from options.lua
function addon:RefreshMinimap()
    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("minimap_refresh", addon.RefreshMinimap)
        end
        return
    end

    if MinimapModule.isEnabled then
        MinimapModule:UpdateSettings()
        -- Also update tracking icon when settings change
        MinimapModule:UpdateTrackingIcon()
        MinimapModule.SyncMinimapVisibility()

        -- Refresh addon icon skinning
        local skinEnabled = addon.db and addon.db.profile and addon.db.profile.minimap
            and addon.db.profile.minimap.addon_button_skin
        if skinEnabled then
            RemoveAllMinimapIconBorders()
        else
            UnskinAllMinimapButtons()
        end

        -- Instant toggle for addon button fade
        UpdateAddonButtonFade()
        UpdateDragonUISettingsButton()

        if addon.MinimapDecorations and addon.MinimapDecorations.Refresh then
            addon.MinimapDecorations:Refresh()
        end
    end
end

-- Profile Callbacks for configuration change handling
MinimapModule.OnProfileChanged = function()
    addon:RefreshMinimapSystem()
end

MinimapModule.OnProfileCopied = function()
    addon:RefreshMinimapSystem()
end

MinimapModule.OnProfileReset = function()
    addon:RefreshMinimapSystem()
end

-- System refresh function for enable/disable
function addon:RefreshMinimapSystem()
    -- If SexyMap-only mode, never apply DragonUI minimap
    local minimapModuleConfig = addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.minimap
    if minimapModuleConfig and minimapModuleConfig.sexymap_mode == "sexymap" then
        if MinimapModule.applied then
            if addon:ShouldDeferModuleDisable("minimap", MinimapModule) then
                return
            end
            MinimapModule:RestoreMinimapSystem()
        end
        return
    end

    local isEnabled =
        addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.minimap and
            addon.db.profile.modules.minimap.enabled

    if isEnabled == nil then
        isEnabled = true -- Default to enabled
    end

    if isEnabled then
        if MinimapModule.applied then
            addon:RefreshMinimap()
        else
            MinimapModule:ApplyMinimapSystem()
        end
    else
        if addon:ShouldDeferModuleDisable("minimap", MinimapModule) then
            return
        end
        MinimapModule:RestoreMinimapSystem()
    end
end

-- Clean all skinned minimap button borders
local function CleanAllMinimapButtons()
    local buttons = GetAllMinimapButtons()
    for _, child in ipairs(buttons) do
        if child.circle then
            -- Clean the border from oldminimapcore.lua style
            child.circle:Hide()
            child.circle = nil
        end
    end
end

-- Debug utility for minimap button inspection
function addon:DebugMinimapButtons()
    local buttons = GetAllMinimapButtons()
    for _, child in ipairs(buttons) do
        local name = child:GetName() or "Unnamed"
        local hasBorder = child.circle and "YES" or "NO"
        local width, height = child:GetSize()
    end
end

-- =================================================================
-- INITIALIZATION
-- =================================================================

-- Initialize when the addon is ready
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Set original mask to standard Blizzard default
        if not MinimapModule.originalMask then
            MinimapModule.originalMask = "Textures\\MinimapMask"

        end

        -- Check if minimap module should be disabled and restore mask immediately
        if addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.minimap then
            local isEnabled = addon.db.profile.modules.minimap.enabled
            if isEnabled == false then
                Minimap:SetMaskTexture(MinimapModule.originalMask)

            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        MinimapModule:Initialize()
        self:UnregisterAllEvents()
    end
end)

