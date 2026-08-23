-- ===============================================================
-- DRAGONUI PARTY FRAMES MODULE
-- ===============================================================
local addon = select(2, ...)
local UF = addon.UF

-- ===============================================================
-- EARLY EXIT CHECK
-- ===============================================================
-- Simplified: Only check if addon.db exists, not specifically unitframe.party
if not addon or not addon.db then
    return -- Exit early if database not ready
end

-- ===============================================================
-- IMPORTS AND GLOBALS
-- ===============================================================

-- Cache globals and APIs
local _G = _G
local unpack = unpack
local select = select
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitName, UnitClass = UnitName, UnitClass
local UnitExists, UnitIsConnected = UnitExists, UnitIsConnected
local UnitInRange, UnitIsDeadOrGhost = UnitInRange, UnitIsDeadOrGhost
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS or 4

-- ===============================================================
-- MODULE NAMESPACE AND STORAGE
-- ===============================================================

-- Module namespace
local PartyFrames = {}
addon.PartyFrames = PartyFrames

PartyFrames.textElements = {}
PartyFrames.anchor = nil
PartyFrames.initialized = false

-- ===============================================================
-- CONSTANTS AND CONFIGURATION
-- ===============================================================

-- Texture paths from shared core (single source of truth)
local TEXTURES = UF.TEXTURES.party

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Create auxiliary frame for anchoring (similar to target.lua)
local function CreatePartyAnchorFrame()
    if PartyFrames.anchor then
        return PartyFrames.anchor
    end

    -- Use centralized function from core.lua
    -- Initial size - will be updated dynamically based on orientation
    PartyFrames.anchor = addon.CreateUIFrame(130, 300, "PartyFrames")

    return PartyFrames.anchor
end

-- Update anchor size based on orientation
local function UpdatePartyAnchorSize()
    if not PartyFrames.anchor then return end
    
    local settings = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.party
    local orientation = settings and settings.orientation or 'vertical'
    local numMembers = MAX_PARTY_MEMBERS -- 4
    
    if orientation == 'horizontal' then
        local padding = (settings and tonumber(settings.padding_horizontal)) or 50
        local frameWidth = 120
        local frameHeight = 50
        local totalWidth = numMembers * frameWidth + (numMembers - 1) * padding
        PartyFrames.anchor:SetSize(totalWidth, frameHeight)
    else
        local padding = (settings and tonumber(settings.padding_vertical)) or 30
        local frameWidth = 130
        local frameHeight = 50
        local totalHeight = numMembers * frameHeight + (numMembers - 1) * padding
        PartyFrames.anchor:SetSize(frameWidth, totalHeight)
    end
end

local function IsCompactRaidFrameAddonLoaded()
    -- Runtime signal first: if compact raid/party frames already exist,
    -- we should treat compact mode as active regardless of addon ID.
    if _G.CompactRaidFrameManager or _G.CompactRaidFrame1 or _G.CompactPartyFrame then
        return true
    end

    -- Prefer CUF_CVar API when present (matches CompactRaidFrame reference).
    local useCompact = nil
    if CUF_CVar and CUF_CVar.GetCVarBool then
        useCompact = CUF_CVar:GetCVarBool("useCompactPartyFrames") and true or false
    elseif GetCVar then
        useCompact = (GetCVar("useCompactPartyFrames") == "1")
    end

    if useCompact then
        return true
    end

    if IsAddOnLoaded then
        -- Canonical addon folder name in this client branch.
        if IsAddOnLoaded("CompactRaidFrame") then
            return true
        end
    end

    return false
end

local function GetDefaultPartyPosX()
    return 10
end

local function GetCompactRaidPartyOffsetX()
    -- Runtime-only offset: avoids persisting shifted positions in the profile.
    if IsCompactRaidFrameAddonLoaded() then
        return 9
    end
    return 0
end

local function NormalizeCompactRaidPartyPosX(posX)
    local basePosX = posX or GetDefaultPartyPosX()

    -- Backward compatibility: old migrated defaults should fall back to base when
    -- CompactRaidFrames is not active.
    if not IsCompactRaidFrameAddonLoaded() then
        if basePosX == 19 or basePosX == 25 or basePosX == 30 then
            return GetDefaultPartyPosX()
        end
        return basePosX
    end

    -- Apply offset only for default-like positions, keep custom positions intact.
    if basePosX == 10 or basePosX == 19 or basePosX == 25 or basePosX == 30 then
        return GetDefaultPartyPosX() + GetCompactRaidPartyOffsetX()
    end

    return basePosX
end

-- Function to apply position from widgets (similar to target.lua)
local function ApplyWidgetPosition()
    if not PartyFrames.anchor then
        return
    end

    -- CRITICAL: Set BACKGROUND strata to stay behind Compact Raid Frames (which use LOW/MEDIUM)
    -- But skip strata reset during editor mode (overlay needs FULLSCREEN strata)
    if not InCombatLockdown() and not (addon.EditorMode and addon.EditorMode:IsActive()) then
        PartyFrames.anchor:SetFrameStrata('BACKGROUND')
        PartyFrames.anchor:SetFrameLevel(1)
    end

    -- Ensure configuration exists
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local widgetConfig = addon.db.profile.widgets.party

    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        local normalizedPosX = NormalizeCompactRaidPartyPosX(widgetConfig.posX)
        if normalizedPosX ~= widgetConfig.posX then
            widgetConfig.posX = normalizedPosX
        end

        -- Use saved anchor, not always TOPLEFT
        local anchor = widgetConfig.anchor or "TOPLEFT"
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint(anchor, UIParent, anchor, normalizedPosX, widgetConfig.posY)
    else
        -- Create default configuration if it doesn't exist
        if not addon.db.profile.widgets.party then
            addon.db.profile.widgets.party = {
                anchor = "TOPLEFT",
                posX = GetDefaultPartyPosX(),
                posY = -200
            }
        end
        PartyFrames.anchor:ClearAllPoints()
        PartyFrames.anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", GetDefaultPartyPosX(), -200)
    end
end

-- Functions required by the centralized system
function PartyFrames:LoadDefaultSettings()
    -- Ensure configuration exists in widgets
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end

    if not addon.db.profile.widgets.party then
        addon.db.profile.widgets.party = {
            anchor = "TOPLEFT",
            posX = GetDefaultPartyPosX(),
            posY = -200
        }
    end

    -- Ensure configuration exists in unitframe
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end

    if not addon.db.profile.unitframe.party then
        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = false,
            showManaTextAlways = false,
            orientation = 'vertical',
            padding_vertical = 30,
            padding_horizontal = 50,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = GetDefaultPartyPosX(),
            y = -200
        }
    end
end

function PartyFrames:UpdateWidgets()
    ApplyWidgetPosition()
    UpdatePartyAnchorSize() -- Update anchor size based on orientation
    if not InCombatLockdown() then
        local step = GetPartyStep()
        local orientation = GetOrientation()
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = _G['PartyMemberFrame' .. i]
            if frame and PartyFrames.anchor then
                frame:ClearAllPoints()
                if orientation == 'horizontal' then
                    local xOffset = (i - 1) * step
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", xOffset, 0)
                else
                    local yOffset = (i - 1) * -step
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
                end
            end
        end
    end
end

-- Function to check if party frames should be visible
local function IsCompactPartyFramesEnabled()
    -- Prefer CUF_CVar API when present (matches CompactRaidFrame reference).
    if CUF_CVar and CUF_CVar.GetCVarBool then
        return CUF_CVar:GetCVarBool("useCompactPartyFrames") and true or false
    end

    return GetCVar and GetCVar("useCompactPartyFrames") == "1"
end

local function IsHidePartyInRaidEnabled()
    if GetCVarBool then
        return GetCVarBool("hidePartyInRaid") and true or false
    end

    return GetCVar and GetCVar("hidePartyInRaid") == "1"
end

local function ShouldHidePartyFramesInRaid()
    return (GetNumRaidMembers and GetNumRaidMembers() > 0) and IsHidePartyInRaidEnabled()
end

local function ShouldPartyFramesBeVisible()
    if GetNumPartyMembers() == 0 then
        return false
    end

    -- CompactRaidFrames hides party frames in any raid; ClassicAPI stubs this global to return nil.
    if type(GetDisplayedAllyFrames) == "function" then
        local displayed = GetDisplayedAllyFrames()
        if displayed then
            return displayed == "party"
        end
    end

    return not IsCompactPartyFramesEnabled() and not ShouldHidePartyFramesInRaid()
end

-- Test functions for the editor
local function ShowPartyFramesTest()
    -- Update anchor size for editor mode
    UpdatePartyAnchorSize()
    -- Raise overlay strata so it appears ABOVE fake party frames
    if PartyFrames.anchor then
        PartyFrames.anchor:SetFrameStrata('FULLSCREEN')
        PartyFrames.anchor:SetFrameLevel(200)
    end
    -- Display party frames even if not in a group, keep strata below overlay
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            frame:SetFrameStrata('BACKGROUND')
            frame:SetFrameLevel(1)
            frame:Show()
        end
    end
end

local function HidePartyFramesTest()
    -- Restore normal strata
    if PartyFrames.anchor then
        PartyFrames.anchor:SetFrameStrata('MEDIUM')
        PartyFrames.anchor:SetFrameLevel(1)
    end
    -- Hide empty frames when not in a party
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame and not UnitExists("party" .. i) then
            frame:Hide()
        end
    end
end

-- ===============================================================
-- HELPER FUNCTIONS
-- ===============================================================

-- Get settings helper
local function GetSettings()
    -- Perform a robust check with default values
    if not addon.db or not addon.db.profile then
        return {
            scale = 1.0,
            classcolor = false,
            breakUpLargeNumbers = true
        }
    end

    local settings = addon.db.profile.unitframe and addon.db.profile.unitframe.party

    -- If configuration doesn't exist, create it with defaults
    if not settings then
        if not addon.db.profile.unitframe then
            addon.db.profile.unitframe = {}
        end

        addon.db.profile.unitframe.party = {
            enabled = true,
            classcolor = false,
            textFormat = 'both',
            breakUpLargeNumbers = true,
            showHealthTextAlways = false,
            showManaTextAlways = false,
            orientation = 'vertical',
            padding_vertical = 30,
            padding_horizontal = 50,
            scale = 1.0,
            override = false,
            anchor = 'TOPLEFT',
            anchorParent = 'TOPLEFT',
            x = GetDefaultPartyPosX(),
            y = -200
        }
        settings = addon.db.profile.unitframe.party
    end
    
    return settings
end

-- Format numbers helper — delegates to shared TextSystem
-- Text formatting — delegates to shared TextSystem
local function GetFormattedText(current, max, textFormat, breakUpLargeNumbers)
    return addon.TextSystem.FormatStatusText(current, max, textFormat, breakUpLargeNumbers)
end

-- Calculate step based on orientation
local function GetPartyStep()
    local settings = GetSettings()
    local orientation = settings and settings.orientation or 'vertical'
    
    if orientation == 'horizontal' then
        local pad = (settings and tonumber(settings.padding_horizontal)) or 50
        local base = 120  -- width of party frame
        return base + pad
    else
        local pad = (settings and tonumber(settings.padding_vertical)) or 30
        local base = 49   -- height of party frame
        return base + pad
    end
end

-- Get orientation from settings
local function GetOrientation()
    local settings = GetSettings()
    return settings and settings.orientation or 'vertical'
end


-- Get class color helper
-- Get texture coordinates for party frame elements
local function GetPartyCoords(type)
    if type == "background" then
        return 0.480469, 0.949219, 0.222656, 0.414062
    elseif type == "flash" then
        return 0.480469, 0.925781, 0.453125, 0.636719
    elseif type == "status" then
        return 0.00390625, 0.472656, 0.453125, 0.644531
    end
    return 0, 1, 0, 1
end

-- Power bar texture resolver (delegates to shared core)
local function GetPowerBarTexture(unit)
    return UF.GetPartyPowerBarTexture(unit)
end

-- ===============================================================
-- CLASS COLORS
-- ===============================================================

-- New function: Get class color for party member
local function GetPartyClassColor(partyIndex)
    local unit = "party" .. partyIndex
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return 1, 1, 1 -- White if not a player
    end

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end

    return 1, 1, 1 -- White by default
end

-- New function: Update party health bar with class color
local function UpdatePartyHealthBarColor(partyIndex)
    if not partyIndex or partyIndex < 1 or partyIndex > 4 then
        return
    end

    local unit = "party" .. partyIndex
    if not UnitExists(unit) then
        return
    end

    -- Color our own overlay bar, never Blizzard's native bar (touching it taints it).
    local frame = _G['PartyMemberFrame' .. partyIndex]
    local healthbar = frame and frame.DragonUI_HealthBar
    if not healthbar then
        return
    end

    local settings = GetSettings()
    if not settings then
        return
    end

    local texture = healthbar:GetStatusBarTexture()
    if not texture then
        return
    end

    if settings.classcolor and UnitIsPlayer(unit) then
        -- Use constant instead of hardcoded string
        local statusTexturePath = TEXTURES.healthBarStatus
        if texture:GetTexture() ~= statusTexturePath then
            texture:SetTexture(statusTexturePath)
        end

        -- Apply class color
        local r, g, b = GetPartyClassColor(partyIndex)
        healthbar:SetStatusBarColor(r, g, b, 1)
    else
        -- Use constant instead of hardcoded string
        local normalTexturePath = TEXTURES.healthBar
        if texture:GetTexture() ~= normalTexturePath then
            texture:SetTexture(normalTexturePath)
        end

        -- White color (texture already has color)
        healthbar:SetStatusBarColor(1, 1, 1, 1)
    end
end
-- ===============================================================
-- SIMPLE BLIZZARD BUFF/DEBUFF REPOSITIONING
-- ===============================================================
local function RepositionBlizzardBuffs()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- Position auras fully outside frame right edge
            -- Buff row at top, debuff row below (no vertical overlap between members)
            for auraIndex = 1, 4 do
                local buff = _G['PartyMemberFrame' .. i .. 'Buff' .. auraIndex]
                local debuff = _G['PartyMemberFrame' .. i .. 'Debuff' .. auraIndex]

                if buff then
                    buff:ClearAllPoints()
                    buff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 2 + (auraIndex - 1) * 17, -2)
                    buff:SetSize(15, 15)
                end

                if debuff then
                    debuff:ClearAllPoints()
                    debuff:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 2 + (auraIndex - 1) * 17, -19)
                    debuff:SetSize(15, 15)
                end
            end
        end
    end
end


-- ===============================================================
-- DYNAMIC CLIPPING SYSTEM
-- ===============================================================

-- Create our own health StatusBar overlaid on Blizzard's native one. We never touch
-- the native bar (that taints it and breaks its in-combat/vehicle Show/Hide); instead
-- we read its value via the SetValue hook and mirror it onto our own bar.
local function EnsureDragonHealthBar(frame)
    if not frame or frame.DragonUI_HealthBar then
        return frame and frame.DragonUI_HealthBar
    end

    local native = _G[frame:GetName() .. 'HealthBar']
    if not native then
        return nil
    end

    local db = CreateFrame("StatusBar", nil, frame)
    -- Good custom geometry (native bar is hidden below via SetAlpha, see test below).
    db:SetSize(71, 10)
    db:SetPoint('TOPLEFT', frame, 'TOPLEFT', 44, -19)
    db:SetFrameLevel(native:GetFrameLevel() + 1)
    db:SetStatusBarTexture(TEXTURES.healthBar)
    db:SetStatusBarColor(1, 1, 1, 1)
    frame.DragonUI_HealthBar = db

    -- Hide the native bar under our overlay; SetAlpha doesn't taint the frame (reskinning it does).
    native:SetAlpha(0)

    return db
end

-- Clip/color logic for a party health bar. `self` is Blizzard's native bar (from the
-- SetValue hook or a direct call) and is only READ; all writes go to our own overlay.
local function ApplyHealthBarClipping(self, value)
    local frame = self:GetParent()
    if not frame then
        return
    end
    local db = EnsureDragonHealthBar(frame)
    if not db then
        return
    end
    local frameIndex = frame:GetID()
    -- NOTE: Do NOT early return on !UnitExists — during ghost/spirit release
    -- UnitExists can briefly return false, leaving texture stuck invisible

    -- Mirror the native bar's range/value onto our own (read-only on the native bar).
    local min, max = self:GetMinMaxValues()
    local current = value or self:GetValue()
    db:SetMinMaxValues(min, max)
    db:SetValue(current or 0)

    local texture = db:GetStatusBarTexture()
    if not texture then
        return
    end

    -- If disconnected, show full bar in gray (Blizzard native behavior)
    if frame.DragonUI_Disconnected then
        texture:SetTexCoord(0, 1, 0, 1)
        db:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        return
    end

    -- Apply class color first (safe if unit doesn't exist — checks internally)
    UpdatePartyHealthBarColor(frameIndex)

    -- Dynamic clipping: Only show the filled part of the texture
    if max > 0 and current then
        -- Clamp to [0.001, 1] — max=1 can happen during BG loading/phasing
        -- while current holds the real health value, producing TexCoord out of range
        local percentage = math.min(math.max(current / max, 0.001), 1)
        texture:SetTexCoord(0, percentage, 0, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

-- Setup dynamic texture clipping for health bars
local function SetupHealthBarClipping(frame)
    if not frame then
        return
    end

    local healthbar = _G[frame:GetName() .. 'HealthBar']
    if not healthbar then
        return
    end

    EnsureDragonHealthBar(frame)

    if not healthbar.DragonUI_ClippingSetup then
        -- Read-only hook: Blizzard's SetValue drives our overlay, native bar untouched.
        hooksecurefunc(healthbar, "SetValue", ApplyHealthBarClipping)
        healthbar.DragonUI_ClippingSetup = true
        ApplyHealthBarClipping(healthbar, healthbar:GetValue()) -- seed initial fill
    end
end

-- Create our own mana StatusBar overlaid on Blizzard's native one (see health bar rationale).
local function EnsureDragonManaBar(frame)
    if not frame or frame.DragonUI_ManaBar then
        return frame and frame.DragonUI_ManaBar
    end

    local native = _G[frame:GetName() .. 'ManaBar']
    if not native then
        return nil
    end

    local db = CreateFrame("StatusBar", nil, frame)
    db:SetSize(74, 6.5)
    db:SetPoint('TOPLEFT', frame, 'TOPLEFT', 41, -30.5)
    db:SetFrameLevel(native:GetFrameLevel() + 1)
    local initTex = GetPowerBarTexture("party" .. frame:GetID())
    db:SetStatusBarTexture(initTex)
    db.__dui_powerTex = initTex
    db:SetStatusBarColor(1, 1, 1, 1)
    frame.DragonUI_ManaBar = db

    -- Hide the native bar under our overlay; SetAlpha doesn't taint (see health bar).
    native:SetAlpha(0)

    return db
end

-- Clip/texture logic for a party mana bar. `self` is Blizzard's native bar (read-only);
-- all writes go to our own overlay.
local function ApplyManaBarClipping(self, value)
    local frame = self:GetParent()
    if not frame then
        return
    end
    local db = EnsureDragonManaBar(frame)
    if not db then
        return
    end
    local unit = "party" .. frame:GetID()
    -- NOTE: Do NOT early return on !UnitExists — see health bar comment

    -- If disconnected, mana bar is hidden (alpha=0), skip all processing
    if frame.DragonUI_Disconnected then
        return
    end

    -- Mirror the native bar's range/value onto our own (read-only on the native bar).
    local min, max = self:GetMinMaxValues()
    local current = value or self:GetValue()
    db:SetMinMaxValues(min, max)
    db:SetValue(current or 0)

    -- Power-type texture (energy, rage, etc.) — only reassign when it actually changes.
    -- SetStatusBarTexture every SetValue rebuilds the texture region and caused a
    -- periodic hitch (energy ticks ~every 2s drove it constantly).
    local powerTexture = GetPowerBarTexture(unit)
    if db.__dui_powerTex ~= powerTexture then
        db:SetStatusBarTexture(powerTexture)
        db.__dui_powerTex = powerTexture
    end

    local texture = db:GetStatusBarTexture()
    if not texture then
        return
    end

    if max > 0 and current then
        -- Clamp to [0.001, 1] — max=1 can happen during BG loading/phasing
        -- while current holds the real mana value, producing TexCoord out of range
        local percentage = math.min(math.max(current / max, 0.001), 1)
        texture:SetTexCoord(0, percentage, 0, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end

    texture:SetVertexColor(1, 1, 1, 1)
end

-- Setup dynamic texture clipping for mana bars
local function SetupManaBarClipping(frame)
    if not frame then
        return
    end

    local manabar = _G[frame:GetName() .. 'ManaBar']
    if not manabar then
        return
    end

    EnsureDragonManaBar(frame)

    if not manabar.DragonUI_ClippingSetup then
        -- Read-only hook: Blizzard's SetValue drives our overlay, native bar untouched.
        hooksecurefunc(manabar, "SetValue", ApplyManaBarClipping)
        manabar.DragonUI_ClippingSetup = true
        ApplyManaBarClipping(manabar, manabar:GetValue()) -- seed initial fill
    end
end

-- ===============================================================
-- TEXT MANAGEMENT SYSTEM (TAINT-FREE)
-- ===============================================================

-- Hide Blizzard texts permanently with alpha 0 (no taint)
local function HideBlizzardTexts(frame)
    if not frame then return end
    
    local healthText = _G[frame:GetName() .. 'HealthBarText']
    local manaText = _G[frame:GetName() .. 'ManaBarText']
    
    -- Set alpha to 0 instead of hiding to avoid taint
    -- Use hooksecurefunc to re-force alpha=0 after any Blizzard SetAlpha call
    -- A recursion guard flag prevents infinite loop since our SetAlpha(0) also triggers the hook
    if healthText then
        healthText:SetAlpha(0)
        if not healthText.DragonUI_AlphaHooked then
            hooksecurefunc(healthText, "SetAlpha", function(self, alpha)
                if not self.DragonUI_AlphaGuard and alpha ~= 0 then
                    self.DragonUI_AlphaGuard = true
                    self:SetAlpha(0)
                    self.DragonUI_AlphaGuard = nil
                end
            end)
            healthText.DragonUI_AlphaHooked = true
        end
    end
    
    if manaText then
        manaText:SetAlpha(0)
        if not manaText.DragonUI_AlphaHooked then
            hooksecurefunc(manaText, "SetAlpha", function(self, alpha)
                if not self.DragonUI_AlphaGuard and alpha ~= 0 then
                    self.DragonUI_AlphaGuard = true
                    self:SetAlpha(0)
                    self.DragonUI_AlphaGuard = nil
                end
            end)
            manaText.DragonUI_AlphaHooked = true
        end
    end
end

-- Tracking hover state to prevent text disappearing during updates
local hoverStates = {}

-- Forward declaration for CreateCustomTexts (used in update functions)
local CreateCustomTexts
local UpdateHealthText
local UpdateManaText

local PARTY_TEXT_SIZE = 11
local PARTY_TEXT_FLAGS = "OUTLINE"

local function ApplyPartyTextVisualStyle(fontString)
    if not fontString then
        return
    end

    fontString:SetTextColor(1, 1, 1, 1)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function GetPartyTextFontPath()
    return (UF and UF.DEFAULT_FONT) or (addon.Fonts and addon.Fonts.PRIMARY) or "Fonts\\FRIZQT__.TTF"
end

local function EnsurePartyTextFont(fontString)
    if not fontString then
        return false
    end

    if fontString:GetFont() then
        return true
    end

    if GameFontNormalSmall then
        fontString:SetFontObject(TextStatusBarText or GameFontNormalSmall)
    end

    local fontPath = GetPartyTextFontPath()
    if fontPath and fontString:SetFont(fontPath, PARTY_TEXT_SIZE, PARTY_TEXT_FLAGS) then
        return true
    end

    local fallbackPath, _, fallbackFlags = fontString:GetFont()
    if fallbackPath then
        return fontString:SetFont(fallbackPath, PARTY_TEXT_SIZE, fallbackFlags or PARTY_TEXT_FLAGS) and true or false
    end

    return false
end

-- ===============================================================
-- TEXT AND COLOR UPDATE FUNCTIONS
-- ===============================================================

local BAR_TEXT_KINDS = {
    health = {
        center = "DragonUI_HealthText",
        left = "DragonUI_HealthTextLeft",
        right = "DragonUI_HealthTextRight",
        hoverKey = "health",
        alwaysKey = "showHealthTextAlways",
        GetValues = function(unit) return UnitHealth(unit), UnitHealthMax(unit) end,
    },
    mana = {
        center = "DragonUI_ManaText",
        left = "DragonUI_ManaTextLeft",
        right = "DragonUI_ManaTextRight",
        hoverKey = "mana",
        alwaysKey = "showManaTextAlways",
        GetValues = function(unit) return UnitPower(unit), UnitPowerMax(unit) end,
    },
}

local function HidePartyBarText(frame, spec)
    local center, left, right = frame[spec.center], frame[spec.left], frame[spec.right]
    if center then center:Hide() end
    if left then left:Hide() end
    if right then right:Hide() end
end

-- Taint-free health/mana text update
local function UpdatePartyBarText(kind, statusBar, forceShow)
    if not statusBar then return end

    local spec = BAR_TEXT_KINDS[kind]
    local frame = statusBar:GetParent()
    local frameIndex = frame:GetName():match("PartyMemberFrame(%d+)")
    if not frameIndex then return end

    local partyUnit = "party" .. frameIndex
    if not UnitExists(partyUnit) then return end

    if not UnitIsConnected(partyUnit) then
        HidePartyBarText(frame, spec)
        return
    end

    CreateCustomTexts(frame)

    local centerText = frame[spec.center]
    if not centerText then return end

    local settings = GetSettings()

    -- unitframe_layers missing-health mode draws its own numbers; ours would overlap.
    if kind == "health" then
        local uflCfg = addon.GetModuleConfig and addon:GetModuleConfig("unitframe_layers")
        if uflCfg and uflCfg.missing_health == true then
            HidePartyBarText(frame, spec)
            return
        end
    end

    local hoverState = hoverStates[tonumber(frameIndex)]
    local isHovering = false

    if hoverState then
        isHovering = hoverState.portrait or hoverState[spec.hoverKey]
    end

    local shouldShow = false

    if forceShow or isHovering then
        shouldShow = true
    elseif settings and settings[spec.alwaysKey] then
        shouldShow = true
    end

    if not shouldShow then
        HidePartyBarText(frame, spec)
        return
    end

    local current, max = spec.GetValues(partyUnit)

    if current and max and max > 0 then
        local textFormat = settings and settings.textFormat or "formatted"
        local breakUp = settings and settings.breakUpLargeNumbers
        local finalText = GetFormattedText(current, max, textFormat, breakUp)
        local leftText, rightText = frame[spec.left], frame[spec.right]

        if textFormat == "both" and type(finalText) == "table" then
            centerText:Hide()
            if EnsurePartyTextFont(leftText) then
                leftText:SetText(finalText.left or "")
                leftText:Show()
            end
            if EnsurePartyTextFont(rightText) then
                rightText:SetText(finalText.right or "")
                rightText:Show()
            end
        else
            if leftText then leftText:Hide() end
            if rightText then rightText:Hide() end
            if EnsurePartyTextFont(centerText) then
                centerText:SetText(finalText or "")
                centerText:Show()
            end
        end
    else
        HidePartyBarText(frame, spec)
    end
end

UpdateHealthText = function(statusBar, forceShow)
    UpdatePartyBarText("health", statusBar, forceShow)
end

UpdateManaText = function(statusBar, forceShow)
    UpdatePartyBarText("mana", statusBar, forceShow)
end

-- Create invisible hover frames for independent health/mana text display
local function CreateHoverFrames(frame, frameIndex)
    if not frame or frame.DragonUI_HoverFrames then return end
    
    local healthBar = EnsureDragonHealthBar(frame) or _G[frame:GetName() .. 'HealthBar']
    local manaBar = EnsureDragonManaBar(frame) or _G[frame:GetName() .. 'ManaBar']
    local unitToken = "party" .. frameIndex
    
    -- Create hover frame for health bar
    if healthBar and not frame.DragonUI_HealthHover then
        frame.DragonUI_HealthHover = CreateFrame("Button", nil, frame.DragonUI_TextFrame, "SecureUnitButtonTemplate")
        frame.DragonUI_HealthHover:SetFrameLevel(frame.DragonUI_TextFrame:GetFrameLevel() + 1)
        frame.DragonUI_HealthHover:SetAllPoints(healthBar)
        frame.DragonUI_HealthHover:RegisterForClicks("AnyUp")
        frame.DragonUI_HealthHover:SetAttribute("unit", unitToken)
        frame.DragonUI_HealthHover:SetAttribute("*type1", "target")
        frame.DragonUI_HealthHover:SetAttribute("*type2", "togglemenu")
        frame.DragonUI_HealthHover:EnableMouse(true)
        frame.DragonUI_HealthHover:SetScript("OnEnter", function()
            hoverStates[frameIndex].health = true
            HideBlizzardTexts(frame)
            UpdateHealthText(healthBar, true) -- Only show health text
            -- Only hide mana text if it's NOT set to always show
            local settings = GetSettings()
            if not (settings and settings.showManaTextAlways) then
                if frame.DragonUI_ManaText then frame.DragonUI_ManaText:Hide() end
                if frame.DragonUI_ManaTextLeft then frame.DragonUI_ManaTextLeft:Hide() end
                if frame.DragonUI_ManaTextRight then frame.DragonUI_ManaTextRight:Hide() end
            end
        end)
        frame.DragonUI_HealthHover:SetScript("OnLeave", function()
            hoverStates[frameIndex].health = false
            HideBlizzardTexts(frame)
            -- Return to normal visibility for both texts
            UpdateHealthText(healthBar, false)
            if manaBar then UpdateManaText(manaBar, false) end
        end)
    end
    
    -- Create hover frame for mana bar
    if manaBar and not frame.DragonUI_ManaHover then
        frame.DragonUI_ManaHover = CreateFrame("Button", nil, frame.DragonUI_TextFrame, "SecureUnitButtonTemplate")
        frame.DragonUI_ManaHover:SetFrameLevel(frame.DragonUI_TextFrame:GetFrameLevel() + 1)
        frame.DragonUI_ManaHover:SetAllPoints(manaBar)
        frame.DragonUI_ManaHover:RegisterForClicks("AnyUp")
        frame.DragonUI_ManaHover:SetAttribute("unit", unitToken)
        frame.DragonUI_ManaHover:SetAttribute("*type1", "target")
        frame.DragonUI_ManaHover:SetAttribute("*type2", "togglemenu")
        frame.DragonUI_ManaHover:EnableMouse(true)
        frame.DragonUI_ManaHover:SetScript("OnEnter", function()
            hoverStates[frameIndex].mana = true
            HideBlizzardTexts(frame)
            UpdateManaText(manaBar, true) -- Only show mana text
            -- Only hide health text if it's NOT set to always show
            local settings = GetSettings()
            if not (settings and settings.showHealthTextAlways) then
                if frame.DragonUI_HealthText then frame.DragonUI_HealthText:Hide() end
                if frame.DragonUI_HealthTextLeft then frame.DragonUI_HealthTextLeft:Hide() end
                if frame.DragonUI_HealthTextRight then frame.DragonUI_HealthTextRight:Hide() end
            end
        end)
        frame.DragonUI_ManaHover:SetScript("OnLeave", function()
            hoverStates[frameIndex].mana = false
            HideBlizzardTexts(frame)
            -- Return to normal visibility for both texts
            if healthBar then UpdateHealthText(healthBar, false) end
            UpdateManaText(manaBar, false)
        end)
    end
    
    frame.DragonUI_HoverFrames = true
end

-- Create our own text elements for party frames
CreateCustomTexts = function(frame)
    if not frame then return end

    if frame.DragonUI_CustomTexts then
        EnsurePartyTextFont(frame.DragonUI_HealthText)
        EnsurePartyTextFont(frame.DragonUI_HealthTextLeft)
        EnsurePartyTextFont(frame.DragonUI_HealthTextRight)
        EnsurePartyTextFont(frame.DragonUI_ManaText)
        EnsurePartyTextFont(frame.DragonUI_ManaTextLeft)
        EnsurePartyTextFont(frame.DragonUI_ManaTextRight)
        return
    end

    if InCombatLockdown() then
        return
    end
    
    local frameIndex = frame:GetID()
    if not frameIndex or frameIndex < 1 or frameIndex > 4 then return end
    
    -- Initialize hover states (separate for health and mana)
    if not hoverStates[frameIndex] then
        hoverStates[frameIndex] = {
            portrait = false,
            health = false,
            mana = false
        }
    end
    
    -- Create text frame with proper layering (above border)
    if not frame.DragonUI_TextFrame then
        frame.DragonUI_TextFrame = CreateFrame("Frame", nil, frame)
        frame.DragonUI_TextFrame:SetFrameLevel(frame:GetFrameLevel() + 4) -- Above border and bars
        frame.DragonUI_TextFrame:SetAllPoints(frame)
    end

    -- Create custom health text elements (dual system for "both" format)
    -- Anchor to our overlay bar (not Blizzard's), matching where the fill is drawn.
    local healthBar = EnsureDragonHealthBar(frame) or _G[frame:GetName() .. 'HealthBar']
    if healthBar then
        -- Center text for simple formats (numeric, percentage, formatted)
        if not frame.DragonUI_HealthText then
            frame.DragonUI_HealthText = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            frame.DragonUI_HealthText:SetPoint("CENTER", healthBar, "CENTER", 2, 0)
            frame.DragonUI_HealthText:SetJustifyH("CENTER")
            frame.DragonUI_HealthText:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        ApplyPartyTextVisualStyle(frame.DragonUI_HealthText)
        EnsurePartyTextFont(frame.DragonUI_HealthText)
        -- Left text for "both" format (percentage)
        if not frame.DragonUI_HealthTextLeft then
            frame.DragonUI_HealthTextLeft = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            frame.DragonUI_HealthTextLeft:SetPoint("RIGHT", healthBar, "RIGHT", -37, 0)
            frame.DragonUI_HealthTextLeft:SetJustifyH("LEFT")
            frame.DragonUI_HealthTextLeft:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        ApplyPartyTextVisualStyle(frame.DragonUI_HealthTextLeft)
        EnsurePartyTextFont(frame.DragonUI_HealthTextLeft)
        -- Right text for "both" format (numbers)
        if not frame.DragonUI_HealthTextRight then
            frame.DragonUI_HealthTextRight = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            frame.DragonUI_HealthTextRight:SetPoint("RIGHT", healthBar, "RIGHT", -1, 0)
            frame.DragonUI_HealthTextRight:SetJustifyH("RIGHT")
            frame.DragonUI_HealthTextRight:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        ApplyPartyTextVisualStyle(frame.DragonUI_HealthTextRight)
        EnsurePartyTextFont(frame.DragonUI_HealthTextRight)
    end

    -- Create custom mana text elements (dual system for "both" format)
    -- Anchor to our overlay bar (not Blizzard's), matching where the fill is drawn.
    local manaBar = EnsureDragonManaBar(frame) or _G[frame:GetName() .. 'ManaBar']
    if manaBar then
        -- Center text for simple formats
        if not frame.DragonUI_ManaText then
            frame.DragonUI_ManaText = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            frame.DragonUI_ManaText:SetPoint("CENTER", manaBar, "CENTER", 3.5, 0)
            frame.DragonUI_ManaText:SetJustifyH("CENTER")
            frame.DragonUI_ManaText:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        ApplyPartyTextVisualStyle(frame.DragonUI_ManaText)
        EnsurePartyTextFont(frame.DragonUI_ManaText)
        -- Left text for "both" format (percentage)
        if not frame.DragonUI_ManaTextLeft then
            frame.DragonUI_ManaTextLeft = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            frame.DragonUI_ManaTextLeft:SetPoint("RIGHT", manaBar, "RIGHT", -37, 0)
            frame.DragonUI_ManaTextLeft:SetJustifyH("LEFT")
            frame.DragonUI_ManaTextLeft:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        ApplyPartyTextVisualStyle(frame.DragonUI_ManaTextLeft)
        EnsurePartyTextFont(frame.DragonUI_ManaTextLeft)
        -- Right text for "both" format (numbers)
        if not frame.DragonUI_ManaTextRight then
            frame.DragonUI_ManaTextRight = frame.DragonUI_TextFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            frame.DragonUI_ManaTextRight:SetPoint("RIGHT", manaBar, "RIGHT", -1, 0)
            frame.DragonUI_ManaTextRight:SetJustifyH("RIGHT")
            frame.DragonUI_ManaTextRight:SetDrawLayer("OVERLAY", 1) -- Above everything
        end
        ApplyPartyTextVisualStyle(frame.DragonUI_ManaTextRight)
        EnsurePartyTextFont(frame.DragonUI_ManaTextRight)
    end
    
    -- Create invisible dummy frames for independent hover (taint-free)
    CreateHoverFrames(frame, frameIndex)
    
    frame.DragonUI_CustomTexts = true
end

-- (UpdateHealthText and UpdateManaText functions moved above before CreateHoverFrames)

-- Update party colors function
-- New function: Update mana bar texture
local function UpdateManaBarTexture(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        return
    end

    local manabar = EnsureDragonManaBar(frame)
    if manabar then
        local powerTexture = GetPowerBarTexture(unit)
        if manabar.__dui_powerTex ~= powerTexture then
            manabar:SetStatusBarTexture(powerTexture)
            manabar.__dui_powerTex = powerTexture
        end
        manabar:SetStatusBarColor(1, 1, 1, 1) -- Keep white
    end
end
-- ===============================================================
-- FRAME STYLING FUNCTIONS
-- ===============================================================

-- Main styling function for party frames
local function StylePartyFrames()
    -- Skip all restyling during editor mode (prevents texture/layer race conditions on fake frames)
    if addon.EditorMode and addon.EditorMode:IsActive() then return end

    local settings = GetSettings()
    if not settings then return end

    CreatePartyAnchorFrame()
    ApplyWidgetPosition()

    local step = GetPartyStep()
    local orientation = GetOrientation()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            if not InCombatLockdown() then
                frame:SetScale(settings.scale or 1)
                frame:SetFrameStrata('BACKGROUND')
                frame:SetFrameLevel(1)
                frame:ClearAllPoints()
                if orientation == 'horizontal' then
                    local xOffset = (i - 1) * step
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", xOffset, 0)
                else
                    local yOffset = (i - 1) * -step
                    frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
                end
            end

            -- Hide background (and permanently prevent Blizzard's "Party/Arena Background" CVar from showing it)
            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
                if not bg.DragonUI_ShowHooked then
                    hooksecurefunc(bg, "Show", function(self) self:Hide() end)
                    bg.DragonUI_ShowHooked = true
                end
            end

            -- Hide default texture
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
                if not texture.DragonUI_ShowHooked then
                    hooksecurefunc(texture, "Show", function(self) self:Hide() end)
                    texture.DragonUI_ShowHooked = true
                end
            end

            -- Hide vehicle texture (shown when party member is in a vehicle)
            local vehicleTex = _G[frame:GetName() .. 'VehicleTexture']
            if vehicleTex then
                vehicleTex:SetTexture()
                vehicleTex:Hide()
                if not vehicleTex.DragonUI_ShowHooked then
                    hooksecurefunc(vehicleTex, "Show", function(self) self:Hide() end)
                    vehicleTex.DragonUI_ShowHooked = true
                end
            end

            -- Lock portrait position so Blizzard vehicle transitions can't move it
            local portrait = _G[frame:GetName() .. 'Portrait']
            if portrait and not portrait.DragonUI_SetPointHooked then
                local isResetting = false
                hooksecurefunc(portrait, "SetPoint", function(self)
                    if isResetting or InCombatLockdown() then return end
                    isResetting = true
                    self:ClearAllPoints()
                    self:SetPoint("TOPLEFT", 7, -6)
                    isResetting = false
                end)
                portrait.DragonUI_SetPointHooked = true
            end

            -- Health bar: native bar left untouched (reskinning it taints it); our own
            -- overlay bar is created and driven by SetupHealthBarClipping.
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            if healthbar and not InCombatLockdown() then
                SetupHealthBarClipping(frame)
                UpdatePartyHealthBarColor(i)
            end

            -- Mana bar: native bar left untouched (reskinning it taints it); our own
            -- overlay bar is created and driven by SetupManaBarClipping.
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if manabar and not InCombatLockdown() then
                SetupManaBarClipping(frame)
                UpdateManaBarTexture(frame)
            end

            -- Name styling
           local name = _G[frame:GetName() .. 'Name']
            if name then
                name:SetFont(UF.DEFAULT_FONT, 10)
                name:SetShadowOffset(1, -1)
                name:SetTextColor(1, 0.82, 0, 1) -- Yellow like the rest

                if not InCombatLockdown() then
                    name:ClearAllPoints()
                    name:SetPoint('TOPLEFT', 46, -5)
                    name:SetSize(57, 12)
                end
            end

            -- LEADER ICON STYLING
            local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
            if leaderIcon then -- Removed and not InCombatLockdown()
                leaderIcon:ClearAllPoints()
                leaderIcon:SetPoint('TOPLEFT', 42, 9) -- Custom position
                leaderIcon:SetSize(16, 16) -- Custom size (optional)
            end

            -- Master looter icon styling
            local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
            if masterLooterIcon then -- No combat restriction
                masterLooterIcon:ClearAllPoints()
                masterLooterIcon:SetPoint('TOPLEFT', 58, 11) -- Position next to leader icon
                masterLooterIcon:SetSize(16, 16) -- Custom size

            end

            -- Flash setup
            local flash = _G[frame:GetName() .. 'Flash']
            if flash then
                flash:SetSize(114, 47)
                flash:SetTexture(TEXTURES.frame)
                flash:SetTexCoord(GetPartyCoords("flash"))
                flash:SetPoint('TOPLEFT', 2, -2)
                flash:SetVertexColor(1, 0, 0, 1)
                flash:SetDrawLayer('OVERLAY', 1)
            end

            -- Create background and mark as styled
            if not frame.DragonUIStyled then
                -- Background (behind everything)
                local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 0)
                background:SetTexture(TEXTURES.frame)
                background:SetTexCoord(GetPartyCoords("background"))
                background:SetSize(120, 49)
                background:SetPoint('TOPLEFT', 1, -2)

                -- Create border as a separate FRAME (not texture) to appear above bars
                if not frame.DragonUI_BorderFrame then
                    frame.DragonUI_BorderFrame = CreateFrame("Frame", nil, frame)
                    frame.DragonUI_BorderFrame:SetFrameLevel(frame:GetFrameLevel() + 3) -- Above health/mana bars (level 2)
                    frame.DragonUI_BorderFrame:SetAllPoints(frame)
                    
                    -- Now create border texture inside the border frame
                    local border = frame.DragonUI_BorderFrame:CreateTexture(nil, 'ARTWORK', nil, 1)
                    border:SetTexture(TEXTURES.border)
                    border:SetTexCoord(GetPartyCoords("border"))
                    border:SetSize(128, 64)
                    border:SetPoint('TOPLEFT', 1, -2)
                    border:SetVertexColor(1, 1, 1, 1)
                    frame.DragonUI_BorderFrame.texture = border
                end

                if not frame.DragonUI_FlashContainer then
                    local flashContainer = CreateFrame("Frame", nil, frame)
                    flashContainer:SetFrameStrata("BACKGROUND")
                    flashContainer:SetFrameLevel(frame:GetFrameLevel() + 6) -- Above border, below icons
                    flashContainer:SetAllPoints(frame)
                    frame.DragonUI_FlashContainer = flashContainer
                end

                -- Create icon container well above border frame
                if not frame.DragonUI_IconContainer then
                    local iconContainer = CreateFrame("Frame", nil, frame)
                    iconContainer:SetFrameStrata("BACKGROUND")  -- Same strata as party frame
                    iconContainer:SetFrameLevel(frame:GetFrameLevel() + 10)  -- Well above border (+3)
                    iconContainer:SetAllPoints(frame)
                    frame.DragonUI_IconContainer = iconContainer
                end

                if flash and frame.DragonUI_FlashContainer and flash:GetParent() ~= frame.DragonUI_FlashContainer then
                    flash:SetParent(frame.DragonUI_FlashContainer)
                    flash:ClearAllPoints()
                    flash:SetPoint('TOPLEFT', frame, 'TOPLEFT', 2, -2)
                end

                -- Move icons to HIGH strata container and configure layers
                local name = _G[frame:GetName() .. 'Name']
                local healthText = _G[frame:GetName() .. 'HealthBarText']
                local manaText = _G[frame:GetName() .. 'ManaBarText']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local blizzardRoleIcon = _G[frame:GetName() .. 'RoleIcon']
                local guideIcon = _G[frame:GetName() .. 'GuideIcon']
                
                -- Text elements stay in normal layer
                if name then
                    name:SetDrawLayer('OVERLAY', 1)
                end
                if healthText then
                    healthText:SetDrawLayer('OVERLAY', 1)
                end
                if manaText then
                    manaText:SetDrawLayer('OVERLAY', 1)
                end
                
                -- Move PvP and status icons to icon container (above border)
                if leaderIcon then
                    leaderIcon:SetParent(frame.DragonUI_IconContainer)
                    leaderIcon:SetDrawLayer('OVERLAY', 1)
                end
                if masterLooterIcon then
                    masterLooterIcon:SetParent(frame.DragonUI_IconContainer)
                    masterLooterIcon:SetDrawLayer('OVERLAY', 1)
                end
                if pvpIcon then
                    pvpIcon:SetParent(frame.DragonUI_IconContainer)
                    pvpIcon:SetDrawLayer('OVERLAY', 1)
                end
                if statusIcon then 
                    statusIcon:SetParent(frame.DragonUI_IconContainer)
                    statusIcon:SetDrawLayer('OVERLAY', 1)
                end
                if blizzardRoleIcon then
                    blizzardRoleIcon:SetParent(frame.DragonUI_IconContainer)
                    blizzardRoleIcon:SetDrawLayer('OVERLAY', 1)
                end
                if guideIcon then
                    guideIcon:SetParent(frame.DragonUI_IconContainer)
                    guideIcon:SetDrawLayer('OVERLAY', 1)
                end

                frame.DragonUIStyled = true
            end
            -- Hide Blizzard texts and create our custom ones
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            
            -- Update our custom texts initially
            if healthbar then
                UpdateHealthText(healthbar, false)
            end
            if manabar then
                UpdateManaText(manabar, false)
            end

            frame.DragonUIStyled = true
        end
    end
end

-- ===============================================================
-- DISCONNECTED PLAYERS
-- ===============================================================
local function UpdateDisconnectedState(frame)
    if not frame then
        return
    end

    local unit = "party" .. frame:GetID()
    if not UnitExists(unit) then
        -- Member left or slot is empty: clear stale disconnected state.
        frame.DragonUI_Disconnected = false

        local healthbar = EnsureDragonHealthBar(frame)
        local manabar = EnsureDragonManaBar(frame)
        local portrait = _G[frame:GetName() .. 'Portrait']
        local name = _G[frame:GetName() .. 'Name']

        if healthbar then
            healthbar:SetAlpha(1.0)
        end
        if manabar then
            manabar:SetAlpha(1.0)
        end
        if portrait then
            portrait:SetVertexColor(1, 1, 1, 1)
        end
        if name then
            name:SetTextColor(1, 0.82, 0, 1)
        end

        return
    end

    local isConnected = UnitIsConnected(unit)
    local healthbar = EnsureDragonHealthBar(frame)
    local manabar = EnsureDragonManaBar(frame)
    local portrait = _G[frame:GetName() .. 'Portrait']
    local name = _G[frame:GetName() .. 'Name']

    if not isConnected then
        -- Mark frame as disconnected (used by clipping hooks to force gray)
        frame.DragonUI_Disconnected = true

        -- Disconnected member - gray bars at full, no text (Blizzard native behavior)
        if healthbar then
            healthbar:SetAlpha(0.3)
            healthbar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        end

        -- Hide all custom health text elements (numbers should not show when offline)
        if frame.DragonUI_HealthText then frame.DragonUI_HealthText:Hide() end
        if frame.DragonUI_HealthTextLeft then frame.DragonUI_HealthTextLeft:Hide() end
        if frame.DragonUI_HealthTextRight then frame.DragonUI_HealthTextRight:Hide() end

        -- Hide all custom mana text elements
        if frame.DragonUI_ManaText then frame.DragonUI_ManaText:Hide() end
        if frame.DragonUI_ManaTextLeft then frame.DragonUI_ManaTextLeft:Hide() end
        if frame.DragonUI_ManaTextRight then frame.DragonUI_ManaTextRight:Hide() end

        if manabar then
            manabar:SetAlpha(0)  -- Completely hide mana bar when offline (works in combat)
        end

        if portrait then
            portrait:SetVertexColor(0.5, 0.5, 0.5, 1)
        end

        if name then
            name:SetTextColor(0.6, 0.6, 0.6, 1)
        end

        -- Reposition icons so they don't get lost
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 11)
            masterLooterIcon:SetSize(16, 16)
        end

    else
        -- Connected member - undo exactly what was done when disconnecting
        frame.DragonUI_Disconnected = false

        -- Restore transparencies (without taint)
        if healthbar then
            healthbar:SetAlpha(1.0) -- Normal opacity
            -- Restore correct color (class color or white)
            local frameIndex = frame:GetID()
            UpdatePartyHealthBarColor(frameIndex) -- Only updates color, does not recreate frame
        end

        if manabar then
            manabar:SetAlpha(1.0) -- Restore visibility
            manabar:SetStatusBarColor(1, 1, 1, 1) -- White as it should be
            local manaTexture = manabar:GetStatusBarTexture()
            if manaTexture then
                manaTexture:SetVertexColor(1, 1, 1, 1)
            end
        end

        if portrait then
            portrait:SetVertexColor(1, 1, 1, 1) -- Normal color
        end

        if name then
            name:SetTextColor(1, 0.82, 0, 1) -- Normal yellow
        end

        -- Reposition icons (without recreating frames)
        local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
        if leaderIcon then
            leaderIcon:ClearAllPoints()
            leaderIcon:SetPoint('TOPLEFT', 42, 9)
            leaderIcon:SetSize(16, 16)
        end

        local masterLooterIcon = _G[frame:GetName() .. 'MasterIcon']
        if masterLooterIcon then
            masterLooterIcon:ClearAllPoints()
            masterLooterIcon:SetPoint('TOPLEFT', 58, 11)
            masterLooterIcon:SetSize(16, 16)
        end
    end
end

local function ShouldShowDragonUIPartySlot(index)
    if not ShouldPartyFramesBeVisible() then
        return false
    end
    return UnitExists("party" .. index)
end

local function RefreshSinglePartyFrameVisibility(index)
    local frame = _G['PartyMemberFrame' .. index]
    if not frame then
        return
    end

    -- Never hide party frames while editor mode is active (test frames are shown intentionally)
    if addon.EditorMode and addon.EditorMode:IsActive() then
        return
    end

    -- Keep disconnect visuals in sync before deciding visibility.
    UpdateDisconnectedState(frame)

    if ShouldShowDragonUIPartySlot(index) then
        frame:Show()
    else
        frame:Hide()
    end

    if addon.VisibilityFade then
        addon.VisibilityFade.Update("party" .. index)
    end
end

local function RefreshAllPartyFrameVisibility()
    for i = 1, MAX_PARTY_MEMBERS do
        RefreshSinglePartyFrameVisibility(i)
    end
end

local function RequestPartyVisibilityRefresh()
    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("party_refresh", RefreshAllPartyFrameVisibility)
        end
        return
    end

    RefreshAllPartyFrameVisibility()
end




-- ===============================================================
-- HOOK SETUP FUNCTION
-- ===============================================================

-- Setup all necessary hooks for party frames
local function SetupPartyHooks()
    hooksecurefunc("PartyMemberFrame_UpdateMember", function(frame)
        -- Skip restyling during editor mode (fake frames should stay as-is)
        if addon.EditorMode and addon.EditorMode:IsActive() then return end
        if frame and frame:GetName():match("^PartyMemberFrame%d+$") then
            local frameIndex = frame:GetID()
            local unit = frameIndex and ("party" .. frameIndex)

            if unit and UnitExists(unit) and not frame:IsShown() and not InCombatLockdown()
                and ShouldPartyFramesBeVisible() then
                frame:Show()
            end

            if PartyFrames.anchor and not InCombatLockdown() then
                if frameIndex and frameIndex >= 1 and frameIndex <= 4 then
                    frame:ClearAllPoints()
                    local step = GetPartyStep()
                    local orientation = GetOrientation()
                    if orientation == 'horizontal' then
                        local xOffset = (frameIndex - 1) * step
                        frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", xOffset, 0)
                    else
                        local yOffset = (frameIndex - 1) * -step
                        frame:SetPoint("TOPLEFT", PartyFrames.anchor, "TOPLEFT", 0, yOffset)
                    end
                end
            end

            -- Re-hide textures (always needed)
            local texture = _G[frame:GetName() .. 'Texture']
            if texture then
                texture:SetTexture()
                texture:Hide()
            end

            -- Re-hide vehicle texture
            local vehicleTex = _G[frame:GetName() .. 'VehicleTexture']
            if vehicleTex then
                vehicleTex:SetTexture()
                vehicleTex:Hide()
            end

            local bg = _G[frame:GetName() .. 'Background']
            if bg then
                bg:Hide()
            end

            -- Maintain only clipping configuration (ACE3 handles colors)
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']

            if healthbar then
                SetupHealthBarClipping(frame)
            end

            if manabar then
                SetupManaBarClipping(frame)
            end

            -- Update power bar texture
            UpdateManaBarTexture(frame)
            -- Disconnected state
            UpdateDisconnectedState(frame)
            
            -- Always hide Blizzard texts and ensure our custom texts exist
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            
            -- Force reparent icons to icon container (for dynamic PvP icons)
            if frame.DragonUI_IconContainer then
                local pvpIcon = _G[frame:GetName() .. 'PVPIcon']
                local leaderIcon = _G[frame:GetName() .. 'LeaderIcon']
                local statusIcon = _G[frame:GetName() .. 'StatusIcon']
                local guideIcon = _G[frame:GetName() .. 'GuideIcon']
                local roleIcon = _G[frame:GetName() .. 'RoleIcon']
                
                if pvpIcon then
                    pvpIcon:SetParent(frame.DragonUI_IconContainer)
                    pvpIcon:SetDrawLayer('OVERLAY', 1)
                end
                if statusIcon then
                    statusIcon:SetParent(frame.DragonUI_IconContainer)
                    statusIcon:SetDrawLayer('OVERLAY', 1)
                end
                if guideIcon then
                    guideIcon:SetParent(frame.DragonUI_IconContainer)
                    guideIcon:SetDrawLayer('OVERLAY', 1)
                end
                if roleIcon then
                    roleIcon:SetParent(frame.DragonUI_IconContainer)
                    roleIcon:SetDrawLayer('OVERLAY', 1)
                end
            end
            
            -- Update custom health/mana text
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if healthbar then UpdateHealthText(healthbar, false) end
            if manabar then UpdateManaText(manabar, false) end
        end
    end)

    -- Additional hook for party member updates (compatible with 3.3.5a)
    hooksecurefunc("PartyMemberFrame_OnEvent", function(frame, event)
        if frame and frame:GetName() and frame:GetName():match("^PartyMemberFrame%d+$") then
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
                local healthbar = _G[frame:GetName() .. 'HealthBar']
                if healthbar then
                    UpdateHealthText(healthbar, false)
                end
            end
        end
    end)

    -- Main hook for class color (simplified)
    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if statusbar and statusbar:GetName() and statusbar:GetName():match("^PartyMemberFrame%dHealthBar$") then
            -- Drive our overlay from the native bar (read-only); never clip the native texture.
            ApplyHealthBarClipping(statusbar, statusbar:GetValue())
            UpdateHealthText(statusbar, false)
        end
    end)

    -- Hook for mana bar (without touching health)
    hooksecurefunc("UnitFrameManaBar_Update", function(statusbar, unit)
        local id = statusbar and statusbar:GetName()
            and statusbar:GetName():match("^PartyMemberFrame(%d)ManaBar$")
        if id then
            -- Only path that sees power changes: PartyMemberFrame itself registers no power event.
            UpdateManaBarTexture(_G['PartyMemberFrame' .. id])
            -- Drive our overlay from the native bar (read-only); never touch the native texture.
            ApplyManaBarClipping(statusbar, statusbar:GetValue())
            UpdateManaText(statusbar, false)
        end
    end)
    
    -- Handle hover text display with persistent state (portrait hover - shows both texts)
    hooksecurefunc("UnitFrame_OnEnter", function(self)
        if self and self:GetName() and self:GetName():match("^PartyMemberFrame%d+$") then
            local frameIndex = tonumber(self:GetID())
            if frameIndex and hoverStates[frameIndex] then
                hoverStates[frameIndex].portrait = true  -- Mark portrait as hovering
            end
            
            -- Immediately hide Blizzard texts after hover
            HideBlizzardTexts(self)
            
            -- Show both custom texts during portrait hover (even if always show is off)
            local healthbar = _G[self:GetName() .. 'HealthBar']
            local manabar = _G[self:GetName() .. 'ManaBar']
            if healthbar then UpdateHealthText(healthbar, true) end -- forceShow = true
            if manabar then UpdateManaText(manabar, true) end -- forceShow = true
        end
    end)
    
    hooksecurefunc("UnitFrame_OnLeave", function(self)
        if self and self:GetName() and self:GetName():match("^PartyMemberFrame%d+$") then
            local frameIndex = tonumber(self:GetID())
            if frameIndex and hoverStates[frameIndex] then
                hoverStates[frameIndex].portrait = false  -- Clear portrait hover state
            end
            
            -- Ensure Blizzard texts stay hidden after hover ends
            HideBlizzardTexts(self)
            
            -- Return to normal text visibility (respect always show setting)
            local healthbar = _G[self:GetName() .. 'HealthBar']
            local manabar = _G[self:GetName() .. 'ManaBar']
            if healthbar then UpdateHealthText(healthbar, false) end -- forceShow = false
            if manabar then UpdateManaText(manabar, false) end -- forceShow = false
        end
    end)
    
    -- ===============================================================
    -- DISCONNECT VISUAL FIX (mod-playerbots compatibility)
    -- ===============================================================
    -- Hook PartyMemberFrame_UpdateOnlineStatus directly.
    -- This runs AFTER Blizzard has already called UnitFrameHealthBar_Update
    -- (which triggers our SetValue hook that may override gray with class/white
    -- color because DragonUI_Disconnected flag isn't set yet at that point).
    -- By hooking this function, we re-apply disconnect visuals as the LAST step.
    hooksecurefunc("PartyMemberFrame_UpdateOnlineStatus", function(frame)
        if not frame or not frame:GetName() then return end
        if not frame:GetName():match("^PartyMemberFrame%d+$") then return end
        
        local frameIndex = frame:GetID()
        local unit = "party" .. frameIndex
        if not UnitExists(unit) then return end
        
        -- Re-apply disconnect state — this runs after Blizzard AND after our
        -- SetValue/UnitFrameHealthBar_Update hooks have already executed,
        -- ensuring the gray visuals stick.
        UpdateDisconnectedState(frame)

        -- Re-run clip logic directly, not via :SetValue() — that cascade taints Show() calls mid-combat.
        local healthbar = _G[frame:GetName() .. 'HealthBar']
        local manabar = _G[frame:GetName() .. 'ManaBar']
        if healthbar then
            ApplyHealthBarClipping(healthbar, healthbar:GetValue())
        end
        if manabar then
            ApplyManaBarClipping(manabar, manabar:GetValue())
        end
    end)
end

-- ===============================================================
-- MODULE INTERFACE FUNCTIONS
-- ===============================================================

function PartyFrames:UpdateSettings()
    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("party_update_settings", function()
                PartyFrames:UpdateSettings()
            end)
        end
        return
    end

    -- Check initial configuration
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets or not addon.db.profile.widgets.party then
        self:LoadDefaultSettings()
    end

    -- Apply widget position first
    ApplyWidgetPosition()
    
    -- Only apply base styles - ACE3 handles class color
    StylePartyFrames()
    
    -- Reposition buffs
    RepositionBlizzardBuffs()
    
    -- Update anchor size for new orientation
    UpdatePartyAnchorSize()
    
    -- Refresh all texts and power bar textures with new settings
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            
            -- Refresh power bar texture (energy, rage, etc.)
            UpdateManaBarTexture(frame)
            
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            
            if healthbar then UpdateHealthText(healthbar, false) end
            if manabar then UpdateManaText(manabar, false) end
            
            -- Re-apply disconnected state AFTER styling (gray name, hidden texts, etc.)
            -- StylePartyFrames resets name color to yellow, so this must come last
            UpdateDisconnectedState(frame)

            if addon.VisibilityFade then
                local hoverFrames = { frame }
                if frame.DragonUI_HealthHover then table.insert(hoverFrames, frame.DragonUI_HealthHover) end
                if frame.DragonUI_ManaHover then table.insert(hoverFrames, frame.DragonUI_ManaHover) end
                addon.VisibilityFade.Register("party" .. i, frame, {
                    dbTable = function() return addon.UF.GetConfig("party") end,
                    hoverFrames = hoverFrames,
                    clickThrough = true,
                    shouldManage = ShouldPartyFramesBeVisible,
                })
                addon.VisibilityFade.Update("party" .. i)
            end
        end
    end

    -- Single source of truth for Show/Hide decisions.
    RefreshAllPartyFrameVisibility()
end

-- ===============================================================
-- EXPORTS FOR OPTIONS.LUA
-- ===============================================================

function addon:RefreshPartyFrames()
    if PartyFrames and PartyFrames.UpdateSettings then
        PartyFrames:UpdateSettings()
    end
end

-- ===============================================================
-- CENTRALIZED SYSTEM REGISTRATION AND INITIALIZATION
-- ===============================================================

local function InitializePartyFramesForEditor()
    if PartyFrames.initialized then
        return
    end

    -- Create anchor frame
    CreatePartyAnchorFrame()

    -- Always ensure configuration exists
    PartyFrames:LoadDefaultSettings()

    -- Apply initial position
    ApplyWidgetPosition()

    -- Register with centralized system
    if addon and addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "party",
            frame = PartyFrames.anchor,
            configPath = {"widgets", "party"}, -- Add configPath required by core.lua
            showTest = ShowPartyFramesTest,
            hideTest = HidePartyFramesTest,
            hasTarget = ShouldPartyFramesBeVisible -- Use hasTarget instead of shouldShow
        })
    end

    PartyFrames.initialized = true
end

-- ===============================================================
-- INITIALIZATION
-- ===============================================================

-- Initialize everything in correct order
InitializePartyFramesForEditor() -- First: register with centralized system
StylePartyFrames() -- Second: visual properties and positioning
SetupPartyHooks() -- Third: safe hooks only

-- Listener for when the addon is fully loaded
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Apply position after the addon is fully loaded
        if PartyFrames and PartyFrames.UpdateSettings then
            PartyFrames:UpdateSettings()
        end
        RefreshAllPartyFrameVisibility()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local connectionFrame = CreateFrame("Frame")
connectionFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
connectionFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
connectionFrame:SetScript("OnEvent", function(self, event)
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        if frame then
            -- Set the flag FIRST so hooks respect it
            UpdateDisconnectedState(frame)
            -- Re-run clip logic directly, not via :SetValue() — that cascade taints Show() calls mid-combat.
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if healthbar then
                ApplyHealthBarClipping(healthbar, healthbar:GetValue())
            end
            if manabar then
                ApplyManaBarClipping(manabar, manabar:GetValue())
            end
        end
    end
end)

-- ===============================================================
-- DEATH/GHOST RECOVERY SYSTEM
-- ===============================================================
-- After death + spirit release, party frame textures can get stuck invisible
-- because SetValue hooks clip to zero-width and UnitExists may briefly return false.
-- These events force a full texture refresh to recover from that state.

local recoveryFrame = CreateFrame("Frame")
recoveryFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")   -- Party composition changes (join/leave/role swap)
recoveryFrame:RegisterEvent("RAID_ROSTER_UPDATE")
recoveryFrame:RegisterEvent("PLAYER_ENTERING_WORLD")   -- Recovery after reload/zone transitions
recoveryFrame:RegisterEvent("PLAYER_ALIVE")             -- Player resurrects (accept rez or spirit healer)
recoveryFrame:RegisterEvent("PLAYER_UNGHOST")           -- Player returns from ghost form
recoveryFrame:RegisterEvent("UNIT_HEALTH")              -- Any unit health change (catches party member rez too)
recoveryFrame:RegisterEvent("CVAR_UPDATE")              -- React to Blizzard party visibility options changes
recoveryFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        delayFrame:SetScript("OnUpdate", function(delaySelf, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.5 then
                delaySelf:SetScript("OnUpdate", nil)
                -- Skip refresh while editor mode is active (test frames are intentionally shown)
                if addon.EditorMode and addon.EditorMode:IsActive() then
                    return
                end
                if InCombatLockdown() then
                    return
                end
                StylePartyFrames()
                RefreshAllPartyFrameVisibility()
            end
        end)
        return
    end

    -- Roster transitions can change protected visibility, so defer reconciliation in combat.
    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        -- Skip refresh while editor mode is active (test frames are intentionally shown)
        if addon.EditorMode and addon.EditorMode:IsActive() then
            return
        end
        RequestPartyVisibilityRefresh()
    end

    if event == "CVAR_UPDATE" then
        if unit ~= "useCompactPartyFrames" and unit ~= "hidePartyInRaid" then
            return
        end

        if addon.EditorMode and addon.EditorMode:IsActive() then
            return
        end

        RequestPartyVisibilityRefresh()

        return
    end

    -- For UNIT_HEALTH, only process party units
    if event == "UNIT_HEALTH" then
        if not unit or not unit:match("^party%d$") then return end
        local frameIndex = tonumber(unit:match("party(%d)"))
        if frameIndex then
            local frame = _G['PartyMemberFrame' .. frameIndex]
            if frame and UnitExists(unit) then
                -- Skip disconnected frames — their visual state is managed by UpdateDisconnectedState
                if frame.DragonUI_Disconnected then return end
                local healthbar = _G[frame:GetName() .. 'HealthBar']
                local manabar = _G[frame:GetName() .. 'ManaBar']
                if healthbar then
                    ApplyHealthBarClipping(healthbar, healthbar:GetValue())
                    UpdateHealthText(healthbar, false)
                end
                if manabar then
                    ApplyManaBarClipping(manabar, manabar:GetValue())
                    UpdateManaText(manabar, false)
                end
            end
        end
        return
    end
    
    -- For party-wide events, refresh ALL party frames
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G['PartyMemberFrame' .. i]
        local unit = "party" .. i
        if frame and UnitExists(unit) then
            -- Skip disconnected frames — their visual state is managed by UpdateDisconnectedState
            if not frame.DragonUI_Disconnected then
            local healthbar = _G[frame:GetName() .. 'HealthBar']
            local manabar = _G[frame:GetName() .. 'ManaBar']
            if healthbar then
                ApplyHealthBarClipping(healthbar, healthbar:GetValue())
                UpdateHealthText(healthbar, false)
            end
            if manabar then
                ApplyManaBarClipping(manabar, manabar:GetValue())
                UpdateManaText(manabar, false)
            end
            end -- if not DragonUI_Disconnected
        end
    end
end)


-- ===============================================================
-- COMPACT RAID FRAMES HANDSHAKE
-- ===============================================================

-- CompactRaidFrames keeps useCompactPartyFrames in a SavedVariable, so CVAR_UPDATE never fires.
local allyFramesFrame = CreateFrame("Frame")
allyFramesFrame:RegisterEvent("PLAYER_LOGIN")
allyFramesFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if type(_G.RaidOptionsFrame_UpdatePartyFrames) == "function" then
        hooksecurefunc("RaidOptionsFrame_UpdatePartyFrames", RequestPartyVisibilityRefresh)
    end
end)

-- ===============================================================
-- VEHICLE & RELOAD RECOVERY SYSTEM
-- ===============================================================
-- PartyMemberFrame_UpdateArt hook catches all vehicle art transitions.
-- PLAYER_ENTERING_WORLD with delay handles reload while in vehicle.

-- Reset portrait to DragonUI's expected position after Blizzard vehicle transitions
local function ResetPartyPortrait(frame)
    if InCombatLockdown() then return end
    local portrait = _G[frame:GetName() .. "Portrait"]
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", 7, -6)
    end
end

-- Hook PartyMemberFrame_UpdateArt — catches both vehicle enter and exit
if type(PartyMemberFrame_UpdateArt) == "function" then
    hooksecurefunc("PartyMemberFrame_UpdateArt", function(frame)
        if not frame or not frame:GetName() then return end
        if not frame:GetName():match("^PartyMemberFrame%d+$") then return end

        local texture = _G[frame:GetName() .. "Texture"]
        if texture then
            texture:SetTexture()
            texture:Hide()
        end

        local bg = _G[frame:GetName() .. "Background"]
        if bg then
            bg:Hide()
        end

        local frameIndex = frame:GetID()
        local healthbar = _G[frame:GetName() .. "HealthBar"]
        if healthbar then
            -- Refresh our overlay; never re-skin the native bar (that taints it).
            ApplyHealthBarClipping(healthbar, healthbar:GetValue())
        end

        if frame.DragonUI_BorderFrame and frame.DragonUI_BorderFrame.texture then
            frame.DragonUI_BorderFrame.texture:Show()
        end

        UpdateManaBarTexture(frame)
        HideBlizzardTexts(frame)
        CreateCustomTexts(frame)
        UpdateDisconnectedState(frame)
        ResetPartyPortrait(frame)
    end)
end

-- Hook PartyMemberFrame_ToVehicleArt — hides the vehicle texture Blizzard shows
if type(PartyMemberFrame_ToVehicleArt) == "function" then
    hooksecurefunc("PartyMemberFrame_ToVehicleArt", function(frame)
        if not frame or not frame:GetName() then return end
        if not frame:GetName():match("^PartyMemberFrame%d+$") then return end

        -- Hide Blizzard vehicle texture
        local vehicleTex = _G[frame:GetName() .. "VehicleTexture"]
        if vehicleTex then
            vehicleTex:SetTexture()
            vehicleTex:Hide()
        end

        -- Also re-hide the normal texture (Blizzard may have restored it)
        local texture = _G[frame:GetName() .. "Texture"]
        if texture then
            texture:SetTexture()
            texture:Hide()
        end

        local bg = _G[frame:GetName() .. "Background"]
        if bg then
            bg:Hide()
        end

        -- Re-apply DragonUI styling
        local frameIndex = frame:GetID()
        local healthbar = _G[frame:GetName() .. "HealthBar"]
        if healthbar then
            -- Refresh our overlay; never re-skin the native bar (that taints it).
            ApplyHealthBarClipping(healthbar, healthbar:GetValue())
        end

        if frame.DragonUI_BorderFrame and frame.DragonUI_BorderFrame.texture then
            frame.DragonUI_BorderFrame.texture:Show()
        end

        UpdateManaBarTexture(frame)
        HideBlizzardTexts(frame)
        CreateCustomTexts(frame)
        UpdateDisconnectedState(frame)
        ResetPartyPortrait(frame)
    end)
end

-- Hook PartyMemberFrame_ToPlayerArt — re-applies DragonUI styling when exiting vehicle
if type(PartyMemberFrame_ToPlayerArt) == "function" then
    hooksecurefunc("PartyMemberFrame_ToPlayerArt", function(frame)
        if not frame or not frame:GetName() then return end
        if not frame:GetName():match("^PartyMemberFrame%d+$") then return end

        -- Hide vehicle texture (may linger)
        local vehicleTex = _G[frame:GetName() .. "VehicleTexture"]
        if vehicleTex then
            vehicleTex:SetTexture()
            vehicleTex:Hide()
        end

        -- Hide normal Blizzard texture
        local texture = _G[frame:GetName() .. "Texture"]
        if texture then
            texture:SetTexture()
            texture:Hide()
        end

        local bg = _G[frame:GetName() .. "Background"]
        if bg then
            bg:Hide()
        end

        -- Re-apply DragonUI styling
        local frameIndex = frame:GetID()
        local healthbar = _G[frame:GetName() .. "HealthBar"]
        if healthbar then
            -- Refresh our overlay; never re-skin the native bar (that taints it).
            ApplyHealthBarClipping(healthbar, healthbar:GetValue())
        end

        if frame.DragonUI_BorderFrame and frame.DragonUI_BorderFrame.texture then
            frame.DragonUI_BorderFrame.texture:Show()
        end

        UpdateManaBarTexture(frame)
        HideBlizzardTexts(frame)
        CreateCustomTexts(frame)
        UpdateDisconnectedState(frame)
        ResetPartyPortrait(frame)
    end)
end

-- Helper: full party frame refresh (shared by vehicle and reload recovery)
local function RefreshAllPartyFrames()
    StylePartyFrames()
    RepositionBlizzardBuffs()
    for i = 1, MAX_PARTY_MEMBERS do
        local frame = _G["PartyMemberFrame" .. i]
        if frame and UnitExists("party" .. i) then
            HideBlizzardTexts(frame)
            CreateCustomTexts(frame)
            UpdateManaBarTexture(frame)
            UpdateDisconnectedState(frame)
            ResetPartyPortrait(frame)
            local healthbar = _G[frame:GetName() .. "HealthBar"]
            local manabar = _G[frame:GetName() .. "ManaBar"]
            if healthbar then UpdateHealthText(healthbar, false) end
            if manabar then UpdateManaText(manabar, false) end
        end
    end
end

-- Reload recovery: Blizzard re-initializes vehicle state after /reload
local vehicleRecoveryFrame = CreateFrame("Frame")
vehicleRecoveryFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
vehicleRecoveryFrame:SetScript("OnEvent", function(self, event)
    if addon.core and addon.core.ScheduleTimer then
        addon.core:ScheduleTimer(function()
            -- Skip refresh during editor mode (prevents strata/visibility reset)
            if addon.EditorMode and addon.EditorMode:IsActive() then
                return
            end
            if InCombatLockdown() then
                if addon.CombatQueue then
                    addon.CombatQueue:Add("party_vehicle_recovery", RefreshAllPartyFrames)
                end
                return
            end
            RefreshAllPartyFrames()
        end, 0.8)
    end
end)

-- ===============================================================
-- MODULE LOADED CONFIRMATION
-- ===============================================================

