-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- =============================================================================
-- Speedometer Module
-- Movement speed readout modelled on MonkeySpeed's look and behaviour.
-- =============================================================================

local addon = select(2, ...)

local SpeedometerModule = {
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("speedometer", SpeedometerModule,
        addon.L["Speedometer"],
        addon.L["Shows a speed bar and percent readout at the top center."])
end

local BASE_SPEED      = 7
local UPDATE_INTERVAL = 0.1

local BAR_TEXTURE    = "Interface\\AddOns\\DragonUI\\Textures\\Speedometer\\bar.tga"
local RESIZE_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\Speedometer\\ResizeButton.tga"

local DEFAULT_COLORS = {
    frameColor   = { r = 0,   g = 0,   b = 0,   a = 1 },
    borderColor  = { r = 1,   g = 0.7, b = 0 },
    speedColor1  = { r = 1,   g = 0,   b = 0 },
    speedColor2  = { r = 1,   g = 0.5, b = 0 },
    speedColor3  = { r = 1,   g = 1,   b = 0 },
    speedColor4  = { r = 0,   g = 1,   b = 0 },
    speedColor5  = { r = 0,   g = 1,   b = 0.5 },
    speedColor6  = { r = 0,   g = 1,   b = 1 },
    speedColor7  = { r = 1,   g = 0,   b = 1 },
    speedColor8  = { r = 0.5, g = 0,   b = 1 },
    speedColor9  = { r = 0,   g = 0,   b = 1 },
    speedColor10 = { r = 0,   g = 0,   b = 0.5 },
}

local db
local frame
local bar
local text
local resizeButton
local driver
local accumulator = 0
local currentUnit = "player"

local function ColorOf(field)
    local fallback = DEFAULT_COLORS[field]
    local c = db and db[field]
    if not c then return fallback.r, fallback.g, fallback.b end
    return c.r or fallback.r, c.g or fallback.g, c.b or fallback.b
end

local function SpeedColor(percent)
    local key
    if percent == 0 then
        key = "speedColor1"
    elseif percent < 100 then
        key = "speedColor2"
    elseif percent == 100 then
        key = "speedColor3"
    elseif percent < 200 then
        key = "speedColor4"
    elseif percent == 200 then
        key = "speedColor5"
    elseif percent < 380 then
        key = "speedColor6"
    elseif percent == 380 then
        key = "speedColor7"
    elseif percent < 410 then
        key = "speedColor8"
    elseif percent == 410 then
        key = "speedColor9"
    else
        key = "speedColor10"
    end
    return ColorOf(key)
end

local function Round(value)
    if value - math.floor(value) > 0.5 then
        value = value + 0.5
    end
    return math.floor(value)
end

local function IsMountedNow()
    if UnitInVehicle("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    if IsMounted and IsMounted() then return true end
    return false
end

local function UpdateColors()
    if not frame or not db then return end
    local fr, fg, fb = ColorOf("frameColor")
    frame:SetBackdropColor(fr, fg, fb, db.frameColor and db.frameColor.a or 1)
    if db.showBorder ~= false then
        frame:SetBackdropBorderColor(ColorOf("borderColor"))
    else
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if bar then
        if db.showBar ~= false then bar:Show() else bar:Hide() end
    end
    if text then
        if db.showPercent ~= false then text:Show() else text:Hide() end
    end
    if resizeButton then
        if db.frameLocked then resizeButton:Hide() else resizeButton:Show() end
    end
end

local function ApplyFrame()
    if not frame or not db then return end
    local point = db.point and db.point.anchor or "TOP"
    local x = db.point and db.point.x or 0
    local y = db.point and db.point.y or -50
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
    frame:SetSize(db.width or 110, db.height or 30)
end

local function ShouldShow(percent)
    if not db or db.enabled == false then return false end
    if db.hideUnmounted and not IsMountedNow() then return false end
    if db.hideWhenIdle and percent <= 0 then return false end
    return true
end

local function UpdateSpeed()
    if not db then return end

    local speed = GetUnitSpeed(currentUnit)
    local percent = 0
    local known = speed and speed >= 0

    if known then
        percent = Round(speed / BASE_SPEED * 100)
        if db.absoluteSpeed ~= true and (IsSwimming() or IsFlying()) then
            percent = Round(percent * math.cos(GetUnitPitch(currentUnit)))
        end
    end

    if text then
        if known then
            text:SetText(string.format("%d%%", percent))
        else
            text:SetText("???")
        end
    end
    if bar then
        if known then
            bar:SetVertexColor(SpeedColor(percent))
        else
            bar:SetVertexColor(0.5, 0.5, 0.5)
        end
    end

    if ShouldShow(known and percent or 0) then
        frame:Show()
    else
        frame:Hide()
    end
end

local function SavePosition()
    local point, _, _, x, y = frame:GetPoint(1)
    if point and db then
        db.point = { anchor = point, x = x or 0, y = y or -50 }
    end
    db.width = frame:GetWidth()
    db.height = frame:GetHeight()
end

local function CreateSpeedometerFrame()
    frame = CreateFrame("Frame", "DragonUI_Speedometer", UIParent)
    frame:SetSize(110, 30)
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetMinResize(20, 20)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(BAR_TEXTURE)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)

    text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(1, 1, 1)
    text:SetText("0%")

    resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(8, 8)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    resizeButton:SetNormalTexture(RESIZE_TEXTURE)
    resizeButton:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not db.frameLocked then frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)

    frame:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and db.rightClickOpensConfig ~= false then
            local entry = { label = "Enable Speedometer" }
            if addon.OptionsPanel then
                addon.OptionsPanel:Open("enhancements", entry)
            elseif addon.ToggleOptionsUI then
                addon:ToggleOptionsUI("enhancements")
                if addon.OptionsPanel then
                    addon.OptionsPanel:Open("enhancements", entry)
                end
            end
        end
    end)
    frame:Hide()
end

local function CreateDriver()
    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, elapsed)
        if not SpeedometerModule.applied then return end
        accumulator = accumulator + elapsed
        if accumulator >= UPDATE_INTERVAL then
            accumulator = 0
            UpdateSpeed()
        end
    end)

    driver:RegisterEvent("UNIT_ENTERED_VEHICLE")
    driver:RegisterEvent("UNIT_EXITED_VEHICLE")
    driver:SetScript("OnEvent", function(_, event, unit)
        if unit ~= "player" then return end
        if event == "UNIT_ENTERED_VEHICLE" then
            currentUnit = "vehicle"
        else
            currentUnit = "player"
        end
        UpdateSpeed()
    end)
end

function addon.ApplySpeedometerSystem()
    db = addon:GetModuleConfig("speedometer")
    if not frame then CreateSpeedometerFrame() end
    if not driver then CreateDriver() end
    accumulator = 0
    currentUnit = UnitInVehicle("player") and "vehicle" or "player"
    ApplyFrame()
    UpdateColors()
    SpeedometerModule.applied = true
    UpdateSpeed()
end

function addon.RestoreSpeedometerSystem()
    SpeedometerModule.applied = false
    if frame then frame:Hide() end
end

function addon.RefreshSpeedometerSystem()
    if addon:IsModuleEnabled("speedometer") then
        addon.ApplySpeedometerSystem()
    else
        addon.RestoreSpeedometerSystem()
    end
end

function addon.RefreshSpeedometerVisuals()
    if not frame or not db then return end
    UpdateColors()
    UpdateSpeed()
end

function addon.RefreshSpeedometerPosition()
    if frame and db then ApplyFrame() end
end
