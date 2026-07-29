local addon = select(2, ...)
local L = addon.L

-- ============================================================================
-- TOOLTIP MODULE FOR DRAGONUI
-- Enhances GameTooltip with class colors, health bars, target-of-target,
-- and cleaner styling inspired by Dragonflight tooltips.
-- ============================================================================

-- Module state tracking
local TooltipModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    hooks = {},
    frames = {}
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("tooltip", TooltipModule,
        (addon.L and addon.L["Tooltip"]) or "Tooltip",
        (addon.L and addon.L["Enhanced tooltip styling with class colors and health bars"]) or "Enhanced tooltip styling with class colors and health bars")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("tooltip")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("tooltip")
end

-- ============================================================================
-- CLASS COLOR CACHE
-- ============================================================================

local CLASS_COLORS = {}
for class, color in pairs(RAID_CLASS_COLORS) do
    CLASS_COLORS[class] = { r = color.r, g = color.g, b = color.b }
end

-- Faction colors for hostile/friendly/neutral
local FACTION_COLORS = {
    friendly = { r = 0.2, g = 0.8, b = 0.2 },
    neutral  = { r = 1.0, g = 1.0, b = 0.0 },
    hostile  = { r = 1.0, g = 0.2, b = 0.2 },
    tapped   = { r = 0.6, g = 0.6, b = 0.6 },
}

-- ============================================================================
-- TOOLTIP HEALTH BAR ENHANCEMENT
-- ============================================================================

local HEALTHBAR_HEIGHT = 6
local HEALTHBAR_BOTTOM_PAD = 10  -- space between bar and tooltip bottom edge
local TOOLTIP_WIDGET_ANCHOR = "BOTTOMRIGHT"
local TOOLTIP_WIDGET_POSX = -90
local TOOLTIP_WIDGET_POSY = 100

-- Restyle the existing Blizzard GameTooltipStatusBar instead of creating a new one.
-- This avoids the double health bar bug.
local function StyleHealthBar()
    if TooltipModule.healthBarStyled then return end

    local bar = GameTooltipStatusBar
    if not bar then return end

    -- Restyle: slimmer, better texture
    bar:SetHeight(HEALTHBAR_HEIGHT)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    -- Position bar INSIDE the tooltip bottom area (like DragonflightUI)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 9, HEALTHBAR_BOTTOM_PAD)
    bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -9, HEALTHBAR_BOTTOM_PAD)

    -- Add dark background behind the bar
    if not bar.__DragonUI_bg then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bg:SetVertexColor(0.15, 0.15, 0.15, 0.8)
        bar.__DragonUI_bg = bg
    end

    TooltipModule.healthBarStyled = true
end

-- Same trick Blizzard's own GameTooltip_ShowStatusBar uses: a real blank AddLine, so native auto-height covers it.
local function ReserveHealthBarLine()
    if not GameTooltipStatusBar or not GameTooltipStatusBar:IsShown() then return end
    GameTooltip:AddLine(" ")
    GameTooltip:Show()
end

-- Deferred one frame so it runs after every other addon's OnTooltipSetUnit hook (e.g. idWoW) has added its lines.
local reserveRunner = CreateFrame("Frame")
reserveRunner:Hide()
reserveRunner:SetScript("OnUpdate", function(self)
    self:Hide()
    ReserveHealthBarLine()
end)

local function AdjustTooltipForHealthBar()
    reserveRunner:Show()
end

-- ============================================================================
-- TOOLTIP BORDER COLORING
-- ============================================================================

-- Color the tooltip border based on unit reaction/class
local function ColorTooltipBorder(unit)
    if not unit or not UnitExists(unit) then return end

    local config = GetModuleConfig()
    if not config or not config.class_colored_border then return end

    local r, g, b = 1, 1, 1

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and CLASS_COLORS[class] then
            r = CLASS_COLORS[class].r
            g = CLASS_COLORS[class].g
            b = CLASS_COLORS[class].b
        end
    else
        local reaction = UnitReaction(unit, "player")
        if not reaction then
            -- Tapped or unknown
            r, g, b = FACTION_COLORS.tapped.r, FACTION_COLORS.tapped.g, FACTION_COLORS.tapped.b
        elseif reaction >= 5 then
            r, g, b = FACTION_COLORS.friendly.r, FACTION_COLORS.friendly.g, FACTION_COLORS.friendly.b
        elseif reaction == 4 then
            r, g, b = FACTION_COLORS.neutral.r, FACTION_COLORS.neutral.g, FACTION_COLORS.neutral.b
        else
            r, g, b = FACTION_COLORS.hostile.r, FACTION_COLORS.hostile.g, FACTION_COLORS.hostile.b
        end
    end

    GameTooltip:SetBackdropBorderColor(r, g, b)
end

-- ============================================================================
-- TOOLTIP NAME COLORING
-- ============================================================================

-- Color the first line (unit name) by class color for players
local function ColorTooltipName(unit)
    if not unit or not UnitExists(unit) then return end

    local config = GetModuleConfig()
    if not config or not config.class_colored_name then return end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and CLASS_COLORS[class] then
            local c = CLASS_COLORS[class]
            local name = UnitName(unit)
            if name then
                GameTooltipTextLeft1:SetTextColor(c.r, c.g, c.b)
            end
        end
    end
end

-- ============================================================================
-- TARGET-OF-TARGET LINE
-- ============================================================================

-- Add "Targeting: <name>" line to tooltip
local function AddTargetOfTarget(unit)
    if not unit or not UnitExists(unit) then return end

    local config = GetModuleConfig()
    if not config or not config.target_of_target then return end

    local targetUnit = unit .. "target"
    if UnitExists(targetUnit) then
        local targetName = UnitName(targetUnit)
        if targetName then
            local color = "|cFFFFFFFF"
            if UnitIsPlayer(targetUnit) then
                local _, class = UnitClass(targetUnit)
                if class and CLASS_COLORS[class] then
                    local c = CLASS_COLORS[class]
                    color = string.format("|cFF%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
                end
            end
            GameTooltip:AddLine(string.format(L["Targeting: %s"], color .. targetName .. "|r"), 0.7, 0.7, 0.7)
        end
    end
end

-- ============================================================================
-- HEALTH BAR UPDATE
-- ============================================================================

-- Store current tooltip unit and its bar color so OnValueChanged can re-apply
local currentTooltipBarColor = nil

local function UpdateHealthBar(unit)
    local bar = GameTooltipStatusBar
    if not bar then return end

    if not unit or not UnitExists(unit) then
        currentTooltipBarColor = nil
        return
    end

    local config = GetModuleConfig()
    if not config or not config.health_bar then
        currentTooltipBarColor = nil
        return
    end

    -- Style the bar on first use
    StyleHealthBar()

    -- Color by class or reaction
    local r, g, b = 0.2, 0.8, 0.2
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and CLASS_COLORS[class] then
            r = CLASS_COLORS[class].r
            g = CLASS_COLORS[class].g
            b = CLASS_COLORS[class].b
        end
    end
    bar:SetStatusBarColor(r, g, b)
    -- Cache the color so OnValueChanged can re-apply it
    currentTooltipBarColor = { r, g, b }
end

-- ============================================================================
-- TOOLTIP ANCHOR (optional: anchor to cursor vs default)
-- ============================================================================

local function GetTooltipWidgetConfig()
    if not addon.db or not addon.db.profile then
        return nil
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets.tooltip = addon.db.profile.widgets.tooltip or {}

    local cfg = addon.db.profile.widgets.tooltip
    if not cfg.anchor then cfg.anchor = TOOLTIP_WIDGET_ANCHOR end
    if cfg.posX == nil then cfg.posX = TOOLTIP_WIDGET_POSX end
    if cfg.posY == nil then cfg.posY = TOOLTIP_WIDGET_POSY end

    return cfg
end

local function IsTooltipCursorAnchored()
    local config = GetModuleConfig()
    return config and config.anchor_cursor == true
end

local function ApplyTooltipWidgetPosition()
    local anchorFrame = TooltipModule.frames and TooltipModule.frames.tooltipAnchor
    local cfg = GetTooltipWidgetConfig()
    if not anchorFrame or not cfg then return end

    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint(cfg.anchor or TOOLTIP_WIDGET_ANCHOR, UIParent, cfg.anchor or TOOLTIP_WIDGET_ANCHOR, cfg.posX or TOOLTIP_WIDGET_POSX, cfg.posY or TOOLTIP_WIDGET_POSY)
end

local function SyncTooltipEditorPreviewLayout()
    local anchorFrame = TooltipModule.frames and TooltipModule.frames.tooltipAnchor
    if not anchorFrame or not GameTooltip or not GameTooltip:IsShown() then
        return
    end

    local width = GameTooltip:GetWidth()
    local height = GameTooltip:GetHeight()
    if width and width > 0 and height and height > 0 then
        anchorFrame:SetSize(width, height)
    end

    anchorFrame:SetFrameStrata(GameTooltip:GetFrameStrata() or "TOOLTIP")
    anchorFrame:SetFrameLevel((GameTooltip:GetFrameLevel() or 1) + 20)
end

local function ShowTooltipEditorPreview()
    local anchorFrame = TooltipModule.frames and TooltipModule.frames.tooltipAnchor
    if not anchorFrame or IsTooltipCursorAnchored() then
        return
    end

    if anchorFrame.editorText then
        anchorFrame.editorText:ClearAllPoints()
        anchorFrame.editorText:SetPoint("BOTTOM", anchorFrame, "BOTTOM", 0, 6)
    end

    GameTooltip:SetOwner(anchorFrame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
    GameTooltip:SetUnit("player")
    GameTooltip:Show()

    SyncTooltipEditorPreviewLayout()
    anchorFrame:SetScript("OnUpdate", function()
        SyncTooltipEditorPreviewLayout()
    end)
end

local function HideTooltipEditorPreview()
    local anchorFrame = TooltipModule.frames and TooltipModule.frames.tooltipAnchor
    if anchorFrame then
        anchorFrame:SetScript("OnUpdate", nil)
        anchorFrame:SetSize(180, 50)
    end

    if GameTooltip and GameTooltip:IsShown() then
        GameTooltip:Hide()
    end
end

local function EnsureTooltipWidget()
    if TooltipModule.frames.tooltipAnchor or not addon.CreateUIFrame then
        return
    end

    local anchorFrame = addon.CreateUIFrame(180, 50, "TooltipWidget")
    TooltipModule.frames.tooltipAnchor = anchorFrame

    anchorFrame:SetFrameStrata("TOOLTIP")
    anchorFrame:SetFrameLevel((GameTooltip and GameTooltip:GetFrameLevel() or 1) + 20)

    if anchorFrame.editorText then
        anchorFrame.editorText:ClearAllPoints()
        anchorFrame.editorText:SetPoint("BOTTOM", anchorFrame, "BOTTOM", 0, 6)
    end

    ApplyTooltipWidgetPosition()

    if addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "tooltip",
            frame = anchorFrame,
            blizzardFrame = GameTooltip,
            configPath = {"widgets", "tooltip"},
            editorVisible = function()
                return not IsTooltipCursorAnchored()
            end,
            showTest = ShowTooltipEditorPreview,
            hideTest = HideTooltipEditorPreview,
            onShow = ShowTooltipEditorPreview,
            onHide = function()
                HideTooltipEditorPreview()
                ApplyTooltipWidgetPosition()
            end,
            module = TooltipModule,
        })
    end
end

local function EnsureTooltipAnchorHook()
    if TooltipModule.hooks["DefaultAnchor"] then
        return
    end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if tooltip ~= GameTooltip then return end

        if IsTooltipCursorAnchored() then
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
            return
        end

        local anchorFrame = TooltipModule.frames and TooltipModule.frames.tooltipAnchor
        if anchorFrame then
            local point, _, relativePoint, x, y = anchorFrame:GetPoint(1)
            tooltip:SetOwner(parent or UIParent, "ANCHOR_NONE")
            tooltip:ClearAllPoints()
            tooltip:SetPoint(point or TOOLTIP_WIDGET_ANCHOR, UIParent, relativePoint or point or TOOLTIP_WIDGET_ANCHOR, x or TOOLTIP_WIDGET_POSX, y or TOOLTIP_WIDGET_POSY)
        end
    end)

    TooltipModule.hooks["DefaultAnchor"] = true
end

-- ============================================================================
-- AURA SOURCE (caster name on buff/debuff tooltips)
-- ============================================================================

local function ShouldShowAuraSource()
    if not IsModuleEnabled() then
        return false
    end
    local cfg = GetModuleConfig()
    return not cfg or cfg.show_aura_source ~= false
end

local function RGBToHex(r, g, b)
    return string.format("|cff%02x%02x%02x",
        math.floor((r or 1) * 255 + 0.5),
        math.floor((g or 1) * 255 + 0.5),
        math.floor((b or 1) * 255 + 0.5))
end

local AURA_ID_LABEL = _G.ID or "ID"
local AURA_SOURCE_FALLBACK_COLOR = { r = 1, g = 1, b = 1 }

local function AuraSourceAlreadyShown(tt, spellId)
    if not spellId then
        return false
    end
    local needle = tostring(spellId)
    for i = 1, tt:NumLines() do
        local left = _G["GameTooltipTextLeft" .. i]
        local text = left and left:GetText()
        if text and text:find(needle, 1, true) and text:find(AURA_ID_LABEL, 1, true) then
            return true
        end
    end
    return false
end

-- Returns UnitAura's 8th..11th values: unitCaster, isStealable, shouldConsolidate, spellId.
local function GetAuraCasterAndSpellId(unit, index, filter)
    if filter == "HARMFUL" then
        return select(8, UnitDebuff(unit, index))
    elseif filter == "HELPFUL" then
        return select(8, UnitBuff(unit, index))
    end
    return select(8, UnitAura(unit, index, filter))
end

local function AddAuraSourceInfo(tt, unit, index, filter)
    if not ShouldShowAuraSource() or not unit or not index then
        return
    end

    local caster, _, _, spellId = GetAuraCasterAndSpellId(unit, index, filter)

    if AuraSourceAlreadyShown(tt, spellId) then
        return
    end

    local leftText
    if spellId then
        leftText = string.format("|cFFCA3C3C%s|r %d", AURA_ID_LABEL, spellId)
    end

    local rightText
    if caster then
        local name = UnitName(caster)
        if name then
            local _, class = UnitClass(caster)
            local color = (class and CLASS_COLORS[class]) or AURA_SOURCE_FALLBACK_COLOR
            rightText = RGBToHex(color.r, color.g, color.b) .. name
        end
    end

    if leftText and rightText then
        tt:AddDoubleLine(leftText, rightText)
        tt:Show()
    elseif leftText then
        tt:AddLine(leftText)
        tt:Show()
    elseif rightText then
        tt:AddLine(rightText)
        tt:Show()
    end
end

local function HookAuraTooltips()
    if TooltipModule.hooks["AuraSource"] then
        return
    end

    if GameTooltip.SetUnitBuff then
        hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit, index)
            AddAuraSourceInfo(self, unit, index, "HELPFUL")
        end)
    end

    if GameTooltip.SetUnitDebuff then
        hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit, index)
            AddAuraSourceInfo(self, unit, index, "HARMFUL")
        end)
    end

    if GameTooltip.SetUnitAura then
        hooksecurefunc(GameTooltip, "SetUnitAura", function(self, unit, index, filter)
            AddAuraSourceInfo(self, unit, index, filter)
        end)
    end

    TooltipModule.hooks["AuraSource"] = true
end

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

local function ApplyTooltipSystem()
    if TooltipModule.applied then return end

    EnsureTooltipAnchorHook()
    EnsureTooltipWidget()
    ApplyTooltipWidgetPosition()
    HookAuraTooltips()

    -- Hook GameTooltip:SetUnit
    if not TooltipModule.hooks["SetUnit"] then
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            if not IsModuleEnabled() then return end
            local _, unit = self:GetUnit()
            if unit then
                ColorTooltipBorder(unit)
                AddTargetOfTarget(unit)
                UpdateHealthBar(unit)
                self:Show() -- Resize after adding lines
                -- Color name AFTER Show() — calling Show() can reset text colors
                ColorTooltipName(unit)
                -- Extend tooltip to fit health bar inside the border
                AdjustTooltipForHealthBar()
            end
        end)
        TooltipModule.hooks["SetUnit"] = true
    end

    -- GameObject tooltips (e.g. BG doors) never call SetUnit, so OnTooltipSetUnit never fires for them — hook the bar's own OnShow instead.
    if not TooltipModule.hooks["BarShow"] then
        GameTooltipStatusBar:HookScript("OnShow", function(self)
            if not IsModuleEnabled() then return end
            StyleHealthBar()
            AdjustTooltipForHealthBar()
        end)
        TooltipModule.hooks["BarShow"] = true
    end

    -- Hook GameTooltipStatusBar OnValueChanged to persist class color through
    -- health updates (Blizzard resets the bar color on each value change)
    if not TooltipModule.hooks["BarValueChanged"] then
        GameTooltipStatusBar:HookScript("OnValueChanged", function(self)
            if not IsModuleEnabled() then return end
            if currentTooltipBarColor then
                local c = currentTooltipBarColor
                self:SetStatusBarColor(c[1], c[2], c[3])
            end
        end)
        TooltipModule.hooks["BarValueChanged"] = true
    end

    -- Hook OnTooltipCleared to reset state
    if not TooltipModule.hooks["OnCleared"] then
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            if not IsModuleEnabled() then return end
            -- Reset border color
            self:SetBackdropBorderColor(1, 1, 1)
            -- Clear cached bar color so OnValueChanged stops overriding
            currentTooltipBarColor = nil
            -- Reset health bar color to default green
            if GameTooltipStatusBar then
                GameTooltipStatusBar:SetStatusBarColor(0.2, 0.8, 0.2)
            end
        end)
        TooltipModule.hooks["OnCleared"] = true
    end

    TooltipModule.applied = true
    TooltipModule.initialized = true
end

local function RestoreTooltipSystem()
    -- Hooks can't be removed, but they check IsModuleEnabled()
    -- Reset health bar color
    if GameTooltipStatusBar then
        GameTooltipStatusBar:SetStatusBarColor(0.2, 0.8, 0.2)
    end
    TooltipModule.applied = false
end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    EnsureTooltipAnchorHook()
    EnsureTooltipWidget()
    ApplyTooltipWidgetPosition()

    if IsModuleEnabled() then
        ApplyTooltipSystem()
    else
        if addon:ShouldDeferModuleDisable("tooltip", TooltipModule) then
            return
        end
        RestoreTooltipSystem()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        EnsureTooltipAnchorHook()
        EnsureTooltipWidget()
        ApplyTooltipWidgetPosition()

        if not IsModuleEnabled() then return end

        -- Register profile callbacks
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(TooltipModule, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(TooltipModule, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(TooltipModule, "OnProfileReset", OnProfileChanged)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        EnsureTooltipAnchorHook()
        EnsureTooltipWidget()
        ApplyTooltipWidgetPosition()

        if not IsModuleEnabled() then return end
        ApplyTooltipSystem()
    end
end)

-- Export for external use
addon.ApplyTooltipSystem = ApplyTooltipSystem
addon.RestoreTooltipSystem = RestoreTooltipSystem
