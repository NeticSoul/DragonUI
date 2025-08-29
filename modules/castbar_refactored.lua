local addon = select(2, ...);

-- #################################################################
-- ##                    DragonUI Castbar Module                    ##
-- ##      (Refactorizado para eficiencia WotLK 3.3.5a)             ##
-- #################################################################

-- =================================================================
-- CONSTANTES Y CONFIGURACIONES CONSOLIDADAS
-- =================================================================

-- Rutas de texturas optimizadas
local TEXTURE_PATH = "Interface\\AddOns\\DragonUI\\Textures\\CastbarOriginal\\";
local TEXTURES = {
    atlas = TEXTURE_PATH .. "uicastingbar2x",
    atlasSmall = TEXTURE_PATH .. "uicastingbar",
    standard = TEXTURE_PATH .. "CastingBarStandard2",
    channel = TEXTURE_PATH .. "CastingBarChannel",
    interrupted = TEXTURE_PATH .. "CastingBarInterrupted2",
    spark = TEXTURE_PATH .. "CastingBarSpark"
};

-- Coordenadas UV unificadas
local UV_COORDS = {
    background = {0.0009765625, 0.4130859375, 0.3671875, 0.41796875},
    border = {0.412109375, 0.828125, 0.001953125, 0.060546875},
    flash = {0.0009765625, 0.4169921875, 0.2421875, 0.30078125},
    spark = {0.076171875, 0.0859375, 0.796875, 0.9140625},
    borderShield = {0.000976562, 0.0742188, 0.796875, 0.970703},
    textBorder = {0.001953125, 0.412109375, 0.00390625, 0.11328125}
};

-- Configuración de canal ticks
local CHANNEL_TICKS = {
    -- Warlock
    ["Drain Soul"] = 5,
    ["Drain Life"] = 5,
    ["Drain Mana"] = 5,
    ["Rain of Fire"] = 4,
    ["Hellfire"] = 15,
    ["Ritual of Summoning"] = 5,
    -- Priest
    ["Mind Flay"] = 3,
    ["Mind Control"] = 8,
    ["Penance"] = 2,
    -- Mage
    ["Blizzard"] = 8,
    ["Evocation"] = 4,
    ["Arcane Missiles"] = 5,
    -- Otros
    ["Tranquility"] = 4,
    ["Hurricane"] = 10,
    ["First Aid"] = 8
};

-- Configuración de escudo simplificado
local SHIELD_CONFIG = {
    texture = TEXTURES.atlas,
    texCoords = UV_COORDS.borderShield,
    baseIconSize = 20,
    shieldWidthRatio = 1.8, -- 36/20
    shieldHeightRatio = 2.0, -- 40/20
    borderRatio = 1.7, -- 34/20
    position = {
        x = 0,
        y = -4
    },
    alpha = 1.0,
    color = {
        r = 1,
        g = 1,
        b = 1
    }
};

-- Configuración de auras simplificada
local AURA_CONFIG = {
    auraSize = 22,
    rowSpacing = 2,
    baseOffset = 0,
    minRowsToAdjust = 2,
    updateInterval = 0.05
};

-- Constantes adicionales
local GRACE_PERIOD_AFTER_SUCCESS = 0.15;

-- =================================================================
-- VARIABLES DE ESTADO UNIFICADAS
-- =================================================================

-- Estados por tipo de castbar (consolidado)
local castbarStates = {
    player = {
        casting = false,
        isChanneling = false,
        spellStartTime = 0,
        spellEndTime = 0, -- AÑADIDO: Para seguimiento de tiempo absoluto y pushback
        spellDuration = 0,
        holdTime = 0,
        currentSpellName = "",
        currentValue = 0,
        maxValue = 0,
        castSucceeded = false,
        graceTime = 0
    },
    target = {
        casting = false,
        isChanneling = false,
        spellStartTime = 0,
        spellDuration = 0,
        holdTime = 0,
        currentSpellName = "",
        currentValue = 0,
        maxValue = 0
    },
    focus = {
        casting = false,
        isChanneling = false,
        spellStartTime = 0,
        spellDuration = 0,
        holdTime = 0,
        currentSpellName = "",
        currentValue = 0,
        maxValue = 0
    }
};

-- Frames consolidados
local frames = {
    player = {},
    target = {},
    focus = {}
};

-- Control de refreshes para evitar múltiples refreshes rápidos
local lastRefreshTime = {
    player = 0,
    target = 0,
    focus = 0
};

-- Caché de auras optimizado
local auraCache = {
    target = {
        lastUpdate = 0,
        lastRows = 0,
        lastOffset = 0,
        lastTargetGUID = nil,
        updateInterval = AURA_CONFIG.updateInterval
    }
};

-- =================================================================
-- FUNCIONES AUXILIARES OPTIMIZADAS
-- =================================================================

local RefreshCastbar;
-- Forward declarations for functions used before definition
local HandleCastStop;

-- Función para forzar la capa correcta de StatusBar texture
local function ForceStatusBarTextureLayer(statusBar)
    if not statusBar then
        return
    end
    local texture = statusBar:GetStatusBarTexture();
    if texture and texture.SetDrawLayer then
        texture:SetDrawLayer('BORDER', 0);
    end
end

-- Función unificada para aplicar color de vértice
local function ApplyVertexColor(statusBar)
    if not statusBar or not statusBar.SetStatusBarColor then
        return
    end

    if not statusBar._originalSetStatusBarColor then
        statusBar._originalSetStatusBarColor = statusBar.SetStatusBarColor;
        statusBar.SetStatusBarColor = function(self, r, g, b, a)
            statusBar._originalSetStatusBarColor(self, r, g, b, a or 1);
            local texture = self:GetStatusBarTexture();
            if texture then
                texture:SetVertexColor(1, 1, 1, 1)
            end
        end;
    end

    local texture = statusBar:GetStatusBarTexture();
    if texture then
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

-- Función mejorada de detección de iconos (4 métodos)
local function GetSpellIconImproved(spellName, texture, castID)
    if texture and texture ~= "" then
        return texture
    end
    if spellName then
        local spellTexture = GetSpellTexture(spellName);
        if spellTexture then
            return spellTexture
        end
        -- Búsqueda en spellbook
        for i = 1, 1024 do
            local name, _, icon = GetSpellInfo(i, BOOKTYPE_SPELL);
            if not name then
                break
            end
            if name == spellName and icon then
                return icon
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark";
end

-- Función unificada para parsing de tiempos de cast
local function ParseCastTimes(startTime, endTime)
    local start = tonumber(startTime) or 0;
    local finish = tonumber(endTime) or 0;
    local startSeconds = start / 1000;
    local endSeconds = finish / 1000;
    return startSeconds, endSeconds, endSeconds - startSeconds;
end

-- =================================================================
-- SISTEMA DE TICKS DE CANAL OPTIMIZADO
-- =================================================================

-- Crear ticks de canal (función consolidada)
local function CreateChannelTicks(parentFrame, ticksTable, maxTicks)
    maxTicks = maxTicks or 15;
    for i = 1, maxTicks do
        local tick = parentFrame:CreateTexture('Tick' .. i, 'ARTWORK', nil, 1);
        tick:SetTexture('Interface\\ChatFrame\\ChatFrameBackground');
        tick:SetVertexColor(0, 0, 0);
        tick:SetAlpha(0.75);
        tick:SetSize(3, math.max(parentFrame:GetHeight() - 2, 10));
        tick:SetPoint('CENTER', parentFrame, 'LEFT', parentFrame:GetWidth() / 2, 0);
        tick:Hide();
        ticksTable[i] = tick;
    end
end

-- Actualizar posiciones de ticks
local function UpdateChannelTicks(parentFrame, ticksTable, spellName, maxTicks)
    maxTicks = maxTicks or 15;

    -- Ocultar todos los ticks primero
    for i = 1, maxTicks do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end

    local tickCount = CHANNEL_TICKS[spellName];
    if not tickCount or tickCount <= 1 then
        return
    end

    local castbarWidth = parentFrame:GetWidth();
    local castbarHeight = parentFrame:GetHeight();
    local tickDelta = castbarWidth / tickCount;

    -- Mostrar y posicionar los ticks necesarios
    for i = 1, math.min(tickCount - 1, maxTicks) do
        if ticksTable[i] then
            ticksTable[i]:SetSize(3, math.max(castbarHeight - 2, 10));
            ticksTable[i]:SetPoint('CENTER', parentFrame, 'LEFT', i * tickDelta, 0);
            ticksTable[i]:Show();
        end
    end
end

-- Ocultar todos los ticks
local function HideAllChannelTicks(ticksTable, maxTicks)
    maxTicks = maxTicks or 15;
    for i = 1, maxTicks do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end
end

-- =================================================================
-- SISTEMA DE ESCUDO SIMPLIFICADO
-- =================================================================

-- Crear escudo simplificado (reemplaza sistema de 4 piezas)
local function CreateSimplifiedShield(parentFrame, iconTexture, frameName, iconSize)
    if not parentFrame or not iconTexture then
        return nil
    end

    local shieldWidth = iconSize * SHIELD_CONFIG.shieldWidthRatio;
    local shieldHeight = iconSize * SHIELD_CONFIG.shieldHeightRatio;

    local shield = CreateFrame("Frame", frameName .. "Shield", parentFrame);
    shield:SetFrameLevel(parentFrame:GetFrameLevel() - 1);

    local texture = shield:CreateTexture(nil, "ARTWORK", nil, 3);
    texture:SetAllPoints(shield);
    texture:SetTexture(SHIELD_CONFIG.texture);
    texture:SetTexCoord(unpack(SHIELD_CONFIG.texCoords));
    texture:SetVertexColor(SHIELD_CONFIG.color.r, SHIELD_CONFIG.color.g, SHIELD_CONFIG.color.b, SHIELD_CONFIG.alpha);

    shield:SetSize(shieldWidth, shieldHeight);
    shield:ClearAllPoints();
    shield:SetPoint("CENTER", iconTexture, "CENTER", SHIELD_CONFIG.position.x, SHIELD_CONFIG.position.y);

    shield.iconTexture = iconTexture;
    shield.texture = texture;
    shield:Hide();

    return shield;
end

-- Actualizar tamaños proporcionales de escudo y borde
local function UpdateProportionalSizes(castbarType, iconSize)
    if not iconSize then
        return
    end

    local frameData = frames[castbarType];
    if not frameData then
        return
    end

    -- Actualizar escudo si existe
    if frameData.shield then
        local shieldWidth = iconSize * SHIELD_CONFIG.shieldWidthRatio;
        local shieldHeight = iconSize * SHIELD_CONFIG.shieldHeightRatio;
        frameData.shield:SetSize(shieldWidth, shieldHeight);
    end

    -- Actualizar borde del icono si existe
    if frameData.icon and frameData.icon.Border then
        local borderSize = iconSize * SHIELD_CONFIG.borderRatio;
        frameData.icon.Border:SetSize(borderSize, borderSize);
    end
end

-- =================================================================
-- SISTEMA DE OFFSET DE AURAS OPTIMIZADO
-- =================================================================

-- Contar auras visibles manualmente (respuesta inmediata)
local function CountVisibleAuras(unit)
    if not UnitExists(unit) then
        return 0
    end

    local count = 0;
    local maxCheck = 32; -- Verificar hasta 32 auras (4 filas de 8)

    -- Contar buffs
    for i = 1, maxCheck do
        local name = UnitAura(unit, i, "HELPFUL");
        if name then
            count = count + 1
        else
            break
        end
    end

    -- Contar debuffs
    for i = 1, maxCheck do
        local name = UnitAura(unit, i, "HARMFUL");
        if name then
            count = count + 1
        else
            break
        end
    end

    return math.ceil(count / 8); -- Convertir a filas (8 auras por fila)
end

-- Obtener offset de auras del target simplificado
local function GetTargetAuraOffsetSimplified()
    if not addon.db or not addon.db.profile.castbar or not addon.db.profile.castbar.target or
        not addon.db.profile.castbar.target.autoAdjust then
        return AURA_CONFIG.baseOffset;
    end

    local currentTime = GetTime();
    local currentGUID = UnitGUID("target");
    local targetChanged = auraCache.target.lastTargetGUID ~= currentGUID;

    -- Usar caché solo si el target no ha cambiado y el caché es reciente
    if not targetChanged and (currentTime - auraCache.target.lastUpdate) < auraCache.target.updateInterval then
        return auraCache.target.lastOffset;
    end

    -- Obtener filas directamente del cálculo nativo de WoW
    local rows = 0;
    if TargetFrame and TargetFrame.auraRows then
        rows = TargetFrame.auraRows;
    else
        rows = CountVisibleAuras("target"); -- Fallback manual
    end

    -- Calcular offset basado en lógica de ultimaversion
    local offset = AURA_CONFIG.baseOffset;
    if rows > AURA_CONFIG.minRowsToAdjust then
        local delta = (rows - AURA_CONFIG.minRowsToAdjust) * (AURA_CONFIG.auraSize + AURA_CONFIG.rowSpacing);
        local parent = TargetFrame;
        if not parent.buffsOnTop then
            offset = AURA_CONFIG.baseOffset + delta;
        end
    end

    -- Actualizar caché
    auraCache.target.lastUpdate = currentTime;
    auraCache.target.lastRows = rows;
    auraCache.target.lastOffset = offset;
    auraCache.target.lastTargetGUID = currentGUID;

    return offset;
end

-- Aplicar offset de auras simplificado al castbar del target
local function ApplySimplifiedAuraOffsetToTargetCastbar()
    if not frames.target.castbar or not frames.target.castbar:IsVisible() then
        return
    end

    local cfg = addon.db.profile.castbar.target;
    if not cfg.enabled or not cfg.autoAdjust then
        return
    end

    local offset = GetTargetAuraOffsetSimplified();
    local anchorFrame = _G[cfg.anchorFrame] or TargetFrame or UIParent;

    frames.target.castbar:ClearAllPoints();
    frames.target.castbar:SetPoint(cfg.anchor, anchorFrame, cfg.anchorParent, cfg.x_position, cfg.y_position - offset);
end

-- =================================================================
-- FUNCIONES DE VISIBILIDAD Y MODO DE TEXTO OPTIMIZADAS
-- =================================================================

-- Función unificada para establecer visibilidad de iconos
local function SetIconVisibility(castbarType, bShown)
    local frameData = frames[castbarType];
    if not frameData or not frameData.icon then
        return
    end

    if bShown then
        frameData.icon:Show();
    else
        frameData.icon:Hide();
    end

    if frameData.icon.Border then
        if bShown then
            frameData.icon.Border:Show();
        else
            frameData.icon.Border:Hide();
        end
    end
end

-- Función unificada para establecer layout compacto
local function SetCompactLayout(castbarType, bCompact)
    local frameData = frames[castbarType];
    if not frameData or not frameData.castText or not frameData.castTextCompact then
        return
    end

    if bCompact then
        frameData.castText:Hide();
        frameData.castTextCompact:Show();
        if frameData.castTimeText then
            frameData.castTimeText:Hide()
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:Show()
        end
    else
        frameData.castText:Show();
        frameData.castTextCompact:Hide();
        if frameData.castTimeText then
            frameData.castTimeText:Show()
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:Hide()
        end
    end
end

-- Función unificada para establecer modo de texto
local function SetTextMode(castbarType, mode)
    local frameData = frames[castbarType];
    if not frameData then
        return
    end

    if mode == "simple" then
        -- Mostrar solo nombre de hechizo centrado
        if frameData.castText then
            frameData.castText:Hide()
        end
        if frameData.castTextCompact then
            frameData.castTextCompact:Hide()
        end
        if frameData.castTimeText then
            frameData.castTimeText:Hide()
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:Hide()
        end
        if frameData.castTextCentered then
            frameData.castTextCentered:Show()
        end
    else
        -- Mostrar modo detallado (nombre + tiempo)
        if frameData.castTextCentered then
            frameData.castTextCentered:Hide()
        end

        local cfg = addon.db and addon.db.profile and addon.db.profile.castbar;
        if castbarType ~= "player" then
            cfg = cfg and cfg[castbarType];
        end
        local compactLayout = cfg and cfg.compactLayout;

        if compactLayout then
            if frameData.castText then
                frameData.castText:Hide()
            end
            if frameData.castTextCompact then
                frameData.castTextCompact:Show()
            end
            if frameData.castTimeText then
                frameData.castTimeText:Hide()
            end
            if frameData.castTimeTextCompact then
                frameData.castTimeTextCompact:Show()
            end
        else
            if frameData.castText then
                frameData.castText:Show()
            end
            if frameData.castTextCompact then
                frameData.castTextCompact:Hide()
            end
            if frameData.castTimeText then
                frameData.castTimeText:Show()
            end
            if frameData.castTimeTextCompact then
                frameData.castTimeTextCompact:Hide()
            end
        end
    end
end

-- Función auxiliar para establecer texto del castbar
local function SetCastText(castbarType, text)
    if not addon.db or not addon.db.profile or not addon.db.profile.castbar then
        return
    end

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then
            return
        end
    end

    local textMode = cfg.text_mode or "simple";
    SetTextMode(castbarType, textMode);

    local frameData = frames[castbarType];
    if not frameData then
        return
    end

    if textMode == "simple" then
        if frameData.castTextCentered then
            frameData.castTextCentered:SetText(text);
        end
    else
        if frameData.castText then
            frameData.castText:SetText(text)
        end
        if frameData.castTextCompact then
            frameData.castTextCompact:SetText(text)
        end
    end
end

-- =================================================================
-- SISTEMA DE MANEJO DE BLIZZARD CASTBARS
-- =================================================================

-- Función unificada para ocultar castbars de Blizzard
local function HideBlizzardCastbar(castbarType)
    local blizzardFrames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    };

    local frame = blizzardFrames[castbarType];
    if not frame then
        return
    end

    if castbarType == "target" then
        -- Para target: no usar Hide() - necesitamos las actualizaciones para sincronización
        frame:SetAlpha(0);
        frame:ClearAllPoints();
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, -2000);
    else
        -- Para player y focus: ocultar completamente
        frame:Hide();
        frame:SetAlpha(0);
        if frame.SetScript then
            frame:SetScript("OnShow", function(self)
                self:Hide()
            end);
        end
    end
end

-- Función unificada para mostrar castbars de Blizzard
local function ShowBlizzardCastbar(castbarType)
    local blizzardFrames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    };

    local frame = blizzardFrames[castbarType];
    if not frame then
        return
    end

    frame:SetAlpha(1);
    if frame.SetScript then
        frame:SetScript("OnShow", nil);
    end
    if castbarType == "target" then
        -- Restaurar posición original del target castbar
        frame:ClearAllPoints();
        frame:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 25, -5);
    end
end

-- =================================================================
-- SISTEMA DE ACTUALIZACIÓN DE TIEMPOS UNIFICADO
-- =================================================================

-- Función unificada para actualizar texto de tiempo de cast
local function UpdateCastTimeText(castbarType)
    local frameData = frames[castbarType];
    local state = castbarStates[castbarType];

    -- CORREGIDO: Para player castbar, verificar timeValue y timeMax también
    if castbarType == "player" then
        if not frameData.timeValue and not frameData.timeMax then
            return
        end
    else
        if not frameData.castTimeText and not frameData.castTimeTextCompact then
            return
        end
    end

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then
            return
        end
    end

    local seconds = 0;
    local secondsMax = 0;

    -- ARREGLO PUSHBACK: Usar tiempo absoluto para el jugador, relativo para los demás
    if castbarType == "player" and state.spellStartTime > 0 and state.spellEndTime > 0 then
        local now = GetTime();
        secondsMax = state.spellEndTime - state.spellStartTime;
        seconds = math.max(0, state.spellEndTime - now);
    else
        -- Lógica original para target/focus
        secondsMax = state.maxValue or 0;
        if state.casting or state.isChanneling then
            if state.casting and not state.isChanneling then
                -- Para casts regulares, mostrar tiempo restante
                seconds = math.max(0, state.maxValue - state.currentValue);
            else
                -- Para channels, mostrar currentValue como tiempo restante
                seconds = math.max(0, state.currentValue);
            end
        end
    end

    -- Formatear texto de tiempo
    local timeText = string.format('%.' .. (cfg.precision_time or 1) .. 'f', seconds);
    local fullText;

    if cfg.precision_max and cfg.precision_max > 0 then
        -- Formato con tiempo máximo: "2.5 / 8.0"
        local maxText = string.format('%.' .. cfg.precision_max .. 'f', secondsMax);
        fullText = timeText .. ' / ' .. maxText;
    else
        -- Formato simple: "2.5s"
        fullText = timeText .. 's';
    end

    -- CORREGIDO: Manejar player castbar diferente (usa timeValue/timeMax separados)
    if castbarType == "player" then
        -- Solo mostrar tiempos si NO estamos en modo simple
        local textMode = cfg.text_mode or "simple";
        if textMode ~= "simple" and frameData.timeValue and frameData.timeMax then
            frameData.timeValue:SetText(timeText);
            frameData.timeMax:SetText(' / ' .. string.format('%.' .. (cfg.precision_max or 1) .. 'f', secondsMax));
        end
    else
        -- Para target y focus, usar castTimeText
        if frameData.castTimeText then
            frameData.castTimeText:SetText(fullText)
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:SetText(fullText)
        end
    end
end

-- =================================================================
-- SISTEMA DE SINCRONIZACIÓN CON BLIZZARD
-- =================================================================

-- Función unificada para sincronizar con castbars de Blizzard
local function SyncWithBlizzardCastbar(castbarType, ourFrame)
    local blizzardFrames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar
    };

    local blizzardFrame = blizzardFrames[castbarType];
    local state = castbarStates[castbarType];

    if not blizzardFrame or not ourFrame or not state then
        return false
    end

    -- Verificar si el frame de Blizzard está visible/activo
    if not blizzardFrame:IsVisible() and castbarType ~= "target" then
        return false
    end

    -- Copiar valores correctos de Blizzard
    local blizzMin, blizzMax = blizzardFrame:GetMinMaxValues();
    local blizzValue = blizzardFrame:GetValue();

    if blizzMax > 0 and blizzMax ~= 1 then -- 1 es valor por defecto inválido
        -- Usar valores perfectos de Blizzard
        state.maxValue = blizzMax;
        state.currentValue = blizzValue;

        ourFrame:SetMinMaxValues(0, state.maxValue);
        ourFrame:SetValue(state.currentValue);

        -- Aplicar mejoras visuales
        local progress = state.currentValue / state.maxValue;
        if ourFrame.UpdateTextureClipping then
            ourFrame:UpdateTextureClipping(progress);
        end
        UpdateCastTimeText(castbarType);

        return true;
    end
    return false;
end

-- =================================================================
-- FUNCIÓN DE FINALIZACIÓN UNIFICADA
-- =================================================================

-- Función unificada para finalizar spells
local function FinishSpell(castbarType)
    local frameData = frames[castbarType];
    local state = castbarStates[castbarType];
    local cfg = addon.db.profile.castbar;

    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then
            return
        end
    end

    -- Establecer valor final
    if state.maxValue then
        if castbarType == "player" then
            frameData.castbar:SetValue(state.spellEndTime);
        else
            frameData.castbar:SetValue(state.maxValue);
            state.currentValue = state.maxValue;
        end
        -- CORREGIDO: Asegurar que la textura se muestre completamente al finalizar
        if frameData.castbar.UpdateTextureClipping then
            frameData.castbar:UpdateTextureClipping(1.0, state.isChanneling);
        end
        UpdateCastTimeText(castbarType);
    end

    -- Ocultar spark y mostrar flash
    if frameData.spark then
        frameData.spark:Hide()
    end
    if frameData.shield then
        frameData.shield:Hide()
    end

    -- Ocultar todos los ticks
    if frameData.ticks then
        for i = 1, #frameData.ticks do
            if frameData.ticks[i] then
                frameData.ticks[i]:Hide()
            end
        end
    end

    -- Mostrar flash de completado
    if frameData.flash then
        frameData.flash:Show()
    end

    -- Resetear estado de casting
    state.casting = false;
    state.isChanneling = false;
    if castbarType == "player" then
        state.spellStartTime = 0;
        state.spellEndTime = 0;
    end

    -- Establecer tiempo de hold
    state.holdTime = cfg.holdTime or 0.3;
end

-- =================================================================
-- FUNCIONES UPDATE UNIFICADAS
-- =================================================================


-- Función unificada para manejar parada/interrupción de cast
local function HandleCastStop(castbarType, event, isInterrupted)
    local state = castbarStates[castbarType];
    local frameData = frames[castbarType];
    local cfg = addon.db.profile.castbar;

    if castbarType ~= "player" then
        cfg = cfg[castbarType];
    end

    if not state.casting and not state.isChanneling then
        return
    end

    -- Calcular porcentaje de completado
    local completionPercentage = 0;
    if castbarType == "player" then
        if state.spellEndTime > state.spellStartTime then
            completionPercentage = (GetTime() - state.spellStartTime) / (state.spellEndTime - state.spellStartTime);
        end
    else
        if state.maxValue and state.maxValue > 0 then
            if state.isChanneling then
                completionPercentage = (state.maxValue - state.currentValue) / state.maxValue;
            else
                completionPercentage = state.currentValue / state.maxValue;
            end
        end
    end


    -- Manejar según el tipo de evento y completado
    if isInterrupted then
        -- Interrupción real - mostrar estado interrumpido
        if frameData.shield then
            frameData.shield:Hide()
        end
        HideAllChannelTicks(frameData.ticks, 15);

        frameData.castbar:SetStatusBarTexture(TEXTURES.interrupted);
        frameData.castbar:SetStatusBarColor(1, 0, 0, 1);
        ForceStatusBarTextureLayer(frameData.castbar);

        -- CORREGIDO: Para interrupciones, usar el sistema de clipping como las otras barras
        if castbarType == "player" then
             frameData.castbar:SetValue(state.spellEndTime);
        else
            frameData.castbar:SetValue(state.maxValue); -- Llenar completamente la barra
        end

        -- Usar UpdateTextureClipping para mantener capas consistentes
        if frameData.castbar.UpdateTextureClipping then
            frameData.castbar:UpdateTextureClipping(1.0, false); -- Mostrar completo sin recorte
        end

        SetCastText(castbarType, "Interrupted");

        state.casting = false;
        state.isChanneling = false;
        state.holdTime = cfg.holdTimeInterrupt or 0.8;
    elseif completionPercentage >= (state.isChanneling and 0.9 or 0.95) then
        -- Completado exitosamente
        if castbarType == "player" then
            state.castSucceeded = true; -- Activar período de gracia
        else
            FinishSpell(castbarType);
        end
    else
        -- Cancelación manual (movimiento, Esc, etc.) o cambio de hechizo.
        -- Tratar como una interrupción para mostrar la barra roja.
        HandleCastStop(castbarType, event, true);
    end
end

-- Función de actualización principal unificada
local function UpdateCastbar(castbarType, self, elapsed)
    local state = castbarStates[castbarType];
    local frameData = frames[castbarType];
    local cfg = addon.db.profile.castbar;

    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg or not cfg.enabled then
            return
        end

        -- FIXED: Check if target/focus still exists - if not, immediately hide castbar
        local unit = castbarType;
        if not UnitExists(unit) then
            if state.casting or state.isChanneling then
                -- Target/focus died or disappeared during casting - hide castbar immediately
                self:Hide();
                if frameData.background then
                    frameData.background:Hide()
                end
                if frameData.textBackground then
                    frameData.textBackground:Hide()
                end
                if frameData.flash then
                    frameData.flash:Hide()
                end
                if frameData.spark then
                    frameData.spark:Hide()
                end
                if frameData.shield then
                    frameData.shield:Hide()
                end
                if frameData.icon then
                    frameData.icon:Hide()
                end

                -- Reset state
                state.casting = false;
                state.isChanneling = false;
                state.holdTime = 0;
                state.maxValue = 0;
                state.currentValue = 0;
            end
            return;
        end
    elseif not cfg or not cfg.enabled then
        return;
    else
        -- FIXED: For player castbar, check if target exists when casting target spells
        if (state.casting or state.isChanneling) and state.currentSpellName then
            -- Common target spells that should be interrupted if target dies
            local targetSpells = {
                ["Fireball"] = true,
                ["Frostbolt"] = true,
                ["Shadow Bolt"] = true,
                ["Lightning Bolt"] = true,
                ["Heal"] = true,
                ["Greater Heal"] = true,
                ["Flash Heal"] = true,
                ["Smite"] = true,
                ["Mind Blast"] = true,
                ["Aimed Shot"] = true,
                ["Steady Shot"] = true,
                ["Hunter's Mark"] = true,
                ["Polymorph"] = true,
                ["Banish"] = true,
                ["Fear"] = true,
                ["Curse of Agony"] = true,
                ["Immolate"] = true,
                ["Corruption"] = true
            };

            -- If casting a target spell and target doesn't exist, cancel the cast
            if targetSpells[state.currentSpellName] and not UnitExists("target") then
                -- Target died during player casting - hide castbar immediately
                self:Hide();
                if frameData.background then
                    frameData.background:Hide()
                end
                if frameData.textBackground then
                    frameData.textBackground:Hide()
                end
                if frameData.flash then
                    frameData.flash:Hide()
                end
                if frameData.spark then
                    frameData.spark:Hide()
                end
                if frameData.shield then
                    frameData.shield:Hide()
                end
                if frameData.icon then
                    frameData.icon:Hide()
                end

                -- Reset state
                state.casting = false;
                state.isChanneling = false;
                state.holdTime = 0;
                state.maxValue = 0;
                state.currentValue = 0;
                state.castSucceeded = false;
                state.graceTime = 0;
                return;
            end
        end
    end

    -- Manejar período de gracia para casts exitosos (solo player)
    if castbarType == "player" and state.castSucceeded and (state.casting or state.isChanneling) then
        -- Forzar barra al 100% para feedback visual
        if state.isChanneling then
            state.currentValue = 0;
        else
            state.currentValue = state.maxValue;
        end

        self:SetValue(state.spellEndTime);
        if self.UpdateTextureClipping then
            self:UpdateTextureClipping(1.0, state.isChanneling);
        end
        UpdateCastTimeText(castbarType);

        -- Actualizar spark a posición final
        if frameData.spark and frameData.spark:IsShown() then
            frameData.spark:SetPoint('CENTER', self, 'LEFT', self:GetWidth(), 0);
        end

        -- Contar período de gracia
        state.graceTime = state.graceTime + elapsed;
        if state.graceTime >= GRACE_PERIOD_AFTER_SUCCESS then
            FinishSpell(castbarType);
            state.castSucceeded = false;
            state.graceTime = 0;
        end
        return;
    end

    -- Manejar tiempo de hold (barra permanece visible después de que termine el cast)
    if state.holdTime > 0 then
        state.holdTime = state.holdTime - elapsed;
        if state.holdTime <= 0 then
            -- Ocultar todo
            self:Hide();
            if frameData.background then
                frameData.background:Hide()
            end
            if frameData.textBackground then
                frameData.textBackground:Hide()
            end
            if frameData.flash then
                frameData.flash:Hide()
            end
            if frameData.spark then
                frameData.spark:Hide()
            end
            if frameData.shield then
                frameData.shield:Hide()
            end

            -- Resetear estados
            state.casting = false;
            state.isChanneling = false;
            if castbarType == "player" then
                state.castSucceeded = false;
                state.graceTime = 0;
            end
        end
        return;
    end

    -- Usar valores perfectos de Blizzard para casts y channels
    if state.casting or state.isChanneling then
        -- FIXED: Detect silent interruptions (e.g., from CC or other game mechanics)
        local unit = castbarType == "player" and "player" or castbarType;
        local isStillCasting = UnitCastingInfo(unit);
        local isStillChanneling = UnitChannelInfo(unit);

        if not isStillCasting and not isStillChanneling then
            -- The game says we are not casting/channeling, but our addon thinks we are.
            -- This is a silent interruption.
            if HandleCastStop then
                HandleCastStop(castbarType, 'UNIT_SPELLCAST_INTERRUPTED', true);
            else
                -- Fallback: hide castbar immediately
                self:Hide();
                state.casting = false;
                state.isChanneling = false;
                state.holdTime = 0;
            end
            return; -- Stop further processing for this frame
        end
        -- No sincronizar con Blizzard durante período de gracia
        local shouldSync = true;
        if castbarType == "player" and state.castSucceeded then
            shouldSync = false;
        end

        if shouldSync then
            local syncSucceeded = false;
            if castbarType ~= "player" then
                syncSucceeded = SyncWithBlizzardCastbar(castbarType, self);
            end

            -- ARREGLO PUSHBACK: La barra del jugador ahora usa un modelo de tiempo absoluto de alta precisión.
            if castbarType == "player" then
                if state.spellStartTime > 0 and state.spellEndTime > 0 then
                    local now = GetTime();
                    self:SetValue(math.min(now, state.spellEndTime));

                    local totalDuration = state.spellEndTime - state.spellStartTime;
                    local progress = 0;
                    if totalDuration > 0 then
                        progress = (now - state.spellStartTime) / totalDuration;
                    end
                    progress = math.max(0, math.min(1, progress));

                    if self.UpdateTextureClipping then
                        self:UpdateTextureClipping(progress, state.isChanneling);
                    end
                    UpdateCastTimeText(castbarType);
                end
            elseif not syncSucceeded then
                -- Fallback a cálculo manual para target/focus
                if state.casting and not state.isChanneling then
                    state.currentValue = state.currentValue + elapsed;
                    if state.currentValue >= state.maxValue then
                        state.currentValue = state.maxValue;
                    end
                elseif state.isChanneling then
                    state.currentValue = state.currentValue - elapsed;
                    if state.currentValue <= 0 then
                        state.currentValue = 0;
                    end
                end

                -- Aplicar valores manuales
                self:SetValue(state.currentValue);
                local progress;
                if state.isChanneling then
                    progress = state.currentValue / state.maxValue;
                else
                    progress = state.currentValue / state.maxValue;
                end
                if self.UpdateTextureClipping then
                    self:UpdateTextureClipping(progress, state.isChanneling);
                end
                UpdateCastTimeText(castbarType);
            end
        end

        -- Actualizar posición del spark
        if (state.casting or state.isChanneling) and frameData.spark and frameData.spark:IsShown() then
            local progress = 0;
            if castbarType == "player" then
                if state.spellEndTime > state.spellStartTime then
                    progress = (GetTime() - state.spellStartTime) / (state.spellEndTime - state.spellStartTime);
                end
            else
                if state.maxValue > 0 then
                    progress = state.currentValue / state.maxValue;
                end
            end
            progress = math.max(0, math.min(1, progress));

            local actualWidth = self:GetWidth() * progress;
            frameData.spark:ClearAllPoints();
            frameData.spark:SetPoint('CENTER', self, 'LEFT', actualWidth, 0);
        end

        -- Ocultar flash durante casting/channeling
        if frameData.flash then
            frameData.flash:Hide()
        end
    end
end


-- Crear funciones de OnUpdate específicas para cada tipo
local function CreateUpdateFunction(castbarType)
    return function(self, elapsed)
        UpdateCastbar(castbarType, self, elapsed);
    end
end

-- =================================================================
-- SISTEMA DE MANEJO DE EVENTOS UNIFICADO
-- =================================================================

-- Función para manejar eventos de UNIT_AURA
local function HandleUnitAura(unit)
    if unit == 'target' then
        local cfg = addon.db.profile.castbar.target;
        if cfg and cfg.enabled and cfg.autoAdjust then
            -- Pequeño delay para evitar actualizaciones excesivas durante cambios rápidos de aura
            addon.core:ScheduleTimer(function()
                ApplySimplifiedAuraOffsetToTargetCastbar();
            end, 0.05);
        end
    end
end

-- =================================================================
-- SISTEMA DE MANEJO DE EVENTOS DE CASTING UNIFICADO (DECLARADO TEMPRANO)
-- =================================================================

-- Función unificada para manejar inicio de cast
local function HandleCastStart(castbarType, unit)
    local name, subText, text, iconTex, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(
        unit);
    if not name then
        return
    end

    RefreshCastbar(castbarType)

    local state = castbarStates[castbarType];
    local frameData = frames[castbarType];

    state.casting = true;
    state.isChanneling = false;
    state.holdTime = 0;
    state.currentSpellName = name;

    -- Reset estado de éxito (solo player)
    if castbarType == "player" then
        state.castSucceeded = false;
        state.graceTime = 0;
    end

    -- Parsing de tiempo unificado
    local startTimeSeconds, endTimeSeconds, spellDuration = ParseCastTimes(startTime, endTime);

    -- Ajuste para formatos de tiempo poco razonables
    if spellDuration > 3600 or spellDuration < 0 then
        spellDuration = endTime - startTime;
        if spellDuration > 3600 or spellDuration < 0 then
            spellDuration = 3.0; -- fallback por defecto
        end
    end

    -- ARREGLO PUSHBACK: Almacenar tiempos absolutos para todas las barras para consistencia
    state.spellStartTime = startTimeSeconds;
    state.spellEndTime = endTimeSeconds;

    if castbarType == "player" then
        -- Usar modelo de tiempo absoluto para el jugador
        frameData.castbar:SetMinMaxValues(startTimeSeconds, endTimeSeconds);
        frameData.castbar:SetValue(GetTime());
    else
        -- Usar modelo de tiempo relativo para target/focus
        state.currentValue = 0;
        state.maxValue = spellDuration;
        frameData.castbar:SetMinMaxValues(0, state.maxValue);
        frameData.castbar:SetValue(state.currentValue);
    end

    -- Mostrar castbar
    frameData.castbar:Show();
    if frameData.background and frameData.background ~= frameData.textBackground then
        frameData.background:Show();
    end
    frameData.spark:Show();

    frameData.flash:Hide();

    -- Ocultar ticks de canal de hechizos anteriores
    HideAllChannelTicks(frameData.ticks, 15);

    -- Configurar texturas y colores
    frameData.castbar:SetStatusBarTexture(TEXTURES.standard);
    frameData.castbar:SetStatusBarColor(1, 0.7, 0, 1);
    ForceStatusBarTextureLayer(frameData.castbar);

    -- CORREGIDO: Llamar UpdateTextureClipping ahora que está arreglado para WoW 3.3.5a
    frameData.castbar:UpdateTextureClipping(0.0, false); -- Casting normal, empezar vacío

    -- Configurar texto e icono
    SetCastText(castbarType, name);

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
    end

    if frameData.icon and cfg.showIcon then
        frameData.icon:SetTexture(nil); -- Limpiar textura primero
        local improvedIcon = GetSpellIconImproved(name, iconTex, castID);
        frameData.icon:SetTexture(improvedIcon);
        SetIconVisibility(castbarType, true);
    else
        SetIconVisibility(castbarType, false);
    end

    -- CORREGIDO: Mostrar frame de texto para player también
    if frameData.textBackground then
        frameData.textBackground:Show();
        frameData.textBackground:ClearAllPoints();
        frameData.textBackground:SetSize(frameData.castbar:GetWidth(), castbarType == "player" and 22 or 20);
        frameData.textBackground:SetPoint("TOP", frameData.castbar, "BOTTOM", 0, castbarType == "player" and 6 or 8);
    end

    UpdateCastTimeText(castbarType);

    -- Manejar escudo para hechizos no interrumpibles (solo target y focus)
    if castbarType ~= "player" and frameData.shield and cfg.showIcon then
        -- Ocultar escudo para crafting incluso si notInterruptible
        if notInterruptible == true and not (isTradeSkill == true or isTradeSkill == 1) then
            frameData.shield:Show();
        else
            frameData.shield:Hide();
        end
    end
end

-- Función unificada para manejar inicio de channel
local function HandleChannelStart(castbarType, unit)
    local name, subText, text, iconTex, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unit);
    if not name then
        return
    end

    RefreshCastbar(castbarType)

    local state = castbarStates[castbarType];
    local frameData = frames[castbarType];

    state.casting = true;
    state.isChanneling = true;
    state.holdTime = 0;
    state.currentSpellName = name;

    -- Reset estado de éxito (solo player)
    if castbarType == "player" then
        state.castSucceeded = false;
        state.graceTime = 0;
    end

    -- CORREGIDO: Usar parsing correcto para channeling como el original
    local startTimeSeconds, endTimeSeconds, spellDuration = ParseCastTimes(startTime, endTime);

    -- ARREGLO PUSHBACK: Almacenar tiempos absolutos para todas las barras
    state.spellStartTime = startTimeSeconds;
    state.spellEndTime = endTimeSeconds;

    if castbarType == "player" then
        -- Usar modelo de tiempo absoluto para el jugador
        frameData.castbar:SetMinMaxValues(startTimeSeconds, endTimeSeconds);
        frameData.castbar:SetValue(GetTime());
    else
        -- CRITICAL FIX: Para channeling empezar desde max y contar hacia abajo
        state.maxValue = spellDuration;
        state.currentValue = spellDuration; -- Empezar desde el máximo para channeling
        frameData.castbar:SetMinMaxValues(0, state.maxValue);
        frameData.castbar:SetValue(state.currentValue);
    end


    -- Mostrar castbar
    frameData.castbar:Show();
    if frameData.background and frameData.background ~= frameData.textBackground then
        frameData.background:Show();
    end
    frameData.spark:Show();
    frameData.flash:Hide();

    -- Configurar texturas y colores para channeling
    frameData.castbar:SetStatusBarTexture(TEXTURES.channel);
    ForceStatusBarTextureLayer(frameData.castbar);

    -- CORREGIDO: Color correcto para player channeling
    if castbarType == "player" then
        frameData.castbar:SetStatusBarColor(0, 1, 0, 1); -- Verde para player
    else
        frameData.castbar:SetStatusBarColor(1, 1, 1, 1); -- Blanco para target/focus
    end
    -- CORREGIDO: Llamar UpdateTextureClipping ahora que está arreglado para WoW 3.3.5a
    frameData.castbar:UpdateTextureClipping(1.0, true); -- Channeling, empezar lleno

    -- Configurar texto e icono
    SetCastText(castbarType, name);

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
    end

    if frameData.icon and cfg.showIcon then
        frameData.icon:SetTexture(nil);
        local _, _, _, texture = UnitChannelInfo(unit);
        local improvedIcon = GetSpellIconImproved(name, texture, nil);
        frameData.icon:SetTexture(improvedIcon);
        SetIconVisibility(castbarType, true);
    else
        SetIconVisibility(castbarType, false);
    end

    -- CORREGIDO: Mostrar frame de texto para player también
    if frameData.textBackground then
        frameData.textBackground:Show();
        frameData.textBackground:ClearAllPoints();
        frameData.textBackground:SetSize(frameData.castbar:GetWidth(), castbarType == "player" and 22 or 20);
        frameData.textBackground:SetPoint("TOP", frameData.castbar, "BOTTOM", 0, castbarType == "player" and 6 or 8);
    end

    UpdateCastTimeText(castbarType);

    -- Mostrar ticks de canal si están disponibles
    UpdateChannelTicks(frameData.castbar, frameData.ticks, name, 15);

    -- Manejar escudo para channels no interrumpibles
    if castbarType ~= "player" and frameData.shield and cfg.showIcon then
        if notInterruptible == true and not (isTradeSkill == true or isTradeSkill == 1) then
            frameData.shield:Show();
        else
            frameData.shield:Hide();
        end
    end
end


-- Función principal unificada para manejar eventos de casting
local function HandleCastingEvents(castbarType, event, unit, ...)
    local unitToCheck = castbarType == "player" and "player" or castbarType;
    if unit ~= unitToCheck then
        return
    end

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg or not cfg.enabled then
            return
        end
    elseif not cfg or not cfg.enabled then
        return;
    end

    -- Forzar ocultar castbar de Blizzard en cualquier evento de casting
    HideBlizzardCastbar(castbarType);

    if event == 'UNIT_SPELLCAST_START' then
        HandleCastStart(castbarType, unitToCheck);
    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
        -- Solo para player - marcar cast como exitoso
        if castbarType == "player" then
            local state = castbarStates[castbarType];
            if state.casting or state.isChanneling then
                state.castSucceeded = true;
            end
        end
    elseif event == 'UNIT_SPELLCAST_CHANNEL_START' then
        HandleChannelStart(castbarType, unitToCheck);
    elseif event == 'UNIT_SPELLCAST_STOP' then
        HandleCastStop(castbarType, event, false);
    elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
        -- Para channels, verificar si fue interrumpido
        local state = castbarStates[castbarType];
        local isInterrupted = false;

        if state.isChanneling then
            local completionPercentage = 0;
            if castbarType == "player" then
                if state.spellEndTime > state.spellStartTime then
                     completionPercentage = (GetTime() - state.spellStartTime) / (state.spellEndTime - state.spellStartTime);
                end
            elseif state.maxValue > 0 then
                completionPercentage = (state.maxValue - state.currentValue) / state.maxValue;
            end
            isInterrupted = completionPercentage < 0.9;
        end

        HandleCastStop(castbarType, event, isInterrupted);
    elseif event == 'UNIT_SPELLCAST_FAILED' then
        -- Ignorar completamente eventos FAILED - solo ruido de cola
    elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
        HandleCastStop(castbarType, event, true);
    end
end

-- Función para manejar cambios de target
local function HandleTargetChanged()
    -- Ocultar inmediatamente castbar de Blizzard target
    HideBlizzardCastbar("target");

    -- Reset completo del estado del castbar target
    local frameData = frames.target;
    local state = castbarStates.target;

    if frameData.castbar then
        frameData.castbar:Hide();
        if frameData.background then
            frameData.background:Hide()
        end
        if frameData.textBackground then
            frameData.textBackground:Hide()
        end

        state.casting = false;
        state.isChanneling = false;
        state.holdTime = 0;
        state.maxValue = 0;
        state.currentValue = 0;

        -- Limpiar elementos visuales
        if frameData.icon then
            frameData.icon:Hide()
        end
        if frameData.castTimeText then
            frameData.castTimeText:SetText("")
        end
        if frameData.castTimeTextCompact then
            frameData.castTimeTextCompact:SetText("")
        end
        if frameData.spark then
            frameData.spark:Hide()
        end
        if frameData.shield then
            frameData.shield:Hide()
        end

        -- Ocultar todos los ticks
        if frameData.ticks then
            for i = 1, #frameData.ticks do
                frameData.ticks[i]:Hide();
            end
        end
    end

    -- Limpiar caché de auras del target cuando cambia
    auraCache.target.lastUpdate = 0;
    auraCache.target.lastCount = 0;
    auraCache.target.lastOffset = 0;
    auraCache.target.lastTargetGUID = nil;

    -- Verificar si el nuevo target ya está casteando
    if UnitExists("target") and addon.db.profile.castbar.target.enabled then
        addon.core:ScheduleTimer(function()
            local castName = UnitCastingInfo("target");
            local channelName = UnitChannelInfo("target");

            if castName then
                HandleCastingEvents("target", 'UNIT_SPELLCAST_START', "target");
            elseif channelName then
                HandleCastingEvents("target", 'UNIT_SPELLCAST_CHANNEL_START', "target");
            end

            -- Aplicar offset de auras simplificado para nuevo target
            ApplySimplifiedAuraOffsetToTargetCastbar();
        end, 0.05);
    end
end

-- Función para manejar cambios de focus
local function HandleFocusChanged()
    -- Ocultar inmediatamente castbar de Blizzard focus
    HideBlizzardCastbar("focus");

    -- Reset del estado del castbar focus
    local frameData = frames.focus;
    if frameData.castbar then
        FinishSpell("focus"); -- Usar función unificada
    end

    -- Aplicar posicionamiento del castbar focus después de pequeño delay
    if UnitExists("focus") and addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.enabled then
        addon.core:ScheduleTimer(function()
            local cfg = addon.db.profile.castbar.focus;
            local anchorFrame = _G[cfg.anchorFrame] or FocusFrame or UIParent;
            if frameData.castbar then
                frameData.castbar:ClearAllPoints();
                frameData.castbar:SetPoint(cfg.anchor, anchorFrame, cfg.anchorParent, cfg.x_position, cfg.y_position);
            end
        end, 0.1);
    end
end

-- =================================================================
-- SISTEMA DE CREACIÓN DE CASTBARS UNIFICADO
-- =================================================================

-- Sistema de recorte dinámico  usando coordenadas UV
local function CreateTextureClippingSystem(statusBar)

    statusBar.UpdateTextureClipping = function(self, progress, isChanneling)
        local currentTexture = self:GetStatusBarTexture();
        if not currentTexture then
            return
        end

        -- Asegurar que la textura llene todo el frame
        currentTexture:ClearAllPoints();
        currentTexture:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0);
        currentTexture:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0);

        -- CRITICAL: Forzar que la StatusBar texture esté en la capa correcta
        -- En WoW 3.3.5a, algunas veces se reposiciona mal después de SetStatusBarTexture
        if currentTexture.SetDrawLayer then
            currentTexture:SetDrawLayer('BORDER', 0);
        end

        -- Aplicar recorte dinámico profesional usando coordenadas UV
        local clampedProgress = math.max(0.001, math.min(1, progress)); -- Evitar valores extremos

        if isChanneling then
            -- Para channeling: mostrar como barra que se vacía de derecha a izquierda
            -- progress va de 1.0 a 0.0, mostramos desde izquierda hasta esa posición
            currentTexture:SetTexCoord(0, clampedProgress, 0, 1);
        else
            -- Para casting: recorte de izquierda a derecha (empezar vacío, llenarse)
            currentTexture:SetTexCoord(0, clampedProgress, 0, 1);
        end
    end;
end

-- Función unificada para crear elementos de texto
local function CreateTextElements(parentFrame, castbarType, scale)
    local elements = {};
    local fontSize = castbarType == "player" and 'GameFontHighlight' or 'GameFontHighlightSmall';

    -- Texto principal (nombre del hechizo)
    elements.castText = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castText:SetPoint('BOTTOMLEFT', parentFrame, 'BOTTOMLEFT', castbarType == "player" and 8 or 6, 2);
    elements.castText:SetJustifyH("LEFT");
    elements.castText:SetWordWrap(false);

    -- Texto compacto (alternativa para espacios pequeños)
    elements.castTextCompact = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTextCompact:SetPoint('BOTTOMLEFT', parentFrame, 'BOTTOMLEFT', castbarType == "player" and 8 or 6, 2);
    elements.castTextCompact:SetJustifyH("LEFT");
    elements.castTextCompact:SetWordWrap(false);
    elements.castTextCompact:Hide();

    -- Texto de tiempo de cast
    elements.castTimeText = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTimeText:SetPoint('BOTTOMRIGHT', parentFrame, 'BOTTOMRIGHT', castbarType == "player" and -8 or -6, 2);
    elements.castTimeText:SetJustifyH("RIGHT");

    -- Texto compacto de tiempo de cast
    elements.castTimeTextCompact = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTimeTextCompact:SetPoint('BOTTOMRIGHT', parentFrame, 'BOTTOMRIGHT',
        castbarType == "player" and -8 or -6, 2);
    elements.castTimeTextCompact:SetJustifyH("RIGHT");
    elements.castTimeTextCompact:Hide();

    -- Texto centrado para modo simple (solo nombre de hechizo)
    elements.castTextCentered = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
    elements.castTextCentered:SetPoint('BOTTOM', parentFrame, 'BOTTOM', 0, 1);
    elements.castTextCentered:SetPoint('LEFT', parentFrame, 'LEFT', castbarType == "player" and 8 or 6, 0);
    elements.castTextCentered:SetPoint('RIGHT', parentFrame, 'RIGHT', castbarType == "player" and -8 or -6, 0);
    elements.castTextCentered:SetJustifyH("CENTER");
    elements.castTextCentered:SetJustifyV("BOTTOM");
    elements.castTextCentered:Hide();

    -- Para player castbar, elementos separados adicionales
    if castbarType == "player" then
        elements.timeValue = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
        elements.timeValue:SetPoint('BOTTOMRIGHT', parentFrame, 'BOTTOMRIGHT', -50, 2);
        elements.timeValue:SetJustifyH("RIGHT");

        elements.timeMax = parentFrame:CreateFontString(nil, 'OVERLAY', fontSize);
        elements.timeMax:SetPoint('LEFT', elements.timeValue, 'RIGHT', 2, 0);
        elements.timeMax:SetJustifyH("LEFT");
    end

    return elements;
end

-- Función unificada para crear castbar
local function CreateCastbar(castbarType)
    if frames[castbarType].castbar then
        return
    end

    local frameName = 'DragonUI' .. castbarType:sub(1, 1):upper() .. castbarType:sub(2) .. 'Castbar';
    local frameData = frames[castbarType];

    -- Frame principal de StatusBar
    frameData.castbar = CreateFrame('StatusBar', frameName, UIParent);
    frameData.castbar:SetFrameStrata("MEDIUM");
    frameData.castbar:SetFrameLevel(10);
    frameData.castbar:SetMinMaxValues(0, 1);
    frameData.castbar:SetValue(0);
    frameData.castbar:Hide();

    -- PASO 1: FONDO (BACKGROUND layer) - UNA SOLA VEZ
    local bg = frameData.castbar:CreateTexture(nil, 'BACKGROUND');
    bg:SetTexture(TEXTURES.atlas);
    bg:SetTexCoord(unpack(UV_COORDS.background));
    bg:SetAllPoints();

    -- PASO 2: STATUSBAR TEXTURE (forzada en BORDER layer)
    frameData.castbar:SetStatusBarTexture(TEXTURES.standard);
    frameData.castbar:SetStatusBarColor(1, 0.7, 0, 1);
    ForceStatusBarTextureLayer(frameData.castbar);

    -- PASO 3: BORDE DEL CASTBAR (ARTWORK sublevel 0)
    local border = frameData.castbar:CreateTexture(nil, 'ARTWORK', nil, 0);
    border:SetTexture(TEXTURES.atlas);
    border:SetTexCoord(unpack(UV_COORDS.border));
    border:SetPoint("TOPLEFT", frameData.castbar, "TOPLEFT", -2, 2);
    border:SetPoint("BOTTOMRIGHT", frameData.castbar, "BOTTOMRIGHT", 2, -2);

    -- PASO 4: TICKS DE CHANNELING (ARTWORK sublevel 1)
    frameData.ticks = {};
    CreateChannelTicks(frameData.castbar, frameData.ticks, 15);

    -- PASO 5: SPARK - SE CREARÁ DESPUÉS EN RefreshCastbar() cuando el frame esté posicionado
    frameData.spark = nil; -- Placeholder

    -- PASO 6: FLASH DE COMPLETADO (OVERLAY layer)
    frameData.flash = frameData.castbar:CreateTexture(nil, 'OVERLAY');
    frameData.flash:SetTexture(TEXTURES.atlas);
    frameData.flash:SetTexCoord(unpack(UV_COORDS.flash));
    frameData.flash:SetBlendMode('ADD');
    frameData.flash:SetAllPoints();
    frameData.flash:Hide();

    -- PASO 7: ICONO Y BORDE DEL ICONO (ARTWORK layer)
    frameData.icon = frameData.castbar:CreateTexture(frameName .. "Icon", 'ARTWORK');
    frameData.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);
    frameData.icon:Hide();

    local iconBorder = frameData.castbar:CreateTexture(nil, 'ARTWORK');
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2");
    iconBorder:SetTexCoord(0.05, 0.95, 0.05, 0.95);
    iconBorder:SetVertexColor(0.8, 0.8, 0.8, 1);
    iconBorder:Hide();
    frameData.icon.Border = iconBorder;

    -- PASO 8: ESCUDO (solo target y focus)
    if castbarType ~= "player" then
        frameData.shield = CreateSimplifiedShield(frameData.castbar, frameData.icon, frameName,
            SHIELD_CONFIG.baseIconSize);
    else
        frameData.shield = frameData.castbar:CreateTexture(nil, 'OVERLAY');
        frameData.shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Arena-Shield");
        frameData.shield:SetSize(16, 16);
        frameData.shield:Hide();
    end

    -- Aplicar sistemas
    ApplyVertexColor(frameData.castbar);
    CreateTextureClippingSystem(frameData.castbar);

    -- Frame de fondo de texto
    local textBgName = frameName .. 'TextBG';
    frameData.textBackground = CreateFrame('Frame', textBgName, UIParent);
    frameData.textBackground:SetFrameStrata("MEDIUM");
    frameData.textBackground:SetFrameLevel(9);
    frameData.textBackground:Hide();

    local textBg = frameData.textBackground:CreateTexture(nil, 'BACKGROUND');
    if castbarType == "player" then
        textBg:SetTexture(TEXTURES.atlas);
        textBg:SetTexCoord(0.001953125, 0.410109375, 0.00390625, 0.11328125);
    else
        textBg:SetTexture(TEXTURES.atlasSmall);
        textBg:SetTexCoord(unpack(UV_COORDS.textBorder));
    end
    textBg:SetAllPoints();

    -- Crear elementos de texto
    local textElements = CreateTextElements(frameData.textBackground, castbarType);
    for key, element in pairs(textElements) do
        frameData[key] = element;
    end

    -- Frame de fondo adicional
    if castbarType ~= "player" then
        frameData.background = CreateFrame('Frame', frameName .. 'Background', frameData.castbar);
        frameData.background:SetFrameLevel(frameData.castbar:GetFrameLevel() - 1);
        frameData.background:SetAllPoints(frameData.castbar);
    else
        frameData.background = frameData.textBackground;
    end

    -- Configurar OnUpdate handler
    frameData.castbar:SetScript('OnUpdate', CreateUpdateFunction(castbarType));

end

-- =================================================================
-- FUNCIONES DE REFRESH UNIFICADAS
-- =================================================================

-- Función unificada para refresh de castbars
RefreshCastbar = function(castbarType)
    -- CRITICAL: Protección contra refreshes muy frecuentes (causa problemas de capas)
    local currentTime = GetTime();
    local timeSinceLastRefresh = currentTime - (lastRefreshTime[castbarType] or 0);
    -- No permitir refreshes más frecuentes que cada 0.1 segundos (excepto primer refresh)
    if timeSinceLastRefresh < 0.1 and (lastRefreshTime[castbarType] or 0) > 0 then
        -- Descomentar para debug: print("[DragonUI Castbar] BLOCKED rapid refresh for " .. castbarType .. " (time since last: " .. string.format("%.3f", timeSinceLastRefresh) .. "s)");
        return;
    end

    lastRefreshTime[castbarType] = currentTime;

    local cfg = addon.db.profile.castbar;
    if castbarType ~= "player" then
        cfg = cfg[castbarType];
        if not cfg then
            return
        end
    end

    if not cfg then
        return
    end

    -- Manejar castbar de Blizzard primero
    if cfg.enabled then
        HideBlizzardCastbar(castbarType);
    else
        ShowBlizzardCastbar(castbarType);
        -- Ocultar nuestro castbar y salir
        local frameData = frames[castbarType];
        if frameData.castbar then
            frameData.castbar:Hide();
            if frameData.background then
                frameData.background:Hide()
            end
            if frameData.textBackground then
                frameData.textBackground:Hide()
            end
            local state = castbarStates[castbarType];
            state.casting = false;
            state.holdTime = 0;
        end
        return;
    end

    -- Crear castbar si no existe
    if not frames[castbarType].castbar then
        CreateCastbar(castbarType);
    end

    local frameData = frames[castbarType];
    local frameName = 'DragonUI' .. castbarType:sub(1, 1):upper() .. castbarType:sub(2) .. 'Castbar';
    -- Calcular offset de auras para target
    local auraOffset = 0;
    if castbarType == "target" and cfg.autoAdjust then
        auraOffset = GetTargetAuraOffsetSimplified();
    end

    -- Posicionar y dimensionar castbar principal
    frameData.castbar:ClearAllPoints();
    local anchorFrame = UIParent;
    local anchorPoint = "CENTER";
    local relativePoint = "BOTTOM";
    local xPos = cfg.x_position or 0;
    local yPos = cfg.y_position or 200;

    if castbarType ~= "player" then
        anchorFrame = _G[cfg.anchorFrame] or (castbarType == "target" and TargetFrame or FocusFrame) or UIParent;
        anchorPoint = cfg.anchor or "CENTER";
        relativePoint = cfg.anchorParent or "BOTTOM";
    end

    frameData.castbar:SetPoint(anchorPoint, anchorFrame, relativePoint, xPos, yPos - auraOffset);
    frameData.castbar:SetSize(cfg.sizeX or 200, cfg.sizeY or 16);
    frameData.castbar:SetScale(cfg.scale or 1);

    -- CRITICAL: Crear/configurar spark DESPUÉS de que el frame padre esté completamente configurado
    if not frameData.spark then
        -- Convertir el spark en un frame independiente para un control de capas superior
        frameData.spark = CreateFrame("Frame", frameName .. "Spark", UIParent);
        frameData.spark:SetFrameStrata("MEDIUM");
        frameData.spark:SetFrameLevel(11); -- Nivel superior al castbar (10)
        frameData.spark:SetSize(16, 16);
        frameData.spark:SetPoint('CENTER', frameData.castbar, 'LEFT', 0, 0);
        frameData.spark:Hide();

        local sparkTexture = frameData.spark:CreateTexture(nil, 'ARTWORK');
        sparkTexture:SetTexture(TEXTURES.spark);
        sparkTexture:SetAllPoints(frameData.spark);
        sparkTexture:SetBlendMode('ADD');
    end

    -- Posicionar frame de fondo de texto
    if frameData.textBackground then
        frameData.textBackground:ClearAllPoints();
        frameData.textBackground:SetPoint('TOP', frameData.castbar, 'BOTTOM', 0, castbarType == "player" and 6 or 8);
        frameData.textBackground:SetSize(cfg.sizeX or 200, castbarType == "player" and 22 or 20);
        frameData.textBackground:SetScale(cfg.scale or 1);
    end

    -- Posicionar frame de fondo adicional
    if frameData.background and frameData.background ~= frameData.textBackground then
        frameData.background:ClearAllPoints();
        frameData.background:SetAllPoints(frameData.castbar);
        frameData.background:SetScale(cfg.scale or 1);
    end

    -- Configurar icono
    if frameData.icon then
        local iconSize = cfg.sizeIcon or 20;
        frameData.icon:SetSize(iconSize, iconSize);
        frameData.icon:ClearAllPoints();

        if castbarType == "player" then
            -- Posicionar a la izquierda del castbar
            local offsetX = -(iconSize + 6);
            frameData.icon:SetPoint('TOPLEFT', frameData.castbar, 'TOPLEFT', offsetX, -1);
        else
            -- Posicionamiento exacto como ultimaversion
            local iconScale = iconSize / 16;
            frameData.icon:SetPoint('RIGHT', frameData.castbar, 'LEFT', -7 * iconScale, -4);
        end

        frameData.icon:SetAlpha(1);

        -- Actualizar tamaños proporcionales
        UpdateProportionalSizes(castbarType, iconSize);

        -- Configurar borde del icono
        if frameData.icon.Border then
            frameData.icon.Border:ClearAllPoints();
            frameData.icon.Border:SetPoint('CENTER', frameData.icon, 'CENTER', 0, 0);
            if cfg.showIcon then
                frameData.icon.Border:Show();
            else
                frameData.icon.Border:Hide();
            end
        end

        -- Configurar escudo (posicionado relativo al icono)
        if frameData.shield then
            if castbarType == "player" then
                frameData.shield:ClearAllPoints();
                frameData.shield:SetPoint('CENTER', frameData.icon, 'CENTER', 0, 0);
                frameData.shield:SetSize(iconSize * 0.8, iconSize * 0.8);
            else
                -- El escudo simplificado se posiciona automáticamente
            end
            frameData.shield:Hide();
        end

        -- Aplicar visibilidad del icono
        SetIconVisibility(castbarType, cfg.showIcon or false);
    end

    -- Actualizar tamaño del spark (proporcional a la altura del castbar)
    if frameData.spark then
        local sparkSize = cfg.sizeY or 16;
        frameData.spark:SetSize(sparkSize, sparkSize * 2);
        frameData.spark:ClearAllPoints();
        frameData.spark:SetPoint('CENTER', frameData.castbar, 'LEFT', 0, 0);
    end

    -- Actualizar tamaños de ticks
    if frameData.ticks then
        for i = 1, #frameData.ticks do
            frameData.ticks[i]:SetSize(3, (cfg.sizeY or 16) - 2);
        end
    end

    -- Configurar layout compacto para target y focus
    if castbarType ~= "player" then
        SetCompactLayout(castbarType, true);
    end

    -- Asegurar que los frames estén correctamente en capas
    frameData.castbar:SetFrameLevel(10);
    if frameData.background then
        frameData.background:SetFrameLevel(9)
    end
    if frameData.textBackground then
        frameData.textBackground:SetFrameLevel(9)
    end

    -- Forzar ocultar castbar de Blizzard nuevamente
    HideBlizzardCastbar(castbarType);

    -- Asegurar que el color de vértice se mantenga después del refresh
    ApplyVertexColor(frameData.castbar);

    -- Aplicar configuración de modo de texto
    if cfg.text_mode then
        SetTextMode(castbarType, cfg.text_mode);
    end

end

-- =================================================================
-- MANEJADOR PRINCIPAL DE EVENTOS
-- =================================================================

-- Función principal de manejo de eventos unificada
function OnCastbarEvent(self, event, unit, ...)
    -- Manejar evento UNIT_AURA para sistema mejorado de auto-adjust por auras
    if event == 'UNIT_AURA' then
        HandleUnitAura(unit);
        return;
    end

    -- Manejar PLAYER_FOCUS_CHANGED para castbar focus
    if event == 'PLAYER_FOCUS_CHANGED' then
        HandleFocusChanged();
        return;
    end

    -- Manejar PLAYER_TARGET_CHANGED para castbar target
    if event == 'PLAYER_TARGET_CHANGED' then
        HandleTargetChanged();
        return;
    end

    -- Manejar PLAYER_ENTERING_WORLD para inicialización
    if event == 'PLAYER_ENTERING_WORLD' then
        -- Ocultar inmediatamente castbars de Blizzard
        if addon.db.profile.castbar.enabled then
            HideBlizzardCastbar("player");
        end
        if addon.db.profile.castbar.target and addon.db.profile.castbar.target.enabled then
            HideBlizzardCastbar("target");
        end
        if addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.enabled then
            HideBlizzardCastbar("focus");
        end

        -- Pequeño delay para asegurar que todos los frames de Blizzard estén cargados
        addon.core:ScheduleTimer(function()
            RefreshCastbar("player");
            RefreshCastbar("target");
            RefreshCastbar("focus");

            -- Verificación extra para ocultar castbars de Blizzard después de que todo se cargue
            addon.core:ScheduleTimer(function()
                if addon.db.profile.castbar.enabled then
                    HideBlizzardCastbar("player");
                end
                if addon.db.profile.castbar.target and addon.db.profile.castbar.target.enabled then
                    HideBlizzardCastbar("target");
                end
                if addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.enabled then
                    HideBlizzardCastbar("focus");
                end
            end, 1.0);
        end, 0.5);
        return;
    end

    -- ARREGLO PUSHBACK: Manejar eventos de retraso para el jugador
    if (event == 'UNIT_SPELLCAST_DELAYED' or event == 'UNIT_SPELLCAST_CHANNEL_UPDATE') and unit == 'player' then
        local state = castbarStates.player
        local frameData = frames.player
        local name, _, _, _, startTime, endTime

        if event == 'UNIT_SPELLCAST_DELAYED' then
            name, _, _, _, startTime, endTime = UnitCastingInfo(unit)
        else
            name, _, _, _, startTime, endTime = UnitChannelInfo(unit)
        end
        
        if name and startTime and endTime then
            local startTimeSecs, endTimeSecs, _ = ParseCastTimes(startTime, endTime)
            state.spellStartTime = startTimeSecs
            state.spellEndTime = endTimeSecs
            if frameData.castbar then
                 frameData.castbar:SetMinMaxValues(startTimeSecs, endTimeSecs)
            end
        end
        return;
    end

    -- Determinar tipo de castbar basado en unit
    local castbarType;
    if unit == 'player' then
        castbarType = "player";
    elseif unit == 'target' then
        castbarType = "target";
    elseif unit == 'focus' then
        castbarType = "focus";
    else
        return; -- Unidad no soportada
    end

    -- Delegar a manejador de eventos de casting unificado
    HandleCastingEvents(castbarType, event, unit, ...);
end

-- =================================================================
-- FUNCIONES PÚBLICAS PARA EL ADDON
-- =================================================================

-- Función pública para refresh de castbar del player
function addon.RefreshCastbar()
    RefreshCastbar("player");
end

-- Función pública para refresh de castbar del target
function addon.RefreshTargetCastbar()
    RefreshCastbar("target");
end

-- Función pública para refresh de castbar del focus
function addon.RefreshFocusCastbar()
    RefreshCastbar("focus");
end

-- =================================================================
-- INICIALIZACIÓN DEL MÓDULO
-- =================================================================

-- Función de inicialización del módulo
local function InitializeCastbar()
    -- Crear frame de inicialización único para todos los eventos
    local initFrame = CreateFrame('Frame', 'DragonUICastbarEventHandler');

    -- Registrar todos los eventos necesarios en un solo lugar
    local allEvents = {'PLAYER_ENTERING_WORLD', 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED',
                       'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP',
                       'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_AURA', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED',
                       'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_UPDATE'}; -- ARREGLO PUSHBACK: Eventos nuevos añadidos

    for _, event in ipairs(allEvents) do
        initFrame:RegisterEvent(event);
    end

    -- Usar OnCastbarEvent como el manejador central para todo
    initFrame:SetScript('OnEvent', OnCastbarEvent);

    -- Hook ajuste de posición de auras nativo de WoW (como ultimaversion)
    if TargetFrameSpellBar then
        hooksecurefunc('Target_Spellbar_AdjustPosition', function(self)
            -- Aplicar offset de auras simplificado cuando WoW ajusta spellbar nativo del target
            if addon.db and addon.db.profile.castbar and addon.db.profile.castbar.target and
                addon.db.profile.castbar.target.autoAdjust then
                addon.core:ScheduleTimer(function()
                    ApplySimplifiedAuraOffsetToTargetCastbar();
                end, 0.05);
            end
        end);
    end

end

-- Iniciar inicialización
InitializeCastbar();
