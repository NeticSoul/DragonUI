-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local CAMERA_CVAR = "cameraDistanceMaxFactor"

local function GetConfig()
    local profile = addon.db and addon.db.profile
    return profile and profile.camera
end

-- The client saves the CVar itself, so the user's own value is kept to hand back when the option goes off.
function addon.RefreshCamera()
    local cfg = GetConfig()
    if not cfg then return end
    if cfg.max_distance then
        if not cfg.saved then
            cfg.saved = GetCVar(CAMERA_CVAR)
        end
        SetCVar(CAMERA_CVAR, tostring(cfg.factor or 3.4))
    elseif cfg.saved then
        SetCVar(CAMERA_CVAR, cfg.saved)
        cfg.saved = nil
    end
end

addon.package:Subscribe(addon.RefreshCamera, "PLAYER_LOGIN")
-- Blizzard's slider stops at 2 and writes that over the CVar when it fills in on the first PLAYER_ENTERING_WORLD.
InterfaceOptionsCameraPanelMaxDistanceSlider:HookScript("OnValueChanged", function() addon.RefreshCamera() end)
