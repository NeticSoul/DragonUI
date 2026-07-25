-- ===============================================================
-- DRAGONUI PET FRAME MODULE
-- ===============================================================
local addon = select(2, ...)
local L = addon.L
local UF = addon.UF
local PetFrameModule = {}
addon.PetFrameModule = PetFrameModule

-- ===============================================================
-- LOCALIZED API REFERENCES
-- ===============================================================
local _G = _G
local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitExists = UnitExists
local UnitPowerType = UnitPowerType
local hooksecurefunc = hooksecurefunc

-- ===============================================================
-- MODULE CONSTANTS (from shared core)
-- ===============================================================
local PET_TEX = UF.TEXTURES.pet
local TEXTURE_PATH = PET_TEX.TEXTURE_PATH
local UNITFRAME_PATH = PET_TEX.UNITFRAME_PATH
local ATLAS_TEXTURE = PET_TEX.ATLAS_TEXTURE
local TOT_BASE = PET_TEX.TOT_BASE
local POWER_TEXTURES = PET_TEX.POWER_TEXTURES
local COMBAT_TEX_COORDS = PET_TEX.COMBAT_TEX_COORDS
local DEFAULT_ATTACH_X = 18
local DEFAULT_ATTACH_Y = -80

-- ===============================================================
-- COMBAT PULSE ANIMATIONS
-- ===============================================================

-- Combat pulse color configuration
local COMBAT_PULSE_SETTINGS = {
    speed = 9,              -- Heartbeat speed
    minIntensity = 0.3,     -- Minimum red intensity (0.4 = dark red)
    maxIntensity = 0.7,     -- Maximum red intensity (1.0 = bright red)
    enabled = true          -- Enable/disable animation
}

local combatPulseTimer = 0
local petFrameUpdateThrottle = 0

-- Forward declaration (defined after vehicle system section)
local UpdatePetTextSystemUnit


-- ===============================================================
-- COMBAT PULSE ANIMATION
-- ===============================================================
local function AnimatePetCombatPulse(elapsed)
    if not COMBAT_PULSE_SETTINGS.enabled then
        return
    end
    
    local texture = _G.PetAttackModeTexture
    if not texture or not texture:IsVisible() then
        return
    end
    
    -- Increment timer
    combatPulseTimer = combatPulseTimer + (elapsed * COMBAT_PULSE_SETTINGS.speed)
    
    -- Calculate red intensity using sine function
    local intensity = COMBAT_PULSE_SETTINGS.minIntensity + 
                     (COMBAT_PULSE_SETTINGS.maxIntensity - COMBAT_PULSE_SETTINGS.minIntensity) * 
                     (math.sin(combatPulseTimer) * 0.5 + 0.5)
    
    -- Pulse vertex color between min/max red intensity
    texture:SetVertexColor(intensity, 0.0, 0.0, 1.0)
end

-- ===============================================================
-- MODULE STATE
-- ===============================================================
local moduleState = {
    frame = {},
    hooks = {},
    textSystem = nil
}

-- ===============================================================
-- UTILITY FUNCTIONS
-- ===============================================================
local function noop() end
-- Persistently hides the vanilla PetFrame texts (health/power)
local function HideBlizzardPetTexts()
    local petTexts = {
        _G.PetFrameHealthBar and _G.PetFrameHealthBar.TextString,
        _G.PetFrameManaBar and _G.PetFrameManaBar.TextString,
        _G.PetFrameHealthBarText,
        _G.PetFrameManaBarText
    }
    for _, t in pairs(petTexts) do
        if t and not t.DragonUIHidden then
            t:SetAlpha(0)
            -- Phase 2: hooksecurefunc instead of direct .Show override to avoid taint
            hooksecurefunc(t, "Show", function(self)
                if not self.DragonUI_ShowGuard then
                    self.DragonUI_ShowGuard = true
                    self:SetAlpha(0)
                    self.DragonUI_ShowGuard = nil
                end
            end)
            t:Hide()
            t.DragonUIHidden = true
        end
    end
end

-- ===============================================================
-- FRAME POSITIONING
-- ===============================================================
local function ApplyFramePositioning()
    local config = addon.db and addon.db.profile.unitframe.pet
    if not config or not PetFrame then return end

    PetFrame:SetScale(config.scale or 1.0)
    PetFrame:ClearAllPoints()

    if config.override and PetFrameModule.anchor then
        -- Detached: follow the free-floating anchor frame (widgets.pet).
        PetFrame:SetPoint("CENTER", PetFrameModule.anchor, "CENTER", 0, 0)
    else
        -- Attached (default): anchored directly to the player frame.
        PetFrame:SetPoint("CENTER", _G.PlayerFrame, "CENTER", config.x or DEFAULT_ATTACH_X, config.y or DEFAULT_ATTACH_Y)
    end
end

-- ===============================================================
-- POWER BAR MANAGEMENT
-- ===============================================================
local function UpdatePowerBarTexture()
    if not UnitExists("pet") or not PetFrameManaBar then return end
    
    local _, powerType = UnitPowerType('pet')
    local texture = POWER_TEXTURES[powerType]
    
    if texture then
        local statusBar = PetFrameManaBar:GetStatusBarTexture()
        statusBar:SetTexture(texture)
        statusBar:SetVertexColor(1, 1, 1, 1)
    end
end

-- ===============================================================
-- COMBAT MODE TEXTURE
-- ===============================================================
local function ConfigureCombatMode()
    local texture = _G.PetAttackModeTexture
    if not texture then return end
    
    texture:SetTexture(ATLAS_TEXTURE)
    texture:SetTexCoord(unpack(COMBAT_TEX_COORDS))
    texture:SetVertexColor(1.0, 0.0, 0.0, 1.0)  -- Initial color
    texture:SetBlendMode("ADD")
    texture:SetAlpha(0.8)  -- Fixed alpha
    texture:SetDrawLayer("OVERLAY", 9)
    texture:ClearAllPoints()
    texture:SetPoint('CENTER', PetFrame, 'CENTER', -7, -1)
    texture:SetSize(114, 47)
    
    --  RESET TIMER
    combatPulseTimer = 0
end

-- ===============================================================
-- OnUpdate FUNCTION FOR THE PET FRAME
-- ===============================================================
local function PetFrame_OnUpdate(self, elapsed)
    AnimatePetCombatPulse(elapsed)

    petFrameUpdateThrottle = petFrameUpdateThrottle + elapsed
    if petFrameUpdateThrottle < 0.1 then
        return
    end

    petFrameUpdateThrottle = 0
    UpdatePetTextSystemUnit()
end

-- ===============================================================
-- THREAT GLOW SYSTEM 
-- ===============================================================
local function ConfigurePetThreatGlow()
    --  The pet frame uses PetFrameFlash for the threat glow
    local threatFlash = _G.PetFrameFlash
    if not threatFlash then return end
    
    -- Apply custom texture and coordinates
    threatFlash:SetTexture(ATLAS_TEXTURE)  
    threatFlash:SetTexCoord(unpack(COMBAT_TEX_COORDS))
   
    
    --  Visual configuration
    threatFlash:SetBlendMode("ADD")
    threatFlash:SetAlpha(0.7)
    threatFlash:SetDrawLayer("OVERLAY", 10)
    
    -- Position relative to pet frame
    threatFlash:ClearAllPoints()
    threatFlash:SetPoint("CENTER", PetFrame, "CENTER", -7, -1)  
    threatFlash:SetSize(114, 47)  
end
-- ===============================================================
-- FRAME SETUP
-- ===============================================================
local function SetupFrameElement(parent, name, layer, texture, point, size)
    local element = parent:CreateTexture(name)
    element:SetDrawLayer(layer[1], layer[2])
    element:SetTexture(texture)
    element:SetPoint(unpack(point))
    if size then element:SetSize(unpack(size)) end
    return element
end

local function SetupStatusBar(bar, point, size, texture)
    bar:ClearAllPoints()
    bar:SetPoint(unpack(point))
    bar:SetSize(unpack(size))
    if texture then
        bar:GetStatusBarTexture():SetTexture(texture)
        bar:SetStatusBarColor(1, 1, 1, 1)
        -- Phase 2.5: hooksecurefunc instead of direct override to avoid taint
        if not bar.DragonUI_ColorHooked then
            hooksecurefunc(bar, "SetStatusBarColor", function(self)
                local tex = self:GetStatusBarTexture()
                if tex then
                    tex:SetVertexColor(1, 1, 1, 1)
                end
            end)
            bar.DragonUI_ColorHooked = true
        end
    end
end

-- ===============================================================
-- VEHICLE SYSTEM INTEGRATION FOR PET FRAME
-- ===============================================================

-- Function to update PetFrame textSystem unit based on vehicle state
UpdatePetTextSystemUnit = function()
    if not moduleState.textSystem then
        return
    end
    
    local hasVehicleUI = UnitHasVehicleUI("player")
    -- CORRECT LOGIC: When in a vehicle, PetFrame should show the PLAYER as "pet"
    local targetUnit = hasVehicleUI and "player" or "pet"
    
    -- Update both the public unit field and internal reference
    moduleState.textSystem.unit = targetUnit
    if moduleState.textSystem._unitRef then
        moduleState.textSystem._unitRef.unit = targetUnit
    end
    
    -- Force immediate update
    if moduleState.textSystem.update then
        moduleState.textSystem.update()
    end
end

-- ===============================================================
-- MAIN FRAME REPLACEMENT
-- ===============================================================
local function ReplaceBlizzardPetFrame()
    local petFrame = PetFrame
    if not petFrame then return end

    if not moduleState.hooks.onUpdate then
        -- Phase 2: HookScript instead of SetScript to avoid taint on Blizzard PetFrame
        petFrame:HookScript("OnUpdate", PetFrame_OnUpdate)
        moduleState.hooks.onUpdate = true
        
    end
    
    -- Phase 2: Combat protection for secure frame positioning
    if InCombatLockdown() then
        if addon and addon.CombatQueue then
            addon.CombatQueue:Add("petbar_position", ApplyFramePositioning)
        end
    else
        ApplyFramePositioning()
    end
    
    -- Hide original Blizzard texture
    PetFrameTexture:SetTexture('')
    PetFrameTexture:Hide()
    
    -- Hide original text elements to avoid conflicts
    HideBlizzardPetTexts()
    
    -- Setup portrait
    local portrait = PetPortrait
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetPoint("LEFT", 6, 0)
        portrait:SetSize(34, 34)
        portrait:SetDrawLayer('BACKGROUND')
    end
    
    -- Create DragonUI elements if needed
    if not moduleState.frame.background then
        moduleState.frame.background = SetupFrameElement(
            petFrame,
            'DragonUIPetFrameBackground',
            {'BACKGROUND', 1},
            TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND',
            {'LEFT', portrait, 'CENTER', -24, -9}
        )
    end
    
    if not moduleState.frame.border then
        moduleState.frame.border = SetupFrameElement(
            PetFrameHealthBar,
            'DragonUIPetFrameBorder',
            {'OVERLAY', 6},
            TEXTURE_PATH .. TOT_BASE .. 'BORDER',
            {'LEFT', portrait, 'CENTER', -24, -9}
        )
    end
    
    -- Setup health bar
    SetupStatusBar(
        PetFrameHealthBar,
        {'LEFT', portrait, 'RIGHT', 2, 1},
        {70.5, 10},
        UNITFRAME_PATH .. TOT_BASE .. 'Bar-Health'
    )

    -- TexCoord clipping for health bar (prevents baked texture squish)
    if not PetFrameHealthBar.DragonUI_TexCoordHooked then
        hooksecurefunc(PetFrameHealthBar, "SetValue", function(self)
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            local _, max = self:GetMinMaxValues()
            local cur = self:GetValue()
            if max > 0 and cur then
                texture:SetTexCoord(0, cur / max, 0, 1)
            end
        end)
        PetFrameHealthBar.DragonUI_TexCoordHooked = true
    end
    
    -- Setup mana bar
    SetupStatusBar(
        PetFrameManaBar,
        {'LEFT', portrait, 'RIGHT', -1, -9},
        {74, 7.5}
    )
    UpdatePowerBarTexture()

    -- TexCoord clipping for mana bar (prevents baked texture squish/inversion)
    if not PetFrameManaBar.DragonUI_TexCoordHooked then
        hooksecurefunc(PetFrameManaBar, "SetValue", function(self)
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            -- Re-apply power texture in case Blizzard reset it
            UpdatePowerBarTexture()
            local _, max = self:GetMinMaxValues()
            local cur = self:GetValue()
            if max > 0 and cur then
                texture:SetTexCoord(0, cur / max, 0, 1)
            end
        end)
        PetFrameManaBar.DragonUI_TexCoordHooked = true
    end
    
    -- Configure combat mode
    ConfigureCombatMode()
    if not moduleState.hooks.combatMode then
        hooksecurefunc(_G.PetAttackModeTexture, "Show", function(self)
            ConfigureCombatMode()
        end)
        
        --  MODIFY THE SetVertexColor HOOK TO NOT INTERFERE
        hooksecurefunc(_G.PetAttackModeTexture, "SetVertexColor", function(self, r, g, b, a)
            -- Only intervene if not in our pulse color range
            if not COMBAT_PULSE_SETTINGS.enabled then
                if r ~= 1.0 or g ~= 0.0 or b ~= 0.0 then
                    self:SetVertexColor(1.0, 0.0, 0.0, 1.0)
                end
            end
            -- If the pulse is active, let the animation control the color
        end)
        
        moduleState.hooks.combatMode = true
    end

    -- Configure custom threat glow
    if not moduleState.hooks.threatGlow then
        ConfigurePetThreatGlow()
        
        --  HOOK to maintain configuration
        hooksecurefunc(_G.PetFrameFlash, "Show", ConfigurePetThreatGlow)
        
        moduleState.hooks.threatGlow = true
    end
    
    -- Setup pet name positioning (single-line, no word wrap)
    if PetName then
        PetName:ClearAllPoints()
        PetName:SetPoint("CENTER", petFrame, "CENTER", 10, 13)
        PetName:SetJustifyH("LEFT")
        PetName:SetWidth(65)
        PetName:SetWordWrap(false)
        PetName:SetNonSpaceWrap(false)
        PetName:SetDrawLayer("OVERLAY")
    end
    
    -- Position happiness icon
    local happiness = _G[petFrame:GetName() .. 'Happiness']
    if happiness then
        happiness:ClearAllPoints()
        happiness:SetPoint("LEFT", petFrame, "RIGHT", -10, -5)
    end

    -- ===============================================================
    -- INTEGRATE TEXT SYSTEM
    -- ===============================================================
    if addon.TextSystem then
        
        
        -- Setup the advanced text system for pet frame with dynamic unit
        local hasVehicleUI = UnitHasVehicleUI("player")
        local initialUnit = hasVehicleUI and "player" or "pet"
        
        moduleState.textSystem = addon.TextSystem.SetupFrameTextSystem(
            "pet",                 -- frameType
            initialUnit,           -- unit (dynamic based on vehicle state)
            petFrame,              -- parentFrame
            PetFrameHealthBar,     -- healthBar
            PetFrameManaBar,       -- manaBar
            "PetFrame"             -- prefix
        )
        
        -- Ensure we have the correct unit after setup
        UpdatePetTextSystemUnit()
        
    else
        
    end
end


-- ===============================================================
-- UPDATE HANDLER
-- ===============================================================
local function OnPetFrameUpdate()
    -- Refresh textures
    if moduleState.frame.background then
        moduleState.frame.background:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BACKGROUND')
    end
    if moduleState.frame.border then
        moduleState.frame.border:SetTexture(TEXTURE_PATH .. TOT_BASE .. 'BORDER')
    end
    
    UpdatePowerBarTexture()
    ConfigureCombatMode()
    ConfigurePetThreatGlow()
    
    -- Update text system unit for vehicle support
    UpdatePetTextSystemUnit()
    
    -- Update text system if available
    if moduleState.textSystem and moduleState.textSystem.update then
        moduleState.textSystem.update()
    end

    -- Ensure vanilla texts remain hidden
    HideBlizzardPetTexts()
end

-- ===============================================================
-- MODULE INTERFACE
-- ===============================================================
function PetFrameModule:OnEnable()
    if not moduleState.hooks.petUpdate then
        hooksecurefunc('PetFrame_Update', OnPetFrameUpdate)
        moduleState.hooks.petUpdate = true
    end
    -- Hide vanilla texts when enabling the module
    HideBlizzardPetTexts()
end

function PetFrameModule:OnDisable()
    if moduleState.textSystem and moduleState.textSystem.clear then
        moduleState.textSystem.clear()
    end
end

function PetFrameModule:PLAYER_ENTERING_WORLD()
    ReplaceBlizzardPetFrame()
    -- Defensive redundancy in case Blizzard re-activates the texts
    HideBlizzardPetTexts()
end

-- ===============================================================
-- REFRESH FUNCTION FOR OPTIONS
-- ===============================================================
function addon.RefreshPetFrame()
    PetFrameModule:UpdateWidgets()
    if UnitExists("pet") then
        OnPetFrameUpdate()
    end

    if addon.VisibilityFade and _G.PetFrame then
        local petFrame = _G.PetFrame
        local hoverFrames = { petFrame }
        addon.VisibilityFade.Register("pet", petFrame, {
            dbTable = function() return addon.UF.GetConfig("pet") end,
            hoverFrames = hoverFrames,
            clickThrough = true,
        })
        addon.VisibilityFade.Update("pet")
    end
end



-- ===============================================================
-- EVENT HANDLING
-- ===============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Vehicle events for proper unit switching in PetFrame
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        PetFrameModule:OnEnable()
    elseif event == "PLAYER_ENTERING_WORLD" then
        PetFrameModule:PLAYER_ENTERING_WORLD()
        -- Update unit on world enter (handles reloads)
        UpdatePetTextSystemUnit()
    elseif event == "UNIT_ENTERED_VEHICLE" and arg1 == "player" then
        -- When player enters vehicle, PetFrame should show player as "pet"
        UpdatePetTextSystemUnit()
        OnPetFrameUpdate()
    elseif event == "UNIT_EXITED_VEHICLE" and arg1 == "player" then
        -- When player exits vehicle, PetFrame should show actual pet again
        UpdatePetTextSystemUnit()
        OnPetFrameUpdate()
    end
end)

-- ===============================================================
-- CENTRALIZED SYSTEM INTEGRATION
-- ===============================================================

-- Variables for the centralized system
PetFrameModule.anchor = nil
PetFrameModule.initialized = false

-- Create auxiliary frame for anchoring (like party.lua and castbar.lua)
local function CreatePetAnchorFrame()
    if PetFrameModule.anchor then
        return PetFrameModule.anchor
    end

    --  USE CENTRALIZED FUNCTION FROM CORE.LUA
    PetFrameModule.anchor = addon.CreateUIFrame(130, 44, "PetFrame")
    
    return PetFrameModule.anchor
end

-- Detached mode: position the anchor frame from its saved UIParent-relative offset.
local function ApplyWidgetPosition()
    if not PetFrameModule.anchor then return end
    if not addon.db or not addon.db.profile or not addon.db.profile.widgets then return end

    local widgetConfig = addon.db.profile.widgets.pet
    PetFrameModule.anchor:ClearAllPoints()
    if widgetConfig and widgetConfig.posX and widgetConfig.posY then
        local anchor = widgetConfig.anchor or "TOPRIGHT"
        PetFrameModule.anchor:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
    else
        PetFrameModule.anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -150)
    end
end

-- Keep the draggable overlay tracking the real frame while attached.
local function SyncPetOverlayToRealFrame()
    if not PetFrameModule.anchor then return end
    local config = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.pet
    PetFrameModule.anchor:ClearAllPoints()
    if config and config.override then
        ApplyWidgetPosition()
    elseif not (PetFrame and pcall(PetFrameModule.anchor.SetPoint, PetFrameModule.anchor, "CENTER", PetFrame, "CENTER", 0, 0)) then
        ApplyWidgetPosition()
    end
end

-- Save the anchor frame's current screen position (mirrors ToT/FoT).
local function PersistDetachedPetPosition()
    if not PetFrameModule.anchor then return false end
    if not (addon.db and addon.db.profile) then return false end

    local cx, cy = PetFrameModule.anchor:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then return false end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets.pet = addon.db.profile.widgets.pet or {}
    addon.db.profile.widgets.pet.anchor = "CENTER"
    addon.db.profile.widgets.pet.posX = math.floor((cx - ux) + 0.5)
    addon.db.profile.widgets.pet.posY = math.floor((cy - uy) + 0.5)
    return true
end

-- Centralized system interface
function PetFrameModule:LoadDefaultSettings()
    -- Ensure widgets config table exists
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end
    
    if not addon.db.profile.widgets.pet then
        addon.db.profile.widgets.pet = {
            anchor = "TOPRIGHT",
            posX = -50,
            posY = -150
        }
        
    end
    
    -- Ensure unitframe.pet config table exists
    if not addon.db.profile.unitframe then
        addon.db.profile.unitframe = {}
    end
    
    if not addon.db.profile.unitframe.pet then
        -- Pet configuration should already exist in database.lua
        
    end
end

function PetFrameModule:UpdateWidgets()
    ApplyWidgetPosition()
    if InCombatLockdown() then
        if addon and addon.CombatQueue then
            addon.CombatQueue:Add("petframe_widgets", function() PetFrameModule:UpdateWidgets() end)
        end
        return
    end
    ApplyFramePositioning()
    SyncPetOverlayToRealFrame()
end

-- Always visible in editor mode, not filtered by class
local function ShouldPetFrameBeVisible()
    -- RetailUI siempre permite editar el PET frame independientemente de la clase
    return true
end

-- Test display functions for editor mode
local function ShowPetFrameTest()
    -- Show the PET frame even if there is no pet
    if PetFrame then
        PetFrame:Show()
        
        -- Simulate having a pet for the test
        if PetName then
            PetName:SetText(L["Test Pet"])
            PetName:Show()
        end
        
        if PetPortrait then
            PetPortrait:Show()
        end
        
        if PetFrameHealthBar then
            PetFrameHealthBar:SetMinMaxValues(0, 100)
            PetFrameHealthBar:SetValue(75)
            PetFrameHealthBar:Show()
        end
        
        if PetFrameManaBar then
            PetFrameManaBar:SetMinMaxValues(0, 100)
            PetFrameManaBar:SetValue(50)
            PetFrameManaBar:Show()
        end

        SyncPetOverlayToRealFrame()
    end
end

local function HidePetFrameTest()
    -- Restore the normal state of the PET frame
    if PetFrame then
        if UnitExists("pet") then
            -- If there is a real pet, restore real values
            if PetName then
                PetName:SetText(UnitName("pet") or "")
            end
            
            -- Force update bars with real values
            if PetFrameHealthBar then
                PetFrameHealthBar:SetMinMaxValues(0, UnitHealthMax("pet"))
                PetFrameHealthBar:SetValue(UnitHealth("pet"))
            end
            
            if PetFrameManaBar then
                PetFrameManaBar:SetMinMaxValues(0, UnitPowerMax("pet"))
                PetFrameManaBar:SetValue(UnitPower("pet"))
            end
        else
            -- If there is no real pet, hide everything
            PetFrame:Hide()
            
            -- Clear test values
            if PetName then
                PetName:SetText("")
            end
        end
    end
end

-- Detach and persist when the user drags/nudges/types a new position (mirrors ToT/FoT).
local function DetachPetFrame()
    local config = addon.db and addon.db.profile and addon.db.profile.unitframe and addon.db.profile.unitframe.pet
    if config then
        config.override = true
    end
    PersistDetachedPetPosition()
    PetFrameModule:UpdateWidgets()
end

-- Initialize pet frame for the editor system
local function InitializePetFrameForEditor()
    -- Create the anchor frame
    CreatePetAnchorFrame()

    -- Detach immediately on drag stop, like ToT/FoT's small_frame.lua.
    PetFrameModule.anchor:HookScript("OnDragStop", function(self)
        self.DragonUI_WasDragged = true
        DetachPetFrame()
    end)

    -- Register with editor system (full interface like party.lua and castbar.lua)
    addon:RegisterEditableFrame({
        name = "PetFrame",
        frame = PetFrameModule.anchor,
        configPath = {"widgets", "pet"},
        hasTarget = ShouldPetFrameBeVisible,
        showTest = ShowPetFrameTest,
        hideTest = HidePetFrameTest,
        onNudge = DetachPetFrame,
        onHide = function()
            -- Nudge/typed-coordinate edits also count as a manual detach.
            if PetFrameModule.anchor.DragonUI_WasDragged or PetFrameModule.anchor.DragonUI_WasAdjustedByEditor then
                DetachPetFrame()
                PetFrameModule.anchor.DragonUI_WasDragged = nil
                PetFrameModule.anchor.DragonUI_WasAdjustedByEditor = nil
            else
                PetFrameModule:UpdateWidgets()
            end
        end,
        LoadDefaultSettings = function() PetFrameModule:LoadDefaultSettings() end,
        UpdateWidgets = function() PetFrameModule:UpdateWidgets() end
    })

    PetFrameModule.initialized = true

end

-- Initialization
InitializePetFrameForEditor()

-- Apply widget positions once addon is fully loaded
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("ADDON_LOADED")
readyFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        -- Apply widget position when the addon is ready
        if PetFrameModule.UpdateWidgets then
            PetFrameModule:UpdateWidgets()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

