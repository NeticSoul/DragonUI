local addon = select(2, ...)
local L = addon.L

-- ============================================================================
-- CASTBAR MODULE FOR DRAGONUI
-- Original code by Neticsoul
-- ============================================================================

local _G = _G
local pairs, ipairs = pairs, ipairs
local min, max, abs, floor = math.min, math.max, math.abs, math.floor
local format = string.format
local GetTime = GetTime
local UnitExists, UnitGUID = UnitExists, UnitGUID
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local GetSpellTexture, GetSpellInfo = GetSpellTexture, GetSpellInfo

-- ============================================================================
-- CONSTANTS AND TEXTURES
-- ============================================================================

local TEXTURE_PATH = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\"
local TEXTURES = {
    atlas = TEXTURE_PATH .. "uicastingbar2x",
    atlasSmall = TEXTURE_PATH .. "uicastingbar",
    standard = TEXTURE_PATH .. "CastingBarStandard2",
    channel = TEXTURE_PATH .. "CastingBarChannel",
    interrupted = TEXTURE_PATH .. "CastingBarInterrupted2",
    spark = TEXTURE_PATH .. "CastingBarSpark"
}

local UV_COORDS = {
    background = {0.0009765625, 0.4130859375, 0.3671875, 0.41796875},
    border = {0.412109375, 0.828125, 0.001953125, 0.060546875},
    flash = {0.0009765625, 0.4169921875, 0.2421875, 0.30078125},
    spark = {0.076171875, 0.0859375, 0.796875, 0.9140625},
    borderShield = {0.000976562, 0.0742188, 0.796875, 0.970703},
    textBorder = {0.001953125, 0.412109375, 0.00390625, 0.11328125}
}

-- Build CHANNEL_TICKS from spell IDs so the names are auto-localized
-- GetSpellInfo(id) returns the spell name in the client's language
local CHANNEL_TICKS_DATA = {
    -- Warlock
    { id = 1120,  ticks = 5  },  -- Drain Soul
    { id = 689,   ticks = 5  },  -- Drain Life
    { id = 5138,  ticks = 5  },  -- Drain Mana
    { id = 5740,  ticks = 4  },  -- Rain of Fire
    { id = 1949,  ticks = 15 },  -- Hellfire
    { id = 698,   ticks = 5  },  -- Ritual of Summoning
    -- Priest
    { id = 15407, ticks = 3  },  -- Mind Flay
    { id = 605,   ticks = 8  },  -- Mind Control
    { id = 47540, ticks = 2  },  -- Penance
    -- Mage
    { id = 10,    ticks = 8  },  -- Blizzard
    { id = 12051, ticks = 4  },  -- Evocation
    { id = 5143,  ticks = 5  },  -- Arcane Missiles
    -- Druid
    { id = 740,   ticks = 4  },  -- Tranquility
    { id = 16914, ticks = 10 },  -- Hurricane
}

local CHANNEL_TICKS = {}
for _, data in ipairs(CHANNEL_TICKS_DATA) do
    local name = GetSpellInfo(data.id)
    if name then
        CHANNEL_TICKS[name] = data.ticks
    end
end

local MAX_TICKS = 15

-- ============================================================================
-- LATENCY TRACKING STATE (player only, SENT → START delta)
-- ============================================================================

local latencyState = {
    sentTime = nil,        -- GetTime() at UNIT_SPELLCAST_SENT for player
    latencySeconds = 0,    -- last measured SENT→START delta
}

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local CastbarModule = {
    frames = {},
    initialized = false,
    anchor = nil,
    targetAnchor = nil,
    focusAnchor = nil,
    blizzardHidden = {},  -- Track which Blizzard castbars we've hidden
    suppressLayoutHook = false
}
addon.CastbarModule = CastbarModule

if addon.RegisterModule then
    local L = addon.L
    addon:RegisterModule("castbar", CastbarModule,
        L["Cast Bar"],
        L["Custom player, target, and focus cast bars"], {
        refresh = "RefreshCastbar",
        loadOnce = true,
        isEnabled = function()
            local cfg = addon.db and addon.db.profile and addon.db.profile.castbar
            return cfg and cfg.enabled
        end,
    })
end

-- Initialize frames for each castbar type
for _, unitType in ipairs({"player", "target", "focus"}) do
    CastbarModule.frames[unitType] = {}
end

-- ============================================================================
-- CONFIGURATION ACCESS
-- ============================================================================

local function GetConfig(unitType)
    local cfg = addon.db and addon.db.profile and addon.db.profile.castbar
    if not cfg then
        return nil
    end
    
    if unitType == "player" then
        return cfg
    end
    
    return cfg[unitType]
end

local function IsEnabled(unitType)
    local cfg = GetConfig(unitType)
    return cfg and cfg.enabled
end

local function UsesModernIconBorder(cfg)
    return addon.CreateIconFrameTexture ~= nil and not (cfg and cfg.modernIconBorder == false)
end

local function SetIconBordersShown(frames, shown, cfg)
    local icon = frames.icon
    if not icon then return end

    local modern = shown and UsesModernIconBorder(cfg)
    if icon.Border then
        if shown and not modern then icon.Border:Show() else icon.Border:Hide() end
    end
    if icon.ModernBorder then
        if modern then icon.ModernBorder:Show() else icon.ModernBorder:Hide() end
    end
end

local function GetCastbarWidgetKey(unitType)
    if unitType == "target" then
        return "targetCastbar"
    elseif unitType == "focus" then
        return "focusCastbar"
    end

    return nil
end

local function GetCastbarAnchorFrame(unitType)
    if unitType == "target" then
        return CastbarModule.targetAnchor
    elseif unitType == "focus" then
        return CastbarModule.focusAnchor
    end

    return nil
end

local function IsCastbarDetached(unitType)
    local cfg = GetConfig(unitType)
    return cfg and cfg.override == true
end

local function GetLatencyConfig()
    local cfg = addon.db and addon.db.profile and addon.db.profile.castbar
    return cfg and cfg.latency
end

local function IsCompanionDetached(unitType)
    local unitframeCfg = addon.db and addon.db.profile and addon.db.profile.unitframe
    if not unitframeCfg then
        return false
    end

    if unitType == "target" then
        return unitframeCfg.tot and unitframeCfg.tot.override == true
    elseif unitType == "focus" then
        return unitframeCfg.fot and unitframeCfg.fot.override == true
    end

    return false
end

local function ShouldApplyCompanionSpacing(unitType, hasCompanion, auraRows)
    if not hasCompanion then
        return false
    end

    -- Detached mode should not add companion spacing; use aura anchor spacing only.
    if IsCompanionDetached(unitType) then
        return false
    end

    return true
end

local function HasCompanionUnit(unitType)
    if unitType == "target" then
        if not UnitExists("target") then
            return false
        end

        -- Blizzard/DragonUI behavior: no ToT should be treated as visible when target is self.
        if UnitIsUnit and UnitIsUnit("target", "player") then
            return false
        end

        if not UnitExists("targettarget") then
            return false
        end

        return TargetFrameToT and TargetFrameToT.IsShown and TargetFrameToT:IsShown() and true or false
    elseif unitType == "focus" then
        if not UnitExists("focus") then
            return false
        end

        -- Keep attached spacing aligned with real ToF visibility when focus is self.
        if UnitIsUnit and UnitIsUnit("focus", "player") then
            return false
        end

        if not UnitExists("focustarget") then
            return false
        end

        return FocusFrameToT and FocusFrameToT.IsShown and FocusFrameToT:IsShown() and true or false
    end

    return false
end

local function GetAuraAnchor(unitFrame, buffAnchor, debuffAnchor)
    if debuffAnchor then
        return debuffAnchor, "debuff1"
    end

    if buffAnchor then
        return buffAnchor, "buff1"
    end

    local spellbarAnchor = unitFrame and unitFrame.spellbarAnchor
    if spellbarAnchor and spellbarAnchor.IsShown and spellbarAnchor:IsShown() then
        return spellbarAnchor, "spellbarAnchor"
    end

    return nil, "none"
end

local function GetAuraAnchorYOffset(cfg)
    local barHeight = (cfg and cfg.sizeY) or 16
    local extraHeight = barHeight - 13
    if extraHeight < 0 then
        extraHeight = 0
    end

    -- Blizzard's -15 offset assumes a shorter castbar; push slightly lower for taller custom bars.
    return -15 - extraHeight
end

local function GetExtraAuraRowOffset(auraRows)
    local rows = tonumber(auraRows) or 0
    if rows <= 2 then
        return 0
    end

    -- _G.SMALL_AURA_SIZE never exists (FrameXML local); honor DragonUI custom sizes when active.
    local smallSize = 17
    if addon.GetCustomAuraSizes then
        local buffSize, debuffSize = addon.GetCustomAuraSizes()
        if buffSize then
            smallSize = math.max(buffSize, debuffSize or buffSize)
        end
    end

    local rowStep = smallSize + (_G.AURA_OFFSET_Y or 3)
    return (rows - 2) * rowStep
end

-- Additive detached tuning applied after stable geometry offset.
-- Negative values reduce gap; positive values increase gap.
local DETACHED_GAP_TUNE = -6

local function GetLowestVisibleAuraBottom(unitType)
    local buffPrefix, debuffPrefix
    if unitType == "target" then
        buffPrefix = "TargetFrameBuff"
        debuffPrefix = "TargetFrameDebuff"
    elseif unitType == "focus" then
        buffPrefix = "FocusFrameBuff"
        debuffPrefix = "FocusFrameDebuff"
    else
        return nil
    end

    local lowestBottom = nil
    local function ScanAuraPrefix(prefix)
        for i = 1, 40 do
            local aura = _G[prefix .. i]
            if not aura then
                break
            end
            if aura.IsShown and aura:IsShown() then
                local auraBottom = aura:GetBottom()
                if auraBottom and (not lowestBottom or auraBottom < lowestBottom) then
                    lowestBottom = auraBottom
                end
            end
        end
    end

    ScanAuraPrefix(buffPrefix)
    ScanAuraPrefix(debuffPrefix)
    return lowestBottom
end

local function GetSpellbarToLowestAuraOffset(unitType, unitFrame)
    local spellbarAnchor = unitFrame and unitFrame.spellbarAnchor
    if not spellbarAnchor then
        return 0
    end

    local spellbarBottom = spellbarAnchor:GetBottom()
    local lowestBottom = GetLowestVisibleAuraBottom(unitType)
    if not spellbarBottom or not lowestBottom then
        return 0
    end

    local offset = spellbarBottom - lowestBottom
    if offset < 0 then
        offset = 0
    end

    return offset
end

-- 16 makes the geometric result pixel-identical to the old "-21 - extraAuraOffset" all-SMALL formula.
local COMPANION_AURA_GAP = 16

local function GetCompanionSpacingYOffset(unitType, unitFrame, extraAuraOffset)
    local frameBottom = unitFrame and unitFrame.GetBottom and unitFrame:GetBottom()
    local lowestBottom = GetLowestVisibleAuraBottom(unitType)
    if frameBottom and lowestBottom then
        local geoY = (lowestBottom - frameBottom) - COMPANION_AURA_GAP
        if geoY < -21 then
            return geoY
        end
        return -21
    end

    return -21 - extraAuraOffset
end

local function GetAuraStackGeometryOffset(unitType, unitFrame, auraAnchor, auraAnchorSource, fallbackOffset)
    if auraAnchorSource == "spellbarAnchor" then
        return 0
    end

    local offset = fallbackOffset or 0
    local spellbarAnchor = unitFrame and unitFrame.spellbarAnchor
    if not auraAnchor or not spellbarAnchor then
        return offset
    end

    local auraBottom = auraAnchor:GetBottom()
    local spellbarBottom = spellbarAnchor:GetBottom()
    if not auraBottom or not spellbarBottom then
        return offset
    end

    -- A LARGE aura later in the last row hangs below spellbarAnchor (tops align); track the true lowest icon.
    local lowestBottom = GetLowestVisibleAuraBottom(unitType)
    if lowestBottom and lowestBottom < spellbarBottom then
        spellbarBottom = lowestBottom
    end

    local geometryOffset = auraBottom - spellbarBottom

    if geometryOffset < 0 then
        geometryOffset = 0
    end

    return geometryOffset
end

local function GetTargetAuraDistanceCorrection()
    -- Default to 0 so current target spacing remains unchanged unless tuned.
    return 4
end

local function GetFocusAuraDistanceCorrection()
    -- Focus aura anchors sit slightly lower than target in Blizzard layout.
    return 4
end

local function AdjustSpellbarPositionSafely(spellbar)
    if not spellbar or CastbarModule.suppressLayoutHook then
        return
    end
    if type(Target_Spellbar_AdjustPosition) ~= "function" then
        return
    end

    CastbarModule.suppressLayoutHook = true
    pcall(Target_Spellbar_AdjustPosition, spellbar)
    CastbarModule.suppressLayoutHook = false
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetSpellIcon(spellName, texture)
    if texture and texture ~= "" then
        return texture
    end
    
    if spellName then
        local icon = GetSpellTexture(spellName)
        if icon then
            return icon
        end
        
        -- Search in spellbook
        for i = 1, 1024 do
            local name, _, icon = GetSpellInfo(i, BOOKTYPE_SPELL)
            if not name then
                break
            end
            if name == spellName and icon then
                return icon
            end
        end
    end
    
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ParseCastTimes(startTime, endTime)
    local start = (startTime or 0) / 1000
    local finish = (endTime or 0) / 1000
    local duration = finish - start
    
    -- Sanity check for duration
    if duration > 3600 or duration < 0 then
        duration = 3.0
    end
    
    return start, finish, duration
end

-- ============================================================================
-- BLIZZARD CASTBAR MANAGEMENT 
-- ============================================================================

-- Phase 2: Hidden parent frame to suppress Blizzard castbars without SetScript taint
local DragonUI_HiddenCastbarParent = CreateFrame("Frame")
DragonUI_HiddenCastbarParent:Hide()

-- Store original parents for restore
local blizzardCastbarOriginalParents = {}

local function HideBlizzardCastbar(unitType)
    -- Skip if already hidden
    if CastbarModule.blizzardHidden[unitType] then
        return
    end
    
    local frames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    }
    
    local frame = frames[unitType]
    if not frame then
        return
    end
    
    -- Phase 2: Use hidden parent pattern instead of SetScript("OnShow") to avoid taint
    -- Store original parent for restoration
    if not blizzardCastbarOriginalParents[unitType] then
        blizzardCastbarOriginalParents[unitType] = frame:GetParent()
    end
    
    -- Keep target/focus under Blizzard's parent so vanilla position logic still runs.
    -- Player castbar can still be reparented to avoid interference with the custom bar.
    if unitType == "player" and not InCombatLockdown() then
        frame:SetParent(DragonUI_HiddenCastbarParent)
    end
    
    frame:Hide()
    frame:SetAlpha(0)
    
    -- Backup: HookScript (not SetScript) for extra safety if parent gets changed
    if not frame._dragonUIHooked then
        frame:HookScript("OnShow", function(self)
            if CastbarModule.blizzardHidden[unitType] then
                self:Hide()
            end
        end)
        frame._dragonUIHooked = true
    end
    
    CastbarModule.blizzardHidden[unitType] = true
end

local function ShowBlizzardCastbar(unitType)
    CastbarModule.blizzardHidden[unitType] = false
    
    local frames = {
        player = CastingBarFrame,
        target = TargetFrameSpellBar,
        focus = FocusFrameSpellBar
    }
    
    local frame = frames[unitType]
    if not frame then
        return
    end
    
    -- Phase 2: Restore original parent for player castbar only
    if unitType == "player" and not InCombatLockdown() and blizzardCastbarOriginalParents[unitType] then
        frame:SetParent(blizzardCastbarOriginalParents[unitType])
    end
    
    frame:SetAlpha(1)
    
    -- Phase 3A: Only show frame if there's an active cast/channel
    -- Do NOT call frame:Show() unconditionally — that causes a ghost castbar
    -- when the module is disabled and no cast is in progress.
    -- Blizzard's own event system will show the frame when a cast begins.
    if unitType == "player" then
        if UnitCastingInfo("player") or UnitChannelInfo("player") then
            frame:Show()
        end
    elseif unitType == "target" then
        if UnitCastingInfo("target") or UnitChannelInfo("target") then
            frame:Show()
        end
    elseif unitType == "focus" then
        if UnitCastingInfo("focus") or UnitChannelInfo("focus") then
            frame:Show()
        end
    end
end

-- ============================================================================
-- TEXTURE LAYER MANAGEMENT 
-- ============================================================================

local function ForceStatusBarLayer(statusBar)
    if not statusBar then
        return
    end
    
    local texture = statusBar:GetStatusBarTexture()
    if texture and texture.SetDrawLayer then
        texture:SetDrawLayer('BORDER', 0)
    end
end

local function CreateTextureClipping(statusBar)
    -- Cache texture reference to avoid GetStatusBarTexture() every frame
    local cachedTexture = nil
    local lastProgress = -1
    local lastChanneling = nil
    
    statusBar.UpdateTextureClipping = function(self, progress, isChanneling)
        -- Re-fetch only if cached ref is nil (first call or after texture swap)
        if not cachedTexture then
            cachedTexture = self:GetStatusBarTexture()
        end
        if not cachedTexture then
            return
        end
        
        -- Skip if values haven't changed significantly
        if abs(progress - lastProgress) < 0.001 and isChanneling == lastChanneling then
            return
        end
        lastProgress = progress
        lastChanneling = isChanneling
        
        local clampedProgress = max(0.01, min(0.99, progress))
        
        if isChanneling then
            cachedTexture:SetTexCoord(0, clampedProgress, 0, 1)
        else
            cachedTexture:SetTexCoord(0, clampedProgress, 0, 1)
        end
    end
    
    -- Invalidate cached texture when the statusbar texture is swapped
    statusBar.InvalidateTextureCache = function(self)
        cachedTexture = nil
        lastProgress = -1
        lastChanneling = nil
    end
end

-- ============================================================================
-- FADE SYSTEM 
-- ============================================================================

local function RestoreCastbarVisibility(unitType)
    local frames = CastbarModule.frames[unitType]
    if not frames or not frames.container then
        return
    end
    
    -- Cancel any active fades and restore full visibility
    local container = frames.container
    UIFrameFadeRemoveFrame(container)
    container:SetAlpha(1.0)
    container.fadeOutEx = false
    container:Show()
    
    -- Also restore castbar itself
    if frames.castbar then
        UIFrameFadeRemoveFrame(frames.castbar)
        frames.castbar:SetAlpha(1.0)
        frames.castbar.fadeOutEx = false
    end
end

local function FadeOutCastbar(unitType, duration)
    local frames = CastbarModule.frames[unitType]
    if not frames or not frames.container then
        return
    end
    
    local container = frames.container
    if container.fadeOutEx then
        return -- Already fading
    end
    
    container.fadeOutEx = true
    UIFrameFadeOut(container, duration or 1, 1.0, 0.0, function()
        container:Hide()
        container.fadeOutEx = false
    end)
end

-- Show success flash and fade out
-- Phase 3: Persistent flash timer frames per unitType to avoid memory leak
local flashTimerFrames = {}

local function ShowSuccessFlash(unitType)
    local frames = CastbarModule.frames[unitType]
    if not frames then
        return
    end
    
    local cfg = GetConfig(unitType)
    local holdDuration = (cfg and cfg.holdTime) or 0.3
    
    -- Cancel any previous flash timer
    if frames.flashTimer then
        frames.flashTimer:SetScript("OnUpdate", nil)
        frames.flashTimer = nil
    end
    
    if frames.flash then
        frames.flash:SetAlpha(1.0)
        frames.flash:Show()
        
        -- Reuse persistent frame per unitType
        if not flashTimerFrames[unitType] then
            flashTimerFrames[unitType] = CreateFrame("Frame")
        end
        local flashFrame = flashTimerFrames[unitType]
        flashFrame.elapsed = 0
        flashFrame.unitType = unitType
        flashFrame.holdDuration = holdDuration
        flashFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= self.holdDuration then
                self:SetScript("OnUpdate", nil)
                local f = CastbarModule.frames[self.unitType]
                if f then
                    if f.flash then
                        f.flash:Hide()
                    end
                    f.flashTimer = nil
                    
                    -- Only fade if no new cast started
                    local castbar = f.castbar
                    if castbar and not (castbar.castingEx or castbar.channelingEx) then
                        FadeOutCastbar(self.unitType, 0.5)
                    end
                end
            end
        end)
        
        -- Store flash timer so we can cancel it if new cast starts
        frames.flashTimer = flashFrame
    else
        FadeOutCastbar(unitType, (cfg and cfg.holdTime) or 0.3)
    end
end

-- ============================================================================
-- CHANNEL TICKS SYSTEM
-- ============================================================================

local function CreateChannelTicks(parent, ticksTable)
    for i = 1, MAX_TICKS do
        local tick = parent:CreateTexture('Tick' .. i, 'ARTWORK', nil, 1)
        tick:SetTexture('Interface\\ChatFrame\\ChatFrameBackground')
        tick:SetVertexColor(0, 0, 0, 0.75)
        tick:SetSize(3, max(parent:GetHeight() - 2, 10))
        tick:Hide()
        ticksTable[i] = tick
    end
end

local function UpdateChannelTicks(parent, ticksTable, spellName)
    -- Hide all ticks first
    for i = 1, MAX_TICKS do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end
    
    local tickCount = CHANNEL_TICKS[spellName]
    if not tickCount or tickCount <= 1 then
        return
    end
    
    local width = parent:GetWidth()
    local height = parent:GetHeight()
    local tickDelta = width / tickCount
    
    for i = 1, min(tickCount - 1, MAX_TICKS) do
        if ticksTable[i] then
            ticksTable[i]:SetSize(3, max(height - 2, 10))
            ticksTable[i]:ClearAllPoints()
            ticksTable[i]:SetPoint('CENTER', parent, 'LEFT', i * tickDelta, 0)
            ticksTable[i]:Show()
        end
    end
end

local function HideAllTicks(ticksTable)
    for i = 1, MAX_TICKS do
        if ticksTable[i] then
            ticksTable[i]:Hide()
        end
    end
end

-- ============================================================================
-- SHIELD SYSTEM
-- ============================================================================

-- Sibling of castbar so the shield can render behind the icon.
local function CreateShield(container, castbar, icon, frameName, iconSize)
    if not container or not castbar or not icon then
        return nil
    end

    local shield = CreateFrame("Frame", frameName .. "Shield", container)
    shield:SetFrameLevel(max(0, castbar:GetFrameLevel() - 1))
    shield:SetSize(iconSize * 1.8, iconSize * 2.0)
    
    local texture = shield:CreateTexture(nil, "ARTWORK", nil, 3)
    texture:SetAllPoints(shield)
    texture:SetTexture(TEXTURES.atlas)
    texture:SetTexCoord(unpack(UV_COORDS.borderShield))
    texture:SetVertexColor(1, 1, 1, 1)
    
    shield:ClearAllPoints()
    shield:SetPoint("CENTER", icon, "CENTER", 0, -2)
    shield:Hide()
    
    return shield
end

-- ============================================================================
-- TEXT MANAGEMENT
-- ============================================================================

-- Truncate text with "..." if it exceeds maxWidth pixels (UTF-8 safe)
local function TruncateTextWithEllipsis(fontString, text, maxWidth)
    if not fontString or not text then return end
    fontString:SetText(text)
    if not maxWidth or maxWidth <= 0 then return end
    if fontString:GetStringWidth() <= maxWidth then return end
    
    local len = #text
    for i = len - 1, 1, -1 do
        -- Only cut at valid UTF-8 character boundaries:
        -- skip positions where the next byte is a continuation byte (10xxxxxx = 0x80-0xBF)
        local nextByte = strbyte(text, i + 1)
        if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then
            fontString:SetText(strsub(text, 1, i) .. "...")
            if fontString:GetStringWidth() <= maxWidth then
                return
            end
        end
    end
    fontString:SetText("...")
end

local function SetTextMode(unitType, mode)
    local frames = CastbarModule.frames[unitType]
    if not frames then
        return
    end
    
    local elements = {
        frames.castText, 
        frames.castTextCompact, 
        frames.castTextCentered, 
        frames.castTimeText,
        frames.castTimeTextCompact,
        frames.timeValue,  -- Player-specific detailed mode elements
        frames.timeMax
    }
    
    -- Hide all text elements first
    for _, element in ipairs(elements) do
        if element then
            element:Hide()
        end
    end
    
    -- Show appropriate elements based on mode
    if mode == "simple" then
        if frames.castTextCentered then
            frames.castTextCentered:Show()
        end
    else
        local cfg = GetConfig(unitType)
        local isCompact = cfg and cfg.compactLayout
        
        -- Player uses timeValue/timeMax, target/focus use castTimeText
        if unitType == "player" then
            if frames.castText then
                frames.castText:Show()
            end
            if frames.timeValue then
                frames.timeValue:Show()
            end
            if frames.timeMax then
                frames.timeMax:Show()
            end
        elseif isCompact then
            if frames.castTextCompact then
                frames.castTextCompact:Show()
            end
            if frames.castTimeTextCompact then
                frames.castTimeTextCompact:Show()
            end
        else
            if frames.castText then
                frames.castText:Show()
            end
            if frames.castTimeText then
                frames.castTimeText:Show()
            end
        end
    end
end

local function SetCastText(unitType, text)
    local cfg = GetConfig(unitType)
    if not cfg then
        return
    end
    
    local textMode = cfg.text_mode or "simple"
    SetTextMode(unitType, textMode)
    
    local frames = CastbarModule.frames[unitType]
    if not frames then
        return
    end
    
    if textMode == "simple" then
        if frames.castTextCentered then
            frames.castTextCentered:SetText(text)
        end
    else
        -- In detailed mode, truncate spell name with "..." to avoid overlapping the time display
        if unitType == "player" then
            if frames.castText and frames.textBackground then
                local bgWidth = frames.textBackground:GetWidth()
                if not bgWidth or bgWidth < 1 then bgWidth = 200 end
                local maxWidth = bgWidth - 60  -- 8 left pad + 50 right time area + 2 gap
                TruncateTextWithEllipsis(frames.castText, text, maxWidth)
            end
        else
            local bgWidth = frames.textBackground and frames.textBackground:GetWidth()
            if not bgWidth or bgWidth < 1 then bgWidth = 150 end
            local maxWidth = bgWidth - 62  -- 6 left pad + ~50 right time area + 6 right pad
            if frames.castText then
                TruncateTextWithEllipsis(frames.castText, text, maxWidth)
            end
            if frames.castTextCompact then
                TruncateTextWithEllipsis(frames.castTextCompact, text, maxWidth)
            end
        end
    end
end

local function UpdateTimeText(unitType)
    local frames = CastbarModule.frames[unitType]
    if not frames or not frames.castbar then
        return
    end
    
    local castbar = frames.castbar
    
    -- Skip if not casting/channeling
    if not castbar.castingEx and not castbar.channelingEx then
        return
    end
    
    local cfg = GetConfig(unitType)
    if not cfg then
        return
    end
    
    local seconds = 0
    local secondsMax = (castbar.endTime or 0) - (castbar.startTime or 0)
    
    local currentTime = GetTime()
    local elapsed = currentTime - (castbar.startTime or 0)
    
    -- Casts count UP (0 -> max), channels count DOWN (max -> 0)
    if castbar.channelingEx then
        seconds = max(0, secondsMax - elapsed)
    else
        seconds = min(elapsed, secondsMax)
    end
    
    local timeText = format('%.' .. (cfg.precision_time or 1) .. 'f', seconds)
    local fullText
    
    if cfg.precision_max and cfg.precision_max > 0 then
        local maxText = format('%.' .. cfg.precision_max .. 'f', secondsMax)
        fullText = timeText .. ' / ' .. maxText
    else
        fullText = timeText .. 's'
    end
    
    if unitType == "player" then
        local textMode = cfg.text_mode or "simple"
        if textMode ~= "simple" and frames.timeValue and frames.timeMax then
            frames.timeValue:SetText(timeText)
            frames.timeMax:SetText(' / ' .. format('%.' .. (cfg.precision_max or 1) .. 'f', secondsMax))
        end
    else
        if frames.castTimeText then
            frames.castTimeText:SetText(fullText)
        end
        if frames.castTimeTextCompact then
            frames.castTimeTextCompact:SetText(fullText)
        end
    end
end

-- ============================================================================
-- CASTBAR CREATION
-- ============================================================================

local function CreateCastbar(unitType)
    if CastbarModule.frames[unitType].castbar then
        return
    end
    
    local frameName = 'DragonUI' .. unitType:sub(1, 1):upper() .. unitType:sub(2) .. 'Castbar'
    local frames = CastbarModule.frames[unitType]
    
    -- Create unified container frame
    frames.container = CreateFrame('Frame', frameName .. 'Container', UIParent)
    frames.container:SetFrameStrata("MEDIUM")
    frames.container:SetFrameLevel(10)
    frames.container:SetSize(256, 16)
    frames.container:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    frames.container:Hide()
    
    -- Main StatusBar
    frames.castbar = CreateFrame('StatusBar', frameName, frames.container)
    frames.castbar:SetFrameLevel(2)
    frames.castbar:SetAllPoints(frames.container)
    frames.castbar:SetMinMaxValues(0, 1)
    frames.castbar:SetValue(0)
    
    -- State flags
    frames.castbar.castingEx = false
    frames.castbar.channelingEx = false
    frames.castbar.fadeOutEx = false
    frames.castbar.selfInterrupt = false
    
    -- Background
    local bg = frames.castbar:CreateTexture(nil, 'BACKGROUND')
    bg:SetTexture(TEXTURES.atlas)
    bg:SetTexCoord(unpack(UV_COORDS.background))
    bg:SetAllPoints()
    
    -- StatusBar texture
    frames.castbar:SetStatusBarTexture(TEXTURES.standard)
    local texture = frames.castbar:GetStatusBarTexture()
    if texture then
        texture:SetVertexColor(1, 1, 1, 1)
    end
    frames.castbar:SetStatusBarColor(1, 0.7, 0, 1)
    
    -- Border
    local border = frames.castbar:CreateTexture(nil, 'ARTWORK', nil, 0)
    border:SetTexture(TEXTURES.atlas)
    border:SetTexCoord(unpack(UV_COORDS.border))
    border:SetPoint("TOPLEFT", frames.castbar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", frames.castbar, "BOTTOMRIGHT", 2, -2)
    
    -- Channel ticks
    frames.ticks = {}
    CreateChannelTicks(frames.castbar, frames.ticks)
    
    -- Flash
    frames.flash = frames.castbar:CreateTexture(nil, 'OVERLAY')
    frames.flash:SetTexture(TEXTURES.atlas)
    frames.flash:SetTexCoord(unpack(UV_COORDS.flash))
    frames.flash:SetBlendMode('ADD')
    frames.flash:SetAllPoints()
    frames.flash:Hide()
    
    -- Text background frame
    frames.textBackground = CreateFrame('Frame', frameName .. 'TextBG', frames.container)
    frames.textBackground:SetFrameLevel(1)
    
    local textBg = frames.textBackground:CreateTexture(nil, 'BACKGROUND')
    if unitType == "player" then
        textBg:SetTexture(TEXTURES.atlas)
        textBg:SetTexCoord(0.001953125, 0.410109375, 0.00390625, 0.11328125)
    else
        textBg:SetTexture(TEXTURES.atlasSmall)
        textBg:SetTexCoord(unpack(UV_COORDS.textBorder))
    end
    textBg:SetAllPoints()
    
    -- Create text elements
    if unitType == "player" then
        frames.castText = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        frames.castText:SetPoint('BOTTOMLEFT', frames.textBackground, 'BOTTOMLEFT', 8, 3)
        frames.castText:SetJustifyH("LEFT")
        frames.castText:Hide()
        
        frames.castTextCentered = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        frames.castTextCentered:SetPoint('BOTTOM', frames.textBackground, 'BOTTOM', 0, 2)
        frames.castTextCentered:SetPoint('LEFT', frames.textBackground, 'LEFT', 8, 0)
        frames.castTextCentered:SetPoint('RIGHT', frames.textBackground, 'RIGHT', -8, 0)
        frames.castTextCentered:SetJustifyH("CENTER")
        frames.castTextCentered:Hide()
        
        frames.timeValue = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        frames.timeValue:SetPoint('BOTTOMRIGHT', frames.textBackground, 'BOTTOMRIGHT', -50, 3)
        frames.timeValue:SetJustifyH("RIGHT")
        frames.timeValue:Hide()
        
        frames.timeMax = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        frames.timeMax:SetPoint('LEFT', frames.timeValue, 'RIGHT', 2, 0)
        frames.timeMax:SetJustifyH("LEFT")
        frames.timeMax:Hide()
    else
        frames.castText = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        frames.castText:SetPoint('BOTTOMLEFT', frames.textBackground, 'BOTTOMLEFT', 6, 3)
        frames.castText:SetJustifyH("LEFT")
        frames.castText:Hide()
        
        frames.castTextCentered = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        frames.castTextCentered:SetPoint('BOTTOM', frames.textBackground, 'BOTTOM', 0, 2)
        frames.castTextCentered:SetPoint('LEFT', frames.textBackground, 'LEFT', 6, 0)
        frames.castTextCentered:SetPoint('RIGHT', frames.textBackground, 'RIGHT', -6, 0)
        frames.castTextCentered:SetJustifyH("CENTER")
        frames.castTextCentered:Hide()
        
        frames.castTextCompact = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        frames.castTextCompact:SetPoint('BOTTOMLEFT', frames.textBackground, 'BOTTOMLEFT', 6, 3)
        frames.castTextCompact:SetJustifyH("LEFT")
        frames.castTextCompact:Hide()
        
        frames.castTimeText = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        frames.castTimeText:SetPoint('BOTTOMRIGHT', frames.textBackground, 'BOTTOMRIGHT', -6, 3)
        frames.castTimeText:SetJustifyH("RIGHT")
        frames.castTimeText:Hide()
        
        frames.castTimeTextCompact = frames.textBackground:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        frames.castTimeTextCompact:SetPoint('BOTTOMRIGHT', frames.textBackground, 'BOTTOMRIGHT', -6, 3)
        frames.castTimeTextCompact:SetJustifyH("RIGHT")
        frames.castTimeTextCompact:Hide()
    end
    
    -- Background frame
    if unitType ~= "player" then
        frames.background = CreateFrame('Frame', frameName .. 'Background', frames.container)
        frames.background:SetFrameLevel(0)
        frames.background:SetAllPoints(frames.castbar)
    else
        frames.background = frames.textBackground
    end
    
    -- Spark
    frames.spark = CreateFrame("Frame", frameName .. "Spark", frames.container)
    frames.spark:SetFrameLevel(5)
    frames.spark:SetSize(16, 16)
    frames.spark:Hide()
    
    local sparkTexture = frames.spark:CreateTexture(nil, 'OVERLAY')
    sparkTexture:SetTexture(TEXTURES.spark)
    sparkTexture:SetAllPoints()
    sparkTexture:SetBlendMode('ADD')
    
    -- Icon
    frames.icon = frames.castbar:CreateTexture(frameName .. "Icon", 'ARTWORK')
    frames.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frames.icon:Hide()
    
    -- Icon border
    local iconBorder = frames.castbar:CreateTexture(nil, 'ARTWORK')
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    iconBorder:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    iconBorder:SetVertexColor(0.8, 0.8, 0.8, 1)
    iconBorder:Hide()
    frames.icon.Border = iconBorder

    if addon.CreateIconFrameTexture then
        frames.icon.ModernBorder = addon.CreateIconFrameTexture(frames.castbar, 'OVERLAY')
    end
    
    -- Shield (for target/focus only — player casts are always interruptible in 3.3.5a)
    if unitType ~= "player" then
        frames.shield = CreateShield(frames.container, frames.castbar, frames.icon, frameName, 20)
    end
    
    -- Apply texture clipping system
    CreateTextureClipping(frames.castbar)
    
    -- ================================================================
    -- LATENCY INDICATOR VISUAL (player only — classic Quartz-style)
    -- ================================================================
    if unitType == "player" then
        local latOverlay = frames.castbar:CreateTexture(nil, 'ARTWORK', nil, 2)
        latOverlay:SetTexture(TEXTURES.standard)
        latOverlay:SetBlendMode('ADD')
        latOverlay:SetVertexColor(0.9, 0.5, 0.2, 0.45)
        latOverlay:Hide()
        frames.latencyOverlay = latOverlay
    end

    -- OnUpdate handler 
    frames.castbar:SetScript('OnUpdate', function(self, elapsed)
        CastbarModule:OnUpdate(unitType, self, elapsed)
    end)

    -- Notify dark mode to re-darken borders on this new castbar
    if addon.RefreshDarkModeCastbars then
        addon.RefreshDarkModeCastbars()
    end
end

-- ============================================================================
-- LATENCY INDICATOR — SHOW / HIDE / UPDATE
-- ============================================================================

local MAX_LATENCY_RATIO = 0.4  -- never show more than 40% of the bar

local function HideLatencyIndicator()
    local frames = CastbarModule.frames.player
    if not frames then return end
    if frames.latencyOverlay then frames.latencyOverlay:Hide() end
end

local function ShowLatencyIndicator(castDuration)
    local frames = CastbarModule.frames.player
    if not frames or not frames.castbar then return end

    local lcfg = GetLatencyConfig()
    if not lcfg or not lcfg.enabled then
        HideLatencyIndicator()
        return
    end

    local latency = latencyState.latencySeconds
    if not latency or latency <= 0 then
        HideLatencyIndicator()
        return
    end

    local barWidth = frames.castbar:GetWidth()
    local barHeight = frames.castbar:GetHeight()
    if barWidth <= 0 or castDuration <= 0 then
        HideLatencyIndicator()
        return
    end

    -- Clamp ratio to avoid absurd visuals from lag spikes
    local ratio = min(latency / castDuration, MAX_LATENCY_RATIO)
    local pxWidth = max(1, barWidth * ratio)

    local overlay = frames.latencyOverlay
    if overlay then
        local c = lcfg.color or { r = 0.9, g = 0.5, b = 0.2 }
        local a = lcfg.alpha or 0.45
        overlay:SetVertexColor(c.r or 0.9, c.g or 0.5, c.b or 0.2, a)
        overlay:ClearAllPoints()
        overlay:SetPoint("RIGHT", frames.castbar, "RIGHT", 0, 0)
        overlay:SetSize(pxWidth, barHeight)
        -- Crop TexCoord so the texture gradient matches bar position
        local leftUV = 1 - ratio
        overlay:SetTexCoord(leftUV, 1, 0, 1)
        overlay:Show()
    end
end

-- ============================================================================
-- CASTING EVENT HANDLERS
-- ============================================================================

function CastbarModule:HandleCastStart_Simple(unitType, unit, isChanneling)
    local spell, icon, startTime, endTime, notInterruptible, castID

    if isChanneling then
        spell, _, _, icon, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
        castID = nil -- UnitChannelInfo has no castID in 3.3.5a
    else
        spell, _, _, icon, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
    end
    
    if not spell then
        return
    end
    
    self:RefreshCastbar(unitType)
    
    local frames = self.frames[unitType]
    local castbar = frames.castbar
    
    -- Set GUID for target/focus verification
    if unitType == "target" or unitType == "focus" then
        castbar.unit = UnitGUID(unit)
    end
    
    local start, finish, duration = ParseCastTimes(startTime, endTime)
    
    -- Store cast info for event matching
    castbar.startTime = start
    castbar.endTime = finish
    castbar.spellName = spell
    castbar.castID = castID -- match FAILED/INTERRUPTED like CastingBarFrame (nil for channels)

    -- Cancel any active fade
    castbar.fadeOutEx = false
    if frames.container then
        frames.container.fadeOutEx = false
    end
    
    -- Cancel any active flash timer that might trigger fade later
    if frames.flashTimer then
        frames.flashTimer:SetScript("OnUpdate", nil)
        frames.flashTimer = nil
    end
    
    -- Always use 0-1 range
    castbar:SetMinMaxValues(0, 1)
    
    if isChanneling then
        castbar:SetValue(1.0)
        castbar.channelingEx = true
        castbar.castingEx = false
        if castbar.UpdateTextureClipping then
            castbar:UpdateTextureClipping(1.0, true)
        end
    else
        castbar:SetValue(0.0)
        castbar.castingEx = true
        castbar.channelingEx = false
        if castbar.UpdateTextureClipping then
            castbar:UpdateTextureClipping(0.0, false)
        end
    end
    
    HideAllTicks(frames.ticks)
    
    -- Invalidate texture cache before swapping texture
    if frames.castbar.InvalidateTextureCache then
        frames.castbar:InvalidateTextureCache()
    end
    
    -- Set texture based on type BEFORE making the bar visible
    -- to prevent a one-frame flash with stale colors on the first cast
    if isChanneling then
        frames.castbar:SetStatusBarTexture(TEXTURES.channel)
        frames.castbar:SetStatusBarColor(unitType == "player" and 0 or 1, 1, unitType == "player" and 1 or 1, 1)
        UpdateChannelTicks(frames.castbar, frames.ticks, spell)
        local texture = frames.castbar:GetStatusBarTexture()
        if texture then
            texture:SetVertexColor(1, 1, 1, 1)
        end
    else
        frames.castbar:SetStatusBarTexture(TEXTURES.standard)
        frames.castbar:SetStatusBarColor(1, 0.7, 0, 1)
        local texture = frames.castbar:GetStatusBarTexture()
        if texture then
            texture:SetVertexColor(1, 1, 1, 1)
        end
    end
    
    ForceStatusBarLayer(frames.castbar)
    
    RestoreCastbarVisibility(unitType)

    -- LATENCY: measure SENT→START delta and show indicator (player normal casts only)
    if unitType == "player" and not isChanneling then
        if latencyState.sentTime then
            latencyState.latencySeconds = GetTime() - latencyState.sentTime
            latencyState.sentTime = nil  -- consumed
        end
        ShowLatencyIndicator(duration)
    elseif unitType == "player" and isChanneling then
        -- First version: hide latency for channels to avoid artifacts
        HideLatencyIndicator()
    end
    
    if frames.background and frames.background ~= frames.textBackground then
        frames.background:Show()
    end
    
    if frames.spark then
        frames.spark:Show()
    end
    if frames.flash then
        frames.flash:Hide()
    end
    
    SetCastText(unitType, spell)
    
    -- Non-interruptible visuals (target/focus only — player casts are always interruptible in 3.3.5a)
    if unitType ~= "player" then
        castbar.notInterruptible = notInterruptible and true or false
        local sbTexture = frames.castbar:GetStatusBarTexture()
        if sbTexture and sbTexture.SetDesaturated then
            sbTexture:SetDesaturated(castbar.notInterruptible)
        end
        if frames.shield then
            if castbar.notInterruptible then
                frames.shield:Show()
            else
                frames.shield:Hide()
            end
        end
    else
        castbar.notInterruptible = false
    end
    
    -- Configure icon
    local cfg = GetConfig(unitType)
    if frames.icon and cfg and cfg.showIcon then
        frames.icon:SetTexture(GetSpellIcon(spell, icon))
        frames.icon:Show()
        SetIconBordersShown(frames, true, cfg)
    else
        if frames.icon then
            frames.icon:Hide()
        end
        SetIconBordersShown(frames, false, cfg)
        -- Hide shield when icon is hidden (shield anchors to icon)
        if frames.shield then
            frames.shield:Hide()
        end
    end
    
    if frames.textBackground then
        frames.textBackground:Show()
        frames.textBackground:ClearAllPoints()
        frames.textBackground:SetSize(frames.castbar:GetWidth(), unitType == "player" and 22 or 20)
        frames.textBackground:SetPoint("TOP", frames.castbar, "BOTTOM", 0, unitType == "player" and 6 or 8)
    end
end

function CastbarModule:HandleCastStop_Simple(unitType, wasInterrupted, isChannelStop, overrideText)
    local frames = self.frames[unitType]
    local castbar = frames.castbar
    
    -- GUID verification for target/focus
    if unitType == "target" then
        if castbar.unit ~= UnitGUID("target") then
            return
        end
    elseif unitType == "focus" then
        if castbar.unit ~= UnitGUID("focus") then
            return
        end
    end
    
    if not (castbar.castingEx or castbar.channelingEx) then
        return  -- Already handled by FAILED/INTERRUPTED event that fired before STOP
    end
    
    local cfg = GetConfig(unitType)
    if not cfg then
        return
    end
    
    -- For normal completions (not interrupts), verify no new cast started before clearing flags
    if not wasInterrupted then
        local unit = unitType == "player" and "player" or unitType
        local stillCasting = UnitCastingInfo(unit)
        local stillChanneling = UnitChannelInfo(unit)
        
        if stillCasting or stillChanneling then
            -- New cast already started, don't clear flags or fade
            return
        end
    end
    
    -- Clear casting/channeling flags
    castbar.castingEx = false
    castbar.channelingEx = false
    -- Keep notInterruptible and desaturation alive through flash+fade;
    -- they are reset by HandleCastStart_Simple (new cast) or HideCastbar (cleanup).

    -- Hide latency indicator on cast end (player only)
    if unitType == "player" then
        HideLatencyIndicator()
    end

    -- Timing heuristic for non-player, non-self target/focus:
    -- As a fallback for cases where FAILED/INTERRUPTED events don't fire,
    -- detect early-ending casts and treat them as interrupted.
    -- Skipped for self-targets (INTERRUPTED fires reliably when target=player)
    -- and /stopcasting (should show success).
    castbar.selfInterrupt = false
    if not wasInterrupted and not isChannelStop and unitType ~= "player" then
        local isTargetingSelf = UnitIsUnit(unitType, "player")
        if not isTargetingSelf then
            local endedEarly = GetTime() < (castbar.endTime or 0) - 0.4
            if endedEarly then
                castbar.selfInterrupt = true
            end
        end
    end

    if wasInterrupted or castbar.selfInterrupt then
        -- Show interrupted/failed state
        if frames.spark then frames.spark:Hide() end
        if frames.flash then frames.flash:Hide() end
        HideAllTicks(frames.ticks)
        
        if castbar.InvalidateTextureCache then
            castbar:InvalidateTextureCache()
        end
        castbar:SetStatusBarTexture(TEXTURES.interrupted)
        castbar:SetStatusBarColor(1, 0, 0, 1)
        castbar:SetValue(1.0)
        local texture = castbar:GetStatusBarTexture()
        if texture then
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetVertexColor(1, 1, 1, 1)
        end
        
        -- Text display:
        --   INTERRUPTED event → "Interrupted" (player or target/focus)
        --   FAILED event (via overrideText) → "Failed"
        --   Timing heuristic (selfInterrupt) → "Failed" (non-self target only)
        local displayText = overrideText
        if not displayText then
            if castbar.selfInterrupt then
                -- Timing heuristic path: non-self target, always "Failed"
                displayText = FAILED
            else
                -- Event-driven path: INTERRUPTED event → "Interrupted"
                displayText = INTERRUPTED
            end
        end
        SetCastText(unitType, displayText)
        FadeOutCastbar(unitType, (cfg and cfg.holdTimeInterrupt) or 0.8)
    else
        -- Normal completion - show success flash
        if frames.spark then frames.spark:Hide() end
        HideAllTicks(frames.ticks)
        
        -- Force bar to 100% fill before flash
        castbar:SetValue(1.0)
        if castbar.InvalidateTextureCache then
            castbar:InvalidateTextureCache()
        end
        local texture = castbar:GetStatusBarTexture()
        if texture then
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetVertexColor(1, 1, 1, 1)
        end
        
        ShowSuccessFlash(unitType)
    end
end

function CastbarModule:HandleCastFailed_Simple(unitType, eventSpell, _, eventCastID)
    local frames = self.frames[unitType]
    if not frames or not frames.castbar then return end
    local castbar = frames.castbar
    if not (castbar.castingEx or castbar.channelingEx) then return end

    local unit = (unitType == "player") and "player" or unitType

    -- Ignore FAILED spam from re-pressing the same channel while it is still active.
    if castbar.channelingEx then
        local activeChannelSpell = UnitChannelInfo(unit)
        if activeChannelSpell and castbar.spellName and activeChannelSpell == castbar.spellName then
            return
        end
    end

    -- Same-name re-press / other macro spells differ by castID; channels fall back to name.
    if castbar.castID then
        if eventCastID ~= castbar.castID then
            return
        end
    elseif eventSpell and castbar.spellName and eventSpell ~= castbar.spellName then
        return
    end

    self:HandleCastStop_Simple(unitType, true, nil, FAILED)
end

-- INTERRUPTED used to kill any active bar; gate on castID (or spell name for channels).
function CastbarModule:HandleCastInterrupted_Simple(unitType, isChannel, eventSpell, _, eventCastID)
    local frames = self.frames[unitType]
    if not frames or not frames.castbar then return end
    local castbar = frames.castbar
    if not (castbar.castingEx or castbar.channelingEx) then return end

    if castbar.castID then
        if eventCastID ~= castbar.castID then
            return
        end
    elseif eventSpell and castbar.spellName and eventSpell ~= castbar.spellName then
        return
    end

    self:HandleCastStop_Simple(unitType, true, isChannel)
end

function CastbarModule:HandleCastDelayed_Simple(unitType, unit)
    local frames = self.frames[unitType]
    local castbar = frames.castbar
    
    if not castbar or not (castbar.castingEx or castbar.channelingEx) then
        return
    end
    
    local spell, startTime, endTime
    
    if castbar.castingEx then
        spell, _, _, _, startTime, endTime = UnitCastingInfo(unit)
    else
        spell, _, _, _, startTime, endTime = UnitChannelInfo(unit)
    end
    
    if not spell then
        self:HideCastbar(unitType)
        return
    end
    
    local start = startTime / 1000
    local finish = endTime / 1000
    
    castbar.startTime = start
    castbar.endTime = finish
end

-- ============================================================================
-- UPDATE HANDLER 
-- ============================================================================

function CastbarModule:OnUpdate(unitType, castbar, elapsed)
    -- Early exit if not casting/channeling
    if not castbar.castingEx and not castbar.channelingEx then
        return
    end
    
    local frames = self.frames[unitType]
    if not frames then
        return
    end
    
    local cfg = GetConfig(unitType)
    if not cfg or not cfg.enabled then
        return
    end
    
    local currentTime = GetTime()
    local value = 0
    
    if castbar.castingEx then
        local remainingTime = min(currentTime, castbar.endTime) - castbar.startTime
        value = remainingTime / (castbar.endTime - castbar.startTime)
    elseif castbar.channelingEx then
        local remainingTime = castbar.endTime - currentTime
        value = remainingTime / (castbar.endTime - castbar.startTime)
    end
    
    castbar:SetValue(value)
    
    -- Apply texture clipping
    if castbar.UpdateTextureClipping then
        castbar:UpdateTextureClipping(value, castbar.channelingEx)
    end
    
    if currentTime > castbar.endTime then
        -- Cast/channel completed - show flash
        -- BUT: Don't fade if a new cast already started (ability spam scenario)
        if castbar.castingEx or castbar.channelingEx then
            -- Verify the cast info is actually gone before fading
            local stillCasting = UnitCastingInfo(unitType == "player" and "player" or unitType)
            local stillChanneling = UnitChannelInfo(unitType == "player" and "player" or unitType)
            
            if not stillCasting and not stillChanneling then
                -- No new cast started, safe to fade
                castbar.castingEx = false
                castbar.channelingEx = false
                if unitType == "player" then HideLatencyIndicator() end
                ShowSuccessFlash(unitType)
            end
            -- If new cast started, flags stay true and we skip fadeout
        end
        return
    end
    
    -- Update spark position
    if frames.spark and frames.spark:IsShown() then
        frames.spark:ClearAllPoints()
        frames.spark:SetPoint('CENTER', castbar, 'LEFT', value * castbar:GetWidth(), 0)
    end
    
    UpdateTimeText(unitType)
end

-- ============================================================================
-- CASTBAR REFRESH
-- ============================================================================

function CastbarModule:RefreshCastbar(unitType)
    local cfg = GetConfig(unitType)
    if not cfg then
        return
    end
    
    if cfg.enabled then
        HideBlizzardCastbar(unitType)
    else
        ShowBlizzardCastbar(unitType)
        self:HideCastbar(unitType)
        return
    end
    
    if not self.frames[unitType].castbar then
        CreateCastbar(unitType)
    end
    
    local frames = self.frames[unitType]
    
    -- Calculate positioning
    local anchorFrame = UIParent
    local anchorPoint = "CENTER"
    local relativePoint = "BOTTOM"
    local xPos = cfg.x_position or 0
    local yPos = cfg.y_position or 200
    
    if unitType == "player" then
        if self.anchor then
            anchorFrame = self.anchor
            anchorPoint = "CENTER"
            relativePoint = "CENTER"
            xPos = 0
            yPos = 0
        else
            anchorFrame = UIParent
            anchorPoint = "BOTTOM"
            relativePoint = "BOTTOM"
        end
    elseif unitType == "target" then
        if IsCastbarDetached("target") and self.targetAnchor then
            anchorFrame = self.targetAnchor
            anchorPoint = "CENTER"
            relativePoint = "CENTER"
            xPos = 0
            yPos = 0
        else
            local blizzSpellBar = TargetFrameSpellBar
            local hasUnit = UnitExists("target")
            local hasCompanion = HasCompanionUnit("target")
            local isDetached = IsCompanionDetached("target")
            local auraRows = hasUnit and ((TargetFrame and TargetFrame.auraRows) or 0) or 0
            local extraAuraOffset = GetExtraAuraRowOffset(auraRows)
            local useCompanionSpacing = ShouldApplyCompanionSpacing("target", hasCompanion, auraRows)
            local buffAnchor = hasUnit and TargetFrameBuff1 and TargetFrameBuff1:IsShown() and TargetFrameBuff1 or nil
            local debuffAnchor = hasUnit and TargetFrameDebuff1 and TargetFrameDebuff1:IsShown() and TargetFrameDebuff1 or nil
            local auraAnchor, auraAnchorSource = nil, "none"
            if hasUnit then
                auraAnchor, auraAnchorSource = GetAuraAnchor(TargetFrame, buffAnchor, debuffAnchor)
            end
            local fallbackAuraOffset = (auraAnchorSource == "spellbarAnchor") and 0 or extraAuraOffset
            local auraAnchorOffset = GetAuraStackGeometryOffset("target", TargetFrame, auraAnchor, auraAnchorSource, fallbackAuraOffset)
            local detachedStableOffset = 0
            if isDetached then
                detachedStableOffset = GetSpellbarToLowestAuraOffset("target", TargetFrame) + DETACHED_GAP_TUNE
                auraAnchorOffset = detachedStableOffset
            end

            AdjustSpellbarPositionSafely(blizzSpellBar)
            local spellPoint, spellRel, spellRelPoint, spellX, spellY = nil, nil, nil, 0, 0
            if blizzSpellBar then
                spellPoint, spellRel, spellRelPoint, spellX, spellY = blizzSpellBar:GetPoint(1)
            end

            -- Use deterministic anchors to avoid stale Blizzard spellbar offsets after clear-target paths.
            if useCompanionSpacing and TargetFrame then
                anchorFrame = TargetFrame
                anchorPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xPos = 25
                yPos = GetCompanionSpacingYOffset("target", TargetFrame, extraAuraOffset)
            elseif auraAnchor then
                anchorFrame = (isDetached and TargetFrame and TargetFrame.spellbarAnchor) and TargetFrame.spellbarAnchor or auraAnchor
                anchorPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xPos = 20
                yPos = GetAuraAnchorYOffset(cfg) - auraAnchorOffset
            else
                anchorFrame = TargetFrame or blizzSpellBar or UIParent
                anchorPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xPos = 25
                yPos = 7
            end

            local targetDistanceCorrection = isDetached and 0 or GetTargetAuraDistanceCorrection()
            yPos = yPos + targetDistanceCorrection

            if addon and addon.debugMode then
                local relName = "nil"
                if spellRel and spellRel.GetName then
                    relName = spellRel:GetName() or "unnamed"
                end
                local anchorName = (anchorFrame and anchorFrame.GetName and anchorFrame:GetName()) or "unnamed"
                addon:Debug(
                    "CastbarLayout",
                    "target",
                    "companionShown=" .. tostring(hasCompanion and 1 or 0),
                    "companionSpacing=" .. tostring(useCompanionSpacing and 1 or 0),
                    "auraRows=" .. tostring(auraRows),
                    "extraAuraOffset=" .. tostring(extraAuraOffset),
                    "auraAnchorOffset=" .. tostring(auraAnchorOffset),
                    "detachedStableOffset=" .. tostring(detachedStableOffset),
                    "targetCorrection=" .. tostring(targetDistanceCorrection),
                    "auraAnchorSource=" .. tostring(auraAnchorSource),
                    "spellbarRel=" .. relName,
                    "anchor=" .. tostring(anchorName),
                    "spellPoint=" .. tostring(spellPoint or "nil"),
                    "spellRelPoint=" .. tostring(spellRelPoint or "nil"),
                    "spellX=" .. tostring(spellX or 0),
                    "spellY=" .. tostring(spellY or 0),
                    "x=" .. tostring(xPos),
                    "y=" .. tostring(yPos)
                )
            end
        end
    elseif unitType == "focus" then
        if IsCastbarDetached("focus") and self.focusAnchor then
            anchorFrame = self.focusAnchor
            anchorPoint = "CENTER"
            relativePoint = "CENTER"
            xPos = 0
            yPos = 0
        else
            local blizzSpellBar = FocusFrameSpellBar
            local hasUnit = UnitExists("focus")
            local hasCompanion = HasCompanionUnit("focus")
            local isDetached = IsCompanionDetached("focus")
            local auraRows = hasUnit and ((FocusFrame and FocusFrame.auraRows) or 0) or 0
            local extraAuraOffset = GetExtraAuraRowOffset(auraRows)
            local useCompanionSpacing = ShouldApplyCompanionSpacing("focus", hasCompanion, auraRows)
            local buffAnchor = hasUnit and FocusFrameBuff1 and FocusFrameBuff1:IsShown() and FocusFrameBuff1 or nil
            local debuffAnchor = hasUnit and FocusFrameDebuff1 and FocusFrameDebuff1:IsShown() and FocusFrameDebuff1 or nil
            local auraAnchor, auraAnchorSource = nil, "none"
            if hasUnit then
                auraAnchor, auraAnchorSource = GetAuraAnchor(FocusFrame, buffAnchor, debuffAnchor)
            end
            local fallbackAuraOffset = (auraAnchorSource == "spellbarAnchor") and 0 or extraAuraOffset
            local auraAnchorOffset = GetAuraStackGeometryOffset("focus", FocusFrame, auraAnchor, auraAnchorSource, fallbackAuraOffset)
            local detachedStableOffset = 0
            if isDetached then
                detachedStableOffset = GetSpellbarToLowestAuraOffset("focus", FocusFrame) + DETACHED_GAP_TUNE
                auraAnchorOffset = detachedStableOffset
            end

            AdjustSpellbarPositionSafely(blizzSpellBar)
            local spellPoint, spellRel, spellRelPoint, spellX, spellY = nil, nil, nil, 0, 0
            if blizzSpellBar then
                spellPoint, spellRel, spellRelPoint, spellX, spellY = blizzSpellBar:GetPoint(1)
            end

            if useCompanionSpacing and FocusFrame then
                anchorFrame = FocusFrame
                anchorPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xPos = 25
                yPos = GetCompanionSpacingYOffset("focus", FocusFrame, extraAuraOffset)
            elseif auraAnchor then
                anchorFrame = (isDetached and FocusFrame and FocusFrame.spellbarAnchor) and FocusFrame.spellbarAnchor or auraAnchor
                anchorPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xPos = 20
                yPos = GetAuraAnchorYOffset(cfg) - auraAnchorOffset
            else
                anchorFrame = FocusFrame or blizzSpellBar or UIParent
                anchorPoint = "TOPLEFT"
                relativePoint = "BOTTOMLEFT"
                xPos = 25
                yPos = 7
            end

            local focusDistanceCorrection = isDetached and 0 or GetFocusAuraDistanceCorrection()
            yPos = yPos + focusDistanceCorrection

            if addon and addon.debugMode then
                local relName = "nil"
                if spellRel and spellRel.GetName then
                    relName = spellRel:GetName() or "unnamed"
                end
                local anchorName = (anchorFrame and anchorFrame.GetName and anchorFrame:GetName()) or "unnamed"
                addon:Debug(
                    "CastbarLayout",
                    "focus",
                    "companionShown=" .. tostring(hasCompanion and 1 or 0),
                    "companionSpacing=" .. tostring(useCompanionSpacing and 1 or 0),
                    "auraRows=" .. tostring(auraRows),
                    "extraAuraOffset=" .. tostring(extraAuraOffset),
                    "auraAnchorOffset=" .. tostring(auraAnchorOffset),
                    "detachedStableOffset=" .. tostring(detachedStableOffset),
                    "focusCorrection=" .. tostring(focusDistanceCorrection),
                    "auraAnchorSource=" .. tostring(auraAnchorSource),
                    "spellbarRel=" .. relName,
                    "anchor=" .. tostring(anchorName),
                    "spellPoint=" .. tostring(spellPoint or "nil"),
                    "spellRelPoint=" .. tostring(spellRelPoint or "nil"),
                    "spellX=" .. tostring(spellX or 0),
                    "spellY=" .. tostring(spellY or 0),
                    "x=" .. tostring(xPos),
                    "y=" .. tostring(yPos)
                )
            end
        end
    end
    
    frames.container:ClearAllPoints()
    frames.container:SetPoint(anchorPoint, anchorFrame, relativePoint, xPos, yPos)
    frames.container:SetSize(cfg.sizeX or 200, cfg.sizeY or 16)
    frames.container:SetScale(cfg.scale or 1)
    
    -- Position text background
    if frames.textBackground then
        frames.textBackground:ClearAllPoints()
        frames.textBackground:SetPoint('TOP', frames.castbar, 'BOTTOM', 0, unitType == "player" and 6 or 8)
        frames.textBackground:SetSize(cfg.sizeX or 200, unitType == "player" and 22 or 20)
    end
    
    -- Configure icon
    if frames.icon then
        local iconSize = cfg.sizeIcon or 20
        frames.icon:SetSize(iconSize, iconSize)
        frames.icon:ClearAllPoints()
        
        if unitType == "player" then
            frames.icon:SetPoint('TOPLEFT', frames.castbar, 'TOPLEFT', -(iconSize + 6), -1)
        else
            local iconScale = iconSize / 16
            frames.icon:SetPoint('RIGHT', frames.castbar, 'LEFT', -7 * iconScale, -4)
        end
        
        if frames.icon.Border then
            frames.icon.Border:ClearAllPoints()
            frames.icon.Border:SetPoint('CENTER', frames.icon, 'CENTER', 0, 0)
            frames.icon.Border:SetSize(iconSize * 1.7, iconSize * 1.7)
        end

        if frames.icon.ModernBorder then
            addon.LayoutIconFrameTexture(frames.icon.ModernBorder, frames.icon, iconSize)
        end
        SetIconBordersShown(frames, frames.icon:IsShown() and cfg.showIcon, cfg)

        if frames.shield then
            if unitType == "player" then
                frames.shield:ClearAllPoints()
                frames.shield:SetPoint('CENTER', frames.icon, 'CENTER', 0, 0)
                frames.shield:SetSize(iconSize * 0.8, iconSize * 0.8)
            else
                frames.shield:SetSize(iconSize * 1.8, iconSize * 2.0)
            end
        end
    end
    
    -- Update spark size
    if frames.spark then
        local sparkSize = cfg.sizeY or 16
        frames.spark:SetSize(sparkSize, sparkSize * 2)
    end
    
    -- Update tick sizes
    if frames.ticks then
        for i = 1, MAX_TICKS do
            if frames.ticks[i] then
                local realHeight = frames.castbar:GetHeight()
                frames.ticks[i]:SetSize(3, max(realHeight - 2, 10))
            end
        end
    end

    -- Refresh latency indicator visuals on config/size change (player only)
    if unitType == "player" then
        local castbar = frames.castbar
        if castbar and (castbar.castingEx and not castbar.channelingEx) then
            local duration = (castbar.endTime or 0) - (castbar.startTime or 0)
            if duration > 0 then
                ShowLatencyIndicator(duration)
            end
        else
            HideLatencyIndicator()
        end
    end
    
    -- Set text mode
    if unitType ~= "player" then
        SetTextMode(unitType, cfg.text_mode or "simple")
    end
    
    -- Ensure proper frame levels
    frames.castbar:SetFrameLevel(2)
    if frames.background then
        frames.background:SetFrameLevel(0)
    end
    if frames.textBackground then
        frames.textBackground:SetFrameLevel(1)
    end
    if frames.spark then
        frames.spark:SetFrameLevel(5)
    end
    
    HideBlizzardCastbar(unitType)
    
    if cfg.text_mode then
        SetTextMode(unitType, cfg.text_mode)
    end
end

function CastbarModule:HideCastbar(unitType)
    local frames = self.frames[unitType]
    
    if frames.container then
        frames.container:Hide()
    end
    
    local castbar = frames.castbar
    if castbar then
        castbar.castingEx = false
        castbar.channelingEx = false
        castbar.fadeOutEx = false
        castbar.selfInterrupt = false
        castbar.notInterruptible = false
        castbar.startTime = 0
        castbar.endTime = 0
        castbar.spellName = nil
        castbar.unit = nil
    end
    
    -- Ensure shield and desaturation are cleaned up
    if frames.shield then
        frames.shield:Hide()
    end

    -- Clean up latency visuals
    if unitType == "player" then
        HideLatencyIndicator()
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function CastbarModule:HandleCastingEvent(event, unit, ...)
    local unitType
    if unit == "player" then
        unitType = "player"
    elseif unit == "target" then
        unitType = "target"
    elseif unit == "focus" then
        unitType = "focus"
    else
        return
    end
    
    if not IsEnabled(unitType) then
        return
    end
    
    HideBlizzardCastbar(unitType)
    
    -- GUID verification for target/focus
    if unitType ~= "player" then
        local frames = self.frames[unitType]
        if not frames.castbar then
            return
        end
        
        if event == 'UNIT_SPELLCAST_START' or event == 'UNIT_SPELLCAST_CHANNEL_START' then
            frames.castbar.unit = UnitGUID(unit)
        else
            if frames.castbar.unit ~= UnitGUID(unit) then
                return
            end
        end
    end
    
    -- Event handling
    if event == 'UNIT_SPELLCAST_START' then
        self:HandleCastStart_Simple(unitType, unit, false)
    elseif event == 'UNIT_SPELLCAST_CHANNEL_START' then
        self:HandleCastStart_Simple(unitType, unit, true)
    elseif event == 'UNIT_SPELLCAST_STOP' then
        self:HandleCastStop_Simple(unitType, false)
    elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
        self:HandleCastStop_Simple(unitType, false, true)
    elseif event == 'UNIT_SPELLCAST_FAILED' then
        self:HandleCastFailed_Simple(unitType, ...)
    elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
        self:HandleCastInterrupted_Simple(unitType, false, ...)
    elseif event == 'UNIT_SPELLCAST_CHANNEL_INTERRUPTED' then
        self:HandleCastInterrupted_Simple(unitType, true, ...)
    elseif event == 'UNIT_SPELLCAST_DELAYED' or event == 'UNIT_SPELLCAST_CHANNEL_UPDATE' then
        self:HandleCastDelayed_Simple(unitType, unit)
    elseif event == 'UNIT_SPELLCAST_NOT_INTERRUPTIBLE' then
        self:HandleInterruptibleChanged(unitType, unit, true)
    elseif event == 'UNIT_SPELLCAST_INTERRUPTIBLE' then
        self:HandleInterruptibleChanged(unitType, unit, false)
    end
end

function CastbarModule:HandleInterruptibleChanged(unitType, unit, isNotInterruptible)
    -- Only applies to target/focus castbars (player casts are always interruptible in 3.3.5a)
    if unitType == "player" then
        return
    end
    
    local frames = self.frames[unitType]
    if not frames or not frames.castbar then
        return
    end
    
    local castbar = frames.castbar
    if not (castbar.castingEx or castbar.channelingEx) then
        return
    end
    
    castbar.notInterruptible = isNotInterruptible
    
    -- Update desaturation on the status bar texture
    local sbTexture = castbar:GetStatusBarTexture()
    if sbTexture and sbTexture.SetDesaturated then
        sbTexture:SetDesaturated(isNotInterruptible and true or false)
    end
    
    -- Update shield visibility (only if icon is shown)
    local cfg = GetConfig(unitType)
    if frames.shield then
        if isNotInterruptible and frames.icon and frames.icon:IsShown() then
            frames.shield:Show()
        else
            frames.shield:Hide()
        end
    end
end

function CastbarModule:RefreshCompanionLayout(unitType)
    if not IsEnabled(unitType) then
        return
    end

    self:RefreshCastbar(unitType)
    if addon and addon.core and addon.core.ScheduleTimer then
        addon.core:ScheduleTimer(function()
            if IsEnabled(unitType) then
                CastbarModule:RefreshCastbar(unitType)
            end
        end, 0.05)
    end
end

function CastbarModule:HandleTargetChanged()
    local frames = self.frames.target
    local statusBar = frames.castbar
    
    if not statusBar then
        return
    end
    
    if UnitExists("target") and statusBar.unit == UnitGUID("target") then
        if GetTime() > (statusBar.endTime or 0) then
            self:HideCastbar("target")
        else
            statusBar:Show()
        end
    else
        self:HideCastbar("target")
    end
    
    HideBlizzardCastbar("target")

    -- Always refresh layout on target transitions so stale companion offsets are cleared.
    self:RefreshCompanionLayout("target")
    
    -- Check if new target has active cast
    if UnitExists("target") and IsEnabled("target") then
        if UnitCastingInfo("target") then
            self:HandleCastingEvent('UNIT_SPELLCAST_START', "target")
        elseif UnitChannelInfo("target") then
            self:HandleCastingEvent('UNIT_SPELLCAST_CHANNEL_START', "target")
        end
    end
end

function CastbarModule:HandleFocusChanged()
    local frames = self.frames.focus
    local statusBar = frames.castbar
    
    if not statusBar then
        return
    end
    
    if UnitExists("focus") and statusBar.unit == UnitGUID("focus") then
        if GetTime() > (statusBar.endTime or 0) then
            self:HideCastbar("focus")
        else
            statusBar:Show()
        end
    else
        self:HideCastbar("focus")
    end
    
    HideBlizzardCastbar("focus")

    -- Always refresh layout on focus transitions so stale companion offsets are cleared.
    self:RefreshCompanionLayout("focus")
    
    -- Check if new focus has active cast
    if UnitExists("focus") and IsEnabled("focus") then
        if UnitCastingInfo("focus") then
            self:HandleCastingEvent('UNIT_SPELLCAST_START', "focus")
        elseif UnitChannelInfo("focus") then
            self:HandleCastingEvent('UNIT_SPELLCAST_CHANNEL_START', "focus")
        end
    end
end

-- ============================================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ============================================================================

local function CreateCastbarAnchorFrame()
    if CastbarModule.anchor then
        return CastbarModule.anchor
    end
    
    CastbarModule.anchor = addon.CreateUIFrame(256, 16, "PlayerCastbar")
    
    return CastbarModule.anchor
end

local function CreateTargetCastbarAnchorFrame()
    if CastbarModule.targetAnchor then
        return CastbarModule.targetAnchor
    end

    CastbarModule.targetAnchor = addon.CreateUIFrame(150, 10, "TargetCastbar")

    return CastbarModule.targetAnchor
end

local function CreateFocusCastbarAnchorFrame()
    if CastbarModule.focusAnchor then
        return CastbarModule.focusAnchor
    end

    CastbarModule.focusAnchor = addon.CreateUIFrame(150, 10, "FocusCastbar")

    return CastbarModule.focusAnchor
end

local function ApplyWidgetPosition()
    if not CastbarModule.anchor then
        return
    end
    
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end
    
    local widgetConfig = addon.db.profile.widgets.playerCastbar
    
    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        local anchor = widgetConfig.anchor or "BOTTOM"
        CastbarModule.anchor:ClearAllPoints()
        CastbarModule.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
    else
        CastbarModule.anchor:ClearAllPoints()
        CastbarModule.anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 270)
    end
end

local function ApplyCastbarWidgetPosition(unitType)
    local widgetKey = GetCastbarWidgetKey(unitType)
    local anchorFrame = GetCastbarAnchorFrame(unitType)
    if not widgetKey or not anchorFrame then
        return
    end

    -- Keep attached castbars driven by smart positioning only.
    -- Applying widget coordinates while attached can recenter unrelated overlays in editor mode.
    if not IsCastbarDetached(unitType) then
        return
    end

    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local widgetConfig = addon.db.profile.widgets[widgetKey]
    if widgetConfig and widgetConfig.posX ~= nil and widgetConfig.posY ~= nil then
        local anchor = widgetConfig.anchor or "CENTER"
        anchorFrame:ClearAllPoints()
        anchorFrame:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
    else
        anchorFrame:ClearAllPoints()
        anchorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function SyncCastbarAnchorToContainer(unitType)
    local anchorFrame = GetCastbarAnchorFrame(unitType)
    local frames = CastbarModule.frames[unitType]
    if not anchorFrame or not frames or not frames.container then
        return
    end

    local cx, cy = frames.container:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then
        anchorFrame:ClearAllPoints()
        anchorFrame:SetPoint("CENTER", UIParent, "CENTER", cx - ux, cy - uy)
    end
end

local function AnchorCastbarEditorToContainer(unitType)
    local anchorFrame = GetCastbarAnchorFrame(unitType)
    local frames = CastbarModule.frames[unitType]
    if not anchorFrame or not frames or not frames.container then
        return
    end

    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint("CENTER", frames.container, "CENTER", 0, 0)
end

local function PersistCastbarAnchorPosition(unitType)
    local widgetKey = GetCastbarWidgetKey(unitType)
    local anchorFrame = GetCastbarAnchorFrame(unitType)
    if not widgetKey or not anchorFrame then
        return false
    end

    if not addon.db or not addon.db.profile then
        return false
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets[widgetKey] = addon.db.profile.widgets[widgetKey] or {}

    local cx, cy = anchorFrame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then
        return false
    end

    addon.db.profile.widgets[widgetKey].anchor = "CENTER"
    addon.db.profile.widgets[widgetKey].posX = floor((cx - ux) + 0.5)
    addon.db.profile.widgets[widgetKey].posY = floor((cy - uy) + 0.5)
    return true
end

function CastbarModule:LoadDefaultSettings()
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.playerCastbar then
        addon.db.profile.widgets.playerCastbar = {
            anchor = "BOTTOM",
            posX = 0,
            posY = 270
        }
    end

    if not addon.db.profile.widgets.targetCastbar then
        addon.db.profile.widgets.targetCastbar = {
            anchor = "CENTER",
            posX = 0,
            posY = 0
        }
    end

    if not addon.db.profile.widgets.focusCastbar then
        addon.db.profile.widgets.focusCastbar = {
            anchor = "CENTER",
            posX = 0,
            posY = 0
        }
    end
    
    if not addon.db.profile.castbar then
        addon.db.profile.castbar = {}
    end

    if addon.db.profile.castbar.target and addon.db.profile.castbar.target.override == nil then
        addon.db.profile.castbar.target.override = false
    end

    if addon.db.profile.castbar.focus and addon.db.profile.castbar.focus.override == nil then
        addon.db.profile.castbar.focus.override = false
    end
end

function CastbarModule:UpdateWidgets()
    ApplyWidgetPosition()
    ApplyCastbarWidgetPosition("target")
    ApplyCastbarWidgetPosition("focus")

    if not InCombatLockdown() then
        self:RefreshCastbar("player")
        self:RefreshCastbar("target")
        self:RefreshCastbar("focus")
    end
end

local function ShouldPlayerCastbarBeVisible()
    local cfg = GetConfig("player")
    return cfg and cfg.enabled
end

local function ShowPlayerCastbarTest()
    local frames = CastbarModule.frames.player
    if not frames.container then
        CreateCastbar("player")
    end
    
    if frames.container then
        frames.container:Show()
        -- Use a very long duration so the preview doesn't expire during editor mode
        CastbarModule:ShowCastbar("player", "Fire ball", 0.5, 1, 86400, false, false)
        -- Freeze the bar at 50% — disable OnUpdate animation flags
        if frames.castbar then
            frames.castbar.castingEx = false
            frames.castbar.channelingEx = false
            frames.castbar:SetValue(0.5)
        end
    end
end

local function HidePlayerCastbarTest()
    CastbarModule:HideCastbar("player")
end

local function ShowCastbarTest(unitType)
    local frames = CastbarModule.frames[unitType]
    if not frames.container then
        CreateCastbar(unitType)
        frames = CastbarModule.frames[unitType]
    end

    CastbarModule:RefreshCastbar(unitType)

    if not IsCastbarDetached(unitType) then
        AnchorCastbarEditorToContainer(unitType)
    end

    if frames.container then
        frames.container:Show()
        CastbarModule:ShowCastbar(unitType, "Fireball", 0.5, 1, 86400, false, false)
        if frames.castbar then
            frames.castbar.castingEx = false
            frames.castbar.channelingEx = false
            frames.castbar:SetValue(0.5)
        end
    end
end

local function HideCastbarTest(unitType)
    CastbarModule:HideCastbar(unitType)
end

local function HandleCastbarEditorHide(unitType)
    local anchorFrame = GetCastbarAnchorFrame(unitType)
    if not anchorFrame then
        return
    end

    if anchorFrame.DragonUI_WasDragged or anchorFrame.DragonUI_WasAdjustedByEditor then
        local cfg = GetConfig(unitType)
        if cfg then
            cfg.override = true
        end

        PersistCastbarAnchorPosition(unitType)

        anchorFrame.DragonUI_WasDragged = nil
        anchorFrame.DragonUI_WasAdjustedByEditor = nil
    end

    ApplyCastbarWidgetPosition(unitType)
    CastbarModule:RefreshCastbar(unitType)
end

function CastbarModule:ShowCastbar(unitType, spellName, currentValue, maxValue, duration, isChanneling, isInterrupted)
    local frames = self.frames[unitType]
    if not frames.castbar then
        self:RefreshCastbar(unitType)
        frames = self.frames[unitType]
    end
    
    if not frames.castbar then
        return
    end
    
    local castbar = frames.castbar
    local currentTime = GetTime()
    
    castbar.startTime = currentTime
    castbar.endTime = currentTime + (duration or maxValue or 1)
    castbar.castingEx = not isChanneling
    castbar.channelingEx = isChanneling
    castbar.fadeOutEx = false
    castbar.selfInterrupt = false
    
    castbar:SetMinMaxValues(0, 1)
    
    local progress = maxValue > 0 and (currentValue / maxValue) or 0
    if isChanneling then
        progress = 1 - progress
    end
    castbar:SetValue(progress)
    
    if not frames.container then
        CreateCastbar(unitType)
    end
    
    frames.container:Show()
    UIFrameFadeRemoveFrame(frames.container)
    frames.container:SetAlpha(1.0)
    
    if isInterrupted then
        castbar:SetStatusBarTexture(TEXTURES.interrupted)
        local texture = castbar:GetStatusBarTexture()
        if texture then
            texture:SetVertexColor(1, 1, 1, 1)
        end
        castbar:SetStatusBarColor(1, 0, 0, 1)
        SetCastText(unitType, "Interrupted")
        castbar.selfInterrupt = true
    else
        if isChanneling then
            castbar:SetStatusBarTexture(TEXTURES.channel)
            local texture = castbar:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1, 1)
            end
            castbar:SetStatusBarColor(0, 1, 0, 1)
        else
            castbar:SetStatusBarTexture(TEXTURES.standard)
            local texture = castbar:GetStatusBarTexture()
            if texture then
                texture:SetVertexColor(1, 1, 1, 1)
            end
            castbar:SetStatusBarColor(1, 0.7, 0, 1)
        end
        SetCastText(unitType, spellName)
    end
    
    if frames.textBackground then
        frames.textBackground:Show()
    end
    
    ForceStatusBarLayer(castbar)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function InitializeCastbarForEditor()
    CreateCastbarAnchorFrame()
    CreateTargetCastbarAnchorFrame()
    CreateFocusCastbarAnchorFrame()

    if CastbarModule.targetAnchor then
        local originalTargetDragStart = CastbarModule.targetAnchor:GetScript("OnDragStart")
        CastbarModule.targetAnchor:SetScript("OnDragStart", function(self, button)
            if not IsCastbarDetached("target") then
                SyncCastbarAnchorToContainer("target")
            end

            if originalTargetDragStart then
                originalTargetDragStart(self, button)
            end

            local cfg = GetConfig("target")
            if cfg and not cfg.override then
                cfg.override = true
                CastbarModule:RefreshCastbar("target")
            end
        end)

        CastbarModule.targetAnchor:HookScript("OnDragStop", function(self)
            self.DragonUI_WasDragged = true

            local cfg = GetConfig("target")
            if cfg then
                cfg.override = true
            end

            PersistCastbarAnchorPosition("target")
            CastbarModule:UpdateWidgets()
        end)
    end

    if CastbarModule.focusAnchor then
        local originalFocusDragStart = CastbarModule.focusAnchor:GetScript("OnDragStart")
        CastbarModule.focusAnchor:SetScript("OnDragStart", function(self, button)
            if not IsCastbarDetached("focus") then
                SyncCastbarAnchorToContainer("focus")
            end

            if originalFocusDragStart then
                originalFocusDragStart(self, button)
            end

            local cfg = GetConfig("focus")
            if cfg and not cfg.override then
                cfg.override = true
                CastbarModule:RefreshCastbar("focus")
            end
        end)

        CastbarModule.focusAnchor:HookScript("OnDragStop", function(self)
            self.DragonUI_WasDragged = true

            local cfg = GetConfig("focus")
            if cfg then
                cfg.override = true
            end

            PersistCastbarAnchorPosition("focus")
            CastbarModule:UpdateWidgets()
        end)
    end
    
    addon:RegisterEditableFrame({
        name = "PlayerCastbar",
        frame = CastbarModule.anchor,
        configPath = {"widgets", "playerCastbar"},
        hasTarget = ShouldPlayerCastbarBeVisible,
        editorVisible = ShouldPlayerCastbarBeVisible,
        showTest = ShowPlayerCastbarTest,
        hideTest = HidePlayerCastbarTest,
        onHide = function()
            CastbarModule:UpdateWidgets()
        end,
        LoadDefaultSettings = function()
            CastbarModule:LoadDefaultSettings()
        end,
        UpdateWidgets = function()
            CastbarModule:UpdateWidgets()
        end
    })

    addon:RegisterEditableFrame({
        name = "TargetCastbar",
        frame = CastbarModule.targetAnchor,
        configPath = {"widgets", "targetCastbar"},
        hasTarget = function()
            return IsEnabled("target")
        end,
        editorVisible = function()
            return IsEnabled("target")
        end,
        showTest = function()
            ShowCastbarTest("target")
        end,
        hideTest = function()
            HideCastbarTest("target")
        end,
        onHide = function()
            HandleCastbarEditorHide("target")
        end,
    })

    addon:RegisterEditableFrame({
        name = "FocusCastbar",
        frame = CastbarModule.focusAnchor,
        configPath = {"widgets", "focusCastbar"},
        hasTarget = function()
            return IsEnabled("focus")
        end,
        editorVisible = function()
            return IsEnabled("focus")
        end,
        showTest = function()
            ShowCastbarTest("focus")
        end,
        hideTest = function()
            HideCastbarTest("focus")
        end,
        onHide = function()
            HandleCastbarEditorHide("focus")
        end,
    })

    ApplyWidgetPosition()
    ApplyCastbarWidgetPosition("target")
    ApplyCastbarWidgetPosition("focus")
    
    CastbarModule.initialized = true
end

local function SetupBlizzardLayoutHooks()
    if CastbarModule.layoutHooksInstalled then
        return
    end

    -- DragonflightUI pattern: sync to Blizzard's final spellbar positioning callback.
    if type(Target_Spellbar_AdjustPosition) == "function" then
        hooksecurefunc("Target_Spellbar_AdjustPosition", function(spellbar)
            if CastbarModule.suppressLayoutHook then
                return
            end
            if spellbar == TargetFrameSpellBar then
                if IsEnabled("target") then
                    CastbarModule:RefreshCastbar("target")
                end
            elseif spellbar == FocusFrameSpellBar then
                if IsEnabled("focus") then
                    CastbarModule:RefreshCastbar("focus")
                end
            end
        end)
    end

    CastbarModule.layoutHooksInstalled = true
end

local function OnEvent(self, event, unit, ...)
    if event == 'PLAYER_TARGET_CHANGED' then
        CastbarModule:HandleTargetChanged()
    elseif event == 'PLAYER_FOCUS_CHANGED' then
        CastbarModule:HandleFocusChanged()
    elseif event == 'UNIT_TARGET' then
        if unit == "target" then
            CastbarModule:RefreshCompanionLayout("target")
        elseif unit == "focus" then
            CastbarModule:RefreshCompanionLayout("focus")
        end
    elseif event == 'PLAYER_ENTERING_WORLD' then
        SetupBlizzardLayoutHooks()
        -- Full protection for reload during combat
        if addon.core and addon.core.ScheduleTimer then
            -- Normal path with timers
            addon.core:ScheduleTimer(function()
                CastbarModule:RefreshCastbar("player")
                CastbarModule:RefreshCastbar("target")
                CastbarModule:RefreshCastbar("focus")
                
                addon.core:ScheduleTimer(function()
                    if IsEnabled("player") then
                        HideBlizzardCastbar("player")
                    end
                    if IsEnabled("target") then
                        HideBlizzardCastbar("target")
                    end
                    if IsEnabled("focus") then
                        HideBlizzardCastbar("focus")
                    end
                end, 1.0)
            end, 0.5)
        else
            -- Immediate fallback without timers (reload during combat)
            CastbarModule:RefreshCastbar("player")
            CastbarModule:RefreshCastbar("target")
            CastbarModule:RefreshCastbar("focus")
            
            -- Second step also immediate
            if IsEnabled("player") then
                HideBlizzardCastbar("player")
            end
            if IsEnabled("target") then
                HideBlizzardCastbar("target")
            end
            if IsEnabled("focus") then
                HideBlizzardCastbar("focus")
            end
        end
    elseif event == 'UNIT_SPELLCAST_SENT' then
        -- Latency tracking: record send time for player only
        if unit == "player" then
            latencyState.sentTime = GetTime()
        end
    else
        CastbarModule:HandleCastingEvent(event, unit, ...)
    end
end

function addon.ApplyCastbarWidgetPositions()
    ApplyWidgetPosition()
    ApplyCastbarWidgetPosition("target")
    ApplyCastbarWidgetPosition("focus")
end

-- Public API
function addon.RefreshCastbar()
    CastbarModule:RefreshCastbar("player")
end

function addon.RefreshTargetCastbar()
    CastbarModule:RefreshCastbar("target")
end

function addon.RefreshFocusCastbar()
    CastbarModule:RefreshCastbar("focus")
end

function addon.ResetTargetCastbarPosition()
    if not addon.db or not addon.db.profile then
        return
    end

    if addon.db.profile.castbar and addon.db.profile.castbar.target then
        addon.db.profile.castbar.target.override = false
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}

    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets and addon.defaults.profile.widgets.targetCastbar
    if defaults then
        if addon.CopyTable then
            addon.db.profile.widgets.targetCastbar = addon:CopyTable(defaults)
        else
            addon.db.profile.widgets.targetCastbar = {
                anchor = defaults.anchor,
                posX = defaults.posX,
                posY = defaults.posY,
            }
        end
    else
        addon.db.profile.widgets.targetCastbar = {
            anchor = "CENTER",
            posX = 0,
            posY = 0,
        }
    end

    ApplyCastbarWidgetPosition("target")
    CastbarModule:RefreshCastbar("target")
end

function addon.ResetFocusCastbarPosition()
    if not addon.db or not addon.db.profile then
        return
    end

    if addon.db.profile.castbar and addon.db.profile.castbar.focus then
        addon.db.profile.castbar.focus.override = false
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}

    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets and addon.defaults.profile.widgets.focusCastbar
    if defaults then
        if addon.CopyTable then
            addon.db.profile.widgets.focusCastbar = addon:CopyTable(defaults)
        else
            addon.db.profile.widgets.focusCastbar = {
                anchor = defaults.anchor,
                posX = defaults.posX,
                posY = defaults.posY,
            }
        end
    else
        addon.db.profile.widgets.focusCastbar = {
            anchor = "CENTER",
            posX = 0,
            posY = 0,
        }
    end

    ApplyCastbarWidgetPosition("focus")
    CastbarModule:RefreshCastbar("focus")
end

-- Initialize event frame
local eventFrame = CreateFrame('Frame', 'DragonUICastbarEventHandler')
local events = {
    'PLAYER_ENTERING_WORLD',
    'UNIT_SPELLCAST_SENT',
    'UNIT_SPELLCAST_START',
    'UNIT_SPELLCAST_DELAYED',
    'UNIT_SPELLCAST_STOP',
    'UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE',
    'UNIT_SPELLCAST_NOT_INTERRUPTIBLE',
    'UNIT_SPELLCAST_INTERRUPTIBLE',
    'UNIT_TARGET',
    'PLAYER_TARGET_CHANGED',
    'PLAYER_FOCUS_CHANGED'
}

for _, event in ipairs(events) do
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript('OnEvent', OnEvent)

-- Initialize centralized system
InitializeCastbarForEditor()
SetupBlizzardLayoutHooks()

-- Load settings when addon is ready
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        if CastbarModule.UpdateWidgets then
            CastbarModule:UpdateWidgets()
        end
        ApplyCastbarWidgetPosition("target")
        ApplyCastbarWidgetPosition("focus")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
