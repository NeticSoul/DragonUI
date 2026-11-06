-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - System Graphics Tab
================================================================================
Full video settings: display mode, resolution/refresh/multisampling,
all effect sliders, quality presets, and extended engine CVars.
Client-saved / client APIs.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

local function CVarNum(cvar, fallback)
    if not GetCVar then return fallback end
    local ok, val = pcall(GetCVar, cvar)
    local num = ok and tonumber(val)
    return num or fallback
end

local function SetCVarNum(cvar, value)
    if SetCVar then pcall(SetCVar, cvar, value) end
end

local function CVarBool(cvar)
    if not GetCVar then return false end
    local ok, val = pcall(GetCVar, cvar)
    return ok and val == "1"
end

local function SetCVarBool(cvar, on)
    if SetCVar then SetCVar(cvar, on and "1" or "0") end
end

local function HasHardwareCursor()
    if not GetVideoCaps then return true end
    local ok, caps = pcall(GetVideoCaps)
    if not ok or not caps then return true end
    local hw = select(7, caps)
    return hw == true or hw == 1
end

local function RestartVideo()
    if RestartGx then
        RestartGx()
    end
end

local function PromptClientRestart()
    if StaticPopupDialogs and StaticPopupDialogs.CLIENT_RESTART_ALERT then
        StaticPopup_Show("CLIENT_RESTART_ALERT")
    end
end

local function BuildGraphicsTab(scroll)
    -- ====================================================================
    -- DISPLAY & MODE
    -- ====================================================================
    local displaySection = C:AddSection(scroll, LO["Display & Mode"] or "Display & Mode")

    C:AddDropdown(displaySection, {
        label = LO["Display Mode"] or "Display Mode",
        desc = LO["Fullscreen or windowed."] or "Fullscreen or windowed.",
        values = {
            ["0"] = LO["Fullscreen"] or "Fullscreen",
            ["1"] = LO["Windowed"] or "Windowed",
        },
        getFunc = function() return tostring(GetCVar and GetCVar("gxWindow") or "0") end,
        setFunc = function(val) SetCVarNum("gxWindow", val) RestartVideo() end,
        callback = function() Panel:SelectTab("graphics") end,
    })

    C:AddToggle(displaySection, {
        label = LO["Vertical Sync"] or "Vertical Sync",
        desc = LO["Limit frame rate to display refresh."] or "Limit frame rate to display refresh.",
        getFunc = function() return CVarBool("gxVSync") end,
        setFunc = function(val) SetCVarBool("gxVSync", val) RestartVideo() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Triple Buffering"] or "Triple Buffering",
        desc = LO["Smoother frame pacing with vertical sync."] or "Smoother frame pacing with vertical sync.",
        getFunc = function() return CVarBool("gxTripleBuffer") end,
        setFunc = function(val) SetCVarBool("gxTripleBuffer", val) RestartVideo() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Hardware Cursor"] or "Hardware Cursor",
        desc = LO["Offload the mouse cursor to the graphics hardware."] or "Offload the mouse cursor to the graphics hardware.",
        getFunc = function() return CVarBool("gxCursor") end,
        setFunc = function(val) SetCVarBool("gxCursor", val) end,
        disabled = function() return not HasHardwareCursor() end,
    })

    C:AddToggle(displaySection, {
        label = LO["Reduce Input Lag"] or "Reduce Input Lag",
        desc = LO["Reduce input lag for the cost of raw frame rate."] or "Reduce input lag for the cost of raw frame rate.",
        getFunc = function() return CVarBool("gxFixLag") end,
        setFunc = function(val) SetCVarBool("gxFixLag", val) end,
    })

    C:AddToggle(displaySection, {
        label = LO["Maximized"] or "Maximized",
        desc = LO["Start maximized in windowed mode."] or "Start maximized in windowed mode.",
        getFunc = function() return CVarBool("gxMaximize") end,
        setFunc = function(val) SetCVarBool("gxMaximize", val) RestartVideo() end,
        callback = function() Panel:SelectTab("graphics") end,
        disabled = function() return not CVarBool("gxWindow") end,
    })

    C:AddToggle(displaySection, {
        label = LO["Disable Resize"] or "Disable Resize",
        desc = LO["Lock window size in windowed mode."] or "Lock window size in windowed mode.",
        getFunc = function() return CVarBool("windowResizeLock") end,
        setFunc = function(val) SetCVarBool("windowResizeLock", val) end,
        disabled = function() return not CVarBool("gxWindow") end,
    })

    -- Shared with General settings.
    local UIScale = addon.UIScale
    if UIScale then
        local scaleSlider
        C:AddToggle(displaySection, {
            label = LO["Custom UI Scale"] or "Custom UI Scale",
            desc = LO["Lets the interface go smaller than 0.64."] or "Lets the interface go smaller than 0.64.",
            getFunc = UIScale.IsEnabled,
            setFunc = function(enabled)
                UIScale.SetEnabled(enabled)
                SetCVarBool("useUiScale", enabled)
            end,
            callback = function(enabled)
                if scaleSlider then
                    scaleSlider:SetValue(UIScale.Get())
                    scaleSlider:SetDisabled(not enabled)
                end
                Panel:ApplyUIScale()
            end,
        })

        scaleSlider = C:AddSlider(displaySection, {
            label = LO["UI Scale"] or "UI Scale",
            desc = LO["Interface size."] or "Interface size.",
            min = UIScale.MIN,
            max = UIScale.MAX,
            step = 0.01,
            width = 200,
            getFunc = UIScale.Get,
            setFunc = function(val) Panel:SetUIScale(val) end,
            disabled = function() return not UIScale.IsEnabled() end,
        })
    end

    -- ====================================================================
    -- RESOLUTION
    -- ====================================================================
    local resolutionSection = C:AddSection(scroll, LO["Resolution"] or "Resolution")

    -- Resolutions list from the client at build time, keyed by index
    -- (GetCurrentResolution / SetScreenResolution work with indices).
    local resValues = {}
    local resList = nil
    if GetScreenResolutions then
        local ok, list = pcall(function() return { GetScreenResolutions() } end)
        if ok and type(list) == "table" and #list > 0 then
            resList = list
            for index, res in ipairs(list) do
                local w, h = string.match(tostring(res), "^(%d+)x(%d+)")
                local label = tostring(res)
                if w and h and tonumber(w) / tonumber(h) > 4 / 3 then
                    label = label .. " (Wide)"
                end
                resValues[index] = label
            end
        end
    end
    if next(resValues) == nil then
        resValues[1] = "1024x768"
    end

    C:AddDropdown(resolutionSection, {
        label = LO["Screen Resolution"] or "Screen Resolution",
        desc = LO["Display resolution."] or "Display resolution.",
        values = resValues,
        width = 240,
        getFunc = function()
            if GetCurrentResolution then
                local ok, cur = pcall(GetCurrentResolution)
                if ok and cur and resValues[cur] then return cur end
            end
            -- Fall back to the saved gxResolution string if the index is unknown.
            local saved = GetCVar and GetCVar("gxResolution")
            if resList and saved then
                for index, res in ipairs(resList) do
                    if tostring(res) == tostring(saved) then return index end
                end
            end
            return 1
        end,
        setFunc = function(val)
            if SetScreenResolution then SetScreenResolution(val) end
            RestartVideo()
        end,
        disabled = function() return CVarBool("gxWindow") and CVarBool("gxMaximize") end,
    })

    -- Refresh rates from the client; the CVar holds the Hz value.
    local refreshValues = {}
    if GetRefreshRates then
        local ok, list = pcall(function() return { GetRefreshRates() } end)
        if ok and type(list) == "table" then
            for _, hz in ipairs(list) do
                refreshValues[hz] = tostring(hz) .. "Hz"
            end
        end
    end
    if next(refreshValues) == nil then
        local hz = CVarNum("gxRefresh", 60)
        refreshValues[hz] = tostring(hz) .. "Hz"
    end

    C:AddDropdown(resolutionSection, {
        label = LO["Refresh Rate"] or "Refresh Rate",
        desc = LO["Refresh rate."] or "Refresh rate.",
        values = refreshValues,
        width = 240,
        getFunc = function() return CVarNum("gxRefresh", 60) end,
        setFunc = function(val) SetCVarNum("gxRefresh", val) RestartVideo() end,
    })

    -- Multisampling formats from the client (triples: color, depth, samples).
    local msValues = {}
    if GetMultisampleFormats then
        local ok, list = pcall(function() return { GetMultisampleFormats() } end)
        if ok and type(list) == "table" and #list >= 3 then
            local index = 1
            for i = 1, #list - 2, 3 do
                local c, d, m = list[i], list[i + 1], list[i + 2]
                if c and d and m then
                    msValues[index] = string.format("%d-bit color %d-bit depth %dx multisample", c, d, m)
                    index = index + 1
                end
            end
        end
    end
    if next(msValues) == nil then
        msValues[1] = LO["24-bit color 24-bit depth 1x multisample"] or "24-bit color 24-bit depth 1x multisample"
    end

    C:AddDropdown(resolutionSection, {
        label = LO["Multisampling"] or "Multisampling",
        desc = LO["Anti-aliasing and color/depth."] or "Anti-aliasing and color/depth.",
        values = msValues,
        width = 240,
        getFunc = function()
            if GetCurrentMultisampleFormat then
                local ok, cur = pcall(GetCurrentMultisampleFormat)
                if ok and cur then return cur end
            end
            return CVarNum("gxMultisampleQuality", 1)
        end,
        setFunc = function(val)
            if SetMultisampleFormat then SetMultisampleFormat(val) end
            RestartVideo()
        end,
    })

    -- ====================================================================
    -- BRIGHTNESS
    -- ====================================================================
    local brightnessSection = C:AddSection(scroll, LO["Brightness"] or "Brightness")

    C:AddToggle(brightnessSection, {
        label = LO["Use Desktop Gamma"] or "Use Desktop Gamma",
        desc = LO["Use desktop gamma."] or "Use desktop gamma.",
        getFunc = function() return CVarBool("desktopGamma") end,
        setFunc = function(val) SetCVarBool("desktopGamma", val) end,
        callback = function() Panel:SelectTab("graphics") end,
        disabled = function() return CVarBool("gxWindow") end,
    })

    C:AddSlider(brightnessSection, {
        label = LO["Gamma"] or "Gamma",
        desc = LO["Gamma."] or "Gamma.",
        min = -0.5, max = 0.5, step = 0.1,
        width = 200,
        getFunc = function() return CVarNum("gamma", 0) end,
        setFunc = function(val) SetCVarNum("gamma", val) end,
        disabled = function() return CVarBool("gxWindow") or CVarBool("desktopGamma") end,
    })

    -- ====================================================================
    -- EFFECTS
    -- ====================================================================
    local effectsSection = C:AddSection(scroll, LO["Effects"] or "Effects")

    -- Video quality presets.
    local PRESETS = {
        [1] = { farclip = 177, particleDensity = 0.1, environmentDetail = 0.5, groundEffectDensity = 16, groundEffectDist = 70, extShadowQuality = 0, BaseMip = 0, textureFilteringMode = 0, weatherDensity = 0, componentTextureLevel = 8, specular = false, ffxGlow = false, ffxDeath = false, projectedTextures = false },
        [2] = { farclip = 507, particleDensity = 0.4, environmentDetail = 0.75, groundEffectDensity = 24, groundEffectDist = 80, extShadowQuality = 0, BaseMip = 0, textureFilteringMode = 1, weatherDensity = 0, componentTextureLevel = 8, specular = true, ffxGlow = true, ffxDeath = true, projectedTextures = false },
        [3] = { farclip = 727, particleDensity = 0.6, environmentDetail = 1.0, groundEffectDensity = 48, groundEffectDist = 120, extShadowQuality = 1, BaseMip = 1, textureFilteringMode = 2, weatherDensity = 2, componentTextureLevel = 9, specular = true, ffxGlow = true, ffxDeath = true, projectedTextures = true },
        [4] = { farclip = 1057, particleDensity = 0.8, environmentDetail = 1.25, groundEffectDensity = 56, groundEffectDist = 130, extShadowQuality = 4, BaseMip = 1, textureFilteringMode = 4, weatherDensity = 3, componentTextureLevel = 9, specular = true, ffxGlow = true, ffxDeath = true, projectedTextures = true },
        [5] = { farclip = 1277, particleDensity = 1.0, environmentDetail = 1.5, groundEffectDensity = 64, groundEffectDist = 140, extShadowQuality = 5, BaseMip = 1, textureFilteringMode = 5, weatherDensity = 3, componentTextureLevel = 9, specular = true, ffxGlow = true, ffxDeath = true, projectedTextures = true },
    }

    C:AddDropdown(effectsSection, {
        label = LO["Video Quality"] or "Video Quality",
        desc = LO["Apply a graphics preset."] or "Apply a graphics preset.",
        values = {
            [1] = LO["Low"] or "Low",
            [2] = LO["Fair"] or "Fair",
            [3] = LO["Good"] or "Good",
            [4] = LO["High"] or "High",
            [5] = LO["Ultra"] or "Ultra",
        },
        width = 240,
        getFunc = function() return 5 end,
        setFunc = function(val)
            local preset = PRESETS[tonumber(val)]
            if not preset then return end
            SetCVarNum("farclip", preset.farclip)
            SetCVarNum("particleDensity", preset.particleDensity)
            SetCVarNum("environmentDetail", preset.environmentDetail)
            SetCVarNum("groundEffectDensity", preset.groundEffectDensity)
            SetCVarNum("groundEffectDist", preset.groundEffectDist)
            SetCVarNum("extShadowQuality", preset.extShadowQuality)
            SetCVarNum("BaseMip", preset.BaseMip)
            SetCVarNum("textureFilteringMode", preset.textureFilteringMode)
            SetCVarNum("weatherDensity", preset.weatherDensity)
            SetCVarNum("componentTextureLevel", preset.componentTextureLevel)
            SetCVarBool("specular", preset.specular)
            SetCVarBool("ffxGlow", preset.ffxGlow)
            SetCVarBool("ffxDeath", preset.ffxDeath)
            SetCVarBool("projectedTextures", preset.projectedTextures)
            Panel:SelectTab("graphics")
        end,
    })

    C:AddSlider(effectsSection, {
        label = LO["View Distance"] or "View Distance",
        desc = LO["Terrain render distance."] or "Terrain render distance.",
        min = 177, max = 1600, step = 50,
        width = 200,
        getFunc = function() return CVarNum("farclip", 777) end,
        setFunc = function(val) SetCVarNum("farclip", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Environment Detail"] or "Environment Detail",
        desc = LO["Amount of environment detail drawn."] or "Amount of environment detail drawn.",
        min = 0.5, max = 1.5, step = 0.25,
        width = 200,
        getFunc = function() return CVarNum("environmentDetail", 1) end,
        setFunc = function(val) SetCVarNum("environmentDetail", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Texture Resolution"] or "Texture Resolution",
        desc = LO["World texture resolution."] or "World texture resolution.",
        min = 0, max = 1, step = 1,
        width = 200,
        getFunc = function() return CVarNum("BaseMip", 1) end,
        setFunc = function(val) SetCVarNum("BaseMip", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Ground Clutter Density"] or "Ground Clutter Density",
        desc = LO["Ground clutter density."] or "Ground clutter density.",
        min = 16, max = 256, step = 16,
        width = 200,
        getFunc = function() return CVarNum("groundEffectDensity", 64) end,
        setFunc = function(val) SetCVarNum("groundEffectDensity", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Ground Clutter Radius"] or "Ground Clutter Radius",
        desc = LO["Maximum distance at which grass and ground clutter spawn."] or "Maximum distance at which grass and ground clutter spawn.",
        min = 40, max = 140, step = 10,
        width = 200,
        getFunc = function() return CVarNum("groundEffectDist", 70) end,
        setFunc = function(val) SetCVarNum("groundEffectDist", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Texture Filtering"] or "Texture Filtering",
        desc = LO["Anisotropic filtering."] or "Anisotropic filtering.",
        min = 0, max = 5, step = 1,
        width = 200,
        getFunc = function() return CVarNum("textureFilteringMode", 1) end,
        setFunc = function(val) SetCVarNum("textureFilteringMode", val) PromptClientRestart() end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Particle Density"] or "Particle Density",
        desc = LO["Spell and environment particle density."] or "Spell and environment particle density.",
        min = 0.1, max = 1, step = 0.1,
        width = 200,
        getFunc = function() return CVarNum("particleDensity", 1) end,
        setFunc = function(val) SetCVarNum("particleDensity", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Weather Intensity"] or "Weather Intensity",
        desc = LO["Rain, snow and sandstorm particle intensity."] or "Rain, snow and sandstorm particle intensity.",
        min = 0, max = 3, step = 1,
        width = 200,
        getFunc = function() return CVarNum("weatherDensity", 2) end,
        setFunc = function(val) SetCVarNum("weatherDensity", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Shadow Quality"] or "Shadow Quality",
        desc = LO["Quality of rendered character and environment shadows."] or "Quality of rendered character and environment shadows.",
        min = 0, max = 5, step = 1,
        width = 200,
        getFunc = function() return CVarNum("extShadowQuality", 4) end,
        setFunc = function(val) SetCVarNum("extShadowQuality", val) end,
    })

    C:AddSlider(effectsSection, {
        label = LO["Player Textures"] or "Player Textures",
        desc = LO["Character texture detail."] or "Character texture detail.",
        min = 8, max = 9, step = 1,
        width = 200,
        getFunc = function() return CVarNum("componentTextureLevel", 9) end,
        setFunc = function(val) SetCVarNum("componentTextureLevel", val) PromptClientRestart() end,
    })

    C:AddToggle(effectsSection, {
        label = LO["Specular Lighting"] or "Specular Lighting",
        desc = LO["Terrain specular highlights."] or "Terrain specular highlights.",
        getFunc = function() return CVarBool("specular") end,
        setFunc = function(val) SetCVarBool("specular", val) end,
    })

    C:AddToggle(effectsSection, {
        label = LO["Death Effect"] or "Death Effect",
        desc = LO["Full-screen death effect."] or "Full-screen death effect.",
        getFunc = function() return CVarBool("ffxDeath") end,
        setFunc = function(val) SetCVarBool("ffxDeath", val) end,
    })

    C:AddToggle(effectsSection, {
        label = LO["Full-Screen Glow"] or "Full-Screen Glow",
        desc = LO["Full-screen glow effect."] or "Full-screen glow effect.",
        getFunc = function() return CVarBool("ffxGlow") end,
        setFunc = function(val) SetCVarBool("ffxGlow", val) end,
    })

    C:AddToggle(effectsSection, {
        label = LO["Projected Textures"] or "Projected Textures",
        desc = LO["Projected textures on the terrain."] or "Projected textures on the terrain.",
        getFunc = function() return CVarBool("projectedTextures") end,
        setFunc = function(val) SetCVarBool("projectedTextures", val) end,
    })

    -- ====================================================================
    -- CAMERA
    -- ====================================================================
    -- Absolute distance (cameraDistanceMax, max 15); the factor multiplier
    -- stays in Enhancements via RefreshCamera.
    local cameraSection = C:AddSection(scroll, LO["Camera"] or "Camera")

    C:AddSlider(cameraSection, {
        label = LO["Camera Max Distance"] or "Camera Max Distance",
        desc = LO["Maximum camera zoom-out distance (15 is the maximum)."] or "Maximum camera zoom-out distance (15 is the maximum).",
        min = 1, max = 15, step = 1,
        width = 200,
        getFunc = function() return CVarNum("cameraDistanceMax", 15) end,
        setFunc = function(val) SetCVarNum("cameraDistanceMax", val) end,
    })
end

Panel:RegisterTab("graphics", LO["Graphics"] or "Graphics", BuildGraphicsTab, 80)
