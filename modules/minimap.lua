--[[
    DragonUI Minimap Module - Adaptado de RetailUI
    Código base por Dmitriy (RetailUI) adaptado para DragonUI
]] local addon = select(2, ...);

--  Import DragonUI atlas function for tracking icons
local atlas = addon.minimap_SetAtlas;

--  Ensure _noop function exists
if not addon._noop then
    addon._noop = function() return end
end

-- #################################################################
-- ##                    DragonUI Minimap Module                  ##
-- ##              Unified minimap system (1 file)                ##
-- ##        Based on RetailUI pattern                            ##
-- #################################################################

local MinimapModule = {};
addon.MinimapModule = MinimapModule;

MinimapModule.minimapFrame = nil
MinimapModule.borderFrame = nil
MinimapModule.isEnabled = false
MinimapModule.originalMinimapSettings = {}  -- Store original Blizzard settings
MinimapModule.originalMask = nil  -- Store original minimap mask

local DEFAULT_MINIMAP_WIDTH = Minimap:GetWidth() * 1.36
local DEFAULT_MINIMAP_HEIGHT = Minimap:GetHeight() * 1.36
local blipScale = 1.12
local BORDER_SIZE = 71 * 2 * 2 ^ 0.5

local MINIMAP_TEXTURES = {
    BORDER = "Interface\\AddOns\\DragonUI\\assets\\uiminimapborder"
}

--  VERIFICAR FUNCIÓN ATLAS AL INICIO
local function GetAtlasFunction()
    -- Verificar múltiples posibles ubicaciones de la función atlas
    if addon.minimap_SetAtlas then
        return addon.minimap_SetAtlas
    elseif addon.SetAtlas then
        return addon.SetAtlas
    elseif SetAtlasTexture then
        return SetAtlasTexture
    else

        return nil
    end
end

local function UpdateCalendarDate()
    local _, _, day = CalendarGetDate()

    local gameTimeFrame = GameTimeFrame

    local normalTexture = gameTimeFrame:GetNormalTexture()
    normalTexture:SetAllPoints(gameTimeFrame)
    SetAtlasTexture(normalTexture, 'Minimap-Calendar-' .. day .. '-Normal')

    local highlightTexture = gameTimeFrame:GetHighlightTexture()
    highlightTexture:SetAllPoints(gameTimeFrame)
    SetAtlasTexture(highlightTexture, 'Minimap-Calendar-' .. day .. '-Highlight')

    local pushedTexture = gameTimeFrame:GetPushedTexture()
    pushedTexture:SetAllPoints(gameTimeFrame)
    SetAtlasTexture(pushedTexture, 'Minimap-Calendar-' .. day .. '-Pushed')
end

local function ReplaceBlizzardFrame(frame)
    local minimapCluster = MinimapCluster
    minimapCluster:ClearAllPoints()
    minimapCluster:SetPoint("CENTER", frame, "CENTER", 0, 0)

    local minimapBorderTop = MinimapBorderTop
    minimapBorderTop:ClearAllPoints()
    minimapBorderTop:SetPoint("TOP", 0, 5)
    SetAtlasTexture(minimapBorderTop, 'Minimap-Border-Top')
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

    local timeClockButton = TimeManagerClockButton
    timeClockButton:GetRegions():Hide()
    timeClockButton:ClearAllPoints()
    timeClockButton:SetPoint("RIGHT", minimapBorderTop, "RIGHT", -5, 0)
    timeClockButton:SetWidth(30)

    local gameTimeFrame = GameTimeFrame
    gameTimeFrame:ClearAllPoints()
    gameTimeFrame:SetPoint("LEFT", minimapBorderTop, "RIGHT", 3, -1)
    gameTimeFrame:SetSize(26, 24)
    gameTimeFrame:SetHitRectInsets(0, 0, 0, 0)
    gameTimeFrame:GetFontString():Hide()

    UpdateCalendarDate()

    local minimapBattlefieldFrame = MiniMapBattlefieldFrame
    minimapBattlefieldFrame:ClearAllPoints()
    minimapBattlefieldFrame:SetPoint("BOTTOMLEFT", 8, 2)

    local minimapInstanceFrame = MiniMapInstanceDifficulty
    minimapInstanceFrame:ClearAllPoints()
    minimapInstanceFrame:SetPoint("TOP", minimapBorderTop, 'BOTTOMRIGHT', -18, 9)

    local minimapTracking = MiniMapTracking
    minimapTracking:ClearAllPoints()
    minimapTracking:SetPoint("RIGHT", minimapBorderTop, "LEFT", -3, 0)
    minimapTracking:SetSize(26, 24)

    local minimapMailFrame = MiniMapMailFrame
    minimapMailFrame:ClearAllPoints()
    minimapMailFrame:SetPoint("TOP", minimapTracking, "BOTTOM", 0, -3)
    minimapMailFrame:SetSize(20, 14)
    minimapMailFrame:SetHitRectInsets(0, 0, 0, 0)

    local minimapMailIconTexture = MiniMapMailIcon
    minimapMailIconTexture:SetAllPoints(minimapMailFrame)
    SetAtlasTexture(minimapMailIconTexture, 'Minimap-Mail-Normal')

    local backgroundTexture = _G[minimapTracking:GetName() .. "Background"]
    backgroundTexture:SetAllPoints(minimapTracking)
    SetAtlasTexture(backgroundTexture, 'Minimap-Tracking-Background')

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
    SetAtlasTexture(normalTexture, 'Minimap-Tracking-Normal')

    minimapTrackingButton:SetNormalTexture(normalTexture)

    local highlightTexture = minimapTrackingButton:GetHighlightTexture()
    highlightTexture:SetAllPoints(minimapTrackingButton)
    SetAtlasTexture(highlightTexture, 'Minimap-Tracking-Highlight')

    local pushedTexture = minimapTrackingButton:GetPushedTexture() or minimapTrackingButton:CreateTexture(nil, "BORDER")
    pushedTexture:SetAllPoints(minimapTrackingButton)
    SetAtlasTexture(pushedTexture, 'Minimap-Tracking-Pushed')

    minimapTrackingButton:SetPushedTexture(pushedTexture)

    local minimapFrame = Minimap
    minimapFrame:ClearAllPoints()
    minimapFrame:SetPoint("CENTER", minimapCluster, "CENTER", 0, -25)
    minimapFrame:SetWidth(DEFAULT_MINIMAP_WIDTH / blipScale)
    minimapFrame:SetHeight(DEFAULT_MINIMAP_HEIGHT / blipScale)
    minimapFrame:SetScale(blipScale)
    minimapFrame:SetMaskTexture("Interface\\AddOns\\DragonUI\\assets\\uiminimapmask.tga")

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

    local blipTexture = useNewBlipStyle and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or 'Interface\\Minimap\\ObjectIcons'
    minimapFrame:SetBlipTexture(blipTexture)
    local MINIMAP_POINTS = {}
    for i = 1, Minimap:GetNumPoints() do
        MINIMAP_POINTS[i] = {Minimap:GetPoint(i)}
    end

    for _, regions in ipairs {Minimap:GetChildren()} do
        if regions ~= WatchFrame and regions ~= _G.WatchFrame then
            regions:SetScale(1 / blipScale)
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

    local minimapBackdropTexture = MinimapBackdrop
    minimapBackdropTexture:ClearAllPoints()
    minimapBackdropTexture:SetPoint("CENTER", minimapFrame, "CENTER", 0, 3)

    local minimapBorderTexture = MinimapBorder
    minimapBorderTexture:Hide()
    if not Minimap.Circle then
        Minimap.Circle = MinimapBackdrop:CreateTexture(nil, 'ARTWORK')

        Minimap.Circle:SetSize(BORDER_SIZE, BORDER_SIZE)
        Minimap.Circle:SetPoint('CENTER', Minimap, 'CENTER')
        Minimap.Circle:SetTexture("Interface\\AddOns\\DragonUI\\assets\\uiminimapborder.tga")
    end

    local zoomInButton = MinimapZoomIn
    zoomInButton:ClearAllPoints()
    zoomInButton:SetPoint("BOTTOMRIGHT", 0, 15)

    zoomInButton:SetSize(25, 24)
    zoomInButton:SetHitRectInsets(0, 0, 0, 0)

    normalTexture = zoomInButton:GetNormalTexture()
    normalTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(normalTexture, 'Minimap-ZoomIn-Normal')

    highlightTexture = zoomInButton:GetHighlightTexture()
    highlightTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(highlightTexture, 'Minimap-ZoomIn-Highlight')

    pushedTexture = zoomInButton:GetPushedTexture()
    pushedTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(pushedTexture, 'Minimap-ZoomIn-Pushed')

    local disabledTexture = zoomInButton:GetDisabledTexture()
    disabledTexture:SetAllPoints(zoomInButton)
    SetAtlasTexture(disabledTexture, 'Minimap-ZoomIn-Pushed')

    local zoomOutButton = MinimapZoomOut
    zoomOutButton:ClearAllPoints()
    zoomOutButton:SetPoint("BOTTOMRIGHT", -22, 0)

    zoomOutButton:SetSize(20, 12)
    zoomOutButton:SetHitRectInsets(0, 0, 0, 0)

    normalTexture = zoomOutButton:GetNormalTexture()
    normalTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(normalTexture, 'Minimap-ZoomOut-Normal')

    highlightTexture = zoomOutButton:GetHighlightTexture()
    highlightTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(highlightTexture, 'Minimap-ZoomOut-Highlight')

    pushedTexture = zoomOutButton:GetPushedTexture()
    pushedTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(pushedTexture, 'Minimap-ZoomOut-Pushed')

    disabledTexture = zoomOutButton:GetDisabledTexture()
    disabledTexture:SetAllPoints(zoomOutButton)
    SetAtlasTexture(disabledTexture, 'Minimap-ZoomOut-Pushed')

    -- faction taking progress bar
    local WorldStateCaptureBar1 = _G['WorldStateCaptureBar1']
    if WorldStateCaptureBar1 then

        WorldStateCaptureBar1:ClearAllPoints()
        WorldStateCaptureBar1:SetPoint('CENTER', minimapFrame, 'BOTTOM', 0, -20)

        -- Hook SetPoint to prevent other code from overriding our positioning - HACKY
        -- SOMETHING likely Blizzard frame is trying to reposition the bar periodically so we need to block it
        local originalSetPoint = WorldStateCaptureBar1.SetPoint
        WorldStateCaptureBar1.SetPoint = function(self, ...)
            -- Only allow our specific positioning, ignore all others
            if select(1, ...) == 'CENTER' and select(2, ...) == minimapFrame and select(3, ...) == 'BOTTOM' then
                originalSetPoint(self, ...)
            end
            -- Silently ignore all other SetPoint calls
        end
    end

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

    --  CONTROLAR MANUALMENTE EL MOVIMIENTO DEL BOTÓN
    minimapTrackingButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            -- Mover el icono/botón manualmente - TÚ CONTROLAS CUÁNTO
            if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                -- Mover icono OLD STYLE: 1 pixel abajo-derecha (sutil)
                MiniMapTrackingIcon:ClearAllPoints()
                MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 2, -2)
            end
        end
    end)

    minimapTrackingButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            -- Restaurar posición original cuando sueltas
            if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
                MiniMapTrackingIcon:ClearAllPoints()
                MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
            end
        end
    end)

    --  HOOK PARA RESETEAR POSICIÓN DEL ICONO DESPUÉS DE CLICKS
    local function ResetTrackingIconPosition()
        if MiniMapTrackingIcon and MiniMapTrackingIcon:GetAlpha() > 0 then
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)
        end
    end

    -- Hook al cierre del dropdown
    hooksecurefunc("CloseDropDownMenus", ResetTrackingIconPosition)
end

local function CreateMinimapBorderFrame(width, height)
    local minimapBorderFrame = CreateFrame('Frame', UIParent)
    minimapBorderFrame:SetSize(width, height)
    minimapBorderFrame:SetScript("OnUpdate", function(self)
        local angle = GetPlayerFacing()
        self.border:SetRotation(angle)
    end)

    do
        local texture = minimapBorderFrame:CreateTexture(nil, "BORDER")
        texture:SetAllPoints(minimapBorderFrame)
        texture:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\Minimap\\MinimapBorder.blp")

        minimapBorderFrame.border = texture
    end

    minimapBorderFrame:Hide()
    return minimapBorderFrame
end

--  ADDON ICON SKINNING: Aplicar borders personalizados a iconos de addons (del minimap_core.lua)
local WHITE_LIST = {
    'MiniMapBattlefieldFrame','MiniMapTrackingButton','MiniMapMailFrame','HelpOpenTicketButton',
    'GatherMatePin','HandyNotesPin','TimeManagerClockButton','Archy','GatherNote','MinimMap',
    'Spy_MapNoteList_mini','ZGVMarker','poiWorldMapPOIFrame','WorldMapPOIFrame','QuestMapPOI',
    'GameTimeFrame'
}

local function IsFrameWhitelisted(frameName)
    if not frameName then return false end

    for i, buttons in pairs(WHITE_LIST) do
        if frameName ~= nil then
            if frameName:match(buttons) then
                return true
            end
        end
    end
    return false
end

-- Funciones de fade para hover effect
local function fadein(self)
    securecall(UIFrameFadeIn, self, 0.2, self:GetAlpha(), 1.0)
end

local function fadeout(self)
    securecall(UIFrameFadeOut, self, 0.2, self:GetAlpha(), 0.2)
end

-- Función para aplicar skin personalizado a iconos de addons (COPIA EXACTA del oldminimapcore.lua)
local function ApplyAddonIconSkin(button)
    if not button or button:GetObjectType() ~= 'Button' then
        return
    end

    local frameName = button:GetName()
    --  USAR LA VERIFICACIÓN EXACTA DEL OLDMINIMAPCORE.LUA
    if IsFrameWhitelisted(frameName) then
        return
    end

    -- Procesar texturas EXACTO como oldminimapcore.lua
    for index = 1, button:GetNumRegions() do
        local region = select(index, button:GetRegions())
        if region:GetObjectType() == 'Texture' then
            local name = region:GetTexture()
            if name and (name:find('Border') or name:find('Background') or name:find('AlphaMask')) then
                region:SetTexture(nil)
            else
                region:ClearAllPoints()
                region:SetPoint('TOPLEFT', button, 'TOPLEFT', 2, -2)
                region:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2)
                region:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                region:SetDrawLayer('ARTWORK')
                --  FORZAR TAMAÑO DEL ICONO PARA QUE COINCIDA CON EL TEXCOORD
                region:SetSize(18, 18)
                if frameName == 'PS_MinimapButton' then
                    region.SetPoint = addon._noop
                end
            end
        end
    end

    -- Limpiar texturas del botón EXACTO como oldminimapcore.lua
    button:SetPushedTexture(nil)
    button:SetHighlightTexture(nil)
    button:SetDisabledTexture(nil)
    button:SetSize(21, 21)

    -- Aplicar border EXACTO como oldminimapcore.lua
    button.circle = button:CreateTexture(nil, 'OVERLAY')
    button.circle:SetSize(23, 23)
    button.circle:SetPoint('CENTER', button)
    button.circle:SetTexture("Interface\\AddOns\\DragonUI\\assets\\border_buttons.tga")

    --  VERIFICACIÓN SEGURA DE CONFIGURACIÓN
    local fadeEnabled = false

    -- Primero verificar DragonUI database (principal)
    if addon.db and addon.db.profile and addon.db.profile.minimap then
        fadeEnabled = addon.db.profile.minimap.addon_button_fade or false
    end

    if fadeEnabled then
        button:SetAlpha(0.2)
        button:HookScript('OnEnter', fadein)
        button:HookScript('OnLeave', fadeout)
    else
        button:SetAlpha(1)
    end
end



--  BORDER REMOVAL: Aplicar skin a iconos (SIMPLE como oldminimapcore.lua)
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

    --  APLICAR SKIN SIMPLE A TODOS LOS BOTONES
    local function ApplySkinsToAllButtons()
        -- Verificar si el skinning está habilitado
        local skinEnabled = addon.db and addon.db.profile and addon.db.profile.minimap and
                           addon.db.profile.minimap.addon_button_skin

        if not skinEnabled then
            return
        end

        for i = 1, Minimap:GetNumChildren() do
            local child = select(i, Minimap:GetChildren())
            if child and child:GetObjectType() == "Button" then
                ApplyAddonIconSkin(child)
            end
        end
    end

    -- Aplicar inmediatamente
    ApplySkinsToAllButtons()
end

--  PVP STYLING: Estilizar frame PVP con faction detection (del minimapa_old.lua)
local function StylePVPBattlefieldFrame()
    if not MiniMapBattlefieldFrame then return end

    -- Configurar el frame PVP como en minimapa_old.lua
    MiniMapBattlefieldFrame:SetSize(44, 44)
    MiniMapBattlefieldFrame:ClearAllPoints()
    MiniMapBattlefieldFrame:SetPoint('BOTTOMLEFT', Minimap, 0, 18)
    MiniMapBattlefieldFrame:SetNormalTexture('')
    MiniMapBattlefieldFrame:SetPushedTexture('')

    -- Detectar facción del jugador y aplicar texturas apropiadas
    local faction = string.lower(UnitFactionGroup('player'))

    -- Aplicar texturas usando SetAtlasTexture
    if MiniMapBattlefieldFrame:GetNormalTexture() then
        SetAtlasTexture(MiniMapBattlefieldFrame:GetNormalTexture(), 'Minimap-PVP-' .. faction .. '-Normal')
    end
    if MiniMapBattlefieldFrame:GetPushedTexture() then
        SetAtlasTexture(MiniMapBattlefieldFrame:GetPushedTexture(), 'Minimap-PVP-' .. faction .. '-Pushed')
    end

    -- Configurar script de click como en minimapa_old.lua
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
            --  SIMPLE: Usar la misma función que el botón PVP del micromenu
            TogglePVPFrame()
        end
    end)
end

local function RemoveBlizzardFrames()
    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Hide()
        MiniMapWorldMapButton:UnregisterAllEvents()
        MiniMapWorldMapButton:SetScript("OnClick", nil)
        MiniMapWorldMapButton:SetScript("OnEnter", nil)
        MiniMapWorldMapButton:SetScript("OnLeave", nil)
    end

    local blizzFrames =
        {MiniMapTrackingIcon, MiniMapTrackingIconOverlay, MiniMapMailBorder, MiniMapTrackingButtonBorder}

    for _, frame in pairs(blizzFrames) do
        frame:SetAlpha(0)
    end

    --  LLAMAR A LAS NUEVAS FUNCIONES
    RemoveAllMinimapIconBorders()
    StylePVPBattlefieldFrame()
end

local function Minimap_UpdateRotationSetting()
    local minimapBorder = MinimapBorder
    if GetCVar("rotateMinimap") == "1" then
        if MinimapModule.borderFrame then
            MinimapModule.borderFrame:Show()
        end
        minimapBorder:Hide()
    else
        if MinimapModule.borderFrame then
            MinimapModule.borderFrame:Hide()
        end
        minimapBorder:Show()
    end

    MinimapNorthTag:Hide()
    MinimapCompassTexture:Hide()
end

local selectedRaidDifficulty
local allowedRaidDifficulty

--  TRACKING UPDATE FUNCTION - Using exact logic from minimap_map.lua with atlas textures
function MinimapModule:UpdateTrackingIcon()
    local texture = GetTrackingTexture()

    local useOldStyle = addon.db and addon.db.profile and addon.db.profile.minimap and
                            addon.db.profile.minimap.tracking_icons

    --  VERIFICACIÓN DE SEGURIDAD
    if not addon or not addon.db then
        return
    end

    if useOldStyle == nil then
        useOldStyle = false
    end

    --  VERIFICACIÓN ADICIONAL: Asegurar que los frames existen
    if not MiniMapTrackingIcon or not MiniMapTrackingButton then
        return
    end



    if useOldStyle then

        if texture == 'Interface\\Minimap\\Tracking\\None' then

            -- OLD STYLE + No tracking = Mostrar icono de lupa por defecto
            MiniMapTrackingIcon:SetTexture('')
            MiniMapTrackingIcon:SetAlpha(0)

            -- Mostrar el botón moderno como "icono de lupa" por defecto
            local normalTexture = MiniMapTrackingButton:GetNormalTexture()
            if normalTexture then
                SetAtlasTexture(normalTexture, 'Minimap-Tracking-Normal')
            end

            local pushedTexture = MiniMapTrackingButton:GetPushedTexture()
            if pushedTexture then
                SetAtlasTexture(pushedTexture, 'Minimap-Tracking-Pushed')
            end

            local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
            if highlightTexture then
                SetAtlasTexture(highlightTexture, 'Minimap-Tracking-Highlight')
            end
        else

            -- OLD STYLE + Tracking active = Mostrar el icono específico del tracking
            MiniMapTrackingIcon:SetTexture(texture)
            MiniMapTrackingIcon:SetTexCoord(0, 1, 0, 1)
            MiniMapTrackingIcon:SetSize(20, 20)
            MiniMapTrackingIcon:SetAlpha(1)
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint('CENTER', MiniMapTracking, 'CENTER', 0, 0)

            -- Limpiar texturas del botón para que no interfieran con el icono específico
            MiniMapTrackingButton:SetNormalTexture('')
            MiniMapTrackingButton:SetPushedTexture('')
            local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
            if highlightTexture then
                highlightTexture:SetTexture('')
            end
        end
    else

        --  MODERN STYLE: Siempre mostrar botón moderno (RetailUI style)

        -- Limpiar el icono clásico para que no interfiera
        MiniMapTrackingIcon:SetTexture('')
        MiniMapTrackingIcon:SetAlpha(0)

        -- Usar las texturas de RetailUI que ya funcionan (las que están en ReplaceBlizzardFrame)
        local normalTexture = MiniMapTrackingButton:GetNormalTexture()
        if normalTexture then
            SetAtlasTexture(normalTexture, 'Minimap-Tracking-Normal')
        end

        local pushedTexture = MiniMapTrackingButton:GetPushedTexture()
        if pushedTexture then
            SetAtlasTexture(pushedTexture, 'Minimap-Tracking-Pushed')
        end

        local highlightTexture = MiniMapTrackingButton:GetHighlightTexture()
        if highlightTexture then
            SetAtlasTexture(highlightTexture, 'Minimap-Tracking-Highlight')
        end


    end

    -- Siempre ocultar overlay
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
        -- the 1 looks a little off when text is centered
        local xOffset = 0
        if maxPlayers >= 10 and maxPlayers <= 19 then
            xOffset = -1
        end

        local minimapInstanceTexture = MiniMapInstanceDifficultyTexture

        if isHeroic then
            SetAtlasTexture(minimapInstanceTexture, 'Minimap-GuildBanner-Heroic')
            MiniMapInstanceDifficultyText:SetPoint("CENTER", xOffset, -6)
        else
            SetAtlasTexture(minimapInstanceTexture, 'Minimap-GuildBanner-Normal')
            MiniMapInstanceDifficultyText:SetPoint("CENTER", xOffset, 2)
        end
        minimapInstanceTexture:SetSize(minimapInstanceTexture:GetWidth() * 0.45,
            minimapInstanceTexture:GetHeight() * 0.45)
        self:Show()
    else
        self:Hide()
    end
end

-- =================================================================
-- MODULE ENABLE/DISABLE SYSTEM
-- =================================================================

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

    -- Store that we need to restore to Blizzard default mask
    if not self.originalMask then
        self.originalMask = "Textures\\MinimapMask"  -- Standard Blizzard default

    end
end

function MinimapModule:ApplyMinimapSystem()
    if self.isEnabled then
        return  -- Already enabled
    end



    -- Store original settings before applying DragonUI changes
    self:StoreOriginalSettings()

    -- Initialize the DragonUI minimap system
    self:InitializeMinimapSystem()

    self.isEnabled = true

end

function MinimapModule:RestoreMinimapSystem()
    if not self.isEnabled then
        return  -- Already disabled
    end



    -- Hide DragonUI frames
    if self.minimapFrame then
        self.minimapFrame:Hide()
    end
    if self.borderFrame then
        self.borderFrame:Hide()
    end

    -- Restore original Blizzard minimap settings
    if MinimapCluster and self.originalMinimapSettings.isStored then
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint(
            self.originalMinimapSettings.point or "TOPRIGHT",
            self.originalMinimapSettings.relativeTo or UIParent,
            self.originalMinimapSettings.relativePoint or "TOPRIGHT",
            self.originalMinimapSettings.xOfs or -16,
            self.originalMinimapSettings.yOfs or -116
        )
        MinimapCluster:SetScale(self.originalMinimapSettings.scale or 1.0)
    end

    -- Restore original Blizzard frames that were hidden
    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Show()
    end

    -- Restore original textures and positions
    if MinimapBorder then
        MinimapBorder:Show()
    end

    if Minimap.Circle then
        Minimap.Circle:Hide()
    end

    -- CRITICAL: Restore original Blizzard minimap mask
    if Minimap then
        local maskToRestore = self.originalMask or "Textures\\MinimapMask"
        Minimap:SetMaskTexture(maskToRestore)

    end

    self.isEnabled = false

end

function MinimapModule:InitializeMinimapSystem()
    -- Load TimeManager addon if not loaded
    if not IsAddOnLoaded('Blizzard_TimeManager') then
        LoadAddOn('Blizzard_TimeManager')
    end

    self.minimapFrame = CreateUIFrame(230, 230, "MinimapFrame")

    --  REGISTRO AUTOMÁTICO EN EL SISTEMA CENTRALIZADO
    addon:RegisterEditableFrame({
        name = "minimap",
        frame = self.minimapFrame,
        blizzardFrame = MinimapCluster,
        configPath = {"widgets", "minimap"},
        onHide = function()
            self:UpdateWidgets() -- Aplicar nueva configuración al salir del editor
        end,
        module = self
    })

    local defaultX, defaultY = -7, 0
    local widgetConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.minimap

    if widgetConfig then
        self.minimapFrame:SetPoint(widgetConfig.anchor or "TOPRIGHT", UIParent, widgetConfig.anchor or "TOPRIGHT",
                                  widgetConfig.posX or defaultX, widgetConfig.posY or defaultY)
    else
        self.minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", defaultX, defaultY)
    end

    self.borderFrame = CreateMinimapBorderFrame(232, 232)
    self.borderFrame:SetPoint("CENTER", MinimapBorder, "CENTER", 0, -2)

    RemoveBlizzardFrames()
    ReplaceBlizzardFrame(self.minimapFrame)

    --  AÑADIR ESTA LÍNEA PARA APLICAR TODAS LAS CONFIGURACIONES AL INICIO
    self:UpdateSettings()

    -- Hook tracking changes to update icon automatically
    MiniMapTrackingButton:HookScript("OnEvent", function()
        self:UpdateTrackingIcon()
    end)

    -- Initial tracking icon update
    self:UpdateTrackingIcon()


end

function MinimapModule:Initialize()
    -- Check if minimap module is enabled
    local isEnabled = addon.db and addon.db.profile and addon.db.profile.modules and
                     addon.db.profile.modules.minimap and addon.db.profile.modules.minimap.enabled

    if isEnabled == nil then
        isEnabled = true  -- Default to enabled for existing installations
    end

    if not isEnabled then

        -- Don't apply any DragonUI modifications when disabled
        return
    end

    -- Only apply DragonUI modifications if module is enabled
    self:ApplyMinimapSystem()
end

-- Eliminar las funciones que no existen más y convertir en funciones DragonUI
function MinimapModule:UpdateSettings()
    local scale = addon.db.profile.minimap.scale or 1.0

    if self.minimapFrame then
        --  MANEJAR POSICIÓN: Prioridad a widgets (editor mode), fallback a x,y
        local x, y, anchor

        -- 1. Intentar usar posición del editor mode (widgets)
        if addon.db.profile.widgets and addon.db.profile.widgets.minimap then
            local widgetConfig = addon.db.profile.widgets.minimap
            anchor = widgetConfig.anchor or "TOPRIGHT"
            x = widgetConfig.posX or 0
            y = widgetConfig.posY or 0

        else
            -- 2. Fallback a posición legacy (x, y)
            x = addon.db.profile.minimap.x or -7
            y = addon.db.profile.minimap.y or 0
            anchor = "TOPRIGHT"

        end

        --  APLICAR POSICIÓN
        self.minimapFrame:ClearAllPoints()
        self.minimapFrame:SetPoint(anchor, UIParent, anchor, x, y)

        --  APLICAR ESCALA (funciona perfecto ahora)
        if MinimapCluster then
            MinimapCluster:SetScale(scale)

        end

        if self.borderFrame then
            self.borderFrame:SetScale(scale)
        end

        --  APLICAR TODAS LAS CONFIGURACIONES
        self:ApplyAllSettings()
    end

    --  CONFIGURACIONES GLOBALES DEL MINIMAP
    if Minimap then
        -- Apply blip texture based on user setting (new vs old style)
        local useNewBlipStyle = addon.db.profile.minimap.blip_skin
        if useNewBlipStyle == nil then
            useNewBlipStyle = true -- Default to new style
        end

        local blipTexture = useNewBlipStyle and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or 'Interface\\Minimap\\ObjectIcons'
        Minimap:SetBlipTexture(blipTexture)

        local playerArrowSize = addon.db.profile.minimap.player_arrow_size
        if playerArrowSize then
            Minimap:SetPlayerTextureHeight(playerArrowSize)
            Minimap:SetPlayerTextureWidth(playerArrowSize)
        end
    end

    --  REFRESCAR OTROS ELEMENTOS
    self:UpdateTrackingIcon()


end

local function GetClockTextFrame()
    if not TimeManagerClockButton then
        return nil
    end

    -- Intentar múltiples métodos para encontrar el texto del reloj
    local clockText = TimeManagerClockButton.text
    if clockText then
        return clockText
    end

    clockText = TimeManagerClockButton:GetFontString()
    if clockText then
        return clockText
    end

    -- Buscar en los children
    for i = 1, TimeManagerClockButton:GetNumChildren() do
        local child = select(i, TimeManagerClockButton:GetChildren())
        if child and child.GetFont then
            return child
        end
    end

    -- Buscar en las regiones
    for i = 1, TimeManagerClockButton:GetNumRegions() do
        local region = select(i, TimeManagerClockButton:GetRegions())
        if region and region.GetFont then
            return region
        end
    end

    return nil
end

--  NUEVA FUNCIÓN PARA APLICAR TODAS LAS CONFIGURACIONES
function MinimapModule:ApplyAllSettings()
    if not addon.db or not addon.db.profile or not addon.db.profile.minimap then
        return
    end

    local settings = addon.db.profile.minimap

    --  APLICAR BORDER ALPHA
    if MinimapBorderTop and settings.border_alpha then
        MinimapBorderTop:SetAlpha(settings.border_alpha)
    end

    --  APLICAR ZOOM BUTTONS VISIBILITY
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

    --  APLICAR CALENDAR VISIBILITY
    if settings.calendar ~= nil then
        if GameTimeFrame then
            if settings.calendar then
                GameTimeFrame:Show()
            else
                GameTimeFrame:Hide()
            end
        end
    end

    --  APLICAR CLOCK VISIBILITY Y AJUSTAR ZONA TEXT
    if settings.clock ~= nil then
        if TimeManagerClockButton then
            if settings.clock then
                TimeManagerClockButton:Show()
                -- Clock visible: zona text alineado a la izquierda (posición original)
                if MinimapZoneTextButton then
                    MinimapZoneTextButton:ClearAllPoints()
                    MinimapZoneTextButton:SetPoint("LEFT", MinimapBorderTop, "LEFT", 7, 1)
                    MinimapZoneTextButton:SetWidth(108)
                end
                if MinimapZoneText then
                    MinimapZoneText:SetJustifyH("LEFT")
                end
            else
                TimeManagerClockButton:Hide()
                -- Clock oculto: centrar zona text en todo el border
                if MinimapZoneTextButton then
                    MinimapZoneTextButton:ClearAllPoints()
                    MinimapZoneTextButton:SetPoint("CENTER", MinimapBorderTop, "CENTER", 0, 1)
                    MinimapZoneTextButton:SetWidth(150) -- Más ancho para texto centrado
                end
                if MinimapZoneText then
                    MinimapZoneText:SetJustifyH("CENTER")
                end
            end
        end
    end

    --  APLICAR CLOCK FONT SIZE (MEJORADO)
    if settings.clock_font_size and TimeManagerClockButton then
        local clockText = GetClockTextFrame()
        if clockText then
            local font, _, flags = clockText:GetFont()
            clockText:SetFont(font, settings.clock_font_size, flags)

        else

        end
    end

    --  APLICAR ZONE TEXT FONT SIZE
    if settings.zonetext_font_size and MinimapZoneText then
        local font, _, flags = MinimapZoneText:GetFont()
        MinimapZoneText:SetFont(font, settings.zonetext_font_size, flags)
    end

    --  APLICAR BLIP TEXTURE (NEW VS OLD STYLE)
    if settings.blip_skin ~= nil and Minimap then
        local blipTexture = settings.blip_skin and "Interface\\AddOns\\DragonUI\\assets\\objecticons" or 'Interface\\Minimap\\ObjectIcons'
        Minimap:SetBlipTexture(blipTexture)
    end

    --  APLICAR PLAYER ARROW SIZE
    if settings.player_arrow_size and Minimap then
        Minimap:SetPlayerTextureHeight(settings.player_arrow_size)
        Minimap:SetPlayerTextureWidth(settings.player_arrow_size)
    end
end
--  Editor Mode Functions
function MinimapModule:LoadDefaultSettings()
    --  USAR LA BASE DE DATOS CORRECTA: addon.db (no addon.core.db)
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
    --  USAR LA BASE DE DATOS CORRECTA: addon.db (no addon.core.db)
    if not addon.db or not addon.db.profile.widgets or not addon.db.profile.widgets.minimap then

        self:LoadDefaultSettings()
        return
    end

    local widgetOptions = addon.db.profile.widgets.minimap
    self.minimapFrame:SetPoint(widgetOptions.anchor, widgetOptions.posX, widgetOptions.posY)


end

--  FUNCIONES EDITOR MODE ELIMINADAS - AHORA USA SISTEMA CENTRALIZADO

-- Función de refresh para ser llamada desde options.lua
function addon:RefreshMinimap()
    if MinimapModule.isEnabled then
        MinimapModule:UpdateSettings()
        -- Also update tracking icon when settings change
        MinimapModule:UpdateTrackingIcon()
        --  NUEVO: Refrescar skinning de iconos de addons
        RemoveAllMinimapIconBorders()
    end
end

-- Función de refresh del sistema para habilitar/deshabilitar
function addon:RefreshMinimapSystem()
    local isEnabled = addon.db and addon.db.profile and addon.db.profile.modules and
                     addon.db.profile.modules.minimap and addon.db.profile.modules.minimap.enabled

    if isEnabled == nil then
        isEnabled = true  -- Default to enabled
    end

    if isEnabled then
        MinimapModule:ApplyMinimapSystem()
    else
        MinimapModule:RestoreMinimapSystem()
    end
end

--  NUEVA FUNCIÓN: Limpiar skinning de todos los botones
local function CleanAllMinimapButtons()
    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if child and child:GetObjectType() == "Button" and child.circle then
            -- Limpiar el border del oldminimapcore.lua style
            child.circle:Hide()
            child.circle = nil
        end
    end
end

--  FUNCIÓN PARA DEBUGGING
function addon:DebugMinimapButtons()

    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if child and child:GetObjectType() == "Button" then
            local name = child:GetName() or "Unnamed"
            local hasBorder = child.circle and "YES" or "NO"
            local width, height = child:GetSize()

        end
    end
end

-- =================================================================
-- INICIALIZACIÓN
-- =================================================================

-- Inicializar cuando el addon esté listo
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
