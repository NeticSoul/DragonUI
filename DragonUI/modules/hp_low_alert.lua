-- =============================================================================
-- Low HP Alert Module
-- Screen-edge flash and warning sound while player health is below a threshold.
-- =============================================================================

local addon = select(2, ...)

local LowHPAlertModule = {
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("hp_low_alert", LowHPAlertModule,
        addon.L["Low HP Alert"],
        addon.L["Plays a sound and flashes the screen edges when your HP drops below the threshold."])
end

local PULSE_SPEED    = 1.6
local SOUND_INTERVAL = 3
local TEST_DURATION  = 3

local EVENTS = {
    "UNIT_HEALTH",
    "UNIT_MAXHEALTH",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
}

local db
local flashFrame
local flashTextures = {}
local warning    = false
local testTimer
local pulseAlpha = 0
local pulseDir   = 1
local soundTimer = 0

-- =============================================================================
-- FLASH FRAME
-- =============================================================================

local function UpdateFlashVisuals()
    if not flashFrame or not db then return end
    local c = db.flashColor
    if db.useClassColor then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS[class]
        if cc then c = cc end
    end
    local ext = db.flashExtent

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
    flashFrame = CreateFrame("Frame", "DragonUI_LowHPAlertFlash", UIParent)
    flashFrame:SetAllPoints(UIParent)
    flashFrame:SetFrameStrata("FULLSCREEN")
    flashFrame:Hide()

    local TEX = "Interface\\ChatFrame\\ChatFrameBackground"

    flashTextures.top = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.top:SetPoint("TOPLEFT",  flashFrame, "TOPLEFT",  0, 0)
    flashTextures.top:SetPoint("TOPRIGHT", flashFrame, "TOPRIGHT", 0, 0)
    flashTextures.top:SetTexture(TEX)

    flashTextures.bot = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.bot:SetPoint("BOTTOMLEFT",  flashFrame, "BOTTOMLEFT",  0, 0)
    flashTextures.bot:SetPoint("BOTTOMRIGHT", flashFrame, "BOTTOMRIGHT", 0, 0)
    flashTextures.bot:SetTexture(TEX)

    flashTextures.lft = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.lft:SetPoint("TOPLEFT",    flashFrame, "TOPLEFT",    0, 0)
    flashTextures.lft:SetPoint("BOTTOMLEFT", flashFrame, "BOTTOMLEFT", 0, 0)
    flashTextures.lft:SetTexture(TEX)

    flashTextures.rgt = flashFrame:CreateTexture(nil, "ARTWORK")
    flashTextures.rgt:SetPoint("TOPRIGHT",    flashFrame, "TOPRIGHT",    0, 0)
    flashTextures.rgt:SetPoint("BOTTOMRIGHT", flashFrame, "BOTTOMRIGHT", 0, 0)
    flashTextures.rgt:SetTexture(TEX)
end

-- =============================================================================
-- WARNING STATE
-- =============================================================================

local function IsHealthLow()
    if UnitIsDeadOrGhost("player") then return false end
    local max = UnitHealthMax("player")
    return max > 0 and UnitHealth("player") / max * 100 <= db.threshold
end

local OnUpdate

local function SetWarning(on)
    if on == warning then return end
    warning = on
    if on then
        pulseAlpha, pulseDir = 0, 1
        soundTimer = SOUND_INTERVAL
        flashFrame:SetAlpha(0)
        flashFrame:Show()
        flashFrame:SetScript("OnUpdate", OnUpdate)
    else
        flashFrame:SetScript("OnUpdate", nil)
        flashFrame:Hide()
    end
end

local function Evaluate()
    SetWarning(testTimer ~= nil or (LowHPAlertModule.applied and IsHealthLow()))
end

function OnUpdate(_, elapsed)
    if testTimer then
        testTimer = testTimer - elapsed
        if testTimer <= 0 then
            testTimer = nil
            Evaluate()
            if not warning then return end
        end
    end

    if db.flashEnabled then
        pulseAlpha = pulseAlpha + pulseDir * PULSE_SPEED * elapsed
        if pulseAlpha >= 1 then
            pulseAlpha, pulseDir = 1, -1
        elseif pulseAlpha <= 0 then
            pulseAlpha, pulseDir = 0, 1
        end
        flashFrame:SetAlpha(pulseAlpha * db.flashOpacity)
    else
        flashFrame:SetAlpha(0)
    end

    if db.soundEnabled then
        soundTimer = soundTimer + elapsed
        if soundTimer >= SOUND_INTERVAL then
            soundTimer = 0
            PlaySound("RaidWarning")
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit ~= "player" then return end
    if testTimer then return end
    Evaluate()
end)

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

function addon.ApplyHpLowAlertSystem()
    db = addon:GetModuleConfig("hp_low_alert")
    if not flashFrame then
        CreateFlashFrame()
    end
    UpdateFlashVisuals()

    for _, event in ipairs(EVENTS) do
        eventFrame:RegisterEvent(event)
    end

    LowHPAlertModule.applied = true
    Evaluate()
end

function addon.RestoreHpLowAlertSystem()
    eventFrame:UnregisterAllEvents()
    testTimer = nil
    LowHPAlertModule.applied = false
    SetWarning(false)
end

function addon.RefreshHpLowAlertSystem()
    if addon:IsModuleEnabled("hp_low_alert") then
        addon.ApplyHpLowAlertSystem()
    else
        addon.RestoreHpLowAlertSystem()
    end
end

-- =============================================================================
-- OPTIONS PANEL HOOKS
-- =============================================================================

addon.RefreshHpLowAlertFlash = UpdateFlashVisuals

addon.LowHPAlert = {
    StartTest = function()
        if not LowHPAlertModule.applied then return end
        testTimer = TEST_DURATION
        SetWarning(true)
    end,
}
