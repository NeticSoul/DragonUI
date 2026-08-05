--[[
  DragonUI - Unit Frame Shared Core (uf_core.lua)

  Shared constants, utilities, and factory helpers for all unit frame modules.
  Loaded first via unitframes.xml; other UF modules reference addon.UF.
]]

local _, addon = ...

-- Create the shared UF namespace
addon.UF = addon.UF or {}
local UF = addon.UF


-- ============================================================================
-- TEXTURE PATH REGISTRY
-- ============================================================================

UF.TEXTURES = {
    -- Target-style frames (TargetFrame, FocusFrame)
    targetStyle = {
        BACKGROUND     = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND",
        BACKGROUND_FAT = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\UI-HUD-UnitFrame-Target-PortraitOn-BACKGROUND-Fat",
        BORDER         = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER",
        BORDER_FAT     = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\UI-HUD-UnitFrame-Target-PortraitOn-BORDER-Fat",
        BAR_PREFIX     = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
        NAME_BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\NameBackground",
        BOSS           = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\uiunitframeboss2x",
        THREAT         = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\ui-hud-unitframe-target-portraiton-incombat-2x",
        THREAT_NUMERIC = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\uiunitframe",
    },

    -- Small-style frames (ToT, FoT, Pet)
    smallStyle = {
        BACKGROUND = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Small\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BACKGROUND",
        BORDER     = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Small\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
        BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
        BOSS       = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\uiunitframeboss2x",
    },

    -- Player frame (unique textures)
    -- NOTE: Vehicle border uses atlas 'PlayerFrame-TextureFrame-Vehicle' from UnitFrame.blp (defined in Atlas.lua)
    player = {
        BASE          = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\uiunitframe",
        BASE_FAT      = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\uiunitframe-fat",
        HEALTH_BAR    = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health",
        HEALTH_STATUS = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status",
        BORDER        = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Player\\UI-HUD-UnitFrame-Player-PortraitOn-BORDER",
        BORDER_FAT    = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Player\\UI-HUD-UnitFrame-Player-PortraitOn-BORDER-Fat",
        REST_ICON     = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\PlayerRestFlipbook",
        RUNE_TEXTURE  = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\ClassOverlayDeathKnightRunes",
        RUNE_TEXTURE_PURPLE = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\ClassOverlayDeathKnightRunes_Purple",
        LFG_ICONS     = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Player\\LFGRoleIcons",
        POWER_BARS = {
            MANA        = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana",
            RAGE        = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage",
            FOCUS       = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus",
            ENERGY      = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy",
            RUNIC_POWER = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower",
        },
    },

    -- Party frames (unique textures)
    party = {
        healthBarStatus = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status",
        frame           = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\uipartyframe",
        border          = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Small\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-BORDER",
        healthBar       = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health",
        manaBar         = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana",
        focusBar        = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Focus",
        rageBar         = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Rage",
        energyBar       = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-Energy",
        runicPowerBar   = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Party\\UI-HUD-UnitFrame-Party-PortraitOn-Bar-RunicPower",
    },

    -- Pet frame (constructs paths from prefix)
    pet = {
        SMALL_FRAME_PATH = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Small\\",
        UNITFRAME_PATH   = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\",
        ATLAS_TEXTURE    = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\uiunitframe",
        TOT_BASE         = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-",
        -- Pre-computed power textures (same as smallStyle BAR_PREFIX + power name)
        POWER_TEXTURES = {
            MANA        = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana",
            FOCUS       = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Focus",
            RAGE        = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage",
            ENERGY      = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy",
            RUNIC_POWER = "Interface\\Addons\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-RunicPower",
        },
        COMBAT_TEX_COORDS = {0.3095703125, 0.4208984375, 0.3125, 0.404296875},
    },

    -- Shared class icon texture (used by class portrait system)
    CLASS_ICON_ALTERNATIVE_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\ClassIcons\\",
    CLASS_ICON_ALTERNATIVE_SUFFIX = ".blp",
    CLASS_ICON = "Interface\\TargetingFrame\\UI-Classes-Circles",
}


-- ============================================================================
-- CLASSIFICATION COORDINATES
-- ============================================================================
-- Tex coords + pixel dimensions for boss/elite/rare portrait decorations.
-- targetStyle uses larger icons; smallStyle uses smaller ones for ToT/FoT.

UF.BOSS_COORDS = {
    -- For target-style frames (TargetFrame, FocusFrame) — larger decorations
    targetStyle = {
        elite     = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 80, 79, 4, 1},
        rare      = {0.00390625, 0.31640625, 0.64453125, 0.953125, 80, 79, 4, 1},
        rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 99, 81, 13, 1},
    },
    -- For small-style frames (ToT, FoT) — smaller decorations
    smallStyle = {
        elite     = {0.001953125, 0.314453125, 0.322265625, 0.630859375, 60, 59, 3, 1},
        rare      = {0.00390625, 0.31640625, 0.64453125, 0.953125, 60, 59, 3, 1},
        rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937, 74, 61, 10, 1},
    },
}


-- ============================================================================
-- POWER TYPE MAP
-- ============================================================================
-- Numeric power type ID -> texture suffix name.

UF.POWER_MAP = {
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "RunicPower",
}


-- ============================================================================
-- THREAT COLORS
-- ============================================================================
-- Indexed by threat level (1=low, 2=medium, 3=high).

UF.THREAT_COLORS = {
    {1.0, 1.0, 0.47}, -- Low threat
    {1.0, 0.6, 0.0},  -- Medium threat
    {1.0, 0.0, 0.0},  -- High threat
}


-- ============================================================================
-- FAMOUS NPCs
-- ============================================================================
-- Classification overrides for specific NPCs.

UF.FAMOUS_NPCS = {
    ["Patufet"] = true,
}

-- Legacy alias
addon.unitframe = addon.unitframe or {}
addon.unitframe.famous = UF.FAMOUS_NPCS


-- ============================================================================
-- LOCALE-AWARE DEFAULT FONT
-- ============================================================================
-- Uses centralized font system from core/fonts.lua.
-- Modules should use UF.DEFAULT_FONT instead of hardcoding FRIZQT__.

UF.DEFAULT_FONT = addon.Fonts and addon.Fonts.PRIMARY or "Fonts\\FRIZQT__.TTF"

-- Fine-tune for non-alternative class portrait apparent size.
-- 0.000 = smallest (native atlas crop), higher values zoom in slightly.
UF.CLASSIC_CLASS_ICON_INSET = 0.012


-- ============================================================================
-- CONFIG ACCESS
-- ============================================================================
-- Returns config table with database defaults as metatable fallback.

function UF.GetConfig(unitKey)
    local config = {}
    if addon.GetConfigValue then
        config = addon:GetConfigValue("unitframe", unitKey) or {}
    elseif addon.db and addon.db.profile and addon.db.profile.unitframe then
        config = addon.db.profile.unitframe[unitKey] or {}
    end

    local defaults = addon.defaults
        and addon.defaults.profile
        and addon.defaults.profile.unitframe
        and addon.defaults.profile.unitframe[unitKey] or {}

    return setmetatable(config, { __index = defaults })
end

function UF.IsEnabled(unitKey)
    local config = UF.GetConfig(unitKey)
    return config.enabled ~= false
end


-- ============================================================================
-- CLASSIFICATION HELPERS
-- ============================================================================
-- Returns the effective classification string for a unit, accounting for
-- famous NPC overrides, vehicles, and skull-level bosses.

function UF.GetClassification(unit, famousNpcs)
    if not UnitExists(unit) then return nil end

    local classification = UnitClassification(unit)

    -- Famous NPC override
    if famousNpcs then
        local name = UnitName(unit)
        if name and famousNpcs[name] then
            -- If value is a string, use it as classification; if true, keep current
            local override = famousNpcs[name]
            if type(override) == "string" then
                classification = override
            end
        end
    end

    -- Vehicle override — vehicles show as normal
    if UnitInVehicle and UnitInVehicle(unit) then
        classification = "normal"
    end

    -- Level -1 indicates boss
    if UnitLevel(unit) == -1 and classification ~= "worldboss" then
        if classification == "rare" then
            classification = "rareelite"
        elseif classification ~= "rareelite" then
            classification = "elite"
        end
    end

    return classification
end

function UF.GetBossCoords(classification, bossCoords)
    if not classification then return nil end
    return bossCoords[classification]
end


-- ============================================================================
-- CLASS PORTRAIT
-- ============================================================================
-- Overlays a class icon on the unit portrait when enabled.
-- Lazy-creates the background and icon textures on first call.

function UF.UseAlternativeClassIcons(unitKey)
    local config = UF.GetConfig(unitKey)
    return config and config.classPortrait and config.alternativeClassIcons or false
end

function UF.ApplyClassPortraitIcon(icon, classFileName, useAlternative)
    if not icon or not classFileName then
        return false
    end

    local function ClampInset(value)
        local inset = tonumber(value) or 0
        if inset < 0 then return 0 end
        if inset > 0.03 then return 0.03 end
        return inset
    end

    if useAlternative then
        icon:SetTexture(
            UF.TEXTURES.CLASS_ICON_ALTERNATIVE_PREFIX
            .. classFileName
            .. UF.TEXTURES.CLASS_ICON_ALTERNATIVE_SUFFIX)
        icon:SetTexCoord(0, 1, 0, 1)
        return true
    end

    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFileName]
    if not coords then
        return false
    end

    local inset = ClampInset(UF.CLASSIC_CLASS_ICON_INSET)
    icon:SetTexture(UF.TEXTURES.CLASS_ICON)
    icon:SetTexCoord(
        coords[1] + inset, coords[2] - inset,
        coords[3] + inset, coords[4] - inset)
    return true
end

function UF.ApplyClassPortraitToTexture(unit, portraitTexture, useAlternative)
    if not portraitTexture or not unit then
        return false
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return false
    end

    local _, classFileName = UnitClass(unit)
    if not classFileName then
        return false
    end

    if UF.ApplyClassPortraitIcon(portraitTexture, classFileName, useAlternative) then
        portraitTexture:SetAlpha(1)
        return true
    end

    return false
end

function UF.UpdateClassPortrait(unit, portrait, parentFrame, elements, enabled, useAlternative)
    -- Legacy cleanup: old implementations used dedicated overlay frames.
    if elements then
        if elements.classPortraitFrame then elements.classPortraitFrame:Hide() end
        if elements.classPortraitBg then elements.classPortraitBg:Hide() end
        if elements.classPortraitIcon then elements.classPortraitIcon:Hide() end
    end

    if not enabled then
        return false
    end

    if useAlternative == nil and parentFrame and parentFrame.unitKey then
        useAlternative = UF.UseAlternativeClassIcons(parentFrame.unitKey)
    end

    return UF.ApplyClassPortraitToTexture(unit, portrait, useAlternative)
end


-- ============================================================================
-- BAR HOOK HELPERS
-- ============================================================================

-- Hooks SetValue on healthBar to clip the texture and optionally apply class color.

function UF.SetupHealthBarHook(healthBar, statusTexture, useClassColor)
    if not healthBar then return end

    hooksecurefunc(healthBar, "SetValue", function(self)
        local _, max = self:GetMinMaxValues()
        local val = self:GetValue()
        if max > 0 and val > 0 then
            local pct = val / max
            -- Clip texture to show only filled portion
            if statusTexture then
                statusTexture:SetTexCoord(0, pct, 0, 1)
                statusTexture:SetWidth(self:GetWidth() * pct)
            end
            -- Apply class color if enabled
            if useClassColor then
                local unit = self.unit or (self:GetParent() and self:GetParent().unit)
                if unit and UnitExists(unit) and UnitIsPlayer(unit) then
                    local _, class = UnitClass(unit)
                    if class then
                        local color = RAID_CLASS_COLORS[class]
                        if color and statusTexture then
                            statusTexture:SetVertexColor(color.r, color.g, color.b)
                        end
                    end
                end
            end
        end
    end)
end

-- Returns the texture suffix string for a given power type ID.

function UF.GetPowerBarTextureSuffix(powerType)
    return UF.POWER_MAP[powerType] or "Mana"
end

-- Returns the full party power bar texture path for a unit.

function UF.GetPartyPowerBarTexture(unit)
    if not unit or not UnitExists(unit) then
        return UF.TEXTURES.party.manaBar
    end
    local powerType = UnitPowerType(unit)
    if powerType == 1 then
        return UF.TEXTURES.party.rageBar
    elseif powerType == 2 then
        return UF.TEXTURES.party.focusBar
    elseif powerType == 3 then
        return UF.TEXTURES.party.energyBar
    elseif powerType == 6 then
        return UF.TEXTURES.party.runicPowerBar
    else
        return UF.TEXTURES.party.manaBar
    end
end

-- Returns the full pet power bar texture path for a power type string.

function UF.GetPetPowerTexture(powerTypeString)
    return UF.TEXTURES.pet.POWER_TEXTURES[powerTypeString]
        or UF.TEXTURES.pet.POWER_TEXTURES.MANA
end


-- ============================================================================
-- MODULE TEMPLATE
-- ============================================================================

function UF.CreateModule(name)
    return {
        name = name,
        overlay = nil,          -- Editor overlay frame (CreateUIFrame)
        textSystem = nil,       -- TextSystem reference
        initialized = false,    -- ADDON_LOADED has fired
        configured = false,     -- Frame setup is complete
        eventsFrame = nil,      -- Event handler frame
        elements = {},          -- Created textures/regions (for cleanup and reference)
    }
end
