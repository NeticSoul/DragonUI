--[[
  DragonUI - Target Frame Module (target.lua)

  Target-specific configuration and hooks passed to the
  UF.TargetStyle closure factory defined in target_style.lua.
]]

local addon = select(2, ...)
local UF = addon.UF

-- ============================================================================
-- BLIZZARD FRAME CACHE
-- ============================================================================

local TargetFrame                      = _G.TargetFrame
local TargetFrameHealthBar             = _G.TargetFrameHealthBar
local TargetFrameManaBar               = _G.TargetFrameManaBar
local TargetFramePortrait              = _G.TargetFramePortrait
local TargetFrameTextureFrameName      = _G.TargetFrameTextureFrameName
local TargetFrameTextureFrameLevelText = _G.TargetFrameTextureFrameLevelText
local TargetFrameNameBackground        = _G.TargetFrameNameBackground

local FocusFrame = _G.FocusFrame

-- Detached ToT/FoT aura layout hook (safe: post-hook only, no ToT/FoT Hide/Show)
local MAX_TARGET_BUFFS = _G.MAX_TARGET_BUFFS or 32
local MAX_TARGET_DEBUFFS = _G.MAX_TARGET_DEBUFFS or 16
local AURA_OFFSET_Y = _G.AURA_OFFSET_Y or 3
local AURA_START_X = _G.AURA_START_X or 5
local AURA_START_Y = _G.AURA_START_Y or 32
local SMALL_AURA_SIZE = _G.SMALL_AURA_SIZE or 17
local LARGE_AURA_SIZE = _G.LARGE_AURA_SIZE or 21
local DEFAULT_AURA_ROW_WIDTH = 122

local function IsToTDetached()
    local cfg = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.tot
    return cfg and cfg.override == true
end

local function IsToFDetached()
    local cfg = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.fot
    return cfg and cfg.override == true
end

local function ShouldUseDetachedAuraLayout(frame)
    if frame == TargetFrame then
        return IsToTDetached()
    end
    if frame == FocusFrame then
        return IsToFDetached()
    end
    return false
end

local PLAYER_CAST_UNITS = { player = true, pet = true, vehicle = true }

-- Returns buffSize, debuffSize when custom sizing is active; nil when Blizzard defaults apply.
local function GetCustomAuraSizes()
    local cfg = addon.db and addon.db.profile and addon.db.profile.modules
        and addon.db.profile.modules.auracooldowns
    if not cfg or cfg.enabled ~= true or cfg.icons_enabled ~= true then
        return nil
    end

    local function Resolve(block)
        local sub = cfg[block] or {}
        local size = tonumber(sub.icon_size) or 0
        local scale = tonumber(sub.icon_scale) or 1
        if size <= 0 then
            size = SMALL_AURA_SIZE
        end
        size = math.floor(size * scale + 0.5)
        if size < 8 then
            size = 8
        end
        return size
    end

    local buffSize = Resolve("buffs")
    local debuffSize = Resolve("debuffs")
    if buffSize == SMALL_AURA_SIZE and debuffSize == SMALL_AURA_SIZE then
        return nil
    end

    return buffSize, debuffSize
end

addon.GetCustomAuraSizes = GetCustomAuraSizes

local function GetAuraCountsAndSizes(frame)
    local selfName = frame and frame.GetName and frame:GetName()
    local unit = frame and frame.unit
    if not selfName or not unit then
        return 0, 0, {}, {}
    end

    local numBuffs = 0
    local numDebuffs = 0
    local largeBuffList = {}
    local largeDebuffList = {}

    -- Large from caster (Blizzard's PLAYER_UNITS rule), not width: prior SetSize corrupts width inference.
    for i = 1, MAX_TARGET_BUFFS do
        local buff = _G[selfName .. "Buff" .. i]
        if not buff or not buff:IsShown() then
            break
        end
        numBuffs = i
        local caster = select(8, UnitBuff(unit, i))
        largeBuffList[i] = caster and PLAYER_CAST_UNITS[caster] or false
    end

    for i = 1, MAX_TARGET_DEBUFFS do
        local debuff = _G[selfName .. "Debuff" .. i]
        if not debuff or not debuff:IsShown() then
            break
        end
        numDebuffs = i
        local caster = select(8, UnitDebuff(unit, i))
        largeDebuffList[i] = caster and PLAYER_CAST_UNITS[caster] or false
    end

    return numBuffs, numDebuffs, largeBuffList, largeDebuffList
end

local function UpdateAuraPositionsDetached(self, auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc,
                                           maxRowWidth, offsetX, mirrorAurasVertically, smallSize, largeSize, extraGap)
    local size
    extraGap = extraGap or 0
    local offsetY = AURA_OFFSET_Y + extraGap
    local rowWidth = 0
    local firstAuraOnRow = 1

    for i = 1, numAuras do
        if largeAuraList[i] then
            size = largeSize
            offsetY = AURA_OFFSET_Y + AURA_OFFSET_Y + extraGap
        else
            size = smallSize
        end

        if i == 1 then
            rowWidth = size
            self.auraRows = self.auraRows + 1
        else
            rowWidth = rowWidth + size + offsetX
        end

        if rowWidth > maxRowWidth then
            updateFunc(self, auraName, i, numOppositeAuras, firstAuraOnRow, size, offsetX, offsetY, mirrorAurasVertically)
            rowWidth = size
            self.auraRows = self.auraRows + 1
            firstAuraOnRow = i
            offsetY = AURA_OFFSET_Y + extraGap
        else
            updateFunc(self, auraName, i, numOppositeAuras, i - 1, size, offsetX, offsetY, mirrorAurasVertically)
        end
    end
end

local function UpdateBuffAnchorDetached(self, buffName, index, numDebuffs, anchorIndex, size, offsetX, offsetY,
                                        mirrorVertically)
    local point, relativePoint
    local startY, auraOffsetY

    if mirrorVertically then
        point = "BOTTOM"
        relativePoint = "TOP"
        startY = -15
        offsetY = -offsetY
        auraOffsetY = -AURA_OFFSET_Y
    else
        point = "TOP"
        relativePoint = "BOTTOM"
        startY = AURA_START_Y
        auraOffsetY = AURA_OFFSET_Y
    end

    local buff = _G[buffName .. index]
    if not buff then
        return
    end

    if index == 1 then
        if UnitIsFriend("player", self.unit) or numDebuffs == 0 then
            buff:SetPoint(point .. "LEFT", self, relativePoint .. "LEFT", AURA_START_X, startY)
        else
            buff:SetPoint(point .. "LEFT", self.debuffs, relativePoint .. "LEFT", 0, -offsetY)
        end
        self.buffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
        self.buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, -auraOffsetY)
        self.spellbarAnchor = buff
    elseif anchorIndex ~= (index - 1) then
        buff:SetPoint(point .. "LEFT", _G[buffName .. anchorIndex], relativePoint .. "LEFT", 0, -offsetY)
        self.buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, -auraOffsetY)
        self.spellbarAnchor = buff
    else
        buff:SetPoint(point .. "LEFT", _G[buffName .. anchorIndex], point .. "RIGHT", offsetX, 0)
    end

    buff:SetWidth(size)
    buff:SetHeight(size)
end

local function UpdateDebuffAnchorDetached(self, debuffName, index, numBuffs, anchorIndex, size, offsetX, offsetY,
                                          mirrorVertically)
    local debuff = _G[debuffName .. index]
    local isFriend = UnitIsFriend("player", self.unit)
    local point, relativePoint
    local startY, auraOffsetY

    if mirrorVertically then
        point = "BOTTOM"
        relativePoint = "TOP"
        startY = -15
        offsetY = -offsetY
        auraOffsetY = -AURA_OFFSET_Y
    else
        point = "TOP"
        relativePoint = "BOTTOM"
        startY = AURA_START_Y
        auraOffsetY = AURA_OFFSET_Y
    end

    if not debuff then
        return
    end

    if index == 1 then
        if isFriend and numBuffs > 0 then
            debuff:SetPoint(point .. "LEFT", self.buffs, relativePoint .. "LEFT", 0, -offsetY)
        else
            debuff:SetPoint(point .. "LEFT", self, relativePoint .. "LEFT", AURA_START_X, startY)
        end
        self.debuffs:SetPoint(point .. "LEFT", debuff, point .. "LEFT", 0, 0)
        self.debuffs:SetPoint(relativePoint .. "LEFT", debuff, relativePoint .. "LEFT", 0, -auraOffsetY)
        if isFriend or (not isFriend and numBuffs == 0) then
            self.spellbarAnchor = debuff
        end
    elseif anchorIndex ~= (index - 1) then
        debuff:SetPoint(point .. "LEFT", _G[debuffName .. anchorIndex], relativePoint .. "LEFT", 0, -offsetY)
        self.debuffs:SetPoint(relativePoint .. "LEFT", debuff, relativePoint .. "LEFT", 0, -auraOffsetY)
        if isFriend or (not isFriend and numBuffs == 0) then
            self.spellbarAnchor = debuff
        end
    else
        debuff:SetPoint(point .. "LEFT", _G[debuffName .. (index - 1)], point .. "RIGHT", offsetX, 0)
    end

    debuff:SetWidth(size)
    debuff:SetHeight(size)
    local border = _G[debuffName .. index .. "Border"]
    if border then
        border:SetWidth(size + 2)
        border:SetHeight(size + 2)
    end
end

local function ApplyDragonAuraLayout(frame)
    if not frame or not frame.unit or not UnitExists(frame.unit) then
        return
    end

    local frameName = frame:GetName()
    if frameName ~= "TargetFrame" and frameName ~= "FocusFrame" then
        return
    end

    local detached = ShouldUseDetachedAuraLayout(frame)
    local buffSize, debuffSize = GetCustomAuraSizes()
    if not detached and not buffSize then
        return
    end
    buffSize = buffSize or SMALL_AURA_SIZE
    debuffSize = debuffSize or SMALL_AURA_SIZE
    local largeDelta = LARGE_AURA_SIZE - SMALL_AURA_SIZE

    local numBuffs, numDebuffs, largeBuffList, largeDebuffList = GetAuraCountsAndSizes(frame)
    if numBuffs == 0 and numDebuffs == 0 then
        return
    end

    frame.auraRows = 0
    local mirrorAurasVertically = frame.buffsOnTop and true or false
    frame.spellbarAnchor = nil

    -- Attached mode mirrors Blizzard: shrink rows beside a visible ToT, expand back after NUM_TOT_AURA_ROWS.
    local haveToT = not detached and frame.totFrame and frame.totFrame:IsShown()
    local totRowWidth = frame.TOT_AURA_ROW_WIDTH or 101
    local buffGap = addon.GetAuraChromeGap and addon.GetAuraChromeGap(buffSize + largeDelta) or 0
    local debuffGap = addon.GetAuraChromeGap and addon.GetAuraChromeGap(debuffSize + largeDelta) or 0
    local debuffOffsetX = (detached and 3 or 4) + debuffGap

    local maxRowWidth = (haveToT and totRowWidth) or DEFAULT_AURA_ROW_WIDTH
    UpdateAuraPositionsDetached(frame, frameName .. "Buff", numBuffs, numDebuffs, largeBuffList,
        UpdateBuffAnchorDetached, maxRowWidth, 3 + buffGap, mirrorAurasVertically, buffSize, buffSize + largeDelta,
        buffGap)
    maxRowWidth = (haveToT and frame.auraRows < (_G.NUM_TOT_AURA_ROWS or 2) and totRowWidth) or DEFAULT_AURA_ROW_WIDTH
    UpdateAuraPositionsDetached(frame, frameName .. "Debuff", numDebuffs, numBuffs, largeDebuffList,
        UpdateDebuffAnchorDetached, maxRowWidth, debuffOffsetX, mirrorAurasVertically, debuffSize, debuffSize + largeDelta,
        debuffGap)

    if frame.spellbar and _G.Target_Spellbar_AdjustPosition then
        _G.Target_Spellbar_AdjustPosition(frame.spellbar)
    end
end

-- Re-runs the full Blizzard update chain (layout -> our hook -> spellbar -> castbar) after config changes.
function addon.RefreshTargetFocusAuraLayout()
    if type(_G.TargetFrame_UpdateAuras) ~= "function" then
        return
    end
    if TargetFrame and UnitExists("target") then
        _G.TargetFrame_UpdateAuras(TargetFrame)
    end
    if FocusFrame and UnitExists("focus") then
        _G.TargetFrame_UpdateAuras(FocusFrame)
    end
end

local function InstallDetachedAuraLayoutHook()
    if _G.DragonUI_DetachedAuraLayoutHooked then
        return
    end
    if type(_G.TargetFrame_UpdateAuras) ~= "function" then
        return
    end

    hooksecurefunc("TargetFrame_UpdateAuras", ApplyDragonAuraLayout)

    _G.DragonUI_DetachedAuraLayoutHooked = true
end

-- ============================================================================
-- CREATE VIA FACTORY
-- ============================================================================

local api = UF.TargetStyle.Create({
    -- Identity
    configKey        = "target",
    unitToken        = "target",
    widgetKey        = "target",
    combatQueueKey   = "target_position",

    -- Blizzard frame references
    blizzFrame       = TargetFrame,
    healthBar        = TargetFrameHealthBar,
    manaBar          = TargetFrameManaBar,
    portrait         = TargetFramePortrait,
    nameText         = TargetFrameTextureFrameName,
    levelText        = TargetFrameTextureFrameLevelText,
    nameBackground   = TargetFrameNameBackground,

    -- Naming & layout
    namePrefix       = "Target",
    defaultPos       = { anchor = "TOPLEFT", posX = 250, posY = -4 },
    overlaySize      = { 200, 75 },

    -- Events
    unitChangedEvent = "PLAYER_TARGET_CHANGED",
    extraEvents      = {
        "UNIT_MODEL_CHANGED",
        "UNIT_LEVEL",
        "UNIT_NAME_UPDATE",
        "UNIT_PORTRAIT_UPDATE",
    },

    -- Feature flags
    forceLayoutOnUnitChange = true,   -- ReapplyElementPositions on every change
    hasTapDenied            = true,   -- Grey name bg for tapped-by-other targets

    -- Blizzard elements to hide
    hideListFn = function()
        return {
            _G.TargetFrameTextureFrameTexture,
            _G.TargetFrameBackground,
            _G.TargetFrameFlash,
            _G.TargetFrameNumericalThreat,
            TargetFrame.threatNumericIndicator,
            TargetFrame.threatIndicator,
            -- ToT children (visible as part of TargetFrame even if ToT module is disabled)
            _G.TargetFrameToTBackground,
            _G.TargetFrameToTTextureFrameTexture,
        }
    end,

    -- Famous NPC callback (message throttle)
    onFamousNpc = function(name, cache)
        local now = GetTime()
        if cache.lastFamousTarget ~= name
           or (now - cache.lastFamousMessage) > 5 then
            cache.lastFamousMessage = now
            cache.lastFamousTarget  = name
        end
    end,

    -- ----------------------------------------------------------------
    -- After-init hooks
    -- ----------------------------------------------------------------
    afterInit = function(ctx)
        -- Hook TargetFrame_CheckClassification for threat flash texture
        if not ctx.Module.threatHooked then
            hooksecurefunc("TargetFrame_CheckClassification",
                function(self, forceNormalTexture)
                    local threatFlash = _G.TargetFrameFlash
                    if threatFlash then
                        threatFlash:SetTexture(ctx.TEXTURES.THREAT)
                        threatFlash:SetTexCoord(0, 376/512, 0, 134/256)
                        threatFlash:SetBlendMode("ADD")
                        threatFlash:SetAlpha(0.7)
                        threatFlash:SetDrawLayer("ARTWORK", 10)
                        threatFlash:ClearAllPoints()
                        threatFlash:SetPoint("BOTTOMLEFT",
                            TargetFrame, "BOTTOMLEFT", 2, 25)
                        threatFlash:SetSize(188, 67)
                    end
                end)
            ctx.Module.threatHooked = true
        end

        -- Classification delay frame + hooks
        if not ctx.Module.classificationHooked then
            local delayFrame = CreateFrame("Frame")
            delayFrame:Hide()
            delayFrame.elapsed = 0
            delayFrame:SetScript("OnUpdate", function(self, dt)
                self.elapsed = self.elapsed + dt
                if self.elapsed >= 0.1 then
                    self:Hide()
                    if UnitExists("target") then
                        ctx.UpdateClassification()
                    end
                end
            end)

            if _G.TargetFrame_CheckClassification then
                hooksecurefunc("TargetFrame_CheckClassification",
                    function()
                        if UnitExists("target") then
                            delayFrame.elapsed = 0
                            delayFrame:Show()
                        end
                    end)
            end

            if _G.TargetFrame_Update then
                hooksecurefunc("TargetFrame_Update", function()
                    if UnitExists("target") then
                        ctx.UpdateClassification()
                    end
                end)
            end

            ctx.Module.classificationHooked = true
        end

        InstallDetachedAuraLayoutHook()
     end,

    -- ----------------------------------------------------------------
    -- Class color hooks
    -- ----------------------------------------------------------------
    setupExtraHooks = function(UpdateHealthBarColor, UpdateClassPortrait)
        if not _G.DragonUI_TargetHealthHookSetup then
            hooksecurefunc("UnitFrameHealthBar_Update",
                function(statusbar, unit)
                    if statusbar == TargetFrameHealthBar
                       and unit == "target" then
                        UpdateHealthBarColor()
                    end
                end)

            hooksecurefunc("TargetFrame_Update", function()
                if UnitExists("target") then
                    UpdateHealthBarColor()
                    UpdateClassPortrait()
                end
            end)

            -- UnitFramePortrait_Update is already hooked in SetupBarHooks

            _G.DragonUI_TargetHealthHookSetup = true
        end
    end,

    -- ----------------------------------------------------------------
    -- Extra event handler
    -- ----------------------------------------------------------------
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
})

-- ============================================================================
-- PUBLIC API
-- ============================================================================

addon.TargetFrame = {
    Refresh                  = api.Refresh,
    RefreshTargetFrame       = api.Refresh,
    Reset                    = api.Reset,
    anchor                   = api.anchor,
    ChangeTargetFrame        = api.Refresh,
    UpdateTargetHealthBarColor = function()
        if UnitExists("target") then
            api.UpdateHealthBarColor()
        end
    end,
    UpdateTargetClassPortrait = api.UpdateClassPortrait,
}

-- Legacy compatibility
addon.unitframe = addon.unitframe or {}
addon.unitframe.ChangeTargetFrame   = api.Refresh
addon.unitframe.ReApplyTargetFrame  = api.Refresh

function addon:RefreshTargetFrame()
    api.Refresh()
end
