-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI - Cooldown Text Module
-- Displays countdown timers on action buttons via metatable hooking.
-- ============================================================================

local addon = select(2, ...)
local L = addon.L
local unpack = unpack
local ceil = math.ceil
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc

local CooldownsModule = {
    initialized = false,
    applied = false,
    hooks = {},
}
addon.CooldownsModule = CooldownsModule

if addon.RegisterModule then
    addon:RegisterModule("cooldowns", CooldownsModule,
        L["Cooldown Text"],
        L["Cooldown text on action buttons"])
end

-- Create a table within the main addon object to hold our functions
addon.CooldownText = {}

-- Tenths are only drawn under 5s; above that the text changes once a second.
local TICK_FAST, TICK_SLOW = 0.05, 0.25

local COUNTDOWN_STEPS = {
    { ceiling = 5, decimals = '%.1f', rgb = { 1, 0, 0.2 } },
    { ceiling = 60, per = 1, unit = '', rgb = { 1, 1, 0 } },
    { ceiling = 3600, per = 60, unit = 'm' },
    { ceiling = math.huge, per = 3600, unit = 'h', shade = 0.7 },
}

local DEFAULT_TEXT_ANCHOR = { 'CENTER', 0, 1 }
local NO_FONT = {}

local function StepFor(secondsLeft)
    for _, step in ipairs(COUNTDOWN_STEPS) do
        if secondsLeft <= step.ceiling then
            return step
        end
    end
end

local function PaintCountdown(label, step, secondsLeft, dbColor)
    if step.decimals then
        label:SetText(step.decimals:format(secondsLeft))
    else
        label:SetText(ceil(secondsLeft / step.per) .. step.unit)
    end
    local rgb, shade = step.rgb, step.shade
    if rgb then
        label:SetTextColor(rgb[1], rgb[2], rgb[3])
    elseif shade then
        local r, g, b, a = unpack(dbColor)
        label:SetTextColor(r * shade, g * shade, b * shade, a)
    else
        label:SetTextColor(unpack(dbColor))
    end
end

local function StopCountdown(cooldown, blankText)
    cooldown.remain = nil
    local label = cooldown.text
    if label then
        label:Hide()
        if blankText then
            label:SetText('')
        end
    end
end

function addon.CooldownText:UpdateText(elapsed)
    if not self:GetParent().action or not self.remain then
        return
    end

    local wait = (self.duiNextTick or 0) - (elapsed or 0)
    if wait > 0 then
        self.duiNextTick = wait
        return
    end

    local secondsLeft = self.remain - GetTime()
    self.duiNextTick = (secondsLeft <= 5) and TICK_FAST or TICK_SLOW

    if secondsLeft <= 0 then
        StopCountdown(self, true)
        return
    end

    local settings = addon.db.profile.buttons.cooldown
    if settings == nil then
        return
    end
    PaintCountdown(self.text, StepFor(secondsLeft), secondsLeft, settings.color)
end

function addon.CooldownText:CreateText()
    -- The template guarantees a font even when the SetFont path below fails on this locale.
    local label = self:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    label:SetFont(addon.Fonts.ACTIONBAR, 16, 'OUTLINE')
    label:SetPoint('CENTER', self, 'CENTER')
    self.text = label
    self:SetScript('OnUpdate', addon.CooldownText.UpdateText)
    return label
end

function addon.CooldownText:OnSetCooldown(start, duration)
    -- Only process action button cooldowns, not buff/debuff cooldowns.
    -- The metatable hook fires for ALL CooldownFrame:SetCooldown calls.
    -- Buff frames lack .action, and processing them causes unnecessary
    -- SetPoint/Show calls that interfere with the sweep animation.
    if not self:GetParent() or not self:GetParent().action then
        return
    end

    -- Skip redundant calls with identical cooldown values.
    -- This prevents unnecessary text updates (and visual flicker) when
    -- e.g. TargetFrame_UpdateAuras re-fires SetTimer with the same values.
    if self._dui_cdStart == start and self._dui_cdDur == duration then
        return
    end
    self._dui_cdStart = start
    self._dui_cdDur   = duration

    local moduleDb = addon.db.profile.modules.cooldowns
    local db = addon.db.profile.buttons.cooldown
    if not db then
        return
    end

    if type(start) ~= 'number' or type(duration) ~= 'number' then
        return
    end

    -- Defensive normalization: some environments/addons can feed SetCooldown
    -- with a start value from a different clock base than GetTime().
    -- If remaining time is much larger than duration, keep duration and
    -- rebase start to the local clock to avoid absurd values (e.g. 1194h).
    if start > 0 and duration > 0 then
        local now = GetTime()
        local remaining = (start + duration) - now
        if remaining > (duration + 2) then
            start = now
        end
    end

    local showText = moduleDb.enabled and start > 0 and duration > db.min_duration
    if not showText then
        StopCountdown(self)
        return
    end

    self.remain = start + duration
    self.duiNextTick = 0
    local label = self.text or addon.CooldownText.CreateText(self)
    local font = db.font or NO_FONT
    label:SetFont(font[1] or addon.Fonts.ACTIONBAR, db.font_size or font[2] or 16, font[3] or 'OUTLINE')
    -- No ClearAllPoints: the DB point is layered on top of CreateText's CENTER anchor.
    label:SetPoint(unpack(db.position or DEFAULT_TEXT_ANCHOR))
    label:Show()
end

function addon.RefreshCooldowns()
    if not addon.buttons_iterator then
        return
    end
    local moduleDb = addon.db.profile.modules.cooldowns
    local db = addon.db.profile.buttons.cooldown
    if not db then
        return
    end

    for button in addon.buttons_iterator() do
        if button then
            local cooldown = _G[button:GetName() .. 'Cooldown']
            if cooldown then
                -- Update existing text font settings
                if cooldown.text then
                    local fontPath = db.font and db.font[1]
                    cooldown.text:SetFont(
                        fontPath or addon.Fonts.ACTIONBAR,
                        db.font_size or (db.font and db.font[2]) or 16,
                        (db.font and db.font[3]) or 'OUTLINE'
                    )

                    -- If cooldowns are disabled, hide the text
                    if not moduleDb.enabled then
                        cooldown.text:Hide()
                    end
                end

                -- Refresh active cooldowns or force check if cooldowns are enabled
                if cooldown.GetCooldown then
                    local start, duration = cooldown:GetCooldown()
                    if start and start > 0 then
                        -- Always reapply cooldown to update settings
                        addon.CooldownText.OnSetCooldown(cooldown, start, duration)
                    elseif moduleDb.enabled and cooldown.text then
                        -- If cooldowns are enabled but no active cooldown, ensure text is hidden
                        cooldown.text:Hide()
                        cooldown.remain = nil
                    end
                end
            end
        end
    end
end


-- Called from core.lua to ensure the hook is applied only once at the right time
local isHooked = false
function addon.InitializeCooldowns()
    if isHooked then return end
    
    if not _G.ActionButton1Cooldown then

        return
    end
    
    -- One hook on the shared widget method table sees every Cooldown's SetCooldown.
    local widgetMeta = getmetatable(_G.ActionButton1Cooldown)
    local cooldownMethods = widgetMeta and widgetMeta.__index
    if type(cooldownMethods) == 'table' and cooldownMethods.SetCooldown then
        hooksecurefunc(cooldownMethods, 'SetCooldown', addon.CooldownText.OnSetCooldown)
        isHooked = true
    end

    -- =========================================================================
    -- BUFF/DEBUFF SWEEP ANIMATION PROTECTION (taint-safe)
    -- =========================================================================
    -- When TargetFrame_UpdateAuras runs (e.g. on target change, UNIT_AURA),
    -- it calls CooldownFrame_SetTimer → :SetCooldown() for EVERY buff/debuff,
    -- even when start/duration haven't changed.  Each :SetCooldown() resets
    -- the sweep animation to 12-o'clock, causing a visible flash.
    --
    -- We CANNOT replace the global CooldownFrame_SetTimer (causes taint on
    -- secure action button code paths).  Instead we replace :SetCooldown()
    -- on individual buff/debuff cooldown frame INSTANCES.  These frames are
    -- NOT secure, so the replacement doesn't propagate taint to action bars.
    -- =========================================================================
    local MAX_TARGET_BUFFS  = 32
    local MAX_TARGET_DEBUFFS = 16

    local function ProtectCooldownSweep(cd)
        if not cd or cd._dui_sweepProtected then return end
        local origSetCooldown = cd.SetCooldown
        if not origSetCooldown then return end

        cd.SetCooldown = function(self, start, duration, ...)
            if self._dui_cdStart == start and self._dui_cdDur == duration then
                return  -- identical values → skip → sweep continues smoothly
            end
            self._dui_cdStart = start
            self._dui_cdDur   = duration
            return origSetCooldown(self, start, duration, ...)
        end
        cd._dui_sweepProtected = true
    end

    -- Scan and protect all existing aura cooldown frames for a given parent
    local function ProtectAuraCooldownsForFrame(frameName)
        for i = 1, MAX_TARGET_BUFFS do
            ProtectCooldownSweep(_G[frameName .. "Buff" .. i .. "Cooldown"])
        end
        for i = 1, MAX_TARGET_DEBUFFS do
            ProtectCooldownSweep(_G[frameName .. "Debuff" .. i .. "Cooldown"])
        end
    end

    -- Hook TargetFrame_UpdateAuras: Blizzard may create buff frames lazily,
    -- so we re-scan after each call to catch any new cooldown frames.
    if _G.TargetFrame_UpdateAuras then
        hooksecurefunc("TargetFrame_UpdateAuras", function(self)
            local name = self and self.GetName and self:GetName()
            if name then
                ProtectAuraCooldownsForFrame(name)
            end
        end)
    end

    -- Also scan immediately for any frames that already exist at init time
    ProtectAuraCooldownsForFrame("TargetFrame")
    ProtectAuraCooldownsForFrame("FocusFrame")
end

