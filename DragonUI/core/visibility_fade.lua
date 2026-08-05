-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...);

-- ============================================================================
-- SHARED VISIBILITY FADE ENGINE (hover/combat show-on-hover, show-in-combat)
-- ============================================================================
-- Never touches Show/Hide (safe on secure frames); EnableMouse only changes when clickThrough is set.

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
    if cfg.always_hidden then return false end

    local showOnHover = cfg.show_on_hover
    -- hide_in_combat is show_in_combat with inverted polarity — same slot, opposite condition.
    local combatActive = cfg.show_in_combat or cfg.hide_in_combat
    local combatShow
    if cfg.hide_in_combat then
        combatShow = not state.inCombat
    else
        combatShow = state.inCombat
    end

    if not showOnHover and not combatActive then
        return true
    end

    if showOnHover and combatActive then
        local mode = cfg.visibility_logic == "or" and "or" or "and"
        if mode == "or" then
            return state.hovered or combatShow
        end
        return state.hovered and combatShow
    end

    if showOnHover then
        return state.hovered
    end

    return combatShow
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

-- onComplete (optional) fires once the target alpha is actually reached — lets callers defer a
-- visual change (e.g. a texture swap) until it can't be seen happening mid-fade.
local function FadeToAlpha(entry, targetAlpha, duration, onComplete)
    targetAlpha = Clamp01(targetAlpha)
    duration = math.max(0, tonumber(duration) or 0)

    local currentAlpha = Clamp01(entry.frames[1] and entry.frames[1]:GetAlpha() or 1)

    if math.abs(currentAlpha - targetAlpha) <= 0.01 or duration <= 0 then
        if entry.driver then entry.driver:SetScript("OnUpdate", nil) end
        ApplyAlpha(entry, targetAlpha)
        if onComplete then onComplete() end
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
            if onComplete then onComplete() end
            return
        end
        ApplyAlpha(entry, entry.fromAlpha + ((entry.toAlpha - entry.fromAlpha) * progress))
    end)
end

-- EnableMouse is protected in combat on secure frames; mouseSafeInCombat opts in known-safe ones.
-- Even those (e.g. MinimapCluster) can still get blocked in some contexts (PvP) — pcall per frame.
local function ApplyMouseState(entry, cfg, shouldShow)
    if not entry.clickThrough or not entry.hoverFrames then return end
    if InCombatLockdown() and not entry.mouseSafeInCombat then return end
    for _, frame in ipairs(entry.hoverFrames) do
        if frame and frame.EnableMouse then
            pcall(frame.EnableMouse, frame, shouldShow)
        end
    end
end

function VF.Update(key)
    local entry = registry[key]
    if not entry then return end

    if entry.shouldManage and not entry.shouldManage() then
        if entry.driver then entry.driver:SetScript("OnUpdate", nil) end
        entry.state.hovered = false
        return
    end

    local cfg = GetConfig(entry)
    if not cfg then return end

    -- always_hidden annuls hover/combat: fall through to the normal hide path below.
    if not cfg.always_hidden and not cfg.show_on_hover and not cfg.show_in_combat and not cfg.hide_in_combat then
        local _, _, fadeInDuration = GetFadeConfig(cfg)
        ApplyMouseState(entry, cfg, true)
        if entry.onVisibilityChange then entry.onVisibilityChange(true) end
        -- Fire onFadeComplete at full alpha, not now: minimap terrain refresh only takes once actually visible.
        FadeToAlpha(entry, 1, fadeInDuration, function()
            if entry.onFadeComplete then entry.onFadeComplete(true) end
        end)
        return
    end

    local shouldShow = EvaluateShouldShow(cfg, entry.state)
    ApplyMouseState(entry, cfg, shouldShow)

    local shownAlpha, hiddenAlpha, fadeInDuration, fadeOutDuration = GetFadeConfig(cfg)
    local targetAlpha = shouldShow and shownAlpha or hiddenAlpha
    local duration = shouldShow and fadeInDuration or fadeOutDuration
    if shouldShow then
        -- Reveal is safe to apply up front — alpha is still near 0 when this fires, so it's not visible.
        if entry.onVisibilityChange then entry.onVisibilityChange(true) end
        FadeToAlpha(entry, targetAlpha, duration, function()
            if entry.onFadeComplete then entry.onFadeComplete(true) end
        end)
    else
        -- Deferred to fade-out completion by default (immediate would pop while still opaque);
        -- immediateHideCallback opts out for callers that need the opposite timing.
        if entry.immediateHideCallback and entry.onVisibilityChange then
            entry.onVisibilityChange(false)
        end
        FadeToAlpha(entry, targetAlpha, duration, function()
            if not entry.immediateHideCallback and entry.onVisibilityChange then
                entry.onVisibilityChange(false)
            end
            if entry.onFadeComplete then entry.onFadeComplete(false) end
        end)
    end
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

local POLL_INTERVAL = 0.15

-- IsMouseOver() works regardless of EnableMouse, so clickThrough entries poll for hover
-- instead of relying on OnEnter/OnLeave — those stop firing the moment the mouse is disabled.
local function EvaluatePollHover(key, entry)
    local cfg = GetConfig(entry)
    if not cfg or cfg.always_hidden or not cfg.show_on_hover then return end

    local isOver = false
    for _, frame in ipairs(entry.hoverFrames) do
        if frame and frame.IsMouseOver and frame:IsVisible() and frame:IsMouseOver() then
            isOver = true
            break
        end
    end

    if isOver then
        -- Also re-enter mid-debounce, or a blip's pending hide timer never gets cancelled.
        if not entry.state.hovered or hoverTimers[key] then
            OnHoverEnter(key)
        end
    elseif entry.state.hovered and not hoverTimers[key] then
        OnHoverLeave(key)
    end
end

local function StartHoverPoller(key, entry)
    if entry.poller then return end
    entry.poller = CreateFrame("Frame")
    entry.pollElapsed = 0
    entry.poller:SetScript("OnUpdate", function(self, elapsed)
        entry.pollElapsed = entry.pollElapsed + elapsed
        if entry.pollElapsed < POLL_INTERVAL then return end
        entry.pollElapsed = 0
        EvaluatePollHover(key, entry)
    end)
end

-- hoverFrames defaults to {frame}; enableMouse defaults true (pass false for secure/native-hover frames).
-- clickThrough=true lets the mouse pass through these hoverFrames while hidden in combat-only mode.
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
    entry.clickThrough = opts.clickThrough
    entry.pollHover = opts.pollHover
    entry.mouseSafeInCombat = opts.mouseSafeInCombat
    entry.shouldManage = opts.shouldManage
    entry.onVisibilityChange = opts.onVisibilityChange
    entry.onFadeComplete = opts.onFadeComplete
    entry.immediateHideCallback = opts.immediateHideCallback

    -- Merge (not replace): overwriting here would silently drop frames added later via
    -- AddHoverFrames the next time this key re-registers (e.g. a settings change).
    local hoverFrames = opts.hoverFrames or { frame }
    entry.hoverFrames = entry.hoverFrames or {}
    local enableMouse = opts.enableMouse
    if enableMouse == nil then enableMouse = true end
    for _, hoverFrame in ipairs(hoverFrames) do
        HookHoverFrame(key, hoverFrame, enableMouse)
        if hoverFrame and not hoverFrame.__DragonUI_VFTracked then
            table.insert(entry.hoverFrames, hoverFrame)
            hoverFrame.__DragonUI_VFTracked = true
        end
    end

    if entry.clickThrough or entry.pollHover then
        StartHoverPoller(key, entry)
    end
end

-- Adds more hover-trigger frames to an already-registered key; never forces EnableMouse(true),
-- but still tracks them so click-through management (ApplyMouseState) covers them too.
function VF.AddHoverFrames(key, frames)
    local entry = registry[key]
    if not entry then return end
    entry.hoverFrames = entry.hoverFrames or {}
    for _, f in ipairs(frames) do
        HookHoverFrame(key, f, false)
        if f and not f.__DragonUI_VFTracked then
            table.insert(entry.hoverFrames, f)
            f.__DragonUI_VFTracked = true
        end
    end
end

-- Stops any in-flight fade and snaps to alpha (default 1) — use when a module disables itself mid-fade.
function VF.Reset(key, alpha)
    local entry = registry[key]
    if not entry then return end
    if entry.driver then entry.driver:SetScript("OnUpdate", nil) end
    ApplyAlpha(entry, alpha or 1)
    if entry.clickThrough and entry.hoverFrames and (entry.mouseSafeInCombat or not InCombatLockdown()) then
        for _, frame in ipairs(entry.hoverFrames) do
            if frame and frame.EnableMouse then frame:EnableMouse(true) end
        end
    end
end

-- Full teardown on module disable: Reset leaves the hover poller ticking; this drops the entry.
function VF.Unregister(key)
    local entry = registry[key]
    if not entry then return end
    if hoverTimers[key] and addon.core and addon.core.CancelTimer then
        addon.core:CancelTimer(hoverTimers[key], true)
        hoverTimers[key] = nil
    end
    if entry.driver then entry.driver:SetScript("OnUpdate", nil) end
    if entry.poller then entry.poller:SetScript("OnUpdate", nil) end
    ApplyAlpha(entry, 1)
    registry[key] = nil
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
    for key, entry in pairs(registry) do
        entry.state.inCombat = inCombat
        VF.Update(key)
        -- EnableMouse is protected mid-combat on secure buttons; ApplyMouseState honours mouseSafeInCombat.
        if inCombat and entry.clickThrough and entry.hoverFrames then
            local cfg = GetConfig(entry)
            if cfg and not cfg.always_hidden and (cfg.show_in_combat or cfg.show_on_hover) then
                ApplyMouseState(entry, cfg, true)
            end
        end
    end
end)
