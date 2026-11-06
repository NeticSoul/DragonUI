-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - System Audio Tab
================================================================================
Full sound settings: master toggle, playback toggles,
hardware/output, volume, and the unlocked engine extras.
Client-saved CVars.
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
    if SetCVar then SetCVar(cvar, value) end
end

local function CVarBool(cvar)
    if not GetCVar then return false end
    local ok, val = pcall(GetCVar, cvar)
    return ok and val == "1"
end

local function SetCVarBool(cvar, on)
    if SetCVar then SetCVar(cvar, on and "1" or "0") end
end

local function RestartSoundSystem()
    if Sound_GameSystem_RestartSoundSystem then
        Sound_GameSystem_RestartSoundSystem()
    end
end

local function BuildAudioTab(scroll)
    -- ====================================================================
    -- MASTER
    -- ====================================================================
    local masterSection = C:AddSection(scroll, LO["Master"] or "Master")

    C:AddToggle(masterSection, {
        label = LO["Enable Sound"] or "Enable Sound",
        desc = LO["Master switch for all game sound."] or "Master switch for all game sound.",
        getFunc = function() return CVarBool("Sound_EnableAllSound") end,
        setFunc = function(val) SetCVarBool("Sound_EnableAllSound", val) end,
    })

    -- ====================================================================
    -- PLAYBACK
    -- ====================================================================
    local playbackSection = C:AddSection(scroll, LO["Playback"] or "Playback")

    C:AddToggle(playbackSection, {
        label = LO["Sound Effects"] or "Sound Effects",
        desc = LO["In-game sound effects."] or "In-game sound effects.",
        getFunc = function() return CVarBool("Sound_EnableSFX") end,
        setFunc = function(val) SetCVarBool("Sound_EnableSFX", val) end,
    })

    -- Error speech / emote / pet follow Sound Effects.
    C:AddToggle(playbackSection, {
        label = LO["Error Speech"] or "Error Speech",
        desc = LO["Speech played when you make an error."] or "Speech played when you make an error.",
        getFunc = function() return CVarBool("Sound_EnableErrorSpeech") end,
        setFunc = function(val) SetCVarBool("Sound_EnableErrorSpeech", val) end,
        disabled = function() return not CVarBool("Sound_EnableSFX") end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Emote Sounds"] or "Emote Sounds",
        desc = LO["Sounds played by /emote actions."] or "Sounds played by /emote actions.",
        getFunc = function() return CVarBool("Sound_EnableEmoteSounds") end,
        setFunc = function(val) SetCVarBool("Sound_EnableEmoteSounds", val) end,
        disabled = function() return not CVarBool("Sound_EnableSFX") end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Pet Sounds"] or "Pet Sounds",
        desc = LO["Sounds made by your pet."] or "Sounds made by your pet.",
        getFunc = function() return CVarBool("Sound_EnablePetSounds") end,
        setFunc = function(val) SetCVarBool("Sound_EnablePetSounds", val) end,
        disabled = function() return not CVarBool("Sound_EnableSFX") end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Music"] or "Music",
        desc = LO["Background music in zones."] or "Background music in zones.",
        getFunc = function() return CVarBool("Sound_EnableMusic") end,
        setFunc = function(val) SetCVarBool("Sound_EnableMusic", val) end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Loop Music"] or "Loop Music",
        desc = LO["Loop zone music."] or "Loop zone music.",
        getFunc = function() return CVarBool("Sound_ZoneMusicNoDelay") end,
        setFunc = function(val) SetCVarBool("Sound_ZoneMusicNoDelay", val) end,
        disabled = function() return not CVarBool("Sound_EnableMusic") end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Ambient Sounds"] or "Ambient Sounds",
        desc = LO["Non-music background ambience."] or "Non-music background ambience.",
        getFunc = function() return CVarBool("Sound_EnableAmbience") end,
        setFunc = function(val) SetCVarBool("Sound_EnableAmbience", val) end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Sound in Background"] or "Sound in Background",
        desc = LO["Play sound when unfocused."] or "Play sound when unfocused.",
        getFunc = function() return CVarBool("Sound_EnableSoundWhenGameIsInBG") end,
        setFunc = function(val) SetCVarBool("Sound_EnableSoundWhenGameIsInBG", val) end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Enable Reverb"] or "Enable Reverb",
        desc = LO["Echo."] or "Echo.",
        getFunc = function() return CVarBool("Sound_EnableReverb") end,
        setFunc = function(val) SetCVarBool("Sound_EnableReverb", val) RestartSoundSystem() end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Headphone Mode"] or "Headphone Mode",
        desc = LO["Optimized for headphones."] or "Optimized for headphones.",
        getFunc = function() return CVarBool("Sound_EnableSoftwareHRTF") end,
        setFunc = function(val) SetCVarBool("Sound_EnableSoftwareHRTF", val) RestartSoundSystem() end,
    })

    C:AddToggle(playbackSection, {
        label = LO["Death Knight Voices"] or "Death Knight Voices",
        desc = LO["DSP effects."] or "DSP effects.",
        getFunc = function() return CVarBool("Sound_EnableDSPEffects") end,
        setFunc = function(val) SetCVarBool("Sound_EnableDSPEffects", val) RestartSoundSystem() end,
    })

    C:AddSlider(playbackSection, {
        label = LO["Sound Quality"] or "Sound Quality",
        desc = LO["Quality (0 low, 1 medium, 2 high)."] or "Quality (0 low, 1 medium, 2 high).",
        min = 0, max = 2, step = 1,
        width = 200,
        getFunc = function() return CVarNum("Sound_OutputQuality", 1) end,
        setFunc = function(val) SetCVarNum("Sound_OutputQuality", val) RestartSoundSystem() end,
    })

    -- ====================================================================
    -- VOLUME
    -- ====================================================================
    local volumeSection = C:AddSection(scroll, LO["Volume"] or "Volume")

    C:AddSlider(volumeSection, {
        label = LO["Master Volume"] or "Master Volume",
        desc = LO["Overall game volume."] or "Overall game volume.",
        min = 0, max = 1, step = 0.05, isPercent = true,
        width = 200,
        getFunc = function() return CVarNum("Sound_MasterVolume", 1) end,
        setFunc = function(val) SetCVarNum("Sound_MasterVolume", val) end,
    })

    C:AddSlider(volumeSection, {
        label = LO["Sound Volume"] or "Sound Volume",
        desc = LO["Sound effects volume."] or "Sound effects volume.",
        min = 0, max = 1, step = 0.05, isPercent = true,
        width = 200,
        getFunc = function() return CVarNum("Sound_SFXVolume", 1) end,
        setFunc = function(val) SetCVarNum("Sound_SFXVolume", val) end,
    })

    C:AddSlider(volumeSection, {
        label = LO["Music Volume"] or "Music Volume",
        desc = LO["Music volume."] or "Music volume.",
        min = 0, max = 1, step = 0.05, isPercent = true,
        width = 200,
        getFunc = function() return CVarNum("Sound_MusicVolume", 0.4) end,
        setFunc = function(val) SetCVarNum("Sound_MusicVolume", val) end,
    })

    C:AddSlider(volumeSection, {
        label = LO["Ambience Volume"] or "Ambience Volume",
        desc = LO["Ambience volume."] or "Ambience volume.",
        min = 0, max = 1, step = 0.05, isPercent = true,
        width = 200,
        getFunc = function() return CVarNum("Sound_AmbienceVolume", 0.6) end,
        setFunc = function(val) SetCVarNum("Sound_AmbienceVolume", val) end,
    })

    -- ====================================================================
    -- HARDWARE
    -- ====================================================================
    local hardwareSection = C:AddSection(scroll, LO["Hardware"] or "Hardware")

    -- Device list comes from the client at build time; guarded for clients without it.
    local deviceValues = {}
    if Sound_GameSystem_GetNumOutputDrivers and Sound_GameSystem_GetOutputDriverNameByIndex then
        local ok, num = pcall(Sound_GameSystem_GetNumOutputDrivers)
        if ok and type(num) == "number" and num > 0 then
            for index = 0, num - 1 do
                local okName, name = pcall(Sound_GameSystem_GetOutputDriverNameByIndex, index)
                deviceValues[index] = okName and name or ("Device " .. index)
            end
        end
    end
    if next(deviceValues) == nil then
        deviceValues[0] = LO["System Default"] or "System Default"
    end

    C:AddDropdown(hardwareSection, {
        label = LO["Game Sound Output"] or "Game Sound Output",
        desc = LO["Output device."] or "Output device.",
        values = deviceValues,
        width = 240,
        getFunc = function() return CVarNum("Sound_OutputDriverIndex", 0) end,
        setFunc = function(val) SetCVarNum("Sound_OutputDriverIndex", val) RestartSoundSystem() end,
    })

    C:AddSlider(hardwareSection, {
        label = LO["Sound Channels"] or "Sound Channels",
        desc = LO["Sound channels."] or "Sound channels.",
        min = 16, max = 128, step = 16,
        width = 200,
        getFunc = function() return CVarNum("Sound_NumChannels", 32) end,
        setFunc = function(val) SetCVarNum("Sound_NumChannels", val) RestartSoundSystem() end,
    })

    C:AddToggle(hardwareSection, {
        label = LO["Use Hardware"] or "Use Hardware",
        desc = LO["Hardware output."] or "Hardware output.",
        getFunc = function() return CVarBool("Sound_EnableHardware") end,
        setFunc = function(val) SetCVarBool("Sound_EnableHardware", val) RestartSoundSystem() end,
    })

    -- ====================================================================
    -- ENGINE EXTRAS
    -- ====================================================================
    local extraSection = C:AddSection(scroll, LO["Engine Extras"] or "Engine Extras")

    C:AddSlider(extraSection, {
        label = LO["Dialog Volume"] or "Dialog Volume",
        desc = LO["Voice and speech dialogue volume."] or "Voice and speech dialogue volume.",
        min = 0, max = 1, step = 0.05, isPercent = true,
        width = 200,
        getFunc = function() return CVarNum("Sound_DialogVolume", 1) end,
        setFunc = function(val) SetCVarNum("Sound_DialogVolume", val) end,
    })

    C:AddSlider(extraSection, {
        label = LO["DSP Buffer Size"] or "DSP Buffer Size",
        desc = LO["Processing buffer size."] or "Processing buffer size.",
        min = 0, max = 1024, step = 128,
        width = 200,
        getFunc = function() return CVarNum("Sound_DSPBufferSize", 0) end,
        setFunc = function(val) SetCVarNum("Sound_DSPBufferSize", val) RestartSoundSystem() end,
    })

    C:AddToggle(extraSection, {
        label = LO["Listener at Character"] or "Listener at Character",
        desc = LO["Listener at character."] or "Listener at character.",
        getFunc = function() return CVarBool("Sound_ListenerAtCharacter") end,
        setFunc = function(val) SetCVarBool("Sound_ListenerAtCharacter", val) end,
    })

    C:AddToggle(extraSection, {
        label = LO["Armor Foley (Self)"] or "Armor Foley (Self)",
        desc = LO["Armor sounds for your own character."] or "Armor sounds for your own character.",
        getFunc = function() return CVarBool("Sound_EnableArmorFoleySoundForSelf") end,
        setFunc = function(val) SetCVarBool("Sound_EnableArmorFoleySoundForSelf", val) end,
    })

    C:AddToggle(extraSection, {
        label = LO["Armor Foley (Others)"] or "Armor Foley (Others)",
        desc = LO["Armor sounds for other characters."] or "Armor sounds for other characters.",
        getFunc = function() return CVarBool("Sound_EnableArmorFoleySoundForOthers") end,
        setFunc = function(val) SetCVarBool("Sound_EnableArmorFoleySoundForOthers", val) end,
    })

    C:AddSlider(extraSection, {
        label = LO["Output Sample Rate"] or "Output Sample Rate",
        desc = LO["Output sample rate."] or "Output sample rate.",
        min = 11025, max = 96000, step = 11025,
        width = 200,
        getFunc = function() return CVarNum("Sound_OutputSampleRate", 44100) end,
        setFunc = function(val) SetCVarNum("Sound_OutputSampleRate", val) RestartSoundSystem() end,
    })
end

Panel:RegisterTab("audio", LO["Audio"] or "Audio", BuildAudioTab, 81)
