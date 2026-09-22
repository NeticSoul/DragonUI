-- =============================================================================
-- Level Up Enhance Module
-- Enhanced level-up notification with animated frame.
-- =============================================================================

local addon = select(2, ...)
local L = addon.L

local LEVEL_FRAME = addon._dir .. "NewLevelUp\\levelup"
local LEVEL_FONT = addon.Fonts.PRIMARY

-- Only rows 67-188 of the 512x256 sheet carry art; the rest is transparent padding.
local ART_TOP, ART_BOTTOM = 67 / 256, 189 / 256
local WIDTH = 400
local HEIGHT = WIDTH * (189 - 67) / 512

local HOLD_TIME, FADE_TIME = 4.5, 1.5

local LevelUpEnhance = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("levelupenhance", LevelUpEnhance,
        L["Level Up Enhance"],
        L["Enhanced level-up notification with animated frame"],
        { lifecyclePrefix = "LevelUpEnhance" })
end

local anchor, banner

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive()
end

-- =============================================================================
-- POSITION
-- =============================================================================

local function ApplyWidgetPosition()
    if IsEditorActive() then return end

    local widgets = addon.db.profile.widgets
    local cfg = widgets and widgets.levelupenhance or addon.defaults.profile.widgets.levelupenhance

    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY)
end

-- =============================================================================
-- BANNER
-- =============================================================================

local function ShowBanner(level)
    banner.footer:SetText(string.format(L["Level %d"], level))
    banner.fade:Stop()
    banner:Show()
    banner.fade:Play()
end

local function CreateBanner()
    anchor = addon.CreateUIFrame(WIDTH, HEIGHT, "LevelUpFrame")

    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetFrameStrata("HIGH")
    banner:SetAllPoints(anchor)
    banner:Hide()

    local art = banner:CreateTexture(nil, "BACKGROUND")
    art:SetTexture(LEVEL_FRAME)
    art:SetTexCoord(0, 1, ART_TOP, ART_BOTTOM)
    art:SetAllPoints()

    banner.header = banner:CreateFontString(nil, "ARTWORK")
    banner.header:SetFont(LEVEL_FONT, 18)
    banner.header:SetPoint("CENTER", 0, 20)
    banner.header:SetText(L["You've Reached"])

    banner.footer = banner:CreateFontString(nil, "ARTWORK")
    banner.footer:SetFont(LEVEL_FONT, 30)
    banner.footer:SetPoint("CENTER", 0, -20)
    banner.footer:SetTextColor(207 / 255, 191 / 255, 20 / 255, 1)

    banner.fade = banner:CreateAnimationGroup()
    local fadeOut = banner.fade:CreateAnimation("Alpha")
    fadeOut:SetStartDelay(HOLD_TIME)
    fadeOut:SetDuration(FADE_TIME)
    fadeOut:SetChange(-1)
    banner.fade:SetScript("OnFinished", function()
        banner:Hide()
    end)

    addon:RegisterEditableFrame({
        name = "levelupenhance",
        frame = anchor,
        blizzardFrame = banner,
        configPath = {"widgets", "levelupenhance"},
        editorVisible = function()
            return addon:IsModuleEnabled("levelupenhance")
        end,
        showTest = function()
            banner.fade:Stop()
            banner.footer:SetText(string.format(L["Level %d"], UnitLevel("player") + 1))
            anchor:Show()
            banner:Show()
        end,
        hideTest = function()
            banner.fade:Stop()
            banner:Hide()
        end,
        onHide = ApplyWidgetPosition,
        module = LevelUpEnhance,
    })
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, _, level)
    if IsEditorActive() then return end
    ShowBanner(level)
end)

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

function addon.ApplyLevelUpEnhanceSystem()
    if not banner then
        CreateBanner()
    end

    ApplyWidgetPosition()
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

    LevelUpEnhance.initialized = true
    LevelUpEnhance.applied = true
end

function addon.RestoreLevelUpEnhanceSystem()
    eventFrame:UnregisterEvent("PLAYER_LEVEL_UP")

    if banner then
        banner.fade:Stop()
        banner:Hide()
    end

    LevelUpEnhance.applied = false
end

function addon.RefreshLevelUpEnhanceSystem()
    if addon:IsModuleEnabled("levelupenhance") then
        addon.ApplyLevelUpEnhanceSystem()
    else
        addon.RestoreLevelUpEnhanceSystem()
    end
end

-- =============================================================================
-- TEST COMMAND
-- =============================================================================

SLASH_DRAGONUI_TESTLEVEL1 = "/testlevel"
SlashCmdList["DRAGONUI_TESTLEVEL"] = function(msg)
    if not LevelUpEnhance.applied then
        addon:Print(L["Module disabled."])
        return
    end
    ShowBanner(tonumber(msg) or UnitLevel("player") + 1)
end
