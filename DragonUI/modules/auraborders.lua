local addon = select(2, ...)
local _G = getfenv(0)

-- ============================================================================
-- DragonUI - Aura Borders Module
-- Action buttons get free layering: CheckButton NormalTexture draws over the
-- Cooldown child. Aura templates are plain Frames, so chrome lives on a sibling
-- host above the Cooldown. Frame overhang scales with icon size to keep the same
-- ratio as buttons.lua at 37px (fixed 2.2px overhang breaks on large auras).
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

local BORDER_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local FRAME_TEXTURE = addon._dir .. "ActionBars\\uiactionbariconframe_white.tga"

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

local DURATION_DROP = 2
local BAR_REF = 37 -- buttons.lua SetSize(37,37); NormalTexture overhang tuned for this

-- Keep the same frame/icon ratio as a 37px action button (overhang 2.2 / 2.3).
local function ResolveFrameOverhang(size)
    local scale = (size or BAR_REF) / BAR_REF
    if scale < 0.45 then scale = 0.45 end
    return 2.2 * scale, 2.3 * scale, -2.2 * scale, -2.2 * scale
end

local MAX_PLAYER_BUFFS = 32
local MAX_PLAYER_DEBUFFS = 16
local MAX_TARGET_BUFFS = 32
local MAX_TARGET_DEBUFFS = 16
local MAX_TEMP_ENCHANTS = 3

local DebuffTypeColor = DebuffTypeColor

local styledButtons = {}

local function GetConfig()
    return addon:GetModuleConfig("auraborders")
end

local function IsEnabled()
    return addon:IsModuleEnabled("auraborders")
end

local function IsRoundedBorderEnabled()
    local cfg = GetConfig()
    return cfg and cfg.custom_border == true
end

local function GetBuffColor()
    local cfg = GetConfig()
    local c = cfg and cfg.buff_color
    if c and c.r then
        return c.r, c.g, c.b
    end
    return 0.2, 0.2, 0.2
end

-- Soft-edged frame texture vanishes faster than the solid icon at the same alpha.
-- 0 = chrome stays opaque; 1 = match button SetAlpha. Tune here (not an options slider).
local BORDER_EXPIRY_FADE = 0.4

local function SyncChromeAlpha(button, alpha)
    local host = button.duiHost
    if not host then return end
    if alpha == nil then
        alpha = button.GetAlpha and button:GetAlpha() or 1
    end
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    host:SetAlpha(1 - (1 - alpha) * BORDER_EXPIRY_FADE)
end

local function BuildSquareSlice(host, thickness)
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
    return s
end

local function ColorSquare(slice, r, g, b)
    slice.top:SetVertexColor(r, g, b)
    slice.bottom:SetVertexColor(r, g, b)
    slice.left:SetVertexColor(r, g, b)
    slice.right:SetVertexColor(r, g, b)
end

-- Host is a sibling at the parent's scale; without this the overhang stays 1x on a scaled button.
local function SyncChromeScale(button)
    local host = button.duiHost
    if not host then return end
    local scale = button:GetScale() or 1
    if scale > 0 and host:GetScale() ~= scale then
        host:SetScale(scale)
    end
end

local function AnchorHostToButton(host, button)
    local size = button:GetWidth() or BAR_REF
    local trX, trY, blX, blY = ResolveFrameOverhang(size)
    host:ClearAllPoints()
    host:SetPoint("TOPRIGHT", button, trX, trY)
    host:SetPoint("BOTTOMLEFT", button, blX, blY)
end

local CD_BASE = 20

-- Aura cooldown model stops stretching past ~26px (CENTER-only template anchor); fixed rect + SetScale scales the swirl itself.
local function FitCooldown(button, size)
    local name = button.GetName and button:GetName()
    local cd = name and _G[name .. "Cooldown"]
    if not cd then return nil end

    -- Full button size, no inset — action bars run SetAllPoints(button) and the sweep edge hides under the frame.
    if not size or size < 1 then size = BAR_REF end

    cd:ClearAllPoints()
    cd:SetPoint("CENTER", button, "CENTER", 0, 0)
    cd:SetWidth(CD_BASE)
    cd:SetHeight(CD_BASE)
    cd:SetScale(size / CD_BASE)
    cd:SetFrameLevel(button:GetFrameLevel() + 1)
    button.duiCdFitted = true
    return cd
end

local function FitAuraChrome(button, icon)
    local size = button:GetWidth() or BAR_REF

    -- Same as buttons.lua main_buttons: flush icon + bevel crop.
    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    if not button.duiIconOrigLayer then
        button.duiIconOrigLayer = icon:GetDrawLayer() or "BACKGROUND"
    end
    icon:SetDrawLayer("BORDER")

    -- Player AuraButtonTemplate puts Count on BACKGROUND with the icon; BORDER icon would hide stacks.
    -- Target/focus counts already sit on ARTWORK/OVERLAY — leave them alone.
    local name = button.GetName and button:GetName()
    local count = button.count or (name and _G[name .. "Count"])
    if count and not button.duiCountRaised then
        local layer = count:GetDrawLayer()
        if layer == "BACKGROUND" then
            button.duiCountOrigLayer = layer
            count:SetDrawLayer("OVERLAY")
            button.duiCountRaised = true
        end
    end

    return FitCooldown(button, size)
end

-- Blizzard resets aura size (17/21) each update before target.lua's resize hook; refit on every size write.
local function RefitChrome(button)
    if not AuraBordersModule.applied or not styledButtons[button] then return end
    local size = button:GetWidth() or BAR_REF
    if button.duiCdFitted then
        FitCooldown(button, size)
    end
    if button.duiHost and button.duiFrame and button.duiFrame:IsShown() then
        AnchorHostToButton(button.duiHost, button)
    end
end

local function ReparentChromeHost(button)
    local host = button.duiHost
    if not host then return end

    local parent = button:GetParent() or UIParent
    if host:GetParent() ~= parent then
        host:SetParent(parent)
    end

    -- Preview icons use HIGH; without this the sibling chrome stays on UIParent's
    -- default strata and draws behind the icon (real BuffButtons share LOW).
    local strata = button.GetFrameStrata and button:GetFrameStrata()
    if strata and host:GetFrameStrata() ~= strata then
        host:SetFrameStrata(strata)
    end

    local base = button:GetFrameLevel() + 1
    local name = button.GetName and button:GetName()
    local cd = name and _G[name .. "Cooldown"]
    if cd and cd.GetFrameLevel then
        local cdLevel = cd:GetFrameLevel()
        if cdLevel >= base then
            base = cdLevel
        end
    end
    host:SetFrameLevel(base + 5)
end

-- Sibling as a sibling (not a child): mirror Show/Hide/SetParent and apply compensated
-- SetAlpha so the soft-edged chrome can track the buff expiry pulse.
local function EnsureChromeVisibilitySync(button)
    if button.duiAlphaHooked then return end

    hooksecurefunc(button, "SetAlpha", function(self, alpha)
        if self.duiHost and AuraBordersModule.applied and styledButtons[self] then
            SyncChromeAlpha(self, alpha)
        end
    end)
    hooksecurefunc(button, "Hide", function(self)
        if self.duiHost then
            self.duiHost:Hide()
        end
    end)
    hooksecurefunc(button, "Show", function(self)
        if self.duiHost and AuraBordersModule.applied and styledButtons[self] then
            SyncChromeAlpha(self)
            self.duiHost:Show()
        end
    end)
    -- Consolidated buffs SetParent into the tooltip container after AuraButton_Update.
    hooksecurefunc(button, "SetParent", function(self)
        if self.duiHost and AuraBordersModule.applied and styledButtons[self] then
            ReparentChromeHost(self)
        end
    end)

    button.duiAlphaHooked = true
end

local function EnsureChromeHost(button, cd)
    local parent = button:GetParent() or UIParent
    local host = button.duiHost
    if not host then
        host = CreateFrame("Frame", nil, parent)
        button.duiHost = host
    end

    ReparentChromeHost(button)
    SyncChromeScale(button)
    AnchorHostToButton(host, button)
    SyncChromeAlpha(button)
    EnsureChromeVisibilitySync(button)
    return host
end

local function EnsureFrameChrome(button, cd)
    local host = EnsureChromeHost(button, cd)

    if not button.duiFrame then
        local frame = host:CreateTexture(nil, "OVERLAY")
        frame:SetTexture(FRAME_TEXTURE)
        frame:SetAllPoints(host)
        button.duiFrame = frame
    else
        button.duiFrame:ClearAllPoints()
        button.duiFrame:SetAllPoints(host)
    end

    return button.duiFrame
end

local function EnsureSquareChrome(button, isDebuff, isUnit, cd)
    local host = EnsureChromeHost(button, cd)
    local spec = GetSpec(isDebuff, isUnit)
    -- Square uses thin overhang; re-anchor tighter than the iconframe host.
    local o = spec.overhang
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", button, "TOPLEFT", -o, o)
    host:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", o, -o)

    if not button.duiSlice then
        button.duiSlice = BuildSquareSlice(host, spec.thickness)
    end
    return button.duiSlice
end

local function EnsureBorder(button, isDebuff, isUnit)
    local name = button.GetName and button:GetName()
    local icon = button.duiAuraIcon or button.icon or (name and _G[name .. "Icon"])
    if not icon then return nil end

    local cd = FitAuraChrome(button, icon)
    button.duiAuraIcon = icon
    styledButtons[button] = true

    if not button.duiSizeHooked then
        hooksecurefunc(button, "SetWidth", RefitChrome)
        hooksecurefunc(button, "SetHeight", RefitChrome)
        hooksecurefunc(button, "SetScale", SyncChromeScale)
        button.duiSizeHooked = true
    end

    if IsRoundedBorderEnabled() then
        EnsureFrameChrome(button, cd)
    else
        EnsureSquareChrome(button, isDebuff, isUnit, cd)
    end
    return true
end

local function RestoreButton(button)
    if button.duiHost then
        button.duiHost:SetAlpha(1)
        button.duiHost:Hide()
    end
    if button.duiFrame then
        button.duiFrame:Hide()
    end
    if button.duiAuraIcon then
        button.duiAuraIcon:SetTexCoord(0, 1, 0, 1)
        if button.duiIconOrigLayer then
            button.duiAuraIcon:SetDrawLayer(button.duiIconOrigLayer)
            button.duiIconOrigLayer = nil
        end
    end
    local name = button.GetName and button:GetName()
    if button.duiCountRaised then
        local count = button.count or (name and _G[name .. "Count"])
        if count then
            count:SetDrawLayer(button.duiCountOrigLayer or "BACKGROUND")
        end
        button.duiCountRaised = nil
        button.duiCountOrigLayer = nil
    end
    if button.duiCdFitted then
        local cd = name and _G[name .. "Cooldown"]
        if cd then
            cd:SetScale(1)
            cd:ClearAllPoints()
            cd:SetPoint("CENTER", button, "CENTER", 0, -1)
        end
        button.duiCdFitted = nil
    end
    if button.duiDurMoved then
        local dur = button.duration or (name and _G[name .. "Duration"])
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

local function StyleAura(button, isDebuff, stockBorderName, isUnit)
    if not button then return end

    if not AuraBordersModule.applied then
        RestoreButton(button)
        return
    end

    if not EnsureBorder(button, isDebuff, isUnit) then return end

    if not isUnit and not button.duiDurMoved then
        local name = button.GetName and button:GetName()
        local dur = button.duration or (name and _G[name .. "Duration"])
        if dur then
            dur:ClearAllPoints()
            dur:SetPoint("TOP", button, "BOTTOM", 0, -DURATION_DROP)
            button.duiDurMoved = true
        end
    end

    local stock = (stockBorderName and _G[stockBorderName]) or button.Border
    local r, g, b
    if isDebuff then
        if stock then
            r, g, b = stock:GetVertexColor()
        else
            local none = DebuffTypeColor and DebuffTypeColor["none"]
            r, g, b = none and none.r or 0.8, none and none.g or 0, none and none.b or 0
        end
    else
        r, g, b = GetBuffColor()
    end

    if stock then
        stock:Hide()
        button.duiStockBorder = stock
    end

    local rounded = IsRoundedBorderEnabled()
    if rounded then
        if button.duiSlice then
            button.duiSlice.top:SetAlpha(0)
            button.duiSlice.bottom:SetAlpha(0)
            button.duiSlice.left:SetAlpha(0)
            button.duiSlice.right:SetAlpha(0)
        end
        if button.duiFrame then
            button.duiFrame:SetVertexColor(r, g, b, 1)
            button.duiFrame:Show()
        end
        if button.duiHost then
            SyncChromeAlpha(button)
            button.duiHost:Show()
        end
    else
        if button.duiFrame then button.duiFrame:Hide() end
        local slice = button.duiSlice
        if slice then
            slice.top:SetAlpha(1)
            slice.bottom:SetAlpha(1)
            slice.left:SetAlpha(1)
            slice.right:SetAlpha(1)
            ColorSquare(slice, r, g, b)
        end
        if button.duiHost then
            SyncChromeAlpha(button)
            button.duiHost:Show()
        end
    end
end

-- ============================================================================
-- HOOKS
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

local function RestyleShown(name, isDebuff, stockSuffix, isUnit)
    local button = _G[name]
    if not button then return end
    if button:IsShown() then
        StyleAura(button, isDebuff, stockSuffix and (name .. stockSuffix) or nil, isUnit)
    elseif button.duiFrame or button.duiHost then
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

-- Rounded chrome overhangs 2.2*size/37 per side; report how much the stock 3px aura gap falls short.
function addon.GetAuraChromeGap(size)
    if not AuraBordersModule.applied or not IsRoundedBorderEnabled() then return 0 end
    local deficit = 2 * 2.2 * ((size or BAR_REF) / BAR_REF) - 3
    if deficit <= 0 then return 0 end
    return math.ceil(deficit)
end

-- Styled frames are retained and hooked for good, so only pass pooled/persistent frames.
function addon.StyleAuraButton(button, isDebuff)
    StyleAura(button, isDebuff == true, nil, false)
end

-- RestyleAll only walks fixed Blizzard names, so the pooled preview icons need their own pass.
local function RefreshLayoutPreviewBorders()
    local mod = addon.BuffFrameModule
    if mod and mod.UpdateLayoutPreview then
        mod:UpdateLayoutPreview()
    end
end

function addon.ApplyAuraBordersSystem()
    AuraBordersModule.initialized = true
    InstallHooks()
    AuraBordersModule.applied = true
    RestyleAll()
    RefreshLayoutPreviewBorders()
    -- Re-run the aura layout so GetAuraChromeGap spacing tracks the new border style immediately.
    if addon.RefreshTargetFocusAuraLayout then
        addon.RefreshTargetFocusAuraLayout()
    end
end

function addon.RestoreAuraBordersSystem()
    AuraBordersModule.applied = false
    for button in pairs(styledButtons) do
        RestoreButton(button)
    end
    if addon.RefreshTargetFocusAuraLayout then
        addon.RefreshTargetFocusAuraLayout()
    end
end

function addon.RefreshAuraBordersSystem()
    if IsEnabled() then
        addon.ApplyAuraBordersSystem()
    else
        addon.RestoreAuraBordersSystem()
    end
end
