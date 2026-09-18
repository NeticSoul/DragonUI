-- =============================================================================
-- Level Up Enhance Module
-- Enhanced level-up notification with animated frame.
-- =============================================================================

local addon = select(2, ...)
local L = addon.L

local DIR = addon._dir
local LEVEL_FRAME = DIR .. "NewLevelUp\\levelup"
local LEVEL_FONT = "Fonts\\FRIZQT__.TTF"

local LevelUpEnhance = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("levelupenhance", LevelUpEnhance,
        (L and L["Level Up Enhance"]) or "Level Up Enhance",
        (L and L["Enhanced level-up notification with animated frame"]) or "Enhanced level-up notification with animated frame",
        {
            lifecycle = {
                apply   = "ApplyLevelUpEnhanceSystem",
                restore = "RestoreLevelUpEnhanceSystem",
                refresh = "RefreshLevelUpEnhanceSystem",
            },
        })
end

-- =============================================================================
-- MODULE STATE
-- =============================================================================

local function IsModuleEnabled()
    return addon:IsModuleEnabled("levelupenhance")
end

local function GetModuleConfig()
    return addon:GetModuleConfig("levelupenhance")
end

-- =============================================================================
-- INTERNAL STATE
-- =============================================================================

local newLevelFrame

-- =============================================================================
-- EDITOR MODE
-- =============================================================================

local anchor
local DEFAULT_ANCHOR, DEFAULT_X, DEFAULT_Y = "TOP", 0, -128

local function ApplyWidgetPosition()
    if InCombatLockdown() then return end
    if addon.EditorMode and addon.EditorMode:IsActive() then return end
    if not anchor then return end

    local cfg = addon.db.profile.widgets and addon.db.profile.widgets.levelupenhance
    if not cfg then return end

    if not cfg then return end

    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor or DEFAULT_ANCHOR, UIParent,
        cfg.anchor or DEFAULT_ANCHOR, cfg.posX or DEFAULT_X, cfg.posY or DEFAULT_Y)

    if newLevelFrame then
        newLevelFrame:ClearAllPoints()
        newLevelFrame:SetPoint("TOP", anchor, "TOP", cfg.posX or DEFAULT_X, cfg.posY or DEFAULT_Y)
    end
end

-- =============================================================================
-- NEW LEVEL FRAME
-- =============================================================================

local function ShowNewLevelFrame(level)
    if not newLevelFrame or not newLevelFrame.footer then return end
    newLevelFrame.footer:SetText(string.format(L and L["Level %d"] or "Level %d", level))

    local cfg = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.levelupenhance
    newLevelFrame:ClearAllPoints()
    newLevelFrame:SetPoint("TOP", UIParent, "TOP", (cfg and cfg.posX) or 0, (cfg and cfg.posY) or -128)
    newLevelFrame:SetFrameStrata("HIGH")
    newLevelFrame:SetAlpha(1)
    newLevelFrame:Show()
    newLevelFrame.timeShown = 0
    local fadeInfo = { mode = "IN", fadeFunc = function() end, timeToFade = 1.5, startAlpha = 1, endAlpha = 1 }
    UIFrameFade(newLevelFrame, fadeInfo)
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        newLevelFrame.timeShown = newLevelFrame.timeShown + elapsed
        if newLevelFrame.timeShown >= 4.5 then
            UIFrameFadeOut(newLevelFrame, 1.5, 1, 0)
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

function addon.ApplyLevelUpEnhanceSystem()
    if LevelUpEnhance.applied then return end

    newLevelFrame = CreateFrame("Frame", nil, UIParent)
    newLevelFrame:SetFrameStrata("MEDIUM")
    newLevelFrame:SetWidth(400)
    newLevelFrame:SetHeight(200)

    local texture = newLevelFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture(LEVEL_FRAME)
    texture:SetAllPoints(newLevelFrame)

    newLevelFrame.header = newLevelFrame:CreateFontString(nil, "ARTWORK")
    newLevelFrame.header:SetFont(LEVEL_FONT, 18)
    newLevelFrame.header:SetPoint("CENTER", 0, 20)
    newLevelFrame.header:SetText(L and L["You've Reached"] or "You've Reached")

    newLevelFrame.footer = newLevelFrame:CreateFontString(nil, "ARTWORK")
    newLevelFrame.footer:SetFont(LEVEL_FONT, 30)
    newLevelFrame.footer:SetPoint("CENTER", 0, -20)
    newLevelFrame.footer:SetTextColor(207 / 255, 191 / 255, 20 / 255, 1)

    newLevelFrame:Hide()

    if not anchor then
        anchor = addon.CreateUIFrame(400, 200, "LevelUpFrame")

        addon:RegisterEditableFrame({
            name = "levelupenhance",
            frame = anchor,
            blizzardFrame = newLevelFrame,
            configPath = {"widgets", "levelupenhance"},
            editorVisible = function()
                return IsModuleEnabled()
            end,
            showTest = function()
                anchor:Show()
                newLevelFrame.footer:SetText(L and L["Level %d"] or "Level %d", UnitLevel("player") + 1)
                newLevelFrame:Show()
                newLevelFrame:SetAlpha(1)
            end,
            hideTest = function()
                newLevelFrame:Hide()
            end,
            onHide = function()
                newLevelFrame:Hide()
                ApplyWidgetPosition()
            end,
            module = LevelUpEnhance,
        })
    end

    ApplyWidgetPosition()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if not IsModuleEnabled() then return end
        if addon.EditorMode and addon.EditorMode:IsActive() then return end
        ShowNewLevelFrame(select(1, ...))
    end)

    LevelUpEnhance.eventFrame = eventFrame
    LevelUpEnhance.newLevelFrame = newLevelFrame
    LevelUpEnhance.initialized = true
    LevelUpEnhance.applied = true
end

function addon.RestoreLevelUpEnhanceSystem()
    if not LevelUpEnhance.applied then return end

    if LevelUpEnhance.eventFrame then
        LevelUpEnhance.eventFrame:UnregisterAllEvents()
        LevelUpEnhance.eventFrame:SetScript("OnEvent", nil)
    end

    if LevelUpEnhance.newLevelFrame then
        LevelUpEnhance.newLevelFrame:Hide()
        LevelUpEnhance.newLevelFrame:SetScript("OnUpdate", nil)
    end

    if anchor then
        anchor:Hide()
    end

    LevelUpEnhance.eventFrame = nil
    LevelUpEnhance.newLevelFrame = nil
    LevelUpEnhance.applied = false
end

function addon.RefreshLevelUpEnhanceSystem()
    if IsModuleEnabled() then
        addon.ApplyLevelUpEnhanceSystem()
    else
        addon.RestoreLevelUpEnhanceSystem()
    end
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end

        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                    addon.RefreshLevelUpEnhanceSystem()
                end)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        addon.ApplyLevelUpEnhanceSystem()
    end
end)

-- =============================================================================
-- TEST COMMAND
-- =============================================================================

SLASH_DRAGONUI_TESTLEVEL1 = "/testlevel"
SlashCmdList["DRAGONUI_TESTLEVEL"] = function(msg)
    if not IsModuleEnabled() then
        print("|cffFFD700[LevelUpEnhance]|r Module is disabled.")
        return
    end
    if not newLevelFrame then
        print("|cffFFD700[LevelUpEnhance]|r Module not initialized yet.")
        return
    end
    local level = tonumber(msg) or UnitLevel("player") + 1
    ShowNewLevelFrame(level)
end
