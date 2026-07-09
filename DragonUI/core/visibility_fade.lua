-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...);

-- ============================================================================
-- SHARED VISIBILITY FADE ENGINE (hover/combat show-on-hover, show-in-combat)
-- ============================================================================
-- Alpha-only by design: never touches Show/Hide/EnableMouse, so it's safe on secure frames too.

addon.VisibilityFade = addon.VisibilityFade or {}
local VF = addon.VisibilityFade

local registry = {}
local hoverTimers = {}

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function GetConfig(entry)
    return entry.dbTable and entry.dbTable()
end

local function EvaluateShouldShow(cfg, state)
    local showOnHover = cfg.show_on_hover
    local showInCombat = cfg.show_in_combat

    if not showOnHover and not showInCombat then
        return true
    end

    if showOnHover and showInCombat then
        local mode = cfg.visibility_logic == "or" and "or" or "and"
        if mode == "or" then
            return state.hovered or state.inCombat
        end
        return state.hovered and state.inCombat
    end

    if showOnHover then
        return state.hovered
    end

    return state.inCombat
end

local function GetFadeConfig(cfg)
    local shownAlpha = Clamp01(cfg.visibility_shown_alpha == nil and 1 or cfg.visibility_shown_alpha)
    local hiddenAlpha = Clamp01(cfg.visibility_hidden_alpha == nil and 0 or cfg.visibility_hidden_alpha)
    local fadeInDuration = math.max(0, tonumber(cfg.visibility_fade_in_duration) or 0.15)
    local fadeOutDuration = math.max(0, tonumber(cfg.visibility_fade_out_duration) or 0.2)
    local fadeOutDelay = math.max(0, tonumber(cfg.visibility_fade_out_delay) or 0.2)
    return shownAlpha, hiddenAlpha, fadeInDuration, fadeOutDuration, fadeOutDelay
end

local function ApplyAlpha(entry, alpha)
    alpha = Clamp01(alpha)
    for _, frame in ipairs(entry.frames) do
        if frame then
            frame:SetAlpha(alpha)
        end
    end
end

local function FadeToAlpha(entry, targetAlpha, duration)
    targetAlpha = Clamp01(targetAlpha)
    duration = math.max(0, tonumber(duration) or 0)

    local currentAlpha = Clamp01(entry.frames[1] and entry.frames[1]:GetAlpha() or 1)

    if math.abs(currentAlpha - targetAlpha) <= 0.01 or duration <= 0 then
        if entry.driver then entry.driver:SetScript("OnUpdate", nil) end
        ApplyAlpha(entry, targetAlpha)
        return
    end

    entry.driver = entry.driver or CreateFrame("Frame")
    entry.fromAlpha = currentAlpha
    entry.toAlpha = targetAlpha
    entry.duration = duration
    entry.elapsed = 0

    entry.driver:SetScript("OnUpdate", function(self, elapsed)
        entry.elapsed = entry.elapsed + elapsed
        local progress = entry.elapsed / entry.duration
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            ApplyAlpha(entry, entry.toAlpha)
            return
        end
        ApplyAlpha(entry, entry.fromAlpha + ((entry.toAlpha - entry.fromAlpha) * progress))
    end)
end

function VF.Update(key)
    local entry = registry[key]
    if not entry then return end

    local cfg = GetConfig(entry)
    if not cfg then return end

    if not cfg.show_on_hover and not cfg.show_in_combat then
        local _, _, fadeInDuration = GetFadeConfig(cfg)
        FadeToAlpha(entry, 1, fadeInDuration)
        return
    end

    local shouldShow = EvaluateShouldShow(cfg, entry.state)
    local shownAlpha, hiddenAlpha, fadeInDuration, fadeOutDuration = GetFadeConfig(cfg)
    local targetAlpha = shouldShow and shownAlpha or hiddenAlpha
    local duration = shouldShow and fadeInDuration or fadeOutDuration
    FadeToAlpha(entry, targetAlpha, duration)
end

local function OnHoverEnter(key)
    local entry = registry[key]
    if not entry then return end
    if hoverTimers[key] and addon.core and addon.core.CancelTimer then
        addon.core:CancelTimer(hoverTimers[key], true)
        hoverTimers[key] = nil
    end
    entry.state.hovered = true
    VF.Update(key)
end

local function OnHoverLeave(key)
    local entry = registry[key]
    if not entry then return end
    if hoverTimers[key] and addon.core and addon.core.CancelTimer then
        addon.core:CancelTimer(hoverTimers[key], true)
    end
    if not (addon.core and addon.core.ScheduleTimer) then return end
    local cfg = GetConfig(entry)
    local delay = cfg and select(5, GetFadeConfig(cfg)) or 0.2
    hoverTimers[key] = addon.core:ScheduleTimer(function()
        entry.state.hovered = false
        hoverTimers[key] = nil
        VF.Update(key)
    end, delay)
end

local function HookHoverFrame(key, frame, enableMouse)
    if not frame or frame.__DragonUI_VFHoverHooked then return end
    if enableMouse and frame.EnableMouse and not InCombatLockdown() then
        frame:EnableMouse(true)
    end
    frame:HookScript("OnEnter", function() OnHoverEnter(key) end)
    frame:HookScript("OnLeave", function() OnHoverLeave(key) end)
    frame.__DragonUI_VFHoverHooked = true
end

-- hoverFrames defaults to {frame}; enableMouse defaults true (pass false for secure/native-hover frames).
function VF.Register(key, frame, opts)
    if not frame or not opts or not opts.dbTable then return end

    local entry = registry[key]
    if not entry then
        entry = { state = { hovered = false, inCombat = false } }
        registry[key] = entry
    end

    entry.frames = { frame }
    if opts.frames then
        for _, extra in ipairs(opts.frames) do table.insert(entry.frames, extra) end
    end
    entry.dbTable = opts.dbTable

    local hoverFrames = opts.hoverFrames or { frame }
    local enableMouse = opts.enableMouse
    if enableMouse == nil then enableMouse = true end
    for _, hoverFrame in ipairs(hoverFrames) do
        HookHoverFrame(key, hoverFrame, enableMouse)
    end
end

-- Adds more hover-trigger frames to an already-registered key; never touches EnableMouse.
function VF.AddHoverFrames(key, frames)
    if not registry[key] then return end
    for _, f in ipairs(frames) do
        HookHoverFrame(key, f, false)
    end
end

-- Stops any in-flight fade and snaps to alpha (default 1) — use when a module disables itself mid-fade.
function VF.Reset(key, alpha)
    local entry = registry[key]
    if not entry then return end
    if entry.driver then entry.driver:SetScript("OnUpdate", nil) end
    ApplyAlpha(entry, alpha or 1)
end

function VF.RefreshAll()
    for key, entry in pairs(registry) do
        local frame = entry.frames and entry.frames[1]
        if frame and frame.IsMouseOver then
            entry.state.hovered = frame:IsMouseOver()
        end
        VF.Update(key)
    end
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    local inCombat = event == "PLAYER_REGEN_DISABLED"
    for key in pairs(registry) do
        registry[key].state.inCombat = inCombat
        VF.Update(key)
    end
end)
