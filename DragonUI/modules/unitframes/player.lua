local addon = select(2, ...)
local UF = addon.UF
local L = addon.L

-- ====================================================================
-- DRAGONUI PLAYER FRAME MODULE
-- ====================================================================

-- ============================================================================
-- MODULE VARIABLES & CONFIGURATION
-- ============================================================================

-- Variable to defer application after combat
local deferredPositionUpdate = false

local Module = {
    playerFrame = nil,
    textSystem = nil,
    initialized = false,
    applied = false,
    eventsFrame = nil,
    hooks = {},
    registeredEvents = {},
    originalStates = {}
}

if addon.RegisterModule then
    addon:RegisterModule("player", Module,
        L["Player Frame"],
        L["Dragonflight-styled player unit frame"])
end
-- Animation variables for Combat Flash pulse effect
local combatPulseTimer = 0
local eliteStatusPulseTimer = 0

-- Elite Glow System State
local eliteGlowActive = false
local statusGlowVisible = false
local combatGlowVisible = false

-- Cache frequently accessed globals for performance
local PlayerFrame = _G.PlayerFrame
local PlayerFrameHealthBar = _G.PlayerFrameHealthBar
local PlayerFrameManaBar = _G.PlayerFrameManaBar
local PlayerPortrait = _G.PlayerPortrait
local PlayerStatusTexture = _G.PlayerStatusTexture
local PlayerFrameFlash = _G.PlayerFrameFlash
local PlayerRestIcon = _G.PlayerRestIcon
local PlayerStatusGlow = _G.PlayerStatusGlow
local PlayerRestGlow = _G.PlayerRestGlow
local PlayerName = _G.PlayerName
local PlayerLevelText = _G.PlayerLevelText

-- Texture paths from shared core (single source of truth)
local TEXTURES = UF.TEXTURES.player

-- Keep a fixed on-screen border size so higher-resolution replacements
-- do not render larger than the original DragonUI frame.
local PLAYER_BORDER_WIDTH = 256
local PLAYER_BORDER_HEIGHT = 128

-- Dedicated player corner embellishment (normal state) from standalone texture.
local PLAYER_CORNER_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\ui-hud-unitframe-player-portraiton-cornerembellishment-2x"
local PLAYER_CORNER_TEX_COORDS = {
    0, 44 / 64,
    0, 44 / 64
}

-- Combat icon uses the white crossed-swords glyph from atlas crop.
local PLAYER_COMBAT_ICON_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\uiunitframe2x_ptr_icons_crop"
local PLAYER_COMBAT_ICON_TEX_COORDS = {
    2 / 256, 32 / 256,   -- x: 2..31 (exclusive right edge at 32)
    63 / 256, 90 / 256   -- y: 63..89 (exclusive bottom edge at 90)
}

-- Coordinates for elite/rare glows (inverted target frame)
local ELITE_GLOW_COORDINATES = {
    -- Using the correct texture: 'Interface\\Addons\\DragonUI\\Textures\\UI\\UnitFrame'
    texCoord = {0.2061015625, 0, 0.537109375, 0.712890625},
    size = {209, 90},
    texture = 'Interface\\Addons\\DragonUI\\Textures\\UI\\UnitFrame'
}

-- Dragon decoration coordinates for uiunitframeboss2x texture (always flipped for player frame)
local DRAGON_COORDINATES = {
    elite = {
        texCoord = {0.314453125, 0.001953125, 0.322265625, 0.630859375},
        size = {80, 79},
        offset = {4, 1}
    },
    rareelite = {
        texCoord = {0.388671875, 0.001953125, 0.001953125, 0.31835937},
        size = {99, 81}, -- 97*1.02 ≈ 99, 79*1.02 ≈ 81
        offset = {23, 2}
    }
}

-- Combat Flash animation settings *NO Elite activated
local COMBAT_PULSE_SETTINGS = {
    speed = 9, -- Pulse speed
    minAlpha = 0.3, -- Minimum transparency
    maxAlpha = 1.0, -- Maximum transparency
    enabled = true -- Enable/disable animation
}

-- Elite Combat Flash animation settings (when elite decoration is ON)
local ELITE_COMBAT_PULSE_SETTINGS = {
    speed = 9, -- Speed for combat in elite mode (different from normal)
    minAlpha = 0.2,
    maxAlpha = 0.9,
    enabled = true
}

-- Normal Status/Rest animation settings (when NO elite decoration)
local NORMAL_STATUS_PULSE_SETTINGS = {
    speed = 5, -- Speed for resting in normal mode
    minAlpha = 0,
    maxAlpha = 0.7,
    enabled = true
}

-- Elite Status/Rest animation settings (when elite decoration is ON)
local ELITE_STATUS_PULSE_SETTINGS = {
    speed = 5, -- Speed for resting in elite mode
    minAlpha = 0,
    maxAlpha = 0.7,
    enabled = true
}

-- Event lookup tables for O(1) performance
local HEALTH_EVENTS = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true
}

-- 3.3.5a has no UNIT_POWER/UNIT_MAXPOWER; power changes fire one event per power token.
local POWER_EVENTS = {
    UNIT_DISPLAYPOWER = true,
    UNIT_MANA = true,
    UNIT_RAGE = true,
    UNIT_FOCUS = true,
    UNIT_ENERGY = true,
    UNIT_HAPPINESS = true,
    UNIT_RUNIC_POWER = true,
    UNIT_MAXMANA = true,
    UNIT_MAXRAGE = true,
    UNIT_MAXFOCUS = true,
    UNIT_MAXENERGY = true,
    UNIT_MAXHAPPINESS = true,
    UNIT_MAXRUNIC_POWER = true
}

-- Rune type coordinates
local RUNE_COORDS = {
    [1] = {0 / 128, 34 / 128, 0 / 128, 34 / 128}, -- Blood
    [2] = {0 / 128, 34 / 128, 68 / 128, 102 / 128}, -- Unholy
    [3] = {34 / 128, 68 / 128, 0 / 128, 34 / 128}, -- Frost
    [4] = {68 / 128, 102 / 128, 0 / 128, 34 / 128} -- Death
}
local RUNE_TYPE_DEATH = 4
local DEATH_RUNE_COORDS = RUNE_COORDS[3]

-- LFG Role icon coordinates
local ROLE_COORDS = {
    TANK = {35 / 256, 53 / 256, 0 / 256, 17 / 256},
    HEALER = {18 / 256, 35 / 256, 0 / 256, 18 / 256},
    DAMAGER = {0 / 256, 17 / 256, 0 / 256, 17 / 256}
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get player configuration with defaults fallback via shared core
local function GetPlayerConfig()
    return UF.GetConfig("player")
end

local function IsPlayerModuleEnabled()
    return UF and UF.IsEnabled and UF.IsEnabled("player")
end

-- Cache target-style texture paths for decoration system
local TARGET_TEXTURES = UF.TEXTURES.targetStyle

-- Check if we're currently in a vehicle
local function IsInVehicle()
    return UnitHasVehicleUI("player")
end

-- Check if fat healthbar is enabled in config (regardless of vehicle/decoration state)
local function IsFatConfigEnabled()
    local config = GetPlayerConfig()
    return config and config.fat_healthbar or false
end

-- Check if fat healthbar mode should be visually active right now
-- Fat mode is disabled during vehicle (reverts to normal vehicle frame)
local function IsFatHealthbarActive()
    if not IsFatConfigEnabled() then return false end
    -- Fat mode disabled during vehicle — show standard vehicle interface
    if IsInVehicle() then return false end
    return true
end

-- Get the correct BASE texture path (fat or normal, not vehicle — vehicle uses atlas)
local function GetBaseTexture()
    return IsFatHealthbarActive() and TEXTURES.BASE_FAT or TEXTURES.BASE
end

-- Get the correct BORDER texture path (fat or normal, not vehicle — vehicle uses atlas)
local function GetBorderTexture()
    return IsFatHealthbarActive() and TEXTURES.BORDER_FAT or TEXTURES.BORDER
end

-- Get the correct decoration BACKGROUND texture (target style, flipped for player)
-- When fat mode + decoration are both active, use fat variant
local function GetDecorationBackground()
    if IsFatConfigEnabled() and not IsInVehicle() then
        return TARGET_TEXTURES.BACKGROUND_FAT or TARGET_TEXTURES.BACKGROUND
    end
    return TARGET_TEXTURES.BACKGROUND
end

-- Get the correct decoration BORDER texture (target style, flipped for player)
-- When fat mode + decoration are both active, use fat variant
local function GetDecorationBorder()
    if IsFatConfigEnabled() and not IsInVehicle() then
        return TARGET_TEXTURES.BORDER_FAT or TARGET_TEXTURES.BORDER
    end
    return TARGET_TEXTURES.BORDER
end

-- Get fat mana bar configuration values
local function GetFatManaConfig()
    local config = GetPlayerConfig()
    if not config then return 200, 8, false end
    return config.fat_manabar_width or 200,
           config.fat_manabar_height or 8,
           config.fat_manabar_hidden or false
end

-- Mana bar texture override lookup (vanilla Blizzard textures available in 3.3.5a)
local MANABAR_TEXTURE_OVERRIDES = {
    blizzard       = "Interface\\TargetingFrame\\UI-StatusBar",
    blizzard_flat  = "Interface\\ChatFrame\\ChatFrameBackground",
    smooth         = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    aluminium      = "Interface\\BUTTONS\\WHITE8X8",
    litestep       = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight",
}

-- Dragonflight-style power bar colors (from RetailUI reference)
-- These are applied via SetStatusBarColor on vanilla override textures
-- which are neutral/grayscale and need explicit coloring.
local DF_POWER_COLORS = {
    ["MANA"]         = { r = 0.02, g = 0.32, b = 0.71 },
    ["RAGE"]         = { r = 1.00, g = 0.00, b = 0.00 },
    ["FOCUS"]        = { r = 1.00, g = 0.50, b = 0.25 },
    ["ENERGY"]       = { r = 1.00, g = 1.00, b = 0.00 },
    ["HAPPINESS"]    = { r = 0.00, g = 1.00, b = 1.00 },
    ["RUNES"]        = { r = 0.50, g = 0.50, b = 0.50 },
    ["RUNIC_POWER"]  = { r = 0.00, g = 0.82, b = 1.00 },
    ["AMMOSLOT"]     = { r = 0.80, g = 0.60, b = 0.00 },
    ["FUEL"]         = { r = 0.00, g = 0.55, b = 0.50 },
}

-- Get the correct power bar texture path, applying user texture override ONLY in fat mode
local function GetPowerBarTexture(powerTypeString)
    -- Override textures only apply when fat healthbar is active
    if IsFatHealthbarActive() then
        local config = GetPlayerConfig()
        local textureSetting = config and config.manabar_texture or "dragonui"
        if textureSetting ~= "dragonui" and MANABAR_TEXTURE_OVERRIDES[textureSetting] then
            return MANABAR_TEXTURE_OVERRIDES[textureSetting]
        end
    end
    
    -- Default DragonUI per-power-type textures (normal mode always uses these)
    return TEXTURES.POWER_BARS[powerTypeString] or TEXTURES.POWER_BARS.MANA
end

-- Create or get the fat mana bar anchor frame (for editor mode movability)
local function GetOrCreateFatManaAnchor()
    if Module.fatManaFrame then return Module.fatManaFrame end

    local width, height = GetFatManaConfig()
    Module.fatManaFrame = addon.CreateUIFrame(width, height + 4, "ManaBar")
    Module.fatManaFrame:SetFrameStrata("LOW")

    return Module.fatManaFrame
end

-- Apply fat mana bar position from widget config
local function ApplyFatManaPosition()
    if not Module.fatManaFrame then return end

    local widgetConfig = addon:GetConfigValue("widgets", "fat_manabar")
    if not widgetConfig then
        widgetConfig = { anchor = "TOPLEFT", posX = 187, posY = -9 }
    end

    Module.fatManaFrame:ClearAllPoints()
    Module.fatManaFrame:SetPoint(
        widgetConfig.anchor or "TOPLEFT", UIParent,
        widgetConfig.anchor or "TOPLEFT",
        widgetConfig.posX or 187, widgetConfig.posY or -9
    )
end

-- Apply fat mana bar config (size, visibility, position)
local function ApplyFatManaBar()
    local fatMode = IsFatHealthbarActive()
    local hasVehicleUI = UnitHasVehicleUI("player")

    if not fatMode then
        -- Normal mode: standard mana bar positioning (ignore fat settings)
        PlayerFrameManaBar:ClearAllPoints()
        PlayerFrameManaBar:SetSize(hasVehicleUI and 117 or 125, hasVehicleUI and 9 or 9)
        if hasVehicleUI then
            -- Vehicle: position relative to PlayerFrame (matches RetailUI pattern)
            PlayerFrameManaBar:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 114, -58.5)
        else
            -- Normal: position relative to portrait
            PlayerFrameManaBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -16.5)
        end
        PlayerFrameManaBar:Show()

        -- Hide the fat anchor if it exists
        if Module.fatManaFrame then
            Module.fatManaFrame:SetSize(1, 1)
        end
        return
    end

    -- Fat mode: check hidden state
    local width, height, hidden = GetFatManaConfig()
    if hidden then
        PlayerFrameManaBar:Hide()
        if Module.fatManaFrame then
            Module.fatManaFrame:SetSize(1, 1)
        end
        return
    end

    -- Fat mode: use configurable width/height and anchor frame
    PlayerFrameManaBar:Show()

    -- Create anchor if needed and apply position
    local anchor = GetOrCreateFatManaAnchor()
    anchor:SetSize(width, height + 4)
    ApplyFatManaPosition()

    -- Lazy-register in editor system if not already registered
    if not Module.fatManaRegistered and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "fat_manabar",
            frame = anchor,
            configPath = {"widgets", "fat_manabar"},
            editorVisible = function() return IsFatHealthbarActive() end,
            onHide = function()
                ApplyFatManaBar()
            end,
            module = Module
        })
        Module.fatManaRegistered = true
    end

    -- Parent mana bar to anchor frame
    PlayerFrameManaBar:ClearAllPoints()
    PlayerFrameManaBar:SetSize(hasVehicleUI and 117 or width, hasVehicleUI and 9 or height)
    PlayerFrameManaBar:SetPoint('CENTER', anchor, 'CENTER', 0, 0)
end

-- ============================================================================
-- BLIZZARD FRAME MANAGEMENT
-- ============================================================================
-- Hide Blizzard's original player frame texts permanently using alpha 0
local function HideBlizzardPlayerTexts()
    -- Get Blizzard's ORIGINAL text elements (not our custom ones)
    local blizzardTexts = { -- These are the actual Blizzard frame text elements in WoW 3.3.5a
    PlayerFrameHealthBar.TextString, PlayerFrameManaBar.TextString, -- Alternative names that might exist
    _G.PlayerFrameHealthBarText, _G.PlayerFrameManaBarText}

    -- Hide each BLIZZARD text element permanently with alpha 0 (ONE TIME SETUP)
    for _, textElement in pairs(blizzardTexts) do
        if textElement and not textElement.DragonUIHidden then
            -- Set alpha to 0 immediately (taint-free)
            textElement:SetAlpha(0)

            -- Phase 2: hooksecurefunc instead of direct .Show override to avoid taint
            hooksecurefunc(textElement, "Show", function(self)
                if not self.DragonUI_ShowGuard then
                    self.DragonUI_ShowGuard = true
                    self:SetAlpha(0)
                    self.DragonUI_ShowGuard = nil
                end
            end)

            -- Mark as processed to avoid duplicate setup
            textElement.DragonUIHidden = true
        end
    end
end
-- Hide and permanently disable Blizzard glow effects
local function HideBlizzardGlows()
    local glows = {PlayerStatusGlow, PlayerRestGlow}
    for _, glow in ipairs(glows) do
        if glow then
            glow:Hide()
            glow:SetAlpha(0)
            -- Permanent hook: prevent Blizzard from re-showing the resting glow
            if not glow.__DragonUI_GlowHooked and glow.HookScript then
                glow:HookScript("OnShow", function(self)
                    self:Hide()
                    self:SetAlpha(0)
                end)
                glow.__DragonUI_GlowHooked = true
            end
        end
    end
    -- Always suppress Blizzard's PlayerFrameFlash (combat red flash)
    -- UIFrameFlash drives alpha in an OnUpdate loop, so we must stop it here too
    if PlayerFrameFlash then
        PlayerFrameFlash:Hide()
        PlayerFrameFlash:SetAlpha(0)
        if UIFrameFlashStop then
            UIFrameFlashStop(PlayerFrameFlash)
        end
    end
end

-- Remove unwanted Blizzard frame elements
local function RemoveBlizzardFrames(isVehicle)
    -- NOTE: PlayerGuideIcon is intentionally NOT in this list — it's the LFG
    -- "dungeon leader" flag (shares LeaderIcon's anchor, shown instead of it for
    -- LFG-formed groups), not decorative clutter. See UpdateLeaderIconPosition().
    local elementsToHide = {"PlayerAttackIcon", "PlayerFrameBackground", "PlayerAttackBackground",
                            "PlayerFrameGroupIndicatorLeft", "PlayerFrameGroupIndicatorRight"}

    for _, name in ipairs(elementsToHide) do
        local obj = _G[name]
        if obj and not obj.__DragonUIHidden then
            obj:Hide()
            obj:SetAlpha(0)

            if obj.HookScript then
                obj:HookScript("OnShow", function(self)
                    self:Hide()
                    self:SetAlpha(0)
                end)
            end

            if obj.GetObjectType and obj:GetObjectType() == "Texture" and obj.SetTexture then
                obj:SetTexture(nil)
            end

            obj.__DragonUIHidden = true
        end
    end

    -- Hide standard frame textures (always hidden — we use our own custom textures)
    if PlayerFrameTexture then
        PlayerFrameTexture:SetAlpha(0)
    end
    -- Hide Blizzard's PlayerFrameBackground (global, not our DragonUI one)
    if PlayerFrameBackground then
        PlayerFrameBackground:SetAlpha(0)
    end

    -- Vehicle texture: toggle visibility only — positioning and atlas applied by
    -- UpdatePlayerDragonDecoration() which runs at the end of ChangePlayerframe()
    if PlayerFrameVehicleTexture then
        if isVehicle then
            PlayerFrameVehicleTexture:Show()
        else
            PlayerFrameVehicleTexture:SetAlpha(0)
        end
    end
end

-- ============================================================================
-- ELITE GLOW SYSTEM - Switch system

-- Check if elite mode is active based on dragon decoration
local function IsEliteModeActive()
    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    return decorationType == "elite" or decorationType == "rareelite"
end

-- Get combat flash configuration (enabled + opacity multiplier)
local function GetCombatFlashConfig()
    local config = GetPlayerConfig()
    local enabled = config.combat_flash_enabled ~= false -- default true
    local opacity = config.combat_flash_opacity or 1.0
    return enabled, opacity
end

-- Toggle glow visibility based on elite mode
local function UpdateGlowVisibility()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- Check if rest glow is disabled by user option
    local config = GetPlayerConfig()
    local restGlowEnabled = config.show_rest_glow ~= false -- default true

    -- Vehicle mode: DragonUI's custom glow textures (uiunitframe/uiunitframe-fat) don't
    -- match the vehicle border shape. Instead, use dedicated VehicleCombatFlash and
    -- VehicleStatusGlow frames which use the 209×89 vehicle atlas shape.
    -- This avoids conflict with Blizzard's UIFrameFlash system on PlayerFrameFlash.
    if IsInVehicle() then
        -- Suppress ALL normal/elite custom glows (wrong shape for vehicle frame)
        if dragonFrame.DragonUICombatGlow then
            dragonFrame.DragonUICombatGlow:Hide()
        end
        if dragonFrame.DragonUIStatusGlow then
            dragonFrame.DragonUIStatusGlow:Hide()
        end
        if dragonFrame.EliteStatusGlow then
            dragonFrame.EliteStatusGlow:Hide()
        end
        if dragonFrame.EliteCombatGlow then
            dragonFrame.EliteCombatGlow:Hide()
        end

        -- Suppress Blizzard's native flash/status to avoid UIFrameFlash conflicts
        if PlayerFrameFlash then
            PlayerFrameFlash:Hide()
            PlayerFrameFlash:SetAlpha(0)
        end
        if PlayerStatusTexture then
            PlayerStatusTexture:Hide()
            PlayerStatusTexture:SetAlpha(0)
        end

        -- Vehicle combat flash: dedicated DragonUI frame with vehicle atlas shape
        local combatFlashEnabled = GetCombatFlashConfig()
        if dragonFrame.VehicleCombatFlash then
            if combatGlowVisible and combatFlashEnabled then
                dragonFrame.VehicleCombatFlash:Show()
                dragonFrame.VehicleCombatTexture:SetAlpha(1)
            else
                dragonFrame.VehicleCombatFlash:Hide()
            end
        end

        -- Vehicle status (resting) glow: dedicated DragonUI frame with vehicle atlas shape
        if dragonFrame.VehicleStatusGlow then
            if statusGlowVisible and restGlowEnabled then
                dragonFrame.VehicleStatusGlow:Show()
                dragonFrame.VehicleStatusTexture:SetAlpha(1)
            else
                dragonFrame.VehicleStatusGlow:Hide()
            end
        end
        return
    end

    --  DragonUI always suppresses Blizzard's PlayerStatusTexture
    --  Custom glow is handled by DragonUIStatusGlow / EliteStatusGlow / VehicleStatusGlow
    if PlayerStatusTexture then
        PlayerStatusTexture:Hide()
        PlayerStatusTexture:SetAlpha(0)
    end

    eliteGlowActive = IsEliteModeActive()
    local combatFlashEnabled = GetCombatFlashConfig()

    if dragonFrame.DragonUICombatGlow then
        if eliteGlowActive then
            -- In elite mode: hide normal combat glow
            dragonFrame.DragonUICombatGlow:Hide()
            dragonFrame.DragonUICombatGlow:SetAlpha(0)
        else
            -- In normal mode: show/hide original glow based on combatGlowVisible
            dragonFrame.DragonUICombatGlow:SetAlpha(1) -- Restore alpha
            if combatGlowVisible and combatFlashEnabled then
                dragonFrame.DragonUICombatGlow:Show()
            else
                dragonFrame.DragonUICombatGlow:Hide()
            end
        end
    end

    -- Normal/fat status glow (only when NOT in elite mode)
    if dragonFrame.DragonUIStatusGlow then
        if not eliteGlowActive and statusGlowVisible and restGlowEnabled then
            dragonFrame.DragonUIStatusGlow:Show()
        else
            dragonFrame.DragonUIStatusGlow:Hide()
        end
    end

    -- Update elite glows (only in elite mode)
    if eliteGlowActive then
        if dragonFrame.EliteStatusGlow then
            if statusGlowVisible and restGlowEnabled then
                dragonFrame.EliteStatusGlow:Show()
            else
                dragonFrame.EliteStatusGlow:Hide()
            end
        end
        if dragonFrame.EliteCombatGlow then
            if combatGlowVisible and combatFlashEnabled then
                dragonFrame.EliteCombatGlow:Show()
            else
                dragonFrame.EliteCombatGlow:Hide()
            end
        end
    else
        -- Hide elite glows in normal mode
        if dragonFrame.EliteStatusGlow then
            dragonFrame.EliteStatusGlow:Hide()
        end
        if dragonFrame.EliteCombatGlow then
            dragonFrame.EliteCombatGlow:Hide()
        end
    end

    -- Hide vehicle glows when NOT in vehicle
    if dragonFrame.VehicleCombatFlash then
        dragonFrame.VehicleCombatFlash:Hide()
    end
    if dragonFrame.VehicleStatusGlow then
        dragonFrame.VehicleStatusGlow:Hide()
    end
end

-- Set status glow state (replaces original logic)
local function SetStatusGlowVisible(visible)
    statusGlowVisible = visible
    UpdateGlowVisibility()
end

-- Set combat glow state (replaces original logic)
local function SetEliteCombatFlashVisible(visible)
    combatGlowVisible = visible
    UpdateGlowVisibility()
end

-- ============================================================================
-- ANIMATION & VISUAL EFFECTS
-- ============================================================================

-- Animate texture coordinates for rest icon
local function AnimateTexCoords(texture, textureWidth, textureHeight, frameWidth, frameHeight, numFrames, elapsed,
    throttle)
    if not texture or not texture:IsVisible() then
        return
    end

    texture.animationTimer = (texture.animationTimer or 0) + elapsed
    if texture.animationTimer >= throttle then
        texture.animationFrame = ((texture.animationFrame or 0) + 1) % numFrames
        local col = texture.animationFrame % (textureWidth / frameWidth)
        local row = math.floor(texture.animationFrame / (textureWidth / frameWidth))

        local left = col * frameWidth / textureWidth
        local right = (col + 1) * frameWidth / textureWidth
        local top = row * frameHeight / textureHeight
        local bottom = (row + 1) * frameHeight / textureHeight

        texture:SetTexCoord(left, right, top, bottom)
        texture.animationTimer = 0
    end
end

-- Animate Combat Flash pulse effect
local function AnimateCombatFlashPulse(elapsed)
    if not COMBAT_PULSE_SETTINGS.enabled then
        return
    end

    local combatFlashEnabled, combatFlashOpacity = GetCombatFlashConfig()
    if not combatFlashEnabled then
        return
    end

    -- Vehicle mode: pulse dedicated VehicleCombatFlash (uses vehicle atlas shape)
    if IsInVehicle() then
        local dragonFrame = _G["DragonUIUnitframeFrame"]
        if dragonFrame and dragonFrame.VehicleCombatFlash and dragonFrame.VehicleCombatFlash:IsVisible() then
            combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)
            local pulseAlpha = COMBAT_PULSE_SETTINGS.minAlpha +
                                   (COMBAT_PULSE_SETTINGS.maxAlpha - COMBAT_PULSE_SETTINGS.minAlpha) *
                                   (math.sin(combatPulseTimer) * 0.5 + 0.5)
            dragonFrame.VehicleCombatTexture:SetAlpha(pulseAlpha * combatFlashOpacity)
        end
        return
    end

    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    if eliteGlowActive then
        -- Elite mode: use specific configuration for elite combat
        if not ELITE_COMBAT_PULSE_SETTINGS.enabled then
            return
        end

        combatPulseTimer = combatPulseTimer + (elapsed * ELITE_COMBAT_PULSE_SETTINGS.speed)

        local pulseAlpha = ELITE_COMBAT_PULSE_SETTINGS.minAlpha +
                               (ELITE_COMBAT_PULSE_SETTINGS.maxAlpha - ELITE_COMBAT_PULSE_SETTINGS.minAlpha) *
                               (math.sin(combatPulseTimer) * 0.5 + 0.5)

        if dragonFrame.EliteCombatGlow and dragonFrame.EliteCombatGlow:IsVisible() then
            dragonFrame.EliteCombatTexture:SetAlpha(pulseAlpha * combatFlashOpacity)
        end
    else
        -- Normal mode: use normal configuration
        if not COMBAT_PULSE_SETTINGS.enabled then
            return
        end

        combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)

        local pulseAlpha = COMBAT_PULSE_SETTINGS.minAlpha +
                               (COMBAT_PULSE_SETTINGS.maxAlpha - COMBAT_PULSE_SETTINGS.minAlpha) *
                               (math.sin(combatPulseTimer) * 0.5 + 0.5)

        if dragonFrame.DragonUICombatGlow and dragonFrame.DragonUICombatGlow:IsVisible() then
            dragonFrame.DragonUICombatTexture:SetAlpha(pulseAlpha * combatFlashOpacity)
        end
    end
end

-- Animate Status/Rest pulse effect (both normal and elite modes)
local function AnimateStatusPulse(elapsed)
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    -- Elite mode: pulse EliteStatusGlow
    if eliteGlowActive then
        if not ELITE_STATUS_PULSE_SETTINGS.enabled then return end
        if dragonFrame.EliteStatusGlow and dragonFrame.EliteStatusGlow:IsVisible() then
            eliteStatusPulseTimer = eliteStatusPulseTimer + (elapsed * ELITE_STATUS_PULSE_SETTINGS.speed)
            local pulseAlpha = ELITE_STATUS_PULSE_SETTINGS.minAlpha +
                                   (ELITE_STATUS_PULSE_SETTINGS.maxAlpha - ELITE_STATUS_PULSE_SETTINGS.minAlpha) *
                                   (math.sin(eliteStatusPulseTimer) * 0.5 + 0.5)
            dragonFrame.EliteStatusTexture:SetAlpha(pulseAlpha)
        end
    else
        -- Normal/fat mode: pulse DragonUIStatusGlow
        if not NORMAL_STATUS_PULSE_SETTINGS.enabled then return end
        if dragonFrame.DragonUIStatusGlow and dragonFrame.DragonUIStatusGlow:IsVisible() then
            eliteStatusPulseTimer = eliteStatusPulseTimer + (elapsed * NORMAL_STATUS_PULSE_SETTINGS.speed)
            local pulseAlpha = NORMAL_STATUS_PULSE_SETTINGS.minAlpha +
                                   (NORMAL_STATUS_PULSE_SETTINGS.maxAlpha - NORMAL_STATUS_PULSE_SETTINGS.minAlpha) *
                                   (math.sin(eliteStatusPulseTimer) * 0.5 + 0.5)
            dragonFrame.DragonUIStatusTexture:SetAlpha(pulseAlpha)
        end
    end
end

-- Frame update handler for animations
local function PlayerFrame_OnUpdate(self, elapsed)
    -- Rest icon animation
    if PlayerRestIcon and PlayerRestIcon:IsVisible() then
        AnimateTexCoords(PlayerRestIcon, 512, 512, 64, 64, 42, elapsed, 0.09)
    end

    -- Combat Flash pulse animation
    AnimateCombatFlashPulse(elapsed)

    -- Status/Rest pulse animation (normal and elite)
    AnimateStatusPulse(elapsed)
end

-- Override Blizzard status update to prevent glow interference
local function PlayerFrame_UpdateStatus()
    HideBlizzardGlows()
    -- Trigger status glow based on player state
    local isResting = IsResting()
    SetStatusGlowVisible(isResting)
end

-- ============================================================================
-- CLASS-SPECIFIC FEATURES
-- ============================================================================

-- Update Death Knight rune display
local function UpdateRune(button)
    if not button then
        return
    end

    local rune = button:GetID()
    local runeType = GetRuneType and GetRuneType(rune)

    if runeType and RUNE_COORDS[runeType] then
        local runeTexture = _G[button:GetName() .. "Rune"]
        if runeTexture then
            local texture = TEXTURES.RUNE_TEXTURE
            local coords = RUNE_COORDS[runeType]

            if runeType == RUNE_TYPE_DEATH then
                texture = TEXTURES.RUNE_TEXTURE_PURPLE
                coords = DEATH_RUNE_COORDS
            end

            runeTexture:SetTexture(texture)
            runeTexture:SetTexCoord(unpack(coords))
        end
    end
end

-- Setup Death Knight rune frame
local function SetupRuneFrame()
    -- WoW automatically handles rune availability for DKs
    -- No need to manually check the class

    for index = 1, 6 do
        local button = _G['RuneButtonIndividual' .. index]
        if button then
            button:ClearAllPoints()
            if index > 1 then
                button:SetPoint('LEFT', _G['RuneButtonIndividual' .. (index - 1)], 'RIGHT', 4, 0)
            else
                button:SetPoint('CENTER', PlayerFrame, 'BOTTOM', -10, 15)
            end
            UpdateRune(button)

            -- FIX: Hook each button's OnEvent to re-apply DragonUI texture
            -- AFTER Blizzard's built-in handler runs (HookScript fires post-original).
            -- This prevents Blizzard's handler from permanently overwriting our texture.
            if not button.__DragonUIRuneHooked then
                button:HookScript('OnEvent', function(self, event)
                    if event == 'RUNE_TYPE_UPDATE' then
                        UpdateRune(self)
                    end
                end)
                button.__DragonUIRuneHooked = true
            end
        end
    end
end

-- Handle Death Knight runes in vehicle transitions (like RetailUI)
local function HandleRuneFrameVehicleTransition(toVehicle)
    for index = 1, 6 do
        local button = _G['RuneButtonIndividual' .. index]
        if button then
            if toVehicle then
                button:Hide() -- Hide runes in vehicle
            else
                button:Show() -- Show runes outside vehicle
                UpdateRune(button) -- Update when exiting vehicle
            end
        end
    end
end

-- Update LFG role icon display
local function UpdatePlayerRoleIcon()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.PlayerRoleIcon then
        return
    end

    local iconTexture = dragonFrame.PlayerRoleIcon
    local isTank, isHealer, isDamage = UnitGroupRolesAssigned("player")

    if isTank then
        iconTexture:SetTexture(TEXTURES.LFG_ICONS)
        iconTexture:SetTexCoord(unpack(ROLE_COORDS.TANK))
        iconTexture:Show()
    elseif isHealer then
        iconTexture:SetTexture(TEXTURES.LFG_ICONS)
        iconTexture:SetTexCoord(unpack(ROLE_COORDS.HEALER))
        iconTexture:Show()
    elseif isDamage then
        iconTexture:SetTexture(TEXTURES.LFG_ICONS)
        iconTexture:SetTexCoord(unpack(ROLE_COORDS.DAMAGER))
        iconTexture:Show()
    else
        iconTexture:Hide()
    end
end

-- Update group indicator for raids
local function UpdateGroupIndicator()
    local groupIndicatorFrame = _G[PlayerFrame:GetName() .. 'GroupIndicator']
    local groupText = _G[PlayerFrame:GetName() .. 'GroupIndicatorText']

    if not groupIndicatorFrame or not groupText then
        return
    end

    groupIndicatorFrame:Hide()

    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers == 0 then
        return
    end

    for i = 1, numRaidMembers do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name and name == UnitName("player") then
            local groupFormat = _G.GROUP_NUMBER or "Group %d"
            groupText:SetText(string.format(groupFormat, subgroup))
            groupIndicatorFrame:Show()
            break
        end
    end
end

-- ============================================================================
-- LEADERSHIP & PVP ICONS MANAGEMENT
-- ============================================================================

-- Cache leadership and PVP icons
local PlayerLeaderIcon = _G.PlayerLeaderIcon
local PlayerGuideIcon = _G.PlayerGuideIcon
local PlayerMasterIcon = _G.PlayerMasterIcon
local PlayerPVPIcon = _G.PlayerPVPIcon

-- Update leader icon positioning based on dragon decoration mode
-- GuideIcon shares LeaderIcon's anchor point (Blizzard shows only one at a time:
-- GuideIcon for LFG-formed groups, LeaderIcon otherwise), so both need the same treatment.
local function UpdateLeaderIconPosition()
    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    local icons = {PlayerLeaderIcon, PlayerGuideIcon}

    for i = 1, 2 do
        local icon = icons[i]
        if icon then
            icon:ClearAllPoints()

            if isEliteMode then
                -- In elite mode: reparent to EliteIconContainer so the icon renders
                -- above the dragon decoration textures (strata HIGH, level 1000).
                -- Same pattern used by UpdateMasterIconPosition.
                if dragonFrame and dragonFrame.EliteIconContainer then
                    icon:SetParent(dragonFrame.EliteIconContainer)
                end
                icon:SetPoint('BOTTOM', PlayerFrame, "TOP", -1, -33)
            else
                -- Non-elite mode: STILL use EliteIconContainer so the icon renders
                -- above the portrait overlay (level +2) and border overlay (level +3).
                -- If we parented to PlayerFrame directly, the icon (a texture) would
                -- draw below all child overlay frames and be hidden behind the border.
                if dragonFrame and dragonFrame.EliteIconContainer then
                    icon:SetParent(dragonFrame.EliteIconContainer)
                end
                icon:SetPoint('BOTTOM', PlayerFrame, "TOP", -70, -25)
            end
        end
    end
end

-- Update master icon positioning based on dragon decoration mode
local function UpdateMasterIconPosition()
    if not PlayerMasterIcon then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"

    PlayerMasterIcon:ClearAllPoints()

    if isEliteMode then
        local iconContainer = _G["DragonUIUnitframeFrame"].EliteIconContainer
        PlayerMasterIcon:SetParent(iconContainer)
        PlayerMasterIcon:ClearAllPoints()
        PlayerMasterIcon:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -135, -55)
    else
        -- Non-elite mode: still use EliteIconContainer for correct layering
        local dragonFrame = _G["DragonUIUnitframeFrame"]
        if dragonFrame and dragonFrame.EliteIconContainer then
            PlayerMasterIcon:SetParent(dragonFrame.EliteIconContainer)
        end
        PlayerMasterIcon:SetPoint('BOTTOM', PlayerFrame, "TOP", -71, -75)
    end
end

-- Hide/show dragon decoration AND all glow effects for vehicle transitions.
-- The vehicle frame border has a different shape from normal/fat/elite, so
-- glow textures designed for those shapes must be suppressed in vehicle mode.
local function UpdateDragonVisibilityForVehicle(inVehicle, hasEliteDecoration)
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end
    
    -- Dragon decoration texture (only relevant with elite/rareelite decoration)
    if hasEliteDecoration and dragonFrame.PlayerDragonDecoration then
        dragonFrame.PlayerDragonDecoration:SetAlpha(inVehicle and 0 or 1)
    end
    
    -- Update glow visibility: switches between atlas-based glows (vehicle)
    -- and DragonUI custom glows (normal) based on current vehicle/combat/rest state
    UpdateGlowVisibility()
end

-- Function to raise the PVP timer above the dragon AND reposition it
local function UpdatePVPTimerPosition(isEliteMode)
    local pvpTimerText = _G["PlayerPVPTimerText"]
    if not pvpTimerText then
        return
    end
    
    -- ONLY modify if there's elite decoration (elite, rareelite, worldboss, etc.)
    if isEliteMode then
        -- With elite decoration: use the SAME parent as the PVP icon (already above)
        local dragonFrame = _G["DragonUIUnitframeFrame"]
        if dragonFrame and dragonFrame.EliteIconContainer then
            -- 1. Reparent to the same container as the PVP icon
            pvpTimerText:SetParent(dragonFrame.EliteIconContainer)
            pvpTimerText:SetDrawLayer("OVERLAY", 7)
            
            -- 2. Reposition the timer (adjust these coordinates as needed)
            pvpTimerText:ClearAllPoints()
            pvpTimerText:SetPoint("CENTER", PlayerPVPIcon, "LEFT", 22, 38)  -- To the left of the icon
            
            -- Optional: adjust text size for better visibility
            pvpTimerText:SetFont(pvpTimerText:GetFont(), 11, "OUTLINE")
        end
    end
    -- WITHOUT elite decoration: DO NOT touch anything, leave Blizzard's original parent, layer and position
end

local function UpdatePVPIconPosition()
    if not PlayerPVPIcon then
        return
    end

    -- FIX: Check that the frame exists before continuing
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame or not dragonFrame.EliteIconContainer then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
    local hasVehicleUI = UnitHasVehicleUI("player")

    local iconContainer = dragonFrame.EliteIconContainer
    PlayerPVPIcon:SetParent(iconContainer)
    PlayerPVPIcon:ClearAllPoints()

    if isEliteMode then
        -- Elite mode: specific position
        PlayerPVPIcon:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -155, -22)
    else
        -- Normal mode: differentiate between vehicle and player
        if hasVehicleUI then
            -- MODIFY VEHICLE POSITION HERE
            PlayerPVPIcon:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -149, -25)
        else
            -- Normal player position
            PlayerPVPIcon:SetPoint("TOPRIGHT", PlayerFrame, "TOPRIGHT", -155, -22)
        end
    end
    
    -- Reposition the PVP timer based on mode
    UpdatePVPTimerPosition(isEliteMode)
end

-- Master function to update all leadership icons positioning
local function UpdateLeadershipIcons()
    UpdateLeaderIconPosition()
    UpdateMasterIconPosition()
    UpdatePVPIconPosition()
end

-- ============================================================================
-- BAR COLOR & TEXTURE MANAGEMENT
-- ============================================================================
-- Update player health bar color and texture based on class color setting
local function UpdatePlayerHealthBarColor()
    if not PlayerFrameHealthBar then
        return
    end

    local config = GetPlayerConfig()
    local texture = PlayerFrameHealthBar:GetStatusBarTexture()

    if not texture then
        return
    end

    if config.classcolor then
        --  USE STATUS TEXTURE (WHITE) FOR CLASS COLOR
        local statusTexturePath = TEXTURES.HEALTH_STATUS
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end

        --  APPLY PLAYER CLASS COLOR
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        if color then
            PlayerFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b, 1)
        else
            PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
        end
    else
        --  USE NORMAL TEXTURE (COLORED) WITHOUT CLASS COLOR
        local normalTexturePath = TEXTURES.HEALTH_BAR
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end

        --  WHITE COLOR (texture already has color)
        PlayerFrameHealthBar:SetStatusBarColor(1, 1, 1, 1)
    end
end
-- Update health bar color and texture
local function UpdateHealthBarColor(statusBar, unit)
    if not unit then
        unit = "player"
    end
    if statusBar ~= PlayerFrameHealthBar or unit ~= "player" then
        return
    end

    --  CALL THE NEW FUNCTION
    UpdatePlayerHealthBarColor()
end

-- Update mana bar color based on texture mode:
-- DragonUI textures: force white (1,1,1) because color is baked into the texture.
-- Override textures: apply power colors from DB (user-customizable) or DF defaults.
-- (vanilla textures are neutral/grayscale and need explicit coloring).
local function UpdateManaBarColor(statusBar)
    if statusBar ~= PlayerFrameManaBar then return end

    local useOverride = IsFatHealthbarActive()
    if useOverride then
        local config = GetPlayerConfig()
        local textureSetting = config and config.manabar_texture or "dragonui"
        if textureSetting ~= "dragonui" then
            -- Override texture: use DB color if available, else fall back to DF defaults
            local _, powerToken = UnitPowerType('player')
            local dbColors = config and config.power_colors
            local color = (dbColors and dbColors[powerToken]) or DF_POWER_COLORS[powerToken] or DF_POWER_COLORS["MANA"]
            statusBar:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1)
            return
        end
    end
    -- DragonUI textures (or normal mode): force white so baked color shows
    statusBar:SetStatusBarColor(1, 1, 1)
end

-- Update power bar texture based on current power type (handles druid forms)
local function UpdatePowerBarTexture(statusBar)
    if statusBar ~= PlayerFrameManaBar then
        return
    end

    local powerType, powerTypeString = UnitPowerType('player')
    local powerTexture = GetPowerBarTexture(powerTypeString)

    --  CHANGE TEXTURE based on current power type
    local currentTexture = statusBar:GetStatusBarTexture():GetTexture()
    if currentTexture ~= powerTexture then
        statusBar:GetStatusBarTexture():SetTexture(powerTexture)
    end

    -- Update color after texture change (druid form shifts change power type)
    UpdateManaBarColor(statusBar)
end
-- ============================================================================
-- VEHICLE SYSTEM INTEGRATION
-- ============================================================================

-- Function to update textSystem unit based on vehicle state
local function UpdateTextSystemUnit()
    if not Module.textSystem then
        return
    end

    local hasVehicleUI = UnitHasVehicleUI("player")
    local targetUnit = hasVehicleUI and "vehicle" or "player"

    -- Update both the public unit field and internal reference
    Module.textSystem.unit = targetUnit
    if Module.textSystem._unitRef then
        Module.textSystem._unitRef.unit = targetUnit
    end

    -- Force immediate update
    if Module.textSystem.update then
        Module.textSystem.update()
    end
end

-- Create DragonUI text elements for alternate mana bar
local function SetupAlternateManaTextElements()
    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if not alternateManaBar or not addon.TextSystem then
        return
    end
    
    -- Create dual text elements using TextSystem
    addon.TextSystem.CreateDualTextElements(
        alternateManaBar, -- parentFrame
        alternateManaBar, -- barFrame (same as parent for this case)
        "AlternateMana", -- prefix
        "OVERLAY", -- layer
        "TextStatusBarText" -- font template
    )
end

-- Update alternate mana text using DragonUI TextSystem
local function UpdateAlternateManaText()
    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if not alternateManaBar or not addon.TextSystem then
        return
    end
    
    -- Get current mana values
    local currentMana = UnitPower("player", POWER_TYPE_MANA or 0)
    local maxMana = UnitPowerMax("player", POWER_TYPE_MANA or 0)
    
    if not currentMana or not maxMana or maxMana == 0 then
        return
    end
    
    -- Get configuration
    local config = GetPlayerConfig()
    local textFormat = config and config.alternateManaFormat or "both"
    local useBreakup = config and config.breakUpLargeNumbers
    
    -- Custom handling for alternate mana bar
    if textFormat == "both" then
        -- Custom separation for alternate mana bar - adjust spacing here
        local currentText = useBreakup and addon.TextSystem.AbbreviateLargeNumbers(currentMana) or tostring(currentMana)
        local percent = math.floor((currentMana / maxMana) * 100)
        local customSeparator = "    " -- Custom spacing for alternate mana bar (adjust here) 
        local combinedText = percent .. "%" .. customSeparator .. currentText
        
        -- Use as single text instead of dual
        addon.TextSystem.UpdateDualText(
            alternateManaBar,
            "AlternateMana",
            combinedText,
            "numeric", -- Treat as single text
            true -- shouldShow
        )
    else
        -- Use normal TextSystem for other formats
        local formattedText = addon.TextSystem.FormatStatusText(
            currentMana, 
            maxMana, 
            textFormat, 
            useBreakup, 
            "alternateMana"
        )
        
        addon.TextSystem.UpdateDualText(
            alternateManaBar,
            "AlternateMana",
            formattedText,
            textFormat,
            true -- shouldShow
        )
    end
end

-- Setup always visible behavior for DragonUI alternate mana text
local function SetupAlternateManaAlwaysVisible()
    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if not alternateManaBar then
        return
    end
    
    -- Phase 3C: Disable hover mode via flag (can't unhook HookScript)
    alternateManaBar.DragonUIHoverEnabled = false
    
    -- Show text immediately and keep it visible
    UpdateAlternateManaText()
end

-- Hide DragonUI alternate mana text elements
local function HideAlternateManaTextElements()
    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if not alternateManaBar or not addon.TextSystem then
        return
    end
    
    -- Hide all text elements
    addon.TextSystem.UpdateDualText(
        alternateManaBar,
        "AlternateMana", 
        "", 
        "numeric", 
        false -- shouldShow = false
    )
end

-- Setup hover-only behavior for DragonUI alternate mana text
local function SetupAlternateManaHoverBehavior()
    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if not alternateManaBar then
        return
    end
    
    -- Hide text initially
    HideAlternateManaTextElements()
    
    -- Phase 3C: Use HookScript instead of SetScript on Blizzard frame
    -- Hook only once, use flag to enable/disable behavior
    if not alternateManaBar.DragonUIHoverHooked then
        alternateManaBar:HookScript("OnEnter", function()
            if alternateManaBar.DragonUIHoverEnabled then
                UpdateAlternateManaText()
            end
        end)
        
        alternateManaBar:HookScript("OnLeave", function()
            if alternateManaBar.DragonUIHoverEnabled then
                HideAlternateManaTextElements()
            end
        end)
        alternateManaBar.DragonUIHoverHooked = true
    end
    
    alternateManaBar.DragonUIHoverEnabled = true
end

-- Setup alternate mana bar text system based on configuration
local function SetupAlternateManaBarAlwaysVisible()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "DRUID" then
        return
    end
    
    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if not alternateManaBar then
        return
    end
    
    -- ALWAYS hide Blizzard text - we always use DragonUI system for druids
    local blizzardText = alternateManaBar.TextString or _G.PlayerFrameAlternateManaBarText
    if blizzardText then
        blizzardText:Hide()
        blizzardText:SetAlpha(0)
    end
    
    -- ALWAYS setup DragonUI text elements for druids
    SetupAlternateManaTextElements()
    
    -- Get configuration to determine visibility behavior
    local config = GetPlayerConfig()
    local alwaysShow = config and config.alwaysShowAlternateManaText
    
    if alwaysShow then
        -- Show DragonUI text always
        UpdateAlternateManaText()
        SetupAlternateManaAlwaysVisible()
    else
        -- Show DragonUI text only on hover (default behavior)
        SetupAlternateManaHoverBehavior()
    end
end

-- ============================================================================
-- FRAME CREATION & CONFIGURATION
-- ============================================================================

-- Update decorative dragon for player frame
local function UpdatePlayerDragonDecoration()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        return
    end

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"

    -- Remove existing dragon if it exists
    if dragonFrame.PlayerDragonDecoration then
        if dragonFrame.PlayerDragonFrame then
            dragonFrame.PlayerDragonFrame:Hide()
            dragonFrame.PlayerDragonFrame = nil
        end
        dragonFrame.PlayerDragonDecoration = nil
    end

    --  Reposition rest icon in elite/dragon mode
    if PlayerRestIcon then
        if decorationType ~= "none" then
            -- Elite mode: move up and to the right
            PlayerRestIcon:ClearAllPoints()
            PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 60, 20)
        else
            -- Normal mode: original position
            PlayerRestIcon:ClearAllPoints()
            PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 40, 15) -- Original position
        end
    end

    --  Change background, border AND STRETCH MANA BAR based on decoration
    local inVehicle = IsInVehicle()

    if decorationType ~= "none" and not inVehicle then
        -- Dragon decoration active (and not in vehicle): use target textures (flipped) 
        -- GetDecorationBackground/Border will pick fat variant if fat is enabled
        local decorBg = GetDecorationBackground()
        local decorBorder = GetDecorationBorder()
        local fatMode = IsFatHealthbarActive()

        -- Fat mode shifts the health bar 6px lower; compensate so textures stay aligned
        -- Adjust these offsets to fine-tune fat+decoration positioning
        local bgX, bgY, bgW, bgH
        local borderX, borderY
        if fatMode then
            -- Fat + decoration: compensate for health bar's -6 Y shift
            bgX, bgY   = -121, -23.5   -- ←  Y here for fat+decoration background
            bgW, bgH    = 255, 130
            borderX, borderY = -121, -23.5   -- ← Y here for fat+decoration border
        else
            -- Normal decoration (no fat)
            bgX, bgY   = -128, -29.5
            bgW, bgH    = 255, 129
            borderX, borderY = -129, -29.5
        end

        if dragonFrame.PlayerFrameBackground then
            dragonFrame.PlayerFrameBackground:Show()
            dragonFrame.PlayerFrameBackground:SetTexture(decorBg)
            dragonFrame.PlayerFrameBackground:SetSize(bgW, bgH)
            dragonFrame.PlayerFrameBackground:SetTexCoord(1, 0, 0, 1) -- Flip horizontal for player

            dragonFrame.PlayerFrameBackground:ClearAllPoints()
            dragonFrame.PlayerFrameBackground:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', bgX, bgY)
        end
        if dragonFrame.PlayerFrameBorder then
            dragonFrame.PlayerFrameBorder:Show()
            dragonFrame.PlayerFrameBorder:SetTexture(decorBorder)
            dragonFrame.PlayerFrameBorder:SetTexCoord(1, 0, 0, 1) -- Flip horizontal for player
            dragonFrame.PlayerFrameBorder:SetSize(PLAYER_BORDER_WIDTH, PLAYER_BORDER_HEIGHT)

            dragonFrame.PlayerFrameBorder:ClearAllPoints()
            dragonFrame.PlayerFrameBorder:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', borderX, borderY)
        end

        -- Hide deco dot when dragon decoration is active
        if dragonFrame.PlayerFrameDeco then
            dragonFrame.PlayerFrameDeco:Hide()
        end

        -- Mana bar: fat mode uses its own anchor system, non-fat stretches for decoration
        if fatMode then
            -- Fat + decoration: stretch health bar leftward to cover gap (same idea as mana stretch in normal decoration)
            local normalHealthWidth = 125
            local extendedHealthWidth = 132
            local HP_OFFSET = 6
            PlayerFrameHealthBar:ClearAllPoints()
            PlayerFrameHealthBar:SetSize(extendedHealthWidth, 30)
            -- Anchor by RIGHT side so it stretches leftward, matching the mana pattern
            PlayerFrameHealthBar:SetPoint('RIGHT', PlayerPortrait, 'RIGHT', 1 + normalHealthWidth, -HP_OFFSET)

            -- === LAYER ORDER: Background < HealthBar < Portrait < Border ===
            -- HealthBar is a child frame of PlayerFrame (level +1).
            -- PlayerPortrait is a Texture on PlayerFrame — child frames always draw
            -- on top of parent textures, so we need overlay frames for portrait & border.

            -- Portrait overlay frame (level +2, above HealthBar)
            if not dragonFrame.PortraitOverlay then
                dragonFrame.PortraitOverlay = CreateFrame("Frame", nil, PlayerFrame)
                dragonFrame.PortraitOverlayTexture = dragonFrame.PortraitOverlay:CreateTexture(nil, "ARTWORK", nil, 2)
                dragonFrame.PortraitOverlayTexture:SetAllPoints()
            end
            dragonFrame.PortraitOverlay:SetFrameLevel(PlayerFrame:GetFrameLevel() + 2)
            dragonFrame.PortraitOverlay:ClearAllPoints()
            dragonFrame.PortraitOverlay:SetPoint("CENTER", PlayerPortrait, "CENTER", 0, 0)
            dragonFrame.PortraitOverlay:SetSize(56, 56)
            SetPortraitTexture(dragonFrame.PortraitOverlayTexture, "player")
            dragonFrame.PortraitOverlay:Show()

            -- Border overlay frame (level +3, above portrait)
            if not dragonFrame.BorderOverlay then
                dragonFrame.BorderOverlay = CreateFrame("Frame", nil, PlayerFrame)
                dragonFrame.BorderOverlay:SetAllPoints(PlayerFrame)
                dragonFrame.BorderOverlayTexture = dragonFrame.BorderOverlay:CreateTexture(nil, 'OVERLAY', nil, 5)
            end
            dragonFrame.BorderOverlay:SetFrameLevel(PlayerFrame:GetFrameLevel() + 3)
            dragonFrame.BorderOverlay:Show()

            -- Show border on overlay (above portrait), hide original border (on HealthBar level)
            dragonFrame.PlayerFrameBorder:Hide()
            dragonFrame.BorderOverlayTexture:SetTexture(decorBorder)
            dragonFrame.BorderOverlayTexture:SetTexCoord(1, 0, 0, 1)
            dragonFrame.BorderOverlayTexture:SetSize(PLAYER_BORDER_WIDTH, PLAYER_BORDER_HEIGHT)
            dragonFrame.BorderOverlayTexture:ClearAllPoints()
            dragonFrame.BorderOverlayTexture:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', borderX, borderY)
            dragonFrame.BorderOverlayTexture:Show()

            -- Keep class portraits on the same render plane as the active portrait texture.
            local pConfig = GetPlayerConfig()
            if pConfig and pConfig.classPortrait and not IsInVehicle() then
                if not UF.ApplyClassPortraitToTexture(
                    "player",
                    dragonFrame.PortraitOverlayTexture,
                    pConfig.alternativeClassIcons
                ) then
                    SetPortraitTexture(dragonFrame.PortraitOverlayTexture, "player")
                end
            else
                SetPortraitTexture(dragonFrame.PortraitOverlayTexture, "player")
            end

            dragonFrame.PortraitOverlay:SetAlpha(1)
            if dragonFrame.ClassPortraitOverlay then
                dragonFrame.ClassPortraitOverlay:Hide()
            end

            -- Fat + decoration: use the same fat mana anchor system as non-decoration
            ApplyFatManaBar()

            -- Fat + decoration: nudge health text right to compensate for leftward bar stretch
            -- TextSystem creates elements named PlayerFrameHealthTextLeft/Right (no "Bar")
            if dragonFrame.PlayerFrameHealthTextLeft then
                dragonFrame.PlayerFrameHealthTextLeft:ClearAllPoints()
                dragonFrame.PlayerFrameHealthTextLeft:SetPoint("LEFT", PlayerFrameHealthBar, "LEFT", 9, 0)
            end
            if dragonFrame.PlayerFrameHealthTextRight then
                dragonFrame.PlayerFrameHealthTextRight:ClearAllPoints()
                dragonFrame.PlayerFrameHealthTextRight:SetPoint("RIGHT", PlayerFrameHealthBar, "RIGHT", -3, 0)
            end
        elseif PlayerFrameManaBar then
            -- Normal (non-fat) decoration: stretch mana bar to fit decoration frame
            local normalWidth = 125
            local extendedWidth = 131

            PlayerFrameManaBar:ClearAllPoints()
            PlayerFrameManaBar:SetSize(extendedWidth, 9)
            -- Anchor by RIGHT side so it stretches leftward
            PlayerFrameManaBar:SetPoint('RIGHT', PlayerPortrait, 'RIGHT', 1 + normalWidth, -16.5)
        end
        -- Normal (non-fat) decoration: hide overlay frames (not needed without fat)
        if not fatMode then
            if dragonFrame.PortraitOverlay then dragonFrame.PortraitOverlay:Hide() end
            if dragonFrame.BorderOverlay then dragonFrame.BorderOverlay:Hide() end
            if dragonFrame.ClassPortraitOverlay then dragonFrame.ClassPortraitOverlay:Hide() end
        end

        -- Raise PlayerHitIndicator above decoration/dragon overlays.
        -- PlayerHitIndicator is a FontString on PlayerFrame (combat feedback: heals/damage).
        -- Border and dragon decoration are on higher-level frames and cover it.
        local hitIndicator = _G["PlayerHitIndicator"]
        if hitIndicator then
            if not dragonFrame.HitIndicatorFrame then
                local hif = CreateFrame("Frame", nil, PlayerFrame)
                hif:SetSize(100, 100)
                dragonFrame.HitIndicatorFrame = hif
            end
            -- HIGH strata to render above dragon decoration (MEDIUM strata)
            -- Level PlayerFrame+11 to render above EliteIconContainer (level+10) which holds PVP icon
            dragonFrame.HitIndicatorFrame:SetFrameStrata("MEDIUM")
            dragonFrame.HitIndicatorFrame:SetFrameLevel(PlayerFrame:GetFrameLevel() + 11)
            dragonFrame.HitIndicatorFrame:ClearAllPoints()
            dragonFrame.HitIndicatorFrame:SetPoint("CENTER", PlayerPortrait, "CENTER", 0, 0)
            dragonFrame.HitIndicatorFrame:Show()
            hitIndicator:SetParent(dragonFrame.HitIndicatorFrame)
            hitIndicator:ClearAllPoints()
            hitIndicator:SetPoint("CENTER", dragonFrame.HitIndicatorFrame, "CENTER", 0, 0)
        end
    else
        -- No dragon decoration, OR in vehicle: use normal/fat/vehicle textures
        local fatMode = IsFatHealthbarActive() -- false during vehicle

        -- Hide fat+decoration overlay frames (not needed without decoration)
        if dragonFrame.PortraitOverlay then dragonFrame.PortraitOverlay:Hide() end
        if dragonFrame.BorderOverlay then dragonFrame.BorderOverlay:Hide() end
        if dragonFrame.ClassPortraitOverlay then dragonFrame.ClassPortraitOverlay:Hide() end

        -- Raise PlayerHitIndicator above border (lives on HealthBar at level+1).
        -- No HIGH strata needed here — just a higher frame level than the border.
        local hitIndicator = _G["PlayerHitIndicator"]
        if hitIndicator then
            if not dragonFrame.HitIndicatorFrame then
                local hif = CreateFrame("Frame", nil, PlayerFrame)
                hif:SetSize(100, 100)
                dragonFrame.HitIndicatorFrame = hif
            end
            -- MEDIUM strata + level PlayerFrame+11 to render above EliteIconContainer (level+10)
            -- which holds the PVP icon
            dragonFrame.HitIndicatorFrame:SetFrameStrata("MEDIUM")
            dragonFrame.HitIndicatorFrame:SetFrameLevel(PlayerFrame:GetFrameLevel() + 11)
            dragonFrame.HitIndicatorFrame:ClearAllPoints()
            dragonFrame.HitIndicatorFrame:SetPoint("CENTER", PlayerPortrait, "CENTER", 0, 0)
            dragonFrame.HitIndicatorFrame:Show()
            hitIndicator:SetParent(dragonFrame.HitIndicatorFrame)
            hitIndicator:ClearAllPoints()
            hitIndicator:SetPoint("CENTER", dragonFrame.HitIndicatorFrame, "CENTER", 0, 0)
        end

        if inVehicle then
            -- VEHICLE MODE: Use atlas on Blizzard's PlayerFrameVehicleTexture (RetailUI pattern)
            -- This is more reliable than custom textures which can be hidden by Blizzard's frame management
            if PlayerFrameVehicleTexture then
                PlayerFrameVehicleTexture:ClearAllPoints()
                PlayerFrameVehicleTexture:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 35, 0)
                PlayerFrameVehicleTexture:set_atlas('PlayerFrame-TextureFrame-Vehicle', true)
                PlayerFrameVehicleTexture:SetDrawLayer('BORDER') -- Below flash/status OVERLAY
                PlayerFrameVehicleTexture:SetBlendMode('BLEND') -- Normal rendering (not ADD)
                PlayerFrameVehicleTexture:SetVertexColor(1, 1, 1, 1) -- No tint
                PlayerFrameVehicleTexture:Show()
                PlayerFrameVehicleTexture:SetAlpha(1)
            end

            -- Hide our custom bg/border (designed for normal player frame, not vehicle layout)
            if dragonFrame.PlayerFrameBackground then
                dragonFrame.PlayerFrameBackground:Hide()
            end
            if dragonFrame.PlayerFrameBorder then
                dragonFrame.PlayerFrameBorder:Hide()
            end
            if dragonFrame.PlayerFrameDeco then
                dragonFrame.PlayerFrameDeco:Hide()
            end

            -- Hide combat glow in vehicle
            if dragonFrame.DragonUICombatGlow then
                dragonFrame.DragonUICombatGlow:Hide()
            end

            -- Standard vehicle mana bar positioning
            ApplyFatManaBar() -- IsFatHealthbarActive() is false → normal positioning
        else
            -- NORMAL / FAT MODE (no vehicle): show our custom bg/border
            local baseTexture = GetBaseTexture()
            local borderTexture = GetBorderTexture()
            local HP_OFFSET = fatMode and 6 or 0

            if dragonFrame.PlayerFrameBackground then
                dragonFrame.PlayerFrameBackground:Show()
                dragonFrame.PlayerFrameBackground:SetTexture(baseTexture)
                dragonFrame.PlayerFrameBackground:SetTexCoord(0.7890625, 0.982421875, 0.001953125, 0.140625)
                dragonFrame.PlayerFrameBackground:SetSize(198, 71)

                dragonFrame.PlayerFrameBackground:ClearAllPoints()
                dragonFrame.PlayerFrameBackground:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, 0 + HP_OFFSET)
            end
            if dragonFrame.PlayerFrameBorder then
                dragonFrame.PlayerFrameBorder:Show()
                dragonFrame.PlayerFrameBorder:SetTexture(borderTexture)
                dragonFrame.PlayerFrameBorder:SetTexCoord(0, 1, 0, 1)
                dragonFrame.PlayerFrameBorder:SetSize(PLAYER_BORDER_WIDTH, PLAYER_BORDER_HEIGHT)

                dragonFrame.PlayerFrameBorder:ClearAllPoints()
                dragonFrame.PlayerFrameBorder:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5 + HP_OFFSET)
            end

            -- Update combat and status glow textures to match fat/normal mode
            if dragonFrame.DragonUICombatTexture then
                dragonFrame.DragonUICombatTexture:SetTexture(baseTexture)
            end
            if dragonFrame.DragonUIStatusTexture then
                dragonFrame.DragonUIStatusTexture:SetTexture(baseTexture)
            end

            -- Show deco dot when no dragon decoration
            if dragonFrame.PlayerFrameDeco then
                dragonFrame.PlayerFrameDeco:Show()
            end

            -- Adjust mana bar for fat/normal mode
            ApplyFatManaBar()
        end

    end

    -- Don't create dragon if decoration is disabled or currently in vehicle
    if decorationType == "none" or inVehicle then
        return
    end

    -- Get dragon coordinates
    local coords = DRAGON_COORDINATES[decorationType]
    if not coords then

        return
    end

    -- Create HIGH strata frame for dragon (parented to PlayerFrame for scaling)
    local dragonParent = CreateFrame("Frame", nil, PlayerFrame)
    dragonParent:SetFrameStrata("MEDIUM")
    dragonParent:SetFrameLevel(1)
    dragonParent:SetSize(coords.size[1], coords.size[2])
    dragonParent:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", -coords.offset[1] + 29.5, coords.offset[2] - 5)

    -- Create dragon texture in high strata frame
    local dragon = dragonParent:CreateTexture(nil, "OVERLAY")
    dragon:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\uiunitframeboss2x")
    dragon:SetTexCoord(coords.texCoord[1], coords.texCoord[2], coords.texCoord[3], coords.texCoord[4])
    dragon:SetAllPoints(dragonParent)

    -- Store references
    dragonFrame.PlayerDragonFrame = dragonParent
    dragonFrame.PlayerDragonDecoration = dragon

    -- If dark mode is active, re-apply tint to newly created dragon decoration
    if addon.RefreshDarkModeUnitFrames then
        addon.RefreshDarkModeUnitFrames()
    end

    UpdateLeadershipIcons() -- Reposition leadership icons

end

-- Create custom DragonUI textures and elements
local function CreatePlayerFrameTextures()
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if not dragonFrame then
        dragonFrame = CreateFrame('FRAME', 'DragonUIUnitframeFrame', UIParent)

    end

    HideBlizzardGlows()

    if not dragonFrame.EliteIconContainer then
        local iconContainer = CreateFrame("Frame", "DragonUI_EliteIconContainer", PlayerFrame)
        iconContainer:SetFrameStrata("MEDIUM")
        iconContainer:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)
        iconContainer:SetSize(200, 200)
        iconContainer:SetPoint("CENTER", PlayerFrame, "CENTER", 0, 0)
        dragonFrame.EliteIconContainer = iconContainer
    end

    if not dragonFrame.DragonUICombatGlow then
        local combatFlashFrame = CreateFrame("Frame", "DragonUICombatFlash", PlayerFrame)
        combatFlashFrame:SetFrameStrata("LOW")
        combatFlashFrame:SetFrameLevel(900)
        combatFlashFrame:SetSize(192, 71)
        combatFlashFrame:Hide()

        local combatTexture = combatFlashFrame:CreateTexture(nil, "OVERLAY")
        combatTexture:SetTexture(GetBaseTexture())
        combatTexture:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)
        combatTexture:SetAllPoints(combatFlashFrame)
        combatTexture:SetBlendMode("ADD")
        combatTexture:SetVertexColor(1.0, 0.0, 0.0, 1.0)

        dragonFrame.DragonUICombatGlow = combatFlashFrame
        dragonFrame.DragonUICombatTexture = combatTexture

    end

    -- CREATE NORMAL STATUS GLOW (rest glow for normal/fat mode, no elite)
    if not dragonFrame.DragonUIStatusGlow then
        local statusGlowFrame = CreateFrame("Frame", "DragonUIStatusGlow", PlayerFrame)
        statusGlowFrame:SetFrameStrata("LOW")
        statusGlowFrame:SetFrameLevel(998)
        statusGlowFrame:SetSize(192, 71)
        statusGlowFrame:Hide()

        local statusGlowTexture = statusGlowFrame:CreateTexture(nil, "OVERLAY")
        statusGlowTexture:SetTexture(GetBaseTexture()) -- uses uiunitframe or uiunitframe-fat
        statusGlowTexture:SetTexCoord(0.1943359375, 0.3818359375, 0.169921875, 0.30859375)
        statusGlowTexture:SetAllPoints(statusGlowFrame)
        statusGlowTexture:SetBlendMode("ADD")
        statusGlowTexture:SetVertexColor(1.0, 0.82, 0.0, 0.6) -- Gold/yellow for resting

        dragonFrame.DragonUIStatusGlow = statusGlowFrame
        dragonFrame.DragonUIStatusTexture = statusGlowTexture
    end

    -- CREATE ELITE GLOW SYSTEM - Two glows using ELITE_GLOW_COORDINATES
    if not dragonFrame.EliteStatusGlow then
        -- Elite Status Glow (Yellow)
        local statusFrame = CreateFrame("Frame", "DragonUIEliteStatusGlow", PlayerFrame)
        statusFrame:SetFrameStrata("LOW")
        statusFrame:SetFrameLevel(998)
        statusFrame:SetSize(ELITE_GLOW_COORDINATES.size[1], ELITE_GLOW_COORDINATES.size[2])
        statusFrame:Hide()

        local statusTexture = statusFrame:CreateTexture(nil, "OVERLAY")
        statusTexture:SetTexture(ELITE_GLOW_COORDINATES.texture) --  Use from coordinates
        statusTexture:SetTexCoord(unpack(ELITE_GLOW_COORDINATES.texCoord))
        statusTexture:SetAllPoints(statusFrame)
        statusTexture:SetBlendMode("ADD")
        statusTexture:SetVertexColor(1.0, 0.8, 0.2, 0.6) -- Yellow

        dragonFrame.EliteStatusGlow = statusFrame
        dragonFrame.EliteStatusTexture = statusTexture

        -- Elite Combat Glow (Red with pulse)
        local combatFrame = CreateFrame("Frame", "DragonUIEliteCombatGlow", PlayerFrame)
        combatFrame:SetFrameStrata("LOW")
        combatFrame:SetFrameLevel(900)
        combatFrame:SetSize(ELITE_GLOW_COORDINATES.size[1], ELITE_GLOW_COORDINATES.size[2])
        combatFrame:Hide()

        local eliteCombatTexture = combatFrame:CreateTexture(nil, "OVERLAY")
        eliteCombatTexture:SetTexture(ELITE_GLOW_COORDINATES.texture) --  Use from coordinates
        eliteCombatTexture:SetTexCoord(unpack(ELITE_GLOW_COORDINATES.texCoord))
        eliteCombatTexture:SetAllPoints(combatFrame)
        eliteCombatTexture:SetBlendMode("ADD")
        eliteCombatTexture:SetVertexColor(1.0, 0.0, 0.0, 1.0) -- Red

        dragonFrame.EliteCombatGlow = combatFrame
        dragonFrame.EliteCombatTexture = eliteCombatTexture

    end

    -- CREATE VEHICLE GLOW SYSTEM - Dedicated frames for vehicle combat/status effects.
    -- Vehicle border (PlayerFrame-TextureFrame-Vehicle, 209×89) has a different shape than
    -- normal/fat/elite frames. Using dedicated frames avoids conflict with Blizzard's
    -- UIFrameFlash system which controls PlayerFrameFlash independently.
    if not dragonFrame.VehicleCombatFlash then
        local vehicleCombatFrame = CreateFrame("Frame", "DragonUIVehicleCombatFlash", PlayerFrame)
        vehicleCombatFrame:SetFrameStrata("MEDIUM")
        vehicleCombatFrame:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)
        vehicleCombatFrame:SetSize(209, 89) -- Vehicle atlas dimensions
        vehicleCombatFrame:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 35, 0)
        vehicleCombatFrame:Hide()

        local vehicleCombatTexture = vehicleCombatFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        vehicleCombatTexture:set_atlas('PlayerFrame-TextureFrame-Vehicle', true)
        vehicleCombatTexture:ClearAllPoints()
        vehicleCombatTexture:SetPoint('TOPLEFT', vehicleCombatFrame, 'TOPLEFT', 0, 0)
        vehicleCombatTexture:SetBlendMode("ADD")
        vehicleCombatTexture:SetVertexColor(1.0, 0.0, 0.0, 1.0) -- Red for combat

        dragonFrame.VehicleCombatFlash = vehicleCombatFrame
        dragonFrame.VehicleCombatTexture = vehicleCombatTexture
    end

    if not dragonFrame.VehicleStatusGlow then
        local vehicleStatusFrame = CreateFrame("Frame", "DragonUIVehicleStatusGlow", PlayerFrame)
        vehicleStatusFrame:SetFrameStrata("MEDIUM")
        vehicleStatusFrame:SetFrameLevel(PlayerFrame:GetFrameLevel() + 10)
        vehicleStatusFrame:SetSize(209, 89) -- Vehicle atlas dimensions
        vehicleStatusFrame:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 35, 0)
        vehicleStatusFrame:Hide()

        local vehicleStatusTexture = vehicleStatusFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        vehicleStatusTexture:set_atlas('PlayerFrame-TextureFrame-Vehicle', true)
        vehicleStatusTexture:ClearAllPoints()
        vehicleStatusTexture:SetPoint('TOPLEFT', vehicleStatusFrame, 'TOPLEFT', 0, 0)
        vehicleStatusTexture:SetBlendMode("ADD")
        vehicleStatusTexture:SetVertexColor(1.0, 0.85, 0.0, 0.6) -- Yellow for resting

        dragonFrame.VehicleStatusGlow = vehicleStatusFrame
        dragonFrame.VehicleStatusTexture = vehicleStatusTexture
    end

    -- Create background texture
    if not dragonFrame.PlayerFrameBackground then
        local background = PlayerFrame:CreateTexture('DragonUIPlayerFrameBackground')
        background:SetDrawLayer('BACKGROUND', 2)
        background:SetTexture(GetBaseTexture())
        background:SetTexCoord(0.7890625, 0.982421875, 0.001953125, 0.140625)
        background:SetSize(198, 71)
        background:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, 0)
        dragonFrame.PlayerFrameBackground = background
    end

    -- Create border texture
    if not dragonFrame.PlayerFrameBorder then
        local border = PlayerFrameHealthBar:CreateTexture('DragonUIPlayerFrameBorder')
        border:SetDrawLayer('OVERLAY', 5)
        border:SetTexture(GetBorderTexture())
        border:SetSize(PLAYER_BORDER_WIDTH, PLAYER_BORDER_HEIGHT)
        border:SetPoint('LEFT', PlayerFrameHealthBar, 'LEFT', -67, -28.5)
        dragonFrame.PlayerFrameBorder = border
    end

    -- Create decoration texture
    if not dragonFrame.PlayerFrameDeco then
        local deco = PlayerFrame:CreateTexture('DragonUIPlayerFrameDeco')
        deco:SetDrawLayer('OVERLAY', 5)
        deco:SetTexture(PLAYER_CORNER_TEXTURE)
        deco:SetTexCoord(unpack(PLAYER_CORNER_TEX_COORDS))
        deco:SetPoint('CENTER', PlayerPortrait, 'CENTER', 15.5, -16)
        deco:SetSize(23, 23)
        dragonFrame.PlayerFrameDeco = deco
    end

    -- Setup rest icon
    if not dragonFrame.PlayerRestIconOverride then
        PlayerRestIcon:SetTexture(TEXTURES.REST_ICON)
        PlayerRestIcon:ClearAllPoints()
        PlayerRestIcon:SetPoint("TOPLEFT", PlayerPortrait, "TOPLEFT", 40, 15)
        PlayerRestIcon:SetSize(28, 28)
        PlayerRestIcon:SetTexCoord(0, 0.125, 0, 0.125) -- First frame
        dragonFrame.PlayerRestIconOverride = true
    end

    -- Create group indicator
    if not dragonFrame.PlayerGroupIndicator then
        local groupIndicator = CreateFrame("Frame", "DragonUIPlayerGroupIndicator", PlayerFrame)

        --  USE uiunitframe texture like RetailUI
        local bgTexture = groupIndicator:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetTexture(TEXTURES.BASE) -- Tu textura uiunitframe
        bgTexture:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625) --  GroupIndicator coordinates
        bgTexture:SetAllPoints(groupIndicator)

        --  FIXED SIZING as per coordinates
        groupIndicator:SetSize(71, 13)
        groupIndicator:SetPoint("BOTTOMLEFT", PlayerFrame, "TOP", 30, -19.5)

        --  CENTERED TEXT like original
        local text = groupIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", groupIndicator, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetTextColor(1, 1, 1, 1)
        text:SetFont(UF.DEFAULT_FONT, 9)
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)

        groupIndicator.text = text
        groupIndicator.backgroundTexture = bgTexture
        groupIndicator:Hide()

        _G[PlayerFrame:GetName() .. 'GroupIndicator'] = groupIndicator
        _G[PlayerFrame:GetName() .. 'GroupIndicatorText'] = text
        _G[PlayerFrame:GetName() .. 'GroupIndicatorMiddle'] = bgTexture --  Like original
        dragonFrame.PlayerGroupIndicator = groupIndicator
    end

    -- Create role icon
    if not dragonFrame.PlayerRoleIcon then
        local roleIcon = PlayerFrame:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(18, 18)
        roleIcon:SetPoint("TOPRIGHT", PlayerPortrait, "TOPRIGHT", -2, -2)
        roleIcon:Hide()
        dragonFrame.PlayerRoleIcon = roleIcon
    end

    -- Create text elements for health and mana bars
    local textElements = {{
        name = "PlayerFrameHealthBarTextLeft",
        parent = PlayerFrameHealthBar,
        point = "LEFT",
        x = 6,
        y = 0,
        justify = "LEFT"
    }, {
        name = "PlayerFrameHealthBarTextRight",
        parent = PlayerFrameHealthBar,
        point = "RIGHT",
        x = -6,
        y = 0,
        justify = "RIGHT"
    }, {
        name = "PlayerFrameManaBarTextLeft",
        parent = PlayerFrameManaBar,
        point = "LEFT",
        x = 6,
        y = 0,
        justify = "LEFT"
    }, {
        name = "PlayerFrameManaBarTextRight",
        parent = PlayerFrameManaBar,
        point = "RIGHT",
        x = -6,
        y = 0,
        justify = "RIGHT"
    }}

    for _, elem in ipairs(textElements) do
        if not dragonFrame[elem.name] then
            local text = elem.parent:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            local font, size, flags = text:GetFont()
            if font and size then
                text:SetFont(font, size + 1, flags)
            end
            text:SetPoint(elem.point, elem.parent, elem.point, elem.x, elem.y)
            text:SetJustifyH(elem.justify)
            dragonFrame[elem.name] = text
        end
    end
    -- NOTE: UpdatePlayerDragonDecoration() is called at the end of ChangePlayerframe()
    -- to ensure all bar/portrait positioning is done before decoration is applied
end

-- ============================================================================
-- CLASS PORTRAIT SYSTEM
-- ============================================================================

-- Class icon texture coordinates (matches WoW's CLASS_ICON_TCOORDS)
-- NOTE: CLASS_ICON_TEXTURE is declared at top of file (before UpdatePlayerDragonDecoration)

local function RestorePlayerPortraitTexture()
    -- Skip in vehicle mode: Blizzard controls the vehicle portrait texture.
    if not IsInVehicle() then
        PlayerPortrait:SetDrawLayer("ARTWORK", 2)
        SetPortraitTexture(PlayerPortrait, "player")
        PlayerPortrait:SetTexCoord(0, 1, 0, 1)
    end
    PlayerPortrait:SetAlpha(1)
end

-- Apply class portrait if enabled in config
local function UpdatePlayerClassPortrait()
    local config = GetPlayerConfig()
    if not config then return end

    local useClassPortrait = config.classPortrait and not IsInVehicle()
    if useClassPortrait and UF.ApplyClassPortraitToTexture(
        "player",
        PlayerPortrait,
        config.alternativeClassIcons
    ) then
        local dragonFrame = _G["DragonUIUnitframeFrame"]
        if dragonFrame and dragonFrame.ClassPortraitOverlay then
            dragonFrame.ClassPortraitOverlay:Hide()
        end
        return
    end

    RestorePlayerPortraitTexture()

    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and dragonFrame.ClassPortraitOverlay then
        dragonFrame.ClassPortraitOverlay:Hide()
    end
end

local function RefreshPlayerPortraitState(unit)
    local portraitUnit = unit == "vehicle" and "vehicle" or "player"

    UpdatePlayerClassPortrait()

    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and dragonFrame.PortraitOverlayTexture
       and dragonFrame.PortraitOverlay
       and dragonFrame.PortraitOverlay:IsShown() then
        local pConfig = GetPlayerConfig()
        if pConfig and pConfig.classPortrait and not IsInVehicle() and portraitUnit ~= "vehicle" then
            if not UF.ApplyClassPortraitToTexture(
                "player",
                dragonFrame.PortraitOverlayTexture,
                pConfig.alternativeClassIcons
            ) then
                SetPortraitTexture(dragonFrame.PortraitOverlayTexture, portraitUnit)
            end
        else
            SetPortraitTexture(dragonFrame.PortraitOverlayTexture, portraitUnit)
        end
    end
end

-- Main frame configuration function
local function ChangePlayerframe()
    CreatePlayerFrameTextures()

    local hasVehicleUI = IsInVehicle()

    RemoveBlizzardFrames(hasVehicleUI)
    HideBlizzardGlows()

    -- Configure portrait with vehicle-specific positioning
    PlayerPortrait:ClearAllPoints()
    PlayerPortrait:SetDrawLayer('ARTWORK', 2)  -- Lower layer so border is on top
    
    if hasVehicleUI then
        -- Vehicle: position relative to PlayerFrame (matches RetailUI pattern)
        PlayerPortrait:SetPoint('LEFT', PlayerFrame, 'LEFT', 45, 5)
        PlayerPortrait:SetSize(69, 69)
    else
        -- Normal player position
        PlayerPortrait:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 42, -15)
        PlayerPortrait:SetSize(56, 56)
    end
    
    -- Apply class portrait if enabled
    UpdatePlayerClassPortrait()

    -- Position name and level (shifted right in vehicle due to larger portrait)
    -- Ensure name/level are on OVERLAY draw layer so they render above vehicle textures
    PlayerName:SetDrawLayer('OVERLAY', 7)
    PlayerName:ClearAllPoints()
    if hasVehicleUI then
        PlayerName:SetJustifyH("LEFT")
        PlayerName:SetWidth(90)
        PlayerName:SetPoint('CENTER', PlayerFrame, 'CENTER', 50, 20)
    else
        local pConfig = GetPlayerConfig()
        local decorationType = pConfig.dragon_decoration or "none"
        local isPlayerEliteMode = decorationType == "elite" or decorationType == "rareelite"
        if isPlayerEliteMode then
            -- Dragon decoration mode: center the name above the health bar
            PlayerName:SetJustifyH("CENTER")
            PlayerName:SetWidth(110)
            PlayerName:SetPoint('BOTTOM', PlayerFrameHealthBar, 'TOP', 0, 2)
        else
            -- Normal mode: left-aligned above health bar
            PlayerName:SetJustifyH("LEFT")
            PlayerName:SetWidth(90)
            PlayerName:SetPoint('BOTTOMLEFT', PlayerFrameHealthBar, 'TOPLEFT', 12, 2)
        end
    end
    -- Force name visible — Blizzard vehicle transition can hide it
    PlayerName:SetAlpha(1)
    PlayerName:Show()

    PlayerLevelText:SetDrawLayer('OVERLAY', 7)
    PlayerLevelText:ClearAllPoints()
    PlayerLevelText:SetPoint('BOTTOMRIGHT', PlayerFrameHealthBar, 'TOPRIGHT', -5, 3)
    PlayerLevelText:SetAlpha(1)
    PlayerLevelText:Show()

    -- Configure health bar (fat mode uses full-width bar, vehicle uses standard)
    local fatMode = IsFatHealthbarActive() -- false during vehicle
    local HP_OFFSET = fatMode and 6 or 0
    PlayerFrameHealthBar:ClearAllPoints()
    if hasVehicleUI then
        -- Vehicle: bar position relative to PlayerFrame
        PlayerFrameHealthBar:SetSize(117.5, 19)
        PlayerFrameHealthBar:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 113, -38)
        -- Raise bars above vehicle border texture
        PlayerFrameHealthBar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 3)
        PlayerFrameManaBar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 3)
    elseif fatMode then
        PlayerFrameHealthBar:SetSize(125, 29.5) -- Taller in fat mode
        PlayerFrameHealthBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, -HP_OFFSET)
        PlayerFrameHealthBar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 1)
        PlayerFrameManaBar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 1)
    else
        PlayerFrameHealthBar:SetSize(125, 20) -- Normal size
        PlayerFrameHealthBar:SetPoint('LEFT', PlayerPortrait, 'RIGHT', 1, 0)
        PlayerFrameHealthBar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 1)
        PlayerFrameManaBar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 1)
    end

    -- Configure mana bar (fat mode uses anchor frame, vehicle/normal use inline position)
    ApplyFatManaBar()

    -- Set power bar texture based on type (respects user texture override)
    local powerType, powerTypeString = UnitPowerType('player')
    local powerTexture = GetPowerBarTexture(powerTypeString)
    PlayerFrameManaBar:GetStatusBarTexture():SetTexture(powerTexture)

    -- Configure status and flash textures 
    -- In vehicle: hide our custom glow effects (vehicle frame doesn't use them)
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    local baseTexture = GetBaseTexture()
    if hasVehicleUI then
        -- Vehicle mode: suppress Blizzard's native flash/status completely.
        -- DragonUI uses dedicated VehicleCombatFlash / VehicleStatusGlow frames
        -- (created in CreatePlayerFrameTextures) to avoid UIFrameFlash conflicts.
        if PlayerStatusTexture then
            PlayerStatusTexture:Hide()
            PlayerStatusTexture:SetAlpha(0)
        end
        if PlayerFrameFlash then
            PlayerFrameFlash:Hide()
            PlayerFrameFlash:SetAlpha(0)
            -- Stop Blizzard's UIFrameFlash animation if running
            if UIFrameFlashStop then
                UIFrameFlashStop(PlayerFrameFlash)
            end
        end
        -- Hide DragonUI normal-mode combat glow (wrong shape for vehicle frame)
        if dragonFrame and dragonFrame.DragonUICombatGlow then
            dragonFrame.DragonUICombatGlow:Hide()
        end
        -- Position dedicated vehicle glow frames
        if dragonFrame and dragonFrame.VehicleCombatFlash then
            dragonFrame.VehicleCombatFlash:ClearAllPoints()
            dragonFrame.VehicleCombatFlash:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 35, 0)
        end
        if dragonFrame and dragonFrame.VehicleStatusGlow then
            dragonFrame.VehicleStatusGlow:ClearAllPoints()
            dragonFrame.VehicleStatusGlow:SetPoint('TOPLEFT', PlayerFrame, 'TOPLEFT', 35, 0)
        end
    else
        -- Normal/fat mode: update DragonUIStatusGlow texture to match current base texture
        -- (PlayerStatusTexture is permanently suppressed by UpdateGlowVisibility)
        if dragonFrame and dragonFrame.DragonUIStatusTexture then
            dragonFrame.DragonUIStatusTexture:SetTexture(baseTexture)
        end
        -- Also update combat glow texture to match fat/normal
        if dragonFrame and dragonFrame.DragonUICombatTexture then
            dragonFrame.DragonUICombatTexture:SetTexture(baseTexture)
        end
    end

    -- ALWAYS hide Blizzard's PlayerFrameFlash — DragonUI uses its own glow system
    -- (DragonUICombatGlow in normal, VehicleCombatFlash in vehicle, EliteCombatGlow in elite)
    if PlayerFrameFlash then
        PlayerFrameFlash:Hide()
        PlayerFrameFlash:SetAlpha(0)
        if UIFrameFlashStop then
            UIFrameFlashStop(PlayerFrameFlash)
        end
    end

    -- Position glow effects ONLY in normal mode — vehicle hides all glows
    -- (UpdateGlowVisibility blocks them in vehicle; positioning them at the wrong
    -- portrait offset would cause misaligned effects if they were ever shown)
    if not hasVehicleUI then
        if dragonFrame and dragonFrame.DragonUICombatGlow then
            dragonFrame.DragonUICombatGlow:ClearAllPoints()
            dragonFrame.DragonUICombatGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -9, 9)
        end
        if dragonFrame and dragonFrame.DragonUIStatusGlow then
            dragonFrame.DragonUIStatusGlow:ClearAllPoints()
            dragonFrame.DragonUIStatusGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -9, 9)
        end
        if dragonFrame and dragonFrame.EliteStatusGlow then
            dragonFrame.EliteStatusGlow:ClearAllPoints()
            dragonFrame.EliteStatusGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -24.5, 19)
        end
        if dragonFrame and dragonFrame.EliteCombatGlow then
            dragonFrame.EliteCombatGlow:ClearAllPoints()
            dragonFrame.EliteCombatGlow:SetPoint('TOPLEFT', PlayerPortrait, 'TOPLEFT', -24.5, 19)
        end
    end

    -- Setup class-specific elements
    local config = GetPlayerConfig()
    if config.show_runes ~= false then -- Only setup if not explicitly disabled
        SetupRuneFrame()
    end
    UpdatePlayerRoleIcon()
    UpdateGroupIndicator()
    UpdateHealthBarColor(PlayerFrameHealthBar, "player")
    UpdateManaBarColor(PlayerFrameManaBar)
    UpdateLeadershipIcons()

    -- Hide Blizzard texts after frame configuration
    HideBlizzardPlayerTexts()

    -- Apply decoration LAST — after all positioning is finalized
    -- This ensures vehicle atlas, bg/border, and dragon decoration are properly placed
    UpdatePlayerDragonDecoration()

end

local function SetCombatFlashVisible(visible)
    local dragonFrame = _G["DragonUIUnitframeFrame"]

    -- Update deco icon (swords in combat, dot in normal) — skip if deco doesn't exist
    -- or we're in vehicle (deco is hidden during vehicle anyway)
    if dragonFrame and dragonFrame.PlayerFrameDeco and not IsInVehicle() then
        if visible then
            combatPulseTimer = 0 -- Reset pulse timer

            --  CHANGE DECORATION TO COMBAT ICON (crossed swords)
            dragonFrame.PlayerFrameDeco:SetTexture(PLAYER_COMBAT_ICON_TEXTURE)
            dragonFrame.PlayerFrameDeco:SetTexCoord(unpack(PLAYER_COMBAT_ICON_TEX_COORDS))
            --  ADJUST SIZE FOR COMBAT ICON
            dragonFrame.PlayerFrameDeco:SetSize(16, 14)
            dragonFrame.PlayerFrameDeco:SetPoint('CENTER', PlayerPortrait, 'CENTER', 18.5, -20)
        else
            --  RESTORE NORMAL DECORATION
            dragonFrame.PlayerFrameDeco:SetTexture(PLAYER_CORNER_TEXTURE)
            dragonFrame.PlayerFrameDeco:SetTexCoord(unpack(PLAYER_CORNER_TEX_COORDS))
            --  RESTORE ORIGINAL SIZE
            dragonFrame.PlayerFrameDeco:SetSize(23, 23)
            dragonFrame.PlayerFrameDeco:SetPoint('CENTER', PlayerPortrait, 'CENTER', 15.5, -16)
        end
    end

    -- ALWAYS update glow state — this drives both normal and vehicle combat flash
    if visible then
        combatPulseTimer = 0
    end
    SetEliteCombatFlashVisible(visible) -- Use unified system
end

-- Vehicle transition slide, same feel as Blizzard's PlayerFrameAnimTable (0.3s / 140px up)
local PLAYER_SLIDE_TIME = 0.3
local PLAYER_SLIDE_DIST = 140
local slideOffset = 0
local slideDriver, slideStart, slideReverse

local PLAYER_ANCHOR_OFFSETS = {
    player = {-15, -7},
    vehicle = {-20, -5}
}

local secureGuard, secureAnchor, Ghost_Refresh

-- Restricted SetPoint only accepts relative frames from the protected handle pool, hence the mirror.
local SECURE_GUARD_SNIPPET = [[
    if newstate ~= "fix" then return end

    -- The manager only re-fires on a value change, so dirtying our own state is the 0.2s clock.
    self:SetAttribute("state-duipos", "idle")

    local pf = self:GetFrameRef("playerFrame")
    if not pf then return end

    local n = pf:GetNumPoints()
    if n < 2 then return end

    local anchor = self:GetFrameRef("playerAnchor")
    if not anchor then return end

    local stock = false
    for i = 1, n do
        local p, rel, rp, x, y = pf:GetPoint(i)
        -- GetPoint hands back scale-skewed offsets, so match a window, never equality.
        if p == "TOPLEFT" and rp == "TOPLEFT" and x and y
            and x > -19.5 and x < -18.5 and y > -4.5 and y < -3.5 then
            stock = true
        end
    end
    if not stock then return end

    local ox, oy
    if pf:GetAttribute("unit") == "vehicle" then
        ox, oy = self:GetAttribute("duiVehX"), self:GetAttribute("duiVehY")
    else
        ox, oy = self:GetAttribute("duiPlrX"), self:GetAttribute("duiPlrY")
    end

    pf:ClearAllPoints()
    pf:SetPoint("CENTER", anchor, "CENTER", ox or 0, oy or 0)
]]

local function SecureGuard_Install()
    if secureGuard or InCombatLockdown() or not Module.playerFrame then
        return
    end
    if not IsPlayerModuleEnabled() then
        return
    end

    secureAnchor = CreateFrame("Frame", "DragonUI_PlayerSecureAnchor", UIParent, "SecureFrameTemplate")
    secureAnchor:SetAllPoints(Module.playerFrame)

    local guard = CreateFrame("Frame", "DragonUI_PlayerPosGuard", UIParent, "SecureHandlerStateTemplate")
    guard:SetFrameRef("playerFrame", PlayerFrame)
    guard:SetFrameRef("playerAnchor", secureAnchor)

    -- Handles only exist when the lookup ran securely; a missing ref makes the snippet a silent no-op.
    if not guard:GetAttribute("frameref-playerFrame") or not guard:GetAttribute("frameref-playerAnchor") then
        addon:Debug("Secure position guard disabled: frame refs unavailable")
        return
    end

    guard:SetAttribute("duiPlrX", PLAYER_ANCHOR_OFFSETS.player[1])
    guard:SetAttribute("duiPlrY", PLAYER_ANCHOR_OFFSETS.player[2])
    guard:SetAttribute("duiVehX", PLAYER_ANCHOR_OFFSETS.vehicle[1])
    guard:SetAttribute("duiVehY", PLAYER_ANCHOR_OFFSETS.vehicle[2])
    guard:SetAttribute("_onstate-duipos", SECURE_GUARD_SNIPPET)

    secureGuard = guard
    RegisterStateDriver(guard, "duipos", "[combat] fix; off")
end

local function SecureGuard_Uninstall()
    if not secureGuard or InCombatLockdown() then
        return
    end
    UnregisterStateDriver(secureGuard, "duipos")
    UnregisterStateDriver(secureGuard)
    secureGuard:SetAttribute("_onstate-duipos", nil)
    secureGuard = nil
end

-- Apply saved widget position to the player frame
local function ApplyWidgetPosition()
    -- COMBAT GUARD: Do NOT touch ANY frame during combat.
    -- Even our aux frame (DragonUI_PlayerFrame) generates taint when called from
    -- a secure context (AnimationSystem, vehicle transitions). Defer everything.
    if InCombatLockdown() then
        deferredPositionUpdate = true
        return
    end

    if not Module.playerFrame then
        return
    end

    local widgetConfig = addon:GetConfigValue("widgets", "player")
    if not widgetConfig then
        widgetConfig = {
            anchor = "TOPLEFT",
            posX = -19,
            posY = -4
        }
    end

    -- Position the auxiliary frame
    Module.playerFrame:ClearAllPoints()
    Module.playerFrame:SetPoint(widgetConfig.anchor or "TOPLEFT", UIParent, widgetConfig.anchor or "TOPLEFT",
        widgetConfig.posX or -19, widgetConfig.posY or -4)

    -- Anchor PlayerFrame to auxiliary frame
    PlayerFrame:ClearAllPoints()
    local ofs = PLAYER_ANCHOR_OFFSETS[UnitHasVehicleUI("player") and "vehicle" or "player"]
    PlayerFrame:SetPoint("CENTER", Module.playerFrame, "CENTER", ofs[1], ofs[2] + slideOffset)

    SecureGuard_Install()
    if Ghost_Refresh then
        Ghost_Refresh()
    end
end

local function PlayerSlide_Stop()
    slideStart = nil
    if slideDriver then
        slideDriver:SetScript("OnUpdate", nil)
    end
end

local function PlayerSlide_IsRunning()
    return slideDriver ~= nil and slideDriver:GetScript("OnUpdate") ~= nil
end

-- Returns false when combat blocks the move; PlayerFrame:SetPoint is protected there.
local function PlayerSlide_Place(fraction)
    if InCombatLockdown() then
        PlayerSlide_Stop()
        slideOffset = 0
        deferredPositionUpdate = true
        return false
    end
    slideOffset = fraction * PLAYER_SLIDE_DIST
    ApplyWidgetPosition()
    return true
end

local function PlayerSlide_OnUpdate()
    local now = GetTime()
    if not slideStart then
        slideStart = now
    end
    local fraction = (now - slideStart) / PLAYER_SLIDE_TIME
    if fraction >= 1 then
        PlayerSlide_Stop()
        PlayerSlide_Place(slideReverse and 0 or 1)
        return
    end
    PlayerSlide_Place(slideReverse and (1 - fraction) or fraction)
end

-- reverse = slide back down into the configured position, otherwise slide up and out
local function PlayerSlide_Start(reverse)
    if not Module.playerFrame then
        return
    end
    -- Blizzard re-applies art several times during load; restarting would re-park and never let it land.
    if PlayerSlide_IsRunning() and slideReverse == reverse then
        return
    end
    PlayerSlide_Stop()
    slideReverse = reverse
    if not PlayerSlide_Place(reverse and 1 or 0) then
        return
    end
    if not slideDriver then
        slideDriver = CreateFrame("Frame")
    end
    -- t0 comes from the first tick we receive; SetUpAnimation's shared clock eats a whole slide after a reload
    slideStart = nil
    slideDriver:SetScript("OnUpdate", PlayerSlide_OnUpdate)
end

local function PlayerSlide_Out()
    PlayerSlide_Start(false)
    -- An aborted vehicle entry never sends the event that brings the frame back; never leave it off screen
    addon:After(2, function()
        if slideOffset ~= 0 and not PlayerSlide_IsRunning() then
            PlayerSlide_Start(true)
        end
    end)
end

-- Apply configuration settings
local function ApplyPlayerConfig()
    local config = GetPlayerConfig()

    -- Apply scale (protected — pcall for combat safety)
    local scaleOk, scaleErr = pcall(function() PlayerFrame:SetScale(config.scale or 1.0) end)
    if not scaleOk and addon.Debug then addon:Debug("PlayerFrame:SetScale error:", scaleErr) end

    --  ALWAYS use widget position (Editor Mode)
    ApplyWidgetPosition()

    -- Setup text system
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame and addon.TextSystem then
        if not Module.textSystem then
            -- Initialize with dynamic unit based on vehicle state
            local initialUnit = UnitHasVehicleUI("player") and "vehicle" or "player"
            Module.textSystem = addon.TextSystem.SetupFrameTextSystem("player", initialUnit, dragonFrame,
                PlayerFrameHealthBar, PlayerFrameManaBar, "PlayerFrame")
        end
        if Module.textSystem then
            -- Ensure we have the correct unit after setup
            UpdateTextSystemUnit()
            Module.textSystem.update()
        end
    end

    UpdatePlayerDragonDecoration()
    UpdateGlowVisibility()
    
    -- Setup alternate mana bar text to always be visible for druids
    SetupAlternateManaBarAlwaysVisible()

end

-- ============================================================================
-- PUBLIC API FUNCTIONS
-- ============================================================================

-- Reset frame to default configuration
local function ResetPlayerFrame()
    -- Use database defaults instead of local DEFAULTS
    local dbDefaults = addon.defaults and addon.defaults.profile.unitframe.player or {}
    for key, value in pairs(dbDefaults) do
        addon:SetConfigValue("unitframe", "player", key, value)
    end
    ApplyPlayerConfig()

end

-- Refresh frame configuration
local function RefreshPlayerFrame()
    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("player_refresh_frame", RefreshPlayerFrame)
        end
        return
    end

    --  APPLY CONFIGURATION IMMEDIATELY
    ApplyPlayerConfig()

    --  RE-APPLY FRAME LAYOUT (health/mana bar sizes, positions - needed for fat healthbar toggle)
    ChangePlayerframe()

    --  UPDATE CLASS COLOR
    UpdatePlayerHealthBarColor()

    --  UPDATE DRAGON DECORATION (important for scale)
    UpdatePlayerDragonDecoration()

    --  UPDATE TEXT SYSTEM
    if Module.textSystem then
        Module.textSystem.update()
    end

    --  Alternate mana bar text visibility is configured once in ApplyPlayerConfig()

    -- Fade PlayerFrame and its detached decoration frame together (see uf_core.lua UF.GetConfig)
    if addon.VisibilityFade then
        local dragonFrame = _G["DragonUIUnitframeFrame"]
        addon.VisibilityFade.Register("player", PlayerFrame, {
            frames = { dragonFrame },
            dbTable = function() return addon.UF.GetConfig("player") end,
            hoverFrames = { PlayerFrame, PlayerFrameHealthBar, PlayerFrameManaBar },
            clickThrough = true,
        })
        addon.VisibilityFade.Update("player")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
-- Hook for automatic class color refresh on health bar updates
local function SetupPlayerClassColorHooks()
    if not _G.DragonUI_PlayerHealthHookSetup then
        -- Taint-safe hook: refresh color when Blizzard updates health bar
        hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
            if statusbar == PlayerFrameHealthBar and unit == "player" then
                UpdatePlayerHealthBarColor()
            end
        end)

        _G.DragonUI_PlayerHealthHookSetup = true

    end
end
-- Initialize the PlayerFrame module
local function InitializePlayerFrame()
    if Module.initialized then
        return
    end

    -- Setup vehicle transition hooks with safe function
    local function SafeHookSecureFunc(funcName, hookFunc)
        if _G[funcName] and type(_G[funcName]) == "function" then
            hooksecurefunc(funcName, hookFunc)
        end
    end

    
    -- These are hooked at file scope below with richer logic (vehicle transitions section)
    -- HandleRuneFrameVehicleTransition is called from the file-scope hooks instead

    -- BLIZZARD FUNCTION HOOKS — must defer in combat.
    -- These hooks fire when Blizzard internally manages PlayerFrame during reload/vehicle
    -- transitions. If registered during combat, ChangePlayerframe() fires at a time when
    -- vehicle state isn't fully initialized → disrupts vehicle action bar layout.
    local function RegisterBlizzardHooks()
        if Module.blizzardHooksRegistered then return end
        SafeHookSecureFunc("PlayerFrame_UpdateStatus", PlayerFrame_UpdateStatus)
        SafeHookSecureFunc("PlayerFrame_UpdateArt", ChangePlayerframe)
        SafeHookSecureFunc("PlayerFrame_UpdateGroupIndicator", UpdateGroupIndicator)
        SafeHookSecureFunc("UnitFramePortrait_Update", function(frame, unit)
            if frame == PlayerFrame and (unit == "player" or unit == "vehicle") then
                RefreshPlayerPortraitState(unit)
            end
        end)
        SafeHookSecureFunc("ShowHelm", function()
            RefreshPlayerPortraitState("player")
        end)
        SafeHookSecureFunc("HideHelm", function()
            RefreshPlayerPortraitState("player")
        end)
        Module.blizzardHooksRegistered = true
    end

    if InCombatLockdown() then
        -- Defer Blizzard hooks to after combat
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        hookFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            RegisterBlizzardHooks()
        end)
    else
        RegisterBlizzardHooks()
    end
    
    -- Alternate mana bar text setup done once in ApplyPlayerConfig() - no need for hooks

    -- Hook to update PVP timer position when it appears/changes
    local pvpTimerText = _G["PlayerPVPTimerText"]
    if pvpTimerText and pvpTimerText.HookScript then
        pvpTimerText:HookScript("OnShow", function()
            local config = GetPlayerConfig()
            local decorationType = config.dragon_decoration or "none"
            local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
            UpdatePVPTimerPosition(isEliteMode)
        end)
        -- Also update when the text changes
        pvpTimerText:HookScript("OnTextChanged", function()
            local config = GetPlayerConfig()
            local decorationType = config.dragon_decoration or "none"
            local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
            UpdatePVPTimerPosition(isEliteMode)
        end)
    end

    -- Create auxiliary frame
    Module.playerFrame = addon.CreateUIFrame(200, 75, "PlayerFrame")

    --  AUTOMATIC REGISTRATION IN CENTRALIZED SYSTEM
    addon:RegisterEditableFrame({
        name = "player",
        frame = Module.playerFrame,
        blizzardFrame = PlayerFrame,
        configPath = {"widgets", "player"},
        onHide = function()
            ApplyPlayerConfig() -- Apply new configuration when exiting editor
        end,
        module = Module
    })

    -- Register fat mana bar anchor as editable frame (for editor mode movability)
    if IsFatHealthbarActive() and not Module.fatManaRegistered then
        local fatAnchor = GetOrCreateFatManaAnchor()
        addon:RegisterEditableFrame({
            name = "fat_manabar",
            frame = fatAnchor,
            configPath = {"widgets", "fat_manabar"},
            editorVisible = function() return IsFatHealthbarActive() end,
            onHide = function()
                ApplyFatManaBar()
            end,
            module = Module
        })
        Module.fatManaRegistered = true
    end

    -- Setup frame hooks
    if PlayerFrame and PlayerFrame.HookScript then
        PlayerFrame:HookScript('OnUpdate', PlayerFrame_OnUpdate)
    end

    -- Phase 2: Removed duplicate hooksecurefunc for PlayerFrame_UpdateStatus and
    -- PlayerFrame_UpdateArt — already hooked via SafeHookSecureFunc above (L1685-1686)

    -- Setup bar hooks for persistent colors
    if PlayerFrameHealthBar and PlayerFrameHealthBar.HookScript then
        PlayerFrameHealthBar:HookScript('OnValueChanged', function(self)
            --  APPLY CLASS COLOR ON EACH CHANGE
            UpdatePlayerHealthBarColor()
        end)
        PlayerFrameHealthBar:HookScript('OnShow', function(self)
            --  APPLY CLASS COLOR ON SHOW
            UpdatePlayerHealthBarColor()
        end)
    end

    -- Instance-level SetStatusBarColor defense (same pattern as small_frame.lua).
    -- Blizzard's HealthBar_OnValueChanged calls SetStatusBarColor(green) on every
    -- health change through code paths that DragonUI's higher-level hooks don't
    -- intercept.  WeakAuras (and similar addons) trigger additional Blizzard UI
    -- refresh cycles asynchronously, making the race visible.  This hook catches
    -- ALL SetStatusBarColor calls regardless of code path and re-applies our color.
    if PlayerFrameHealthBar then
        local healthColorGuard = false
        hooksecurefunc(PlayerFrameHealthBar, "SetStatusBarColor", function(self)
            if healthColorGuard then return end
            healthColorGuard = true
            UpdatePlayerHealthBarColor()
            healthColorGuard = false
        end)
    end

    if PlayerFrameManaBar and PlayerFrameManaBar.HookScript then
        PlayerFrameManaBar:HookScript('OnValueChanged', UpdateManaBarColor)
    end

    -- TexCoord clipping for baked textures (critical for DragonUI dynamic cropping).
    -- Overlay anchoring uses the statusbar texture object, so clipping remains compatible.
    if PlayerFrameHealthBar then
        hooksecurefunc(PlayerFrameHealthBar, "SetValue", function(self)
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            local _, max = self:GetMinMaxValues()
            local cur = self:GetValue()
            if max > 0 and cur and cur >= 0 then
                texture:SetTexCoord(0, cur / max, 0, 1)
            end
        end)
    end

    -- Mana texcoord clipping (same baked texture rule).
    if PlayerFrameManaBar then
        hooksecurefunc(PlayerFrameManaBar, "SetValue", function(self)
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            local _, max = self:GetMinMaxValues()
            local cur = self:GetValue()
            if max > 0 and cur and cur >= 0 then
                texture:SetTexCoord(0, cur / max, 0, 1)
            end
        end)
    end

    -- Instance-level SetStatusBarColor defense for mana bar (same rationale).
    if PlayerFrameManaBar then
        local manaColorGuard = false
        hooksecurefunc(PlayerFrameManaBar, "SetStatusBarColor", function(self)
            if manaColorGuard then return end
            manaColorGuard = true
            UpdateManaBarColor(self)
            manaColorGuard = false
        end)
    end

    -- Blizzard re-Shows this bar on its own (e.g. UnitFrameManaBar_UpdateType), undoing "hide mana bar".
    if PlayerFrameManaBar then
        hooksecurefunc(PlayerFrameManaBar, "Show", function(self)
            if IsFatHealthbarActive() then
                local _, _, hidden = GetFatManaConfig()
                if hidden then
                    self:Hide()
                end
            end
        end)
    end

    -- Protect against Blizzard's UnitFrameManaBar_UpdateType resetting our texture
    if not Module._manaTypeHooked and _G.UnitFrameManaBar_UpdateType then
        hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
            if manaBar == PlayerFrameManaBar then
                UpdatePowerBarTexture(PlayerFrameManaBar)
            end
        end)
        Module._manaTypeHooked = true
    end

    -- Setup glow suppression hooks
    local glows = {PlayerStatusGlow, PlayerRestGlow}
    for _, glow in ipairs(glows) do
        if glow and glow.HookScript then
            glow:HookScript('OnShow', function(self)
                self:Hide()
                self:SetAlpha(0)
            end)
        end
    end

    -- Suppress Blizzard's PlayerFrameFlash permanently — DragonUI uses its own combat flash
    -- (DragonUICombatGlow / VehicleCombatFlash / EliteCombatGlow depending on mode)
    -- Clear the texture entirely so UIFrameFlash's OnUpdate alpha animation has nothing to render
    if PlayerFrameFlash then
        PlayerFrameFlash:SetTexture('')
        PlayerFrameFlash:Hide()
        PlayerFrameFlash:SetAlpha(0)
        if UIFrameFlashStop then
            UIFrameFlashStop(PlayerFrameFlash)
        end
    end

    if PlayerFrameFlash and not PlayerFrameFlash.__DragonUI_FlashHooked then
        hooksecurefunc(PlayerFrameFlash, 'Show', function(self)
            self:Hide()
            self:SetAlpha(0)
            self:SetTexture('')
            if UIFrameFlashStop then
                UIFrameFlashStop(self)
            end
        end)
        PlayerFrameFlash.__DragonUI_FlashHooked = true
    end

    -- Always suppress Blizzard's PlayerStatusTexture (resting glow)
    -- DragonUI provides custom glow system (EliteStatusGlow / VehicleStatusGlow)
    -- and the status glow state is tracked via statusGlowVisible
    if PlayerStatusTexture and PlayerStatusTexture.HookScript then
        PlayerStatusTexture:HookScript('OnShow', function(self)
            if not self.DragonUI_ShowGuard then
                self.DragonUI_ShowGuard = true
                self:Hide()
                self:SetAlpha(0)
                self.DragonUI_ShowGuard = nil
            end
        end)
    end

    -- Hide Blizzard texts after module initialization
    HideBlizzardPlayerTexts()

    Module.initialized = true
    Module.applied = true

end

-- ============================================================================
-- EVENT SYSTEM
-- ============================================================================

-- Combined update function for efficiency
local function UpdateBothBars()
    UpdateHealthBarColor(PlayerFrameHealthBar, "player")
    UpdateManaBarColor(PlayerFrameManaBar)
end

-- Re-skin for whatever art Blizzard just installed; only ever called while the frame is slid away
local function ApplyPlayerArtState()
    local inVehicle = IsInVehicle()

    if InCombatLockdown() then
        deferredPositionUpdate = true
    else
        ApplyWidgetPosition()
    end

    HandleRuneFrameVehicleTransition(inVehicle)

    local config = GetPlayerConfig()
    local decorationType = config.dragon_decoration or "none"
    local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
    UpdateDragonVisibilityForVehicle(inVehicle, isEliteMode)

    UpdateGlowVisibility()
    ChangePlayerframe()
    UpdatePlayerDragonDecoration()

    -- Blizzard owns these anchors while the vehicle art is up; ours only fit the normal frame
    if not inVehicle then
        UpdateLeadershipIcons()
    end
end

-- Setup event handling system
local function SetupPlayerEvents()
    if Module.eventsFrame then
        return
    end

    local f = CreateFrame("Frame")
    Module.eventsFrame = f

    -- Event handlers
    local handlers = {
        PLAYER_REGEN_ENABLED = function()
            UpdateBothBars()
            SetCombatFlashVisible(false)
            -- Ensure module is initialized before deferred updates
            -- (reload in combat defers InitializePlayerFrame; this runs it now)
            if not Module.initialized then
                InitializePlayerFrame()
            end
            -- SAFE: Apply deferred changes after combat
            if deferredPositionUpdate then
                ApplyPlayerConfig()  -- Includes ApplyWidgetPosition + scale
                ChangePlayerframe()  -- Re-apply full layout (vehicle state may have changed during combat)
                HideBlizzardPlayerTexts()
                deferredPositionUpdate = false
                -- Delayed retry: Blizzard may reposition PlayerFrame after PLAYER_REGEN_ENABLED
                -- (vehicle exit animation, level-up, etc.). Re-apply after a few frames to
                -- ensure our position is the final one.
                if not Module.regenDelayFrame then
                    Module.regenDelayFrame = CreateFrame("Frame")
                end
                Module.regenDelayAttempts = 0
                Module.regenDelayFrame:SetScript("OnUpdate", function(self)
                    Module.regenDelayAttempts = (Module.regenDelayAttempts or 0) + 1
                    if Module.regenDelayAttempts >= 3 then -- After 3 frames (~0.1s)
                        if not InCombatLockdown() then
                            ApplyPlayerConfig()
                            ChangePlayerframe()
                        end
                        self:SetScript("OnUpdate", nil)
                    end
                end)
            end
        end,

        PLAYER_REGEN_DISABLED = function()
            SetCombatFlashVisible(true)
        end,


        ADDON_LOADED = function(addonName)
            if addonName == "DragonUI" then
                InitializePlayerFrame()
            end
        end,

        PLAYER_ENTERING_WORLD = function()
            if InCombatLockdown() then
                -- Reload happened in combat: touching ANY frame generates taint
                -- that breaks vehicle action bar. Defer everything to after combat.
                -- This is a WoW 3.3.5a limitation — RetailUI has the same issue.
                deferredPositionUpdate = true
                -- Only safe non-frame operations:
                UpdateTextSystemUnit()
                return
            end
            ChangePlayerframe()
            ApplyPlayerConfig()
            -- Ensure Blizzard texts are hidden after entering world
            HideBlizzardPlayerTexts()
            -- Update textSystem unit in case of reload while in vehicle
            UpdateTextSystemUnit()

            -- Applying the art inside this dispatch is what kills the restyle flash; sliding during load is
            -- not, and frame pacing there is too erratic to time it, so land it at rest like Blizzard does.
            if UnitHasVehicleUI("player") then
                ApplyPlayerArtState()
            end
        end,

        RUNE_TYPE_UPDATE = function(runeIndex)
            -- FIX: Update ALL 6 runes, not just the one that changed.
            -- Blizzard's OnEvent fires on ALL rune buttons for any RUNE_TYPE_UPDATE,
            -- resetting ALL textures to the Blizzard default. Updating only the
            -- changed rune leaves the other 5 stuck on Blizzard's texture.
            for i = 1, 6 do
                local button = _G['RuneButtonIndividual' .. i]
                if button then
                    UpdateRune(button)
                end
            end
        end,

        GROUP_ROSTER_UPDATE = UpdateGroupIndicator,
        ROLE_CHANGED_INFORM = UpdatePlayerRoleIcon,
        LFG_ROLE_UPDATE = UpdatePlayerRoleIcon,

        UNIT_AURA = function(unit)
            if unit == "player" then
                UpdateBothBars()
            end
        end,

        UNIT_MODEL_CHANGED = function(unit)
            if unit == "player" or unit == "vehicle" then
                RefreshPlayerPortraitState(unit)
            end
        end,

        UNIT_PORTRAIT_UPDATE = function(unit)
            if unit == "player" or unit == "vehicle" then
                RefreshPlayerPortraitState(unit)
            end
        end,

        PLAYER_EQUIPMENT_CHANGED = function()
            RefreshPlayerPortraitState("player")
        end,

        -- Vehicle events for proper unit switching
        UNIT_ENTERING_VEHICLE = function(unit, showVehicleFrame)
            if unit == "player" and (showVehicleFrame or PlayerFrame.state == "vehicle") then
                PlayerSlide_Out()
            end
        end,

        UNIT_EXITING_VEHICLE = function(unit)
            if unit == "player" and PlayerFrame.state == "vehicle" then
                PlayerSlide_Out()
            end
        end,

        UNIT_ENTERED_VEHICLE = function(unit)
            if unit == "player" then
                UpdateTextSystemUnit()
                UpdateBothBars()
                -- Force textSystem update after unit change
                if Module.textSystem and Module.textSystem.update then
                    Module.textSystem.update()
                end
                
                -- Hide dragon decoration when entering vehicle
                local config = GetPlayerConfig()
                local decorationType = config.dragon_decoration or "none"
                local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
                UpdateDragonVisibilityForVehicle(true, isEliteMode)
            end
        end,

        UNIT_EXITED_VEHICLE = function(unit)
            if unit == "player" then
                UpdateTextSystemUnit()
                UpdateBothBars()
                -- Force textSystem update after unit change and trigger health events
                if Module.textSystem and Module.textSystem.update then
                    Module.textSystem.update()
                end
                
                -- Show dragon decoration when exiting vehicle
                local config = GetPlayerConfig()
                local decorationType = config.dragon_decoration or "none"
                local isEliteMode = decorationType == "elite" or decorationType == "rareelite"
                UpdateDragonVisibilityForVehicle(false, isEliteMode)
                -- Force health and power updates to ensure bars show correctly
                if PlayerFrameHealthBar then
                    PlayerFrameHealthBar:GetScript("OnEvent")(PlayerFrameHealthBar, "UNIT_HEALTH", "player")
                end
                if PlayerFrameManaBar then
                    PlayerFrameManaBar:GetScript("OnEvent")(PlayerFrameManaBar, "UNIT_MANA", "player")
                    -- FIX: Restore white tint for texture purity
                    UpdateManaBarColor(PlayerFrameManaBar)
                end
            end
        end
    }

    -- Register events
    for event in pairs(handlers) do
        f:RegisterEvent(event)
    end

    for event in pairs(HEALTH_EVENTS) do
        f:RegisterEvent(event)
    end

    for event in pairs(POWER_EVENTS) do
        f:RegisterEvent(event)
    end

    -- Event dispatcher
    f:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then
            handler(...)
            return
        end

        local unit = ...
        if unit ~= "player" then
            return
        end

        if HEALTH_EVENTS[event] then
            UpdateHealthBarColor(PlayerFrameHealthBar, "player")
        elseif POWER_EVENTS[event] then
            UpdateManaBarColor(PlayerFrameManaBar)
            UpdatePowerBarTexture(PlayerFrameManaBar)
            -- Update alternate mana text for druids (both always visible and hover modes)
            local _, playerClass = UnitClass("player")
            if playerClass == "DRUID" then
                local config = GetPlayerConfig()
                if config and config.alwaysShowAlternateManaText then
                    -- Always visible mode: update immediately
                    UpdateAlternateManaText()
                else
                    -- Hover mode: only update if currently showing (mouse over)
                    local alternateManaBar = _G.PlayerFrameAlternateManaBar
                    if alternateManaBar and alternateManaBar:IsMouseOver() then
                        UpdateAlternateManaText()
                    end
                end
            end
        end
    end)

end

-- ============================================================================
-- MODULE STARTUP
-- ============================================================================

-- Initialize event system
SetupPlayerEvents()
SetupPlayerClassColorHooks()

-- Hide Blizzard texts after initialization
HideBlizzardPlayerTexts()

-- Druid alternate mana bar: Blizzard updates the bar but never our text on it
hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
    if unit ~= "player" then
        return
    end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "DRUID" then
        return
    end

    local config = GetPlayerConfig()
    if config and config.alwaysShowAlternateManaText then
        UpdateAlternateManaText()
        return
    end

    local alternateManaBar = _G.PlayerFrameAlternateManaBar
    if alternateManaBar and alternateManaBar:IsMouseOver() then
        UpdateAlternateManaText()
    end
end)

-- ===============================================================
-- HOOKS TO MAINTAIN POSITION DURING VEHICLE TRANSITIONS
-- ===============================================================

-- Blizzard swaps art only while the frame is animated away, so this is where the slide turns around.
-- After a reload its AnimationSystem clock is frozen, so the swap can land before our outbound slide has
-- moved at all; testing the driver too (not just the offset) is what stops the frame parking off screen.
local function OnBlizzardArtApplied()
    ApplyPlayerArtState()
    if slideOffset ~= 0 or (PlayerSlide_IsRunning() and not slideReverse) then
        PlayerSlide_Start(true)
    end
end

hooksecurefunc("PlayerFrame_ToPlayerArt", OnBlizzardArtApplied)
hooksecurefunc("PlayerFrame_ToVehicleArt", OnBlizzardArtApplied)

if PlayerFrame_SequenceFinished then
    hooksecurefunc("PlayerFrame_SequenceFinished", function()
        ApplyPlayerArtState()
    end)
end

-- Stand-in for the transition: DragonUI owns it and nothing protected anchors to it, so unlike
-- PlayerFrame it can be moved during combat lockdown.
local GHOST_BASE_LEVEL = 8
local ghostFrame, ghostKids, ghostPortraits, ghostLive
local ghostLayout, ghostRefreshPending
local ghostDriver, ghostStart, ghostReverse, ghostActive
local ghostCache = {}

-- Textures have no GetEffectiveScale in 3.3.5a, so the scale has to come from the owning frame.
local function Ghost_RegionScale(region)
    local parent = region.GetParent and region:GetParent()
    if parent and parent.GetEffectiveScale then
        return parent:GetEffectiveScale()
    end
    return UIParent:GetEffectiveScale()
end

-- Rect of a frame or region in PlayerFrame units; nil when it cannot be measured yet.
local function Ghost_Rect(obj)
    local left, right = obj:GetLeft(), obj:GetRight()
    local top, bottom = obj:GetTop(), obj:GetBottom()
    local baseLeft, baseTop = PlayerFrame:GetLeft(), PlayerFrame:GetTop()
    if not left or not right or not top or not bottom or not baseLeft or not baseTop then
        return nil
    end
    local os = obj.GetEffectiveScale and obj:GetEffectiveScale() or Ghost_RegionScale(obj)
    local ps = PlayerFrame:GetEffectiveScale()
    if not ps or ps == 0 then
        return nil
    end
    return (left * os - baseLeft * ps) / ps, (top * os - baseTop * ps) / ps,
        (right - left) * os / ps, (top - bottom) * os / ps
end

local function Ghost_Capture(region, parentAlpha)
    if not region or not region.IsShown or not region:IsShown() then
        return nil
    end
    local kind = region.GetObjectType and region:GetObjectType()
    if kind ~= "Texture" and kind ~= "FontString" then
        return nil
    end
    -- DragonUI suppresses Blizzard's own art with SetAlpha(0) rather than Hide(), so IsShown lies.
    local alpha = parentAlpha * ((region.GetAlpha and region:GetAlpha()) or 1)
    if alpha < 0.05 then
        return nil
    end

    local x, y, w, h = Ghost_Rect(region)
    if not x then
        return nil
    end

    -- Anything living outside the frame is not part of it: a parked mana bar, a stray overlay.
    if x + w <= 0 or x >= PlayerFrame:GetWidth() or y <= -PlayerFrame:GetHeight() or y - h >= 0 then
        return nil
    end

    local coords
    if kind == "Texture" and region.GetTexCoord then
        local ulx, uly, llx, lly, urx = region:GetTexCoord()
        if ulx then
            coords = {ulx, urx, uly, lly}
        end
    end

    local layer = region.GetDrawLayer and region:GetDrawLayer()
    local capture = {
        kind = kind,
        layer = layer or "ARTWORK",
        src = region,
        alpha = alpha,
        x = x,
        y = y,
        w = w,
        h = h
    }

    if kind == "Texture" then
        capture.isPortrait = (region == PlayerPortrait) or nil
        capture.texture = region:GetTexture()
        if not capture.texture and not capture.isPortrait then
            return nil
        end
        capture.coords = coords
        if region.GetVertexColor then
            capture.r, capture.g, capture.b = region:GetVertexColor()
        end
    else
        capture.text = region:GetText()
        capture.font, capture.size, capture.flags = region:GetFont()
        if not capture.font then
            return nil
        end
        capture.r, capture.g, capture.b = region:GetTextColor()
        capture.justifyH = region:GetJustifyH() or "LEFT"
        -- Anchor the justified edge, so a capture taken while the text was still empty
        -- lands in the right place once the text exists.
        if capture.justifyH == "RIGHT" then
            capture.anchor, capture.ax = "TOPRIGHT", capture.x + capture.w
        elseif capture.justifyH == "CENTER" then
            capture.anchor, capture.ax = "TOP", capture.x + capture.w / 2
        else
            capture.anchor, capture.ax = "TOPLEFT", capture.x
        end
        capture.ay = capture.y
    end
    return capture
end

-- Fat mode and the elite/dragon decorations change which pieces exist and where they sit,
-- so a snapshot is only valid for the layout it was taken under. Use the raw config, never
-- IsFatHealthbarActive: that reports false inside a vehicle and would invalidate every snapshot.
local function Ghost_Layout()
    local config = GetPlayerConfig()
    return tostring(IsFatConfigEnabled()) .. "|" .. tostring((config and config.dragon_decoration) or "none")
end

-- Mirror the frame tree rather than flattening it: draw layers only order regions inside one
-- frame, while frame level orders the frames themselves, and DragonUI relies on both.
local function Ghost_Walk(frame, parentAlpha, depth, out, baseLevel)
    local index = table.getn(out.frames) + 1
    table.insert(out.frames, {
        level = (frame:GetFrameLevel() or baseLevel) - baseLevel
    })

    local fill = nil
    if frame.GetObjectType and frame:GetObjectType() == "StatusBar" then
        -- Clone the bar as a real StatusBar: 3.3.5a clips the fill rather than resizing it,
        -- so replaying it as a plain texture can only ever guess at the value.
        fill = frame:GetStatusBarTexture()
        local info = out.frames[index]
        info.isBar = true
        info.barSrc = frame
        info.bx, info.by, info.bw, info.bh = Ghost_Rect(frame)
        if not info.bx then
            info.bx, info.by, info.bw, info.bh = 0, 0, 0, 0
        end
    end

    local regions = {frame:GetRegions()}
    for i = 1, table.getn(regions) do
        if regions[i] ~= fill then
            local capture = Ghost_Capture(regions[i], parentAlpha)
            if capture then
                capture.frame = index
                table.insert(out.pieces, capture)
            end
        end
    end

    if depth >= 3 then
        return
    end
    local children = {frame:GetChildren()}
    for i = 1, table.getn(children) do
        local child = children[i]
        -- PetFrame is parented to PlayerFrame but is a different unit entirely.
        if child ~= ghostFrame and child ~= _G.PetFrame and child:IsShown() then
            local childAlpha = parentAlpha * (child:GetAlpha() or 1)
            if childAlpha >= 0.05 then
                Ghost_Walk(child, childAlpha, depth + 1, out, baseLevel)
            end
        end
    end
end

local function Ghost_Create()
    if ghostFrame then
        return
    end
    ghostFrame = CreateFrame("Frame", "DragonUI_PlayerGhost", UIParent)
    ghostFrame:SetFrameLevel(GHOST_BASE_LEVEL)
    ghostFrame:Hide()
    ghostKids = {}
    ghostPortraits = {}
end

local function Ghost_Mirror(index, info)
    local kid = ghostKids[index]
    local wantBar = (info and info.isBar) or false
    if kid and (kid.duiIsBar or false) ~= wantBar then
        kid:Hide()
        kid = nil
    end
    if not kid then
        kid = CreateFrame(wantBar and "StatusBar" or "Frame", nil, ghostFrame)
        kid.duiPool = {}
        kid.duiIsBar = wantBar
        ghostKids[index] = kid
    end
    kid:ClearAllPoints()
    if wantBar then
        kid:SetPoint("TOPLEFT", ghostFrame, "TOPLEFT", info.bx, info.by)
        kid:SetWidth(info.bw > 0 and info.bw or 1)
        kid:SetHeight(info.bh > 0 and info.bh or 1)
    else
        kid:SetAllPoints(ghostFrame)
    end
    local level = GHOST_BASE_LEVEL + (info and info.level or 0)
    if level < 0 then
        level = 0
    end
    kid:SetFrameLevel(level)
    kid:Show()
    return kid
end

local function Ghost_Acquire(kid, capture, used)
    local key = capture.kind .. capture.layer
    used[key] = (used[key] or 0) + 1
    local pool = kid.duiPool[key]
    if not pool then
        pool = {}
        kid.duiPool[key] = pool
    end
    local obj = pool[used[key]]
    if not obj then
        if capture.kind == "Texture" then
            obj = kid:CreateTexture(nil, capture.layer)
        else
            obj = kid:CreateFontString(nil, capture.layer)
        end
        pool[used[key]] = obj
    end
    return obj
end

-- Bars are copied wholesale from the source every frame: value, texture and colour are all live.
local function Ghost_SyncBar(kid, source)
    if not kid or not source then
        return
    end
    local fill = source:GetStatusBarTexture()
    if fill and fill:GetTexture() then
        kid:SetStatusBarTexture(fill:GetTexture())
        local r, g, b, a = fill:GetVertexColor()
        if r then
            kid:SetStatusBarColor(r, g, b, a or 1)
        end
        local barFill = kid:GetStatusBarTexture()
        if barFill then
            barFill:SetDrawLayer("ARTWORK")
        end
    end
    if source.GetOrientation then
        kid:SetOrientation(source:GetOrientation())
    end
    local minValue, maxValue = source:GetMinMaxValues()
    kid:SetMinMaxValues(minValue or 0, maxValue or 1)
    kid:SetValue(source:GetValue() or 0)
    kid:SetAlpha(source:GetAlpha() or 1)
end

-- Only the geometry is cached; the frame is displaced mid-transition so it cannot be re-measured,
-- but every value the player can see is re-read live so the ghost never shows a stale bar.
local function Ghost_ApplyRegion(obj, capture)
    local x, y, w, h = capture.x, capture.y, capture.w, capture.h
    local texture, coords = capture.texture, capture.coords
    local r, g, b, text = capture.r, capture.g, capture.b, capture.text
    local src = capture.src

    if src and src:IsShown() then
        if capture.kind == "Texture" then
            -- Texture and texcoords must be read together: fat mode and the elite decorations
            -- swap atlases, so a live texture with cached coords shows the wrong slice.
            texture = src:GetTexture() or texture
            if src.GetTexCoord then
                local ulx, uly, llx, lly, urx = src:GetTexCoord()
                if ulx then
                    coords = {ulx, urx, uly, lly}
                end
            end
            if src.GetVertexColor then
                local vr, vg, vb = src:GetVertexColor()
                if vr then
                    r, g, b = vr, vg, vb
                end
            end
        else
            text = src:GetText() or text
            local vr, vg, vb = src:GetTextColor()
            if vr then
                r, g, b = vr, vg, vb
            end
        end
    end

    if capture.kind == "Texture" then
        if w <= 0 or h <= 0 or (not texture and not capture.isPortrait) then
            obj:Hide()
            return
        end
    elseif not text or text == "" then
        obj:Hide()
        return
    end

    obj:SetDrawLayer(capture.layer)
    obj:ClearAllPoints()
    obj:SetAlpha(capture.alpha or 1)
    if capture.kind == "Texture" then
        obj:SetPoint("TOPLEFT", ghostFrame, "TOPLEFT", x, y)
        obj:SetWidth(w)
        obj:SetHeight(h)
        if not capture.isPortrait then
            obj:SetTexture(texture)
        end
        -- Always reset: these objects are pooled, and a leftover crop from a previous
        -- configuration is what renders as a whole uncropped atlas sheet.
        if coords and table.getn(coords) >= 4 then
            obj:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            obj:SetTexCoord(0, 1, 0, 1)
        end
        obj:SetVertexColor(r or 1, g or 1, b or 1)
    else
        obj:SetPoint(capture.anchor or "TOPLEFT", ghostFrame, "TOPLEFT", capture.ax or x, capture.ay or y)
        -- Zero means the text was empty when captured; let it size itself instead.
        obj:SetWidth(w > 0 and w or 0)
        obj:SetHeight(h > 0 and h or 0)
        obj:SetFont(capture.font, capture.size, capture.flags)
        obj:SetText(text)
        obj:SetTextColor(r or 1, g or 1, b or 1)
        obj:SetJustifyH(capture.justifyH or "LEFT")
    end
    obj:Show()
end

-- Snapshots must be taken while the frame is settled; mid-transition it carries Blizzard's
-- extra anchor and every measurement is taken against a displaced, over-constrained rect.
local function Ghost_Snapshot()
    -- Read-only, so combat is fine; the frame just has to be settled on a single anchor.
    if slideOffset ~= 0 or not Module.playerFrame then
        return false
    end
    if PlayerFrame:GetNumPoints() ~= 1 or not PlayerFrame:GetLeft() then
        return false
    end
    Ghost_Create()

    local layout = Ghost_Layout()
    if ghostLayout ~= layout then
        ghostLayout = layout
        ghostCache = {}
    end

    local out = {frames = {}, pieces = {}}
    Ghost_Walk(PlayerFrame, 1, 0, out, PlayerFrame:GetFrameLevel() or 0)
    if table.getn(out.pieces) == 0 then
        return false
    end

    -- Bake the portrait content now: once the transition starts the vehicle unit is gone.
    local state = UnitHasVehicleUI("player") and "vehicle" or "player"
    local root = Ghost_Mirror(1, out.frames[1])
    local tex = ghostPortraits[state]
    if not tex then
        tex = root:CreateTexture(nil, "ARTWORK")
        ghostPortraits[state] = tex
    end
    tex:Hide()
    -- A live portrait reports a generated name like "Portrait1", not a path; only a class icon is copyable.
    local file = PlayerPortrait:GetTexture()
    local portraitFile = nil
    if file and string.find(tostring(file), "\\") then
        portraitFile = file
        tex:SetTexture(file)
    else
        local unit = PlayerFrame.unit or "player"
        if not UnitExists(unit) then
            unit = "player"
        end
        SetPortraitTexture(tex, unit)
    end

    ghostCache[state] = {
        scale = PlayerFrame:GetScale() or 1,
        width = PlayerFrame:GetWidth(),
        height = PlayerFrame:GetHeight(),
        strata = PlayerFrame:GetFrameStrata(),
        layout = layout,
        portraitFile = portraitFile,
        frames = out.frames,
        pieces = out.pieces
    }
    return true
end

-- ApplyWidgetPosition runs inside ApplyPlayerConfig, before ChangePlayerframe has applied the
-- new fat/decoration art, so capturing inline would store old art under the new layout tag.
Ghost_Refresh = function()
    if ghostRefreshPending then
        return
    end
    ghostRefreshPending = true
    local attempts = 0
    local function attempt()
        attempts = attempts + 1
        if Ghost_Snapshot() or attempts >= 12 then
            ghostRefreshPending = false
            return
        end
        addon:After(0.25, attempt)
    end
    addon:After(0.05, attempt)
end

local function Ghost_Build(state)
    local snapshot = ghostCache[state]
    if not snapshot or not Module.playerFrame then
        return false
    end
    if snapshot.layout ~= Ghost_Layout() then
        return false
    end
    Ghost_Create()

    ghostFrame:SetScale(snapshot.scale)
    ghostFrame:SetWidth(snapshot.width)
    ghostFrame:SetHeight(snapshot.height)
    ghostFrame:SetFrameStrata(snapshot.strata)
    ghostFrame:SetFrameLevel(GHOST_BASE_LEVEL)

    for i = 1, table.getn(snapshot.frames) do
        Ghost_Mirror(i, snapshot.frames[i])
    end

    for key, tex in pairs(ghostPortraits) do
        if key ~= state then
            tex:Hide()
        end
    end

    -- Re-bake now when possible: the very first snapshot after a reload can predate the portrait.
    local portrait = ghostPortraits[state]
    if portrait then
        local unit = (state == "vehicle") and "vehicle" or "player"
        if snapshot.portraitFile then
            portrait:SetTexture(snapshot.portraitFile)
        elseif UnitExists(unit) then
            SetPortraitTexture(portrait, unit)
        end
    end

    local used = {}
    ghostLive = {}
    for i = 1, table.getn(snapshot.frames) do
        local info = snapshot.frames[i]
        if info.isBar then
            Ghost_SyncBar(ghostKids[i], info.barSrc)
            table.insert(ghostLive, {bar = ghostKids[i], barSrc = info.barSrc})
        end
    end
    for i = 1, table.getn(snapshot.pieces) do
        local capture = snapshot.pieces[i]
        local kid = ghostKids[capture.frame or 1]
        if kid then
            local obj
            if capture.isPortrait then
                obj = ghostPortraits[state]
            else
                if not used[kid] then
                    used[kid] = {}
                end
                obj = Ghost_Acquire(kid, capture, used[kid])
            end
            if obj then
                Ghost_ApplyRegion(obj, capture)
                -- Text can change mid-slide; static textures cannot.
                if capture.kind == "FontString" then
                    table.insert(ghostLive, {obj = obj, capture = capture})
                end
            end
        end
    end

    for i = 1, table.getn(ghostKids) do
        local kid = ghostKids[i]
        local counts = used[kid]
        for key, pool in pairs(kid.duiPool) do
            for n = ((counts and counts[key]) or 0) + 1, table.getn(pool) do
                pool[n]:Hide()
            end
        end
    end
    return true
end

local function Ghost_Place(offset)
    local ofs = PLAYER_ANCHOR_OFFSETS[UnitHasVehicleUI("player") and "vehicle" or "player"]
    ghostFrame:ClearAllPoints()
    ghostFrame:SetPoint("CENTER", Module.playerFrame, "CENTER", ofs[1], ofs[2] + offset)
end

local function Ghost_Stop()
    if ghostDriver then
        ghostDriver:SetScript("OnUpdate", nil)
    end
    if ghostFrame then
        ghostFrame:Hide()
    end
    ghostLive = nil
    ghostActive = false
end

local function Ghost_OnUpdate()
    local fraction = (GetTime() - ghostStart) / PLAYER_SLIDE_TIME
    if fraction >= 1 then
        Ghost_Stop()
        return
    end
    Ghost_Place(PLAYER_SLIDE_DIST * (ghostReverse and (1 - fraction) or fraction))
    if ghostLive then
        for i = 1, table.getn(ghostLive) do
            local entry = ghostLive[i]
            if entry.bar then
                Ghost_SyncBar(entry.bar, entry.barSrc)
            else
                Ghost_ApplyRegion(entry.obj, entry.capture)
            end
        end
    end
end

local function Ghost_Start(reverse)
    -- Outbound still shows the vehicle; inbound is already back on the player art.
    local state = "player"
    if not reverse and PlayerFrame.unit == "vehicle" then
        state = "vehicle"
    end
    if not Ghost_Build(state) then
        return false
    end
    ghostReverse = reverse
    ghostStart = GetTime()
    ghostActive = true
    Ghost_Place(reverse and PLAYER_SLIDE_DIST or 0)
    ghostFrame:SetAlpha(1)
    ghostFrame:Show()
    if not ghostDriver then
        ghostDriver = CreateFrame("Frame")
    end
    ghostDriver:SetScript("OnUpdate", Ghost_OnUpdate)
    return true
end

-- Runs inside Blizzard's vehicle event path, so a fault here must never escape.
local function Ghost_SafeStart(reverse)
    local ok, err = pcall(Ghost_Start, reverse)
    if not ok and addon.Debug then
        addon:Debug("Ghost_Start error:", err)
    end
end

local PLAYER_MASK_TIMEOUT = 2
local PLAYER_MASK_HARDCAP = 10
local PLAYER_MASK_SETTLE = 0.02
local PLAYER_MASK_FADE = 0.06
local maskDriver, maskStart, maskLastWrite, maskFadeStart, maskAlpha

local function PlayerMask_Stop()
    Ghost_Stop()
    if maskDriver then
        maskDriver:SetScript("OnUpdate", nil)
    end
    maskStart = nil
    maskFadeStart = nil
    if maskAlpha then
        PlayerFrame:SetAlpha(maskAlpha)
        maskAlpha = nil
    end
    if Ghost_Refresh then
        Ghost_Refresh()
    end
end

local function PlayerMask_OnUpdate()
    local now = GetTime()

    if maskFadeStart then
        if ghostActive then
            return
        end
        local fraction = (now - maskFadeStart) / PLAYER_MASK_FADE
        if fraction >= 1 then
            PlayerMask_Stop()
        else
            PlayerFrame:SetAlpha((maskAlpha or 1) * fraction)
        end
        return
    end

    if not InCombatLockdown() or (now - maskStart) > PLAYER_MASK_HARDCAP then
        PlayerMask_Stop()
        return
    end

    -- One point means the guard corrected; a live animation re-adds Blizzard's within a frame.
    local quiet = (now - maskLastWrite) > PLAYER_MASK_SETTLE
    if quiet and PlayerFrame:GetNumPoints() == 1 then
        maskFadeStart = now
        Ghost_SafeStart(true)
    elseif quiet and (now - maskStart) > PLAYER_MASK_TIMEOUT then
        -- Giving up while Blizzard is still writing would reveal the frame at its stock anchor.
        PlayerMask_Stop()
    end
end

-- Blizzard animates at frame rate and the secure guard can only answer at 5Hz, so hide rather than race.
local function PlayerMask_Begin()
    if not secureGuard then
        return
    end
    local now = GetTime()
    maskLastWrite = now
    if maskStart and not maskFadeStart then
        return
    end
    if maskAlpha == nil then
        maskAlpha = PlayerFrame:GetAlpha()
    end
    maskStart = now
    maskFadeStart = nil
    PlayerFrame:SetAlpha(0)
    Ghost_SafeStart(false)
    if not maskDriver then
        maskDriver = CreateFrame("Frame")
    end
    maskDriver:SetScript("OnUpdate", PlayerMask_OnUpdate)
end

-- hooksecurefunc fires after Blizzard's SetPoint, so our position is restored in the same frame.
hooksecurefunc(PlayerFrame, "SetPoint", function(self, point, relativeTo, relativePoint, x, y)
    if self.DragonUI_SettingPoint then return end
    if InCombatLockdown() then
        deferredPositionUpdate = true
        if point == "TOPLEFT" and relativeTo == UIParent then
            PlayerMask_Begin()
        end
        return
    end

    -- Blizzard only auto-anchors to UIParent TOPLEFT/CENTER; anything else is ours or another addon's.
    if point and relativeTo == UIParent and (point == "TOPLEFT" or point == "CENTER") then
        self.DragonUI_SettingPoint = true
        local ok, err = pcall(ApplyWidgetPosition)
        if not ok and addon.Debug then addon:Debug("ApplyWidgetPosition error:", err) end
        self.DragonUI_SettingPoint = nil
    end
end)

local function OnProfileChanged()
    if not IsPlayerModuleEnabled() then
        SecureGuard_Uninstall()
        addon:ShouldDeferModuleDisable("player", Module)
        return
    end

    RefreshPlayerFrame()
    SetupAlternateManaBarAlwaysVisible()
end

if addon.db and addon.db.RegisterCallback then
    addon.db.RegisterCallback(Module, "OnProfileChanged", OnProfileChanged)
    addon.db.RegisterCallback(Module, "OnProfileCopied", OnProfileChanged)
    addon.db.RegisterCallback(Module, "OnProfileReset", OnProfileChanged)
end

addon.PlayerFrame = {
    Refresh = RefreshPlayerFrame,
    RefreshPlayerFrame = RefreshPlayerFrame,
    Reset = ResetPlayerFrame,
    anchor = function()
        return Module.playerFrame
    end,
    ChangePlayerframe = ChangePlayerframe,
    CreatePlayerFrameTextures = CreatePlayerFrameTextures,
    UpdatePlayerHealthBarColor = UpdatePlayerHealthBarColor,
    UpdatePlayerClassPortrait = UpdatePlayerClassPortrait
}
