local addon = select(2, ...)
local _G = getfenv(0)

-- ============================================================================
-- DragonUI - Aura Borders Module
-- Modern Dragonflight-style aura icons on player, target and focus frames:
-- crops the icon's baked-in bevel and frames it with a clean 1px border.
-- Debuff borders take the dispel-type color, buffs a neutral tint. The rounded
-- icon mask DragonflightUI uses is Legion+ only, hence the crop-and-frame here.
-- ============================================================================

local AuraBordersModule = {
    initialized = false,
    applied = false,
    hooksInstalled = false,
}
addon.AuraBordersModule = AuraBordersModule

if addon.RegisterModule then
    addon:RegisterModule("auraborders", AuraBordersModule,
        (addon.L and addon.L["Aura Borders"]) or "Aura Borders",
        (addon.L and addon.L["Modern borders on buff and debuff icons."])
            or "Modern borders on buff and debuff icons.",
        { lifecyclePrefix = "AuraBorders" })
end

-- Solid uniform border: 4 straight edges of a fixed thickness (WHITE8X8), so
-- every side is exactly equal — no beveled texture, no per-side quirks. Tinted
-- per aura: buffs a neutral color, debuffs the dispel-type color.
local BORDER_TEXTURE = "Interface\\Buttons\\WHITE8X8"
-- Optional overlay texture (user-authored) laid on top of the solid border to
-- round its corners. Ships as a transparent 64x64 placeholder to paint into.
local CUSTOM_TEXTURE = "Interface\\AddOns\\DragonUI\\assets\\auracustomborder"
local CUSTOM_EXPAND = 0.5 -- grow the custom overlay this many px per side; keep it equal all sides or the square texture stretches

-- ============================================================================
-- BORDER SIZE / FIT — tune each context here.
-- thickness = border line width (px). overhang = how far it sits outside the icon.
-- Player auras are ~30px; target/focus auras are smaller (~17-21px).
-- ============================================================================
local PLAYER_BUFF   = { thickness = 1.5, overhang = 1 }
local PLAYER_DEBUFF = { thickness = 1.5, overhang = 1 }
local UNIT_BUFF     = { thickness = 1,   overhang = 0.5 }
local UNIT_DEBUFF   = { thickness = 1,   overhang = 0.5 }

local function GetSpec(isDebuff, isUnit)
    if isUnit then
        return isDebuff and UNIT_DEBUFF or UNIT_BUFF
    end
    return isDebuff and PLAYER_DEBUFF or PLAYER_BUFF
end

local ICON_CROP = 0.05 -- crop the baked-in icon bevel (matches buttons.lua)
local DURATION_DROP = 2 -- push the player duration text down so the bottom border doesn't crowd it

local MAX_PLAYER_BUFFS = 32
local MAX_PLAYER_DEBUFFS = 16
local MAX_TARGET_BUFFS = 32
local MAX_TARGET_DEBUFFS = 16
local MAX_TEMP_ENCHANTS = 3

local DebuffTypeColor = DebuffTypeColor

-- Every button that ever received a border, for a clean restore.
local styledButtons = {}

local function GetConfig()
    return addon:GetModuleConfig("auraborders")
end

local function IsEnabled()
    return addon:IsModuleEnabled("auraborders")
end

local function IsCustomBorderEnabled()
    local cfg = GetConfig()
    return cfg and cfg.custom_border == true
end

local function GetBuffColor()
    local cfg = GetConfig()
    local c = cfg and cfg.buff_color
    if c and c.r then
        return c.r, c.g, c.b
    end
    return 0.6, 0.6, 0.6 -- grayish neutral for buff borders; debuffs use dispel color
end

-- Builds a uniform 1px-style frame from 4 solid edges. Corners overlap (same
-- color), giving crisp square corners at any size.
local function BuildSlice(host, thickness)
    local function line()
        local tex = host:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(BORDER_TEXTURE)
        return tex
    end

    local s = {}
    s.top = line()
    s.top:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    s.top:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    s.top:SetHeight(thickness)

    s.bottom = line()
    s.bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
    s.bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    s.bottom:SetHeight(thickness)

    s.left = line()
    s.left:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    s.left:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
    s.left:SetWidth(thickness)

    s.right = line()
    s.right:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    s.right:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    s.right:SetWidth(thickness)

    -- Optional overlay (created last = drawn on top of the lines), covering the
    -- whole frame so a user-painted rounded border sits exactly over the corners.
    s.custom = host:CreateTexture(nil, "OVERLAY")
    s.custom:SetTexture(CUSTOM_TEXTURE)
    s.custom:SetPoint("TOPLEFT", host, "TOPLEFT", -CUSTOM_EXPAND, CUSTOM_EXPAND)
    s.custom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", CUSTOM_EXPAND, -CUSTOM_EXPAND)
    s.custom:Hide()

    return s
end

local function ColorSlice(slice, r, g, b)
    for _, part in pairs(slice) do
        part:SetVertexColor(r, g, b)
    end
end

local function EnsureBorder(button, isDebuff, isUnit)
    if button.duiSlice then
        return button.duiSlice
    end

    local icon = _G[button:GetName() .. "Icon"]
    if not icon then return nil end

    local spec = GetSpec(isDebuff, isUnit)

    -- Host frame above the cooldown swipe (target/focus auras have a Cooldown
    -- frame that would otherwise draw over the border), anchored to the icon.
    local host = CreateFrame("Frame", nil, button)
    local o = spec.overhang
    host:SetPoint("TOPLEFT", icon, "TOPLEFT", -o, o)
    host:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", o, -o)
    local cd = _G[button:GetName() .. "Cooldown"]
    local level = (cd and cd.GetFrameLevel and cd:GetFrameLevel()) or button:GetFrameLevel()
    host:SetFrameLevel(level + 5)
    host:Hide()

    button.duiHost = host
    button.duiSlice = BuildSlice(host, spec.thickness)
    button.duiAuraIcon = icon
    styledButtons[button] = true
    return button.duiSlice
end

local function RestoreButton(button)
    if button.duiHost then
        button.duiHost:Hide()
    end
    if button.duiAuraIcon then
        button.duiAuraIcon:SetTexCoord(0, 1, 0, 1)
    end
    button.duiCropped = nil
    if button.duiDurMoved then
        local dur = button.duration or _G[button:GetName() .. "Duration"]
        if dur then
            dur:ClearAllPoints()
            dur:SetPoint("TOP", button, "BOTTOM", 0, 0)
        end
        button.duiDurMoved = nil
    end
    if button.duiStockBorder then
        button.duiStockBorder:Show()
        button.duiStockBorder = nil
    end
end

-- stockBorderName: Blizzard border to suppress (debuff dispel ring, temp-enchant
-- ring). Debuffs inherit its dispel color; buffs get the neutral tint.
local function StyleAura(button, isDebuff, stockBorderName, isUnit)
    if not button then return end

    local slice = EnsureBorder(button, isDebuff, isUnit)
    if not slice then return end

    if not AuraBordersModule.applied then
        RestoreButton(button)
        return
    end

    if not button.duiCropped then
        button.duiAuraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        button.duiCropped = true
    end

    -- Player auras show the duration text right under the icon; nudge it down so
    -- the border's bottom edge doesn't sit on top of it. (target/focus timers are
    -- handled by the auracooldowns module, so leave those alone.)
    if not isUnit and not button.duiDurMoved then
        local dur = button.duration or _G[button:GetName() .. "Duration"]
        if dur then
            dur:ClearAllPoints()
            dur:SetPoint("TOP", button, "BOTTOM", 0, -DURATION_DROP)
            button.duiDurMoved = true
        end
    end

    local stock = stockBorderName and _G[stockBorderName]

    if isDebuff then
        if stock then
            ColorSlice(slice, stock:GetVertexColor())
        else
            local none = DebuffTypeColor and DebuffTypeColor["none"]
            ColorSlice(slice, none and none.r or 0.8, none and none.g or 0, none and none.b or 0)
        end
    else
        ColorSlice(slice, GetBuffColor())
    end

    if stock then
        stock:Hide()
        button.duiStockBorder = stock
    end

    -- With a custom overlay active, fade the straight lines out so only the
    -- user's (rounded) texture shows.
    local useCustom = IsCustomBorderEnabled()
    local lineAlpha = useCustom and 0 or 1
    slice.top:SetAlpha(lineAlpha)
    slice.bottom:SetAlpha(lineAlpha)
    slice.left:SetAlpha(lineAlpha)
    slice.right:SetAlpha(lineAlpha)
    if useCustom then slice.custom:Show() else slice.custom:Hide() end

    button.duiHost:Show()
end

-- ============================================================================
-- HOOKS (installed once; harmless while the module is disabled since StyleAura
-- hides the border whenever applied is false).
-- ============================================================================

local function InstallHooks()
    if AuraBordersModule.hooksInstalled then return end

    if type(AuraButton_Update) == "function" then
        hooksecurefunc("AuraButton_Update", function(buttonName, index, filter)
            local name = buttonName .. index
            local button = _G[name]
            if not button or not button:IsShown() then return end
            StyleAura(button, filter == "HARMFUL", name .. "Border", false)
        end)
    end

    if type(TargetFrame_UpdateAuras) == "function" then
        hooksecurefunc("TargetFrame_UpdateAuras", function(frame)
            local frameName = frame and frame.GetName and frame:GetName()
            if frameName ~= "TargetFrame" and frameName ~= "FocusFrame" then return end

            for i = 1, MAX_TARGET_BUFFS do
                local buff = _G[frameName .. "Buff" .. i]
                if buff and buff:IsShown() then
                    StyleAura(buff, false, nil, true)
                end
            end
            for i = 1, MAX_TARGET_DEBUFFS do
                local dName = frameName .. "Debuff" .. i
                local debuff = _G[dName]
                if debuff and debuff:IsShown() then
                    StyleAura(debuff, true, dName .. "Border", true)
                end
            end
        end)
    end

    if type(BuffFrame_Update) == "function" then
        hooksecurefunc("BuffFrame_Update", function()
            for i = 1, MAX_TEMP_ENCHANTS do
                local enchant = _G["TempEnchant" .. i]
                if enchant and enchant:IsShown() then
                    StyleAura(enchant, false, "TempEnchant" .. i .. "Border", false)
                end
            end
        end)
    end

    AuraBordersModule.hooksInstalled = true
end

-- ============================================================================
-- Re-style currently visible auras without invoking Blizzard update paths.
-- ============================================================================

local function RestyleShown(name, isDebuff, stockSuffix, isUnit)
    local button = _G[name]
    if not button then return end
    if button:IsShown() then
        StyleAura(button, isDebuff, stockSuffix and (name .. stockSuffix) or nil, isUnit)
    elseif button.duiHost then
        RestoreButton(button)
    end
end

local function RestyleAll()
    for i = 1, MAX_PLAYER_BUFFS do
        RestyleShown("BuffButton" .. i, false, nil, false)
    end
    for i = 1, MAX_PLAYER_DEBUFFS do
        RestyleShown("DebuffButton" .. i, true, "Border", false)
    end
    for i = 1, MAX_TEMP_ENCHANTS do
        RestyleShown("TempEnchant" .. i, false, "Border", false)
    end
    for _, frameName in ipairs({ "TargetFrame", "FocusFrame" }) do
        for i = 1, MAX_TARGET_BUFFS do
            RestyleShown(frameName .. "Buff" .. i, false, nil, true)
        end
        for i = 1, MAX_TARGET_DEBUFFS do
            RestyleShown(frameName .. "Debuff" .. i, true, "Border", true)
        end
    end
end

-- ============================================================================
-- LIFECYCLE (driven by the module registry: Apply/Restore/Refresh<Prefix>System)
-- ============================================================================

function addon.ApplyAuraBordersSystem()
    AuraBordersModule.initialized = true
    InstallHooks()
    AuraBordersModule.applied = true
    RestyleAll()
end

function addon.RestoreAuraBordersSystem()
    AuraBordersModule.applied = false
    for button in pairs(styledButtons) do
        RestoreButton(button)
    end
end

function addon.RefreshAuraBordersSystem()
    if IsEnabled() then
        addon.ApplyAuraBordersSystem()
    else
        addon.RestoreAuraBordersSystem()
    end
end
