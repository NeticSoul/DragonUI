local addon = select(2, ...)
local unitframe = {}
addon.unitframe = unitframe

--[[
* DragonUI Unit Frame Module
* 
* This module handles all unit frame customizations including:
* - Player, Target, Pet, ToT, and Party frames
* - Health and power bars
* - Text display and formatting
* - Frame positioning and scaling
* - Combat state handling
* - Event registration and updates
--]]

-- Module frame object to store custom UI elements
local frame = {}

-- =====================================================================
-- START: TAINT-FREE PET THREAT SYSTEM
-- This system prevents combat errors by separating configuration from the combat event.
-- =====================================================================
-- 1. A local variable to store the current state of the threat glow setting.
--    This avoids accessing addon settings during combat.
local isPetThreatGlowEnabled = true

-- 2. A function that will be called from the options menu to turn the system on or off.
function unitframe.SetPetThreatGlow(enabled)
    isPetThreatGlowEnabled = enabled
end
-- =====================================================================
-- END: TAINT-FREE PET THREAT SYSTEM
-- =====================================================================

-- =====================================================================
-- START: TAINT-FREE CONFIGURATION CACHE
-- Estas variables locales guardan la configuración para evitar leerla en combate.
-- =====================================================================
local safeConfig = {
    player = {},
    target = {},
    focus = {},
    party = {},
    pet = {}
}

-- Esta función se llamará cada vez que se cambie una opción para actualizar nuestra caché segura.
function unitframe.UpdateSafeConfig()
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end
    local db = addon.db.profile.unitframe

    safeConfig.player = db.player or {}
    safeConfig.target = db.target or {}
    safeConfig.focus = db.focus or {}
    safeConfig.party = db.party or {}
    safeConfig.pet = db.pet or {}
end
-- =====================================================================
-- END: TAINT-FREE CONFIGURATION CACHE
-- =====================================================================

-- Famous players table for special highlighting or treatment
-- Add player names as keys with 'true' as value to mark them as famous
unitframe.famous = {
    ['Patufet'] = true
}

------------------------------------------
-- Configuration and State Variables
------------------------------------------
local db, getOptions
local mName = 'UnitFrame'

-- WoW 3.3.5a Global API references for compatibility and performance
-- Localizing these functions improves performance by avoiding global lookups
local InCombatLockdown = InCombatLockdown -- Checks if player is in combat lockdown
local UnitAffectingCombat = UnitAffectingCombat -- Checks if a unit is in combat
local CreateFrame = CreateFrame -- Creates UI frame objects
local UIParent = UIParent -- The main UI container frame
local UnitExists = UnitExists -- Checks if a unit exists
local UnitHealth = UnitHealth -- Gets current health of a unit
local UnitHealthMax = UnitHealthMax -- Gets maximum health of a unit
local UnitPower = UnitPower -- Gets current power (mana, energy, etc.) of a unit
local UnitPowerMax = UnitPowerMax -- Gets maximum power of a unit

-- Empty function used to disable or override default functionality
local function noop()
end

--[[
* Optimized text truncation function to prevent flickering
* 
* Uses binary search algorithm to efficiently find the optimal truncation point,
* minimizing the number of SetText calls which reduces UI flickering
* 
* @param textFrame FontString - The text frame object to modify
* @param name string - The original text to display
* @param maxWidth number - The maximum width in pixels for the text
* @return string - The final text string (truncated if necessary)
--]]
local function TruncateToTText(textFrame, name, maxWidth)
    if not textFrame or not name or name == "" then
        if textFrame then
            textFrame:SetText("")
        end
        return ""
    end

    -- First check if truncation is needed without setting text
    local tempText = name
    textFrame:SetText(tempText)
    local currentWidth = textFrame:GetStringWidth()

    if currentWidth <= maxWidth then
        return name -- No truncation needed
    end

    -- Binary search for optimal truncation point to minimize SetText calls
    local left, right = 1, string.len(name)
    local bestTruncated = name

    while left <= right do
        local mid = math.floor((left + right) / 2)
        local testText = string.sub(name, 1, mid) .. "..."
        textFrame:SetText(testText)
        local testWidth = textFrame:GetStringWidth()

        if testWidth <= maxWidth then
            bestTruncated = testText
            left = mid + 1
        else
            right = mid - 1
        end
    end

    return bestTruncated
end

-- Utility function to format large numbers with abbreviations (e.g., 12.3k, 1.4M)
local function AbbreviateLargeNumbers(value)
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

-- Format health/mana text according to settings
--[[
* Format status text for health/power bars based on configuration options
*
* @param current number - Current value (health/power)
* @param maximum number - Maximum value (max health/power) 
* @param textFormat string - Format type: 'numeric', 'percentage', 'both', or 'formatted'
* @param useBreakup boolean - Whether to format large numbers with commas/periods
* @param frameType string - Type of unit frame (player, target, etc.)
* @return string|table - Formatted text string or table with different format options
--]]
local function FormatStatusText(current, maximum, textFormat, useBreakup, frameType)
    if frameType then
        local unit =
            frameType == "player" and "player" or frameType == "target" and "target" or frameType == "focus" and "focus" or
                frameType == "pet" and "pet" or nil

        if unit then
            if UnitIsDeadOrGhost(unit) or not UnitExists(unit) then
                return ""
            end
            -- AÑADIR: Verificación adicional para unidades offline
            if UnitIsConnected and not UnitIsConnected(unit) then
                return ""
            end
        end
    end
    -- If useBreakup is nil, try to auto-detect the frame type
    if useBreakup == nil then
        if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
            -- Auto-detect frame type by comparing with current unit values
            local playerHealth = UnitHealth("player")
            local targetHealth = UnitExists("target") and UnitHealth("target") or 0
            local focusHealth = UnitExists("focus") and UnitHealth("focus") or 0
            local petHealth = UnitExists("pet") and UnitHealth("pet") or 0

            local frameType = "player" -- default

            -- Check each frame type in order of specificity
            if current == focusHealth and current ~= playerHealth and current ~= targetHealth and focusHealth > 0 then
                frameType = "focus"
            elseif current == targetHealth and current ~= playerHealth and targetHealth > 0 then
                frameType = "target"
            elseif current == petHealth and current ~= playerHealth and petHealth > 0 then
                frameType = "pet"
            elseif current == playerHealth then
                frameType = "player"
            else
                -- Check for party members-> moved to party block
            end

            local config = addon.db.profile.unitframe[frameType]
            useBreakup = config and config.breakUpLargeNumbers
            if useBreakup == nil then
                useBreakup = false
            end
        else
            useBreakup = false
        end
    end

    if not current or not maximum or maximum == 0 then
        return ""
    end

    local currentText, maxText
    if useBreakup then
        currentText = AbbreviateLargeNumbers(current)
        maxText = AbbreviateLargeNumbers(maximum)
    else
        currentText = tostring(current)
        maxText = tostring(maximum)
    end

    local percent = math.floor((current / maximum) * 100)

    if textFormat == "numeric" then
        return currentText
    elseif textFormat == "percentage" then
        return percent .. "%"
    elseif textFormat == "both" then
        return {
            percentage = percent .. "%",
            current = currentText,
            combined = percent .. "%" .. "                     " .. currentText -- fallback for compatibility
        }
    elseif textFormat == "formatted" then
        return currentText .. " / " .. maxText
    else
        -- Default fallback
        return currentText .. " / " .. maxText
    end
end

-- =============================================================================
-- MASTER REFRESH SYSTEM (RESTRUCTURED)
-- =============================================================================

-- 1. The single, master refresh function. This is the ONLY function that should be called
--    when settings change or profiles are switched.
function addon:RefreshUnitFrames()
    if not (PlayerFrame and TargetFrame) then
        return
    end

    -- First, apply all position, scale, and override settings
    if unitframe.ApplySettings then
        unitframe:ApplySettings()
    end

    -- Second, re-style all frames with their respective textures and colors
    unitframe.ChangePlayerframe()
    unitframe.ChangeTargetFrame()
    unitframe.ReApplyTargetFrame()
    unitframe.ChangeStatusIcons()

    if FocusFrame then
        unitframe.ChangeFocusFrame()
        unitframe.ReApplyFocusFrame()
        unitframe.ChangeFocusToT()
        if UnitExists('focustarget') then
            unitframe.ReApplyFocusToTFrame()
        end
    end

    if PetFrame then
        unitframe.ChangePetFrame()
    end

    unitframe.ChangeToT()
    if UnitExists('targettarget') then
        unitframe.ReApplyToTFrame()
    end

    -- Third, refresh Party Frames layout and textures
    if unitframe.PartyMoveFrame then
        local partySettings = addon:GetConfigValue("unitframe", "party")
        if partySettings then
            unitframe:UpdatePartyState(partySettings)
        end
        unitframe.RefreshAllPartyFrames()
    end

    -- Finally, update all text displays according to the new settings
    if unitframe.UpdateAllTextDisplays then
        unitframe.UpdateAllTextDisplays()
    end
end

-- FIXED: Function to clear target frame texts when target changes or disappears
function unitframe.ClearTargetFrameTexts()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- Clear health texts
    if dragonFrame.TargetFrameHealthBarText then
        dragonFrame.TargetFrameHealthBarText:SetText("")
        dragonFrame.TargetFrameHealthBarText:Hide()
    end
    if dragonFrame.TargetFrameHealthBarTextLeft then
        dragonFrame.TargetFrameHealthBarTextLeft:SetText("")
        dragonFrame.TargetFrameHealthBarTextLeft:Hide()
    end
    if dragonFrame.TargetFrameHealthBarTextRight then
        dragonFrame.TargetFrameHealthBarTextRight:SetText("")
        dragonFrame.TargetFrameHealthBarTextRight:Hide()
    end

    -- Clear mana texts
    if dragonFrame.TargetFrameManaBarText then
        dragonFrame.TargetFrameManaBarText:SetText("")
        dragonFrame.TargetFrameManaBarText:Hide()
    end
    if dragonFrame.TargetFrameManaBarTextLeft then
        dragonFrame.TargetFrameManaBarTextLeft:SetText("")
        dragonFrame.TargetFrameManaBarTextLeft:Hide()
    end
    if dragonFrame.TargetFrameManaBarTextRight then
        dragonFrame.TargetFrameManaBarTextRight:SetText("")
        dragonFrame.TargetFrameManaBarTextRight:Hide()
    end
end

-- FIXED: Function to clear player frame texts when needed
function unitframe.ClearPlayerFrameTexts()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- Clear health texts
    if dragonFrame.PlayerFrameHealthBarText then
        dragonFrame.PlayerFrameHealthBarText:SetText("")
        dragonFrame.PlayerFrameHealthBarText:Hide()
    end
    if dragonFrame.PlayerFrameHealthBarTextLeft then
        dragonFrame.PlayerFrameHealthBarTextLeft:SetText("")
        dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
    end
    if dragonFrame.PlayerFrameHealthBarTextRight then
        dragonFrame.PlayerFrameHealthBarTextRight:SetText("")
        dragonFrame.PlayerFrameHealthBarTextRight:Hide()
    end

    -- Clear mana texts
    if dragonFrame.PlayerFrameManaBarText then
        dragonFrame.PlayerFrameManaBarText:SetText("")
        dragonFrame.PlayerFrameManaBarText:Hide()
    end
    if dragonFrame.PlayerFrameManaBarTextLeft then
        dragonFrame.PlayerFrameManaBarTextLeft:SetText("")
        dragonFrame.PlayerFrameManaBarTextLeft:Hide()
    end
    if dragonFrame.PlayerFrameManaBarTextRight then
        dragonFrame.PlayerFrameManaBarTextRight:SetText("")
        dragonFrame.PlayerFrameManaBarTextRight:Hide()
    end

    -- FIXED: Also hide Blizzard's default texts to prevent conflicts
    if PlayerFrameHealthBarText then
        PlayerFrameHealthBarText:Hide()
    end
    if PlayerFrameHealthBarTextLeft then
        PlayerFrameHealthBarTextLeft:Hide()
    end
    if PlayerFrameHealthBarTextRight then
        PlayerFrameHealthBarTextRight:Hide()
    end
    if PlayerFrameManaBarText then
        PlayerFrameManaBarText:Hide()
    end
    if PlayerFrameManaBarTextLeft then
        PlayerFrameManaBarTextLeft:Hide()
    end
    if PlayerFrameManaBarTextRight then
        PlayerFrameManaBarTextRight:Hide()
    end
end

------------------------------------------
-- Default Configuration Settings
------------------------------------------
-- We directly use the centralized settings from database.lua
-- This ensures that all configuration is maintained in a single location
-- and reduces code duplication

-- Access to unitframe defaults through addon.defaults.profile.unitframe
-- This approach improves maintainability and consistency

-- We use a local reference to the original frame positions
-- that can be saved and restored without modifying user settings
local localSettings = {}

-- Helper function to get the default value string for configuration UI tooltips
-- @param key string - The configuration key to look up
-- @param sub string - Optional sub-category for nested settings
-- @return string - Formatted string showing the default value
local function getDefaultStr(key, sub)

    local unitframeDefaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.unitframe or {}

    if sub and unitframeDefaults[sub] then
        local value = unitframeDefaults[sub][key]
        return '\n' .. '(Default: ' .. tostring(value) .. ')'
    elseif unitframeDefaults[key] then
        local value = unitframeDefaults[key]
        return '\n' .. '(Default: ' .. tostring(value) .. ')'
    else
        return '\n' .. '(Default: not set)'
    end
end

local function setDefaultValues()
    local unitframeDefaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.unitframe or {}
    for k, v in pairs(unitframeDefaults) do
        if type(v) == 'table' then
            for kSub, vSub in pairs(v) do
                if addon:GetConfigValue("unitframe", k, kSub) == nil then
                    addon:SetConfigValue("unitframe", k, kSub, vSub)
                end
            end
        else
            if addon:GetConfigValue("unitframe", k) == nil then
                addon:SetConfigValue("unitframe", k, nil, v)
            end
        end
    end
end

-- Function to retrieve configuration values adapted for DragonUI unit frames
-- @param info table - Configuration key path 
-- @return any - The stored configuration value or default if not found
local function getOption(info)
    local key = info[1]
    local sub = info[2]

    if sub then
        return addon:GetConfigValue("unitframe", key, sub)
    else
        return addon:GetConfigValue("unitframe", key)
    end
end

local function setOption(info, value)
    local key = info[1]
    local sub = info[2]

    if sub then
        addon:SetConfigValue("unitframe", key, sub, value)
    else
        addon:SetConfigValue("unitframe", key, nil, value)
    end

    -- CRITICAL FIX: Call the single, master refresh function for ANY change.
    -- This guarantees that all frames are updated consistently when any option
    -- is changed from the settings panel.
    addon:RefreshUnitFrames()

    unitframe.UpdateSafeConfig()
end

-- Common definitions to reuse across all frame options
-- These anchor points define all possible frame positioning options
local commonAnchorValues = {
    ['TOP'] = 'TOP',
    ['RIGHT'] = 'RIGHT',
    ['BOTTOM'] = 'BOTTOM',
    ['LEFT'] = 'LEFT',
    ['TOPRIGHT'] = 'TOPRIGHT',
    ['TOPLEFT'] = 'TOPLEFT',
    ['BOTTOMLEFT'] = 'BOTTOMLEFT',
    ['BOTTOMRIGHT'] = 'BOTTOMRIGHT',
    ['CENTER'] = 'CENTER'
}

-- Common text format options for displaying numerical values
-- These define how health, mana and other resources are displayed
local commonTextFormats = {
    ['numeric'] = 'Numeric Only',
    ['percentage'] = 'Percentage Only',
    ['both'] = 'Both (Numbers + Percentage)',
    ['formatted'] = 'Formatted Numbers'
}

-- Function to create full configuration options for unit frames
-- @param frameName string - Display name of the frame in configuration
-- @param frameDesc string - Description of the frame
-- @param unitKey string - Key identifier for the frame (player, target, etc.)
-- @return table - Complete options table for the frame
local function CreateUnitFrameOptions(frameName, frameDesc, unitKey)
    local options = {
        name = frameName,
        desc = frameDesc,
        get = getOption,
        set = setOption,
        type = 'group',
        args = {
            configGeneral = {
                type = 'header',
                name = 'General',
                order = 10
            },
            classcolor = {
                type = 'toggle',
                name = 'Class Color',
                desc = 'Enable class colors for the healthbar',
                order = 10.1
            },
            configText = {
                type = 'header',
                name = 'Text Format',
                order = 15
            },
            textFormat = {
                type = 'select',
                name = 'Health/Mana Text Format',
                desc = 'Choose how to display health and mana values:\n• Numeric: 1234 / 2000\n• Percentage: 85%\n• Both: 1234 / 2000 (85%)\n• Formatted: 1,234 / 2,000',
                values = commonTextFormats,
                order = 15.1
            },
            breakUpLargeNumbers = {
                type = 'toggle',
                name = 'Use Comma Separators',
                desc = 'Format large numbers with commas (e.g., 1,234 instead of 1234)',
                order = 15.2
            },
            configSize = {
                type = 'header',
                name = 'Size',
                order = 50
            },
            scale = {
                type = 'range',
                name = 'Scale',
                desc = '' .. getDefaultStr('scale', unitKey),
                min = 0.1,
                max = 3,
                bigStep = 0.025,
                order = 50.1
            },
            configPos = {
                type = 'header',
                name = 'Position',
                order = 100
            },
            override = {
                type = 'toggle',
                name = 'Override',
                desc = 'Override positions',
                order = 101,
                width = 'full'
            },
            anchor = {
                type = 'select',
                name = 'Anchor',
                desc = 'Anchor' .. getDefaultStr('anchor', unitKey),
                values = commonAnchorValues,
                order = 105
            },
            anchorParent = {
                type = 'select',
                name = 'AnchorParent',
                desc = 'AnchorParent' .. getDefaultStr('anchorParent', unitKey),
                values = commonAnchorValues,
                order = 105.1
            },
            x = {
                type = 'range',
                name = 'X',
                desc = 'X relative to *ANCHOR*' .. getDefaultStr('x', unitKey),
                min = -2500,
                max = 2500,
                bigStep = 0.50,
                order = 107
            },
            y = {
                type = 'range',
                name = 'Y',
                desc = 'Y relative to *ANCHOR*' .. getDefaultStr('y', unitKey),
                min = -2500,
                max = 2500,
                bigStep = 0.50,
                order = 108
            }
        }
    }

    -- Add specific options for player and target frames only
    -- These options provide additional text display controls
    if unitKey == 'player' or unitKey == 'target' then
        options.args.showHealthTextAlways = {
            type = 'toggle',
            name = 'Always Show Health Text',
            desc = 'Always display health text (otherwise only on mouseover)',
            order = 15.3
        }
        options.args.showManaTextAlways = {
            type = 'toggle',
            name = 'Always Show Mana Text',
            desc = 'Always display mana/energy/rage text (otherwise only on mouseover)',
            order = 15.4
        }
    end

    return options
end

-- Create options for each main frame type using the common function
-- This generates all configuration structure for primary frames
local optionsPlayer = CreateUnitFrameOptions('Player', 'Player Frame Settings', 'player')
local optionsTarget = CreateUnitFrameOptions('Target', 'Target Frame Settings', 'target')
local optionsFocus = CreateUnitFrameOptions('Focus', 'Focus Frame Settings', 'focus')

-- Secondary frames options (ToT and FoT)
-- These frames have simpler options than primary frames

-- Function to create simplified options for secondary frames (ToT and FoT)
-- @param frameName string - Display name of the frame in configuration
-- @param frameDesc string - Description of the frame
-- @param unitKey string - Key identifier for the frame
-- @return table - Simplified options table for the frame
local function CreateCompactFrameOptions(frameName, frameDesc, unitKey)
    return {
        name = frameName,
        desc = frameDesc,
        get = getOption,
        set = setOption,
        type = 'group',
        args = {
            classcolor = {
                type = 'toggle',
                name = 'Class Color',
                desc = 'Enable class colors for the healthbar',
                order = 1
            },
            scale = {
                type = 'range',
                name = 'Scale',
                desc = 'Frame scale',
                min = 0.1,
                max = 3,
                bigStep = 0.025,
                order = 2
            },
            x = {
                type = 'range',
                name = 'X Position',
                desc = 'X relative to anchor' .. getDefaultStr('x', unitKey),
                min = -2500,
                max = 2500,
                bigStep = 0.50,
                order = 3
            },
            y = {
                type = 'range',
                name = 'Y Position',
                desc = 'Y relative to anchor' .. getDefaultStr('y', unitKey),
                min = -2500,
                max = 2500,
                bigStep = 0.50,
                order = 4
            }
        }
    }
end

-- Create options for secondary frames using the compact options function
-- ToT = Target of Target
-- FoT = Focus of Target
local optionsToT = CreateCompactFrameOptions('Target of Target', 'Target of Target Frame configuration', 'tot')
local optionsFoT = CreateCompactFrameOptions('Focus of Target', 'Focus of Target Frame configuration', 'fot')



local options = {
    type = 'group',
    name = 'DragonUI - ' .. mName,
    get = getOption,
    set = setOption,
    args = {
        toggle = {
            type = 'toggle',
            name = 'Enable',
            get = function()
                return addon:GetConfigValue("unitframe", "enabled")
            end,
            set = function(info, v)
                addon:SetConfigValue("unitframe", "enabled", nil, v)
            end,
            order = 1
        },
        reload = {
            type = 'execute',
            name = '/reload',
            desc = 'reloads UI',
            func = function()
                ReloadUI()
            end,
            order = 1.1
        },
        defaults = {
            type = 'execute',
            name = 'Defaults',
            desc = 'Sets Config to default values',
            func = setDefaultValues,
            order = 1.1
        },
        focus = optionsFocus,
        player = optionsPlayer,
        target = optionsTarget,
        pet = optionsPet,
        tot = optionsToT,
        fot = optionsFoT,
        party = optionsParty
    }
}

function unitframe:Initialize()
    -- Module initialization adapted for DragonUI
    setDefaultValues()

    -- Initialize the optimized texture system
    unitframe.InitializeOptimizedSystem()
end

function unitframe:OnEnable()
    -- Enable the module adapted for DragonUI
    -- Events are registered at the end of the file where the frame is defined

    -- Initialization - save current settings and apply configurations
    unitframe:SaveLocalSettings()
    unitframe:ApplySettings()
	
	-- Hook for Health Loss effect
	unitframe.HookHealthBarValues()

    -- Basic hooks (only the original ones)
    unitframe.HookFunctions()
    unitframe.HookDrag()

    -- Hooks for persistent colors of target and focus frames
    unitframe.HookVertexColor()
    if unitframe.HookManaBarColors then
        unitframe.HookManaBarColors()
    end
end

function unitframe:OnDisable()
end

function unitframe:SaveLocalSettings()
    -- Initialize localSettings tables if they don't exist
    if not localSettings.player then
        localSettings.player = {}
    end
    if not localSettings.target then
        localSettings.target = {}
    end
    if not localSettings.focus then
        localSettings.focus = {}
    end
    if not localSettings.party then
        localSettings.party = {}
    end

    -- Save Player frame position and scale
    -- This captures the current state to be restored later if needed
    do
        local scale = PlayerFrame:GetScale()
        local point, relativeTo, relativePoint, xOfs, yOfs = PlayerFrame:GetPoint(1)

        local obj = localSettings.player
        obj.scale = scale
        obj.anchor = point
        obj.anchorParent = relativePoint
        obj.x = xOfs
        obj.y = yOfs
    end

    -- Save Target frame position and scale
    do
        local scale = TargetFrame:GetScale()
        local point, relativeTo, relativePoint, xOfs, yOfs = TargetFrame:GetPoint(1)

        local obj = localSettings.target
        obj.scale = scale
        obj.anchor = point
        obj.anchorParent = relativePoint
        obj.x = xOfs
        obj.y = yOfs
    end

    -- Save Focus frame position and scale
    if true then
        do
            local scale = FocusFrame:GetScale()
            local point, relativeTo, relativePoint, xOfs, yOfs = FocusFrame:GetPoint(1)

            local obj = localSettings.focus
            obj.scale = scale
            obj.anchor = point
            obj.anchorParent = relativePoint
            obj.x = xOfs
            obj.y = yOfs
        end
    end

    -- DevTools_Dump({localSettings})
end
function unitframe:ApplySettings()
    -- Use centralized settings from database.lua
    -- No need for local copies of defaults

    -- playerframe
    do
        local playerConfig = addon:GetConfigValue("unitframe", "player") or {}

        if not localSettings.player then
            localSettings.player = {}
        end
        local objLocal = localSettings.player

        -- Use database values if override is active, otherwise use local (default) settings
        local anchor = playerConfig.override and playerConfig.anchor or objLocal.anchor
        local anchorParent = playerConfig.override and playerConfig.anchorParent or objLocal.anchorParent
        local anchorPoint = playerConfig.override and playerConfig.anchorPoint or objLocal.anchorParent -- ✅ Get the correct anchor point
        local x = playerConfig.override and playerConfig.x or objLocal.x
        local y = playerConfig.override and playerConfig.y or objLocal.y

        if playerConfig.override then
            PlayerFrame:SetUserPlaced(true)
        end

        -- ✅ Call MovePlayerFrame with the correct arguments
        unitframe.MovePlayerFrame(anchor, anchorParent, anchorPoint, x, y)
        PlayerFrame:SetScale(playerConfig.scale or 1)
    end

    -- target
    do
        -- ✅ CORRECCIÓN: Cargar la configuración del target desde la base de datos.
        local targetConfig = addon:GetConfigValue("unitframe", "target") or {}

        if not localSettings.target then
            localSettings.target = {}
        end
        local objLocal = localSettings.target
        -- Set defaults if missing
        if not objLocal.anchor then
            objLocal.anchor = addon.defaults.profile.unitframe.target.anchor
        end
        if not objLocal.anchorParent then
            objLocal.anchorParent = addon.defaults.profile.unitframe.target.anchorParent
        end
        if not objLocal.x then
            objLocal.x = addon.defaults.profile.unitframe.target.x
        end
        if not objLocal.y then
            objLocal.y = addon.defaults.profile.unitframe.target.y
        end

        if targetConfig.override then
            TargetFrame:SetMovable(1)
            TargetFrame:StartMoving()
            unitframe.MoveTargetFrame(targetConfig.anchor, targetConfig.anchorParent, targetConfig.x, targetConfig.y)
            -- TargetFrame:SetUserPlaced(true)
            TargetFrame:StopMovingOrSizing()
            TargetFrame:SetMovable()
        else
            unitframe.MoveTargetFrame(objLocal.anchor, objLocal.anchorParent, objLocal.x, objLocal.y)
        end
        -- Support for Combo Points scaling
        TargetFrame:SetScale(targetConfig.scale)
        if ComboFrame and TargetFrame then
            ComboFrame:SetScale(TargetFrame:GetScale() or 1)
        end

    end

    if true then
        -- focus
        do
            -- ✅ CORRECCIÓN: Usar la misma lógica de carga que Player/Target.
            local focusConfig = addon:GetConfigValue("unitframe", "focus") or {}

            if not localSettings.focus then
                localSettings.focus = {}
            end
            local objLocal = localSettings.focus

            -- Usar valores de la base de datos si override está activo, si no, los locales.
            local anchor = focusConfig.override and focusConfig.anchor or objLocal.anchor
            local anchorParent = focusConfig.override and focusConfig.anchorParent or objLocal.anchorParent
            local anchorPoint = focusConfig.override and focusConfig.anchorPoint or objLocal.anchorParent
            local x = focusConfig.override and focusConfig.x or objLocal.x
            local y = focusConfig.override and focusConfig.y or objLocal.y
            local scale = focusConfig.scale or 1.0

            if focusConfig.override then
                FocusFrame:SetMovable(true) -- Hacerlo movible primero
                FocusFrame:SetUserPlaced(true)
            end

            -- ✅ Llamar a MoveFocusFrame con los 5 argumentos correctos.
            unitframe.MoveFocusFrame(anchor, anchorParent, anchorPoint, x, y)
            FocusFrame:SetScale(scale)
        end
    end
    -- ✅ AÑADIDO: Lógica para aplicar la configuración del grupo.
    do
        local partyConfig = addon:GetConfigValue("unitframe", "party") or {}
        if unitframe.PartyMoveFrame then
            -- La función UpdatePartyState ya contiene toda la lógica de posicionamiento.
            -- Simplemente la llamamos para que aplique la configuración guardada.
            unitframe:UpdatePartyState(partyConfig)
        end
    end

    -- TEMPORARILY DISABLED - Testing to find what broke player frame
    -- Update all text displays immediately after applying settings
    -- unitframe.UpdateAllTextDisplays()
end

-- Function to update all text displays immediately
function unitframe.UpdateAllTextDisplays()
    -- Verificar que addon.db est? disponible antes de proceder
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end

    -- Get reference to the DragonUI frame that stores our custom text elements
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- Update party frame texts (AÑADIDO)
    for i = 1, 4 do
        if _G['PartyMemberFrame' .. i] and UnitExists('party' .. i) then
            unitframe.UpdatePartyFrameText(i)
        end
    end

    -- Update player frame custom texts based on individual settings
    if UnitExists('player') then
        local config = addon.db.profile.unitframe.player or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        local health = UnitHealth('player') or 0
        local maxHealth = UnitHealthMax('player') or 1
        local power = UnitPower('player') or 0
        local maxPower = UnitPowerMax('player') or 1

        local textFormat = config.textFormat or "both"
        local useBreakup = config.breakUpLargeNumbers or false

        local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup)
        local powerText = FormatStatusText(power, maxPower, textFormat, useBreakup)

        -- FIXED: NO hover detection in UpdateAllTextDisplays - only show if always enabled

        -- Handle health text with dual elements for "both" format
        if textFormat == "both" and type(healthText) == "table" then
            -- Show left and right elements for dual display
            if dragonFrame.PlayerFrameHealthBarTextLeft then
                if showHealthAlways then
                    dragonFrame.PlayerFrameHealthBarTextLeft:SetText(healthText.percentage or "")
                    dragonFrame.PlayerFrameHealthBarTextLeft:Show()
                else
                    dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
                end
            end
            if dragonFrame.PlayerFrameHealthBarTextRight then
                if showHealthAlways then
                    dragonFrame.PlayerFrameHealthBarTextRight:SetText(healthText.current or "")
                    dragonFrame.PlayerFrameHealthBarTextRight:Show()
                else
                    dragonFrame.PlayerFrameHealthBarTextRight:Hide()
                end
            end
            -- Hide single element when using dual
            if dragonFrame.PlayerFrameHealthBarText then
                dragonFrame.PlayerFrameHealthBarText:Hide()
            end
        else
            -- Single element display for other formats
            if dragonFrame.PlayerFrameHealthBarText then
                if showHealthAlways then
                    dragonFrame.PlayerFrameHealthBarText:SetText(healthText)
                    dragonFrame.PlayerFrameHealthBarText:Show()
                else
                    dragonFrame.PlayerFrameHealthBarText:Hide()
                end
            end
            -- Hide dual elements when using single
            if dragonFrame.PlayerFrameHealthBarTextLeft then
                dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.PlayerFrameHealthBarTextRight then
                dragonFrame.PlayerFrameHealthBarTextRight:Hide()
            end
        end

        -- Handle mana text with dual elements for "both" format
        if textFormat == "both" and type(powerText) == "table" then
            -- Show left and right elements for dual display
            if dragonFrame.PlayerFrameManaBarTextLeft then
                if showManaAlways then
                    dragonFrame.PlayerFrameManaBarTextLeft:SetText(powerText.percentage or "")
                    dragonFrame.PlayerFrameManaBarTextLeft:Show()
                else
                    dragonFrame.PlayerFrameManaBarTextLeft:Hide()
                end
            end
            if dragonFrame.PlayerFrameManaBarTextRight then
                if showManaAlways then
                    dragonFrame.PlayerFrameManaBarTextRight:SetText(powerText.current or "")
                    dragonFrame.PlayerFrameManaBarTextRight:Show()
                else
                    dragonFrame.PlayerFrameManaBarTextRight:Hide()
                end
            end
            -- Hide single element when using dual
            if dragonFrame.PlayerFrameManaBarText then
                dragonFrame.PlayerFrameManaBarText:Hide()
            end
        else
            -- Single element display for other formats
            if dragonFrame.PlayerFrameManaBarText then
                if showManaAlways then
                    dragonFrame.PlayerFrameManaBarText:SetText(powerText)
                    dragonFrame.PlayerFrameManaBarText:Show()
                else
                    dragonFrame.PlayerFrameManaBarText:Hide()
                end
            end
            -- Hide dual elements when using single
            if dragonFrame.PlayerFrameManaBarTextLeft then
                dragonFrame.PlayerFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.PlayerFrameManaBarTextRight then
                dragonFrame.PlayerFrameManaBarTextRight:Hide()
            end
        end
    end

    -- Target frame is now handled exclusively by UpdateTargetFrameText() to avoid conflicts

    -- Update focus frame custom texts based on individual settings
    if UnitExists('focus') then
        local config = addon.db.profile.unitframe.focus or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        local health = UnitHealth('focus') or 0
        local maxHealth = UnitHealthMax('focus') or 1
        local power = UnitPower('focus') or 0
        local maxPower = UnitPowerMax('focus') or 1

        local textFormat = config.textFormat or "both"
        local useBreakup = config.breakUpLargeNumbers or false

        local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup)
        local powerText = FormatStatusText(power, maxPower, textFormat, useBreakup)

        -- FIXED: Check if mouse is over focus frames
        local focusHealthHover = IsMouseOverFrame(dragonFrame.FocusFrameHealthBarDummy)
        local focusManaHover = IsMouseOverFrame(dragonFrame.FocusFrameManaBarDummy)

        -- Handle health text with dual elements for "both" format
        if textFormat == "both" and type(healthText) == "table" then
            -- Show left and right elements for dual display
            if dragonFrame.FocusFrameHealthBarTextLeft then
                if showHealthAlways or focusHealthHover then
                    dragonFrame.FocusFrameHealthBarTextLeft:SetText(healthText.percentage or "")
                    dragonFrame.FocusFrameHealthBarTextLeft:Show()
                else
                    dragonFrame.FocusFrameHealthBarTextLeft:Hide()
                end
            end
            if dragonFrame.FocusFrameHealthBarTextRight then
                if showHealthAlways or focusHealthHover then
                    dragonFrame.FocusFrameHealthBarTextRight:SetText(healthText.current or "")
                    dragonFrame.FocusFrameHealthBarTextRight:Show()
                else
                    dragonFrame.FocusFrameHealthBarTextRight:Hide()
                end
            end
            -- Hide single element when using dual
            if dragonFrame.FocusFrameHealthBarText then
                dragonFrame.FocusFrameHealthBarText:Hide()
            end
        else
            -- Single element display for other formats
            if dragonFrame.FocusFrameHealthBarText then
                if showHealthAlways or focusHealthHover then
                    dragonFrame.FocusFrameHealthBarText:SetText(healthText)
                    dragonFrame.FocusFrameHealthBarText:Show()
                else
                    dragonFrame.FocusFrameHealthBarText:Hide()
                end
            end
            -- Hide dual elements when using single
            if dragonFrame.FocusFrameHealthBarTextLeft then
                dragonFrame.FocusFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.FocusFrameHealthBarTextRight then
                dragonFrame.FocusFrameHealthBarTextRight:Hide()
            end
        end

        -- Handle mana text with dual elements for "both" format
        if textFormat == "both" and type(powerText) == "table" then
            -- Show left and right elements for dual display
            if dragonFrame.FocusFrameManaBarTextLeft then
                if showManaAlways or focusManaHover then
                    dragonFrame.FocusFrameManaBarTextLeft:SetText(powerText.percentage or "")
                    dragonFrame.FocusFrameManaBarTextLeft:Show()
                else
                    dragonFrame.FocusFrameManaBarTextLeft:Hide()
                end
            end
            if dragonFrame.FocusFrameManaBarTextRight then
                if showManaAlways or focusManaHover then
                    dragonFrame.FocusFrameManaBarTextRight:SetText(powerText.current or "")
                    dragonFrame.FocusFrameManaBarTextRight:Show()
                else
                    dragonFrame.FocusFrameManaBarTextRight:Hide()
                end
            end
            -- Hide single element when using dual
            if dragonFrame.FocusFrameManaBarText then
                dragonFrame.FocusFrameManaBarText:Hide()
            end
        else
            -- Single element display for other formats
            if dragonFrame.FocusFrameManaBarText then
                if showManaAlways or focusManaHover then
                    dragonFrame.FocusFrameManaBarText:SetText(powerText)
                    dragonFrame.FocusFrameManaBarText:Show()
                else
                    dragonFrame.FocusFrameManaBarText:Hide()
                end
            end
            -- Hide dual elements when using single
            if dragonFrame.FocusFrameManaBarTextLeft then
                dragonFrame.FocusFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.FocusFrameManaBarTextRight then
                dragonFrame.FocusFrameManaBarTextRight:Hide()
            end
        end
    end
end

-- Function to update target frame custom text displays - IMPROVED VERSION
function unitframe.UpdateTargetFrameText()
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end

    -- Get reference to the DragonUI frame
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- FIXED: Clear target frame texts if no target exists
    if not UnitExists('target') or UnitIsDeadOrGhost('target') then
        unitframe.ClearTargetFrameTexts()
        return
    end

    if UnitIsPlayer('target') and UnitIsConnected and not UnitIsConnected('target') then
        unitframe.ClearTargetFrameTexts()
        return
    end

    -- TAINT-FIX: Usar la caché segura.
    local config = safeConfig.target or {}
    local showHealthAlways = config.showHealthTextAlways or false
    local showManaAlways = config.showManaTextAlways or false
    local textFormat = config.textFormat or "numeric"
    local useBreakup = config.breakUpLargeNumbers or false

    -- FIXED: Improved hover detection function for specific bars
    local function IsMouseOverFrame(frame)
        if not frame or not frame:IsVisible() then
            return false
        end
        local mouseX, mouseY = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        if not scale or scale == 0 then
            return false
        end
        mouseX = mouseX / scale
        mouseY = mouseY / scale

        local left, bottom, width, height = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight()
        if not (left and bottom and width and height) then
            return false
        end

        local right = left + width
        local top = bottom + height

        return mouseX >= left and mouseX <= right and mouseY >= bottom and mouseY <= top
    end

    -- FIXED: Specific hover detection for individual bars only
    local targetHealthHover = TargetFrameHealthBar and IsMouseOverFrame(TargetFrameHealthBar)
    local targetManaHover = TargetFrameManaBar and IsMouseOverFrame(TargetFrameManaBar)

    -- Update health text
    if UnitExists('target') then
        local health = UnitHealth('target') or 0
        local maxHealth = UnitHealthMax('target') or 1

        -- FIXED: When breakUpLargeNumbers is enabled, always use abbreviated format
        -- The issue was that hover detection was failing, so we simplify the logic
        local shouldUseBreakup = useBreakup

        local healthText = FormatStatusText(health, maxHealth, textFormat, shouldUseBreakup)

        if textFormat == "both" then
            -- Use dual text elements for "both" format - ONLY show Left/Right, NOT combined
            if dragonFrame.TargetFrameHealthBarTextLeft and dragonFrame.TargetFrameHealthBarTextRight then
                dragonFrame.TargetFrameHealthBarTextLeft:SetText(healthText.percentage)
                dragonFrame.TargetFrameHealthBarTextRight:SetText(healthText.current)

                if showHealthAlways or targetHealthHover then
                    dragonFrame.TargetFrameHealthBarTextLeft:Show()
                    dragonFrame.TargetFrameHealthBarTextRight:Show()
                else
                    dragonFrame.TargetFrameHealthBarTextLeft:Hide()
                    dragonFrame.TargetFrameHealthBarTextRight:Hide()
                end

                -- FIXED: Hide the combined text element to avoid duplication in "both" format
                if dragonFrame.TargetFrameHealthBarText then
                    dragonFrame.TargetFrameHealthBarText:Hide()
                end
            end
        else
            -- Use single text element for other formats
            if dragonFrame.TargetFrameHealthBarText then
                local displayText = type(healthText) == "table" and healthText.combined or healthText
                dragonFrame.TargetFrameHealthBarText:SetText(displayText)

                if showHealthAlways or targetHealthHover then
                    dragonFrame.TargetFrameHealthBarText:Show()
                else
                    dragonFrame.TargetFrameHealthBarText:Hide()
                end
            end

            -- Hide dual text elements
            if dragonFrame.TargetFrameHealthBarTextLeft then
                dragonFrame.TargetFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.TargetFrameHealthBarTextRight then
                dragonFrame.TargetFrameHealthBarTextRight:Hide()
            end
        end
    end

    -- Update mana text
    if UnitExists('target') then
        local power = UnitPower('target') or 0
        local maxPower = UnitPowerMax('target') or 1

        -- FIXED: When breakUpLargeNumbers is enabled, always use abbreviated format
        -- The issue was that hover detection was failing, so we simplify the logic
        local shouldUseBreakup = useBreakup

        local powerText = FormatStatusText(power, maxPower, textFormat, shouldUseBreakup)

        if textFormat == "both" then
            -- Use dual text elements for "both" format - ONLY show Left/Right, NOT combined
            if dragonFrame.TargetFrameManaBarTextLeft and dragonFrame.TargetFrameManaBarTextRight then
                dragonFrame.TargetFrameManaBarTextLeft:SetText(powerText.percentage)
                dragonFrame.TargetFrameManaBarTextRight:SetText(powerText.current)

                if showManaAlways or targetManaHover then
                    dragonFrame.TargetFrameManaBarTextLeft:Show()
                    dragonFrame.TargetFrameManaBarTextRight:Show()
                else
                    dragonFrame.TargetFrameManaBarTextLeft:Hide()
                    dragonFrame.TargetFrameManaBarTextRight:Hide()
                end

                -- FIXED: Hide the combined text element to avoid duplication in "both" format
                if dragonFrame.TargetFrameManaBarText then
                    dragonFrame.TargetFrameManaBarText:Hide()
                end
            end
        else
            -- Use single text element for other formats
            if dragonFrame.TargetFrameManaBarText then
                local displayText = type(powerText) == "table" and powerText.combined or powerText
                dragonFrame.TargetFrameManaBarText:SetText(displayText)

                if showManaAlways or targetManaHover then
                    dragonFrame.TargetFrameManaBarText:Show()
                else
                    dragonFrame.TargetFrameManaBarText:Hide()
                end
            end

            -- Hide dual text elements
            if dragonFrame.TargetFrameManaBarTextLeft then
                dragonFrame.TargetFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.TargetFrameManaBarTextRight then
                dragonFrame.TargetFrameManaBarTextRight:Hide()
            end
        end
    end
end

local function HandleUnitDeath(unit)
    if unit == "target" then
        unitframe.ClearTargetFrameTexts()
    elseif unit == "focus" then
        -- Limpiar textos del focus
        local dragonFrame = _G["DragonUIUnitframeFrame"]
        if dragonFrame then
            if dragonFrame.FocusFrameHealthBarText then
                dragonFrame.FocusFrameHealthBarText:Hide()
            end
            if dragonFrame.FocusFrameManaBarText then
                dragonFrame.FocusFrameManaBarText:Hide()
            end
            if dragonFrame.FocusFrameHealthBarTextLeft then
                dragonFrame.FocusFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.FocusFrameHealthBarTextRight then
                dragonFrame.FocusFrameHealthBarTextRight:Hide()
            end
            if dragonFrame.FocusFrameManaBarTextLeft then
                dragonFrame.FocusFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.FocusFrameManaBarTextRight then
                dragonFrame.FocusFrameManaBarTextRight:Hide()
            end
        end
    elseif unit == "pet" then
        unitframe.UpdatePetFrameText()
    elseif string.match(unit or "", "^party[1-4]$") then
        local partyIndex = tonumber(string.match(unit, 'party([1-4])'))
        if partyIndex then
            unitframe.ClearPartyFrameTexts(partyIndex)
        end
    elseif unit == "player" then
        unitframe.ClearPlayerFrameTexts()
    end
end
-- FIXED: Setup proper hover events for PlayerFrame to ensure consistent text display behavior
function unitframe.SetupPlayerFrameHoverEvents()
    if not PlayerFrame then
        return
    end

    -- Create invisible overlay frames for health and mana bars to capture mouse events
    if not PlayerFrame.DragonUIHealthHover then
        local healthHover = CreateFrame("Frame", nil, PlayerFrame)
        healthHover:SetAllPoints(PlayerFrameHealthBar)
        healthHover:EnableMouse(true)
        healthHover:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)

        healthHover:SetScript("OnEnter", function()
            -- FIXED: Only show health text when hovering health bar
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.player
            if config then
                unitframe.UpdatePlayerFrameTextSelective(true, config.showManaTextAlways or false)
            end
        end)

        healthHover:SetScript("OnLeave", function()
            -- FIXED: Clear health text when leaving health bar (unless always shown)
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.player
            if config then
                unitframe.UpdatePlayerFrameTextSelective(config.showHealthTextAlways or false,
                    config.showManaTextAlways or false)
            end
        end)

        PlayerFrame.DragonUIHealthHover = healthHover
    end

    if not PlayerFrame.DragonUIManaHover then
        local manaHover = CreateFrame("Frame", nil, PlayerFrame)
        manaHover:SetAllPoints(PlayerFrameManaBar)
        manaHover:EnableMouse(true)
        manaHover:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)

        manaHover:SetScript("OnEnter", function()
            -- FIXED: Only show mana text when hovering mana bar
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.player
            if config then
                unitframe.UpdatePlayerFrameTextSelective(config.showHealthTextAlways or false, true)
            end
        end)

        manaHover:SetScript("OnLeave", function()
            -- FIXED: Clear mana text when leaving mana bar (unless always shown)
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.player
            if config then
                unitframe.UpdatePlayerFrameTextSelective(config.showHealthTextAlways or false,
                    config.showManaTextAlways or false)
            end
        end)

        PlayerFrame.DragonUIManaHover = manaHover
    end
end

-- Setup proper hover events for TargetFrame to ensure consistent text display behavior
function unitframe.SetupTargetFrameHoverEvents()
    if not TargetFrame then
        return
    end

    -- Create invisible overlay frames for health and mana bars to capture mouse events
    if not TargetFrame.DragonUIHealthHover then
        local healthHover = CreateFrame("Frame", nil, TargetFrame)
        healthHover:SetAllPoints(TargetFrameHealthBar)
        healthHover:EnableMouse(true)
        healthHover:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)

        healthHover:SetScript("OnEnter", function()
            -- FIXED: Simple hover logic like PlayerFrame
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.target
            if config then
                unitframe.UpdateTargetFrameTextSelective(true, config.showManaTextAlways or false)
            end
        end)

        healthHover:SetScript("OnLeave", function()
            -- FIXED: Simple hover logic like PlayerFrame
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.target
            if config then
                unitframe.UpdateTargetFrameTextSelective(config.showHealthTextAlways or false,
                    config.showManaTextAlways or false)
            end
        end)

        TargetFrame.DragonUIHealthHover = healthHover
    end

    if not TargetFrame.DragonUIManaHover then
        local manaHover = CreateFrame("Frame", nil, TargetFrame)
        manaHover:SetAllPoints(TargetFrameManaBar)
        manaHover:EnableMouse(true)
        manaHover:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)

        manaHover:SetScript("OnEnter", function()
            -- FIXED: Simple hover logic like PlayerFrame
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.target
            if config then
                unitframe.UpdateTargetFrameTextSelective(config.showHealthTextAlways or false, true)
            end
        end)

        manaHover:SetScript("OnLeave", function()
            -- FIXED: Simple hover logic like PlayerFrame
            local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                               addon.db.profile.unitframe.target
            if config then
                unitframe.UpdateTargetFrameTextSelective(config.showHealthTextAlways or false,
                    config.showManaTextAlways or false)
            end
        end)

        TargetFrame.DragonUIManaHover = manaHover
    end
end

-- Selective update function for TargetFrame text displays
function unitframe.UpdateTargetFrameTextSelective(showHealth, showMana)
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end

    -- Get reference to the DragonUI frame
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- FIXED: Clear target frame texts if no target exists
    if not UnitExists('target') then
        unitframe.ClearTargetFrameTexts()
        return
    end

    local config = addon.db.profile.unitframe.target or {}
    local textFormat = config.textFormat or "numeric"
    local useBreakup = config.breakUpLargeNumbers or false

    -- Update health text only if requested
    if showHealth and UnitExists('target') then
        local health = UnitHealth('target') or 0
        local maxHealth = UnitHealthMax('target') or 1

        local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup, "target")

        if type(healthText) == "table" then
            -- Handle "both" format with percentage and current values - ONLY show Left/Right, NOT combined
            if dragonFrame.TargetFrameHealthBarTextLeft then
                dragonFrame.TargetFrameHealthBarTextLeft:SetText(healthText.percentage or "")
                dragonFrame.TargetFrameHealthBarTextLeft:Show()
            end
            if dragonFrame.TargetFrameHealthBarTextRight then
                dragonFrame.TargetFrameHealthBarTextRight:SetText(healthText.current or "")
                dragonFrame.TargetFrameHealthBarTextRight:Show()
            end
            -- FIXED: Hide the combined text element to avoid duplication in "both" format
            if dragonFrame.TargetFrameHealthBarText then
                dragonFrame.TargetFrameHealthBarText:Hide()
            end
        else
            -- Handle single text format
            if dragonFrame.TargetFrameHealthBarText then
                dragonFrame.TargetFrameHealthBarText:SetText(healthText)
                dragonFrame.TargetFrameHealthBarText:Show()
            end
            -- Hide dual text elements for single format
            if dragonFrame.TargetFrameHealthBarTextLeft then
                dragonFrame.TargetFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.TargetFrameHealthBarTextRight then
                dragonFrame.TargetFrameHealthBarTextRight:Hide()
            end
        end
    else
        -- Hide health text
        if dragonFrame.TargetFrameHealthBarText then
            dragonFrame.TargetFrameHealthBarText:Hide()
        end
        if dragonFrame.TargetFrameHealthBarTextLeft then
            dragonFrame.TargetFrameHealthBarTextLeft:Hide()
        end
        if dragonFrame.TargetFrameHealthBarTextRight then
            dragonFrame.TargetFrameHealthBarTextRight:Hide()
        end
    end

    -- Update mana text only if requested
    if showMana and UnitExists('target') then
        local power = UnitPower('target') or 0
        local maxPower = UnitPowerMax('target') or 1

        local powerText = FormatStatusText(power, maxPower, textFormat, useBreakup, "target")

        if type(powerText) == "table" then
            -- Handle "both" format with percentage and current values - ONLY show Left/Right, NOT combined
            if dragonFrame.TargetFrameManaBarTextLeft then
                dragonFrame.TargetFrameManaBarTextLeft:SetText(powerText.percentage or "")
                dragonFrame.TargetFrameManaBarTextLeft:Show()
            end
            if dragonFrame.TargetFrameManaBarTextRight then
                dragonFrame.TargetFrameManaBarTextRight:SetText(powerText.current or "")
                dragonFrame.TargetFrameManaBarTextRight:Show()
            end
            -- FIXED: Hide the combined text element to avoid duplication in "both" format
            if dragonFrame.TargetFrameManaBarText then
                dragonFrame.TargetFrameManaBarText:Hide()
            end
        else
            -- Handle single text format
            if dragonFrame.TargetFrameManaBarText then
                dragonFrame.TargetFrameManaBarText:SetText(powerText)
                dragonFrame.TargetFrameManaBarText:Show()
            end
            -- Hide dual text elements for single format
            if dragonFrame.TargetFrameManaBarTextLeft then
                dragonFrame.TargetFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.TargetFrameManaBarTextRight then
                dragonFrame.TargetFrameManaBarTextRight:Hide()
            end
        end
    else
        -- Hide mana text
        if dragonFrame.TargetFrameManaBarText then
            dragonFrame.TargetFrameManaBarText:Hide()
        end
        if dragonFrame.TargetFrameManaBarTextLeft then
            dragonFrame.TargetFrameManaBarTextLeft:Hide()
        end
        if dragonFrame.TargetFrameManaBarTextRight then
            dragonFrame.TargetFrameManaBarTextRight:Hide()
        end
    end
end

-- IMPROVED: Wrapper function to safely update player frame text only when appropriate
function unitframe.SafeUpdatePlayerFrameText()
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end

    -- TAINT-FIX: Usar la caché segura.
    local config = safeConfig.player or {}
    local showHealthAlways = config.showHealthTextAlways or false
    local showManaAlways = config.showManaTextAlways or false

    -- FIXED: Improved hover detection for individual bars
    local function IsMouseOverFrame(frame)
        if not frame or not frame:IsVisible() then
            return false
        end
        local mouseX, mouseY = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        if not scale or scale == 0 then
            return false
        end
        mouseX = mouseX / scale
        mouseY = mouseY / scale

        local left, bottom, width, height = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight()
        if not (left and bottom and width and height) then
            return false
        end

        local right = left + width
        local top = bottom + height

        return mouseX >= left and mouseX <= right and mouseY >= bottom and mouseY <= top
    end

    -- FIXED: Check hover state for individual bars ONLY (no general frame hover)
    local healthBarHover = PlayerFrameHealthBar and IsMouseOverFrame(PlayerFrameHealthBar) or false
    local manaBarHover = PlayerFrameManaBar and IsMouseOverFrame(PlayerFrameManaBar) or false

    -- ✅ CORRECCIÓN LÓGICA: Determinar si se debe mostrar el texto.
    -- La opción "Always" tiene prioridad. El hover solo funciona si "Always" está desactivado.
    local shouldShowHealth = showHealthAlways or (healthBarHover and not showHealthAlways)
    local shouldShowMana = showManaAlways or (manaBarHover and not showManaAlways)

    -- Llamar a la función de actualización con los valores correctos.
    -- No es necesario un 'else' para limpiar, la propia función ya lo hace.
    unitframe.UpdatePlayerFrameTextSelective(shouldShowHealth, shouldShowMana)
end

-- FIXED: New function to update player frame texts selectively (health and/or mana)
function unitframe.UpdatePlayerFrameTextSelective(showHealth, showMana)
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end

    -- Get reference to the DragonUI frame
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    local config = addon.db.profile.unitframe.player or {}
    local textFormat = config.textFormat or "numeric"
    local useBreakup = config.breakUpLargeNumbers or false

    -- Update health text only if requested
    if showHealth and UnitExists('player') then
        local health = UnitHealth('player') or 0
        local maxHealth = UnitHealthMax('player') or 1

        local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup, "player")

        if type(healthText) == "table" then
            -- Handle "both" format with percentage and current values - ONLY show Left/Right, NOT combined
            if dragonFrame.PlayerFrameHealthBarTextLeft then
                dragonFrame.PlayerFrameHealthBarTextLeft:SetText(healthText.percentage or "")
                dragonFrame.PlayerFrameHealthBarTextLeft:Show()
            end
            if dragonFrame.PlayerFrameHealthBarTextRight then
                dragonFrame.PlayerFrameHealthBarTextRight:SetText(healthText.current or "")
                dragonFrame.PlayerFrameHealthBarTextRight:Show()
            end
            -- FIXED: Hide the combined text element to avoid duplication in "both" format
            if dragonFrame.PlayerFrameHealthBarText then
                dragonFrame.PlayerFrameHealthBarText:Hide()
            end
        else
            -- Handle simple text formats
            if dragonFrame.PlayerFrameHealthBarText then
                dragonFrame.PlayerFrameHealthBarText:SetText(healthText)
                dragonFrame.PlayerFrameHealthBarText:Show()
            end
            -- Clear left/right texts for simple formats
            if dragonFrame.PlayerFrameHealthBarTextLeft then
                dragonFrame.PlayerFrameHealthBarTextLeft:SetText("")
                dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.PlayerFrameHealthBarTextRight then
                dragonFrame.PlayerFrameHealthBarTextRight:SetText("")
                dragonFrame.PlayerFrameHealthBarTextRight:Hide()
            end
        end
    else
        -- Clear health texts if not requested
        if dragonFrame.PlayerFrameHealthBarText then
            dragonFrame.PlayerFrameHealthBarText:SetText("")
            dragonFrame.PlayerFrameHealthBarText:Hide()
        end
        if dragonFrame.PlayerFrameHealthBarTextLeft then
            dragonFrame.PlayerFrameHealthBarTextLeft:SetText("")
            dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
        end
        if dragonFrame.PlayerFrameHealthBarTextRight then
            dragonFrame.PlayerFrameHealthBarTextRight:SetText("")
            dragonFrame.PlayerFrameHealthBarTextRight:Hide()
        end
    end

    -- Update mana text only if requested
    if showMana and UnitExists('player') then
        local mana = UnitPower('player') or 0 -- FIXED: Use UnitPower
        local maxMana = UnitPowerMax('player') or 1 -- FIXED: Use UnitPowerMax

        local manaText = FormatStatusText(mana, maxMana, textFormat, useBreakup, "player")

        if type(manaText) == "table" then
            -- Handle "both" format with percentage and current values - ONLY show Left/Right, NOT combined
            if dragonFrame.PlayerFrameManaBarTextLeft then
                dragonFrame.PlayerFrameManaBarTextLeft:SetText(manaText.percentage or "")
                dragonFrame.PlayerFrameManaBarTextLeft:Show()
            end
            if dragonFrame.PlayerFrameManaBarTextRight then
                dragonFrame.PlayerFrameManaBarTextRight:SetText(manaText.current or "")
                dragonFrame.PlayerFrameManaBarTextRight:Show()
            end
            -- FIXED: Hide the combined text element to avoid duplication in "both" format
            if dragonFrame.PlayerFrameManaBarText then
                dragonFrame.PlayerFrameManaBarText:Hide()
            end
        else
            -- Handle simple text formats
            if dragonFrame.PlayerFrameManaBarText then
                dragonFrame.PlayerFrameManaBarText:SetText(manaText)
                dragonFrame.PlayerFrameManaBarText:Show()
            end
            -- Clear left/right texts for simple formats
            if dragonFrame.PlayerFrameManaBarTextLeft then
                dragonFrame.PlayerFrameManaBarTextLeft:SetText("")
                dragonFrame.PlayerFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.PlayerFrameManaBarTextRight then
                dragonFrame.PlayerFrameManaBarTextRight:SetText("")
                dragonFrame.PlayerFrameManaBarTextRight:Hide()
            end
        end
    else
        -- Clear mana texts if not requested
        if dragonFrame.PlayerFrameManaBarText then
            dragonFrame.PlayerFrameManaBarText:SetText("")
            dragonFrame.PlayerFrameManaBarText:Hide()
        end
        if dragonFrame.PlayerFrameManaBarTextLeft then
            dragonFrame.PlayerFrameManaBarTextLeft:SetText("")
            dragonFrame.PlayerFrameManaBarTextLeft:Hide()
        end
        if dragonFrame.PlayerFrameManaBarTextRight then
            dragonFrame.PlayerFrameManaBarTextRight:SetText("")
            dragonFrame.PlayerFrameManaBarTextRight:Hide()
        end
    end

    -- Handle Druid Alternate Mana Bar
    if PlayerFrameAlternateManaBar and PlayerFrameAlternateManaBar:IsVisible() then
        if not _G["DragonUIDruidManaText"] then
            local text = PlayerFrameAlternateManaBar:CreateFontString("DragonUIDruidManaText", "OVERLAY",
                "TextStatusBarText")
            text:SetPoint("CENTER", PlayerFrameAlternateManaBar, "CENTER", 0, 0)
        end
        if not _G["DragonUIDruidManaTextLeft"] then
            local textLeft = PlayerFrameAlternateManaBar:CreateFontString("DragonUIDruidManaTextLeft", "OVERLAY",
                "TextStatusBarText")
            textLeft:SetPoint("LEFT", PlayerFrameAlternateManaBar, "LEFT", 6, 0)
            textLeft:SetJustifyH("LEFT")
        end
        if not _G["DragonUIDruidManaTextRight"] then
            local textRight = PlayerFrameAlternateManaBar:CreateFontString("DragonUIDruidManaTextRight", "OVERLAY",
                "TextStatusBarText")
            textRight:SetPoint("RIGHT", PlayerFrameAlternateManaBar, "RIGHT", -6, 0)
            textRight:SetJustifyH("RIGHT")
        end

        local textFrame = _G["DragonUIDruidManaText"]
        local textFrameLeft = _G["DragonUIDruidManaTextLeft"]
        local textFrameRight = _G["DragonUIDruidManaTextRight"]

        if showMana then
            local mana, maxMana = UnitPower("player", 0), UnitPowerMax("player", 0)
            local formattedText = FormatStatusText(mana, maxMana, config.textFormat, config.breakUpLargeNumbers,
                "player")

            if type(formattedText) == "table" then
                textFrameLeft:SetText(formattedText.percentage or "")
                textFrameRight:SetText(formattedText.current or "")
                textFrameLeft:Show()
                textFrameRight:Show()
                textFrame:Hide()
            else
                textFrame:SetText(formattedText)
                textFrame:Show()
                textFrameLeft:Hide()
                textFrameRight:Hide()
            end
        else
            textFrame:Hide()
            textFrameLeft:Hide()
            textFrameRight:Hide()
        end
    elseif _G["DragonUIDruidManaText"] then
        _G["DragonUIDruidManaText"]:Hide()
        if _G["DragonUIDruidManaTextLeft"] then
            _G["DragonUIDruidManaTextLeft"]:Hide()
        end
        if _G["DragonUIDruidManaTextRight"] then
            _G["DragonUIDruidManaTextRight"]:Hide()
        end
    end
end

-- FIXED: Define IsMouseOverFrame globally for pet frame usage
function IsMouseOverFrame(frame)
    if not frame or not frame:IsVisible() then
        return false
    end
    local mouseX, mouseY = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    if not scale or scale == 0 then
        return false
    end
    mouseX = mouseX / scale
    mouseY = mouseY / scale

    local left, bottom, width, height = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight()
    if not (left and bottom and width and height) then
        return false
    end

    local right = left + width
    local top = bottom + height

    return mouseX >= left and mouseX <= right and mouseY >= bottom and mouseY <= top
end

-- FIXED: Enhanced UpdatePetFrameText function with full format support
function unitframe.UpdatePetFrameText()
    if not (addon and addon.db and addon.db.profile and addon.db.profile.unitframe) then
        return
    end
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    if not UnitExists('pet') then
        if dragonFrame.PetFrameHealthBarText then
            dragonFrame.PetFrameHealthBarText:Hide()
        end
        if dragonFrame.PetFrameHealthBarTextLeft then
            dragonFrame.PetFrameHealthBarTextLeft:Hide()
        end
        if dragonFrame.PetFrameHealthBarTextRight then
            dragonFrame.PetFrameHealthBarTextRight:Hide()
        end
        if dragonFrame.PetFrameManaBarText then
            dragonFrame.PetFrameManaBarText:Hide()
        end
        if dragonFrame.PetFrameManaBarTextLeft then
            dragonFrame.PetFrameManaBarTextLeft:Hide()
        end
        if dragonFrame.PetFrameManaBarTextRight then
            dragonFrame.PetFrameManaBarTextRight:Hide()
        end
        return
    end

    local config = addon.db.profile.unitframe.pet or {}
    local textFormat = config.textFormat or 'numeric'
    local useBreakup = config.breakUpLargeNumbers or false
    local showHealthAlways = config.showHealthTextAlways or false
    local showManaAlways = config.showManaTextAlways or false

    -- Use the same hover detection function as other frames
    -- FIXED: Check if the dummy frames exist before checking for mouseover
    local healthHover = dragonFrame.PetFrameHealthBarDummy and IsMouseOverFrame(dragonFrame.PetFrameHealthBarDummy) or
                            false
    local manaHover = dragonFrame.PetFrameManaBarDummy and IsMouseOverFrame(dragonFrame.PetFrameManaBarDummy) or false

    local shouldShowHealth = showHealthAlways or healthHover
    local shouldShowMana = showManaAlways or manaHover

    -- Health Logic
    if shouldShowHealth and UnitHealthMax('pet') > 0 then
        local health, maxHealth = UnitHealth('pet'), UnitHealthMax('pet')
        local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup, "pet")

        if textFormat == "both" and type(healthText) == "table" then
            if dragonFrame.PetFrameHealthBarTextLeft then
                dragonFrame.PetFrameHealthBarTextLeft:SetText(healthText.percentage);
                dragonFrame.PetFrameHealthBarTextLeft:Show()
            end
            if dragonFrame.PetFrameHealthBarTextRight then
                dragonFrame.PetFrameHealthBarTextRight:SetText(healthText.current);
                dragonFrame.PetFrameHealthBarTextRight:Show()
            end
            if dragonFrame.PetFrameHealthBarText then
                dragonFrame.PetFrameHealthBarText:Hide()
            end
        else
            local displayText = type(healthText) == "table" and healthText.combined or healthText
            if dragonFrame.PetFrameHealthBarText then
                dragonFrame.PetFrameHealthBarText:SetText(displayText);
                dragonFrame.PetFrameHealthBarText:Show()
            end
            if dragonFrame.PetFrameHealthBarTextLeft then
                dragonFrame.PetFrameHealthBarTextLeft:Hide()
            end
            if dragonFrame.PetFrameHealthBarTextRight then
                dragonFrame.PetFrameHealthBarTextRight:Hide()
            end
        end
    else
        if dragonFrame.PetFrameHealthBarText then
            dragonFrame.PetFrameHealthBarText:Hide()
        end
        if dragonFrame.PetFrameHealthBarTextLeft then
            dragonFrame.PetFrameHealthBarTextLeft:Hide()
        end
        if dragonFrame.PetFrameHealthBarTextRight then
            dragonFrame.PetFrameHealthBarTextRight:Hide()
        end
    end

    -- Power Logic
    if shouldShowMana and UnitPowerMax('pet') > 0 then
        local power, maxPower = UnitPower('pet'), UnitPowerMax('pet')
        local powerText = FormatStatusText(power, maxPower, textFormat, useBreakup, "pet")

        if textFormat == "both" and type(powerText) == "table" then
            if dragonFrame.PetFrameManaBarTextLeft then
                dragonFrame.PetFrameManaBarTextLeft:SetText(powerText.percentage);
                dragonFrame.PetFrameManaBarTextLeft:Show()
            end
            if dragonFrame.PetFrameManaBarTextRight then
                dragonFrame.PetFrameManaBarTextRight:SetText(powerText.current);
                dragonFrame.PetFrameManaBarTextRight:Show()
            end
            if dragonFrame.PetFrameManaBarText then
                dragonFrame.PetFrameManaBarText:Hide()
            end
        else
            local displayText = type(powerText) == "table" and powerText.combined or powerText
            if dragonFrame.PetFrameManaBarText then
                dragonFrame.PetFrameManaBarText:SetText(displayText);
                dragonFrame.PetFrameManaBarText:Show()
            end
            if dragonFrame.PetFrameManaBarTextLeft then
                dragonFrame.PetFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.PetFrameManaBarTextRight then
                dragonFrame.PetFrameManaBarTextRight:Hide()
            end
        end
    else
        if dragonFrame.PetFrameManaBarText then
            dragonFrame.PetFrameManaBarText:Hide()
        end
        if dragonFrame.PetFrameManaBarTextLeft then
            dragonFrame.PetFrameManaBarTextLeft:Hide()
        end
        if dragonFrame.PetFrameManaBarTextRight then
            dragonFrame.PetFrameManaBarTextRight:Hide()
        end
    end
end

-- FIXED: Add refresh function for pet frame
function addon:RefreshPetFrame()
    if UnitExists("pet") then
        unitframe.ChangePetFrame()
        unitframe.UpdatePetFrameText()
    end
end

function unitframe.MovePlayerTargetPreset(name)

    if name == 'DEFAULT' then
        local orig = addon.defaults and addon.defaults.profile and addon.defaults.profile.unitframe or {}

        db.playerOverride = false
        db.playerAnchor = orig.playerAnchor
        db.playerAnchorParent = orig.playerAnchorParent
        db.playerX = orig.playerX
        db.playerY = orig.playerY

        db.targetOverride = false
        db.targetAnchor = orig.targetAnchor
        db.targetAnchorParent = orig.targetAnchorParent
        db.targetX = orig.targetX
        db.targetY = orig.targetY

        addon:RefreshUnitFrames()
    elseif name == 'CENTER' then
        local deltaX = 50
        local deltaY = 180

        db.playerOverride = true
        db.playerAnchor = 'CENTER'
        db.playerAnchorParent = 'CENTER'
        -- player and target frame center is not perfect/identical
        db.playerX = -107.5 - deltaX
        db.playerY = -deltaY

        db.targetOverride = true
        db.targetAnchor = 'CENTER'
        db.targetAnchorParent = 'CENTER'
        -- see above
        db.targetX = 112 + deltaX
        db.targetY = -deltaY

        addon:RefreshUnitFrames()
    end
end

-- =====================================================================
-- START: HEALTH LOSS VISUALIZATION MODULE
-- =====================================================================

-- Table to store the last known health values for units
unitframe.lastHealthValues = {}

--[[
* Creates the "loss bar" used to visualize recent damage.
* This version uses a manual script-driven animation for maximum compatibility.
*
* @param parentFrame Frame - The main unit frame (e.g., PlayerFrame).
* @param mainHealthBar StatusBar - The primary health bar to attach to.
--]]
local function CreateHealthLossBar(parentFrame, mainHealthBar)
    -- Do nothing if the bar already exists
    if parentFrame.HealthLossBar then return end

    local lossBar = CreateFrame("StatusBar", nil, parentFrame)
    lossBar:SetAllPoints(mainHealthBar)
    
    -- Set the draw layer to be just behind the main health bar
    lossBar:SetFrameLevel(mainHealthBar:GetFrameLevel() - 1)
    
    -- Set texture and color (red)
    lossBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    lossBar:SetStatusBarColor(1, 0, 0, 1)
    
    -- Create the fade-out animation MANUALLY
    lossBar.fadeOutAnimation = lossBar:CreateAnimationGroup()
    lossBar.fadeOutAnimation:SetScript("OnFinished", function()
        lossBar:SetAlpha(0)
        lossBar:Hide()
    end)

    -- This is a script-driven animation, which is more robust
    local manualFade = lossBar.fadeOutAnimation:CreateAnimation("Script")
    manualFade:SetDuration(0.7) -- How long the animation should take

    -- Script to run when the animation STARTS
    manualFade:SetScript("OnPlay", function()
        lossBar:SetAlpha(0.9)
    end)

    -- Script to run on EVERY FRAME of the animation
    manualFade:SetScript("OnUpdate", function(self, elapsed)
        -- GetProgress() returns a number from 0.0 (start) to 1.0 (end)
        local progress = self:GetProgress() 
        -- Calculate the new transparency based on progress
        local newAlpha = 0.9 * (1 - progress) 
        lossBar:SetAlpha(newAlpha)
    end)
    
    lossBar:Hide()
    parentFrame.HealthLossBar = lossBar
end

--[[
* This is the new, faster function that triggers on health bar value changes.
* It's called by our hook on :SetValue().
*
* @param healthBar StatusBar - The health bar object that changed.
* @param value number - The new health value.
--]]
function unitframe.OnHealthBarValueChanged(healthBar, value)
    local parentFrame = healthBar:GetParent()
    if not parentFrame or not parentFrame.HealthLossBar or not parentFrame.unit then return end

    local lossBar = parentFrame.HealthLossBar
    local unit = parentFrame.unit
    
    local currentHealth = value
    local maxHealth = UnitHealthMax(unit)
    
    if not maxHealth or maxHealth == 0 then
        unitframe.lastHealthValues[unit] = currentHealth
        return
    end

    local previousHealth = unitframe.lastHealthValues[unit] or currentHealth
    
    if currentHealth < previousHealth then
        lossBar.fadeOutAnimation:Stop()
        lossBar:SetMinMaxValues(0, maxHealth)
        lossBar:SetValue(previousHealth)
        lossBar:Show()
        lossBar.fadeOutAnimation:Play()
    end
    
    unitframe.lastHealthValues[unit] = currentHealth
end
-- =====================================================================
-- END: HEALTH LOSS VISUALIZATION MODULE
-- =====================================================================

--[[
* Applies secure hooks to the main unit frame health bars.
* This connects our animation logic to the game's health updates.
--]]
function unitframe.HookHealthBarValues()
    if PlayerFrameHealthBar then
        hooksecurefunc(PlayerFrameHealthBar, "SetValue", unitframe.OnHealthBarValueChanged)
    end
    if TargetFrameHealthBar then
        hooksecurefunc(TargetFrameHealthBar, "SetValue", unitframe.OnHealthBarValueChanged)
    end
    if FocusFrameHealthBar then
        hooksecurefunc(FocusFrameHealthBar, "SetValue", unitframe.OnHealthBarValueChanged)
    end
    if PetFrameHealthBar then
        hooksecurefunc(PetFrameHealthBar, "SetValue", unitframe.OnHealthBarValueChanged)
    end

    for i=1, 4 do
        local healthbar = _G['PartyMemberFrame'..i..'HealthBar']
        if healthbar then
            -- Create the loss bar for party frames here as well
            CreateHealthLossBar(_G['PartyMemberFrame'..i], healthbar)
            hooksecurefunc(healthbar, "SetValue", unitframe.OnHealthBarValueChanged)
        end
    end
end

local frame = CreateFrame('FRAME', 'DragonUIUnitframeFrame', UIParent)

-- =============================================================================
-- OPTIMIZED TEXTURE COORDINATES SYSTEM (Embedded for WoW compatibility)
-- =============================================================================

local TextureCoordinates = {}

-- Cache for frequently accessed coordinates
local coordsCache = {}

-- Initialize texture coordinates data inline (WoW 3.3.5a compatibility)
local function initTextureCoords()
    if TextureCoordinates.data then
        return
    end -- Already initialized

    TextureCoordinates.data = {
        -- Target of Target coordinates from reference addon
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn'] = {120, 49, 0.0009765625, 0.1181640625, 0.8203125, 0.916015625,
                                                          false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health'] = {70, 10, 0.921875, 0.990234375, 0.14453125,
                                                                     0.1640625, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health-Status'] = {70, 10, 0.91796875, 0.986328125, 0.3515625,
                                                                            0.37109375, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana'] = {74, 7, 0.3876953125, 0.4599609375, 0.482421875,
                                                                   0.49609375, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana-Status'] = {74, 7, 0.4619140625, 0.5341796875,
                                                                          0.482421875, 0.49609375, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy'] = {74, 7, 0.91796875, 0.990234375, 0.37890625,
                                                                     0.392578125, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus'] = {74, 7, 0.3134765625, 0.3857421875, 0.482421875,
                                                                    0.49609375, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage'] = {74, 7, 0.5361328125, 0.6083984375, 0.482421875,
                                                                   0.49609375, false, false},
        ['UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower'] = {74, 7, 0.6103515625, 0.6826171875, 0.482421875,
                                                                         0.49609375, false, false},
        ['UI-HUD-UnitFrame-Player-Absorb-Edge'] = {8, 32, 0.984375, 0.9921875, 0.001953125, 0.064453125, false, false},
        ['UI-HUD-UnitFrame-Player-CombatIcon'] = {16, 16, 0.9775390625, 0.9931640625, 0.259765625, 0.291015625, false,
                                                  false},
        ['UI-HUD-UnitFrame-Player-CombatIcon-Glow'] = {32, 32, 0.1494140625, 0.1806640625, 0.8203125, 0.8828125, false,
                                                       false},
        ['UI-HUD-UnitFrame-Player-Group-FriendOnlineIcon'] = {16, 16, 0.162109375, 0.177734375, 0.716796875,
                                                              0.748046875, false, false},
        ['UI-HUD-UnitFrame-Player-Group-GuideIcon'] = {16, 16, 0.162109375, 0.177734375, 0.751953125, 0.783203125,
                                                       false, false},
        ['UI-HUD-UnitFrame-Player-Group-LeaderIcon'] = {16, 16, 0.1259765625, 0.1416015625, 0.919921875, 0.951171875,
                                                        false, false},
        ['UI-HUD-UnitFrame-Player-GroupIndicator'] = {71, 13, 0.927734375, 0.9970703125, 0.3125, 0.337890625, false,
                                                      false},
        ['UI-HUD-UnitFrame-Player-PlayTimeTired'] = {29, 29, 0.1904296875, 0.21875, 0.505859375, 0.5625, false, false},
        ['UI-HUD-UnitFrame-Player-PlayTimeUnhealthy'] = {29, 29, 0.1904296875, 0.21875, 0.56640625, 0.623046875, false,
                                                         false},
        ['UI-HUD-UnitFrame-Player-PortraitOff'] = {133, 51, 0.0009765625, 0.130859375, 0.716796875, 0.81640625, false,
                                                   false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-Energy'] = {124, 10, 0.6708984375, 0.7919921875, 0.35546875, 0.375,
                                                              false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-Focus'] = {124, 10, 0.6708984375, 0.7919921875, 0.37890625, 0.3984375,
                                                             false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-Health'] = {126, 23, 0.0009765625, 0.1240234375, 0.919921875,
                                                              0.96484375, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-Health-Status'] = {124, 20, 0.5478515625, 0.6689453125, 0.3125,
                                                                     0.3515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-Mana'] = {126, 12, 0.0009765625, 0.1240234375, 0.96875, 0.9921875,
                                                            false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-Rage'] = {124, 10, 0.8203125, 0.94140625, 0.435546875, 0.455078125,
                                                            false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOff-Bar-RunicPower'] = {124, 10, 0.1904296875, 0.3115234375, 0.458984375,
                                                                  0.478515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn'] = {198, 71, 0.7890625, 0.982421875, 0.001953125, 0.140625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy'] = {124, 10, 0.3134765625, 0.4345703125, 0.458984375,
                                                             0.478515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus'] = {124, 10, 0.4365234375, 0.5576171875, 0.458984375,
                                                            0.478515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health'] = {124, 20, 0.5478515625, 0.6689453125, 0.35546875,
                                                             0.39453125, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status'] = {124, 20, 0.6708984375, 0.7919921875, 0.3125,
                                                                    0.3515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana'] = {124, 10, 0.5595703125, 0.6806640625, 0.458984375,
                                                           0.478515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Status'] = {124, 10, 0.6826171875, 0.8037109375, 0.458984375,
                                                                  0.478515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage'] = {124, 10, 0.8056640625, 0.9267578125, 0.458984375,
                                                           0.478515625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower'] = {124, 10, 0.1904296875, 0.3115234375, 0.482421875,
                                                                 0.501953125, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-CornerEmbellishment'] = {23, 23, 0.953125, 0.9755859375, 0.259765625,
                                                                      0.3046875, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-InCombat'] = {192, 71, 0.1943359375, 0.3818359375, 0.169921875, 0.30859375,
                                                           false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Status'] = {196, 71, 0.0009765625, 0.1923828125, 0.169921875, 0.30859375,
                                                         false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Vehicle'] = {202, 84, 0.0009765625, 0.1982421875, 0.001953125, 0.166015625,
                                                          false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Vehicle-InCombat'] = {198, 84, 0.3984375, 0.591796875, 0.001953125,
                                                                   0.166015625, false, false},
        ['UI-HUD-UnitFrame-Player-PortraitOn-Vehicle-Status'] = {201, 84, 0.2001953125, 0.396484375, 0.001953125,
                                                                 0.166015625, false, false},
        ['UI-HUD-UnitFrame-Player-PVP-AllianceIcon'] = {28, 41, 0.1201171875, 0.1474609375, 0.8203125, 0.900390625,
                                                        false, false},
        ['UI-HUD-UnitFrame-Player-PVP-FFAIcon'] = {28, 44, 0.1328125, 0.16015625, 0.716796875, 0.802734375, false, false},
        ['UI-HUD-UnitFrame-Player-PVP-HordeIcon'] = {44, 44, 0.953125, 0.99609375, 0.169921875, 0.255859375, false,
                                                     false},
        ['UI-HUD-UnitFrame-Target-HighLevelTarget_Icon'] = {11, 14, 0.984375, 0.9951171875, 0.068359375, 0.095703125,
                                                            false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn'] = {192, 67, 0.57421875, 0.76171875, 0.169921875, 0.30078125,
                                                           false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Energy'] = {127, 10, 0.8544921875, 0.978515625, 0.412109375,
                                                                      0.431640625, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Focus'] = {127, 10, 0.1904296875, 0.314453125, 0.435546875,
                                                                     0.455078125, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health'] = {125, 12, 0.7939453125, 0.916015625, 0.3515625,
                                                                      0.375, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health-Status'] = {125, 12, 0.7939453125, 0.916015625,
                                                                             0.37890625, 0.40234375, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Mana'] = {127, 10, 0.31640625, 0.4404296875, 0.435546875,
                                                                    0.455078125, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Mana-Status'] = {127, 10, 0.4423828125, 0.56640625,
                                                                           0.435546875, 0.455078125, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Rage'] = {127, 10, 0.568359375, 0.6923828125, 0.435546875,
                                                                    0.455078125, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-RunicPower'] = {127, 10, 0.6943359375, 0.818359375,
                                                                          0.435546875, 0.455078125, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-InCombat'] = {188, 67, 0.0009765625, 0.1845703125, 0.447265625,
                                                                    0.578125, false, false},
        ['UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Status'] = {193, 69, 0.3837890625, 0.572265625, 0.169921875,
                                                                  0.3046875, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn'] = {192, 67, 0.763671875, 0.951171875, 0.169921875, 0.30078125, false,
                                                  false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Energy'] = {134, 10, 0.7890625, 0.919921875, 0.14453125, 0.1640625,
                                                             false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Focus'] = {134, 10, 0.1904296875, 0.3212890625, 0.412109375,
                                                            0.431640625, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health'] = {126, 20, 0.4228515625, 0.5458984375, 0.3125, 0.3515625,
                                                             false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status'] = {126, 20, 0.4228515625, 0.5458984375, 0.35546875,
                                                                    0.39453125, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana'] = {134, 10, 0.3232421875, 0.4541015625, 0.412109375,
                                                           0.431640625, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Status'] = {134, 10, 0.4560546875, 0.5869140625, 0.412109375,
                                                                  0.431640625, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage'] = {134, 10, 0.5888671875, 0.7197265625, 0.412109375,
                                                           0.431640625, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Bar-RunicPower'] = {134, 10, 0.7216796875, 0.8525390625, 0.412109375,
                                                                 0.431640625, false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-InCombat'] = {188, 67, 0.0009765625, 0.1845703125, 0.58203125, 0.712890625,
                                                           false, false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Type'] = {135, 18, 0.7939453125, 0.92578125, 0.3125, 0.34765625, false,
                                                       false},
        ['UI-HUD-UnitFrame-Target-PortraitOn-Vehicle'] = {198, 81, 0.59375, 0.787109375, 0.001953125, 0.16015625, false,
                                                          false},
        ['UI-HUD-UnitFrame-Target-Rare-PortraitOn'] = {192, 67, 0.0009765625, 0.1884765625, 0.3125, 0.443359375, false,
                                                       false}
    }
end

function unitframe.GetCoords(key)
    -- Initialize texture coordinates if not done
    initTextureCoords()

    -- Check cache first for performance
    if coordsCache[key] then
        local cached = coordsCache[key]
        return cached[1], cached[2], cached[3], cached[4]
    end

    local data = TextureCoordinates.data and TextureCoordinates.data[key]
    if not data then
        -- Log missing coordinates for debugging
        if key then

        end
        -- Return default coordinates to prevent crashes
        return 0, 1, 0, 1
    end

    -- Validate data format
    if type(data) ~= "table" or #data < 6 then

        return 0, 1, 0, 1
    end

    -- Extract texture coordinates (indices 3-6) and cache result
    local coords = {data[3], data[4], data[5], data[6]}

    -- Validate coordinates are numbers
    for i, coord in ipairs(coords) do
        if type(coord) ~= "number" then

            return 0, 1, 0, 1
        end
    end

    coordsCache[key] = coords
    return coords[1], coords[2], coords[3], coords[4]
end

-- Clear coordinate cache for memory management (can be called periodically)
function unitframe.ClearCoordsCache()
    coordsCache = {}
    collectgarbage("collect")
end

-- =============================================================================
-- OPTIMIZED SYSTEM INTEGRATION
-- Optimizations applied directly to the original system
-- =============================================================================

-- Performance optimization: Cache frequently used values
local performanceCache = {
    lastCacheCleanup = 0,
    cacheCleanupInterval = 300 -- 5 minutes
}

--- Periodic maintenance function for performance optimization
function unitframe.PerformanceMaintenance()
    local currentTime = GetTime()

    -- Clear coordinate cache periodically to free memory
    if currentTime - performanceCache.lastCacheCleanup > performanceCache.cacheCleanupInterval then
        unitframe.ClearCoordsCache()
        performanceCache.lastCacheCleanup = currentTime
    end
end

--- Initialize optimized texture coordinate system
function unitframe.InitializeOptimizedSystem()
    -- Initialize texture coordinates cache
    initTextureCoords()

    -- Test a few key coordinates to ensure they work
    local testKeys = {'UI-HUD-UnitFrame-Player-PortraitOn', 'UI-HUD-UnitFrame-Target-PortraitOn',
                      'UI-HUD-UnitFrame-Player-Group-LeaderIcon'}

    for _, key in ipairs(testKeys) do
        local left, top, right, bottom = unitframe.GetCoords(key)
        if left and top and right and bottom then

        else

        end
    end
end

function unitframe.CreatePlayerFrameTextures()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    -- Get reference to the DragonUI frame
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        dragonFrame = CreateFrame('FRAME', 'DragonUIUnitframeFrame', UIParent)
    end

    if not dragonFrame.PlayerFrameBackground then
        local background = PlayerFrame:CreateTexture('DragonUIPlayerFrameBackground')
        background:SetDrawLayer('BACKGROUND', 2)
        background:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Player-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5)

        background:SetTexture(base)
        background:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-PortraitOn'))
        background:SetSize(198, 71)
        background:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, 0)
        dragonFrame.PlayerFrameBackground = background
    end

    if not dragonFrame.PlayerFrameBorder then
        local border = PlayerFrameHealthBar:CreateTexture('DragonUIPlayerFrameBorder')
        border:SetDrawLayer('ARTWORK', 2)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Player-PortraitOn-BORDER')
        border:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5)
        border:SetDrawLayer('OVERLAY', 5)
        dragonFrame.PlayerFrameBorder = border
    end

    if not dragonFrame.PlayerFrameDeco then
        local textureSmall = PlayerFrame:CreateTexture('DragonUIPlayerFrameDeco')
        textureSmall:SetDrawLayer('OVERLAY', 5)
        textureSmall:SetTexture(base)
        textureSmall:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-PortraitOn-CornerEmbellishment'))
        local delta = 15
        textureSmall:SetPoint('CENTER', PlayerPortrait, 'CENTER', delta, -delta - 2)
        textureSmall:SetSize(23, 23)
        -- textureSmall:SetScale(1)
        dragonFrame.PlayerFrameDeco = textureSmall
    end

    -- Create dual text elements for "both" format
    -- Health bar dual texts
    if not dragonFrame.PlayerFrameHealthBarTextLeft then
        local healthTextLeft = PlayerFrameHealthBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Set manually larger font size for health dual text while keeping base template
        local font, originalSize, flags = healthTextLeft:GetFont()
        if font and originalSize then
            healthTextLeft:SetFont(font, originalSize + 1, flags) -- Make health dual text larger than mana
        end
        healthTextLeft:SetPoint("LEFT", PlayerFrameHealthBar, "LEFT", 6, 0)
        healthTextLeft:SetJustifyH("LEFT")
        dragonFrame.PlayerFrameHealthBarTextLeft = healthTextLeft
    end

    if not dragonFrame.PlayerFrameHealthBarTextRight then
        local healthTextRight = PlayerFrameHealthBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Set manually larger font size for health dual text while keeping base template
        local font, originalSize, flags = healthTextRight:GetFont()
        if font and originalSize then
            healthTextRight:SetFont(font, originalSize + 1, flags) -- Make health dual text larger than mana
        end
        healthTextRight:SetPoint("RIGHT", PlayerFrameHealthBar, "RIGHT", -6, 0)
        healthTextRight:SetJustifyH("RIGHT")
        dragonFrame.PlayerFrameHealthBarTextRight = healthTextRight
    end

    -- Mana bar dual texts
    if not dragonFrame.PlayerFrameManaBarTextLeft then
        local manaTextLeft = PlayerFrameManaBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextLeft:SetPoint("LEFT", PlayerFrameManaBar, "LEFT", 6, 0)
        manaTextLeft:SetJustifyH("LEFT")
        dragonFrame.PlayerFrameManaBarTextLeft = manaTextLeft
    end

    if not dragonFrame.PlayerFrameManaBarTextRight then
        local manaTextRight = PlayerFrameManaBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextRight:SetPoint("RIGHT", PlayerFrameManaBar, "RIGHT", -6, 0)
        dragonFrame.PlayerFrameManaBarTextRight = manaTextRight
    end
end

function unitframe.ChangeStatusIcons()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    PlayerAttackIcon:SetTexture(base)
    PlayerAttackIcon:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-CombatIcon'))
    PlayerAttackIcon:ClearAllPoints()
    PlayerAttackIcon:SetPoint('BOTTOMRIGHT', PlayerPortrait, 'BOTTOMRIGHT', -3, 0)
    PlayerAttackIcon:SetSize(16, 16)

    PlayerAttackBackground:SetTexture(base)
    PlayerAttackBackground:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-CombatIcon-Glow'))
    PlayerAttackBackground:ClearAllPoints()
    PlayerAttackBackground:SetPoint('CENTER', PlayerAttackIcon, 'CENTER')
    PlayerAttackBackground:SetSize(32, 32)

    PlayerFrameGroupIndicator:ClearAllPoints()
    -- PlayerFrameGroupIndicator:SetPoint('BOTTOMRIGHT', PlayerFrameHealthBar, 'TOPRIGHT', 4, 13)
    PlayerFrameGroupIndicator:SetPoint('BOTTOM', PlayerName, 'TOP', 0, 0)

    PlayerLeaderIcon:SetTexture(base)
    PlayerLeaderIcon:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-Group-LeaderIcon'))
    -- PlayerLeaderIcon:ClearAllPoints()
    -- PlayerLeaderIcon:SetPoint('BOTTOM', PlayerName, 'TOP', 0, 0)
    PlayerLeaderIcon:ClearAllPoints()
    PlayerLeaderIcon:SetPoint('BOTTOMRIGHT', PlayerPortrait, 'TOPLEFT', 10, -10)

    TargetFrameTextureFrameLeaderIcon:SetTexture(base)
    TargetFrameTextureFrameLeaderIcon:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-Group-LeaderIcon'))
    TargetFrameTextureFrameLeaderIcon:ClearAllPoints()
    TargetFrameTextureFrameLeaderIcon:SetPoint('BOTTOMLEFT', TargetFramePortrait, 'TOPRIGHT', -10 - 3, -10)
end

function unitframe.HookDrag()
    local DragStopPlayerFrame = function(self)
        unitframe.SaveLocalSettings()

        for k, v in pairs(localSettings.player) do
            addon:SetConfigValue("unitframe", "player", k, v)
        end
        addon:SetConfigValue("unitframe", "player", "override", false)
    end
    PlayerFrame:HookScript('OnDragStop', DragStopPlayerFrame)
    -- hooksecurefunc('PlayerFrame_ResetUserPlacedPosition', DragStopPlayerFrame)

    local DragStopTargetFrame = function(self)
        unitframe.SaveLocalSettings()

        for k, v in pairs(localSettings.target) do
            addon:SetConfigValue("unitframe", "target", k, v)
        end
        addon:SetConfigValue("unitframe", "target", "override", false)
    end
    TargetFrame:HookScript('OnDragStop', DragStopTargetFrame)
    -- hooksecurefunc('TargetFrame_ResetUserPlacedPosition', DragStopTargetFrame)

    if true then
        local DragStopFocusFrame = function(self)
            unitframe.SaveLocalSettings()

            for k, v in pairs(localSettings.focus) do
                addon:SetConfigValue("unitframe", "focus", k, v)
            end
            addon:SetConfigValue("unitframe", "focus", "override", false)
        end
        FocusFrame:HookScript('OnDragStop', DragStopFocusFrame)
        -- hooksecurefunc('FocusFrame_ResetUserPlacedPosition', DragStopFocusFrame)
    end
end

function unitframe.HookVertexColor()
    -- Player frame health bar hook for persistent colors (ADDED TO FIX COLOR ISSUES)
    PlayerFrameHealthBar:HookScript('OnValueChanged', function(self)
        if addon:GetConfigValue("unitframe", "player", "classcolor") then
            PlayerFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status')
            local localizedClass, englishClass, classIndex = UnitClass('player')
            if RAID_CLASS_COLORS[englishClass] then
                PlayerFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r,
                    RAID_CLASS_COLORS[englishClass].g, RAID_CLASS_COLORS[englishClass].b, 1)
            end
        else
            PlayerFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health')
            PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
        end
    end)

    -- FIXED: Player frame mana bar hook for persistent colors (fixes level up color reset)
    PlayerFrameManaBar:HookScript('OnValueChanged', function(self)
        local powerType, powerTypeString = UnitPowerType('player')

        if powerTypeString == 'MANA' then
            PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana')
        elseif powerTypeString == 'RAGE' then
            PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage')
        elseif powerTypeString == 'FOCUS' then
            PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus')
        elseif powerTypeString == 'ENERGY' then
            PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy')
        elseif powerTypeString == 'RUNIC_POWER' then
            PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower')
        end

        -- Force white color to work with DragonUI textures
        PlayerFrameManaBar:SetStatusBarColor(1, 1, 1, 1)
    end)

    -- Target frame health bar hook for persistent colors
    TargetFrameHealthBar:HookScript('OnValueChanged', function(self)
        if addon:GetConfigValue("unitframe", "target", "classcolor") and UnitIsPlayer('target') then
            TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status')
            local localizedClass, englishClass, classIndex = UnitClass('target')
            TargetFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r, RAID_CLASS_COLORS[englishClass].g,
                RAID_CLASS_COLORS[englishClass].b, 1)
        else
            TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
            TargetFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
        end
    end)

    -- Additional hooks for target health bar events to ensure colors persist
    local updateTargetFrameHealthBar = function()
        if addon:GetConfigValue("unitframe", "target", "classcolor") and UnitIsPlayer('target') then
            TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status')
            local localizedClass, englishClass, classIndex = UnitClass('target')
            if RAID_CLASS_COLORS[englishClass] then
                TargetFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r,
                    RAID_CLASS_COLORS[englishClass].g, RAID_CLASS_COLORS[englishClass].b, 1)
            end
        else
            TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
            TargetFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
        end
    end

    -- Hook target events for consistent color updates
    TargetFrame:HookScript('OnEvent', function(self, event, arg1)
        if event == 'PLAYER_TARGET_CHANGED' then
            updateTargetFrameHealthBar()
        end
    end)

    if true then
        -- Additional hooks for focus health bar events
        local updateFocusFrameHealthBar = function()
            if addon:GetConfigValue("unitframe", "focus", "classcolor") and UnitIsPlayer('focus') then
                FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status')
                local localizedClass, englishClass, classIndex = UnitClass('focus')
                if RAID_CLASS_COLORS[englishClass] then
                    FocusFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r,
                        RAID_CLASS_COLORS[englishClass].g, RAID_CLASS_COLORS[englishClass].b, 1)
                end
            else
                FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
                FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
            end
            -- BORDER con sublevel bajo: por encima del fondo, por debajo de todo lo demás
            FocusFrameHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 1)
        end

        -- Hook focus events for consistent color updates  
        FocusFrame:HookScript('OnEvent', function(self, event, arg1)
            if event == 'PARTY_MEMBERS_CHANGED' or event == 'PARTY_MEMBER_ENABLE' or event == 'PARTY_MEMBER_DISABLE' then
                -- SIMPLE: Solo aplicar colores sin logging ni delays complejos
                if UnitExists('focus') then
                    -- Obtener configuración actual
                    local shouldUseClassColor = addon:GetConfigValue("unitframe", "focus", "classcolor") and
                                                    UnitIsPlayer('focus')

                    if shouldUseClassColor then
                        local localizedClass, englishClass, classIndex = UnitClass('focus')
                        if englishClass and RAID_CLASS_COLORS[englishClass] then
                            local color = RAID_CLASS_COLORS[englishClass]
                            FocusFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
                        else
                            FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
                        end
                    else
                        FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
                    end

                    -- Asegurar color blanco en mana (sin verificaciones complejas)
                    if FocusFrameManaBar then
                        FocusFrameManaBar:SetStatusBarColor(1, 1, 1, 1)
                    end
                end
            end
        end)
        FocusFrameHealthBar:HookScript('OnValueChanged', function(self)
            if addon:GetConfigValue("unitframe", "focus", "classcolor") and UnitIsPlayer('focus') then
                FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status')
                local localizedClass, englishClass, classIndex = UnitClass('focus')
                FocusFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r,
                    RAID_CLASS_COLORS[englishClass].g, RAID_CLASS_COLORS[englishClass].b, 1)
            else
                FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
                FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
            end
            -- BORDER con sublevel bajo: por encima del fondo, por debajo de todo lo demás
            FocusFrameHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 1)
        end)
    end
end

-- FIXED: Utility function to force correct player frame colors (fixes level up issues)
function unitframe.ForcePlayerFrameColors()
    -- Force health bar colors
    if addon:GetConfigValue("unitframe", "player", "classcolor") then
        PlayerFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status')
        local localizedClass, englishClass, classIndex = UnitClass('player')
        if RAID_CLASS_COLORS[englishClass] then
            PlayerFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r, RAID_CLASS_COLORS[englishClass].g,
                RAID_CLASS_COLORS[englishClass].b, 1)
        end
    else
        PlayerFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health')
        PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    end

    -- Force mana bar colors
    local powerType, powerTypeString = UnitPowerType('player')

    if powerTypeString == 'MANA' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana')
    elseif powerTypeString == 'RAGE' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage')
    elseif powerTypeString == 'FOCUS' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus')
    elseif powerTypeString == 'ENERGY' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy')
    elseif powerTypeString == 'RUNIC_POWER' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower')
    end

    -- Force white color to work with DragonUI textures
    PlayerFrameManaBar:SetStatusBarColor(1, 1, 1, 1)
end

function unitframe.ChangePlayerframe()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    -- Ensure DragonUI player frame textures are created first
    unitframe.CreatePlayerFrameTextures()

    -- Hide Blizzard's default player frame elements
    PlayerFrameTexture:Hide()
    PlayerFrameBackground:Hide()
    PlayerFrameVehicleTexture:Hide()

    PlayerPortrait:ClearAllPoints()
    PlayerPortrait:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 42, -15)
    PlayerPortrait:SetDrawLayer('ARTWORK', 5)
    PlayerPortrait:SetSize(56, 56)

    -- @TODO: change text spacing
    PlayerName:ClearAllPoints()
    PlayerName:SetPoint('BOTTOMLEFT', PlayerFrameHealthBar, 'TOPLEFT', 0, 1)

    PlayerLevelText:ClearAllPoints()
    PlayerLevelText:SetPoint('BOTTOMRIGHT', PlayerFrameHealthBar, 'TOPRIGHT', -5, 1)

    -- Health 119,12
    PlayerFrameHealthBar:SetSize(125, 20)
    PlayerFrameHealthBar:ClearAllPoints()
    PlayerFrameHealthBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, 0)

    if addon:GetConfigValue("unitframe", "player", "classcolor") then
        PlayerFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status')

        local localizedClass, englishClass, classIndex = UnitClass('player')
        PlayerFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r, RAID_CLASS_COLORS[englishClass].g,
            RAID_CLASS_COLORS[englishClass].b, 1)
    else
        PlayerFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health')
        PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    end

    -- Fix text overlap when Character info panel is open
    if PlayerFrameHealthBarText and not PlayerFrameHealthBarText.DragonUINoShow then
        -- Permanently disable Blizzard's health text by overriding its Show method.
        PlayerFrameHealthBarText.Show = function()
        end
        PlayerFrameHealthBarText:Hide() -- Hide it one last time just in case.
        PlayerFrameHealthBarText.DragonUINoShow = true -- Flag it as handled.
    end

    if PlayerFrameManaBarText and not PlayerFrameManaBarText.DragonUINoShow then
        -- Permanently disable Blizzard's mana text by overriding its Show method.
        PlayerFrameManaBarText.Show = function()
        end
        PlayerFrameManaBarText:Hide() -- Hide it one last time.
        PlayerFrameManaBarText.DragonUINoShow = true -- Flag it as handled.
    end
    -- End of fix

    -- Hide original Blizzard text elements - we use custom ones
    PlayerFrameHealthBarText:Hide()
    PlayerFrameHealthBarText:SetPoint('CENTER', PlayerFrameHealthBar, 'CENTER', 0, 0)

    local dx = 5
    -- PlayerFrameHealthBarTextLeft:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', dx, 0)
    -- PlayerFrameHealthBarTextRight:SetPoint('RIGHT', PlayerFrameHealthBar, 'RIGHT', -dx, 0)

    -- Mana 119,12
    PlayerFrameManaBar:ClearAllPoints()
    PlayerFrameManaBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -17 + 0.5)
    PlayerFrameManaBar:SetSize(125, 8)

    -- Hide original Blizzard mana text - we use custom ones
    PlayerFrameManaBarText:Hide()
    PlayerFrameManaBarText:SetPoint('CENTER', PlayerFrameManaBar, 'CENTER', 0, 0)
    -- PlayerFrameManaBarTextLeft:SetPoint('LEFT', PlayerFrameManaBar, 'LEFT', dx, 0)
    -- PlayerFrameManaBarTextRight:SetPoint('RIGHT', PlayerFrameManaBar, 'RIGHT', -dx, 0)

    local powerType, powerTypeString = UnitPowerType('player')

    if powerTypeString == 'MANA' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana')
    elseif powerTypeString == 'RAGE' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage')
    elseif powerTypeString == 'FOCUS' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus')
    elseif powerTypeString == 'ENERGY' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy')
    elseif powerTypeString == 'RUNIC_POWER' then
        PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower')
    end

    PlayerFrameManaBar:SetStatusBarColor(1, 1, 1, 1)

    -- UI-HUD-UnitFrame-Player-PortraitOn-Status
    PlayerStatusTexture:SetTexture(base)
    PlayerStatusTexture:SetSize(192, 71)
    PlayerStatusTexture:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Player-PortraitOn-InCombat'))

    PlayerStatusTexture:ClearAllPoints()

    -- Get reference to the DragonUI frame for PlayerFrameBorder
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and dragonFrame.PlayerFrameBorder then
        PlayerStatusTexture:SetPoint('TOPLEFT', dragonFrame.PlayerFrameBorder, 'TOPLEFT', 1, 1)
    end

    -- Create custom health text for player frame (similar to target/focus)
    if not dragonFrame.PlayerFrameHealthBarText then
        local PlayerFrameHealthBarDummy = CreateFrame('FRAME', 'PlayerFrameHealthBarDummy')
        PlayerFrameHealthBarDummy:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', 0, 0)
        PlayerFrameHealthBarDummy:SetPoint('TOP', PlayerFrameHealthBar, 'TOP', 0, 0)
        PlayerFrameHealthBarDummy:SetPoint('RIGHT', PlayerFrameHealthBar, 'RIGHT', 0, 0)
        PlayerFrameHealthBarDummy:SetPoint('BOTTOM', PlayerFrameHealthBar, 'BOTTOM', 0, 0)
        PlayerFrameHealthBarDummy:SetParent(PlayerFrame)
        PlayerFrameHealthBarDummy:SetFrameStrata('LOW')
        PlayerFrameHealthBarDummy:SetFrameLevel(3)
        PlayerFrameHealthBarDummy:EnableMouse(true)

        dragonFrame.PlayerFrameHealthBarDummy = PlayerFrameHealthBarDummy

        local t = PlayerFrameHealthBarDummy:CreateFontString('PlayerFrameCustomHealthBarText', 'OVERLAY',
            'TextStatusBarText')
        -- Set manually larger font size for health text while keeping base template
        local font, originalSize, flags = t:GetFont()
        if font and originalSize then
            t:SetFont(font, originalSize + 1, flags) -- Make health text 2 points larger than mana
        end
        t:SetPoint('CENTER', PlayerFrameHealthBarDummy, 0, 0)
        t:SetText('HP')
        t:Hide()
        dragonFrame.PlayerFrameHealthBarText = t

        local function UpdatePlayerCustomHealthText()
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if not dragonFrame then
                return
            end

            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.player or {}
                local textFormat = config.textFormat or "numeric"

                if UnitExists('player') then
                    local current = UnitHealth('player') or 0
                    local maximum = UnitHealthMax('player') or 1
                    local formattedText = FormatStatusText(current, maximum, textFormat)

                    if textFormat == "both" and type(formattedText) == "table" then
                        -- Update dual text elements
                        if dragonFrame.PlayerFrameHealthBarTextLeft then
                            dragonFrame.PlayerFrameHealthBarTextLeft:SetText(formattedText.percentage)
                        end
                        if dragonFrame.PlayerFrameHealthBarTextRight then
                            dragonFrame.PlayerFrameHealthBarTextRight:SetText(formattedText.current)
                        end
                    else
                        -- Update single text element
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        if dragonFrame.PlayerFrameHealthBarText then
                            dragonFrame.PlayerFrameHealthBarText:SetText(displayText)
                        end
                    end
                end
            end
        end

        PlayerFrameHealthBarDummy:HookScript('OnEnter', function(self)
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.player or {}
                local showHealthAlways = config.showHealthTextAlways or false
                local textFormat = config.textFormat or "numeric"

                if not showHealthAlways then
                    if textFormat == "both" then
                        -- Show dual text elements for "both" format
                        if dragonFrame.PlayerFrameHealthBarTextLeft and dragonFrame.PlayerFrameHealthBarTextRight then
                            UpdatePlayerCustomHealthText()
                            dragonFrame.PlayerFrameHealthBarTextLeft:Show()
                            dragonFrame.PlayerFrameHealthBarTextRight:Show()
                        end
                    else
                        -- Show single text element for other formats
                        UpdatePlayerCustomHealthText()
                        dragonFrame.PlayerFrameHealthBarText:Show()
                    end
                end
            end
        end)

        PlayerFrameHealthBarDummy:HookScript('OnLeave', function(self)
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.player or {}
                local showHealthAlways = config.showHealthTextAlways or false
                local textFormat = config.textFormat or "numeric"

                if not showHealthAlways then
                    if textFormat == "both" then
                        -- Hide dual text elements for "both" format
                        if dragonFrame.PlayerFrameHealthBarTextLeft and dragonFrame.PlayerFrameHealthBarTextRight then
                            dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
                            dragonFrame.PlayerFrameHealthBarTextRight:Hide()
                        end
                    else
                        -- Hide single text element for other formats
                        dragonFrame.PlayerFrameHealthBarText:Hide()
                    end
                end
            end
        end)
    end

    -- Create custom mana text for player frame (similar to target/focus)
    if not dragonFrame.PlayerFrameManaBarText then
        local PlayerFrameManaBarDummy = CreateFrame('FRAME', 'PlayerFrameManaBarDummy')
        PlayerFrameManaBarDummy:SetPoint('LEFT', PlayerFrameManaBar, 'LEFT', 0, 0)
        PlayerFrameManaBarDummy:SetPoint('TOP', PlayerFrameManaBar, 'TOP', 0, 0)
        PlayerFrameManaBarDummy:SetPoint('RIGHT', PlayerFrameManaBar, 'RIGHT', 0, 0)
        PlayerFrameManaBarDummy:SetPoint('BOTTOM', PlayerFrameManaBar, 'BOTTOM', 0, 0)
        PlayerFrameManaBarDummy:SetParent(PlayerFrame)
        PlayerFrameManaBarDummy:SetFrameStrata('LOW')
        PlayerFrameManaBarDummy:SetFrameLevel(3)
        PlayerFrameManaBarDummy:EnableMouse(true)

        dragonFrame.PlayerFrameManaBarDummy = PlayerFrameManaBarDummy

        local t = PlayerFrameManaBarDummy:CreateFontString('PlayerFrameCustomManaBarText', 'OVERLAY',
            'TextStatusBarText')
        t:SetPoint('CENTER', PlayerFrameManaBarDummy, 0, 0)
        t:SetText('MANA')
        t:Hide()
        dragonFrame.PlayerFrameManaBarText = t

        local function UpdatePlayerCustomManaText()
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if not dragonFrame then
                return
            end

            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.player or {}
                local textFormat = config.textFormat or "numeric"

                if UnitExists('player') then
                    local currentMana = UnitPower('player') or 0
                    local maximumMana = UnitPowerMax('player') or 1
                    local formattedText = FormatStatusText(currentMana, maximumMana, textFormat)

                    if textFormat == "both" and type(formattedText) == "table" then
                        -- Update dual text elements
                        if dragonFrame.PlayerFrameManaBarTextLeft then
                            dragonFrame.PlayerFrameManaBarTextLeft:SetText(formattedText.percentage)
                        end
                        if dragonFrame.PlayerFrameManaBarTextRight then
                            dragonFrame.PlayerFrameManaBarTextRight:SetText(formattedText.current)
                        end
                    else
                        -- Update single text element
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        if dragonFrame.PlayerFrameManaBarText then
                            dragonFrame.PlayerFrameManaBarText:SetText(displayText)
                        end
                    end
                end
            end
        end

        PlayerFrameManaBarDummy:HookScript('OnEnter', function(self)
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.player or {}
                local showManaAlways = config.showManaTextAlways or false
                local textFormat = config.textFormat or "numeric"

                if not showManaAlways then
                    if textFormat == "both" then
                        -- Show dual text elements for "both" format
                        if dragonFrame.PlayerFrameManaBarTextLeft and dragonFrame.PlayerFrameManaBarTextRight then
                            UpdatePlayerCustomManaText()
                            dragonFrame.PlayerFrameManaBarTextLeft:Show()
                            dragonFrame.PlayerFrameManaBarTextRight:Show()
                        end
                    else
                        -- Show single text element for other formats
                        UpdatePlayerCustomManaText()
                        dragonFrame.PlayerFrameManaBarText:Show()
                    end
                end
            end
        end)

        PlayerFrameManaBarDummy:HookScript('OnLeave', function(self)
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.player or {}
                local showManaAlways = config.showManaTextAlways or false
                local textFormat = config.textFormat or "numeric"

                if not showManaAlways then
                    if textFormat == "both" then
                        -- Hide dual text elements for "both" format
                        if dragonFrame.PlayerFrameManaBarTextLeft and dragonFrame.PlayerFrameManaBarTextRight then
                            dragonFrame.PlayerFrameManaBarTextLeft:Hide()
                            dragonFrame.PlayerFrameManaBarTextRight:Hide()
                        end
                    else
                        -- Hide single text element for other formats
                        dragonFrame.PlayerFrameManaBarText:Hide()
                    end
                end
            end
        end)
    end

    -- Update visibility based on individual showTextAlways settings for Player
    if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
        local config = addon.db.profile.unitframe.player or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        -- Handle health text visibility
        if UnitExists('player') then
            local current = UnitHealth('player') or 0
            local maximum = UnitHealthMax('player') or 1
            local textFormat = config.textFormat or "numeric"
            local formattedText = FormatStatusText(current, maximum, textFormat)

            if showHealthAlways then
                if textFormat == "both" and type(formattedText) == "table" then
                    -- Show dual text elements for "both" format
                    if dragonFrame.PlayerFrameHealthBarTextLeft and dragonFrame.PlayerFrameHealthBarTextRight then
                        dragonFrame.PlayerFrameHealthBarTextLeft:SetText(formattedText.percentage)
                        dragonFrame.PlayerFrameHealthBarTextRight:SetText(formattedText.current)
                        dragonFrame.PlayerFrameHealthBarTextLeft:Show()
                        dragonFrame.PlayerFrameHealthBarTextRight:Show()
                    end
                    -- Hide single text element
                    if dragonFrame.PlayerFrameHealthBarText then
                        dragonFrame.PlayerFrameHealthBarText:Hide()
                    end
                else
                    -- Show single text element for other formats
                    if dragonFrame.PlayerFrameHealthBarText then
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        dragonFrame.PlayerFrameHealthBarText:SetText(displayText)
                        dragonFrame.PlayerFrameHealthBarText:Show()
                    end
                    -- Hide dual text elements
                    if dragonFrame.PlayerFrameHealthBarTextLeft then
                        dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
                    end
                    if dragonFrame.PlayerFrameHealthBarTextRight then
                        dragonFrame.PlayerFrameHealthBarTextRight:Hide()
                    end
                end
            else
                -- Hide all text elements when not showing always
                if dragonFrame.PlayerFrameHealthBarText then
                    dragonFrame.PlayerFrameHealthBarText:Hide()
                end
                if dragonFrame.PlayerFrameHealthBarTextLeft then
                    dragonFrame.PlayerFrameHealthBarTextLeft:Hide()
                end
                if dragonFrame.PlayerFrameHealthBarTextRight then
                    dragonFrame.PlayerFrameHealthBarTextRight:Hide()
                end
            end
        end

        -- Handle mana text visibility
        if UnitExists('player') then
            local currentMana = UnitPower('player') or 0
            local maximumMana = UnitPowerMax('player') or 1
            local textFormat = config.textFormat or "numeric"
            local formattedText = FormatStatusText(currentMana, maximumMana, textFormat)

            if showManaAlways then
                if textFormat == "both" and type(formattedText) == "table" then
                    -- Show dual text elements for "both" format
                    if dragonFrame.PlayerFrameManaBarTextLeft and dragonFrame.PlayerFrameManaBarTextRight then
                        dragonFrame.PlayerFrameManaBarTextLeft:SetText(formattedText.percentage)
                        dragonFrame.PlayerFrameManaBarTextRight:SetText(formattedText.current)
                        dragonFrame.PlayerFrameManaBarTextLeft:Show()
                        dragonFrame.PlayerFrameManaBarTextRight:Show()
                    end
                    -- Hide single text element
                    if dragonFrame.PlayerFrameManaBarText then
                        dragonFrame.PlayerFrameManaBarText:Hide()
                    end
                else
                    -- Show single text element for other formats
                    if dragonFrame.PlayerFrameManaBarText then
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        dragonFrame.PlayerFrameManaBarText:SetText(displayText)
                        dragonFrame.PlayerFrameManaBarText:Show()
                    end
                    -- Hide dual text elements
                    if dragonFrame.PlayerFrameManaBarTextLeft then
                        dragonFrame.PlayerFrameManaBarTextLeft:Hide()
                    end
                    if dragonFrame.PlayerFrameManaBarTextRight then
                        dragonFrame.PlayerFrameManaBarTextRight:Hide()
                    end
                end
            else
                -- Hide all text elements when not showing always
                if dragonFrame.PlayerFrameManaBarText then
                    dragonFrame.PlayerFrameManaBarText:Hide()
                end
                if dragonFrame.PlayerFrameManaBarTextLeft then
                    dragonFrame.PlayerFrameManaBarTextLeft:Hide()
                end
                if dragonFrame.PlayerFrameManaBarTextRight then
                    dragonFrame.PlayerFrameManaBarTextRight:Hide()
                end
            end
        end
    end

    -- Update custom text displays with proper settings
    unitframe.SafeUpdatePlayerFrameText()
	
	-- Hook for Health Loss effect
	PlayerFrame.unit = "player"
	CreateHealthLossBar(PlayerFrame, PlayerFrameHealthBar)
end
-- ChangePlayerframe()
-- frame:RegisterEvent('PLAYER_ENTERING_WORLD')

function unitframe.HookPlayerStatus()

    local UpdateStatus = function()
        local frame = _G["DragonUIUnitframeFrame"]
        if not (frame and frame.PlayerFrameDeco) then
            return
        end

        -- TODO: fix statusglow
        PlayerStatusGlow:Hide()

        if UnitHasVehiclePlayerFrameUI and UnitHasVehiclePlayerFrameUI('player') then
            -- TODO: vehicle stuff
            -- frame.PlayerFrameDeco:Show()
        elseif IsResting() then
            frame.PlayerFrameDeco:Show()
            frame.PlayerFrameBorder:SetVertexColor(1.0, 1.0, 1.0, 1.0)

            if frame.RestIcon then
                frame.RestIcon:Show()
                frame.RestIconAnimation:Play()
            end

            -- FIXED: Show DragonUI custom resting glow texture
            PlayerStatusTexture:Show()
            PlayerStatusTexture:SetVertexColor(1.0, 0.88, 0.25, 1.0)
            PlayerStatusTexture:SetAlpha(1.0)
        elseif PlayerFrame.onHateList then
            -- FIXED: Show DragonUI custom hate list glow texture  
            PlayerStatusTexture:Show()
            PlayerStatusTexture:SetVertexColor(1.0, 0, 0, 1.0)
            frame.PlayerFrameDeco:Hide()

            if frame.RestIcon then
                frame.RestIcon:Hide()
                frame.RestIconAnimation:Stop()
            end

            frame.PlayerFrameBorder:SetVertexColor(1.0, 0, 0, 1.0)
            frame.PlayerFrameBackground:SetVertexColor(1.0, 0, 0, 1.0)
        elseif PlayerFrame.inCombat then
            frame.PlayerFrameDeco:Hide()

            if frame.RestIcon then
                frame.RestIcon:Hide()
                frame.RestIconAnimation:Stop()
            end

            frame.PlayerFrameBackground:SetVertexColor(1.0, 0, 0, 1.0)

            -- FIXED: Show DragonUI custom combat glow texture
            PlayerStatusTexture:Show()
            PlayerStatusTexture:SetVertexColor(1.0, 0, 0, 1.0)
            PlayerStatusTexture:SetAlpha(1.0)
        else
            frame.PlayerFrameDeco:Show()

            if frame.RestIcon then
                frame.RestIcon:Hide()
                frame.RestIconAnimation:Stop()
            end

            frame.PlayerFrameBorder:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            frame.PlayerFrameBackground:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            -- FIXED: Hide DragonUI combat glow when not in combat
            PlayerStatusTexture:Hide()
        end
    end

    hooksecurefunc('PlayerFrame_UpdateStatus', UpdateStatus)
end
-- No llamar UpdateStatus inmediatamente - dejar que los eventos lo manejen
-- UpdateStatus()

function unitframe.MovePlayerFrame(point, relativeTo, relativePoint, xOfs, yOfs)
    PlayerFrame:ClearAllPoints()
    -- Usamos _G[relativeTo] para asegurarnos de que funciona con "UIParent" u otros marcos
    PlayerFrame:SetPoint(point or "TOPLEFT", _G[relativeTo or "UIParent"] or UIParent, relativePoint or "TOPLEFT",
        xOfs or -24, yOfs or -4)
end

function unitframe.ChangeTargetFrame()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    -- Get reference to the DragonUI frame
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    TargetFrameTextureFrameTexture:Hide()
    TargetFrameBackground:Hide()

    if not dragonFrame.TargetFrameBackground then
        local background = TargetFrame:CreateTexture('DragonUITargetFrameBackground')
        background:SetDrawLayer('BACKGROUND', 2)
        background:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', TargetFrame, 'LEFT', 0, -32.5 + 10)
        dragonFrame.TargetFrameBackground = background
    end

    if not dragonFrame.TargetFrameBorder then
        local border = TargetFrame:CreateTexture('DragonUITargetFrameBorder')
        border:SetDrawLayer('ARTWORK', 2)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER')
        border:SetPoint('LEFT', TargetFrame, 'LEFT', 0, -32.5 + 10)
        border:SetDrawLayer('OVERLAY', 5)
        dragonFrame.TargetFrameBorder = border
    end

    TargetFramePortrait:SetDrawLayer('ARTWORK', 1)
    TargetFramePortrait:SetSize(56, 56)
    local CorrectionY = -3
    local CorrectionX = -5
    TargetFramePortrait:SetPoint('TOPRIGHT', TargetFrame, 'TOPRIGHT', -42 + CorrectionX, -12 + CorrectionY)

    -- TargetFrameBuff1:SetPoint('TOPLEFT', TargetFrame, 'BOTTOMLEFT', 5, 0)

    -- @TODO: change text spacing
    TargetFrameTextureFrameName:ClearAllPoints()
    TargetFrameTextureFrameName:SetPoint('BOTTOM', TargetFrameHealthBar, 'TOP', 10, 3 - 2)

    TargetFrameTextureFrameLevelText:ClearAllPoints()
    TargetFrameTextureFrameLevelText:SetPoint('BOTTOMRIGHT', TargetFrameHealthBar, 'TOPLEFT', 16, 3 - 2)

    -- Health 119,12
    TargetFrameHealthBar:ClearAllPoints()
    TargetFrameHealthBar:SetSize(125, 20)
    TargetFrameHealthBar:SetPoint('RIGHT', TargetFramePortrait, 'LEFT', -1, 0)
    TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
    TargetFrameHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 1) -- BORDER con sublevel bajo: por encima del fondo, por debajo de todo lo demás
    TargetFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)

    -- [[ INICIO DE LA LÓGICA DE RECORTE DINÁMICO PARA LA BARRA DE VIDA DEL TARGET ]]
    if not TargetFrameHealthBar.DragonUI_HealthBarHooked then
        TargetFrameHealthBar:HookScript("OnValueChanged", function(self, value)
            if not UnitExists("target") then
                return
            end

            local statusBarTexture = self:GetStatusBarTexture()
            statusBarTexture:SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')

            -- BORDER con sublevel bajo: por encima del fondo, por debajo de todo lo demás
            statusBarTexture:SetDrawLayer("BORDER", 1)

            -- La magia del recorte dinámico: ajustamos las coordenadas de la textura.
            local min, max = self:GetMinMaxValues()
            if max > 0 and value then
                local percentage = value / max
                -- SetTexCoord(izquierda, derecha, arriba, abajo)
                -- Recortamos la coordenada derecha para que coincida con el porcentaje.
                statusBarTexture:SetTexCoord(0, percentage, 0, 1)
            else
                -- Si no hay valor o el máximo es 0, mostramos la textura completa.
                statusBarTexture:SetTexCoord(0, 1, 0, 1)
            end

            -- Nos aseguramos de que no se aplique ningún tinte de color que arruine la textura.
            statusBarTexture:SetVertexColor(1, 1, 1, 1)
        end)
        -- Marcamos que el hook ya ha sido aplicado.
        TargetFrameHealthBar.DragonUI_HealthBarHooked = true
    end

    -- Forzamos una actualización inicial de la barra de vida para que nuestro nuevo hook se ejecute.
    if UnitExists("target") then
        local currentHealth = UnitHealth("target")
        local maxHealth = UnitHealthMax("target")
        TargetFrameHealthBar:SetMinMaxValues(0, maxHealth)
        TargetFrameHealthBar:SetValue(currentHealth)
    end
    -- [[ FIN DE LA LÓGICA DE RECORTE DINÁMICO PARA LA BARRA DE VIDA DEL TARGET ]]
    -- Mana 119,12
    TargetFrameManaBar:ClearAllPoints()
    TargetFrameManaBar:SetPoint('RIGHT', TargetFramePortrait, 'LEFT', -1 + 8 - 0.5, -18 + 1 + 0.5)
    TargetFrameManaBar:SetSize(132, 9)

    -- [[ INICIO DE LA CORRECCIÓN DEFINITIVA ]]
    -- Instead of a simple 'noop', we intercept the original function.
    -- Esto asegura que CUALQUIER llamada a SetStatusBarColor (incluso las de Blizzard)
    -- se redirija a SetVertexColor, forzando siempre el recorte.
    if not TargetFrameManaBar.originalSetStatusBarColor then
        TargetFrameManaBar.originalSetStatusBarColor = TargetFrameManaBar.SetStatusBarColor
        TargetFrameManaBar.SetStatusBarColor = function(self, r, g, b, a)
            -- Siempre usamos SetVertexColor para evitar la compresión.
            self:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        end
    end
    -- Aplicamos el color inicial una vez.
    TargetFrameManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    -- [[ FIN DE LA CORRECCIÓN DEFINITIVA ]]
    TargetFrameNameBackground:SetTexture(base)
    TargetFrameNameBackground:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Target-PortraitOn-Type'))
    TargetFrameNameBackground:SetSize(135, 18)
    TargetFrameNameBackground:ClearAllPoints()
    TargetFrameNameBackground:SetPoint('BOTTOMLEFT', TargetFrameHealthBar, 'TOPLEFT', -2, -4 - 1)

    if true then
        local dx = 5
        -- health vs mana bar
        local deltaSize = 132 - 125

        TargetFrameTextureFrameHealthBarText:SetPoint('CENTER', TargetFrameHealthBar, 'CENTER', 0, 0)
        -- TargetFrameTextureFrame.HealthBarTextLeft:SetPoint('LEFT', TargetFrameHealthBar, 'LEFT', dx, 0)
        -- TargetFrameTextureFrame.HealthBarTextRight:SetPoint('RIGHT', TargetFrameHealthBar, 'RIGHT', -dx, 0)

        TargetFrameTextureFrameManaBarText:SetPoint('CENTER', TargetFrameManaBar, 'CENTER', -deltaSize / 2, 0)
        -- TargetFrameTextureFrame.ManaBarTextLeft:SetPoint('LEFT', TargetFrameManaBar, 'LEFT', dx, 0)
        -- TargetFrameTextureFrame.ManaBarTextRight:SetPoint('RIGHT', TargetFrameManaBar, 'RIGHT', -deltaSize - dx, 0)
    end

    if true then
        TargetFrameFlash:SetTexture('')

        if not dragonFrame.TargetFrameFlash then
            local flash = TargetFrame:CreateTexture('DragonUITargetFrameFlash')
            flash:SetDrawLayer('BACKGROUND', 2)
            flash:SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-InCombat')
            flash:SetPoint('CENTER', TargetFrame, 'CENTER', 20 + CorrectionX, -20 + CorrectionY)
            flash:SetSize(256, 128)
            -- flash:SetScale(1)
            flash:SetVertexColor(1.0, 0.0, 0.0, 1.0)
            flash:SetBlendMode('ADD')
            dragonFrame.TargetFrameFlash = flash
        end

        hooksecurefunc(TargetFrameFlash, 'Show', function()

            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and dragonFrame.TargetFrameFlash then
                TargetFrameFlash:SetTexture('')
                dragonFrame.TargetFrameFlash:Show()
                if (UIFrameIsFlashing(dragonFrame.TargetFrameFlash)) then
                else

                    local dt = 0.5
                    UIFrameFlash(dragonFrame.TargetFrameFlash, dt, dt, -1)
                end
            end
        end)

        hooksecurefunc(TargetFrameFlash, 'Hide', function()

            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and dragonFrame.TargetFrameFlash then
                TargetFrameFlash:SetTexture('')
                if (UIFrameIsFlashing(dragonFrame.TargetFrameFlash)) then
                    UIFrameFlashStop(dragonFrame.TargetFrameFlash)
                end
                dragonFrame.TargetFrameFlash:Hide()
            end
        end)
    end

    if not dragonFrame.PortraitExtra then
        local extra = TargetFrame:CreateTexture('DragonUITargetFramePortraitExtra')
        extra:SetTexture('Interface\\Addons\\DragonUI\\Textures\\uiunitframeboss2x')
        extra:SetTexCoord(0.001953125, 0.314453125, 0.322265625, 0.630859375)
        extra:SetSize(80, 79)
        extra:SetDrawLayer('OVERLAY', 3)
        extra:SetPoint('CENTER', TargetFramePortrait, 'CENTER', 4, 1)

        extra.UpdateStyle = function()
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if not dragonFrame then
                return
            end

            local class = UnitClassification('target')
            --[[ "worldboss", "rareelite", "elite", "rare", "normal", "trivial" or "minus" ]]
            if class == 'worldboss' then
                dragonFrame.PortraitExtra:Show()
                dragonFrame.PortraitExtra:SetSize(99, 81)
                dragonFrame.PortraitExtra:SetTexCoord(0.001953125, 0.388671875, 0.001953125, 0.31835937)
                dragonFrame.PortraitExtra:SetPoint('CENTER', TargetFramePortrait, 'CENTER', 13, 1)
            elseif class == 'rareelite' or class == 'rare' then
                dragonFrame.PortraitExtra:Show()
                dragonFrame.PortraitExtra:SetSize(80, 79)
                dragonFrame.PortraitExtra:SetTexCoord(0.00390625, 0.31640625, 0.64453125, 0.953125)
                dragonFrame.PortraitExtra:SetPoint('CENTER', TargetFramePortrait, 'CENTER', 4, 1)
            elseif class == 'elite' then
                dragonFrame.PortraitExtra:Show()
                dragonFrame.PortraitExtra:SetTexCoord(0.001953125, 0.314453125, 0.322265625, 0.630859375)
                dragonFrame.PortraitExtra:SetSize(80, 79)
                dragonFrame.PortraitExtra:SetPoint('CENTER', TargetFramePortrait, 'CENTER', 4, 1)
            else
                local name, realm = UnitName('target')
                if unitframe.famous[name] then
                    dragonFrame.PortraitExtra:Show()
                    dragonFrame.PortraitExtra:SetSize(99, 81)
                    dragonFrame.PortraitExtra:SetTexCoord(0.001953125, 0.388671875, 0.001953125, 0.31835937)
                    dragonFrame.PortraitExtra:SetPoint('CENTER', TargetFramePortrait, 'CENTER', 13, 1)
                else
                    dragonFrame.PortraitExtra:Hide()
                end
            end
        end

        dragonFrame.PortraitExtra = extra
    end

    -- CUSTOM HealthText for Target (similar to Focus)
    if not dragonFrame.TargetFrameHealthBarText then
        local TargetFrameHealthBarDummy = CreateFrame('FRAME', 'TargetFrameHealthBarDummy')
        TargetFrameHealthBarDummy:SetPoint('LEFT', TargetFrameHealthBar, 'LEFT', 0, 0)
        TargetFrameHealthBarDummy:SetPoint('TOP', TargetFrameHealthBar, 'TOP', 0, 0)
        TargetFrameHealthBarDummy:SetPoint('RIGHT', TargetFrameHealthBar, 'RIGHT', 0, 0)
        TargetFrameHealthBarDummy:SetPoint('BOTTOM', TargetFrameHealthBar, 'BOTTOM', 0, 0)
        TargetFrameHealthBarDummy:SetParent(TargetFrame)
        TargetFrameHealthBarDummy:SetFrameStrata('LOW')
        TargetFrameHealthBarDummy:SetFrameLevel(3)
        TargetFrameHealthBarDummy:EnableMouse(true)

        dragonFrame.TargetFrameHealthBarDummy = TargetFrameHealthBarDummy

        local t = TargetFrameHealthBarDummy:CreateFontString('TargetFrameCustomHealthBarText', 'OVERLAY',
            'TextStatusBarText')
        -- Set manually larger font size for health text while keeping base template
        local font, originalSize, flags = t:GetFont()
        if font and originalSize then
            t:SetFont(font, originalSize + 1, flags) -- Make health text 2 points larger than mana
        end
        t:SetPoint('CENTER', TargetFrameHealthBarDummy, -2, 0)
        t:SetText('HP')
        t:Hide()
        dragonFrame.TargetFrameHealthBarText = t

        -- Create dual text elements for "both" format - Target Health
        local healthTextLeft = TargetFrameHealthBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Set manually larger font size for health dual text while keeping base template
        local font, originalSize, flags = healthTextLeft:GetFont()
        if font and originalSize then
            healthTextLeft:SetFont(font, originalSize + 1, flags) -- Make health dual text larger than mana
        end
        healthTextLeft:SetPoint("LEFT", TargetFrameHealthBarDummy, "LEFT", 6, 0)
        healthTextLeft:SetJustifyH("LEFT")
        healthTextLeft:Hide()
        dragonFrame.TargetFrameHealthBarTextLeft = healthTextLeft

        local healthTextRight = TargetFrameHealthBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Set manually larger font size for health dual text while keeping base template
        local font, originalSize, flags = healthTextRight:GetFont()
        if font and originalSize then
            healthTextRight:SetFont(font, originalSize + 1, flags) -- Make health dual text larger than mana
        end
        healthTextRight:SetPoint("RIGHT", TargetFrameHealthBarDummy, "RIGHT", -6, 0)
        healthTextRight:SetJustifyH("RIGHT")
        healthTextRight:Hide()
        dragonFrame.TargetFrameHealthBarTextRight = healthTextRight

        local function UpdateTargetCustomText()
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if not dragonFrame then
                return
            end

            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.target or {}
                local textFormat = config.textFormat or "both"
                local useBreakup = config.breakUpLargeNumbers or false

                if UnitExists('target') then
                    local current = UnitHealth('target') or 0
                    local maximum = UnitHealthMax('target') or 1
                    local formattedText = FormatStatusText(current, maximum, textFormat)

                    if textFormat == "both" and type(formattedText) == "table" then
                        -- Update dual text elements
                        if dragonFrame.TargetFrameHealthBarTextLeft then
                            dragonFrame.TargetFrameHealthBarTextLeft:SetText(formattedText.percentage)
                        end
                        if dragonFrame.TargetFrameHealthBarTextRight then
                            dragonFrame.TargetFrameHealthBarTextRight:SetText(formattedText.current)
                        end
                    else
                        -- Update single text element
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        if dragonFrame.TargetFrameHealthBarText then
                            dragonFrame.TargetFrameHealthBarText:SetText(displayText)
                        end
                    end

                    -- Also update mana text if it exists
                    if dragonFrame.TargetFrameManaBarText then
                        local currentMana = UnitPower('target') or 0
                        local maximumMana = UnitPowerMax('target') or 1
                        local formattedManaText = FormatStatusText(currentMana, maximumMana, textFormat)

                        if textFormat == "both" and type(formattedManaText) == "table" then
                            -- Update dual mana text elements
                            if dragonFrame.TargetFrameManaBarTextLeft then
                                dragonFrame.TargetFrameManaBarTextLeft:SetText(formattedManaText.percentage)
                            end
                            if dragonFrame.TargetFrameManaBarTextRight then
                                dragonFrame.TargetFrameManaBarTextRight:SetText(formattedManaText.current)
                            end
                        else
                            -- Update single mana text element
                            local displayManaText = type(formattedManaText) == "table" and formattedManaText.combined or
                                                        formattedManaText
                            dragonFrame.TargetFrameManaBarText:SetText(displayManaText)
                        end
                    end
                end
            end
        end

        TargetFrameHealthBarDummy:HookScript('OnEnter', function(self)
            -- Check if we should show always or only on hover for health text
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.target or {}
                local showHealthAlways = config.showHealthTextAlways or false
                local textFormat = config.textFormat or "both"

                if not showHealthAlways then
                    UpdateTargetCustomText()
                    if textFormat == "both" then
                        -- Show dual text elements for "both" format
                        if dragonFrame.TargetFrameHealthBarTextLeft and dragonFrame.TargetFrameHealthBarTextRight then
                            dragonFrame.TargetFrameHealthBarTextLeft:Show()
                            dragonFrame.TargetFrameHealthBarTextRight:Show()
                        end
                    else
                        -- Show single text element for other formats
                        dragonFrame.TargetFrameHealthBarText:Show()
                    end
                end
            end
        end)
        TargetFrameHealthBarDummy:HookScript('OnLeave', function(self)
            -- Check if we should show always or only on hover for health text
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.target or {}
                local showHealthAlways = config.showHealthTextAlways or false
                local textFormat = config.textFormat or "both"

                if not showHealthAlways then
                    if textFormat == "both" then
                        -- Hide dual text elements for "both" format
                        if dragonFrame.TargetFrameHealthBarTextLeft and dragonFrame.TargetFrameHealthBarTextRight then
                            dragonFrame.TargetFrameHealthBarTextLeft:Hide()
                            dragonFrame.TargetFrameHealthBarTextRight:Hide()
                        end
                    else
                        -- Hide single text element for other formats
                        dragonFrame.TargetFrameHealthBarText:Hide()
                    end
                end
            end
        end)
    end

    -- CUSTOM ManaText for Target (similar to Focus)
    if not dragonFrame.TargetFrameManaBarText then
        local TargetFrameManaBarDummy = CreateFrame('FRAME', 'TargetFrameManaBarDummy')
        TargetFrameManaBarDummy:SetPoint('LEFT', TargetFrameManaBar, 'LEFT', 0, 0)
        TargetFrameManaBarDummy:SetPoint('TOP', TargetFrameManaBar, 'TOP', 0, 0)
        TargetFrameManaBarDummy:SetPoint('RIGHT', TargetFrameManaBar, 'RIGHT', 0, 0)
        TargetFrameManaBarDummy:SetPoint('BOTTOM', TargetFrameManaBar, 'BOTTOM', 0, 0)
        TargetFrameManaBarDummy:SetParent(TargetFrame)
        TargetFrameManaBarDummy:SetFrameStrata('LOW')
        TargetFrameManaBarDummy:SetFrameLevel(3)
        TargetFrameManaBarDummy:EnableMouse(true)

        dragonFrame.TargetFrameManaBarDummy = TargetFrameManaBarDummy

        local t = TargetFrameManaBarDummy:CreateFontString('TargetFrameCustomManaBarText', 'OVERLAY',
            'TextStatusBarText')
        t:SetPoint('CENTER', TargetFrameManaBarDummy, -6, 0)
        t:SetText('MANA')
        t:Hide()
        dragonFrame.TargetFrameManaBarText = t

        -- Create dual text elements for "both" format - Target Mana
        local manaTextLeft = TargetFrameManaBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextLeft:SetPoint("LEFT", TargetFrameManaBarDummy, "LEFT", 6, 0)
        manaTextLeft:SetJustifyH("LEFT")
        manaTextLeft:Hide()
        dragonFrame.TargetFrameManaBarTextLeft = manaTextLeft

        local manaTextRight = TargetFrameManaBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextRight:SetPoint("RIGHT", TargetFrameManaBarDummy, "RIGHT", -13, 0)
        manaTextRight:SetJustifyH("RIGHT")
        manaTextRight:Hide()
        dragonFrame.TargetFrameManaBarTextRight = manaTextRight

        TargetFrameManaBarDummy:HookScript('OnEnter', function(self)
            -- Check if we should show always or only on hover for mana text
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.target or {}
                local showManaAlways = config.showManaTextAlways or false
                local textFormat = config.textFormat or "both"

                if not showManaAlways and UnitExists('target') then
                    local currentMana = UnitPower('target') or 0
                    local maximumMana = UnitPowerMax('target') or 1
                    local formattedText = FormatStatusText(currentMana, maximumMana, textFormat)

                    if textFormat == "both" and type(formattedText) == "table" then
                        -- Show dual text elements for "both" format
                        if dragonFrame.TargetFrameManaBarTextLeft and dragonFrame.TargetFrameManaBarTextRight then
                            dragonFrame.TargetFrameManaBarTextLeft:SetText(formattedText.percentage)
                            dragonFrame.TargetFrameManaBarTextRight:SetText(formattedText.current)
                            dragonFrame.TargetFrameManaBarTextLeft:Show()
                            dragonFrame.TargetFrameManaBarTextRight:Show()
                        end
                    else
                        -- Show single text element for other formats
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        dragonFrame.TargetFrameManaBarText:SetText(displayText)
                        dragonFrame.TargetFrameManaBarText:Show()
                    end
                end
            end
        end)
        TargetFrameManaBarDummy:HookScript('OnLeave', function(self)
            -- Check if we should show always or only on hover for mana text
            local dragonFrame = _G["DragonUIUnitframeFrame"]
            if dragonFrame and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.target or {}
                local showManaAlways = config.showManaTextAlways or false
                local textFormat = config.textFormat or "both"

                if not showManaAlways then
                    if textFormat == "both" then
                        -- Hide dual text elements for "both" format
                        if dragonFrame.TargetFrameManaBarTextLeft and dragonFrame.TargetFrameManaBarTextRight then
                            dragonFrame.TargetFrameManaBarTextLeft:Hide()
                            dragonFrame.TargetFrameManaBarTextRight:Hide()
                        end
                    else
                        -- Hide single text element for other formats
                        dragonFrame.TargetFrameManaBarText:Hide()
                    end
                end
            end
        end)
    end

    -- Update visibility based on individual showTextAlways settings for Target
    if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
        local config = addon.db.profile.unitframe.target or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        -- Handle health text visibility
        if dragonFrame.TargetFrameHealthBarText then
            if showHealthAlways and UnitExists('target') then
                local current = UnitHealth('target') or 0
                local maximum = UnitHealthMax('target') or 1
                local textFormat = config.textFormat or "both"
                local useBreakup = config.breakUpLargeNumbers or false
                local formattedText = FormatStatusText(current, maximum, textFormat)
                dragonFrame.TargetFrameHealthBarText:SetText(formattedText)
                dragonFrame.TargetFrameHealthBarText:Show()
            else
                dragonFrame.TargetFrameHealthBarText:Hide()
            end
        end

        -- Handle mana text visibility (same logic as health)
        if UnitExists('target') then
            local currentMana = UnitPower('target') or 0
            local maximumMana = UnitPowerMax('target') or 1
            local textFormat = config.textFormat or "both"
            local formattedText = FormatStatusText(currentMana, maximumMana, textFormat)

            if showManaAlways then
                if textFormat == "both" and type(formattedText) == "table" then
                    -- Show dual text elements for "both" format
                    if dragonFrame.TargetFrameManaBarTextLeft and dragonFrame.TargetFrameManaBarTextRight then
                        dragonFrame.TargetFrameManaBarTextLeft:SetText(formattedText.percentage)
                        dragonFrame.TargetFrameManaBarTextRight:SetText(formattedText.current)
                        dragonFrame.TargetFrameManaBarTextLeft:Show()
                        dragonFrame.TargetFrameManaBarTextRight:Show()
                    end
                    -- Hide single text element
                    if dragonFrame.TargetFrameManaBarText then
                        dragonFrame.TargetFrameManaBarText:Hide()
                    end
                else
                    -- Show single text element for other formats
                    if dragonFrame.TargetFrameManaBarText then
                        local displayText = type(formattedText) == "table" and formattedText.combined or formattedText
                        dragonFrame.TargetFrameManaBarText:SetText(displayText)
                        dragonFrame.TargetFrameManaBarText:Show()
                    end
                    -- Hide dual text elements
                    if dragonFrame.TargetFrameManaBarTextLeft then
                        dragonFrame.TargetFrameManaBarTextLeft:Hide()
                    end
                    if dragonFrame.TargetFrameManaBarTextRight then
                        dragonFrame.TargetFrameManaBarTextRight:Hide()
                    end
                end
            else
                -- Hide all text elements when not showing always
                if dragonFrame.TargetFrameManaBarText then
                    dragonFrame.TargetFrameManaBarText:Hide()
                end
                if dragonFrame.TargetFrameManaBarTextLeft then
                    dragonFrame.TargetFrameManaBarTextLeft:Hide()
                end
                if dragonFrame.TargetFrameManaBarTextRight then
                    dragonFrame.TargetFrameManaBarTextRight:Hide()
                end
            end
        end
    end
	
	-- Hook for Health Loss effect
	TargetFrame.unit = "target"
	CreateHealthLossBar(TargetFrame, TargetFrameHealthBar)
end
function unitframe.ReApplyTargetFrame()
    -- Lógica de la barra de vida (se mantiene igual)
    if addon:GetConfigValue("unitframe", "target", "classcolor") and UnitIsPlayer('target') then
        TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status')
        local localizedClass, englishClass, classIndex = UnitClass('target')
        TargetFrameHealthBar:SetStatusBarColor(RAID_CLASS_COLORS[englishClass].r, RAID_CLASS_COLORS[englishClass].g,
            RAID_CLASS_COLORS[englishClass].b, 1)
    else
        TargetFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
        TargetFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    end

    -- [[ INICIO DE LA LÓGICA DE RECORTE DINÁMICO PARA LA BARRA DE PODER ]]
    -- Nos aseguramos de que el hook se aplique solo una vez para evitar duplicados.
    if not TargetFrameManaBar.DragonUI_PowerBarHooked then
        TargetFrameManaBar:HookScript("OnValueChanged", function(self, value)
            if not UnitExists("target") then
                return
            end

            local powerType, powerTypeString = UnitPowerType('target')
            local texturePath = 'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\'

            if powerTypeString == 'MANA' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana'
            elseif powerTypeString == 'FOCUS' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Focus'
            elseif powerTypeString == 'RAGE' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage'
            elseif powerTypeString == 'ENERGY' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Energy'
            elseif powerTypeString == 'RUNIC_POWER' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-RunicPower'
            else
                -- Textura por defecto si el tipo de poder no es reconocido
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana'
            end

            local statusBarTexture = self:GetStatusBarTexture()
            statusBarTexture:SetTexture(texturePath)

            -- La magia del recorte dinámico: ajustamos las coordenadas de la textura.
            local min, max = self:GetMinMaxValues()
            if max > 0 and value then
                local percentage = value / max
                -- SetTexCoord(izquierda, derecha, arriba, abajo)
                -- Recortamos la coordenada derecha para que coincida con el porcentaje.
                statusBarTexture:SetTexCoord(0, percentage, 0, 1)
            else
                -- Si no hay valor o el máximo es 0, mostramos la textura completa.
                statusBarTexture:SetTexCoord(0, 1, 0, 1)
            end

            -- Nos aseguramos de que no se aplique ningún tinte de color que arruine la textura.
            statusBarTexture:SetVertexColor(1, 1, 1, 1)
        end)
        -- Marcamos que el hook ya ha sido aplicado.
        TargetFrameManaBar.DragonUI_PowerBarHooked = true
    end

    -- Forzamos una actualización del valor de la barra de poder para que nuestro nuevo hook se ejecute inmediatamente.
    if UnitExists("target") then
        local currentValue = UnitPower("target")
        local maxPower = UnitPowerMax("target")
        TargetFrameManaBar:SetMinMaxValues(0, maxPower)
        TargetFrameManaBar:SetValue(currentValue)
    end
    -- [[ FIN DE LA LÓGICA DE RECORTE DINÁMICO ]]

    if true then
        TargetFrameFlash:SetTexture('')
    end

    if frame.PortraitExtra then
        frame.PortraitExtra:UpdateStyle()
    end

    -- Actualizamos los textos del marco del objetivo.
    if UnitExists('target') then
        local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                           addon.db.profile.unitframe.target
        if config then
            unitframe.UpdateTargetFrameTextSelective(config.showHealthTextAlways or false,
                config.showManaTextAlways or false)
        end
    end
end

-- FIXED: Target of Target Frame Functions - Completely Rewritten
-- FIXED: Simplified ToT reapply function based on ultimaversion
function unitframe.ReApplyToTFrame()
    if not TargetFrameToT or not UnitExists('targettarget') then
        return
    end

    local config = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.tot or {}

    -- Apply health bar texture and colors (simplified like ultimaversion)
    if TargetFrameToTHealthBar then
        -- CRITICAL FIX: Use SetVertexColor, consistent with StyleToTFrame
        if config.classcolor and UnitIsPlayer('targettarget') then
            TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health-Status')
            local _, englishClass = UnitClass('targettarget')
            if englishClass and RAID_CLASS_COLORS[englishClass] then
                local color = RAID_CLASS_COLORS[englishClass]
                TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(color.r, color.g, color.b, 1)
            else
                TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
            end
        else
            TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
            TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Apply mana bar texture based on power type (simplified like ultimaversion)
    if TargetFrameToTManaBar then
        -- CRITICAL FIX: Call the unified texture update function which already handles VertexColor
        unitframe.UpdateToTPowerBarTexture()
    end
end

-- FIXED: Simplified ToT configuration function based on ultimaversion
function unitframe.ChangeToT()
    if not TargetFrameToT then
        return
    end

    -- Get configuration settings
    local config = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.tot or {}
    local scale = config.scale or 1.0
    local anchorFrame = config.anchorFrame or 'TargetFrame'
    local anchor = config.anchor or 'BOTTOMRIGHT'
    local anchorParent = config.anchorParent or 'BOTTOMRIGHT'
    local x = config.x or (-35 + 27)
    local y = config.y or -15

    -- Position and scale the ToT frame (like ultimaversion)
    TargetFrameToT:ClearAllPoints()
    TargetFrameToT:SetPoint(anchor, _G[anchorFrame] or TargetFrame, anchorParent, x, y)
    TargetFrameToT:SetScale(scale)
    TargetFrameToT:SetSize(93 + 27, 45)

    -- Hide default texture frame (simplified)
    if TargetFrameToTTextureFrameTexture then
        TargetFrameToTTextureFrameTexture:SetTexture('')
    end

    -- Hide original background
    if TargetFrameToTBackground then
        TargetFrameToTBackground:Hide()
    end

    -- Create custom background and border (like ultimaversion)
    local totDelta = 1

    -- WoW 3.3.5a Layer Order: Create background (BACKGROUND layer - Capa 0)
    -- FIXED: Follow exact same pattern as PlayerFrame, TargetFrame, FocusFrame
    if not frame.TargetFrameToTBackground then
        local background = TargetFrameToT:CreateTexture('DragonUITargetFrameToTBackground')
        background:SetDrawLayer('BACKGROUND', 0) -- Same sublevel as other frames
        background:SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', TargetFrameToTPortrait, 'CENTER', -25 + 1, -10 + totDelta)
        frame.TargetFrameToTBackground = background
    end

    -- WoW 3.3.5a Layer Order: Create border (OVERLAY layer - Capa 3) - Real border on top
    if not frame.TargetFrameToTBorder then
        local border = TargetFrameToTHealthBar:CreateTexture('DragonUITargetFrameToTBorder')
        border:SetDrawLayer('OVERLAY', 0) -- Capa 3: Real border on top of everything
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER')
        border:SetPoint('LEFT', TargetFrameToTPortrait, 'CENTER', -25 + 1, -10 + totDelta)
        -- FIXED: Ensure visibility
        border:Show()
        border:SetAlpha(1)
        frame.TargetFrameToTBorder = border
    end

    -- WoW 3.3.5a Layer Order: Position health bar in BORDER layer (Capa 1)
    TargetFrameToTHealthBar:ClearAllPoints()
    TargetFrameToTHealthBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 + 1, 0 + totDelta)
    TargetFrameToTHealthBar:SetFrameStrata("LOW")
    TargetFrameToTHealthBar:SetSize(70.5, 10)

    -- WoW 3.3.5a Layer Order: Position mana bar in BORDER layer (Capa 1)
    TargetFrameToTManaBar:ClearAllPoints()
    TargetFrameToTManaBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 - 2 - 1.5 + 1, 2 - 10 - 1 + totDelta)
    TargetFrameToTManaBar:SetFrameStrata("LOW")
    TargetFrameToTManaBar:SetSize(74, 7.5)
    TargetFrameToTManaBar:SetSize(74, 7.5)

    -- WoW 3.3.5a Layer Order: Position name text in BORDER layer (Capa 1)
    if TargetFrameToTTextureFrameName then
        TargetFrameToTTextureFrameName:ClearAllPoints()
        TargetFrameToTTextureFrameName:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 + 1, 2 + 12 - 1 + totDelta)
        TargetFrameToTTextureFrameName:SetDrawLayer("BORDER", 1) -- Capa 1: Text in BORDER layer
    end

    -- Position dead/unconscious text (like ultimaversion)
    if TargetFrameToTTextureFrameDeadText then
        TargetFrameToTTextureFrameDeadText:ClearAllPoints()
        TargetFrameToTTextureFrameDeadText:SetPoint('CENTER', TargetFrameToTHealthBar, 'CENTER', 0, 0)
    end

    if TargetFrameToTTextureFrameUnconsciousText then
        TargetFrameToTTextureFrameUnconsciousText:ClearAllPoints()
        TargetFrameToTTextureFrameUnconsciousText:SetPoint('CENTER', TargetFrameToTHealthBar, 'CENTER', 0, 0)
    end

    -- Position debuffs (like ultimaversion)
    if TargetFrameToTDebuff1 then
        TargetFrameToTDebuff1:SetPoint('TOPLEFT', TargetFrameToT, 'TOPRIGHT', 5, -20)
    end
end

-- FIXED: ToT styling function - Consistent with target and player frames
function unitframe.StyleToTFrame()
    if not TargetFrameToT then
        return
    end

    -- FIXED: Completely remove default Blizzard texture frame that causes visual artifacts
    if TargetFrameToTTextureFrame and TargetFrameToTTextureFrame.EnableMouse then
        TargetFrameToTTextureFrame:Hide()
        TargetFrameToTTextureFrame:SetAlpha(0)
        TargetFrameToTTextureFrame:EnableMouse(false)
        -- Move it completely out of view
        TargetFrameToTTextureFrame:ClearAllPoints()
        TargetFrameToTTextureFrame:SetPoint('TOPLEFT', UIParent, 'BOTTOMRIGHT', 1000, 1000)
    elseif TargetFrameToTTextureFrame then
        -- Fallback if EnableMouse doesn't exist
        TargetFrameToTTextureFrame:Hide()
        TargetFrameToTTextureFrame:SetAlpha(0)
    end
    if TargetFrameToTTextureFrameTexture then
        TargetFrameToTTextureFrameTexture:SetTexture('')
        TargetFrameToTTextureFrameTexture:SetAlpha(0)
    end

    -- Position elements using consistent coordinates
    local totDelta = 1

    -- NOTE: Background and border are created in ChangeToT() to avoid duplication

    -- WoW 3.3.5a Layer Order: Complete health bar initialization - CORRECT LAYER APPROACH
    TargetFrameToTHealthBar:Hide() -- Hide first to prevent visual glitches
    TargetFrameToTHealthBar:ClearAllPoints()
    TargetFrameToTHealthBar:SetParent(TargetFrameToT)

    -- CRITICAL FIX: Use BORDER layer (Capa 1) with high sublevel to be above background

    TargetFrameToTHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5) -- BORDER layer, high sublevel

    -- Apply texture and properties
    TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
    TargetFrameToTHealthBar.SetStatusBarColor = noop
    TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

    -- Position and size
    TargetFrameToTHealthBar:SetSize(70.5, 10)
    TargetFrameToTHealthBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 + 1, 0 + totDelta)

    -- Final show
    TargetFrameToTHealthBar:Show()

    -- WoW 3.3.5a Layer Order: Complete mana bar initialization - CORRECT LAYER APPROACH
    TargetFrameToTManaBar:Hide() -- Hide first to prevent visual glitches
    TargetFrameToTManaBar:ClearAllPoints()
    TargetFrameToTManaBar:SetParent(TargetFrameToT)

    -- CRITICAL FIX: Use BORDER layer (Capa 1) with high sublevel to be above background
    TargetFrameToTManaBar:SetFrameStrata("LOW")
    TargetFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5) -- BORDER layer, high sublevel

    -- Apply texture and properties
    TargetFrameToTManaBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana')

    TargetFrameToTManaBar.SetStatusBarColor = noop
    TargetFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

    -- Position and size
    TargetFrameToTManaBar:SetSize(74, 7.5)
    TargetFrameToTManaBar:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 1 - 2 - 1.5 + 1, 2 - 10 - 1 + totDelta)

    -- Final show
    TargetFrameToTManaBar:Show()

    -- WoW 3.3.5a Layer Order: Position name text in BORDER layer (Capa 1)
    if TargetFrameToTTextureFrameName then
        TargetFrameToTTextureFrameName:ClearAllPoints()
        TargetFrameToTTextureFrameName:SetPoint('LEFT', TargetFrameToTPortrait, 'RIGHT', 3, 13 + totDelta) -- 3px higher
        TargetFrameToTTextureFrameName:SetParent(TargetFrameToT) -- Ensure correct parent
        TargetFrameToTTextureFrameName:Show() -- Ensure it's visible
        -- Ensure proper font and color for visibility
        local font, size, flags = TargetFrameToTTextureFrameName:GetFont()
        if font and size then
            TargetFrameToTTextureFrameName:SetFont(font, math.max(size, 10), flags)
        end
        -- Use the same yellow color as other WoW unit name texts
        TargetFrameToTTextureFrameName:SetTextColor(1.0, 0.82, 0.0, 1.0) -- WoW standard unit name yellow
        TargetFrameToTTextureFrameName:SetDrawLayer("BORDER", 1) -- Capa 1: Text in BORDER layer
    end

    -- Position dead/unconscious text (if they exist)
    if TargetFrameToTTextureFrameDeadText then
        TargetFrameToTTextureFrameDeadText:ClearAllPoints()
        TargetFrameToTTextureFrameDeadText:SetPoint('CENTER', TargetFrameToTHealthBar, 'CENTER', 0, 0)
    end

    if TargetFrameToTTextureFrameUnconsciousText then
        TargetFrameToTTextureFrameUnconsciousText:ClearAllPoints()
        TargetFrameToTTextureFrameUnconsciousText:SetPoint('CENTER', TargetFrameToTHealthBar, 'CENTER', 0, 0)
    end

    -- Position debuffs (if they exist)
    if TargetFrameToTDebuff1 then
        TargetFrameToTDebuff1:SetPoint('TOPLEFT', TargetFrameToT, 'TOPRIGHT', 5, -20)
    end

    -- FIXED: Add persistent color hooks for ToT frames like target frame
    -- Target ToT Health Bar persistent color hook
    TargetFrameToTHealthBar:HookScript('OnValueChanged', function(self)
        if not UnitExists('targettarget') then
            return
        end

        -- WoW 3.3.5a: Force correct layer assignment for bars to be above background
        TargetFrameToTHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5)

        local config =
            addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.tot or {}

        if config.classcolor and UnitIsPlayer('targettarget') then
            local localizedClass, englishClass, classIndex = UnitClass('targettarget')
            if englishClass and RAID_CLASS_COLORS[englishClass] then
                TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health-Status')
                local color = RAID_CLASS_COLORS[englishClass]
                -- Use SetVertexColor since SetStatusBarColor is disabled
                TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(color.r, color.g, color.b, 1)
            else
                TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
                -- Use SetVertexColor since SetStatusBarColor is disabled
                TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
            end
        else
            TargetFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
            -- Use SetVertexColor since SetStatusBarColor is disabled
            TargetFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        end

        -- SIMPLE: Update name text when health changes (indicates unit change)
        if TargetFrameToTTextureFrameName and UnitExists('targettarget') then
            local name = UnitName('targettarget')
            if name then
                -- FIXED: Use optimized truncation function with smaller width
                local finalText = TruncateToTText(TargetFrameToTTextureFrameName, name, 50)
                TargetFrameToTTextureFrameName:SetText(finalText)
            else
                TargetFrameToTTextureFrameName:SetText("")
            end
        end
    end)

    -- Target ToT Mana Bar persistent color hook
    TargetFrameToTManaBar:HookScript('OnValueChanged', function(self)
        if not UnitExists('targettarget') then
            return
        end

        -- WoW 3.3.5a: Force correct layer assignment for bars to be above background
        TargetFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5)

        -- Always maintain white color for mana bar regardless of power type
        -- Use SetVertexColor since SetStatusBarColor is disabled
        TargetFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

        -- Also ensure correct texture based on power type
        unitframe.UpdateToTPowerBarTexture()
    end)

    -- FIXED: Minimal OnUpdate that only handles critical frame level maintenance
    local frameCounter = 0
    local lastUnitName = ""
    TargetFrameToT:HookScript('OnUpdate', function(self)
        frameCounter = frameCounter + 1
        if frameCounter >= 60 then -- Only check every 60 frames (every 2 seconds) to minimize interference
            frameCounter = 0

            -- Update name text only if unit name actually changed
            if TargetFrameToTTextureFrameName and UnitExists('targettarget') then
                local name = UnitName('targettarget') or ""
                if name ~= lastUnitName then
                    lastUnitName = name
                    if name ~= "" then
                        local finalText = TruncateToTText(TargetFrameToTTextureFrameName, name, 50)
                        TargetFrameToTTextureFrameName:SetText(finalText)
                    else
                        TargetFrameToTTextureFrameName:SetText("")
                    end
                end
            elseif TargetFrameToTTextureFrameName then
                -- Clear text when no unit exists
                if lastUnitName ~= "" then
                    lastUnitName = ""
                    TargetFrameToTTextureFrameName:SetText("")
                end
            end
        end
    end)

    -- FIXED: Remove aggressive SetFrameLevel hooks that cause combat issues
    -- Instead, we'll rely on the OnUpdate check every 10 frames which is less intrusive

    -- Create tooltip system for Target of Target
    if not frame.TargetFrameToTTooltip then
        -- Create health text (positioned over health bar)
        local healthText = TargetFrameToTHealthBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Make font smaller for better fit in ToT frame
        local font, size, flags = healthText:GetFont()
        if font and size then
            healthText:SetFont(font, size - 1, flags) -- Reduce size by 1 point
        end
        healthText:SetPoint("CENTER", TargetFrameToTHealthBar, "TOP", 0, -4)
        healthText:SetTextColor(1, 1, 1, 1)
        healthText:SetJustifyH("CENTER")
        healthText:Hide()

        -- Create mana text (positioned over mana bar)
        local manaText = TargetFrameToTManaBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Make font smaller for better fit in ToT frame
        local font, size, flags = manaText:GetFont()
        if font and size then
            manaText:SetFont(font, size - 1, flags) -- Reduce size by 1 point
        end
        manaText:SetPoint("CENTER", TargetFrameToTManaBar, "TOP", 1, -4)
        manaText:SetTextColor(1, 1, 1, 1)
        manaText:SetJustifyH("CENTER")
        manaText:Hide()

        -- Store references
        frame.TargetFrameToTHealthText = healthText
        frame.TargetFrameToTManaText = manaText

        -- Function to update tooltip content
        local function UpdateToTTooltip()
            if not UnitExists('targettarget') then
                frame.TargetFrameToTHealthText:Hide()
                frame.TargetFrameToTManaText:Hide()
                return
            end

            local health = UnitHealth('targettarget') or 0
            local mana = UnitPower('targettarget') or 0
            local powerType = UnitPowerType('targettarget')

            -- Format health text
            local healthFormatted = health > 999 and string.format("%.1fk", health / 1000) or tostring(health)
            frame.TargetFrameToTHealthText:SetText(healthFormatted)

            -- Format mana/power text based on power type
            local manaFormatted = mana > 999 and string.format("%.1fk", mana / 1000) or tostring(mana)
            frame.TargetFrameToTManaText:SetText(manaFormatted)
        end

        -- Store update function for external access
        frame.TargetFrameToTUpdateTooltip = UpdateToTTooltip
    end

    -- Create separate invisible frames for health and mana bars only (not covering portrait)
    if not frame.TargetFrameToTHealthMouseFrame then
        -- Health bar hover frame
        local healthMouseFrame = CreateFrame("Frame", "DragonUITargetFrameToTHealthMouseFrame", TargetFrameToT)
        healthMouseFrame:SetAllPoints(TargetFrameToTHealthBar)
        healthMouseFrame:SetFrameLevel(4) -- Level 4: Above bars (3) for mouse detection
        healthMouseFrame:EnableMouse(true)

        -- Mana bar hover frame
        local manaMouseFrame = CreateFrame("Frame", "DragonUITargetFrameToTManaMouseFrame", TargetFrameToT)
        manaMouseFrame:SetAllPoints(TargetFrameToTManaBar)
        manaMouseFrame:SetFrameLevel(4) -- Level 4: Above bars (3) for mouse detection
        manaMouseFrame:EnableMouse(true)

        local isUpdating = false
        local updateCounter = 0

        -- Shared functions for both frames
        local function OnEnterHandler()
            if UnitExists('targettarget') then
                -- Update and show texts
                frame.TargetFrameToTUpdateTooltip()
                frame.TargetFrameToTHealthText:Show()
                frame.TargetFrameToTManaText:Show()

                -- Start real-time updates while mouse is over
                isUpdating = true
                updateCounter = 0
            end
        end

        local function OnLeaveHandler()
            -- Hide texts when mouse leaves
            frame.TargetFrameToTHealthText:Hide()
            frame.TargetFrameToTManaText:Hide()
            isUpdating = false
        end

        -- Apply hover events to both health and mana frames
        healthMouseFrame:SetScript("OnEnter", OnEnterHandler)
        healthMouseFrame:SetScript("OnLeave", OnLeaveHandler)
        manaMouseFrame:SetScript("OnEnter", OnEnterHandler)
        manaMouseFrame:SetScript("OnLeave", OnLeaveHandler)

        -- Use OnUpdate for real-time updates (WoW 3.3.5a compatible) - only on health frame to avoid duplication
        healthMouseFrame:SetScript("OnUpdate", function(self, elapsed)
            if isUpdating and UnitExists('targettarget') then
                updateCounter = updateCounter + 1
                -- Update every 3 frames (roughly 10 times per second)
                if updateCounter >= 3 then
                    updateCounter = 0
                    frame.TargetFrameToTUpdateTooltip()
                end
            elseif isUpdating then
                -- Unit no longer exists, hide texts
                frame.TargetFrameToTHealthText:Hide()
                frame.TargetFrameToTManaText:Hide()
                isUpdating = false
            end
        end)

        frame.TargetFrameToTHealthMouseFrame = healthMouseFrame
        frame.TargetFrameToTManaMouseFrame = manaMouseFrame
    end
end

-- Helper function to format numbers for ToT/FoT display
function unitframe.FormatToTNumber(value)
    if not value or type(value) ~= "number" then
        return "0"
    end
    if value < 1000 then
        return tostring(value)
    end
    return string.format("%.1fk", value / 1000)
end

-- FIXED: Unified ToT power bar texture update function
function unitframe.UpdateToTPowerBarTexture()
    if not TargetFrameToTManaBar or not UnitExists('targettarget') then
        return
    end

    local powerType = UnitPowerType('targettarget')
    local texturePath = "Interface\\Addons\\DragonUI\\Textures\\Unitframe\\"

    -- FIXED: Use consistent texture naming without -Status suffix for natural colors
    if powerType == 0 then -- Mana
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana"
    elseif powerType == 1 then -- Rage
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage"
    elseif powerType == 2 then -- Focus
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus"
    elseif powerType == 3 then -- Energy
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy"
    elseif powerType == 6 then -- Runic Power
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower"
    else
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana"
    end

    TargetFrameToTManaBar:GetStatusBarTexture():SetTexture(texturePath)

    -- WoW 3.3.5a: Maintain proper layer assignment
    TargetFrameToTManaBar:SetFrameStrata("LOW")
    TargetFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5)
    -- FIXED: Use SetVertexColor since SetStatusBarColor is disabled
    TargetFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
end

-- Function to update Target of Target name text
function unitframe.UpdateToTNameText()
    if TargetFrameToTTextureFrameName and UnitExists('targettarget') then
        local name = UnitName('targettarget')
        if name then
            -- Use optimized truncation function with appropriate width
            local finalText = TruncateToTText(TargetFrameToTTextureFrameName, name, 50)
            TargetFrameToTTextureFrameName:SetText(finalText)
        else
            TargetFrameToTTextureFrameName:SetText("")
        end
    elseif TargetFrameToTTextureFrameName then
        -- Clear text if no target of target exists
        TargetFrameToTTextureFrameName:SetText("")
    end
end

-- Function to update Focus Target of Target name text
function unitframe.UpdateFocusToTNameText()
    if FocusFrameToTTextureFrameName and UnitExists('focustarget') then
        local name = UnitName('focustarget')
        if name then
            -- Use optimized truncation function with appropriate width
            local finalText = TruncateToTText(FocusFrameToTTextureFrameName, name, 50)
            FocusFrameToTTextureFrameName:SetText(finalText)
        else
            FocusFrameToTTextureFrameName:SetText("")
        end
    elseif FocusFrameToTTextureFrameName then
        -- Clear text if no focus target exists
        FocusFrameToTTextureFrameName:SetText("")
    end
end

-- Function to format numbers with k, M suffixes for ToT tooltip
function unitframe.FormatToTNumber(value)
    if not value or value == 0 then
        return "0"
    end

    if value < 1000 then
        return tostring(math.floor(value))
    elseif value < 1000000 then
        if value < 10000 then
            return string.format("%.1fk", value / 1000)
        else
            return string.format("%.0fk", value / 1000)
        end
    else
        return string.format("%.1fM", value / 1000000)
    end
end

function unitframe.MoveTargetFrame(point, relativeTo, relativePoint, xOfs, yOfs)
    TargetFrame:ClearAllPoints()
    -- Usamos _G[relativeTo] para asegurarnos de que funciona con "UIParent" u otros marcos
    TargetFrame:SetPoint(point or "TOPLEFT", _G[relativeTo or "UIParent"] or UIParent, relativePoint or "TOPLEFT",
        xOfs or 216, yOfs or -4)
end

function unitframe.ChangeFocusFrame()
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    -- Get reference to the DragonUI frame
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    FocusFrameTextureFrameTexture:Hide()
    FocusFrameBackground:Hide()

    if not dragonFrame.FocusFrameBackground then
        local background = FocusFrame:CreateTexture('DragonUIFocusFrameBackground')
        background:SetDrawLayer('BACKGROUND', 2)
        background:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', FocusFrame, 'LEFT', 0, -32.5 + 10)
        dragonFrame.FocusFrameBackground = background
    end

    if not dragonFrame.FocusFrameBorder then
        local border = FocusFrame:CreateTexture('DragonUIFocusFrameBorder')
        border:SetDrawLayer('ARTWORK', 2)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER')
        border:SetPoint('LEFT', FocusFrame, 'LEFT', 0, -32.5 + 10)
        border:SetDrawLayer('OVERLAY', 5)
        dragonFrame.FocusFrameBorder = border
    end

    FocusFramePortrait:SetDrawLayer('ARTWORK', 1)
    FocusFramePortrait:SetSize(56, 56)
    local CorrectionY = -3
    local CorrectionX = -5
    FocusFramePortrait:SetPoint('TOPRIGHT', FocusFrame, 'TOPRIGHT', -42 + CorrectionX, -12 + CorrectionY)

    -- Raid target icon positioning (like in original)
    if FocusFrameTextureFrameRaidTargetIcon then
        FocusFrameTextureFrameRaidTargetIcon:SetPoint('CENTER', FocusFramePortrait, 'TOP', 0, 2)
    end

    if FocusFrameNameBackground then
        FocusFrameNameBackground:ClearAllPoints()
        FocusFrameNameBackground:SetTexture(base)
        FocusFrameNameBackground:SetTexCoord(unitframe.GetCoords('UI-HUD-UnitFrame-Target-PortraitOn-Type'))
        FocusFrameNameBackground:SetSize(135, 18)
        FocusFrameNameBackground:SetPoint('BOTTOMLEFT', FocusFrameHealthBar, 'TOPLEFT', -2, -4 - 1)
        -- Configurar draw layer para que esté por encima de las barras pero por debajo del borde
        FocusFrameNameBackground:SetDrawLayer('ARTWORK', 2)
    end

    -- @TODO: change text spacing
    if FocusFrameTextureFrameName then
        FocusFrameTextureFrameName:ClearAllPoints()
        FocusFrameTextureFrameName:SetPoint('BOTTOM', FocusFrameHealthBar, 'TOP', 10, 3 - 2)
        -- Usar SetFont como ToT para ser más confiable que SetScale
        local font, size, flags = FocusFrameTextureFrameName:GetFont()
        if font and size then
            FocusFrameTextureFrameName:SetFont(font, math.max(size * 0.9, 10), flags) -- Reducir tamaño de fuente
        end
    end

    if FocusFrameTextureFrameLevelText then
        FocusFrameTextureFrameLevelText:ClearAllPoints()
        FocusFrameTextureFrameLevelText:SetPoint('BOTTOMRIGHT', FocusFrameHealthBar, 'TOPLEFT', 16, 3 - 2)
    end

    local dx = 5
    -- health vs mana bar
    local deltaSize = 132 - 125

    -- Use proper references like in original (if they exist in 3.3.5a)
    if FocusFrameTextureFrameHealthBarText then
        FocusFrameTextureFrameHealthBarText:ClearAllPoints()
        FocusFrameTextureFrameHealthBarText:SetPoint('CENTER', FocusFrameHealthBar, 0, 0)
    end
    if FocusFrameTextureFrameManaBarText then
        FocusFrameTextureFrameManaBarText:ClearAllPoints()
        FocusFrameTextureFrameManaBarText:SetPoint('CENTER', FocusFrameManaBar, -deltaSize / 2, 0)
    end

    -- Health 119,12
    FocusFrameHealthBar:ClearAllPoints()
    FocusFrameHealthBar:SetSize(125, 20)
    FocusFrameHealthBar:SetPoint('RIGHT', FocusFramePortrait, 'LEFT', -1, 0)

    -- Mana 119,12
    FocusFrameManaBar:ClearAllPoints()
    FocusFrameManaBar:SetPoint('RIGHT', FocusFramePortrait, 'LEFT', -1 + 8 - 0.5, -18 + 1 + 0.5)
    FocusFrameManaBar:SetSize(132, 9)
    FocusFrameManaBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana')
    FocusFrameManaBar:GetStatusBarTexture():SetDrawLayer("BORDER", 1) -- Misma capa que la barra de vida
    FocusFrameManaBar:SetStatusBarColor(1, 1, 1, 1)

    -- [[ INICIO DE LA LÓGICA DE RECORTE DINÁMICO PARA LA BARRA DE PODER DEL FOCUS ]]
    -- Nos aseguramos de que el hook se aplique solo una vez para evitar duplicados.
    if not FocusFrameManaBar.DragonUI_PowerBarHooked then
        FocusFrameManaBar:HookScript("OnValueChanged", function(self, value)
            if not UnitExists("focus") then
                return
            end

            local powerType, powerTypeString = UnitPowerType('focus')
            local texturePath = 'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\'

            if powerTypeString == 'MANA' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana'
            elseif powerTypeString == 'FOCUS' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Focus'
            elseif powerTypeString == 'RAGE' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage'
            elseif powerTypeString == 'ENERGY' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Energy'
            elseif powerTypeString == 'RUNIC_POWER' then
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-RunicPower'
            else
                -- Textura por defecto si el tipo de poder no es reconocido
                texturePath = texturePath .. 'UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana'
            end

            local statusBarTexture = self:GetStatusBarTexture()
            statusBarTexture:SetTexture(texturePath)

            -- Configurar el draw layer correcto para la barra de maná del focus
            statusBarTexture:SetDrawLayer("BORDER", 1)

            -- La magia del recorte dinámico: ajustamos las coordenadas de la textura.
            local min, max = self:GetMinMaxValues()
            if max > 0 and value then
                local percentage = value / max
                -- SetTexCoord(izquierda, derecha, arriba, abajo)
                -- Recortamos la coordenada derecha para que coincida con el porcentaje.
                statusBarTexture:SetTexCoord(0, percentage, 0, 1)
            else
                -- Si no hay valor o el máximo es 0, mostramos la textura completa.
                statusBarTexture:SetTexCoord(0, 1, 0, 1)
            end

            -- Nos aseguramos de que no se aplique ningún tinte de color que arruine la textura.
            statusBarTexture:SetVertexColor(1, 1, 1, 1)
        end)
        -- Marcamos que el hook ya ha sido aplicado.
        FocusFrameManaBar.DragonUI_PowerBarHooked = true
    end

    -- Forzamos una actualización del valor de la barra de poder para que nuestro nuevo hook se ejecute inmediatamente.
    if UnitExists("focus") then
        local currentValue = UnitPower("focus")
        local maxPower = UnitPowerMax("focus")
        FocusFrameManaBar:SetMinMaxValues(0, maxPower)
        FocusFrameManaBar:SetValue(currentValue)
    end
    -- [[ FIN DE LA LÓGICA DE RECORTE DINÁMICO PARA EL FOCUS ]]

    -- CUSTOM HealthText
    if not frame.FocusFrameHealthBarText then
        local FocusFrameHealthBarDummy = CreateFrame('FRAME', 'FocusFrameHealthBarDummy')
        FocusFrameHealthBarDummy:SetPoint('LEFT', FocusFrameHealthBar, 'LEFT', 0, 0)
        FocusFrameHealthBarDummy:SetPoint('TOP', FocusFrameHealthBar, 'TOP', 0, 0)
        FocusFrameHealthBarDummy:SetPoint('RIGHT', FocusFrameHealthBar, 'RIGHT', 0, 0)
        FocusFrameHealthBarDummy:SetPoint('BOTTOM', FocusFrameHealthBar, 'BOTTOM', 0, 0)
        FocusFrameHealthBarDummy:SetParent(FocusFrame)
        FocusFrameHealthBarDummy:SetFrameStrata('LOW')
        FocusFrameHealthBarDummy:SetFrameLevel(3)
        FocusFrameHealthBarDummy:EnableMouse(true)

        frame.FocusFrameHealthBarDummy = FocusFrameHealthBarDummy

        local t = FocusFrameHealthBarDummy:CreateFontString('FocusFrameHealthBarText', 'OVERLAY', 'TextStatusBarText')
        -- Set manually larger font size for health text while keeping base template
        local font, originalSize, flags = t:GetFont()
        if font and originalSize then
            t:SetFont(font, originalSize + 1, flags) -- Make health text 2 points larger than mana
        end
        t:SetPoint('CENTER', FocusFrameHealthBarDummy, 0, 0)
        t:SetText('HP')
        t:Hide()
        frame.FocusFrameHealthBarText = t

        -- Create dual text elements for "both" format - Focus Health
        local healthTextLeft = FocusFrameHealthBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Set manually larger font size for health dual text while keeping base template
        local font, originalSize, flags = healthTextLeft:GetFont()
        if font and originalSize then
            healthTextLeft:SetFont(font, originalSize + 1, flags) -- Make health dual text larger than mana
        end
        healthTextLeft:SetPoint("LEFT", FocusFrameHealthBarDummy, "LEFT", 6, 0)
        healthTextLeft:SetJustifyH("LEFT")
        healthTextLeft:Hide()
        frame.FocusFrameHealthBarTextLeft = healthTextLeft

        local healthTextRight = FocusFrameHealthBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        -- Set manually larger font size for health dual text while keeping base template
        local font, originalSize, flags = healthTextRight:GetFont()
        if font and originalSize then
            healthTextRight:SetFont(font, originalSize + 1, flags) -- Make health dual text larger than mana
        end
        healthTextRight:SetPoint("RIGHT", FocusFrameHealthBarDummy, "RIGHT", -6, 0)
        healthTextRight:SetJustifyH("RIGHT")
        healthTextRight:Hide()
        frame.FocusFrameHealthBarTextRight = healthTextRight

        FocusFrameHealthBarDummy:HookScript('OnEnter', function(self)
            -- Check if we should show always or only on hover for health text
            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.focus or {}
                local showHealthAlways = config.showHealthTextAlways or false
                local textFormat = config.textFormat or "numeric"
                local useBreakup = config.breakUpLargeNumbers
                if useBreakup == nil then
                    useBreakup = false
                end

                if not showHealthAlways then
                    -- Check if standard text is visible (like in original)
                    if FocusFrameTextureFrameHealthBarText and FocusFrameTextureFrameHealthBarText:IsVisible() then
                        -- Don't show custom text if standard is visible
                    else
                        -- Update ONLY health text content
                        if UnitExists('focus') then
                            local max_health = UnitHealthMax('focus')
                            local health = UnitHealth('focus')
                            local formattedHealthText = FormatStatusText(health, max_health, textFormat, useBreakup)

                            -- Show appropriate health elements based on format
                            if textFormat == "both" and type(formattedHealthText) == "table" then
                                -- For "both" format, show dual elements
                                if frame.FocusFrameHealthBarTextLeft then
                                    frame.FocusFrameHealthBarTextLeft:SetText(formattedHealthText.percentage)
                                    frame.FocusFrameHealthBarTextLeft:Show()
                                end
                                if frame.FocusFrameHealthBarTextRight then
                                    frame.FocusFrameHealthBarTextRight:SetText(formattedHealthText.current)
                                    frame.FocusFrameHealthBarTextRight:Show()
                                end
                                -- Hide single element
                                if frame.FocusFrameHealthBarText then
                                    frame.FocusFrameHealthBarText:Hide()
                                end
                            else
                                -- For other formats, show single element
                                local displayText = type(formattedHealthText) == "table" and
                                                        formattedHealthText.combined or formattedHealthText
                                if frame.FocusFrameHealthBarText then
                                    frame.FocusFrameHealthBarText:SetText(displayText)
                                    frame.FocusFrameHealthBarText:Show()
                                end
                                -- Hide dual elements
                                if frame.FocusFrameHealthBarTextLeft then
                                    frame.FocusFrameHealthBarTextLeft:Hide()
                                end
                                if frame.FocusFrameHealthBarTextRight then
                                    frame.FocusFrameHealthBarTextRight:Hide()
                                end
                            end
                        end
                    end
                end
            end
        end)
        FocusFrameHealthBarDummy:HookScript('OnLeave', function(self)
            -- Check if we should show always or only on hover for health text
            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.focus or {}
                local showHealthAlways = config.showHealthTextAlways or false

                if not showHealthAlways then
                    -- Hide only HEALTH text elements
                    if frame.FocusFrameHealthBarText then
                        frame.FocusFrameHealthBarText:Hide()
                    end
                    if frame.FocusFrameHealthBarTextLeft then
                        frame.FocusFrameHealthBarTextLeft:Hide()
                    end
                    if frame.FocusFrameHealthBarTextRight then
                        frame.FocusFrameHealthBarTextRight:Hide()
                    end
                end
            end
        end)
    end

    -- CUSTOM ManaText
    if not frame.FocusFrameManaBarText then
        local FocusFrameManaBarDummy = CreateFrame('FRAME', 'FocusFrameManaBarDummy')
        FocusFrameManaBarDummy:SetPoint('LEFT', FocusFrameManaBar, 'LEFT', 0, 0)
        FocusFrameManaBarDummy:SetPoint('TOP', FocusFrameManaBar, 'TOP', 0, 0)
        FocusFrameManaBarDummy:SetPoint('RIGHT', FocusFrameManaBar, 'RIGHT', 0, 0)
        FocusFrameManaBarDummy:SetPoint('BOTTOM', FocusFrameManaBar, 'BOTTOM', 0, 0)
        FocusFrameManaBarDummy:SetParent(FocusFrame)
        FocusFrameManaBarDummy:SetFrameStrata('LOW')
        FocusFrameManaBarDummy:SetFrameLevel(3)
        FocusFrameManaBarDummy:EnableMouse(true)

        frame.FocusFrameManaBarDummy = FocusFrameManaBarDummy

        local t = FocusFrameManaBarDummy:CreateFontString('FocusFrameManaBarText', 'OVERLAY', 'TextStatusBarText')
        t:SetPoint('CENTER', FocusFrameManaBarDummy, -dx, 0)
        t:SetText('MANA')
        t:Hide()
        frame.FocusFrameManaBarText = t

        -- Create dual text elements for "both" format - Focus Mana
        local manaTextLeft = FocusFrameManaBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextLeft:SetPoint("LEFT", FocusFrameManaBarDummy, "LEFT", 6, 0)
        manaTextLeft:SetJustifyH("LEFT")
        manaTextLeft:Hide()
        frame.FocusFrameManaBarTextLeft = manaTextLeft

        local manaTextRight = FocusFrameManaBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextRight:SetPoint("RIGHT", FocusFrameManaBarDummy, "RIGHT", -13, 0)
        manaTextRight:SetJustifyH("RIGHT")
        manaTextRight:Hide()
        frame.FocusFrameManaBarTextRight = manaTextRight

        FocusFrameManaBarDummy:HookScript('OnEnter', function(self)
            -- Check if we should show always or only on hover for mana text
            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.focus or {}
                local showManaAlways = config.showManaTextAlways or false
                local textFormat = config.textFormat or "numeric"
                local useBreakup = config.breakUpLargeNumbers
                if useBreakup == nil then
                    useBreakup = false
                end

                if not showManaAlways then
                    -- Check if standard text is visible (like in original)
                    if FocusFrameTextureFrameManaBarText and FocusFrameTextureFrameManaBarText:IsVisible() then
                        -- Don't show custom text if standard is visible
                    else
                        -- Update ONLY mana text content
                        if UnitExists('focus') then
                            local max_mana = UnitPowerMax('focus')
                            local mana = UnitPower('focus')

                            if max_mana == 0 then
                                -- Hide all mana text if no mana
                                if frame.FocusFrameManaBarText then
                                    frame.FocusFrameManaBarText:SetText('')
                                    frame.FocusFrameManaBarText:Hide()
                                end
                                if frame.FocusFrameManaBarTextLeft then
                                    frame.FocusFrameManaBarTextLeft:SetText('')
                                    frame.FocusFrameManaBarTextLeft:Hide()
                                end
                                if frame.FocusFrameManaBarTextRight then
                                    frame.FocusFrameManaBarTextRight:SetText('')
                                    frame.FocusFrameManaBarTextRight:Hide()
                                end
                            else
                                local formattedManaText = FormatStatusText(mana, max_mana, textFormat, useBreakup)

                                -- Show appropriate mana elements based on format
                                if textFormat == "both" and type(formattedManaText) == "table" then
                                    -- For "both" format, show dual elements
                                    if frame.FocusFrameManaBarTextLeft then
                                        frame.FocusFrameManaBarTextLeft:SetText(formattedManaText.percentage)
                                        frame.FocusFrameManaBarTextLeft:Show()
                                    end
                                    if frame.FocusFrameManaBarTextRight then
                                        frame.FocusFrameManaBarTextRight:SetText(formattedManaText.current)
                                        frame.FocusFrameManaBarTextRight:Show()
                                    end
                                    -- Hide single element
                                    if frame.FocusFrameManaBarText then
                                        frame.FocusFrameManaBarText:Hide()
                                    end
                                else
                                    -- For other formats, show single element
                                    local displayText = type(formattedManaText) == "table" and
                                                            formattedManaText.combined or formattedManaText
                                    if frame.FocusFrameManaBarText then
                                        frame.FocusFrameManaBarText:SetText(displayText)
                                        frame.FocusFrameManaBarText:Show()
                                    end
                                    -- Hide dual elements
                                    if frame.FocusFrameManaBarTextLeft then
                                        frame.FocusFrameManaBarTextLeft:Hide()
                                    end
                                    if frame.FocusFrameManaBarTextRight then
                                        frame.FocusFrameManaBarTextRight:Hide()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
        FocusFrameManaBarDummy:HookScript('OnLeave', function(self)
            -- Check if we should show always or only on hover for mana text
            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.focus or {}
                local showManaAlways = config.showManaTextAlways or false

                if not showManaAlways then
                    -- Hide only MANA text elements
                    if frame.FocusFrameManaBarText then
                        frame.FocusFrameManaBarText:Hide()
                    end
                    if frame.FocusFrameManaBarTextLeft then
                        frame.FocusFrameManaBarTextLeft:Hide()
                    end
                    if frame.FocusFrameManaBarTextRight then
                        frame.FocusFrameManaBarTextRight:Hide()
                    end
                end
            end
        end)
    end

    if FocusFrameFlash then
        FocusFrameFlash:SetTexture('')
    end

    -- ToT Debuff positioning (like in original)
    if FocusFrameToTDebuff1 then
        FocusFrameToTDebuff1:SetPoint('TOPLEFT', FocusFrameToT, 'TOPRIGHT', 25, -20)
    end

    if not frame.FocusFrameFlash then
        local flash = FocusFrame:CreateTexture('DragonUIFocusFrameFlash')
        flash:SetDrawLayer('BACKGROUND', 1) -- Sublevel más bajo para que esté por debajo de todo
        flash:SetTexture('Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-InCombat')
        flash:SetPoint('CENTER', FocusFrame, 'CENTER', 20 + CorrectionX, -20 + CorrectionY)
        flash:SetSize(256, 128)
        -- Textures don't have SetScale in WoW 3.3.5a, only frames do
        if flash.SetScale then
            flash:SetScale(1)
        end
        flash:SetVertexColor(1.0, 0.0, 0.0, 1.0)
        flash:SetBlendMode('ADD')
        frame.FocusFrameFlash = flash
    end

    hooksecurefunc(FocusFrameFlash, 'Show', function()
        if FocusFrameFlash then
            FocusFrameFlash:SetTexture('')
        end
        frame.FocusFrameFlash:Show()
        if (UIFrameIsFlashing(frame.FocusFrameFlash)) then
        else
            local dt = 0.5
            UIFrameFlash(frame.FocusFrameFlash, dt, dt, -1)
        end
    end)

    hooksecurefunc(FocusFrameFlash, 'Hide', function()
        if FocusFrameFlash then
            FocusFrameFlash:SetTexture('')
        end
        if (UIFrameIsFlashing(frame.FocusFrameFlash)) then
            UIFrameFlashStop(frame.FocusFrameFlash)
        end
        frame.FocusFrameFlash:Hide()
    end)

    if not frame.FocusExtra then
        local extra = FocusFrame:CreateTexture('DragonUIFocusFramePortraitExtra')
        extra:SetTexture('Interface\\Addons\\DragonUI\\Textures\\uiunitframeboss2x')
        extra:SetTexCoord(0.001953125, 0.314453125, 0.322265625, 0.630859375)
        extra:SetSize(80, 79)
        extra:SetDrawLayer('ARTWORK', 3)
        extra:SetPoint('CENTER', FocusFramePortrait, 'CENTER', 4, 1)

        extra.UpdateStyle = function()
            local class = UnitClassification('focus')
            --[[ "worldboss", "rareelite", "elite", "rare", "normal", "trivial" or "minus" ]]
            if class == 'worldboss' then
                frame.FocusExtra:Show()
                frame.FocusExtra:SetSize(99, 81)
                frame.FocusExtra:SetTexCoord(0.001953125, 0.388671875, 0.001953125, 0.31835937)
                frame.FocusExtra:SetPoint('CENTER', FocusFramePortrait, 'CENTER', 13, 1)
            elseif class == 'rareelite' or class == 'rare' then
                frame.FocusExtra:Show()
                frame.FocusExtra:SetSize(80, 79)
                frame.FocusExtra:SetTexCoord(0.00390625, 0.31640625, 0.64453125, 0.953125)
                frame.FocusExtra:SetPoint('CENTER', FocusFramePortrait, 'CENTER', 4, 1)
            elseif class == 'elite' then
                frame.FocusExtra:Show()
                frame.FocusExtra:SetTexCoord(0.001953125, 0.314453125, 0.322265625, 0.630859375)
                frame.FocusExtra:SetSize(80, 79)
                frame.FocusExtra:SetPoint('CENTER', FocusFramePortrait, 'CENTER', 4, 1)
            else
                local name, realm = UnitName('focus') -- Fixed: was 'target', now 'focus'
                if unitframe.famous[name] then
                    frame.FocusExtra:Show()
                    frame.FocusExtra:SetSize(99, 81)
                    frame.FocusExtra:SetTexCoord(0.001953125, 0.388671875, 0.001953125, 0.31835937)
                    frame.FocusExtra:SetPoint('CENTER', FocusFramePortrait, 'CENTER', 13, 1)
                else
                    frame.FocusExtra:Hide()
                end
            end
        end

        frame.FocusExtra = extra
    end

    -- Update visibility based on individual showTextAlways settings for Focus
    if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
        local config = addon.db.profile.unitframe.focus or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        -- Handle health text visibility
        if frame.FocusFrameHealthBarText then
            if showHealthAlways and UnitExists('focus') then
                unitframe.UpdateFocusText()
                frame.FocusFrameHealthBarText:Show()
            else
                frame.FocusFrameHealthBarText:Hide()
            end
        end

        -- Handle mana text visibility
        if frame.FocusFrameManaBarText then
            if showManaAlways and UnitExists('focus') then
                unitframe.UpdateFocusText()
                frame.FocusFrameManaBarText:Show()
            else
                frame.FocusFrameManaBarText:Hide()
            end
        end
    end
	
	-- Hook for Health Loss effect
	FocusFrame.unit = "focus"
	CreateHealthLossBar(FocusFrame, FocusFrameHealthBar)
end

function unitframe.MoveFocusFrame(point, relativeTo, relativePoint, xOfs, yOfs)
    FocusFrame:ClearAllPoints()
    FocusFrame:SetPoint(point or "TOPLEFT", _G[relativeTo or "UIParent"] or UIParent, relativePoint or "TOPLEFT",
        xOfs or 288, yOfs or -258)
end
function unitframe.ReApplyFocusFrame()
    -- FIXED: Función más robusta que SIEMPRE aplica colores correctamente

    if not UnitExists('focus') then

        return
    end

    -- 1. SIEMPRE aplicar la configuración de colores de clase
    local shouldUseClassColor = addon:GetConfigValue("unitframe", "focus", "classcolor") and UnitIsPlayer('focus')

    if shouldUseClassColor then
        local localizedClass, englishClass, classIndex = UnitClass('focus')
        if englishClass and RAID_CLASS_COLORS[englishClass] then
            FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status')
            local color = RAID_CLASS_COLORS[englishClass]
            FocusFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b, 1)

        else
            -- Fallback si no se puede obtener la clase
            FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
            FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)

        end
    else
        -- CRÍTICO: Colores de clase deshabilitados o no es jugador - FORZAR BLANCO
        FocusFrameHealthBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
        FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    end

    -- 2. CRÍTICO: FORZAR el DrawLayer correcto
    FocusFrameHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 1)

    -- 3. CRÍTICO: FORZAR actualización del valor para triggear el hook de OnValueChanged
    if UnitExists("focus") then
        local currentHealth = UnitHealth("focus")
        local maxHealth = UnitHealthMax("focus")
        FocusFrameHealthBar:SetMinMaxValues(0, maxHealth)
        FocusFrameHealthBar:SetValue(currentHealth)

    end

    -- 4. CRÍTICO: Aplicar configuración de power bar con COLOR BLANCO FORZADO
    local powerType, powerTypeString = UnitPowerType('focus')

    if powerTypeString == 'MANA' then
        FocusFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana')
    elseif powerTypeString == 'FOCUS' then
        FocusFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Focus')
    elseif powerTypeString == 'RAGE' then
        FocusFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage')
    elseif powerTypeString == 'ENERGY' then
        FocusFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Energy')
    elseif powerTypeString == 'RUNIC_POWER' then
        FocusFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-RunicPower')
    end

    -- CRÍTICO: SIEMPRE forzar color blanco en la barra de poder
    FocusFrameManaBar:SetStatusBarColor(1, 1, 1, 1)

    -- 5. Ocultar flash de combate si existe
    if FocusFrameFlash then
        FocusFrameFlash:SetTexture('')
    end

    -- 6. Actualizar extra portrait si existe
    if frame.FocusExtra then
        frame.FocusExtra:UpdateStyle()
    end

end

-- FIXED: Focus ToT Frame Functions - Completely Rewritten like Target ToT
-- FIXED: Simplified FoT reapply function based on ultimaversion
function unitframe.ReApplyFocusToTFrame()
    if not FocusFrameToT or not UnitExists('focustarget') then
        return
    end

    local config = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.fot or {}

    -- Apply health bar texture and colors (simplified like ultimaversion)
    if FocusFrameToTHealthBar then
        -- CRITICAL FIX: Use SetVertexColor, consistent with StyleFocusToTFrame
        if config.classcolor and UnitIsPlayer('focustarget') then
            FocusFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health-Status')
            local _, englishClass = UnitClass('focustarget')
            if englishClass and RAID_CLASS_COLORS[englishClass] then
                local color = RAID_CLASS_COLORS[englishClass]
                FocusFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(color.r, color.g, color.b, 1)
            else
                FocusFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
            end
        else
            FocusFrameToTHealthBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
            FocusFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Apply mana bar texture based on power type (simplified like ultimaversion)
    if FocusFrameToTManaBar then
        -- CRITICAL FIX: Call the unified texture update function which already handles VertexColor
        unitframe.UpdateFocusToTPowerBarTexture()
    end
end

function unitframe.ChangeFocusToT()
    if not FocusFrameToT then
        return
    end

    -- Get configuration settings
    local config = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.fot or {}
    local scale = config.scale or 1.0
    local anchorFrame = config.anchorFrame or 'FocusFrame'
    local anchor = config.anchor or 'BOTTOMRIGHT'
    local anchorParent = config.anchorParent or 'BOTTOMRIGHT'
    local x = config.x or (-35 + 27)
    local y = config.y or -15

    -- Position and scale the FoT frame (like ultimaversion)
    FocusFrameToT:ClearAllPoints()
    FocusFrameToT:SetPoint(anchor, _G[anchorFrame] or FocusFrame, anchorParent, x, y)
    FocusFrameToT:SetScale(scale)
    FocusFrameToT:SetSize(93 + 27, 45)

    -- Hide default texture frame (simplified)
    if FocusFrameToTTextureFrameTexture then
        FocusFrameToTTextureFrameTexture:SetTexture('')
    end

    -- Hide original background
    if FocusFrameToTBackground then
        FocusFrameToTBackground:Hide()
    end

    -- Create custom background and border (like ultimaversion)
    local fotDelta = 1

    if not frame.FocusFrameToTBackground then
        local background = FocusFrameToT:CreateTexture('DragonUIFocusFrameToTBackground')
        background:SetDrawLayer('BACKGROUND', 0)
        background:SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', FocusFrameToTPortrait, 'CENTER', -25 + 1, -10 + fotDelta)
        frame.FocusFrameToTBackground = background
    end

    if not frame.FocusFrameToTBorder then
        local border = FocusFrameToTHealthBar:CreateTexture('DragonUIFocusFrameToTBorder')
        border:SetDrawLayer('OVERLAY', 0)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER')
        border:SetPoint('LEFT', FocusFrameToTPortrait, 'CENTER', -25 + 1, -10 + fotDelta)
        border:Show()
        border:SetAlpha(1)
        frame.FocusFrameToTBorder = border
    end

    -- Position name text 
    if FocusFrameToTTextureFrameName then
        FocusFrameToTTextureFrameName:ClearAllPoints()
        FocusFrameToTTextureFrameName:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 1 + 1, 2 + 12 - 1 + fotDelta)
        FocusFrameToTTextureFrameName:SetDrawLayer('BORDER', 1)
    end

    -- Position dead/unconscious text 
    if FocusFrameToTTextureFrameDeadText then
        FocusFrameToTTextureFrameDeadText:ClearAllPoints()
        FocusFrameToTTextureFrameDeadText:SetPoint('CENTER', FocusFrameToTHealthBar, 'CENTER', 0, 0)
    end

    if FocusFrameToTTextureFrameUnconsciousText then
        FocusFrameToTTextureFrameUnconsciousText:ClearAllPoints()
        FocusFrameToTTextureFrameUnconsciousText:SetPoint('CENTER', FocusFrameToTHealthBar, 'CENTER', 0, 0)
    end

    -- Position debuffs 
    if FocusFrameToTDebuff1 then
        FocusFrameToTDebuff1:SetPoint('TOPLEFT', FocusFrameToT, 'TOPRIGHT', 5, -20)
    end
end

function unitframe.StyleFocusToTFrame()
    if not FocusFrameToT then
        return
    end

    -- Hide default Blizzard texture frame (Tu código original - CORRECTO)
    if FocusFrameToTTextureFrame and FocusFrameToTTextureFrame.EnableMouse then
        FocusFrameToTTextureFrame:Hide()
        FocusFrameToTTextureFrame:SetAlpha(0)
        FocusFrameToTTextureFrame:EnableMouse(false)
    elseif FocusFrameToTTextureFrame then
        FocusFrameToTTextureFrame:Hide()
        FocusFrameToTTextureFrame:SetAlpha(0)
    end
    if FocusFrameToTTextureFrameTexture then
        FocusFrameToTTextureFrameTexture:SetTexture('')
        FocusFrameToTTextureFrameTexture:SetAlpha(0)
    end

    local fotDelta = 1

    -- Setup health bar
    FocusFrameToTHealthBar:Hide()
    FocusFrameToTHealthBar:ClearAllPoints()
    FocusFrameToTHealthBar:SetParent(FocusFrameToT)
    FocusFrameToTHealthBar:SetFrameStrata("LOW")
    FocusFrameToTHealthBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5) -- Capa 1 (BORDER), por encima del fondo
    FocusFrameToTHealthBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
    FocusFrameToTHealthBar.SetStatusBarColor = noop -- Desactivar el cambio de color de Blizzard
    FocusFrameToTHealthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1) -- Usar VertexColor para el color
    FocusFrameToTHealthBar:SetSize(70.5, 10)
    FocusFrameToTHealthBar:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 1 + 1, 0 + fotDelta)
    FocusFrameToTHealthBar:Show()

    -- Setup power bar
    FocusFrameToTManaBar:Hide()
    FocusFrameToTManaBar:ClearAllPoints()
    FocusFrameToTManaBar:SetParent(FocusFrameToT)
    FocusFrameToTManaBar:SetFrameStrata("LOW")
    FocusFrameToTManaBar:GetStatusBarTexture():SetDrawLayer("BORDER", 5) -- Capa 1 (BORDER), por encima del fondo
    FocusFrameToTManaBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana')
    FocusFrameToTManaBar.SetStatusBarColor = noop -- Desactivar el cambio de color de Blizzard
    FocusFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1) -- Usar VertexColor para el color
    FocusFrameToTManaBar:SetSize(74, 7.5)
    FocusFrameToTManaBar:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 1 - 2 - 1.5 + 1, 2 - 10 - 1 + fotDelta)
    FocusFrameToTManaBar:Show()

    -- Posicionar texto del nombre (Tu código original - CORRECTO)
    if FocusFrameToTTextureFrameName then
        FocusFrameToTTextureFrameName:ClearAllPoints()
        FocusFrameToTTextureFrameName:SetPoint('LEFT', FocusFrameToTPortrait, 'RIGHT', 3, 13 + fotDelta)
        FocusFrameToTTextureFrameName:SetParent(FocusFrameToT)
        FocusFrameToTTextureFrameName:Show()
        local font, size, flags = FocusFrameToTTextureFrameName:GetFont()
        if font and size then
            FocusFrameToTTextureFrameName:SetFont(font, math.max(size, 10), flags)
        end
        FocusFrameToTTextureFrameName:SetTextColor(1.0, 0.82, 0.0, 1.0)
        FocusFrameToTTextureFrameName:SetDrawLayer("BORDER", 1) -- Usar BORDER como en ToT
    end

    -- Posicionar textos de estado (Tu código original - CORRECTO)
    if FocusFrameToTTextureFrameDeadText then
        FocusFrameToTTextureFrameDeadText:ClearAllPoints()
        FocusFrameToTTextureFrameDeadText:SetPoint('CENTER', FocusFrameToTHealthBar, 'CENTER', 0, 0)
    end
    if FocusFrameToTTextureFrameUnconsciousText then
        FocusFrameToTTextureFrameUnconsciousText:ClearAllPoints()
        FocusFrameToTTextureFrameUnconsciousText:SetPoint('CENTER', FocusFrameToTHealthBar, 'CENTER', 0, 0)
    end
    if FocusFrameToTDebuff1 then
        FocusFrameToTDebuff1:SetPoint('TOPLEFT', FocusFrameToT, 'TOPRIGHT', 5, -20)
    end

    -- Hook de la barra de vida (Tu código adaptado para usar SetVertexColor)
    FocusFrameToTHealthBar:HookScript('OnValueChanged', function(self)
        if not UnitExists('focustarget') then
            return
        end

        -- Seguridad para mantener la capa correcta
        self:GetStatusBarTexture():SetDrawLayer("BORDER", 5)

        local config =
            addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.fot or {}
        if config.classcolor and UnitIsPlayer('focustarget') then
            local _, englishClass = UnitClass('focustarget')
            if englishClass and RAID_CLASS_COLORS[englishClass] then
                self:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health-Status')
                local color = RAID_CLASS_COLORS[englishClass]
                self:GetStatusBarTexture():SetVertexColor(color.r, color.g, color.b, 1)
            else
                self:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
                self:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
            end
        else
            self:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
            self:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        end

        -- Text Update
        if FocusFrameToTTextureFrameName and UnitExists('focustarget') then
            local name = UnitName('focustarget')
            if name then
                -- Use the same truncation function as for ToT
                local finalText = TruncateToTText(FocusFrameToTTextureFrameName, name, 50)
                FocusFrameToTTextureFrameName:SetText(finalText)
            else
                FocusFrameToTTextureFrameName:SetText("")
            end
        end

    end)

    -- Hook de la barra de maná (Tu código adaptado)
    FocusFrameToTManaBar:HookScript('OnValueChanged', function(self)
        if not UnitExists('focustarget') then
            return
        end

        -- Seguridad para mantener la capa correcta
        self:GetStatusBarTexture():SetDrawLayer("BORDER", 5)
        self:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        unitframe.UpdateFocusToTPowerBarTexture()
    end)

    -- Creación del Tooltip (Tu código original - CORRECTO)
    if not frame.FocusFrameToTTooltip then

        local healthText = FocusFrameToTHealthBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        local font, size, flags = healthText:GetFont()
        if font and size then
            healthText:SetFont(font, size - 1, flags)
        end
        healthText:SetPoint("CENTER", FocusFrameToTHealthBar, "TOP", 0, -4)
        healthText:SetTextColor(1, 1, 1, 1)
        healthText:SetJustifyH("CENTER")
        healthText:Hide()

        local manaText = FocusFrameToTManaBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        local font, size, flags = manaText:GetFont()
        if font and size then
            manaText:SetFont(font, size - 1, flags)
        end
        manaText:SetPoint("CENTER", FocusFrameToTManaBar, "TOP", 1, -4)
        manaText:SetTextColor(1, 1, 1, 1)
        manaText:SetJustifyH("CENTER")
        manaText:Hide()

        frame.FocusFrameToTHealthText = healthText
        frame.FocusFrameToTManaText = manaText

        local function UpdateFocusToTTooltip()
            if not UnitExists('focustarget') then
                frame.FocusFrameToTHealthText:Hide()
                frame.FocusFrameToTManaText:Hide()
                return
            end
            local health = UnitHealth('focustarget') or 0
            local mana = UnitPower('focustarget') or 0
            local healthFormatted = unitframe.FormatFocusToTNumber(health)
            frame.FocusFrameToTHealthText:SetText(healthFormatted)
            local manaFormatted = unitframe.FormatFocusToTNumber(mana)
            frame.FocusFrameToTManaText:SetText(manaFormatted)
        end

        frame.FocusFrameToTUpdateTooltip = UpdateFocusToTTooltip
        frame.FocusFrameToTTooltip = true
    end

    -- Creación de los frames para el ratón (Tu código original - CORRECTO)
    if not frame.FocusFrameToTHealthMouseFrame then
        -- ... (todo tu código de creación de healthMouseFrame, manaMouseFrame y sus scripts se conserva aquí)
        local healthMouseFrame = CreateFrame("Frame", "DragonUIFocusFrameToTHealthMouseFrame", FocusFrameToT)
        healthMouseFrame:SetAllPoints(FocusFrameToTHealthBar)
        healthMouseFrame:SetFrameLevel(FocusFrameToTHealthBar:GetFrameLevel() + 1)
        healthMouseFrame:EnableMouse(true)

        local manaMouseFrame = CreateFrame("Frame", "DragonUIFocusFrameToTManaMouseFrame", FocusFrameToT)
        manaMouseFrame:SetAllPoints(FocusFrameToTManaBar)
        manaMouseFrame:SetFrameLevel(FocusFrameToTManaBar:GetFrameLevel() + 1)
        manaMouseFrame:EnableMouse(true)

        local isUpdating = false
        local updateCounter = 0

        local function OnEnterHandler()
            if UnitExists('focustarget') then
                frame.FocusFrameToTUpdateTooltip()
                frame.FocusFrameToTHealthText:Show()
                frame.FocusFrameToTManaText:Show()
                isUpdating = true
                updateCounter = 0
            end
        end

        local function OnLeaveHandler()
            frame.FocusFrameToTHealthText:Hide()
            frame.FocusFrameToTManaText:Hide()
            isUpdating = false
        end

        healthMouseFrame:SetScript("OnEnter", OnEnterHandler)
        healthMouseFrame:SetScript("OnLeave", OnLeaveHandler)
        manaMouseFrame:SetScript("OnEnter", OnEnterHandler)
        manaMouseFrame:SetScript("OnLeave", OnLeaveHandler)

        healthMouseFrame:SetScript("OnUpdate", function(self, elapsed)
            if isUpdating and UnitExists('focustarget') then
                updateCounter = updateCounter + elapsed
                if updateCounter >= 0.1 then
                    updateCounter = 0
                    frame.FocusFrameToTUpdateTooltip()
                end
            elseif isUpdating then
                frame.FocusFrameToTHealthText:Hide()
                frame.FocusFrameToTManaText:Hide()
                isUpdating = false
            end
        end)

        frame.FocusFrameToTHealthMouseFrame = healthMouseFrame
        frame.FocusFrameToTManaMouseFrame = manaMouseFrame
    end
end

-- FIXED: Unified FoT power bar texture update function
function unitframe.UpdateFocusToTPowerBarTexture()
    if not FocusFrameToTManaBar or not UnitExists('focustarget') then
        return
    end

    local powerType = UnitPowerType('focustarget')
    local texturePath = "Interface\\Addons\\DragonUI\\Textures\\Unitframe\\"

    -- FIXED: Use consistent texture naming without -Status suffix for natural colors
    if powerType == 0 then -- Mana
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana"
    elseif powerType == 1 then -- Rage
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage"
    elseif powerType == 2 then -- Focus
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus"
    elseif powerType == 3 then -- Energy
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy"
    elseif powerType == 6 then -- Runic Power
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower"
    else
        texturePath = texturePath .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana"
    end

    FocusFrameToTManaBar:GetStatusBarTexture():SetTexture(texturePath)
    -- FIXED: Use SetVertexColor since SetStatusBarColor is disabled
    FocusFrameToTManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

end

-- Function to format numbers with k, M suffixes for FoT tooltip
function unitframe.FormatFocusToTNumber(value)
    if not value or value == 0 then
        return "0"
    end

    if value < 1000 then
        return tostring(math.floor(value))
    elseif value < 1000000 then
        if value < 10000 then
            return string.format("%.1fk", value / 1000)
        else
            return string.format("%.0fk", value / 1000)
        end
    else
        return string.format("%.1fM", value / 1000000)
    end
end

function unitframe.UpdateFocusText()

    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    if UnitExists('focus') then
        local max_health = UnitHealthMax('focus')
        local health = UnitHealth('focus')

        -- Use configurable text format for focus
        if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
            local config = addon.db.profile.unitframe.focus or {}
            local textFormat = config.textFormat or "numeric"
            local useBreakup = config.breakUpLargeNumbers -- Don't use 'or false' to preserve nil vs false distinction
            if useBreakup == nil then
                useBreakup = false
            end -- Explicit nil check
            local showHealthAlways = config.showHealthTextAlways or false
            local showManaAlways = config.showManaTextAlways or false

            -- FIXED: Helper function to check if mouse is over a frame
            local function IsMouseOverFrame(frame)
                if not frame then
                    return false
                end
                local mouseX, mouseY = GetCursorPosition()
                local scale = frame:GetEffectiveScale()
                mouseX = mouseX / scale
                mouseY = mouseY / scale

                local left, bottom, width, height = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(),
                    frame:GetHeight()
                if not (left and bottom and width and height) then
                    return false
                end

                local right = left + width
                local top = bottom + height

                return mouseX >= left and mouseX <= right and mouseY >= bottom and mouseY <= top
            end

            -- FIXED: Check if mouse is over focus frames
            local focusHealthHover = IsMouseOverFrame(dragonFrame.FocusFrameHealthBarDummy)
            local focusManaHover = IsMouseOverFrame(dragonFrame.FocusFrameManaBarDummy)

            local formattedHealthText = FormatStatusText(health, max_health, textFormat, useBreakup)

            if textFormat == "both" and type(formattedHealthText) == "table" then
                -- Update dual text elements
                if dragonFrame.FocusFrameHealthBarTextLeft then
                    dragonFrame.FocusFrameHealthBarTextLeft:SetText(formattedHealthText.percentage)
                    if showHealthAlways or focusHealthHover then
                        dragonFrame.FocusFrameHealthBarTextLeft:Show()
                    else
                        dragonFrame.FocusFrameHealthBarTextLeft:Hide()
                    end
                end
                if dragonFrame.FocusFrameHealthBarTextRight then
                    dragonFrame.FocusFrameHealthBarTextRight:SetText(formattedHealthText.current)
                    if showHealthAlways or focusHealthHover then
                        dragonFrame.FocusFrameHealthBarTextRight:Show()
                    else
                        dragonFrame.FocusFrameHealthBarTextRight:Hide()
                    end
                end
                -- Hide single element
                if dragonFrame.FocusFrameHealthBarText then
                    dragonFrame.FocusFrameHealthBarText:Hide()
                end
            else
                -- Update single text element
                local displayText = type(formattedHealthText) == "table" and formattedHealthText.combined or
                                        formattedHealthText
                if dragonFrame.FocusFrameHealthBarText then
                    dragonFrame.FocusFrameHealthBarText:SetText(displayText)
                    if showHealthAlways or focusHealthHover then
                        dragonFrame.FocusFrameHealthBarText:Show()
                    else
                        dragonFrame.FocusFrameHealthBarText:Hide()
                    end
                end
                -- Hide dual elements
                if dragonFrame.FocusFrameHealthBarTextLeft then
                    dragonFrame.FocusFrameHealthBarTextLeft:Hide()
                end
                if dragonFrame.FocusFrameHealthBarTextRight then
                    dragonFrame.FocusFrameHealthBarTextRight:Hide()
                end
            end
        else
            -- Fallback to simple format if config not available
            if dragonFrame.FocusFrameHealthBarText then
                dragonFrame.FocusFrameHealthBarText:SetText(health .. ' / ' .. max_health)
                dragonFrame.FocusFrameHealthBarText:Show()
            end
        end

        local max_mana = UnitPowerMax('focus')
        local mana = UnitPower('focus')

        if max_mana == 0 then
            if dragonFrame.FocusFrameManaBarText then
                dragonFrame.FocusFrameManaBarText:SetText('')
                dragonFrame.FocusFrameManaBarText:Hide()
            end
            if dragonFrame.FocusFrameManaBarTextLeft then
                dragonFrame.FocusFrameManaBarTextLeft:SetText('')
                dragonFrame.FocusFrameManaBarTextLeft:Hide()
            end
            if dragonFrame.FocusFrameManaBarTextRight then
                dragonFrame.FocusFrameManaBarTextRight:SetText('')
                dragonFrame.FocusFrameManaBarTextRight:Hide()
            end
        else
            if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                local config = addon.db.profile.unitframe.focus or {}
                local textFormat = config.textFormat or "numeric"
                local useBreakup = config.breakUpLargeNumbers -- Don't use 'or false' to preserve nil vs false distinction
                if useBreakup == nil then
                    useBreakup = false
                end -- Explicit nil check

                local formattedManaText = FormatStatusText(mana, max_mana, textFormat, useBreakup)

                if textFormat == "both" and type(formattedManaText) == "table" then
                    -- Update dual mana text elements
                    if dragonFrame.FocusFrameManaBarTextLeft then
                        dragonFrame.FocusFrameManaBarTextLeft:SetText(formattedManaText.percentage)
                        if showManaAlways or focusManaHover then
                            dragonFrame.FocusFrameManaBarTextLeft:Show()
                        else
                            dragonFrame.FocusFrameManaBarTextLeft:Hide()
                        end
                    end
                    if dragonFrame.FocusFrameManaBarTextRight then
                        dragonFrame.FocusFrameManaBarTextRight:SetText(formattedManaText.current)
                        if showManaAlways or focusManaHover then
                            dragonFrame.FocusFrameManaBarTextRight:Show()
                        else
                            dragonFrame.FocusFrameManaBarTextRight:Hide()
                        end
                    end
                    -- Hide single element
                    if dragonFrame.FocusFrameManaBarText then
                        dragonFrame.FocusFrameManaBarText:Hide()
                    end
                else
                    -- Update single mana text element
                    local displayText = type(formattedManaText) == "table" and formattedManaText.combined or
                                            formattedManaText
                    if dragonFrame.FocusFrameManaBarText then
                        dragonFrame.FocusFrameManaBarText:SetText(displayText)
                        if showManaAlways or focusManaHover then
                            dragonFrame.FocusFrameManaBarText:Show()
                        else
                            dragonFrame.FocusFrameManaBarText:Hide()
                        end
                    end
                    -- Hide dual elements
                    if dragonFrame.FocusFrameManaBarTextLeft then
                        dragonFrame.FocusFrameManaBarTextLeft:Hide()
                    end
                    if dragonFrame.FocusFrameManaBarTextRight then
                        dragonFrame.FocusFrameManaBarTextRight:Hide()
                    end
                end
            else
                -- Fallback to simple format if config not available
                if dragonFrame.FocusFrameManaBarText then
                    dragonFrame.FocusFrameManaBarText:SetText(mana .. ' / ' .. max_mana)
                    dragonFrame.FocusFrameManaBarText:Show()
                end
            end
        end
    else
        -- Clear text when no focus exists
        if dragonFrame.FocusFrameHealthBarText then
            dragonFrame.FocusFrameHealthBarText:SetText('')
            dragonFrame.FocusFrameHealthBarText:Hide()
        end
        if dragonFrame.FocusFrameHealthBarTextLeft then
            dragonFrame.FocusFrameHealthBarTextLeft:SetText('')
            dragonFrame.FocusFrameHealthBarTextLeft:Hide()
        end
        if dragonFrame.FocusFrameHealthBarTextRight then
            dragonFrame.FocusFrameHealthBarTextRight:SetText('')
            dragonFrame.FocusFrameHealthBarTextRight:Hide()
        end
        if dragonFrame.FocusFrameManaBarText then
            dragonFrame.FocusFrameManaBarText:SetText('')
            dragonFrame.FocusFrameManaBarText:Hide()
        end
        if dragonFrame.FocusFrameManaBarTextLeft then
            dragonFrame.FocusFrameManaBarTextLeft:SetText('')
            dragonFrame.FocusFrameManaBarTextLeft:Hide()
        end
        if dragonFrame.FocusFrameManaBarTextRight then
            dragonFrame.FocusFrameManaBarTextRight:SetText('')
            dragonFrame.FocusFrameManaBarTextRight:Hide()
        end
    end
end

function unitframe.HookFunctions()
    hooksecurefunc(PlayerFrameTexture, 'Show', function()

        unitframe.ChangePlayerframe()
    end)

    -- Essential hooks for player frame text updates
    if PlayerFrameHealthBar and PlayerFrameHealthBar.SetValue then
        hooksecurefunc(PlayerFrameHealthBar, "SetValue", function()
            -- CHANGED: Now calls the correct and safe function.
            unitframe.SafeUpdatePlayerFrameText()
        end)
    end

    if PlayerFrameManaBar and PlayerFrameManaBar.SetValue then
        hooksecurefunc(PlayerFrameManaBar, "SetValue", function()
            -- CHANGED: Now calls the correct and safe function.
            unitframe.SafeUpdatePlayerFrameText()
        end)
    end

    -- Hook to ensure player frame updates on health/mana changes
    if PlayerFrame then
        PlayerFrame:HookScript("OnEvent", function(self, event, unit)
            if (event == "UNIT_HEALTH" or event == "UNIT_POWER_UPDATE") and unit == "player" then
                unitframe.SafeUpdatePlayerFrameText()
            end
        end)
    end
end

-- ====================================================================
-- ██████╗  █████╗ ██████╗ ████████╗██╗   ██╗    ███████╗██████╗  █████╗ ███╗   ███╗███████╗███████╗
-- ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝╚██╗ ██╔╝    ██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝██╔════╝
-- ██████╔╝███████║██████╔╝   ██║    ╚████╔╝     █████╗  ██████╔╝███████║██╔████╔██║█████╗  ███████╗
-- ██╔═══╝ ██╔══██║██╔══██╗   ██║     ╚██╔╝      ██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝  ╚════██║
-- ██║     ██║  ██║██║  ██║   ██║      ██║       ██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗███████║
-- ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝       ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝
-- ====================================================================
-- START OF PARTY FRAMES MODULE
-- This section contains all functions and logic related to Party Frames
-- ====================================================================

-- MOVED: Party frames initialization system
if not unitframe.PartyEventFrameMain then
    local partyMainEventFrame = CreateFrame('Frame')
    partyMainEventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
    partyMainEventFrame:SetScript('OnEvent', function(self, event, ...)
        if event == 'PLAYER_ENTERING_WORLD' then
            --  CRÍTICO: Forzar inicialización de party frames en primer login
            if not unitframe.PartyMoveFrame then
                unitframe.ChangePartyFrame()
            end
        end
    end)
    unitframe.PartyEventFrameMain = partyMainEventFrame
end

-- Party frame options 
local optionsParty = CreateUnitFrameOptions('Party', 'Party frame settings', 'party')

-- Party frames need additional layout options not required by individual unit frames
optionsParty.args.showHealthTextAlways = {
    type = 'toggle',
    name = 'Always Show Health Text',
    desc = 'Always display health text (otherwise only on mouseover)',
    order = 15.3
}
optionsParty.args.showManaTextAlways = {
    type = 'toggle',
    name = 'Always Show Mana Text',
    desc = 'Always display mana/energy/rage text (otherwise only on mouseover)',
    order = 15.4
}
optionsParty.args.configLayout = {
    type = 'header',
    name = 'Layout',
    order = 40
}
optionsParty.args.orientation = {
    type = 'select',
    name = 'Orientation',
    desc = 'Party frame orientation',
    values = {
        ['vertical'] = 'Vertical',
        ['horizontal'] = 'Horizontal'
    },
    order = 40.1
}
optionsParty.args.padding = {
    type = 'range',
    name = 'Padding',
    desc = 'Space between party frames',
    min = 0,
    max = 50,
    step = 1,
    order = 40.2
}

-- MOVED: Safe party detection function (avoids taint)
local function GetPartyFrameType(current)
    -- Only check if we actually have party members to avoid unnecessary loops
    if GetNumPartyMembers() == 0 then
        return nil
    end
    
    for i = 1, 4 do
        if UnitExists("party" .. i) then
            local partyHealth = UnitHealth("party" .. i)
            if current == partyHealth and partyHealth > 0 then
                return "party"
            end
        end
    end
    return nil
end



-- Function to reconfigure party frames on reload without recreating them
function unitframe.ReconfigurePartyFramesForReload()

    -- Only reconfigure if PartyMoveFrame exists (frames are already initialized)
    if not unitframe.PartyMoveFrame then

        unitframe.ChangePartyFrame()
        return
    end

    -- CRITICAL: Add delay to allow party frames to fully settle after reload
    local delayFrame = CreateFrame("Frame")
    local delayTime = 0
    delayFrame:SetScript("OnUpdate", function(self, elapsed)
        delayTime = delayTime + elapsed
        if delayTime >= 0.1 then -- Wait 100ms for frames to fully initialize
            self:SetScript("OnUpdate", nil)
            unitframe.DoPartyFrameReconfiguration()
        end
    end)
end

-- Separate function for the actual reconfiguration
function unitframe.DoPartyFrameReconfiguration()
    -- For each party frame, reapply class color settings without touching frame structure
    for i = 1, 4 do
        local pf = _G['PartyMemberFrame' .. i]
        local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']

        if pf and healthbar and UnitExists('party' .. i) then
            local settings = addon:GetConfigValue("unitframe", "party") or {}

            if settings.classcolor then
                local _, class = UnitClass('party' .. i)
                if class and RAID_CLASS_COLORS[class] then
                    -- Apply class color texture and color (EXACTLY like the hooks do)
                    healthbar:SetStatusBarTexture(
                        'Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status')
                    local color = RAID_CLASS_COLORS[class]
                    healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
                else
                    -- Fallback to normal texture for unknown classes
                    healthbar:SetStatusBarTexture(
                        'Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health')
                    healthbar:SetStatusBarColor(1, 1, 1, 1)
                end
            else
                -- Class colors disabled, use coordinate-based system
                healthbar:SetStatusBarTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')
                healthbar:SetStatusBarColor(1, 1, 1, 1)
                unitframe.SetPartyHealthBarCoords(healthbar)
            end
        end
    end
end


-- ====================================================================
-- REFACTORED PARTY FRAMES SYSTEM
-- Divided into smaller, manageable functions for better maintainability
-- ====================================================================

-- Main coordinator function
function unitframe.ChangePartyFrame()
    unitframe.CreatePartyContainer()
    unitframe.SetupAllPartyFrames()
    unitframe.RegisterPartyEvents()
end

-- Creates the main container frame for party frames
function unitframe.CreatePartyContainer()
    -- Create main container frame for party frames
    local PartyMoveFrame = CreateFrame('Frame', 'DragonUIPartyMoveFrame', UIParent)
    -- FIXED: Use BACKGROUND strata to stay behind Compact Raid Frames which use LOW/MEDIUM
    -- This prevents our party frames from appearing over raid frames
    PartyMoveFrame:SetFrameStrata('BACKGROUND')
    -- FIXED: Use lower frame level to ensure compatibility with other addons
    PartyMoveFrame:SetFrameLevel(1)
    PartyMoveFrame:Show() -- Force show
    unitframe.PartyMoveFrame = PartyMoveFrame

    -- Reparent original frames to our container
    for i = 1, 4 do
        local originalFrame = _G['PartyMemberFrame' .. i]
        if originalFrame then
            -- Desanclar de posición original
            originalFrame:SetMovable(true)
            originalFrame:ClearAllPoints()
            -- Reparentar a nuestro contenedor para control completo
            originalFrame:SetParent(PartyMoveFrame)
            originalFrame:SetMovable(false)
        end
    end

    -- Calculate container size and position first party frame
    local sizeX, sizeY = _G['PartyMemberFrame1']:GetSize()
    local gap = 10
    PartyMoveFrame:SetSize(sizeX, sizeY * 4 + 3 * gap)

    -- Position first party frame
    local first = _G['PartyMemberFrame1']
    first:ClearAllPoints()
    first:SetPoint('TOPLEFT', PartyMoveFrame, 'TOPLEFT', 0, 0)
end

-- Sets up all 4 party frames
function unitframe.SetupAllPartyFrames()
    for i = 1, 4 do
        unitframe.SetupSinglePartyFrame(i)
    end
end

-- Configures a single party frame completely
function unitframe.SetupSinglePartyFrame(i)
    unitframe.ConfigurePartyFrameStructure(i)
    unitframe.SetupPartyFrameTextures(i)
    unitframe.SetupPartyFrameBars(i)
    unitframe.SetupPartyFrameEvents(i)
    unitframe.SetupPartyFrameIcons(i)
    unitframe.SetupPartyFrameRange(i)
    unitframe.InitializePartyFrameBars(i)
end

-- Configures basic frame structure (size, position, parent)
function unitframe.ConfigurePartyFrameStructure(i)
    local pf = _G['PartyMemberFrame' .. i]
    if not pf then return end
	pf.unit = "party"..i
    
    pf:SetParent(unitframe.PartyMoveFrame)
    pf:SetSize(120, 53)
    pf:SetHitRectInsets(0, 0, 0, 12)
    -- DO NOT force Show() - let WoW control visibility
    -- pf:Show() -- Comentado - causa frames fantasma
    -- pf:SetAlpha(1) -- Comentado - dejar que WoW controle

    -- Hide original background
    local bg = _G['PartyMemberFrame' .. i .. 'Background']
    if bg then
        bg:Hide()
    end

    -- Hide original texture
    local texture = _G['PartyMemberFrame' .. i .. 'Texture']
    if texture then
        texture:SetTexture()
        texture:Hide()
    end

    -- Reposition name
    local name = _G['PartyMemberFrame' .. i .. 'Name']
    if name then
        name:ClearAllPoints()
        name:SetSize(57, 12)
        name:SetPoint('TOPLEFT', 46, -6)
    end

    -- Position debuffs - IMPROVED: Handle all debuffs, not just first one
    for debuffIndex = 1, 16 do -- Party frames can show up to 16 debuffs
        local debuff = _G['PartyMemberFrame' .. i .. 'Debuff' .. debuffIndex]
        if debuff then
            debuff:ClearAllPoints()
            -- Calculate position: first debuff at base position, others offset
            local xOffset = 120 + ((debuffIndex - 1) % 8) * 17 -- 8 debuffs per row
            local yOffset = -20 - (math.floor((debuffIndex - 1) / 8) * 17) -- Second row if >8 debuffs
            debuff:SetPoint('TOPLEFT', pf, 'TOPLEFT', xOffset, yOffset)
        end
    end
end

-- Sets up all party frame textures (border, flash, status)
function unitframe.SetupPartyFrameTextures(i)
    local pf = _G['PartyMemberFrame' .. i]
    if not pf then return end

    -- Setup flash texture
    local flash = _G['PartyMemberFrame' .. i .. 'Flash']
    if flash then
        flash:SetSize(114, 47)
        flash:SetTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')
        flash:SetTexCoord(0.480469, 0.925781, 0.453125, 0.636719)
        flash:SetPoint('TOPLEFT', 1 + 1, -2)
        flash:SetVertexColor(1, 0, 0, 1)
        flash:SetDrawLayer('ARTWORK', 5)
    end

    -- Create border texture
    if not pf.PartyFrameBorder then
        local border = pf:CreateTexture('DragonUIPartyFrameBorder')
        -- FIXED: Use BORDER layer as per WoW 3.3.5a documentation
        border:SetDrawLayer('BORDER', 1)
        border:SetSize(120, 49)
        border:SetTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')
        border:SetTexCoord(0.480469, 0.949219, 0.222656, 0.414062)
        border:SetPoint('TOPLEFT', 1, -2)
        pf.PartyFrameBorder = border
    end

    -- Setup status texture
    local status = _G['PartyMemberFrame' .. i .. 'Status']
    if status then
        status:SetSize(114, 47)
        status:SetTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')
        status:SetTexCoord(0.00390625, 0.472656, 0.453125, 0.644531)
        status:SetPoint('TOPLEFT', 1, -2)
        status:SetDrawLayer('BORDER', 1)
    end
end

-- Configures health and mana bars
function unitframe.SetupPartyFrameBars(i)
    unitframe.SetupPartyHealthBar(i)
    unitframe.SetupPartyManaBar(i)
end

-- Sets up health bar specifically
function unitframe.SetupPartyHealthBar(i)
    local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
    if not healthbar then return end

    healthbar:SetSize(70 + 1, 10)
    healthbar:ClearAllPoints()
    healthbar:SetPoint('TOPLEFT', 45 - 1, -19)

    -- FIXED: Set frame level to be above border layer but not excessively high
    -- This prevents conflicts with other addons while maintaining proper layering
    healthbar:SetFrameLevel(3)

    -- Use individual texture files instead of uipartyframe.blp for better class color support
    healthbar:SetStatusBarTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health')
    healthbar:SetStatusBarColor(1, 1, 1, 1)

    -- Completely disable the original WoW text system
    if healthbar.TextString then
        healthbar.TextString:Hide()
        healthbar.TextString:SetText("")
    end
    -- Desactivar también el cvar que controla el texto automático
    healthbar.cvar = nil
    healthbar.textLockable = 0
    healthbar.lockShow = 0

    -- Crear nuestros elementos de texto personalizados
    healthbar.DFTextString = healthbar.DFHealthBarText or
                                 healthbar:CreateFontString('DragonUIHealthBarText', 'OVERLAY', 'TextStatusBarText')
    healthbar.DFLeftText = healthbar.DFHealthBarTextLeft or
                               healthbar:CreateFontString('DragonUIHealthBarTextLeft', 'OVERLAY', 'TextStatusBarText')
    healthbar.DFRightText = healthbar.DFHealthBarTextRight or
                                healthbar:CreateFontString('DragonUIHealthBarTextRight', 'OVERLAY', 'TextStatusBarText')

    -- Posicionar correctamente en la barra de vida
    healthbar.DFTextString:SetPoint('CENTER', healthbar, 'CENTER', 0, 0)
    healthbar.DFLeftText:SetPoint('LEFT', healthbar, 'LEFT', 0, 0)
    healthbar.DFRightText:SetPoint('RIGHT', healthbar, 'RIGHT', 0, 0)
end

-- Sets up mana bar specifically
function unitframe.SetupPartyManaBar(i)
    local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']
    if not manabar then return end

    manabar:SetSize(74, 7)
    manabar:ClearAllPoints()
    manabar:SetPoint('TOPLEFT', 41, -30)

    -- FIXED: Set frame level consistent with health bar
    manabar:SetFrameLevel(3)

    -- Use uipartyframe.blp with coordinates for mana bar (3.3.5a compatible)
    manabar:SetStatusBarTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')

    -- Default mana bar coordinates - will be updated based on power type
    unitframe.SetPartyManaBarCoords(manabar, 0, 1000, 1000) -- 0 = mana, default values for initialization
    manabar:SetStatusBarColor(1, 1, 1, 1)

    -- DESACTIVAR completamente el sistema de texto original de WoW
    if manabar.TextString then
        manabar.TextString:Hide()
        manabar.TextString:SetText("")
    end
    -- Desactivar también el cvar que controla el texto automático
    manabar.cvar = nil
    manabar.textLockable = 0
    manabar.lockShow = 0

    -- Crear nuestros elementos de texto personalizados
    manabar.DFTextString = manabar.DFManaBarText or
                               manabar:CreateFontString('DragonUIManaBarText', 'OVERLAY', 'TextStatusBarText')
    manabar.DFLeftText = manabar.DFManaBarTextLeft or
                             manabar:CreateFontString('DragonUIManaBarTextLeft', 'OVERLAY', 'TextStatusBarText')
    manabar.DFRightText = manabar.DFManaBarTextRight or
                              manabar:CreateFontString('DragonUIManaBarTextRight', 'OVERLAY', 'TextStatusBarText')

    -- Posicionar correctamente en la barra de mana
    manabar.DFTextString:SetPoint('CENTER', manabar, 'CENTER', 1.5, 0)
    manabar.DFLeftText:SetPoint('LEFT', manabar, 'LEFT', 3, 0)
    manabar.DFRightText:SetPoint('RIGHT', manabar, 'RIGHT', 0, 0)
end

-- Sets up party frame icons (leader, master, pvp, etc.)
function unitframe.SetupPartyFrameIcons(i)
    local pf = _G['PartyMemberFrame' .. i]
    if not pf then return end

    -- Setup small icons positioning
    local function updateSmallIcons()
        local leaderIcon = _G['PartyMemberFrame' .. i .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('BOTTOM', pf, 'TOP', -10, -6)
            leaderIcon:SetSize(16, 16)
        end

        local masterIcon = _G['PartyMemberFrame' .. i .. 'MasterIcon']
        if masterIcon then
            masterIcon:ClearAllPoints()
            masterIcon:SetPoint('BOTTOM', pf, 'TOP', -10 + 16, -6)
        end

        local guideIcon = _G['PartyMemberFrame' .. i .. 'GuideIcon']
        if guideIcon then
            guideIcon:ClearAllPoints()
            guideIcon:SetPoint('BOTTOM', pf, 'TOP', -10, -6)
        end

        local pvpIcon = _G['PartyMemberFrame' .. i .. 'PVPIcon']
        if pvpIcon then
            pvpIcon:ClearAllPoints()
            pvpIcon:SetPoint('CENTER', pf, 'TOPLEFT', 7, -24)
        end

        local readyCheck = _G['PartyMemberFrame' .. i .. 'ReadyCheck']
        if readyCheck then
            readyCheck:ClearAllPoints()
            readyCheck:SetPoint('CENTER', _G['PartyMemberFrame' .. i .. 'Portrait'], 'CENTER', 0, -2)
        end

        local notPresentIcon = _G['PartyMemberFrame' .. i .. 'NotPresentIcon']
        if notPresentIcon then
            notPresentIcon:ClearAllPoints()
            notPresentIcon:SetPoint('LEFT', pf, 'RIGHT', 2, -2)
        end
    end
    
    updateSmallIcons()
    pf.updateSmallIcons = updateSmallIcons -- Store the function for later use
end

-- Sets up range checking for party frames
function unitframe.SetupPartyFrameRange(i)
    local pf = _G['PartyMemberFrame' .. i]
    if not pf then return end

    -- Range checking
    local function updateRange()
        if UnitInRange then
            local inRange, checkedRange = UnitInRange('party' .. i)
            if checkedRange and not inRange then
                pf:SetAlpha(0.55)
                -- FIXED: Ensure health bar stays fully opaque even when frame is dimmed
                if pf.PartyFrameHealthBar then
                    pf.PartyFrameHealthBar:SetAlpha(1.0)
                    pf.PartyFrameHealthBar:SetVertexColor(1, 1, 1)
                end
            else
                pf:SetAlpha(1)
                -- FIXED: Ensure health bar is fully opaque and bright
                if pf.PartyFrameHealthBar then
                    pf.PartyFrameHealthBar:SetAlpha(1.0)
                    pf.PartyFrameHealthBar:SetVertexColor(1, 1, 1)
                end
            end
        else
            -- Fallback for 3.3.5a - always show at full alpha
            pf:SetAlpha(1)
        end
    end

    pf:HookScript('OnUpdate', updateRange)
    pf.updateRange = updateRange
end

-- Sets up all event handling for a party frame
function unitframe.SetupPartyFrameEvents(i)
    local pf = _G['PartyMemberFrame' .. i]
    if not pf then return end
    
    local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
    local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']

    -- Additional event handling for visual updates
    pf:HookScript('OnShow', function(self)
        -- SIMPLIFIED: Just hide original texture, don't change layers
        local texture = _G['PartyMemberFrame' .. i .. 'Texture']
        if texture then
            texture:SetTexture()
            texture:Hide()
        end
        if healthbar then
            healthbar:SetStatusBarColor(1, 1, 1, 1)
        end
        if pf.updateSmallIcons then
            pf.updateSmallIcons()
        end
        -- updateRange call
        if pf.updateRange then
            pf.updateRange()
        end
    end)

    -- Hook party frame events for automatic updates
    pf:RegisterEvent('PARTY_MEMBER_CHANGED')
    pf:RegisterEvent('UNIT_HEALTH')
    pf:RegisterEvent('UNIT_POWER_UPDATE')
    pf:RegisterEvent('UNIT_MAXHEALTH')
    pf:RegisterEvent('UNIT_MAXPOWER')
    pf:RegisterEvent('UNIT_DISPLAYPOWER')

    -- Hook mana bar value changes to update texture coordinates AND text
    if manabar then
        manabar:HookScript('OnValueChanged', function(self, value)
            unitframe.SetPartyManaBarCoords(self, 0) -- Actualizar coordenadas cuando cambie el valor
            -- ✅ FIX: También actualizar texto inmediatamente
            if UnitExists('party' .. i) then
                unitframe.UpdatePartyFrameText(i)
            end
        end)
    end

    -- Hook health bar value changes to maintain class colors and texture switching
    if healthbar then
        healthbar:HookScript('OnValueChanged', function(self, value)
            if not UnitExists('party' .. i) then
                return
            end

            -- SIMPLIFIED: Just handle class colors, don't touch layers or frame levels
            local settings = addon:GetConfigValue("unitframe", "party") or {}

            if settings.classcolor then
                local _, class = UnitClass('party' .. i)
                if class and RAID_CLASS_COLORS[class] then
                    -- Use individual -Status texture for class colors
                    self:SetStatusBarTexture(
                        'Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status')

                    local color = RAID_CLASS_COLORS[class]
                    self:SetStatusBarColor(color.r, color.g, color.b, 1)
                end
            end
        end)
    end

    -- Hook the original OnEvent to update our custom elements
    local originalOnEvent = pf:GetScript('OnEvent')
    pf:SetScript('OnEvent', function(self, event, ...)
        if originalOnEvent then
            originalOnEvent(self, event, ...)
        end

        -- Update our custom bars when relevant events fire (with combat protection)
        if event == 'UNIT_HEALTH' or event == 'UNIT_MAXHEALTH' or event == 'PARTY_MEMBER_CHANGED' then
            local unit = ...
            if unit == 'party' .. i then
                if not InCombatLockdown() and not UnitAffectingCombat('player') then
                    unitframe.UpdatePartyHPBar(i)
                else
                    -- Queue update for after combat
                    unitframe.QueuePartyUpdate(i, 'health')
                end
            end
        elseif event == 'UNIT_POWER_UPDATE' or event == 'UNIT_MAXPOWER' or event == 'UNIT_DISPLAYPOWER' then
            local unit = ...
            if unit == 'party' .. i then
                if not InCombatLockdown() and not UnitAffectingCombat('player') then
                    unitframe.UpdatePartyManaBar(i)
                else
                    -- Queue update for after combat
                    unitframe.QueuePartyUpdate(i, 'mana')
                end
            end
        end
    end)
end

-- Initialize bars for existing party members
function unitframe.InitializePartyFrameBars(i)
    -- Initialize bars solo si hay un miembro real
    if UnitExists('party' .. i) then
        unitframe.UpdatePartyHPBar(i)
        unitframe.UpdatePartyManaBar(i)
    end

    -- FIXED: Set frame levels ONCE during initialization, not on every update
    unitframe.EnsurePartyFrameLayerOrder(i)
end

-- Registers global party events
function unitframe.RegisterPartyEvents()
    -- Register global events for party changes
    if not unitframe.PartyEventFrame then
        local eventFrame = CreateFrame('Frame')
        eventFrame:RegisterEvent('PARTY_MEMBERS_CHANGED')
        eventFrame:RegisterEvent('PARTY_MEMBER_ENABLE')
        eventFrame:RegisterEvent('PARTY_MEMBER_DISABLE')
        eventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
        -- FIXED: Add raid detection to handle Compact Raid Frames conflicts
        eventFrame:RegisterEvent('RAID_ROSTER_UPDATE')
        eventFrame:RegisterEvent('PARTY_CONVERTED_TO_RAID')
        eventFrame:SetScript('OnEvent', function(self, event, ...)
            -- FIXED: Only update if we actually have party members or the event affects existing members
            if event == 'PLAYER_ENTERING_WORLD' then
                -- Always update on entering world
            elseif event == 'RAID_ROSTER_UPDATE' or event == 'PARTY_CONVERTED_TO_RAID' then
                -- FIXED: Hide our party frames when in raid mode to avoid conflicts with Compact Raid Frames
                if GetNumRaidMembers() > 0 then
                    if unitframe.PartyMoveFrame then
                        unitframe.PartyMoveFrame:Hide()
                    end
                    return -- Don't update party frames in raid mode
                else
                    if unitframe.PartyMoveFrame then
                        unitframe.PartyMoveFrame:Show()
                    end
                end
            elseif event == 'PARTY_MEMBERS_CHANGED' or event == 'PARTY_MEMBER_ENABLE' or event == 'PARTY_MEMBER_DISABLE' then
                -- Only update if we actually have party members
                local hasPartyMembers = false
                for i = 1, 4 do
                    if UnitExists('party' .. i) then
                        hasPartyMembers = true
                        break
                    end
                end

                -- Skip update if no party members (someone just declined invitation)
                if not hasPartyMembers then
                    return
                end
            end

            -- FIXED: Use WoW 3.3.5a compatible timer instead of C_Timer.After
            local updateFrame = CreateFrame("Frame")
            local updateTime = 0
            updateFrame:SetScript("OnUpdate", function(self, elapsed)
                updateTime = updateTime + elapsed
                if updateTime >= 0.1 then -- Wait 0.1 seconds
                    -- Update all party frames when party composition changes
                    for i = 1, 4 do
                        local pf = _G['PartyMemberFrame' .. i]
                        if pf then
                            -- Only update if not in combat
                            if not InCombatLockdown() and not UnitAffectingCombat('player') then
                                unitframe.UpdatePartyHPBar(i)
                                unitframe.UpdatePartyManaBar(i)

                                -- Re-run the icon positioning logic on every group update
                                local updateSmallIcons = pf.updateSmallIcons
                                if updateSmallIcons then
                                    updateSmallIcons()
                                end
                            else
                                -- Queue for after combat
                                unitframe.QueuePartyUpdate(i, 'health')
                                unitframe.QueuePartyUpdate(i, 'mana')
                            end
                        end
                    end

                    -- FIXED: Update party frame text for all party members safely
                    unitframe.UpdateAllPartyFrameText()

                    -- Stop the timer
                    updateFrame:SetScript("OnUpdate", nil)
                end
            end)
        end)
        unitframe.PartyEventFrame = eventFrame
    end
end
-- END OF REFACTORING


-- Function to update party state (position, scale, orientation)
function unitframe:UpdatePartyState(state)
    if not unitframe.PartyMoveFrame then
        return
    end

    -- ✅ CORRECCIÓN: Lógica de carga robusta que respeta el 'override'.
    local partyConfig = addon:GetConfigValue("unitframe", "party") or {}

    -- Determinar los valores a usar basados en el override.
    local anchor, parent, anchorPoint, x, y
    if partyConfig.override then
        anchor = partyConfig.anchor or "BOTTOMLEFT"
        -- Usamos _G para obtener el frame por su nombre, con fallback a UIParent
        parent = _G[partyConfig.anchorParent or "UIParent"] or UIParent
        anchorPoint = partyConfig.anchorPoint or "BOTTOMLEFT"
        x = partyConfig.x or 0
        y = partyConfig.y or 0
    else
        -- Valores por defecto si no hay override (posición inicial)
        anchor = "TOPLEFT"
        parent = UIParent
        anchorPoint = "TOPLEFT"
        x = 20
        y = -120
    end

    -- Valores que no dependen del override (escala, padding, etc.)
    local scale = partyConfig.scale or 1.0
    local padding = partyConfig.padding or 10
    local orientation = partyConfig.orientation or 'vertical'

    -- Aplicar la posición y escala.
    unitframe.PartyMoveFrame:ClearAllPoints()
    unitframe.PartyMoveFrame:SetPoint(anchor, parent, anchorPoint, x, y)
    unitframe.PartyMoveFrame:SetScale(scale)

    -- El resto de la lógica para la orientación y el tamaño se mantiene.
    local sizeX, sizeY = _G['PartyMemberFrame' .. 1]:GetSize()

    if orientation == 'vertical' then
        unitframe.PartyMoveFrame:SetSize(sizeX, sizeY * 4 + 3 * padding)
    else
        unitframe.PartyMoveFrame:SetSize(sizeX * 4 + 3 * padding, sizeY)
    end

    for i = 2, 4 do
        local pf = _G['PartyMemberFrame' .. i]
        if orientation == 'vertical' then
            pf:ClearAllPoints()
            pf:SetPoint('TOPLEFT', _G['PartyMemberFrame' .. (i - 1)], 'BOTTOMLEFT', 0, -padding)
        else
            pf:ClearAllPoints()
            pf:SetPoint('TOPLEFT', _G['PartyMemberFrame' .. (i - 1)], 'TOPRIGHT', padding, 0)
        end
    end

    -- Actualizar las barras de los miembros del grupo.
    for i = 1, 4 do
        if UnitExists("party" .. i) then
            unitframe.UpdatePartyHPBar(i)
            unitframe.UpdatePartyManaBar(i)
        end
    end
end

-- Function to initialize party frame mouseover scripts
function unitframe.InitializePartyFrameMouseover()
    for i = 1, 4 do
        local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
        local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']

        if healthbar and not healthbar.DFMouseoverSet then
            healthbar:SetScript("OnEnter", function()
                unitframe.UpdatePartyFrameText(i)
            end)
            healthbar:SetScript("OnLeave", function()
                unitframe.UpdatePartyFrameText(i)
            end)
            healthbar.DFMouseoverSet = true
        end

        if manabar and not manabar.DFMouseoverSet then
            manabar:SetScript("OnEnter", function()
                unitframe.UpdatePartyFrameText(i)
            end)
            manabar:SetScript("OnLeave", function()
                unitframe.UpdatePartyFrameText(i)
            end)
            manabar.DFMouseoverSet = true
        end
    end
end

-- FIXED: Helper function to update text for all party frames safely
function unitframe.UpdateAllPartyFrameText()
    for i = 1, 4 do
        unitframe.UpdatePartyFrameText(i)
    end
end

-- Clear party frame texts
function unitframe.ClearPartyFrameTexts(i)
    local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
    local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']

    if healthbar then
        if healthbar.DFTextString then
            healthbar.DFTextString:Hide()
        end
        if healthbar.DFLeftText then
            healthbar.DFLeftText:Hide()
        end
        if healthbar.DFRightText then
            healthbar.DFRightText:Hide()
        end
    end

    if manabar then
        if manabar.DFTextString then
            manabar.DFTextString:Hide()
        end
        if manabar.DFLeftText then
            manabar.DFLeftText:Hide()
        end
        if manabar.DFRightText then
            manabar.DFRightText:Hide()
        end
    end
end

function unitframe.UpdatePartyFrameText(i)
    -- Verificaciones como en target/pet
    if not i or type(i) ~= "number" or i < 1 or i > 4 then
        return
    end

    -- Verificar estado de la unidad
    if not UnitExists('party' .. i) or UnitIsDeadOrGhost('party' .. i) then
        unitframe.ClearPartyFrameTexts(i)
        return
    end

    -- Verificar conexión
    if UnitIsPlayer('party' .. i) and UnitIsConnected and not UnitIsConnected('party' .. i) then
        unitframe.ClearPartyFrameTexts(i)
        return
    end

    local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
    local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']

    if not healthbar or not manabar then
        return
    end

    -- TAINT-FIX: Usar la caché segura
    local config = safeConfig.party or {}
    local showHealthAlways = config.showHealthTextAlways or false
    local showManaAlways = config.showManaTextAlways or false
    local textFormat = config.textFormat or "both"
    local useBreakup = config.breakUpLargeNumbers or false

    -- Helper function to check mouseover (compatible with 3.3.5a)
    local function IsMouseOverBar(bar)
        if not bar then
            return false
        end
        local success, isOver = pcall(function()
            return bar:IsMouseOver()
        end)
        return success and isOver
    end

    -- Create DFLeftText and DFRightText if they don't exist (for 'both' format)
    if not healthbar.DFLeftText then
        healthbar.DFLeftText = healthbar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        healthbar.DFLeftText:SetPoint("LEFT", healthbar, "LEFT", 2, 0)
        healthbar.DFLeftText:SetJustifyH("LEFT")
    end
    if not healthbar.DFRightText then
        healthbar.DFRightText = healthbar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        healthbar.DFRightText:SetPoint("RIGHT", healthbar, "RIGHT", -2, 0)
        healthbar.DFRightText:SetJustifyH("RIGHT")
    end
    if not manabar.DFLeftText then
        manabar.DFLeftText = manabar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manabar.DFLeftText:SetPoint("LEFT", manabar, "LEFT", 2, 0)
        manabar.DFLeftText:SetJustifyH("LEFT")
    end
    if not manabar.DFRightText then
        manabar.DFRightText = manabar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manabar.DFRightText:SetPoint("RIGHT", manabar, "RIGHT", -2, 0)
        manabar.DFRightText:SetJustifyH("RIGHT")
    end

    -- Health text logic - CORREGIDO
    if healthbar.DFTextString then
        local health = UnitHealth('party' .. i)
        local maxHealth = UnitHealthMax('party' .. i)

        local showHealthText = showHealthAlways or IsMouseOverBar(healthbar)

        if showHealthText and health and maxHealth and maxHealth > 0 then
            local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup)

            if textFormat == 'both' and type(healthText) == 'table' then
                -- ✅ Para formato "both": usar elementos izquierda/derecha, OCULTAR el principal
                healthbar.DFTextString:SetText("")
                healthbar.DFTextString:Hide() -- ← AÑADIDO: Ocultar elemento principal
                healthbar.DFLeftText:SetText(healthText.percentage)
                healthbar.DFRightText:SetText(healthText.current)
                healthbar.DFLeftText:Show()
                healthbar.DFRightText:Show()
            else
                -- ✅ Para otros formatos: usar elemento principal, OCULTAR izquierda/derecha
                healthbar.DFTextString:SetText(healthText)
                healthbar.DFTextString:Show() -- ← MOVIDO: Solo mostrar cuando se usa
                healthbar.DFLeftText:SetText("")
                healthbar.DFLeftText:Hide() -- ← AÑADIDO: Ocultar elementos duales
                healthbar.DFRightText:SetText("")
                healthbar.DFRightText:Hide() -- ← AÑADIDO: Ocultar elementos duales
            end
        else
            -- ✅ Ocultar TODOS los elementos cuando no hay texto
            healthbar.DFTextString:SetText("")
            healthbar.DFTextString:Hide()
            healthbar.DFLeftText:SetText("")
            healthbar.DFLeftText:Hide()
            healthbar.DFRightText:SetText("")
            healthbar.DFRightText:Hide()
        end
    end

    -- Mana text logic - CORREGIDO
    if manabar.DFTextString then
        local power = UnitPower('party' .. i)
        local maxPower = UnitPowerMax('party' .. i)

        local showManaText = showManaAlways or IsMouseOverBar(manabar)

        if showManaText and power and maxPower and maxPower > 0 then
            local powerText = FormatStatusText(power, maxPower, textFormat, useBreakup)

            if textFormat == 'both' and type(powerText) == 'table' then
                -- ✅ Para formato "both": usar elementos izquierda/derecha, OCULTAR el principal
                manabar.DFTextString:SetText("")
                manabar.DFTextString:Hide() -- ← AÑADIDO: Ocultar elemento principal
                manabar.DFLeftText:SetText(powerText.percentage)
                manabar.DFRightText:SetText(powerText.current)
                manabar.DFLeftText:Show()
                manabar.DFRightText:Show()
            else
                -- ✅ Para otros formatos: usar elemento principal, OCULTAR izquierda/derecha
                manabar.DFTextString:SetText(powerText)
                manabar.DFTextString:Show() -- ← MOVIDO: Solo mostrar cuando se usa
                manabar.DFLeftText:SetText("")
                manabar.DFLeftText:Hide() -- ← AÑADIDO: Ocultar elementos duales
                manabar.DFRightText:SetText("")
                manabar.DFRightText:Hide() -- ← AÑADIDO: Ocultar elementos duales
            end
        else
            -- ✅ Ocultar TODOS los elementos cuando no hay texto
            manabar.DFTextString:SetText("")
            manabar.DFTextString:Hide()
            manabar.DFLeftText:SetText("")
            manabar.DFLeftText:Hide()
            manabar.DFRightText:SetText("")
            manabar.DFRightText:Hide()
        end
    end
end

-- FIXED: Comprehensive function to refresh all party frames (called from options)
-- CRITICAL: Party frame update queue system to handle combat lockdown
unitframe.partyUpdateQueue = {}

function unitframe.QueuePartyUpdate(index, updateType)
    if not unitframe.partyUpdateQueue[index] then
        unitframe.partyUpdateQueue[index] = {}
    end
    unitframe.partyUpdateQueue[index][updateType] = true

    -- Register for combat end if not already registered
    if not unitframe.combatEndFrame then
        unitframe.combatEndFrame = CreateFrame("Frame")
        unitframe.combatEndFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        unitframe.combatEndFrame:SetScript("OnEvent", function()
            unitframe.ProcessPartyUpdateQueue()
        end)

        -- The automatic layer monitoring system was too aggressive and caused more problems than it solved
        -- Let WoW handle its own natural layer system
    end
end

function unitframe.ProcessPartyUpdateQueue()
    if InCombatLockdown() or UnitAffectingCombat('player') then
        return -- Still in combat, wait more
    end

    for index, updates in pairs(unitframe.partyUpdateQueue) do
        if updates.health then
            unitframe.UpdatePartyHPBar(index)
        end
        if updates.mana then
            unitframe.UpdatePartyManaBar(index)
        end
        -- SIMPLIFIED: Don't call EnsurePartyFrameLayerOrder here - it was causing repositioning
    end

    -- Clear queue
    unitframe.partyUpdateQueue = {}
end

-- CRITICAL: Function to ensure proper layer ordering for party frames
function unitframe.EnsurePartyFrameLayerOrder(index)
    if InCombatLockdown() or UnitAffectingCombat('player') then
        return
    end

    local pf = _G['PartyMemberFrame' .. index]
    if not pf then
        return
    end

    local healthBar = _G['PartyMemberFrame' .. index .. 'HealthBar']
    local manaBar = _G['PartyMemberFrame' .. index .. 'ManaBar']

    -- FIXED: Set correct frame levels per WoW 3.3.5a layering system
    -- Use lower levels to avoid conflicts with other addons like Compact Raid Frames
    if healthBar then
        healthBar:SetFrameLevel(3)
    end

    if manaBar then
        manaBar:SetFrameLevel(3)
    end

    -- Don't force alpha changes - causes flicker
end

function unitframe.RefreshAllPartyFrames()
    -- FIXED: Protect against combat lockdown
    if InCombatLockdown() or UnitAffectingCombat('player') then
        return
    end

    for i = 1, 4 do
        local pf = _G['PartyMemberFrame' .. i]
        if pf then
            -- SIMPLIFIED: Just update the bars without touching layers
            unitframe.UpdatePartyHPBar(i)
            unitframe.UpdatePartyManaBar(i)

            -- The original code was forcing BORDER layer which sends textures to the back
        end
    end

    -- Safe text update for all party members
    if unitframe.UpdateAllPartyFrameText then
        unitframe.UpdateAllPartyFrameText()
    end
end

-- Function to update party health bar text and colors
function unitframe.UpdatePartyHPBar(i)
    local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
    if not healthbar then
        return
    end

    -- TAINT-FIX: Usar la caché segura en lugar de leer la configuración directamente.
    local settings = safeConfig.party or {}
    local health = UnitHealth('party' .. i)
    local maxHealth = UnitHealthMax and UnitHealthMax('party' .. i) or UnitHealthMax('party' .. i)

    if not health or not maxHealth or maxHealth == 0 then
        healthbar:Hide()
        return
    end

    healthbar:Show()

    -- SIMPLIFIED: Don't touch frame levels or draw layers - leave them as originally set

    -- Apply class colors if enabled
    if settings.classcolor then
        local _, class = UnitClass('party' .. i)
        if class and RAID_CLASS_COLORS[class] then
            -- Use individual -Status texture for class colors
            healthbar:SetStatusBarTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status')
            -- FIXED: Don't force DrawLayer - let Blizzard use default layer like normal texture

            -- Apply dynamic clipping for status textures too
            local tex = healthbar:GetStatusBarTexture()
            if tex then
                -- Apply the same clipping system as normal textures
                unitframe.ApplyStatusTextureClipping(healthbar, tex)
                local layer, sublayer = tex:GetDrawLayer()
            end

            local color = RAID_CLASS_COLORS[class]
            healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
        else
            -- Use normal texture for unknown classes
            healthbar:SetStatusBarTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Partyframe\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health')
            healthbar:SetStatusBarColor(1, 1, 1, 1)
            -- Also reset texture coordinates for consistency
            local tex = healthbar:GetStatusBarTexture()
            if tex then
                tex:SetTexCoord(0, 1, 0, 1)
            end
        end
    else
        -- Use coordinate-based system when class colors disabled
        healthbar:SetStatusBarTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')
        healthbar:SetStatusBarColor(1, 1, 1, 1)

        -- No layer monitoring needed - using Blizzard default layers

        -- Apply coordinates for uipartyframe.blp texture
        unitframe.SetPartyHealthBarCoords(healthbar)
    end

    -- CRUCIAL: When using class colors, don't apply any SetTexCoord manipulations
    -- The -Status texture must maintain its original coordinates to avoid deformation

    -- El texto se maneja ahora en UpdatePartyFrameText() como el sistema del target
end

-- Function to set health bar coordinates using uipartyframe.blp with dynamic clipping
function unitframe.SetPartyHealthBarCoords(healthbar)
    if not healthbar then
        return
    end

    -- Coordenadas exactas para health bar
    local coords = {0.0, 0.28125, 0.6484375, 0.6953125} -- Health bar coordinates

    -- Aplicar coordenadas con recorte dinámico desde la derecha
    local texture = healthbar:GetStatusBarTexture()
    if texture then
        -- Obtener el porcentaje actual de vida
        local currentValue = healthbar:GetValue()
        local maxValue = select(2, healthbar:GetMinMaxValues())
        local percentage = maxValue > 0 and (currentValue / maxValue) or 1

        -- Recortar desde la derecha según el porcentaje (misma técnica que mana)
        local adjustedCoords = {coords[1], coords[2], coords[3], coords[4]}

        -- Calcular nueva coordenada derecha basada en el porcentaje
        local textureWidth = coords[2] - coords[1] -- Ancho total de la textura
        local newWidth = textureWidth * percentage -- Nuevo ancho según porcentaje
        adjustedCoords[2] = coords[1] + newWidth -- Nueva coordenada derecha

        texture:SetTexCoord(adjustedCoords[1], adjustedCoords[2], adjustedCoords[3], adjustedCoords[4])

        -- Set the texture to use our party frame texture
        texture:SetTexture('Interface\\Addons\\DragonUI\\Textures\\Partyframe\\uipartyframe')
    end
end

-- Function to apply dynamic clipping to status textures (for class colors)
function unitframe.ApplyStatusTextureClipping(healthbar, texture)
    if not healthbar or not texture then
        return
    end

    -- Status textures use full coordinates (0,1,0,1) but need dynamic clipping
    -- They don't use atlas coordinates like uipartyframe.blp

    -- Obtener el porcentaje actual de vida
    local currentValue = healthbar:GetValue()
    local maxValue = select(2, healthbar:GetMinMaxValues())
    local percentage = maxValue > 0 and (currentValue / maxValue) or 1

    -- Para status textures, recortamos desde 0 hasta el porcentaje en X
    -- Y mantenemos Y completo (0 a 1)
    local left = 0
    local right = percentage -- Recorte dinámico desde la derecha
    local top = 0
    local bottom = 1

    texture:SetTexCoord(left, right, top, bottom)
end

-- Function to update party mana bar text, colors and coordinates
function unitframe.UpdatePartyManaBar(i)
    local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']
    if not manabar then
        return
    end

    if not UnitExists('party' .. i) then
        manabar:Hide()
        return
    end

    local power = UnitMana('party' .. i) or 0
    local maxPower = UnitManaMax('party' .. i) or 0
    local powerType = UnitPowerType('party' .. i) or 0

    if maxPower > 0 then
        manabar:Show()
        manabar:SetMinMaxValues(0, maxPower)
        unitframe.SetPartyManaBarCoords(manabar, powerType, power, maxPower)
        manabar:SetStatusBarColor(1, 1, 1, 1)
    else
        -- Hide the bar if there's no mana/power
        manabar:Hide()
    end
end

-- Function to set mana bar coordinates based on power type using uipartyframe.blp
-- NOW WITH DYNAMIC CROPPING (Pac-Man style) - texture gets "eaten" from right to left
function unitframe.SetPartyManaBarCoords(manabar, powerType, currentPower, maxPower)
    if not manabar then
        return
    end

    -- Base coordinates for different power types in uipartyframe.blp
    local baseCoords = {}
    local color = {1, 1, 1, 1} -- Default white color

    if powerType == 0 then -- Mana (blue)
        -- Coordenadas base para mana azul (barra grande)
        baseCoords = {0.0, 0.296875, 0.7421875, 0.77734375}
        color = {0.8, 0.9, 1.0, 0.8} -- Azul suave con transparencia
    elseif powerType == 1 then -- Rage (red)
        -- Coordenadas para rage
        baseCoords = {0.59375, 0.890625, 0.7421875, 0.77734375}
        color = {1.0, 0.3, 0.3, 1} -- Rojo suave
    elseif powerType == 2 then -- Focus (orange)
        -- Coordenadas para focus
        baseCoords = {0.56640625, 0.86328125, 0.6953125, 0.73046875}
        color = {1.0, 0.6, 0.2, 1} -- Naranja suave
    elseif powerType == 3 then -- Energy (yellow)
        -- Coordenadas para energy
        baseCoords = {0.26953125, 0.56640625, 0.6953125, 0.73046875}
        color = {1.0, 1.0, 0.3, 1} -- Amarillo suave
    elseif powerType == 6 then -- Runic Power (cyan)
        -- Coordenadas para runic power
        baseCoords = {0.0, 0.296875, 0.77734375, 0.8125}
        color = {0.3, 0.8, 1.0, 1} -- Cyan suave
    else
        -- Default to mana coordinates
        baseCoords = {0.0, 0.28125, 0.8125, 0.84765625}
        color = {0.5, 0.7, 1.0, 1} -- Azul suave
    end

    -- MASK SIMULATION: Calculate how much of the texture to show based on current/max power
    local percentage = 1.0 -- Default to full
    if maxPower and maxPower > 0 and currentPower then
        percentage = currentPower / maxPower
    end

    -- Aplicar la textura con coordenadas FIJAS (no modificar UV)
    manabar:SetStatusBarTexture('Interface\\AddOns\\DragonUI\\Textures\\Partyframe\\uipartyframe')

    -- SISTEMA HÍBRIDO: UV dinámico + tamaño físico proporcional
    local texture = manabar:GetStatusBarTexture()
    if texture then
        -- RECORTE DINÁMICO: Calcular coordenadas UV que se "comen" de derecha a izquierda
        local left = baseCoords[1]
        local right = baseCoords[1] + (baseCoords[2] - baseCoords[1]) * percentage
        local top = baseCoords[3]
        local bottom = baseCoords[4]

        -- Aplicar coordenadas UV dinámicas (Pac-Man effect)
        texture:SetTexCoord(left, right, top, bottom)

        -- FIXED: Don't manipulate texture anchoring - let WoW handle natural positioning
        -- The constant texture repositioning was causing the bars to move to the background
    end

    -- FIXED: Don't force repositioning of the StatusBar - this was causing drift issues
    -- Let the original positioning from ChangePartyFrame() remain stable

    -- Aplicar el color suave encima de la textura
    manabar:SetStatusBarColor(color[1], color[2], color[3], color[4])
end

-- ====================================================================
-- ███████╗███╗   ██╗██████╗      ██████╗ ███████╗    ██████╗  █████╗ ██████╗ ████████╗██╗   ██╗    ███████╗██████╗  █████╗ ███╗   ███╗███████╗███████╗
-- ██╔════╝████╗  ██║██╔══██╗    ██╔═══██╗██╔════╝    ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝╚██╗ ██╔╝    ██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝██╔════╝
-- █████╗  ██╔██╗ ██║██║  ██║    ██║   ██║█████╗      ██████╔╝███████║██████╔╝   ██║    ╚████╔╝     █████╗  ██████╔╝███████║██╔████╔██║█████╗  ███████╗
-- ██╔══╝  ██║╚██╗██║██║  ██║    ██║   ██║██╔══╝      ██╔═══╝ ██╔══██║██╔══██╗   ██║     ╚██╔╝      ██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝  ╚════██║
-- ███████╗██║ ╚████║██████╔╝    ╚██████╔╝██║         ██║     ██║  ██║██║  ██║   ██║      ██║       ██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗███████║
-- ╚══════╝╚═╝  ╚═══╝╚═════╝      ╚═════╝ ╚═╝         ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝       ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝
-- ====================================================================
-- END OF PARTY FRAMES MODULE
-- All Party Frame related functions end here
-- ====================================================================

-- FIXED: Enhanced Pet Frame function with full configuration support
function unitframe.ChangePetFrame()

    if InCombatLockdown() then
        return
    end
    local base = 'Interface\\Addons\\DragonUI\\Textures\\uiunitframe'

    -- Get pet configuration
    local petConfig = addon:GetConfigValue("unitframe", "pet") or {}

    -- Apply scale
    local scale = petConfig.scale or 1.0
    PetFrame:SetScale(scale)

    -- Apply positioning
    if petConfig.override then
        -- FIXED: Make PetFrame movable before setting user placement
        PetFrame:SetMovable(true)
        PetFrame:ClearAllPoints()

        -- FIXED: Use consistent default coordinates that match the non-override position
        -- When not using override, position is 'TOPLEFT', PlayerFrame, 'TOPLEFT', 100, -70
        -- Convert this to UIParent coordinates for override mode
        local defaultX = petConfig.x or 200 -- Aproximadamente PlayerFrame.x + 100
        local defaultY = petConfig.y or -150 -- Aproximadamente PlayerFrame.y - 70
        local anchor = petConfig.anchor or 'TOPLEFT'
        local anchorParent = petConfig.anchorParent or 'TOPLEFT'

        PetFrame:SetPoint(anchor, UIParent, anchorParent, defaultX, defaultY)
        PetFrame:SetUserPlaced(true)
        -- FIXED: Set movable back to false to prevent accidental dragging
        PetFrame:SetMovable(false)
    else
        -- Default positioning relative to PlayerFrame (unchanged)
        PetFrame:ClearAllPoints()
        PetFrame:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 100, -70)
    end

    PetFrameTexture:SetTexture('')
    PetFrameTexture:Hide()

    if PetFrameHealthBarText then
        PetFrameHealthBarText:Hide()
        PetFrameHealthBarText.Show = noop
        PetFrameHealthBarText.SetText = noop
    end
    if PetFrameManaBarText then
        PetFrameManaBarText:Hide()
        PetFrameManaBarText.Show = noop
        PetFrameManaBarText.SetText = noop
    end

    if not frame.PetFrameBackground then
        local background = PetFrame:CreateTexture('DragonUIPetFrameBackground')
        background:SetDrawLayer('BACKGROUND', 1)
        background:SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND')
        background:SetPoint('LEFT', PetPortrait, 'CENTER', -25 + 1, -10)
        frame.PetFrameBackground = background
    end

    if not frame.PetFrameBorder then
        local border = PetFrameHealthBar:CreateTexture('DragonUIPetFrameBorder')
        border:SetDrawLayer('OVERLAY', 2)
        border:SetTexture('Interface\\Addons\\DragonUI\\Textures\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER')
        border:SetPoint('LEFT', PetPortrait, 'CENTER', -25 + 1, -10)
        frame.PetFrameBorder = border
    end

    PetFrameHealthBar:ClearAllPoints()
    PetFrameHealthBar:SetPoint('LEFT', PetPortrait, 'RIGHT', 1 + 1 - 2 + 0.5, 0)
    PetFrameHealthBar:SetSize(70.5, 10)
    PetFrameHealthBar:GetStatusBarTexture():SetTexture(
        'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
    PetFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    PetFrameHealthBar.SetStatusBarColor = noop

    -- Hook text update
    if not PetFrameHealthBar.DragonUI_Hooked then
        PetFrameHealthBar:HookScript("OnValueChanged", function(self)
            unitframe.UpdatePetFrameText()
        end)
        PetFrameHealthBar.DragonUI_Hooked = true
    end

    -- FIXED: Create custom text elements for pet frame like other frames
    if not frame.PetFrameHealthBarDummy then
        local PetFrameHealthBarDummy = CreateFrame('FRAME', 'PetFrameHealthBarDummy', PetFrame)
        PetFrameHealthBarDummy:SetAllPoints(PetFrameHealthBar)
        PetFrameHealthBarDummy:SetFrameStrata('LOW')
        PetFrameHealthBarDummy:SetFrameLevel(PetFrameHealthBar:GetFrameLevel() + 1)
        PetFrameHealthBarDummy:EnableMouse(true)

        frame.PetFrameHealthBarDummy = PetFrameHealthBarDummy

        local t = PetFrameHealthBarDummy:CreateFontString('PetFrameHealthBarText', 'OVERLAY', 'TextStatusBarText')
        t:SetPoint('CENTER', PetFrameHealthBarDummy, 0, 0)
        t:SetText('HP')
        t:Hide()
        frame.PetFrameHealthBarText = t

        -- Create dual text elements for "both" format
        local healthTextLeft = PetFrameHealthBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        healthTextLeft:SetPoint("LEFT", PetFrameHealthBarDummy, "LEFT", 2, 0)
        healthTextLeft:SetJustifyH("LEFT")
        healthTextLeft:Hide()
        frame.PetFrameHealthBarTextLeft = healthTextLeft

        local healthTextRight = PetFrameHealthBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        healthTextRight:SetPoint("RIGHT", PetFrameHealthBarDummy, "RIGHT", -2, 0)
        healthTextRight:SetJustifyH("RIGHT")
        healthTextRight:Hide()
        frame.PetFrameHealthBarTextRight = healthTextRight

        -- Assign scripts right after creation
        PetFrameHealthBarDummy:SetScript('OnEnter', function(self)
            unitframe.UpdatePetFrameText()
        end)

        PetFrameHealthBarDummy:SetScript('OnLeave', function(self)
            unitframe.UpdatePetFrameText()
        end)
    end

    PetFrameManaBar:ClearAllPoints()
    PetFrameManaBar:SetPoint('LEFT', PetPortrait, 'RIGHT', 1 - 2 - 1.5 + 1 - 2 + 0.5, 2 - 10 - 1)
    PetFrameManaBar:SetSize(74, 7.5)
    if UnitExists("pet") then
        local powerType, powerTypeString = UnitPowerType('pet')
        local texturePath = 'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\'
        if powerTypeString == 'MANA' then
            texturePath = texturePath .. 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana'
        elseif powerTypeString == 'FOCUS' then
            texturePath = texturePath .. 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus'
        elseif powerTypeString == 'RAGE' then
            texturePath = texturePath .. 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage'
        elseif powerTypeString == 'ENERGY' then
            texturePath = texturePath .. 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy'
        elseif powerTypeString == 'RUNIC_POWER' then
            texturePath = texturePath .. 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower'
        else
            texturePath = texturePath .. 'UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana'
        end
        PetFrameManaBar:GetStatusBarTexture():SetTexture(texturePath)
    else
        -- Si no hay mascota, ponemos la de maná por defecto
        PetFrameManaBar:GetStatusBarTexture():SetTexture(
            'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana')
    end
    PetFrameManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)

    if not PetFrameManaBar.DragonUI_Hooked then
        PetFrameManaBar:HookScript("OnValueChanged", function(self)
            unitframe.UpdatePetFrameText()
        end)
        PetFrameManaBar.DragonUI_Hooked = true
    end

    -- FIXED: Create custom mana text elements for pet frame
    if not frame.PetFrameManaBarDummy then
        local PetFrameManaBarDummy = CreateFrame('FRAME', 'PetFrameManaBarDummy', PetFrame)
        PetFrameManaBarDummy:SetAllPoints(PetFrameManaBar)
        PetFrameManaBarDummy:SetFrameStrata('LOW')
        PetFrameManaBarDummy:SetFrameLevel(PetFrameManaBar:GetFrameLevel() + 1)
        PetFrameManaBarDummy:EnableMouse(true)

        frame.PetFrameManaBarDummy = PetFrameManaBarDummy

        local t = PetFrameManaBarDummy:CreateFontString('PetFrameManaBarText', 'OVERLAY', 'TextStatusBarText')
        t:SetPoint('CENTER', PetFrameManaBarDummy, 0, 0)
        t:SetText('MANA')
        t:Hide()
        frame.PetFrameManaBarText = t

        -- Create dual text elements for "both" format
        local manaTextLeft = PetFrameManaBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextLeft:SetPoint("LEFT", PetFrameManaBarDummy, "LEFT", 2, 0)
        manaTextLeft:SetJustifyH("LEFT")
        manaTextLeft:Hide()
        frame.PetFrameManaBarTextLeft = manaTextLeft

        local manaTextRight = PetFrameManaBarDummy:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        manaTextRight:SetPoint("RIGHT", PetFrameManaBarDummy, "RIGHT", -2, 0)
        manaTextRight:SetJustifyH("RIGHT")
        manaTextRight:Hide()
        frame.PetFrameManaBarTextRight = manaTextRight

        -- Assign scripts right after creation
        PetFrameManaBarDummy:SetScript('OnEnter', function(self)
            unitframe.UpdatePetFrameText()
        end)

        PetFrameManaBarDummy:SetScript('OnLeave', function(self)
            unitframe.UpdatePetFrameText()
        end)
    end

    frame.UpdatePetManaBarTexture = function()
        local powerType, powerTypeString = UnitPowerType('pet')

        if powerTypeString == 'MANA' then
            PetFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana')
        elseif powerTypeString == 'FOCUS' then
            PetFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus')
        elseif powerTypeString == 'RAGE' then
            PetFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage')
        elseif powerTypeString == 'ENERGY' then
            PetFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy')
        elseif powerTypeString == 'RUNIC_POWER' then
            PetFrameManaBar:GetStatusBarTexture():SetTexture(
                'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower')
        end

        PetFrameManaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    end

    hooksecurefunc('PetFrame_Update', function(self)
        frame.UpdatePetManaBarTexture()
    end)

    -- Position name
    PetName:ClearAllPoints()
    PetName:SetPoint('LEFT', PetPortrait, 'RIGHT', 1 + 1, 2 + 12 - 1)

    -- Hide original Blizzard text elements
    PetFrameHealthBarText:Hide()
    PetFrameManaBarText:Hide()

    -- Apply initial text visibility based on settings
    unitframe.UpdatePetFrameText()

    -- Update visibility based on individual showTextAlways settings for Pet
    if addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
        local config = addon.db.profile.unitframe.pet or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        -- Handle health text visibility
        if showHealthAlways and UnitExists('pet') then
            local health = UnitHealth('pet') or 0
            local maxHealth = UnitHealthMax('pet') or 1
            local textFormat = config.textFormat or 'numeric'
            local useBreakup = config.breakUpLargeNumbers or false

            if maxHealth > 0 then
                local healthText = FormatStatusText(health, maxHealth, textFormat, useBreakup, "pet")

                if textFormat == "both" and type(healthText) == "table" then
                    if frame.PetFrameHealthBarTextLeft and frame.PetFrameHealthBarTextRight then
                        frame.PetFrameHealthBarTextLeft:SetText(healthText.percentage)
                        frame.PetFrameHealthBarTextRight:SetText(healthText.current)
                        frame.PetFrameHealthBarTextLeft:Show()
                        frame.PetFrameHealthBarTextRight:Show()
                    end
                    if frame.PetFrameHealthBarText then
                        frame.PetFrameHealthBarText:Hide()
                    end
                else
                    if frame.PetFrameHealthBarText then
                        local displayText = type(healthText) == "table" and healthText.combined or healthText
                        frame.PetFrameHealthBarText:SetText(displayText)
                        frame.PetFrameHealthBarText:Show()
                    end
                    if frame.PetFrameHealthBarTextLeft then
                        frame.PetFrameHealthBarTextLeft:Hide()
                    end
                    if frame.PetFrameHealthBarTextRight then
                        frame.PetFrameHealthBarTextRight:Hide()
                    end
                end
            end
        end

        -- Handle mana text visibility
        if showManaAlways and UnitExists('pet') then
            local power = UnitPower('pet') or 0
            local maxPower = UnitPowerMax('pet') or 1
            local textFormat = config.textFormat or 'numeric'
            local useBreakup = config.breakUpLargeNumbers or false

            if maxPower > 0 then
                local powerText = FormatStatusText(power, maxPower, textFormat, useBreakup, "pet")

                if textFormat == "both" and type(powerText) == "table" then
                    if frame.PetFrameManaBarTextLeft and frame.PetFrameManaBarTextRight then
                        frame.PetFrameManaBarTextLeft:SetText(powerText.percentage)
                        frame.PetFrameManaBarTextRight:SetText(powerText.current)
                        frame.PetFrameManaBarTextLeft:Show()
                        frame.PetFrameManaBarTextRight:Show()
                    end
                    if frame.PetFrameManaBarText then
                        frame.PetFrameManaBarText:Hide()
                    end
                else
                    if frame.PetFrameManaBarText then
                        local displayText = type(powerText) == "table" and powerText.combined or powerText
                        frame.PetFrameManaBarText:SetText(displayText)
                        frame.PetFrameManaBarText:Show()
                    end
                    if frame.PetFrameManaBarTextLeft then
                        frame.PetFrameManaBarTextLeft:Hide()
                    end
                    if frame.PetFrameManaBarTextRight then
                        frame.PetFrameManaBarTextRight:Hide()
                    end
                end
            end
        end
    end
    -- =====================================================================
    -- START: DEFINITIVE TAINT-PROOF PET THREAT SYSTEM
    -- Replace the old "Threat Glow logic for Pet" block with this one.
    -- =====================================================================
    if not frame.PetThreatSystemInitialized then
        -- 1. Guardamos la función original de Blizzard antes de modificarla.
        if not unitframe.originalPetFrameFlashShow then
            unitframe.originalPetFrameFlashShow = PetFrameFlash.Show
        end

        -- 2. Creamos una función vacía que no hace nada. Será nuestro "interruptor de apagado".
        local function disabledGlow()
            -- Esta función está vacía a propósito.
        end

        -- 3. Creamos la función de control que se llamará desde el menú de opciones.
        --    Es SEGURA porque solo se llama al hacer clic en la casilla, nunca en combate.
        function unitframe.TogglePetThreatGlow(enabled)
            if enabled then
                -- Si el usuario quiere el brillo, restauramos la función original de Blizzard.
                PetFrameFlash.Show = unitframe.originalPetFrameFlashShow
            else
                -- Si el usuario NO quiere el brillo, reemplazamos la función de Blizzard por la nuestra vacía.
                PetFrameFlash.Show = disabledGlow
                PetFrameFlash:Hide() -- También lo ocultamos ahora por si ya se estaba mostrando.
            end
        end

        -- 4. Aplicamos la configuración guardada cuando se carga la UI por primera vez.
        local petConfig = addon:GetConfigValue("unitframe", "pet") or {}
        local threatEnabled = petConfig.enableThreatGlow
        if threatEnabled == nil then
            threatEnabled = true
        end -- Por defecto, activado.
        unitframe.TogglePetThreatGlow(threatEnabled)

        frame.PetThreatSystemInitialized = true
    end
    -- =====================================================================
    -- END: DEFINITIVE TAINT-PROOF PET THREAT SYSTEM
    -- =====================================================================
	
	-- Hook for Health Loss effect
	PetFrame.unit = "pet"
	CreateHealthLossBar(PetFrame, PetFrameHealthBar)
end

-- FIXED: Create options for pet frame with proper defaults
local optionsPet = CreateUnitFrameOptions('Pet', 'Pet Frame Settings', 'pet')

-- FIXED: Override pet frame defaults to match the non-override position
optionsPet.args.x.min = -2500
optionsPet.args.x.max = 2500
optionsPet.args.x.bigStep = 1
-- FIXED: Set better default description that reflects actual default values
optionsPet.args.x.desc = 'X relative to *ANCHOR* (Default: 200 when override enabled)'

optionsPet.args.y.min = -2500
optionsPet.args.y.max = 2500
optionsPet.args.y.bigStep = 1
-- FIXED: Set better default description that reflects actual default values
optionsPet.args.y.desc = 'Y relative to *ANCHOR* (Default: -150 when override enabled)'

-- FIXED: Add pet-specific options like player and target frames
optionsPet.args.showHealthTextAlways = {
    type = 'toggle',
    name = 'Always Show Health Text',
    desc = 'Always display health text (otherwise only on mouseover)',
    order = 15.3
}
optionsPet.args.showManaTextAlways = {
    type = 'toggle',
    name = 'Always Show Mana Text',
    desc = 'Always display mana/energy/rage text (otherwise only on mouseover)',
    order = 15.4
}

-- ADD THIS NEW OPTION FOR THE PET THREAT GLOW
optionsPet.args.enableThreatGlow = {
    type = 'toggle',
    name = 'Enable Threat Glow',
    desc = 'Shows a flashing red glow on the pet frame when it has aggro.',
    order = 16,
    get = function(info)
        local value = getOption(info)
        if value == nil then
            return true
        end
        return value
    end,
    set = function(info, value)
        -- Esta función guarda la nueva configuración y llama a nuestro controlador seguro.
        setOption(info, value)
        -- CRÍTICO: Esto llama a nuestra nueva función de control, que es segura.
        -- Solo se ejecuta al hacer clic en la opción, nunca en combate.
        if unitframe.TogglePetThreatGlow then
            unitframe.TogglePetThreatGlow(value)
        end
        addon:RefreshPetFrame()
    end
}

function unitframe.CreateRestFlipbook()
    if not frame.RestIcon then
        local rest = CreateFrame('Frame', 'DragonUIRestFlipbook')
        rest:SetSize(20, 20)
        rest:SetPoint('CENTER', PlayerPortrait, 'TOPRIGHT', 0, 0)

        local restTexture = rest:CreateTexture('DragonUIRestFlipbookTexture')
        restTexture:SetAllPoints()
        restTexture:SetTexture(1, 1, 1, 1)
        restTexture:SetTexture('Interface\\Addons\\DragonUI\\Textures\\uiunitframerestingflipbook')
        restTexture:SetTexCoord(128 / 1024, 192 / 1024, 0, 64 / 128)

        local animationGroup = restTexture:CreateAnimationGroup()
        -- flipbook doesn't seem to be supported on Era :/   lua error when calling 'SetFlipBookFrameWidth' etc
        -- @TODO: maybe other animation, better than static rest icon

        frame.RestIcon = rest
        -- 'pointless', but saves multiple 'If DF.Wrath...' to eliminate lua error in HookRestFunctions
        frame.RestIconAnimation = animationGroup

        -- Inicialmente ocultar el icono - solo se mostrará cuando IsResting() sea verdadero
        frame.RestIcon:Hide()

        PlayerFrame_UpdateStatus()
    end
end

function unitframe.HookRestFunctions()
    hooksecurefunc(PlayerStatusGlow, 'Show', function()
        PlayerStatusGlow:Hide()
    end)

    hooksecurefunc(PlayerRestIcon, 'Show', function()
        PlayerRestIcon:Hide()
    end)

    hooksecurefunc(PlayerRestGlow, 'Show', function()
        PlayerRestGlow:Hide()
    end)

    -- FIXED: Hide Blizzard's player frame combat flash that conflicts with DragonUI custom combat glow
    if PlayerFrameFlash then
        hooksecurefunc(PlayerFrameFlash, 'Show', function()
            PlayerFrameFlash:Hide()
        end)
        -- Also set empty texture to prevent any residual display
        PlayerFrameFlash:SetTexture('')
    end

    hooksecurefunc('SetUIVisibility', function(visible)
        if visible then
            PlayerFrame_UpdateStatus()
        else
            if frame.RestIcon then
                frame.RestIcon:Hide()
                frame.RestIconAnimation:Stop()
            end
        end
    end)
end

------------------------------------------
-- Event Handling System
-- Handles all events for unit frame updates and state changes *Except PARTY FRAMES
------------------------------------------
local eventFrame = CreateFrame("Frame")

--[[
* Main event handler for unit frame updates
* Processes events and routes them to appropriate handler functions
* 
* @param event string - The event name that triggered this handler
* @param arg1 string - First argument (usually the unit ID)
--]]
function eventFrame:OnEvent(event, arg1)
    if event == 'UNIT_POWER_UPDATE' and arg1 == 'focus' then
        unitframe.UpdateFocusText()
    elseif event == 'UNIT_POWER_UPDATE' and arg1 == 'pet' then

    elseif event == 'UNIT_POWER_UPDATE' then


        -- Focus frame handling (mantener código existente)
        if UnitExists('focus') then
            local shouldUseClassColor = addon:GetConfigValue("unitframe", "focus", "classcolor") and
                                            UnitIsPlayer('focus')
            if shouldUseClassColor then
                local localizedClass, englishClass, classIndex = UnitClass('focus')
                if englishClass and RAID_CLASS_COLORS[englishClass] then
                    local color = RAID_CLASS_COLORS[englishClass]
                    FocusFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
                else
                    FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
                end
            else
                FocusFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
            end
            if FocusFrameManaBar then
                FocusFrameManaBar:SetStatusBarColor(1, 1, 1, 1)
            end
        end

    elseif event == 'UNIT_HEALTH' and arg1 then
        -- NUEVO: Verificar si la unidad murió PRIMERO
        if UnitIsDeadOrGhost(arg1) then
            HandleUnitDeath(arg1)
        else
            -- Código existente para unidades vivas
            if arg1 == 'focus' then
                unitframe.UpdateFocusText()

                -- Ensure mouseover scripts are set up
                unitframe.InitializePartyFrameMouseover()

            end
        end

    elseif event == 'PLAYER_FOCUS_CHANGED' then
        unitframe.ReApplyFocusFrame()
        unitframe.UpdateFocusText()
    elseif event == 'PLAYER_ENTERING_WORLD' then
        unitframe.CreatePlayerFrameTextures()
        unitframe.ChangePlayerframe()
        unitframe.ChangeTargetFrame()
        unitframe.ReApplyTargetFrame()
        unitframe.ReApplyToTFrame()
        unitframe.ChangeStatusIcons()
        unitframe.CreateRestFlipbook()
        unitframe.ChangeFocusFrame()
        unitframe.ChangeFocusToT()
        unitframe.ChangePetFrame()

        unitframe:ApplySettings()

        -- Force update of resting state after everything is configured
        if PlayerFrame_UpdateStatus then
            PlayerFrame_UpdateStatus()
        end
    elseif event == 'PLAYER_TARGET_CHANGED' then
        -- unitframe.ApplySettings()
        unitframe.ReApplyTargetFrame()
        unitframe.ReApplyToTFrame() -- FIXED: Use correct function name
        unitframe.ChangePlayerframe()

        -- FIXED: Clear target frame texts and update immediately when target changes
        unitframe.ClearTargetFrameTexts()
        unitframe.UpdateTargetFrameText()

        -- FIXED: Update player frame only if settings require it (independent of target)
        local config = addon.db.profile.unitframe and addon.db.profile.unitframe.player or {}
        local showHealthAlways = config.showHealthTextAlways or false
        local showManaAlways = config.showManaTextAlways or false

        -- Only update player frame if texts should always be shown, regardless of target
        if showHealthAlways or showManaAlways then
            unitframe.SafeUpdatePlayerFrameText()
        else
            -- If texts shouldn't always be shown, clear them to respect the setting
            unitframe.ClearPlayerFrameTexts()
        end
    elseif event == 'UNIT_ENTERED_VEHICLE' then
        if arg1 == 'player' then
            unitframe.ChangePlayerframe()
        end
    elseif event == 'UNIT_EXITED_VEHICLE' then
        if arg1 == 'player' then
            unitframe.ChangePlayerframe()
        end
    elseif event == 'ZONE_CHANGED' or event == 'ZONE_CHANGED_INDOORS' or event == 'ZONE_CHANGED_NEW_AREA' then
        unitframe.ChangePlayerframe()
    elseif event == 'PLAYER_UPDATE_RESTING' then
        -- Force update of resting state
        if PlayerFrame_UpdateStatus then
            PlayerFrame_UpdateStatus()
        end
        -- NUEVOS EVENTOS PARA MANEJAR MUERTE/RESURRECCIÓN
    elseif event == 'PLAYER_DEAD' then
        HandleUnitDeath("player")
    elseif event == 'PLAYER_ALIVE' or event == 'PLAYER_UNGHOST' then
        -- Actualizar textos del player cuando revive
        unitframe.SafeUpdatePlayerFrameText()
    elseif event == 'UNIT_CONNECTION' and arg1 then
        -- Manejar desconexiones de jugadores
        if arg1 == "target" then
            if UnitIsConnected and not UnitIsConnected(arg1) then
                unitframe.ClearTargetFrameTexts()
            else
                unitframe.UpdateTargetFrameText()
            end
        elseif arg1 == "focus" then
            unitframe.UpdateFocusText()
        
        end
    end
end
eventFrame:SetScript('OnEvent', eventFrame.OnEvent)

------------------------------------------
-- Event Registration
-- Register all events needed for unit frame updates
------------------------------------------
-- Register core events for all unit frames
eventFrame:RegisterEvent('UNIT_HEALTH')
eventFrame:RegisterEvent('UNIT_MANA')
eventFrame:RegisterEvent('UNIT_MAXMANA')
eventFrame:RegisterEvent('UNIT_POWER_UPDATE')
eventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
eventFrame:RegisterEvent('PLAYER_TARGET_CHANGED')
eventFrame:RegisterEvent('PLAYER_FOCUS_CHANGED')
eventFrame:RegisterEvent('UNIT_EXITED_VEHICLE')
eventFrame:RegisterEvent('ZONE_CHANGED')
eventFrame:RegisterEvent('ZONE_CHANGED_INDOORS')
eventFrame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
eventFrame:RegisterEvent('PLAYER_UPDATE_RESTING')
eventFrame:RegisterEvent('PLAYER_DEAD')
eventFrame:RegisterEvent('PLAYER_ALIVE')
eventFrame:RegisterEvent('PLAYER_UNGHOST')
eventFrame:RegisterEvent('UNIT_CONNECTION')


-- Module initialization compatible with DragonUI
local frameInit = CreateFrame("Frame")
frameInit:RegisterEvent("ADDON_LOADED")
frameInit:RegisterEvent("PLAYER_ENTERING_WORLD")

frameInit:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "DragonUI" then
            unitframe:Initialize()
            unitframe.UpdateSafeConfig()
            -- Crear el RestIcon personalizado de DragonflightUI
            unitframe.CreateRestFlipbook()
            -- Registrar el hook para actualizar el estado del player frame (incluye el icono de descanso)
            unitframe.HookPlayerStatus()
            -- Ocultar los iconos de rest de Blizzard para usar los nuestros
            unitframe.HookRestFunctions()

            -- FIXED: If player is already in world (reload case), execute OnEnable logic
            if UnitExists("player") then
                unitframe:OnEnable()
                if PlayerFrame_UpdateStatus then
                    PlayerFrame_UpdateStatus()
                end
                -- CRITICAL: Force party frame refresh on reload (only reapply settings, don't recreate)
                unitframe.ReconfigurePartyFramesForReload()
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        unitframe:OnEnable()
        -- Actualizar el estado del RestIcon una vez que el jugador est? en el mundo
        if PlayerFrame_UpdateStatus then
            PlayerFrame_UpdateStatus()
        end
    end
end)

-- REMOVED OLD REFRESH FUNCTIONS --
-- These are no longer needed thanks to the new master addon:RefreshUnitFrames() system.
-- function unitframe:RefreshSettings() ... end
-- function addon:Refreshunitframe() ... end
--

-- Create event frame for automatic text updates (3.3.5a compatible)
local textUpdateFrame = CreateFrame("Frame")
textUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
textUpdateFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
textUpdateFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
textUpdateFrame:RegisterEvent("PLAYER_LEVEL_UP")
textUpdateFrame:RegisterEvent("UNIT_HEALTH")
textUpdateFrame:RegisterEvent("UNIT_POWER_UPDATE")
textUpdateFrame:RegisterEvent("UNIT_POWER_FREQUENT") -- More frequent power updates
textUpdateFrame:RegisterEvent("UNIT_MAXPOWER") -- Max power changes
-- FIXED: Add pet events for proper pet frame handling
textUpdateFrame:RegisterEvent("UNIT_PET")
textUpdateFrame:RegisterEvent("PET_UI_UPDATE")
-- Add events for rest icon updates
textUpdateFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
textUpdateFrame:RegisterEvent("ZONE_CHANGED")
textUpdateFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
textUpdateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- Add more target-specific events
textUpdateFrame:RegisterEvent("UNIT_DISPLAYPOWER") -- Power type changes
-- Add ToT specific events
textUpdateFrame:RegisterEvent("UNIT_TARGET") -- Target of target changes
textUpdateFrame:RegisterEvent("ADDON_LOADED")

-- Note: ToT name text updates are handled by the OnUpdate hook in StyleToTFrame() for efficiency

-- FIXED: Also create an OnUpdate handler for immediate updates
local totUpdateFrame = CreateFrame("Frame")
totUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate >= 0.1 then -- Update every 0.1 seconds
        self.timeSinceLastUpdate = 0
        -- Only update if the frame should be visible
        if TargetFrameToT and TargetFrameToT:IsShown() and UnitExists('targettarget') then
            local currentName = UnitName('targettarget')
            local displayedName = TargetFrameToTTextureFrameName and TargetFrameToTTextureFrameName:GetText()

            -- Only update if the name has changed or if text is not visible
            if currentName and
                (not displayedName or displayedName ~= currentName or not TargetFrameToTTextureFrameName:IsShown()) then
                unitframe.UpdateToTNameText()
            end
        end
    end
end)
textUpdateFrame:RegisterEvent("UNIT_HEALTH") -- Health changes for all units including targettarget
textUpdateFrame:RegisterEvent("UNIT_POWER_UPDATE") -- Power changes for all units including targettarget

-- Hook to WoW's mana bar update function to catch target mana changes
local function HookTargetManaUpdates()
    -- Hook the target frame mana bar update function
    if TargetFrameManaBar and TargetFrameManaBar.SetValue then
        hooksecurefunc(TargetFrameManaBar, "SetValue", function(self, value)
            if UnitExists('target') then
                -- Force update our custom target frame text when mana changes
                unitframe.UpdateTargetFrameText()
            end
        end)
    end

    -- Also hook the standard UnitFrameManaBar_Update function if it exists
    if UnitFrameManaBar_Update then
        hooksecurefunc("UnitFrameManaBar_Update", function(manabar, unit)
            if unit == "target" and UnitExists('target') then
                -- Force update our custom target frame text
                unitframe.UpdateTargetFrameText()
            end
        end)
    end
end

-- Function to completely disable Blizzard's party frame text functions
local function DisableBlizzardPartyText()
    -- Disable Blizzard's party frame text functions to prevent conflicts
    for i = 1, 4 do
        local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
        local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']

        if healthbar then
            -- Disable ALL possible Blizzard health text elements
            if healthbar.TextString then
                healthbar.TextString:SetText("")
                healthbar.TextString:Hide()
                healthbar.TextString:SetAlpha(0)
            end
            if healthbar.LeftText then
                healthbar.LeftText:SetText("")
                healthbar.LeftText:Hide()
                healthbar.LeftText:SetAlpha(0)
            end
            if healthbar.RightText then
                healthbar.RightText:SetText("")
                healthbar.RightText:Hide()
                healthbar.RightText:SetAlpha(0)
            end
            -- Also disable any tooltip text on hover
            healthbar:SetScript("OnEnter", nil)
            healthbar:SetScript("OnLeave", nil)
        end

        if manabar then
            -- Disable ALL possible Blizzard mana text elements
            if manabar.TextString then
                manabar.TextString:SetText("")
                manabar.TextString:Hide()
                manabar.TextString:SetAlpha(0)
            end
            if manabar.LeftText then
                manabar.LeftText:SetText("")
                manabar.LeftText:Hide()
                manabar.LeftText:SetAlpha(0)
            end
            if manabar.RightText then
                manabar.RightText:SetText("")
                manabar.RightText:Hide()
                manabar.RightText:SetAlpha(0)
            end
            -- Also disable any tooltip text on hover
            manabar:SetScript("OnEnter", nil)
            manabar:SetScript("OnLeave", nil)
        end
    end

    -- Also hook TextStatusBar_UpdateTextString to prevent any text updates
    if TextStatusBar_UpdateTextString then
        local originalTextStatusBarUpdate = TextStatusBar_UpdateTextString
        TextStatusBar_UpdateTextString = function(statusbar)
            -- Check if this is a party frame
            local name = statusbar:GetName()
            if name and string.match(name, "PartyMemberFrame[1-4]") then
                -- For party frames, do nothing (disable text completely)
                return
            elseif name and (string.match(name, "PlayerFrame") or string.match(name, "TargetFrame")) then
                -- FIXED: For player/target frames, apply our large numbers formatting
                originalTextStatusBarUpdate(statusbar)

                -- Apply large numbers formatting if enabled
                if statusbar.TextString and addon and addon.db and addon.db.profile and addon.db.profile.unitframe then
                    local frameType = string.match(name, "PlayerFrame") and "player" or "target"
                    local config = addon.db.profile.unitframe[frameType]

                    if config and config.breakUpLargeNumbers then
                        local text = statusbar.TextString:GetText()
                        if text and string.match(text, "%d+") then
                            -- Replace numbers in the text with abbreviated versions
                            local newText = string.gsub(text, "(%d+)", function(num)
                                local value = tonumber(num)
                                if value and value >= 1000 then
                                    return AbbreviateLargeNumbers(value)
                                end
                                return num
                            end)
                            statusbar.TextString:SetText(newText)
                        end
                    end
                end
            else
                -- For other frames, use original function
                originalTextStatusBarUpdate(statusbar)
            end
        end
    end
end

-- Replace Blizzard's party frame update functions to prevent text conflicts
local function HookPartyFrameUpdates()
    -- Hook the main health bar update function to ensure our textures update
    hooksecurefunc("UnitFrameHealthBar_Update", function(healthbar, unit)
        local partyIndex = unit and string.match(unit, "^party([1-4])$")
        if partyIndex then
            local i = tonumber(partyIndex)
            if i then

                unitframe.UpdatePartyHPBar(i)
            end
        end
    end)

    -- Hook individual party frame SetValue functions
    for i = 1, 4 do
        local healthbar = _G['PartyMemberFrame' .. i .. 'HealthBar']
        local manabar = _G['PartyMemberFrame' .. i .. 'ManaBar']

        if healthbar and healthbar.SetValue then
            hooksecurefunc(healthbar, "SetValue", function(self, value)
                if UnitExists('party' .. i) then
                    unitframe.UpdatePartyFrameText(i)
                    unitframe.UpdatePartyHPBar(i)
                end
            end)
        end

        -- Hook manabar SetValue for immediate updates (3.3.5a compatibility)
        if manabar and manabar.SetValue then
            hooksecurefunc(manabar, "SetValue", function(self, value)
                if UnitExists('party' .. i) then
                    -- Force immediate mana bar update
                    unitframe.UpdatePartyManaBar(i)
                end
            end)
        end
    end
end

-- Function to force update all party mana bars (3.3.5a compatibility)
function unitframe.ForceUpdateAllPartyManaBars()
    for i = 1, 4 do
        if UnitExists('party' .. i) then
            unitframe.UpdatePartyManaBar(i)
            unitframe.UpdatePartyFrameText(i)
        end
    end
end

-- Initialize the hooks when the addon loads
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("ADDON_LOADED")
hookFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        HookTargetManaUpdates()
        HookPartyFrameUpdates()
        DisableBlizzardPartyText()
        unitframe.InitializePartyFrameMouseover()

        -- Force initial update of all party mana bars after a short delay using WoW 3.3.5a compatible timer
        local delayFrame = CreateFrame("Frame")
        local delayTime = 0
        delayFrame:SetScript("OnUpdate", function(self, elapsed)
            delayTime = delayTime + elapsed
            if delayTime >= 1.0 then -- Wait 1 second
                unitframe.ForceUpdateAllPartyManaBars()
                self:SetScript("OnUpdate", nil) -- Stop the timer
            end
        end)

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

textUpdateFrame:SetScript("OnEvent", function(self, event, unit)
    -- Simple immediate update for most important events
    if event == "PLAYER_ENTERING_WORLD" then
        unitframe.UpdateAllTextDisplays()
        -- FIXED: Use selective update on world enter based on settings
        local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                           addon.db.profile.unitframe.player
        if config then
            unitframe.UpdatePlayerFrameTextSelective(config.showHealthTextAlways or false,
                config.showManaTextAlways or false)
        end
        unitframe.UpdateTargetFrameText()

        if UnitExists("pet") and frame.UpdatePetManaBarTexture then
            frame.UpdatePetManaBarTexture()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        -- FIXED: Force player frame update on level up to maintain DragonUI colors
        unitframe.ChangePlayerframe()
        unitframe.ForcePlayerFrameColors()
        -- FIXED: Use selective update on level up based on settings
        local config = addon.db and addon.db.profile and addon.db.profile.unitframe and
                           addon.db.profile.unitframe.player
        if config then
            unitframe.UpdatePlayerFrameTextSelective(config.showHealthTextAlways or false,
                config.showManaTextAlways or false)
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        -- FIXED: Improved handling of target/focus changes with proper separation
        if event == "PLAYER_TARGET_CHANGED" then
            -- Clear old target texts immediately
            unitframe.ClearTargetFrameTexts()
            -- Update target frame with new target (or empty if no target)
            unitframe.UpdateTargetFrameText()

        elseif event == "PLAYER_FOCUS_CHANGED" then
            unitframe.UpdateFocusText()
        end
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_MAXMANA" or event == "UNIT_POWER_UPDATE" or
        event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") then
        -- FIXED: Handle unit events without triggering hover logic for player
        if unit == "target" then
            -- Simple robust function that handles both health and mana
            unitframe.UpdateTargetFrameText()
        elseif unit == "focus" then
            unitframe.UpdateFocusText()
        elseif unit == "pet" then
            unitframe.UpdatePetFrameText()
            if event == "UNIT_POWER_UPDATE" then
                -- FIXED: Handle pet power type changes
                if UnitExists("pet") and frame.UpdatePetManaBarTexture then
                    frame.UpdatePetManaBarTexture()
                end
            end
        elseif unit == "target" and event == "UNIT_TARGET" then
            -- FIXED: Handle target of target changes - apply textures and colors properly
            if UnitExists('targettarget') then
                unitframe.StyleToTFrame() -- Apply positioning and textures first
                unitframe.ReApplyToTFrame() -- Then apply colors
                unitframe.UpdateToTPowerBarTexture() -- Update power type texture
            end
        elseif unit == "targettarget" then
            -- FIXED: Handle direct targettarget unit events (health/mana changes)
            if UnitExists('targettarget') then
                unitframe.ReApplyToTFrame() -- Update colors and textures
                -- Update power bar texture on power type changes
                if event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_UPDATE" then
                    unitframe.UpdateToTPowerBarTexture()
                end
            end
        elseif unit == "focus" and event == "UNIT_TARGET" then
            -- FIXED: Handle focus target of target changes
            if UnitExists('focustarget') then
                unitframe.StyleFocusToTFrame() -- Apply positioning and textures first
                unitframe.ReApplyFocusToTFrame() -- Then apply colors
                unitframe.UpdateFocusToTPowerBarTexture() -- Update power type texture
            else
                -- Focus has no target - hide the name text
            end
        elseif unit == "focustarget" then
            -- FIXED: Handle focustarget health/mana changes
            if UnitExists('focustarget') then
                unitframe.ReApplyFocusToTFrame() -- Update colors and textures
                unitframe.UpdateFocusToTPowerBarTexture() -- Update power type texture
            end
            -- Already handled by UnitFrameManaBar_Update hook
        end
    elseif event == "UNIT_PET" and unit == "player" then
        -- FIXED: Handle pet summon/dismiss events
        if UnitExists("pet") then
            -- Pet was summoned, ensure pet frame is properly styled
            unitframe.ChangePetFrame()
            -- REMOVED: PetFrame:Show() is a protected function and causes taint.
            -- The game will handle showing the frame automatically.
            -- if PetFrame then
            --     PetFrame:Show()
            -- end
            -- FIXED: Also update pet power bar texture after pet summon
            if frame.UpdatePetManaBarTexture then
                frame.UpdatePetManaBarTexture()
            end
        else
            -- Pet was dismissed, hide pet frame
            -- REMOVED: PetFrame:Hide() is also protected. The game handles this.
            -- if PetFrame then
            --     PetFrame:Hide()
            -- end
        end
    elseif event == "PET_UI_UPDATE" then
        -- FIXED: Handle pet UI updates
        if UnitExists("pet") and PetFrame then
            -- Make sure pet frame is visible and properly styled
            unitframe.ChangePetFrame()
            PetFrame:Show()
            -- FIXED: Also update pet power bar texture after UI update
            if frame.UpdatePetManaBarTexture then
                frame.UpdatePetManaBarTexture()
            end
        end
        -- FIXED: Cambiar VARIABLES_LOADED por un evento más apropiado
    elseif event == "ADDON_LOADED" then
        local addonName = unit -- En ADDON_LOADED, unit es el nombre del addon
        if addonName == "DragonUI" then
            -- FIXED: Complete pet frame refresh when addon reloads
            if UnitExists("pet") then
                -- Get the pet configuration
                local petConfig = addon:GetConfigValue("unitframe", "pet") or {}

                -- Apply scale
                local scale = petConfig.scale or 1.0
                PetFrame:SetScale(scale)

                -- Apply positioning if override is enabled
                if petConfig.override then
                    PetFrame:SetMovable(true)
                    PetFrame:ClearAllPoints()
                    local defaultX = petConfig.x or 200
                    local defaultY = petConfig.y or -150
                    local anchor = petConfig.anchor or 'TOPLEFT'
                    local anchorParent = petConfig.anchorParent or 'TOPLEFT'
                    PetFrame:SetPoint(anchor, UIParent, anchorParent, defaultX, defaultY)
                    PetFrame:SetUserPlaced(true)
                    PetFrame:SetMovable(false)
                else
                    -- Reset to default position relative to PlayerFrame
                    PetFrame:ClearAllPoints()
                    PetFrame:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 100, -70)
                end

                -- FIXED: Llamar a ChangePetFrame para aplicar toda la configuración
                unitframe.ChangePetFrame()

                -- Update text with new text format settings
                unitframe.UpdatePetFrameText()

                -- Update power bar texture for current pet power type
                if frame.UpdatePetManaBarTexture then
                    frame.UpdatePetManaBarTexture()
                end
            end

            -- FIXED: Also refresh all other frames on addon reload
            unitframe:ApplySettings()

            -- Force update of all text displays with new profile settings
            unitframe.UpdateAllTextDisplays()
        end
    end
end)

-- Immediate initialization of frames (crucial for visibility upon loading)
-- Esta se ejecuta en cuanto el addon se carga para configurar los frames b?sicos
if PlayerFrame and TargetFrame then
    unitframe.CreatePlayerFrameTextures()
    unitframe.ChangePlayerframe()
    unitframe.ChangeTargetFrame()
    unitframe.ReApplyTargetFrame()
    unitframe.ChangeStatusIcons()
    if FocusFrame then
        unitframe.ChangeFocusFrame()
        unitframe.ReApplyFocusFrame()

        -- FIXED: Setup Focus ToT frame
        unitframe.ChangeFocusToT()
        if UnitExists('focustarget') then
            unitframe.ReApplyFocusToTFrame()
        end
    end

    -- FIXED: Setup proper hover events for PlayerFrame text display
    unitframe.SetupPlayerFrameHoverEvents()

    -- FIXED: Setup proper hover events for TargetFrame text display
    unitframe.SetupTargetFrameHoverEvents()

    -- FIXED: Setup Target of Target frame
    unitframe.ChangeToT()

    -- FIXED: Force initial texture application for ToT
    unitframe.StyleToTFrame()

    -- FIXED: Apply initial ToT colors and textures
    if UnitExists('targettarget') then
        unitframe.ReApplyToTFrame()
    end

    -- FIXED: Setup Focus of Target frame
    unitframe.ChangeFocusToT()

    -- FIXED: Force initial texture application for FoT
    unitframe.StyleFocusToTFrame()

    -- FIXED: Apply initial FoT colors and textures
    if UnitExists('focustarget') then
        unitframe.ReApplyFocusToTFrame()
    end

end

function unitframe.HookManaBarColors()
    -- Hook the WoW function that updates mana bar types to ensure DragonflightUI colors persist
    hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
        local name = manaBar:GetName()

        if name == 'PlayerFrameManaBar' then
            -- FIXED: Handle PlayerFrameManaBar to prevent color resets on level up
            local powerType, powerTypeString = UnitPowerType('player')

            if powerTypeString == 'MANA' then
                PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana')
            elseif powerTypeString == 'RAGE' then
                PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage')
            elseif powerTypeString == 'FOCUS' then
                PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus')
            elseif powerTypeString == 'ENERGY' then
                PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy')
            elseif powerTypeString == 'RUNIC_POWER' then
                PlayerFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower')
            end

            -- Force white color to work with DragonUI textures
            PlayerFrameManaBar:SetStatusBarColor(1, 1, 1, 1)

        elseif name == 'TargetFrameManaBar' then
            local currentValue = UnitPower("target")
            if currentValue then
                TargetFrameManaBar:SetValue(currentValue)
            end

        elseif name == 'FocusFrameManaBar' then
            local powerType, powerTypeString = UnitPowerType('focus')

            if powerTypeString == 'MANA' then
                FocusFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana')
            elseif powerTypeString == 'FOCUS' then
                FocusFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Focus')
            elseif powerTypeString == 'RAGE' then
                FocusFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage')
            elseif powerTypeString == 'ENERGY' then
                FocusFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-Energy')
            elseif powerTypeString == 'RUNIC_POWER' then
                FocusFrameManaBar:GetStatusBarTexture():SetTexture(
                    'Interface\\Addons\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-RunicPower')
            end

            FocusFrameManaBar:SetStatusBarColor(1, 1, 1, 1)

            -- Clear target flash for consistency
            if FocusFrameFlash then
                FocusFrameFlash:SetTexture('')
            end
        end
    end)
end

-- =============================================================================
-- PROFILE CHANGE HOOK
-- =============================================================================

-- This function registers the necessary callbacks with AceDB-3.0.
-- It tells the database to call our master refresh function whenever a profile event occurs.
function unitframe.RegisterProfileCallbacks()
    if addon and addon.db and addon.db.RegisterCallback then
        -- When the profile is changed, copied, or reset, call addon:RefreshUnitFrames()
        addon.db.RegisterCallback(addon, "OnProfileChanged", "RefreshUnitFrames")
        addon.db.RegisterCallback(addon, "OnProfileCopied", "RefreshUnitFrames")
        addon.db.RegisterCallback(addon, "OnProfileReset", "RefreshUnitFrames")
    end
end

-- We use a dedicated frame to safely call the registration function once the addon is loaded.
local profileCallbackFrame = CreateFrame("Frame")
profileCallbackFrame:RegisterEvent("ADDON_LOADED")
profileCallbackFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        unitframe.RegisterProfileCallbacks()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
