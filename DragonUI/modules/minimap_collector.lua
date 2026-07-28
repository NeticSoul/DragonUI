-- ============================================================================
-- DragonUI - Minimap Collector Module
-- Isolated collector system used by minimap.lua via dependency injection.
-- ============================================================================

local addon = select(2, ...)
if not addon then return end

local Collector = addon.MinimapCollector or {}
addon.MinimapCollector = Collector

-- ----------------------------------------------------------------------------
-- Cached globals
-- ----------------------------------------------------------------------------
local _G            = _G
local CreateFrame   = CreateFrame
local UIParent      = UIParent
local GameTooltip   = GameTooltip
local GetTime       = GetTime
local GetCursorPosition    = GetCursorPosition
local SetPortraitToTexture = SetPortraitToTexture
local hooksecurefunc = hooksecurefunc
local pcall, tonumber, tostring, type, ipairs, unpack, select =
      pcall, tonumber, tostring, type, ipairs, unpack, select
local mathmax, mathmin, mathfloor, mathceil =
      math.max, math.min, math.floor, math.ceil
local mathrad, mathdeg, mathcos, mathsin, mathpi =
      math.rad, math.deg, math.cos, math.sin, math.pi
local mathatan2, mathatan = math.atan2, math.atan
local strlower, tsort = string.lower, table.sort

-- ----------------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------------
local STYLE_DUI       = "dragonui"
local STYLE_CLASSIC   = "classic"
local DEFAULT_ANGLE   = 315
local ANIM_DURATION   = 0.14
local ANIM_SHRINK     = 0.35
local HIGHLIGHT_TEX   = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local WHITE_TEX       = "Interface\\Buttons\\WHITE8X8"
local BORDER_TEX      = "Interface\\AddOns\\DragonUI\\Textures\\border_buttons.tga"
local GOLD_R, GOLD_G, GOLD_B = 1.0, 0.82, 0.20

local INCLUDE_BUTTONS = {
    "WIM_IconFrame",
    "CTMod2_MinimapButton",
    "PoisonerMinimapButton",
    "AtlasButton",
}

-- Legacy addons parent the launcher Button inside a Frame wrapper on Minimap.
local BUTTON_WRAPPER_FRAMES = {
    AtlasButton = "AtlasButtonFrame",
}

local EXCLUDED_BUTTONS = {
    -- MBB controls this container's anchoring; collecting it causes SetPoint dependency loops.
    ["MBB_MinimapButtonFrame"] = true,
}

-- ----------------------------------------------------------------------------
-- State
-- ----------------------------------------------------------------------------
local deps = Collector._deps or {}
local isRefreshingCollector = false  -- guards against reentrant RefreshCollector calls

-- ----------------------------------------------------------------------------
-- Config helpers
-- ----------------------------------------------------------------------------
local function GetCfg()
    local a = deps.addon
    return a and a.db and a.db.profile and a.db.profile.minimap
end

local function IsEnabled()
    local c = GetCfg()
    if not c or c.collector_enabled == nil then return true end
    return c.collector_enabled
end

local function NormalizeAngle(a)
    a = (tonumber(a) or DEFAULT_ANGLE) % 360
    if a < 0 then a = a + 360 end
    return a
end

local function GetStyle()
    local c = GetCfg()
    local s = (c and c.collector_style) or STYLE_DUI
    if s == STYLE_CLASSIC then return s end
    if s ~= STYLE_DUI then
        s = STYLE_DUI
        if c then c.collector_style = s end
    end
    return s
end

local function IsSkinEnabled()
    local c = GetCfg()
    return (c and c.addon_button_skin) and true or false
end

local function IsSettingsButtonFadeEnabled()
    return GetStyle() ~= STYLE_CLASSIC and (deps.IsFadeEnabled and deps.IsFadeEnabled())
end

local function GetStoredAngle()
    local c = GetCfg()
    return c and NormalizeAngle(c.settings_button_angle) or DEFAULT_ANGLE
end

local function SetStoredAngle(a)
    local c = GetCfg()
    if c then c.settings_button_angle = NormalizeAngle(a) end
end

local function GetModule()      return deps.MinimapModule end
local function GetFrames()      local m = GetModule(); return m and m.frames end
local function GetCollector()   local f = GetFrames(); return f and f.iconCollector end
local function GetSettingsBtn() local f = GetFrames(); return f and f.settingsButton end

local function ApplyCollectorCompatibilityFix(btn, collector)
    local a = deps.addon
    local c = a and a.compatibility
    if c and c.ApplySexyMapCollectorVisibilityFix then
        c:ApplySexyMapCollectorVisibilityFix(btn, collector)
    end
end

local function ApplyCollectorToggleVisibilityCompatibility(btn)
    local a = deps.addon
    local c = a and a.compatibility
    if c and c.ApplySexyMapCollectorToggleVisibilityFix then
        return c:ApplySexyMapCollectorToggleVisibilityFix(btn) and true or false
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Texture helpers
-- ----------------------------------------------------------------------------
local function SafeSet(tex, primary, fallback)
    local a = deps.addon
    if a and a.SafeSetTexture then
        a:SafeSetTexture(tex, primary, fallback)
    elseif primary then
        tex:SetTexture(primary)
    end
end

local function SetClassicIcon(tex)
    if not tex then return end
    SafeSet(tex, deps.DRAGONUI_CLASSIC_COLLECTOR_ICON)
    tex:SetTexCoord(0, 1, 0, 1)
end

local function SetSettingsIcon(tex)
    if not tex then return end
    if SetPortraitToTexture then
        local ok = pcall(SetPortraitToTexture, tex, deps.DRAGONUI_SETTINGS_BUTTON_ICON)
        if ok then
            tex:SetTexCoord(0, 1, 0, 1)
            return
        end
    end
    SafeSet(tex, deps.DRAGONUI_SETTINGS_BUTTON_ICON)
    tex:SetTexCoord(0, 1, 0, 1)
end

local function LayoutSettingsIcon(btn, pressed)
    local icon = btn and btn.icon
    if not icon or GetStyle() ~= STYLE_DUI then return end
    local btnSize = btn:GetWidth() or deps.DRAGONUI_SETTINGS_BUTTON_SIZE or 21
    -- File portrait: TexCoord breaks SetPortraitToTexture. Grow under oversized ring (Bagster guild).
    local ringSize = btnSize + 4
    local rest = btnSize
    local size = pressed and (ringSize - 2) or rest
    icon:ClearAllPoints()
    icon:SetSize(size, size)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexCoord(0, 1, 0, 1)
    if btn.ringFrame then
        btn.ringFrame:ClearAllPoints()
        btn.ringFrame:SetSize(ringSize, ringSize)
        btn.ringFrame:SetPoint("CENTER", btn, "CENTER", 0, 0)
    end
    if btn.circle then
        btn.circle:ClearAllPoints()
        btn.circle:SetAllPoints(btn.ringFrame or btn)
    end
end

local function SetClassicGlow(tex)
    if not tex then return end
    local a = deps.addon
    if a and a.SafeSetTexture then
        a:SafeSetTexture(tex, deps.DRAGONUI_CLASSIC_COLLECTOR_ICON)
    else
        tex:SetTexture(deps.DRAGONUI_CLASSIC_COLLECTOR_ICON or WHITE_TEX)
    end
    tex:SetTexCoord(0, 1, 0, 1)
end

-- ----------------------------------------------------------------------------
-- Child iteration helper (no per-call table allocation)
-- ----------------------------------------------------------------------------
local function ForEachChild(frame, fn)
    if not frame or not frame.GetChildren then return end
    local children = { frame:GetChildren() }
    local n = #children
    if n == 0 then return end
    for i = 1, n do
        local c = children[i]
        if c then fn(c) end
    end
end

-- ----------------------------------------------------------------------------
-- Highlight / glow / animations
-- ----------------------------------------------------------------------------
local UpdateHighlightStyle  -- forward declaration
local RefreshCollector  -- forward declaration
local HookButtonVisibility  -- forward declaration

local function EnsureHighlight(btn)
    if btn.DragonUI_HighlightPrepared then return end
    btn.DragonUI_HighlightPrepared = true

    btn:SetHighlightTexture(HIGHLIGHT_TEX, "ADD")
    local h = btn:GetHighlightTexture()
    if h then
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        h:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        h:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
    end

    local parent = btn.ringFrame or btn
    local function makeLayer(alpha)
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(HIGHLIGHT_TEX)
        t:SetBlendMode("ADD")
        t:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, alpha)
        t:Hide()
        return t
    end
    btn.DragonUI_CircleHighlightLayer1 = makeLayer(1.0)
    btn.DragonUI_CircleHighlightLayer2 = makeLayer(0.8)
end

local function EnsureClassicGlow(btn)
    if btn.DragonUI_ArrowGlow then return end
    local g = btn:CreateTexture(nil, "OVERLAY")
    g:SetBlendMode("ADD")
    g:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 0.9)
    g:Hide()
    btn.DragonUI_ArrowGlow = g
    SetClassicGlow(g)
end

local function EnsureCircleClickAnimation(btn)
    if btn.DragonUI_ClickFlash then return end

    local parent = btn.ringFrame or btn
    local flash = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    flash:SetTexture(BORDER_TEX)
    flash:SetBlendMode("ADD")
    flash:SetAllPoints(parent)
    flash:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
    flash:SetAlpha(0)
    flash:Hide()
    btn.DragonUI_ClickFlash = flash

    local fa = flash:CreateAnimationGroup()
    local fin = fa:CreateAnimation("Alpha"); fin:SetOrder(1); fin:SetDuration(0.06); fin:SetChange(0.9)
    local fout = fa:CreateAnimation("Alpha"); fout:SetOrder(2); fout:SetDuration(0.16); fout:SetChange(-0.9)
    fa:SetScript("OnPlay",     function() flash:SetAlpha(0); flash:Show() end)
    fa:SetScript("OnFinished", function() flash:SetAlpha(0); flash:Hide() end)
    fa:SetScript("OnStop",     function() flash:SetAlpha(0); flash:Hide() end)
    btn.DragonUI_ClickFlashAnim = fa

    if btn.circle then
        local pulse = btn.circle:CreateAnimationGroup()
        local dim = pulse:CreateAnimation("Alpha"); dim:SetOrder(1); dim:SetDuration(0.06); dim:SetChange(-0.45)
        local br  = pulse:CreateAnimation("Alpha"); br:SetOrder(2); br:SetDuration(0.12); br:SetChange(0.45)
        local function reset() if btn.circle then btn.circle:SetAlpha(1) end end
        pulse:SetScript("OnPlay", reset)
        pulse:SetScript("OnFinished", reset)
        pulse:SetScript("OnStop", reset)
        btn.DragonUI_ClickRingPulse = pulse
    end
end

local function EnsureClassicAttention(btn)
    if btn.DragonUI_ArrowAttentionAnim or not btn.icon then return end

    local function restoreIcon()
        local i = btn.icon
        if not i then return end
        if i.SetScale then i:SetScale(1) end
        i:ClearAllPoints()
        i:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        i:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        SetClassicIcon(i)
    end

    local anim = btn.icon:CreateAnimationGroup()
    for p = 1, 3 do
        local grow = anim:CreateAnimation("Scale")
        grow:SetOrder(p * 2 - 1); grow:SetDuration(0.44); grow:SetScale(1.40, 1.40)
        local shrink = anim:CreateAnimation("Scale")
        shrink:SetOrder(p * 2); shrink:SetDuration(0.44); shrink:SetScale(0.7, 0.7)
    end
    anim:SetScript("OnPlay", function()
        restoreIcon()
        local g = btn.DragonUI_ArrowGlow
        if g then g:SetAlpha(0.9); g:Show() end
    end)
    anim:SetScript("OnFinished", function() restoreIcon(); UpdateHighlightStyle(btn) end)
    anim:SetScript("OnStop",     function() restoreIcon(); UpdateHighlightStyle(btn) end)
    btn.DragonUI_ArrowAttentionAnim = anim
end

local function PlayCircleClick(btn)
    if GetStyle() ~= STYLE_DUI then return end
    EnsureCircleClickAnimation(btn)
    local p = btn.DragonUI_ClickRingPulse
    if p then if p:IsPlaying() then p:Stop() end; p:Play() end
    local f = btn.DragonUI_ClickFlashAnim
    if f then if f:IsPlaying() then f:Stop() end; f:Play() end
end

local function PlayClassicAttention(btn)
    if GetStyle() ~= STYLE_CLASSIC then return end
    EnsureClassicGlow(btn)
    EnsureClassicAttention(btn)
    local a = btn.DragonUI_ArrowAttentionAnim
    if a then if a:IsPlaying() then a:Stop() end; a:Play() end
end

UpdateHighlightStyle = function(btn)
    if not btn then return end
    EnsureHighlight(btn)
    EnsureClassicGlow(btn)

    local style = GetStyle()
    local h = btn.GetHighlightTexture and btn:GetHighlightTexture()
    local active = btn.IsMouseOver and btn:IsMouseOver()
    local l1, l2, glow = btn.DragonUI_CircleHighlightLayer1, btn.DragonUI_CircleHighlightLayer2, btn.DragonUI_ArrowGlow

    if h then h:SetAlpha(0) end

    if style == STYLE_CLASSIC then
        if l1 then l1:Hide() end
        if l2 then l2:Hide() end
        if glow then
            glow:ClearAllPoints()
            glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
            glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
            SetClassicGlow(glow)
            if active then glow:Show() else glow:Hide() end
        end
    else
        if glow then glow:Hide() end
        -- Match oversized ring (btn+4), not the smaller button box.
        local anchor = btn.ringFrame or btn
        if l1 then
            l1:ClearAllPoints()
            l1:SetAllPoints(anchor)
            if active then l1:Show() else l1:Hide() end
        end
        if l2 then
            l2:ClearAllPoints()
            l2:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
            l2:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)
            if active then l2:Show() else l2:Hide() end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Geometry helpers
-- ----------------------------------------------------------------------------
local function GetOrbitRadius(btn)
    local mapR = mathmax(Minimap:GetWidth(), Minimap:GetHeight()) * 0.5
    local size = (btn and btn:GetWidth()) or deps.DRAGONUI_SETTINGS_BUTTON_SIZE or 24
    local scale = (btn and btn.GetScale and btn:GetScale()) or 1
    -- Sit on the minimap rim and hang outside (+8); ring is already btn+4.
    return mathmax(12, mapR - (size * scale) * 0.5 + 6)
end

local function GetMinimapScale()
    if not Minimap or not Minimap.GetScale then return 1 end
    local s = tonumber(Minimap:GetScale()) or 1
    if s <= 0 then return 1 end
    return s
end

local function PositionByAngle(btn, angle)
    if not btn or not Minimap then return end
    local n = NormalizeAngle(angle)
    local r = GetOrbitRadius(btn)
    local rad = mathrad(n)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", mathcos(rad) * r, mathsin(rad) * r)
    btn.DragonUI_Angle = n
end

local function GetCursorAngle()
    if not Minimap or not GetCursorPosition then return nil end
    local cx, cy = Minimap:GetCenter()
    if not cx then return nil end
    local sc = (Minimap.GetEffectiveScale and Minimap:GetEffectiveScale()) or 1
    local mx, my = GetCursorPosition()
    local dx, dy = mx / sc - cx, my / sc - cy
    if dx == 0 and dy == 0 then return nil end
    local rad
    if mathatan2 then
        rad = mathatan2(dy, dx)
    else
        rad = mathatan(dy / (dx == 0 and 0.0001 or dx))
        if dx < 0 then rad = rad + mathpi
        elseif dy < 0 then rad = rad + 2 * mathpi end
    end
    return NormalizeAngle(mathdeg(rad))
end

local function ToggleInterfaceConfig()
    local a = deps.addon
    if not a then return end
    if a.OptionsPanel and a.OptionsPanel.Toggle then
        a.OptionsPanel:Toggle("general")
        return
    end
    if a.ToggleOptionsUI then a:ToggleOptionsUI("general") end
end

-- ----------------------------------------------------------------------------
-- Detect addon launcher buttons hidden via their own settings
-- ----------------------------------------------------------------------------
local function IsAddonMinimapButtonHidden(btn)
    if not btn then return false end
    if btn.db and btn.db.hide then return true end

    if btn.IsShown and not btn:IsShown() then
        local parent = btn:GetParent()
        return parent == Minimap or parent == MinimapBackdrop or btn.DragonUI_CollectorManaged or false
    end

    return false
end

local function ApplyCollectedButtonVisibility(btn, c)
    if not btn or not c then return end

    if IsAddonMinimapButtonHidden(btn) then
        btn:Hide()
        return
    end

    if c.isOpen then
        btn:Show()
    end
end

-- ----------------------------------------------------------------------------
-- Origin tracking (single subtable instead of many keys)
-- ----------------------------------------------------------------------------
local function RememberWrapperFrame(btn)
    local btnName = btn and btn.GetName and btn:GetName()
    if not btnName then return end

    local wrapperName = BUTTON_WRAPPER_FRAMES[btnName]
    if not wrapperName then return end

    local wrapper = _G[wrapperName]
    if not wrapper then return end

    btn.DragonUI_CollectorWrapper = wrapper
    btn.DragonUI_CollectorWrapperShown = wrapper:IsShown()
end

local function HideWrapperFrame(btn)
    local wrapper = btn and btn.DragonUI_CollectorWrapper
    if wrapper then
        wrapper:Hide()
    end
end

local function RestoreWrapperFrame(btn)
    local wrapper = btn and btn.DragonUI_CollectorWrapper
    if not wrapper then return end

    if btn.DragonUI_CollectorWrapperShown then
        wrapper:Show()
    else
        wrapper:Hide()
    end

    btn.DragonUI_CollectorWrapper = nil
    btn.DragonUI_CollectorWrapperShown = nil
end

local function RememberOrigin(btn)
    if btn.DragonUI_CollectorOrigin then return end
    local pts = {}
    for i = 1, btn:GetNumPoints() do pts[i] = { btn:GetPoint(i) } end
    local w, h = btn:GetSize()
    btn.DragonUI_CollectorOrigin = {
        parent = btn:GetParent(),
        strata = btn:GetFrameStrata(),
        level  = btn:GetFrameLevel(),
        shown  = not IsAddonMinimapButtonHidden(btn) and btn:IsShown(),
        alpha  = btn:GetAlpha(),
        scale  = btn:GetScale(),
        w = w, h = h,
        points = pts,
    }
    RememberWrapperFrame(btn)
end

local function RestoreOrigin(btn)
    local o = btn.DragonUI_CollectorOrigin
    if not o then return end
    RestoreWrapperFrame(btn)
    btn.DragonUI_CollectorManaged = nil
    btn.DragonUI_ForceCollectorAlpha = nil
    btn.DragonUI_CollectorIndex = nil
    btn.DragonUI_CollectorRepositioning = nil
    if o.parent then btn:SetParent(o.parent) end
    if o.strata then btn:SetFrameStrata(o.strata) end
    if o.level  then btn:SetFrameLevel(o.level) end
    if o.w and o.h then btn:SetSize(o.w, o.h) end
    if o.alpha then btn:SetAlpha(o.alpha) end
    if o.scale then btn:SetScale(o.scale) end
    btn:ClearAllPoints()
    if o.points then
        for _, p in ipairs(o.points) do btn:SetPoint(unpack(p)) end
    end
    if IsAddonMinimapButtonHidden(btn) or not o.shown then btn:Hide() else btn:Show() end
    btn.DragonUI_CollectorOrigin = nil
end

-- ----------------------------------------------------------------------------
-- Collector entries
-- ----------------------------------------------------------------------------
local function EntrySort(a, b) return strlower(a.title or "") < strlower(b.title or "") end

local function CollectEntries()
    if not IsEnabled() or not deps.GetAllMinimapButtons then return {} end

    local entries, seen = {}, {}
    local sbtn = GetSettingsBtn()
    local coll = GetCollector()
    local isQuest = deps.IsQuestMinimapPin

    local function tryAdd(child)
        if not child or child == sbtn or child == coll then return end
        if child.GetObjectType and child:GetObjectType() ~= "Button" then return end
        local childName = child.GetName and child:GetName()
        if childName and EXCLUDED_BUTTONS[childName] then return end
        if isQuest and isQuest(child) then return end

        if not child.DragonUI_CollectorManaged then
            local g = child.GetScript
            if not g or (g(child, "OnClick") == nil
                     and g(child, "OnMouseUp") == nil
                     and g(child, "OnMouseDown") == nil) then
                return
            end
        end

        if IsAddonMinimapButtonHidden(child) then
            -- Hook while hidden so OnHookedShow can grab it the moment it shows.
            HookButtonVisibility(child)
            return
        end

        if seen[child] then return end
        seen[child] = true
        entries[#entries + 1] = {
            title = (child.GetName and child:GetName()) or "Addon",
            button = child,
        }
    end

    for _, child in ipairs(deps.GetAllMinimapButtons()) do tryAdd(child) end
    for _, name in ipairs(INCLUDE_BUTTONS) do
        local c = _G[name]; if c then tryAdd(c) end
    end
    if coll then
        ForEachChild(coll, function(c)
            if c.DragonUI_CollectorManaged then tryAdd(c) end
        end)
    end

    tsort(entries, EntrySort)
    return entries
end

-- ----------------------------------------------------------------------------
-- Collector frame creation / styling
-- ----------------------------------------------------------------------------
local function CreateCollectorFrame()
    local frames = GetFrames()
    if not frames then return nil end
    if frames.iconCollector then return frames.iconCollector end

    local c = CreateFrame("Frame", "DragonUI_MinimapIconCollector", UIParent)
    c:SetFrameStrata("MEDIUM")
    c:SetFrameLevel(24)
    c:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    c:SetBackdropColor(0.08, 0.08, 0.10, 0.5)
    c:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)
    c:Hide()
    c.isOpen = false
    frames.iconCollector = c
    return c
end

local function ApplyCollectorStyle(c)
    if not c then return end

    if not c.classicBackground then
        local bg = c:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(WHITE_TEX)
        bg:SetAllPoints(c)
        bg:SetGradientAlpha("HORIZONTAL", 0.1, 0.1, 0.1, 0, 0.1, 0.1, 0.1, 0.7)
        c.classicBackground = bg

        local function mkBorder()
            local t = c:CreateTexture(nil, "OVERLAY")
            t:SetTexture(WHITE_TEX)
            t:SetVertexColor(1, 0.82, 0, 1)
            return t
        end
        local top, bot, right = mkBorder(), mkBorder(), mkBorder()

        top:SetPoint("BOTTOMLEFT",  c, "TOPLEFT", 0, 0)
        top:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", 0, 0)
        top:SetHeight(1)
        top:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0, 1, 0.82, 0, 1)

        bot:SetPoint("TOPLEFT",  c, "BOTTOMLEFT", 0, 0)
        bot:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", 0, 0)
        bot:SetHeight(1)
        bot:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0, 1, 0.82, 0, 1)

        right:SetPoint("TOPLEFT",    c, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMLEFT", c, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(1)

        c.classicTopBorder, c.classicBottomBorder, c.classicRightBorder = top, bot, right
    end

    -- Original behavior: both styles show the same background/borders.
    c.classicBackground:Show()
    c.classicTopBorder:Show()
    c.classicBottomBorder:Show()
    c.classicRightBorder:Show()
    c:SetBackdropColor(0, 0, 0, 0)
    c:SetBackdropBorderColor(0, 0, 0, 0)
end

local function PositionCollector()
    local c = GetCollector()
    if not c then return end

    c:SetScale(GetMinimapScale())
    c:ClearAllPoints()

    if GetStyle() == STYLE_CLASSIC then
        c:SetPoint("RIGHT", Minimap, "LEFT", -5, 0)
        return
    end

    local sbtn = GetSettingsBtn()
    if sbtn then c:SetPoint("TOPRIGHT", sbtn, "TOPLEFT", -5, 0) end
end

local function ResizeCollector(c, count)
    local classic = GetStyle() == STYLE_CLASSIC
    local skin    = IsSkinEnabled()

    if count <= 0 then
        if classic then c:SetSize(200, 60) else c:SetSize(30, 30) end
        return
    end

    if classic then
        local perCol = 3
        local cols = mathceil(count / perCol)
        if skin then
            c:SetSize(34 + cols * 24, mathmax(28, 13 + mathmin(count, perCol) * 24))
        else
            c:SetSize(42 + cols * 28, mathmax(30, 15 + mathmin(count, perCol) * 28))
        end
    else
        local perRow = 5
        local rows = mathceil(count / perRow)
        local cols = mathmin(count, perRow)
        if skin then
            c:SetSize(cols * 28 + 12, rows * 28 + 12)
        else
            c:SetSize(cols * 31 + 14, rows * 31 + 14)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Open/close animation - single shared OnUpdate driver
-- ----------------------------------------------------------------------------
local function StopAnim(c)
    if not c then return end
    c:SetScript("OnUpdate", nil)
    c.DragonUI_Anim = nil
end

local function AnimUpdate(self, elapsed)
    local s = self.DragonUI_Anim
    if not s then self:SetScript("OnUpdate", nil); return end

    s.t = s.t + elapsed
    local p = s.t / s.dur
    if p > 1 then p = 1 end
    local ease = 1 - (1 - p) * (1 - p)
    local w = s.fromW + (s.toW - s.fromW) * ease

    self:SetWidth(w)
    if s.opening then
        self:SetAlpha(0.2 + 0.8 * p)
    else
        self:SetAlpha(1 - p)
    end

    if p >= 1 then
        if s.opening then
            self:SetWidth(s.toW)
            self:SetAlpha(1)
        else
            self:SetAlpha(1)
            self:Hide()
        end
        StopAnim(self)
    end
end

local function ShowAnimated(c)
    if not c then return end
    local targetW, targetH = c:GetWidth(), c:GetHeight()
    local startW = mathmax(1, targetW * ANIM_SHRINK)
    StopAnim(c)
    c:SetWidth(startW)
    c:SetHeight(targetH)
    c:SetAlpha(0)
    c:Show()
    c.DragonUI_Anim = { t = 0, dur = ANIM_DURATION, fromW = startW, toW = targetW, opening = true }
    c:SetScript("OnUpdate", AnimUpdate)
end

local function HideAnimated(c)
    if not c then return end
    local startW = c:GetWidth()
    local targetW = mathmax(1, startW * ANIM_SHRINK)
    StopAnim(c)
    c:SetAlpha(1)
    c:Show()
    c.DragonUI_Anim = { t = 0, dur = ANIM_DURATION, fromW = startW, toW = targetW, opening = false }
    c:SetScript("OnUpdate", AnimUpdate)
end

-- ----------------------------------------------------------------------------
-- Collected button placement
-- ----------------------------------------------------------------------------
local function NormalizeSkinned(btn)
    if btn.DragonUI_NormalizingCollectorSize then return end
    btn.DragonUI_NormalizingCollectorSize = true
    btn:SetScale(1)
    btn:SetSize(21, 21)
    if btn.circle then
        btn.circle:SetSize(25, 25)
        btn.circle:ClearAllPoints()
        btn.circle:SetPoint("CENTER", btn, "CENTER", 0, 0)
    end
    btn.DragonUI_NormalizingCollectorSize = nil
end

local function ClampUnskinnedCollectorButton(btn)
    if btn.DragonUI_NormalizingCollectorSize then return end

    local w, h = btn:GetSize()
    if not w or w <= 0 then w = 31 end
    if not h or h <= 0 then h = 31 end

    -- Keep non-skinned collector cells consistent and avoid oversized outliers (e.g. 33x33 icons).
    if w <= 31 and h <= 31 then return end

    btn.DragonUI_NormalizingCollectorSize = true
    btn:SetScale(1)
    btn:SetSize(mathmin(31, w), mathmin(31, h))
    btn.DragonUI_NormalizingCollectorSize = nil
end

local function RestoreCollectedToOrigin()
    local c = GetCollector()
    if not c then return end
    ForEachChild(c, RestoreOrigin)
    c.isOpen = false
    c:Hide()
end

local function OnHookedShow(self)
    local m = GetModule()
    if not m or not m.applied then return end
    if IsAddonMinimapButtonHidden(self) then
        self:Hide()
        return
    end
    -- Reflow immediately so the grid stays compact and in sync.
    local c = GetCollector()
    if c and self:GetParent() == c then
        if c.isOpen then RefreshCollector() else self:Hide() end
    elseif self.DragonUI_CollectorManaged then
        self:Hide()
    elseif self.DragonUI_CollectorVisibilityHooked then
        -- First time visible after always being hidden: grab it now.
        RefreshCollector()
    end
end

local function OnHookedHide(self)
    local m = GetModule()
    if not m or not m.applied then return end
    if not self.DragonUI_CollectorManaged then return end

    local c = GetCollector()
    if c and self:GetParent() == c and c.isOpen then
        RefreshCollector()
    end
end

HookButtonVisibility = function(btn)
    if btn.DragonUI_CollectorVisibilityHooked then return end
    btn.DragonUI_CollectorVisibilityHooked = true
    btn:HookScript("OnShow", OnHookedShow)
    btn:HookScript("OnHide", OnHookedHide)
end

local function PositionCollectedButton(btn, c, index, skin)
    if GetStyle() == STYLE_CLASSIC then
        local perCol = 3
        local row = (index - 1) % perCol
        local col = mathfloor((index - 1) / perCol)
        local spacing = skin and 24 or 28
        local padding = skin and 5 or 6
        local nudge   = skin and 3 or 0
        local offX = -padding - col * spacing - nudge
        local offY = -padding - row * spacing - nudge
        btn:SetPoint("TOPRIGHT", c, "TOPRIGHT", offX, offY)
        return
    end

    local perRow = 5
    local col = (index - 1) % perRow
    local row = mathfloor((index - 1) / perRow)
    local cell = skin and 28 or 31
    local pad  = skin and 6 or 7
    local bw, bh = btn:GetSize()
    if not bw or bw <= 0 then bw = 31 end
    if not bh or bh <= 0 then bh = 31 end
    local offX = -((col * cell) + pad + (cell - bw) * 0.5)
    local offY = -((row * cell) + pad + (cell - bh) * 0.5)
    btn:SetPoint("TOPRIGHT", c, "TOPRIGHT", offX, offY)
end

local function EnforceCollectedButtonPlacement(btn)
    if not btn or not btn.DragonUI_CollectorManaged or btn.DragonUI_CollectorRepositioning then
        return
    end

    local c = GetCollector()
    if not c then
        return
    end

    local anchoredToCollector = false
    if btn:GetNumPoints() > 0 then
        anchoredToCollector = (select(2, btn:GetPoint(1)) == c)
    end

    if btn:GetParent() == c and anchoredToCollector then
        return
    end

    btn.DragonUI_CollectorRepositioning = true
    btn:SetParent(c)
    btn:SetFrameStrata(c:GetFrameStrata())
    btn:SetFrameLevel(c:GetFrameLevel() + 2)
    btn:ClearAllPoints()
    if not IsSkinEnabled() then
        ClampUnskinnedCollectorButton(btn)
    end
    PositionCollectedButton(btn, c, btn.DragonUI_CollectorIndex or 1, IsSkinEnabled())
    btn:SetAlpha(1)
    ApplyCollectedButtonVisibility(btn, c)
    btn.DragonUI_CollectorRepositioning = nil
end

local function OnCollectedButtonSetParent(self)
    EnforceCollectedButtonPlacement(self)
end

local function HookCollectedButtonPlacement(btn)
    if not btn or btn.DragonUI_CollectorPlacementHooked or not hooksecurefunc then
        return
    end

    btn.DragonUI_CollectorPlacementHooked = true
    hooksecurefunc(btn, "SetParent", OnCollectedButtonSetParent)
end

local function PlaceCollectedButton(btn, c, index)
    if not btn or not c then return end

    local skin = IsSkinEnabled()
    local styleKey = (GetStyle() == STYLE_CLASSIC and "classic" or "dragonui") .. ":" .. (skin and "1" or "0")
    local sameLayout = btn.DragonUI_CollectorManaged
        and btn:GetParent() == c
        and btn.DragonUI_CollectorIndex == index
        and btn.DragonUI_CollectorStyleKey == styleKey

    HookButtonVisibility(btn)
    HookCollectedButtonPlacement(btn)
    RememberOrigin(btn)

    btn:EnableMouse(true)
    btn.DragonUI_CollectorManaged = true
    btn.DragonUI_CollectorIndex = index
    btn.DragonUI_CollectorStyleKey = styleKey
    btn:SetParent(c)
    ApplyCollectorCompatibilityFix(btn, c)
    btn:SetFrameStrata(c:GetFrameStrata())
    btn:SetFrameLevel(c:GetFrameLevel() + 2)
    btn:SetAlpha(1)
    btn:ClearAllPoints()

    if not sameLayout then
        if skin then
            if deps.ApplyAddonIconSkin then deps.ApplyAddonIconSkin(btn) end
            NormalizeSkinned(btn)
        elseif btn.DragonUI_Skinned and deps.UnskinAddonButton then
            deps.UnskinAddonButton(btn)
        end

        if not skin then
            ClampUnskinnedCollectorButton(btn)
        end
    end

    PositionCollectedButton(btn, c, index, skin)
    HideWrapperFrame(btn)

    ApplyCollectedButtonVisibility(btn, c)
end

-- ----------------------------------------------------------------------------
-- Collector lifecycle
-- ----------------------------------------------------------------------------
local function HideCollectorImmediate()
    local c = GetCollector()
    if not c then return end
    StopAnim(c)
    c.isOpen = false
    c.DragonUI_PendingTransition = nil
    c:Hide()
end

local function RefreshAddonButtonsAfterDisable()
    if not deps.GetAllMinimapButtons then return end
    local skin = IsSkinEnabled()
    local fade = (deps.IsFadeEnabled and deps.IsFadeEnabled()) or false
    local isQuest = deps.IsQuestMinimapPin

    for _, child in ipairs(deps.GetAllMinimapButtons()) do
        if not isQuest or not isQuest(child) then
            if skin then
                if deps.ApplyAddonIconSkin then deps.ApplyAddonIconSkin(child) end
            elseif child.DragonUI_Skinned and deps.UnskinAddonButton then
                deps.UnskinAddonButton(child)
            end

            if not child.DragonUI_FadeHooked then
                child.DragonUI_FadeHooked = true
                if deps.fadein  then child:HookScript("OnEnter", deps.fadein) end
                if deps.fadeout then child:HookScript("OnLeave", deps.fadeout) end
            end
            child:SetAlpha(fade and 0.2 or 1)
        end
    end
end

local function RefreshCollectorImpl()
    if not IsEnabled() then
        RestoreCollectedToOrigin()
        HideCollectorImmediate()
        return
    end

    local c = CreateCollectorFrame()
    if not c then return end

    local entries = CollectEntries()
    ApplyCollectorStyle(c)
    PositionCollector()
    ResizeCollector(c, #entries)

    local placed = {}
    for i, e in ipairs(entries) do
        PlaceCollectedButton(e.button, c, i)
        placed[e.button] = true
    end

    ForEachChild(c, function(child)
        if child.DragonUI_CollectorManaged and not placed[child] then
            -- Still addon-hidden: park it hidden instead of restoring it.
            if IsAddonMinimapButtonHidden(child) then
                child:Hide()
            else
                RestoreOrigin(child)
            end
        end
    end)

    if #entries == 0 then
        StopAnim(c)
        c.isOpen = false
        c.DragonUI_PendingTransition = nil
        c:Hide()
        return
    end

    if c.isOpen then
        if c.DragonUI_PendingTransition == "open" then
            c.DragonUI_PendingTransition = nil
            ShowAnimated(c)
        else
            StopAnim(c)
            c:SetAlpha(1)
            c:Show()
        end
    else
        if c.DragonUI_PendingTransition == "close" then
            c.DragonUI_PendingTransition = nil
            HideAnimated(c)
        else
            StopAnim(c)
            c:SetAlpha(1)
            c:Hide()
        end
    end
end

RefreshCollector = function()
    if isRefreshingCollector then return end
    isRefreshingCollector = true
    RefreshCollectorImpl()
    isRefreshingCollector = false
end

local function ToggleCollector()
    if not IsEnabled() then return end
    local c = CreateCollectorFrame()
    if not c then return end
    c.isOpen = not c.isOpen
    c.DragonUI_PendingTransition = c.isOpen and "open" or "close"
    RefreshCollector()
end

-- ----------------------------------------------------------------------------
-- Settings button scripts (named, no closures over local btn)
-- ----------------------------------------------------------------------------
local function OnSettingsClick(self, mouseBtn)
    if self.DragonUI_SuppressClickUntil and GetTime and GetTime() < self.DragonUI_SuppressClickUntil then
        return
    end
    if mouseBtn == "RightButton" then
        ToggleInterfaceConfig()
    else
        ToggleCollector()
        UpdateHighlightStyle(self)
    end
end

local function OnSettingsMouseDown(self, mouseBtn)
    if GetStyle() ~= STYLE_DUI then return end
    self.DragonUI_PressZoom = true
    LayoutSettingsIcon(self, true)
    PlayCircleClick(self)
end

local function OnSettingsMouseUp(self)
    self.DragonUI_PressZoom = nil
    LayoutSettingsIcon(self, false)
end

local function OnSettingsEnter(self)
    if IsSettingsButtonFadeEnabled() and deps.fadein then
        deps.fadein(self)
    else
        self:SetAlpha(1)
    end
    UpdateHighlightStyle(self)

    if not GameTooltip then return end
    local L = deps.L
    local style = GetStyle()
    if style == STYLE_CLASSIC then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("RIGHT", self, "LEFT", 3, -85)
    else
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    end
    GameTooltip:SetText((L and L["Minimap Buttons"]) or "Minimap Buttons")
    GameTooltip:AddLine((L and L["Left-click to show or hide minimap addon buttons."])
        or "Left-Click to open minimap buttons.", 1, 0.82, 0, true)
    GameTooltip:AddLine((L and L["Right-click to open DragonUI settings."])
        or "Right-click to open DragonUI settings.", 1, 0.82, 0, true)
    if style == STYLE_DUI then
        GameTooltip:AddLine((L and L["Drag to move"]) or "Drag to move", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

local function OnSettingsLeave(self)
    self.DragonUI_PressZoom = nil
    LayoutSettingsIcon(self, false)
    if IsSettingsButtonFadeEnabled() and deps.fadeout then
        deps.fadeout(self)
    else
        self:SetAlpha(1)
    end
    UpdateHighlightStyle(self)
    if GameTooltip then GameTooltip:Hide() end
end

local function OnDragUpdate(self)
    local a = GetCursorAngle()
    if a then
        PositionByAngle(self, a)
        SetStoredAngle(a)
        PositionCollector()
        if self.DragonUI_PressZoom then
            self.DragonUI_PressZoom = nil
            LayoutSettingsIcon(self, false)
        end
        self.DragonUI_DragMoved = true
    end
end

local function OnDragStart(self)
    if GetStyle() ~= STYLE_DUI then return end
    self.DragonUI_Dragging = true
    self.DragonUI_DragMoved = false
    local a = GetCursorAngle()
    if a then
        PositionByAngle(self, a)
        SetStoredAngle(a)
        PositionCollector()
    end
    self:SetScript("OnUpdate", OnDragUpdate)
end

local function OnDragStop(self)
    if GetStyle() ~= STYLE_DUI then return end
    self.DragonUI_Dragging = false
    self.DragonUI_PressZoom = nil
    self:SetScript("OnUpdate", nil)
    LayoutSettingsIcon(self, false)
    PositionCollector()
    if self.DragonUI_DragMoved and GetTime then
        self.DragonUI_SuppressClickUntil = GetTime() + 0.2
    end
end

local function CreateSettingsButton()
    local frames = GetFrames()
    if not frames then return nil end
    if frames.settingsButton then return frames.settingsButton end

    local size = deps.DRAGONUI_SETTINGS_BUTTON_SIZE
    local btn = CreateFrame("Button", "DragonUI_MinimapSettingsButton", Minimap)
    btn:SetFrameStrata(Minimap:GetFrameStrata())
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 20)
    btn:SetSize(size, size)
    btn:SetScale(1)
    btn:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetHitRectInsets(0, 0, 0, 0)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    SetSettingsIcon(icon)
    btn.icon = icon

    local ringFrame = CreateFrame("Frame", nil, btn)
    ringFrame:SetFrameLevel(btn:GetFrameLevel() + 6)
    local ring = ringFrame:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(ringFrame)
    ring:SetTexture(BORDER_TEX)
    ring:SetVertexColor(1, 0.82, 0.28)
    btn.ringFrame = ringFrame
    btn.circle = ring

    EnsureHighlight(btn)
    EnsureClassicGlow(btn)
    LayoutSettingsIcon(btn, false)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnClick",     OnSettingsClick)
    btn:SetScript("OnMouseDown", OnSettingsMouseDown)
    btn:SetScript("OnMouseUp",   OnSettingsMouseUp)
    btn:SetScript("OnEnter",     OnSettingsEnter)
    btn:SetScript("OnLeave",     OnSettingsLeave)
    btn:SetScript("OnDragStart", OnDragStart)
    btn:SetScript("OnDragStop",  OnDragStop)

    frames.settingsButton = btn
    return btn
end

local function ApplyClassicStyle(btn)
    local prev = btn.DragonUI_LastStyle
    btn:SetScript("OnUpdate", nil)
    btn.DragonUI_Dragging = false
    btn.DragonUI_DragMoved = false
    btn:SetSize(21, 21)
    btn:SetScale(1)
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", Minimap, "LEFT", 16.5, -2)

    if btn.icon then
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        SetClassicIcon(btn.icon)
    end
    if btn.ringFrame then btn.ringFrame:Hide() end

    UpdateHighlightStyle(btn)
    btn.DragonUI_LastStyle = STYLE_CLASSIC

    if prev == STYLE_DUI or prev == "disabled" then
        PlayClassicAttention(btn)
    end
end

local function ApplyDUIStyle(btn)
    btn:SetSize(deps.DRAGONUI_SETTINGS_BUTTON_SIZE, deps.DRAGONUI_SETTINGS_BUTTON_SIZE)
    btn:SetScale(1)
    if btn.ringFrame then btn.ringFrame:Show() end
    if btn.icon then
        SetSettingsIcon(btn.icon)
        LayoutSettingsIcon(btn, false)
    end
    UpdateHighlightStyle(btn)
    btn.DragonUI_LastStyle = STYLE_DUI
    PositionByAngle(btn, GetStoredAngle())
end

local function ApplySettingsStyle(btn)
    if not btn then return end
    if GetStyle() == STYLE_CLASSIC then ApplyClassicStyle(btn) else ApplyDUIStyle(btn) end
end

local function UpdateSettingsButton()
    local btn = CreateSettingsButton()
    if not btn then return end

    if not IsEnabled() then
        btn:SetScript("OnUpdate", nil)
        btn.DragonUI_LastStyle = "disabled"
        btn:Hide()
        RestoreCollectedToOrigin()
        HideCollectorImmediate()
        RefreshAddonButtonsAfterDisable()
        return
    end

    ApplySettingsStyle(btn)
    PositionCollector()

    local managedByCompatibility = ApplyCollectorToggleVisibilityCompatibility(btn)
    if not managedByCompatibility then
        btn:SetAlpha(IsSettingsButtonFadeEnabled() and 0.2 or 1)
    end

    btn:Show()
    RefreshCollector()
end

-- ----------------------------------------------------------------------------
-- Public API
-- ----------------------------------------------------------------------------
function Collector:Configure(newDeps)
    deps = newDeps or deps
    self._deps = deps
end

function Collector:Refresh()                    RefreshCollector() end
function Collector:Toggle()                     ToggleCollector() end
function Collector:Hide()                       HideCollectorImmediate() end
function Collector:Restore()                    RestoreCollectedToOrigin() end
function Collector:HideIntegratedAddonButtons() RefreshCollector() end
function Collector:UpdateSettingsButton()       UpdateSettingsButton() end
