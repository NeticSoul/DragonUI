-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

local min, max, floor = math.min, math.max, math.floor
local GetTime, GetSpellCooldown = GetTime, GetSpellCooldown

local KEY = "gcd"
-- Spell 61304 is the client's own GCD timer: haste, 1 s GCDs and cast-time starts come for free.
local SPELL_ID = 61304
-- Blizzard's cast bar border art rises above its 13 px bar, so the indicator clears it by more.
local GAP, BLIZZARD_GAP = 4, 8
local MOVER_MIN_HEIGHT = 16

local CASTBAR_ART = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\"
local SOLID = "Interface\\Buttons\\WHITE8X8"
-- crop = the square, fully opaque core {l, r, t, b}; those fills also vary along x, so they need it per frame.
local FILLS = {
    castbar = { file = CASTBAR_ART .. "CastingBarStandard2", crop = { 10 / 512, 502 / 512, 4 / 32, 28 / 32 } },
    classic = { file = "Interface\\TargetingFrame\\UI-StatusBar" },
    flat = { file = SOLID },
    smooth = { file = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\bar-fill", crop = { 12 / 512, 502 / 512, 2 / 32, 30 / 32 } },
}
local CASTBAR_BG = { 8 / 1024, 416 / 1024, 188 / 512, 214 / 512 }

local GCD = { initialized = false, applied = false, lift = 0 }

-- Settings stay under castbar.gcd and widgets.gcd so saved profiles and position presets keep working.
local function GetConfig()
    local cfg = addon.db and addon.db.profile and addon.db.profile.castbar
    local gcfg = cfg and cfg.gcd
    return gcfg and gcfg.enabled and gcfg or nil
end

if addon.RegisterModule then
    addon:RegisterModule(KEY, GCD,
        L["GCDAnchor"],
        L["Show a bar above the player cast bar that fills while the global cooldown runs."], {
        lifecyclePrefix = "GCD",
        isEnabled = function() return GetConfig() ~= nil end,
    })
end

local function GetWidget(create)
    local widgets = addon.db and addon.db.profile and addon.db.profile.widgets
    if widgets and create and not widgets.gcd then
        widgets.gcd = {}
    end
    return widgets and widgets.gcd
end

local function IsCustomPlaced()
    local widget = GetWidget()
    return widget and widget.custom_position and widget.posX ~= nil and widget.posY ~= nil or false
end

-- The DragonUI player cast bar while it is on, Blizzard's own otherwise.
local function GetHost()
    local cfg = addon.db.profile.castbar
    if cfg.enabled then
        local frames = addon.CastbarModule and addon.CastbarModule.frames.player
        return frames and frames.container, cfg.sizeX or 200, cfg.scale or 1, GAP
    end
    return CastingBarFrame, CastingBarFrame:GetWidth(), 1, BLIZZARD_GAP
end

-- 3.3.5a stretches a StatusBar fill across the filled width; cropping keeps the art at its real proportions.
local function SetProgress(progress)
    GCD.bar:SetValue(progress)
    local crop, fill = GCD.crop, GCD.bar:GetStatusBarTexture()
    if crop and fill then
        fill:SetTexCoord(crop[1], crop[1] + (crop[2] - crop[1]) * max(progress, 0.001), crop[3], crop[4])
    end
end

local function ShowIdle()
    local gcfg = GetConfig()
    SetProgress(0)
    GCD.spark:Hide()
    if gcfg and gcfg.alwaysShow then
        GCD.bar:Show()
    else
        GCD.bar:Hide()
    end
end

local function OnUpdate(bar)
    local elapsed = GetTime() - GCD.start
    if elapsed >= GCD.duration then
        GCD.start = nil
        bar:SetScript("OnUpdate", nil)
        ShowIdle()
    else
        SetProgress(elapsed / GCD.duration)
    end
end

local function Read()
    if addon.EditorMode and addon.EditorMode:IsActive() then
        return
    end
    local start, duration = GetSpellCooldown(SPELL_ID)
    if start and duration and duration > 0 and start + duration > GetTime() then
        GCD.start, GCD.duration = start, duration
        GCD.bar:SetScript("OnUpdate", OnUpdate)
        GCD.bar:Show()
        if GCD.sparkOn then GCD.spark:Show() end
        OnUpdate(GCD.bar)
    elseif GCD.start then
        GCD.start = nil
        GCD.bar:SetScript("OnUpdate", nil)
        ShowIdle()
    end
end

local function ApplyLook(gcfg)
    local bar, bg = GCD.bar, GCD.bg
    local fill = FILLS[gcfg.style] or FILLS.castbar
    if GCD.fill ~= fill then
        GCD.fill, GCD.crop = fill, fill.crop
        bar:SetStatusBarTexture(fill.file)
        if not fill.crop then
            bar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
        end
        SetProgress(bar:GetValue())
        GCD.spark:ClearAllPoints()
        GCD.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    end

    local background = gcfg.background or "castbar"
    if GCD.background ~= background then
        GCD.background = background
        if background == "castbar" then
            bg:SetTexture(CASTBAR_ART .. "uicastingbar2x")
            bg:SetTexCoord(unpack(CASTBAR_BG))
            bg:SetVertexColor(1, 1, 1, 1)
        else
            bg:SetTexture(SOLID)
            bg:SetTexCoord(0, 1, 0, 1)
            bg:SetVertexColor(0, 0, 0, 0.6)
        end
        if background == "none" then bg:Hide() else bg:Show() end
        if background == "framed" then GCD.border:Show() else GCD.border:Hide() end
    end

    GCD.sparkOn = gcfg.spark == true
    if not GCD.sparkOn then GCD.spark:Hide() end
    -- The cast bar fill is already coloured art; tinting it on top turns it orange.
    if fill == FILLS.castbar then
        bar:SetStatusBarColor(1, 1, 1, 1)
    else
        local color = gcfg.color or {}
        bar:SetStatusBarColor(color.r or 1, color.g or 0.7, color.b or 0, color.a or 1)
    end
end

local function Layout(gcfg)
    local container, baseWidth, scale, gap = GetHost()
    local width = baseWidth * min(max(gcfg.width or 1, 0.1), 1)
    local height = max(1, gcfg.height or 4)
    local custom = IsCustomPlaced()
    local widget = GetWidget()
    local x, y = custom and widget.posX, custom and widget.posY

    -- The cast bar asks for a relayout on every player cast start; skip the re-anchor when nothing moved.
    if GCD.scale == scale and GCD.width == width and GCD.height == height and GCD.x == x and GCD.y == y
        and GCD.container == container and GCD.gap == gap then
        return
    end
    GCD.scale, GCD.width, GCD.height, GCD.x, GCD.y, GCD.container, GCD.gap = scale, width, height, x, y, container, gap

    GCD.bar:SetScale(scale)
    GCD.bar:SetSize(width, height)
    GCD.spark:SetSize(max(6, height * 2), max(12, height * 3.5))
    -- The editor's 16px corners overlap on anything shorter, so the box grows and the bar stays centred in it.
    local moverHeight = max(height * scale, MOVER_MIN_HEIGHT)
    GCD.mover:SetSize(width * scale, moverHeight)
    GCD.mover:ClearAllPoints()
    if custom then
        GCD.mover:SetPoint("CENTER", UIParent, "CENTER", x, y)
    elseif container then
        GCD.mover:SetPoint("BOTTOM", container, "TOP", 0, gap * scale - (moverHeight - height * scale) / 2)
    else
        GCD.mover:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end
end

-- Only an initialised loot roll is refreshed; RefreshLootRoll would otherwise build the module.
local function SyncLift()
    local lift = addon.GetGCDStackLift()
    if lift ~= GCD.lift then
        GCD.lift = lift
        if addon.LootRollModule and addon.LootRollModule.initialized and addon.RefreshLootRoll then
            addon.RefreshLootRoll()
        end
    end
end

local function ForceLayout()
    GCD.scale = nil
    addon.RelayoutGCD()
end

-- No configPath on purpose: GetPoint offsets read back skewed, so the on-screen centre is stored instead.
local function SaveMoved()
    local x, y = addon.GetAnchorOffset(GCD.mover, "CENTER")
    local widget = GetWidget(true)
    if not (x and widget) then
        return
    end
    widget.anchor, widget.posX, widget.posY = "CENTER", floor(x + 0.5), floor(y + 0.5)
    widget.custom_position = true
    ForceLayout()
end

local function ResetPosition()
    local widget = GetWidget()
    if widget then
        widget.custom_position, widget.anchor, widget.posX, widget.posY = false, nil, nil, nil
    end
    ForceLayout()
end

local function Create()
    if GCD.bar then
        return
    end

    local bar = CreateFrame("StatusBar", "DragonUIGCDBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(12)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    local border = CreateFrame("Frame", nil, bar)
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = SOLID, edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    border:Hide()
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(CASTBAR_ART .. "CastingBarSpark")
    spark:SetBlendMode("ADD")
    spark:Hide()
    bar:SetScript("OnEvent", Read)
    GCD.bar, GCD.bg, GCD.border, GCD.spark = bar, bg, border, spark

    local mover = addon.CreateUIFrame(200, 4, "GCDAnchor")
    mover:HookScript("OnDragStop", SaveMoved)
    bar:SetPoint("CENTER", mover, "CENTER", 0, 0)
    GCD.mover = mover

    addon:RegisterEditableFrame({
        name = "GCDIndicator",
        frame = mover,
        hasTarget = function() return GetConfig() ~= nil end,
        editorVisible = function() return GetConfig() ~= nil end,
        showTest = function()
            GCD.start = nil
            bar:SetScript("OnUpdate", nil)
            SetProgress(0.5)
            bar:Show()
            if GCD.sparkOn then spark:Show() end
        end,
        hideTest = ShowIdle,
        onNudge = SaveMoved,
        resetPosition = ResetPosition,
        isDefaultPosition = function() return not IsCustomPlaced() end,
        module = GCD,
    })
end

-- =============================================================================
-- Lifecycle
-- =============================================================================

function addon.ApplyGCDSystem()
    local gcfg = GetConfig()
    if not gcfg then
        return
    end

    Create()
    GCD.initialized = true
    GCD.applied = true
    GCD.bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    ApplyLook(gcfg)
    Layout(gcfg)
    SyncLift()
    if addon.EditorMode and addon.EditorMode:IsActive() then
        return
    end
    Read()
    if not GCD.start then
        ShowIdle()
    end
end

function addon.RestoreGCDSystem()
    GCD.applied = false
    if GCD.bar then
        GCD.bar:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        GCD.bar:SetScript("OnUpdate", nil)
        GCD.bar:Hide()
        GCD.start = nil
    end
    SyncLift()
end

function addon.RefreshGCDSystem()
    if GetConfig() then
        addon.ApplyGCDSystem()
    else
        addon.RestoreGCDSystem()
    end
end

-- Entry point for the editor and options controls.
addon.RefreshGCD = addon.RefreshGCDSystem
addon.ResetGCDPosition = ResetPosition

-- The cast bar calls this whenever the player bar is laid out or switched off.
function addon.RelayoutGCD()
    local gcfg = GetConfig()
    if gcfg and GCD.applied then
        Layout(gcfg)
    end
    SyncLift()
end

-- Room the loot rolls leave for a GCD bar sitting on a DragonUI cast bar at its default spot.
function addon.GetGCDStackLift()
    local gcfg = GetConfig()
    if not gcfg or not addon.db.profile.castbar.enabled or IsCustomPlaced()
        or not (addon.IsPlayerCastbarAtDefault and addon.IsPlayerCastbarAtDefault()) then
        return 0
    end
    return (GAP + max(1, gcfg.height or 4)) * (addon.db.profile.castbar.scale or 1)
end
