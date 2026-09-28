-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local floor, max, min = math.floor, math.max, math.min
local GetPVPDesired = _G.GetPVPDesired

local art, flame, glow, swords, ring, catcher
local glowGoal = 0

-- Fire cells are 96x84 on 1024x512 and smoke cells 48x42 on 512x256, ten per row.
local FLAME_FRAMES, FLAME_FPS, FLAME_COLS = 58, 20, 10
local IGNITE_TIME, DOUSE_TIME = 1.234, 0.6

local function pvpOn()
    local desired = GetPVPDesired()
    return desired == 1 or desired == true
end

-- Flame -------------------------------------------------------------------------------------------

local function flameCell(tex, frame, cellW, cellH, sheetW, sheetH)
    local x = (frame % FLAME_COLS) * cellW
    local y = floor(frame / FLAME_COLS) * cellH
    tex:SetTexCoord(x / sheetW, (x + cellW) / sheetW, y / sheetH, (y + cellH) / sheetH)
end

local function stepFlame(self, elapsed)
    self.clock = self.clock + elapsed
    local frame = floor(self.clock * FLAME_FPS) % FLAME_FRAMES
    if frame ~= self.frame then
        self.frame = frame
        flameCell(self.fire, frame, 96, 84, 1024, 512)
        flameCell(self.smoke, frame, 48, 42, 512, 256)
    end
    local ramp = self.ramp
    if not ramp then return end
    ramp.spent = ramp.spent + elapsed
    local share = ramp.length > 0 and min(1, ramp.spent / ramp.length) or 1
    self:SetAlpha(ramp.from + (ramp.to - ramp.from) * share)
    if share < 1 then return end
    self.ramp = nil
    if ramp.to <= 0 then self:Hide() end
end

local function fadeFlame(to, length)
    flame.ramp = { from = flame:GetAlpha(), to = to, length = max(0, length), spent = 0 }
end

local function dousing()
    return flame.ramp ~= nil and flame.ramp.to <= 0
end

local function ignite()
    if not flame:IsShown() then
        flame:SetAlpha(0)
        flame:Show()
        fadeFlame(1, IGNITE_TIME)
    elseif dousing() then
        fadeFlame(1, IGNITE_TIME * (1 - flame:GetAlpha()))
    end
end

local function douse()
    if flame:IsShown() and not dousing() then
        fadeFlame(0, DOUSE_TIME * flame:GetAlpha())
    end
end

function ns.RefreshOrbState()
    if not art then return end
    local on = pvpOn()
    local suffix = on and "" or "-disabled"
    swords:SetAtlasTexture("pvptalents-warmode-swords" .. suffix, true)
    ring:SetAtlasTexture("talents-warmode-ring" .. suffix)
    ring:SetSize(94, 100)
    if on then ignite() else douse() end
end

-- Hover glow --------------------------------------------------------------------------------------

local function stepGlow(_, elapsed)
    local alpha = glow:GetAlpha()
    if alpha < glowGoal then
        alpha = min(glowGoal, alpha + elapsed * 0.75 / 0.2)
    elseif alpha > glowGoal then
        alpha = max(glowGoal, alpha - elapsed * 0.75 / 0.3)
    end
    glow:SetAlpha(alpha)
    if alpha <= 0 then glow:Hide() else glow:Show() end
end

local function catcherTooltip(owner)
    local state = pvpOn() and { L["Enabled — click to toggle"], 0.13, 1, 0.13 }
        or { L["Disabled — click to toggle"], 1, 0.25, 0.25 }
    ns.Tip(owner, "ANCHOR_LEFT", { PVP, 1, 1, 1 }, state)
end

-- Secure catcher ----------------------------------------------------------------------------------

-- On UIParent: a secure frame parented or anchored to the window would make the window protected.
local function buildCatcher()
    if catcher then return end
    catcher = CreateFrame("Button", "DragonUI_TalentPvPToggle", UIParent, "SecureActionButtonTemplate")
    catcher:SetAttribute("type", "macro")
    catcher:SetAttribute("macrotext", "/pvp")
    catcher:SetFrameStrata("HIGH")
    catcher:RegisterForClicks("LeftButtonUp")
    catcher:Hide()
    catcher:SetScript("OnEnter", function(self)
        glowGoal = 0.75
        catcherTooltip(self)
    end)
    catcher:SetScript("OnLeave", function()
        glowGoal = 0
        GameTooltip_Hide()
    end)
    -- The desired flag settles a moment after the slash command runs.
    catcher:SetScript("PostClick", function(self)
        addon:After(0.2, ns.RefreshOrbState)
        addon:After(0.6, function()
            ns.RefreshOrbState()
            if GameTooltip:IsOwned(self) then catcherTooltip(self) end
        end)
    end)
end

function ns.HideCatcher()
    if catcher and not InCombatLockdown() then catcher:Hide() end
end

function ns.PlaceCatcher()
    if not catcher or InCombatLockdown() or ns.dragging then return end
    local x, y
    if art and art:IsVisible() then x, y = art:GetCenter() end
    if not x then
        catcher:Hide()
        return
    end
    local ratio = art:GetEffectiveScale() / UIParent:GetEffectiveScale()
    catcher:ClearAllPoints()
    catcher:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
    catcher:SetSize(art:GetWidth() * ratio, art:GetHeight() * ratio)
    catcher:SetFrameLevel(art:GetFrameLevel() + 5)
    catcher:Show()
end

-- The window is toplevel and re-levels itself on every click, so the catcher is checked on a poll.
local function watchCatcher(self, elapsed)
    self.wait = self.wait + elapsed
    if self.wait < 0.25 then return end
    self.wait = 0
    if not catcher then return end
    if not catcher:IsShown() or catcher:GetFrameLevel() <= self:GetFrameLevel() then ns.PlaceCatcher() end
end

function ns.ShowOrb(shown)
    if not art then return end
    local was = art:IsShown()
    art:SetShownCompat(shown)
    if shown and not was and ns.win:IsShown() then ns.RefreshOrbState() end
end

function ns.OrbWindowShown()
    if art and art:IsShown() then ns.RefreshOrbState() end
end

-- Construction ------------------------------------------------------------------------------------

function ns.BuildOrb(win, level)
    art = CreateFrame("Frame", nil, win)
    art:SetSize(100, 100)
    art:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 0)
    art:SetFrameLevel(level)
    art.wait = 0

    local indent = art:CreateTexture(nil, "BACKGROUND")
    indent:SetAtlasTexture("talents-warmode-indent", true)
    indent:SetPoint("BOTTOM", art, "BOTTOM", 0, 6)
    swords = art:CreateTexture(nil, "BORDER", nil, 0)
    swords:SetAtlasTexture("pvptalents-warmode-swords", true)
    swords:SetPoint("BOTTOM", art, "BOTTOM", 0, 39)
    local orb = art:CreateTexture(nil, "BORDER", nil, 1)
    orb:SetAtlasTexture("pvptalents-warmode-orb", true)
    orb:SetPoint("BOTTOM", art, "BOTTOM", 0, 14)
    orb:SetAlpha(0.4)

    flame = CreateFrame("Frame", nil, art)
    flame:SetFrameLevel(level + 1)
    flame:SetSize(96, 84)
    flame:SetPoint("BOTTOM", art, "BOTTOM", 2, 18)
    flame.fire = flame:CreateTexture(nil, "ARTWORK", nil, 1)
    flame.fire:SetTexture(addon._dir .. "Talents\\talents-warmode-flame")
    flame.fire:SetBlendMode("ADD")
    flame.fire:SetAllPoints(flame)
    flame.smoke = flame:CreateTexture(nil, "ARTWORK", nil, 2)
    flame.smoke:SetTexture(addon._dir .. "Talents\\talents-warmode-smoke")
    flame.smoke:SetAllPoints(flame)
    flame.clock, flame.frame = 0, -1
    flame:SetScript("OnUpdate", stepFlame)
    flame:Hide()

    local holder = CreateFrame("Frame", nil, art)
    holder:SetFrameLevel(level + 2)
    holder:SetAllPoints(art)
    ring = holder:CreateTexture(nil, "ARTWORK")
    ring:SetAtlasTexture("talents-warmode-ring")
    ring:SetSize(94, 100)
    ring:SetPoint("BOTTOM", art, "BOTTOM", 0, 5)
    glow = holder:CreateTexture(nil, "OVERLAY")
    glow:SetAtlasTexture("pvptalents-warmode-glow", true)
    glow:SetPoint("CENTER", orb, "CENTER", 0, 0)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    glow:Hide()
    holder:SetScript("OnUpdate", stepGlow)

    art:SetScript("OnUpdate", watchCatcher)
    art:SetScript("OnHide", function()
        glowGoal = 0
        glow:SetAlpha(0)
        glow:Hide()
    end)

    addon:SafeExecute("talents", "pvp_catcher", buildCatcher)
end

local function onFlags(event, unit)
    if not ns.win or not ns.win:IsShown() then return end
    if event == "UNIT_FACTION" and unit and unit ~= "player" then return end
    ns.RefreshOrbState()
end

function ns.InstallOrbEvents()
    ns.Listen("PLAYER_FLAGS_CHANGED", onFlags)
    ns.Listen("UNIT_FACTION", onFlags)
    -- Last chance to hide it: a window closed mid-fight must not leave a live /pvp spot.
    ns.Listen("PLAYER_REGEN_DISABLED", function()
        if catcher then catcher:Hide() end
    end)
    ns.Listen("PLAYER_REGEN_ENABLED", function() ns.PlaceCatcher() end)
end
