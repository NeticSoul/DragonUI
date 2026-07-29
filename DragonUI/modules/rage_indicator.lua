local addon = select(2, ...)
local _G = getfenv(0)

-- ============================================================================
-- RAGE INDICATOR MODULE FOR DRAGONUI
-- Tints action button icons by range/usability state:
--   out of range = red, not enough mana = blue, unusable = gray.
-- ============================================================================

local RageIndicatorModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    frames = {}
}

if addon.RegisterModule then
    addon:RegisterModule("rage_indicator", RageIndicatorModule,
    (addon.L and addon.L["Range Indicator"]) or "Range Indicator",
    (addon.L and addon.L["Color action button icons when target is out of range or ability is unusable."])
        or "Color action button icons when target is out of range or ability is unusable.")
end

local updateInterval = 0.2
local updateTimer = 0
local indicatorFrame
local eventFrame
local hooksInstalled = false
local IsSystemActive

local DEFAULT_OOR_COLOR = { r = 0.8, g = 0.2, b = 0.2 }
local DEFAULT_OOM_COLOR = { r = 0.5, g = 0.5, b = 1.0 }

local function GetModuleConfig()
    return addon:GetModuleConfig("rage_indicator")
end

local function GetIconColor(key, fallback)
    local cfg = GetModuleConfig()
    local c = cfg and cfg[key]
    if c and c.r then return c.r, c.g, c.b end
    return fallback.r, fallback.g, fallback.b
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("rage_indicator")
end

local function IsButtonsModuleEnabled()
    return addon:IsModuleEnabled("buttons")
end

local function ResetButtonColor(button)
    if not button then return end
    local icon = button.icon or _G[button:GetName() .. "Icon"]
    if icon then
        icon:SetVertexColor(1.0, 1.0, 1.0)
    end
end

local function RestoreDefaultButtonState(button)
    if not button then return end

    if type(ActionButton_UpdateUsable) == "function" then
        ActionButton_UpdateUsable(button)
    else
        ResetButtonColor(button)
    end
end

local function UpdateButtonColor(button)
    if not button then return end

    local actionID
    if type(ActionButton_GetPagedID) == "function" then
        actionID = ActionButton_GetPagedID(button)
    else
        actionID = button.action
    end

    if not actionID then
        ResetButtonColor(button)
        return
    end

    local icon = button.icon or _G[button:GetName() .. "Icon"]
    if not icon then return end

    if not HasAction(actionID) then
        ResetButtonColor(button)
        return
    end

    local isUsable, notEnoughMana = IsUsableAction(actionID)

    -- Out-of-mana has priority over range (prevents red/blue flicker).
    if notEnoughMana then
        icon:SetVertexColor(GetIconColor("oom_color", DEFAULT_OOM_COLOR))
        return
    end

    -- Gray for unusable actions that are not mana-related.
    if not isUsable then
        icon:SetVertexColor(0.4, 0.4, 0.4)
        return
    end

    -- Red only applies to usable actions that are out of range.
    if IsActionInRange(actionID) == 0 then
        icon:SetVertexColor(GetIconColor("oor_color", DEFAULT_OOR_COLOR))
    else
        icon:SetVertexColor(1.0, 1.0, 1.0)
    end
end

local function SetupHooks()
    if hooksInstalled then return end

    hooksecurefunc("ActionButton_UpdateUsable", function(button)
        if not IsSystemActive() then return end
        UpdateButtonColor(button)
    end)

    if type(ActionButton_UpdateRangeIndicator) == "function" then
        hooksecurefunc("ActionButton_UpdateRangeIndicator", function(button)
            if not IsSystemActive() then return end
            UpdateButtonColor(button)
        end)
    end

    hooksInstalled = true
end

local function UpdateAllButtons()
    if not indicatorFrame or not indicatorFrame.buttonList then return end

    for _, button in ipairs(indicatorFrame.buttonList) do
        UpdateButtonColor(button)
    end
end

local function RestoreAllButtonsDefault()
    if not indicatorFrame or not indicatorFrame.buttonList then return end

    for _, button in ipairs(indicatorFrame.buttonList) do
        RestoreDefaultButtonState(button)
    end
end

local function RebuildButtonList()
    if not indicatorFrame then return end

    wipe(indicatorFrame.buttonList)

    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            table.insert(indicatorFrame.buttonList, button)
        end
    end

    local multiBarPrefixes = {
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }

    for _, prefix in ipairs(multiBarPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                table.insert(indicatorFrame.buttonList, button)
            end
        end
    end

    for i = 1, VEHICLE_MAX_ACTIONBUTTONS do
        local button = _G["VehicleMenuBarActionButton" .. i]
        if button then
            table.insert(indicatorFrame.buttonList, button)
        end
    end
end

IsSystemActive = function()
    local cfg = GetModuleConfig()
    return cfg and cfg.enabled and IsButtonsModuleEnabled()
end

local function SetSystemState(enabled)
    if not indicatorFrame then return end

    if enabled then
        if #indicatorFrame.buttonList == 0 then
            RebuildButtonList()
        end
        indicatorFrame:Show()
        UpdateAllButtons()
        RageIndicatorModule.applied = true
    else
        indicatorFrame:Hide()
        RestoreAllButtonsDefault()
        RageIndicatorModule.applied = false
    end
end

local function RefreshSystem()
    SetSystemState(IsSystemActive())
end

function addon.RefreshRageIndicatorSystem()
    if not RageIndicatorModule.initialized then return end
    RefreshSystem()
end

function addon.ApplyRageIndicatorSystem()
    if not RageIndicatorModule.initialized then return end
    RefreshSystem()
end

function addon.RestoreRageIndicatorSystem()
    if not RageIndicatorModule.initialized then return end
    SetSystemState(false)
end


local function RegisterTrackedEvent(frame, event)
    frame:RegisterEvent(event)
    table.insert(RageIndicatorModule.registeredEvents, { frame = frame, event = event })
end

local function Initialize()
    if RageIndicatorModule.initialized then return end

    SetupHooks()

    indicatorFrame = CreateFrame("Frame", "DragonUI_RageIndicatorFrame")
    indicatorFrame:Hide()
    indicatorFrame.buttonList = {}
    indicatorFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer < updateInterval then return end
        updateTimer = 0

        if not IsSystemActive() then
            self:Hide()
            RestoreAllButtonsDefault()
            RageIndicatorModule.applied = false
            return
        end

        UpdateAllButtons()
    end)

    eventFrame = CreateFrame("Frame", "DragonUI_RageIndicatorEventFrame")
    RegisterTrackedEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    RegisterTrackedEvent(eventFrame, "PLAYER_TARGET_CHANGED")
    RegisterTrackedEvent(eventFrame, "ACTIONBAR_SLOT_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "ACTIONBAR_SLOT_CHANGED" then
            RebuildButtonList()
        end

        RefreshSystem()

        if event == "PLAYER_TARGET_CHANGED" and indicatorFrame:IsShown() then
            UpdateAllButtons()
        end
    end)

    RageIndicatorModule.frames.indicatorFrame = indicatorFrame
    RageIndicatorModule.frames.eventFrame = eventFrame

    RebuildButtonList()
    RefreshSystem()
    RageIndicatorModule.initialized = true
end

local initFrame = CreateFrame("Frame")
RegisterTrackedEvent(initFrame, "ADDON_LOADED")
RegisterTrackedEvent(initFrame, "PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

RageIndicatorModule.frames.initFrame = initFrame
