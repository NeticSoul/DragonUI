--[[
  DragonUI - Boss Frames (boss.lua)

  Reskins Blizzard's native Boss1-4TargetFrame with Dragonflight visual styling.
  Follows the RetailUI pattern: retexture existing Blizzard frames instead of
  creating new ones from scratch.

  Architecture:
  - Config: addon.db.profile.unitframe.boss
  - Atlas: texture:set_atlas(name, true) (from utils/atlas.lua)
  - Editor: RegisterEditableFrame for drag positioning
  - Visibility: RegisterUnitWatch(bossFrame) per boss frame — required because
    INSTANCE_ENCOUNTER_ENGAGE_UNIT does NOT exist in 3.3.5a (MCP Ch.25).
    RegisterUnitWatch auto-shows/hides frames based on UnitExists("bossN").
]]

local _, addon = ...
local L = addon.L

local UF = addon.UF
if not UF then return end

-- ============================================================================
-- CONFIG ACCESS
-- ============================================================================

local function GetConfig()
    return UF.GetConfig("boss")
end

local function IsEnabled()
    return UF.IsEnabled("boss")
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local NUM_BOSS_FRAMES = 4

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local BossModule = UF.CreateModule("boss")
BossModule.wrapperFrames = {} -- editor wrapper frames indexed 1-4
BossModule.secureAnchors = {}
BossModule.configured = false

if addon.RegisterModule then
    addon:RegisterModule("boss", BossModule,
        L["Boss Frames"],
        L["Dragonflight-styled boss target frames"])
end

-- ============================================================================
-- TEXTURE & LAYOUT CONSTANTS
-- ============================================================================

local TEXTURES = UF.TEXTURES.targetStyle
local BOSS_COORDS = UF.BOSS_COORDS.targetStyle
local PORTRAIT_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- Atlas border name by classification (boss frames always >= elite)
local CLASSIFICATION_ATLAS = {
    worldboss = "TargetFrame-TextureFrame-Elite",
    elite     = "TargetFrame-TextureFrame-Elite",
    rareelite = "TargetFrame-TextureFrame-RareElite",
    rare      = "TargetFrame-TextureFrame-Rare",
}

local function ApplyEliteDecoration(bossFrame, portrait)
    local elite = bossFrame.DragonUI_Elite
    if not elite or not portrait then return end
    local unit = bossFrame.unit or bossFrame:GetAttribute("unit")
    local classification
    if unit and UnitExists(unit) then
        classification = UnitClassification(unit)
    end
    local coords
    if classification == "worldboss" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "elite" then
        coords = BOSS_COORDS.elite
    elseif classification == "rareelite" then
        coords = BOSS_COORDS.rareelite
    elseif classification == "rare" then
        coords = BOSS_COORDS.rare
    else
        coords = BOSS_COORDS.rareelite -- boss frames default to the winged dragon
    end
    if not coords then return end
    elite:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    elite:SetSize(coords[5], coords[6])
    elite:ClearAllPoints()
    elite:SetPoint("CENTER", portrait, "CENTER", coords[7], coords[8])
    elite:SetDrawLayer("OVERLAY", 6)
    elite:Show()
end

-- Blizzard can re-anchor TextureFrame back to its default screen position; lock it.
local function HookTextureFrameSetPoint(textureFrame, bossFrame)
    if textureFrame.__DragonUI_SetPointHooked then return end
    hooksecurefunc(textureFrame, "SetPoint", function(self, ...)
        if self._DragonUI_SettingPoint or InCombatLockdown() then return end
        self._DragonUI_SettingPoint = true
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, 0)
        self._DragonUI_SettingPoint = nil
    end)
    textureFrame.__DragonUI_SetPointHooked = true
end

-- Re-anchor border (called from hooks after Blizzard resets)
local function UpdateBossFrameBorder(bossFrame)
    if not bossFrame.DragonUI_FrameBorder or not bossFrame.DragonUI_FrameBG then return end
    bossFrame.DragonUI_FrameBG:ClearAllPoints()
    bossFrame.DragonUI_FrameBG:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, -8)
    -- Border is on its own overlay frame — just reanchor the frame
    local borderFrame = bossFrame.DragonUI_BorderFrame
    if borderFrame then
        borderFrame:ClearAllPoints()
        borderFrame:SetAllPoints(bossFrame)
        borderFrame:SetFrameLevel(bossFrame:GetFrameLevel() + 2)
    end
    -- Blizzard TextureFrame above border AND above decoFrame (elite dragon).
    -- borderFrame = N+2, decoFrame (child) = N+3, TextureFrame must be N+4.
    local frameName = bossFrame:GetName()
    if frameName then
        local textureFrame = _G[frameName .. "TextureFrame"]
        if textureFrame and borderFrame then
            textureFrame._DragonUI_SettingPoint = true
            textureFrame:ClearAllPoints()
            textureFrame:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, 0)
            textureFrame._DragonUI_SettingPoint = nil
            textureFrame:SetFrameLevel(borderFrame:GetFrameLevel() + 2)
            HookTextureFrameSetPoint(textureFrame, bossFrame)
        end
    end
    -- Decoration frame (child of borderFrame) always renders above border
    local decoFrame = bossFrame.DragonUI_DecoFrame
    if decoFrame then
        decoFrame:ClearAllPoints()
        decoFrame:SetAllPoints(bossFrame)
    end
    bossFrame.DragonUI_FrameBorder:ClearAllPoints()
    bossFrame.DragonUI_FrameBorder:SetPoint(
        "TOPLEFT", bossFrame.DragonUI_FrameBG, "TOPLEFT", 0, 0)
end

-- Re-apply custom flash styling on our mirror texture (on BorderFrame)
local function EnforceFlashStyle(flashTex, parentFrame)
    if not flashTex then return end
    -- Hide the Blizzard flash — we use our own mirror
    flashTex:SetAlpha(0)

    local bossFrame = parentFrame

    -- Create mirror flash on bossFrame itself (once).
    -- bossFrame is level N, borderFrame is level N+2, so the flash
    -- naturally renders BELOW the border — correct "glow behind border" look.
    if not bossFrame.DragonUI_Flash then
        local mirror = bossFrame:CreateTexture(nil, "OVERLAY")
        mirror:SetDrawLayer("OVERLAY", 7)
        bossFrame.DragonUI_Flash = mirror
        -- Sync: when Blizzard shows/hides the original flash, mirror it
        hooksecurefunc(flashTex, "Show", function() mirror:Show() end)
        hooksecurefunc(flashTex, "Hide", function() mirror:Hide() end)
        mirror:Hide()
    end

    local mirror = bossFrame.DragonUI_Flash
    mirror:SetTexture(TEXTURES.THREAT)
    mirror:SetTexCoord(0, 376/512, 0, 134/256)
    mirror:SetVertexColor(1, 0, 0, 1)
    mirror:SetBlendMode("ADD")
    mirror:SetAlpha(0.7)
    mirror:SetDrawLayer("OVERLAY", 7)
    mirror:ClearAllPoints()
    mirror:SetPoint("BOTTOMLEFT", bossFrame, "BOTTOMLEFT", 3, 25)
    mirror:SetSize(188, 67)
    -- Match current visibility
    if flashTex:IsShown() then mirror:Show() else mirror:Hide() end
end

-- ============================================================================
-- POSITION ENFORCEMENT
-- ============================================================================
-- Hooks SetPoint on each boss frame to block ALL Blizzard repositioning.
-- Without this, Blizzard re-positions boss frames through multiple codepaths
-- (TargetFrame_Update, XML anchors, UIParent_ManageFramePositions) that we
-- can't catch with just TargetFrame_Update hooks.

local function CreateSecureBossAnchor(wrapper, bossFrame, bossIndex)
    local anchor = CreateFrame("Frame", nil, wrapper, "SecureHandlerStateTemplate")
    anchor:SetAllPoints(wrapper)
    anchor:SetFrameRef("bossFrame", bossFrame)
    anchor:SetAttribute("unit", "boss" .. bossIndex)
    anchor:SetAttribute("_onstate-unitexists", [[
        if newstate then
            local bossFrame = self:GetFrameRef("bossFrame")
            if bossFrame then
                bossFrame:ClearAllPoints()
                bossFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            end
            -- Clear the cache so later Blizzard reanchors are repaired on the next unit-watch pass.
            self:SetAttribute("state-unitexists", nil)
        end
    ]])
    RegisterUnitWatch(anchor, true)
    BossModule.secureAnchors[bossIndex] = anchor
    return anchor
end

local function HookBossFrameSetPoint(bossFrame, bossIndex)
    if bossFrame.__DragonUI_SetPointHooked then return end
    hooksecurefunc(bossFrame, "SetPoint", function(self, ...)
        if self._DragonUI_SettingPoint or InCombatLockdown() then return end
        local anchor = BossModule.secureAnchors[bossIndex] or BossModule.wrapperFrames[bossIndex]
        if not anchor then return end
        self._DragonUI_SettingPoint = true
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        self._DragonUI_SettingPoint = nil
    end)
    bossFrame.__DragonUI_SetPointHooked = true
end

-- ============================================================================
-- RESKIN BLIZZARD BOSS FRAME
-- ============================================================================

local function ReskinBossFrame(wrapperFrame, bossFrame, bossIndex)
    -- Anchor the Blizzard boss frame to our wrapper
    local positionAnchor = BossModule.secureAnchors[bossIndex] or wrapperFrame
    bossFrame._DragonUI_SettingPoint = true
    bossFrame:ClearAllPoints()
    bossFrame:SetPoint("TOPLEFT", positionAnchor, "TOPLEFT", 0, 0)
    bossFrame:SetHitRectInsets(0, 0, 0, 0)
    bossFrame._DragonUI_SettingPoint = nil

    local frameName = bossFrame:GetName()

    -- Hide ALL Blizzard default textures
    local blizzBorder = _G[frameName .. "TextureFrameTexture"]
    if blizzBorder then blizzBorder:SetAlpha(0) end
    local blizzBG = _G[frameName .. "Background"]
    if blizzBG then blizzBG:SetAlpha(0) end

    -- ---- Frame background (dark fill behind bars — same as target_style) ----
    if not bossFrame.DragonUI_FrameBG then
        bossFrame.DragonUI_FrameBG = bossFrame:CreateTexture(
            nil, "BACKGROUND")
        bossFrame.DragonUI_FrameBG:SetDrawLayer("BACKGROUND", -7)
        bossFrame.DragonUI_FrameBG:SetTexture(TEXTURES.BACKGROUND)
        bossFrame.DragonUI_FrameBG:ClearAllPoints()
        bossFrame.DragonUI_FrameBG:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, -8)
    end

    -- ---- Frame border (on its own overlay frame above bars) ----
    if not bossFrame.DragonUI_BorderFrame then
        local borderFrame = CreateFrame("Frame", nil, bossFrame)
        borderFrame:SetAllPoints(bossFrame)
        borderFrame:SetFrameLevel(bossFrame:GetFrameLevel() + 2)
        borderFrame:EnableMouse(false)
        bossFrame.DragonUI_BorderFrame = borderFrame

        bossFrame.DragonUI_FrameBorder = borderFrame:CreateTexture(
            nil, "OVERLAY")
        bossFrame.DragonUI_FrameBorder:SetDrawLayer("OVERLAY", 5)
        bossFrame.DragonUI_FrameBorder:SetTexture(TEXTURES.BORDER)
        bossFrame.DragonUI_FrameBorder:ClearAllPoints()
        bossFrame.DragonUI_FrameBorder:SetPoint(
            "TOPLEFT", bossFrame.DragonUI_FrameBG, "TOPLEFT", 0, 0)
    end

    -- ---- Raise Blizzard TextureFrame above border AND decoFrame ----
    -- TextureFrame holds name, level, skull, raid target, pvp icon, etc.
    -- borderFrame = N+2, decoFrame (child) = N+3, TextureFrame must be N+4.
    local textureFrame = _G[frameName .. "TextureFrame"]
    if textureFrame then
        textureFrame:SetFrameLevel(bossFrame.DragonUI_BorderFrame:GetFrameLevel() + 2)
    end

    -- ---- Decoration frame (child of borderFrame — always renders above border) ----
    -- In 3.3.5a, child frames render above parent textures regardless of
    -- draw layer, solving the random elite/border layering race condition.
    -- This is the same pattern target_style.lua uses with Blizzard's TextureFrame.
    if not bossFrame.DragonUI_DecoFrame then
        local decoFrame = CreateFrame("Frame", nil, bossFrame.DragonUI_BorderFrame)
        decoFrame:SetAllPoints(bossFrame)
        decoFrame:EnableMouse(false)
        bossFrame.DragonUI_DecoFrame = decoFrame
    end

    -- ---- Portrait (same anchor as target: TOPRIGHT) ----
    local portrait = _G[frameName .. "Portrait"]
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetSize(56, 56)
        portrait:SetPoint("TOPRIGHT", bossFrame, "TOPRIGHT", -47, -15)
        portrait:SetDrawLayer("ARTWORK", 1)
        local unit = bossFrame.unit or bossFrame:GetAttribute("unit")
        if unit and UnitExists(unit) then
            SetPortraitTexture(portrait, unit)
        end
    end

    -- ---- Portrait mask (circular dark background) ----
    if portrait and not bossFrame.DragonUI_PortraitMask then
        bossFrame.DragonUI_PortraitMask = bossFrame:CreateTexture(
            nil, "BACKGROUND")
        bossFrame.DragonUI_PortraitMask:SetDrawLayer("BACKGROUND", 1)
        bossFrame.DragonUI_PortraitMask:SetTexture(PORTRAIT_MASK)
        bossFrame.DragonUI_PortraitMask:SetVertexColor(0, 0, 0, 1)
        bossFrame.DragonUI_PortraitMask:SetPoint(
            "CENTER", portrait, "CENTER", 0, 0)
        bossFrame.DragonUI_PortraitMask:SetSize(56, 56)
    end

    -- ---- Elite decoration (dragon) — on decoFrame (child of borderFrame) ----
    local decoFrame = bossFrame.DragonUI_DecoFrame
    if portrait and not bossFrame.DragonUI_Elite and decoFrame then
        bossFrame.DragonUI_Elite = decoFrame:CreateTexture(
            nil, "OVERLAY")
        bossFrame.DragonUI_Elite:SetDrawLayer("OVERLAY", 6)
        bossFrame.DragonUI_Elite:SetTexture(TEXTURES.BOSS)
        bossFrame.DragonUI_Elite:Hide()
    end
    ApplyEliteDecoration(bossFrame, portrait)

    -- ---- Health bar (anchored to portrait like target_style) ----
    local healthBar = _G[frameName .. "HealthBar"]
    if healthBar then
        healthBar:ClearAllPoints()
        healthBar:SetSize(125, 20)
        healthBar:SetPoint("RIGHT", portrait, "LEFT", -1, 0)
        healthBar:SetFrameLevel(bossFrame:GetFrameLevel() + 1)

        local statusBarTex = healthBar:GetStatusBarTexture()
        if statusBarTex then
            statusBarTex:SetAllPoints(healthBar)
            statusBarTex:SetTexture(TEXTURES.BAR_PREFIX .. "Health")
            statusBarTex:SetDrawLayer("ARTWORK", 1)
            statusBarTex:SetVertexColor(1, 1, 1, 1)
        end

        if not healthBar.DragonUI_ColorLocked then
            hooksecurefunc(healthBar, "SetStatusBarColor", function(self)
                local tex = self:GetStatusBarTexture()
                if tex then tex:SetVertexColor(1, 1, 1, 1) end
            end)
            healthBar.DragonUI_ColorLocked = true
        end

        -- Dynamic texcoord cropping (same as target_style)
        if not healthBar.DragonUI_TexCoordHooked then
            hooksecurefunc(healthBar, "SetValue", function(self)
                local texture = self:GetStatusBarTexture()
                if not texture then return end
                local _, max = self:GetMinMaxValues()
                local cur = self:GetValue()
                if max > 0 and cur then
                    texture:SetTexCoord(0, cur / max, 0, 1)
                end
            end)
            healthBar.DragonUI_TexCoordHooked = true
        end
    end

    -- ---- Mana bar (anchored to portrait like target_style) ----
    local manaBar = _G[frameName .. "ManaBar"]
    if manaBar then
        manaBar:ClearAllPoints()
        manaBar:SetSize(132, 9)
        manaBar:SetPoint("RIGHT", portrait, "LEFT", 6.5, -16.5)
        manaBar:SetFrameLevel(bossFrame:GetFrameLevel() + 1)

        local statusBarTex = manaBar:GetStatusBarTexture()
        if statusBarTex then
            statusBarTex:SetAllPoints(manaBar)
            statusBarTex:SetTexture(TEXTURES.BAR_PREFIX .. "Mana")
            statusBarTex:SetDrawLayer("ARTWORK", 1)
            statusBarTex:SetVertexColor(1, 1, 1, 1)
        end

        if not manaBar.DragonUI_ColorLocked then
            hooksecurefunc(manaBar, "SetStatusBarColor", function(self)
                local tex = self:GetStatusBarTexture()
                if tex then tex:SetVertexColor(1, 1, 1, 1) end
            end)
            manaBar:SetStatusBarColor(1, 1, 1, 1)
            manaBar.DragonUI_ColorLocked = true
        end

        -- Dynamic texcoord cropping (same as target_style)
        if not manaBar.DragonUI_TexCoordHooked then
            hooksecurefunc(manaBar, "SetValue", function(self)
                local texture = self:GetStatusBarTexture()
                if not texture then return end
                texture:SetVertexColor(1, 1, 1, 1)
                local _, max = self:GetMinMaxValues()
                local cur = self:GetValue()
                if max > 0 and cur then
                    texture:SetTexCoord(0, cur / max, 0, 1)
                end
            end)
            manaBar.DragonUI_TexCoordHooked = true
        end
    end

    -- ---- Name background (anchored to healthBar like target_style) ----
    local nameBG = _G[frameName .. "NameBackground"]
    if nameBG then
        nameBG:ClearAllPoints()
        nameBG:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", -2, -5)
        nameBG:SetSize(135, 18)
        nameBG:SetTexture(TEXTURES.NAME_BACKGROUND)
        nameBG:SetDrawLayer("BORDER", 1)
        nameBG:SetBlendMode("ADD")
    end

    -- ---- Name text (anchored to healthBar like target_style) ----
    local nameText = _G[frameName .. "TextureFrameName"]
    if nameText then
        nameText:ClearAllPoints()
        nameText:SetPoint("BOTTOM", healthBar, "TOP", 4, 3)
        nameText:SetDrawLayer("OVERLAY", 2)
    end

    -- ---- Level text ----
    local levelText = _G[frameName .. "TextureFrameLevelText"]
    if levelText then
        levelText:ClearAllPoints()
        levelText:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", 18, 3)
        levelText:SetDrawLayer("OVERLAY", 2)
    end

    -- High level icon (skull)
    local highLevelTex = _G[frameName .. "TextureFrameHighLevelTexture"]
    if highLevelTex and levelText then
        highLevelTex:ClearAllPoints()
        highLevelTex:SetPoint("CENTER", levelText, "CENTER", -9, 6)
        highLevelTex:set_atlas("TargetFrame-HighLevelIcon", true)
    end

    -- Health text
    local healthText = _G[frameName .. "TextureFrameHealthBarText"]
    if healthText and healthBar then
        healthText:ClearAllPoints()
        healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
        healthText:SetDrawLayer("OVERLAY")
    end

    -- Dead text
    local deadText = _G[frameName .. "TextureFrameDeadText"]
    if deadText and healthBar then
        deadText:ClearAllPoints()
        deadText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
        deadText:SetDrawLayer("OVERLAY")
    end

    -- Mana text
    local manaText = _G[frameName .. "TextureFrameManaBarText"]
    if manaText and manaBar then
        manaText:ClearAllPoints()
        manaText:SetPoint("CENTER", manaBar, "CENTER", 0, 0)
        manaText:SetDrawLayer("OVERLAY")
    end

    -- PVP icon
    local pvpIcon = _G[frameName .. "TextureFramePVPIcon"]
    if pvpIcon then
        pvpIcon:ClearAllPoints()
        pvpIcon:SetPoint("CENTER", bossFrame, "BOTTOMRIGHT", 6, 14)
        pvpIcon:SetDrawLayer("OVERLAY", 7)
    end

    -- Leader icon
    local leaderIcon = _G[frameName .. "TextureFrameLeaderIcon"]
    if leaderIcon then
        leaderIcon:ClearAllPoints()
        leaderIcon:SetPoint("BOTTOM", bossFrame, "TOP", 26, -3)
    end

    -- Raid target icon — use Blizzard original directly (like target_style.lua)
    -- TextureFrame is raised above borderFrame+decoFrame so the icon renders on top.
    local raidTargetIcon = _G[frameName .. "TextureFrameRaidTargetIcon"]
    if raidTargetIcon and portrait then
        raidTargetIcon:SetDrawLayer("OVERLAY", 7)
        raidTargetIcon:SetSize(24, 24)
        raidTargetIcon:ClearAllPoints()
        raidTargetIcon:SetPoint("CENTER", portrait, "TOP", 0, 5)
        -- Hook SetPoint to block Blizzard from resetting position after reload
        if not raidTargetIcon.__DragonUI_SetPointHooked then
            local iconPortrait = portrait
            hooksecurefunc(raidTargetIcon, "SetPoint", function(self, ...)
                if self._DragonUI_SettingPoint or InCombatLockdown() then return end
                self._DragonUI_SettingPoint = true
                self:ClearAllPoints()
                self:SetPoint("CENTER", iconPortrait, "TOP", 0, 5)
                self._DragonUI_SettingPoint = nil
            end)
            raidTargetIcon.__DragonUI_SetPointHooked = true
        end
        -- Hook Hide to prevent Blizzard from hiding the icon when raid target exists
        if not raidTargetIcon.__DragonUI_HideHooked then
            local iconBossFrame = bossFrame
            hooksecurefunc(raidTargetIcon, "Hide", function(self)
                local unit = iconBossFrame.unit or iconBossFrame:GetAttribute("unit")
                if unit and UnitExists(unit) then
                    local idx = GetRaidTargetIndex(unit)
                    if idx then
                        self:Show()
                    end
                end
            end)
            raidTargetIcon.__DragonUI_HideHooked = true
        end
    end

    -- Flash texture (threat / combat glow)
    -- Same pattern as target.lua: custom THREAT texture with proper sizing.
    local flashTex = _G[frameName .. "Flash"]
    if flashTex then
        EnforceFlashStyle(flashTex, bossFrame)
    end

    -- Threat indicator
    if bossFrame.threatIndicator then
        bossFrame.threatIndicator:ClearAllPoints()
        bossFrame.threatIndicator:SetPoint("BOTTOMLEFT", 0, 0)
        bossFrame.threatIndicator:set_atlas("TargetFrame-Status", true)
    end

    -- Apply classification-based atlas border
    UpdateBossFrameBorder(bossFrame)

    -- ShowTest function for editor mode / testboss command
    bossFrame.ShowTest = function(self)
        local fn = self:GetName()
        local p = _G[fn .. "Portrait"]
        if p then
            SetPortraitTexture(p, "player")
        end

        local bg = _G[fn .. "NameBackground"]
        if bg then
            bg:SetVertexColor(UnitSelectionColor("player"))
        end

        local dead = _G[fn .. "TextureFrameDeadText"]
        if dead then dead:Hide() end

        local highLevel = _G[fn .. "TextureFrameHighLevelTexture"]
        if highLevel then highLevel:Hide() end

        local name = _G[fn .. "TextureFrameName"]
        if name then name:SetText(UnitName("player")) end

        local level = _G[fn .. "TextureFrameLevelText"]
        if level then
            level:SetText(UnitLevel("player"))
            level:Show()
        end

        local hpText = _G[fn .. "TextureFrameHealthBarText"]
        local curHP = UnitHealth("player")
        if hpText then hpText:SetText(curHP .. "/" .. curHP) end

        local mpText = _G[fn .. "TextureFrameManaBarText"]
        local curMP = UnitPower("player", 0) -- Mana
        if mpText then mpText:SetText(curMP .. "/" .. curMP) end

        local hp = _G[fn .. "HealthBar"]
        if hp then
            hp:SetMinMaxValues(0, curHP)
            hp:SetStatusBarColor(0.29, 0.69, 0.07)
            hp:SetValue(curHP)
            hp:Show()
        end

        local mp = _G[fn .. "ManaBar"]
        if mp then
            mp:SetMinMaxValues(0, curMP)
            mp:SetValue(curMP)
            mp:SetStatusBarColor(0.02, 0.32, 0.71)
            mp:Show()
        end

        self:Show()
    end

    bossFrame.HideTest = function(self)
        self:Hide()
    end
end

-- ============================================================================
-- HIDE BLIZZARD BACKGROUNDS
-- ============================================================================

local function HideBlizzardBossBackgrounds()
    local backgrounds = {
        _G.Boss1TargetFrameBackground,
        _G.Boss2TargetFrameBackground,
        _G.Boss3TargetFrameBackground,
        _G.Boss4TargetFrameBackground,
    }
    for _, bg in ipairs(backgrounds) do
        if bg then bg:SetAlpha(0) end
    end
end

-- ============================================================================
-- CLASSIFICATION HOOK (re-apply styling after Blizzard resets it)
-- ============================================================================

local function HookClassification()
    if BossModule.classificationHooked then return end

    hooksecurefunc("TargetFrame_CheckClassification", function(self, forceNormalTexture)
        -- Only process boss frames
        local frameName = self:GetName()
        if not frameName or not frameName:match("^Boss%dTargetFrame$") then return end
        if InCombatLockdown() then return end

        -- Hide Blizzard border (we use our own custom textures)
        local blizzBorder = _G[frameName .. "TextureFrameTexture"]
        if blizzBorder then blizzBorder:SetAlpha(0) end

        -- Re-apply bar size and anchor — Blizzard also re-anchors these here.
        local portrait = _G[frameName .. "Portrait"]
        local healthBar = _G[frameName .. "HealthBar"]
        if healthBar then
            healthBar:SetSize(125, 20)
            if portrait then
                healthBar:ClearAllPoints()
                healthBar:SetPoint("RIGHT", portrait, "LEFT", -1, 0)
            end
        end

        local manaBar = _G[frameName .. "ManaBar"]
        if manaBar then
            manaBar:SetSize(132, 9)
            if portrait then
                manaBar:ClearAllPoints()
                manaBar:SetPoint("RIGHT", portrait, "LEFT", 6.5, -16.5)
            end
        end

        local nameText = _G[frameName .. "TextureFrameName"]
        if nameText then
            nameText:ClearAllPoints()
            local healthBar = _G[frameName .. "HealthBar"]
            if healthBar then
                nameText:SetPoint("BOTTOM", healthBar, "TOP", 4, 3)
            end
        end

        local levelText = _G[frameName .. "TextureFrameLevelText"]
        if levelText then
            levelText:ClearAllPoints()
            local healthBar = _G[frameName .. "HealthBar"]
            if healthBar then
                levelText:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", 18, 3)
            end
        end

        local pvpIcon = _G[frameName .. "TextureFramePVPIcon"]
        if pvpIcon then
            pvpIcon:ClearAllPoints()
            pvpIcon:SetPoint("CENTER", self, "BOTTOMRIGHT", 6, 14)
        end

        -- Update border textures
        UpdateBossFrameBorder(self)

        -- Re-enforce elite decoration on decoFrame
        local portrait = _G[frameName .. "Portrait"]
        ApplyEliteDecoration(self, portrait)

        -- Re-enforce flash after classification change
        local flashTex = _G[frameName .. "Flash"]
        EnforceFlashStyle(flashTex, self)

        -- Re-enforce raid target icon draw layer (like target_style.lua)
        local raidTargetIcon = _G[frameName .. "TextureFrameRaidTargetIcon"]
        if raidTargetIcon then
            raidTargetIcon:SetDrawLayer("OVERLAY", 7)
            raidTargetIcon:SetSize(24, 24)
            raidTargetIcon:ClearAllPoints()
            local portrait = _G[frameName .. "Portrait"]
            if portrait then
                raidTargetIcon:SetPoint("CENTER", portrait, "TOP", 0, 5)
            end
        end
    end)

    BossModule.classificationHooked = true
end

-- ============================================================================
-- HEALTH BAR COLOR HOOK
-- ============================================================================

local function HookHealthBarColor()
    if BossModule.healthHooked then return end

    hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
        if not statusbar or statusbar.lockValues then return end
        if not unit or not unit:match("^boss%d$") then return end
        if unit ~= statusbar.unit then return end
        if InCombatLockdown() then return end

        -- Re-enforce bar sizing — Blizzard can reset during combat
        statusbar:SetSize(125, 20)
        local parent = statusbar:GetParent()
        if parent then statusbar:SetFrameLevel(parent:GetFrameLevel() + 1) end
        local statusBarTex = statusbar:GetStatusBarTexture()
        if statusBarTex then
            statusBarTex:SetAllPoints(statusbar)
        end
    end)

    BossModule.healthHooked = true
end

-- ============================================================================
-- TARGET FRAME UPDATE HOOK — re-enforce reskin after Blizzard resets layout
-- ============================================================================
-- Blizzard's TargetFrame_Update runs during combat and can reset health/mana
-- bar sizes, anchors, and the boss frame size itself. This hook fires after
-- every such update to maintain our Dragonflight styling.

local function HookTargetFrameUpdate()
    if BossModule.targetFrameUpdateHooked then return end

    local function RefreshBossTargetFrameLayout(self)
        local frameName = self:GetName()
        if not frameName or not frameName:match("^Boss%dTargetFrame$") then return end

        -- Find which wrapper this boss frame belongs to
        local bossIdx = tonumber(frameName:match("Boss(%d)TargetFrame"))
        local positionAnchor = bossIdx and
            (BossModule.secureAnchors[bossIdx] or BossModule.wrapperFrames[bossIdx])
        if positionAnchor then
            -- Re-anchor boss frame to our wrapper — Blizzard's TargetFrame_Update
            -- repositions frames to their default location during combat.
            -- (SetPoint hook also enforces this, but we double-check here.)
            self._DragonUI_SettingPoint = true
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", positionAnchor, "TOPLEFT", 0, 0)
            self:SetHitRectInsets(0, 0, 0, 0)
            self._DragonUI_SettingPoint = nil
        end

        -- Re-enforce portrait positioning and refresh texture
        local portrait = _G[frameName .. "Portrait"]
        if portrait then
            portrait:ClearAllPoints()
            portrait:SetSize(56, 56)
            portrait:SetPoint("TOPRIGHT", self, "TOPRIGHT", -47, -15)
            portrait:SetDrawLayer("ARTWORK", 1)
            local unit = self.unit or self:GetAttribute("unit")
            if unit and UnitExists(unit) then
                SetPortraitTexture(portrait, unit)
            end
        end

        -- Re-enforce health bar sizing and position
        local healthBar = _G[frameName .. "HealthBar"]
        if healthBar and portrait then
            healthBar:ClearAllPoints()
            healthBar:SetSize(125, 20)
            healthBar:SetPoint("RIGHT", portrait, "LEFT", -1, 0)
            healthBar:SetFrameLevel(self:GetFrameLevel() + 1)
            local statusBarTex = healthBar:GetStatusBarTexture()
            if statusBarTex then
                statusBarTex:SetAllPoints(healthBar)
            end
        end

        -- Re-enforce mana bar sizing and position
        local manaBar = _G[frameName .. "ManaBar"]
        if manaBar and portrait then
            manaBar:ClearAllPoints()
            manaBar:SetSize(132, 9)
            manaBar:SetPoint("RIGHT", portrait, "LEFT", 6.5, -16.5)
            manaBar:SetFrameLevel(self:GetFrameLevel() + 1)
            local statusBarTex = manaBar:GetStatusBarTexture()
            if statusBarTex then
                statusBarTex:SetAllPoints(manaBar)
            end
        end

        -- Hide Blizzard border and re-anchor our textures
        local blizzBorder = _G[frameName .. "TextureFrameTexture"]
        if blizzBorder then blizzBorder:SetAlpha(0) end
        UpdateBossFrameBorder(self)

        -- Re-enforce elite decoration on decoFrame
        ApplyEliteDecoration(self, portrait)

        -- Re-enforce name background
        local nameBG = _G[frameName .. "NameBackground"]
        if nameBG and healthBar then
            nameBG:ClearAllPoints()
            nameBG:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", -2, -5)
            nameBG:SetSize(135, 18)
            nameBG:SetTexture(TEXTURES.NAME_BACKGROUND)
        end

        -- Re-enforce flash (race condition fix)
        local flashTex = _G[frameName .. "Flash"]
        EnforceFlashStyle(flashTex, self)

        -- Re-enforce raid target icon draw layer (like target_style.lua)
        local raidTargetIcon = _G[frameName .. "TextureFrameRaidTargetIcon"]
        if raidTargetIcon then
            raidTargetIcon:SetDrawLayer("OVERLAY", 7)
            raidTargetIcon:SetSize(24, 24)
            raidTargetIcon:ClearAllPoints()
            if portrait then
                raidTargetIcon:SetPoint("CENTER", portrait, "TOP", 0, 5)
            end
        end

        -- Re-hide Blizzard background
        local bg = _G[frameName .. "Background"]
        if bg then bg:SetAlpha(0) end
    end

    hooksecurefunc("TargetFrame_Update", function(self)
        if InCombatLockdown() then
            if addon.CombatQueue and self and self.GetName then
                local frameName = self:GetName()
                if frameName and frameName:match("^Boss%dTargetFrame$") then
                    addon.CombatQueue:Add("boss_targetframe_update_" .. frameName, function()
                        if self and self.GetName and self:GetName() == frameName and not InCombatLockdown() then
                            RefreshBossTargetFrameLayout(self)
                        end
                    end)
                end
            end
            return
        end

        RefreshBossTargetFrameLayout(self)
    end)

    BossModule.targetFrameUpdateHooked = true
end

-- ============================================================================
-- POSITIONING
-- ============================================================================

local function PositionBossFrames()
    if InCombatLockdown() then return end

    local config = GetConfig()
    local scale = config.scale or 1.0

    for i = 1, NUM_BOSS_FRAMES do
        local wrapper = BossModule.wrapperFrames[i]
        if wrapper then
            wrapper:SetScale(scale)

            if i == 1 then
                -- Always anchor to overlay so editor drag moves everything
                if BossModule.overlay then
                    wrapper:ClearAllPoints()
                    wrapper:SetPoint("TOP", BossModule.overlay, "TOP", 20, 0)
                else
                    wrapper:ClearAllPoints()
                    wrapper:SetPoint(
                        config.anchor or "TOPRIGHT",
                        UIParent,
                        config.anchorParent or "TOPRIGHT",
                        config.x or -100,
                        config.y or -270
                    )
                end
            else
                -- Stack below previous
                wrapper:ClearAllPoints()
                wrapper:SetPoint("TOP", BossModule.wrapperFrames[i - 1], "BOTTOM", 0, 0)
            end
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function InitializeBossFrames()
    if BossModule.configured then return end
    if InCombatLockdown() then return end
    if not IsEnabled() then return end

    HideBlizzardBossBackgrounds()

    for i = 1, NUM_BOSS_FRAMES do
        local bossFrame = _G["Boss" .. i .. "TargetFrame"]
        if bossFrame then
            -- Create wrapper frame for positioning
            local wrapper = addon.CreateUIFrame(200, 75, "Boss" .. i .. "Frame")
            BossModule.wrapperFrames[i] = wrapper
            CreateSecureBossAnchor(wrapper, bossFrame, i)

            -- Ensure the unit attribute is set so RegisterUnitWatch knows
            -- which unit token to track (INSTANCE_ENCOUNTER_ENGAGE_UNIT
            -- does not exist in 3.3.5a — MCP Ch.25 / Roadmap note).
            if not bossFrame:GetAttribute("unit") then
                bossFrame:SetAttribute("unit", "boss" .. i)
            end

            -- RegisterUnitWatch: auto show/hide based on UnitExists("bossN").
            -- This is the 3.3.5a replacement for INSTANCE_ENCOUNTER_ENGAGE_UNIT.
            -- DragonflightUI Bossframe.mixin.lua uses the same pattern.
            RegisterUnitWatch(bossFrame)

            -- Alpha-only fade layered on top of RegisterUnitWatch's own Show/Hide.
            if addon.VisibilityFade then
                addon.VisibilityFade.Register("boss" .. i, bossFrame, {
                    dbTable = function() return addon.UF.GetConfig("boss") end,
                    clickThrough = true,
                })
            end

            -- Hook SetPoint to block ALL Blizzard repositioning
            HookBossFrameSetPoint(bossFrame, i)

            -- Reskin the Blizzard boss frame
            ReskinBossFrame(wrapper, bossFrame, i)

            -- Hook OnShow to refresh visuals when boss appears
            if not bossFrame.__DragonUI_OnShowHooked then
                bossFrame:HookScript("OnShow", function(self)
                    if addon.VisibilityFade then addon.VisibilityFade.Update("boss" .. i) end
                    -- Re-hide Blizzard elements
                    local fn = self:GetName()
                    local bg = _G[fn .. "Background"]
                    if bg then bg:SetAlpha(0) end
                    local blizzBorder = _G[fn .. "TextureFrameTexture"]
                    if blizzBorder then blizzBorder:SetAlpha(0) end
                    if InCombatLockdown() then return end
                    -- Update border textures
                    UpdateBossFrameBorder(self)
                    -- Refresh portrait
                    local portrait = _G[fn .. "Portrait"]
                    if portrait then
                        local unit = self.unit or self:GetAttribute("unit")
                        if unit and UnitExists(unit) then
                            SetPortraitTexture(portrait, unit)
                        end
                    end
                    -- Re-enforce flash on show
                    local flashTex = _G[fn .. "Flash"]
                    EnforceFlashStyle(flashTex, self)
                    -- Re-enforce elite decoration on show
                    ApplyEliteDecoration(self, portrait)
                    -- Re-enforce raid target icon draw layer on show
                    local raidTargetIcon = _G[fn .. "TextureFrameRaidTargetIcon"]
                    if raidTargetIcon then
                        raidTargetIcon:SetDrawLayer("OVERLAY", 7)
                        raidTargetIcon:SetSize(24, 24)
                        raidTargetIcon:ClearAllPoints()
                        if portrait then
                            raidTargetIcon:SetPoint("CENTER", portrait, "TOP", 0, 5)
                        end
                    end
                end)
                bossFrame.__DragonUI_OnShowHooked = true
            end
        end
    end

    HookClassification()
    HookHealthBarColor()
    HookTargetFrameUpdate()
    PositionBossFrames()

    BossModule.initialized = true
    BossModule.applied = true
    BossModule.configured = true
end

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

local function SetupEditorMode()
    local totalHeight = NUM_BOSS_FRAMES * 75 - 6
    BossModule.overlay = addon.CreateUIFrame(178, totalHeight, "boss")

    if BossModule.overlay.editorText then
        local L = addon.L
        BossModule.overlay.editorText:SetText((L and (L["boss"] or L["Boss Frames"])) or "Boss Frames")
    end

    -- Initial position will be set by ApplyBossFramePosition()
    BossModule.overlay:ClearAllPoints()
    BossModule.overlay:SetPoint(
        "TOPRIGHT", UIParent, "TOPRIGHT", -100, -270
    )

    BossModule.overlay:HookScript("OnDragStop", function(self)
        self.DragonUI_WasDragged = true
    end)

    addon:RegisterEditableFrame({
        name = "boss",
        frame = BossModule.overlay,
        configPath = {"widgets", "boss"},
        hasTarget = function()
            return true
        end,
        showTest = function()
            if BossModule.overlay then
                BossModule.overlay:Show()
            end
            -- Show boss frames in test mode
            for i = 1, NUM_BOSS_FRAMES do
                local bossFrame = _G["Boss" .. i .. "TargetFrame"]
                if bossFrame and not InCombatLockdown() then
                    UnregisterUnitWatch(bossFrame)
                    if bossFrame.ShowTest then
                        bossFrame:ShowTest()
                    end
                end
            end
        end,
        hideTest = function()
            for i = 1, NUM_BOSS_FRAMES do
                local bossFrame = _G["Boss" .. i .. "TargetFrame"]
                if bossFrame and not InCombatLockdown() then
                    RegisterUnitWatch(bossFrame)
                    if bossFrame.HideTest and not UnitExists("boss" .. i) then
                        bossFrame:HideTest()
                    end
                end
            end
        end,
        onHide = function()
            if BossModule.overlay and BossModule.overlay.DragonUI_WasDragged then
                local config = GetConfig()
                if config then
                    config.override = true
                end
                PositionBossFrames()
                BossModule.overlay.DragonUI_WasDragged = nil
            end
        end,
        module = BossModule
    })
end

-- ============================================================================
-- APPLY / RESTORE
-- ============================================================================

local function ApplyBossFramePosition()
    if not BossModule.overlay then return end
    local config = GetConfig()
    if config and config.override then
        if addon.db and addon.db.profile and addon.db.profile.widgets then
            local widgetConfig = addon.db.profile.widgets.boss
            if widgetConfig and widgetConfig.posX and widgetConfig.posY then
                local anchor = widgetConfig.anchor or "CENTER"
                BossModule.overlay:ClearAllPoints()
                BossModule.overlay:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
                return
            end
        end
    end
    -- Default: use config position
    if config then
        BossModule.overlay:ClearAllPoints()
        BossModule.overlay:SetPoint(
            config.anchor or "TOPRIGHT",
            UIParent,
            config.anchorParent or "TOPRIGHT",
            config.x or -100,
            config.y or -270
        )
    else
        BossModule.overlay:ClearAllPoints()
        BossModule.overlay:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -270)
    end
end

-- ============================================================================
-- RAID TARGET ICON REFRESH
-- ============================================================================
-- After /reload, RAID_TARGET_UPDATE doesn't fire — existing marks are already
-- set. We must manually query GetRaidTargetIndex for each boss and apply the
-- texture. Called after init and with a short delay to cover late unit loading.

local function RefreshRaidTargetIcons()
    for i = 1, NUM_BOSS_FRAMES do
        local bf = _G["Boss" .. i .. "TargetFrame"]
        if bf then
            local fn = bf:GetName()
            local icon = _G[fn .. "TextureFrameRaidTargetIcon"]
            local portrait = _G[fn .. "Portrait"]
            -- Re-raise TextureFrame above borderFrame+decoFrame
            local textureFrame = _G[fn .. "TextureFrame"]
            local borderFrame = bf.DragonUI_BorderFrame
            if textureFrame and borderFrame then
                textureFrame:SetFrameLevel(borderFrame:GetFrameLevel() + 2)
            end
            if icon and portrait then
                icon:SetDrawLayer("OVERLAY", 7)
                icon:SetSize(24, 24)
                local unit = bf.unit or bf:GetAttribute("unit")
                if unit and UnitExists(unit) then
                    local idx = GetRaidTargetIndex(unit)
                    if idx then
                        SetRaidTargetIconTexture(icon, idx)
                        icon:Show()
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventsFrame = CreateFrame("Frame")
BossModule.eventsFrame = eventsFrame

eventsFrame:SetScript("OnEvent", function(self, event, ...)
    if not IsEnabled() then return end

    if event == "ADDON_LOADED" then
        local name = ...
        if name == "DragonUI" then
            SetupEditorMode()
            ApplyBossFramePosition()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeBossFrames()
        PositionBossFrames()
        HideBlizzardBossBackgrounds()
        RefreshRaidTargetIcons()
        -- Delayed refresh: boss units may not exist yet at PLAYER_ENTERING_WORLD
        if not BossModule.raidIconRefreshFrame then
            local f = CreateFrame("Frame")
            f.elapsed = 0
            f.ticks = 0
            f:SetScript("OnUpdate", function(self, dt)
                self.elapsed = self.elapsed + dt
                if self.elapsed >= 0.5 then
                    self.elapsed = 0
                    self.ticks = self.ticks + 1
                    RefreshRaidTargetIcons()
                    if self.ticks >= 4 then
                        self:SetScript("OnUpdate", nil)
                    end
                end
            end)
            BossModule.raidIconRefreshFrame = f
        else
            -- Re-arm the delayed refresh
            local f = BossModule.raidIconRefreshFrame
            f.elapsed = 0
            f.ticks = 0
            f:SetScript("OnUpdate", function(self, dt)
                self.elapsed = self.elapsed + dt
                if self.elapsed >= 0.5 then
                    self.elapsed = 0
                    self.ticks = self.ticks + 1
                    RefreshRaidTargetIcons()
                    if self.ticks >= 4 then
                        self:SetScript("OnUpdate", nil)
                    end
                end
            end)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if not BossModule.configured then
            InitializeBossFrames()
        end
        PositionBossFrames()

    elseif event == "RAID_TARGET_UPDATE" then
        RefreshRaidTargetIcons()
    end
end)

eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventsFrame:RegisterEvent("RAID_TARGET_UPDATE")

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function addon.RefreshBossFrames()
    if not BossModule.configured then return end
    if InCombatLockdown() then return end
    if not IsEnabled() then
        addon:ShouldDeferModuleDisable("boss", BossModule)
        return
    end

    HideBlizzardBossBackgrounds()

    for i = 1, NUM_BOSS_FRAMES do
        local bossFrame = _G["Boss" .. i .. "TargetFrame"]
        local wrapper = BossModule.wrapperFrames[i]
        if bossFrame and wrapper then
            ReskinBossFrame(wrapper, bossFrame, i)
        end
    end

    PositionBossFrames()
end

-- Store reference on addon for profile callbacks
addon.BossModule = BossModule

-- Profile change callbacks
local function OnProfileChanged()
    if not IsEnabled() then
        addon:ShouldDeferModuleDisable("boss", BossModule)
        return
    end

    if addon.RefreshBossFrames then
        addon.RefreshBossFrames()
    end
end

local profileFrame = CreateFrame("Frame")
profileFrame:RegisterEvent("PLAYER_LOGIN")
profileFrame:SetScript("OnEvent", function(self, event)
    if addon.db and addon.db.RegisterCallback then
        addon.db.RegisterCallback(BossModule, "OnProfileChanged", OnProfileChanged)
        addon.db.RegisterCallback(BossModule, "OnProfileCopied", OnProfileChanged)
        addon.db.RegisterCallback(BossModule, "OnProfileReset", OnProfileChanged)
    end
    self:UnregisterAllEvents()
end)
