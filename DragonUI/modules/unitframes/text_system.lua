local addon = select(2, ...)

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

-- Function to abbreviate large numbers
function TextSystem.AbbreviateLargeNumbers(value)
    if not value or type(value) ~= "number" then
        return "0"
    end
    if value < 1000 then
        return tostring(value)
    end

    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
end

-- Main text formatting function
function TextSystem.FormatStatusText(current, maximum, textFormat, useBreakup, frameType)
    if maximum == nil or maximum == 0 or current == nil then
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
    
    --  CHECK IF THE UNIT EXISTS AND IS ALIVE
    if not UnitExists(actualUnit) or UnitIsDeadOrGhost(actualUnit) then
        return TextSystem.ClearFrameText(parentFrame, prefix)
    end

    local config = TextSystem.GetFrameTextConfig(frameType)

    -- Detect specific hover on each bar
    local healthHover = healthBar and TextSystem.IsMouseOverFrame(healthBar) or false
    local manaHover = manaBar and TextSystem.IsMouseOverFrame(manaBar) or false

    -- Determine whether to show each text type
    local shouldShowHealth = config.showHealthTextAlways or healthHover
    local shouldShowMana = config.showManaTextAlways or manaHover

    -- Update health text
    if healthBar and shouldShowHealth then
        local health = UnitHealth(actualUnit) or 0
        local maxHealth = UnitHealthMax(actualUnit) or 1
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

    if not healthBar then

    end

    if not manaBar then

    end

    prefix = prefix or frameType:gsub("^%l", string.upper) .. "Frame"

    -- Store reference to returned textSystem for dynamic unit access
    local textSystemRef = { unit = unit }
    
    --  COMMON UPDATE FUNCTION
    local function updateCallback()
        TextSystem.UpdateFrameText(frameType, unit, parentFrame, healthBar, manaBar, prefix, textSystemRef)
    end

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

-- Set up hover events for text display (player frame uses click-through)
function TextSystem.SetupHoverEvents(parentFrame, healthBar, manaBar, updateCallback)
    -- Detect if it's PlayerFrame to apply click-through
    local parentName = parentFrame:GetName() or ""
    local isPlayerFrame = (parentName:find("DragonUIUnitframeFrame") ~= nil)
    
    if healthBar then
        local healthHover = CreateFrame("Frame", nil, parentFrame)
        healthHover:SetAllPoints(healthBar)
        healthHover:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
        
        if isPlayerFrame then
            -- PLAYER FRAME: Click-through enabled
            healthHover:EnableMouse(false)  -- DO NOT capture clicks
            -- Phase 3C: Use HookScript on Blizzard StatusBar to avoid taint
            if not healthBar.DragonUIHoverSetup then
                healthBar:EnableMouse(true)
                healthBar:HookScript("OnEnter", updateCallback)
                healthBar:HookScript("OnLeave", updateCallback)
                healthBar.DragonUIHoverSetup = true
            end
        else
            -- OTHER FRAMES (Focus, Target): Original behavior
            healthHover:EnableMouse(true)
            healthHover:SetScript("OnEnter", updateCallback)
            healthHover:SetScript("OnLeave", updateCallback)
        end

        parentFrame.DragonUIHealthHover = healthHover
    end

    if manaBar then
        local manaHover = CreateFrame("Frame", nil, parentFrame)
        manaHover:SetAllPoints(manaBar)
        manaHover:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
        
        if isPlayerFrame then
            -- PLAYER FRAME: Click-through enabled
            manaHover:EnableMouse(false)  -- DO NOT capture clicks
            -- Phase 3C: Use HookScript on Blizzard StatusBar to avoid taint
            if not manaBar.DragonUIHoverSetup then
                manaBar:EnableMouse(true)
                manaBar:HookScript("OnEnter", updateCallback)
                manaBar:HookScript("OnLeave", updateCallback)
                manaBar.DragonUIHoverSetup = true
            end
        else
            -- OTHER FRAMES (Focus, Target): Original behavior
            manaHover:EnableMouse(true)
            manaHover:SetScript("OnEnter", updateCallback)
            manaHover:SetScript("OnLeave", updateCallback)
        end

        parentFrame.DragonUIManaHover = manaHover
    end
end

