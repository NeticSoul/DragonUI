-- ============================================================
--  Hp low alert Module for DragonUI
--  Screen flash + sound when player HP drops below threshold.
--  Integrated as a DragonUI module (config in Enhancements tab).
-- ============================================================

local addon = select(2, ...)

-- -----------------------------------------------
-- Defaults
-- -----------------------------------------------
local DEFAULTS = {
    threshold     = 30,
    enabled       = true,
    soundEnabled  = false,
    flashEnabled  = true,
    flashColor    = { r = 1, g = 0, b = 0 },
    useClassColor = false,
    flashOpacity  = 0.35,
    flashExtent   = 40,
}

-- -----------------------------------------------
-- Module state
-- -----------------------------------------------
local LowHPAlertModule = {
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("hp_low_alert", LowHPAlertModule,
        "Low HP Alert",
        "Plays a sound and flashes the screen edges when your HP drops below the threshold.",
        {
            lifecycle = {
                apply   = "ApplyHpLowAlertSystem",
                restore = "RestoreHpLowAlertSystem",
                refresh = "RefreshHpLowAlertSystem",
            },
        })
end

-- -----------------------------------------------
-- Internal state
-- -----------------------------------------------
local db
local isWarning      = false
local flashFrame
local pulseAlpha     = 0
local pulseDir       = 1            -- 1 = fading in, -1 = fading out
local PULSE_SPEED    = 1.6           -- full cycle per second
local warnSoundTimer = 0
local SOUND_INTERVAL = 3
local testTimer      = nil

-- -----------------------------------------------
-- Flash frame: four gradient edges, centre clear
-- -----------------------------------------------
local flashTextures = {}

local function UpdateFlashVisuals()
    if not flashFrame or not db then return end
    local c = db.flashColor or { r = 1, g = 0, b = 0 }
    if db.useClassColor then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS[class]
        if cc then c = cc end
    end
    local ext = db.flashExtent or 40

    flashTextures.top:SetHeight(ext)
    flashTextures.bot:SetHeight(ext)
    flashTextures.lft:SetWidth(ext)
    flashTextures.rgt:SetWidth(ext)

    flashTextures.top:SetGradientAlpha("VERTICAL", 0, 0, 0, 0,   c.r, c.g, c.b, 1)
    flashTextures.bot:SetGradientAlpha("VERTICAL", c.r, c.g, c.b, 1,   0, 0, 0, 0)
    flashTextures.lft:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, 1,   0, 0, 0, 0)
    flashTextures.rgt:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0,   c.r, c.g, c.b, 1)
end

local function CreateFlashFrame()
    if flashFrame then return end

    flashFrame = CreateFrame("Frame", "LowHPAlertFlash", UIParent)
    flashFrame:SetAllPoints(UIParent)
    flashFrame:SetFrameStrata("FULLSCREEN")
    flashFrame:SetAlpha(0)

    local TEX = "Interface\\ChatFrame\\ChatFrameBackground"

    -- Top
    flashTextures.top = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.top:SetPoint("TOPLEFT",  flashFrame, "TOPLEFT",  0,  0)
    flashTextures.top:SetPoint("TOPRIGHT", flashFrame, "TOPRIGHT", 0,  0)
    flashTextures.top:SetTexture(TEX)

    -- Bottom
    flashTextures.bot = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.bot:SetPoint("BOTTOMLEFT",  flashFrame, "BOTTOMLEFT",  0, 0)
    flashTextures.bot:SetPoint("BOTTOMRIGHT", flashFrame, "BOTTOMRIGHT", 0, 0)
    flashTextures.bot:SetTexture(TEX)

    -- Left
    flashTextures.lft = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.lft:SetPoint("TOPLEFT",    flashFrame, "TOPLEFT",    0, 0)
    flashTextures.lft:SetPoint("BOTTOMLEFT", flashFrame, "BOTTOMLEFT", 0, 0)
    flashTextures.lft:SetTexture(TEX)

    -- Right
    flashTextures.rgt = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.rgt:SetPoint("TOPRIGHT",    flashFrame, "TOPRIGHT",    0, 0)
    flashTextures.rgt:SetPoint("BOTTOMRIGHT", flashFrame, "BOTTOMRIGHT", 0, 0)
    flashTextures.rgt:SetTexture(TEX)

    UpdateFlashVisuals()
end

-- -----------------------------------------------
-- Helpers
-- -----------------------------------------------
local function GetHPPercent()
    local hp  = UnitHealth("player")
    local max = UnitHealthMax("player")
    if max == 0 then return 100 end
    return (hp / max) * 100
end

local function StartWarning()
    if isWarning then return end
    isWarning = true
    warnSoundTimer = SOUND_INTERVAL   -- fire sound immediately on first tick
end

local function StopWarning()
    if not isWarning then return end
    isWarning = false
    pulseAlpha = 0
    pulseDir   = 1
    if flashFrame then
        flashFrame:SetAlpha(0)
    end
end

-- -----------------------------------------------
-- Master OnUpdate — drives pulse and sound repeat
-- -----------------------------------------------
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end

    -- Test timer countdown
    if testTimer then
        testTimer = testTimer - elapsed
        if testTimer <= 0 then
            testTimer = nil
            StopWarning()
        end
    end

    -- HP check (skip if test is running so it doesn't cancel early)
    if not testTimer then
        if not db.enabled then
            StopWarning()
            return
        end

        -- Dead/ghost: no HP warnings (no way to be low HP while dead)
        if UnitIsDeadOrGhost("player") then
            StopWarning()
            return
        end

        if GetHPPercent() <= db.threshold then
            StartWarning()
        else
            StopWarning()
            return
        end
    end

    -- Pulse flash (guarded: flashFrame may be nil if module hasn't applied yet)
    if db.flashEnabled and isWarning and flashFrame then
        pulseAlpha = pulseAlpha + pulseDir * PULSE_SPEED * elapsed
        if pulseAlpha >= 1 then
            pulseAlpha = 1
            pulseDir   = -1
        elseif pulseAlpha <= 0 then
            pulseAlpha = 0
            pulseDir   = 1
        end
        local opacityScale = db.flashOpacity or 1.0
        flashFrame:SetAlpha(pulseAlpha * opacityScale)
    end

    -- Sound repeat
    if db.soundEnabled and isWarning then
        warnSoundTimer = warnSoundTimer + elapsed
        if warnSoundTimer >= SOUND_INTERVAL then
            PlaySound("RaidWarning")
            warnSoundTimer = 0
        end
    end
end)

-- -----------------------------------------------
-- DragonUI Lifecycle
-- -----------------------------------------------

-- Ensure the module config entry exists in the profile, creating it from DEFAULTS
-- if needed. This covers the case where DeepCopy didn't run because the profile
-- already existed before hp_low_alert was added to database.lua.
local function EnsureConfig()
    if not addon.db or not addon.db.profile then return false end
    if not addon.db.profile.modules then
        addon.db.profile.modules = {}
    end
    if not addon.db.profile.modules.hp_low_alert then
        addon.db.profile.modules.hp_low_alert = {}
        for k, v in pairs(DEFAULTS) do
            addon.db.profile.modules.hp_low_alert[k] = v
        end
    end
    db = addon.db.profile.modules.hp_low_alert
    -- Apply any missing defaults (e.g. if a new field was added to DEFAULTS)
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    return true
end

function addon.ApplyHpLowAlertSystem()
    if LowHPAlertModule.applied then return end
    if not EnsureConfig() then return end

    CreateFlashFrame()
    LowHPAlertModule.applied = true
end

function addon.RestoreHpLowAlertSystem()
    if not LowHPAlertModule.applied then return end
    StopWarning()
    LowHPAlertModule.applied = false
end

-- Refresh acts as the orchestrator dispatcher (same pattern as RefreshUnitFrameLayers).
-- ModuleRegistry calls refresh during startup and on profile changes, NOT apply.
function addon.RefreshHpLowAlertSystem()
    if not EnsureConfig() then return end

    if db.enabled then
        addon.ApplyHpLowAlertSystem()
    else
        addon.RestoreHpLowAlertSystem()
    end
end

-- -----------------------------------------------
-- Self-initialization
-- -----------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not EnsureConfig() then return end
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                    addon.RefreshHpLowAlertSystem()
                end)
                addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                    addon.RefreshHpLowAlertSystem()
                end)
                addon.db.RegisterCallback(addon, "OnProfileReset", function()
                    addon.RefreshHpLowAlertSystem()
                end)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not EnsureConfig() then return end
        addon.RefreshHpLowAlertSystem()
    end
end)

-- -----------------------------------------------
-- Slash command  /lhp → DragonUI config
-- -----------------------------------------------
SLASH_LOWHPALERT1 = "/lhp"
SlashCmdList["LOWHPALERT"] = function(msg)
    msg = msg and msg:lower():trim() or ""
    if msg == "toggle" then
        if not db then return end
        db.enabled = not db.enabled
        print("|cffFFD700[HpLowAlert]|r " .. (db.enabled and "|cff00ff00Enabled|r" or "|cffff4444Disabled|r"))
    elseif msg:match("^thresh%s+%d+$") then
        if not db then return end
        local val = tonumber(msg:match("%d+"))
        val = math.max(5, math.min(80, val))
        db.threshold = val
        print(string.format("|cffFFD700[HpLowAlert]|r Threshold set to |cffff4444%d%%|r", val))
    else
        -- Open DragonUI options and select Enhancements tab
        if addon.ToggleOptionsUI then
            addon:ToggleOptionsUI("enhancements")
        end
    end
end

-- -----------------------------------------------
-- Called from the options panel when flash visuals change (color, opacity, extent)
addon.RefreshHpLowAlertFlash = UpdateFlashVisuals

-- Exports for test button in Enhancements tab
-- -----------------------------------------------
addon.LowHPAlert = {
    StartTest = function()
        isWarning = false
        StartWarning()
        testTimer = 3
        if db and db.soundEnabled then
            PlaySound("RaidWarning")
            warnSoundTimer = 0
        end
    end,
    GetThreshold = function() return db and db.threshold or DEFAULTS.threshold end,
}
