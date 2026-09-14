-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local L = addon.L
local T = addon.TalentModule

local SOCKET_COUNT = 6
local GLYPH_DOT_SIZE = 4
local GLYPH_NAME_PREFIX = "Glyph of "

local TEX = addon._dir .. "Talents\\"
local GLYPH_RING_TEXTURE = TEX .. "glyph-ring-gold.tga"
local GLYPH_RING_DESAT_TEXTURE = TEX .. "glyph-ring-desat.tga"
local RING_ART_FRAC = 0.66
local GLOBE_HEALTH = TEX .. "glyph-globe-health.tga"
local GLOBE_MANA   = TEX .. "glyph-globe-mana.tga"
local GLYPH_GLOSS_TEXTURE = TEX .. "glyph-orbgloss.tga"
local GLYPH_SHADOW_TEXTURE = TEX .. "glyph-shadow.tga"
local GLOBE_FRAMES, GLOBE_COLS, GLOBE_FW, GLOBE_STRIDE, GLOBE_SHEET = 67, 11, 350, 352, 4096

local function globeCoord(i)
    local col = (i - 1) % GLOBE_COLS
    local row = math.floor((i - 1) / GLOBE_COLS)
    local x, y = col * GLOBE_STRIDE, 1 + row * GLOBE_STRIDE
    return x / GLOBE_SHEET, (x + GLOBE_FW) / GLOBE_SHEET, y / GLOBE_SHEET, (y + GLOBE_FW) / GLOBE_SHEET
end

local glyphGlobes = {}
local globeFrameIndex = 1
local function ensureGlobeTicker()
    if T._globeTicker then return end
    T._globeTicker = true
    local ticker = CreateFrame("Frame")
    local acc = 0
    ticker:SetScript("OnUpdate", function(self, dt)
        acc = acc + (dt or 0)
        if acc < 1 / 30 then return end
        acc = 0
        if not (T.GlyphsIsActive and T.GlyphsIsActive()) then return end
        globeFrameIndex = globeFrameIndex % GLOBE_FRAMES + 1
        local l, r, t, b = globeCoord(globeFrameIndex)
        for i = 1, #glyphGlobes do
            local g = glyphGlobes[i]
            if g:IsShown() then g:SetTexCoord(l, r, t, b) end
        end
    end)
end

local GLOBE_SCALE = 1.00
local RING_SCALE  = 1.8

local function configGlobe(button, isMajor, lit, size)
    local g = button and button.Globe
    if not g then return end
    g:SetTexture(isMajor and GLOBE_HEALTH or GLOBE_MANA)
    local d = size * GLOBE_SCALE
    g:SetSize(d, d)
    if g.SetDesaturated then g:SetDesaturated(not lit) end
    g:SetAlpha(lit and 1 or 0.45)
    g:Show()
    local gs = button.Gloss
    if gs then
        gs:SetTexture(GLYPH_GLOSS_TEXTURE)
        gs:SetSize(d * 1.2, d * 1.2)
        gs:SetAlpha(lit and 0.8 or 0.5)
        gs:Show()
    end
end

local root
local panes = {}
local glyphOptionsMenu

T._glyphActive = (T._glyphActive ~= nil) and T._glyphActive or false

local function glyphLabelNamesEnabled()
    local cfg = addon:GetModuleConfig("talents")
    return (cfg and cfg.talentGlyphSlotNames) and true or false
end
local function setGlyphLabelNamesEnabled(enabled)
    local cfg = addon:GetModuleConfig("talents")
    if cfg then cfg.talentGlyphSlotNames = enabled and true or false end
end
local function glyphShowEffectsEnabled()
    local cfg = addon:GetModuleConfig("talents")
    if not cfg or cfg.talentGlyphShowEffects == nil then return true end
    return cfg.talentGlyphShowEffects and true or false
end
local function setGlyphShowEffectsEnabled(enabled)
    local cfg = addon:GetModuleConfig("talents")
    if cfg then cfg.talentGlyphShowEffects = enabled and true or false end
end

-- ============================================================================
-- Glyph name trimming + display names
-- ============================================================================
local function trimGlyphPrefix(name)
    if type(name) ~= "string" then return nil end
    local trimmed = name:gsub("^Glyph%s+[Oo]f%s+", "")
    if trimmed == "" then return name end
    if trimmed ~= name then return trimmed end
    if name:sub(1, #GLYPH_NAME_PREFIX) == GLYPH_NAME_PREFIX then
        return name:sub(#GLYPH_NAME_PREFIX + 1)
    end
    return name
end

local function glyphDisplayName(info, fallbackSpellName)
    if not info then return nil end
    local itemName
    if info.link and GetItemInfo then itemName = GetItemInfo(info.link) end
    if (not itemName) and type(info.link) == "string" then itemName = info.link:match("%[(.-)%]") end
    return trimGlyphPrefix(itemName or fallbackSpellName)
end

-- ============================================================================
-- Deferred refresh driver
-- ============================================================================
local refreshDriver
local function queueGlyphRefresh(passes)
    passes = tonumber(passes) or 1
    if passes < 1 then return end
    if not refreshDriver then
        refreshDriver = CreateFrame("Frame")
        refreshDriver:Hide()
    end
    refreshDriver._remaining = math.max(refreshDriver._remaining or 0, passes)
    refreshDriver:SetScript("OnUpdate", function(self)
        self._remaining = (self._remaining or 1) - 1
        if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
        if T.GlyphsApplyPaneVisibility then pcall(T.GlyphsApplyPaneVisibility) end
        if self._remaining <= 0 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
    refreshDriver:Show()
end

if not T.registeredEvents["GLYPH_EVENTS"] then
    T.registeredEvents["GLYPH_EVENTS"] = true
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED", "USE_GLYPH", "ACTIVE_TALENT_GROUP_CHANGED" }) do
        pcall(function() ev:RegisterEvent(e) end)
    end
    ev:SetScript("OnEvent", function()
        if not T.applied then return end
        if T.GlyphsIsActive and T.GlyphsIsActive() then queueGlyphRefresh(2) end
    end)
end

if not StaticPopupDialogs["DUI_GLYPH_REMOVE_CONFIRM"] then
    StaticPopupDialogs["DUI_GLYPH_REMOVE_CONFIRM"] = {
        text = L["Remove this glyph?"] or "Remove this glyph?",
        button1 = ACCEPT, button2 = CANCEL,
        OnAccept = function(self, data)
            local button = data and data.button
            local info = button and button._glyphInfo
            if not (info and info.socket) then return end
            if type(_G.RemoveGlyphFromSocket) == "function" then
                local ok = pcall(_G.RemoveGlyphFromSocket, info.socket)
                if ok then
                    button._hasGlyph = nil
                    if button.Icon then button.Icon:SetTexture(nil) end
                    if button.IconTint then button.IconTint:Hide() end
                    if button.Glow then button.Glow:Hide() end
                    local socket, group = info.socket, info.group
                    local tries = 0
                    local function poll()
                        tries = tries + 1
                        local _, _, glyphSpell = GetGlyphSocketInfo(socket, group)
                        local cleared = not (type(glyphSpell) == "number" and glyphSpell > 0)
                        if cleared or tries >= 25 then
                            if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
                        else
                            addon:After(0.15, poll)
                        end
                    end
                    addon:After(0.15, poll)
                end
            end
        end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = STATICPOPUP_NUMDIALOGS,
    }
end

local function setAtlas(tex, atlas, fallbackTexture)
    if tex and tex.set_atlas and atlas then
        if tex:set_atlas(atlas, true) then return true end
    end
    if tex and fallbackTexture and tex.SetTexture then
        tex:SetTexture(fallbackTexture)
    end
    return false
end

-- ============================================================================
-- Glyph socket connection edges (static: no marching animation)
-- ============================================================================
local function resetPaneEdges(pane)
    if not pane then return end
    pane._edgeN = 0
    pane._glyphEdges = pane._glyphEdges or {}
    for i = 1, #pane._glyphEdges do pane._glyphEdges[i] = nil end
end

local function acquirePaneDot(pane)
    pane._edgeN = (pane._edgeN or 0) + 1
    pane.edgePool = pane.edgePool or {}
    local d = pane.edgePool[pane._edgeN]
    if not d then
        d = pane:CreateTexture(nil, "ARTWORK", nil, -2)
        pane.edgePool[pane._edgeN] = d
    end
    d:SetTexture("Interface\\Buttons\\WHITE8X8")
    d:SetTexCoord(0, 1, 0, 1)
    d:Show()
    return d
end

local function hideUnusedPaneDots(pane)
    if not (pane and pane.edgePool) then return end
    for i = (pane._edgeN or 0) + 1, #pane.edgePool do pane.edgePool[i]:Hide() end
end

local function drawPaneEdge(pane, startButton, endButton, color)
    if not (pane and startButton and endButton) then return end
    local sx, sy = startButton:GetCenter()
    local ex, ey = endButton:GetCenter()
    local px, py = pane:GetCenter()
    if not (sx and sy and ex and ey and px and py) then return end
    sx, sy = sx - px, sy - py
    ex, ey = ex - px, ey - py
    local dx, dy = ex - sx, ey - sy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end
    local ux, uy = dx / dist, dy / dist
    local startRadius = (startButton.Border and startButton.Border:GetWidth() or startButton:GetWidth() or 0) * 0.5 * RING_ART_FRAC
    local endRadius = (endButton.Border and endButton.Border:GetWidth() or endButton:GetWidth() or 0) * 0.5 * RING_ART_FRAC
    local x0, y0 = sx + ux * startRadius, sy + uy * startRadius
    local span = dist - startRadius - endRadius
    if span <= 0 then return end
    if math.abs(dx) < 0.5 or math.abs(dy) < 0.5 then
        local horizontal = math.abs(dx) >= math.abs(dy)
        local d = acquirePaneDot(pane)
        d:SetSize(horizontal and span or GLYPH_DOT_SIZE, (horizontal and GLYPH_DOT_SIZE) or span)
        d:SetVertexColor(color[1], color[2], color[3], color[4])
        d:ClearAllPoints()
        d:SetPoint("CENTER", pane, "CENTER", x0 + ux * (span / 2), y0 + uy * (span / 2))
        pane._glyphEdges[#pane._glyphEdges + 1] =
            { parent = pane, x0 = x0, y0 = y0, ux = ux, uy = uy, span = span, gap = 0, dots = { d } }
        return
    end
    local step = 2
    local n = math.max(1, math.floor((span - 2 * step) / step) + 1)
    local dots = {}
    local tEnd = span - step
    for i = 0, n - 1 do
        local t = step + i * step
        if t > tEnd then t = tEnd end
        local d = acquirePaneDot(pane)
        d:SetSize(GLYPH_DOT_SIZE, GLYPH_DOT_SIZE)
        d:SetVertexColor(color[1], color[2], color[3], color[4])
        d:ClearAllPoints()
        d:SetPoint("CENTER", pane, "CENTER", x0 + ux * t, y0 + uy * t)
        dots[#dots + 1] = d
    end
    pane._glyphEdges[#pane._glyphEdges + 1] =
        { parent = pane, x0 = x0, y0 = y0, ux = ux, uy = uy, span = span, gap = step, dots = dots }
end

local function updatePaneEdges(pane, activePane)
    if not pane then return end
    resetPaneEdges(pane)
    if not T._glyphActive then hideUnusedPaneDots(pane); return end
    local majorColor = activePane and { 1.0, 0.84, 0.18, 0.95 } or { 0.62, 0.49, 0.24, 0.45 }
    local minorColor = activePane and { 1.0, 0.84, 0.18, 0.72 } or { 0.62, 0.49, 0.24, 0.32 }
    local sockets = pane.sockets
    drawPaneEdge(pane, sockets[1], sockets[3], majorColor)
    drawPaneEdge(pane, sockets[3], sockets[5], majorColor)
    drawPaneEdge(pane, sockets[5], sockets[1], majorColor)
    drawPaneEdge(pane, sockets[2], sockets[4], minorColor)
    drawPaneEdge(pane, sockets[4], sockets[6], minorColor)
    drawPaneEdge(pane, sockets[6], sockets[2], minorColor)
    hideUnusedPaneDots(pane)
end

-- ============================================================================
-- Pane background + spec background nickname
-- ============================================================================
local function applyPaneBackground(pane)
    if not (pane and pane.bg and pane._bgNick) then return end
    local nick = pane._bgNick
    if nick and pane.bg.set_atlas then pane.bg:set_atlas(nick, false) end
end

local function specBackgroundNick(group)
    local bestTab, bestSpent = 1, -1
    local tabCount = (GetNumTalentTabs and GetNumTalentTabs(false, false)) or 0
    for tab = 1, tabCount do
        local spent = 0
        local numTalents = (GetNumTalents and GetNumTalents(tab, false, false)) or 0
        if GetTalentInfo then
            for i = 1, numTalents do
                local _, _, _, _, rank, _, _, _, previewRank = GetTalentInfo(tab, i, false, false, group)
                spent = spent + (previewRank or rank or 0)
            end
        else
            local _, _, tabSpent = GetTalentTabInfo and GetTalentTabInfo(tab, false, false, group)
            spent = tabSpent or 0
        end
        if spent > bestSpent then bestSpent = spent; bestTab = tab end
    end
    return T.BackgroundNick and T.BackgroundNick(bestTab) or nil
end

-- ============================================================================
-- Glyph data getters
-- ============================================================================
local function getGlyphLink(socket, group)
    if not GetGlyphLink then return nil end
    local ok, link = pcall(GetGlyphLink, socket, group)
    if ok and link and link ~= "" then return link end
    ok, link = pcall(GetGlyphLink, socket)
    if ok and link and link ~= "" then return link end
    return nil
end

local function getSocketInfo(socket, group)
    if not GetGlyphSocketInfo then return nil end
    local enabled, glyphType, r3, r4, r5 = GetGlyphSocketInfo(socket, group)
    local glyphSpellID, icon
    if (type(r4) == "string" or type(r4) == "number") and r5 == nil then
        glyphSpellID = r3; icon = r4
    else
        glyphSpellID = r4; icon = r5
    end
    return {
        socket = socket, enabled = enabled and true or false, glyphType = glyphType,
        glyphSpellID = glyphSpellID, icon = icon, link = getGlyphLink(socket, group),
    }
end

local function emptyGlyphIcon(glyphType)
    if glyphType == 2 then return "Interface\\Icons\\INV_Glyph_MinorGlyph" end
    return "Interface\\Icons\\INV_Glyph_MajorGlyph"
end

local function getStockGlyphSocket(button)
    local info = button and button._glyphInfo
    if not (info and info.socket) then return nil end
    if not ((addon.IsAddOnLoaded and addon.IsAddOnLoaded("Blizzard_GlyphUI")) or _G.GlyphFrame) then
        if type(_G.LoadAddOn) == "function" then pcall(_G.LoadAddOn, "Blizzard_GlyphUI") end
    end
    return _G["GlyphFrameGlyph" .. tostring(info.socket)]
end

-- ============================================================================
-- Socket tooltip (delegates to the stock glyph frame when possible)
-- ============================================================================
local function copyTooltipToButton(button)
    if not (button and GameTooltip and GameTooltip:IsShown()) then return false end
    local lines = {}
    local numLines = GameTooltip:NumLines() or 0
    for i = 1, numLines do
        local left = _G["GameTooltipTextLeft" .. i]
        if left and left.GetText then
            local text = left:GetText()
            if text and text ~= "" then
                local r, g, b = left:GetTextColor()
                lines[#lines + 1] = { text = text, r = r or 1, g = g or 1, b = b or 1 }
            end
        end
    end
    if #lines == 0 then return false end
    GameTooltip:Hide()
    GameTooltip:SetOwner(button, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", button, "TOPRIGHT", 3, 2)
    GameTooltip:SetText(lines[1].text, lines[1].r, lines[1].g, lines[1].b)
    for i = 2, #lines do GameTooltip:AddLine(lines[i].text, lines[i].r, lines[i].g, lines[i].b, true) end
    GameTooltip:Show()
    return true
end

local function tooltipForSocket(button)
    local info = button._glyphInfo
    if not info then return end
    local stock = getStockGlyphSocket(button)
    if stock and stock.GetScript then
        local onEnter = stock:GetScript("OnEnter")
        if type(onEnter) == "function" then
            local ok = pcall(onEnter, stock)
            if ok and GameTooltip and GameTooltip:IsShown() then
                if copyTooltipToButton(button) then return end
            end
        end
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local shown = false
    if GameTooltip.SetGlyph and info.socket then
        local ok = pcall(GameTooltip.SetGlyph, GameTooltip, info.socket, button._group or 1)
        shown = ok and true or false
    end
    if (not shown) and info.link and GameTooltip.SetHyperlink then
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, info.link)
        shown = ok and true or false
    end
    if not shown then
        GameTooltip:SetText(button._fallbackName or "Glyph Socket", 1, 1, 1)
        if button._fallbackState then GameTooltip:AddLine(button._fallbackState, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

local function clickStockGlyphSocket(button, mouseButton)
    local info = button and button._glyphInfo
    if not (info and info.socket and button._activePane) then return end
    if mouseButton == "RightButton" and type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown() then
        if button._hasGlyph and type(_G.StaticPopup_Show) == "function" then
            _G.StaticPopup_Show("DUI_GLYPH_REMOVE_CONFIRM", nil, nil, { button = button })
        end
        return
    end
    if mouseButton == "LeftButton" and CursorHasGlyph and CursorHasGlyph() then
        if PlaceGlyphInSocket then pcall(PlaceGlyphInSocket, info.socket) end
        return
    end
    local stock = getStockGlyphSocket(button)
    if not stock then return end
    if stock.Click then pcall(stock.Click, stock, mouseButton or "LeftButton"); return end
    local onClick = stock.GetScript and stock:GetScript("OnClick")
    if type(onClick) == "function" then pcall(onClick, stock, mouseButton or "LeftButton") end
end

-- ============================================================================
-- Socket visual state helpers
-- ============================================================================
local function applyBorderTint(button, hovered)
    if not (button and button.Border) then return end
    local tint = (hovered and button._hoverTint) or button._borderTint
    if not tint then return end
    button.Border:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 1)
end

local function applyIconHover(button, hovered)
    if not (button and button.Icon) then return end
    if not button._hasGlyph then
        button.Icon:SetAlpha(button._iconAlpha or 1)
        if button.IconTint then button.IconTint:SetAlpha(button._iconTintAlpha or 0) end
        return
    end
    local iconAlpha = button._iconAlpha or 1
    button.Icon:SetAlpha(hovered and math.min(1, iconAlpha + 0.45) or iconAlpha)
    if button.IconTint and button._iconTintShown then
        local tintAlpha = button._iconTintAlpha or 0
        button.IconTint:SetAlpha(hovered and math.min(1, tintAlpha + 0.40) or tintAlpha)
    end
end

local function setSocketHitRect(button, frameSize, hitSize)
    if not (button and button.SetHitRectInsets) then return end
    local inset = math.max(0, math.floor(((frameSize or 0) - (hitSize or 0)) / 2))
    button:SetHitRectInsets(inset, inset, inset, inset)
end

-- ============================================================================
-- Socket button factory
-- ============================================================================
local function buildSocket(parent, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(64, 64)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b.GlowUnder = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.GlowUnder:SetPoint("CENTER")

    b.Globe = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.Globe:SetPoint("CENTER")
    b.Globe:SetTexCoord(globeCoord(1))
    glyphGlobes[#glyphGlobes + 1] = b.Globe
    ensureGlobeTicker()

    b.Gloss = b:CreateTexture(nil, "ARTWORK", nil, 3)
    b.Gloss:SetPoint("CENTER")

    b.Border = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.Border:SetSize(64, 64)
    b.Border:SetPoint("CENTER")

    b.Glow = b:CreateTexture(nil, "ARTWORK", nil, -1)
    b.Glow:SetSize(82, 82)
    b.Glow:SetPoint("CENTER")
    b.Glow:SetBlendMode("ADD")
    b.Glow:Hide()

    b.Icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.Icon:SetSize(34, 34)
    b.Icon:SetPoint("CENTER")
    b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if b.Icon.SetVertexColor then b.Icon:SetVertexColor(1, 1, 1, 1) end

    b.IconTint = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.IconTint:SetSize(34, 34)
    b.IconTint:SetPoint("CENTER")
    b.IconTint:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.IconTint:SetBlendMode("ADD")
    b.IconTint:SetVertexColor(1.0, 0.84, 0.28)
    b.IconTint:SetAlpha(0.55)
    b.IconTint:Hide()

    b.Plus = b:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    b.Plus:SetPoint("CENTER", 0, 0)
    b.Plus:SetText("+")
    b.Plus:SetTextColor(0.95, 0.88, 0.55)

    b.Name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if _G.SystemFont_Shadow_Med1 then b.Name:SetFontObject(_G.SystemFont_Shadow_Med1) end
    b.Name:SetTextColor(0.95, 0.90, 0.75)
    b.Name:SetWidth(160)
    b.Name:SetWordWrap(true)
    b.Name:Hide()

    if index == 1 then
        b.Name:SetPoint("BOTTOM", b, "TOP", 0, 8); b.Name:SetJustifyH("CENTER")
    elseif index == 4 then
        b.Name:SetPoint("TOP", b, "BOTTOM", 0, -10); b.Name:SetJustifyH("CENTER")
    elseif index == 2 or index == 3 then
        b.Name:SetPoint("LEFT", b, "RIGHT", 10, 0); b.Name:SetJustifyH("LEFT")
    else
        b.Name:SetPoint("RIGHT", b, "LEFT", -10, 0); b.Name:SetJustifyH("RIGHT")
    end

    b:SetScript("OnEnter", function(self)
        self._hovered = true
        if self._hoverBorder then applyBorderTint(self, true) end
        applyIconHover(self, true)
        tooltipForSocket(self)
    end)
    b:SetScript("OnLeave", function(self)
        self._hovered = nil
        applyBorderTint(self, false)
        applyIconHover(self, false)
        if self.Glow then self.Glow:Hide() end
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self, mouseButton) clickStockGlyphSocket(self, mouseButton) end)

    b._index = index
    return b
end
local function updateSocket(button, info, activePane, wantMajor)
    button._glyphInfo = info
    button._group = info and info.group or button._group
    local slotIsMajor = (wantMajor == true) or (info and info.glyphType ~= 2) or false
    local slotButtonSize = slotIsMajor and 104 or 92
    local lockedMajorBorderSize = 74
    local emptyMajorBorderSize = 78
    local filledMajorBorderSize = 84
    local lockedMinorBorderSize = 57
    local emptyMinorBorderSize = 57
    local filledMinorBorderSize = 65
    if not info then
        button:SetSize(slotButtonSize, slotButtonSize)
        if button.Globe then button.Globe:Hide() end
        if button.GlowUnder then button.GlowUnder:Hide() end
        if button.Gloss then button.Gloss:Hide() end
        button.Border:SetTexture(GLYPH_RING_TEXTURE)
        local lockedBorderSize = slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize
        button.Border:SetSize(lockedBorderSize * RING_SCALE, lockedBorderSize * RING_SCALE)
        setSocketHitRect(button, slotButtonSize, lockedBorderSize)
        button._borderTint = { 0.55, 0.55, 0.55, 1 }
        button._hoverTint = nil; button._hoverBorder = nil
        applyBorderTint(button, false)
        button.Icon:SetSize(34, 34)
        button.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        button._hasGlyph = nil; button._iconAlpha = 1; button._iconTintAlpha = 0; button._iconTintShown = nil
        if button.Icon.SetDesaturated then button.Icon:SetDesaturated(true) end
        if button.IconTint then button.IconTint:Hide() end
        button.Glow:Hide(); button.Plus:SetText("")
        button._fallbackName = "Glyph Socket"; button._fallbackState = "Unavailable"
        if button.Name then button.Name:SetText(""); button.Name:Hide() end
        button:EnableMouse(false); button._activePane = nil; button:SetAlpha(0.45)
        return
    end
    button._activePane = activePane and true or nil
    button:EnableMouse(activePane and true or false)
    button:SetSize(slotButtonSize, slotButtonSize)
    button:SetAlpha(activePane and 1 or 0.55)
    if not info.enabled then
        button:SetSize(slotButtonSize, slotButtonSize)
        button.Border:SetTexture(GLYPH_RING_DESAT_TEXTURE)
        local lockedBorderSize = slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize
        button.Border:SetSize(lockedBorderSize * RING_SCALE, lockedBorderSize * RING_SCALE)
        configGlobe(button, slotIsMajor, false, lockedBorderSize)
        setSocketHitRect(button, slotButtonSize, lockedBorderSize)
        button._borderTint = { 0.55, 0.55, 0.55, 1 }
        button._hoverTint = nil; button._hoverBorder = nil
        applyBorderTint(button, false)
        button.Icon:SetSize(34, 34)
        button.Icon:SetTexture(emptyGlyphIcon(info.glyphType))
        button._hasGlyph = nil; button._iconAlpha = 1; button._iconTintAlpha = 0; button._iconTintShown = nil
        if button.Icon.SetDesaturated then button.Icon:SetDesaturated(true) end
        if button.IconTint then button.IconTint:Hide() end
        button.Glow:Hide(); button.Plus:SetText("")
        button._fallbackName = "Locked socket"; button._fallbackState = "Requires higher level"
        if button.Name then button.Name:SetText(""); button.Name:Hide() end
        return
    end
    local spellName, _, spellIcon = nil, nil, nil
    if info.glyphSpellID and info.glyphSpellID > 0 and GetSpellInfo then
        spellName, _, spellIcon = GetSpellInfo(info.glyphSpellID)
    end
    local isMajor = slotIsMajor
    local hasGlyph = (type(info.glyphSpellID) == "number" and info.glyphSpellID > 0)
    local borderSize = isMajor and ((hasGlyph and filledMajorBorderSize) or emptyMajorBorderSize)
                       or ((hasGlyph and filledMinorBorderSize) or emptyMinorBorderSize)
    button.Border:SetTexture(GLYPH_RING_TEXTURE)
    button.Border:SetSize(borderSize * RING_SCALE, borderSize * RING_SCALE)
    configGlobe(button, isMajor, hasGlyph and activePane, borderSize)
    setSocketHitRect(button, slotButtonSize, borderSize)
    button._borderTint = activePane and { 1.0, 1.0, 1.0, 1 } or { 0.70, 0.70, 0.70, 1 }
    button._hoverTint = { 1.0, 1.0, 1.0, 1 }
    button._hoverBorder = true
    applyBorderTint(button, button._hovered)
    local iconSize
    if isMajor then iconSize = hasGlyph and 52 or 47 else iconSize = hasGlyph and 34 or 30 end
    if not activePane then iconSize = iconSize - 2 end
    if hasGlyph then iconSize = iconSize * 0.9 end
    button.Icon:SetSize(iconSize, iconSize)
    local iconTex = hasGlyph and (info.icon or spellIcon) or emptyGlyphIcon(info.glyphType)
    if not hasGlyph then button.Icon:SetTexture(nil) end
    button.Icon:SetTexture(iconTex)
    if button.Icon.SetVertexColor then button.Icon:SetVertexColor(1, 1, 1, 1) end
    button._hasGlyph = hasGlyph and true or nil
    button._iconAlpha = hasGlyph and (activePane and 0.75 or 0.6) or (activePane and 1 or 0.75)
    button.Icon:SetAlpha(button._iconAlpha)
    if button.Icon.SetDesaturated then
        if hasGlyph and activePane then button.Icon:SetDesaturated(false) else button.Icon:SetDesaturated(not activePane) end
    end
    if button.IconTint then
        if hasGlyph and activePane then
            button.IconTint:SetSize(iconSize, iconSize)
            button.IconTint:SetTexture(iconTex)
            button._iconTintAlpha = isMajor and 0.7 or 0.5
            button._iconTintShown = true
            button.IconTint:SetAlpha(button._iconTintAlpha)
            button.IconTint:Show()
        else
            button._iconTintAlpha = 0; button._iconTintShown = nil; button.IconTint:Hide()
        end
    end
    button.Glow:Hide()
    applyIconHover(button, button._hovered)
    button.Plus:SetText("")
    local displayName = hasGlyph and glyphDisplayName(info, spellName) or nil
    button._fallbackName = displayName or spellName or "Glyph"
    button._fallbackState = hasGlyph and "Equipped" or "Empty socket"
    if button.Name then
        if glyphLabelNamesEnabled() and hasGlyph and displayName then
            button.Name:SetText(displayName)
            button.Name:SetAlpha(activePane and 1 or 0.8)
            button.Name:Show()
        else
            button.Name:SetText(""); button.Name:Hide()
        end
    end
end

local function specTabLabel(group)
    local text = _G["DragonUI_TalentSpecTab" .. tostring(group) .. "Text"]
    if text and text.GetText then
        local label = text:GetText()
        if label and label ~= "" then return label end
    end
    local tab = _G["DragonUI_TalentSpecTab" .. tostring(group)]
    if tab and tab.GetText then
        local label = tab:GetText()
        if label and label ~= "" then return label end
    end
    return (group == 2) and "Secondary" or "Primary"
end

local function groupStatus(group)
    return specTabLabel(group)
end

local function layoutPane(pane, index, total, rootWidth, rootHeight)
    if not pane then return end
    local gap = 0
    local paneW, paneH
    if total >= 2 then
        paneW = math.floor((rootWidth - gap) / 2)
        paneH = math.floor(rootHeight)
        pane:SetSize(paneW, paneH)
        pane:ClearAllPoints()
        if index == 1 then pane:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        else pane:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0) end
    else
        paneW = math.floor(rootWidth)
        paneH = math.floor(rootHeight)
        pane:SetSize(paneW, paneH)
        pane:ClearAllPoints()
        pane:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        pane:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    end
    applyPaneBackground(pane)
end

local function applyPaneStyle(pane, active)
    if not pane then return end
    local totalGroups = (GetNumTalentGroups and (GetNumTalentGroups() or 1)) or 1
    if totalGroups >= 2 then
        pane.spec:SetText(string.upper(pane._group or ""))
        pane.spec:Show()
    else
        pane.spec:SetText("")
        pane.spec:Hide()
    end
    pane.spec:SetTextColor(1, 1, 1)
end

local function updatePane(pane, group, activeGroup)
    if not pane then return end
    pane._group = group
    local activePane = (group == activeGroup)
    applyPaneStyle(pane, activePane)
    pane:SetAlpha(activePane and 1 or 0.62)

    local numSockets = (GetNumGlyphSockets and GetNumGlyphSockets()) or 0
    local majors, minors, other = {}, {}, {}
    for socketIndex = 1, numSockets do
        local info = getSocketInfo(socketIndex, group)
        if info then
            info.group = group
            if info.glyphType == 2 then table.insert(minors, info)
            elseif info.glyphType == 1 then table.insert(majors, info)
            else table.insert(other, info) end
        end
    end
    local function popFirst(tbl)
        if #tbl == 0 then return nil end
        return table.remove(tbl, 1)
    end
    for displayIndex = 1, SOCKET_COUNT do
        local button = pane.sockets[displayIndex]
        local wantMajor = (displayIndex % 2) == 1
        local info
        if wantMajor then info = popFirst(majors) or popFirst(other) or popFirst(minors)
        else info = popFirst(minors) or popFirst(other) or popFirst(majors) end
        updateSocket(button, info, activePane, wantMajor)
    end
    updatePaneEdges(pane, activePane)
    if T._glyphActive then pane:Show() else pane:Hide() end
end

local function layoutRoot()
    local h = T.Host and T.Host() or T.frame
    if not h then return nil end
    if root and root:GetParent() ~= h then root:SetParent(h) end
    if not root then
        root = CreateFrame("Frame", "DragonUI_TalentGlyphRoot", h)
        root:SetFrameLevel((h:GetFrameLevel() or 1))
        root.title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        if _G.SystemFont_Shadow_Large2 then root.title:SetFontObject(_G.SystemFont_Shadow_Large2) end
        if root.title.SetTextScale then root.title:SetTextScale(1.1) end
        root.title:SetJustifyH("CENTER")
        root.title:SetPoint("TOP", root, "TOP", 0, -28)
        root.title:SetText(GLYPHS or L["GLYPHS"] or "GLYPHS")
        root.title:SetTextColor(1, 1, 1)
        buildGlyphCog(root)
    end
    if root and not root.listFrame then
        local lf = CreateFrame("Frame", "DragonUI_TalentGlyphListFrame", root)
        lf.card = CreateFrame("Frame", "DragonUI_TalentGlyphCard", lf)
        lf.card:SetFrameLevel((lf:GetFrameLevel() or 1) + 1)
        lf.card.PaneTop = lf.card:CreateTexture(nil, "BACKGROUND")
        if lf.card.PaneTop.set_atlas then lf.card.PaneTop:set_atlas("professions-qualitypane-bg-top", false) end
        lf.card.PaneTop:SetPoint("TOPLEFT", lf.card, "TOPLEFT", 0, 0)
        lf.card.PaneTop:SetPoint("TOPRIGHT", lf.card, "TOPRIGHT", 0, 0)
        lf.card.PaneBottom = lf.card:CreateTexture(nil, "BACKGROUND")
        if lf.card.PaneBottom.set_atlas then lf.card.PaneBottom:set_atlas("professions-qualitypane-bg-bottom", false) end
        lf.card.PaneBottom:SetPoint("BOTTOMLEFT", lf.card, "BOTTOMLEFT", 0, 0)
        lf.card.PaneBottom:SetPoint("BOTTOMRIGHT", lf.card, "BOTTOMRIGHT", 0, 0)
        lf.card.PaneMid = lf.card:CreateTexture(nil, "BACKGROUND")
        if lf.card.PaneMid.set_atlas then lf.card.PaneMid:set_atlas("professions-qualitypane-bg-middle", false) end
        lf.card.PaneMid:SetPoint("TOPLEFT", lf.card.PaneTop, "BOTTOMLEFT", 0, 0)
        lf.card.PaneMid:SetPoint("BOTTOMRIGHT", lf.card.PaneBottom, "TOPRIGHT", 0, 0)
        lf.card:Hide()
        lf.textLayer = CreateFrame("Frame", nil, lf)
        lf.textLayer:SetAllPoints(lf)
        lf.textLayer:SetFrameLevel((lf:GetFrameLevel() or 1) + 2)
        lf.title = lf.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        if _G.SystemFont_Shadow_Large2 then lf.title:SetFontObject(_G.SystemFont_Shadow_Large2) end
        if lf.title.SetTextScale then lf.title:SetTextScale(0.72) end
        lf.title:SetText(L["ACTIVE EFFECTS"] or "ACTIVE EFFECTS")
        lf.title:SetPoint("TOPLEFT", lf, "TOPLEFT", 40, -66)
        lf.title:SetTextColor(1, 1, 1)
        lf.lines = {}
        lf.GetOrCreateLine = function(self, index)
            if self.lines[index] then return self.lines[index] end
            local line = self.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            if _G.SystemFont_Shadow_Med1 then line:SetFontObject(_G.SystemFont_Shadow_Med1) end
            line:SetWordWrap(true)
            line:SetJustifyH("LEFT")
            self.lines[index] = line
            return line
        end
        lf.icons = {}
        lf.GetOrCreateIcon = function(self, index)
            if self.icons[index] then return self.icons[index] end
            local tex = self.textLayer:CreateTexture(nil, "OVERLAY")
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            self.icons[index] = tex
            return tex
        end
        lf.scratchTip = CreateFrame("GameTooltip", "DragonUI_GlyphScratchTooltip", nil, "GameTooltipTemplate")
        lf.scratchTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        root.listFrame = lf
    end
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    root:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, (T.FRAME and T.FRAME.BOTTOMBAR_H) or 80)
    return root
end

local function buildPane(group)
    if panes[group] then return panes[group] end
    local h = T.Host and T.Host() or T.frame
    if not h then return nil end
    local pane = CreateFrame("Frame", "DragonUI_TalentGlyphPane" .. group, h)
    pane:SetFrameLevel((h:GetFrameLevel() or 1))

    pane.bg = pane:CreateTexture(nil, "BACKGROUND", nil, -1)
    pane.bg:SetAllPoints(pane)
    pane._bgNick = specBackgroundNick(group)
    pane._bgFlip = (group == 1)
    pane.bg:Hide()

    pane.spec = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if _G.SystemFont_Shadow_Large2 then pane.spec:SetFontObject(_G.SystemFont_Shadow_Large2) end
    if pane.spec.SetTextScale then pane.spec:SetTextScale(0.72) end
    pane.spec:SetJustifyH("CENTER")
    pane.spec:SetPoint("TOP", pane, "TOP", 0, -66)
    pane.spec:SetText("")

    pane.core = pane:CreateTexture(nil, "ARTWORK")
    pane.core:SetSize(84, 84)
    pane.core:SetPoint("CENTER", 0, 0)
    pane.core:Hide()

    pane.coreIcon = pane:CreateTexture(nil, "OVERLAY", nil, 1)
    pane.coreIcon:SetSize(20, 20)
    pane.coreIcon:SetPoint("CENTER", 0, 0)
    if not setAtlas(pane.coreIcon, "questlog-icon-setting", "Interface\\Buttons\\UI-OptionsButton") then
        pane.coreIcon:SetSize(18, 18)
    end
    pane.coreIcon:Hide()

    pane.sockets = {}
    local positions = {
        [1] = { 0, 118 }, [2] = { 102, 60 }, [3] = { 102, -60 },
        [4] = { 0, -118 }, [5] = { -102, -60 }, [6] = { -102, 60 },
    }
    for displayIndex = 1, SOCKET_COUNT do
        local socket = buildSocket(pane, displayIndex)
        socket:SetPoint("CENTER", pane, "CENTER", positions[displayIndex][1], positions[displayIndex][2])
        pane.sockets[displayIndex] = socket
    end

    panes[group] = pane
    return pane
end

local function ensurePanes()
    if not layoutRoot() then return nil end
    local currentGroup = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
    buildPane(currentGroup)
    return root
end

function T.GlyphsSetActive(on)
    T._glyphActive = on and true or false
    if T.GlyphsApplyPaneVisibility then T.GlyphsApplyPaneVisibility() end
end

function T.GlyphsIsActive()
    return T._glyphActive and true or false
end

-- ============================================================================
-- Glyph background (per-class painting behind sockets)
-- ============================================================================
local GLYPH_BG_PATH = TEX .. "Artifact\\"
local GLYPH_BG_FILE = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
    PRIEST = "Priest", DEATHKNIGHT = "DeathKnight", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}
local function applyGlyphBackground(f)
    if not f then return false end
    local _, classFile = UnitClass("player")
    local file = classFile and GLYPH_BG_FILE[classFile]
    if not file then return false end
    if not f.glyphBg then
        local FR = T.FRAME or {}
        local tx = f:CreateTexture(nil, "BORDER")
        tx:SetPoint("TOPLEFT",     f, "TOPLEFT",     (FR.CHROME_L or 0), -(FR.CHROME_T or 0))
        tx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(FR.CHROME_R or 0), (FR.CHROME_B or 0) + (FR.BOTTOMBAR_H or 0))
        tx:SetTexCoord(0, 1, 0, 1)
        f.glyphBg = tx
    end
    f.glyphBg:SetTexture(GLYPH_BG_PATH .. file)
    return true
end

function T.GlyphsApplyPaneVisibility()
    local f = T.frame
    local r = root or layoutRoot()
    if not r then return end

    if f and f.GetNumChildren then
        local search = _G.DragonUI_TalentSearchEdit
        if search then
            if T._glyphActive then search:Hide() else search:Show() end
        end
    end

    if T._glyphActive then
        if root.listFrame then
            if glyphShowEffectsEnabled() then root.listFrame:Show() else root.listFrame:Hide() end
        end
        if f then
            if f.bg then f.bg:Hide() end
            if f.petBg then f.petBg:Hide() end
            local hasArt = applyGlyphBackground(f)
            if f.glyphBg then if hasArt then f.glyphBg:Show() else f.glyphBg:Hide() end end
            if hasArt then
                for _, pane in pairs(panes) do if pane and pane.bg then pane.bg:Hide() end end
            end
            if f.trees then
                for _, tree in ipairs(f.trees) do if tree then tree:Hide() end end
            end
            if f.bottomBar then f.bottomBar:Show() end
            if f.pointsText then f.pointsText:Hide() end
            if f._loBtn then f._loBtn:Hide() end
            if f.apply then f.apply:Hide() end
            if f.reset then f.reset:Hide() end
            if f.activate then f.activate:Hide() end
        end
        local currentGroup = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
        for g, pane in pairs(panes) do
            if pane then
                if g == currentGroup then pane:Show() else pane:Hide() end
            end
        end
        r:Show()
    else
        if root.listFrame then root.listFrame:Hide() end
        for _, pane in pairs(panes) do if pane then pane:Hide() end end
        r:Hide()
        if f then
            if f.glyphBg then f.glyphBg:Hide() end
            local petView = T.PetViewActive and T.PetViewActive()
            if f.bg then if petView then f.bg:Hide() else f.bg:Show() end end
            if f.petBg then if petView then f.petBg:Show() else f.petBg:Hide() end end
            if f._loBtn and not petView then f._loBtn:Show() end
            if f.trees then
                for _, tree in ipairs(f.trees) do if tree then tree:Show() end end
            end
            if f.bottomBar then f.bottomBar:Show() end
            if f.pointsText then f.pointsText:Show() end
        end
    end
end

function T.GlyphsEnsureUI()
    if not ensurePanes() then return end
    T.GlyphsRefresh()
    T.GlyphsApplyPaneVisibility()
end

function T.GlyphsRefresh()
    if not ensurePanes() then return end
    local h = T.Host and T.Host() or T.frame
    if not h then return end
    local rootWidth = (root and root:GetWidth()) or (h.GetWidth and h:GetWidth()) or 0
    local rootHeight = (root and root:GetHeight()) or (h.GetHeight and h:GetHeight()) or 0
    if rootWidth <= 0 or rootHeight <= 0 then return end
    local activeGroup = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
    local currentGroup = activeGroup
    local showEffects = glyphShowEffectsEnabled()
    local pane = panes[currentGroup]
    if pane then
        layoutPane(pane, 1, showEffects and 2 or 1, rootWidth, rootHeight)
        updatePane(pane, currentGroup, activeGroup)
    end
    if root.listFrame then
        if not showEffects then
            root.listFrame:Hide()
            for _, line in pairs(root.listFrame.lines) do line:SetText(""); line:Hide() end
            for _, ic in pairs(root.listFrame.icons) do ic:Hide() end
        else
            root.listFrame:Show()
            local paneW = math.floor(rootWidth / 2)
            root.listFrame:SetSize(paneW, rootHeight)
            root.listFrame:ClearAllPoints()
            root.listFrame:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)

            local numSockets = (GetNumGlyphSockets and GetNumGlyphSockets()) or 0
            local majors, minors = {}, {}

            local function getSpellDesc(spellID)
                if not spellID or spellID <= 0 then return "" end
                local tip = root.listFrame.scratchTip
                tip:ClearLines()
                tip:SetHyperlink("spell:" .. spellID)
                for k = 2, tip:NumLines() do
                    local textObj = _G["DragonUI_GlyphScratchTooltipTextLeft" .. k]
                    if textObj and textObj.GetText then
                        local txt = textObj:GetText()
                        if txt and txt ~= "" and not txt:find("^%s*Requires") then
                            return txt
                        end
                    end
                end
                return ""
            end

            for i = 1, numSockets do
                local info = getSocketInfo(i, currentGroup)
                if info and info.enabled and type(info.glyphSpellID) == "number" and info.glyphSpellID > 0 then
                    local spellName, _, spellIcon = GetSpellInfo(info.glyphSpellID)
                    if spellName then
                        local data = { name = trimGlyphPrefix(spellName), desc = getSpellDesc(info.glyphSpellID),
                                       icon = info.icon or spellIcon }
                        if info.glyphType == 2 then table.insert(minors, data) else table.insert(majors, data) end
                    end
                end
            end

            local SECTION_SCALE, NAME_SCALE, DESC_SCALE = 1.15, 1.08, 1.02
            local CARD_W = math.max(320, math.min(440, math.floor(paneW - 80)))
            local cardX = math.floor((paneW - CARD_W) / 2)
            local TEXT_PAD = 26
            local ICON_X, ICON_SIZE, ICON_PAD = TEXT_PAD, 26, 8
            local TEXT_INDENT = ICON_X + ICON_SIZE + ICON_PAD

            local entries = {}
            local function addEntry(text, scale, gap, indent, icon)
                entries[#entries + 1] = { text = text, scale = scale, gap = gap, indent = indent or 0, icon = icon }
                return #entries
            end
            local function addSection(headerText, list)
                addEntry("|cffffcc55" .. headerText .. "|r", SECTION_SCALE, (#entries > 0) and 28 or 0, TEXT_PAD)
                if #list == 0 then
                    addEntry("|cff808080None active.|r", NAME_SCALE, 8, TEXT_INDENT)
                else
                    for _, glyph in ipairs(list) do
                        local nameIdx = addEntry("|cffffd100" .. glyph.name .. "|r", NAME_SCALE, 10, TEXT_INDENT, glyph.icon)
                        local lastIdx = nameIdx
                        if glyph.desc ~= "" then
                            lastIdx = addEntry("|cffb3b3b3" .. glyph.desc .. "|r", DESC_SCALE, 4, TEXT_INDENT)
                        end
                        entries[nameIdx].blockEnd = lastIdx
                    end
                end
            end

            local hasAny = (#majors > 0) or (#minors > 0)
            if hasAny then
                root.listFrame.title:SetText("")
                root.listFrame.title:Hide()
                addSection(L["MAJOR GLYPHS"] or "MAJOR GLYPHS", majors)
                addSection(L["MINOR GLYPHS"] or "MINOR GLYPHS", minors)
            else
                root.listFrame.title:SetText(L["NO ACTIVE EFFECTS"] or "NO ACTIVE EFFECTS")
                root.listFrame.title:Show()
            end

            for _, line in pairs(root.listFrame.lines) do line:SetText(""); line:Hide() end
            for _, ic in pairs(root.listFrame.icons) do ic:Hide() end
            local rendered = {}
            for idx, e in ipairs(entries) do
                local line = root.listFrame:GetOrCreateLine(idx)
                line:SetWidth(math.max(80, CARD_W - e.indent - TEXT_PAD))
                line:SetText(e.text)
                if line.SetTextScale then line:SetTextScale(e.scale) end
                rendered[idx] = line
            end

            local TITLE_GAP = 22
            local titleH = hasAny and 0
                           or ((root.listFrame.title.GetStringHeight and root.listFrame.title:GetStringHeight()) or 0)
            local blockH = titleH
            if titleH > 0 and #entries > 0 then blockH = blockH + TITLE_GAP end
            for idx, e in ipairs(entries) do
                blockH = blockH + e.gap + ((rendered[idx].GetStringHeight and rendered[idx]:GetStringHeight()) or 0)
            end

            local topOffset = math.max(24, math.floor((rootHeight - blockH) / 2))
            root.listFrame.title:ClearAllPoints()
            root.listFrame.title:SetJustifyH("CENTER")
            root.listFrame.title:SetPoint("TOP", root.listFrame, "TOPLEFT", cardX + CARD_W / 2, -topOffset)

            local lineTop, lineH = {}, {}
            local y = topOffset + titleH + ((titleH > 0 and #entries > 0) and TITLE_GAP or 0)
            for idx, e in ipairs(entries) do
                local line = rendered[idx]
                y = y + e.gap
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", root.listFrame, "TOPLEFT", cardX + e.indent, -y)
                line:Show()
                lineTop[idx] = y
                lineH[idx] = (line.GetStringHeight and line:GetStringHeight()) or 0
                y = y + lineH[idx]
            end

            for idx, e in ipairs(entries) do
                if e.icon then
                    local last = e.blockEnd or idx
                    local blockTop = lineTop[idx]
                    local blockBottom = (lineTop[last] or lineTop[idx]) + (lineH[last] or lineH[idx] or 0)
                    local iconCenter = (blockTop + blockBottom) / 2
                    local ic = root.listFrame:GetOrCreateIcon(idx)
                    ic:SetTexture(e.icon)
                    ic:SetSize(ICON_SIZE, ICON_SIZE)
                    ic:ClearAllPoints()
                    ic:SetPoint("TOPLEFT", root.listFrame, "TOPLEFT", cardX + ICON_X, -(iconCenter - ICON_SIZE / 2))
                    ic:Show()
                end
            end

            if root.listFrame.card then
                local card = root.listFrame.card
                local contentBottom = (#entries > 0) and y or (topOffset + titleH)
                local CARD_PAD_TOP, CARD_PAD_BOTTOM = 40, 40
                local cardTop = topOffset - CARD_PAD_TOP
                local cardBottom = contentBottom + CARD_PAD_BOTTOM
                local capH = math.floor(100 * CARD_W / 260 + 0.5)
                local minH = capH * 2
                if (cardBottom - cardTop) < minH then
                    local c = (cardTop + cardBottom) / 2
                    cardTop, cardBottom = c - minH / 2, c + minH / 2
                end
                card.PaneTop:SetHeight(capH)
                card.PaneBottom:SetHeight(capH)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", root.listFrame, "TOPLEFT", cardX, -cardTop)
                card:SetPoint("BOTTOMRIGHT", root.listFrame, "TOPLEFT", cardX + CARD_W, -cardBottom)
                card:Show()
            end
        end
    end

    for g, p in pairs(panes) do
        if p and g ~= currentGroup then p:Hide() end
    end
end

function T.LO_HidePanel() if T.panel and T.panel:IsShown() then T.panel:Hide() end end
function T.LO_TogglePanel() if filterButton and filterButton:GetScript("OnClick") then filterButton:GetScript("OnClick")(filterButton) end; if T.LO_HidePanel then T.LO_HidePanel() end end
