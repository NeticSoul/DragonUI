--[[
  DragonUI - Small Frame Factory (small_frame.lua)

  Parameterized factory for compact companion unit frames (ToT, FoT).
  Each call to UF.SmallFrame.Create(opts) returns an independent module
  instance using closures.
]]

local _, addon = ...
local L = addon.L
local UF = addon.UF

-- Namespace for the factory
UF.SmallFrame = UF.SmallFrame or {}


-- ============================================================================
-- Factory function
-- ============================================================================
-- opts fields:
--   configKey         : string  "tot" or "fot" (database key)
--   unitToken         : string  "targettarget" or "focustarget"
--   parentUnit        : string  "target" or "focus"
--   unitEvent         : string  "PLAYER_TARGET_CHANGED" or "PLAYER_FOCUS_CHANGED"
--   unitTargetFilters : table   {"target", "player"} or {"focus"}
--   namePrefix        : string  "DragonUI_ToT" or "DragonUI_FoT"
--   frames            : table   { main, healthBar, manaBar, portrait, nameText,
--                                 blizzTexture, blizzBackground, debuff1, parent }
--   defaultAnchor       : string  (default "BOTTOMRIGHT")
--   defaultAnchorParent : string  (default "BOTTOMRIGHT")
--   defaultX            : number  default X offset for positioning
--   defaultY            : number  default Y offset for positioning
--   cvar                : string? "showTargetOfTarget" for ToT, nil for FoT
--   hideWhenParentIsPlayer : bool? Hide companion frame when parent unit is the player
--   extraInit           : func?   function(Module, config) — called at end of InitializeFrame
-- ============================================================================

function UF.SmallFrame.Create(opts)
    -- ========================================================================
    -- MODULE STATE
    -- ========================================================================

    local Module = {
        anchorFrame = nil,
        textSystem = nil,
        initialized = false,
        configured = false,
        eventsFrame = nil,
        retryFrame = nil,
        updateTypeHooked = false,
        portraitHooked = false,
        parentUpdateHooked = false,
    }

    local frames = opts.frames

    local frameElements = {
        background = nil,
        border = nil,
        borderFrame = nil,
        elite = nil,
        classPortraitBg = nil,
        classPortraitIcon = nil,
    }

    local updateCache = {
        lastHealthUpdate = 0,
        lastPowerUpdate = 0,
    }

    local pendingWidgetPositionUpdate = false
    local pendingVisibilityUpdate = false

    -- Visibility helpers (assigned below; declared early for hooks + mutual recursion)
    local ReconcileVisibility, RequestVisibilityRefresh, RequestVisibilityRefreshFromEvent


    -- ========================================================================
    -- CONFIG
    -- ========================================================================

    local function GetConfig()
        return UF.GetConfig(opts.configKey)
    end

    local function IsEnabled()
        return UF.IsEnabled(opts.configKey)
    end

    local function IsNativeVisibilityEnabled()
        if not opts.cvar then
            return true
        end
        return not (GetCVar and GetCVar(opts.cvar) == "0")
    end


    -- ========================================================================
    -- UNIT HELPERS
    -- ========================================================================

    local function GetUnit()
        if not UnitExists(opts.parentUnit) then
            return nil
        end
        if UnitExists(opts.unitToken) then
            return opts.unitToken
        end
        return nil
    end

    local function ShouldShow()
        if not IsNativeVisibilityEnabled() then
            return false
        end

        if not UnitExists(opts.parentUnit) then
            return false
        end

        -- Optional guard used by ToT: do not show when target is the player.
        if opts.hideWhenParentIsPlayer and UnitIsUnit(opts.parentUnit, "player") then
            return false
        end

        -- Always show if the companion unit exists
        if UnitExists(opts.unitToken) then
            return true
        end

        return false
    end


    -- ========================================================================
    -- CLASSIFICATION SYSTEM
    -- ========================================================================

    local function UpdateClassification()
        local unit = GetUnit()
        if not unit or not frameElements.elite then
            if frameElements.elite then
                frameElements.elite:Hide()
            end
            return
        end

        local classification = UnitClassification(unit)
        local coords = nil

        -- Check vehicle first
        if UnitVehicleSeatCount and UnitVehicleSeatCount(unit) > 0 then
            frameElements.elite:Hide()
            return
        end

    -- Determine classification and apply boss/elite/rare decoration
        if classification == "worldboss" or classification == "elite" then
            coords = UF.BOSS_COORDS.smallStyle.elite
        elseif classification == "rareelite" then
            coords = UF.BOSS_COORDS.smallStyle.rareelite
        elseif classification == "rare" then
            coords = UF.BOSS_COORDS.smallStyle.rare
        else
            -- Famous NPC override
            local name = UnitName(unit)
            if name and addon.unitframe and addon.unitframe.famous and addon.unitframe.famous[name] then
                coords = UF.BOSS_COORDS.smallStyle.elite
            end
        end

        if coords then
            frameElements.elite:SetTexture(UF.TEXTURES.smallStyle.BOSS)

            -- Horizontal flip for small frame decorations
            local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
            frameElements.elite:SetTexCoord(right, left, top, bottom)

            frameElements.elite:SetSize(51, 51)
            frameElements.elite:SetPoint("CENTER", frames.portrait, "CENTER", -4, -2)
            frameElements.elite:SetDrawLayer("OVERLAY", 11)
            frameElements.elite:Show()
            frameElements.elite:SetAlpha(1)
        else
            frameElements.elite:Hide()
        end
    end


    -- ========================================================================
    -- CLASS PORTRAIT
    -- ========================================================================

    local function RestoreSmallFramePortrait(portrait)
        if not portrait then return end
        if UnitExists(opts.unitToken) then
            SetPortraitTexture(portrait, opts.unitToken)
            portrait:SetTexCoord(0, 1, 0, 1)
        end
        portrait:SetAlpha(1)
    end

    local function UpdateSmallFrameClassPortrait()
        local config = GetConfig()
        if not config then return end

        local enabled = config.classPortrait
        local portrait = frames.portrait
        if not portrait or not frames.main then return end

        if not enabled then
            UF.UpdateClassPortrait(opts.unitToken, portrait, frames.main, frameElements, false)
            RestoreSmallFramePortrait(portrait)
            return
        end

        local useAlternative = config.alternativeClassIcons

        if not UF.UpdateClassPortrait(
            opts.unitToken,
            portrait,
            frames.main,
            frameElements,
            true,
            useAlternative
        ) then
            RestoreSmallFramePortrait(portrait)
        end
    end


    -- ========================================================================
    -- BAR HOOKS
    -- ========================================================================

    local function SetupBarHooks()
        -- ----------------------------------------------------------------
        -- Health bar hook
        -- ----------------------------------------------------------------
        if not frames.healthBar.DragonUI_Setup then
            local healthTexture = frames.healthBar:GetStatusBarTexture()
            if healthTexture then
                healthTexture:SetDrawLayer("ARTWORK", 1)
            end

            hooksecurefunc(frames.healthBar, "SetValue", function(self)
                if not UnitExists(opts.unitToken) then
                    return
                end

                local now = GetTime()
                if now - updateCache.lastHealthUpdate < 0.05 then
                    return
                end
                updateCache.lastHealthUpdate = now

                local texture = self:GetStatusBarTexture()
                if not texture then
                    return
                end

                local config = GetConfig()
                local texturePath

                -- Class color health bar
                if config.classcolor and UnitIsPlayer(opts.unitToken) then
                    texturePath = UF.TEXTURES.smallStyle.BAR_PREFIX .. "Health-Status"
                else
                    texturePath = UF.TEXTURES.smallStyle.BAR_PREFIX .. "Health"
                end

                -- Update texture
                if texture:GetTexture() ~= texturePath then
                    texture:SetTexture(texturePath)
                    texture:SetDrawLayer("ARTWORK", 1)
                end

                -- Update coords (clip to fill percentage)
                local min, max = self:GetMinMaxValues()
                local current = self:GetValue()
                if max > 0 and current then
                    texture:SetTexCoord(0, current / max, 0, 1)
                end

                -- Update vertex color
                if config.classcolor and UnitIsPlayer(opts.unitToken) then
                    local _, class = UnitClass(opts.unitToken)
                    local color = RAID_CLASS_COLORS[class]
                    if color then
                        texture:SetVertexColor(color.r, color.g, color.b)
                    else
                        texture:SetVertexColor(1, 1, 1)
                    end
                else
                    texture:SetVertexColor(1, 1, 1)
                end
            end)

            frames.healthBar.DragonUI_Setup = true
        end

        -- ----------------------------------------------------------------
        -- Power bar hook
        -- ----------------------------------------------------------------
        if not frames.manaBar.DragonUI_Setup then
            local powerTexture = frames.manaBar:GetStatusBarTexture()
            if powerTexture then
                powerTexture:SetDrawLayer("ARTWORK", 1)
            end

            hooksecurefunc(frames.manaBar, "SetValue", function(self)
                if not UnitExists(opts.unitToken) then
                    return
                end

                local now = GetTime()
                if now - updateCache.lastPowerUpdate < 0.05 then
                    return
                end
                updateCache.lastPowerUpdate = now

                local texture = self:GetStatusBarTexture()
                if not texture then
                    return
                end

                -- Update texture based on power type
                local powerType = UnitPowerType(opts.unitToken)
                local powerName = UF.POWER_MAP[powerType] or "Mana"
                local texturePath = UF.TEXTURES.smallStyle.BAR_PREFIX .. powerName

                if texture:GetTexture() ~= texturePath then
                    texture:SetTexture(texturePath)
                    texture:SetDrawLayer("ARTWORK", 1)
                end

                -- Update coords
                local min, max = self:GetMinMaxValues()
                local current = self:GetValue()
                if max > 0 and current then
                    texture:SetTexCoord(0, current / max, 0, 1)
                end

                -- Force white color (power bars don't use class color)
                texture:SetVertexColor(1, 1, 1)
            end)

            frames.manaBar.DragonUI_Setup = true
        end
    end


    -- ========================================================================
    -- ADDITIONAL HOOKS
    -- ========================================================================

    local function SetupAdditionalHooks()
        local function QueueWidgetPositionUpdate()
            if pendingWidgetPositionUpdate then
                return
            end
            if addon and addon.CombatQueue then
                pendingWidgetPositionUpdate = true
                addon.CombatQueue:Add(opts.configKey .. "_widget_position", function()
                    pendingWidgetPositionUpdate = false
                    Module:UpdateWidgets()
                end)
            end
        end

        local function ReapplyDetachedWidgetPositionIfNeeded()
            if not IsEnabled() then return end
            local config = GetConfig()
            if config and config.override then
                if InCombatLockdown() then
                    QueueWidgetPositionUpdate()
                    return
                end
                Module:UpdateWidgets()
            end
        end

        -- Hook UnitFrameManaBar_UpdateType to reapply textures on power type changes
        if not Module.updateTypeHooked then
            hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
                if manaBar == frames.manaBar and IsEnabled() and UnitExists(opts.unitToken) then
                    local texture = manaBar:GetStatusBarTexture()
                    if texture then
                        local powerType = UnitPowerType(opts.unitToken)
                        local powerName = UF.POWER_MAP[powerType] or "Mana"
                        texture:SetTexture(UF.TEXTURES.smallStyle.BAR_PREFIX .. powerName)
                        texture:SetDrawLayer("ARTWORK", 1)
                        texture:SetVertexColor(1, 1, 1)
                    end
                end
            end)
            Module.updateTypeHooked = true
        end

        -- Hook Show() to restore custom textures when Blizzard shows the frame
        if frames.main and not frames.main.DragonUI_ShowHook then
            hooksecurefunc(frames.main, "Show", function(self)
                if IsEnabled() and ShouldShow() then
                    if frameElements.background then
                        frameElements.background:Show()
                    end
                    if frameElements.border then
                        frameElements.border:Show()
                    end
                    UpdateClassification()
                end
            end)
            frames.main.DragonUI_ShowHook = true
        end

        -- Hook UnitFramePortrait_Update to reapply styles on portrait changes
        if not Module.portraitHooked then
            hooksecurefunc("UnitFramePortrait_Update", function(frame, unit)
                if frame == frames.main and IsEnabled() and UnitExists(opts.unitToken) then
                    if frameElements.background then frameElements.background:Show() end
                    if frameElements.border then frameElements.border:Show() end
                    UpdateClassification()
                    UpdateSmallFrameClassPortrait()
                end
            end)
            Module.portraitHooked = true
        end

        -- Sync visibility when Blizzard refreshes the parent unit frame (ToT/FoT
        -- updates run inside TargetFrame_Update / FocusFrame_Update).
        if not Module.parentUpdateHooked then
            if opts.parentUnit == "target" and type(TargetFrame_Update) == "function" then
                hooksecurefunc("TargetFrame_Update", function()
                    if IsEnabled() then
                        RequestVisibilityRefreshFromEvent()
                    end
                    ReapplyDetachedWidgetPositionIfNeeded()
                end)
                Module.parentUpdateHooked = true
            elseif opts.parentUnit == "focus" and type(FocusFrame_Update) == "function" then
                hooksecurefunc("FocusFrame_Update", function()
                    if IsEnabled() then
                        RequestVisibilityRefreshFromEvent()
                    end
                    ReapplyDetachedWidgetPositionIfNeeded()
                end)
                Module.parentUpdateHooked = true
            end
        end
    end


    -- ========================================================================
    -- FRAME INITIALIZATION
    -- ========================================================================

    local function InitializeFrame()
        if Module.configured then
            return
        end

        -- Defer entirely if in combat (secure frame modifications)
        if InCombatLockdown() then
            if addon and addon.CombatQueue then
                addon.CombatQueue:Add(opts.configKey .. "_initialize", InitializeFrame)
            end
            return
        end

        -- Disabled: hide and bail
        if not IsEnabled() then
            if frames.main then
                frames.main:Hide()
            end
            return
        end

        -- Verify frame exists
        if not frames.main then
            return
        end

        -- Get configuration
        local config = GetConfig()

        -- Ensure detached anchor has the latest saved widget position.
        -- ADDON_LOADED may have already fired before this module registered events.
        if config.override and Module.anchorFrame then
            Module:ApplyWidgetPosition()
        end

        -- Position frame: override (detached) or attached to parent
        frames.main:ClearAllPoints()
        if config.override and Module.anchorFrame then
            -- Detached mode: follow the free anchor frame
            frames.main:SetPoint("CENTER", Module.anchorFrame, "CENTER", 0, 0)
        else
            -- Attached mode: anchored to parent frame (default)
            frames.main:SetPoint(
                config.anchor or opts.defaultAnchor or "BOTTOMRIGHT",
                frames.parent,
                config.anchorParent or opts.defaultAnchorParent or "BOTTOMRIGHT",
                config.x or opts.defaultX or 0,
                config.y or opts.defaultY or 0
            )
        end
        frames.main:SetScale(config.scale or 1.0)

        -- Hide Blizzard default textures
        local toHide = { frames.blizzTexture, frames.blizzBackground }
        for _, element in ipairs(toHide) do
            if element then
                element:SetAlpha(0)
                element:Hide()
            end
        end

        -- Create custom background texture
        if not frameElements.background then
            frameElements.background = frames.main:CreateTexture(opts.namePrefix .. "BG", "BACKGROUND", nil, 0)
            frameElements.background:SetTexture(UF.TEXTURES.smallStyle.BACKGROUND)
            frameElements.background:SetPoint("LEFT", frames.portrait, "CENTER", -25 + 1, -9)
        end

        -- Create custom border texture
        if not frameElements.borderFrame then
            frameElements.borderFrame = CreateFrame("Frame", nil, frames.main)
            frameElements.borderFrame:SetAllPoints(frames.main)
            frameElements.borderFrame:EnableMouse(false)
        end

        if not frameElements.border then
            frameElements.border = frameElements.borderFrame:CreateTexture(opts.namePrefix .. "Border", "OVERLAY", nil, 1)
            frameElements.border:SetTexture(UF.TEXTURES.smallStyle.BORDER)
            frameElements.border:SetPoint("LEFT", frames.portrait, "CENTER", -25 + 1, -9)
            frameElements.border:Show()
            frameElements.border:SetAlpha(1)
        end

        -- Create elite decoration
        if not frameElements.elite then
            local eliteFrame = CreateFrame("Frame", opts.namePrefix .. "EliteFrame", frames.main)
            eliteFrame:SetFrameStrata("MEDIUM")
            eliteFrame:SetAllPoints(frames.portrait)

            frameElements.elite = eliteFrame:CreateTexture(opts.namePrefix .. "Elite", "OVERLAY", nil, 1)
            frameElements.elite:SetTexture(UF.TEXTURES.smallStyle.BOSS)
            frameElements.elite:Hide()
        end

        -- ----------------------------------------------------------------
        -- Configure health bar
        -- ----------------------------------------------------------------
        frames.healthBar:Hide()
        frames.healthBar:ClearAllPoints()
        frames.healthBar:SetParent(frames.main)
        frames.healthBar:SetFrameStrata("LOW")
        frames.healthBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
        frames.healthBar:GetStatusBarTexture():SetTexture(UF.TEXTURES.smallStyle.BAR_PREFIX .. "Health")
        -- Prevent Blizzard from changing our color (class-color aware)
        hooksecurefunc(frames.healthBar, "SetStatusBarColor", function(self)
            local texture = self:GetStatusBarTexture()
            if not texture then return end
            local config = GetConfig()
            if config.classcolor and UnitIsPlayer(opts.unitToken) then
                local _, class = UnitClass(opts.unitToken)
                local color = class and RAID_CLASS_COLORS[class]
                if color then
                    texture:SetVertexColor(color.r, color.g, color.b)
                else
                    texture:SetVertexColor(1, 1, 1, 1)
                end
            else
                texture:SetVertexColor(1, 1, 1, 1)
            end
        end)
        frames.healthBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        frames.healthBar:SetSize(70.5, 10)
        frames.healthBar:SetPoint("LEFT", frames.portrait, "RIGHT", 1 + 1, 1)
        frames.healthBar:Show()

        if frameElements.borderFrame then
            frameElements.borderFrame:SetFrameStrata(frames.healthBar:GetFrameStrata())
            frameElements.borderFrame:SetFrameLevel(frames.healthBar:GetFrameLevel() + 3)
            frameElements.borderFrame:Show()
        end

        -- ----------------------------------------------------------------
        -- Configure power bar
        -- ----------------------------------------------------------------
        frames.manaBar:Hide()
        frames.manaBar:ClearAllPoints()
        frames.manaBar:SetParent(frames.main)
        frames.manaBar:SetFrameStrata("LOW")
        frames.manaBar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
        frames.manaBar:GetStatusBarTexture():SetTexture(UF.TEXTURES.smallStyle.BAR_PREFIX .. "Mana")
        -- Prevent Blizzard from changing our color
        hooksecurefunc(frames.manaBar, "SetStatusBarColor", function(self)
            local texture = self:GetStatusBarTexture()
            if texture then texture:SetVertexColor(1, 1, 1, 1) end
        end)
        frames.manaBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
        frames.manaBar:SetSize(74, 7.5)
        frames.manaBar:SetPoint("LEFT", frames.portrait, "RIGHT", 1 - 2 - 1.5 + 1, 2 - 10 - 1)
        frames.manaBar:Show()

        -- ----------------------------------------------------------------
        -- Configure name text
        -- ----------------------------------------------------------------
        if frames.nameText then
            frames.nameText:ClearAllPoints()
            frames.nameText:SetPoint("LEFT", frames.portrait, "RIGHT", 3, 13)
            frames.nameText:SetParent(frames.main)
            frames.nameText:Show()
            local font, size, flags = frames.nameText:GetFont()
            if font and size then
                frames.nameText:SetFont(font, math.max(size, 10), flags)
            end
            frames.nameText:SetTextColor(1.0, 0.82, 0.0, 1.0)
            frames.nameText:SetDrawLayer("BORDER", 1)
            frames.nameText:SetWidth(65)
            frames.nameText:SetJustifyH("LEFT")
        end

        -- Force debuff positions
        if frames.debuff1 then
            frames.debuff1:ClearAllPoints()
            frames.debuff1:SetPoint("TOPLEFT", frames.main, "BOTTOMLEFT", 120, 35)
        end

        -- ----------------------------------------------------------------
        -- Setup hooks
        -- ----------------------------------------------------------------
        SetupBarHooks()
        SetupAdditionalHooks()

        -- Apply class portrait if enabled
        UpdateSmallFrameClassPortrait()

        -- Run caller-supplied extra initialization
        if opts.extraInit then
            opts.extraInit(Module, config)
        end

        -- Show the frame
        if not InCombatLockdown() then
            frames.main:Show()
        end

        Module.configured = true
    end


    -- ========================================================================
    -- EVENT HANDLING
    -- ========================================================================

    ReconcileVisibility = function()
        if InCombatLockdown() then
            Module.pendingVisibilityRefresh = true
            if addon and addon.CombatQueue then
                addon.CombatQueue:Add(opts.configKey .. "_visibility_refresh", function()
                    ReconcileVisibility()
                end)
            end
            return
        end

        Module.pendingVisibilityRefresh = nil

        if not IsEnabled() then
            Module.pendingHideVerify = nil
            if frames.main then
                frames.main:Hide()
            end
            return
        end

        if frames.main then
            if ShouldShow() then
                Module.pendingHideVerify = nil
                frames.main:Show()
            elseif not Module.pendingHideVerify then
                -- Defer hide one frame so a transient UnitExists("targettarget")
                -- false does not leave the frame hidden until the next event.
                Module.pendingHideVerify = true
                RequestVisibilityRefresh()
                return
            else
                Module.pendingHideVerify = nil
                frames.main:Hide()
            end
        end

        UpdateClassification()
        UpdateSmallFrameClassPortrait()

        local config = GetConfig()
        if config and config.override then
            Module:UpdateWidgets()
        end
    end

    RequestVisibilityRefresh = function()
        Module.pendingVisibilityRefresh = true

        if InCombatLockdown() then
            if addon and addon.CombatQueue then
                addon.CombatQueue:Add(opts.configKey .. "_visibility_refresh", function()
                    ReconcileVisibility()
                end)
            end
            return
        end

        if pendingVisibilityUpdate then
            return
        end

        pendingVisibilityUpdate = true

        if not Module.visibilityUpdateFrame then
            Module.visibilityUpdateFrame = CreateFrame("Frame")
        end

        Module.visibilityUpdateFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            pendingVisibilityUpdate = false

            if Module.pendingVisibilityRefresh then
                ReconcileVisibility()
            end
        end)
    end

    RequestVisibilityRefreshFromEvent = function()
        -- Defer one frame to avoid mutating protected unit frame visibility
        -- directly from Blizzard unit update event call stacks.
        RequestVisibilityRefresh()
    end

    local function OnEvent(self, event, ...)
        -- ----------------------------------------------------------------
        -- ADDON_LOADED
        -- ----------------------------------------------------------------
        if event == "ADDON_LOADED" then
            local name = ...
            if name == "DragonUI" then
                -- Apply widget position from DB (addon.db is now available)
                Module:ApplyWidgetPosition()
            end

        -- ----------------------------------------------------------------
        -- PLAYER_ENTERING_WORLD
        -- ----------------------------------------------------------------
        elseif event == "PLAYER_ENTERING_WORLD" then
            InitializeFrame()

            -- Retry if frame wasn't ready (e.g., loading screen)
            if not Module.configured and IsEnabled() then
                if not Module.retryFrame then
                    Module.retryFrame = CreateFrame("Frame")
                end
                local retryCount = 0
                Module.retryFrame:SetScript("OnUpdate", function(retryself, elapsed)
                    retryCount = retryCount + 1
                    if Module.configured or retryCount > 50 then
                        retryself:SetScript("OnUpdate", nil)
                        return
                    end
                    if frames.main and not Module.configured then
                        InitializeFrame()
                    end
                end)
            end

            -- Ensure visibility after entering world
            RequestVisibilityRefreshFromEvent()

        -- ----------------------------------------------------------------
        -- Unit event (target/focus changed)
        -- ----------------------------------------------------------------
        elseif event == opts.unitEvent then
            if not IsEnabled() then return end

            RequestVisibilityRefreshFromEvent()

        -- ----------------------------------------------------------------
        -- UNIT_TARGET
        -- ----------------------------------------------------------------
        elseif event == "UNIT_TARGET" then
            if not IsEnabled() then return end

            local unit = ...
            local shouldHandle = false
            for _, filterUnit in ipairs(opts.unitTargetFilters) do
                if unit == filterUnit then
                    shouldHandle = true
                    break
                end
            end

            if shouldHandle then
                RequestVisibilityRefreshFromEvent()
            end

        elseif event == "PLAYER_REGEN_ENABLED" then
            if IsEnabled() then
                RequestVisibilityRefresh()
            end

        elseif event == "CVAR_UPDATE" then
            local cvarName = ...
            if opts.cvar and cvarName == opts.cvar then
                RequestVisibilityRefreshFromEvent()
            end

        -- ----------------------------------------------------------------
        -- UNIT_CLASSIFICATION_CHANGED
        -- ----------------------------------------------------------------
        elseif event == "UNIT_CLASSIFICATION_CHANGED" then
            if not IsEnabled() then return end

            local unit = ...
            if unit == opts.unitToken then
                UpdateClassification()
            end
        end
    end

    -- Register events
    Module.eventsFrame = CreateFrame("Frame")
    Module.eventsFrame:RegisterEvent("ADDON_LOADED")
    Module.eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Module.eventsFrame:RegisterEvent(opts.unitEvent)
    Module.eventsFrame:RegisterEvent("UNIT_TARGET")
    Module.eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    if opts.cvar then
        Module.eventsFrame:RegisterEvent("CVAR_UPDATE")
    end
    Module.eventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    Module.eventsFrame:SetScript("OnEvent", OnEvent)


    -- ========================================================================
    -- WIDGET POSITION HELPERS (like pet.lua / party.lua pattern)
    -- ========================================================================

    function Module:ApplyWidgetPosition()
        if not Module.anchorFrame then return end

        if InCombatLockdown() then
            if not pendingWidgetPositionUpdate and addon and addon.CombatQueue then
                pendingWidgetPositionUpdate = true
                addon.CombatQueue:Add(opts.configKey .. "_widget_position", function()
                    pendingWidgetPositionUpdate = false
                    Module:UpdateWidgets()
                end)
            end
            return
        end

        local config = GetConfig()
        if config and config.override then
            -- Detached mode: use saved widget position from DB
            if addon.db and addon.db.profile and addon.db.profile.widgets then
                local widgetConfig = addon.db.profile.widgets[opts.configKey]
                if widgetConfig and widgetConfig.posX ~= nil and widgetConfig.posY ~= nil then
                    local anchor = widgetConfig.anchor or "CENTER"
                    Module.anchorFrame:ClearAllPoints()
                    Module.anchorFrame:SetPoint(anchor, UIParent, anchor, widgetConfig.posX, widgetConfig.posY)
                    return
                end
            end

            -- Fallback: if detached but DB coords are missing, keep anchor at
            -- the current Blizzard frame position to avoid center flicker.
            if frames.main and frames.main.GetCenter then
                local fx, fy = frames.main:GetCenter()
                local ux, uy = UIParent:GetCenter()
                if fx and fy and ux and uy then
                    Module.anchorFrame:ClearAllPoints()
                    Module.anchorFrame:SetPoint("CENTER", UIParent, "CENTER", fx - ux, fy - uy)
                    return
                end
            end
        end
        -- Attached mode or no saved data: temporary position (showTest will reposition in editor)
        Module.anchorFrame:ClearAllPoints()
        Module.anchorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local function PersistDetachedAnchorFromCurrentPosition()
        if not Module.anchorFrame then
            return false
        end

        if not (addon.db and addon.db.profile) then
            return false
        end

        addon.db.profile.widgets = addon.db.profile.widgets or {}
        addon.db.profile.widgets[opts.configKey] = addon.db.profile.widgets[opts.configKey] or {}

        local cx, cy = Module.anchorFrame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if not (cx and cy and ux and uy) then
            return false
        end

        addon.db.profile.widgets[opts.configKey].anchor = "CENTER"
        addon.db.profile.widgets[opts.configKey].posX = math.floor((cx - ux) + 0.5)
        addon.db.profile.widgets[opts.configKey].posY = math.floor((cy - uy) + 0.5)
        return true
    end

    function Module:UpdateWidgets()
        if InCombatLockdown() then
            if not pendingWidgetPositionUpdate and addon and addon.CombatQueue then
                pendingWidgetPositionUpdate = true
                addon.CombatQueue:Add(opts.configKey .. "_widget_position", function()
                    pendingWidgetPositionUpdate = false
                    Module:UpdateWidgets()
                end)
            end
            return
        end

        Module:ApplyWidgetPosition()
        -- Reposition the main frame relative to the updated anchor if overridden
        if frames.main then
            local config = GetConfig()
            if config and config.override and Module.anchorFrame then
                frames.main:ClearAllPoints()
                frames.main:SetPoint("CENTER", Module.anchorFrame, "CENTER", 0, 0)
            end
        end
    end


    -- ========================================================================
    -- PUBLIC API
    -- ========================================================================

    local function RefreshFrame()
        if not IsEnabled() then
            if frames.main and not InCombatLockdown() then
                frames.main:Hide()
            elseif frames.main then
                RequestVisibilityRefresh()
            end
            return
        end

        if not Module.configured then
            InitializeFrame()
        else
            if frames.main and not InCombatLockdown() then
                local config = GetConfig()
                if config and config.override and Module.anchorFrame then
                    Module:ApplyWidgetPosition()
                    frames.main:ClearAllPoints()
                    frames.main:SetPoint("CENTER", Module.anchorFrame, "CENTER", 0, 0)
                else
                    frames.main:ClearAllPoints()
                    frames.main:SetPoint(
                        (config and config.anchor) or opts.defaultAnchor or "BOTTOMRIGHT",
                        frames.parent,
                        (config and config.anchorParent) or opts.defaultAnchorParent or "BOTTOMRIGHT",
                        (config and config.x) or opts.defaultX or 0,
                        (config and config.y) or opts.defaultY or 0
                    )
                end
                frames.main:SetScale((config and config.scale) or 1.0)

                RequestVisibilityRefresh()
            elseif frames.main then
                RequestVisibilityRefresh()
            end
        end

        if ShouldShow() then
            UpdateClassification()
        end
    end

    local function ResetFrame()
        -- Re-attach to parent frame (clear override)
        local config = GetConfig()
        if config then
            config.override = false
        end
        addon:SetConfigValue("unitframe", opts.configKey, "x", opts.defaultX or 0)
        addon:SetConfigValue("unitframe", opts.configKey, "y", opts.defaultY or 0)
        addon:SetConfigValue("unitframe", opts.configKey, "scale", 1.0)

        if not InCombatLockdown() then
            frames.main:ClearAllPoints()
            frames.main:SetPoint(
                opts.defaultAnchor or "BOTTOMRIGHT",
                frames.parent,
                opts.defaultAnchorParent or "BOTTOMRIGHT",
                opts.defaultX or 0,
                opts.defaultY or 0
            )
            frames.main:SetScale(1.0)
        end
    end

    -- ========================================================================
    -- EDITOR MODE INITIALIZATION (at file load time, like pet.lua/party.lua)
    -- ========================================================================

    -- Create anchor frame immediately (addon.CreateUIFrame is available)
    Module.anchorFrame = addon.CreateUIFrame(120, 47, opts.configKey)
    if Module.anchorFrame.editorText then
        local L = addon.L
        Module.anchorFrame.editorText:SetText(
            (L and (L[opts.configKey] or L[opts.namePrefix])) or opts.namePrefix
        )
    end
    -- Temporary position until ADDON_LOADED restores from DB
    Module:ApplyWidgetPosition()

    -- Track if the user actually dragged this frame in editor mode
    Module.anchorFrame:HookScript("OnDragStop", function(self)
        self.DragonUI_WasDragged = true

        -- Detach and persist immediately on drag stop so ToT does not get
        -- re-attached by Blizzard updates before editor mode is closed.
        local config = GetConfig()
        if config then
            config.override = true
        end
        PersistDetachedAnchorFromCurrentPosition()
        Module:UpdateWidgets()
    end)

    -- Register with editor mode system immediately
    addon:RegisterEditableFrame({
        name = opts.configKey,  -- "tot" or "fot"
        frame = Module.anchorFrame,
        configPath = {"widgets", opts.configKey},
        hasTarget = function()
            -- Always show in editor mode (like pet frame)
            return true
        end,
        showTest = function()
            -- Position anchor overlay on top of the actual frame when attached
            if Module.anchorFrame then
                Module.anchorFrame:Show() -- Ensure anchor is visible
                local config = GetConfig()
                if not config or not config.override then
                    -- Ensure we have a valid center before trying to sync overlay.
                    if frames.main and not InCombatLockdown() then
                        frames.main:Show()
                    end

                    -- Attached mode: prefer true anchoring so the editor overlay
                    -- follows target/focus movement in real time. If that creates
                    -- a dependency cycle (known edge case), fallback to absolute center.
                    if frames.main then
                        Module.anchorFrame:ClearAllPoints()
                        local linked = pcall(Module.anchorFrame.SetPoint, Module.anchorFrame, "CENTER", frames.main, "CENTER", 0, 0)
                        if not linked then
                            local fx, fy = frames.main:GetCenter()
                            local ux, uy = UIParent:GetCenter()
                            if fx and fy and ux and uy then
                                Module.anchorFrame:SetPoint("CENTER", UIParent, "CENTER", fx - ux, fy - uy)
                            end
                        end
                    end
                else
                    Module:ApplyWidgetPosition()
                    Module:UpdateWidgets()
                end
            end
            -- Show the Blizzard frame in editor mode even without a target
            if frames.main and not InCombatLockdown() then
                frames.main:Show()
            end
        end,
        hideTest = function()
            -- Restore normal visibility when leaving editor
            if frames.main and not InCombatLockdown() then
                if not ShouldShow() then
                    frames.main:Hide()
                end
            end
        end,
        onHide = function()
            -- Detach if the user dragged OR adjusted via pixel-perfect controls.
            if Module.anchorFrame.DragonUI_WasDragged or Module.anchorFrame.DragonUI_WasAdjustedByEditor then
                local config = GetConfig()
                if config then
                    config.override = true
                end

                PersistDetachedAnchorFromCurrentPosition()

                Module:UpdateWidgets()
                Module.anchorFrame.DragonUI_WasDragged = nil
                Module.anchorFrame.DragonUI_WasAdjustedByEditor = nil
            end
        end,
        module = Module
    })

    Module.initialized = true

    -- ========================================================================
    -- Return module API table
    -- ========================================================================
    return {
        Refresh = RefreshFrame,
        Reset = ResetFrame,
        anchor = function() return Module.anchorFrame end,
        IsEnabled = IsEnabled,
        GetConfig = GetConfig,
        UpdateClassPortrait = UpdateSmallFrameClassPortrait,
    }
end
