-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

-- Retail's WarmodeButtonTemplate as New Era lays it out: indent < swords < orb < flame < ring.
local FIRE = addon._dir .. "Talents\\talents-warmode-flame"
local SMOKE = addon._dir .. "Talents\\talents-warmode-smoke"
local FLAME_W, FLAME_H = 96, 84
local FLAME_FRAMES, FLAME_FPS, CELL_COLS = 58, 20, 10
-- Fire keeps full resolution; the smoke is soft enough to ship at half.
local FIRE_SHEET = { cellW = 96, cellH = 84, w = 1024, h = 512 }
local SMOKE_SHEET = { cellW = 48, cellH = 42, w = 512, h = 256 }
local FADE_IN, FADE_OUT = 1.234, 0.6
-- The glow is additive: at full alpha it blows the orb out.
local GLOW_PEAK, GLOW_FADE_IN, GLOW_FADE_OUT = 0.75, 0.2, 0.3

local function isOn()
    return GetPVPDesired() == 1
end

-- The flame is New Era's three-layer M2 recipe baked into a flipbook: a fire layer and a smoke layer.
local function cellCoords(sheet, index)
    local col = index % CELL_COLS
    local row = math.floor(index / CELL_COLS)
    local l, t = col * sheet.cellW / sheet.w, row * sheet.cellH / sheet.h
    return l, l + sheet.cellW / sheet.w, t, t + sheet.cellH / sheet.h
end

local function buildFlame(parent)
    local fl = CreateFrame("Frame", nil, parent)
    fl:SetFrameLevel(parent:GetFrameLevel() + 1)
    fl:SetSize(FLAME_W, FLAME_H)
    fl:SetPoint("BOTTOM", parent, "BOTTOM", 2, 18)
    fl.fire = fl:CreateTexture(nil, "ARTWORK", nil, 1)
    fl.fire:SetTexture(FIRE)
    fl.fire:SetBlendMode("ADD")
    fl.fire:SetAllPoints(fl)
    fl.smoke = fl:CreateTexture(nil, "ARTWORK", nil, 2)
    fl.smoke:SetTexture(SMOKE)
    fl.smoke:SetAllPoints(fl)
    fl.t = 0
    fl:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        local frame = math.floor(self.t * FLAME_FPS) % FLAME_FRAMES
        if frame ~= self.frame then
            self.frame = frame
            self.fire:SetTexCoord(cellCoords(FIRE_SHEET, frame))
            self.smoke:SetTexCoord(cellCoords(SMOKE_SHEET, frame))
        end
        local fade = self.fade
        if fade then
            fade.t = fade.t + elapsed
            local k = fade.dur > 0 and fade.t / fade.dur or 1
            if k >= 1 then
                self:SetAlpha(fade.to)
                self.fade = nil
                if fade.to == 0 then self:Hide() end
            else
                self:SetAlpha(fade.from + (fade.to - fade.from) * k)
            end
        end
    end)
    fl:Hide()

    function fl:SetIgnite(on)
        if on then
            if not self:IsShown() then
                self:SetAlpha(0)
                self.fade = { t = 0, from = 0, to = 1, dur = FADE_IN }
                self:Show()
            elseif self.fade and self.fade.to == 0 then
                local a = self:GetAlpha()
                self.fade = { t = 0, from = a, to = 1, dur = FADE_IN * (1 - a) }
            end
        elseif self:IsShown() and not (self.fade and self.fade.to == 0) then
            local a = self:GetAlpha()
            self.fade = { t = 0, from = a, to = 0, dur = FADE_OUT * a }
        end
    end
    return fl
end

-- ============================================================================
-- Art (insecure, on the window) + click catcher (secure, on UIParent)
-- ============================================================================
-- TogglePVP is protected; the /pvp button lives on UIParent so the window never turns protected.
local catcher

local function tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(PVP, 1, 1, 1)
    if isOn() then
        GameTooltip:AddLine(L["Enabled — click to toggle"], 0.13, 1, 0.13)
    else
        GameTooltip:AddLine(L["Disabled — click to toggle"], 1, 0.25, 0.25)
    end
    GameTooltip:Show()
end

function T.UpdatePvP()
    local f = T.frame
    if not (f and f.pvp) then return end
    local on = isOn()
    f.pvp.swords:set_atlas(on and "pvptalents-warmode-swords" or "pvptalents-warmode-swords-disabled", true)
    f.pvp.ring:set_atlas(on and "talents-warmode-ring" or "talents-warmode-ring-disabled")
    f.pvp.flame:SetIgnite(on)
end

local function placeCatcher()
    local art = T.frame and T.frame.pvp
    if not (catcher and art) or InCombatLockdown() or T.frame._duiDragging then return end
    local want = art:IsVisible()
    if want then
        local x, y = art:GetCenter()
        if not x then want = false else
            local ratio = art:GetEffectiveScale() / UIParent:GetEffectiveScale()
            catcher:ClearAllPoints()
            catcher:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
            catcher:SetSize(art:GetWidth() * ratio, art:GetHeight() * ratio)
            -- The window is toplevel and climbs its strata on every click; the catcher has to stay above it.
            catcher:SetFrameLevel(art:GetFrameLevel() + 5)
        end
    end
    catcher:SetShownReq(want)
end
T.PlacePvPCatcher = placeCatcher

function T.RefreshPvP(visible)
    local f = T.frame
    if not (f and f.pvp) then return end
    f.pvp:SetShownReq(visible)
    if visible then T.UpdatePvP() end
    placeCatcher()
end

T.OnBuild(function(f)
    local pvp = CreateFrame("Frame", nil, f)
    pvp:SetSize(100, 100)
    pvp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 0)
    pvp:SetFrameLevel(f:GetFrameLevel() + 9)

    pvp.indent = pvp:CreateTexture(nil, "BACKGROUND")
    pvp.indent:set_atlas("talents-warmode-indent", true)
    pvp.indent:SetPoint("BOTTOM", 0, 6)
    pvp.swords = pvp:CreateTexture(nil, "BORDER", nil, 0)
    pvp.swords:set_atlas("pvptalents-warmode-swords", true)
    pvp.swords:SetPoint("BOTTOM", 0, 39)
    pvp.orb = pvp:CreateTexture(nil, "BORDER", nil, 1)
    pvp.orb:set_atlas("pvptalents-warmode-orb", true)
    pvp.orb:SetPoint("BOTTOM", 0, 14)
    pvp.orb:SetAlpha(0.4)
    pvp.flame = buildFlame(pvp)

    -- The ring frames the fire, so it sits on its own frame above the flame's.
    local ringHost = CreateFrame("Frame", nil, pvp)
    ringHost:SetAllPoints(pvp)
    ringHost:SetFrameLevel(pvp:GetFrameLevel() + 2)
    pvp.ring = ringHost:CreateTexture(nil, "ARTWORK")
    pvp.ring:SetSize(94, 100)
    pvp.ring:SetPoint("BOTTOM", pvp, "BOTTOM", 0, 5)
    pvp.glow = ringHost:CreateTexture(nil, "OVERLAY")
    pvp.glow:set_atlas("pvptalents-warmode-glow", true)
    pvp.glow:SetPoint("CENTER", pvp.orb, "CENTER")
    pvp.glow:SetBlendMode("ADD")
    pvp.glow:SetAlpha(0)
    pvp.glow:Hide()
    local glowAlpha, glowTarget = 0, 0
    local function stepGlow(_, elapsed)
        local rate = GLOW_PEAK / (glowTarget > glowAlpha and GLOW_FADE_IN or GLOW_FADE_OUT)
        if glowTarget > glowAlpha then
            glowAlpha = math.min(glowTarget, glowAlpha + elapsed * rate)
        else
            glowAlpha = math.max(glowTarget, glowAlpha - elapsed * rate)
        end
        pvp.glow:SetAlpha(glowAlpha)
        if glowAlpha == glowTarget then
            ringHost:SetScript("OnUpdate", nil)
            if glowAlpha == 0 then pvp.glow:Hide() end
        end
    end
    function pvp:FadeGlow(on)
        glowTarget = on and GLOW_PEAK or 0
        if glowAlpha == glowTarget then return end
        pvp.glow:Show()
        ringHost:SetScript("OnUpdate", stepGlow)
    end
    pvp:SetScript("OnHide", function()
        glowAlpha, glowTarget = 0, 0
        ringHost:SetScript("OnUpdate", nil)
        pvp.glow:SetAlpha(0)
        pvp.glow:Hide()
    end)
    f.pvp = pvp

    catcher = CreateFrame("Button", "DragonUI_TalentPvPToggle", UIParent, "SecureActionButtonTemplate")
    catcher:SetAttribute("type", "macro")
    catcher:SetAttribute("macrotext", "/pvp")
    catcher:SetFrameStrata(f:GetFrameStrata())
    catcher:Hide()
    catcher:HookScript("OnEnter", function(self)
        pvp:FadeGlow(true)
        tooltip(self)
    end)
    catcher:HookScript("OnLeave", function()
        pvp:FadeGlow(false)
        GameTooltip:Hide()
    end)
    catcher:HookScript("PostClick", function(self)
        -- The desired flag settles a moment after the slash command runs.
        addon:After(0.2, T.UpdatePvP)
        addon:After(0.6, function()
            T.UpdatePvP()
            if GameTooltip:IsOwned(self) then tooltip(self) end
        end)
    end)

    f:HookScript("OnHide", function()
        if catcher:IsShown() and not InCombatLockdown() then catcher:Hide() end
    end)
    f:HookScript("OnDragStart", function()
        f._duiDragging = true
        if not InCombatLockdown() then catcher:Hide() end
    end)
    f:HookScript("OnDragStop", function()
        f._duiDragging = nil
        placeCatcher()
    end)
    f:HookScript("OnMouseDown", function() addon:After(0, placeCatcher) end)
    -- The first open has no layout yet, and a click on any child raises the window without telling us.
    local acc = 0
    pvp:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        if acc < 0.25 then return end
        acc = 0
        if not catcher:IsShown() or catcher:GetFrameLevel() <= self:GetFrameLevel() then placeCatcher() end
    end)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_FLAGS_CHANGED")
events:RegisterEvent("UNIT_FACTION")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if not (T.applied and catcher) then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Last moment it can be hidden: closing the window mid-fight must not leave a live /pvp spot behind.
        catcher:Hide()
    elseif event == "PLAYER_REGEN_ENABLED" or event == "UI_SCALE_CHANGED" then
        placeCatcher()
    elseif unit == nil or unit == "player" then
        if T.frame:IsShown() then T.UpdatePvP() end
    end
end)
