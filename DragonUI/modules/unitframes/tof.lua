--[[
  DragonUI - Target of Focus (FoT)

  FoT-specific configuration passed to the UF.SmallFrame closure factory.
]]

local _, addon = ...
local UF = addon.UF

-- Create FoT module via shared factory
local ToFModule = UF.SmallFrame.Create({
    configKey         = "fot",
    unitToken         = "focustarget",
    parentUnit        = "focus",
    unitEvent         = "PLAYER_FOCUS_CHANGED",
    unitTargetFilters = {"focus"},
    hideWhenParentIsPlayer = true,
    namePrefix        = "ToF",
    frames = {
        main            = FocusFrameToT,
        healthBar       = FocusFrameToTHealthBar,
        manaBar         = FocusFrameToTManaBar,
        portrait        = FocusFrameToTPortrait,
        nameText        = FocusFrameToTTextureFrameName,
        blizzTexture    = FocusFrameToTTextureFrameTexture,
        blizzBackground = FocusFrameToTBackground,
        debuff1         = FocusFrameToTDebuff1,
        parent          = FocusFrame,
    },
    defaultAnchor       = "BOTTOMRIGHT",
    defaultAnchorParent = "BOTTOMRIGHT",
    defaultX            = -8,
    defaultY            = -30,
    -- No cvar for FoT (only ToT has showTargetOfTarget)
})

-- Export public API (must match names used by DragonUI_Options/unitframes.lua)
addon.TargetOfFocus = {
    Refresh = ToFModule.Refresh,
    RefreshToFFrame = ToFModule.Refresh,
    Reset = ToFModule.Reset,
    anchor = ToFModule.anchor,
    UpdateClassPortrait = ToFModule.UpdateClassPortrait,
}

function addon:RefreshToFFrame()
    ToFModule.Refresh()
end
