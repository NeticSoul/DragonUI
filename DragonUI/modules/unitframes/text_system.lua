-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local LOCALE_UNITS = ({
    zhCN = { { 100000000, "亿" }, { 10000, "万" } },
    zhTW = { { 100000000, "億" }, { 10000, "萬" } },
    koKR = { { 100000000, "억" }, { 10000, "만" } },
})[GetLocale()]

-- ===============================================================
-- DRAGONUI TEXT SYSTEM
-- ===============================================================

local TextSystem = {}
addon.TextSystem = TextSystem

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Available text formats
TextSystem.TEXT_FORMATS = {
    numeric = "numeric", -- Current numbers only
    percentage = "percentage", -- Percentage only  
    both = "both", -- Numbers + percentage (dual)
    formatted = "formatted" -- "current / max" format
}

-- ===============================================================
-- CORE FORMATTING FUNCTIONS
-- ===============================================================

-- Format large values using the client's familiar number units.
function TextSystem.AbbreviateLargeNumbers(value)
    if not value or type(value) ~= "number" then
        return "0"
    end

    if LOCALE_UNITS then
        for _, unit in ipairs(LOCALE_UNITS) do
            if value >= unit[1] then
                return (string.format("%.1f", value / unit[1]):gsub("%.0$", "")) .. unit[2]
            end
        end
        return tostring(value)
    end

    if value < 1000 then
        return tostring(value)
    elseif value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
end

-- Main text formatting function
function TextSystem.FormatStatusText(current, maximum, textFormat, useBreakup, frameType)
    if not current or not maximum or maximum == 0 then
        return ""
    end

    local currentText, maxText
    if useBreakup then
        currentText = TextSystem.AbbreviateLargeNumbers(current)
        maxText = TextSystem.AbbreviateLargeNumbers(maximum)
    else
        currentText = tostring(current)
        maxText = tostring(maximum)
    end

    local percent = math.floor((current / maximum) * 100)

    if textFormat == TextSystem.TEXT_FORMATS.numeric then
        return currentText
    elseif textFormat == TextSystem.TEXT_FORMATS.percentage then
        return percent .. "%"
    elseif textFormat == TextSystem.TEXT_FORMATS.both then
        return {
            left = percent .. "%",
            right = currentText
        }
    elseif textFormat == TextSystem.TEXT_FORMATS.formatted then
        return currentText .. " / " .. maxText
    else
        -- Default fallback
        return currentText .. " / " .. maxText
    end
end

-- ===============================================================
-- TEXT ELEMENT SYSTEM
-- ===============================================================

-- Function to create dual text elements (for "both" format)
function TextSystem.CreateDualTextElements(parentFrame, barFrame, prefix, layer, font)
    layer = layer or "OVERLAY"
    font = font or "TextStatusBarText"

    local elements = {}

    -- Center text (for numeric, percentage, formatted formats)
    if not parentFrame[prefix .. "Text"] then
        local centerText = barFrame:CreateFontString(nil, layer, font)
        local fontPath, originalSize, flags = centerText:GetFont()
        if fontPath and originalSize then
            centerText:SetFont(fontPath, originalSize + 1, flags) --  LARGER FONT
        end
        if prefix == "TargetFrameMana" then
            centerText:SetPoint("CENTER", barFrame, "CENTER", -2, 0)
        elseif prefix == "FocusFrameMana" then
            centerText:SetPoint("CENTER", barFrame, "CENTER", -3, 0)
        elseif prefix == "PetFrameMana" then
            centerText:SetPoint("CENTER", barFrame, "CENTER", 1, 0)
        else
            centerText:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
        end
        centerText:SetJustifyH("CENTER")
        parentFrame[prefix .. "Text"] = centerText
        elements.center = centerText
    end

    -- Left text (for "both" format)
    if not parentFrame[prefix .. "TextLeft"] then
        local leftText = barFrame:CreateFontString(nil, layer, font)
        local fontPath, originalSize, flags = leftText:GetFont()
        if fontPath and originalSize then
            leftText:SetFont(fontPath, originalSize + 1, flags) --  LARGER FONT
        end
        leftText:SetPoint("LEFT", barFrame, "LEFT", 6, 0)
        leftText:SetJustifyH("LEFT")
        parentFrame[prefix .. "TextLeft"] = leftText
        elements.left = leftText
    end

    -- Right text (for "both" format)
    if not parentFrame[prefix .. "TextRight"] then
        local rightText = barFrame:CreateFontString(nil, layer, font)
        local fontPath, originalSize, flags = rightText:GetFont()
        if fontPath and originalSize then
            rightText:SetFont(fontPath, originalSize + 1, flags) --  LARGER FONT
        end

        --  SPECIAL POSITION FOR TARGET AND FOCUS MANA TEXT
        if prefix == "TargetFrameMana" then
            rightText:SetPoint("RIGHT", barFrame, "RIGHT", -13, 0) --  FURTHER LEFT
        elseif prefix == "FocusFrameMana" then
            rightText:SetPoint("RIGHT", barFrame, "RIGHT", -13, 0) --  FURTHER LEFT
        else
            rightText:SetPoint("RIGHT", barFrame, "RIGHT", -6, 0) --  NORMAL POSITION
        end

        rightText:SetJustifyH("RIGHT")
        parentFrame[prefix .. "TextRight"] = rightText
        elements.right = rightText
    end

    return elements
end

-- ===============================================================
-- EDITOR PREVIEW (stand-in numbers and a timed reveal for fake frames)
-- ===============================================================

local PREVIEW_SECONDS = 3
local previewUntil = {}
local previewUpdaters = {}

local function EditorIsActive()
    local mode = addon.EditorMode
    return mode and mode.IsActive and mode:IsActive() and true or false
end
TextSystem.IsEditorActive = EditorIsActive

-- The fake frames borrow the player's numbers, like they already borrow the portrait and name.
function TextSystem.GetPreviewUnit(unit)
    if EditorIsActive() and not UnitExists(unit) then
        return "player", true
    end
    return unit, false
end

-- Low-level characters have tiny pools; scaled up, "Format Large Numbers" has something to abbreviate.
function TextSystem.ScalePreviewValues(kind, current, maximum)
    local target = kind == "health" and 25000 or 12000
    current, maximum = tonumber(current) or 0, tonumber(maximum) or 0
    if maximum <= 0 then return target, target end
    if maximum >= target then return current, maximum end
    local factor = target / maximum
    return math.floor(current * factor), math.floor(maximum * factor)
end

function TextSystem.IsPreviewing(frameType)
    local deadline = previewUntil[frameType]
    return deadline ~= nil and GetTime() < deadline
end

-- Registers what refreshes a frame type's texts (the party frames add their own).
function TextSystem.RegisterPreviewUpdater(frameType, fn)
    previewUpdaters[frameType] = fn
end

local function RunPreviewUpdater(frameType)
    local fn = previewUpdaters[frameType]
    if fn then fn() end
end

-- Repaints a frame type's texts from its settings alone, ending any reveal in progress.
function TextSystem.RefreshTexts(frameType)
    previewUntil[frameType] = nil
    RunPreviewUpdater(frameType)
end

-- Shows the texts of one frame type for a few seconds so a format change is visible.
function TextSystem.PreviewTexts(frameType)
    if not EditorIsActive() then return end
    previewUntil[frameType] = GetTime() + PREVIEW_SECONDS
    RunPreviewUpdater(frameType)
    addon:After(PREVIEW_SECONDS + 0.1, function()
        if not TextSystem.IsPreviewing(frameType) then RunPreviewUpdater(frameType) end
    end)
end

-- ===============================================================
-- TEXT UPDATE SYSTEM (HYBRID)
-- ===============================================================

-- Function to update text in dual elements
function TextSystem.UpdateDualText(parentFrame, prefix, formattedText, textFormat, shouldShow)
    local centerText = parentFrame[prefix .. "Text"]
    local leftText = parentFrame[prefix .. "TextLeft"]
    local rightText = parentFrame[prefix .. "TextRight"]

    if not shouldShow then
        -- Hide ALL text elements
        if centerText then
            centerText:Hide()
        end
        if leftText then
            leftText:Hide()
        end
        if rightText then
            rightText:Hide()
        end
        return
    end

    if textFormat == TextSystem.TEXT_FORMATS.both and type(formattedText) == "table" then
        -- Dual format: show left and right, hide center
        if centerText then
            centerText:Hide()
        end
        if leftText then
            leftText:SetText(formattedText.left or "")
            leftText:Show()
        end
        if rightText then
            rightText:SetText(formattedText.right or "")
            rightText:Show()
        end
    else
        -- Simple format: show center, hide left and right
        if leftText then
            leftText:Hide()
        end
        if rightText then
            rightText:Hide()
        end
        if centerText then
            centerText:SetText(formattedText or "")
            centerText:Show()
        end
    end
end

-- ===============================================================
-- UTILITY FUNCTIONS
-- ===============================================================

-- Detect if the mouse is hovering over a frame
function TextSystem.IsMouseOverFrame(frame)
    if not frame or not frame:IsVisible() then
        return false
    end

    --  USE IsMouseOver() WHICH IS MORE RELIABLE
    return frame:IsMouseOver()
end

-- Function to get text configuration for a unitframe
function TextSystem.GetFrameTextConfig(frameType, configKey)
    if not addon.db or not addon.db.profile or not addon.db.profile.unitframe then
        return {}
    end

    local config = addon.db.profile.unitframe[frameType] or {}
    return {
        textFormat = config.textFormat or "both",
        breakUpLargeNumbers = config.breakUpLargeNumbers or false,
        showHealthTextAlways = config.showHealthTextAlways or false,
        showManaTextAlways = config.showManaTextAlways or false
    }
end

-- ===============================================================
-- HYBRID SYSTEM - HOOK + HOVER + EVENTS
-- ===============================================================

-- Hook StatusBar:SetValue for automatic text updates
function TextSystem.HookStatusBar(statusBar, parentFrame, prefix, frameType, unit, updateCallback)
    if not statusBar or not parentFrame then
        return
    end

    if not statusBar.DragonUIHooked then
        hooksecurefunc(statusBar, "SetValue", function(self, value)
            -- Update our text immediately after Blizzard's SetValue completes
            if updateCallback then
                updateCallback()
            end
        end)
        statusBar.DragonUIHooked = true

    end
end

-- ===============================================================
-- SPECIFIC INTEGRATION FUNCTIONS (COMPLETE)
-- ===============================================================

-- Function to update health/mana text for any unitframe
function TextSystem.UpdateFrameText(frameType, unit, parentFrame, healthBar, manaBar, prefix, textSystemRef)
    -- Use dynamic unit from textSystem if available, otherwise use passed unit
    local actualUnit = (textSystemRef and textSystemRef.unit) or unit
    local fake
    actualUnit, fake = TextSystem.GetPreviewUnit(actualUnit)

    --  CHECK IF THE UNIT EXISTS AND IS ALIVE
    if not UnitExists(actualUnit) or (not fake and UnitIsDeadOrGhost(actualUnit)) then
        return TextSystem.ClearFrameText(parentFrame, prefix)
    end

    local config = TextSystem.GetFrameTextConfig(frameType)

    -- Detect specific hover on each bar
    local healthHover = healthBar and TextSystem.IsMouseOverFrame(healthBar) or false
    local manaHover = manaBar and TextSystem.IsMouseOverFrame(manaBar) or false
    local previewing = TextSystem.IsPreviewing(frameType)

    -- Determine whether to show each text type
    local shouldShowHealth = config.showHealthTextAlways or healthHover or previewing
    local shouldShowMana = config.showManaTextAlways or manaHover or previewing

    -- If UnitFrameLayers missing-health mode is active for this friendly non-pet unit,
    -- hide TextSystem health text to prevent overlap and let missing-health text take priority.
    -- Exception: friendly target/player in "both" mode can show both TextSystem + missing-health text.
    local moduleCfg = addon.GetModuleConfig and addon:GetModuleConfig("unitframe_layers")
    local missingHealthEnabled = moduleCfg and moduleCfg.missing_health == true
    local missingHealthEligible = frameType ~= "pet"
        and addon.UFL_ShouldShowMissingHealthForUnit
        and addon.UFL_ShouldShowMissingHealthForUnit(actualUnit)
    local allowBothWithMissing = (frameType == "target" or frameType == "player" or frameType == "focus")
        and config.textFormat == TextSystem.TEXT_FORMATS.both
    if missingHealthEnabled and missingHealthEligible and not allowBothWithMissing then
        shouldShowHealth = false
    end

    -- Update health text
    if healthBar and shouldShowHealth then
        local health = UnitHealth(actualUnit) or 0
        local maxHealth = UnitHealthMax(actualUnit) or 1
        if fake then health, maxHealth = TextSystem.ScalePreviewValues("health", health, maxHealth) end
        local healthText = TextSystem.FormatStatusText(health, maxHealth, config.textFormat, config.breakUpLargeNumbers,
            frameType)
        TextSystem.UpdateDualText(parentFrame, prefix .. "Health", healthText, config.textFormat, true)
    else
        TextSystem.UpdateDualText(parentFrame, prefix .. "Health", "", config.textFormat, false)
    end

    -- Update mana text
    if manaBar and shouldShowMana then
        local power = UnitPower(actualUnit) or 0
        local maxPower = UnitPowerMax(actualUnit) or 1
        if fake then power, maxPower = TextSystem.ScalePreviewValues("mana", power, maxPower) end
        local powerText = TextSystem.FormatStatusText(power, maxPower, config.textFormat, config.breakUpLargeNumbers,
            frameType)
        TextSystem.UpdateDualText(parentFrame, prefix .. "Mana", powerText, config.textFormat, true)
    else
        TextSystem.UpdateDualText(parentFrame, prefix .. "Mana", "", config.textFormat, false)
    end
end

-- Function to clear all texts from a frame
function TextSystem.ClearFrameText(parentFrame, prefix)
    TextSystem.UpdateDualText(parentFrame, prefix .. "Health", "", "numeric", false)
    TextSystem.UpdateDualText(parentFrame, prefix .. "Mana", "", "numeric", false)
end

-- ===============================================================
-- INITIAL SETUP FUNCTIONS (HYBRID)
-- ===============================================================

-- Setup text system for any unit frame
function TextSystem.SetupFrameTextSystem(frameType, unit, parentFrame, healthBar, manaBar, prefix)
    -- Input validation
    if not parentFrame then

        return {
            update = function()
            end,
            clear = function()
            end
        }
    end

    prefix = prefix or frameType:gsub("^%l", string.upper) .. "Frame"

    -- Store reference to returned textSystem for dynamic unit access
    local textSystemRef = { unit = unit }
    
    --  COMMON UPDATE FUNCTION
    local function updateCallback()
        TextSystem.UpdateFrameText(frameType, unit, parentFrame, healthBar, manaBar, prefix, textSystemRef)
    end
    TextSystem.RegisterPreviewUpdater(frameType, updateCallback)

    --  CREATE DUAL TEXT ELEMENTS (WITH LARGER FONT)
    if healthBar then
        TextSystem.CreateDualTextElements(parentFrame, healthBar, prefix .. "Health", "OVERLAY", "TextStatusBarText")
        --  HOOK STATUSBAR FOR AUTOMATIC UPDATES
        TextSystem.HookStatusBar(healthBar, parentFrame, prefix .. "Health", frameType, unit, updateCallback)
    end
    if manaBar then
        TextSystem.CreateDualTextElements(parentFrame, manaBar, prefix .. "Mana", "OVERLAY", "TextStatusBarText")
        --  HOOK STATUSBAR FOR AUTOMATIC UPDATES
        TextSystem.HookStatusBar(manaBar, parentFrame, prefix .. "Mana", frameType, unit, updateCallback)
    end

    --  SET UP HOVER EVENTS (KEEP)
    TextSystem.SetupHoverEvents(parentFrame, healthBar, manaBar, updateCallback)

    return {
        update = updateCallback,
        clear = function()
            TextSystem.ClearFrameText(parentFrame, prefix)
        end,
        unit = unit,  -- For compatibility
        -- Internal reference that can be modified dynamically
        _unitRef = textSystemRef
    }
end

-- One shared sweep: an OnUpdate per bar costs more than checking every watched frame at once.
local hoverWatchers = {}
local hoverPoller = CreateFrame("Frame")
hoverPoller:Hide()
hoverPoller.elapsed = 0
hoverPoller:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.05 then return end
    self.elapsed = 0

    for _, watcher in ipairs(hoverWatchers) do
        local shown = watcher.parent:IsVisible()
        local overHealth = (shown and TextSystem.IsMouseOverFrame(watcher.health)) and true or false
        local overMana = (shown and TextSystem.IsMouseOverFrame(watcher.mana)) and true or false
        if overHealth ~= watcher.overHealth or overMana ~= watcher.overMana then
            watcher.overHealth, watcher.overMana = overHealth, overMana
            watcher.update()
        end
    end
end)

-- Set up hover events for text display
function TextSystem.SetupHoverEvents(parentFrame, healthBar, manaBar, updateCallback)
    -- Mouse-enabled bars would swallow the unit button's tooltip and clicks; poll geometry instead.
    if healthBar then healthBar:EnableMouse(false) end
    if manaBar then manaBar:EnableMouse(false) end

    local watcher = parentFrame.DragonUIHoverWatcher
    if watcher then
        watcher.health, watcher.mana, watcher.update = healthBar, manaBar, updateCallback
        return
    end

    watcher = {parent = parentFrame, health = healthBar, mana = manaBar, update = updateCallback}
    parentFrame.DragonUIHoverWatcher = watcher
    table.insert(hoverWatchers, watcher)
    hoverPoller:Show()
end

