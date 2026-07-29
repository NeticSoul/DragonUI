--[[
  DragonUI - Target of Target (ToT)

  ToT-specific configuration passed to the UF.SmallFrame closure factory.
]]

local _, addon = ...
local UF = addon.UF

-- Create ToT module via shared factory
local ToTModule = UF.SmallFrame.Create({
    configKey         = "tot",
    unitToken         = "targettarget",
    parentUnit        = "target",
    unitEvent         = "PLAYER_TARGET_CHANGED",
    unitTargetFilters = {"target"},
    hideWhenParentIsPlayer = true,
    namePrefix        = "ToT",
    frames = {
        main            = TargetFrameToT,
        healthBar       = TargetFrameToTHealthBar,
        manaBar         = TargetFrameToTManaBar,
        portrait        = TargetFrameToTPortrait,
        nameText        = TargetFrameToTTextureFrameName,
        blizzTexture    = TargetFrameToTTextureFrameTexture,
        blizzBackground = TargetFrameToTBackground,
        debuff1         = TargetFrameToTDebuff1,
        parent          = TargetFrame,
    },
    defaultAnchor       = "BOTTOMRIGHT",
    defaultAnchorParent = "BOTTOMRIGHT",
    defaultX            = 22,
    defaultY            = -15,
    cvar                = "showTargetOfTarget",
})

-- Export public API (must match names used by DragonUI_Options/unitframes.lua)
addon.TargetOfTarget = {
    Refresh = ToTModule.Refresh,
    RefreshToTFrame = ToTModule.Refresh,
    Reset = ToTModule.Reset,
    anchor = ToTModule.anchor,
    UpdateClassPortrait = ToTModule.UpdateClassPortrait,
}

function addon:RefreshToTFrame()
    ToTModule.Refresh()
end


