--[[
  DragonUI - Focus Frame Module (focus.lua)

  Focus-specific configuration and hooks passed to the
  UF.TargetStyle closure factory defined in target_style.lua.
]]

local addon = select(2, ...)
local UF = addon.UF

-- ============================================================================
-- BLIZZARD FRAME CACHE
-- ============================================================================

local FocusFrame                      = _G.FocusFrame
local FocusFrameHealthBar             = _G.FocusFrameHealthBar
local FocusFrameManaBar               = _G.FocusFrameManaBar
local FocusFramePortrait              = _G.FocusFramePortrait
local FocusFrameTextureFrameName      = _G.FocusFrameTextureFrameName
local FocusFrameTextureFrameLevelText = _G.FocusFrameTextureFrameLevelText
local FocusFrameNameBackground        = _G.FocusFrameNameBackground

local FULL_SIZE_FOCUS_FRAME_CVAR = "fullSizeFocusFrame"
local isApplyingFocusAuraSetting = false

-- Vanilla behavior: no aura expansion override

local function GetFocusConfig()
    return addon.db and addon.db.profile and addon.db.profile.unitframe
        and addon.db.profile.unitframe.focus
end

local function SyncFocusAuraSetting(smallSize)
    local config = GetFocusConfig()
    if not config then return end

    config.show_buff_debuff = (smallSize == false)
end

local function ShouldShowFocusAuras()
    local config = GetFocusConfig()
    if config and config.show_buff_debuff ~= nil then
        return config.show_buff_debuff
    end

    return GetCVarBool(FULL_SIZE_FOCUS_FRAME_CVAR) and true or false
end

local function ApplyFocusAuraSetting()
    local setSmallSize = _G.FocusFrame_SetSmallSize
    if isApplyingFocusAuraSetting or not FocusFrame or type(setSmallSize) ~= "function" then
        return
    end

    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("focus_aura_mode", ApplyFocusAuraSetting)
        end
        return
    end

    local showAuras = ShouldShowFocusAuras()
    local wantSmallSize = not showAuras
    isApplyingFocusAuraSetting = true

    if GetCVar(FULL_SIZE_FOCUS_FRAME_CVAR) ~= (showAuras and "1" or "0") then
        SetCVar(FULL_SIZE_FOCUS_FRAME_CVAR, showAuras and "1" or "0")
    end

    if FocusFrame.smallSize ~= wantSmallSize then
        setSmallSize(wantSmallSize)
    end

    if FocusFrame.UpdateAuras then
        FocusFrame:UpdateAuras()
    end

    if addon.RefreshToFFrame then
        addon:RefreshToFFrame()
    end

    isApplyingFocusAuraSetting = false
end

-- ============================================================================
-- CREATE VIA FACTORY
-- ============================================================================

local api = UF.TargetStyle.Create({
    -- Identity
    configKey        = "focus",
    unitToken        = "focus",
    widgetKey        = "focus",
    combatQueueKey   = "focus_position",

    -- Blizzard frame references
    blizzFrame       = FocusFrame,
    healthBar        = FocusFrameHealthBar,
    manaBar          = FocusFrameManaBar,
    portrait         = FocusFramePortrait,
    nameText         = FocusFrameTextureFrameName,
    levelText        = FocusFrameTextureFrameLevelText,
    nameBackground   = FocusFrameNameBackground,

    -- Naming & layout
    namePrefix       = "Focus",
    defaultPos       = { anchor = "TOPLEFT", posX = 250, posY = -170 },
    overlaySize      = { 180, 70 },

    -- Events
    unitChangedEvent = "PLAYER_FOCUS_CHANGED",
    extraEvents      = {
        "UNIT_MODEL_CHANGED",
        "UNIT_LEVEL",
        "UNIT_NAME_UPDATE",
        "UNIT_PORTRAIT_UPDATE",
    },

    -- Feature flags
    nameFrameAlpha   = 0.9,   -- SetAlpha on name background
    nameVertexAlpha  = 0.8,   -- 4th param of SetVertexColor
    nameFontSize     = 10,    -- Fixed font size for name text
    levelFontSize    = 10,    -- Fixed font size for level text

    -- Blizzard elements to hide
    hideListFn = function()
        return {
            _G.FocusFrameTextureFrameTexture,
            _G.FocusFrameBackground,
            _G.FocusFrameFlash,
            _G.FocusFrameNumericalThreat,
            FocusFrame.threatNumericIndicator,
            FocusFrame.threatIndicator,
            -- FoT children (visible as part of FocusFrame even if FoT module is disabled)
            _G.FocusFrameToTBackground,
            _G.FocusFrameToTTextureFrameTexture,
        }
    end,

    -- Extra bar hooks: force white on SetMinMaxValues
    afterBarHooks = function(Module, ManaBar, GetConfig, updateCache)
        -- FocusFrame_SetSmallSize re-runs InitializeFrame, so this must not stack.
        if ManaBar.DragonUI_MinMaxHook then return end
        hooksecurefunc(ManaBar, "SetMinMaxValues", function(self)
            if not UnitExists("focus") then return end
            local texture = self:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1, 1)
            end
        end)
        ManaBar.DragonUI_MinMaxHook = true
    end,

    extraEventHandler = function(event, unitToken, UpdateClassification,
                                  UpdateHealthBarColor, ForceUpdatePowerBar,
                                  textSystem, ...)
        local unit = ...
        if unit ~= unitToken or not UnitExists(unitToken) then return end

        if event == "UNIT_MODEL_CHANGED" then
            UpdateClassification()
            UpdateHealthBarColor()
            if textSystem then textSystem.update() end
        elseif event == "UNIT_LEVEL"
            or event == "UNIT_NAME_UPDATE" then
            UpdateClassification()
        end
    end,

    -- After-init: FocusFrame_SetSmallSize hook
    afterInit = function(ctx)
        if not ctx.Module.scaleHooked then
            hooksecurefunc("FocusFrame_SetSmallSize", function(smallSize)
                SyncFocusAuraSetting(smallSize)
                if isApplyingFocusAuraSetting then return end
                if InCombatLockdown() then return end
                local config = ctx.GetConfig()
                local correctScale = config.scale or 1
                FocusFrame:SetScale(correctScale)
                -- Force re-initialization to restore our customizations
                if ctx.Module.configured then
                    ctx.Module.configured = false
                    ctx.InitializeFrame()
                end
            end)
            ctx.Module.scaleHooked = true
        end

        ApplyFocusAuraSetting()
    end,
})

local function RefreshFocusFrame()
    ApplyFocusAuraSetting()
    api.Refresh()
end

local function ResetFocusFrame()
    api.Reset()
    ApplyFocusAuraSetting()
    api.Refresh()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

addon.FocusFrame = {
    Refresh               = RefreshFocusFrame,
    RefreshFocusFrame     = RefreshFocusFrame,
    Reset                 = ResetFocusFrame,
    anchor                 = api.anchor,
    ChangeFocusFrame       = RefreshFocusFrame,
    UpdateFocusClassPortrait = api.UpdateClassPortrait,
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeFocusFrame  = RefreshFocusFrame
addon.unitframe.ReApplyFocusFrame = RefreshFocusFrame

function addon:RefreshFocusFrame()
    RefreshFocusFrame()
end
