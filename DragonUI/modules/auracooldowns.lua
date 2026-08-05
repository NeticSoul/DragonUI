local addon = select(2, ...)

local ceil = math.ceil
local format = string.format
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff

-- ============================================================================
-- DragonUI - Aura Cooldown Text Module
-- Displays cooldown text on target/focus buff and debuff icons.
-- ============================================================================

local AuraCooldownsModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    frames = {},
    styleGeneration = 1
}
addon.AuraCooldownsModule = AuraCooldownsModule

if addon.RegisterModule then
    addon:RegisterModule("auracooldowns", AuraCooldownsModule,
    addon.L["Target & Focus Aura Customization"],
    addon.L["Customize target/focus aura icons and timers."],
        { lifecyclePrefix = "AuraCooldownText" })
end

local function GetModuleConfig()
    return addon:GetModuleConfig("auracooldowns")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("auracooldowns")
end

local function GetUnitConfig(unitKey)
    local cfg = GetModuleConfig()
    if not cfg then return nil end
    return cfg[unitKey]
end

local function IsTimerFeatureEnabled()
    local cfg = GetModuleConfig()
    return cfg and (
        cfg.timers_enabled == true
        or (cfg.target and cfg.target.enabled == true)
        or (cfg.focus and cfg.focus.enabled == true)
    )
end

local function IsIconFeatureEnabled()
    local cfg = GetModuleConfig()
    return cfg and cfg.icons_enabled == true
end

local function IsTimerEnabledForUnit(unitKey)
    local cfg = GetModuleConfig() or {}
    local unitCfg = cfg[unitKey]
    if unitCfg and unitCfg.enabled ~= nil then
        return unitCfg.enabled == true
    end

    local timerUnits = cfg.timer_units
    if timerUnits == "target" or timerUnits == "focus" or timerUnits == "both" then
        return timerUnits == "both" or timerUnits == unitKey
    end

    return true
end

local MAX_AURA_BUFFS = 32
local MAX_AURA_DEBUFFS = 16
local UPDATE_INTERVAL = 0.1

local FONT_PRESETS = {
    actionbar = function()
        return (addon.Fonts and addon.Fonts.ACTIONBAR) or STANDARD_TEXT_FONT
    end,
    primary = function()
        return (addon.Fonts and addon.Fonts.PRIMARY) or STANDARD_TEXT_FONT
    end,
    narrow = function()
        return (addon.Fonts and addon.Fonts.NARROW) or STANDARD_TEXT_FONT
    end,
    arial = function()
        return (addon.Fonts and addon.Fonts.ARIALN) or "Fonts\\ARIALN.TTF"
    end,
    system = function()
        return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end,
}

local function GetModuleDefaults()
    return addon.defaults
        and addon.defaults.profile
        and addon.defaults.profile.modules
        and addon.defaults.profile.modules.auracooldowns
end

local function ReadNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback
    end
    return n
end

local function ResolveFontPath(fontKey)
    local resolver = FONT_PRESETS[fontKey]
    if resolver then
        return resolver()
    end
    return FONT_PRESETS.system()
end

local function GetCommonConfig()
    local cfg = GetModuleConfig() or {}
    local def = GetModuleDefaults() or {}

    return {
        duration_anchor = cfg.duration_anchor or def.duration_anchor or "CENTER",
        duration_offset_x = ReadNumber(cfg.duration_offset_x, ReadNumber(def.duration_offset_x, 0)),
        duration_offset_y = ReadNumber(cfg.duration_offset_y, ReadNumber(def.duration_offset_y, 0)),
        stack_anchor = cfg.stack_anchor or def.stack_anchor or "TOPRIGHT",
        stack_offset_x = ReadNumber(cfg.stack_offset_x, ReadNumber(def.stack_offset_x, 0)),
        stack_offset_y = ReadNumber(cfg.stack_offset_y, ReadNumber(def.stack_offset_y, 0)),
        duration_font = cfg.duration_font or def.duration_font or "system",
        count_font = cfg.count_font or def.count_font or "system",
    }
end

local function GetAuraTypeConfig(isDebuff)
    local cfg = GetModuleConfig() or {}
    local def = GetModuleDefaults() or {}
    local blockKey = isDebuff and "debuffs" or "buffs"
    local auraCfg = cfg[blockKey] or {}
    local auraDef = def[blockKey] or {}

    return {
        icon_size = ReadNumber(auraCfg.icon_size, ReadNumber(auraDef.icon_size, 0)),
        icon_scale = ReadNumber(auraCfg.icon_scale, ReadNumber(auraDef.icon_scale, 1)),
        stack_font_size = ReadNumber(auraCfg.stack_font_size, ReadNumber(auraDef.stack_font_size, 0)),
    }
end

local function ResolveUnitKey(cooldown)
    if not cooldown then return nil end

    local name = cooldown.GetName and cooldown:GetName()
    if name then
        if name:find("^TargetFrame") then
            return "target"
        elseif name:find("^FocusFrame") then
            return "focus"
        end
    end

    local parent = cooldown.GetParent and cooldown:GetParent()
    local parentName = parent and parent.GetName and parent:GetName()
    if parentName then
        if parentName:find("^TargetFrame") then
            return "target"
        elseif parentName:find("^FocusFrame") then
            return "focus"
        end
    end

    return nil
end

local function IsDebuffCooldown(cooldown)
    local name = cooldown and cooldown.GetName and cooldown:GetName()
    return name and name:find("Debuff") ~= nil
end

local function SetJustifyFromAnchor(fontString, anchor)
    if not fontString then return end

    if anchor and anchor:find("LEFT") then
        fontString:SetJustifyH("LEFT")
    elseif anchor and anchor:find("RIGHT") then
        fontString:SetJustifyH("RIGHT")
    else
        fontString:SetJustifyH("CENTER")
    end
end

local function EnsureText(cooldown)
    if cooldown._duiAuraText then
        return cooldown._duiAuraText
    end

    -- Sibling holder above the cooldown: auraborders scales the cooldown, which would scale a child FontString.
    local parent = (cooldown.GetParent and cooldown:GetParent()) or cooldown
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetAllPoints(parent)
    holder:SetFrameLevel(parent:GetFrameLevel() + 15)

    local text = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", parent, "CENTER", 0, 0)
    text:Hide()

    cooldown._duiAuraText = text
    return text
end

local function HideCooldownText(cooldown)
    if cooldown and cooldown._duiAuraText then
        cooldown._duiAuraText:Hide()
        cooldown._duiAuraText:SetText("")
    end
end

local function ShouldCustomizeStacks(common, auraCfg)
    if not common or not auraCfg then
        return false
    end

    return (auraCfg.stack_font_size or 0) > 0
        or (common.stack_anchor or "TOPRIGHT") ~= "TOPRIGHT"
        or (common.stack_offset_x or 0) ~= 0
        or (common.stack_offset_y or 0) ~= 0
        or (common.count_font or "system") ~= "system"
end

local function StyleAuraButton(cooldown)
    if not cooldown then return nil end

    local button = cooldown.GetParent and cooldown:GetParent()
    if not button then return nil end

    -- Positions/fonts are static per config (Blizzard only SetText/Show/Hides the count); restyle once per config change.
    if button._duiStyleGen == AuraCooldownsModule.styleGeneration then
        return button
    end

    local common = GetCommonConfig()
    local auraCfg = GetAuraTypeConfig(IsDebuffCooldown(cooldown))

    -- icon_size/icon_scale feed the shared aura layout hook (target.lua); resizing here would fight it.

    if ShouldCustomizeStacks(common, auraCfg) then
        local buttonName = button.GetName and button:GetName()
        local count = buttonName and _G[buttonName .. "Count"] or button.count
        if count then
            count:ClearAllPoints()
            count:SetPoint(common.stack_anchor, button, common.stack_anchor, common.stack_offset_x, common.stack_offset_y)
            count:SetJustifyV("TOP")
            SetJustifyFromAnchor(count, common.stack_anchor)
            count:SetShadowOffset(0, 0)
            count:SetDrawLayer("OVERLAY")

            local countFont = ResolveFontPath(common.count_font)
            local countSize = auraCfg.stack_font_size > 0 and auraCfg.stack_font_size or 10
            count:SetFont(countFont, countSize, "THINOUTLINE")
        end
    end

    button._duiStyleGen = AuraCooldownsModule.styleGeneration
    return button
end

local function FormatRemaining(remaining)
    if remaining <= 5 then
        return format("%.1f", remaining), 1, 0.2, 0.2
    end

    if remaining < 60 then
        return ceil(remaining), 1, 0.85, 0
    end

    if remaining < 3600 then
        return ceil(remaining / 60) .. "m", 1, 1, 1
    end

    return ceil(remaining / 3600) .. "h", 0.8, 0.8, 0.8
end

local function UpdateCooldownText(cooldown)
    if not cooldown then return end

    if not AuraCooldownsModule.applied or not IsModuleEnabled() then
        HideCooldownText(cooldown)
        return
    end

    local unitKey = ResolveUnitKey(cooldown)
    if not unitKey then
        HideCooldownText(cooldown)
        return
    end

    local unitCfg = GetUnitConfig(unitKey)
    if not unitCfg then
        HideCooldownText(cooldown)
        return
    end

    local button = cooldown.GetParent and cooldown:GetParent()
    if not button then
        HideCooldownText(cooldown)
        return
    end

    if IsIconFeatureEnabled() then
        button = StyleAuraButton(cooldown) or button
    end

    if not IsTimerFeatureEnabled() or not IsTimerEnabledForUnit(unitKey) then
        HideCooldownText(cooldown)
        return
    end

    local start = cooldown._duiAuraStart or 0
    local duration = cooldown._duiAuraDuration or 0
    if start <= 0 or duration <= 0 then
        HideCooldownText(cooldown)
        return
    end

    local remaining = (start + duration) - GetTime()
    local minDuration = tonumber(unitCfg.min_duration) or 0
    local maxDurationMinutes = tonumber(unitCfg.max_duration_minutes)
    if maxDurationMinutes == nil then
        local legacyMaxDuration = tonumber(unitCfg.max_duration) or 0
        if legacyMaxDuration > 0 then
            maxDurationMinutes = legacyMaxDuration / 60
        else
            maxDurationMinutes = 0
        end
    end

    local maxDurationSeconds = maxDurationMinutes > 0 and (maxDurationMinutes * 60) or 0
    if maxDurationSeconds > 0 and remaining > maxDurationSeconds then
        HideCooldownText(cooldown)
        return
    end

    if remaining <= minDuration then
        HideCooldownText(cooldown)
        return
    end

    local text = EnsureText(cooldown)
    if text._duiStyleGen ~= AuraCooldownsModule.styleGeneration then
        local common = GetCommonConfig()
        text:ClearAllPoints()
        text:SetPoint(common.duration_anchor, button, common.duration_anchor, common.duration_offset_x, common.duration_offset_y)
        SetJustifyFromAnchor(text, common.duration_anchor)

        local fontPath = ResolveFontPath(common.duration_font)
        local fontSize = ReadNumber(unitCfg.font_size, 11)
        if not text:SetFont(fontPath, fontSize, "THINOUTLINE") and STANDARD_TEXT_FONT then
            text:SetFont(STANDARD_TEXT_FONT, fontSize, "THINOUTLINE")
        end
        text._duiStyleGen = AuraCooldownsModule.styleGeneration
    end

    local textValue, r, g, b = FormatRemaining(remaining)
    text:SetText(textValue)
    text:SetTextColor(r, g, b)
    text:Show()
end

local function UpdateAllTrackedCooldowns()
    local tracked = AuraCooldownsModule.frames.trackedCooldowns
    if not tracked then return end

    for cooldown in pairs(tracked) do
        UpdateCooldownText(cooldown)
    end
end

local function RegisterEvent(frame, event)
    frame:RegisterEvent(event)
    table.insert(AuraCooldownsModule.registeredEvents, { frame = frame, event = event })
end

local function TrackCooldown(cooldown, start, duration)
    if not cooldown then return end

    AuraCooldownsModule.frames.trackedCooldowns = AuraCooldownsModule.frames.trackedCooldowns or {}
    AuraCooldownsModule.frames.trackedCooldowns[cooldown] = true

    if not cooldown._duiAuraCooldownHooked then
        hooksecurefunc(cooldown, "SetCooldown", function(self, start, duration)
            self._duiAuraStart = start or 0
            self._duiAuraDuration = duration or 0
            UpdateCooldownText(self)
        end)
        cooldown._duiAuraCooldownHooked = true
    end

    cooldown._duiAuraStart = start or 0
    cooldown._duiAuraDuration = duration or 0

    UpdateCooldownText(cooldown)
end

local function GetUnitTokenForFrame(frameName)
    if frameName == "TargetFrame" then
        return "target"
    elseif frameName == "FocusFrame" then
        return "focus"
    end
    return nil
end

local function GetAuraTiming(unitToken, index, isDebuff)
    if not unitToken then
        return 0, 0
    end

    local duration, expirationTime
    if isDebuff then
        duration, expirationTime = select(6, UnitDebuff(unitToken, index, "INCLUDE_NAME_PLATE_ONLY"))
    else
        duration, expirationTime = select(6, UnitBuff(unitToken, index))
    end

    duration = duration or 0
    expirationTime = expirationTime or 0
    if duration <= 0 or expirationTime <= 0 then
        return 0, 0
    end

    local start = expirationTime - duration
    if start < 0 then
        start = 0
    end

    return start, duration
end

local function ScanAuraCooldownsForFrame(frameName)
    local unitToken = GetUnitTokenForFrame(frameName)

    for i = 1, MAX_AURA_BUFFS do
        local start, duration = GetAuraTiming(unitToken, i, false)
        TrackCooldown(_G[frameName .. "Buff" .. i .. "Cooldown"], start, duration)
    end

    for i = 1, MAX_AURA_DEBUFFS do
        local start, duration = GetAuraTiming(unitToken, i, true)
        TrackCooldown(_G[frameName .. "Debuff" .. i .. "Cooldown"], start, duration)
    end
end

local function ScanAllAuraCooldowns()
    ScanAuraCooldownsForFrame("TargetFrame")
    ScanAuraCooldownsForFrame("FocusFrame")
end

local function EnsureUpdateFrame()
    if AuraCooldownsModule.frames.updateFrame then
        return AuraCooldownsModule.frames.updateFrame
    end

    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:Hide()
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < UPDATE_INTERVAL then
            return
        end

        self.elapsed = 0
        UpdateAllTrackedCooldowns()
    end)

    AuraCooldownsModule.frames.updateFrame = frame
    return frame
end

local function InstallAuraHooks()
    if AuraCooldownsModule.hooks.targetFrameUpdateHooked then
        return
    end

    if TargetFrame_UpdateAuras then
        hooksecurefunc("TargetFrame_UpdateAuras", function(frame)
            local frameName = frame and frame.GetName and frame:GetName()
            if frameName == "TargetFrame" or frameName == "FocusFrame" then
                ScanAuraCooldownsForFrame(frameName)
            end
        end)
        AuraCooldownsModule.hooks.targetFrameUpdateHooked = true
    end
end

local function RegisterModuleEvents()
    if AuraCooldownsModule.frames.eventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" then
            if unit == "target" then
                ScanAuraCooldownsForFrame("TargetFrame")
            elseif unit == "focus" then
                ScanAuraCooldownsForFrame("FocusFrame")
            end
            return
        end

        ScanAllAuraCooldowns()
    end)

    RegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    RegisterEvent(eventFrame, "PLAYER_TARGET_CHANGED")
    RegisterEvent(eventFrame, "PLAYER_FOCUS_CHANGED")
    RegisterEvent(eventFrame, "UNIT_AURA")

    AuraCooldownsModule.frames.eventFrame = eventFrame
end

function addon.ApplyAuraCooldownTextSystem()
    -- Config may have changed: invalidate cached button/text styling so the next update restyles once.
    AuraCooldownsModule.styleGeneration = AuraCooldownsModule.styleGeneration + 1
    AuraCooldownsModule.initialized = true

    if AuraCooldownsModule.applied then
        ScanAllAuraCooldowns()
        return
    end

    InstallAuraHooks()
    RegisterModuleEvents()
    EnsureUpdateFrame():Show()
    AuraCooldownsModule.applied = true

    ScanAllAuraCooldowns()
end

function addon.RestoreAuraCooldownTextSystem()
    local tracked = AuraCooldownsModule.frames.trackedCooldowns
    if tracked then
        for cooldown in pairs(tracked) do
            HideCooldownText(cooldown)
        end
    end

    if AuraCooldownsModule.frames.updateFrame then
        AuraCooldownsModule.frames.updateFrame:Hide()
    end

    for _, entry in ipairs(AuraCooldownsModule.registeredEvents) do
        if entry.frame and entry.frame.UnregisterEvent then
            entry.frame:UnregisterEvent(entry.event)
        end
    end

    if AuraCooldownsModule.frames.eventFrame then
        AuraCooldownsModule.frames.eventFrame:SetScript("OnEvent", nil)
        AuraCooldownsModule.frames.eventFrame = nil
    end

    AuraCooldownsModule.registeredEvents = {}

    AuraCooldownsModule.applied = false
end

function addon.RefreshAuraCooldownTextSystem()
    if IsModuleEnabled() then
        addon.ApplyAuraCooldownTextSystem()
    else
        addon.RestoreAuraCooldownTextSystem()
    end

    -- Size/scale changes must re-run wrap/anchor math and re-anchor the castbar.
    if addon.RefreshTargetFocusAuraLayout then
        addon.RefreshTargetFocusAuraLayout()
    end
end
