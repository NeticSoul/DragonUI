--[[
  DragonUI - Target-Style Unit Frame Factory (target_style.lua)

  Closure factory for target-style unit frames (Target, Focus).
  Loaded after uf_core.lua, before target.lua and focus.lua.
]]

local _, addon = ...
local UF = addon.UF

UF.TargetStyle = {}

-- 3.3.5a has no UNIT_POWER/UNIT_MAXPOWER; power changes fire one event per power token.
local POWER_EVENTS = {
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
    UNIT_MAXRUNIC_POWER = true,
}

-- ============================================================================
-- FACTORY
-- ============================================================================

function UF.TargetStyle.Create(opts)
    -- ----------------------------------------------------------------
    -- Module table
    -- ----------------------------------------------------------------
    local Module = {
        overlay       = nil,    -- Editor overlay frame
        textSystem    = nil,    -- TextSystem reference
        initialized   = false,  -- ADDON_LOADED has fired
        configured    = false,  -- Frame setup is complete
        eventsFrame   = nil,    -- Event handler frame
        positionStabilizer = nil,
    }

    -- ----------------------------------------------------------------
    -- Local aliases from opts
    -- ----------------------------------------------------------------
    local configKey       = opts.configKey
    local unitToken       = opts.unitToken
    local widgetKey       = opts.widgetKey or configKey
    local combatQueueKey  = opts.combatQueueKey or (configKey .. "_position")
    local BlizzFrame      = opts.blizzFrame
    local HealthBar       = opts.healthBar
    local ManaBar         = opts.manaBar
    local Portrait        = opts.portrait
    local NameText        = opts.nameText
    local LevelText       = opts.levelText
    local NameBackground  = opts.nameBackground
    local namePrefix      = opts.namePrefix
    local DeadText        = opts.deadText or _G[namePrefix .. "FrameTextureFrameDeadText"]
    local HighLevelTexture = _G[namePrefix .. "FrameTextureFrameHighLevelTexture"]
    local defaultPos      = opts.defaultPos

    -- Shared texture / constant tables from uf_core
    local TEXTURES    = UF.TEXTURES.targetStyle
    local BOSS_COORDS = UF.BOSS_COORDS.targetStyle
    local POWER_MAP   = UF.POWER_MAP

    -- Name background color variants sourced from UIUnitFrame2x_PTR.blp.
    -- Coords extracted from the local PTR atlas (1024x512) and mapped by color.
    local NAME_BG_PTR_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Target\\UIUnitFrame2x_PTR"
    local NAME_BG_WIDTH = 135
    local NAME_BG_HEIGHT = 14
    local NAME_BG_OFFSET_X = -0.5
    local NAME_BG_OFFSET_Y = 0.2
    local NAME_BG_TEX_COORDS = {
        blue = {
            266 / 1024, 534 / 1024,
            135 / 512, 166 / 512,
        },
        green = {
            536 / 1024, 804 / 1024,
            135 / 512, 166 / 512,
        },
        orange = {
            266 / 1024, 534 / 1024,
            168 / 512, 199 / 512,
        },
        red = {
            536 / 1024, 804 / 1024,
            168 / 512, 199 / 512,
        },
        yellow = {
            266 / 1024, 534 / 1024,
            201 / 512, 232 / 512,
        },
    }

    local NAME_BG_COLOR_PALETTE = {
        blue = {0.0, 0.44, 1.0},
        green = {0.0, 1.0, 0.0},
        orange = {1.0, 0.5, 0.0},
        red = {1.0, 0.0, 0.0},
        yellow = {1.0, 1.0, 0.0},
    }

    local function ApplyNameBackgroundLayout()
        if not NameBackground or not HealthBar then return end

        NameBackground:ClearAllPoints()
        NameBackground:SetPoint(
            "BOTTOMLEFT", HealthBar, "TOPLEFT", NAME_BG_OFFSET_X, NAME_BG_OFFSET_Y)
        NameBackground:SetSize(NAME_BG_WIDTH, NAME_BG_HEIGHT)
    end

    local function ResolveNameBackgroundColorKey(r, g, b)
        if not r or not g or not b then
            return "yellow"
        end

        local bestKey, bestDist = "yellow", 10
        for key, p in pairs(NAME_BG_COLOR_PALETTE) do
            local dr = r - p[1]
            local dg = g - p[2]
            local db = b - p[3]
            local dist = dr * dr + dg * dg + db * db
            if dist < bestDist then
                bestDist = dist
                bestKey = key
            end
        end

        return bestKey
    end

    -- ----------------------------------------------------------------
    -- Frame elements & throttle cache
    -- ----------------------------------------------------------------
    local frameElements = {
        background    = nil,
        border        = nil,
        elite         = nil,
        threatNumeric = nil,
    }

    local updateCache = {
        lastHealthUpdate  = 0,
        lastPowerUpdate   = 0,
        lastThreatUpdate  = 0,
        lastFamousMessage = 0,
        lastFamousTarget  = nil,
        lastPortraitClass = nil,
        lastPortraitAlt   = nil,
    }

    -- ================================================================
    -- CONFIG
    -- ================================================================

    local function GetConfig()
        return UF.GetConfig(configKey)
    end

    -- ================================================================
    -- WIDGET POSITION
    -- ================================================================

    local function ApplyWidgetPosition()
        if not Module.overlay then return end
        if InCombatLockdown() then
            if addon.CombatQueue then
                addon.CombatQueue:Add(combatQueueKey, ApplyWidgetPosition)
            end
            return
        end

        local wc = addon.db and addon.db.profile.widgets
                    and addon.db.profile.widgets[widgetKey]
        if wc then
            Module.overlay:ClearAllPoints()
            Module.overlay:SetPoint(
                wc.anchor or defaultPos.anchor, UIParent,
                wc.anchor or defaultPos.anchor,
                wc.posX ~= nil and wc.posX or defaultPos.posX,
                wc.posY ~= nil and wc.posY or defaultPos.posY)
            BlizzFrame:ClearAllPoints()
            BlizzFrame:SetPoint("CENTER", Module.overlay, "CENTER", 20, -7)
        else
            Module.overlay:ClearAllPoints()
            Module.overlay:SetPoint(
                defaultPos.anchor, UIParent, defaultPos.anchor,
                defaultPos.posX, defaultPos.posY)
            BlizzFrame:ClearAllPoints()
            BlizzFrame:SetPoint("CENTER", Module.overlay, "CENTER", 20, -7)
        end
    end

    local function StartPositionStabilizer(duration)
        if not Module.configured then return end

        if not Module.positionStabilizer then
            Module.positionStabilizer = CreateFrame("Frame")
        end

        local elapsed = 0
        local maxDuration = duration or 1.0
        Module.positionStabilizer:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt

            -- Re-apply often for a short window to win any delayed Blizzard reanchor.
            if Module.configured then
                ApplyWidgetPosition()
            end

            if elapsed >= maxDuration then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    -- ================================================================
    -- VISIBILITY
    -- ================================================================

    local function ShouldBeVisible()
        return UnitExists(unitToken)
    end

    local function ShowFrameTest()
        if BlizzFrame and BlizzFrame.ShowTest then
            BlizzFrame:ShowTest()
        end
    end

    local function HideFrameTest()
        if BlizzFrame and BlizzFrame.HideTest then
            BlizzFrame:HideTest()
        end
    end

    -- ================================================================
    -- CLASS PORTRAIT
    -- ================================================================

    local function RestoreNativePortrait()
        if UnitExists(unitToken) then
            -- Do NOT force a draw layer here. Previously this set
            -- Portrait:SetDrawLayer("ARTWORK", 0) on every refresh, which
            -- fought with addons that legitimately alter the portrait layer
            -- (BigDebuffs, LoseControl, etc.). The initial DragonUI style
            -- setup (further below) already sets the desired layer once
            -- at frame construction. Re-applying it on every update only
            -- created a draw-layer conflict. Keep whatever layer is current.
            Portrait:SetDrawLayer(Portrait:GetDrawLayer())
            SetPortraitTexture(Portrait, unitToken)
            Portrait:SetTexCoord(0, 1, 0, 1)
        end
        Portrait:SetAlpha(1)
    end

    local function UpdateClassPortrait()
        local config = GetConfig()
        if not config then return end

        local useAlternative = config.alternativeClassIcons and true or false

        if config.classPortrait and UnitExists(unitToken) and UnitIsPlayer(unitToken) then
            local _, classFileName = UnitClass(unitToken)
            if classFileName
               and updateCache.lastPortraitClass == classFileName
               and updateCache.lastPortraitAlt == useAlternative then
                return
            end

            if UF.UpdateClassPortrait(
                unitToken,
                Portrait,
                BlizzFrame,
                frameElements,
                true,
                useAlternative
            ) then
                updateCache.lastPortraitClass = classFileName
                updateCache.lastPortraitAlt = useAlternative
                return
            end
        end

        -- Disabled, non-player, or fallback: restore the native portrait texture.
        updateCache.lastPortraitClass = nil
        updateCache.lastPortraitAlt = nil
        UF.UpdateClassPortrait(unitToken, Portrait, BlizzFrame, frameElements, false, useAlternative)
        RestoreNativePortrait()
    end

    -- ================================================================
    -- HEALTH BAR COLOR
    -- ================================================================

    local isUpdatingColor = false

    local function UpdateHealthBarColor(force)
        if not UnitExists(unitToken) or not HealthBar then return end
        if isUpdatingColor then return end -- prevent recursion from SetVertexColor/SetStatusBarColor hooks

        -- Per-frame throttle: skip redundant calls in the same render frame.
        -- Multiple hooks (SetValue, OnValueChanged, SetStatusBarColor,
        -- UnitFrameHealthBar_Update, TargetFrame_Update) can all fire for
        -- the same event, especially when target==player.  Running once per
        -- frame is enough to keep visuals correct while avoiding the
        -- rendering pipeline churn that causes aura-icon flicker.
        -- The "force" flag bypasses the throttle so that correction hooks
        -- (SetStatusBarColor) always win the race against Blizzard resets.
        if not force then
            local now = GetTime()
            if now == updateCache.lastColorFrame then return end
            updateCache.lastColorFrame = now
        end

        isUpdatingColor = true

        local config  = GetConfig()
        local texture = HealthBar:GetStatusBarTexture()
        if not texture then return end

        if config.classcolor and UnitIsPlayer(unitToken) then
            local statusPath = TEXTURES.BAR_PREFIX .. "Health-Status"
            if texture:GetTexture() ~= statusPath then
                texture:SetTexture(statusPath)
                texture:SetDrawLayer("ARTWORK", 1)
            end
            local _, class = UnitClass(unitToken)
            local color = RAID_CLASS_COLORS[class]
            if color then
                texture:SetVertexColor(color.r, color.g, color.b, 1)
            else
                texture:SetVertexColor(1, 1, 1, 1)
            end
        else
            local normalPath = TEXTURES.BAR_PREFIX .. "Health"
            if texture:GetTexture() ~= normalPath then
                texture:SetTexture(normalPath)
                texture:SetDrawLayer("ARTWORK", 1)
            end
            texture:SetVertexColor(1, 1, 1, 1)
        end

        isUpdatingColor = false
    end

    -- ================================================================
    -- POWER BAR FORCE UPDATE
    -- ================================================================

    local function ForceUpdatePowerBar()
        if not UnitExists(unitToken) or not ManaBar then return end
        local texture = ManaBar:GetStatusBarTexture()
        if not texture then return end

        local powerType = UnitPowerType(unitToken)
        local powerName = POWER_MAP[powerType] or "Mana"
        texture:SetTexture(TEXTURES.BAR_PREFIX .. powerName)
        texture:SetDrawLayer("ARTWORK", 1)
        texture:SetVertexColor(1, 1, 1)

        local _, max = ManaBar:GetMinMaxValues()
        local current = ManaBar:GetValue()
        if max > 0 and current then
            texture:SetTexCoord(0, current / max, 0, 1)
        end
    end

    -- ================================================================
    -- LAYOUT REAPPLY
    -- ================================================================
    -- Overrides Blizzard element repositioning that occurs for special
    -- units (bosses, vehicles). Used by target; not needed for focus.

    local function ForceReapplyLayout()
        if Portrait then
            Portrait:ClearAllPoints()
            Portrait:SetSize(56, 56)
            Portrait:SetPoint("TOPRIGHT", BlizzFrame, "TOPRIGHT", -47, -15)
        end
        if HealthBar then
            HealthBar:ClearAllPoints()
            HealthBar:SetSize(125, 20)
            HealthBar:SetPoint("RIGHT", Portrait, "LEFT", -1, 0)
            HealthBar:SetFrameLevel(BlizzFrame:GetFrameLevel())
        end
        if ManaBar then
            ManaBar:ClearAllPoints()
            ManaBar:SetSize(132, 9.5)
            ManaBar:SetPoint("RIGHT", Portrait, "LEFT", 6.5, -16.5)
            ManaBar:SetFrameLevel(BlizzFrame:GetFrameLevel())
        end
        if NameText then
            NameText:ClearAllPoints()
            NameText:SetPoint("BOTTOM", HealthBar, "TOP", 10, 3)
        end
        if LevelText then
            LevelText:ClearAllPoints()
            LevelText:SetPoint("BOTTOMRIGHT", HealthBar, "TOPLEFT", 18, 3)
        end
        if HighLevelTexture and HealthBar then
            HighLevelTexture:ClearAllPoints()
            HighLevelTexture:SetPoint("BOTTOMRIGHT", HealthBar, "TOPLEFT", 18, 0)
        end
        if NameBackground then
            ApplyNameBackgroundLayout()
        end
        if DeadText and HealthBar then
            DeadText:ClearAllPoints()
            DeadText:SetPoint("CENTER", HealthBar, "CENTER", opts.deadTextOffsetX or 0, opts.deadTextOffsetY or 0)
            if DeadText.SetDrawLayer then
                DeadText:SetDrawLayer("OVERLAY", 2)
            end
        end
    end

    -- ================================================================
    -- BAR HOOKS
    -- ================================================================

    local function SetupBarHooks()
        -- Health bar hooks (once)
        if not HealthBar.DragonUI_Setup then
            local ht = HealthBar:GetStatusBarTexture()
            if ht then ht:SetDrawLayer("ARTWORK", 1) end

            hooksecurefunc(HealthBar, "SetValue", function(self)
                if not UnitExists(unitToken) then return end

                -- Color: always update immediately (no throttle)
                UpdateHealthBarColor()

                -- TexCoord: throttled for performance
                local now = GetTime()
                if now - updateCache.lastHealthUpdate < 0.05 then return end
                updateCache.lastHealthUpdate = now

                local texture = self:GetStatusBarTexture()
                if texture then
                    local _, max = self:GetMinMaxValues()
                    local cur = self:GetValue()
                    if max > 0 and cur then
                        texture:SetTexCoord(0, cur / max, 0, 1)
                    end
                end
            end)

            -- Catch value changes that bypass SetValue (Blizzard internal updates)
            HealthBar:HookScript("OnValueChanged", function(self)
                if UnitExists(unitToken) then
                    UpdateHealthBarColor()
                end
            end)

            -- Prevent Blizzard from resetting health bar to default green
            -- Use force=true to bypass the per-frame throttle so this
            -- correction always wins the race against Blizzard color resets.
            hooksecurefunc(HealthBar, "SetStatusBarColor", function(self)
                if UnitExists(unitToken) then
                    UpdateHealthBarColor(true)
                end
            end)

            HealthBar.DragonUI_Setup = true
        end

        -- Power bar hooks (once)
        if not ManaBar.DragonUI_Setup then
            local pt = ManaBar:GetStatusBarTexture()
            if pt then pt:SetDrawLayer("ARTWORK", 1) end

            -- Force white on any color change attempt
            hooksecurefunc(ManaBar, "SetStatusBarColor", function(self)
                local texture = self:GetStatusBarTexture()
                if texture then texture:SetVertexColor(1, 1, 1, 1) end
            end)
            ManaBar:SetStatusBarColor(1, 1, 1, 1)

            -- Update texture & coords on every value change
            hooksecurefunc(ManaBar, "SetValue", function(self)
                if not UnitExists(unitToken) then return end
                local texture = self:GetStatusBarTexture()
                if not texture then return end

                local powerType = UnitPowerType(unitToken)
                local powerName = POWER_MAP[powerType] or "Mana"
                texture:SetTexture(TEXTURES.BAR_PREFIX .. powerName)
                texture:SetDrawLayer("ARTWORK", 1)
                texture:SetVertexColor(1, 1, 1)
                ManaBar:SetStatusBarColor(1, 1, 1)

                local _, max = self:GetMinMaxValues()
                local cur = self:GetValue()
                if max > 0 and cur then
                    texture:SetTexCoord(0, cur / max, 0, 1)
                end
            end)
            ManaBar.DragonUI_Setup = true
        end

        -- Portrait hook for class portrait
        if not BlizzFrame.DragonUI_PortraitHook then
            hooksecurefunc("UnitFramePortrait_Update", function(frame, unit)
                if frame == BlizzFrame and unit == unitToken then
                    UpdateClassPortrait()
                end
            end)
            BlizzFrame.DragonUI_PortraitHook = true
        end

        -- Vanilla routes the bars through TextStatusBar, skipping UnitFrame_OnEnter's newbie tip.
        if not BlizzFrame.DragonUI_BarTooltipHook then
            local overBar

            local function IsOverBar()
                return ((HealthBar:IsVisible() and HealthBar:IsMouseOver())
                    or (ManaBar:IsVisible() and ManaBar:IsMouseOver())) and true or false
            end

            local function ApplyTooltip()
                if overBar then
                    UnitFrame_UpdateTooltip(BlizzFrame)
                else
                    -- Newbie tips never install UpdateTooltip; a stale one would swap the tip out mid-hover.
                    BlizzFrame.UpdateTooltip = nil
                    UnitFrame_OnEnter(BlizzFrame)
                end
            end

            -- Only reacts to crossing the bar edge; rebuilding on a timer flickers the tooltip.
            local watcher = CreateFrame("Frame")
            watcher:Hide()
            watcher:SetScript("OnUpdate", function(self)
                if not BlizzFrame:IsMouseOver() then
                    self:Hide()
                    return
                end
                local now = IsOverBar()
                if now ~= overBar then
                    overBar = now
                    ApplyTooltip()
                end
            end)

            BlizzFrame:HookScript("OnEnter", function()
                overBar = IsOverBar()
                ApplyTooltip()
                watcher:Show()
            end)
            BlizzFrame:HookScript("OnLeave", function()
                watcher:Hide()
            end)

            BlizzFrame.DragonUI_BarTooltipHook = true
        end

        -- Hook afterBarHooks callback if provided
        if opts.afterBarHooks then
            opts.afterBarHooks(Module, ManaBar, GetConfig, updateCache)
        end

    end

    -- ================================================================
    -- THREAT SYSTEM
    -- ================================================================

    local function UpdateThreat()
        if not UnitExists(unitToken) then
            if frameElements.threatNumeric then
                frameElements.threatNumeric:Hide()
            end
            return
        end

        local status = UnitThreatSituation("player", unitToken)
        local level  = status and math.min(status, 3) or 0

        if level > 0 then
            local _, _, _, pct = UnitDetailedThreatSituation("player", unitToken)
            if frameElements.threatNumeric and pct and pct > 0 then
                local displayPct = math.floor(math.min(100, math.max(0, pct)))
                frameElements.threatNumeric.text:SetText(displayPct .. "%")
                if level == 1 then
                    frameElements.threatNumeric.text:SetTextColor(1.0, 1.0, 0.47)
                elseif level == 2 then
                    frameElements.threatNumeric.text:SetTextColor(1.0, 0.6, 0.0)
                else
                    frameElements.threatNumeric.text:SetTextColor(1.0, 0.0, 0.0)
                end
                frameElements.threatNumeric:Show()
            else
                if frameElements.threatNumeric then
                    frameElements.threatNumeric:Hide()
                end
            end
        else
            if frameElements.threatNumeric then
                frameElements.threatNumeric:Hide()
            end
        end
    end

    -- ================================================================
    -- CLASSIFICATION SYSTEM
    -- ================================================================

    local function UpdateClassification()
        local raidTargetIcon = _G[namePrefix .. "FrameTextureFrameRaidTargetIcon"]
        if raidTargetIcon and raidTargetIcon.SetDrawLayer then
            raidTargetIcon:SetDrawLayer("OVERLAY", 7)
        end

        local pvpIcon = _G[namePrefix .. "FrameTextureFramePVPIcon"]
        if pvpIcon and pvpIcon.SetDrawLayer then
            pvpIcon:SetDrawLayer("OVERLAY", 7)
        end

        if not UnitExists(unitToken) or not frameElements.elite then
            if frameElements.elite then frameElements.elite:Hide() end
            return
        end

        local classification = UnitClassification(unitToken)
        local name   = UnitName(unitToken)
        local coords = nil

        if classification == "worldboss" then
            coords = BOSS_COORDS.rareelite
        elseif classification == "elite" then
            coords = BOSS_COORDS.elite
        elseif classification == "rareelite" then
            coords = BOSS_COORDS.rareelite
        elseif classification == "rare" then
            coords = BOSS_COORDS.rare
        else
            -- Fallback: famous NPC or skull-level boss
            if name and UF.FAMOUS_NPCS[name] then
                coords = BOSS_COORDS.elite
                if opts.onFamousNpc then
                    opts.onFamousNpc(name, updateCache)
                end
            else
                local unitLevel = UnitLevel(unitToken)
                if unitLevel == -1 then
                    coords = BOSS_COORDS.rareelite
                end
            end
        end

        if coords then
            frameElements.elite:SetDrawLayer("ARTWORK", 1)
            frameElements.elite:SetTexCoord(
                coords[1], coords[2], coords[3], coords[4])
            frameElements.elite:SetSize(coords[5], coords[6])
            frameElements.elite:ClearAllPoints()
            frameElements.elite:SetPoint(
                "CENTER", Portrait, "CENTER", coords[7], coords[8])
            frameElements.elite:Show()
        else
            frameElements.elite:Hide()
        end
    end

    local function QueueClassificationRefresh(delay)
        if not Module.classificationRefreshFrame then
            Module.classificationRefreshFrame = CreateFrame("Frame")
        end

        local refreshFrame = Module.classificationRefreshFrame
        refreshFrame.delay = delay or 0.08
        refreshFrame.elapsed = 0
        refreshFrame.passes = 0
        refreshFrame.maxPasses = 3
        refreshFrame.targetGUID = UnitGUID(unitToken)

        refreshFrame:SetScript("OnUpdate", function(self, dt)
            self.elapsed = self.elapsed + dt
            if self.elapsed >= self.delay then
                self.elapsed = 0
                self.passes = self.passes + 1

                if UnitExists(unitToken) then
                    local currentGUID = UnitGUID(unitToken)
                    if (not self.targetGUID) or (not currentGUID) or currentGUID == self.targetGUID then
                        UpdateClassification()
                    else
                        -- Unit swapped again during delay; apply once for the new unit.
                        UpdateClassification()
                    end
                elseif frameElements.elite then
                    frameElements.elite:Hide()
                end

                if self.passes >= self.maxPasses then
                    self:SetScript("OnUpdate", nil)
                end
            end
        end)
    end

    -- ================================================================
    -- NAME BACKGROUND
    -- ================================================================

    local function UpdateNameBackground()
        if not NameBackground then return end
        if not UnitExists(unitToken) then
            NameBackground:Hide()
            return
        end

        -- Check if name background is disabled in config
        local config = GetConfig()
        if config and config.show_name_background == false then
            NameBackground:Hide()
            return
        end

        local r, g, b
        local isTapDenied = false
        -- Tap-denied check (target only)
        if opts.hasTapDenied
           and UnitIsTapped(unitToken)
           and not UnitIsTappedByPlayer(unitToken) then
            r, g, b = 1, 1, 1
            isTapDenied = true
        else
            r, g, b = UnitSelectionColor(unitToken)
        end

        local colorKey = isTapDenied and "green" or ResolveNameBackgroundColorKey(r, g, b)
        local coords = NAME_BG_TEX_COORDS[colorKey] or NAME_BG_TEX_COORDS.yellow

        NameBackground:SetTexture(NAME_BG_PTR_TEXTURE)
        NameBackground:SetTexCoord(unpack(coords))
        if isTapDenied then
            NameBackground:SetBlendMode("BLEND")
        else
            NameBackground:SetBlendMode("ADD")
        end
        if NameBackground.SetDesaturated then
            NameBackground:SetDesaturated(isTapDenied)
        end

        if isTapDenied then
            if opts.nameVertexAlpha then
                NameBackground:SetVertexColor(0.08, 0.08, 0.08, opts.nameVertexAlpha)
            else
                NameBackground:SetVertexColor(0.08, 0.08, 0.08, 1)
            end
        else
            if opts.nameVertexAlpha then
                NameBackground:SetVertexColor(1, 1, 1, opts.nameVertexAlpha)
            else
                NameBackground:SetVertexColor(1, 1, 1, 1)
            end
        end

        NameBackground:Show()
    end

    -- ================================================================
    -- FRAME INITIALIZATION
    -- ================================================================

    local function InitializeFrame()
        if Module.configured then return end
        if not BlizzFrame then return end

        -- ---- Create editor overlay ----
        if not Module.overlay then
            Module.overlay = addon.CreateUIFrame(
                opts.overlaySize[1], opts.overlaySize[2],
                namePrefix .. "Frame")

            addon:RegisterEditableFrame({
                name       = widgetKey,
                frame      = Module.overlay,
                blizzardFrame = BlizzFrame,
                configPath = {"widgets", widgetKey},
                hasTarget  = ShouldBeVisible,
                showTest   = ShowFrameTest,
                hideTest   = HideFrameTest,
                onHide     = function() ApplyWidgetPosition() end,
                module     = Module,
            })
        end

        -- ---- Hide Blizzard elements ----
        if opts.hideListFn then
            for _, element in ipairs(opts.hideListFn()) do
                if element then
                    element:SetAlpha(0)
                    element:Hide()
                end
            end
        end

        -- ---- Create background texture ----
        if not frameElements.background then
            frameElements.background = BlizzFrame:CreateTexture(
                "DragonUI_" .. namePrefix .. "BG", "BACKGROUND", nil, -7)
            frameElements.background:SetTexture(TEXTURES.BACKGROUND)
            frameElements.background:SetPoint(
                "TOPLEFT", BlizzFrame, "TOPLEFT", 0, -8)
        end

        -- ---- Create border+elite frame (above health/mana bars) ----
        -- Bars are child frames at BlizzFrame level (+0), so they render above
        -- BlizzFrame's own textures. Border sits at +1, elite at +2 on top of border.
        if not frameElements.borderFrame then
            local bf = CreateFrame("Frame", nil, BlizzFrame)
            bf:SetAllPoints(BlizzFrame)
            bf:SetFrameLevel(BlizzFrame:GetFrameLevel() + 1)
            frameElements.borderFrame = bf
        end
        if not frameElements.border then
            frameElements.border = frameElements.borderFrame:CreateTexture(
                "DragonUI_" .. namePrefix .. "Border", "OVERLAY", nil, 5)
            frameElements.border:SetTexture(TEXTURES.BORDER)
            frameElements.border:SetPoint(
                "TOPLEFT", frameElements.background, "TOPLEFT", 0, 0)
        end

        -- ---- Create elite decoration (above border) ----
        if not frameElements.eliteFrame then
            local ef = CreateFrame("Frame", nil, BlizzFrame)
            ef:SetAllPoints(BlizzFrame)
            ef:SetFrameLevel(BlizzFrame:GetFrameLevel() + 2)
            frameElements.eliteFrame = ef
        end
        if not frameElements.elite then
            frameElements.elite = frameElements.eliteFrame:CreateTexture(
                "DragonUI_" .. namePrefix .. "Elite", "ARTWORK", nil, 1)
            frameElements.elite:SetTexture(TEXTURES.BOSS)
            frameElements.elite:Hide()
        end

        local raidTargetIcon = _G[namePrefix .. "FrameTextureFrameRaidTargetIcon"]
        if raidTargetIcon and raidTargetIcon.SetDrawLayer then
            raidTargetIcon:SetDrawLayer("OVERLAY", 7)
        end

        local pvpIcon = _G[namePrefix .. "FrameTextureFramePVPIcon"]
        if pvpIcon and pvpIcon.SetDrawLayer then
            pvpIcon:SetDrawLayer("OVERLAY", 7)
        end

        -- Raise FrameTextureFrame above eliteFrame (+2) so raid markers and PVP icon
        -- always render on top of all decorations.
        local textureFrame = _G[namePrefix .. "FrameTextureFrame"]
        if textureFrame and textureFrame.SetFrameLevel then
            textureFrame:SetFrameLevel(BlizzFrame:GetFrameLevel() + 3)
        end

        -- ---- Create threat numeric indicator ----
        if not frameElements.threatNumeric then
            local numeric = CreateFrame("Frame",
                "DragonUI" .. namePrefix .. "NumericalThreat", BlizzFrame)
            numeric:SetFrameStrata("HIGH")
            numeric:SetFrameLevel(BlizzFrame:GetFrameLevel() + 10)
            numeric:SetSize(71, 13)
            numeric:SetPoint("BOTTOM", BlizzFrame, "TOP", -45, -20)
            numeric:Hide()

            local bg = numeric:CreateTexture(nil, "ARTWORK")
            bg:SetTexture(TEXTURES.THREAT_NUMERIC)
            bg:SetTexCoord(0.927734375, 0.9970703125, 0.3125, 0.337890625)
            bg:SetAllPoints()

            numeric.text = numeric:CreateFontString(
                nil, "OVERLAY", "GameFontNormalSmall")
            numeric.text:SetPoint("CENTER", 0, 1)
            numeric.text:SetFont(UF.DEFAULT_FONT, 10)
            numeric.text:SetShadowOffset(1, -1)

            frameElements.threatNumeric = numeric
        end

        -- ---- Configure name background ----
        if NameBackground then
            ApplyNameBackgroundLayout()
            NameBackground:SetTexture(NAME_BG_PTR_TEXTURE)
            NameBackground:SetTexCoord(unpack(NAME_BG_TEX_COORDS.green))
            NameBackground:SetBlendMode("ADD")
            if NameBackground.SetDesaturated then
                NameBackground:SetDesaturated(false)
            end
            NameBackground:SetVertexColor(1, 1, 1, 1)
            NameBackground:SetDrawLayer("BORDER", 1)
            if opts.nameFrameAlpha then
                NameBackground:SetAlpha(opts.nameFrameAlpha)
            end
        end

        -- ---- Configure portrait ----
        Portrait:ClearAllPoints()
        Portrait:SetSize(56, 56)
        Portrait:SetPoint("TOPRIGHT", BlizzFrame, "TOPRIGHT", -47, -15)
        Portrait:SetDrawLayer("ARTWORK", 0)

        -- TargetFrame's OnLoad cuts 96px off its left hit rect; undo it so the button covers the bars.
        BlizzFrame:SetHitRectInsets(0, 40, 10, 20)

        -- ---- Configure health bar ----
        -- Frame level -1 keeps bar fills below portrait area (level 0)
        -- so the mana bar overlap doesn't render on top of the portrait.
        HealthBar:ClearAllPoints()
        HealthBar:SetSize(125, 20)
        HealthBar:SetPoint("RIGHT", Portrait, "LEFT", -1, 0)
        HealthBar:SetFrameLevel(BlizzFrame:GetFrameLevel())

        -- ---- Configure power bar ----
        ManaBar:ClearAllPoints()
        ManaBar:SetSize(132, 9.5)
        ManaBar:SetPoint("RIGHT", Portrait, "LEFT", 6.5, -16.5)
        ManaBar:SetFrameLevel(BlizzFrame:GetFrameLevel())

        -- ---- Configure text elements ----
        if NameText then
            NameText:ClearAllPoints()
            NameText:SetPoint("BOTTOM", HealthBar, "TOP", 10, 3)
            NameText:SetDrawLayer("OVERLAY", 2)
            if opts.nameFontSize then
                local font, _, flags = NameText:GetFont()
                if font and flags then
                    NameText:SetFont(font, opts.nameFontSize, flags)
                end
            end
        end

        if LevelText then
            LevelText:ClearAllPoints()
            LevelText:SetPoint("BOTTOMRIGHT", HealthBar, "TOPLEFT", 18, 3)
            LevelText:SetDrawLayer("OVERLAY", 2)
            if opts.levelFontSize then
                local font, _, flags = LevelText:GetFont()
                if font and flags then
                    LevelText:SetFont(font, opts.levelFontSize, flags)
                end
            end
        end
        if HighLevelTexture and HealthBar then
            HighLevelTexture:ClearAllPoints()
            HighLevelTexture:SetPoint("BOTTOMRIGHT", HealthBar, "TOPLEFT", 18, 0)
        end

        if DeadText then
            DeadText:ClearAllPoints()
            DeadText:SetPoint("CENTER", HealthBar, "CENTER", opts.deadTextOffsetX or 0, opts.deadTextOffsetY or 0)
            if DeadText.SetDrawLayer then
                DeadText:SetDrawLayer("OVERLAY", 2)
            end
        end

        -- ---- Setup bar hooks ----
        SetupBarHooks()

        -- Hook Blizzard classification updates so decoration refreshes
        -- whenever the client receives updated unit data
        if not BlizzFrame.DragonUI_ClassificationHook then
            hooksecurefunc("TargetFrame_CheckClassification", function(self, forceNormal)
                if self == BlizzFrame then
                    UpdateClassification()
                end
            end)
            BlizzFrame.DragonUI_ClassificationHook = true
        end

        -- ---- Apply config (scale + position) ----
        local config = GetConfig()
        if not InCombatLockdown() then
            BlizzFrame:SetClampedToScreen(false)
            BlizzFrame:SetScale(config.scale or 1)
        end
        ApplyWidgetPosition()

        Module.configured = true

        -- ---- After-init callback (frame-specific hooks) ----
        if opts.afterInit then
            opts.afterInit({
                Module              = Module,
                frameElements       = frameElements,
                BlizzFrame          = BlizzFrame,
                GetConfig           = GetConfig,
                updateCache         = updateCache,
                UpdateClassification = UpdateClassification,
                Portrait            = Portrait,
                TEXTURES            = TEXTURES,
                InitializeFrame     = InitializeFrame,
            })
        end

        -- ---- ShowTest / HideTest (editor mode) ----
        if not BlizzFrame.ShowTest then
            BlizzFrame.ShowTest = function(self)
                self:Show()
                self:SetFrameStrata("MEDIUM")
                self:SetFrameLevel(10)

                -- Force layout for frames that need it (target)
                if opts.forceLayoutOnUnitChange then
                    ForceReapplyLayout()
                end

                -- Custom textures
                if frameElements.background then
                    frameElements.background:Show()
                end
                if frameElements.border then
                    frameElements.border:Show()
                end

                -- Player portrait
                if Portrait then
                    SetPortraitTexture(Portrait, "player")
                end

                -- Name background with player color
                if NameBackground then
                    local r, g, b = UnitSelectionColor("player")
                    local colorKey = ResolveNameBackgroundColorKey(r, g, b)
                    local coords = NAME_BG_TEX_COORDS[colorKey] or NAME_BG_TEX_COORDS.yellow
                    NameBackground:SetTexture(NAME_BG_PTR_TEXTURE)
                    NameBackground:SetTexCoord(unpack(coords))
                    NameBackground:SetBlendMode("ADD")
                    if NameBackground.SetDesaturated then
                        NameBackground:SetDesaturated(false)
                    end
                    if opts.nameVertexAlpha then
                        NameBackground:SetVertexColor(1, 1, 1, opts.nameVertexAlpha)
                    else
                        NameBackground:SetVertexColor(1, 1, 1, 1)
                    end
                    NameBackground:Show()
                end

                -- Name & level text (preserve original color)
                if NameText then
                    if not NameText.originalColor then
                        local r, g, b, a = NameText:GetTextColor()
                        NameText.originalColor = {r, g, b, a}
                    end
                    NameText:SetText(UnitName("player"))
                end
                if LevelText then
                    if not LevelText.originalColor then
                        local r, g, b, a = LevelText:GetTextColor()
                        LevelText.originalColor = {r, g, b, a}
                    end
                    LevelText:SetText(UnitLevel("player"))
                end

                -- Health bar with class color system
                if HealthBar then
                    local curHP  = UnitHealth("player")
                    local maxHP  = UnitHealthMax("player")
                    HealthBar:SetMinMaxValues(0, maxHP)
                    HealthBar:SetValue(curHP)

                    local tex = HealthBar:GetStatusBarTexture()
                    if tex then
                        local cfg = GetConfig()
                        if cfg.classcolor then
                            tex:SetTexture(
                                TEXTURES.BAR_PREFIX .. "Health-Status")
                            local _, cls = UnitClass("player")
                            local clr = RAID_CLASS_COLORS[cls]
                            if clr then
                                tex:SetVertexColor(
                                    clr.r, clr.g, clr.b, 1)
                            else
                                tex:SetVertexColor(1, 1, 1, 1)
                            end
                        else
                            tex:SetTexture(
                                TEXTURES.BAR_PREFIX .. "Health")
                            tex:SetVertexColor(1, 1, 1, 1)
                        end
                        if maxHP > 0 then
                            tex:SetTexCoord(0, curHP / maxHP, 0, 1)
                        end
                    end
                    HealthBar:Show()
                end

                -- Power bar with custom texture
                if ManaBar then
                    local pType    = UnitPowerType("player")
                    local curPwr   = UnitPower("player", pType)
                    local maxPwr   = UnitPowerMax("player", pType)
                    ManaBar:SetMinMaxValues(0, maxPwr)
                    ManaBar:SetValue(curPwr)

                    local tex = ManaBar:GetStatusBarTexture()
                    if tex then
                        local pName = POWER_MAP[pType] or "Mana"
                        tex:SetTexture(TEXTURES.BAR_PREFIX .. pName)
                        tex:SetDrawLayer("ARTWORK", 1)
                        tex:SetVertexColor(1, 1, 1, 1)
                        if maxPwr > 0 then
                            tex:SetTexCoord(0, curPwr / maxPwr, 0, 1)
                        end
                    end
                    ManaBar:Show()
                end

                -- Elite decoration
                if frameElements.elite then
                    local classification = UnitClassification("player")
                    local pName   = UnitName("player")
                    local eCoords = nil

                    if pName and UF.FAMOUS_NPCS[pName] then
                        eCoords = BOSS_COORDS.elite
                    elseif classification
                           and classification ~= "normal" then
                        eCoords = BOSS_COORDS[classification]
                                  or BOSS_COORDS.elite
                    end

                    if eCoords then
                        frameElements.elite:SetTexCoord(
                            eCoords[1], eCoords[2],
                            eCoords[3], eCoords[4])
                        frameElements.elite:SetSize(
                            eCoords[5], eCoords[6])
                        frameElements.elite:ClearAllPoints()
                        frameElements.elite:SetPoint(
                            "CENTER", Portrait, "CENTER",
                            eCoords[7], eCoords[8])
                        frameElements.elite:Show()
                    else
                        frameElements.elite:Hide()
                    end
                end

                -- Hide threat in test mode
                if frameElements.threatNumeric then
                    frameElements.threatNumeric:Hide()
                end
            end

            BlizzFrame.HideTest = function(self)
                self:SetFrameStrata("LOW")
                self:SetFrameLevel(1)

                if NameText and NameText.originalColor then
                    NameText:SetVertexColor(
                        NameText.originalColor[1],
                        NameText.originalColor[2],
                        NameText.originalColor[3],
                        NameText.originalColor[4])
                end
                if LevelText and LevelText.originalColor then
                    LevelText:SetVertexColor(
                        LevelText.originalColor[1],
                        LevelText.originalColor[2],
                        LevelText.originalColor[3],
                        LevelText.originalColor[4])
                end

                if not UnitExists(unitToken) then
                    self:Hide()
                end
            end
        end
    end -- InitializeFrame

    -- ================================================================
    -- EVENT HANDLING
    -- ================================================================

    local function OnEvent(self, event, ...)
        if event == "ADDON_LOADED" then
            local name = ...
            if name == "DragonUI" and not Module.initialized then
                Module.initialized = true
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            InitializeFrame()
            if opts.forceLayoutOnUnitChange then
                StartPositionStabilizer(1.2)
            end

            -- Setup TextSystem
            if addon.TextSystem and not Module.textSystem then
                Module.textSystem = addon.TextSystem.SetupFrameTextSystem(
                    configKey, unitToken, BlizzFrame, HealthBar,
                    ManaBar, namePrefix .. "Frame")
            end

            if UnitExists(unitToken) then
                if opts.forceLayoutOnUnitChange then
                    ForceReapplyLayout()
                end
                UpdateNameBackground()
                UpdateClassification()
                QueueClassificationRefresh(0.12)
                UpdateThreat()
                if Module.textSystem then Module.textSystem.update() end
            end

        elseif event == opts.unitChangedEvent then
            -- Unit changed (target/focus) — clear throttle caches so first update is immediate
            updateCache.lastColorFrame = nil
            updateCache.lastPortraitClass = nil
            if UnitExists(unitToken) and opts.forceLayoutOnUnitChange then
                ForceReapplyLayout()
            end
            UpdateNameBackground()
            UpdateClassification()
            QueueClassificationRefresh(0.08)
            UpdateThreat()
            UpdateHealthBarColor()
            UpdateClassPortrait()
            if Module.textSystem then Module.textSystem.update() end

        elseif event == "UNIT_MODEL_CHANGED"
            or event == "UNIT_PORTRAIT_UPDATE" then
            local unit = ...
            if unit == unitToken and UnitExists(unitToken) then
                updateCache.lastPortraitClass = nil
                UpdateClassPortrait()

                if event == "UNIT_MODEL_CHANGED" then
                    UpdateClassification()
                    UpdateHealthBarColor()
                    if Module.textSystem then Module.textSystem.update() end
                end
            end

        elseif event == "UNIT_CLASSIFICATION_CHANGED" then
            local unit = ...
            if unit == unitToken then
                UpdateClassification()
                QueueClassificationRefresh(0.05)
            end

        elseif event == "UNIT_THREAT_SITUATION_UPDATE"
            or event == "UNIT_THREAT_LIST_UPDATE" then
            UpdateThreat()

        elseif event == "UNIT_FACTION" then
            local unit = ...
            if unit == unitToken then UpdateNameBackground() end

        elseif event == "UNIT_DISPLAYPOWER" then
            local unit = ...
            if unit == unitToken and UnitExists(unitToken) then
                ForceUpdatePowerBar()
                UpdateClassification()
                UpdateHealthBarColor()
                if Module.textSystem then Module.textSystem.update() end
            end

        elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            local unit = ...
            if unit == unitToken and UnitExists(unitToken)
               and Module.textSystem then
                Module.textSystem.update()
            end

        elseif POWER_EVENTS[event] then
            local unit = ...
            if unit == unitToken and UnitExists(unitToken) then
                ForceUpdatePowerBar()
                if Module.textSystem then Module.textSystem.update() end
            end

        else
            -- Forward unhandled events to per-module handler
            if opts.extraEventHandler then
                opts.extraEventHandler(
                    event, unitToken,
                    UpdateClassification, UpdateHealthBarColor,
                    ForceUpdatePowerBar, Module.textSystem, ...)
            end
        end
    end

    -- ---- Register events ----
    if not Module.eventsFrame then
        Module.eventsFrame = CreateFrame("Frame")
        local ef = Module.eventsFrame
        ef:RegisterEvent("ADDON_LOADED")
        ef:RegisterEvent("PLAYER_ENTERING_WORLD")
        ef:RegisterEvent(opts.unitChangedEvent)
        ef:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
        ef:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
        ef:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
        ef:RegisterEvent("UNIT_FACTION")
        ef:RegisterEvent("UNIT_HEALTH")
        ef:RegisterEvent("UNIT_MAXHEALTH")
        for ev in pairs(POWER_EVENTS) do
            ef:RegisterEvent(ev)
        end
        ef:RegisterEvent("UNIT_DISPLAYPOWER")

        -- Register additional per-module events
        if opts.extraEvents then
            for _, ev in ipairs(opts.extraEvents) do
                ef:RegisterEvent(ev)
            end
        end

        ef:SetScript("OnEvent", OnEvent)
    end

    -- ================================================================
    -- PUBLIC API: Refresh / Reset
    -- ================================================================

    -- Wrap the container so castbar.lua's own Show/Hide/alpha fades never fight our visibility state.
    local castbarWrapper

    -- Target/Focus share one visibility toggle with their ToT/ToF and cast bar, anchored or not.
    local function SyncVisibilityFade()
        if not addon.VisibilityFade then return end

        -- Skip native spellbar: castbar.lua already hides it, fading it here undid that.
        local extraFrames, hoverFrames = {}, { BlizzFrame }
        if configKey == "target" then
            if _G.TargetFrameToT then table.insert(extraFrames, _G.TargetFrameToT); table.insert(hoverFrames, _G.TargetFrameToT) end
        elseif configKey == "focus" then
            if _G.FocusFrameToT then table.insert(extraFrames, _G.FocusFrameToT); table.insert(hoverFrames, _G.FocusFrameToT) end
        end

        local castbarFrames = addon.CastbarModule and addon.CastbarModule.frames
        local castbarContainer = castbarFrames and castbarFrames[configKey] and castbarFrames[configKey].container
        if castbarContainer then
            if not castbarWrapper then
                castbarWrapper = CreateFrame("Frame", nil, UIParent)
            end
            if castbarContainer:GetParent() ~= castbarWrapper then
                castbarContainer:SetParent(castbarWrapper)
            end
            table.insert(extraFrames, castbarWrapper)
            table.insert(hoverFrames, castbarContainer)
        end

        addon.VisibilityFade.Register(configKey, BlizzFrame, {
            frames = extraFrames,
            dbTable = GetConfig,
            hoverFrames = hoverFrames,
            clickThrough = true,
        })
        addon.VisibilityFade.Update(configKey)
    end

    local function RefreshFrame()
        if not Module.configured then
            InitializeFrame()
        end

        local config = GetConfig()
        if not InCombatLockdown() then
            BlizzFrame:SetScale(config.scale or 1)
        end

        ApplyWidgetPosition()

        if UnitExists(unitToken) then
            if opts.forceLayoutOnUnitChange then
                ForceReapplyLayout()
            end
            if DeadText and HealthBar then
                DeadText:ClearAllPoints()
                DeadText:SetPoint("CENTER", HealthBar, "CENTER", opts.deadTextOffsetX or 0, opts.deadTextOffsetY or 0)
            end
            UpdateNameBackground()
            UpdateClassification()
            UpdateThreat()
            UpdateHealthBarColor()
            ForceUpdatePowerBar()
            if Module.textSystem then Module.textSystem.update() end
        end

        SyncVisibilityFade()
    end

    local function ResetFrame()
        local defaults = addon.defaults
            and addon.defaults.profile.unitframe[configKey] or {}
        for key, value in pairs(defaults) do
            addon:SetConfigValue("unitframe", configKey, key, value)
        end

        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end
        addon.db.profile.widgets[widgetKey] = {
            anchor = defaultPos.anchor,
            posX   = defaultPos.posX,
            posY   = defaultPos.posY,
        }

        local config = GetConfig()
        if not InCombatLockdown() then
            BlizzFrame:ClearAllPoints()
            BlizzFrame:SetScale(config.scale or 1)
        end
        ApplyWidgetPosition()
    end

    -- ================================================================
    -- EDITOR MODE SUPPORT
    -- ================================================================

    function Module:LoadDefaultSettings()
        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end
        addon.db.profile.widgets[widgetKey] = {
            anchor = defaultPos.anchor,
            posX   = defaultPos.posX,
            posY   = defaultPos.posY,
        }
    end

    function Module:UpdateWidgets()
        if not addon.db or not addon.db.profile.widgets
           or not addon.db.profile.widgets[widgetKey] then
            self:LoadDefaultSettings()
            return
        end
        ApplyWidgetPosition()
    end

    -- ================================================================
    -- EXTRA HOOKS
    -- ================================================================

    if opts.setupExtraHooks then
        opts.setupExtraHooks(UpdateHealthBarColor, UpdateClassPortrait)
    end

    -- ================================================================
    -- RETURN API
    -- ================================================================

    return {
        Refresh              = RefreshFrame,
        Reset                = ResetFrame,
        anchor               = function() return Module.overlay end,
        Module               = Module,
        -- Exposed for external use (options panel, wrapper modules)
        GetConfig            = GetConfig,
        UpdateHealthBarColor = UpdateHealthBarColor,
        UpdateClassPortrait  = UpdateClassPortrait,
        UpdateThreat         = UpdateThreat,
        UpdateClassification = UpdateClassification,
        UpdateNameBackground = UpdateNameBackground,
        ForceUpdatePowerBar  = ForceUpdatePowerBar,
        frameElements        = frameElements,
        updateCache          = updateCache,
    }
end
