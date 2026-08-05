-- ============================================================================
-- DragonUI - Minimap Decorations
-- ============================================================================
-- Preset attribution note:
-- Original preset work credited to the SexyMap author:
-- https://github.com/funkydude
-- https://www.curseforge.com/members/funkehdude

local addon = select(2, ...)
if not addon then return end

local _G = _G
local CreateFrame = CreateFrame
local Minimap = Minimap
local GetPlayerFacing = GetPlayerFacing
local pairs, ipairs, type, tonumber = pairs, ipairs, type, tonumber
local mathmax, sin, cos, rad = math.max, math.sin, math.cos, math.rad

local AUTO_SCALE_BORDER_VISIBLE = 0.9
local AUTO_SCALE_BORDER_HIDDEN = 1

-- Manual global X nudge for all decorative layers.
-- Applied only when DragonUI border is visible.
local DECORATIONS_GLOBAL_OFFSET_X = 2

-- Manual global Y nudge for all decorative layers.
-- Applied only when DragonUI border is visible.
local DECORATIONS_GLOBAL_OFFSET_Y = -3

local MinimapDecorationsModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    frames = {},
    textures = {},
    texturePool = {},
    rotatingTextures = {},
    currentPreset = nil,
    currentOpacity = nil,
}
addon.MinimapDecorations = MinimapDecorationsModule

if addon.RegisterModule then
    addon:RegisterModule("MinimapDecorations", MinimapDecorationsModule,
        addon.L["Minimap Decorations"],
        addon.L["Native animated minimap decoration effects for DragonUI."])
end

local PRESET_ORDER = {
    "drg_preset_01",
    "drg_preset_02",
    "drg_preset_03",
    "drg_preset_04",
    "drg_preset_05",
    "drg_preset_06",
    "drg_preset_07",
}

local PRESET_LABELS = {
    ["drg_preset_01"] = "Azure Halo",
    ["drg_preset_02"] = "Prismatic Facet",
    ["drg_preset_03"] = "Solar Ember",
    ["drg_preset_04"] = "Astral Lattice",
    ["drg_preset_05"] = "Crimson Orbit",
    ["drg_preset_06"] = "Verdant Bloom",
    ["drg_preset_07"] = "Elemental Crown",
}

local PRESET_AVAILABLE = {}
for i = 1, #PRESET_ORDER do
    PRESET_AVAILABLE[PRESET_ORDER[i]] = true
end

local PRESETS = {
    ["drg_preset_01"] = {
        borders = {
            { texture = "SPELLS\\AURARUNE256.BLP", scale = 1.4, rotSpeed = -16, r = 0.3098039215686275, g = 0.4784313725490196, b = 1, a = 1 },
            { texture = "SPELLS\\AuraRune_A.blp", scale = 2.1, rotSpeed = 4, r = 0.196078431372549, g = 0.2901960784313725, b = 1, a = 0.3799999952316284 },
            { texture = "SPELLS\\T_VFX_HERO_CIRCLE.BLP", scale = 1.6, r = 0, g = 0.2235294117647059, b = 1, a = 0.3 },
        },
    },
    ["drg_preset_02"] = {
        borders = {
            { texture = "SPELLS\\AuraRune256b.blp", scale = 1.62, rotation = 0, rotSpeed = 0, hNudge = -1, vNudge = 0, drawLayer = "BACKGROUND", r = 0, g = 0.3450980392156863, b = 1, a = 1 },
            { texture = "Interface\\GLUES\\MODELS\\UI_Tauren\\gradientCircle.blp", scale = 2.1, vNudge = 0, disableRotation = true, drawLayer = "ARTWORK", r = 0.3294117647058824, g = 0.5333333333333333, b = 1, a = 0.06999999284744263 },
        },
    },
    ["drg_preset_03"] = {
        borders = {
            { texture = "PARTICLES\\GENERICGLOW5.BLP", scale = 1.82, rotSpeed = 21, r = 1, g = 0.2901960784313725, b = 0.04313725490196078, a = 1 },
            { texture = "PARTICLES\\GENERICGLOW5.BLP", scale = 1.62, rotSpeed = -18, r = 1, g = 0.8705882352941177, b = 0.3529411764705882, a = 1 },
            { texture = "SPELLS\\T_VFX_HERO_CIRCLE.BLP", scale = 1.35, r = 1, g = 0.6705882352941176, b = 0.3254901960784314, a = 0.449999988079071 },
        },
    },
    ["drg_preset_04"] = {
        borders = {
            { texture = "SPELLS\\AURARUNE256.BLP", scale = 1.4, rotSpeed = -16, playerRotation = "normal", r = 0.5764705882352941, g = 0.6862745098039216, b = 1, a = 1 },
            { texture = "SPELLS\\AuraRune_A.blp", scale = 2.05, rotation = 105, rotSpeed = 0, playerRotation = "none", r = 0.2823529411764706, g = 0.6588235294117647, b = 1, a = 0.3799999952316284 },
            { texture = "SPELLS\\T_VFX_HERO_CIRCLE.BLP", scale = 1.6, r = 0, g = 0.2235294117647059, b = 1, a = 0.3 },
            { texture = "SPELLS\\AuraRune_B.blp", scale = 1.65, rotSpeed = -6, r = 0.1137254901960784, g = 0.1686274509803922, b = 0.3529411764705882, a = 1 },
        },
    },
    ["drg_preset_05"] = {
        borders = {
            { texture = "SPELLS\\RogueRune2.blp", scale = 2.13, rotSpeed = -8, r = 0.1450980392156863, g = 0.00392156862745098, b = 0, a = 1 },
            { texture = "SPELLS\\White-Circle.blp", scale = 0.89, disableRotation = true, blendMode = "ADD", r = 0.6, g = 0.2078431372549019, b = 0.09411764705882353, a = 1 },
        },
    },
    ["drg_preset_06"] = {
        borders = {
            { texture = "XTEXTURES\\splash\\splash.blp", scale = 1.17, rotSpeed = 8, hNudge = 2, vNudge = -1, blendMode = "ADD", r = 0, g = 0.4745098039215686, b = 0.01568627450980392, a = 1 },
            { texture = "Textures\\moonglare.blp", scale = 1.6, drawLayer = "BACKGROUND", blendMode = "ADD", r = 1, g = 0.9725490196078431, b = 0.3490196078431372, a = 1 },
            { texture = "Textures\\Moon02Glare.blp", scale = 1.07, blendMode = "ADD", r = 0.807843137254902, g = 1, b = 0.4431372549019608, a = 0.09000003337860107 },
            { texture = "SPELLS\\AURA_01.blp", scale = 1.22, rotation = 45, rotSpeed = 41, hNudge = 41, vNudge = 38, drawLayer = "OVERLAY", blendMode = "ADD", r = 0.1725490196078431, g = 0.8705882352941177, b = 1, a = 0.7199999988079071 },
            { texture = "SPELLS\\Nature_Rune_128.blp", scale = 0.84, rotSpeed = -8, hNudge = -57, vNudge = 32, blendMode = "ADD", r = 0, g = 0.4156862745098039, b = 0.05098039215686274, a = 0.2599999904632568 },
            { texture = "SPELLS\\Nature_Rune_128.blp", scale = 0.87, rotSpeed = 8, hNudge = 39, vNudge = -45, r = 0.4823529411764706, g = 0.4313725490196079, b = 0.1176470588235294, a = 0.1800000071525574 },
            { texture = "SPELLS\\Nature_Rune_128.blp", scale = 0.78, rotSpeed = -13, hNudge = 53, vNudge = 39, r = 0.2941176470588235, g = 1, b = 0.7764705882352941, a = 0.1200000047683716 },
            { texture = "SPELLS\\Nature_Rune_128.blp", scale = 0.85, rotSpeed = -6, hNudge = -48, vNudge = -45, r = 0.7607843137254902, g = 1, b = 0.4352941176470588, a = 0.09000003337860107 },
            { texture = "SPELLS\\Nature_Rune_128.blp", scale = 1.81, rotSpeed = -14, r = 0.09019607843137255, g = 0.3372549019607843, b = 0.07450980392156863, a = 0.14000004529953 },
            { texture = "SPELLS\\SHOCKWAVE_INVERTGREY.BLP", scale = 1.45, rotSpeed = -1, drawLayer = "BACKGROUND", blendMode = "BLEND", r = 0, g = 0.4666666666666667, b = 0.01568627450980392, a = 0.6599999964237213 },
            { texture = "SPELLS\\SHOCKWAVE_INVERTGREY.BLP", scale = 1.46, rotSpeed = 2, drawLayer = "BORDER", r = 0.02352941176470588, g = 0.3098039215686275, b = 0.06666666666666667, a = 0.5800000131130219 },
            { texture = "SPELLS\\TREANTLEAVES.BLP", scale = 1.58, rotation = 231, rotSpeed = 0, drawLayer = "BACKGROUND", blendMode = "BLEND", r = 1, g = 1, b = 1, a = 0.5 },
        },
    },
    ["drg_preset_07"] = {
        borders = {
            { texture = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\SHAMANSTONEEARTH.blp", scale = 0.4, hNudge = 65, vNudge = 65, disableRotation = true, r = 1, g = 1, b = 1, a = 1 },
            { texture = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\ShamanStoneAir.blp", scale = 0.35, hNudge = -65, vNudge = -65, disableRotation = true },
            { texture = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\ShamanStoneWater.blp", scale = 0.35, hNudge = 65, vNudge = -65, disableRotation = true, r = 0.4392156862745098, g = 0.984313725490196, b = 1, a = 1 },
            { texture = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\ShamanStoneFlame.blp", scale = 0.35, hNudge = -65, vNudge = 65, disableRotation = true, r = 1, g = 1, b = 1, a = 1 },
            { texture = "SPELLS\\Shockwave4.blp", scale = 1.79, rotation = 184, rotSpeed = 9, drawLayer = "BORDER", blendMode = "ADD", r = 1, g = 1, b = 1, a = 1 },
            { texture = "World\\ENVIRONMENT\\DOODAD\\GENERALDOODADS\\ELEMENTALRIFTS\\Shockwave_blue.blp", scale = 1.12, rotSpeed = 10, disableRotation = true, drawLayer = "BORDER", blendMode = "ADD", r = 0, g = 0.5568627450980392, b = 1, a = 0.75 },
            { texture = "SPELLS\\SHOCKWAVE_INVERTGREY.BLP", scale = 1.49, rotSpeed = -1, r = 1, g = 0.6313725490196078, b = 0, a = 0.3700000047683716 },
            { texture = "SPELLS\\GENERICGLOW64.BLP", hNudge = -65, vNudge = 65, drawLayer = "BACKGROUND", disableRotation = true, r = 1, g = 0.2313725490196079, b = 0, a = 0.5 },
            { texture = "SPELLS\\GENERICGLOW64.BLP", scale = 1.11, hNudge = -65, vNudge = -65, drawLayer = "BACKGROUND", r = 1, g = 0, b = 0.9333333333333334, a = 0.4700000286102295 },
            { texture = "SPELLS\\GENERICGLOW64.BLP", scale = 1.11, hNudge = 65, vNudge = -65, drawLayer = "BACKGROUND", r = 0, g = 0.04705882352941176, b = 1, a = 0.5100000202655792 },
            { texture = "SPELLS\\GENERICGLOW64.BLP", scale = 1.1, hNudge = 65, vNudge = 65, drawLayer = "BACKGROUND", r = 0.2588235294117647, g = 1, b = 0, a = 0.4000000357627869 },
        },
    },
}

local function GetMinimapConfig()
    return addon.db and addon.db.profile and addon.db.profile.minimap
end

local function GetModuleConfig()
    return addon:GetModuleConfig("MinimapDecorations")
end

local function IsModuleEnabled()
    local config = GetModuleConfig()
    if config and config.enabled == false then
        return false
    end
    return true
end

local function IsMinimapSystemEnabled()
    local cfg = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.minimap
    if not cfg or cfg.enabled == nil then
        return true
    end
    return cfg.enabled == true
end

local function IsHybridModeActive()
    local moduleConfig = addon.db and addon.db.profile and addon.db.profile.modules and addon.db.profile.modules.minimap
    local mode = moduleConfig and moduleConfig.sexymap_mode
    return mode == "hybrid" or mode == "sexymap"
end

local function IsEffectEnabled()
    local config = GetMinimapConfig()
    return IsModuleEnabled()
        and IsMinimapSystemEnabled()
        and not IsHybridModeActive()
        and config
        and config.animated_border_enabled == true
end

local function ClampOpacity(value)
    value = tonumber(value) or 1
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ClampDecorationScale(value)
    value = tonumber(value) or 1
    if value < 0.5 then return 0.5 end
    if value > 2 then return 2 end
    return value
end

local function GetPresetName()
    local config = GetMinimapConfig()
    local name = config and config.animated_border_preset or nil
    local defaultPreset = PRESET_ORDER[1]

    if not name or not PRESET_AVAILABLE[name] or not PRESETS[name] then
        if config then
            config.animated_border_preset = defaultPreset
        end
        return defaultPreset
    end
    return name
end

local function ShouldHideDragonUIBorder()
    local config = GetMinimapConfig()
    return config and config.animated_border_hide_dragonui_border == true
end

local function GetRecommendedDecorationScale()
    if ShouldHideDragonUIBorder() then
        return AUTO_SCALE_BORDER_HIDDEN
    end
    return AUTO_SCALE_BORDER_VISIBLE
end

local function IsAnimationEnabled()
    local config = GetMinimapConfig()
    if not config or config.animated_border_animations == nil then
        return true
    end
    return config.animated_border_animations == true
end

local function GetDecorationScale()
    local config = GetMinimapConfig()
    local recommended = GetRecommendedDecorationScale()

    if not config then
        return recommended
    end

    if config.animated_border_scale_auto ~= false then
        config.animated_border_scale = recommended
        return recommended
    end

    return ClampDecorationScale(config.animated_border_scale or recommended)
end

local function GetBaseSize()
    if not Minimap then return 180 end
    local width = Minimap:GetWidth() or 140
    local height = Minimap:GetHeight() or 140
    return mathmax(width, height) * 1.25
end

local function RotateTexture(texture, increment, set)
    if not texture then return end

    if type(increment) == "string" then
        local facing = GetPlayerFacing and GetPlayerFacing()
        if not facing then return end
        if increment == "normal" then
            facing = facing * -1
        end
        texture.hAngle = facing
    else
        texture.hAngle = (set and 0 or texture.hAngle or 0) - rad(increment or 0)
    end

    local s = sin(texture.hAngle)
    local c = cos(texture.hAngle)

    texture:SetTexCoord(
        0.5 - s, 0.5 + c,
        0.5 + c, 0.5 + s,
        0.5 - c, 0.5 - s,
        0.5 + s, 0.5 - c
    )
end

local function ClearTextures()
    for i = #MinimapDecorationsModule.textures, 1, -1 do
        local texture = MinimapDecorationsModule.textures[i]
        texture:Hide()
        texture:SetTexture(nil)
        texture.settings = nil
        texture.hAngle = nil
        MinimapDecorationsModule.texturePool[#MinimapDecorationsModule.texturePool + 1] = texture
        MinimapDecorationsModule.textures[i] = nil
    end

    for texture in pairs(MinimapDecorationsModule.rotatingTextures) do
        MinimapDecorationsModule.rotatingTextures[texture] = nil
    end
end

local function EnsureDragonUICirclePriority()
    local circle = Minimap and Minimap.Circle
    if circle and circle.SetDrawLayer then
        -- Keep the DragonUI circular border visually above decoration layers.
        circle:SetDrawLayer("OVERLAY", 7)
    end
end

local function EnsureMinimapTopPriority()
    local borderTop = _G.MinimapBorderTop
    local zoneButton = _G.MinimapZoneTextButton
    local clockButton = _G.TimeManagerClockButton
    local calendarFrame = _G.GameTimeFrame
    local baseLevel = (Minimap and Minimap.GetFrameLevel and Minimap:GetFrameLevel()) or 0
    local topLevel = baseLevel + 20

    if borderTop then
        -- Keep the zone/clock top strip above decoration textures.
        if borderTop.SetDrawLayer then
            borderTop:SetDrawLayer("OVERLAY", 7)
        end
        if borderTop.SetFrameStrata then
            borderTop:SetFrameStrata("MEDIUM")
        end
        if borderTop.SetFrameLevel then
            borderTop:SetFrameLevel(topLevel)
        end
    end

    if zoneButton then
        if zoneButton.SetFrameStrata then
            zoneButton:SetFrameStrata("MEDIUM")
        end
        if zoneButton.SetFrameLevel then
            zoneButton:SetFrameLevel(topLevel + 1)
        end
    end

    if clockButton then
        if clockButton.SetFrameStrata then
            clockButton:SetFrameStrata("MEDIUM")
        end
        if clockButton.SetFrameLevel then
            clockButton:SetFrameLevel(topLevel + 1)
        end
    end

    if calendarFrame then
        if calendarFrame.SetFrameStrata then
            calendarFrame:SetFrameStrata("MEDIUM")
        end
        if calendarFrame.SetFrameLevel then
            calendarFrame:SetFrameLevel(topLevel + 1)
        end
    end
end

local function RefreshMinimapMaskState()
    local minimapModule = addon.MinimapModule
    if minimapModule and minimapModule.applied and minimapModule.UpdateRotation then
        minimapModule.UpdateRotation()
    end
end

local function UpdateDragonUIBorderVisibility()
    local minimapModule = addon.MinimapModule
    local borderFrame = minimapModule and minimapModule.borderFrame
    local borderTexture = borderFrame and borderFrame.border

    local circle = Minimap and Minimap.Circle
    local toggleButton = _G.MinimapToggleButton

    if not borderTexture and not circle and not toggleButton then
        MinimapDecorationsModule.originalStates.minimapBorderTextureHiddenByDecorations = nil
        MinimapDecorationsModule.originalStates.minimapBorderTextureAlpha = nil
        MinimapDecorationsModule.originalStates.minimapBorderTextureShown = nil
        MinimapDecorationsModule.originalStates.minimapCircleHiddenByDecorations = nil
        MinimapDecorationsModule.originalStates.minimapCircleAlpha = nil
        MinimapDecorationsModule.originalStates.minimapCircleShown = nil
        MinimapDecorationsModule.originalStates.minimapToggleButtonHiddenByDecorations = nil
        MinimapDecorationsModule.originalStates.minimapToggleButtonAlpha = nil
        MinimapDecorationsModule.originalStates.minimapToggleButtonShown = nil
        MinimapDecorationsModule.originalStates.minimapToggleButtonEnabled = nil
        return
    end

    if ShouldHideDragonUIBorder() then
        if not MinimapDecorationsModule.originalStates.minimapBorderTextureHiddenByDecorations then
            MinimapDecorationsModule.originalStates.minimapBorderTextureAlpha = borderTexture and borderTexture:GetAlpha() or nil
            MinimapDecorationsModule.originalStates.minimapBorderTextureShown = borderTexture and borderTexture:IsShown() or nil

            MinimapDecorationsModule.originalStates.minimapCircleAlpha = circle and circle:GetAlpha() or nil
            MinimapDecorationsModule.originalStates.minimapCircleShown = circle and circle:IsShown() or nil

            MinimapDecorationsModule.originalStates.minimapToggleButtonAlpha = toggleButton and toggleButton:GetAlpha() or nil
            MinimapDecorationsModule.originalStates.minimapToggleButtonShown = toggleButton and toggleButton:IsShown() or nil
            MinimapDecorationsModule.originalStates.minimapToggleButtonEnabled = toggleButton and toggleButton:IsEnabled() or nil
        end
        if borderTexture then
            borderTexture:SetAlpha(0)
            borderTexture:Hide()
        end
        if circle then
            circle:SetAlpha(0)
            circle:Hide()
            MinimapDecorationsModule.originalStates.minimapCircleHiddenByDecorations = true
        end
        if toggleButton then
            toggleButton:SetAlpha(0)
            toggleButton:Hide()
            if toggleButton.Disable then
                toggleButton:Disable()
            end
            MinimapDecorationsModule.originalStates.minimapToggleButtonHiddenByDecorations = true
        end
        MinimapDecorationsModule.originalStates.minimapBorderTextureHiddenByDecorations = true
        return
    end

    if MinimapDecorationsModule.originalStates.minimapBorderTextureHiddenByDecorations then
        if borderTexture then
            local alpha = MinimapDecorationsModule.originalStates.minimapBorderTextureAlpha
            if alpha == nil then
                alpha = 0
            end
            borderTexture:SetAlpha(alpha)
            if MinimapDecorationsModule.originalStates.minimapBorderTextureShown then
                borderTexture:Show()
            else
                borderTexture:Hide()
            end
        end

        if circle then
            local circleAlpha = MinimapDecorationsModule.originalStates.minimapCircleAlpha
            if circleAlpha == nil then
                circleAlpha = 1
            end
            circle:SetAlpha(circleAlpha)
            if MinimapDecorationsModule.originalStates.minimapCircleShown ~= false then
                circle:Show()
            else
                circle:Hide()
            end
            EnsureDragonUICirclePriority()
        end

        if toggleButton then
            local toggleAlpha = MinimapDecorationsModule.originalStates.minimapToggleButtonAlpha
            if toggleAlpha == nil then
                toggleAlpha = 1
            end
            toggleButton:SetAlpha(toggleAlpha)
            if MinimapDecorationsModule.originalStates.minimapToggleButtonShown ~= false then
                toggleButton:Show()
            else
                toggleButton:Hide()
            end
            if MinimapDecorationsModule.originalStates.minimapToggleButtonEnabled == false then
                if toggleButton.Disable then
                    toggleButton:Disable()
                end
            elseif toggleButton.Enable then
                toggleButton:Enable()
            end
        end
    end

    MinimapDecorationsModule.originalStates.minimapBorderTextureHiddenByDecorations = nil
    MinimapDecorationsModule.originalStates.minimapBorderTextureAlpha = nil
    MinimapDecorationsModule.originalStates.minimapBorderTextureShown = nil
    MinimapDecorationsModule.originalStates.minimapCircleHiddenByDecorations = nil
    MinimapDecorationsModule.originalStates.minimapCircleAlpha = nil
    MinimapDecorationsModule.originalStates.minimapCircleShown = nil
    MinimapDecorationsModule.originalStates.minimapToggleButtonHiddenByDecorations = nil
    MinimapDecorationsModule.originalStates.minimapToggleButtonAlpha = nil
    MinimapDecorationsModule.originalStates.minimapToggleButtonShown = nil
    MinimapDecorationsModule.originalStates.minimapToggleButtonEnabled = nil
end

local function EnsureBackdrop()
    if MinimapDecorationsModule.frames.backdrop then
        return MinimapDecorationsModule.frames.backdrop
    end

    local backdrop = CreateFrame("Frame", "DragonUI_MinimapDecorationsBackdrop", Minimap)
    backdrop:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    backdrop:SetFrameStrata("BACKGROUND")
    backdrop:SetFrameLevel(mathmax(0, Minimap:GetFrameLevel() - 1))
    backdrop:EnableMouse(false)
    backdrop:Hide()
    MinimapDecorationsModule.frames.backdrop = backdrop
    return backdrop
end

local function AcquireTexture(parent)
    local texture = MinimapDecorationsModule.texturePool[#MinimapDecorationsModule.texturePool]
    if texture then
        MinimapDecorationsModule.texturePool[#MinimapDecorationsModule.texturePool] = nil
        if texture.SetParent then
            texture:SetParent(parent)
        end
    else
        texture = parent:CreateTexture(nil, "ARTWORK")
    end
    MinimapDecorationsModule.textures[#MinimapDecorationsModule.textures + 1] = texture
    return texture
end

local function ApplyBackdrop(preset, opacity, scaleMultiplier)
    local backdrop = EnsureBackdrop()
    local data = preset and preset.backdrop
    if not data or not data.show then
        backdrop:Hide()
        return
    end

    local baseSize = GetBaseSize()
    local scale = (data.scale or 1) * (scaleMultiplier or 1)
    backdrop:SetSize(baseSize, baseSize)
    backdrop:SetScale(scale)
    backdrop:SetAlpha(opacity)
    backdrop:SetBackdrop(data.settings)

    local color = data.textureColor or {}
    backdrop:SetBackdropColor(color.r or 0, color.g or 0, color.b or 0, (color.a or 1) * opacity)

    color = data.borderColor or {}
    backdrop:SetBackdropBorderColor(color.r or 1, color.g or 1, color.b or 1, (color.a or 1) * opacity)
    backdrop:Show()
end

local function ApplyPresetLayers(preset, opacity, scaleMultiplier)
    local baseSize = GetBaseSize()
    local hasRotations = false
    local hasLayers = false
    local layerScaleMultiplier = scaleMultiplier or 1
    local globalXOffset = ShouldHideDragonUIBorder() and 0 or DECORATIONS_GLOBAL_OFFSET_X
    local globalYOffset = ShouldHideDragonUIBorder() and 0 or DECORATIONS_GLOBAL_OFFSET_Y

    for _, layer in ipairs((preset and preset.borders) or {}) do
        local texture = AcquireTexture(Minimap)
        texture:SetTexture(layer.texture)
        texture:SetBlendMode(layer.blendMode or "ADD")
        texture:SetVertexColor(layer.r or 1, layer.g or 1, layer.b or 1, (layer.a or 1) * opacity)
        texture:SetDrawLayer(layer.drawLayer or "ARTWORK")
        texture:SetSize(baseSize * (layer.scale or 1) * layerScaleMultiplier, baseSize * (layer.scale or 1) * layerScaleMultiplier)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", Minimap, "CENTER", ((layer.hNudge or 0) * layerScaleMultiplier) + globalXOffset, ((layer.vNudge or 0) * layerScaleMultiplier) + globalYOffset)
        texture.settings = layer
        texture:Show()
        hasLayers = true

        if layer.disableRotation then
            texture:SetTexCoord(0, 1, 0, 1)
        else
            RotateTexture(texture, layer.rotation or 0, true)
            if IsAnimationEnabled() then
                if layer.playerRotation and layer.playerRotation ~= "none" then
                    MinimapDecorationsModule.rotatingTextures[texture] = layer.playerRotation
                    hasRotations = true
                elseif layer.rotSpeed and layer.rotSpeed ~= 0 then
                    MinimapDecorationsModule.rotatingTextures[texture] = layer.rotSpeed
                    hasRotations = true
                end
            end
        end
    end

    if not hasLayers then
        ClearTextures()
    end

    return hasRotations
end

local updateInterval = 1 / 60
local elapsedSinceUpdate = 0
local function UpdateRotations(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < updateInterval then
        return
    end

    local delta = elapsedSinceUpdate
    elapsedSinceUpdate = 0

    for texture, speed in pairs(MinimapDecorationsModule.rotatingTextures) do
        if type(speed) == "number" then
            RotateTexture(texture, speed * delta)
        else
            RotateTexture(texture, speed)
        end
    end
end

local function StopAnimation()
    if MinimapDecorationsModule.frames.animationFrame then
        MinimapDecorationsModule.frames.animationFrame:SetScript("OnUpdate", nil)
    end
    elapsedSinceUpdate = 0
end

local function StartAnimation()
    if not MinimapDecorationsModule.frames.animationFrame then
        MinimapDecorationsModule.frames.animationFrame = CreateFrame("Frame")
    end
    MinimapDecorationsModule.frames.animationFrame:SetScript("OnUpdate", UpdateRotations)
end

function MinimapDecorationsModule:GetPresetList()
    local values = {}
    for _, name in ipairs(PRESET_ORDER) do
        values[name] = PRESET_LABELS[name] or name
    end
    return values
end

function MinimapDecorationsModule:Restore()
    StopAnimation()
    ClearTextures()
    if self.frames.effectFrame then
        self.frames.effectFrame:Hide()
    end
    if self.frames.backdrop then
        self.frames.backdrop:Hide()
    end

    local minimapModule = addon.MinimapModule
    local minimapSystemActive = IsMinimapSystemEnabled()
        and minimapModule
        and minimapModule.applied
    if minimapSystemActive then
        EnsureMinimapTopPriority()
    end

    -- Skip circle/border restore when Minimap System is off (avoids DragonUI chrome over other addons).
    if self.originalStates.minimapBorderTextureHiddenByDecorations and minimapSystemActive then
        local borderTexture = minimapModule.borderFrame and minimapModule.borderFrame.border
        local circle = Minimap and Minimap.Circle
        local toggleButton = _G.MinimapToggleButton
        if borderTexture then
            local alpha = self.originalStates.minimapBorderTextureAlpha
            if alpha == nil then
                alpha = 0
            end
            borderTexture:SetAlpha(alpha)
            if self.originalStates.minimapBorderTextureShown then
                borderTexture:Show()
            else
                borderTexture:Hide()
            end
        end
        if circle then
            local circleAlpha = self.originalStates.minimapCircleAlpha
            if circleAlpha == nil then
                circleAlpha = 1
            end
            circle:SetAlpha(circleAlpha)
            if self.originalStates.minimapCircleShown ~= false then
                circle:Show()
            else
                circle:Hide()
            end
            EnsureDragonUICirclePriority()
        end
        if toggleButton then
            local toggleAlpha = self.originalStates.minimapToggleButtonAlpha
            if toggleAlpha == nil then
                toggleAlpha = 1
            end
            toggleButton:SetAlpha(toggleAlpha)
            if self.originalStates.minimapToggleButtonShown ~= false then
                toggleButton:Show()
            else
                toggleButton:Hide()
            end
            if self.originalStates.minimapToggleButtonEnabled == false then
                if toggleButton.Disable then
                    toggleButton:Disable()
                end
            elseif toggleButton.Enable then
                toggleButton:Enable()
            end
        end
    end

    self.originalStates.minimapBorderTextureHiddenByDecorations = nil
    self.originalStates.minimapBorderTextureAlpha = nil
    self.originalStates.minimapBorderTextureShown = nil
    self.originalStates.minimapCircleHiddenByDecorations = nil
    self.originalStates.minimapCircleAlpha = nil
    self.originalStates.minimapCircleShown = nil
    self.originalStates.minimapToggleButtonHiddenByDecorations = nil
    self.originalStates.minimapToggleButtonAlpha = nil
    self.originalStates.minimapToggleButtonShown = nil
    self.originalStates.minimapToggleButtonEnabled = nil
    self.applied = false
    self.currentPreset = nil
    self.currentOpacity = nil

    RefreshMinimapMaskState()
end

function MinimapDecorationsModule:Apply()
    if not Minimap or not IsEffectEnabled() then
        self:Restore()
        return
    end

    ClearTextures()

    local presetName = GetPresetName()
    local preset = PRESETS[presetName] or PRESETS[PRESET_ORDER[1]]
    local config = GetMinimapConfig()
    local opacity = ClampOpacity(config and config.animated_border_opacity or 1)
    local scaleMultiplier = GetDecorationScale()

    ApplyBackdrop(preset, opacity, scaleMultiplier)
    local hasRotations = ApplyPresetLayers(preset, opacity, scaleMultiplier)

    if hasRotations then
        StartAnimation()
    else
        StopAnimation()
    end

    EnsureDragonUICirclePriority()
    EnsureMinimapTopPriority()
    UpdateDragonUIBorderVisibility()
    RefreshMinimapMaskState()

    self.currentPreset = presetName
    self.currentOpacity = opacity
    self.applied = true
end

function MinimapDecorationsModule:Refresh()
    if IsEffectEnabled() then
        self:Apply()
    else
        -- Hide DragonUI Border only applies while decorations are on; clear stale flag on disable.
        local minimapConfig = GetMinimapConfig()
        if minimapConfig and minimapConfig.animated_border_enabled ~= true
            and minimapConfig.animated_border_hide_dragonui_border then
            minimapConfig.animated_border_hide_dragonui_border = false
        end
        self:Restore()
        if IsModuleEnabled()
            and IsMinimapSystemEnabled()
            and addon.MinimapModule
            and addon.MinimapModule.applied then
            UpdateDragonUIBorderVisibility()
            RefreshMinimapMaskState()
        end
    end
end

function MinimapDecorationsModule:Initialize()
    if self.initialized then return end
    self.initialized = true

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        MinimapDecorationsModule:Refresh()
    end)
    self.frames.eventFrame = eventFrame

    if addon.RegisterCallback then
        addon:RegisterCallback("OnProfileChanged", function() MinimapDecorationsModule:Refresh() end)
        addon:RegisterCallback("OnProfileCopied", function() MinimapDecorationsModule:Refresh() end)
        addon:RegisterCallback("OnProfileReset", function() MinimapDecorationsModule:Refresh() end)
    end
end

MinimapDecorationsModule:Initialize()




