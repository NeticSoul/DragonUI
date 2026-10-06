-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

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
    local POWER_MAP   = UF.POWER_MAP

    local NAME_BG_COLOR_PALETTE = {
        blue = {0.0, 0.44, 1.0},
        green = {0.0, 1.0, 0.0},
        orange = {1.0, 0.5, 0.0},
        red = {1.0, 0.0, 0.0},
        yellow = {1.0, 1.0, 0.0},
    }

    local function ApplyNameBackgroundLayout()
        if not NameBackground or not HealthBar then return end

        local piece = UF.GetFrameSkin().target.nameBackground
        NameBackground:ClearAllPoints()
        NameBackground:SetPoint("BOTTOMLEFT", HealthBar, "TOPLEFT", piece.x, piece.y)
        NameBackground:SetSize(piece.w, piece.h)
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
    -- SKIN (art and bar geometry from uf_skins.lua)
    -- ================================================================

    local function ApplyBarLayout(bar, layout)
        bar:ClearAllPoints()
        bar:SetSize(layout.w, layout.h)
        bar:SetPoint("RIGHT", Portrait, "LEFT", layout.x, layout.y)
        bar:SetFrameLevel(BlizzFrame:GetFrameLevel())
    end

    local function ApplyPortraitLayout()
        local layout = UF.GetFrameSkin().target.portrait
        Portrait:ClearAllPoints()
        Portrait:SetSize(layout.w, layout.h)
        Portrait:SetPoint("TOPRIGHT", BlizzFrame, "TOPRIGHT", layout.x, layout.y)
    end

    -- Bars anchor to the portrait, so both go together; the dragons and the PvP badge follow it too.
    local function ApplyBarsLayout()
        local skin = UF.GetFrameSkin().target
        if Portrait then
            ApplyPortraitLayout()
        end
        if HealthBar then
            ApplyBarLayout(HealthBar, skin.bars.health)
        end
        if ManaBar then
            ApplyBarLayout(ManaBar, skin.bars.mana)
        end
        Module.appliedLayout = skin
    end

    local skullHome, levelTextSize, nameHome

    -- Blizzard owns the name width (FocusFrame_SetSmallSize), so only what the Forever spot changed is undone.
    local function ApplyNameLayout()
        if not NameText or not HealthBar then return end
        local name = UF.GetNameSpot("target")
        NameText:ClearAllPoints()
        if name and frameElements.background then
            if not nameHome then
                nameHome = { NameText:GetWidth(), NameText:GetJustifyH() }
            end
            NameText:SetPoint("LEFT", frameElements.background, "TOPLEFT", name.x, name.y)
            NameText:SetWidth(name.w)
            NameText:SetJustifyH(UF.GetNameSpotJustify())
        else
            NameText:SetPoint("BOTTOM", HealthBar, "TOP", 10, 3)
            if nameHome then
                NameText:SetWidth(nameHome[1])
                NameText:SetJustifyH(nameHome[2])
                nameHome = nil
            end
        end
    end

    local function ApplyLevelLayout()
        local circle, levelFrame = frameElements.levelCircle, frameElements.levelFrame
        local onCircle = circle and UF.ApplyLevelCircle(circle, UF.GetLevelSpot("target"), frameElements.background)
        local textHome = levelFrame and levelFrame:GetParent()
        if levelFrame then
            -- Forever draws the level over the PvP badge, which sits one level above the text frame.
            levelFrame:SetFrameLevel(textHome:GetFrameLevel() + 2)
        end
        if LevelText then
            LevelText:ClearAllPoints()
            if onCircle then
                LevelText:SetParent(levelFrame)
                LevelText:SetPoint("CENTER", circle, "CENTER", 0, UF.GetLevelTextY(levelFrame))
            else
                if textHome then
                    LevelText:SetParent(textHome)
                end
                LevelText:SetPoint("BOTTOMRIGHT", HealthBar, "TOPLEFT", 18, 3)
            end
            LevelText:SetDrawLayer("OVERLAY", 2)
            local font, size, flags = LevelText:GetFont()
            levelTextSize = levelTextSize or size
            if font then
                LevelText:SetFont(font, onCircle and UF.LEVEL_ART.fontSize or opts.levelFontSize or levelTextSize, flags)
            end
        end
        if HighLevelTexture and HealthBar then
            if not skullHome then
                skullHome = { HighLevelTexture:GetTexture(), HighLevelTexture:GetWidth(), HighLevelTexture:GetHeight() }
            end
            if onCircle then
                HighLevelTexture:SetParent(levelFrame)
            elseif textHome then
                HighLevelTexture:SetParent(textHome)
            end
            HighLevelTexture:SetDrawLayer("ARTWORK")
            local skull = onCircle and UF.LEVEL_ART.skull
            HighLevelTexture:SetTexture(skull and UF.LEVEL_ART.file or skullHome[1])
            if skull then
                HighLevelTexture:SetTexCoord(unpack(skull.tc))
            else
                HighLevelTexture:SetTexCoord(0, 1, 0, 1)
            end
            HighLevelTexture:SetSize(skull and skull.w or skullHome[2], skull and skull.h or skullHome[3])
            HighLevelTexture:ClearAllPoints()
            if onCircle then
                HighLevelTexture:SetPoint("CENTER", circle, "CENTER", 0, 0)
            else
                HighLevelTexture:SetPoint("BOTTOMRIGHT", HealthBar, "TOPLEFT", 18, 0)
            end
        end
    end

    -- TargetFrame_Update repaints the icon (crown, or the guide under LFG restrictions) every time it runs.
    local function ApplyLeaderArt()
        local leader = BlizzFrame.leaderIcon
        if not leader then return end
        local style = UF.GetStatusIconStyle()
        local guide = HasLFGRestrictions and HasLFGRestrictions()
        local spot = UF.TARGET_ICONS[(style == "forever" and not guide) and "foreverLeader" or "leader"]
        leader:SetTexture(UF.STATUS_ICONS.file)
        leader:SetTexCoord(unpack(guide and UF.STATUS_ICONS.guide or UF.STATUS_ICONS.leader[style]))
        leader:SetSize(spot.w, spot.h)
        leader:ClearAllPoints()
        leader:SetPoint("TOPRIGHT", BlizzFrame, "TOPLEFT", spot.x, spot.y)
    end

    -- Retail's spots: the crown left of the portrait above the name strip, the raid mark centred on its top.
    local function ApplyStatusIcons()
        ApplyLeaderArt()
        local raidTargetIcon = _G[namePrefix .. "FrameTextureFrameRaidTargetIcon"]
        if raidTargetIcon and Portrait then
            raidTargetIcon:ClearAllPoints()
            raidTargetIcon:SetPoint("CENTER", Portrait, "TOP", 0, 0)
        end
    end

    local function ApplySkinTextures()
        local skin = UF.GetFrameSkin().target
        UF.ApplySkinPiece(frameElements.background, skin.background, "TOPLEFT", BlizzFrame, "TOPLEFT", 0, -8)
        UF.ApplySkinPiece(frameElements.border, skin.border, "TOPLEFT", frameElements.background, "TOPLEFT", 0, 0)
        ApplyNameBackgroundLayout()
        ApplyNameLayout()
        ApplyLevelLayout()
        ApplyStatusIcons()
    end

    -- ================================================================
    -- LAYOUT REAPPLY
    -- ================================================================
    -- Overrides Blizzard element repositioning that occurs for special
    -- units (bosses, vehicles). Used by target; not needed for focus.

    local function ForceReapplyLayout()
        ApplyBarsLayout()
        ApplyNameLayout()
        ApplyLevelLayout()
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
            -- Blizzard just redrew the portrait (e.g. focus on PARTY_MEMBERS_CHANGED), so the cache is stale.
            hooksecurefunc("UnitFramePortrait_Update", function(frame)
                if frame == BlizzFrame then
                    updateCache.lastPortraitClass = nil
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

    local function ShowDragon(kind)
        local file, left, right, top, bottom, place
        if kind then
            file, left, right, top, bottom, place = UF.GetDragon("target", kind)
        end
        if not file then
            frameElements.elite:Hide()
            return
        end
        frameElements.elite:SetTexture(file)
        frameElements.elite:SetDrawLayer("ARTWORK", 1)
        frameElements.elite:SetTexCoord(left, right, top, bottom)
        frameElements.elite:SetSize(place.w, place.h)
        frameElements.elite:ClearAllPoints()
        frameElements.elite:SetPoint("CENTER", Portrait, "CENTER", place.x, place.y)
        frameElements.elite:Show()
    end

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
        local kind = nil

        if classification == "worldboss" then
            kind = "boss"
        elseif classification == "elite" then
            kind = "elite"
        elseif classification == "rareelite" then
            kind = "rareelite"
        elseif classification == "rare" then
            kind = "rare"
        else
            -- Fallback: famous NPC or skull-level boss
            if name and UF.FAMOUS_NPCS[name] then
                kind = "elite"
                if opts.onFamousNpc then
                    opts.onFamousNpc(name, updateCache)
                end
            else
                local unitLevel = UnitLevel(unitToken)
                if unitLevel == -1 then
                    kind = "boss"
                end
            end
        end

        ShowDragon(kind)
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

    local function PaintNameBackground(r, g, b, tapDenied)
        local piece = UF.GetFrameSkin().target.nameBackground
        local tapped = tapDenied and piece.tapped
        local cell = piece.cells[tapped and tapped.cell or ResolveNameBackgroundColorKey(r, g, b)]
        local color = tapped and tapped.color or piece.color
        NameBackground:SetTexture(piece.file)
        NameBackground:SetTexCoord(unpack(cell or piece.cells.yellow))
        NameBackground:SetBlendMode(tapped and tapped.blend or piece.blend)
        if NameBackground.SetDesaturated then
            NameBackground:SetDesaturated(tapped and tapped.desaturate or false)
        end
        NameBackground:SetVertexColor(color[1], color[2], color[3], opts.nameVertexAlpha or 1)
    end

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

        PaintNameBackground(r, g, b, isTapDenied)
        NameBackground:Show()
    end

    -- ================================================================
    -- PVP ICON
    -- ================================================================

    local pvpBadge

    -- Runs after TargetFrame_CheckFaction, the only code that shows the icon; a small focus clears showPVP.
    local function ApplyPvPIconVisibility()
        local pvpIcon = BlizzFrame.pvpIcon
        if not pvpIcon then return end
        local config = GetConfig()
        local kind = BlizzFrame.showPVP and UnitExists(unitToken) and UF.GetPvPKind(unitToken)
        local shown = kind and config.show_pvp_icon ~= false
        UF.ApplyClassicPvPTexture(pvpIcon, kind)
        if not pvpBadge then
            -- Same frame as Blizzard's icon, so it draws over the portrait the same way.
            pvpBadge = UF.CreatePvPBadge(pvpIcon:GetParent(), "DragonUI_" .. namePrefix .. "PvPCircle")
        end
        local badge = UF.GetFrameSkin().target.pvp
        pvpBadge:ClearAllPoints()
        pvpBadge:SetPoint("TOP", frameElements.background or BlizzFrame, "TOPLEFT", badge.x, badge.y)
        local onBadge = shown and UF.GetPvPIconStyle(config) == "forever"
            and UF.ShowPvPBadge(pvpBadge, kind, badge.scale, true)
        if not onBadge then
            pvpBadge:Hide()
        end
        -- Alpha only: TargetFrame_CheckFaction owns Show/Hide, including the small focus that never shows it.
        pvpIcon:SetAlpha((shown and not onBadge) and 1 or 0)
    end

    -- ================================================================
    -- THREAT FLASH
    -- ================================================================

    -- Show/Hide and color stay with UnitFrame_UpdateThreatIndicator.
    local function ApplyThreatFlash()
        local flash = BlizzFrame.threatIndicator
        if not flash or not frameElements.eliteFrame then return end
        -- On eliteFrame like retail's: over the border, under the elite dragon.
        flash:SetParent(frameElements.eliteFrame)
        flash:SetDrawLayer("BACKGROUND")
        flash:SetTexture(TEXTURES.THREAT)
        flash:SetTexCoord(0, 376/512, 0, 134/256)
        local spot = UF.GetFrameSkin().target.flash
        flash:ClearAllPoints()
        flash:SetPoint("BOTTOMLEFT", BlizzFrame, "BOTTOMLEFT", spot.x, spot.y)
        flash:SetSize(188, 67)
    end

    -- ================================================================
    -- FRAME INITIALIZATION
    -- ================================================================

    local function InitializeFrame()
        if Module.configured then return end
        if not BlizzFrame then return end

        if InCombatLockdown() then
            if addon.CombatQueue then
                addon.CombatQueue:Add(configKey .. "_init_frame", InitializeFrame)
            end
            return
        end

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
        end
        -- Above the text frame (border, dragons) and the PvP badge; text and skull move in with the circle.
        if not frameElements.levelFrame then
            local lf = CreateFrame("Frame", nil, _G[namePrefix .. "FrameTextureFrame"])
            lf:SetAllPoints(BlizzFrame)
            frameElements.levelFrame = lf
            frameElements.levelCircle = lf:CreateTexture("DragonUI_" .. namePrefix .. "LevelCircle", "BACKGROUND")
            frameElements.levelCircle:Hide()
        end
        ApplySkinTextures()

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
            frameElements.elite:Hide()
        end
        ApplyThreatFlash()

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
            PaintNameBackground(0, 1, 0, false)
            NameBackground:SetDrawLayer("BORDER", 1)
            if opts.nameFrameAlpha then
                NameBackground:SetAlpha(opts.nameFrameAlpha)
            end
        end

        -- ---- Configure portrait ----
        ApplyPortraitLayout()
        Portrait:SetDrawLayer("ARTWORK", 0)

        -- TargetFrame's OnLoad cuts 96px off its left hit rect; undo it so the button covers the bars.
        BlizzFrame:SetHitRectInsets(0, 40, 10, 20)

        -- ---- Configure health bar ----
        -- Frame level -1 keeps bar fills below portrait area (level 0)
        -- so the mana bar overlap doesn't render on top of the portrait.
        ApplyBarsLayout()

        -- ---- Configure text elements ----
        if NameText then
            ApplyNameLayout()
            NameText:SetDrawLayer("OVERLAY", 2)
            if opts.nameFontSize then
                local font, _, flags = NameText:GetFont()
                if font and flags then
                    NameText:SetFont(font, opts.nameFontSize, flags)
                end
            end
        end

        if LevelText then
            LevelText:SetDrawLayer("OVERLAY", 2)
            if opts.levelFontSize then
                local font, _, flags = LevelText:GetFont()
                if font and flags then
                    LevelText:SetFont(font, opts.levelFontSize, flags)
                end
            end
        end
        ApplyLevelLayout()

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
                    ApplyThreatFlash()
                    UpdateClassification()
                end
            end)
            BlizzFrame.DragonUI_ClassificationHook = true
        end

        if not BlizzFrame.DragonUI_PvPIconHook then
            hooksecurefunc("TargetFrame_CheckFaction", function(self)
                if self == BlizzFrame then
                    ApplyPvPIconVisibility()
                end
            end)
            BlizzFrame.DragonUI_PvPIconHook = true
        end

        if not BlizzFrame.DragonUI_LeaderArtHook then
            hooksecurefunc("TargetFrame_Update", function(self)
                if self == BlizzFrame then
                    ApplyLeaderArt()
                end
            end)
            BlizzFrame.DragonUI_LeaderArtHook = true
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
                    PaintNameBackground(r, g, b, false)
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
                    local kind = nil

                    if pName and UF.FAMOUS_NPCS[pName] then
                        kind = "elite"
                    elseif classification
                           and classification ~= "normal" then
                        kind = (classification == "rare" or classification == "rareelite")
                               and classification or "elite"
                    end

                    ShowDragon(kind)
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

        if frameElements.border then
            ApplySkinTextures()
        end
        if Module.appliedLayout and Module.appliedLayout ~= UF.GetFrameSkin().target
                and not InCombatLockdown() then
            ApplyBarsLayout()
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

        ApplyPvPIconVisibility()
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
